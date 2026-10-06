"""Run with python3 scripts/test_city_scope.py. No model calls or file mutation."""
import copy
import json
import unittest
from datetime import date
from pathlib import Path

from check_city_catalog import check_file


class ScopeContractTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[1]
        self.path = self.root / 'data/cities/jp-tokyo.json'
        self.data = json.loads(self.path.read_text())
        vocab = json.loads((self.root / 'data/experience-categories.json').read_text())
        self.categories = {c['id'] for c in vocab['categories']}
        self.category_version = vocab['version']

    def check(self, data):
        return check_file(self.path, data, self.categories, self.category_version,
                          {'jp-tokyo'}, date(2026, 10, 5))

    def test_known_and_unknown_scope_are_preserved(self):
        self.check(self.data)
        for relation in ('outside', 'unknown'):
            draft = copy.deepcopy(self.data)
            draft['places'][0]['scope_relation'] = relation
            if relation == 'unknown':
                draft['places'][0]['scope_evidence_ids'] = []
            self.check(draft)
            self.assertEqual(draft['places'][0]['scope_relation'], relation)
        # Valid structure does not prove that 'outside' matches the source.

    def test_invalid_scope_and_evidence_are_rejected(self):
        mutations = [
            lambda d: d['experiences'][0]['place_ids'].append('missing-place'),
            lambda d: d['places'].append(copy.deepcopy(d['places'][0])),
            lambda d: d['places'][0].update(scope_relation='far'),
            lambda d: d['places'][0].update(scope_evidence_ids=[]),
            lambda d: d['places'][0].update(scope_evidence_ids=['missing-evidence']),
            lambda d: d['places'][0].update(scope_evidence_ids=['ueno-park-walk']),
            lambda d: d['claims'][0].update(status='unknown'),
            lambda d: d['experiences'][0]['travel_requirements']['boat_required'].update(value=False),
            lambda d: d['experiences'][0]['travel_requirements']['boat_required'].update(value=1),
            lambda d: d['experiences'][0]['travel_requirements']['boat_required'].update(
                value=True, evidence_ids=['asakusa-location']),
            lambda d: d['experiences'][0]['travel_requirements']['overnight_required'].update(
                value=True, evidence_ids=['local-round-trip']),
            lambda d: d['summary'].append(dict(text='Fare', evidence_ids=['ueno-entry-fee'])),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(case=index):
                draft = copy.deepcopy(self.data)
                mutate(draft)
                with self.assertRaises(ValueError):
                    self.check(draft)

    def test_boat_false_requires_evidence_just_like_true(self):
        for value in (False, True):
            draft = copy.deepcopy(self.data)
            next(c for c in draft['claims'] if c['id'] == 'asakusa-rail-access')['usage'] = 'recommendation'
            draft['experiences'][0]['travel_requirements']['boat_required'].update(
                value=value, evidence_ids=['asakusa-rail-access'])
            self.check(draft)
            self.assertIs(draft['experiences'][0]['travel_requirements']['boat_required']['value'], value)
        # Only type/reference checks: whether rail access supports this value needs review.


if __name__ == '__main__':
    unittest.main()
