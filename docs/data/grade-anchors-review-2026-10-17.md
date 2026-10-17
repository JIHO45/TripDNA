# 등급 기준표 모델 검수 — 2026-10-17

대상: [anchors.json](../../data/destinations/anchors.json)의 28개 세부 × 2등급, 경계 사례 56건과 연결된 판정 문장·대표 사례. [기준표](grade-anchors.md)와 [판정 절차](destination-grading.md)를 함께 본다. `locals`의 상위 단계는 여전히 미정의다.

**결론: 현재 초안을 그대로 승인하거나 103곳 재판정의 확정 기준으로 쓰기 어렵다.** 경험을 좋아하는 여행자를 보겠다는 원칙과 달리 명소 개수·도시의 다른 매력·체류 시간·시즌으로 낮추는 사례가 반복된다. 먼저 이 판정 이유를 고치고, 분류 경계를 정한 뒤 사람이 행 전체를 승인해야 한다.

56건의 검토 결과: 유지 제안 17건, 수정 제안 18건, 보류 21건. 이는 모델의 검토 의견이며 승인 건수가 아니다. **승인 0건, catalog 등급 변경 0건.** 유지 제안도 사실·시즌 검증 완료를 뜻하지 않는다.

## 검수 범위와 증거 수준

- 56건 모두 판정 문장·사례 간 논리와 현재 catalog 범위를 검토했다. 대표 사례는 판정 문장과의 정합성을 함께 봤으며 모든 장소의 사실·운영까지 확인한 것은 아니다.
- 사실·분류 쟁점은 아래 공식 출처 19개와 부분 대조했다. 본문을 읽은 출처와 검색 결과 발췌만 확인한 출처를 구분했다. 검색 결과 확인만으로 출시용 사실 검수를 통과시키지 않는다.
- 출처는 경험의 존재·위치·유형을 뒷받침한다. choose 또는 make_time이라는 등급은 제품의 판정이므로 출처의 관광 홍보 표현이 이를 확정하지 않는다.
- 출처 없는 항목은 모델의 논리 검토다. 2026년 운영·입장 가능성·정확한 시즌을 모두 검수하지 않았다. 비용·기후·비행시간은 조사 범위에 넣지 않았다.

## 먼저 고칠 공통 기준

1. **개수·세계적 명성을 등급의 필수 조건으로 쓰지 않는다.** 단일 건축·박물관·테마파크도 그 경험의 선호자에게 여행 동기가 될 수 있다. 시드니 건축, 도하 박물관, 싱가포르 테마파크의 하향 이유가 특히 취약하다.
2. **짧은 시간도 별도 일정이 될 수 있다.** make_time의 반나절·하루 조건을 없애고, 그 경험을 위해 동선·예약·시간을 따로 잡을지를 본다. 니스 경관, 취리히 산행, 프랑크푸르트 골목 등이 해당한다.
3. **다른 볼거리와 함께 간다는 것은 하향 근거가 아니다.** 부다페스트 야경, 파리 길거리 음식, 프라하 미술관, 리우 라이브 바, 뉴욕 술을 각 경험의 선호자 관점에서 비교한다.
4. **시즌·조사 상태를 등급으로 대체하지 않는다.** 로마 오페라의 시즌 한정과 서울 공연의 날짜 의존을 같은 규칙으로 처리한다. 푸껫 수상 활동의 범위 미확인은 낮은 등급이 아니라 미확인으로 남긴다. 시즌 중 가능한 경험의 가치와 방문 시점에 가능한지를 나눈다.
5. **분류를 먼저 정한다.** 스튜디오 투어, 요리 교실, 애프터눈 티, 동물원, 관광 보트, 제트보트가 해당한다. 같은 경험을 이름만 바꿔 여러 세부의 상위 등급 근거로 복제하지 않는다. 그렇다고 한 세부에 넣었다는 이유만으로 다른 독립적인 경험을 배제하지도 않는다.
6. **기존 등급 하향을 목표로 삼지 않는다.** 뉴욕 스포츠는 US Open을 포함하면 choose를 재검토해야 한다. 파리·뉴욕의 상위 등급이 많다는 사실은 경고 지표일 뿐 개별 등급을 내리는 근거가 아니다.
7. **기준표가 같아도 사실 오류는 수정할 수 있어야 한다.** 판정 절차의 “기존 등급이 바뀌는 경우는 기준표가 바뀌었을 때뿐”은 너무 좁다. 새 사실·범위 오류·기존 판정 오류를 이유와 함께 정정하는 경로를 추가하도록 제안한다. 정책 문장은 이번에 임의 변경하지 않았다.

## 실제 반영한 수정

- 퀸스타운 hiking/choose 대표의 로이스 피크는 와나카 지역이므로 현재 catalog scope 밖이다. anchors에서 로이스 피크를 제거하고 벤 로먼드만 남겼다. 벤 로먼드만으로 choose가 충분한지는 미승인 상태로 명시했다. 범위를 늘리지는 않았다.
- 뉴욕 drinks/make_time은 이미 `above`여서 `make_time`을 제안한다. 잘못된 `below`는 현 파일에 없어 다시 수정하지 않았다.
- 렌더 검사기에 같은 도시·세부의 상충하는 등급 제안, 대표 사례의 잘못된 side, locals 외 세부의 undefined 우회를 거부하는 검사를 추가했다. 체크박스가 행 승인 상태를 반영하고 대표 사례에도 catalog scope가 표시되도록 했다.
- 그 밖의 등급·경계 방향·사람 승인 상태는 바꾸지 않았다. 아래 수정 제안은 검토 의견이며 자동 적용되지 않았다.

## 56건 경계 검토

유지 제안은 현재 방향을 잠정 유지, 수정 제안은 판정 이유·분류·제안 등급 중 명시된 부분의 변경 제안, 보류는 추가 근거 또는 기준 결정이 필요함을 뜻한다. 범위는 중복 저장하지 않으며 [생성 기준표](grade-anchors.md)의 catalog scope를 확인한다. 아래 현재 값과 제안값은 검수 시점의 스냅샷이다.

### scenery

- **choose · 밴쿠버 — 보류**
  - 원안 `make_time` / catalog `choose`. 밴쿠버를 도시·자연의 조합으로 고른다는 주장은 경관 선호자의 choose 가능성을 반박하지 않는다. 범위 안의 구체적 경관과 대표 사례를 비교해야 하며, 현재 하향 이유는 교체해야 한다.

- **make_time · 니스 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 니스 전망대의 체류 시간이 짧다는 이유만으로 if_there가 되지 않는다. 전망을 위해 동선·시간을 따로 잡는 경험이면 make_time 후보다. 실제 접근 경로·관람 경험은 미대조다.

### hiking

- **choose · 밴쿠버 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 밴쿠버 산행을 여행 동기로 보는 방향은 판정 질문과 맞는다. 다만 여러 코스에 대중교통으로 닿는다는 일반화, 코스별 난도·시즌은 미확인이다. 대표 퀸스타운의 범위 밖 로이스 피크는 이번에 제거했다. [DOC — Roys Peak Track](https://www.doc.govt.nz/parks-and-recreation/places-to-go/otago/places/wanaka-area/things-to-do/roys-peak-track) [DOC — Ben Lomond Track](https://www.doc.govt.nz/ben-lomond-track)

- **make_time · 취리히 — 수정 제안**
  - 원안 `if_there` / catalog `make_time`. 취리히를 짧은 언덕 산책으로 일괄 낮출 근거가 부족하다. 공식 안내는 위틀리베르크까지 오르는 등산로를 소개한다. 이 경로를 구체화해 make_time으로 다시 비교한다. 펠제네크까지의 연장 코스는 현재 scope 포함 여부를 별도로 판단한다. [Zürich Tourism — Uetliberg](https://www.zuerich.com/en/visit/nature/uetliberg-zurichs-very-own-mountain)

### wildlife

- **choose · 케이프타운 — 보류**
  - 원안 `make_time` / catalog `make_time`. 케이프타운의 다른 일정과 함께 간다는 이유는 하향 근거가 아니다. 볼더스 비치와 장소가 명시되지 않은 계절 고래 관찰을 나누고, 특히 고래 관찰 지점이 scope 안인지 확인해야 한다. 대표 케언스 하나만으로 경계를 확정하기 어렵다.

- **make_time · 싱가포르 — 수정 제안**
  - 원안 `make_time` / catalog `make_time`. 싱가포르 make_time 제안은 유지할 수 있지만, 일반 동물원은 모두 if_there라는 판정 문장을 고쳐야 한다. 나이트 사파리는 별도 관람 프로그램이 확인된다. 자연 상태 여부·시설 유형을 곧바로 등급으로 치환하지 않는다. [Mandai — Night Safari itinerary](https://www.mandai.com/en/plan-your-visit/itinerary/night-safari-too-wild-to-miss.html)

### beach

- **choose · 리우데자네이루 — 수정 제안**
  - 원안 `choose` / catalog `choose`. 리우 choose 제안은 유지하되, 수질·모래·수영만 강조하는 판정 문장에 해변에서 머무는 문화·휴식 경험을 포함해야 한다. 수영 가능성이나 안전까지 확인한 것은 아니다.

- **make_time · 니스 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 니스가 자갈 해변이라는 사실만으로 낮추지 않은 방향은 타당하다. make_time의 반나절 조건은 삭제하고 일부러 시간을 내는지를 본다. 수영 가능 시기·구역은 별도 미확인이다.

### spa

- **choose · 이스탄불 — 보류**
  - 원안 `make_time` / catalog `make_time`. 이스탄불 하맘만으로 도시를 고르지 않는다는 단정은 그 경험의 선호자를 고려하지 않는다. 역사적 하맘의 구체적 목욕 경험을 부다페스트 대표와 비교해야 한다.

- **make_time · 도쿄 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 도쿄 온천은 하코네로 간다는 이유로 if_there에 두면 범위 안의 독립적인 스파 일정을 놓친다. 도쿄 공식 관광 안내에 분쿄구 Spa LaQua가 있다. 이를 구체 사례로 make_time 재검토하되 센토 전체를 같은 등급으로 올리지는 않는다. [GO TOKYO — Spa LaQua](https://www.gotokyo.org/en/spot/51/)

### resort

- **choose · 라스베이거스 — 보류**
  - 원안 `make_time` / catalog `choose`. 라스베이거스 방문객이 쇼·카지노를 찾는다는 설명만으로 리조트 휴식의 가치를 낮출 수 없다. 실제 숙박·수영장 휴식 경험을 비교해야 한다. 객실·시설 접근 조건은 미확인이다.

- **make_time · 방콕 — 수정 제안**
  - 원안 `make_time` / catalog `make_time`. 방콕 호캉스 make_time은 유지 후보지만 가격 대비 고급이라는 이유는 제거한다. 가격을 이번 조사 범위에 넣지 않기로 했으므로 휴식 경험 자체로 설명해야 한다. 대표 spa의 방콕 가격·품질 표현도 같은 원칙으로 수정한다.

### streets

- **choose · 포르투 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 포르투가 작은 도시여도 골목 걷기가 방문 동기가 될 수 있다는 판정 방향은 일관된다. 히베이라·언덕 골목의 경로와 경험은 출처 미대조다.

- **make_time · 프랑크푸르트 — 수정 제안**
  - 원안 `if_there` / catalog `make_time`. 프랑크푸르트 구시가가 작다는 이유만으로 if_there가 되지 않는다. 골목 걷기만을 위해 잡는 구체적 동선이 있는지 확인해 make_time과 비교한다. 아직 경로 사실 검수는 하지 않았다.

### architecture

- **choose · 시드니 — 수정 제안**
  - 원안 `make_time` / catalog `choose`. 시드니를 건축 묶음이 적다는 이유로 내리지 않는다. 오페라 하우스에는 건축을 주제로 한 별도 투어가 있다. 단일 핵심 건축 경험도 choose 후보가 될 수 있도록 판정 문장을 바꾸고 재비교한다. 투어 존재만으로 choose가 확정되지는 않는다. [Sydney Opera House — Architectural Tour](https://www.sydneyoperahouse.com/tours/architectural-tour)

- **make_time · 로스앤젤레스 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 로스앤젤레스에는 건축을 주제로 한 Getty Center 투어가 있어 건축 자체가 목적이 되는 경우가 드물다는 이유는 부적절하다. 흩어진 위치·짧은 소요 시간을 하향 기준으로 쓰지 말고 make_time으로 비교한다. [Getty — Center Architecture Tour](https://www.getty.edu/calendar/center-architecture-tour/)

### nightview

- **choose · 부다페스트 — 보류**
  - 원안 `make_time` / catalog `make_time`. 부다페스트 야경이 온천·건축과 묶인다는 것은 choose 하향 근거가 아니다. 야경 선호자의 방문 동기와 구체적 관람 경험을 홍콩·뉴욕 사례와 비교해야 한다.

- **make_time · 로마 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 로마 야간 산책을 별도 일정으로 보는 방향은 가능하다. 흔한 저녁 일정이라는 말 대신 일부러 찾는 야간 관람 동선을 적고, 조명·접근 가능 시간은 미확인으로 남긴다.

### street

- **choose · 오사카 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 오사카의 길거리 음식 choose는 잠정 유지한다. 음식 이름만으로 street와 dining을 나누지 말고 노점·테이크아웃·먹으며 걷는 경험인지 명시한다. 맛집 수나 존재만으로 등급을 확정하지 않는다.

- **make_time · 파리 — 보류**
  - 원안 `if_there` / catalog `if_there`. 파리 미식의 중심이 식당이라는 설명은 길거리 음식이 make_time인지 판단하지 못한다. 특정 시장·노점 방문 경험을 평가해야 한다. 시장이 있다는 것만으로 상향하지도 않는다.

### dining

- **choose · 볼로냐 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 볼로냐가 작아도 지역 요리가 방문 동기가 될 수 있다는 판정 방향은 일관된다. 대표 식사 경험의 출처·차별성은 미대조다.

- **make_time · 암스테르담 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 암스테르담 라이스타펠은 공식 관광 안내에서 식당을 골라 즐기는 구체적 식사 경험으로 소개된다. 도시 미식 전체가 부수적이라는 이유로 낮추지 말고 make_time 후보로 비교한다. [I amsterdam — Indonesian restaurants](https://www.iamsterdam.com/en/see-and-do/restaurant-and-bars/best-indonesian-restaurants-in-amsterdam)

### cafe

- **choose · 파리 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 파리 카페·파티스리를 선호자의 방문 동기로 보는 제안은 유지한다. 카페 소비와 단순 거리 산책의 근거를 분리한다. 개별 경험의 출처 대조는 하지 않았다.

- **make_time · 런던 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 런던 애프터눈 티의 예약형 경험은 확인된다. 차·디저트를 먹는 경험을 cafe로 우선 설명하고, 전통이라는 수식어만으로 traditional의 근거도 복제하지 않는다. 별도의 문화 학습·참여 요소가 있을 때 분류를 다시 본다. [Visit London — Afternoon tea](https://www.visitlondon.com/things-to-do/food-and-drink/afternoon-tea)

### drinks

- **choose · 케이프타운 — 보류**
  - 원안 `make_time` / catalog `make_time`. 케이프타운 범위에 콘스탄시아가 남아 있고 공식 관광청은 와인 지역·시음 경험을 소개한다. 스텔렌보스 제외만으로 choose를 내릴 수 없다. 콘스탄시아 자체의 경험을 포르투 등과 비교해야 한다. [Cape Town Tourism — Constantia guide](https://www.capetown.travel/travel-like-a-local-your-neighbourhood-guide-to-constantia/)

- **make_time · 뉴욕 — 수정 제안**
  - 원안 `make_time` / catalog `choose`. 뉴욕 경계 방향은 이미 above라 제안값이 make_time이다. 오타 수정은 필요 없다. 다만 술 자체로 뉴욕을 고르지 않는다는 단정과 현재 choose는 높다는 문장은 지우거나 추가 근거를 붙여야 한다. 별도 바 일정은 make_time의 하한만 지지하며 choose를 배제하지 못한다.

### heritage

- **choose · 카이로 — 수정 제안**
  - 원안 `choose` / catalog `choose`. 카이로 choose 제안은 유지하되 기자를 범위에 넣었기 때문에 choose라는 순환 설명을 고친다. 범위 포함은 평가 자격이고, 피라미드 관람 경험의 성격이 판정 이유다. 여러 유적이 있어야 한다는 개수 조건도 제거한다.

- **make_time · 뉴욕 — 유지 제안**
  - 원안 `make_time` / catalog `if_there`. 뉴욕 자유의 여신상·엘리스섬 make_time은 역사 관람 경험으로 비교할 수 있다. 반나절 걸린다는 사실이 아닌 역사 전시·장소 방문의 목적을 이유로 쓴다. 운영·입장 조건은 미확인이다.

### museums

- **choose · 도하 — 보류**
  - 원안 `make_time` / catalog `choose`. 도하의 컬렉션 수가 적다는 표현은 모호하다. MIA는 여러 지역·시대에 걸친 컬렉션을 공개한다. 박물관 수와 컬렉션 깊이를 혼동하지 말고 단일 기관으로도 choose가 가능한지 비교한다. 공식 소개만으로 choose를 확정하지 않는다. [Museum of Islamic Art — Collection](https://mia.org.qa/en/about-us/collection/)

- **make_time · 프라하 — 수정 제안**
  - 원안 `if_there` / catalog `none`. 프라하 국립미술관은 여러 건물·컬렉션을 갖춘 별도 관람 대상이다. 여행의 중심이 구시가라는 이유로 if_there에 두지 말고 make_time 후보로 비교한다. 모든 건물·전시가 현재 동시에 운영된다는 뜻은 아니다. [National Gallery Prague — 10 reasons to visit](https://www.ngprague.cz/en/about/10-reasons-to-visit)

### traditional

- **choose · 부에노스아이레스 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 부에노스아이레스 탱고 공연·밀롱가 제안은 유지한다. 관람과 실제 참여를 구분하고, 대표 교토의 게이샤 관찰도 예약 가능한 문화 관람인지 단순 길거리 목격인지 명확히 해야 한다. 일정·참여 조건은 미확인이다.

- **make_time · 방콕 — 보류**
  - 원안 `make_time` / catalog `make_time`. 방콕의 실제 요리 교실은 태국 관광청 자료로 확인된다. 그러나 체험이 있다는 사실은 traditional 분류를 결정하지 않는다. 조리 체험과 지역 전통·문화 학습의 기준을 먼저 정해야 한다. [Tourism Authority of Thailand — Blue Elephant Bangkok](https://www.tourismthailand.org/Restaurant/blue-elephant-bangkok)

### water

- **choose · 푸껫 — 보류**
  - 원안 `make_time` / catalog `make_time`. 푸껫을 투어 의존·범위 미확인 때문에 낮추면 투어를 쓰는 케언스와 일관되지 않는다. 현재 scope에는 이미 팡아만·피피 섬·라차 섬 당일 투어가 포함되어 있어 원안의 범위 미확인 설명은 갱신이 필요하다. 구체적 활동 지점과 계절·운영을 확인하고, 확인 전에는 판정 보류로 남긴다. 미확인을 낮은 등급으로 표현하지 않는다.

- **make_time · 안탈리아 — 보류**
  - 원안 `if_there` / catalog `make_time`. 안탈리아 항구 관광 보트는 참여형 수상 활동과 다른 경험일 수 있다. 보트 경험을 water에 포함할지 먼저 정하고, 포함하지 않는다면 실제 수상 활동 사례로 교체한다. 근교에 의존한다는 사실은 미검증이다.

### winter

- **choose · 밴쿠버 — 보류**
  - 원안 `make_time` / catalog `make_time`. 밴쿠버보다 휘슬러를 고른다는 경쟁지 비교는 절대 기준과 맞지 않는다. 범위 안 스키장의 코스·활동 경험으로 판정하고, 휘슬러·니세코가 빠지는 범위 규칙을 다른 대표에도 동일하게 적용한다.

- **make_time · 삿포로 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 삿포로 테이네를 범위 안 당일 스키 경험으로 비교하는 제안은 유지한다. 실제 운영 월·시즌은 별도 확인해야 하며 니세코 경험을 합치지 않는다.

### extreme

- **choose · 케이프타운 — 보류**
  - 원안 `make_time` / catalog `make_time`. 케이프타운에서 이것만으로 도시를 고르지 않는다는 이유가 부족하다. 라이언스 헤드로 적힌 이륙 지점·허용 조건부터 확인하고 대표 퀸스타운과 비교한다. 퀸스타운 제트보트는 water와의 분류·중복 근거도 확인한다.

- **make_time · 싱가포르 — 보류**
  - 원안 `if_there` / catalog `if_there`. 싱가포르의 시설형 체험이라는 이유만으로 if_there가 되지 않는다. 실제 짚라인 등 활동의 경험·예약 동기를 비교해야 한다. 도시형 시설을 낮추는 숨은 기준은 제거한다.

### themepark

- **choose · 싱가포르 — 보류**
  - 원안 `make_time` / catalog `make_time`. 싱가포르에 파크가 하나라는 것은 하향의 충분한 이유가 아니다. 대표 판정 문장이 허용하는 단일 핵심 테마파크와 일관되게 비교해야 한다. 규모·이용 경험의 사실 검수는 남아 있다.

- **make_time · 런던 — 수정 제안**
  - 원안 `make_time` / catalog `make_time`. 런던 Leavesden 운영사는 스튜디오 투어가 테마파크가 아니며 놀이기구도 없다고 명시한다. 현재 themepark 기준에서는 이 경계 사례를 제외하거나 교체하는 쪽을 제안한다. 다른 세부로 자동 이동하거나 catalog 런던 등급을 내리지는 않는다. [Warner Bros. Studio Tour — Tour experience FAQ](https://www.wbstudiotour.co.uk/de/faqs/tour-experience-faqs/)

### markets

- **choose · 방콕 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 방콕 짜뚜짝 제안은 잠정 유지한다. 대형이라는 규모보다 물건을 둘러보고 거래하는 독립적인 경험을 이유로 적는다. 주말·운영 정보는 최신 확인이 필요하다.

- **make_time · 피렌체 — 유지 제안**
  - 원안 `make_time` / catalog `if_there`. 피렌체 공식 안내에서 산 로렌초 야외 시장의 의류·가죽·기념품과 실내 중앙시장의 음식을 구분할 수 있다. make_time 사례는 야외 시장으로 명확히 쓴다. 가죽의 원산지·품질이나 개별 점포 운영을 보장하지 않는다. [Feel Florence — Piazza del Mercato Centrale](https://www.feelflorence.it/it/punti-di-interesse/piazza-del-mercato-centrale)

### brands

- **choose · 홍콩 — 보류**
  - 원안 `choose` / catalog `make_time`. 홍콩 면세·가격 이점으로 choose를 제안하는 근거는 이번에 검증하지 않았다. 가격을 판정 이유에서 빼고 범위 안 브랜드·매장 탐색 경험으로 다시 비교한다. 현재 make_time이 낮다는 결론은 보류한다.

- **make_time · 바르셀로나 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 바르셀로나 공식 관광 안내는 독립적인 쇼핑 경로와 매장을 소개한다. 건축 관람 중 들른다는 단정으로 if_there에 두지 말고 make_time 후보로 비교한다. 쇼핑 안내가 있다는 사실만으로 등급이 확정되지는 않는다. [Barcelona Turisme — Best shops](https://bid.barcelonaturisme.com/wv3/en/enjoy/143/barcelona-s-best-shops.html)

### bars

- **choose · 부다페스트 — 보류**
  - 원안 `make_time` / catalog `make_time`. 부다페스트 폐허 바만으로 도시를 고르지 않는다는 단정에 근거가 없다. 밤문화 선호자의 독립적인 방문 동기를 다른 대표와 비교해야 한다.

- **make_time · 로마 — 보류**
  - 원안 `if_there` / catalog `if_there`. 로마에서 저녁 식사 뒤 바에 간다는 순서가 부수 경험임을 뜻하지 않는다. 일부러 찾아가는 구체적 바·밤 일정을 확인해 make_time과 비교한다.

### livebar

- **choose · 리우데자네이루 — 보류**
  - 원안 `make_time` / catalog `make_time`. 리우 삼바 바를 해변·카니발과 함께 즐긴다는 이유로 낮추지 않는다. 라이브 음악 선호자의 경험을 뉴욕·더블린과 비교해야 한다. 실제 공연·참여 조건은 미확인이다.

- **make_time · 도쿄 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 도쿄 재즈 클럽·라이브 하우스를 일부러 찾는 경험으로 설명하는 방향은 유지한다. 공연장이 많다는 수량만으로 판정하지 말고 구체적 공연 경험을 적는다. 개별 공연 일정은 미확인이다.

### travelers

- **choose · 방콕 — 보류**
  - 원안 `make_time` / catalog `make_time`. 대표 사례가 0개여서 방콕을 choose 아래에 둘 비교 기준 자체가 없다. 카오산 거리의 존재만으로 교류 경험·동기를 추정하지 않는다. 적절한 대표를 못 찾으면 미완성 상태를 유지한다.

- **make_time · 푸껫 — 보류**
  - 원안 `if_there` / catalog `make_time`. 푸껫에 바가 있어도 여행자 교류가 자동 성립하지 않고, bars에 반영했다고 교류 경험이 사라지는 것도 아니다. 실제 모임·호스트 진행·참여 구조를 확인한다. 대표 방콕의 펍 크롤도 같은 기준으로 재검수한다.

### festival

- **choose · 삿포로 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 삿포로 눈축제를 방문 동기로 보는 제안은 잠정 유지한다. 개최 연도·월·관람 가능성을 별도 확인해야 한다. 대표와 경계의 시즌 검수가 완료된 것은 아니다.

- **make_time · 부산 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 부산을 일반 여행자에게 제한적이라는 이유로 낮추면 축제 선호자를 전제로 한 질문과 맞지 않는다. 불꽃축제의 공식 개최 기록을 확인했으므로 make_time 이상 후보로 다시 비교한다. 확인한 자료는 2025년 자료여서 2026년 날짜·월 확정에는 쓰지 않는다. 암스테르담 King’s Day 대표도 choose와 재비교할 필요가 있다. [Visit Busan — 불꽃축제 기록](https://www.visitbusan.net/schedule/view.do?boardId=BBS_0000010&dataSid=4853&menuCd=DOM_000000304003000000)

### sports

- **choose · 뉴욕 — 수정 제안**
  - 원안 `make_time` / catalog `choose`. 뉴욕을 구단 경기만으로 낮추면 scope 안 퀸스의 US Open을 놓친다. 그랜드슬램 대회 관람을 런던의 윔블던과 같은 질문으로 비교해 choose 후보로 재검토한다. 대회가 열리는 시기·티켓 확보는 별도 조건이다. [USTA — About](https://careers.usta.com/about/)

- **make_time · 로마 — 유지 제안**
  - 원안 `make_time` / catalog `make_time`. 로마 세리에 A를 별도 관람 일정으로 보는 제안은 유지한다. 흔한 일정이라는 말 대신 실제 관람 경험을 적는다. 경기일·입장 조건은 미확인이다. 대표 도쿄 스모도 선호자에게 choose인지 재비교할 여지가 있다.

### concert

- **choose · 서울 — 유지 제안**
  - 원안 `choose` / catalog `choose`. 서울 공연을 팬의 방문 동기로 본 것은 판정 질문과 맞는다. 날짜 의존은 등급 하향 근거가 아니라 시즌·관람 가능성 조건으로 분리한다. 개별 콘서트 개최·예매는 확인하지 않았다.

- **make_time · 로마 — 수정 제안**
  - 원안 `if_there` / catalog `if_there`. 로마 여름 오페라를 시즌 한정이라 if_there에 두는 것은 서울 사례와 모순된다. 시즌 중 일부러 관람하면 make_time 후보가 된다. 공식 시즌에는 여러 공연장이 있어 카라칼라 욕장이라는 장소 표현을 개별 공연별로 다시 확인해야 한다. [Teatro dell’Opera di Roma — Season](https://www.operaroma.it/en/stagione/)

## 대표 사례와 남은 빈칸

대표 2개를 채우지 못한 칸은 wildlife·spa·winter·extreme의 choose와 travelers의 make_time이다. travelers/choose는 0개다. 빈칸을 채우기 위해 약한 사례를 올리지 않는다. 이 여섯 행은 경계 사례를 읽었다는 이유만으로 승인할 수 없다.

대표 사례에도 같은 규칙을 적용한다. 퀸스타운 산행의 범위 수정 외에 방콕 스파의 가격·품질 표현, 교토 전통 체험의 관람·참여 구분, 케언스 투어와 푸껫 투어의 대칭성, 런던 윔블던과 뉴욕 US Open, 도쿄 스모·암스테르담 King’s Day의 상위 경계를 추가로 비교해야 한다.

`if_there`의 세부별 판정 문장·대표 사례는 아직 없고, `none`과 미조사의 구분도 구현 전이다. 따라서 상위 두 등급의 논리 검수만으로 103곳 전체 재판정 준비가 끝났다고 보지 않는다.

## 공식 출처와 확인 범위

- [DOC — Roys Peak Track](https://www.doc.govt.nz/parks-and-recreation/places-to-go/otago/places/wanaka-area/things-to-do/roys-peak-track) — 공식 검색 결과: 와나카 지역·출발 도로. 퀸스타운 catalog 범위 밖임을 판별하는 데 사용.
- [DOC — Ben Lomond Track](https://www.doc.govt.nz/ben-lomond-track) — 본문: 퀸스타운 출발·산행 및 겨울 조건. choose 등급 자체의 증명은 아님.
- [Zürich Tourism — Uetliberg](https://www.zuerich.com/en/visit/nature/uetliberg-zurichs-very-own-mountain) — 공식 검색 결과: Albisgüetli·Triemli 쪽 산행 접근로. 범위 밖 연장 코스는 근거에서 제외.
- [Mandai — Night Safari itinerary](https://www.mandai.com/en/plan-your-visit/itinerary/night-safari-too-wild-to-miss.html) — 공식 검색 결과: 별도 야간 관람 동선·프로그램.
- [Sydney Opera House — Architectural Tour](https://www.sydneyoperahouse.com/tours/architectural-tour) — 공식 검색 결과: 건축을 주제로 한 투어. 단일 건축 경험의 목적성을 확인.
- [Getty — Center Architecture Tour](https://www.getty.edu/calendar/center-architecture-tour/) — 공식 검색 결과: 건축 주제 투어. 도시 전체 등급은 별도 판단.
- [Museum of Islamic Art — Collection](https://mia.org.qa/en/about-us/collection/) — 공식 검색 결과: 여러 지역·시대의 컬렉션. 박물관 수와 컬렉션 범위를 구분.
- [National Gallery Prague — 10 reasons to visit](https://www.ngprague.cz/en/about/10-reasons-to-visit) — 본문: 여러 건물과 컬렉션. 개별 전시의 현재 운영 여부는 미확인.
- [Warner Bros. Studio Tour — Tour experience FAQ](https://www.wbstudiotour.co.uk/de/faqs/tour-experience-faqs/) — 본문: 운영사가 테마파크가 아니고 놀이기구가 없다고 설명. 스튜디오·세트 관람 경험.
- [Cape Town Tourism — Constantia guide](https://www.capetown.travel/travel-like-a-local-your-neighbourhood-guide-to-constantia/) — 공식 검색 결과: 콘스탄시아의 와인 관광. 오래된 안내여서 현재 운영 수·가격에는 사용하지 않음.
- [I amsterdam — Indonesian restaurants](https://www.iamsterdam.com/en/see-and-do/restaurant-and-bars/best-indonesian-restaurants-in-amsterdam) — 공식 검색 결과: 라이스타펠 식사 경험. 개별 식당 예약·운영은 미확인.
- [Barcelona Turisme — Best shops](https://bid.barcelonaturisme.com/wv3/en/enjoy/143/barcelona-s-best-shops.html) — 공식 검색 결과: 쇼핑 경로·매장 안내. 가격·면세 조건 검증 아님.
- [Feel Florence — Piazza del Mercato Centrale](https://www.feelflorence.it/it/punti-di-interesse/piazza-del-mercato-centrale) — 공식 검색 결과: 실내 음식 시장과 야외 의류·가죽·기념품 시장 구분.
- [Visit Busan — 불꽃축제 기록](https://www.visitbusan.net/schedule/view.do?boardId=BBS_0000010&dataSid=4853&menuCd=DOM_000000304003000000) — 공식 검색 결과: 2025년 개최 기록. 2026년 일정 근거로 쓰지 않음.
- [Teatro dell’Opera di Roma — Season](https://www.operaroma.it/en/stagione/) — 본문: 시즌·공연장별 목록. 여름 오페라를 모두 카라칼라 욕장으로 단정할 수 없음.
- [USTA — About](https://careers.usta.com/about/) — 공식 검색 결과: US Open의 Flushing Meadows, Queens 위치. catalog 뉴욕 범위 안 대회 경험을 확인.
- [Visit London — Afternoon tea](https://www.visitlondon.com/things-to-do/food-and-drink/afternoon-tea) — 공식 검색 결과: 장소를 골라 예약하는 애프터눈 티 경험.
- [Tourism Authority of Thailand — Blue Elephant Bangkok](https://www.tourismthailand.org/Restaurant/blue-elephant-bangkok) — 공식 검색 결과: 방콕의 참여형 요리 교실. traditional 분류 자체의 근거는 아님.
- [GO TOKYO — Spa LaQua](https://www.gotokyo.org/en/spot/51/) — 공식 검색 결과: 분쿄구 스파·목욕 시설. 가격·현재 운영시간은 미검증.

## 재현 정보

- 검수 전 anchors SHA-256: `e7bef7dbb4725bae02d00fa39eb7d18d2c442aa659b8d3c882ddeb351a5d4cf2`.
- 범위 오류 수정 후 anchors SHA-256: `190ff39c1f660eac70233e3c7b1ddff7d7f370e8ce5e1d85574b8a9565e5a246`.
- 변경하지 않은 catalog SHA-256: `d0d35b1d50a16d303fa2cd06de863064ba009423bee532b43d97011a9ced6147`.
- 모든 행의 status는 draft다. 모델 검수 기록과 사람 승인 상태를 분리했다.

## 실행한 검사

- `python3 scripts/render_grade_anchors.py`: 통과, 기준표 재생성. 원본과 다른 등급 제안은 계속 14건이며 자동 반영하지 않았다.
- `python3 scripts/check_destination_draft.py`: 103곳·2,987칸 구조 검사 통과. 출시 검수 완료 0곳, 시즌 미확인 255칸이라는 기존 상태를 확인했다.
- `python3 -m unittest discover -s scripts -p 'test_*draft.py'`: 기존 자료 검사 테스트 4개 통과.
- `python3 scripts/test_grade_anchors.py`: 회귀 테스트 3개 통과. 경계 방향, 뉴욕 술 make_time, 잘못된 입력 9종, 승인 표시, catalog 범위 반영을 검사했다.
- `git diff --check`: 통과. 새 파일은 별도로 행 끝 공백·로컬 링크·56건 누락 여부를 검사했다.
- `xcodebuild -quiet -project TripDNA.xcodeproj -scheme TripDNA -destination 'generic/platform=iOS Simulator' build`: 최초 제한 환경에서는 DerivedData 쓰기·Simulator 서비스 접근이 막혀 실패했다. 권한을 허용한 재실행은 종료 코드 0으로 통과했다.
- `graphify update .`: 종료 코드 0으로 갱신. 이번에 수정하지 않은 `AppDependencies.swift`·`LedgerServices.swift`에 AST 부분 추출 경고가 있었고, 커뮤니티 이름 일부는 허브 기준으로 재명명되었다. Swift 컴파일 실패를 뜻하지 않으며 빌드는 별도로 통과했다.
- Swift 앱 코드 변경은 없어 XCTest·UI 테스트는 실행하지 않았다. 사실·운영·시즌 전수 검증과 사람 승인은 별도로 남아 있다.
