import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/subscription_service.dart';

/// Which plan is currently selected on the paywall. Purely UI state —
/// the actual product id resolution happens in [_SubscriptionSheetState._selectedProductId].
enum _PlanChoice { monthly, yearly, lifetime }

/// Per-plan color theme. Yearly stays on-brand (mint/teal, matches the
/// app's #1ABFBC brand color). Monthly gets its own green so it reads as
/// a distinct, lighter-commitment option. Lifetime gets a rich, saturated
/// purple→violet→pink gradient with sparkle accents and a glow — it's
/// meant to visually outshine the other two, since it's the plan we most
/// want subscribers trading up to.
class _PlanTheme {
  final List<Color> colors;
  final bool vivid; // true only for lifetime — triggers the "fancy" hero treatment
  const _PlanTheme(this.colors, {this.vivid = false});

  Color get solid => colors.first;
  LinearGradient get gradient => LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const _monthlyTheme = _PlanTheme([Color(0xFF34D399), Color(0xFF10B981)]);
const _yearlyTheme = _PlanTheme([Color(0xFF3DDAD7), Color(0xFF00A39F)]);
const _lifetimeTheme = _PlanTheme(
  [Color(0xFF6D28D9), Color(0xFFA855F7), Color(0xFFEC4899)],
  vivid: true,
);

_PlanTheme _themeFor(_PlanChoice choice) {
  switch (choice) {
    case _PlanChoice.monthly:
      return _monthlyTheme;
    case _PlanChoice.yearly:
      return _yearlyTheme;
    case _PlanChoice.lifetime:
      return _lifetimeTheme;
  }
}

class SubscriptionSheet extends StatefulWidget {
  /// Short label for what surfaced this paywall (e.g. 'ad_dismiss',
  /// 'badge_moment', 'settings'). Logged with the checkout funnel event so
  /// trigger effectiveness can be compared later. Pass null if the call
  /// site doesn't track this yet.
  final String? triggerContext;

  const SubscriptionSheet({super.key, this.triggerContext});

  static Future<void> show(BuildContext context, {String? triggerContext}) {
    AdService.instance.setUiOverlayActive();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionSheet(triggerContext: triggerContext),
    ).whenComplete(() => AdService.instance.clearUiOverlayActive());
  }

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  // Yearly preselected — it's the plan we want most people to land on.
  _PlanChoice _selected = _PlanChoice.yearly;

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, sub, _) {
        if (sub.isPremium) {
          return _buildActiveSheet(context, sub);
        }
        return _buildPaywallSheet(context, sub);
      },
    );
  }

  // ── Already-subscribed state ──────────────────────────────────────────
  Widget _buildActiveSheet(BuildContext context, SubscriptionService sub) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handleBar(),
          const SizedBox(height: 20),
          _logo(),
          const SizedBox(height: 14),
          const Text(
            'Travelog Premium',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            sub.isLifetime
                ? 'You have lifetime Premium access ✓'
                : 'You are subscribed to Premium ✓',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3DDAD7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3DDAD7)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF3DDAD7), size: 20),
                SizedBox(width: 8),
                Text('Premium Active',
                    style: TextStyle(
                        color: Color(0xFF3DDAD7),
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),

          // 기존 구독자용 Lifetime 업그레이드 — 이미 lifetime인 유저에겐 숨김.
          // 가격은 항상 sub.productDetailsFor()로 스토어에서 조회한 실제
          // 값(국가별로 다름)을 그대로 씀, 하드코딩 없음.
          if (!sub.isLifetime) ...[
            const SizedBox(height: 20),
            Builder(builder: (context) {
              final ProductDetails? lifetime =
              sub.productDetailsFor(SubscriptionService.kLifetimeId);
              return _GradientGlowButton(
                theme: _lifetimeTheme,
                enabled: !sub.isLoading && lifetime != null,
                loading: sub.isLoading,
                label: lifetime != null
                    ? 'Upgrade to Lifetime — ${lifetime.price}'
                    : 'Upgrade to Lifetime',
                onTap: () => _handleUpgradeToLifetime(context, sub),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'One-time payment for lifetime access. Your current subscription won\'t cancel automatically — cancel it separately in your Play Store subscriptions to avoid being charged for both.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500], height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleUpgradeToLifetime(
      BuildContext context, SubscriptionService sub) async {
    final bool success = await sub.buyProduct(
      SubscriptionService.kLifetimeId,
      triggerContext: 'existing_subscriber_upgrade',
    );
    if (success && context.mounted) Navigator.of(context).pop();
  }

  // ── Paywall ──────────────────────────────────────────────────────────
  Widget _buildPaywallSheet(BuildContext context, SubscriptionService sub) {
    final _PlanTheme theme = _themeFor(_selected);
    final ProductDetails? selectedDetails =
    _productDetailsFor(_selected, sub);
    // yearly 카드에 "월별로 냈으면 이만큼" 원가를 찍찍 긋고 보여주려면
    // monthly 가격이 항상 필요함 (선택된 게 monthly가 아니어도).
    final ProductDetails? monthlyForCompare =
    sub.productDetailsFor(SubscriptionService.kMonthlyId);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handleBar(),
            const SizedBox(height: 20),
            _logo(),
            const SizedBox(height: 14),
            const Text(
              'Travelog Premium',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Unlock everything, ad-free',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // ── Segmented plan switch ───────────────────────────────────
            _PlanSwitch(
              selected: _selected,
              onChanged: (choice) => setState(() => _selected = choice),
            ),
            const SizedBox(height: 16),

            // ── Hero card for the currently-selected plan ───────────────
            _PlanHeroCard(
              choice: _selected,
              theme: theme,
              details: selectedDetails,
              monthlyForCompare: monthlyForCompare,
            ),
            const SizedBox(height: 20),

            // Benefits — lead with what's unique to Premium; ad removal
            // last since it's a bonus, not the headline. Icon color follows
            // the currently-selected plan's theme, so switching plans
            // re-tints this list too.
            _BenefitRow(
                icon: Icons.emoji_events_rounded,
                label: 'Unlock all 500+ badges',
                highlightWord: '500+ badges',
                color: theme.solid,
                tag: 'NEW'),
            const SizedBox(height: 10),
            _BenefitRow(
                icon: Icons.psychology_alt_rounded,
                label: 'Daily Quiz — Expert mode',
                highlightWord: 'Expert mode',
                color: theme.solid,
                tag: 'NEW'),
            const SizedBox(height: 10),
            _BenefitRow(
                icon: Icons.bar_chart_rounded,
                label: 'Full stats — countries, cities, landmarks & flights',
                highlightWord: 'Full stats',
                color: theme.solid),
            const SizedBox(height: 10),
            _BenefitRow(
                icon: Icons.block_rounded,
                label: 'No interstitial or banner ads',
                highlightWord: 'ads',
                color: theme.solid),
            const SizedBox(height: 22),

            // ── CTA — themed to match the selected plan ────────────────
            _GradientGlowButton(
              theme: theme,
              enabled: !sub.isLoading && selectedDetails != null,
              loading: sub.isLoading,
              label: _ctaLabel(),
              onTap: () => _handlePurchase(context, sub),
            ),
            const SizedBox(height: 10),

            // Auto-renew / one-time disclosure — required by store policy,
            // wording changes with the selected plan.
            Text(
              _disclosureText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500], height: 1.4),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed:
              sub.isLoading ? null : () => sub.restorePurchases(),
              child: Text('Restore Purchases',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  ProductDetails? _productDetailsFor(
      _PlanChoice choice, SubscriptionService sub) {
    switch (choice) {
      case _PlanChoice.monthly:
        return sub.productDetailsFor(SubscriptionService.kMonthlyId);
      case _PlanChoice.yearly:
        return sub.productDetailsFor(sub.yearlyProductIdToOffer);
      case _PlanChoice.lifetime:
        return sub.productDetailsFor(SubscriptionService.kLifetimeId);
    }
  }

  String _selectedProductId(SubscriptionService sub) {
    switch (_selected) {
      case _PlanChoice.monthly:
        return SubscriptionService.kMonthlyId;
      case _PlanChoice.yearly:
        return sub.yearlyProductIdToOffer;
      case _PlanChoice.lifetime:
        return SubscriptionService.kLifetimeId;
    }
  }

  String _ctaLabel() {
    return _selected == _PlanChoice.lifetime
        ? 'Get Lifetime Access'
        : 'Subscribe Now';
  }

  String _disclosureText() {
    if (_selected == _PlanChoice.lifetime) {
      return 'One-time payment. No recurring charges.';
    }
    final String period = _selected == _PlanChoice.monthly ? 'month' : 'year';
    final String storeName = Platform.isIOS ? 'App Store' : 'Play Store';
    return 'Auto-renews every $period until cancelled. Manage or cancel anytime in your $storeName account settings.';
  }

  Future<void> _handlePurchase(
      BuildContext context, SubscriptionService sub) async {
    final bool success = await sub.buyProduct(
      _selectedProductId(sub),
      triggerContext: widget.triggerContext,
    );
    if (success && context.mounted) Navigator.of(context).pop();
  }

  Widget _handleBar() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
        color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
  );

  Widget _logo() => Image.asset(
    'assets/icons/app_logo_large.png',
    height: 56,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => const Icon(
        Icons.workspace_premium_rounded,
        size: 56,
        color: Color(0xFF3DDAD7)),
  );
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  // [수정] 문장 전체가 아니라 이 안의 특정 단어/구절만 테마 컬러로 강조.
  // label 안에 이 문자열이 있으면 그 부분만 굵게+색칠되고 나머지는 평범한 회색.
  final String? highlightWord;
  // [추가] 오른쪽에 붙는 작은 "NEW" 태그. null이면 안 보임.
  final String? tag;

  const _BenefitRow({
    required this.icon,
    required this.label,
    required this.color,
    this.highlightWord,
    this.tag,
  });

  Widget _buildLabel() {
    const baseStyle = TextStyle(fontSize: 14, color: Color(0xFF444444), height: 1.3);

    final word = highlightWord;
    if (word == null || !label.contains(word)) {
      return Text(label, style: baseStyle);
    }

    final idx = label.indexOf(word);
    final before = label.substring(0, idx);
    final match = label.substring(idx, idx + word.length);
    final after = label.substring(idx + word.length);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildLabel()),
        if (tag != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 3-way segmented "switch" — tap a pill to flip [_PlanHeroCard] below to
/// that plan. Each pill fills with its own theme gradient when active
/// (green / mint / purple+pink) instead of one fixed accent color, so the
/// switch itself previews which plan you're looking at.
class _PlanSwitch extends StatelessWidget {
  final _PlanChoice selected;
  final ValueChanged<_PlanChoice> onChanged;

  const _PlanSwitch({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _pill(_PlanChoice.monthly, 'Monthly', _monthlyTheme),
          _pill(_PlanChoice.yearly, 'Yearly', _yearlyTheme),
          _pill(_PlanChoice.lifetime, 'Lifetime', _lifetimeTheme),
        ],
      ),
    );
  }

  Widget _pill(_PlanChoice choice, String label, _PlanTheme theme) {
    final bool active = choice == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(choice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? theme.gradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
              BoxShadow(
                  color: theme.solid.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF888C99),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big detail card for whichever plan is currently selected.
///
/// All three share one inner layout: same padding, same label/tagline/price
/// row, and — critically — the same fixed-height slot below the price row.
/// That reserved slot is what guarantees identical card height regardless
/// of plan; it's empty for Monthly/Lifetime and holds the discount chip for
/// Yearly. Never put plan-specific content inline in a row that isn't the
/// same shape across all three — that's what caused the height to jump
/// between plans before.
///
/// The tinted background is blended to a fully OPAQUE pale color (never a
/// low-opacity wash) — a semi-transparent background lets the border's
/// full-strength color bleed through from underneath and wash out the
/// text, which is what caused the "text disappears" bug earlier.
class _PlanHeroCard extends StatelessWidget {
  final _PlanChoice choice;
  final _PlanTheme theme;
  final ProductDetails? details;
  final ProductDetails? monthlyForCompare;

  static const double _outerRadius = 18;
  static const double _borderWidth = 2.5;
  static const double _bottomSlotHeight = 28;

  const _PlanHeroCard({
    required this.choice,
    required this.theme,
    required this.details,
    required this.monthlyForCompare,
  });

  String get _label {
    switch (choice) {
      case _PlanChoice.monthly:
        return 'Monthly';
      case _PlanChoice.yearly:
        return 'Yearly';
      case _PlanChoice.lifetime:
        return 'Lifetime';
    }
  }

  String get _tagline {
    switch (choice) {
      case _PlanChoice.monthly:
        return 'Try it out, cancel anytime';
      case _PlanChoice.yearly:
        return 'Our most popular plan';
      case _PlanChoice.lifetime:
        return 'Pay once, yours forever';
    }
  }

  String get _priceSuffix {
    switch (choice) {
      case _PlanChoice.monthly:
        return '/ month';
      case _PlanChoice.yearly:
        return '/ year';
      case _PlanChoice.lifetime:
        return 'one-time';
    }
  }

  /// Real math (monthly × 12), not a marketing percentage — how much a
  /// year costs if paid month-by-month, vs. [details]'s actual yearly
  /// price. Only meaningful when [choice] is yearly.
  int? get _savingsPercent {
    if (choice != _PlanChoice.yearly || monthlyForCompare == null || details == null) {
      return null;
    }
    final double yearlyIfPaidMonthly = monthlyForCompare!.rawPrice * 12;
    if (yearlyIfPaidMonthly <= 0) return null;
    final double savings = (yearlyIfPaidMonthly - details!.rawPrice) / yearlyIfPaidMonthly;
    if (savings <= 0) return null;
    return (savings * 100).round();
  }

  /// Formats [amount] using the same currency symbol already present in
  /// [sampleFormattedPrice] (e.g. "$4.99" → prefix "$"), so a derived
  /// figure like "monthly × 12" always matches the store's own formatting
  /// instead of assuming "$".
  String _formatWithSameCurrency(double amount, String sampleFormattedPrice) {
    final String formatted = amount.toStringAsFixed(2);
    final prefixMatch = RegExp(r'^[^\d]+').firstMatch(sampleFormattedPrice);
    if (prefixMatch != null) return '${prefixMatch.group(0)!.trim()}$formatted';
    final suffixMatch = RegExp(r'[^\d]+$').firstMatch(sampleFormattedPrice);
    if (suffixMatch != null) return '$formatted${suffixMatch.group(0)!.trim()}';
    return formatted;
  }

  /// "$59.88" — what a year costs paying month-by-month, struck through
  /// next to the discount chip.
  String? get _originalAnnualText {
    if (choice != _PlanChoice.yearly || monthlyForCompare == null) return null;
    final double perYearIfMonthly = monthlyForCompare!.rawPrice * 12;
    return _formatWithSameCurrency(perYearIfMonthly, monthlyForCompare!.price);
  }

  @override
  Widget build(BuildContext context) {
    final bool vivid = theme.vivid;
    final bool isYearly = choice == _PlanChoice.yearly;

    // Text stays fixed dark/neutral regardless of plan — never theme.solid —
    // so it can never blend into the card's own (theme-colored) background.
    final Color labelColor = vivid ? Colors.white : const Color(0xFF1A1A2E);
    final Color taglineColor = vivid ? Colors.white.withOpacity(0.85) : const Color(0xFF6B7280);
    final Color priceColor = vivid ? Colors.white : const Color(0xFF1A1A2E);
    final Color suffixColor = vivid ? Colors.white.withOpacity(0.8) : const Color(0xFF9AA0AC);
    final Color strikeColor = vivid ? Colors.white.withOpacity(0.65) : const Color(0xFF9AA0AC);

    final int? savingsPercent = _savingsPercent;
    final String? originalAnnual = _originalAnnualText;
    final bool showDiscountRow = isYearly && savingsPercent != null;

    // Background: Monthly is a plain flat single-color tint (intentionally
    // the "least special" of the three). Yearly gets a visible two-tone
    // wash blending BOTH of its theme colors, so it doesn't read as "the
    // same design as Monthly, just green vs. teal." Lifetime keeps its
    // full vivid gradient fill.
    Gradient? bgGradient;
    Color? bgColor;
    if (vivid) {
      bgGradient = theme.gradient;
    } else if (isYearly) {
      bgGradient = LinearGradient(
        colors: [
          Color.alphaBlend(theme.colors[0].withOpacity(0.14), Colors.white),
          Color.alphaBlend(theme.colors[1].withOpacity(0.14), Colors.white),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      bgColor = Color.alphaBlend(theme.solid.withOpacity(0.07), Colors.white);
    }

    final Widget innerCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: bgGradient,
        color: bgColor,
        borderRadius: BorderRadius.circular(_outerRadius - _borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: labelColor)),
          const SizedBox(height: 2),
          Text(_tagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: taglineColor)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                details?.price ?? '—',
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, color: priceColor),
              ),
              const SizedBox(width: 6),
              Text(_priceSuffix, style: TextStyle(fontSize: 13, color: suffixColor)),
            ],
          ),
          // 항상 같은 자리를 차지하는 고정 높이 슬롯 — 이게 있어야 yearly만
          // 내용이 있어도 세 카드 전체 높이가 절대 안 흔들림. Monthly/
          // Lifetime은 이 자리를 비워둠(내용 없이 SizedBox만).
          SizedBox(
            height: _bottomSlotHeight,
            child: showDiscountRow
                ? Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: theme.gradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '-$savingsPercent% OFF',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2),
                    ),
                  ),
                  if (originalAnnual != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        originalAnnual,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: strikeColor,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: strikeColor,
                            decorationThickness: 2),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : null,
          ),
        ],
      ),
    );

    // Monthly: flat single-color border. Yearly: static two-tone gradient
    // border. Lifetime: the same gradient, but rotating.
    final List<Color> borderColors =
    choice == _PlanChoice.monthly ? [theme.solid, theme.solid] : theme.colors;

    final Widget bordered = _CardBorder(
      colors: borderColors,
      animated: vivid,
      borderWidth: _borderWidth,
      borderRadius: _outerRadius,
      child: innerCard,
    );

    Widget card = bordered;
    if (vivid) {
      // Ambient glow sits outside the border ring so it isn't clipped by it.
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_outerRadius),
          boxShadow: [
            BoxShadow(
                color: theme.colors[0].withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: theme.colors.last.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: bordered,
      );
    }

    if (!isYearly) return card;

    // "MOST POPULAR" ribbon — a Positioned overlay in a Stack, so it never
    // affects the Stack's own size (Stack sizes to the non-positioned
    // `card` child only). Purely decorative, safe against the height-jump
    // bug by construction.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -10,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: theme.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: theme.solid.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: const Text('MOST POPULAR',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4)),
          ),
        ),
      ],
    );
  }
}

/// Wraps [child] in a border of constant [borderWidth], colored with
/// [colors]. When [animated] is false it's a static gradient (or a flat
/// color, if both entries in [colors] match) — when true, the gradient
/// visibly spins around the card using a rotating [SweepGradient], giving
/// a "light chasing around the edge" effect.
class _CardBorder extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final bool animated;
  final double borderWidth;
  final double borderRadius;

  const _CardBorder({
    required this.child,
    required this.colors,
    required this.animated,
    required this.borderWidth,
    required this.borderRadius,
  });

  @override
  State<_CardBorder> createState() => _CardBorderState();
}

class _CardBorderState extends State<_CardBorder>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget inner = ClipRRect(
      borderRadius:
      BorderRadius.circular(widget.borderRadius - widget.borderWidth),
      child: widget.child,
    );

    if (!widget.animated) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: widget.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(widget.borderWidth),
        child: inner,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              // 3색을 두 바퀴 반복 배치 -> 회전 중 "빛 덩어리" 하나가
              // 도는 게 아니라 색 전체가 고르게 도는 느낌이 나도록.
              gradient: SweepGradient(
                colors: [
                  ...widget.colors,
                  ...widget.colors,
                  widget.colors.first,
                ],
                transform: GradientRotation(_controller!.value * 6.283185307179586),
              ),
            ),
            padding: EdgeInsets.all(widget.borderWidth),
            child: inner,
          );
        },
      ),
    );
  }
}

/// Full-width CTA button, themed with [theme]'s gradient and a matching
/// glow when [theme.vivid] (lifetime). Used for both the paywall CTA and
/// the existing-subscriber "Upgrade to Lifetime" button.
class _GradientGlowButton extends StatelessWidget {
  final _PlanTheme theme;
  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onTap;

  const _GradientGlowButton({
    required this.theme,
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: (enabled && theme.vivid)
            ? [
          BoxShadow(
              color: theme.colors[0].withOpacity(0.4),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 5)),
          BoxShadow(
              color: theme.colors.last.withOpacity(0.3),
              blurRadius: 22,
              offset: const Offset(0, 7)),
        ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled ? theme.gradient : null,
              color: enabled ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}