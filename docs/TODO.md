# 실행 상태

기준일: 2026-10-07. 이 문서는 **상태·다음 행동·산출물·실제 검증**만 기록한다. 기준은 [현재 문서 목차](README.md), 과거 작업 번호·완료 근거는 [v1 진행 기록](v1/progress.md)을 따른다. 정책·실험 결과를 여기에 다시 쓰지 않는다.

## 현재 구현과 보존 자료

현행 앱의 연결은 [AppDependencies](../TripDNA/App/AppDependencies.swift)의 국가 자료·RecommendationService와 [SwiftDataStore](../TripDNA/Infrastructure/SwiftDataStore.swift)에 있다. 이번 작업은 문서 변경이며 도시·LLM·검색 앱 구현을 추가하지 않았다.
B1·D1·D2의 이전 완료 기록은 [v1 진행 기록](v1/progress.md)에 보존한다. 해당 검증을 이번 작업에서 다시 실행한 것으로 해석하지 않는다.
기존 도시 자료와 실험 입력·원본 응답·검수표는 [자료 목차](../data/exploration/README.md) 및 [후보 계약](README.md#candidates)에서 찾는다.

## 다음 작업

- [x] **문서 체계 v2 작성:** 주제별 원문·링크와 버전 기록 분리. 2026-10-07, [산출물](v2/README.md).
- [ ] **실행 4 검수 마무리:** [원본·검수표](../data/exploration/runs4/)를 대조해 불일치와 사실 확인 상태를 별도 결과 문서로 집계한다. 파일 존재만으로 검수 완료로 처리하지 않는다.
- [ ] **다음 실험 고정본 작성:** [평가 계획](README.md#evaluation)의 모델·도구·새 사례·한도·판정 기준을 확정한다. 현재는 실행 가능한 최종 설정이 모두 고정된 상태가 아니다.
- [ ] **실행 도구 준비·검사:** 기존 도구의 재사용 범위를 확인하고 필요한 검색·기록·출력 검사만 추가한다. 외부 호출 없는 검사 후 실행한다.
- [ ] **비교 실행과 결과 기록:** 같은 실행의 기준선과 비교하고 원본·검수·비용·지연·한계를 별도 결과 문서에 남긴다.
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

## 압축본 적용 범위 정정 — 2026-10-07

- 화면·기억·저장·계측의 기존 원문을 현재 기준으로 복원했다. 후보·제휴·출시도 기존 원문의 지정 범위를 사용한다. [적용 목차](README.md#적용-범위).
- 추천·출처·평가만 v2를 적용한다. 나머지 압축본은 채택 철회 초안으로 보존하며 항목별 대조를 완료한 것으로 보고하지 않는다.
- 이번 후속 수정은 문서만 변경했다. 이전 빌드 통과는 위 작업의 기록이며 이번에 재실행한 결과가 아니다.
- 후속 검사: 로컬 링크·앵커 363개 오류 0건, 복원한 14개 원문의 본문 비교 통과(안내문·링크 대상 제외), `git diff --check` 통과. 단위/UI 테스트는 실행하지 않았다.
