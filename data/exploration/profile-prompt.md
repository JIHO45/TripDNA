# Lightweight destination profile — authoring instructions (v2, 2026-10-06)

You are drafting short destination profiles for a travel recommendation app.
A small model will read all profiles at once to choose destinations for a user
and to answer follow-up questions. Write from your own knowledge. Do not browse
the web and do not read other files in this repository.

## Output

Write one JSON file: an object keyed by destination `id`, in the order given
below. Each value has exactly these fields:

```json
{
  "scope": "1-2 sentences: the area this profile covers and what is outside it.",
  "experiences": [
    {"category": "<category id>", "what": "short phrase", "places": ["Place", "Place"]}
  ],
  "constraints": ["One sentence each."]
}
```

- All text in English. Place names in their common English form.
- `scope`: follow the editorial scope note given for the destination. Do not widen it.
  The notes were written as work instructions, so read them this way: a place the
  note says to verify separately, add later, or not merge is OUTSIDE the scope of
  this draft. A note that says to "start with" an area names where coverage begins;
  it does not exclude other well-known experiences inside the same city.
- `experiences`: at most 6 entries, only ones you are sure of. Fewer is fine. Do
  not repeat the same place under several categories to add entries. `category` must be one of:
  `city_exploration`, `nature_scenery`, `food`, `relaxation`, `culture_history`,
  `activities`, `shopping`, `nightlife`, `meeting_people`.
  Only include a category when the destination is genuinely known for it and you
  can name 1 to 3 real, well-known places inside the scope. `what` must say what
  one actually does or sees there, specific to this destination ("night food stalls
  along a riverside market", not "local food"). Do not fill every
  category. Do not use `meeting_people` for nightlife or for travelling with
  companions; use it only for well-known daytime group formats a solo traveller
  can join, and leave it out when unsure.
- `constraints`: 0 to 4 entries. Only durable conditions that would change
  whether to recommend the destination or an experience: a strong seasonal
  limitation, a boat or flight being required, an overnight stay being required,
  a long transfer from the base. Do not write booking or reservation requirements.
  Do not say a means of transport is the only one unless that is certain.
  State the condition and what it applies to. Leave the list empty when unsure.

## Do not include

- Prices, opening hours, timetables, current availability, events with dates.
- Safety guarantees, crowd levels, "friendly locals", rankings or scores.
- Anything you are not confident is true and stable. Omit instead of guessing.
- Advice addressed to a traveller. Describe the destination only.

Keep each profile under about 150 words.

## Destinations (id | display name | country | editorial scope note)

fr-paris | 파리 | FR | 파리 도심부터 시작. 베르사유 등 근교 방문은 별도 근거로 다룬다.
jp-tokyo | 도쿄 | JP | 도심 구역부터 시작. 도쿄도 도서 지역·후지산을 합치지 않는다.
us-new-york | 뉴욕 | US | 뉴욕시 구역 단위. 뉴욕주 전체를 합치지 않는다.
sg-singapore | 싱가포르 | SG | 동네별 경험을 나누고 센토사는 이동·입장 조건을 따로 검수한다.
ae-dubai | 두바이 | AE | 도시 내 경험부터 시작. 사막 체험은 출발점·이동·운영 조건을 따로 검수한다.
tr-istanbul | 이스탄불 | TR | 도시 구역별 경험과 해협 이동을 구분. 카파도키아를 합치지 않는다.
tw-taipei | 타이베이 | TW | 타이베이 도심부터 시작. 지우펀 등 다른 행정구역은 별도 이동 검수 후 포함한다.
jp-kyoto | 교토 | JP | 교토시의 문화 경험부터 시작. 교토부 전체·오사카를 합치지 않는다.
th-bangkok | 방콕 | TH | 도심 시장·문화 경험부터 시작. 먼 근교 상품을 자동 포함하지 않는다.
pt-lisbon | 리스본 | PT | 리스본 도심부터 시작. 신트라·카스카이스를 묵시적으로 합치지 않는다.
au-sydney | 시드니 | AU | 도심·항만·해변부터 시작. 국립공원 등 외곽 자연 경험은 이동 검수 후 포함한다.
th-phuket-island | 푸껫 | TH | 앱에서는 푸껫 본섬을 지역 단위로 다룬다. 초기 경험 자료는 빠통·까따·까론 해변과 올드타운으로 제한하며 본섬 밖 섬·보트 투어는 제외한다.
mx-mexico-city | 멕시코시티 | MX | 도시 내 구역별 경험부터 시작. 근교 유적은 이동 검수 후 포함한다.
ca-vancouver | 밴쿠버 | CA | 스탠리파크 등 도시 자연부터 검수. 노스쇼어는 이동 확인 후 추가하고 휘슬러를 기본 포함하지 않는다.
us-honolulu | 호놀룰루 | US | 도심·와이키키 중심. 오아후 전체와 다른 하와이 섬을 자동 포함하지 않는다.
in-delhi | 델리 | IN | 델리 도시 체류권의 문화 경험부터 시작. 다른 주의 명소는 이동 검수 전 포함하지 않는다.
ma-marrakesh | 마라케시 | MA | 도시 문화·시장 경험 중심. 사하라 숙박 여행을 기본 범위에서 제외한다.
za-cape-town | 케이프타운 | ZA | 도시와 테이블마운틴 등 근접 경험부터 검수. 사파리·가든루트를 합치지 않는다.
au-cairns | 케언스 | AU | 케언스 체류와 케언스 출항 코스를 구분. 리프 전체·다일 선상 숙박을 기본 포함하지 않는다.
nz-queenstown | 퀸스타운 | NZ | 도시 근처 산책·호수 경험부터 검수. 밀퍼드사운드·다일 트레킹은 기본 범위에서 제외한다.
