// My Trips 화면의 Travelog Social 메뉴: 보석빛 카드 + 바로가기 3개 (프로필 / 친구 / 통계)
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class SocialMenu extends StatelessWidget {
  const SocialMenu({
    super.key,
    required this.duelInvites,
    required this.onOpen,
    required this.onProfile,
    required this.onFriends,
    required this.onStats,
  });

  final int duelInvites;
  final VoidCallback onOpen;
  final VoidCallback onProfile;
  final VoidCallback onFriends;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Column(
      children: [
        SocialMenuCard(onTap: onOpen),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SocialShortcut(icon: Icons.account_circle_rounded, label: 'Profile', onTap: onProfile),
            ),
            const SizedBox(width: 8),
            Expanded(
              // 대결은 Friends 화면에서 친구를 골라 시작하므로, 받은 신청 배지도 여기에 단다
              child: SocialShortcut(icon: Icons.group_rounded, label: 'Friends', badge: duelInvites, onTap: onFriends),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SocialShortcut(icon: Icons.bar_chart_rounded, label: 'Stats', onTap: onStats),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 신규 기능 안내용 NEW 태그. (정적 — 애니메이션 없음)
// ─────────────────────────────────────────────
class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFFFB300)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.6), blurRadius: 8, spreadRadius: 0.5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white),
          SizedBox(width: 2),
          Text(
            tr('NEW'),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 소셜 카드 배경에 쓰이는 "색이 흐르는" 애니메이션 그라데이션.
// 폭이 2배인 그라데이션 띠를 계속 왼쪽으로 흘려보내는 방식이라, 색상
// 리스트의 처음/끝이 이어져 있으면 끊김 없이 무한 루프된다.
// ─────────────────────────────────────────────
class _FlowingGradient extends StatefulWidget {
  final List<Color> colors;
  final Duration duration;

  const _FlowingGradient({required this.colors, this.duration = const Duration(seconds: 5)});

  @override
  State<_FlowingGradient> createState() => _FlowingGradientState();
}

class _FlowingGradientState extends State<_FlowingGradient> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 색상 리스트를 두 번 이어 붙여서 "끝 -> 처음"이 자연스럽게 이어지도록 함.
    final loopColors = [...widget.colors, ...widget.colors];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -_controller.value * width;
              return Stack(
                children: [
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    width: width * 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: loopColors,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Travelog Social 진입 카드 (밝은 가넷빛, 색이 천천히 흐른다)
// ─────────────────────────────────────────────
class SocialMenuCard extends StatelessWidget {
  final VoidCallback onTap;

  const SocialMenuCard({super.key, required this.onTap});

  // 밝은 가넷/로도라이트 톤. 색 차이를 작게 해서 흐름이 은은하게 보이도록.
  static const List<Color> _gemFlow = [
    Color(0xFFC8566F),
    Color(0xFFD46A80),
    Color(0xFFC04F6C),
    Color(0xFFCF6279),
    Color(0xFFC8566F),
  ];

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFFC8566F).withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _FlowingGradient(colors: _gemFlow, duration: Duration(seconds: 9)),
            // 보석 표면의 은은한 반사광 하나
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.16), Colors.transparent],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Color(0xFFB0445F), size: 26),
                      ),
                      const Positioned(top: -7, right: -7, child: _NewBadge()),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    // 아주 큰 글씨에서는 카드 높이에 맞게 줄어든다
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr('TRAVEL WITH FRIENDS'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('Travelog Social'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 소셜 카드 아래의 바로가기 (내 프로필 / 친구 / 대결)
class SocialShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final int badge;
  final VoidCallback onTap;

  const SocialShortcut({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    this.badge = 0,
    required this.onTap,
  });

  static const Color ruby = Color(0xFFB0445F);

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ruby.withOpacity(0.10)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                backgroundColor: const Color(0xFFEF4444),
                child: Icon(icon, color: ruby, size: 22),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(label),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF5C1F30)),
                ),
              ),
              if (caption != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    caption!,
                    maxLines: 1,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ruby.withOpacity(0.7)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
