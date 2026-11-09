"""Offline completeness, billing and conservative export checks for repeat evaluation."""
import collections
import copy
import statistics

from revalidate_destinations import BASE, OUT, AXES, read, save, RATE


def main():
    jobs = read(OUT/'requests.json')
    rows = read(OUT/'evaluations_reviewed.json')
    report = read(OUT/'summary.json')
    assert len(jobs) == 753*3 == len({j['id'] for j in jobs})
    assert len(rows) == 753 == len({r['id'] for r in rows})
    tokens = 0
    for job in jobs:
        response = read(OUT/'cache'/f"{job['id']}.json")['response']
        assert set(response['answers']) == set(AXES)
        tokens += response['usage']['input_tokens']
    assert abs(tokens*RATE-report['new_usd']) < 1e-9
    assert report['cumulative_usd'] <= 2
    assert report['completed_requests'] == len(jobs)
    original = {r['id']:r for r in read(BASE/'evaluations_reviewed.json')}
    for row in rows:
        for axis,value in row['axes'].items():
            assert len(value['revalidation']) == 3
            if value['usable_without_more_review']:
                assert original[row['id']]['axes'][axis]['usable_without_more_review']
            assert value['score_0_to_4'] == original[row['id']]['axes'][axis]['score_0_to_4']
    indexed = {row['id']:row for row in rows}
    for kind in ['country','city']:
        export = copy.deepcopy(read(BASE/f'{kind}_profiles_v2.json'))
        for place in export['places']:
            current = indexed[place['id']]
            for axis,value in current['axes'].items():
                if not value['usable_without_more_review']:
                    place['scores'].pop(axis,None)
                    place['pending_axes'][axis] = value['status']
        export['revalidation_passes'] = 3
        export['score_policy'] = 'Retain original estimates only when original evidence and all robustness checks pass.'
        save(OUT/f'{kind}_profiles_v2.json', export)
    comparisons = read(OUT/'comparisons.json')
    report['per_axis'] = {}
    for axis in AXES:
        items = [r for r in comparisons if r['axis']==axis]
        report['per_axis'][axis] = {'comparisons':len(items),
            'mean_absolute_delta_0_to_4':statistics.mean(r['delta'] for r in items),
            'delta_over_075':sum(r['delta']>.75 for r in items)}
    report['new_input_tokens'] = tokens
    report['pending_axes'] = len(rows)*4-report['usable_axes']
    report['newly_withheld'] = [{'id':r['id'],'identity':r['identity'],'axis':a,
        'max_delta':max(c['delta'] for c in v['revalidation']),
        'max_distribution_stddev':max(c['distribution_stddev'] for c in v['revalidation'])}
        for r in rows for a,v in r['axes'].items() if v['status']=='revalidation_instability']
    report['completeness_and_budget_checks_passed'] = True
    save(OUT/'summary.json',report)
    save(OUT/'budget.json', {'cap_usd':2.0,'prior_usd':report['prior_including_exploratory_usd'],
        'new_usd':report['new_usd'],'cumulative_usd':report['cumulative_usd'],
        'next_wave_reserved_usd':0,'complete':True})
    print(__import__('json').dumps(report,ensure_ascii=True,indent=2))


if __name__ == '__main__':
    main()
