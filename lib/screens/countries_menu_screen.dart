// lib/screens/countries_menu_screen.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/countrydex_screen.dart';

import 'package:jidoapp/screens/population_stats_screen.dart';
import 'package:jidoapp/screens/economy_stats_screen.dart';
import 'package:jidoapp/screens/area_stats_screen.dart';
import 'package:jidoapp/screens/climate_stats_screen.dart';
import 'package:jidoapp/screens/geography_stats_screen.dart';
import 'package:jidoapp/screens/language_stats_screen.dart';
import 'package:jidoapp/screens/religion_stats_screen.dart';
import 'package:jidoapp/screens/specials_stats_screen.dart';
import 'package:jidoapp/screens/society_stats_screen.dart';
import 'package:jidoapp/screens/history_stats_screen.dart';
import 'package:jidoapp/screens/sports_stats_screen.dart';
import 'package:jidoapp/screens/military_stats_screen.dart';
import 'package:jidoapp/screens/geopolitics_stats_screen.dart';
import 'package:jidoapp/screens/overview_stats_screen.dart';
import 'package:jidoapp/screens/settings_screen.dart';

// ⭐️ 분리된 공유 기능 파일 임포트
import 'package:jidoapp/screens/countries_share.dart';
import 'package:screenshot/screenshot.dart'; // 지도 캡처용

// [추가] 로딩 로고 위젯 임포트
import 'package:jidoapp/widgets/plane_loading_logo.dart';

// [추가] 홈 위젯 서비스 임포트
import 'package:jidoapp/services/home_widget_service.dart';

class CountriesMenuScreen extends StatefulWidget {
  const CountriesMenuScreen({super.key});

  @override
  State<CountriesMenuScreen> createState() => _CountriesMenuScreenState();
}

class _CountriesMenuScreenState extends State<CountriesMenuScreen> {
  int _selectedStatIndex = 0;

  // ⭐️ 지도 캡처 컨트롤러
  final ScreenshotController _mapScreenshotController = ScreenshotController();
  final ScreenshotController _widgetScreenshotController = ScreenshotController();
  bool _isSharing = false;

  final List<Map<String, dynamic>> statisticsItems = [
    {'icon': Icons.menu_book, 'title': 'CountryDex', 'screen': const CountryDexScreen()},
    {'icon': Icons.insights, 'title': 'General', 'screen': const OverviewStatsScreen()},
    {'icon': Icons.groups, 'title': 'Culture', 'screen': const SocietyStatsScreen()},
    {'icon': Icons.public, 'title': 'World', 'screen': const MilitaryStatsScreen()},
    {'icon': Icons.terrain, 'title': 'Geography', 'screen': const GeographyStatsScreen()},
    {'icon': Icons.auto_awesome, 'title': 'Specials', 'screen': const SpecialsStatsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FlutterMap 폴리곤 렌더링 시간을 위해 3000ms로 변경
      Future.delayed(const Duration(milliseconds: 3000), () {
        _captureAndUpdateWidget();
      });
    });
  }

  Future<void> _captureAndUpdateWidget() async {
    if (!mounted) return;
    try {
      final provider = context.read<CountryProvider>();
      final visitedList = provider.allCountries
          .where((c) => provider.visitedCountries.contains(c.name))
          .toList();

      // 위젯 전체 UI (지도+통계) 캡처
      final widgetImage = await _widgetScreenshotController.captureFromWidget(
        _buildWidgetPreview(provider, visitedList),
        context: context,
        pixelRatio: 2.0,
        targetSize: const Size(600, 300),
      );

      await HomeWidgetService.updateWidget(
        visitedCountries: visitedList,
        widgetImage: widgetImage,
      );
      debugPrint('✅ 위젯 업데이트 완료');
    } catch (e) {
      debugPrint('❌ 위젯 캡처 실패: $e');
    }
  }

  Widget _buildWidgetPreview(CountryProvider provider, List<Country> visitedList) {
    final continentTotals = {
      'Asia': 48, 'Europe': 44, 'Africa': 54,
      'North America': 23, 'South America': 12, 'Oceania': 14,
    };

    // 대륙별 통계 계산
    final stats = <String, int>{};
    for (final c in visitedList) {
      final continent = c.continent;
      if (continent == null || continent.isEmpty) continue;
      String mapped;
      if (continent.contains('Asia')) mapped = 'Asia';
      else if (continent.contains('Europe')) mapped = 'Europe';
      else if (continent.contains('Africa')) mapped = 'Africa';
      else if (continent == 'North America' || continent.contains('Caribbean') || continent.contains('Central America')) mapped = 'North America';
      else if (continent == 'South America') mapped = 'South America';
      else if (continent.contains('Oceania') || continent.contains('Australia')) mapped = 'Oceania';
      else mapped = continent;
      stats[mapped] = (stats[mapped] ?? 0) + 1;
    }

    final continentItems = [
      {'name': 'Asia', 'fullName': 'Asia', 'color': Colors.pink.shade300},
      {'name': 'Europe', 'fullName': 'Europe', 'color': Colors.yellow.shade700},
      {'name': 'Africa', 'fullName': 'Africa', 'color': Colors.brown.shade400},
      {'name': 'N. America', 'fullName': 'North America', 'color': Colors.blue.shade400},
      {'name': 'S. America', 'fullName': 'South America', 'color': Colors.green.shade400},
      {'name': 'Oceania', 'fullName': 'Oceania', 'color': Colors.purple.shade400},
    ];

    return Container(
      width: 600,
      height: 300,
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 지도 영역
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(-50, 0),
                    initialZoom: 0.3,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(urlTemplate: '', backgroundColor: Colors.white),
                    PolygonLayer(
                      polygons: provider.allCountries.expand((country) {
                        final isVisited = provider.visitedCountries.contains(country.name);
                        final color = isVisited
                            ? (provider.continentColors[country.continent] ?? Colors.grey)
                            : Colors.grey.withOpacity(0.15);
                        return country.polygonsData.map((polygonData) => Polygon(
                          points: polygonData.first,
                          holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                          color: color,
                          borderColor: Colors.white,
                          borderStrokeWidth: 0.5,
                          isFilled: true,
                        ));
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 통계 영역
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Travelog', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                      child: Text('${visitedList.length} Countries',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 대륙 그리드
                Expanded(
                  child: Column(
                    children: List.generate(3, (rowIdx) {
                      final left = continentItems[rowIdx * 2];
                      final right = continentItems[rowIdx * 2 + 1];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(child: _buildMiniStatItem(
                                left['name'] as String,
                                stats[left['fullName']] ?? 0,
                                continentTotals[left['fullName']] ?? 1,
                                left['color'] as Color,
                              )),
                              const SizedBox(width: 4),
                              Expanded(child: _buildMiniStatItem(
                                right['name'] as String,
                                stats[right['fullName']] ?? 0,
                                continentTotals[right['fullName']] ?? 1,
                                right['color'] as Color,
                              )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatItem(String name, int count, int total, Color color) {
    final ratio = (count / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          Text('$count/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: ratio, backgroundColor: Colors.grey.shade200, color: color, minHeight: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCategoryChip(BuildContext context, int index) {
    final item = statisticsItems[index];
    final isSelected = _selectedStatIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

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
              ? [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(
          item['icon'],
          color: isSelected ? Colors.white : Colors.grey.shade500,
          size: 22,
        ),
      ),
    );
  }

  // ⭐️ [리팩토링됨] 공유 버튼 클릭 시 실행
  Future<void> _handleShare(BuildContext context, CountryProvider provider) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      // 1. 현재 화면의 지도를 캡처합니다.
      final Uint8List? mapImage = await _mapScreenshotController.capture();

      if (mapImage == null) throw Exception("Failed to capture map");

      // 2. 방문 국가 데이터를 가져옵니다.
      final visitedCountries = provider.allCountries
          .where((c) => provider.visitedCountries.contains(c.name))
          .toList();

      if (!mounted) return;

      // 3. 분리된 파일(CountriesShare)의 기능을 호출하여 공유를 시작합니다.
      await CountriesShare.share(
        context: context,
        mapImage: mapImage,
        visitedCountries: visitedCountries,
      );

    } catch (e) {
      debugPrint("Main Screen Share Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ⭐️ 배경색을 흰색으로 변경 (이미지가 깨끗하게 보이도록)
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ⭐️ 배경 월페이퍼 이미지 추가
          Positioned.fill(
            child: Opacity(
              opacity: 0.3, // 아주 연하게 설정 (0.0 ~ 1.0 사이 값 조절)
              child: Image.asset(
                'assets/icons/app_wallpaper.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 기존 UI 내용 (SafeArea 포함)
          SafeArea(
            top: false,
            child: Consumer<CountryProvider>(
              builder: (context, provider, child) {
                // [수정] Provider 로딩 상태일 때 -> 꽉 찬 비디오 로딩 화면 출력 (Cities와 동일하게 변경)
                if (provider.isLoading) {
                  return const SizedBox.expand(
                    child: PlaneLoadingLogo(),
                  );
                }

                final countriesToDisplay = provider.filteredCountries;
                final totalCountries = countriesToDisplay.length;
                final visitedInFilter = countriesToDisplay
                    .where((c) => provider.visitedCountries.contains(c.name));
                final visitedCountriesCount = visitedInFilter.length;
                final countryRatio = totalCountries > 0 ? visitedCountriesCount / totalCountries : 0.0;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ========== 메인 지도 ==========
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
                              // 상단 통계 영역
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                                child: TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 2000),
                                  curve: Curves.easeOutCubic,
                                  tween: Tween<double>(begin: 0, end: countryRatio),
                                  builder: (context, double value, child) {
                                    return Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 30,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.location_on,
                                                            size: 14,
                                                            color: Theme.of(context).primaryColor,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'Countries',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: Theme.of(context).primaryColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        TweenAnimationBuilder(
                                                          duration: const Duration(milliseconds: 1500),
                                                          curve: Curves.easeOutExpo,
                                                          tween: Tween<double>(begin: 0, end: visitedCountriesCount.toDouble()),
                                                          builder: (context, double val, child) {
                                                            return ShaderMask(
                                                              shaderCallback: (bounds) => LinearGradient(
                                                                begin: Alignment.topLeft,
                                                                end: Alignment.bottomRight,
                                                                colors: [
                                                                  Theme.of(context).primaryColor,
                                                                  Theme.of(context).primaryColor.withOpacity(0.7),
                                                                ],
                                                              ).createShader(bounds),
                                                              child: Text(
                                                                '${val.toInt()}',
                                                                style: const TextStyle(
                                                                  fontSize: 64,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Colors.white,
                                                                  height: 0.9,
                                                                  letterSpacing: -3,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 8, left: 8),
                                                          child: Text(
                                                            '/ $totalCountries',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.grey.shade400,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              TweenAnimationBuilder(
                                                duration: const Duration(milliseconds: 1500),
                                                curve: Curves.easeOutExpo,
                                                tween: Tween<double>(begin: 0, end: value * 100),
                                                builder: (context, double val, child) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Theme.of(context).primaryColor,
                                                          Theme.of(context).primaryColor.withOpacity(0.8),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(16),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      '${val.toInt()}%',
                                                      style: const TextStyle(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          _AnimatedProgressBar(
                                            progress: value,
                                            primaryColor: Theme.of(context).primaryColor,
                                            totalCountries: totalCountries,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // 지도 영역
                              SizedBox(
                                height: 250,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 20,
                                      left: -50,
                                      right: -50,
                                      bottom: -80,
                                      child: Screenshot(
                                        controller: _mapScreenshotController,
                                        child: IgnorePointer(
                                          child: FlutterMap(
                                            options: const MapOptions(
                                              initialCenter: LatLng(0, 0),
                                              initialZoom: 0.3,
                                              interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                                            ),
                                            children: [
                                              TileLayer(urlTemplate: '', backgroundColor: Colors.white),
                                              PolygonLayer(
                                                polygons: provider.allCountries.expand((country) {
                                                  final isVisited = provider.visitedCountries.contains(country.name);
                                                  final color = isVisited
                                                      ? (provider.continentColors[country.continent] ?? Colors.grey)
                                                      : Colors.grey.withOpacity(0.15);
                                                  return country.polygonsData.map((polygonData) => Polygon(
                                                    points: polygonData.first,
                                                    holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                                                    color: color,
                                                    borderColor: Colors.white,
                                                    borderStrokeWidth: 0.5,
                                                    isFilled: true,
                                                  ));
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 우측 상단 버튼 그룹
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ⭐️ 공유 버튼
                                          GestureDetector(
                                            onTap: () => _handleShare(context, provider),
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
                                                  ? SizedBox(
                                                width: 26,
                                                height: 26,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                ),
                                              )
                                                  : Icon(
                                                Icons.share_rounded,
                                                color: Theme.of(context).primaryColor,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // 기존 추가 버튼
                                          GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const CountriesMapScreen()),
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).primaryColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).primaryColor.withOpacity(0.4),
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

                      // ========== Statistics 메뉴 ==========
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
                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        statisticsItems[_selectedStatIndex]['icon'],
                                        color: Theme.of(context).primaryColor,
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
                                            'View detailed statistics',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => statisticsItems[_selectedStatIndex]['screen'],
                                          ),
                                        ),
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
    );
  }
}

// 애니메이션 프로그레스 바
class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color primaryColor;
  final int totalCountries;

  const _AnimatedProgressBar({
    required this.progress,
    required this.primaryColor,
    required this.totalCountries,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        TweenAnimationBuilder(
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeOutExpo,
          tween: Tween<double>(begin: 0, end: progress),
          builder: (context, double value, child) {
            return Row(
              children: [
                Expanded(
                  flex: (value * 100).toInt(),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.6),
                          primaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1 - value) * 100).toInt() + 1,
                  child: const SizedBox(),
                ),
              ],
            );
          },
        ),
        TweenAnimationBuilder(
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeOutExpo,
          tween: Tween<double>(begin: 0, end: progress),
          builder: (context, double value, child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(0, -4),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ⭐️ 물결 페인터 및 기타 보조 클래스 (유지)
class _LiquidWavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color primaryColor;

  _LiquidWavePainter({
    required this.progress,
    required this.wavePhase,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseHeight = size.height * (1 - progress);

    // 첫 번째 물결
    final wave1Path = ui.Path();
    wave1Path.moveTo(0, size.height);
    wave1Path.lineTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi)) * 6 +
          math.sin((x / size.width * 4 * math.pi) + (wavePhase * 2 * math.pi * 1.5)) * 3;
      wave1Path.lineTo(x, y);
    }

    wave1Path.lineTo(size.width, size.height);
    wave1Path.close();

    final wave1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(wave1Path, wave1Paint);

    // 두 번째 물결
    final wave2Path = ui.Path();
    wave2Path.moveTo(0, size.height);
    wave2Path.lineTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi) + math.pi) * 4 +
          math.sin((x / size.width * 3 * math.pi) + (wavePhase * 2 * math.pi * 2)) * 2;
      wave2Path.lineTo(x, y);
    }

    wave2Path.lineTo(size.width, size.height);
    wave2Path.close();

    final wave2Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.7),
          primaryColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(wave2Path, wave2Paint);

    if (progress > 0.1) {
      final bubblePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final bubbleY = baseHeight + 15;
      if (bubbleY < size.height - 10) {
        canvas.drawCircle(
          Offset(20 + math.sin(wavePhase * 4 * math.pi) * 5, bubbleY),
          3,
          bubblePaint,
        );
        canvas.drawCircle(
          Offset(70 + math.cos(wavePhase * 3 * math.pi) * 8, bubbleY + 10),
          2,
          bubblePaint,
        );
        canvas.drawCircle(
          Offset(45 + math.sin(wavePhase * 5 * math.pi) * 6, bubbleY + 5),
          2.5,
          bubblePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.primaryColor != primaryColor;
  }
}