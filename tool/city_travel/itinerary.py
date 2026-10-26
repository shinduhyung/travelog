"""Trip plans section for build_page.py.

Reads tool/city_travel/itineraries/<city-slug>.json and renders one tab per trip
length, each day with a route map, a timeline of stops and the transport between
them. Taxi legs are estimated from straight-line distance x road_factor with the
city's metered fare; walking, shuttle, pickup and tour legs cost nothing extra.
"""
import html
import json
import math
import re
from pathlib import Path

from trip_maps import BaseMap

ITIN_DIR = Path(__file__).resolve().parent / "itineraries"
e = html.escape


def load_itinerary(slug):
    p = ITIN_DIR / f"{slug}.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def km_between(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


CURRENCY = "AED"  # set per city by Renderer (itinerary "currency")


def fmt_aed(v):
    return f"{CURRENCY} {round(v):,}"


def hhmm_plus(at, minutes):
    h, m = map(int, at.split(":"))
    t = h * 60 + m + minutes
    return f"{t // 60 % 24:02d}:{t % 60:02d}"


def dur(minutes):
    if minutes < 60:
        return f"{minutes} min"
    h, m = divmod(minutes, 60)
    return f"{h} h {m} min" if m else f"{h} h"


class Renderer:
    def __init__(self, data, city, tours, landmarks, page):
        global CURRENCY
        self.d = data
        CURRENCY = data.get("currency", "AED")
        self.usd_rate = data.get("usd_rate", data.get("usd_to_aed", 1))
        self.airports = {k for k, v in data["places"].items() if v.get("kind") == "airport"}
        self.city = city
        self.tours = tours
        self.landmarks = landmarks  # name -> landmark record
        self.page = page            # build_page module (fetch_image, snake, a, ICON)
        self.places = data["places"]
        self.tx = data["transport"]
        self.maps = {k: BaseMap(f"{page.slug(city)}-{k}", v["south"], v["west"], v["north"], v["east"], v["zoom"])
                     for k, v in data["maps"].items()}
        self.used_maps = set()
        self.photos = {}
        self.stays = {s["area"]: s for s in data["stays"]}

    # ── helpers ──────────────────────────────────────────────────────────
    def photo(self, place_id):
        if place_id in self.photos:
            return self.photos[place_id]
        p = self.places.get(place_id, {})
        src = None
        lm = self.landmarks.get(p.get("landmark") or "")
        if lm:
            snake = self.page.snake(lm["name"])
            iso3 = (re.findall(r"[A-Z]{3}", str(lm.get("countriesIsoA3") or "")) or [""])[0].lower()
            if iso3:
                src = self.page.fetch_image(f"new_countrydex%2F{iso3}_{snake}.webp", 480)
            if not src:
                src = self.page.fetch_image(f"countrydex%2F{snake}.jpg", 480)
        self.photos[place_id] = src
        return src

    def pt(self, place_id):
        p = self.places[place_id]
        return (p["lat"], p["lon"]) if "lat" in p else None

    def leg(self, frm, to, mode):
        """frm/to are (lat, lon) or None. Returns dict(mode, km, minutes, cost) or None."""
        if mode in ("pickup", "included"):
            return {"mode": mode, "km": None, "minutes": None, "cost": 0}
        if not frm or not to:
            return None
        km = km_between(frm, to) * self.tx["road_factor"]
        if km < 0.15:
            return None
        if mode in ("walk",):
            return {"mode": "walk", "km": km, "minutes": max(3, round(km / 4.5 * 60)), "cost": 0}
        if mode == "shuttle":
            return {"mode": "shuttle", "km": km, "minutes": max(5, round(km / 25 * 60) + 5), "cost": 0}
        taxi = self.tx["taxi"]
        airport = any(frm == self.pt(a) for a in self.airports)
        cost = max(taxi["min_fare"], (taxi["flag_airport"] if airport else taxi["flag_day"]) + taxi["per_km"] * km)
        return {"mode": "taxi", "km": km, "minutes": round(km / self.tx["city_kmh"] * 60) + 5, "cost": cost}

    def leg_html(self, lg, label=None):
        icon = {"taxi": "car", "walk": "walk", "shuttle": "bus", "bus": "bus", "pickup": "car", "included": "car"}[lg["mode"]]
        if lg["mode"] == "pickup":
            text = label or "Hotel pickup included"
        elif lg["mode"] == "included":
            text = label or "With the tour"
        else:
            name = {"taxi": "Taxi", "walk": "Walk", "shuttle": "Free shuttle", "bus": "Bus"}[lg["mode"]]
            bits = [label or name]
            if lg.get("km"):
                bits.append(f"{lg['km']:.0f} km" if lg["km"] >= 1.5 else f"{lg['km'] * 1000:.0f} m")
            if lg.get("minutes"):
                bits.append(f"≈ {dur(lg['minutes'])}")
            if lg.get("cost"):
                bits.append(f"≈ {fmt_aed(lg['cost'])}" + (" per person" if lg.get("per_person") else ""))
            text = " · ".join(bits)
        return f'<li class="leg leg-{lg["mode"]}"><span class="leg-ic" aria-hidden="true">{ICONS[icon]}</span><span>{e(text)}</span></li>'

    # ── stops ────────────────────────────────────────────────────────────
    def place_html(self, place_id, stop, n):
        p = self.places[place_id]
        img = self.photo(place_id)
        kind_icon = ICONS.get({"airport": "plane", "food": "food", "park": "ride", "tour": "desert", "activity": "kayak",
                               "transit": "bus", "show": "spark", "beach": "wave"}.get(p.get("kind"), "pin"))
        thumb = f'<img src="{img}" alt="">' if img else f'<span class="ph" aria-hidden="true">{kind_icon}</span>'
        quest = '<span class="quest-chip">Landmark quest</span>' if p.get("landmark") in self.landmarks else ""
        meta = []
        if stop.get("minutes"):
            meta.append(f"{stop['at']}–{hhmm_plus(stop['at'], stop['minutes'])}")
        else:
            meta.append(stop["at"])
        if p.get("price_text"):
            meta.append(e(p["price_text"]))
        note = stop.get("note") or p.get("tip")
        extra = []
        if p.get("hours"):
            extra.append(f'<span>Open {e(p["hours"])}</span>')
        if p.get("source"):
            extra.append(f'<a href="{e(p["source"])}" target="_blank" rel="noopener">Source</a>')
        num = f'<span class="num">{n}</span>' if n else ""
        return f"""<li class="stop">
          <div class="thumb">{thumb}{num}</div>
          <div class="stop-body">
            <p class="stop-meta">{' · '.join(meta)}</p>
            <h4>{e(p['name'])} {quest}</h4>
            {f'<p class="stop-note">{e(note)}</p>' if note else ''}
            {f'<p class="stop-extra">{" · ".join(extra)}</p>' if extra else ''}
          </div></li>"""

    def tour_html(self, stop, numbers):
        t = self.tours[stop["tour"]]
        usd = float(re.sub(r"[^0-9.]", "", t.get("price", "0")) or 0)
        aed = usd * self.usd_rate
        covers = []
        for pid in stop["covers"]:
            src = self.photo(pid)
            img = f'<img src="{src}" alt="">' if src else ICONS["pin"]
            quest = ' <span class="quest-chip">Landmark quest</span>' if self.places[pid].get("landmark") in self.landmarks else ""
            covers.append(f'<li><span class="mini">{img}<span class="num">{numbers[pid]}</span></span>'
                          f'<span>{e(self.places[pid]["name"])}{quest}</span></li>')
        covers = "".join(covers)
        rating = f'<span class="star">★</span> {t["rating"]} ({t.get("reviewCount", 0):,})' if t.get("rating") else ""
        end = hhmm_plus(stop["at"], stop["minutes"])
        return f"""<li class="stop tour-stop">
          <div class="tour-box">
            <p class="stop-meta">{stop['at']}–{end} · Guided tour · {e(t.get('provider', ''))}</p>
            <h4>{e(t['title'])}</h4>
            <p class="tour-facts">{rating} · {e(t.get('duration', ''))} · <b>{e(t.get('price', ''))}</b> ≈ {fmt_aed(aed)} per person</p>
            <ul class="covers">{covers}</ul>
            <p class="stop-note">{e(stop.get('note', ''))} {e(self.d.get("tour_note", "Check the tour page for which entry tickets are included."))}</p>
            {self.page.a(t['url'], f"Book this tour {self.page.ICON['arrow']}", "btn")}
          </div></li>"""

    # ── days and plans ───────────────────────────────────────────────────
    def day_html(self, plan, day, i):
        map_key = day.get("map", "city")
        hotel_area = day.get("hotel") or plan.get("stay_area")
        hotel = tuple(self.stays[hotel_area]["center"]) if hotel_area in self.stays and map_key == "city" else None

        items, points, modes = [], [], []
        numbers, n = {}, 0
        taxi_total, pp_total, tickets = 0.0, 0.0, 0.0
        prev_pt = None
        stops = day["stops"]

        if day.get("start"):
            s = day["start"]
            items.append(self.leg_html({"mode": s["mode"], "km": s["km"], "minutes": s["minutes"], "cost": s["cost"], "per_person": s.get("per_person")}, s["label"]))
            pp_total += s["cost"] if s.get("per_person") else 0

        for si, stop in enumerate(stops):
            first = si == 0
            if "tour" in stop:
                lg = self.leg(prev_pt, None, "pickup")
                items.append(self.leg_html(lg))
                cov_pts = []
                for pid in stop["covers"]:
                    n += 1
                    numbers[pid] = n
                    cov_pts.append(self.pt(pid))
                    points.append((*self.pt(pid), n))
                    modes.append("included")
                items.append(self.tour_html(stop, numbers))
                t = self.tours[stop["tour"]]
                tickets += float(re.sub(r"[^0-9.]", "", t.get("price", "0")) or 0) * self.usd_rate
                prev_pt = cov_pts[-1]
                continue

            pid = stop["place"]
            p = self.places[pid]
            cur = self.pt(pid) if p.get("map", "city") == map_key else None
            mode = stop.get("by", "taxi")
            origin = prev_pt if prev_pt else (None if pid in self.airports or mode == "pickup" else hotel)
            if first and origin is hotel and hotel and mode != "pickup":
                lg = self.leg(hotel, cur, "taxi")
                if lg:
                    items.append(self.leg_html(lg, "Taxi from your hotel"))
                    taxi_total += lg["cost"]
            elif not first or mode == "pickup":
                lg = self.leg(origin, cur, mode)
                if lg:
                    items.append(self.leg_html(lg))
                    taxi_total += lg["cost"] if lg["mode"] == "taxi" else 0

            label_n = None
            if cur:
                same = points and abs(points[-1][0] - cur[0]) < 1e-4 and abs(points[-1][1] - cur[1]) < 1e-4
                if same:
                    label_n = points[-1][2]
                else:
                    n += 1
                    label_n = n
                    points.append((*cur, n))
                    modes.append(mode)
            items.append(self.place_html(pid, stop, label_n))
            if isinstance(p.get("price"), (int, float)):
                tickets += p["price"]
            prev_pt = cur or prev_pt

        last = stops[-1]
        if hotel and last.get("place") not in self.airports and not day.get("end") and prev_pt and last.get("by") != "pickup":
            lg = self.leg(prev_pt, hotel, "taxi")
            if lg:
                items.append(self.leg_html(lg, "Taxi back to your hotel"))
                taxi_total += lg["cost"]
        if day.get("end"):
            s = day["end"]
            items.append(self.leg_html({"mode": s["mode"], "km": s["km"], "minutes": s["minutes"], "cost": s["cost"], "per_person": s.get("per_person")}, s["label"]))
            pp_total += s["cost"] if s.get("per_person") else 0

        # modes[k] is how we reached point k; the line from k to k+1 uses modes[k+1]
        line_modes = modes[1:] + [None]
        svg = self.maps[map_key].day_svg(points, f"Day {i} route map", line_modes) if len(points) >= 1 else ""
        self.used_maps.add(map_key)
        cost = f"Tickets ≈ {fmt_aed(tickets)} pp · taxis ≈ {fmt_aed(taxi_total)}" + (f" · bus {fmt_aed(pp_total)} pp" if pp_total else "")
        return (f"""<article class="day">
          <header class="day-head"><span class="day-n">Day {i}</span><h3>{e(day['title'])}</h3><span class="day-cost">{cost}</span></header>
          <div class="day-body">
            <figure class="map">{svg}<figcaption>Approximate route · map © OpenStreetMap contributors</figcaption></figure>
            <ol class="timeline">{''.join(items)}</ol>
          </div></article>""", tickets, taxi_total, pp_total)

    def plan_html(self, plan):
        days, t_tot, x_tot, pp_tot = [], 0, 0, 0
        for i, day in enumerate(plan["days"], 1):
            h, t, x, pp = self.day_html(plan, day, i)
            days.append(h)
            t_tot += t
            x_tot += x
            pp_tot += pp
        stay = self.stays.get(plan.get("stay_area"))
        budget = [("Tickets & tours", f"≈ {fmt_aed(t_tot + pp_tot)}", "per person")]
        budget.append(("Taxis", f"≈ {fmt_aed(x_tot)}", "per taxi, up to 4 people"))
        if plan["nights"] and stay:
            lo, hi = stay["range"]
            budget.append(("Hotel", f"{fmt_aed(lo * plan['nights'])}–{fmt_aed(hi * plan['nights']).replace(f'{CURRENCY} ', '')}",
                           f"{plan['nights']} night{'s' if plan['nights'] > 1 else ''} · {stay['area']}"))
        budget_html = "".join(f"<div><dt>{e(k)}</dt><dd>{e(v)}</dd><small>{e(s)}</small></div>" for k, v, s in budget)
        length = self.lengths[plan["length"]]
        style = self.styles[plan["style"]]
        rec = '<span class="rec">★ Recommended length</span>' if length.get("recommended") else ""
        stay_line = ""
        if stay:
            stay_line = f'<p class="stay-line"><b>Stay:</b> {e(plan.get("stay_note") or stay["area"] + ". " + stay["why"])}</p>'
        return f"""<div class="plan" id="plan-{plan['id']}" data-length="{plan['length']}" data-style="{plan['style']}" {'' if plan.get('_first') else 'hidden'}>
          <div class="plan-head"><p class="plan-kicker">{e(length['label'])} · {e(style['label'])} {rec}</p><p>{e(plan['for'])}</p>{stay_line}
            <dl class="budget">{budget_html}</dl></div>
          {''.join(days)}
        </div>"""

    def render(self, custom_html=""):
        """custom_html: the "My dates" planner (planner.py). It sits next to the trip lengths as one more
        option: the same plans, built around the traveler's own arrival and departure times."""
        # Show trip lengths only up to the recommended length + 1 day; longer plans pad the city out.
        rec_idx = next((i for i, x in enumerate(self.d["lengths"]) if x.get("recommended")), 0)
        self.d["lengths"] = self.d["lengths"][:rec_idx + 2]
        allowed = {x["id"] for x in self.d["lengths"]}
        self.d["plans"] = [p for p in self.d["plans"] if p["length"] in allowed]
        plans = self.d["plans"]
        self.lengths = {x["id"]: x for x in self.d["lengths"]}
        self.styles = {x["id"]: x for x in self.d["styles"]}
        rec_len = next((x["id"] for x in self.d["lengths"] if x.get("recommended")), self.d["lengths"][0]["id"])
        first_style = self.d["styles"][0]["id"]
        for p in plans:
            p["_first"] = p["length"] == rec_len and p["style"] == first_style
        len_btns = "".join(
            f'<button type="button" data-length="{x["id"]}" aria-pressed="{str(x["id"] == rec_len).lower()}"'
            f' class="{"is-rec" if x.get("recommended") else ""}">{"★ " if x.get("recommended") else ""}{e(x["label"])}</button>'
            for x in self.d["lengths"])
        style_btns = "".join(
            f'<button type="button" data-style="{x["id"]}" aria-pressed="{str(x["id"] == first_style).lower()}">'
            f'<b>{e(x["label"])}</b><span>{e(x["blurb"])}</span></button>'
            for x in self.d["styles"])
        panels = "".join(self.plan_html(p) for p in plans)
        teaser = ""
        if custom_html:
            len_btns += '<button type="button" data-length="custom" aria-pressed="false" class="is-custom">✦ My dates</button>'
            panels += f'<div class="plan" id="plan-custom" data-length="custom" data-style="any" hidden>{custom_html}</div>'
            teaser = ('<button type="button" class="custom-teaser" id="open-custom"><span class="spark" aria-hidden="true">✦</span>'
                      '<span><b>Plan around your own flights</b><small>Enter your real arrival and departure times. We check the '
                      'season, closures and hotel prices for those dates, and AI builds the days.</small></span>'
                      '<span class="cta">Try it →</span></button>')
        defs = "".join(self.maps[k].defs() for k in self.used_maps)
        notes = "".join(f"<li>{e(_text(n))}</li>" for n in self.tx["notes"])
        stays = "".join(f'<li><b>{e(s["area"])}</b> · ≈ {fmt_aed(s["range"][0])}–{s["range"][1]:,} a night<br><span>{e(s["why"])}</span></li>'
                        for s in self.d["stays"])
        more = "".join(f"<li>{e(_text(m))}</li>" for m in self.d.get("more_time", []))
        food = "".join(f"<li>{e(_text(m))}</li>" for m in self.d.get("food", []))
        used = {st.get("place") for pl in plans for dy in pl["days"] for st in dy["stops"]}
        used |= {c for pl in plans for dy in pl["days"] for st in dy["stops"] for c in st.get("covers", [])}
        srcs = {}
        for pid, p in self.places.items():
            if p.get("source") and pid in used:
                srcs[p["source"]] = p["name"]
        for name, url in self.tx.get("sources", []):
            srcs[url] = name
        src_html = "".join(f'<li><a href="{e(u)}" target="_blank" rel="noopener">{e(n)}</a></li>' for u, n in srcs.items())
        return f"""{defs}
  <section aria-labelledby="h-plans" class="plans">
    <h2 id="h-plans">Plans</h2>
    <p class="muted">{e(self.d.get("intro", "Pick how long you have and what you enjoy most."))} Prices checked {e(self.d['checked'])}; ≈ marks estimates.</p>
    <div class="picker">
      <p class="pick-label" id="lbl-len">How long?</p>
      <div class="tabs" role="group" aria-labelledby="lbl-len">{len_btns}</div>
      {teaser}
      <div class="style-pick"><p class="pick-label" id="lbl-style">What do you enjoy most?</p>
      <div class="styles" role="group" aria-labelledby="lbl-style">{style_btns}</div></div>
    </div>
    <div aria-live="polite">{panels}</div>
    <div class="aside-grid">
      <div class="aside"><h3>Swap in instead</h3><ul>{more}</ul></div>
      <div class="aside"><h3>Getting around</h3><ul>{notes}</ul></div>
      <div class="aside"><h3>Where to stay</h3><ul class="stays">{stays}</ul></div>
      {f'<div class="aside"><h3>Food &amp; drink</h3><ul>{food}</ul></div>' if food else ''}
    </div>
    <!--TIPS-->
    <details class="sources"><summary>Sources for prices and hours</summary><ul>{src_html}</ul>
      <p class="muted">Taxi costs are estimates from straight-line distance and the metered fare. Map positions are approximate.</p></details>
  </section>"""


def _text(x):
    """DeepSeek sometimes returns {"title": ..., "text": ...} instead of a plain tip line."""
    if isinstance(x, dict):
        vals = [str(v) for v in x.values() if isinstance(v, (str, int, float)) and str(v).strip()]
        return vals[0] + (": " + " ".join(vals[1:]) if len(vals) > 1 else "") if vals else ""
    return str(x)


ICONS = {
    "car": '<svg viewBox="0 0 24 24"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11v7h-2v-2H7v2H5zm2.2-1h9.6l-1-3H8.2zM7.5 14a1.25 1.25 0 1 0 0-2.5 1.25 1.25 0 0 0 0 2.5m9 0a1.25 1.25 0 1 0 0-2.5 1.25 1.25 0 0 0 0 2.5"/></svg>',
    "walk": '<svg viewBox="0 0 24 24"><path d="M13.5 5.5a2 2 0 1 0 0-4 2 2 0 0 0 0 4M9.8 8.9 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3A7.3 7.3 0 0 0 19 13v-2a5 5 0 0 1-4.4-2.4l-1-1.6a2 2 0 0 0-1.7-1c-.3 0-.5 0-.8.1L6 8.3V13h2V9.6z"/></svg>',
    "bus": '<svg viewBox="0 0 24 24"><path d="M4 16c0 .9.4 1.7 1 2.2V20a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h8v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1.8c.6-.5 1-1.3 1-2.2V6c0-3.5-3.6-4-8-4S4 2.5 4 6zm3.5 1a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3m9 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3M6 11V6h12v5z"/></svg>',
    "plane": '<svg viewBox="0 0 24 24"><path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/></svg>',
    "food": '<svg viewBox="0 0 24 24"><path d="M8 2v9a2 2 0 0 1-1 1.7V22H5v-9.3A2 2 0 0 1 4 11V2h1v6h1V2h1v6h1V2zm8 0c2 0 3 2.5 3 6v5h-2v9h-2V2z"/></svg>',
    "ride": '<svg viewBox="0 0 24 24"><path d="M2 18c4-10 7-12 10-12s6 2 10 12h-2.2C17 11 14.6 8 12 8s-5 3-7.8 10zm9-6h2v8h-2z"/></svg>',
    "desert": '<svg viewBox="0 0 24 24"><path d="M17 4a3 3 0 1 1 0 6 3 3 0 0 1 0-6M2 19c3-4 6-6 10-6s7 2 10 6z"/></svg>',
    "kayak": '<svg viewBox="0 0 24 24"><path d="M2 15c4 2 16 2 20 0l-2 3c-3 1.5-13 1.5-16 0zM16.5 3 18 4.5 7.5 15 6 13.5z"/></svg>',
    "spark": '<svg viewBox="0 0 24 24"><path d="m12 2 2.4 7.6L22 12l-7.6 2.4L12 22l-2.4-7.6L2 12l7.6-2.4z"/></svg>',
    "wave": '<svg viewBox="0 0 24 24"><path d="M2 17c2 0 3-1.5 5-1.5S10 17 12 17s3-1.5 5-1.5 3 1.5 5 1.5v2c-2 0-3-1.5-5-1.5S14 19 12 19s-3-1.5-5-1.5S4 19 2 19zm10-13a5 5 0 0 1 5 5h-2a3 3 0 0 0-6 0H7a5 5 0 0 1 5-5"/></svg>',
    "pin": '<svg viewBox="0 0 24 24"><path d="M12 2a7 7 0 0 1 7 7c0 5-7 13-7 13S5 14 5 9a7 7 0 0 1 7-7m0 4.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5"/></svg>',
}

CSS = """
.plans h3 { font: 800 18px/1.25 var(--font-display); margin: 0; }
.tabs { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 2px; }
.tabs button { font: 600 14px var(--font-body); color: var(--ink); background: var(--surface); border: 1px solid var(--line);
  border-radius: 999px; padding: 8px 14px; white-space: nowrap; cursor: pointer; }
.tabs button[aria-pressed="true"] { background: var(--ink); border-color: var(--ink); color: var(--bg); }
.tabs button.is-rec:not([aria-pressed="true"]) { border-color: var(--accent); color: var(--accent); }
.tabs button:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
.picker { display: flex; flex-direction: column; gap: 8px; }
.pick-label { margin: 6px 0 0; font-size: 12px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.styles { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.styles button { text-align: left; font: inherit; color: var(--ink); background: var(--surface); border: 1px solid var(--line);
  border-radius: 14px; padding: 10px 12px; display: flex; flex-direction: column; gap: 2px; cursor: pointer; min-width: 0; }
.styles button b { font-size: 14px; }
.styles button span { font-size: 12px; color: var(--muted); }
.styles button[aria-pressed="true"] { border: 2px solid var(--accent); background: var(--accent-soft); padding: 9px 11px; }
.styles button:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
@media (max-width: 520px) { .styles { grid-template-columns: 1fr; } }
.plan-kicker { font-size: 13px; font-weight: 700; color: var(--accent); display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.plan { display: flex; flex-direction: column; gap: 16px; }
.plan[hidden] { display: none; }
.plan-head { display: flex; flex-direction: column; gap: 8px; }
.plan-head p { margin: 0; }
.rec { align-self: flex-start; font-size: 12px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--accent-ink);
  background: var(--accent); padding: 4px 10px; border-radius: 999px; }
.stay-line { font-size: 14px; color: var(--muted); }
.budget { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1px; margin: 4px 0 0;
  background: var(--line); border: 1px solid var(--line); border-radius: 14px; overflow: hidden; }
.budget div { background: var(--surface); padding: 10px 12px; min-width: 0; }
.budget dt { font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.budget dd { margin: 2px 0 0; font: 800 18px/1.25 var(--font-display); font-variant-numeric: tabular-nums; }
.budget small { font-size: 12px; color: var(--muted); }

.day { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; overflow: hidden; }
.day-head { display: grid; grid-template-columns: auto 1fr; gap: 2px 10px; align-items: baseline; padding: 14px 16px; border-bottom: 1px solid var(--line); }
.day-n { font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--accent); }
.day-cost { grid-column: 1 / -1; font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; }
.day-body { display: flex; flex-direction: column; }
.map { margin: 0; position: relative; }
.daymap { display: block; overflow: hidden; width: 100%; height: auto; aspect-ratio: 1.6; background: var(--bg); }
.map-base { filter: var(--map-filter); }
.route { stroke: var(--accent); fill: none; stroke-linecap: round; opacity: .9; }
.pin { fill: var(--accent); stroke: var(--surface); }
.pin-n { fill: var(--accent-ink); font-family: var(--font-body); font-weight: 800; text-anchor: middle; }
.map figcaption { position: absolute; right: 8px; bottom: 6px; font-size: 10px; color: var(--muted); background: var(--surface); padding: 1px 6px; border-radius: 6px; opacity: .9; }

.timeline { list-style: none; margin: 0; padding: 12px 16px 16px; display: flex; flex-direction: column; gap: 4px; }
.stop { display: grid; grid-template-columns: 76px 1fr; gap: 12px; padding: 8px 0; }
.thumb { position: relative; width: 76px; height: 64px; }
.thumb img, .thumb .ph, .thumb .pic { width: 72px; height: 72px; aspect-ratio: 1; border-radius: 12px; object-fit: cover; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent); }
.num { position: absolute; left: -6px; top: -6px; min-width: 22px; height: 22px; border-radius: 999px; display: grid; place-items: center;
  background: var(--accent); color: var(--accent-ink); font-size: 12px; font-weight: 800; border: 2px solid var(--surface); }
.stop-body { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.stop-meta { margin: 0; font-size: 13px; font-weight: 600; color: var(--muted); font-variant-numeric: tabular-nums; }
.stop h4 { margin: 0; font-size: 16px; font-weight: 700; line-height: 1.3; }
.stop-note { margin: 2px 0 0; font-size: 14px; }
.stop-extra { margin: 2px 0 0; font-size: 12px; color: var(--muted); }
.stop-extra a { color: var(--muted); }
.quest-chip { display: inline-block; font-size: 11px; font-weight: 700; color: var(--accent); background: var(--accent-soft); padding: 1px 7px; border-radius: 999px; vertical-align: 2px; }
.leg { display: flex; align-items: center; gap: 8px; margin-left: 27px; padding: 6px 0 6px 22px; border-left: 2px dashed var(--line); font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; }
.leg-ic svg { width: 16px; height: 16px; }
.tour-stop { grid-template-columns: 1fr; }
.tour-box { border: 2px solid var(--accent); border-radius: 16px; padding: 14px; display: flex; flex-direction: column; gap: 8px; background: var(--accent-soft); }
.tour-box h4 { font-size: 17px; }
.tour-facts { margin: 0; font-size: 14px; font-variant-numeric: tabular-nums; }
.covers { list-style: none; margin: 4px 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.covers li { display: flex; align-items: center; gap: 10px; font-weight: 600; font-size: 14px; }
.mini { position: relative; width: 56px; height: 44px; flex: none; }
.mini img, .mini svg, .mini .pic { width: 48px; height: 48px; aspect-ratio: 1; border-radius: 10px; object-fit: cover; background: var(--surface); color: var(--accent); }
.mini .num { left: -6px; top: -6px; }
.tour-box .btn { align-self: flex-start; }

.aside-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
.aside { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 14px 16px; min-width: 0; }
.aside ul { margin: 8px 0 0; padding-left: 18px; display: flex; flex-direction: column; gap: 6px; font-size: 14px; }
.stays { list-style: none; padding-left: 0 !important; }
.stays span { color: var(--muted); font-size: 13px; }
.sources { font-size: 14px; }
.sources summary { cursor: pointer; font-weight: 600; }
.sources ul { padding-left: 18px; columns: 2 220px; }
.sources a { color: var(--muted); }
"""

JS = """
<script>
(() => {
  const lens = [...document.querySelectorAll('.tabs [data-length]')];
  const styles = [...document.querySelectorAll('.styles [data-style]')];
  const plans = [...document.querySelectorAll('.plan')];
  const state = {
    length: (lens.find((b) => b.getAttribute('aria-pressed') === 'true') || lens[0]).dataset.length,
    style: (styles.find((b) => b.getAttribute('aria-pressed') === 'true') || styles[0]).dataset.style,
  };
  const stylePick = document.querySelector('.style-pick');
  const teaser = document.getElementById('open-custom');
  const render = () => {
    const custom = state.length === 'custom';
    lens.forEach((b) => b.setAttribute('aria-pressed', b.dataset.length === state.length));
    styles.forEach((b) => b.setAttribute('aria-pressed', b.dataset.style === state.style));
    plans.forEach((p) => { p.hidden = custom ? p.dataset.length !== 'custom' : !(p.dataset.length === state.length && p.dataset.style === state.style); });
    if (stylePick) stylePick.hidden = custom;
    if (teaser) teaser.hidden = custom;
    if (custom) document.dispatchEvent(new CustomEvent('tripplans:custom', { detail: { style: state.style } }));
  };
  const remember = () => { try { history.replaceState(null, '', '#' + (state.length === 'custom' ? 'custom' : state.length + '-' + state.style)); } catch (_) {} };
  lens.forEach((b) => b.addEventListener('click', () => { state.length = b.dataset.length; render(); remember(); }));
  styles.forEach((b) => b.addEventListener('click', () => { state.style = b.dataset.style; render(); remember(); }));
  if (teaser) teaser.addEventListener('click', () => { state.length = 'custom'; render(); remember(); });
  const m = location.hash.slice(1).match(/^([a-z0-9]+)-([a-z]+)$/);
  window.addEventListener('hashchange', () => {
    if (location.hash === '#custom' && document.getElementById('plan-custom')) {
      state.length = 'custom'; render(); document.getElementById('h-plans').scrollIntoView({ block: 'start' });
    }
  });
  if (location.hash === '#custom' && document.getElementById('plan-custom')) { state.length = 'custom'; render(); }
  else if (m && document.getElementById('plan-' + m[1] + '-' + m[2])) { state.length = m[1]; state.style = m[2]; render(); }
})();
</script>"""
