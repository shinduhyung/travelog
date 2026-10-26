// Google Hotels list-price harvest. Run on https://www.google.com/travel/hotels/<City>?hl=en once the list
// has loaded: reads the hotel cards already on the page (name, lowest price for the shown dates, rating,
// review count, stars) and hands them to gyg_receiver.py, which saves tool/hotel_prices/live/<slug>.json.
// Set window.HOTEL_CITY to the app city name first. Returns the hotel count, or "check:<text>" when the page
// is not a hotel list (consent page, "unusual traffic" check) so the caller can stop.
(() => {
  const text = document.body.innerText;
  if (/unusual traffic|not a robot|Before you continue/i.test(text)) return 'check:' + document.title;
  const ins = [...document.querySelectorAll('input')].map(i => [i.getAttribute('aria-label') || '', i.value]);
  const dateOf = k => (ins.find(([a]) => a.startsWith(k)) || [, ''])[1];
  const L = text.split('\n').map(s => s.trim()).filter(Boolean);
  const out = [], seen = new Set();
  for (let i = 1; i < L.length; i++) {
    const m = L[i].match(/^([₩$€£¥]|[A-Z]{3}\s?)([\d,]+)$/);
    if (!m) continue;
    // a deal badge ("GREAT DEAL") can sit between the hotel name and its price: take the line above it
    let k = i - 1;
    while (k > 0 && /^(DEAL|GREAT DEAL|GREAT PRICE|LOW PRICE|\d+% less than usual)$/i.test(L[k])) k--;
    const name = L[k];
    if (/^(Under|Price|From|Sponsored|\d)/.test(name) || name.length < 4 || seen.has(name)) continue;
    let r = null, n = null, star = null;
    for (let j = i + 1; j < Math.min(i + 7, L.length); j++) {
      if (/^([₩$€£¥]|[A-Z]{3}\s?)[\d,]+$/.test(L[j])) break;
      const a = L[j].match(/^(\d\.\d)\/5$/); if (a) r = +a[1];
      const b = L[j].match(/^\(([\d.]+)(K?)\)$/); if (b) n = Math.round(+b[1] * (b[2] ? 1000 : 1));
      const c = L[j].match(/(\d)-star/); if (c) star = +c[1];
    }
    seen.add(name);
    out.push({h: name, p: +m[2].replace(/,/g, ''), cur: m[1].trim(), r, n, star});
  }
  const d = [{kind: 'hotels', city: window.HOTEL_CITY, checkin: dateOf('Check-in'), checkout: dateOf('Check-out'),
              source: location.href.split('&ved')[0], fetched: new Date().toISOString().slice(0, 10), hotels: out}];
  if (out.length) setTimeout(() => { location.href = 'http://127.0.0.1:8766/save?d=' + encodeURIComponent(JSON.stringify(d)); }, 100);
  return out.length;
})();
