import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/global_stats.dart';
import 'flag.dart';

/// Travelog 순위표 카드 (제목 2줄 + 부제 + Top 10). SNS용 이미지와 같은 모양을 위젯으로 그린다.
/// 설계 크기 360x540(2:3)로 그린 뒤 가로 폭에 맞춰 줄여서, 어디에 놓아도 비율이 같다.
class RankingCard extends StatelessWidget {
  const RankingCard({super.key, required this.data});

  final RankingData data;

  static const double designWidth = 360;
  static const double designHeight = 540;

  // 순위별 막대/숫자 색: 1~3위는 보라/주황 계열, 나머지는 고정 팔레트
  static const _rankColors = <Color>[
    Color(0xFFD946EF),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFB45309),
    Color(0xFF1E3A8A),
    Color(0xFF0EA5E9),
    Color(0xFFE11D48),
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: designWidth / designHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        // 이미지처럼 고정된 모양이라 기기의 글자 크기 설정은 따르지 않는다
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox(width: designWidth, height: designHeight, child: _CardBody(data: data)),
        ),
      ),
    );
  }

  static Color colorAt(int i) => _rankColors[i % _rankColors.length];
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.data});

  final RankingData data;

  @override
  Widget build(BuildContext context) {
    final rows = data.rows;
    final top = rows.isEmpty ? 1.0 : rows.first.value.abs();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F8FF), Color(0xFFFFFFFF), Color(0xFFF3F0FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          children: [
            const _Brand(),
            const SizedBox(height: 2),
            Text(data.titleTop,
                maxLines: 1,
                style: const TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1.5)),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899)]).createShader(r),
              child: Text(data.titleBottom,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5)),
            ),
            const SizedBox(height: 2),
            Text(data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF2547C8))),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Expanded(child: _Row(rank: i + 1, row: rows[i], fraction: top == 0 ? 0 : (rows[i].value.abs() / top).clamp(0.02, 1.0))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('follow @travelog_travel_map for more travel stats',
                style: TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/icons/app_logo.png', width: 24, height: 24, errorBuilder: (_, _, _) => const SizedBox(width: 24, height: 24)),
        ),
        const SizedBox(width: 6),
        const Text('Travelog', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8))),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.row, required this.fraction});

  final int rank;
  final RankRow row;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = RankingCard.colorAt(rank - 1);
    final tint = switch (rank) {
      1 => const Color(0xFFFCE7F8),
      2 => const Color(0xFFF1EDFF),
      3 => const Color(0xFFFFEFE6),
      _ => Colors.white,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: rank == 1 ? Border.all(color: const Color(0xFFF5C2EE)) : null,
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: rank >= 10 ? 20 : 24, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(width: 6),
          Flag(row.iso2, width: 30, radius: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.1)),
                if (row.sub != null)
                  Text(row.sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF), height: 1.1)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 6, color: const Color(0xFFE5E7EB)),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(height: 6, color: color),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 62, maxWidth: 96),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(row.valueText, maxLines: 1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드를 이미지로 만들어 공유 시트를 연다.
Future<void> shareRankingCard(BuildContext context, RankingData data, {String? id}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final bytes = await ScreenshotController().captureFromWidget(
    MediaQuery(
      data: MediaQueryData.fromView(View.of(context)).copyWith(devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(width: RankingCard.designWidth, height: RankingCard.designHeight, child: _CardBody(data: data)),
        ),
      ),
    ),
    pixelRatio: 3,
    delay: const Duration(milliseconds: 250),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/travelog_${id ?? 'ranking'}.png');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin));
}
