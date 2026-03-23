// lib/screens/badge_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/city_model.dart';

import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/economy_data_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/economy_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart'; // 공통 위젯 임포트
import 'package:jidoapp/widgets/unesco_visit_editor_card.dart'; // 공통 위젯 임포트
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jidoapp/models/visit_details_model.dart';

import 'package:jidoapp/widgets/badge_detail_checklists/country_checklist.dart';
import 'package:jidoapp/widgets/badge_detail_checklists/city_checklist.dart';
import 'package:jidoapp/widgets/badge_detail_checklists/landmark_checklist.dart';
import 'package:jidoapp/widgets/badge_detail_checklists/flight_checklist.dart';
import 'package:jidoapp/widgets/badge_detail_checklists/continent_checklist.dart';

class BadgeDetailScreen extends StatelessWidget {
  final Achievement achievement;

  const BadgeDetailScreen({
    super.key,
    required this.achievement,
  });

  String _formatPopulation(int? value) {
    if (value == null || value == 0) return '0.00B';
    const int billion = 1000000000;
    return '${(value / billion).toStringAsFixed(2)}B';
  }

  String _formatArea(int? value) {
    if (value == null || value == 0) return '0.00M km²';
    const int million = 1000000;
    return '${(value / million).toStringAsFixed(2)}M km²';
  }

  String _formatGdp(int? value) {
    if (value == null || value == 0) return '0.00T USD';
    double val = value.toDouble();
    const double trillion = 1000000000000.0;
    return '${(val / trillion).toStringAsFixed(2)}T USD';
  }

  String _getFlagImageUrl(String isoA2) {
    return 'https://flagcdn.com/w160/${isoA2.toLowerCase()}.png';
  }

  String _getSectionTitle() {
    if (achievement.targetIsoCodes != null) return 'Checklist';

    if (achievement.category == AchievementCategory.Landmarks) {
      if (achievement.requiresRating) return 'Rated Landmarks';
      if (achievement.requiresCulturalLandmark || achievement.requiresNaturalLandmark) return 'Visited Landmarks';
      return 'Visited Landmarks';
    }

    if (achievement.category == AchievementCategory.City) {
      if (achievement.requiresHome) return 'Home Cities';
      if (achievement.requiresRating) return 'Rated Cities';
      return 'Visited Cities';
    }

    if (achievement.category == AchievementCategory.Country) {
      if (achievement.requiresHome) return 'Home Country';
      if (achievement.requiresRating) return 'Rated Countries';
      if (achievement.id.startsWith('continents_')) return 'Continents Progress';
      return 'Checklist';
    }

    if (achievement.category == AchievementCategory.Flight) {
      if (achievement.requiresAirportHub) return 'Hub Airports';
      if (achievement.requiresAirportRating) return 'Rated Airports';
      if (achievement.requiresAirlineRating) return 'Rated Airlines';
      if (achievement.requiresBusinessClass) return 'Business Class Flights';
      if (achievement.requiresFirstClass) return 'First Class Experience';

      if (achievement.id.startsWith('flights_')) return 'Flight History';
      if (achievement.id.startsWith('airlines_')) return 'Checklist';
      if (achievement.id.startsWith('airports_')) return 'Visited Airports';

      if (achievement.id == 'skyteam_20' ||
          achievement.id == 'oneworld_20' ||
          achievement.id == 'staralliance_20') {
        return 'Alliance Members';
      }
    }

    return 'Visited Countries';
  }

  DateTime? _getEarliestVisitDate(CountryProvider countryProvider, String countryName) {
    final details = countryProvider.getVisitDetails(countryName);
    if (details == null || details.visitDateRanges.isEmpty) return null;

    DateTime? earliestDate;
    for (var range in details.visitDateRanges) {
      if (range.arrival != null) {
        if (earliestDate == null || range.arrival!.isBefore(earliestDate)) {
          earliestDate = range.arrival;
        }
      }
    }
    return earliestDate;
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.Country:
        return const Color(0xFF3B82F6);
      case AchievementCategory.City:
        return const Color(0xFFFBBF24);
      case AchievementCategory.Landmarks:
        return const Color(0xFF66BB6A);
      case AchievementCategory.Flight:
        return const Color(0xFFAB47BC);
      default:
        return Colors.grey;
    }
  }

  Widget _buildFixedTitle(String text) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryProvider = context.watch<CountryProvider>();
    final cityProvider = context.watch<CityProvider>();
    final economyProvider = context.watch<EconomyProvider>();
    final airlineProvider = context.watch<AirlineProvider>();
    final airportProvider = context.watch<AirportProvider>();
    final landmarksProvider = context.watch<LandmarksProvider>();
    final unescoProvider = context.watch<UnescoProvider>();
    final badgeProvider = context.watch<BadgeProvider>();

    final visitedIsos = countryProvider.visitedCountries
        .map((name) => countryProvider.countryNameToIsoMap[name])
        .where((iso) => iso != null)
        .cast<String>()
        .toSet();

    final progressData = badgeProvider.getAchievementProgress(
      achievement,
      visitedIsos,
      countryProvider.allCountries,
      economyProvider.economyData,
      visitedCities: cityProvider.visitedCities.toSet(),
      allCities: cityProvider.allCities,
      totalFlights: airlineProvider.allFlightLogs.fold<int>(0, (sum, log) => sum + log.times),
      visitedAirlines: airlineProvider.airlines.where((a) => a.totalTimes > 0).map((a) => a.code).toSet(),
      visitedAirlineNames: airlineProvider.airlines.where((a) => a.totalTimes > 0).map((a) => a.name).toSet(),
      visitedAirlineCode3s: airlineProvider.airlines.where((a) => a.totalTimes > 0 && a.code3 != null).map((a) => a.code3!).toSet(),
      visitedAirports: airportProvider.visitedAirports,
      visitedLandmarks: landmarksProvider.visitedLandmarks,
      allLandmarks: landmarksProvider.allLandmarks,
      unescoProvider: unescoProvider,
    );

    final int current = progressData['current'] ?? 0;
    final int total = progressData['total'] ?? 1;
    final double progress = total > 0 ? current / total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, progress, current, total, progressData),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _getSectionTitle(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildChecklist(
                context,
                countryProvider,
                cityProvider,
                visitedIsos,
                economyProvider.economyData,
                airlineProvider,
                airportProvider,
                landmarksProvider,
                unescoProvider,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      double progress,
      int current,
      int total,
      Map<String, int> progressData,
      ) {
    final bool isPopulationAchievement = achievement.targetPopulationLimit != null;
    final bool isAreaAchievement = achievement.targetAreaLimit != null;
    final bool isGdpAchievement = achievement.targetGdpLimit != null;

    String progressDetailText;
    if (isPopulationAchievement) {
      progressDetailText = '${_formatPopulation(current)} / ${_formatPopulation(total)}';
    } else if (isAreaAchievement) {
      progressDetailText = '${_formatArea(current)} / ${_formatArea(total)}';
    } else if (isGdpAchievement) {
      progressDetailText = '${_formatGdp(current)} / ${_formatGdp(total)}';
    } else {
      progressDetailText = '$current / $total';
    }

    final categoryColor = _getCategoryColor(achievement.category);
    final isUnlocked = achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      isUnlocked ? Colors.transparent : Colors.grey,
                      isUnlocked ? BlendMode.dst : BlendMode.saturation,
                    ),
                    child: Image.asset(
                      achievement.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${achievement.points} points',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            achievement.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    progressDetailText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  color: categoryColor,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% Complete',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist(
      BuildContext context,
      CountryProvider countryProvider,
      CityProvider cityProvider,
      Set<String> visitedIsos,
      List<EconomyData> allEconomyData,
      AirlineProvider airlineProvider,
      AirportProvider airportProvider,
      LandmarksProvider landmarksProvider,
      UnescoProvider unescoProvider,
      ) {
    if (achievement.id.startsWith('continents_')) {
      return ContinentChecklist(
        achievement: achievement,
        countryProvider: countryProvider,
      );
    }

    if (achievement.category == AchievementCategory.Landmarks) {
      final isUnescoBadge = achievement.id.contains('unesco') ||
          achievement.id.contains('heritage');

      if (isUnescoBadge) {
        if (unescoProvider.isLoading) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ));
        }

        final visitedSitesToShow = unescoProvider.allSites.where((site) {
          final isVisited = unescoProvider.visitedSites.contains(site.name);
          if (!isVisited) return false;

          if (achievement.id == 'cultural_heritage') {
            return site.type == 'Cultural';
          } else if (achievement.id == 'natural_heritage') {
            return site.type == 'Natural' || site.type == 'Mixed';
          }
          return true;
        }).toList();

        if (visitedSitesToShow.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No visited sites listed yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: visitedSitesToShow.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final site = visitedSitesToShow[index];

            final bool isMultinational = site.countriesIsoA3.length > 1;
            final String? firstIsoA3 = site.countriesIsoA3.firstOrNull;
            final country = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == firstIsoA3);
            final String isoA2 = country?.isoA2 ?? '';

            return Container(
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
                  onTap: () {
                    _showUnescoDetailsInBadge(context, site, unescoProvider);
                  },
                  leading: SizedBox(
                    width: 40,
                    height: 28,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: isoA2.isNotEmpty
                          ? Image.network(
                        _getFlagImageUrl(isoA2),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[200], child: const Icon(Icons.flag, size: 20)),
                      )
                          : Container(color: Colors.grey[200]),
                    ),
                  ),
                  title: Text(
                    site.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            site.city,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMultinational)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Multinational',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 24),
                ),
              ),
            );
          },
        );
      } else {
        if (achievement.targetIsoCodes != null) {
          final landmarkChecklist = LandmarkChecklist(
            achievement: achievement,
            showLandmarkDetailsModal: _showLandmarkDetailsModal,
            buildFixedTitle: _buildFixedTitle,
          );
          return landmarkChecklist.buildLandmarkChecklist(context, landmarksProvider, countryProvider);
        }
        if (achievement.requiresRating) {
          final landmarkChecklist = LandmarkChecklist(
            achievement: achievement,
            showLandmarkDetailsModal: _showLandmarkDetailsModal,
            buildFixedTitle: _buildFixedTitle,
          );
          return landmarkChecklist.buildRatedLandmarkChecklist(context, landmarksProvider, countryProvider);
        }
        if (achievement.requiresCulturalLandmark) {
          final landmarkChecklist = LandmarkChecklist(
            achievement: achievement,
            showLandmarkDetailsModal: _showLandmarkDetailsModal,
            buildFixedTitle: _buildFixedTitle,
          );
          return landmarkChecklist.buildAttributeLandmarkChecklist(context, landmarksProvider, countryProvider, true);
        }
        if (achievement.requiresNaturalLandmark) {
          final landmarkChecklist = LandmarkChecklist(
            achievement: achievement,
            showLandmarkDetailsModal: _showLandmarkDetailsModal,
            buildFixedTitle: _buildFixedTitle,
          );
          return landmarkChecklist.buildAttributeLandmarkChecklist(context, landmarksProvider, countryProvider, false);
        }
        if (achievement.targetCount != null) {
          final landmarkChecklist = LandmarkChecklist(
            achievement: achievement,
            showLandmarkDetailsModal: _showLandmarkDetailsModal,
            buildFixedTitle: _buildFixedTitle,
          );
          return landmarkChecklist.buildCategoryLandmarkChecklist(context, landmarksProvider, countryProvider);
        }
      }
    }

    if (achievement.category == AchievementCategory.City && achievement.targetIsoCodes != null) {
      final cityChecklist = CityChecklist(
        achievement: achievement,
        getFlagImageUrl: _getFlagImageUrl,
        showCityDetailSheet: _showCityDetailSheet,
      );
      return cityChecklist.buildCityChecklist(context, cityProvider);
    }

    if (achievement.category == AchievementCategory.City && (achievement.requiresRating || achievement.requiresHome)) {
      final cityChecklist = CityChecklist(
        achievement: achievement,
        getFlagImageUrl: _getFlagImageUrl,
        showCityDetailSheet: _showCityDetailSheet,
      );
      return cityChecklist.buildCityStatusChecklist(context, cityProvider);
    }
    if (achievement.category == AchievementCategory.Country && (achievement.requiresRating || achievement.requiresHome)) {
      final countryChecklist = CountryChecklist(
        achievement: achievement,
        getFlagImageUrl: _getFlagImageUrl,
      );
      return countryChecklist.buildCountryStatusChecklist(context, countryProvider);
    }

    if (achievement.category == AchievementCategory.City && achievement.targetCount != null) {
      if (achievement.id == 'cities_10' ||
          achievement.id == 'cities_50' ||
          achievement.id == 'cities_100' ||
          achievement.id == 'cities_300' ||
          achievement.id == 'cities_500') {
        final cityChecklist = CityChecklist(
          achievement: achievement,
          getFlagImageUrl: _getFlagImageUrl,
          showCityDetailSheet: _showCityDetailSheet,
        );
        return cityChecklist.buildGeneralCityChecklist(context, cityProvider);
      }
      if (achievement.id == 'both_hemispheres' ||
          achievement.id == 'north_60_latitude' ||
          achievement.id == 'south_40_latitude') {
        final cityChecklist = CityChecklist(
          achievement: achievement,
          getFlagImageUrl: _getFlagImageUrl,
          showCityDetailSheet: _showCityDetailSheet,
        );
        return cityChecklist.buildLatitudeChecklist(context, cityProvider);
      }
      final cityChecklist = CityChecklist(
        achievement: achievement,
        getFlagImageUrl: _getFlagImageUrl,
        showCityDetailSheet: _showCityDetailSheet,
      );
      return cityChecklist.buildCapitalCitiesChecklist(context, cityProvider, visitedIsos);
    }

    if (achievement.category == AchievementCategory.Flight) {
      if (achievement.requiresAirportRating || achievement.requiresAirportHub) {
        final flightChecklist = FlightChecklist(
          achievement: achievement,
        );
        return flightChecklist.buildAirportStatusChecklist(context, airportProvider);
      }
      if (achievement.requiresAirlineRating) {
        final flightChecklist = FlightChecklist(
          achievement: achievement,
        );
        return flightChecklist.buildRatedAirlineChecklist(context, airlineProvider);
      }
      final flightChecklist = FlightChecklist(
        achievement: achievement,
      );
      return flightChecklist.buildFlightChecklist(
        context,
        airlineProvider,
        airportProvider,
      );
    }

    final List<Country> countriesList;
    final bool isQuantifiable = achievement.targetCount != null ||
        achievement.targetPopulationLimit != null ||
        achievement.targetAreaLimit != null ||
        achievement.targetGdpLimit != null;

    final Map<String, double> gdpMap = {
      for (var e in allEconomyData) e.isoA3: e.gdpNominal
    };

    if (achievement.targetIsoCodes != null) {
      countriesList = countryProvider.allCountries
          .where((c) => achievement.targetIsoCodes!.contains(c.isoA3))
          .toList();
      countriesList.sort((a, b) => a.name.compareTo(b.name));
    } else if (isQuantifiable) {
      if (achievement.id == 'africa_10') {
        countriesList = countryProvider.allCountries
            .where((c) => c.continent == 'Africa')
            .toList();
      } else if (achievement.id == 'asia_20') {
        countriesList = countryProvider.allCountries
            .where((c) => c.continent == 'Asia')
            .toList();
      } else if (achievement.id == 'europe_20') {
        countriesList = countryProvider.allCountries
            .where((c) => c.continent == 'Europe')
            .toList();
      } else if (achievement.id == 'americas_10') {
        countriesList = countryProvider.allCountries
            .where((c) => c.continent == 'North America' || c.continent == 'South America')
            .toList();
      } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6') {
        countriesList = countryProvider.allCountries
            .where((c) => visitedIsos.contains(c.isoA3))
            .toList();
      } else {
        countriesList = countryProvider.allCountries
            .where((c) => visitedIsos.contains(c.isoA3))
            .toList();
      }

      if (achievement.targetPopulationLimit != null) {
        countriesList.sort((a, b) => b.populationEst.compareTo(a.populationEst));
      } else if (achievement.targetAreaLimit != null) {
        countriesList.sort((a, b) => (b.area ?? 0.0).compareTo(a.area ?? 0.0));
      } else if (achievement.targetGdpLimit != null) {
        countriesList.sort((a, b) =>
            (gdpMap[b.isoA3] ?? 0.0).compareTo(gdpMap[a.isoA3] ?? 0.0));
      } else if (achievement.targetCount != null) {
        if (achievement.id == 'africa_10' || achievement.id == 'asia_20' ||
            achievement.id == 'europe_20' || achievement.id == 'americas_10') {
          countriesList.sort((a, b) => a.name.compareTo(b.name));
        } else {
          countriesList.sort((a, b) {
            final dateA = _getEarliestVisitDate(countryProvider, a.name);
            final dateB = _getEarliestVisitDate(countryProvider, b.name);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateA.compareTo(dateB);
          });
        }
      } else {
        countriesList.sort((a, b) => a.name.compareTo(b.name));
      }
    } else {
      return const SizedBox.shrink();
    }

    if (countriesList.isEmpty && isQuantifiable) {
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
              Icon(Icons.explore_off_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No countries visited yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your journey!',
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: countriesList.length,
      itemBuilder: (context, index) {
        final country = countriesList[index];
        final bool isVisited = visitedIsos.contains(country.isoA3);

        final details = countryProvider.getVisitDetails(country.name);
        final double rating = details?.rating ?? 0.0;
        final bool isHome = countryProvider.homeCountryIsoA3 == country.isoA3;

        String? subtitleText;
        if (achievement.targetPopulationLimit != null) {
          subtitleText = 'Population: ${_formatPopulation(country.populationEst)}';
        } else if (achievement.targetAreaLimit != null) {
          subtitleText = 'Area: ${_formatArea(country.area?.toInt())}';
        } else if (achievement.targetGdpLimit != null) {
          final double countryGdp = gdpMap[country.isoA3] ?? 0.0;
          subtitleText = 'GDP: ${_formatGdp((countryGdp * 1000000000).toInt())}';
        } else if (achievement.targetCount != null) {
          if (achievement.id == 'africa_10' || achievement.id == 'asia_20' ||
              achievement.id == 'europe_20' || achievement.id == 'americas_10') {
            if (isVisited) {
              final visitDate = _getEarliestVisitDate(countryProvider, country.name);
              subtitleText = visitDate != null
                  ? 'Visited: ${visitDate.toString().split(' ')[0]}'
                  : 'Visited';
            } else {
              subtitleText = 'Not visited yet';
            }
          } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6') {
            subtitleText = country.continent ?? 'Unknown continent';
          } else {
            final visitDate = _getEarliestVisitDate(countryProvider, country.name);
            subtitleText = visitDate != null
                ? 'Visited: ${visitDate.toString().split(' ')[0]}'
                : 'Visited: Unknown date';
          }
        }

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
                      _getFlagImageUrl(country.isoA2),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitleText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    if (achievement.requiresRating && rating > 0)
                      Padding(
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
                      ),
                    if (achievement.requiresHome && isHome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.home, color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Home',
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
                trailing: achievement.targetIsoCodes != null ||
                    achievement.id == 'africa_10' ||
                    achievement.id == 'asia_20' ||
                    achievement.id == 'europe_20' ||
                    achievement.id == 'americas_10'
                    ? (isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 24)
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24))
                    : (isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 24)
                    : null),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount = freshLandmark.locations?.length ?? 0;

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (e) {
            landmarkThemeColor = null;
          }
        }

        final Color themeColor = landmarkThemeColor ?? fallbackThemeColor;

        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                            child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: Text(freshLandmark.name,
                                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                        if (isVisited || visitedSubCount > 0) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(locationDisplay, style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                          ],
                        ),
                        const Divider(height: 20),
                        if (totalSubCount > 1) ...[
                          Text("Components / Locations",
                              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: freshLandmark.locations!.map((loc) {
                                final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                return CheckboxListTile(
                                  title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                  value: isLocVisited,
                                  activeColor: themeColor,
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (val) {
                                    provider.toggleSubLocation(freshLandmark.name, loc.name);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 24),
                        ],
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name))]),
                        const SizedBox(height: 8),
                        if (freshLandmark.visitDates.isNotEmpty) ...freshLandmark.visitDates.asMap().entries.map((entry) => LandmarkVisitEditorCard(
                          key: ValueKey('${freshLandmark.name}_${entry.key}'),
                          landmarkName: freshLandmark.name,
                          visitDate: entry.value,
                          index: entry.key,
                          onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                          availableLocations: freshLandmark.locations,
                        )) else const Center(child: Text('No visits recorded.')),
                        const Divider(height: 24),
                        LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {});
  }

  void _showCityDetailSheet(BuildContext context, String cityName, String countryCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<CityProvider>(
        builder: (context, provider, child) {
          final cityVisitDetail = provider.getCityVisitDetail(cityName) ??
              CityVisitDetail(name: cityName);
          final countryProvider = context.read<CountryProvider>();
          final countryModel = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == countryCode);
          final cityModel = provider.allCities.firstWhereOrNull((c) => c.name == cityName);
          final themeColor = countryModel?.themeColor ?? const Color(0xFF6A5ACD);
          final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold)),
                            ),
                            if (countryModel != null)
                              Container(
                                width: 40,
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: headerTextColor.withOpacity(0.3)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CountryFlag.fromCountryCode(countryModel.isoA2),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cityName,
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: headerTextColor),
                              ),
                            ),
                            if (cityVisitDetail.visitDateRanges.isNotEmpty)
                              Icon(Icons.verified, color: headerTextColor, size: 28),
                          ],
                        ),
                        Text(
                          countryModel?.name ?? countryCode,
                          style: TextStyle(
                            fontSize: 16,
                            color: headerTextColor.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('My Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  RatingBar.builder(
                                    initialRating: cityVisitDetail.rating,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 24,
                                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                    onRatingUpdate: (rating) => provider.updateCityVisitDetail(
                                      cityName,
                                      cityVisitDetail.copyWith(rating: rating),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  cityVisitDetail.isWishlisted ? Icons.favorite : Icons.favorite_border,
                                  color: cityVisitDetail.isWishlisted ? Colors.red : Colors.grey,
                                  size: 30,
                                ),
                                onPressed: () => provider.updateCityVisitDetail(
                                  cityName,
                                  cityVisitDetail.copyWith(isWishlisted: !cityVisitDetail.isWishlisted),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 40),
                          if (cityModel != null) ...[
                            _buildCityStatRow('Population', NumberFormat('#,###').format(cityModel.population), Icons.people_outline, themeColor),
                            const Divider(height: 40),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Visits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                                onPressed: () {
                                  final updated = cityVisitDetail.copyWith(
                                    visitDateRanges: [...cityVisitDetail.visitDateRanges, DateRange()],
                                  );
                                  provider.updateCityVisitDetail(cityName, updated);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (cityVisitDetail.visitDateRanges.isNotEmpty)
                            ...cityVisitDetail.visitDateRanges.asMap().entries.map((entry) => _CityVisitCard(
                              key: ValueKey('${cityName}_visit_${entry.key}'),
                              range: entry.value,
                              onSave: (updated) => provider.updateCityDateRange(cityName, entry.key, updated),
                              onDelete: () => provider.removeCityDateRange(cityName, entry.key),
                            ))
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('No visits recorded.'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCityStatRow(String label, String value, IconData icon, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: themeColor),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showUnescoDetailsInBadge(BuildContext context, UnescoSite site, UnescoProvider unescoProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Consumer<UnescoProvider>(
          builder: (context, provider, _) {
            final countryProvider = context.read<CountryProvider>();

            final freshSite = provider.allSites.firstWhere((l) => l.name == site.name);
            final isVisited = provider.visitedSites.contains(freshSite.name);
            final isWishlisted = provider.wishlistedSites.contains(freshSite.name);

            Color themeColor = const Color(0xFF66BB6A);
            if (freshSite.countriesIsoA3.isNotEmpty) {
              final country = countryProvider.allCountries.firstWhereOrNull(
                      (c) => c.isoA3 == freshSite.countriesIsoA3.first
              );
              if (country?.themeColor != null) themeColor = country!.themeColor!;
            }

            final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
                ? Colors.white
                : Colors.black;

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                                  child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(freshSite.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: headerTextColor))),
                              if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 28),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text("${freshSite.city}, ${freshSite.countriesIsoA3.join(', ')}",
                                      style: TextStyle(color: headerTextColor.withOpacity(0.8), fontSize: 14))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Text('Wishlist:'),
                                  IconButton(
                                    icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border,
                                        color: isWishlisted ? Colors.red : Colors.grey),
                                    onPressed: () => provider.toggleWishlistStatus(freshSite.name),
                                  ),
                                ]),
                                Row(children: [
                                  const Text('My Rating:'),
                                  const SizedBox(width: 8),
                                  RatingBar.builder(
                                    initialRating: freshSite.rating ?? 0.0,
                                    minRating: 0,
                                    allowHalfRating: true,
                                    itemSize: 24,
                                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                    onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating),
                                  ),
                                ]),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Visit History (${freshSite.visitDates.length})',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Visit'),
                                  onPressed: () => provider.addVisitDate(freshSite.name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (freshSite.visitDates.isNotEmpty)
                              ...freshSite.visitDates.asMap().entries.map((entry) => UnescoVisitEditorCard(
                                siteName: freshSite.name,
                                visitDate: entry.value,
                                index: entry.key,
                                onDelete: () => provider.removeVisitDate(freshSite.name, entry.key),
                                availableLocations: freshSite.locations,
                              ))
                            else
                              const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('No visits recorded.'),
                              )),
                            const Divider(height: 40),
                            LandmarkInfoCard(
                              overview: freshSite.overview,
                              historySignificance: freshSite.history_significance,
                              highlights: freshSite.highlights,
                              themeColor: themeColor,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CityVisitCard extends StatefulWidget {
  final DateRange range;
  final Function(DateRange) onSave;
  final VoidCallback onDelete;

  const _CityVisitCard({
    super.key,
    required this.range,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_CityVisitCard> createState() => _CityVisitCardState();
}

class _CityVisitCardState extends State<_CityVisitCard> {
  late DateTime? _arrivalDate;
  late DateTime? _departureDate;

  @override
  void initState() {
    super.initState();
    _arrivalDate = widget.range.arrival;
    _departureDate = widget.range.departure;
  }

  Future<void> _selectDate(BuildContext context, bool isArrival) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isArrival ? _arrivalDate : _departureDate) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isArrival) {
          _arrivalDate = picked;
        } else {
          _departureDate = picked;
        }
      });
      widget.onSave(DateRange(arrival: _arrivalDate, departure: _departureDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Arrival',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _arrivalDate != null ? DateFormat('MMM d, yyyy').format(_arrivalDate!) : 'Select date',
                        style: TextStyle(color: _arrivalDate != null ? Colors.black : Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Departure',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _departureDate != null ? DateFormat('MMM d, yyyy').format(_departureDate!) : 'Select date',
                        style: TextStyle(color: _departureDate != null ? Colors.black : Colors.grey),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showAirportDetailsModal(BuildContext context, Airport airport, AirportProvider airportProvider, CountryProvider countryProvider) {
  final useCount = airportProvider.getVisitCount(airport.iataCode);

  String countryName = airport.country;
  try {
    final matchedCountry = countryProvider.allCountries.firstWhere(
            (c) => c.isoA2.toUpperCase() == airport.country.toUpperCase()
    );
    countryName = matchedCountry.name;
  } catch (_) {}

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            Container(
              color: Colors.blue.shade800,
              padding: const EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${airport.name} (${airport.iataCode})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          countryName,
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$useCount',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'uses',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Consumer<AirportProvider>(
                  builder: (context, provider, _) {
                    final rating = provider.getRating(airport.iataCode);
                    final isHub = provider.isHub(airport.iataCode);
                    final isFavorite = provider.isFavorite(airport.iataCode);
                    final loungeVisitCount = provider.getLoungeVisitCount(airport.iataCode);
                    final avgLoungeRating = provider.getAverageLoungeRating(airport.iataCode);
                    final visits = provider.getVisitEntries(airport.iataCode);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isHub ? Colors.amber.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isHub ? Colors.amber.shade200 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.star, color: isHub ? Colors.amber : Colors.grey),
                                    const SizedBox(width: 8),
                                    const Text('My Hub'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isFavorite ? Colors.red.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFavorite ? Colors.red.shade200 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite, color: isFavorite ? Colors.red : Colors.grey),
                                    const SizedBox(width: 8),
                                    const Text('Favorite'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (rating > 0) ...[
                          const Text(
                            'My Rating',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${rating.toStringAsFixed(1)} / 5.0',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (loungeVisitCount > 0) ...[
                          const Text(
                            'Business Lounge',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.wine_bar, color: Colors.purple.shade700),
                                    const SizedBox(width: 8),
                                    Text('$loungeVisitCount visits'),
                                  ],
                                ),
                                if (avgLoungeRating > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Average: ${avgLoungeRating.toStringAsFixed(1)}'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          'Visit History (${visits.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visits.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No visits recorded',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else
                          ...visits.asMap().entries.map((entry) {
                            final visit = entry.value;
                            final date = visit.date;
                            String dateStr = 'Unknown date';
                            if (date != null) {
                              dateStr = DateFormat('MMM d, yyyy').format(date);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    visit.isTransfer ? Icons.sync_alt :
                                    visit.isLayover ? Icons.connecting_airports :
                                    visit.isStopover ? Icons.layers :
                                    Icons.flight_takeoff,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (visit.isTransfer || visit.isLayover || visit.isStopover)
                                          Text(
                                            visit.isTransfer ? 'Transfer' :
                                            visit.isLayover ? 'Layover' :
                                            'Stopover',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (visit.isLoungeUsed)
                                    Icon(Icons.wine_bar, color: Colors.purple.shade700, size: 20),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}