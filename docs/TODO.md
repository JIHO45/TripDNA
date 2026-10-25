# 실행 상태

기준일: 2026-10-08. 이 문서는 **상태·다음 행동·산출물·실제 검증**만 기록한다. 기준은 [현재 문서 목차](README.md), 과거 작업 번호·완료 근거는 git 태그 `docs-versioned-2026-10-07`의 `docs/v1/progress.md`에 있다. 정책·실험 결과를 여기에 다시 쓰지 않는다.

## 도시 자료 103곳 확장 — 2026-10-17

- [x] **초안 작성:** [도시 자료](../data/destinations/catalog.json), [형식·검수 순서](data/destination-format.md). 기존 20곳 재판정과 추가 83곳을 합쳐 103곳, 세부 2,987칸, 핵심 경험 789항목. 기존 등급 24칸 변경 기록을 남겼다. 신규 83곳의 과소평가를 19곳 43칸 보정하고 core 메모 15문장을 정리했다(`revisions`). 추가 비교 실험과 LLM API 호출은 하지 않았다.
- [x] **자료 검사:** `check_destination_draft.py`, `test_destination_draft.py`의 테스트 4개(잘못된 자료 15종 포함), 기존 `check_destination_candidates.py`, `check_city_draft.py` 통과. 출시 검사 `--release`는 예상대로 거부한다.
- [ ] **출시용 검수:** 0곳 완료. 시즌 255칸 미확인. 신규 도시의 none ↔ if_there 경계는 기존 20곳보다 보수적이며 미보정이다. 후보 진입·순위 경계, 범위, 시즌부터 검수한다. 기후·비행시간·비용은 이번 확장에 포함하지 않는다. 앱 연결도 하지 않았다.
- [ ] **MVP 잠정 고정(2026-10-25):** 기준표·catalog 등급은 MVP용 잠정 버전이다. “승인”은 검증 완료가 아니다. 사용해 본 뒤 [사용 기록](evaluation/mvp-tester-log.md)에서 반복해서 나오는 문제만 수정한다.
- [ ] **등급 기준 정비:** 2026-10-24 [검수표](data/grade-anchors.md)에 단일 경험도 choose 가능하다는 규칙을 반영했다. 시드니 건축 choose 제안, 바르셀로나 스포츠는 윔블던과 상위 경계 사람 판정 대기. 하위 경계 4쌍+상위 후보 1쌍, 사람 승인 없음. 로마 테니스·럭비와 유적 야외 공연의 공식 근거를 확인했으며 2025 카라칼라/2026 치르코 마시모를 구분했다. 테스트 15개·자료 형식·재렌더 동일성·catalog 불변·공백 검사·Xcode 빌드 통과, graphify 갱신(기존 Swift 2곳 부분 추출 경고). XCTest 미실행. 퀸스타운 보류 2칸과 나머지 세부 정비·103곳 재판정·분포 경고는 남아 있다. 2026-10-24 사람 승인(Joe): 건축·박물관·스포츠의 make_time↔if_there 경계 3쌍과 해당 칸 17개 승인(퀸스타운 건축 보류 제외). 바르셀로나 스포츠는 choose로 판정해 윔블던과 같은 등급이 되어 스포츠 choose↔make_time 경계는 다시 미확보다. 같은 날 로마 여름 야외 오페라의 반복 기록(1937년 시작, 공백 뒤 재개, 2020–21·2026년은 치르코 마시모)을 공식 페이지로 확인하고 공연 경계(로마↔밴쿠버)와 해당 칸 5개도 승인했다. 4개 세부 경계 4쌍 승인 완료, 남은 것은 퀸스타운 보류 2칸과 스포츠 choose↔make_time 경계다. 2026-10-24 나머지 24개 세부 초안(모델): 기준점·후보 144칸·경계 45쌍(make_time↔if_there 24, choose↔make_time 21; streets·cafe 상위 경계는 두지 않았고 travelers는 choose 기준점이 없다). `locals`는 사용자 결정으로 상위 등급 없이 if_there까지만 둔다. 검사기는 이전 비교 쌍이 없는 세부도 경계 검수 행으로 다루도록 바꿨다. 사람 승인 대기. 2026-10-25: 모델 논리 점검(45쌍)과 사실 확인 9건을 받아, "곁들이는 경험인지는 구체적 내용으로 설명하면 근거로 쓸 수 있다" 규칙을 넣고(사용자 결정) 분류 3건을 확정했다. 45쌍 이유를 다시 썼고, 사실에 따라 경계 상대 5곳(해변·익스트림·테마파크·라이브 바·축제)을 바꿨다. 런던 테마파크는 보류. 2026-10-25 Joe가 나머지 24개 세부를 일괄 승인했다(경계 49쌍 모두 승인, 보류 3칸 제외: 퀸스타운 건축·공연, 런던 테마파크). 승인된 판정 중 catalog와 다른 19칸을 catalog에 반영하고 변경 기록을 남겼다(core 3개 추가, 792항목). 기준표 밖의 칸(약 2,800칸)은 같은 기준으로 다시 보지 않았다. 같은 날 MVP에서 핵심 경험 문장을 LLM에 넣지 않기로 결정했다(추천 구조 문서). 이어서 묶음별 분포 보고 스크립트(`report_grade_distribution.py`)를 만들고 신규 83곳을 세부별로 한 번 훑어 31칸을 올렸다(core 820항목). 도시형 세부의 묶음 차이는 남아 있으며 MVP 사용 기록으로 넘긴다. [사용 기록 양식](evaluation/mvp-tester-log.md)을 만들었다. catalog는 아직 바꾸지 않았다(103곳 재판정 단계에서 반영). 2026-10-25: 초안 경계 45쌍의 논리를 점검하고 재비교 쟁점을 기록했다. 9쌍에 사실 출처를 붙였으며 분류 3건은 사람 결정 대기다. 분류 미결정 경계의 승인을 검사기로 차단한다. 제안 등급·기존 승인·catalog는 유지했다. Python 테스트 16개와 재렌더 동일성 통과. 등급 강도 비교와 나머지 출처 확인은 미완료다.
- [x] **Xcode 빌드:** 지정된 iOS Simulator 빌드가 최종 종료 코드 0으로 통과했다. 첫 시도는 샌드박스 접근 제한, 다음 시도는 자동 승인 검토의 사용량 한도 오류로 막혔으나 계속 진행 요청 후 권한 확대 재시도에 성공했다. Swift 앱 코드를 바꾸지 않아 앱 단위·UI 테스트는 실행하지 않았다.
- [x] **최종 확인:** 문서 로컬 링크 경로 119개와 `git diff --check` 통과. `graphify update .` 실행 완료(3,189 nodes, 6,769 edges). 기존 `AppDependencies.swift`, `LedgerServices.swift`의 부분 추출 경고와 커뮤니티 이름 갱신 안내가 남았다. 문서 의미 추출·LLM 재명명은 실행하지 않았다.

## 현재 구현과 보존 자료

현행 앱의 연결은 [AppDependencies](../TripDNA/App/AppDependencies.swift)의 국가 자료·RecommendationService와 [SwiftDataStore](../TripDNA/Infrastructure/SwiftDataStore.swift)에 있다. 이번 작업은 문서 변경이며 도시·LLM·검색 앱 구현을 추가하지 않았다.
B1·D1·D2의 이전 완료 기록은 같은 파일에 있다. 해당 검증을 이번 작업에서 다시 실행한 것으로 해석하지 않는다.
기존 도시 자료와 실험 입력·원본 응답·검수표는 [자료 목차](../data/exploration/README.md) 및 [후보 계약](README.md#candidates)에서 찾는다.

## 다음 작업

- [x] **초기 취향·지문 합의 문서 복원:** 2026-10-07, [제품 원칙](../README.md#취향과-추천의-핵심-원칙), [기억](recommendation/memory.md), [추천 구조](recommendation/README.md), [지문 화면](screens/home-and-fingerprint.md#취향-지문)에 반영하고 관련 화면·목차의 표현을 맞췄다. 이후 목록·실험 우선·구독 결정은 유지했다. 앱 구현 완료를 뜻하지 않는다.
- [ ] **컨셉 지문 표시 구현:** [지문 화면](screens/home-and-fingerprint.md#취향-지문)에 따라 여행별 컨셉 기록과 집계, 표시를 구현한다. 2026-10-07의 5축 요약 계획은 2026-10-08에 철회했다. 2026-10-17 부분 구현: 등록·수정 화면의 컨셉 선택(큰 컨셉 10개, ID는 `data/experience-categories.json` v1 9개 + `event`), 도시별 별점·좋았던 점·아쉬웠던 점 메모(태그 선택 UI 제거, 기존 태그 기록 보존), 지문 화면 상단의 주 컨셉 횟수 집계와 빈 상태. 산출물: `TripDNA/Domain/DomainModels.swift`(`TripConcept`, `TripConcepts`, `CityReview`, `ConceptFingerprint`), `TripDNATests/ConceptAndCityReviewTests.swift`. 저장은 기존 JSON payload에 선택 필드로 더해 SwiftData 스키마를 바꾸지 않았다(이관 단계 없음, 이전 payload 해독 테스트). 검사: 시뮬레이터 빌드, `TripDNATests` 53개 통과(iPhone 17), `graphify update .`. 실제 앱 화면 조작은 확인하지 않았다. 남은 것: 홈의 지문 진입이 5축 벡터가 있을 때만 보이고, 지문 화면 아래·공유 카드에 5축 표시가 남아 있다(제거 여부 결정 필요). 평가의 여행 전체 만족도·재방문 단계는 도시 별점을 여행 랭킹으로 환산하는 규칙이 없어 유지했다. 평가 화면의 컨셉 수정, 온보딩 과거 여행의 컨셉 입력은 없다.
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
- [ ] **구독·저장 결정의 후속:** 결정 내용은 [추천 구조](recommendation/README.md#2026-10-07-추가-결정-구독-자료-배포-저장)에 있다. 2026-10-17에 가격·한도를 문서화했다(README.md, 목차, 추천 구조). 남은 것: Apple 가격 단계 확인, 무료 한도를 세는 단위와 남용 방지, 사용량 서버 저장의 계약, 저장·출시·LLM 문서의 반영, 구독 화면과 서버 구현. 구현은 시작하지 않았다.
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
