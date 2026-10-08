"""두 단계 컨셉 매칭의 PC 계산. 입력: data/exploration/coverage-check/grades-v2.json. LLM·네트워크 없음.

순서: 주 컨셉 2등급 미만 제외 -> (주 컨셉 등급, 부 컨셉 등급 합) -> 티어 가중 합(3/2/1) -> 남으면 동점.
주 컨셉의 세부를 골랐으면 그 세부 등급으로 판정한다. 세부 기록이 없는 도시는 빼지 않고 기록 있는 도시 뒤에 둔다.
피하고 싶은 컨셉이 3등급인 도시는 같은 순위 안에서 뒤로 보낸다.
"""
import itertools
import json
import random
from collections import Counter
from pathlib import Path

DATA = json.loads((Path(__file__).resolve().parent.parent / "data/exploration/coverage-check/grades-v2.json").read_text())
G, CONCEPTS = DATA["grades"], DATA["concepts"]
TOPS = list(CONCEPTS)
PARENT = {s: t for t, c in CONCEPTS.items() for s in c["sub"]}
LABEL = {**{t: c["label"] for t, c in CONCEPTS.items()}, **{s: n for c in CONCEPTS.values() for s, n in c["sub"].items()}}


def rank(main, subs=(), tiers=None, avoid=(), detail=None):
    """[(정렬 키, [도시...])]를 좋은 순으로. tiers는 {큰 컨셉: 3|2|1}, detail은 주 컨셉의 세부."""
    groups = {}
    for city, g in G.items():
        top = g["top"]
        if top[main] < 2:
            continue
        first = (1, g["sub"][detail]) if detail in g["sub"] else (0, top[main]) if detail else (1, top[main])
        key = (first, sum(top[s] for s in subs), -any(top[a] == 3 for a in avoid),
               sum(w * top[t] for t, w in (tiers or {}).items()))
        groups.setdefault(key, []).append(city)
    return [(k, sorted(v)) for k, v in sorted(groups.items(), reverse=True)]


def top3(ranked):
    out = []
    for _, cities in ranked:
        out += cities
        if len(out) >= 3:
            break
    return out


def self_check():
    assert all(c in rank("nature")[0][1] for c in ("ca-vancouver", "au-cairns"))
    assert "fr-paris" not in [c for _, v in rank("nature") for c in v]  # 주 컨셉 2등급 미만 제외
    r = rank("food", detail="street")
    assert r[0][0][0] == (1, 3) and "fr-paris" in [c for k, v in r if k[0][0] == 0 for c in v]  # 기록 없는 도시는 뒤
    assert rank("nature", avoid=["activities"])[0][1] == ["ca-vancouver"]


def summarize(name, inputs):
    sizes, first, shown, n = [], Counter(), Counter(), 0
    for kw in inputs:
        r = rank(**kw)
        sizes.append(len(r[0][1]))
        first.update(r[0][1])
        shown.update(top3(r))
        n += 1
    never = sorted(set(G) - set(first))
    print(f"{name}: 입력 {n}개, 단독 1위 {sizes.count(1) / n:.0%}, 1위 그룹 평균 {sum(sizes) / n:.2f}, "
          f"1위 없음 {len(never)}곳, 상위 3곳에도 없음 {len(set(G) - set(shown))}곳")
    print("   1위 비율:", ", ".join(f"{c} {v / n:.0%}" for c, v in first.most_common(5)), "| 1위 없음:", never)


def main():
    self_check()
    rnd = random.Random(20261008)
    pairs = lambda m: itertools.combinations([t for t in TOPS if t != m], 2)
    tier = lambda: {t: w for t in TOPS if (w := rnd.choice((3, 2, 1, 0, 0)))}  # 0은 '잘 모르겠음'
    base = [dict(main=m, subs=s) for m in TOPS for s in pairs(m)]
    summarize("주 1 + 부 2", base)
    summarize("주 1 + 부 2 + 티어", [dict(kw, tiers=tier()) for kw in base for _ in range(5)])
    det = [dict(main=PARENT[d], detail=d, subs=s) for d in PARENT for s in pairs(PARENT[d])]
    summarize("세부 선택 + 부 2", det)
    summarize("세부 선택 + 부 2 + 티어", [dict(kw, tiers=tier()) for kw in det for _ in range(3)])

    print("\n## 검수용 예시 (상위 그룹 순, 괄호는 근거 등급)")
    examples = [
        ("미식 여행, 길거리 음식·시장 / 부: 쇼핑", dict(main="food", detail="street", subs=["shopping"])),
        ("미식 여행, 맛집·파인다이닝 / 부: 도시", dict(main="food", detail="dining", subs=["city"])),
        ("자연 여행, 하이킹 / 피함: 액티비티", dict(main="nature", detail="hiking", avoid=["activities"])),
        ("휴양 여행, 해변·바다 / 부: 미식", dict(main="relaxation", detail="beach", subs=["food"])),
        ("휴양 여행, 온천·스파 / 부: 문화·역사", dict(main="relaxation", detail="spa", subs=["culture"])),
        ("문화·역사 여행, 유적·사원 / 부: 휴양 / 피함: 나이트라이프", dict(main="culture", detail="heritage", subs=["relaxation"], avoid=["nightlife"])),
        ("교류 여행 / 부: 액티비티 / 피함: 나이트라이프", dict(main="social", subs=["activities"], avoid=["nightlife"])),
        ("이벤트 여행, 스포츠 직관 / 부: 미식", dict(main="event", detail="sports", subs=["food"])),
        ("도시 여행 / 부: 자연 / 티어1 미식, 티어2 문화·역사", dict(main="city", subs=["nature"], tiers={"food": 3, "culture": 2})),
        ("액티비티 여행, 겨울 스포츠", dict(main="activities", detail="winter")),
    ]
    for title, kw in examples:
        print(f"\n{title}")
        used = [kw.get("detail") or kw["main"], *kw.get("subs", []), *kw.get("avoid", []), *(kw.get("tiers") or {})]
        for i, (key, cities) in enumerate(rank(**kw)[:3], 1):
            for c in cities:
                g = G[c]
                why = ", ".join(f"{LABEL[u]} {g['sub'].get(u, '기록 없음') if u in PARENT else g['top'][u]}" for u in used)
                print(f"  {i}위 {c} ({why})")


if __name__ == "__main__":
    main()
