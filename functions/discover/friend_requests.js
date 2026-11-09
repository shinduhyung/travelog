'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const {createHash} = require('node:crypto');
const options = {maxInstances: 2, timeoutSeconds: 60};
function authenticated(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  return request.auth.uid;
}
function target(request) {
  const uid = request.data?.uid;
  if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/')) throw new HttpsError('invalid-argument', 'Invalid member.');
  return uid;
}
exports.socialSendFriendRequest = onCall(options, async request => {
  const from = authenticated(request), to = target(request);
  if (from === to) throw new HttpsError('invalid-argument', 'Choose another traveler.');
  const db = admin.firestore();
  return db.runTransaction(async tx => {
    const ref = db.doc(`social_friend_requests/${to}/incoming/${from}`);
    const quota = db.doc(`social_request_limits/${from}`);
    const [grant, friend, existing, limit, profile] = await Promise.all([
      tx.get(db.doc(`discover_grants/${from}/targets/${to}`)), tx.get(db.doc(`users/${from}/friends/${to}`)),
      tx.get(ref), tx.get(quota), tx.get(db.doc(`profiles/${from}`)),
    ]);
    if (friend.exists) return {state: 'friends'};
    if (existing.exists) return {state: 'sent'};
    if (!grant.exists || grant.data().expiresAt.toMillis() < Date.now()) throw new HttpsError('permission-denied', 'Refresh your travel soulmate first.');
    const day = new Date().toISOString().slice(0, 10);
    const count = limit.data()?.day === day ? limit.data().count : 0;
    if (count >= 10) throw new HttpsError('resource-exhausted', 'Try again tomorrow.');
    tx.set(quota, {day, count: count + 1});
    tx.create(ref, {fromUid: from, nationality: profile.data()?.homeCountryIso3 || null, createdAt: admin.firestore.FieldValue.serverTimestamp()});
    return {state: 'sent'};
  });
});
exports.socialRespondFriendRequest = onCall(options, async request => {
  const to = authenticated(request), from = target(request);
  if (typeof request.data?.accept !== 'boolean' || from === to) throw new HttpsError('invalid-argument', 'Invalid response.');
  const db = admin.firestore();
  return db.runTransaction(async tx => {
    const ref = db.doc(`social_friend_requests/${to}/incoming/${from}`);
    if (!(await tx.get(ref)).exists) throw new HttpsError('not-found', 'Request is no longer available.');
    if (request.data.accept) {
      const fields = {createdAt: admin.firestore.FieldValue.serverTimestamp()};
      tx.set(db.doc(`users/${from}/friends/${to}`), fields);
      tx.set(db.doc(`users/${to}/friends/${from}`), fields);
      tx.delete(db.doc(`social_friend_requests/${from}/incoming/${to}`));
    }
    tx.delete(ref);
    return {state: request.data.accept ? 'friends' : 'declined'};
  });
});
// Possession of the opaque FCM token permits unbinding on logout. Binding always
// takes the authenticated UID, never a caller-supplied account identifier.
exports.socialRegisterPushToken = onCall(options, async request => {
  const token = request.data?.token;
  if (typeof token !== 'string' || token.length < 40 || token.length > 4096) throw new HttpsError('invalid-argument', 'Invalid push token.');
  const ref = admin.firestore().doc(`social_push_tokens/${createHash('sha256').update(token).digest('hex')}`);
  if (!request.auth || request.data?.unbind === true) await ref.delete();
  else await ref.set({uid: request.auth.uid, token, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
  return {ok: true};
});
exports.notifySocialFriendRequest = onDocumentCreated({document: 'social_friend_requests/{recipient}/incoming/{sender}', maxInstances: 2}, async event => {
  if (!event.data) return;
  const db = admin.firestore();
  // The request may have been accepted before this event was delivered.
  if (!(await event.data.ref.get()).exists) return;
  const docs = await db.collection('social_push_tokens').where('uid', '==', event.params.recipient).get();
  for (let i = 0; i < docs.size; i += 500) {
    const batch = docs.docs.slice(i, i + 500);
    const result = await admin.messaging().sendEachForMulticast({tokens: batch.map(d => d.data().token),
      notification: {title: 'New travel friend request', body: 'A traveler wants to connect with you.'},
      data: {type: 'social_friend_request'}, android: {priority: 'high'},
      apns: {payload: {aps: {sound: 'default'}}}});
    await Promise.all(result.responses.map((r, n) => !r.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(r.error?.code) ? batch[n].ref.delete() : Promise.resolve()));
  }
});

exports.socialRefreshFriendIdentities = onCall({maxInstances:2,timeoutSeconds:120}, async request => {
 const uid=authenticated(request), db=admin.firestore(), model=require('./twin_model');
 const friends=await db.collection('users').doc(uid).collection('friends').get();
 let updated=0;
 for(let offset=0;offset<friends.size;offset+=100){
  const ids=friends.docs.slice(offset,offset+100).map(d=>d.id);
  const [users,profiles]=await Promise.all([
   db.getAll(...ids.map(id=>db.doc(`users/${id}`)),{fieldMask:['homeCountryIsoA3','selectedPassportIso','ai_analysis_result']}),
   db.getAll(...ids.map(id=>db.doc(`profiles/${id}`))),
  ]);
  const batch=db.batch();let count=0;
  for(let i=0;i<ids.length;i++){
   if(!users[i].exists||!profiles[i].exists)continue;
   const raw=users[i].data(),profile=profiles[i].data();
   const nationality=raw.homeCountryIsoA3||raw.selectedPassportIso||profile.homeCountryIso3||null;
   const travelerType=model.travelerType(raw,profile);
   if(nationality!==profile.homeCountryIso3||travelerType!==(profile.travelerType??null)){
    batch.update(profiles[i].ref,{homeCountryIso3:nationality,travelerType});count++;
   }
  }
  if(count){await batch.commit();updated+=count;}
 }
 return {updated};
});
