"""Precompute a 0-10 location score for each tracked hotel from the app's own data (no API cost).

Usage (from the repo root, after fetch_prices.py created hotels/<city>.json):
    python tool/hotel_prices/location_scores.py --city "Abu Dhabi"

Inputs:  hotels/<city>.json (hotel coordinates), assets/all_landmarks.json (sights),
         assets/airports.json (airport), assets/cities.json (city center).
Output:  hotels/<city>_location.json, merged into report.json by analyze_prices.py.

Score = 60% sights + 20% city center + 20% airport, each 0-10.
Sights uses the 3 nearest sight spots (weighted 50/30/20), so a hotel next to one cluster
scores well even when the city's sights are far apart.
Distances are straight-line km, not driving time; fine for ranking hotels within one city.
"""

import argparse
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "assets")

# Per-city settings. Distances in km: full points at `near`, zero at `far`.
CITIES = {
    "Abu Dhabi": {
        "airport_iata": "AUH",
        # Abu Dhabi is spread out and car-based, so "near" is generous.
        "sights_near": 1.0, "sights_far": 8.0,
        "center_near": 2.0, "center_far": 20.0,
        "airport_near": 10.0, "airport_far": 45.0,
        # Approximate district centers, used only to label where a hotel is.
        "areas": {
            "Corniche & Downtown": (24.4860, 54.3570),
            "Breakwater & Marina": (24.4720, 54.3200),
            "Al Reem & Al Maryah Island": (24.4990, 54.3950),
            "Saadiyat Island": (24.5400, 54.4350),
            "Grand Mosque & Al Maqta": (24.4150, 54.4850),
            "Al Raha & Khalifa City": (24.4300, 54.5800),
            "Yas Island": (24.4900, 54.6050),
        },
    },
}

# Landmark entries that aren't places to visit on their own (a dish, an artwork inside a museum).
SKIP_ATTRIBUTES = {"Food", "Painting"}
SPOT_MERGE_KM = 0.3  # landmarks closer than this count as one spot (e.g. Yas theme parks)
NEAREST_SIGHT_WEIGHTS = (0.5, 0.3, 0.2)
AREA_MAX_KM = 3.0  # farther than this from every district center -> no area label

WEIGHTS = {"sights": 0.6, "center": 0.2, "airport": 0.2}


def slug(city):
    return city.lower().replace(" ", "_")


def km(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def closeness(d, near, far):
    """1.0 at or under `near` km, 0.0 at or over `far` km, linear between."""
    return max(0.0, min(1.0, (far - d) / (far - near)))


def load_json(*parts):
    with open(os.path.join(*parts), encoding="utf-8") as f:
        return json.load(f)


def sight_spots(city):
    """Group the city's landmarks into spots; a spot with several attractions weighs a bit more."""
    spots = []
    for l in load_json(ASSETS, "all_landmarks.json"):
        if l.get("city") != city or l.get("latitude") is None:
            continue
        if SKIP_ATTRIBUTES & set(l.get("attributes") or []):
            continue
        p = (float(l["latitude"]), float(l["longitude"]))
        spot = next((s for s in spots if km(s["pos"], p) < SPOT_MERGE_KM), None)
        if spot:
            spot["names"].append(l["name"])
        else:
            spots.append({"pos": p, "names": [l["name"]]})
    for s in spots:
        s["label"] = s["names"][0] if len(s["names"]) == 1 else f"{s['names'][0]} +{len(s['names']) - 1}"
    return spots


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--city", required=True, choices=sorted(CITIES))
    args = ap.parse_args()
    cfg = CITIES[args.city]

    hotels = load_json(HERE, "hotels", f"{slug(args.city)}.json")["hotels"]
    spots = sight_spots(args.city)
    airport = next(a for a in load_json(ASSETS, "airports.json").values() if a.get("iata") == cfg["airport_iata"])
    airport_pos = (airport["lat"], airport["lon"])
    center = next(r["values"] for r in load_json(ASSETS, "cities.json")["tables"][0]["records"]
                  if r["dimensions"]["name"] == args.city)
    center_pos = (center["latitude"], center["longitude"])

    rows = []
    for h in hotels:
        pos = (h["lat"], h["lng"])
        dists = sorted(((km(pos, s["pos"]), s) for s in spots), key=lambda t: t[0])
        sights = sum(w * closeness(d, cfg["sights_near"], cfg["sights_far"])
                     for w, (d, _) in zip(NEAREST_SIGHT_WEIGHTS, dists))
        center_km = km(pos, center_pos)
        airport_km = km(pos, airport_pos)
        parts = {
            "sights": sights,
            "center": closeness(center_km, cfg["center_near"], cfg["center_far"]),
            "airport": closeness(airport_km, cfg["airport_near"], cfg["airport_far"]),
        }
        area = min(cfg["areas"], key=lambda a: km(pos, cfg["areas"][a]))
        if km(pos, cfg["areas"][area]) > AREA_MAX_KM:
            area = None
        rows.append({
            "hotel_identifier": h["hotel_identifier"],
            "title": h["title"],
            "score": round(10 * sum(WEIGHTS[k] * v for k, v in parts.items()), 1),
            "parts": {k: round(10 * v, 1) for k, v in parts.items()},
            "area": area,
            "center_km": round(center_km, 1),
            "airport_km": round(airport_km, 1),
            "nearest_sights": [{"name": s["label"], "km": round(d, 1)} for d, s in dists[:3]],
        })
    rows.sort(key=lambda r: -r["score"])

    out = os.path.join(HERE, "hotels", f"{slug(args.city)}_location.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"city": args.city, "weights": WEIGHTS, "spots": [s["label"] for s in spots],
                   "airport": cfg["airport_iata"], "hotels": rows}, f, ensure_ascii=False, indent=2)

    print(f"{args.city}: {len(spots)} sight spots ({', '.join(s['label'] for s in spots)}), airport {cfg['airport_iata']}")
    print(f"{'score':>5} {'sights':>6} {'center':>6} {'airprt':>6}  {'hotel':36} {'area':27} nearest sight")
    for r in rows:
        p = r["parts"]
        near = r["nearest_sights"][0]
        print(f"{r['score']:>5} {p['sights']:>6} {p['center']:>6} {p['airport']:>6}  {r['title'][:35]:36} "
              f"{(r['area'] or '-')[:26]:27} {near['name'][:28]} {near['km']}km")
    print(f"Saved -> {os.path.relpath(out)}")


if __name__ == "__main__":
    main()
