"""Turn the published trip-prep pages (out/<slug>.html) into light copies the app shows in a WebView.

 * every embedded photo (data:image/...) is written once to app_img/<hash>.<ext> (same name rule as
   export_web.py), uploaded to Firebase Storage city_report_img/ and linked, so the page stays small and
   the WebView loads (and caches) the photos over HTTPS. Tiny inline images (icons) stay embedded.
 * the "Run AI" part of the planner only works on claude.ai, so it is hidden in the app.
 * the result is gzipped into assets/city_reports/<slug>.html.gz and indexed in index.json
   ({city name: slug}), which the app reads (lib/widgets/city_report_screen.dart).

Run from this folder:  python export_app_reports.py           (export + upload new photos)
                       python export_app_reports.py --no-upload
"""
import base64
import gzip
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = HERE / "out"
DEST = ROOT / "assets" / "city_reports"
IMG_DIR = HERE / "app_img"
UPLOADED = HERE / "app_img_uploaded.json"
BUCKET = "gs://proboscis-2025.firebasestorage.app/city_report_img/"
PUBLIC = "https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/city_report_img%2F{}?alt=media"
INLINE_MAX = 2048  # bytes; smaller images stay as data: URIs

sys.path.insert(0, str(HERE))
from build_page import slug  # noqa: E402  (same slug rule the pages were built with)

IMG = re.compile(r"data:image/([a-z+]+);base64,([A-Za-z0-9+/=]+)")
APP_CSS = (
    "\n/* app: the AI planner step needs claude.ai */\n"
    ".custom .run, .custom .step:has(+ .run), #pl-run, #pl-stop, #pl-status { display: none !important; }\n"
)


def img_url(m):
    raw = base64.b64decode(m.group(2))
    if len(raw) <= INLINE_MAX:
        return m.group(0)
    name = hashlib.sha1(raw).hexdigest()[:16] + (".jpg" if m.group(1) == "jpeg" else "." + m.group(1).replace("+xml", ""))
    p = IMG_DIR / name
    if not p.exists():
        p.write_bytes(raw)
    return PUBLIC.format(name)


def light(page: str) -> str:
    page = IMG.sub(img_url, page)
    page = page.replace('<img src="https://firebasestorage', '<img loading="lazy" src="https://firebasestorage')
    return page.replace("</style>", APP_CSS + "</style>", 1)


def upload():
    """Upload photos not uploaded yet (content-hashed names, so never overwrite)."""
    done = set(json.loads(UPLOADED.read_text(encoding="utf-8"))) if UPLOADED.exists() else set()
    todo = sorted(p for p in IMG_DIR.iterdir() if p.name not in done)
    if not todo:
        print("photos: nothing new to upload")
        return
    r = subprocess.run(["gcloud.cmd", "storage", "cp", "-I", "--no-clobber",
                        "--cache-control=public, max-age=31536000, immutable", BUCKET],
                       input="\n".join(str(p) for p in todo), capture_output=True, text=True)
    if r.returncode:
        sys.exit("upload failed: " + (r.stderr or r.stdout)[-600:])
    done.update(p.name for p in todo)
    UPLOADED.write_text(json.dumps(sorted(done), indent=0), encoding="utf-8")
    print(f"photos: uploaded {len(todo)} (total {len(done)})")


def main():
    pages = json.loads((ROOT / "assets" / "city_trip_pages.json").read_text(encoding="utf-8"))
    DEST.mkdir(parents=True, exist_ok=True)
    IMG_DIR.mkdir(exist_ok=True)
    index, missing, total = {}, [], 0
    for city in sorted(pages):
        s = slug(city)
        src = OUT / f"{s}.html"
        if not src.is_file():
            missing.append(city)
            continue
        data = light(src.read_text(encoding="utf-8")).encode("utf-8")
        gz = gzip.compress(data, 9)
        (DEST / f"{s}.html.gz").write_bytes(gz)
        index[city] = s
        total += len(gz)
    (DEST / "index.json").write_text(json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(index)} pages, {total / 1e6:.1f} MB gzipped; missing: {missing}")
    if "--no-upload" not in sys.argv:
        upload()


if __name__ == "__main__":
    main()
