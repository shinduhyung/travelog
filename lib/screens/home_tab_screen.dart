// lib/screens/home_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/badges_screen.dart';
import 'package:jidoapp/screens/calendar_screen.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/passport_screen.dart';
import 'package:jidoapp/screens/settings_screen.dart';
import 'package:jidoapp/screens/trip_dna_screen.dart';
import 'package:jidoapp/screens/trip_log_list_screen.dart';
import 'package:jidoapp/screens/my_trips_tab_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:jidoapp/providers/passport_provider.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  bool _isColorByVisits = false;

  static const List<Color> visitColors = [
    Color(0xFFADD8E6),
    Color(0xFF87CEEB),
    Color(0xFF1E90FF),
    Color(0xFF4169E1),
    Color(0xFF6A0DAD),
  ];

  Color _getColorByVisitCount(int count) {
    if (count <= 0) return Colors.grey.withOpacity(0.35);
    if (count >= 5) return visitColors[4];
    return visitColors[count - 1];
  }

  Color _getColorByContinent(String? continent) {
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

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = context.watch<CountryProvider>();
    final passportProvider = context.watch<PassportProvider>();
    final selectedPassportIso = passportProvider.selectedPassportIso;
    final passportImagePath = 'assets/passports/$selectedPassportIso.jpg';

    final seamlessBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title:  Text(tr('Jido')),
        elevation: 0,
        backgroundColor: seamlessBackgroundColor,
      ),
      // bottom: false로 설정하여 시스템 하단 영역까지 레이아웃을 확장
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Expanded를 사용하여 지도가 남은 모든 공간을 강제로 차지하게 함
            Expanded(
              child: countryProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: const LatLng(25, 0),
                      initialZoom: 0.5,
                      backgroundColor: seamlessBackgroundColor,
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(
                          const LatLng(-85, -180),
                          const LatLng(85, 180),
                        ),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: '',
                        backgroundColor: Colors.transparent,
                      ),
                      PolygonLayer(
                        polygons:
                        countryProvider.allCountries.expand((country) {
                          final details =
                          countryProvider.visitDetails[country.name];
                          final isVisited = details != null;
                          Color polygonColor;

                          if (_isColorByVisits) {
                            if (details?.hasLived ?? false) {
                              polygonColor = Colors.black;
                            } else {
                              final visitCount = details?.visitCount ?? 0;
                              polygonColor =
                                  _getColorByVisitCount(visitCount);
                            }
                          } else {
                            final color =
                            _getColorByContinent(country.continent);
                            polygonColor = isVisited
                                ? color
                                : Colors.grey.withOpacity(0.35);
                          }

                          return country.polygonsData.map((polygonData) {
                            return Polygon(
                              points: polygonData.first,
                              holePointsList: polygonData.length > 1
                                  ? polygonData.sublist(1)
                                  : null,
                              color: polygonColor,
                              borderColor: isVisited
                                  ? Colors.black45
                                  : Colors.white70,
                              borderStrokeWidth: 0.5,
                              isFilled: true,
                            );
                          });
                        }).toList(),
                      ),
                    ],
                  ),
                  // 지도 위 스위치 버튼
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                             Text(
                              tr('By Visits'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                            Switch(
                              value: _isColorByVisits,
                              onChanged: (value) {
                                setState(() {
                                  _isColorByVisits = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 하단 패널 (화면 최하단에 위치, 내비게이션 바 위에 배치)
            Container(
              height: 250,
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 95), // 내비게이션 바 높이만큼 bottom padding 추가
              color: seamlessBackgroundColor,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalHeight = constraints.maxHeight - 95; // bottom padding 제외
                  final totalWidth = constraints.maxWidth;

                  // 여권 이미지 비율에 맞춘 너비 계산
                  final passportWidth = totalWidth * 0.38;
                  final calendarWidth = totalWidth - passportWidth - 16;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 캘린더 (왼쪽)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CalendarScreen()),
                          );
                        },
                        child: Container(
                          width: calendarWidth,
                          height: totalHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: AbsorbPointer(
                            child: TableCalendar(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: DateTime.now(),
                              rowHeight: 22.0,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(fontSize: 12.0),
                                headerPadding: EdgeInsets.only(bottom: 4),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(fontSize: 9.0),
                                weekendStyle: TextStyle(
                                    fontSize: 9.0, color: Colors.redAccent),
                              ),
                              calendarStyle: const CalendarStyle(
                                defaultTextStyle: TextStyle(fontSize: 9.0),
                                weekendTextStyle: TextStyle(fontSize: 9.0),
                                outsideTextStyle: TextStyle(
                                    fontSize: 9.0, color: Colors.grey),
                                todayDecoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                todayTextStyle: TextStyle(
                                    fontSize: 9.0, color: Colors.white),
                                selectedDecoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                selectedTextStyle: TextStyle(
                                    fontSize: 9.0, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 여권 및 버튼 (오른쪽)
                      SizedBox(
                        width: passportWidth,
                        height: totalHeight,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 7,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const MyTripsTabScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(2, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                          child: Image.asset(
                                            passportImagePath,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                            const Icon(Icons
                                                .image_not_supported),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                       Text(
                                        tr('My Trips'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const BadgesScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        Colors.deepPurple.shade400,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        padding: EdgeInsets.zero,
                                        elevation: 3,
                                      ),
                                      child:  Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.emoji_events, size: 20),
                                          Text(tr('Badges'),
                                              style: TextStyle(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                              const SettingsScreen()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade800,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        padding: EdgeInsets.zero,
                                        elevation: 3,
                                      ),
                                      child:  Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.settings, size: 20),
                                          Text(tr('Set'),
                                              style: TextStyle(fontSize: 10)),
                                        ],
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