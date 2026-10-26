"""Trip planner + hotel list sections for build_page.py.

Inputs (all optional except the planner file; a missing one just drops that part):
  planner/<slug>.json                          traveler types, place metadata, monthly climate (researched)
  itineraries/<slug>.json                      places with hours / prices / coordinates, taxi fares
  ../hotel_prices/data/<city>/report.json      hotel price signals (analyze_prices.py)
  ../hotel_prices/data/<city>/<date>.json      latest price calendars (fetch_prices.py)

Everything is embedded as one JSON blob; the page renders it in the browser. "Run AI" asks
Claude through the artifact `sample` capability (publish with capabilities {"sample": {}}),
so it only works when the page is opened on claude.ai; elsewhere the button explains that.
"""
import glob
import json
import statistics
import urllib.parse
from datetime import date, datetime, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
PRICES = HERE.parent / "hotel_prices"

# Same affiliate values as lib/widgets/city_travel_modal.dart.
HOTELS_COM = ("www.hotels.com", "1011l6uqXc", "1011l66481")
VRBO = ("vrbo.com", "1011l6uqXe", "1101l63118")


def affiliate(brand, landing):
    host, camref, creativeref = brand
    return (f"https://{host}/affiliate?landingPage={urllib.parse.quote(landing, safe='')}"
            f"&camref={camref}&creativeref={creativeref}")


def hotels_com_search(query):
    return affiliate(HOTELS_COM, "https://www.hotels.com/Hotel-Search?destination=" + urllib.parse.quote(query))


def vrbo_search(query):
    return affiliate(VRBO, "https://www.vrbo.com/search?destination=" + urllib.parse.quote(query))


def _read(path):
    return json.loads(Path(path).read_text(encoding="utf-8")) if Path(path).exists() else None


BADGES = {"DEAL", "GREAT DEAL", "GREAT PRICE", "LOW PRICE", "SPONSORED"}


def live_hotels(city):
    """Fallback without DataForSEO: one night's Google Hotels list prices read from the page
    (../hotel_prices/live/<slug>.json, hotel_harvest.js), converted to USD with fx_rates.json."""
    import re
    d = _read(PRICES / "live" / (re.sub(r"[^a-z0-9-]+", "-", city.lower()).strip("-") + ".json"))
    if not d or not d.get("hotels"):
        return None
    rates = (_read(HERE / "fx_rates.json") or {}).get("rates", {})
    sym = {"₩": "KRW", "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY"}
    fetched = date.fromisoformat(d["fetched"])
    checkin = None
    try:  # "Sun, Nov 1" -> the next such date on or after the fetch day
        m = datetime.strptime(d["checkin"].split(", ", 1)[1] + f" {fetched.year}", "%b %d %Y").date()
        checkin = (m if m >= fetched else m.replace(year=fetched.year + 1)).isoformat()
    except (ValueError, IndexError, KeyError):
        pass
    hotels = []
    for h in d["hotels"]:
        rate = rates.get(sym.get(h["cur"], h["cur"]))
        if not rate or h["h"].upper() in BADGES:  # a deal badge read in place of the name: the name is lost
            continue
        hotels.append({"id": h["h"], "name": h["h"], "stars": h.get("star"), "rating": h.get("r"), "votes": h.get("n"),
                       "area": None, "loc": None, "sights": [], "url": hotels_com_search(f"{h['h']}, {city}"),
                       "prices": [], "price": round(h["p"] / rate)})
    return {"single": True, "checkin": checkin, "start": checkin or d["fetched"], "fetched": d["fetched"],
            "currency": "USD", "adults": 2, "hotels": hotels, "index": []} if hotels else None


def hotel_data(city):
    """Report rows + compact price calendars + a city-wide daily price index, or None."""
    folder = PRICES / "data" / city.lower().replace(" ", "_")
    report = _read(folder / "report.json")
    snaps = sorted(glob.glob(str(folder / "????-??-??.json")))
    if not report or not snaps:
        return live_hotels(city)
    latest = _read(snaps[-1])
    start = date.fromisoformat(latest["fetched"])
    days = 335
    cal = {h["hotel_identifier"]: h.get("prices_by_dates", {}) for h in latest["hotels"] if "error" not in h}

    def series(c):
        return [c.get((start + timedelta(i)).isoformat()) for i in range(days)]

    hotels = []
    for r in report["hotels"]:
        loc = r.get("location") or {}
        hotels.append({
            "id": r["hotel_identifier"], "name": r["title"], "stars": r["stars"], "rating": r["rating"],
            "votes": r["votes"], "area": loc.get("area"), "loc": loc.get("score"),
            "sights": [f"{s['name']} {s['km']} km" for s in loc.get("nearest_sights", [])[:2]],
            "url": hotels_com_search(f"{r['title']}, {city}"),
            "prices": series(cal.get(r["hotel_identifier"], {})),
        })

    # Daily index: median over hotels of (that night's price / the hotel's own median). 1.0 = typical.
    medians = {h["id"]: statistics.median([p for p in h["prices"] if p]) for h in hotels if any(h["prices"])}
    index = []
    for i in range(days):
        ratios = [h["prices"][i] / medians[h["id"]] for h in hotels if h["id"] in medians and h["prices"][i]]
        index.append(round(statistics.median(ratios), 3) if len(ratios) >= 5 else None)
    return {"start": start.isoformat(), "fetched": latest["fetched"], "currency": latest.get("currency", "USD"),
            "adults": latest.get("adults", 2), "hotels": hotels, "index": index}


def build(city, slug, tours):
    """Return (planner_html, stays_html, css, js); empty strings when there is no planner file."""
    plan = _read(HERE / "planner" / f"{slug}.json")
    if not plan:
        return "", "", "", ""
    itin = _read(HERE / "itineraries" / f"{slug}.json") or {}
    src_places = itin.get("places", {})
    places = []
    for pid, meta in plan["places"].items():
        p = src_places.get(pid)
        if not p:
            continue
        places.append({"id": pid, "name": p["name"], "kind": p.get("kind"), "lat": p.get("lat"), "lon": p.get("lon"),
                       "price": p.get("price"), "price_text": p.get("price_text", ""), "hours": p.get("hours", ""),
                       "tip": p.get("tip", ""), **meta})

    # Which places the curated tour covers (from the hand-made plans).
    covers = sorted({c for pl in itin.get("plans", []) for d in pl["days"] for s in d["stops"]
                     if s.get("tour") == 0 for c in s.get("covers", [])})
    tour_list = [{"title": t["title"], "url": t["url"], "price": t.get("price"), "duration": t.get("duration"),
                  "covers": covers if i == 0 else []} for i, t in enumerate(tours)]

    data = {
        "city": city, "types": plan["types"], "fit": plan["type_month_fit"], "climate": plan["climate"],
        "note": plan.get("note", ""), "places": places, "tours": tour_list,
        "taxi": itin.get("transport", {}).get("taxi"), "road_factor": itin.get("transport", {}).get("road_factor", 1.25),
        "stays": itin.get("stays", []), "hotels": hotel_data(city),
        "currency": itin.get("currency", "AED"),
        "airport": next((a["code"] for a in plan.get("airports", []) if a.get("primary")), ""),
    }
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")

    # The "My dates" panel of Trip plans: same job as the ready-made plans, built around the traveler's
    # real arrival/departure times. itinerary.Renderer shows it when the "My dates" tab is picked.
    planner_html = f"""
  <div class="custom">
    <div class="step"><span class="pl-num">1</span><h3>When are you there?</h3></div>
    <div class="when">
      <div class="dtf"><span class="dtl">Arrive</span><span class="dt" data-for="pl-arrive"></span><input type="hidden" id="pl-arrive"></div>
      <div class="dtf"><span class="dtl">Leave</span><span class="dt" data-for="pl-depart"></span><input type="hidden" id="pl-depart"></div>
      <label>Pace <select id="pl-pace"><option value="relaxed">Relaxed</option><option value="standard" selected>Standard</option><option value="packed">Packed</option></select></label>
    </div>
    <div id="pl-season"></div>
    <div class="step"><span class="pl-num">2</span><h3>What kind of trip?</h3></div>
    <div class="chips" id="pl-types" role="group" aria-label="Traveler type"></div>
    <details class="pl-box"><summary><b>Places to include</b> <span class="muted" id="pl-count"></span> <span class="muted">· tap to edit</span></summary>
      <div class="places" id="pl-places"></div></details>
    <details class="pl-box"><summary><b>Best months for your style</b> <span class="muted">· weather and hotel prices</span></summary>
      <div class="months" id="pl-months"></div><p class="muted fine" id="pl-months-note"></p></details>
    <div class="step"><span class="pl-num">3</span><h3>Build my plan</h3></div>
    <div class="run"><button type="button" class="btn" id="pl-run">Run AI</button>
      <button type="button" class="btn ghost" id="pl-stop" hidden>Stop</button>
      <span class="muted" id="pl-status"></span></div>
    <div id="pl-result"></div>
    <script type="application/json" id="planner-data">{blob}</script>
  </div>"""

    n_hotels = len((data["hotels"] or {}).get("hotels", []))
    stays_html = f"""
  <a class="row-card" href="{hotels_com_search(city)}" target="_blank" rel="noopener sponsored">
    <span class="row-text"><b>Search all {city} hotels</b><span>Hotels.com</span></span><span class="go" aria-hidden="true">→</span></a>
  <div class="hotels-head"><h3>Popular hotels</h3><span class="muted fine" id="ht-sub"></span></div>
  <div id="ht-all" hidden>
    <div class="chips small" id="ht-filter" role="group" aria-label="Filter hotels">
      <button type="button" data-f="all" aria-pressed="true">All</button>
      <button type="button" data-f="good" aria-pressed="false">Good price</button>
    </div>
  </div>
  <div class="hotels" id="ht-list"></div>
  <div class="ht-more-wrap"><button type="button" class="btn ghost" id="ht-more" aria-expanded="false" data-n="{n_hotels}">See all {n_hotels} hotels</button></div>
  <p class="muted fine" id="ht-note"></p>"""
    return planner_html, stays_html, CSS, JS


def arrival(city, slug):
    """'Getting in' block: each airport's ways to the hotel areas with price and time, then the
    recommended trip length and themes. Empty string when the planner file has no airports."""
    import html as _h
    e = _h.escape
    plan = _read(HERE / "planner" / f"{slug}.json") or {}
    itin = _read(HERE / "itineraries" / f"{slug}.json") or {}
    airports = plan.get("airports") or []
    if not airports:
        return ""
    cards = []
    for ap in airports:
        rows = "".join(f'<tr><td><b>{e(o["mode"])}</b><small>{e(o["to"])}</small></td><td class="v">{e(o["price"])}</td>'
                       f'<td class="v">{e(o["time"])}</td></tr>'
                       + (f'<tr class="note"><td colspan="3">{e(o["note"])}</td></tr>' if o.get("note") else "")
                       for o in ap["options"])
        cards.append(f"""<details class="airport"{' open' if ap.get('primary') else ''}>
      <summary><span class="code">{e(ap['code'])}</span><span><b>{e(ap['name'])}</b><small>{e(ap.get('note', ''))}</small></span></summary>
      <table><thead><tr><th>How</th><th>Cost</th><th>Time</th></tr></thead><tbody>{rows}</tbody></table></details>""")
    rec = next((x for x in itin.get("lengths", []) if x.get("recommended")), None)
    rec_txt = ""
    if rec:
        n = int(rec["id"][:-1]) if rec["id"].endswith("n") and rec["id"][:-1].isdigit() else 0
        rec_txt = "Day trip" if rec["id"] == "day" else f"{n} night{'s' if n > 1 else ''} ({n + 1} days)"
    short = {t["id"]: t["label"] for t in plan.get("types", [])}
    # "Best for" is what the city is objectively strong at (planner file's best_for), not every style we plan.
    best = plan.get("best_for") or [st["id"] for st in itin.get("styles", [])]
    themes = "".join(f'<li><b>{e(short.get(st["id"], st["label"]))}</b><span>{e(st.get("blurb", ""))}</span></li>'
                     for st in itin.get("styles", []) if st["id"] in best)
    why = (plan.get("recommend") or {}).get("why", "")
    # Monthly weather (current month highlighted in the browser) + traveler-focused climate guide.
    weather_html = ""
    months = (plan.get("climate") or {}).get("months") or []
    if len(months) == 12:
        rain = lambda m: f" · 🌧 {m['rain_days']}d" if m.get("rain_days") else ""
        names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        top = max(m["high"] for m in months)
        cols = "".join(
            f'<div class="wm" data-m="{i}" title="{e(m.get("note", ""))}"><span class="wh">{m["high"]}°</span>'
            f'<span class="wbar"><i style="height:{round(100 * m["high"] / top)}%"></i></span>'
            f'<span class="wl">{m["low"]}°</span><b>{names[i]}</b>'
            f'<small>{("🌊 " + str(m["sea"]) + "°") if m.get("sea") is not None else ""}{rain(m) if m.get("sea") is not None else rain(m).replace(" · ", "", 1)}</small></div>'
            for i, m in enumerate(months))
        guide = plan.get("climate_guide") or {}
        guide_cards = "".join(f'<li><span class="wi" aria-hidden="true">{e(g["icon"])}</span><span><b>{e(g["title"])}</b><small>{e(g["text"])}</small></span></li>'
                        for g in guide.get("items", []))
        weather_html = f"""<div class="weather">
      <h3>Weather by month</h3><p class="muted fine" id="w-now"></p>
      <div class="wgrid">{cols}</div>
      <p class="muted fine">Average daily high / low (°C), sea temperature and rainy days. Typical figures, not a forecast.</p>
    </div>
    <div class="climate"><h3>Climate</h3><p>{e(guide.get("summary", ""))}</p><ul>{guide_cards}</ul></div>
    <script>(() => {{ const m = new Date().getMonth(), el = document.querySelector('.wm[data-m="' + m + '"]');
      if (el) {{ el.classList.add('now'); const n = document.getElementById('w-now');
        n.textContent = 'This month: ' + el.querySelector('b').textContent + ' · ' + el.title; }} }})();</script>"""
    tr = plan.get("transit") or {}
    transit_html = ""
    if tr.get("modes"):
        items = "".join(f'<li class="{"yes" if m.get("has") else "no"}"><span class="mk" aria-hidden="true">{"✓" if m.get("has") else "✗"}</span>'
                        f'<span><b>{e(m["mode"])}{' <span class="tr-best" title="Best way">★</span>' if m.get("best") else ""}</b><small>{e(m["text"])}</small></span></li>'
                        for m in tr["modes"])
        best_way = f'<p>{e(tr["best"])}</p>' if tr.get("best") else ""
        transit_html = f'<div class="transit"><h3>Getting around</h3>{best_way}<ul>{items}</ul></div>'
    srcs = " · ".join(f'<a href="{e(u)}" target="_blank" rel="noopener">{e(n)}</a>' for n, u in plan.get("airports_sources", []))
    return f"""
  <section aria-labelledby="h-arrive" class="arrive">
    <h2 id="h-arrive">Getting in</h2>
    {''.join(cards)}
    <p class="muted fine">Estimates, checked {e(plan.get('airports_checked', ''))}. {srcs}</p>
    {transit_html}
    <div class="best">
      <div><span class="lbl">Recommended stay</span><b>★ {e(rec_txt)}</b><p>{e(why)}</p></div>
      <div><span class="lbl">Best for</span><ul>{themes}</ul></div>
    </div>
    {weather_html}
  </section>"""


CSS = r"""
.arrive .airport { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 12px 14px; }
.arrive summary { display: flex; gap: 12px; align-items: center; cursor: pointer; }
.arrive summary b { display: block; } .arrive summary small { display: block; color: var(--muted); font-size: 13px; }
.arrive .code { font: 800 18px var(--font-display); color: var(--accent); background: var(--accent-soft); padding: 6px 10px; border-radius: 10px; }
.arrive table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 14px; }
.arrive th { text-align: left; font-size: 11px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); padding: 4px 6px; }
.arrive td { padding: 8px 6px 2px; border-top: 1px solid var(--line); vertical-align: top; }
.arrive td small { display: block; color: var(--muted); font-size: 12.5px; }
.arrive td.v { white-space: nowrap; font-variant-numeric: tabular-nums; font-weight: 600; }
.arrive tr.note td { border-top: 0; padding: 0 6px 8px; font-size: 12.5px; color: var(--muted); }
.arrive .transit { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 14px 16px; }
.arrive .transit h3 { margin: 0; font: 700 17px/1.3 var(--font-display); }
.arrive .transit > p { margin: 4px 0 8px; font-size: 14px; font-weight: 600; color: var(--accent); }
.arrive .transit ul { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: 1fr 1fr; gap: 8px 14px; }
.arrive .transit li { display: grid; grid-template-columns: 22px 1fr; gap: 8px; font-size: 14px; }
.arrive .transit .mk { display: grid; place-items: center; width: 22px; height: 22px; border-radius: 50%; font-size: 12px; font-weight: 800; }
.arrive .transit .yes .mk { background: #ccfbf1; color: #0f766e; } .arrive .transit .no .mk { background: #fee2e2; color: #b91c1c; }
.arrive .transit em { font-style: normal; font-size: 11px; font-weight: 700; color: var(--accent-ink); background: var(--accent); padding: 1px 7px; border-radius: 999px; margin-left: 6px; }
.arrive .transit small { display: block; color: var(--muted); font-size: 12.5px; line-height: 1.4; margin-top: 2px; }
@media (max-width: 560px) { .arrive .transit ul { grid-template-columns: 1fr; } }
.weather, .climate { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 14px 16px; }
.weather h3, .climate h3 { margin: 0; font: 700 17px/1.3 var(--font-display); }
.wgrid { display: grid; grid-template-columns: repeat(12, 1fr); gap: 4px; margin-top: 10px; }
.wm { display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 6px 0; border-radius: 10px; font-size: 11px; }
.wm .wh { font-weight: 700; }
.wm .wbar { height: 70px; width: 10px; display: flex; align-items: flex-end; background: var(--bg); border-radius: 6px; }
.wm .wbar i { display: block; width: 100%; border-radius: 6px; background: linear-gradient(#f97316, #fcd34d); }
.wm .wl { color: var(--muted); }
.wm b { font-size: 12px; } .wm small { font-size: 9.5px; color: var(--muted); text-align: center; line-height: 1.3; }
.wm.now { background: var(--accent); color: var(--accent-ink); box-shadow: 0 4px 12px rgba(0,0,0,.15); transform: scale(1.06); }
.wm.now .wl, .wm.now small { color: inherit; opacity: .9; } .wm.now .wbar { background: rgba(255,255,255,.25); }
#w-now { margin: 2px 0 0; font-weight: 600; color: var(--accent); }
.climate > p { margin: 4px 0 10px; font-size: 15px; font-weight: 600; }
.climate ul { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: 1fr 1fr; gap: 10px 14px; }
.climate li { display: grid; grid-template-columns: 40px 1fr; gap: 10px; align-items: start; }
.climate .wi { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 12px; background: var(--accent-soft); font-size: 22px; }
.climate li b { display: block; font-size: 14px; } .climate li small { color: var(--muted); font-size: 13px; line-height: 1.4; }
@media (max-width: 560px) { .wgrid { grid-template-columns: repeat(6, 1fr); } .climate ul { grid-template-columns: 1fr; } }
.arrive .best { display: grid; grid-template-columns: 1fr 1.4fr; gap: 10px; }
.arrive .best > div { background: var(--accent-soft); border-radius: 16px; padding: 14px; }
.arrive .lbl { font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.arrive .best b { display: block; font: 800 20px/1.3 var(--font-display); }
.arrive .best p { margin: 4px 0 0; font-size: 14px; }
.arrive .best ul { list-style: none; margin: 4px 0 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
.arrive .best li b { font: 700 15px var(--font-body); display: inline; } .arrive .best li span { color: var(--muted); font-size: 13px; margin-left: 6px; }
@media (max-width: 560px) { .arrive .best { grid-template-columns: 1fr; } }
.tabs button.is-custom { border: 2px dashed var(--accent); color: var(--accent); font-weight: 700; }
.tabs button.is-custom[aria-pressed="true"] { border-style: solid; background: var(--accent); color: var(--accent-ink); }
.custom-teaser { display: grid; grid-template-columns: 40px 1fr auto; gap: 12px; align-items: center; text-align: left; width: 100%;
  font: inherit; color: var(--ink); cursor: pointer; padding: 14px 16px; border-radius: 16px; border: 2px dashed var(--accent);
  background: linear-gradient(135deg, var(--accent-soft), transparent 70%); }
.custom-teaser .spark { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 12px; background: var(--accent); color: var(--accent-ink); font-size: 20px; }
.custom-teaser b { display: block; font: 700 16px/1.3 var(--font-display); }
.custom-teaser small { display: block; font-size: 13px; color: var(--muted); margin-top: 2px; }
.custom-teaser .cta { font-weight: 700; color: var(--accent); white-space: nowrap; }
.custom-teaser:hover { border-style: solid; }
.custom-teaser[hidden], .style-pick[hidden] { display: none; }
.toc { position: sticky; top: 0; z-index: 5; display: flex; gap: 6px; overflow-x: auto; padding: 8px 0; margin: -16px 0 -16px;
  background: var(--bg); scrollbar-width: none; }
.toc a { flex: none; font: 600 13px var(--font-body); text-decoration: none; padding: 6px 12px; border-radius: 999px;
  background: var(--surface); border: 1px solid var(--line); color: var(--ink); }
.toc a.hl { border-color: var(--accent); color: var(--accent); }
.toc a:hover { border-color: var(--accent); }
section[aria-labelledby] { scroll-margin-top: 56px; }
.custom { display: flex; flex-direction: column; gap: 12px; }
.pl-box { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; padding: 12px 14px; }
.pl-box summary { cursor: pointer; font-size: 14px; }
.pl-box[open] summary { margin-bottom: 10px; }
.ht-more-wrap { display: flex; justify-content: center; }
.ht-more-wrap .btn { border: 1px solid var(--line); cursor: pointer; }
.step { display: flex; align-items: center; gap: 10px; margin-top: 8px; }
.step h3 { margin: 0; font: 700 17px/1.3 var(--font-display); }
.step small { font: 500 13px var(--font-body); }
.pl-num { display: grid; place-items: center; width: 26px; height: 26px; border-radius: 50%; background: var(--accent); color: var(--accent-ink); font-weight: 800; font-size: 13px; flex: none; }
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chips button { font: 600 14px var(--font-body); padding: 8px 14px; border-radius: 999px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; }
.chips button[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
.chips.small button { padding: 5px 11px; font-size: 13px; }
.places { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 8px; }
.place { display: grid; grid-template-columns: 22px 1fr; gap: 10px; padding: 12px; border-radius: 14px; background: var(--surface); border: 1px solid var(--line); cursor: pointer; }
.place.pl-rec { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
.place input { width: 18px; height: 18px; margin: 2px 0 0; accent-color: var(--accent); }
.place b { font-weight: 700; }
.place .tags { display: flex; flex-wrap: wrap; gap: 4px; margin: 4px 0; }
.place .tags span { font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 999px; background: var(--bg); color: var(--muted); }
.place .tags .recb { background: var(--accent); color: var(--accent-ink); }
.place .tags .hot { background: #fde68a; color: #78350f; }
.place p { margin: 0; font-size: 12.5px; color: var(--muted); line-height: 1.4; }
.when { display: flex; flex-wrap: wrap; gap: 10px; }
.dtl small { text-transform: none; letter-spacing: 0; font-weight: 500; }
.dtf { display: flex; flex-direction: column; gap: 4px; flex: 1 1 260px; }
.dtl { font-size: 12px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
.dt { display: flex; gap: 6px; flex-wrap: wrap; }
.dt select { font: 500 15px var(--font-body); padding: 9px 8px; border-radius: 12px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); }
.place .pop { color: var(--star); font-size: 12px; letter-spacing: 1px; white-space: nowrap; }
.when label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; flex: 1 1 180px; }
.when input, .when select { font: 500 15px var(--font-body); padding: 10px 12px; border-radius: 12px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); text-transform: none; letter-spacing: 0; }
.season { display: flex; flex-direction: column; gap: 8px; padding: 14px; border-radius: 16px; background: var(--surface); border: 1px solid var(--line); }
.season .big { font: 800 20px/1.2 var(--font-display); }
.season ul { margin: 0; padding-left: 18px; display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
.season .warn { color: #b45309; }
.season .good { color: #0f766e; }
.months-wrap h4 { margin: 6px 0; font-size: 14px; }
.months { display: grid; grid-template-columns: repeat(12, 1fr); gap: 4px; }
.months div { text-align: center; padding: 8px 0 6px; border-radius: 10px; font-size: 12px; font-weight: 700; position: relative; }
.months small { display: block; font-size: 10px; font-weight: 600; opacity: .85; }
.months .best::after { content: "★"; position: absolute; top: -6px; right: 2px; font-size: 12px; color: var(--star); }
@media (max-width: 520px) { .months { grid-template-columns: repeat(6, 1fr); } }
.fine { font-size: 12px; margin: 4px 0 0; }
.run { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.run .btn { border: 0; cursor: pointer; font-size: 15px; }
.btn.ghost { background: var(--surface); color: var(--ink); border: 1px solid var(--line); }
.btn[disabled] { opacity: .5; cursor: default; }
.pl-day { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; padding: 14px 16px; display: flex; flex-direction: column; gap: 10px; }
.pl-day h4 { margin: 0; font: 700 17px/1.3 var(--font-display); }
.pl-day .dmeta { font-size: 13px; color: var(--muted); }
.tl { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.tl li { display: grid; grid-template-columns: 52px 1fr; gap: 10px; padding: 8px 0; border-top: 1px dashed var(--line); }
.tl li:first-child { border-top: 0; }
.tl time { font: 700 14px var(--font-display); font-variant-numeric: tabular-nums; color: var(--accent); }
.tl b { display: block; }
.tl p { margin: 2px 0 0; font-size: 13px; color: var(--muted); }
.tl .move { font-size: 12px; color: var(--muted); }
.ai-sum { padding: 14px; border-radius: 16px; background: var(--accent-soft); font-size: 15px; }
.ai-tips { margin: 0; padding-left: 18px; font-size: 14px; display: flex; flex-direction: column; gap: 4px; }
.hotels-head { display: flex; align-items: center; justify-content: space-between; gap: 10px; flex-wrap: wrap; margin-top: 6px; }
.hotels-head h3 { margin: 0; font: 700 17px/1.3 var(--font-display); }
.hotels { display: flex; flex-direction: column; gap: 8px; }
.hotel { display: grid; grid-template-columns: 1fr auto; gap: 4px 12px; padding: 12px 14px; border-radius: 14px; background: var(--surface); border: 1px solid var(--line); text-decoration: none; }
.hotel:hover { border-color: var(--accent); }
.hotel .hn { font-weight: 700; }
.hotel .hs { font-size: 12.5px; color: var(--muted); }
.hotel .hp { text-align: right; font: 800 20px/1.1 var(--font-display); font-variant-numeric: tabular-nums; }
.hotel .hp small { display: block; font: 500 11px var(--font-body); color: var(--muted); }
.hotel .hb { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 6px; }
.hotel .hb span { font-size: 11.5px; font-weight: 700; padding: 3px 9px; border-radius: 999px; background: var(--bg); color: var(--muted); }
.hotel .hb .g { background: #ccfbf1; color: #0f766e; } .hotel .hb .r { background: #fee2e2; color: #b91c1c; }
.hotel .hb .n { background: var(--bg); color: var(--muted); } .hotel .hb .s { background: var(--accent); color: var(--accent-ink); }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .hotel .hb .g { background: #134e4a; color: #99f6e4; }
  :root:not([data-theme="light"]) .hotel .hb .r { background: #7f1d1d; color: #fecaca; }
  :root:not([data-theme="light"]) .place .tags .hot { background: #78350f; color: #fde68a; } }
"""

JS = r"""
<script>
(() => {
  const el = document.getElementById("planner-data");
  if (!el) return;
  const D = JSON.parse(el.textContent);
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const DOW = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const S = { types: new Set(), picked: new Set(), userTouched: false, filter: "all", expanded: false };
  const store = { get(k) { try { return JSON.parse(localStorage.getItem("planner:" + k)); } catch { return null; } },
                  set(k, v) { try { localStorage.setItem("planner:" + k, JSON.stringify(v)); } catch {} } };

  const typeLabel = Object.fromEntries(D.types.map((t) => [t.id, t.label]));
  const recAreas = () => new Set([...S.types].flatMap((t) => (D.types.find((x) => x.id === t) || {}).areas || []));
  const isRec = (p) => [...S.types].some((t) => p.types.includes(t));
  const parseDT = (v) => (v ? new Date(v) : null);
  const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
  // English dates everywhere ("Wed, Dec 10"), whatever the viewer's OS language is.
  const fmtDate = (isoDate) => { const d = new Date(isoDate.slice(0, 10) + "T12:00"); return `${DOW[d.getDay()]}, ${MON[d.getMonth()]} ${d.getDate()}`; };
  const fmtLong = (isoDate) => { const d = new Date(isoDate.slice(0, 10) + "T12:00"); return `${MON[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`; };
  const stars = (n) => "★".repeat(n) + "☆".repeat(5 - n);
  const dur = (m) => m < 60 ? `${m} min` : `${Math.floor(m / 60)} h${m % 60 ? ` ${m % 60} min` : ""}`;

  function trip() {
    const a = parseDT($("pl-arrive").value), b = parseDT($("pl-depart").value);
    if (!a || !b || b <= a) return null;
    const nights = [];
    for (let d = new Date(a.getFullYear(), a.getMonth(), a.getDate()); iso(d) < iso(b); d = addDays(d, 1)) nights.push(iso(d));
    return { a, b, nights, months: [...new Set([a.getMonth(), b.getMonth()])] };
  }

  // ── 1. types
  function renderTypes() {
    $("pl-types").innerHTML = D.types.map((t) =>
      `<button type="button" data-t="${t.id}" aria-pressed="${S.types.has(t.id)}">${esc(t.label)}</button>`).join("");
  }
  $("pl-types").addEventListener("click", (e) => {
    const b = e.target.closest("button[data-t]"); if (!b) return;
    const t = b.dataset.t; S.types.has(t) ? S.types.delete(t) : S.types.add(t);
    if (!S.userTouched) S.picked = new Set(D.places.filter(isRec).map((p) => p.id));
    store.set("types", [...S.types]); renderAll();
  });

  // ── 2. places
  function hotMonths() { const t = trip(); return t ? t.months.filter((m) => D.climate.months[m].high >= 36) : []; }
  function renderPlaces() {
    const hot = hotMonths().length > 0;
    // Always most popular first, whatever the traveler picked; their picks are just ticked in place.
    const order = Object.fromEntries(D.places.map((p, i) => [p.id, i]));
    const list = [...D.places].sort((x, y) => ((y.popularity || 0) - (x.popularity || 0)) || (order[x.id] - order[y.id]));
    $("pl-places").innerHTML = list.map((p) => {
      const tags = [];
      if (isRec(p)) tags.push(`<span class="recb">For you</span>`);
      tags.push(`<span>${esc(p.area)}</span>`, `<span>${dur(p.minutes)}</span>`,
                `<span>${p.setting === "indoor" ? "Indoor" : p.setting === "mixed" ? "Indoor + outdoor" : "Outdoor"}</span>`);
      if (hot && p.setting === "outdoor") tags.push(`<span class="hot">Hot season: go early or late</span>`);
      return `<label class="place${isRec(p) ? " pl-rec" : ""}"><input type="checkbox" data-p="${p.id}"${S.picked.has(p.id) ? " checked" : ""}>
        <span><b>${esc(p.name)}</b> <span class="pop" title="Popularity with visitors">${stars(p.popularity || 0)}</span><span class="tags">${tags.join("")}</span>
        <p>${esc(p.price_text)}${p.hours ? " · " + esc(p.hours) : ""}</p><p>Best: ${esc(p.best)}</p></span></label>`;
    }).join("");
    $("pl-count").textContent = `${S.picked.size} picked`;
  }
  $("pl-places").addEventListener("change", (e) => {
    const c = e.target.closest("input[data-p]"); if (!c) return;
    S.userTouched = true; c.checked ? S.picked.add(c.dataset.p) : S.picked.delete(c.dataset.p);
    store.set("picked", [...S.picked]); $("pl-count").textContent = `${S.picked.size} picked`;
  });

  // ── hotel price index helpers
  const H = D.hotels;
  const idxAt = (isoDate) => {
    if (!H) return null;
    const i = Math.round((new Date(isoDate) - new Date(H.start)) / 864e5);
    return i >= 0 && i < H.index.length ? H.index[i] : null;
  };
  function monthIndex() {
    if (!H) return {};
    const by = {};
    H.index.forEach((v, i) => { if (v == null) return; const m = addDays(new Date(H.start), i).getMonth(); (by[m] ||= []).push(v); });
    return Object.fromEntries(Object.entries(by).filter(([, a]) => a.length >= 10).map(([m, a]) => [m, a.reduce((s, x) => s + x, 0) / a.length]));
  }

  // ── 3. season + best months
  function renderSeason() {
    const t = trip(), box = $("pl-season");
    if (!t) { box.innerHTML = `<p class="muted fine">Set arrival and departure to see the weather, closures and hotel prices for your dates.</p>`; return; }
    const m = t.months.map((i) => D.climate.months[i]);
    const hi = Math.max(...m.map((x) => x.high)), lo = Math.min(...m.map((x) => x.low));
    const items = [];
    t.months.forEach((i) => items.push(`<li>${MON[i]}: ${esc(D.climate.months[i].note)} Sea about ${D.climate.months[i].sea}°C.</li>`));
    const days = []; for (let d = new Date(t.a.getFullYear(), t.a.getMonth(), t.a.getDate()); d <= t.b; d = addDays(d, 1)) days.push(new Date(d));
    const dows = new Set(days.map((d) => d.getDay()));
    const FULL = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    D.places.filter((p) => S.picked.has(p.id)).forEach((p) => {
      const m = /closed\s+(sun|mon|tue|wed|thu|fri|sat)/i.exec(p.hours || "");
      if (!m) return;
      const dow = DOW.findIndex((x) => x.toLowerCase() === m[1].toLowerCase());
      const hit = days.filter((d) => d.getDay() === dow);
      if (hit.length) items.push(`<li class="warn">${esc(p.name)} is closed on ${FULL[dow]}s (${hit.map((d) => fmtDate(iso(d))).join(" · ")}).</li>`);
    });
    if (dows.has(5) && S.picked.has("mosque")) items.push(`<li class="warn">Friday: the Grand Mosque closes for prayers around midday.</li>`);
    if (hi >= 36) items.push(`<li class="warn">Very hot: keep outdoor places before 10:00 or after 17:00; theme parks and museums are air-conditioned.</li>`);
    if (H && t.nights.length) {
      const v = t.nights.map(idxAt).filter((x) => x != null);
      if (v.length) {
        const avg = v.reduce((s, x) => s + x, 0) / v.length, pct = Math.round((avg - 1) * 100);
        const peak = t.nights.filter((n) => (idxAt(n) || 0) >= 1.4);
        const level = avg >= 1.8 ? `about ${avg.toFixed(1)}× typical prices` : pct > 0 ? `${pct}% above typical prices` : pct < 0 ? `${-pct}% below typical prices` : "about typical prices";
        items.push(`<li class="${pct > 8 ? "warn" : pct < -8 ? "good" : ""}">Hotels on your nights: ${level}${peak.length ? ` · peak nights ${peak.map(fmtDate).join(" · ")} (likely a big event; some hotels are sold out)` : ""}.</li>`);
      } else items.push(`<li class="muted">Your dates are beyond the hotel price data we have.</li>`);
    }
    const len = Math.max(1, Math.round((t.b - t.a) / 36e5));
    box.innerHTML = `<div class="season"><div class="big">${lo}–${hi}°C · ${t.nights.length} night${t.nights.length === 1 ? "" : "s"} · ${len} hours on the ground</div><ul>${items.join("")}</ul></div>`;
  }

  function renderMonths() {
    const types = S.types.size ? [...S.types] : D.types.map((t) => t.id);
    const mi = monthIndex(), vals = Object.values(mi);
    const minI = vals.length ? Math.min(...vals) : 1, maxI = vals.length ? Math.max(...vals) : 1;
    const priceW = S.types.has("budget") ? 0.5 : 0.3;
    const scores = MON.map((_, m) => {
      const fit = types.reduce((s, t) => s + D.fit[t][m], 0) / types.length;
      const cheap = mi[m] == null || maxI === minI ? 0.5 : 1 - (mi[m] - minI) / (maxI - minI);
      return (1 - priceW) * fit + priceW * cheap;
    });
    const top = [...scores].map((s, i) => [s, i]).sort((a, b) => b[0] - a[0]).slice(0, 3).map((x) => x[1]);
    const color = (s) => s >= 0.85 ? ["#0f766e", "#ccfbf1"] : s >= 0.7 ? ["#3f6212", "#ecfccb"] : s >= 0.55 ? ["#92400e", "#fef3c7"] : ["#991b1b", "#fee2e2"];
    $("pl-months").innerHTML = scores.map((s, m) => { const [fg, bg] = color(s);
      return `<div class="${top.includes(m) ? "best" : ""}" style="color:${fg};background:${bg}" title="${esc(D.climate.months[m].note)}">${MON[m]}<small>${D.climate.months[m].high}°</small></div>`; }).join("");
    $("pl-months-note").textContent = `For ${types.map((t) => typeLabel[t]).join(", ")}: weather fit${H ? " plus hotel prices from our tracked hotels" : ""}. ★ = best three.`;
  }

  // ── stays
  function hotelView(h, t) {
    // One-night list price (live Google Hotels read, no calendar): shown as-is, never colored.
    if (H.single) return { total: null, perNight: h.price ?? null, pos: null, color: "n", nights: 1, dated: false,
                           missing: 0, beyond: false, single: true };
    const at = (isoDate) => { const i = Math.round((new Date(isoDate) - new Date(H.start)) / 864e5); return i >= 0 && i < h.prices.length ? h.prices[i] : null; };
    const pos = (isoDate) => {
      const p = at(isoDate); if (p == null) return null;
      const dow = new Date(isoDate).getDay(), same = [];
      for (let i = 0; i < Math.min(180, h.prices.length); i++) { const d = addDays(new Date(H.start), i); if (d.getDay() === dow && h.prices[i] != null) same.push(h.prices[i]); }
      if (same.length < 4) return null;
      return Math.round(100 * same.filter((x) => x < p).length / (same.length - 1));
    };
    let nights = t ? t.nights : [];
    if (!nights.length) { const d = addDays(new Date(H.start), 30); nights = [iso(d)]; }
    const prices = nights.map(at), known = prices.filter((p) => p != null);
    const positions = nights.map(pos).filter((p) => p != null);
    const p = positions.length ? Math.round(positions.reduce((s, x) => s + x, 0) / positions.length) : null;
    return { total: known.length === nights.length ? known.reduce((s, x) => s + x, 0) : null, perNight: known.length ? Math.round(known.reduce((s, x) => s + x, 0) / known.length) : null,
             pos: p, color: p == null ? "n" : p <= 25 ? "g" : p >= 75 ? "r" : "n", nights: nights.length, dated: !!t,
             missing: nights.length - known.length, beyond: nights.every((n) => { const i = Math.round((new Date(n) - new Date(H.start)) / 864e5); return i < 0 || i >= h.prices.length; }) };
  }
  function renderHotels() {
    if (!H) { $("ht-note").textContent = "Hotel price tracking isn't set up for this city yet."; return; }
    const t = trip();
    const rows = H.hotels.map((h) => ({ h, v: hotelView(h, t) }));
    const order = { g: 0, n: 1, r: 2 };
    let shown;
    if (!S.expanded) {
      // Collapsed: the three most-reviewed hotels, not the "best deals", so it never reads like an ad.
      shown = [...rows].sort((x, y) => (y.h.votes || 0) - (x.h.votes || 0)).slice(0, 3);
      $("ht-sub").textContent = "Most reviewed";
    } else {
      // Same neutral order as the collapsed list (most reviewed first), never "best deal first".
      rows.sort((x, y) => (y.h.votes || 0) - (x.h.votes || 0));
      shown = rows.filter((r) => S.filter === "all" || (S.filter === "good" && r.v.color === "g"));
      $("ht-sub").textContent = "Most reviewed";
    }
    const lbl = { g: "Good price for these dates", n: "Typical price", r: "Pricier than usual" };
    const noColor = (v) => v.perNight == null || v.single;
    $("ht-list").innerHTML = shown.map(({ h, v }) => `
      <a class="hotel" href="${esc(h.url)}" target="_blank" rel="noopener sponsored">
        <span><span class="hn">${esc(h.name)}</span><br><span class="hs">${"★".repeat(h.stars || 0)} · ${h.rating ?? "-"} (${(h.votes || 0).toLocaleString()})${h.area ? " · " + esc(h.area) : ""}</span></span>
        <span class="hp">${v.perNight != null ? "$" + v.perNight : "–"}<small>${v.perNight == null ? (v.beyond ? "beyond our price data" : "no rooms listed (sold out?)")
          : v.missing ? `avg of ${v.nights - v.missing} nights; ${v.missing} with no rooms listed`
          : v.single ? `per night, ${H.checkin ? fmtLong(H.checkin) : "next week"}`
          : v.dated ? (v.nights > 1 ? `$${v.total} for ${v.nights} nights` : "per night") : "per night, 30 days out"}</small></span>
        <span class="hb">${noColor(v) ? "" : `<span class="${v.color}">${lbl[v.color]}</span>`}${h.loc != null ? `<span>Location ${h.loc}/10</span>` : ""}${h.sights.length ? `<span>${esc(h.sights[0])}</span>` : ""}</span>
      </a>`).join("") || `<p class="muted">No hotels match this filter.</p>`;
    if (H.single) { $("ht-note").textContent = `Sample prices for one night (${H.checkin ? fmtLong(H.checkin) : "next week"}), ${H.adults} adults, one room, USD · Google Hotels lowest across sites, checked ${fmtLong(H.fetched)}. Prices on your dates will differ.`; return; }
    $("ht-note").textContent = `${t ? "Prices for your nights" : "Pick dates above to price your nights"} · ${H.adults} adults, one room, ${H.currency} · Google Hotels lowest across sites, checked ${fmtLong(H.fetched)}. Colors compare each hotel with its own prices on the same weekday.`;
  }
  $("ht-filter").addEventListener("click", (e) => {
    const b = e.target.closest("button[data-f]"); if (!b) return;
    S.filter = b.dataset.f; [...$("ht-filter").children].forEach((x) => x.setAttribute("aria-pressed", x === b)); renderHotels();
  });
  $("ht-more").addEventListener("click", (e) => {
    S.expanded = !S.expanded;
    e.currentTarget.setAttribute("aria-expanded", S.expanded);
    e.currentTarget.textContent = S.expanded ? "Show fewer" : `See all ${e.currentTarget.dataset.n} hotels`;
    $("ht-all").hidden = !S.expanded;
    renderHotels();
    if (!S.expanded) document.getElementById("h-stays").scrollIntoView({ block: "start" });
  });
  // Trip plans' "My dates" tab: start from the style picked there if nothing is chosen yet.
  document.addEventListener("tripplans:custom", (e) => {
    const style = e.detail && e.detail.style;
    if (!S.types.size && style && typeLabel[style]) {
      S.types.add(style);
      if (!S.userTouched) S.picked = new Set(D.places.filter(isRec).map((p) => p.id));
      renderAll();
    }
  });

  // ── 4. Run AI (Claude via the artifact `sample` capability)
  const km = (a, b) => { const R = 6371, r = Math.PI / 180, dLa = (b.lat - a.lat) * r, dLo = (b.lon - a.lon) * r;
    const h = Math.sin(dLa / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLo / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(h)); };
  const byId = Object.fromEntries(D.places.map((p) => [p.id, p]));
  function prompt(t) {
    const picked = D.places.filter((p) => S.picked.has(p.id));
    const optional = D.places.filter((p) => !S.picked.has(p.id) && isRec(p)).slice(0, 8);
    const slim = (p) => ({ id: p.id, name: p.name, area: p.area, minutes: p.minutes, setting: p.setting, best: p.best, hours: p.hours, price: p.price_text, tip: p.tip });
    const ctx = {
      city: D.city, arrive: $("pl-arrive").value, leave: $("pl-depart").value,
      days: (() => { const out = []; for (let d = new Date(t.a.getFullYear(), t.a.getMonth(), t.a.getDate()); d <= t.b; d = addDays(d, 1)) out.push(`${iso(d)} (${DOW[d.getDay()]})`); return out; })(),
      pace: $("pl-pace").value, traveler_types: [...S.types].map((x) => typeLabel[x]),
      weather: t.months.map((m) => ({ month: MON[m], high_c: D.climate.months[m].high, low_c: D.climate.months[m].low, note: D.climate.months[m].note })),
      must_include: picked.map(slim), optional_if_time: optional.map(slim),
      tours: D.tours.map((x) => ({ title: x.title, duration: x.duration, price: x.price, covers_place_ids: x.covers })),
      suggested_stay_areas: [...recAreas()],
      taxi: D.taxi ? `metered taxi: ${D.currency} ${D.taxi.flag_day} flag fall (${D.currency} ${D.taxi.flag_airport} from the airport), ${D.currency} ${D.taxi.per_km}/km, ${D.currency} ${D.taxi.min_fare} minimum; ride apps similar` : "",
    };
    return `You are planning a real trip in ${D.city}. Build a day-by-day schedule from the data below.
Rules:
- First day starts about 90 minutes after "arrive" (immigration + transfer). Last day ends 3 hours before "leave" at the airport (${D.airport || "main airport"}).
- Respect each place's opening hours and closed days for the actual weekday. Respect the weather: when the daily high is 36°C or more, outdoor places only before 10:00 or after 17:00.
- Group places by area to limit driving. Fit "must_include" places; add "optional_if_time" only if there is room. If something cannot fit, say so in tips.
- Pace: relaxed = up to 3 stops a day, standard = 4, packed = 6, plus meals.
- If a tour covers several must_include places, you may use it (set place to null and name the tour in label).
- Include lunch and dinner suggestions as stops with place null.
Reply with ONLY JSON in this shape:
{"summary":"2 sentences","stay_area":"one area name","days":[{"date":"YYYY-MM-DD","title":"short","stops":[{"time":"HH:MM","place":"<id from the data or null>","label":"short name","minutes":90,"note":"one line"}]}],"tips":["short tip"]}

DATA:
${JSON.stringify(ctx)}`;
  }
  function renderPlan(plan) {
    const taxi = D.taxi, rf = D.road_factor || 1.25;
    const days = (plan.days || []).map((d) => {
      let prev = null, fees = 0, rides = 0;
      const items = (d.stops || []).map((s) => {
        const p = s.place && byId[s.place]; let move = "";
        if (p && p.lat != null && prev && prev.lat != null && taxi) {
          const k = km(prev, p) * rf;
          if (k > 0.8) { const fare = Math.max(taxi.min_fare, taxi.flag_day + taxi.per_km * k); rides += fare;
            move = `<span class="move">Taxi ≈ ${k.toFixed(0)} km, ${Math.round(k / 45 * 60 + 5)} min, ≈ ${D.currency} ${Math.round(fare)}</span>`; }
        }
        if (p) { if (typeof p.price === "number") fees += p.price; if (p.lat != null) prev = p; }
        return `<li><time>${esc(s.time)}</time><span>${move}<b>${esc(s.label || (p && p.name) || "")}</b><p>${esc(s.note || "")}${s.minutes ? ` · ${s.minutes} min` : ""}</p></span></li>`;
      }).join("");
      const dt = d.date ? new Date(d.date + "T12:00") : null;
      return `<article class="pl-day"><h4>${dt ? fmtDate(d.date) + " · " : ""}${esc(d.title || "")}</h4>
        <div class="dmeta">Entry fees ≈ ${D.currency} ${Math.round(fees)}${rides ? ` · taxis ≈ ${D.currency} ${Math.round(rides)}` : ""}</div><ol class="tl">${items}</ol></article>`;
    }).join("");
    $("pl-result").innerHTML = `<div class="ai-sum">${esc(plan.summary || "")}${plan.stay_area ? `<br><b>Stay in:</b> ${esc(plan.stay_area)}` : ""}</div>${days}
      ${(plan.tips || []).length ? `<ul class="ai-tips">${plan.tips.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>` : ""}
      <p class="muted fine">AI draft from this page's data. Check opening hours and prices before you go.</p>`;
  }
  let sample = null, ctl = null;
  const run = $("pl-run"), stop = $("pl-stop"), status = $("pl-status");
  run.onclick = async () => {
    const t = trip();
    if (!t) { status.textContent = "Set arrival and departure first."; return; }
    if (!S.picked.size && !S.types.size) { status.textContent = "Pick a trip type or a few places first."; return; }
    if (!sample) { status.textContent = "Run AI works when this page is opened on claude.ai."; return; }
    ctl = new AbortController(); run.disabled = true; stop.hidden = false; status.textContent = "Thinking…";
    try {
      const plan = await sample.json(prompt(t), { signal: ctl.signal, onText: ({ text }) => { status.textContent = `Writing your plan… (${text.length} characters)`; } });
      renderPlan(plan); status.textContent = "";
    } catch (e) {
      const msg = { cancelled: "", not_granted: "AI wasn't allowed for this page.", sampling_disabled: "AI isn't available for this account.",
        rate_limited: "Too many requests right now. Try again in a bit.", invalid_json: "The answer came back garbled. Try again.",
        session_expired: "Sign in to claude.ai again." }[e && e.code];
      status.textContent = msg ?? "Something went wrong. Try again.";
      if (e && ["not_granted", "sampling_disabled", "not_declared", "capability_disabled"].includes(e.code)) run.hidden = true;
    } finally { run.disabled = false; stop.hidden = true; }
  };
  stop.onclick = () => ctl && ctl.abort();
  if (window.claude && claude.use) claude.use("sample").then((s) => { sample = s; if (!s) status.textContent = "Run AI works when this page is opened on claude.ai."; });
  else status.textContent = "Run AI works when this page is opened on claude.ai.";

  // ── init
  (store.get("types") || []).forEach((t) => typeLabel[t] && S.types.add(t));
  const saved = store.get("picked");
  if (saved && saved.length) { S.userTouched = true; saved.forEach((p) => byId[p] && S.picked.add(p)); }
  else S.picked = new Set(D.places.filter(isRec).map((p) => p.id));
  // English date (and time) pickers; the hidden input keeps "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM".
  function mountPicker(id, { dateOnly = false, onChange } = {}) {
    const host = document.querySelector(`.dt[data-for="${id}"]`), hidden = $(id), y0 = new Date().getFullYear();
    if (!host || !hidden) return null;
    const opt = (v, t) => `<option value="${v}">${t}</option>`;
    const times = []; for (let m = 0; m < 1440; m += 30) { const h = Math.floor(m / 60), mm = m % 60;
      times.push(opt(`${String(h).padStart(2, "0")}:${String(mm).padStart(2, "0")}`, `${h % 12 || 12}:${String(mm).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`)); }
    host.innerHTML = `<select data-k="m" aria-label="Month">${opt("", "Month")}${MON.map((m, i) => opt(i + 1, m)).join("")}</select>`
      + `<select data-k="d" aria-label="Day">${opt("", "Day")}${Array.from({ length: 31 }, (_, i) => opt(i + 1, i + 1)).join("")}</select>`
      + `<select data-k="y" aria-label="Year">${opt("", "Year")}${[y0, y0 + 1, y0 + 2].map((y) => opt(y, y)).join("")}</select>`
      + (dateOnly ? "" : `<select data-k="t" aria-label="Time">${opt("", "Time")}${times.join("")}</select>`);
    const sel = (k) => host.querySelector(`[data-k="${k}"]`);
    const set = (v) => {
      const ok = dateOnly ? /^\d{4}-\d{2}-\d{2}$/.test(v || "") : /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(v || "");
      hidden.value = ok ? v : "";
      sel("y").value = ok ? +v.slice(0, 4) : ""; sel("m").value = ok ? +v.slice(5, 7) : ""; sel("d").value = ok ? +v.slice(8, 10) : "";
      if (!dateOnly) sel("t").value = ok ? v.slice(11, 16) : "";
    };
    set(store.get(id));
    host.addEventListener("change", () => {
      const y = sel("y").value, m = sel("m").value, d = sel("d").value, t = dateOnly ? "x" : sel("t").value;
      if (y && m && d) { const last = new Date(+y, +m, 0).getDate(); if (+d > last) sel("d").value = last; }
      const date = `${y}-${String(m).padStart(2, "0")}-${String(sel("d").value).padStart(2, "0")}`;
      hidden.value = y && m && d && t ? (dateOnly ? date : `${date}T${t}`) : "";
      store.set(id, hidden.value); (onChange || renderAll)();
    });
    return { set };
  }
  ["pl-arrive", "pl-depart"].forEach((id) => mountPicker(id));

  function renderAll() { renderTypes(); renderPlaces(); renderSeason(); renderMonths(); renderHotels(); }
  renderAll();
})();
</script>
"""
