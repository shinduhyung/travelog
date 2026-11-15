// lib/ads/ad_revenue_logger.dart
//
// Shared writer for the `ad_revenue_events` collection (read by the revenue
// dashboard). Every onPaidEvent in the app goes through here so server-side
// ad revenue covers all formats, not just the main interstitial.
//
// Banners fire onPaidEvent on every refresh, so this is one fire-and-forget
// `add` with no reads; failures are swallowed with a debug log and never touch
// the ad flow.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/screen_tracking.dart';

class AdRevenueLogger {
  AdRevenueLogger._();

  static const String formatInterstitial = 'interstitial';
  static const String formatBanner = 'banner';
  static const String formatGameInterstitial = 'game_interstitial';
  static const String formatRewarded = 'rewarded';

  /// Writes one revenue event. [revenue] is in currency units (micros / 1e6).
  /// [screen] defaults to the currently tracked screen name.
  static Future<void> log({
    required String format,
    required double revenue,
    required String currencyCode,
    required PrecisionType precision,
    String? adSourceName,
    String? screen,
    String? placement,
  }) async {
    try {
      final svc = AdService.instance;
      final String? screenName = screen ?? ScreenTracking.currentScreen.value;
      await FirebaseFirestore.instance.collection('ad_revenue_events').add({
        'adExperimentGroup': svc.experimentGroup,
        'deviceId': svc.deviceId,
        'revenue': revenue,
        'currencyCode': currencyCode,
        'precision': precision.toString(),
        'adSourceName': adSourceName ?? 'unknown',
        'format': format,
        if (screenName != null) 'screen': screenName,
        if (placement != null) 'placement': placement,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdRevenueLogger] $format revenue log error: $e');
    }
  }

  /// Convenience for an onPaidEvent callback: reads the mediation adapter
  /// from the ad's response info.
  static void fromPaidEvent(
    Ad ad,
    double valueMicros,
    PrecisionType precision,
    String currencyCode, {
    required String format,
    String? placement,
  }) {
    log(
      format: format,
      revenue: valueMicros / 1000000.0,
      currencyCode: currencyCode,
      precision: precision,
      adSourceName: ad.responseInfo?.mediationAdapterClassName,
      placement: placement,
    );
  }
}
