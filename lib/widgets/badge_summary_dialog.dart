import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/widgets/firebase_badge_image.dart';

// Shown instead of one popup per badge when many unlock at once.
// Pops true when the user taps "View Badges".
class BadgeSummaryDialog extends StatefulWidget {
  final List<Achievement> badges;

  const BadgeSummaryDialog({super.key, required this.badges});

  static const Color _mint = Color(0xFF3DDAD7);
  static const Color _mintDark = Color(0xFF14B8A6);
  static const int _perPage = 8; // 4 x 2 per page, swipe for more

  static Future<bool?> show(BuildContext context, List<Achievement> badges) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => BadgeSummaryDialog(badges: List.of(badges)),
    );
  }

  @override
  State<BadgeSummaryDialog> createState() => _BadgeSummaryDialogState();
}

class _BadgeSummaryDialogState extends State<BadgeSummaryDialog> {
  static const Color _mint = BadgeSummaryDialog._mint;
  static const Color _mintDark = BadgeSummaryDialog._mintDark;
  static const int _perPage = BadgeSummaryDialog._perPage;
  static const double _thumb = 56;
  static const double _gap = 10;

  int _page = 0;

  List<Achievement> get badges => widget.badges;
  int get _pageCount => (badges.length / _perPage).ceil();

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_mint, _mintDark],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${badges.length}',
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('New badges unlocked'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: SizedBox(
                // Every page is sized for two rows so swiping doesn't change the height.
                height: _thumb * 2 + _gap,
                child: PageView.builder(
                  itemCount: _pageCount,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, page) {
                    final pageBadges = badges.skip(page * _perPage).take(_perPage).toList();
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _thumb * 4 + _gap * 3,
                        child: Wrap(
                          spacing: _gap,
                          runSpacing: _gap,
                          children: [for (final b in pageBadges) _badgeThumb(b)],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_pageCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? _mintDark : _mint.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(tr('Close'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _mintDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(tr('View Badges'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeThumb(Achievement b) {
    return Container(
      width: _thumb,
      height: _thumb,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        border: Border.all(color: _mint.withValues(alpha: 0.6), width: 2),
      ),
      child: ClipOval(
        child: FirebaseBadgeImage(imagePath: b.imagePath, fit: BoxFit.cover, width: _thumb, height: _thumb),
      ),
    );
  }
}
