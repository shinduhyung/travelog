const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { fetchDecodedSubscriptionStatus } = require('./apple_server_api');

// 라이프타임은 갱신이 없으니 제외 — 구독형 상품만 체크 대상.
const SUBSCRIPTION_PRODUCT_IDS = [
  'travelog_premium_monthly',
  'travelog_premium_yearly_v2',
  'travelog_premium_yearly',
];

const PERIOD_DAYS_BY_PRODUCT = {
  travelog_premium_monthly: 30,
  travelog_premium_yearly_v2: 365,
  travelog_premium_yearly: 365,
};

// Apple의 결제 재시도(billing retry)/유예(grace period)가 길게는 몇 주까지 이어질 수 있어서,
// 예상 갱신일이 지나도 이 기간만큼은 계속 재확인한다. 이 기간까지 지나도 갱신이 안 잡히면
// 구독이 끝난 것으로 확정하고 더 이상 체크하지 않는다.
const GRACE_WINDOW_DAYS = 21;

// App Store Server API 구독 상태 코드. 1=ACTIVE, 2=EXPIRED, 3=BILLING_RETRY,
// 4=BILLING_GRACE_PERIOD, 5=REVOKED. 2/5만 "더 이상 안 살아난다"는 확정 상태.
const TERMINAL_STATUSES = new Set([2, 5]);

function addDays(date, days) {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

exports.checkIosSubscriptionRenewals = onSchedule(
  {
    schedule: '0 3 * * *',
    timeZone: 'Etc/UTC',
    timeoutSeconds: 540,
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const snapshot = await db.collection('orders')
      .where('platform', '==', 'ios')
      .where('productId', 'in', SUBSCRIPTION_PRODUCT_IDS)
      .get();

    // originalTransactionId별로 우리가 갖고 있는 가장 최근(purchaseTime 기준) 주문 문서만 남긴다.
    // 이게 "우리가 마지막으로 확인한 시점"의 기준이 된다.
    const latestByOriginalId = new Map();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const originalId = data.originalTransactionId;
      if (!originalId) continue;
      if (data.subscriptionEnded === true) continue; // 이미 종료 확정된 구독은 스킵

      const purchaseTime = data.purchaseTime?.toDate?.();
      if (!purchaseTime) continue;

      const existing = latestByOriginalId.get(originalId);
      if (!existing || purchaseTime > existing.purchaseTime) {
        latestByOriginalId.set(originalId, { doc, data, purchaseTime });
      }
    }

    console.log(`[RenewalCheck] tracking ${latestByOriginalId.size} active iOS subscription chains`);

    let checked = 0;
    let newRenewals = 0;
    let markedEnded = 0;

    for (const [originalId, { doc, data, purchaseTime }] of latestByOriginalId) {
      // knownExpiresDate가 있으면(이전에 Apple이 알려준 실제 만료일) 그걸 기준으로 쓰고,
      // 없으면(최초 구매 문서뿐일 때) 상품 주기로 추정한다.
      const knownExpiresDate = data.knownExpiresDate?.toDate?.();
      const periodDays = PERIOD_DAYS_BY_PRODUCT[data.productId] ?? 365;
      const expectedRenewalDate = knownExpiresDate ?? addDays(purchaseTime, periodDays);

      const windowStart = addDays(expectedRenewalDate, -1);
      const windowEnd = addDays(expectedRenewalDate, GRACE_WINDOW_DAYS);

      if (now < windowStart) continue; // 아직 갱신 예정일 근처도 아님 — 조회 안 함
      if (now > windowEnd) {
        // 그레이스 기간까지 다 지나도록 새 결제가 안 잡혔으면 종료로 확정하고 그만 확인
        await doc.ref.set({
          subscriptionEnded: true,
          subscriptionEndedReason: 'grace_window_expired_unresolved',
        }, { merge: true });
        markedEnded++;
        console.log(`[RenewalCheck] ${originalId}: grace window expired, marking ended`);
        continue;
      }

      checked++;
      try {
        const { statuses } = await fetchDecodedSubscriptionStatus(originalId);
        if (statuses.length === 0) {
          console.log(`[RenewalCheck] ${originalId}: no statuses returned`);
          continue;
        }

        const relevant = statuses.filter(
          (s) => s.decodedTransaction?.originalTransactionId === originalId,
        );
        if (relevant.length === 0) continue;
        relevant.sort((a, b) =>
          (b.decodedTransaction?.purchaseDate ?? 0) - (a.decodedTransaction?.purchaseDate ?? 0),
        );
        const latest = relevant[0];
        const tx = latest.decodedTransaction;

        if (tx && tx.transactionId && tx.transactionId !== data.orderId) {
          // 새 트랜잭션 발견 = 우리가 놓쳤던 갱신 결제.
          // tx.price는 밀리단위 실제 결제 금액(예: 10990 = $10.99) — 카탈로그 정가가 아니라
          // Apple이 검증해준 진짜 결제 금액이라, 0이면 진짜로 무료(오퍼/프로모션)였다는 뜻.
          const price = tx.price;
          const isFreeOffer = price === 0;

          await db.collection('orders').doc(tx.transactionId).set({
            orderId: tx.transactionId,
            originalTransactionId: tx.originalTransactionId,
            productId: tx.productId,
            isLifetime: false,
            purchaseTime: admin.firestore.Timestamp.fromMillis(tx.purchaseDate),
            platform: 'ios',
            status: 'purchased',
            priceAmountMicros: price != null ? price * 1000 : null,
            priceCurrencyCode: tx.currency ?? null,
            knownExpiresDate: tx.expiresDate
              ? admin.firestore.Timestamp.fromMillis(tx.expiresDate)
              : null,
            isAutoDetectedRenewal: true,
            isPromoOverride: isFreeOffer,
          }, { merge: true });

          newRenewals++;
          console.log(`[RenewalCheck] ${originalId}: recorded missed renewal ${tx.transactionId}`);
        } else if (tx?.expiresDate) {
          // 새 결제는 아직 없지만(갱신 전) 정확한 만료일은 알게 됐으니 다음 체크 윈도우 계산에 반영.
          await doc.ref.set({
            knownExpiresDate: admin.firestore.Timestamp.fromMillis(tx.expiresDate),
          }, { merge: true });
        }

        if (TERMINAL_STATUSES.has(latest.status)) {
          await doc.ref.set({
            subscriptionEnded: true,
            subscriptionEndedReason: `apple_status_${latest.status}`,
          }, { merge: true });
          markedEnded++;
        }
      } catch (e) {
        console.error(`[RenewalCheck] ${originalId}: error`, e.message ?? e);
      }
    }

    console.log(
      `[RenewalCheck] done — checked=${checked} newRenewals=${newRenewals} markedEnded=${markedEnded}`,
    );
  },
);
