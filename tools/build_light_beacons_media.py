"""Bundle original Blizzard UI pieces and synthesize an original two-note horn."""
from pathlib import Path
from PIL import Image
import hashlib, io, json, math, subprocess, urllib.request, wave
from array import array
import random
root=Path(__file__).resolve().parents[1]
out=root/'LightTheBeacons'/'Media';out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((out/'sources.json').read_text())
for item in manifest['files']:
    dest=out/item['file']
    if not dest.exists():
        raw=urllib.request.urlopen(item['source'],timeout=30).read()
        Image.open(io.BytesIO(raw)).convert('RGBA').save(dest)
    assert hashlib.sha256(dest.read_bytes()).hexdigest()==item['sha256'],dest
# Original synthesized brass/war-horn call. No sampled recordings.
rate=44100;duration=3.2;count=int(rate*duration)
signal=[0.0]*count;rng=random.Random(17)
for start,length,freq in [(0.05,.8,146.83),(.98,1.55,110.0)]:
    phase=0
    for i in range(int(start*rate),min(count,int((start+length)*rate))):
        u=i/rate-start;env=min(u/.13,1)*min(max(length-u,0)/.3,1)
        phase+=2*math.pi*freq*(1+.003*math.sin(2*math.pi*4.7*u))/rate
        brass=sum(math.sin(k*phase+.06*k)/(k**1.25) for k in range(1,12))
        signal[i]+=(brass+rng.gauss(0,.02))*env
stereo=[]
for delay in [.135,.171]:
    channel=signal.copy()
    for echo,level in [(delay,.19),(delay*2,.1),(delay*3,.05)]:
        n=int(echo*rate)
        for i in range(n,count):channel[i]+=signal[i-n]*level
    stereo.append(channel)
gain=.63/max(1,max(abs(v) for channel in stereo for v in channel))
sound=array('h',(int(stereo[channel][i]*gain*32767) for i in range(count) for channel in range(2)))
wav=out/'WarHorn.wav'
with wave.open(str(wav),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(sound.tobytes())
subprocess.run(['ffmpeg','-y','-v','error','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(out/'WarHorn.ogg')],check=True)
wav.unlink()
print('Bundled Blizzard textures and original 3.2-second war horn.')
