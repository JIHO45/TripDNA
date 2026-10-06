"""Check D2 selection bookkeeping, not destination facts or travel feasibility."""

import json
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

REGION_LABELS = {
    "east_asia": "동아시아", "southeast_asia": "동남아시아", "south_asia": "남아시아",
    "europe": "유럽", "west_asia": "서아시아", "africa": "아프리카",
    "north_america": "북미", "latin_america": "중남미", "oceania": "오세아니아",
}
RANK_EVIDENCE = {"official", "press_two_outlets", "press_one_outlet"}
SOURCE_ACCESS = {"page_read", "page_limited", "search_excerpt"}
SUPPLEMENT_REQUIREMENTS = {"todo_d2_nature_gateway_min_4"}


def region_summary(rows):
    counts = Counter(row["region"] for row in rows)
    return ", ".join(f"{label} {counts[key]}" for key, label in REGION_LABELS.items() if counts[key])


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check():
    root = Path(__file__).resolve().parents[1]
    plan = json.loads((root / "data/planning/destination-candidates.json").read_text())
    document = (root / "docs/data/destination-selection.md").read_text()
    updated_on = date.fromisoformat(plan["updated_on"])
    rows = plan["candidates"]
    ids = [row["id"] for row in rows]
    require(len(ids) == len(set(ids)), "duplicate candidate id")

    base = [row for row in rows if row["origin"] == "euromonitor_2025"]
    supplements = [row for row in rows if row["origin"] == "supplement"]
    require(len(base) + len(supplements) == len(rows), "unknown origin")
    require(sorted(row["source_rank"] for row in base) == list(range(1, 101)), "base ranks must be 1..100")
    require(len({row["source_name"] for row in base}) == 100, "duplicate source_name")

    listed = dict(re.findall(r"^- `([^`]+)` (.+)$", document, re.M))
    require(set(listed) == set(ids), "document list and JSON ids differ")

    pilot = [row for row in rows if row["pilot"]]
    gateways = [row for row in rows if row["nature_gateway_test"]]
    require(15 <= len(pilot) <= 20, "pilot must be 15-20 cities")
    require(len(gateways) >= 4 and all(row["pilot"] for row in gateways), "need >=4 pilot nature gateways")

    json_urls = {s["url"] for s in plan["base_list"]["official_sources"] + plan["base_list"]["press_sources"]}
    for row in rows:
        cid, line = row["id"], listed[row["id"]]
        require(re.fullmatch(r"[a-z]{2}-[a-z0-9-]+", cid), f"{cid}: bad id")
        require(cid.startswith(row["country_code"].lower() + "-"), f"{cid}: id/country mismatch")
        require(row["name_ko"] in line, f"{cid}: name missing in document")
        require(("**파일럿**" in line) == row["pilot"], f"{cid}: pilot mark mismatch")
        require(("**자연 거점**" in line) == row["nature_gateway_test"], f"{cid}: gateway mark mismatch")
        if row["origin"] == "euromonitor_2025":
            require(row["rank_evidence"] in RANK_EVIDENCE, f"{cid}: bad rank_evidence")
            require(row["scope_mapping"] == "unverified", f"{cid}: scope mapping must stay unverified until D3")
            require(line.startswith(f"{row['source_rank']}위 ") and row["source_name"] in line, f"{cid}: rank/source name missing")
        else:
            require(row["supplement_requirement"] in SUPPLEMENT_REQUIREMENTS and row["supplement_reason"]
                    and row["supplement_experience"], f"{cid}: supplement needs requirement, reason and experience")
            require(row["supplement_status"] == "provisional" and isinstance(row["base_alternative_checked"], bool),
                    f"{cid}: supplement must record provisional status and base-alternative check")
            require(row["supplement_experience"] in document, f"{cid}: supplement experience missing in document")
            require(line.startswith("**보충** "), f"{cid}: supplement mark missing")
        if row["pilot"]:
            require(row["pilot_question"] in line, f"{cid}: pilot question missing")
            require(row["scope_proposal"] in document and row["source_leads"], f"{cid}: scope or source lead missing")
        for source in row.get("source_leads", []):
            require(source["url"].startswith("https://"), f"{cid}: non-https source")
            require(source["access"] in SOURCE_ACCESS, f"{cid}: bad access value")
            require(source["claim_review_status"] == "not_started", f"{cid}: claim review must not be marked")
            require(date.fromisoformat(source["discovered_on"]) <= updated_on, f"{cid}: source date after update")
            json_urls.add(source["url"])
        json_urls.update(ref["url"] for ref in row.get("scope_references", []))

    document_urls = set(re.findall(r"\]\((https://[^)\s]+)\)", document))
    require(document_urls <= json_urls, f"document links missing from JSON: {sorted(document_urls - json_urls)}")
    require(json_urls <= document_urls, f"JSON links missing from document: {sorted(json_urls - document_urls)}")

    for label, subset in (("원본", base), ("보충", supplements), ("파일럿", pilot)):
        require(f"{label}: {region_summary(subset)}." in document, f"{label} region counts in document are stale")

    print(f"PASS: {len(base)} base + {len(supplements)} supplements, {len(pilot)} pilot, "
          f"{len(gateways)} nature gateways; document, links and region counts match.")
    for label, subset in (("Base", base), ("Supplement", supplements), ("Pilot", pilot)):
        print(f"{label} regions: {region_summary(subset)}")


if __name__ == "__main__":
    try:
        check()
    except ValueError as error:
        sys.exit(f"FAIL: {error}")
