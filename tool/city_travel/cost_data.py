"""Real price data for the cost ratings (replaces model guesses).

    python tool/city_travel/cost_data.py Bangkok Tokyo ...      # fetch -> cost_data.json
    python tool/city_travel/cost_data.py --rate                  # ratings -> signature.json costs

Sources (fetched per city, cached in cost_data.json):
  BudgetYourTrip "Mid-Range" daily spend per traveler: accommodation, local transportation, food
  Numbeo (USD): inexpensive meal, mid-range meal for 2, one-way transit ticket, taxi start, taxi 1 km
Daily values used for rating (USD):
  stay      = BudgetYourTrip mid-range accommodation (per person, double occupancy)
  food      = average of BYT mid-range food/day and Numbeo (2 inexpensive meals + 1/2 mid-range meal for 2)
  transport = average of BYT mid-range local transport/day and Numbeo (4 transit rides + one 6 km taxi)
Ratings: each category is scaled against its own spread across popular destinations, so a typical
tourist city lands on $$$ in every category (thresholds = fixed USD bands below, set from the data).
"""
import json
import city_records
import re
import sys
import time
import unicodedata
from pathlib import Path

from curl_cffi import requests

HERE = Path(__file__).resolve().parent
OUT = HERE / "cost_data.json"
ROOT = HERE.parents[1]


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def text(url):
    r = requests.get(url, impersonate="chrome", timeout=40)
    if r.status_code != 200:
        return ""
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", r.text)).replace("&#36;", "$").replace("&nbsp;", " ")


def money(s):
    m = re.search(r"\$\s?([\d,]+(?:\.\d+)?)", s)
    return float(m.group(1).replace(",", "")) if m else None


def byt(city, country):
    names = {"New York City": "new-york", "Washington D.C.": "washington-dc", "Hong Kong": "hong-kong",
             "Singapore": "singapore", "Dubai": "dubai", "Abu Dhabi": "abu-dhabi"}
    path = names.get(city, slug(city))
    if "/" not in path and path not in ("singapore", "hong-kong"):
        path = f"{ {'Czechia': 'czech-republic'}.get(country, slug(country)) }/{path}"
    t = text(f"https://www.budgetyourtrip.com/{path}")
    m = re.search(r"Category Budget Mid-Range Luxury (.{0,900})", t)
    if not m:
        return None, path
    row = m.group(1)
    out = {}
    for key, label in (("stay", "Accommodation"), ("transport", "Local Transportation"), ("food", "Food")):
        seg = re.search(label + r"(.{0,140})", row)
        usd = re.findall(r"(?<![A-Z])\$ ?([\d,]+(?:\.\d+)?) \(", seg.group(1)) if seg else []
        if len(usd) >= 2:   # budget, mid-range, luxury -> mid-range (USD; the local-currency value follows in brackets)
            out[key] = float(usd[1].replace(",", ""))
    return out, path


def numbeo(city):
    q = {"New York City": "New-York", "Washington D.C.": "Washington", "Mexico City": "Mexico-City", "Abu Dhabi": "Abu-Dhabi",
         "Ho Chi Minh City": "Ho-Chi-Minh-City", "São Paulo": "Sao-Paulo", "Bogotá": "Bogota"}.get(city, city.replace(" ", "-"))
    t = text(f"https://www.numbeo.com/cost-of-living/in/{q}?displayCurrency=USD")
    out = {}
    for key, label in (("meal", "Meal at an Inexpensive Restaurant"), ("meal2", "Meal for Two"), ("ticket", "One-Way Ticket"),
                       ("taxi_start", "Taxi Start"), ("taxi_km", "Taxi 1 km")):
        i = t.find(label)
        if i >= 0:
            out[key] = money(t[i:i + 200])
    return out


def fetch(cities):
    data = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    recs = city_records.load_cities()
    for c in cities:
        b, path = byt(c, recs[c]["dimensions"]["country"])
        n = numbeo(c)
        data[c] = {"byt": b, "byt_path": path, "numbeo": n}
        print(f"{c}: byt {b} | numbeo {n}")
        time.sleep(1.5)
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def daily(d):
    b, n = d.get("byt") or {}, d.get("numbeo") or {}
    food_n = (2 * n["meal"] + n["meal2"] / 2) if n.get("meal") and n.get("meal2") else None
    tr_n = (4 * n["ticket"] + n["taxi_start"] + 6 * n["taxi_km"]) if all(n.get(k) for k in ("ticket", "taxi_start", "taxi_km")) else None
    avg = lambda *v: round(sum(x for x in v if x) / len([x for x in v if x]), 1) if any(v) else None
    return {"stay": b.get("stay"), "food": avg(b.get("food"), food_n), "transport": avg(b.get("transport"), tr_n)}


if __name__ == "__main__" and not sys.argv[1:2] in (["--rate"], ["--rate-write"]):
    sys.stdout.reconfigure(encoding="utf-8")
    if sys.argv[1:2] == ["--show"]:
        data = json.loads(OUT.read_text(encoding="utf-8"))
        for c, d in data.items():
            print(f"{c:15}", daily(d))
    else:
        fetch(sys.argv[1:])


# Centre of $$$ per category = a typical tourist destination (a bit below these big cities' median),
# so each category is judged against its own scale and no category is systematically lower.
REF = {"food": 55, "transport": 17, "stay": 85}
BANDS = [(0.45, 1), (0.75, 2), (1.3, 3), (1.8, 4)]
MANUAL = {("New York City", "stay"): 5}   # no BudgetYourTrip data; among the priciest hotel cities


def numbers(d):
    n, b = d.get("numbeo") or {}, d.get("byt") or {}
    food = 2 * n["meal"] + n["meal2"] / 2 if n.get("meal") and n.get("meal2") else b.get("food")
    tr = 4 * n["ticket"] + n["taxi_start"] + 6 * n["taxi_km"] if all(n.get(k) for k in ("ticket", "taxi_start", "taxi_km")) else b.get("transport")
    return {"food": food, "transport": tr, "stay": b.get("stay")}


def level(v, ref):
    r = v / ref
    return next((lv for cut, lv in BANDS if r < cut), 5)


def rate(write=False):
    data = json.loads(OUT.read_text(encoding="utf-8"))
    sig_p = HERE / "signature.json"
    sig = json.loads(sig_p.read_text(encoding="utf-8"))
    sums = {k: [] for k in REF}
    for c, d in data.items():
        num = numbers(d)
        lv = {}
        for k, ref in REF.items():
            lv[k] = MANUAL.get((c, k)) or (level(num[k], ref) if num[k] else None)
            if lv[k]:
                sums[k].append(lv[k])
        ex = {"food": f"About ${num['food']:.0f} a day for two cheap meals and one mid-range dinner" if num["food"] else "",
              "stay": f"Mid-range hotel about ${num['stay'] * 2:.0f} a night for two" if num["stay"] else "Among the priciest hotel cities",
              "transport": f"About ${num['transport']:.0f} a day: 4 transit rides and one 6 km taxi" if num["transport"] else ""}
        print(f"{c:14} food {lv['food']} ({num['food'] and round(num['food'])})  stay {lv['stay']} ({num['stay']})  transport {lv['transport']} ({num['transport'] and round(num['transport'])})")
        if write and all(lv.values()):
            sig.setdefault(c, {})["costs"] = {k: [lv[k], ex[k]] for k in ("food", "stay", "transport")}
    print("averages:", {k: round(sum(v) / len(v), 2) for k, v in sums.items()})
    if write:
        sig_p.write_text(json.dumps(sig, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__" and sys.argv[1:2] in (["--rate"], ["--rate-write"]):
    rate(sys.argv[1] == "--rate-write")
