// lib/screens/airline_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/screens/add_flight_log_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'flight_connection_screen.dart';

// Hex 색상 코드를 Color 객체로 변환하는 헬퍼 함수
Color colorFromHex(String? hexString, {Color fallback = Colors.green}) {
  if (hexString == null || hexString.isEmpty) {
    return fallback;
  }
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) {
    buffer.write('ff'); // 알파 채널(투명도) 추가
  }
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return fallback; // 변환 실패 시 기본 색상 반환
  }
}

class AirlineDetailScreen extends StatefulWidget {
  final String airlineName;

  const AirlineDetailScreen({super.key, required this.airlineName});

  @override
  State<AirlineDetailScreen> createState() => _AirlineDetailScreenState();
}

class _AirlineDetailScreenState extends State<AirlineDetailScreen> {
  final MaterialColor _mileageThemeColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Consumer<AirlineProvider>(
      builder: (context, airlineProvider, child) {
        Airline airline;
        try {
          airline = airlineProvider.airlines.firstWhere((a) => a.name == widget.airlineName);
        } catch (e) {
          return  Scaffold(body: Center(child: Text(tr("Airline not found."))));
        }

        final themeColor = colorFromHex(airline.themeColorHex, fallback: Colors.green.shade800);
        // 얼라이언스 정보 가져오기 (Provider에 정의된 맵 활용 가정, 없으면 null)
        final allianceName = airlineAlliances[airline.name];

        return Scaffold(
          backgroundColor: Colors.white,
          // 상단바(AppBar) 및 뒤로가기 버튼 완전히 제거
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 커스텀 헤더: 뒤로가기 삭제, 항공사 배너 로고 적용, FSC/LCC 배지 추가
                  _buildCustomHeader(airline, allianceName, themeColor),

                  const SizedBox(height: 16),

                  // 2. 평점 및 하트 버튼 (헤더 아래 배치)
                  Row(
                    children: [
                      RatingBar.builder(
                        initialRating: airline.rating,
                        minRating: 0,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 28,
                        itemPadding: const EdgeInsets.only(right: 4.0),
                        itemBuilder: (context, _) => Icon(Icons.star, color: themeColor),
                        onRatingUpdate: (rating) {
                          airlineProvider.updateAirlineRating(airline.name, rating);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          airline.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: airline.isFavorite ? Colors.redAccent : Colors.grey,
                          size: 28,
                        ),
                        onPressed: () {
                          airlineProvider.toggleFavoriteStatus(widget.airlineName);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 3. Flights 섹션 (스위치 제거, 바로 표시)
                  _buildFlightsContent(airline, airlineProvider, themeColor),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Divider(thickness: 1, height: 1),
                  ),

                  // 4. Mileage 섹션 (Flights 아래에 이어서 표시)
                  _buildMileageContent(airline, airlineProvider),

                  const SizedBox(height: 100), // FAB 공간 확보
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showActionOptions(context, airline),
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  // 헤더 위젯: 배너 이미지 적용, 뒤로가기 버튼 제거, FSC/LCC 배지 추가
  Widget _buildCustomHeader(Airline airline, String? allianceName, Color themeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // 텍스트가 여러 줄일 때 위쪽 정렬
      children: [
        // 1. 항공사 아이콘 배너
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Image.asset(
            'assets/avcodes_banners/${airline.code3}.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.flight,
                color: Colors.grey[300],
                size: 30,
              );
            },
          ),
        ),
        const SizedBox(width: 16),

        // 2. 항공사 이름 및 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름과 배지를 한 줄(Row)에 배치하고 양 끝으로 정렬
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      airline.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // FSC / LCC 배지 추가
                  _buildAirlineTypeBadge(airline.airlineType),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (allianceName != null) ...[
                    Text(
                      tr(allianceName),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                  Text(
                    tr('${airline.code} / ${airline.code3 ?? ""}'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 항공사 유형(FSC/LCC) 배지 위젯
  Widget _buildAirlineTypeBadge(String? type) {
    if (type == null || (type != 'FSC' && type != 'LCC')) {
      return const SizedBox.shrink();
    }

    Color color;
    String text;

    if (type == 'FSC') {
      color = const Color(0xFF2980B9); // 파란색
      text = "FSC";
    } else {
      color = const Color(0xFFF1C40F); // 노란색
      text = "LCC";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            tr(text),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 통합 액션 메뉴 (비행 기록 추가 + 마일리지 사용 옵션)
  void _showActionOptions(BuildContext context, Airline airline) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.flight_takeoff, color: Colors.blue),
                title:  Text(tr('Add Flight Log'), style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddFlightLogScreen(initialAirlineName: widget.airlineName)));
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.star, color: _mileageThemeColor),
                title:  Text(tr('Book Award Flight (Miles)')),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddFlightLogScreen(initialAirlineName: widget.airlineName, initialIsMileage: true)));
                },
              ),
              ListTile(
                leading: Icon(Icons.upgrade, color: _mileageThemeColor),
                title:  Text(tr('Upgrade Seat (Miles)')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFlightSelectionForUpgrade(context, airline.name);
                },
              ),
              ListTile(
                leading: Icon(Icons.shopping_bag_outlined, color: _mileageThemeColor),
                title:  Text(tr('Other Mileage Usage')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showOtherMileageUsageDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Flights 뷰 -> 컨텐츠 위젯 (스크롤 제거, 리스트 뷰 shrinkWrap 적용)
  Widget _buildFlightsContent(Airline airline, AirlineProvider airlineProvider, Color themeColor) {
    final sortedLogs = List<FlightLog>.from(airline.logs)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.date);
        final dateB = DateTime.tryParse(b.date);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

    final Set<String> processedItineraryIds = {};
    final totalCashSpent = airline.logs.where((l) {
      if (l.isCanceled || l.ticketPrice == null || l.isMileageTicket) return false;
      if (l.itineraryId != null) {
        if (processedItineraryIds.contains(l.itineraryId!)) return false;
        processedItineraryIds.add(l.itineraryId!);
      }
      return true;
    }).fold(0.0, (sum, l) => sum + l.ticketPrice!);

    final numberFormatter = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          tr('Flight Logs'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('Total Flights: ${airline.totalTimes}'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            Text(
              tr('Total Cash Spent: \$${numberFormatter.format(totalCashSpent)}'),
              style: TextStyle(fontSize: 16, color: themeColor.withOpacity(0.8), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (sortedLogs.isEmpty)
           Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(tr('No flight logs yet.'), style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedLogs.length,
            itemBuilder: (context, index) {
              final log = sortedLogs[index];
              return _buildFlightLogCard(context, log, airlineProvider, themeColor);
            },
          ),
      ],
    );
  }

  // Mileage 뷰 -> 컨텐츠 위젯 (스크롤 제거, 리스트 뷰 shrinkWrap 적용)
  Widget _buildMileageContent(Airline airline, AirlineProvider airlineProvider) {
    final numberFormatter = NumberFormat('#,##0');
    final allLogs = airlineProvider.allFlightLogs;

    List<Map<String, dynamic>> combinedUsageHistory = [];

    final mileageTickets = allLogs.where((l) {
      if (!l.isMileageTicket || l.ticketPrice == null || l.isCanceled) return false;
      final effectiveAirline = l.mileageAirline ?? l.airlineName;
      return effectiveAirline == airline.name;
    }).map((log) => {'date': DateTime.tryParse(log.date ?? ''), 'data': log, 'type': 'ticket'});
    combinedUsageHistory.addAll(mileageTickets);

    final otherUsages = airline.otherUsages.map((usage) => {'date': DateTime.tryParse(usage.date), 'data': usage, 'type': 'other'});
    combinedUsageHistory.addAll(otherUsages);

    final mileageUpgrades = allLogs.where((l) {
      if (!l.isUpgradedWithMiles || l.upgradePrice == null || l.isCanceled) return false;
      return l.upgradeMileageAirline == airline.name;
    }).map((log) => {'date': DateTime.tryParse(log.upgradeDate ?? ''), 'data': log, 'type': 'upgrade'});
    combinedUsageHistory.addAll(mileageUpgrades);

    combinedUsageHistory.removeWhere((item) => item['date'] == null);
    combinedUsageHistory.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    final double totalTicketMiles = combinedUsageHistory.where((i) => i['type'] == 'ticket').fold(0.0, (prev, i) {
      final log = i['data'] as FlightLog;
      if (log.itineraryId != null) {
        try {
          final itineraryFirstLogDate = airlineProvider.itineraries.firstWhere((it) => it.id == log.itineraryId).flightLogIds
              .map((id) => airlineProvider.getFlightLogById(id)).whereType<FlightLog>()
              .map((l) => DateTime.tryParse(l.date ?? '')).whereType<DateTime>().first;
          if (i['date'] == itineraryFirstLogDate) {
            return prev + (log.ticketPrice ?? 0.0);
          }
          return prev;
        } catch (e) {
          return prev + (log.ticketPrice ?? 0.0);
        }
      }
      return prev + (log.ticketPrice ?? 0.0);
    });
    final double totalUpgradeMiles = combinedUsageHistory.where((i) => i['type'] == 'upgrade').fold(0.0, (prev, i) => prev + ((i['data'] as FlightLog).upgradePrice ?? 0.0));
    final double totalOtherMiles = combinedUsageHistory.where((i) => i['type'] == 'other').fold(0.0, (prev, i) => prev + ((i['data'] as OtherMileageUsage).miles));
    final totalMileageSpent = totalTicketMiles + totalUpgradeMiles + totalOtherMiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
              tr('Mileage Program'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.grey.shade600),
              onPressed: () => _showEditMileageDialog(context, airlineProvider, airline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _mileageThemeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Current Balance'),
                style: TextStyle(fontSize: 14, color: _mileageThemeColor.shade700, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: _mileageThemeColor, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                  children: [
                    TextSpan(
                      text: tr(numberFormatter.format(airline.mileageBalance ?? 0)),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                     TextSpan(text: tr(' miles'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('Total Mileage Spent: ${numberFormatter.format(totalMileageSpent)} miles'),
          style: TextStyle(fontSize: 14, color: _mileageThemeColor[800], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Text(
          tr('Usage History'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _mileageThemeColor),
        ),
        const SizedBox(height: 8),
        if (combinedUsageHistory.isEmpty)
           Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_edu, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(tr('No mileage usage history yet.'), style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: combinedUsageHistory.length,
            itemBuilder: (context, index) {
              final item = combinedUsageHistory[index];
              final String type = item['type'];
              final dynamic data = item['data'];

              if (type == 'ticket') {
                return _buildMileageLogCard(data as FlightLog);
              }
              if (type == 'other') {
                return _buildOtherMileageUsageCard(data as OtherMileageUsage);
              }
              if (type == 'upgrade') {
                return _buildUpgradeUsageCard(data as FlightLog);
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  // --- 기존 다이얼로그 및 헬퍼 메서드 ---

  void _showEditMileageDialog(BuildContext context, AirlineProvider provider, Airline airline) {
    final mileageController = TextEditingController(text: airline.mileageBalance?.toStringAsFixed(0) ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:  Text(tr('Edit Mileage Balance')),
          content: TextField(
            controller: mileageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration:  InputDecoration(labelText: tr('Miles')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final newBalance = double.tryParse(mileageController.text);
                if (newBalance != null) {
                  provider.updateAirlineMileageBalance(airline.name, newBalance);
                }
                Navigator.pop(context);
              },
              child:  Text(tr('Save')),
            ),
          ],
        );
      },
    );
  }

  void _showMileageUsageOptions(BuildContext context, Airline airline) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.flight_takeoff, color: _mileageThemeColor),
                title:  Text(tr('Book a Flight with Miles')),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddFlightLogScreen(
                        initialAirlineName: widget.airlineName,
                        initialIsMileage: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.upgrade, color: _mileageThemeColor),
                title:  Text(tr('Upgrade a Seat')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFlightSelectionForUpgrade(context, airline.name);
                },
              ),
              ListTile(
                leading: Icon(Icons.shopping_bag_outlined, color: _mileageThemeColor),
                title:  Text(tr('Other Usage (Hotel, Shopping, etc.)')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showOtherMileageUsageDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFlightSelectionForUpgrade(BuildContext context, String currentAirlineName) {
    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final upgradeableClasses = ['Economy', 'Premium Economy', 'Business'];
    final allFlights = provider.allFlightLogs.where((log) => !log.isCanceled && upgradeableClasses.contains(log.seatClass)).toList();

    final flightsByCurrentAirline = allFlights.where((log) => log.airlineName == currentAirlineName).toList();
    final flightsByOtherAirlines = allFlights.where((log) => log.airlineName != currentAirlineName).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12))),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(tr('Select Flight to Upgrade'), style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      if (flightsByCurrentAirline.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(tr('Flights by $currentAirlineName'), style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final log = flightsByCurrentAirline[index];
                            return _buildFlightUpgradeTile(context, log, currentAirlineName);
                          },
                          childCount: flightsByCurrentAirline.length,
                        ),
                      ),
                      if (flightsByOtherAirlines.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                            child: Text(tr('Flights by Other Airlines'), style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final log = flightsByOtherAirlines[index];
                            return _buildFlightUpgradeTile(context, log, currentAirlineName);
                          },
                          childCount: flightsByOtherAirlines.length,
                        ),
                      ),
                      if (flightsByCurrentAirline.isEmpty && flightsByOtherAirlines.isEmpty)
                         SliverFillRemaining(
                          child: Center(child: Text(tr('No upgradeable flights found.'))),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFlightUpgradeTile(BuildContext context, FlightLog log, String defaultUpgradeAirline) {
    final isUpgraded = log.upgradePrice != null && log.upgradePrice! > 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
            children: [
              TextSpan(text: tr('${log.airlineName} ${log.flightNumber.isNotEmpty ? log.flightNumber : ""}(${log.departureIata} → ${log.arrivalIata})')),
              if (isUpgraded)
                 TextSpan(
                  text: tr(' (upgraded)'),
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                ),
            ],
          ),
        ),
        subtitle: Text('${log.date} ・ ${trSeatClass(log.seatClass)}'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFlightLogScreen(
                initialLog: log,
                isEditing: true,
                startWithUpgradeView: true,
                scrollToSection: 'Ticket',
                defaultUpgradeAirline: defaultUpgradeAirline,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOtherMileageUsageDialog(BuildContext context) {
    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final descriptionController = TextEditingController();
    final milesController = TextEditingController();
    final vatController = TextEditingController();
    String? selectedCategory;
    final categories = ['Lounge Usage', 'Excess Baggage', 'Taxes/Surcharges', 'Companion Ticket', 'Hotel', 'Rental Car / Transport', 'Shopping / Gifts', 'Point Conversion', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:  Text(tr('Log Other Mileage Usage')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration:  InputDecoration(labelText: tr('Date'), icon: Icon(Icons.calendar_today)),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                      if (picked != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    hint:  Text(tr('Category')),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(tr(c)))).toList(),
                    onChanged: (val) => selectedCategory = val,
                    validator: (val) => val == null ? 'Please select a category' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration:  InputDecoration(labelText: tr('Description'), icon: Icon(Icons.description)),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: milesController,
                    decoration:  InputDecoration(labelText: tr('Miles Used'), icon: Icon(Icons.star)),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: vatController,
                    decoration:  InputDecoration(labelText: tr('Additional Payment (USD)'), icon: Icon(Icons.monetization_on)),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:  Text(tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newUsage = OtherMileageUsage(
                    date: dateController.text,
                    description: descriptionController.text,
                    category: selectedCategory!,
                    miles: double.tryParse(milesController.text) ?? 0,
                    cashAmount: double.tryParse(vatController.text),
                  );
                  provider.addOtherMileageUsage(widget.airlineName, newUsage);
                  Navigator.pop(ctx);
                }
              },
              child:  Text(tr('Save')),
            )
          ],
        );
      },
    );
  }

  Widget _buildUpgradeUsageCard(FlightLog log) {
    final numberFormatter = NumberFormat('#,##0');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFlightLogScreen(
                initialLog: log,
                isEditing: true,
                scrollToSection: 'Ticket',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr('Upgrade: ${log.airlineName} ${log.flightNumber} (to ${trSeatClass(log.seatClass)})'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(tr(log.upgradeDate ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('Route: ${log.departureIata} → ${log.arrivalIata}'),
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.black87, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                        children: [
                          TextSpan(
                            text: tr('${numberFormatter.format(log.upgradePrice ?? 0)} miles'),
                            style: TextStyle(fontWeight: FontWeight.bold, color: _mileageThemeColor[700]),
                          ),
                          if (log.upgradeVat != null && log.upgradeVat! > 0)
                            TextSpan(
                              text: tr(' + \$${numberFormatter.format(log.upgradeVat)}'),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                            ),
                        ]
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMileageLogCard(FlightLog log) {
    final numberFormatter = NumberFormat('#,##0');
    final isDifferentOperator = log.airlineName != log.mileageAirline;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFlightLogScreen(
                initialLog: log,
                isEditing: true,
                scrollToSection: 'Ticket',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr('${log.departureIata} → ${log.arrivalIata}'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  Text(tr(log.date), style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 8),
              if (isDifferentOperator)
                Text(
                  tr('Operated by: ${log.airlineName}'),
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.black87, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                        children: [
                          TextSpan(
                            text: tr('${numberFormatter.format(log.ticketPrice ?? 0)} miles'),
                            style: TextStyle(fontWeight: FontWeight.bold, color: _mileageThemeColor[700]),
                          ),
                          if (log.vat != null && log.vat! > 0)
                            TextSpan(
                              text: tr(' + \$${numberFormatter.format(log.vat)}'),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                            ),
                        ]
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherMileageUsageCard(OtherMileageUsage usage) {
    final numberFormatter = NumberFormat('#,##0');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tr(usage.description),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Text(tr(usage.date), style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('Category: ${usage.category}'),
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                      style: TextStyle(fontSize: 16, color: Colors.black87, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                      children: [
                        TextSpan(
                          text: tr('${numberFormatter.format(usage.miles)} miles'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: _mileageThemeColor[700]),
                        ),
                        if (usage.cashAmount != null && usage.cashAmount! > 0)
                          TextSpan(
                            text: tr(' + \$${numberFormatter.format(usage.cashAmount)}'),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                          ),
                      ]
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFlightLogCard(BuildContext context, FlightLog log, AirlineProvider airlineProvider, Color themeColor) {
    return Card(
      color: log.isCanceled ? Colors.grey.shade300 : null,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFlightLogScreen(
                initialLog: log,
                isEditing: true,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr(log.flightNumber.isNotEmpty ? log.flightNumber : 'Unknown Flight'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        tr(log.date),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      IconButton(
                        padding: const EdgeInsets.only(left: 8, right: 0),
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.sync_alt, color: Colors.orange),
                        tooltip: tr('Connect Itinerary'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlightConnectionScreen(startNewItineraryWith: log),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (log.isCanceled)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Chip(
                    label:  Text(tr('CANCELED')),
                    backgroundColor: Colors.red.shade400,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 8),
              if (log.rating > 0)
                RatingBarIndicator(
                  rating: log.rating,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  itemCount: 5,
                  itemSize: 20.0,
                  direction: Axis.horizontal,
                ),
              const SizedBox(height: 8),
              Text(
                tr('${log.departureIata ?? 'N/A'} → ${log.arrivalIata ?? 'N/A'}'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
              ),
              const Divider(height: 20, thickness: 1),
              if (!log.isCanceled) ...[
                _buildLogDetailRow(Icons.access_time, 'Duration', log.duration ?? 'Unknown'),
                if (log.delay != null && log.delay!.isNotEmpty)
                  _buildLogDetailRow(Icons.warning_amber_rounded, 'Delay', log.delay!),
                const Divider(height: 20, thickness: 1),
              ],
              _buildLogDetailRow(Icons.airline_seat_recline_normal, 'Class', log.seatClass ?? 'Unknown'),
              _buildPriceDetailRow(log),
              _buildLogDetailRow(Icons.calendar_today_outlined, 'Booked', log.bookingDate ?? 'Unknown'),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    _confirmDeleteLog(context, log, airlineProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDetailRow(FlightLog log) {
    final numberFormatter = NumberFormat('#,##0');
    String value;
    final iconData = log.isMileageTicket ? Icons.star_border : Icons.monetization_on_outlined;

    if (log.ticketPrice != null) {
      if (log.isMileageTicket) {
        final priceText = '${numberFormatter.format(log.ticketPrice)} miles';
        final vatText = (log.vat != null && log.vat! > 0) ? ' (VAT: ${numberFormatter.format(log.vat)} USD)' : '';
        value = priceText + vatText;
      } else {
        value = '${numberFormatter.format(log.ticketPrice)} USD';
      }
    } else {
      value = 'Unknown';
    }

    return _buildLogDetailRow(iconData, 'Price', value);
  }

  Widget _buildLogDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(tr('$label: '), style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
          Expanded(child: Text(tr(value), style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.end,)),
        ],
      ),
    );
  }

  void _confirmDeleteLog(BuildContext context, FlightLog log, AirlineProvider airlineProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:  Text(tr('Delete Flight Log')),
          content: Text(tr('Are you sure you want to delete flight ${log.flightNumber} on ${log.date}?')),
          actions: <Widget>[
            TextButton(
              child:  Text(tr('Cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:  Text(tr('Delete'), style: TextStyle(color: Colors.white)),
              onPressed: () {
                airlineProvider.removeFlightLog(log);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(tr('Flight log deleted successfully!'))),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
