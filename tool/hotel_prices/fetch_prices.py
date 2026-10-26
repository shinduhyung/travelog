"""Fetch a city's popular hotels and their 1-year price calendars from DataForSEO.

Usage (from the repo root):
    python tool/hotel_prices/fetch_prices.py --city "Abu Dhabi"            # real run
    python tool/hotel_prices/fetch_prices.py --city "Abu Dhabi" --dry-run  # cost estimate only

Credentials come from DATAFORSEO_LOGIN / DATAFORSEO_PASSWORD, or from tool/hotel_prices/.env
(git-ignored) with the same two lines. DataForSEO dashboard -> API Access shows both.

What it does:
  1. First run only: Google Hotels search for the city (most reviewed first) -> hotels/<city>.json.
     The hotel list is then fixed, so later snapshots compare the same hotels. --refresh-hotels redoes it.
  2. Every run: hotel_info for each hotel with load_prices_by_dates over a year
     -> data/<city>/<YYYY-MM-DD>.json (one snapshot per day).
Run analyze_prices.py afterwards to score the prices.
"""

import argparse
import base64
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
API_BASE = os.environ.get("DATAFORSEO_BASE_URL", "https://api.dataforseo.com")

# City -> map coordinate used for the search. Coordinates avoid guessing DataForSEO location names.
CITIES = {
    "Abu Dhabi": "24.4539,54.3773",
    "London": "51.5072,-0.1276",
    "Paris": "48.8566,2.3522",
    "Tokyo": "35.6812,139.7671",
    "New York City": "40.7580,-73.9855",
    "Bangkok": "13.7450,100.5340",
}

# Fixed comparison conditions: every snapshot uses the same stay shape.
ADULTS = 2
CURRENCY = "USD"
STAY_OFFSET_DAYS = 30  # "current price" = 1 night, 30 days from today

# Live-mode prices (USD) from DataForSEO's pricing page, Oct 2026. Check before scaling up.
COST_SEARCH_PER_18 = 0.004
COST_HOTEL_INFO = 0.004
PRICES_BY_DATES_MULTIPLIER = 2  # load_prices_by_dates doubles the hotel_info price


def slug(city):
    return city.lower().replace(" ", "_")


def load_credentials():
    login = os.environ.get("DATAFORSEO_LOGIN")
    password = os.environ.get("DATAFORSEO_PASSWORD")
    env_path = os.path.join(HERE, ".env")
    if (not login or not password) and os.path.exists(env_path):
        with open(env_path, encoding="utf-8") as f:
            for line in f:
                key, _, value = line.strip().partition("=")
                if key == "DATAFORSEO_LOGIN":
                    login = value.strip().strip('"')
                elif key == "DATAFORSEO_PASSWORD":
                    password = value.strip().strip('"')
    if not login or not password:
        sys.exit("Missing DATAFORSEO_LOGIN / DATAFORSEO_PASSWORD (env vars or tool/hotel_prices/.env).")
    return login, password


def post(path, task, auth, retries=3):
    """POST one live task and return tasks[0].result[0] (or raise)."""
    body = json.dumps([task]).encode("utf-8")
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=body,
        headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"},
        method="POST",
    )
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                payload = json.load(resp)
            break
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < retries:
                time.sleep(2 * attempt)
                continue
            raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}") from e
    if payload.get("status_code") != 20000:
        raise RuntimeError(f"API error {payload.get('status_code')}: {payload.get('status_message')}")
    t = payload["tasks"][0]
    if t.get("status_code") != 20000:
        raise RuntimeError(f"Task error {t.get('status_code')}: {t.get('status_message')}")
    return (t.get("result") or [None])[0]


def search_hotels(city, count, auth):
    result = post("/v3/business_data/google/hotel_searches/live", {
        "location_coordinate": CITIES[city],
        "language_code": "en",
        "currency": CURRENCY,
        "adults": ADULTS,
        "sort_by": "most_reviewed",
        "depth": count + 10,  # ads are dropped below
    }, auth)
    hotels = []
    for it in (result or {}).get("items") or []:
        if it.get("is_paid") or not it.get("hotel_identifier"):
            continue
        reviews = it.get("reviews") or {}
        loc = it.get("location") or {}
        hotels.append({
            "hotel_identifier": it["hotel_identifier"],
            "title": it.get("title"),
            "stars": it.get("stars"),
            "rating": reviews.get("value"),
            "votes": reviews.get("votes_count"),
            "lat": loc.get("latitude"),
            "lng": loc.get("longitude"),
        })
        if len(hotels) == count:
            break
    return hotels


def fetch_hotel(city, hotel, check_in, auth, adults=ADULTS):
    check_out = (dt.date.fromisoformat(check_in) + dt.timedelta(days=1)).isoformat()
    try:
        result = post("/v3/business_data/google/hotel_info/live/advanced", {
            "hotel_identifier": hotel["hotel_identifier"],
            "location_coordinate": CITIES[city],
            "language_code": "en",
            "currency": CURRENCY,
            "adults": adults,
            "check_in": check_in,
            "check_out": check_out,
            "load_prices_by_dates": True,
            "prices_start_date": dt.date.today().isoformat(),
            "prices_date_range": "year",
        }, auth)
    except RuntimeError as e:
        return {"hotel_identifier": hotel["hotel_identifier"], "title": hotel["title"], "error": str(e)}
    prices = (result or {}).get("prices") or {}
    calendar = {}
    for p in prices.get("prices_by_dates") or []:
        if p.get("price") is not None and p.get("check_in_date"):
            calendar[p["check_in_date"][:10]] = p["price"]
    sources = [
        {"title": s.get("title"), "price": s.get("price"), "official_site": s.get("official_site"),
         "max_visitors": max((o.get("max_visitors") or 0 for o in s.get("offers") or []), default=None)}
        for s in prices.get("items") or [] if s.get("price") is not None
    ]
    return {
        "hotel_identifier": hotel["hotel_identifier"],
        "title": hotel["title"],
        "check_in": check_in,
        "price": prices.get("price"),
        "price_without_discount": prices.get("price_without_discount"),
        "sources": sources,
        "prices_by_dates": dict(sorted(calendar.items())),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--city", required=True, choices=sorted(CITIES))
    ap.add_argument("--count", type=int, default=30, help="hotels per city (default 30)")
    ap.add_argument("--refresh-hotels", action="store_true", help="redo the hotel search")
    ap.add_argument("--adults", type=int, default=ADULTS, help=f"guests per room (default {ADULTS})")
    ap.add_argument("--sample-per-star", type=int, default=0,
                    help="test mode: only the N most-reviewed hotels of each star class")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and cost, call nothing")
    args = ap.parse_args()
    # Anything other than the standard run goes to data/<city>/tests/ so it never mixes
    # with the 2-adult price history that analyze_prices.py compares over time.
    is_test = args.adults != ADULTS or args.sample_per_star > 0

    hotels_path = os.path.join(HERE, "hotels", f"{slug(args.city)}.json")
    need_search = args.refresh_hotels or not os.path.exists(hotels_path)
    search_units = -(-(args.count + 10) // 18)
    n_hotels = args.sample_per_star * 3 if args.sample_per_star else args.count  # ~3 star classes
    cost = (COST_SEARCH_PER_18 * search_units if need_search else 0) \
        + n_hotels * COST_HOTEL_INFO * PRICES_BY_DATES_MULTIPLIER
    print(f"{args.city}: {'search + ' if need_search else ''}{n_hotels} price calendars "
          f"({args.adults} adults), est. ${cost:.2f}")
    if args.dry_run:
        return

    auth = base64.b64encode(":".join(load_credentials()).encode()).decode()

    if need_search:
        hotels = search_hotels(args.city, args.count, auth)
        os.makedirs(os.path.dirname(hotels_path), exist_ok=True)
        with open(hotels_path, "w", encoding="utf-8") as f:
            json.dump({"city": args.city, "created": dt.date.today().isoformat(), "hotels": hotels},
                      f, ensure_ascii=False, indent=2)
        print(f"Saved {len(hotels)} hotels -> {os.path.relpath(hotels_path)}")
    with open(hotels_path, encoding="utf-8") as f:
        hotels = json.load(f)["hotels"][: args.count]
    if args.sample_per_star:
        picked = {}
        for h in sorted(hotels, key=lambda h: -(h.get("votes") or 0)):
            picked.setdefault(h.get("stars"), [])
            if len(picked[h.get("stars")]) < args.sample_per_star:
                picked[h.get("stars")].append(h)
        hotels = [h for stars in sorted(picked, key=lambda s: s or 0) for h in picked[stars]]
        print("Sample: " + ", ".join(f"{h['stars']}* {h['title']}" for h in hotels))

    check_in = (dt.date.today() + dt.timedelta(days=STAY_OFFSET_DAYS)).isoformat()
    with ThreadPoolExecutor(max_workers=5) as pool:
        rows = list(pool.map(lambda h: fetch_hotel(args.city, h, check_in, auth, args.adults), hotels))

    today = dt.date.today().isoformat()
    out_path = os.path.join(HERE, "data", slug(args.city), "tests", f"{today}_adults{args.adults}.json")         if is_test else os.path.join(HERE, "data", slug(args.city), f"{today}.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"city": args.city, "fetched": today, "adults": args.adults, "currency": CURRENCY,
                   "hotels": rows}, f, ensure_ascii=False, indent=2)

    failed = [r for r in rows if "error" in r]
    days = [len(r.get("prices_by_dates", {})) for r in rows if "error" not in r]
    print(f"Saved snapshot -> {os.path.relpath(out_path)}")
    print(f"  {len(rows) - len(failed)} ok, {len(failed)} failed; calendar days per hotel: "
          f"min {min(days, default=0)}, max {max(days, default=0)}")
    for r in failed:
        print(f"  ! {r['title']}: {r['error']}")


if __name__ == "__main__":
    main()
