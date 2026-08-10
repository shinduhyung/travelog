const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const { google } = require("googleapis");

admin.initializeApp();

// 통화 코드 -> 국가 코드 (Play 주문에서 국가를 못 가져왔을 때 폴백)
const CURRENCY_TO_COUNTRY = {
  USD: 'US', KRW: 'KR', JPY: 'JP', GBP: 'GB', EUR: 'EU',
  AUD: 'AU', CAD: 'CA', PHP: 'PH', PLN: 'PL', BRL: 'BR',
  MXN: 'MX', INR: 'IN', IDR: 'ID', VND: 'VN', THB: 'TH',
  TWD: 'TW', HKD: 'HK', SGD: 'SG', MYR: 'MY', CNY: 'CN',
  CHF: 'CH', SEK: 'SE', NOK: 'NO', DKK: 'DK', NZD: 'NZ',
  ZAR: 'ZA', TRY: 'TR', RUB: 'RU', AED: 'AE', SAR: 'SA',
};

const ANDROID_PACKAGE_NAME = 'com.ahnlee.jidoapp';

// 국가 코드 -> 국기 이모지
function countryFlag(countryCode) {
  if (!countryCode || countryCode.length !== 2) return '🌐';
  if (countryCode.toUpperCase() === 'EU') return '🇪🇺';
  const base = 0x1F1E6;
  const upper = countryCode.toUpperCase();
  const first = upper.codePointAt(0) - 65 + base;
  const second = upper.codePointAt(1) - 65 + base;
  return String.fromCodePoint(first) + String.fromCodePoint(second);
}

// Android Publisher API 클라이언트 (대시보드와 동일한 서비스 계정 사용)
let _playClient = null;
async function getPlayClient() {
  if (_playClient) return _playClient;
  const keyPath = path.join(__dirname, 'proboscis-2025-76736893710c.json');
  const auth = new google.auth.GoogleAuth({
    keyFile: keyPath,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const authClient = await auth.getClient();
  _playClient = google.androidpublisher({ version: 'v3', auth: authClient });
  return _playClient;
}

// Android 주문의 정확한 국가 + 결제 금액을 orders.get으로 조회
async function fetchAndroidOrderInfo(orderId) {
  try {
    const client = await getPlayClient();
    const res = await client.purchases.orders.get({
      packageName: ANDROID_PACKAGE_NAME,
      orderId: orderId,
    });
    const data = res.data;
    const country = data.buyerAddress?.buyerCountry ?? null;
    const total = data.total; // {currencyCode, units, nanos}
    let amountStr = null;
    if (total) {
      const units = parseFloat(total.units ?? '0');
      const nanos = (total.nanos ?? 0) / 1e9;
      const amount = units + nanos;
      amountStr = `${total.currencyCode} ${amount.toLocaleString('en-US', { maximumFractionDigits: 2 })}`;
    }
    return { country, amountStr };
  } catch (e) {
    console.error(`[Play] orders.get error (${orderId}):`, e.message ?? e);
    return { country: null, amountStr: null };
  }
}

exports.addDailyQuiz = onSchedule(
  {
    schedule: "0 0 * * *",
    timeZone: "Etc/UTC",
  },
  async (event) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    const today = new Date();
    const year = today.getUTCFullYear();
    const month = String(today.getUTCMonth() + 1).padStart(2, '0');
    const day = String(today.getUTCDate()).padStart(2, '0');
    const dateStr = `${year}${month}${day}`;

    try {
      const jsonPath = path.join(__dirname, "quizzes.json");
      const rawData = fs.readFileSync(jsonPath, "utf-8");
      const quizBank = JSON.parse(rawData);

      if (!quizBank || quizBank.length === 0) {
        throw new Error("Quiz data array is empty.");
      }

      const todayQuiz = quizBank.find(q => q.date === dateStr);
      if (!todayQuiz) {
        console.log(`No quiz found for date: ${dateStr}`);
        return;
      }

      const notificationTitle = `🌍 Today's Travel Quiz`;
      const notificationBody = `${todayQuiz.question} 👉 Tap to answer!`;

      const tokensSnapshot = await db.collection('fcm_tokens').get();
      if (tokensSnapshot.empty) {
        console.log('No FCM tokens found.');
        return;
      }

      const tokens = tokensSnapshot.docs
        .filter(doc => doc.data().device !== 'revenue_dashboard')
        .map(doc => doc.data().token)
        .filter(Boolean);
      console.log(`Sending to ${tokens.length} devices for date: ${dateStr}`);

      const BATCH_SIZE = 500;
      let successCount = 0;
      let failCount = 0;

      for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
        const batch = tokens.slice(i, i + BATCH_SIZE);

        const message = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: 'daily_quiz',
            date: dateStr,
          },
          android: {
            notification: {
              channelId: 'daily_quiz',
              priority: 'high',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
          tokens: batch,
        };

        const response = await messaging.sendEachForMulticast(message);
        successCount += response.successCount;
        failCount += response.failureCount;

        const deletePromises = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              const invalidToken = batch[idx];
              deletePromises.push(
                db.collection('fcm_tokens').doc(invalidToken).delete()
              );
            }
          }
        });
        await Promise.all(deletePromises);
      }

      console.log(`✅ FCM 발송 완료 — 성공: ${successCount}, 실패: ${failCount}`);
    } catch (error) {
      console.error(`Error in addDailyQuiz: ${error}`);
    }
  }
);

exports.notifyNewSubscription = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    const order = event.data?.data();
    if (!order) return;

    // purchased 상태만 알림 발송 (Android + iOS 모두)
    if (order.status !== 'purchased') {
      console.log(`Skipping notification for status: ${order.status}`);
      return;
    }

    const orderId = event.params.orderId;
    const platform = order.platform ?? 'unknown';

    // 국가/금액 정보 조회
    let country = null;
    let amountStr = null;

    if (platform === 'android') {
      const info = await fetchAndroidOrderInfo(orderId);
      country = info.country;
      amountStr = info.amountStr;
    }

    // 국가를 못 얻었으면 통화 코드 기반 폴백
    const currencyCode = order.priceCurrencyCode ?? null;
    if (!country && currencyCode) {
      country = CURRENCY_TO_COUNTRY[currencyCode] ?? null;
    }
    // 금액을 못 얻었으면 priceAmountMicros 기반 폴백
    if (!amountStr && order.priceAmountMicros != null && currencyCode) {
      const amount = order.priceAmountMicros / 1e6;
      amountStr = `${currencyCode} ${amount.toLocaleString('en-US', { maximumFractionDigits: 2 })}`;
    }

    const flag = countryFlag(country);
    const titleParts = [flag];
    if (country) titleParts.push(country);
    if (amountStr) titleParts.push(amountStr);
    const title = titleParts.join(' ');
    const body = amountStr ? `Travelog Premium ${amountStr}` : 'Travelog Premium 결제 완료';

    // revenue_dashboard 기기 토큰만 조회
    const tokensSnapshot = await db.collection('fcm_tokens')
        .where('device', '==', 'revenue_dashboard')
        .get();

    if (tokensSnapshot.empty) {
      console.log('No revenue_dashboard tokens found.');
      return;
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.data().token).filter(Boolean);

    const BATCH_SIZE = 500;
    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE);

      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'new_subscription',
          orderId: orderId,
          platform: platform,
        },
        android: {
          notification: {
            channelId: 'subscription',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: { sound: 'default', badge: 1 },
          },
        },
        tokens: batch,
      };

      const response = await messaging.sendEachForMulticast(message);

      const deletePromises = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            deletePromises.push(
              db.collection('fcm_tokens').doc(batch[idx]).delete()
            );
          }
        }
      });
      await Promise.all(deletePromises);
    }

    console.log(`✅ 구독 알림 발송 (${platform}): ${orderId}`);
  }
);