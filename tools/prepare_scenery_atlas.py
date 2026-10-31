"""Pack existing scenery cutouts and native Cyrillic signage; no new tree art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
out=Image.new('RGBA',(2048,3072))
for i,name in enumerate(['pine_tree.png','oak_tree.png','level2/wheat_tuft.png','street_lamp.png']):
    image=Image.open(ROOT/'assets'/name).convert('RGBA')
    image.thumbnail((496,496),Image.Resampling.LANCZOS)
    out.alpha_composite(image,(i*512+(512-image.width)//2,(512-image.height)//2))
draw=ImageDraw.Draw(out)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
names=['ЗОЛОТЫЕ ПОЛЯ','ЛУННЫЙ МОСТ','ЛЕСНОЙ СПУСК','ПОДЗЕМНЫЙ ТОННЕЛЬ','ОКРАИНЫ ГОРОДА','ОГНИ ГОРОДА']
for row,name in enumerate(names):
    top=544+row*80
    draw.rounded_rectangle((8,top+4,1016,top+76),radius=9,fill='#183b38',outline='#c1d8c9',width=4)
    font=ImageFont.truetype(font_path,40)
    draw.text((512,top+40),name,font=font,fill='#e3eee0',anchor='mm')
for row,(name,color) in enumerate([('МАРКЕТ 24','#59f9b5'),('КАФЕ • 24','#fe8cbf'),('АВТОСЕРВИС','#71d9ff'),('АПТЕКА','#91e797'),('ЦВЕТЫ','#efafd6'),('ПЕКАРНЯ','#f5c879'),('АРКАДА','#a9a0ff'),('ДИНЕР • 24','#f0a070')]):
    top=544+row*112
    draw.rounded_rectangle((1032,top+4,2040,top+108),radius=8,fill='#12212c',outline=color,width=5)
    font=ImageFont.truetype(font_path,50)
    draw.text((1536,top+56),name,font=font,fill=color,anchor='mm',stroke_width=1)
for row,(name,color) in enumerate([('FOREST • VISITOR CENTRE','#65e9ff'),('PINE • GLAMPING','#aef0b4'),('GOLDEN FIELDS • ESTATE','#ffdc95'),('GRAIN • AGRITECH','#a9e8ff'),('SKYLINE • OBSERVATORY','#65e9ff'),('FOREST • LOUNGE','#ffd295'),('LUNA OIL • 24','#65e9ff'),('NIGHT DINER','#ff7ab8'),('95 • 98 • ДИЗЕЛЬ','#b4ecd9')]):
    top=1056+row*48
    draw.rounded_rectangle((8,top+2,1016,top+46),radius=5,fill='#09131e',outline=color,width=2)
    draw.text((512,top+24),name,font=ImageFont.truetype(font_path,29),fill=color,anchor='mm')
draw.rectangle((2024,1512,2047,1535),fill='white')
# Immutable generated source, cropped/packed with four-pixel extrusion.
# The source is excluded from Android; only the shared compressed atlas ships.
facades=Image.open(ROOT/'assets/level2/source/neon_facades.png').convert('RGBA')
for tile in range(8):
    col,row=tile%2,tile//2
    box=(round(col*facades.width/2),round(row*facades.height/4),round((col+1)*facades.width/2),round((row+1)*facades.height/4))
    panel=facades.crop(box).resize((760,248),Image.Resampling.LANCZOS)
    x,y=col*768,1536+row*256
    out.paste(panel,(x+4,y+4))
    out.paste(panel.crop((0,0,1,248)).resize((4,248)),(x,y+4))
    out.paste(panel.crop((759,0,760,248)).resize((4,248)),(x+764,y+4))
    out.paste(out.crop((x,y+4,x+768,y+5)).resize((768,4)),(x,y))
    out.paste(out.crop((x,y+251,x+768,y+252)).resize((768,4)),(x,y+252))
# Small code-authored materials and precise instrumentation replace tiny meshes.
import math
for y in range(256):
    shade=int(22+8*math.sin(y*.025)+3*math.sin(y*1.9))
    draw.line((0,2816+y,511,2816+y),fill=(shade,shade+6,shade+13,255))
    draw.line((512,2816+y,1023,2816+y),fill=(12,24,35,255))
    draw.line((1536,2816+y,2047,2816+y),fill=(31+y//24,39+y//24,47+y//24,255))
for x in range(0,512,128): draw.line((x,2816,x,3071),fill='#0b111c',width=2)
for y in range(2848,3072,64): draw.line((0,y,511,y),fill='#111923',width=2)
for x in range(520,1024,128):
    for y in range(2824,3072,64):
        draw.rectangle((x,y,x+112,y+48),fill='#112635',outline='#365465',width=2)
        for line in range(1,5): draw.line((x+line*22,y,x+line*22,y+48),fill='#223e51')
for y in range(2816,3072,64):
    draw.line((1536,y,2047,y),fill='#141f29',width=2)
    for x in range(1536+((y//64)%2)*64,2048,128): draw.line((x,y,x,y+64),fill='#141f29',width=2)
for pump in range(4):
    x=1024+pump*128
    accent=['#68e6ff','#bdf38f','#ffcc79','#ea93ef'][pump]
    draw.rectangle((x,2816,x+127,3071),fill='#192a3b')
    draw.rectangle((x+8,2824,x+119,3038),fill='#293c4b',outline='#778e9e',width=3)
    draw.rectangle((x+12,2830,x+115,2869),fill=accent)
    draw.text((x+64,2850),['95','98','D','EV'][pump],font=ImageFont.truetype(font_path,29),fill='#091827',anchor='mm')
    draw.rounded_rectangle((x+18,2880,x+109,2926),radius=3,fill='#09151f',outline='#82b8c9',width=2)
    draw.text((x+64,2903),'00.00',font=ImageFont.truetype(font_path,19),fill='#bdf9e9',anchor='mm')
    draw.rectangle((x+22,2940,x+55,2974),fill='#17232e',outline='#91a7ad',width=2)
    draw.line((x+87,2940,x+102,2953,x+92,3009,x+77,3014),fill='#091119',width=8)
    draw.rectangle((x+85,2937,x+96,2956),fill='#a3bac7')
    draw.text((x+64,3026),'LUNA',font=ImageFont.truetype(font_path,13),fill=accent,anchor='mm')
# One 2048x2560 atlas: keep facade resolution near the generated source width.
packed=out.crop((0,0,2048,2560))
for tile in range(4):
    packed.paste(out.crop((tile*512,2816,(tile+1)*512,3072)),(1536,1536+tile*256))
packed.save(ROOT/'assets/level2/scenery_atlas.png',optimize=True)
