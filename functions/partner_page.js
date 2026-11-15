// 제휴업체 전용 통계 페이지 HTML 렌더링 (partner_system.js의 partnerStats가 사용).
// 외부 리소스 없이 인라인 CSS/SVG만 쓴다. 라이트/다크 모드와 모바일 폭을 지원한다.
// 개인정보(유저 id, 이메일 등)는 받지도 그리지도 않는다 — 건수, 날짜, 국가 코드만.

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

function flag(regionCode) {
  if (!regionCode || !/^[A-Za-z]{2}$/.test(regionCode)) return "";
  const base = 0x1F1E6;
  const up = regionCode.toUpperCase();
  return String.fromCodePoint(base + up.charCodeAt(0) - 65, base + up.charCodeAt(1) - 65);
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function fmtDate(d) {
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
}
function dayKey(d) {
  return d.toISOString().slice(0, 10);
}

function money(currency, amount) {
  const sym = currency === "USD" ? "$" : `${currency} `;
  return `${sym}${amount.toFixed(2)}`;
}

// 최근 30일 일별 건수 막대 차트 (인라인 SVG)
function dailyChart(events, now) {
  const days = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - i));
    days.push({ key: dayKey(d), date: d, n: 0 });
  }
  const idx = new Map(days.map((d, i) => [d.key, i]));
  for (const e of events) {
    const i = idx.get(dayKey(e.startedAt));
    if (i !== undefined) days[i].n++;
  }
  const max = Math.max(1, ...days.map((d) => d.n));
  const W = 600, H = 120, gap = 4, bw = (W - gap * 29) / 30;
  const bars = days.map((d, i) => {
    const h = d.n === 0 ? 3 : Math.max(8, (d.n / max) * (H - 8));
    const x = i * (bw + gap);
    const cls = d.n === 0 ? "bar zero" : "bar";
    return `<rect class="${cls}" x="${x.toFixed(1)}" y="${(H - h).toFixed(1)}" width="${bw.toFixed(1)}" height="${h.toFixed(1)}" rx="3"><title>${fmtDate(d.date)}: ${d.n}</title></rect>`;
  }).join("");
  const total = days.reduce((s, d) => s + d.n, 0);
  return { total, svg: `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Trials per day, last 30 days" preserveAspectRatio="none">${bars}</svg>`,
    from: fmtDate(days[0].date), to: fmtDate(days[29].date) };
}

function renderPartnerPage({ partner, events, now = new Date() }) {
  const reward = Number(partner.rewardPerTrial ?? 1);
  const convReward = Number(partner.rewardPerConversion ?? 4);
  const minPayout = Number(partner.minPayout ?? 10);
  const currency = partner.currency ?? "USD";
  const total = events.length;
  const converted = events.filter((e) => e.status === "paid").length;
  const active = events.filter((e) => e.status === "trial" && !e.trialCanceled).length;
  const ended = events.filter((e) => e.status === "expired" || e.status === "refunded" || (e.status === "trial" && e.trialCanceled)).length;
  const earned = total * reward + converted * convReward;      // 확정: 체험 시작 + 유료 전환
  const potential = active * convReward;                         // 진행 중인 체험이 전환되면 추가될 금액
  const toGo = Math.max(0, minPayout - earned);
  const pct = Math.min(100, (earned / minPayout) * 100);
  const byCode = {};
  for (const e of events) byCode[e.code] = (byCode[e.code] ?? 0) + 1;
  const codes = partner.codes ?? [];
  const hasApple = (partner.appleOffers ?? []).length > 0;
  const chart = dailyChart(events, now);

  const codeCards = codes.map((c) => `
    <div class="code">
      <div>
        <div class="code-name">${esc(c)}</div>
        <div class="muted">${byCode[c] ?? 0} ${(byCode[c] ?? 0) === 1 ? "trial" : "trials"} started</div>
      </div>
      <button class="copy" type="button" data-code="${esc(c)}">Copy</button>
    </div>`).join("");

  const label = { trial: "In trial", paid: "Paid", expired: "Expired", refunded: "Refunded" };
  const rows = events.slice(0, 50).map((e) => {
    const st = e.status === "trial" && e.trialCanceled ? "Cancelled" : (label[e.status] ?? "In trial");
    const cls = e.status === "paid" ? "pill ok" : (e.status === "trial" && !e.trialCanceled ? "pill" : "pill off");
    return `
    <li>
      <span class="when">${esc(fmtDate(e.startedAt))}</span>
      <span class="what">${esc(e.code)}</span>
      <span class="where">${e.platform === "ios" ? "App Store" : "Google Play"} · ${esc(e.regionCode ?? "")}</span>
      <span class="${cls}">${esc(st)}</span>
    </li>`;
  }).join("");

  const payoutLine = earned >= minPayout
    ? `You've reached the ${esc(money(currency, minPayout))} payout minimum. Paid monthly via PayPal.`
    : `${esc(money(currency, toGo))} to go until the ${esc(money(currency, minPayout))} payout minimum. Unpaid balance carries forward.`;

  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow"><meta name="color-scheme" content="light dark">
<title>Travelog partner dashboard</title>
<style>
:root{--bg:#f4f7fa;--card:#fff;--ink:#14202b;--muted:#64748b;--line:#e6ebf0;--brand:#1abfbc;--brand-ink:#0b7f7d;--brand-soft:#e3f8f7;--bar:#1abfbc;--bar-zero:#dfe6ec}
@media (prefers-color-scheme:dark){:root{--bg:#0e1419;--card:#17202a;--ink:#e8eef3;--muted:#94a3b3;--line:#263341;--brand:#2dd4d0;--brand-ink:#7ee8e5;--brand-soft:#12383a;--bar:#2dd4d0;--bar-zero:#263341}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:720px;margin:0 auto;padding:0 16px 40px}
header{padding:28px 0 8px}
.eyebrow{font-size:13px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:var(--brand-ink)}
h1{font-size:26px;line-height:1.2;margin:4px 0 0}
.muted{color:var(--muted);font-size:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-top:16px}
.hero{background:linear-gradient(135deg,var(--brand-soft),var(--card));}
.hero .label{font-size:14px;color:var(--muted)}
.hero .big{font-size:56px;line-height:1.05;font-weight:800;letter-spacing:-.02em;margin:6px 0 2px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.stat .num{font-size:28px;font-weight:700;margin-top:2px}
.bar-track{height:10px;border-radius:99px;background:var(--line);overflow:hidden;margin:14px 0 8px}
.bar-fill{height:100%;border-radius:99px;background:linear-gradient(90deg,var(--brand),var(--brand-ink))}
h2{font-size:17px;margin:0 0 12px}
.code{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 0;border-top:1px solid var(--line)}
.code:first-of-type{border-top:0;padding-top:0}
.code-name{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-weight:700;font-size:18px;letter-spacing:.02em}
.copy{border:1px solid var(--brand);background:transparent;color:var(--brand-ink);font:inherit;font-size:14px;font-weight:600;padding:8px 16px;border-radius:99px;cursor:pointer}
.copy:active,.copy.done{background:var(--brand);color:#fff}
.chart{margin-top:6px}
.chart svg{width:100%;height:120px;display:block}
.bar{fill:var(--bar)}.bar.zero{fill:var(--bar-zero)}
.axis{display:flex;justify-content:space-between;margin-top:6px}
ul.list{list-style:none;margin:0;padding:0}
ul.list li{display:grid;grid-template-columns:110px 1fr auto auto;gap:10px;align-items:center;padding:11px 0;border-top:1px solid var(--line);font-size:15px}
ul.list li:first-child{border-top:0}
.when{color:var(--muted)}.what{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:14px}.where{white-space:nowrap}
.empty{padding:24px 0;text-align:center;color:var(--muted)}
.how{font-size:14px;color:var(--muted)}
.how ol{margin:8px 0 0;padding-left:20px}
.applink{margin-top:6px}.applink a{color:var(--brand-ink);font-weight:600}
footer{margin-top:24px;font-size:13px;color:var(--muted);text-align:center}
.funnel{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;text-align:center}.fn{font-size:30px;font-weight:700}.fn.ok{color:var(--brand-ink)}
.pill{font-size:12px;font-weight:600;padding:3px 10px;border-radius:99px;background:var(--brand-soft);color:var(--brand-ink);white-space:nowrap}.pill.ok{background:var(--brand);color:#fff}.pill.off{background:var(--line);color:var(--muted)}
@media (max-width:480px){.hero .big{font-size:48px}.grid{grid-template-columns:1fr}ul.list li{grid-template-columns:90px 1fr auto;row-gap:4px}ul.list li .pill{grid-column:3;grid-row:1}ul.list li .where{grid-column:1 / -1;grid-row:2;font-size:13px;color:var(--muted)}}
</style></head>
<body><div class="wrap">
<header><div class="eyebrow">Travelog partner program</div><h1>${esc(partner.name)}</h1></header>

<section class="card hero">
  <div class="label">Valid trials started with your codes</div>
  <div class="big">${total}</div>
  <div class="muted">${esc(money(currency, reward))} per trial started, plus ${esc(money(currency, convReward))} when a trial converts to a paid subscription · paid monthly via PayPal</div>
</section>

<section class="grid">
  <div class="card stat"><div class="muted">Confirmed earnings</div><div class="num">${esc(money(currency, earned))}</div>
    ${potential > 0 ? `<div class="muted">+ ${esc(money(currency, potential))} if active trials convert</div>` : ""}</div>
  <div class="card stat"><div class="muted">Converted to paid</div><div class="num">${converted}</div>
    <div class="muted">of ${total} ${total === 1 ? "trial" : "trials"}</div></div>
</section>

<section class="card">
  <h2>Trial status</h2>
  <div class="funnel">
    <div><div class="fn">${active}</div><div class="muted">In trial</div></div>
    <div><div class="fn ok">${converted}</div><div class="muted">Paid</div></div>
    <div><div class="fn">${ended}</div><div class="muted">Cancelled / expired</div></div>
  </div>
  <div class="muted" style="margin-top:10px">Last 30 days: ${chart.total} ${chart.total === 1 ? "trial" : "trials"} started.</div>
</section>

<section class="card">
  <h2>Payout progress</h2>
  <div class="bar-track" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${pct.toFixed(0)}"><div class="bar-fill" style="width:${pct.toFixed(1)}%"></div></div>
  <div class="muted">${payoutLine}</div>
</section>

<section class="card">
  <h2>Your codes</h2>
  ${codeCards || '<div class="empty">No codes assigned yet.</div>'}
  <div class="how" style="margin-top:14px"><b>On Android</b> (Google Play)
    <ol><li>Open the Travelog app and tap <b>Go Premium</b>.</li>
    <li>On the payment sheet, open the payment method and tap <b>Redeem code</b>.</li>
    <li>Enter the code, then confirm to start the free trial.</li></ol>
    ${hasApple ? `<div style="margin-top:12px"><b>On iPhone</b> (App Store)</div>
    <ol><li>Open the App Store, tap your profile picture, then <b>Redeem Gift Card or Code</b>, and enter the code,<br>or just open the code's link below on the iPhone.</li>
    <li>Confirm the free trial, then open Travelog.</li></ol>
    ${codes.map((c) => `<div class="applink"><a href="https://apps.apple.com/redeem?ctx=offercodes&amp;id=6760092556&amp;code=${encodeURIComponent(c)}">iPhone link for ${esc(c)}</a></div>`).join("")}` : ""}
    <div style="margin-top:8px">Codes are for people who haven't subscribed to Travelog Premium before. The trial renews into an annual plan unless cancelled.</div>
  </div>
</section>

<section class="card">
  <h2>Trials per day</h2>
  <div class="chart">${chart.svg}<div class="axis muted"><span>${esc(chart.from)}</span><span>${esc(chart.to)}</span></div></div>
</section>

<section class="card">
  <h2>Recent trials</h2>
  ${rows ? `<ul class="list">${rows}</ul>` : '<div class="empty">No trials yet — they appear here within minutes of starting.</div>'}
</section>

<footer>Google Play &amp; App Store · Updated ${esc(now.toISOString().slice(0, 16).replace("T", " "))} UTC</footer>
</div>
<script>
document.querySelectorAll('.copy').forEach(function(b){b.addEventListener('click',function(){
  var t=b.getAttribute('data-code');
  var done=function(){b.textContent='Copied';b.classList.add('done');setTimeout(function(){b.textContent='Copy';b.classList.remove('done')},1500)};
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(done,function(){})}
})});
</script>
</body></html>`;
}

module.exports = { renderPartnerPage };
