"""기준표의 모순된 판정과 승인·범위 표시를 검사한다."""
import copy
import unittest

from check_destination_draft import CATALOG, load
from render_grade_anchors import ANCHORS, expected, render, validate


class GradeAnchorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.anchors = load(ANCHORS)
        cls.catalog = load(CATALOG)

    def test_draft_and_boundary_direction(self):
        validate(self.anchors, self.catalog)
        for level, below in [('choose', 'make_time'), ('make_time', 'if_there')]:
            self.assertEqual(expected(level, {'side': 'above'}), level)
            self.assertEqual(expected(level, {'side': 'below'}), below)
        row = self.anchors['subs']['drinks']['make_time']
        self.assertEqual(row['boundary']['city'], 'us-new-york')
        self.assertEqual(expected('make_time', row['boundary']), 'make_time')

    def test_rejects_invalid_anchors(self):
        mutations = [
            lambda a: a['subs'].pop('cafe'),
            lambda a: a['subs'].update(cafe={'undefined': '미조사'}),
            lambda a: a['subs']['cafe']['choose'].update(status='reviewed'),
            lambda a: a['subs']['cafe']['choose']['examples'].pop(),
            lambda a: a['subs']['cafe']['choose']['boundary'].update(city='missing'),
            lambda a: a['subs']['cafe']['choose']['boundary'].update(side='down'),
            lambda a: a['subs']['cafe']['choose']['examples'][0].update(side='below'),
            lambda a: a['subs']['cafe']['choose']['boundary'].update(
                city=a['subs']['cafe']['choose']['examples'][0]['city']),
            # 같은 세부에서 대표 choose와 경계 make_time을 동시에 제안할 수 없다.
            lambda a: a['subs']['cafe']['make_time']['boundary'].update(
                city=a['subs']['cafe']['choose']['examples'][0]['city']),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                anchors = copy.deepcopy(self.anchors)
                mutate(anchors)
                with self.assertRaises(ValueError):
                    validate(anchors, self.catalog)

    def test_approval_marks_and_catalog_scope(self):
        anchors = copy.deepcopy(self.anchors)
        catalog = copy.deepcopy(self.catalog)
        row = anchors['subs']['cafe']['choose']
        row['status'] = 'approved'
        example_city = row['examples'][0]['city']
        boundary_city = row['boundary']['city']
        catalog['cities'][example_city]['scope'] = '대표 사례 범위 변경'
        catalog['cities'][boundary_city]['scope'] = '경계 사례 범위 변경'
        validate(anchors, catalog)
        output = render(anchors, catalog)
        self.assertIn('- [x] **cafe / choose**', output)
        self.assertIn('- [ ] **cafe / make_time**', output)
        self.assertIn('  - 범위: 대표 사례 범위 변경', output)
        self.assertIn('  - 범위: 경계 사례 범위 변경', output)

    def test_rejects_invalid_comparisons(self):
        mutations = [
            lambda c: c['questions'].pop('purpose'),
            lambda c: c['pairs'][0].update(sub='locals'),
            lambda c: c['pairs'][0].update(boundary='none'),
            lambda c: c['pairs'].append(copy.deepcopy(c['pairs'][0])),
            lambda c: c.update(pairs=[p for p in c['pairs'] if not (p['sub'] == 'architecture' and p['boundary'] == 'choose')]),
            lambda c: c['pairs'][0]['cases'].pop(),
            lambda c: c['pairs'][0]['cases'][0].update(city='missing'),
            lambda c: c['pairs'][0]['cases'][0].update(scope='복사한 범위'),
            lambda c: c['pairs'][0]['cases'][0].update(proposal='if_there'),
            lambda c: c['pairs'][0]['cases'][0].update(proposal=None),
            lambda c: c['pairs'][0].update(outcome='split'),
            lambda c: c['pairs'][0].update(outcome='unresolved'),
            lambda c: c['pairs'][2].update(status='approved'),
            lambda c: c['pairs'][0]['comparison'].pop('specificity'),
            lambda c: c['pairs'][0]['cases'][0]['source'].update(checked='verified'),
            lambda c: c['pairs'][0]['cases'][0]['source'].update(url='not-a-url'),
            lambda c: c['pairs'][0]['cases'][0]['source'].update(checked_on='2026-99-99'),
            lambda c: c['pairs'][1]['cases'][0].update(city=c['pairs'][0]['cases'][0]['city']),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                anchors = copy.deepcopy(self.anchors)
                mutate(anchors['calibration'])
                with self.assertRaises(ValueError):
                    validate(anchors, self.catalog)

    def test_same_and_unresolved_do_not_count_as_split(self):
        anchors = copy.deepcopy(self.anchors)
        anchors['calibration']['pairs'] = anchors['calibration']['pairs'][:2]
        unresolved = anchors['calibration']['pairs'][1]
        unresolved['outcome'] = 'unresolved'
        unresolved['cases'][1]['proposal'] = None
        validate(anchors, self.catalog)
        output = render(anchors, self.catalog)
        self.assertIn('양쪽 등급을 가르는 제안 0쌍, 같은 등급 제안 1쌍, 보류 1쌍', output)
        self.assertIn('비교 제안: `보류`', output)
        self.assertIn('검색 발췌', output)
        self.assertIn('비교 결과 반영 전', output)
        pair = anchors['calibration']['pairs'][0]
        pair['outcome'] = 'split'
        pair['cases'][1]['proposal'] = 'make_time'
        validate(anchors, self.catalog)
        self.assertIn('양쪽 등급을 가르는 제안 1쌍', render(anchors, self.catalog))

    def test_comparison_scope_comes_from_catalog(self):
        catalog = copy.deepcopy(self.catalog)
        city = self.anchors['calibration']['pairs'][0]['cases'][0]['city']
        catalog['cities'][city]['scope'] = '비교 쌍 범위 변경'
        comparison_section = render(self.anchors, catalog).split('## 기존 단일 경계 사례')[0]
        self.assertIn('  - 범위: 비교 쌍 범위 변경', comparison_section)

    def test_multiple_pairs_per_boundary_and_reversed_duplicate(self):
        anchors = copy.deepcopy(self.anchors)
        anchors['calibration']['pairs'] = anchors['calibration']['pairs'][:2]
        extra = copy.deepcopy(anchors['calibration']['pairs'][0])
        extra['cases'][1]['city'] = 'ae-dubai'
        anchors['calibration']['pairs'].append(extra)
        validate(anchors, self.catalog)
        output = render(anchors, self.catalog)
        self.assertIn('경계별 상하 제안: 0/2', output)
        extra['cases'].reverse()
        anchors['calibration']['pairs'].append(copy.deepcopy(extra))
        with self.assertRaisesRegex(ValueError, '중복 비교 쌍'):
            validate(anchors, self.catalog)


if __name__ == '__main__':
    unittest.main()
