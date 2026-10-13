"""도시 자료 초안의 형식 검사와 요약. 입력: data/exploration/city-draft/draft.json. LLM·네트워크 없음.

검사: 세부 29개가 모두 levels의 이름으로 적혔는가(출력은 이전 표기 0~3으로 보여준다), 핵심 경험 문장이 2등급 이상 세부에만 빠짐없이 있는가,
season은 1등급 이상 세부의 달(1~12)인가, season_unverified가 season과 겹치지 않는가, nearby는 세부 ID만 가리키는가.
출력: 큰 컨셉 등급(세부 최댓값), grades-v2.json과 달라진 칸, 작업량.
"""
import json
from pathlib import Path

EXP = Path(__file__).resolve().parent.parent / "data/exploration"
DRAFT = json.loads((EXP / "city-draft/draft.json").read_text())
LEVELS = [lv["id"] for lv in DRAFT["levels"]]  # 낮은 것부터. 아래에서 0~3으로 바꿔 비교한다
V2 = json.loads((EXP / "coverage-check/grades-v2.json").read_text())
CONCEPTS = V2["concepts"]
SUBS = [s for c in CONCEPTS.values() for s in c["sub"]]
LABEL = {**{t: c["label"] for t, c in CONCEPTS.items()}, **{s: n for c in CONCEPTS.values() for s, n in c["sub"].items()}}


def tops(grades):
    return {t: max(grades[s] for s in c["sub"]) for t, c in CONCEPTS.items()}


def main():
    cells = sentences = 0
    for cid, city in DRAFT["cities"].items():
        assert list(city["grades"]) == SUBS and all(v in LEVELS for v in city["grades"].values()), cid
        g = {s: LEVELS.index(v) for s, v in city["grades"].items()}
        assert set(city["core"]) == {s for s, v in g.items() if v >= 2}, (cid, set(city["core"]) ^ {s for s, v in g.items() if v >= 2})
        assert all(isinstance(t, str) and t.strip() for t in city["core"].values()), cid
        assert all(g[s] >= 1 and m and all(type(x) is int and 1 <= x <= 12 for x in m) for s, m in city["season"].items()), cid
        assert all(g[s] >= 1 and s not in city["season"] for s in city["season_unverified"]), cid
        assert city["scope"] and all(set(v) <= set(SUBS) for v in city["nearby"].values()), cid
        assert city["name"]["ko"] and city["name"]["en"], cid
        cells, sentences = cells + len(g), sentences + len(city["core"])

        old = V2["grades"][cid.replace("th-phuket-island", "th-phuket")]
        top = tops(g)
        print(f"\n{city['name']['ko']}: " + ", ".join(f"{LABEL[t]} {v}" for t, v in top.items()))
        # v2는 2등급 이상 세부만 적었다. 적히지 않은 세부는 '1 이하'로 본다.
        diff = [f"{LABEL[k]} {old['top'][k]}→{v}" for k, v in top.items() if old["top"][k] != v]
        diff += [f"{LABEL[s]} {old['sub'].get(s, '1 이하')}→{v}" for s, v in g.items()
                 if (old["sub"][s] != v if s in old["sub"] else v >= 2)]
        print("  v2와 다른 칸:", ", ".join(diff) or "없음")
        print("  시즌:", ", ".join(f"{LABEL[s]} {m}" for s, m in city["season"].items()) or "없음",
              "| 근교:", ", ".join(city["nearby"]) or "없음")
    print(f"\n도시 {len(DRAFT['cities'])}곳, 등급 {cells}칸, 핵심 경험 문장 {sentences}개")


if __name__ == "__main__":
    main()
