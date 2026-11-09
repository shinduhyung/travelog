"""Three blinded robustness passes; preserve originals and enforce a cumulative budget."""
import copy
import json
import statistics
from collections import Counter
from pathlib import Path

import pilot_city_knowledge as transport
from evaluate_priority_destinations import OUT as BASE, questions, digest, save, probability_spread

OUT = BASE / 'revalidation_2usd'
AXES = ['nature_culture', 'activity', 'cost', 'difficulty']
RATE = .042 / 1e6
LIMIT = 2.0


def read(path):
    return json.loads(path.read_text(encoding='utf8'))


def spent():
    return sum(read(p)['response']['usage']['input_tokens'] * RATE for p in (OUT/'cache').glob('*.json'))


def main():
    baseline = read(BASE/'final_report.json')['total_usd']
    # Include the earlier exploratory experiments as well, conservatively.
    baseline += .00249018 + .010602522
    contexts = read(BASE/'contexts.json')
    original = read(BASE/'evaluations_reviewed.json')
    jobs = []
    for variant in ['reordered', 'rubric_check', 'sources_only']:
        for context in contexts:
            q = {a: copy.deepcopy(questions(audit=True)[a]) for a in AXES}
            if variant == 'rubric_check':
                for a in AXES:
                    q[a]['instructions'] += (' Independently compare the concrete evidence against every level. '
                        'Rate the typical visitor experience, not the most exceptional attraction. '
                        'Do not infer a city from national averages or a country from its capital.')
            if variant == 'sources_only':
                for a in AXES:
                    q[a]['instructions'] = q[a]['instructions'].replace(
                        'reliable established knowledge may supplement it.',
                        'Use only the supplied sources; do not add remembered facts. Missing evidence is not a balanced score.')
            sources = copy.deepcopy(context['sources'])
            if isinstance(sources, list):
                sources.reverse()
            elif isinstance(sources, dict):
                sources = dict(reversed(list(sources.items())))
            job = {'target': context['id'], 'stratum': context['kind'], 'variant': variant,
                   'body': {'model': transport.MODEL, 'state': {'identity':context['identity'], 'sources':sources}, 'questions':q}}
            job['id'] = digest(job)
            jobs.append(job)
    save(OUT/'requests.json', jobs)
    transport.OUT = OUT
    # Reserve a deliberately inflated UTF-8 byte ceiling for every submitted wave.
    # An uncertain paid request halts the run through the transport's .started guard.
    for i in range(0, len(jobs), 40):
        wave = jobs[i:i+40]
        pending = [j for j in wave if not (OUT/'cache'/f"{j['id']}.json").exists()]
        reserve = sum(len(json.dumps(j['body'], ensure_ascii=False).encode()) + 4096 for j in pending)*RATE*2
        current = spent()
        save(OUT/'budget.json', {'cap_usd':LIMIT,'prior_usd':baseline,'new_usd':current,
             'next_wave_reserved_usd':reserve,'cumulative_usd':baseline+current})
        if baseline + current + reserve > LIMIT:
            print('Budget reserve reached; no further requests submitted.', flush=True)
            break
        transport.run(wave, LIMIT-baseline-current)
    records = []
    deltas = {v: [] for v in ['reordered','rubric_check','sources_only']}
    by_id = {r['id']:r for r in original}
    for job in jobs:
        path = OUT/'cache'/f"{job['id']}.json"
        if not path.exists():
            continue
        answers = read(path)['response']['answers']
        for a in AXES:
            answer = answers[a]
            score = answer['score']
            if not isinstance(score,(int,float)) or not 0 <= score <= 4:
                raise ValueError('Invalid score')
            spread = probability_spread(answer['probabilities'])
            old = by_id[job['target']]['axes'][a]
            delta = abs(score-old['score_0_to_4'])
            deltas[job['variant']].append(delta)
            records.append({'id':job['target'],'kind':job['stratum'],'axis':a,'variant':job['variant'],
                'score':score,'previous_score':old['score_0_to_4'],'delta':delta,'distribution_stddev':spread,
                'previous_usable':old['usable_without_more_review']})
    save(OUT/'comparisons.json', records)
    reviewed = copy.deepcopy(original)
    for row in reviewed:
        for a, value in row['axes'].items():
            checks = [r for r in records if r['id']==row['id'] and r['axis']==a]
            value['revalidation'] = checks
            # Robustness checks can revoke acceptance, never manufacture missing evidence.
            unstable = any(r['delta']>.75 or r['distribution_stddev']>1 for r in checks)
            if unstable and value['usable_without_more_review']:
                value['review_flags'].append('revalidation_instability')
                value['status'] = 'revalidation_instability'
                value['usable_without_more_review'] = False
    save(OUT/'evaluations_reviewed.json', reviewed)
    summary = {'cap_usd':LIMIT,'prior_including_exploratory_usd':baseline,'new_usd':spent(),
        'cumulative_usd':baseline+spent(),'completed_requests':len(records)//4,
        'planned_requests':len(jobs),'passes':{v:{'axis_comparisons':len(ds),
            'mean_absolute_delta_0_to_4':statistics.mean(ds) if ds else None,
            'delta_over_075':sum(d>.75 for d in ds),'delta_at_least_1':sum(d>=1 for d in ds)} for v,ds in deltas.items()},
        'newly_withheld_axes':sum(r['status']=='revalidation_instability' for row in reviewed for r in row['axes'].values()),
        'usable_axes':sum(r['usable_without_more_review'] for row in reviewed for r in row['axes'].values()),
        'statuses':dict(Counter(r['status'] for row in reviewed for r in row['axes'].values())),
        'all_four_usable':{kind:sum(all(v['usable_without_more_review'] for v in r['axes'].values()) for r in reviewed if r['kind']==kind) for kind in ['country','city']},
        'limitations':['Same-model robustness is not independent factual accuracy.',
            'Missing evidence and existing identity/price flags remain withheld.',
            'New reviewed results are separate artifacts; app assets are unchanged.']}
    if summary['cumulative_usd']>LIMIT:
        raise ValueError('Budget exceeded')
    save(OUT/'summary.json',summary)
    print(json.dumps(summary,ensure_ascii=True,indent=2),flush=True)


if __name__ == '__main__':
    main()
