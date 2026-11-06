# App Store 스크린샷 HTML 생성. 2026-11-07.
# 다른 앱(Airbnb, 마이리얼트립 등)처럼 단색 배경 + 위 두 줄 문구 + 아래로 잘리는 큰 휴대폰. 장식은 넣지 않는다.
# 6장 모두 문구·휴대폰 위치가 같다. 보여줄 부분은 앱 안에서 스크롤해 맞춘다.
# captures/{번호}-{언어}-{기기}.png는 -uiDemo appStore로 띄운 시뮬레이터 캡처다.
# 실행: python3 make.py 후 out/*.html을 Chrome headless로 렌더링(docs/app-store-submission.md 참고).
import os
d = os.path.dirname(os.path.abspath(__file__))
SIZE = {'iphone': (1320, 2868), 'ipad': (2064, 2752)}
SHOTS = {
    1: {'ko': ('지난 여행의 취향으로', '다음 여행지를 골라요'), 'en': ('From the trips you loved', 'Find your next destination')},
    2: {'ko': ('좋았던 점, 아쉬웠던 점', '여행마다 남겨두세요'), 'en': ("What you loved, what you didn't", 'Saved with every trip')},
    3: {'ko': ('궁금한 건', 'AI에게 바로 물어보세요'), 'en': ('Questions about a city?', 'Just ask')},
    4: {'ko': ('왜 이 도시인지', '이유까지 알려드려요'), 'en': ('Why this city', 'The reasons come with it')},
    5: {'ko': ('내가 좋아하는 여행이', '한눈에 보여요'), 'en': ('See the kind of travel', 'you keep coming back to')},
    6: {'ko': ('올해 다녀온 여행을', '한 번에 돌아봐요'), 'en': ('Look back on', 'your year of travel')},
}
# iPad는 기기 테두리 없이, 실제 화면에서 잘라낸 핵심 영역을 얇은 테두리 사각 카드로 넣는다.
# 캡처 px 기준 (왼쪽, 위, 오른쪽, 아래). 카드 시작 위치·좌우 여백은 6장 모두 같고 높이만 내용에 맞춘다.
# 같은 폭(앱 내용 열 1385px)을 잘라 글자 배율을 맞춘다. 3번은 대화 열, 6번은 화면 전체 폭이라 예외.
CARD = {
    1: (340, 200, 1725, 1510),    # 추천 카드
    2: (340, 300, 1725, 1715),    # 평가와 하루 한 장
    3: (660, 345, 2030, 1090),    # 질문·답변. 이 장만 iOS 글자 크기를 '아주 크게'(XXL)로 찍었다
    4: (340, 193, 1725, 1600),    # 도시 상세
    5: (340, 193, 1725, 1690),    # 지문 요약
    6: (0, 280, 2064, 2420),     # Wrapped 사진 격자
}
# 영어는 문장이 길어 줄이 늘어나는 장만 따로 잡는다.
CARD_EN = {
    3: (660, 385, 2030, 1125),
    4: (340, 193, 1725, 1660),
}
CARD_TOP, CARD_SIDE = 700, 150
os.makedirs(f'{d}/out', exist_ok=True)
for n, langs in SHOTS.items():
    for lang, (small, big) in langs.items():
        for device, (w, h) in SIZE.items():
            cap = f'captures/{n}-{lang}-{device}.png'
            if not os.path.exists(f'{d}/{cap}'):
                continue
            # iPad는 화면이 정사각형에 가까워 기기를 작게 넣고 문구 크기를 iPhone 높이 비율로 맞춘다.
            k = 1.0 if device == 'iphone' else h / 2868 * 1.35
            phone_w = round(w * (0.96 if device == 'iphone' else 0.80))
            pad = round(22 * k)
            top = round(640 * k)  # 6장 모두 같은 위치. 아래쪽은 잘린다.
            screen = f'<div class="p"><img src="../{cap}"></div>'
            if device == 'ipad':
                x0, y0, x1, y1 = (CARD_EN if lang == 'en' else {}).get(n, CARD[n])
                cw = w - 2 * CARD_SIDE
                s = cw / (x1 - x0)
                top = CARD_TOP
                screen = (f'<div style="position:absolute;left:{CARD_SIDE}px;top:{top}px;width:{cw}px;height:{round((y1 - y0) * s)}px;'
                          f'overflow:hidden;border:3px solid #E2DED6;border-radius:36px;background:#fff;box-shadow:0 20px 60px rgba(16,24,43,.08)">'
                          f'<img src="../{cap}" style="display:block;width:{round(w * s)}px;max-width:none;'
                          f'margin-left:{-round(x0 * s)}px;margin-top:{-round(y0 * s)}px"></div>')
            html = f'''<!doctype html><html lang="{lang}"><meta charset="utf-8"><style>
*{{margin:0;box-sizing:border-box}}
body{{width:{w}px;height:{h}px;overflow:hidden;background:#F5F3EF;font-family:-apple-system,"SF Pro Display","Apple SD Gothic Neo",sans-serif;text-align:center}}
.t{{height:{top}px;display:flex;flex-direction:column;justify-content:center;padding-bottom:{round(40*k)}px}}
.s{{font-size:{round(64*k)}px;font-weight:500;color:#6B7280;letter-spacing:-.5px}}
.b{{margin-top:{round(16*k)}px;font-size:{round(100*k)}px;font-weight:700;color:#10182B;letter-spacing:-1.5px}}
.p{{position:absolute;left:{(w-phone_w)//2}px;top:{top}px;width:{phone_w}px;padding:{pad}px;background:#10182B;border-radius:{round(150*k)}px}}
.p img{{width:100%;display:block;border-radius:{round(130*k)}px}}
</style><body><div class="t"><div class="s">{small}</div><div class="b">{big}</div></div>
{screen}</body></html>'''
            open(f'{d}/out/{n}-{lang}-{device}.html', 'w').write(html)
