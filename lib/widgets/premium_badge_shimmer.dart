// lib/widgets/premium_badge_shimmer.dart
//
// "완료했지만 미구독이라 못 받는" 프리미엄 뱃지 상태 전용 위젯.
// 흑백(자물쇠 상태)도, 완전 컬러(정상 해금)도 아닌 그 사이를 천천히 오가며
// "이미 내 것"이라는 인식과 아쉬움을 동시에 유발한다.
//
// [중요] 이 위젯은 순수 시각 효과만 담당하고 자체 탭 동작은 없다.
// 예전엔 여기에 GestureDetector를 달아서 이미지를 탭하면 바로 구독 시트가
// 뜨게 했었는데, 그러면 그리드 카드처럼 이 위젯이 다른 탭 영역(진행률 팝업 등)
// 안에 중첩되는 경우 안쪽 탭이 우선권을 가져가서 팝업을 건너뛰고 바로 구독
// 화면으로 가버리는 문제가 있었다. 탭 시 무엇을 할지는 이 위젯을 사용하는
// 쪽(그리드 카드 → 팝업, 팝업 → "Subscribe to Claim" 버튼 등)에서 명시적으로
// 결정한다.
import 'package:flutter/material.dart';

class PremiumBadgeShimmer extends StatefulWidget {
  final Widget child; // 뱃지 이미지 (Image.asset 등)

  /// 채도 진동 범위. 1.0 = 완전 컬러, 0.0 = 완전 흑백.
  final double minSaturation;
  final Duration cycleDuration;

  const PremiumBadgeShimmer({
    Key? key,
    required this.child,
    this.minSaturation = 0.0,
    this.cycleDuration = const Duration(milliseconds: 2200),
  }) : super(key: key);

  @override
  State<PremiumBadgeShimmer> createState() => _PremiumBadgeShimmerState();
}

class _PremiumBadgeShimmerState extends State<PremiumBadgeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _saturation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    )..repeat(reverse: true);

    // easeInOutSine: 양 끝(완전 컬러/완전 흑백)에서 속도가 거의 0에 가까워서
    // "깜빡"이는 느낌 없이 숨 쉬듯 천천히 넘어간다.
    _saturation = Tween<double>(begin: 1.0, end: widget.minSaturation)
        .chain(CurveTween(curve: Curves.easeInOutSine))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Android ColorMatrix의 표준 saturation 공식.
  // sat=1 → 원본 컬러, sat=0 → 완전 흑백(휘도 기준).
  List<double> _saturationMatrix(double sat) {
    const lumR = 0.213, lumG = 0.715, lumB = 0.072;
    final invSat = 1 - sat;
    return <double>[
      lumR * invSat + sat, lumG * invSat, lumB * invSat, 0, 0,
      lumR * invSat, lumG * invSat + sat, lumB * invSat, 0, 0,
      lumR * invSat, lumG * invSat, lumB * invSat + sat, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _saturation,
      builder: (context, _) {
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(
            _saturationMatrix(_saturation.value),
          ),
          child: widget.child,
        );
      },
    );
  }
}