"""Render the repository-owned geometric app icon using Pillow."""
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parent/'resources'
for pixels in (60,76,120,152,167,180):
    scale=4*pixels/180
    image=Image.new('RGB',(pixels*4,pixels*4),'#1765d1');draw=ImageDraw.Draw(image)
    rect=lambda coords:tuple(round(x*scale) for x in coords)
    draw.rounded_rectangle(rect((38,22,142,158)),radius=round(12*scale),fill='#a8ccff')
    draw.rounded_rectangle(rect((46,30,134,150)),radius=round(7*scale),fill='#eff6ff')
    draw.rounded_rectangle(rect((24,72,156,108)),radius=round(5*scale),fill='#142d52')
    for x,y in ((24,72),(156,72),(24,108),(156,108)):
        draw.ellipse(rect((x-7,y-7,x+7,y+7)),fill='white')
    image.resize((pixels,pixels),Image.Resampling.LANCZOS).save(root/f'Icon-{pixels}.png')
