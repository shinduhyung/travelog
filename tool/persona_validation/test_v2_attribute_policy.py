import unittest

from estimate_v2_cost import SHARED, mean_attribute_scores
from landmark_eligibility import eligible, POLICY


class AttributePolicyTest(unittest.TestCase):
    def test_mixed_place_averages_category_and_individual_attributes(self):
        self.assertEqual(
            mean_attribute_scores(['Beach', 'Island'],
                                  {'Beach': {'activity': -1}},
                                  {'Island': {'activity': 1}}),
            {'activity': 0})

    def test_duplicate_tags_do_not_get_extra_weight(self):
        self.assertEqual(
            mean_attribute_scores(['Beach', 'Beach', 'Island'],
                                  {'Beach': {'activity': -1}},
                                  {'Island': {'activity': 1}}),
            {'activity': 0})

    def test_unknown_is_not_neutral(self):
        self.assertEqual(
            mean_attribute_scores(['Beach', 'Island'], {'Beach': {}},
                                  {'Island': {'activity': 1}}),
            {'activity': 1})
        self.assertEqual(mean_attribute_scores(['Beach'], {}, {}), {})

    def test_exceptions_remain_individual(self):
        self.assertTrue({'Island', 'Unique Landscape', 'Museum', 'Statue',
                         'Christian', 'Buddhist', 'Islamic', 'Hindu',
                         'Other Religion'}.isdisjoint(SHARED))
        self.assertTrue({'Zoo', 'Beach', 'Theater', 'Resort'} <= SHARED)

    def test_excluded_attributes_reject_the_entire_mixed_place(self):
        for tag in POLICY['excluded_attributes']:
            self.assertFalse(eligible({'name': 'New place', 'attributes': [tag, 'Museum']}))
            self.assertEqual(mean_attribute_scores([tag, 'Museum'], {}, {'Museum': {'activity': 1}}), {})
            self.assertNotIn(tag, SHARED)

    def test_lake_and_island_allowlists_are_required(self):
        self.assertTrue(eligible({'name': 'Lake Bled', 'attributes': ['Lake']}))
        self.assertFalse(eligible({'name': 'Lake Baikal', 'attributes': ['Lake']}))
        self.assertTrue(eligible({'name': 'Alcatraz', 'attributes': ['Island']}))
        self.assertFalse(eligible({'name': 'Bali', 'attributes': ['Island']}))
        self.assertFalse(eligible({'name': 'Alcatraz', 'attributes': ['Island', 'Sea']}))
        self.assertFalse(eligible({'name': 'Bali', 'attributes': []}))  # UNESCO/name-only bypass


if __name__ == '__main__':
    unittest.main()
