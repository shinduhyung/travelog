"""Stronger fixed-profile distribution adjustment; offline, no runtime quotas.

Fit class offsets on the original 350 training users only, aiming for 10% each.
Preserve original >=80% leads. Keep the moderate profile and original scores.
"""
import collections
import hashlib
import json
import math

from calibrate_distribution import OUT, adjust, leader, validate_scores

TEMPERATURES = (1,.5,.2,.1,.05,.02)
ITERATIONS = 300


def fit_offsets(training, moderate_profile):
    types = moderate_profile['types']
    n = len(training)
    if not n:
        raise ValueError('Training users required')
    for row in training:
        validate_scores(row['scores'],types)
    locked = [r for r in training if max(r['scores'].values()) >= moderate_profile['preserve_top_share']]
    free = [r for r in training if max(r['scores'].values()) < moderate_profile['preserve_top_share']]
    fixed_counts = collections.Counter(leader(r['scores']) for r in locked)
    targets = [n/len(types)-fixed_counts[k] for k in types]
    if not free or min(targets) <= 0:
        raise ValueError('Uniform target conflicts with protected leads; do not change protected users automatically')
    vectors = []
    for row in sorted(free,key=lambda r:r['person_id']):
        scores = adjust(row['scores'],moderate_profile,moderate_profile['strength'])
        vectors.append([math.log(max(scores[k],1e-12)) for k in types])
    offsets = [0.0]*len(types)
    trace = []
    for temperature in TEMPERATURES:
        for _ in range(ITERATIONS):
            totals = [0.0]*len(types)
            for vector in vectors:
                z = [(v+b)/temperature for v,b in zip(vector,offsets)]
                maximum = max(z)
                weights = [math.exp(v-maximum) for v in z]
                total = sum(weights)
                for j in range(len(types)):
                    totals[j] += weights[j]/total
            delta = [temperature*.7*math.log(t/max(c,1e-12)) for t,c in zip(targets,totals)]
            offsets = [b+d for b,d in zip(offsets,delta)]
            center = sum(offsets)/len(offsets)
            offsets = [b-center for b in offsets]
        stage_counts = collections.Counter(fixed_counts)
        for vector in vectors:
            j = max(range(len(types)),key=lambda i:vector[i]+offsets[i])
            stage_counts[types[j]] += 1
        trace.append({'temperature':temperature,'training_counts':{k:stage_counts[k] for k in types}})
    return {'types':types,'offsets':dict(zip(types,offsets)),
            'moderate_profile':moderate_profile,
            'target_share':1/len(types),'protected_training_counts':dict(fixed_counts),
            'adjustable_training_targets':dict(zip(types,targets)),
            'training_stage_trace':trace,
            'meaning':'Product distribution balancing, not verified traveler-type accuracy or calibrated probabilities'}


def balance(scores, profile):
    moderate = profile['moderate_profile']
    validate_scores(scores,profile['types'])
    if leader(scores) == 'unresolved' or max(scores.values()) >= moderate['preserve_top_share']:
        return dict(scores)
    adjusted = adjust(scores,moderate,moderate['strength'])
    logits = {k:math.log(max(adjusted[k],1e-12))+profile['offsets'][k] for k in profile['types']}
    maximum = max(logits.values())
    weights = {k:math.exp(v-maximum) for k,v in logits.items()}
    total = sum(weights.values())
    return {k:v/total for k,v in weights.items()}


def describe(rows, profile):
    original,moderate,strong = collections.Counter(),collections.Counter(),collections.Counter()
    changed_original = changed_moderate = protected = protected_changed = outside_top3 = 0
    reference = profile['moderate_profile']
    for row in rows:
        raw = row['scores']
        a = leader(raw)
        b = leader(adjust(raw,reference,reference['strength']))
        c = leader(balance(raw,profile))
        original[a] += 1
        moderate[b] += 1
        strong[c] += 1
        changed_original += a != c
        changed_moderate += b != c
        outside_top3 += c not in sorted(raw,key=lambda k:(-raw[k],k))[:3]
        if max(raw.values()) >= reference['preserve_top_share']:
            protected += 1
            protected_changed += a != c
    return {'n':len(rows),'original_counts':{k:original[k] for k in profile['types']},
            'moderate_counts':{k:moderate[k] for k in profile['types']},
            'strong_counts':{k:strong[k] for k in profile['types']},
            'strong_min_share':min(strong[k] for k in profile['types'])/len(rows),
            'strong_max_share':max(strong.values())/len(rows),
            'changed_vs_original':changed_original,'changed_vs_moderate':changed_moderate,
            'protected_users':protected,'protected_changed':protected_changed,
            'new_top_outside_original_top3':outside_top3}


def main():
    source = OUT/'results_500.jsonl'
    moderate_path = OUT/'distribution_profile.json'
    moderate = json.loads(moderate_path.read_text(encoding='utf8'))
    if hashlib.sha256(source.read_bytes()).hexdigest() != moderate['source_sha256']:
        raise ValueError('Original Jev score source changed; review and rebuild the reference')
    rows = [json.loads(line) for line in source.read_text(encoding='utf8').splitlines() if line.strip()]
    ids = {r['person_id'] for r in rows}
    train_ids,holdout_ids = set(moderate['training_person_ids']),set(moderate['holdout_person_ids'])
    if len(rows)!=500 or len(ids)!=500 or len(train_ids)!=350 or len(holdout_ids)!=150 or train_ids&holdout_ids or train_ids|holdout_ids!=ids:
        raise ValueError('Original 350/150 cohort split changed')
    training = [r for r in rows if r['person_id'] in train_ids]
    holdout = [r for r in rows if r['person_id'] in holdout_ids]
    profile = fit_offsets(training,moderate)
    profile.update({'source_sha256':moderate['source_sha256'],
                    'moderate_profile_sha256':hashlib.sha256(moderate_path.read_bytes()).hexdigest(),
                    'fit_split':'original 350 training users only; no new split or holdout tuning'})
    report = {'method':'Fixed per-type log-score offsets after the moderate percentile correction',
              'target_share':.1,'preserve_original_top_at_least':moderate['preserve_top_share'],
              'comparisons':{'training':describe(training,profile),'holdout':describe(holdout,profile),'all':describe(rows,profile)},
              'no_api_calls':True,'app_integration':False,'fit_on_holdout':False,
              'limits':['Near-uniform distribution is the explicit product objective, not evidence of higher accuracy.',
                        'Only training distribution is targeted; future users are not forced into quotas.',
                        'This changes many users\' first type. Keep original scores for review and reversibility.',
                        'The protected 80% threshold refers to relative scores, not statistically validated confidence.']}
    for name,value in [('distribution_strong_profile.json',profile),('distribution_strong_comparison.json',report)]:
        (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf8')
    with (OUT/'distribution_strong_results_500.jsonl').open('w',encoding='utf8') as stream:
        for row in sorted(rows,key=lambda r:r['person_id']):
            scores = balance(row['scores'],profile)
            stream.write(json.dumps({'person_id':row['person_id'],'split':'training' if row['person_id'] in train_ids else 'holdout',
                                    'original_top':leader(row['scores']),
                                    'moderate_top':leader(adjust(row['scores'],moderate,moderate['strength'])),
                                    'strong_top':leader(scores),'original_scores':row['scores'],'strong_scores':scores},
                                   separators=(',',':'),allow_nan=False)+'\n')
    print(json.dumps(report,ensure_ascii=True,indent=2))


if __name__ == '__main__':
    main()
