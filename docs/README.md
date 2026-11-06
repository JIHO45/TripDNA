# TripDNA 문서 목차

2026-10-17 추가: release에 개인정보 초안 링크를 넣었다.
2026-10-17 변경: 구독 가격·한도가 정해져 남은 목록의 해당 항목을 고쳤다.
2026-10-08 정합성 보완: 현재 정책의 연결과 남은 결정 목록을 갱신했다. 고정 실험·검수 기록은 보존한다.
2026-10-07 변경: 초기 합의를 복원한 담당 문서의 위치를 명시했다. 남은 화면·저장·계측 최신화는 유지한다.

이 문서는 **문서 위치와 담당 주제**만 관리한다. 제품 목표·범위는 [루트 README](../README.md), 진행 상태는 [TODO](TODO.md)가 담당한다. 아래 문서는 설계와 실험 계획이며 구현 완료를 뜻하지 않는다.

## 주제별 문서

다른 주제를 참조할 때는 아래 고정 경로로 연결한다.

### recommendation

[추천 구조](recommendation/README.md): 여행권·접근 조건·매칭과 LLM 처리 책임.

### llm

[LLM 적용 방식](llm/README.md): 일반적인 적용 방법 정리와 적용 계획 초안. 결정은 추천 구조를 따른다.

### memory

[사용자 기억·조건·제외와 이관](recommendation/memory.md): 독립 경험 상태·근거·학습 경계.

### sources

[사실 근거와 출처](recommendation/sources.md)

### candidates

후보의 원문은 [destination-candidates.json](../data/planning/destination-candidates.json)이다. 새 도시 등급 자료의 계약과 검수 순서는 [도시 자료 제작 형식](data/destination-format.md), 판정 기준과 도시 추가 순서는 [등급 판정 절차](data/destination-grading.md), 초안은 [103곳 자료](../data/destinations/catalog.json)에 있다. 2026-10-17에 제작을 재개했으며 출시 검수·앱 적용은 별개다. [후보 선정 기록](data/destination-selection.md)과 [예전 상세 자료 형식](data/city-format.md)은 당시 기록으로 보존한다.

### storage

[저장·전송](data/storage-and-privacy.md)

### evaluation

[평가 계획과 도입 기준](evaluation/README.md)

[R1 필수 시나리오 정리](evaluation/r1-checklist.md): 출시 검사 R1의 시나리오별 자동·시뮬레이터·실기기 근거

### metrics

[계측](evaluation/metrics.md)

### screens

[화면별 문서 목록](screens/README.md)

### affiliates

[제휴 정책](affiliates.md)

### release

[출시 차단 요건과 출시 검사](release.md)

[개인정보 초안](privacy-draft.md): 프라이버시 선언·처리방침 골격·권한 문구 점검. 사용자 결정 전.

## 아직 최신화하지 못한 부분

2026-10-08의 흐름에 맞춰 화면·저장·계측·평가·출시 문서를 대조했다. 아래는 이전 정책을 대신 적용하라는 뜻이 아니라 아직 결정·검증이 필요한 부분이다.

- 빈 추천 결과·재호출 횟수·코드 순위 계산·입력 후보 범위·평가 입력 상한·도시 자료 제작: [추천 구조의 미정 목록](recommendation/README.md#미정).
- 메모 전송과 도시 요청 집계의 동의·보관·삭제 계약: [저장·전송](data/storage-and-privacy.md).
- 구독 가격과 무료·구독 한도는 2026-10-17에 정했다([추천 구조](recommendation/README.md#2026-10-07-추가-결정-구독-자료-배포-저장)). 구독 화면의 구체적 문구·동작과 Apple 가격 단계의 확인은 남아 있다. 현재 화면은 무료 무제한 호출을 약속하지 않는다.
- 기존 상세 도시 파일 형식과 고정 실험 계획은 당시 기록이다. [새 등급·핵심 경험 자료](data/destination-format.md)는 제작 초안이며 출시 검수·앱 적용은 남아 있다.

## 문서를 쓰는 규칙

- 한 주제에 문서 하나다. 설계가 바뀌면 그 문서를 직접 고친다. 버전 폴더나 이전 본문의 사본을 만들지 않는다. 이전 내용은 git 이력에서 본다.
- 각 정책·필드·평가 규칙·화면 동작은 담당 문서 한 곳에만 쓴다. 다른 문서에는 설명을 복제하지 않고 상대 경로 링크를 둔다. 링크의 역할 설명은 허용하되 수치·예외·규칙을 다시 쓰지 않는다.
- 고칠 때 변경 날짜와 이유를 그 문서에 한 줄 남긴다. 결정이 뒤집힌 경우 이전 결정이 무엇이었는지도 적는다.
- TODO에는 작업 상태·산출물·실제 검증 기록만 둔다.
- 코드나 JSON이 원문인 목록·ID·필드는 문서에 전수 복사하지 않는다. 문서는 의미와 사용 범위만 설명한다.
- `graphify-out/`은 생성된 탐색 자료이며 정책 원문이 아니다. 에이전트 작업 규칙은 루트 `AGENTS.md`와 `CLAUDE.md`를 따른다.

## 고치지 않는 기록

실험 계획·결과와 날짜가 붙은 검수 기록은 최신화 대상이 아니다. 호출이 시작된 입력·사전 기준·원본 응답은 수정하지 않는다. 새 실험은 새 계획·실행 디렉터리로, 집계·정정은 별도 결과 문서로 남기고 계획과 연결한다. 미완료 검수를 완료로 표시하지 않는다. 오탈자와 끊어진 링크만 고친다.

- 실험 계획과 결과: [비교 실험 설계](evaluation/offline-evaluation.md), [목록 대 프로필(실행 1~2)](evaluation/profile-exploration.md), [지침 비교(실행 3~4)](evaluation/guideline-comparison.md), [실행 5 계획](evaluation/run5-plan.md), [실행 6 계획](evaluation/run6-plan.md).
- 자료 기록: [후보 선정 기록](data/destination-selection.md), [자료 형식](data/city-format.md), [3곳 검수 준비 2026-10-06](data/city-review-2026-10-06.md).
- 입력·실행 파일: [실험 파일 목차](../data/exploration/README.md).

2026-10-07까지 문서를 `v1/`·`v2/` 폴더로 나눠 관리했다. 그 시점의 전체 문서는 git 태그 `docs-versioned-2026-10-07`에 있다. 기록 안에 적힌 `docs/v1/…`, `docs/v2/…`, `docs/recommendation/architecture.md` 같은 옛 경로는 그 태그에서 연다. 기록 본문의 “설계 v2”, 도시 스키마 v3, 실험 계획 v5는 각 기록의 자체 번호다.
