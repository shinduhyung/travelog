import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:jidoapp/screens/travelog_poll_history_screen.dart';
import 'package:jidoapp/widgets/poll_countdown.dart';
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'package:jidoapp/services/travelog_poll_service.dart';
import 'package:jidoapp/services/travelog_poll_preview.dart';

class TravelogPollsScreen extends StatefulWidget {
  final TravelogPollGateway? gateway;
  const TravelogPollsScreen({super.key, this.gateway});
  @override
  State<TravelogPollsScreen> createState() => _TravelogPollsScreenState();
}

class _TravelogPollsScreenState extends State<TravelogPollsScreen>
    with WidgetsBindingObserver {
  late final TravelogPollGateway _api;
  Map<String, dynamic>? _data;
  String? _choice, _error;
  bool _loading = false, _voting = false;
  Timer? _release, _refresh;
  @override
  void initState() {
    super.initState();
    _api =
        widget.gateway ??
        (kDebugMode
            ? TravelogPollWeekPreview()
            : FirebaseTravelogPollGateway());
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await _api.load();
      if (!mounted) return;
      final poll = data['active'] as Map?;
      setState(() {
        if (_data?['active']?['id'] != poll?['id']) _choice = null;
        _data = data;
        _error = null;
      });
      _release?.cancel();
      if (poll != null) {
        final delay = DateTime.parse(
          poll['releaseAt'] as String,
        ).difference(DateTime.parse(data['serverNow'] as String));
        if (!delay.isNegative)
          _release = Timer(delay + const Duration(milliseconds: 500), _load);
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = tr('Could not load polls. Please try again.'));
    } finally {
      _loading = false;
    }
  }

  Future<void> _vote(Map poll) async {
    if (_choice == null || _voting) return;
    setState(() => _voting = true);
    try {
      await _api.vote(poll['id'] as String, _choice!);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Could not confirm your vote. Please try again.')),
          ),
        );
      await _load();
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  String _question(Map poll) =>
      Localizations.localeOf(context).languageCode == 'ko'
      ? (poll['questionKo'] ?? poll['question']) as String
      : tr(poll['question'] as String);
  Widget _flag(String code) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: SizedBox(
      width: 36,
      height: 25,
      child: CountryFlag.fromCountryCode(code),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final poll = _data?['active'] as Map?;
    final previous = (_data?['previous'] as List? ?? [])
        .whereType<Map>()
        .where((p) => p['released'] == true && p['counts'] is Map)
        .toList();
    final voted = poll?['choice'] as String?;
    const navy = Color(0xFF173B46);
    return DiscoverScaffold(
      appBar: AppBar(title: Text(tr('Travelog Polls'))),
      bottomNavigationBar: poll != null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                onPressed: voted != null || _choice == null || _voting
                    ? null
                    : () => _vote(poll),
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: Icon(
                  voted != null
                      ? Icons.check_circle_outline
                      : Icons.how_to_vote_outlined,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(
                      _voting
                          ? 'Saving...'
                          : voted != null
                          ? 'Vote saved'
                          : 'Cast my vote',
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: ValueKey(poll?['id']),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          children: [
            if (_data == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: Text(tr('Retry'))),
            ],
            if (poll != null) ...[
              _header(poll),
              const SizedBox(height: 14),
              for (final option in (poll['options'] as List).cast<Map>())
                _option(option, voted),
            ],
            if (_data != null && poll == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  tr('The next poll is on its way.'),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_data != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TravelogPollHistoryScreen(
                      polls: previous.reversed.toList(),
                      showPreview: kDebugMode,
                    ),
                  ),
                ),
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                label: Column(
                  children: [
                    Text(
                      Localizations.localeOf(context).languageCode == 'ko'
                          ? '과거 여론조사 결과'
                          : tr('Past poll results'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_data?['preview'] == true)
                      Text(
                        Localizations.localeOf(context).languageCode == 'ko'
                            ? '지난주 · 음식이 가장 맛있는 나라'
                            : tr('Last week · Best food'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: Color(0xFFD2E1E4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(Map poll) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    final release = DateTime.parse(poll['releaseAt'] as String).toUtc();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF173B46), Color(0xFF32636B)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -55,
            child: Transform.rotate(
              angle: -.3,
              child: Icon(
                Icons.public_rounded,
                size: 200,
                color: Colors.white.withValues(alpha: .075),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ko ? '이번 주 투표' : tr('THIS WEEK'),
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBCE8E5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_data?['preview'] == true)
                    Text(
                      ko ? '미리보기' : tr('PREVIEW'),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFFBCE8E5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _question(poll),
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ko ? '결과 공개' : tr('REVEAL')} · ${DateFormat('MMM d').format(release)}\n${DateFormat('HH:mm').format(release)} UTC',
                      style: const TextStyle(
                        color: Color(0xFFDEEFEE),
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PollCountdown(
                    serverNow: DateTime.parse(_data!['serverNow'] as String),
                    revealAt: release,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _option(Map option, String? voted) {
    final selected = (voted ?? _choice) == option['code'];
    const teal = Color(0xFF008F83);
    final accent = switch (option['code']) {
      'CN' => const Color(0xFFC8423C),
      'JP' => const Color(0xFFB54864),
      'KR' => const Color(0xFF316CB7),
      'TW' => const Color(0xFF3D6D85),
      'MN' => const Color(0xFF2F79A7),
      _ => teal,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height:
            56 +
            16 *
                (MediaQuery.textScalerOf(context).scale(16) / 16 - 1).clamp(
                  0.0,
                  1.5,
                ),
        child: Material(
          color: accent.withValues(alpha: selected ? .13 : .055),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? accent : accent.withValues(alpha: .12),
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: voted != null || _voting
                ? null
                : () => setState(() => _choice = option['code'] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: _flag(option['code'] as String)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(option['label'] as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF173B46),
                          ),
                        ),
                        if (option['detail'] is String) ...[
                          const SizedBox(height: 2),
                          Text(
                            tr(option['detail'] as String),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.15,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? accent : accent.withValues(alpha: .3),
                    size: 22,
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
