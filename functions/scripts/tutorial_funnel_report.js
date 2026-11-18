// Welcome + onboarding tutorial step funnel (where new users drop off).
//
// The app writes one tutorial_step_events doc per step view/complete
// (step -1 = welcome, 0..5 = tutorial steps). Each device is counted once per
// step, so this shows how many devices reached / finished each step.
//
// Usage (from the jidoapp/functions folder):
//   node scripts/tutorial_funnel_report.js            -> all data
//   node scripts/tutorial_funnel_report.js --days 7   -> events from the last 7 days
//   node scripts/tutorial_funnel_report.js --platform android
//
// Auth: gcloud application-default login. Read-only.

const admin = require("firebase-admin");

const DAY = 24 * 60 * 60 * 1000;
const STEPS = [
  [-1, "welcome"],
  [0, "home_country"],
  [1, "passport_airport"],
  [2, "highlights"],
  [3, "popular_countries"],
  [4, "gawc_cities"],
  [5, "top_landmarks"],
];

function median(a) {
  if (!a.length) return null;
  const s = [...a].sort((x, y) => x - y);
  return s[Math.floor(s.length / 2)];
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : null;
  };
  const days = opt("--days") ? Number(opt("--days")) : null;
  const platform = opt("--platform");

  admin.initializeApp({ projectId: "proboscis-2025" });
  let q = admin.firestore().collection("tutorial_step_events");
  if (days) q = q.where("timestamp", ">=", new Date(Date.now() - days * DAY));
  const snap = await q.get();

  // step -> {view:Set, complete:Set, login:Set, viewAt: Map(device->ms), doneAt: Map, selections: []}
  const by = new Map(STEPS.map(([s]) => [s, { view: new Set(), complete: new Set(), login: new Set(), viewAt: new Map(), doneAt: new Map(), selections: [] }]));
  for (const doc of snap.docs) {
    const d = doc.data();
    if (!d.deviceId || !by.has(d.step)) continue;
    if (platform && d.platform !== platform) continue;
    const r = by.get(d.step);
    if (d.action === "view") {
      r.view.add(d.deviceId);
      if (!r.viewAt.has(d.deviceId)) r.viewAt.set(d.deviceId, d.elapsedMs);
    } else if (d.action === "complete") {
      r.complete.add(d.deviceId);
      if (!r.doneAt.has(d.deviceId)) r.doneAt.set(d.deviceId, d.elapsedMs);
      if (typeof d.selections === "number") r.selections.push(d.selections);
    } else if (d.action === "login") {
      r.login.add(d.deviceId);
    }
  }

  const start = by.get(-1).view.size || 1;
  console.log(`Tutorial funnel (${days ? `last ${days} days` : "all data"}${platform ? `, ${platform}` : ""}) — ${new Date().toISOString()}`);
  console.log("step                    viewed  done  drop-in-step  % of welcome  median sec in step  median selections");
  for (const [s, name] of STEPS) {
    const r = by.get(s);
    const secs = [];
    for (const [dev, v] of r.viewAt) {
      const done = r.doneAt.get(dev);
      if (typeof v === "number" && typeof done === "number" && done >= v) secs.push((done - v) / 1000);
    }
    const drop = r.view.size ? `${(100 * (1 - r.complete.size / r.view.size)).toFixed(0)}%` : "-";
    const sel = median(r.selections);
    const sec = median(secs);
    console.log(
      `${String(s).padStart(2)} ${name.padEnd(20)} ${String(r.view.size).padStart(6)} ${String(r.complete.size).padStart(5)} ${drop.padStart(13)} ${`${((100 * r.view.size) / start).toFixed(0)}%`.padStart(13)} ${(sec === null ? "-" : sec.toFixed(0)).padStart(19)} ${(sel === null ? "-" : String(sel)).padStart(18)}`,
    );
    if (s === -1 && r.login.size) console.log(`   (welcome -> "I already have an account": ${r.login.size})`);
  }
}

main().catch((e) => {
  console.error("ERR", e.message);
  process.exit(1);
});
