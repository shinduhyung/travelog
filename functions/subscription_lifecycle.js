// 구독 생애주기 기록 (모든 구독, 제휴 여부 무관).
//
// 스토어 알림(애플 App Store Server Notifications V2, 구글 Play RTDN)을 받을 때마다
//   subscription_lifecycle_events/{eventId}   알림 1건 = 문서 1건 (추가만, 수정 없음)
//     eventId: 애플 = notificationUUID, 구글 = Pub/Sub messageId (없으면 token+type+eventTime 해시)
//   subscription_states/{key}                 구독 1건의 최신 상태
//     key: iOS = originalTransactionId, Android = purchaseToken (길거나 '/' 포함 시 sha256)
// 를 쓴다. 그리고 앱이 다시 열리지 않아도 대시보드가 갱신 결제를 셀 수 있게, 갱신 알림이 오면
// orders/{주문ID} 문서를 (없을 때만) 만든다. 문서 ID는 앱이 쓰는 것과 같아서 중복 생성되지 않는다.
//
// 스토어 ID(거래/주문/토큰) 외의 개인정보는 넣지 않는다. 이미 앱이 orders 문서에 붙여 둔 uid만
// 연결용으로 복사한다. 호출하는 쪽(apple_notifications.js, partner_system.js)은 이 모듈의 실패가
// 기존 처리에 영향을 주지 않도록 반드시 try/catch로 감싸서 부른다.

const admin = require("firebase-admin");
const crypto = require("crypto");

const EVENTS = "subscription_lifecycle_events";
const STATES = "subscription_states";
const ORDERS = "orders";

const ts = (ms) => (ms != null && Number.isFinite(Number(ms)) ? admin.firestore.Timestamp.fromMillis(Number(ms)) : null);
const tsIso = (iso) => { if (!iso) return null; const ms = Date.parse(iso); return Number.isFinite(ms) ? admin.firestore.Timestamp.fromMillis(ms) : null; };
const sha = (s) => crypto.createHash("sha256").update(String(s)).digest("hex");
const safeId = (s) => (s && !String(s).includes("/") && String(s).length <= 700 ? String(s) : sha(s));
const isAlreadyExists = (e) => e?.code === 6 || /already exists/i.test(e?.message ?? "");
const millisOf = (t) => (t && typeof t.toMillis === "function" ? t.toMillis() : null);

// ---------------------------------------------------------------- 타입 정규화

// 애플 notificationType/subtype → 정규화 타입
function normalizeApple(type, subtype) {
  switch (type) {
    case "SUBSCRIBED": return "SUBSCRIBED"; // subtype INITIAL_BUY / RESUBSCRIBE
    case "DID_RENEW": return subtype === "BILLING_RECOVERY" ? "RECOVERED" : "RENEWED";
    case "DID_CHANGE_RENEWAL_STATUS": return subtype === "AUTO_RENEW_DISABLED" ? "CANCELED" : "UNCANCELED";
    case "DID_FAIL_TO_RENEW": return subtype === "GRACE_PERIOD" ? "GRACE" : "BILLING_RETRY";
    case "GRACE_PERIOD_EXPIRED": return "BILLING_RETRY";
    case "EXPIRED": return "EXPIRED"; // subtype VOLUNTARY / BILLING_RETRY / PRICE_INCREASE / PRODUCT_NOT_FOR_SALE
    case "REFUND": return "REFUNDED";
    case "REFUND_DECLINED": return "REFUND_DECLINED";
    case "REFUND_REVERSED": return "REFUND_REVERSED";
    case "REVOKE": return "REVOKED";
    case "PRICE_INCREASE": return "PRICE_INCREASE";
    case "DID_CHANGE_RENEWAL_PREF": return "PLAN_CHANGE";
    case "OFFER_REDEEMED": return "OFFER_REDEEMED";
    case "RENEWAL_EXTENDED": return "RENEWAL_EXTENDED";
    case "ONE_TIME_CHARGE": return "ONE_TIME_PURCHASE";
    case "CONSUMPTION_REQUEST": return "CONSUMPTION_REQUEST";
    case "TEST": return "TEST";
    default: return type ?? "UNKNOWN";
  }
}

// Play subscriptionNotification.notificationType (숫자) → [원래 이름, 정규화 타입]
const PLAY_TYPES = {
  1: ["SUBSCRIPTION_RECOVERED", "RECOVERED"],
  2: ["SUBSCRIPTION_RENEWED", "RENEWED"],
  3: ["SUBSCRIPTION_CANCELED", "CANCELED"],
  4: ["SUBSCRIPTION_PURCHASED", "SUBSCRIBED"],
  5: ["SUBSCRIPTION_ON_HOLD", "BILLING_RETRY"],
  6: ["SUBSCRIPTION_IN_GRACE_PERIOD", "GRACE"],
  7: ["SUBSCRIPTION_RESTARTED", "UNCANCELED"],
  8: ["SUBSCRIPTION_PRICE_CHANGE_CONFIRMED", "PRICE_INCREASE"],
  9: ["SUBSCRIPTION_DEFERRED", "RENEWAL_EXTENDED"],
  10: ["SUBSCRIPTION_PAUSED", "PAUSED"],
  11: ["SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED", "PAUSE_SCHEDULE_CHANGED"],
  12: ["SUBSCRIPTION_REVOKED", "REVOKED"],
  13: ["SUBSCRIPTION_EXPIRED", "EXPIRED"],
  17: ["SUBSCRIPTION_ITEMS_CHANGED", "PLAN_CHANGE"],
  18: ["SUBSCRIPTION_CANCELLATION_SCHEDULED", "CANCELLATION_SCHEDULED"],
  19: ["SUBSCRIPTION_PRICE_CHANGE_UPDATED", "PRICE_INCREASE"],
  20: ["SUBSCRIPTION_PENDING_PURCHASE_CANCELED", "PENDING_CANCELED"],
};

// 정규화 타입 → 상태 (null = 상태를 바꾸지 않는 정보성 알림)
const STATUS_BY_TYPE = {
  SUBSCRIBED: "active", RENEWED: "active", RECOVERED: "active", UNCANCELED: "active",
  RENEWAL_EXTENDED: "active", REFUND_REVERSED: "active", OFFER_REDEEMED: "active", ONE_TIME_PURCHASE: "active",
  CANCELED: "canceled", // 자동 갱신 꺼짐, 만료일까지는 이용 가능
  GRACE: "grace", BILLING_RETRY: "billing_retry", PAUSED: "paused",
  EXPIRED: "expired", PENDING_CANCELED: "expired", REFUNDED: "refunded", REVOKED: "revoked",
};

// 애플 notification data.status: 1 active, 2 expired, 3 billing retry, 4 grace, 5 revoked
const APPLE_DATA_STATUS = { 1: "active", 2: "expired", 3: "billing_retry", 4: "grace", 5: "revoked" };

// Play subscriptionsv2 subscriptionState → 상태
const PLAY_STATE = {
  SUBSCRIPTION_STATE_ACTIVE: "active",
  SUBSCRIPTION_STATE_CANCELED: "canceled",
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "grace",
  SUBSCRIPTION_STATE_ON_HOLD: "billing_retry",
  SUBSCRIPTION_STATE_PAUSED: "paused",
  SUBSCRIPTION_STATE_EXPIRED: "expired",
  SUBSCRIPTION_STATE_PENDING: "pending",
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "expired",
};

// ---------------------------------------------------------------- 공통

// orders 문서와 연결 (문서 ID 직접 조회 최대 2회, 쿼리/인덱스 없음)
// 서버가 만든 갱신 주문 문서에는 uid가 없으므로, uid가 있는 문서(보통 최초 주문)를 우선한다.
async function findOrder(db, ids) {
  let found = { orderDocId: null, uid: null };
  for (const id of [...new Set(ids.filter(Boolean))]) {
    try {
      const snap = await db.collection(ORDERS).doc(safeId(id)).get();
      if (!snap.exists) continue;
      const uid = snap.data()?.uid ?? null;
      if (uid) return { orderDocId: snap.id, uid };
      if (!found.orderDocId) found = { orderDocId: snap.id, uid: null };
    } catch (e) { console.error(`[lifecycle] order lookup failed (${id}):`, e.message); }
  }
  return found;
}

// 이벤트 1건 기록 + 상태 문서 갱신. 이미 기록된 이벤트면 아무것도 안 하고 "duplicate".
async function writeEvent(db, eventId, event, stateKey, statePatch) {
  const now = admin.firestore.Timestamp.now();
  try {
    await db.collection(EVENTS).doc(safeId(eventId)).create({ ...event, stateKey: stateKey ?? null, receivedAt: now });
  } catch (e) {
    if (isAlreadyExists(e)) return "duplicate";
    throw e;
  }
  if (!stateKey) return "event-only";

  const ref = db.collection(STATES).doc(stateKey);
  return db.runTransaction(async (t) => {
    const cur = await t.get(ref);
    const prev = cur.exists ? cur.data() : null;
    const prevAt = millisOf(prev?.lastEventAt);
    const thisAt = millisOf(event.eventAt);
    // 늦게 도착한 옛 알림은 최신 상태를 덮어쓰지 않는다 (이벤트 문서는 이미 남겼음).
    const stale = prevAt != null && thisAt != null && thisAt < prevAt;
    const patch = { updatedAt: now };
    if (!stale) {
      for (const [k, v] of Object.entries(statePatch)) if (v !== undefined && v !== null) patch[k] = v;
      patch.lastEventType = event.type;
      patch.lastEventId = safeId(eventId);
      if (event.eventAt) patch.lastEventAt = event.eventAt;
    } else {
      // 연결 정보는 옛 알림이어도 채운다
      if (statePatch.orderDocId && !prev?.orderDocId) patch.orderDocId = statePatch.orderDocId;
      if (statePatch.uid && !prev?.uid) patch.uid = statePatch.uid;
    }
    if (!prev) { patch.createdAt = now; patch.firstEventType = event.type; }
    t.set(ref, patch, { merge: true });
    return stale ? "event+stale-state" : "event+state";
  });
}

// ---------------------------------------------------------------- iOS

// decoded: verifyAndDecodeNotification 결과, tx: 디코딩된 signedTransactionInfo, renewal: 디코딩된 signedRenewalInfo
async function recordAppleLifecycle(db, { decoded, tx, renewal, sandbox }) {
  const rawType = decoded.notificationType ?? null;
  const rawSubtype = decoded.subtype ?? null;
  const type = normalizeApple(rawType, rawSubtype);
  const data = decoded.data ?? {};
  const originalTransactionId = tx?.originalTransactionId ?? renewal?.originalTransactionId ?? null;
  const productId = tx?.productId ?? renewal?.productId ?? null;
  const expiresAt = ts(tx?.expiresDate);
  const autoRenew = renewal?.autoRenewStatus != null ? renewal.autoRenewStatus === 1 : null;
  const order = originalTransactionId ? await findOrder(db, [tx?.transactionId, originalTransactionId]) : { orderDocId: null, uid: null };

  const event = {
    platform: "ios",
    type,
    rawType,
    rawSubtype,
    productId,
    originalTransactionId,
    transactionId: tx?.transactionId ?? null,
    transactionReason: tx?.transactionReason ?? null, // PURCHASE / RENEWAL
    offerType: tx?.offerType ?? null,
    offerIdentifier: tx?.offerIdentifier ?? null,
    expiresAt,
    purchaseAt: ts(tx?.purchaseDate),
    revocationAt: ts(tx?.revocationDate),
    revocationReason: tx?.revocationReason ?? null,
    price: tx?.price != null ? tx.price / 1000 : null, // 애플 price는 1/1000 단위
    priceMicros: tx?.price != null ? tx.price * 1000 : null,
    currency: tx?.currency ?? null,
    storefront: tx?.storefront ?? null,
    autoRenew,
    autoRenewProductId: renewal?.autoRenewProductId ?? null,
    expirationIntent: renewal?.expirationIntent ?? null,
    isInBillingRetryPeriod: renewal?.isInBillingRetryPeriod ?? null,
    gracePeriodExpiresAt: ts(renewal?.gracePeriodExpiresDate),
    priceIncreaseStatus: renewal?.priceIncreaseStatus ?? null,
    appleDataStatus: data.status ?? null,
    environment: data.environment ?? tx?.environment ?? (sandbox ? "Sandbox" : "Production"),
    sandbox: !!sandbox,
    eventAt: ts(decoded.signedDate) ?? admin.firestore.Timestamp.now(),
    orderDocId: order.orderDocId,
    uid: order.uid,
  };

  let status = STATUS_BY_TYPE[type] ?? null;
  // 정보성 알림(가격 인상 안내 등)은 애플이 같이 보내 주는 현재 상태를 쓴다.
  if (!status && data.status != null) status = APPLE_DATA_STATUS[data.status] ?? null;
  // 해지 철회가 아닌데 자동 갱신이 꺼져 있고 아직 활성이면 canceled로 본다.
  if (status === "active" && autoRenew === false) status = "canceled";

  const statePatch = {
    platform: "ios",
    status,
    autoRenew,
    expiresAt,
    productId,
    originalTransactionId,
    latestTransactionId: tx?.transactionId ?? null,
    storefront: tx?.storefront ?? null,
    sandbox: !!sandbox,
    orderDocId: order.orderDocId,
    uid: order.uid,
  };
  if (type === "REFUNDED") statePatch.lastRefundAt = event.revocationAt ?? event.eventAt;

  const result = await writeEvent(db, decoded.notificationUUID ?? sha(`${rawType}|${rawSubtype}|${tx?.transactionId}|${decoded.signedDate}`),
    event, originalTransactionId ? safeId(originalTransactionId) : null, statePatch);

  let orderResult = "-";
  if (result !== "duplicate") orderResult = await upsertAppleOrder(db, { type, rawType, tx, sandbox });
  return `${type} ${result} order=${orderResult}`;
}

// 갱신 결제를 orders에 남긴다 (subscription_renewal_check.js와 같은 형식, 문서 ID = transactionId).
// DID_RENEW는 없으면 만들고 있으면 knownExpiresDate만 맞춘다. SUBSCRIBED는 없을 때만 만든다.
// 이미 있는 문서의 purchaseTime/uid는 절대 덮어쓰지 않는다.
async function upsertAppleOrder(db, { type, rawType, tx, sandbox }) {
  if (sandbox) return "skip-sandbox";
  if (!tx?.transactionId || !tx.expiresDate) return "skip-no-tx";
  if (rawType !== "DID_RENEW" && rawType !== "SUBSCRIBED") return "skip-type";
  const ref = db.collection(ORDERS).doc(safeId(tx.transactionId));
  const price = tx.price;
  try {
    await ref.create({
      orderId: tx.transactionId,
      originalTransactionId: tx.originalTransactionId ?? null,
      productId: tx.productId ?? null,
      isLifetime: false,
      purchaseTime: ts(tx.purchaseDate) ?? admin.firestore.Timestamp.now(),
      platform: "ios",
      status: "purchased",
      priceAmountMicros: price != null ? price * 1000 : null,
      priceCurrencyCode: tx.currency ?? null,
      knownExpiresDate: ts(tx.expiresDate),
      isAutoDetectedRenewal: rawType === "DID_RENEW",
      isPromoOverride: price === 0,
      source: "asn",
    });
    return "created";
  } catch (e) {
    if (!isAlreadyExists(e)) throw e;
    if (rawType === "DID_RENEW") { await ref.set({ knownExpiresDate: ts(tx.expiresDate) }, { merge: true }); return "exists-expiry-merged"; }
    return "exists";
  }
}

// ---------------------------------------------------------------- Android

// msg: RTDN DeveloperNotification JSON, messageId: Pub/Sub messageId, sub: subscriptionsv2.get 결과(실패 시 null)
async function recordPlayLifecycle(db, { msg, messageId, sub }) {
  const n = msg.subscriptionNotification;
  const code = Number(n.notificationType);
  const [rawType, type] = PLAY_TYPES[code] ?? [`TYPE_${code}`, `UNKNOWN_${code}`];
  const purchaseToken = n.purchaseToken;
  const item = sub?.lineItems?.[0] ?? {};
  const productId = item.productId ?? n.subscriptionId ?? null;
  const expiresAt = tsIso(item.expiryTime);
  const autoRenew = item.autoRenewingPlan ? item.autoRenewingPlan.autoRenewEnabled === true : (item.prepaidPlan ? false : null);
  const rp = item.autoRenewingPlan?.recurringPrice;
  const priceMicros = rp ? Number(rp.units ?? 0) * 1e6 + Math.round(Number(rp.nanos ?? 0) / 1000) : null;
  const latestOrderId = item.latestSuccessfulOrderId ?? sub?.latestOrderId ?? null;
  const originalOrderId = latestOrderId ? latestOrderId.split("..")[0] : null;
  const order = await findOrder(db, [latestOrderId, originalOrderId]);
  const isTest = sub ? sub.testPurchase != null : null;

  const event = {
    platform: "android",
    type,
    rawType,
    rawTypeCode: code,
    productId,
    purchaseToken,
    latestOrderId,
    linkedPurchaseToken: sub?.linkedPurchaseToken ?? null,
    subscriptionState: sub?.subscriptionState ?? null,
    expiresAt,
    autoRenew,
    price: priceMicros != null ? priceMicros / 1e6 : null, // 다음 갱신 정가 (recurringPrice)
    priceMicros,
    currency: rp?.currencyCode ?? null,
    regionCode: sub?.regionCode ?? null,
    offerPhase: item.offerPhase ? Object.keys(item.offerPhase)[0] : null,
    cancelReason: sub?.canceledStateContext ? Object.keys(sub.canceledStateContext)[0] : null,
    environment: isTest == null ? null : (isTest ? "Test" : "Production"),
    sandbox: isTest,
    subFetched: !!sub,
    eventAt: ts(msg.eventTimeMillis) ?? admin.firestore.Timestamp.now(),
    orderDocId: order.orderDocId,
    uid: order.uid,
  };

  let status = (sub && PLAY_STATE[sub.subscriptionState]) || STATUS_BY_TYPE[type] || null;
  if (type === "REVOKED") status = "revoked";
  if (status === "active" && autoRenew === false) status = "canceled";

  const statePatch = {
    platform: "android",
    status,
    autoRenew,
    expiresAt,
    productId,
    purchaseToken,
    latestOrderId,
    linkedPurchaseToken: sub?.linkedPurchaseToken ?? null,
    regionCode: sub?.regionCode ?? null,
    sandbox: isTest,
    orderDocId: order.orderDocId,
    uid: order.uid,
  };

  const eventId = messageId || sha(`${purchaseToken}|${code}|${msg.eventTimeMillis}`);
  const result = await writeEvent(db, eventId, event, safeId(purchaseToken), statePatch);

  let orderResult = "-";
  if (result !== "duplicate") orderResult = await createPlayRenewalOrder(db, { code, sub, purchaseToken });
  return `${type} ${result} order=${orderResult}`;
}

// 갱신(2)·결제 복구(1)는 새 결제가 생긴 것이라, 앱이 안 열려도 orders에 남긴다.
// 앱도 같은 문서 ID(orderId)로 쓰고 이미 있으면 건너뛰므로 create()로 중복을 막는다.
async function createPlayRenewalOrder(db, { code, sub, purchaseToken }) {
  if (code !== 2 && code !== 1) return "skip-type";
  if (!sub) return "skip-no-sub";
  if (sub.testPurchase != null) return "skip-test";
  const item = sub.lineItems?.[0] ?? {};
  const orderId = sub.latestOrderId ?? item.latestSuccessfulOrderId ?? null;
  if (!orderId) return "skip-no-order";
  const rp = item.autoRenewingPlan?.recurringPrice;
  try {
    await db.collection(ORDERS).doc(safeId(orderId)).create({
      orderId,
      originalOrderId: orderId.split("..")[0],
      purchaseToken,
      productId: item.productId ?? null,
      isLifetime: false,
      isRenewal: orderId.includes(".."),
      purchaseTime: admin.firestore.FieldValue.serverTimestamp(),
      platform: "android",
      status: "purchased",
      priceAmountMicros: rp ? Number(rp.units ?? 0) * 1e6 + Math.round(Number(rp.nanos ?? 0) / 1000) : null,
      priceCurrencyCode: rp?.currencyCode ?? null,
      regionCode: sub.regionCode ?? null,
      source: "rtdn",
    });
    return "created";
  } catch (e) {
    if (isAlreadyExists(e)) return "exists";
    throw e;
  }
}

// Play voidedPurchaseNotification (환불/취소된 주문). 상태는 바꾸지 않고(보통 REVOKED 알림이 따로 옴) 환불 기록만 남긴다.
async function recordPlayVoided(db, { msg, messageId }) {
  const v = msg.voidedPurchaseNotification;
  const isSub = Number(v.productType) === 1;
  const order = await findOrder(db, [v.orderId]);
  const event = {
    platform: "android",
    type: "REFUNDED",
    rawType: "VOIDED_PURCHASE",
    productType: isSub ? "subscription" : "one_time",
    refundType: Number(v.refundType) === 2 ? "quantity_partial" : "full",
    purchaseToken: v.purchaseToken ?? null,
    latestOrderId: v.orderId ?? null,
    eventAt: ts(msg.eventTimeMillis) ?? admin.firestore.Timestamp.now(),
    orderDocId: order.orderDocId,
    uid: order.uid,
  };
  const eventId = messageId || sha(`${v.purchaseToken}|voided|${v.orderId}|${msg.eventTimeMillis}`);
  const stateKey = isSub && v.purchaseToken ? safeId(v.purchaseToken) : null;
  // 상태 문서에는 환불 표시만 (status는 그대로)
  const result = await writeEvent(db, eventId, event, null, {});
  if (stateKey && result !== "duplicate") {
    await db.collection(STATES).doc(stateKey).set({
      platform: "android", purchaseToken: v.purchaseToken, lastRefundAt: event.eventAt, refundedOrderId: v.orderId ?? null,
      updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });
  }
  return `REFUNDED ${result}`;
}

module.exports = {
  recordAppleLifecycle, recordPlayLifecycle, recordPlayVoided,
  normalizeApple, PLAY_TYPES, STATUS_BY_TYPE,
  // 테스트용
  _upsertAppleOrder: upsertAppleOrder, _createPlayRenewalOrder: createPlayRenewalOrder,
};
