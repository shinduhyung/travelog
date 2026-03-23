// lib/screens/flight_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui; // PathMetric 사용을 위해 추가

import 'package:jidoapp/screens/flight_log_list_screen.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/screens/flight_connection_screen.dart';
import 'package:jidoapp/screens/flight_route_map_screen.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';

// Statistics Screens
import 'package:jidoapp/screens/flight_overview_stats_screen.dart';
import 'package:jidoapp/screens/aircraft_stats_screen.dart';
import 'package:jidoapp/screens/flight_transfer_stats_screen.dart';
import 'package:jidoapp/screens/flight_frequency_stats_screen.dart';
import 'package:jidoapp/screens/purchase_stats_screen.dart';
import 'package:jidoapp/screens/seat_class_stats_screen.dart';

class FlightHubScreen extends StatelessWidget {
  const FlightHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    final airlineProvider = Provider.of<AirlineProvider>(context);
    final airportProvider = Provider.of<AirportProvider>(context);

    // 실제 데이터 계산
    final totalFlights = airlineProvider.allFlightLogs
        .where((log) => !log.isCanceled)
        .fold<int>(0, (sum, log) => sum + log.times);
    final uniqueAircraft = airlineProvider.allFlightLogs
        .where((log) => !log.isCanceled && log.aircraft != null)
        .map((log) => log.aircraft)
        .toSet()
        .length;
    final transferCount = airlineProvider.flightConnections.fold<int>(
        0,
            (sum, conn) =>
        sum + conn.connections.where((c) => c.type == 'Transfer').length);
    final uniqueRoutes = airlineProvider.allFlightLogs
        .where((log) => !log.isCanceled)
        .map((log) => '${log.departureIata}-${log.arrivalIata}')
        .toSet()
        .length;
    final totalSpent = airlineProvider.purchases
        .where((p) => !p.isMileage && p.price != null)
        .fold<double>(0, (sum, p) => sum + p.price!);
    final premiumFlights = airlineProvider.allFlightLogs
        .where((log) =>
    !log.isCanceled &&
        log.seatClass != null &&
        (log.seatClass!.toLowerCase().contains('business') ||
            log.seatClass!.toLowerCase().contains('first')))
        .fold<int>(0, (sum, log) => sum + log.times);

    // 금액 포맷팅
    String formatMoney(double amount) {
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(0)}K';
      }
      return amount.toStringAsFixed(0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flight Hub',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  height: 1.0,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All systems active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child:
                          Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Quick Actions
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Quick Access',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Flight Logs - 큰 강조 카드
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildFeaturedFlightLogsCard(
                      context,
                      totalFlights: totalFlights,
                      screen: const FlightLogListScreen(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Route Map & Connections - 2개 나란히 (높이 통일)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 160, // 두 카드의 높이를 강제로 통일
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildRouteMapCard(
                              context,
                              screen: const FlightRouteMapScreen(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildCompactCard(
                              context,
                              title: 'Connections',
                              subtitle:
                              '${airlineProvider.flightConnections.length} Itineraries',
                              icon: Icons.connecting_airports_rounded,
                              color: Color(0xFFEC4899),
                              screen: const FlightConnectionScreen(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // Analytics Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Flight Analytics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _GatedAnalyticsWrapper(
                  destination: const FlightOverviewStatsScreen(),
                  child: _buildOverviewCard(
                    context,
                    totalFlights: totalFlights,
                    uniqueRoutes: uniqueRoutes,
                    screen: const FlightOverviewStatsScreen(),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 2x2 Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _GatedAnalyticsWrapper(
                    destination: const AircraftStatsScreen(),
                    child: _buildCompactAnalyticsCard(
                      context,
                      title: 'Aircraft',
                      count: '$uniqueAircraft',
                      unit: 'types',
                      icon: Icons.airplanemode_active,
                      color: Color(0xFF11998E),
                      screen: const AircraftStatsScreen(),
                    ),
                  ),
                  _GatedAnalyticsWrapper(
                    destination: const FlightTransferStatsScreen(),
                    child: _buildCompactAnalyticsCard(
                      context,
                      title: 'Transfer',
                      count: '$transferCount',
                      unit: 'stops',
                      icon: Icons.swap_horiz,
                      color: Color(0xFFFA709A),
                      screen: const FlightTransferStatsScreen(),
                    ),
                  ),
                  _GatedAnalyticsWrapper(
                    destination: const FlightFrequencyStatsScreen(),
                    child: _buildCompactAnalyticsCard(
                      context,
                      title: 'Frequency',
                      count: '$uniqueRoutes',
                      unit: 'routes',
                      icon: Icons.repeat,
                      color: Color(0xFFFEE140),
                      screen: const FlightFrequencyStatsScreen(),
                    ),
                  ),
                  _GatedAnalyticsWrapper(
                    destination: const PurchaseStatsScreen(),
                    child: _buildCompactAnalyticsCard(
                      context,
                      title: 'Purchase',
                      count: totalSpent > 0 ? '\$${formatMoney(totalSpent)}' : '0',
                      unit: 'spent',
                      icon: Icons.credit_card,
                      color: Color(0xFFFA8BFF),
                      screen: const PurchaseStatsScreen(),
                    ),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Seat Class
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _GatedAnalyticsWrapper(
                  destination: const SeatClassStatsScreen(),
                  child: _buildWideAnalyticsCard(
                    context,
                    title: 'Premium Cabins',
                    subtitle: '$premiumFlights Business & First Class flights',
                    icon: Icons.airline_seat_flat,
                    iconBg: Color(0xFFFF6B6B),
                    screen: const SeatClassStatsScreen(),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedFlightLogsCard(
      BuildContext context, {
        required int totalFlights,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.flight_takeoff_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Logs',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View all your flights',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalFlights',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'flights',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        // height: double.infinity를 주어 부모 SizedBox(height:160)을 꽉 채우게 함
        height: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // 내용물이 위아래로 적절히 배치되도록 변경
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMapCard(
      BuildContext context, {
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        // height 지정 제거 (부모에서 제어)
        height: double.infinity,
        decoration: BoxDecoration(
          // 더 깊이감 있는 지도로 변경
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0F172A).withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 배경 장식용 지구본 아이콘
            Positioned(
              right: -30,
              top: -20,
              child: Icon(
                Icons.public,
                size: 140,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            // 지도 경로 패턴 (커스텀 페인터)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _MapPatternPainter(),
                ),
              ),
            ),
            // 내용
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(Icons.map_rounded,
                        color: Colors.blue.shade200, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Map',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explore World',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOldRouteMapCard(
      BuildContext context, {
        required int airportCount,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF06B6D4).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 배경 패턴
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CustomPaint(
                  painter: _MapPatternPainter(),
                ),
              ),
            ),
            // 내용
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.map_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Route Map',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View your global flight network',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
      BuildContext context, {
        required int totalFlights,
        required int uniqueRoutes,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics_rounded,
                      color: Color(0xFF667EEA), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Flight Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.grey.shade400, size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalFlights',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Flights',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$uniqueRoutes',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unique Routes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOldOverviewCard(
      BuildContext context, {
        required int totalFlights,
        required int uniqueRoutes,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics_rounded,
                      color: Colors.white, size: 24),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.8), size: 18),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Flight Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalFlights',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Flights',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$uniqueRoutes',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unique Routes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideAnalyticsCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconBg,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAnalyticsCard(
      BuildContext context, {
        required String title,
        required String count,
        required String unit,
        required IconData icon,
        required Color color,
        required Widget screen,
      }) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ⭐️ Analytics 카드를 로그인 없이 탭 시 LoginPromptScreen을 띄우는 래퍼
class _GatedAnalyticsWrapper extends StatelessWidget {
  final Widget child;
  final Widget destination;

  const _GatedAnalyticsWrapper({
    required this.child,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.user == null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LoginPromptScreen(),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      child: AbsorbPointer(child: child),
    );
  }
}
class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. 공항(점) 그리기
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final points = [
      Offset(size.width * 0.2, size.height * 0.4),
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.8),
    ];

    for (var point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    // 2. 비행 경로 (점선 곡선) 그리기
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 점선을 그리는 함수 (간단 구현)
    void drawDashedPath(Path sourcePath) {
      const double dashWidth = 4.0;
      const double dashSpace = 4.0;
      double distance = 0.0;
      // ui.PathMetric으로 수정
      for (final ui.PathMetric metric in sourcePath.computeMetrics()) {
        while (distance < metric.length) {
          canvas.drawPath(
            metric.extractPath(distance, distance + dashWidth),
            pathPaint,
          );
          distance += dashWidth + dashSpace;
        }
      }
    }

    // 경로 1
    final path1 = Path();
    path1.moveTo(points[0].dx, points[0].dy);
    path1.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.1,
      points[1].dx,
      points[1].dy,
    );
    drawDashedPath(path1);

    // 경로 2
    final path2 = Path();
    path2.moveTo(points[1].dx, points[1].dy);
    path2.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.2,
      points[2].dx,
      points[2].dy,
    );
    drawDashedPath(path2);

    // 경로 3
    final path3 = Path();
    path3.moveTo(points[0].dx, points[0].dy);
    path3.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.8,
      points[3].dx,
      points[3].dy,
    );
    drawDashedPath(path3);

    // 경로 4
    final path4 = Path();
    path4.moveTo(points[3].dx, points[3].dy);
    path4.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.9,
      points[4].dx,
      points[4].dy,
    );
    drawDashedPath(path4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}