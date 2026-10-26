// GetYourGuide city-page harvest. Run in the browser tab while a GYG city page (/<city>-l<id>/) is open:
// reads the tour cards already on the page (no extra requests), keeps the most-reviewed 40 and hands them
// to gyg_receiver.py by a top-level navigation (the page's CSP blocks fetch() to localhost).
// Set window.GYG_CITY to the app city name first. Returns -1 (and saves nothing) when not on a city page.
(() => {
  // English site only (titles go on English pages); a Korean/other locale returns "lang:<code>"
  const lang = (document.documentElement.lang || '').toLowerCase();
  if (lang && !lang.startsWith('en')) return 'lang:' + lang;
  if (!/^\/[a-z0-9-]+-l\d+\/?$/.test(location.pathname)) {
    // on the search results page: return the city page link to open next ("go:/bogota-l361/"), or -1
    const want = (window.GYG_CITY || '').normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase()
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    const locs = [...document.querySelectorAll('a[href]')].map(a => a.getAttribute('href').split('?')[0])
      .filter(h => /^\/[a-z0-9-]+-l\d+\/?$/.test(h));
    const hit = locs.find(h => h.replace(/-l\d+\/?$/, '').replace(/^\//, '') === want)
      || locs.find(h => h.slice(1).startsWith(want));
    if (hit) return 'go:' + hit;
    // no name match (Bengaluru is "bangalore-l…"): list the locations the result tours belong to, most first
    const c = {};
    for (const a of document.querySelectorAll('a[href]')) {
      const m = (a.getAttribute('href') || '').match(/^\/([a-z0-9-]+-l\d+)\/[^?]*-t\d+/);
      if (m) c[m[1]] = (c[m[1]] || 0) + 1;
    }
    const top = Object.entries(c).sort((x, y) => y[1] - x[1]).slice(0, 4).map(([k, n]) => k + ':' + n);
    return top.length ? 'candidates:' + top.join(',') : -1;
  }
  const isTour = h => /-t\d+\/?$/.test((h || '').split('?')[0]);
  const tourLinks = el => new Set([...el.querySelectorAll('a[href]')].map(a => a.getAttribute('href').split('?')[0]).filter(isTour));
  const seen = new Set(), tours = [];
  for (const a of document.querySelectorAll('a[href]')) {
    const href = (a.getAttribute('href') || '').split('?')[0];
    if (!isTour(href) || seen.has(href)) continue;
    // the card: the largest ancestor that still holds only this one tour
    let c = a;
    while (c.parentElement && tourLinks(c.parentElement).size === 1) c = c.parentElement;
    const text = c.innerText;
    const lines = text.split('\n').map(s => s.trim()).filter(Boolean);
    const ri = lines.findIndex(s => /^\d(\.\d)?$/.test(s));  // new listings show a whole "5"
    const n = (text.match(/\((\d[\d,.]*)\)/) || [])[1];
    const p = (text.match(/From\s*\n?\s*[^\d\n]*([\d,.]+)/) || [])[1];
    if (ri < 0 || !n) continue;
    seen.add(href);
    const skip = /^(Certified by|Top pick|Likely to sell out|New activity|Activity ranking|Booked \d|From|per person|per group|Free cancellation|\$|\d)/i;
    const body = lines.filter(s => !skip.test(s));
    // some cards start with a location label ("Amsterdam") above the title
    if (body.length > 1 && body[0].length < 25 && body[1].length > body[0].length) body.shift();
    tours.push({u: href, t: body[0] || '', r: +lines[ri], n: +n.replace(/[,.]/g, ''),
                p: p ? Math.round(+p.replace(/,/g, '')) : null, a: (body[1] || '').slice(0, 160)});
  }
  tours.sort((x, y) => y.n - x.n);
  const d = [{city: window.GYG_CITY, page: location.pathname, tours: tours.slice(0, 40)}];
  setTimeout(() => { location.href = 'http://127.0.0.1:8766/save?d=' + encodeURIComponent(JSON.stringify(d)); }, 100);
  return tours.length;
})();
