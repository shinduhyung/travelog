"""Export reviewed public destination scores and reconcile all evaluation costs."""
import collections
import json
import math

from evaluate_priority_destinations import OUT, save, DESTINATION, MODEL


def main():
    score=json.loads((OUT/'summary.json').read_text(encoding='utf8'))
    review=json.loads((OUT/'evidence_review/summary.json').read_text(encoding='utf8'))
    rows=json.loads((OUT/'evaluations_reviewed.json').read_text(encoding='utf8'))
    contexts={r['id']:r for r in json.loads((OUT/'contexts.json').read_text(encoding='utf8'))}
    if len(rows)!=753 or review['completed_reviews']!=753 or score['completed_places']!=753:
        raise ValueError('Evaluation or evidence review incomplete')
    if review['controls']['false_positive_context'] or review['controls']['false_negative_context']:
        raise ValueError('Evidence control failed; do not export without review')
    assert len({(r['kind'],r['id']) for r in rows})==753
    kinds=collections.Counter(r['kind'] for r in rows)
    assert kinds=={'country':232,'city':521}
    forbidden={'person_id','uid','email','dna_responses','distinct_visitors','recorded_visits',
               'TYPESAFE_API_KEY','JEV_API_KEY'}
    exports=collections.defaultdict(list)
    statuses=collections.Counter()
    def check(value):
        if isinstance(value,dict):
            assert not(forbidden & set(value))
            for child in value.values():check(child)
        elif isinstance(value,list):
            for child in value:check(child)
        elif isinstance(value,float):assert math.isfinite(value)
    for row in rows:
        links=set(row.get('source_links',[]))
        for source in contexts[row['id']]['sources']:
            for link in source.get('sources',[]):
                if isinstance(link,str) and link.startswith('https://'):links.add(link)
        place={'id':row['id'],'identity':row['identity'],'scores':{},'pending_axes':{},'source_urls':sorted(links)}
        for axis,value in row['axes'].items():
            statuses[value['status']]+=1
            if value['usable_without_more_review']:
                assert -1<=value['normalized_score']<=1
                place['scores'][axis]=value['normalized_score']
            else:
                place['pending_axes'][axis]=value['status']
        exports[row['kind']].append(place)
    for kind,places in exports.items():
        data={'schema_version':2,'model':MODEL,'assessment_date':score['assessment_date'],
              'axes':{k:{'negative':v[0],'positive':v[1]} for k,v in DESTINATION.items()},
              'cost_bands_daily_usd_per_person':[50,100,175,275],
              'policy':'Only consistent, source-backed axes are exported as scores. Missing axes are not neutral.',
              'not_independently_accuracy_validated':True,'places':places}
        check(data)
        save(OUT/f'{kind}_profiles_v2.json',data)
    costs={}
    for kind in ['country','city','control']:
        base=score['billed_including_superseded_pilots'].get(kind,{})
        extra=review['review_costs'].get(kind,{})
        costs[kind]={'requests':base.get('requests',0)+extra.get('requests',0),
            'input_tokens':base.get('input_tokens',0)+extra.get('input_tokens',0),
            'usd':base.get('estimated_usd',0)+extra.get('estimated_usd',0)}
    report={'places':dict(kinds),'scoring_passes_per_place':2,'additional_evidence_review_per_place':1,
        'costs_including_pilots_and_reassessments':costs,
        'total_requests':sum(c['requests'] for c in costs.values()),
        'total_input_tokens':sum(c['input_tokens'] for c in costs.values()),
        'total_usd':sum(c['usd'] for c in costs.values()),
        'price_usd_per_million_input_tokens':.042,
        'pricing_source':'https://docs.typesafe.ai/models',
        'quality_statuses':dict(statuses),'per_kind_quality':review['places'],
        'all_review_flags':review.get('all_review_flags',{}),
        'evidence_controls':review['controls'],
        'usable_axes':statuses['source_backed_consistent_estimate'],
        'pending_axes':sum(n for status,n in statuses.items() if status!='source_backed_consistent_estimate'),
        'model_agreement_is_not_accuracy':True,'not_applied_to_app':True,
        'landmarks_not_evaluated_in_this_run':True,
        'cost_note':'Computed from actual API input token usage at the published rate; not a provider invoice. Free public-source retrieval is excluded.'}
    assert report['usable_axes']+report['pending_axes']==753*4
    save(OUT/'final_report.json',report)
    print(json.dumps(report,ensure_ascii=True,indent=2))


if __name__=='__main__':main()
