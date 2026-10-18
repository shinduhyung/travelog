// lib/screens/language_family_map_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/language_family_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

// Enum 값은 내부 로직용으로 유지
enum LanguageMapView { family, subbranch, subsubbranch }

class LanguageFamilyMapScreen extends StatefulWidget {
  final String? familyFilter;
  final String? subbranchFilter; // ✅ JSON 키와 동일하게 유지
  final String? subsubbranchFilter; // ✅ JSON 키와 동일하게 유지

  const LanguageFamilyMapScreen({
    super.key,
    this.familyFilter,
    this.subbranchFilter, // ✅ JSON 키와 동일하게 유지
    this.subsubbranchFilter, // ✅ JSON 키와 동일하게 유지
  });

  @override
  State<LanguageFamilyMapScreen> createState() => _LanguageFamilyMapScreenState();
}

class _LanguageFamilyMapScreenState extends State<LanguageFamilyMapScreen> {
  LanguageMapView _mapView = LanguageMapView.family;

  String _getAppBarTitle() {
    // 필터 이름은 JSON 키와 동일하게 사용
    if (widget.subsubbranchFilter != null) return widget.subsubbranchFilter!;
    if (widget.subbranchFilter != null) return widget.subbranchFilter!;
    if (widget.familyFilter != null) return widget.familyFilter!;
    return 'Asia-Europe Language Families';
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = context.watch<CountryProvider>();
    final langFamilyProvider = context.watch<LanguageFamilyProvider>();
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultCountryColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400;

    if (countryProvider.isLoading || langFamilyProvider.isLoading) {
      return Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator()));
    }

    final List<Polygon> allMapPolygons = [];
    // ✅ 3. 그룹화된 범례를 위한 새 데이터 구조
    // Map<ParentName, Map<ItemName, ItemColor>>
    final Map<String, Map<String, Color>> groupedLegend = {};

    for (var country in countryProvider.allCountries) {
      final langInfo = langFamilyProvider.languageFamilyDataMap[country.isoA3];
      Color finalColor = defaultCountryColor;

      if (langInfo != null) {
        bool passesFilter = (widget.familyFilter == null || langInfo.family == widget.familyFilter) &&
            (widget.subbranchFilter == null || langInfo.subbranch == widget.subbranchFilter) &&
            (widget.subsubbranchFilter == null || langInfo.subsubbranch == widget.subsubbranchFilter);

        if (passesFilter) {
          String key;
          String parentKey; // ✅ 3. 부모 키 추가
          Map<String, Color> colorMap;

          switch (_mapView) {
            case LanguageMapView.family:
              key = langInfo.family;
              parentKey = 'Families'; // 최상위 레벨은 공통 키 사용
              colorMap = langFamilyProvider.familyColors;
              break;
            case LanguageMapView.subbranch:
              key = langInfo.subbranch;
              parentKey = langInfo.family; // 부모 = Family
              colorMap = langFamilyProvider.subbranchColors;
              break;
            case LanguageMapView.subsubbranch:
              key = langInfo.subsubbranch;
              parentKey = langInfo.subbranch; // 부모 = Branch
              colorMap = langFamilyProvider.subsubbranchColors;
              break;
          }

          if (colorMap.containsKey(key)) {
            finalColor = colorMap[key]!;
            // ✅ 3. N/A가 아닌 항목만 그룹화된 범례에 추가
            if (key != 'N/A' && parentKey != 'N/A') {
              groupedLegend.putIfAbsent(parentKey, () => {});
              groupedLegend[parentKey]![key] = finalColor;
            }
          } else {
            finalColor = Colors.grey.shade400;
          }
        }
      }

      for (var polygonData in country.polygonsData) {
        allMapPolygons.add(Polygon(
          points: polygonData.first,
          holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
          color: finalColor,
          borderColor: backgroundColor,
          borderStrokeWidth: 0.5,
          isFilled: true,
        ));
      }
    }

    // ✅ 3. 범례 위젯 생성을 위해 부모 키 정렬
    final sortedParentKeys = groupedLegend.keys.toList()..sort();
    final headerColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: Text(tr(_getAppBarTitle()))),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
                initialCenter: const LatLng(45, 40),
                initialZoom: 2.5,
                backgroundColor: backgroundColor,
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                )
            ),
            children: [
              PolygonLayer(polygons: allMapPolygons),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SegmentedButton<LanguageMapView>(
                  segments:  [
                    ButtonSegment(value: LanguageMapView.family, label: Text(tr('Family'))),
                    ButtonSegment(value: LanguageMapView.subbranch, label: Text(tr('Branch'))),
                    ButtonSegment(value: LanguageMapView.subsubbranch, label: Text(tr('Subbranch'))),
                  ],
                  selected: {_mapView},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _mapView = newSelection.first;
                    });
                  },
                  // ✅ 1. 체크 아이콘 제거
                  showSelectedIcon: false,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Card(
              elevation: 4,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  // ✅ 3. 그룹화된 범례 위젯 빌드
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: sortedParentKeys.map((parentKey) {
                      final items = groupedLegend[parentKey]!;
                      final sortedItemEntries = items.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0), // 그룹 간 간격
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Family 뷰가 아닐 때만 부모 그룹 헤더 표시
                            if (_mapView != LanguageMapView.family)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                                child: Text(
                                  tr(parentKey),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: headerColor,
                                  ),
                                ),
                              ),
                            // 그룹에 속한 항목들
                            ...sortedItemEntries.map((entry) => _legendRow(entry.value, entry.key)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(tr(name), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}