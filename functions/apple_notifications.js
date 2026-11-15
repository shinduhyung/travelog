// App Store Server Notifications V2 수신 (제휴업체 코드 추적용).
//
// App Store Connect > 앱 정보 > "App Store 서버 알림"의 프로덕션/Sandbox URL에 이 함수 주소를 넣는다.
// 애플이 구독 이벤트(시작, 갱신, 해지, 만료, 환불)를 서명된 JWS로 POST한다.
//   1) 서명을 애플 루트 인증서로 검증한다. 검증 실패면 아무것도 기록하지 않고 401.
//   2) notificationUUID로 중복 처리를 막는다 (애플은 실패 시 같은 알림을 다시 보낸다).
//   3) 오퍼 식별자가 업체에 매핑돼 있으면 partner_events에 기록/갱신한다.
// 이 함수는 푸시 알림을 보내지 않는다.

const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
const { handleAppleLifecycle } = require("./partner_lifecycle");
const { recordAppleLifecycle } = require("./subscription_lifecycle");

const BUNDLE_ID = "com.ahnlee.travellog";
const APP_APPLE_ID = 6760092556;

let _verifiers = null;
function getVerifiers() {
  if (_verifiers) return _verifiers;
  const dir = path.join(__dirname, "apple_root_certs");
  const certs = fs.readdirSync(dir).filter((f) => /\.(cer|der|pem)$/i.test(f)).map((f) => fs.readFileSync(path.join(dir, f)));
  if (!certs.length) throw new Error("no Apple root certificates in apple_root_certs/");
  _verifiers = {
    production: new SignedDataVerifier(certs, false, Environment.PRODUCTION, BUNDLE_ID, APP_APPLE_ID),
    sandbox: new SignedDataVerifier(certs, false, Environment.SANDBOX, BUNDLE_ID),
  };
  return _verifiers;
}

// 프로덕션으로 검증해 보고 안 되면 샌드박스로 검증한다. 둘 다 실패하면 위조/오류.
async function verifyNotification(signedPayload) {
  const v = getVerifiers();
  try {
    return { decoded: await v.production.verifyAndDecodeNotification(signedPayload), verifier: v.production, sandbox: false };
  } catch (e1) {
    try {
      return { decoded: await v.sandbox.verifyAndDecodeNotification(signedPayload), verifier: v.sandbox, sandbox: true };
    } catch (e2) {
      return null;
    }
  }
}

exports.appleNotifications = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== "POST") { res.status(405).send("POST only"); return; }
  const signedPayload = req.body?.signedPayload;
  if (typeof signedPayload !== "string" || signedPayload.length < 50) { res.status(400).send("bad request"); return; }

  const verified = await verifyNotification(signedPayload);
  if (!verified) {
    console.warn("[apple] signature verification failed — ignored");
    // 조용한 누락을 막으려고 실패를 분 단위 문서 하나에 센다 (위조 요청이 몰려도 분당 쓰기 1건으로 제한됨).
    try {
      const bucket = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, "");
      await admin.firestore().collection("apple_notifications_failed").doc(bucket).set({
        count: admin.firestore.FieldValue.increment(1),
        lastAt: admin.firestore.FieldValue.serverTimestamp(),
        reason: "signature verification failed (both production and sandbox)",
        payloadLength: signedPayload.length,
      }, { merge: true });
    } catch (e) { console.error("[apple] failed to record verification failure:", e.message); }
    res.status(401).send("invalid signature");
    return;
  }
  const { decoded, verifier, sandbox } = verified;
  const uuid = decoded.notificationUUID;
  const type = decoded.notificationType;
  const subtype = decoded.subtype ?? null;

  const db = admin.firestore();
  try {
    if (uuid) {
      try {
        await db.collection("apple_notifications").doc(uuid).create({ type, subtype, sandbox, receivedAt: admin.firestore.FieldValue.serverTimestamp() });
      } catch (e) {
        if (e.code === 6 || /already exists/i.test(e.message ?? "")) { console.log(`[apple] ${uuid} duplicate, skip`); res.status(200).send("ok"); return; }
        throw e;
      }
    }

    let tx = null;
    if (decoded.data?.signedTransactionInfo) tx = await verifier.verifyAndDecodeTransaction(decoded.data.signedTransactionInfo);
    // 자동 갱신 여부/만료 사유 (구독 생애주기 기록용). 실패해도 기존 처리는 계속한다.
    let renewal = null;
    if (decoded.data?.signedRenewalInfo) {
      try { renewal = await verifier.verifyAndDecodeRenewalInfo(decoded.data.signedRenewalInfo); }
      catch (e) { console.error("[apple] renewal info decode failed:", e.message); }
    }
    // 실제 애플 알림에서 어떤 필드가 오는지 확인할 수 있게, 오퍼 관련 필드만 (개인정보 없이) 알림 문서에 남긴다.
    if (uuid && tx) {
      try {
        await db.collection("apple_notifications").doc(uuid).update({ sample: {
          productId: tx.productId ?? null, offerType: tx.offerType ?? null, offerIdentifier: tx.offerIdentifier ?? null,
          offerDiscountType: tx.offerDiscountType ?? null, offerPeriod: tx.offerPeriod ?? null,
          price: tx.price ?? null, currency: tx.currency ?? null, storefront: tx.storefront ?? null,
        },
        originalTransactionId: tx.originalTransactionId ?? null, transactionId: tx.transactionId ?? null,
        expiresDate: tx.expiresDate ? admin.firestore.Timestamp.fromMillis(tx.expiresDate) : null,
        productId: tx.productId ?? null,
        });
      } catch (e) { console.error("[apple] sample write failed:", e.message); }
    }
    const result = tx ? await handleAppleLifecycle(db, { type, subtype, tx, sandbox }) : "no-transaction";
    // 모든 구독의 생애주기 기록 (subscription_lifecycle.js). 실패해도 알림 처리는 성공으로 둔다(애플 재전송 폭주 방지).
    let lifecycle = "-";
    try { lifecycle = await recordAppleLifecycle(db, { decoded, tx, renewal, sandbox }); }
    catch (e) { lifecycle = "error"; console.error("[apple] subscription lifecycle record failed:", e); }
    console.log(`[apple] ${type}${subtype ? "/" + subtype : ""} env=${sandbox ? "sandbox" : "production"} offer=${tx?.offerIdentifier ?? "-"} -> ${result} | lifecycle ${lifecycle}`);
    res.status(200).send("ok");
  } catch (e) {
    // 500이면 애플이 같은 알림을 다시 보낸다. 중복 방지 문서는 지워서 재처리가 가능하게 한다.
    console.error("[apple] processing error:", e);
    if (uuid) { try { await db.collection("apple_notifications").doc(uuid).delete(); } catch (_) {} }
    res.status(500).send("error");
  }
});
