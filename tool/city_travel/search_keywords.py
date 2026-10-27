"""English search keywords per city page: city, country and landmark names plus their aliases.

Real names first: Wikidata English labels and aliases (city matched by distance, country by ISO code,
landmarks by name + distance). Then Claude Haiku (via deepseek_city.ask) adds common English
abbreviations and nicknames Wikidata misses (NYC, Big Apple, USA, America...).

Output: assets/city_search_keywords.json  {city: {"city": [...], "country": [...], "landmarks": {name: [...]}, "all": [...]}}
Cache:  search_kw_cache/  (re-runs skip finished work)

  python search_keywords.py            # all 192 hub cities
  python search_keywords.py Seoul      # one city
"""
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import city_records
import landmarks as landmark_section
from deepseek_city import ask

HERE = Path(__file__).parent
ASSETS = city_records.ASSETS
CACHE = HERE / "search_kw_cache"
OUT = ASSETS / "city_search_keywords.json"
UA = "jidoapp-search-keywords/1.0 (leeahn137@gmail.com)"
WD = "https://www.wikidata.org/w/api.php"


def get(url, tries=5):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            return json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception:
            time.sleep(2 * (i + 1))
    return {}


def km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (*a, *b))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def cached(kind, key, fn):
    f = CACHE / kind / (re.sub(r"[^\w.-]+", "_", key)[:120] + ".json")
    if f.is_file():
        return json.loads(f.read_text(encoding="utf-8"))
    val = fn()
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(val, ensure_ascii=False), encoding="utf-8")
    return val


def names_of(ent):
    out = [ent.get("labels", {}).get("en", {}).get("value", "")]
    out += [a["value"] for a in ent.get("aliases", {}).get("en", [])]
    return [n for n in out if n]


def coord(ent):
    for c in ent.get("claims", {}).get("P625", []):
        v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
        if v:
            return v["latitude"], v["longitude"]
    return None


def wd_match(name, center, max_km):
    """English names of the Wikidata item called `name` that lies within max_km of center."""
    def run():
        q = urllib.parse.urlencode({"action": "wbsearchentities", "search": name, "language": "en",
                                    "limit": 7, "format": "json"})
        ids = [h["id"] for h in get(f"{WD}?{q}").get("search", [])]
        if not ids:
            return []
        q = urllib.parse.urlencode({"action": "wbgetentities", "ids": "|".join(ids), "languages": "en",
                                    "props": "labels|aliases|claims", "format": "json"})
        ents = get(f"{WD}?{q}").get("entities", {})
        for i in ids:  # search order = relevance
            c = coord(ents.get(i, {}))
            if c and center and km(c, center) <= max_km:
                return names_of(ents[i])
        return []
    return cached("wd", f"{name}@{round(center[0], 1)},{round(center[1], 1)}" if center else name, run)


def wd_country(iso2):
    def run():
        sparql = f'SELECT ?c WHERE {{ ?c wdt:P297 "{iso2}" }} LIMIT 1'
        r = get("https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": sparql, "format": "json"}))
        b = r.get("results", {}).get("bindings", [])
        if not b:
            return []
        qid = b[0]["c"]["value"].rsplit("/", 1)[1]
        q = urllib.parse.urlencode({"action": "wbgetentities", "ids": qid, "languages": "en",
                                    "props": "labels|aliases", "format": "json"})
        return names_of(get(f"{WD}?{q}").get("entities", {}).get(qid, {}))
    return cached("country", iso2, run)


SYSTEM = ("You write English search keywords for a travel app. Return only JSON. Include every name an "
          "English-speaking traveller might type: official and short names, common abbreviations and acronyms "
          "(NYC, LA, USA, UK, UAE), nicknames (Big Apple), former names, spellings without accents, and "
          "local names written in Latin letters. No translations into other languages, no descriptions, "
          "no generic words like 'city' or 'museum' on their own.")


def ai_extra(city, country, lms):
    def run():
        user = (f"City: {city}\nCountry: {country}\nLandmarks:\n" + "\n".join(f"- {n}" for n in lms) +
                '\n\nReturn {"city": [...], "country": [...], "landmarks": {"<exact landmark name>": [...]}}. '
                "Give 3-10 keywords for the city and the country, 1-5 for each landmark.")
        txt = ask(SYSTEM, user, max_tokens=8000)
        if isinstance(txt, dict):
            return txt
        m = re.search(r"\{.*\}", txt or "", re.S)
        try:
            return json.loads(m.group(0)) if m else {}
        except json.JSONDecodeError:
            return {}
    return cached("ai", city, run)


def clean(words, *drop):
    seen, out = {w.lower() for w in drop}, []
    for w in words:
        w = re.sub(r"\s+", " ", str(w)).strip()
        if 1 < len(w) <= 80 and w.lower() not in seen and not re.search(r"\.(com|org|net)|https?:", w):
            seen.add(w.lower())
            out.append(w)
    return out


def build(city, cities, all_lms):
    rec = cities[city]
    v, d = rec["values"], rec["dimensions"]
    center = (v["latitude"], v["longitude"])
    country = d.get("country", "")
    lm_recs = landmark_section.collect(city, center, all_lms, set(cities))
    lms = [lm["name"] for lm in lm_recs]
    # Towns the page's landmarks belong to (Suwon -> Seoul, Vatican City -> Rome) so searching them finds this city.
    lm_towns = sorted({lm["city"] for lm in lm_recs if lm.get("city") and lm["city"] != city})
    with ThreadPoolExecutor(6) as ex:
        lm_wd = dict(zip(lms, ex.map(lambda n: wd_match(re.sub(r"\s*\(.*?\)", "", n), center, 60), lms)))
    ai = ai_extra(city, country, lms)
    ai_lm = ai.get("landmarks", {}) if isinstance(ai.get("landmarks"), dict) else {}
    city_kw = clean([city, *wd_match(city, center, 40), *ai.get("city", [])])
    country_kw = clean([country, *wd_country(d.get("country_iso", "")), *ai.get("country", [])])
    lm_kw = {n: clean([n, *lm_wd.get(n, []), *ai_lm.get(n, [])]) for n in lms}
    every = clean([*city_kw, *country_kw, *lm_towns, *(w for ws in lm_kw.values() for w in ws)])
    return {"city": city_kw, "country": country_kw, "nearby_towns": lm_towns, "landmarks": lm_kw, "all": every}


def main(args):
    cities = city_records.load_cities()
    all_lms = json.loads((ASSETS / "all_landmarks.json").read_text(encoding="utf-8"))
    hub = [h["name"] for h in json.loads((ASSETS / "top_city_hub_airport.json").read_text(encoding="utf-8"))]
    todo = args or hub
    out = json.loads(OUT.read_text(encoding="utf-8")) if OUT.is_file() else {}
    for i, city in enumerate(todo, 1):
        try:
            out[city] = build(city, cities, all_lms)
            print(f"[{i}/{len(todo)}] {city}: {len(out[city]['all'])} keywords", flush=True)
        except Exception as ex:
            print(f"[{i}/{len(todo)}] {city}: ERROR {ex}", flush=True)
        if i % 10 == 0 or i == len(todo):
            OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1:])
