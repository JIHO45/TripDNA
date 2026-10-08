"""충족률 매칭의 PC 검증. 입력: data/exploration/coverage-check/{grades,cases}.json.

충족률 = sum(원함 가중치 * 등급) / sum(원함 가중치 * 3). 원하지 않는 항목은 계산에 넣지 않는다.
꼭 원함(2)의 등급이 2 미만이면 후보에서 뺀다. 피하고 싶음(-1)이 3등급인 후보는 같은 충족률 안에서 뒤로 보낸다.
충족률이 같으면 동점이다. LLM·네트워크를 쓰지 않는다.
"""
import itertools
import json
import random
from collections import Counter
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "data/exploration/coverage-check"


def rank(wants, grades):
    """[(충족률, 피하고 싶음 충돌 여부, [도시...])] 를 좋은 순으로 돌려준다. 원함이 없으면 전부 한 동점."""
    pos = {k: w for k, w in wants.items() if w > 0}
    groups = {}
    for city, g in grades.items():
        if any(w == 2 and g[k] < 2 for k, w in pos.items()):
            continue
        rate = Fraction(sum(w * g[k] for k, w in pos.items()), 3 * sum(pos.values())) if pos else Fraction(0)
        clash = any(w < 0 and g[k] == 3 for k, w in wants.items())
        groups.setdefault((rate, clash), []).append(city)
    return [(r, c, sorted(v)) for (r, c), v in sorted(groups.items(), key=lambda x: (-x[0][0], x[0][1]))]


def top_n(ranked, n=3):
    """동점 그룹을 쪼개지 않고 n곳 이상이 될 때까지 담는다."""
    out = []
    for _, _, cities in ranked:
        out += cities
        if len(out) >= n:
            break
    return out


def self_check():
    g = {"a": {"x": 3, "y": 0}, "b": {"x": 1, "y": 3}}
    assert rank({"x": 1}, g)[0][2] == ["a"]  # 원하지 않는 y는 영향 없음
    assert rank({"x": 2}, g) == [(Fraction(1), False, ["a"])]  # 꼭 원함 2등급 미만 제외
    assert rank({"x": 1, "y": 1}, g)[0][2] == ["b"]  # 3/6 < 4/6
    assert rank({}, g)[0][2] == ["a", "b"]  # 원함 없음 = 전부 동점
    assert rank({"x": 1, "y": -1}, {"a": {"x": 3, "y": 3}, "c": {"x": 3, "y": 0}})[0][2] == ["c"]


def structure(grades, cats):
    sets = [c for n in (1, 2, 3) for c in itertools.combinations(cats, n)]
    top1, top3, sizes = Counter(), Counter(), []
    for s in sets:
        r = rank({k: 1 for k in s}, grades)
        sizes.append(len(r[0][2]))
        top1.update(r[0][2])
        top3.update(top_n(r))
    return sets, top1, top3, sizes


def sensitivity(grades, cats, sets, trials=300, p=0.15):
    """등급 칸의 15%를 ±1 바꿨을 때, 원래 1위 그룹이 새 상위 3곳 안에 남는 비율."""
    rnd = random.Random(20261007)
    base = {s: set(rank({k: 1 for k in s}, grades)[0][2]) for s in sets}
    kept = 0
    for _ in range(trials):
        g2 = {c: {k: min(3, max(0, v + (rnd.choice((-1, 1)) if rnd.random() < p else 0))) for k, v in g.items()}
              for c, g in grades.items()}
        kept += sum(bool(base[s] & set(top_n(rank({k: 1 for k in s}, g2)))) for s in sets)
    return kept / (trials * len(sets))


def main():
    self_check()
    data = json.loads((DIR / "grades.json").read_text())
    grades, cats = data["grades"], data["categories"]
    cases = json.loads((DIR / "cases.json").read_text())["cases"]

    print("## 1. 구조: 좋아함 1~3개의 모든 조합")
    sets, top1, top3, sizes = structure(grades, cats)
    print(f"조합 {len(sets)}개. 1위 그룹 크기 평균 {sum(sizes)/len(sizes):.2f}, 단독 1위 {sizes.count(1)}개, 3곳 이상 동점 {sum(s >= 3 for s in sizes)}개")
    print("도시 | 1위 그룹에 든 조합 수 | 상위 3곳에 든 조합 수")
    for c in sorted(grades, key=lambda c: -top3[c]):
        print(f"{c} | {top1[c]} | {top3[c]}")

    print("\n## 2. 민감도")
    print(f"칸의 15%를 ±1 바꾼 300회: 원래 1위가 새 상위 3곳에 남는 비율 {sensitivity(grades, cats, sets):.1%}")

    print("\n## 3. 독립 프로필 초안(profiles.json)과의 일치")
    prof = json.loads((ROOT / "data/exploration/profiles.json").read_text())
    both = only_grade = only_prof = 0
    for pid, p in prof.items():
        g = grades[pid.replace("th-phuket-island", "th-phuket")]
        listed = {e["category"] for e in p["experiences"]}
        for k in cats:
            hi = g[k] >= 2
            both += hi and k in listed
            only_grade += hi and k not in listed
            only_prof += (not hi) and k in listed
    print(f"2등급 이상이면서 프로필에도 있음 {both}, 2등급 이상인데 프로필에 없음 {only_grade}, 프로필에 있는데 1등급 이하 {only_prof}")

    print("\n## 4. 사례")
    for c in cases:
        r = rank(c["wants"], grades)
        t3 = top_n(r)
        line = f"{c['id']} ({c['note']})\n  상위: " + " > ".join(
            f"[{float(rate):.2f}{' 충돌' if clash else ''}] {', '.join(v)}" for rate, clash, v in r[:3])
        checks = []
        if "expect_top" in c:
            checks.append(f"1위 기대 {c['expect_top']}: {'통과' if r[0][2] == c['expect_top'] else '실패'}")
        if "expect_in_top3" in c:
            checks.append(f"상위 3 포함 기대 {c['expect_in_top3']}: {'통과' if set(c['expect_in_top3']) <= set(t3) else '실패'}")
        if "expect_not_in_top3" in c:
            checks.append(f"상위 3 제외 기대: {'통과' if not set(c['expect_not_in_top3']) & set(t3) else '실패'}")
        if "violators" in c:
            checks.append(f"상위 {len(t3)}곳 중 조건 위반 {sorted(set(t3) & set(c['violators']))}")
        if c.get("llm"):
            checks.append(f"LLM 추천과 겹침 {sorted(set(t3) & set(c['llm']))} / LLM {c['llm']}")
        print(line + "".join("\n  " + x for x in checks))


if __name__ == "__main__":
    main()
