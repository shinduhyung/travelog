"""Travelog 전체 유저 통계 CSV -> assets/user_stats.json

입력: travelogdata/export/travelog_all_statistics_combined.csv (combine_travelog_stats.py 결과)
  - 값별 유저 수 분포(users_exactly), 평균/중앙값(Summary 행), 도시/랜드마크 방문율(visit rate 행)을 쓴다.
출력: 앱에 번들되는 assets/user_stats.json
  {"updatedAt", "metrics": {key: {"mean", "median", "hist": {value: 유저 비율(합 1)}}},
   "cities": [[name, visitRatePercent]], "landmarks": [...]}
유저 수 규모가 앱에서 드러나지 않도록 인원 수는 에셋에 넣지 않고 비율만 담는다.
통계를 새로 뽑았을 때 이 스크립트를 다시 돌려 에셋을 갈아끼운다.

사용: python tool/user_stats/build_user_stats.py <combined.csv> [--out assets/user_stats.json]
"""
import argparse
import csv
import json
from datetime import date

# CSV section -> (앱 StatMetric 키, Summary 행의 metric)
SECTIONS = {
    'Countries': ('countries_total', 'countries'),
    'Asia': ('countries_asia', 'continent_Asia'),
    'Europe': ('countries_europe', 'continent_Europe'),
    'Africa': ('countries_africa', 'continent_Africa'),
    'North America': ('countries_north_america', 'continent_North America'),
    'South America': ('countries_south_america', 'continent_South America'),
    'Oceania': ('countries_oceania', 'continent_Oceania'),
    'GaWC Cities': ('gawc_cities', 'gawc_cities'),
    'Top 250 Landmarks': ('top250_landmarks', 'top250_landmarks'),
    'UNESCO': ('unesco', 'unesco'),
    'Airports': ('airports', 'airports'),
    'Airlines': ('airlines', 'airlines'),
    'Flight Logs': ('flights', 'flight_logs'),
}
MAX_CITIES = 100
MAX_LANDMARKS = 400


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('csv')
    ap.add_argument('--out', default='assets/user_stats.json')
    args = ap.parse_args()

    with open(args.csv, newline='', encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))

    summary = {r['metric']: r for r in rows if r['section'] == 'Summary'}
    metrics = {}
    for section, (key, summary_key) in SECTIONS.items():
        hist = {}
        for r in rows:
            if r['section'] == section and r['users_exactly'] != '':
                count = int(r['users_exactly'])
                if count > 0:
                    hist[str(int(float(r['countries_or_places'])))] = count
        if not hist:
            continue
        n = sum(hist.values())
        # 소수 셋째 자리까지만: 1명짜리 칸(1/n)이 0이 되어 모수를 거꾸로 셀 수 없다
        m = {'hist': {k: round(v / n, 3) for k, v in sorted(hist.items(), key=lambda kv: int(kv[0])) if round(v / n, 3) > 0}}
        s = summary.get(summary_key)
        if s and s['mean'] != '':
            m['mean'] = float(s['mean'])
            m['median'] = float(s['median'])
        metrics[key] = m

    def visit_rates(section, limit):
        out = [r for r in rows if r['section'] == section and r['name']]
        out.sort(key=lambda r: -float(r['visit_rate_percent']))
        return [[r['name'], float(r['visit_rate_percent'])] for r in out[:limit]]

    doc = {
        'updatedAt': date.today().isoformat(),
        'metrics': metrics,
        'cities': visit_rates('City visit rate >1%', MAX_CITIES),
        'landmarks': visit_rates('Landmark visit rate >1%', MAX_LANDMARKS),
    }
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{len(metrics)} metrics, {len(doc["cities"])} cities, {len(doc["landmarks"])} landmarks -> {args.out}')


if __name__ == '__main__':
    main()
