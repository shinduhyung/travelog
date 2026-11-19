// Onboarding A/B report: 'tutorial' (6-step tutorial) vs 'direct_add'
// (skip tutorial, coach mark on My Trips Countries "+").
//
// Only devices first installed on 1.0.10+ get a group (onboardingAbGroup on
// app_open_events / ad_revenue_events / tutorial_step_events).
//
// Per group: new installs, onboarding finished, visited countries registered,
// day-0 interstitials and ad revenue (first 24h), day-1+ return (installs older
// than 48h), and the funnel of the onboarding steps.
//
// Usage (from jidoapp/functions):
//   node scripts/onboarding_ab_report.js
//   node scripts/onboarding_ab_report.js --platform android
//
// Auth: gcloud application-default login. Read-only.

const admin = require("firebase-admin");

const H = 3600 * 1000;
const G = ["tutorial", "direct_add"];

const median = (a) => {
  if (!a.length) return null;
  const s = [...a].sort((x, y) => x - y);
  return s[Math.floor(s.length / 2)];
};
const pct = (a, b) => (b ? `${((100 * a) / b).toFixed(0)}%` : "-");

async function main() {
  const args = process.argv.slice(2);
  const i = args.indexOf("--platform");
  const platform = i >= 0 ? args[i + 1] : null;

  admin.initializeApp({ projectId: "proboscis-2025" });
  const db = admin.firestore();
  const now = Date.now();

  const dev = new Map(); // deviceId -> {g, platform, opens:[], inter:[], rev, steps:Map}
  const get = (id, g) => {
    if (!dev.has(id)) dev.set(id, { g, opens: [], inter: [], rev: [], steps: new Map() });
    return dev.get(id);
  };

  const opens = await db.collection("app_open_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of opens.docs) {
    const d = doc.data();
    if (!d.deviceId || !d.timestamp) continue;
    if (platform && d.platform !== platform) continue;
    get(d.deviceId, d.onboardingAbGroup).opens.push(d.timestamp.toMillis());
  }
  const rev = await db.collection("ad_revenue_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of rev.docs) {
    const d = doc.data();
    if (!dev.has(d.deviceId) || !d.timestamp || d.currencyCode !== "USD") continue;
    const v = dev.get(d.deviceId);
    const t = d.timestamp.toMillis();
    v.rev.push({ t, r: Number(d.revenue) || 0 });
    if (d.format === "interstitial") v.inter.push(t);
  }
  const steps = await db.collection("tutorial_step_events").where("onboardingAbGroup", "in", G).get();
  for (const doc of steps.docs) {
    const d = doc.data();
    if (!dev.has(d.deviceId)) continue;
    const k = `${d.stepName}|${d.action}`;
    const s = dev.get(d.deviceId).steps;
    if (!s.has(k)) s.set(k, d.selections);
  }

  console.log(`Onboarding A/B (${platform || "all platforms"}) — ${new Date().toISOString()}`);
  for (const g of G) {
    const all = [...dev.values()].filter((v) => v.g === g && v.opens.length);
    const rows = all.map((v) => {
      v.opens.sort((a, b) => a - b);
      const t0 = v.opens[0];
      const d0 = (t) => t < t0 + 24 * H;
      const finished =
        v.steps.has("tutorial_countries|complete") ||
        v.steps.has("direct_coach|complete") ||
        v.steps.has("direct_coach|skip");
      const countries =
        v.steps.get("tutorial_countries|complete") ?? v.steps.get("direct_countries|complete") ?? null;
      return {
        welcome: v.steps.has("welcome|complete"),
        finished,
        countries,
        coachAdd: v.steps.has("direct_coach|complete"),
        coachSkip: v.steps.has("direct_coach|skip"),
        inter0: v.inter.filter(d0).length,
        rev0: v.rev.filter((x) => d0(x.t)).reduce((a, x) => a + x.r, 0),
        eligible: now - t0 > 48 * H,
        back: v.opens.some((t) => t >= t0 + 24 * H),
      };
    });
    const n = rows.length;
    const el = rows.filter((r) => r.eligible);
    const c = rows.map((r) => r.countries).filter((x) => typeof x === "number");
    console.log(`\n[${g}] new installs ${n}`);
    console.log(`  passed welcome        ${rows.filter((r) => r.welcome).length} (${pct(rows.filter((r) => r.welcome).length, n)})`);
    console.log(`  finished onboarding   ${rows.filter((r) => r.finished).length} (${pct(rows.filter((r) => r.finished).length, n)})`);
    if (g === "direct_add")
      console.log(`  coach: tapped + ${rows.filter((r) => r.coachAdd).length}, later ${rows.filter((r) => r.coachSkip).length}`);
    console.log(`  visited countries     median ${median(c) ?? "-"}, mean ${c.length ? (c.reduce((a, b) => a + b, 0) / c.length).toFixed(1) : "-"} (n=${c.length}), zero ${c.filter((x) => x === 0).length}`);
    console.log(`  day-0 interstitials   mean ${(rows.reduce((a, r) => a + r.inter0, 0) / (n || 1)).toFixed(2)}, none ${pct(rows.filter((r) => r.inter0 === 0).length, n)}`);
    console.log(`  day-0 ad revenue      $${(rows.reduce((a, r) => a + r.rev0, 0) / (n || 1)).toFixed(4)} per install`);
    console.log(`  day-1+ return         ${el.filter((r) => r.back).length}/${el.length} (${pct(el.filter((r) => r.back).length, el.length)})`);
  }
}

main().catch((e) => {
  console.error("ERR", e.message);
  process.exit(1);
});
