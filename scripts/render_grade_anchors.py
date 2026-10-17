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


def expected(level, case):
    return BELOW[level] if case.get('side') == 'below' else level


def render(anchors, catalog):
    cities = catalog['cities']
    rows = [(sub, level, row) for sub, entry in anchors['subs'].items() if 'undefined' not in entry for level, row in entry.items()]

    def name(cid):
        return f"{cities[cid]['name']['ko']}(`{cid}`)"

    def current(sub, cid):
        return cities[cid]['grades'][sub]

    out = [
        '# 등급 기준표',
        '',
        f"`scripts/render_grade_anchors.py`가 [anchors.json](../../data/destinations/anchors.json)에서 생성한다. 손으로 고치지 않는다. 상태: **{anchors['status']}**, {anchors['author']}. 절차는 [등급 판정 절차](destination-grading.md)다.",
        '',
        '사례는 기준이며 현재 catalog 값의 확인이 아니다. 범위는 catalog의 `scope`를 그대로 보여준다.',
        '',
    ]
    calibration = anchors['calibration']
    pairs = calibration['pairs']
    split = sum(p['outcome'] == 'split' for p in pairs)
    same = sum(p['outcome'] == 'same' for p in pairs)
    boundaries = {(p['sub'], p['boundary']) for p in pairs}
    divided = {(p['sub'], p['boundary']) for p in pairs if p['outcome'] == 'split'}
    out += ['## 공통 질문과 경계 비교 쌍', '',
            f'{len({p["sub"] for p in pairs})}개 세부, {len(pairs)}쌍. 양쪽 등급을 가르는 제안 {split}쌍, 같은 등급 제안 {same}쌍, 보류 {len(pairs) - split - same}쌍. 사람 승인 {sum(p["status"] == "approved" for p in pairs)}쌍.', '',
            f'경계별 상하 제안: {len(divided)}/{len(boundaries)}. 미확보: ' + (', '.join(f'{s}/{b}↔{BELOW[b]}' for s, b in sorted(boundaries - divided)) or '없음') + '.', '',
            '같은 등급 쌍과 보류 쌍은 경계 양쪽을 확보한 것으로 세지 않는다. 기존 단일 사례 초안의 등급과 다를 수 있으며, 비교 결과도 사람 승인 전 제안이다. catalog에는 적용하지 않는다.', '']
    out += [f'- {rule}' for rule in calibration['rules']]
    out += [''] + [f'- {calibration["questions"][q]}' for q in QUESTIONS] + ['']
    for pair in pairs:
        sub = pair['sub']
        out += [f'### {sub}: {pair["boundary"]} ↔ {BELOW[pair["boundary"]]}', '',
                f'상태: `{pair["status"]}`, 결과: `{pair["outcome"]}`.', '']
        for c in pair['cases']:
            source = c['source']
            out += [f'- **{name(c["city"])}** — {c["experience"]}',
                    f'  - 비교 제안: `{c["proposal"] or "보류"}`. 현재 catalog: `{current(sub, c["city"])}`.',
                    f'  - 범위: {cities[c["city"]]["scope"]}',
                    f'  - [공식 출처]({source["url"]}) ({source["checked_on"]}, {"본문" if source["checked"] == "page" else "검색 발췌"}): {source["fact"]}']
        out += [''] + [f'- {calibration["questions"][q]} {pair["comparison"][q]}' for q in QUESTIONS]
        out += [f'- **판정 이유:** {pair["reason"]}', f'- **남은 검수:** {pair["remaining"]}', '']
    out += [
        '## 기존 단일 경계 사례 초안 — 비교 결과 반영 전',
        '',
        '사람이 판정 문장·대표 사례·경계 사례를 함께 검수한 뒤 anchors.json의 해당 등급 `status`를 `approved`로 바꾼다. 체크 표시는 그 행 전체의 승인 상태다. 모델 검수는 승인으로 세지 않는다.',
        '',
        '[2026-10-17 모델 검수 기록](grade-anchors-review-2026-10-17.md): 사실 대조와 판정 제안을 구분하며, catalog 값은 자동 변경하지 않는다.',
        '',
    ]
    for sub, level, row in rows:
        b = row['boundary']
        verdict = expected(level, b)
        out += [
            f"- [{'x' if row['status'] == 'approved' else ' '}] **{sub} / {level}** — {name(b['city'])}: {b['experience']}",
            f"  - 제안: `{verdict}` ({'이 등급' if b['side'] == 'above' else '한 단계 아래'}). 현재 catalog: `{current(sub, b['city'])}`",
            f"  - 이유: {b['reason']}",
            f"  - 범위: {cities[b['city']]['scope']}",
        ]
    mismatch = [(sub, level, case, expected(level, case)) for sub, level, row in rows for case in row['examples'] + [row['boundary']] if current(sub, case['city']) != expected(level, case)]
    out += ['', '## 현재 값과 다른 사례', '', f'기준표 제안과 현재 catalog 등급이 다른 {len(mismatch)}건이다. 재판정 후보이며 자동으로 고치지 않는다.', '', '| 세부 | 도시 | 기준표 | 현재 |', '| --- | --- | --- | --- |']
    out += [f"| {sub} | {name(case['city'])} | `{want}` | `{current(sub, case['city'])}` |" for sub, level, case, want in mismatch]
    out += ['', '## 세부별 기준', '']
    for sub, entry in anchors['subs'].items():
        out.append(f'### {sub}')
        out.append('')
        if 'undefined' in entry:
            out += [entry['undefined'], '']
            continue
        for level in TOP:
            row = entry[level]
            out += [f"**{level}** ({row['status']}): {row['rule']}", '']
            for c in row['examples']:
                out += [f"- 대표: {name(c['city'])} — {c['experience']}. {c['reason']}",
                        f"  - 범위: {cities[c['city']]['scope']}"]
            if row.get('gap'):
                out.append(f"- 대표 부족: {row['gap']}")
            b = row['boundary']
            out += [f"- 경계({b['side']}): {name(b['city'])} — {b['experience']}. {b['reason']}", '']
    return '\n'.join(out) + '\n'


def main():
    anchors, catalog = load(ANCHORS), load(CATALOG)
    validate(anchors, catalog)
    OUT.write_text(render(anchors, catalog))
    print(f'기준표 통과, {OUT.relative_to(ROOT)} 생성')


if __name__ == '__main__':
    main()
