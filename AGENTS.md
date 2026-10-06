# TripDNA instructions

## Communication and judgment

- Respond to the user in Korean by default. Keep code, commands, and proper names in their original form.
- Never invent facts, file paths, APIs, or test results. State clearly what you could not verify.
- If evidence contradicts the user's premise, explain why. For significant design decisions, consider alternatives, counterexamples, costs, and risks without adding unnecessary analysis to simple tasks.
- In the final report, distinguish changes made, checks actually run, and remaining limitations.

## Project context

- The root `README.md` is authoritative for product goals and scope. Use `docs/README.md` to find relevant detail and read only what the task needs.
- Distinguish the current app implementation from the new recommendation design. Do not report a documented goal as an implemented feature.
- The Xcode project is `TripDNA.xcodeproj`, the scheme is `TripDNA`, and the test targets are `TripDNATests` and `TripDNAUITests`.

## Build and test

- Build: `xcodebuild -quiet -project TripDNA.xcodeproj -scheme TripDNA -destination 'generic/platform=iOS Simulator' build` (`-quiet` prints only warnings and errors; judge success by exit code)
- Compile tests without running them: same command with `build-for-testing` instead of `build`.
- Run unit tests: `xcodebuild -quiet -project TripDNA.xcodeproj -scheme TripDNA -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:TripDNATests`. If that device is missing, pick one from `xcrun simctl list devices available`; if that list is empty, no simulator runtime is installed, so report that tests could not run.
- Done means the build succeeds, relevant tests pass (or the reason they could not run is reported), and `graphify update .` has run after code changes.

## Code changes

- Inspect the relevant code and call flow, and follow existing patterns. Change only what the request requires; avoid speculative features and abstractions.
- Run tests relevant to the change. If a test cannot run or fails, report the reason and result instead of claiming success.
- Preserve the user's existing changes. Do not clean up or revert unrelated files.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
