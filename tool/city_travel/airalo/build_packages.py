"""Turn an Impact catalog export for Airalo into packages.json for the eSIM picker.

    python tool/city_travel/airalo/build_packages.py raw/airalo_catalog_2026-10-19.txt

Get the export from Impact: Discover > Products > search "Airalo eSIM" > My Brands >
Download (tab-separated). Each product's `Url` is already our tracking link
(airalo.pxf.io/c/7592796/...) that opens that exact package on airalo.com.

Impact caps a download at 5,000 rows and repeats products, so one export may not
hold every package; download again with a narrower filter (for example per region)
and pass several files to merge them. The newest row per SKU wins.
"""
import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
NAME = re.compile(r"^(Unlimited|[\d.]+) GB (.+?) travel eSIM valid for (\d+) days?(?: in (\d+) countries)?$")


def parse_date(s):
    try:
        return datetime.strptime(s.strip(), "%a %b %d %H:%M:%S %Z %Y")
    except ValueError:
        return datetime.min


def main(paths):
    best = {}
    for p in paths:
        path = Path(p) if Path(p).is_absolute() else HERE / p
        with open(path, encoding="utf-8-sig", errors="replace") as f:
            for r in csv.DictReader(f, delimiter="\t"):
                if r.get("Program Names") != "Airalo" or r.get("Stock Availability") != "InStock":
                    continue
                m = NAME.match(r["Name"].strip())
                if not m:
                    continue
                when = parse_date(r["Last Updated"])
                if r["Sku"] in best and best[r["Sku"]][0] >= when:
                    continue
                gb, place, days, n_countries = m.groups()
                best[r["Sku"]] = (when, {
                    "sku": r["Sku"],
                    "place": place,
                    "region_of": int(n_countries) if n_countries else None,
                    "gb": None if gb == "Unlimited" else float(gb),
                    "days": int(days),
                    "price": float(r["Current Price"]),
                    "currency": r["Currency"],
                    "url": r["Url"],
                    "updated": when.strftime("%Y-%m-%d"),
                })

    places = {}
    for _, pkg in best.values():
        key = pkg.pop("place")
        places.setdefault(key, []).append(pkg)
    for pkgs in places.values():
        # one row per (data, days): keep the cheapest if a product is listed twice
        uniq = {}
        for p in pkgs:
            k = (p["gb"], p["days"])
            if k not in uniq or p["price"] < uniq[k]["price"]:
                uniq[k] = p
        pkgs[:] = sorted(uniq.values(), key=lambda p: (p["days"], p["gb"] if p["gb"] is not None else 1e9))

    countries = {k: v for k, v in places.items() if not any(p["region_of"] for p in v)}
    regions = {k: v for k, v in places.items() if any(p["region_of"] for p in v)}
    dates = [w for w, _ in best.values() if w != datetime.min]
    out = {
        "source": "Impact product catalog (Airalo)",
        "prices_as_of": max(dates).strftime("%Y-%m-%d") if dates else None,
        "oldest_price": min(dates).strftime("%Y-%m-%d") if dates else None,
        "packages": len(best),
        "countries": dict(sorted(countries.items())),
        "regions": dict(sorted(regions.items())),
    }
    (HERE / "packages.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    # a script copy so the picker also works when opened straight from disk
    (HERE / "packages.js").write_text("window.AIRALO_PACKAGES = " + json.dumps(out, ensure_ascii=False) + ";\n", encoding="utf-8")
    print(f"{len(best)} packages · {len(countries)} countries · {len(regions)} regions · prices {out['oldest_price']}…{out['prices_as_of']}")


if __name__ == "__main__":
    main(sys.argv[1:] or ["raw/airalo_catalog_2026-10-19.txt"])
