# App Store 공용 크리에이티브(16:9 5244x2950) HTML 생성. 2026-11-07.
# 실행: python3 make.py 후 각 HTML을 Chrome headless로 렌더링(docs/app-store-submission.md 참고).
# reco-*.png는 -uiDemo recoResult로 띄워 조건 요약을 접은 iPhone 18 Pro Max 시뮬레이터 캡처다.
import sys,os
# 배치 기준(2026-11-07 App Store Connect 미리보기에서 잰 값, 5244x2950 기준):
# iPhone은 x 1230~4020, y 50~1890만 보이고 위 약 300px은 상태 표시줄·버튼에 가린다.
# iPad는 x 250~4980, y 360~1780만 보이고 위 가운데(x 2140~3076, y ~625까지)는 탭 메뉴에 가린다.
# 그래서 문구와 추천 카드는 가운데 띠(x 1230~4020, y 650~1780) 안에 둔다.
d=os.path.dirname(os.path.abspath(__file__))

COVER={'en':[(0,2110,1320,500)],'ko':[(0,1930,1320,470)]}
def covers(lang):
  s=''.join(f'<div style="position:absolute;background:#fff;left:{x/13.2}%;top:{y/28.68}%;width:{w/13.2}%;height:{h/28.68}%"></div>' for x,y,w,h in COVER[lang])
  # 영어는 AI 버튼 뒤에 카드 배경이 깔려 있어, 배경이 흰 한국어 캡처의 같은 자리(버튼 모양 동일)를 얹는다.
  if lang=='en':
    x,y,w,h=1060,2380,260,230
    s+=f'<div style="position:absolute;left:{x/13.2}%;top:{y/28.68}%;width:{w/13.2}%;height:{h/28.68}%;background:url(reco-ko.png) {x/(1320-w)*100}% {y/(2868-h)*100}%/{1320/w*100}% auto"></div>'
  return s
T={'en':('Let your past trips<br>pick your<br><em>next destination.</em>','Rate past trips.<br>Find your next city.'),
   'ko':('지난 여행이<br><em>다음 여행지</em>를 골라요','다녀온 여행을 평가하고<br>다음 도시를 찾아요.')}
for lang,(h,s) in T.items():
  for guide in (0,1):
    g='''<div class="g" style="left:1230px;top:50px;width:2790px;height:1840px;border-color:#0a0"></div>
<div class="g" style="left:250px;top:360px;width:4730px;height:1420px;border-color:#f0f"></div>
<div class="g" style="left:2140px;top:360px;width:936px;height:265px;border-color:#f80;background:rgba(255,136,0,.15)"></div>''' if guide else ''
    html=f'''<!doctype html><html lang="{lang}"><meta charset="utf-8"><style>
*{{margin:0;box-sizing:border-box}}
body{{width:5244px;height:2950px;overflow:hidden;background:#fff;position:relative;font-family:-apple-system,"SF Pro Display","Apple SD Gothic Neo",sans-serif;color:#10182B}}
.blob{{position:absolute;left:2200px;top:-100px;width:2600px;height:2600px;border-radius:50%;background:radial-gradient(circle,#FDE8EB 0%,#fff 68%)}}
.left{{position:absolute;left:1330px;top:650px;height:1130px;width:1500px;display:flex;flex-direction:column;justify-content:center}}
h1{{font-size:140px;line-height:1.1;font-weight:800;letter-spacing:{-4 if lang=="en" else -3}px}}
h1 em{{font-style:normal;color:#D93A50}}
p{{margin-top:60px;font-size:92px;line-height:1.3;color:#5B6270;font-weight:600;letter-spacing:-1px}}
.card{{position:absolute;width:820px;height:547px;border-radius:56px;background-size:cover;background-position:center;box-shadow:0 40px 120px rgba(16,24,43,.18)}}
.phone{{position:absolute;left:3060px;top:460px;width:860px;height:{round(800*2868/1320)+60}px;padding:30px;background:#10182B;border-radius:130px;box-shadow:0 60px 160px rgba(16,24,43,.28)}}
.phone img{{width:100%;height:100%;border-radius:100px;display:block}}
.g{{position:absolute;border:8px dashed}}
</style><body>
<div class="blob"></div>
<div class="card" style="left:3640px;top:380px;transform:rotate(7deg);background-image:url(../../../TripDNA/Resources/CityPhotos/jp-kyoto.jpg)"></div>
<div class="card" style="left:3760px;top:1300px;transform:rotate(-5deg);background-image:url(../../../TripDNA/Resources/CityPhotos/pt-lisbon.jpg)"></div>
<div class="card" style="left:2520px;top:1720px;transform:rotate(-6deg);background-image:url(../../../TripDNA/Resources/CityPhotos/es-barcelona.jpg)"></div>
<div class="phone"><div style="position:relative;height:100%;border-radius:100px;overflow:hidden"><img src="reco-{lang}.png">{covers(lang)}</div></div>
<div class="left"><h1>{h}</h1><p>{s}</p></div>
{g}</body></html>'''
    open(f'{d}/{lang}{"-guide" if guide else ""}.html','w').write(html)
