# App Store 공용 크리에이티브(16:9 5244x2950) HTML 생성. 2026-11-07.
# 실행: python3 make.py 후 각 HTML을 Chrome headless로 렌더링(docs/app-store-submission.md 참고).
# reco-*.png는 -uiDemo recoResult로 띄워 조건 요약을 접은 iPhone 18 Pro Max 시뮬레이터 캡처다.
import sys,os
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
    g='''<div class="g" style="left:410px;top:351px;width:4424px;height:2248px;border-color:#00f"></div>
<div class="g" style="left:0;top:351px;width:5244px;height:2248px;border-color:#f0f"></div>
<div class="g" style="left:410px;top:0;width:4424px;height:2950px;border-color:#0a0"></div>''' if guide else ''
    html=f'''<!doctype html><html lang="{lang}"><meta charset="utf-8"><style>
*{{margin:0;box-sizing:border-box}}
body{{width:5244px;height:2950px;overflow:hidden;background:#fff;position:relative;font-family:-apple-system,"SF Pro Display","Apple SD Gothic Neo",sans-serif;color:#10182B}}
.blob{{position:absolute;left:2500px;top:200px;width:2500px;height:2500px;border-radius:50%;background:radial-gradient(circle,#FDE8EB 0%,#fff 68%)}}
.left{{position:absolute;left:640px;top:0;height:2950px;width:2200px;display:flex;flex-direction:column;justify-content:center}}
.brand{{display:flex;align-items:center;gap:56px;margin-bottom:120px}}
.brand img{{width:250px;height:250px;border-radius:56px}}
.brand span{{font-size:120px;font-weight:700;letter-spacing:-2px}}
h1{{font-size:{210 if lang=="en" else 220}px;line-height:1.08;font-weight:800;letter-spacing:{-6 if lang=="en" else -4}px}}
h1 em{{font-style:normal;color:#D93A50}}
p{{margin-top:100px;font-size:136px;line-height:1.3;color:#5B6270;font-weight:600;letter-spacing:-2px}}
.card{{position:absolute;width:1000px;height:667px;border-radius:64px;background-size:cover;background-position:center;box-shadow:0 40px 120px rgba(16,24,43,.18)}}
.phone{{position:absolute;left:3180px;top:400px;height:2150px;width:{round(2150*1320/2868)+60}px;padding:30px;background:#10182B;border-radius:170px;box-shadow:0 60px 160px rgba(16,24,43,.28)}}
.phone img{{width:100%;height:100%;border-radius:140px;display:block}}
.g{{position:absolute;border:8px dashed}}
</style><body>
<div class="blob"></div>
<div class="card" style="left:2560px;top:560px;transform:rotate(-7deg);background-image:url(../../../TripDNA/Resources/CityPhotos/jp-kyoto.jpg)"></div>
<div class="card" style="left:3880px;top:500px;transform:rotate(6deg);background-image:url(../../../TripDNA/Resources/CityPhotos/pt-lisbon.jpg)"></div>
<div class="card" style="left:3900px;top:1780px;transform:rotate(-4deg);background-image:url(../../../TripDNA/Resources/CityPhotos/es-barcelona.jpg)"></div>
<div class="phone"><div style="position:relative;height:100%;border-radius:140px;overflow:hidden"><img src="reco-{lang}.png">{covers(lang)}</div></div>
<div class="left"><div class="brand"><img src="../../../TripDNA/Assets.xcassets/AppIcon.appiconset/AppIcon.png"><span>TripDNA</span></div><h1>{h}</h1><p>{s}</p></div>
{g}</body></html>'''
    open(f'{d}/{lang}{"-guide" if guide else ""}.html','w').write(html)
