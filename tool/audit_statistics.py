"""Read-only audit of bundled statistics; writes audit artifacts only.

Run: python tool/audit_statistics.py
External source verification is recorded separately in audit/statistics_findings.md.
"""
from statistics_schema import decode_statistics
import collections
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit'


def audit():
    OUT.mkdir(exist_ok=True)
    dart = {str(p.relative_to(ROOT)).replace('\\', '/'): p.read_text(encoding='utf-8-sig')
            for p in (ROOT / 'lib').rglob('*.dart')}
    geo = json.loads((ROOT / 'assets/custom.geo.json').read_text(encoding='utf-8-sig'))
    countries = {f['properties'].get('iso_a3_eh') or f['properties'].get('iso_a3'): f['properties']['name']
                 for f in geo['features']}
    inventory, checks, hashes = [], [], collections.defaultdict(list)

    def walk(value, path, issues):
        if isinstance(value, list):
            for key in ('iso_a3', 'iso_a2', 'name', 'rank', 'iata_code'):
                vals = [r[key] for r in value if isinstance(r, dict) and key in r]
                dup = {str(k): v for k, v in collections.Counter(vals).items() if v > 1}
                if dup:
                    issues.append({'path': path, 'check': 'duplicate_' + key, 'values': dup})
            for i, row in enumerate(value):
                walk(row, f'{path}[{i}]', issues)
        elif isinstance(value, dict):
            for k, v in value.items():
                if isinstance(v, (int, float)) and not isinstance(v, bool):
                    invalid = ((k in ('latitude', 'lat', 'centroid_lat', 'north_lat', 'south_lat', 'capital_lat') and abs(v) > 90)
                               or (k in ('longitude', 'lon', 'lng', 'centroid_lon') and abs(v) > 180)
                               or (k == 'hdi' and not 0 <= v <= 1)
                               or (k == 'democracy' and not 0 <= v <= 10)
                               or (k in ('population', 'population_est', 'gdp_nominal', 'gdp_ppp') and v < 0))
                    if invalid:
                        issues.append({'path': path + '.' + k, 'check': 'out_of_range', 'value': v})
                walk(v, path + '.' + k, issues)

    for p in sorted((ROOT / 'assets').glob('*.json')):
        rel = 'assets/' + p.name
        refs = sorted(k for k, v in dart.items() if rel in v)
        item = {'file': rel, 'bytes': p.stat().st_size, 'references': refs}
        try:
            raw = p.read_text(encoding='utf-8-sig')
            data = decode_statistics(json.loads(raw))
            hashes[hashlib.sha256(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()].append(rel)
            item.update(kind=type(data).__name__, records=len(data),
                        fields=sorted({k for r in data if isinstance(r, dict) for k in r}) if isinstance(data, list) else list(data))
            item['year_hints'] = sorted(set(re.findall(r'(?<!\d)(?:19|20)\d{2}(?!\d)', ' '.join(item['fields']))))
            item['metadata_fields'] = [k for k in item['fields'] if re.search('source|updated|as_of|year|method|unit|date', k, re.I)]
            if isinstance(data, dict):
                item['sections'] = {k: {'records': len(v), 'fields': sorted({f for r in v if isinstance(r, dict) for f in r})}
                                    for k, v in data.items() if isinstance(v, list)}
            if isinstance(data, list) and any(isinstance(r, dict) and 'iso_a3' in r for r in data):
                codes = {r['iso_a3'] for r in data if isinstance(r, dict) and 'iso_a3' in r}
                item['missing_map_countries'] = sorted(set(countries) - codes)
                item['codes_not_in_map'] = sorted(codes - set(countries))
            walk(data, rel, checks)
        except Exception as e:
            item['parse_error'] = str(e)
        inventory.append(item)
    result = {'audit_date': '2026-10-17', 'scope': 'Bundled JSON and Dart asset references; external values require source verification.',
              'map_features': len(geo['features']), 'map_country_codes': countries,
              'inventory': inventory, 'structural_checks': checks,
              'identical_datasets': [v for v in hashes.values() if len(v) > 1]}
    (OUT / 'statistics_inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    lines = ['# 통계 데이터 전수 목록', '', '검토 기준: 2026-10-17. 참조 없음은 lib 내 직접 문자열 참조가 없다는 뜻이며, 동적 경로는 별도 확인이 필요합니다.', '',
             '| 파일 | 레코드/섹션 | 직접 참조 Dart 수 | 연도 힌트 | 메타데이터 필드 |', '|---|---:|---:|---|---|']
    for row in inventory:
        lines.append(f"| {row['file']} | {row.get('records', '파싱 오류')} | {len(row['references'])} | {', '.join(row.get('year_hints', [])) or '없음'} | {', '.join(row.get('metadata_fields', [])) or '없음'} |")
    lines += ['', '## 동일한 데이터', *['- ' + ', '.join(v) for v in result['identical_datasets']], '', '## 구조 검사 경고', '']
    for check in checks:
        brief = dict(check)
        if 'values' in brief:
            brief['duplicate_keys'] = len(brief['values'])
            brief['values'] = dict(list(brief['values'].items())[:20])
        lines.append('- ' + json.dumps(brief, ensure_ascii=False))
    (OUT / 'statistics_inventory.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps({'files': len(inventory), 'parse_errors': [r['file'] for r in inventory if 'parse_error' in r],
                      'structural_warnings': len(checks), 'identical_datasets': result['identical_datasets']}, ensure_ascii=False))


if __name__ == '__main__':
    audit()
