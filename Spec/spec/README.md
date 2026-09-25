# Travel Fingerprint — 평가체계 스펙 (3.0)

**제품·UI 최종 고정본:**
[Travel_Fingerprint_3.0_Final_Spec.md](../docs/product/Travel_Fingerprint_3.0_Final_Spec.md)

신호·UTV·Profile 모델 본문:
[Travel_Fingerprint_3.0_Spec.md](../docs/product/Travel_Fingerprint_3.0_Spec.md)

이 폴더는 위 문서를 실행 가능한 수준으로 구체화한 하위 문서 모음입니다.
문서 간 제품·UI 충돌 시 Final Spec이 우선합니다.

> 구버전 충돌 이력: 이 폴더는 원래 "여행 중 다회 슬라이더 유지" 전제로 작성되었고,
> 이후 루트의 2.0 스펙(종료 시 1회 회고)과 충돌 상태였습니다. 3.0 확정으로 충돌이
> 해소되었으며, 폴더 전체가 3.0 기준으로 재작성되었습니다. 2.0 스펙 파일은 삭제됨.

## 폴더 구조

```text
spec/
  signal/           신호 모델 · 실험
  recommendation/   추천 설명 · 태그 어휘
  analytics/        KPI · 이벤트
  ui/               온보딩 · 퀴즈 · UI 상세
  data/             Firestore 스키마
  pilot/            30개국 파일럿 · 시드
```

## 3.0 확정 사항 요약

- **여행 중 취향 입력 없음** — 스토리/순간기록(moment_logged)은 v1.5로 이동.
  단, 기록용 **하루 한 장**(동의된 자동 폴백 + Storage 동기화, UTV 미반영)과
  **여행 감지→평가 유도 알림**은 MVP 포함
- **평가 = 판정 + 서열 + 귀속**, 30초, 제출 후 수정 없음(서열 교정은 랭킹)
- **온보딩** = 사진첩/직접입력/퀴즈 동등 선택 → Apple 로그인 필수
- **홈** 최소화 + 탭 `홈/추천/여행`, Wrapped는 **12/15~1/15**
- **UTV = 원장 결정적 재생**, Profile_x Stage0 동결
- 유지: 3계층 취향 모델, 3슬롯, 램프업, λ 하한, 베이지안 수축, 상황 필터
- 전체 고정 목록은 Final Spec §1 참고

## 문서 목록

| 문서 | 내용 |
|---|---|
| [Travel_Fingerprint_3.0_Final_Spec.md](../docs/product/Travel_Fingerprint_3.0_Final_Spec.md) | **제품·UI 최종 고정** — 확정 결정, 화면 체크리스트, 개발 순서 |
| [Travel_Fingerprint_3.0_Class_Diagram.md](../docs/product/Travel_Fingerprint_3.0_Class_Diagram.md) | 개발용 도메인·서비스·저장소 클래스 다이어그램 |
| [Travel_Fingerprint_3.0_Spec.md](../docs/product/Travel_Fingerprint_3.0_Spec.md) | 신호·모델 본문 — 설계 원칙, 입력, UTV/Profile_x, 추천, 체감 루프, 로드맵, 리스크 |
| [pilot/01-country-profiles-and-axis-diagnostics.md](pilot/01-country-profiles-and-axis-diagnostics.md) | 30개국 라벨링 파이프라인, 2인 검수(+태그 어휘 서명 검수 추가), 축 진단 |
| [signal/02-signal-quality-and-aggregation.md](signal/02-signal-quality-and-aggregation.md) | s̃_t 서열 캘리브레이션, x_t 계산, UTV 원장 재생 규칙, 축별 게인/신뢰도 |
| [signal/03-ema-experiment-design.md](signal/03-ema-experiment-design.md) | 실험 A′(simple vs calibrated 신호 정제) + 실험 E(랭킹 보드) |
| [recommendation/04-slot-explainability.md](recommendation/04-slot-explainability.md) | 태그 언어 기반 설명 카피, 예측 책임지기, 탐험 반경 개인화 |
| [analytics/05-kpi-and-events.md](analytics/05-kpi-and-events.md) | trip_evaluated/ranking_adjusted/utv_recomputed 이벤트, 체감 지표, 실험 매핑 |
| [recommendation/06-tag-vocabulary.md](recommendation/06-tag-vocabulary.md) | 귀속 태그 어휘 초안 — 축 서명, 라우팅 3갈래(taste/constraint/quality), 노출 규칙 |
| [ui/07-onboarding-ui-flow.md](ui/07-onboarding-ui-flow.md) | 온보딩 UI 플로우 — Rise 스타일 설문 구조(훅→카드 루프→분석 연출→페이오프), 시간 예산, 다크 패턴 금지 목록 |
| [ui/08-ui-prompts.md](ui/08-ui-prompts.md) | UI 생성 프롬프트 — 공통 디자인 시스템 + 온보딩 핵심 6화면 (v0/Stitch 등 입력용) |
| [ui/09-taste-quiz.md](ui/09-taste-quiz.md) | 취향 퀴즈(P2-C 구체화) — 축별 문항 13개, 서명·점수화, 퀴즈만으로 첫 추천 도달 경로 |
| [data/10-firestore-schema.md](data/10-firestore-schema.md) | Firestore 데이터 구조 (앱 직접 쓰기) — 원장(trips)/랭킹/하루한장/이벤트 컬렉션, Security Rules, 시드 데이터 |
| [ui/detail/README.md](ui/detail/README.md) | UI-1~8 상세 구조 — 메인/서브 화면, 상태·분기, 데이터, 완료 조건 |

## 사람이 결정/실행해야 하는 항목 (요약)

- 파일럿: 30개국 최종 리스트, 진짜 2인 검수자 배정, 국가분산/독립성 임계값,
  **태그 어휘 축 서명 검수** (신규)
- 신호 모델: signal/02 7절 상수(w_rank, α_pos, δ_step, k_axis, g 곡선 등) — 전부 원격 설정 분리
- 태그: 한국어 최종 카피, 노출 우선순위 규칙
- KPI: 기존 이벤트와 3.0 기준 이름의 충돌 확인, 재열람 인정 기준

## 재현 방법

```bash
python3 spec/pilot/scripts/generate_pilot_diagnostics.py
python3 spec/pilot/scripts/generate_seed_data.py   # Firestore countries/tagVocabulary 시드 생성
```
