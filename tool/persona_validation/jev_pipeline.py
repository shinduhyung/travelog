"""Prepare public Jev requests, run a key-gated pilot, and join cached scores locally.

python tool/persona_validation/jev_pipeline.py prepare
python tool/persona_validation/jev_pipeline.py score --execute --limit 5
python tool/persona_validation/jev_pipeline.py aggregate

The score command reads TYPESAFE_API_KEY (or JEV_API_KEY) from environment/.env.
Only score --execute can make HTTP requests. prepare and aggregate are offline.
"""
import argparse
import collections
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import urllib.error
import urllib.request

from jev_catalog import (AXES, CITY_AXES, GROUPS, HERE, LANDMARK_AXES, MODEL,
                         OUT, ROOT, VERSION, build_catalog, digest, norm,
                         write_json)

MIN_CONFIDENCE = .35
MIN_SUPPORTED = .75
PRICE_PER_MILLION = .042
ENDPOINT = 'https://api.typesafe.ai/v1/systemone'


def read_lines(path):
    with Path(path).open(encoding='utf-8-sig') as stream:
        return [json.loads(line) for line in stream if line.strip()]


def write_lines(path, rows):
    with Path(path).open('w',encoding='utf8') as stream:
        for row in rows:
            stream.write(json.dumps(row,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')


def finite(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)


def file_hash(path):
    sha = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):
            sha.update(chunk)
    return sha.hexdigest()


def verify_prepared_sources():
    report = json.loads((OUT / 'preparation_summary.json').read_text(encoding='utf8'))
    if report['source_reduced_sha256'] != file_hash(HERE / 'out/users_reduced.jsonl') or \
       report['source_vectors_sha256'] != file_hash(HERE / 'out/vectors.jsonl'):
        raise ValueError('User dataset changed since prepare; prepare again before joining scores')
    cohort = json.loads((OUT / 'cohort.json').read_text(encoding='utf8'))
    if report['cohort_fingerprint'] != digest(cohort):
        raise ValueError('Frozen cohort fingerprint changed')


def validate_answers(job, response):
    if response.get('model') != MODEL:
        raise ValueError('Unexpected response model; review before mixing model versions')
    answers = response.get('answers',{})
    accepted, rejected = {}, {}
    for axis in job['axes']:
        answer, support = answers.get(axis,{}), answers.get(axis+'__supported',{})
        if answer.get('type') != 'score' or support.get('type') != 'noul':
            raise ValueError(f'Missing or invalid answer type for {axis}')
        score, confidence, supported = answer.get('score'), answer.get('confidence'), support.get('noul')
        if not (finite(score) and 0 <= score <= 4 and finite(confidence) and 0 <= confidence <= 1 and
                finite(supported) and 0 <= supported <= 1):
            raise ValueError(f'Invalid numeric answer for {axis}')
        if confidence < MIN_CONFIDENCE or supported < MIN_SUPPORTED:
            rejected[axis] = {'confidence':confidence,'supported':supported}
        else:
            accepted[axis] = score / 2 - 1
    return accepted, rejected


def resolve_landmark(name, source, index):
    candidates = index.get((source,norm(name)),[])
    if not candidates:
        return None, 'unmatched'
    signatures = {(r['excluded'],tuple(r['groups'])) for r in candidates}
    if len(signatures) != 1:
        return None, 'ambiguous'
    row = candidates[0]
    return row, 'excluded' if row['excluded'] else 'matched'


def prepare():
    cities, mapping, jobs, report = build_catalog()
    vectors = read_lines(HERE / 'out/vectors.jsonl')
    cohort = [r for r in vectors if r['dna'] and r['travel']]
    if len(cohort) != 500:
        raise ValueError(f'Expected the previously audited 500-person cohort, found {len(cohort)}. Review cohort changes explicitly.')
    people = {r['person_id']:r for r in read_lines(HERE / 'out/users_reduced.jsonl')}
    city_index = collections.defaultdict(set)
    for city in cities:
        for name in city['aliases']:
            city_index[norm(name)].add(city['id'])
    lm_index = collections.defaultdict(list)
    for row in mapping:
        lm_index[(row['source'],row['match_key'])].append(row)
    city_total = city_matched = lm_total = lm_matched = 0
    users_with_city = users_with_landmark = users_with_any = 0
    unmatched_cities = collections.Counter()
    landmark_status = collections.Counter()
    for row in cohort:
        person = people[row['person_id']]
        matches = 0
        for name, v in person['cities'].items():
            if not v['recorded_visits'] or v.get('hasLived') or name == person.get('homeCityName'):
                continue
            city_total += 1
            if len(city_index.get(norm(name),[])) == 1:
                city_matched += 1
                matches += 1
            else:
                unmatched_cities[name] += 1
        users_with_city += matches > 0
        city_has_match = matches > 0
        seen = set()
        matches = 0
        for source, key in [('landmark','landmark_visited'),('unesco','unesco_visited')]:
            for name in person[key]:
                if norm(name) in seen:
                    continue
                seen.add(norm(name))
                lm_total += 1
                record, status = resolve_landmark(name,source,lm_index)
                if record and not record['excluded'] and not record['groups']:
                    status = 'unclassified'
                landmark_status[status] += 1
                if status == 'matched':
                    lm_matched += 1
                    matches += 1
        users_with_landmark += matches > 0
        users_with_any += city_has_match or matches > 0
    report.update({
        'status':'READY_FOR_API_KEY_NO_REQUESTS_SENT',
        'model':MODEL,'catalog_version':VERSION,'cohort_users':len(cohort),
        'cohort_fingerprint':digest(cohort),'catalog_fingerprint':digest([cities,mapping,jobs]),
        'source_reduced_sha256':file_hash(HERE / 'out/users_reduced.jsonl'),
        'source_vectors_sha256':file_hash(HERE / 'out/vectors.jsonl'),
        'city_visit_records':city_total,'city_visit_records_matched':city_matched,
        'users_with_catalog_city':users_with_city,
        'landmark_visit_records':lm_total,'landmark_visit_records_classified':lm_matched,
        'users_with_classified_landmark':users_with_landmark,
        'users_with_any_catalog_match':users_with_any,
        'landmark_match_status':dict(landmark_status),
        'request_question_count':sum(len(j['body']['questions']) for j in jobs),
        'request_utf8_bytes':sum(len(json.dumps(j['body'],ensure_ascii=False).encode()) for j in jobs),
        'confidence_gate':MIN_CONFIDENCE,'supported_gate':MIN_SUPPORTED,
        'not_inferred_from_generic_categories':[
            'landmark_crowd','landmark_budget_luxury','landmark_local_tourist','landmark_calm_nightlife'],
        'legacy_online_prompt_direction_conflicts':[
            'landmark_ancient_modern','landmark_urban_rural','landmark_art_science','landmark_spiritual_secular'],
        'limitations':[
            'Catalog shadows the production scorer; no production app assets are overwritten.',
            'Generic category traits cannot provide all ten landmark axes; unknown axes stay absent.',
            'Gate thresholds are initial engineering heuristics, not validated accuracy thresholds.',
            'No independent traveler-type labels. A more balanced result is not proof of accuracy.',
        ],
    })
    write_json('cities.json',cities)
    write_json('landmark_mapping.json',mapping)
    write_json('categories.json',GROUPS)
    write_json('axis_contract.json',{k:{'description':v[0],'negative':v[1],'positive':v[2]} for k,v in AXES.items()})
    write_json('cohort.json',cohort)
    write_json('preparation_summary.json',report)
    write_json('unmatched_cities.json',dict(unmatched_cities.most_common()))
    write_lines(OUT / 'requests.jsonl',jobs)
    print(json.dumps(report,ensure_ascii=True,indent=2))


def load_key():
    for key in ('TYPESAFE_API_KEY','JEV_API_KEY'):
        if os.environ.get(key):
            return os.environ[key].strip()
    path = ROOT / '.env'
    if path.exists():
        values = {}
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            key, sep, value = line.strip().partition('=')
            if sep and key.strip() in ('TYPESAFE_API_KEY','JEV_API_KEY'):
                values[key.strip()] = value.strip().strip('"\'')
        for key in ('TYPESAFE_API_KEY','JEV_API_KEY'):
            if values.get(key):
                return values[key]
    return None


def read_cache(job):
    if job['fingerprint'] != digest([VERSION,job['body']]):
        raise ValueError('Request fingerprint does not match payload')
    path = OUT / 'cache' / (job['fingerprint']+'.json')
    if not path.exists():
        return None
    cached = json.loads(path.read_text(encoding='utf8'))
    if cached.get('fingerprint') != job['fingerprint'] or cached.get('job_id') != job['id']:
        raise ValueError('Cache fingerprint mismatch')
    validate_answers(job,cached['response'])
    return cached


def score_jobs(args):
    jobs = read_lines(OUT / 'requests.jsonl')
    pending = [j for j in jobs if read_cache(j) is None]
    if not args.execute:
        print(json.dumps({'status':'DRY_RUN_NO_NETWORK','total':len(jobs),'pending':len(pending),'pilot_limit':args.limit}))
        return
    key = load_key()
    if not key:
        raise SystemExit('API KEY REQUIRED. Set TYPESAFE_API_KEY in the ignored project .env or environment. No HTTP request was sent.')
    if args.limit < 0 or args.max_usd <= 0:
        raise ValueError('limit must be >=0 (0 means all), max-usd must be >0')
    selected = pending if args.limit == 0 else pending[:args.limit]
    # Mix a few public categories into the first pilot instead of only cities.
    if args.limit and len(pending) > args.limit and args.limit >= 3:
        city = [j for j in pending if j['kind']=='city']
        groups = [j for j in pending if j['kind']=='group']
        preferred_cities = [j for j in city if j['target'] in ('FR:paris','JP:tokyo','US:new york')]
        preferred_groups = [j for j in groups if j['target'] in ('theme_park','zoo')]
        ordered_cities = preferred_cities+[j for j in city if j not in preferred_cities]
        ordered_groups = preferred_groups+[j for j in groups if j not in preferred_groups]
        selected = ordered_cities[:args.limit-2]+ordered_groups[:2]
        selected += [j for j in pending if j not in selected][:args.limit-len(selected)]
    (OUT / 'cache').mkdir(exist_ok=True)
    spent, tokens, done = 0.0, 0, 0
    for job in selected:
        payload = json.dumps(job['body'],ensure_ascii=False).encode('utf8')
        # One UTF-8 byte per token is deliberately conservative for a spend stop.
        estimated_ceiling = len(payload)*PRICE_PER_MILLION/1_000_000
        if spent + estimated_ceiling > args.max_usd:
            raise SystemExit('Spend stop reached before next request')
        request = urllib.request.Request(ENDPOINT,data=payload,method='POST',
            headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(request,timeout=60) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            raise SystemExit(f'Jev HTTP {error.code}; stopped without automatic POST retries') from None
        except (urllib.error.URLError,TimeoutError):
            raise SystemExit('Jev network timeout/error; stopped. The server may have processed this request; check billing before retrying.') from None
        usage = result.get('usage',{}).get('input_tokens')
        # Persist a received response before validating it, so an interrupted or
        # malformed paid response cannot silently trigger the same POST again.
        path = OUT / 'cache' / (job['fingerprint']+'.json')
        cached = {'job_id':job['id'],'fingerprint':job['fingerprint'],'response':result}
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(cached,ensure_ascii=False),encoding='utf8')
        temporary.replace(path)
        if not isinstance(usage,int) or usage < 0:
            write_json('last_unvalidated_response.json',{'job_id':job['id'],'response':result})
            raise SystemExit('Usage missing; stopped for review')
        tokens += usage
        spent += usage*PRICE_PER_MILLION/1_000_000
        write_json('last_run_usage.json',{'requests':done+1,'input_tokens':tokens,'estimated_usd':spent,
                   'price_per_million':PRICE_PER_MILLION,'remaining':len(pending)-done-1})
        accepted, rejected = validate_answers(job,result)
        # Keep the already persisted raw response. Derived gates are recomputed
        # when loading; replacing the same new file twice can hit Windows locks.
        done += 1
        print(json.dumps({'job':job['id'],'accepted':len(accepted),'omitted':len(rejected),'input_tokens':usage}))
    write_json('last_run_usage.json',{'requests':done,'input_tokens':tokens,'estimated_usd':spent,
               'price_per_million':PRICE_PER_MILLION,'remaining':len(pending)-done})
    print(json.dumps({'requests':done,'input_tokens':tokens,'estimated_usd':spent,'remaining':len(pending)-done}))


def rating_weights(items):
    positive = [r for _,r in items if finite(r) and r > 0]
    mean = statistics.mean(positive) if positive else 0
    sd = statistics.pstdev(positive) if len(positive) > 1 else 0
    result = {}
    for key, rating in items:
        result[key] = max(.25,min(2,1+(rating-mean)/(2*sd))) if sd and finite(rating) and rating > 0 else 1.0
    return result


def weighted_mean(items):
    total = sum(w for _,w in items)
    return sum(v*w for v,w in items)/total if total else None


def person_axes(person, city_index, lm_index, city_scores, group_scores):
    city_values = collections.defaultdict(list)
    group_values = collections.defaultdict(list)
    audit = collections.Counter()
    eligible = [(name,v) for name,v in person['cities'].items()
                if v['recorded_visits'] > 0 and not v.get('hasLived') and name != person.get('homeCityName')]
    weights = rating_weights([(k,v.get('rating',0)) for k,v in eligible])
    for name,value in eligible:
        candidates = city_index.get(norm(name),set())
        if len(candidates) != 1:
            audit['city_unmatched_or_ambiguous'] += 1
            continue
        city = next(iter(candidates))
        scores = city_scores.get(city,{})
        if scores:
            audit['cities_used'] += 1
        weight = weights[name] * min(3, math.sqrt(value['recorded_visits']))
        for axis,score in scores.items():
            city_values[axis].append((score,weight))
    seen, visits = set(), []
    for source,key,rating_key in [('landmark','landmark_visited','landmark_ratings'),('unesco','unesco_visited','unesco_ratings')]:
        for name in person[key]:
            match = norm(name)
            if match in seen:
                continue
            seen.add(match)
            record,status = resolve_landmark(name,source,lm_index)
            audit['landmark_'+status] += 1
            if status == 'matched' and record['groups']:
                visits.append((match,record['groups'],person[rating_key].get(name,0)))
    weights = rating_weights([(name,rating) for name,_,rating in visits])
    for name,groups,_ in visits:
        for group in groups:
            for axis,score in group_scores.get(group,{}).items():
                group_values[(group,axis)].append((score,weights[name]/len(groups)))
    # Each category has one bounded vote per axis: a long theme-park checklist
    # cannot outweigh every other category merely through its number of venues.
    landmark_values = collections.defaultdict(list)
    for (group,axis),values in group_values.items():
        landmark_values[axis].append((weighted_mean(values),min(2,sum(w for _,w in values)/len(values))))
    result = {axis:weighted_mean(values) for axis,values in city_values.items()}
    result.update({axis:weighted_mean(values) for axis,values in landmark_values.items()})
    return result,dict(audit)


def aggregate():
    verify_prepared_sources()
    jobs = read_lines(OUT / 'requests.jsonl')
    missing = [j['id'] for j in jobs if read_cache(j) is None]
    if missing:
        raise SystemExit(f'WAITING_FOR_JEV: {len(missing)} uncached public-place jobs. No 500-person Jev result was generated.')
    cities = json.loads((OUT / 'cities.json').read_text(encoding='utf8'))
    mapping = json.loads((OUT / 'landmark_mapping.json').read_text(encoding='utf8'))
    cohort = json.loads((OUT / 'cohort.json').read_text(encoding='utf8'))
    city_index,lm_index = collections.defaultdict(set),collections.defaultdict(list)
    for row in cities:
        for name in row['aliases']:
            city_index[norm(name)].add(row['id'])
    for row in mapping:
        lm_index[(row['source'],row['match_key'])].append(row)
    city_scores,group_scores = {},{}
    rejected = collections.Counter()
    total_input = total_output = 0
    for job in jobs:
        response = read_cache(job)['response']
        accepted,omitted = validate_answers(job,response)
        (city_scores if job['kind']=='city' else group_scores)[job['target']] = accepted
        rejected.update(omitted.keys())
        total_input += response.get('usage',{}).get('input_tokens',0)
        total_output += response.get('usage',{}).get('output_tokens',0)
    people = {r['person_id']:r for r in read_lines(HERE / 'out/users_reduced.jsonl')}
    output, coverage = [],collections.Counter()
    for row in cohort:
        new_axes,audit = person_axes(people[row['person_id']],city_index,lm_index,city_scores,group_scores)
        coverage.update(new_axes.keys())
        output.append({'person_id':row['person_id'],'before':row['combined'],
                       'after':{**row['combined'],**new_axes},'added_axes':new_axes,'evidence':audit})
    if len(output) != 500:
        raise ValueError('Cohort size changed')
    write_lines(OUT / 'vectors_500.jsonl',output)
    prepared = json.loads((OUT / 'preparation_summary.json').read_text(encoding='utf8'))
    write_json('aggregation_summary.json',{'users':len(output),'users_with_new_axes':sum(bool(r['added_axes']) for r in output),
               'catalog_fingerprint':prepared['catalog_fingerprint'],
               'cohort_fingerprint':prepared['cohort_fingerprint'],
               'axis_user_coverage':dict(coverage),'rejected_job_axes':dict(rejected),
               'jev_usage':{'requests':len(jobs),'input_tokens':total_input,'output_tokens':total_output,
                            'estimated_usd':total_input*PRICE_PER_MILLION/1_000_000,'price_per_million':PRICE_PER_MILLION},
               'scored_cities_with_accepted_axes':sum(bool(v) for v in city_scores.values()),
               'scored_categories_with_accepted_axes':sum(bool(v) for v in group_scores.values()),
               'rating_weights':'Positive bounded relative weights; no negative preference inversion.',
               'category_cap':'One bounded category vote per axis; duplicate venue names counted once.',
               'score_fingerprint':digest([read_cache(j) for j in jobs])})
    print(json.dumps({'status':'READY_TO_RERUN_DART','users':len(output),'axis_user_coverage':dict(coverage)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command',required=True)
    commands.add_parser('prepare')
    score = commands.add_parser('score')
    score.add_argument('--execute',action='store_true')
    score.add_argument('--limit',type=int,default=5)
    score.add_argument('--max-usd',type=float,default=.5)
    commands.add_parser('aggregate')
    args = parser.parse_args()
    if args.command == 'prepare': prepare()
    elif args.command == 'score': score_jobs(args)
    else: aggregate()


if __name__ == '__main__':
    main()
