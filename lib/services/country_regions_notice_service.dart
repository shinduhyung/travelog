import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract class CountryRegionsNoticeStore {
  Future<bool> isPending(String uid);
  Future<bool> claim(String uid, String token, bool Function() canShow);
  Future<void> release(String uid, String token);
}

class FirestoreCountryRegionsNoticeStore implements CountryRegionsNoticeStore {
  static const field = 'countryRegionsNoticeV1';
  static const tokenField = 'countryRegionsNoticeV1Token';
  static const timeField = 'countryRegionsNoticeV1At';

  @override
  Future<bool> isPending(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return snapshot.exists && snapshot.data()?[field] == null;
  }

  @override
  Future<bool> claim(String uid, String token, bool Function() canShow) {
    final firestore = FirebaseFirestore.instance;
    final ref = firestore.collection('users').doc(uid);
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()?[field] != null || !canShow()) {
        return false;
      }
      transaction.update(ref, {
        field: 'shown',
        tokenField: token,
        timeField: FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<void> release(String uid, String token) {
    final firestore = FirebaseFirestore.instance;
    final ref = firestore.collection('users').doc(uid);
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.data()?[field] == 'shown' &&
          snapshot.data()?[tokenField] == token) {
        transaction.update(ref, {
          field: FieldValue.delete(),
          tokenField: FieldValue.delete(),
          timeField: FieldValue.delete(),
        });
      }
    });
  }
}

class CountryRegionsNoticeClaim {
  final String uid;
  final String token;
  const CountryRegionsNoticeClaim(this.uid, this.token);
}

/// Account-scoped server claim prevents repeats on other devices. Local cache
/// avoids further reads on a device after the announcement has been displayed.
class CountryRegionsNoticeService {
  final CountryRegionsNoticeStore store;
  CountryRegionsNoticeService({CountryRegionsNoticeStore? store})
    : store = store ?? FirestoreCountryRegionsNoticeStore();

  static String seenKey(String uid) => 'country_regions_notice_v1_seen_$uid';

  Future<bool> isPending({
    required String? uid,
    required bool isNewAccount,
  }) async {
    if (uid == null || isNewAccount) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(seenKey(uid)) == true) return false;
    return store.isPending(uid);
  }

  Future<CountryRegionsNoticeClaim?> claim({
    required String? uid,
    required bool isNewAccount,
    required bool Function() canShow,
  }) async {
    if (uid == null || isNewAccount || !canShow()) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(seenKey(uid)) == true || !canShow()) return null;
    final token = const Uuid().v4();
    if (!await store.claim(uid, token, canShow)) return null;
    final claim = CountryRegionsNoticeClaim(uid, token);
    if (!canShow()) {
      await release(claim);
      return null;
    }
    return claim;
  }

  Future<void> markDisplayed(CountryRegionsNoticeClaim claim) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey(claim.uid), true);
  }

  Future<void> release(CountryRegionsNoticeClaim claim) =>
      store.release(claim.uid, claim.token);
}
