# R1 필수 시나리오 정리

2026-11-07 작성. 원문 시나리오는 [구현 회귀 시나리오](README.md#구현-회귀-시나리오)이고, 이 문서는 시나리오마다 확인 근거를 붙인다. 출시 검사 정의는 [출시 문서](../release.md#출시-검사와-병행-업무) R1이다.

상태: **R1 진행 중이며 통과 기록이 아니다.** 시뮬레이터 확인은 2026-11-07에 12·17·22번을 마쳤다. 2026-11-07 사용자 결정으로 출시 전 실기기 확인은 아래 [출시 전 필수 실기기 확인](#출시-전-필수-실기기-확인) 6가지로 줄였다. 표의 나머지 실기기 칸은 출시 후 업데이트에서 확인한다(통과가 아니다).

## 기준

- **자동:** `TripDNATests`(단위)·`TripDNAUITests`(UI)의 테스트 이름. 2026-11-06~07 코드 기준으로 통과했다(단위 253개, UI 19개는 세 번에 나눠 통과). 최종 코드에서 R2로 다시 실행한다.
- **시뮬레이터:** Xcode DEBUG 빌드. LLM이 필요 없는 화면·저장 동작만 본다. 시뮬레이터의 AI 호출은 App Check 디버그 토큰 등록과 무료 한도에 묶여 있어 LLM 출력이 필요한 항목은 실기기로 보낸다.
- **실기기:** 최종 TestFlight 빌드에서 사람이 확인한다. UI 테스트를 TestFlight 빌드에 돌리는 것이 아니다.
- **미확인:** 자동 근거가 없고 아직 실행 계획도 없는 부분.

현행 앱 전제: 도시 추천의 입력은 이번 여행 컨셉·조건, 원하는 여행 티어, 피하고 싶은 것 메모(기억), 다녀온 도시·제외 목록이다. 사진·별점·평가 메모에서 취향을 자동으로 만들지 않는다. 평가 메모는 AI 대화에서 동의했을 때만 맥락으로 보낸다. 옛 취향 축 모델과 사진 퀴즈 화면은 2026-10-24 온보딩 재구성으로 화면에서 빠졌고, 그 모델의 단위 테스트는 남아 있다.

## 시나리오별 근거

| # | 시나리오 | 자동 근거 | 시뮬레이터 | 실기기 | 미확인 |
|---|---|---|---|---|---|
| 1 | 즉흥 선호자 사진 등록 → 계획 선호 생성 | `TasteEvidenceTests/visitsComparisonsAndSavesDoNotInventTasteOrConfidence`(옛 축 모델) | — | 사진첩으로 여행 등록 후 원하는 여행·기억에 새 항목이 생기지 않는지 | 현행 도시 추천은 사진에서 선호를 만들지 않음(코드 전제). 화면 확인은 실기기 |
| 2 | 이유 없는 도쿄 긍정 → 미식·사교 선호 생성 | `TripDNATests/satisfactionWithoutReasonDoesNotInferAxes`, `explicitPositiveTagOnlyUpdatesItsAxis`(옛 축 모델) | — | 메모 없이 별점 5 → 기억·원하는 여행에 변화 없는지 | 없음(실기기 확인 후) |
| 3 | 혼자 새 사람 만나기 / 친구와 시간 → 서로 다른 요구 구분 | 부분: `acceptsOnlyConditionsGroundedInUserText`(입력에 근거한 조건만 받음) | — | 자유문장에 "혼자 가서 새 사람 만나고 싶어요"와 "친구들과 시간 보내고 싶어요"를 각각 넣어, 뒤쪽이 교류(`meeting_people`) 조건으로 바뀌지 않는지 | 설계상 구분은 이미 있다: `meeting_people`은 새로운 사람과의 만남이고 동행 여부가 아니다([기억](../recommendation/memory.md)). 새 입력칸은 만들지 않는다 |
| 4 | 도시·자연 모두 좋아함 / 둘 다 모름 → 같은 입력으로 압축 | `CityLLMRequestTests/bothWantedAndBothUnplacedStayDistinct`(2026-11-07 추가: 저장값과 추천 요청 문장이 다르다), `wantedTiersSurviveStoreReopen`, `ordersByPrimaryThenSecondarySumThenTier` | 생략(단위 테스트로 대신) | — | 없음. 티어 설계(넷째 칸)는 바꾸지 않는다 |
| 5 | 도쿄 계속 제외 후 재시작·재추천 → 도쿄 노출·오사카 연쇄 제외 | `excludedCityIsRemovedFromRankingPoolAndRecut`, `rankerSkipsExcludedCities`, `savedAndExcludedCitiesSurviveReopeningTheStore`, `refillTakesNextPoolCityAndNeverReshowsOrExcluded`, `restoredResultHidesCitiesAndCountriesExcludedLater` | — | 도쿄 카드 메뉴 "다시 추천하지 않기" → 앱 종료·재실행 → 새 추천에 도쿄가 없는지, 도쿄 제외 때문에 오사카까지 빠지지 않는지(오사카가 반드시 추천돼야 하는 것은 아님) | 도쿄 제외가 오사카를 빼지 않는지는 자동 근거가 직접 없다(도시 ID 단위 제외라 코드상 빠지지 않음) |
| 6 | 이번 여행 제외 후 재시작·새 여행 → 범위별 지속성 | `CityStateTests/skipsSurviveRestartAndRefillsMatch`, `newResultClearsSkipsButBudgetRecutKeepsThem`, `skippedIDsRoundTripAndOldDataDecodesEmpty` | — | 카드 메뉴 "이번 결과에서 넘기기" → 재실행 후 유지 → 새 여행 추천에서 풀리는지 | 없음(실기기 확인 후) |
| 7 | 예산 불만 → 자동 제외·기억 저장·임의 예산 숫자 | 부분: `TasteEvidenceTests/everyCountryRejectionLeavesTasteUnchanged` | — | 평가 메모에 "비쌌다" → 기억·제외·예산 칸에 자동 변화 없는지, 다음 추천 예산이 비어 있는지 | AI 대화가 메모를 보고 예산 숫자를 지어내는지는 대화 사례 검사 범위 |
| 8 | 질문·열람·북마크 → 평소 취향 자동 생성 | `TasteEvidenceTests/visitsComparisonsAndSavesDoNotInventTasteOrConfidence`, `CityQuestionLogTests/questionsSurviveReopenAndStayPerCity` | 실행 안 함(자동 근거와 실기기로 확인) | 같은 확인을 실제 추천 카드로 | 없음 |
| 9 | 요청 중 조건 변경 → 늦은 응답이 현재 결과 덮어씀 | 부분: `DeleteAllDuringRequestTests/recommendationArrivingAfterDeleteAllIsNotSavedOrLogged`, `staleGenerationCannotWriteToEitherStore`(전체 삭제만). 새 요청은 이전 작업을 취소한다(`CityRecommendationSection.begin`) | — | 추천 로딩 중 취소 → 조건 바꿔 다시 요청 → 앞 요청 결과가 뒤늦게 나타나지 않는지 | 조건 변경 경로 전용 자동 테스트 없음 |
| 10 | 근거 없는 명소·가격·운영·URL을 사실처럼 표시 | `CityQuestionTests/dropsURLNotInSearchResults`, `searchErrorKeepsAnswerAndFlagsUnconfirmed`, 비용은 "실시간 가격이 아닌 대략적인 추정" 표시 | — | 도시 질문 2~3개로 출처 없는 URL·가격이 확정처럼 보이지 않는지 | 문장 안의 사실 정확도는 LLM 평가(대화 사례 H01~H13) 범위 |
| 11 | 후보 부족·비용 한도 → 제외 해제·LLM이 고르지 않은 카드 | `fewWithinBudgetFillWithOverBudgetCitiesInRankOrder`, `allOverBudgetStillShowsCardsAndIsLogged`, `rejectsWrongOrMissingIDs`, `dropsCitiesOutsideCandidatesWhenCandidateOrderHolds`, `citiesOutsideCandidatesAreDroppedInResultRefillAndRecut`, `quotaExceededIsReportedFromEitherStep` | — | 무료 한도 소진 시 안내만 나오고 카드가 생기지 않는지 | 없음 |
| 12 | 기억 삭제·되돌리기 → 다음 입력·공유·과거 요약에서 복원 | 부분: `memoryIDNotInInputIsRejected`, `noMemoriesMeansNoMemorySectionInRequest`, `deletionClearsEveryLocalDataModel` | 2026-11-07 통과: 데모에서 기억 삭제 → 원하는 여행의 "피하고 싶은 것" 칸도 비워짐(같은 값) | 기억 삭제 → 재실행 → 새 추천 "반영한 기억"에 안 나오는지 | 공유 카드·과거 결과 요약에서의 복원은 자동 근거 없음 |
| 13 | 나라만 확인된 방문 → 소속 도시 전부 방문 처리 | `ConceptAndCityReviewTests/reviewTargetsKeepCountryOnlyLegsAndDeduplicate`, `CityRecommendationTests/visitedCitiesMatchByNameAndCountryOnly` | — | — | 없음 |
| 14 | 핵심 조건 근거 없음 → 충족 배지 | `badgeFollowsRequiredConditionTable`, `requiredNotMetDropsRequiredUnconfirmedGoesLastCoreOrders`, `unverifiedSeasonNeedsCheckAndNeverOutranksConfirmed` | 2026-11-06 데모 화면: 확인 못 한 도시는 "추가 확인 필요 1곳"으로 따로 표시됨 | — | 없음 |
| 15 | 조언으로 포장한 사실·무관한 출처 연결 | 부분: `dropsURLNotInSearchResults`(목록 밖 URL만) | — | — | **미확인.** 의미 불일치는 코드로 거르지 않는다. LLM 평가 사례로 다룬다 |
| 16 | 범위 밖/미확인 장소·배편·숙박 → 범위 안·당일 가능으로 둔갑 | 부분: `CityScopeSeasonTests/confirmedSceneryStillDisclosesUnavailableActivities`, `bundledScopesArePresent` | — | — | **미확인.** 대화·질문 답의 이동 판단은 LLM 평가 범위 |
| 17 | 주 컨셉 미선택 / 티어만 완료 → 자동 호출·카드 생성 | `RecommendationRequestTests/mainConceptIsRequired`, `secondaryRules`, UI `TasteStartFlowTests`(티어만 넣고 추천 탭 도착) | 2026-11-07 통과: 티어만 넣고 온보딩을 마치면 추천 탭이 "아직 받은 추천이 없어요"에 머문다. 주 컨셉 없이 "추천 받기"를 누르면 호출 없이 컨셉 칸만 빨갛게 표시된다 | — | 없음 |
| 18 | 메모 없는 별점 / 날씨 불만 / 다른 과거 메모 → 근거 없는 취향·반영 표시 | `satisfactionWithoutReasonDoesNotInferAxes`(옛 모델), `memoryIDNotInInputIsRejected`(입력에 없는 기억을 반영했다고 못 함) | — | 별점만 남긴 여행 뒤 추천의 "반영한 기억"에 엉뚱한 항목이 없는지 | 없음 |
| 19 | 일본 계속 제외 후 이번 일본 요청 → 이번만 포함·새 여행에 승계 안 됨 | 부분: `excludedCountriesAreRemoved`, `oldPolicyWithExperienceConditionKeepsResultButExplainsBlockedActions`, `Round5Tests/noticeUsesHomeCountryStoredInRecord` | — | 일본 제외 → "일본" 요청 → 결과·안내 확인 → 새 여행에서 다시 제외되는지 | 제외 나라를 이번 요청에만 포함하는 경로의 직접 테스트 없음 |
| 20 | 목록 밖 도시 확정·검토 요청 → 동의 없는 이동·가짜 ID·횟수 차감 | 부분: `rejectsWrongOrMissingIDs`, `dropsCitiesOutsideCandidatesWhenCandidateOrderHolds`, `citiesOutsideCandidatesAreDroppedInResultRefillAndRecut`(후보 밖 도시 카드는 버림) | — | 자유문장에 목록에 없는 도시를 넣어 가짜 추천 카드나 도시가 생기지 않는지 | **출시 제외(2026-11-07 결정).** 전용 등록 연결·검토 요청 기능은 설계에만 있고 구현되지 않았다. 통과가 아니라 이번 출시 범위에서 뺀 것으로 기록한다 |
| 21 | 도시별 평가 수정·삭제 → 메모 이동·삭제 전 내용 복원 | `ConceptAndCityReviewTests/revisingEvaluationKeepsOldTagsAndSavesCityMemos`, `RecordLifecycleTests/deletingEvaluationKeepsTripAndReopensEvaluation`, `ChatTests/contextLeavesOutTripsAndRatingsWhenNotAllowed` | — | 메모 수정 → 재실행 → AI 대화 맥락에 새 메모만 가는지(평가 전송 동의 시) | 서버 캐시는 없다(처리방침: 요청 내용 미저장) |
| 22 | 예산 수정·후보 교체 → 새 호출 없이 처리·조건 의존 설명 재사용 | `recutChangesBudgetWithoutCallingLLM`, `recutDropsStaleUnderstandingAndMarksDerived`, `refillTakesNextPoolCityAndNeverReshowsOrExcluded` | 2026-11-07 통과: 데모 결과에서 예산 150만→50만 원, 로딩 없이 재정렬·"처음 입력한 예산 기준" 안내·되돌리기·이해 문장 제거. 오사카가 "추가 확인 필요"로 바뀐 것은 데모 카드의 조건 표시가 순위 계산과 달라서다(`UIDemoSeed.resultRecord`) | 실제 결과에서 같은 확인 | 없음 |

## 저장·재시작·네트워크 실패

출시 문서 R1은 저장·재시작·네트워크 실패를 포함하라고 한다.

| 항목 | 자동 근거 | 실기기 |
|---|---|---|
| 재시작 후 데이터 유지 | `tripEvaluationAndFingerprintSurviveRestart`, `wantedTiersSurviveStoreReopen`, `savedAndExcludedCitiesSurviveReopeningTheStore`, `conversationsSurviveReopenAndDeleteAll`, `v1StoreOpensAsV2` | 여행·평가·저장 도시·대화를 만든 뒤 앱 강제 종료·재실행 |
| 전체 삭제 | `deletionClearsEveryLocalDataModel`, `deleteAllUserDataRemovesSavedCitiesExclusionsAndLastResult`, `ICloudBackupTests/failedRemoteDeletionIsReported` | 모든 데이터 지우기 → 재실행 시 온보딩 → Firestore에서 익명 사용량 문서 삭제 |
| 네트워크 실패 | `failedResponseIsStillLoggedWithError`, `failedRecommendationReusesItsIDOnce`, `ChatTests/failedSummaryLeavesConversationUntouched` | 비행기 모드에서 추천·대화·질문 → 연결 확인 안내와 다시 시도, 기존 결과 유지 |
| iCloud 백업·복구 | `ICloudBackupTests` 9개 | 2026-11-03 TestFlight 재설치 복구 확인됨([TODO](../TODO.md)). 최종 빌드에서 한 번 더 |
| 구독 만료 | `SubscriptionTests/activeAfterPurchase`(구매 후 활성만) | 해지한 샌드박스 구독의 자격이 실제로 끝난 뒤(자동 갱신 꺼짐, 현재 자격 없음) 설정 표시·요금제 화면·무료 사용량 문서로 돌아오는지 |

## 결정

- 3번·4번은 새 설계 결정이 필요 없다(2026-11-07 사용자 확인). 3번은 자유문장 처리, 4번은 저장·요청 입력의 구분을 확인한다.
- 20번은 이번 출시에서 뺀다(2026-11-07 사용자 결정). 목록 밖 도시를 입력해도 가짜 카드·도시가 생기지 않는지만 확인한다.
- 출시 전 실기기 확인을 API 비용·앱 장애·심사 거절 위험이 있는 6가지로 줄인다(2026-11-07 사용자 결정). 목적은 다운로드 반응을 먼저 보는 것이다. 나머지 실기기 확인은 출시 후 업데이트에서 하며 통과로 표시하지 않는다.

## 출시 전 필수 실기기 확인

최종 TestFlight 빌드에서 한다. 결과 칸에 날짜와 결과를 적는다.

| # | 확인 | 위험 | 결과 |
|---|---|---|---|
| 1 | 무료 계정으로 추천 3회 뒤 4번째, AI 대화 여러 번 → 안내·구독 화면만 나오고 더 호출되지 않는지 | API 비용 | 미실행 |
| 2 | 구독 자격이 실제로 끝난 뒤 설정 "구독 안 함", 새 사용량이 익명 uid 문서에 쌓이는지 | API 비용 | 미실행 |
| 3 | 새로 설치 → 사진첩 경로(권한 허용·거부 각각) → 홈까지 멈춤 없이 | 앱 장애 | 미실행 |
| 4 | 추천·AI 대화·도시 질문 각 1회, 구매 복원 버튼 | 앱 장애·심사 | 미실행 |
| 5 | 비행기 모드에서 추천·대화 → 멈추지 않고 연결 안내 | 앱 장애·심사(2.1) | 미실행 |
| 6 | 여행을 만들고 강제 종료·재실행해 남는지 → 마지막에 모든 데이터 지우기 → 온보딩 | 데이터 유실·심사 | 미실행 |

## 출시 후로 미룬 실기기 확인

2026-11-07 결정. 추천 품질·표시 문제라 업데이트에서 고친다. 통과로 보지 않는다.

- 추천 제외·넘기기 유지: 5·6·19번
- 근거 없는 취향 생성 없음: 1·2·7·12·18번
- 요청 처리: 9번(로딩 중 조건 변경), 3번(새 사람 대 친구), 20번(목록 밖 도시 입력 시 가짜 카드 없음)
- 표시: 10번(도시 질문 출처), 22번(실제 결과에서 예산 재정렬), 21번(메모 수정 후 대화 맥락)
- iCloud 재설치 복구: 2026-11-03 TestFlight에서 확인했다. 최종 빌드 재확인은 미룬다

## 알려진 서버 위험(출시 후 관찰)

- 서버 전체 하루 호출 상한 1000회(`functions/index.js` `DAILY_CALL_CAP`): 넘으면 구독자를 포함해 그날 모든 AI 호출이 막힌다. 비용 안전장치로 두고 Firebase 콘솔에서 사용량을 본다.
- 익명 계정을 새로 만들어 무료 한도를 반복해 받는 악용: App Check가 막고, 하루 상한이 마지막 안전장치다.
