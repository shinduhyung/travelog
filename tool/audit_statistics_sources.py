"""Offline verification against the downloaded official source snapshots.

Requires audit/sources produced during the 2026-10-17 audit.
Does not modify app source or assets.
"""
from statistics_schema import decode_statistics
import collections
import csv
import html
import json
import pathlib
import re
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit'
SOURCES = OUT / 'sources'


def read_asset(name):
    return decode_statistics(json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8-sig')))


def normal(value):
    value = unicodedata.normalize('NFKD', html.unescape(value)).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]', '', value)


def main():
    result = {}
    # UNDP's complete 2025 release contains observations through 2023.
    with (SOURCES / 'hdi_2025.csv').open(encoding='latin1', newline='') as f:
        official = {r['iso3']: r for r in csv.DictReader(f)}
    result['hdi'] = []
    for row in read_asset('hdi_data.json'):
        value = official.get(row['iso_a3'], {}).get('hdi_2023')
        result['hdi'].append({'iso_a3': row['iso_a3'], 'local': row['hdi'], 'official_2023': float(value) if value else None,
                              'matches_at_3dp': round(float(value), 3) == row['hdi'] if value else None})

    # Keep rank comparisons internal; report aggregates and a few examples,
    # rather than reproducing Skytrax's entire ranking in the findings.
    for kind, filename, name_key in [('airlines', 'top_airlines.json', 'name'), ('airports', 'top_airports.json', 'airport')]:
        body = (SOURCES / f'skytrax_{kind}_2026.html').read_text(encoding='utf8')
        pairs = re.findall(r'<h6[^>]*>\s*(\d+)\s*</h6>.*?<h4[^>]*>(.*?)</h4>', body, re.S)
        assert len(pairs) == 100, f'{kind}: failed to parse the full ranking'
        ranks = {normal(n): int(r) for r, n in pairs}
        aliases = {'cathaypacific': 'cathaypacificairways', 'alaskaairlines': 'alaskaairlines',
                   'saudiarabianairlines': 'saudia', 'azulairlines': 'azulbrazilian',
                   'jetsmart': 'jetsmartairlines', 'guangzhou': 'guangzhoubaiyun',
                   'shenzhen': 'shenzhenbaoan', 'johannesburg': 'johannesburgortambo',
                   'seoulgimpo': 'seoulgimpo', 'istanbulairport': 'istanbul', 'hongkonginternational': 'hongkong'}
        comparisons = []
        for row in read_asset(filename):
            key = normal(row[name_key])
            official_rank = ranks.get(aliases.get(key, key))
            comparisons.append({'name': row[name_key], 'local_rank': row['rank'], 'official_2026_rank': official_rank,
                                'status': 'name_unmatched_or_not_top100' if official_rank is None else 'same' if row['rank'] == official_rank else 'changed'})
        result[f'skytrax_{kind}'] = {'summary': dict(collections.Counter(r['status'] for r in comparisons)), 'comparisons': comparisons}

    # Global Firepower: normalize source names against the app's own country list.
    body = (SOURCES / 'globalfirepower_2026.html').read_text(encoding='utf8')
    pairs = re.findall(r'title="Military strength values of (.*?) for the year 2026".*?PwrIndx:\s*([0-9.]+)', body, re.S)
    assert len(pairs) == 145, 'Global Firepower: incomplete source parse'
    country_names = {r['iso_a3']: r['name'] for r in read_asset('updated_country_populations.json')}
    indices = {normal(n): float(v) for n, v in pairs}
    aliases = {'unitedstatesofamerica': 'unitedstates', 'czechrepublic': 'czechia', 'turkey': 'turkiye',
               'ivorycoast': 'ivorycoast', 'republicofserbia': 'serbia', 'demrepcongo': 'drcongo'}
    gfp = []
    for row in read_asset('power_index.json'):
        key = normal(country_names.get(row['iso_a3'], row['iso_a3']))
        val = indices.get(aliases.get(key, key))
        gfp.append({'iso_a3': row['iso_a3'], 'name': country_names.get(row['iso_a3']), 'local': row['PwrIndx'], 'official_2026': val,
                    'status': 'unmatched_name_or_not_in_source' if val is None else 'same' if val == row['PwrIndx'] else 'changed'})
    result['globalfirepower'] = {'summary': dict(collections.Counter(r['status'] for r in gfp)), 'comparisons': gfp}

    stats_rows = read_asset('cities.json')
    # Exactly reproduce the Dart map semantics: last city with the same name wins.
    stats = {r['name']: r for r in stats_rows}
    result['city_merge'] = {}
    for label, base in [('bundled', read_asset('cities15000.json')),
                        ('remote', json.loads((SOURCES / 'remote_cities15000.json').read_text(encoding='utf8')))]:
        groups = collections.defaultdict(list)
        for row in base:
            groups[row['name']].append(row)
        collisions = []
        for name, row in stats.items():
            if name not in groups:
                continue
            selected = max(groups[name], key=lambda r: r['population'])
            if selected['country_code'] != row['country_iso']:
                collisions.append({'name': name, 'stats_country': row['country_iso'], 'chosen_map_country': selected['country_code'],
                                   'chosen_map_population': selected['population'], 'stats_population': row['population'],
                                   'chosen_coordinates': [selected['latitude'], selected['longitude']]})
        unique = {json.dumps(r, sort_keys=True) for r in base}
        result['city_merge'][label] = {'rows': len(base), 'exact_duplicate_extra_rows': len(base) - len(unique),
                                      'wrong_country_or_missing_code': collisions,
                                      'stats_names_without_base_match': sorted(set(stats) - set(groups))}

    landmarks = read_asset('all_landmarks.json')
    by_name = collections.defaultdict(list)
    for row in landmarks:
        by_name[row['name']].append(row)
    result['landmarks'] = {
        'duplicate_names': {k: [{'countries': r['countriesIsoA3'], 'latitude': r.get('latitude'), 'longitude': r.get('longitude')} for r in v]
                            for k, v in by_name.items() if len(v) > 1},
        'missing_coordinates': [r['name'] for r in landmarks if r.get('latitude') is None or r.get('longitude') is None],
        'global_rank_missing_names': [r['name'] for r in read_asset('global_rank.json') if r['name'] not in by_name],
        'local_rank_missing_names': [{'country': group['country'], 'name': r['name']} for group in read_asset('local_rank.json') for r in group['items'] if r['name'] not in by_name],
        'city_rank_missing_names': [{'city': city, 'name': name} for city, names in read_asset('city_rank.json').items() for name in names if name not in by_name],
    }
    result['hardcoded_measurement_rankings'] = {}
    for path in (ROOT / 'lib/screens').glob('top_*screen.dart'):
        rows = []
        for number, line in enumerate(path.read_text(encoding='utf8').splitlines(), 1):
            match = re.search(r"'rank':\s*(\d+).*?'name':\s*'((?:\\.|[^'])*)'.*?'(height|length|area)':\s*'([^']+)'", line)
            if match:
                rank, name, metric, display = match.groups()
                name = name.replace("\\'", "'")
                rows.append({'rank': int(rank), 'name': name, 'line': number, 'metric': metric, 'display': display,
                             'numeric_value': float(re.sub(r'[^0-9.]', '', display))})
        if rows:
            result['hardcoded_measurement_rankings'][path.name] = {
                'records': len(rows),
                'descending_order_violations': [{'earlier': a, 'later': b} for a, b in zip(rows, rows[1:]) if a['numeric_value'] < b['numeric_value']],
                'names_not_in_landmarks': [r['name'] for r in rows if r['name'] not in by_name],
            }
    # Capital group names with numeric latitude contradictions.
    city_stats = read_asset('city_stats.json')
    tropic = []
    for row in city_stats['capitals_on_tropic_of_cancer']:
        city = stats.get(row['city'])
        if city:
            tropic.append({'city': row['city'], 'latitude': city['latitude'], 'distance_from_23_436_degrees_km': round(abs(city['latitude'] - 23.436) * 111, 1)})
    result['tropic_of_cancer_capitals'] = tropic
    (OUT / 'source_and_logic_checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print('HDI matches', sum(r['matches_at_3dp'] is True for r in result['hdi']))
    for key in ['skytrax_airlines', 'skytrax_airports', 'globalfirepower']:
        print(key, result[key]['summary'])
    print('City collision counts', {k: len(v['wrong_country_or_missing_code']) for k, v in result['city_merge'].items()})
    print('Landmark missing rank references', {k: len(v) for k, v in result['landmarks'].items()})


if __name__ == '__main__':
    main()
