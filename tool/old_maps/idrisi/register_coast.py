"""현대 해안선을 고지도의 해안선에 자동 정합(ICP + TPS)해서 변환 정밀도를 높인다.

산출물
  registered_points.json : 최종 변환(위경도 -> 고지도 픽셀)을 재구성하는 원점/대응점
  land_polygons.json     : 고지도 육지 윤곽(고지도 픽셀 좌표 벡터)
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy.interpolate import RBFInterpolator
from scipy.spatial import cKDTree
from shapely.geometry import shape
from shapely.ops import unary_union

HERE = Path(__file__).parent
ASSETS = HERE.parents[2] / 'assets'
Z = 3
W, H = 720, 321


def old_land_contours():
    """육지 마스크(Z배)에서 윤곽선 벡터를 뽑는다. 반환: [(외곽(N,2), [구멍...])] 단위 px(원본 좌표)."""
    m = np.asarray(Image.open(HERE / 'idrisi_land_mask.png'))[..., 3] > 127
    m = m.astype(np.uint8) * 255
    cs, hier = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    return cs, hier[0]


def coast_points(cs):
    pts = []
    for c in cs:
        p = c[:, 0, :].astype(float)
        # 이미지 프레임에 붙은 윤곽(그림 가장자리)은 해안선이 아니므로 제외
        ok = (p[:, 0] > 6) & (p[:, 0] < W * Z - 6) & (p[:, 1] > 6) & (p[:, 1] < H * Z - 6)
        pts.append(p[ok])
    return np.vstack(pts) / Z


def modern_coast(step=0.25):
    feats = json.loads((ASSETS / 'custom.geo.json').read_text(encoding='utf-8'))['features']
    geoms = [shape(f['geometry']) for f in feats]
    u = unary_union([g.buffer(0.02) for g in geoms])
    polys = list(u.geoms) if u.geom_type == 'MultiPolygon' else [u]
    pts = []
    for p in polys:
        rings = [p.exterior] + [r for r in p.interiors if shape({'type': 'Polygon', 'coordinates': [list(r.coords)]}).area > 8]
        for r in rings:
            n = max(int(r.length / step), 2)
            for d in np.linspace(0, r.length, n, endpoint=False):
                x, y = r.interpolate(d).coords[0]
                if -22 <= x <= 128 and -2 <= y <= 66:
                    pts.append((x, y))
    return np.array(pts)


def fit(src, dst, smoothing):
    return RBFInterpolator(src, dst, kernel='thin_plate_spline', smoothing=smoothing)


def main():
    cp = json.loads((HERE / 'control_points.json').read_text(encoding='utf-8'))['points']
    csrc = np.array([[p['lon'], p['lat']] for p in cp])
    cdst = np.array([[p['x'], p['y']] for p in cp], float)
    cs, _ = old_land_contours()
    old = coast_points(cs)
    tree = cKDTree(old)
    mod = modern_coast()
    rng = np.random.default_rng(0)
    print('old coast pts', len(old), 'modern coast pts', len(mod))

    warp = fit(csrc, cdst, 40.0)

    def score(wp):
        d, _ = tree.query(wp(mod))
        return float(np.median(d)), float(np.mean(d < 4))

    print('start  median dist %.2f px, within4px %.2f' % score(warp))
    src_all, dst_all = csrc, cdst
    for it, r in enumerate([22, 18, 14, 11, 9, 7, 6, 5, 4.5, 4]):
        xy = warp(mod)
        d, idx = tree.query(xy)
        keep = d < r
        sel = np.flatnonzero(keep)
        if len(sel) > 900:
            sel = rng.choice(sel, 900, replace=False)
        # 절반만 이동(과적합 방지)
        tgt = xy[sel] + 0.6 * (old[idx[sel]] - xy[sel])
        src_all = np.vstack([csrc, mod[sel]])
        dst_all = np.vstack([cdst, tgt])
        sm = np.concatenate([np.full(len(csrc), 20.0), np.full(len(sel), 25.0)])
        warp = fit(src_all, dst_all, sm)
        print('iter %d r=%.1f pairs=%d  median %.2f px, within4px %.2f' % ((it, r, len(sel)) + score(warp)))

    out = {'src': src_all.round(4).tolist(), 'dst': dst_all.round(2).tolist(),
           'smoothing': sm.round(2).tolist()}
    (HERE / 'registered_points.json').write_text(json.dumps(out), encoding='utf-8')
    print('saved registered_points.json')


if __name__ == '__main__':
    main()
