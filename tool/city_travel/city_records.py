"""City records keyed by name: assets/cities.json, plus a fallback from assets/cities15000.json for the
hub cities (top_city_hub_airport.json) the app's cities.json lacks. Fallback records use the cities.json
shape: {"dimensions": {name, country, country_iso}, "values": {latitude, longitude, population, isCapital}}.
The country comes from the hub airport (so Valencia -> Spain, San Jose -> USA), else the most populous row."""
import json
from functools import lru_cache
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[2] / "assets"
ALIAS = {"Seville": "Sevilla", "Florence": "Firenze"}  # cities15000 spelling for the hub name
CAPITALS = {"New Delhi"}  # national capitals among the fallback cities


def _load(name):
    return json.loads((ASSETS / name).read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def load_cities():
    cities = {r["dimensions"]["name"]: r for r in _load("cities.json")["tables"][0]["records"]}
    # cities.json files "George Town" under the Cayman Islands, but the hub airport (PEN) and the user mean
    # George Town, Penang: the trip pages use Penang (user, 2026-10-25)
    cities.pop("George Town", None)
    hubs = [h for h in _load("top_city_hub_airport.json") if h["name"] not in cities]
    if not hubs:
        return cities
    by_iata = {v["iata"]: v.get("country") for v in _load("airports.json").values() if v.get("iata")}
    names = {c["iso_a2"]: c["name"] for c in _load("countries_light.json")}
    names.update({r["dimensions"]["country_iso"]: r["dimensions"]["country"] for r in cities.values()})
    rows = {}
    for r in _load("cities15000.json"):
        rows.setdefault(r["name"], []).append(r)
    for h in hubs:
        iso2 = next((by_iata.get(i) for i in h.get("iata", []) if by_iata.get(i)), None)
        alts = [h["name"], h["name"].replace("St. ", "Saint "), ALIAS.get(h["name"], h["name"])]
        cand = [r for a in alts for r in rows.get(a, []) if r["country_code"] == iso2] or rows.get(h["name"], [])
        if not cand:
            continue
        r = max(cand, key=lambda r: r.get("population") or 0)
        cities[h["name"]] = {
            "dimensions": {"name": h["name"], "country": names.get(r["country_code"], r["country_code"]),
                           "country_iso": r["country_code"]},
            "values": {"latitude": r["latitude"], "longitude": r["longitude"],
                       "population": r.get("population"), "isCapital": h["name"] in CAPITALS},
        }
    return cities
