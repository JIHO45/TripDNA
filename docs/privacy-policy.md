# TripDNA 개인정보 처리방침

> 이 파일은 Notion에 붙여넣기 위한 사본이다. 게시한 뒤에는 **Notion 페이지가 원본**이다. 내용을 바꿀 때는 Notion을 먼저 고치고 이 파일도 맞춘다. 근거가 되는 결정은 [저장·전송](data/storage-and-privacy.md#결정-선택지초안)에 있다.
> 2026-10-31 작성. 아래 `---` 사이의 한국어·영어 두 부분을 각각 다른 Notion 페이지에 붙여넣는다. 이 안내 문단은 붙여넣지 않는다.
> 게시 주소(영어): https://woolly-devourer-5d2.notion.site/TripDNA-Privacy-Policy-4093ed084bab809a99c9ffcf15daf337 (앱 설정의 링크). 2026-10-31 사용자 결정으로 영어 페이지만 게시한다. 한국어 부분은 게시하지 않는 참고용 번역이다.

---

# TripDNA 개인정보 처리방침

시행일: 2026년 11월 2일

TripDNA(이하 “앱”)는 지난 여행의 기록을 바탕으로 다음 여행지를 추천합니다. 이 방침은 앱이 어떤 정보를 어디에 두고, 무엇을 누구에게 보내며, 얼마나 보관하는지 설명합니다.

## 1. 운영자와 연락처

- 운영자: 박지호(Park Jiho)
- 개인정보 보호책임자: 박지호
- 문의: joe45dev@gmail.com

## 2. 기기에만 저장하는 정보

여행 기록, 평가와 메모, 고른 사진의 사본, 원하는 여행·기억하는 취향 같은 선호, 추천 결과는 사용자의 기기에만 저장합니다. 운영자는 이 정보를 서버에 모으지 않습니다. 앱을 삭제하면 이 정보도 함께 지워집니다.

기기에서 iCloud에 로그인되어 있으면 이 기록(사진 사본 포함)을 사용자 Apple 계정의 iCloud에 백업합니다. 백업은 기본으로 켜져 있고 설정 > iCloud 백업에서 끌 수 있습니다. 백업은 Apple의 iCloud에 저장되며 운영자는 볼 수 없습니다. 같은 Apple 계정의 새 기기에서 기록을 되살리는 데만 씁니다.

## 3. 사진 접근

사진 접근을 허용하면 사진의 날짜와 위치로 지난 여행을 찾고, 여행일의 사진을 고르고, 공유 카드를 사진첩에 저장합니다. 사진 원본은 기기 밖으로 보내지 않습니다. 사진의 위치를 장소 이름으로 바꿀 때 Apple의 위치 서비스에 좌표가 전송됩니다.

## 4. 추천·질문·AI 대화를 위해 보내는 정보

도시 추천, 도시에 대한 질문 답변, AI 대화의 답은 외부 AI 모델이 만듭니다. 이를 위해 아래 정보를 운영자의 중계 서버를 거쳐 AI 제공자에게 보냅니다. 처음 추천을 받기 전과 처음 AI 대화를 하기 전에 보내는 항목을 안내하고 동의를 받습니다.

- 항상 보내는 것: 고른 여행 컨셉, 여행 조건(시기, 기간, 인원, 예산 등), 직접 적은 문장, 원하는 여행, 질문 내용과 해당 도시
- AI 대화에서 항상 보내는 것: 대화 메시지, 지난 여행의 컨셉별 개수, 원하는 여행의 단계와 피하고 싶은 점, 저장한 도시(이름, 나라, 조건 요약)
- 동의한 경우에만 보내는 것: 최근 여행 평가 최대 10건의 별점과 메모(칸마다 500자까지), 다녀온 도시. AI 대화에서는 여행 목록(장소, 날짜, 컨셉, 만족도)과 위 평가도 이 경우에만 보냅니다.
- 보내지 않는 것: 사진 원본, 위치 기록, 이름·연락처

지난 여행 평가 전송은 설정 > 권한과 보내는 정보에서 언제든 끌 수 있습니다. 끄면 다음 요청부터 보내지 않습니다. 이미 보낸 내용은 앱에서 되돌릴 수 없습니다. 끄면 평가가 담긴 맥락으로 시작한 AI 대화는 읽을 수만 있고 이어 쓸 수 없습니다.

AI 대화의 원문은 기기에만 저장하고(iCloud 백업 포함, 우리 서버에는 저장하지 않음), 답을 만들 때 이전 내용의 요약과 최근 메시지를 보냅니다. 대화가 길어지면 앞부분을 요약하려고 그 부분을 한 번 더 보냅니다. AI 대화는 웹 검색을 쓸 수 있습니다.

## 5. 서버에 남는 정보

| 항목 | 내용 | 보관 기간 |
| --- | --- | --- |
| 익명 ID | 로그인 없이 앱 설치마다 자동으로 만드는 무작위 식별자(Google Firebase). 이름·이메일과 연결하지 않습니다. | 앱에서 모든 데이터 지우기를 할 때까지 |
| 사용 횟수 | 무료 한도를 확인하기 위한 익명 ID별 월간 추천 횟수와 AI 사용량(비용 기준, 처리 중인 예약분과 최근 정산한 요청 ID 포함), 그 달에 기기 확인을 마쳤는지 여부 | 해당 월이 끝나고 7일 뒤 삭제 |
| 구독 사용 횟수 | 구독자의 한도를 확인하기 위해, Apple이 발급한 구독의 원 거래 ID별로 결제 주기마다 추천 횟수와 AI 사용량(비용 기준, 처리 중인 예약분과 최근 정산한 요청 ID 포함)을 셉니다. 구독 확인을 위해 앱이 현재 구독 거래 정보(Apple 서명 데이터)를 요청과 함께 보내며, 서버는 서명·상품·만료·환불 여부만 확인하고 거래 정보 자체는 저장하지 않습니다. 이 기록에는 익명 ID를 함께 두지 않습니다. | 해당 결제 주기가 끝나고 7일 뒤 삭제 |
| 기기 확인 | 앱을 다시 설치하거나 데이터를 지운 뒤 같은 기기에서 무료 한도를 다시 받지 못하게 하려고, 그 달 처음 요청할 때 Apple DeviceCheck로 이 기기가 이번 달에 이미 무료 한도를 받았는지 확인하고 표시합니다. Apple은 기기마다 2개의 값과 마지막으로 표시한 달만 보관하며, 우리 서버는 확인에 쓰는 기기 토큰을 저장하지 않습니다. | 기기 토큰은 저장하지 않음. 기기 표시는 Apple이 보관 |
| 요청과 응답 내용 | 저장하지 않습니다. 중계 서버는 전달만 합니다. | 보관하지 않음 |
| 이용 합계 | 앱을 고치기 위해 하루 동안 특정 행동이 몇 번 있었는지 세는 숫자(예: 추천을 받은 횟수, 공유한 횟수, 추천에서 도시를 뺀 횟수). 익명 ID나 기기 정보 없이 숫자만 더하므로 누가 했는지 알 수 없습니다. | 기한 없음(개인을 알아볼 수 없는 합계) |
| 운영 비용 합계 | AI 호출 비용을 파악하려고 하루 동안의 호출 시작 수, 비용을 확인한 수와 그 비용 합계, 확인하지 못한 수를 더한 숫자. 익명 ID나 기기 정보 없이 날짜별 숫자만 더합니다. | (보관 기간 미정) |
| 서버 운영 기록 | 요청 시각, 처리 결과 코드 등. 요청 내용은 기록하지 않습니다. IP 주소 같은 접속 정보는 Google이 서비스 운영을 위해 처리할 수 있습니다. | Google Cloud 기본 보관 기간(30일) |

추천 카드의 “틀린 내용 알리기”를 누르면 메일 앱이 열리고 도시 이름과 추천 결과의 버전이 미리 채워집니다. 사용자가 직접 보낸 경우에만 받으며, 받은 메일은 문의 답변과 추천 수정에만 씁니다.

AI 제공자(Anthropic)는 받은 정보를 자체 정책에 따라 처리·보관할 수 있습니다. 자세한 내용은 [Anthropic 개인정보 처리방침](https://www.anthropic.com/legal/privacy)을 참고해 주세요.

## 6. 이용 목적

도시 추천, 질문 답변, AI 대화, 사용 한도 확인, 정상적인 앱에서 온 요청인지 확인(부정 이용 방지), 이용 합계로 앱을 고치는 데에만 씁니다. 광고, 추적, 다른 회사 데이터와의 결합에는 쓰지 않습니다.

## 7. 처리를 맡기는 곳(제3자)

- Google LLC (Firebase): 중계 서버 운영, 익명 ID, 앱 확인(App Check). 처리 지역: 미국
- Anthropic PBC: AI 모델로 추천, 답변, 대화 응답·요약 생성. 처리 지역: 미국
- Apple Inc.: 사진 위치의 장소 이름 변환, 정상 앱 확인(App Attest), 같은 기기의 무료 한도 확인(DeviceCheck), 구독 결제와 구독 확인

## 8. 국외 이전

4번의 정보는 추천, 질문, AI 대화를 요청할 때마다 인터넷을 통해 미국에 있는 Google과 Anthropic의 서버로 전송되어 처리됩니다. 이전을 원하지 않으면 추천·질문·AI 대화 기능을 쓰지 않거나 지난 여행 평가 전송을 끌 수 있습니다. 이 경우 해당 기능을 이용할 수 없거나 평가 없이 추천됩니다.

## 9. 사용자의 권리와 삭제

- 기기에 저장된 정보는 앱에서 직접 보고, 고치고, 지울 수 있습니다.
- 설정 > 데이터 삭제 > 모든 데이터 지우기를 하면 기기의 모든 기록(AI 대화 포함)과 서버의 익명 ID를 삭제합니다. 인터넷에 연결되지 않아 서버 삭제에 실패하면 기기에서 연결을 끊고, 다음부터 새 익명 ID를 씁니다.
- 모든 데이터 지우기는 iCloud에 있는 백업도 지웁니다. 백업을 지우지 못하면 기기 기록도 지우지 않고 그 사실을 알립니다.
- 모든 데이터 지우기나 앱 재설치를 해도, 같은 기기에서는 그 달의 무료 한도가 다시 생기지 않습니다. 다음 달 1일(UTC)에 다시 생깁니다.
- 구독 사용 횟수(AI 사용량 포함)는 익명 ID와 연결되어 있지 않아 모든 데이터 지우기로 지워지지 않으며, 결제 주기가 끝나고 7일 뒤 자동으로 삭제됩니다. 구독 해지와 환불은 Apple 계정의 구독 설정에서 합니다.
- 그 밖의 열람·정정·삭제·처리 정지 요청은 위 이메일로 보내 주세요.

## 10. 아동

앱은 만 14세 미만 아동을 대상으로 하지 않으며, 만 14세 미만 아동의 정보를 알면서 받지 않습니다.

## 11. 보호 조치

AI 제공자의 키는 서버에만 두고 앱에는 넣지 않습니다. 서버는 정상 앱(App Check)과 익명 ID 확인을 거친 요청만 처리하며, 모든 전송은 암호화(HTTPS)됩니다.

## 12. 방침의 변경

이 방침을 바꾸면 이 페이지에 시행일과 함께 게시하고, 보내는 정보나 받는 곳이 달라지는 경우에는 앱 안에서 다시 안내하고 동의를 받습니다.

---

# TripDNA Privacy Policy

Effective date: November 2, 2026

TripDNA (“the app”) suggests your next destination based on your past trips. This policy explains what the app keeps where, what it sends to whom, and how long it is kept.

## 1. Operator and contact

- Operator: Park Jiho
- Privacy officer: Park Jiho
- Contact: joe45dev@gmail.com

## 2. Information kept only on your device

Your trips, ratings and notes, copies of photos you choose, preferences such as wanted trips and remembered tastes, and recommendation results are stored only on your device. The operator does not collect them on a server. Deleting the app deletes them.

If the device is signed in to iCloud, these records (including photo copies) are backed up to your Apple account's iCloud. Backup is on by default and can be turned off in Settings > iCloud backup. The backup is stored in Apple's iCloud and the operator cannot see it. It is used only to restore your records on a new device with the same Apple account.

## 3. Photo access

If you allow photo access, the app uses photo dates and locations to find past trips, lets you pick photos for a trip day, and saves share cards to your library. Photo files never leave your device. To turn a photo’s location into a place name, its coordinates are sent to Apple’s location service.

## 4. Information sent for recommendations, questions, and AI chat

City recommendations, answers to questions about a city, and AI chat replies are written by an external AI model. To do this, the app sends the information below through the operator’s relay server to the AI provider. Before your first recommendation and before your first AI chat, the app shows what will be sent and asks for your consent.

- Always sent: the trip concept you chose, trip conditions (timing, length, party size, budget, etc.), text you typed, your wanted trips, and your question with the city it is about
- Always sent for AI chat: your chat messages, the number of past trips per concept, your wanted-trip tiers and avoid note, and your saved cities (name, country, condition summary)
- Sent only if you agree: star ratings and notes from up to 10 recent trip reviews (up to 500 characters per note), and cities you have visited. For AI chat, the trip list (places, dates, concepts, satisfaction) and these reviews are also sent only in this case.
- Never sent: photo files, location history, your name or contact details

You can turn off sending past trip reviews at any time in Settings > Permissions and shared info. It stops from the next request. Information already sent cannot be recalled from the app. If you turn it off, chats that started with reviews included can be read but not continued.

AI chat text is stored only on your device (including your iCloud backup), not on our server. To write a reply, the app sends a summary of earlier messages and the recent messages. When a chat gets long, the earlier part is sent once more to be summarized. AI chat can use web search.

## 5. Information kept on the server

| Item | Details | Retention |
| --- | --- | --- |
| Anonymous ID | A random identifier created automatically for each install without sign-in (Google Firebase). It is not linked to a name or email. | Until you use Delete all data in the app |
| Usage count | Monthly number of recommendations and AI usage amount (cost-based, including pending reservations and recently settled request IDs) per anonymous ID, used to check the free limit, and whether the device check was done that month | Deleted 7 days after the month ends |
| Subscription usage count | For subscribers, the number of recommendations and the AI usage amount (cost-based, including pending reservations and recently settled request IDs) in each billing period, counted per original transaction ID of the Apple subscription. To check the subscription, the app sends the current subscription transaction (data signed by Apple) with the request; the server checks only the signature, product, expiry, and refund status and does not store the transaction itself. This record does not include the anonymous ID. | Deleted 7 days after the billing period ends |
| Device check | So that reinstalling the app or deleting data does not give the same device the free limit again, the first request each month uses Apple DeviceCheck to check and mark whether this device already received the free limit this month. Apple keeps only two values and the month they were last set for each device; our server does not store the device token used for the check. | Device token not stored. The device mark is kept by Apple |
| Request and response content | Not stored. The relay server only passes it on. | Not kept |
| Usage totals | Daily counts of certain actions, used to improve the app (for example, how many recommendations were received, how many cards were shared, how many cities were removed from recommendations). Only numbers are added, with no anonymous ID or device information, so no one can tell who did what. | No limit (totals that cannot identify anyone) |
| Operating cost totals | To understand AI call costs, daily numbers of calls started, calls whose cost was confirmed with the total cost, and calls whose cost could not be confirmed. Only numbers per date are added, with no anonymous ID or device information. | (retention period not yet set) |
| Server operation logs | Request time, result code and similar. Request content is not logged. Google may process connection data such as IP addresses to run its service. | Google Cloud default retention (30 days) |

If you tap “Report a problem” on a recommendation card, your mail app opens with the city name and the recommendation’s version filled in. We receive it only if you send it, and use it only to reply and fix recommendations.

The AI provider (Anthropic) may process and keep what it receives under its own policy. See the [Anthropic Privacy Policy](https://www.anthropic.com/legal/privacy).

## 6. Purpose of use

Only to create recommendations, answers, and AI chat replies, check usage limits, confirm requests come from the genuine app (abuse prevention), and improve the app using usage totals. Never for advertising, tracking, or combining with other companies’ data.

## 7. Service providers (third parties)

- Google LLC (Firebase): relay server, anonymous ID, app verification (App Check). Location: United States
- Anthropic PBC: AI model that writes recommendations, answers, chat replies, and summaries. Location: United States
- Apple Inc.: place names for photo locations, genuine app verification (App Attest), free limit check for the same device (DeviceCheck), subscription payment and verification

## 8. International transfer

Each time you request a recommendation, ask a question, or chat with the AI, the information in section 4 is sent over the internet to Google and Anthropic servers in the United States for processing. If you do not want this, you can avoid the recommendation, question, and AI chat features or turn off sending past trip reviews; those features will then be unavailable or work without your reviews.

## 9. Your rights and deletion

- You can view, edit, and delete information on your device directly in the app.
- Settings > Delete data > Delete all data removes all records on the device (including AI chats) and the anonymous ID on the server. If the server deletion fails because you are offline, the device disconnects from that ID and uses a new one from then on.
- Delete all data also deletes the iCloud backup. If the backup cannot be deleted, the records on the device are kept and the app tells you.
- Deleting all data or reinstalling the app does not restore that month’s free limit on the same device. It comes back on the 1st of the next month (UTC).
- The subscription usage count (including AI usage) is not linked to the anonymous ID, so Delete all data does not remove it; it is deleted automatically 7 days after the billing period ends. Cancellations and refunds are handled in your Apple account’s subscription settings.
- For any other access, correction, deletion, or restriction request, email the address above.

## 10. Children

The app is not intended for children under 14, and we do not knowingly receive information from children under 14.

## 11. Security

The AI provider key is kept only on the server, never in the app. The server only handles requests that pass genuine-app (App Check) and anonymous ID checks, and all transfers are encrypted (HTTPS).

## 12. Changes

If this policy changes, the new version is posted on this page with its effective date. If what is sent or who receives it changes, the app will tell you again and ask for consent.

---
