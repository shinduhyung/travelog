"""Prepare and merge bulk translation work for one language.

  python tool/l10n/translate.py prepare <lang>   # write work/in/NNN.json chunks
  python tool/l10n/translate.py merge <lang>     # validate work/out, update translated.json

The source strings are every English string any language already translates,
plus literal tr('...') strings in lib/ that no language has yet. Only strings
this language is missing are prepared, so rerunning after adding new content
translates just the new strings. See tool/l10n/README.md for the workflow.
"""
import json
import re
import shutil
import sys

from build import ROOT, SOURCES, code_strings, country_sources, languages, load_json, read_reviewed, write_json

CHUNK_CHARS = 30000
REFERENCE = 'ko'  # hand-reviewed language used as a context hint
GEO_FIELDS = {'zh': 'name_zh', 'zh-Hans': 'name_zh', 'zh-Hant': 'name_zht', 'pt-BR': 'name_pt'}


def existing(lang):
    folder = SOURCES / lang
    return set(load_json(folder / 'translated.json', {})) | set(read_reviewed(folder / 'reviewed.tsv'))


def landmark_context():
    context = {}
    for name in ['all_landmarks', 'unesco_landmarks']:
        for item in load_json(ROOT / f'assets/{name}.json'):
            label = item['name'] + (f" / {item['city']}" if item.get('city') else '')
            for field in ['overview', 'history_significance', 'history', 'highlights']:
                if isinstance(item.get(field), str) and item[field].strip():
                    context.setdefault(item[field], label)
    return context


def prepare(lang):
    folder = SOURCES / lang
    folder.mkdir(exist_ok=True)
    if not (folder / 'meta.json').exists():
        write_json(folder / 'meta.json', {
            'name': 'TODO native language name',
            'english_name': 'TODO English language name',
            'geo_field': GEO_FIELDS.get(lang, f"name_{lang.split('-')[0]}"),
        })
        print(f'Created {folder / "meta.json"}: fill in the language names.')
    sources = {}  # ordered set
    for other in languages():
        sources.update(dict.fromkeys(load_json(SOURCES / other / 'translated.json', {})))
        sources.update(dict.fromkeys(read_reviewed(SOURCES / other / 'reviewed.tsv')))
    sources = list(sources)
    # The app looks strings up trimmed and case-insensitively as a fallback.
    norm = lambda text: text.strip().lower()
    known = {norm(s) for s in sources}
    sources += [s for s in code_strings() if norm(s) not in known]
    if not load_json(folder / 'meta.json', {}).get('geo_field'):
        # No map-data names for this language: translate the country names too.
        sources += [s for s in country_sources() if norm(s) not in known]
    done = {norm(s) for s in existing(lang)}
    todo = [s for s in dict.fromkeys(sources) if norm(s) not in done]
    context = landmark_context()
    # An existing translation disambiguates short labels ("Met", "Stay").
    reference = {} if lang == REFERENCE else {
        **load_json(SOURCES / REFERENCE / 'translated.json', {}),
        **read_reviewed(SOURCES / REFERENCE / 'reviewed.tsv'),
    }
    work = folder / 'work'
    shutil.rmtree(work, ignore_errors=True)
    (work / 'in').mkdir(parents=True)
    (work / 'out').mkdir()
    chunk, size, count = [], 0, 0
    def flush():
        nonlocal chunk, size, count
        if chunk:
            write_json(work / 'in' / f'{count:03d}.json', chunk)
            count += 1
        chunk, size = [], 0
    for source in todo:
        item = {'id': len(chunk), 'en': source}
        if source in context:
            item['landmark'] = context[source]
        elif len(source) < 40 and source in reference:
            item[f'ref_{REFERENCE}'] = reference[source]
        chunk.append(item)
        size += len(source) + 40
        if size >= CHUNK_CHARS:
            flush()
    flush()
    print(f'{lang}: {len(todo)} strings to translate in {count} chunks under {work / "in"}')


def plural_slots(source):
    """Placeholders glued to an English word ("hop{1}") carry a plural "s"."""
    return set(re.findall(r'(?<=[A-Za-z])\{\d+\}', source))


def drop_plural_slots(source, translation):
    """Drop a plural slot unless the translation glued it to a Latin-script
    word too ("día{1}" → días): languages without an "s" plural lose it."""
    for slot in plural_slots(source):
        translation = re.sub(r'(?<![A-Za-zÀ-ɏ])' + re.escape(slot), '', translation)
    return translation


def validate(item, translation):
    source = item['en']
    if not translation.strip():
        return 'empty'
    if source.count('\n') != translation.count('\n'):
        return 'line count'
    every = set(re.findall(r'\{\d+\}', source))
    found = set(re.findall(r'\{\d+\}', translation))
    # Plural slots are optional: kept where the language also adds "s".
    if not every - plural_slots(source) <= found <= every:
        return 'placeholders'
    return None


def merge(lang):
    folder = SOURCES / lang
    work = folder / 'work'
    translated = load_json(folder / 'translated.json', {})
    missing, issues, added = [], [], 0
    for chunk in sorted((work / 'in').glob('*.json')):
        out = work / 'out' / chunk.name
        if not out.exists():
            missing.append(chunk.stem)
            continue
        items, result = load_json(chunk), load_json(out)
        for item in items:
            translation = result.get(str(item['id']))
            if translation is not None:
                translation = drop_plural_slots(item['en'], translation)
            problem = 'missing' if translation is None else validate(item, translation)
            if problem:
                issues.append(f'{chunk.stem}#{item["id"]}: {problem}: {item["en"][:60]!r}')
                continue
            translated[item['en']] = translation
            added += 1
    write_json(folder / 'translated.json', translated)
    print(f'{lang}: merged {added} translations ({len(translated)} total)')
    if missing:
        print('Chunks without output: ' + ' '.join(missing))
    for issue in issues:
        print('  ' + issue)
    return 1 if missing or issues else 0


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('prepare', 'merge'):
        sys.exit(__doc__)
    command, lang = sys.argv[1:]
    sys.exit(prepare(lang) if command == 'prepare' else merge(lang))
