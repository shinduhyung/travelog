// lib/screens/flight_log_list_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/screens/add_flight_log_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FlightLogListScreen extends StatefulWidget {
  final String? highlightLogId;

  const FlightLogListScreen({
    super.key,
    this.highlightLogId,
  });

  @override
  State<FlightLogListScreen> createState() => _FlightLogListScreenState();
}

class _FlightLogListScreenState extends State<FlightLogListScreen> {
  final GlobalKey _targetKey = GlobalKey();
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.highlightLogId != null && _targetKey.currentContext != null) {
        if (!_hasScrolled) {
          Scrollable.ensureVisible(
            _targetKey.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
          _hasScrolled = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<AirlineProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple.shade700,
                      ),
                    );
                  }

                  final allLogs = provider.allFlightLogs;
                  if (allLogs.isEmpty) {
                    return  Center(
                      child: Text(
                        tr('No flight logs yet.\nTap the + button below to add one!'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    );
                  }

                  final connections = provider.flightConnections;
                  final logMap = {for (var log in allLogs) log.id: log};
                  final connectedLogIds =
                  connections.expand((c) => c.flightLogIds).toSet();

                  List<Widget> items = [];

                  // 1. 연결편 처리
                  for (final itinerary in connections) {
                    List<Widget> itineraryItems = [];
                    for (int i = 0; i < itinerary.flightLogIds.length; i++) {
                      final logId = itinerary.flightLogIds[i];
                      final log = logMap[logId];
                      if (log != null) {
                        Key? key;
                        if (widget.highlightLogId == log.id) {
                          key = _targetKey;
                        }

                        itineraryItems.add(
                          Container(
                            key: key,
                            child: _buildBoardingPassCard(context, log, provider),
                          ),
                        );

                        if (i < itinerary.connections.length) {
                          itineraryItems.add(
                            _buildConnectionInfoWidget(
                              itinerary.connections[i],
                            ),
                          );
                        }
                      }
                    }

                    if (itineraryItems.isNotEmpty) {
                      items.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(children: itineraryItems),
                        ),
                      );
                    }
                  }

                  // 2. 단독 비행 처리
                  final standaloneLogs = allLogs
                      .where((log) => !connectedLogIds.contains(log.id))
                      .toList();
                  for (final log in standaloneLogs) {
                    Key? key;
                    if (widget.highlightLogId == log.id) {
                      key = _targetKey;
                    }

                    items.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: Container(
                          key: key,
                          child: _buildBoardingPassCard(
                            context,
                            log,
                            provider,
                          ),
                        ),
                      ),
                    );
                  }

                  // 3. 렌더링 후 스크롤 로직 트리거
                  if (widget.highlightLogId != null && !_hasScrolled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_targetKey.currentContext != null) {
                        Scrollable.ensureVisible(
                          _targetKey.currentContext!,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                          alignment: 0.2,
                        );
                        _hasScrolled = true;
                      }
                    });
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return items[index];
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFlightLogScreen(),
            ),
          );
        },
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConnectionInfoWidget(ConnectionInfo info) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.connecting_airports,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            tr(info.type.toUpperCase()),
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (info.duration != null && info.duration!.trim().isNotEmpty)
            Text(
              tr(' (${info.duration})'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return Colors.deepPurple.shade700;
    }
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // 🎫 비행기 표 스타일 카드
  Widget _buildBoardingPassCard(
      BuildContext context, FlightLog log, AirlineProvider provider) {
    String displayDate = log.date;
    if (displayDate != 'Unknown') {
      try {
        final date = DateTime.parse(displayDate);
        displayDate = DateFormat.MMMd(AppLocale.instance.locale.languageCode).format(date);
      } catch (e) {}
    }

    final flightNumberUpper = log.flightNumber.toUpperCase();
    final displayFlightNumber =
    (flightNumberUpper == 'UNKNOWN' || flightNumberUpper.isEmpty)
        ? '-'
        : flightNumberUpper;

    final airline = provider.airlines.firstWhere(
          (a) => a.code == log.airlineCode,
      orElse: () => Airline(
        name: 'Unknown',
        code: '',
        themeColorHex: '#673AB7',
      ),
    );

    Color accentColor = _parseHexColor(airline.themeColorHex);
    String classSuffix = '';
    Color? borderColor;
    const double cardRadius = 12.0;

    IconData? classIcon;
    Color classTextColor = Colors.white;
    FontWeight classFontWeight = FontWeight.bold;
    Color classContainerColor = Colors.white.withOpacity(0.3);

    double borderWidth = 0.0;
    Color cardBackgroundColor = Colors.white;

    if (log.seatClass == 'First') {
      classSuffix = 'First Class';
      borderColor = Colors.pink.shade700;
      classIcon = Icons.diamond;
      classTextColor = Colors.pink.shade800;
      classFontWeight = FontWeight.w900;
      classContainerColor = Colors.white;
      borderWidth = 4.0;
      cardBackgroundColor = Colors.pink.shade50;
    } else if (log.seatClass == 'Business') {
      classSuffix = 'Business';
      borderColor = Colors.purple.shade700;
      classIcon = Icons.star_rate;
      classTextColor = Colors.purple.shade800;
      classContainerColor = Colors.white;
      borderWidth = 3.0;
      cardBackgroundColor = Colors.purple.shade50;
    } else if (log.seatClass == 'Premium Economy') {
      classSuffix = 'Premium Economy';
      classIcon = Icons.grade;
      classTextColor = Colors.white;
      classContainerColor = Colors.white.withOpacity(0.25);
    }

    final double innerRadius =
    (borderColor != null) ? cardRadius - borderWidth : cardRadius;

    // code3를 사용하여 avcodes_banners 경로 설정
    final String bannerCode = (airline.code3 != null && airline.code3!.isNotEmpty)
        ? airline.code3!
        : (log.airlineCode ?? 'unknown');
    final bannerPath = 'assets/avcodes_banners/$bannerCode.png';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddFlightLogScreen(initialLog: log, isEditing: true),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(cardRadius),
          border: borderColor != null
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(borderColor != null ? 0.2 : 0.1),
              blurRadius: borderColor != null ? 12 : 8,
              offset: Offset(0, borderColor != null ? 5 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Stack(
            children: [
              // 🔥 [수정] 배경 이미지 크기 및 fit 조정
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    // 크기가 줄어들어 존재감이 약해질 수 있으므로 투명도를 약간 올림 (0.12 -> 0.15)
                    opacity: 0.15,
                    child: Image.asset(
                      bannerPath,
                      // double.infinity 제거 및 고정 크기/비율 설정
                      width: 280, // 배너가 너무 넓게 퍼지지 않도록 제한
                      height: 180, // 배너 높이 제한
                      fit: BoxFit.contain, // 이미지가 잘리지 않고 전체가 다 보이도록 설정
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.flight_takeoff,
                          size: 120, // 에러 아이콘 크기도 적절히 조절
                          color: Colors.grey[300],
                        );
                      },
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 항공사 바
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: log.isCanceled
                          ? Colors.grey.shade400
                          : accentColor,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log.airlineName ?? 'Unknown Airline',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (classSuffix.isNotEmpty && !log.isCanceled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: classContainerColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                if (log.seatClass == 'First' ||
                                    log.seatClass == 'Business')
                                  BoxShadow(
                                    color: (log.seatClass == 'First'
                                        ? Colors.pink.shade200
                                        : Colors.purple.shade200)
                                        .withOpacity(0.7),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (classIcon != null)
                                  Icon(
                                    classIcon,
                                    size: 14,
                                    color: classTextColor,
                                  ),
                                if (classIcon != null) const SizedBox(width: 4),
                                Text(
                                  tr(classSuffix),
                                  style: TextStyle(
                                    fontSize:
                                    log.seatClass == 'First' ? 12 : 10,
                                    fontWeight: classFontWeight,
                                    color: classTextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 날짜 & 편명
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr(displayDate),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                tr(displayFlightNumber),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  decoration: log.isCanceled
                                      ? TextDecoration.lineThrough
                                      : null,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 출발 → 도착
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('DEPARTURE'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr(log.departureIata ?? 'N/A'),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: log.isCanceled
                                          ? Colors.grey.shade600
                                          : accentColor,
                                      decoration: log.isCanceled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (log.scheduledDepartureTime != null &&
                                      log.scheduledDepartureTime!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tr(log.scheduledDepartureTime!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  if (log.delay != null &&
                                      log.delay!.isNotEmpty &&
                                      log.delay != 'Unknown' &&
                                      !log.isCanceled) ...[
                                    Text(
                                      tr('+ ${log.delay}'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Icon(
                                    Icons.flight_takeoff,
                                    size: 24,
                                    color: accentColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 40,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor.withOpacity(0.1),
                                          accentColor.withOpacity(0.5),
                                          accentColor.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (log.duration != null &&
                                      log.duration!.isNotEmpty &&
                                      log.duration != 'Unknown') ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                          accentColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tr(log.duration!),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    tr('ARRIVAL'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr(log.arrivalIata ?? 'N/A'),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: log.isCanceled
                                          ? Colors.grey.shade600
                                          : accentColor,
                                      decoration: log.isCanceled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (log.scheduledArrivalTime != null &&
                                      log.scheduledArrivalTime!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tr(log.scheduledArrivalTime!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (!log.isCanceled) ...[
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                              children: [
                                _buildInfoColumn(
                                    'Terminal',
                                    log.departureTerminal,
                                    Icons.business),
                                _buildVerticalDivider(),
                                _buildInfoColumn('Gate', log.departureGate,
                                    Icons.sensors),
                                _buildVerticalDivider(),
                                _buildInfoColumn(
                                    'Arr. Terminal',
                                    log.arrivalTerminal,
                                    Icons.location_on),
                                _buildVerticalDivider(),
                                _buildInfoColumn(
                                    'Arr. Gate', log.arrivalGate, Icons.place),
                              ],
                            ),
                          ),

                          if (log.rating > 0) ...[
                            const SizedBox(height: 10),
                            RatingBar.builder(
                              initialRating: log.rating,
                              itemCount: 5,
                              itemSize: 20.0,
                              itemBuilder: (context, _) => Icon(
                                Icons.airplanemode_active,
                                color: Colors.amber.shade600,
                              ),
                              onRatingUpdate: (rating) {},
                              ignoreGestures: true,
                            ),
                          ],
                        ],

                        if (log.isCanceled) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(
                                color: Colors.red.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('CANCELED'),
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String? value, IconData icon) {
    final displayValue =
    (value != null && value.isNotEmpty && value != 'Unknown')
        ? value
        : '-';
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(height: 3),
        Text(
          tr(label),
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          tr(displayValue),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 35,
      color: Colors.grey.shade300,
    );
  }
}