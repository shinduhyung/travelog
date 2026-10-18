import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

const _premiumRegionsMessage =
    'Regions in the original 30 countries are free. Subscribe to Premium to explore and track regions in additional countries.';

Future<void> showCountryRegionsPremiumDialog(BuildContext context) async {
  final upgrade = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title:  Text(tr('Unlock more regions')),
      content:  Text(tr(_premiumRegionsMessage)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:  Text(tr('Not now')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child:  Text(tr('Get Premium')),
        ),
      ],
    ),
  );
  if (upgrade == true && context.mounted) {
    await SubscriptionSheet.show(context, triggerContext: 'country_regions');
  }
}

/// Rechecks entitlement while mounted, including after purchase or expiry.
/// Locked content is built lazily so region maps and controls never leak.
class CountryRegionAccessGate extends StatelessWidget {
  final String countryIsoA2;
  final WidgetBuilder builder;

  const CountryRegionAccessGate({
    super.key,
    required this.countryIsoA2,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: SubscriptionService.instance,
    builder: (context, _) {
      if (CountryRegionAccess.isUnlocked(countryIsoA2)) return builder(context);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF26A69A)),
            const SizedBox(height: 8),
             Text(
              tr('Premium regions'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
             Text(tr(_premiumRegionsMessage), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => showCountryRegionsPremiumDialog(context),
              child:  Text(tr('Get Premium')),
            ),
          ],
        ),
      );
    },
  );
}
