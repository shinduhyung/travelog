// 제휴업체용 쿠폰 사용·전환 집계 시스템.
//
// 흐름
//   안드로이드: Play가 구독 이벤트를 Pub/Sub 주제 play-rtdn으로 보낸다 (Play Console > 수익 창출 설정 > 실시간 알림).
//   iOS: 애플이 App Store Server Notifications를 appleNotifications로 보낸다 (apple_notifications.js).
//   두 경로 모두 partner_lifecycle.js가 partner_events에 "구독 1건의 현재 상태"를 기록한다.
//     체험 시작(trial) → 유료 전환(paid) / 만료(expired) / 환불(refunded)
//   partnerStats 페이지가 토큰 링크로 업체 본인의 퍼널과 정산 예상액만 보여준다.
//
// Firestore 컬렉션 (클라이언트 접근은 firestore.rules 기본 거부, Functions의 Admin SDK만 읽고 쓴다)
//   partners/{partnerId}   { name, token, codes: [..], appleOffers: [..], rewardPerTrial: 1, rewardPerConversion: 4,
//                            minPayout: 10, currency: 'USD', countTestPurchases?: bool }
//   play_subscription_starts/{orderId}   Play가 알려준 신규 구독 전체 (중복 방지용)
//   partner_events/{key}   구독 1건의 현재 상태 (partner_lifecycle.js 참고)
//
// 서비스 계정: recordPlayTrial은 play-revenue-reader로 실행한다 (Play Console에 이미 등록된 계정).
// 키 파일 없이 런타임 기본 자격 증명으로 Play API를 호출한다. 이 파일은 푸시 알림을 보내지 않는다.

const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const { renderPartnerPage } = require("./partner_page");
const { findPartner, createEvent, handlePlayLifecycle, decidePlayReconcile, PLAY } = require("./partner_lifecycle");
const { recordPlayLifecycle, recordPlayVoided } = require("./subscription_lifecycle");

// 모든 구독의 생애주기 기록 (subscription_lifecycle.js). 실패해도 제휴 처리를 막거나 Pub/Sub 재시도를 일으키지 않는다.
async function recordLifecycleSafe(db, msg, event, sub) {
  try {
    const r = await recordPlayLifecycle(db, { msg, messageId: event.data?.message?.messageId, sub });
    console.log(`[lifecycle] play type=${msg.subscriptionNotification?.notificationType} -> ${r}`);
  } catch (e) {
    console.error("[lifecycle] play record failed:", e);
  }
}

const PACKAGE_NAME = "com.ahnlee.jidoapp";
const READER_SA = "id-play-revenue-reader@proboscis-2025.iam.gserviceaccount.com";

let _playClient = null;
async function getPlayClient() {
  if (_playClient) return _playClient;
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  _playClient = google.androidpublisher({ version: "v3", auth: await auth.getClient() });
  return _playClient;
}


// 로그용 구독 상태 요약 (토큰 등 민감값은 넣지 않는다). 실제 구글 응답에서 체험/정가 단계가 어떻게 보이는지 확인하는 용도.
function summarizeSub(sub) {
  const item = sub?.lineItems?.[0] ?? {};
  const phase = item.offerPhase ? Object.keys(item.offerPhase)[0] : null;
  return `state=${sub?.subscriptionState} phase=${phase} expiry=${item.expiryTime} autoRenew=${item.autoRenewingPlan?.autoRenewEnabled} latestOrder=${sub?.latestOrderId} test=${sub?.testPurchase != null}`;
}

exports.recordPlayTrial = onMessagePublished(
  { topic: "play-rtdn", serviceAccount: READER_SA },
  async (event) => {
    let msg;
    try {
      msg = event.data.message.json;
    } catch (e) {
      console.error("[partner] RTDN payload is not JSON:", e.message);
      return;
    }

    if (msg.reconcile === true) {
      await reconcileAll(admin.firestore(), await getPlayClient());
      return;
    }

    if (msg.testNotification) {
      console.log("[partner] RTDN test notification received");
      return;
    }
    // 환불·취소된 주문 (구독 생애주기 기록만, 제휴 처리 없음). 실패해도 재시도시키지 않는다.
    if (msg.voidedPurchaseNotification && (!msg.packageName || msg.packageName === PACKAGE_NAME)) {
      try { console.log(`[lifecycle] play voided -> ${await recordPlayVoided(admin.firestore(), { msg, messageId: event.data?.message?.messageId })}`); }
      catch (e) { console.error("[lifecycle] play voided record failed:", e); }
      return;
    }
    const n = msg.subscriptionNotification;
    if (!n) return;
    if (msg.packageName && msg.packageName !== PACKAGE_NAME) return;

    const db = admin.firestore();
    const client = await getPlayClient();
    const getSub = async () => (await client.purchases.subscriptionsv2.get({ packageName: PACKAGE_NAME, token: n.purchaseToken })).data;

    // 신규 구독이 아닌 이벤트: 갱신(체험→유료 전환), 해지, 만료, 환불
    if (n.notificationType !== PLAY.PURCHASED) {
      // 모든 알림 유형을 구독 생애주기로 기록하고, 제휴 처리는 기존과 같은 4가지 유형만 한다.
      const partnerType = [PLAY.RENEWED, PLAY.CANCELED, PLAY.EXPIRED, PLAY.REVOKED].includes(n.notificationType);
      let sub = null;
      try { sub = await getSub(); console.log(`[partner] sub-summary type=${n.notificationType} ${summarizeSub(sub)}`); }
      catch (e) { console.error(`[partner] subscriptionsv2.get failed on type=${n.notificationType}:`, e.message); }
      await recordLifecycleSafe(db, msg, event, sub);
      if (!partnerType) return;
      const result = await handlePlayLifecycle(db, { type: n.notificationType, purchaseToken: n.purchaseToken, sub });
      console.log(`[partner] lifecycle type=${n.notificationType} -> ${result}`);
      return;
    }

    const sub = await getSub();
    await recordLifecycleSafe(db, msg, event, sub);
    const item = (sub.lineItems ?? [])[0] ?? {};
    const code = item.signupPromotion?.vanityCode?.promotionCode ?? null;
    const orderId = sub.latestOrderId;
    if (!orderId) {
      console.error("[partner] subscriptionsv2 response without latestOrderId");
      return;
    }

    const base = {
      platform: "android",
      productId: item.productId ?? n.subscriptionId ?? null,
      code,
      promotionType: item.signupPromotion?.oneTimeCode ? "oneTimeCode"
        : item.signupPromotion?.vanityCode ? "vanityCode" : null,
      startedAt: sub.startTime ? admin.firestore.Timestamp.fromDate(new Date(sub.startTime))
        : admin.firestore.Timestamp.now(),
      regionCode: sub.regionCode ?? null,
      isTest: sub.testPurchase != null,
      subscriptionState: sub.subscriptionState ?? null,
    };

    try {
      await db.collection("play_subscription_starts").doc(orderId).create(base);
    } catch (e) {
      if (e.code === 6 || /already exists/i.test(e.message ?? "")) {
        console.log(`[partner] ${orderId} already recorded, skip`);
        return; // Pub/Sub 재전달
      }
      throw e;
    }

    console.log(`[partner] ${orderId} product=${base.productId} code=${code ?? "-"} type=${base.promotionType ?? "-"}`);
    if (!code) return;

    const partner = await findPartner(db, [code]);
    if (!partner) {
      console.log(`[partner] code ${code} has no partner`);
      return;
    }
    await createEvent(db, orderId, {
      partnerId: partner.id,
      ...base,
      purchaseToken: n.purchaseToken,
      status: item.offerPhase?.basePrice ? "paid" : "trial",
      lastEvent: "PURCHASED",
    });
  }
);

// 체험 중으로 기록된 안드로이드 구독의 실제 상태를 구글에 직접 물어 맞춘다 (알림 누락·지연 대비 안전망).
// 확신할 수 없으면 바꾸지 않는다. Cloud Scheduler가 매일 play-rtdn 주제에 {"reconcile":true}를 보내 깨운다
// (예약 작업이 함수를 직접 호출하려면 별도 인증 권한이 필요해서, 이미 권한이 있는 알림 수신 경로를 재사용한다).
async function reconcileAll(db, client) {
  const snap = await db.collection("partner_events").where("status", "==", "trial").limit(300).get();
  let checked = 0, changed = 0, skipped = 0, errors = 0;
  for (const d of snap.docs) {
    const ev = d.data();
    if (ev.platform !== "android" || !ev.purchaseToken) { skipped++; continue; }
    try {
      const sub = (await client.purchases.subscriptionsv2.get({ packageName: PACKAGE_NAME, token: ev.purchaseToken })).data;
      const r = decidePlayReconcile(ev, sub);
      checked++;
      if (r.patch) {
        await d.ref.update({ ...r.patch, lastEvent: "RECONCILE", reconciledAt: admin.firestore.Timestamp.now() });
        changed++;
      }
      console.log(`[reconcile] ${d.id} ${r.result} | ${summarizeSub(sub)}`);
    } catch (e) {
      errors++;
      console.error(`[reconcile] ${d.id} error:`, e.message);
    }
  }
  console.log(`[reconcile] done checked=${checked} changed=${changed} skipped=${skipped} errors=${errors}`);
}

// 매일 06:00(서울)에 reconcileAll을 실행한다. 새로 만든 직후 몇 분은 호출 권한 반영 지연으로 401이 날 수 있으나 곧 정상화된다(실제 확인).
// 같은 점검은 play-rtdn 주제에 {"reconcile":true}를 한 번 보내 수동으로도 돌릴 수 있다.
exports.reconcilePlayTrials = onSchedule(
  { schedule: "every day 06:00", timeZone: "Asia/Seoul", serviceAccount: READER_SA },
  async () => { await reconcileAll(admin.firestore(), await getPlayClient()); }
);

// 업체 전용 페이지. 토큰을 아는 사람만 본다. 개인정보(유저 id, 이메일 등)는 담지 않고 건수·날짜·국가만.
exports.partnerStats = onRequest({ cors: false }, async (req, res) => {
  res.set("Cache-Control", "no-store");
  res.set("X-Robots-Tag", "noindex, nofollow");

  const token = String(req.query.t ?? "");
  if (token.length < 24) {
    res.status(404).send("Not found");
    return;
  }

  const db = admin.firestore();
  const found = await db.collection("partners").where("token", "==", token).limit(1).get();
  if (found.empty) {
    res.status(404).send("Not found");
    return;
  }
  const partnerDoc = found.docs[0];
  const partner = partnerDoc.data();

  const events = (await db.collection("partner_events").where("partnerId", "==", partnerDoc.id).get())
    .docs.map((d) => d.data())
    .filter((e) => !e.isTest || partner.countTestPurchases === true)
    .sort((a, b) => b.startedAt.toMillis() - a.startedAt.toMillis());

  const normalized = events.map((e) => ({
    code: e.code,
    regionCode: e.regionCode ?? null,
    startedAt: e.startedAt.toDate(),
    platform: e.platform ?? "android",
    status: e.status ?? "trial",
    trialCanceled: !!e.trialCanceledAt,
    convertedAt: e.convertedAt?.toDate?.() ?? null,
  }));
  res.status(200).type("html").send(renderPartnerPage({ partner, events: normalized }));
});
