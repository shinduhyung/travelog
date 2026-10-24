import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jidoapp/services/ad_service.dart';

import '../models/duel.dart';
import '../services/social_repository.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/flag.dart';
import 'common.dart';
import '../social_hub.dart';

// Travelog 게임(Which is farther 등)과 같은 색
const _kInk = Color(0xFF1A1B23);
const _kMuted = Color(0xFF8E8E9B);
const _kFaint = Color(0xFFC7C7D1);
const _kSurface = Color(0xFFFAFAFC);
const _kGreen = Color(0xFF2FBE73);
const _kRed = Color(0xFFFF5A5F);

/// 정답 공개를 보여주는 시간. 서버는 라운드가 끝나고 3.6초 뒤에 다음 문제를 연다.
const _revealMs = 2400;

/// 실시간 대결 화면 하나로 대기실 → 3-2-1 → 문제/정답 공개 × 10 → 결과까지 보여준다.
/// 화면에 보이는 시각은 서버 시계에 맞춘 값이다 (socialTickDuel 응답으로 차이를 잰다).
class DuelGameScreen extends StatefulWidget {
  const DuelGameScreen({super.key, required this.matchId, this.debugStream, this.debugClock});

  final String matchId;

  /// 위젯 테스트용: Firebase 없이 대결 데이터와 시계를 넣는다
  final Stream<Duel>? debugStream;
  final int Function()? debugClock;

  /// 게임 화면이 열려 있으면 대결 신청 팝업을 띄우지 않는다
  static int openCount = 0;

  /// 위젯 테스트에서는 네트워크 사진 대신 빈 상자를 그린다
  static bool offlineImages = false;

  @override
  State<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends State<DuelGameScreen> {
  SocialRepository get _repo => SocialRepository.instance;
  StreamSubscription<Duel>? _sub;
  Timer? _ticker;
  Duel? _duel;
  Object? _error;

  int _offsetMs = 0;
  int _bestRttMs = 1 << 30;
  int _lastTickLocalMs = 0;
  bool _ticking = false;
  bool _busy = false;

  // 이번 라운드에 내가 고른 보기
  int _pickedRound = -1;
  int? _picked;
  final _precached = <String>{};

  bool get _offline => widget.debugStream != null;

  int get _now => widget.debugClock?.call() ?? DateTime.now().millisecondsSinceEpoch + _offsetMs;

  @override
  void initState() {
    super.initState();
    // Travelog 게임과 같은 방식: 대결 화면(대기실~결과)에 있는 동안 앱 광고 트리거를 멈춘다.
    // 리셋하지 않고 멈추기만 해서, 나가면 쌓여 있던 그대로 이어진다.
    // 재대결은 화면을 바꿔 끼우므로 열린 대결 화면 수로 판단한다.
    if (DuelGameScreen.openCount++ == 0 && !_offline) AdService.instance.pauseForGames();
    final stream = widget.debugStream ?? _repo.watchDuel(widget.matchId);
    _sub = stream.listen(
      (d) {
        if (!mounted) return;
        setState(() => _duel = d);
        _precacheImages(d);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
    if (!_offline) _syncClock();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeTick();
    });
  }

  @override
  void dispose() {
    if (--DuelGameScreen.openCount == 0 && !_offline) AdService.instance.resumeForGames();
    _ticker?.cancel();
    _sub?.cancel();
    // 대기실에서 나가면 보낸 신청을 취소한다 (상대가 혼자 시작하지 않게)
    final d = _duel;
    if (!_offline && d != null && d.isInvite && d.createdBy == _uid) {
      unawaited(_repo.leaveDuel(d.id).catchError((_) {}));
    }
    super.dispose();
  }

  String _uid = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _uid = SocialScope.read(context).uid;
  }

  /// 서버 시각 - 내 시각. 왕복 시간이 가장 짧았던 측정을 쓴다.
  Future<void> _syncClock() async {
    for (var i = 0; i < 2; i++) {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      try {
        final server = await _repo.tickDuel(widget.matchId);
        final t1 = DateTime.now().millisecondsSinceEpoch;
        if (t1 - t0 < _bestRttMs) {
          _bestRttMs = t1 - t0;
          _offsetMs = server - (t0 + t1) ~/ 2;
        }
      } catch (_) {
        return;
      }
    }
  }

  /// 마감이 지났는데 라운드가 안 닫혔으면 서버에 닫아 달라고 한다 (둘 중 누구든)
  void _maybeTick() {
    final d = _duel;
    if (d == null || _offline || _ticking) return;
    final local = DateTime.now().millisecondsSinceEpoch;
    if (local - _lastTickLocalMs < 1500) return;
    final now = _now;
    final due = (d.isPlaying && !d.roundAt(d.round).closed && now > (d.roundEndsMs ?? 0) + 400) || (d.isInvite && !d.inviteOpen(now));
    if (!due) return;
    _ticking = true;
    _lastTickLocalMs = local;
    _repo.tickDuel(d.id).catchError((_) => 0).whenComplete(() => _ticking = false);
  }

  void _precacheImages(Duel d) {
    for (final q in d.questions) {
      final url = q.image;
      if (url == null || DuelGameScreen.offlineImages || !_precached.add(url)) continue;
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
    }
  }

  Future<void> _answer(Duel d, int choice) async {
    if (_pickedRound == d.round) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pickedRound = d.round;
      _picked = choice;
    });
    if (_offline) return;
    try {
      await _repo.answerDuel(d.id, d.round, choice, math.max(0, _now - (d.roundStartMs ?? _now)));
    } catch (e) {
      if (mounted) showError(context, 'Couldn\'t send your answer: ${describeError(e)}');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave(Duel d) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this duel?'),
        content: const Text('Leaving now counts as a loss.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _kRed),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    if (!_offline) unawaited(_repo.leaveDuel(d.id).catchError((_) {}));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = _duel;
    final accent = d == null ? AppColors.mint : duelDifficultyOf(d.difficulty).color;
    final playing = d != null && d.isPlaying;

    Widget body;
    if (_error != null) {
      body = _Message(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load this duel', text: describeError(_error!), accent: accent);
    } else if (d == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _buildFor(d, accent);
    }

    return PopScope(
      canPop: !playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && d != null) _confirmLeave(d);
      },
      child: Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: d == null ? null : _TitleChip(duel: d, accent: accent),
        ),
        extendBodyBehindAppBar: true,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.14), _kSurface],
              stops: const [0.0, 0.4],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight - 8),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: body),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFor(Duel d, Color accent) {
    final now = _now;
    final store = SocialScope.of(context);
    final opponent = d.opponentOf(_uid);
    final opponentName = store.friend(opponent)?.displayName ?? 'Friend';

    if (d.isInvite) {
      if (!d.inviteOpen(now)) {
        return _Message(icon: Icons.timer_off_rounded, title: 'This invite expired', text: 'Invites last 10 minutes.', accent: accent);
      }
      return d.createdBy == _uid
          ? _Lobby(duel: d, accent: accent, opponentName: opponentName, now: now, onCancel: () => Navigator.pop(context))
          : _Lobby(
              duel: d,
              accent: accent,
              opponentName: opponentName,
              now: now,
              busy: _busy,
              onAccept: () => _run(() => _repo.joinDuel(d.id)),
              onDecline: () => _run(() async {
                await _repo.leaveDuel(d.id);
                if (mounted) Navigator.pop(context);
              }),
            );
    }
    if (d.isClosed) {
      final (icon, title) = switch (d.status) {
        'declined' => (Icons.do_not_disturb_on_rounded, '$opponentName declined'),
        'cancelled' => (Icons.close_rounded, 'This duel was cancelled'),
        _ => (Icons.timer_off_rounded, 'This invite expired'),
      };
      return _Message(icon: icon, title: title, text: 'Try again when you\'re both online.', accent: accent);
    }

    if (d.isFinished) {
      final last = d.roundAt(d.questions.length - 1);
      final showReveal = !d.legacy && d.forfeitBy == null && last.closed && now < last.closedMs! + _revealMs;
      if (showReveal) return _play(d, d.questions.length - 1, accent, now, reveal: true);
      return _Results(
        key: const ValueKey('results'),
        duel: d,
        uid: _uid,
        accent: accent,
        onRematch: () => _rematch(d),
        onAcceptRematch: (invite) => _run(() async {
          await _repo.joinDuel(invite.id);
          if (!mounted) return;
          Navigator.pushReplacement(context, socialRoute<void>((_) => DuelGameScreen(matchId: invite.id)));
        }),
      );
    }

    // playing
    final start = d.roundStartMs ?? now;
    if (now < start) {
      if (d.round > 0) {
        final prev = d.roundAt(d.round - 1);
        if (prev.closed && now < prev.closedMs! + _revealMs) return _play(d, d.round - 1, accent, now, reveal: true);
      }
      return _Countdown(
        key: ValueKey('cd${d.round}'),
        duel: d,
        uid: _uid,
        accent: accent,
        secondsLeft: ((start - now) / 1000).ceil().clamp(1, 3),
        first: d.round == 0,
      );
    }
    return _play(d, d.round, accent, now, reveal: d.roundAt(d.round).closed);
  }

  Widget _play(Duel d, int round, Color accent, int now, {required bool reveal}) {
    final r = d.roundAt(round);
    final mine = reveal ? r.picks[_uid] : null;
    final picked = _pickedRound == round ? _picked : null;
    final iAnswered = picked != null || r.answered.contains(_uid);
    final opponent = d.opponentOf(_uid);
    final remaining = math.max(0, (d.roundEndsMs ?? now) - now);

    Widget status;
    if (reveal) {
      status = _ResultBanner(
        round: r,
        uid: _uid,
        opponentName: SocialScope.of(context).friend(opponent)?.displayName ?? 'Friend',
        scoring: d.scoring,
      );
    } else {
      status = _TimerBar(remainingMs: remaining, limitMs: d.timeLimitMs, waiting: iAnswered);
    }

    return Padding(
      key: ValueKey('play$round$reveal'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _ScoreBoard(
            duel: d,
            uid: _uid,
            round: round,
            reveal: reveal ? r : null,
            answered: reveal ? const {} : r.answered.union({if (iAnswered) _uid}),
          ),
          const SizedBox(height: 10),
          status,
          const SizedBox(height: 12),
          Expanded(
            child: _QuestionView(
              question: d.questions[round],
              reveal: reveal ? r : null,
              picked: reveal ? (mine?.choice ?? picked) : picked,
              opponentPick: reveal ? r.picks[opponent]?.choice : null,
              opponentLabel: _initialOf(opponent),
              locked: reveal || iAnswered || remaining <= 0,
              onPick: (c) => _answer(d, c),
            ),
          ),
        ],
      ),
    );
  }

  String _initialOf(String uid) {
    final name = SocialScope.of(context).friend(uid)?.displayName ?? '?';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  Future<void> _rematch(Duel d) async {
    final friend = SocialScope.read(context).friend(d.opponentOf(_uid));
    if (friend == null) return;
    await _run(() async {
      final id = await _repo.createDuel(friend.uid, mode: d.mode, difficulty: d.difficulty, scoring: d.scoring);
      if (!mounted) return;
      Navigator.pushReplacement(context, socialRoute<void>((_) => DuelGameScreen(matchId: id)));
    });
  }
}

// ── 공통 조각 ────────────────────────────────────────────────────────────

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white, this.border});

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border ?? Colors.black.withValues(alpha: 0.04), width: 1.4),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: child,
  );
}

class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.duel, required this.accent});

  final Duel duel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mode = duelModeOf(duel.mode);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${mode.title} · ${duelDifficultyOf(duel.difficulty).label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.color, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.85), color]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: Center(
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentCircle extends StatelessWidget {
  const _AccentCircle({required this.accent, required this.child, this.size = 84});

  final Color accent;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: 0.85), accent]),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
    ),
    child: child,
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, required this.accent});

  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AccentCircle(
            accent: accent,
            child: Icon(icon, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 22),
          _GradientButton(label: 'Back', color: accent, onPressed: () => Navigator.maybePop(context)),
        ],
      ),
    ),
  );
}

/// 동그란 프로필 (나 / 친구)
class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.uid, this.radius = 20});

  final String uid;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final p = uid == store.uid ? store.me : store.friend(uid);
    return p == null ? ProfileAvatar(name: 'Friend', radius: radius) : UserAvatar(profile: p, radius: radius);
  }
}

class _SettingChips extends StatelessWidget {
  const _SettingChips({required this.duel});

  final Duel duel;

  @override
  Widget build(BuildContext context) {
    final mode = duelModeOf(duel.mode);
    final diff = duelDifficultyOf(duel.difficulty);
    final scoring = duelScorings[duel.scoring];
    Widget chip(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color.lerp(color, Colors.black, 0.2)),
            ),
          ),
        ],
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(mode.icon, mode.title, mode.color),
        chip(Icons.speed_rounded, '${diff.label} · ${diff.seconds}s', diff.color),
        if (scoring != null) chip(scoring.$3, scoring.$1, AppColors.indigo),
      ],
    );
  }
}

// ── 대기실 ───────────────────────────────────────────────────────────────

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.duel,
    required this.accent,
    required this.opponentName,
    required this.now,
    this.onCancel,
    this.onAccept,
    this.onDecline,
    this.busy = false,
  });

  final Duel duel;
  final Color accent;
  final String opponentName;
  final int now;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final mine = duel.createdBy == store.uid;
    final left = Duration(milliseconds: math.max(0, Duel.inviteTtlMs - (now - (duel.createdMs ?? now))));
    final scoring = duelScorings[duel.scoring];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlayerAvatar(uid: store.uid, radius: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _kMuted),
                    ),
                  ),
                ),
                _PlayerAvatar(uid: duel.opponentOf(store.uid), radius: 32),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              mine ? 'Waiting for $opponentName' : '$opponentName challenged you!',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk),
            ),
            const SizedBox(height: 6),
            Text(
              mine
                  ? 'The duel starts as soon as they accept. Keep this screen open.'
                  : 'You both answer the same ${duel.questions.length} questions at the same time.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _SettingChips(duel: duel),
            if (scoring != null) ...[
              const SizedBox(height: 12),
              Text(
                scoring.$2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
            ],
            const SizedBox(height: 22),
            if (mine) ...[
              const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
              const SizedBox(height: 10),
              Text(
                'Invite expires in ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: _kFaint, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextButton(onPressed: onCancel, child: const Text('Cancel invite')),
            ] else ...[
              _GradientButton(label: 'Accept & play', icon: Icons.play_arrow_rounded, color: accent, busy: busy, onPressed: onAccept),
              const SizedBox(height: 8),
              TextButton(onPressed: busy ? null : onDecline, child: const Text('Decline')),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 3-2-1 ───────────────────────────────────────────────────────────────

class _Countdown extends StatelessWidget {
  const _Countdown({
    super.key,
    required this.duel,
    required this.uid,
    required this.accent,
    required this.secondsLeft,
    required this.first,
  });

  final Duel duel;
  final String uid;
  final Color accent;
  final int secondsLeft;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _ScoreBoard(duel: duel, uid: uid, round: duel.round, answered: const {}),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ROUND ${duel.round + 1} OF ${duel.questions.length}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted),
                  ),
                  const SizedBox(height: 18),
                  TweenAnimationBuilder<double>(
                    key: ValueKey(secondsLeft),
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: _AccentCircle(
                      accent: accent,
                      size: 96,
                      child: Text(
                        '$secondsLeft',
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    first ? 'Get ready...' : 'Next question',
                    style: const TextStyle(fontSize: 14, color: _kMuted, fontWeight: FontWeight.w600),
                  ),
                  if (first) ...[const SizedBox(height: 16), _SettingChips(duel: duel)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 점수판 ───────────────────────────────────────────────────────────────

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.duel, required this.uid, required this.round, required this.answered, this.reveal});

  final Duel duel;
  final String uid;
  final int round;
  final Set<String> answered;
  final DuelRound? reveal;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final opponent = duel.opponentOf(uid);

    Widget side(String who, String name, bool alignEnd) {
      final pts = reveal?.picks[who]?.points ?? 0;
      final avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          _PlayerAvatar(uid: who, radius: 17),
          if (answered.contains(who))
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
              ),
            ),
        ],
      );
      final info = Flexible(
        child: Column(
          crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kMuted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alignEnd && pts > 0) _PlusChip(pts),
                  Text(
                    '${duel.scoreOf(who)}',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kInk,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (!alignEnd && pts > 0) _PlusChip(pts),
                ],
              ),
            ),
          ],
        ),
      );
      return Expanded(
        child: Row(
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: alignEnd ? [info, const SizedBox(width: 8), avatar] : [avatar, const SizedBox(width: 8), info],
        ),
      );
    }

    return _SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          side(uid, 'You', false),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${math.min(round + 1, duel.questions.length)} / ${duel.questions.length}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kMuted, letterSpacing: 0.4),
            ),
          ),
          side(opponent, store.friend(opponent)?.displayName ?? 'Friend', true),
        ],
      ),
    );
  }
}

class _PlusChip extends StatelessWidget {
  const _PlusChip(this.points);

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
    child: Text(
      '+$points',
      maxLines: 1,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kGreen),
    ),
  );
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.remainingMs, required this.limitMs, required this.waiting});

  final int remainingMs;
  final int limitMs;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final ratio = (remainingMs / limitMs).clamp(0.0, 1.0);
    final color = Color.lerp(_kRed, _kGreen, ratio)!;
    return SizedBox(
      height: 44,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: waiting
                    ? const Text(
                        'Answer locked · waiting for the round to end',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted),
                      )
                    : const SizedBox.shrink(),
              ),
              Text(
                '${(remainingMs / 1000).toStringAsFixed(1)}s',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.round, required this.uid, required this.opponentName, required this.scoring});

  final DuelRound round;
  final String uid;
  final String opponentName;
  final String scoring;

  @override
  Widget build(BuildContext context) {
    final mine = round.picks[uid];
    final theirs = round.picks.entries.where((e) => e.key != uid).map((e) => e.value).firstOrNull;
    final (bool good, String text) = switch (mine) {
      DuelPick(ok: true, points: > 0) => (true, scoring == 'first' ? 'You got it first! +1' : 'Correct! +${mine.points}'),
      DuelPick(ok: true) => (true, 'Correct, but $opponentName was faster'),
      _ when theirs?.ok == true && scoring == 'first' => (false, '$opponentName got it first'),
      null => (false, 'Time\'s up'),
      _ => (false, 'Wrong'),
    };
    final color = good ? _kGreen : _kRed;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(good ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 문제 ────────────────────────────────────────────────────────────────

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.reveal,
    required this.picked,
    required this.opponentPick,
    required this.opponentLabel,
    required this.locked,
    required this.onPick,
  });

  final DuelQuestion question;
  final DuelRound? reveal;
  final int? picked;
  final int? opponentPick;
  final String opponentLabel;
  final bool locked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final q = question;
    if (q.type == 'farther' && q.choices.length == 2) return _farther(context);

    final prompt = Text(
      q.prompt,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk, height: 1.2),
    );

    // 인구/면적: 국기 카드 2×2
    if (q.type == 'population' || q.type == 'area') {
      return Column(
        children: [
          prompt,
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 10),
                          Expanded(child: row * 2 + col < q.choices.length ? _flagTile(row * 2 + col) : const SizedBox()),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        prompt,
        const SizedBox(height: 12),
        Expanded(child: _visual()),
        const SizedBox(height: 12),
        for (var i = 0; i < q.choices.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: _choiceTile(i)),
      ],
    );
  }

  (Color bg, Color fg, Color border, IconData? mark) _colors(int i) {
    final r = reveal;
    if (r != null) {
      if (i == r.answer) return (_kGreen, Colors.white, _kGreen, Icons.check_circle_rounded);
      if (i == picked) return (_kRed, Colors.white, _kRed, Icons.cancel_rounded);
      return (Colors.white, _kInk, Colors.black.withValues(alpha: 0.04), null);
    }
    if (i == picked) return (AppColors.mint.withValues(alpha: 0.14), _kInk, AppColors.mint, null);
    return (Colors.white, _kInk, Colors.black.withValues(alpha: 0.04), null);
  }

  Widget _opponentBadge(int i, Color bg) {
    if (reveal == null || opponentPick != i) return const SizedBox.shrink();
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(left: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.friend,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        opponentLabel,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }

  String? _detail(int i) {
    final d = reveal?.detail;
    return d != null && i < d.length ? d[i] : null;
  }

  Widget _tap(int i, Widget child) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: locked ? null : () => onPick(i), child: child);

  Widget _choiceTile(int i) {
    final c = question.choices[i];
    final (bg, fg, border, mark) = _colors(i);
    final detail = _detail(i);
    return _tap(
      i,
      _SoftCard(
        color: bg,
        border: border,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 30),
          child: Row(
            children: [
              if (c.flag != null) ...[Flag(c.flag, width: 30), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: fg, height: 1.15),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        maxLines: 1,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.75)),
                      ),
                  ],
                ),
              ),
              _opponentBadge(i, bg),
              if (mark != null) ...[const SizedBox(width: 6), Icon(mark, color: Colors.white, size: 22)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _flagTile(int i) {
    final c = question.choices[i];
    final (bg, fg, border, mark) = _colors(i);
    final detail = _detail(i);
    return _tap(
      i,
      _SoftCard(
        color: bg,
        border: border,
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, box) =>
                        Flag(c.flag, width: math.min(box.maxWidth * 0.8, box.maxHeight / 0.7).clamp(24.0, 140.0), radius: 8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg, height: 1.15),
                ),
                if (detail != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      detail,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.8)),
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _opponentBadge(i, bg),
                  if (mark != null) ...[const SizedBox(width: 4), Icon(mark, color: Colors.white, size: 20)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visual() {
    final q = question;
    if (q.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (DuelGameScreen.offlineImages)
              const ColoredBox(color: Color(0xFFEDEDF2))
            else
              CachedNetworkImage(
                imageUrl: q.image!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(
                  color: Color(0xFFEDEDF2),
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFFEDEDF2),
                  child: Center(child: Icon(Icons.image_not_supported_rounded, color: _kFaint, size: 40)),
                ),
              ),
            if (q.subject != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Text(
                    q.subject!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (q.flag != null) {
      return Center(
        child: LayoutBuilder(
          builder: (context, box) {
            final w = math.min(box.maxWidth * 0.8, box.maxHeight / 0.7).clamp(40.0, 320.0);
            return Flag(q.flag, width: w, radius: 12);
          },
        ),
      );
    }
    // 도시 이름 카드 (보기에 공간을 내줘야 할 때는 작아진다)
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CITY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kMuted),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  q.subject ?? '?',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _kInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Travelog "Which is farther?"와 같은 배치: 출발 도시 + 위아래 두 카드
  Widget _farther(BuildContext context) {
    final q = question;
    Widget card(int i) {
      final c = q.choices[i];
      final (bg, fg, border, mark) = _colors(i);
      final detail = _detail(i);
      return _tap(
        i,
        _SoftCard(
          color: bg,
          border: border,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Flag(c.flag, width: 40, radius: 6),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg),
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          detail,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.75)),
                        ),
                      ),
                  ],
                ),
              ),
              _opponentBadge(i, bg),
              if (mark != null) ...[const SizedBox(width: 6), Icon(mark, color: Colors.white, size: 24)],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'FROM',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kMuted),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flag(q.flag, width: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                q.subject ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'which is farther?',
          style: TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Column(
            children: [
              Expanded(child: card(0)),
              const SizedBox(height: 12),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kMuted),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: card(1)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 결과 ────────────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.duel,
    required this.uid,
    required this.accent,
    required this.onRematch,
    required this.onAcceptRematch,
  });

  final Duel duel;
  final String uid;
  final Color accent;
  final VoidCallback onRematch;
  final ValueChanged<Duel> onAcceptRematch;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final opponent = duel.opponentOf(uid);
    final opponentName = store.friend(opponent)?.displayName ?? 'Friend';
    final won = duel.winner == uid;
    final draw = duel.winner == null;
    final (IconData icon, String headline) = won
        ? (Icons.emoji_events_rounded, 'You win!')
        : draw
        ? (Icons.handshake_rounded, 'It\'s a draw')
        : (Icons.flag_rounded, '$opponentName wins');
    final note = duel.forfeitBy == null
        ? null
        : duel.forfeitBy == uid
        ? 'You left the duel'
        : '$opponentName left the duel';
    // 상대가 이 대결 뒤에 다시 신청했으면 바로 받을 수 있게
    final rematchInvite = store.incomingInvites
        .where((d) => d.createdBy == opponent && (d.createdMs ?? 0) >= (duel.createdMs ?? 0) && d.id != duel.id)
        .firstOrNull;

    Widget scoreCard(String who, String name, bool winner) => Expanded(
      child: _SoftCard(
        border: winner ? AppColors.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _PlayerAvatar(uid: who, radius: 22),
                if (winner)
                  const Positioned(top: -12, right: -10, child: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kMuted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${duel.scoreOf(who)}',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kInk,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              '${_correctCount(who)}/${duel.questions.length} correct',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kMuted),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: _AccentCircle(
            accent: won ? AppColors.gold : accent,
            child: Icon(icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          headline,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _kInk),
        ),
        if (note != null || duel.abandoned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note ?? 'Nobody was playing, so the duel ended early',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 12),
        if (!duel.legacy) _SettingChips(duel: duel),
        const SizedBox(height: 16),
        Row(
          children: [
            scoreCard(uid, 'You', duel.winner == uid),
            const SizedBox(width: 10),
            scoreCard(opponent, opponentName, duel.winner == opponent),
          ],
        ),
        const SizedBox(height: 16),
        if (rematchInvite != null)
          _GradientButton(
            label: '$opponentName wants a rematch!',
            icon: Icons.play_arrow_rounded,
            color: _kGreen,
            onPressed: () => onAcceptRematch(rematchInvite),
          )
        else if (store.friend(opponent) != null)
          _GradientButton(label: 'Rematch', icon: Icons.replay_rounded, color: accent, onPressed: onRematch),
        const SizedBox(height: 22),
        const Text(
          'Round by round',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInk),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < duel.questions.length; i++)
          if (duel.roundAt(i).closed) _ReviewRow(index: i, duel: duel, uid: uid, opponentName: opponentName),
      ],
    );
  }

  int _correctCount(String who) => duel.rounds.values.where((r) => r.picks[who]?.ok == true).length;
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.index, required this.duel, required this.uid, required this.opponentName});

  final int index;
  final Duel duel;
  final String uid;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final q = duel.questions[index];
    final r = duel.roundAt(index);
    final answer = r.answer != null && r.answer! >= 0 && r.answer! < q.choices.length ? q.choices[r.answer!] : null;
    final opponent = duel.opponentOf(uid);

    Widget mark(String who) {
      final p = r.picks[who];
      final color = p == null ? _kFaint : (p.ok ? _kGreen : _kRed);
      return SizedBox(
        width: 46,
        child: Column(
          children: [
            Icon(p == null ? Icons.timer_off_rounded : (p.ok ? Icons.check_circle_rounded : Icons.cancel_rounded), color: color, size: 20),
            Text(
              p != null && p.points > 0 ? '+${p.points}' : (who == uid ? 'You' : 'Friend'),
              maxLines: 1,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p != null && p.points > 0 ? _kGreen : _kMuted),
            ),
          ],
        ),
      );
    }

    final leading = q.image != null && !DuelGameScreen.offlineImages
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: q.image!,
              width: 44,
              height: 34,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox(width: 44),
            ),
          )
        : q.flag != null
        ? Flag(q.flag, width: 44, radius: 6)
        : Icon(duelModeOf(q.type).icon, color: duelModeOf(q.type).color, size: 26);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kFaint),
            ),
          ),
          SizedBox(width: 48, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.type == 'farther' ? 'Farther from ${q.subject}' : (q.subject ?? q.prompt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    if (answer?.flag != null) ...[Flag(answer!.flag, width: 18, radius: 2), const SizedBox(width: 5)],
                    Flexible(
                      child: Text(
                        answer?.label ?? '?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          mark(uid),
          mark(opponent),
        ],
      ),
    );
  }
}

/// 친구가 보낸 대결 신청을 받는 팝업 (홈 화면에서 띄운다)
Future<void> showDuelInviteDialog(BuildContext context, Duel invite) async {
  final store = SocialScope.read(context);
  final from = store.friend(invite.createdBy);
  final accent = duelDifficultyOf(invite.difficulty).color;
  final accept = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          from == null ? const ProfileAvatar(name: 'Friend', radius: 30) : UserAvatar(profile: from, radius: 30),
          const SizedBox(height: 12),
          Text(
            '${from?.displayName ?? 'A friend'} challenged you!',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk),
          ),
          const SizedBox(height: 12),
          _SettingChips(duel: invite),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Decline')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
          child: const Text('Play'),
        ),
      ],
    ),
  );
  if (accept == null || !context.mounted) return;
  if (!accept) {
    unawaited(SocialRepository.instance.leaveDuel(invite.id).catchError((_) {}));
    return;
  }
  await openDuelInvite(context, invite);
}

/// 신청 수락 → 게임 화면
Future<void> openDuelInvite(BuildContext context, Duel invite) async {
  try {
    await SocialRepository.instance.joinDuel(invite.id);
  } catch (e) {
    if (context.mounted) showError(context, describeError(e));
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(context, socialRoute<void>((_) => DuelGameScreen(matchId: invite.id)));
}

/// 대결 신청이 오면 팝업을 띄운다. 게임 중에는 띄우지 않는다.
class DuelInviteListener extends StatefulWidget {
  const DuelInviteListener({super.key, required this.child});

  final Widget child;

  @override
  State<DuelInviteListener> createState() => _DuelInviteListenerState();
}

class _DuelInviteListenerState extends State<DuelInviteListener> {
  // 소셜 화면마다 리스너가 있으므로 같은 신청을 두 번 띄우지 않게 공유한다
  static final _seen = <String>{};
  static bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final invites = SocialScope.of(context).incomingInvites;
    final fresh = invites.where((d) => !_seen.contains(d.id)).toList();
    if (fresh.isEmpty || _showing || DuelGameScreen.openCount > 0) return;
    _seen.addAll(fresh.map((d) => d.id));
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await showDuelInviteDialog(context, fresh.first);
      _showing = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 다른 화면에서 쓰는 짧은 설명 (예: "Flags · Hard · Speed")
String duelSummary(Duel d) {
  if (d.legacy) return duelModeOf(d.mode).title;
  final scoring = duelScorings[d.scoring]?.$1 ?? '';
  return '${duelModeOf(d.mode).title} · ${duelDifficultyOf(d.difficulty).label} · $scoring';
}

// startDuelFlow(new_duel_sheet.dart)에서 쓰는 공통 진입점
Future<void> openDuelGame(BuildContext context, String matchId) =>
    Navigator.push(context, socialRoute<void>((_) => DuelGameScreen(matchId: matchId)));
