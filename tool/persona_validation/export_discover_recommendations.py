"""Offline public recommendation catalog from reviewed Jev scores and aggregate visits."""
import collections
import csv
import hashlib
import json
import math
import sys
from pathlib import Path
from landmark_eligibility import eligible, POLICY

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/traveler_type/discover_profiles.json'
BASE=ROOT/'tool/persona_validation/out'

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def norm(s):return ' '.join(s.lower().split())
def distance(a,b):
    if not all(isinstance(r.get(k),(int,float)) for r in [a,b] for k in ['latitude','longitude']):return float('inf')
    x,y=math.radians(a['latitude']),math.radians(b['latitude'])
    dl=math.radians(a['longitude']-b['longitude'])
    return 6371*2*math.asin(min(1,math.sqrt(math.sin((x-y)/2)**2+math.cos(x)*math.cos(y)*math.sin(dl/2)**2)))

def main():
    stats=Path(sys.argv[1]) if len(sys.argv)>1 else Path('C:/Users/ahnlee123/Desktop/travelogdata/export/travelog_all_statistics_combined.csv')
    csv_rows=list(csv.DictReader(stats.open(encoding='utf-8-sig',newline='')))
    country_rows=read(ROOT/'assets/countries_light.json')
    by_a3={r['iso_a3']:r for r in country_rows}
    by_name={norm(r['name']):r['iso_a3'] for r in country_rows}
    for a3,r in read(ROOT/'assets/social/geo.json').items():
        if a3 in by_a3:
            for key in ['n','nl']:
                if r.get(key):by_name[norm(r[key])]=a3
    counts=collections.Counter(); accounts=0; unresolved=collections.Counter()
    for line in (BASE/'users_reduced.jsonl').open(encoding='utf8'):
        row=json.loads(line); visited=set()
        for name,value in row.get('countries',{}).items():
            if not value.get('isVisited'):continue
            a3=by_name.get(norm(name))
            if a3:visited.add(a3)
            else:unresolved[name]+=1
        if visited:accounts+=1;counts.update(visited)
    landmarks=read(ROOT/'assets/all_landmarks.json')
    global_ranks={r['name']:r['rank'] for r in read(ROOT/'assets/global_rank.json')}
    lm_index=collections.defaultdict(list)
    for r in landmarks:lm_index[(norm(r['name']),tuple(sorted(r.get('countriesIsoA3',[]))))].append(r)
    manifest=read(BASE/'priority_cities/manifest.json')
    approved={r['place_id'] for r in manifest if r['in_city_tour_catalog']}
    assert len(approved)==202
    sys.path.insert(0,str(ROOT/'tool/city_travel'))
    from city_records import load_cities
    guides=load_cities()
    tours=read(ROOT/'assets/city_tour_links.json')
    tour_aliases=collections.defaultdict(list)
    for tour in tours:
        name=tour['city'];g=guides[name]
        point={k:float(g['values'][k]) for k in ['latitude','longitude']}
        options=[r for r in manifest if r['place_id'] in approved and r['country_code']==g['dimensions']['country_iso']]
        nearest=min(options,key=lambda r:distance(r,point))
        assert distance(nearest,point)<60
        tour_aliases[nearest['place_id']].append(name)
    assert len(tour_aliases)==202
    rates={section:{norm(r['name']):float(r['visit_rate_percent'])/100 for r in csv_rows
        if r['section']==section and r.get('name') and r.get('visit_rate_percent')}
        for section in ['City visit rate >1%','Landmark visit rate >1%']}
    popular=sorted([r for r in csv_rows if r['section']=='Landmark visit rate >1%' and r.get('name')],
                   key=lambda r:(-int(r['visiting_users']),norm(r['name'])))[:500]
    popularity_rank={norm(r['name']):i+1 for i,r in enumerate(popular)}
    assert len(popularity_rank)==500
    name_identities=collections.defaultdict(set)
    for r in landmarks:
        name_identities[norm(r['name'])].add((tuple(sorted(r.get('countriesIsoA3',[]))),r.get('latitude'),r.get('longitude')))
    places=[]
    for kind,path in [('country',BASE/'destination_evaluation/revalidation_2usd/country_profiles_v2.json'),
                      ('city',BASE/'destination_evaluation/revalidation_2usd/city_profiles_v2.json'),
                      ('landmark',BASE/'landmark_evaluation/landmark_profiles_v2.json')]:
        for p in read(path)['places']:
            identity=p['identity'];scores={a:v for a,v in p['scores'].items() if a not in p.get('pending_axes',{})}
            row={'id':p['id'],'kind':kind,'name':identity['name'],'scores':scores,'candidate':False,'visit_rate':0.0}
            if kind=='country':
                c=by_a3[p['id']];row.update(name=c['name'],country=c['iso_a2'],aliases=[identity['name'],c['name']],
                    candidate=True,visit_rate=counts[p['id']]/accounts)
            elif kind=='city':
                row.update(country=identity['country_code'],latitude=identity['latitude'],longitude=identity['longitude'],
                    aliases=sorted(set([identity['name']]+tour_aliases.get(p['id'],[]))),candidate=p['id'] in approved)
                if p['id'] in approved:row['name']=tour_aliases[p['id']][0]
                row['visit_rate']=rates['City visit rate >1%'].get(norm(row['name']),0)
            else:
                candidates=lm_index[(norm(identity['name']),tuple(sorted(identity.get('countriesIsoA3',[]))))]
                candidates=[r for r in candidates if distance(r,identity)<1]
                if not candidates:continue
                source=min(candidates,key=lambda r:distance(r,identity))
                if not eligible(source):continue
                codes=source.get('countriesIsoA3',[])
                row.update(country=by_a3.get(codes[0],{}).get('iso_a2','') if codes else '',
                    latitude=identity['latitude'],longitude=identity['longitude'],aliases=[identity['name']],
                    attributes=source.get('attributes',[]),global_rank=global_ranks.get(source['name'],0))
                row['recommendation_rank']=popularity_rank.get(norm(row['name']),0)
                row['candidate']=0<row['recommendation_rank']<=500 and len(name_identities[norm(row['name'])])==1
                row['visit_rate']=rates['Landmark visit rate >1%'].get(norm(row['name']),0)
            places.append(row)
    assert len({(r['kind'],r['id']) for r in places})==len(places)
    data={'schema_version':1,'model':'jev-1.14.0-reviewed','places':places,'eligibility':POLICY,
          'country_rate_denominator':accounts,'country_rate_source':'distinct visitors from users_reduced; accounts with at least one mapped visited country',
          'statistics_sha256':hashlib.sha256(stats.read_bytes()).hexdigest(),
          'country_popularity_max_bonus':.12,'minimum_ratings_per_domain':5}
    OUT.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'),allow_nan=False),encoding='utf8')
    summary={'no_api_calls':True,'asset_bytes':OUT.stat().st_size,'country_rate_accounts':accounts,
        'unmatched_country_names':dict(unresolved),'candidate_counts':dict(collections.Counter(r['kind'] for r in places if r['candidate'])),
        'candidates_with_two_axes':dict(collections.Counter(r['kind'] for r in places if r['candidate'] and len(r['scores'])>=2)),
        'top500_policy':'CSV distinct visiting_users descending, first 500, then exclusions/ambiguous identities; no backfill.',
        'csv_country_rates_present':False,'csv_rates_used':'City/landmark tie-break only; country rates independently aggregated.'}
    (BASE/'discover_export_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(summary,ensure_ascii=True,indent=2))

if __name__=='__main__':main()
