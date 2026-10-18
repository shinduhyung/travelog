// lib/screens/flight_transfer_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'flight_connection_screen.dart';
import 'add_flight_log_screen.dart';


class FlightTransferStatsScreen extends StatefulWidget {
  const FlightTransferStatsScreen({super.key});

  @override
  State<FlightTransferStatsScreen> createState() => _FlightTransferStatsScreenState();
}

class _FlightTransferStatsScreenState extends State<FlightTransferStatsScreen> {
  // 🚨 [수정] 테마 색상을 핑크 계열로 변경
  final Color _primaryColor = const Color(0xFFE91E63); // Deep Pink
  final Color _accentColor = const Color(0xFFFF4081); // Light Pink Accent
  final List<String> _periods = ['Last 365 Days', 'Year', 'All Time', 'Custom'];
  String _selectedPeriod = 'All Time';
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  String _selectedView = 'Airports';
  String _selectedVisitType = 'Normal';
  bool _showRanking = true;
  bool _countItineraryAsOne = true;

  int? _touchedIndex = -1;
  int _totalItemsInPeriod = 0;
  List<dynamic> _filteredItemsForView = [];
  List<Map<String, dynamic>> _rankedItems = [];
  Map<String, int> _pieChartCounts = {};
  int _interlineConnectionsCount = 0;
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0;

  // 🚨 [색상 정의]
  final Map<String, Map<String, dynamic>> _visitTypeInfo = {
    'Normal': {'color': const Color(0xFF607D8B), 'name': 'Normal', 'abbr': 'Normal'}, // Blue Grey
    'Transfer': {'color': const Color(0xFFE91E63), 'name': 'Transfer', 'abbr': 'Transfer'}, // Pink
    'Layover': {'color': const Color(0xFF4CAF50), 'name': 'Layover', 'abbr': 'Layover'}, // Green
    'Stopover': {'color': const Color(0xFF00BCD4), 'name': 'Stopover', 'abbr': 'Stopover'}, // Cyan
    'Mixed': {'color': const Color(0xFF9C27B0), 'name': 'Mixed', 'abbr': 'Mixed'}, // Purple
  };

  // Connect Flights 버튼
  Widget _buildConnectFlightsButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        // 🚨 [수정] 핑크 그라데이션 적용
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FlightConnectionScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.connecting_airports,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                 Text(
                  tr('Connect Flights'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData();
  }

  void _prepareData() {
    dynamic allItems;
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Last 365 Days': startDate = now.subtract(const Duration(days: 365)); endDate = now; break;
      case 'Year': startDate = DateTime(_selectedYear, 1, 1); endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59); break;
      case 'Custom': startDate = _customStartDate; endDate = _customEndDate; break;
      case 'All Time': default: break;
    }

    if (_selectedView == 'Airports') {
      final airportProvider = Provider.of<AirportProvider>(context, listen: false);
      final allAirportVisits = [];
      airportProvider.visitedAirports.forEach((iata) {
        final airport = airportProvider.allAirports.firstWhere((a) => a.iataCode == iata, orElse: () => Airport(iataCode: iata, name: 'Unknown', country: 'Unknown', latitude: 0, longitude: 0));
        airportProvider.getVisitEntries(iata).forEach((entry) {
          allAirportVisits.add({'airport': airport, 'entry': entry});
        });
      });
      allItems = allAirportVisits.where((item) {
        final itemDate = (item['entry'] as AirportVisitEntry).date;
        if (itemDate == null) return false;
        if (_selectedPeriod == 'All Time') return true;
        if (startDate != null && itemDate.isBefore(startDate)) return false;
        if (endDate != null && itemDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    } else {
      allItems = airlineProvider.allFlightLogs.where((log) {
        final itemDate = DateTime.tryParse(log.date);
        if (itemDate == null) return false;
        if (_selectedPeriod == 'All Time') return true;
        if (startDate != null && itemDate.isBefore(startDate)) return false;
        if (endDate != null && itemDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    _updateStateWithStats(allItemsInPeriod: allItems);
  }

  String _getVisitType(AirportVisitEntry? entry) {
    if (entry == null) return 'Normal';
    if (entry.isTransfer) return 'Transfer';
    if (entry.isLayover) return 'Layover';
    if (entry.isStopover) return 'Stopover';
    return 'Normal';
  }

  void _updateStateWithStats({ required List<dynamic> allItemsInPeriod }) {
    _pieChartCounts = { for (var key in _visitTypeInfo.keys) key: 0 };
    List<dynamic> itemsForView = [];
    Map<String, int> rankCounts = {};
    _interlineConnectionsCount = 0;
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);

    if (_selectedView == 'Airports') {
      _totalItemsInPeriod = allItemsInPeriod.length;
      for (var item in allItemsInPeriod) {
        final mapItem = item as Map<String, dynamic>;
        final entry = mapItem['entry'] as AirportVisitEntry;
        final type = _getVisitType(entry);
        _pieChartCounts[type] = (_pieChartCounts[type] ?? 0) + 1;

        if (type == _selectedVisitType) {
          itemsForView.add(mapItem);
          final iata = (mapItem['airport'] as Airport).iataCode;
          rankCounts[iata] = (rankCounts[iata] ?? 0) + 1;
        }
      }
    } else {
      final logsInPeriod = allItemsInPeriod.cast<FlightLog>();
      final Map<String, String> logIdToConnectionId = {};
      for (final connection in airlineProvider.flightConnections) {
        for (final logId in connection.flightLogIds) {
          logIdToConnectionId[logId] = connection.id;
        }
      }

      if (_countItineraryAsOne) {
        final Set<String> processedConnectionIds = {};
        int totalCount = 0;
        for (final log in logsInPeriod) {
          final connectionId = logIdToConnectionId[log.id];
          if (connectionId != null) {
            if (processedConnectionIds.contains(connectionId)) continue;

            totalCount++;
            processedConnectionIds.add(connectionId);

            final connection = airlineProvider.flightConnections.firstWhere((c) => c.id == connectionId);
            final connectionTypes = connection.connections.map((c) => c.type).toSet();
            String type = (connection.flightLogIds.length >= 3 && connectionTypes.length > 1)
                ? 'Mixed'
                : (connectionTypes.firstOrNull ?? 'Transfer');

            _pieChartCounts[type] = (_pieChartCounts[type] ?? 0) + 1;

            if (type == _selectedVisitType) {
              itemsForView.add(connection);
              final logs = connection.flightLogIds.map((id) => airlineProvider.getFlightLogById(id)).whereType<FlightLog>().toList();
              if (logs.isNotEmpty) {
                final firstAirline = logs.first.airlineName;
                if (logs.any((l) => l.airlineName != firstAirline)) {
                  _interlineConnectionsCount++;
                } else if (firstAirline != null && firstAirline != 'Unknown') {
                  rankCounts[firstAirline] = (rankCounts[firstAirline] ?? 0) + 1;
                }
              }
            }
          } else {
            totalCount += log.times;
            _pieChartCounts['Normal'] = (_pieChartCounts['Normal'] ?? 0) + log.times;
            if (_selectedVisitType == 'Normal') {
              itemsForView.add(log);
              final airlineName = log.airlineName;
              if (airlineName != null && airlineName != 'Unknown') {
                rankCounts[airlineName] = (rankCounts[airlineName] ?? 0) + log.times;
              }
            }
          }
        }
        _totalItemsInPeriod = totalCount;
      } else {
        _totalItemsInPeriod = logsInPeriod.fold<int>(0, (sum, log) => sum + log.times);
        final Map<String, String> flightIdToCategoryType = {};
        for (final connection in airlineProvider.flightConnections) {
          for (int i = 0; i < connection.flightLogIds.length; i++) {
            flightIdToCategoryType[connection.flightLogIds[i]] = (i < connection.connections.length) ? connection.connections[i].type : 'Normal';
          }
        }
        for (final log in logsInPeriod) {
          final type = flightIdToCategoryType[log.id] ?? 'Normal';
          _pieChartCounts[type] = (_pieChartCounts[type] ?? 0) + log.times;
          if (type == _selectedVisitType) {
            itemsForView.add(log);
            final airlineName = log.airlineName;
            if (airlineName != null && airlineName != 'Unknown') {
              rankCounts[airlineName] = (rankCounts[airlineName] ?? 0) + log.times;
            }
          }
        }
      }
    }

    final ranked = rankCounts.entries
        .where((e) => e.key != 'Unknown')
        .map((e) {
      if (_selectedView == 'Airports') {
        final airport = Provider.of<AirportProvider>(context, listen: false).allAirports.firstWhere((a) => a.iataCode == e.key, orElse: () => Airport(iataCode: e.key, name: 'Unknown', country: 'Unknown', latitude: 0, longitude: 0));
        return {'name': airport.name, 'count': e.value};
      } else {
        return {'name': e.key, 'count': e.value};
      }
    }).toList();
    ranked.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    _prepareLineChartData();

    if (mounted) {
      setState(() {
        _filteredItemsForView = itemsForView;
        _rankedItems = ranked;
      });
    }
  }

  void _prepareLineChartData() {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;
    final Map<int, Map<String, int>> yearlyCounts = {
      for (var i = startYear; i <= currentYear; i++) i: { for (var key in _visitTypeInfo.keys) key: 0 }
    };
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = airlineProvider.allFlightLogs;

    if (_selectedView == 'Airports') {
      final airportProvider = Provider.of<AirportProvider>(context, listen: false);
      airportProvider.visitedAirports.forEach((iata) {
        airportProvider.getVisitEntries(iata).forEach((entry) {
          final year = entry.date?.year;
          if (year != null && year >= startYear && year <= currentYear) {
            final type = _getVisitType(entry);
            yearlyCounts[year]![type] = (yearlyCounts[year]![type] ?? 0) + 1;
          }
        });
      });
    } else {
      final Map<String, String> logIdToConnectionId = {};
      for (final connection in airlineProvider.flightConnections) {
        for (final logId in connection.flightLogIds) {
          logIdToConnectionId[logId] = connection.id;
        }
      }

      if (_countItineraryAsOne) {
        final Set<String> processedConnectionIds = {};
        for (final log in allLogs) {
          final year = DateTime.tryParse(log.date)?.year;
          if (year == null || year < startYear || year > currentYear) continue;

          final connectionId = logIdToConnectionId[log.id];
          if (connectionId != null) {
            if (processedConnectionIds.contains(connectionId)) continue;
            processedConnectionIds.add(connectionId);

            final connection = airlineProvider.flightConnections.firstWhere((c) => c.id == connectionId);
            final connectionTypes = connection.connections.map((c) => c.type).toSet();
            String type = (connection.flightLogIds.length >= 3 && connectionTypes.length > 1)
                ? 'Mixed'
                : (connectionTypes.firstOrNull ?? 'Transfer');
            yearlyCounts[year]![type] = (yearlyCounts[year]![type] ?? 0) + 1;
          } else {
            yearlyCounts[year]!['Normal'] = (yearlyCounts[year]!['Normal'] ?? 0) + log.times;
          }
        }
      } else {
        final Map<String, String> flightIdToCategoryType = {};
        for (final connection in airlineProvider.flightConnections) {
          for (int i = 0; i < connection.flightLogIds.length; i++) {
            flightIdToCategoryType[connection.flightLogIds[i]] = (i < connection.connections.length) ? connection.connections[i].type : 'Normal';
          }
        }
        for (final log in allLogs) {
          final year = DateTime.tryParse(log.date)?.year;
          if (year == null || year < startYear || year > currentYear) continue;
          final type = flightIdToCategoryType[log.id] ?? 'Normal';
          yearlyCounts[year]![type] = (yearlyCounts[year]![type] ?? 0) + log.times;
        }
      }
    }

    double maxCount = 0;
    final List<LineChartBarData> lines = [];
    final allDataPoints = <String, List<FlSpot>>{ for (var key in _visitTypeInfo.keys) key: [], 'Total': [] };

    for (int year = startYear; year <= currentYear; year++) {
      int yearlyTotal = 0;
      _visitTypeInfo.keys.forEach((type) {
        final count = yearlyCounts[year]![type] ?? 0;
        allDataPoints[type]!.add(FlSpot(year.toDouble(), count.toDouble()));
        yearlyTotal += count;
      });
      allDataPoints['Total']!.add(FlSpot(year.toDouble(), yearlyTotal.toDouble()));
      if (yearlyTotal > maxCount) maxCount = yearlyTotal.toDouble();
    }

    allDataPoints.forEach((name, spots) {
      final isTotal = name == 'Total';
      final color = isTotal ? Colors.black87 : (_visitTypeInfo[name]?['color'] ?? Colors.grey);
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        preventCurveOvershootingThreshold: 0.0,
        color: color,
        barWidth: isTotal ? 2.5 : 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: isTotal ? 3 : 4,
              color: color,
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
        dashArray: isTotal ? [5, 5] : null,
      ));
    });

    double newMaxY = maxCount == 0 ? 10 : (maxCount * 1.25);
    if (newMaxY > 10) { newMaxY = (newMaxY / 5).ceil() * 5.0; } else { newMaxY = newMaxY.ceilToDouble(); }

    if(mounted) {
      setState(() {
        _lineChartData = lines;
        _lineChartMaxY = newMaxY;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectFlightsButton(context),
              const SizedBox(height: 20),
              _buildMainSelector(),
              const SizedBox(height: 20),
              _buildPeriodSelector(),
              if (_selectedView == 'Flights')
                _buildGroupByItinerarySwitch(),
              const SizedBox(height: 20),
              _buildPieChartSection(),
              const SizedBox(height: 24),
              _buildViewSelector(),
              const SizedBox(height: 20),
              _buildTypeDropdown(),
              const SizedBox(height: 24),
              _showRanking ? _buildRankingList() : _buildLogList(),
              const SizedBox(height: 32),
              _buildLineChartSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
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
          tr('Connected flights as a single item'), // Count 제거
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        value: _countItineraryAsOne,
        // 🚨 [수정] 핑크색 적용 및 체크마크 아이콘 제거
        activeColor: _primaryColor,
        thumbIcon: MaterialStateProperty.all(null), // 체크 아이콘 제거
        onChanged: (value) {
          setState(() {
            _countItineraryAsOne = value;
            if (!_countItineraryAsOne && _selectedVisitType == 'Mixed') {
              _selectedVisitType = 'Normal';
            }
            _prepareData();
          });
        },
      ),
    );
  }

  Widget _buildLogList() {
    if (_filteredItemsForView.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredItemsForView.length,
      itemBuilder: (context, index) {
        final item = _filteredItemsForView[index];
        if (item is Map<String, dynamic>) {
          return _buildAirportVisitLogItem(item);
        } else if (item is FlightConnection) {
          return _buildItineraryLogItem(item);
        } else if (item is FlightLog) {
          return _buildAirlineLogItem(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState() {
    final type = _selectedView == 'Airports' ? 'visits' : 'items';
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedView == 'Airports' ? Icons.connecting_airports : Icons.flight,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('No $type found'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('for this type in the selected period'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList() {
    if (_rankedItems.isEmpty && _interlineConnectionsCount == 0) {
      return _buildEmptyState();
    }

    final maxCount = _rankedItems.isNotEmpty ? _rankedItems.first['count'] as int : 1;
    final unit = _selectedView == 'Airports' ? 'Visits' : (_countItineraryAsOne ? 'Itineraries' : 'Flights');
    final selectedTypeColor = _visitTypeInfo[_selectedVisitType]!['color'] as Color;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(_rankedItems.length, 15),
          itemBuilder: (context, index) {
            final item = _rankedItems[index];
            final name = item['name'] as String;
            final count = item['count'] as int;

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
                            gradient: LinearGradient(
                              colors: [
                                selectedTypeColor,
                                selectedTypeColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              tr('#${index + 1}'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedTypeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tr('$count $unit'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selectedTypeColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: count / (maxCount > 0 ? maxCount : 1),
                        backgroundColor: selectedTypeColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(selectedTypeColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_interlineConnectionsCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.multiple_stop,
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('Interline Connections: $_interlineConnectionsCount'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildAirportVisitLogItem(Map<String,dynamic> visit) {
    final airport = visit['airport'] as Airport;
    final entry = visit['entry'] as AirportVisitEntry;
    final date = entry.date;
    final displayDate = date != null ? DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(date) : 'Unknown Date';
    final selectedTypeColor = _visitTypeInfo[_selectedVisitType]!['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selectedTypeColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: selectedTypeColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [selectedTypeColor, selectedTypeColor.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              airport.iataCode,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          airport.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          tr(airport.country),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: Text(
          tr(displayDate),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAirlineLogItem(FlightLog log) {
    final displayDate = log.date != 'Unknown' ? DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(DateTime.parse(log.date)) : 'Unknown';
    final selectedTypeColor = _visitTypeInfo[_selectedVisitType]!['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selectedTypeColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: selectedTypeColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selectedTypeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.flight, color: selectedTypeColor, size: 24),
        ),
        title: Text(
          tr('${log.airlineName} ${log.flightNumber}'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          tr('${log.departureIata} → ${log.arrivalIata}'),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: Text(
          tr(displayDate),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItineraryLogItem(FlightConnection itinerary) {
    final provider = context.read<AirlineProvider>();
    final List<Widget> itineraryItems = [];
    final logMap = {for (var log in provider.allFlightLogs) log.id: log};

    for (int i = 0; i < itinerary.flightLogIds.length; i++) {
      final logId = itinerary.flightLogIds[i];
      final log = logMap[logId];
      if (log != null) {
        itineraryItems.add(_buildLogCardContent(context, log));
        if (i < itinerary.connections.length) {
          itineraryItems.add(_buildConnectionInfoWidget(itinerary.connections[i]));
        }
      }
    }

    if (itineraryItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // 🚨 [수정] 핑크색 테두리 적용
        border: Border.all(color: _primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: itineraryItems),
    );
  }

  // 🚨 [수정] 연결 타입(Transfer/Layover/Stopover)에 맞는 색상과 시간을 표시하도록 수정
  Widget _buildConnectionInfoWidget(ConnectionInfo info) {
    // 타입 이름의 첫 글자를 대문자로 변환하여 키로 사용 (혹시 모를 대소문자 문제 방지)
    final typeKey = info.type.isEmpty ? 'Transfer' : info.type[0].toUpperCase() + info.type.substring(1).toLowerCase();
    // 해당 타입의 색상을 가져옴. 없으면 기본값 사용
    final typeColor = _visitTypeInfo[typeKey]?['color'] ?? _primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        // 해당 타입 색상의 옅은 배경
        color: typeColor.withOpacity(0.08),
        border: Border(
          top: BorderSide(color: typeColor.withOpacity(0.1)),
          bottom: BorderSide(color: typeColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 해당 타입 색상의 아이콘
          Icon(Icons.arrow_downward, color: typeColor, size: 18),
          const SizedBox(width: 10),
          // 해당 타입 색상의 텍스트
          Text(
            tr(info.type.toUpperCase()),
            style: TextStyle(
              color: typeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 13,
            ),
          ),
          // 🚨 [수정] 시간(Duration) 표시
          if (info.duration != null && info.duration!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 12, color: typeColor),
                  const SizedBox(width: 4),
                  Text(
                    tr(info.duration!),
                    style: TextStyle(
                      color: typeColor.darken(0.1), // 텍스트는 약간 더 진하게
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogCardContent(BuildContext context, FlightLog log) {
    String displayDate = log.date;
    if (displayDate != 'Unknown') {
      try {
        displayDate = DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(DateTime.parse(displayDate));
      } catch (e) { /* Use original date string */ }
    }

    final flightNumberUpper = log.flightNumber.toUpperCase();
    final displayFlightNumber = (flightNumberUpper == 'UNKNOWN' || flightNumberUpper.isEmpty) ? '-' : flightNumberUpper;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.airlineName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(displayFlightNumber),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          // 🚨 [수정] 핑크색 적용
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tr(displayDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          tr(log.departureIata ?? 'N/A'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          tr(log.arrivalIata ?? 'N/A'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    final title = _selectedView == 'Airports' ? 'Total Visits' : (_countItineraryAsOne ? 'Total Itineraries' : 'Total Flights');
    final keys = _visitTypeInfo.keys.toList();
    final pieData = List.generate(keys.length, (i) {
      final key = keys[i];
      final info = _visitTypeInfo[key]!;
      final count = _pieChartCounts[key] ?? 0;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 75.0 : 65.0;
      final color = info['color'] as Color;

      return PieChartSectionData(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        value: count.toDouble(),
        title: '',
        radius: radius,
        borderSide: isTouched
            ? BorderSide(color: Colors.white, width: 4)
            : BorderSide.none,
      );
    });

    Widget? centerWidget;
    if (_touchedIndex == null || _touchedIndex == -1 || _totalItemsInPeriod == 0) {
      centerWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('$_totalItemsInPeriod'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                // 🚨 [수정] 핑크색 적용
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(title),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    } else {
      final key = keys[_touchedIndex!];
      final info = _visitTypeInfo[key]!;
      final count = _pieChartCounts[key] ?? 0;
      final percentage = (_totalItemsInPeriod > 0) ? (count / _totalItemsInPeriod) * 100 : 0.0;
      centerWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(info['abbr']),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: info['color'],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('$count'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              tr('${percentage.toStringAsFixed(1)}%'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
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
            // 🚨 [수정] 원형 그래프 제목 (이름 및 스타일 변경)
            Padding(
              padding: const EdgeInsets.only(bottom: 40), // 🚨 [수정] 간격 12 -> 40
              child: Text(
                tr('Connection Type'), // 🚨 [수정] 'Distribution' 제거
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900, // 🚨 [수정] 폰트 굵기
                  fontSize: 24, // 🚨 [수정] 폰트 크기
                  color: _primaryColor.lighten(0.1), // 🚨 [수정] 핑크색 계열
                  letterSpacing: 0.5, // 🚨 [수정] 자간
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: (_totalItemsInPeriod == 0)
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      tr('No data for this period'),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
                  : Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: pieData,
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 70,
                    ),
                  ),
                  centerWidget,
                ],
              ),
            ),
            const SizedBox(height: 32),
            // [수정됨] Row -> Wrap으로 변경하여 범례가 두 줄로 표시되도록 수정
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0, // 가로 간격
              runSpacing: 8.0, // 세로 간격 (두 줄이 될 때)
              children: _visitTypeInfo.entries
                  .map((entry) => _buildLegendItem(entry.value['color'], entry.value['abbr']))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSelector() {
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
      child: SegmentedButton<String>(
        // 🚨 [수정] 체크 표시 제거
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<String>(
            value: 'Airports',
            label: Text(tr('Airports')),
            icon: Icon(Icons.connecting_airports),
          ),
          ButtonSegment<String>(
            value: 'Flights',
            label: Text(tr('Flights')),
            icon: Icon(Icons.flight_takeoff),
          ),
        ],
        selected: {_selectedView},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedView = newSelection.first;
            _prepareData();
          });
        },
        style: SegmentedButton.styleFrom(
          // 🚨 [수정] 핑크색 적용
          selectedBackgroundColor: _primaryColor,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // 🚨 [수정] 드롭다운 디자인 개선 및 연도 선택기 통합
  Widget _buildPeriodSelector() {
    // 🚨 [수정] 드롭다운 전체 컨테이너에 테두리와 그림자 추가
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
            color: _primaryColor.withOpacity(0.2), // 핑크색 그림자
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 'Year'가 선택되었을 때 커스텀 위젯을 사용
          if (_selectedPeriod == 'Year')
            _buildYearSelectorTile()
          else
          // 'Year'가 아닐 때 기존 드롭다운 필드 사용
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: inputDecoration.copyWith(suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor)),
              isExpanded: true,
              // 🚨 [수정] 선택된 텍스트 핑크색 적용
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
              ),
              items: _periods.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  // 🚨 [수정] 드롭다운 항목 텍스트 핑크색 적용
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
                  setState(() {
                    _selectedPeriod = newValue;
                  });
                  _prepareData();
                }
              },
            ),

          // Custom 기간 표시
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

  // 🚨 [수정] 'Year' 선택 시 드롭다운 자리에 들어갈 위젯 (스타일 적용)
  Widget _buildYearSelectorTile() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.5), width: 1.5), // 🚨 [추가] 테두리
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Period 선택 드롭다운 (Year)
          Container(
            padding: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: Icon(Icons.arrow_drop_down, color: _primaryColor), // 🚨 [수정] 핑크색 아이콘
                items: _periods.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      tr(value),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor, // 🚨 [수정] 드롭다운 항목 텍스트 핑크색
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue == 'Custom') {
                    _showCustomDateRangePicker();
                  } else if (newValue != null) {
                    setState(() {
                      _selectedPeriod = newValue;
                    });
                    _prepareData();
                  }
                },
                // 🚨 [수정] 선택된 텍스트('Year') 핑크색 적용
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                ),
              ),
            ),
          ),
          // 🚨 [수정] 연도 선택기 (왼쪽으로 공간 확보)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _primaryColor), // 🚨 [수정] 핑크색 아이콘
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear--;
                    _prepareData();
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 🚨 [수정] 패딩 축소
                  margin: const EdgeInsets.symmetric(horizontal: 4), // 🚨 [수정] 마진 축소
                  decoration: BoxDecoration(
                    // 🚨 [수정] 핑크색 배경
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('$_selectedYear'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      // 🚨 [수정] 핑크색 텍스트
                      color: _primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _primaryColor), // 🚨 [수정] 핑크색 아이콘
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
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              // 🚨 [수정] 핑크색 적용
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
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

  Widget _buildLegendItem(Color color, String text) {
    // [수정됨] 범례가 두 줄로 들어갈 때 공간 확보를 위해 패딩과 폰트 사이즈 조정
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // 12 -> 10으로 축소
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr(text),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11, // 12 -> 11로 축소
              color: Colors.grey[800],
            ),
          ),
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
        // 🚨 [수정] 체크 표시 제거
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<bool>(
            value: false,
            label: Text(tr('Logs')),
            icon: Icon(Icons.list_alt),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text(tr('Ranking')),
            icon: Icon(Icons.emoji_events),
          ),
        ],
        selected: {_showRanking},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _showRanking = newSelection.first;
          });
        },
        style: SegmentedButton.styleFrom(
          // 🚨 [수정] 핑크색 적용
          selectedBackgroundColor: _primaryColor,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    final visitTypes = Map.of(_visitTypeInfo);
    if (_selectedView == 'Flights' && !_countItineraryAsOne) {
      visitTypes.remove('Mixed');
    }

    // 🚨 [수정] 선택된 항목의 색상을 가져옴
    final selectedColor = _visitTypeInfo[_selectedVisitType]!['color'] as Color;

    // 🚨 [수정] 드롭다운 전체 컨테이너에 테두리와 그림자 추가
    final inputDecoration = InputDecoration(
      labelText: tr('Visit Type'),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        Icons.sync_alt,
        color: selectedColor, // 🚨 [수정] 아이콘 색상도 동기화
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5), // 🚨 [수정] 선택된 색상 적용
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5), // 🚨 [수정] 선택된 색상 적용
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor, width: 2.0), // 🚨 [수정] 선택된 색상 적용
      ),
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
            color: selectedColor.withOpacity(0.2), // 🚨 [수정] 선택된 색상으로 그림자 적용
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedVisitType,
        decoration: inputDecoration,
        items: visitTypes.entries.map((entry) {
          String name = entry.value['name'];
          if (_selectedView == 'Flights' && _countItineraryAsOne && entry.key == 'Mixed') {
            name = _showRanking ? 'Interlined' : 'Mixed';
          }
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.value['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr(name),
                  style: TextStyle(
                    color: entry.value['color'],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedVisitType = newValue;
            });
            _prepareData();
          }
        },
      ),
    );
  }

  Widget _buildLineChartSection() {
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
                    // 🚨 [수정] 핑크색 배경
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  // 🚨 [수정] 핑크색 아이콘
                  child: Icon(Icons.trending_up, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  tr("Yearly Trend (10 Years)"),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
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
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return Container();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              tr(value.toInt().toString()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            tr(value.toInt().toString().substring(2)),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      left: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  minX: (DateTime.now().year - 9).toDouble(),
                  maxX: DateTime.now().year.toDouble(),
                  minY: 0,
                  maxY: _lineChartMaxY,
                  lineBarsData: _lineChartData,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // [수정됨] Line Chart 범례도 Wrap을 사용하여 줄바꿈 처리 및 간격 조정
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.black87, 'Total'),
                ..._visitTypeInfo.entries
                    .where((e) => e.key != 'Mixed')
                    .map((e) => _buildLegendItem(e.value['color'], e.value['abbr'])),
              ],
            ),
          ],
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
  // 🚨 [추가] lighten 메서드 추가
  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}