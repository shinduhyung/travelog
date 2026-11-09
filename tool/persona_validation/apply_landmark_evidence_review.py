"""Merge independently asked evidence adequacy; never change the actual scores."""
import shutil

from evaluate_landmark_profiles import OUT, BASE, read, save, summarize, RATE
from review_landmark_evidence import OUT as REVIEW, controls


def main():
    jobs=read(REVIEW/'requests.json')
    assert controls(jobs),'Synthetic evidence controls failed'
    evidence={}
    tokens=0
    for j in jobs:
        response=read(REVIEW/'cache'/f"{j['id']}.json")['response']
        tokens+=response['usage']['input_tokens']
        if j['stratum']=='control':continue
        values={key:value['noul'] for key,value in response['answers'].items()}
        assert set(values)==set(j['body']['questions'])
        assert all(isinstance(v,(int,float)) and 0<=v<=1 for v in values.values())
        evidence[j['target']]=values
    primary=read(OUT/'requests.json')
    assert set(evidence)=={j['target'] for j in primary if j['stratum']!='shared' and j['variant']=='primary'}
    for filename in ['summary.json','profiles.json','attribute_evaluations.json']:
        backup=OUT/('before_evidence_review_'+filename)
        if not backup.exists():shutil.copyfile(OUT/filename,backup)
    prior=read(BASE/'revalidation_2usd/summary.json')['cumulative_usd']
    summarize(primary,read(OUT/'catalog.json'),prior,evidence_reviews=evidence)
    report=read(OUT/'summary.json')
    report['base_scoring_usd']=report['new_usd']
    report['evidence_review_usd']=tokens*RATE
    report['evidence_review_requests']=len(jobs)
    report['evidence_review_input_tokens']=tokens
    report['evidence_controls']=read(REVIEW/'controls.json')
    report['evidence_controls'].pop('results',None)
    report['new_usd']+=tokens*RATE
    report['cumulative_usd']+=tokens*RATE
    report['evidence_policy']='Described fixed artworks/buildings/ruins support observational experience; no activities or facilities invented. Unsupported natural-site activities remain missing.'
    report['before_evidence_review_profiles_by_kind']=read(OUT/'before_evidence_review_summary.json')['profiles_by_kind']
    assert report['cumulative_usd']<=2
    save(OUT/'summary.json',report)
    print(__import__('json').dumps(report,ensure_ascii=True,indent=2))


if __name__=='__main__':main()
