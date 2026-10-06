# 도시 자료 파일 형식 v3

상태: D1의 파일 계약. 앱 연결·추천 검증기는 아직 구현하지 않았다. 정책은 [데이터 경계](storage-and-privacy.md), 경험 분류는 [경험 어휘](../recommendation/experience-vocabulary.md)를 따른다.

실제 파일 모양은 [가상 도시 예제](../../data/cities/example.json)에 있다. 예제의 장소·가격·출처·검수자는 모두 가상이며 실제 검수 실적으로 세지 않는다. `dataset_kind: synthetic`은 형식 시험에만 사용하고 실제 사용자 추천·품질 평가에서는 거부해야 한다.

## 파일과 식별자

도시 또는 사전 검토한 지역 하나를 UTF-8 JSON 파일 하나로 저장한다. 초기 자료는 `data/cities/`에 둔다. `example.json`은 카탈로그에 포함하지 않는다. 이 JSON 계약은 현재 작성·검수·PC 평가용이며 Firestore 컬렉션이나 MySQL 테이블 설계가 아니다. 운영 배포와 저장소 결정은 [저장 단계](storage-and-privacy.md#저장-방식과-도입-단계)를 따른다.

- `schema_version`: 형식 버전, 현재 `3`. v3는 장소 ID·추천 범위 관계·경험별 주요 이동 제약·주장 사용 범위를 추가한다. v2는 분류 ID와 선택 교통 상세 필드를 도입했다.
- `category_version`: [경험 분류 목록](../../data/experience-categories.json)의 버전. 현재 `1`.
- `dataset_kind`: `synthetic` 또는 `catalog`. 실제 지명만 넣었다고 `catalog`로 바꾸지 않는다.
- `data_version`: 이 파일의 양의 정수 버전. 내용 변경 시 올리고 평가 실행에는 해당 파일의 해시도 남긴다.
- `destination`: `id`, `kind`(`city`/`region`), `name`, `aliases`, `country_codes`, `coverage`, `review_status`를 갖는다. 실제 나라 코드는 ISO 3166-1 alpha-2, 가상 예제는 `ZZ`다.
- `id`는 카탈로그 내 고유하고 이름이 바뀌어도 유지한다. 별칭은 검색용이며 중복될 수 있다. 나라만 아는 방문을 임의 도시 ID에 연결하지 않는다.
- `coverage`: 적용 범위 `description`, 그 범위를 확인할 `evidence_ids`, `gateway_city_ids`. 도시 경계 밖 경험은 각 주장의 `area`에 따로 적는다. 지역의 거점 ID는 카탈로그에 실제 존재해야 한다.
- `review_status`: `draft`/`partial`/`reviewed`. 편집 진행 표시일 뿐, 아래 개별 근거 검사를 생략하는 허가가 아니다. 예제에서는 가상 상태다.

## 경험과 추천 요약

`places`는 파일 안에서 고유한 `id`, 표시용 `name`, `scope_relation`(`inside`/`outside`/`unknown`), `scope_evidence_ids`를 갖는다. 외부 참조는 `destination.id + place.id`로 구분한다. 관계는 행정경계가 아니라 `destination.coverage`의 명시된 추천 범위 기준이다. 알려진 관계에는 위치 주장(`kind: location`)의 근거 ID가 필요하다. 범위 밖이라는 것과 멀다는 것은 다르다.

`experiences`는 고유한 `id`, 표시용 `label`, `categories`, `place_ids`, `evidence_ids`, `constraint_evidence_ids`, `travel_requirements`를 갖는다. v2의 `place_names`는 `places`와 `place_ids`로 대체한다.

`travel_requirements`에는 `boat_required`, `overnight_required`를 각각 `{ value: true/false/null, evidence_ids: [] }`로 둔다. `null`은 미확인이다. `false`도 근거가 필요하며 본섬·도심에 있다는 이유로 채우지 않는다. 근거는 출발점·이용 경로·적용 조건이 드러나는 `transport` 또는 `access` 주장으로 연결한다. 필요한 경우 기존 `mobility`로 보충한다.

이 필드들은 검수 전에도 **초안 값**을 보존할 수 있다. 실행 시에는 연결 근거가 검수·유효성·적용 조건을 통과한 경우에만 확인된 값으로 사용하고, 아니면 관계는 `unknown`, 이동 제약은 `null`로 해석한다. 별도의 검수 상태를 중복 저장하지 않는다. 범위 밖·미확인 장소를 범위 안의 경험으로 조용히 합치지 않는다. 범위 밖 경험을 포함하려면 별도 범위 검토와 근거가 필요하며, 숙박 필요가 확인된 핵심 경험은 별도 지역 후보를 검토한다. 범위 안이어도 당일 일정 가능을 보장하지 않는다.

- 분류는 경험 분류 목록의 고정 ID를 사용한다(예: `city_exploration`, `nature_scenery`). 한국어 라벨은 표시할 때 연결한다. 수치화한 도시 성격·개인 성격을 넣지 않는다.
- `evidence_ids`는 실제 활동·장소를 뒷받침한다. `constraint_evidence_ids`는 이동·예약·계절·가격 등의 확인된 제약 또는 미상 항목을 연결한다. 빈 배열은 ‘제약 없음’이 아니라 ‘등록된 근거 없음’이다.
- 근교 경험도 장소·범위 관계와 추천을 바꾸는 중요한 제약부터 기록한다. 버스 요금·배차·정류장별 소요 시간은 필수가 아니다. 실제 당일 일정 가능을 주장할 때만 왕복·대기·체험 시간 등의 추가 근거를 요구한다.

`summary`는 `{ text, evidence_ids }` 배열이다. 문장 하나에 필요한 **모든** 근거를 연결하고, 연결한 주장보다 넓게 표현하지 않는다. 서로 수명이 다른 가격과 상설 경험은 문장을 나눈다. 경험 이름·분류도 근거 없이 LLM 입력에 사실로 전달하지 않는다.

추적 경로는 `summary → evidence_ids → claims[].id → source.url + source.locator`다. 요약의 문장과 출처의 의미 일치는 사람이 검수한다. ID가 존재한다는 것만으로 문장이 참이라는 뜻은 아니다.

## 언어와 자료 범위

LLM용 `claims[].statement`, `claims[].question`, `summary[].text`는 영어로 작성한다. 도시·장소 이름과 경험 라벨은 한국어 표시용으로 유지하고 별칭·원문 출처는 보존한다. 검수 메모·적용 조건·출처 위치는 한국어 또는 원문 언어일 수 있다. 따라서 파일 전체를 영문 입력이라고 간주하지 않는다. 사용자 답변 원문을 영어로 덮어쓰지 않으며 최종 답변은 사용자 언어로 요청한다. 영어 사용이 품질·비용 개선을 보장한다는 뜻은 아니며 E 단계에서 같은 사실로 비교한다.

필수 제작 범위는 장소·랜드마크, 가능한 경험, 추천을 바꾸는 중요한 제약이다. 정확한 요금·시간표·개별 운영시간·실시간 예약 재고를 모든 도시에 채우지 않는다. 이미 조사한 상세 자료는 삭제하지 않고 `usage: detail_only`로 보존할 수 있다. 재확인 주기는 저장한 항목의 사용 조건이며 필수 수집 목록이 아니다.

## 주장별 근거

`claims`는 한 항목당 하나의 검증 가능한 주장 또는 미상 질문을 담는다.

- `id`: 파일 내 고유한 근거 ID. 외부에서는 `destination.id + data_version + claim.id`로 특정한다.
- `usage`: `recommendation` 또는 `detail_only`. 추천 요약·경험·범위·주요 이동 제약의 근거는 `recommendation`만 참조한다. 상세 자료는 관련 질문에서만 검수·만료 확인 후 사용한다.
- `version`: 해당 주장·범위·출처가 바뀌면 올리는 양의 정수. 재검수 전 이전 검수를 재사용하지 않는다.
- `kind`: `price`, `operation`, `reservation`, `transport`, `access`, `season`, `location`, `experience` 중 하나. 서로 다른 종류의 주장은 분리한다.
- `statement`: 사실 문장. 모르면 `null`로 두고 `question`에 확인할 내용을 쓴다. 아는 주장에서는 `question: null`.
- `area`: 이 주장이 성립하는 장소·경로. 도시 전체에 일반화하지 않는다.
- `applies`: `date_from`, `date_through`, `months`, `conditions`. 날짜는 `YYYY-MM-DD`, 월은 1~12 배열. 미상 값은 `null`이며 연중 적용으로 해석하지 않는다. 연중을 확인했으면 12개월을 모두 적는다. 운영 요일·교통수단·대상 인원 같은 조건은 `conditions`에 쓴다.
- `source`: `{ url, locator, checked_on, valid_through }` 또는 `null`. `locator`에는 원문의 절/항목과 해당 주장을 확인한 짧은 요지를 남긴다. URL만 존재하거나 페이지에 접속된 것으로 검수하지 않는다. 출처가 여러 개 필요하면 주장도 나눠 추적한다.
- `checked_on`: 실제 원문 확인일. 미검수 출처 후보는 `null`을 허용한다. 다운로드일·파일 수정일·LLM 생성일로 대신하지 않는다. 미래 날짜를 쓰지 않는다.
- `valid_through`: 출처가 명시한 마지막 유효일(그날 포함), 미상이면 `null`. 출처의 발행일이나 행사일을 재확인일로 쓰지 않는다.
- `status`: `unknown`(확인할 주장 자체가 미상), `unreviewed`(초안/출처 후보 존재), `reviewed`(사람이 출처·범위를 검수), `withheld`(변경·충돌 등으로 보류).
- `review`: `{ kind, reviewer_id, reviewed_on, claim_version, notes }` 또는 `null`. `kind`는 `self`/`independent`, 검수자는 기록에서 구별 가능한 내부 ID다. `reviewed`는 이 객체와 출처가 필수이며 `claim_version == version`이어야 한다. 자체 검수도 사용 가능하지만 독립 검수로 집계하지 않는다.
- `notes`: 미상·보류 이유, 다음 확인 사항. 새로운 사실의 우회 저장소로 사용하지 않는다.
- `cost`: `price`에만 필수인 객체, 다른 종류에서는 `null`. 가격 미상이면 `null`과 `unknown`을 사용한다.

`cost`는 통화 `currency`, 금액 `amount_min`/`amount_max`, 가격 기준일 `as_of`, 인원 `party_size`, 부과 단위 `basis`(`per_person`/`per_group`), 기간·횟수 `period`, `includes`, `excludes`를 갖는다. 금액은 음수 불가, 최솟값 ≤ 최댓값이다. 한 시설 입장료를 도시 하루 예산이나 여행 총비용으로 확대하지 않는다. 환율 환산·실시간 가격·예약 재고 확인을 뜻하지 않는다.

### 선택 교통 상세 필드

`transport`·`access` 주장에는 `mobility` 객체를 추가할 수 있다. 생략 또는 `null`은 구조화하지 못했다는 뜻이다. 객체를 쓰면 다음 필드를 모두 두되 미상 값은 `null`로 남긴다.

- `origin_destination_id`: 카탈로그의 출발 거점 ID. 동명이거나 미확인인 경우 `null`.
- `origin_place`: 역·숙소 지역 등 실제 출발점. 도착점은 주장의 `area`에 명시한다.
- `mode`: `walk`, `bicycle`, `public_transport`, `car`, `taxi`, `boat`, `flight`, `mixed` 또는 `null`. 복합 경로의 구간은 원문에 보존한다.
- `one_way_minutes`: `{ min, max }` 또는 `null`. 분 단위 음수 아닌 정수, `min ≤ max`. 대기·환승 포함 여부는 `applies.conditions`에 명시한다.
- `car_required`, `overnight_required`: `true`/`false`/`null`. 미상은 `false`가 아니다. 같은 경험도 선택한 경로·시기에 따라 달라지므로 해당 주장 범위만 나타낸다.

구조화 값에도 동일한 출처·검수·만료 규칙을 적용한다. 출처가 숫자나 불리언을 뒷받침하지 않으면 `null`로 둔다. 다른 출처의 경로나 조건을 하나의 검수 기록으로 합치지 않는다.
편도 시간 × 2만으로 당일 가능을 확정하지 않는다. 귀환편·대기·체험 시간·개방 시간까지 D2·D3에서 확인하고, 부족하면 당일 가능 미확인으로 남긴다. `overnight_required: true`가 검수된 핵심 경험은 지역 후보 검토 대상으로 삼되, `false`만으로 당일 적합 판정을 통과시키지 않는다. 모든 도시에 공통인 임의의 시간 제한은 도입하지 않는다.

## 미상과 만료 처리

재확인 기한은 `source.checked_on`에 종류별 달력 개월을 더해 계산한다. 가격·운영·예약 3개월, 교통·접근·계절 제약 6개월, 위치·상설 경험 12개월이다. 목표 월에 같은 일이 없으면 말일로 맞춘다. 계산한 날짜부터 재확인이 필요하다. 예: 2026-01-31 + 3개월 = 2026-04-30, 2024-02-29 + 12개월 = 2025-02-28.

실행 기준일 `as_of`와 확인·검수일은 **Asia/Seoul(KST) 날짜**로 고정한다. 재확인 기한 당일 KST 00:00부터 보류한다. 출처가 명시한 현지 유효일은 해당 지역에서의 만료보다 늦게 사용하지 않도록 KST로 보수적으로 환산해 `source.valid_through`에 기록하고, 원래 시간대·일시는 `source.locator`에 남긴다. 날짜만으로 당일 일부 시간의 유효성을 보장하지 않는다. 여행의 `applies` 날짜는 해당 여행지 현지 날짜다.

근거 사용 시에는 실행 기준일 `as_of`를 고정하고 다음을 모두 확인한다.

1. 실제 추천에는 `catalog` 자료만 사용한다. 도시/경험/근거 ID 중복·끊어진 참조는 입력 오류다.
2. `reviewed`이며 현재 주장 버전에 대한 검수와 출처가 있어야 한다. `checked_on ≤ reviewed_on ≤ as_of`여야 한다.
3. `as_of`가 계산한 재확인 기한 전이어야 하며 공식 `valid_through`가 있으면 그날을 넘지 않아야 한다. 알려진 변경·출처 충돌은 기한 전이라도 즉시 `withheld`로 바꾼다.
4. 여행 날짜·지역·조건이 `applies`와 맞아야 한다. 여행 날짜 미입력이나 적용 범위 미상은 조건 충족의 증거가 아니다. 미래 여행의 운영·가격도 현재 확인일만으로 보장하지 않는다.
5. 위 검사를 통과한 근거로만 사실·요약을 제공한다. 요약의 근거 중 하나라도 쓸 수 없으면 해당 문장을 보류한다. 도시 전체는 자동 삭제하지 않는다.

만료는 저장한 `status`와 별개인 계산 결과다. 원문은 남기되 만료 주장을 사실 근거에서 빼고, 연결된 필수 조건은 **미확인**으로 낮춘다. ‘예약 확인 안 됨’을 ‘예약 불필요’로 바꾸지 않는다. 미상/미검수 항목은 확인할 정보 목록으로 전달할 수 있지만 추천의 긍정 근거로 쓰지 않는다. 강제 조건이 미확인이면 적합 판정을 통과시키지 않는다.

## 예제의 기대 해석과 남은 구현

예제는 v3 구조에 맞춘 가상 자료이며, 가격·교통 등의 상세 정보도 형식 시험을 위해 포함한다. 실제 카탈로그처럼 추천 입력을 구성하는 예제는 아니다. 기준일을 **2026-09-30**으로 고정했을 때:

- `scope`와 `walk`는 가상의 검수 기록이 있어 형식 시험에서는 사용 가능하다. 예제 자체는 `synthetic`이므로 실제 추천에서는 전부 제외한다.
- `access`는 출처 후보가 있어도 미검수다. `reservation`·`season`은 미상이다. 산책 경험을 예약 없이 연중 이용할 수 있다고 답할 수 없다.
- `price`는 2026-05-31 확인 + 3개월인 2026-08-31부터 재확인 대상이며 공식 유효일도 지났다. 가격 요약은 보류하고 산책 요약은 남긴다.
- `evening_opening`은 재확인 기한 전이라도 변경 공지와 충돌해 `withheld`다. 저녁 운영 요약은 보류한다.

저장된 [예제 검사 스크립트](../../scripts/check_city_example.py)를 `python3 scripts/check_city_example.py`로 실행한다. JSON 구조·분류 ID·근거 참조·이동 값·검수 기록·월말/윤년·만료와 보류 요약을 확인하는 D1 예제 검사다. 임의의 카탈로그 입력을 보장하는 E2 검증기나 실제 여행 조건 판정기는 아니다.

v3의 장소 참조·범위 관계·주요 이동 제약·상세 자료 분리도 검사한다. 이는 출처의 의미나 앱의 실행 시 보류를 검증하지 않는다. `python3 scripts/test_city_scope.py`는 잘못된 참조·근거 없는 값 등의 회귀 검사다.

실제 카탈로그 파일(`data/cities/*.json`, 예제 제외)은 [카탈로그 무결성 검사](../../scripts/check_city_catalog.py)를 `python3 scripts/check_city_catalog.py`로 실행한다. 구조·근거 참조·상태별 규칙(미상은 질문과 `null`, 확인된 이동 값의 형식, 검수 기록의 검수자·날짜·주장 버전)·`applies`의 필드와 시작일 ≤ 종료일·`cost`의 필수 필드와 타입(금액에 불리언 불가)·D2 추천 ID 연결을 확인하고 상태별 개수를 출력한다. 출처와 문장의 의미 일치나 검수자의 실제 검수 여부는 증명하지 않는다.

D1은 이 파일 형식과 예제의 구조·참조 확인까지다. 실제 목록은 D2, 출처 조사·사람 검수는 D3, 입력 로더·유효 근거 추출과 LLM 출력 검증의 실행 구현은 E1·E2에서 한다. 예제의 기대 해석을 구현 완료 또는 실제 사실 검수로 보고하지 않는다.
