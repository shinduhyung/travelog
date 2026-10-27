import math
import unittest

from calibrate_distribution import adjust, fit_reference, leader


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.rows = [{'scores':{'a':a,'b':1-a}} for a in [.15,.25,.35,.45,.55,.65]]
        self.profile = fit_reference(self.rows)

    def test_no_correction_returns_original(self):
        raw = {'a':.6,'b':.4}
        self.assertEqual(adjust(raw,self.profile,0),raw)

    def test_strong_lead_is_unchanged(self):
        raw = {'a':.95,'b':.05}
        self.assertEqual(adjust(raw,self.profile,1),raw)

    def test_neutral_does_not_invent_a_type(self):
        raw = {'a':.5,'b':.5}
        self.assertEqual(adjust(raw,self.profile,1),raw)
        self.assertEqual(leader(raw),'unresolved')

    def test_finite_normalized_and_order_independent(self):
        a = adjust({'a':.6,'b':.4},self.profile,.85)
        b = adjust({'b':.4,'a':.6},self.profile,.85)
        self.assertEqual(a,b)
        self.assertAlmostEqual(sum(a.values()),1)
        self.assertTrue(all(math.isfinite(v) and v>=0 for v in a.values()))

    def test_zero_score_is_handled(self):
        result = adjust({'a':0,'b':1},self.profile,.85)
        self.assertEqual(result,{'a':0,'b':1})

    def test_batch_population_does_not_change_result(self):
        raw = {'a':.6,'b':.4}
        expected = adjust(raw,self.profile,.85)
        for other in self.rows*10:
            adjust(other['scores'],self.profile,.85)
        self.assertEqual(adjust(raw,self.profile,.85),expected)

    def test_invalid_or_missing_type_scores_rejected(self):
        for raw in [{'a':float('nan'),'b':.5},{'a':-.2,'b':1.2},{'a':.2}, {'a':.2,'b':.2}]:
            with self.assertRaises(ValueError): adjust(raw,self.profile,.85)

    def test_reference_only_contains_supplied_training_rows(self):
        profile = fit_reference(self.rows)
        self.assertEqual(profile['reference_size'],6)
        self.assertEqual(len(profile['reference_log_scores']['a']),6)
        self.assertEqual(profile,fit_reference(list(reversed(self.rows))))


if __name__ == '__main__':
    unittest.main()
