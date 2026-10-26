"""DeepSeek first drafts of the city-level picks that Claude used to write by hand, so Claude only
reviews a short summary instead of researching from scratch.

    python tool/city_travel/deepseek_prep.py Lisbon Rome ...     # draft
    python tool/city_travel/deepseek_prep.py --summary Lisbon     # compact review text for Claude
    python tool/city_travel/deepseek_prep.py --apply Lisbon       # write the reviewed draft into
                                                                  # signature.json + city_tour_links.json

Inputs: the city's landmarks (landmarks.collect), cities.json (country, isCapital), city_rank.json
(the app's top landmarks), gyg/<slug>.json (GetYourGuide harvest, most-reviewed first).
Draft (drafts/<slug>.prep.json):
  status     capital / largest / largest_city
  signature  1-10 must-see landmarks (names from the given list only) with a 2-3 sentence detail
  costs      food / stay / transport levels 1-5 with a one-line example in US dollars
  tours      3-6 GetYourGuide picks from the harvest, each linked to landmark names from the list
  missing    must-see sights that are NOT in the landmark list (Claude decides whether to add them)
Every name and URL is checked against the inputs; anything invented is dropped and reported.
"""
import json
import city_records
import re
import sys
from concurrent.futures import ThreadPoolExecutor

import deepseek_city as ds
import landmarks as lmk

HERE = ds.HERE
ASSETS = ds.ROOT / "assets"
PARTNER = "partner_id=EMZVISH&utm_medium=online_publisher"

SYSTEM = ("You are a careful travel editor. Reply with one JSON object only. Use only names and URLs "
          "given in the input; never invent landmarks, tours, prices or facts. Write in plain English.")

PROMPT = """City: {city}, {country}. Officially the national capital: {capital}.
App's top landmarks for this city (most famous first): {rank}

LANDMARKS (the only names you may use, exactly as written; attribute in brackets):
{landmarks}

GETYOURGUIDE TOURS (most reviewed first; i = index):
{tours}

Return JSON:
{{
 "status": {{"capital": true/false, "largest": true/false, "largest_city": "<the country's largest city if not this one, else null>"}},
 "signature": [{{"name": "<exact landmark name>", "detail": "<2-3 sentences: why it is a must-see, plus one practical tip (best time, tickets, dress code, how to get there)>"}}],
 "costs": {{"food": [1-5, "<one line in US dollars, e.g. 'Casual meal $8-15'>"], "stay": [1-5, "<e.g. 'Good 3-4* hotel $90-150 a night'>"], "transport": [1-5, "<e.g. 'Metro $1 a ride; taxis cheap'>"]}},
 "tours": [{{"i": <index>, "landmarks": ["<exact landmark names this tour visits>"], "badges": ["<2 short tags, e.g. 'Entry included', 'Hotel pickup'>"], "highlights": ["<2 short lines on what you see or do>"]}}],
 "missing": ["<must-see sights of this city that are NOT in the landmark list, max 5, only truly famous ones>"]
}}
Rules:
- signature: 1 to 10 landmarks, most iconic first. Scale with the city: a world city like London or Rome has 8-10,
  a city with one famous sight has 1-2. Only places a first-time visitor travels for; no restaurants, shops, festivals,
  films or stadiums unless they are the city's icon.
- costs levels: 1 very cheap (Bangkok street food), 3 moderate, 5 very expensive (London/NYC/Zurich hotels). Be realistic for 2026.
- tours: pick 3-6 tours a real visitor would book: high rating (4.5+), many reviews, varied (no two of the same thing),
  preferring ones that visit the signature landmarks. Each tour must list at least one landmark name it actually visits.
  Skip airport transfers, lounges, SIM cards and passes.
- largest: compare with every city of the country (city proper or metro, the usual reference answer)."""


def inputs(city):
    cities = city_records.load_cities()
    rec = cities[city]
    all_lm = json.loads((ASSETS / "all_landmarks.json").read_text(encoding="utf-8"))
    center = (rec["values"].get("latitude"), rec["values"].get("longitude"))
    lms = lmk.collect(city, center if None not in center else None, all_lm, set(cities))
    rank = json.loads((ASSETS / "city_rank.json").read_text(encoding="utf-8")).get(city, [])
    gyg_file = HERE / "gyg" / f"{re.sub(r'[^a-z0-9-]+', '-', city.lower()).strip('-')}.json"
    gyg = json.loads(gyg_file.read_text(encoding="utf-8"))["tours"] if gyg_file.exists() else []
    return rec, lms, rank, gyg


def draft(city):
    rec, lms, rank, gyg = inputs(city)
    lm_lines = "\n".join(f"- {l['name']} [{(l.get('attributes') or [''])[0]}]" for l in lms[:150])
    tour_lines = "\n".join(f"{i}. {t['t']} | {t['r']} ({t['n']:,} reviews) | from ${t['p']} | {t['a']}" for i, t in enumerate(gyg)) or "(none)"
    out = ds.ask(SYSTEM, PROMPT.format(city=city, country=rec["dimensions"]["country"], capital=bool(rec["values"].get("isCapital")),
                                       rank=", ".join(rank) or "(none)", landmarks=lm_lines, tours=tour_lines), max_tokens=4000)
    names = {l["name"] for l in lms}
    problems = []
    sig = [s for s in out.get("signature", []) if s.get("name") in names]
    problems += [f"signature not in list: {s.get('name')}" for s in out.get("signature", []) if s.get("name") not in names]
    tours, extra = [], []
    for t in out.get("tours", []):
        if not isinstance(t.get("i"), int) or not 0 <= t["i"] < len(gyg):
            problems.append(f"bad tour index {t.get('i')}")
            continue
        g = gyg[t["i"]]
        lmn = [n for n in t.get("landmarks", []) if n in names]
        problems += [f"tour landmark not in list: {n}" for n in t.get("landmarks", []) if n not in names]
        rec_t = {"title": g["t"], "provider": "GetYourGuide",
                 "url": f"https://www.getyourguide.com{g['u']}?{PARTNER}", "rating": g["r"], "reviewCount": g["n"],
                 "price": f"${g['p']}", "badges": t.get("badges", [])[:2],
                 "highlights": t.get("highlights", [])[:2] + [f"{g['n']:,} reviews · {g['r']} rating"], "landmarks": lmn}
        if not lmn:  # day trips beyond the city's landmarks (Great Ocean Road, Masada): kept only to fill up to 4
            extra.append(rec_t)
            continue
        tours.append({"title": g["t"], "provider": "GetYourGuide",
                      "url": f"https://www.getyourguide.com{g['u']}?{PARTNER}", "rating": g["r"], "reviewCount": g["n"],
                      "price": f"${g['p']}", "badges": t.get("badges", [])[:2],
                      "highlights": t.get("highlights", [])[:2] + [f"{g['n']:,} reviews · {g['r']} rating"], "landmarks": lmn})
    tours += extra[:max(0, 4 - len(tours))]
    costs = out.get("costs", {})
    for k in ("food", "stay", "transport"):
        v = costs.get(k)
        if not (isinstance(v, list) and len(v) == 2 and isinstance(v[0], int) and 1 <= v[0] <= 5):
            problems.append(f"bad cost {k}: {v}")
    res = {"city": city, "status": out.get("status"), "signature": sig[:10], "costs": costs, "tours": tours,
           "missing": out.get("missing", [])[:5], "problems": problems, "n_landmarks": len(lms), "n_gyg": len(gyg)}
    (ds.DRAFTS / f"{ds.slug(city)}.prep.json").write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    return res


def summary(city):
    d = json.loads((ds.DRAFTS / f"{ds.slug(city)}.prep.json").read_text(encoding="utf-8"))
    st = d["status"] or {}
    c = d["costs"]
    lines = [f"## {city}  ({d['n_landmarks']} lm, {d['n_gyg']} gyg)",
             f"status: capital={st.get('capital')} largest={st.get('largest')} {st.get('largest_city') or ''}",
             "costs: " + " | ".join(f"{k} {v[0]} {v[1]}" for k, v in c.items() if isinstance(v, list)),
             "sig: " + "; ".join(s["name"] for s in d["signature"]),
             "tours: " + "; ".join(f"{t['title'][:60]} ({t['rating']}, {t['reviewCount']:,}) -> {', '.join(t['landmarks'])}" for t in d["tours"]),
             "missing: " + ", ".join(d["missing"])]
    if d["problems"]:
        lines.append("problems: " + "; ".join(d["problems"]))
    return "\n".join(lines)


def apply(city):
    d = json.loads((ds.DRAFTS / f"{ds.slug(city)}.prep.json").read_text(encoding="utf-8"))
    sp = HERE / "signature.json"
    sig = json.loads(sp.read_text(encoding="utf-8"))
    st = d["status"]
    sig[city] = {"status": {k: v for k, v in st.items() if v is not None}, "signature": d["signature"], "costs": d["costs"]}
    sp.write_text(json.dumps(sig, ensure_ascii=False, indent=2), encoding="utf-8")
    tp = ASSETS / "city_tour_links.json"
    tl = json.loads(tp.read_text(encoding="utf-8"))
    tl = [e for e in tl if e["city"] != city] + [{"city": city, "tours": d["tours"]}]
    tp.write_text(json.dumps(tl, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"applied {city}: {len(d['signature'])} signature, {len(d['tours'])} tours")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if args and args[0] == "--summary":
        print("\n\n".join(summary(c) for c in args[1:]))
    elif args and args[0] == "--apply":
        for c in args[1:]:
            apply(c)
    else:
        with ThreadPoolExecutor(6) as pool:
            for r in pool.map(draft, args):
                print(f"{r['city']}: {len(r['signature'])} sig, {len(r['tours'])} tours, {len(r['problems'])} problems")
