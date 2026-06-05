import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// 1. 매일 자정(UTC) 오늘의 퀴즈를 업데이트하는 스케줄러 (v2 스펙)
export const updateDailyQuiz = onSchedule({
  schedule: "0 0 * * *",
  timeZone: "UTC",
  maxInstances: 10
}, async (event) => {
  const todayStr = new Date().toISOString().split("T")[0].replace(/-/g, "");
  const quizDoc = await db.collection("quizzes").doc(`quiz_${todayStr}`).get();

  if (quizDoc.exists) {
    await db.collection("daily_quiz_status").doc("current").set({
      utcDate: todayStr,
      quizId: `quiz_${todayStr}`
    });
    console.log(`Daily quiz updated for ${todayStr}`);
  } else {
    console.error(`Quiz for ${todayStr} not found!`);
  }
});

// 2. 유저가 선택한 정답을 검증하고 기록하는 함수 (v2 스펙)
export const submitDailyQuiz = onCall({
  maxInstances: 10
}, async (request) => {
  // v2에서는 context 대신 request.auth를 사용해 유저 검증을 해
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const uid = request.auth.uid;
  const selectedIndex = request.data.selectedIndex;

  // 오늘의 퀴즈 기준 상태 조회
  const currentStatus = await db.collection("daily_quiz_status").doc("current").get();
  if (!currentStatus.exists) {
    throw new HttpsError("not-found", "No quiz available today.");
  }

  const { quizId, utcDate } = currentStatus.data() as { quizId: string, utcDate: string };

  // 이미 풀었는지 체크
  const historyRef = db.collection("users").doc(uid).collection("quiz_history").doc(utcDate);
  const historyDoc = await historyRef.get();
  if (historyDoc.exists) {
    throw new HttpsError("already-exists", "You already solved today's quiz.");
  }

  // 퀴즈 정답지 조회
  const quizDoc = await db.collection("quizzes").doc(quizId).get();
  if (!quizDoc.exists) {
    throw new HttpsError("not-found", "Quiz data details missing.");
  }

  const { correctAnswerIndex, explanation } = quizDoc.data() as { correctAnswerIndex: number, explanation: string };
  const isCorrect = selectedIndex === correctAnswerIndex;

  // 결과 기록
  await historyRef.set({
    isCorrect,
    solvedAt: admin.firestore.FieldValue.serverTimestamp(),
    selectedAnswerIndex: selectedIndex
  });
  
  return {
    isCorrect,
    correctAnswerIndex,
    explanation
  };
});