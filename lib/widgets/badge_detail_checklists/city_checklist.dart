import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';

class CityChecklist {
  final Achievement achievement;
  final String Function(String) getFlagImageUrl;
  final Function(BuildContext, String, String) showCityDetailSheet;

  CityChecklist({
    required this.achievement,
    required this.getFlagImageUrl,
    required this.showCityDetailSheet,
  });

  Widget buildCityChecklist(BuildContext context, CityProvider cityProvider) {
    if (achievement.targetIsoCodes == null) {
      return const SizedBox.shrink();
    }

    final visitedCities = cityProvider.visitedCities.toSet();
    final targetCities = achievement.targetIsoCodes!.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: targetCities.length,
      itemBuilder: (context, index) {
        final cityName = targetCities[index];
        final bool isVisited = visitedCities.contains(cityName);

        final city = cityProvider.allCities.firstWhere(
              (c) => c.name == cityName,
          orElse: () => cityProvider.allCities.first,
        );
        final countryIsoA2 = city.countryIsoA2;

        final cityVisitDetail = cityProvider.visitDetails[cityName];
        final double rating = cityVisitDetail?.rating ?? 0.0;
        final bool isHome = cityVisitDetail?.isHome ?? false;

        return GestureDetector(
          onTap: () => showCityDetailSheet(context, cityName, countryIsoA2),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: SizedBox(
                  width: 40,
                  height: 28,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      getFlagImageUrl(countryIsoA2),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
                        );
                      },
                    ),
                  ),
                ),
                title: Text(
                  cityName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 24) // Yellow/Orange
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCityStatusChecklist(BuildContext context, CityProvider cityProvider) {
    List<String> targetCityNames = [];

    if (achievement.requiresHome) {
      targetCityNames = cityProvider.visitDetails.entries
          .where((entry) => entry.value.isHome)
          .map((entry) => entry.key)
          .toList();
    } else if (achievement.requiresRating) {
      targetCityNames = cityProvider.visitDetails.entries
          .where((entry) => entry.value.rating > 0)
          .map((entry) => entry.key)
          .toList();
    }

    targetCityNames.sort();

    if (targetCityNames.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                achievement.requiresHome ? Icons.home_outlined : Icons.star_outline,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                tr(achievement.requiresHome
                    ? 'No home cities set yet'
                    : 'No cities rated yet'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: targetCityNames.length,
      itemBuilder: (context, index) {
        final cityName = targetCityNames[index];

        final city = cityProvider.allCities.firstWhere(
              (c) => c.name == cityName,
          orElse: () => cityProvider.allCities.first,
        );
        final countryIsoA2 = city.countryIsoA2;

        final cityVisitDetail = cityProvider.visitDetails[cityName];
        final double rating = cityVisitDetail?.rating ?? 0.0;
        final bool isHome = cityVisitDetail?.isHome ?? false;

        return GestureDetector(
          onTap: () => showCityDetailSheet(context, cityName, countryIsoA2),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: SizedBox(
                  width: 40,
                  height: 28,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      getFlagImageUrl(countryIsoA2),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
                        );
                      },
                    ),
                  ),
                ),
                title: Text(
                  cityName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rating > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              tr(rating.toStringAsFixed(1)),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isHome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.home, color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              tr('Home'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 24), // Yellow/Orange
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCityStatRow(String label, String value, IconData icon, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: themeColor),
          const SizedBox(width: 12),
          Text(tr(label), style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const Spacer(),
          Text(tr(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  Widget buildGeneralCityChecklist(BuildContext context, CityProvider cityProvider) {
    final visitedCities = cityProvider.visitedCities.toList()
      ..sort();

    if (visitedCities.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.location_city, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                tr('No cities visited yet'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('Start exploring cities!'),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: visitedCities.length,
      itemBuilder: (context, index) {
        final cityName = visitedCities[index];

        final city = cityProvider.allCities.firstWhere(
              (c) => c.name == cityName,
          orElse: () => cityProvider.allCities.first,
        );
        final countryIsoA2 = city.countryIsoA2;

        final cityVisitDetail = cityProvider.visitDetails[cityName];
        final double rating = cityVisitDetail?.rating ?? 0.0;
        final bool isHome = cityVisitDetail?.isHome ?? false;

        return GestureDetector(
          onTap: () => showCityDetailSheet(context, cityName, countryIsoA2),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: SizedBox(
                  width: 40,
                  height: 28,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      getFlagImageUrl(countryIsoA2),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
                        );
                      },
                    ),
                  ),
                ),
                title: Text(
                  cityName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 24), // Yellow/Orange
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCapitalCitiesChecklist(BuildContext context, CityProvider cityProvider, Set<String> visitedIsos) {
    final visitedCities = cityProvider.visitedCities.toSet();

    final visitedCapitals = cityProvider.allCities
        .where((city) =>
    visitedCities.contains(city.name) &&
        (city.capitalStatus == CapitalStatus.capital ||
            city.capitalStatus == CapitalStatus.territory))
        .toList();

    visitedCapitals.sort((a, b) => a.name.compareTo(b.name));

    if (visitedCapitals.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                tr('No capital cities visited yet'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('Start your journey!'),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: visitedCapitals.length,
      itemBuilder: (context, index) {
        final city = visitedCapitals[index];

        final cityVisitDetail = cityProvider.visitDetails[city.name];
        final double rating = cityVisitDetail?.rating ?? 0.0;
        final bool isHome = cityVisitDetail?.isHome ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: SizedBox(
                width: 40,
                height: 28,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    getFlagImageUrl(city.countryIsoA2),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
                      );
                    },
                  ),
                ),
              ),
              title: Text(
                city.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(city.country),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 24), // Yellow/Orange
            ),
          ),
        );
      },
    );
  }

  Widget buildLatitudeChecklist(BuildContext context, CityProvider cityProvider) {
    final visitedCities = cityProvider.visitedCities.toSet();
    List<City> filteredCities = [];

    if (achievement.id == 'both_hemispheres') {
      final northern = cityProvider.allCities
          .where((city) => visitedCities.contains(city.name) && city.latitude > 0)
          .toList();
      final southern = cityProvider.allCities
          .where((city) => visitedCities.contains(city.name) && city.latitude < 0)
          .toList();

      if (northern.isNotEmpty) filteredCities.add(northern.first);
      if (southern.isNotEmpty) filteredCities.add(southern.first);
    } else if (achievement.id == 'north_60_latitude') {
      filteredCities = cityProvider.allCities
          .where((city) => visitedCities.contains(city.name) && city.latitude >= 60)
          .toList();
    } else if (achievement.id == 'south_40_latitude') {
      filteredCities = cityProvider.allCities
          .where((city) => visitedCities.contains(city.name) && city.latitude <= -40)
          .toList();
    }

    filteredCities.sort((a, b) => a.name.compareTo(b.name));

    if (filteredCities.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                tr('No matching cities visited yet'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('Start your journey!'),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: filteredCities.length,
      itemBuilder: (context, index) {
        final city = filteredCities[index];
        String subtitle = '${city.latitude.toStringAsFixed(2)}°';
        if (achievement.id == 'both_hemispheres') {
          subtitle += city.latitude > 0 ? ' N' : ' S';
        }

        final cityVisitDetail = cityProvider.visitDetails[city.name];
        final double rating = cityVisitDetail?.rating ?? 0.0;
        final bool isHome = cityVisitDetail?.isHome ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: SizedBox(
                width: 40,
                height: 28,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    getFlagImageUrl(city.countryIsoA2),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
                      );
                    },
                  ),
                ),
              ),
              title: Text(
                city.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(subtitle),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 24), // Yellow/Orange
            ),
          ),
        );
      },
    );
  }

}