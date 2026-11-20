// Onboarding A/B report: 'tutorial' (6-step tutorial) vs 'direct_add'
// (skip tutorial, 2-step coach mark: My Trips Countries "+" → map "+").
//
// Only fresh installs on 1.0.10+ get a group (onboardingAbGroup on
// app_open_events, ad_revenue_events, ad_impression_events,
// ad_request_events, tutorial_step_events). Everything else (orders,
// subscription_funnel_events) is joined by deviceId. GA4 also has the
// user property `onboarding_ab` for retention / engagement / purchase views.
//
// Per group:
//   onboarding   passed welcome, finished, coach taps, visited countries
//   visits       opens per install, active days, opens on day 0
//   retention    D1 / D3 / D7 (any open on that day after install, cohorts old enough)
//   ads          interstitials and ad revenue on day 0, days 0–6, all time
//   subscription paywall views, checkouts, purchases, revenue (by currency)
//   rating       in-app review prompts shown
//
// Usage (from jidoapp/functions):
//   node scripts/onboarding_ab_report.js
//   node scripts/onboarding_ab_report.js --platform android
//
// Auth: gcloud application-default login. Read-only.

const admin = require("firebase-admin");

const H = 3600 * 1000;
const D = 24 * H;
const G = ["tutorial", "direct_add"];

const median = (a) => {
  if (!a.length) return null;
  const s = [...a].sort((x, y) => x - y);
  return s[Math.floor(s.length / 2)];
};
const mean = (a) => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : null);
const pct = (a, b) => (b ? `${((100 * a) / b).toFixed(1)}%` : "-");
const f = (x, d = 2) => (x === null || x === undefined ? "-" : x.toFixed(d));

async function inChunks(db, coll, field, ids) {
  const out = [];
  for (let i = 0; i < ids.length; i += 30) {
    const snap = await db.collection(coll).where(field, "in", ids.slice(i, i + 30)).get();
    out.push(...snap.docs.map((d) => d.data()));
  }
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const i = args.indexOf("--platform");
  const platform = i >= 0 ? args[i + 1] : null;

  admin.initializeApp({ projectId: "proboscis-2025" });
  const db = admin.firestore();
  const now = Date.now();

  const dev = new Map(); // deviceId -> data
  const opens = await db.collection("app_open_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of opens.docs) {
    const d = doc.data();
    if (!d.deviceId || !d.timestamp) continue;
    if (platform && d.platform !== platform) continue;
    if (!dev.has(d.deviceId))
      dev.set(d.deviceId, { g: d.onboardingAbGroup, opens: [], ads: [], steps: new Map(), funnel: [], orders: [] });
    dev.get(d.deviceId).opens.push(d.timestamp.toMillis());
  }
  const rev = await db.collection("ad_revenue_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of rev.docs) {
    const d = doc.data();
    const v = dev.get(d.deviceId);
    if (!v || !d.timestamp || d.currencyCode !== "USD") continue;
    v.ads.push({ t: d.timestamp.toMillis(), r: Number(d.revenue) || 0, inter: d.format === "interstitial" });
  }
  const steps = await db.collection("tutorial_step_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of steps.docs) {
    const d = doc.data();
    const v = dev.get(d.deviceId);
    if (!v) continue;
    const k = `${d.stepName}|${d.action}`;
    if (!v.steps.has(k)) v.steps.set(k, d.selections);
  }
  const ids = [...dev.keys()];
  for (const d of await inChunks(db, "subscription_funnel_events", "deviceId", ids)) dev.get(d.deviceId)?.funnel.push(d.event);
  for (const d of await inChunks(db, "orders", "deviceId", ids)) dev.get(d.deviceId)?.orders.push(d);

  console.log(`Onboarding A/B (${platform || "all platforms"}) — ${new Date().toISOString()}`);
  for (const g of G) {
    const rows = [...dev.values()]
      .filter((v) => v.g === g && v.opens.length)
      .map((v) => {
        v.opens.sort((a, b) => a - b);
        const t0 = v.opens[0];
        const age = now - t0;
        const dayOf = (t) => Math.floor((t - t0) / D);
        const openDays = new Set(v.opens.map(dayOf));
        const adsIn = (days) => v.ads.filter((a) => a.t < t0 + days * D);
        const s = v.steps;
        return {
          age,
          welcome: s.has("welcome|complete"),
          finished: s.has("tutorial_countries|complete") || s.has("direct_coach|complete") || s.has("direct_coach|skip"),
          coach1: s.has("direct_coach|complete"),
          coach1Skip: s.has("direct_coach|skip"),
          coach2: s.has("direct_map_add|complete"),
          countries: s.get("tutorial_countries|complete") ?? s.get("direct_countries|complete") ?? null,
          review: s.has("review_prompt|view"),
          opens: v.opens.length,
          opens0: v.opens.filter((t) => dayOf(t) === 0).length,
          activeDays: openDays.size,
          d1: openDays.has(1), d3: openDays.has(3), d7: openDays.has(7),
          inter0: adsIn(1).filter((a) => a.inter).length,
          rev0: adsIn(1).reduce((x, a) => x + a.r, 0),
          rev7: adsIn(7).reduce((x, a) => x + a.r, 0),
          revAll: v.ads.reduce((x, a) => x + a.r, 0),
          paywall: v.funnel.filter((e) => e === "paywall_shown").length,
          checkout: v.funnel.includes("checkout_started"),
          orders: v.orders.filter((o) => o.status === "purchased" && !o.isRenewal),
        };
      });
    const n = rows.length;
    const cnt = (fn) => rows.filter(fn).length;
    const ret = (k, days) => {
      const el = rows.filter((r) => r.age > (days + 1) * D);
      return `${el.filter((r) => r[k]).length}/${el.length} (${pct(el.filter((r) => r[k]).length, el.length)})`;
    };
    const c = rows.map((r) => r.countries).filter((x) => typeof x === "number");
    const buyers = rows.filter((r) => r.orders.length);
    const subRev = {};
    for (const r of buyers) for (const o of r.orders) subRev[o.priceCurrencyCode] = (subRev[o.priceCurrencyCode] || 0) + (o.priceAmountMicros || 0) / 1e6;

    console.log(`\n[${g}] new installs ${n}`);
    console.log("  onboarding");
    console.log(`    passed welcome          ${cnt((r) => r.welcome)} (${pct(cnt((r) => r.welcome), n)})`);
    console.log(`    finished onboarding     ${cnt((r) => r.finished)} (${pct(cnt((r) => r.finished), n)})`);
    if (g === "direct_add")
      console.log(`    coach: My Trips + ${cnt((r) => r.coach1)}, later ${cnt((r) => r.coach1Skip)}, map + ${cnt((r) => r.coach2)}`);
    console.log(`    visited countries       median ${median(c) ?? "-"}, mean ${f(mean(c), 1)} (n=${c.length}), zero ${c.filter((x) => x === 0).length}`);
    console.log("  visits");
    console.log(`    opens per install       ${f(mean(rows.map((r) => r.opens)))} (day 0: ${f(mean(rows.map((r) => r.opens0)))})`);
    console.log(`    active days per install ${f(mean(rows.map((r) => r.activeDays)))}`);
    console.log("  retention (installs old enough)");
    console.log(`    D1 ${ret("d1", 1)}   D3 ${ret("d3", 3)}   D7 ${ret("d7", 7)}`);
    console.log("  ads");
    console.log(`    day-0 interstitials     mean ${f(mean(rows.map((r) => r.inter0)))}, none ${pct(cnt((r) => r.inter0 === 0), n)}`);
    console.log(`    ad revenue / install    day 0 $${f(mean(rows.map((r) => r.rev0)), 4)}, days 0–6 $${f(mean(rows.filter((r) => r.age > 7 * D).map((r) => r.rev7)), 4)} (installs ≥7d old), all $${f(mean(rows.map((r) => r.revAll)), 4)}`);
    console.log("  subscription");
    console.log(`    saw paywall             ${cnt((r) => r.paywall > 0)} (${pct(cnt((r) => r.paywall > 0), n)}), views ${rows.reduce((x, r) => x + r.paywall, 0)}`);
    console.log(`    started checkout        ${cnt((r) => r.checkout)} (${pct(cnt((r) => r.checkout), n)})`);
    console.log(`    purchased               ${buyers.length} (${pct(buyers.length, n)}) revenue ${Object.entries(subRev).map(([k, v]) => `${v.toFixed(2)} ${k}`).join(", ") || "-"}`);
    console.log("  rating");
    console.log(`    review prompt shown     ${cnt((r) => r.review)} (${pct(cnt((r) => r.review), n)})`);
  }
  console.log("\nStar ratings themselves are not visible per user; compare the store rating trend in Play Console / App Store Connect over the test window.");
}

main().catch((e) => {
  console.error("ERR", e.message);
  process.exit(1);
});
