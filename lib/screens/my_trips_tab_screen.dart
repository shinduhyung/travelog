// lib/screens/my_trips_tab_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
// ⭐️ Firebase Auth와 명칭 충돌을 막기 위해 custom_auth로 alias 지정
import 'package:jidoapp/providers/auth_provider.dart' as custom_auth;
import 'package:jidoapp/screens/profile_screen.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/screens/badges_screen.dart';
import 'package:jidoapp/screens/calendar_screen.dart';
import 'package:jidoapp/screens/passport_screen.dart';
import 'package:jidoapp/screens/settings_screen.dart';
import 'package:jidoapp/screens/visa_screen.dart';
import 'package:jidoapp/screens/trip_log_list_screen.dart';
import 'package:jidoapp/screens/recommendations_screen.dart';
import 'package:jidoapp/screens/favorites_screen.dart';
import 'package:jidoapp/screens/traveler_type_selector_screen.dart';
import 'package:jidoapp/screens/daily_quiz_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/top_cities_screen.dart';
import 'package:jidoapp/screens/top_landmarks_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/widgets/premium_theme.dart';
import 'package:jidoapp/screens/countries_share.dart';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

// ─────────────────────────────────────────────
// 업데이트된 기능(뱃지 400+, 데일리 퀴즈 Expert 모드) 안내용 반짝이는 NEW 태그.
// 은은하게 커졌다 작아졌다 하면서 살짝 발광하는 느낌을 준다.
// ─────────────────────────────────────────────
class _SparkleNewBadge extends StatefulWidget {
  const _SparkleNewBadge();

  @override
  State<_SparkleNewBadge> createState() => _SparkleNewBadgeState();
}

class _SparkleNewBadgeState extends State<_SparkleNewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.92, end: 1.12)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFFFB300)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withOpacity(0.6),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white),
            SizedBox(width: 2),
            Text(
              'NEW',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyTripsTabScreen extends StatefulWidget {
  const MyTripsTabScreen({super.key});

  @override
  State<MyTripsTabScreen> createState() => _MyTripsTabScreenState();
}

class _MyTripsTabScreenState extends State<MyTripsTabScreen> {
  String? _travelerType;
  String? _travelerTypeIconName;

  // Daily Quiz state
  bool _quizSolvedToday = false;
  bool _quizLoadingDone = false;
  // 사용자가 DailyQuizScreen에서 "Set as my default"로 저장해둔 기본 모드.
  // My Trips 카드와 알림 모두 이 값을 기준으로 Normal/Expert를 보여줌.
  static const String _prefKeyDefaultQuizMode = 'daily_quiz_default_mode';
  bool _quizDefaultIsExpert = false;
  static const List<Color> _quizNormalGradient = [Color(0xFF6366F1), Color(0xFF4F46E5)];
  static const List<Color> _quizExpertGradient = [Color(0xFF7C3AED), Color(0xFFDB2777)];

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
      _loadTravelerType();
      _loadQuizDefaultMode();
    });
  }

  Future<void> _loadQuizDefaultMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyDefaultQuizMode);
      final isPremium = SubscriptionService.instance.isPremium;
      // 저장된 기본값이 Expert인데 지금은 구독자가 아니면(만료 등) Normal로 안전하게 폴백
      final isExpert = saved == 'expert' && isPremium;
      if (mounted) setState(() => _quizDefaultIsExpert = isExpert);
    } catch (e) {
      debugPrint('Error loading quiz default mode: $e');
    } finally {
      _checkQuizSolvedToday();
    }
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
          .collection(_quizDefaultIsExpert ? 'quiz_history_expert' : 'quiz_history')
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

  Future<void> _loadTravelerType() async {
    final prefs = await SharedPreferences.getInstance();
    String? typeName;
    final aiJson = prefs.getString('ai_analysis_result');
    if (aiJson != null) {
      try {
        final parsed = jsonDecode(aiJson) as Map<String, dynamic>;
        final types = (parsed['summary']?['persona_scores'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (types.isNotEmpty) {
          types.sort((a, b) =>
              (b['score'] as num).compareTo(a['score'] as num));
          typeName = types.first['label'] as String?;
        }
      } catch (e) {
        debugPrint('Error parsing AI result: $e');
      }
    }
    typeName ??= prefs.getString('traveler_type');
    if (mounted) {
      setState(() {
        _travelerType = typeName;
        _travelerTypeIconName = _getIconNameForType(typeName);
      });
    }
  }

  String? _getIconNameForType(String? typeName) {
    if (typeName == null || typeName.isEmpty) return null;
    final map = {
      'Identity Seeker': 'self_improvement_outlined',
      'Sensory Immersionist': 'camera_roll_outlined',
      'Efficiency Maximizer': 'speed_outlined',
      'Cultural Decoder': 'museum_outlined',
      'Joy Collector': 'celebration_outlined',
      'Inner Sanctuary Seeker': 'spa_outlined',
      'Wildlife & Earth Enthusiast': 'forest_outlined',
      'Global Connector': 'people_alt_outlined',
      'Freedom Drifter': 'directions_car_filled_outlined',
      'Achievement Hunter': 'emoji_events_outlined',
    };
    return map[typeName];
  }

  IconData _getTravelerTypeIcon() {
    switch (_travelerTypeIconName) {
      case 'self_improvement_outlined':
        return Icons.self_improvement_outlined;
      case 'camera_roll_outlined':
        return Icons.camera_roll_outlined;
      case 'speed_outlined':
        return Icons.speed_outlined;
      case 'museum_outlined':
        return Icons.museum_outlined;
      case 'celebration_outlined':
        return Icons.celebration_outlined;
      case 'spa_outlined':
        return Icons.spa_outlined;
      case 'forest_outlined':
        return Icons.forest_outlined;
      case 'people_alt_outlined':
        return Icons.people_alt_outlined;
      case 'directions_car_filled_outlined':
        return Icons.directions_car_filled_outlined;
      case 'emoji_events_outlined':
        return Icons.emoji_events_outlined;
      default:
        return Icons.person_outline;
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
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildMainFeatures(context),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                            color: darkMint,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'My Documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildDocumentsSection(context),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSettingsCard(context),
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
                            builder: (context, sub, _) {
                              const double avatarSize = 60;
                              final kind = sub.activePlanKind;
                              final colors = PremiumTheme.colorsFor(kind);

                              if (!sub.isPremium) {
                                // 원래 그대로: 단일 컨테이너에 테두리만 페인트
                                // (테두리가 레이아웃 크기를 차지하지 않음).
                                return Container(
                                  width: avatarSize,
                                  height: avatarSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade100, width: 2),
                                    image: user?.photoURL != null
                                        ? DecorationImage(
                                      image: NetworkImage(user!.photoURL!),
                                      fit: BoxFit.cover,
                                    )
                                        : null,
                                    color: Colors.grey.shade100,
                                  ),
                                  child: user?.photoURL == null
                                      ? Icon(Icons.person, color: Colors.grey.shade400, size: 30)
                                      : null,
                                );
                              }

                              // 그라디언트 테두리는 바깥에 두께만큼 패딩을 더하는
                              // 방식이라, 전체가 60x60을 유지하려면 안쪽 원의
                              // 크기를 테두리 두께만큼 미리 줄여야 함.
                              final double borderWidth =
                              kind == PremiumPlanKind.lifetime ? 2.5 : 2;
                              final double coreSize = avatarSize - borderWidth * 2;

                              final Widget avatarCore = Container(
                                width: coreSize,
                                height: coreSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: user?.photoURL != null
                                      ? DecorationImage(
                                    image: NetworkImage(user!.photoURL!),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                  color: colors[0].withOpacity(0.1),
                                ),
                                child: user?.photoURL == null
                                    ? Icon(Icons.workspace_premium_rounded, color: colors[0], size: 28)
                                    : null,
                              );

                              // borderRadius = 절반 크기로 두면 정사각형
                              // 컨테이너가 완전한 원으로 보임.
                              return PremiumGradientBorder(
                                colors: colors,
                                animated: PremiumTheme.isVivid(kind),
                                borderWidth: borderWidth,
                                borderRadius: avatarSize / 2,
                                child: avatarCore,
                              );
                            },
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
                                      final kind = sub.activePlanKind;
                                      final colors = PremiumTheme.colorsFor(kind);
                                      return GestureDetector(
                                        onTap: () => SubscriptionSheet.show(context, triggerContext: 'my_trips_header'),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 13, color: colors[0]),
                                            const SizedBox(width: 4),
                                            if (PremiumTheme.isVivid(kind))
                                              ShaderMask(
                                                shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
                                                child: const Text(
                                                  'Lifetime Premium',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                                ),
                                              )
                                            else
                                              Text(
                                                'Premium Active',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors[0]),
                                              ),
                                          ],
                                        ),
                                      );
                                    } else if (!sub.hasEverBeenPremium) {
                                      // 눈에 잘 띄는 그라디언트 프로모 — yearly 테마로
                                      // (가장 추천하는 플랜과 톤을 맞춤).
                                      return GestureDetector(
                                        onTap: () => SubscriptionSheet.show(context, triggerContext: 'my_trips_promo'),
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: PremiumTheme.yearly,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: PremiumTheme.yearly[0].withOpacity(0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text(
                                                'Go Premium',
                                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
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

                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TravelerTypeSelectorScreen(),
                        ),
                      );
                      _loadTravelerType();
                    },
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
                              child: Icon(_getTravelerTypeIcon(),
                                  color: darkMint, size: 24)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Traveler Type',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade500)),
                                const SizedBox(height: 2),
                                Text(
                                    _travelerType?.isNotEmpty == true
                                        ? _travelerType!
                                        : 'Analyze DNA',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _travelerType?.isNotEmpty == true
                                            ? Colors.black87
                                            : Colors.grey.shade400)),
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
                          Stack(
                            clipBehavior: Clip.none,
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
                              // [추가] 뱃지 400+ 추가 업데이트 안내용 반짝이는 NEW 태그
                              const Positioned(
                                top: -8,
                                right: -8,
                                child: _SparkleNewBadge(),
                              ),
                            ],
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
                            MaterialPageRoute(builder: (_) => const DailyQuizScreen(useSavedDefaultMode: true)),
                          );
                          _loadQuizDefaultMode();
                        }
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DailyQuizScreen(useSavedDefaultMode: true)),
                        );
                        _loadQuizDefaultMode();
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: !_quizLoadingDone
                                      ? Colors.grey.shade100
                                      : _quizSolvedToday
                                      ? const Color(0xFF10B981).withOpacity(0.1)
                                      : (_quizDefaultIsExpert ? _quizExpertGradient.first : _quizNormalGradient.first)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: (_quizLoadingDone && !_quizSolvedToday && _quizDefaultIsExpert)
                                      ? Border.all(color: _quizExpertGradient.first.withOpacity(0.35), width: 1.5)
                                      : null,
                                  boxShadow: (_quizLoadingDone && !_quizSolvedToday && _quizDefaultIsExpert)
                                      ? [
                                    BoxShadow(
                                      color: _quizExpertGradient.first.withOpacity(0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                      : null,
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
                                    : _quizSolvedToday
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24)
                                    : _quizDefaultIsExpert
                                    ? ShaderMask(
                                  shaderCallback: (bounds) =>
                                      LinearGradient(colors: _quizExpertGradient).createShader(bounds),
                                  child: const Icon(Icons.local_fire_department_rounded,
                                      color: Colors.white, size: 24),
                                )
                                    : const Icon(Icons.help_rounded, color: Color(0xFF6366F1), size: 24),
                              ),
                              // [추가] 데일리 퀴즈 Expert 모드 업데이트 안내용 반짝이는 NEW 태그
                              const Positioned(
                                top: -8,
                                right: -8,
                                child: _SparkleNewBadge(),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _quizDefaultIsExpert
                                    ? ShaderMask(
                                  shaderCallback: (bounds) =>
                                      LinearGradient(colors: _quizExpertGradient).createShader(bounds),
                                  child: const Text(
                                    'Daily Quiz · Expert',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                )
                                    : Text(
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
                                gradient: LinearGradient(
                                  colors: _quizDefaultIsExpert ? _quizExpertGradient : _quizNormalGradient,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Go!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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

  Widget _buildMainFeatures(BuildContext context) {
    void gated(VoidCallback action) async {
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
          action();
        }
        return;
      }
      action();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildFeatureCard(
                    context,
                    'Trip Log',
                    '',
                    Icons.auto_stories_rounded,
                    orange,
                        () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripLogListScreen()))))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildFeatureCard(
                    context,
                    'Discover',
                    '',
                    Icons.search_rounded,
                    recommendBlue,
                        () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen()))))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildFeatureCard(
                    context,
                    'Favorites',
                    '',
                    Icons.favorite_rounded,
                    pink,
                        () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))))),
          ],
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
            context,
            'Calendar',
            'Plan your next adventure',
            Icons.calendar_month_rounded,
            red,
                () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))),
            isWide: true),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap,
      {bool isWide = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        EdgeInsets.symmetric(vertical: 20, horizontal: isWide ? 20 : 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: isWide
            ? Row(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500)),
                    ]
                  ])),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.grey.shade300)
        ])
            : Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
        ]),
      ),
    );
  }

  Widget _buildDocumentsSection(BuildContext context) {
    void gated(VoidCallback action) async {
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
          action();
        }
        return;
      }
      action();
    }

    return Row(children: [
      Expanded(
          child: _buildDocCard(
              context,
              'Passport',
              Icons.book_rounded,
              purple,
                  () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportScreen()))))),
      const SizedBox(width: 12),
      Expanded(
          child: _buildDocCard(
              context,
              'Visa',
              Icons.article_rounded,
              mint,
                  () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisaScreen()))))),
    ]);
  }

  Widget _buildDocCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Column(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87))
            ])));
  }

  Widget _buildSettingsCard(BuildContext context) {
    return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Row(children: [
              Icon(Icons.settings_outlined,
                  color: Colors.grey.shade700, size: 24),
              const SizedBox(width: 16),
              const Expanded(
                  child: Text('Settings',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87))),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade300)
            ])));
  }
}