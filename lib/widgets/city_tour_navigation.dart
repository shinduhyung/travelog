import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/discover_recommendation_runtime.dart';
import 'package:jidoapp/services/discover_recommender.dart';
import 'package:jidoapp/widgets/city_report_screen.dart';

final _tourTargets = <String, Future<DiscoverPlace?>>{};

Future<DiscoverPlace?> resolveCityTour(String city,
    {String? countryCode, double? latitude, double? longitude}) {
  final country = countryCode == null || countryCode.isEmpty ? null : countryCode.toUpperCase();
  final key = '$city|$country|$latitude|$longitude';
  return _tourTargets.putIfAbsent(key, () async {
    try {
      final model = await DiscoverRecommendationRuntime.load();
      final place = model.resolve('city', city, country: country,
          latitude: latitude, longitude: longitude);
      if (place == null || !place.candidate || !await CityReports.has(place.name)) return null;
      return place;
    } catch (_) {
      _tourTargets.remove(key);
      return null;
    }
  });
}

/// Direct navigation for recommendations; shared by every city Tour button.
Future<void> openCityTour(BuildContext context, String city,
    {String? countryCode, double? latitude, double? longitude}) async {
  final place = await resolveCityTour(city, countryCode: countryCode,
      latitude: latitude, longitude: longitude);
  if (!context.mounted) return;
  if (place != null) {
    openCityReport(context, place.name);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Could not load this guide.'))));
  }
}

/// Prominent, top-of-sheet CTA; takes zero space when the exact city has no Tour.
class CityTourButton extends StatelessWidget {
  final String city;
  final String? countryCode;
  final double? latitude, longitude;
  const CityTourButton({super.key, required this.city, this.countryCode,
    this.latitude, this.longitude});

  @override
  Widget build(BuildContext context) => FutureBuilder<DiscoverPlace?>(
    future: resolveCityTour(city, countryCode: countryCode,
        latitude: latitude, longitude: longitude),
    builder: (context, snapshot) {
      final target = snapshot.data;
      if (target == null) return const SizedBox.shrink();
      return CityViewSwitch(tourSelected: false,
          onTour: () => openCityReport(context, target.name, fromInfo: true));
    },
  );
}

/// Info | Tour segmented switch shared by the city Info sheet and the Tour page.
class CityViewSwitch extends StatelessWidget {
  final bool tourSelected;
  final VoidCallback? onInfo, onTour;
  const CityViewSwitch({super.key, required this.tourSelected, this.onInfo, this.onTour});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(child: _seg(Icons.info_outline_rounded, tr('Info'), !tourSelected,
            tourSelected ? onInfo : null)),
        Expanded(child: _seg(Icons.travel_explore_rounded, tr('Tour'), tourSelected,
            tourSelected ? null : onTour)),
      ]),
    ),
  );

  Widget _seg(IconData icon, String label, bool selected, VoidCallback? onTap) {
    final fg = selected ? Colors.black87 : Colors.grey.shade600;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg))),
        ]),
      ),
    );
  }
}
