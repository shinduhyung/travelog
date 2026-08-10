import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facebook_app_events/facebook_app_events.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  static const String kProductId = 'travelog_premium_yearly';
  static const String _prefKeyIsPremium = 'is_premium';
  static const String _prefKeyHasEverBeenPremium = 'has_ever_been_premium';

  static const bool _debugForceNonPremium = false;

  final InAppPurchase _iap = InAppPurchase.instance;
  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isPremium = false;
  bool _hasEverBeenPremium = false;
  bool _isLoading = false;
  bool _isAvailable = false;

  ProductDetails? _productDetails;

  bool get isPremium => _isPremium;
  bool get hasEverBeenPremium => _hasEverBeenPremium;
  bool get isLoading => _isLoading;
  bool get isAvailable => _isAvailable;
  ProductDetails? get productDetails => _productDetails;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = _debugForceNonPremium ? false : (prefs.getBool(_prefKeyIsPremium) ?? false);
    _hasEverBeenPremium = _debugForceNonPremium ? false : (prefs.getBool(_prefKeyHasEverBeenPremium) ?? false);
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

    final response = await _iap.queryProductDetails({kProductId});
    if (response.productDetails.isNotEmpty) {
      _productDetails = response.productDetails.first;
      notifyListeners();
    } else {
      debugPrint('[SubscriptionService] product not found: ${response.notFoundIDs}');
    }

    if (!_debugForceNonPremium) await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setLoading(true);
          break;
        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.restored:
        // 복원(restored)은 Firestore에 기록하지 않고 프리미엄 상태만 활성화
          _setPremium(true);
          _setLoading(false);
          break;
        case PurchaseStatus.error:
          _setLoading(false);
          debugPrint('[SubscriptionService] purchase error: ${purchase.error?.message}');
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

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    // ProductDetails에서 가격 및 통화 정보 추출
    double price = _productDetails?.rawPrice ?? 0.0;
    String currencyCode = _productDetails?.currencyCode ?? 'USD';

    // 페이스북으로 구매(Purchase) 이벤트와 실제 가격 전송
    _facebookAppEvents.logPurchase(
      amount: price,
      currency: currencyCode,
    );

    if (Platform.isAndroid) {
      final androidDetails = purchase as GooglePlayPurchaseDetails?;
      if (androidDetails != null) {
        final orderId = androidDetails.billingClientPurchase.orderId;
        debugPrint('[SubscriptionService] Android orderId: $orderId');

        int priceAmountMicros = (price * 1000000).round();

        // Firestore에 주문 저장 → 대시보드에서 수익 집계용
        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .set({
            'orderId': orderId,
            'productId': purchase.productID,
            'purchaseTime': FieldValue.serverTimestamp(),
            'platform': 'android',
            'status': 'purchased',
            'priceAmountMicros': priceAmountMicros,
            'priceCurrencyCode': currencyCode,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[SubscriptionService] Firestore save error: $e');
        }
      }
    }

    await _setPremium(true);
    _setLoading(false);
    debugPrint('[SubscriptionService] premium activated');
  }

  Future<bool> buySubscription() async {
    if (!_isAvailable || _productDetails == null) return false;

    _setLoading(true);

    final PurchaseParam param = PurchaseParam(productDetails: _productDetails!);

    try {
      final result = await _iap.buyNonConsumable(purchaseParam: param);
      if (!result) _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      debugPrint('[SubscriptionService] buy error: $e');
      return false;
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

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsPremium, value);

    // 프리미엄이 한 번이라도 활성화되면 이력을 남김
    if (value) {
      _hasEverBeenPremium = true;
      await prefs.setBool(_prefKeyHasEverBeenPremium, true);
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