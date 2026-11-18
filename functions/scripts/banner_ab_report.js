// Android banner A/B test report: banner_on vs banner_off.
//
// The app assigns each Android device once (50:50) and writes the group as
// `bannerAbGroup` on app_open_events and ad_revenue_events. Subscription orders
// are joined by deviceId.
//
// Usage (from the jidoapp/functions folder):
//   node scripts/banner_ab_report.js            -> all data since the test began
//   node scripts/banner_ab_report.js --days 14  -> only devices assigned in the last 14 days
//
// Auth: gcloud application-default login (same as set_admin_claim.js). Read-only.

const admin = require("firebase-admin");

const GROUPS = ["banner_on", "banner_off"];
const DAY = 24 * 60 * 60 * 1000;
const RETENTION_DAYS = [1, 3, 7, 14, 30];

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  return new Date(v);
}

function pct(n, d) {
  return d ? `${((100 * n) / d).toFixed(1)}%` : "-";
}

function money(v) {
  return `$${v.toFixed(2)}`;
}

async function main() {
  const args = process.argv.slice(2);
  const daysIdx = args.indexOf("--days");
  const sinceDays = daysIdx >= 0 ? Number(args[daysIdx + 1]) : null;

  admin.initializeApp({ projectId: "proboscis-2025" });
  const db = admin.firestore();
  const now = Date.now();
  const cutoff = sinceDays ? new Date(now - sinceDays * DAY) : null;

  // 1) Devices and their app opens.
  const opens = await db.collection("app_open_events").where("bannerAbGroup", "in", GROUPS).get();
  const devices = new Map(); // deviceId -> {group, assignedAt, newInstall, opens: [Date]}
  for (const doc of opens.docs) {
    const d = doc.data();
    if (!d.deviceId) continue;
    const ts = toDate(d.timestamp);
    if (!ts) continue;
    let dev = devices.get(d.deviceId);
    if (!dev) {
      dev = { group: d.bannerAbGroup, assignedAt: null, newInstall: false, opens: [] };
      devices.set(d.deviceId, dev);
    }
    const assigned = toDate(d.bannerAbAssignedAt) || ts;
    if (!dev.assignedAt || assigned < dev.assignedAt) dev.assignedAt = assigned;
    if (d.bannerAbAssignedThisLaunch && d.firstLaunch) dev.newInstall = true;
    dev.opens.push(ts);
  }
  if (cutoff) {
    for (const [id, dev] of devices) if (dev.assignedAt < cutoff) devices.delete(id);
  }

  // 2) Ad revenue per group (only events from devices in the cohort).
  const revenue = await db.collection("ad_revenue_events").where("bannerAbGroup", "in", GROUPS).get();
  const rev = {};
  for (const g of GROUPS) rev[g] = { total: 0, byFormat: {} };
  for (const doc of revenue.docs) {
    const d = doc.data();
    const dev = devices.get(d.deviceId);
    if (!dev || d.currencyCode !== "USD") continue;
    const r = Number(d.revenue) || 0;
    rev[dev.group].total += r;
    rev[dev.group].byFormat[d.format || "unknown"] = (rev[dev.group].byFormat[d.format || "unknown"] || 0) + r;
  }

  // 3) Subscription purchases after assignment, joined by deviceId.
  const orders = await db.collection("orders").where("platform", "==", "android").get();
  const subs = {};
  for (const g of GROUPS) subs[g] = { buyers: new Set(), orders: 0 };
  for (const doc of orders.docs) {
    const d = doc.data();
    const dev = devices.get(d.deviceId);
    if (!dev || d.isRenewal) continue;
    const t = toDate(d.purchaseTime);
    if (!t || t < dev.assignedAt) continue;
    subs[dev.group].buyers.add(d.deviceId);
    subs[dev.group].orders += 1;
  }

  // 4) Per-group summary.
  const rows = {};
  for (const g of GROUPS) {
    rows[g] = { devices: 0, newInstalls: 0, activeDays: 0, ret: {} };
    for (const n of RETENTION_DAYS) rows[g].ret[n] = { eligible: 0, returned: 0 };
  }
  for (const dev of devices.values()) {
    const row = rows[dev.group];
    row.devices += 1;
    if (dev.newInstall) row.newInstalls += 1;
    // assignedAt is the device clock, open timestamps are server time: clamp small skew to day 0.
    const dayIdx = new Set(dev.opens.map((t) => Math.max(0, Math.floor((t - dev.assignedAt) / DAY))));
    row.activeDays += dayIdx.size;
    const age = Math.floor((now - dev.assignedAt) / DAY);
    for (const n of RETENTION_DAYS) {
      if (age < n + 1) continue; // day n not fully over yet
      row.ret[n].eligible += 1;
      if ([...dayIdx].some((i) => i >= n)) row.ret[n].returned += 1;
    }
  }

  console.log(`Banner A/B report (${sinceDays ? `assigned in last ${sinceDays} days` : "all data"}) — ${new Date().toISOString()}`);
  console.log("Retention = came back on day N or later after assignment. Revenue in USD from ad_revenue_events.\n");
  for (const g of GROUPS) {
    const r = rows[g];
    const fmt = Object.entries(rev[g].byFormat).map(([k, v]) => `${k} ${money(v)}`).join(", ") || "-";
    console.log(`== ${g}`);
    console.log(`  devices: ${r.devices} (new installs ${r.newInstalls}), active device-days: ${r.activeDays}`);
    console.log(`  ad revenue: ${money(rev[g].total)} [${fmt}]`);
    console.log(`  ad revenue per device: ${r.devices ? money(rev[g].total / r.devices) : "-"}, per active device-day: ${r.activeDays ? money(rev[g].total / r.activeDays) : "-"}`);
    console.log(`  retention: ${RETENTION_DAYS.map((n) => `D${n}+ ${pct(r.ret[n].returned, r.ret[n].eligible)} (n=${r.ret[n].eligible})`).join(" | ")}`);
    console.log(`  subscription buyers after assignment: ${subs[g].buyers.size} (${pct(subs[g].buyers.size, r.devices)}), orders ${subs[g].orders}`);
  }
}

main().catch((e) => {
  console.error("ERR", e.message);
  process.exit(1);
});
