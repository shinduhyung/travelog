import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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

  static const bool _debugForceNonPremium = false; // [디버깅용] true로 두면 실제 구독 상태와 무관하게 항상 비구독으로 취급됨. 프리미엄 뱃지 잠금 UI 테스트 끝나면 반드시 false로 되돌릴 것.

  // TikTok Android Native SDK와 연결하는 통로
  static const MethodChannel _tiktokChannel =
  MethodChannel('com.ahnlee.jidoapp/tiktok_events');

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
        debugPrint(
          '[SubscriptionService] purchaseStream error: $e',
        );
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

  void _onPurchaseUpdate(
      List<PurchaseDetails> purchases,
      ) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setLoading(true);
          break;

        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchase, isRestore: false);
          break;

        case PurchaseStatus.restored:
        // 복원은 신규 구매가 아니므로
        // Meta/TikTok Purchase 이벤트를 전송하지 않음
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
        _iap.completePurchase(purchase);
      }
    }
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
        debugPrint(
          '[SubscriptionService] Meta Purchase error: $e',
        );
      }

      // --------------------------------------------------
      // TikTok Purchase
      // --------------------------------------------------
      if (Platform.isAndroid) {
        try {
          await _tiktokChannel.invokeMethod(
            'trackPurchase',
            {
              'value': price,
              'currency': currencyCode,
              'productId': productId,
            },
          );

          debugPrint(
            '[SubscriptionService] TikTok Purchase sent: '
                '$price $currencyCode / $productId',
          );
        } catch (e) {
          // TikTok 광고 이벤트 실패해도
          // 실제 프리미엄 활성화에는 영향 없음
          debugPrint(
            '[SubscriptionService] TikTok Purchase error: $e',
          );
        }
      }

      // --------------------------------------------------
      // Android 주문 정보 Firestore 저장
      // --------------------------------------------------
      if (Platform.isAndroid) {
        final androidDetails = purchase as GooglePlayPurchaseDetails?;

        if (androidDetails != null) {
          final orderId = androidDetails.billingClientPurchase.orderId;

          debugPrint(
            '[SubscriptionService] Android orderId: $orderId',
          );

          final int priceAmountMicros = (price * 1000000).round();

          try {
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .set(
              {
                'orderId': orderId,
                'productId': productId,
                'isLifetime': isLifetimePurchase,
                'purchaseTime': FieldValue.serverTimestamp(),
                'platform': 'android',
                'status': 'purchased',
                'priceAmountMicros': priceAmountMicros,
                'priceCurrencyCode': currencyCode,
                'adExperimentGroup': AdService.instance.experimentGroup,
                'deviceId': AdService.instance.deviceId,
                'userAssignedAt': AdService.instance.assignedAt != null
                    ? Timestamp.fromDate(AdService.instance.assignedAt!)
                    : null,
              },
              SetOptions(merge: true),
            );
          } catch (e) {
            debugPrint(
              '[SubscriptionService] Firestore save error: $e',
            );
          }
        }
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

    final PurchaseParam param = PurchaseParam(
      productDetails: details,
    );

    try {
      final result = await _iap.buyNonConsumable(
        purchaseParam: param,
      );

      if (!result) {
        _setLoading(false);
        _logFunnelEvent('checkout_failed_to_start', productId, triggerContext);
      }

      return result;
    } catch (e) {
      _setLoading(false);

      debugPrint(
        '[SubscriptionService] buy error: $e',
      );

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
      debugPrint(
        '[SubscriptionService] restore error: $e',
      );
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

    await prefs.setBool(
      _prefKeyIsPremium,
      value,
    );

    if (value) {
      _hasEverBeenPremium = true;

      await prefs.setBool(
        _prefKeyHasEverBeenPremium,
        true,
      );

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

  void _setLoading(
      bool value,
      ) {
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