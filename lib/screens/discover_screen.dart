import 'travelog_polls_screen.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'recommendations_screen.dart';
import 'traveler_type_ai_screen.dart';
import 'discover_quiz_screen.dart';
import 'country_twin_screen.dart';
import 'tourist_local_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final features = <(String, String, IconData, Color, Widget)>[
      (
        'Traveler Type AI',
        'Meet your travel self.',
        Icons.fingerprint_rounded,
        const Color(0xFF0F766E),
        const TravelerTypeAiScreen(),
      ),
      (
        'AI Recommendation',
        'Find your next stop.',
        Icons.travel_explore_rounded,
        const Color(0xFF2563EB),
        const RecommendationsScreen(),
      ),
      (
        'Travel Soulmate',
        'Find your travel soulmate.',
        Icons.public_rounded,
        const Color(0xFF009688),
        const CountryTwinScreen(),
      ),
      (
        'Travelog Polls',
        'One question. Your pick.',
        Icons.how_to_vote_rounded,
        const Color(0xFFDF705D),
        const TravelogPollsScreen(),
      ),
      (
        'Tourist vs Local',
        'Find your travel style.',
        Icons.explore_rounded,
        const Color(0xFFEA580C),
        const TouristLocalScreen(),
      ),
      (
        'Travel Survival',
        'Test your travel skills.',
        Icons.backpack_rounded,
        const Color(0xFF0891B2),
        const DiscoverQuizScreen(quizId: 'survival'),
      ),
      (
        'Overpaying Test',
        'Check your price sense.',
        Icons.price_check_rounded,
        const Color(0xFFDB2777),
        const DiscoverQuizScreen(quizId: 'savvy'),
      ),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = (MediaQuery.sizeOf(context).width - 158).clamp(
      80.0,
      double.infinity,
    );
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: tr(text), style: style),
        maxLines: 2,
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: textWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 17,
      height: 1.2,
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontSize: 13, height: 1.35);
    final titleHeight = features
        .map((f) => measure(f.$1, titleStyle))
        .reduce((a, b) => a > b ? a : b);
    final subtitleHeight = features
        .map((f) => measure(f.$2, subtitleStyle))
        .reduce((a, b) => a > b ? a : b);
    final contentHeight = titleHeight + 4 + subtitleHeight;
    final tileHeight = 32.0 + (contentHeight > 44 ? contentHeight : 44.0);
    return DiscoverScaffold(
      appBar: AppBar(
        title: Text(tr('Discover'), maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFFF8FAFC),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (var i = 0; i < features.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                key: ValueKey('discover-feature-$i'),
                height: tileHeight,
                child: Material(
                  color: i == 0
                      ? features[i].$4
                      : Color.lerp(Colors.white, features[i].$4, .09),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: features[i].$4.withValues(alpha: .18),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => features[i].$5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? Colors.white.withValues(alpha: .14)
                                  : features[i].$4,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              features[i].$3,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: titleHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      tr(features[i].$1),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: i == 0
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: subtitleHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      tr(features[i].$2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: i == 0
                                            ? Colors.white70
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: i == 0 ? Colors.white : features[i].$4,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
