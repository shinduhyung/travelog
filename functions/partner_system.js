// 제휴업체용 쿠폰 사용 집계 시스템.
//
// 흐름
//   1) Play가 구독 이벤트를 Pub/Sub 주제 play-rtdn으로 보낸다 (Play Console > 수익 창출 설정 > 실시간 알림).
//   2) recordPlayTrial이 새 구독(SUBSCRIPTION_PURCHASED)만 골라 purchases.subscriptionsv2.get으로
//      그 구독이 쓴 전용(커스텀) 코드를 조회한다. 앱이 orders에 기록하지 못해도(로그인 상태 구매 누락 버그)
//      구글이 직접 알려주므로 빠지지 않는다.
//   3) partners 문서의 codes에 그 코드가 있으면 partner_events에 한 건 기록한다.
//   4) partnerStats 페이지가 토큰 링크로 업체 본인의 건수와 정산 예상액만 보여준다.
//
// Firestore 컬렉션 (클라이언트 접근은 firestore.rules 기본 거부, Functions의 Admin SDK만 읽고 쓴다)
//   partners/{partnerId}        { name, token, codes: [..], rewardPerTrial: 1, currency: 'USD' }
//   play_subscription_starts/{orderId}   Play가 알려준 신규 구독 전체 (코드 유무와 무관, 중복 방지용)
//   partner_events/{orderId}    { partnerId, code, platform, productId, startedAt, regionCode, isTest }
//
// 서비스 계정: 이 파일의 함수는 play-revenue-reader로 실행한다 (Play Console에 이미 등록된 계정).
// 키 파일 없이 런타임 기본 자격 증명으로 Play API를 호출한다.

const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require("googleapis");

const PACKAGE_NAME = "com.ahnlee.jidoapp";
const READER_SA = "id-play-revenue-reader@proboscis-2025.iam.gserviceaccount.com";
const SUBSCRIPTION_PURCHASED = 4; // https://developer.android.com/google/play/billing/rtdn-reference

let _playClient = null;
async function getPlayClient() {
  if (_playClient) return _playClient;
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  _playClient = google.androidpublisher({ version: "v3", auth: await auth.getClient() });
  return _playClient;
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

    if (msg.testNotification) {
      console.log("[partner] RTDN test notification received");
      return;
    }
    const n = msg.subscriptionNotification;
    if (!n || n.notificationType !== SUBSCRIPTION_PURCHASED) return;
    if (msg.packageName && msg.packageName !== PACKAGE_NAME) return;

    const client = await getPlayClient();
    const res = await client.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: n.purchaseToken,
    });
    const sub = res.data;
    const item = (sub.lineItems ?? [])[0] ?? {};
    const code = item.signupPromotion?.vanityCode?.promotionCode ?? null;
    const orderId = sub.latestOrderId;
    if (!orderId) {
      console.error("[partner] subscriptionsv2 response without latestOrderId");
      return;
    }

    const db = admin.firestore();
    const base = {
      platform: "android",
      productId: item.productId ?? n.subscriptionId ?? null,
      code,
      promotionType: item.signupPromotion?.oneTimeCode ? "oneTimeCode"
        : item.signupPromotion?.vanityCode ? "vanityCode" : null,
      startedAt: sub.startTime ? admin.firestore.Timestamp.fromDate(new Date(sub.startTime))
        : admin.firestore.FieldValue.serverTimestamp(),
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

    const partners = await db.collection("partners").where("codes", "array-contains", code).limit(1).get();
    if (partners.empty) {
      console.log(`[partner] code ${code} has no partner`);
      return;
    }
    await db.collection("partner_events").doc(orderId).set({
      partnerId: partners.docs[0].id,
      ...base,
    });
  }
);

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

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
  const reward = Number(partner.rewardPerTrial ?? 1);
  const currency = partner.currency ?? "USD";

  const events = (await db.collection("partner_events").where("partnerId", "==", partnerDoc.id).get())
    .docs.map((d) => d.data())
    .filter((e) => !e.isTest || partner.countTestPurchases === true)
    .sort((a, b) => b.startedAt.toMillis() - a.startedAt.toMillis());

  const byCode = {};
  for (const e of events) byCode[e.code] = (byCode[e.code] ?? 0) + 1;

  const rows = events.slice(0, 200).map((e) => `<tr>
    <td>${esc(e.startedAt.toDate().toISOString().slice(0, 10))}</td>
    <td>${esc(e.code)}</td><td>${esc(e.regionCode ?? "")}</td><td>Android</td></tr>`).join("");
  const codeRows = (partner.codes ?? []).map((c) =>
    `<tr><td>${esc(c)}</td><td>${byCode[c] ?? 0}</td></tr>`).join("");
  const total = events.length;

  res.status(200).type("html").send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow"><title>Travelog partner stats</title>
<style>body{font:16px/1.5 system-ui,sans-serif;max-width:640px;margin:0 auto;padding:24px 16px;color:#1a1a2e}
h1{font-size:22px}.big{font-size:40px;font-weight:700;margin:4px 0}
table{border-collapse:collapse;width:100%;margin:8px 0 24px}th,td{text-align:left;padding:8px;border-bottom:1px solid #e5e7eb}
.card{background:#f4f7fb;border-radius:12px;padding:16px;margin:16px 0}.muted{color:#6b7280;font-size:14px}</style></head>
<body><h1>${esc(partner.name)} — Travelog partner stats</h1>
<div class="card"><div class="muted">Valid trials started with your codes</div><div class="big">${total}</div>
<div class="muted">Estimated earnings: <b>${esc(currency)} ${(total * reward).toFixed(2)}</b> (${esc(currency)} ${reward.toFixed(2)} per trial)</div></div>
<h2>Your codes</h2><table><tr><th>Code</th><th>Trials</th></tr>${codeRows}</table>
<h2>Recent trials</h2><table><tr><th>Date</th><th>Code</th><th>Country</th><th>Store</th></tr>${rows || '<tr><td colspan="4" class="muted">No trials yet.</td></tr>'}</table>
<p class="muted">Counts update within minutes of a trial starting. Android only for now; iOS counts are added separately.</p>
</body></html>`);
});
