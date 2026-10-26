"""Add missing must-see landmarks to assets/all_landmarks.json without Claude writing them.

Input JSON: {"City": [["Landmark name", "Attr1|Attr2"], ...]}  (attributes must already exist in the file;
"" lets DeepSeek pick 1-2 from the attributes in use)
Coordinates come from OpenStreetMap Nominatim, else the Wikipedia article (real data; skipped if not found or > MAX_KM from the city);
overview / history_significance / highlights come from DeepSeek. Records are inserted as text next to the
city's other records (the big file is not re-serialized).

  python add_landmarks.py <input.json>        # prints one line per landmark: added / skipped + reason
"""
import json
import math
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import city_records
import deepseek_city as ds

LM = city_records.ASSETS / "all_landmarks.json"
MAX_KM = 80


def km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (*a, *b))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 12742 * math.asin(math.sqrt(h))


def get(url):
    for wait in (2, 10, 30, 60):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "jidoapp-city-pages/1.0 (leeahn137@gmail.com)"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.load(r)
            time.sleep(1.1)  # Nominatim / Wikipedia usage policy: about 1 request per second
            return data
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(wait)
    return None


def geocode(name, city, country):
    for q in (f"{name}, {city}, {country}", f"{name}, {country}"):
        url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({"q": q, "format": "json", "limit": 1})
        res = get(url)
        if res:
            return round(float(res[0]["lat"]), 4), round(float(res[0]["lon"]), 4)
    # fallback: the English Wikipedia article's coordinates (real data, often present when OSM names differ)
    url = "https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "query", "format": "json", "generator": "search", "gsrsearch": f"{name} {city}", "gsrlimit": 1,
         "prop": "coordinates"})
    pages = ((get(url) or {}).get("query") or {}).get("pages") or {}
    for p in pages.values():
        if p.get("coordinates"):
            c = p["coordinates"][0]
            return round(c["lat"], 4), round(c["lon"], 4)
    return None


def texts(city, names, attrs):
    out = ds.ask("You write short, factual landmark entries for a travel app. Reply with one JSON object only. "
                 "If unsure of a fact, leave it out rather than guess.",
                 f"City: {city}. For each landmark give overview (1-2 sentences), history_significance "
                 f"(1-2 sentences), highlights (exactly 3 short points) and attributes (1-2 picked ONLY from this list: "
                 f"{', '.join(sorted(attrs))}). Landmarks: {json.dumps(names)}. "
                 'Format: {"<name>": {"overview": "...", "history_significance": "...", "highlights": ["..", "..", ".."], "attributes": [".."]}}',
                 max_tokens=4000)
    return out


def main(path):
    add(json.loads(open(path, encoding="utf-8").read()))


def add(src):
    text = LM.read_text(encoding="utf-8")
    all_lm = json.loads(text)
    have = {l["name"].lower() for l in all_lm}
    attrs = {a for l in all_lm for a in l.get("attributes", [])}
    use = [a for l in all_lm for a in l.get("attributes", [])]
    common = {a for a in attrs if use.count(a) >= 5}  # leaves out one-off typos such as "Caslte"
    cities = city_records.load_cities()
    iso3 = {c["iso_a2"]: c["iso_a3"] for c in json.loads((city_records.ASSETS / "countries_light.json").read_text(encoding="utf-8"))}
    for city, rows in src.items():
        rec = cities[city]
        center = (rec["values"]["latitude"], rec["values"]["longitude"])
        country, iso2 = rec["dimensions"]["country"], rec["dimensions"]["country_iso"]
        keep = []
        for name, attr in rows:
            a = [x for x in attr.split("|") if x]
            if name.lower() in have:
                print(f"{city}: skip {name} (exists)"); continue
            if any(x not in attrs for x in a):
                print(f"{city}: skip {name} (attribute {attr} not in use)"); continue
            pt = geocode(name, city, country)
            if not pt:
                print(f"{city}: skip {name} (not found on OSM or Wikipedia)"); continue
            d = km(center, pt)
            if d > MAX_KM:
                print(f"{city}: skip {name} ({d:.0f} km away)"); continue
            keep.append((name, a, pt))
        if not keep:
            continue
        info = texts(city, [k[0] for k in keep], common)
        recs = []
        for name, a, (la, lo) in keep:
            t = info.get(name) or {}
            hl = t.get("highlights") or []
            a = a or [x for x in t.get("attributes", []) if x in common][:2]
            if not t.get("overview") or len(hl) < 2 or not a:
                print(f"{city}: skip {name} (no text)"); continue
            recs.append({"name": name, "latitude": la, "longitude": lo, "global_rank": 0, "local_rank": 0,
                         "attribute_rank": 0, "countriesIsoA3": [iso3.get(iso2, iso2)], "city": city, "attributes": a,
                         "overview": t["overview"], "history_significance": t.get("history_significance", ""),
                         "highlights": "\n ".join(hl)})
            have.add(name.lower())
            print(f"{city}: added {name} ({la}, {lo})")
        if not recs:
            continue
        blob = "".join(json.dumps(r, ensure_ascii=False, indent=2).replace("\n", "\n  ") + ",\n  " for r in recs)
        i = text.find(f'"city": "{city}"')
        s = text.rindex("{", 0, text.rindex('"name"', 0, i)) if i >= 0 else text.index("{")
        text = text[:s] + blob + text[s:]
    json.loads(text)
    LM.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1])
