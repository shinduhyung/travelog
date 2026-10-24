// lib/widgets/my_hub_board.dart
//
// My Trips 아래쪽의 My Hub: 자주 쓰는 메뉴 7개 + 개발자에게 연락하기를 4×2 바로가기로 보여준다.
// 아이콘과 색은 예전 My Trips 메뉴와 같다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/auth_provider.dart' as custom_auth;
import 'package:jidoapp/screens/calendar_screen.dart';
import 'package:jidoapp/screens/favorites_screen.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/screens/passport_screen.dart';
import 'package:jidoapp/screens/recommendations_screen.dart';
import 'package:jidoapp/screens/settings_screen.dart';
import 'package:jidoapp/screens/trip_log_list_screen.dart';
import 'package:jidoapp/screens/visa_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const String contactEmail = 'contact@travelogapp.uk';

const Color _darkMint = Color(0xFF009688);
const Color _ink = Color(0xFF1F2937);

class MyHubItem {
  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  /// 로그인해야 열리는 화면인지 (설정만 아니다)
  final bool needsLogin;

  const MyHubItem(this.title, this.icon, this.color, this.builder, {this.needsLogin = true});
}

final List<MyHubItem> myHubItems = [
  MyHubItem('Trip Log', Icons.auto_stories_rounded, const Color(0xFFF97316), (_) => const TripLogListScreen()),
  MyHubItem('Discover', Icons.search_rounded, const Color(0xFF2563EB), (_) => const RecommendationsScreen()),
  MyHubItem('Favorites', Icons.favorite_rounded, const Color(0xFFEC4899), (_) => const FavoritesScreen()),
  MyHubItem('Calendar', Icons.calendar_month_rounded, const Color(0xFFEF4444), (_) => const CalendarScreen()),
  MyHubItem('Passport', Icons.book_rounded, const Color(0xFF8B5CF6), (_) => const PassportScreen()),
  MyHubItem('Visa', Icons.article_rounded, const Color(0xFF00CDB5), (_) => const VisaScreen()),
  MyHubItem('Settings', Icons.settings_outlined, const Color(0xFF616161), (_) => const SettingsScreen(),
      needsLogin: false),
];

/// 메뉴 하나를 연다 (설정 외에는 로그인 필요)
Future<void> openMyHubItem(BuildContext context, MyHubItem item) async {
  if (item.needsLogin && Provider.of<custom_auth.AuthProvider>(context, listen: false).user == null) {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LoginPromptScreen(),
    );
    if (!context.mounted) return;
    if (Provider.of<custom_auth.AuthProvider>(context, listen: false).user == null) return;
  }
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: item.builder));
}

class MyHubBoard extends StatelessWidget {
  const MyHubBoard({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final tiles = <Widget>[
      for (final item in myHubItems)
        _ShortcutTile(
          icon: item.icon,
          color: item.color,
          label: tr(item.title),
          onTap: () => openMyHubItem(context, item),
        ),
      _ShortcutTile(
        icon: Icons.mail_rounded,
        color: _darkMint,
        label: tr('Contact'),
        filled: true,
        onTap: () => showContactSheet(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 기존 My Trips 섹션 제목과 같은 형식
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(color: _darkMint, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              tr('My Hub'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < 4; col++) Expanded(child: tiles[row * 4 + col]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: filled ? null : color.withOpacity(0.11),
              gradient: filled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2BC4B4), Color(0xFF009688)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: filled ? Colors.white : color, size: 23),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 개발자에게 연락하기 ────────────────────────────────────────────────────

/// 메일 앱을 연다. 받는 사람과 제목, 본문 틀을 채워 둔다. 메일 앱이 없으면 false.
Future<bool> openContactEmail() {
  final platform = Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : Platform.operatingSystem);
  final uri = Uri(
    scheme: 'mailto',
    path: contactEmail,
    // mailto는 +를 공백으로 바꾸지 않아서 queryParameters 대신 직접 인코딩한다
    query: 'subject=${Uri.encodeComponent('Travelog feedback')}'
        '&body=${Uri.encodeComponent('Hi Travelog team,\n\n\n\n---\nPlatform: $platform')}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
}

Future<void> showContactSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => const _ContactSheet(),
  );
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet();

  Future<void> _copy(BuildContext context, {String? message}) async {
    await Clipboard.setData(const ClipboardData(text: contactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(message ?? 'Email address copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return SafeArea(
      // 작은 화면/큰 글씨에서는 스크롤된다
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 22),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2BC4B4), Color(0xFF009688)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.mail_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Contact us'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Found a bug, have an idea, or want a new feature? '
                  'Anything is welcome. We read every message.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEFAF8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                contactEmail,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _darkMint),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () async {
                  final opened = await openContactEmail();
                  if (!context.mounted) return;
                  if (opened) {
                    Navigator.pop(context);
                  } else {
                    // 메일 앱이 없으면 주소라도 복사해 둔다
                    await _copy(context, message: 'No email app found. Address copied.');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _darkMint,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.send_rounded, size: 19),
                label: Text(tr('Send email')),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _copy(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              child: Text(tr('Copy address')),
            ),
          ],
        ),
      ),
    );
  }
}
