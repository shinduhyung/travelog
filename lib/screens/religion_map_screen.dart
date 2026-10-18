// lib/screens/religion_map_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/religion_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class ReligionMapScreen extends StatefulWidget {
  final String? religionFilter;
  final String? denominationFilter;

  const ReligionMapScreen({super.key, this.religionFilter, this.denominationFilter});

  @override
  State<ReligionMapScreen> createState() => _ReligionMapScreenState();
}

class _ReligionMapScreenState extends State<ReligionMapScreen> {
  bool _showDenominations = false;

  // ✅ 수정된 부분: Ibadi 색상 추가
  static const Color catholicColor = Color(0xFF795548);
  static const Color protestantColor = Colors.pinkAccent;
  static const Color orthodoxyColor = Color(0xFF4A004A);
  static const Color sunniColor = Color(0xFF98FB98);
  static const Color shiaColor = Color(0xFF808000);
  static const Color ibadiColor = Color(0xFF3CB371); // Ibadi 색상

  static const Color christianityColor = Colors.purple;
  static const Color islamColor = Colors.green;
  static const Color buddhismColor = Colors.orange;
  static const Color hinduismColor = Colors.red;
  static const Color judaismColor = Colors.blue;
  static const Color restColor = Colors.grey;

  Color _getColorForReligion(String religion) {
    switch (religion) {
      case 'Christianity': return christianityColor;
      case 'Islam': return islamColor;
      case 'Buddhism': return buddhismColor;
      case 'Hinduism': return hinduismColor;
      case 'Judaism': return judaismColor;
      default: return restColor;
    }
  }

  // ✅ 수정된 부분: _getColorForDenomination 함수에 Ibadi 케이스 추가
  Color _getColorForDenomination(String? denomination) {
    switch (denomination) {
      case 'Catholicism': return catholicColor;
      case 'Protestantism': return protestantColor;
      case 'Eastern Orthodoxy': return orthodoxyColor;
      case 'Sunni': return sunniColor;
      case 'Shia': return shiaColor;
      case 'Ibadi': return ibadiColor; // Ibadi 케이스
      default: return restColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);
    final religionProvider = Provider.of<ReligionProvider>(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultCountryColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400;

    if (countryProvider.isLoading || religionProvider.isLoading) {
      return Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator()));
    }

    final List<Polygon> allMapPolygons = [];
    for (var country in countryProvider.allCountries) {
      final religionInfo = religionProvider.religionDataMap[country.isoA3];
      final isVisited = countryProvider.visitedCountries.contains(country.name);

      Color finalColor = defaultCountryColor;

      if (religionInfo != null) {
        Color baseColor = defaultCountryColor;
        bool shouldBeColored = false;

        if (widget.denominationFilter != null) {
          if (religionInfo.denomination == widget.denominationFilter) {
            shouldBeColored = true;
            baseColor = _getColorForDenomination(religionInfo.denomination);
          }
        } else if (widget.religionFilter != null) {
          if (religionInfo.religion == widget.religionFilter) {
            shouldBeColored = true;
            if (_showDenominations) {
              baseColor = _getColorForDenomination(religionInfo.denomination);
            } else {
              baseColor = _getColorForReligion(religionInfo.religion);
            }
          }
        } else {
          shouldBeColored = true;
          if (_showDenominations && (religionInfo.religion == 'Christianity' || religionInfo.religion == 'Islam')) {
            baseColor = _getColorForDenomination(religionInfo.denomination);
          } else {
            baseColor = _getColorForReligion(religionInfo.religion);
          }
        }

        if (shouldBeColored) {
          finalColor = isVisited ? baseColor : baseColor.withOpacity(0.35);
        }
      }

      for (var polygonData in country.polygonsData) {
        if (polygonData.isNotEmpty && polygonData.first.length > 2) {
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
    }

    // 🚨 변경: 스위치 표시 여부 결정 (범례와 통합되도록)
    final bool showDenominationSwitch = widget.denominationFilter == null && (widget.religionFilter == null || widget.religionFilter == 'Christianity' || widget.religionFilter == 'Islam');

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(tr(widget.denominationFilter ?? widget.religionFilter ?? 'World Religions Map')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black, // 다크 모드/라이트 모드 제목 색상 조정
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 1.5,
              backgroundColor: backgroundColor,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              PolygonLayer(polygons: allMapPolygons),
            ],
          ),

          // 🚨 변경: 스위치와 범례를 우측 상단에 통합
          Positioned(
            top: 10,
            right: 10,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 종파 스위치 (필요할 경우)
                    if (showDenominationSwitch)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                            tr('Show Denominations'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _showDenominations,
                            onChanged: (value) => setState(() => _showDenominations = value),
                            activeColor: Theme.of(context).primaryColor,
                            // size 통일을 위해 SwitchListTile 대신 Switch와 Text를 조합
                          ),
                        ],
                      ),

                    if (showDenominationSwitch)
                      const Divider(height: 10, thickness: 1),

                    // 범례 표시
                    ...widget.denominationFilter != null
                        ? [_legendRow(_getColorForDenomination(widget.denominationFilter), widget.denominationFilter!)]
                        : (_showDenominations && showDenominationSwitch
                        ? _buildDenominationLegendRows(widget.religionFilter)
                        : _buildReligionLegendRows(widget.religionFilter)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReligionLegendRows(String? filter) {
    if (filter == null) {
      return [
        _legendRow(christianityColor, 'Christianity'),
        _legendRow(islamColor, 'Islam'),
        _legendRow(buddhismColor, 'Buddhism'),
        _legendRow(hinduismColor, 'Hinduism'),
        _legendRow(judaismColor, 'Judaism'),
      ];
    }
    return [_legendRow(_getColorForReligion(filter), filter)];
  }

  // ✅ 수정된 부분: _buildDenominationLegendRows 함수에 Ibadi 범례 추가
  List<Widget> _buildDenominationLegendRows(String? religionFilter) {
    List<Widget> christianityRows = [
      _legendRow(christianityColor, 'Christianity', isHeader: true),
      _legendRow(catholicColor, 'Catholicism', isIndented: true),
      _legendRow(protestantColor, 'Protestantism', isIndented: true),
      _legendRow(orthodoxyColor, 'Eastern Orthodoxy', isIndented: true),
    ];

    List<Widget> islamRows = [
      _legendRow(islamColor, 'Islam', isHeader: true),
      _legendRow(sunniColor, 'Sunni', isIndented: true),
      _legendRow(shiaColor, 'Shia', isIndented: true),
      _legendRow(ibadiColor, 'Ibadi', isIndented: true), // Ibadi 범례
    ];

    switch(religionFilter) {
      case 'Christianity':
        return christianityRows;
      case 'Islam':
        return islamRows;
      default:
        return [
          ...christianityRows,
          const SizedBox(height: 6),
          ...islamRows,
          const SizedBox(height: 6),
          _legendRow(buddhismColor, 'Buddhism'),
          _legendRow(hinduismColor, 'Hinduism'),
          _legendRow(judaismColor, 'Judaism'),
        ];
    }
  }

  Widget _legendRow(Color color, String name, {bool isHeader = false, bool isIndented = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 12.0 : 0, top: 2.0, bottom: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(
            tr(name),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}