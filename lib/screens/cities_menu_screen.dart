// lib/screens/cities_menu_screen.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'package:jidoapp/screens/cities_share.dart';
import 'package:jidoapp/screens/city_geography_screen.dart';
import 'package:jidoapp/screens/city_overview_stats_screen.dart';
import 'package:jidoapp/screens/city_society_screen.dart';
import 'package:jidoapp/screens/city_specials_screen.dart';
import 'package:jidoapp/screens/top_cities_screen.dart';
import 'package:jidoapp/screens/tourism_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

// [추가] 로딩 로고 위젯 임포트

import 'package:jidoapp/services/home_widget_service.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';

class CitiesMenuScreen extends StatefulWidget {
  const CitiesMenuScreen({super.key});

  @override
  State<CitiesMenuScreen> createState() => _CitiesMenuScreenState();
}

class _CitiesMenuScreenState extends State<CitiesMenuScreen> {
  int _selectedStatIndex = 0;

  // ⭐️ 지도 캡처 컨트롤러
  final ScreenshotController _mapScreenshotController = ScreenshotController();
  bool _isSharing = false;
  bool _widgetUpdated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), _captureAndUpdateWidget);
  }

  final List<Map<String, dynamic>> statisticsItems = [
    {
      'icon': Icons.emoji_events,
      'title': 'Top Cities',
      'description': 'View detailed statistics',
      'screen': const TopCitiesScreen(),
    },
    {
      'icon': Icons.insights,
      'title': 'General',
      'description': 'View detailed statistics',
      'screen': const CityOverviewStatsScreen(),
    },
    {
      'icon': Icons.groups,
      'title': 'Culture',
      'description': 'View detailed statistics',
      'screen': const CitySocietyScreen(),
    },
    {
      'icon': Icons.tour,
      'title': 'Travel',
      'description': 'View detailed statistics',
      'screen': TourismScreen(),
    },
    {
      'icon': Icons.terrain,
      'title': 'Geography',
      'description': 'View detailed statistics',
      'screen': const CityGeographyStatsScreen(),
    },
    {
      'icon': Icons.auto_awesome,
      'title': 'Specials',
      'description': 'View detailed statistics',
      'screen': const CitySpecialsScreen(),
    },
  ];

  final Map<String, Color> _countryColorMap = {
    'IN': const Color(0xFFFF9933),
    'CN': const Color(0xFFEE1C25),
    'US': const Color(0xFF002868),
    'ID': const Color(0xFFCE1126),
    'PK': const Color(0xFF006643),
    'NG': const Color(0xFF008751),
    'BR': const Color(0xFF009B3A),
    'BD': const Color(0xFF006A4E),
    'RU': const Color(0xFFD52B1E),
    'MX': const Color(0xFF006847),
    'JP': const Color(0xFFBC002D),
    'PH': const Color(0xFF0038A8),
    'CD': const Color(0xFF00A9CE),
    'ET': const Color(0xFF078930),
    'EG': const Color(0xFFCE1126),
    'VN': const Color(0xFFDA251D),
    'IR': const Color(0xFF239F40),
    'TR': const Color(0xFFE30A17),
    'DE': const Color(0xFFDD0000),
    'FR': const Color(0xFF0055A4),
    'GB': const Color(0xFF012169),
    'TZ': const Color(0xFF1EB53A),
    'TH': const Color(0xFF2D2A4A),
    'ZA': const Color(0xFFFFB612),
    'IT': const Color(0xFF009246),
    'KE': const Color(0xFF000000),
    'CO': const Color(0xFFFCD116),
    'SD': const Color(0xFFD21034),
    'MM': const Color(0xFFFECB00),
    'KR': const Color(0xFF0047A0),
    'ES': const Color(0xFFAA151B),
    'DZ': const Color(0xFF006633),
    'AR': const Color(0xFF75AADB),
    'IQ': const Color(0xFFCE1126),
    'UG': const Color(0xFF000000),
    'UA': const Color(0xFF005BBB),
    'CA': const Color(0xFFFF0000),
    'PL': const Color(0xFFDC143C),
    'MA': const Color(0xFFC1272D),
    'UZ': const Color(0xFF0072CE),
    'SA': const Color(0xFF006C35),
    'PE': const Color(0xFFD91023),
    'AF': const Color(0xFF000000),
    'VE': const Color(0xFFFCD116),
    'MY': const Color(0xFF0032A0),
    'GH': const Color(0xFFCF0921),
    'NP': const Color(0xFFDC143C),
    'YE': const Color(0xFFCE1126),
    'AO': const Color(0xFFCE1126),
    'MZ': const Color(0xFF009736),
    'AU': const Color(0xFF00008B),
    'SY': const Color(0xFFCE1126),
    'CI': const Color(0xFFF77F00),
    'MG': const Color(0xFFFC3D32),
    'CM': const Color(0xFF007A5E),
    'NE': const Color(0xFFE05206),
    'ML': const Color(0xFF14B53A),
    'TW': const Color(0xFF000095),
    'BF': const Color(0xFFDE0000),
    'LK': const Color(0xFFFF5F00),
    'EC': const Color(0xFFFFDD00),
    'KZ': const Color(0xFF00AFCA),
    'CL': const Color(0xFFDA291C),
    'RO': const Color(0xFF002B7F),
    'NL': const Color(0xFFFF6700),
    'MW': const Color(0xFF000000),
    'GT': const Color(0xFF4997D0),
    'SO': const Color(0xFF4189DD),
    'TD': const Color(0xFF002664),
    'SN': const Color(0xFF00853F),
    'KH': const Color(0xFF032EA1),
    'ZW': const Color(0xFF009530),
    'RW': const Color(0xFF2060A3),
    'BJ': const Color(0xFF008850),
    'BO': const Color(0xFFD93025),
    'BE': const Color(0xFF000000),
    'CU': const Color(0xFF00529B),
    'TN': const Color(0xFFE70013),
    'HT': const Color(0xFF00209F),
    'GR': const Color(0xFF0D5EAF),
    'CZ': const Color(0xFFD7141A),
    'SE': const Color(0xFF006AA7),
    'PT': const Color(0xFFDA291C),
    'AZ': const Color(0xFF0092BC),
    'DO': const Color(0xFF002D62),
    'HN': const Color(0xFF00BCE4),
    'BI': const Color(0xFF1DB954),
    'AE': const Color(0xFFFF0000),
    'AT': const Color(0xFFED2939),
    'CH': const Color(0xFFFF0000),
    'BG': const Color(0xFF00966E),
    'KG': const Color(0xFFFF0000),
    'TJ': const Color(0xFFCD2027),
    'SL': const Color(0xFF1EB53A),
    'LA': const Color(0xFFCE1126),
    'PG': const Color(0xFFCE1126),
    'SV': const Color(0xFF0047AB),
    'LY': const Color(0xFFE70013),
    'SG': const Color(0xFFED2939),
    'DK': const Color(0xFFC8102E),
    'FI': const Color(0xFF002F6C),
    'NO': const Color(0xFFBA0C2F),
    'IE': const Color(0xFF169B62),
    'OM': const Color(0xFFDC143C),
    'KW': const Color(0xFF007A3D),
    'GE': const Color(0xFFFF0000),
    'HR': const Color(0xFFFF0000),
    'ER': const Color(0xFF1DB954),
    'PA': const Color(0xFF002868),
    'UY': const Color(0xFF75AADB),
    'MN': const Color(0xFFDA2032),
    'QA': const Color(0xFF8A1538),
    'NZ': const Color(0xFF00247D),
    'SK': const Color(0xFF0B4EA2),
    'LB': const Color(0xFFED1C24),
    'PS': const Color(0xFF009639),
    'PR': const Color(0xFFED1C24),
    'LT': const Color(0xFFFDB913),
    'AL': const Color(0xFFDA291C),
    'JO': const Color(0xFF007A3D),
    'EE': const Color(0xFF4891D9),
    'CY': const Color(0xFFD47600),
    'FJ': const Color(0xFF62B5E5),
    'LU': const Color(0xFF00A1DE),
    'IS': const Color(0xFF02529C),
    'MT': const Color(0xFFCF142B),
    'MV': const Color(0xFFD21034),
    'BZ': const Color(0xFF003F87),
    'BH': const Color(0xFFCE1126),
    'GQ': const Color(0xFF3E9A00),
    'GA': const Color(0xFF009F6B),
    'GM': const Color(0xFF1DBE5E),
    'NA': const Color(0xFF003580),
    'BW': const Color(0xFF75AADB),
    'GN': const Color(0xFFCE1126),
    'CF': const Color(0xFF0038A8),
    'CG': const Color(0xFF009543),
    '民間': const Color(0xFF6AB2E7),
    'KM': const Color(0xFF3A75C4),
    'LS': const Color(0xFF00209F),
    'SZ': const Color(0xFF3E5EB8),
    'CV': const Color(0xFF003893),
    'SB': const Color(0xFF0051BA),
    'VU': const Color(0xFF009543),
    'WS': const Color(0xFFCE1126),
    'TO': const Color(0xFFC10000),
    'FM': const Color(0xFF6797D6),
    'KI': const Color(0xFF0032A0),
    'NR': const Color(0xFF002B7F),
    'PW': const Color(0xFF4AADD6),
    'MH': const Color(0xFF0033A0),
    'TV': const Color(0xFF68BBE2),
    'SM': const Color(0xFF74C0E3),
    'LI': const Color(0xFF002B7F),
    'MC': const Color(0xFFCE1126),
    'VA': const Color(0xFFFFE000),
    'AD': const Color(0xFF10069F),
    'IM': const Color(0xFFC8102E),
    'JE': const Color(0xFFDA291C),
    'GG': const Color(0xFFE8112D),
    'FK': const Color(0xFF012169),
    'GL': const Color(0xFFD00C33),
    'AX': const Color(0xFF0064AE),
    'PN': const Color(0xFF012169),
    'WF': const Color(0xFFEF4135),
    'NC': const Color(0xFF0036A7),
    'PF': const Color(0xFFCE1126),
    'PM': const Color(0xFF00267F),
    'BL': const Color(0xFF0055A4),
    'MF': const Color(0xFF0055A4),
    'CW': const Color(0xFF002B7F),
    'SX': const Color(0xFF002B7F),
    'AW': const Color(0xFF4189DD),
    'BM': const Color(0xFFCF142B),
    'VG': const Color(0xFF012169),
    'KY': const Color(0xFF012169),
    'TC': const Color(0xFF012169),
    'VI': const Color(0xFF002868),
    'MS': const Color(0xFF012169),
    'AG': const Color(0xFFCE1126),
    'GD': const Color(0xFFCE1126),
    'LC': const Color(0xFF65C6E8),
    'VC': const Color(0xFF002868),
    'BB': const Color(0xFF00267F),
    'DM': const Color(0xFF006B3F),
    'KN': const Color(0xFF009E49),
    'AI': const Color(0xFF012169),
    'NF': const Color(0xFF008751),
    'CK': const Color(0xFF00247D),
    'NU': const Color(0xFFFCD116),
    'AS': const Color(0xFF002868),
    'GU': const Color(0xFF003C71),
    'MP': const Color(0xFF65C6E8),
    'HK': const Color(0xFFDE2910),
    'MO': const Color(0xFF006747),
    'MU': const Color(0xFFEA2839),
    'FO': const Color(0xFF00559B),
    'SC': const Color(0xFF003F87),
    'CR': const Color(0xFF002B7F),
    'NI': const Color(0xFF0067C6),
    'BS': const Color(0xFF00ABC9),
    'TT': const Color(0xFFE00000),
    'JM': const Color(0xFF009B3A),
    'IL': const Color(0xFF0038B8),
    'KP': const Color(0xFFED1C27),
    'BT': const Color(0xFFFF9933),
    'AM': const Color(0xFFD90012),
    'TL': const Color(0xFFDC241F),
    'BN': const Color(0xFFFCE300),
    'TM': const Color(0xFF009736),
    'SR': const Color(0xFF377E3F),
    'GY': const Color(0xFF009E49),
    'PY': const Color(0xFF0038A8),
    'SS': const Color(0xFF000000),
    'EH': const Color(0xFF00822B),
    'ZM': const Color(0xFF198D00),
    'LR': const Color(0xFF002868),
    'TG': const Color(0xFF006A44),
    'GW': const Color(0xFF009E49),
    'MR': const Color(0xFF00A95C),
    'ST': const Color(0xFF12AD2B),
    'BY': const Color(0xFFCF101A),
    'LV': const Color(0xFF9E3039),
    'MK': const Color(0xFFD20000),
    'XK': const Color(0xFF244AA5),
    'HU': const Color(0xFFCD2A3E),
    'RS': const Color(0xFFC6363C),
    'SI': const Color(0xFF005DAA),
    'ME': const Color(0xFFC40308),
    'BA': const Color(0xFF002395),
    'MD': const Color(0xFF0047AB),
  };

  // ⭐️ 공유 버튼 클릭 시 실행
  Future<void> _handleShare(BuildContext context, CityProvider cityProvider) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      // 1. 현재 화면의 지도를 캡처합니다.
      final Uint8List? mapImage = await _mapScreenshotController.capture();
      if (mapImage == null) throw Exception("Failed to capture map");

      // 2. 방문 도시 데이터를 가져옵니다.
      final visitedCities = cityProvider.allCities.where((city) {
        return cityProvider.visitDetails.containsKey(city.name);
      }).toList();

      if (!mounted) return;

      // 3. CitiesShare의 기능을 호출하여 공유를 시작합니다.
      await CitiesShare.share(
        context: context,
        mapImage: mapImage,
        visitedCities: visitedCities,
      );
    } catch (e) {
      debugPrint("Cities Share Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _captureAndUpdateWidget() async {
    if (!mounted || _widgetUpdated) return;
    _widgetUpdated = true;
    try {
      final cityProvider = context.read<CityProvider>();
      final visitedCities = cityProvider.allCities
          .where((city) => cityProvider.visitDetails.containsKey(city.name))
          .toList();
      final mapImage = await _mapScreenshotController.capture();
      if (mapImage == null) return;
      final continentStats = CitiesShare.calculateContinentStats(visitedCities);
      final widgetImage = await ScreenshotController().captureFromWidget(
        CitiesShare.buildStatsLayout(context, mapImage, visitedCities, continentStats),
        context: context,
        pixelRatio: 2.0,
      );
      await HomeWidgetService.updateWidget(
        widgetImage: widgetImage,
        widgetType: WidgetType.cities,
      );
    } catch (e) {
      debugPrint('❌ cities 위젯 캡처 실패: $e');
    }
  }

  Widget _buildStatCategoryChip(BuildContext context, int index) {
    final item = statisticsItems[index];
    final isSelected = _selectedStatIndex == index;
    final primaryColor = Colors.amber;

    return GestureDetector(
      onTap: () => setState(() => _selectedStatIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Icon(
          item['icon'],
          color: isSelected ? Colors.white : Colors.grey.shade500,
          size: 22,
        ),
      ),
    );
  }

  String _getContinentAsset(String continent) {
    switch (continent) {
      case 'Asia':
        return 'assets/icons/asia.png';
      case 'Europe':
        return 'assets/icons/europe.png';
      case 'Africa':
        return 'assets/icons/africa.png';
      case 'North America':
        return 'assets/icons/n_america.png';
      case 'South America':
        return 'assets/icons/s_america.png';
      case 'Oceania':
        return 'assets/icons/oceania.png';
      default:
        return 'assets/icons/asia.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.amber;
    const backgroundColor = Colors.white;

    const double citiesScreenBaseRadius = 2.5;
    final double menuScreenRadius = (citiesScreenBaseRadius * 0.7) / 2;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.amber,
        ).copyWith(secondary: Colors.amberAccent),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/icons/app_wallpaper.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Consumer2<CityProvider, CountryProvider>(
                builder: (context, cityProvider, countryProvider, child) {
                  // [수정] Provider 로딩 상태일 때 -> 꽉 찬 비디오 로딩 화면 출력
                  if (cityProvider.isLoading || countryProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final Map<String, String> isoToCountryName = {
                    for (var c in countryProvider.allCountries) c.isoA2.toUpperCase(): c.name
                  };

                  final visitedCount = cityProvider.totalVisitedCount;

                  Map<String, int> countryCityCounts = {};
                  Map<String, String> countryIsoToResolvedName = {};

                  cityProvider.visitDetails.forEach((cityName, detail) {
                    final city = cityProvider.getCityDetail(cityName);
                    if (city != null && city.countryIsoA2.isNotEmpty) {
                      final iso = city.countryIsoA2.toUpperCase();
                      countryCityCounts[iso] = (countryCityCounts[iso] ?? 0) + 1;

                      if (!countryIsoToResolvedName.containsKey(iso)) {
                        String? resolvedName = isoToCountryName[iso];

                        if ((resolvedName == null || resolvedName == 'Unknown') &&
                            cityProvider.allCities.isNotEmpty) {
                          final sameIsoCity = cityProvider.allCities.firstWhereOrNull(
                                (c) => c.countryIsoA2.toUpperCase() == iso,
                          );
                          if (sameIsoCity != null && sameIsoCity.country != 'Unknown') {
                            resolvedName = sameIsoCity.country;
                          }
                        }

                        resolvedName ??= city.country;

                        if (resolvedName == 'Unknown') {
                          resolvedName = iso;
                        }

                        countryIsoToResolvedName[iso] = resolvedName;
                      }
                    }
                  });

                  String topCountryName = 'None';
                  String topCountryIso = '';
                  int topCountryCityCount = 0;

                  if (countryCityCounts.isNotEmpty) {
                    final entry = countryCityCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
                    topCountryIso = entry.key;
                    topCountryCityCount = entry.value;
                    topCountryName = countryIsoToResolvedName[topCountryIso] ?? topCountryIso;
                  }

                  Map<String, int> continentCounts = {};
                  cityProvider.visitDetails.forEach((cityName, detail) {
                    final city = cityProvider.getCityDetail(cityName);
                    if (city != null) {
                      continentCounts[city.continent] = (continentCounts[city.continent] ?? 0) + 1;
                    }
                  });

                  String topContinent = 'None';
                  int topContinentCount = 0;
                  continentCounts.forEach((continent, count) {
                    if (count > topContinentCount) {
                      topContinentCount = count;
                      topContinent = continent;
                    }
                  });

                  Color getCountryColor(String isoA2) {
                    return _countryColorMap[isoA2.toUpperCase()] ?? primaryColor;
                  }

                  Color getContinentColor(String continent) {
                    switch (continent) {
                      case 'North America':
                        return Colors.blue.shade400;
                      case 'South America':
                        return Colors.green.shade400;
                      case 'Africa':
                        return Colors.brown.shade400;
                      case 'Europe':
                        return Colors.yellow.shade700;
                      case 'Asia':
                        return Colors.pink.shade300;
                      case 'Oceania':
                        return Colors.purple.shade400;
                      default:
                        return Colors.grey.shade500;
                    }
                  }

                  final visitedCityMarkers = cityProvider.visitDetails.keys
                      .map((cityName) {
                    final cityData = cityProvider.getCityDetail(cityName);
                    if (cityData != null) {
                      return LatLng(cityData.latitude, cityData.longitude);
                    }
                    return null;
                  })
                      .whereType<LatLng>()
                      .toList();

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.location_city_rounded,
                                              size: 24,
                                              color: primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Total Visited',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade500,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                                textBaseline: TextBaseline.alphabetic,
                                                children: [
                                                  TweenAnimationBuilder<double>(
                                                    duration: const Duration(milliseconds: 1200),
                                                    curve: Curves.easeOutCubic,
                                                    tween: Tween<double>(
                                                      begin: 0,
                                                      end: visitedCount.toDouble(),
                                                    ),
                                                    builder: (context, val, child) {
                                                      return Text(
                                                        '${val.toInt()}',
                                                        style: const TextStyle(
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.black87,
                                                          height: 1.0,
                                                          letterSpacing: -1.0,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'cities',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                if (topCountryIso.isNotEmpty) {
                                                  final targetCountry = countryProvider.allCountries.firstWhereOrNull(
                                                          (c) => c.isoA2.toUpperCase() == topCountryIso
                                                  );
                                                  if (targetCountry != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => CountryDetailScreen(country: targetCountry),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      getCountryColor(topCountryIso).withOpacity(0.12),
                                                      getCountryColor(topCountryIso).withOpacity(0.05),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: getCountryColor(topCountryIso).withOpacity(0.2),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 28,
                                                          height: 28,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(6),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.1),
                                                                blurRadius: 4,
                                                                offset: const Offset(0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: topCountryIso.isNotEmpty
                                                                ? CountryFlag.fromCountryCode(topCountryIso)
                                                                : Icon(
                                                              Icons.flag_rounded,
                                                              size: 16,
                                                              color: Colors.grey.shade400,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Top Country',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.grey.shade600,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      topCountryName,
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.w900,
                                                        color: getCountryColor(topCountryIso),
                                                        height: 1.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.8),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: getCountryColor(topCountryIso).withOpacity(0.3),
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: getCountryColor(topCountryIso).withOpacity(0.1),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        '$topCountryCityCount ${topCountryCityCount == 1 ? 'city' : 'cities'}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: getCountryColor(topCountryIso),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    getContinentColor(topContinent).withOpacity(0.12),
                                                    getContinentColor(topContinent).withOpacity(0.05),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: getContinentColor(topContinent).withOpacity(0.2),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: getContinentColor(topContinent).withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: topContinent != 'None'
                                                            ? Image.asset(
                                                          _getContinentAsset(topContinent),
                                                          width: 16,
                                                          height: 16,
                                                          color: getContinentColor(topContinent),
                                                        )
                                                            : Icon(
                                                          Icons.public_rounded,
                                                          size: 16,
                                                          color: getContinentColor(topContinent),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Top Region',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.grey.shade600,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    topContinent == 'North America'
                                                        ? 'N. America'
                                                        : topContinent == 'South America'
                                                        ? 'S. America'
                                                        : topContinent,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w900,
                                                      color: getContinentColor(topContinent),
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.8),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: getContinentColor(topContinent).withOpacity(0.3),
                                                        width: 1.5,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: getContinentColor(topContinent).withOpacity(0.1),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      '$topContinentCount ${topContinentCount == 1 ? 'city' : 'cities'}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w800,
                                                        color: getContinentColor(topContinent),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 250,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 0,
                                        left: -50,
                                        right: -50,
                                        bottom: -80,
                                        child: Screenshot(
                                          controller: _mapScreenshotController,
                                          child: IgnorePointer(
                                            child: FlutterMap(
                                              options: const MapOptions(
                                                initialCenter: LatLng(20, 0),
                                                initialZoom: 0.3,
                                                interactionOptions: InteractionOptions(
                                                  flags: InteractiveFlag.none,
                                                ),
                                                backgroundColor: Colors.white,
                                              ),
                                              children: [
                                                PolygonLayer(
                                                  polygons: countryProvider.allCountries.expand((country) {
                                                    return country.polygonsData.map((polygonData) {
                                                      return Polygon(
                                                        points: polygonData.first,
                                                        holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                                                        color: Colors.grey.withOpacity(0.15),
                                                        borderColor: Colors.white,
                                                        borderStrokeWidth: 0.5,
                                                        isFilled: true,
                                                      );
                                                    });
                                                  }).toList(),
                                                ),
                                                CircleLayer(
                                                  circles: visitedCityMarkers
                                                      .map(
                                                        (point) => CircleMarker(
                                                      point: point,
                                                      color: primaryColor,
                                                      borderColor: primaryColor.withOpacity(0.7),
                                                      borderStrokeWidth: 0.5,
                                                      radius: menuScreenRadius,
                                                    ),
                                                  )
                                                      .toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _handleShare(context, cityProvider),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: _isSharing
                                                    ? const SizedBox(
                                                  width: 26,
                                                  height: 26,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                  ),
                                                )
                                                    : const Icon(
                                                  Icons.share_rounded,
                                                  color: Colors.amber,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => const CitiesScreen()),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: primaryColor.withOpacity(0.4),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.add_rounded,
                                                  color: Colors.white,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  statisticsItems.length,
                                      (i) => _buildStatCategoryChip(context, i),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  key: ValueKey<int>(_selectedStatIndex),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          statisticsItems[_selectedStatIndex]['icon'],
                                          color: primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              statisticsItems[_selectedStatIndex]['title'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              statisticsItems[_selectedStatIndex]['description'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            // index 0 (Top Cities) 만 로그인 없이 접근 가능
                                            if (_selectedStatIndex > 0) {
                                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                              if (authProvider.user == null) {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (_) => const LoginPromptScreen(),
                                                );
                                                return;
                                              }
                                            }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => statisticsItems[_selectedStatIndex]['screen'],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}