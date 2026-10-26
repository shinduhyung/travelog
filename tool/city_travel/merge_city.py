"""Merge facts (checked by Claude) + DeepSeek drafts into the files build_page.py reads, and validate.

    python tool/city_travel/merge_city.py "London"          # validate + write
    python tool/city_travel/merge_city.py "London" --check  # validate only

Writes itineraries/<slug>.json and planner/<slug>.json. Landmark coordinates always come from
assets/all_landmarks.json (never from the model). Exit code 1 when an error is found.
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from deepseek_city import slug  # noqa: E402

KINDS = {"sight", "museum", "park", "food", "activity", "tour", "beach", "show", "airport", "transit"}
SETTINGS = {"indoor", "outdoor", "mixed"}
HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


def km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def bounds(places, center, max_km=25):
    """Day-map area: every place within max_km of the center, padded 10%; zoom by span."""
    pts = [(p["lat"], p["lon"]) for p in places.values() if p.get("lat") is not None and km(center, (p["lat"], p["lon"])) <= max_km]
    lats, lons = [x for x, _ in pts], [y for _, y in pts]
    pad_lat, pad_lon = (max(lats) - min(lats)) * 0.1 + 0.005, (max(lons) - min(lons)) * 0.1 + 0.005
    span = max(max(lats) - min(lats), max(lons) - min(lons))
    return {"south": round(min(lats) - pad_lat, 4), "west": round(min(lons) - pad_lon, 4), "north": round(max(lats) + pad_lat, 4),
            "east": round(max(lons) + pad_lon, 4), "zoom": 13 if span < 0.12 else 12 if span < 0.3 else 11}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("city")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    s = slug(a.city)
    facts = json.loads((HERE / "facts" / f"{s}.json").read_text(encoding="utf-8"))
    load = lambda n: json.loads((HERE / "drafts" / f"{s}.{n}.json").read_text(encoding="utf-8"))
    places, frame, plans = load("places")["places"], load("frame"), load("plans")["plans"]
    lms = {l["name"]: l for l in json.loads((ROOT / "assets" / "all_landmarks.json").read_text(encoding="utf-8"))}
    center = tuple(facts["center"])
    errors, warns = [], []
    err, warn = errors.append, warns.append

    type_ids = {t["id"] for t in facts["types"]}
    for pid, p in places.items():
        if not re.fullmatch(r"[a-z][a-z0-9_-]{1,30}", pid):
            err(f"place id '{pid}' not short lowercase")
        if p.get("landmark"):
            lm = lms.get(p["landmark"])
            if not lm:
                err(f"{pid}: landmark '{p['landmark']}' not in all_landmarks.json")
            else:
                p["lat"], p["lon"] = float(lm["latitude"]), float(lm["longitude"])
        if p.get("kind") not in KINDS:
            err(f"{pid}: kind '{p.get('kind')}'")
        if p.get("setting") not in SETTINGS:
            err(f"{pid}: setting '{p.get('setting')}'")
        if not set(p.get("types") or []) <= type_ids:
            err(f"{pid}: types {p.get('types')} not in {sorted(type_ids)}")
        if not isinstance(p.get("popularity"), int) or not 1 <= p["popularity"] <= 5:
            err(f"{pid}: popularity")
        if p.get("area") not in facts["areas"]:
            warn(f"{pid}: area '{p.get('area')}' not one of the hotel areas")
        if p.get("lat") is not None and p.get("kind") != "tour":
            d = km(center, (p["lat"], p["lon"]))
            if d > facts.get("max_km", 60):
                warn(f"{pid}: {d:.0f} km from the center (day trip?)")
        elif p.get("kind") not in ("tour",):
            warn(f"{pid}: no coordinates")

    styles = {x["id"] for x in frame["styles"]}
    lengths = {x["id"] for x in frame["lengths"]}
    if not styles <= type_ids:
        err(f"styles {styles} not traveler type ids")
    if sum(1 for x in frame["lengths"] if x.get("recommended")) != 1:
        err("exactly one recommended length needed")
    if not set(frame["best_for"]) <= type_ids:
        err("best_for has unknown type ids")
    for t, row in frame["type_month_fit"].items():
        if t not in type_ids or len(row) != 12 or not all(0 <= v <= 1 for v in row):
            err(f"type_month_fit[{t}] bad")
    for st in frame["stays"]:
        if st["area"] not in facts["areas"]:
            err(f"stay area '{st['area']}' unknown")
        if km(center, st["center"]) > 40:
            err(f"stay '{st['area']}' center {km(center, st['center']):.0f} km away")

    have = set()
    for pl in plans:
        have.add((pl["length"], pl["style"]))
        if pl["length"] not in lengths or pl["style"] not in styles:
            err(f"plan {pl.get('id')}: unknown length/style")
        for d in pl["days"]:
            for st in d["stops"]:
                if not HHMM.match(st.get("at", "")):
                    err(f"plan {pl['id']}: time '{st.get('at')}'")
                if "tour" in st:
                    if not 0 <= st["tour"] < len(facts.get("tours", [])):
                        err(f"plan {pl['id']}: tour index {st['tour']}")
                    for c in st.get("covers", []):
                        if c not in places:
                            err(f"plan {pl['id']}: covers unknown place '{c}'")
                elif st.get("place") not in places:
                    err(f"plan {pl['id']}: unknown place '{st.get('place')}'")
    missing = {(l, s2) for l in lengths for s2 in styles} - have
    if missing:
        err(f"missing plans: {sorted(missing)}")

    for w in warns:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print(f"{a.city}: {len(places)} places, {len(plans)} plans, {len(errors)} errors, {len(warns)} warnings")
    if errors:
        sys.exit(1)
    if a.check:
        return

    itin_keys = ("styles", "lengths", "stays", "food", "more_time")
    meta_keys = ("types", "minutes", "setting", "best", "area", "popularity")
    itin = {"city": a.city, "checked": facts["checked"], "currency": facts["currency"], "usd_rate": facts["usd_rate"],
            "intro": facts.get("intro", ""), "tour_note": facts.get("tour_note", "Check the tour page for which entry tickets are included."),
            "maps": {"city": facts.get("map_bounds") or bounds(places, center)},
            "transport": {"taxi": facts["taxi"], "road_factor": facts.get("road_factor", 1.3), "city_kmh": facts.get("city_kmh", 25),
                          "notes": facts["transit_facts"], "sources": facts.get("transport_sources", [])},
            "places": {pid: {k: v for k, v in p.items() if k not in meta_keys} for pid, p in places.items()},
            "plans": plans, **{k: frame[k] for k in itin_keys}}
    types = [{**t, "areas": t.get("areas") or facts["areas"]} for t in facts["types"]]
    months = [dict(m) for m in facts["climate_months"]]
    for m, note in zip(months, frame.get("month_notes") or []):
        m["note"] = note
    planner = {"city": a.city, "checked": facts["checked"], "intro_line": facts.get("intro_line", ""),
               "note": "Typical figures for planning; check hours and prices on the day.",
               "types": types, "climate": {"source": facts["climate_source"], "months": months},
               "type_month_fit": frame["type_month_fit"],
               "places": {pid: {k: p[k] for k in meta_keys if k in p} for pid, p in places.items()},
               "recommend": frame["recommend"], "airports": facts["airports"], "airports_checked": facts["checked"],
               "airports_sources": facts.get("airports_sources", []), "best_for": frame["best_for"],
               "transit": frame["transit"], "climate_guide": frame["climate_guide"]}
    (HERE / "itineraries" / f"{s}.json").write_text(json.dumps(itin, ensure_ascii=False, indent=2), encoding="utf-8")
    (HERE / "planner" / f"{s}.json").write_text(json.dumps(planner, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote itineraries/{s}.json and planner/{s}.json")


if __name__ == "__main__":
    main()
