"""Build the app's translation catalogs from tool/l10n/<lang>/ sources.

Every folder under tool/l10n/ that has a meta.json is a language:
  meta.json          {"name": native name, "english_name": ..., "geo_field": "name_xx"}
  translated.json    English source -> translation (bulk translation output)
  reviewed.tsv       hand-reviewed overrides: source<TAB>translation, newlines as \\n
  countries.json     optional {"names": {...}, "short_names": {...}} overrides
  InfoPlist.strings  optional iOS permission prompts

Outputs (all generated, never edit by hand):
  build/l10n/<lang>-<hash>.json   one catalog per language, for publish.py
  assets/l10n/languages.json      bundled manifest the app starts from
  assets/l10n/<lang>.json         only for languages with "bundled": true
  and the iOS language registration.

Usage: python tool/l10n/build.py [--check]
"""
import hashlib
import json
import pathlib
import re
import shutil
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = ROOT / 'tool/l10n'
OUT = ROOT / 'assets/l10n'
PUBLISH = ROOT / 'build/l10n'  # uploaded to Firebase Storage by publish.py
IOS = ROOT / 'ios/Runner'
BUCKET = 'proboscis-2025.firebasestorage.app'
STORAGE_PREFIX = 'l10n/'
# Public-read Storage objects are served without auth or the Firebase SDK.
BASE_URL = f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/'


def load_json(path, default=None):
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else default


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def languages():
    """Every language folder, including ones still being translated."""
    return sorted(p.parent.name for p in SOURCES.glob('*/meta.json'))


def ready_languages(minimum=0.98):
    """Languages complete enough to ship: an unfinished translation would show
    up in the app's language list while displaying mostly English."""
    counts = {lang: len(build_messages(lang)) for lang in languages()}
    full = max(counts.values(), default=0)
    ready = [lang for lang, n in counts.items() if full and n >= minimum * full]
    for lang in sorted(set(counts) - set(ready)):
        print(f'{lang}: skipped, {counts[lang]}/{full} strings translated')
    return ready


def read_reviewed(path):
    reviewed = {}
    if not path.exists():
        return reviewed
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        source, translation = line.split('\t', 1)
        reviewed[source.replace('\\n', '\n')] = translation.replace('\\n', '\n')
    return reviewed


def build_messages(lang):
    folder = SOURCES / lang
    messages = load_json(folder / 'translated.json', {})
    messages.update(read_reviewed(folder / 'reviewed.tsv'))
    return messages


# Spellings the app uses that the map data lacks, resolved to a spelling it has.
COUNTRY_ALIASES = {
    'Turkiye': 'Turkey', 'Türkiye': 'Turkey', 'USA': 'United States of America',
    'UK': 'United Kingdom', 'UAE': 'United Arab Emirates', 'Korea': 'South Korea',
    'Republic of Korea': 'South Korea', 'Korea, Republic of': 'South Korea',
    'Czech Republic': 'Czechia',
}


def country_sources():
    """English country names, for languages the map data has no names for:
    they are translated like any other string (see translate.py)."""
    return sorted(set(build_countries(None, {'geo_field': 'name_en'}).values()))


def build_countries(lang, meta, messages=None):
    """Country display names from the Natural Earth asset, keyed by every
    English spelling the app uses for that country. Without a `geo_field`
    the English names are looked up in the language's translations."""
    field = meta.get('geo_field')
    if not field:
        english = build_countries(None, {'geo_field': 'name_en'})
        countries = {k: messages[v] for k, v in english.items() if v in (messages or {})}
        return apply_country_overrides(lang, countries)
    features = load_json(ROOT / 'assets/custom.geo.json')['features']
    countries, by_iso = {}, {}
    for feature in features:
        p = feature['properties']
        name = p.get(field)
        if not name:
            continue
        for key in ('name', 'name_long', 'name_en', 'admin', 'formal_en', 'brk_name', 'name_sort'):
            if p.get(key):
                countries[p[key]] = name
        for key in ('iso_a3', 'adm0_a3'):
            by_iso[p.get(key)] = name
    for country in load_json(ROOT / 'assets/countries_light.json'):
        countries[country['name']] = by_iso[country['iso_a3']]
        by_iso[country['iso_a2']] = by_iso[country['iso_a3']]
    # Game labels can use a different English spelling for the same ISO country.
    flag_source = (ROOT / 'lib/games/flag_guess.dart').read_text(encoding='utf-8')
    for match in re.finditer(r'''_FlagCountry\(\s*(['"])(.*?)\1\s*,\s*(['"])([A-Z]{2})\3''', flag_source):
        if match[4] in by_iso:
            countries[match[2].replace("\\'", "'")] = by_iso[match[4]]
    for alias, target in COUNTRY_ALIASES.items():
        if alias not in countries and target in countries:
            countries[alias] = countries[target]
    return apply_country_overrides(lang, countries)


def apply_country_overrides(lang, countries):
    overrides = load_json(SOURCES / lang / 'countries.json', {}) if lang else {}
    countries.update(overrides.get('names', {}))
    short = overrides.get('short_names', {})
    return {key: short.get(value, value) for key, value in countries.items()}


def ios_code(lang):
    return lang  # Flutter-style codes (ko, ja, zh-Hant) are valid iOS lproj names.


def sync_ios(langs):
    """Register each language with iOS: CFBundleLocalizations, knownRegions and
    a localized InfoPlist.strings variant."""
    codes = ['en'] + [ios_code(lang) for lang in langs]
    plist_path = IOS / 'Info.plist'
    plist = plist_path.read_text(encoding='utf-8')
    entries = ''.join(f'        <string>{code}</string>\n' for code in codes)
    plist = re.sub(
        r'(<key>CFBundleLocalizations</key>\s*<array>\n).*?(\s*</array>)',
        lambda m: m[1] + entries.rstrip('\n') + m[2], plist, count=1, flags=re.S)
    plist_path.write_text(plist, encoding='utf-8')

    pbx_path = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    pbx = pbx_path.read_text(encoding='utf-8')
    for lang in langs:
        code = ios_code(lang)
        strings = SOURCES / lang / 'InfoPlist.strings'
        if strings.exists():
            target = IOS / f'{code}.lproj'
            target.mkdir(exist_ok=True)
            (target / 'InfoPlist.strings').write_text(strings.read_text(encoding='utf-8'), encoding='utf-8')
            if f'path = {code}.lproj/InfoPlist.strings;' not in pbx and f'path = "{code}.lproj/InfoPlist.strings";' not in pbx:
                ref = 'A18B1018C0DE' + f'{abs(hash_code(code)) % 16**12:012X}'
                quoted = f'"{code}"' if '-' in code else code
                pbx = pbx.replace(
                    '/* Begin PBXFileReference section */\n',
                    '/* Begin PBXFileReference section */\n'
                    f'\t\t{ref} /* {code} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
                    f'name = {quoted}; path = "{code}.lproj/InfoPlist.strings"; sourceTree = "<group>"; }};\n', 1)
                pbx = re.sub(
                    r'(/\* InfoPlist\.strings \*/ = \{\s*isa = PBXVariantGroup;\s*children = \(\n)',
                    lambda m: m[1] + f'\t\t\t\t{ref} /* {code} */,\n', pbx, count=1)
        regions = re.search(r'knownRegions = \((.*?)\);', pbx, re.S)
        known = {r.strip().strip('"') for r in regions[1].split(',') if r.strip()}
        if code not in known:
            quoted = f'"{code}"' if '-' in code else code
            pbx = pbx.replace(regions[0], regions[0].replace('\n\t\t\t\tBase,', f'\n\t\t\t\t{quoted},\n\t\t\t\tBase,'))
    pbx_path.write_text(pbx, encoding='utf-8')


def hash_code(text):
    # Stable across runs (Python's hash() is salted per process).
    value = 0
    for char in text:
        value = (value * 131 + ord(char)) % (1 << 48)
    return value


def code_strings():
    """Literal tr('...') strings in lib/, mapped to the file they appear in."""
    found = {}
    for path in (ROOT / 'lib').rglob('*.dart'):
        for match in re.finditer(r"\btr\(\s*'((?:[^'\\$]|\\.)*)'\s*[,)]", path.read_text(encoding='utf-8')):
            text = match[1].replace("\\'", "'").replace('\\n', '\n')
            if len(re.findall('[A-Za-z]', text)) > 3:
                found.setdefault(text, path.name)
    return found


def check(lang, messages, countries):
    """Report literal tr('...') strings in lib/ that have no translation."""
    known = {k.strip().lower() for k in list(messages) + list(countries)}
    for text, file in sorted(code_strings().items()):
        if text.strip().lower() not in known:
            print(f'  [{lang}] untranslated in {file}: {text!r}')


def main():
    langs = ready_languages()
    OUT.mkdir(exist_ok=True)
    shutil.rmtree(PUBLISH, ignore_errors=True)
    PUBLISH.mkdir(parents=True)
    for stale in OUT.glob('*.json'):
        if stale.name != 'languages.json':
            stale.unlink()
    previous = load_json(OUT / 'languages.json', {})
    if not isinstance(previous, dict):  # pre-manifest format
        previous = {}
    index = []
    for lang in langs:
        meta = load_json(SOURCES / lang / 'meta.json')
        messages = build_messages(lang)
        countries = build_countries(lang, meta, messages)
        payload = json.dumps({'messages': messages, 'countries': countries},
                             ensure_ascii=False, separators=(',', ':'),
                             sort_keys=True).encode('utf-8')  # stable hash
        digest = hashlib.sha256(payload).hexdigest()
        # Content-addressed, so a published file never changes under a cached copy.
        file = f'{lang}-{digest[:16]}.json'
        (PUBLISH / file).write_bytes(payload)
        if meta.get('bundled'):
            (OUT / f'{lang}.json').write_bytes(payload)
        index.append({
            'code': lang, 'name': meta['name'], 'english_name': meta['english_name'],
            'file': file, 'sha256': digest, 'bundled': bool(meta.get('bundled')),
        })
        print(f'{lang}: {len(messages)} messages, {len(countries)} country names -> {file}')
        if '--check' in sys.argv:
            check(lang, messages, countries)
    # The app prefers whichever manifest (bundled or published) has the higher
    # version, so it only moves forward when the content actually changed.
    version = previous.get('version', 0)
    if index != previous.get('languages'):
        version = max(version + 1, int(time.time()))
    manifest = {'version': version, 'base_url': BASE_URL, 'prefix': STORAGE_PREFIX, 'languages': index}
    write_json(OUT / 'languages.json', manifest)
    write_json(PUBLISH / 'languages.json', manifest)
    sync_ios(langs)


if __name__ == '__main__':
    main()
