import 'dart:async';
import 'dart:io';
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
      true; // [디버깅용] true로 두면 실제 구독 상태와 무관하게 항상 비구독으로 취급됨. 프리미엄 뱃지 잠금 UI 테스트 끝나면 반드시 false로 되돌릴 것.

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
    }
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
    final ProductDetails? details = _productDetailsById[productId];
    final double price = details?.rawPrice ?? 0.0;
    final String currencyCode = details?.currencyCode ?? 'USD';

    if (!isRestore) {
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

      if (orderId != null && orderId.isNotEmpty) {
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
