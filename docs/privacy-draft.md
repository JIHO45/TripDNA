# 개인정보 초안: 프라이버시 선언과 처리방침 골격

2026-10-29 보완: 서버 미구현·제공자 미정 표현을 현재 호출 경로에 맞추고, 실제 전송·보관·삭제 확인은 저장 계약으로 연결했다. 선언 유형과 최종 처리방침은 확정하지 않았다.
2026-10-17 작성: [출시 차단 요건](release.md)의 프라이버시 선언·처리방침·권한 문구 항목을 준비하기 위한 초안이다.
2026-10-31: 선언 입력표를 코드 대조로 다시 쓰고, 매니페스트 추가·사진 권한 문구 수정을 했다.
상태: **선언 입력표는 사용자 입력 전.** 법률 자문이 아니다. 출시 전 공식 요건을 다시 확인한다([R3](release.md#출시-검사와-병행-업무)). 저장·전송 정책의 원문은 [저장·전송](data/storage-and-privacy.md)이며, 미정 항목의 선택지는 그 문서의 [결정 선택지(초안)](data/storage-and-privacy.md#결정-선택지초안)에 있다. 현재 항목과 미확인 운영 설정은 [저장 계약의 구현 점검](data/storage-and-privacy.md#현재-구현-점검2026-10-29)을 우선 참고한다.

## 확인한 Apple 요건

확인일: 2026-10-17. 웹 페이지를 요약 도구로 읽었으며 원문 전체를 대조하지는 않았다.

- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
  - “수집”은 기기 밖으로 보낸 데이터를 개발자나 제3자 파트너가 실시간 처리에 필요한 시간보다 오래 접근할 수 있는 경우다. 기기에서만 처리한 데이터와, 서버로 보낸 뒤 처리 직후 버린 데이터는 선언 대상이 아니다.
  - 제3자 파트너(SDK·외부 업체)의 수집도 포함해 선언한다. Apple이 수집하는 데이터는 개발자가 선언하지 않는다.
  - “사용자 연결”은 수집 전에 비식별 조치를 하지 않으면 대개 연결로 본다. “추적”은 앱 데이터를 다른 회사의 데이터와 엮어 광고·광고 측정에 쓰거나 데이터 브로커와 공유하는 것이다.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (페이지의 최종 수정일은 확인하지 못함)
  - 5.1.1(i): 처리방침을 App Store Connect와 앱 안에 둔다. 수집 항목·방법·용도, 제3자의 동등한 보호, 보관·삭제 정책과 동의 철회·삭제 요청 방법을 적는다.
  - 5.1.1(ii): 수집에 동의를 받고 쉽게 철회할 수 있게 한다. 권한 문구는 용도를 명확하고 완전하게 적는다.
  - 5.1.1(iii): 가능하면 전체 사진 접근 대신 시스템 사진 선택기를 쓴다.
  - 5.1.1(v): 계정 생성을 지원하면 앱 안에서 계정 삭제를 제공한다.
  - 5.1.2(i): 제3자 AI를 포함해 제3자와 개인 데이터를 공유할 때 명확히 알리고 **명시적 허락**을 받는다.
- 개인정보 매니페스트: 2026-10-31 [`TripDNA/PrivacyInfo.xcprivacy`](../TripDNA/PrivacyInfo.xcprivacy)를 추가했다. 앱 코드의 필수 사유 API는 UserDefaults뿐이라 `CA92.1`(앱 자신의 값만 읽고 씀)을 적었다(사진의 `creationDate`는 PHAsset 속성이라 파일 시각 API가 아니다). Firebase SDK의 매니페스트는 SDK가 제공한다. 이번에 Apple 문서를 다시 읽지는 않았다. 업로드 때 App Store Connect 경고로 확인한다.
- 미확인: 익명 로그인(Firebase)만 있는 경우가 5.1.1(v)의 “계정 생성”에 해당하는지. 앱 로그인 화면과 Apple 로그인은 없지만 Firebase 익명 계정은 만든다. 2026-10-31부터 앱의 모든 데이터 지우기가 그 계정과 서버 사용량 문서를 지운다([실제 삭제 범위](data/storage-and-privacy.md#남는-기록과-현재-삭제-범위)). 해당하더라도 요건을 충족한다고 본다.

## App Store Connect 입력표

2026-10-31 코드 대조로 다시 썼다(이전 표는 구독·목록 밖 도시 기록을 전제로 했다). 근거: 앱이 넣은 Firebase SDK는 Core·Auth·AppCheck뿐이고(Analytics·Crashlytics 없음, `GoogleService-Info.plist`의 `IS_ANALYTICS_ENABLED` false), StoreKit 코드가 없고, 목록 밖 도시는 기록하지 않는다(결정 D). 같은 내용을 [`PrivacyInfo.xcprivacy`](../TripDNA/PrivacyInfo.xcprivacy)에 넣었다. App Store Connect에는 사용자가 직접 입력한다.

**Do you or your third-party partners collect data from this app? → Yes.** **Tracking → No.**

| Apple 데이터 유형 | 내용 | Linked to user | Tracking | 목적 | 판단 근거 |
|---|---|---|---|---|---|
| Identifiers › User ID | Firebase 익명 UID(설치별, 이름·이메일 없음) | Yes | No | App Functionality | 서버(Auth·`usage/{uid}`)에 남는다 |
| Usage Data › Other Usage Data | 익명 UID별 이번 달 추천·질문 횟수 | Yes | No | App Functionality | 무료 한도 확인. 그 달 끝 + 7일에 삭제 |
| Usage Data › Product Interaction | 이벤트별 일별 합계(`metric`) | No | No | Analytics | ID·기기 정보 없이 숫자만. 자동 수집이라 선택적 공개 예외에 들지 않는다고 보고 선언한다 |
| User Content › Other User Content | 조건·자유문장·질문, 동의 시 평가 별점·메모·다녀온 도시 | No | No | App Functionality | 중계 서버는 저장하지 않지만 Anthropic이 자체 정책(일반적으로 30일 이내)으로 보관할 수 있어 "실시간 처리 후 폐기"로 보기 어렵다. 요청에 UID를 넣지 않는다 |

선언하지 않는 것과 이유:

- 여행·평가·사진·프로필: 기기에만 저장한다.
- 사진 위치의 장소 이름 변환: Apple `CLGeocoder`. Apple의 수집은 개발자가 선언하지 않는다(처리방침 3절에는 적었다).
- App Check·App Attest 토큰: 요청 검증 후 보관하지 않는다.
- DeviceCheck 토큰(2026-11-02 추가): 그 달 첫 요청에서 Apple에 조회·표시하는 데만 쓰고 보관하지 않는다. 기기 표시(2비트와 달)는 Apple이 보관한다. 우리 서버에 남는 것은 사용량 문서의 확인한 달(`deviceMonth`)뿐이라 위 Other Usage Data(사용 횟수)에 포함된다. 처리방침 5·7·9절에 적었다.
- 서버 운영 로그의 IP 등 접속 정보: Google Cloud 기본 보관(30일). Apple 데이터 유형에 IP 자체는 없고 위치 추정에 쓰지 않아 선언하지 않는다. 처리방침 5절에는 적었다.
- "틀린 내용 알리기" 메일: 사용자가 직접 보낼 때만 받는 선택적 의견이라 선택적 공개(optional disclosure) 예외로 본다. 처리방침 5절에는 적었다.
- 구매 기록: 구독 미구현. 구독(StoreKit 서버 검증)을 넣으면 Purchases › Purchase History를 다시 판단한다.

검토할 점(사용자 판단):

- 사용 횟수를 Product Interaction이 아니라 Other Usage Data로 둔 것은, 한 유형을 Linked와 Not linked로 동시에 답할 수 없어서다. 둘 다 Product Interaction으로 두면 합계까지 Linked로 표시해야 한다.
- Other User Content를 빼려면 Anthropic 무보관(Zero Data Retention) 계약 같은 근거가 있어야 한다. 지금은 선언하는 쪽이 안전하다.

5.1.2(i) 제3자 AI 고지·명시적 허락은 선언과 별개로 첫 추천 전 동의 시트가 맡는다(결정 A1, 2026-10-31 구현).

## 개인정보 처리방침

2026-10-31 확정·게시했다. 본문은 [처리방침 사본](privacy-policy.md), 원본은 그 파일 머리의 Notion 주소다(영어만 게시). 이전 골격은 지웠다.

## 권한 문구

2026-10-31 고침: 실제로 쓰이는 `InfoPlist.xcstrings`(en·ko)의 사진 읽기 문구가 위치로 지난 여행 찾기만 적고 있어, 빌드 설정 문구와 처리방침 3절에 맞춰 "날짜·위치로 지난 여행 찾기, 여행일마다 사진 고르기, 사진은 기기 밖으로 보내지 않음"으로 바꿨다. 좌표가 Apple 장소 이름 변환으로 나가는 것은 처리방침에 적었다. 빌드 산출물 `ko.lproj/InfoPlist.strings`에 반영된 것을 확인했고, 권한 창을 실제로 띄워 보지는 않았다.

- 위치·추적 권한 키 없음(설계와 맞음). Apple 로그인 entitlement는 이미 없고 App Attest만 있다.
- 사진 추가 문구: 공유 카드 저장 용도와 맞다.
