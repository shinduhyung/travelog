"""After a GYG harvest: let DeepSeek pick each city's tours, keeping the reviewed status and signature.

    python add_tours.py [City ...]     # default: every city with gyg/<slug>.json except the 16 hand-made ones

deepseek_prep.draft() reruns the whole prep prompt, so the earlier status / signature / costs / missing are
put back after it and only "tours" (and tour problems) change. Then deepseek_prep.apply() writes
signature.json and assets/city_tour_links.json. Prints one line per city: tours picked, problems.
"""
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor

import deepseek_city as ds
import deepseek_prep as prep

HAND_MADE = {"Abu Dhabi", "London", "Paris", "Tokyo", "New York City", "Bangkok", "Lisbon", "Rome", "Barcelona",
             "Seoul", "Istanbul", "Singapore", "Sydney", "Dubai", "Prague", "Mexico City"}


def gyg_slug(city):
    return re.sub(r"[^a-z0-9-]+", "-", city.lower()).strip("-")


def one(city):
    pp = ds.DRAFTS / f"{ds.slug(city)}.prep.json"
    if not pp.exists():
        return f"{city}: no prep draft"
    old = json.loads(pp.read_text(encoding="utf-8"))
    new = prep.draft(city)
    for k in ("status", "signature", "costs", "missing"):
        new[k] = old.get(k, new.get(k))
    new["problems"] = [p for p in new.get("problems", []) if "tour" in p]
    pp.write_text(json.dumps(new, ensure_ascii=False, indent=1), encoding="utf-8")
    return f"{city}: {len(new['tours'])} tours" + (f" | {'; '.join(new['problems'][:3])}" if new["problems"] else "")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    hubs = [h["name"] for h in json.loads((ds.ROOT / "assets" / "top_city_hub_airport.json").read_text(encoding="utf-8"))]
    cities = sys.argv[1:] or [c for c in hubs if c not in HAND_MADE and (ds.HERE / "gyg" / f"{gyg_slug(c)}.json").exists()]
    with ThreadPoolExecutor(6) as pool:
        lines = list(pool.map(one, cities))
    for c, line in zip(cities, lines):  # apply writes shared files: one at a time
        if "tours" in line:
            prep.apply(c)
    print("\n".join(lines))
