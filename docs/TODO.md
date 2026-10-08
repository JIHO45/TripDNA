# 실행 상태

기준일: 2026-10-08. 이 문서는 **상태·다음 행동·산출물·실제 검증**만 기록한다. 기준은 [현재 문서 목차](README.md), 과거 작업 번호·완료 근거는 git 태그 `docs-versioned-2026-10-07`의 `docs/v1/progress.md`에 있다. 정책·실험 결과를 여기에 다시 쓰지 않는다.

## 현재 구현과 보존 자료

현행 앱의 연결은 [AppDependencies](../TripDNA/App/AppDependencies.swift)의 국가 자료·RecommendationService와 [SwiftDataStore](../TripDNA/Infrastructure/SwiftDataStore.swift)에 있다. 이번 작업은 문서 변경이며 도시·LLM·검색 앱 구현을 추가하지 않았다.
B1·D1·D2의 이전 완료 기록은 같은 파일에 있다. 해당 검증을 이번 작업에서 다시 실행한 것으로 해석하지 않는다.
기존 도시 자료와 실험 입력·원본 응답·검수표는 [자료 목차](../data/exploration/README.md) 및 [후보 계약](README.md#candidates)에서 찾는다.

## 다음 작업

- [x] **초기 취향·지문 합의 문서 복원:** 2026-10-07, [제품 원칙](../README.md#취향과-추천의-핵심-원칙), [기억](recommendation/memory.md), [추천 구조](recommendation/README.md), [지문 화면](screens/home-and-fingerprint.md#취향-지문)에 반영하고 관련 화면·목차의 표현을 맞췄다. 이후 목록·실험 우선·구독 결정은 유지했다. 앱 구현 완료를 뜻하지 않는다.
- [ ] **컨셉 지문 표시 구현:** [지문 화면](screens/home-and-fingerprint.md#취향-지문)에 따라 여행별 컨셉 기록과 집계, 표시를 구현한다. 2026-10-07의 5축 요약 계획은 2026-10-08에 철회했다. 미구현.
- [x] **컨셉 기반 추천 설계 문서화:** 2026-10-08, [추천 구조](recommendation/README.md#2026-10-08-결정-컨셉-기반-추천), [컨셉과 티어](recommendation/memory.md#컨셉과-티어), 화면 문서 7개. 근거 기록은 `data/exploration/coverage-check/`와 `data/exploration/chips-vs-llm/`. 검사: 로컬 링크·앵커, `git diff --check`. 앱 코드는 바꾸지 않아 빌드·테스트는 실행하지 않았다.
- [x] **추천 흐름 재정리 문서화:** 2026-10-08, 매 추천 LLM 호출, 주 컨셉 필수, 도시별 평가와 메모 입력, 카드 행동, 목록 밖 도시, 자동 일정 생성기의 제외 범위 해제. [추천 구조](recommendation/README.md#흐름), [기억](recommendation/memory.md), [추천 화면](screens/recommendations.md), [여행 평가](screens/trip-evaluation.md), [루트 README](../README.md#범위). 검사: 로컬 링크·앵커, `git diff --check`.
- [x] **추천 흐름의 문서 간 정합성 보완:** 2026-10-08, 저장·전송, 화면, 평가·계측·출시, 목차의 이전 규칙을 최신 흐름에 맞췄다. 0개 결과의 예산 초과 대안과 새 LLM 재호출의 무료 처리는 미정으로 유지했다. 검사: 30개 문서의 로컬 링크·앵커 300개, `git diff --check`, `check_destination_candidates.py` 통과. 시뮬레이터 대상 빌드는 샌드박스의 DerivedData·서비스 접근 제한으로 첫 시도 실패 후 권한을 확보해 성공했다. 앱 코드 변경이 없어 단위·UI 테스트는 실행하지 않았다. `graphify update .`로 코드·Markdown 구조를 갱신하고 새 절이 질의에 나타나는 것을 확인했다. Swift 두 파일의 부분 추출 경고는 남아 있으며, LLM 의미 추출·커뮤니티 이름 재생성은 하지 않았다. 커밋하지 않았다.
- [ ] **컨셉 기반 추천의 미정 사항 결정:** [추천 구조의 미정 목록](recommendation/README.md#미정)과 [등급 갱신에 필요한 결정](recommendation/README.md#여행지-값의-갱신-출시-후). 세부 목록 확정과 기준 파일 v2, 사람이 판정한 취향 사례, 100곳 이상의 자료 제작이 앞선다.

- [x] **문서를 주제당 하나로 정리:** `v1/`·`v2/` 폴더와 채택 철회 초안을 없애고 주제별 문서를 제자리에서 고치는 방식으로 바꿨다. 2026-10-07, [목차](README.md). 화면·저장·계측 문서의 최신화는 [남은 목록](README.md#아직-최신화하지-못한-부분)에 있다.
- [x] **실행 4 검수 마무리:** 2026-10-07, [결과 집계](../data/exploration/runs4/result-r0.md). 검수자 2명 기준으로 선택 보류이며 이후 실험은 G0으로 진행한다. 계획한 제3 검수는 받지 못했고 틀린 사실 항목은 대부분 미판정으로 남았다.
- [x] **다음 실험 고정본 작성:** 2026-10-07 고정. [실행 5 계획](evaluation/run5-plan.md), [에이전트 지침](../data/exploration/guidelines/r5-agents.md), [사례 R1~R12](../data/exploration/drafts/cases-r5.md), 입력 해시 `467f421fb3f74493`. Console의 남은 한도는 확인하지 못했다.
- [x] **실행 도구 준비·검사:** 2026-10-07, `scripts/run_profile_exploration.py --run 5`. `--dry-run`과 가짜 응답 검사 통과, 실행 1~4 입력 해시 유지. 실제 API 호출은 하지 않았다.
- [x] **실행 5:** 96호출 중 76건에서 멈췄고 남은 호출은 하지 않기로 했다(2026-10-07). [부분 결과](../data/exploration/runs5/result-partial.md)가 최종 기록이며 계획한 판정은 아니다.
- [ ] **실행 6 (Gemini만, 실행 5의 세 구성):** 2026-10-07에 72건을 실행했고 [잠정 결과](../data/exploration/runs6/result.md)가 있다(검수자 1명, 방식을 가리지 않음). 남은 것: 계획한 가린 검수 2명, 모델·검색 구성의 채택 판정. [계획](evaluation/run6-plan.md), [지침](../data/exploration/guidelines/r6-agents.md).
- [ ] **구독·저장 결정의 후속:** 2026-10-07에 LLM 기능의 구독 도입, 도시 자료의 앱 번들 배포, 외부 DB 보류를 정했다([추천 구조](recommendation/README.md#2026-10-07-추가-결정-구독-자료-배포-저장)). 서버와 서버 저장은 Firebase(Cloud Functions, Firestore)로 정하고 제외를 해제했다. 구독자 한정 제공과 무료 사용자 LLM 미사용은 2026-10-08에 철회했다. 미정: 가격과 상품 형태, 무료·구독 사용자의 LLM 사용 범위, 사용자별 사용량 한도와 그에 필요한 서버 저장. 화면·출시·저장 문서에는 현재 결정과 미정 범위를 반영했다. 실제 정책 확정과 구현은 남아 있다.
- [ ] **방식 채택·확대 판정:** [평가](README.md#evaluation)에 따라 결정한다. 과거 D3/V1의 전체 프로필 제작·확대를 자동 재개하지 않는다.
- [ ] **채택 후 앱 전환:** [기억·이관](README.md#memory), [저장·서버](README.md#storage), [추천](README.md#recommendation), [화면](README.md#screens), [계측](README.md#metrics)을 구현·검증한다.
- [ ] **출시 검증:** [출시 기준](README.md#release)에 실제 빌드·기기·운영 증거를 남긴다.

제휴·공유·제출 준비는 [출시 문서](README.md#release)에 따라 병행한다. 각 완료 항목에는 날짜·산출물 경로·실제 검사 결과를 남기고 실행하지 않은 검사는 체크하지 않는다.

## 이번 문서 개편 검증

2026-10-07 실행:

- 로컬 문서 링크·앵커 검사 통과. 과거 25개 문서의 본문은 링크 대상 변경을 제외하고 보존됨을 비교했다.
- `python3 scripts/check_destination_candidates.py` 통과: 기존 후보 문서와 JSON 정합성 유지.
- `git diff --check` 통과.
- `xcodebuild -quiet -project TripDNA.xcodeproj -scheme TripDNA -destination 'generic/platform=iOS Simulator' build` 종료 코드 0. 최초 sandbox 실행은 DerivedData·Simulator 접근 제한으로 실패했고, 권한을 확보한 재실행은 통과했다.
- `graphify update .` 종료 코드 0. AST 코드 그래프만 갱신하며 새 문서의 의미 추출은 수행하지 않았다. 기존 Swift 두 파일(AppDependencies.swift, LedgerServices.swift)에 추출기 구문 경고가 있었으나 Xcode 빌드는 통과했다.
- 앱 코드·실험 입력/응답은 변경하지 않았다. 문서 변경이므로 단위/UI 테스트와 유료 API 실험은 실행하지 않았다.

## 주제당 문서 하나로 정리 — 2026-10-07

- 위 “문서 체계 v2”와 “압축본 적용 범위 정정”은 이 정리로 대체했다. 그 시점의 문서는 git 태그 `docs-versioned-2026-10-07`에 있다.
- 추천·출처·평가 문서와 실행 5·6 계획을 주제 폴더로 옮겼다. 기억 문서는 옛 설계 3·6절, 직접 증거, 경험 어휘 원문을 한 파일로 이어 붙였다. 제휴·출시 문서는 옛 제품 문서의 해당 절을 옮겼다.
- 채택 철회 초안 7개 중 제휴 초안은 원문과 줄 단위로 같아 그대로 썼고 나머지 6개는 삭제했다. 초안에만 있던 문장은 옮기지 않았다.
- 화면·저장·계측 문서의 본문은 머리말과 링크, 저장 문서의 2026-10-07 결정 반영만 고쳤다. 새 설계에 맞춘 최신화는 하지 않았다.
- 검사: 로컬 링크 검사, `python3 scripts/check_destination_candidates.py`, `git diff --check`. 앱 코드는 바꾸지 않아 빌드와 테스트는 실행하지 않았다.

## 초기 합의 복원 검증 — 2026-10-07

- 수정 문서의 로컬 링크·앵커 112개와 `git diff --check` 통과.
- `python3 scripts/check_destination_candidates.py` 통과. 후보 JSON·선정 기록은 변경하지 않았다.
- 프로젝트 지침의 `xcodebuild -quiet -project TripDNA.xcodeproj -scheme TripDNA -destination 'generic/platform=iOS Simulator' build`는 최초 sandbox 실행에서 DerivedData·Simulator 접근 제한으로 실패(65), 권한을 확보한 재실행에서 통과(0)했다.
- 작업 시작 시점 파일 해시와 비교해 이번 변경이 Markdown 10개에 한정됨을 확인했다. 앱 코드·스크립트·JSON·고정 실험 기록은 보존했다.
- 문서만 변경했으므로 단위/UI 테스트·유료 API 호출·코드 변경 후 그래프 갱신은 실행하지 않았다. 새 지문 계산과 새 추천의 앱 구현·품질 검증은 미완료다. 커밋하지 않았다.
