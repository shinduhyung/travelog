// App Store Server API 연동 헬퍼.
// - AppStoreServerAPIClient: originalTransactionId로 구독 상태(getAllSubscriptionStatuses) 조회
// - SignedDataVerifier: 응답에 들어있는 signedTransactionInfo/signedRenewalInfo(JWS)를
//   Apple의 서명인지 검증하고 실제 값(가격/만료일/오퍼타입 등)으로 디코딩
//
// 필요한 준비물 (functions/ 폴더 기준):
//   1. functions/SubscriptionKey_4A33FUJNJ9.p8   ← App Store Connect에서 발급받은 In-App Purchase 키
//   2. functions/apple_root_certs/AppleRootCA-G3.cer
//        https://www.apple.com/certificateauthority/ 페이지에서 "Apple Root CA - G3 Root" 직접 다운로드해서
//        이 경로에 넣어두면 됨 (Apple이 안정적인 다운로드 URL을 공식 문서화하지 않아서 자동 다운로드 대신 수동 배치)
//   3. APPLE_APP_STORE_ID는 이미 아래에 하드코딩되어 있음 (6760092556) — 앱이 바뀌면 여기서 수정.
//
// npm install @apple/app-store-server-library --save  (functions 폴더에서)

const fs = require('fs');
const path = require('path');
const {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
} = require('@apple/app-store-server-library');

const APPLE_ISSUER_ID = '57fb8587-154a-4f47-8751-53922573c21f';
const APPLE_KEY_ID = '4A33FUJNJ9';
const APPLE_BUNDLE_ID = 'com.ahnlee.travellog';
const APPLE_KEY_PATH = path.join(__dirname, 'SubscriptionKey_4A33FUJNJ9.p8');
const APPLE_ROOT_CERTS_DIR = path.join(__dirname, 'apple_root_certs');

// App Store Connect > 앱 정보 에서 확인한 숫자 Apple ID. Production 환경
// SignedDataVerifier에 필수.
const APPLE_APP_STORE_ID = 6760092556;

const ENVIRONMENT = Environment.PRODUCTION;

let _client = null;
function getAppStoreServerClient() {
  if (_client) return _client;
  const encodedKey = fs.readFileSync(APPLE_KEY_PATH, 'utf8');
  _client = new AppStoreServerAPIClient(
    encodedKey,
    APPLE_KEY_ID,
    APPLE_ISSUER_ID,
    APPLE_BUNDLE_ID,
    ENVIRONMENT,
  );
  return _client;
}

let _verifier = null;
function getSignedDataVerifier() {
  if (_verifier) return _verifier;
  if (!APPLE_APP_STORE_ID) {
    throw new Error(
      'APPLE_APP_STORE_ID is not set — required for Production SignedDataVerifier. ' +
      'Set it via functions/.env or firebase functions:config.',
    );
  }
  const certFiles = fs.readdirSync(APPLE_ROOT_CERTS_DIR)
    .filter((f) => f.endsWith('.cer'));
  if (certFiles.length === 0) {
    throw new Error(
      `No .cer files found in ${APPLE_ROOT_CERTS_DIR} — download Apple's root certs from ` +
      'https://www.apple.com/certificateauthority/ and place them there.',
    );
  }
  const rootCertificates = certFiles.map((f) =>
    fs.readFileSync(path.join(APPLE_ROOT_CERTS_DIR, f)),
  );
  const enableOnlineChecks = true;
  _verifier = new SignedDataVerifier(
    rootCertificates,
    enableOnlineChecks,
    ENVIRONMENT,
    APPLE_BUNDLE_ID,
    APPLE_APP_STORE_ID,
  );
  return _verifier;
}

/**
 * originalTransactionId 하나로 그 구독의 최신 상태 + 디코딩된 트랜잭션 목록을 조회.
 * 반환: { statuses: [{ status, decodedTransaction, decodedRenewalInfo }] }
 *   status: 1=ACTIVE, 2=EXPIRED, 3=BILLING_RETRY, 4=BILLING_GRACE_PERIOD, 5=REVOKED
 *   decodedTransaction.price는 밀리단위(예: 10990 = $10.99, /1000 하면 실제 금액)
 *   decodedTransaction.offerType이 있으면(1/2/3) 프로모션/오퍼 코드/도입 오퍼로 결제된 것
 */
async function fetchDecodedSubscriptionStatus(originalTransactionId) {
  const client = getAppStoreServerClient();
  const verifier = getSignedDataVerifier();

  const statusResponse = await client.getAllSubscriptionStatuses(originalTransactionId);

  const results = [];
  for (const group of statusResponse.data ?? []) {
    for (const last of group.lastTransactions ?? []) {
      const decodedTransaction = last.signedTransactionInfo
        ? await verifier.verifyAndDecodeTransaction(last.signedTransactionInfo)
        : null;
      const decodedRenewalInfo = last.signedRenewalInfo
        ? await verifier.verifyAndDecodeRenewalInfo(last.signedRenewalInfo)
        : null;
      results.push({
        status: last.status,
        decodedTransaction,
        decodedRenewalInfo,
      });
    }
  }
  return { statuses: results };
}

module.exports = {
  fetchDecodedSubscriptionStatus,
  getAppStoreServerClient,
  getSignedDataVerifier,
};
