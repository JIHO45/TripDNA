#!/usr/bin/env python3
"""
시드 데이터 생성 스크립트.

- countries.json: country_profiles_draft.csv(0~1 스케일)를 국가 프로필
  문서 형태(tasteCore -1.0~1.0)로 변환.
- tagVocabulary.json: recommendation/06-tag-vocabulary.md 초안을
  `tagVocabulary/{tagId}` 문서 형태로 정리 (검수 전 초안, 2인 검수 통과 전까지 값 변경 가능).

편집은 CSV에서만 한다. JSON을 직접 고치면 다음 실행에서 덮어써진다.
countries.json은 앱 번들 리소스(TripDNA/Resources)에도 같이 써서 두 사본이
어긋나지 않게 한다.

실행: python3 generate_seed_data.py
출력: ../data/seed/{countries,tagVocabulary}.json, TripDNA/Resources/countries.json
"""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = ROOT.parents[2]
DRAFT_CSV = ROOT / "data" / "country_profiles_draft.csv"
SEED_DIR = ROOT / "data" / "seed"
APP_COUNTRIES_JSON = REPO_ROOT / "TripDNA" / "Resources" / "countries.json"

# country name -> (ISO 3166-1 alpha-2, 한국어 표기)
COUNTRY_CODES = {
    "Japan": ("JP", "일본"),
    "Thailand": ("TH", "태국"),
    "Vietnam": ("VN", "베트남"),
    "India": ("IN", "인도"),
    "South Korea": ("KR", "대한민국"),
    "Indonesia": ("ID", "인도네시아"),
    "France": ("FR", "프랑스"),
    "Italy": ("IT", "이탈리아"),
    "Iceland": ("IS", "아이슬란드"),
    "Portugal": ("PT", "포르투갈"),
    "Norway": ("NO", "노르웨이"),
    "Greece": ("GR", "그리스"),
    "Morocco": ("MA", "모로코"),
    "Kenya": ("KE", "케냐"),
    "South Africa": ("ZA", "남아프리카공화국"),
    "Egypt": ("EG", "이집트"),
    "Tanzania": ("TZ", "탄자니아"),
    "USA": ("US", "미국"),
    "Mexico": ("MX", "멕시코"),
    "Canada": ("CA", "캐나다"),
    "Costa Rica": ("CR", "코스타리카"),
    "Peru": ("PE", "페루"),
    "Brazil": ("BR", "브라질"),
    "Argentina": ("AR", "아르헨티나"),
    "Colombia": ("CO", "콜롬비아"),
    "New Zealand": ("NZ", "뉴질랜드"),
    "Australia": ("AU", "오스트레일리아"),
    "Fiji": ("FJ", "피지"),
    "UAE": ("AE", "아랍에미리트"),
    "Jordan": ("JO", "요르단"),
}

# 매칭에 쓰는 축. noveltyAppetite는 국가별 값(noveltyDistance)이 아직 없으므로 제외한다.
# 1축(natureUrban)만 쓰면 코사인 유사도가 부호 일치 여부로 붕괴해 매치 점수가
# 1.0/0.0 두 값만 나오므로, 값이 채워진 4축 전부를 매칭에 쓴다.
MATCHING_AXES = ["natureUrban", "energyLevel", "planningStyle", "socialMode"]

# 관심 태그 id -> CSV 컬럼명. tagVocabulary의 interest 그룹 9개와 1:1로 맞춘다.
INTEREST_TAG_COLUMNS = {
    "food": "food_tag",
    "culture": "culture_tag",
    "history": "history_tag",
    "outdoor": "outdoor_tag",
    "beach": "beach_tag",
    "nightlife": "nightlife_tag",
    "shopping": "shopping_tag",
    "wellness": "wellness_tag",
    "sportsAndEvents": "sports_events_tag",
}


def to_signed(v01: float) -> float:
    """0.0~1.0 편집값 -> Taste Core 저장 스케일 -1.0~1.0."""
    return round(v01 * 2 - 1, 3)


def unit(row: dict, column: str) -> float:
    """0.0~1.0 편집값을 그대로 읽는다. 범위를 벗어나면 데이터 오류로 끊는다."""
    value = float(row[column])
    assert 0.0 <= value <= 1.0, f"{row['country']} {column} 범위 초과: {value}"
    return round(value, 3)


def build_countries():
    countries = {}
    with DRAFT_CSV.open(newline="") as f:
        for row in csv.DictReader(f):
            name = row["country"]
            code, name_ko = COUNTRY_CODES[name]
            countries[code] = {
                "name": name,
                "nameKo": name_ko,
                "continent": row["continent"],
                "status": "confirmed" if row["pilot_pass"] == "PASS" else "grey",
                "tasteCore": {
                    "natureUrban": to_signed(float(row["nature_urban"])),
                    "energyLevel": to_signed(float(row["energy_level"])),
                    "planningStyle": to_signed(float(row["planning_style"])),
                    "socialMode": to_signed(float(row["social_mode"])),
                    "noveltyDistance": None,  # 별도 산출 전 (spec/pilot/01 참고)
                },
                "matchingAxes": MATCHING_AXES,
                "interestTags": {
                    tag_id: unit(row, column)
                    for tag_id, column in INTEREST_TAG_COLUMNS.items()
                },
                "constraints": {
                    "cost": round(float(row["cost"]), 3),
                    "climate": round(float(row["climate"]), 3),
                },
                # underrated_fit 슬롯의 "저인기" 항이 쓰는 값. 국제 관광객 수 규모를
                # 0~1로 눌러 담은 편집값이며, 추천 품질 지표가 아니라 인지도 지표다.
                "popularity": unit(row, "popularity"),
                "pilotReviewCosine": round(float(row["review_cosine_agreement"]), 3),
                "source": "editorial_freeze",
            }
    assert len(countries) == 30, f"국가 수가 30개가 아님: {len(countries)}"
    return countries


# tagId -> (labelKo, group, routing[], axisSignature|None, polarityPairId|None,
#           isNegative, constraintTarget|None, qualityTarget)
TAGS = [
    ("food", "미식", "interest", ["taste", "interest"], None, None, False, None, False),
    ("culture", "문화/예술", "interest", ["interest"], None, None, False, None, False),
    ("history", "역사/유적", "interest", ["interest"], None, None, False, None, False),
    ("outdoor", "자연/트레킹", "interest", ["taste", "interest"],
     {"natureUrban": -0.6}, None, False, None, False),
    ("beach", "해변/휴양", "interest", ["taste", "interest"],
     {"natureUrban": -0.4, "energyLevel": -0.4}, None, False, None, False),
    ("nightlife", "밤문화", "interest", ["taste", "interest"],
     {"energyLevel": 0.6}, None, False, None, False),
    ("shopping", "쇼핑", "interest", ["taste", "interest"],
     {"natureUrban": 0.4}, None, False, None, False),
    ("wellness", "휴식/웰니스", "interest", ["taste", "interest"],
     {"energyLevel": -0.6}, None, False, None, False),
    ("sportsAndEvents", "스포츠/페스티벌 직관", "interest", ["taste", "interest"],
     {"energyLevel": 0.4}, None, False, None, False),

    ("energyLow", "고요한 평화", "polarity", ["taste"],
     {"energyLevel": -0.8}, "energyLevel", False, None, False),
    ("energyHigh", "에너지 넘치는 자극", "polarity", ["taste"],
     {"energyLevel": 0.8}, "energyLevel", False, None, False),
    ("planningLow", "무계획의 묘미", "polarity", ["taste"],
     {"planningStyle": -0.8}, "planningStyle", False, None, False),
    ("planningHigh", "알찬 계획과 실행", "polarity", ["taste"],
     {"planningStyle": 0.8}, "planningStyle", False, None, False),
    ("socialLow", "혼자만의 여유", "polarity", ["taste"],
     {"socialMode": -0.8}, "socialMode", False, None, False),
    ("socialHigh", "함께하는 즐거움", "polarity", ["taste"],
     {"socialMode": 0.8}, "socialMode", False, None, False),
    ("noveltyLow", "편안한 익숙함", "polarity", ["taste"],
     {"noveltyAppetite": -0.7}, "noveltyAppetite", False, None, False),
    ("noveltyHigh", "낯선 새로움 · 숨은 명소 탐험", "polarity", ["taste"],
     {"noveltyAppetite": 0.7}, "noveltyAppetite", False, None, False),
    ("natureUrbanNature", "대자연의 감동", "polarity", ["taste"],
     {"natureUrban": -0.8}, "natureUrban", False, None, False),
    ("natureUrbanCity", "도시의 매력", "polarity", ["taste"],
     {"natureUrban": 0.8}, "natureUrban", False, None, False),

    ("negCrowded", "너무 북적였어요", "negative", ["taste"],
     {"socialMode": -0.5, "energyLevel": -0.3}, None, True, None, False),
    ("negBoring", "너무 심심했어요", "negative", ["taste"],
     {"energyLevel": -0.5}, None, True, None, False),
    ("negPacked", "일정이 너무 빡셌어요", "negative", ["taste"],
     {"energyLevel": 0.5}, None, True, None, False),
    ("negPlanDisrupted", "계획대로 안 돼서 힘들었어요", "negative", ["taste"],
     {"planningStyle": 0.5}, None, True, None, False),
    ("negWeather", "날씨가 아쉬웠어요", "negative", ["constraint"],
     None, None, True, "seasonFit", False),
    ("negExpensive", "예상보다 비쌌어요", "negative", ["constraint"],
     None, None, True, "budgetFit", False),
    ("negTransit", "이동이 힘들었어요", "negative", ["constraint"],
     None, None, True, "flightFriction", False),
    ("negRipoffUnfriendly", "바가지/불친절", "negative", ["quality"],
     None, None, True, None, True),
    ("negHygiene", "위생이 아쉬웠어요", "negative", ["quality"],
     None, None, True, None, True),
    ("negInfra", "인프라가 부족해 불편했어요", "negative", ["quality"],
     None, None, True, None, True),
]


def build_tag_vocabulary():
    tags = {}
    for (tag_id, label_ko, group, routing, axis_sig, polarity_pair_id,
         is_negative, constraint_target, quality_target) in TAGS:
        tags[tag_id] = {
            "labelKo": label_ko,
            "group": group,
            "routing": routing,
            "axisSignature": axis_sig,
            "polarityPairId": polarity_pair_id,
            "isNegative": is_negative,
            "constraintTarget": constraint_target,
            "qualityTarget": quality_target,
        }
    return tags


def main():
    SEED_DIR.mkdir(parents=True, exist_ok=True)

    countries_json = json.dumps(build_countries(), ensure_ascii=False, indent=2) + "\n"
    for countries_path in (SEED_DIR / "countries.json", APP_COUNTRIES_JSON):
        countries_path.write_text(countries_json)
        print(f"wrote {countries_path}")

    tags_path = SEED_DIR / "tagVocabulary.json"
    tags_path.write_text(
        json.dumps(build_tag_vocabulary(), ensure_ascii=False, indent=2) + "\n"
    )
    print(f"wrote {tags_path}")


if __name__ == "__main__":
    main()
