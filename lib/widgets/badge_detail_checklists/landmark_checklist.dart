// lib/widgets/badge_detail_checklists/landmark_checklist.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';

class LandmarkChecklist {
  final Achievement achievement;
  final Function(BuildContext, Landmark, Color) showLandmarkDetailsModal;
  final Widget Function(String) buildFixedTitle;

  LandmarkChecklist({
    required this.achievement,
    required this.showLandmarkDetailsModal,
    required this.buildFixedTitle,
  });

  // --- 커스텀 도시명 및 랜드마크 축약 이름 로직 추가 ---
  final Map<String, String> _customCityMap = {
    'Mount Everest': 'Solukhumbu / Tingri',
    'Grand Canyon': 'Arizona',
    'Mount Fuji': 'Shizuoka–Yamanashi',
    'Great Barrier Reef': 'Queensland',
    'Amazon Rainforest': 'Amazon Basin',
    'Sahara Desert': 'North Africa',
    'Galápagos Islands': 'Galápagos Province',
    'Easter Island': 'Rapa Nui',
    'Mount Kilimanjaro': 'Kilimanjaro Region',
    'Dead Sea': 'Jordan Rift Valley',
    'Matterhorn': 'Valais / Aosta Valley',
    'Banff National Park': 'Alberta',
    'Uluru': 'Northern Territory',
    'Alcatraz': 'San Francisco Bay',
    'Ha Long Bay': 'Quảng Ninh Province',
    'Serengeti National Park': 'Mara–Serengeti Ecosystem',
    'Cappadocia Fairy Chimneys': 'Nevşehir Province',
    'Salar de Uyuni': 'Potosí Department',
    'Amalfi Coast': 'Campania',
    'Monument Valley': 'Arizona–Utah Border',
    'Mount Vesuvius': 'Campania',
    'Antelope Canyon': 'Arizona',
    'Mont Blanc': 'Auvergne-Rhône-Alpes / Aosta',
    'French Polynesia': 'South Pacific',
    'Blue Lagoon': 'Reykjanes Peninsula',
    'Cape of Good Hope': 'Western Cape',
    'Table Mountain': 'Cape Town',
    'Cliffs of Moher': 'County Clare',
    'Jungfrau': 'Bernese Oberland',
    'Lake Titicaca': 'Puno / La Paz',
    'Mount Sinai': 'South Sinai',
    'Dolomites': 'Northern Italy',
    'Milford Sound': 'Fiordland',
    'Bryce Canyon': 'Utah',
    'Atacama Desert': 'Antofagasta Region',
    'Death Valley': 'California',
    'Torres del Paine': 'Magallanes Region',
    "Giant's Causeway": 'County Antrim',
    'Perito Moreno Glacier': 'Santa Cruz Province',
    'Zion Canyon': 'Utah',
    'Lake Bled': 'Upper Carniola',
    'Zhangjiajie National Forest': 'Hunan Province',
    'Pamukkale Travertine Terraces': 'Denizli Province',
    'Plitvice Lakes': 'Lika-Senj County',
    'Arches National Park': 'Utah',
    'Ngorongoro Crater': 'Arusha Region',
    'Denali': 'Alaska',
    'The Twelve Apostles': 'Victoria',
    'Geirangerfjord': 'Møre og Romsdal',
    'Avenue of the Baobabs': 'Menabe Region',
    'Glacier National Park': 'Montana',
    'Waitomo Glowworm Caves': 'Waikato',
    'Jiuzhaigou Valley': 'Sichuan Province',
    'Thingvellir National Park': 'Southwest Iceland',
    'Mount Roraima': 'Guiana Highlands',
    'Vatnajökull Ice Caves': 'Southeast Iceland',
    'Mount Cook': 'Canterbury',
    'Lençóis Maranhenses': 'Maranhão',
    'Mount Athos': 'Chalkidiki',
    'Jökulsárlón Glacier Lagoon': 'Southeast Iceland',
    'Fraser Island': 'Queensland',
    'Mount Rainier': 'Washington State',
    'Lake Baikal': 'Irkutsk Oblast',
    'Mount Etna': 'Sicily',
    'Huangshan': 'Anhui Province'
  };

  String _getDisplayLandmarkName(String name) {
    if (name == 'Auschwitz-Birkenau Memorial and Museum') return 'Auschwitz Birkenau';
    if (name == 'Hungarian Parliament Building') return 'Hungarian Parliament';
    if (name == 'Notre Dame of Cathedral of Saigon' || name == 'Notre Dame Cathedral of Saigon') return 'Saigon Notre Dame';
    if (name == 'Bagan Archaeological Zone') return 'Bagan';
    if (name == 'Pamukkale Travertine Terraces') return 'Pamukkale';
    if (name == 'Pearl Harbor National Memorial' || name == 'Pearl Harbor Peace Memorial') return 'Pearl Harbor Memorial';    if (name == 'Mezquita-Cathedral of Córdoba') return 'Cordoba Mezquita';
    if (name == 'Sheikh Zayed Grand Mosque') return 'Sheikh Zayed Mosque';
    return name;
  }

  String _getDisplayCityName(Landmark item, LandmarksProvider provider) {
    if (_customCityMap.containsKey(item.name)) {
      return _customCityMap[item.name]!;
    }
    if (item.city != 'Unknown' && item.city != 'Unknown City') {
      return item.city;
    }
    // 기본값이면 국가명으로 대체
    return provider.getCountryNames(item.countriesIsoA3);
  }
  // --------------------------------------------------------

  DateTime? _getVisitDate(VisitDate visitDate) {
    if (visitDate.year == null) return null;
    return DateTime(
      visitDate.year!,
      visitDate.month ?? 1,
      visitDate.day ?? 1,
    );
  }

  String _formatVisitDate(VisitDate visitDate) {
    if (visitDate.year == null) return 'Date unknown';
    if (visitDate.month == null) return '${visitDate.year}';
    if (visitDate.day == null) return DateFormat('MMM yyyy').format(DateTime(visitDate.year!, visitDate.month!));
    return DateFormat('MMM d, yyyy').format(DateTime(visitDate.year!, visitDate.month!, visitDate.day!));
  }

  // [수정됨] Top 100 등 특정 타겟 리스트가 있는 뱃지
  Widget buildLandmarkChecklist(BuildContext context, LandmarksProvider landmarksProvider, CountryProvider countryProvider) {
    if (achievement.targetIsoCodes == null) {
      return const SizedBox.shrink();
    }

    final targetNames = achievement.targetIsoCodes!;

    // DB에 실제로 존재하는 랜드마크만 필터링하여 리스트 생성 (없는 랜드마크로 인한 빈 공간 방지)
    final validLandmarks = landmarksProvider.allLandmarks
        .where((l) => targetNames.contains(l.name))
        .toList();

    // 정렬: 이름순 (또는 필요시 방문 여부로 정렬 가능)
    validLandmarks.sort((a, b) => a.name.compareTo(b.name));

    if (validLandmarks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            tr('No landmarks found for this badge.'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final visitedLandmarksSet = landmarksProvider.visitedLandmarks;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: validLandmarks.length,
      itemBuilder: (context, index) {
        final landmark = validLandmarks[index];
        final isVisited = visitedLandmarksSet.contains(landmark.name);

        String? flagCode;
        Color? themeColor;
        if (landmark.countriesIsoA3.isNotEmpty) {
          final country = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA3 == landmark.countriesIsoA3.first
          );
          if (country != null) {
            flagCode = country.isoA2;
            themeColor = country.themeColor;
          }
        }

        return GestureDetector(
          onTap: () {
            showLandmarkDetailsModal(context, landmark, themeColor ?? const Color(0xFF66BB6A)); // Green fallback
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
                leading: flagCode != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 32,
                    height: 24,
                    child: CountryFlag.fromCountryCode(flagCode),
                  ),
                )
                    : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, color: Colors.grey, size: 20),
                ),
                title: buildFixedTitle(_getDisplayLandmarkName(landmark.name)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr(_getDisplayCityName(landmark, landmarksProvider)),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 24) // Green
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  // [수정됨] 박물관, 성 등 카테고리/속성 기반 뱃지
  Widget buildCategoryLandmarkChecklist(
      BuildContext context,
      LandmarksProvider landmarksProvider,
      CountryProvider countryProvider,
      ) {
    final String? attribute;
    switch (achievement.id) {
      case 'museums_10':
        attribute = 'Museum';
        break;
      case 'castles_10':
        attribute = 'Castle';
        break;
      case 'palaces_10':
        attribute = 'Palace';
        break;
      case 'arches_10':
        attribute = 'Gate';
        break;
      case 'christian_10':
        attribute = 'Christian';
        break;
      case 'islamic_10':
        attribute = 'Islamic';
        break;
      case 'buddhist_10':
        attribute = 'Buddhist';
        break;
      case 'hindu_10':
        attribute = 'Hindu';
        break;
      default:
        attribute = null;
    }

    if (attribute == null) {
      return const SizedBox.shrink();
    }

    // 1. 해당 속성을 가진 모든 랜드마크 필터링
    final categoryLandmarks = landmarksProvider.allLandmarks
        .where((l) => l.attributes.contains(attribute))
        .toList();

    // 2. 그 중 방문한 랜드마크만 필터링 (개수 뱃지는 '달성 현황'을 보여주는 것이 목적)
    final visitedCategoryLandmarks = categoryLandmarks
        .where((l) => landmarksProvider.visitedLandmarks.contains(l.name))
        .toList();

    // 3. 정렬: 최근 방문일 순
    visitedCategoryLandmarks.sort((a, b) {
      final dateA = a.visitDates.isNotEmpty ? _getVisitDate(a.visitDates.first) : null;
      final dateB = b.visitDates.isNotEmpty ? _getVisitDate(b.visitDates.first) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    if (visitedCategoryLandmarks.isEmpty) {
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
              Icon(Icons.location_off_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                tr('No ${attribute.toLowerCase()}s visited yet'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('Explore and discover!'),
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
      itemCount: visitedCategoryLandmarks.length,
      itemBuilder: (context, index) {
        final landmark = visitedCategoryLandmarks[index];
        final visitDate = landmark.visitDates.isNotEmpty ? landmark.visitDates.first : null;
        final dateStr = visitDate != null ? _formatVisitDate(visitDate) : 'Date unknown';

        String? flagCode;
        Color? themeColor;
        if (landmark.countriesIsoA3.isNotEmpty) {
          final country = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA3 == landmark.countriesIsoA3.first
          );
          if (country != null) {
            flagCode = country.isoA2;
            themeColor = country.themeColor;
          }
        }

        return GestureDetector(
          onTap: () {
            showLandmarkDetailsModal(context, landmark, themeColor ?? const Color(0xFF66BB6A)); // Green
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
                leading: flagCode != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 32,
                    height: 24,
                    child: CountryFlag.fromCountryCode(flagCode),
                  ),
                )
                    : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, color: Colors.grey, size: 20),
                ),
                title: buildFixedTitle(_getDisplayLandmarkName(landmark.name)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tr(_getDisplayCityName(landmark, landmarksProvider)),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tr(dateStr),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 24), // Green
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildAttributeLandmarkChecklist(
      BuildContext context,
      LandmarksProvider landmarksProvider,
      CountryProvider countryProvider,
      bool isCultural,
      ) {
    final targetAttributes = isCultural
        ? BadgeProvider.culturalAttributes
        : BadgeProvider.naturalAttributes;

    final visitedFiltered = landmarksProvider.allLandmarks
        .where((l) =>
    l.visitDates.isNotEmpty &&
        l.attributes.any((attr) => targetAttributes.contains(attr)))
        .toList();

    visitedFiltered.sort((a, b) {
      final dateA = a.visitDates.isNotEmpty ? _getVisitDate(a.visitDates.first) : null;
      final dateB = b.visitDates.isNotEmpty ? _getVisitDate(b.visitDates.first) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    if (visitedFiltered.isEmpty) {
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
                isCultural ? Icons.museum_outlined : Icons.landscape_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                tr(isCultural
                    ? 'No cultural landmarks visited yet'
                    : 'No natural landmarks visited yet'),
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
      itemCount: visitedFiltered.length,
      itemBuilder: (context, index) {
        final landmark = visitedFiltered[index];
        final visitDate = landmark.visitDates.isNotEmpty ? landmark.visitDates.first : null;
        final dateStr = visitDate != null ? _formatVisitDate(visitDate) : 'Date unknown';

        String? flagCode;
        Color? themeColor;
        if (landmark.countriesIsoA3.isNotEmpty) {
          final country = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA3 == landmark.countriesIsoA3.first
          );
          if (country != null) {
            flagCode = country.isoA2;
            themeColor = country.themeColor;
          }
        }

        return GestureDetector(
          onTap: () {
            showLandmarkDetailsModal(context, landmark, themeColor ?? const Color(0xFF66BB6A)); // Green
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
                leading: flagCode != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 32,
                    height: 24,
                    child: CountryFlag.fromCountryCode(flagCode),
                  ),
                )
                    : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, color: Colors.grey, size: 20),
                ),
                title: buildFixedTitle(_getDisplayLandmarkName(landmark.name)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr(dateStr),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 24), // Green
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildRatedLandmarkChecklist(
      BuildContext context,
      LandmarksProvider landmarksProvider,
      CountryProvider countryProvider,
      ) {
    // Filter landmarks with rating > 0
    final ratedLandmarks = landmarksProvider.allLandmarks
        .where((l) => l.rating != null && l.rating! > 0)
        .toList();

    // Sort by rating (high to low)
    ratedLandmarks.sort((a, b) => b.rating!.compareTo(a.rating!));

    if (ratedLandmarks.isEmpty) {
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
                Icons.rate_review_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                tr('No landmarks rated yet'),
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
      itemCount: ratedLandmarks.length,
      itemBuilder: (context, index) {
        final landmark = ratedLandmarks[index];
        final double rating = landmark.rating ?? 0.0;

        String? flagCode;
        Color? themeColor;
        if (landmark.countriesIsoA3.isNotEmpty) {
          final country = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA3 == landmark.countriesIsoA3.first
          );
          if (country != null) {
            flagCode = country.isoA2;
            themeColor = country.themeColor;
          }
        }

        return GestureDetector(
          onTap: () {
            showLandmarkDetailsModal(context, landmark, themeColor ?? const Color(0xFF66BB6A)); // Green
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
                leading: flagCode != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 32,
                    height: 24,
                    child: CountryFlag.fromCountryCode(flagCode),
                  ),
                )
                    : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, color: Colors.grey, size: 20),
                ),
                title: buildFixedTitle(_getDisplayLandmarkName(landmark.name)),
                subtitle: Padding(
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
                trailing: const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 24), // Green
              ),
            ),
          ),
        );
      },
    );
  }
}