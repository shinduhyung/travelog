// lib/screens/traveler_type_selector_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/screens/trip_dna_screen.dart';
import 'package:jidoapp/screens/traveler_type_ai_screen.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';

class TravelerTypeSelectorScreen extends StatefulWidget {
  const TravelerTypeSelectorScreen({super.key});

  @override
  State<TravelerTypeSelectorScreen> createState() => _TravelerTypeSelectorScreenState();
}

class _TravelerTypeSelectorScreenState extends State<TravelerTypeSelectorScreen> {
  String? _topTypeLabel;
  double? _topTypeScore;
  String? _topTypeRationale;
  String? _topTypeIconName;

  static const Color mint = Color(0xFF00CDB5);
  static const Color darkMint = Color(0xFF00A99D);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF6366F1);

  static const Map<String, String> _staticDescriptions = {
    'Identity Seeker': 'Travel focused on self-reflection, meaning, and personal growth. They often keep detailed journals or logs of their inner journey.',
    'Sensory Immersionist': 'Prefers slow, relaxed travel, focusing on atmosphere, local views, smells, and sounds. They seek sensory experience over packed schedules.',
    'Efficiency Maximizer': 'Driven to see and do as much as possible in limited time. Highly organized, planning routes, and utilizing checklists to maximize output.',
    'Cultural Decoder': 'Travels with a deep interest in history, context, and politics. They prioritize museums, ancient sites, and understanding local culture deeply.',
    'Joy Collector': 'Focused on fun, enjoyment, and memorable experiences. They enjoy socializing, nightlife, cafes, and collecting moments of pure delight.',
    'Inner Sanctuary Seeker': 'Seeks healing, quiet, and retreat. Prefers peaceful natural settings, beaches, or small towns for wellness and recharging.',
    'Wildlife & Earth Enthusiast': 'Primary motivation is experiencing nature, wildlife, landscapes, national parks, and ecological sites. They love hiking and outdoor exploration.',
    'Global Connector': 'Motivated by meeting new people, connecting with locals, and forming international friendships. They are flexible and prioritize social interactions.',
    'Freedom Drifter': 'Long-term, open-ended travel with maximum spontaneity. They avoid strict schedules and enjoy the simple, unpredictable nature of drifting.',
    'Achievement Hunter': 'Focuses on quantifiable goals like country counts, UNESCO sites visited, or completing specific challenges. They value stats and trophies over relaxation.',
  };

  @override
  void initState() {
    super.initState();
    _loadTravelerTypeResult();
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

  IconData _getTravelerTypeIcon(String? iconName) {
    switch (iconName) {
      case 'self_improvement_outlined': return Icons.self_improvement_outlined;
      case 'camera_roll_outlined': return Icons.camera_roll_outlined;
      case 'speed_outlined': return Icons.speed_outlined;
      case 'museum_outlined': return Icons.museum_outlined;
      case 'celebration_outlined': return Icons.celebration_outlined;
      case 'spa_outlined': return Icons.spa_outlined;
      case 'forest_outlined': return Icons.forest_outlined;
      case 'people_alt_outlined': return Icons.people_alt_outlined;
      case 'directions_car_filled_outlined': return Icons.directions_car_filled_outlined;
      case 'emoji_events_outlined': return Icons.emoji_events_outlined;
      default: return Icons.person_outline;
    }
  }

  Future<void> _loadTravelerTypeResult() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('ai_analysis_result');

    if (savedJson != null) {
      try {
        final parsed = jsonDecode(savedJson) as Map<String, dynamic>;
        final types = (parsed['summary']?['persona_scores'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final summary = parsed['summary'] as Map<String, dynamic>?;

        if (types.isNotEmpty) {
          types.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
          final topType = types.first;

          final label = topType['label'] as String? ?? 'Unknown';
          final score = topType['score'] as num? ?? 0.0;
          final rationale = summary?['top_type_rationale'] as String?;
          final iconName = _getIconNameForType(label);

          if (mounted) {
            setState(() {
              _topTypeLabel = label;
              _topTypeScore = score.toDouble();
              _topTypeRationale = rationale;
              _topTypeIconName = iconName;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _topTypeLabel = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 여백
            const SizedBox(height: 40),

            // 스크롤 가능한 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타이틀 영역
                      _buildHeader(),
                      const SizedBox(height: 32),

                      // 결과 표시 영역 (고정 높이)
                      _buildResultDisplay(),
                      const SizedBox(height: 40),

                      // 기능 카드들
                      _buildFeatureOptions(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: mint.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'YOUR PROFILE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: darkMint,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Travel Type',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [mint, darkMint],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 25,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    final hasResult = _topTypeLabel != null;

    // 고정 높이 컨테이너
    return SizedBox(
      height: 280,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasResult ? mint.withOpacity(0.3) : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: hasResult
                  ? darkMint.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: hasResult
            ? _buildResultContent()
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildResultContent() {
    final icon = _getTravelerTypeIcon(_topTypeIconName);
    final score = _topTypeScore ?? 0.0;
    final scoreString = '${(score * 100).toStringAsFixed(0)}%';
    // AI rationale이 없으면 static description 사용
    final rationale = _topTypeRationale ?? _staticDescriptions[_topTypeLabel] ?? 'No description available.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [mint, darkMint],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: mint.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _topTypeLabel!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: darkMint.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      scoreString,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: darkMint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              rationale,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey[700],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.psychology_alt_outlined,
          size: 56,
          color: Colors.grey[350],
        ),
        const SizedBox(height: 20),
        Text(
          'No Analysis Yet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete a test below to discover\nyour travel personality type',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureOptions(BuildContext context) {
    return Column(
      children: [
        _buildOptionCard(
          context: context,
          title: 'Travel DNA Test',
          subtitle: '60-question personality quiz',
          icon: Icons.quiz_outlined,
          gradientColors: const [mint, darkMint],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TripDnaScreen(),
              ),
            );
            _loadTravelerTypeResult();
          },
        ),
        const SizedBox(height: 20),
        _buildOptionCard(
          context: context,
          title: 'Traveler Type AI',
          subtitle: 'Advanced travel behavior analysis',
          icon: Icons.psychology_alt_outlined,
          gradientColors: const [purple, blue],
          onTap: () async {
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
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TravelerTypeAiScreen(),
              ),
            );
            _loadTravelerTypeResult();
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: gradientColors.first.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}