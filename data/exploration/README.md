# 목록 대 프로필 탐색 실험 입력

계획과 결과: [profile-exploration.md](../../docs/evaluation/profile-exploration.md) v5. 실행: `scripts/run_profile_exploration.py`.

- `profile-prompt.md`: 프로필 작성 지침 v2. 도시 목록·기존 범위안·형식만 담고 시험 사례는 담지 않는다.
- `profiles.json`: 20곳 프로필 초안. 2026-10-06 Claude Opus 5.5가 위 지침 파일만 읽고 작성했다(Claude Code 세션의 별도 에이전트, 웹·다른 파일 미사용이라고 보고). 사람 보정·출처 대조 전이며 앱에 노출하지 않는다.
- `cases.json`: 계획 문서의 합성 사례 6개 문장.
- `expectations.md`: 호출 전에 고정한 사례별 위반 기준과 대조 출처. AI 작성, 사람 확인 전.
- `profiles-constraints.json`: 실행 2의 제약 중심 입력(B′). `profiles.json`에서 범위와 제약만 기계적으로 옮기고 호놀룰루 “긴 비행” 제약 1건을 뺐다. 문장은 고치지 않았다.
- `runs/`: 실행 1(목록 대 전체 프로필)의 호출 기록, 방식을 가린 검수 시트와 대응표, AI 검수.
- `runs2/`: 실행 2(목록 대 제약 중심 입력)의 기록. `--run 2`로 실행한다.

실행별 첫 호출 뒤에는 그 실행의 입력을 고치지 않는다. 고치면 새 실행으로 기록한다.

## 추천 지침 비교 (실행 3·4)

계획: [guideline-comparison.md](../../docs/evaluation/guideline-comparison.md).

- `guidelines/`: 실행 3에 쓰는 지침 고정본. `g1-claude.md`, `g2-codex.md`. 세 줄표(`---`) 아래가 모델에 보내는 본문이다.
- `cases-n.json`: 개발용 사례 N1~N6의 문장. 판정 기준은 `drafts/cases-claude.md`.
- `drafts/`: 지침·사례 초안. `cases-c.md`는 지침 고정 뒤에 쓰는 확인용 사례 C1~C6이다.
- `cases-c.json`: 확인용 사례 C1~C6의 문장. 판정 기준은 `drafts/cases-c.md`.
- `runs3/`: 실행 3의 기록. `--run 3`으로 실행한다.
- `runs4/`: 실행 4(같은 세 지침, C1~C6)의 기록. `--run 4`로 실행한다. 결과는 [`runs4/result-r0.md`](runs4/result-r0.md)(검수자 2명 기준, 선택 보류).
