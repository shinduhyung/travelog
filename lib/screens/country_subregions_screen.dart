// lib/screens/country_subregions_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/subregion_model.dart'; // 🆕 지도 모델 임포트
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:latlong2/latlong.dart'; // 🆕 지도 관련 임포트
import 'package:provider/provider.dart';
import 'dart:convert'; // 🆕 지도 관련 임포트
import 'dart:developer' as developer; // 🆕 지도 관련 임포트

// 🆕 StatefulWidget으로 변경 (지도 데이터 로딩을 위해)
class CountrySubregionsScreen extends StatefulWidget {
  final Country country;

  const CountrySubregionsScreen({super.key, required this.country});

  @override
  State<CountrySubregionsScreen> createState() => _CountrySubregionsScreenState();
}

class _CountrySubregionsScreenState extends State<CountrySubregionsScreen> {
  // --- 🆕 지도 관련 상태 변수 ---
  final MapController _mapController = MapController();
  bool _isLoadingMap = true;
  List<Subregion> _subregionsData = [];
  LatLngBounds _bounds = LatLngBounds(const LatLng(24.39, -125.00), const LatLng(49.38, -66.93)); // 미국 본토 기본
  // --- -------------------- ---

  // 🆕 체크리스트에 표시될 주(State) 목록
  late final List<String> _subregionNameList;

  @override
  void initState() {
    super.initState();
    // 🆕 체크리스트 목록을 먼저 가져옴
    _subregionNameList = _getPlaceholderSubregions(widget.country.isoA3);

    // 🆕 지도 데이터를 비동기 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubregionGeoJson();
    });
  }

  // 🆕 subregion_map_screen.dart 에서 가져온 지도 데이터 로딩 로직
  Future<void> _loadSubregionGeoJson() async {
    if (!mounted) return;
    setState(() => _isLoadingMap = true);

    String assetPath;
    if (widget.country.isoA3 == 'USA') {
      assetPath = 'assets/us_states.geo.json';
    } else {
      developer.log('No map data for ${widget.country.isoA3}', name: 'SubregionMapScreen');
      setState(() => _isLoadingMap = false);
      return;
    }

    try {
      final String jsonStr = await rootBundle.loadString(assetPath);
      final data = json.decode(jsonStr);
      final features = data['features'] as List<dynamic>;

      _subregionsData = features.map((f) => Subregion.fromJson(f as Map<String, dynamic>)).toList();

      if (_subregionsData.isNotEmpty) {
        // 🚨 주의: GeoJSON에 포함되지 않은 'District of Columbia'는 제외하고 본토 경계만 계산합니다.
        final allPoints = _subregionsData
            .where((s) => s.name != 'Alaska' && s.name != 'Hawaii' && s.name != 'Puerto Rico') // 본토 경계만 계산
            .expand((s) => s.polygonsData)
            .expand((p) => p)
            .expand((r) => r);
        if (allPoints.isNotEmpty) {
          _bounds = LatLngBounds.fromPoints(allPoints.toList());
        }
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _bounds,
          padding: const EdgeInsets.all(25.0),
        ),
      );

    } catch (e) {
      developer.log('Error loading subregion GeoJSON: $e', name: 'SubregionMapScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error loading map data: $e. Make sure $assetPath exists.'))),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoadingMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 🆕 SubregionProvider를 사용하여 상태 관리 (Consumer는 지도와 리스트에서 각각 사용)
    final subregionProvider = Provider.of<SubregionProvider>(context, listen: false);

    if (subregionProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(widget.country.name))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_subregionNameList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(widget.country.name))),
        body:  Center(child: Text(tr('No subregion data available.'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.country.name)),
      ),
      // 🆕 Stack을 사용하여 지도를 배경에, 체크리스트를 위에 띄움
      body: Stack(
        children: [
          // --- 1. 지도 (배경) ---
          Consumer<SubregionProvider>(
            builder: (context, provider, child) {
              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  PolygonLayer(
                    polygons: _subregionsData.map((subregion) {
                      // GeoJSON의 이름(e.g. "California")과 체크리스트의 이름이 일치해야 함
                      final isVisited = provider.isSubregionVisited(
                        widget.country.isoA3,
                        subregion.name,
                      );

                      final color = isVisited
                          ? Colors.blue.shade400
                          : Colors.grey.withOpacity(0.35);

                      return subregion.polygonsData.map((polygonData) {
                        return Polygon(
                          points: polygonData.first,
                          holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                          color: color,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.0,
                          isFilled: true,
                        );
                      }).toList();
                    }).expand((list) => list).toList(),
                  ),
                ],
              );
            },
          ),

          // --- 2. 로딩 인디케이터 (지도 로딩 중에만) ---
          if (_isLoadingMap)
            const Center(child: CircularProgressIndicator()),

          // --- 3. 체크리스트 (오른쪽 아래) ---
          Positioned(
            bottom: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: 250, // 너비 고정
                height: 350, // 높이 고정
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        tr('Visited States'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    // 🆕 리스트가 스크롤되도록 Expanded로 감쌈
                    Expanded(
                      // 🆕 Provider의 변경 사항을 감지하도록 Consumer 사용
                      child: Consumer<SubregionProvider>(
                          builder: (context, provider, child) {
                            return ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _subregionNameList.length,
                              itemBuilder: (context, index) {
                                final subregionName = _subregionNameList[index];
                                final isVisited = provider.isSubregionVisited(
                                    widget.country.isoA3,
                                    subregionName
                                );

                                return CheckboxListTile(
                                  title: Text(subregionName),
                                  value: isVisited,
                                  dense: true, // 🆕 더 촘촘하게
                                  controlAffinity: ListTileControlAffinity.leading, // 🆕 체크박스를 앞으로
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  onChanged: (bool? value) {
                                    // 체크박스를 누르면 상태 변경 (listen: false)
                                    subregionProvider.toggleVisitedStatus(
                                        widget.country.isoA3,
                                        subregionName
                                    );
                                  },
                                );
                              },
                            );
                          }
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 임시 데이터 함수.
  // 🚨 참고: GeoJSON 파일의 'name' 속성과 이 목록의 이름이 정확히 일치해야 합니다.
  List<String> _getPlaceholderSubregions(String countryIsoA3) {
    switch (countryIsoA3) {
      case 'USA':
      // 🆕 'District of Columbia'는 현재 GeoJSON 파일에 포함되어 있지 않으므로 제외했습니다.
        return ['Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'];
      case 'KOR':
        return ['Seoul', 'Busan', 'Daegu', 'Incheon', 'Gwangju', 'Daejeon', 'Ulsan', 'Sejong', 'Gyeonggi-do', 'Gangwon-do', 'Chungcheongbuk-do', 'Chungcheongnam-do', 'Jeollabuk-do', 'Jeollanam-do', 'Gyeongsangbuk-do', 'Gyeongsangnam-do', 'Jeju'];
      case 'CAN':
        return ['Alberta', 'British Columbia', 'Manitoba', 'New Brunswick', 'Newfoundland and Labrador', 'Nova Scotia', 'Ontario', 'Prince Edward Island', 'Quebec', 'Saskatchewan', 'Northwest Territories', 'Nunavut', 'Yukon'];
      case 'JPN':
        return ['Hokkaido', 'Aomori', 'Iwate', 'Miyagi', 'Akita', 'Yamagata', 'Fukushima', 'Ibaraki', 'Tochigi', 'Gunma', 'Saitama', 'Chiba', 'Tokyo', 'Kanagawa', 'Niigata', 'Toyama', 'Ishikawa', 'Fukui', 'Yamanashi', 'Nagano', 'Gifu', 'Shizuoka', 'Aichi', 'Mie', 'Shiga', 'Kyoto', 'Osaka', 'Hyogo', 'Nara', 'Wakayama', 'Tottori', 'Shimane', 'Okayama', 'Hiroshima', 'Yamaguchi', 'Tokushima', 'Kagawa', 'Ehime', 'Kochi', 'Fukuoka', 'Saga', 'Nagasaki', 'Kumamoto', 'Oita', 'Miyazaki', 'Kagoshima', 'Okinawa'];
      default:
        return []; // 데이터가 없는 경우 빈 리스트 반환
    }
  }
}
