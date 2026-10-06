"""D3 catalog integrity check for data/cities/*.json (except the synthetic example).

Checks structure, references, status rules and the D2 planning link. It does not prove
that a claim matches its source or that a recorded reviewer actually reviewed it, and it
is not the E2 validator for LLM responses, exclusions or trip conditions.

Run: python3 scripts/check_city_catalog.py
"""

import json
import math
import re
import sys
from collections import Counter
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

CLAIM_KINDS = {"price", "operation", "reservation", "transport", "access", "season", "location", "experience"}
STATUSES = {"unknown", "unreviewed", "reviewed", "withheld"}
REVIEW_KINDS = {"self", "independent"}
MODES = {None, "walk", "bicycle", "public_transport", "car", "taxi", "boat", "flight", "mixed"}
DESTINATION_KINDS = {"city", "region"}
DESTINATION_STATUSES = {"draft", "partial", "reviewed"}
MOBILITY_FIELDS = {"origin_destination_id", "origin_place", "mode", "one_way_minutes",
                   "car_required", "overnight_required"}
MOBILITY_FACTS = ("mode", "one_way_minutes", "car_required", "overnight_required")
APPLIES_FIELDS = {"date_from", "date_through", "months", "conditions"}
COST_FIELDS = {"currency", "amount_min", "amount_max", "as_of", "party_size", "basis",
               "period", "includes", "excludes"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def is_positive_int(value):
    return type(value) is int and value > 0


def is_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def is_text(value):
    return isinstance(value, str) and bool(value.strip())


def is_text_list(value):
    return isinstance(value, list) and all(is_text(item) for item in value)


def parse_date(value, label):
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError):
        raise ValueError(f"{label}: invalid date {value!r}")


def check_source(source, label, today):
    require(isinstance(source, dict), f"{label}: source required")
    require(str(source.get("url", "")).startswith("https://"), f"{label}: source url must be https")
    require(bool(source.get("locator")), f"{label}: source locator required")
    checked = None
    if source.get("checked_on") is not None:
        checked = parse_date(source["checked_on"], f"{label}.checked_on")
        require(checked <= today, f"{label}: checked_on is in the future")
    if source.get("valid_through") is not None:
        parse_date(source["valid_through"], f"{label}.valid_through")
    return checked


def check_review(claim, label, checked, today):
    review = claim["review"]
    require(isinstance(review, dict), f"{label}: reviewed claim needs a review record")
    require(review.get("kind") in REVIEW_KINDS, f"{label}: review kind must be self/independent")
    require(bool(review.get("reviewer_id")), f"{label}: reviewer_id required")
    require(review.get("claim_version") == claim["version"], f"{label}: review is for another claim version")
    reviewed_on = parse_date(review.get("reviewed_on"), f"{label}.reviewed_on")
    require(checked is not None, f"{label}: reviewed claim needs source.checked_on")
    require(checked <= reviewed_on <= today, f"{label}: reviewed_on must be between checked_on and today")


def check_mobility(claim, label, destination_ids):
    mobility = claim.get("mobility")
    if mobility is None:
        return
    require(claim["kind"] in {"transport", "access"}, f"{label}: mobility only on transport/access")
    require(set(mobility) == MOBILITY_FIELDS, f"{label}: mobility must have exactly the format fields")
    origin = mobility["origin_destination_id"]
    require(origin is None or origin in destination_ids, f"{label}: unknown origin_destination_id")
    require(mobility["mode"] in MODES, f"{label}: unknown mobility mode")
    minutes = mobility["one_way_minutes"]
    if minutes is not None:
        require(isinstance(minutes, dict) and set(minutes) == {"min", "max"}, f"{label}: one_way_minutes needs min/max")
        require(all(type(minutes[k]) is int for k in ("min", "max")), f"{label}: minutes must be integers")
        require(0 <= minutes["min"] <= minutes["max"], f"{label}: minutes must satisfy 0 <= min <= max")
    for key in ("car_required", "overnight_required"):
        require(mobility[key] is None or type(mobility[key]) is bool, f"{label}: {key} must be true/false/null")
    if claim["status"] == "unknown":
        require(all(mobility[k] is None for k in MOBILITY_FACTS), f"{label}: unknown claim cannot carry mobility values")


def check_applies(applies, label):
    require(isinstance(applies, dict) and set(applies) == APPLIES_FIELDS,
            f"{label}: applies must have exactly {sorted(APPLIES_FIELDS)}")
    start = end = None
    if applies["date_from"] is not None:
        start = parse_date(applies["date_from"], f"{label}.applies.date_from")
    if applies["date_through"] is not None:
        end = parse_date(applies["date_through"], f"{label}.applies.date_through")
    require(start is None or end is None or start <= end, f"{label}: applies.date_from is after date_through")
    months = applies["months"]
    require(months is None or (isinstance(months, list) and months and len(set(months)) == len(months)
                               and all(type(m) is int and 1 <= m <= 12 for m in months)),
            f"{label}: months must be null or unique integers 1-12")
    require(is_text_list(applies["conditions"]), f"{label}: applies.conditions must be a list of text")


def check_cost(claim, label, today):
    cost = claim["cost"]
    if claim["kind"] != "price" or claim["status"] == "unknown":
        require(cost is None, f"{label}: cost only on known price claims")
        return
    require(isinstance(cost, dict), f"{label}: known price claim needs cost")
    require(set(cost) == COST_FIELDS, f"{label}: cost must have exactly {sorted(COST_FIELDS)}")
    require(isinstance(cost["currency"], str) and re.fullmatch(r"[A-Z]{3}", cost["currency"]),
            f"{label}: currency must be an ISO 4217 code")
    require(cost["basis"] in {"per_person", "per_group"}, f"{label}: basis must be per_person/per_group")
    require(is_positive_int(cost["party_size"]), f"{label}: party_size must be a positive integer")
    low, high = cost["amount_min"], cost["amount_max"]
    require(is_number(low) and is_number(high) and 0 <= low <= high,
            f"{label}: amounts must be numbers with 0 <= min <= max")
    as_of = parse_date(cost["as_of"], f"{label}.cost.as_of")
    require(as_of <= today, f"{label}: cost as_of is in the future")
    require(is_text(cost["period"]), f"{label}: cost period required")
    require(is_text_list(cost["includes"]) and cost["includes"], f"{label}: cost includes must list what is paid for")
    require(is_text_list(cost["excludes"]), f"{label}: cost excludes must be a list of text")


def check_claim(claim, label, today, destination_ids):
    require(claim['usage'] in {'recommendation', 'detail_only'}, f'{label}: invalid usage')
    require(claim["kind"] in CLAIM_KINDS, f"{label}: unknown kind")
    require(claim["status"] in STATUSES, f"{label}: unknown status")
    require(is_positive_int(claim["version"]), f"{label}: version must be a positive integer")
    require(bool(claim.get("area")), f"{label}: area required")
    check_applies(claim["applies"], label)

    status = claim["status"]
    if status == "unknown":
        require(claim["statement"] is None and bool(claim["question"]), f"{label}: unknown must stay a question")
        require(claim["source"] is None and claim["review"] is None, f"{label}: unknown cannot have source/review")
    else:
        require(bool(claim["statement"]) and claim["question"] is None, f"{label}: known claim needs statement only")
        checked = check_source(claim["source"], label, today)
        if status == "unreviewed":
            require(claim["review"] is None, f"{label}: unreviewed claim cannot have a review record")
        elif status == "reviewed":
            check_review(claim, label, checked, today)
        else:
            require(bool(claim.get("notes")), f"{label}: withheld claim needs a reason in notes")
            if claim["review"] is not None:
                check_review(claim, label, checked, today)
    check_mobility(claim, label, destination_ids)
    check_cost(claim, label, today)


def check_places(data, claims):
    """Check references only; runtime must also check review, expiry and meaning."""
    places = {p['id']: p for p in data['places']}
    require(len(places) == len(data['places']), 'duplicate place id')
    for pid, place in places.items():
        require(is_text(pid) and is_text(place['name']), 'place id/name required')
        require(place['scope_relation'] in {'inside', 'outside', 'unknown'}, f'{pid}: invalid scope relation')
        evidence = place['scope_evidence_ids']
        require(is_text_list(evidence), f'{pid}: scope evidence must be a list')
        require(all(ref in claims and claims[ref]['kind'] == 'location'
                    and claims[ref]['usage'] == 'recommendation' for ref in evidence),
                f'{pid}: scope needs location evidence')
        if place['scope_relation'] != 'unknown':
            require(evidence and all(claims[ref]['status'] != 'unknown' for ref in evidence),
                    f'{pid}: known relation needs a source-backed location claim')
    for exp in data['experiences']:
        label = exp['id']
        require(is_text_list(exp['place_ids']) and exp['place_ids'], f'{label}: place ids required')
        require(len(set(exp['place_ids'])) == len(exp['place_ids']), f'{label}: duplicate place reference')
        require(set(exp['place_ids']) <= places.keys(), f'{label}: unknown place reference')
        requirements = exp['travel_requirements']
        require(set(requirements) == {'boat_required', 'overnight_required'}, f'{label}: invalid travel requirements')
        for key, requirement in requirements.items():
            require(set(requirement) == {'value', 'evidence_ids'}, f'{label}/{key}: invalid fields')
            value, evidence = requirement['value'], requirement['evidence_ids']
            require(value is None or type(value) is bool, f'{label}/{key}: value must be bool/null')
            require(is_text_list(evidence), f'{label}/{key}: evidence must be a list')
            require(all(ref in claims and claims[ref]['kind'] in {'transport', 'access'}
                        and claims[ref]['usage'] == 'recommendation' for ref in evidence),
                    f'{label}/{key}: invalid travel evidence')
            if value is not None:
                require(evidence and all(claims[ref]['status'] != 'unknown' for ref in evidence),
                        f'{label}/{key}: known value needs source-backed evidence')


def check_file(path, data, categories, category_version, destination_ids, today):
    destination = data["destination"]
    did = destination["id"]
    require(data["schema_version"] == 3 and data["dataset_kind"] == "catalog", f"{path.name}: expected v3 catalog")
    require(data["category_version"] == category_version, f"{path.name}: category version differs")
    require(is_positive_int(data["data_version"]), f"{path.name}: data_version must be a positive integer")
    require(re.fullmatch(r"[a-z]{2}-[a-z0-9-]+", did), f"{path.name}: bad destination id")
    require(path.stem == did, f"{path.name}: file name must match destination id")
    require(destination["kind"] in DESTINATION_KINDS, f"{did}: bad destination kind")
    require(destination["review_status"] in DESTINATION_STATUSES, f"{did}: bad review_status")
    require(destination["country_codes"] and all(re.fullmatch(r"[A-Z]{2}", c) for c in destination["country_codes"]),
            f"{did}: bad country codes")
    coverage = destination["coverage"]
    require(bool(coverage["description"]), f"{did}: coverage description required")
    require(set(coverage["gateway_city_ids"]) <= destination_ids, f"{did}: unknown gateway city id")

    claims = {item["id"]: item for item in data["claims"]}
    require(len(claims) == len(data["claims"]), f"{did}: duplicate claim id")
    check_places(data, claims)
    require(len({e["id"] for e in data["experiences"]}) == len(data["experiences"]), f"{did}: duplicate experience id")
    refs = [("coverage", ref) for ref in coverage["evidence_ids"]]
    for item in data["experiences"]:
        require(item["categories"] and set(item["categories"]) <= categories, f"{did}/{item['id']}: unknown category")
        refs += [(item["id"], ref) for ref in item["evidence_ids"] + item["constraint_evidence_ids"]]
    for number, item in enumerate(data["summary"], 1):
        require(bool(item["text"]) and bool(item["evidence_ids"]), f"{did}: summary {number} needs text and evidence")
        refs += [(f"summary {number}", ref) for ref in item["evidence_ids"]]
    broken = sorted({f"{owner}->{ref}" for owner, ref in refs if ref not in claims})
    require(not broken, f"{did}: broken evidence references {broken}")
    require(all(claims[ref]['usage'] == 'recommendation' for _, ref in refs),
            f'{did}: detail-only evidence in recommendation input')

    for cid, claim in claims.items():
        check_claim(claim, f"{did}/{cid}", today, destination_ids)
    return Counter(claim["status"] for claim in claims.values())


def check():
    root = Path(__file__).resolve().parents[1]
    today = datetime.now(ZoneInfo("Asia/Seoul")).date()
    vocabulary = json.loads((root / "data/experience-categories.json").read_text())
    categories = {item["id"] for item in vocabulary["categories"]}
    plan = json.loads((root / "data/planning/destination-candidates.json").read_text())
    paths = sorted(p for p in (root / "data/cities").glob("*.json") if p.name != "example.json")
    files = {p: json.loads(p.read_text()) for p in paths}
    destination_ids = {data["destination"]["id"] for data in files.values()}
    require(len(destination_ids) == len(files), "duplicate destination id across files")

    links = [row for row in plan["candidates"] if row.get("recommendation_destination_id")]
    linked = Counter(row["recommendation_destination_id"] for row in links)
    require(all(count == 1 for count in linked.values()), "a destination is linked from several candidates")
    require(set(linked) == destination_ids, f"planning links and catalog files differ: {sorted(set(linked) ^ destination_ids)}")
    kinds = {data["destination"]["id"]: data["destination"]["kind"] for data in files.values()}
    for row in links:
        require(row.get("recommendation_unit") == kinds[row["recommendation_destination_id"]],
                f"{row['id']}: recommendation_unit differs from destination kind")

    total = Counter()
    for path, data in files.items():
        counts = check_file(path, data, categories, vocabulary["version"], destination_ids, today)
        total += counts
        print(f"{data['destination']['id']} (data_version {data['data_version']}): "
              + ", ".join(f"{status} {counts[status]}" for status in sorted(STATUSES)))
    print(f"PASS: {len(files)} catalog file(s), as of {today} KST. "
          + ", ".join(f"{status} {total[status]}" for status in sorted(STATUSES))
          + ". Review records are format-checked only.")


if __name__ == "__main__":
    try:
        check()
    except (ValueError, KeyError, TypeError) as error:
        sys.exit(f"FAIL: {type(error).__name__}: {error}")
