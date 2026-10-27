import math
import unittest

from balance_distribution import balance, fit_offsets
from calibrate_distribution import fit_reference


class StrongDistributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = [{'person_id':str(i),'scores':{'a':.2+i*.03,'b':.8-i*.03}} for i in range(20)]
        reference = fit_reference(cls.rows)
        reference['strength'] = .85
        cls.profile = fit_offsets(cls.rows,reference)

    def test_strong_and_neutral_results_remain_unchanged(self):
        for scores in [{'a':.95,'b':.05},{'a':.5,'b':.5}]:
            self.assertEqual(balance(scores,self.profile),scores)

    def test_fixed_profile_is_normalized_and_independent_of_batch_order(self):
        raw = {'a':.7,'b':.3}
        expected = balance(raw,self.profile)
        for row in reversed(self.rows):
            balance(row['scores'],self.profile)
        self.assertEqual(balance(raw,self.profile),expected)
        self.assertEqual(balance(dict(reversed(list(raw.items()))),self.profile),expected)
        self.assertAlmostEqual(sum(expected.values()),1)
        self.assertTrue(all(math.isfinite(v) and v>=0 for v in expected.values()))

    def test_infeasible_protected_target_is_not_forced(self):
        rows = [{'person_id':str(i),'scores':{'a':.99,'b':.01}} for i in range(5)]
        with self.assertRaisesRegex(ValueError,'conflicts'):
            fit_offsets(rows,self.profile['moderate_profile'])

    def test_fitted_profile_uses_only_supplied_training_people(self):
        self.assertEqual(len(self.profile['training_stage_trace']),6)
        self.assertAlmostEqual(sum(self.profile['offsets'].values()),0)
        for stage in self.profile['training_stage_trace']:
            self.assertEqual(sum(stage['training_counts'].values()),len(self.rows))


if __name__ == '__main__':
    unittest.main()
