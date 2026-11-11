"""Deterministic original tome materials; no game or third-party artwork copied."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import hashlib, json, math, random
root=Path(__file__).resolve().parents[1]
art=root/'art';media=root/'LightTheBeacons/Media';art.mkdir(exist_ok=True)
rng=random.Random(1731)
w,h=960,640
im=Image.new('RGBA',(w,h));pix=im.load()
for y in range(h):
    for x in range(w):
        grain=rng.gauss(0,3)
        edge=min(x,w-1-x,y,h-1-y)
        c=24+min(9,edge*.5)+grain
        pix[x,y]=(int(c+5),int(c),max(0,int(c-5)),255)
d=ImageDraw.Draw(im)
for inset,color in [(3,(59,49,35)),(8,(92,73,49)),(11,(15,12,9)),(16,(68,48,31))]:
    d.rounded_rectangle((inset,inset,w-inset-1,h-inset-1),radius=7,outline=color,width=2)
for y,offset,color in [(600,0,'#635032'),(603,2,'#89704c'),(606,-1,'#493820'),(609,1,'#745c3d')]:
    d.rounded_rectangle((23+offset,47,937+offset,y),radius=7,fill=color)
paper=Image.new('RGBA',(912,552));pp=paper.load()
for y in range(552):
    for x in range(912):
        edge=min(x,911-x,y,551-y)
        gutter=math.exp(-abs(x-456)/13)*62
        edgeShade=math.exp(-edge/19)*40
        stain=20*math.exp(-((x-15)/100)**2-((y-10)/90)**2)+15*math.exp(-((x-865)/90)**2-((y-540)/120)**2)
        noise=rng.gauss(0,3.2)+2*math.sin(x/35+y/51)
        delta=noise-gutter-edgeShade-stain
        pp[x,y]=(max(0,int(168+delta)),max(0,int(149+delta)),max(0,int(112+delta)),255)
paper=paper.convert('RGB')
pd=ImageDraw.Draw(paper,'RGBA')
for _ in range(220):
    x=rng.randrange(912);y=rng.randrange(552)
    if 50<x<860 and 50<y<500 and rng.random()<.7:continue
    r=rng.randrange(1,4);pd.ellipse((x-r,y-r,x+r,y+r),fill=(57,33,14,rng.randrange(7,29)))
paper=paper.convert('RGBA')
wear=Image.new('RGBA',paper.size);wd=ImageDraw.Draw(wear)
wd.ellipse((-94,375,70,550),outline=(69,43,24,35),width=3)
wd.ellipse((843,345,1030,545),outline=(70,43,23,29),width=3)
wd.line((0,462,440,542),fill=(64,44,22,24),width=2)
wd.line((510,537,912,471),fill=(62,42,23,23),width=2)
paper.alpha_composite(wear.filter(ImageFilter.GaussianBlur(1)))
mask=Image.new('L',paper.size,255);md=ImageDraw.Draw(mask)
for x in range(0,912,7):
    md.rectangle((x,0,x+7,rng.randrange(1,4)),fill=0)
    md.rectangle((x,551-rng.randrange(1,4),x+7,552),fill=0)
im.paste(paper,(24,48),mask)
d=ImageDraw.Draw(im)
for x,y,sx,sy in [(4,4,1,1),(956,4,-1,1),(4,636,1,-1),(956,636,-1,-1)]:
    points=[(x,y),(x+sx*42,y),(x+sx*42,y+sy*7),(x+sx*9,y+sy*9),(x+sx*7,y+sy*42),(x,y+sy*42)]
    d.polygon(points,fill='#4c493c');d.line(points+[points[0]],fill='#76684e',width=1)
    cx,cy=x+sx*5,y+sy*5;d.ellipse((cx-2,cy-2,cx+2,cy+2),fill='#9a8968')
im.save(art/'GrudgeTome.png')
im.resize((1024,1024),Image.Resampling.LANCZOS).save(media/'GrudgeTome.tga')
seal=Image.new('RGBA',(128,128));sd=ImageDraw.Draw(seal)
points=[]
for i in range(38):
    a=i*math.tau/38;r=49+rng.randrange(-4,5);points.append((64+math.cos(a)*r,64+math.sin(a)*r))
sd.polygon([(x+2,y+4) for x,y in points],fill=(15,7,5,90));sd.polygon(points,fill='#552b23')
sd.ellipse((24,23,104,103),fill='#69372a',outline='#8a5237',width=2)
sd.ellipse((29,28,99,98),outline='#362018',width=3)
sd.line((51,14,57,36,48,49),fill='#291910',width=2)
sd.line((86,98,78,85,84,72),fill='#321c14',width=2)
seal.save(art/'GrudgeSeal.png');seal.save(media/'GrudgeSeal.tga')
manifest=json.loads((media/'sources.json').read_text())
manifest['files']=[f for f in manifest['files'] if f['file'] not in ('GrudgeTome.tga','GrudgeSeal.tga')]
for stem,size in [('GrudgeTome',[1024,1024]),('GrudgeSeal',[128,128])]:
    source=art/(stem+'.png');target=media/(stem+'.tga')
    manifest['files'].append({'file':target.name,'kind':'original','source':str(source.relative_to(root)),
        'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':size,
        'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'description':'Original procedural aged-tome material; reproducible with tools/build_grudge_media.py.'})
manifest['copyright']='Original brazier and procedural tome artwork for Light the Beacons. Blizzard textures and sounds remain native references.'
(media/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Built original aged tome and cracked wax seal.')
