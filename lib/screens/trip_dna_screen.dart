import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/models/personality_question.dart';

// 새롭게 추가할 슬라이더 위젯 (같은 파일 내에 정의)
class CustomSliderWidget extends StatelessWidget {
  final int? selectedValue;
  final ValueChanged<int> onChanged;

  const CustomSliderWidget({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final double valueToDisplay = selectedValue?.toDouble() ?? 0.0;
    final bool isAnswered = selectedValue != null;

    final Color activeColor = Theme.of(context).primaryColor;
    final Color inactiveColor = Colors.grey[300]!;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor: inactiveColor,
            thumbColor: activeColor,
            overlayColor: activeColor.withOpacity(0.2),
            trackHeight: 6.0,
            thumbShape: isAnswered
                ? const RoundSliderThumbShape(enabledThumbRadius: 10.0)
                : const RoundSliderThumbShape(enabledThumbRadius: 0.0),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: valueToDisplay,
            min: 0,
            max: 7,
            divisions: 7,
            onChanged: (double newValue) {
              if (newValue.round() >= 1) {
                onChanged(newValue.round());
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0)
              .copyWith(left: 16.0 + 24.0 / 2, right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final score = index + 1;
              final isSelected = selectedValue == score;
              return Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected && isAnswered ? activeColor.withOpacity(0.15) : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  tr('$score'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected && isAnswered ? FontWeight.bold : FontWeight.normal,
                    color: isSelected && isAnswered ? activeColor : Colors.grey,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}


class TripDnaScreen extends StatefulWidget {
  const TripDnaScreen({super.key});

  @override
  State<TripDnaScreen> createState() => _TripDnaScreenState();
}

class _TripDnaScreenState extends State<TripDnaScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonalityProvider>().loadQuestions();
    });
  }

  void _onAnswered(int questionId, int score, PersonalityProvider provider) {
    provider.answerQuestion(questionId, score);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = context.watch<PersonalityProvider>();
    final questions = provider.questions;
    final allAnswered = questions.isNotEmpty && provider.responses.length == questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // 더 부드러운 밝은 배경

      body: SafeArea(
        child: provider.isCalculated
            ? _buildResultScreen(provider)
            : questions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildQuizScreen(questions, provider),
      ),

      bottomNavigationBar: provider.isCalculated || questions.isEmpty
          ? null
          : _buildBottomButton(context, provider, allAnswered),
    );
  }

  Widget _buildQuizScreen(
      List<PersonalityQuestion> questions,
      PersonalityProvider provider) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 섹션 - 밝은 accent 추가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 작은 accent 라벨
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr('PERSONALITY TEST'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('Travel Personality\nQuiz'),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 진행률 표시
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if(provider.isCalculated)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: Theme.of(context).primaryColor),
                  onPressed: provider.resetQuiz,
                  tooltip: tr('Reset Quiz'),
                )
            ],
          ),
          const SizedBox(height: 32),

          // 질문 카드들
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final isAnswered = provider.responses.containsKey(question.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAnswered
                        ? Theme.of(context).primaryColor.withOpacity(0.3)
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAnswered
                          ? Theme.of(context).primaryColor.withOpacity(0.08)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 질문 번호와 체크마크
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isAnswered
                                  ? Theme.of(context).primaryColor.withOpacity(0.15)
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isAnswered
                                  ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              )
                                  : Text(
                                tr("${index + 1}"),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr("Question ${index + 1}"),
                              style: TextStyle(
                                color: isAnswered
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 질문 텍스트
                      Text(
                        tr(question.text),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 레이블
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('Disagree'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                          Text(
                            tr('Agree'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 슬라이더
                      CustomSliderWidget(
                        selectedValue: provider.responses[question.id],
                        onChanged: (score) => _onAnswered(question.id, score, provider),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
      BuildContext context,
      PersonalityProvider provider,
      bool allAnswered) {

    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: allAnswered ? [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ] : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: allAnswered
                ? Theme.of(context).primaryColor
                : Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: allAnswered ? () => provider.calculateScores() : null,
          child: Text(
            tr("View Results"),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: allAnswered ? Colors.white : Colors.grey[500],
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen(PersonalityProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 결과 화면 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr('YOUR RESULTS'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                     Text(
                      tr("Travel DNA"),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: Theme.of(context).primaryColor),
                  onPressed: provider.resetQuiz,
                  tooltip: tr('Retake Quiz'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // 결과 바들
          ...provider.dimensions.map((dim) {
            final score = provider.finalScores[dim] ?? 50.0;
            final leftLabel = provider.getLeftLabel(dim);
            final rightLabel = provider.getRightLabel(dim);
            final isLeftDominant = score < 40;
            final isRightDominant = score > 60;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // 레이블
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isLeftDominant
                                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr(leftLabel),
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isLeftDominant ? FontWeight.w700 : FontWeight.w500,
                                  color: isLeftDominant
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isRightDominant
                                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr(rightLabel),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRightDominant ? FontWeight.w700 : FontWeight.w500,
                                  color: isRightDominant
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 프로그레스 바
                      SizedBox(
                        height: 20,
                        child: Stack(
                          children: [
                            // 배경
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            // 중앙선
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  width: 2,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                            // 점수 바
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: score / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).primaryColor.withOpacity(0.7),
                                          Theme.of(context).primaryColor,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 점수 표시
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment(
                                  (score - 50) / 50, // -1 to 1 range
                                  0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    tr("${score.round()}"),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}