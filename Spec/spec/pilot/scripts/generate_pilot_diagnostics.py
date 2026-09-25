#!/usr/bin/env python3
"""
30개국 국가 프로필 파일럿 - 축 진단 스크립트 (3.0 축 체계)

파이프라인: 편집 확정 프로필 -> (선택) 2인 검수 합치도 -> 조건부 3축
           (energy_level/planning_style/social_mode)의 국가분산/독립성 진단

3.0 개편 반영 사항:
- 축 이름을 3.0 스펙(Travel_Fingerprint_3.0_Spec.md 1.1절)으로 통일.
  (calm_stimulating -> energy_level, spontaneous_planned -> planning_style,
   together_solitude -> social_mode)
- food는 Interest Tag Profile, cost/climate는 Constraint Profile 소속으로
  코사인 매칭에서 제외 (기존과 동일하나 소속 계층이 명시됨).
- noveltyAppetite는 유저 성향 축이므로 국가분산 필터 대상이 아님. 국가측 값
  novelty_distance는 별도 산출물(공개데이터+편집)로, 이 스크립트 범위 밖.
- 필터2(유저분산)의 측정 대상 변경: (구) 회고 슬라이더 응답 -> (신) trip_evaluated
  기반 축 추정치(spec/02의 x_t/태그 서명 경유). 계산 로직은 실데이터 확보 후 추가.
- 태그 어휘(spec/06)의 축 서명도 이 파일럿의 2인 검수 게이트를 함께 통과해야 함
  (3.0 스펙 7절). 검수 템플릿은 국가 프로필과 동일 절차 사용.

프로필 출처 (EDITORIAL_FREEZE=True):
- Taste Core + food_tag: country_profiles_baseline_community.csv (커뮤 검수 초안)를
  여행 관행(사파리 패키지 예약, 성수기 인파 등)으로 소폭 보정.
- cost: Numbeo Cost of Living Index 2025를 0~1로 정규화한 뒤, 관광 비용 현실
  (사파리·리조트·두바이 등)로 보정.
- climate: World Bank 1991–2020 연평균기온을 0~1로 매핑하되, 관광 코리더
  (캐나다/미국/페루 안데스 등)는 여행 체감으로 조정.
  매핑 대략식: climate ≈ clamp((T°C + 5) / 35)

주의:
- EDITORIAL_FREEZE=True면 Reviewer B 노이즈를 넣지 않고 편집값을 그대로 출력.
- 진짜 2인 독립 검수 시 EDITORIAL_FREEZE=False로 바꾸고 reviewer_b를 실데이터로 교체.

실행: python3 generate_pilot_diagnostics.py
출력: ../data/country_profiles_draft.csv, ../01-country-profiles-and-axis-diagnostics.generated.md
"""

import csv
import math
import random
import statistics
from pathlib import Path

random.seed(42)

# True: 편집 확정값을 그대로 CSV에 기록 (노이즈 평균 없음)
EDITORIAL_FREEZE = True

# Taste Core 매칭 축 (0~1 스케일 초안, 서빙 시 -1~1로 변환)
AXES = [
    "nature_urban",    # 자연(0) <-> 도시(1), 확정, 매칭 가중치 1
    "energy_level",    # 고요/휴식(0) <-> 활동/자극(1), 조건부
    "planning_style",  # 즉흥(0) <-> 계획(1), 조건부
    "social_mode",     # 혼자/소수 몰입(0) <-> 사람 많은 경험(1), 조건부
    "food_tag",        # Interest Tag Profile 소속, 코사인 매칭 제외
    "cost",            # Constraint Profile 소속 (budgetFit), 공개데이터+관광보정
    "climate",         # Constraint Profile 소속 (seasonFit), 공개데이터+관광보정
]

MATCHING_AXES = ["nature_urban", "energy_level", "planning_style", "social_mode"]
CONDITIONAL_AXES = ["energy_level", "planning_style", "social_mode"]

COSINE_PASS_THRESHOLD = 0.7
VARIANCE_PASS_THRESHOLD = 0.030   # 0~1 스케일 기준 국가 간 분산 하한 (제안값, 확정 필요)
INDEPENDENCE_CORR_LIMIT = 0.60    # |r| 이 값 이상이면 타 축과 독립성 실패로 간주 (제안값, 확정 필요)

# country: (continent, nature_urban, energy_level, planning_style, social_mode, food_tag, cost, climate)
# 편집 확정 초안 (0~1). 대륙 균형: Asia 6 / Europe 6 / Africa 5 / NA 4 / SA 4 / Oceania 3 / ME 2
COUNTRIES = {
    # Asia — 커뮤 검수 축 유지. Japan planning↑(예약·교통패스), India energy↑(감각과부하)
    "Japan":        ("Asia", 0.75, 0.55, 0.80, 0.40, 0.90, 0.52, 0.42),
    "Thailand":     ("Asia", 0.45, 0.65, 0.35, 0.65, 0.90, 0.32, 0.88),
    "Vietnam":      ("Asia", 0.45, 0.60, 0.35, 0.55, 0.85, 0.26, 0.82),
    "India":        ("Asia", 0.45, 0.80, 0.55, 0.60, 0.80, 0.22, 0.82),
    "South Korea":  ("Asia", 0.80, 0.60, 0.65, 0.50, 0.80, 0.55, 0.43),
    "Indonesia":    ("Asia", 0.30, 0.50, 0.40, 0.55, 0.65, 0.28, 0.85),
    # Europe
    "France":       ("Europe", 0.70, 0.55, 0.60, 0.50, 0.90, 0.65, 0.42),
    "Italy":        ("Europe", 0.65, 0.60, 0.60, 0.60, 0.95, 0.58, 0.48),
    "Iceland":      ("Europe", 0.10, 0.30, 0.70, 0.25, 0.40, 0.85, 0.12),
    "Portugal":     ("Europe", 0.55, 0.50, 0.35, 0.55, 0.80, 0.42, 0.58),
    "Norway":       ("Europe", 0.15, 0.30, 0.65, 0.30, 0.45, 0.80, 0.15),
    "Greece":       ("Europe", 0.40, 0.55, 0.45, 0.60, 0.80, 0.48, 0.62),
    # Africa — Kenya/Tanzania/Egypt는 투어·가이드 구조라 planning↑
    "Morocco":      ("Africa", 0.55, 0.65, 0.50, 0.55, 0.75, 0.32, 0.62),
    "Kenya":        ("Africa", 0.15, 0.45, 0.75, 0.45, 0.45, 0.50, 0.72),
    "South Africa": ("Africa", 0.40, 0.55, 0.65, 0.45, 0.65, 0.42, 0.58),
    "Egypt":        ("Africa", 0.50, 0.65, 0.70, 0.55, 0.55, 0.30, 0.78),
    "Tanzania":     ("Africa", 0.10, 0.40, 0.80, 0.50, 0.40, 0.52, 0.72),
    # North America
    "USA":          ("North America", 0.55, 0.60, 0.55, 0.45, 0.70, 0.72, 0.50),
    "Mexico":       ("North America", 0.50, 0.65, 0.40, 0.60, 0.90, 0.35, 0.78),
    "Canada":       ("North America", 0.25, 0.35, 0.60, 0.35, 0.55, 0.65, 0.28),
    "Costa Rica":   ("North America", 0.10, 0.55, 0.50, 0.45, 0.55, 0.55, 0.80),
    # South America — Peru food↑(리마 미식), Brazil social↑(카니발·사교)
    "Peru":         ("South America", 0.30, 0.50, 0.70, 0.55, 0.90, 0.30, 0.52),
    "Brazil":       ("South America", 0.55, 0.80, 0.40, 0.75, 0.70, 0.38, 0.85),
    "Argentina":    ("South America", 0.50, 0.55, 0.55, 0.55, 0.80, 0.40, 0.55),
    "Colombia":     ("South America", 0.50, 0.65, 0.45, 0.65, 0.60, 0.32, 0.78),
    # Oceania — Fiji는 리조트 관광비↑, NZ/호주 COL 반영
    "New Zealand":  ("Oceania", 0.10, 0.45, 0.60, 0.35, 0.55, 0.68, 0.35),
    "Australia":    ("Oceania", 0.45, 0.55, 0.50, 0.55, 0.65, 0.68, 0.65),
    "Fiji":         ("Oceania", 0.10, 0.25, 0.50, 0.55, 0.45, 0.50, 0.88),
    # Middle East — UAE COL은 중간이나 관광단가↑, 기후 최상위권
    "UAE":          ("Middle East", 0.90, 0.65, 0.70, 0.50, 0.75, 0.78, 0.92),
    "Jordan":       ("Middle East", 0.30, 0.40, 0.60, 0.45, 0.65, 0.35, 0.72),
}

assert len(COUNTRIES) == 30, f"국가 수가 30개가 아님: {len(COUNTRIES)}"


def cosine_similarity(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def pearson(xs, ys):
    mx, my = statistics.mean(xs), statistics.mean(ys)
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    sy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if sx == 0 or sy == 0:
        return 0.0
    return cov / (sx * sy)


def main():
    reviewer_a = {c: dict(zip(AXES, v[1:])) for c, v in COUNTRIES.items()}
    continent = {c: v[0] for c, v in COUNTRIES.items()}

    if EDITORIAL_FREEZE:
        # 편집 동결: 확정값을 그대로 사용. 합치도는 1.0(자체 합의)으로 기록.
        final_scores = {c: dict(scores) for c, scores in reviewer_a.items()}
        agreement = {c: 1.0 for c in COUNTRIES}
    else:
        # Reviewer B 시뮬레이션: 실제 2인 검수 데이터 부재 -> 소폭 노이즈로 대체 (임시)
        reviewer_b = {}
        for c, scores in reviewer_a.items():
            reviewer_b[c] = {ax: clamp(v + random.gauss(0, 0.20)) for ax, v in scores.items()}

        final_scores = {}
        agreement = {}
        for c in COUNTRIES:
            va = [reviewer_a[c][ax] for ax in MATCHING_AXES]
            vb = [reviewer_b[c][ax] for ax in MATCHING_AXES]
            agreement[c] = cosine_similarity(va, vb)
            final_scores[c] = {ax: (reviewer_a[c][ax] + reviewer_b[c][ax]) / 2 for ax in AXES}

    passed = {c: sim >= COSINE_PASS_THRESHOLD for c, sim in agreement.items()}

    # 축 진단: 국가분산(필터1) + 독립성 (통과한 국가만 대상 -> 실사용 매칭 풀 기준)
    passed_countries = [c for c, ok in passed.items() if ok]
    axis_diag = {}
    for axis in CONDITIONAL_AXES:
        values = [final_scores[c][axis] for c in passed_countries]
        var = statistics.pvariance(values)
        corrs = {}
        for other in MATCHING_AXES:
            if other == axis:
                continue
            other_values = [final_scores[c][other] for c in passed_countries]
            corrs[other] = pearson(values, other_values)
        max_abs_corr = max(abs(v) for v in corrs.values())
        axis_diag[axis] = {
            "variance": var,
            "variance_pass": var >= VARIANCE_PASS_THRESHOLD,
            "correlations": corrs,
            "independence_pass": max_abs_corr < INDEPENDENCE_CORR_LIMIT,
        }

    write_csv(final_scores, continent, agreement, passed)
    write_report(agreement, passed, axis_diag, passed_countries, continent)


def write_csv(final_scores, continent, agreement, passed):
    out_path = Path(__file__).resolve().parent.parent / "data" / "country_profiles_draft.csv"
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["country", "continent", *AXES, "review_cosine_agreement", "pilot_pass"])
        for c in COUNTRIES:
            row = [c, continent[c]] + [round(final_scores[c][ax], 3) for ax in AXES]
            row += [round(agreement[c], 3), "PASS" if passed[c] else "FAIL"]
            w.writerow(row)
    print(f"wrote {out_path}")


def write_report(agreement, passed, axis_diag, passed_countries, continent):
    out_path = Path(__file__).resolve().parent.parent / "01-country-profiles-and-axis-diagnostics.generated.md"
    lines = []
    lines.append("<!-- 이 파일은 generate_pilot_diagnostics.py 로 생성됨. EDITORIAL_FREEZE 시 편집 확정값 기준 -->")
    lines.append("<!-- 축 체계: Travel_Fingerprint_3.0_Spec.md 1.1절 (energy_level/planning_style/social_mode) -->")
    lines.append("")
    if EDITORIAL_FREEZE:
        lines.append("## 국가별 프로필 상태 (편집 동결)")
        lines.append("")
        lines.append("| 국가 | 대륙 | 합치도 | 파일럿 통과(>=0.7) |")
        lines.append("|---|---|---|---|")
        for c in COUNTRIES:
            lines.append(f"| {c} | {continent[c]} | {agreement[c]:.3f} | {'PASS' if passed[c] else 'FAIL'} |")
        lines.append("")
        lines.append("- 모드: `EDITORIAL_FREEZE=True` — 커뮤 검수 축 + Numbeo/기후 공개데이터로 확정값을 그대로 기록.")
        lines.append("- 진짜 2인 독립 검수 전에는 합치도 1.0이 시뮬레이션이 아니라 **자체 동결** 표시임.")
    else:
        lines.append("## 국가별 검수 합치도 (LLM 초안 vs 검수자, 코사인 유사도)")
        lines.append("")
        lines.append("| 국가 | 대륙 | 코사인 합치도 | 파일럿 통과(>=0.7) |")
        lines.append("|---|---|---|---|")
        for c in COUNTRIES:
            lines.append(f"| {c} | {continent[c]} | {agreement[c]:.3f} | {'PASS' if passed[c] else 'FAIL'} |")

    fail_list = [c for c, ok in passed.items() if not ok]
    lines.append("")
    lines.append(f"- 통과 {len(passed) - len(fail_list)}개국 / 탈락 {len(fail_list)}개국")
    lines.append(f"- 탈락국(플랜B 회색 처리 대상): {', '.join(fail_list) if fail_list else '없음'}")

    lines.append("")
    lines.append("## 조건부 축 진단 (통과국 기준)")
    lines.append("")
    lines.append("| 축 | 국가분산 | 필터1 통과(>=%.3f) | 최대 상관계수(타 매칭축) | 독립성(|r|<%.2f) |" % (VARIANCE_PASS_THRESHOLD, INDEPENDENCE_CORR_LIMIT))
    lines.append("|---|---|---|---|---|")
    for axis in CONDITIONAL_AXES:
        d = axis_diag[axis]
        max_corr = max(d["correlations"].values(), key=abs)
        lines.append(
            f"| {axis} | {d['variance']:.4f} | {'PASS' if d['variance_pass'] else 'FAIL'} | "
            f"{max_corr:+.3f} | {'PASS' if d['independence_pass'] else 'FAIL'} |"
        )

    lines.append("")
    lines.append("### 종합 판정 (국가분산 필터1 + 독립성)")
    lines.append("")
    for axis in CONDITIONAL_AXES:
        d = axis_diag[axis]
        overall = d["variance_pass"] and d["independence_pass"]
        lines.append(f"- **{axis}**: 필터1(국가분산) {'PASS' if d['variance_pass'] else 'FAIL'}, "
                      f"독립성 {'PASS' if d['independence_pass'] else 'FAIL'} "
                      f"-> 국가측 진단 {'PASS' if overall else 'FAIL'} "
                      f"(필터2 유저분산은 trip_evaluated 실데이터 필요, 별도 판정)")

    out_path.write_text("\n".join(lines) + "\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
