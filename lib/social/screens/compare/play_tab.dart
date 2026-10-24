import 'package:flutter/material.dart';

import '../../models/social_profile.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../common.dart';
import 'compare_screen.dart';

class PlayTab extends StatelessWidget {
  const PlayTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;
    final now = DateTime.now();
    final gameKeys = {...cmp.me.gameBest.keys, ...cmp.friend.gameBest.keys}.toList()..sort();

    Widget quizSide(SocialProfile p, Color color, String who) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text(who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _ring(context, p.quizNormal, color, 'Normal'),
                  const SizedBox(width: 12),
                  _ring(context, p.quizExpert, color, 'Expert'),
                ]),
              ),
              const SizedBox(height: 10),
              Text('🔥 ${p.quizNormal.streak(now)}-day streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('Best: ${p.quizNormal.bestStreak} days',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
            ]),
          ),
        );

    return TabList(children: [
      SectionCard(
        emoji: '🧠',
        title: 'Daily quiz',
        tint: AppColors.indigo,
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            quizSide(cmp.me, AppColors.me, 'You'),
            const SizedBox(width: 10),
            quizSide(cmp.friend, AppColors.friend, name),
          ]),
          const SizedBox(height: 12),
          VsBar(label: 'Solved', emoji: '📝',
              mine: cmp.me.quizNormal.solved + cmp.me.quizExpert.solved,
              theirs: cmp.friend.quizNormal.solved + cmp.friend.quizExpert.solved),
          VsBar(label: 'Correct', emoji: '✅',
              mine: cmp.me.quizNormal.correct + cmp.me.quizExpert.correct,
              theirs: cmp.friend.quizNormal.correct + cmp.friend.quizExpert.correct),
        ]),
      ),
      SectionCard(
        emoji: '🟩',
        title: 'Quiz calendar',
        tint: AppColors.mint,
        subtitle: 'Last 18 weeks',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.me, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          QuizHeatmap(stats: _merge(cmp.me), color: AppColors.me),
          const SizedBox(height: 14),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.friend, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          QuizHeatmap(stats: _merge(cmp.friend), color: AppColors.friend),
        ]),
      ),
      SectionCard(
        emoji: '🎮',
        title: 'Mini-games',
        tint: AppColors.gold,
        trailing: VsLegend(friendName: name, showBoth: false),
        child: gameKeys.isEmpty
            ? const EmptyHint('Neither of you has mini-game scores yet', emoji: '🕹️')
            : Column(children: [
                for (final k in gameKeys)
                  VsBar(label: gameLabel(k), mine: cmp.me.gameBest[k] ?? 0, theirs: cmp.friend.gameBest[k] ?? 0, format: formatScore),
              ]),
      ),
    ]);
  }

  /// 일반 + 전문가 출석을 합쳐서 (같은 날이면 하나라도 맞히면 정답)
  QuizStats _merge(SocialProfile p) {
    final days = <String, bool>{...p.quizExpert.days};
    p.quizNormal.days.forEach((k, v) => days[k] = (days[k] ?? false) || v);
    return QuizStats(days: days);
  }

  Widget _ring(BuildContext context, QuizStats q, Color color, String label) {
    final theme = Theme.of(context);
    return Column(children: [
      Ring(
        value: q.accuracy,
        color: color,
        size: 66,
        child: Text(q.solved == 0 ? '-' : '${(q.accuracy * 100).round()}%',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 4),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
      Text('${q.correct}/${q.solved}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
    ]);
  }
}
