"""Score a city's hotel prices from the snapshots fetch_prices.py saved.

Usage (from the repo root):
    python tool/hotel_prices/analyze_prices.py --city "Abu Dhabi"
    python tool/hotel_prices/analyze_prices.py --city "Abu Dhabi" --date 2026-12-10

For one stay date (default: the check-in of the latest snapshot) each hotel gets:
  - position  where that night's price sits in the hotel's own calendar for the next 180 days,
              same weekday only, so weekends don't look "expensive" just for being weekends.
              0% = cheapest such night, 100% = most expensive.
  - trend     change vs. the first snapshot that had a price for the same date
              (needs 2+ snapshot days; "rising" means book now).
  - vs peers  price vs. the median of same-star hotels on that date.
  - color     green <= 25% position, red >= 75%, otherwise neutral.
Also lists each hotel's cheapest upcoming nights (next 90 days) relative to its median.
Adds each hotel's location score from hotels/<city>_location.json when location_scores.py has run.
Writes data/<city>/report.json for the app / page to read.
"""

import argparse
import datetime as dt
import glob
import json
import os
import statistics

HERE = os.path.dirname(os.path.abspath(__file__))

GREEN_MAX_POSITION = 25
RED_MIN_POSITION = 75
TREND_THRESHOLD = 10  # percent change that counts as rising / falling
POSITION_WINDOW_DAYS = 180
DEALS_WINDOW_DAYS = 90


def slug(city):
    return city.lower().replace(" ", "_")


def load_snapshots(city):
    paths = sorted(glob.glob(os.path.join(HERE, "data", slug(city), "????-??-??.json")))
    snaps = []
    for p in paths:
        with open(p, encoding="utf-8") as f:
            snaps.append(json.load(f))
    return snaps


def position(calendar, date, today):
    """Percent of same-weekday nights in the window that are cheaper than `date`'s price."""
    price = calendar.get(date)
    if price is None:
        return None
    weekday = dt.date.fromisoformat(date).weekday()
    end = today + dt.timedelta(days=POSITION_WINDOW_DAYS)
    same = [p for d, p in calendar.items()
            if today <= dt.date.fromisoformat(d) <= end and dt.date.fromisoformat(d).weekday() == weekday]
    if len(same) < 4:
        return None
    cheaper = sum(1 for p in same if p < price)
    equal = sum(1 for p in same if p == price)
    return round(100 * (cheaper + 0.5 * (equal - 1)) / (len(same) - 1)) if len(same) > 1 else 50


def trend(snaps, hotel_id, date):
    """(first seen price, latest price, % change) for one hotel and stay date across snapshots."""
    seen = []
    for s in snaps:
        for h in s["hotels"]:
            if h["hotel_identifier"] == hotel_id and date in h.get("prices_by_dates", {}):
                seen.append((s["fetched"], h["prices_by_dates"][date]))
    if len(seen) < 2:
        return None
    (first_day, first), (last_day, last) = seen[0], seen[-1]
    return {"first_seen": first_day, "first_price": first, "latest_price": last,
            "change_pct": round(100 * (last - first) / first, 1) if first else None}


def color(pos):
    if pos is None:
        return "unknown"
    if pos <= GREEN_MAX_POSITION:
        return "green"
    if pos >= RED_MIN_POSITION:
        return "red"
    return "neutral"


def cheapest_nights(calendar, today, n=3):
    end = today + dt.timedelta(days=DEALS_WINDOW_DAYS)
    window = {d: p for d, p in calendar.items() if today <= dt.date.fromisoformat(d) <= end}
    if len(window) < 7:
        return []
    median = statistics.median(window.values())
    best = sorted(window.items(), key=lambda kv: kv[1])[:n]
    return [{"date": d, "price": p, "vs_median_pct": round(100 * (p - median) / median, 1)} for d, p in best]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--city", required=True)
    ap.add_argument("--date", help="stay date yyyy-mm-dd (default: latest snapshot's check-in)")
    args = ap.parse_args()

    snaps = load_snapshots(args.city)
    if not snaps:
        raise SystemExit(f"No snapshots in data/{slug(args.city)}/ - run fetch_prices.py first.")
    latest = snaps[-1]
    today = dt.date.fromisoformat(latest["fetched"])
    hotels_meta = {}
    meta_path = os.path.join(HERE, "hotels", f"{slug(args.city)}.json")
    if os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            hotels_meta = {h["hotel_identifier"]: h for h in json.load(f)["hotels"]}

    locations = {}
    loc_path = os.path.join(HERE, "hotels", f"{slug(args.city)}_location.json")
    if os.path.exists(loc_path):
        with open(loc_path, encoding="utf-8") as f:
            locations = {h["hotel_identifier"]: h for h in json.load(f)["hotels"]}

    ok = [h for h in latest["hotels"] if "error" not in h]
    date = args.date or next((h["check_in"] for h in ok if h.get("check_in")), None)
    if not date:
        raise SystemExit("No stay date in the snapshot; pass --date.")

    # Peer medians: same star class, same date.
    by_stars = {}
    for h in ok:
        stars = hotels_meta.get(h["hotel_identifier"], {}).get("stars")
        p = h.get("prices_by_dates", {}).get(date)
        if stars and p:
            by_stars.setdefault(stars, []).append(p)

    rows = []
    for h in ok:
        meta = hotels_meta.get(h["hotel_identifier"], {})
        cal = h.get("prices_by_dates", {})
        price = cal.get(date)
        pos = position(cal, date, today)
        peers = by_stars.get(meta.get("stars"), [])
        rows.append({
            "hotel_identifier": h["hotel_identifier"],
            "title": h["title"],
            "stars": meta.get("stars"),
            "rating": meta.get("rating"),
            "votes": meta.get("votes"),
            "date": date,
            "price": price,
            "position": pos,
            "color": color(pos),
            "trend": trend(snaps, h["hotel_identifier"], date),
            "vs_peers_pct": round(100 * (price - statistics.median(peers)) / statistics.median(peers), 1)
                            if price and len(peers) >= 3 else None,
            "calendar_days": len(cal),
            "cheapest_nights": cheapest_nights(cal, today),
            "location": {k: v for k, v in locations.get(h["hotel_identifier"], {}).items()
                         if k not in ("hotel_identifier", "title")} or None,
        })
    order = {"green": 0, "neutral": 1, "red": 2, "unknown": 3}
    rows.sort(key=lambda r: (order[r["color"]], r["position"] if r["position"] is not None else 999))

    report = {"city": args.city, "generated": dt.date.today().isoformat(), "snapshots": len(snaps),
              "first_snapshot": snaps[0]["fetched"], "latest_snapshot": latest["fetched"],
              "currency": latest.get("currency", "USD"), "date": date, "hotels": rows}
    out = os.path.join(HERE, "data", slug(args.city), "report.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    dot = {"green": "G", "neutral": "-", "red": "R", "unknown": "?"}
    print(f"{args.city} - night of {date} - {len(snaps)} snapshot(s), {report['currency']}")
    print(f"{'':2}{'hotel':38}{'*':>2}{'price':>7}{'pos':>6}{'trend':>8}{'peers':>8}{'loc':>5}  cheapest nights (90d)")
    def pct(v, signed=False):
        if v is None:
            return "-"
        return f"{v:+.0f}%" if signed else f"{v}%"

    for r in rows:
        tr = r["trend"]["change_pct"] if r["trend"] else None
        deals = ", ".join(f"{d['date'][5:]} {d['price']}" for d in r["cheapest_nights"])
        price = "-" if r["price"] is None else str(r["price"])
        loc = str(r["location"]["score"]) if r["location"] else "-"
        print(f"{dot[r['color']]:2}{(r['title'] or '')[:37]:38}{str(r['stars'] or ''):>2}{price:>7}"
              f"{pct(r['position']):>6}{pct(tr, True):>8}{pct(r['vs_peers_pct'], True):>8}{loc:>5}  {deals}")
    for h in latest["hotels"]:
        if "error" in h:
            print(f"! {h['title']}: {h['error']}")
    print(f"Report -> {os.path.relpath(out)}")


if __name__ == "__main__":
    main()
