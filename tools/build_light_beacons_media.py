"""Restore the pinned Blizzard UI textures; sounds are native client references."""
from pathlib import Path
from PIL import Image
import hashlib, io, json, urllib.request
root=Path(__file__).resolve().parents[1]
out=root/'LightTheBeacons'/'Media';out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((out/'sources.json').read_text())
for item in manifest['files']:
    dest=out/item['file']
    if not dest.exists():
        raw=urllib.request.urlopen(item['source'],timeout=30).read()
        Image.open(io.BytesIO(raw)).convert('RGBA').save(dest)
    assert hashlib.sha256(dest.read_bytes()).hexdigest()==item['sha256'],dest
print("Verified bundled Blizzard textures. Sounds play from native WoW sound kits.")
