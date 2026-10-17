"""도시 초안의 누락·시즌·출시 오표시를 거부하는 회귀 검사."""
import copy
import json
import subprocess
import sys
import unittest

from check_destination_draft import CATALOG, ROOT, load, unique_object, validate


class DestinationDraftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = load(CATALOG)
        cls.candidates = load(ROOT / 'data/planning/destination-candidates.json')
        cls.pilot = load(ROOT / 'data/exploration/city-draft/draft.json')

    def test_catalog(self):
        validate(self.catalog, self.candidates, self.pilot)

    def test_rejects_invalid_records(self):
        mutations = [
            lambda d: d['cities'].pop('jp-tokyo'),
            lambda d: d['cities']['jp-tokyo']['grades'].pop('dining'),
            lambda d: d['cities']['jp-tokyo']['core'].pop('dining'),
            lambda d: d['cities']['jp-tokyo'].update(candidate_id='jp-kyoto'),
            lambda d: d['cities']['jp-tokyo']['grades'].update(dining=3),
            lambda d: d['cities']['jp-kyoto']['season'].update(festival=[True]),
            lambda d: d['cities']['jp-kyoto']['season'].update(festival=[13]),
            lambda d: d['cities']['jp-kyoto']['season'].update(festival=[5, 5]),
            lambda d: d['cities']['jp-kyoto']['season_unverified'].append('festival'),
            lambda d: d['cities']['sg-singapore']['season_unverified'].remove('sports'),
            lambda d: d['cities']['jp-kyoto']['season_basis'].clear(),
            lambda d: d['cities']['jp-kyoto']['evidence'].update(drinks=['missing-source']),
            lambda d: d['cities']['jp-tokyo']['reassessment']['changed'].clear(),
            lambda d: d['cities']['gb-london']['grades'].update(nightview='choose'),
            lambda d: d.update(release_ready=True),
            lambda d: d['cities']['jp-tokyo'].update(status='reviewed'),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                data = copy.deepcopy(self.catalog)
                mutate(data)
                with self.assertRaises(ValueError):
                    validate(data, self.candidates, self.pilot)

    def test_duplicate_json_key(self):
        with self.assertRaises(ValueError):
            json.loads('{"id": 1, "id": 2}', object_pairs_hook=unique_object)

    def test_release_gate(self):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/check_destination_draft.py'), '--release'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('출시 거부', result.stderr)


if __name__ == '__main__':
    unittest.main()
