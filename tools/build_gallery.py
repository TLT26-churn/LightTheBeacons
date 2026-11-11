"""Build CurseForge gallery images from real Lua widgets and synthetic fixtures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
work = root / 'work/gallery-1.6.1'
out = root / 'docs/gallery'
work.mkdir(parents=True, exist_ok=True)
out.mkdir(parents=True, exist_ok=True)
prefix = work / 'native'
subprocess.run(['luajit', 'tests/light-beacons.lua', 'LightTheBeacons', str(prefix)], cwd=root, check=True)

scenes = ['window', 'expanded', 'alert', 'composer', 'grudges', 'grudges-fields', 'grudges-avenged', 'grudges-empty']
for scene in scenes:
    subprocess.run([sys.executable, 'tests/render_light_beacons.py', str(prefix) + '-' + scene + '.json',
                    str(work / (scene + '.png'))], cwd=root, check=True, stdout=subprocess.DEVNULL)

font = root / 'LightTheBeacons/Fonts/IMFeENrm28P.ttf'
def face(size):
    return ImageFont.truetype(str(font), size)

def page(title, subtitle):
    im = Image.new('RGB', (1920, 1440), '#0b1019')
    d = ImageDraw.Draw(im)
    d.rectangle((25, 25, 1894, 1414), outline='#695339', width=2)
    d.text((80, 62), title, font=face(48), fill='#dcc28d')
    d.text((80, 126), subtitle, font=face(29), fill='#bcc3ce')
    d.line((80, 179, 1840, 179), fill='#695339', width=2)
    d.text((80, 1373), 'Light the Beacons 1.6.1  /  WoW Forever', font=face(23), fill='#a09a8c')
    d.text((1090, 1373), 'UI renders with fictional sample names', font=face(23), fill='#a09a8c')
    return im

def widget(im, name, box):
    picture = Image.open(work / (name + '.png')).convert('RGB')
    # Remove only the renderer's neutral outer margin; preserve the whole widget.
    picture = picture.crop((28, 28, picture.width - 28, picture.height - 28))
    picture.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    im.paste(picture, (box[0] + (box[2] - picture.width) // 2, box[1]))

gallery = []
im = page('Guild calls for aid', 'A compact Rally card, a native war horn, and routes using your known flight points.')
d = ImageDraw.Draw(im)
d.text((105, 225), 'Compact Rally card', font=face(32), fill='#dcc28d')
d.text((1015, 225), 'Expanded route details', font=face(32), fill='#dcc28d')
widget(im, 'window', (90, 285, 820, 660))
widget(im, 'expanded', (1000, 285, 820, 1020))
d.text((105, 850), 'Guild-only beacon alert', font=face(32), fill='#dcc28d')
widget(im, 'alert', (90, 910, 820, 350))
gallery.append(('01-rally-and-routes.png', im, 'Guild calls and rescue routes', 'Compact Rally card, incoming alert and expanded route. Fictional sample names; rendered addon UI.'))
im = page('Grudges', 'A guild-shared ledger with signed entries, unpaid tallies, and seals for avenged grudges.')
widget(im, 'grudges-avenged', (105, 205, 1710, 1140))
gallery.append(('02-guild-grudges.png', im, 'Guild-shared Grudges ledger', 'A recorded grudge marked avenged while preserving the original entry. Fictional sample names; rendered addon UI.'))
im = page('Add a grudge', 'Clear fields and actions, with each saved entry shared through the guild addon channel.')
widget(im, 'grudges-fields', (105, 205, 1710, 1140))
gallery.append(('03-add-a-grudge.png', im, 'Clear grudge entry controls', 'Outlined fields, typing hints and a Save to guild ledger button. Fictional sample names; rendered addon UI.'))
records = []
for filename, im, title, caption in gallery:
    path = out / filename
    im.save(path, optimize=True)
    records.append({'file': filename, 'title': title, 'caption': caption,
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'size': list(im.size)})
for scene, filename in [('window', 'compact-rally-card.png'), ('expanded', 'compact-rally-details.png'),
                        ('composer', 'beacon-messages.png'), ('grudges', 'book-of-grudges.png')]:
    (root / 'docs' / filename).write_bytes((work / (scene + '.png')).read_bytes())
(out / 'manifest.json').write_text(json.dumps({'version': '1.6.1', 'kind': 'Native Lua UI renders',
    'sampleNames': ['Example Ally', 'Sample Scout', 'Sample Healer', 'Example Enemy', 'Sample Rival', 'Training Foe', 'Sample Scribe'],
    'images': records}, indent=2) + '\n')
print(json.dumps(records, indent=2))
