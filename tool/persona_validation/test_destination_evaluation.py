import unittest
from evaluate_priority_destinations import (price_basket, probability_spread,
    classify_axis, is_city_page, sections)


class DestinationEvaluationTest(unittest.TestCase):
    def test_namesake_coordinates_must_match(self):
        page={'coordinates':[{'lat':48.856,'lon':2.352}]}
        self.assertTrue(is_city_page(page,{'latitude':48.8566,'longitude':2.3522}))
        self.assertFalse(is_city_page(page,{'latitude':33.66,'longitude':-95.55}))

    def test_incomplete_basket_does_not_become_a_cheap_destination(self):
        self.assertIsNone(price_basket({'byt':{'food':30,'transport':10}}))
        self.assertEqual(price_basket({'byt':{'stay':80,'food':30,'transport':10}})['cost_band'],2)

    def test_probability_spread_distinguishes_adjacent_and_opposing_levels(self):
        self.assertAlmostEqual(probability_spread({'1':.5,'2':.5}),.5)
        self.assertAlmostEqual(probability_spread({'0':.5,'4':.5}),2)
        with self.assertRaises(ValueError): probability_spread({'0':0,'4':0})

    def test_low_concentration_is_not_automatically_missing_evidence(self):
        value={'score':1.5,'confidence':0,'distribution_stddev':.5,'support':.95,'direct_evidence':.95}
        self.assertEqual(classify_axis(value,value,.99,.99),'source_supported_estimate')
        self.assertEqual(classify_axis(value,{**value,'distribution_stddev':1.2},.99,.99),'wide_distribution_review')

    def test_identity_disagreement_and_missing_evidence_are_not_published(self):
        value={'score':2,'distribution_stddev':.5,'support':.95,'direct_evidence':.95}
        self.assertEqual(classify_axis(value,value,.5,.99),'identity_review')
        self.assertEqual(classify_axis(value,{**value,'score':3},.99,.99),'disagreement_review')
        self.assertEqual(classify_axis(value,{**value,'support':.5},.99,.99),'insufficient_evidence')

    def test_safety_is_not_mixed_into_logistical_difficulty(self):
        result=sections({'extract':'Intro\n== Get around ==\nTrain\n== Stay safe ==\nWarnings'})
        self.assertEqual(result['get around'],'Train')
        self.assertNotIn('stay safe',result)


if __name__=='__main__': unittest.main()
