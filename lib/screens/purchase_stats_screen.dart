// lib/screens/purchase_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jidoapp/screens/add_flight_log_screen.dart';

class PurchaseStatsScreen extends StatefulWidget {
  const PurchaseStatsScreen({super.key});

  @override
  State<PurchaseStatsScreen> createState() => _PurchaseStatsScreenState();
}

class _PurchaseStatsScreenState extends State<PurchaseStatsScreen> {
  // --- 상태 변수 정의 ---
  // 디자인 통일을 위해 Primary Color 정의 (기존 Amber 유지하되 가독성 위해 shade800 사용)
  final Color _primaryColor = Colors.amber.shade800;

  final List<String> _periods = ['Last 30 Days', 'Last 365 Days', 'Year', 'All Time', 'Custom'];
  String _selectedPeriod = 'All Time';
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  String _selectedPurchaseType = 'Cash';
  bool _showRanking = false;

  String _mileageRankingMode = 'Amount';
  String _mileageRankingAttribution = 'Operating';
  bool _groupByItinerary = true;

  // 연간 트렌드 차트 상태 변수
  String _lineChartType = 'Cash';
  bool _lineChartIncludeVat = true;

  // 데이터 처리 결과 저장
  int? _touchedIndex = -1;
  Map<String, int> _purchaseCounts = {};
  int _totalItemsInPeriod = 0;
  double _totalCashSpent = 0.0;
  double _totalMileageUsed = 0.0;
  double _totalMileageVat = 0.0;

  List<FlightLog> _filteredLogsForView = [];
  List<Map<String, dynamic>> _rankedAirlines = [];
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0;

  final Map<String, Map<String, dynamic>> _purchaseTypeInfo = {
    'Cash': {'color': Colors.amber.shade700, 'name': 'Cash', 'abbr': 'Cash'},
    'Mileage': {'color': Colors.tealAccent.shade400, 'name': 'Mileage', 'abbr': 'Mileage'},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData();
  }

  // --- 데이터 처리 로직 (기존 로직 유지) ---
  void _prepareData() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = airlineProvider.allFlightLogs;

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Last 30 Days':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'Last 365 Days':
        startDate = now.subtract(const Duration(days: 365));
        endDate = now;
        break;
      case 'Year':
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case 'Custom':
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
      case 'All Time':
      default:
        break;
    }

    final logsInPeriod = allLogs.where((log) {
      if (log.isCanceled) return false;
      if (_selectedPeriod == 'All Time') return true;

      DateTime? logDate;
      final dateToFilter = log.bookingDate ?? log.date;
      if (dateToFilter != 'Unknown' && dateToFilter.isNotEmpty) {
        try {
          logDate = DateTime.parse(dateToFilter);
        } catch (e) { logDate = null; }
      }

      if (logDate == null) return false;

      if (startDate != null && logDate.isBefore(startDate)) return false;
      if (endDate != null && logDate.isAfter(endDate)) return false;

      return true;
    }).toList();

    final Set<String> processedItineraryIds = {};
    final Map<String, int> purchaseCounts = {'Cash': 0, 'Mileage': 0};

    if (_groupByItinerary) {
      for (var log in logsInPeriod) {
        if (log.itineraryId != null) {
          if (processedItineraryIds.contains(log.itineraryId!)) continue;
          processedItineraryIds.add(log.itineraryId!);
          purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] = (purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] ?? 0) + 1;
        } else {
          purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] = (purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] ?? 0) + log.times;
        }
      }
    } else {
      for (var log in logsInPeriod) {
        purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] = (purchaseCounts[log.isMileageTicket ? 'Mileage' : 'Cash'] ?? 0) + log.times;
      }
    }

    double totalCash = 0.0;
    double totalMileage = 0.0;
    double totalVatForMileage = 0.0;
    processedItineraryIds.clear();

    for (var log in logsInPeriod) {
      bool isStandalone = log.itineraryId == null;
      bool isFirstInItinerary = false;
      if (!isStandalone) {
        if (!processedItineraryIds.contains(log.itineraryId!)) {
          processedItineraryIds.add(log.itineraryId!);
          isFirstInItinerary = true;
        }
      }

      if (isStandalone || isFirstInItinerary) {
        if (log.isMileageTicket) {
          totalMileage += log.ticketPrice ?? 0.0;
          totalVatForMileage += log.vat ?? 0.0;
        } else {
          totalCash += (log.ticketPrice ?? 0.0);
        }

        if (log.upgradePrice != null) {
          if (log.isUpgradedWithMiles) {
            totalMileage += log.upgradePrice!;
            totalVatForMileage += log.upgradeVat ?? 0.0;
          } else {
            totalCash += (log.upgradePrice ?? 0.0);
          }
        }
      }
    }

    int totalItems = purchaseCounts.values.fold<int>(0, (a, b) => a + b);

    final logsForView = logsInPeriod.where((log) {
      final isMileage = log.isMileageTicket;
      if (_selectedPurchaseType == 'Mileage' ? !isMileage : isMileage) return false;
      if (log.airlineName == 'Unknown' || log.airlineName == null) return false;

      double price = log.ticketPrice ?? 0.0;
      if (log.upgradePrice != null) {
        if (_selectedPurchaseType == 'Cash' && !log.isUpgradedWithMiles) {
          price += log.upgradePrice!;
        } else if (_selectedPurchaseType == 'Mileage' && log.isUpgradedWithMiles) {
          price += log.upgradePrice!;
        }
      }
      return price > 0;
    }).toList();


    final Map<String, Map<String, dynamic>> airlineStats = {};
    processedItineraryIds.clear();

    for (var log in logsForView) {
      String? airlineToAttribute;
      int flightCountInPurchase;
      double purchasePrice = 0;
      double purchaseVat = 0;

      bool isStandalone = log.itineraryId == null;
      bool isFirstInItinerary = false;
      if(!isStandalone){
        if(!processedItineraryIds.contains(log.itineraryId!)){
          processedItineraryIds.add(log.itineraryId!);
          isFirstInItinerary = true;
        }
      }

      if (isStandalone || isFirstInItinerary) {
        purchasePrice = log.ticketPrice ?? 0.0;
        purchaseVat = log.vat ?? 0.0;

        if (_groupByItinerary) {
          flightCountInPurchase = isStandalone ? log.times : 1;
        } else {
          final itineraryLogs = isStandalone ? [log] : allLogs.where((l) => l.itineraryId == log.itineraryId).toList();
          flightCountInPurchase = itineraryLogs.fold(0, (sum, l) => sum + l.times);
        }

        if (_selectedPurchaseType == 'Mileage' && _mileageRankingAttribution == 'Purchasing') {
          airlineToAttribute = log.mileageAirline ?? log.airlineName;
        } else {
          airlineToAttribute = log.airlineName;
        }

        if (log.upgradePrice != null) {
          purchasePrice += log.upgradePrice!;
          if (log.isUpgradedWithMiles) {
            purchaseVat += log.upgradeVat ?? 0.0;
            if (_mileageRankingAttribution == 'Purchasing') {
              airlineToAttribute = log.upgradeMileageAirline ?? log.mileageAirline ?? log.airlineName;
            }
          }
        }
      } else {
        continue;
      }

      if (airlineToAttribute != null && airlineToAttribute != 'Unknown') {
        if (!airlineStats.containsKey(airlineToAttribute)) {
          airlineStats[airlineToAttribute] = {'totalAmount': 0.0, 'flightCount': 0, 'totalVat': 0.0};
        }
        airlineStats[airlineToAttribute]!['totalAmount'] += purchasePrice;
        airlineStats[airlineToAttribute]!['flightCount'] += flightCountInPurchase;
        if (log.isMileageTicket || log.isUpgradedWithMiles) {
          airlineStats[airlineToAttribute]!['totalVat'] += purchaseVat;
        }
      }
    }

    List<Map<String, dynamic>> ranked = airlineStats.entries.map((e) {
      return {'name': e.key, 'totalAmount': e.value['totalAmount'], 'flightCount': e.value['flightCount'], 'totalVat': e.value['totalVat']};
    }).toList();

    ranked.removeWhere((item) => (item['totalAmount'] as double) <= 0);

    if (_selectedPurchaseType == 'Cash') {
      ranked.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
    } else {
      if (_mileageRankingMode == 'Amount') {
        ranked.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
      } else {
        ranked.sort((a, b) => (b['flightCount'] as int).compareTo(a['flightCount'] as int));
      }
    }

    _prepareLineChartData(allLogs);

    if (mounted) {
      setState(() {
        _totalItemsInPeriod = totalItems;
        _purchaseCounts = purchaseCounts;
        _filteredLogsForView = logsForView;
        _rankedAirlines = ranked;
        _totalCashSpent = totalCash;
        _totalMileageUsed = totalMileage;
        _totalMileageVat = totalVatForMileage;
      });
    }
  }

  void _prepareLineChartData(List<FlightLog> allLogs) {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;

    final Map<int, double> yearlyCash = { for (var i = startYear; i <= currentYear; i++) i: 0.0 };
    final Map<int, double> yearlyMileage = { for (var i = startYear; i <= currentYear; i++) i: 0.0 };
    final Map<int, double> yearlyVat = { for (var i = startYear; i <= currentYear; i++) i: 0.0 };
    final Set<String> processedItineraryIds = {};

    for (var log in allLogs) {
      if (log.isCanceled) continue;

      final dateToFilter = log.bookingDate ?? log.date;
      if (dateToFilter == 'Unknown' || dateToFilter.isEmpty) continue;

      final year = int.tryParse(dateToFilter.split('-')[0]);
      if (year == null || year < startYear || year > currentYear) continue;

      bool isStandalone = log.itineraryId == null;
      bool isFirstInItinerary = false;
      if (!isStandalone) {
        if (!processedItineraryIds.contains(log.itineraryId!)) {
          processedItineraryIds.add(log.itineraryId!);
          isFirstInItinerary = true;
        }
      }

      if (isStandalone || isFirstInItinerary) {
        if (log.isMileageTicket) {
          yearlyMileage[year] = (yearlyMileage[year] ?? 0.0) + (log.ticketPrice ?? 0.0);
          yearlyVat[year] = (yearlyVat[year] ?? 0.0) + (log.vat ?? 0.0);
        } else {
          yearlyCash[year] = (yearlyCash[year] ?? 0.0) + (log.ticketPrice ?? 0.0);
        }
      }
      if (log.upgradePrice != null) {
        if (log.isUpgradedWithMiles) {
          yearlyMileage[year] = (yearlyMileage[year] ?? 0.0) + log.upgradePrice!;
          yearlyVat[year] = (yearlyVat[year] ?? 0.0) + (log.upgradeVat ?? 0.0);
        } else {
          yearlyCash[year] = (yearlyCash[year] ?? 0.0) + log.upgradePrice!;
        }
      }
    }

    final List<FlSpot> spots = [];
    double maxAmount = 0.0;

    for (int year = startYear; year <= currentYear; year++) {
      double currentYearAmount = 0.0;
      if (_lineChartType == 'Cash') {
        currentYearAmount = yearlyCash[year]!;
        if (_lineChartIncludeVat) {
          currentYearAmount += yearlyVat[year]!;
        }
      } else { // Mileage
        currentYearAmount = yearlyMileage[year]!;
      }
      spots.add(FlSpot(year.toDouble(), currentYearAmount));
      if (currentYearAmount > maxAmount) {
        maxAmount = currentYearAmount;
      }
    }

    final chartColor = _lineChartType == 'Cash'
        ? _purchaseTypeInfo['Cash']!['color']
        : _purchaseTypeInfo['Mileage']!['color'];

    _lineChartData = [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        preventCurveOvershootingThreshold: 0.0,
        color: chartColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: chartColor,
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      )
    ];
    _lineChartMaxY = maxAmount == 0 ? 1000 : (maxAmount * 1.25);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 배경색 통일: Colors.grey[50]
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // [수정] AppBar 제거
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0), // 패딩 통일
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodSelector(),
              _buildGroupByItinerarySwitch(),
              const SizedBox(height: 20),
              _buildPieChartSection(),
              const SizedBox(height: 24),
              _buildViewSelector(),
              const SizedBox(height: 20),
              _buildPurchaseTypeDropdown(),
              const SizedBox(height: 24),
              _showRanking ? _buildRankingList() : _buildFlightLogList(),
              const SizedBox(height: 32),
              _buildLineChartSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedPeriod == 'Year')
            _buildYearSelectorTile()
          else
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: inputDecoration.copyWith(suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor)),
              isExpanded: true,
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
              ),
              items: _periods.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    tr(value),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue == 'Custom') {
                  _showCustomDateRangePicker();
                } else if (newValue != null) {
                  setState(() => _selectedPeriod = newValue);
                  _prepareData();
                }
              },
            ),

          if (_selectedPeriod == 'Custom' && _customStartDate != null && _customEndDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      tr('${DateFormat('yyyy-MM-dd').format(_customStartDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_customEndDate!)}'),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearSelectorTile() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                items: _periods.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      tr(value),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue == 'Custom') {
                    _showCustomDateRangePicker();
                  } else if (newValue != null) {
                    setState(() => _selectedPeriod = newValue);
                    _prepareData();
                  }
                },
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _primaryColor),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear--;
                    _prepareData();
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('$_selectedYear'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _primaryColor),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear++;
                    _prepareData();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null ? DateTimeRange(start: _customStartDate!, end: _customEndDate!) : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _prepareData();
    }
  }

  Widget _buildGroupByItinerarySwitch() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:  Text(
          tr('Group by Itinerary'),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          tr('Through-ticket as one purchase'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        value: _groupByItinerary,
        activeColor: _primaryColor,
        onChanged: (value) {
          setState(() {
            _groupByItinerary = value;
            _prepareData();
          });
        },
      ),
    );
  }

  Widget _buildTotalsDisplay() {
    final cashFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final numberFormatter = NumberFormat('#,##0');

    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildTotalItem(
              'Total Spent',
              cashFormatter.format(_totalCashSpent),
              _purchaseTypeInfo['Cash']!['color'],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 20, indent: 8, endIndent: 8),
          Expanded(
            child: _buildTotalItem(
              'Total Mileage',
              '${numberFormatter.format(_totalMileageUsed)} mi',
              _purchaseTypeInfo['Mileage']!['color'],
              vatAmount: _totalMileageVat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, Color color, {double? vatAmount}) {
    final cashFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(tr(label), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
            children: [
              TextSpan(text: tr(value)),
              if (vatAmount != null && vatAmount > 0)
                TextSpan(
                  text: tr('\n(+ ${cashFormatter.format(vatAmount)})'),
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartSection() {
    final title = 'Tickets';
    final keys = _purchaseTypeInfo.keys.toList();

    final pieData = List.generate(keys.length, (i) {
      final key = keys[i];
      final info = _purchaseTypeInfo[key]!;
      final count = _purchaseCounts[key] ?? 0;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 75.0 : 65.0;
      final color = info['color'] as Color;

      return PieChartSectionData(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        value: count.toDouble(),
        title: '',
        radius: radius,
        borderSide: isTouched ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
      );
    });

    Widget? centerWidget;
    if (_touchedIndex == null || _touchedIndex == -1 || _totalItemsInPeriod == 0) {
      centerWidget = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tr('$_totalItemsInPeriod'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor)),
        const SizedBox(height: 4),
        Text(tr(title), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]))
      ]));
    } else {
      final key = keys[_touchedIndex!];
      final info = _purchaseTypeInfo[key]!;
      final count = _purchaseCounts[key] ?? 0;
      final percentage = (_totalItemsInPeriod > 0) ? (count / _totalItemsInPeriod) * 100 : 0.0;
      centerWidget = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tr(info['abbr']), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: info['color'])),
        const SizedBox(height: 4),
        Text(tr('$count'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text(tr('${percentage.toStringAsFixed(1)}%'), style: TextStyle(fontSize: 14, color: Colors.grey[600]))
      ]));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                tr('Purchase Type'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: _primaryColor.lighten(0.1),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _buildTotalsDisplay(),
            ),
            SizedBox(
              height: 220,
              child: (_totalItemsInPeriod == 0)
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text(tr('No data for this period'), style: TextStyle(color: Colors.grey[500], fontSize: 16))]))
                  : Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    }),
                    sections: pieData,
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 70,
                  )),
                  centerWidget,
                ],
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 8.0,
              children: _purchaseTypeInfo.entries.map((entry) => _buildLegendItem(entry.value['color'], entry.value['abbr'])).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text(tr(text), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<bool>(value: false, label: Text(tr('Flight Logs')), icon: Icon(Icons.list_alt)),
          ButtonSegment<bool>(value: true, label: Text(tr('Ranking')), icon: Icon(Icons.emoji_events)),
        ],
        selected: {_showRanking},
        onSelectionChanged: (Set<bool> newSelection) => setState(() => _showRanking = newSelection.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _primaryColor,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildPurchaseTypeDropdown() {
    final selectedColor = _purchaseTypeInfo[_selectedPurchaseType]!['color'] as Color;

    final inputDecoration = InputDecoration(
      labelText: tr('Purchase Type'),
      labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
      prefixIcon: Icon(Icons.credit_card, color: selectedColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor, width: 2.0)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: selectedColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedPurchaseType,
        decoration: inputDecoration,
        items: _purchaseTypeInfo.entries.map((entry) => DropdownMenuItem<String>(
          value: entry.key,
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.value['color'], shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text(tr(entry.value['name']), style: TextStyle(color: entry.value['color'], fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() => _selectedPurchaseType = newValue);
            _prepareData();
          }
        },
      ),
    );
  }

  Widget _buildFlightLogList() {
    if (_filteredLogsForView.isEmpty) {
      return _buildEmptyState('flights');
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredLogsForView.length,
      itemBuilder: (context, index) => _buildLogCard(_filteredLogsForView[index]),
    );
  }

  Widget _buildEmptyState(String type) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.airplanemode_inactive, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(tr('No $type found'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(tr('for this type in the selected period'), style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRankingList() {
    if (_rankedAirlines.isEmpty) {
      return _buildEmptyState('airlines');
    }

    double maxValue = 1.0;
    if (_rankedAirlines.isNotEmpty) {
      if (_selectedPurchaseType == 'Cash' || (_selectedPurchaseType == 'Mileage' && _mileageRankingMode == 'Amount')) {
        maxValue = _rankedAirlines.first['totalAmount'] as double;
      } else {
        maxValue = (_rankedAirlines.first['flightCount'] as int).toDouble();
      }
    }
    if (maxValue == 0) maxValue = 1.0;

    final numberFormatter = NumberFormat('#,##0');
    final color = _purchaseTypeInfo[_selectedPurchaseType]!['color'] as Color;
    final unit = _groupByItinerary ? 'Purchases' : 'Flights';

    return Column(
      children: [
        if (_selectedPurchaseType == 'Mileage')
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _mileageRankingMode,
                    decoration:  InputDecoration(labelText: tr('Sort By'), border: OutlineInputBorder()),
                    items:  [
                      DropdownMenuItem(value: 'Amount', child: Text(tr('Amount'))),
                      DropdownMenuItem(value: 'Count', child: Text(tr('Count'))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _mileageRankingMode = value;
                          _prepareData();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _mileageRankingAttribution,
                    decoration:  InputDecoration(labelText: tr('Group By'), border: OutlineInputBorder()),
                    items:  [
                      DropdownMenuItem(value: 'Operating', child: Text(tr('Operating Airline'), style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Purchasing', child: Text(tr('Mileage Program'), style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _mileageRankingAttribution = value;
                          _prepareData();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(_rankedAirlines.length, 15),
          itemBuilder: (context, index) {
            final item = _rankedAirlines[index];
            final name = item['name'] as String;
            final totalAmount = item['totalAmount'] as double;
            final flightCount = item['flightCount'] as int;
            final totalVat = item['totalVat'] as double;

            double currentItemValue;
            Widget primaryDisplay;
            Widget secondaryDisplay;

            if (_selectedPurchaseType == 'Cash') {
              primaryDisplay = Text(tr('\$${numberFormatter.format(totalAmount)}'), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16));
              secondaryDisplay = Text(tr('$flightCount $unit'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
              currentItemValue = totalAmount;
            } else { // Mileage
              if (_mileageRankingMode == 'Amount') {
                primaryDisplay = RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                      children: [
                        TextSpan(text: tr('${numberFormatter.format(totalAmount)} mi'), style: TextStyle(color: color)),
                        if (totalVat > 0) TextSpan(text: tr(' + \$${numberFormatter.format(totalVat)}'), style: const TextStyle(color: Colors.orange)),
                      ]
                  ),
                );
                secondaryDisplay = Text(tr('$flightCount $unit'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
                currentItemValue = totalAmount;
              } else { // Count
                primaryDisplay = Text(tr('$flightCount $unit'), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16));
                secondaryDisplay = RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                      children: [
                        TextSpan(text: tr('${numberFormatter.format(totalAmount)} mi')),
                        if (totalVat > 0) TextSpan(text: tr(' + \$${numberFormatter.format(totalVat)}'), style: const TextStyle(color: Colors.orange)),
                      ]
                  ),
                );
                currentItemValue = flightCount.toDouble();
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              tr('#${index + 1}'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tr(name), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [primaryDisplay, secondaryDisplay]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: currentItemValue / maxValue,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLineChartSection() {
    final legendText = _lineChartType == 'Cash' ? 'Cash' : 'Mileage';
    final isCash = _lineChartType == 'Cash'; // 현재 모드 확인

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.trending_up, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(tr("Yearly Trend (10 Years)"), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 16),
            // [수정] SegmentedButton과 VAT Switch를 한 줄에 배치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SegmentedButton<String>(
                  // [수정] 체크 표시 제거
                  showSelectedIcon: false,
                  segments:  [
                    ButtonSegment(value: 'Cash', label: Text(tr('Cash'))),
                    ButtonSegment(value: 'Mileage', label: Text(tr('Mileage')))
                  ],
                  selected: {_lineChartType},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _lineChartType = newSelection.first;
                      _prepareLineChartData(context.read<AirlineProvider>().allFlightLogs);
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: _primaryColor,
                    selectedForegroundColor: Colors.white,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                // [수정] Include VAT 스위치 배치 및 Mileage 선택 시 비활성화(회색) 처리
                Row(
                  children: [
                    Text(
                      tr('Include VAT'),
                      style: TextStyle(
                        // Mileage일 때 회색으로 표시
                        color: isCash ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: _lineChartIncludeVat,
                      activeColor: _primaryColor,
                      // Mileage일 때 onChanged를 null로 설정하여 스위치 비활성화 (회색 처리됨)
                      onChanged: isCash ? (value) {
                        setState(() {
                          _lineChartIncludeVat = value;
                          _prepareLineChartData(context.read<AirlineProvider>().allFlightLogs);
                        });
                      } : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return Container();
                          final formattedValue = _lineChartType == 'Cash' ? '\$${NumberFormat.compact().format(value)}' : NumberFormat.compact().format(value);
                          return SideTitleWidget( axisSide: meta.axisSide, child: Text(tr(formattedValue), style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)) );
                        }
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 30, interval: 1,
                      getTitlesWidget: (value, meta) => SideTitleWidget(axisSide: meta.axisSide, child: Text(tr(value.toInt().toString().substring(2)), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
                    )),
                  ),
                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), left: BorderSide(color: Colors.grey[300]!, width: 1))),
                  minX: (DateTime.now().year - 9).toDouble(),
                  maxX: DateTime.now().year.toDouble(),
                  minY: 0,
                  maxY: _lineChartMaxY,
                  lineBarsData: _lineChartData,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: _buildLegendItem(_lineChartType == 'Cash' ? _purchaseTypeInfo['Cash']!['color'] : _purchaseTypeInfo['Mileage']!['color'], legendText)),
          ],
        ),
      ),
    );
  }


  Widget _buildLogCard(FlightLog log) {
    String displayDate = log.date;
    if (displayDate != 'Unknown') {
      try {
        final dateTime = DateTime.parse(displayDate);
        displayDate = DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(dateTime);
      } catch (e) {/* Use original date string */}
    }

    final flightNumberUpper = log.flightNumber.toUpperCase();
    final displayFlightNumber = (flightNumberUpper == 'UNKNOWN' || flightNumberUpper.isEmpty) ? '-' : flightNumberUpper;
    final purchaseColor = _purchaseTypeInfo[log.isMileageTicket ? 'Mileage' : 'Cash']!['color'] as Color;


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purchaseColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: purchaseColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true)));
          _prepareData();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: purchaseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flight, color: purchaseColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.airlineName ?? tr('Unknown'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(tr(displayFlightNumber), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                    const SizedBox(height: 4),
                    Text(tr('${log.departureIata ?? 'N/A'} → ${log.arrivalIata ?? 'N/A'}'), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr(displayDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  if (log.rating > 0) ...[
                    const SizedBox(height: 8),
                    RatingBar.builder(
                      initialRating: log.rating,
                      itemCount: 5,
                      itemSize: 16.0,
                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {},
                      ignoreGestures: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}