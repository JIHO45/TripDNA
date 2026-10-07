> **문서 체계 v1 기록 — 현재 적용 문서 아님.** 2026-10-07부터 [../README.md](../README.md)의 현재 버전을 따른다. 아래 본문·실험 계획·결과는 당시 기록으로 보존한다. 본문에 적힌 설계/스키마 버전은 문서 체계 버전과 별개다.

# D2 후보 목록과 파일럿 선정안

작성 시작: 2026-09-30. 갱신: 2026-10-05(목록 v4, 도쿄·밴쿠버 자료 연결). **상태: 사용자의 D3 착수 지시에 따라 후보 목록 확정. D3 자료 작성 중이며 사람 검수는 미완료다.**
목록 원본은 [후보 JSON](../../data/planning/destination-candidates.json)이다. 이 문서 아래 목록은 같은 JSON을 사람이 읽을 수 있게 옮긴 것이다. 수정 시 둘을 맞추고 [목록 검사](../../scripts/check_destination_candidates.py)를 실행한다.

## 구성 원칙

후보는 **출처 기반 원본 목록 + 이유가 명시된 보충 후보 + 검증 목적의 파일럿**으로 구성한다. v1에서 편집자가 100곳을 직접 고르던 방식은 폐기했다. 포함 근거를 재현할 수 없었기 때문이다.

1. **원본 목록:** Euromonitor International의 Top 100 City Destinations Index 2025(2025-12-05 발표)를 그대로 쓴다. 원문 이름·연도·순위·출처를 보존한다.
2. **보충 후보:** [TODO](../v1/progress.md)의 D2에 이미 적힌 시험 요구와 연결될 때만 추가한다. 각 보충 후보에는 연결된 요구, 보충 이유, 원본 목록으로 대체 가능한지 확인했는지를 기록한다. 원본 목록에 없다는 이유만으로 추가하지 않으며, 100곳을 맞추려고 원본 도시를 빼지 않는다.
3. **파일럿:** 원본과 보충 후보 가운데 먼저 자료를 만들 **여행지 후보 20곳**이다. 검증하려는 질문과 권역 분산으로 고른다. 푸껫은 지역 단위로 다루므로 ‘도시 20곳’으로 부르지 않는다.

실제 제작·운영 범위는 D3 검수와 실험 결과로 좁힌다. 목록 확정은 전체 제작이나 출시 승인이 아니며, 전체 제작은 E7 이후다.

## 원본 목록의 성격과 근거 수준

이 지수는 사람들이 가장 좋아하는 도시 순위가 아니다. [Euromonitor 설명](https://www.euromonitor.com/article/top-100-city-destinations-index-2025-driving-growth-and-innovation)에 따르면 경제·비즈니스, 관광 성과, 인프라, 관광 정책·매력, 보건·안전, 지속가능성의 6개 분야에서 50개 이상 지표로 산출한 도시 매력도 점수다. **후보를 확보하는 근거로만 쓰고, 개인의 여행 만족도나 추천 점수로 쓰지 않는다.** 추천은 사용자 선호와 검수된 경험으로 판단한다. 순위 기준선은 E1의 선택 사항이다. 보충 후보에 임의 순위를 붙이거나 일부 비교에서만 빼면 비교 조건이 달라지므로, 우선 같은 20곳에서 단순 규칙과 LLM을 비교한다. 순위 기준선을 추가하더라도 모든 비교 대상에 같은 후보 범위를 적용한다.

순위의 근거 수준은 JSON의 `rank_evidence`로 구분한다. 전체 목록은 공식 원문이 아니라 **언론 재인용**이다. 공식 보고서는 유료라 원문 대조(`full_list_official_verification`)는 시작하지 않았다.

- `official`(1~5위): [Euromonitor 보도자료](https://www.euromonitor.com/newsroom/press-releases/december-2025/euromonitor-international-unveils-worlds-top-100-city-destinations-for-2025)에서 확인.
- `press_two_outlets`(6~10·13·17·18·19위): [Vacations & Travel](https://www.vacationstravel.com/top-100-city-destinations/)과 [CNN](https://www.cnn.com/2025/12/04/travel/euromonitor-international-top-city-destinations-2025)이 일치.
- `press_one_outlet`(나머지): Vacations & Travel의 전체 목록만으로 확인.

판은 2025년판으로 고정한다. 같은 판을 ‘2026 순위’로 부르는 기사도 있으므로 발행처의 판 이름을 기록한다. 새 판이 나와도 자동으로 교체하지 않고, 바꾸려면 목록 버전을 올린다.

## 범위 연결과 제외·보류 기준

순위표의 이름은 집계 단위이며, 그 이름이 도시·섬·주 중 어디를 가리키는지는 아직 확인하지 않았다(모든 원본 항목 `scope_mapping: unverified`). 예를 들어 ‘Phuket’을 푸껫 타운과 동일시하거나, 덴파사르·팔마데마요르카·무을라 등을 ‘도시가 아니다’라는 이유로 제외하지 않는다. 연결 범위는 D3에서 확인한다.

원본의 집계 범위와 앱에서 다룰 추천 단위는 별개로 기록한다. 원본 집계 범위를 끝내 확인하지 못하면 그 사실을 남기고, 앱의 추천 단위를 따로 명시한다. 추천 단위를 원본보다 좁히면(예: 섬 전체 대신 특정 지역) **원본 순위를 좁힌 범위의 순위처럼 표시하지 않는다.**

제외·보류 사유는 확인 가능한 것으로 제한한다.

- **중복:** 두 항목이 같은 범위를 가리키는 것이 확인된 경우.
- **범위 식별 불가:** 앱에서 추천할 대상 지역을 명확히 정의하고 근거를 연결할 수 없으면 후보의 추천 사용을 보류한다. 원본 순위의 집계 범위만 미확인이면 원본과 앱 범위의 동일성·순위 연결을 보류하고, 별도로 정의한 앱 자료의 검수는 진행할 수 있다.
- **근거 부족:** D3에서 검수 가능한 경험 자료를 확보하지 못한 경우.

출장 수요가 크다는 인상, 입장·이용 제한 같은 이유로는 제외하지 않는다. 입장 제한은 도시 전체인지 특정 구역인지, 누구에게 적용되는지를 출처로 확인해 도시 자료의 제약으로 기록한다. 사용자 조건과의 적합성은 추천 단계에서 판단한다. **후보 목록 자체에서 적용한 제외·보류는 없다. 실제 추천 사용 가능 여부는 별도의 D3 검수 상태로 판단한다.**

## 도시 목록의 출처와 도시 정보의 출처

순위 기사는 ‘왜 이 도시를 다루는가’의 근거일 뿐이다. ‘무엇을 할 수 있고 어떤 제약이 있는가’는 관광청·시설·교통 운영기관 자료로 D3에서 주장별로 작성·검수한다. 순위 기사의 서술을 도시 경험의 근거로 쓰지 않는다.

파일럿 20곳에는 공식 관광 기관의 출처 후보를 연결했다. `page_read`는 도구가 본문을 반환했다는 의미, `page_limited`는 페이지는 열렸으나 본문이 거의 없었다는 의미(두바이), `search_excerpt`는 검색 발췌만 확인했다는 의미(타이베이·싱가포르)다. **모두 사람의 주장별 검수 완료를 뜻하지 않는다.** 홈페이지는 조사 시작점일 뿐 가격·예약·개방 조건의 근거로 재사용할 수 없다. 추천 범위를 포함하거나 제외한 결정의 근거는 JSON의 `scope_references`에 둔다. 도시 사실 주장의 출처는 도시 파일의 `claims[].source`가 기준이며, D2 파일에 다시 등록하지 않는다.

`data/planning/`의 자료는 추천용 `data/cities/`와 분리한다. 파일럿 추천에는 D3에서 주장별로 검수한 도시 파일만 사용한다.

## 보충 후보

TODO D2의 ‘자연 여행 거점 도시 최소 4곳’ 요구와 연결해, **서로 다른 자연 경험을 비교하기 위해 3곳을 잠정 보충했다.** 원본 목록만으로 자연 거점 4곳을 확보할 수 없는지는 확인하지 않았다. 이 단계에서 확인한 것은 이번 안이 원본에서 자연 거점으로 지정한 곳이 밴쿠버뿐이라는 사실까지다.

- 케이프타운(ZA): 도시에 인접한 산·해안. 케언스(AU): 출항형 리프 체험. 퀸스타운(NZ): 산악·호수 풍경과 활동 강도의 분리. v1에서 조사한 범위안과 출처 후보를 유지했다.

원본 도시(예: 시드니)가 자연 거점으로 확인되더라도 위 경험과 같아지는 것은 아니므로, 숫자가 채워졌다는 이유만으로 보충을 철회하지 않는다. 유지 여부는 D3에서 확보한 경험 자료로 판단한다.

v1에만 있던 나머지 35곳(제주시·치앙마이·다낭·자이푸르·레이캬비크·쿠스코 등)은 TODO의 시험 요구와 연결되지 않아 이번 목록에서 뺐다. 다시 넣으려면 연결할 요구를 먼저 문서화한다.

## 편중 점검

- 원본: 동아시아 15, 동남아시아 11, 남아시아 1, 유럽 39, 서아시아 10, 아프리카 2, 북미 11, 중남미 9, 오세아니아 2. 권역은 편집용 묶음이며 이스탄불·트빌리시는 서아시아, 멕시코·도미니카공화국은 중남미, 하와이는 북미로 묶었다. 코드·권역은 정치적 지위 판단이 아니다.
- 보충: 아프리카 1, 오세아니아 2.
- 파일럿: 동아시아 3, 동남아시아 3, 남아시아 1, 유럽 2, 서아시아 2, 아프리카 2, 북미 3, 중남미 1, 오세아니아 3.
- 원본 목록은 유럽에 크게 쏠려 있고 아프리카·남아시아·오세아니아가 적다. **이 편중은 보충으로 메우지 않고 후보 풀의 한계로 기록한다.** 파일럿에서만 권역을 분산했으며, 이는 실제 수요를 대표하는 표본이 아니다. 남아시아·중남미는 파일럿이 각 1곳이라 지역 전체 품질은 판단할 수 없다. 파일럿의 목적은 자료 구조와 추천의 실패 유형 발견이며, **파일럿 결과를 원본 100곳 전체의 품질로 일반화하지 않는다.**
- `meeting_people`은 ‘사람들이 친절하다’로 채우지 않는다. D3에서 혼자 참여할 수 있는 실제 체험·운영 조건을 찾고, 자료가 없으면 해당 수요의 평가 공백으로 기록한다. 예산·동행·차량 필요도 출처 전에는 적합으로 표시하지 않는다.

## 파일럿 20곳의 선정 논리

- **같은 나라의 쌍:** 도쿄·교토, 방콕·푸껫. 도시 규모보다 실제 경험으로 구분되는지 본다. 오사카까지 동시에 넣지는 않는다.
- **경험이 넓은 대도시:** 파리·리스본·뉴욕·싱가포르. 경험이 많다는 이유로 과도하게 상위에 드는지 비교한다.
- **해변과 도시의 조합:** 호놀룰루·푸껫·시드니.
- **인상으로 배제하지 않는지:** 두바이. 출장·쇼핑 수요가 큰 도시도 실제 경험으로 판단하는지 본다.
- **자연 거점:** 밴쿠버·케언스·퀸스타운·케이프타운. 자연 선호를 고강도 활동 선호로 해석하지 않는지, 휴식과 도시 탐방을 함께 원하는 경우를 포함해 비교한다. 자료 제작 대상 선정일 뿐 당일 이동·안전·계절 적합을 검증했다는 뜻이 아니다.
- **권역 분산:** 델리(원본 목록의 유일한 남아시아 도시), 멕시코시티, 이스탄불, 마라케시, 타이베이.

v1 파일럿 중 원본 목록에 없는 치앙마이·다낭·자이푸르·레이캬비크·쿠스코는 위 보충 기준에 따라 뺐다. 이 도시들이 맡던 질문은 방콕·푸껫 쌍, 푸껫·시드니(해변과 도시), 델리(남아시아), 멕시코시티(중남미)로 옮겼다. 레이캬비크·쿠스코가 맡던 ‘도시와 광역 명소 분리’는 각 파일럿의 범위안과 푸껫의 범위 확인으로 다룬다.

## 자연 거점과 지역 분리 검토

이 단계의 결정은 **어디까지를 조사할지**다. 당일 가능 판정은 왕복 이동·대기·체험·개방/귀환 시간을 함께 확인해야 한다. 편도 시간만 배로 늘려 통과시키지 않는다. 조사 전 `overnight_required`를 추측해 채우지 않는다.

- **밴쿠버:** 도시 자연인 스탠리파크부터 시작한다. 노스쇼어 경험은 출발점·왕복 이동을 별도 검수하며 휘슬러를 기본 포함하지 않는다.
- **케언스:** 케언스에서 출항하는 리프 체험을 경험 단위로 조사한다. [지역 관광 기관의 스노클링 안내](https://tropicalnorthqueensland.org.au/things-to-do/great-barrier-reef-ocean/snorkelling/)는 여러 출항 거점을 소개하므로 다른 항구의 코스를 케언스에 귀속하지 않는다. 귀항·체험 시간·예약·날씨 제약을 D3에서 확인한다. 다일 선상 숙박은 기본 범위에서 제외한다.
- **퀸스타운:** 도심 근처 산책부터 조사한다. [피오르드랜드 안내](https://www.queenstownnz.co.nz/plan/surrounding-region/fiordland/)는 밀퍼드사운드까지 차로 약 4시간과 중간 정차 여유를 안내한다. 당일 불가능으로 단정하지 않되 ‘여유로운 근교 체험’으로 합치지 않는다. 밀퍼드사운드가 핵심 목적이면 별도 지역 후보로 검토하며, 이번 목록에는 넣지 않는다.
- **케이프타운:** 테이블마운틴을 출발점으로 근접 자연 경험을 조사한다. 접근·운영·날씨 조건을 개별 검수한다. 사파리와 가든루트 전체를 같은 도시 경험으로 합치지 않는다.

파일럿은 **여행지 후보 20곳**을 유지한다. 푸껫의 앱 추천 단위는 본섬을 대상으로 한 `region`으로 정했으며 후보 수를 늘리지 않는다. 나머지 후보의 추천 범위도 D3에서 순차 검수한다. D3에서 자연 거점 4곳의 유효 경험을 확보하지 못하면 파일럿 전에 후보를 교체하거나 지역 범위를 다시 검토하고 목록 버전을 올린다. 검수되지 않은 자연 거점을 충족 수에 넣지 않는다.

## D3 작성 순서와 완료 경계

푸껫의 앱 추천 단위를 본섬으로 정했다. 도쿄·푸껫·밴쿠버는 초안을 작성했으며, 이어서 케언스·퀸스타운·케이프타운으로 다양한 자료 형태와 범위 연결을 먼저 확인하고 나머지 14곳으로 이어간다. 도시마다 핵심 경험·제약·출처를 같은 수준으로 검수해, 자료가 더 길다는 이유로 큰 도시가 유리해지지 않게 한다. 사람이 검수하기 전에는 `reviewed`로 바꾸지 않는다.

2026-10-04 사용자가 D3를 푸껫부터 시작하도록 지시해 이 후보 목록으로 진행한다. D2 확정은 조사 대상 목록에 대한 것이며 D3의 사실 검수를 대신하지 않는다. 목록 변경은 JSON 버전·날짜·이 문서·검사 결과에 반영한다.

## D3 첫 자료: 푸껫의 추천 단위

앱 추천 ID는 `th-phuket-island`, 표시 이름은 **푸껫섬**, 종류는 `region`이다. 후보 원본 ID `th-phuket`과 분리해 연결한다. 원본 `Phuket, Thailand`의 47위는 조사 대상 선정 이력에만 남기고 앱의 푸껫섬에 붙이지 않는다. `scope_mapping: unverified`는 원본 집계 범위가 아직 미확인이라는 뜻이며, 앱 범위를 선택한 것과 모순되지 않는다.

- **범위 근거:** [태국 해양연안자원국의 푸껫주 섬 자료](https://km.dmcr.go.th/c_1/s_186/d_7567)는 본섬과 주변 섬을 구분한다. [태국 관광청의 태국어 안내](https://thai.tourismthailand.org/Destinations/Provinces/%E0%B8%A0%E0%B8%B9%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95/350)도 본섬 서해안과 주변 섬을 나눠 설명한다. 이 구분을 바탕으로 본섬만을 다루는 편집 결정을 내렸다. 행정구역 전체를 포함하는 결정이 아니다.
- **초기 경험:** 빠통·까따·까론 해변과 올드타운 건축 탐방을 초안에 담았다. 각 경험의 출처와 올드타운이 본섬에 있다는 위치 근거는 도시 파일의 주장에 연결했다. 구시가지로만 제한하면 해변 경험이 빠지고, 주 전체로 넓히면 주변 섬과 보트 이동을 함께 검수해야 하므로 본섬을 선택했다. 본섬 안에서도 검수한 경험만 사용할 수 있다.
- **제외 범위:** 본섬 밖 섬·보트 투어·팡아만·끄라비 경험. 같은 푸껫주이거나 본섬과 연결된 장소라도 자동 포함하지 않는다. 푸껫섬의 별칭에 푸껫주·푸껫 타운을 동의어로 등록하지 않는다.
- **시간·조건:** 본섬 안이라는 이유만으로 하루에 모두 방문 가능하다고 판단하지 않는다. 당일 동선·시설별 예약·비용은 아직 미상이다. 계절·현장 경고 안내 초안은 있으나 사람 검수 전이다. 해변 위치 정보로 수영 가능이나 안전을 보장하지 않는다.

[푸껫섬 자료 초안](../../data/cities/th-phuket-island.json)(data_version 4, schema_version 3)은 미검수 주장 11개와 미상 질문 5개다. 기존 버스 노선·요금 등은 상세 질문용으로 분리했고 추천 요약에서는 제외했다. `catalog`는 실재 여행지 자료라는 구분이며 사용 허가가 아니다. 현재 주장은 모두 `unreviewed` 또는 `unknown`, 사람의 `review`는 전부 `null`이다. 추천에 사용 가능한 검수 근거는 **0개**다. 요약도 검수 전 초안이다.

올드타운의 위치 주장은 ONEP 구시가지 경계 보고서의 ‘푸껫 시는 푸껫섬의 도시’라는 서술과 구시가지 경계를 결합한 것이다. 검수 전에는 올드타운 경험이 추천 범위 안에 있는지가 **미확인**이다.

자체 검수자는 출처 기반 주장과 원문 범위·번역을 확인한 뒤 본인의 검수 기록을 남긴다. 특히 올드타운 기사는 2020년 자료이므로 식당의 현재 영업·메뉴·가격을 재사용하지 않는다. 추가 조사는 추천을 바꾸는 계절·예약·범위 제약에 집중한다. 모든 교통·시설별 가격을 채울 필요는 없다. 단위를 정한 것만으로 푸껫 자료 또는 D3 전체를 완료 처리하지 않는다. 구조·참조·상태 규칙·D2 연결은 `python3 scripts/check_city_catalog.py`로 확인하며, 주장 개수는 검사 결과로 출력된다.

## D3 추가 초안 — 2026-10-05

[도쿄](../../data/cities/jp-tokyo.json)는 아사쿠사·우에노의 도시/문화 탐방과 공원 산책, [밴쿠버](../../data/cities/ca-vancouver.json)는 스탠리파크의 해안길·숲길 경험으로 시작한다. 자료 v2, 형식 v3이며 표시 ID는 각각 `jp-tokyo`, `ca-vancouver`, 종류는 `city`다. 도시 전체나 광역권을 조사했다는 뜻이 아니다. 원본 순위의 집계 범위는 미확인으로 유지한다.

두 파일은 장소 ID·추천 범위 관계와 근거를 연결하며 배편·숙박 필요 여부는 미확인으로 남겼다. `inside` 값도 출처를 바탕으로 편집한 초안일 뿐, 검수 전에는 확인된 범위로 사용하지 않는다. 주장별 출처는 도시 파일에서 관리하고 여기에 중복 등록하지 않는다. 상세 교통을 채우는 것은 완료 조건이 아니며, 사람 검수 전이므로 D3는 미완료다.

## 전체 후보 — 원본 100곳 + 보충 3곳

순위는 Euromonitor 2025년판 순위다. **파일럿**은 먼저 자료를 만들 20곳, **자연 거점**은 그중 4곳, **보충**은 원본 목록 밖에서 요구에 따라 잠정 추가한 후보다. 파일럿의 설명은 검증하려는 질문이며, 출처 후보는 조사 시작점이다.

### 동아시아 — 원본 15곳

- `jp-tokyo` 3위 도쿄 (JP, 원문 Tokyo, Japan) **파일럿** — 같은 도시를 서로 다른 경험 때문에 선호하는 사례
  범위안: 도심 구역부터 시작. 도쿄도 도서 지역·후지산을 합치지 않는다. [출처 후보](https://www.gotokyo.org/en/see-and-do/attractions/)
- `kr-seoul` 10위 서울 (KR, 원문 Seoul, South Korea)
- `jp-osaka` 11위 오사카 (JP, 원문 Osaka, Japan)
- `tw-taipei` 15위 타이베이 (TW, 원문 Taipei, Taiwan) **파일럿** — 미식·도시 탐방과 근교 이동 조건 구분
  범위안: 타이베이 도심부터 시작. 지우펀 등 다른 행정구역은 별도 이동 검수 후 포함한다. [출처 후보](https://www.travel.taipei/en)
- `hk-hong-kong` 17위 홍콩 (HK, 원문 Hong Kong SAR, China)
- `jp-kyoto` 19위 교토 (JP, 원문 Kyoto, Japan) **파일럿** — 역사·문화 경험과 혼잡 회피 조건의 충돌
  범위안: 교토시의 문화 경험부터 시작. 교토부 전체·오사카를 합치지 않는다. [출처 후보](https://kyoto.travel/en/)
- `cn-shanghai` 34위 상하이 (CN, 원문 Shanghai, China)
- `cn-guangzhou` 41위 광저우 (CN, 원문 Guangzhou, China)
- `cn-beijing` 42위 베이징 (CN, 원문 Beijing, China)
- `cn-shenzhen` 46위 선전 (CN, 원문 Shenzhen, China)
- `jp-sapporo` 50위 삿포로 (JP, 원문 Sapporo, Japan)
- `kr-busan` 56위 부산 (KR, 원문 Busan, South Korea)
- `mo-macau` 61위 마카오 (MO, 원문 Macau SAR, China)
- `jp-fukuoka` 64위 후쿠오카 (JP, 원문 Fukuoka, Japan)
- `cn-zhuhai` 98위 주하이 (CN, 원문 Zhuhai, China)

### 동남아시아 — 원본 11곳

- `sg-singapore` 9위 싱가포르 (SG, 원문 Singapore, Singapore) **파일럿** — 다양한 경험이 있는 도시의 과도한 상위 노출 점검
  범위안: 동네별 경험을 나누고 센토사는 이동·입장 조건을 따로 검수한다. [출처 후보](https://www.visitsingapore.com/neighbourhood/featured-neighbourhood/)
- `th-bangkok` 20위 방콕 (TH, 원문 Bangkok, Thailand) **파일럿** — 같은 도시에서 미식·시장·문화 경험의 선택 차이
  범위안: 도심 시장·문화 경험부터 시작. 먼 근교 상품을 자동 포함하지 않는다. [출처 후보](https://www.tourismthailand.org/Destinations/Provinces/Bangkok/219)
- `my-kuala-lumpur` 24위 쿠알라룸푸르 (MY, 원문 Kuala Lumpur, Malaysia)
- `th-pattaya-chonburi` 45위 파타야-촌부리 (TH, 원문 Pattaya-Chonburi, Thailand)
- `th-phuket` 47위 푸껫 (TH, 원문 Phuket, Thailand) **파일럿** — 목록 이름이 가리키는 범위를 확인한 뒤 해변 휴식 경험을 연결하는 사례. 방콕과 같은 나라의 다른 여행 유형 비교.
  범위안: 앱에서는 푸껫 본섬을 지역 단위로 다룬다. 초기 경험 자료는 빠통·까따·까론 해변과 올드타운으로 제한하며 본섬 밖 섬·보트 투어는 제외한다. Euromonitor 집계 범위는 미확인으로 유지한다. [출처 후보](https://www.tourismthailand.org/Destinations/Provinces/Phuket/350)
- `vn-ho-chi-minh-city` 52위 호찌민 (VN, 원문 Ho Chi Minh City, Vietnam)
- `vn-hanoi` 72위 하노이 (VN, 원문 Hanoi, Vietnam)
- `my-johor-bahru` 81위 조호르바루 (MY, 원문 Johor Bahru, Malaysia)
- `vn-nha-trang` 86위 냐짱 (VN, 원문 Nha Trang, Vietnam)
- `id-jakarta` 90위 자카르타 (ID, 원문 Jakarta, Indonesia)
- `id-denpasar` 96위 덴파사르 (ID, 원문 Denpasar, Indonesia)

### 남아시아 — 원본 1곳

- `in-delhi` 74위 델리 (IN, 원문 Delhi, India) **파일럿** — 원본 목록의 유일한 남아시아 도시. 도시 문화 경험과 광역 여행권 분리.
  범위안: 델리 도시 체류권의 문화 경험부터 시작. 다른 주의 명소는 이동 검수 전 포함하지 않는다. [출처 후보](https://delhitourism.gov.in/)

### 유럽 — 원본 39곳

- `fr-paris` 1위 파리 (FR, 원문 Paris, France) **파일럿** — 유명도보다 실제 선호 경험으로 선택되는지
  범위안: 파리 도심부터 시작. 베르사유 등 근교 방문은 별도 근거로 다룬다. [출처 후보](https://parisjetaime.com/eng/)
- `es-madrid` 2위 마드리드 (ES, 원문 Madrid, Spain)
- `it-rome` 4위 로마 (IT, 원문 Rome, Italy)
- `it-milan` 5위 밀라노 (IT, 원문 Milan, Italy)
- `nl-amsterdam` 7위 암스테르담 (NL, 원문 Amsterdam, Netherlands)
- `es-barcelona` 8위 바르셀로나 (ES, 원문 Barcelona, Spain)
- `de-berlin` 16위 베를린 (DE, 원문 Berlin, Germany)
- `gb-london` 18위 런던 (GB, 원문 London, United Kingdom)
- `de-munich` 22위 뮌헨 (DE, 원문 Munich, Germany)
- `it-florence` 23위 피렌체 (IT, 원문 Florence, Italy)
- `gr-athens` 25위 아테네 (GR, 원문 Athens, Greece)
- `pt-lisbon` 26위 리스본 (PT, 원문 Lisbon, Portugal) **파일럿** — 옛 모델의 특정 국가 쏠림과 별개로 도시 적합성 확인
  범위안: 리스본 도심부터 시작. 신트라·카스카이스를 묵시적으로 합치지 않는다. [출처 후보](https://www.visitlisboa.com/en)
- `it-venice` 30위 베네치아 (IT, 원문 Venice, Italy)
- `at-vienna` 31위 빈 (AT, 원문 Vienna, Austria)
- `cz-prague` 32위 프라하 (CZ, 원문 Prague, Czech Republic)
- `ie-dublin` 33위 더블린 (IE, 원문 Dublin, Ireland)
- `de-frankfurt` 37위 프랑크푸르트 (DE, 원문 Frankfurt, Germany)
- `dk-copenhagen` 38위 코펜하겐 (DK, 원문 Copenhagen, Denmark)
- `de-hamburg` 43위 함부르크 (DE, 원문 Hamburg, Germany)
- `es-palma-de-mallorca` 49위 팔마데마요르카 (ES, 원문 Palma de Mallorca, Spain)
- `es-seville` 51위 세비야 (ES, 원문 Seville, Spain)
- `fr-nice` 53위 니스 (FR, 원문 Nice, France)
- `ch-zurich` 55위 취리히 (CH, 원문 Zurich, Switzerland)
- `no-oslo` 57위 오슬로 (NO, 원문 Oslo, Norway)
- `be-brussels` 59위 브뤼셀 (BE, 원문 Brussels, Belgium)
- `hu-budapest` 60위 부다페스트 (HU, 원문 Budapest, Hungary)
- `es-valencia` 62위 발렌시아 (ES, 원문 Valencia, Spain)
- `fi-helsinki` 63위 헬싱키 (FI, 원문 Helsinki, Finland)
- `se-stockholm` 67위 스톡홀름 (SE, 원문 Stockholm, Sweden)
- `pt-porto` 68위 포르투 (PT, 원문 Porto, Portugal)
- `gr-rhodes` 69위 로도스 (GR, 원문 Rhodes, Greece)
- `it-verona` 71위 베로나 (IT, 원문 Verona, Italy)
- `it-bologna` 75위 볼로냐 (IT, 원문 Bologna, Italy)
- `pl-warsaw` 78위 바르샤바 (PL, 원문 Warsaw, Poland)
- `gr-heraklion` 82위 이라클리오 (GR, 원문 Heraklion, Greece)
- `gb-edinburgh` 85위 에든버러 (GB, 원문 Edinburgh, United Kingdom)
- `gr-thessaloniki` 89위 테살로니키 (GR, 원문 Thessaloniki, Greece)
- `pl-krakow` 92위 크라쿠프 (PL, 원문 Kraków, Poland)
- `lt-vilnius` 99위 빌뉴스 (LT, 원문 Vilnius, Lithuania)

### 서아시아 — 원본 10곳

- `ae-dubai` 12위 두바이 (AE, 원문 Dubai, United Arab Emirates) **파일럿** — 출장·쇼핑 수요가 큰 도시를 인상으로 배제하지 않고 실제 경험으로 판단하는지.
  범위안: 도시 내 경험부터 시작. 사막 체험은 출발점·이동·운영 조건을 따로 검수한다. [출처 후보](https://www.visitdubai.com/en/places-to-visit)
- `tr-istanbul` 14위 이스탄불 (TR, 원문 Istanbul, Türkiye) **파일럿** — 역사·시장·수변 경험이 다른 선호를 충족하는지
  범위안: 도시 구역별 경험과 해협 이동을 구분. 카파도키아를 합치지 않는다. [출처 후보](https://goturkiye.com/istanbul)
- `tr-antalya` 48위 안탈리아 (TR, 원문 Antalya, Türkiye)
- `ae-abu-dhabi` 66위 아부다비 (AE, 원문 Abu Dhabi, United Arab Emirates)
- `qa-doha` 73위 도하 (QA, 원문 Doha, Qatar)
- `sa-riyadh` 76위 리야드 (SA, 원문 Riyadh, Saudi Arabia)
- `sa-medina` 87위 메디나 (SA, 원문 Medina, Saudi Arabia)
- `sa-mecca` 91위 메카 (SA, 원문 Mecca, Saudi Arabia)
- `ge-tbilisi` 94위 트빌리시 (GE, 원문 Tbilisi, Georgia)
- `tr-mugla` 100위 무을라 (TR, 원문 Muğla, Türkiye)

### 아프리카 — 원본 2곳 + 보충 1곳

- `ma-marrakesh` 95위 마라케시 (MA, 원문 Marrakech, Morocco) **파일럿** — 역사·시장 경험과 사막 숙박 여행 분리
  범위안: 도시 문화·시장 경험 중심. 사하라 숙박 여행을 기본 범위에서 제외한다. [출처 후보](https://www.visitmorocco.com/en/travel/marrakesh)
- `eg-cairo` 97위 카이로 (EG, 원문 Cairo, Egypt)
- `za-cape-town` **보충** 케이프타운 (ZA) **파일럿** **자연 거점** — 도시와 산·해안 자연 경험의 병존
  범위안: 도시와 테이블마운틴 등 근접 경험부터 검수. 사파리·가든루트를 합치지 않는다. [출처 후보](https://www.capetown.travel/top-attractions/tablemountain/)

### 북미 — 원본 11곳

- `us-new-york` 6위 뉴욕 (US, 원문 New York, United States) **파일럿** — 혼자 탐방·공연·동행 활동의 서로 다른 선호
  범위안: 뉴욕시 구역 단위. 뉴욕주 전체를 합치지 않는다. [출처 후보](https://www.nyctourism.com/)
- `us-los-angeles` 13위 로스앤젤레스 (US, 원문 Los Angeles, United States)
- `us-orlando` 21위 올랜도 (US, 원문 Orlando, United States)
- `us-las-vegas` 27위 라스베이거스 (US, 원문 Las Vegas, United States)
- `us-san-francisco` 35위 샌프란시스코 (US, 원문 San Francisco, United States)
- `us-miami` 36위 마이애미 (US, 원문 Miami, United States)
- `ca-toronto` 39위 토론토 (CA, 원문 Toronto, Canada)
- `us-washington` 40위 워싱턴 (US, 원문 Washington, United States)
- `ca-vancouver` 58위 밴쿠버 (CA, 원문 Vancouver, Canada) **파일럿** **자연 거점** — 고강도 활동 없이 자연을 원하는 사용자 비교
  범위안: 스탠리파크 등 도시 자연부터 검수. 노스쇼어는 이동 확인 후 추가하고 휘슬러를 기본 포함하지 않는다. [출처 후보](https://www.destinationvancouver.com/things-to-do/stanley-park)
- `us-honolulu` 65위 호놀룰루 (US, 원문 Honolulu, United States) **파일럿** — 해변 휴식과 도시 경험을 같은 나라 대도시와 비교
  범위안: 도심·와이키키 중심. 오아후 전체와 다른 하와이 섬을 자동 포함하지 않는다. [출처 후보](https://www.gohawaii.com/islands/oahu)
- `ca-montreal` 77위 몬트리올 (CA, 원문 Montreal, Canada)

### 중남미 — 원본 9곳

- `br-sao-paulo` 44위 상파울루 (BR, 원문 São Paulo, Brazil)
- `mx-mexico-city` 54위 멕시코시티 (MX, 원문 Mexico City, Mexico) **파일럿** — 문화·미식 중심 대도시에서 서로 다른 선호가 구분되는지.
  범위안: 도시 내 구역별 경험부터 시작. 근교 유적은 이동 검수 후 포함한다. [출처 후보](https://www.turismo.cdmx.gob.mx/)
- `br-rio-de-janeiro` 70위 리우데자네이루 (BR, 원문 Rio de Janeiro, Brazil)
- `mx-cancun` 79위 칸쿤 (MX, 원문 Cancún, Mexico)
- `ar-buenos-aires` 80위 부에노스아이레스 (AR, 원문 Buenos Aires, Argentina)
- `co-bogota` 83위 보고타 (CO, 원문 Bogotá, Colombia)
- `pe-lima` 84위 리마 (PE, 원문 Lima, Peru)
- `cl-santiago` 88위 산티아고 (CL, 원문 Santiago, Chile)
- `do-punta-cana` 93위 푼타카나 (DO, 원문 Punta Cana, Dominican Republic)

### 오세아니아 — 원본 2곳 + 보충 2곳

- `au-sydney` 28위 시드니 (AU, 원문 Sydney, Australia) **파일럿** — 항구·해변·문화 경험의 조합. 원본 목록의 오세아니아 도시로서 보충 자연 거점과 비교.
  범위안: 도심·항만·해변부터 시작. 국립공원 등 외곽 자연 경험은 이동 검수 후 포함한다. [출처 후보](https://www.sydney.com/destinations/sydney)
- `au-melbourne` 29위 멜버른 (AU, 원문 Melbourne, Australia)
- `au-cairns` **보충** 케언스 (AU) **파일럿** **자연 거점** — 자연 관찰과 수중 액티비티를 같은 선호로 보지 않는지
  범위안: 케언스 체류와 케언스 출항 코스를 구분. 리프 전체·다일 선상 숙박을 기본 포함하지 않는다. [출처 후보](https://tropicalnorthqueensland.org.au/where-to-go/cairns-northern-beaches/)
- `nz-queenstown` **보충** 퀸스타운 (NZ) **파일럿** **자연 거점** — 자연 풍경과 고강도 활동 선호를 분리하는지
  범위안: 도시 근처 산책·호수 경험부터 검수. 밀퍼드사운드·다일 트레킹은 기본 범위에서 제외한다. [출처 후보](https://www.queenstownnz.co.nz/things-to-do/outdoor-activities/walking-and-hiking/)
