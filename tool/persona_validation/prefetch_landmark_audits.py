"""Prefetch disjoint tail jobs after reserving the entire remaining run budget.

The main worker processes landmark primaries first; these workers populate the
later UNESCO and audit caches. No new manifests or duplicate jobs are created.
"""
import concurrent.futures
import json
import sys

import pilot_city_knowledge as transport
from evaluate_landmark_profiles import OUT, BASE, RATE, read, save, spent


def main():
    jobs=read(OUT/'requests.json')
    prior=read(BASE/'revalidation_2usd/summary.json')['cumulative_usd']
    pending=[j for j in jobs if not (OUT/'cache'/f"{j['id']}.json").exists()]
    actual=spent()
    reserve=sum(len(json.dumps(j['body'],ensure_ascii=False).encode()) for j in pending)*RATE
    # Same deliberately conservative byte planning bound as the HTTP transport.
    # This reserves ALL remaining jobs together, including the active worker.
    bound=prior+actual+reserve
    if bound>1.99:
        raise SystemExit('No concurrent dispatch: full-run budget reservation has insufficient margin.')
    save(OUT/'parallel_budget_reservation.json',{'prior_usd':prior,'actual_new_usd':actual,
        'all_remaining_utf8_reserve_usd':reserve,'conservative_total_usd':bound,
        'cap_usd':2,'pending_jobs':len(pending)})
    if '--gap' in sys.argv:
        groups=[[j for j in pending if j['stratum']=='landmark' and j['variant']=='primary'
                 and '90'<=j['target'].split(':',1)[1]<'a0']]
    elif '--middle' in sys.argv:
        groups=[[j for j in pending if j['stratum']=='landmark' and j['variant']=='primary'
                 and 'a0'<=j['target'].split(':',1)[1]<'c0']]
    elif '--tail' in sys.argv:
        groups=[[j for j in pending if j['stratum']=='landmark' and j['variant']=='primary'
                 and j['target'].split(':',1)[1]>='c0']]
    else:
        groups=[[j for j in pending if j['stratum']=='unesco' and j['variant']=='primary'],
                [j for j in pending if j['stratum']!='shared' and j['variant']=='audit']]
        assert not(set(j['id'] for j in groups[0]) & set(j['id'] for j in groups[1]))
    transport.OUT=OUT
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(transport.run,group,2-prior-actual) for group in groups]
        for future in futures:future.result()
    print('Disjoint tail prefetch complete; all responses cached.',flush=True)


if __name__=='__main__':main()
