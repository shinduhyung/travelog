// 제휴업체 구독 생애주기 기록 (구글 RTDN + 애플 App Store Server Notifications 공용).
//
// partner_events/{key} 한 문서 = 업체 코드로 시작된 구독 1건의 현재 상태.
//   key: 안드로이드 = 최초 주문번호(GPA.…), iOS = "ios_<originalTransactionId>"
//   status: 'trial'(체험 중) → 'paid'(유료 전환) | 'expired'(전환 없이 만료) | 'refunded'(환불/취소됨)
//           (체험 없이 바로 결제한 구독은 'paid'로 시작)
//   trialCanceledAt: 체험 중 자동 갱신을 끈 시각 (전환 전이라 아직 'trial'이지만 곧 'expired'가 됨)
//
// db를 인자로 받는 순수 함수들이라 가짜 db로 로컬 테스트할 수 있다.
// 이 파일은 푸시 알림을 보내지 않는다 (messaging 사용 없음).

const admin = require("firebase-admin");
const { Timestamp } = admin.firestore;

const COLLECTION = "partner_events";

function ts(ms) {
  return Timestamp.fromMillis(Number(ms));
}

// 코드(안드로이드 전용 코드) 또는 오퍼 식별자(iOS)로 업체를 찾는다.
// 업체 문서: codes[] (안드로이드/공용 코드), appleOffers[] (애플 오퍼 식별자)
async function findPartner(db, candidates) {
  const list = [...new Set((candidates ?? []).filter(Boolean).map(String))];
  for (const c of list) {
    for (const field of ["codes", "appleOffers"]) {
      const s = await db.collection("partners").where(field, "array-contains", c).limit(1).get();
      if (!s.empty) return { id: s.docs[0].id, matched: c };
    }
  }
  return null;
}

async function createEvent(db, key, data) {
  try {
    await db.collection(COLLECTION).doc(key).create(data);
    return true;
  } catch (e) {
    if (e.code === 6 || /already exists/i.test(e.message ?? "")) return false;
    throw e;
  }
}

async function findByField(db, field, value) {
  const s = await db.collection(COLLECTION).where(field, "==", value).limit(1).get();
  return s.empty ? null : { id: s.docs[0].id, data: s.docs[0].data() };
}

async function patch(db, id, fields) {
  await db.collection(COLLECTION).doc(id).update(fields);
}

// ── 안드로이드 (RTDN) ────────────────────────────────────────────────────────
// n: subscriptionNotification, sub: subscriptionsv2.get 결과
const PLAY = { RENEWED: 2, CANCELED: 3, PURCHASED: 4, REVOKED: 12, EXPIRED: 13 };

async function handlePlayLifecycle(db, { type, purchaseToken, sub }) {
  const found = await findByField(db, "purchaseToken", purchaseToken);
  if (!found) return "no-event-for-token";
  const ev = found.data;
  const now = Timestamp.now();

  if (type === PLAY.RENEWED) {
    if (ev.status !== "trial") return `renewed-ignored(status=${ev.status})`;
    // 체험 단계가 끝나고 정가 단계로 넘어갔는지 확인 (문서 예시상 offerPhase: freeTrial → basePrice).
    const phase = sub?.lineItems?.[0]?.offerPhase;
    if (phase && phase.freeTrial) return "renewed-but-still-free-trial";
    await patch(db, found.id, { status: "paid", convertedAt: now, lastEvent: "RENEWED" });
    return phase?.basePrice ? "converted(basePrice)" : "converted(phase-unknown)";
  }
  if (type === PLAY.CANCELED) {
    if (ev.status === "trial") { await patch(db, found.id, { trialCanceledAt: now, lastEvent: "CANCELED" }); return "trial-canceled"; }
    await patch(db, found.id, { canceledAt: now, lastEvent: "CANCELED" });
    return "canceled-after-paid";
  }
  if (type === PLAY.EXPIRED) {
    if (ev.status === "trial") { await patch(db, found.id, { status: "expired", endedAt: now, lastEvent: "EXPIRED" }); return "expired-without-conversion"; }
    await patch(db, found.id, { endedAt: now, lastEvent: "EXPIRED" });
    return "expired-after-paid";
  }
  if (type === PLAY.REVOKED) {
    await patch(db, found.id, { status: "refunded", refundedAt: now, lastEvent: "REVOKED" });
    return "refunded";
  }
  return "type-ignored";
}

// ── 애플 (App Store Server Notifications V2) ─────────────────────────────────
// tx: 복호화된 거래 정보(JWSTransactionDecodedPayload), sandbox: 샌드박스 환경 여부
function offerAudit(tx) {
  return { offerType: tx.offerType ?? null, offerIdentifier: tx.offerIdentifier ?? null, offerDiscountType: tx.offerDiscountType ?? null,
    price: tx.price ?? null, currency: tx.currency ?? null, transactionId: tx.transactionId ?? null };
}

async function handleAppleLifecycle(db, { type, subtype, tx, sandbox }) {
  const original = tx?.originalTransactionId;
  if (!original) return "no-original-transaction-id";
  const key = `ios_${original}`;
  const now = Timestamp.now();

  if (type === "SUBSCRIBED" || type === "OFFER_REDEEMED") {
    if (!tx.offerIdentifier) return "start-without-offer";
    const partner = await findPartner(db, [tx.offerIdentifier]);
    if (!partner) return `offer-has-no-partner(${tx.offerIdentifier})`;
    const created = await createEvent(db, key, {
      partnerId: partner.id,
      platform: "ios",
      code: tx.offerIdentifier,
      productId: tx.productId ?? null,
      startedAt: ts(tx.purchaseDate ?? Date.now()),
      regionCode: tx.storefront ?? null,
      isTest: !!sandbox,
      status: "trial", // 우리 파트너 오퍼는 무료 체험. offerDiscountType이 없어도 체험으로 시작한다 (전환은 아래 DID_RENEW에서만)
      originalTransactionId: original,
      offerType: tx.offerType ?? null,
      startAudit: offerAudit(tx),
      lastEvent: type + (subtype ? `/${subtype}` : ""),
    });
    return created ? "start-recorded" : "start-duplicate";
  }

  const ev = (await db.collection(COLLECTION).doc(key).get());
  if (!ev.exists) return "no-event-for-subscription";
  const data = ev.data();

  if (type === "DID_RENEW") {
    if (data.status !== "trial") return `renew-ignored(status=${data.status})`;
    // 유료 전환 = 오퍼 없는 갱신, 또는 오퍼가 붙어 있어도 실제 청구 금액이 0보다 큰 갱신.
    // (오퍼 필드가 남아 있거나 offerDiscountType이 없어도 무료 기간 중 갱신을 전환으로 세지 않는다)
    const charged = tx.price != null ? Number(tx.price) : 0;
    if (tx.offerType && charged <= 0) return "renew-still-in-offer";
    await patch(db, key, {
      status: "paid", convertedAt: ts(tx.purchaseDate ?? Date.now()), lastEvent: "DID_RENEW",
      paidAmount: tx.price != null ? tx.price / 1000 : null, paidCurrency: tx.currency ?? null, convertAudit: offerAudit(tx),
    });
    return "converted";
  }
  if (type === "DID_CHANGE_RENEWAL_STATUS") {
    if (subtype === "AUTO_RENEW_DISABLED") {
      await patch(db, key, data.status === "trial" ? { trialCanceledAt: now, lastEvent: "AUTO_RENEW_DISABLED" } : { canceledAt: now, lastEvent: "AUTO_RENEW_DISABLED" });
      return "auto-renew-off";
    }
    if (subtype === "AUTO_RENEW_ENABLED") {
      await patch(db, key, { trialCanceledAt: admin.firestore.FieldValue.delete(), canceledAt: admin.firestore.FieldValue.delete(), lastEvent: "AUTO_RENEW_ENABLED" });
      return "auto-renew-on";
    }
    return "renewal-status-ignored";
  }
  if (type === "EXPIRED") {
    await patch(db, key, data.status === "trial" ? { status: "expired", endedAt: now, lastEvent: "EXPIRED" } : { endedAt: now, lastEvent: "EXPIRED" });
    return data.status === "trial" ? "expired-without-conversion" : "expired-after-paid";
  }
  if (type === "REFUND" || type === "REVOKE") {
    await patch(db, key, { status: "refunded", refundedAt: now, lastEvent: type });
    return "refunded";
  }
  return "type-ignored";
}


// ── 안드로이드 점검(reconcile) ──────────────────────────────────────────────
// 알림이 누락돼도 전환을 놓치지 않도록, 매일 구글에 직접 물어본 구독 상태(sub)로 체험 중인 이벤트를 맞춘다.
// 확신할 수 없으면 아무것도 바꾸지 않는다 (phase-unknown). 지급 근거는 항상 구글이 알려준 상태다.
function decidePlayReconcile(ev, sub, now = Timestamp.now()) {
  const item = sub?.lineItems?.[0] ?? {};
  const state = sub?.subscriptionState;
  const phase = item.offerPhase ?? {};
  if (state === "SUBSCRIPTION_STATE_EXPIRED") return { patch: { status: "expired", endedAt: now }, result: "expired-without-conversion" };
  if (phase.basePrice && ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED"].includes(state)) {
    return { patch: { status: "paid", convertedAt: now }, result: "converted" };
  }
  if (phase.freeTrial) {
    // 구글은 false 값을 응답에서 생략하므로(autoRenewEnabled가 undefined로 옴) 구독 상태 CANCELED도 해지로 본다. (실제 응답으로 확인)
    const autoRenewOff = item.autoRenewingPlan?.autoRenewEnabled === false || state === "SUBSCRIPTION_STATE_CANCELED";
    if (autoRenewOff && !ev.trialCanceledAt) return { patch: { trialCanceledAt: now }, result: "trial-auto-renew-off" };
    return { patch: null, result: "still-in-trial" };
  }
  return { patch: null, result: "phase-unknown" };
}

module.exports = { findPartner, createEvent, handlePlayLifecycle, handleAppleLifecycle, decidePlayReconcile, PLAY, COLLECTION };
