// 제휴업체 생애주기 로직 로컬 테스트 (가짜 Firestore 사용, 네트워크/운영 데이터 접근 없음).
// 실행: node scripts/test_partner_lifecycle.js
const assert = require("assert");
const admin = require("firebase-admin");
const { handlePlayLifecycle, handleAppleLifecycle, decidePlayReconcile, PLAY } = require("../partner_lifecycle");
const { renderPartnerPage } = require("../partner_page");

function fakeDb(seed = {}) {
  const cols = {};
  for (const [c, docs] of Object.entries(seed)) cols[c] = JSON.parse(JSON.stringify(docs));
  const col = (name) => (cols[name] ??= {});
  const isDel = (v) => v && typeof v === "object" && String(v.constructor?.name).includes("Delete");
  const docRef = (name, id) => ({
    async create(d) { if (col(name)[id]) { const e = new Error("already exists"); e.code = 6; throw e; } col(name)[id] = { ...d }; },
    async get() { const d = col(name)[id]; return { exists: !!d, data: () => d, id }; },
    async update(p) { const d = col(name)[id]; if (!d) throw new Error("not found"); for (const [k, v] of Object.entries(p)) { if (isDel(v)) delete d[k]; else d[k] = v; } },
    async set(d) { col(name)[id] = { ...d }; },
    async delete() { delete col(name)[id]; },
  });
  return {
    _cols: cols,
    collection(name) {
      return {
        doc: (id) => docRef(name, id),
        where(field, op, val) {
          const match = () => Object.entries(col(name)).filter(([, d]) => (op === "==" ? d[field] === val : (d[field] ?? []).includes(val)));
          return {
            limit() { return { async get() { const h = match(); return { empty: !h.length, docs: h.slice(0, 1).map(([id, d]) => ({ id, data: () => d })) }; } }; },
            async get() { return { docs: match().map(([id, d]) => ({ id, data: () => d })) }; },
          };
        },
      };
    },
  };
}
const T = admin.firestore.Timestamp;
let n = 0;
const ok = (m) => { n++; console.log("  ok:", m); };

(async () => {
  // ── 안드로이드 ──
  let db = fakeDb({ partner_events: { "GPA.1": { partnerId: "p", status: "trial", purchaseToken: "tok1", startedAt: T.now() } } });
  assert.equal(await handlePlayLifecycle(db, { type: PLAY.RENEWED, purchaseToken: "nope", sub: null }), "no-event-for-token"); ok("android: 모르는 토큰은 무시");
  assert.match(await handlePlayLifecycle(db, { type: PLAY.RENEWED, purchaseToken: "tok1", sub: { lineItems: [{ offerPhase: { freeTrial: {} } }] } }), /still-free-trial/);
  assert.equal(db._cols.partner_events["GPA.1"].status, "trial"); ok("android: 갱신이지만 아직 체험 단계면 전환 아님");
  await handlePlayLifecycle(db, { type: PLAY.CANCELED, purchaseToken: "tok1" });
  assert.ok(db._cols.partner_events["GPA.1"].trialCanceledAt); ok("android: 체험 중 해지 기록");
  assert.match(await handlePlayLifecycle(db, { type: PLAY.RENEWED, purchaseToken: "tok1", sub: { lineItems: [{ offerPhase: { basePrice: {} } }] } }), /converted/);
  assert.equal(db._cols.partner_events["GPA.1"].status, "paid"); ok("android: 정가 단계 갱신 -> 유료 전환");
  assert.match(await handlePlayLifecycle(db, { type: PLAY.RENEWED, purchaseToken: "tok1", sub: null }), /ignored/); ok("android: 이미 paid면 중복 전환 안 함");
  await handlePlayLifecycle(db, { type: PLAY.REVOKED, purchaseToken: "tok1" });
  assert.equal(db._cols.partner_events["GPA.1"].status, "refunded"); ok("android: 환불");
  db = fakeDb({ partner_events: { "GPA.2": { partnerId: "p", status: "trial", purchaseToken: "tok2", startedAt: T.now() } } });
  await handlePlayLifecycle(db, { type: PLAY.EXPIRED, purchaseToken: "tok2" });
  assert.equal(db._cols.partner_events["GPA.2"].status, "expired"); ok("android: 전환 없이 만료");

  // ── 애플 ──
  db = fakeDb({ partners: { acme: { appleOffers: ["acme_yearly_3m"], codes: ["ACME90"] }, test: { appleOffers: ["test_yearly_3m"] } } });
  const start = { originalTransactionId: "900", productId: "travelog_premium_yearly_v2", purchaseDate: Date.UTC(2026, 10, 9), offerType: 3, offerIdentifier: "test_yearly_3m", offerDiscountType: "FREE_TRIAL", storefront: "KOR" };
  assert.equal(await handleAppleLifecycle(db, { type: "SUBSCRIBED", subtype: "INITIAL_BUY", tx: start, sandbox: false }), "start-recorded");
  const ev = db._cols.partner_events.ios_900;
  assert.equal(ev.partnerId, "test"); assert.equal(ev.status, "trial"); assert.equal(ev.platform, "ios"); ok("ios: 오퍼 식별자로 업체 매핑, 체험 시작 기록");
  { const noDisc = { ...start, originalTransactionId: "905", offerDiscountType: undefined }; await handleAppleLifecycle(db, { type: "SUBSCRIBED", tx: noDisc }); assert.equal(db._cols.partner_events.ios_905.status, "trial"); ok("ios: offerDiscountType 없어도 체험으로 시작"); }
  assert.equal(await handleAppleLifecycle(db, { type: "OFFER_REDEEMED", subtype: "INITIAL_BUY", tx: start }), "start-duplicate"); ok("ios: 같은 구독 시작 중복 방지");
  assert.match(await handleAppleLifecycle(db, { type: "SUBSCRIBED", tx: { ...start, originalTransactionId: "901", offerIdentifier: "stranger" } }), /no-partner/);
  assert.ok(!db._cols.partner_events.ios_901); ok("ios: 매핑 없는 오퍼는 기록 안 함");
  assert.equal(await handleAppleLifecycle(db, { type: "SUBSCRIBED", tx: { originalTransactionId: "902", productId: "x" } }), "start-without-offer"); ok("ios: 오퍼 없는 일반 구독은 무시");
  await handleAppleLifecycle(db, { type: "DID_CHANGE_RENEWAL_STATUS", subtype: "AUTO_RENEW_DISABLED", tx: start });
  assert.ok(db._cols.partner_events.ios_900.trialCanceledAt); ok("ios: 체험 중 자동 갱신 끔");
  await handleAppleLifecycle(db, { type: "DID_CHANGE_RENEWAL_STATUS", subtype: "AUTO_RENEW_ENABLED", tx: start });
  assert.ok(!db._cols.partner_events.ios_900.trialCanceledAt); ok("ios: 자동 갱신 다시 켬 -> 해지 표시 제거");
  assert.equal(await handleAppleLifecycle(db, { type: "DID_RENEW", tx: { ...start, offerType: 3, offerDiscountType: undefined } }), "renew-still-in-offer"); ok("ios: 오퍼가 붙은 0원 갱신은 전환 아님(offerDiscountType 없어도)");
  assert.equal(await handleAppleLifecycle(db, { type: "DID_RENEW", tx: { originalTransactionId: "900", purchaseDate: Date.UTC(2027, 1, 7), price: 19900000, currency: "KRW" } }), "converted");
  const paid = db._cols.partner_events.ios_900; assert.equal(paid.status, "paid"); assert.equal(paid.paidAmount, 19900); ok("ios: 오퍼 없는 갱신 -> 유료 전환(금액 19,900)");
  assert.match(await handleAppleLifecycle(db, { type: "DID_RENEW", tx: { originalTransactionId: "900" } }), /ignored/); ok("ios: 이미 paid면 중복 전환 안 함");
  await handleAppleLifecycle(db, { type: "REFUND", tx: start });
  assert.equal(db._cols.partner_events.ios_900.status, "refunded"); ok("ios: 환불");
  await handleAppleLifecycle(db, { type: "SUBSCRIBED", tx: { ...start, originalTransactionId: "910" }, sandbox: true });
  assert.equal(db._cols.partner_events.ios_910.isTest, true);
  await handleAppleLifecycle(db, { type: "EXPIRED", subtype: "VOLUNTARY", tx: { originalTransactionId: "910" } });
  assert.equal(db._cols.partner_events.ios_910.status, "expired"); ok("ios: 샌드박스는 isTest, 전환 없이 만료");


  // ── 안드로이드 점검(reconcile) ──
  const ev0 = { status: "trial" };
  const mk = (state, phase, autoRenew) => ({ subscriptionState: state, lineItems: [{ offerPhase: phase, autoRenewingPlan: { autoRenewEnabled: autoRenew } }] });
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_ACTIVE", { basePrice: {} }, true)).result, "converted"); ok("reconcile: 활성 + 정가 단계 -> 전환");
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_CANCELED", { basePrice: {} }, false)).result, "converted"); ok("reconcile: 정가 결제 후 해지(만료 전)도 전환으로 인정");
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_ON_HOLD", { basePrice: {} }, true)).result, "phase-unknown"); ok("reconcile: 결제 보류(ON_HOLD)는 전환으로 세지 않음");
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_EXPIRED", { freeTrial: {} }, false)).result, "expired-without-conversion"); ok("reconcile: 체험 중 만료 -> expired");
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_ACTIVE", { freeTrial: {} }, true)).patch, null); ok("reconcile: 체험 중이면 변경 없음");
  assert.equal(decidePlayReconcile(ev0, mk("SUBSCRIPTION_STATE_ACTIVE", { freeTrial: {} }, false)).result, "trial-auto-renew-off"); ok("reconcile: 체험 중 자동 갱신 꺼짐 표시");
  assert.equal(decidePlayReconcile(ev0, { subscriptionState: "SUBSCRIPTION_STATE_CANCELED", lineItems: [{ offerPhase: { freeTrial: {} } }] }).result, "trial-auto-renew-off"); ok("reconcile: 실제 응답 형태(CANCELED, autoRenew 필드 없음) -> 체험 중 해지");
  assert.equal(decidePlayReconcile({ status: "trial", trialCanceledAt: 1 }, mk("SUBSCRIPTION_STATE_ACTIVE", { freeTrial: {} }, false)).patch, null); ok("reconcile: 이미 표시했으면 다시 쓰지 않음");
  assert.equal(decidePlayReconcile(ev0, { subscriptionState: "SUBSCRIPTION_STATE_ACTIVE", lineItems: [{}] }).result, "phase-unknown"); ok("reconcile: 단계를 모르면 아무것도 바꾸지 않음");

  // ── 페이지 렌더 ──
  const d = (k) => new Date(Date.UTC(2026, 10, 9 - k));
  const html = renderPartnerPage({ partner: { name: "Acme", codes: ["ACME90"], rewardPerTrial: 1, rewardPerConversion: 4, minPayout: 10 }, now: d(0), events: [
    { code: "ACME90", platform: "android", status: "paid", startedAt: d(1), regionCode: "KR" },
    { code: "ACME90", platform: "ios", status: "trial", startedAt: d(0), regionCode: "KOR" },
    { code: "ACME90", platform: "android", status: "trial", trialCanceled: true, startedAt: d(2), regionCode: "US" },
    { code: "ACME90", platform: "android", status: "expired", startedAt: d(3), regionCode: "US" }] });
  assert.match(html, /\$8\.00/); ok("page: 확정 수익 = 4건x$1 + 전환 1건x$4 = $8.00");
  assert.match(html, /\+ \$4\.00 if active trials convert/); ok("page: 진행 중 체험 1건 -> 예상 +$4.00");
  assert.match(html, />Cancelled</); assert.match(html, /App Store/); assert.match(html, /Google Play/); ok("page: 상태 표시와 스토어 표시");
  console.log("\nALL " + n + " CHECKS PASSED");
})().catch((e) => { console.error("FAILED:", e.message); process.exit(1); });
