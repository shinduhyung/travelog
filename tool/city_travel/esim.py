"""Embed the official affiliate catalog picker in a standalone city page."""
import html
import json
from pathlib import Path
from english_dates import SCRIPT as ENGLISH_DATES

HERE = Path(__file__).resolve().parent


def render(country):
    catalog = json.loads((HERE / 'airalo/packages.json').read_text(encoding='utf-8'))
    verified_file = HERE / 'airalo/uae_verified.json'
    if country == 'United Arab Emirates' and verified_file.exists():
        verified = json.loads(verified_file.read_text(encoding='utf-8'))
        catalog['countries'][country] = verified['packages']
        catalog['source'] = 'Airalo official storefront'
    plans = catalog['countries'].get(country, [])
    if not plans:
        return None
    # Country coverage of regional packages isn't verified by this export.
    subset = dict(catalog, countries={country: plans}, regions={})
    subset['prices_as_of'] = max(p['updated'] for p in plans)
    page = (HERE / 'esim_picker.html').read_text(encoding='utf-8')
    payload = json.dumps(subset, ensure_ascii=False).replace('<', '\\u003c')
    page = page.replace('<script src="airalo/packages.js"></script>',
                        '<script>window.AIRALO_PACKAGES=' + payload + ';</script>')
    page = page.replace('country: "United Arab Emirates"', 'country: ' + json.dumps(country))
    page = page.replace('You only leave Travelog to pay.', 'Choose a plan here, then review and buy it on Airalo.')
    page = page.replace('You can top up the same eSIM in the Airalo app when it runs out.',
                        'Check available top-ups and activation rules on Airalo before buying.')
    page = page.replace('Best fit for your trip', 'Lowest-priced plan matching your estimate')
    page = page.replace("Prices from Airalo's affiliate catalog, last updated", 'All fixed-data and unlimited UAE plans verified on Airalo,')
    page = page.replace('Checkout on Airalo', 'Select this plan on Airalo')
    page = page.replace('Price checked', 'Verified on Airalo')
    page = page.replace('<details id="moreBox" hidden>', '<details id="moreBox" open hidden>')
    page = page.replace('const covers = plans.filter((p) => p.days >= state.days);', 'const covers = plans.filter((p) => p.days >= state.days && (state.mode === "all" || (state.mode === "unlimited" ? p.gb == null : p.gb != null)));')
    page = page.replace('const plans = data.countries[state.country];', 'const plans = (data.countries[state.country] || []).filter(p => state.mode === "all" || (state.mode === "unlimited" ? p.gb == null : p.gb != null));')
    page = page.replace('days: 3, use: "normal"', 'days: 3, use: "normal", mode: "all"')
    page = page.replace('<section aria-label="Plans"', '<div class="chips" id="dataMode" role="group" aria-label="Plan type"><button type="button" data-mode="all" aria-pressed="true">All plans</button><button type="button" data-mode="fixed" aria-pressed="false">Fixed data</button><button type="button" data-mode="unlimited" aria-pressed="false">Unlimited</button></div><section aria-label="Plans"')
    page = page.replace('render();\n</script>', '''$("dataMode").addEventListener("click", e => {
  const b = e.target.closest("button"); if (!b) return;
  state.mode = b.dataset.mode;
  document.querySelectorAll("#dataMode button").forEach(x => x.setAttribute("aria-pressed", String(x === b)));
  render();
});
render();
</script>''')
    page = page.replace('of ${USES.find((u) => u.id === state.use).label.toLowerCase()} use you\'ll want about',
                        'of ${USES.find((u) => u.id === state.use).label.toLowerCase()} use we estimate about')
    page = page.replace('<input id="country" list="countryList"', '<input readonly id="country" list="countryList"')
    page = page.replace('</head>', '<style>body{padding:8px 0 16px;background:transparent}main{max-width:none}header h1{font-size:22px}</style></head>')
    page = page.replace('</body>', ENGLISH_DATES + '''<script>
const hostFrame = parent.document.getElementById('airalo-picker');
const size = () => { if (hostFrame) hostFrame.style.height = (document.body.scrollHeight + 32) + 'px'; };
new ResizeObserver(size).observe(document.body);
const syncTrip = () => {
  const a = parent.document.getElementById('pl-arrive')?.value?.slice(0,10);
  const b = parent.document.getElementById('pl-depart')?.value?.slice(0,10);
  if (!a || !b) return;
  $('from').value = a; $('to').value = b;
  $('from').dispatchEvent(new Event('change')); $('to').dispatchEvent(new Event('change'));
  const days = daysFromDates(); if (days) { state.days = days; render(); }
};
parent.document.addEventListener('change', (event) => {
  if (event.target.closest('[data-for="pl-arrive"], [data-for="pl-depart"]')) syncTrip();
});
syncTrip(); size();
</script></body>''')
    picks = []
    for gb, days in [(1, 3), (5, 7), (None, 7)]:
        match = next((p for p in plans if p['gb'] == gb and p['days'] == days), None)
        if match:
            picks.append(match)
    if len(picks) < 3:
        picks = sorted(plans, key=lambda p: p['price'])[:3]
    cards = ''.join(
        '<a class="esim-featured" rel="noopener sponsored" target="_blank" href="' + html.escape(p['url'], quote=True) + '">'
        '<strong>' + ('Unlimited' if p['gb'] is None else f"{p['gb']:g} GB") + '</strong>'
        f'<span>{p["days"]} days</span><b>${p["price"]:g} {html.escape(p["currency"])}</b><small>Select plan →</small></a>'
        for p in picks)
    return ('<style>.esim-featured-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:12px 0}'
            '.esim-featured{display:flex;flex-direction:column;gap:5px;padding:14px;border:1px solid var(--line);border-radius:14px;'
            'background:var(--surface);color:var(--ink);text-decoration:none}.esim-featured span,.esim-featured small{font-size:12px;color:var(--muted)}'
            '.esim-featured b{font-size:18px}.esim-expand{border:1px solid var(--line);border-radius:14px;padding:14px}'
            '.esim-expand summary{cursor:pointer;font-weight:700}@media(max-width:420px){.esim-featured{padding:10px}.esim-featured b{font-size:15px}}</style>'
            '<div class="esim-featured-grid">' + cards + '</div>'
            '<details class="esim-expand"><summary>Compare all ' + str(len(plans)) + ' plans · choose data and duration</summary>'
            '<p class="muted fine">Check that your phone supports eSIM and is carrier-unlocked. '
            'Data-use estimates are a guide; verify coverage, activation rules and the final price on Airalo.</p>'
            '<iframe id="airalo-picker" title="Compare Airalo data plans" '
            'style="width:100%;height:1100px;border:0;display:block" srcdoc="'
            + html.escape(page, quote=True) + '"></iframe></details>')
