"""Build display-only country aliases from the existing Natural Earth asset."""
import json
import pathlib
import re
import sys
from localization_entities import names, trie, mask, restore, COMMON_WORDS

root = pathlib.Path(__file__).resolve().parent.parent
out = root / 'assets/l10n'
out.mkdir(exist_ok=True)
features = json.loads((root / 'assets/custom.geo.json').read_text(encoding='utf-8'))['features']
countries = {}
by_iso = {}
for feature in features:
    p = feature['properties']
    ko = p.get('name_ko')
    if not ko:
        continue
    for key in ('name', 'name_long', 'name_en', 'admin', 'formal_en', 'brk_name', 'name_sort'):
        if p.get(key):
            countries[p[key]] = ko
    for key in ('iso_a3', 'adm0_a3'):
        by_iso[p.get(key)] = ko
for country in json.loads((root / 'assets/countries_light.json').read_text(encoding='utf-8')):
    countries[country['name']] = by_iso[country['iso_a3']]
    by_iso[country['iso_a2']] = by_iso[country['iso_a3']]
# Game labels can use a different English spelling for the same ISO country.
flag_source = (root / 'lib/games/flag_guess.dart').read_text(encoding='utf-8')
for match in re.finditer(r'''_FlagCountry\(\s*(['"])(.*?)\1\s*,\s*(['"])([A-Z]{2})\3''', flag_source):
    if match[4] in by_iso:
        countries[match[2].replace("\\'", "'")] = by_iso[match[4]]
countries['Turkiye'] = '튀르키예'
countries.update({'South Korea': '대한민국', 'Republic of Korea': '대한민국', 'Korea, Republic of': '대한민국', 'Korea': '대한민국', 'USA': '미국', 'UK': '영국', 'UAE': '아랍에미리트', 'Czech Republic': '체코', 'Türkiye': '튀르키예', 'Turkey': '튀르키예'})
short_names = {'중화인민공화국': '중국', '조선민주주의인민공화국': '북한', '중화민국': '대만'}
countries = {key: short_names.get(value, value) for key, value in countries.items()}
(out / 'countries_ko.json').write_text(json.dumps(countries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
editorial = out / 'ko_editorial.json'
draft = json.loads(editorial.read_text(encoding='utf-8')) if editorial.exists() else {}
reviewed = {}
for line in (out / 'ko.tsv').read_text(encoding='utf-8').splitlines():
    if not line or line.startswith('#'):
        continue
    source, translation = line.split('\t', 1)
    reviewed[source.replace('\\n', '\n')] = translation.replace('\\n', '\n')
entity_names = names()
protected = trie(entity_names - set(reviewed) - set(countries) - COMMON_WORDS)
glossary = {key: value for key, value in (reviewed | countries).items() if '{' not in key and re.search('[A-Za-z]', key) and len(key) > 2}
glossary.update({'Many': '많은', 'The': '그', 'This': '이', 'These': '이러한', 'Those': '그러한', 'First': '첫', 'Second': '두 번째', 'English': '영어', 'Roman': '로마', 'Independence': '독립', 'International': '국제', 'National': '국립', 'City': '도시', 'Town': '마을', 'Republic': '공화국', 'Union': '연합', 'Ocean': '대양', 'Sea': '바다', 'River': '강', 'Lake': '호수', 'Bay': '만', 'Island': '섬', 'Valley': '계곡', 'Mountain': '산', 'Home': '본거지', 'Old': '오래된', 'New': '새로운', 'Central': '중부', 'North': '북부', 'South': '남부', 'East': '동부', 'West': '서부'})
pattern = re.compile(r'(?<![A-Za-z])(?:' + '|'.join(re.escape(x) for x in sorted(glossary, key=len, reverse=True)) + r')(?![A-Za-z])')
messages = {}
for source, translation in draft.items():
    if source in entity_names and source not in reviewed and source not in countries:
        continue
    hidden, originals = mask(translation, protected)
    cleaned = pattern.sub(lambda match: glossary[match[0]], hidden)
    if re.search(r'\bcapital\b', source, re.IGNORECASE) and not re.search(r'\b(?:investment|stock|venture|human) capital\b|capital (?:investment|stock|market|flow)', source, re.IGNORECASE):
        cleaned = cleaned.replace('자본', '수도')
    translated = restore(cleaned, originals)
    capital = re.fullmatch(r'Which country has (.+) as its capital\?', source)
    if capital:
        translated = f'{capital[1]}을(를) 수도로 하는 국가는 어디인가요?'
    capital_of = re.fullmatch(r'What is the capital of (.+)\?', source)
    if capital_of:
        translated = f'{countries.get(capital_of[1], capital_of[1])}의 수도는 어디인가요?'
    attractions = re.fullmatch(r'Which (city|country) (?:contains|is home to) (.+)\?', source)
    if attractions:
        sites = attractions[2].removeprefix('the ').split(' and ')
        if all(site in entity_names for site in sites):
            locations = '와(과) '.join(sites)
            kind = '도시' if attractions[1] == 'city' else '국가'
            translated = f'{locations}이(가) 있는 {kind}는 어디인가요?'
    messages[source] = translated
# Full editorial retranslations replace the machine draft verbatim (no glossary
# pass), but hand-reviewed UI strings still win.
retranslated = out / 'ko_retranslated.json'
if retranslated.exists():
    messages.update(json.loads(retranslated.read_text(encoding='utf-8')))
messages.update(reviewed)
assert all('ZXQ' not in value for value in messages.values()), 'Unrestored translation protection token'
(out / 'ko.json').write_text(json.dumps(messages, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    print(f'{len(messages)} Korean messages, {len(countries)} country aliases')
    if '--audit' in sys.argv:
        words = set()
        for source_file in (root / 'lib').rglob('*.dart'):
            for word in re.findall(r'''['"]([A-Z][a-z]+(?:-[A-Z]?[a-z]+)?)['"]''', source_file.read_text(encoding='utf-8')):
                if word not in messages and word not in countries and word not in (entity_names - COMMON_WORDS):
                    words.add(word)
        print('Uncatalogued label candidates: ' + ', '.join(sorted(words)))
