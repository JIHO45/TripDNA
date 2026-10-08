#!/usr/bin/env python3
"""Render sample recommendation-card text from pre-written sentences, with no model call.

  python3 scripts/render_card_sentences.py     # writes data/exploration/card-sentences/sample-cards.md

For each sample user and city it picks, among the city's matching axes, the axis where user and city
agree most (the reason it fits) and the one where they differ most (what may not fit), the same
per-axis product the app's cosine match is built from. It prints the pre-written, city-specific
sentence next to a generic template sentence so the two can be compared by reading.
"""
import json
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "data" / "exploration" / "card-sentences"
MIN_LEAN = 0.15  # same threshold AxisNarrative uses to call an axis a leaning
# Wording from TripDNA/Fingerprint/AxisNarrative.swift (leaningPhraseKo), plus English for the same poles.
PHRASE = {
    "natureUrban": {"ko": ("고요한 자연", "생동감 있는 도시"), "en": ("quiet nature", "a lively city")},
    "energyLevel": {"ko": ("느긋한 휴식", "활기찬 활동"), "en": ("an easy pace", "an active trip")},
    "planningStyle": {"ko": ("즉흥적인 여정", "촘촘한 계획"), "en": ("a spontaneous trip", "a planned trip")},
    "socialMode": {"ko": ("혼자만의 시간", "함께하는 여행"), "en": ("time to yourself", "being among people")},
}
TEMPLATE = {
    "fit": {"ko": "{u} 쪽을 좋아하는데, 이곳도 그런 편이에요.", "en": "You lean towards {u}, and this place leans the same way."},
    "caution": {"ko": "{u} 쪽을 좋아하는데, 이곳은 {c} 쪽에 가까워요.", "en": "You lean towards {u}, while this place is closer to {c}."},
    "none_fit": {"ko": "지금 취향과 뚜렷이 맞는 점은 찾지 못했어요.", "en": "Nothing here stands out as a match for your tastes."},
    "unclear_fit": {"ko": "아직 취향이 뚜렷하지 않아 맞는 이유를 단정하지 않아요.", "en": "Your tastes are not clear yet, so no reason is claimed."},
    "none_caution": {"ko": "지금 취향으로는 크게 어긋나는 점이 보이지 않아요.", "en": "Nothing stands out as a mismatch for your tastes so far."},
}


def pick(user, city):
    """(best matching axis or None, most conflicting axis or None) over the city's matching axes."""
    axes = [a for a in city["matchingAxes"] if a not in user["acceptedAxes"] and abs(user["axes"][a]) >= MIN_LEAN]
    score = lambda a: user["axes"][a] * city["tasteCore"][a]
    fits = sorted((a for a in axes if score(a) > 0), key=score, reverse=True)
    clashes = sorted((a for a in axes if score(a) < 0), key=score)
    return (fits[0] if fits else None), (clashes[0] if clashes else None)


def phrase(axis, value, lang):
    return PHRASE[axis][lang][0 if value < 0 else 1]


def card(user, city, lang):
    fit, clash = pick(user, city)
    lines = [f"- {'대표 장소' if lang == 'ko' else 'Places'}: " + ", ".join(city["places"][lang])]
    for kind, axis, label in (("fit", fit, {"ko": "맞는 이유", "en": "Why it fits"}),
                              ("caution", clash, {"ko": "안 맞을 수 있는 점", "en": "What may not fit"})):
        if axis is None:
            # "No match found" and "we do not know your tastes yet" are different things to tell the user.
            unclear = kind == "fit" and all(abs(v) < MIN_LEAN for v in user["axes"].values())
            lines.append(f"- {label[lang]}: {TEMPLATE['unclear_fit' if unclear else 'none_' + kind][lang]}")
            continue
        generic = TEMPLATE[kind][lang].format(u=phrase(axis, user["axes"][axis], lang),
                                              c=phrase(axis, city["tasteCore"][axis], lang))
        lines.append(f"- {label[lang]} ({axis})")
        lines.append(f"  - {'미리 쓴 문장' if lang == 'ko' else 'Pre-written'}: {city['sentences'][axis][kind][lang]}")
        lines.append(f"  - {'틀 문장' if lang == 'ko' else 'Template'}: {generic}")
    return lines


def demo():
    """The smallest check that the picker follows the axis signs."""
    city = {"matchingAxes": ["natureUrban", "energyLevel"], "tasteCore": {"natureUrban": 0.8, "energyLevel": -0.5}}
    assert pick({"axes": {"natureUrban": 0.6, "energyLevel": 0.7}, "acceptedAxes": []}, city) == ("natureUrban", "energyLevel")
    assert pick({"axes": {"natureUrban": 0.6, "energyLevel": 0.7}, "acceptedAxes": ["energyLevel"]}, city) == ("natureUrban", None)
    assert pick({"axes": {"natureUrban": 0.1, "energyLevel": 0.05}, "acceptedAxes": []}, city) == (None, None)


def main():
    demo()
    data = json.loads((DIR / "cities-draft.json").read_text())
    out = ["# 추천 카드 문장 견본 (모델 호출 없음)", "",
           "`cities-draft.json`의 초안으로 만든 견본이다. 장소·축 값·문장은 출처로 확인하지 않은 초안이며 앱 자료가 아니다.",
           "각 항목에서 **미리 쓴 문장**(도시별로 써 둔 것)과 **틀 문장**(축 이름만 채운 것)을 나란히 보여 준다.", ""]
    for uid, user in data["users"].items():
        for lang in ("ko", "en") if uid in ("U1", "U2") else ("ko",):
            axes = ", ".join(f"{a} {v:+.1f}" for a, v in user["axes"].items())
            out += [f"## {uid} — {user['label'][lang]}" + (" (English)" if lang == "en" else ""), "", f"축: {axes}"
                    + (f" / 양쪽 다 좋음: {', '.join(user['acceptedAxes'])}" if user["acceptedAxes"] else ""), ""]
            for city in data["cities"].values():
                out += [f"### {city['nameKo'] if lang == 'ko' else city['name']}", ""] + card(user, city, lang) + [""]
    (DIR / "sample-cards.md").write_text("\n".join(out))
    print(f"wrote {DIR / 'sample-cards.md'} ({len(data['users'])} users x {len(data['cities'])} cities)")


if __name__ == "__main__":
    main()
