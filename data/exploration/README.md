# 목록 대 프로필 탐색 실험 입력

계획: [profile-exploration.md](../../docs/evaluation/profile-exploration.md) v4. 실행: `scripts/run_profile_exploration.py`.

- `profile-prompt.md`: 프로필 작성 지침 v2. 도시 목록·기존 범위안·형식만 담고 시험 사례는 담지 않는다.
- `profiles.json`: 20곳 프로필 초안. 2026-10-06 Claude Opus 5.5가 위 지침 파일만 읽고 작성했다(Claude Code 세션의 별도 에이전트, 웹·다른 파일 미사용이라고 보고). 사람 보정·출처 대조 전이며 앱에 노출하지 않는다.
- `cases.json`: 계획 문서의 합성 사례 6개 문장.
- `expectations.md`: 호출 전에 고정한 사례별 위반 기준과 대조 출처. AI 작성, 사람 확인 전.
- `runs/`: 호출 기록(`responses.jsonl`)과 방식을 가린 검수 시트.

첫 호출 뒤에는 위 입력을 고치지 않는다. 고치면 새 실행으로 기록한다.
