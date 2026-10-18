"""Verify non-environment city ideas using retained publisher observations.

Offline verification only; no application datasets are changed. Do not mix
publication years with reference years or rank numbers with measured scores.
"""
import json
import csv
import io
from html.parser import HTMLParser
import math
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'audit/city_culture_commerce_sources'
NON_EUROPE_WCCF = set('abu_dhabi adelaide austin beijing boston brasilia chengdu dubai guangzhou hong_kong jakarta los_angeles melbourne montreal nanjing new_york rio_de_janeiro san_francisco sao_paulo seoul sydney taipei tokyo toronto'.split())


def numeric(value):
    try:
        result = float(str(value).replace(',', ''))
        return result if math.isfinite(result) else None
    except (ValueError, TypeError):
        return None


def checked(domain, label, period, observations, url, **extra):
    assert len({r['city'] for r in observations}) == len(observations), label
    assert len(observations) >= 10, label
    assert len({r['value'] for r in observations}) >= 10, label
    return dict(domain=domain, label=label, period=period,
                verified_non_europe_city_count=len(observations),
                distinct_values=len({r['value'] for r in observations}),
                source_url=url, observations=observations, **extra)


class PublishedTables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.buffer = None
        self.row = []
        self.rows = []

    def handle_starttag(self, tag, attrs):
        if tag == 'tr': self.row = []
        if tag in ('td','th'): self.buffer = []

    def handle_data(self, data):
        if self.buffer is not None: self.buffer.append(data)

    def handle_endtag(self, tag):
        if tag in ('td','th') and self.buffer is not None:
            self.row.append(' '.join(''.join(self.buffer).split()))
            self.buffer = None
        if tag == 'tr' and self.row: self.rows.append(self.row)


def main():
    cities = json.loads((RAW/'wccf_city_data.json').read_text(encoding='utf-8'))
    result = []
    for slug, label in [('no_of_museums', '박물관 수'), ('no_of_public_libraries', '공공도서관 수'),
                         ('no_of_cinemas', '영화관 수'), ('no_of_theatres', '극장·공연시설 수')]:
        points = []
        for key in sorted(NON_EUROPE_WCCF):
            city = cities[key]
            row = city['acf'].get(slug, {})
            value = numeric(row.get('figure'))
            if row.get('year') != '2024' or value is None:
                continue
            # Entry says 2024 but its cited underlying survey is 2022–23.
            if key == 'hong_kong' and slug == 'no_of_theatres':
                continue
            points.append(dict(city=city['title'], value=value, source=row.get('source'),
                               notes=row.get('notes'), reference_year=row['year'],
                               city_source_url=city['permalink']))
        result.append(checked('문화', label, '2024', points,
            'https://worldcitiescultureforum.com/data-explorer-indicators/',
            indicator=slug, data_kind='WCCF city-reported counts',
            limitation='City boundaries and facility definitions vary. Some library counts include mobile libraries; theatre counts may include companies or multipurpose facilities. Not yet harmonized for direct implementation.'))

    # Manually transcribed resident quality ratings from each named section's
    # “How it ranked” paragraph. Expert-panel scores and affordability are not
    # mixed into these percentages. “three-quarters” is exactly 75%.
    for domain, label, source_name, pairs in [
        ('문화', '주민의 문화생활 만족도', 'culture', [
            ('New York City',93),('Cape Town',84),('Melbourne',92),('São Paulo',69),
            ('Taipei',71),('Marrakech',63),('Guadalajara',86),('Cairo',62),
            ('Beijing',80),('Jaipur',77),('Chiang Mai',75)]),
        ('음식', '현지인의 외식 만족도', 'food', [
            ('Lima',80),('Bangkok',81),('Mexico City',80),('Ho Chi Minh City',75),
            ('Melbourne',94),('Beijing',82),('Cape Town',93),('Osaka',68),
            ('Bengaluru',82),('New York',90),('Hong Kong',73),('Buenos Aires',72),('Medellin',94)])]:
        url = ('https://www.timeout.com/travel/best-cities-for-culture-2026' if source_name=='culture'
               else 'https://www.timeout.com/uk/travel/worlds-best-cities-for-food-2026')
        text = (RAW/f'timeout_{source_name}_2026.html').read_text(encoding='utf-8')
        assert 'How it ranked' in text
        result.append(checked(domain, label, '2026 survey publication',
            [dict(city=c, value=v, unit='%', non_europe=True) for c,v in pairs], url,
            data_kind='Resident survey quality approval; not expert-panel scores',
            raw_file=f'timeout_{source_name}_2026.html',
            limitation='Published survey edition, not a calendar-year administrative measurement. Sample sizes by city are not supplied in the public article.'))

    # Read HOME rows only. The same page also contains ROAD attendance: taking
    # the first match for each team preserves the HOME table, never the second.
    text = (RAW/'nba_attendance_2024_25.txt').read_text(encoding='utf-8')
    direct_cities = 'Atlanta|Boston|Charlotte|Chicago|Cleveland|Dallas|Denver|Detroit|Houston|Memphis|Miami|Milwaukee|New Orleans|Oklahoma City|Orlando|Philadelphia|Phoenix|Portland|Sacramento|San Antonio|Toronto|Washington'
    seen = {}
    for line in text.splitlines():
        m = re.search(r'('+direct_cities+r') ([A-Za-z0-9 ]+?)\s{2,}(\d+)\s+([\d,]+)\s+([\d,]+)\s*$', line)
        if not m:
            continue
        city, team, games, total, average = m.groups()
        if city in seen:
            continue
        games, total, average = int(games), int(total.replace(',','')), int(average.replace(',',''))
        assert abs(total/games-average) <= 1, city
        seen[city] = dict(city=city, team=city+' '+team.strip(), value=average,
                          home_games=games, total_home_attendance=total, unit='people/game')
    assert len(seen) == 22
    result.append(checked('스포츠', '도시 연고 NBA 구단의 평균 홈 관중 수', '2024–25 season', list(seen.values()),
        'https://lalweb.blob.core.windows.net/public/lakers/media-relations/2025-26-Lakers-Media-Guide.pdf',
        raw_file='lakers_media_2025_26.pdf', pdf_page=87, printed_page=85,
        data_kind='Official NBA team media-guide league attendance table',
        limitation='22 directly named single-team cities in USA/Canada. Not all-sport city attendance. Multi-team city aggregation and state/region-named franchises are not proposed.'))

    # Publisher's final capacities announced immediately before the tournament,
    # not earlier approximate stadium capacities or projected match attendance.
    blocks = json.loads((RAW/'fifa_capacities_2026_blocks.json').read_text(encoding='utf-8'))
    points = []
    for tag, value in blocks:
        m = re.fullmatch(r'(.+?):\s*([\d,]{4,})',value)
        if tag == 'li' and m:
            stadium, value = m.groups()
            points.append(dict(city=stadium, value=int(value.replace(',','')), unit='seats'))
    assert len(points) == 16
    result.append(checked('스포츠', '2026 월드컵 개최 도시권의 대회 경기장 수용인원', '2026 final tournament capacities', points,
        'https://inside.fifa.com/organisation/news/fifa-world-cup-stadium-capacities-confirmed?entryId=UTg91O9jLQEFnQtlYrdfh&requester=MediaHub',
        data_kind='FIFA confirmed final event capacities',
        limitation='16 North American host markets. Host names can be metropolitan areas; not every stadium lies in the named administrative city. Not citywide stadium capacity.'))

    # One documented prime street per distinct APAC city. These are representative
    # commercial street asking rents, never residential rents or a city average.
    rents = [('Hong Kong','Tsim Sha Tsui',1515),('Tokyo','Ginza',1257),('Osaka','Midosuji',914),
             ('Sydney','Pitt Street Mall',795),('Seoul','Myeongdong',653),('Shanghai','West Nanjing Road',517),
             ('Singapore','Orchard Road',478),('Beijing','CBD',408),('Nanjing','Xinjiekou',368),
             ('Ho Chi Minh City','Dong Khoi',346),('Melbourne','Bourke Street',336),
             ('Hanoi','Trang Tien & Hang Khay',312)]
    raw = (RAW/'mainstreets_2025.html').read_text(encoding='utf-8')
    assert 'APAC Ranking 2025' in raw
    for _,_,value in rents:
        assert '$'+f'{value:,}' in raw
    result.append(checked('상업', '핵심 쇼핑 상권의 대표 상가 임대료', '2025 report / Q3 2025',
        [dict(city=c, street=s, value=v, unit='USD/sq ft/year') for c,s,v in rents],
        'https://digital.cushmanwakefield.com/mainstreets-11-2025-global-central-en-content-retail/20/',
        data_kind='Cushman & Wakefield Main Streets APAC table, report printed page 20',
        limitation='12 APAC cities verified. Representative prime retail location; not an average for all shops in the city.'))

    # Public industry republication of the ICCA 2025 APAC numerical table.
    # The ICCA/JNTO releases corroborate the edition, but not every observation.
    meetings = [('Singapore',156),('Seoul',121),('Tokyo',119),('Bangkok',118),('Hong Kong',102),
                ('Taipei',89),('Kuala Lumpur',73),('Sydney',62),('Shanghai',57),('Kyoto',53),
                ('Beijing',51),('Brisbane',50),('Busan',50)]
    tables = PublishedTables()
    tables.feed((RAW/'icca_2025_reprint.html').read_text(encoding='utf-8'))
    for city, value in meetings:
        assert any(len(row)==4 and row[1]==city and row[-1]==str(value) for row in tables.rows), (city,value)
    result.append(checked('상업', '국제협회회의 개최 건수·ICCA 기준', '2025',
        [dict(city=c,value=v,unit='meetings') for c,v in meetings],
        'https://micetimes.jp/en/icca-2026-news-2/',
        data_kind='ICCA data republished in MICE TIMES ONLINE; numerical table read directly',
        raw_file='icca_2025_reprint.html',
        snapshot_note='HTTP transfer ended short at footer; all 13 complete numerical table rows are parsed and asserted against the retained HTML.',
        official_release='https://www.iccaworld.org/news/post/public-abstract-released-for-globewatch-country-and-city-rankings-2025/',
        corroborating_agency='https://www.japanmeetings.org/news/detail/2696.html',
        limitation='13 APAC cities verified in public republication; full ICCA database was not accessed. Not a count of all corporate events, trade fairs or exhibitions.'))

    # Official Census bulk data is publicly offered separately from the API
    # (which now requires a key). Retain establishments, not employment/payroll
    # fields with disclosure flags. Join only CBSA top-level MSA rows, never
    # metropolitan divisions, counties, or micropolitan areas.
    with (RAW/'cbsa-est2023-alldata.csv').open(encoding='cp1252') as stream:
        metros = {r['CBSA']:r['NAME'] for r in csv.DictReader(stream)
                  if r['LSAD']=='Metropolitan Statistical Area' and not r['STCOU'] and not r['MDIV']}
    census_specs = {
        '451211':('문화','서점 사업장 수·미국 도시권'),
        '312120':('음식','맥주 양조 사업장 수·미국 도시권'),
        '722330':('음식','푸드트럭 등 이동식 음식점 사업장 수·미국 도시권'),
    }
    census_points = {key:[] for key in census_specs}
    with zipfile.ZipFile(RAW/'cbp23msa.zip') as archive:
        with io.TextIOWrapper(archive.open('cbp23msa.txt'),encoding='utf-8-sig') as stream:
            for row in csv.DictReader(stream):
                code = row['naics']
                if code not in census_specs or row['msa'] not in metros or not row['est'].isdigit():
                    continue
                census_points[code].append(dict(id=row['msa'],city=metros[row['msa']],
                    value=int(row['est']),unit='employer establishments'))
    for code,(domain,label) in census_specs.items():
        result.append(checked(domain,label,'2023',census_points[code],
            'https://www2.census.gov/programs-surveys/cbp/datasets/2023/',
            data_kind='US Census County Business Patterns 2023, NAICS2017 '+code,
            raw_file='cbp23msa.zip', geography_reference='cbsa-est2023-alldata.csv',
            limitation='USA metropolitan statistical areas only, not administrative cities. Counts establishments with paid employees, excluding nonemployer businesses. Brewery count is not a count of craft beer bars; mobile food services counts establishments, not individual vehicles.'))

    # Numeric availability alone is not enough to create another recommended
    # metric when it largely repeats a retained food-quality question.
    alternatives = [checked('음식', '향토음식 평점·TasteAtlas', '2025/26 edition',
        [dict(city=c,value=v) for c,v in [('Mumbai',4.78),('Lima',4.74),('Osaka',4.74),('Kyoto',4.70),
         ('New Orleans',4.68),('New York City',4.66),('Singapore',4.64),('Jakarta',4.64),
         ('Tokyo',4.60),('San Francisco',4.60),('Philadelphia',4.58),('Chicago',4.57),
         ('Padang',4.51),('Hanoi',4.49),('Amritsar',4.48),('Beijing',4.48),('Melbourne',4.47),('New Delhi',4.45)]],
         'https://www.tasteatlas.com/best/cities', status='verified alternative, not an additional checkbox',
         reason='Both this and resident dining satisfaction concern food quality; retain one to avoid padding the recommendation list.')]
    rejected = [
        dict(label='미쉐린 별·5성급 호텔·영화 촬영·영화제·프로리그 연고 도시', reason='Already represented by capital_concentration.json, hollywood.json, city_stats.json and league city assets.'),
        dict(label='WCCF 음식점 수·바 수', reason='Only 8 non-European cities each in common reference year 2024.'),
        dict(label='WCCF 라이브 음악 공연장 수·문화센터 수', reason='Only 9 non-European cities each in reference year 2024.'),
        dict(label='WCCF 문화예산 비율', reason='10 matched 2024 city rows before quality checks, but source notes contain amount-scale and reference-year concerns (including Seoul, Hong Kong, Brasilia). Fewer than 10 reliable common-period cities after exclusion.'),
        dict(label='문화시설 관람·참여율', reason='No common reference year with 10 non-European cities.'),
        dict(label='HappyCow 비건 식당 수', reason='Public ranking description gives venue counts for only 3 non-European top-ten cities; the remaining places only have ranks in the readable page.'),
        dict(label='Burson 스포츠 도시 순위', reason='Ranking numbers confirmed, but no public numerical score table was found. Rank alone was not counted as an underlying metric.'),
        dict(label='NBA 구단 수·리그별 연고 도시 수', reason='Overlaps existing sports-city collections; not new statistics.'),
    ]
    exclusions = {'existing_assets_reviewed':['assets/capital_concentration.json','assets/city_stats.json',
        'assets/hollywood.json','assets/starbucks.json','assets/sports.json','assets/nba_cities.json',
        'assets/nhl_cities.json','assets/mlb_cities.json','assets/nfl_cities.json','assets/mls_cities.json'],
        'existing_screens_reviewed':['lib/screens/city_specials_screen.dart','lib/screens/city_economy_screen.dart',
        'lib/screens/sports_stats_screen.dart','lib/screens/landmark_stats_screen.dart'],
        'distinction':'Citywide external cultural facility counts are different from the user’s visited landmark counts. NBA measured spectator demand and FIFA event venue capacity are different from existing league-city membership lists.'}
    output = dict(verified_at='2026-10-17', criteria='Each candidate: >=10 distinct non-European cities/host markets and >=10 distinct actual finite values in a common stated reference period or survey edition; no rank-to-score invention.',
                  recommended_count=len(result), recommended=result, alternatives=alternatives,
                  rejected=rejected, overlap_review=exclusions)
    path = ROOT/'audit/city_culture_commerce_verified.json'
    path.write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    lines = ['# 문화·음식·스포츠·상업: 신규 도시 통계 후보','',
        '검증일 2026-10-17. 모든 항목은 유럽 밖 서로 다른 도시·도시권 10곳 이상과 서로 다른 실제 수치 10개 이상을 확인. 항목별 자료 범위가 다르며 앱 도시 매칭 수를 의미하지 않음.','']
    for domain in ['문화','음식','스포츠','상업']:
        lines += ['## '+domain,'']
        for r in result:
            if r['domain'] != domain: continue
            lines.append(f"- [ ] {r['label']} — {r['period']} / 유럽 밖 **{r['verified_non_europe_city_count']}곳** / [출처]({r['source_url']})")
            examples = r['observations'][:3]
            lines.append('  - 표본: '+', '.join(f"{v['city']} {v['value']:g}" for v in examples))
            lines.append('  - 범위: '+r['limitation'])
        lines.append('')
    lines += ['## 제외한 후보',''] + [f"- {r['label']}: {r['reason']}" for r in rejected]
    (ROOT/'audit/city_culture_commerce_checklist.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    assert len(result)==13
    print(json.dumps({r['label']:r['verified_non_europe_city_count'] for r in result},ensure_ascii=False))


if __name__ == '__main__':
    main()
