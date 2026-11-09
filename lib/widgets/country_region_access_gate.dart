import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

const _brand = Color(0xFF1ABFBC);

const _premiumRegionsMessage =
    'Sub-regions in the original 30 countries are free. Subscribe to Premium to explore and track sub-regions in additional countries.';

/// Same look as the other subscription pitches (StatLockedPromo): tinted card,
/// lock badge, one clear call to action.
class _RegionsPitch extends StatelessWidget {
  final String title;
  final VoidCallback onUpgrade;
  final VoidCallback? onDismiss;

  const _RegionsPitch({
    required this.title,
    required this.onUpgrade,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brand.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.public_rounded, color: _brand, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            tr(_premiumRegionsMessage),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onUpgrade,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(
                tr('Go Premium'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onDismiss,
              child: Text(
                tr('Not now'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showCountryRegionsPremiumDialog(BuildContext context) async {
  final upgrade = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _RegionsPitch(
            title: tr('Unlock sub-regions'),
            onUpgrade: () => Navigator.pop(sheetContext, true),
            onDismiss: () => Navigator.pop(sheetContext, false),
          ),
        ),
      ),
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
        child: _RegionsPitch(
          title: tr('Sub-regions'),
          onUpgrade: () => SubscriptionSheet.show(
            context,
            triggerContext: 'country_regions',
          ),
        ),
      );
    },
  );
}
