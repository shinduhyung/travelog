"""Offline distribution debiasing experiment; not an accuracy calibration.

Keeps original Jev/persona results, fits only 350 users, evaluates 150 separately.
No API calls, app asset changes, per-batch quotas or online count balancing.
"""
import bisect
import collections
import hashlib
import json
import math
from pathlib import Path
import random

OUT = Path(__file__).resolve().parent / 'out/jev'
SEED = 20261027
TRAIN_SIZE = 350
MAX_TRAIN_SHARE = .25
MIN_TRAIN_SHARE = .02
PRESERVE_TOP_SHARE = .8
GRID = [i/20 for i in range(21)]


def validate_scores(scores, types=None):
    if not isinstance(scores,dict) or not scores:
        raise ValueError('Nonempty score map required')
    if types is not None and set(scores) != set(types):
        raise ValueError('Type keys differ from reference profile')
    if any(not isinstance(v,(int,float)) or isinstance(v,bool) or not math.isfinite(v) or v < 0 for v in scores.values()):
        raise ValueError('Invalid score')
    if not math.isclose(sum(scores.values()),1,abs_tol=1e-8):
        raise ValueError('Input scores must sum to one')


def leader(scores):
    if max(scores.values())-min(scores.values()) < 1e-12:
        return 'unresolved'
    return min(scores,key=lambda k:(-scores[k],k))


def fit_reference(rows):
    if len(rows) < 2:
        raise ValueError('At least two reference users required')
    types = sorted(rows[0]['scores'])
    for row in rows:
        validate_scores(row['scores'],types)
    return {'types':types,'reference_size':len(rows),
            'reference_log_scores':{k:sorted(math.log(max(r['scores'][k],1e-12)) for r in rows) for k in types},
            'preserve_top_share':PRESERVE_TOP_SHARE}


def adjust(scores, profile, strength):
    validate_scores(scores,profile['types'])
    if not 0 <= strength <= 1:
        raise ValueError('Strength outside [0,1]')
    if strength == 0 or leader(scores) == 'unresolved' or max(scores.values()) >= profile['preserve_top_share']:
        return dict(scores)
    logits = {}
    for kind in profile['types']:
        value = math.log(max(scores[kind],1e-12))
        reference = profile['reference_log_scores'][kind]
        if reference[-1]-reference[0] < 1e-12:
            # A constant reference carries no evidence for a rank correction.
            logits[kind] = value
            continue
        left,right = bisect.bisect_left(reference,value),bisect.bisect_right(reference,value)
        percentile = (left+right+1)/(2*(len(reference)+1))
        logit = math.log(percentile/(1-percentile))
        logits[kind] = (1-strength)*value+strength*logit
    maximum = max(logits.values())
    weights = {k:math.exp(v-maximum) for k,v in logits.items()}
    total = sum(weights.values())
    return {k:v/total for k,v in weights.items()}


def counts(rows, profile=None, strength=0):
    return collections.Counter(leader(adjust(r['scores'],profile,strength) if profile else r['scores']) for r in rows)


def choose_strength(training, profile):
    grid = []
    selected = None
    for strength in GRID:
        distribution = counts(training,profile,strength)
        shares = [distribution.get(k,0)/len(training) for k in profile['types']]
        meets = max(shares) <= MAX_TRAIN_SHARE and min(shares) >= MIN_TRAIN_SHARE
        grid.append({'strength':strength,'counts':dict(distribution),
                     'max_share':max(shares),'min_share':min(shares),'meets_train_target':meets})
        if meets and selected is None:
            selected = strength
    # Do not quietly pick an arbitrarily aggressive correction if goals fail.
    if selected is None:
        raise ValueError('No candidate meets the declared training target; review rather than force quotas')
    return selected,grid


def metrics(rows, profile, strength):
    before = counts(rows)
    after = counts(rows,profile,strength)
    changed = top3_changed = strong = strong_changed = 0
    for row in rows:
        raw = row['scores']
        adjusted = adjust(raw,profile,strength)
        b,a = leader(raw),leader(adjusted)
        changed += a != b
        top3_changed += a not in sorted(raw,key=lambda k:(-raw[k],k))[:3]
        if max(raw.values()) >= profile['preserve_top_share']:
            strong += 1
            strong_changed += a != b
    def share_top3(c):
        return sum(v for _,v in c.most_common(3))/len(rows)
    return {'n':len(rows),
            'before_counts':{k:before.get(k,0) for k in profile['types']},
            'after_counts':{k:after.get(k,0) for k in profile['types']},
            'before_max_share':max(before.values())/len(rows),
            'after_max_share':max(after.values())/len(rows),
            'before_top3_share':share_top3(before),'after_top3_share':share_top3(after),
            'changed_top':changed,'new_top_outside_original_top3':top3_changed,
            'original_top_above_80pct':strong,'strong_lead_changed':strong_changed}


def main():
    source = OUT/'results_500.jsonl'
    rows = [json.loads(line) for line in source.read_text(encoding='utf8').splitlines() if line.strip()]
    if len(rows) != 500 or len({r['person_id'] for r in rows}) != 500:
        raise ValueError('Expected the original unique 500-person cohort')
    rows.sort(key=lambda r:r['person_id'])
    random.Random(SEED).shuffle(rows)
    training,holdout = rows[:TRAIN_SIZE],rows[TRAIN_SIZE:]
    profile = fit_reference(training)
    strength,grid = choose_strength(training,profile)
    profile.update({'method':'Smoothed per-type log-score percentile, blended with original log score',
        'strength':strength,'split_seed':SEED,'train_size':len(training),'holdout_size':len(holdout),
        'training_person_ids':sorted(r['person_id'] for r in training),
        'holdout_person_ids':sorted(r['person_id'] for r in holdout),
        'selection':'Smallest grid strength with max training share <=25% and each >=2%; no holdout tuning',
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_method':'Cached Jev place axes + existing production persona scorer',
        'meaning':'Relative distribution adjustment, not calibrated type probabilities or demonstrated accuracy'})
    comparisons = {'training':metrics(training,profile,strength),
                   'holdout':metrics(holdout,profile,strength),'all':metrics(rows,profile,strength)}
    report = {'method':profile['method'],'strength':strength,
        'preserve_original_top_at_least':PRESERVE_TOP_SHARE,
        'comparisons':comparisons,
        'no_api_calls':True,'app_integration':False,'profile_refit_on_holdout':False,
        'limits':['No true traveler-type labels: balance is a product preference, not an accuracy result.',
                  'Reference comes from this app cohort; unseen populations and missingness patterns may differ.',
                  'A stored profile gives each user the same result independent of batch order or class quotas.',
                  'The 80% preservation threshold applies to relative scores, not verified confidence.']}
    for name,value in [('distribution_profile.json',profile),('distribution_comparison.json',report),('distribution_grid.json',grid)]:
        (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf8')
    with (OUT/'distribution_results_500.jsonl').open('w',encoding='utf8') as stream:
        for row in sorted(rows,key=lambda r:r['person_id']):
            raw = row['scores']
            adjusted = adjust(raw,profile,strength)
            stream.write(json.dumps({'person_id':row['person_id'],'split':'training' if row in training else 'holdout',
                'original_top':leader(raw),'calibrated_top':leader(adjusted),
                'original_scores':raw,'calibrated_scores':adjusted,
                'strong_lead_preserved':max(raw.values())>=PRESERVE_TOP_SHARE},separators=(',',':'),allow_nan=False)+'\n')
    print(json.dumps(report,ensure_ascii=True,indent=2))


if __name__ == '__main__':
    main()
