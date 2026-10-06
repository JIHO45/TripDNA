"""D1 fixture checks only; not a catalog or LLM response validator.

Run: python3 scripts/check_city_example.py
"""

import json
from calendar import monthrange
from datetime import date
from pathlib import Path
from check_city_catalog import check_places


def add_months(day, months):
    year, month = divmod(day.year * 12 + day.month - 1 + months, 12)
    month += 1
    return date(year, month, min(day.day, monthrange(year, month)[1]))


def check():
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "data/cities/example.json").read_text())
    vocabulary = json.loads((root / "data/experience-categories.json").read_text())
    category_ids = {item["id"] for item in vocabulary["categories"]}
    assert len(category_ids) == len(vocabulary["categories"])
    assert data["schema_version"] == 3 and data["dataset_kind"] == "synthetic"
    assert data["category_version"] == vocabulary["version"]
    assert data["data_version"] > 0
    claims = {item["id"]: item for item in data["claims"]}
    assert len(claims) == len(data["claims"]) == 7
    check_places(data, claims)
    assert len({item["id"] for item in data["experiences"]}) == len(data["experiences"])
    refs = list(data["destination"]["coverage"]["evidence_ids"])
    for item in data["experiences"]:
        assert set(item["categories"]) <= category_ids
        refs += item["evidence_ids"] + item["constraint_evidence_ids"]
    for item in data["summary"]:
        assert item["evidence_ids"]
        refs += item["evidence_ids"]
    assert all(ref in claims for ref in refs)

    assert add_months(date(2026, 1, 31), 3) == date(2026, 4, 30)
    assert add_months(date(2024, 2, 29), 12) == date(2025, 2, 28)
    as_of = date(2026, 9, 30)  # Fixed KST date, independent of host timezone.
    periods = dict(price=3, operation=3, reservation=3, transport=6,
                   access=6, season=6, location=12, experience=12)
    current = set()
    for item in claims.values():
        assert item["kind"] in periods
        assert item["status"] in {"unknown", "unreviewed", "reviewed", "withheld"}
        months = item["applies"]["months"]
        assert months is None or all(type(m) is int and 1 <= m <= 12 for m in months)
        if item["status"] == "unknown":
            assert item["statement"] is None and item["question"]
        if item["status"] == "reviewed":
            source, review = item["source"], item["review"]
            assert item["statement"] and source["url"] and source["locator"]
            assert review["kind"] in {"self", "independent"} and review["reviewer_id"]
            assert review["claim_version"] == item["version"]
            checked = date.fromisoformat(source["checked_on"])
            assert checked <= date.fromisoformat(review["reviewed_on"]) <= as_of
            deadline = add_months(checked, periods[item["kind"]])
            if as_of < deadline and (source["valid_through"] is None
                                    or as_of <= date.fromisoformat(source["valid_through"])):
                current.add(item["id"])
        if item["cost"]:
            cost = item["cost"]
            assert item["kind"] == "price"
            assert 0 <= cost["amount_min"] <= cost["amount_max"]
            assert cost["party_size"] > 0 and cost["basis"] in {"per_person", "per_group"}
        if item.get("mobility"):
            mobility = item["mobility"]
            assert item["kind"] in {"transport", "access"}
            assert mobility["origin_destination_id"] == data["destination"]["id"]
            assert mobility["origin_place"]
            assert mobility["mode"] in {None, "walk", "bicycle", "public_transport",
                                         "car", "taxi", "boat", "flight", "mixed"}
            minutes = mobility["one_way_minutes"]
            if minutes is not None:
                assert all(type(minutes[key]) is int for key in ("min", "max"))
                assert 0 <= minutes["min"] <= minutes["max"]
            for key in ("car_required", "overnight_required"):
                assert mobility[key] is None or type(mobility[key]) is bool

    assert current == {"scope", "walk"}
    assert claims["access"]["mobility"]["overnight_required"] is None
    assert claims["evening_opening"]["status"] == "withheld"
    assert as_of < add_months(date(2026, 9, 20), 3)  # Withheld despite freshness.
    assert add_months(date(2026, 5, 31), 3) == date(2026, 8, 31)
    summaries = [item for item in data["summary"] if set(item["evidence_ids"]) <= current]
    assert len(summaries) == 1 and summaries[0]["evidence_ids"] == ["walk"]
    print(f"PASS: D1 synthetic example, {len(claims)} claims, {len(refs)} references; "
          "category IDs, mobility, reviews, cost scope, expiry and withheld summaries.")


if __name__ == "__main__":
    check()
