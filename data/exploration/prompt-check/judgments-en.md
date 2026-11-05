# 추천·조건 추출 지침 v5 연결 검증: 영어 앱 (2026-11-05)

실제 1단계 응답을 2단계로 이었다(`runs/en-linked/`, Haiku 5.5, 18호출 $0.0168, 사례당 1회). 판정은 Claude(Joe 검수 전). 지침은 한국어 연결 검증과 같은 버전(표·marked 금지, understanding 요청만, 머리말 수정 포함).

## 계약 (앱 검증 코드)

18/18 통과. 추출 응답 없음 0. 한국어 요청의 quote는 모두 한국어 원문 그대로였다(E06은 영어 원문).

## 언어

카드 reason·caveat, understanding, memories_used.how, 조건 text 모두 영어. 한글 0자.

## 조건 추출

한국어 앱과 level·방향이 같다. 다른 곳은 E01 하나: 한국어 앱은 subconcept scenery, 영어 앱은 other(같은 supporting). E06 street food는 quote가 "it must have good street food"로 조금 길어졌지만 원문 안에 있어 통과.

## 문제

- **R01 understanding이 필수 조건을 선호로 바꿔 씀(실제 오류):** 입력은 직항 `required`인데 "with a direct flight preferred"라고 썼다. 한국어 앱에서는 "직항 항공편이어야 하고"로 맞았다. 한국어 E05의 인원 재서술(Party size 1 → "동행 인원 미정")과 같은 유형이다: understanding이 전달받은 값이나 조건 수준을 다르게 서술한다.
- **내부 용어 노출(영어에서만 확인):** E04 두바이 "The desert experiences in the city's scope", 베이징 "the Great Wall at Mutianyu is within the trip's scope", 베이징 caveat "hiking or other unverified activities". 표의 열 이름(city scope, unverified)이 그대로 문장에 나왔다. 검증 코드의 금지 용어 목록에 없어 통과했다.

## 검토 필요

- R01 파리 caveat "the flight cost will make up most of the budget, so the trip is close to the top of the range": 범위(160만~230만 원)가 예산(150만 원)을 넘는데 "범위 위쪽에 가깝다"고 해 뜻이 흐리다. 예산 판정 문장에 가깝다.
- E05 caveat들이 야경 요청과 무관한 "concert, festival, or sports schedules" 확인을 나열한다(표의 시즌 미확인 세부를 그대로 옮김). 지침은 언급할 때만 확인 필요를 쓰라고 했는데, 언급하지 않은 활동까지 나열했다.

## 맞게 된 것

- (정정) R01 서울 caveat "Since Seoul is domestic, the flight conditions do not apply"는 개선이 아니라 오류다. 입력 표는 서울도 두 조건 모두 needs check인데, 모델이 코드의 판정을 '해당 없음'으로 바꿨다(출발지는 Korea까지만 주어짐).
- E05 understanding은 "solo trip"으로 입력 인원과 일치(한국어 앱의 인원 오류는 여기서는 재현되지 않음).
- E06 교토 caveat가 해변이 없고 붐빈다는 점을 숨기지 않음. E03 일본 도시 없음.
- R03 메모: how에 "the note about tiring crowds in Kyoto was treated as your preference, not as a fact about Muğla"라고 적어 메모를 개인 선호로만 썼다.

## 규칙 세 줄 수정 후 재확인: R01·E04·E05 (같은 날)

지침: 입력 보존, 판정 유지("not applicable" 포함), 관련 있는 확인만(규칙 세 줄 교체). `runs/en-linked/`, Haiku 5.5, 사례당 1회. 계약 3/3 통과. 판정은 Claude(Joe 검수 전).

| 사례 | 본 것 | 결과 |
|---|---|---|
| R01 | 필수 유지, 서울 판정, 파리 예산 표현 | understanding "A direct flight is required, and a flight time within 5 hours is preferred"로 필수·선호가 맞다. 서울 caveat는 needs check를 유지했다("these still need checking"). 8장 모두 두 확인이 남았다. **파리 예산 표현은 그대로 흐리다**: 자기 범위 하단(160만 원)이 1인 예산(150만 원)보다 높은데 "the budget is tight". 멕시코시티 "flights may push the total above the budget"는 금지한 예산 판정 문장에 가깝다. 볼로냐(160만~230만)·부에노스아이레스(200만~280만)는 예산 언급이 없어 카드마다 다르다 |
| E04 | 지역 설명이 자연스러운지 | 8장 모두 소음 선호를 needs check로 유지했고 understanding도 "this isn't a requirement"로 맞다. "unverified" 노출은 사라졌다. **"within the city scope"가 3장(베이징, 멕시코시티, 베네치아)에 남았다**: 표의 열 이름이며 "표·열을 언급하지 말라" 규칙 위반이다 |
| E05 | 관련 없는 활동 나열 | concert·festival·sports 같은 나열은 사라졌다(1회 표본이고 원인은 여전히 가설). **새 문제(판정 유지 위반)**: 도쿄는 박물관 f2 not met인데 reason에 "it has a wide range of museums"라고 써 공급된 판정과 반대로 말했다. 라스베이거스·상하이·홍콩·방콕의 not met도 "limited", "may need more planning"처럼 확인하면 되는 문제로 약해졌다. 같은 사례의 한국어 앱은 not met을 그대로 썼다 |

## 검토 필요

- 도쿄 박물관이 not met인 것이 카탈로그 등급의 문제인지는 확인하지 않았다. 지침 기준으로는 판정을 바꾼 것이 오류이고, 실제 사실로 틀렸다는 뜻은 아니다.
- 예산 규칙은 "예산이 범위 하단 근처일 때"만 다룬다. 예산이 범위 하단보다 낮을 때 무엇을 쓸지 지침에 없다(규칙 공백일 수 있음).
- 지침의 범위 규칙 자체가 "city scope"라는 말을 쓰고 있어 모델이 그 말을 옮겼을 가능성이 있다(가설).

## 검토 반영 (같은 날)

- 파리 "the budget is tight"는 예산 충족을 보장하지 않으므로 오류로 세지 않는다. 멕시코시티 "flights may push the total above the budget"가 예산 판정 문장 문제다.
- E04 "within the city scope"는 표현 문제로 낮춘다(주의사항 누락·판정 변경과 같은 심각도로 세지 않는다).
- E05 도쿄: 박물관 등급은 `make_time`이고, 1단계 추출이 "있으면 좋겠어요"에 `min_grade: choose`를 붙여 코드가 불충족으로 판정했다. 등급 자체가 아니라 충족 기준이 원인이었다. 영어 답이 판정을 따르지 않은 것은 판정 유지 규칙 기준으로 위반이지만, 그 판정이 요청에 맞지 않았다.
- 조치(city-prompt-v6, city-rank-v4): 경험 조건 충족 기준을 `make_time`으로 통일(정책 변경), 설명 입력에서 등급과 충족·불충족 제거(확인 필요만 남김), 범위 규칙에 "범위는 언급할 장소를 제한하는 데만 쓰고 장소와 위치를 자연스럽게 설명", 예산 규칙을 "예산 충족·초과를 어떤 표현으로도 판정하지 않고, 추정의 불확실성(항공료 등)만 설명"으로 바꿨다.

## v6 재확인: E05·E04·R01 (같은 날, city-prompt-v6·city-rank-v4)

`runs/en-linked/`, Haiku 5.5, 사례당 1회, 9호출 $0.0095. 계약 6/6 통과. 판정은 Claude(Joe 검수 전). 기준 네 가지(사용자 결정).

1. **후보별 등급·충족 판정 제거:** 통과. 요청 원문 3개의 후보 표에 등급 이름과 후보별 met/not met이 없다("met, unmet이라고 말하지 말라"는 시스템 지침 문구에는 남아 있다). 추출 요청에도 min_grade가 없다.
2. **새 충족 기준이 선정·정렬에 반영:** 통과. E05 후보가 바뀌었다(이전: 뉴욕·라스베이거스·도쿄·파리·상하이·홍콩·베를린·방콕 → 라스베이거스·뉴욕·도쿄·방콕·서울·파리·바르셀로나·싱가포르). cities.json과 대조하면 표 12곳 모두 야경 make_time 이상이라 핵심 조건을 채웠고, 도쿄 박물관(make_time)이 충족이 됐다. 방콕은 야경 make_time으로 핵심을 채웠고 박물관(if_there)만 미충족이다. 순서는 핵심 충족 수 → 주 컨셉 등급 → 보조 충족 수 규칙과 맞다(방콕은 주 컨셉 등급이 높아 보조 미충족에도 앞선다). 야경 if_there인 베를린은 빠졌다. R01·E04는 경험 조건이 없어 후보가 그대로다.
3. **입력값·필수·확인 필요 보존:** 한 곳 빼고 통과(누락은 통과로 치지 않는다). understanding 3개 모두 시기·인원·기간·예산·필수/선호가 입력과 같다. E04 8장 모두 소음 확인 필요, R01 7장은 직항·비행시간 확인이 남았다. **예외(보조 조건의 확인 안내 누락):** R01 후쿠오카 caveat 전문 "Please check whether a direct flight is available for your departure city, though flight time is typically short." 직항 확인은 남았지만 5시간 이내인지 확인하라는 안내가 빠졌다. 과거 서울처럼 "조건이 해당하지 않는다"고 판정을 명시적으로 뒤집은 것과는 달라 같은 심각도로 묶지 않는다. 전체 회귀에서 이 유형이 얼마나 반복되는지 본다.
4. **예산 판정 없음:** 통과. R01 카드 8장에 예산 충족·초과 문장이 없다.

그 밖: "within the city scope"는 사라졌다(두바이 "outside the city center", 아부다비 "reached by bridge", 베네치아 "reached by boat"). E05 라스베이거스 "Museums are fewer and less central than in the other candidates"는 등급과 모순이 아니다(make_time은 방문 가치이지 박물관 수가 아님). "다른 후보보다 적다"는 별도의 비교 사실이라, 검토한다면 등급 대조가 아니라 사실 확인 대상이다(확인하지 않음). 무관한 활동 나열 없음.

## v6 전체 회귀: 10개 사례 (같은 날, city-prompt-v6·city-rank-v4)

`runs/en-linked/`, Haiku 5.5, 사례당 1회. 새 호출 12개 $0.0111(E04·E05·R01은 재확인 응답 재사용). 계약 18/18, 추출 응답 없음 0. 판정은 Claude(Joe 검수 전). 기준 네 가지(사용자 결정). 두 언어 표는 한국어와 같다.

| 기준 | 한국어 | 영어 |
|---|---|---|
| 1. 후보별 등급·충족 판정 제거 | 통과(요청 18개) | 통과(요청 18개) |
| 2. 새 충족 기준이 선정·정렬에 반영 | 통과 | 통과 |
| 3. 입력값·필수 조건·확인 필요 보존 | 통과(경미 1) | 누락 1, 안내 약함 3 |
| 4. 예산 충족·초과를 판정하지 않음 | 통과 | 위반 1, 경계 1 |

- **조건 추출:** 10개 사례 모두 기대 수준과 같다(E01 supporting, E02 required, E03 required country JP, E04 supporting, E05 core·supporting, E06 supporting·supporting·required, E07 supporting, R01 required·supporting). E07 문장 속 지시를 따르지 않았다. 한국어 quote는 원문 그대로다.
- **새 기준 반영:** E05는 재확인 절 참조. E06의 필수 경험 조건(길거리 음식): 후보 8곳 모두 street make_time 이상(부산·푸껫·홍콩·발렌시아 make_time, 타이베이·서울·싱가포르 choose, 교토 make_time)이고, 해변 make_time 이상이지만 street가 기준 미만인 17곳은 후보에 없다. 이전 기준(choose)이었다면 부산·푸껫은 빠졌을 도시다.
- **확인 필요 보존:**
  - E02 직항(필수): 8장 모두 확인 필요.
  - E06 혼잡도(보조, needs check): 8장 중 5장은 확인 필요라고 썼다. **안내 약함 3장:** 푸껫 "Popular beaches and island tours can be crowded at peak times"(혼잡을 사실처럼 말하고 확인 안내는 투어에만), 타이베이 "whether the hiking trails and quieter nature spots are open and suitable in March needs checking"(혼잡도라는 말이 없음), 싱가포르 "Sentosa and the main parks can be busy"(확인 안내는 야생동물에만). 혼잡 가능성은 언급했으므로 R01 후쿠오카처럼 조건이 빠진 누락보다는 약하게 본다.
  - E06 season check needed(서울 hiking·wildlife, 싱가포르 wildlife): 둘 다 확인 필요라고 썼다.
  - 후쿠오카 유형(확인 필요 조건 안내 누락): 전체 회귀에서 R01 후쿠오카 1건, 안내 약함은 E06 3건.
- **예산:** **위반 1건:** R02 서울 caveat "Round-trip flights from JFK are often well above the budget's flight share"는 예산과 비교한 판정 문장이다. **경계 1건:** R02 방콕 "may make up most of the budget". 나머지 R02 caveat는 추정의 불확실성(항공료·환율)만 말했다. 비용은 USD, JFK 출발 반영 문구가 있다(금액이 맞는지는 범위 밖).
- **그 밖:** E07 understanding "Staying near the sea is a supporting preference"는 조건 수준 이름을 그대로 썼다(경미). R03 메모: m1(방콕 야시장)→냐짱 야시장, m2는 "Your past dislike of crowded Kyoto"로 개인 경험으로만 써서 교토를 객관적으로 붐비는 곳이라 단정하지 않았다. "city scope" 같은 표 용어 노출 없음.

## 검토 반영: 전체 회귀 판정 기준 (같은 날, 사용자 결정)

- **지침은 더 늘리지 않는다.** 두 유형 모두 이미 명시적으로 요구하거나 금지한 내용이라, 비슷한 문장을 더하는 효과가 불확실하다. 이번 지침 수정 작업은 v6에서 마무리한다.
- **혼잡도 안내 약함(E06 3장):** "붐빌 수 있다"도 불확실성을 전달한다. "확인하세요" 문구가 없다고 실패로 세지 않고, 사용자가 조건을 충족한다고 오해할지를 기준으로 본다. 이 기준으로 푸껫·싱가포르는 혼잡 가능성을 밝혀 오해 소지가 낮다. 타이베이는 "quieter nature spots"만 말해 혼잡도 판단을 사용자에게 넘기지 않으므로 검토 필요로 남긴다.
- **R01 후쿠오카 비행시간 누락:** 조건별 확인 안내가 제품 요구이므로 실제 누락이다.
- **R02 서울 예산 비교:** 명확한 문제다. 입력에 없는 "예산 중 항공료 몫"을 만들어 비교했다.
- **다음:** 같은 지침으로 영어 R01·E06·R02 추천 단계만 2회씩 더 실행해(추출은 1회 결과 재사용) 재현 여부를 본다. 실패율 추정에는 부족한 표본이다.
- **반복되면:** 문구를 더 붙이기보다 모델의 역할을 줄인다. 예: 확인 필요 조건을 화면에 직접 표시하면 모델 문장이 빠뜨려도 사용자가 확인할 수 있다(별도 개선으로 판단).

## 반복 확인: R01·E06·R02 추천 단계 2회 추가 (2026-11-05~06, v6 그대로)

`runs/en-linked/`, Haiku 5.5. 같은 요청(같은 추출 결과)으로 추천만 2회 더 호출(6호출 $0.0092). 앱 검증 코드 기준 계약 6/6(`check --nth 2`, `--nth 3`). 판정은 Claude(Joe 검수 전). 재현 여부를 보는 용도이며 실패율 추정에는 부족하다.

| 사례 | 본 유형 | 1회차(전체 회귀) | 2회차 | 3회차 |
|---|---|---|---|---|
| R01 | 확인 필요 조건의 안내 누락 | 1장(후쿠오카 비행시간) | 0/8 | 0/8 |
| E06 | 혼잡도 조건을 충족한다고 오해할 문장 | 0(타이베이 검토 필요 1) | 0/8 | 0/8 |
| R02 | 예산과 비교하는 문장 | 1장(서울), 경계 1(방콕) | 0/8 | 0/8 |

- R01: 두 회차 모두 8장 전부 직항과 비행시간을 함께 확인하라고 썼다.
- E06: 두 회차 모두 8장 전부 혼잡도 확인이 필요하다고 썼다. 2회차 교토 "it's hard to meet a 'not too crowded' preference"는 보조 선호를 모델이 미충족 쪽으로 말한 것이지만, 충족으로 오해할 문장은 아니다.
- R02: 두 회차 모두 caveat는 항공료·환율·영업시간 같은 추정의 불확실성만 말했다. 2회차 understanding "Each card below explains … and gives an estimated total cost"는 요청이 아니라 출력 내용을 말했다(경미, 한국어 R03과 같은 유형).
- 결론: 세 유형 모두 추가 2회에서 재현되지 않음. 1회차의 두 문제(후쿠오카 누락, 서울 예산 비교)는 해결된 것으로 바꾸지 않고 실제 문제로 기록을 유지한다. 비용 범위가 회차마다 크게 달라진 것(R01 파리 하단 160만~200만 원 등)은 이번 검증 범위 밖이다.
