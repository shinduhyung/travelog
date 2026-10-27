"""Offline tests only: fake responses do not enter the real Jev cache."""
import argparse
import collections
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import jev_catalog as catalog
import jev_pipeline as pipeline


def response(axes, confidence=.8, supported=.95, score=3):
    answers = {}
    for axis in axes:
        answers[axis] = {'type':'score','score':score,'confidence':confidence}
        answers[axis+'__supported'] = {'type':'noul','noul':supported}
    return {'model':catalog.MODEL,'answers':answers,'usage':{'input_tokens':100,'output_tokens':10}}


def person():
    return {'cities':{},'landmark_visited':[],'landmark_ratings':{},'unesco_visited':[],'unesco_ratings':{}}


class JevPipelineTests(unittest.TestCase):
    def test_sign_contract_matches_archetype_anchors(self):
        self.assertEqual(catalog.AXES['landmark_ancient_modern'][1],'ancient or historic')
        self.assertEqual(catalog.AXES['landmark_urban_rural'][2],'rural or wilderness environment')
        self.assertEqual(catalog.AXES['landmark_art_science'][1],'arts and aesthetics')
        self.assertEqual(catalog.AXES['landmark_spiritual_secular'][1],'spiritual or religious')

    def test_unicode_names_do_not_collapse(self):
        self.assertNotEqual(catalog.norm('서울'),catalog.norm('부산'))
        self.assertEqual(catalog.norm('São Paulo'),catalog.norm('Sao Paulo'))

    def test_five_levels_convert_to_signed_axis(self):
        for score,expected in [(0,-1),(2,0),(4,1)]:
            accepted,_ = pipeline.validate_answers({'axes':['cityType']},response(['cityType'],score=score))
            self.assertEqual(accepted['cityType'],expected)

    def test_unknown_is_omitted_not_neutral(self):
        for confidence,supported in [(.1,.95),(.9,.3)]:
            accepted,rejected = pipeline.validate_answers({'axes':['cityType']},response(['cityType'],confidence,supported))
            self.assertFalse(accepted)
            self.assertIn('cityType',rejected)

    def test_invalid_response_cannot_be_used(self):
        for value in [float('nan'),float('inf'),-1,5]:
            with self.assertRaises(ValueError):
                pipeline.validate_answers({'axes':['cityType']},response(['cityType'],score=value))
        bad = response(['cityType'])
        bad['model'] = 'other-model'
        with self.assertRaises(ValueError):
            pipeline.validate_answers({'axes':['cityType']},bad)

    def test_repeated_venues_do_not_overweight_category(self):
        index = collections.defaultdict(list)
        for i in range(10):
            index[('landmark',f'park {i}')].append({'excluded':False,'groups':['theme_park']})
        index[('landmark','temple')].append({'excluded':False,'groups':['religious_site']})
        scores = {'theme_park':{'landmark_culture_nature':1},'religious_site':{'landmark_culture_nature':-1}}
        p = person()
        p['landmark_visited'] = ['park 0','temple']
        a,_ = pipeline.person_axes(p,{},index,{},scores)
        p['landmark_visited'] = [f'park {i}' for i in range(10)]+['temple']
        b,_ = pipeline.person_axes(p,{},index,{},scores)
        self.assertEqual(a,b)

    def test_duplicate_venues_across_unesco_are_not_double_counted(self):
        index = {('landmark','same'):[{'excluded':False,'groups':['museum']}],
                 ('unesco','same'):[{'excluded':False,'groups':['unesco_cultural']}]}
        p = person()
        p['landmark_visited'] = ['same']
        p['unesco_visited'] = ['same']
        result,audit = pipeline.person_axes(p,{},index,{}, {'museum':{'landmark_culture_nature':1},'unesco_cultural':{'landmark_culture_nature':-1}})
        self.assertEqual(result['landmark_culture_nature'],1)
        self.assertEqual(audit['landmark_matched'],1)

    def test_ambiguous_names_are_not_guessed(self):
        index = {('landmark','same'):[{'excluded':False,'groups':['museum']},{'excluded':False,'groups':['zoo']}]}
        self.assertEqual(pipeline.resolve_landmark('same','landmark',index),(None,'ambiguous'))

    def test_low_ratings_never_reverse_preference_sign(self):
        weights = pipeline.rating_weights([('low',1),('high',5),('unrated',0)])
        self.assertTrue(all(0 < v <= 2 for v in weights.values()))
        self.assertLess(weights['low'],weights['high'])

    def test_no_key_stops_before_network(self):
        args = argparse.Namespace(execute=True,limit=5,max_usd=.5)
        with patch.object(pipeline,'read_lines',return_value=[]),patch.object(pipeline,'load_key',return_value=None),patch.object(pipeline.urllib.request,'urlopen') as network:
            with self.assertRaises(SystemExit): pipeline.score_jobs(args)
            network.assert_not_called()

    def test_dry_run_does_not_read_a_key_or_call_api(self):
        args = argparse.Namespace(execute=False,limit=5,max_usd=.5)
        with patch.object(pipeline,'read_lines',return_value=[]),patch.object(pipeline,'load_key') as key,patch.object(pipeline.urllib.request,'urlopen') as network,contextlib.redirect_stdout(io.StringIO()):
            pipeline.score_jobs(args)
            key.assert_not_called()
            network.assert_not_called()

    def test_cache_is_bound_to_payload_and_version(self):
        body = {'model':catalog.MODEL,'state':{'name':'fixture'},'questions':catalog.make_questions(['cityType'])}
        job = {'id':'fixture','axes':['cityType'],'body':body,'fingerprint':catalog.digest([catalog.VERSION,body])}
        catalog.OUT.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=catalog.OUT) as tmp,patch.object(pipeline,'OUT',Path(tmp)):
            self.assertTrue(Path(tmp).resolve().is_relative_to(catalog.OUT.resolve()))
            (Path(tmp)/'cache').mkdir()
            path = Path(tmp)/'cache'/(job['fingerprint']+'.json')
            path.write_text(json.dumps({'job_id':'fixture','fingerprint':job['fingerprint'],'response':response(['cityType'])}),encoding='utf8')
            self.assertIsNotNone(pipeline.read_cache(job))
            job['body']['state']['name'] = 'changed'
            with self.assertRaises(ValueError): pipeline.read_cache(job)

    def test_incomplete_jobs_cannot_generate_500_person_result(self):
        with patch.object(pipeline,'verify_prepared_sources'),patch.object(pipeline,'read_lines',return_value=[{'id':'missing'}]),patch.object(pipeline,'read_cache',return_value=None):
            with self.assertRaisesRegex(SystemExit,'No 500-person Jev result'):
                pipeline.aggregate()

    def test_cached_scores_join_500_fixtures_without_network(self):
        catalog.OUT.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=catalog.OUT) as tmp:
            root = Path(tmp)
            self.assertTrue(root.resolve().is_relative_to(catalog.OUT.resolve()))
            out = root / 'out/jev'
            (out / 'cache').mkdir(parents=True)
            people,cohort = [],[]
            for i in range(500):
                p = person()
                p.update(person_id=f'fixture-{i}',cities={'Paris':{'recorded_visits':1}})
                people.append(p)
                cohort.append({'person_id':p['person_id'],'combined':{'solo_social':.5}})
            pipeline.write_lines(root/'out/users_reduced.jsonl',people)
            pipeline.write_lines(root/'out/vectors.jsonl',cohort)
            body = {'model':catalog.MODEL,'state':{'name':'Paris'},'questions':catalog.make_questions(['cityType','cityNightlife'])}
            job = {'id':'city/FR:paris','kind':'city','target':'FR:paris','axes':['cityType','cityNightlife'],
                   'body':body,'fingerprint':catalog.digest([catalog.VERSION,body])}
            pipeline.write_lines(out/'requests.jsonl',[job])
            fixtures = {
                'cities.json':[{'id':'FR:paris','aliases':['Paris']}],
                'landmark_mapping.json':[], 'cohort.json':cohort,
                'preparation_summary.json':{
                    'source_reduced_sha256':pipeline.file_hash(root/'out/users_reduced.jsonl'),
                    'source_vectors_sha256':pipeline.file_hash(root/'out/vectors.jsonl'),
                    'catalog_fingerprint':'synthetic-fixture-only',
                    'cohort_fingerprint':catalog.digest(cohort)},
            }
            for name,value in fixtures.items():
                (out/name).write_text(json.dumps(value),encoding='utf8')
            reply = response(['cityType','cityNightlife'])
            reply['answers']['cityNightlife__supported']['noul'] = .1
            (out/'cache'/(job['fingerprint']+'.json')).write_text(json.dumps({
                'job_id':job['id'],'fingerprint':job['fingerprint'],'response':reply}),encoding='utf8')
            with patch.object(pipeline,'HERE',root),patch.object(pipeline,'OUT',out),patch.object(catalog,'OUT',out),patch.object(pipeline.urllib.request,'urlopen') as network,contextlib.redirect_stdout(io.StringIO()):
                pipeline.aggregate()
                rows = pipeline.read_lines(out/'vectors_500.jsonl')
                self.assertEqual(len(rows),500)
                self.assertEqual(rows[0]['before'],{'solo_social':.5})
                self.assertEqual(rows[0]['after'],{'solo_social':.5,'cityType':.5})
                self.assertEqual(len({r['person_id'] for r in rows}),500)
                summary = json.loads((out/'aggregation_summary.json').read_text(encoding='utf8'))
                self.assertEqual(summary['rejected_job_axes'],{'cityNightlife':1})
                network.assert_not_called()
                with (root/'out/vectors.jsonl').open('a',encoding='utf8') as stream:
                    stream.write(' ')
                with self.assertRaisesRegex(ValueError,'dataset changed'):
                    pipeline.aggregate()

    def test_public_request_catalog_has_no_user_fields_or_old_scores(self):
        cities,mapping,jobs,report = catalog.build_catalog()
        self.assertGreater(len(cities),200)
        self.assertLess(len(cities),400)
        self.assertFalse(report['unresolved_cities'])
        self.assertFalse(report['unknown_tags'])
        forbidden = {'person_id','uid','email','dna_responses','dna_scores','P','W'}
        def walk(value):
            if isinstance(value,dict):
                self.assertFalse(set(value)&forbidden)
                for item in value.values(): walk(item)
            elif isinstance(value,list):
                for item in value: walk(item)
        for job in jobs:
            walk(job['body'])
            self.assertEqual(len(job['body']['questions']),2*len(job['axes']))
        for row in mapping:
            if row.get('reason') == 'food_or_drink_venue': self.assertFalse(row['groups'])
        blocked = {'landmark_crowd','landmark_budget_luxury','landmark_local_tourist','landmark_calm_nightlife'}
        self.assertFalse({a for g in catalog.GROUPS.values() for a in g['axes']}&blocked)


if __name__ == '__main__':
    unittest.main()
