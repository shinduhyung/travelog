'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const model = require('./twin_model');
const catalog = require('./catalog.json');

// Cache only travel sets and city-sharing preferences; no names or contact details.
let pending = null;
let expires = 0;
async function members(db) {
  if (pending && Date.now() < expires) return pending;
  expires = Date.now() + 60 * 60 * 1000;
  pending = (async () => {
    const rows = [];
    let cursor = null;
    while (true) {
      let query = db.collection('users').orderBy(admin.firestore.FieldPath.documentId())
        .select('country_visits_v2').limit(500);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        const countries = model.countries(doc.data().country_visits_v2, catalog.countryAliases);
        if (countries.length) rows.push({uid: doc.id, countries});
      }
      if (page.size < 500) break;
      cursor = page.docs[page.docs.length - 1];
    }
    return rows;
  })().catch(error => {pending = null; expires = 0; throw error;});
  return pending;
}

exports.discoverCountryTwin = onCall({maxInstances: 1, memory: '512MiB', timeoutSeconds: 120}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to find your travel twin.');
  const input = request.data?.countries;
  const allowed = new Set(Object.values(catalog.countryAliases));
  if (!Array.isArray(input) || input.length > 300 || input.some(c => typeof c !== 'string' || !allowed.has(c))) {
    throw new HttpsError('invalid-argument', 'A valid visited-country list is required.');
  }
  const db = admin.firestore();
  const [mineDoc, mineProfile] = await Promise.all([db.collection('users').doc(request.auth.uid).get(), db.collection('profiles').doc(request.auth.uid).get()]);
  const mine = model.travel(mineDoc.data() || {}, catalog.countryAliases, mineProfile.data()?.privacy);
  const pool = await members(db);
  const selection = model.closest(mine.countries, pool, request.auth.uid);
  if (!selection.best) return {match: null, compared: selection.compared};
  const uid = selection.best.row.uid;
  const [userDoc, badgeDoc, profileDoc] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('users').doc(uid).collection('badges').doc('unlocked').get(),
    db.collection('profiles').doc(uid).get(),
  ]);
  if (!userDoc.exists) {expires = 0; return {match: null, compared: selection.compared};}
  const result = model.anonymousResult(userDoc.data(), badgeDoc.exists ? badgeDoc.data() : null,
    profileDoc.data()?.privacy, catalog.countryAliases, catalog.badgePoints);
  // If this member's country set changed during the cache interval, don't
  // publish a stale similarity next to their current travel list.
  if (JSON.stringify(result.countries) !== JSON.stringify(selection.best.row.countries)) {
    expires = 0;
    throw new HttpsError('unavailable', 'Travel records changed. Please try again.');
  }
  const current = model.closest(mine.countries, [{uid, ...result}], request.auth.uid).best;
  if (!current) return {match: null, compared: selection.compared};
  const [friend, sent] = await Promise.all([db.doc(`users/${request.auth.uid}/friends/${uid}`).get(), db.doc(`social_friend_requests/${uid}/incoming/${request.auth.uid}`).get()]);
  await db.doc(`discover_grants/${request.auth.uid}/targets/${uid}`).set({expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000)});
  return {mine, match: {...result, uid, nationality: userDoc.data()?.homeCountryIsoA3 || userDoc.data()?.selectedPassportIso || profileDoc.data()?.homeCountryIso3 || null, travelerType: model.travelerType(userDoc.data(), profileDoc.data()), friendState: friend.exists ? 'friends' : sent.exists ? 'sent' : 'none', similarity: current.similarity, shared: result.countries.filter(c => mine.countries.includes(c)).length},
    compared: selection.compared};
});
