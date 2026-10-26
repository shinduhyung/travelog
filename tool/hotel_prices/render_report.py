"""Render data/<city>/report.json (+ the latest price calendars) as a standalone HTML page to eyeball.

Usage (from the repo root, after analyze_prices.py):
    python tool/hotel_prices/render_report.py --city "Abu Dhabi"
Writes data/<city>/report.html (self-contained, opens from disk).
"""

import argparse
import datetime as dt
import glob
import html
import json
import os
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
CHART_DAYS = 90

# Same Hotels.com affiliate format as city_travel_modal.dart (_expediaGroupAffiliateUrl).
HOTELS_COM_CAMREF = "1011l6uqXc"
HOTELS_COM_CREATIVEREF = "1011l66481"

COLORS = {
    "green": ("#0f766e", "#ccfbf1", "Good price now"),
    "neutral": ("#475569", "#e2e8f0", "Typical price"),
    "red": ("#b91c1c", "#fee2e2", "Pricier than usual"),
    "unknown": ("#64748b", "#f1f5f9", "Not enough data"),
}


def slug(city):
    return city.lower().replace(" ", "_")


def hotels_com_url(title, city):
    landing = "https://www.hotels.com/Hotel-Search?destination=" + urllib.parse.quote(f"{title}, {city}")
    return (f"https://www.hotels.com/affiliate?landingPage={urllib.parse.quote(landing, safe='')}"
            f"&camref={HOTELS_COM_CAMREF}&creativeref={HOTELS_COM_CREATIVEREF}")


def sparkline(calendar, start, mark_date, w=300, h=56):
    days = [(start + dt.timedelta(d)).isoformat() for d in range(CHART_DAYS)]
    pts = [(i, calendar[d]) for i, d in enumerate(days) if d in calendar]
    if len(pts) < 2:
        return '<div class="nochart">No calendar data</div>'
    lo, hi = min(p for _, p in pts), max(p for _, p in pts)
    span = (hi - lo) or 1
    xy = lambda i, p: (round(i * w / (CHART_DAYS - 1), 1), round(h - 6 - (p - lo) * (h - 12) / span, 1))
    path = " ".join(f"{'M' if k == 0 else 'L'}{x},{y}" for k, (x, y) in enumerate(xy(i, p) for i, p in pts))
    mark = ""
    if mark_date in days and mark_date in calendar:
        mx, my = xy(days.index(mark_date), calendar[mark_date])
        mark = f'<circle cx="{mx}" cy="{my}" r="3.5" class="mark"/>'
    return (f'<svg viewBox="0 0 {w} {h}" class="spark" preserveAspectRatio="none">'
            f'<path d="{path}" class="line"/>{mark}</svg>'
            f'<div class="axis"><span>{days[0][5:]}</span><span>low ${lo} · high ${hi}</span><span>{days[-1][5:]}</span></div>')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--city", required=True)
    args = ap.parse_args()
    folder = os.path.join(HERE, "data", slug(args.city))
    with open(os.path.join(folder, "report.json"), encoding="utf-8") as f:
        report = json.load(f)
    latest = sorted(glob.glob(os.path.join(folder, "????-??-??.json")))[-1]
    with open(latest, encoding="utf-8") as f:
        calendars = {h["hotel_identifier"]: h.get("prices_by_dates", {}) for h in json.load(f)["hotels"]}
    start = dt.date.fromisoformat(report["latest_snapshot"])
    e = html.escape

    cards = []
    for r in report["hotels"]:
        fg, bg, label = COLORS[r["color"]]
        loc = r.get("location") or {}
        trend = r.get("trend")
        trend_txt = f"{trend['change_pct']:+.0f}% since {trend['first_seen'][5:]}" if trend else "needs a 2nd day"
        peers = r.get("vs_peers_pct")
        peers_txt = "-" if peers is None else (f"{abs(peers):.0f}% {'below' if peers < 0 else 'above'} {r['stars']}★ median")
        deals = "".join(f'<span class="chip">{e(d["date"][5:])} · ${d["price"]}</span>' for d in r["cheapest_nights"])
        sights = ", ".join(f"{e(s['name'])} {s['km']}km" for s in loc.get("nearest_sights", [])[:2])
        pos = r["position"]
        cards.append(f"""
<article class="card">
  <header>
    <span class="badge" style="color:{fg};background:{bg}">{label}</span>
    <h2>{e(r['title'])}</h2>
    <div class="sub">{'★' * (r['stars'] or 0)} · {r['rating'] or '-'} ({(r['votes'] or 0):,} reviews){' · ' + e(loc['area']) if loc.get('area') else ''}</div>
  </header>
  <div class="row">
    <div class="price"><b>${r['price'] if r['price'] is not None else '-'}</b><span>night of {e(r['date'][5:])}</span></div>
    <div class="pos">
      <div class="bar"><i style="left:{pos if pos is not None else 50}%;background:{fg}"></i></div>
      <div class="barlabels"><span>cheapest</span><span>{'' if pos is None else f'{pos}% of same weekdays'}</span><span>priciest</span></div>
    </div>
  </div>
  <dl>
    <div><dt>Trend</dt><dd>{trend_txt}</dd></div>
    <div><dt>vs peers</dt><dd>{peers_txt}</dd></div>
    <div><dt>Location</dt><dd><b>{loc.get('score', '-')}</b>/10 <small>{sights}</small></dd></div>
  </dl>
  {sparkline(calendars.get(r['hotel_identifier'], {}), start, r['date'])}
  <div class="deals"><span class="dl">Cheapest next 90 days</span>{deals or '<span class="chip">-</span>'}</div>
  <a class="cta" href="{e(hotels_com_url(r['title'], args.city))}" target="_blank" rel="noopener">View on Hotels.com →</a>
</article>""")

    counts = {c: sum(1 for r in report["hotels"] if r["color"] == c) for c in COLORS}
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>{e(args.city)} Hotel Prices</title>
<style>
:root{{--bg:#f8fafc;--card:#fff;--line:#e2e8f0;--text:#0f172a;--muted:#64748b;--accent:#1ABFBC}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 -apple-system,"Segoe UI",sans-serif}}
.top{{padding:20px 16px 8px;max-width:1200px;margin:0 auto}} h1{{margin:0;font-size:22px}}
.meta{{color:var(--muted);margin-top:4px}} .legend{{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}}
.legend span{{padding:3px 10px;border-radius:999px;font-size:12px;font-weight:600}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:12px;padding:12px 16px 32px;max-width:1200px;margin:0 auto}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px}}
.badge{{font-size:11px;font-weight:700;padding:3px 9px;border-radius:999px}} h2{{font-size:16px;margin:6px 0 2px}}
.sub{{color:var(--muted);font-size:12px}} .row{{display:flex;gap:14px;align-items:center}}
.price b{{font-size:22px;display:block}} .price span{{font-size:11px;color:var(--muted)}}
.pos{{flex:1}} .bar{{position:relative;height:8px;border-radius:4px;background:linear-gradient(90deg,#99f6e4,#e2e8f0 50%,#fecaca)}}
.bar i{{position:absolute;top:-3px;width:14px;height:14px;border-radius:50%;border:2px solid #fff;transform:translateX(-50%);box-shadow:0 1px 3px rgba(0,0,0,.3)}}
.barlabels{{display:flex;justify-content:space-between;font-size:10px;color:var(--muted);margin-top:4px}}
dl{{margin:0;display:grid;grid-template-columns:1fr 1fr 1.4fr;gap:8px}} dl div{{background:var(--bg);border-radius:8px;padding:6px 8px}}
dt{{font-size:10px;color:var(--muted);text-transform:uppercase}} dd{{margin:0;font-size:12px}} dd small{{display:block;color:var(--muted);font-size:10px}}
.spark{{width:100%;height:56px}} .line{{fill:none;stroke:var(--accent);stroke-width:1.6}} .mark{{fill:#0f172a}}
.axis{{display:flex;justify-content:space-between;font-size:10px;color:var(--muted)}} .nochart{{font-size:12px;color:var(--muted)}}
.deals{{display:flex;flex-wrap:wrap;gap:6px;align-items:center}} .dl{{font-size:11px;color:var(--muted);margin-right:2px}}
.chip{{font-size:11px;background:#f0fdfa;color:#0f766e;padding:2px 8px;border-radius:999px}}
.cta{{align-self:flex-start;color:var(--accent);font-weight:700;text-decoration:none;font-size:13px}}
@media (max-width:420px){{dl{{grid-template-columns:1fr}}}}
</style></head><body>
<div class="top">
  <h1>{e(args.city)} · hotel prices</h1>
  <div class="meta">Night of {e(report['date'])} · 2 adults · {e(report['currency'])} · snapshots {report['snapshots']} (latest {e(report['latest_snapshot'])}) · Google Hotels lowest price across sites</div>
  <div class="legend">{''.join(f'<span style="color:{COLORS[c][0]};background:{COLORS[c][1]}">{COLORS[c][2]} · {counts[c]}</span>' for c in ('green', 'neutral', 'red'))}</div>
</div>
<main class="grid">{''.join(cards)}</main>
</body></html>"""
    out = os.path.join(folder, "report.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"Saved -> {os.path.relpath(out)}")


if __name__ == "__main__":
    main()
