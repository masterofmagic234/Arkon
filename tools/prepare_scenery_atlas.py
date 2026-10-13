"""Pack existing scenery cutouts and native Cyrillic signage; no new tree art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
out=Image.new('RGBA',(2048,1536))
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
for row,(name,color) in enumerate([('МАРКЕТ 24','#59f9b5'),('КАФЕ • 24','#fe8cbf'),('АВТОСЕРВИС','#71d9ff')]):
    top=1088+row*96
    draw.rounded_rectangle((8,top+4,1016,top+92),radius=8,fill='#12212c',outline=color,width=5)
    font=ImageFont.truetype(font_path,45)
    draw.text((512,top+48),name,font=font,fill=color,anchor='mm',stroke_width=1)
draw.rectangle((2024,1512,2047,1535),fill='white')
out.save(ROOT/'assets/level2/scenery_atlas.png',optimize=True)
