import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/language_data_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/language_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// isDominant 헬퍼 함수
bool isDominant(String language, Country country) {
  const nonDominantMap = {
    'English': {'CMR', 'SGP', 'CAN', 'ZAF'},
    'Chinese': {'MYS', 'SGP'},
    'Spanish': {'BLZ', 'GNQ'},
    'French': {'BEL', 'CMR', 'CAN', 'LUX', 'CHE'},
    'Arabic': {'DZA', 'IRQ', 'MAR', 'TUN'},
    'Portuguese': {'AGO', 'GNB', 'MOZ', 'TLS'},
    'German': {'CHE', 'LUX'},
  };

  if (language == 'Dutch') return country.isoA3 == 'NLD';
  if (language == 'Russian') return country.isoA3 == 'RUS';
  if (nonDominantMap.containsKey(language)) {
    return !nonDominantMap[language]!.contains(country.isoA3);
  }
  return true;
}


class LanguageMapScreen extends StatefulWidget {
  final String? languageFilter;
  const LanguageMapScreen({super.key, this.languageFilter});

  @override
  State<LanguageMapScreen> createState() => _LanguageMapScreenState();
}

class _LanguageMapScreenState extends State<LanguageMapScreen> {
  // ✅ 수정된 부분: Dutch, Chinese 색상 변경
  final Map<String, Color> _legendData = {
    'English': const Color(0xFFA0522D),
    'French': const Color(0xFF000080),
    'Spanish': const Color(0xFFFFD700),
    'Portuguese': const Color(0xFF87CEEB),
    'Arabic': const Color(0xFF2E8B57),
    'Russian': const Color(0xFF2F4F4F),
    'Chinese': const Color(0xFFFF0000), // 빨간색
    'German': const Color(0xFF9966CC),
    'Dutch': const Color(0xFFFFA500), // 주황색
  };

  bool _includeNonDominant = true;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _includeNonDominant = prefs.getBool('includeNonDominantLanguages') ?? true;
        _isLoadingSettings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (countryProvider.isLoading || languageProvider.isLoading || _isLoadingSettings) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Polygon> allMapPolygons = [];
    for (var country in countryProvider.allCountries) {
      final isVisited = countryProvider.visitedCountries.contains(country.name);
      final langData = languageProvider.languageDataMap[country.isoA3];
      Color polygonColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400;

      if (langData != null && langData.languages.isNotEmpty) {
        LanguageInfo? langToDraw;
        bool shouldDraw = false;

        if (widget.languageFilter != null) {
          try {
            langToDraw = langData.languages.firstWhere((l) => l.language == widget.languageFilter);
            if (_includeNonDominant || isDominant(langToDraw.language, country)) {
              shouldDraw = true;
            }
          } catch (e) {
            langToDraw = null;
          }
        } else {
          langToDraw = langData.languages.first;
          if (_includeNonDominant || isDominant(langToDraw.language, country)) {
            shouldDraw = true;
          }
        }

        if (shouldDraw && langToDraw != null) {
          polygonColor = isVisited ? langToDraw.color : langToDraw.color.withOpacity(0.4);
        }
      }

      for (var polygonData in country.polygonsData) {
        if (polygonData.isNotEmpty && polygonData.first.length > 2) {
          allMapPolygons.add(Polygon(
            points: polygonData.first,
            holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
            color: polygonColor,
            borderColor: Colors.white.withOpacity(0.2),
            borderStrokeWidth: 0.5,
            isFilled: true,
          ));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.languageFilter ?? 'World Language Map'))),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 1.5,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(const LatLng(-90, -180), const LatLng(90, 180)),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              PolygonLayer(polygons: allMapPolygons),
            ],
          ),
          _buildMapLegend(context),
        ],
      ),
    );
  }

  Widget _buildMapLegend(BuildContext context) {
    final List<String> languagesToShow = widget.languageFilter != null
        ? [_capitalize(widget.languageFilter!)]
        : _legendData.keys.toList();

    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          maxWidth: 180,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: languagesToShow.map((lang) {
              final color = _legendData[lang];
              if (color == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: color),
                    const SizedBox(width: 8),
                    Text(
                      tr(lang),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}