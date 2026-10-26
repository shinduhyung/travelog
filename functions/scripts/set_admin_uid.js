// Revenue 앱(익명 로그인) 계정에 admin 클레임을 붙인다. 앱을 지웠다 다시 깔면 익명 uid가 바뀌어서 필요.
// 사용법 (jidoapp/functions 폴더에서): node scripts/set_admin_uid.js <uid>
const admin = require("firebase-admin");

async function main() {
  const uid = process.argv[2];
  if (!uid) {
    console.error("Usage: node scripts/set_admin_uid.js <uid>");
    process.exit(1);
  }
  admin.initializeApp({ projectId: "proboscis-2025" });
  const user = await admin.auth().getUser(uid);
  await admin.auth().setCustomUserClaims(uid, { ...(user.customClaims || {}), admin: true });
  console.log(uid, (await admin.auth().getUser(uid)).customClaims);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
