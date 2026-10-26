"""Build a standalone trip-prep page for one city from the app's assets.

    python tool/city_travel/build_page.py "Abu Dhabi"

Writes tool/city_travel/out/<city-slug>.html. The page mirrors the sections of
lib/widgets/city_travel_modal.dart (flights, stays, tours, eSIM, luggage storage,
travel tips) with the same affiliate links, and embeds its images so it works as a
single file (shareable as a published page, where outside images are blocked).
"""
import base64
import city_records
import html
import io
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import itinerary  # noqa: E402
import planner  # noqa: E402
import flights as flight_search  # noqa: E402
import landmarks as landmark_section  # noqa: E402
import esim as esim_picker  # noqa: E402
import daytrip_section  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
OUT = Path(__file__).resolve().parent / "out"

# Same values as lib/widgets/city_travel_modal.dart
TRIP_COM_HOME = "https://www.trip.com/?Allianceid=8685083&SID=319520097&trip_sub1=&trip_sub3=D1919_3743"
AIRALO_TRACKING = "https://airalo.pxf.io/c/7592796/1268485/15608"
BOUNCE_REF = "TRAVELOG999083578969"
STORAGE = "https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/"
COST_LABELS = ["", "$ · Very cheap", "$$ · Affordable", "$$$ · Moderate", "$$$$ · Expensive", "$$$$$ · Very expensive"]


def load(name):
    return json.loads((ASSETS / name).read_text(encoding="utf-8"))


def snake(s):
    s = s.lower()
    s = re.sub(r"['`’]", "", s)
    s = re.sub(r"[^a-z0-9\s]", "", s)
    return re.sub(r"\s+", "_", s.strip())


from deepseek_city import SLUG_OVERRIDE as ds_slug_override


def slug(s):
    if s in ds_slug_override:
        return ds_slug_override[s]
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return snake(s).replace("_", "-")


def fetch_image(path, width):
    """Download an image from the app's storage, shrink it, return a data: URI (or None)."""
    try:
        local = Path(__file__).resolve().parent / "images" / "abu-dhabi" / Path(urllib.parse.unquote(path)).name
        if path.startswith("new_countrydex%2F") and local.is_file():
            raw = local.read_bytes()
        else:
            with urllib.request.urlopen(STORAGE + path + "?alt=media", timeout=20) as r:
                raw = r.read()
    except Exception:
        return None
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(raw)).convert("RGB")
        if img.width > width:
            img = img.resize((width, round(img.height * width / img.width)))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=78, optimize=True)
        raw = buf.getvalue()
    except Exception:
        pass
    return "data:image/jpeg;base64," + base64.b64encode(raw).decode()


def dedupe_images(page):
    """Embed each photo once: <img src="data:..."> becomes a span drawing a shared CSS background."""
    uris = {}

    def swap(m):
        n = uris.setdefault(m.group(1), len(uris))
        return f'<span class="pic p{n}" aria-hidden="true"></span>'

    page = re.sub(r'<img src="(data:image/[^"]+)" alt="">', swap, page)
    # !important: thumbnail rules like ".thumbs .pic { background: ... }" are more specific than ".pN"
    # and their background shorthand would otherwise wipe the photo.
    rules = "".join(f".p{n}{{background:center/cover no-repeat url({u})!important}}" for u, n in uris.items())
    css = ".pic{display:block;background:center/cover no-repeat var(--accent-soft)}\n" + rules
    return page.replace("</style>", css + "\n</style>", 1)


def landmark_photo(lm, width):
    """A landmark's own photo, the way lib/screens/country_detail_screen.dart loads it:
    new_countrydex/{first ISO3}_{snake}.webp, else new_countrydex/m_{snake}.webp (multi-country)."""
    if not lm:
        return None
    name = snake(lm["name"])
    iso3 = (re.findall(r"[A-Z]{3}", str(lm.get("countriesIsoA3") or "")) or [""])[0].lower()
    for file in ([f"{iso3}_{name}"] if iso3 else []) + [f"m_{name}"]:
        src = fetch_image(f"new_countrydex%2F{file}.webp", width)
        if src:
            return src
    return None


def flag(iso):
    return "".join(chr(0x1F1E6 + ord(c) - 65) for c in iso.upper()) if len(iso or "") == 2 else ""


def a(href, inner, cls=""):
    return f'<a class="{cls}" href="{html.escape(href)}" target="_blank" rel="noopener sponsored">{inner}</a>'




SIGNATURE = json.loads((Path(__file__).resolve().parent / "signature.json").read_text(encoding="utf-8"))


def city_status(city, rec, cities):
    """'Capital · largest' style label from signature.json (Claude-checked); missing cities are reported."""
    st = (SIGNATURE.get(city) or {}).get("status")
    if not st:
        print(f"check: no status for {city} in signature.json")
        return ""
    return ("Capital" if st["capital"] else "Not capital") + "\n" + ("Largest city" if st["largest"] else "Not largest")


FX_FILE = Path(__file__).resolve().parent / "fx_rates.json"
# Converter targets in menu order: currency -> flag country (EU flag for the euro).
FX_CHOICES = {
    "USD": "US", "EUR": "EU", "GBP": "GB", "JPY": "JP", "KRW": "KR", "CNY": "CN", "AUD": "AU", "CAD": "CA",
    "CHF": "CH", "HKD": "HK", "SGD": "SG", "TWD": "TW", "NZD": "NZ", "INR": "IN", "THB": "TH", "VND": "VN",
    "IDR": "ID", "MYR": "MY", "PHP": "PH", "AED": "AE", "SAR": "SA", "QAR": "QA", "TRY": "TR", "ILS": "IL",
    "EGP": "EG", "ZAR": "ZA", "MAD": "MA", "BRL": "BR", "MXN": "MX", "ARS": "AR", "CLP": "CL", "COP": "CO",
    "PEN": "PE", "SEK": "SE", "NOK": "NO", "DKK": "DK", "ISK": "IS", "PLN": "PL", "CZK": "CZ", "HUF": "HU",
    "RON": "RO", "RUB": "RU", "UAH": "UA", "KZT": "KZ", "PKR": "PK", "BDT": "BD", "LKR": "LK", "NPR": "NP",
    "MNT": "MN", "KHR": "KH", "LAK": "LA", "MOP": "MO", "JOD": "JO", "KWD": "KW", "BHD": "BH", "OMR": "OM",
    "KES": "KE", "NGN": "NG", "TZS": "TZ", "GEL": "GE", "AMD": "AM", "AZN": "AZ", "UZS": "UZ",
}
FX_NAMES = {
    "USD": "US dollar", "EUR": "Euro", "GBP": "British pound", "JPY": "Japanese yen", "KRW": "Korean won",
    "CNY": "Chinese yuan", "AUD": "Australian dollar", "CAD": "Canadian dollar", "CHF": "Swiss franc",
    "HKD": "Hong Kong dollar", "SGD": "Singapore dollar", "TWD": "Taiwan dollar", "NZD": "New Zealand dollar",
    "INR": "Indian rupee", "THB": "Thai baht", "VND": "Vietnamese dong", "IDR": "Indonesian rupiah",
    "MYR": "Malaysian ringgit", "PHP": "Philippine peso", "AED": "UAE dirham", "SAR": "Saudi riyal",
    "QAR": "Qatari riyal", "TRY": "Turkish lira", "ILS": "Israeli shekel", "EGP": "Egyptian pound",
    "ZAR": "South African rand", "MAD": "Moroccan dirham", "BRL": "Brazilian real", "MXN": "Mexican peso",
    "ARS": "Argentine peso", "CLP": "Chilean peso", "COP": "Colombian peso", "PEN": "Peruvian sol",
    "SEK": "Swedish krona", "NOK": "Norwegian krone", "DKK": "Danish krone", "ISK": "Icelandic krona",
    "PLN": "Polish zloty", "CZK": "Czech koruna", "HUF": "Hungarian forint", "RON": "Romanian leu",
    "RUB": "Russian ruble", "UAH": "Ukrainian hryvnia", "KZT": "Kazakh tenge", "PKR": "Pakistani rupee",
    "BDT": "Bangladeshi taka", "LKR": "Sri Lankan rupee", "NPR": "Nepalese rupee", "MNT": "Mongolian tugrik",
    "KHR": "Cambodian riel", "LAK": "Lao kip", "MOP": "Macau pataca", "JOD": "Jordanian dinar",
    "KWD": "Kuwaiti dinar", "BHD": "Bahraini dinar", "OMR": "Omani rial", "KES": "Kenyan shilling",
    "NGN": "Nigerian naira", "TZS": "Tanzanian shilling", "GEL": "Georgian lari", "AMD": "Armenian dram",
    "AZN": "Azerbaijani manat", "UZS": "Uzbek som",
}


def fx_rates():
    """USD-based rates from open.er-api.com (free, no key), cached; refetched when older than 30 days."""
    import datetime as dt
    cached = json.loads(FX_FILE.read_text(encoding="utf-8")) if FX_FILE.exists() else None
    if cached and (dt.date.today() - dt.date.fromisoformat(cached["date"])).days < 30:
        return cached
    try:
        with urllib.request.urlopen("https://open.er-api.com/v6/latest/USD", timeout=20) as r:
            d = json.load(r)
        cached = {"date": dt.date.today().isoformat(), "rates": d["rates"]}
        FX_FILE.write_text(json.dumps(cached), encoding="utf-8")
    except Exception as err:  # keep the old file if the fetch fails
        print(f"fx fetch failed: {err}")
    return cached


def theme_colors(page, iso):
    """Swap the default red accent for the country's theme colour (assets/country_color.json, same as the app)."""
    hex_ = next((c["theme_color_hex"] for c in load("country_color.json") if c["iso_a2"] == iso), None)
    if not hex_:
        return page
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    ink = "#ffffff" if lum < .6 else "#1e1715"
    # dark theme: lift the colour toward white so it reads on a dark background
    mix = lambda v, t: round(v + (255 - v) * t)
    t = .55 if lum < .35 else .3
    dr, dg, db = mix(r, t), mix(g, t), mix(b, t)
    light = f"--accent: {hex_}; --accent-ink: {ink}; --accent-soft: rgba({r}, {g}, {b}, .08);"
    dark = f"--accent: #{dr:02x}{dg:02x}{db:02x}; --accent-ink: #141010; --accent-soft: rgba({dr}, {dg}, {db}, .12);"
    page = page.replace("--accent: #c42a1f; --accent-ink: #ffffff; --accent-soft: rgba(196, 42, 31, .08);", light)
    return page.replace("--accent: #ff6b5d; --accent-ink: #1e0d0b; --accent-soft: rgba(255, 107, 93, .12);", dark)


def money_section(cost_level, currency, costs=None):
    """Cost of a day + a currency converter (local currency vs USD by default; amount and target editable)."""
    e = html.escape
    cells = []
    dollars = lambda n: f'{"$" * n}<i>{"$" * (5 - n)}</i>'
    keys = (("food", "Food", .35), ("stay", "Stay", .4), ("transport", "Transport", .25))
    note = ""
    if costs and all(k in costs for k, _, _ in keys):
        # The overall level is derived from the three parts (stay weighs most), so they always agree.
        cost_level = max(1, min(5, int(sum(costs[k][0] * w for k, _, w in keys) + .5)))
        note = "Weighted from stay, food and transport"
    if cost_level:
        parts = "".join(f'<li><span>{label}</span><b>{dollars(costs[key][0])}</b><small>{e(costs[key][1])}</small></li>'
                        for key, label, _ in keys if key in (costs or {}))
        cells.append(f'<div><h3>Cost of a day</h3><div class="big cost-big">{dollars(cost_level)}</div>'
                     f'<small>{e(COST_LABELS[cost_level].split(" · ")[1])}{" · " + note if note else ""}</small>'
                     f'{f"<ul class=cost-parts>{parts}</ul>" if parts else ""}</div>')
    fx = fx_rates() if currency else None
    if fx and currency in fx["rates"]:
        rates = {c: fx["rates"][c] for c in dict.fromkeys(list(FX_CHOICES) + [currency]) if c in fx["rates"]}
        opts = "".join(f'<option value="{c}"{" selected" if c == "USD" else ""}>{flag(FX_CHOICES.get(c, ""))} {c} · {e(FX_NAMES.get(c, ""))}</option>'
                       for c in rates if c != currency)
        cells.append(f"""<div><h3>Exchange rate</h3>
      <div class="fx-row"><input id="fx-amt" type="number" min="0" step="any" value="1" aria-label="Amount in {e(currency)}">
        <b>{flag(FX_CHOICES.get(currency, ""))} {e(currency)}</b> =<span class="big" id="fx-out"></span>
        <select id="fx-to" aria-label="Convert to">{opts}</select></div>
      <small>Rates from {e(fx["date"])}, refreshed monthly.</small></div>
    <script>(() => {{
      const R = {json.dumps(rates)}, base = {json.dumps(currency)};
      const amt = document.getElementById("fx-amt"), to = document.getElementById("fx-to"), out = document.getElementById("fx-out");
      const run = () => {{ const v = (+amt.value || 0) / R[base] * R[to.value];
        out.textContent = v.toLocaleString("en-US", {{ maximumFractionDigits: v >= 100 ? 0 : v >= 1 ? 2 : 4 }}); }};
      amt.addEventListener("input", run); to.addEventListener("change", run); run();
    }})();</script>""")
    if not cells:
        return ""
    return f'<section aria-label="Money"><div class="money">{"".join(cells)}</div></section>'


def main(city):
    e = html.escape
    cities = city_records.load_cities()
    rec = cities.get(city)
    if not rec:
        sys.exit(f'"{city}" is not in assets/cities.json (names must match the app exactly).')
    country, iso = rec["dimensions"]["country"], rec["dimensions"]["country_iso"]
    info = load("city_info.json").get(city.lower().strip(), {})
    hub = {h["name"]: h["iata"] for h in load("top_city_hub_airport.json")}
    iata = (hub.get(city) or [None])[0]
    airport_name = city_tz = None
    if iata:
        hub_airport = next((v for v in load("airports.json").values() if v.get("iata") == iata), {})
        airport_name, city_tz = hub_airport.get("name"), hub_airport.get("tz")
    tours = next((c["tours"] for c in load("city_tour_links.json") if c["city"] == city), [])
    bounce_slug = load("bounce_city_pages.json").get(city)
    all_landmarks = load("all_landmarks.json")
    landmark_names = {l["name"] for l in all_landmarks}
    lm_by_name_all = {l["name"]: l for l in all_landmarks}

    hero = fetch_image(f"ranked_cities%2F{'san_jose_cr' if city == 'San José' else snake(city)}.jpg.jpg", 1280)
    # ── glance strip
    glance = []
    if info.get("timezone"):
        glance.append(("Local time", info["timezone"], ""))
    if info.get("population"):
        glance.append(("Population", info["population"], ""))

    # Flight route search. The host supplies each signed-in user's Hub.
    airport_choices = (planner._read(planner.HERE / "planner" / f"{slug(city)}.json") or {}).get("airports", [])
    if not airport_choices and iata:
        airport_choices = [{"code": iata, "name": airport_name or iata}]
    flights = flight_search.render(iata, airport_choices)

    # ── stays (Hotels.com / Vrbo, same affiliate links as the app) + trip planner
    planner_html, stays_block, planner_css, planner_js = planner.build(city, slug(city), tours)
    if not stays_block:
        stays_block = '<div class="tiles two">' + "".join(
            a(url, f'<span class="ic" aria-hidden="true">{ICON[icon]}</span><b>{label}</b><span>{brand}</span>', "tile")
            for label, brand, icon, url in [("Hotels", "Hotels.com", "hotel", planner.hotels_com_search(city)),
                                            ("Apartments & homes", "Vrbo", "apartment", planner.vrbo_search(city))]) + "</div>"

    # ── tours
    tour_cards = []
    for t in tours:
        lms = [n for n in t.get("landmarks", []) if n in landmark_names]
        thumbs = ""
        if lms:
            items = []
            for n in lms:
                src = landmark_photo(lm_by_name_all.get(n), 360)
                img = f'<img src="{src}" alt="">' if src else f'<span class="ph" aria-hidden="true">{ICON["mountain"]}</span>'
                items.append(f'<figure>{img}<figcaption>{e(n)}</figcaption></figure>')
            thumbs = f"""<p class="quest">{ICON['flag']} Take this tour to unlock {len(lms)} landmark quest{'s' if len(lms) > 1 else ''}</p>
              <div class="thumbs">{''.join(items)}</div>"""
        hl = "".join(f"<li>{e(h)}</li>" for h in t.get("highlights", []))
        badges = "".join(f"<span>{e(b)}</span>" for b in t.get("badges", []))
        meta = [e(t.get("provider", ""))]
        if t.get("rating") is not None:
            meta.append(f'<span class="star">★</span> {e(str(t["rating"]))}' + (f' ({t["reviewCount"]:,})' if t.get("reviewCount") else ""))
        if t.get("duration"):
            meta.append(e(t["duration"]))
        price = ""
        if t.get("price"):
            price = (f'<s>{e(t["originalPrice"])}</s>' if t.get("originalPrice") else "") + f'<b>{e(t["price"])}</b>'
        tour_cards.append(f"""
        <article class="tour">
          {thumbs}
          {f'<ul class="why">{hl}</ul>' if hl else ''}
          {f'<div class="badges">{badges}</div>' if badges else ''}
          <h3>{e(t.get('title', ''))}</h3>
          <p class="meta">{' · '.join(meta)}</p>
          <div class="buy"><span class="price">{price}</span>{a(t['url'], f"View tour {ICON['arrow']}", "btn")}</div>
        </article>""")
    if not tour_cards:
        q = urllib.parse.quote(city)
        tour_cards.append(f"""<div class="tiles two">
          {a('https://www.getyourguide.com/s/?q=' + q + '&partner_id=EMZVISH&utm_medium=online_publisher', '<b>GetYourGuide</b><span>Tours &amp; activities</span>', 'tile')}
          {a('https://www.klook.com/search/result/?query=' + q, '<b>Klook</b><span>Tours &amp; activities</span>', 'tile')}
        </div>""")

    # ── eSIM, luggage
    esim_url = AIRALO_TRACKING + "?u=" + urllib.parse.quote(f"https://www.airalo.com/{slug(country)}-esim", safe="")
    esim = a(esim_url, f"""
      <span class="ic" aria-hidden="true">{ICON['sim']}</span>
      <span class="row-text"><b>Get an eSIM for {e(city)}</b><span>Stay connected in {e(country)} from day one · Airalo</span></span>
      <span class="go" aria-hidden="true">{ICON['arrow']}</span>""", "row-card accent")
    esim += esim_picker.render(country) or ''
    bounce_url = (f"https://bounce.com/luggage-storage/{bounce_slug}?ref={BOUNCE_REF}&utm_source=affiliates&utm_medium=link"
                  if bounce_slug else f"https://go.bounce.com/{BOUNCE_REF}")
    luggage = a(bounce_url, f"""
      <span class="ic" aria-hidden="true">{ICON['bag']}</span>
      <span class="row-text"><b>Store your bags in {e(city)}</b><span>Drop luggage at nearby shops and hotels · Bounce</span></span>
      <span class="go" aria-hidden="true">{ICON['arrow']}</span>""", "row-card")

    tips = "".join(f"<li>{e(t)}</li>" for t in info.get("tips", []))
    tips_html = f'<ol class="tips">{tips}</ol>' if tips else '<p class="muted">No city tips yet.</p>'

    hero_style = f' style="background-image:url({hero})"' if hero else ""
    glance_html = "".join(f'<div><dt>{e(k)}</dt><dd{" class=\"status\"" if k == "Status" else ""}>{e(v).replace(chr(10), "<br>")}</dd>{f"<small>{e(s)}</small>" if s else ""}</div>' for k, v, s in glance)
    # Live local time + difference from the viewer's own device clock (no GPS, no question asked).
    # The city's IANA zone comes from its hub airport, so daylight saving is handled.
    clock_js = ""
    if city_tz:
        glance_html = glance_html.replace(f'<dt>Local time</dt><dd>{e(info.get("timezone", ""))}</dd>',
                                          f'<dt>Local time</dt><dd id="lt-now">{e(info.get("timezone", ""))}</dd><small id="lt-diff"></small>', 1)
        clock_js = CLOCK_JS.replace("__TZ__", json.dumps(city_tz))

    plans_html, plans_css, plans_js = "", "", ""
    itin = itinerary.load_itinerary(slug(city))
    if itin:
        lm_by_name = {l["name"]: l for l in all_landmarks}
        plans_html = itinerary.Renderer(itin, city, tours, lm_by_name, sys.modules[__name__]).render(planner_html)
        plans_css, plans_js = itinerary.CSS, itinerary.JS

    # Contents bar: one chip per section that is on the page.
    arrive_html = planner.arrival(city, slug(city))
    # Landmarks above the tours, grouped like the app's city screen, with each landmark's own photo.
    center = (rec["values"].get("latitude"), rec["values"].get("longitude"))
    city_lms = landmark_section.collect(city, center if None not in center else None, all_landmarks, set(cities))
    daytrips_html, dt_lms = daytrip_section.render(city, slug(city), lm_by_name_all,
                                                   lambda n: landmark_photo(lm_by_name_all.get(n), 360), ICON)
    own = {lm["name"] for lm in city_lms}
    landmarks_html, no_photo = landmark_section.render(
        city, city_lms, lambda n: landmark_photo(lm_by_name_all.get(n), 360), ICON["mountain"],
        (SIGNATURE.get(city) or {}).get("signature"), f"{slug(city)}-sig",
        extra=[lm_by_name_all[n] for n in dt_lms if n not in own])
    if no_photo:
        print(f"landmarks without a photo ({len(no_photo)}): " + ", ".join(no_photo))
    toc_items = [("h-arrive", "Getting in", arrive_html), ("h-landmarks", "Landmarks", landmarks_html), ("h-daytrips", "Day trips", daytrips_html),
                 ("h-plans", "Plans", plans_html), ("h-tours", "Tours", True), ("h-flights", "Flights", True), ("h-stays", "Hotels", True),
                 ("h-esim", "eSIM", True), ("h-tips", "Tips", True)]
    toc = "".join(f'<a href="#{i}"{" class=\"hl\"" if i == "h-plans" else ""}>{label}</a>' for i, label, on in toc_items if on)
    toc += a(bounce_url, 'Luggage')

    money_html = money_section(info.get("cost_level"), (itin or {}).get("currency"), (SIGNATURE.get(city) or {}).get("costs"))

    page = TEMPLATE.format(
        money=money_html,
        city_intro=e((planner._read(planner.HERE / "planner" / f"{slug(city)}.json") or {}).get("intro_line")
                     or f"Discover the places, flavours and journeys that define {city}."),
        clock_js=clock_js, plans=plans_html, plans_css=plans_css + planner_css + landmark_section.CSS + daytrip_section.CSS, daytrips=daytrips_html, landmarks=landmarks_html, plans_js=plans_js + planner_js, toc=toc, arrive=arrive_html,
        city=e(city), country=e(country), flag=flag(iso), hero_style=hero_style,
        glance=glance_html, flights=flights, stays=stays_block, tours="".join(tour_cards),
        esim=esim, luggage=luggage,
    )
    tips_block = f'<div class="aside tips-box" id="h-tips"><h3>Tips</h3>{tips_html}</div>'
    page = page.replace("<!--TIPS-->", tips_block, 1) if "<!--TIPS-->" in page else page.replace("</main>", f"<section>{tips_block}</section></main>", 1)
    page = theme_colors(dedupe_images(page), iso)
    OUT.mkdir(exist_ok=True)
    out = OUT / f"{slug(city)}.html"
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} KB)")


CLOCK_JS = """<script>(() => {
  const tz = __TZ__, now = document.getElementById("lt-now"), diff = document.getElementById("lt-diff");
  if (!now) return;
  const offsetMin = (zone, d) => {   // minutes east of UTC for a time zone at date d
    const p = Object.fromEntries(new Intl.DateTimeFormat("en-US", { timeZone: zone, hourCycle: "h23", year: "numeric", month: "2-digit",
      day: "2-digit", hour: "2-digit", minute: "2-digit" }).formatToParts(d).map((x) => [x.type, x.value]));
    return Math.round((Date.UTC(+p.year, p.month - 1, +p.day, +p.hour, +p.minute) - d.getTime()) / 60000);
  };
  const tick = () => {
    const d = new Date();
    try { now.textContent = d.toLocaleTimeString("en-US", { timeZone: tz, hour: "numeric", minute: "2-digit" }); } catch (_) { return; }
    const m = offsetMin(tz, d) + d.getTimezoneOffset();   // city minus viewer
    const h = Math.floor(Math.abs(m) / 60), r = Math.abs(m) % 60, span = `${h ? h + " h" : ""}${h && r ? " " : ""}${r ? r + " min" : ""}`;
    diff.textContent = m === 0 ? "Same time as you" : `${span} ${m > 0 ? "ahead of" : "behind"} you`;
  };
  tick(); setInterval(tick, 30000);
})();</script>"""

ICON = {
    "plane": '<svg viewBox="0 0 24 24"><path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/></svg>',
    "arrow": '<svg viewBox="0 0 24 24"><path d="M5 12h12m-5-6 6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "hotel": '<svg viewBox="0 0 24 24"><path d="M3 20V5h2v9h7V8h6a3 3 0 0 1 3 3v9h-2v-3H5v3zm5-7a2 2 0 1 1 0-4 2 2 0 0 1 0 4"/></svg>',
    "hostel": '<svg viewBox="0 0 24 24"><path d="M4 4h2v6h12V4h2v16h-2v-4H6v4H4zm2 8v2h12v-2z"/></svg>',
    "apartment": '<svg viewBox="0 0 24 24"><path d="M4 21V3h11v6h5v12h-7v-4h-2v4zm3-14v2h2V7zm4 0v2h2V7zm-4 4v2h2v-2zm4 0v2h2v-2zm5 2v2h2v-2zm-9 2v2h2v-2zm9 2v2h2v-2z"/></svg>',
    "resort": '<svg viewBox="0 0 24 24"><path d="M12 3a9 9 0 0 1 9 9h-8v8h-2v-8H3a9 9 0 0 1 9-9m-9 18h18v-1H3z"/></svg>',
    "sim": '<svg viewBox="0 0 24 24"><path d="M7 2h7l5 5v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2m1 9v7h8v-7z"/></svg>',
    "bag": '<svg viewBox="0 0 24 24"><path d="M9 2h6v4h3a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2v1h-2v-1H8v1H6v-1a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3zm2 2v2h2V4zM8 9v9h2V9zm6 0v9h2V9z"/></svg>',
    "flag": '<svg viewBox="0 0 24 24" class="inline"><path d="M5 21V4h9l.5 2H20v9h-6l-.5-2H7v8z"/></svg>',
    "mountain": '<svg viewBox="0 0 24 24"><path d="m3 19 6-9 4 6 3-4 5 7z"/></svg>',
}

TEMPLATE = """<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{city} Trip Prep</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,800&family=Figtree:wght@400;500;600;700&family=Noto+Color+Emoji&display=swap">
<style>
/* Layout: one phone-width column, a full-bleed photo header, then booking blocks in the order a traveler books. */
:root {{
  --bg: #f8f5f3; --surface: #ffffff; --ink: #1e1715; --muted: #6f625e; --line: #ebe2de;
  --accent: #c42a1f; --accent-ink: #ffffff; --accent-soft: rgba(196, 42, 31, .08); --star: #b7791f; --map-filter: saturate(.85);
  --font-display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --font-body: "Figtree", "Segoe UI", system-ui, sans-serif;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #141010; --surface: #1e1817; --ink: #f4ece9; --muted: #ab9e99; --line: #332a28;
  --accent: #ff6b5d; --accent-ink: #1e0d0b; --accent-soft: rgba(255, 107, 93, .12); --star: #f0b453; --map-filter: invert(.9) hue-rotate(180deg) saturate(.5) brightness(.95); color-scheme: dark; }} }}
:root[data-theme="dark"] {{
  --bg: #141010; --surface: #1e1817; --ink: #f4ece9; --muted: #ab9e99; --line: #332a28;
  --accent: #ff6b5d; --accent-ink: #1e0d0b; --accent-soft: rgba(255, 107, 93, .12); --star: #f0b453; --map-filter: invert(.9) hue-rotate(180deg) saturate(.5) brightness(.95); color-scheme: dark; }}
* {{ box-sizing: border-box; }}
body {{ background: var(--bg); color: var(--ink); font: 16px/1.5 var(--font-body);
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 16px 40px; }}
main {{ max-width: 680px; margin: 0 auto; display: flex; flex-direction: column; gap: 32px; }}
a {{ color: inherit; }}
a:focus-visible {{ outline: 3px solid var(--accent); outline-offset: 2px; border-radius: 14px; }}
svg {{ width: 22px; height: 22px; fill: currentColor; flex: none; }}
svg.inline {{ width: 16px; height: 16px; vertical-align: -3px; }}
.muted {{ color: var(--muted); }}

.hero {{ position: relative; min-height: 300px; border-radius: 22px; overflow: hidden; display: flex; align-items: flex-end;
  background: var(--accent-soft) center / cover no-repeat; color: #fff; }}
.hero::after {{ content: ""; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(0,0,0,0) 35%, rgba(0,0,0,.62)); }}
.hero-text {{ position: relative; z-index: 1; padding: 24px; }}
.eyebrow {{ font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; opacity: .9; }}
h1 {{ font: 800 clamp(40px, 11vw, 64px)/0.95 var(--font-display); letter-spacing: -.02em; margin: 6px 0 4px; text-wrap: balance; }}
.hero-text p {{ margin: 0; font-weight: 500; }}

.glance {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 1px; margin: 0;
  background: var(--line); border: 1px solid var(--line); border-radius: 16px; overflow: hidden; }}
.glance div {{ background: var(--surface); padding: 12px 14px; min-width: 0; }}
.glance dt {{ font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }}
.glance dd {{ margin: 2px 0 0; font: 800 22px/1.2 var(--font-display); font-variant-numeric: tabular-nums; }}
.glance small {{ display: block; font-size: 12px; color: var(--muted); }}
.glance dd.status {{ font: 800 18px/1.2 var(--font-display); margin-top: 3px; }}

.money {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; }}
.money > div {{ background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 14px 16px; min-width: 0; }}
.money h3 {{ margin: 0 0 6px; font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }}
.money .big {{ font: 800 22px/1.2 var(--font-display); font-variant-numeric: tabular-nums; }}
.money .fx-row {{ display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }}
.cost-big i, .cost-parts b i {{ font-style: normal; color: var(--line); }}
.money select, .money .fx-row b {{ font-family: var(--font-body), "Noto Color Emoji"; max-width: 100%; }}
.money input, .money select {{ font: 700 16px var(--font-body), "Noto Color Emoji"; padding: 6px 8px; border-radius: 10px; border: 1px solid var(--line);
  background: var(--bg); color: var(--ink); }}
.money input {{ width: 7em; font-variant-numeric: tabular-nums; }}
.money small {{ display: block; font-size: 12px; color: var(--muted); margin-top: 6px; }}
.cost-parts {{ list-style: none; margin: 10px 0 0; padding: 10px 0 0; border-top: 1px solid var(--line); display: flex; flex-direction: column; gap: 8px; }}
.cost-parts li {{ display: grid; grid-template-columns: 80px auto; gap: 0 10px; align-items: baseline; }}
.cost-parts span {{ font-weight: 700; font-size: 14px; }}
.cost-parts b {{ font: 800 16px var(--font-display); color: var(--accent); letter-spacing: .05em; }}
.cost-parts b i {{ font-style: normal; color: var(--line); }}
.cost-parts small {{ grid-column: 2; margin: 0; }}

section {{ display: flex; flex-direction: column; gap: 12px; }}
h2 {{ font: 800 22px/1.2 var(--font-display); margin: 0; letter-spacing: -.01em; }}

.row-card {{ display: flex; align-items: center; gap: 14px; padding: 16px; border-radius: 16px; text-decoration: none;
  background: var(--surface); border: 1px solid var(--line); transition: transform .15s ease, border-color .15s ease; }}
.row-card:hover {{ border-color: var(--accent); transform: translateY(-1px); }}
.row-card .ic {{ display: grid; place-items: center; width: 44px; height: 44px; border-radius: 12px; background: var(--accent-soft); color: var(--accent); flex: none; }}
.row-text {{ display: flex; flex-direction: column; min-width: 0; flex: 1; }}
.row-text b {{ font-weight: 700; }}
.row-text span {{ font-size: 14px; color: var(--muted); }}
.go {{ color: var(--muted); }}
.row-card.accent {{ background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }}
.row-card.accent .ic {{ background: rgba(255,255,255,.18); color: inherit; }}
.row-card.accent .row-text span, .row-card.accent .go {{ color: inherit; opacity: .85; }}

.tiles {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }}
.tiles.two {{ grid-template-columns: 1fr 1fr; }}
.tile {{ display: flex; flex-direction: column; gap: 18px; padding: 14px; border-radius: 16px; text-decoration: none; min-width: 0;
  background: var(--accent-soft); border: 1px solid transparent; transition: border-color .15s ease; }}
.tile:hover {{ border-color: var(--accent); }}
.tile .ic {{ color: var(--accent); }}
.tile b {{ font-size: 14px; }}
.tile span:not(.ic) {{ font-size: 12px; color: var(--muted); }}
@media (max-width: 460px) {{ .tiles {{ grid-template-columns: 1fr 1fr; }} }}

.tour {{ background: var(--surface); border: 1px solid var(--line); border-radius: 18px; padding: 16px; display: flex; flex-direction: column; gap: 12px; }}
.quest {{ margin: 0; font-size: 14px; font-weight: 700; color: var(--accent); }}
.thumbs {{ display: flex; align-items: flex-start; gap: 10px; overflow-x: auto; }}
.thumbs figure {{ margin: 0; width: 120px; flex: none; }}
.thumbs img, .thumbs .ph, .thumbs .pic {{ width: 120px; height: 120px; aspect-ratio: 1; border-radius: 12px; object-fit: cover; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent); }}
.thumbs figcaption {{ font-size: 12px; font-weight: 600; margin-top: 4px; line-height: 1.25; }}
.why {{ margin: 0; padding: 12px 14px; list-style: none; background: var(--bg); border-radius: 12px; display: flex; flex-direction: column; gap: 6px; font-size: 14px; }}
.why li {{ padding-left: 22px; position: relative; }}
.why li::before {{ content: "✓"; position: absolute; left: 0; color: var(--accent); font-weight: 800; }}
.badges {{ display: flex; flex-wrap: wrap; gap: 6px; }}
.badges span {{ font-size: 12px; font-weight: 600; color: var(--accent); background: var(--accent-soft); padding: 4px 10px; border-radius: 999px; }}
.tour h3 {{ margin: 0; font: 700 18px/1.3 var(--font-display); text-wrap: balance; }}
.meta {{ margin: -6px 0 0; font-size: 14px; color: var(--muted); font-variant-numeric: tabular-nums; }}
.star {{ color: var(--star); }}
.buy {{ display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; border-top: 1px solid var(--line); padding-top: 12px; }}
.price {{ display: flex; align-items: baseline; gap: 8px; font-variant-numeric: tabular-nums; }}
.price s {{ color: var(--muted); font-size: 14px; }}
.price b {{ font: 800 24px/1 var(--font-display); }}
.btn {{ display: inline-flex; align-items: center; gap: 6px; padding: 10px 16px; border-radius: 999px; background: var(--accent); color: var(--accent-ink);
  text-decoration: none; font-weight: 700; font-size: 14px; }}
.btn svg {{ width: 18px; height: 18px; }}

.tips {{ margin: 0; padding: 0; list-style: none; counter-reset: tip; display: flex; flex-direction: column; gap: 10px; }}
.tips li {{ counter-increment: tip; display: grid; grid-template-columns: 28px 1fr; gap: 10px; padding: 14px; background: var(--surface); border: 1px solid var(--line); border-radius: 14px; }}
.tips li::before {{ content: counter(tip); font: 800 18px/1.3 var(--font-display); color: var(--accent); }}

footer {{ font-size: 13px; color: var(--muted); border-top: 1px solid var(--line); padding-top: 16px; display: flex; flex-direction: column; gap: 4px; }}
@media (prefers-reduced-motion: reduce) {{ * {{ transition: none !important; }} }}
{plans_css}
</style>

<main>
  <header class="hero"{hero_style}>
    <div class="hero-text">
      <div class="eyebrow">Trip prep · {flag} {country}</div>
      <h1>{city}</h1>
      <p>{city_intro}</p>
    </div>
  </header>

  <nav class="toc" aria-label="On this page">{toc}</nav>
  <dl class="glance" aria-label="At a glance">{glance}</dl>
  {money}
  {arrive}
  {landmarks}
  {daytrips}
  {plans}
  <section aria-labelledby="h-tours"><h2 id="h-tours">Tours &amp; activities</h2>{tours}</section>
  <section aria-labelledby="h-flights"><h2 id="h-flights">Flights</h2>{flights}</section>
  <section aria-labelledby="h-stays"><h2 id="h-stays">Hotels</h2>{stays}</section>
  <section aria-labelledby="h-esim"><h2 id="h-esim">eSIM</h2>{esim}</section>
  <section aria-labelledby="h-bags"><h2 id="h-bags">Luggage storage</h2>{luggage}</section>

  <footer>
    <span>We may earn a commission from bookings made through these links, at no extra cost to you.</span>
    <span>Travelog · travelogapp.uk</span>
  </footer>
</main>
{plans_js}
{clock_js}
"""

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Abu Dhabi")
