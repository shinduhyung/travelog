// lib/screens/my_trips_tab_screen.dart
import 'package:flutter/material.dart';
// ⭐️ Firebase Auth와 명칭 충돌을 막기 위해 custom_auth로 alias 지정
import 'package:jidoapp/providers/auth_provider.dart' as custom_auth;
import 'package:jidoapp/screens/profile_screen.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/screens/badges_screen.dart';
import 'package:jidoapp/screens/my_journey_screen.dart';
import 'package:jidoapp/screens/daily_quiz_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/top_cities_screen.dart';
import 'package:jidoapp/screens/top_landmarks_screen.dart';
import 'package:jidoapp/screens/world_discover_screen.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/screens/countries_share.dart';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

class MyTripsTabScreen extends StatefulWidget {
  const MyTripsTabScreen({super.key});

  @override
  State<MyTripsTabScreen> createState() => _MyTripsTabScreenState();
}

class _MyTripsTabScreenState extends State<MyTripsTabScreen> {
  // Daily Quiz state
  bool _quizSolvedToday = false;
  bool _quizLoadingDone = false;

  bool _isSharing = false;
  final ScreenshotController _mapScreenshotController = ScreenshotController();

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final provider = context.read<CountryProvider>();
      final visitedCountries = provider.allCountries
          .where((c) => provider.visitedCountries.contains(c.name))
          .toList();
      final Uint8List? mapImage = await _mapScreenshotController.capture();
      if (!mounted) return;
      await CountriesShare.share(
        context: context,
        mapImage: mapImage ?? Uint8List(0),
        visitedCountries: visitedCountries,
      );
    } catch (e) {
      debugPrint('MyTrips share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  static const Color mint = Color(0xFF00CDB5);
  static const Color darkMint = Color(0xFF009688);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF6366F1);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);
  static const Color skyBlue = Color(0xFF0EA5E9);
  static const Color pink = Color(0xFFEC4899);
  static const Color recommendBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQuizSolvedToday();
    });
  }

  Future<void> _checkQuizSolvedToday() async {
    if (mounted) {
      setState(() {
        _quizSolvedToday = false;
        _quizLoadingDone = false;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _quizLoadingDone = true);
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final year = nowUtc.year.toString();
      final month = nowUtc.month.toString().padLeft(2, '0');
      final day = nowUtc.day.toString().padLeft(2, '0');
      final todayStr = '$year$month$day';

      final historyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quiz_history')
          .doc(todayStr)
          .get();

      if (mounted) {
        setState(() {
          _quizSolvedToday = historyDoc.exists;
          _quizLoadingDone = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _quizLoadingDone = true);
    }
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

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Rookie':
        return const Color(0xFF8B4513);
      case 'Explorer':
        return const Color(0xFFFFA726);
      case 'Nomad':
        return const Color(0xFF66BB6A);
      case 'Adventurer':
        return const Color(0xFF26A69A);
      case 'Globetrotter':
        return const Color(0xFF5C6BC0);
      case 'Worldmaster':
        return const Color(0xFFAB47BC);
      case 'Legend':
        return const Color(0xFFEC407A);
      default:
        return const Color(0xFF8B4513);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Consumer<CountryProvider>(
            builder: (context, countryProvider, _) {
              return Positioned(
                left: -9999,
                top: 0,
                width: 600,
                height: 300,
                child: Screenshot(
                  controller: _mapScreenshotController,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(20, 0),
                        initialZoom: 0.3,
                        interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(urlTemplate: '', backgroundColor: Colors.white),
                        PolygonLayer(
                          polygons: countryProvider.allCountries.expand((country) {
                            final isVisited = countryProvider.visitedCountries.contains(country.name);
                            final color = isVisited
                                ? (countryProvider.continentColors[country.continent] ?? Colors.grey)
                                : Colors.grey.withOpacity(0.15);
                            return country.polygonsData.map((polygonData) => Polygon(
                              points: polygonData.first,
                              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                              color: color,
                              borderColor: Colors.white,
                              borderStrokeWidth: 0.5,
                              isFilled: true,
                            ));
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                        image: DecorationImage(
                          image: AssetImage('assets/icons/app_logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Container(
                        height: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Travelog',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            fontFamily: 'Pretendard',
                            height: 1.0,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 10.0,
                                color: Color.fromARGB(120, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 220, left: 24, right: 24),
                      child: _buildProfileSection(context),
                    ),
                  ],
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Consumer<custom_auth.AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        return Consumer<BadgeProvider>(
          builder: (context, badgeProvider, _) {
            final totalPoints = badgeProvider.achievements
                .where((a) => a.isUnlocked)
                .map((a) => a.points)
                .fold(0, (sum, points) => sum + points);

            final currentLevel = _getCurrentLevel(totalPoints);
            final levelColor = _getLevelColor(currentLevel);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (user == null) {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const LoginPromptScreen(),
                        );
                        if (!context.mounted) return;
                        if (Provider.of<custom_auth.AuthProvider>(context, listen: false).user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Consumer<SubscriptionService>(
                            builder: (context, sub, _) => Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: sub.isPremium
                                        ? const Color(0xFF3DDAD7)
                                        : Colors.grey.shade100,
                                    width: sub.isPremium ? 2.5 : 2),
                                image: user?.photoURL != null
                                    ? DecorationImage(
                                  image: NetworkImage(user!.photoURL!),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                                color: sub.isPremium
                                    ? const Color(0xFF3DDAD7).withOpacity(0.08)
                                    : Colors.grey.shade100,
                              ),
                              child: user?.photoURL == null
                                  ? sub.isPremium
                                  ? const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFF3DDAD7),
                                size: 30,
                              )
                                  : Icon(Icons.person,
                                  color: Colors.grey.shade400, size: 30)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.email ?? 'Sign in to sync',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Consumer<SubscriptionService>(
                                  builder: (context, sub, _) {
                                    if (sub.isPremium) {
                                      return GestureDetector(
                                        onTap: () => SubscriptionSheet.show(context),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF3DDAD7)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Premium Active',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3DDAD7)),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (!sub.hasEverBeenPremium) {
                                      return GestureDetector(
                                        onTap: () => SubscriptionSheet.show(context, onShareTap: _handleShare),
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF8F0),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFFFB347), width: 1.2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🎁', style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 6),
                                              RichText(
                                                text: const TextSpan(
                                                  style: TextStyle(fontSize: 12, height: 1.3),
                                                  children: [
                                                    TextSpan(
                                                      text: 'Try 30 days FREE! ',
                                                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 20),
                  const _DiscoverSection(),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyJourneyScreen(),
                      ),
                    ),
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mint.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.luggage_rounded,
                                  color: darkMint, size: 24)),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('My Journey',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87)),
                                SizedBox(height: 2),
                                Text('Trips, documents & more',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BadgesScreen())),
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: levelColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Image.asset(
                              'assets/badge_levels/${currentLevel.toLowerCase()}.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rank',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade500)),
                                const SizedBox(height: 2),
                                Text(
                                  currentLevel,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: levelColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.shade200)),
                              child: Text('$totalPoints pts',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: levelColor))),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () async {
                      final auth = Provider.of<custom_auth.AuthProvider>(context, listen: false);
                      if (auth.user == null) {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const LoginPromptScreen(),
                        );
                        if (!context.mounted) return;
                        if (Provider.of<custom_auth.AuthProvider>(context, listen: false).user != null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DailyQuizScreen()),
                          );
                          _checkQuizSolvedToday();
                        }
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DailyQuizScreen()),
                        );
                        _checkQuizSolvedToday();
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: !_quizLoadingDone
                                  ? Colors.grey.shade100
                                  : _quizSolvedToday
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: !_quizLoadingDone
                                ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            )
                                : Icon(
                              _quizSolvedToday
                                  ? Icons.check_circle_rounded
                                  : Icons.help_rounded,
                              color: _quizSolvedToday
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6366F1),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Quiz',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  !_quizLoadingDone
                                      ? '...'
                                      : _quizSolvedToday
                                      ? 'Completed today!'
                                      : "Today's quiz is waiting!",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: !_quizLoadingDone
                                        ? Colors.grey.shade400
                                        : _quizSolvedToday
                                        ? const Color(0xFF10B981)
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_quizLoadingDone && !_quizSolvedToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Go!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            )
                          else
                            Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 16),
                  _buildTravelStatsSection(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTravelStatsSection(BuildContext context) {
    final countriesColor = Theme.of(context).primaryColor;
    const citiesColor = Colors.amber;

    return Consumer3<CountryProvider, CityProvider, LandmarksProvider>(
      builder: (context, countryProvider, cityProvider, landmarksProvider, _) {
        final visitedCountryCount = countryProvider.visitedCountries.length;
        final totalCountryCount = countryProvider.allCountries.length;

        final gawcCities = cityProvider.gawcCities
            .where((c) => c.gawcTier != 'N/A')
            .toList();
        final totalGawcCount = gawcCities.length;
        final visitedGawcCount = gawcCities
            .where((c) => cityProvider.visitedCities.contains(c.name))
            .length;

        final topPicks = landmarksProvider.allLandmarks
            .where((l) => l.global_rank > 0)
            .toList()
          ..sort((a, b) => a.global_rank.compareTo(b.global_rank));
        final top250 = topPicks.take(250).toList();
        final visitedTopCount = top250
            .where((l) => landmarksProvider.visitedLandmarks.contains(l.name))
            .length;

        return Column(
          children: [
            _buildStatRow(
              context: context,
              icon: Icons.location_on,
              iconColor: countriesColor,
              labelTop: 'Countries',
              labelBottom: '$visitedCountryCount / $totalCountryCount',
              progressValue: totalCountryCount > 0
                  ? visitedCountryCount / totalCountryCount
                  : 0.0,
              progressColor: countriesColor,
              isAddButton: true,
              isRainbow: false,
              onButtonTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CountriesMapScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _buildStatRow(
              context: context,
              icon: Icons.location_city_rounded,
              iconColor: citiesColor,
              labelTop: 'Top Cities',
              labelBottom: '$visitedGawcCount / $totalGawcCount',
              progressValue: totalGawcCount > 0
                  ? (visitedGawcCount / totalGawcCount).clamp(0.0, 1.0)
                  : 0.0,
              progressColor: citiesColor,
              isAddButton: true,
              isRainbow: false,
              onButtonTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TopCitiesScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _buildStatRow(
              context: context,
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFEC4899),
              labelTop: 'Top Landmarks',
              labelBottom: '$visitedTopCount / 250',
              progressValue: visitedTopCount / 250,
              progressColor: const Color(0xFFEC4899),
              isAddButton: false,
              isRainbow: true,
              onButtonTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TopLandmarksScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String labelTop,
    required String labelBottom,
    required double progressValue,
    required Color progressColor,
    required bool isAddButton,
    required bool isRainbow,
    required VoidCallback onButtonTap,
  }) {
    return Row(
      children: [
        isRainbow
            ? Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEC4899),
                  Color(0xFFF97316),
                  Color(0xFFF59E0B),
                  Color(0xFF22C55E),
                  Color(0xFF0EA5E9),
                  Color(0xFF8B5CF6),
                ],
              ).createShader(bounds),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        )
            : Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labelTop,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    labelBottom,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              isRainbow
                  ? _buildRainbowProgressBar(progressValue.clamp(0.0, 1.0))
                  : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade100,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onButtonTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: isRainbow
                ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEC4899),
                  Color(0xFF8B5CF6),
                  Color(0xFF0EA5E9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            )
                : BoxDecoration(
              color: progressColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: progressColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isAddButton ? Icons.add_rounded : Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRainbowProgressBar(double value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth = totalWidth * value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Container(
                  width: totalWidth,
                  color: Colors.grey.shade100,
                ),
                if (value > 0)
                  Container(
                    width: filledWidth,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFEC4899),
                          Color(0xFFF97316),
                          Color(0xFFF59E0B),
                          Color(0xFF22C55E),
                          Color(0xFF0EA5E9),
                          Color(0xFF8B5CF6),
                        ],
                      ),
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

// ⭐️ Discover 섹션: 앱 전체와 통일된 화이트 카드 스타일. Discover는 헤더(탭 불가)이고,
//    실제 진입점은 하위 3개 옵션(Next Trip / Flight Deals / Hotels) 중 하나를 고르는 구조.
//    움직임 포인트는 헤더 아이콘이 천천히 도는 것 하나로 절제함.
// ⚠️ Next Trip / Flight Deals / Hotels는 전용 화면이 아직 없어서 임시로 WorldDiscoverScreen으로 연결됨.
//    추후 제휴 로드맵(숙소/항공 딥링크)에 맞춰 각각 별도 화면으로 교체 필요.
class _DiscoverSection extends StatefulWidget {
  const _DiscoverSection();

  @override
  State<_DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends State<_DiscoverSection>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _glowController;
  late final Animation<double> _glow;

  static const Color accent = Color(0xFF6D5DF6); // Discover 헤더 아이콘 전용 포인트 컬러
  static const Color orange = Color(0xFFF97316);
  static const Color recommendBlue = Color(0xFF2563EB);
  static const Color pink = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _openDiscover(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorldDiscoverScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withOpacity(0.20 + 0.16 * _glow.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.10 + 0.10 * _glow.value),
                blurRadius: 14 + 8 * _glow.value,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // 헤더 (탭 불가 — Discover 자체는 버튼이 아니라 아래 옵션들의 라벨)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [accent.withOpacity(0.10), accent.withOpacity(0.02)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _spinController.value * 2 * 3.14159265,
                        child: child,
                      );
                    },
                    child: const Icon(Icons.public_rounded, color: accent, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your next destination',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 1),
          // 하위 3개 옵션 — Discover에 속한 선택지로, 하나만 고르는 구조 (같은 카드 안에 세그먼트로 병합)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildOption(
                    context,
                    icon: Icons.search_rounded,
                    label: 'Next Trip',
                    color: recommendBlue,
                  ),
                ),
                VerticalDivider(color: Colors.grey.shade100, width: 1),
                Expanded(
                  child: _buildOption(
                    context,
                    icon: Icons.flight_rounded,
                    label: 'Flight Deals',
                    color: orange,
                  ),
                ),
                VerticalDivider(color: Colors.grey.shade100, width: 1),
                Expanded(
                  child: _buildOption(
                    context,
                    icon: Icons.hotel_rounded,
                    label: 'Hotels',
                    color: pink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
      }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _openDiscover(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}