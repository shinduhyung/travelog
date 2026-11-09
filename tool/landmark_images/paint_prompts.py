"""Prompts for the artwork set (attribute Painting or Artwork in all_landmarks.json), one square 1:1 image each.

For each work: Wikidata gives the real image (P18, kept as the reference for paint_qa.py), its size ratio, the
creator and the creator's death year. Claude Sonnet then writes a faithful-reproduction prompt that turns the
original into a natural square: extend sky/background/floor, or trim the sides slightly, never squash or frame it.
Works whose creator died after 1955 are marked "copyright": they are listed but not queued.

    python paint_prompts.py      # writes paint_prompts.json (queued) and paint_refs.json (reference image per file)
"""
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

from make_prompts import HERE, KEY

UA = {"User-Agent": "jidoapp-artwork/1.0 (leeahn137@gmail.com)"}
WD = "https://www.wikidata.org/w/api.php"


def get(url, raw=False):
    for _ in range(4):
        try:
            r = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40).read()
            return r if raw else json.loads(r)
        except Exception:
            time.sleep(3)  # Wikimedia throttles bursts
    return None if raw else {}


def claim(ent, p):
    for c in ent.get("claims", {}).get(p, []):
        v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
        if v is not None:
            return v


def wikidata(name):
    q = urllib.parse.urlencode({"action": "wbsearchentities", "search": name, "language": "en", "limit": 10, "format": "json"})
    ids = [h["id"] for h in get(f"{WD}?{q}").get("search", [])]
    if not ids:
        return {}
    q = urllib.parse.urlencode({"action": "wbgetentities", "ids": "|".join(ids), "props": "claims|labels",
                                "languages": "en", "format": "json"})
    ents = get(f"{WD}?{q}").get("entities", {})
    for i in ids:  # first hit that has an image and a creator = the artwork
        e = ents.get(i, {})
        img, creator = claim(e, "P18"), claim(e, "P170")
        if img and creator:
            died = None
            q = urllib.parse.urlencode({"action": "wbgetentities", "ids": creator["id"], "props": "claims|labels",
                                        "languages": "en", "format": "json"})
            c = get(f"{WD}?{q}").get("entities", {}).get(creator["id"], {})
            d = claim(c, "P570")
            if d:
                died = int(d["time"][1:5])
            return {"qid": i, "image": img, "artist": c.get("labels", {}).get("en", {}).get("value", ""), "died": died}
    return {}


def ratio_of(image):
    url = "https://commons.wikimedia.org/w/index.php?" + urllib.parse.urlencode(
        {"title": "Special:FilePath/" + image, "width": 800})
    raw = get(url, raw=True)
    if not raw:
        return None, None
    w, h = Image.open(io.BytesIO(raw)).size
    return round(w / h, 3), url


ASK = """Write an image-generation prompt for a travel app: a faithful reproduction of the artwork "{name}"{by} ({city}).
Category: {attrs}. Notes: {overview}
The original's width:height ratio is {ratio}. The output MUST be a square 1:1 image that looks natural:
- wider than square: keep the whole subject, extend the sky/ceiling/background above (and ground below) in the same style, or trim the sides only slightly;
- taller than square: extend the background at the left and right in the same style, or trim top/bottom slightly;
- never squash, stretch, add a frame, wall, museum room, plaque, caption or signature.
For a sculpture or mural, show the real work itself, centred, with its real surroundings or a plain museum backdrop.
Describe the real composition, colours and technique concretely so it is recognisable. No extra people beyond those in the artwork itself.
Return only JSON: {{"prompt": "<the full prompt, 90-160 words>"}}"""


def ask(row, meta):
    by = f" by {meta['artist']}" if meta.get("artist") else ""
    body = json.dumps({"model": "claude-sonnet-5-5", "max_tokens": 1500, "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": ASK.format(
                           name=row["name"], by=by, city=row.get("city", ""), attrs=", ".join(row["attributes"]),
                           overview=(row.get("overview") or "")[:400], ratio=meta.get("ratio") or "unknown")}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=90))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            return json.loads(txt[txt.index("{"): txt.rindex("}") + 1])["prompt"].strip()
        except Exception as e:
            err = e
    print("prompt failed", row["name"], err)


def work(row):
    meta = wikidata(row["name"])
    if meta.get("image"):
        meta["ratio"], meta["ref_url"] = ratio_of(meta["image"])
    iso3 = (row.get("countriesIsoA3") or ["xxx"])[0].lower()
    file = f"{iso3}_{re.sub(r'[^a-z0-9]+', '_', row['name'].lower()).strip('_')}.webp"
    meta["copyright"] = bool(meta.get("died") and meta["died"] > 1955)
    p = None if meta["copyright"] else ask(row, meta)
    return file, row, meta, p


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    rows = json.loads((HERE / "paintings_targets.json").read_text(encoding="utf-8"))
    prompts, refs = {}, {}
    with ThreadPoolExecutor(2) as pool:
        for file, row, meta, p in pool.map(work, rows):
            refs[file] = {"name": row["name"], **meta}
            if p:
                prompts[file] = {"name": row["name"], "city": row.get("city", ""), "iso3": file[:3], "file": file,
                                 "attributes": row["attributes"], "overview": row.get("overview", ""), "prompt": p}
    (HERE / "paint_prompts.json").write_text(json.dumps(prompts, ensure_ascii=False, indent=1), encoding="utf-8")
    (HERE / "paint_refs.json").write_text(json.dumps(refs, ensure_ascii=False, indent=1), encoding="utf-8")
    cr = [v["name"] for v in refs.values() if v.get("copyright")]
    print("queued", len(prompts), "| no wikidata image", sum(1 for v in refs.values() if not v.get("image")),
          "| copyright held", len(cr), cr)
