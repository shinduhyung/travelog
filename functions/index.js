const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const path = require("path");
const { google } = require("googleapis");

admin.initializeApp();

// Flight price + booking link Cloud Functions (RapidAPI Sky-scrapper proxy) —
// see functions/flight_functions.js for the implementation.
// 변경 후 (주석 처리)
// const flightFunctions = require('./flight_functions');
// exports.getFlightPrice = flightFunctions.getFlightPrice;
// exports.getFlightBookingLink = flightFunctions.getFlightBookingLink;

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

// Firebase Storage 경로 (Flutter 앱과 동일한 경로를 읽음)
const QUIZ_STORAGE_PATHS = {
  normal: 'functions/quizzes.json',
  expert: 'functions/quizzes_hard.json',
};

// Storage에서 퀴즈 뱅크 JSON을 읽어옴 (배포 불필요, 파일만 교체하면 반영됨)
async function fetchQuizBankFromStorage(storagePath) {
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`Storage file not found: ${storagePath}`);
  }
  const [buffer] = await file.download();
  return JSON.parse(buffer.toString('utf-8'));
}

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
      const tokensSnapshot = await db.collection('fcm_tokens').get();
      if (tokensSnapshot.empty) {
        console.log('No FCM tokens found.');
        return;
      }

      const eligibleDocs = tokensSnapshot.docs.filter(
        doc => doc.data().device !== 'revenue_dashboard'
      );

      // 각 기기가 DailyQuizScreen에서 저장해둔 기본 모드(quizMode 필드)에 따라
      // Normal/Expert 중 하나만 발송함. 필드가 없으면(구버전 앱 등) Normal로 취급.
      const normalTokens = eligibleDocs
        .filter(doc => doc.data().quizMode !== 'expert')
        .map(doc => doc.data().token)
        .filter(Boolean);
      const expertTokens = eligibleDocs
        .filter(doc => doc.data().quizMode === 'expert')
        .map(doc => doc.data().token)
        .filter(Boolean);

      if (normalTokens.length === 0 && expertTokens.length === 0) {
        console.log('No eligible device tokens.');
        return;
      }

      console.log(
        `Sending Normal to ${normalTokens.length} devices, Expert to ${expertTokens.length} devices for date: ${dateStr}`
      );

      // Normal + Expert 퀴즈 푸시를 각각 독립적으로 시도 (하나가 실패해도 다른 하나는 발송됨)
      await Promise.all([
        normalTokens.length > 0
          ? sendDailyQuizPush({
              db,
              messaging,
              tokens: normalTokens,
              dateStr,
              storagePath: QUIZ_STORAGE_PATHS.normal,
              mode: null, // Normal 모드는 mode 필드를 넣지 않음 (기존 앱과 호환)
              notificationTitle: `🌍 Today's Travel Quiz`,
              channelId: 'daily_quiz',
              color: '#6366F1', // Normal 테마 (인디고)
            })
          : Promise.resolve(),
        expertTokens.length > 0
          ? sendDailyQuizPush({
              db,
              messaging,
              tokens: expertTokens,
              dateStr,
              storagePath: QUIZ_STORAGE_PATHS.expert,
              mode: 'expert',
              notificationTitle: `🧠 Today's Expert Quiz`,
              channelId: 'daily_quiz', // 별도 채널을 앱에 만들어두었다면 여기서 바꿔주면 됨
              color: '#7C3AED', // Expert 테마 (보라 → 핑크 그라데이션의 시작색)
            })
          : Promise.resolve(),
      ]);
    } catch (error) {
      console.error(`Error in addDailyQuiz: ${error}`);
    }
  }
);

// 퀴즈 뱅크(Storage) 하나를 읽어서 해당 날짜 문제를 찾고 FCM 발송까지 처리
async function sendDailyQuizPush({ db, messaging, tokens, dateStr, storagePath, mode, notificationTitle, channelId, color }) {
  try {
    const quizBank = await fetchQuizBankFromStorage(storagePath);

    if (!quizBank || quizBank.length === 0) {
      console.log(`Quiz bank is empty: ${storagePath}`);
      return;
    }

    const todayQuiz = quizBank.find(q => q.date === dateStr);
    if (!todayQuiz) {
      console.log(`No quiz found for date: ${dateStr} (${storagePath})`);
      return;
    }

    const notificationBody = `${todayQuiz.question} 👉 Tap to answer!`;
    const dataPayload = {
      type: 'daily_quiz',
      date: dateStr,
    };
    if (mode) {
      dataPayload.mode = mode;
    }

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
        data: dataPayload,
        android: {
          notification: {
            channelId: channelId,
            priority: 'high',
            sound: 'default',
            color: color,
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

    console.log(`✅ FCM 발송 완료 (${storagePath}, mode=${mode ?? 'normal'}) — 성공: ${successCount}, 실패: ${failCount}`);
  } catch (error) {
    console.error(`Error sending push for ${storagePath}:`, error);
  }
}

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

    // 상품 종류 라벨 (알림만 보고 monthly/yearly/lifetime 바로 구분되도록)
    const PRODUCT_LABELS = {
      travelog_premium_yearly: 'Yearly (Legacy)',
      travelog_premium_yearly_v2: 'Yearly',
      travelog_premium_monthly: 'Monthly',
      travelog_lifetime: 'Lifetime',
    };
    const productLabel = PRODUCT_LABELS[order.productId] ?? '';

    const flag = countryFlag(country);
    const titleParts = [flag];
    if (country) titleParts.push(country);
    if (amountStr) titleParts.push(amountStr);
    const title = titleParts.join(' ');
    const body = amountStr
      ? `Travelog Premium ${productLabel ? productLabel + ' ' : ''}${amountStr}`
      : 'Travelog Premium 결제 완료';

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