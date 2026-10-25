"""Builds sports statistics assets from public sources (see docs/sports_statistics.md).

Sources: Wikipedia tables (CC BY-SA 4.0), FIFA ranking JSON used by inside.fifa.com,
MLB Opening Day press release (hand-entered below). Run from the repo root:
    python -X utf8 tool/sports_stats/build_sports_datasets.py [olympics fifa ucl wc tennis fide mlb]
Unresolved country names are printed and fail the build, never silently dropped.
"""
import json
import re
import sys
import urllib.request
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from isomap import IsoResolver  # noqa: E402
from wp import tables  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TODAY = '2026-10-24'
WIKI = 'https://en.wikipedia.org/wiki/'
R = IsoResolver()


def metric(mid, unit, src, period):
    return {'id': mid, 'unit': unit, 'source_url': src, 'reference_period': period, 'updated_at': TODAY}


def write(dataset_id, layout, tbls, src, period):
    doc = {
        'schema_version': 1, 'dataset_id': dataset_id,
        'metadata': {'source_url': src, 'reference_period': period, 'updated_at': TODAY},
        'legacy_layout': layout, 'tables': tbls,
    }
    (ROOT / 'assets' / f'{dataset_id}.json').write_text(
        json.dumps(doc, ensure_ascii=False, indent=1) + '\n', encoding='utf8')
    print('wrote', dataset_id, [(t['id'], len(t['records'])) for t in tbls])


def table(tid, dims, metrics, records, src, period):
    return {'id': tid, 'metadata': {'source_url': src, 'reference_period': period, 'updated_at': TODAY},
            'dimensions': dims, 'metrics': metrics, 'records': records}


def clean(s):
    return re.sub(r'\[[^\]]*\]', '', str(s)).strip()


def need(iso, name):
    if iso is None:
        raise SystemExit(f'unresolved country: {name}')
    return iso


# ---------------------------------------------------------------- Olympics
# Direct continuations of the same national team are merged: Germany (GER+EUA+FRG+GDR),
# Russia (RUS+ROC+OAR), Serbia (SRB+SCG). Soviet Union, Unified Team, Czechoslovakia,
# Yugoslavia and the Russian Empire are historic entities and are excluded.
OLY_MERGE = {'EUA': 'GER', 'FRG': 'GER', 'GDR': 'GER', 'ROC': 'RUS', 'OAR': 'RUS', 'SCG': 'SRB'}
OLY_SKIP = {'URS', 'EUN', 'TCH', 'YUG', 'RU1', 'AIN', 'IOA', 'IOP', 'ZZX', 'EOR', 'ROT'}


def build_olympics():
    rev, t = tables('All-time_Olympic_Games_medal_table')
    x = t[1]
    x.columns = ['team', 'sn', 'sg', 'ss', 'sb', 'st', 'wn', 'wg', 'ws', 'wb', 'wt', 'cn', 'cg', 'cs', 'cb', 'ct']
    acc = {}
    for _, r in x.iterrows():
        raw = str(r['team'])
        if raw.startswith('Totals'):
            continue
        codes = re.findall(r'\[([A-Z]{3}(?:/[A-Z]{3})?)\]', raw)
        code = codes[0].split('/')[-1] if codes else None
        if code in OLY_SKIP or 'Mixed team' in raw or raw.startswith('Refugee'):
            continue
        if code == 'SCG' or (codes and codes[0] == 'YUG/SCG'):
            code = 'SCG'
        name = clean(raw).replace(' (ROC)', '')
        if name in ('Australasia', 'Bohemia'):
            continue
        if code in OLY_MERGE:
            name = {'GER': 'Germany', 'RUS': 'Russia', 'SRB': 'Serbia'}[OLY_MERGE[code]]
        if name in ('Yugoslavia', 'Soviet Union'):
            continue
        iso = R.resolve(name)
        if iso is None:
            print('  unresolved NOC row:', raw)
            continue
        a = acc.setdefault(iso, [0, 0, 0, 0])
        for i, k in enumerate(('sg', 'st', 'wg', 'wt')):
            a[i] += int(r[k])
    recs = [{'dimensions': {'iso_a3': k}, 'values': dict(zip(('summer_gold', 'summer_total', 'winter_gold', 'winter_total'), v))}
            for k, v in sorted(acc.items(), key=lambda kv: -(kv[1][0] + kv[1][2]))]
    src = WIKI + 'All-time_Olympic_Games_medal_table'
    per = f'Summer Games through Paris 2024, Winter Games through Milano Cortina 2026 (Wikipedia revision {rev})'
    ms = [metric(m, 'medals', src, per) for m in ('summer_gold', 'summer_total', 'winter_gold', 'winter_total')]
    write('olympics', 'list', [table('main', ['iso_a3'], ms, recs, src, per)], src, per)


# ---------------------------------------------------------------- FIFA
def fetch_json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'TravelogResearch/1.0 (leeahn137@gmail.com)'})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def build_fifa():
    ids = {'men': 'FRS_Male_Football_20260720', 'women': 'FRS_Female_Football_20260615'}
    tbls = []
    src = 'https://inside.fifa.com/fifa-rankings/world-ranking'
    for key, sid in ids.items():
        d = fetch_json('https://api.fifa.com/api/v3/fifarankings/rankings/rankingsbyschedule'
                       f'?rankingScheduleId={sid}&language=en')['Results']
        recs = []
        for e in d:
            name = e['TeamName'][0]['Description']
            iso = R.resolve(name)
            if iso is None or e['Rank'] is None:
                print('  skip:', name, 'rank', e['Rank'], 'iso', iso)
                continue
            recs.append({'dimensions': {'iso_a3': iso, 'name': name},
                         'values': {'rank': e['Rank'], 'points': round(e['TotalPoints'], 2)}})
        recs.sort(key=lambda r: r['values']['rank'])
        per = 'FIFA ranking edition ' + sid.rsplit('_', 1)[1]
        ms = [metric('rank', 'rank', src, per), metric('points', 'points', src, per)]
        tbls.append(table(key, ['iso_a3', 'name'], ms, recs, src, per))
    write('sports_fifa_ranking', 'sections', tbls, src, 'men 2026-10-07 edition, women 2026-06-15 edition')


# ---------------------------------------------------------------- UEFA CL
CLUB_CITY = {
    'Real Madrid': ('Madrid', 'ESP'), 'Milan': ('Milan', 'ITA'), 'Bayern Munich': ('Munich', 'DEU'),
    'Liverpool': ('Liverpool', 'GBR'), 'Barcelona': ('Barcelona', 'ESP'), 'Ajax': ('Amsterdam', 'NLD'),
    'Inter Milan': ('Milan', 'ITA'), 'Manchester United': ('Manchester', 'GBR'),
    'Juventus': ('Turin', 'ITA'), 'Benfica': ('Lisbon', 'PRT'), 'Chelsea': ('London', 'GBR'),
    'Paris Saint-Germain': ('Paris', 'FRA'), 'Nottingham Forest': ('Nottingham', 'GBR'),
    'Porto': ('Porto', 'PRT'), 'Borussia Dortmund': ('Dortmund', 'DEU'), 'Celtic': ('Glasgow', 'GBR'),
    'Hamburger SV': ('Hamburg', 'DEU'), 'Steaua București': ('Bucharest', 'ROU'),
    'Marseille': ('Marseille', 'FRA'), 'Manchester City': ('Manchester', 'GBR'),
    'Feyenoord': ('Rotterdam', 'NLD'), 'Aston Villa': ('Birmingham', 'GBR'),
    'PSV Eindhoven': ('Eindhoven', 'NLD'), 'Red Star Belgrade': ('Belgrade', 'SRB'),
}


def build_ucl():
    page = 'List_of_European_Cup_and_UEFA_Champions_League_finals'
    rev, t = tables(page)
    clubs = t[4]
    nations = t[5]
    src = WIKI + page
    per = f'Through the 2026 final (Wikipedia revision {rev})'
    agg = {}
    for _, r in nations.iterrows():
        if int(r['Title(s)']) == 0:
            continue
        iso = need(R.resolve(clean(r['Nation'])), r['Nation'])
        a = agg.setdefault(iso, [0, 0])
        a[0] += int(r['Title(s)'])
        a[1] += int(r['Runners-up'])
    country = [{'dimensions': {'iso_a3': k}, 'values': {'titles': v[0], 'runners_up': v[1]}}
               for k, v in sorted(agg.items(), key=lambda kv: -kv[1][0])]
    cities = {}
    for _, r in clubs.iterrows():
        n = int(r['Title(s)'])
        if n == 0:
            continue
        club = clean(r['Club'])
        if club not in CLUB_CITY:
            raise SystemExit(f'club without city mapping: {club}')
        city, iso = CLUB_CITY[club]
        c = cities.setdefault((city, iso), {'titles': 0, 'clubs': []})
        c['titles'] += n
        c['clubs'].append(f'{club} ({n})')
    # Sanity: both views must agree on the grand total.
    assert sum(v[0] for v in agg.values()) == sum(c['titles'] for c in cities.values())
    city = [{'dimensions': {'city': k[0], 'iso_a3': k[1]}, 'values': {'titles': v['titles'], 'clubs': ', '.join(v['clubs'])}}
            for k, v in sorted(cities.items(), key=lambda kv: -kv[1]['titles'])]
    t1 = table('country', ['iso_a3'], [metric('titles', 'titles', src, per), metric('runners_up', 'finals', src, per)], country, src, per)
    t2 = table('city', ['city', 'iso_a3'], [metric('titles', 'titles', src, per), metric('clubs', None, src, per)], city, src, per)
    write('sports_ucl_titles', 'sections', [t1, t2], src, per)


# ---------------------------------------------------------------- World Cup
WC_ORDER = ['Champions', 'Runners-up', 'Third place', 'Fourth place', 'Quarter-finals',
            'Round of 16', 'Round of 32', 'Group stage']


def wc_category(text):
    s = clean(re.sub(r'\([^)]*\)', '', str(text)))
    for c in WC_ORDER:
        if s.startswith(c):
            return c
    # Early second-round formats count as the round of 16 equivalent.
    if s.lower().startswith(('second round', 'first round', 'second group', 'final round')):
        return 'Round of 16' if s.lower().startswith(('second round', 'second group', 'final round')) else 'Group stage'
    raise SystemExit(f'unknown World Cup result: {text!r}')


def build_wc():
    page = 'National_team_appearances_in_the_FIFA_World_Cup'
    rev, t = tables(page)
    x = t[0]
    best = {}
    for _, r in x.iterrows():
        name = clean(re.sub(r'\[[a-z]+\]', '', str(r['Team'])))
        cat = wc_category(r['Best result'])
        iso = need(R.resolve(name), name)
        cur = best.get(iso)
        apps = int(r['Appearances'])
        if cur is None or WC_ORDER.index(cat) < WC_ORDER.index(cur[0]):
            best[iso] = [cat, apps + (cur[1] if cur else 0)]
        else:
            cur[1] += apps
    recs = [{'dimensions': {'iso_a3': k}, 'values': {'best_result': v[0], 'appearances': v[1]}}
            for k, v in sorted(best.items(), key=lambda kv: (WC_ORDER.index(kv[1][0]), -kv[1][1]))]
    src = WIKI + page
    per = f'Through the 2026 FIFA World Cup (Wikipedia revision {rev})'
    ms = [metric('best_result', None, src, per), metric('appearances', 'tournaments', src, per)]
    write('sports_world_cup_results', 'list', [table('main', ['iso_a3'], ms, recs, src, per)], src, per)


# ---------------------------------------------------------------- Tennis
def build_tennis():
    import requests
    page = "List of Grand Slam men's singles champions"
    UA = {'User-Agent': 'TravelogResearch/1.0 (leeahn137@gmail.com)'}
    j = requests.get('https://en.wikipedia.org/w/api.php', params=dict(
        action='parse', page=page, prop='text|revid', format='json'), headers=UA, timeout=60).json()['parse']
    h = j['text']['*']
    i = h.find('Grand_Slam_titles_by_country')
    k = h.find('Open_Era', i)
    seg = re.sub(r'<[^>]+>', ' ', h[i:k]).replace('&#160;', ' ')
    seg = re.sub(r'\s+', ' ', seg)
    agg = {}
    for titles, name, players in re.findall(r'(\d+)\s+([A-Z][A-Za-z /.]+?) \((\d+) players?\)', seg):
        # "Czechoslovakia / Czech Republic" -> use the last (current) name.
        iso = need(R.resolve(name.split(' / ')[-1].strip()), name)
        a = agg.setdefault(iso, [0, 0])
        a[0] += int(titles)
        a[1] += int(players)
    recs = [{'dimensions': {'iso_a3': k}, 'values': {'titles': v[0], 'players': v[1]}}
            for k, v in sorted(agg.items(), key=lambda kv: -kv[1][0])]
    src = WIKI + 'List_of_Grand_Slam_men%27s_singles_champions'
    per = f'All-time through the 2026 US Open (Wikipedia revision {j["revid"]})'
    ms = [metric('titles', 'titles', src, per), metric('players', 'players', src, per)]
    write('sports_tennis_slam_men', 'list', [table('main', ['iso_a3'], ms, recs, src, per)], src, per)


# ---------------------------------------------------------------- FIDE
def build_fide():
    page = 'Geography_of_chess'
    rev, t = tables(page)
    x = t[0]
    agg = {}
    for _, r in x.iterrows():
        m = re.search(r'\d+', str(r['#GM']))
        n = int(m.group()) if m else 0
        if n == 0:
            continue
        iso = need(R.resolve(clean(r['Country'])), r['Country'])
        agg[iso] = agg.get(iso, 0) + n
    recs = [{'dimensions': {'iso_a3': k}, 'values': {'grandmasters': v}} for k, v in sorted(agg.items(), key=lambda kv: -kv[1])]
    src = WIKI + page
    per = f'FIDE federation grandmaster counts as compiled by Wikipedia (revision {rev}; as-of date not stated, total {sum(agg.values())})'
    write('sports_fide_grandmasters', 'list',
          [table('main', ['iso_a3'], [metric('grandmasters', 'players', src, per)], recs, src, per)], src, per)


# ---------------------------------------------------------------- MLB
MLB = [('Dominican Republic', 93), ('Venezuela', 60), ('Cuba', 20), ('Canada', 19), ('Japan', 14),
       ('Puerto Rico', 14), ('Mexico', 7), ('Curaçao', 4), ('Panama', 4), ('Colombia', 3),
       ('South Korea', 3), ('Aruba', 1), ('Bahamas', 1), ('Honduras', 1), ('Nicaragua', 1), ('Taiwan', 1)]


def build_mlb():
    recs = [{'dimensions': {'iso_a3': need(R.resolve(n), n)}, 'values': {'players': v}} for n, v in MLB]
    src = 'https://www.mlb.com/press-release/press-release-opening-day-rosters-feature-249-internationally-born-players'
    per = '2026 Opening Day rosters and inactive lists (MLB press release, 2026-03-26); players born outside the U.S.'
    write('sports_mlb_international_players', 'list',
          [table('main', ['iso_a3'], [metric('players', 'players', src, per)], recs, src, per)], src, per)


BUILDERS = {'olympics': build_olympics, 'fifa': build_fifa, 'ucl': build_ucl, 'wc': build_wc,
            'tennis': build_tennis, 'fide': build_fide, 'mlb': build_mlb}

if __name__ == '__main__':
    for name in (sys.argv[1:] or BUILDERS):
        BUILDERS[name]()
