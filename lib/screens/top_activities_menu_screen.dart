import 'package:flutter/material.dart';
import 'package:jidoapp/screens/top_paintings_screen.dart';
import 'package:jidoapp/screens/disneyland_screen.dart';
import 'package:jidoapp/screens/universal_studios_screen.dart';
import 'package:jidoapp/screens/champions_league_teams_screen.dart';
import 'package:jidoapp/screens/film_festivals_screen.dart';
import 'package:jidoapp/screens/top_orchestras_screen.dart';

class TopActivitiesMenuScreen extends StatelessWidget {
  const TopActivitiesMenuScreen({super.key});

  static const List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Best Paintings',
      'subtitle': 'Top 20 masterpieces',
      'icon': Icons.palette_outlined,
      'accent': Color(0xFFC06C84),
      'light': Color(0xFFFBE8F1),
    },
    {
      'title': 'Film Festivals',
      'subtitle': 'The Big Five',
      'icon': Icons.local_movies_outlined,
      'accent': Color(0xFF764BA2),
      'light': Color(0xFFF0EBF8),
    },
    {
      'title': 'Disneyland',
      'subtitle': 'Magical parks worldwide',
      'icon': Icons.castle_outlined,
      'accent': Color(0xFFf5576c),
      'light': Color(0xFFFEEBED),
    },
    {
      'title': 'Universal Studios',
      'subtitle': 'Theme parks worldwide',
      'icon': Icons.movie_filter_outlined,
      'accent': Color(0xFF4facfe),
      'light': Color(0xFFE8F4FF),
    },
    {
      'title': 'Champions League',
      'subtitle': '14 iconic stadiums',
      'icon': Icons.emoji_events_outlined,
      'accent': Color(0xFFE8854A),
      'light': Color(0xFFFEF0E8),
    },
    {
      'title': 'Best Orchestras',
      'subtitle': 'Top 15 concert halls',
      'icon': Icons.music_note_outlined,
      'accent': Color(0xFF6B4EFF),
      'light': Color(0xFFEDEBFF),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top Activities',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: Color(0xFF111827), letterSpacing: -0.6, height: 1.1)),
                      Text('Explore the best experiences',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ─────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _menuItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item   = _menuItems[index];
                  final title  = item['title'] as String;
                  final sub    = item['subtitle'] as String;
                  final icon   = item['icon'] as IconData;
                  final accent = item['accent'] as Color;
                  final light  = item['light'] as Color;

                  return GestureDetector(
                    onTap: () => _navigate(context, title),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        // 아이콘 — 액자형
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: light,
                            border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827), letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(sub,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        ])),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String title) {
    Widget screen;
    switch (title) {
      case 'Best Paintings':
        screen = const TopPaintingsScreen(); break;
      case 'Film Festivals':
        screen = const FilmFestivalsScreen(); break;
      case 'Disneyland':
        screen = const DisneylandScreen(); break;
      case 'Universal Studios':
        screen = const UniversalStudiosScreen(); break;
      case 'Champions League':
        screen = const ChampionsLeagueTeamsScreen(); break;
      case 'Best Orchestras':
        screen = const TopOrchestrasScreen(); break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}