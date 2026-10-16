import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// Test-only platform adapter for the application's existing IAP dependency.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

class _UnavailableTestStore extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<bool> isAvailable() async => false;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Instantiate the facade without registering Android's native BillingClient.
  // All tests use a fake unavailable store; no native billing or purchase calls.
  final originalPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    InAppPurchasePlatform.instance = _UnavailableTestStore();
    InAppPurchase.instance;
  } finally {
    debugDefaultTargetPlatformOverride = originalPlatform;
  }
  await testMain();
}
