"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.submitDailyQuiz = exports.updateDailyQuiz = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
// 1. 매일 자정(UTC) 오늘의 퀴즈를 업데이트하는 스케줄러 (v2 스펙)
exports.updateDailyQuiz = (0, scheduler_1.onSchedule)({
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
    }
    else {
        console.error(`Quiz for ${todayStr} not found!`);
    }
});
// 2. 유저가 선택한 정답을 검증하고 기록하는 함수 (v2 스펙)
exports.submitDailyQuiz = (0, https_1.onCall)({
    maxInstances: 10
}, async (request) => {
    // v2에서는 context 대신 request.auth를 사용해 유저 검증을 해
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;
    const selectedIndex = request.data.selectedIndex;
    // 오늘의 퀴즈 기준 상태 조회
    const currentStatus = await db.collection("daily_quiz_status").doc("current").get();
    if (!currentStatus.exists) {
        throw new https_1.HttpsError("not-found", "No quiz available today.");
    }
    const { quizId, utcDate } = currentStatus.data();
    // 이미 풀었는지 체크
    const historyRef = db.collection("users").doc(uid).collection("quiz_history").doc(utcDate);
    const historyDoc = await historyRef.get();
    if (historyDoc.exists) {
        throw new https_1.HttpsError("already-exists", "You already solved today's quiz.");
    }
    // 퀴즈 정답지 조회
    const quizDoc = await db.collection("quizzes").doc(quizId).get();
    if (!quizDoc.exists) {
        throw new https_1.HttpsError("not-found", "Quiz data details missing.");
    }
    const { correctAnswerIndex, explanation } = quizDoc.data();
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
//# sourceMappingURL=index.js.map