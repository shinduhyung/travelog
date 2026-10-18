"""Describe audit coverage conservatively; structural checks are not certification."""
import collections
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit'
inventory = json.loads((OUT / 'statistics_inventory.json').read_text(encoding='utf8'))
wb = collections.defaultdict(list)
from compare_statistics_worldbank import SPECS
for metric, _, filename, section, _, _ in SPECS:
    wb[filename].append(f'{section or "전체"}: {metric}')

specific = {
    'hdi_data.json': 'UNDP 2025 원표 전행 대조: 193개국 일치, 대만 미검증',
    'top_airlines.json': 'Skytrax 2026 전체 순위 대조; 이름 미연결 항목 보류',
    'top_airports.json': 'Skytrax 2026 전체 순위 대조; 이름 미연결 항목 보류',
    'power_index.json': 'GFP 2026 전체 순위 대조; 이름 미연결 항목 보류',
    'cities.json': '지도 병합·좌표·동명 도시 대조; 인구/GDP/관광객 원수치 전수 검증 보류',
    'cities15000.json': '번들/공개 서버 스냅샷·중복·병합 대조; 도시별 원수치 검증 보류',
    'all_landmarks.json': '이름 중복·좌표 누락·순위 참조 대조; 모든 명소의 사실 검증 보류',
    'city_rank.json': '전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증',
    'global_rank.json': '전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증',
    'local_rank.json': '전체 이름 참조 무결성 검사; 선정 순위의 객관적 근거 미검증',
    'olympics.json': '국가 코드·중복·인도 메달 대조; 전 국가 메달 수 재구축 필요',
    'unesco_landmarks.json': '공식 총수·분류·표본 등재연도 대조; 전체 개별 등재항목 대조 보류',
    'millionaire.json': 'Henley 2024 표본으로 지표/범위 오표기 확인; 전행 최신값 대조 보류',
    'mls_cities.json': 'MLB 파일과 완전 동일 확인·공식 구단 목록 대조',
    'mlb_cities.json': 'Athletics 연고지 갱신 누락 확인; 전 구단 세부 정보 미검증',
    'nhl_cities.json': '유타 연고지 갱신 누락 확인; 전 구단 세부 정보 미검증',
    'city_stats.json': '북회귀선 5개 수도 좌표 대조; 나머지 테마 분류 전수 외부 검증 보류',
    'country_info.json': '인구·GDP·면적의 다른 앱 자료와 불일치 확인; 설명문 전체 사실 검증 보류',
    'geography_data.json': '일본 섬 개수·에베레스트 고도 표본 대조; 나머지 전수 검증 보류',
    'historical_empires.json': '로마제국 네덜란드 면적 모순 확인; 역사적 경계·면적 전수 검증 보류',
    'economics_trivia.json': '32개 지표 구조·국가 코드 확인; 각 생산량/보유량 공식 최신값 대조 보류',
    'language_data.json': '캐나다 분류·화면 helper 불일치 확인; 전체 언어 비율 미검증',
    'religion_data.json': '아르메니아/에티오피아 교파 분류 표본 대조; 나머지 전수 검증 보류',
    'financial_index.json': 'GFCI 40 공식 발표와 선두 격차 표본 대조; 전체 원표 미검증',
    'pollution.json': 'IQAir 2025 최신 선두값과 판 차이 확인; 전행 원표 대조 보류',
    'student.json': '관련 QS 최신 판 확인; 이 파일의 전체 Student Cities 순위 대조 보류',
    'ddad.json': '파싱 실패·직접 사용 경로 미발견; 통계 런타임 영향 미확인',
}
lines = ['# 파일별 검증 범위', '',
         '기준일 2026-10-17. 아래 109개 파일 모두 구조 검사 대상이다. “구조 검사”는 JSON 파싱·중복·참조·일부 숫자 범위 검사이며, 내용 전체의 정확성이나 최신성을 뜻하지 않는다. 개별 보류 항목을 정상 판정으로 해석하면 안 된다.', '',
         '외부 비교의 연도·정의 차이와 확정 문제는 [상세 결과](statistics_findings.md)를 함께 참고한다. Dart에 하드코딩된 국가 분류·Top Picks·개인 기록 계산은 상세 결과에 별도로 정리했다.', '',
         '| 파일 | 외부 값/내용 검증 범위와 남은 작업 | 직접 참조 Dart 수 |', '|---|---|---:|']
for item in inventory['inventory']:
    filename = pathlib.Path(item['file']).name
    scope = specific.get(filename, '구조 검사; 외부 원자료에 대한 내용 전수 검증 보류')
    if filename in wb:
        scope = '세계은행 공개 원표 전행 비교 (' + '; '.join(wb[filename]) + '); 정의·연도 차이는 별도 판정 필요'
        if item.get('sections'):
            checked = {x[3] for x in SPECS if x[2] == filename}
            unchecked = set(item['sections']) - checked
            scope += f'; 나머지 {len(unchecked)}개 섹션 외부 전수 검증 보류'
    lines.append(f"| [{filename}](../{item['file']}) | {scope} | {len(item['references'])} |")
lines += ['', '직접 참조 수는 lib 내 파일명 문자열 검색 결과다. 동적 파일명, 다른 JSON의 참조, pubspec 등록 여부를 완전히 대체하지 않는다.', '']
(OUT / 'statistics_review_status.md').write_text('\n'.join(lines), encoding='utf8')
print('Coverage rows:', len(inventory['inventory']))
