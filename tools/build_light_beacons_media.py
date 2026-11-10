"""Restore original addon art; cache native texture references only for previews."""
from pathlib import Path
from PIL import Image
import hashlib, io, json, urllib.request
root=Path(__file__).resolve().parents[1]
out=root/'LightTheBeacons'/'Media';out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((out/'sources.json').read_text())
preview=root/'work'/'native-texture-previews';preview.mkdir(parents=True,exist_ok=True)
for item in manifest['files']+manifest.get('nativeTextures',[]):
    dest=(out if item.get('kind')=='original' else preview)/item['file']
    if not dest.exists():
        if item.get('kind')=='original':
            source=root/item['source']
            assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sourceSha256'],source
            Image.open(source).convert('RGBA').resize(tuple(item['size']),Image.Resampling.LANCZOS).save(dest)
        else:
            raw=urllib.request.urlopen(item['source'],timeout=30).read()
            Image.open(io.BytesIO(raw)).convert('RGBA').save(dest)
    assert hashlib.sha256(dest.read_bytes()).hexdigest()==item['sha256'],dest
print("Verified original brazier and local preview cache. Blizzard textures and sounds stay in the WoW client.")
