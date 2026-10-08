> **당시 기록 — 현재 적용 문서 아님.** 현재 기준은 [문서 목차](../README.md)에서 찾는다. 아래 본문·실험 계획·결과는 당시 기록으로 보존한다. 본문에 적힌 설계/스키마 버전은 문서 체계 버전과 별개다.

# 도쿄·푸껫·밴쿠버 자체 검수 준비

현재 상태: 2026-10-06 후속 합의로 사람 검수를 중단했다. 이 문서는 기존 초안의 검수 준비 스냅샷으로 보존하며 다음 작업은 [목록 대 프로필 탐색 실험](../evaluation/profile-exploration.md)이다. 아래 확인 순서는 재개 지시가 아니다.

작성일: 2026-10-06. D3의 사람 검수용 자료이며 LLM 재열람을 검수 완료로 취급하지 않는다. 원본은 `data/cities/`의 도시 JSON이다. 이 문서는 그 시점의 스냅샷이며 아래 버전·SHA-256과 원본이 달라지면 다시 대조한다.

## 확인 순서

1. 추천용 위치·경험부터 원문·번역·범위를 대조한다.
2. 추천을 바꾸는 계절·접근 제약을 확인한다. 오래된 일반 안내와 현재 상태를 구분한다.
3. 미상 질문은 억지로 채우지 않고 실제 추천 조건에 필요한 것만 추가 조사한다. 상세 교통·가격은 후순위다.
4. 검수자가 확인한 주장만 원본 JSON에 `review`를 기록한다. 수정한 주장에는 버전을 올리고 수정 전 검수를 재사용하지 않는다.

## 먼저 판단할 연결

- 푸껫 `west-coast-beach-visit`는 현재 위치 주장 `west-coast-beaches`만 활동 근거로 참조한다. 장소 존재와 가능한 활동을 구분해 경험 근거를 보강하거나 표현·분류를 좁힐지 판단한다.
- 푸껫 `old-town-location` PDF는 이번 도구에서 열리지 않았다. 기존 기록을 삭제하거나 확인일을 덮어쓰지 않았으며 원문 두 부분의 사람 확인이 필요하다.
- 도쿄 `ueno-park-location`은 산책 경로에서 위치 관계를 분리한 주장이다. 지도까지 대조할지 판단한다.
- 밴쿠버 `seawall-path-separation`은 추천 선택 제약인지 이용 안내인지 판단한다. 분류 변경은 사람 확인 뒤 별도로 반영한다.
- 6개 경험의 배편·숙박 필요 여부는 모두 미상이다. `null`을 `false`로 바꾸지 않는다. 특정 필수 조건을 확인하지 못했을 때는 충족했다고 표시할 수 없다.

## 검수 기록 방법

주장별로 유지·수정·보류를 정한다. 유지 시 원본의 `review.kind: self`, 실제 검수자 ID, 실제 검수일, 현재 주장 버전, 범위·번역 확인 메모를 기록한 뒤 `status: reviewed`로 바꾼다. 수정 시 주장 버전과 도시 자료 버전을 갱신하고 새 내용을 검수한다. 보류는 이유를 남기며 미상·미검수를 확인된 사실로 승격하지 않는다. 요약·경험·장소 연결도 함께 확인하고 일부 승인만으로 도시 전체를 완료 처리하지 않는다.

원본의 확인일은 2026-10-04~05이며 이번 재열람 날짜와 사람 검수일은 서로 다르다. 이번 작업은 원본 자료의 상태·버전·확인일을 변경하지 않는다.

## 도쿄 — 자료 v2

원본: [data/cities/jp-tokyo.json](../../data/cities/jp-tokyo.json). SHA-256: `9cd1c34267387a89b98dd764b555f84d9d2bad0b3a9106bdf962744ebaaa5967`.

초기 자료는 도쿄의 아사쿠사와 우에노 공원 주변 경험으로 제한한다. 도쿄도 도서 지역·후지산·다른 현의 경험을 포함하지 않는다. 도쿄 전체를 조사·검수했다는 뜻이 아니다.

주장 12개: 추천용 8개, 상세용 4개. 사람 검수 완료 0개.

### 장소·경험 연결

- 가미나리몬 (`kaminarimon`): 범위 초안 `inside`, 근거 asakusa-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 나카미세 상점가 (`nakamise`): 범위 초안 `inside`, 근거 asakusa-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 센소지 (`sensoji`): 범위 초안 `inside`, 근거 asakusa-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 우에노 공원 (`ueno-park`): 범위 초안 `inside`, 근거 ueno-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 시노바즈 연못 (`shinobazu-pond`): 범위 초안 `inside`, 근거 ueno-location, ueno-park-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 아사쿠사 거리·사찰 주변 탐방 (`asakusa-cultural-walk`): 활동 근거 asakusa-location, asakusa-street-walk; 제약 facility-reservation, visit-day-access. 배편·숙박 필요 여부는 미상.
- 우에노 공원·연못 주변 산책 (`ueno-park-stroll`): 활동 근거 ueno-location, ueno-park-walk; 제약 ueno-cherry-season, facility-reservation, visit-day-access. 배편·숙박 필요 여부는 미상.

### 요약 연결

- Explore the Kaminarimon, Nakamise and Sensoji area in Asakusa. — 근거 asakusa-location, asakusa-street-walk. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.
- Walk through Ueno Park and enjoy the scenery around the pond. — 근거 ueno-location, ueno-park-walk. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.

### 추천용 주장

#### `asakusa-location` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Asakusa is an area in eastern Tokyo centered on Sensoji Temple, Kaminarimon and Nakamise shopping street.

적용 범위: 도쿄 아사쿠사. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/destinations/eastern-tokyo/asakusa/). 원본 확인일: 2026-10-05.
대조 위치: Eastern Tokyo 분류 / An iconic Tokyo temple complex.

검수할 점: 아사쿠사 위치와 세 장소의 연결을 함께 확인한다. 강변 유람선 경험을 거리 탐방에 섞지 않는다.
기존 메모: 도쿄도 전체 또는 인근 현의 경험까지 포함하는 근거가 아니다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `asakusa-street-walk` — 주장 v2 / experience

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Visitors can explore the streets from Kaminarimon through Nakamise toward Sensoji in Asakusa.

적용 범위: 가미나리몬·나카미세·센소지 일대. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/destinations/eastern-tokyo/asakusa/). 원본 확인일: 2026-10-05.
대조 위치: Thunder gate, temples and traditional theme parks.

검수할 점: 가미나리몬→나카미세→센소지 탐방만 확인한다. 건물 내부 입장·상점 영업·혼잡은 별도다.
기존 메모: 개별 건물 내부 입장·상점 영업·혼잡 수준·무료 여부를 보장하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `ueno-location` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Ueno Park is located at 5-20 Ueno-koen, Taito City, Tokyo.

적용 범위: 우에노 공원. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/spot/482/index.html). 원본 확인일: 2026-10-05.
대조 위치: 제목 아래 주소.

검수할 점: 주소가 도쿄 다이토구임을 확인한다. 도쿄도 전체의 경험으로 확대하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `ueno-park-walk` — 주장 v2 / experience

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Visitors can walk through Ueno Park and view the scenery around Shinobazu Pond.

적용 범위: 우에노 공원·시노바즈 연못 주변. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/spot/482/index.html). 원본 확인일: 2026-10-05.
대조 위치: View beautiful cherry blossoms… / 산책 안내.

검수할 점: 산책과 연못 경관을 확인한다. 유료 보트·동물원·박물관은 포함하지 않는다.
기존 메모: 보트 이용·동물원·박물관 입장을 이 산책 경험에 포함하지 않는다. 공원이라는 이유로 조용함·낮은 운동 강도를 보장하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `ueno-cherry-season` — 주장 v2 / season

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

GO TOKYO describes the usual cherry blossom season in Ueno Park as late March to early April.

적용 범위: 우에노 공원의 벚꽃 관람. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/spot/482/index.html). 원본 확인일: 2026-10-05.
대조 위치: 벚꽃 관람 안내.

검수할 점: 통상 3월 말~4월 초를 월 전체 또는 특정 여행일 개화 보장으로 바꾸지 않는다.
기존 메모: 개별 여행일의 개화나 만개를 보장하지 않는다. 월 배열은 대략적인 시기이며 해당 월 전체가 개화 기간이라는 뜻이 아니다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `facility-reservation` — 주장 v2 / reservation

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What admission and advance booking conditions apply to the selected facilities or activities?

적용 범위: 아사쿠사·우에노의 개별 시설·체험. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 선택 시설의 조건이다. 거리·공원 경험 전체를 예약 필수/불필요로 단정하지 않는다.
기존 메모: 거리 산책·공원 입장과 내부 시설을 구분한다. 예약 불필요로 추정하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `visit-day-access` — 주장 v2 / access

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What closures, opening conditions and access restrictions apply on the intended visit date?

적용 범위: 아사쿠사·우에노의 실제 방문 구간. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 적용 구간·조건을 확인하며 안전·당일 개방을 보장하지 않는다.
기존 메모: 일반 관광 안내는 실시간 개방·접근 가능성을 증명하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `ueno-park-location` — 주장 v1 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Shinobazu Pond is in Ueno Park.

적용 범위: 우에노 공원·시노바즈 연못 주변. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/spot/482/index.html). 원본 확인일: 2026-10-05.
대조 위치: 산책 경로 마지막 Shinobazu Pond 언급.

검수할 점: 연못으로 이어지는 산책 설명에서 공원 내부 위치를 추론한 연결이다. 공식 지도와 대조할지 판단한다.
기존 메모: 기존에 열람한 공식 소개에서 위치 관계를 분리한 초안. 범위와 번역은 사람 검수 전이다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

### 상세용 주장 — 후순위

#### `asakusa-rail-access` — 주장 v2 / transport

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Asakusa Station is served by the Tokyo Metro Ginza Line, Toei Asakusa Line and Tobu Skytree Line.

적용 범위: 아사쿠사역. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/destinations/eastern-tokyo/asakusa/). 원본 확인일: 2026-10-05.
대조 위치: How to Get There.

검수할 점: 상세 질문용 보존 자료다. 이번 재열람에서는 노선 이름만 보았으며 시간·환승을 추천에 추가하지 않는다.
기존 메모: 숙소에서 출발하는 경로·환승·왕복 시간은 미확인이다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `ueno-entry-fee` — 주장 v2 / price

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

GO TOKYO lists admission to Ueno Park itself as free, separately from fees for facilities within the park.

적용 범위: 우에노 공원 자체 입장. 조건: 별도 조건 미등록.

출처: [공식 원문](https://www.gotokyo.org/en/spot/482/index.html). 원본 확인일: 2026-10-05.
대조 위치: How to Get to the Heart of the Ueno Area.

검수할 점: 공원 입장과 내부 시설 요금을 구분한다. 이번 핵심 검수 대상에서 후순위로 둔다.
기존 메모: 확인일의 게시 정보이며 모든 내부 시설이나 여행 총비용이 무료라는 뜻이 아니다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `local-round-trip` — 주장 v2 / transport

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What transport, transfers, waiting and round-trip travel time are needed from the chosen accommodation?

적용 범위: 아사쿠사·우에노의 선택 경험. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: 숙소·경로 미지정. 역 존재만으로 당일에 두 지역을 모두 체험 가능하다고 판단하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `visit-cost` — 주장 v2 / price

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What costs apply to transport, meals and selected facilities, and what do they include as of the quoted date?

적용 범위: 아사쿠사·우에노 방문. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 비용은 후순위다. 확인일·포함 범위와 1인/일행 기준을 구분한다.
기존 메모: 우에노 공원 자체 입장료를 도시 하루 예산으로 확대하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

## 푸껫섬 — 자료 v4

원본: [data/cities/th-phuket-island.json](../../data/cities/th-phuket-island.json). SHA-256: `662b827dbc974f7fc76cba5b8b5a7abb98acb5dab8351e7977051f157fcc95de`.

푸껫 본섬만을 대상으로 한다. 초기 자료는 빠통·까따·까론 해변과 푸껫 올드타운으로 제한한다. 주변 섬·보트 투어·팡아만·끄라비 등 본섬 밖 경험은 포함하지 않는다. 본섬 전체의 모든 경험을 검수했다는 의미가 아니다.

주장 16개: 추천용 8개, 상세용 8개. 사람 검수 완료 0개.

### 장소·경험 연결

- 빠통 해변 (`patong-beach`): 범위 초안 `inside`, 근거 west-coast-beaches. 검수 전에는 확인된 범위로 사용할 수 없다.
- 까따 해변 (`kata-beach`): 범위 초안 `inside`, 근거 west-coast-beaches. 검수 전에는 확인된 범위로 사용할 수 없다.
- 까론 해변 (`karon-beach`): 범위 초안 `inside`, 근거 west-coast-beaches. 검수 전에는 확인된 범위로 사용할 수 없다.
- 푸껫 올드타운 (`old-town`): 범위 초안 `inside`, 근거 old-town-location. 검수 전에는 확인된 범위로 사용할 수 없다.
- 서해안 해변 탐방 (`west-coast-beach-visit`): 활동 근거 west-coast-beaches; 제약 beach-season, experience-access, beach-red-flag, beach-current-conditions. 배편·숙박 필요 여부는 미상.
- 올드타운 건축 탐방 (`old-town-walk`): 활동 근거 old-town-architecture, old-town-location; 제약 experience-access. 배편·숙박 필요 여부는 미상.

### 요약 연결

- Patong, Kata and Karon beaches are on the west coast of Phuket main island. — 근거 west-coast-beaches. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.
- Explore Sino-Portuguese architecture in Phuket Old Town. — 근거 old-town-architecture. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.
- Waves and rip currents can pose swimming risks in Phuket during the May–October southwest monsoon. — 근거 beach-season. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.

### 추천용 주장

#### `island-scope` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Phuket main island and the surrounding islands within Phuket Province are distinct geographical areas.

적용 범위: 푸껫 본섬 및 푸껫주. 조건: 별도 조건 미등록.

출처: [공식 원문](https://km.dmcr.go.th/c_1/s_186/d_7567). 원본 확인일: 2026-10-04.
대조 위치: เกาะในจังหวัดภูเก็ต 서두.

검수할 점: 태국어 본섬과 주변 섬의 구분을 확인한다. 섬 수·면적·행정 경계까지 승인하지 않는다.
기존 메모: 태국어 원문을 바탕으로 작성한 초안. 섬 수·면적·현재 행정 경계는 이 주장에 포함하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `west-coast-beaches` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Patong, Kata and Karon beaches are on the west coast of Phuket main island.

적용 범위: 푸껫 본섬 서해안의 빠통·까따·까론 해변. 조건: 별도 조건 미등록.

출처: [공식 원문](https://thai.tourismthailand.org/Destinations/Provinces/%E0%B8%A0%E0%B8%B9%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95/350). 원본 확인일: 2026-10-04.
대조 위치: แนะนำ의 본섬 서해안 문단.

검수할 점: 세 해변 이름과 본섬 서해안 위치를 확인한다. 위치 주장만으로 활동·수영·휴식 적합성을 승인하지 않는다.
기존 메모: 위치만을 뒷받침한다. 수영 가능·운영·혼잡·이동 시간·예약 불필요를 뜻하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `old-town-architecture` — 주장 v2 / experience

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Visitors can explore older Sino-Portuguese architecture in Phuket Old Town.

적용 범위: 푸껫 올드타운. 조건: 별도 조건 미등록.

출처: [공식 원문](https://thai.tourismthailand.org/Articles/%E0%B9%80%E0%B8%94%E0%B8%B4%E0%B8%99%E0%B8%8A%E0%B8%B4%E0%B8%A5-%E0%B8%8A%E0%B8%B4%E0%B8%A1%E0%B8%AD%E0%B8%B2%E0%B8%AB%E0%B8%B2%E0%B8%A3-%E0%B8%A2%E0%B9%88%E0%B8%B2%E0%B8%99%E0%B9%80%E0%B8%A1%E0%B8%B7%E0%B8%AD%E0%B8%87%E0%B9%80%E0%B8%81%E0%B9%88%E0%B8%B2-%E0%B8%A0%E0%B8%B9%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95). 원본 확인일: 2026-10-04.
대조 위치: รายละเอียด 첫 문단.

검수할 점: 2020년 기사에서 건축 탐방만 확인한다. 식당 현재 영업·메뉴·가격과 건물 내부 입장은 제외한다.
기존 메모: 오래된 소개 기사다. 개별 건물 실내 입장이나 나열된 식당의 현재 영업·메뉴·가격은 확인하지 않았다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `old-town-location` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 이번 PDF 열람 실패·재확인 보류.

Phuket Old Town is the historic quarter of Phuket City (Mueang Phuket) on Phuket main island.

적용 범위: 푸껫 올드타운(라차다·푸껫·텝까사뜨리·사뚠·디북 거리로 둘러싸인 구역). 조건: 별도 조건 미등록.

출처: [공식 원문](https://nced.onep.go.th/opendata/2568/oldtown36_announce/phuket.pdf). 원본 확인일: 2026-10-04.
대조 위치: 4.2 / 보고서 표기 20쪽; PDF 파일 페이지 번호와 구별.

검수할 점: PDF 보고서 20쪽의 섬 내 도시 서술과 구시가지 경계를 모두 확인해야 한다. 이번 도구에서 PDF를 열지 못했으므로 재열람 보류다.
기존 메모: 천연자원환경정책계획청(ONEP)의 구시가지 경계 보고서. 도시가 섬에 있다는 서술과 구시가지 경계를 결합한 주장이므로 검수자가 두 부분을 모두 확인한다. 개별 건물 위치·개방은 포함하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `beach-season` — 주장 v3 / season

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

The Tourism Authority of Thailand warns that large waves and rip currents can make swimming dangerous in Phuket and similar destinations during the May–October southwest monsoon.

적용 범위: 푸껫 해안의 해수욕; 빠통·까따·까론의 당일 상태는 별도 확인. 조건: 바다에서 수영하려는 경우.

출처: [공식 원문](https://www.tatnews.org/2018/07/important-information-on-marine-tourism-in-thailand-during-the-southwest-monsoon-season/). 원본 확인일: 2026-10-05.
대조 위치: 2018-07-24 서두 / Swimming.

검수할 점: 2018년 일반 안내를 통상 계절 위험 설명으로만 쓸지 판단한다. 현재 날씨·연도별 몬순 날짜·당일 수영 가능은 확인되지 않았다.
기존 메모: 오래된 공식 일반 안내를 재열람한 것이다. 특정 연도의 몬순 시작·종료일이나 현재 개방 상태를 확인한 것은 아니다. 해변 산책과 해수욕을 구분한다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `experience-access` — 주장 v3 / reservation

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What advance booking and admission conditions apply to the selected facilities or activities?

적용 범위: 해변 및 올드타운의 개별 시설·체험. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 선택 시설의 조건이다. 거리·공원 경험 전체를 예약 필수/불필요로 단정하지 않는다.
기존 메모: 거리·해변 방문과 개별 유료 시설·체험의 예약 조건은 분리한다. 공식 관광 소개만으로 예약 불필요를 확인할 수 없었다. 버스 차내 결제도 예약 불필요의 근거가 아니다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `beach-red-flag` — 주장 v2 / access

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

The Tourism Authority of Thailand states that red flags on beaches in Phuket and similar destinations mean no swimming.

적용 범위: 푸껫 해변의 해수욕 구역. 조건: 현장에 빨간 깃발이 표시된 경우.

출처: [공식 원문](https://www.tatnews.org/2018/07/important-information-on-marine-tourism-in-thailand-during-the-southwest-monsoon-season/). 원본 확인일: 2026-10-05.
대조 위치: Swimming.

검수할 점: 빨간 깃발의 의미만 확인한다. 특정 해변에 지금 깃발이 있다는 뜻이 아니며 깃발 부재는 안전 증거가 아니다.
기존 메모: 깃발의 의미에 대한 안내이며 특정 해변에 현재 깃발이 있다는 주장은 아니다. 깃발 부재를 안전 확인으로 해석하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `beach-current-conditions` — 주장 v2 / access

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What warning flags, local restrictions and swimming conditions apply at the selected beach on the visit date?

적용 범위: 빠통·까따·까론 중 실제 방문할 해변. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 적용 구간·조건을 확인하며 안전·당일 개방을 보장하지 않는다.
기존 메모: 일반 계절 안내로 당일 수영 가능을 확정하지 않는다. 현장 통제와 당일 공식 안내 확인이 필요하다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

### 상세용 주장 — 후순위

#### `old-town-to-patong` — 주장 v3 / transport

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What transport, waiting and actual round-trip travel time apply to this route?

적용 범위: 푸껫 올드타운 → 빠통 해변. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: smartbus-town-patong-route에 시내 경유 노선을 별도로 기록했다. 올드타운의 정확한 승하차 지점·도보 접근·대기·왕복 시간은 확인하지 못했으므로 이 질문은 미상으로 유지한다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `patong-to-kata-karon` — 주장 v3 / transport

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What transport, waiting and actual round-trip travel time apply to this route?

적용 범위: 빠통 → 까론·까따 해변. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: smartbus-west-coast-route에 양방향 노선을 별도로 기록했다. 정확한 승하차 지점·대기·귀환편·왕복 시간은 확인하지 못했으므로 이 질문은 미상으로 유지한다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `experience-cost` — 주장 v3 / price

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What is the reference date and scope of each activity price and transport cost?

적용 범위: 선택할 해변·올드타운 체험 및 이동. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 비용은 후순위다. 확인일·포함 범위와 1인/일행 기준을 구분한다.
기존 메모: 버스 일반 편도 운임은 별도 price 주장에 기록했다. 개별 시설·체험·정류장 접근 비용은 미확인이며 버스 요금으로 도시 총예산이나 무료 이용을 추정하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `smartbus-west-coast-route` — 주장 v2 / transport

저장 상태: `unreviewed`. 도구 확인: 상세 자료·이번 재열람 대상 제외.

Phuket Smart Bus publishes an Airport–Rawai route in both directions via Patong, Karon and Kata.

적용 범위: 빠통·까론·까따의 Phuket Smart Bus 정류장 구간. 조건: 별도 조건 미등록.

출처: [공식 원문](https://phuketsmartbus.com/th/timetable). 원본 확인일: 2026-10-05.
대조 위치: 시간표 첫 노선의 South/North 경로: Airport → Patong → Karon → Kata → Rawai 및 역방향..

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: 노선 존재에 한정한다. 정류장까지의 도보·대기·혼잡·귀환편을 확인하지 않았으며 실제 왕복 시간이나 당일 경험 조합을 보장하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `smartbus-town-patong-route` — 주장 v2 / transport

저장 상태: `unreviewed`. 도구 확인: 상세 자료·이번 재열람 대상 제외.

Phuket Smart Bus publishes a Bus Terminal 2–Patong Beach route in both directions via Phuket Town.

적용 범위: Bus Terminal 2↔Phuket Town↔Patong Beach; 올드타운의 특정 건물까지 연결되는지는 미확인. 조건: 별도 조건 미등록.

출처: [공식 원문](https://phuketsmartbus.com/th/timetable). 원본 확인일: 2026-10-05.
대조 위치: 시간표 두 번째 노선의 Patong/Terminal 경로에 Phuket Town을 양방향 경유지로 표시한다..

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: 노선 존재에 한정한다. 정류장까지의 도보·대기·혼잡·귀환편을 확인하지 않았으며 실제 왕복 시간이나 당일 경험 조합을 보장하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `smartbus-west-coast-fare` — 주장 v2 / price

저장 상태: `unreviewed`. 도구 확인: 상세 자료·이번 재열람 대상 제외.

Phuket Smart Bus lists the standard one-way fare on its Airport–Patong–Rawai route as THB 100 per person.

적용 범위: Phuket Smart Bus 공항↔빠통↔라와이 노선. 조건: 일반 운임 대상 승객 1명; 해당 노선의 편도 승차 1회.

출처: [공식 원문](https://phuketsmartbus.com/th/payment). 원본 확인일: 2026-10-05.
대조 위치: ค่าโดยสาร 표: Airport ⇄ Patong ⇄ Rawai, 편도 100 ฿ flat..

검수할 점: 상세 비용은 후순위다. 확인일·포함 범위와 1인/일행 기준을 구분한다.
기존 메모: 공식 게시 운임의 확인일 기준 초안. 미래 여행일 가격이나 도시 총예산을 보장하지 않는다. 어린이 무료 기준은 조사 페이지 간 표현 차이가 있어 포함하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `smartbus-town-patong-fare` — 주장 v2 / price

저장 상태: `unreviewed`. 도구 확인: 상세 자료·이번 재열람 대상 제외.

Phuket Smart Bus lists the standard one-way fare on its Bus Terminal–Patong route as THB 50 per person.

적용 범위: Phuket Smart Bus Bus Terminal↔Patong 노선. 조건: 일반 운임 대상 승객 1명; 해당 노선의 편도 승차 1회.

출처: [공식 원문](https://phuketsmartbus.com/th/payment). 원본 확인일: 2026-10-05.
대조 위치: ค่าโดยสาร 표: Bus Terminal ⇄ Patong, 편도 50 ฿..

검수할 점: 상세 비용은 후순위다. 확인일·포함 범위와 1인/일행 기준을 구분한다.
기존 메모: 공식 게시 운임의 확인일 기준 초안. 미래 여행일 가격이나 도시 총예산을 보장하지 않는다. 어린이 무료 기준은 조사 페이지 간 표현 차이가 있어 포함하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `smartbus-onboard-payment` — 주장 v2 / operation

저장 상태: `unreviewed`. 도구 확인: 상세 자료·이번 재열람 대상 제외.

Phuket Smart Bus advertises onboard payment by cash or contactless card.

적용 범위: Phuket Smart Bus 차내 결제. 조건: 별도 조건 미등록.

출처: [공식 원문](https://phuketsmartbus.com/th/payment). 원본 확인일: 2026-10-05.
대조 위치: Payment Methods의 Mastercard / Visa, Cash 및 FAQ의 차내 결제 안내..

검수할 점: 상세 운영 정보는 후순위다. 현재 조건이나 예약 재고로 확대하지 않는다.
기존 메모: 차내 결제 가능과 예약 불필요·좌석 보장은 별개다. 이 근거로 사전 예약 조건을 채우지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

## 밴쿠버 — 자료 v2

원본: [data/cities/ca-vancouver.json](../../data/cities/ca-vancouver.json). SHA-256: `dfac8f773783943218ab8b47cec40938d1d6e58152a82f69bcce5a4fea12d348`.

밴쿠버 시내의 스탠리파크 해안길·숲길부터 다룬다. 노스쇼어·휘슬러 등 광역 자연 경험은 이번 자료에 포함하지 않는다. 밴쿠버 전체의 대표 경험을 모두 조사·검수한 것은 아니다.

주장 11개: 추천용 9개, 상세용 2개. 사람 검수 완료 0개.

### 장소·경험 연결

- 스탠리파크 Seawall (`stanley-seawall`): 범위 초안 `inside`, 근거 stanley-location, stanley-path-locations. 검수 전에는 확인된 범위로 사용할 수 없다.
- 스탠리파크 내부 숲길 (`stanley-forest`): 범위 초안 `inside`, 근거 stanley-location, stanley-path-locations. 검수 전에는 확인된 범위로 사용할 수 없다.
- 스탠리파크 해안길 산책 (`stanley-seawall-stroll`): 활동 근거 stanley-location, seawall-walk; 제약 seawall-path-separation, seawall-winter-maintenance, walk-effort, visit-day-access, facility-reservation. 배편·숙박 필요 여부는 미상.
- 스탠리파크 숲길 산책 (`stanley-forest-stroll`): 활동 근거 stanley-location, forest-walk; 제약 walk-effort, visit-day-access, facility-reservation. 배편·숙박 필요 여부는 미상.

### 요약 연결

- Stanley Park in downtown Vancouver offers waterfront and interior forest walks. — 근거 stanley-location, seawall-walk, forest-walk. 연결 근거가 모두 검수·유효성 검사를 통과해야 사용 가능.

### 추천용 주장

#### `stanley-location` — 주장 v2 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Stanley Park is located in downtown Vancouver.

적용 범위: 스탠리파크. 조건: 별도 조건 미등록.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/stanley-park.aspx). 원본 확인일: 2026-10-05.
대조 위치: Digital map.

검수할 점: 스탠리파크의 downtown Vancouver 위치만 확인한다. 노스쇼어·휘슬러는 포함하지 않는다.
기존 메모: 노스쇼어·휘슬러를 포함하는 위치 근거가 아니다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `seawall-walk` — 주장 v2 / experience

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Visitors can walk along the Stanley Park section of the Seawall.

적용 범위: 스탠리파크 Seawall. 조건: 별도 조건 미등록.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/seawall.aspx). 원본 확인일: 2026-10-05.
대조 위치: Walking and cycling around Stanley Park on the seawall.

검수할 점: 스탠리파크 구간의 보행 경험을 확인한다. 전 구간 완주·낮은 운동 강도는 보장하지 않는다.
기존 메모: 전 구간 완주를 필수로 권하지 않는다. 산책 가능이라는 이유로 짧거나 저강도라고 단정하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `forest-walk` — 주장 v2 / experience

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

Stanley Park has walking trails through its interior forest.

적용 범위: 스탠리파크 내부 숲길. 조건: 별도 조건 미등록.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/stanley-park-trails.aspx). 원본 확인일: 2026-10-05.
대조 위치: Forest trails 서두 / interior paths.

검수할 점: 내부 숲길 경험만 확인한다. 조용함·야생동물 관찰 성공·모든 길의 접근성을 일반화하지 않는다.
기존 메모: 구간별 경사·거리·사용자 체력과의 적합성은 별도 확인한다. 야생동물 관찰 성공·안전·조용함은 보장하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `seawall-path-separation` — 주장 v2 / access

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

The Seawall separates walking and jogging from cycling and inline skating, and visitors are instructed to follow the signs.

적용 범위: 스탠리파크를 포함한 밴쿠버 Seawall. 조건: 별도 조건 미등록.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/seawall.aspx). 원본 확인일: 2026-10-05.
대조 위치: 서두의 두 경로 안내.

검수할 점: 보행/조깅과 자전거/인라인의 분리·표지 준수를 확인한다. 추천 선택을 바꾸는 제약인지 단순 이용 안내인지도 판단한다.
기존 메모: 자전거 이용 규칙을 보행 규칙과 혼동하지 않는다. 현장 우회로는 별도 확인한다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `seawall-winter-maintenance` — 주장 v2 / season

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

The City of Vancouver describes temporary closures of some Stanley Park Seawall sections during winter maintenance.

적용 범위: Prospect Point~Third Beach 및 Ferguson Point 구간. 조건: 겨울 정비 시행 시.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/seawall.aspx). 원본 확인일: 2026-10-05.
대조 위치: Annual slope stabilization and maintenance.

검수할 점: 연례 정비 일반 안내다. 실제 방문일 폐쇄 여부와 구분하고 특정 날짜를 채우지 않는다.
기존 메모: 연례 정비의 일반 안내다. 특정 연도의 폐쇄 날짜·현재 전 구간 개방 여부는 미확인이다. 겨울의 시작·종료 월은 원문에 없어 null로 둔다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `walk-effort` — 주장 v2 / access

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: Do the selected section’s distance, gradient, surface and resting places suit the user’s walking requirements?

적용 범위: 스탠리파크 해안길·숲길의 선택 구간. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 적용 구간·조건을 확인하며 안전·당일 개방을 보장하지 않는다.
기존 메모: 자연 선호를 긴 도보나 고강도 운동 선호로 바꾸지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `visit-day-access` — 주장 v2 / access

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: Which sections are restricted by maintenance, weather or local controls on the intended visit date?

적용 범위: 스탠리파크 해안길·숲길. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 적용 구간·조건을 확인하며 안전·당일 개방을 보장하지 않는다.
기존 메모: 일반 정비 안내만으로 특정 날짜 개방 여부를 판정하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `facility-reservation` — 주장 v2 / reservation

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What booking conditions apply to any additional guided tour or facility?

적용 범위: 스탠리파크의 선택 투어·시설. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 선택 시설의 조건이다. 거리·공원 경험 전체를 예약 필수/불필요로 단정하지 않는다.
기존 메모: 초안의 자율 산책과 별도 유료 서비스의 예약 조건을 구분한다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `stanley-path-locations` — 주장 v1 / location

저장 상태: `unreviewed`. 도구 확인: 공식 본문 재열람·사람 검수 대기.

The waterfront Seawall and interior forest trails described here are in Stanley Park.

적용 범위: 스탠리파크. 조건: 별도 조건 미등록.

출처: [공식 원문](https://vancouver.ca/parks-recreation-culture/stanley-park.aspx). 원본 확인일: 2026-10-05.
대조 위치: 공원 서두 / 연결된 Seawall·trails 페이지.

검수할 점: 공원 소개와 연결된 Seawall·forest trails 설명을 대조한다. 밴쿠버 전체 Seawall을 공원 안으로 처리하지 않는다.
기존 메모: 기존에 열람한 공식 소개에서 위치 관계를 분리한 초안. 범위와 번역은 사람 검수 전이다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

### 상세용 주장 — 후순위

#### `local-round-trip` — 주장 v2 / transport

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What transport, waiting and round-trip travel time are needed between the accommodation and the chosen trail entrance?

적용 범위: 밴쿠버 숙소~스탠리파크 선택 구간. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 교통 자료는 후순위다. 경로·대기·왕복 시간의 빈칸을 추정하지 않는다.
기존 메모: 도심 위치만으로 차량 불필요·특정 이동 시간·당일 적합성을 확정하지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.
#### `visit-cost` — 주장 v2 / price

저장 상태: `unknown`. 도구 확인: 출처 없음·미상 유지.

미상 질문: What costs apply to the selected experience, transport, parking and rentals, and what do they include?

적용 범위: 스탠리파크 방문. 조건: 별도 조건 미등록.

출처는 등록되지 않았다. 원문을 확인하기 전까지 미상으로 유지한다.

검수할 점: 상세 비용은 후순위다. 확인일·포함 범위와 1인/일행 기준을 구분한다.
기존 메모: 공공 공원이라는 이유로 모든 방문 비용을 0으로 채우지 않는다.

- [ ] 원문·번역·적용 범위를 확인하고 유지/수정/보류와 이유를 기록한다.
- [ ] 사용되는 장소·경험·요약 연결이 주장 범위를 넘지 않는지 확인한다.

## 이번 확인 범위

공식 출처 URL 9개의 본문을 재열람했다. PDF 1개는 도구 열람 실패, 푸껫 버스 상세 출처 2개는 이번 재열람 대상에서 제외했다. 출처를 다시 읽은 것과 사람 자체 검수는 다르며 검수 완료는 여전히 0개다.
