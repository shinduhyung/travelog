"""Export public place lookups and fitted numeric parameters, never user records.

Uses existing Jev caches only; no network calls. Commit the two exported assets,
not the ignored validation output directory.
"""
import collections
import json
import math
from pathlib import Path
import unicodedata

from jev_catalog import FOOD, LODGING, GROUPS, TAG_FIXES, ROOT, norm, digest, read_asset
from landmark_eligibility import POLICY
from jev_pipeline import OUT, read_lines, read_cache, validate_answers


def fold_character(char):
    text = ''.join(c for c in unicodedata.normalize('NFKD',char) if not unicodedata.combining(c)).casefold()
    return ''.join(c if c.isalnum() else ' ' for c in text)


def main():
    cities = json.loads((OUT/'cities.json').read_text(encoding='utf8'))
    mappings = json.loads((OUT/'landmark_mapping.json').read_text(encoding='utf8'))
    trained = json.loads((OUT/'distribution_strong_profile.json').read_text(encoding='utf8'))
    moderate = trained['moderate_profile']
    jobs = read_lines(OUT/'requests.jsonl')
    city_scores,group_scores = {},{}
    for job in jobs:
        cached = read_cache(job)
        if cached is None:
            raise ValueError('All Jev jobs must be cached before exporting app assets')
        accepted,_ = validate_answers(job,cached['response'])
        (city_scores if job['kind']=='city' else group_scores)[job['target']] = accepted
    city_lookup = collections.defaultdict(set)
    names = []
    for row in cities:
        for name in row['aliases']:
            names.append(name)
            city_lookup[norm(name)].add(row['id'])
    by_name = collections.defaultdict(list)
    for row in mappings:
        names.append(row['name'])
        by_name[(row['source'],row['match_key'])].append(row)
    landmark_lookup = {'landmark':{},'unesco':{}}
    for (source,name),rows in by_name.items():
        signatures = {(r['excluded'],tuple(r['groups'])) for r in rows}
        ambiguous = len(signatures) != 1
        landmark_lookup[source][name] = {'groups':[] if ambiguous else rows[0]['groups'],
                                        'excluded':False if ambiguous else rows[0]['excluded'],
                                        'ambiguous':ambiguous}
    names.extend(c['name'] for c in read_asset('cities15000.json'))
    characters = {chr(i) for i in range(32,127)}
    for name in names:
        for char in name:
            characters.update(char+char.upper()+char.lower()+char.casefold())
    places = {
        'schema_version':1,'model_version':'tourism-jev-1.14.0-v1',
        'city_count':len(cities),'category_count':len(group_scores),
        'city_lookup':{k:sorted(v) for k,v in city_lookup.items()},
        'city_axes':city_scores,'landmark_lookup':landmark_lookup,'category_axes':group_scores,
        'fold_characters':{c:fold_character(c) for c in sorted(characters)},
        'name_aliases':{'new york city':'new york','bengaluru':'bangalore',
                        'ho chi minh city':'ho chi minh','saint petersburg':'st petersburg'},
        'tag_aliases':TAG_FIXES,'food_tags':sorted(FOOD),'lodging_tags':sorted(LODGING),
        'eligibility_policy':POLICY,
        'tag_groups':{tag:sorted(k for k,v in GROUPS.items() if tag in v['tags'])
                      for tag in sorted({t for g in GROUPS.values() for t in g['tags'] if t})},
        'axis_contract':json.loads((OUT/'axis_contract.json').read_text(encoding='utf8')),
    }
    distribution = {
        'schema_version':1,'profile_version':'balanced-tourism-v1-stable-cdf',
        'cdf_tolerance':1e-12,
        'types':trained['types'],'offsets':trained['offsets'],
        'percentile_strength':moderate['strength'],'preserve_top_share':moderate['preserve_top_share'],
        'reference_size':moderate['reference_size'],'reference_log_scores':moderate['reference_log_scores'],
        'target_share':trained['target_share'],
    }
    # Explicit allowlist above prevents cohort IDs, visits or answers leaking
    # into the application bundle. Numeric reference marginals are model weights.
    forbidden = {'person_id','training_person_ids','holdout_person_ids','dna_responses',
                 'email','uid','TYPESAFE_API_KEY','JEV_API_KEY'}
    def check(value):
        if isinstance(value,dict):
            if forbidden & value.keys(): raise ValueError('Private field in runtime asset')
            for item in value.values(): check(item)
        elif isinstance(value,list):
            for item in value: check(item)
        elif isinstance(value,float) and not math.isfinite(value):
            raise ValueError('Invalid numeric parameter')
    folder = ROOT/'assets/traveler_type'
    folder.mkdir(exist_ok=True)
    for name,value in [('place_profiles.json',places),('distribution_balance.json',distribution)]:
        check(value)
        value['fingerprint'] = digest(value)
        path = folder/name
        path.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False),encoding='utf8')
        print(json.dumps({'asset':name,'bytes':path.stat().st_size,'fingerprint':value['fingerprint']}))
    # Private parity fixture stays in ignored output, not in app assets.
    from balance_distribution import balance
    golden = []
    for row in read_lines(OUT/'results_500.jsonl'):
        scores = balance(row['scores'],trained)
        golden.append({'person_id':row['person_id'],'scores':scores})
    from jev_pipeline import write_lines
    write_lines(OUT/'app_expected_500.jsonl',golden)


if __name__ == '__main__':
    main()
