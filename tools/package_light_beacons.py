"""Check and package one portable Light the Beacons ZIP; does not publish."""
from pathlib import Path
import hashlib,json,re,subprocess,tempfile,zipfile
import xml.etree.ElementTree as ET
from PIL import Image
root=Path(__file__).resolve().parents[1];addon=root/'LightTheBeacons'
toc=(addon/'LightTheBeacons.toc').read_text()
version=re.search(r'^## Version: (.+)$',toc,re.M)[1]
assert re.search(r'^## Interface: 16001$',toc,re.M)
assert (root/'LICENSE.txt').read_bytes()==(addon/'LICENSE.txt').read_bytes(), 'License copies must match'
assert (addon/'PRIVACY.txt').is_file()
assert (addon/'ThirdParty/Lodestar-LICENSE.txt').is_file()
for item in json.loads((addon/'Fonts/sources.json').read_text()):
    assert hashlib.sha256((addon/'Fonts'/item['file']).read_bytes()).hexdigest()==item['sha256']
    assert 'SIL OPEN FONT LICENSE' in (addon/'Fonts'/item['license']).read_text()
for line in toc.splitlines():
    if line and not line.startswith('#'):assert (addon/line).is_file(),line
for path in addon.rglob('*.lua'):
    subprocess.run(['luac','-p',str(path)],check=True)
    text=path.read_text()
    assert 'SendChatMessage' not in text and 'C_CombatLogSecure.' not in text and 'C_CombatLogInternal.' not in text,path
bindings=ET.parse(addon/'Bindings.xml').getroot()
assert bindings.tag=='Bindings'
# WoW discovers Bindings.xml separately; a TOC entry uses the wrong XML loader.
assert 'Bindings.xml' not in toc.splitlines()
assert {b.attrib['name'] for b in bindings}=={'LTB_TOGGLE','LTB_LIGHT'}
for path in (addon/'Media').glob('*.tga'):
    with Image.open(path) as im:
        assert im.width&(im.width-1)==0 and im.height&(im.height-1)==0,path
        im.verify()
with Image.open(addon/'Media/GrudgeTome.tga') as im:
    assert im.getchannel('A').getextrema()==(255,255), 'Tome paper must remain opaque beneath stains'
assert not list((addon/'Media').glob('*.ogg')), 'Native WoW sound kits require no bundled recordings'
assert {s['soundKitID'] for s in json.loads((addon/'Media/sources.json').read_text())['sounds']}=={10843,8173}
assert {s['fileDataID'] for s in json.loads((addon/'Media/sources.json').read_text())['sounds']}=={566064,569543}
for item in json.loads((addon/'Media/sources.json').read_text())['files']:
    assert hashlib.sha256((addon/'Media'/item['file']).read_bytes()).hexdigest()==item['sha256']
manifest=json.loads((addon/'Media/sources.json').read_text())
assert {p.name for p in (addon/'Media').glob('*.tga')}=={item['file'] for item in manifest['files']}, 'Only original art may be bundled'
for item in manifest.get('nativeTextures',[]):
    assert not (addon/'Media'/item['file']).exists(), 'Native Blizzard textures must not be bundled'
archive=root/f'LightTheBeacons-{version}.zip'
files=sorted(p for p in addon.rglob('*') if p.is_file())
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in files:z.write(p,p.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(n.startswith('LightTheBeacons/') and '..' not in Path(n).parts for n in z.namelist())
    assert len(z.namelist())==len(set(n.lower() for n in z.namelist()))
    with tempfile.TemporaryDirectory(prefix='ltb-package-') as tmp:
        z.extractall(tmp)
        subprocess.run(['luajit',str(root/'tests/light-beacons.lua'),str(Path(tmp)/'LightTheBeacons')],cwd=root,check=True)
        for p in files:
            assert (Path(tmp)/p.relative_to(root)).read_bytes()==p.read_bytes()
receipt={'addon':'Light the Beacons','version':version,'interface':16001,'archive':str(archive),
         'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'bytes':archive.stat().st_size,
         'fileCount':len(files),'verification':'Lua syntax, asset integrity, ZIP extraction and simulated-client tests passed',
         'liveClientVerified':False}
out=root/'work'/f'light-the-beacons-{version}';out.mkdir(parents=True,exist_ok=True)
(out/'build.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
