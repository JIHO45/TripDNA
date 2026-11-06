# App Store 제출 자료 (초안)

2026-11-07 수정: 제출 작업 순서로 재배치하고 최근 AI 대화·도시 사진·참고용 예상 비용·Klook 링크·구독 화면 변경을 반영했다. 글자 수, AI 동의·서버 보관 설명을 바로잡았다.
상태: **사용자 검토 전인 입력 초안.** 이번 작업에서는 App Store Connect를 열거나 값을 입력하지 않았다. 기존 등록 상태는 [TODO](TODO.md), 출시 통과 조건은 [R3](release.md#출시-검사와-병행-업무)를 따른다.

## 1. 입력 전 준비

아래 순서로 준비한 뒤 2·3절의 문구와 4절의 심사 메모를 입력한다. 초안 문구가 있다는 사실은 출시 검증 완료를 뜻하지 않는다.

1. **출시 빌드와 운영 서버를 맞춘다.** 최근 기능의 포함 여부와 [R1 확인 근거](evaluation/r1-checklist.md), [R2 검사](release.md#출시-검사와-병행-업무)를 확인한다. 특히 아래 문구의 **AI 사용량 15배는 저장소 설정 기준**이다. TODO에는 2026-11-06 예산 변경의 배포를 사용자가 따로 한다고 기록돼 있으므로 실제 서버에 적용됐는지 확인한 뒤 사용한다.
2. **앱 공통 정보를 확정한다.** 영·한 이름·부제는 아래 제안이며 등록된 이름을 확인한 값이 아니다. 기본 언어, 카테고리, 연령 등급 질문, 콘텐츠 권리, 저작권자 표기(`2026 권리자명`), 배포 국가·가격·공개 방식을 확인한다. 한국어 이름을 영어 이름과 통일할지는 사용자 선택으로 남긴다.
3. **공개 URL과 개인정보 항목을 확인한다.** 지원 페이지에는 실제 연락처가 있어야 한다. 현재 `hosting/index.html`에는 연락처가 없고, 루트 Hosting 주소는 향후 설치 링크로 넘길 계획이므로 지원 URL로 바로 쓰지 않는다. 별도 지원 페이지를 준비하고 공개 접근을 확인한다. 처리방침은 앱에 연결된 Notion 게시본과 [저장소 사본](privacy-policy.md)을 대조하고, App Privacy 입력은 [선언 자료](privacy-draft.md)를 따른다. 이 문서는 새 지원 페이지를 만들거나 배포하지 않는다.
4. **구독을 확인한다.** TODO에는 2026-11-02 사용자가 상품 등록·원화 가격 확인을 완료했다고 기록돼 있다. 상품 ID·그룹·지역별 가격·기간·혜택·복원·심사용 자료를 실제 App Store Connect와 출시 빌드에서 다시 맞춘다. `.storekit`의 가격과 무료 체험 없음은 로컬 테스트 설정이며 실제 판매 설정의 증거가 아니다.
5. **영·한 스토어 자료를 준비한다.** 아래 문구, 출시 빌드의 스크린샷, 앱 아이콘을 확인한다. 스크린샷은 추천 결과 → 도시 상세·참고 비용 → AI 대화 → 여행 기록·지문 → Wrapped 순서를 제안한다. 첫 화면에서 핵심 추천 가치를 보여 주고 나머지는 보조 기능으로 잇는다. 실제 기기 크기별 요구사항은 [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)에 맞춘다.

### 입력 제한과 복사 범위

2·3절의 필드 값과 설명 코드 블록만 복사한다. 글자 수·주석·제목은 입력하지 않는다. 이름·부제 30자, 프로모션 텍스트 170자, 설명 4,000자 이내이며 키워드는 **100바이트** 이내로 준비한다. 이름·부제는 [제품 페이지 안내](https://developer.apple.com/app-store/product-page/), 나머지 제한과 지원 URL은 [App Store Connect 필드 안내](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)를 확인했다(2026-11-07). Apple의 제품 소개 페이지는 키워드를 100자로 설명하지만 Connect 필드 안내는 100바이트로 명시하므로 더 엄격한 기준을 쓴다.

글자 수는 Python `len()`, 바이트 수는 UTF-8로 계산했다. 설명 길이는 본문 끝의 줄바꿈을 제외한다. 최종 저장 가능 여부는 App Store Connect에서도 확인한다.

---

## 2. 영어 입력 문구 (en-US)

**Name** (24자): TripDNA: AI Travel Match

**Subtitle** (28자): Find your next trip by taste

**Promotional text** (145자):
Rate the trips you've taken. TripDNA remembers what you loved and what let you down, then suggests cities that fit, with the reasons spelled out.

**Keywords** (99자, UTF-8 99바이트):
destination,where to go,vacation,holiday,city,journal,diary,wrapped,fingerprint,bucket list,getaway

이름·부제와 중복되는 단어는 뺐다.

**Description** (2491자):

```
Pick your next destination based on the trips you've actually taken.

TripDNA remembers what you loved and what let you down on past trips, and uses it to suggest cities that fit you, so you repeat the good parts and skip the disappointments.

GET RECOMMENDATIONS THAT EXPLAIN THEMSELVES
• Tell TripDNA what you want this time, in your own words
• Explore city photos, reasons to visit, and things to check before you go
• See rough cost estimates as a reference, not live prices or a guarantee that a trip fits your budget
• Bookmark cities, rule out places you don't want, and edit what TripDNA remembers about you

ASK THE AI
• Chat about a destination or your trip plans from the Recommendations and Trips tabs
• Ask follow-up questions about a city from its detail screen
• Answers can use web search and show their sources
• Revisit saved conversations when planning your next trip

BUILD YOUR TRAVEL FINGERPRINT
• Add past trips from your photo library or by hand
• Rate each trip and leave notes on what worked and what didn't
• Rank your trips and see the travel concepts you keep coming back to
• Share your fingerprint as a card

RELIVE YOUR TRIPS
• A daily photo from your past trips on the Home screen
• A yearly Wrapped story of your travels, ready to share

EXPLORE LOCAL ACTIVITIES
• Open Klook activity pages from supported city and trip detail screens
• Affiliate links are disclosed; bookings are made with the provider

YOUR RECORDS STAY YOURS
• No account creation or sign-in required
• Store trips, ratings, photos and conversations on your device, with backup and restore through your own iCloud when available
• Before using AI, review what is sent through our server to Anthropic and choose whether to include past trip records

FREE AND SUBSCRIPTION
TripDNA is free to use with 3 recommendations a month and a small monthly AI chat allowance.
TripDNA Monthly and TripDNA Yearly give you 30 recommendations a month and 15× the AI usage allowance of free. City questions and chat share this allowance; the number of answers varies with the request.

Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in your Apple Account settings.

Privacy Policy: https://woolly-devourer-5d2.notion.site/TripDNA-Privacy-Policy-4093ed084bab809a99c9ffcf15daf337
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

---

## 3. 한국어 입력 문구 (ko)

**이름** (18자): TripDNA: AI 여행지 추천

**부제** (17자): 지난 여행으로 찾는 다음 여행지

**프로모션 텍스트** (57자):
다녀온 여행을 평가하면 좋았던 점과 아쉬웠던 점을 기억해서, 나에게 맞는 도시를 이유와 함께 추천해요.

**키워드** (30자, UTF-8 80바이트):
해외여행,여행기록,여행일기,취향분석,버킷리스트,어디갈까

이름·부제와 중복되는 단어는 뺐다. 키워드는 UTF-8 100바이트 이내로 유지한다.

**설명** (1252자):

```
실제로 다녀온 여행을 바탕으로 다음 여행지를 골라요.

TripDNA는 지난 여행에서 좋았던 점과 아쉬웠던 점을 기억하고, 그걸 바탕으로 나에게 맞는 도시를 추천해요. 좋았던 경험은 다시, 실망은 피할 수 있게요.

이유가 보이는 추천
• 이번에 원하는 여행을 내 말로 적기만 하면
• 도시 사진과 함께 추천 이유, 안 맞을 수 있는 점과 확인할 조건 살펴보기
• 예상 비용은 실시간 가격이나 예산 충족 보장이 아닌 참고용 추정치로 확인
• 북마크, 가기 싫은 곳 제외, TripDNA가 기억하는 내 정보 수정

AI에게 물어보기
• 추천·여행 탭에서 여행지나 일정에 대해 AI와 대화
• 도시 상세에서 궁금한 점을 추가로 질문
• 웹 검색을 쓸 수 있고 출처를 함께 보여줘요
• 저장된 대화를 다시 보며 다음 여행을 준비

나만의 여행 지문
• 사진첩에서 불러오거나 직접 입력해 지난 여행을 추가
• 여행마다 평가하고 좋았던 점·아쉬웠던 점을 메모
• 여행 순위를 매기고, 내가 자주 찾는 여행 컨셉을 확인
• 여행 지문을 카드로 공유

여행 다시 보기
• 홈 화면의 하루 한 장 여행 사진
• 한 해 여행을 돌아보는 연간 Wrapped, 바로 공유

현지 액티비티 둘러보기
• 지원되는 도시·여행 상세에서 Klook 액티비티 페이지 열기
• 제휴 링크임을 표시하며 예약은 제휴사에서 진행해요

내 기록은 내 것
• 회원가입·로그인 없이 사용
• 여행·평가·사진·대화는 기기에 저장하고, iCloud를 사용할 수 있으면 내 iCloud에 백업·복구
• AI 사용 전에 우리 서버를 거쳐 Anthropic에 보내는 내용을 확인하고, 지난 여행 기록을 포함할지 선택해요

무료와 구독
무료로 매달 추천 3회와 소량의 AI 대화를 쓸 수 있어요.
TripDNA 월간·연간 구독은 매달 추천 30회와 무료의 15배 AI 사용량을 제공해요. 도시 질문과 대화가 이 사용량을 함께 쓰며, 질문 내용에 따라 답변받을 수 있는 횟수는 달라져요.

결제는 구매 확인 시 Apple 계정으로 청구돼요. 현재 기간이 끝나기 최소 24시간 전에 해지하지 않으면 자동으로 갱신돼요. Apple 계정 설정에서 관리하거나 해지할 수 있어요.

개인정보 처리방침: https://woolly-devourer-5d2.notion.site/TripDNA-Privacy-Policy-4093ed084bab809a99c9ffcf15daf337
이용약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

---

## 4. 심사 정보 (App Review Information)

연락 담당자 이름·이메일·전화번호는 별도 연락처 필드에도 입력한다. 아래 이메일은 앱의 오류 신고 주소이며, 담당자 이름·전화번호는 사용자가 확인한다. 앱 로그인은 없으므로 Sign-in required를 선택하지 않는다. 다음은 **Notes용 영어 초안**이며, 최종 빌드와 서버를 대조한 뒤 사용한다.

```
Thank you for reviewing TripDNA.

SIGN-IN
No user registration or app sign-in is required. Firebase creates an anonymous identifier for request verification and usage limits. No app demo credentials are needed.

GETTING STARTED
1. Complete onboarding. Photo library access is optional; use manual trip entry or preference questions without granting photo access.
2. Open Recommendations and describe the trip you want, for example, "a walkable city with great food in spring". The first recommendation consent sheet explains the information sent to Google Firebase and Anthropic. You can agree with or without past trip reviews; canceling sends nothing.
3. Open a city result to see its reasons, things to check, rough cost estimate, and city questions. Costs are estimates, not live quotes. Cities estimated to exceed the budget can still appear, with a warning and lower priority.
4. Open AI chat from Recommendations or Trips. Chat has its own first-use consent sheet and saved conversation history. City questions and chat share a cost-based AI usage allowance, not a fixed number of messages.

AI AND STORAGE
AI requests are relayed through Firebase Cloud Functions to Anthropic and may use web search. Past trip reviews and the chat trip list are included only with permission. Our relay does not persist request or response bodies. Firebase anonymous identifiers, usage records, aggregate metrics, and operational logs are handled as described in the Privacy Policy; Anthropic may retain data under its own policy.
Trip records, photos, and conversations are stored on the device. iCloud backup is enabled by default when available, can be turned off in Settings, and supports restore on a new device using the same iCloud account.

SUBSCRIPTION
Open Settings > TripDNA Subscription to view the monthly and yearly auto-renewable plans. Restore Purchases is available on the purchase screen; existing subscribers can manage their subscription from the same settings destination.
Free users receive 3 recommendations per calendar month (UTC). Subscribers receive 30 per monthly allowance period based on the purchase date, including for the yearly plan. Our server validates Apple-signed Sandbox transactions for testing and review.
Reinstalling or deleting all data does not reset the free allowance. On a previously used device, a new anonymous identifier may be blocked for the remainder of the same month. Please contact us if this prevents review.

AFFILIATE LINKS
Supported city and trip detail screens include Klook activity links with a commission disclosure. These open the provider's website in an in-app browser; bookings take place with the provider. Affiliate links do not determine which cities are recommended.

CONTACT
joe45dev@gmail.com
```

## 5. 최종 확인과 제출 순서

- [ ] 출시 빌드에서 온보딩 → 추천 → 도시 질문·AI 대화 → 구독 구매·복원·관리 경로를 확인하고, 위 메뉴 이름·동의 안내·제휴 표시와 맞춘다. 응답 시간은 측정하지 않았으므로 보장 문구를 넣지 않는다.
- [ ] 실제 배포 서버에서 15배 AI 사용량이 적용되는지 확인한다. 같은 양의 답변이나 메시지 15배를 보장하지 않는다.
- [ ] 지원 URL·처리방침 URL을 로그인 없이 열고, 연락처·정책이 보이는지 확인한다. 스크린샷과 설명이 같은 출시 빌드를 나타내는지도 확인한다.
- [ ] App Store Connect에서 개인정보 선언·연령 등급·가격 및 배포·수출 규정 질문·심사 연락처·공개 방식을 마무리하고 올바른 빌드를 선택한다. 저장소의 암호화 설정만으로 업로드 질문이 완료됐다고 판단하지 않는다.
- [ ] 첫 자동 갱신 구독 심사라면 **앱 버전·구독 그룹·심사할 월간/연간 구독을 같은 제출 초안에 추가**한다. [Apple 구독 제출 안내](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)를 따른다.
- [ ] `Add for Review`로 모은 항목을 검토한 뒤 `Submit for Review`로 실제 제출한다. 둘은 별도 단계다. [Apple 앱 제출 안내](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)를 따른다.

이 체크리스트는 완료 기록이 아니다. 실제 검사 결과·남은 항목은 [TODO](TODO.md)에 남긴다.

## 6. 코드 대조 근거와 남은 확인

- 최근 변경: `0f1679a` AI 대화, `b544008` 질문·대화 공용 사용량, `f2b3609` 15배 예산, `aee01f3` 구독 화면·관리, `04f8316` 예산 초과 도시 유지·비용 안내, `c05009b` 추천 상세 Klook 링크·Release 활성화. 커밋 반영은 서버 배포나 실기기 검증 완료와 다르다.
- AI 전송·동의: [추천 동의](../TripDNA/Recommendation/City/CityMemory.swift), [대화 동의](../TripDNA/Chat/ChatModel.swift). 과거 메모 전송만이 아니라 기본 요청 전송에도 동의를 받으며 대화는 별도 동의가 있다.
- 한도·서버 기록: [서버 구현](../functions/index.js), [저장·전송 계약](data/storage-and-privacy.md). AI 사용량의 정책 원문은 [추천 구조](recommendation/README.md#ai-대화와-ai-사용량-2026-11-03)를 따른다.
- 구독: [구독 화면](../TripDNA/Settings/SubscriptionView.swift), [테스트 설정](../TripDNATests/TripDNA.storekit). 테스트 가격은 US$3.99/월·US$39.99/년이며 이번에 실제 판매 가격·체험 설정은 확인하지 않았다.
- 백업·복구: [iCloud 구현](../TripDNA/Infrastructure/ICloudBackup.swift). iCloud 계정·가용 용량·설정에 따라 백업 가능 여부가 달라진다.
- 제휴: [공용 액티비티 화면](../TripDNA/UI/AffiliateActivitySection.swift), [제휴 정책](affiliates.md). 링크 구현과 예약 귀속 검증은 구분한다.
- 이번 점검은 문서·코드·최근 변경 이력·Apple 공식 안내 대조다. 실기기 동작, 배포 서버, App Store Connect 현재 값, 공개 페이지의 최신 내용은 확인하지 않았다.

---

## 헤더·검색 결과 자산 (2026-11-07 조사, 같은 날 Apple 공식 문서로 재확인. 진행안은 사용자 결정 전)

### 확인한 사실

- WWDC26에서 처음 소개됐고, 2026-10-05부터 App Store Connect에서 쓸 수 있다([출시 공지](https://developer.apple.com/news/?id=ljpl7kyn)).
- 선택 자산이다. 스크린샷·앱 미리보기와 별개이며 **iOS·iPadOS 27 이상**에서 보인다([관리 안내](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets)).
- 규격([공식 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)):
  - 헤더: 21:9, 3840×1646, JPEG 또는 PNG.
  - 검색 결과: 3:2, 1920×1280~3840×2560, JPEG 또는 PNG.
  - 공용: 두 자리 모두 16:9 PNG 5244×2950을 받는다.
  - 알파 채널과 투명 배경은 쓸 수 없다.
- "Use header asset in search results"는 **공용(universal) 자산에만** 켤 수 있다(관리 안내).
- 제출 방법은 두 가지다(관리 안내).
  - 앱 버전과 함께 제출하거나, Asset Library에서 따로 심사받는다. 따로 낸 자산은 최신 앱 버전을 기준으로 심사한다.
  - 현재 버전이 이미 출시돼 있으면, 승인된 자산으로 새 버전 제출 없이 바꿀 수 있다.
- 검색 결과 자산을 넣지 않으면 이벤트·앱 미리보기·스크린샷이 나온다([제작 가이드](https://developer.apple.com/app-store/asset-best-practices/)). 넣으면 스크린샷 줄 자리에 나온다는 설명은 제3자 가이드에서 나온 것이다.
- Apple 권장 사항(의무 아님, 제작 가이드):
  - 헤더: 브랜드나 분위기를 보여주고 아이디어 하나에 집중한다.
  - 검색 결과: UI·콘텐츠를 보여주고 앱의 목적이 한눈에 보이게 한다. 앱과 관련된 브랜드 이미지도 허용된다.
  - 중요한 요소는 공식 템플릿의 안전 영역과 가운데에 둔다.
  - 문구를 넣으면 지원 언어마다 현지화한다.
- 넣으면 안 되는 것(제작 가이드):
  - 가격·할인, URL, ©.
  - 다른 플랫폼이나 마켓의 로고·언급.
  - 받지 않은 수상 등 확인할 수 없는 주장.
  - Editor's Choice, App of the Day, Apple Design Award 같은 Apple 선정 표시(실제로 받았어도 넣지 않는다).
  - 4+ 등급을 넘는 내용.
- **효과와 보급에 관한 근거는 없다.**
  - 헤더와 검색 결과 중 어느 쪽 효과가 큰지, 몇 곳이 쓰고 있는지, 다운로드가 늘었는지를 보여주는 자료를 찾지 못했다.
  - 제3자 글의 "대부분 아직 안 쓴다"는 근거가 붙지 않은 언급이다.
  - App Store를 직접 열어 확인하지는 않았다.

### 진행안 (제안)

1. **출시를 막는 항목으로 두지 않는다.** 선택 자산이고 따로 심사받을 수 있으니 필수인 스크린샷을 먼저 끝낸다.
2. **공용 16:9 PNG(5244×2950)를 영어·한국어 한 장씩, 모두 두 장 만들고** "Use header asset in search results"를 켠다. 헤더와 검색 결과를 따로 만들지 않는 건 작업량 때문이고, 어느 쪽이 더 효과적이라는 판단은 아니다.
3. 구성안: 여행 사진 배경, 가운데에 추천 카드 화면(도시와 추천 이유), 짧은 문구 한 줄(예: "Your past trips pick the next one" / "지난 여행이 다음 여행지를 골라요"). 앱 화면을 넣는 건 Apple 권장을 따른 우리 선택이고 의무는 아니다. Apple Figma Universal 템플릿의 안전 영역에 맞추고, App Store Connect 미리보기로 잘리는 곳이 없는지 확인한다.
4. 시안은 스크린샷 틀과 같이 지금 만들고, 최종 캡처는 실기기 확인 뒤에 넣는다. 출시 빌드와 함께 내되, 늦어지면 출시 뒤 Asset Library로 따로 제출한다.
5. 영상, 맞춤 제품 페이지, PPO는 출시 뒤 다운로드 기준치가 생긴 다음에 다시 본다.

제3자 참고: [Adapty](https://adapty.io/blog/app-store-asset-library/), [AJ Development](https://www.aj-development.com/blog/app-store-header-and-search-result-images), [iamtayyab](https://www.iamtayyab.com/blog/app-store-creative-assets-product-page-headers), [MobileAction](https://www.mobileaction.co/blog/new-creative-assets-are-coming-to-the-app-store/).

### 시안 (2026-11-07, 사용자 검토 후 저장)

- 최종 시안: [universal-en.png](../design/app-store/creative/universal-en.png), [universal-ko.png](../design/app-store/creative/universal-ko.png). 16:9 PNG 5244×2950, 투명도 없음.
- 구성(2026-11-07 미리보기 확인 후 가운데 배치로 수정): 흰 바탕, 문구(영어 "Let your past trips pick your next destination." / 한국어 "지난 여행이 다음 여행지를 골라요"), 추천 결과 화면, 교토·리스본·바르셀로나 사진(앱 번들과 같은 Unsplash 사진, 출처는 `data/destinations/city-photo-sources.csv`).
- 휴대폰 화면은 `-uiDemo recoResult`로 띄워 조건 요약을 접은 시뮬레이터 캡처다. "추가 확인 필요" 영역은 흰색으로 덮었다. 모든 카드가 조건 확인을 통과하면 이 영역이 나오지 않으므로 앱에 있는 화면이다. **필수 스크린샷은 덮지 않고 실제 화면으로 찍는다.**
- 데모 데이터는 앱 언어에 맞춰 문장과 통화를 바꾼다(영어는 USD, 원화 금액의 1/1000). `UIDemoSeed.swift`, DEBUG 빌드에만 들어간다.
- 다시 만들기: `design/app-store/creative/`에서 `python3 make.py` 후 아래 명령으로 렌더링한다(`*-guide.html`은 잘림 범위 점선이 들어간 확인용).
  `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --force-device-scale-factor=1 --window-size=5244,2950 --virtual-time-budget=3000 --screenshot=universal-en.png file://$PWD/en.html`
- 보이는 범위(2026-11-07 App Store Connect 제품 페이지 미리보기 화면에서 잰 값, 5244×2950 기준):
  - iPhone 헤더: x 1230~4020, y 50~1890. 위 약 300px은 상태 표시줄과 뒤로·공유 버튼에 가린다.
  - iPad 헤더: x 250~4980, y 360~1780. 위 가운데(x 2140~3076, y 625까지)는 탭 메뉴에 가린다.
  - 그래서 문구와 추천 카드는 가운데 띠(x 1230~4020, y 650~1780)에 둔다. 처음 시안은 비율로 계산한 범위에 맞춰 문구가 잘렸다. 아이콘·이름 줄은 App Store가 바로 아래 보여주므로 뺐다.
- 2026-11-07 수정본을 App Store Connect에 올려 미리보기로 확인했다(사용자 확인, 문제 없음). 위 범위 값은 미리보기 화면에서 잰 근사치다.

### 필수 스크린샷 (2026-11-07)

- 위치: `design/app-store/screenshots/out/` — `{번호}-{ko|en}-{iphone|ipad}.png` 24장. iPhone 6.9인치 1320×2868, iPad 13인치 2064×2752, 투명도 없음.
- 순서: 1 추천 결과 → 2 여행 평가(하루 한 장) → 3 AI 대화 → 4 도시 상세 → 5 여행 지문 → 6 Wrapped 사진. 1번 추천 이유가 2번 타이베이 평가를 근거로 쓴다.
- 모양: 단색 배경 + 두 줄 문구. iPhone은 휴대폰 틀 안에 실제 화면, iPad는 기기 틀 없이 실제 화면에서 잘라낸 핵심 영역을 사각 카드로 넣는다(잘라낸 화면이 기기 전체 화면처럼 보이지 않게).
- 캡처: `-uiDemo appStore -uiDemoPhotoDir <저장소>/design/app-store/screenshots/photos`로 띄운 시뮬레이터(iPhone 18 Pro Max, iPad Pro 13-inch M5), 시계 9:41. iPad 3번만 iOS 글자 크기를 "아주 크게"로 찍었다(대화 글자를 읽히게).
- 하루 한 장 사진 5장은 Unsplash에서 받았고 출처는 `design/app-store/screenshots/photos/sources.csv`. 앱 번들에는 넣지 않는다.
- 다시 만들기: `design/app-store/screenshots/`에서 `python3 make.py` 후 `out/*.html`을 Chrome headless로 렌더링(iPhone `--window-size=1320,2868`, iPad `2064,2752`). 가끔 오른쪽 아래가 검게 깨져 나오면 다시 렌더링한다.
- 이 작업 중 고친 앱 화면: iPad에서 탭 화면 내용 폭을 700pt로 제한(시작값), 도시 사진 높이가 폭에 맞춰 늘어나게, 추천 카드 이유가 "…"로 잘리지 않고 두 줄까지 보이게(카드와 글 모두 필요한 높이를 쓰게 함), Wrapped를 전체 화면으로 열고 사진이 칸을 넘치지 않게.
