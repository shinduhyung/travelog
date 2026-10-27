import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/widgets/city_travel_modal.dart';
import 'package:provider/provider.dart';

/// 메인 화면의 "Your next adventure" 검색 카드.
/// 도시나 나라 이름을 치면 도시 목록이 나오고, 누르면 도시별 여행 화면(city_travel_modal)이 열린다.
class NextAdventureCard extends StatefulWidget {
  const NextAdventureCard({super.key});

  @override
  State<NextAdventureCard> createState() => _NextAdventureCardState();
}

class _NextAdventureCardState extends State<NextAdventureCard> {
  static const _navy = Color(0xFF1E1B6B);
  static const _cyan = Color(0xFF00C2E8);

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Set<String> _withPage = const {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  /// 여행 가이드 페이지가 만들어진 도시는 검색 결과에서 먼저 보여준다.
  Future<void> _loadPages() async {
    try {
      final str = await rootBundle.loadString('assets/city_trip_pages.json');
      final names = (json.decode(str) as Map).keys.map((e) => e.toString()).toSet();
      if (mounted) setState(() => _withPage = names);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<City> _results(List<City> all) {
    final q = _query.trim().toLowerCase();
    if (q.length < 2) return const [];
    int score(City c) {
      final name = c.name.toLowerCase();
      final country = c.country.toLowerCase();
      var s = 0;
      if (name == q) {
        s = 4;
      } else if (name.startsWith(q)) {
        s = 3;
      } else if (name.contains(q)) {
        s = 2;
      } else if (country.startsWith(q) || country.contains(q)) {
        s = 1;
      }
      return s;
    }

    final hits = <(City, int)>[];
    for (final c in all) {
      final s = score(c);
      if (s > 0) hits.add((c, s));
    }
    hits.sort((a, b) {
      if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
      final pa = _withPage.contains(a.$1.name) ? 1 : 0;
      final pb = _withPage.contains(b.$1.name) ? 1 : 0;
      if (pa != pb) return pb.compareTo(pa);
      return b.$1.population.compareTo(a.$1.population);
    });
    return [for (final h in hits.take(6)) h.$1];
  }

  void _open(City city) {
    _focus.unfocus();
    showCityTravelModal(context, city);
  }

  static String _flag(String iso2) {
    if (iso2.length != 2) return '';
    final a = iso2.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = iso2.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([a, b]);
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<CityProvider>().allCities;
    final results = _results(all);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F6FF), Color(0xFFF4EEFF), Color(0xFFFFEAF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFFEC4899)]).createShader(r),
                child: const Icon(Icons.auto_awesome, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(tr('Your next adventure'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _navy, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 14, right: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: (_) {
                      if (results.isNotEmpty) _open(results.first);
                    },
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: tr('Search a country or city'),
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: results.isEmpty ? () => _focus.requestFocus() : () => _open(results.first),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: _cyan, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: results.isEmpty
                ? (_query.trim().length >= 2
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, left: 4),
                        child: Text(tr('No matching city'), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      )
                    : const SizedBox(width: double.infinity))
                : Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        for (var i = 0; i < results.length; i++) ...[
                          if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.shade100),
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _open(results[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Text(_flag(results[i].countryIsoA2), style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${results[i].name}, ${results[i].country}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                    ),
                                  ),
                                  if (_withPage.contains(results[i].name))
                                    const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFEC4899)),
                                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _tag(tr('Essentials'), const Color(0xFF4F46E5), const Color(0xFF38BDF8)),
                _tag(tr('Day trips'), const Color(0xFF4F46E5), const Color(0xFF38BDF8)),
                _tag(tr('Plans'), const Color(0xFFDB2777), const Color(0xFFEC4899)),
                _tag(tr('Tours'), const Color(0xFF0E9AA7), const Color(0xFFF59E0B)),
                _tag(tr('Hotels'), const Color(0xFF4F46E5), const Color(0xFF14B8A6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color textColor, Color dot) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      );
}
