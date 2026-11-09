"""Last-try prompts for the miss-set items that keep failing (wrong look, refused by the filter).

For each item Sonnet (high effort) gets the real photo from Wikipedia plus why earlier tries failed, and writes
the visual description from what it actually sees. Artworks may show the figures painted in them; refused works get
filter-safe wording. Requeues the items (drops them from miss_generated.json / miss_qa.json).

    python hard_prompts.py
"""
import base64
import json
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from make_prompts import HERE, KEY, STYLE, clean

UA = {"User-Agent": "jidoapp-landmark-images/1.0 (leeahn137@gmail.com)"}
ART = ("The subject is a famous artwork. Show the artwork itself filling the square edge to edge, no frame, wall or "
       "gallery. The figures painted in the artwork are part of it and must be shown as in the original; no real "
       "visitors.")
REFUSED = ("The image generator's safety filter refused every earlier prompt for this work. Find wording that passes: "
           "no nudity, bodies, violence, blood, death, children in danger, hearts or organs, and no quoted text. "
           "If the original cannot be described safely, describe a respectful, recognisable rendering of its "
           "composition, colours and setting with all figures fully clothed and calm.")

ITEMS = {  # file stem: extra guidance
    "gbr_bristol_cathedral": "", "usa_union_station": "Denver Union Station (Beaux-Arts, 1914), not any other station.",
    "rus_moscow_oceanarium_moskvarium": "", "fra_philharmonie_de_paris": "", "prt_estadio_do_dragao": "",
    "kor_sejong_center": "", "jpn_suntory_hall": "", "gbr_the_ladies_waldegrave": ART, "esp_semana_santa": (
        "Seville Holy Week: show an ornate golden paso (float) with candles and flowers in an empty narrow Seville "
        "street at dusk, no participants or crowds."),
    "usa_geopoliticus_child_watching_the_birth_of_the_new_man": ART + " " + REFUSED,
    "rus_perseus_and_andromeda": ART + " " + REFUSED, "rus_the_madonna_litta": ART + " " + REFUSED,
    "can_massacre_of_the_innocents": ART + " " + REFUSED, "usa_the_treachery_of_images": ART + " " + REFUSED,
    "mex_the_two_fridas": ART + " " + REFUSED,
}

ASK = """You write the visual part of an image-generation prompt for "{name}" ({city}). Category: {attrs}.
Earlier attempts failed: {why}
Extra guidance: {extra}
{photo}
Think carefully about what makes this subject instantly recognisable (overall silhouette, roof, materials, colours,
signature features, setting) and describe exactly that, concretely. Return only JSON:
{{"desc": "<3-4 sentences of precise visual detail>", "view": "<one camera view sentence that shows the signature features>",
 "avoid": "<one sentence naming the specific wrong versions to avoid>"}}"""


def get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30))


def photo(name):
    q = urllib.parse.urlencode({"action": "query", "titles": name, "prop": "pageimages", "pithumbsize": 800,
                                "redirects": 1, "format": "json"})
    try:
        for page in get(f"https://en.wikipedia.org/w/api.php?{q}")["query"]["pages"].values():
            src = page.get("thumbnail", {}).get("source")
            if src:
                return urllib.request.urlopen(urllib.request.Request(src, headers=UA), timeout=30).read()
    except Exception:
        pass
    return None


def write(item):
    f, row, why, extra = item
    img = photo(row["name"].split(" (")[0])
    content = [{"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                            "data": base64.b64encode(img).decode()}}] if img else []
    content.append({"type": "text", "text": ASK.format(
        name=row["name"], city=row["city"], attrs=", ".join(row.get("attributes") or []), why=why or "none recorded",
        extra=extra or "none", photo="The attached photo shows the real subject." if img else "")})
    body = json.dumps({"model": "claude-sonnet-5-5", "max_tokens": 4000, "output_config": {"effort": "high"},
                       "messages": [{"role": "user", "content": content}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=180))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            d = json.loads(txt[txt.index("{"): txt.rindex("}") + 1])
            p = STYLE.format(name=row["name"], city=row["city"], desc=clean(d["desc"]).rstrip(".") + ".",
                             view=d["view"].rstrip("."), avoid=d.get("avoid", "").strip() + " ")
            if extra.startswith(ART):  # painted figures are allowed for artworks
                p = p.replace("no people anywhere, including", "no real visitors; figures inside the artwork are fine, but not")
                p += " " + ART
            return f, {**row, "prompt": p, "photo_ref": bool(img)}
        except Exception as e:
            err = e
    print("failed", f, err)
    return f, None


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    P = lambda n: HERE / n
    prompts, gen, qa = (json.loads(P(n).read_text("utf-8")) for n in
                        ("miss_prompts.json", "miss_generated.json", "miss_qa.json"))
    items = [(s + ".webp", prompts[s + ".webp"], qa.get(s + ".webp", {}).get("note", "refused or no image"), x)
             for s, x in ITEMS.items()]
    with ThreadPoolExecutor(5) as pool:
        for f, v in pool.map(write, items):
            if v:
                prompts[f] = v
                gen.pop(f, None)
                qa.pop(f, None)
                print("ok", f, "photo" if v["photo_ref"] else "no photo")
    for n, o in (("miss_prompts.json", prompts), ("miss_generated.json", gen), ("miss_qa.json", qa)):
        P(n).write_text(json.dumps(o, ensure_ascii=False, indent=1), encoding="utf-8")
