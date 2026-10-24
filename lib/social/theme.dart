import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Travelog(jidoapp)와 같은 디자인 언어:
/// 테마색은 홈 화면 Travelog Social 카드와 같은 가넷빛 붉은색 (이름은 mint로 남겨 둠), 연회색 배경, 흰 카드(radius 24 + 부드러운 그림자), 틴트 아이콘 타일, Poppins.
class AppColors {
  static const mint = Color(0xFFC8566F); // 가넷 (홈 화면 소셜 카드와 같은 색)
  static const darkMint = Color(0xFFA63D58); // 진한 가넷 (글자, 버튼)
  static const primary = Color(0xFFD46A80); // 밝은 가넷
  static const background = Color(0xFFF5F5F5);
  static const ink = Color(0xFF111827);
  static const label = Color(0xFF9CA3AF);
  static const line = Color(0xFFF3F4F6);
  static const indigo = Color(0xFF6366F1);

  // 비교 화면에서 같은 의미로 쓰는 색
  static const me = mint; // 나
  static const friend = Color(0xFF8B5CF6); // 친구
  static const both = Color(0xFFEC4899); // 둘 다

  static const gold = Color(0xFFF5B301);
  static const silver = Color(0xFF9CA3AF);
  static const bronze = Color(0xFFCD7F32);

  static const tealGradient = LinearGradient(
    colors: [Color(0xFFD46A80), Color(0xFFC04F6C), Color(0xFFA63D58)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const vsGradient = LinearGradient(
    colors: [Color(0xFFC8566F), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const quizGradient = LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]);

  static const cardShadow = [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 12))];

  static Color land(BuildContext context) => const Color(0xFFE5E7EB);
  static Color ocean(BuildContext context) => const Color(0xFFF8FAFC);
}

/// Travelog 홈 상단 타이틀과 같은 스타일 (하늘 배경 위 흰 글씨 + 그림자)
const heroTitleStyle = TextStyle(
  fontSize: 42,
  fontWeight: FontWeight.w900,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.0,
  shadows: [Shadow(offset: Offset(0, 2), blurRadius: 10, color: Color.fromARGB(120, 0, 0, 0))],
);

const heroSubtitleStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  shadows: [Shadow(offset: Offset(0, 1), blurRadius: 8, color: Color.fromARGB(110, 0, 0, 0))],
);

/// 테스트에서는 네트워크 폰트를 쓰지 않는다
bool useGoogleFonts = true;

TextTheme _textTheme(TextTheme base) {
  final themed = base.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  return useGoogleFonts ? GoogleFonts.poppinsTextTheme(themed) : themed;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.darkMint,
    secondary: AppColors.indigo,
    surface: Colors.white,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.light);
  final text = _textTheme(base.textTheme);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AppColors.mint.withValues(alpha: 0.18),
      labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkMint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.darkMint)),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.mint : const Color(0xFFD1D5DB)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.mint.withValues(alpha: 0.18),
        selectedForegroundColor: AppColors.darkMint,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Travelog식 아이콘 타일: 연한 틴트 배경의 둥근 사각형 안에 아이콘/이모지
class IconTile extends StatelessWidget {
  const IconTile({super.key, this.icon, this.emoji, this.color = AppColors.mint, this.size = 44});

  final IconData? icon;
  final String? emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: icon != null
          ? Icon(icon, color: Color.lerp(color, Colors.black, 0.25), size: size * 0.52)
          : Text(emoji ?? '', style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// Travelog식 흰 카드 (radius 24 + 부드러운 그림자)
class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.cardShadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// 회색 작은 라벨 + 굵은 값 (Travelog 홈 카드의 "Traveler Type / Analyze DNA" 형태)
class LabelValue extends StatelessWidget {
  const LabelValue({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: valueColor ?? AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
