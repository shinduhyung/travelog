// lib/screens/my_journey_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
// ⭐️ Firebase Auth와 명칭 충돌을 막기 위해 custom_auth로 alias 지정
import 'package:jidoapp/providers/auth_provider.dart' as custom_auth;
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/screens/calendar_screen.dart';
import 'package:jidoapp/screens/passport_screen.dart';
import 'package:jidoapp/screens/settings_screen.dart';
import 'package:jidoapp/screens/visa_screen.dart';
import 'package:jidoapp/screens/trip_log_list_screen.dart';
import 'package:jidoapp/screens/recommendations_screen.dart';
import 'package:jidoapp/screens/favorites_screen.dart';
import 'package:jidoapp/screens/traveler_type_selector_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyJourneyScreen extends StatefulWidget {
  const MyJourneyScreen({super.key});

  @override
  State<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends State<MyJourneyScreen> {
  String? _travelerType;
  String? _travelerTypeIconName;

  static const Color mint = Color(0xFF00CDB5);
  static const Color darkMint = Color(0xFF009688);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);
  static const Color pink = Color(0xFFEC4899);
  static const Color recommendBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTravelerType();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Journey',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTravelerTypeCard(context),
              const SizedBox(height: 24),
              _buildMainFeatures(context),
              const SizedBox(height: 32),
              Row(
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
              const SizedBox(height: 16),
              _buildDocumentsSection(context),
              const SizedBox(height: 16),
              _buildSettingsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTravelerTypeCard(BuildContext context) {
    return GestureDetector(
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getTravelerTypeIcon(), color: darkMint, size: 24)),
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
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
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
                    'AI Match',
                    '',
                    Icons.lightbulb_rounded,
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