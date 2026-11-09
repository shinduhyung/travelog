import 'package:jidoapp/services/discover_survey_store.dart';
import 'package:jidoapp/services/survey_ad_session.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/discover_quizzes.dart';

class DiscoverQuizScreen extends StatefulWidget {
  final String quizId;
  final SurveyAdSession? adSession;
  final Map<String, dynamic> Function(List<int>)? resultDataBuilder;
  final Widget Function(List<int> answers)? resultBuilder;
  const DiscoverQuizScreen({
    super.key,
    required this.quizId,
    this.adSession,
    this.resultBuilder,
    this.resultDataBuilder,
  });
  @override
  State<DiscoverQuizScreen> createState() => _DiscoverQuizScreenState();
}

class _DiscoverQuizScreenState extends State<DiscoverQuizScreen> {
  DiscoveryQuiz get quiz => discoveryQuizzes[widget.quizId]!;
  final List<int> _answers = [];
  int _step = 0;
  bool _finished = false, _loading = true, _showingReward = false;
  late final SurveyAdSession _ads;
  final _store = DiscoverSurveyStore();
  String get _key =>
      'discover_quiz_${widget.quizId}_${widget.quizId == 'local' ? 'v3' : 'v2'}';
  String get _cacheKey => _store.cacheKey(_key);
  String get _draftKey => '${_cacheKey}_draft';
  @override
  void initState() {
    super.initState();
    _ads = widget.adSession ?? SurveyAdSession.live();
    _ads.enter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) RewardedUnlockService.instance.preload();
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cloud = await _store.load(_key);
      if (cloud == null &&
          _store.uid != null &&
          !prefs.containsKey(_cacheKey)) {
        final owner = prefs.getString('discover_legacy_owner');
        if (owner == null || owner == _store.uid) {
          await prefs.setString('discover_legacy_owner', _store.uid!);
          final old = prefs.getString(_key);
          final draft = prefs.getString('${_key}_draft');
          if (old != null) await prefs.setString(_cacheKey, old);
          if (draft != null) await prefs.setString(_draftKey, draft);
        }
      }
      if (cloud != null) {
        if (cloud['status'] == 'complete') {
          final values = (cloud['answers'] as List).cast<int>();
          quiz.score(values);
          await prefs.setString(_cacheKey, jsonEncode(values));
          await prefs.remove(_draftKey);
        } else {
          await prefs.remove(_cacheKey);
          await prefs.setString(
            _draftKey,
            jsonEncode({
              'answers': cloud['answers'] ?? [],
              'step': cloud['step'] ?? 0,
            }),
          );
        }
      }
      final saved = prefs.getString(_cacheKey);
      if (saved != null) {
        final values = (jsonDecode(saved) as List).cast<int>();
        quiz.score(values);
        _answers.addAll(values);
        _finished = true;
        if (cloud == null)
          await _store.complete(
            _key,
            values,
            quiz.score(values),
            widget.resultDataBuilder?.call(values) ??
                {'score': quiz.score(values)},
          );
      } else {
        final draft = prefs.getString(_draftKey);
        if (draft != null) {
          final data = jsonDecode(draft) as Map;
          final values = (data['answers'] as List).cast<int>();
          if (values.length > quiz.questions.length)
            throw const FormatException('Invalid draft');
          for (var i = 0; i < values.length; i++) {
            if (values[i] < 0 || values[i] >= quiz.questions[i].options.length)
              throw const FormatException('Invalid draft');
          }
          _answers.addAll(values);
          _step = (data['step'] as int)
              .clamp(0, values.length)
              .clamp(0, quiz.questions.length - 1);
        }
      }
    } catch (_) {
      _answers.clear();
    }
    if (_finished) _ads.leave();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveDraft() async {
    final value = jsonEncode({
      'answers': List<int>.from(_answers),
      'step': _step,
    });
    try {
      await (await SharedPreferences.getInstance()).setString(_draftKey, value);
      await _store.save(_key, {
        'status': 'draft',
        'answers': List<int>.from(_answers),
        'step': _step,
        'schema': 1,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ads.leave();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_showingReward) return;
    setState(() => _showingReward = true);
    try {
      await _saveDraft();
      if (!mounted) return;
      final result = await _ads.unlock('discover_quiz_${widget.quizId}');
      if (!mounted) return;
      if (result != RewardedUnlockResult.unlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                result == RewardedUnlockResult.dismissed
                    ? 'Watch the video to reveal your result. Your answers are saved.'
                    : 'No video available yet. Your answers are saved. Please try again.',
              ),
            ),
          ),
        );
        return;
      }
      await _store.complete(
        _key,
        List<int>.from(_answers),
        quiz.score(_answers),
        widget.resultDataBuilder?.call(_answers) ??
            {'score': quiz.score(_answers)},
      );
      if (!mounted) return;
      setState(() => _finished = true);
      _ads.leave();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_answers));
      await prefs.remove(_draftKey);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Please try again. Your answers are saved.')),
          ),
        );
    } finally {
      if (mounted) setState(() => _showingReward = false);
    }
  }

  Future<void> _retake() async {
    _ads.enter();
    setState(() {
      _answers.clear();
      _step = 0;
      _finished = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_draftKey);
      await _store.save(_key, {
        'status': 'draft',
        'answers': <int>[],
        'step': 0,
        'schema': 1,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return DiscoverScaffold(
      appBar: AppBar(
        title: Text(
          tr(quiz.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: _finished ? null : _footer(),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: ValueKey((_finished, _step)),
          padding: const EdgeInsets.all(20),
          children: [
            if (_finished) ..._result() else ..._question(constraints.maxWidth),
          ],
        ),
      ),
    );
  }

  double _measure(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: tr(text), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter.layout(maxWidth: width.clamp(40, double.infinity));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  List<Widget> _question(double width) {
    final question = quiz.questions[_step];
    final selected = _answers.length > _step ? _answers[_step] : null;
    final accent = widget.quizId == 'survival'
        ? const Color(0xFF0891B2)
        : widget.quizId == 'local'
        ? const Color(0xFFEA580C)
        : const Color(0xFFDB2777);
    final questionStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      height: 1.3,
      color: Color.lerp(accent, Colors.black, .5),
    );
    const answerStyle = TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
    // Measure the entire quiz so every page has the same geometry, including translations and large text.
    final questionHeight =
        quiz.questions
            .map((q) => _measure(q.text, questionStyle, width - 80))
            .fold<double>(96, (a, b) => a > b ? a : b) +
        40;
    final answerHeight =
        quiz.questions
            .expand((q) => q.options)
            .map((o) => _measure(o.text, answerStyle, width - 120))
            .fold<double>(40, (a, b) => a > b ? a : b) +
        32;
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: (_step + 1) / quiz.questions.length,
          color: accent,
          minHeight: 6,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(
            widget.quizId == 'survival'
                ? Icons.backpack_rounded
                : widget.quizId == 'local'
                ? Icons.explore_rounded
                : Icons.price_check_rounded,
            color: accent,
            size: 22,
          ),
          const Spacer(),
          Text(
            '${_step + 1} / ${quiz.questions.length}',
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        height: questionHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(tr(question.text), style: questionStyle),
      ),
      const SizedBox(height: 20),
      for (var i = 0; i < question.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: answerHeight,
            child: Material(
              color: selected == i
                  ? accent.withValues(alpha: .12)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: selected == i ? accent : const Color(0xFFE2E8F0),
                  width: selected == i ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showingReward
                    ? null
                    : () {
                        setState(() {
                          if (_answers.length > _step) {
                            _answers[_step] = i;
                          } else {
                            _answers.add(i);
                          }
                        });
                        _saveDraft();
                      },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(question.options[i].text),
                          style: answerStyle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        selected == i
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected == i ? accent : const Color(0xFFCBD5E1),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _footer() {
    final selected = _answers.length > _step;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        height: 48 + 16 * (MediaQuery.textScalerOf(context).scale(14) / 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 64,
              child: _step == 0
                  ? null
                  : TextButton(
                      onPressed: _showingReward
                          ? null
                          : () {
                              setState(() => _step--);
                              _saveDraft();
                            },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(tr('Back'), maxLines: 1),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: !selected || _showingReward
                    ? null
                    : () {
                        if (_step == quiz.questions.length - 1) {
                          _complete();
                        } else {
                          setState(() => _step++);
                          _saveDraft();
                        }
                      },
                child: Text(
                  tr(
                    _showingReward
                        ? 'Opening video...'
                        : _step == quiz.questions.length - 1
                        ? (_ads.needsAd
                              ? 'Watch ad & see result'
                              : 'See result')
                        : 'Next',
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _result() {
    if (widget.resultBuilder != null)
      return [
        widget.resultBuilder!(List<int>.unmodifiable(_answers)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _retake,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('Try again')),
        ),
      ];
    final score = quiz.score(_answers);
    final label = widget.quizId == 'local'
        ? (score >= 67
              ? 'Local-style explorer'
              : score <= 33
              ? 'Landmark-loving tourist'
              : 'A blend of both styles')
        : widget.quizId == 'survival'
        ? (score >= 75
              ? 'Ready to adapt'
              : score >= 45
              ? 'Building your backup plans'
              : 'Room for more preparation')
        : (score >= 75
              ? 'Thoughtful price checker'
              : score >= 45
              ? 'Pause and compare'
              : 'Practice checking the full offer');
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.quizId == 'survival'
                ? const [Color(0xFF087F6B), Color(0xFF12A594)]
                : const [Color(0xFF2563EB), Color(0xFF7C3AED)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              widget.quizId == 'survival'
                  ? Icons.backpack_rounded
                  : widget.quizId == 'local'
                  ? Icons.explore_rounded
                  : Icons.price_check_rounded,
              size: 38,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              tr(quiz.scoreLabel),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$score / 100',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(label),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _retake,
        icon: const Icon(Icons.refresh),
        label: Text(tr('Try again')),
      ),
      const SizedBox(height: 24),
      ExpansionTile(
        title: Text(tr('Review your answers')),
        children: [
          for (var i = 0; i < quiz.questions.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ${tr(quiz.questions[i].text)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(tr(quiz.questions[i].options[_answers[i]].text)),
                    const SizedBox(height: 8),
                    Text(
                      tr(quiz.questions[i].explanation),
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }
}
