"""Render the real headless widget snapshot with local native-texture previews.
Preview uses a substitute serif font; the game uses Friz Quadrata.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageOps
import json, math, os, sys
root=Path(__file__).resolve().parents[1]
media=root/'LightTheBeacons/Media'
scene=json.loads(Path(sys.argv[1]).read_text());scale=2;margin=14
W=int(scene['width'])+2*margin;H=int(scene['height'])+2*margin
canvas=Image.new('RGBA',(W,H),(18,19,21,255))
font_candidates=[os.environ.get('LTB_PREVIEW_FONT'),'/usr/share/fonts/TTF/DejaVuSerif.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf','C:/Windows/Fonts/georgia.ttf']
font_path=next((p for p in font_candidates if p and Path(p).is_file()),None)
if not font_path:raise SystemExit('Set LTB_PREVIEW_FONT to a readable serif TrueType font.')
order={None:-1,'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3}
cache={}
manifest=json.loads((media/'sources.json').read_text())
native={item['nativePath']:root/'work'/'native-texture-previews'/item['file']
        for item in manifest.get('nativeTextures',[])}
def asset(file):
    name=file.split('\\')[-1]
    p=native.get(file,media/name)
    if not p.exists():return None
    if name not in cache:cache[name]=Image.open(p).convert('RGBA')
    return cache[name].copy()
def tint(im,color):
    rgba=list(color)+[1]*(4-len(color))
    return ImageChops.multiply(im,Image.new('RGBA',im.size,tuple(round(v*255) for v in rgba)))
def backdrop(w,h,s):
    im=Image.new('RGBA',(w,h));d=s['backdrop'];edge=int(d.get('edgeSize',24));pad=edge//2
    bg=asset(d['bgFile']);bg=tint(bg,s.get('backdropColor',[1,1,1,1]))
    if bg and s.get('part')!='border':
        tile=bg.resize((32,32))
        for x in range(6,w-6,32):
            for y in range(6,h-6,32):
                im.alpha_composite(tile.crop((0,0,min(32,w-6-x),min(32,h-6-y))),(x,y))
    src=asset(d['edgeFile']);src=tint(src,s.get('border',[1,1,1,1]))
    if src and s.get('part')!='background':
        tiles=[src.crop((i*32+2,2,(i+1)*32-2,30)).resize((edge,edge)) for i in range(8)]
        for i,(x,y) in enumerate([(0,0),(w-edge,0),(0,h-edge),(w-edge,h-edge)]):im.alpha_composite(tiles[4+i],(x,y))
        if h>2*edge:
            im.alpha_composite(tiles[0].resize((edge,h-2*edge)),(0,edge))
            im.alpha_composite(tiles[1].resize((edge,h-2*edge)),(w-edge,edge))
        if w>2*edge:
            im.alpha_composite(tiles[2].rotate(-90).resize((w-2*edge,edge)),(edge,0))
            im.alpha_composite(tiles[3].rotate(-90).resize((w-2*edge,edge)),(edge,h-edge))
    return im
items=[]
for item in scene['items']:
    if item.get('backdrop'):
        items.extend([{**item,'part':'background','layer':'BACKGROUND'},{**item,'part':'border','layer':'BORDER'}])
    else:items.append(item)
for s in sorted(items,key=lambda s:(s['frameLevel'],order.get(s.get('layer'),-1),s['id'])):
    x,y,w,h=(round(s[k]) for k in ('x','y','width','height'));x+=margin;y+=margin
    if w<=0 or h<=0:continue
    surface=None
    if s.get('backdrop'):surface=backdrop(w,h,s)
    elif s.get('solid'):
        color=s['solid'];surface=Image.new('RGBA',(w,h),tuple(round(v*255) for v in color))
    elif s['kind']=='Texture' and s.get('file'):
        surface=asset(s['file'])
        if surface:
            if s.get('desaturated'):
                alpha=surface.getchannel('A');surface=ImageOps.grayscale(surface).convert('RGBA');surface.putalpha(alpha)
            if s.get('vertexColor'):surface=tint(surface,s['vertexColor'])
            if s.get('coords'):
                l,r,t,b=s['coords'];surface=surface.crop((round(l*surface.width),round(t*surface.height),round(r*surface.width),round(b*surface.height)))
            surface=surface.resize((w,h),Image.Resampling.LANCZOS)
    elif s['kind'] in ('FontString','EditBox') and s.get('text') is not None:
        # Draw at 2x then downsample to closely approximate in-game font rasterization.
        surface=Image.new('RGBA',(w*scale,h*scale));draw=ImageDraw.Draw(surface)
        font=ImageFont.truetype(font_path,round(s.get('fontSize',12)*scale))
        lines=[]
        for paragraph in str(s['text']).split('\n'):
            if s.get('wrap') is False:
                line=paragraph
                while line and draw.textlength(line,font=font)>w*scale:line=line[:-1]
                lines.append(line)
            else:
                line=''
                for word in paragraph.split(' '):
                    if s.get('nonSpaceWrap') and draw.textlength(word,font=font)>w*scale:
                        if line:lines.append(line);line=''
                        while draw.textlength(word,font=font)>w*scale:
                            cut=len(word)
                            while cut>1 and draw.textlength(word[:cut],font=font)>w*scale:cut-=1
                            lines.append(word[:cut]);word=word[cut:]
                    candidate=(line+' '+word).strip()
                    if line and draw.textlength(candidate,font=font)>w*scale:lines.append(line);line=word
                    else:line=candidate
                lines.append(line)
        color=tuple(round(v*255) for v in s.get('color',[1,1,1]))[:3]
        for j,line in enumerate(lines):
            tw=draw.textlength(line,font=font);align=s.get('align')
            tx=(w*scale-tw)/2 if align=='CENTER' else w*scale-tw if align=='RIGHT' else 0
            ty=j*(font.size+2)
            if color[0]>150:draw.text((tx+2,ty+2),line,font=font,fill='black',anchor='lt')
            draw.text((tx,ty),line,font=font,fill=color,anchor='lt')
        surface=surface.resize((w,h),Image.Resampling.LANCZOS)
    if surface:
        if s.get('alpha') is not None:surface.putalpha(surface.getchannel('A').point(lambda v:int(v*s['alpha'])))
        layer=Image.new('RGBA',canvas.size);layer.alpha_composite(surface,(x,y))
        if s.get('clip'):
            cx,cy,cw,ch=s['clip'];mask=Image.new('L',canvas.size)
            ImageDraw.Draw(mask).rectangle((cx+margin,cy+margin,cx+cw+margin,cy+ch+margin),fill=255)
            layer.putalpha(ImageChops.multiply(layer.getchannel('A'),mask))
        canvas.alpha_composite(layer)
canvas.resize((W*scale,H*scale),Image.Resampling.LANCZOS).save(sys.argv[2])
print(sys.argv[2])
