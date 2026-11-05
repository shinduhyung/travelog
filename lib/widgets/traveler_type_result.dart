import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class TravelerTypeResult extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const TravelerTypeResult({super.key, required this.analysis});

  static const _looks = <String, (IconData, Color, String)>{
    'identity_seeker': (
      Icons.explore_rounded,
      Color(0xFF8B5CF6),
      'Every journey brings you a little closer to yourself.',
    ),
    'sensory_immersionist': (
      Icons.waves_rounded,
      Color(0xFF0891B2),
      'Slow down. Take it all in.',
    ),
    'efficiency_maximizer': (
      Icons.route_rounded,
      Color(0xFF2563EB),
      'A good plan makes room for more adventures.',
    ),
    'cultural_decoder': (
      Icons.museum_rounded,
      Color(0xFFB77924),
      'You look for the stories behind the sights.',
    ),
    'joy_collector': (
      Icons.celebration_rounded,
      Color(0xFFDB2777),
      'The best souvenirs are the moments you love.',
    ),
    'inner_sanctuary_seeker': (
      Icons.spa_rounded,
      Color(0xFF009688),
      'Quiet escapes. Room to breathe.',
    ),
    'wildlife_earth_enthusiast': (
      Icons.forest_rounded,
      Color(0xFF16835D),
      'Your favorite places are shaped by nature.',
    ),
    'global_connector': (
      Icons.diversity_3_rounded,
      Color(0xFFEA580C),
      'New places. New people. Lasting connections.',
    ),
    'freedom_drifter': (
      Icons.air_rounded,
      Color(0xFF0284C7),
      'Leave a little room for the unexpected.',
    ),
    'achievement_hunter': (
      Icons.emoji_events_rounded,
      Color(0xFFAA7B19),
      'There is always another milestone on your map.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final scores = [
      for (final raw in (analysis['summary']?['persona_scores'] as List? ?? []))
        Map<String, dynamic>.from(raw as Map),
    ]..sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    if (scores.isEmpty) return const SizedBox.shrink();
    final top = scores.first;
    final look = _look(top);
    final vector = Map<String, dynamic>.from(
      analysis['full_feature_vector'] as Map? ?? {},
    );
    const traits = {
      'solo_social': (
        'Social explorer',
        'Solo explorer',
        Icons.person_outline_rounded,
      ),
      'nature_culture': (
        'Culture lover',
        'Nature lover',
        Icons.landscape_outlined,
      ),
      'relaxed_intensive': (
        'Full itinerary',
        'Slow traveler',
        Icons.wb_sunny_outlined,
      ),
      'planned_spontaneous': (
        'Go with the flow',
        'Natural planner',
        Icons.route_outlined,
      ),
      'budget_luxury': (
        'Comfort seeker',
        'Budget savvy',
        Icons.wallet_outlined,
      ),
      'transit_drive': (
        'Road tripper',
        'Transit explorer',
        Icons.train_outlined,
      ),
      'documenter_minimalist': (
        'Live in the moment',
        'Memory keeper',
        Icons.photo_camera_outlined,
      ),
      'morning_night': ('Night owl', 'Early bird', Icons.light_mode_outlined),
    };
    final keys =
        traits.keys
            .where((k) => vector[k] is num && (vector[k] as num).abs() >= .15)
            .toList()
          ..sort(
            (a, b) =>
                (vector[b] as num).abs().compareTo((vector[a] as num).abs()),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(look.$2, const Color(0xFF103A3C), .45)!,
                look.$2,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: look.$2.withValues(alpha: .18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(look.$1, color: Colors.white, size: 32),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: (top['score'] as num).toDouble().clamp(0, 1),
                            strokeWidth: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: .18,
                            ),
                          ),
                        ),
                        Text(
                          '${((top['score'] as num) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                tr('YOUR TRAVEL TYPE'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(top['label'] as String),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr(look.$3),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (keys.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in keys.take(4))
                Chip(
                  side: BorderSide.none,
                  backgroundColor: Colors.white,
                  avatar: Icon(traits[key]!.$3, color: look.$2, size: 18),
                  label: Text(
                    tr(
                      (vector[key] as num) >= 0
                          ? traits[key]!.$2
                          : traits[key]!.$1,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Text(
          tr('Your travel mix'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final type in scores)
                  if ((type['score'] as num) > 0)
                    Expanded(
                      flex: ((type['score'] as num) * 100000).round().clamp(
                        1,
                        100000,
                      ),
                      child: ColoredBox(
                        color: _look(type).$2,
                        child: const SizedBox.expand(),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final type in scores.take(3)) _typeRow(type),
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 18),
            title: Text(
              tr('See all 10 types'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            children: [for (final type in scores.skip(3)) _typeRow(type)],
          ),
        ),
      ],
    );
  }

  (IconData, Color, String) _look(Map<String, dynamic> type) =>
      _looks[type['id']] ??
      (
        Icons.travel_explore_rounded,
        const Color(0xFF009688),
        'Find your own way to explore.',
      );

  Widget _typeRow(Map<String, dynamic> type) {
    final look = _look(type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: look.$2.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(look.$1, color: look.$2, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr(type['label'] as String),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${((type['score'] as num) * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: look.$2,
            ),
          ),
        ],
      ),
    );
  }
}
