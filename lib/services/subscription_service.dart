import 'dart:async';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:jidoapp/services/ad_service.dart';

/// A user's current premium tier, for UI theming purposes (see
/// [SubscriptionService.activePlanKind]).
enum PremiumPlanKind { none, monthly, yearly, lifetime }

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  // ─── Product IDs ──────────────────────────────────────────────────────
  // Legacy yearly is kept forever so existing subscribers keep renewing at
  // their original price — the store auto-renews them on this SKU with no
  // migration needed. New users never see this product; they see kYearlyId.
  static const String kLegacyYearlyId = 'travelog_premium_yearly';
  static const String kYearlyId = 'travelog_premium_yearly_v2';
  static const String kMonthlyId = 'travelog_premium_monthly';
  static const String kLifetimeId = 'travelog_lifetime';

  static const String _prefKeyIsPremium = 'is_premium';
  static const String _prefKeyHasEverBeenPremium = 'has_ever_been_premium';
  static const String _prefKeyActiveProductId = 'active_product_id';
  static const String _prefKeyIsLifetime = 'is_lifetime';

  static const bool _debugForceNonPremium =
      false; // [디버깅용] true로 두면 실제 구독 상태와 무관하게 항상 비구독으로 취급됨. 프리미엄 뱃지 잠금 UI 테스트 끝나면 반드시 false로 되돌릴 것.

  // TikTok Android Native SDK와 연결하는 통로
  static const MethodChannel _tiktokChannel = MethodChannel(
    'com.ahnlee.jidoapp/tiktok_events',
  );

  final InAppPurchase _iap = InAppPurchase.instance;

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isPremium = false;
  bool _hasEverBeenPremium = false;
  bool _isLifetime = false;
  String? _activeProductId;
  bool _isLoading = false;
  bool _isAvailable = false;

  /// Queried product details keyed by product id. Replaces the old single
  /// `_productDetails` field now that there are up to 3 purchasable
  /// products visible to any one user (yearly-or-legacy, monthly, lifetime).
  final Map<String, ProductDetails> _productDetailsById = {};

  bool get isPremium => _isPremium;

  bool get hasEverBeenPremium => _hasEverBeenPremium;

  bool get isLifetime => _isLifetime;

  bool get isLoading => _isLoading;

  bool get isAvailable => _isAvailable;

  /// True once a legacy-priced yearly purchase (or a pre-migration premium
  /// state) has been detected for this user.
  bool get isLegacyYearlyUser => _activeProductId == kLegacyYearlyId;

  /// Which plan the user is actually on right now, for UI theming (avatar
  /// ring color, "Premium Active" badge color, etc.) — not for gating,
  /// `isPremium` still covers that. Legacy and current-price yearly both
  /// report [PremiumPlanKind.yearly] since they should look the same.
  PremiumPlanKind get activePlanKind {
    if (!_isPremium) return PremiumPlanKind.none;
    if (_isLifetime) return PremiumPlanKind.lifetime;
    if (_activeProductId == kMonthlyId) return PremiumPlanKind.monthly;
    return PremiumPlanKind.yearly;
  }

  /// The yearly product id to actually show on the paywall for this user:
  /// their grandfathered legacy price if they're already on it, otherwise
  /// the current-price product. Never mix the two for the same user.
  String get yearlyProductIdToOffer =>
      isLegacyYearlyUser ? kLegacyYearlyId : kYearlyId;

  ProductDetails? productDetailsFor(String productId) =>
      _productDetailsById[productId];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _isPremium = _debugForceNonPremium
        ? false
        : (prefs.getBool(_prefKeyIsPremium) ?? false);

    _hasEverBeenPremium = _debugForceNonPremium
        ? false
        : (prefs.getBool(_prefKeyHasEverBeenPremium) ?? false);

    _isLifetime = _debugForceNonPremium
        ? false
        : (prefs.getBool(_prefKeyIsLifetime) ?? false);

    _activeProductId = prefs.getString(_prefKeyActiveProductId);

    // One-time migration: users who were already premium before this field
    // existed (is_premium=true, but no active_product_id recorded and not
    // lifetime) can only have gotten there via the original yearly SKU —
    // that was the only product that existed. Tag them accordingly so the
    // paywall keeps offering them their original price.
    if (_isPremium && _activeProductId == null && !_isLifetime) {
      _activeProductId = kLegacyYearlyId;
      await prefs.setString(_prefKeyActiveProductId, kLegacyYearlyId);
      debugPrint(
        '[SubscriptionService] migrated existing premium user to legacy yearly',
      );
    }

    notifyListeners();

    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        debugPrint('[SubscriptionService] purchaseStream error: $e');
      },
    );

    await _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) return;

    // Only query the one yearly variant this user should see, plus monthly
    // and lifetime, which everyone sees. This keeps legacy-priced users
    // from ever having the new-price product resolve on their device.
    final idsToQuery = <String>{
      yearlyProductIdToOffer,
      kMonthlyId,
      kLifetimeId,
    };

    final response = await _iap.queryProductDetails(idsToQuery);

    for (final details in response.productDetails) {
      _productDetailsById[details.id] = details;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        '[SubscriptionService] products not found: ${response.notFoundIDs}',
      );
    }

    notifyListeners();

    if (!_debugForceNonPremium) {
      await _iap.restorePurchases();
      // 만료 확인은 앱 시작을 늦추지 않도록 기다리지 않고 백그라운드로 돌린다.
      unawaited(_verifyEntitlementOnStartup());
    }
  }

  // ─── 구독 만료 확인 ─────────────────────────────────────────────────────
  // 예전엔 _setPremium(false)를 부르는 곳이 없어서, 해지한 월간/연간 구독자도
  // 프리미엄이 영원히 유지됐다. 스토어가 "확실히" 구독 없음이라고 답했을 때만
  // 내린다. 오류·타임아웃·오프라인·애매한 응답은 전부 "판단 불가"로 보고 유지.

  static const Set<String> _subscriptionIds = {
    kMonthlyId,
    kLegacyYearlyId,
    kYearlyId,
  };

  static const Duration _entitlementCheckTimeout = Duration(seconds: 20);

  /// iOS: 만료일이 지나도 결제 재시도/유예 중일 수 있어 이만큼은 더 봐준다.
  static const Duration _expiryGrace = Duration(days: 3);

  /// _setPremium(true)가 불릴 때마다 증가. 확인 도중 구매/복원으로 프리미엄이
  /// 켜졌으면 확인 결과(조회 시작 시점 기준)를 버리기 위해 쓴다.
  int _premiumActivationSeq = 0;

  bool _entitlementCheckRunning = false;

  Future<void> _verifyEntitlementOnStartup() async {
    if (_debugForceNonPremium) return;
    if (!_isPremium || _isLifetime) return; // 내릴 게 없거나 평생 이용권
    if (!_isAvailable) return;
    if (_entitlementCheckRunning) return;
    _entitlementCheckRunning = true;

    final int seqAtStart = _premiumActivationSeq;
    try {
      final _EntitlementCheck result;
      if (Platform.isAndroid) {
        result = await _checkAndroidEntitlement().timeout(
          _entitlementCheckTimeout,
        );
      } else if (Platform.isIOS) {
        result = await _checkIosEntitlement().timeout(
          _entitlementCheckTimeout,
        );
      } else {
        return;
      }

      debugPrint(
        '[SubscriptionService] entitlement check: ${result.state.name} '
        '(${result.productId ?? '-'})',
      );

      if (result.state != _EntitlementState.notEntitled) return;

      // 확인 중에 구매/복원이 들어왔거나, 결제가 진행 중이거나, 그 사이 평생
      // 이용권이 잡혔으면 내리지 않는다.
      if (_premiumActivationSeq != seqAtStart ||
          _isLoading ||
          _isLifetime ||
          !_isPremium) {
        return;
      }

      await _downgradeExpired(result.productId ?? _activeProductId);
    } on TimeoutException {
      debugPrint('[SubscriptionService] entitlement check timed out — keep premium');
    } catch (e) {
      debugPrint('[SubscriptionService] entitlement check error: $e — keep premium');
    } finally {
      _entitlementCheckRunning = false;
    }
  }

  /// Android: Play Billing queryPurchases는 "현재 보유 중인" 구매만 돌려준다
  /// (만료·해지 완료·계정 보류 구독은 빠짐). 그래서 오류 없이 끝났는데 우리
  /// 상품이 하나도 없으면 = 권한 없음. restorePurchases()는 결과가 0건이면
  /// 스트림에 아무것도 안 보내서 완료 신호로 쓸 수 없으므로 이걸 직접 쓴다.
  Future<_EntitlementCheck> _checkAndroidEntitlement() async {
    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();

    if (response.error != null) {
      debugPrint(
        '[SubscriptionService] queryPastPurchases error: '
        '${response.error!.code} ${response.error!.message}',
      );
      return const _EntitlementCheck(_EntitlementState.unknown);
    }

    for (final p in response.pastPurchases) {
      // 보류(pending) 결제도 일단 보유로 본다 — 내리는 쪽으로는 보수적으로.
      if (p.productID == kLifetimeId || _subscriptionIds.contains(p.productID)) {
        return _EntitlementCheck(_EntitlementState.entitled, p.productID);
      }
    }
    return const _EntitlementCheck(_EntitlementState.notEntitled);
  }

  /// iOS: StoreKit2(이 패키지 버전의 기본값)의 Transaction.all을
  /// SK2Transaction.transactions()로 받아 구독 만료일(expirationDate)을 직접 본다.
  /// (restorePurchases()는 SK2에서 currentEntitlements를 쓰지만 0건이면 역시
  /// 아무것도 안 보내고, Dart 쪽에 currentEntitlements를 직접 주는 API는 없다.)
  ///
  /// 권한 없음으로 판단하는 조건 (전부 만족해야 함):
  ///  - 평생 이용권 트랜잭션이 하나도 없음
  ///  - 우리 구독 상품 트랜잭션이 최소 1건 있음 (0건이면 기기 이전 직후 등
  ///    아직 동기화가 안 된 상태일 수 있어 판단 불가로 본다)
  ///  - 모든 구독 트랜잭션에 만료일이 있고, 가장 늦은 만료일 + 3일이 이미 지남
  Future<_EntitlementCheck> _checkIosEntitlement() async {
    if (!InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      // StoreKit1 복원은 만료된 트랜잭션도 돌려줘서 믿을 수 없다 → 판단 안 함.
      return const _EntitlementCheck(_EntitlementState.unknown);
    }

    final transactions = await SK2Transaction.transactions();

    DateTime? latestExpiry;
    String? latestProductId;
    var sawSubscription = false;

    for (final t in transactions) {
      if (t.productId == kLifetimeId) {
        return _EntitlementCheck(_EntitlementState.entitled, t.productId);
      }
      if (!_subscriptionIds.contains(t.productId)) continue;
      sawSubscription = true;

      final millis = int.tryParse(t.expirationDate ?? '');
      if (millis == null) {
        // 구독인데 만료일을 모르면 판단 불가.
        return const _EntitlementCheck(_EntitlementState.unknown);
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(millis);
      if (latestExpiry == null || expiry.isAfter(latestExpiry)) {
        latestExpiry = expiry;
        latestProductId = t.productId;
      }
    }

    if (!sawSubscription || latestExpiry == null) {
      return const _EntitlementCheck(_EntitlementState.unknown);
    }

    if (latestExpiry.add(_expiryGrace).isAfter(DateTime.now())) {
      return _EntitlementCheck(_EntitlementState.entitled, latestProductId);
    }
    return _EntitlementCheck(_EntitlementState.notEntitled, latestProductId);
  }

  Future<void> _downgradeExpired(String? productId) async {
    debugPrint(
      '[SubscriptionService] subscription expired — premium off ($productId)',
    );
    // 재구독 시 기존 가격(레거시 연간)을 계속 보여주도록 _activeProductId는 남겨둔다.
    await _setPremium(false);
    unawaited(_logFunnelEvent('premium_expired', productId ?? 'unknown', 'startup_check'));
  }

  /// 캐시에 있으면 그대로, 없으면 스토어에서 해당 상품만 조회해 캐시에 넣는다.
  /// 조회 실패 시 null을 돌려주며, 구매 처리 자체는 막지 않는다.
  Future<ProductDetails?> _resolveProductDetails(String productId) async {
    final cached = _productDetailsById[productId];
    if (cached != null) return cached;
    try {
      if (!await _iap.isAvailable()) return null;
      final response = await _iap.queryProductDetails({productId});
      for (final details in response.productDetails) {
        _productDetailsById[details.id] = details;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] product lookup failed for $productId: $e');
    }
    return _productDetailsById[productId];
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setLoading(true);
          break;

        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchase, isRestore: false);
          break;

        case PurchaseStatus.restored:
          // 복원은 신규 구매가 아니므로 Meta/TikTok Purchase 이벤트는 전송하지 않음.
          // 단, 자동 갱신(재결제)도 앱을 다시 켤 때 restored로 들어오므로
          // Firestore 주문 저장은 _handleSuccessfulPurchase에서 항상 수행한다.
          _handleSuccessfulPurchase(purchase, isRestore: true);
          break;

        case PurchaseStatus.error:
          _setLoading(false);

          debugPrint(
            '[SubscriptionService] purchase error: ${purchase.error?.message}',
          );

          break;

        case PurchaseStatus.canceled:
          _setLoading(false);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        _completePurchaseSafely(purchase);
      }
    }
  }

  // completePurchase(=acknowledge) 실패가 조용히 묻히지 않도록 catch + 로그.
  Future<void> _completePurchaseSafely(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint(
        '[SubscriptionService] completePurchase failed for ${purchase.purchaseID}: $e',
      );
    }
  }

  Future<String?> _extractOriginalTransactionId(
    PurchaseDetails purchase,
  ) async {
    if (purchase is AppStorePurchaseDetails) {
      final original = purchase.skPaymentTransaction.originalTransaction;
      if (original?.transactionIdentifier != null) {
        return original!.transactionIdentifier;
      }
      return purchase.purchaseID;
    }

    if (purchase.purchaseID != null) {
      try {
        final transactions = await SK2Transaction.transactions();
        for (final t in transactions) {
          if (t.id == purchase.purchaseID) {
            return t.originalId;
          }
        }
        debugPrint(
          '[SubscriptionService] SK2 transaction id=${purchase.purchaseID} not found in transactions() list',
        );
      } catch (e) {
        debugPrint('[SubscriptionService] SK2 originalId lookup error: $e');
      }
    }
    return purchase.purchaseID; // 못 찾으면 자기 자신을 원본으로 취급 (안전한 폴백)
  }

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    final String productId = purchase.productID;
    final bool isLifetimePurchase = productId == kLifetimeId;

    // 실제 스토어 가격 및 통화
    // 스토어 상품 정보가 아직 안 불러와졌거나 이 상품이 목록에 없으면 가격이 0으로
    // 기록되어 광고 전환 금액과 주문 금액이 모두 0이 된다(2026-09-02 주문 실제 사례).
    // 그래서 비어 있으면 이 상품만 즉석에서 다시 조회한다.
    final ProductDetails? details = await _resolveProductDetails(productId);
    final double price = details?.rawPrice ?? 0.0;
    final String currencyCode = details?.currencyCode ?? 'USD';

    if (!isRestore) {
      await _logPurchaseEvents(
        productId: productId,
        price: price,
        currencyCode: currencyCode,
        transactionId: purchase.purchaseID,
      );
    }

    // --------------------------------------------------
    // Android 주문 정보 Firestore 저장 — isRestore와 무관하게 항상 실행.
    // 자동 갱신(재결제)은 대부분 앱이 꺼져 있을 때 일어나서, 다음 앱 실행 시
    // restorePurchases()로 restored 상태로만 감지된다. 예전엔 이 저장이
    // if (!isRestore) 안에 있어서 재결제가 통째로 누락됐음.
    //
    // 이미 있는 문서면 건드리지 않는다: restore는 앱 켤 때마다 같은 orderId를
    // 다시 보내므로, 매번 쓰면 purchaseTime(serverTimestamp)이 계속 갱신됨.
    // --------------------------------------------------
    if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
      final orderId = purchase.billingClientPurchase.orderId;

      if (orderId.isNotEmpty) {
        final docRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId);
        var orderLinked = false;

        try {
          // 로그인 상태면 이미 기록된 주문에 내 uid를 붙인다 (로그인 전에 산 주문은 uid가 비어 있어서
          // 서버가 누구 구독인지 모름 → 소셜 프로필 등급이 안 뜸). 규칙상 uid가 비었거나 내 것일 때만 된다.
          // 문서가 없으면 not-found → 아래에서 새로 기록한다.
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            try {
              await docRef.update({'uid': uid});
              debugPrint('[SubscriptionService] order $orderId linked to account (isRestore=$isRestore)');
              orderLinked = true;
            } on FirebaseException catch (e) {
              if (e.code != 'not-found') {
                debugPrint('[SubscriptionService] order $orderId not linked: ${e.code}');
                orderLinked = true; // 다른 계정의 주문이면 건드리지 않는다
              }
            }
          }

          final existing = orderLinked ? null : await docRef.get();

          if (orderLinked || existing!.exists) {
            debugPrint(
              '[SubscriptionService] order $orderId already recorded, skip (isRestore=$isRestore)',
            );
          } else {
            // Play 구독 갱신 orderId 포맷: "<원본 orderId>..N" (N은 0부터).
            // 라이프타임은 갱신이 없으므로 항상 최초 구매.
            final bool isRenewal =
                !isLifetimePurchase && orderId.contains('..');
            final String originalOrderId = isRenewal
                ? orderId.split('..').first
                : orderId;

            debugPrint(
              '[SubscriptionService] Android orderId: $orderId '
              'isRenewal=$isRenewal isRestore=$isRestore',
            );

            final int priceAmountMicros = (price * 1000000).round();

            await docRef.set({
              'orderId': orderId,
              'originalOrderId': originalOrderId,
              'purchaseToken': purchase.billingClientPurchase.purchaseToken,
              'productId': productId,
              'isLifetime': isLifetimePurchase,
              'isRenewal': isRenewal,
              'purchaseTime': FieldValue.serverTimestamp(),
              'platform': 'android',
              'status': 'purchased',
              'priceAmountMicros': priceAmountMicros,
              'priceCurrencyCode': currencyCode,
              'uid': FirebaseAuth.instance.currentUser?.uid,
              'adExperimentGroup': AdService.instance.experimentGroup,
              'deviceId': AdService.instance.deviceId,
              'userAssignedAt': AdService.instance.assignedAt != null
                  ? Timestamp.fromDate(AdService.instance.assignedAt!)
                  : null,
            });

            // 결제가 앱 밖에서 끝나거나(결제창 도중 앱 종료, 지연 결제 승인 등)
            // 다음 실행 때 처음 감지된 신규 구매는 purchased가 아니라 restored로만 들어와서
            // 위의 광고 구매 이벤트(Meta·Firebase·TikTok)가 통째로 빠졌다.
            // 이 주문 문서를 지금 처음 만든 경우 = 처음 보는 주문이므로 여기서 한 번만 보낸다.
            // 갱신은 신규 구매가 아니라서 제외하고, 이 기능 배포 전의 오래된 구매가
            // 뒤늦게 처음 기록되며 신규로 집계되는 일을 막으려고 최근 결제만 보낸다.
            if (isRestore &&
                !isRenewal &&
                _isRecentTransaction(purchase, const Duration(days: 3))) {
              debugPrint(
                '[SubscriptionService] first-seen order $orderId arrived as restored — sending purchase events',
              );
              await _logPurchaseEvents(
                productId: productId,
                price: price,
                currencyCode: currencyCode,
                transactionId: purchase.purchaseID,
              );
            }
          }
        } catch (e) {
          debugPrint('[SubscriptionService] Firestore save error: $e');
        }
      } else {
        debugPrint(
          '[SubscriptionService] ⚠️ Android purchase has no orderId — cannot record order.',
        );
      }
    }

    if (Platform.isIOS) {
      final transactionId = purchase.purchaseID;
      if (transactionId != null && transactionId.isNotEmpty) {
        final int priceAmountMicros = (price * 1000000).round();
        // 구독 갱신 여부(1년차/2년차)를 나중에 판별하기 위해 원본 트랜잭션 ID도 함께 저장.
        final originalTransactionId =
            await _extractOriginalTransactionId(purchase) ?? transactionId;

        // purchase.transactionDate = 이 트랜잭션의 실제 결제/갱신 시각(epoch millis 문자열).
        // FieldValue.serverTimestamp()는 "지금 처리된 시각"이라, restore로 과거 트랜잭션이
        // 재전달될 때마다 원래 결제일이 "오늘"로 덮어써지는 버그의 직접 원인이었음.
        // docId가 transactionId라서 merge:true로 계속 같은 문서를 다시 쓰는 구조이므로,
        // 이 필드만 고치면 앞으로의 write는 물론 이미 오염된 기존 문서도 다음 restore 때
        // 자동으로 정확한 날짜로 재덮어써진다.
        Timestamp purchaseTimestamp;
        final rawDate = purchase.transactionDate;
        final millis = rawDate != null ? int.tryParse(rawDate) : null;
        if (millis != null) {
          purchaseTimestamp = Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(millis),
          );
        } else {
          debugPrint(
            '[SubscriptionService] ⚠️ no transactionDate for $transactionId, falling back to now',
          );
          purchaseTimestamp = Timestamp.now();
        }

        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(transactionId)
              .set({
                'orderId': transactionId,
                'originalTransactionId': originalTransactionId,
                'productId': productId,
                'isLifetime': isLifetimePurchase,
                'purchaseTime': purchaseTimestamp,
                'platform': 'ios',
                'status': 'purchased',
                'priceAmountMicros': priceAmountMicros,
                'priceCurrencyCode': currencyCode,
                'uid': FirebaseAuth.instance.currentUser?.uid,
              }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[SubscriptionService] Firestore save error: $e');
        }
      } else {
        debugPrint(
          '[SubscriptionService] ⚠️ iOS purchase has no purchaseID — cannot record order.',
        );
      }
    }

    // --------------------------------------------------
    // 실제 프리미엄 활성화
    // --------------------------------------------------
    await _setPremium(
      true,
      productId: productId,
      isLifetime: isLifetimePurchase,
    );

    _setLoading(false);

    debugPrint(
      '[SubscriptionService] premium activated ($productId, restore=$isRestore)',
    );
  }

  /// 신규 구매 1건에 대한 광고·분석 구매 이벤트(Meta, Firebase, TikTok)를 보낸다.
  /// 각 이벤트 실패가 실제 구독 처리를 막으면 안 되므로 개별로 감싼다.
  Future<void> _logPurchaseEvents({
    required String productId,
    required double price,
    required String currencyCode,
    required String? transactionId,
  }) async {
    // --------------------------------------------------
    // Meta Purchase
    // --------------------------------------------------
    try {
      await _facebookAppEvents.logPurchase(
        amount: price,
        currency: currencyCode,
      );

      debugPrint(
        '[SubscriptionService] Meta Purchase sent: '
        '$price $currencyCode',
      );
    } catch (e) {
      // 광고 이벤트 실패 때문에 실제 구독 처리가 실패하면 안 됨
      debugPrint('[SubscriptionService] Meta Purchase error: $e');
    }

    // --------------------------------------------------
    // Firebase Purchase (Google Ads 앱 전환용)
    // --------------------------------------------------
    try {
      await FirebaseAnalytics.instance.logPurchase(
        currency: currencyCode,
        value: price,
        transactionId: transactionId,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productId,
            price: price,
            quantity: 1,
          ),
        ],
      );
      debugPrint(
        '[SubscriptionService] Firebase Purchase sent: '
        '$price $currencyCode / $productId',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Firebase Purchase error: $e');
    }

    // --------------------------------------------------
    // TikTok Purchase
    // --------------------------------------------------
    if (Platform.isAndroid) {
      try {
        await _tiktokChannel.invokeMethod('trackPurchase', {
          'value': price,
          'currency': currencyCode,
          'productId': productId,
        });

        debugPrint(
          '[SubscriptionService] TikTok Purchase sent: '
          '$price $currencyCode / $productId',
        );
      } catch (e) {
        // TikTok 광고 이벤트 실패해도
        // 실제 프리미엄 활성화에는 영향 없음
        debugPrint('[SubscriptionService] TikTok Purchase error: $e');
      }
    }
  }

  /// purchase.transactionDate(epoch millis 문자열)가 [window] 안이면 true.
  /// 날짜가 없으면 오래된 구매일 수 있으므로 false.
  bool _isRecentTransaction(PurchaseDetails purchase, Duration window) {
    final millis = int.tryParse(purchase.transactionDate ?? '');
    if (millis == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    return age >= Duration.zero && age <= window;
  }

  /// Starts a purchase for [productId] — pass [yearlyProductIdToOffer],
  /// [kMonthlyId], or [kLifetimeId].
  ///
  /// [triggerContext] is a short label for what surfaced the paywall (e.g.
  /// 'ad_dismiss', 'badge_moment', 'settings'). It's logged alongside the
  /// checkout-start funnel event so trigger effectiveness can be compared
  /// later — pass null if the call site doesn't track this yet.
  Future<bool> buyProduct(String productId, {String? triggerContext}) async {
    final ProductDetails? details = _productDetailsById[productId];

    if (!_isAvailable || details == null) {
      return false;
    }

    _logFunnelEvent('checkout_started', productId, triggerContext);

    _setLoading(true);

    final PurchaseParam param = PurchaseParam(productDetails: details);

    try {
      final result = await _iap.buyNonConsumable(purchaseParam: param);

      if (!result) {
        _setLoading(false);
        _logFunnelEvent('checkout_failed_to_start', productId, triggerContext);
      }

      return result;
    } catch (e) {
      _setLoading(false);

      debugPrint('[SubscriptionService] buy error: $e');

      _logFunnelEvent('checkout_error', productId, triggerContext);

      return false;
    }
  }

  /// Fire-and-forget funnel logging for the paywall → checkout → purchase
  /// pipeline (mirrors the existing ad_revenue_events pattern). Never
  /// affects the actual purchase flow if it fails.
  Future<void> _logFunnelEvent(
    String event,
    String productId,
    String? triggerContext,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('subscription_funnel_events')
          .add({
            'event': event,
            'productId': productId,
            'triggerContext': triggerContext ?? 'unknown',
            'adExperimentGroup': AdService.instance.experimentGroup,
            'deviceId': AdService.instance.deviceId,
            'userAssignedAt': AdService.instance.assignedAt != null
                ? Timestamp.fromDate(AdService.instance.assignedAt!)
                : null,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('[SubscriptionService] funnel log error: $e');
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    _setLoading(true);

    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[SubscriptionService] restore error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _setPremium(
    bool value, {
    String? productId,
    bool isLifetime = false,
  }) async {
    // [디버깅용] 활성 결제/복원 이벤트(예: 이미 구독 중인 계정에서 스토어가 스트림
    // 초기화 시 재전달하는 구매 정보)가 들어와도 강제로 비구독 취급되도록 덮어씀.
    // 이게 없으면 _debugForceNonPremium=true로 꺼둬도 실제 구독 중인 테스트
    // 계정에서는 purchaseStream이 곧바로 _isPremium을 true로 되돌려버림.
    if (_debugForceNonPremium) {
      value = false;
    }

    _isPremium = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_prefKeyIsPremium, value);

    if (value) {
      _premiumActivationSeq++;
      _hasEverBeenPremium = true;

      await prefs.setBool(_prefKeyHasEverBeenPremium, true);

      if (productId != null) {
        _activeProductId = productId;
        await prefs.setString(_prefKeyActiveProductId, productId);
      }

      _isLifetime = isLifetime;
      await prefs.setBool(_prefKeyIsLifetime, isLifetime);
    }

    notifyListeners();

    if (value) {
      AdServiceSubscriptionBridge.instance.onPremiumActivated();
    } else {
      AdServiceSubscriptionBridge.instance.onPremiumDeactivated();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();

    super.dispose();
  }
}

class AdServiceSubscriptionBridge {
  AdServiceSubscriptionBridge._();

  static final AdServiceSubscriptionBridge instance =
      AdServiceSubscriptionBridge._();

  VoidCallback? _onActivated;
  VoidCallback? _onDeactivated;

  void register({
    required VoidCallback onActivated,
    required VoidCallback onDeactivated,
  }) {
    _onActivated = onActivated;
    _onDeactivated = onDeactivated;
  }

  void onPremiumActivated() => _onActivated?.call();

  void onPremiumDeactivated() => _onDeactivated?.call();
}

enum _EntitlementState { entitled, notEntitled, unknown }

class _EntitlementCheck {
  const _EntitlementCheck(this.state, [this.productId]);

  final _EntitlementState state;
  final String? productId;
}
