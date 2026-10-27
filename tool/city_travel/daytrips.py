"""Day trips from a city: fetch real travel data -> DeepSeek draft -> validation -> daytrips/<slug>.json.

    PYTHONIOENCODING=utf-8 python tool/city_travel/daytrips.py Rome Paris Tokyo
    python tool/city_travel/daytrips.py --summary Rome Paris Tokyo

Rules (agreed 2026-10-24): 0 to 5 trips per city, only places genuinely known as day trips from
the city (never pad; 0 = no section), roughly <= 3 h each way, no overnight destinations.
Real data only for numbers:
  - destination coordinates: Omio suggester (position API);
  - road km + drive time: OSRM demo server (fallback haversine x facts road_factor at 70 km/h);
  - train / bus "from" price, typical duration, departures per day: Omio route page FAQ
    (fallback Rome2Rio FAQ, e.g. Japan, which Omio does not cover);
  - taxi: facts/<slug>.json taxi tariff x road km (tolls not included);
  - landmark quests: all_landmarks.json within RADIUS_KM of the destination.
DeepSeek only writes: the candidate list, what to see, the practical route note and a one-line reason
for the recommended way (chosen from the real numbers it is given).
"""
import html as htmlmod
import json
import math
import re
import sys
import time
import urllib.parse
from pathlib import Path

from curl_cffi import requests as http

import deepseek_city as ds

HERE = Path(__file__).resolve().parent
OUT = HERE / "daytrips"
RADIUS_KM = 6
MAX_TRIPS = 5
FORCED = {"Johor Bahru", "Malmö", "Malmo", "Vaduz", "Lucerne", "Hakone", "Perast", "Málaga"}
REPICK = "--repick" in sys.argv
# Claude's judgment calls on the DeepSeek list (pilot 2026-10-24).
DROP = {"Zurich": ["Winterthur"],  # make room for Lucerne (5-trip cap); a 16 min suburban hop
        "Seoul": ["Suwon"],    # already attached to Seoul as landmarks (Hwaseong Fortress), not a separate day trip
        "Rome": ["Naples"],      # its own app city / multi-day destination; Pompeii covers the area
        }
EXTRA_QUESTS = {"Tokyo": {"Mt Fuji & Lake Kawaguchi": ["Mount Fuji"], "Hakone": ["Hakone Ropeway"]}}  # the mountain is the point of the trip


def get(url):
    for attempt in range(3):
        try:
            r = http.get(url, impersonate="chrome", timeout=40, cookies={"currency": "USD"})
            if r.status_code in (200, 404, 410):
                return r.text if r.status_code == 200 else ""
        except Exception as ex:  # network hiccup -> retry, then treated as no data
            print(f"  fetch failed {url}: {ex}")
        time.sleep(3 + attempt * 5)
    return ""


def _norm_words(s):
    import unicodedata
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()


def _norm(s):
    import unicodedata
    return re.sub(r"[^a-z]", "", unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower())


TOWNS = None


def town_entry(names, cc, near, max_km=25):
    """Rule (2026-10-24): a destination must be a city in assets/cities15000.json, same country,
    name equal or a close spelling variant (Pompeii ~ Pompei, Nikko ~ Nikko), within max_km of the place."""
    global TOWNS
    import difflib
    if TOWNS is None:
        TOWNS = json.loads((ds.ROOT / "assets" / "cities15000.json").read_text(encoding="utf-8"))
    keys = [_norm(n) for n in names if n]
    best = None
    for t in TOWNS:
        if t["country_code"] != cc:
            continue
        tn = _norm(t["name"])
        score = max((1.0 if tn == k else difflib.SequenceMatcher(None, tn, k).ratio()) for k in keys) if keys else 0
        if score >= 0.85 and km(near, (t["latitude"], t["longitude"])) <= max_km and (best is None or score > best[0]):
            best = (score, t)
    return best[1] if best else None


def origin_cc(center):
    town_entry([], "", center)  # loads TOWNS
    return min(TOWNS, key=lambda t: km(center, (t["latitude"], t["longitude"])))["country_code"]


def km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def position(term, near):
    try:
        res = json.loads(get("https://www.omio.com/suggester-api/v5/position?term=" + urllib.parse.quote(term) + "&locale=en") or "[]")
    except ValueError:
        return None
    best = None
    for p in res[:6]:
        if p.get("latitude") is None:
            continue
        d = km(near, (p["latitude"], p["longitude"]))
        if d < 400 and (best is None or d < best[0]):
            best = (d, p)
    if not best:
        return None
    p = best[1]
    return {"id": p["positionId"], "name": p["displayName"], "city": p.get("defaultCityName"), "lat": round(p["latitude"], 5), "lng": round(p["longitude"], 5)}


def road(a, b, factor):
    url = f"https://router.project-osrm.org/route/v1/driving/{a[1]},{a[0]};{b[1]},{b[0]}?overview=false"
    try:
        r = http.get(url, impersonate="chrome", timeout=30).json()
        rt = r["routes"][0]
        return {"km": round(rt["distance"] / 1000), "min": round(rt["duration"] / 60), "source": "OSRM"}
    except Exception:
        d = km(a, b) * factor
        return {"km": round(d), "min": round(d / 70 * 60), "source": "haversine x road factor"}


def omio(mode, frm, to):
    url = f"https://www.omio.com/{mode}/{frm}/{to}"
    t = get(url)
    c = re.search(r"cheapest ticket starts at \$?([0-9,.]+) \(([^)]+)\)", t)
    d = re.search(r"takes ([0-9]+h(?: [0-9]+m)?|[0-9]+m) and runs ([0-9]+) per day", t)
    if not (c and d):
        return None
    avg = re.search(r"average price is around \$?[0-9,.]+ \(([^)]+)\)", t)
    return {"from": c.group(2), "from_usd": float(c.group(1).replace(",", "")), "avg": avg.group(1) if avg else None,
            "time": d.group(1), "per_day": int(d.group(2)), "source": url}


def rome2rio(frm, to):
    """Route options listed on the Rome2Rio page (first train and first bus option), plus drive fuel cost."""
    url = f"https://www.rome2rio.com/s/{urllib.parse.quote(frm)}/{urllib.parse.quote(to)}"
    t = htmlmod.unescape(get(url)).replace(" ", " ")
    t = re.sub(r"<script[\s\S]*?</script>|<style[\s\S]*?</style>", "", t)
    x = re.sub(r"(\s*\|\s*)+", " | ", re.sub(r"<[^>]+>", "|", t))
    out = {}
    for m in re.finditer(r"Take the (train|bus) from ([^|]+?) to ([^|]+?) \|(.{0,160}?)\| (\d+h(?: \d+m)?|\d+m|\d+ min) \|(?: (\$[\d,]+(?:–[\d,]+)?) \|)?", x):
        mode = m.group(1)
        if mode not in out:
            out[mode] = {"price": m.group(6).replace("–", "-$") if m.group(6) else None, "time": m.group(5).replace(" min", "m"),
                         "via": f"{m.group(2).strip()} to {m.group(3).strip()}", "source": url}
    d = re.search(r"Drive from [^|]+ \|.{0,160}?\| [\d.]+ km \| (\d+h(?: \d+m)?|\d+m|\d+ min) \|.{0,80}?\| (\$[\d,]+(?:–[\d,]+)?) \|", x)
    if d:
        out["drive"] = {"price": d.group(2).replace("–", "-$"), "time": d.group(1), "source": url}
    return out


def minutes(s):
    if not s:
        return None
    h = re.search(r"(\d+)h", s)
    m = re.search(r"(\d+)m", s)
    return (int(h.group(1)) if h else 0) * 60 + (int(m.group(1)) if m else 0)


def fmt_min(m):
    return f"{m // 60} h {m % 60:02d}" if m >= 60 else f"{m} min"


CANDIDATES_SYS = """You are a careful travel editor. Return JSON only.
List the day trips that are GENUINELY and commonly known as day trips from the given city: places a
typical visitor really does as a return trip in one day, roughly 3 hours or less each way, no overnight.
Return 0 to 5 trips. Never pad the list: if the city has only 1 or 2 real day trips, return those; if none, return [].
Do NOT include: places inside the city or its suburbs that are a normal city visit, places listed in
"skip", or separate destinations that need a night.
For each trip:
  "town": the municipality the trip is based in, exactly as a town/city name (e.g. "Fujikawaguchiko"),
  "place": the TOWN or CITY name only (a real municipality, e.g. "Florence", "Pompei", "Nikko"), never a sight,
           park, lake, mountain or region name (not "Mt Fuji", "Loire Valley", "Monet's Garden"),
  "search": the best rail/bus station or town name to look up on Omio (e.g. "Pompei", "Vernon", "Kawaguchiko"),
  "omio_from": city slug as used in omio.com URLs (lowercase, hyphens, e.g. "rome"),
  "omio_to": destination slug for omio.com/trains/<from>/<to> (e.g. "florence", "pompei", "vernon"),
  "r2r_from"/"r2r_to": names for rome2rio.com/s/<from>/<to> (e.g. "Tokyo", "Kamakura"),
  "landmark_at": [lat, lng] of the main sight (for nearby-landmark lookup),
  "route_note": one practical sentence on HOW the public-transport route works (changes, last leg such as a shuttle bus or local line), no prices,
  "see": 3 to 5 short items for a half-day or one-day visit,
  "visit": "Half day" or "Full day",
  "tour_query": a GetYourGuide search phrase for a day tour from the city (e.g. "Pompeii day trip from Rome")."""

PICK_SYS = """You choose the recommended way to do a day trip, using ONLY the numbers given. Return JSON only:
{"trips": [{"place": ..., "recommended": "train"|"bus"|"car"|"taxi"|"tour", "why": one short sentence,
  "stars": 1-5 integer, how worthwhile this day trip is for a FIRST-TIME visitor to the city (5 = classic, unmissable; use the full range, not all 4-5),
  "know": 1 to 3 short key things to know (closing days, booking ahead, best time/season to go), only well-established facts}]}
Rules: train or bus when it is fast, frequent and drops you near the sights; car/taxi only when it is clearly
better (short road trip with poor transit, or several scattered sights); tour when public transport is
impractical (many changes, rare services, sights spread out, or > 2h30 each way with a last-mile problem).
Do not invent numbers; do not mention prices unless given."""


def build(city, cities, lms, skip, attach):
    s = ds.slug(city)
    facts = json.loads((HERE / "facts" / f"{s}.json").read_text(encoding="utf-8"))
    center = facts["center"]
    print(f"== {city}")
    cache = OUT / f"{s}.candidates.json"
    if cache.exists():
        cand = json.loads(cache.read_text(encoding="utf-8"))
    else:
        cand = ds.ask(CANDIDATES_SYS, json.dumps({"city": city, "skip": sorted(attach),
                                                    "format": {"trips": ["..."]}}), 3000).get("trips", [])[:MAX_TRIPS]
        OUT.mkdir(exist_ok=True)
        cache.write_text(json.dumps(cand, ensure_ascii=False, indent=1), encoding="utf-8")
    cand = [c for c in cand if c["place"] not in DROP.get(city, [])]
    trips, problems = [], []
    cc = origin_cc(center)
    for c in cand:
        pos = position(c.get("search") or c["place"], center)
        if not pos and c.get("force_town"):  # no Omio station (Perast, Hakone): use the hand-set town point
            ft = c["force_town"]
            pos = {"id": None, "name": ft["name"], "city": ft["name"], "lat": ft["lat"], "lng": ft["lng"]}
        if not pos:
            problems.append(f"{c['place']}: no Omio position, dropped")
            continue
        label = c.get("label") or c["place"]
        names = [re.sub(r"\s*[(&].*", "", label).strip()]
        # Town names from DeepSeek / Omio / Rome2Rio count only when they share a word with the label
        # (Fujikawaguchiko ~ "Lake Kawaguchi"), so a nearby station town (Giverny -> Vernon) is never swapped in.
        words = [w for w in re.findall(r"[a-z]{5,}", _norm_words(label))]
        for extra in (c.get("town"), pos.get("city"), pos.get("name"), c.get("r2r_to"), c.get("search")):
            if extra and any(w in _norm(extra) for w in words):
                names.append(extra)
        town = town_entry(names, c.get("cc") or cc, c.get("landmark_at") or (pos["lat"], pos["lng"]))
        if not town and c.get("force_town"):  # cross-border or <15000 pop (Johor Bahru, Malmo, Vaduz), chosen by hand
            town = {"name": c["force_town"]["name"], "latitude": c["force_town"]["lat"], "longitude": c["force_town"]["lng"]}
        if not town:
            problems.append(f"{c['place']}: not a town in cities15000.json ({cc}), dropped")
            continue
        c["label"] = label
        c["place"] = town["name"]
        dest = (town["latitude"], town["longitude"])
        r = road(center, dest, facts.get("road_factor", 1.3))
        if r["min"] > 200:
            problems.append(f"{c['place']}: {r['min']} min by road, dropped (too far for a day trip)")
            continue
        modes = {}
        for m, key in (("trains", "train"), ("buses", "bus")):
            o = omio(m, c.get("omio_from", s), c.get("omio_to", ""))
            if o:
                modes[key] = o
        if len(modes) < 2:  # fill missing train/bus from Rome2Rio (Omio does not cover e.g. Japan)
            rr = {}
            for name in dict.fromkeys([c.get("r2r_to") or c["place"], c.get("search") or "", pos["name"]]):
                rr = rome2rio(c.get("r2r_from", city), name) if name else {}
                if rr.get("train") or rr.get("bus"):
                    break
            for k in ("train", "bus"):
                if k not in modes and rr.get(k) and rr[k]["time"]:
                    modes[k] = {"from": rr[k]["price"], "time": rr[k]["time"], "via": rr[k]["via"], "source": rr[k]["source"]}
        t = facts["taxi"]
        taxi = round(t["flag_day"] + t["per_km"] * r["km"], -1)
        near = [lm for lm in lms if lm.get("latitude") is not None
                and km(c.get("landmark_at") or dest, (float(lm["latitude"]), float(lm["longitude"]))) <= RADIUS_KM]
        near = [lm for lm in near if lm["name"] not in attach and lm.get("city") not in attach]
        quests = [lm["name"] for lm in sorted(near, key=lambda l: int(l.get("global_rank") or 0) or 10 ** 6)][:8]
        quests = list(dict.fromkeys(EXTRA_QUESTS.get(city, {}).get(c["label"], []) + quests))
        trips.append({"place": c["place"], "label": c["label"] if _norm(c["label"]) != _norm(c["place"]) else "", "position": pos, "town": {"name": town["name"], "lat": town["latitude"], "lng": town["longitude"]}, "road": r, "taxi": {"amount": taxi, "currency": facts["currency"]},
                      "modes": modes, "route_note": c.get("route_note", ""), "see": c.get("see", [])[:5],
                      "visit": c.get("visit", "Full day"), "tour_query": c.get("tour_query", f"{c['place']} day trip from {city}"),
                      "quests": quests})
    # Stars / recommended way / why / know are drafted ONCE per trip and kept on re-runs
    # (pass --repick to redraft them).
    old_path = OUT / f"{s}.json"
    old = {} if REPICK or not old_path.exists() else {t["place"]: t for t in json.loads(old_path.read_text(encoding="utf-8")).get("trips", [])}
    for t in trips:
        o = old.get(t["place"])
        if o and "stars" in o:
            for k in ("recommended", "why", "stars", "know"):
                t[k] = o.get(k)
    new = [t for t in trips if "stars" not in t]
    if new:
        brief = [{"place": t["place"], "drive_min": t["road"]["min"], "road_km": t["road"]["km"],
                  "taxi": f"{t['taxi']['amount']:.0f} {t['taxi']['currency']}", "route_note": t["route_note"],
                  **{k: {"time": v["time"], "per_day": v.get("per_day"), "price_from": v["from"], "via": v.get("via")} for k, v in t["modes"].items()}}
                 for t in new]
        picks = {p["place"]: p for p in ds.ask(PICK_SYS, json.dumps({"city": city, "trips": brief}), 1500).get("trips", [])}
        for t in new:
            p = picks.get(t["place"], {})
            rec = p.get("recommended")
            if rec in ("train", "bus") and rec not in t["modes"]:
                problems.append(f"{t['place']}: model picked {rec} without data; set to tour")
                rec = "tour"
            t["recommended"] = rec if rec in ("train", "bus", "car", "taxi", "tour") else "tour"
            t["why"] = p.get("why", "")
            t["stars"] = min(5, max(1, int(p.get("stars") or 3)))
            t["know"] = [k for k in (p.get("know") or []) if isinstance(k, str)][:3]
    trips.sort(key=lambda t: -t["stars"])
    validate(trips, problems)
    data = {"city": city, "trips": trips, "problems": problems}
    OUT.mkdir(exist_ok=True)
    (OUT / f"{s}.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return data


def validate(trips, problems):
    for t in trips:
        if t["place"] in FORCED:
            continue
        if not TOWNS or not any(_norm(x["name"]) == _norm(t["place"]) for x in TOWNS):
            problems.append(f"{t['place']}: not a cities15000 name")
        if not t["see"]:
            problems.append(f"{t['place']}: nothing to see")
        if t["recommended"] in ("train", "bus") and (minutes(t["modes"][t["recommended"]]["time"]) or 0) > 200:
            problems.append(f"{t['place']}: {t['recommended']} over 3h20")
    if len(trips) > MAX_TRIPS:
        problems.append("more than 5 trips")


def summary(city):
    p = OUT / f"{ds.slug(city)}.json"
    if not p.exists():
        print(f"{city}: no file")
        return
    d = json.loads(p.read_text(encoding="utf-8"))
    print(f"{city}: {len(d['trips'])} trips")
    for t in d["trips"]:
        m = t["modes"].get(t["recommended"], {})
        print(f"  {t.get('stars')}* {t['place']} | rec {t['recommended']} {m.get('time', '')} {m.get('from', '')} | road {t['road']['km']} km "
              f"{t['road']['min']} min | taxi {t['taxi']['amount']:.0f} | modes {','.join(t['modes'])} | quests {len(t['quests'])}: "
              + "; ".join(t["quests"]))
    for x in d["problems"]:
        print("  ! " + x)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--summary" in sys.argv:
        for c in args:
            summary(c)
        sys.exit()
    import city_records
    import landmarks as landmark_section
    cities = city_records.load_cities()
    lms = json.loads((ds.ROOT / "assets" / "all_landmarks.json").read_text(encoding="utf-8"))
    scope = json.loads((HERE / "landmark_scope.json").read_text(encoding="utf-8"))
    for city in args:
        rec = cities[city]
        own = landmark_section.collect(city, (rec["values"].get("latitude"), rec["values"].get("longitude")), lms, set(cities))
        skip = set(scope.get("attach", {}).get(city, [])) | {lm["name"] for lm in own}
        build(city, cities, lms, skip, set(scope.get("attach", {}).get(city, [])))
        summary(city)
