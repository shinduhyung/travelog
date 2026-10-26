"""고지도 좌표계 벡터 데이터 내보내기.

  land      : 고지도에서 추출한 육지 윤곽
  countries : 현대 국가 폴리곤을 고지도 좌표로 변환한 뒤 육지 안으로 잘라낸 것
좌표는 모두 고지도 이미지 픽셀(왼쪽 위 원점). 앱은 이 JSON만 쓰고 이미지는 쓰지 않는다.
"""
import json

import cv2
import numpy as np
from shapely.geometry import Polygon, box, mapping
from shapely.ops import unary_union

from register_coast import ASSETS, HERE, W, H, Z, old_land_contours
from warp_preview import load_warp

SIMPLIFY = 0.35


def land_geometry():
    cs, hier = old_land_contours()
    polys = {}
    for i, c in enumerate(cs):
        if hier[i][3] == -1 and len(c) >= 4:
            p = Polygon((c[:, 0, :] / Z)).buffer(0)
            if p.area > 6:
                polys[i] = [p, []]
    for i, c in enumerate(cs):
        par = hier[i][3]
        if par in polys and len(c) >= 4:
            h = Polygon((c[:, 0, :] / Z)).buffer(0)
            if h.area > 3:
                polys[par][1].append(h)
    out = [p.difference(unary_union(holes)) if holes else p for p, holes in polys.values()]
    return unary_union(out).intersection(box(0, 0, W, H))


def to_rings(g):
    g = g.simplify(SIMPLIFY)
    parts = list(g.geoms) if g.geom_type in ('MultiPolygon', 'GeometryCollection') else [g]
    res = []
    for p in parts:
        if p.geom_type != 'Polygon' or p.is_empty or p.area < 1.5:
            continue
        rings = [list(p.exterior.coords)] + [list(r.coords) for r in p.interiors]
        res.append([[[round(x, 1), round(y, 1)] for x, y in r] for r in rings])
    return res


def main():
    cp = json.loads((HERE / 'control_points.json').read_text(encoding='utf-8'))
    warp = load_warp(cp)
    land = land_geometry()
    out = {'width': W, 'height': H, 'land': to_rings(land), 'countries': {}}
    feats = json.loads((ASSETS / 'custom.geo.json').read_text(encoding='utf-8'))['features']
    for f in feats:
        pr = f['properties']
        iso = next((v for v in (pr.get('iso_a3_eh'), pr.get('iso_a3'), pr.get('adm0_a3')) if v and v != '-99'), 'N/A')
        g = f['geometry']
        pl = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
        pieces = []
        for poly in pl:
            ring = np.array(poly[0], float)
            if not (-25 <= ring[:, 0].max() and ring[:, 0].min() <= 135 and -12 <= ring[:, 1].max() and ring[:, 1].min() <= 72):
                continue
            outer = warp(ring)
            holes = [warp(np.array(h, float)) for h in poly[1:]]
            p = Polygon(outer, holes).buffer(0)
            clipped = p.intersection(land)
            if not clipped.is_empty and clipped.area > 1.0:
                pieces.append(clipped)
        if pieces:
            rings = to_rings(unary_union(pieces))
            if rings:
                out['countries'][iso] = {'name': pr['name'], 'polygons': rings}
    dest = ASSETS / 'old_maps' / 'idrisi_vector.json'
    dest.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(len(out['land']), 'land polys,', len(out['countries']), 'countries,', dest.stat().st_size // 1024, 'KB')


if __name__ == '__main__':
    main()
