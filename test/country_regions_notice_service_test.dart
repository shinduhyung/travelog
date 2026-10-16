import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/country_regions_notice_service.dart';

class _Store implements CountryRegionsNoticeStore {
  final Map<String, String> rows = {};
  int attempts = 0;
  void Function()? afterClaim;
  @override
  Future<bool> isPending(String uid) async => !rows.containsKey(uid);
  @override
  Future<bool> claim(String uid, String token, bool Function() canShow) async {
    attempts++;
    if (rows.containsKey(uid) || !canShow()) return false;
    rows[uid] = token;
    afterClaim?.call();
    return true;
  }

  @override
  Future<void> release(String uid, String token) async {
    if (rows[uid] == token) rows.remove(uid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'guest, newly registered and inactive users never claim an announcement',
    () async {
      final store = _Store();
      final service = CountryRegionsNoticeService(store: store);
      expect(
        await service.claim(
          uid: null,
          isNewAccount: false,
          canShow: () => true,
        ),
        isNull,
      );
      expect(
        await service.claim(
          uid: 'new',
          isNewAccount: true,
          canShow: () => true,
        ),
        isNull,
      );
      expect(
        await service.claim(
          uid: 'old',
          isNewAccount: false,
          canShow: () => false,
        ),
        isNull,
      );
      expect(store.attempts, 0);
    },
  );

  test(
    'existing user is notified once locally and once across fresh devices',
    () async {
      final store = _Store();
      final service = CountryRegionsNoticeService(store: store);
      final first = await service.claim(
        uid: 'old',
        isNewAccount: false,
        canShow: () => true,
      );
      expect(first, isNotNull);
      await service.markDisplayed(first!);
      expect(
        await service.claim(
          uid: 'old',
          isNewAccount: false,
          canShow: () => true,
        ),
        isNull,
      );
      expect(store.attempts, 1);
      SharedPreferences.setMockInitialValues(
        {},
      ); // Simulate a different device.
      expect(
        await CountryRegionsNoticeService(
          store: store,
        ).claim(uid: 'old', isNewAccount: false, canShow: () => true),
        isNull,
      );
      expect(store.attempts, 2);
      expect(
        await service.claim(
          uid: 'another-old',
          isNewAccount: false,
          canShow: () => true,
        ),
        isNotNull,
      );
    },
  );

  test(
    'new-account server marker prevents notice after logout or reinstall',
    () async {
      final store = _Store()..rows['new'] = 'new_account';
      expect(
        await CountryRegionsNoticeService(
          store: store,
        ).claim(uid: 'new', isNewAccount: false, canShow: () => true),
        isNull,
      );
    },
  );

  test('simultaneous existing-user visits produce only one claim', () async {
    final store = _Store();
    final claims = await Future.wait(
      List.generate(
        2,
        (_) => CountryRegionsNoticeService(
          store: store,
        ).claim(uid: 'same', isNewAccount: false, canShow: () => true),
      ),
    );
    expect(claims.whereType<CountryRegionsNoticeClaim>(), hasLength(1));
  });

  test(
    'leaving Countries during a claim preserves eligibility for next entry',
    () async {
      var visible = true;
      final store = _Store()..afterClaim = () => visible = false;
      final service = CountryRegionsNoticeService(store: store);
      expect(
        await service.claim(
          uid: 'old',
          isNewAccount: false,
          canShow: () => visible,
        ),
        isNull,
      );
      expect(store.rows, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          CountryRegionsNoticeService.seenKey('old'),
        ),
        isNull,
      );
      visible = true;
      store.afterClaim = null;
      expect(
        await service.claim(
          uid: 'old',
          isNewAccount: false,
          canShow: () => visible,
        ),
        isNotNull,
      );
    },
  );
  test(
    'passive NEW eligibility check never claims or consumes the notice',
    () async {
      final store = _Store();
      final service = CountryRegionsNoticeService(store: store);
      expect(await service.isPending(uid: 'old', isNewAccount: false), isTrue);
      expect(store.attempts, 0);
      expect(store.rows, isEmpty);
      expect(await service.isPending(uid: null, isNewAccount: false), isFalse);
      expect(await service.isPending(uid: 'new', isNewAccount: true), isFalse);
      final claim = await service.claim(
        uid: 'old',
        isNewAccount: false,
        canShow: () => true,
      );
      await service.markDisplayed(claim!);
      expect(await service.isPending(uid: 'old', isNewAccount: false), isFalse);
    },
  );
}
