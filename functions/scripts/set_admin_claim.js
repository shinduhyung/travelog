// Firebase Auth 계정에 admin 커스텀 클레임을 부여/회수한다.
// firestore.rules의 isAdmin()이 이 클레임(request.auth.token.admin == true)을 본다.
//
// 사용법 (jidoapp/functions 폴더에서):
//   node scripts/set_admin_claim.js <email>            -> admin 부여
//   node scripts/set_admin_claim.js <email> --revoke   -> admin 회수
//   node scripts/set_admin_claim.js <email> --check    -> 현재 클레임 확인
//
// 인증 (둘 중 하나):
//   gcloud auth application-default login
//   또는 GOOGLE_APPLICATION_CREDENTIALS=<서비스 계정 키 json 경로>
//
// 클레임은 해당 계정이 다음에 ID 토큰을 갱신할 때 반영된다.
// Travelog Admin 앱은 시작할 때 getIdTokenResult(true)로 강제 갱신하므로
// 앱을 재시작하면 바로 적용된다.

const admin = require("firebase-admin");

const PROJECT_ID = "proboscis-2025";

async function main() {
  const [email, flag] = process.argv.slice(2);
  if (!email || (flag && !["--revoke", "--check"].includes(flag))) {
    console.error("Usage: node scripts/set_admin_claim.js <email> [--revoke|--check]");
    process.exit(1);
  }

  admin.initializeApp({ projectId: PROJECT_ID });
  const user = await admin.auth().getUserByEmail(email);

  if (flag === "--check") {
    console.log(`${email} (${user.uid}) claims:`, user.customClaims || {});
    return;
  }

  const claims = { ...(user.customClaims || {}) };
  if (flag === "--revoke") {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await admin.auth().setCustomUserClaims(user.uid, claims);
  console.log(`${email} (${user.uid}) claims ->`, claims);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
