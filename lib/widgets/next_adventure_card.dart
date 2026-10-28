import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:jidoapp/widgets/city_travel_modal.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:provider/provider.dart';

const _cyan = Color(0xFF00C2E8);
const _ink = Color(0xFF111827);
const _pink = Color(0xFFEC4899);

String _flag(String iso2) {
  if (iso2.length != 2) return '';
  final a = iso2.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = iso2.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([a, b]);
}

String _snake(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"[''`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '_');

/// 도시 상세 화면(city_detail_modal)의 대표 사진과 같은 사진을 쓴다.
String _photoUrl(String name) {
  final file = name == 'San José' ? 'san_jose_cr' : _snake(name);
  return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/ranked_cities%2F$file.jpg.jpg?alt=media';
}

String _landmarkUrl(String name) =>
    'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/countrydex%2F${_snake(name)}.jpg?alt=media';

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
  'ł': 'l', 'ń': 'n', 'ñ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ß': 'ss',
  'ť': 't', 'ţ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// 소문자 + 악센트 제거 (Zürich == zurich)
String _norm(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().trim();
}

/// 검색 결과 하나를 눌렀을 때 호출 쪽으로 돌려주는 값
class _Pick {
  const _Pick.city(City this.city)
      : landmark = null,
        country = null;
  const _Pick.landmark(Landmark this.landmark)
      : city = null,
        country = null;
  const _Pick.country(Country this.country)
      : city = null,
        landmark = null;

  final City? city;
  final Landmark? landmark;
  final Country? country;
}

/// 메인 화면의 "Your next adventure" 카드.
/// 검색창을 누르면 검색 모달이 열리고, 결과에 맞는 화면(도시 여행 가이드, 랜드마크, 나라)으로 이어진다.
class NextAdventureCard extends StatelessWidget {
  const NextAdventureCard({super.key});

  Future<void> _openSearch(BuildContext context) async {
    final pick = await showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CityProvider>.value(value: context.read<CityProvider>()),
          ChangeNotifierProvider<CountryProvider>.value(value: context.read<CountryProvider>()),
          ChangeNotifierProvider<LandmarksProvider>.value(value: context.read<LandmarksProvider>()),
        ],
        child: const _SearchSheet(),
      ),
    );
    if (pick == null || !context.mounted) return;
    if (pick.city != null) {
      showCityTravelModal(context, pick.city!);
    } else if (pick.country != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CountryDetailScreen(country: pick.country!)));
    } else if (pick.landmark != null) {
      _showLandmarkSheet(context, pick.landmark!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openSearch(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: RichText(
                maxLines: 1,
                text: const TextSpan(
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                  children: [
                    TextSpan(text: 'Next ', style: TextStyle(color: Color(0xFF111827))),
                    TextSpan(text: 'Adventure', style: TextStyle(color: Color(0xFF0AA4C8))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 56,
              padding: const EdgeInsets.only(left: 16, right: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Row(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Paris', style: TextStyle(color: Colors.grey.shade500, fontSize: 17, fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: _cyan, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_right_alt_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 한 줄에 다 들어가도록, 좁은 화면에서는 통째로 줄어든다
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tag('🚌', 'Day trips'),
                    const SizedBox(width: 16),
                    _tag('🗓️', 'Plans'),
                    const SizedBox(width: 16),
                    _tag('🏨', 'Hotels'),
                    const SizedBox(width: 16),
                    _tag('🎁', 'Souvenirs'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tag(String emoji, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(text, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
        ],
      );
}

/// 랜드마크 모달: 소개와 하이라이트, 그 도시의 여행 가이드로 가는 버튼.
void _showLandmarkSheet(BuildContext context, Landmark lm) {
  final cities = context.read<CityProvider>().allCities;
  final countries = context.read<CountryProvider>().allCountries;
  final iso3 = lm.countriesIsoA3.isEmpty ? null : lm.countriesIsoA3.first;
  Country? country;
  for (final c in countries) {
    if (c.isoA3 == iso3) country = c;
  }
  City? city;
  for (final c in cities) {
    if (c.name == lm.city && (country == null || c.countryIsoA2.toUpperCase() == country.isoA2.toUpperCase())) {
      if (city == null || c.population > city.population) city = c;
    }
  }
  final color = country?.themeColor ?? const Color(0xFF1ABFBC);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
                  imageUrl: _landmarkUrl(lm.name),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                  errorWidget: (_, __, ___) => Container(color: color.withOpacity(0.12), child: Icon(Icons.account_balance_rounded, size: 48, color: color)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(lm.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 4),
            Text('${country == null ? '' : '${_flag(country.isoA2)} '}${lm.city}${country == null ? '' : ', ${country.name}'}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            LandmarkInfoCard(overview: lm.overview, historySignificance: lm.history_significance, highlights: lm.highlights, themeColor: color),
            if (city != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _cyan, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showCityTravelModal(context, city!);
                  },
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text('${city.name} ${tr('Plans')}'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 도시 여행 가이드(city prep)가 있는 도시의 검색 키워드: 도시명, 나라, 주변 도시, 랜드마크.
class _GuideEntry {
  _GuideEntry(this.name, Map raw)
      : cityTerms = [for (final t in (raw['city'] as List? ?? const [])) _norm('$t')],
        countryTerms = [for (final t in (raw['country'] as List? ?? const [])) _norm('$t')],
        nearbyTerms = [for (final t in (raw['nearby_towns'] as List? ?? const [])) _norm('$t')],
        landmarks = {
          for (final e in ((raw['landmarks'] as Map?) ?? const {}).entries) '${e.key}': [for (final t in (e.value as List)) _norm('$t')],
        };

  final String name;
  final List<String> cityTerms;
  final List<String> countryTerms;
  final List<String> nearbyTerms;
  final Map<String, List<String>> landmarks;
}

class _GuideHit {
  const _GuideHit(this.city, this.score, this.note);

  final City city;
  final int score;
  final String? note;
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();
  List<_GuideEntry> _guides = const [];
  Set<String> _withPhoto = const {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<Map> _readJson(String path) async {
    try {
      return json.decode(await rootBundle.loadString(path)) as Map;
    } catch (_) {
      return const {};
    }
  }

  /// 파일 하나가 없어도 나머지는 동작하도록 따로 읽는다.
  Future<void> _loadAssets() async {
    final kw = await _readJson('assets/city_search_keywords.json');
    final pages = await _readJson('assets/city_trip_pages.json');
    final ranked = await _readJson('assets/city_rank.json');
    final entries = <_GuideEntry>[
      for (final name in pages.keys)
        _GuideEntry('$name', kw['$name'] is Map ? kw['$name'] as Map : const {}),
    ];
    if (!mounted) return;
    setState(() {
      _guides = entries;
      _withPhoto = ranked.keys.map((e) => e.toString()).toSet();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_GuideHit> _guideHits(String q, Map<String, City> byName) {
    final out = <_GuideHit>[];
    for (final g in _guides) {
      final city = byName[g.name];
      if (city == null) continue;
      var score = 0;
      String? note;
      void best(int s, [String? n]) {
        if (s > score) {
          score = s;
          note = n;
        }
      }

      final name = _norm(g.name);
      if (name == q) {
        best(100);
      } else if (name.startsWith(q)) {
        best(90);
      } else if (g.cityTerms.any((t) => t == q)) {
        best(85);
      } else if (q.length >= 3 && g.cityTerms.any((t) => t.startsWith(q))) {
        best(80);
      }
      if (q.length >= 2 && g.countryTerms.any((t) => t == q || (q.length >= 3 && t.startsWith(q)))) best(70);
      for (final e in g.landmarks.entries) {
        final ln = _norm(e.key);
        if (ln == q || e.value.any((t) => t == q)) {
          best(66, e.key);
        } else if (q.length >= 3 && (ln.startsWith(q) || e.value.any((t) => t.startsWith(q)))) {
          best(62, e.key);
        } else if (q.length >= 4 && ln.contains(q)) {
          best(55, e.key);
        }
      }
      if (q.length >= 3 && g.nearbyTerms.any((t) => t == q || t.startsWith(q))) best(50, 'nearby');
      if (q.length >= 3 && name.contains(q)) best(45);
      if (score > 0) out.add(_GuideHit(city, score, note));
    }
    out.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      return b.city.population.compareTo(a.city.population);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cities = context.watch<CityProvider>().allCities;
    final countries = context.watch<CountryProvider>().allCountries;
    final landmarks = context.watch<LandmarksProvider>().allLandmarks;
    final q = _norm(_query);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final byName = <String, City>{};
    for (final c in cities) {
      final cur = byName[c.name];
      if (cur == null || c.population > cur.population) byName[c.name] = c;
    }

    final sections = <Widget>[];
    if (q.isEmpty) {
      final popular = <City>[
        for (final g in _guides)
          if (byName[g.name] != null) byName[g.name]!,
      ]..sort((a, b) => b.population.compareTo(a.population));
      sections.addAll(_section('City guides', [for (final c in popular.take(14)) _cityRow(c, guide: true)]));
    } else {
      final guideHits = _guideHits(q, byName);
      final guideNames = {for (final h in guideHits) h.city.name};
      sections.addAll(_section('City guides', [for (final h in guideHits.take(12)) _cityRow(h.city, guide: true, note: h.note)]));

      // 검색어와 맞는 나라 (이름이 검색어로 시작/포함)
      final matchedCountries = [
        for (final c in countries)
          if (_norm(c.name).startsWith(q) || (q.length >= 3 && _norm(c.name).contains(q))) c,
      ]..sort((a, b) {
          final sa = _norm(a.name).startsWith(q) ? 0 : 1;
          final sb = _norm(b.name).startsWith(q) ? 0 : 1;
          return sa != sb ? sa.compareTo(sb) : b.populationEst.compareTo(a.populationEst);
        });
      final countryIso2 = {for (final c in matchedCountries.take(3)) c.isoA2.toUpperCase()};
      final countryIso3 = {for (final c in matchedCountries.take(3)) c.isoA3};

      // 그 밖의 도시: 이름이 맞거나, 맞는 나라의 도시
      final otherCities = <(City, int)>[];
      if (q.length >= 2) {
        for (final c in cities) {
          if (guideNames.contains(c.name)) continue;
          final n = _norm(c.name);
          var s = 0;
          if (n == q) {
            s = 3;
          } else if (n.startsWith(q)) {
            s = 2;
          } else if (q.length >= 3 && n.contains(q)) {
            s = 1;
          } else if (countryIso2.contains(c.countryIsoA2.toUpperCase())) {
            s = 0;
          } else {
            continue;
          }
          otherCities.add((c, s));
        }
        otherCities.sort((a, b) {
          if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
          return b.$1.population.compareTo(a.$1.population);
        });
      }
      sections.addAll(_section('Cities', [for (final e in otherCities.take(8)) _cityRow(e.$1)]));

      // 랜드마크: 이름이 맞거나, 맞는 나라의 랜드마크
      final lms = <(Landmark, int)>[];
      if (q.length >= 2) {
        for (final l in landmarks) {
          final n = _norm(l.name);
          var s = 0;
          if (n.startsWith(q)) {
            s = 3;
          } else if (q.length >= 3 && n.contains(q)) {
            s = 2;
          } else if (l.countriesIsoA3.any(countryIso3.contains)) {
            s = 1;
          } else {
            continue;
          }
          lms.add((l, s));
        }
        lms.sort((a, b) {
          if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
          return b.$1.popularity.compareTo(a.$1.popularity);
        });
      }
      sections.addAll(_section('Landmarks', [for (final e in lms.take(8)) _landmarkRow(e.$1, countries)]));

      sections.addAll(_section('Countries', [for (final c in matchedCountries.take(3)) _countryRow(c)]));
    }

    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F8), borderRadius: BorderRadius.circular(26)),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: tr('Search a country or city'),
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.cancel_rounded, color: Colors.grey.shade400, size: 20),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: sections.isEmpty
                  ? Center(child: Text(tr('No matching city'), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      children: sections,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<Widget> rows) {
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.3)),
            const SizedBox(width: 6),
            Text('${rows.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
          ],
        ),
      ),
      ...rows,
    ];
  }

  Widget _thumb({String? url, required Widget fallback}) {
    final box = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
      child: fallback,
    );
    if (url == null) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 52, height: 52, color: const Color(0xFFF1F5F9)),
        errorWidget: (_, __, ___) => box,
      ),
    );
  }

  Widget _row({required Widget thumb, required String title, required String sub, required VoidCallback onTap, bool guide = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (guide) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.auto_awesome, size: 15, color: _pink)),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _cityRow(City c, {bool guide = false, String? note}) {
    final flag = _flag(c.countryIsoA2);
    final extra = note == null ? '' : (note == 'nearby' ? ' · nearby' : ' · $note');
    return _row(
      thumb: _thumb(
        url: _withPhoto.contains(c.name) ? _photoUrl(c.name) : null,
        fallback: Text(flag, style: const TextStyle(fontSize: 24)),
      ),
      title: c.name,
      sub: '$flag ${c.country}$extra',
      guide: guide,
      onTap: () => Navigator.pop(context, _Pick.city(c)),
    );
  }

  Widget _landmarkRow(Landmark l, List<Country> countries) {
    final iso3 = l.countriesIsoA3.isEmpty ? null : l.countriesIsoA3.first;
    Country? country;
    for (final c in countries) {
      if (c.isoA3 == iso3) country = c;
    }
    return _row(
      thumb: _thumb(url: _landmarkUrl(l.name), fallback: const Icon(Icons.account_balance_rounded, color: Color(0xFF94A3B8))),
      title: l.name,
      sub: '${country == null ? '' : '${_flag(country.isoA2)} '}${l.city}${country == null ? '' : ', ${country.name}'}',
      onTap: () => Navigator.pop(context, _Pick.landmark(l)),
    );
  }

  Widget _countryRow(Country c) {
    return _row(
      thumb: _thumb(fallback: Text(_flag(c.isoA2), style: const TextStyle(fontSize: 26))),
      title: c.name,
      sub: c.continent ?? '',
      onTap: () => Navigator.pop(context, _Pick.country(c)),
    );
  }
}
