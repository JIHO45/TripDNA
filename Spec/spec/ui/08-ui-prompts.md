# UI 생성 프롬프트 — 온보딩 핵심 화면 (v0 / Stitch / Figma Make 등 입력용)

전제: [07-onboarding-ui-flow.md](07-onboarding-ui-flow.md)의 P0~P3 중 핵심 6화면.
프롬프트는 영어 (생성 툴 품질이 영어에서 안정적), 화면 내 카피는 한국어로 지정.
각 프롬프트는 단독 입력 가능하도록 디자인 시스템 요약을 포함합니다.

## 0. 공통 디자인 시스템 (모든 프롬프트 앞에 붙여도 됨)

```text
Design system for a travel taste-profiling app called "Travel Fingerprint":
- Mood: calm, premium, science-backed — like RISE sleep app's onboarding. Dark theme only.
- Background: deep navy (#0B1020) with subtle aurora gradient glows (indigo #4F46E5 → teal #2DD4BF), never flat black.
- Typography: bold white headlines (Pretendard or SF Pro), muted slate-gray body text (#94A3B8). Korean text.
- Components: large rounded cards (24px radius), soft inner glow, generous whitespace, one primary action per screen.
- Accent: warm coral (#FF6B5E) used ONLY for the primary CTA button (full-width, pill shape, bottom-fixed).
- Motif: a "travel fingerprint" — concentric fingerprint-like ridges drawn from travel data, glowing line art.
- Progress: thin segmented progress bar at top. Always show a subtle "건너뛰기" (skip) text button top-right.
- Mobile: iPhone 15 Pro frame, 393×852, single screen, no scrolling.
```

## 1. P0-1 — 훅 화면

```text
Mobile onboarding hook screen (iPhone 15 Pro, 393×852), dark navy background (#0B1020) with aurora gradient glow (indigo→teal). Style: RISE sleep app onboarding — calm, premium, mysterious.

Center: a large glowing fingerprint made of thin travel-route lines — the ridges of the fingerprint are actually flight paths and coastlines, drawn in gradient line art (indigo to teal), mid-animation as if being drawn.

Headline (Korean, bold, white, 32px, 2 lines): "지금까지의 여행이,\n다음 여행지를 알고 있어요"
No sub-paragraph, no "Welcome" text, no logo prominence — curiosity hook only.

Bottom: full-width coral (#FF6B5E) pill button "시작하기". Below it, tiny muted text: "약 2분이면 끝나요".
No sign-in options on this screen.
```

## 2. P1-1 — 과거 여행 등록 방식 선택

```text
Mobile onboarding choice screen (iPhone 15 Pro, 393×852), dark navy (#0B1020), aurora gradient accents.

Headline (white, bold, 26px): "지난 여행을\n어떻게 불러올까요?"

Center: two equal-size rounded choice cards stacked vertically.
Card 1: map-pin and photo icon, title "사진첩에서 자동으로 찾기", subtitle "사진 위치를 기기 안에서 분석해 국가와 시기를 채워드려요", small teal badge "빠르게 등록".
Card 2: edit icon, title "직접 입력하기", subtitle "사진 권한 없이 국가와 시기를 직접 입력해요".

Neither card is preselected or visually treated as mandatory.
Bottom: plain text button "여행 이력이 없어요 · 사진 퀴즈로 시작".
```

## 3. P1-2 — 사진첩 프라이밍 (권한 요청 직전)

```text
Mobile permission-priming screen (iPhone 15 Pro, 393×852), dark navy (#0B1020), aurora gradient accents. Style: RISE-like trust-building screen shown BEFORE the OS photo permission dialog.

Top: thin segmented progress bar (step 2 of 5 filled), "건너뛰기" text button top-right.

Center: a dark world map (dot-matrix style, slate dots) with 4–5 glowing teal location pins dropping onto it, each pin with a soft ripple. One pin expanded into a small card showing a blurred travel photo thumbnail + label "포르투갈 · 2023년 5월".

Headline (white, bold, 26px): "다녀온 곳을\n지도에서 찾아드릴까요?"

Below, a trust panel — rounded card (#131A2E) with a shield-lock icon and Korean text: "사진 위치는 기기 안에서만 분석돼요. 서버로 전송되지 않아요." This trust line must be visually prominent.

Bottom: coral pill button "사진 접근 허용하고 찾기", below it a plain text button "직접 입력으로 바꾸기".
```

## 4. P2-A — 여행 확인 카드 (만족도 원탭)

```text
Mobile quiz-style card screen (iPhone 15 Pro, 393×852), dark navy (#0B1020). Style: RISE onboarding — one screen, one question, big tap targets.

Top: segmented progress bar + counter "3 / 8", "나머지는 나중에" text button top-right.

Center: one large rounded card (#131A2E, 24px radius, soft glow) filling ~60% of the screen:
- Card top: travel photo collage strip (3 small photos from that trip, rounded).
- Country flag emoji + title "포르투갈" (white, bold, 24px), subtitle "2023년 5월 · 리스본" (slate gray).
- Question (white, 18px): "이 여행, 얼마나 좋았나요?"
- A single row of 5 large circular emoji rating buttons (😞 😕 😐 😊 🤩), evenly spaced, 56px each, subtle outline; the 5th one shown pressed with a teal glow ring.

Below the card: small ghost-text button "이 여행 아니에요".
No keyboard, no sliders, no multi-select — one tap answers the screen.
```

## 5. P2-A 변형 — 서열 비교 원탭 (같은 카드의 두 번째 질문)

```text
Mobile A/B comparison screen (iPhone 15 Pro, 393×852), dark navy (#0B1020). Style: RISE onboarding follow-up question — playful but minimal.

Top: same segmented progress bar "3 / 8".

Headline (white, bold, 22px, center): "둘 중 어느 여행이\n더 좋았나요?"

Center: two tall rounded photo cards side by side (each ~45% width, 3:4 ratio):
- Left card: photo of Lisbon tram, label "포르투갈 · 2023" with flag emoji.
- Right card: photo of Kyoto temple, label "일본 · 2022" with flag emoji.
Cards look tappable (soft border glow on hover state shown on the left one).

Between them: a small circular "VS" badge in slate gray.
Below: ghost text button "비슷했어요 / 기억 안 나요".
One tap completes the screen. No other UI.
```

## 6. P3-2 — 지문 공개 (페이오프 1)

```text
Mobile results-reveal screen (iPhone 15 Pro, 393×852), dark navy (#0B1020) with stronger aurora glow than previous screens — this is the payoff moment. Style: RISE "your sleep need" reveal.

Top: small text "당신의 여행 지문" (slate gray, uppercase feel).

Center: a large radar/fingerprint hybrid visualization — 5-axis radar chart whose filled shape is rendered as glowing concentric fingerprint ridges (indigo→teal gradient). Axis labels in Korean around it: "자연↔도시", "고요↔활동", "즉흥↔계획", "혼자↔함께", "익숙함↔새로움".
Two of the five axes are rendered dimmer/blurred with a tiny "아직 흐려요" caption — honest low-confidence state.

Headline below the chart (white, bold, 24px): "당신은 '고요한 자연' 쪽에\n가까운 여행자예요"
Sub-text (slate): "여행을 평가할수록 지문이 선명해져요"

Bottom: coral pill button "내게 맞는 여행지 보기".
```

## 7. P3-3 — 첫 추천 3슬롯 (페이오프 2)

```text
Mobile recommendation screen (iPhone 15 Pro, 393×852), dark navy (#0B1020). Style: premium travel app result feed, RISE-level polish.

Top: headline (white, bold, 24px): "당신의 지문으로 찾은\n다음 여행지". Small fingerprint icon beside it.

Vertical stack of 3 recommendation cards (rounded 24px, each with a full-bleed destination photo, dark gradient overlay at bottom):
1. Card labeled with teal chip "가장 잘 맞아요" — "조지아", reason line in Korean quoting the user's own tags: "당신이 고른 '고요함'과 '대자연'을 닮았어요".
2. Card with indigo chip "새로운 도전" — "슬로베니아", reason: "익숙한 취향에서 반 발짝 바깥".
3. Card with amber chip "숨은 보석" — "라오스", reason: "당신 같은 여행자들의 만족도가 높아요".

Each card: small save (bookmark) icon and an X (dislike) icon — the dislike icon must be visible, not hidden in a menu.
Bottom safe area: plain text button "지문 다시 보기".
```

## 8. 사용 메모

- 툴에 넣을 때: 0절 디자인 시스템 블록 + 화면 프롬프트 1개를 함께 입력하면 일관성이 좋아짐.
- 화면 간 일관성이 깨지면 "same design system as previous screen" 한 줄 추가.
- 이미지 생성형(미드저니 등)보다 코드 생성형(v0, Stitch)에 맞춰 작성됨 — 이미지형에 쓸 땐
  마지막 줄에 "UI mockup, dribbble style, high fidelity" 추가.
- 카피는 07 문서의 카피 방향 초안이며 UX 라이팅 확정 전 플레이스홀더.
