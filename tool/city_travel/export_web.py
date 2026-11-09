"""Turn out/<slug>.html into a public website in web/public/ (Firebase Hosting, see web/firebase.json).

 * embedded photos reuse the existing public Firebase Storage objects; no image files are written or uploaded.
 * the "Run AI" planner step needs claude.ai, so it is hidden (same rule as export_app_reports.py).
 * adds a meta description, canonical URL, and an index page + sitemap.

Run from this folder:  python export_web.py [slug ...]   (no args = every page in out/)
"""
import base64
import hashlib
import html
import json
import re
import sys
from pathlib import Path

from export_app_reports import APP_CSS

HERE = Path(__file__).resolve().parent
PUB = HERE / "web" / "public"
SITE = "https://travelogapp.uk"
PUBLIC = "https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/city_report_img%2F{}?alt=media"
INLINE_MAX = 2048
# Keep missing Storage objects embedded; never publish broken image URLs or upload.
UPLOADED = set(json.loads((HERE / "app_img_uploaded.json").read_text(encoding="utf-8")))
IMG = re.compile(r"data:image/([a-z+]+);base64,([A-Za-z0-9+/=]+)")


def img_url(m):
    raw = base64.b64decode(m.group(2))
    if len(raw) <= INLINE_MAX:
        return m.group(0)
    name = hashlib.sha1(raw).hexdigest()[:16] + (".jpg" if m.group(1) == "jpeg" else "." + m.group(1).replace("+xml", ""))
    if name not in UPLOADED:
        return m.group(0)
    return PUBLIC.format(name)


def page(s):
    src = (HERE / "out" / f"{s}.html").read_text(encoding="utf-8")
    city = re.search(r"<title>(.*?) Trip Prep</title>", src).group(1)
    src = IMG.sub(img_url, src).replace("</style>", APP_CSS + "</style>", 1)
    src = re.sub(r"<img\b[^>]*>", lambda m: m.group(0) if re.search(r"\bloading\s*=", m.group(0)) else m.group(0).replace("<img", '<img loading="lazy"', 1), src, flags=re.I)
    desc = f"Plan a trip to {city}: getting in, landmarks, day trips, tours, souvenirs with prices, costs and a day-by-day planner."
    head = (f'<meta name="description" content="{html.escape(desc)}">\n'
            f'<link rel="canonical" href="{SITE}/city/{s}">\n'
            f'<meta property="og:title" content="{html.escape(city)} Trip Prep · Travelog">\n'
            f'<meta property="og:description" content="{html.escape(desc)}">\n')
    src = src.replace(f"<title>{city} Trip Prep</title>", f"<title>{city} Trip Prep · Travelog</title>\n{head}", 1)
    (PUB / "city" / f"{s}.html").write_text(src, encoding="utf-8")
    return city


def main(slugs):
    (PUB / "city").mkdir(parents=True, exist_ok=True)
    for s in slugs:
        page(s)
    done = sorted(p.stem for p in (PUB / "city").glob("*.html"))
    links = "".join(f'<li><a href="/city/{s}">{s.replace("-", " ").title()}</a></li>' for s in done)
    (PUB / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>City Trip Prep · Travelog</title><meta name="description" content="Trip-prep guides for 200 cities.">'
        '<style>body{font:16px system-ui,sans-serif;max-width:720px;margin:0 auto;padding:24px 16px;background:#fff;color:#111}'
        'ul{columns:2;padding:0;list-style:none}li{margin:6px 0}a{color:#2563eb}</style>'
        f'<h1>City Trip Prep</h1><ul>{links}</ul></html>', encoding="utf-8")
    (PUB / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(f"<url><loc>{SITE}/city/{s}</loc></url>" for s in done) + "</urlset>", encoding="utf-8")
    print(len(done), "pages")


if __name__ == "__main__":
    main(sys.argv[1:] or [p.stem for p in (HERE / "out").glob("*.html")])
