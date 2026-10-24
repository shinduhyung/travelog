import 'package:flutter/material.dart';

import '../models/duel.dart';
import '../services/social_repository.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import 'common.dart';
import 'duel_game_screen.dart';
import 'new_duel_sheet.dart';
import '../widgets/avatar.dart';

class DuelsScreen extends StatelessWidget {
  const DuelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final theme = Theme.of(context);
    final duels = store.duels;
    final invites = store.incomingInvites;
    final live = store.liveDuels;
    final waiting = store.outgoingInvites;
    final done = store.finishedDuels;
    final wins = done.where((d) => d.winner == store.uid).length;
    final losses = done.where((d) => d.winner != null && d.winner != store.uid).length;
    final nothing = invites.isEmpty && live.isEmpty && waiting.isEmpty && done.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Duels')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-duel',
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        onPressed: () => pickFriendAndDuel(context),
        icon: const Icon(Icons.add),
        label: const Text('New duel'),
      ),
      body: !store.duelsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.vsGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Color(0x336366F1), blurRadius: 20, offset: Offset(0, 10))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$wins W · $losses L',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              done.isEmpty
                                  ? 'Live 1:1 quiz battles with friends'
                                  : '${(wins / done.length * 100).round()}% win rate · ${done.length} ${done.length == 1 ? 'game' : 'games'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (nothing || duels.isEmpty) const EmptyHint('No duels yet.\nTap New duel to challenge a friend!', emoji: '⚔️'),
                if (invites.isNotEmpty) ...[
                  _header(context, Icons.mail_rounded, 'Invites', invites.length, const Color(0xFFEF4444)),
                  for (final d in invites) DuelTile(duel: d),
                  const SizedBox(height: 12),
                ],
                if (live.isNotEmpty) ...[
                  _header(context, Icons.bolt_rounded, 'Live now', live.length, AppColors.mint),
                  for (final d in live) DuelTile(duel: d),
                  const SizedBox(height: 12),
                ],
                if (waiting.isNotEmpty) ...[
                  _header(context, Icons.hourglass_top_rounded, 'Waiting for friend', waiting.length, AppColors.label),
                  for (final d in waiting) DuelTile(duel: d),
                  const SizedBox(height: 12),
                ],
                if (done.isNotEmpty) ...[
                  _header(context, Icons.history_rounded, 'Finished', done.length, AppColors.indigo),
                  for (final d in done.take(50)) DuelTile(duel: d),
                ],
              ],
            ),
    );
  }

  Widget _header(BuildContext context, IconData icon, String text, int n, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4, left: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$text · $n',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class DuelTile extends StatelessWidget {
  const DuelTile({super.key, required this.duel});

  final Duel duel;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final theme = Theme.of(context);
    final uid = store.uid;
    final now = DateTime.now().millisecondsSinceEpoch;
    final opponentUid = duel.opponentOf(uid);
    final opponent = store.friend(opponentUid);
    final name = opponent?.displayName ?? 'Friend';
    final mode = duelModeOf(duel.mode);
    final incoming = duel.inviteOpen(now) && duel.createdBy != uid;

    final (String label, Color color) = switch (duel) {
      _ when incoming => ('Invite', const Color(0xFFEF4444)),
      _ when duel.inviteOpen(now) => ('Waiting', AppColors.label),
      _ when duel.isPlaying && !duel.isStale(now) => ('Live', AppColors.darkMint),
      _ when !duel.isFinished => ('Ended', AppColors.label),
      _ when duel.winner == uid => ('Win', const Color(0xFF16A34A)),
      _ when duel.winner == null => ('Draw', AppColors.label),
      _ => ('Loss', theme.colorScheme.error),
    };

    final subtitle = duel.isFinished || duel.isPlaying
        ? '${duel.scoreOf(uid)} : ${duel.scoreOf(opponentUid)}  ·  ${duelSummary(duel)}'
        : duelSummary(duel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openDuelGame(context, duel.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    opponent == null ? ProfileAvatar(name: name) : UserAvatar(profile: opponent, radius: 20),
                    Positioned(
                      right: -6,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: mode.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(mode.icon, size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vs $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (incoming)
                  FilledButton(
                    onPressed: () => openDuelInvite(context, duel),
                    style: FilledButton.styleFrom(
                      backgroundColor: duelDifficultyOf(duel.difficulty).color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Play'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (incoming)
                  IconButton(
                    tooltip: 'Decline',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => SocialRepository.instance.leaveDuel(duel.id).catchError((Object e) {
                      if (context.mounted) showError(context, describeError(e));
                    }),
                    icon: const Icon(Icons.close_rounded, color: AppColors.label, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
