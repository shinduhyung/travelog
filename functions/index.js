const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

admin.initializeApp();

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

      const tokens = tokensSnapshot.docs.map(doc => doc.data().token).filter(Boolean);
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
    if (!order || order.platform !== 'android') return;

    const orderId = event.params.orderId;
    const purchaseTime = order.purchaseTime?.toDate?.() ?? new Date();
    const timeStr = purchaseTime.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });

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
          title: '🎉 새 구독 발생!',
          body: `Travelog Premium 결제 완료 (${timeStr})`,
        },
        data: {
          type: 'new_subscription',
          orderId: orderId,
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

    console.log(`✅ 구독 알림 발송 (revenue_dashboard only): ${orderId}`);
  }
);