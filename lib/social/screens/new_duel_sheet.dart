import 'package:flutter/material.dart';

import '../models/duel.dart';
import '../models/social_profile.dart';
import '../services/social_repository.dart';
import '../services/social_store.dart';
import '../theme.dart';
import 'common.dart';
import 'duel_game_screen.dart';
import '../widgets/avatar.dart';

typedef DuelSetup = ({String mode, String difficulty, String scoring});

// 마지막으로 고른 설정을 기억한다 (앱을 켜 둔 동안)
DuelSetup _lastSetup = (mode: 'mixed', difficulty: 'medium', scoring: 'speed');

/// 게임/난이도/점수 방식을 고르고 신청을 보낸 뒤 대기실로
Future<void> startDuelFlow(BuildContext context, SocialProfile friend) async {
  final setup = await showModalBottomSheet<DuelSetup>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => _SetupSheet(friend: friend, initial: _lastSetup),
  );
  if (setup == null || !context.mounted) return;
  _lastSetup = setup;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final matchId = await SocialRepository.instance.createDuel(
      friend.uid,
      mode: setup.mode,
      difficulty: setup.difficulty,
      scoring: setup.scoring,
    );
    if (!context.mounted) return;
    Navigator.pop(context); // 로딩
    await openDuelGame(context, matchId);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    showError(context, describeError(e));
  }
}

/// 친구를 먼저 고르는 경우 (대결 탭의 + 버튼)
Future<void> pickFriendAndDuel(BuildContext context) async {
  final store = SocialScope.read(context);
  final friends = store.friends;
  if (friends.isEmpty) {
    showError(context, 'Add a friend first');
    return;
  }
  final picked = await showModalBottomSheet<SocialProfile>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Who do you want to duel?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final f in friends)
              ListTile(
                leading: UserAvatar(profile: f),
                title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${f.countryCount} ${f.countryCount == 1 ? 'country' : 'countries'}',
                  style: const TextStyle(color: AppColors.label),
                ),
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked != null && context.mounted) await startDuelFlow(context, picked);
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.friend, required this.initial});

  final SocialProfile friend;
  final DuelSetup initial;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late String _mode = widget.initial.mode;
  late String _difficulty = widget.initial.difficulty;
  late String _scoring = widget.initial.scoring;

  @override
  Widget build(BuildContext context) {
    final accent = duelDifficultyOf(_difficulty).color;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(profile: widget.friend, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Duel ${widget.friend.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live 1:1 · 10 rounds · you both play at the same time',
                      style: TextStyle(fontSize: 12.5, color: AppColors.label, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    const _Label('Game'),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.9,
                      children: [
                        for (final e in duelModes.entries)
                          _ModeTile(mode: e.value, selected: e.key == _mode, onTap: () => setState(() => _mode = e.key)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _Label('Difficulty'),
                    Row(
                      children: [
                        for (final e in duelDifficulties.entries) ...[
                          if (e.key != duelDifficulties.keys.first) const SizedBox(width: 6),
                          Expanded(
                            child: _DifficultyPill(
                              difficulty: e.value,
                              selected: e.key == _difficulty,
                              onTap: () => setState(() => _difficulty = e.key),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _Label('Scoring'),
                    for (final e in duelScorings.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ScoringTile(
                          title: e.value.$1,
                          text: e.value.$2,
                          icon: e.value.$3,
                          selected: e.key == _scoring,
                          onTap: () => setState(() => _scoring = e.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, (mode: _mode, difficulty: _difficulty, scoring: _scoring)),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text('Send challenge'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppColors.label),
    ),
  );
}

BoxDecoration _option(bool selected, Color color) => BoxDecoration(
  color: selected ? color.withValues(alpha: 0.1) : Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: selected ? color : const Color(0xFFE5E7EB), width: selected ? 1.6 : 1),
);

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.selected, required this.onTap});

  final DuelMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: _option(selected, mode.color),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconTile(icon: mode.icon, color: mode.color, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      mode.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.label),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  const _DifficultyPill({required this.difficulty, required this.selected, required this.onTap});

  final DuelDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 54,
          decoration: _option(selected, color),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        difficulty.label,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${difficulty.seconds}s',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoringTile extends StatelessWidget {
  const _ScoringTile({required this.title, required this.text, required this.icon, required this.selected, required this.onTap});

  final String title;
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: _option(selected, AppColors.indigo),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconTile(icon: icon, color: AppColors.indigo, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.label, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.indigo : const Color(0xFFD1D5DB),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
