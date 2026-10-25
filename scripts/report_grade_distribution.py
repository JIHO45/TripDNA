"""작성 묶음별 등급 분포를 비교해 검토할 세부를 보여준다. 자동 보정은 하지 않는다.

  python3 scripts/report_grade_distribution.py

묶음은 catalog의 provenance(기존 20곳 재판정 / 신규 초안)다. 묶음마다 도시 구성이 달라
분포 차이가 곧 오류는 아니다. 임계값은 정하지 않았고 차이가 큰 순서로 보여준다.
조사 상태 필드는 아직 없어 미조사 비율은 보고하지 않는다.
"""
from collections import Counter

from check_destination_draft import CATALOG, LEVELS, load

BATCH = {'reassessed_pilot': '기존 20곳', 'model_draft': '신규 83곳'}


def share(cities, sub, levels):
    return sum(c['grades'][sub] in levels for c in cities) / len(cities)


def report(catalog):
    batches = {}
    for city in catalog['cities'].values():
        batches.setdefault(BATCH[city['provenance']], []).append(city)
    subs = list(next(iter(catalog['cities'].values()))['grades'])
    lines = ['## 전체 평균 칸 수(도시당)', '', '| 묶음 | 도시 | ' + ' | '.join(LEVELS) + ' |', '|' + ' --- |' * (len(LEVELS) + 2)]
    for name, cities in batches.items():
        counts = Counter(g for c in cities for g in c['grades'].values())
        lines.append(f'| {name} | {len(cities)} | ' + ' | '.join(f'{counts[level] / len(cities):.1f}' for level in LEVELS) + ' |')
    a, b = (batches[name] for name in BATCH.values())
    rows = []
    for sub in subs:
        top_a, top_b = share(a, sub, LEVELS[2:]), share(b, sub, LEVELS[2:])
        ch_a, ch_b = share(a, sub, LEVELS[3:]), share(b, sub, LEVELS[3:])
        rows.append((abs(top_a - top_b), sub, top_a, top_b, ch_a, ch_b))
    rows.sort(reverse=True)
    lines += ['', '## 세부별 비율(차이가 큰 순)', '', '| 세부 | make_time 이상 기존/신규 | choose 기존/신규 |', '| --- | --- | --- |']
    lines += [f'| {sub} | {ta:.0%} / {tb:.0%} | {ca:.0%} / {cb:.0%} |' for _, sub, ta, tb, ca, cb in rows]
    return '\n'.join(lines) + '\n'


def demo():
    city = lambda prov, g: {'provenance': prov, 'grades': {'x': g}}
    data = {'cities': {'a': city('reassessed_pilot', 'choose'), 'b': city('model_draft', 'none'), 'c': city('model_draft', 'make_time')}}
    out = report(data)
    assert '| x | 100% / 50% | 100% / 0% |' in out, out


if __name__ == '__main__':
    demo()
    print(report(load(CATALOG)), end='')
