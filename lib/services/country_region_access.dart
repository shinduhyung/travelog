import 'package:jidoapp/services/subscription_service.dart';

/// The original countries remain free. Keep this list stable across releases.
class CountryRegionAccess {
  CountryRegionAccess._();

  static const freeCountryCodes = <String>{
    'AE',
    'AR',
    'AT',
    'AU',
    'BR',
    'CA',
    'CH',
    'CN',
    'DE',
    'EG',
    'ES',
    'FR',
    'GB',
    'GR',
    'ID',
    'IN',
    'IT',
    'JP',
    'KR',
    'MX',
    'MY',
    'NL',
    'PH',
    'PT',
    'RU',
    'TH',
    'TR',
    'US',
    'VN',
    'ZA',
  };

  static bool canAccess(String countryIsoA2, {required bool isPremium}) =>
      isPremium || freeCountryCodes.contains(countryIsoA2.toUpperCase());

  static bool isUnlocked(String countryIsoA2) => canAccess(
    countryIsoA2,
    isPremium: SubscriptionService.instance.isPremium,
  );
}
