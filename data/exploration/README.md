# 목록 대 프로필 탐색 실험 입력

2026-10-08 정합성 보완: 실행 5의 오래된 호출 전 상태를 고쳤다. 고정 계획·입력·응답은 수정하지 않았다.
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

## 검색·제약 입력·상위 모델 비교 (실행 5)

계획: [run5-plan.md](../../docs/evaluation/run5-plan.md). 2026-10-07에 고정한 계획이며 실행은 76건에서 종료했다. 아래 부분 결과를 따른다.

- `guidelines/r5-agents.md`: 모델이 받는 지침 전부. 검색 없는 방식용(`list`), 검색 방식 공용(`search`), 제약 입력 안내문(`constraints-header`) 세 블록과 방식별 조합표가 있다.
- `drafts/cases-r5.md`: 사례 R1~R12의 문장·판정 기준·확인한 사실. 기존 실패 사례 4개와 새 사례 8개.
- `cases-r5.json`: 위 파일에서 문장만 옮긴 것.
- 실행: `--run 5`. 기록은 `runs5/`에 남는다. 76건 기준 [부분 결과](runs5/result-partial.md)가 있다(크레딧 부족으로 중단, 계획한 판정 아님).

## Gemini로 실행 5의 구성 반복 (실행 6)

계획: [run6-plan.md](../../docs/evaluation/run6-plan.md). 사례는 실행 5의 `cases-r5.json`을 그대로 쓴다.

- `guidelines/r6-agents.md`: 세 방식(Flash + 검색, Flash + 검색 + 제약 입력, Pro + 검색)이 함께 쓰는 `search2` 블록과 제약 입력 안내문. 실행 5의 검색 지침에 형식 규칙을 보강했다.
- 실행: `--run 6`. 기록은 `runs6/`에 남는다. Gemini 호출에는 `GEMINI_API_KEY`가 필요하다. 72건의 [결과](runs6/result.md)가 있다(검수자 1명, 잠정). 스트리밍 시간 측정은 `scripts/measure_gemini_streaming.py`, 기록은 `runs6-stream/`.

## 컨셉 매칭 계산과 칩 대 LLM 비교 (2026-10-08)

설계: [컨셉 기반 추천](../../docs/recommendation/README.md#2026-10-08-결정-컨셉-기반-추천). 실행 1~6과 별개의 탐색이며 채택 판정이 아니다.

- `coverage-check/`: LLM 없이 코드로 계산한 기록. `grades.json`은 파일럿 20곳 × 경험 9개, `grades-v2.json`은 큰 컨셉 10개와 세부 29개의 등급 초안(둘 다 미검수). 결과는 [`result.md`](coverage-check/result.md), [`result-v2.md`](coverage-check/result-v2.md). 실행: `scripts/check_coverage_match.py`, `scripts/check_concept_match.py`.
- `chips-vs-llm/`: 칩만 준 경우와 자유문장을 더한 경우를 Gemini Flash + 검색으로 비교한 26호출. [`plan.md`](chips-vs-llm/plan.md), [`result.md`](chips-vs-llm/result.md)(판정자 AI 1명, 잠정). 실행: `scripts/run_chips_vs_llm.py`.

## 저장소에 올리지 않는 기록 (2026-10-12)

Google 검색을 쓴 Gemini 응답의 원본은 저장소에 넣지 않는다: `runs6/responses.jsonl`, `runs6-stream/timings.jsonl`, `chips-vs-llm/responses.jsonl`. [Gemini API 추가 약관](https://ai.google.dev/gemini-api/terms)의 “Google 검색을 사용한 그라운딩” 조항이 그라운딩된 결과의 복사·배급과 링크의 저장을 제한하기 때문이다(2026-10-12 확인). 파일은 실행한 기기에만 있고 `.gitignore`에 적혀 있다. 결과 문서의 집계는 그 원본에서 계산한 것이며, 원본이 없는 곳에서는 `--report`와 재집계를 할 수 없다. 같은 조항은 표시한 결과의 텍스트 보관을 최대 30일로 제한한다. 기기의 원본을 언제 지울지는 정하지 않았다.
