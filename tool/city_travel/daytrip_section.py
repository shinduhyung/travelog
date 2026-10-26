"""Day trips section for build_page.py, from daytrips/<slug>.json (made by daytrips.py).

Placed right after "Tours & activities". Cities with no file or 0 trips get no section.
Quest landmarks open the shared landmark sheet (data-lm); render() returns the landmark records
the sheet needs that are not already in the city's own landmark set.
"""
import html
import json
import re
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Train/bus booking links. Swap for the Travelog Impact deep link when it is approved:
# Impact tracking link for Omio (media property travelogapp.uk); {u} = url-encoded Omio route URL.
OMIO_WRAP = "https://omio.sjv.io/c/7592796/409973/7385?u={u}"
GYG_PARAMS = "partner_id=EMZVISH&utm_medium=online_publisher"
SYMBOL = {"EUR": "€", "JPY": "¥", "USD": "$", "GBP": "£"}
MODE_LABEL = {"train": "Train", "bus": "Bus", "car": "Car", "taxi": "Taxi", "tour": "Day tour"}


def omio(url):
    return OMIO_WRAP.format(raw=url, u=urllib.parse.quote(url, safe=""))


def gyg(path_or_url):
    url = path_or_url if path_or_url.startswith("http") else "https://www.getyourguide.com" + path_or_url
    return url + ("&" if "?" in url else "?") + GYG_PARAMS


def _min(s):
    if not s:
        return None
    h, m = re.search(r"(\d+)h", s), re.search(r"(\d+)m", s)
    return (int(h.group(1)) if h else 0) * 60 + (int(m.group(1)) if m else 0)


def _hm(m):
    return f"{m // 60} h {m % 60:02d}" if m >= 60 else f"{m} min"


def _money(amount, cur):
    sym = SYMBOL.get(cur)
    n = f"{amount:,.0f}"
    return f"≈ {sym}{n}" if sym else f"≈ {n} {cur}"


def _tour(city, slug, trip):
    """Only a GYG day tour that was checked by hand to go from this city to this place (trip["tour"])."""
    v = trip.get("tour")
    if not v:
        return None, None, None, None, None
    return gyg(v["u"]), v["t"], v.get("r"), v.get("n"), v.get("p")


def render(city, slug, lm_by_name, photo, icon):
    p = HERE / "daytrips" / f"{slug}.json"
    if not p.exists():
        return "", []
    trips = json.loads(p.read_text(encoding="utf-8")).get("trips", [])
    if not trips:
        return "", []
    e = html.escape
    cards, used = [], []
    for t in trips:
        rec, modes, road = t["recommended"], t["modes"], t["road"]
        rm = _min(modes.get(rec, {}).get("time"))
        head = f"{_hm(rm)} by {rec}" if rm else f"{_hm(road['min'])} by road"
        # Each row: mode, time and price only; the arrow opens the booking page.
        go = lambda url, label: (f'<a class="dt-go" href="{e(url)}" target="_blank" rel="noopener sponsored" '
                                 f'aria-label="{label}">{icon["arrow"]}</a>')
        omio_train = (modes.get("train") or {}).get("source", "")
        rows = []
        for k in ("train", "bus"):
            m = modes.get(k)
            if not m:
                continue
            bits = [_hm(_min(m["time"])) if _min(m["time"]) else e(m["time"])]
            if m.get("from"):
                bits.append(f"from {e(m['from'])}")
            src = m.get("source", "")
            if "omio.com" not in src and "omio.com/trains/" in omio_train:
                src = omio_train.replace("/trains/", "/buses/" if k == "bus" else "/trains/")   # same route, bus page
            rows.append((k, " · ".join(bits), go(omio(src), f"Book {k} on Omio") if "omio.com" in src else ""))
        taxi = t["taxi"]
        rows.append(("car", f"{_hm(road['min'])} · taxi {_money(taxi['amount'], taxi['currency'])}", ""))
        turl, _, _, _, tprice = _tour(city, slug, t)
        if turl:
            rows.append(("tour", f"{e(t.get('visit', 'Full day'))}" + (f" · from ${tprice}" if tprice else ""), go(turl, "See the day tour")))
        if rec == "taxi":
            rec = "car"
        tr = "".join(f'<li><b>{MODE_LABEL[k]}{' <span class="dt-best" title="Best way">★</span>' if k == rec else ""}</b>'
                     f'<span>{txt}</span>{btn}</li>' for k, txt, btn in rows)
        see = "".join(f"<li>{e(s)}</li>" for s in t["see"])
        quests = [n for n in t["quests"] if n in lm_by_name]
        used += quests
        thumbs = ""
        if quests:
            items = []
            for n in quests:
                src = photo(n)
                img = f'<img src="{src}" alt="">' if src else f'<span class="ph" aria-hidden="true">{icon["mountain"]}</span>'
                items.append(f'<button type="button" class="dt-lm" data-lm="{e(n)}"><figure>{img}<figcaption>{e(n)}</figcaption></figure></button>')
            thumbs = (f'<p class="quest">{icon["flag"]} {len(quests)} landmark quest{"s" if len(quests) > 1 else ""} to check off here</p>'
                      f'<div class="thumbs">{"".join(items)}</div>')
        cards.append(f"""
        <article class="tour dtrip">
          <h3>{e(t['place'])}{f' ({e(t["label"])})' if t.get('label') else ''} · {head}</h3>
          <p class="meta">{f'<span class="star" aria-label="{t["stars"]} out of 5">{"★" * t["stars"]}{"☆" * (5 - t["stars"])}</span> · ' if t.get("stars") else ''}{e(t.get('visit', 'Full day'))} · {road['km']} km from {e(city)}</p>
          {f'<p class="dt-why"><b>Best way:</b> {e(t["why"])}</p>' if t.get("why") else ''}
          {f'<p class="dt-note">{e(t["route_note"])}</p>' if t.get("route_note") else ''}
          <ul class="dt-modes">{tr}</ul>
          {f'<h4 class="dt-h">What to see</h4><ul class="why">{see}</ul>' if see else ''}
          {thumbs}
          {f'<h4 class="dt-h">Good to know</h4><ul class="dt-know">{"".join(f"<li>{e(k)}</li>" for k in t.get("know", []))}</ul>' if t.get("know") else ''}
        </article>""")
    out = f"""
  <section aria-labelledby="h-daytrips"><h2 id="h-daytrips">Day trips from {e(city)}</h2>
    {''.join(cards)}
    <p class="muted dt-foot">Times and prices are typical one-way estimates (train and bus: Omio / Rome2Rio route data; taxi: local tariff × road distance, tolls extra). Exact prices are on the booking page.</p>
  </section>"""
    return out, list(dict.fromkeys(used))


CSS = """
.dtrip { gap: 10px; min-width: 0; max-width: 100%; }
.dtrip .thumbs { max-width: 100%; }
.dt-why, .dt-note { margin: 0; font-size: 14px; }
.dt-note { color: var(--muted); }
.dt-h { margin: 4px 0 0; font-size: 14px; font-weight: 700; }
.dt-modes { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }
.dt-modes li { display: grid; grid-template-columns: 92px 1fr auto; align-items: center; gap: 4px 10px; padding: 10px 12px; font-size: 14px; border-top: 1px solid var(--line); }
.dt-modes li:first-child { border-top: 0; }
.dt-best, .tr-best { color: var(--star); }
.dt-modes span { min-width: 0; overflow-wrap: anywhere; font-variant-numeric: tabular-nums; }
.dt-go { display: grid; place-items: center; width: 36px; height: 36px; border-radius: 50%; border: 1px solid var(--accent); color: var(--accent); }
.dt-go svg { width: 18px; height: 18px; }
.dt-go:hover { background: var(--accent); color: var(--accent-ink); }
.dt-modes .btn.ghost { background: transparent; color: var(--accent); border: 1px solid var(--accent); }
@media (max-width: 420px) { .dt-modes li { grid-template-columns: 1fr auto; } .dt-modes li span { grid-column: 1 / -1; grid-row: 2; } }
.dt-lm { all: unset; cursor: pointer; flex: none; }
.dt-lm:focus-visible { outline: 2px solid var(--accent); border-radius: 12px; }
.dt-know { margin: 0; padding-left: 18px; font-size: 14px; display: flex; flex-direction: column; gap: 4px; }
.dt-foot { font-size: 12px; margin: 0; }
"""
