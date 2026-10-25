"""등급 기준표를 검사하고 사람이 읽는 표와 경계 사례 검수 목록을 만든다.

  python3 scripts/render_grade_anchors.py   # docs/data/grade-anchors.md 생성

원문은 data/destinations/anchors.json이다. 생성된 md는 손으로 고치지 않는다.
"""
from datetime import date
from urllib.parse import urlparse

from check_destination_draft import CATALOG, ROOT, load

ANCHORS = ROOT / 'data/destinations/anchors.json'
OUT = ROOT / 'docs/data/grade-anchors.md'
TOP = ('choose', 'make_time')
BELOW = {'choose': 'make_time', 'make_time': 'if_there'}
QUESTIONS = ('substitutability', 'purpose', 'specificity')
LEVELS = ('none', 'if_there', 'make_time', 'choose')


def change_counts(records, before):
    counts = dict.fromkeys(('상향', '하향', '유지', '보류', '이전보류해소', '사람판정대기'), 0)
    for row in records:
        previous, proposed = before[(row['sub'], row['city'])], row['proposal']
        if row.get('decision'):
            kind = '사람판정대기'
        elif proposed is None:
            kind = '보류'
        elif previous is None:
            kind = '이전보류해소'
        else:
            delta = LEVELS.index(proposed) - LEVELS.index(previous)
            kind = '상향' if delta > 0 else '하향' if delta < 0 else '유지'
        counts[kind] += 1
    return counts


def large_change(previous, proposed):
    return previous is not None and proposed is not None and abs(LEVELS.index(proposed) - LEVELS.index(previous)) >= 2


def validate(anchors, catalog):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(anchors['schema_version'] == 1 and anchors['status'] == 'draft', 'anchors 상태')
    subs = {s for concept in catalog['concepts'].values() for s in concept['sub']}
    require(set(anchors['subs']) == subs, '기준표 세부 29개와 다름')
    proposals = {}
    for sub, entry in anchors['subs'].items():
        if 'undefined' in entry:
            require(sub == 'locals' and set(entry) == {'undefined'} and entry['undefined'].strip(), f'{sub}: 미정의 표시')
            continue
        require(set(entry) == set(TOP), f'{sub}: choose·make_time만 둔다')
        for level, row in entry.items():
            where = f'{sub}/{level}'
            require(row['status'] in ('draft', 'approved') and row['rule'].strip(), f'{where}: 상태/판정 문장')
            cases = row['examples'] + [row['boundary']]
            require(len(row['examples']) <= 2 and (len(row['examples']) == 2 or row.get('gap', '').strip()), f'{where}: 대표 사례 2개 또는 부족 사유')
            require(row['boundary']['side'] in ('above', 'below'), f'{where}: 경계 판정 방향')
            for case in cases:
                require(case['city'] in catalog['cities'], f"{where}: 없는 도시 {case['city']}")
                require(case['experience'].strip() and case['reason'].strip(), f'{where}: 경험/이유')
                if case is not row['boundary']:
                    require('side' not in case, f'{where}: 대표 사례에 경계 방향을 둘 수 없음')
                key = (sub, case['city'])
                want = expected(level, case)
                require(key not in proposals or proposals[key] == want, f'{where}: 같은 도시·세부의 제안 등급 충돌')
                proposals[key] = want
            require(len({c['city'] for c in cases}) == len(cases), f'{where}: 같은 도시 중복')

    calibration = anchors['calibration']
    require(calibration['status'] == 'draft', '비교표 상태')
    require(set(calibration['questions']) == set(QUESTIONS), '공통 비교 질문 3개')
    require(all(calibration['questions'][q].strip() for q in QUESTIONS), '빈 비교 질문')
    require(calibration['rules'] and all(r.strip() for r in calibration['rules']), '비교 원칙')
    seen, coverage, compared = set(), {}, {}
    for pair in calibration['pairs']:
        sub, boundary = pair['sub'], pair['boundary']
        key = (sub, boundary)
        require(sub in subs - {'locals'} and boundary in TOP, '비교 세부·경계')
        identity = (sub, boundary, tuple(sorted(c['city'] for c in pair['cases'])))
        require(identity not in seen, f'{key}: 중복 비교 쌍')
        seen.add(identity)
        coverage.setdefault(sub, set()).add(boundary)
        require(pair['status'] in ('draft', 'approved'), f'{key}: 비교 상태')
        require(pair['outcome'] in ('split', 'same', 'unresolved'), f'{key}: 비교 결과')
        require(pair['reason'].strip() and pair['remaining'].strip(), f'{key}: 이유·남은 검수')
        require(set(pair['comparison']) == set(QUESTIONS) and all(pair['comparison'][q].strip() for q in QUESTIONS), f'{key}: 비교 답변 3개')
        cases = pair['cases']
        require(len(cases) == 2 and len({c['city'] for c in cases}) == 2, f'{key}: 서로 다른 도시 2곳')
        levels = {boundary, BELOW[boundary]}
        values = [c['proposal'] for c in cases]
        for case in cases:
            require(case['city'] in catalog['cities'] and case['experience'].strip(), f'{key}: 도시·경험')
            require('scope' not in case, f'{key}: 범위는 catalog에서 렌더한다')
            require(case['proposal'] is None or case['proposal'] in levels, f'{key}: 경계 밖 등급')
            source = case['source']
            url = urlparse(source['url'])
            require(url.scheme == 'https' and url.netloc, f'{key}: 출처 URL')
            require(source['checked'] in ('page', 'search_excerpt') and source['fact'].strip(), f'{key}: 출처 확인 수준·사실')
            date.fromisoformat(source['checked_on'])
            ck = (sub, case['city'])
            if case['proposal'] is not None:
                require(ck not in compared or compared[ck] == case['proposal'], f'{key}: 비교 쌍 사이의 등급 충돌')
                compared[ck] = case['proposal']
        if pair['outcome'] == 'split':
            require(set(values) == levels, f'{key}: 경계 양쪽 등급 필요')
        elif pair['outcome'] == 'same':
            require(values[0] is not None and values[0] == values[1], f'{key}: 같은 등급 필요')
        else:
            require(None in values and pair['status'] == 'draft', f'{key}: 보류는 미판정·미승인 상태')
    require(coverage and all(levels == set(TOP) for levels in coverage.values()), '선정 세부마다 두 경계 비교 필요')
    # 이전 비교 쌍(pairs)이 없는 세부도 경계 검수 행이 있으면 다룬다.
    pair_subs = set(coverage)
    coverage = {b['sub'] for b in calibration['boundary_review']}
    require(pair_subs <= coverage and 'locals' not in coverage and coverage <= subs, '검수 세부')
    benchmarks = {}
    expected_benchmarks = {(s, level, c['city']) for s in coverage for level, row in anchors['subs'][s].items() for c in row['examples']}
    for row in calibration['benchmark_review']:
        key = (row['sub'], row['level'], row['city'])
        require(key in expected_benchmarks and key not in benchmarks, '대표 재검토 대상·중복')
        require(row['status'] in ('candidate', 'excluded') and row['reason'].strip(), '대표 재검토 상태·이유')
        benchmarks[key] = row
    require(set(benchmarks) == expected_benchmarks, '대표 재검토 누락')
    reviewed = set()
    targets = {(p['sub'], c['city']) for p in calibration['pairs'] for c in p['cases']}
    for row in calibration['reassessment']:
        key = (row['sub'], row['city'])
        require(row['sub'] in coverage and row['city'] in catalog['cities'] and key not in reviewed, '재검토 대상·중복')
        require(row['proposal'] is None or row['proposal'] in LEVELS[1:], '재검토 등급')
        require(row['change_basis'] in ('rule', 'evidence') and row['reason'].strip(), '재검토 변경 사유')
        required_level = 'choose' if row['proposal'] == 'choose' else 'make_time'
        require(any(s == row['sub'] and level == required_level and cid == row['benchmark'] and b['status'] == 'candidate' for (s, level, cid), b in benchmarks.items()), '사용할 수 없는 기준 후보')
        require(row['status'] in ('draft', 'approved'), '재검토 승인 상태')
        if 'decision' in row:
            decision = row['decision']
            require(row['proposal'] is None and row['status'] == 'draft' and 'pending' not in row, '사람 판정은 미확정 상태')
            require(decision['options'] == ['choose', 'make_time'] and decision['question'].strip() and decision['owner'].strip(), '사람 판정 선택지·질문·담당')
        elif row['proposal'] is None:
            pending = row.get('pending', {})
            require(all(pending.get(k, '').strip() for k in ('question', 'url', 'owner', 'next_action')), '보류 해소 조건 필요')
            require(urlparse(pending['url']).scheme == 'https', '보류 출처 URL')
            require(row['status'] == 'draft', '보류 승인 불가')
        reviewed.add(key)
    require(targets <= reviewed, '재검토 누락')
    classifications = calibration.get('classification_review', [])
    classification_keys = set()
    for row in classifications:
        key = (row['sub'], row['city'])
        require(key in reviewed and key not in classification_keys, '분류 검수 대상·중복')
        require(row['status'] in ('draft', 'approved') and row['proposal'].strip() and row['reason'].strip(), '분류 검수 상태·내용')
        require('source' in row, '분류 사실 근거 필요')
        classification_keys.add(key)
    for row in calibration['benchmark_review'] + calibration['reassessment'] + calibration['boundary_review'] + classifications:
        for source in ([row['source']] if 'source' in row else []) + row.get('sources', []):
            url = urlparse(source['url'])
            require(url.scheme == 'https' and url.netloc, '재검토 출처 URL')
            require(source['checked'] in ('page', 'search_excerpt') and source['fact'].strip(), '재검토 출처 수준·사실')
            date.fromisoformat(source['checked_on'])
    previous = calibration['previous_reassessment']
    prior = [(r['sub'], r['city']) for r in previous]
    require(len(prior) == len(set(prior)) and targets <= set(prior) <= reviewed, '이전 재검토 분모')
    require(all(r['proposal'] is None or r['proposal'] in LEVELS for r in previous), '이전 재검토 등급')
    records = {(r['sub'], r['city']): r for r in calibration['reassessment']}
    boundaries = calibration['boundary_review']
    identities = {(b['sub'], b['boundary']) for b in boundaries}
    require(len(identities) == len(boundaries), '세부·경계 중복')
    require(all((sub, 'make_time') in identities for sub in coverage), '하위 경계 필요')
    for sub in coverage:
        require(len({tuple(b['order']) for b in boundaries if b['sub'] == sub}) == 1, '세부 내 후보 순서 충돌')
    for b in boundaries:
        sub, order, pair = b['sub'], b['order'], b['pair']
        require(b['boundary'] in TOP, '지원하지 않는 경계')
        known = {city for (s, city), r in records.items() if s == sub and (r['proposal'] is not None or 'decision' in r)}
        require(len(order) == len(known) and set(order) == known, '후보 순서 누락·중복')
        require(len(pair) == 2 and all(city in order for city in pair), '경계 후보 도시')
        require(order.index(pair[1]) == order.index(pair[0]) + 1, '인접하지 않은 경계')
        grades = [records[(sub, city)]['proposal'] or records[(sub, city)]['decision']['options'][-1] for city in order]
        require([LEVELS.index(g) for g in grades] == sorted((LEVELS.index(g) for g in grades), reverse=True), '후보 등급 순서')
        for city, level in zip(pair, [b['boundary'], BELOW[b['boundary']]]):
            row = records[(sub, city)]
            require(row['proposal'] == level or level in row.get('decision', {}).get('options', []), '경계 등급')
        require(b['status'] != 'approved' or all(records[(sub, city)]['proposal'] is not None for city in pair), '미판정 경계 승인 불가')
        require(b['status'] in ('draft', 'approved') and b['reason'].strip(), '경계 상태·이유')
        if 'audit' in b:
            audit = b['audit']
            date.fromisoformat(audit['checked_on'])
            require(audit['finding'].strip() and audit['previous_reason'].strip(), '논리 검수 기록')
            if 'resolved_on' in audit:
                date.fromisoformat(audit['resolved_on'])
        if b['status'] == 'approved':
            require(all(r['status'] == 'approved' for r in classifications if r['sub'] == sub and r['city'] in pair), '분류 미결정 경계 승인 불가')


def expected(level, case):
    return BELOW[level] if case.get('side') == 'below' else level


def render(anchors, catalog):
    c = anchors['calibration']
    records = c['reassessment']
    cities = catalog['cities']
    def name(cid):
        return cities[cid]['name']['ko']
    def source(row):
        refs = ([row['source']] if 'source' in row else []) + row.get('sources', [])
        return ''.join(f" [근거]({ref['url']}) ({ref['checked_on']}, {ref['checked']})" for ref in refs)
    current = {(r['sub'], r['city']): cities[r['city']]['grades'][r['sub']] for r in records}
    previous = {(r['sub'], r['city']): r['proposal'] for r in c['previous_reassessment']}
    out = ['# 등급 검수표', '',
           '[원문](../../data/destinations/anchors.json)에서 생성. [판정 규칙](destination-grading.md) · [이전 비교·단일 사례·출처 기록](grade-anchors-archive-2026-10-18.md).', '',
           '2026-10-24: 판정 대상은 그 세부 전체를 좋아하는 여행자다(축구 팬이 아니라 스포츠 직관 선호자). 판정자가 가장 강한 지속적 방문 이유를 조사한 뒤 비교한다. 기존 문장의 빈약함을 하향 근거로 쓰지 않는다. 특정 팬을 가정하지 않되 단일 경험도 충분히 강하면 choose가 될 수 있다. 개수·다양성은 필수 조건이 아니다. 범위는 catalog에서 가져온다. 출처는 사실 근거이며 등급은 비교 판단이다. catalog는 변경하지 않았다.', '',
           f"경계 후보 {len(c['boundary_review'])}쌍, 사람 승인 {sum(b['status'] == 'approved' for b in c['boundary_review'])}쌍. 후보 내 인접성이며 전체 103곳의 인접성·객관적 순위를 뜻하지 않는다. 같은 등급 안의 순서는 검수용 배치다.", '']
    for label, baseline in [('catalog 대비', current), ('직전 제안 대비', previous)]:
        rows = [r for r in records if (r['sub'], r['city']) in baseline]
        jumps = sum(large_change(baseline[(r['sub'], r['city'])], r['proposal']) for r in rows)
        out.append(f'- {label} ({len(rows)}칸): ' + ', '.join(f'{k} {v}' for k, v in change_counts(rows, baseline).items()) + f'. 별도: 2단계 이상 변경 {jumps}칸(상향·하향에 포함).')
    out += ['', '승인은 원문의 해당 reassessment 또는 boundary_review 행 status를 approved로 바꾸고 재렌더한다. 기준 후보 채택은 사람 승인이 아니다. 이전 보류 해소는 상향·하향과 구분한다. 2단계 이상 변경은 반드시 사람이 전후 등급과 조사 근거를 확인한 뒤 해당 행을 승인한다.', '']
    audited = [b for b in c['boundary_review'] if 'audit' in b and 'resolved_on' not in b['audit']]
    if audited:
        out += [f"논리 점검 {len(audited)}쌍: 아래 경계 문장은 확정 근거가 아니라 재비교할 쟁점이다. 칸별 등급·이유도 재판정 전 초안이며 승인한 것이 아니다. 새 사실 근거가 붙은 경계는 {sum('source' in b for b in audited)}쌍이며 나머지는 새 출처 대조를 하지 않았다. 기존 값 일치율·하향 방향은 정확성의 증거가 아니다.", '']
    if c.get('classification_review'):
        out += ['## 먼저 결정할 분류', '']
        for r in c['classification_review']:
            out += [f"- [{'x' if r['status'] == 'approved' else ' '}] **{r['sub']} · {name(r['city'])}: {r['proposal']}** — {r['reason']}" + source(r)]
        pending = sum(r['status'] != 'approved' for r in c['classification_review'])
        out += ['', f'미결정 분류 {pending}건. 제외 결정은 도시 전체 등급의 하향을 뜻하지 않는다. 분류가 미결정인 해당 경계는 승인할 수 없다.', '']
    for sub in dict.fromkeys(b['sub'] for b in c['boundary_review']):
        sub_boundaries = [b for b in c['boundary_review'] if b['sub'] == sub]
        b = sub_boundaries[0]
        out += [f'## {sub}', '']
        for r in c['benchmark_review']:
            if r['sub'] == sub and r['status'] == 'candidate':
                out.append(f"- 기준 `{r['level']}`: **{name(r['city'])}** — {r['reason']}" + source(r))
        excluded = [name(r['city']) for r in c['benchmark_review'] if r['sub'] == sub and r['status'] == 'excluded']
        if excluded:
            out.append('\n기준점 미채택(등급 보류 아님): ' + ', '.join(excluded) + '. 사유는 원문 참조.')
        out += ['', '후보 순서(미판정은 하위 선택지 위치에 잠정 배치): ' + ' → '.join(name(cid) for cid in b['order']) + '.', '']
        for boundary in sub_boundaries:
            upper = boundary['boundary']
            pending = any(r.get('decision') for r in records if r['sub'] == sub and r['city'] in boundary['pair'])
            label = '사람 판정 필요' if pending else '경계 승인'
            out += [f"- [{'x' if boundary['status'] == 'approved' else ' '}] {label}: **{name(boundary['pair'][0])} ↔ {name(boundary['pair'][1])} ({upper} ↔ {BELOW[upper]})** — {boundary['reason']}" + source(boundary), '']
            if 'audit' in boundary and 'resolved_on' not in boundary['audit']:
                out.append(f"  - 검수 쟁점: {boundary['audit']['finding']}")
            if 'source' in boundary:
                out.append(f"  - 확인한 사실: {boundary['source']['fact']}")
        rows = [r for r in records if r['sub'] == sub]
        if all(x['status'] == 'approved' for x in sub_boundaries):
            done = [r for r in rows if r['status'] == 'approved']
            out += [f"승인 완료 칸 {len(done)}개는 원문에 있다. 남은 칸만 아래에 보인다.", '']
            rows = [r for r in rows if r['status'] != 'approved']
        for r in rows:
            out.append(f"- [{'x' if r['status'] == 'approved' else ' '}] **{name(r['city'])}**: `{r['proposal'] or ('사람 판정 필요' if 'decision' in r else '보류')}` (현재 `{current[(sub, r['city'])]}`) — {r['reason']}" + source(r))
            if not r['reason'].startswith('기준점'):
                out.append(f"  - 범위: {cities[r['city']]['scope']}")
            key = (sub, r['city'])
            jumps = [f"{label} `{baseline[key]}` → `{r['proposal']}`"
                     for label, baseline in [('catalog', current), ('직전 제안', previous)]
                     if large_change(baseline.get(key), r['proposal'])]
            if jumps:
                state = '사람 확인 완료' if r['status'] == 'approved' else '사람 확인 필수'
                out.append(f"  - **2단계 이상 변경 · {state}**: " + '; '.join(jumps))
            if 'decision' in r:
                q = r['decision']
                out.append(f"  - 판정: {' ↔ '.join(q['options'])} · {q['question']} · 담당: {q['owner']}")
            elif r['proposal'] is None:
                q = r['pending']
                out.append(f"  - 확인: {q['question']} [출처]({q['url']}) · 담당: {q['owner']} · 다음 조치: {q['next_action']}")
        out.append('')
    return '\n'.join(out).rstrip('\n') + '\n'


def main():
    anchors, catalog = load(ANCHORS), load(CATALOG)
    validate(anchors, catalog)
    OUT.write_text(render(anchors, catalog))
    print(f'기준표 통과, {OUT.relative_to(ROOT)} 생성')


if __name__ == '__main__':
    main()
