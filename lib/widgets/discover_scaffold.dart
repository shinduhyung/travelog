import 'package:flutter/material.dart';
import 'native_back_scope.dart';

/// Uses the same spacing, rounded white cards and mint/blue accents as My Hub
/// and the existing recommendation screens, scoped to Discover pages.
class DiscoverScaffold extends StatelessWidget {
  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  const DiscoverScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const background = Color(0xFFF8FAFC);
    final base = Theme.of(context);
    return NativeBackScope(
      child: Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: background,
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: const Color(0xFF1F2937),
            elevation: 0,
            titleTextStyle: TextStyle(
              fontFamily: base.textTheme.titleLarge?.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          cardTheme: base.cardTheme.copyWith(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
            color: blue,
            linearTrackColor: const Color(0xFFE2E8F0),
          ),
        ),
        child: Scaffold(
          appBar: appBar,
          body: SafeArea(
            top: false,
            bottom: bottomNavigationBar == null,
            child: body,
          ),
          bottomNavigationBar: bottomNavigationBar == null
              ? null
              : SafeArea(top: false, child: bottomNavigationBar!),
        ),
      ),
    );
  }
}
