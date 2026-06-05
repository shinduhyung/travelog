import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  static const String kProductId = 'travelog_premium_yearly';
  static const String _prefKeyIsPremium = 'is_premium';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isPremium = false;
  bool _isLoading = false;
  bool _isAvailable = false;

  ProductDetails? _productDetails;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  bool get isAvailable => _isAvailable;
  ProductDetails? get productDetails => _productDetails;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefKeyIsPremium) ?? false;
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

    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setLoading(true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
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
    if (Platform.isAndroid) {
      final androidDetails = purchase as GooglePlayPurchaseDetails?;
      if (androidDetails != null) {
        final orderId = androidDetails.billingClientPurchase.orderId;
        debugPrint('[SubscriptionService] Android orderId: $orderId');

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
            'status': purchase.status.name,
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