"""기준표의 모순된 판정과 승인·범위 표시를 검사한다."""
import copy
import unittest

from check_destination_draft import CATALOG, load
from render_grade_anchors import ANCHORS, change_counts, expected, large_change, render, validate


def as_draft(anchors):
    """승인 상태와 무관하게 쓰도록 모든 재검토·경계 행을 draft로 되돌린 복사본."""
    anchors = copy.deepcopy(anchors)
    for row in anchors['calibration']['reassessment'] + anchors['calibration']['boundary_review']:
        row['status'] = 'draft'
    return anchors


def with_pending_sports_choice(anchors):
    """바르셀로나 스포츠를 사람 판정 대기로 두고 런던과의 상위 경계를 붙인 복사본."""
    anchors = as_draft(anchors)
    c = anchors['calibration']
    row = next(r for r in c['reassessment'] if (r['sub'], r['city']) == ('sports', 'es-barcelona'))
    row['proposal'], row['benchmark'] = None, 'hk-hong-kong'
    row['decision'] = {'options': ['choose', 'make_time'], 'question': '윔블던과 같은 수준인가?', 'owner': 'Joe'}
    order = next(b['order'] for b in c['boundary_review'] if b['sub'] == 'sports')
    c['boundary_review'] = [b for b in c['boundary_review'] if (b['sub'], b['boundary']) != ('sports', 'choose')]
    c['boundary_review'].append({'sub': 'sports', 'boundary': 'choose', 'order': order, 'pair': ['gb-london', 'es-barcelona'], 'status': 'draft', 'reason': '사람 판정 대기'})
    return anchors


class GradeAnchorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.anchors = load(ANCHORS)
        cls.catalog = load(CATALOG)

    def test_classification_decision_blocks_boundary_approval(self):
        anchors = copy.deepcopy(self.anchors)
        c = anchors['calibration']
        # 경계 쌍에 들어 있는 도시의 분류를 미결정으로 되돌려 시험한다.
        classification, boundary = next((r, b) for r in c['classification_review'] for b in c['boundary_review'] if b['sub'] == r['sub'] and r['city'] in b['pair'])
        classification['status'] = 'draft'
        boundary['status'] = 'approved'
        with self.assertRaisesRegex(ValueError, '분류 미결정'):
            validate(anchors, self.catalog)
        classification['status'] = 'approved'
        validate(anchors, self.catalog)
        classification['source']['url'] = 'file:///tmp/unverified'
        with self.assertRaisesRegex(ValueError, '출처 URL'):
            validate(anchors, self.catalog)

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
        anchors = as_draft(self.anchors)
        catalog = copy.deepcopy(self.catalog)
        row = anchors['calibration']['reassessment'][0]
        row['status'] = 'approved'
        catalog['cities'][row['city']]['scope'] = '검수 범위 변경'
        # 세부 전체가 승인되면 칸이 접히므로 다른 세부의 경계를 승인한다.
        next(b for b in anchors['calibration']['boundary_review'] if b['sub'] != row['sub'])['status'] = 'approved'
        validate(anchors, catalog)
        output = render(anchors, catalog)
        self.assertIn('- [x] **바르셀로나**', output)
        self.assertIn('- [x] 경계 승인:', output)
        self.assertIn('범위: 검수 범위 변경', output)
        self.assertIn('사람 승인 1쌍', output)

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

    def test_compact_review_keeps_history_out(self):
        output = render(self.anchors, self.catalog)
        reviewed = {b['sub'] for b in self.anchors['calibration']['boundary_review']}
        self.assertLess(len(output.splitlines()), 25 * len(reviewed))
        self.assertIn('grade-anchors-archive-2026-10-18.md', output)
        self.assertNotIn('## 기존 단일 경계 사례', output)
        self.assertNotIn('변경 사유: `rule`', output)
        self.assertEqual(output.count('] 경계 승인:'), len(self.anchors['calibration']['boundary_review']))
        holds = sum(r['proposal'] is None and 'decision' not in r for r in self.anchors['calibration']['reassessment'])
        self.assertEqual(output.count('  - 확인:'), holds)

    def test_rejects_pending_without_action_and_false_adjacency(self):
        mutations = [
            lambda c: next(r for r in c['reassessment'] if r['proposal'] is None)['pending'].pop('question'),
            lambda c: next(r for r in c['reassessment'] if r['proposal'] is None)['pending'].update(next_action=''),
            lambda c: next(r for r in c['reassessment'] if r['proposal'] is None).update(status='approved'),
            lambda c: c['boundary_review'][0].update(pair=['it-milan', 'ca-vancouver']),
            lambda c: c['boundary_review'][0]['order'].pop(),
            lambda c: c['boundary_review'].pop(0),
            lambda c: c['previous_reassessment'].pop(),
        ]
        for mutate in mutations:
            anchors = copy.deepcopy(self.anchors)
            mutate(anchors['calibration'])
            with self.assertRaises(ValueError):
                validate(anchors, self.catalog)

    def test_reassessment_source_is_validated(self):
        for change in ({'url': 'bad'}, {'checked': 'verified'}, {'fact': ''}, {'checked_on': '2026-99-99'}):
            anchors = copy.deepcopy(self.anchors)
            row = next(r for r in anchors['calibration']['reassessment'] if 'source' in r)
            row['source'].update(change)
            with self.assertRaises(ValueError):
                validate(anchors, self.catalog)

    def test_large_changes_both_directions_and_pending(self):
        for before, after in [('choose', 'if_there'), ('if_there', 'choose'), ('none', 'choose')]:
            self.assertTrue(large_change(before, after))
        for before, after in [('choose', 'make_time'), ('if_there', 'if_there'), (None, 'choose'), ('choose', None)]:
            self.assertFalse(large_change(before, after))
        anchors = as_draft(self.anchors)
        row = next(r for r in anchors['calibration']['reassessment'] if r['sub'] == 'sports' and r['city'] == 'es-barcelona')
        prior = next(r for r in anchors['calibration']['previous_reassessment'] if r['sub'] == row['sub'] and r['city'] == row['city'])
        row.pop('decision', None)
        row['proposal'], prior['proposal'] = 'choose', 'if_there'
        output = render(anchors, self.catalog)
        self.assertIn('2단계 이상 변경 · 사람 확인 필수', output)
        self.assertIn('직전 제안 `if_there` → `choose`', output)
        self.assertIn('2단계 이상 변경 1칸(상향·하향에 포함)', output)
        row['status'] = 'approved'
        self.assertIn('2단계 이상 변경 · 사람 확인 완료', render(anchors, self.catalog))

    def test_upper_boundary_and_human_decision(self):
        pending = with_pending_sports_choice(self.anchors)
        validate(pending, self.catalog)
        output = render(pending, self.catalog)
        self.assertEqual(output.count('## sports'), 1)
        self.assertIn('(choose ↔ make_time)', output)
        self.assertIn('사람판정대기 1', output)
        mutations = [
            lambda c: c['boundary_review'].append(copy.deepcopy(c['boundary_review'][-1])),
            lambda c: c['boundary_review'][-1].update(boundary='none'),
            lambda c: c['boundary_review'][-1].update(status='approved'),
            lambda c: next(r for r in c['reassessment'] if 'decision' in r).update(status='approved'),
            lambda c: next(r for r in c['reassessment'] if 'decision' in r)['decision'].update(options=['none', 'choose']),
            lambda c: next(r for r in c['reassessment'] if r.get('sources'))['sources'][0].update(url='bad'),
        ]
        for mutate in mutations:
            anchors = copy.deepcopy(pending)
            mutate(anchors['calibration'])
            with self.assertRaises(ValueError):
                validate(anchors, self.catalog)

    def test_change_counts_keep_pending_separate(self):
        before = {('s', str(i)): value for i, value in enumerate(['if_there', 'choose', 'make_time', 'none', None])}
        rows = [dict(sub='s', city=str(i), proposal=value) for i, value in enumerate(['make_time', 'if_there', 'make_time', None, 'if_there'])]
        self.assertEqual(change_counts(rows, before), {'상향': 1, '하향': 1, '유지': 1, '보류': 1, '이전보류해소': 1, '사람판정대기': 0})

    def test_reassessment_rejects_duplicates_gaps_and_held_benchmarks(self):
        mutations = [
            lambda c: c['reassessment'].append(copy.deepcopy(c['reassessment'][0])),
            lambda c: c['reassessment'].pop(),
            lambda c: c['benchmark_review'].pop(),
            lambda c: c['reassessment'][0].update(benchmark='ae-dubai'),
            lambda c: c['reassessment'][0].update(benchmark='it-milan'),
            lambda c: c['reassessment'][0].update(proposal='none'),
            lambda c: c['reassessment'][0].update(change_basis=''),
        ]
        for mutate in mutations:
            anchors = copy.deepcopy(self.anchors)
            mutate(anchors['calibration'])
            with self.assertRaises(ValueError):
                validate(anchors, self.catalog)


if __name__ == '__main__':
    unittest.main()
