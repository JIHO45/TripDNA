<!-- 이 파일은 generate_pilot_diagnostics.py 로 생성됨. EDITORIAL_FREEZE 시 편집 확정값 기준 -->
<!-- 축 체계: Travel_Fingerprint_3.0_Spec.md 1.1절 (energy_level/planning_style/social_mode) -->

## 국가별 프로필 상태 (편집 동결)

| 국가 | 대륙 | 합치도 | 파일럿 통과(>=0.7) |
|---|---|---|---|
| Japan | Asia | 1.000 | PASS |
| Thailand | Asia | 1.000 | PASS |
| Vietnam | Asia | 1.000 | PASS |
| India | Asia | 1.000 | PASS |
| South Korea | Asia | 1.000 | PASS |
| Indonesia | Asia | 1.000 | PASS |
| France | Europe | 1.000 | PASS |
| Italy | Europe | 1.000 | PASS |
| Iceland | Europe | 1.000 | PASS |
| Portugal | Europe | 1.000 | PASS |
| Norway | Europe | 1.000 | PASS |
| Greece | Europe | 1.000 | PASS |
| Morocco | Africa | 1.000 | PASS |
| Kenya | Africa | 1.000 | PASS |
| South Africa | Africa | 1.000 | PASS |
| Egypt | Africa | 1.000 | PASS |
| Tanzania | Africa | 1.000 | PASS |
| USA | North America | 1.000 | PASS |
| Mexico | North America | 1.000 | PASS |
| Canada | North America | 1.000 | PASS |
| Costa Rica | North America | 1.000 | PASS |
| Peru | South America | 1.000 | PASS |
| Brazil | South America | 1.000 | PASS |
| Argentina | South America | 1.000 | PASS |
| Colombia | South America | 1.000 | PASS |
| New Zealand | Oceania | 1.000 | PASS |
| Australia | Oceania | 1.000 | PASS |
| Fiji | Oceania | 1.000 | PASS |
| UAE | Middle East | 1.000 | PASS |
| Jordan | Middle East | 1.000 | PASS |

- 모드: `EDITORIAL_FREEZE=True` — 커뮤 검수 축 + Numbeo/기후 공개데이터로 확정값을 그대로 기록.
- 진짜 2인 독립 검수 전에는 합치도 1.0이 시뮬레이션이 아니라 **자체 동결** 표시임.

- 통과 30개국 / 탈락 0개국
- 탈락국(플랜B 회색 처리 대상): 없음

## 조건부 축 진단 (통과국 기준)

| 축 | 국가분산 | 필터1 통과(>=0.030) | 최대 상관계수(타 매칭축) | 독립성(|r|<0.60) |
|---|---|---|---|---|
| energy_level | 0.0173 | FAIL | +0.702 | FAIL |
| planning_style | 0.0170 | FAIL | -0.577 | PASS |
| social_mode | 0.0112 | FAIL | +0.702 | FAIL |

### 종합 판정 (국가분산 필터1 + 독립성)

- **energy_level**: 필터1(국가분산) FAIL, 독립성 FAIL -> 국가측 진단 FAIL (필터2 유저분산은 trip_evaluated 실데이터 필요, 별도 판정)
- **planning_style**: 필터1(국가분산) FAIL, 독립성 PASS -> 국가측 진단 FAIL (필터2 유저분산은 trip_evaluated 실데이터 필요, 별도 판정)
- **social_mode**: 필터1(국가분산) FAIL, 독립성 FAIL -> 국가측 진단 FAIL (필터2 유저분산은 trip_evaluated 실데이터 필요, 별도 판정)
