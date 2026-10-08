#!/usr/bin/env python3
"""Time-to-first-text for Gemini Flash with Google Search, streamed (follow-up to run 6).

  python3 scripts/measure_gemini_streaming.py --dry-run
  python3 scripts/measure_gemini_streaming.py            # 6 detail + 3 recommend calls

Same model, prompt and inputs as run 6's FS arm; only `stream` differs. For each call it logs when the
first event, the first search call, the first answer text and the end arrived. Not a quality run:
the answers are kept only so the timings can be checked. Needs GEMINI_API_KEY.
"""
import argparse
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

import run_profile_exploration as r

LOG = r.EXP / "runs6-stream" / "timings.jsonl"
CALLS = [(c, "detail") for c in ("R5", "R6", "R8", "R9", "R10", "R12")] + [(c, "recommend") for c in ("R5", "R9", "R12")]


def stream_call(system, user):
    body = {"model": r.FLASH, "input": user, "system_instruction": system, "store": False, "stream": True,
            "tools": [{"type": "google_search"}],
            "generation_config": {"max_output_tokens": r.MAX_TOKENS, "thinking_level": "low"}}
    req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/interactions",
                                 data=json.dumps(body).encode(), method="POST",
                                 headers={"x-goog-api-key": os.environ["GEMINI_API_KEY"], "Content-Type": "application/json"})
    ca = "/etc/ssl/cert.pem"
    tls = ssl.create_default_context(cafile=ca if os.path.exists(ca) else None)
    row = {"events": {}, "queries": [], "text": ""}
    start = time.monotonic()
    mark = lambda name: row.setdefault(name, round(time.monotonic() - start, 2))
    with urllib.request.urlopen(req, timeout=180, context=tls) as resp:
        for raw in resp:  # one SSE line at a time
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            mark("first_event_s")
            try:
                ev = json.loads(line[5:])
            except ValueError:
                continue
            kind = ev.get("event_type", "?")
            delta = ev.get("delta") or {}
            name = f"{kind}:{delta['type']}" if delta.get("type") else kind
            row["events"][name] = row["events"].get(name, 0) + 1
            if delta.get("type") == "google_search_call":
                mark("first_search_s")
                row["queries"] += (delta.get("arguments") or {}).get("queries") or []
            elif delta.get("type") == "google_search_result":
                row["last_search_result_s"] = round(time.monotonic() - start, 2)
            elif delta.get("type") == "text" and delta.get("text"):
                mark("first_text_s")
                row["text"] += delta["text"]
            if kind == "interaction.completed":
                inter = ev.get("interaction") or {}
                row.update(status=inter.get("status"), usage=inter.get("usage"))
    row["total_s"] = round(time.monotonic() - start, 2)
    return row


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    r.configure(6)
    cities, profiles, cases = r.load_inputs()
    by_id = {c["id"]: c for c in cases}
    done = {json.loads(line)["key"] for line in LOG.read_text().splitlines()} if LOG.exists() else set()
    todo = [(c, t) for c, t in CALLS if f"{c}-FS-{t}-stream" not in done]
    if args.dry_run:
        print(f"{len(todo)} call(s) pending, {len(done)} logged:", " ".join(f"{c}-{t}" for c, t in todo))
        return
    LOG.parent.mkdir(parents=True, exist_ok=True)
    for case, task in todo:
        row = {"key": f"{case}-FS-{task}-stream", "case": case, "task": task, "model": r.FLASH,
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        try:
            row.update(stream_call(r.BLOCKS["search2"], r.build_user("FS", task, by_id[case], cities, profiles)))
        except urllib.error.HTTPError as e:
            row["error"] = f"HTTP {e.code}: {e.read().decode(errors='replace')[:500]}"
        except (urllib.error.URLError, TimeoutError) as e:
            row["error"] = f"{type(e).__name__}: {e}"
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {row['key']}: {row['error']}")
        print(row["key"], f"search {row.get('first_search_s')}s  first text {row.get('first_text_s')}s  "
              f"end {row['total_s']}s  queries {len(row['queries'])}  {row['events']}")


if __name__ == "__main__":
    main()
