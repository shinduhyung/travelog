"""Offline validation and billing reconciliation of the frozen landmark run."""
import collections
import statistics

from evaluate_landmark_profiles import OUT, BASE, RATE, LANDMARK, SHARED, eligible, read, save


def main():
    jobs=read(OUT/'requests.json')
    records=read(OUT/'catalog.json')
    report=read(OUT/'summary.json')
    data=read(OUT/'profiles.json')
    assert len({j['id'] for j in jobs})==len(jobs)
    assert len(data['places'])==len(records)
    assert sum(report['statuses'][key] for key in ['fully_supported_axes','partially_supported_axes','missing_axes'])==len(records)*3
    assert len({r['id'] for r in records})==len(records)
    assert report['complete'] and report['completed_requests']==len(jobs)
    costs=collections.defaultdict(lambda:{'requests':0,'input_tokens':0,'usd':0})
    for j in jobs:
        response=read(OUT/'cache'/f"{j['id']}.json")['response']
        cost=costs[j['stratum']]
        cost['requests']+=1
        cost['input_tokens']+=response['usage']['input_tokens']
    for cost in costs.values():cost['usd']=cost['input_tokens']*RATE
    assert abs(sum(c['usd'] for c in costs.values())+report.get('evidence_review_usd',0)-report['new_usd'])<1e-8
    progress_logs=['run.log','prefetch.log','prefetch_tail.log','prefetch_middle.log','prefetch_gap.log']
    logged=sum(sum(line.startswith('{"done":') for line in (OUT/name).read_text(encoding='utf8').splitlines())
        for name in progress_logs if (OUT/name).exists())
    assert logged==len(jobs),'Paid completion logs and cached scoring responses disagree'
    report['logged_scoring_completions']=logged
    indexed={r['id']:r for r in records}
    for p in data['places']:
        assert eligible(p['identity'])
        assert all(-1<=v<=1 for v in p['scores'].values())
        if 'reused_profile' in p:
            r=indexed[p['reused_profile']]
            assert r['state']['name'].casefold().strip()==p['identity']['name'].casefold().strip()
            assert sorted(r['state']['countriesIsoA3'])==sorted(p['identity']['countriesIsoA3'])
        for axis,components in p['attribute_components'].items():
            values=[c['score'] for c in components.values() if c['score'] is not None]
            if values:
                assert abs(p['scores'][axis]-sum(values)/len(values))<1e-9
            else:assert axis not in p['scores']
            assert (axis in p['pending_axes'])==(len(values)<len(components))
    for kind in ['landmark','unesco']:
        export={k:v for k,v in data.items() if k!='places'}
        export['places']=[p for p in data['places'] if p['kind']==kind]
        save(OUT/f'{kind}_profiles_v2.json',export)
    answers=read(OUT/'attribute_evaluations.json')
    deltas=[]
    for target,passes in answers.items():
        if 'primary' not in passes or 'audit' not in passes:continue
        for tag,axes in passes['primary'].items():
            for axis,v in axes.items():
                deltas.append(abs(v['raw_score']-passes['audit'][tag][axis]['raw_score']))
    report['cost_by_request_kind']=dict(costs)
    report['repeated_axis_comparisons']=len(deltas)
    report['repeat_mean_absolute_delta_0_to_4']=statistics.mean(deltas) if deltas else None
    report['repeat_delta_over_075']=sum(d>.75 for d in deltas)
    report['final_checks_passed']=True
    report['not_applied_to_app']=True
    report['not_independently_accuracy_validated']=True
    assert report['cumulative_usd']<=2
    save(OUT/'summary.json',report)
    save(OUT/'budget.json',{'cap_usd':2,'prior_usd':report['prior_usd'],'new_usd':report['new_usd'],
        'cumulative_usd':report['cumulative_usd'],'complete':True,'reserved_next_wave_usd':0})
    print(__import__('json').dumps(report,ensure_ascii=True,indent=2))


if __name__=='__main__':main()
