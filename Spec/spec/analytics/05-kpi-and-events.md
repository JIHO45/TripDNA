# KPI / 이벤트 설계 (3.0)

전제: [3.0 스펙](../../docs/product/Travel_Fingerprint_3.0_Spec.md) 8절. 구버전의 `moment_logged` 확장
필드와 `trip_axis_updated`는 여행 중 입력 폐기로 무효화되어 이 문서로 대체됩니다.
기존 이벤트와 이름 충돌 여부는 구현 전에 확인하되, 아래 표를 3.0의 기준 이름으로 사용합니다.

## 1. 신규/변경/보류 이벤트

| 이벤트 | 상태 | 발생 시점 | 핵심 필드 |
|---|---|---|---|
| `trip_started` | 신규 | 여행 등록 완료 시 | `legs[]{countryCode, cities[], dates}`, `companion`, `purpose`(leisure/obligation) — 무드 태그(구 Trip Mode) 폐지 |
| `trip_evaluated` | **신규 (핵심)** | 여행 종료 평가 또는 온보딩 백필 | 3.0 스펙 2.2 스키마: `legs[]`, `bestLegCountryCode`(다구간), `satisfaction`, `wouldRepeat`, `comparison`, `positiveTags[]`, `negativeTags[]`, `source`, `skipped` |
| `ranking_adjusted` | 신규 | 랭킹 보드 조정 세션 종료 | `moved_trip_ids[]`, `positions_before/after`, 재생 델타 요약 |
| `utv_recomputed` | 신규 | 원장 재생 실행 시 | `trigger`(evaluated/rank_edit/onboarding), 축별 델타, `ledger_version` |
| `daily_photo_selected` | **신규 (기록용, UTV 미반영)** | 여행 중 하루 한 장 선택 또는 자동 폴백 확정 시 | `tripId`, `tripDayIndex`, `photoId`, `selection`(manual/auto_fallback), `dayReaction`(good/neutral/bad/null) — 3.0 스펙 2.5절 경계 규칙 참고 |
| `recommendation_feedback` | 유지 (2.0) | 카드 저장/스킵/싫어요 | `slot`, `action`, `countryCode` |
| `slot_impression` / `slot_click` / `slot_save` / `slot_reopen` | 유지 | 추천 화면 | 구버전 정의 유지 + `explanation_type`(태그인용/랭킹앵커/축폴백) 추가 |
| `explanation_understood_survey` | 유지 (실험 B) | 카드 상세 설문 | `experiment_arm`, `understood` |
| `exploration_slot_feedback` | 유지 (실험 C) | fresh_stretch 반응 | 구버전 정의 유지 |
| `wrapped_opened` / `wrapped_completed` | 신규 | 12/15~1/15 연간 Wrapped 시작/완료 | `year`, `trip_count`, `destination_count`, `has_photo` |
| `wrapped_image_saved` / `wrapped_shared` | 신규 | 연간 공유 이미지 저장/공유 | `year`, `destination_count`, `has_photo` |
| `trip_card_shared` | 신규 | 개별 여행 대표 카드 공유 | `tripId`, `country_count`, `has_photo` |
| `moment_logged` | **보류 (v1.5)** | — | 스토리 기능 재도입 시 재설계 |

랭킹 드래그 중 지문 미리보기는 로컬 임시 UI이므로 이벤트를 발생시키지 않습니다.
`ranking_adjusted`와 `utv_recomputed(trigger=rank_edit)`는 `이 순서로 저장`을 누른 경우에만 기록합니다.

## 2. 체감 지표

| 지표 | 산식 | 목적 |
|---|---|---|
| 평가 완료율 | `trip_evaluated(skipped=false) / 완료 trip` | 30초 예산이 실제로 지켜지는지 (리스크 #7) |
| 서열 응답률 | `comparison.result != skipped 비율` | 캘리브레이션 장치의 생존 여부 (실험 A′ 가드레일) |
| **부정 태그 수집률** | `negativeTags ≥ 1인 평가 비율` | 음성 신호 확보 (리스크 #4의 KPI) |
| 성향 태그 선택률 | 성향 그룹 태그가 선택된 평가 비율 | 양극 태그 선택 경쟁 모니터링 (리스크 #3) |
| 랭킹 조정률 | `ranking_adjusted 발생 유저 / MAU` | 비여행 참여 접점 (리스크 #6, 실험 E) |
| 온보딩 백필 수 | 유저당 `source=onboarding_backfill` 평가 수 | 콜드스타트 해소 정도 |
| 하루 한 장 수동 선택률 | `selection=manual / 전체 daily_photo_selected` | 여행 중 접점의 생존 여부 — 목표가 아닌 관측 지표 (리스크 #8) |
| 선택 유저 평가 완료율 우위 | 수동 선택 유저 vs 자동 폴백 유저의 평가 완료율 차 | **v1.5 스토리 승격 판단의 1차 근거** (3.0 스펙 9절 트리거) |
| 저장 전환율 / 재열람율 / 슬롯 다양성 엔트로피 | 구버전 정의 유지 | 추천 품질 |
| 설명 유형별 저장률 | `explanation_type`별 저장 전환율 | 태그 언어 순환의 효과 검증 (실험 B) |
| 예측 적중률 | 저장 국가 방문 시 s̃_t 상위권 진입 비율 | 장기 신뢰 지표 (spec/04 5절) |

## 3. KPI ↔ 실험 매핑

| 실험 | 1차 지표 | 가드레일 |
|---|---|---|
| A′ (신호 정제: simple vs calibrated) | 저장 전환율, best_match 저장률 | 평가 완료율, 서열 응답률 |
| B (설명 카피: 태그 vs 축 vs 단일점수) | 저장 전환율, 상세 체류시간 | 설명 이해도 |
| C (탐험 반경 개인화) | fresh_stretch 저장/방문 전환율 | 탐험 수용률, 스킵률 |
| D (상황필터 강도) | 노출 대비 저장 전환율 | Fit Tag별 전환율 격차 |
| E (랭킹 보드 노출) | 재방문율, 장기 저장 전환율 | 랭킹 조정률, 재생 델타 분포 |

## 4. 대시보드

- 실험 A′ 패널 최상단: 평가 완료율 + 서열 응답률 (구버전의 moment_logged 채택률 자리를 대체)
- 부정 태그 수집률·성향 태그 선택률을 주간 코호트로 고정 배치 (조용히 무너지는 지표들)
- `utv_recomputed` 축별 델타 분포 — 파라미터 수렴 관측 (리스크 #5)

## 5. 확정이 필요한 항목

- 기존 17개 이벤트 원문과의 이름 충돌 확인 (구버전 미결 승계)
- 재열람 인정 최소 경과 시간 (구버전 미결 승계)
- 부정 태그 수집률·평가 완료율의 목표 임계값 (베이스라인 실측 후)
