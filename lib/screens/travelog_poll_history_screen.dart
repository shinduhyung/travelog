import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';

/// Preview percentages are client-only fixtures and never enter vote storage.
class TravelogPollHistoryScreen extends StatelessWidget {
  final List<Map> polls;
  final bool showPreview;
  const TravelogPollHistoryScreen({
    super.key,
    required this.polls,
    this.showPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    final items = [...polls];
    if (kDebugMode &&
        showPreview &&
        !items.any(
          (p) =>
              p['id'] == 'best_food_20261109' ||
              p['question'] == 'Which country has the best food?',
        )) {
      items.insert(0, {
        'preview': true,
        'question': 'Which country has the best food?',
        'questionKo': '음식이 가장 맛있는 나라는?',
        'options': [
          {'code': 'IT', 'label': 'Italy', 'ko': '이탈리아'},
          {'code': 'JP', 'label': 'Japan', 'ko': '일본'},
          {'code': 'MX', 'label': 'Mexico', 'ko': '멕시코'},
          {'code': 'FR', 'label': 'France', 'ko': '프랑스'},
          {'code': 'TH', 'label': 'Thailand', 'ko': '태국'},
        ],
        'counts': {'IT': 32, 'JP': 22, 'MX': 17, 'FR': 17, 'TH': 12},
      });
    }
    return DiscoverScaffold(
      appBar: AppBar(title: Text(ko ? '과거 여론조사 결과' : tr('Past poll results'))),
      body: items.isEmpty
          ? Center(
              child: Text(
                ko ? '아직 공개된 결과가 없어요' : tr('No results revealed yet'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 28),
              itemBuilder: (_, index) =>
                  _PollHistoryRow(poll: items[index], ko: ko),
            ),
    );
  }
}

String _pollWeek(Map poll) {
  final now = DateTime.now().toUtc();
  final end =
      DateTime.tryParse(poll['releaseAt'] as String? ?? '') ??
      DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
  return '${DateFormat('MMM d').format(end.subtract(const Duration(days: 7)))} – ${DateFormat('MMM d').format(end.subtract(const Duration(days: 1)))}';
}

class _PollHistoryRow extends StatelessWidget {
  final Map poll;
  final bool ko;
  const _PollHistoryRow({required this.poll, required this.ko});
  @override
  Widget build(BuildContext context) {
    final options = (poll['options'] as List).cast<Map>();
    final counts = poll['counts'] as Map;
    if (options.isEmpty) return const SizedBox.shrink();
    final winner = options.reduce(
      (a, b) =>
          (counts[b['code']] as num? ?? 0) > (counts[a['code']] as num? ?? 0)
          ? b
          : a,
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TravelogPollResultScreen(poll: poll),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pollWeek(poll),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF78848A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                (ko
                    ? poll['questionKo'] ?? poll['question']
                    : tr(poll['question'] as String))
                    as String,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173B46),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 17,
                    color: Color(0xFFBC8C32),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 26,
                    height: 18,
                    child: CountryFlag.fromCountryCode(
                      winner['code'] as String,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (ko ? winner['ko'] ?? winner['label'] : tr(winner['label'] as String))
                          as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF173B46),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF78969D),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TravelogPollResultScreen extends StatelessWidget {
  final Map poll;
  const TravelogPollResultScreen({super.key, required this.poll});
  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    return DiscoverScaffold(
      appBar: AppBar(title: Text(ko ? '투표 결과' : tr('Poll results'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _pollWeek(poll),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78848A),
            ),
          ),
          const SizedBox(height: 8),
          _PollReveal(poll: poll, ko: ko),
        ],
      ),
    );
  }
}

class _PollReveal extends StatelessWidget {
  final Map poll;
  final bool ko;
  const _PollReveal({required this.poll, required this.ko});

  Widget flag(String code, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: size,
      height: size * .7,
      child: CountryFlag.fromCountryCode(code),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final counts = Map<String, dynamic>.from(poll['counts'] as Map);
    final options = (poll['options'] as List).cast<Map>().toList();
    // Keep configured order for ties (Mexico, then France in the preview).
    final order = {
      for (var i = 0; i < options.length; i++) options[i]['code']: i,
    };
    options.sort((a, b) {
      final difference = (counts[b['code']] as num? ?? 0).compareTo(
        counts[a['code']] as num? ?? 0,
      );
      return difference != 0
          ? difference
          : order[a['code']]!.compareTo(order[b['code']]!);
    });
    final total = counts.values.fold<double>(
      0,
      (sum, value) => sum + (value as num).toDouble(),
    );
    if (options.isEmpty) return const SizedBox.shrink();
    final winner = options.first;
    String name(Map option) =>
        (ko ? option['ko'] ?? option['label'] : tr(option['label'] as String))
            as String;
    double percent(Map option) =>
        total == 0 ? 0 : (counts[option['code']] as num? ?? 0) * 100 / total;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: reduceMotion ? 0 : 1100),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (poll['preview'] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                ko ? '지난주 · 미리보기' : tr('LAST WEEK · PREVIEW'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF78848A),
                ),
              ),
            ),
          Text(
            (ko
                    ? poll['questionKo'] ?? poll['question']
                    : tr(poll['question'] as String))
                as String,
            style: const TextStyle(
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF173B46),
            ),
          ),
          const SizedBox(height: 18),
          Transform.translate(
            offset: Offset(0, 12 * (1 - progress)),
            child: Opacity(
              opacity: progress,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF173B46), Color(0xFF32636B)],
                  ),
                ),
                child: Row(
                  children: [
                    flag(winner['code'] as String, 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 17,
                                color: Color(0xFFFFD77A),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                ko ? '1위' : tr('1ST PLACE'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFFD77A),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            name(winner),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(percent(winner) * progress).round()}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 1; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: i == 0
                            ? const Color(0xFF008F83)
                            : const Color(0xFF8A989F),
                      ),
                    ),
                  ),
                  flag(options[i]['code'] as String, 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name(options[i]),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${(percent(options[i]) * progress).round()}%',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF173B46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: percent(options[i]) / 100 * progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE5ECEE),
                            color: i == 0
                                ? const Color(0xFF008F83)
                                : const Color(0xFF7CA5AB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
