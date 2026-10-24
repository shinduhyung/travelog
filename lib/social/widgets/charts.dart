import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/social_profile.dart';
import '../theme.dart';

String compactNumber(num v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e4) return '${(v / 1e3).toStringAsFixed(0)}K';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// 가운데 라벨, 왼쪽 나 / 오른쪽 친구 막대. 이긴 쪽 강조.
class VsBar extends StatelessWidget {
  const VsBar({super.key, required this.label, required this.mine, required this.theirs, this.emoji, this.format});

  final String label;
  final num mine;
  final num theirs;
  final String? emoji;
  final String Function(num)? format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = math.max(math.max(mine, theirs), 1).toDouble();
    final fmt = format ?? compactNumber;
    Widget bar(num v, Color color, bool alignRight, bool win) => Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth * (v / maxV);
            return Stack(
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              children: [
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  width: math.max(w, v > 0 ? 6 : 0),
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: win ? 1 : 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fmt(v),
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: win ? FontWeight.w800 : FontWeight.w500,
                        color: w > 40 ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          bar(mine, AppColors.me, true, mine > theirs),
          SizedBox(
            width: 84,
            child: Column(
              children: [
                if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 16)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          bar(theirs, AppColors.friend, false, theirs > mine),
        ],
      ),
    );
  }
}

/// 두 사람 레이더 차트
class RadarVs extends StatelessWidget {
  const RadarVs({super.key, required this.axes, this.size = 240});

  final List<(String, double, double)> axes;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadarPainter(axes, Theme.of(context).colorScheme.outlineVariant, Theme.of(context).textTheme.labelSmall!),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.axes, this.grid, this.labelStyle);

  final List<(String, double, double)> axes;
  final Color grid;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.length < 3) return;
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 28;
    final n = axes.length;
    Offset at(int i, double v) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return center + Offset(math.cos(a), math.sin(a)) * r * v;
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = grid
      ..strokeWidth = 1;
    for (final level in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = at(i, level);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, at(i, 1), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: axes[i].$1, style: labelStyle.copyWith(fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = at(i, 1.18);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    void shape(double Function((String, double, double)) pick, Color color) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = at(i, pick(axes[i]).clamp(0.02, 1.0));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    shape((a) => a.$3, AppColors.friend);
    shape((a) => a.$2, AppColors.me);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.axes != axes;
}

/// 원형 진행률
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.color, this.size = 64, this.stroke = 7, this.child});

  final double value; // 0~1
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, color, color.withValues(alpha: 0.14), stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color;
}

/// 반원 게이지 (여행 궁합)
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value, this.size = 180, this.label});

  final int value; // 0~100
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value / 100),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutBack,
        builder: (context, v, _) => CustomPaint(
          painter: _GaugePainter(v.clamp(0, 1), AppColors.background),
          child: Align(
            alignment: const Alignment(0, 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${(v * 100).round()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                if (label != null)
                  Text(label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value, this.track);

  final double value;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height - stroke / 2), radius: size.width / 2 - stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base..color = track);
    base.shader = const SweepGradient(
      startAngle: math.pi,
      endAngle: math.pi * 2,
      colors: [AppColors.me, AppColors.both, AppColors.friend],
    ).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi * value, false, base);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}

/// 나만 / 둘 다 / 친구만 비율 막대 (벤 다이어그램 대신)
class OverlapBar extends StatelessWidget {
  const OverlapBar({super.key, required this.onlyMine, required this.both, required this.onlyTheirs, this.height = 30});

  final int onlyMine;
  final int both;
  final int onlyTheirs;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = onlyMine + both + onlyTheirs;
    final theme = Theme.of(context);
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      );
    }
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: n,
            child: Container(
              color: c,
              alignment: Alignment.center,
              child: Text('$n',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.clip,
                  maxLines: 1),
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        child: Row(children: [seg(onlyMine, AppColors.me), seg(both, AppColors.both), seg(onlyTheirs, AppColors.friend)]),
      ),
    );
  }
}

/// 깃허브 잔디 같은 퀴즈 히트맵 (최근 [weeks]주)
class QuizHeatmap extends StatelessWidget {
  const QuizHeatmap({super.key, required this.stats, required this.color, this.weeks = 18});

  final QuizStats stats;
  final Color color;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: weeks * 7 - 1 + (today.weekday % 7)));
    return LayoutBuilder(builder: (context, c) {
      final cell = math.min((c.maxWidth - (weeks - 1) * 3) / weeks, 14.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : 3),
              child: Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Builder(builder: (context) {
                      final day = start.add(Duration(days: w * 7 + d));
                      final key = QuizStats.keyOf(day);
                      final v = stats.days[key];
                      final future = day.isAfter(today);
                      return Container(
                        width: cell,
                        height: cell,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: future
                              ? Colors.transparent
                              : v == null
                                  ? AppColors.background
                                  : v
                                      ? color
                                      : color.withValues(alpha: 0.35),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// 연도별 누적 나라 수 (나 vs 친구)
class TimelineChart extends StatelessWidget {
  const TimelineChart({super.key, required this.mine, required this.theirs, this.height = 200});

  final Map<int, int> mine; // 연도 -> 누적
  final Map<int, int> theirs;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = {...mine.keys, ...theirs.keys}.toList()..sort();
    if (years.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(child: Text('No dated trips yet', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label))),
      );
    }
    final first = years.first;
    final last = math.max(years.last, DateTime.now().year);
    List<FlSpot> spots(Map<int, int> m) {
      final out = <FlSpot>[];
      var cur = 0;
      for (var y = first; y <= last; y++) {
        cur = m[y] ?? cur;
        out.add(FlSpot(y.toDouble(), cur.toDouble()));
      }
      return out;
    }

    LineChartBarData line(Map<int, int> m, Color c) => LineChartBarData(
          spots: spots(m),
          isCurved: true,
          preventCurveOverShooting: true,
          color: c,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: c.withValues(alpha: 0.12)),
        );

    final span = last - first;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: first.toDouble(),
          maxX: last.toDouble(),
          minY: 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: theme.textTheme.labelSmall),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: span <= 6 ? 1 : (span / 5).ceilToDouble(),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("'${(v.toInt() % 100).toString().padLeft(2, '0')}", style: theme.textTheme.labelSmall),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('${s.x.toInt()} · ${s.y.toInt()} ${s.y.toInt() == 1 ? 'country' : 'countries'}',
                      TextStyle(color: s.bar.color, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          lineBarsData: [
            if (theirs.isNotEmpty) line(theirs, AppColors.friend),
            if (mine.isNotEmpty) line(mine, AppColors.me),
          ],
        ),
      ),
    );
  }
}

/// 연도별 막대 (그 해 여행한 나라 수) 나 vs 친구
class YearBars extends StatelessWidget {
  const YearBars({super.key, required this.mine, required this.theirs, this.height = 180});

  final Map<int, int> mine;
  final Map<int, int> theirs;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = ({...mine.keys, ...theirs.keys}.toList()..sort());
    final shown = years.length > 10 ? years.sublist(years.length - 10) : years;
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("'${(shown[v.toInt()] % 100).toString().padLeft(2, '0')}", style: theme.textTheme.labelSmall),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${shown[group.x]} · ${rod.toY.toInt()} ${rod.toY.toInt() == 1 ? 'country' : 'countries'}',
                TextStyle(color: rod.color, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < shown.length; i++)
              BarChartGroupData(x: i, barsSpace: 3, barRods: [
                BarChartRodData(toY: (mine[shown[i]] ?? 0).toDouble(), color: AppColors.me, width: 8, borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: (theirs[shown[i]] ?? 0).toDouble(), color: AppColors.friend, width: 8, borderRadius: BorderRadius.circular(3)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// 분류별 도넛 (랜드마크 종류, UNESCO 유형 등)
class Donut extends StatelessWidget {
  const Donut({super.key, required this.data, this.size = 130, this.center});

  final Map<String, int> data;
  final double size;
  final Widget? center;

  static const palette = [
    Color(0xFF14B8A6), Color(0xFF8B5CF6), Color(0xFFF97316), Color(0xFF0EA5E9),
    Color(0xFFEC4899), Color(0xFF84CC16), Color(0xFFF59E0B), Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(7).toList();
    final rest = entries.skip(7).fold(0, (s, e) => s + e.value);
    final slices = [...top, if (rest > 0) MapEntry('Other', rest)];
    if (slices.isEmpty) return SizedBox(width: size, height: size);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: size * 0.3,
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].value.toDouble(),
                      color: palette[i % palette.length],
                      radius: size * 0.18,
                      showTitle: false,
                    ),
                ],
              )),
              ?center,
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < slices.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(slices[i].key,
                              style: Theme.of(context).textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      Text('${slices[i].value}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 여행 DNA 한 축: 양 끝 라벨 + 나/친구 마커
class DnaAxisRow extends StatelessWidget {
  const DnaAxisRow({
    super.key,
    required this.left,
    required this.right,
    required this.leftEmoji,
    required this.rightEmoji,
    this.mine,
    this.theirs,
  });

  final String left, right, leftEmoji, rightEmoji;
  final double? mine; // 0~100
  final double? theirs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$leftEmoji $left',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$right $rightEmoji',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            Widget marker(double v, Color color, String label) => Positioned(
                  left: (w - 26) * (v / 100),
                  top: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                );
            return SizedBox(
              height: 26,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 10,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(colors: [
                          AppColors.mint.withValues(alpha: 0.35),
                          AppColors.background,
                          AppColors.friend.withValues(alpha: 0.35),
                        ]),
                      ),
                    ),
                  ),
                  if (theirs != null) marker(theirs!, AppColors.friend, 'F'),
                  if (mine != null) marker(mine!, AppColors.me, 'You'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
