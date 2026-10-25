#!/usr/bin/env python3
"""catalog.json에서 앱 번들용 TripDNA/Resources/cities.json을 만든다.

앱이 쓰는 필드만 담는다. 핵심 경험 문장(core)과 검수·출처 필드는 넣지 않는다
(2026-10-25 결정: MVP에서는 LLM 입력에 쓰지 않는다).
"""
import hashlib
import json
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
catalog = json.loads((root / "data/destinations/catalog.json").read_text())

levels = [l["id"] for l in catalog["levels"]]
concepts = {cid: list(c["sub"]) for cid, c in catalog["concepts"].items()}
cities = []
for cid, c in sorted(catalog["cities"].items()):
    cities.append({
        "id": cid,
        "ko": c["name"]["ko"],
        "en": c["name"]["en"],
        "country": c["country"],
        "grades": c["grades"],
        "season": c["season"],
        "seasonUnverified": c["season_unverified"],
    })

body = {"levels": levels, "concepts": concepts, "cities": cities}
digest = hashlib.sha256(json.dumps(body, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:8]
out = {"version": f"{catalog['updated_on']}-{digest}", **body}
path = root / "TripDNA/Resources/cities.json"
path.write_text(json.dumps(out, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
print(path, out["version"], len(cities))
