"""Compare every matching country row with public World Bank observations.

Differences flag review, not automatic corrections: years, definitions and
national/territorial coverage must be reconciled before updating app data.
Never changes app assets. Keeps downloaded source snapshots for reproduction.
"""
from statistics_schema import decode_statistics
import concurrent.futures
import csv
import datetime
import json
import pathlib
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit'
SPECS = [
    ('population', 'SP.POP.TOTL', 'updated_country_populations.json', None, 'population_est', 1),
    ('fertility', 'SP.DYN.TFRT.IN', 'fertility_rate.json', None, 'fertility_rate', 1),
    ('life_expectancy', 'SP.DYN.LE00.IN', 'life_expectancy.json', None, 'life_expectancy', 1),
    ('homicide', 'VC.IHR.PSRC.P5', 'homicide_rate.json', None, 'homicide_rate', 1),
    ('gini', 'SI.POV.GINI', 'gini_data.json', None, 'gini_index', 1),
    ('military_gdp_pct', 'MS.MIL.XPND.GD.ZS', 'military_expenditure.json', None, 'military_expenditure', 1),
    ('armed_forces', 'MS.MIL.TOTL.P1', 'armed_forces.json', None, 'armed_forces_personnel_total', 1),
    ('immigrant_pct', 'SM.POP.TOTL.ZS', 'immigration_rate.json', None, 'immigrant_rate', 1),
    ('gdp_nominal', 'NY.GDP.MKTP.CD', 'economy_data.json', None, 'gdp_nominal', 1e9),
    ('gdp_ppp', 'NY.GDP.MKTP.PP.CD', 'economy_data.json', None, 'gdp_ppp', 1e9),
    ('internet_penetration', 'IT.NET.USER.ZS', 'technology.json', 'internet_users_penetration_pct', 'internet_users_pct', 1),
    ('hospital_beds', 'SH.MED.BEDS.ZS', 'health.json', 'hospital_beds_per_1k', 'value', 1),
    ('hiv_prevalence', 'SH.DYN.AIDS.ZS', 'health.json', 'hiv_prevalence_percent', 'value', 1),
    ('alcohol', 'SH.ALC.PCAP.LI', 'health.json', 'alcohol_consumption_2019', 'alcohol_consumption_liters', 1),
    ('land_area_km2', 'AG.LND.TOTL.K2', 'area_data.json', None, 'area', 1),
    ('surface_area_km2', 'AG.SRF.TOTL.K2', 'area_data.json', None, 'area', 1),
]


def fetch(spec):
    label, indicator, filename, section, field, scale = spec
    url = f'https://api.worldbank.org/v2/country/all/indicator/{indicator}?format=json&date=2000:2025&per_page=20000'
    dest = OUT / 'sources' / f'worldbank_{indicator}.json'
    if dest.exists():
        raw = dest.read_bytes()
    else:
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url, timeout=55) as response:
                    raw = response.read()
                parsed = json.loads(raw)
                if not isinstance(parsed, list) or len(parsed) < 2 or not isinstance(parsed[1], list):
                    raise ValueError(str(parsed)[:250])
                dest.write_bytes(raw)
                break
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(1 + attempt)
    response = json.loads(raw)
    if response[0]['pages'] != 1:
        raise ValueError('Unexpected pagination')
    rows = response[1]
    by_country = {}
    for row in rows:
        if row['value'] is not None:
            by_country.setdefault(row['countryiso3code'], []).append(row)
    local = decode_statistics(json.loads((ROOT / 'assets' / filename).read_text(encoding='utf-8-sig')))
    if section:
        local = local[section]
    results = []
    for position, row in enumerate(local):
        if field not in row:
            results.append({'metric': label, 'asset': filename, 'row': position + 1, 'iso_a3': row.get('iso_a3'), 'status': 'local_field_missing', 'source_url': url})
            continue
        iso = row['iso_a3']
        observations = by_country.get('XKX' if iso == 'KOS' else iso, [])
        latest = max(observations, key=lambda r: int(r['date'])) if observations else None
        val = row[field] * scale
        entry = {'metric': label, 'asset': filename, 'row': position + 1, 'iso_a3': iso, 'local_value': val, 'source_url': url}
        if latest:
            ref = latest['value']
            diff = val - ref
            digits = {'fertility': 2, 'life_expectancy': 1, 'homicide': 3,
                      'gini': 1, 'military_gdp_pct': 1, 'immigrant_pct': 1,
                      'internet_penetration': 0, 'hospital_beds': 1,
                      'hiv_prevalence': 1, 'alcohol': 1}.get(label)
            tolerance = 0.5 * 10 ** -digits + 1e-9 if digits is not None else max(abs(ref) * 0.001, 0.0001)
            entry.update(latest_year=latest['date'], latest_value=ref, absolute_difference=diff,
                         difference_pct=round(diff / abs(ref) * 100, 4) if ref else None,
                         comparison_tolerance=tolerance,
                         status='matches_within_rounding_or_0.1pct' if abs(diff) <= tolerance else 'review_difference',
                         closest_historical_year=min(observations, key=lambda r: abs(r['value'] - val))['date'])
        else:
            entry['status'] = 'no_worldbank_observation'
        results.append(entry)
    return label, results, {'metric': label, 'indicator': indicator, 'source_url': url, 'source_lastupdated': response[0].get('lastupdated'),
                            'local_rows': len(local), 'compared': sum('latest_value' in r for r in results),
                            'review_differences': sum(r['status'] == 'review_difference' for r in results)}


def main():
    (OUT / 'sources').mkdir(parents=True, exist_ok=True)
    all_rows, summaries, errors = [], [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(fetch, spec): spec[0] for spec in SPECS}
        for future in concurrent.futures.as_completed(futures):
            label = futures[future]
            try:
                _, rows, summary = future.result()
                all_rows.extend(rows)
                summaries.append(summary)
                print(json.dumps(summary), flush=True)
            except Exception as error:
                errors.append({'metric': label, 'error': str(error)})
                print(label, str(error), flush=True)
    all_rows.sort(key=lambda r: (r['metric'], r['iso_a3'], r['row']))
    artifact = {'audit_date': '2026-10-17', 'retrieved_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'interpretation': 'Review candidates only. Local reference dates and definitions are missing. GDP may be IMF forecasts; area may be surface/land area. Observations published after the audit date must be excluded from audit conclusions.',
                'summaries': sorted(summaries, key=lambda x: x['metric']), 'errors': errors, 'comparisons': all_rows}
    (OUT / 'worldbank_comparison.json').write_text(json.dumps(artifact, ensure_ascii=False, indent=2), encoding='utf8')
    fields = ['metric', 'asset', 'row', 'iso_a3', 'local_value', 'latest_year', 'latest_value', 'absolute_difference', 'difference_pct', 'comparison_tolerance', 'status', 'closest_historical_year', 'source_url']
    with (OUT / 'worldbank_comparison.csv').open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(all_rows)
    print('TOTAL', len(all_rows), 'ERRORS', len(errors))


if __name__ == '__main__':
    main()
