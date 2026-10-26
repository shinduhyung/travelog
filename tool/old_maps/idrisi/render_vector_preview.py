import json, sys
from PIL import Image, ImageDraw
from register_coast import ASSETS
Z = 3
d = json.load(open(ASSETS / 'old_maps' / 'idrisi_vector.json', encoding='utf-8'))
im = Image.new('RGB', (d['width'] * Z, d['height'] * Z), (36, 52, 68))
dr = ImageDraw.Draw(im, 'RGBA')
def draw(poly, fill, line):
    dr.polygon([(x * Z, y * Z) for x, y in poly[0]], fill=fill, outline=line)
    for h in poly[1:]:
        dr.polygon([(x * Z, y * Z) for x, y in h], fill=(36, 52, 68), outline=line)
for p in d['land']:
    draw(p, (233, 217, 166), (120, 90, 50))
visited = {'FRA', 'ITA', 'EGY', 'TUR', 'IRN', 'ESP', 'GRC', 'SAU', 'IND', 'KAZ', 'DEU', 'MAR', 'LBY', 'CHN'}
for iso, c in d['countries'].items():
    for p in c['polygons']:
        draw(p, (179, 38, 30, 190) if iso in visited else None, (110, 80, 45, 120))
im.save(sys.argv[1])
