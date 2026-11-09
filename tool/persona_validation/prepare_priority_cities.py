"""Offline scope: top 500 cities by distinct visitors UNION City Tour catalog.

Only aggregate counts and public place identities are exported, never account IDs.
"""
import collections
import json
import sys
from pathlib import Path

from jev_catalog import norm
from pilot_city_knowledge import distance

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'out/priority_cities'
sys.path.insert(0, str(ROOT/'tool/city_travel'))
from city_records import load_cities


def main():
    def read(path):
        return json.loads((ROOT/path).read_text(encoding='utf-8-sig'))
    base = list({json.dumps(c,sort_keys=True):c for c in read('assets/cities15000.json')}.values())
    index = collections.defaultdict(list)
    aliases = {'seville':'sevilla','florence':'firenze'}
    def namekey(name):
        key = norm(name)
        return aliases.get(key,key)
    for city in base:
        index[(namekey(city['name']),city['country_code'])].append(city)
    geo = read('assets/social/cities.json')
    geo_by_name = collections.defaultdict(list)
    for label, row in geo.items():
        geo_by_name[namekey(label)].append(row)
    guides = load_cities()
    memo, places = {}, {}

    def resolve(name, tour=False):
        cache_key = (name,tour)
        if cache_key in memo:
            return memo[cache_key]
        source = None
        if tour and name in guides:
            record = guides[name]
            values = record['values']
            source = {'country_code':record['dimensions']['country_iso'],
                      'latitude':float(values['latitude']),'longitude':float(values['longitude'])}
        elif name in geo:
            row = geo[name]
            source = {'country_code':row[0],'latitude':row[1],'longitude':row[2]}
        if source is None:
            alternatives = geo_by_name.get(namekey(name), [])
            if len(alternatives)==1:
                row = alternatives[0]
                source = {'country_code':row[0],'latitude':row[1],'longitude':row[2]}
        candidates = index.get((namekey(name),source['country_code']),[]) if source else []
        if source and not candidates:
            # App suffixes distinguish namesakes. Remove only this explicit suffix for matching.
            import re
            plain = re.sub(r'\s*\(\d+\)$','',name)
            candidates = index.get((namekey(plain),source['country_code']),[])
        best = min(candidates,key=lambda c:distance(source,c)) if candidates else None
        if best and distance(source,best)<60:
            ident = f"{best['country_code']}|{best['name']}|{best['latitude']}|{best['longitude']}"
            place = {'name':best['name'],'country_code':best['country_code'],
                     'latitude':best['latitude'],'longitude':best['longitude'],'identity_resolved':True}
        elif source:
            ident = f"{source['country_code']}|{name}|{source['latitude']}|{source['longitude']}"
            place = {'name':name,**source,'identity_resolved':True,'base_catalog_match':False}
        else:
            ident = f'UNRESOLVED|{name}'
            place = {'name':name,'identity_resolved':False}
        places.setdefault(ident,place)
        memo[cache_key] = ident
        return ident

    visitors, visits = collections.Counter(), collections.Counter()
    accounts = 0
    path = ROOT/'tool/persona_validation/out/users_reduced.jsonl'
    for line in path.open(encoding='utf-8-sig'):
        row = json.loads(line)
        accounts += 1
        seen = set()
        for name,record in row.get('cities',{}).items():
            count = record.get('recorded_visits',0)
            if count<=0:
                continue
            ident = resolve(name)
            seen.add(ident)
            visits[ident] += count
        visitors.update(seen)
    top = sorted(visitors,key=lambda i:(-visitors[i],i))[:500]
    tours = read('assets/city_tour_links.json')
    tour_ids = {resolve(row['city'],tour=True) for row in tours}
    active_tour_ids = {resolve(row['city'],tour=True) for row in tours if row.get('tours')}
    selected = set(top)|tour_ids
    manifest = []
    for ident in sorted(selected):
        manifest.append({'place_id':ident,**places[ident],
            'distinct_visitors':visitors[ident],'recorded_visits':visits[ident],
            'in_top_500':ident in top,'in_city_tour_catalog':ident in tour_ids,
            'has_tour_links':ident in active_tour_ids})
    report = {'no_api_calls':True,'source_accounts':accounts,
        'ranking_metric':'Distinct visitors with recorded_visits > 0; repeated visits do not inflate rank.',
        'top_city_count':len(top),'city_tour_rows':len(tours),'city_tour_identities':len(tour_ids),
        'city_tour_with_links':len(active_tour_ids),'overlap':len(set(top)&tour_ids),
        'union_count':len(selected),'union_using_nonempty_tours_only':len(set(top)|active_tour_ids),
        'unresolved_identities':[r['name'] for r in manifest if not r['identity_resolved']],
        'city_scoring_axes':4,'city_api_usd_at_3000_to_8000_input_tokens':[round(len(selected)*n*.042/1e6,4) for n in [3000,8000]],
        'notes':['City Tour catalog includes rows without tour links.',
                 'Counts are based on the frozen local export, not live current users.',
                 'Unresolved identities must be reviewed before AI requests.',
                 'No recommendation accuracy claim is made from selecting popular cities.']}
    OUT.mkdir(parents=True,exist_ok=True)
    for name,value in [('manifest.json',manifest),('summary.json',report)]:
        (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(report,ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
