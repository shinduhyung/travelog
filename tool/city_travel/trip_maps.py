"""Static day maps for build_page.py.

Stitches OpenStreetMap tiles for a city's area into one base image (cached under
out/cache, so the tile server is hit once per area), then draws each day's route as
an SVG on top of it. Published pages can't load outside images, so the base image is
embedded once and every day map reuses it with <use href="#basemap-...">.

Tiles: © OpenStreetMap contributors (https://www.openstreetmap.org/copyright).
"""
import base64
import io
import math
import time
import urllib.request
from pathlib import Path

TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
USER_AGENT = "TravelogTripPrep/1.0 (+https://travelogapp.uk)"
CACHE = Path(__file__).resolve().parent / "out" / "cache"


def _world_px(lat, lon, z):
    n = 256 * 2 ** z
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y


class BaseMap:
    def __init__(self, key, south, west, north, east, zoom):
        from PIL import Image

        self.zoom = zoom
        x0, y0 = _world_px(north, west, zoom)
        x1, y1 = _world_px(south, east, zoom)
        self.tx0, self.ty0 = int(x0 // 256), int(y0 // 256)
        tx1, ty1 = int(x1 // 256), int(y1 // 256)
        self.width = (tx1 - self.tx0 + 1) * 256
        self.height = (ty1 - self.ty0 + 1) * 256
        self.id = f"basemap-{key}"

        CACHE.mkdir(parents=True, exist_ok=True)
        out = CACHE / f"{key}-z{zoom}-{self.tx0}-{self.ty0}-{tx1}-{ty1}.jpg"
        if not out.exists():
            img = Image.new("RGB", (self.width, self.height), "white")
            for tx in range(self.tx0, tx1 + 1):
                for ty in range(self.ty0, ty1 + 1):
                    req = urllib.request.Request(TILE_URL.format(z=zoom, x=tx, y=ty), headers={"User-Agent": USER_AGENT})
                    with urllib.request.urlopen(req, timeout=30) as r:
                        tile = Image.open(io.BytesIO(r.read())).convert("RGB")
                    img.paste(tile, ((tx - self.tx0) * 256, (ty - self.ty0) * 256))
                    time.sleep(0.3)  # be gentle with the volunteer-run tile server
            img.save(out, "JPEG", quality=80, optimize=True)
        self.data_uri = "data:image/jpeg;base64," + base64.b64encode(out.read_bytes()).decode()

    def xy(self, lat, lon):
        x, y = _world_px(lat, lon, self.zoom)
        return x - self.tx0 * 256, y - self.ty0 * 256

    def defs(self):
        """Hidden SVG holding the base image once, for every day map to <use>."""
        return (f'<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>'
                f'<image id="{self.id}" href="{self.data_uri}" width="{self.width}" height="{self.height}"/>'
                f'</defs></svg>')

    def day_svg(self, points, label, legs_modes=None, pad=70, aspect=1.6):
        """points: [(lat, lon, number_label)] in visiting order."""
        xs = [self.xy(p[0], p[1]) for p in points]
        minx, maxx = min(x for x, _ in xs) - pad, max(x for x, _ in xs) + pad
        miny, maxy = min(y for _, y in xs) - pad, max(y for _, y in xs) + pad
        w, h = maxx - minx, maxy - miny
        # widen to a fixed aspect so cards line up
        if w / h < aspect:
            extra = h * aspect - w
            minx -= extra / 2
            w = h * aspect
        else:
            extra = w / aspect - h
            miny -= extra / 2
            h = w / aspect
        minx = max(0, min(minx, self.width - w))
        miny = max(0, min(miny, self.height - h))
        s = max(w / 640, 0.35)  # keep markers a similar size on screen at any zoom

        parts = [f'<svg class="daymap" viewBox="{minx:.0f} {miny:.0f} {w:.0f} {h:.0f}" role="img" aria-label="{label}">',
                 f'<use href="#{self.id}" class="map-base"/>']
        for i in range(len(xs) - 1):
            (ax, ay), (bx, by) = xs[i], xs[i + 1]
            if abs(ax - bx) < 1 and abs(ay - by) < 1:
                continue
            mode = (legs_modes or [None] * len(xs))[i]
            dash = f' stroke-dasharray="{6 * s:.1f} {5 * s:.1f}"' if mode in ("walk", "shuttle") else ""
            parts.append(f'<line x1="{ax:.1f}" y1="{ay:.1f}" x2="{bx:.1f}" y2="{by:.1f}" class="route" '
                         f'stroke-width="{4 * s:.1f}"{dash}/>')
        seen = {}
        for (x, y), p in zip(xs, points):
            key = (round(x), round(y))
            seen[key] = seen.get(key, 0) + 1
            off = (seen[key] - 1) * 22 * s  # stops at the same spot fan out to the right
            r = 13 * s
            parts.append(f'<g transform="translate({x + off:.1f} {y:.1f})"><circle r="{r:.1f}" class="pin" stroke-width="{3 * s:.1f}"/>'
                         f'<text class="pin-n" font-size="{14 * s:.1f}" dy="{5 * s:.1f}">{p[2]}</text></g>')
        parts.append("</svg>")
        return "".join(parts)
