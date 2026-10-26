"""control_points.json(lon,lat -> x,y)으로 TPS 변환을 만들고 국가 외곽선을 고지도 위에 그려 검증한다."""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.interpolate import RBFInterpolator

HERE = Path(__file__).parent
ASSETS = HERE.parents[2] / 'assets'
Z = 3


def build_warp(points, smoothing=40.0):
    src = np.array([[p['lon'], p['lat']] for p in points], float)
    dst = np.array([[p['x'], p['y']] for p in points], float)
    return RBFInterpolator(src, dst, kernel='thin_plate_spline', smoothing=smoothing)


def load_warp(cp):
    """registered_points.json(해안선 자동 정합 결과)이 있으면 그것을, 없으면 수동 기준점만 쓴다."""
    reg = HERE / 'registered_points.json'
    if reg.exists():
        r = json.loads(reg.read_text(encoding='utf-8'))
        return RBFInterpolator(np.array(r['src']), np.array(r['dst']), kernel='thin_plate_spline',
                               smoothing=np.array(r['smoothing']))
    return build_warp(cp['points'])


def rings(geom):
    polys = [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']
    for poly in polys:
        yield poly[0]


def main(out):
    cp = json.loads((HERE / 'control_points.json').read_text(encoding='utf-8'))
    warp = load_warp(cp)
    im = Image.open(HERE / cp['image']).convert('RGB')
    im = im.resize((im.width * Z, im.height * Z), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    feats = json.loads((ASSETS / 'custom.geo.json').read_text(encoding='utf-8'))['features']
    for f in feats:
        for ring in rings(f['geometry']):
            a = np.array(ring)
            if a[:, 0].max() < -30 or a[:, 0].min() > 140 or a[:, 1].max() < -5 or a[:, 1].min() > 70:
                continue
            xy = warp(a) * Z
            d.line([tuple(p) for p in xy], fill=(220, 0, 0), width=1)
    for p in cp['points']:
        x, y = p['x'] * Z, p['y'] * Z
        d.ellipse([x - 4, y - 4, x + 4, y + 4], outline=(0, 0, 255), width=2)
    im.save(out)


if __name__ == '__main__':
    main(sys.argv[1])
