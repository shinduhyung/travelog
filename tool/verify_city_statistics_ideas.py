"""Offline coverage verification of downloaded Eurostat and JRC city data."""
import collections
import csv
import io
import json
import math
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'audit/city_statistics_ideas_sources'
EU_CANDIDATES = '''
urb_ctour|CR1008V|극장 수
urb_ctour|CR1010V|공공도서관 수
urb_ctour|CR1015V|공공 수영장 수
urb_ctour|CR1003V|영화관 총 좌석 수
urb_ctour|CR1003I|주민 1천 명당 영화관 좌석 수
urb_ctour|CR1005V|연간 영화관 관람 횟수
urb_ctour|CR1007V|연간 박물관 방문 횟수
urb_ctour|CR2001V|관광숙박시설 총 숙박일수
urb_ctour|CR2010V|자국 거주자의 관광숙박일수
urb_ctour|CR2011V|비거주자의 관광숙박일수
urb_ctour|CR2009V|관광숙박시설 침대 수
urb_ctour|CR2010I|주민 1천 명당 관광숙박시설 침대 수
urb_ctour|CR2011I|주민 1명당 관광숙박일수
urb_ctran|TT1079V|자전거 전용도로·차로 길이
urb_ctran|TT1080V|도심 대중교통 통합 월 정기권 가격
urb_ctran|TT1081V|도심행 주간 택시 5km 요금
urb_ctran|TT1003V|자가용 통근 비율
urb_ctran|TT1010V|대중교통 통근 비율
urb_ctran|TT1006V|오토바이 통근 비율
urb_ctran|TT1007V|자전거 통근 비율
urb_ctran|TT1008V|도보 통근 비율
urb_ctran|TT1020V|자가용 평균 통근 거리
urb_ctran|TT1064V|외부에서 도시로 들어오는 통근자 수
urb_ctran|TT1065V|도시 밖으로 나가는 통근자 수
urb_ctran|TT1057I|주민 1천 명당 등록 자동차 수
urb_ctran|TT1060I|주민 1만 명당 교통사고 사망자 수
urb_clivcon|DE3004I|가구당 평균 인원
urb_clivcon|DE3002I|1인 가구 비율
urb_clivcon|DE3005I|한부모 가구 비율
urb_clivcon|DE3008I|독거 은퇴자 가구 비율
urb_clivcon|DE3011I|미성년 자녀가 있는 가구 비율
urb_clivcon|SA1011I|자가 거주 가구 비율
urb_clivcon|SA1008I|아파트 거주 가구 비율
urb_clivcon|SA1013V|민간 임대주택 거주 가구 수
urb_clivcon|SA1001V|일반 주택 수
urb_clivcon|SA1025V|비어 있는 일반 주택 수
urb_clivcon|SA1022V|1인당 평균 주거 면적
urb_clivcon|SA1049V|주거용 주택 ㎡당 연간 임대료
urb_clivcon|SA1050V|아파트를 제외한 주택 평균 매매가격
urb_clivcon|SA1051V|아파트 평균 매매가격
urb_clivcon|EC3039V|가구 가처분소득 중앙값
urb_clivcon|EC3065V|사회이전 후 빈곤 위험 인구 비율
urb_cpopstr|DE1073V|인구 중위연령
urb_cpopstr|DE1061I|연간 인구 증감률
urb_cpopstr|DE1003I|남성 100명당 여성 수
urb_cpopcb|DE2007I|외국 국적 인구 비율
urb_cpopcb|DE2009I|해외 출생 인구 비율
urb_cpopcb|DE4003V|전년도 국내 다른 도시에서 이주한 인구
urb_cfermor|SA2007I|인구 1천 명당 출생아 수
urb_cfermor|SA2029I|인구 1천 명당 사망자 수
urb_cfermor|SA2004I|출생아 1천 명당 영아 사망자 수
urb_ceduc|TE1026V|고등교육기관 학생 수
urb_ceduc|TE1026I|주민 1천 명당 고등교육기관 학생 수
urb_ceduc|TE1001I|0~4세 아동 1천 명당 보육시설 이용 아동 수
urb_ceduc|TE2031V|25~64세 고등교육 이수자 수
urb_clma|EC1020I|실업률
urb_clma|EC1174V|20~64세 경제활동인구
urb_clma|EC1177V|20~64세 취업자 수
urb_clma|EC2020V|도시 내 사업장 기준 일자리 수
urb_clma|EC2033V|정보통신업 일자리 수
urb_clma|EC2034V|금융·보험업 일자리 수
urb_clma|EC2038V|예술·여가 등 서비스 부문 일자리 수
urb_cecfi|EC2039V|전 산업 사업체 단위 수
urb_cenv|EN4008V|연간 생활·상업 폐기물 발생량
'''

# Positive categories are summed only when both are present for the same city/year.
SURVEY_CANDIDATES = '''
PS1012V+PS1013V|대중교통 만족 응답률
PS1501V+PS1502V|학교·교육시설 만족 응답률
PS1506V+PS1507V|의료서비스 만족 응답률
PS1052V+PS1053V|공원·녹지 만족 응답률
PS1062V+PS1063V|체육시설 만족 응답률
PS1082V+PS1083V|문화시설 만족 응답률
PS3062V+PS3063V|광장·보행구역 등 공공공간 만족 응답률
PS3260V+PS3261V|공기 질 만족 응답률
PS3270V+PS3271V|도시 소음 수준 만족 응답률
PS3280V+PS3281V|도시 청결도 만족 응답률
PS2012V+PS2013V|좋은 일자리를 찾기 쉽다는 응답률
PS2032V+PS2033V|적정 가격의 주거지를 찾기 쉽다는 응답률
PS3092V+PS3093V|도시 주민을 신뢰한다는 응답률
PS3514V+PS3515V|밤에 혼자 걸어도 안전하다는 응답률
PS3340V+PS3341V|가구 재정상태 만족 응답률
PS3350V+PS3351V|현재 삶에 대한 만족 응답률
PS3360V+PS3361V|현재 도시 거주에 대한 만족 응답률
PS3529V|전반적으로 살기 좋은 도시라는 응답률
PS3532V|인종·민족 소수자가 살기 좋다는 응답률
PS3535V|성소수자가 살기 좋다는 응답률
PS3538V|이민자가 살기 좋다는 응답률
PS3541V|어린 자녀가 있는 가족이 살기 좋다는 응답률
PS3544V|고령자가 살기 좋다는 응답률
PS3547V+PS3548V|대중교통 요금이 저렴하다는 응답률
PS3552V+PS3553V|대중교통이 안전하다는 응답률
PS3557V+PS3558V|대중교통을 이용하기 쉽다는 응답률
PS3562V+PS3563V|대중교통 운행이 빈번하다는 응답률
PS3567V+PS3568V|대중교통이 정시 운행한다는 응답률
PS3572V|지역 경찰을 신뢰한다는 응답률
PS3575V|최근 1년 본인·가구원의 절도 피해 경험률
PS3578V|최근 1년 폭행·노상강도 피해 경험률
PS3587V+PS3588V|지방행정 민원 처리시간 만족 응답률
PS3592V+PS3593V|지방행정 절차를 이해하기 쉽다는 응답률
PS3601V+PS3602V|지방행정 수수료가 합리적이라는 응답률
PS3606V+PS3607V|온라인 지방행정 서비스 접근이 쉽다는 응답률
PS3611V+PS3612V|지방행정에 부패가 있다는 응답률
PS3618V|5년 전보다 삶의 질이 좋아졌다는 응답률
PS3620V+PS3621V|본인의 건강이 좋다는 응답률
PS3626V+PS3627V|최근 4주 대부분·항상 외로웠다는 응답률
'''

GLOBAL_CANDIDATES = '''
INFRASTRUCTURES|IN_ROA_LEN_2024|2024|도로망 총연장
INFRASTRUCTURES|IN_ROA_DEN_2024|2024|도로망 밀도
GREENNESS|GR_AVG_GRN_2025|2025|시가지 평균 녹색도·NDVI
GREENNESS|GR_SHB_GRN_2025|2025|녹색도 기준을 충족하는 구역 내 시가지 비율
GREENNESS|GR_SHB_HGR_2025|2025|고녹색도 구역 내 시가지 비율
GREENNESS|GR_CTH_AVG_2020|2020|시가지 평균 수관 높이
GREENNESS|GR_AVG_GRN_2025-GR_AVG_GRN_2020|2020~2025|5년간 시가지 녹색도 변화
GREENNESS|GR_SHB_GRN_2025-GR_SHB_GRN_2020|2020~2025|5년간 녹색도 구역 내 시가지 비율 변화
SDG|SD_POP_HGR_2025|2025|고녹색도 구역 거주 인구 비율
SDG|SD_POP_HGR_2025-SD_POP_HGR_2020|2020~2025|5년간 고녹색도 구역 거주 인구 비율 변화
SDG|SD_LUE_LCR_2010_2020|2010~2020|도시 토지 소비 증가율
SDG|SD_LUE_PGR_2010_2020|2010~2020|도시권 인구 증가율
SDG|SD_LUE_LPR_2010_2020|2010~2020|인구 증가율 대비 토지 소비 증가율·토지이용 효율 지표
WATER|WA_MAR_SST_2024|2024|해안 도시 주변 해수면 온도
WATER|WA_MAR_SHT_2023|1993~2023|해안 도시 주변 해수면 상승 추세
WATER|WA_MAR_STT_2021|1993~2021|해안 도시 주변 해수면 온도 상승 추세
NATURAL_SYSTEMS|NS_TPA_PER_2025|2025|도시권 면적 중 육상 보호구역 비율
NATURAL_SYSTEMS|NS_MPA_PER_2025|2025|도시권 면적 중 해양 보호구역 비율
HAZARD_RISK|HZ_WLF_BHA_2024|2020~2024|도시권 내 누적 산불 소실 면적
HAZARD_RISK|HZ_WLF_NUM_2024|2024|도시권 내 산불 발생 건수
'''


def read_eurostat(dataset):
    data = json.loads((SOURCES / f'{dataset}.json').read_text(encoding='utf8'))
    codes = {}
    for key in data['id']:
        index = data['dimension'][key]['category']['index']
        codes[key] = sorted(index, key=index.get)
    strides = {key: math.prod(data['size'][i+1:]) for i, key in enumerate(data['id'])}
    result = collections.defaultdict(dict)
    values = data.get('value', {})
    if isinstance(values, list):
        values = {str(i): v for i, v in enumerate(values) if v is not None}
    status = data.get('status', {})
    for flat_index, value in values.items():
        if not isinstance(value, (int, float)) or not math.isfinite(value):
            continue
        i = int(flat_index)
        row = {key: codes[key][i // strides[key] % len(codes[key])] for key in data['id']}
        city = row['cities']
        # Exclude national totals and avoid mixing FUA with city boundaries.
        if not re.fullmatch(r'[A-Z]{2}\d{3}C\d*', city):
            continue
        if row.get('unit', 'PC') != 'PC':
            continue
        flag = status.get(flat_index) if isinstance(status, dict) else None
        result[row['indic_ur']][int(row['time']), city] = (value, flag)
    return data, result


def accepted_record(label, source, period, observations, **kwargs):
    values = {r['value'] for r in observations}
    if len(observations) < 10 or len(values) < 10:
        return None
    return {'label': label, 'scope': source, 'period': str(period),
            'city_count': len(observations), 'distinct_values': len(values),
            'samples': observations[:12], **kwargs}


def main():
    cache, accepted, rejected = {}, [], []
    candidates = [line.split('|') for line in EU_CANDIDATES.strip().splitlines()]
    candidates += [['urb_percep', *line.split('|')] for line in SURVEY_CANDIDATES.strip().splitlines()]
    for dataset, expression, label in candidates:
        if dataset not in cache:
            cache[dataset] = read_eurostat(dataset)
        data, points = cache[dataset]
        fields = expression.split('+')
        keys = set(points.get(fields[0], {}))
        for field in fields[1:]:
            keys &= set(points.get(field, {}))
        by_year = collections.defaultdict(list)
        for year, city in sorted(keys):
            parts = [points[f][year, city] for f in fields]
            value = sum(p[0] for p in parts)
            by_year[year].append({'id': city, 'name': data['dimension']['cities']['category']['label'][city],
                                  'value': value, 'flags': [p[1] for p in parts]})
        item = None
        for year in sorted(by_year, reverse=True):
            item = accepted_record(label, '유럽·설문' if dataset == 'urb_percep' else '유럽', year, by_year[year],
                                   dataset=dataset, indicator_ids=fields, derived=len(fields) > 1,
                                   original_labels=[data['dimension']['indic_ur']['category']['label'].get(f) for f in fields],
                                   url=f'https://ec.europa.eu/eurostat/databrowser/view/{dataset}/default/table?lang=en&indic_ur={fields[0]}')
            if item:
                break
        if item:
            accepted.append(item)
        else:
            rejected.append({'label': label, 'dataset': dataset, 'ids': fields})

    zip_cache = {}
    global_accepted = []
    for theme, expression, period, label in [l.split('|') for l in GLOBAL_CANDIDATES.strip().splitlines()]:
        if theme not in zip_cache:
            path = SOURCES / f'ghsl_{theme}.zip'
            z = zipfile.ZipFile(path)
            name = next(n for n in z.namelist() if n.endswith('.csv'))
            raw = z.read(name)
            try:
                text = raw.decode('utf-8-sig')
            except UnicodeDecodeError:
                text = raw.decode('cp1252')
            zip_cache[theme] = list(csv.DictReader(io.StringIO(text)))
        fields = expression.split('-')
        points, conflicts = {}, set()
        for row in zip_cache[theme]:
            identity = row.get('ID_UC_G0', '')
            if not identity.isdecimal():
                continue
            try:
                nums = [float(row[f]) for f in fields]
            except (KeyError, ValueError, TypeError):
                continue
            if any(not math.isfinite(v) for v in nums):
                continue
            value = nums[0] if len(nums) == 1 else nums[0] - nums[1]
            if identity in points and points[identity]['value'] != value:
                conflicts.add(identity)
            points[identity] = {'id': identity, 'name': row['GC_UCN_MAI_2025'],
                                'country': row['GC_CNT_GAD_2025'], 'value': value}
        observations = [v for k, v in sorted(points.items()) if k not in conflicts]
        url = ('https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_UCDB_GLOBE_R2024A/'
               f'GHS_UCDB_THEME_GLOBE_R2024A/GHS_UCDB_THEME_{theme}_GLOBE_R2024A/V1-2/')
        item = accepted_record(label, '세계·도시권', period, observations, dataset=theme,
                               indicator_ids=fields, derived=len(fields) > 1, excluded_conflicting_ids=sorted(conflicts),
                               url=url, definition_file=str(SOURCES / f'GHS_UCDB_THEME_{theme}_GLOBE_R2024A.pdf'))
        if item:
            global_accepted.append(item)
        else:
            rejected.append({'label': label, 'dataset': theme, 'ids': fields})
    accepted = global_accepted + accepted
    result = {'audit_date': '2026-10-17', 'rule': '>=10 distinct city IDs and >=10 distinct numeric values in one common period',
              'notes': ['Eurostat city/greater-city and JRC urban-centre boundaries are different and must not be merged into one ranking.',
                        'Resident survey response rates are perceptions, not objective crime/safety measurements.',
                        'Derived satisfaction rates sum both positive response categories for the same city and year.',
                        'JRC field years can refer to modelled/satellite estimates and trends; see the supplied definitions.'],
              'accepted': accepted, 'rejected': rejected}
    (ROOT / 'audit/city_statistics_ideas_verified.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    lines = ['# 추가 도시 통계 체크리스트', '',
             '각 항목은 같은 기준기간에 서로 다른 도시 10곳 이상과 서로 다른 수치 10개 이상을 확인했다. 표기: 범위 / 기준기간 / 도시 수.', '',
             '세계·도시권은 JRC Urban Centre, 유럽은 Eurostat 도시·확장도시, 유럽·설문은 주민 인식조사다. 서로 다른 경계를 하나의 순위에 혼합하면 안 된다.', '']
    lines += [f"- [ ] [{r['label']}]({r['url']}) — {r['scope']} / {r['period']} / {r['city_count']:,}곳" for r in accepted]
    (ROOT / 'audit/city_statistics_ideas_checklist.md').write_text('\n'.join(lines)+'\n', encoding='utf8')
    print('Accepted:', len(accepted), 'Global:', len(global_accepted), 'Rejected:',len(rejected))
    print('Minimum cities:', min(r['city_count'] for r in accepted))
    print('Rejected IDs:', [(r['dataset'],r['ids']) for r in rejected])


if __name__ == '__main__':
    main()
