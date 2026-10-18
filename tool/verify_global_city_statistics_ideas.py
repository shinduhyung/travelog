"""Verify worldwide city ideas against saved primary-source numerical data.

No network requests. Reject duplicate city IDs with conflicting values, missing/
censored values, fewer than ten distinct non-European cities or numeric values,
or coverage confined to fewer than three non-European UN regions. Numbeo has no
region column: verify three named non-European countries instead.
"""
import collections
import csv
import gzip
from html.parser import HTMLParser
import io
import json
import math
from pathlib import Path
import re
import zipfile

from verify_city_statistics_ideas import GLOBAL_CANDIDATES

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'audit/city_statistics_ideas_sources'
JRC_URL = 'https://human-settlement.emergency.copernicus.eu/ucdb2024Overview.php'
CANDIDATES = [line.split('|') for line in GLOBAL_CANDIDATES.strip().splitlines()]


def add(theme, code, year, label):
    CANDIDATES.append([theme, code, str(year), label])


for code, label in [('TOT', '전체 건축물 바닥 점유 면적'), ('RES', '주거용 건축물 바닥 점유 면적'),
                    ('NRE', '비주거용 건축물 바닥 점유 면적')]:
    add('GHSL', f'GH_BUS_{code}_2025', 2025, label)
    add('GHSL', f'GH_BPC_{code}_2025', 2025, '주민 1명당 ' + label)
    add('GHSL', f'GH_BUV_{code}_2025', 2025, label.replace('바닥 점유 면적', '부피'))
add('GHSL', 'GH_BUH_AVG_2020', 2020, '평균 건물 높이')
add('GHSL', 'GH_AGE_S75_2025', 2025, '1975년 이전 개발된 시가지 비율')
add('GHSL', 'GH_AGE_S25_2025', 2025, '2015~2025년 새로 개발된 시가지 비율')
for code, label in [('11', '1~2층 주거 건물이 우세한 구역'), ('12', '3~7층 주거 건물이 우세한 구역'),
                    ('13', '고층 주거 건물이 우세한 구역'), ('21', '1~2층 비주거 건물이 우세한 구역'),
                    ('22', '3~7층 비주거 건물이 우세한 구역'), ('23', '고층 비주거 건물이 우세한 구역')]:
    add('GHSL', f'GH_BUT_P{code}_2020', 2020, label + ' 거주 인구')
    add('GHSL', f'GH_BUT_S{code}_2020', 2020, label + ' 건축물 점유 면적')

for code, label in [('ALL', '종합'), ('ENE', '에너지'), ('TRA', '교통'), ('WAT', '상수도'),
                    ('WAS', '폐기물'), ('TEL', '통신'), ('HEA', '의료'), ('EDU', '교육')]:
    add('INFRASTRUCTURES', f'IN_CIS_{code}_2020', 2020, label + ' 핵심 기반시설 분포 지수·CISI')
for code, label in [('HOS', '병원'), ('PHA', '약국')]:
    for prefix, year, name in [('FCL', 2024, 'OSM 등록 {} 수'), ('FDE', 2024, '㎢당 OSM 등록 {} 수'),
                               ('FPC', 2025, '인구 100만 명당 OSM 등록 {} 수'),
                               ('POP', 2025, 'OSM 등록 {} 1km 이내 거주 인구'),
                               ('SHP', 2025, 'OSM 등록 {} 1km 이내 거주 인구 비율')]:
        add('HEALTH', f'HL_{prefix}_{code}_{year}', year, name.format(label))
for code, label in [('DSF', '유선 인터넷 평균 다운로드 속도'), ('DSM', '모바일 인터넷 평균 다운로드 속도'),
                    ('USF', '유선 인터넷 평균 업로드 속도'), ('USM', '모바일 인터넷 평균 업로드 속도'),
                    ('ALF', '유선 인터넷 평균 지연시간'), ('ALM', '모바일 인터넷 평균 지연시간')]:
    add('SOCIOECONOMIC', f'SC_CON_{code}_2023', 2023, label)
for code, label in [('PCF', '여성 인구 비율'), ('PCY', '유소년 인구 비율'),
                    ('PCA', '생산연령 인구 비율'), ('PCO', '고령 인구 비율')]:
    add('SOCIOECONOMIC', f'SC_SEC_{code}_2020', 2020, label + '·WorldPop 격자 추정')

for code, year, label in [('CL_B04_CUR_2010', '2010년대', '기온의 계절 변동성'),
                          ('CL_B07_CUR_2010', '2010년대', '연중 최고·최저 월 기온 범위'),
                          ('CL_REN_PVO_2020', '2020 참조', '일평균 태양광 발전 잠재량'),
                          ('CL_REN_W01_2020', '2020 참조', '지상 10m 평균 풍속'),
                          ('CL_REN_W10_2020', '2020 참조', '지상 100m 평균 풍속'),
                          ('CL_UTC_T32_2020', '2020 참조', '연평균 강한 열 스트레스 발생 일수·UTCI 32℃ 초과'),
                          ('CL_WDS_CUR_2010', '2010년대', '기준기간 상위 10% 고온 기준을 넘는 날의 비율')]:
    add('CLIMATE', code, year, label)
for n, label in enumerate(['밀집 고층', '밀집 중층', '밀집 저층', '개방형 고층', '개방형 중층',
                           '개방형 저층', '경량 저층', '대형 저층', '건물 희박', '중공업',
                           '울창한 수목', '흩어진 수목', '관목', '낮은 식생', '암반·포장', '나지·모래', '수역'], 1):
    add('CLIMATE', f'CL_LCZ_A{n:02d}_2025', 2025, label + ' 지역 비율·LCZ 분류')

for code, label in [('020', '관목지'), ('030', '초본 식생'), ('040', '농경지'), ('050', '인공 구조물 토지'),
                    ('060', '나지·희박 식생'), ('070', '눈·얼음'), ('080', '상시 수역'),
                    ('090', '초본 습지'), ('100', '이끼·지의류')]:
    add('LULC', f'LU_HEC_{code}_2019', 2019, '도시권 내 ' + label + ' 면적')
for codes, label in [([111, 112, 113, 114, 115, 116, 121, 122, 123, 124, 125, 126], '산림'),
                      ([111, 112, 121, 122], '상록수림'), ([113, 114, 123, 124], '낙엽수림'),
                      ([115, 125], '혼합림')]:
    add('LULC', '+'.join(f'LU_HEC_{x}_2019' for x in codes), 2019, '도시권 내 ' + label + ' 면적')

for code, label in [('010', '10년 재현기간 하천 홍수'), ('100', '100년 재현기간 하천 홍수')]:
    for suffix, name in [('POP', '노출 추정 인구'), ('BUS', '노출 건축물 점유 면적'), ('SHB', '노출 건축물 비율')]:
        add('EXPOSURE', f'EX_{code}_{suffix}_2025', 2025, label + ' ' + name)
for code, label in [('SHA_POP', '진도 MMI 6 이상 지진 위험구역 인구 비율'),
                    ('SHA_BUS', '진도 MMI 6 이상 지진 위험구역 건축물 비율'),
                    ('SHA_NRE', '진도 MMI 6 이상 지진 위험구역 비주거 건축물 비율'),
                    ('L05_POP', '해발 5m 미만 해안 저지대 인구'), ('L10_POP', '해발 5~10m 해안 저지대 인구'),
                    ('L05_SHP', '해발 5m 미만 해안 저지대 인구 비율'),
                    ('LEC_SHP', '해발 10m 미만 해안 저지대 인구 비율'),
                    ('LEC_SHB', '해발 10m 미만 해안 저지대 건축물 비율')]:
    add('EXPOSURE', f'EX_{code}_2025', 2025, label)
for code, label in [('020_S1', '20년 재현기간 열대저기압 1~2등급 강풍'),
                    ('100_S1', '100년 재현기간 열대저기압 1~2등급 강풍'),
                    ('400_S3', '400년 재현기간 열대저기압 3~5등급 강풍')]:
    for suffix, name in [('P', '노출 추정 인구'), ('B', '노출 건축물 점유 면적')]:
        add('EXPOSURE', f'EX_{code}{suffix}_2025', 2025, label + ' ' + name)
for code, label in [('CF2', '20년 재현기간 해안 홍수'), ('CF1', '100년 재현기간 해안 홍수')]:
    for suffix, name in [('POP', '노출 추정 인구'), ('SHP', '노출 인구 비율'), ('BUS', '노출 건축물 점유 면적'),
                         ('SHB', '노출 건축물 비율')]:
        add('EXPOSURE', f'EX_{code}_{suffix}_2025', 2025, label + ' ' + name)

for gas, label in [('CO2', 'CO₂'), ('GHG', '온실가스'), ('NOX', '질소산화물'), ('PM2', '초미세먼지')]:
    add('EMISSIONS', f'EM_{gas}_TOT_2024', 2024, label + ' 총 배출량·격자 추정')
    add('EMISSIONS', f'EM_{gas}_PEC_2020', 2020, '1인당 ' + label + ' 배출량·격자 추정')
    sectors = [('AGR', '농업'), ('ENE', '에너지'), ('IND', '산업'), ('RES', '주거'), ('TRA', '교통')]
    if gas != 'PM2':
        sectors.append(('WAS', '폐기물'))
    for code, sector in sectors:
        add('EMISSIONS', f'EM_{gas}_{code}_2024', 2024, sector + ' 부문 ' + label + ' 배출량·격자 추정')


def number(value):
    try:
        value = float(value.replace(',', '')) if isinstance(value, str) else float(value)
        return value if math.isfinite(value) else None
    except (ValueError, TypeError):
        return None


def csv_stream(theme):
    compressed = RAW / f'ghsl_{theme}.csv.gz'
    if compressed.exists():
        stream = gzip.open(compressed, 'rb')
        return io.TextIOWrapper(stream, encoding='utf-8-sig' if stream.peek(3).startswith(b'\xef\xbb\xbf') else 'cp1252')
    archive = zipfile.ZipFile(RAW / f'ghsl_{theme}.zip')
    member = next(n for n in archive.namelist() if n.endswith('.csv'))
    stream = archive.open(member)
    return io.TextIOWrapper(stream, encoding='utf-8-sig' if stream.peek(3).startswith(b'\xef\xbb\xbf') else 'cp1252')


def outcome(label, period, points, source, **meta):
    assert len({p['id'] for p in points}) == len(points), 'duplicate city ID'
    outside = [x for x in points if x['non_europe']]
    values = {x['value'] for x in outside}
    regions = sorted({x['region'] for x in outside})
    countries = sorted({x['country'] for x in outside})
    ok = len(outside) >= 10 and len(values) >= 10 and len(regions) >= 3
    return {'accepted': ok, 'label': label, 'period': period, 'city_count': len(points),
            'non_europe_city_count': len(outside), 'distinct_non_europe_values': len(values),
            'non_europe_regions': regions, 'non_europe_countries': countries,
            'source_url': source, 'samples': outside[:12], **meta}


class Table(HTMLParser):
    def __init__(self):
        super().__init__(); self.active = False; self.cell = None; self.rows = []; self.row = []

    def handle_starttag(self, tag, attrs):
        if tag == 'table' and dict(attrs).get('id') == 't2': self.active = True
        if self.active and tag == 'tr': self.row = []
        if self.active and tag in ('td', 'th'): self.cell = []

    def handle_data(self, text):
        if self.cell is not None: self.cell.append(text)

    def handle_endtag(self, tag):
        if self.active and tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split())); self.cell = None
        if self.active and tag == 'tr' and self.row: self.rows.append(self.row)
        if self.active and tag == 'table': self.active = False


def unwrap(value):
    if isinstance(value, dict): return {k: unwrap(v) for k, v in value.items()}
    if isinstance(value, list) and len(value) == 2 and isinstance(value[0], int):
        if value[0] == 1: return [unwrap(x) for x in value[1]]
        return unwrap(value[1])
    return value


def main():
    results = []
    by_theme = collections.defaultdict(list)
    for theme, expression, period, label in CANDIDATES:
        by_theme[theme].append((expression, period, label))
    for theme, candidates in by_theme.items():
        data = [{} for _ in candidates]; conflicts = [set() for _ in candidates]
        with csv_stream(theme) as stream:
            reader = csv.DictReader(stream)
            for row in reader:
                city = row['ID_UC_G0']
                for i, (expression, _, _) in enumerate(candidates):
                    fields = re.split(r'[+-]', expression)
                    parts = [number(row.get(f)) for f in fields]
                    if any(v is None for v in parts): continue
                    value = parts[0]
                    for sign, part in zip(re.findall(r'[+-]', expression), parts[1:]):
                        value += part if sign == '+' else -part
                    # Metadata says /million, while CSV stores facilities/person.
                    # Verify the scale against counts/population rather than
                    # repeating the inconsistent published unit literally.
                    if expression.startswith('HL_FPC_'):
                        facility = expression.split('_')[2]
                        count = number(row.get(f'HL_FCL_{facility}_2024'))
                        population = number(row.get('GC_POP_TOT_2025'))
                        if count is None or population is None or population <= 0: continue
                        if not math.isclose(value, count / population, rel_tol=0.025, abs_tol=1e-9):
                            continue
                        value *= 1_000_000
                    point = {'id': city, 'name': row['GC_UCN_MAI_2025'], 'value': value,
                             'country': row['GC_CNT_GAD_2025'], 'region': row['GC_DEV_USR_2025'],
                             'non_europe': bool(row['GC_DEV_USR_2025']) and 'Europe' not in row['GC_DEV_USR_2025']}
                    if city in data[i] and data[i][city]['value'] != value: conflicts[i].add(city)
                    data[i][city] = point
        for i, (expression, period, label) in enumerate(candidates):
            points = [p for k, p in data[i].items() if k not in conflicts[i]]
            results.append(outcome(label, period, points, JRC_URL, theme=theme, expression=expression,
                                   conflicting_city_ids_excluded=sorted(conflicts[i]), source_kind='JRC Urban Centre'))
        print(theme, len(candidates), flush=True)

    numbeo = {
        'cost': {2: '생활비 지수', 3: '주거 임대료 지수', 4: '임대료 포함 생활비 지수',
                 5: '식료품 물가 지수', 6: '외식 물가 지수', 7: '지역 구매력 지수'},
        'property': {2: '주택가격 대비 소득 배율', 3: '도심 임대수익률', 4: '외곽 임대수익률',
                     5: '도심 주택가격 대비 연 임대료 배율', 6: '외곽 주택가격 대비 연 임대료 배율',
                     7: '소득 대비 주택담보대출 상환액 비율', 8: '주택 구매 여력 지수'},
        'quality': {2: '삶의 질 종합 지수', 10: '기후 쾌적성 지수'},
        'health': {2: '의료서비스 지수'},
        'traffic': {2: '교통 종합 지수', 5: '통근 교통 비효율 지수', 6: '통근 CO₂ 배출 지수'},
    }
    paths = {'cost':'cost-of-living','property':'property-investment','quality':'quality-of-life',
             'health':'health-care','traffic':'traffic'}
    # Positive whitelist avoids treating European places as non-European due to
    # alternative spellings (e.g. Czechia/Czech Republic). This is a lower bound.
    outside_countries = {'United States', 'Canada', 'Mexico', 'Brazil', 'Argentina', 'Chile', 'Colombia',
        'Peru', 'Australia', 'New Zealand', 'Japan', 'South Korea', 'China', 'India', 'Thailand',
        'Indonesia', 'Vietnam', 'Malaysia', 'Philippines', 'Singapore', 'Taiwan', 'Pakistan',
        'Bangladesh', 'United Arab Emirates', 'Qatar', 'Saudi Arabia', 'Kuwait', 'Oman', 'Israel',
        'South Africa', 'Egypt', 'Morocco', 'Kenya', 'Nigeria', 'Bahrain'}
    for dataset, indicators in numbeo.items():
        table = Table(); table.feed((RAW / f'numbeo_{dataset}_2026.html').read_text(encoding='utf-8'))
        for col, label in indicators.items():
            points = {}
            for row in table.rows[1:]:
                if len(row) <= col: continue
                value = number(row[col])
                if value is None: continue
                city = row[1]; country = city.rsplit(', ', 1)[-1]
                points[city] = {'id': city, 'name': city, 'country': country, 'region': country,
                                'value': value, 'non_europe': country in outside_countries}
            results.append(outcome('Numbeo ' + label, '2026', list(points.values()),
                f'https://www.numbeo.com/{paths[dataset]}/rankings.jsp?title=2026',
                source_kind='Numbeo crowdsourced', expression=table.rows[0][col], theme='NUMBEO',
                non_europe_count_is_lower_bound=True))

    tomtom = unwrap(json.loads((RAW / 'tomtom_props.json').read_text(encoding='utf-8')))['rankingData']['center']
    for field, label in [('c', '평균 교통 혼잡도'), ('cDelta', '전년 대비 교통 혼잡도 변화'),
                          ('v', '평균 주행 속도'), ('d15', '15분간 주행 가능한 거리'),
                          ('tLostRush', '출퇴근 시간대 연간 교통 지체 손실시간')]:
        points = [{'id': r['key'], 'name': r['name'], 'country': r['countryName'],
                   'region': r['continent'], 'non_europe': r['continent'] != 'europe', 'value': number(r[field])}
                  for r in tomtom if number(r.get(field)) is not None]
        results.append(outcome('TomTom ' + label, '2025', points,
            'https://www.tomtom.com/traffic-index/ranking/', theme='TOMTOM', expression=field,
            source_kind='TomTom city center'))

    accepted = [r for r in results if r['accepted']]; rejected = [r for r in results if not r['accepted']]
    previous = {(t, e) for t, e, _, _ in (line.split('|') for line in GLOBAL_CANDIDATES.strip().splitlines())}
    for record in accepted:
        record['previously_proposed'] = (record['theme'], record['expression']) in previous
    new = [r for r in accepted if not r['previously_proposed']]
    out = {'verified_at':'2026-10-17', 'criteria':'same period; >=10 non-European unique city IDs and distinct finite values; >=3 non-European UN regions (Numbeo: >=3 countries)',
           'accepted_count':len(accepted), 'new_count':len(new), 'rejected_count':len(rejected), 'accepted':accepted, 'rejected':rejected,
           'excluded_sources':{'Eurostat':'Europe-only', 'Oxford':'Public numerical JSON inaccessible (403); unverified',
                               'StartupBlink':'Public page inaccessible (403); unverified',
                               'Numbeo individual prices':'Public price page rate limited (429); unverified'},
           'scope_notes':['JRC urban centres are harmonized settlement boundaries, not administrative cities.',
             'HEALTH HL_FPC CSV stores facilities/person despite PDF saying /million. Values are multiplied by 1,000,000 only after verifying against facility count / population within 2.5% rounding tolerance.',
             'JRC thematic periods can refer to modelled/estimated data or older source layers; not every 2025 field is a fresh direct observation.',
             'No socioeconomic HDI/life expectancy/schooling copied from larger administrative regions is proposed.',
             'Numbeo is crowdsourced; reported coverage is source cities, not matched app cities.',
             'TomTom uses city-center observations only; metro rows are not mixed in.',
             'A maximum 10m coastal zone is distinct from the separate 5–10m band.',
             'Missing/censored observations and conflicting duplicate city values are excluded.']}
    (ROOT/'audit/global_city_statistics_ideas_verified.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
    lines = ['# 유럽 전용을 제외한 도시 통계 후보', '', f'검증일: 2026-10-17 / 통과 {len(accepted)}개 / 미통과 {len(rejected)}개', '',
             '각 항목: 동일 기준기간의 유럽 밖 도시 10곳 이상, 서로 다른 수치 10개 이상. 도시명과 원본 지표 ID·표본 수치는 JSON에 보관.', '',
             'JRC는 행정시가 아닌 도시 중심지 경계이며 추정·모델·과거 자료를 포함한다. Numbeo는 이용자 제출 자료다. 도시 수는 원자료 기준으로 앱에 매칭 가능한 도시 수와 다르다.', '']
    last = None
    for r in accepted:
        if r['theme'] != last:
            last=r['theme']; lines.extend(['', f'## {last}', ''])
        lines.append(f"- [ ] {r['label']} — {r['period']} / 전체 {r['city_count']:,}곳, 유럽 밖 {r['non_europe_city_count']:,}곳 / [원자료]({r['source_url']})")
    lines.extend(['', '## 검증에서 제외', ''])
    for r in rejected: lines.append(f"- {r['label']} — 유럽 밖 도시 {r['non_europe_city_count']}곳 / 고유 수치 {r['distinct_non_europe_values']}개")
    (ROOT/'audit/global_city_statistics_ideas_checklist.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    new_lines = ['# 신규 세계 도시 통계 후보', '', f'신규 {len(new)}개 / 검증일 2026-10-17', '', *lines[4:8]]
    last = None
    for r in new:
        if r['theme'] != last:
            last=r['theme']; new_lines.extend(['', f'## {last}', ''])
        new_lines.append(f"- [ ] {r['label']} — {r['period']} / 전체 {r['city_count']:,}곳, 유럽 밖 {r['non_europe_city_count']:,}곳 / [원자료]({r['source_url']})")
    (ROOT/'audit/global_city_statistics_ideas_new_checklist.md').write_text('\n'.join(new_lines)+'\n',encoding='utf-8')
    print(json.dumps({'accepted':len(accepted),'rejected':[(r['label'],r['city_count']) for r in rejected],
                      'themes':dict(collections.Counter(r['theme'] for r in accepted))},ensure_ascii=False))


if __name__ == '__main__':
    main()
