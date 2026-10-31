#!/usr/bin/env python3
"""Sync TripDNA/Localizable.xcstrings with the code, then report keys missing Korean.

Usage: scripts/l10n_sync.py [--no-build] [--clean] [ko-map.json ...]
  ko-map.json: {"<catalog key>": "<Korean>"}; fills ko for those keys.
Exit 1 if any key lacks a translated ko value.
"""
import glob, json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "TripDNA/Localizable.xcstrings"
DD = ROOT / "build/l10n"

args = sys.argv[1:]
if "--no-build" in args:
    args.remove("--no-build")
else:
    # Incremental builds only re-emit changed files, so never delete .stringsdata here.
    # After deleting or renaming a source file, run once with --clean to drop its keys.
    if "--clean" in args:
        args.remove("--clean")
        subprocess.run(["rm", "-rf", str(DD)], check=True)
    subprocess.run(["xcodebuild", "-quiet", "-project", "TripDNA.xcodeproj", "-scheme", "TripDNA",
                    "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", str(DD), "build"],
                   cwd=ROOT, check=True)
    data = sorted(f for f in glob.glob(f"{DD}/**/*.stringsdata", recursive=True) if "/TripDNA.build/" in f)
    if not data:
        sys.exit("no .stringsdata found; is SWIFT_EMIT_LOC_STRINGS on?")
    subprocess.run(["xcrun", "xcstringstool", "sync", str(CATALOG), "--stringsdata", *data], check=True)

cat = json.loads(CATALOG.read_text())
strings = cat["strings"]
for path in args:
    for key, ko in json.loads(Path(path).read_text()).items():
        if key in strings:
            strings[key].setdefault("localizations", {})["ko"] = {"stringUnit": {"state": "translated", "value": ko}}
# Drop keys no longer in code so the catalog stays the truth.
for key in [k for k, v in strings.items() if v.get("extractionState") == "stale"]:
    del strings[key]
CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

missing = [k for k, v in strings.items()
           if v.get("shouldTranslate", True) and k.strip()
           and v.get("localizations", {}).get("ko", {}).get("stringUnit", {}).get("state") != "translated"
           and "variations" not in v.get("localizations", {}).get("ko", {})]
print(f"{len(strings)} keys, {len(missing)} missing ko")
for k in missing:
    print("  MISSING ko:", json.dumps(k, ensure_ascii=False))
sys.exit(1 if missing else 0)
