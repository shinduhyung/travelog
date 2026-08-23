import 'package:flutter/material.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:collection/collection.dart';

class CountryChecklist {
  final Achievement achievement;
  final String Function(String) getFlagImageUrl;

  CountryChecklist({
    required this.achievement,
    required this.getFlagImageUrl,
  });

  // [추가] targetIsoCodes 기반 고정 세트형 국가 뱃지 체크리스트
  // (예: indochina, gulf, eu_all, soviet_union, un_security 등)
  Widget buildCountryTargetChecklist(
      BuildContext context,
      CountryProvider countryProvider,
      ) {
    if (achievement.targetIsoCodes == null) {
      return const SizedBox.shrink();
    }

    final visitedIsos = countryProvider.visitedCountries
        .map((name) => countryProvider.countryNameToIsoMap[name])
        .where((iso) => iso != null)
        .cast<String>()
        .toSet();

    final targetIsos = achievement.targetIsoCodes!.toList()..sort();

    final targetCountries = targetIsos
        .map((iso) => countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == iso))
        .where((c) => c != null)
        .cast<Country>()
        .toList();

    if (targetCountries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No countries found for this badge.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: targetCountries.length,
      itemBuilder: (context, index) {
        final country = targetCountries[index];
        final isVisited = visitedIsos.contains(country.isoA3);
        final countryIsoA2 = country.isoA2;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountryDetailScreen(country: country),
              ),
            );
          },
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
                  country.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 24) // Blue
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildCountryStatusChecklist(
      BuildContext context,
      CountryProvider countryProvider,
      ) {
    List<Country> targetCountries = [];

    if (achievement.requiresHome) {
      // Country has only ONE home country
      if (countryProvider.homeCountryIsoA3 != null) {
        final homeCountry = countryProvider.allCountries.firstWhere(
              (c) => c.isoA3 == countryProvider.homeCountryIsoA3,
          orElse: () => countryProvider.allCountries.first,
        );
        targetCountries = [homeCountry];
      }
    } else if (achievement.requiresRating) {
      targetCountries = countryProvider.allCountries
          .where((c) {
        final details = countryProvider.visitDetails[c.name];
        return details != null && details.rating != null && details.rating! > 0;
      })
          .toList();
    }

    targetCountries.sort((a, b) => a.name.compareTo(b.name));

    if (targetCountries.isEmpty) {
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
                achievement.requiresHome
                    ? 'No home country set yet'
                    : 'No countries rated yet',
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
      itemCount: targetCountries.length,
      itemBuilder: (context, index) {
        final country = targetCountries[index];
        final countryIsoA2 = country.isoA2;

        final countryVisitDetail = countryProvider.visitDetails[country.name];
        final double rating = countryVisitDetail?.rating ?? 0.0;
        final bool isHome = country.isoA3 == countryProvider.homeCountryIsoA3;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountryDetailScreen(country: country),
              ),
            );
          },
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
                  country.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: achievement.requiresRating && rating > 0 ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ) : null,
                trailing: const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 24), // Blue
              ),
            ),
          ),
        );
      },
    );
  }
}