"""Landmarks section for build_page.py: the city's landmarks grouped like the app's city screen
(Cultural / Natural / Activities, then by attribute), each with its own photo (new_countrydex, as on the country screen) when one exists.

Which landmarks belong to a city (landmark_scope.json):
  - every landmark whose `city` is this city;
  - landmarks within `radius_km` of the city center whose own `city` is not another app city
    (picks up places filed under a suburb or district name);
  - `attach`: places that are administratively elsewhere but that everyone visits from this city
    (Paris -> Versailles, Berlin -> Potsdam, Seoul -> Suwon). Separate destinations (Amman -> Petra,
    Abu Dhabi -> Dubai) are never attached.
"""
import html
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "assets"

# Same sets as lib/widgets/city_detail_modal.dart (_naturalAttributes / _activityAttributes / _categoryOf).
NATURAL = {"Mountain", "Volcano", "Desert", "River", "Lake", "Sea", "Beach", "Waterfall", "Falls", "Cave", "Island",
           "Unique Landscape", "Glacier", "Canyon", "Geothermal", "Jungle"}
ACTIVITY = {"Painting", "Artwork", "Library", "Bookstore", "Filming Location", "Theater", "Performing Art", "Food",
            "Restaurant", "Brewery", "Winery", "Cafe", "Fast Food", "Festival", "Event", "Amusement Park",
            "Football Stadium", "Zoo", "Aquarium", "Cruise Tour", "Cable Car"}
CATEGORY_ORDER = ["Cultural", "Natural", "Activities"]


def category(lm):
    first = (lm.get("attributes") or [""])[0]
    return "Natural" if first in NATURAL else "Activities" if first in ACTIVITY else "Cultural"


def _km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def collect(city, center, all_landmarks, app_cities):
    """Landmarks that belong to `city`, ordered by global rank (0/None last)."""
    scope = json.loads((HERE / "landmark_scope.json").read_text(encoding="utf-8"))
    attach = set(scope.get("attach", {}).get(city, []))
    radius = scope.get("radius_km", 30)
    out = []
    for lm in all_landmarks:
        if lm['name'] in scope.get('exclude', {}).get(city, []) or "(defunct)" in lm["name"].lower():
            continue
        lc = lm.get("city")
        keep = lc == city or lc in attach
        if not keep and center and lm.get("latitude") is not None and lc not in app_cities:
            try:
                keep = _km(center, (float(lm["latitude"]), float(lm["longitude"]))) <= radius
            except (TypeError, ValueError):
                keep = False
        if keep:
            out.append(lm)
    rank = lambda lm: int(lm.get("global_rank") or 0) or 10 ** 6
    return sorted(out, key=lambda lm: (rank(lm), lm["name"]))


def _card(lm, photo, placeholder_icon, cls="lm-card"):
    src = photo(lm["name"])
    img = f'<img src="{src}" alt="">' if src else f'<span class="lm-ph" aria-hidden="true">{placeholder_icon}</span>'
    return src, (f'<button type="button" class="{cls}" data-lm="{html.escape(lm["name"])}">{img}'
                 f'<span class="cap">{html.escape(lm["name"])}</span></button>')


def _signature_map(key, items):
    """Static OSM map with a numbered pin and name label per signature landmark."""
    from trip_maps import BaseMap
    pts = [(float(lm["latitude"]), float(lm["longitude"])) for lm, _ in items]
    s, n = min(p[0] for p in pts), max(p[0] for p in pts)
    w, ea = min(p[1] for p in pts), max(p[1] for p in pts)
    # generous margins so pins and their name labels (drawn to the right) stay on the tiles
    pad_lat, pad_lon = max((n - s) * .3, .02), max((ea - w) * .25, .025)
    s, n, w, ea = s - pad_lat, n + pad_lat, w - pad_lon, ea + pad_lon + max((ea - w) * .45, .06)
    zoom = 15
    while zoom > 8:   # at most ~5x4 tiles
        from trip_maps import _world_px
        x0, y0 = _world_px(n, w, zoom)
        x1, y1 = _world_px(s, ea, zoom)
        if (x1 // 256 - x0 // 256 + 1) <= 5 and (y1 // 256 - y0 // 256 + 1) <= 4:
            break
        zoom -= 1
    bm = BaseMap(key, s, w, n, ea, zoom)
    xs = [bm.xy(*p) for p in pts]
    span = max(max(x for x, _ in xs) - min(x for x, _ in xs), 300)
    k = max(span / 520, .6)
    label_w = max(len(lm["name"]) for lm, _ in items) * 8.5 * k + 30 * k
    minx = max(0, min(x for x, _ in xs) - 50 * k)
    maxx = min(bm.width, max(x + label_w for x, _ in xs))
    miny = max(0, min(y for _, y in xs) - 45 * k)
    maxy = min(bm.height, max(y for _, y in xs) + 45 * k)
    vw, vh = maxx - minx, maxy - miny
    if vh < vw / 2.2:   # not too flat
        extra = vw / 2.2 - vh
        miny = max(0, miny - extra / 2)
        vh = min(bm.height - miny, vw / 2.2)
    parts = [bm.defs(), f'<svg class="sig-map" viewBox="{minx:.0f} {miny:.0f} {vw:.0f} {vh:.0f}" role="img" aria-label="Map of signature landmarks">',
             f'<use href="#{bm.id}" class="map-base"/>']
    for i, ((x, y), (lm, _)) in enumerate(zip(xs, items), 1):
        name = html.escape(lm["name"])
        parts.append(f'<g class="sig-pin" data-lm="{name}" transform="translate({x:.1f} {y:.1f})">'
                     f'<circle r="{15 * k:.1f}" stroke-width="{3 * k:.1f}"/><text class="n" font-size="{15 * k:.1f}" dy="{5 * k:.1f}">{i}</text>'
                     f'<text class="lab" x="{20 * k:.1f}" dy="{5 * k:.1f}" font-size="{14 * k:.1f}" stroke-width="{4 * k:.1f}">{name}</text></g>')
    parts.append("</svg>")
    return "".join(parts)


def render(city, landmarks, photo, placeholder_icon, signature=None, map_key=None, extra=None):
    """photo(name) -> data URI or None (build_page.landmark_photo).
    signature: [{"name", "detail"}] from signature.json, shown first (row + map) before the categories."""
    if not landmarks:
        return "", []
    e = html.escape
    by_name = {lm["name"]: lm for lm in landmarks}
    sig_items = [(by_name[s["name"]], s["detail"]) for s in (signature or []) if s["name"] in by_name]
    for s in signature or []:
        if s["name"] not in by_name:
            print(f"signature landmark not in this city's landmarks: {s['name']}")
    sig_html = ""
    if sig_items:
        rows = []
        for i, (lm, detail) in enumerate(sig_items, 1):
            _, card = _card(lm, photo, placeholder_icon, "sig-pic")
            rows.append(f'<li class="sig"><span class="sig-n">{i}</span>{card}<div class="sig-text">'
                        f'<h4>{e(lm["name"])}</h4><p>{e(detail)}</p></div></li>')
        sig_html = (f'<div class="lm-cat"><h3>Must-see{"" if len(sig_items) == 1 else f" · {len(sig_items)}"}</h3>'
                    f'<ol class="sig-list">{"".join(rows)}</ol>'
                    f'{_signature_map(map_key or city, sig_items)}</div>')
    groups = {}
    for lm in landmarks:
        groups.setdefault(category(lm), {}).setdefault((lm.get("attributes") or ["Other"])[0], []).append(lm)
    missing, blocks = [], []
    for cat in CATEGORY_ORDER:
        if cat not in groups:
            continue
        rows = []
        for attr, items in groups[cat].items():
            cards = []
            for lm in items:
                src, card = _card(lm, photo, placeholder_icon)
                if not src:
                    missing.append(lm["name"])
                cards.append(card)
            rows.append(f'<div class="lm-attr"><h4>{e(attr)} <span class="muted">{len(items)}</span></h4>'
                        f'<div class="lm-row">{"".join(cards)}</div></div>')
        blocks.append(f'<div class="lm-cat"><h3>{cat}</h3><div class="lm-attrs">{"".join(rows)}</div></div>')
    # Data for the detail sheet (same content as the app's landmark modal).
    data = {lm["name"]: {"loc": lm.get("city") or city, "attrs": lm.get("attributes") or [],
                         "overview": lm.get("overview") or "", "history": lm.get("history_significance") or "",
                         "highlights": [h.strip() for h in (lm.get("highlights") or "").split("\n") if h.strip()]}
            for lm in list(landmarks) + list(extra or [])}  # extra: sheet-only records (day-trip quests)
    html_out = f"""
  <section aria-labelledby="h-landmarks">
    <h2 id="h-landmarks">Landmarks <span class="muted lm-count">{len(landmarks)}</span></h2>
    {sig_html}
    {''.join(blocks)}
  </section>
  <dialog id="lm-sheet" aria-labelledby="lm-sheet-name">
    <div class="lm-sheet-head"><span class="pic lm-sheet-pic"></span>
      <button type="button" class="lm-x" aria-label="Close">×</button></div>
    <div class="lm-sheet-body">
      <h3 id="lm-sheet-name"></h3><p class="lm-loc"></p><div class="lm-tags"></div>
      <h4>Overview</h4><p class="lm-ov"></p>
      <h4>History &amp; significance</h4><p class="lm-hist"></p>
      <h4>Highlights</h4><ul class="lm-hl"></ul>
    </div>
  </dialog>
  <script>(() => {{
    const D = {json.dumps(data, ensure_ascii=False).replace("</", "<\\/")};
    const dlg = document.getElementById("lm-sheet"), q = (s) => dlg.querySelector(s);
    const open = (name, from) => {{
      const d = D[name]; if (!d) return;
      q("#lm-sheet-name").textContent = name;
      q(".lm-loc").textContent = d.loc;
      q(".lm-tags").innerHTML = ""; d.attrs.forEach((a) => {{ const s = document.createElement("span"); s.textContent = a; q(".lm-tags").append(s); }});
      q(".lm-ov").textContent = d.overview; q(".lm-hist").textContent = d.history;
      q(".lm-hl").innerHTML = ""; d.highlights.forEach((h) => {{ const li = document.createElement("li"); li.textContent = h; q(".lm-hl").append(li); }});
      const src = document.querySelector(`[data-lm="${{CSS.escape(name)}}"] .pic`);
      q(".lm-sheet-pic").className = "pic lm-sheet-pic " + (src ? [...src.classList].filter((c) => /^p\\d+$/.test(c)).join(" ") : "");
      dlg.showModal();
    }};
    document.addEventListener("click", (ev) => {{
      const t = ev.target.closest("[data-lm]"); if (t && !dlg.contains(t)) open(t.dataset.lm);
    }});
    q(".lm-x").addEventListener("click", () => dlg.close());
    dlg.addEventListener("click", (ev) => {{ if (ev.target === dlg) dlg.close(); }});
  }})();</script>"""
    return html_out, missing


CSS = """
.lm-count { font: 600 15px var(--font-body); }
.lm-cat { display: flex; flex-direction: column; gap: 10px; }
.lm-cat h3 { margin: 4px 0 0; font: 800 17px/1.3 var(--font-display); }
.lm-attrs { display: flex; flex-wrap: wrap; gap: 14px 18px; }
.lm-attr { min-width: 0; max-width: 100%; }
.lm-attr h4 { margin: 0 0 6px; font-size: 13px; font-weight: 700; }
.lm-attr h4 .muted { font-weight: 500; }
.lm-row { display: flex; align-items: flex-start; gap: 10px; overflow-x: auto; padding-bottom: 4px; }
.lm-card, .sig-pic { margin: 0; padding: 0; border: 0; background: none; color: inherit; font: inherit; text-align: left; cursor: pointer; }
/* buttons centre their content vertically; keep the photo at the top when a neighbour's name wraps */
.lm-card { width: 132px; flex: none; display: flex; flex-direction: column; justify-content: flex-start; }
.lm-card img, .lm-card .pic, .lm-card .lm-ph, .sig-pic .pic, .sig-pic .lm-ph { width: 132px; height: 132px; aspect-ratio: 1; border-radius: 14px; object-fit: cover;
  display: grid; place-items: center; background-color: var(--accent-soft); color: var(--accent); }
.lm-card .cap { display: block; font-size: 12.5px; font-weight: 600; margin-top: 5px; line-height: 1.25; }
.lm-card:hover .pic, .sig-pic:hover .pic { outline: 2px solid var(--accent); outline-offset: 2px; }
.lm-ph svg { width: 28px; height: 28px; fill: currentColor; }

.sig-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 12px; }
.sig { display: flex; gap: 14px; align-items: flex-start; background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 12px; position: relative; }
.sig-n { position: absolute; top: 6px; left: 6px; z-index: 1; width: 26px; height: 26px; border-radius: 50%; display: grid; place-items: center;
  background: var(--accent); color: var(--accent-ink); font: 800 13px var(--font-body); }
.sig-pic .cap { display: none; }
.sig-text { min-width: 0; }
.sig-text h4 { margin: 2px 0 4px; font: 800 17px/1.25 var(--font-display); }
.sig-text p { margin: 0; font-size: 14px; line-height: 1.5; }
@media (max-width: 520px) { .sig-pic .pic, .sig-pic .lm-ph { width: 96px; height: 96px; } .sig-text p { font-size: 13.5px; } }
.sig-map { display: block; width: 100%; height: auto; border-radius: 16px; border: 1px solid var(--line); background: var(--bg); }
.sig-pin { cursor: pointer; }
.sig-pin circle { fill: var(--accent); stroke: #fff; }
.sig-pin .n { fill: var(--accent-ink); font-family: var(--font-body); font-weight: 800; text-anchor: middle; }
.sig-pin .lab { fill: #1a1a1a; stroke: #fff; paint-order: stroke; font-family: var(--font-body); font-weight: 800; }

#lm-sheet { width: min(560px, calc(100vw - 32px)); max-height: calc(100vh - 48px); padding: 0; border: 0; border-radius: 24px; background: var(--surface); color: var(--ink); overflow: auto; }
#lm-sheet::backdrop { background: rgba(0, 0, 0, .45); }
.lm-sheet-head { position: relative; }
.lm-sheet-pic { width: 100%; aspect-ratio: 1; max-height: 360px; }
.lm-x { position: absolute; top: 10px; right: 10px; width: 36px; height: 36px; border-radius: 50%; border: 0; background: rgba(0, 0, 0, .55); color: #fff; font-size: 22px; cursor: pointer; }
.lm-sheet-body { padding: 16px 20px 22px; }
.lm-sheet-body h3 { margin: 0; font: 800 22px/1.2 var(--font-display); }
.lm-loc { margin: 2px 0 8px; color: var(--muted); font-size: 13px; }
.lm-tags { display: flex; flex-wrap: wrap; gap: 6px; }
.lm-tags span { font-size: 12px; font-weight: 700; padding: 3px 10px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); }
.lm-sheet-body h4 { margin: 16px 0 4px; font-size: 13px; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
.lm-sheet-body p, .lm-sheet-body li { font-size: 14.5px; line-height: 1.55; margin: 0; }
.lm-hl { margin: 0; padding-left: 18px; }
"""
