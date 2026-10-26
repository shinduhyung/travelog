"""facts/<slug>.json for a new city without Claude doing the research by hand.

    python tool/city_travel/deepseek_facts.py Lisbon Rome ...

Sources fetched by the script (free): Wikivoyage "Get in" / "Get around" text, the app's hub airports
(assets/top_city_hub_airport.json + airports.json), Open-Meteo monthly climate, the FX file.
DeepSeek turns them into the facts shape (airports with transfer options, taxi tariff, transit facts,
hotel areas, traveler types, intro). Picks from deepseek_prep (signature, tours) feed place_landmarks.
Checks: every airport option needs price + time; the taxi tariff must give an airport fare within
0.5x-2x of the airport taxi option; train/bus must not cost more than the taxi. Problems are listed in
facts/<slug>.json "problems" for Claude to look at — the only part Claude reviews by hand.
"""
import json
import math
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import climate_fetch
import deepseek_city as ds
import deepseek_prep as prep

HERE, ASSETS = ds.HERE, ds.ROOT / "assets"
UA = {"User-Agent": "TravelogTripPrep/1.0 (+https://travelogapp.uk)"}

SYSTEM = ("You write checked travel facts as JSON for a trip-prep page. Reply with one JSON object only. Use the "
          "Wikivoyage text as your main source; where it is silent use well-known facts, and give ranges, not exact "
          "numbers, when unsure. Prices in the local currency with its symbol. English, short sentences.")

PROMPT = """City: {city}, {country}. Local currency code: {currency}. City centre: {center}.
Hub airports (code, name, straight-line km to centre): {airports}

WIKIVOYAGE "GET IN" / "GET AROUND" (may be dated; prefer recent-looking prices):
{wv}

Return JSON:
{{
 "intro_line": "<one evocative line about the city, max 12 words>",
 "intro": "<two sentences: how the city rewards visitors + 'Pick how long you have and what you enjoy most.'>",
 "types": [5 objects {{"id": "<one of culture|food|nature|beach|nightlife|shopping|family|romance|budget|adventure|history|art>", "label": "<one word>"}}],
 "areas": ["<4 best hotel areas / neighbourhoods for visitors, short names>"],
 "taxi": {{"flag_day": <number>, "flag_airport": <number>, "per_km": <number>, "min_fare": <number>}},
 "road_factor": <1.2-1.5 road km per straight km>, "city_kmh": <average taxi speed in town, 12-35>,
 "transit_facts": ["<5-6 lines: metro/tram, buses, taxis + which ride apps work, driving, walking/bikes, any ferry>"],
 "airports": [{{"code": "<IATA>", "name": "<airport name>", "primary": true/false, "note": "<one line: role + distance>",
   "options": [{{"mode": "<e.g. Metro line 7 / Airport bus / Taxi / Uber / Train>", "to": "<where in the city>",
                "price": "<e.g. €2 or €15-20>", "time": "<e.g. 25-35 min>", "note": "<one short tip>"}}]}}],
 "max_km": <how far day trips reach, 30-80>
}}
Rules: 3-5 options per airport, cheapest public option first, always include taxi and (if they operate) ride apps.
Include the listed hub airports plus any other airport with regular international flights that serves the city (max 3 airports). If an option's price or time is unknown write "check locally"."""


def km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (*a, *b))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def wikivoyage(city, country):
    for title in (city, f"{city} ({country})", city.replace(" City", "")):
        url = "https://en.wikivoyage.org/w/index.php?" + urllib.parse.urlencode({"title": title, "action": "raw", "redirect": "yes"})
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                txt = r.read().decode("utf-8")
        except Exception:
            continue
        m = re.match(r"#REDIRECT\s*\[\[([^\]]+)\]\]", txt, re.I)
        if m:
            return wikivoyage(m.group(1), country)
        parts = re.split(r"\n==\s*([^=]+?)\s*==\n", txt)
        keep = [f"== {parts[i]} ==\n{parts[i + 1]}" for i in range(1, len(parts) - 1, 2)
                if parts[i].strip().lower() in ("get in", "get around")]
        if keep:
            text = re.sub(r"\{\{(?:listing|do|see|go)[^}]*\}\}", "", "\n".join(keep))
            return text[:14000]
    return ""


def first_number(s):
    m = re.search(r"(\d[\d,]*(?:\.\d+)?)", (s or "").replace(" ", ""))
    return float(m.group(1).replace(",", "")) if m else None


def check(f, dist):
    problems = []
    t = f.get("taxi", {})
    for ap in f.get("airports", []):
        d = dist.get(ap.get("code"))
        opts = ap.get("options", [])
        taxi = next((o for o in opts if "taxi" in o.get("mode", "").lower()), None)
        for o in opts:
            if not o.get("price") or not o.get("time"):
                problems.append(f"{ap['code']} {o.get('mode')}: missing price/time")
        if taxi and d and t.get("per_km"):
            est = t.get("flag_airport", 0) + t["per_km"] * d * f.get("road_factor", 1.3)
            got = first_number(taxi["price"])
            if got and not 0.5 * est <= got <= 2 * est:
                problems.append(f"{ap['code']} taxi {taxi['price']} vs tariff estimate {est:.0f}")
            for o in opts:
                p = first_number(o.get("price"))
                if got and p and o is not taxi and re.search(r"bus|train|metro|rail|tram|express", o.get("mode", ""), re.I) and p > got:
                    problems.append(f"{ap['code']} {o['mode']} {o['price']} costs more than taxi {taxi['price']}")
        if d is None:
            problems.append(f"airport {ap.get('code')} unknown code")
        elif d > 120:
            problems.append(f"airport {ap.get('code')} is {d} km away")
    return problems


def build(city):
    rec, lms, rank, _ = prep.inputs(city)
    country = rec["dimensions"]["country"]
    center = (rec["values"]["latitude"], rec["values"]["longitude"])
    hubs = next((h["iata"] for h in json.loads((ASSETS / "top_city_hub_airport.json").read_text(encoding="utf-8")) if h["name"] == city), [])
    all_aps = {v["iata"]: v for v in json.loads((ASSETS / "airports.json").read_text(encoding="utf-8")).values() if v.get("iata")}
    aps = {c: all_aps[c] for c in hubs if c in all_aps}
    dist = {c: round(km(center, (float(a["lat"]), float(a["lon"])))) for c, a in all_aps.items() if a.get("lat") is not None}
    cur = currency_of(rec["dimensions"]["country_iso"])
    fx = json.loads((HERE / "fx_rates.json").read_text(encoding="utf-8"))["rates"]
    wv = wikivoyage(city, country)
    out = ds.ask(SYSTEM, PROMPT.format(city=city, country=country, currency=cur, center=center,
                                       airports="; ".join(f"{c} {aps[c].get('name')} {dist.get(c)} km" for c in aps),
                                       wv=wv or "(no Wikivoyage text found)"), max_tokens=5000)
    pd = json.loads((ds.DRAFTS / f"{ds.slug(city)}.prep.json").read_text(encoding="utf-8"))
    names = [s["name"] for s in pd["signature"]]
    for n in rank + [l["name"] for l in lms]:   # signature first, then the app's ranking, then global rank
        if len(names) >= 22:
            break
        if n not in names and any(l["name"] == n for l in lms) and "Restaurant" not in str(next(l for l in lms if l["name"] == n).get("attributes")):
            names.append(n)
    f = {"currency": cur, "usd_rate": round(fx.get(cur, 1), 4), **{k: out.get(k) for k in
         ("intro_line", "intro", "types", "areas", "taxi", "road_factor", "city_kmh", "transit_facts", "airports", "max_km")},
         "place_landmarks": names, "airports_sources": [["Wikivoyage: " + city, f"https://en.wikivoyage.org/wiki/{urllib.parse.quote(city)}"]] if wv else [],
         "checked": "October 2026", "center": list(center),
         "climate_source": "Open-Meteo historical weather, 2015-2024 averages (rain days = days with 1 mm or more)",
         "climate_months": climate_fetch.monthly(*center),
         "tours": [{"title": t["title"], "price": t["price"], "landmarks": t["landmarks"], "covers": []} for t in pd["tours"]]}
    f["problems"] = check(f, dist) + ([] if wv else ["no Wikivoyage text: airport facts are from the model alone"])
    (HERE / "facts" / f"{ds.slug(city)}.json").write_text(json.dumps(f, ensure_ascii=False, indent=2), encoding="utf-8")
    return city, f["problems"]


def currency_of(iso2):
    # ISO 4217 by country (enough for the app's cities); euro countries collapsed.
    euro = "AT BE CY DE EE ES FI FR GR HR IE IT LT LU LV MT NL PT SI SK".split()
    if iso2 in euro:
        return "EUR"
    table = dict(x.split(":") for x in (
        "AE:AED GB:GBP JP:JPY US:USD TH:THB AU:AUD CA:CAD CH:CHF CN:CNY HK:HKD SG:SGD TW:TWD NZ:NZD IN:INR VN:VND "
        "ID:IDR MY:MYR PH:PHP SA:SAR QA:QAR TR:TRY IL:ILS EG:EGP ZA:ZAR MA:MAD BR:BRL MX:MXN AR:ARS CL:CLP CO:COP "
        "PE:PEN SE:SEK NO:NOK DK:DKK IS:ISK PL:PLN CZ:CZK HU:HUF RO:RON RU:RUB UA:UAH KZ:KZT PK:PKR BD:BDT LK:LKR "
        "NP:NPR MN:MNT KH:KHR LA:LAK MO:MOP JO:JOD KW:KWD BH:BHD OM:OMR KE:KES NG:NGN TZ:TZS GE:GEL AM:AMD AZ:AZN "
        "UZ:UZS KR:KRW RS:RSD AL:ALL BG:BGN LB:LBP TN:TND UG:UGX GH:GHS MU:MUR UY:UYU EC:USD PA:PAB GT:GTQ HN:HNL "
        "NI:NIO SV:USD DO:DOP CR:CRC VE:VES BO:BOB PY:PYG KY:KYD BN:BND MV:MVR").split())
    return table.get(iso2, "USD")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    with ThreadPoolExecutor(6) as pool:
        for city, problems in pool.map(build, sys.argv[1:]):
            print(f"{city}: {len(problems)} problems" + ("".join(f"\n  - {p}" for p in problems)))
