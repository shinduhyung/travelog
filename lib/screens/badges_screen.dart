// lib/screens/badges_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/economy_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart'; // [수정 1] 추가
import 'package:provider/provider.dart';
import 'badge_detail_screen.dart';
import 'package:jidoapp/screens/badge_share.dart';
import 'dart:ui';
import 'dart:math';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _showUnlocked = true;
  bool _showLocked = true;
  AchievementCategory? _selectedCategory; // null이면 전체 표시
  bool _isCategoryDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    context.read<EconomyProvider>().loadEconomyData();
  }

  // [수정됨] 색상 매핑 업데이트
  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.Country:
        return const Color(0xFF3B82F6); // Blue (변경됨: 민트 -> 파랑)
      case AchievementCategory.City:
        return const Color(0xFFFBBF24); // Orange/Yellow
      case AchievementCategory.Landmarks:
        return const Color(0xFF66BB6A); // Green (변경됨: 드롭다운과 일치)
      case AchievementCategory.Flight:
        return const Color(0xFFAB47BC); // Purple (변경됨: 드롭다운과 일치)
      default:
        return Colors.grey;
    }
  }

  String _formatPopulation(int? value) {
    if (value == null || value == 0) return '0.00B';
    const int billion = 1000000000;
    return '${(value / billion).toStringAsFixed(2)}B';
  }

  String _formatArea(int? value) {
    if (value == null || value == 0) return '0.00M km²';
    const int million = 1000000;
    return '${(value / million).toStringAsFixed(2)}M km²';
  }

  String _formatGdp(int? value) {
    if (value == null || value == 0) return '0.00T USD';
    double val = value.toDouble();
    const double trillion = 1000000000000.0;
    return '${(val / trillion).toStringAsFixed(2)}T USD';
  }

  // Level theme colors
  Color _getLevelColor(String level) {
    switch (level) {
      case 'Rookie':
        return const Color(0xFF8B4513); // Brown
      case 'Explorer':
        return const Color(0xFFFFA726); // Orange/Yellow
      case 'Nomad':
        return const Color(0xFF66BB6A); // Green
      case 'Adventurer':
        return const Color(0xFF26A69A); // Mint
      case 'Globetrotter':
        return const Color(0xFF5C6BC0); // Navy/Indigo
      case 'Worldmaster':
        return const Color(0xFFAB47BC); // Purple
      case 'Legend':
        return const Color(0xFFEC407A); // Pink
      default:
        return const Color(0xFF8B4513);
    }
  }

  String _getLevelImagePath(String level) {
    return 'assets/badge_levels/${level.toLowerCase()}.png';
  }

  String _getCurrentLevel(int points) {
    if (points >= 600) return 'Legend';
    if (points >= 400) return 'Worldmaster';
    if (points >= 200) return 'Globetrotter';
    if (points >= 100) return 'Adventurer';
    if (points >= 50) return 'Nomad';
    if (points >= 10) return 'Explorer';
    return 'Rookie';
  }

  @override
  Widget build(BuildContext context) {
    final badgeProvider = context.watch<BadgeProvider>();
    final countryProvider = context.watch<CountryProvider>();
    final cityProvider = context.watch<CityProvider>();
    final economyProvider = context.watch<EconomyProvider>();
    final airlineProvider = context.watch<AirlineProvider>();
    final airportProvider = context.watch<AirportProvider>();
    final landmarksProvider = context.watch<LandmarksProvider>();
    final unescoProvider = context.watch<UnescoProvider>(); // [수정 2] 추가

    if (economyProvider.isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final allAchievements = badgeProvider.achievements;

    final filteredAchievements = allAchievements.where((a) {
      // 카테고리 필터
      if (_selectedCategory != null && a.category != _selectedCategory) {
        return false;
      }
      // Unlocked/Locked 필터
      if (_showUnlocked && _showLocked) return true;
      if (_showUnlocked) return a.isUnlocked;
      if (_showLocked) return !a.isUnlocked;
      return false;
    }).toList();

    final totalPossiblePoints = allAchievements
        .map((a) => a.points)
        .fold(0, (sum, points) => sum + points);

    final currentPoints = allAchievements
        .where((a) => a.isUnlocked)
        .map((a) => a.points)
        .fold(0, (sum, points) => sum + points);

    final levelThresholds = [
      {'points': 0, 'label': 'Start'},
      {'points': 10, 'label': 'Explorer'},
      {'points': 50, 'label': 'Nomad'},
      {'points': 100, 'label': 'Adventurer'},
      {'points': 200, 'label': 'Globetrotter'},
      {'points': 400, 'label': 'Worldmaster'},
      {'points': 600, 'label': 'Legend'},
    ];

    final currentLevel = _getCurrentLevel(currentPoints);
    final currentLevelColor = _getLevelColor(currentLevel);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Level Info + Zigzag Bar)
            _buildHeader(currentPoints, totalPossiblePoints, currentLevel, levelThresholds),

            // 2. Unified Category Filter (Integrated Dropdown)
            _buildUnifiedCategoryFilter(currentLevelColor),

            // 3. Badge Grid
            Expanded(
              child: filteredAchievements.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_list_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "No badges match filters",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: filteredAchievements.length,
                itemBuilder: (context, index) {
                  final achievement = filteredAchievements[index];
                  return _buildBadgeGridItem(
                    achievement,
                    badgeProvider,
                    countryProvider,
                    cityProvider,
                    economyProvider,
                    airlineProvider,
                    airportProvider,
                    landmarksProvider,
                    unescoProvider, // [수정] unescoProvider 추가 전달
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int currentPoints, int totalPossiblePoints, String currentLevel, List<Map<String, Object>> levelThresholds) {
    final levelColor = _getLevelColor(currentLevel);
    final levelImagePath = _getLevelImagePath(currentLevel);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        children: [
          // Level Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: levelColor,
                      width: 3,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    levelImagePath,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: levelColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'CURRENT RANK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: levelColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentLevel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: levelColor,
                          height: 1.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // [메인 헤더] 점수 표시
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currentPoints',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: levelColor,
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'POINTS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: levelColor.withOpacity(0.6),
                              letterSpacing: 3.0,
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

          const SizedBox(height: 12),

          // Progress bar container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: _buildZigzagProgressBar(currentPoints, totalPossiblePoints, levelThresholds, levelColor),
          ),
        ],
      ),
    );
  }

  // --- Zigzag Progress Bar & Buttons Logic ---

  Widget _buildZigzagProgressBar(int currentPoints, int totalPossiblePoints, List<Map<String, Object>> levelThresholds, Color levelColor) {
    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final barHeight = 12.0;

          final y1 = 30.0;
          final y2 = 80.0;
          final y3 = 130.0;

          final rowLen = width;
          final connLen = y2 - y1;

          final totalPathLen = (rowLen * 3) + (connLen * 2);

          final double progressRatio = totalPossiblePoints > 0
              ? (currentPoints / totalPossiblePoints).clamp(0.0, 1.0)
              : 0.0;
          final double currentDrawLen = totalPathLen * progressRatio;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Background Track
              _buildTrackBackground(width, barHeight, y1, y2, y3),

              // 2. Active Progress Track
              ..._buildActiveTrack(currentDrawLen, width, barHeight, y1, y2, y3, levelColor),

              // 3. Level Buttons
              ...levelThresholds.map((threshold) {
                final int pts = threshold['points'] as int;
                final String label = threshold['label'] as String;
                if (pts == 0) return const SizedBox.shrink();

                final double ptRatio = totalPossiblePoints > 0 ? pts / totalPossiblePoints : 0.0;
                final double targetDist = totalPathLen * ptRatio;

                final Offset pos = _getCoordinateOnZigzag(targetDist, width, y1, y2, y3, barHeight);
                final bool isReached = currentPoints >= pts;
                final Color btnColor = isReached ? _getLevelColor(label) : Colors.grey[400]!;

                return Positioned(
                  left: pos.dx - 18,
                  top: pos.dy - 18 + (barHeight / 2),
                  child: GestureDetector(
                    onTap: () => _showLevelDialog(context, label, pts, currentPoints, btnColor),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: btnColor, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: btnColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isReached
                                ? Icon(Icons.check_rounded, color: btnColor, size: 20)
                                : Icon(Icons.lock_outline_rounded, color: btnColor, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackBackground(double w, double h, double y1, double y2, double y3) {
    return Stack(
      children: [
        Positioned(left: 0, top: y1, width: w, height: h, child: _grayBar()),
        Positioned(right: 0, top: y1, width: h, height: (y2 - y1) + h, child: _grayBar()),
        Positioned(left: 0, top: y2, width: w, height: h, child: _grayBar()),
        Positioned(left: 0, top: y2, width: h, height: (y3 - y2) + h, child: _grayBar()),
        Positioned(left: 0, top: y3, width: w, height: h, child: _grayBar()),
      ],
    );
  }

  Widget _grayBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  List<Widget> _buildActiveTrack(double dist, double w, double h, double y1, double y2, double y3, Color color) {
    List<Widget> widgets = [];
    double remaining = dist;
    double connH = y2 - y1;

    // Row 1
    if (remaining > 0) {
      double segLen = remaining.clamp(0.0, w);
      widgets.add(Positioned(left: 0, top: y1, width: segLen, height: h, child: _colorBar(color)));
      remaining -= w;
    }
    // Conn 1
    if (remaining > 0) {
      double segLen = remaining.clamp(0.0, connH);
      widgets.add(Positioned(right: 0, top: y1, width: h, height: segLen + h, child: _colorBar(color)));
      remaining -= connH;
    }
    // Row 2
    if (remaining > 0) {
      double segLen = remaining.clamp(0.0, w);
      widgets.add(Positioned(right: 0, top: y2, width: segLen, height: h, child: _colorBar(color)));
      remaining -= w;
    }
    // Conn 2
    if (remaining > 0) {
      double segLen = remaining.clamp(0.0, connH);
      widgets.add(Positioned(left: 0, top: y2, width: h, height: segLen + h, child: _colorBar(color)));
      remaining -= connH;
    }
    // Row 3
    if (remaining > 0) {
      double segLen = remaining.clamp(0.0, w);
      widgets.add(Positioned(left: 0, top: y3, width: segLen, height: h, child: _colorBar(color)));
    }

    return widgets;
  }

  Widget _colorBar(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Offset _getCoordinateOnZigzag(double d, double w, double y1, double y2, double y3, double h) {
    double remaining = d;
    double connH = y2 - y1;

    if (remaining <= w) return Offset(remaining.clamp(0, w), y1);
    remaining -= w;
    if (remaining <= connH) return Offset(w - h + (h/2), y1 + remaining);
    remaining -= connH;
    if (remaining <= w) return Offset(w - remaining, y2);
    remaining -= w;
    if (remaining <= connH) return Offset(0, y2 + remaining);
    remaining -= connH;
    return Offset(remaining.clamp(0, w), y3);
  }


  // --- Unified Category Filter (Integrated Dropdown) ---

  Widget _buildUnifiedCategoryFilter(Color currentLevelColor) {
    final categories = [
      {'label': 'All', 'category': null, 'icon': Icons.grid_view_rounded, 'color': currentLevelColor},
      {'label': 'Country', 'category': AchievementCategory.Country, 'icon': Icons.public_rounded, 'color': const Color(0xFF3B82F6)},
      {'label': 'City', 'category': AchievementCategory.City, 'icon': Icons.location_city_rounded, 'color': const Color(0xFFFBBF24)},
      {'label': 'Landmarks', 'category': AchievementCategory.Landmarks, 'icon': Icons.landscape_rounded, 'color': const Color(0xFF66BB6A)},
      {'label': 'Flight', 'category': AchievementCategory.Flight, 'icon': Icons.flight_rounded, 'color': const Color(0xFFAB47BC)},
    ];

    final selectedCat = categories.firstWhere(
          (cat) => cat['category'] == _selectedCategory,
      orElse: () => categories[0],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Bar
          GestureDetector(
            onTap: () {
              setState(() {
                _isCategoryDropdownOpen = !_isCategoryDropdownOpen;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: _isCategoryDropdownOpen
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (selectedCat['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            selectedCat['icon'] as IconData,
                            size: 20,
                            color: selectedCat['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedCat['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isCategoryDropdownOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildMiniToggle(
                        icon: Icons.check_circle_rounded,
                        color: currentLevelColor,
                        isActive: _showUnlocked,
                        onTap: () => setState(() => _showUnlocked = !_showUnlocked),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniToggle(
                        icon: Icons.lock_rounded,
                        color: Colors.grey[600]!,
                        isActive: _showLocked,
                        onTap: () => setState(() => _showLocked = !_showLocked),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Dropdown Options
          if (_isCategoryDropdownOpen)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                children: categories.map((cat) {
                  if (cat['category'] == _selectedCategory) return const SizedBox.shrink();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['category'] as AchievementCategory?;
                        _isCategoryDropdownOpen = false;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 20,
                            color: (cat['color'] as Color).withOpacity(0.5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniToggle({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? color : Colors.grey[400],
        ),
      ),
    );
  }

  void _showLevelDialog(BuildContext context, String levelName, int points, int currentPoints, Color levelColor) {
    final isUnlocked = currentPoints >= points;
    final displayColor = isUnlocked ? levelColor : Colors.grey[400]!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: displayColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: displayColor, width: 3),
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/badge_levels/${levelName.toLowerCase()}.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                levelName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: displayColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: displayColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$points Points Required',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: displayColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeGridItem(
      Achievement achievement,
      BadgeProvider badgeProvider,
      CountryProvider countryProvider,
      CityProvider cityProvider,
      EconomyProvider economyProvider,
      AirlineProvider airlineProvider,
      AirportProvider airportProvider,
      LandmarksProvider landmarksProvider,
      UnescoProvider unescoProvider,
      ) {
    return GestureDetector(
      onTap: () => _showBadgeDialog(
        achievement,
        badgeProvider,
        countryProvider,
        cityProvider,
        economyProvider,
        airlineProvider,
        airportProvider,
        landmarksProvider,
        unescoProvider,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        achievement.isUnlocked ? Colors.transparent : Colors.grey,
                        achievement.isUnlocked ? BlendMode.dst : BlendMode.saturation,
                      ),
                      child: Image.asset(
                        achievement.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDialog(
      Achievement achievement,
      BadgeProvider badgeProvider,
      CountryProvider countryProvider,
      CityProvider cityProvider,
      EconomyProvider economyProvider,
      AirlineProvider airlineProvider,
      AirportProvider airportProvider,
      LandmarksProvider landmarksProvider,
      UnescoProvider unescoProvider,
      ) {
    final visitedCountryIsos = countryProvider.visitedCountries
        .map((countryName) => countryProvider.countryNameToIsoMap[countryName])
        .where((iso) => iso != null)
        .map((iso) => iso!)
        .toSet();

    final progressData = badgeProvider.getAchievementProgress(
      achievement,
      visitedCountryIsos,
      countryProvider.allCountries,
      economyProvider.economyData,
      visitedCities: cityProvider.visitedCities.toSet(),
      allCities: cityProvider.allCities,
      totalFlights: airlineProvider.allFlightLogs.fold<int>(0, (sum, log) => sum + log.times),
      visitedAirlines: airlineProvider.airlines.where((a) => a.totalTimes > 0).map((a) => a.code).toSet(),
      visitedAirlineNames: airlineProvider.airlines.where((a) => a.totalTimes > 0).map((a) => a.name).toSet(),
      // [수정: 중요] BadgeProvider 로직 대응을 위한 Code3 Set 전달 (BadgeDetailScreen과 동일하게)
      visitedAirlineCode3s: airlineProvider.airlines.where((a) => a.totalTimes > 0 && a.code3 != null).map((a) => a.code3!).toSet(),
      visitedAirports: airportProvider.visitedAirports,
      visitedLandmarks: landmarksProvider.visitedLandmarks,
      allLandmarks: landmarksProvider.allLandmarks,
      unescoProvider: unescoProvider, // [수정 3] 반영
    );

    int currentRaw = progressData['current'] ?? 0;
    final total = progressData['total'] ?? 1;

    if (achievement.category == AchievementCategory.Landmarks && achievement.targetCount != null) {
      final attribute = badgeProvider.getAttributeForAchievement(achievement.id);
      if (attribute != null) {
        final categoryLandmarks = landmarksProvider.allLandmarks
            .where((l) => l.attributes.contains(attribute))
            .map((l) => l.name)
            .toSet();
        final visitedCategoryLandmarks = landmarksProvider.visitedLandmarks.intersection(categoryLandmarks);
        currentRaw = visitedCategoryLandmarks.length;
      }
    }

    final int current = min(currentRaw, total);
    final double progressVal = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final categoryColor = _getCategoryColor(achievement.category);

    String progressString;
    if (achievement.targetPopulationLimit != null) {
      progressString = '${_formatPopulation(current)} / ${_formatPopulation(total)}';
    } else if (achievement.targetAreaLimit != null) {
      progressString = '${_formatArea(current)} / ${_formatArea(total)}';
    } else if (achievement.targetGdpLimit != null) {
      progressString = '${_formatGdp(current)} / ${_formatGdp(total)}';
    } else {
      progressString = '$current / $total';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: ClipRect(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            achievement.isUnlocked ? Colors.transparent : Colors.grey,
                            achievement.isUnlocked ? BlendMode.dst : BlendMode.saturation,
                          ),
                          child: Image.asset(achievement.imagePath, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          achievement.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+ ${achievement.points}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      achievement.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progress', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text(progressString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            backgroundColor: Colors.grey[200],
                            color: categoryColor,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BadgeDetailScreen(achievement: achievement)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: categoryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('View Checklist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 20, color: Colors.grey[600]),
                    ),
                  ),
                ),

                // 우측 상단 공유 버튼
                Positioned(
                  right: 0,
                  top: 0,
                  child: _BadgeShareButton(
                    achievement: achievement,
                    progress: progressVal,
                    progressDetailText: progressString,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 공유 버튼 위젯
// ─────────────────────────────────────────────

class _BadgeShareButton extends StatefulWidget {
  final Achievement achievement;
  final double progress;
  final String progressDetailText;
  final Color color;

  const _BadgeShareButton({
    required this.achievement,
    required this.progress,
    required this.progressDetailText,
    required this.color,
  });

  @override
  State<_BadgeShareButton> createState() => _BadgeShareButtonState();
}

class _BadgeShareButtonState extends State<_BadgeShareButton> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSharing
          ? null
          : () async {
        setState(() => _isSharing = true);
        await BadgeShare.share(
          context: context,
          achievement: widget.achievement,
          progress: widget.progress,
          progressDetailText: widget.progressDetailText,
        );
        if (mounted) {
          setState(() => _isSharing = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: _isSharing
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.color,
          ),
        )
            : Icon(
          Icons.ios_share_rounded,
          color: widget.color,
          size: 20,
        ),
      ),
    );
  }
}