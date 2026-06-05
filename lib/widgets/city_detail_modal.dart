// lib/widgets/city_detail_modal.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_info_provider.dart';
import 'package:jidoapp/providers/city_info_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Attribute category sets
// ─────────────────────────────────────────────────────────────────────────────
const Set<String> _naturalAttributes = {
  'Mountain','Volcano','Desert','River','Lake','Sea','Beach',
  'Waterfall','Falls','Cave','Island','Unique Landscape','Glacier',
  'Canyon','Geothermal','Jungle',
};
const Set<String> _activityAttributes = {
  'Painting','Artwork','Library','Bookstore','Filming Location',
  'Theater','Performing Art','Food','Restaurant','Brewery','Winery',
  'Cafe','Fast Food','Festival','Event','Amusement Park',
  'Football Stadium','Zoo','Aquarium','Cruise Tour','Cable Car',
};
String _categoryOf(Landmark l) {
  final first = l.attributes.isNotEmpty ? l.attributes.first : '';
  if (_naturalAttributes.contains(first)) return 'Natural';
  if (_activityAttributes.contains(first)) return 'Activities';
  return 'Cultural';
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry points
// ─────────────────────────────────────────────────────────────────────────────
void showCityDetailModal(BuildContext context, City city) {
  final countryProvider = context.read<CountryProvider>();
  final country = countryProvider.allCountries
      .firstWhereOrNull((c) => c.isoA2.toUpperCase() == city.countryIsoA2.toUpperCase());
  final themeColor = country?.themeColor ?? const Color(0xFF1ABFBC);
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, sc) => _CityDetailSheet(
          city: city, themeColor: themeColor,
          countryIsoA3: country?.isoA3, scrollController: sc),
    ),
  );
}
void showExternalCityDetailsModal(BuildContext context, City city) =>
    showCityDetailModal(context, city);

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CityDetailSheet extends StatefulWidget {
  final City city;
  final Color themeColor;
  final String? countryIsoA3;
  final ScrollController scrollController;
  const _CityDetailSheet({required this.city, required this.themeColor,
    required this.countryIsoA3, required this.scrollController});
  @override
  State<_CityDetailSheet> createState() => _CityDetailSheetState();
}

class _CityDetailSheetState extends State<_CityDetailSheet> {
  City get city => widget.city;
  Color get themeColor => widget.themeColor;
  String? get countryIsoA3 => widget.countryIsoA3;
  ScrollController get scrollController => widget.scrollController;

  // city_rank.json 캐시 (static → 앱 전체 공유, 한 번만 로딩)
  static Map<String, List<String>>? _cityRankCache;
  List<String>? _cityRankedNames;

  @override
  void initState() {
    super.initState();
    _loadCityRank();
  }

  Future<void> _loadCityRank() async {
    if (_cityRankCache == null) {
      try {
        final raw = await rootBundle.loadString('assets/city_rank.json');
        final decoded = json.decode(raw) as Map<String, dynamic>;
        _cityRankCache = decoded.map((k, v) => MapEntry(k, List<String>.from(v as List)));
      } catch (_) {
        _cityRankCache = {};
      }
    }
    if (mounted) {
      setState(() {
        _cityRankedNames = _cityRankCache![city.name];
      });
    }
  }

  String _toSnake(String s) {
    String r = s.toLowerCase();
    r = r.replaceAll(RegExp(r"[''`]"), '');
    r = r.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return r.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  String get _heroUrl {
    // 예외: San José (코스타리카) vs San Jose (미국)
    String filename;
    if (city.name == 'San José') {
      filename = 'san_jose_cr';
    } else {
      filename = _toSnake(city.name);
    }
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/ranked_cities%2F$filename.jpg.jpg?alt=media';
  }
  String _lmUrl(String name) =>
      'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/countrydex%2F${_toSnake(name)}.jpg?alt=media';

  String _flag(String iso) {
    if (iso.length != 2) return '';
    final a = iso.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = iso.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  // ── badges ─────────────────────────────────────────────────────────────────
  Widget _safetyBadge(int level) {
    const labels = ['','Very Safe','Generally Safe','Use Caution','High Risk','Avoid'];
    const bg = [Colors.transparent,Color(0xFFE1F5EE),Color(0xFFFFF9C4),
      Color(0xFFFFF3CD),Color(0xFFFFE0CC),Color(0xFFFFDDDD)];
    const fg = [Colors.transparent,Color(0xFF0F6E56),Color(0xFF7B6100),
      Color(0xFF7B4500),Color(0xFF8B2500),Color(0xFF8B0000)];
    const icons = [Icons.shield,Icons.shield_outlined,Icons.shield_outlined,
      Icons.warning_amber_outlined,Icons.dangerous_outlined,Icons.dangerous_outlined];
    final i = level.clamp(0,5);
    return _pill(icon: icons[i], label: labels[i], bg: bg[i], fg: fg[i]);
  }

  Widget _costBadge(int level) {
    const labels = ['','\$ Very Cheap','\$\$ Affordable','\$\$\$ Moderate','\$\$\$\$ Expensive','\$\$\$\$\$ Very Expensive'];
    const bg = [Colors.transparent,Color(0xFFE1F5EE),Color(0xFFE6F1FB),
      Color(0xFFFFF9C4),Color(0xFFFFE0CC),Color(0xFFFFDDDD)];
    const fg = [Colors.transparent,Color(0xFF0F6E56),Color(0xFF185FA5),
      Color(0xFF7B6100),Color(0xFF8B2500),Color(0xFF8B0000)];
    final i = level.clamp(0,5);
    return _pill(icon: null, label: labels[i], bg: bg[i], fg: fg[i]);
  }

  Widget _pill({required IconData? icon, required String label, required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );

  // ── section header ─────────────────────────────────────────────────────────
  Widget _secHead(String title, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: themeColor.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, size: 18, color: themeColor), const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
    ]),
  );

  Widget _bullets(List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: items.map((t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 7), width: 5, height: 5,
            decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87))),
      ]),
    )).toList());
  }

  Widget _statBox(String label, String value, {bool highlight = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: highlight ? themeColor : Colors.black87),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );

  Widget _actionBtn({required IconData icon, required IconData iconActive,
    required String label, required bool isActive, required Color activeColor, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(isActive ? iconActive : icon, size: 24,
                color: isActive ? activeColor : Colors.grey.shade400),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10,
                color: isActive ? activeColor : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ]),
        ),
      );

  // ── highlight photo card ───────────────────────────────────────────────────
  Widget _hlCard(BuildContext context, Landmark lm, LandmarksProvider lp) {
    final isVisited = lp.visitedLandmarks.contains(lm.name);
    return GestureDetector(
      onTap: () => _showLmModal(context, lm, lp),
      child: Container(
        width: 130, margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0,4))]),
        child: Column(children: [
          Expanded(child: Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: CachedNetworkImage(imageUrl: _lmUrl(lm.name), fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity,
                    placeholder: (_, __) => Container(color: themeColor.withOpacity(0.12)),
                    errorWidget: (_, __, ___) => Container(color: themeColor.withOpacity(0.12),
                        child: Icon(Icons.landscape_outlined, color: themeColor.withOpacity(0.4), size: 32)))),
            if (isVisited) Positioned(top: 6, right: 6,
                child: Container(padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                    child: Icon(Icons.check_circle, color: themeColor, size: 16))),
          ])),
          Container(height: 48, width: double.infinity,
            decoration: BoxDecoration(
                color: isVisited ? themeColor : themeColor.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Align(alignment: Alignment.centerLeft,
                child: Text(lm.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.25,
                        color: themeColor.computeLuminance() > 0.35 ? Colors.black87 : Colors.white))),
          ),
        ]),
      ),
    );
  }

  // ── grouped landmark row — highlights: bold + themed ──────────────────────
  Widget _groupedRow(BuildContext context, Landmark lm, LandmarksProvider lp, {required bool isHighlight}) {
    final isVisited = lp.visitedLandmarks.contains(lm.name);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Expanded(child: Text(lm.name,
            style: TextStyle(fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight ? themeColor : Colors.black87),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        GestureDetector(
            onTap: () => _showLmModal(context, lm, lp),
            child: Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.menu_book_outlined, size: 17, color: Colors.grey.shade600))),
        GestureDetector(
            onTap: isVisited ? null : () { HapticFeedback.lightImpact(); lp.addVisitDate(lm.name); },
            child: Container(width: 32, height: 32,
                decoration: BoxDecoration(
                    color: isVisited ? themeColor.withOpacity(0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(isVisited ? Icons.check_rounded : Icons.add_rounded,
                    size: 17, color: isVisited ? themeColor : Colors.grey.shade500))),
      ]),
    );
  }

  // ── landmark detail modal ─────────────────────────────────────────────────
  void _showLmModal(BuildContext context, Landmark lm, LandmarksProvider provider) {
    final fresh = provider.allLandmarks.firstWhereOrNull((l) => l.name == lm.name) ?? lm;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
        builder: (_, sc) => StatefulBuilder(builder: (ctx, _) {
          final lp = ctx.watch<LandmarksProvider>();
          final freshL = lp.allLandmarks.firstWhereOrNull((l) => l.name == lm.name) ?? fresh;
          final isVisited = lp.visitedLandmarks.contains(freshL.name);
          return Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              Expanded(child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(freshL.name,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    // visited 표시만 — 탭 기능 없음
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: isVisited ? themeColor.withOpacity(0.12) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isVisited ? Icons.check_rounded : Icons.location_on_outlined,
                            size: 16, color: isVisited ? themeColor : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(isVisited ? 'Visited' : 'Not visited',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: isVisited ? themeColor : Colors.grey.shade500)),
                      ]),
                    ),
                  ]),

                  if (freshL.attributes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(freshL.attributes.take(2).join(' · '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                  if (freshL.overview != null && freshL.overview!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _lmSec('Overview', Icons.info_outline, freshL.overview!),
                  ],
                  if (freshL.history_significance != null && freshL.history_significance!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _lmSec('Historical Significance', Icons.account_balance_outlined, freshL.history_significance!),
                  ],
                  if (freshL.highlights != null && freshL.highlights!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _hlSec(freshL.highlights!),
                  ],

                  // visit history — add/delete here only
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Icon(Icons.history, size: 18, color: themeColor),
                      const SizedBox(width: 8),
                      Text('Visit history', style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Text('${freshL.visitDates.length}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700))),
                    ]),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      onPressed: () => _pickLmDate(ctx, freshL.name, lp),
                      style: OutlinedButton.styleFrom(foregroundColor: themeColor,
                          side: BorderSide(color: themeColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (freshL.visitDates.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('No visits recorded.', style: TextStyle(color: Colors.grey.shade500)))
                  else
                    ...freshL.visitDates.asMap().entries.map((e) =>
                        _LandmarkVisitTile(visitDate: e.value, index: e.key,
                            landmarkName: freshL.name, themeColor: themeColor)),
                ]),
              )),
            ]),
          );
        }),
      ),
    );
  }

  Future<void> _pickLmDate(BuildContext context, String name, LandmarksProvider lp) async {
    final picked = await showDatePicker(context: context,
        initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100),
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: themeColor)), child: child!));
    if (picked != null && context.mounted) lp.addVisitDate(name, date: picked);
  }

  Widget _lmSec(String title, IconData icon, String body) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, size: 16, color: themeColor), const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: themeColor))]),
    const SizedBox(height: 6),
    Text(body, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6)),
  ]);

  Widget _hlSec(String raw) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.star_outline, size: 16, color: themeColor), const SizedBox(width: 6),
        Text('Highlights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: themeColor))]),
      const SizedBox(height: 6),
      ...lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 6), width: 5, height: 5,
                decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(line, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5))),
          ]))),
    ]);
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CityProvider>();
    final countryProvider = context.watch<CountryProvider>();
    final lp = context.watch<LandmarksProvider>();
    final cip = context.watch<CountryInfoProvider>();
    final cityInfoProvider = context.watch<CityInfoProvider>();

    final cityInfo = cityInfoProvider.getByName(city.name);
    final hlNames = (cityInfo?.highlights ?? []).toSet();

    final detail = cp.getCityVisitDetail(city.name);
    final visitCount = detail?.visitCount ?? 0;
    final totalDays = detail?.totalDurationInDays() ?? 0;
    final isHomeCity = cp.homeCityName == city.name;
    final hasLived = detail?.hasLived ?? false;
    final isWishlisted = detail?.isWishlisted ?? false;
    final rating = detail?.rating ?? 0.0;

    final safetyLevel = countryIsoA3 != null
        ? (cip.countryInfoMap[countryIsoA3]?.safetyLevel ?? 0) : 0;

    final country = countryProvider.allCountries.firstWhereOrNull(
            (c) => c.isoA2.toUpperCase() == city.countryIsoA2.toUpperCase());

    final allLm = lp.allLandmarks.where((l) => l.city == city.name).toList()
      ..sort((a, b) {
        final ra = a.local_rank > 0 ? a.local_rank : 9999;
        final rb = b.local_rank > 0 ? b.local_rank : 9999;
        return ra.compareTo(rb);
      });

    List<Landmark> hlCards;
    if (_cityRankedNames != null && _cityRankedNames!.isNotEmpty) {
      // city_rank.json 순서 유지하며 매칭
      hlCards = _cityRankedNames!
          .map((n) => allLm.firstWhereOrNull((l) => l.name == n))
          .whereType<Landmark>().toList();
      if (hlCards.isEmpty) hlCards = allLm.take(5).toList();
    } else if (hlNames.isNotEmpty) {
      hlCards = (cityInfo!.highlights)
          .map((n) => allLm.firstWhereOrNull((l) => l.name == n))
          .whereType<Landmark>().toList();
      if (hlCards.isEmpty) hlCards = allLm.take(5).toList();
    } else {
      hlCards = allLm.take(5).toList();
    }

    final Map<String, List<Landmark>> byCategory = {};
    for (final l in allLm) byCategory.putIfAbsent(_categoryOf(l), () => []).add(l);

    Map<String, List<Landmark>> attrGroups(List<Landmark> items) {
      final Map<String, List<Landmark>> g = {};
      for (final l in items) {
        g.putIfAbsent(l.attributes.isNotEmpty ? l.attributes.first : 'Other', () => []).add(l);
      }
      return g;
    }
    const catOrder = ['Cultural','Natural','Activities'];

    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

          // ── hero 200px ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(imageUrl: _heroUrl, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: themeColor.withOpacity(0.08)),
                  errorWidget: (_, __, ___) => Container(color: themeColor.withOpacity(0.08),
                      child: Icon(Icons.location_city_rounded, size: 48, color: themeColor.withOpacity(0.3))))),

          Padding(
            padding: const EdgeInsets.fromLTRB(20,16,20,0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // title
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_flag(city.countryIsoA2), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Text(city.name,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87))),
                if (city.gawcTier.isNotEmpty && city.gawcTier != 'N/A')
                  Container(margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(20)),
                      child: Text(city.gawcTier, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF854F0B)))),
              ]),
              const SizedBox(height: 3),
              Text([city.country, if (country?.continent != null) country!.continent!].join(' · '),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),

              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (safetyLevel > 0) _safetyBadge(safetyLevel),
                if (cityInfo != null && cityInfo.costLevel > 0) _costBadge(cityInfo.costLevel),
              ]),

              const SizedBox(height: 14),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.6,
                children: [
                  _statBox('Population', cityInfo?.population ?? 'N/A'),
                  _statBox('Area', cityInfo?.areaKm2 != null
                      ? '${cityInfo!.areaKm2.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km²' : 'N/A'),
                  _statBox('GDP (metro)', cityInfo?.gdp ?? 'N/A'),
                  _statBox('Timezone', cityInfo?.timezone ?? 'N/A'),
                  _statBox('Capital', (cityInfo?.isCapital ?? false) ? 'Yes' : 'No', highlight: cityInfo?.isCapital ?? false),
                  _statBox('Largest city', (cityInfo?.isLargestCity ?? false) ? 'Yes' : 'No', highlight: cityInfo?.isLargestCity ?? false),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 4),

              // visit count
              Text(visitCount > 0
                  ? '$visitCount ${visitCount == 1 ? 'visit' : 'visits'} · $totalDays ${totalDays == 1 ? 'day' : 'days'}'
                  : 'Not visited yet',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 10),

              // action + rating
              Row(children: [
                Expanded(child: Row(children: [
                  _actionBtn(icon: Icons.home_outlined, iconActive: Icons.home_rounded,
                      label: 'Home', isActive: isHomeCity, activeColor: themeColor,
                      onTap: () => cp.setCityHomeStatus(city.name, !isHomeCity)),
                  _actionBtn(icon: Icons.apartment_outlined, iconActive: Icons.apartment_rounded,
                      label: 'Lived', isActive: hasLived, activeColor: themeColor,
                      onTap: () => cp.toggleCityLivedStatus(city.name)),
                  _actionBtn(icon: Icons.favorite_border, iconActive: Icons.favorite,
                      label: 'Favorite', isActive: isWishlisted, activeColor: Colors.red,
                      onTap: () => cp.toggleCityWishlistStatus(city.name)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200)),
                  child: Column(children: [
                    RatingBar.builder(initialRating: rating, minRating: 0, allowHalfRating: true,
                        itemCount: 5, itemSize: 20.0,
                        itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (r) => cp.setCityRating(city.name, r)),
                    const SizedBox(height: 4),
                    Text(rating > 0 ? rating.toStringAsFixed(1) : 'Rate',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),

              // ── Add Visit → addCityDateRange (즉시 생성, unknown) ─────────
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('History ($visitCount visits, $totalDays days)',
                    style: Theme.of(context).textTheme.titleSmall),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Visit'),
                  onPressed: () {
                    cp.addCityDateRange(city.name);
                    HapticFeedback.mediumImpact();
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor, side: BorderSide(color: themeColor)),
                ),
              ]),
              const SizedBox(height: 8),

              // visit record tiles
              if (detail != null && detail.visitDateRanges.isNotEmpty)
                ...detail.visitDateRanges.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dateRange = entry.value;
                  return _CityVisitDetailEditorSheet(
                    key: ValueKey('${city.name}_visit_$index'),
                    range: dateRange,
                    onSave: (updatedRange) => cp.updateCityDateRange(city.name, index, updatedRange),
                    onDelete: () => cp.removeCityDateRange(city.name, index),
                  );
                }).toList()
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No visits recorded.',
                        style: TextStyle(color: Colors.grey.shade500))),

              Divider(color: Colors.grey.shade100, height: 36),

              // info sections
              if (cityInfo != null && cityInfo.geography.isNotEmpty) ...[
                _secHead('Geography', Icons.terrain_outlined), const SizedBox(height: 8),
                _bullets(cityInfo.geography), const SizedBox(height: 16),
              ],
              if (cityInfo != null && cityInfo.history.isNotEmpty) ...[
                _secHead('City History', Icons.account_balance_outlined), const SizedBox(height: 8),
                _bullets(cityInfo.history), const SizedBox(height: 16),
              ],
              if (cityInfo != null && cityInfo.transportation.isNotEmpty) ...[
                _secHead('Transportation', Icons.directions_transit_outlined), const SizedBox(height: 8),
                _bullets(cityInfo.transportation), const SizedBox(height: 16),
              ],
              if (cityInfo != null && cityInfo.tips.isNotEmpty) ...[
                _secHead('Travel Tips', Icons.lightbulb_outline), const SizedBox(height: 8),
                _bullets(cityInfo.tips), const SizedBox(height: 16),
              ],
              if (cityInfo != null && cityInfo.tags.isNotEmpty) ...[
                _secHead('Tags', Icons.label_outline), const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8,
                    children: cityInfo.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Text(t, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)))).toList()),
                const SizedBox(height: 16),
              ],

              // landmarks
              if (allLm.isNotEmpty) ...[
                _secHead('Highlights in ${city.name}', Icons.emoji_events_outlined),
                const SizedBox(height: 12),
                SizedBox(height: 180,
                    child: ListView.builder(scrollDirection: Axis.horizontal, padding: EdgeInsets.zero,
                        itemCount: hlCards.length,
                        itemBuilder: (_, i) => _hlCard(context, hlCards[i], lp))),
                const SizedBox(height: 16),
                ...catOrder.where((cat) => byCategory.containsKey(cat)).expand((cat) {
                  final groups = attrGroups(byCategory[cat]!);
                  return [
                    Padding(padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700, letterSpacing: 0.3))),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: groups.entries.expand((entry) => [
                            if (groups.length > 1)
                              Padding(padding: const EdgeInsets.only(top: 10, bottom: 2),
                                  child: Text(entry.key, style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w600, color: themeColor, letterSpacing: 0.2))),
                            ...entry.value.map((l) => _groupedRow(context, l, lp, isHighlight: hlNames.contains(l.name))),
                          ]).toList()),
                    ),
                    const SizedBox(height: 10),
                  ];
                }),
              ],

              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CityVisitDetailEditorSheet — cities_screen.dart의 것과 동일
// ─────────────────────────────────────────────────────────────────────────────
class _CityVisitDetailEditorSheet extends StatefulWidget {
  final DateRange range;
  final ValueChanged<DateRange> onSave;
  final VoidCallback onDelete;
  const _CityVisitDetailEditorSheet({super.key, required this.range, required this.onSave, required this.onDelete});
  @override
  State<_CityVisitDetailEditorSheet> createState() => _CityVisitDetailEditorSheetState();
}

class _CityVisitDetailEditorSheetState extends State<_CityVisitDetailEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _durationController;
  late bool _isLayover;
  late bool _isTransfer;
  int? _arrivalYear, _arrivalMonth, _arrivalDay;
  int? _departureYear, _departureMonth, _departureDay;
  List<String> _currentPhotos = [];
  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.range.title);
    _memoController = TextEditingController(text: widget.range.memo);
    _isLayover = widget.range.isLayover;
    _isTransfer = widget.range.isTransfer;
    _currentPhotos = List.from(widget.range.photos);
    _arrivalYear = widget.range.arrival?.year;
    _arrivalMonth = widget.range.arrival?.month;
    _arrivalDay = widget.range.arrival?.day;
    _departureYear = widget.range.departure?.year;
    _departureMonth = widget.range.departure?.month;
    _departureDay = widget.range.departure?.day;
    if (widget.range.userDefinedDuration != null) {
      _durationController = TextEditingController(text: widget.range.userDefinedDuration.toString());
    } else {
      final calc = _calculateDuration();
      _durationController = TextEditingController(
          text: calc?.toString() ?? (widget.range.isDurationUnknown ? 'Unknown' : ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose(); _memoController.dispose(); _durationController.dispose(); super.dispose();
  }

  int? _calculateDuration() {
    if (_arrivalYear == null || _arrivalMonth == null || _arrivalDay == null ||
        _departureYear == null || _departureMonth == null || _departureDay == null) return null;
    final arr = DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!);
    final dep = DateTime(_departureYear!, _departureMonth!, _departureDay!);
    if (dep.isBefore(arr)) return null;
    return dep.difference(arr).inDays + 1;
  }

  void _handleSave() {
    final userDuration = int.tryParse(_durationController.text);
    if (_arrivalYear != null && _arrivalMonth != null && _arrivalDay != null &&
        _departureYear != null && _departureMonth != null && _departureDay != null) {
      final arr = DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!);
      final dep = DateTime(_departureYear!, _departureMonth!, _departureDay!);
      if (dep.isBefore(arr)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Departure date cannot be before arrival date.')));
        return;
      }
    }
    final isAllKnown = _arrivalYear != null && _arrivalMonth != null && _arrivalDay != null &&
        _departureYear != null && _departureMonth != null && _departureDay != null;
    final calc = isAllKnown ? _calculateDuration() : null;
    final finalDuration = userDuration ?? calc;
    final updated = widget.range.copyWith(
      title: _titleController.text, memo: _memoController.text,
      isLayover: _isLayover, isTransfer: _isTransfer,
      userDefinedDuration: finalDuration,
      isDurationUnknown: finalDuration == null || finalDuration <= 0,
      arrival: _arrivalYear != null && _arrivalMonth != null && _arrivalDay != null
          ? DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!) : null,
      departure: _departureYear != null && _departureMonth != null && _departureDay != null
          ? DateTime(_departureYear!, _departureMonth!, _departureDay!) : null,
      photos: _currentPhotos,
    );
    widget.onSave(updated);
    _expansionTileController.collapse();
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: source);
    if (f != null) setState(() => _currentPhotos.add(f.path));
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    final file = File(photoPath);
    return Stack(children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400)),
          child: file.existsSync()
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, fit: BoxFit.cover))
              : const Center(child: Icon(Icons.error_outline, color: Colors.red))),
      Positioned(top: -8, right: -8,
          child: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () => setState(() => _currentPhotos.removeAt(index)))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final int? calc = _calculateDuration();
    final int? finalDuration = widget.range.userDefinedDuration ?? calc;
    final String durationText = finalDuration?.toString() ?? (widget.range.isDurationUnknown ? 'Unknown' : '');

    if (widget.range.userDefinedDuration == null) {
      if (finalDuration != null && _durationController.text != finalDuration.toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _durationController.text = finalDuration.toString();
        });
      } else if (finalDuration == null && _durationController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _durationController.text = '';
        });
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      child: ExpansionTile(
        controller: _expansionTileController,
        title: Text(widget.range.title.isNotEmpty ? widget.range.title : 'Visit Record'),
        subtitle: Text(
          '${widget.range.arrival != null ? DateFormat('yyyy-MM-dd').format(widget.range.arrival!) : 'Unknown'}'
              ' - ${widget.range.departure != null ? DateFormat('yyyy-MM-dd').format(widget.range.departure!) : 'Unknown'}'
              ' (Duration: $durationText days)',
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: widget.onDelete),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  onChanged: (val) => widget.onSave(widget.range.copyWith(title: val))),
              const SizedBox(height: 12),
              TextField(controller: _memoController,
                  decoration: const InputDecoration(labelText: 'Memo', border: OutlineInputBorder()),
                  maxLines: 3,
                  onChanged: (val) => widget.onSave(widget.range.copyWith(memo: val))),
              const SizedBox(height: 16),
              const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                GestureDetector(
                  onTap: () => showModalBottomSheet(context: context,
                      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Library'),
                            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
                        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'),
                            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
                      ]))),
                  child: Container(width: 80, height: 80,
                      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Icon(Icons.add_a_photo, color: Colors.blue))),
                ),
                ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)),
              ]),
              const Divider(height: 24),
              _buildDateSection('Arrival', _arrivalYear, _arrivalMonth, _arrivalDay, (y, m, d) {
                setState(() {
                  _arrivalYear = y; _arrivalMonth = m; _arrivalDay = d;
                  widget.range.userDefinedDuration = null;
                  widget.onSave(widget.range.copyWith(
                      arrival: y != null && m != null && d != null ? DateTime(y, m, d) : null));
                });
              }),
              const SizedBox(height: 12),
              _buildDateSection('Departure', _departureYear, _departureMonth, _departureDay, (y, m, d) {
                setState(() {
                  _departureYear = y; _departureMonth = m; _departureDay = d;
                  widget.range.userDefinedDuration = null;
                  widget.onSave(widget.range.copyWith(
                      departure: y != null && m != null && d != null ? DateTime(y, m, d) : null));
                });
              }),
              const SizedBox(height: 12),
              TextField(controller: _durationController,
                  decoration: const InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) => widget.onSave(widget.range.copyWith(userDefinedDuration: int.tryParse(val)))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Transfer'),
                  Checkbox(value: _isTransfer, onChanged: (val) {
                    setState(() => _isTransfer = val ?? false);
                    widget.onSave(widget.range.copyWith(isTransfer: val ?? false));
                  }),
                ])),
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Layover'),
                  Checkbox(value: _isLayover, onChanged: (val) {
                    setState(() => _isLayover = val ?? false);
                    widget.onSave(widget.range.copyWith(isLayover: val ?? false));
                  }),
                ])),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: widget.onDelete,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Save'))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(String label, int? year, int? month, int? day,
      Function(int?, int?, int?) onChanged) {
    final years = [null, ...List.generate(80, (i) => DateTime.now().year - i)];
    final months = [null, ...List.generate(12, (i) => i + 1)];
    int daysInMonth = 31;
    if (year != null && month != null) {
      try { daysInMonth = DateUtils.getDaysInMonth(year, month); } catch (_) {}
    }
    final days = [null, ...List.generate(daysInMonth, (i) => i + 1)];
    final currentDay = (day != null && day <= daysInMonth) ? day : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _buildDropdown('Year', year, years, (val) => onChanged(val, month, currentDay))),
        const SizedBox(width: 8),
        Expanded(child: _buildDropdown('Month', month, months, (val) => onChanged(year, val, currentDay))),
        const SizedBox(width: 8),
        Expanded(child: _buildDropdown('Day', currentDay, days, (val) => onChanged(year, month, val))),
      ]),
    ]);
  }

  Widget _buildDropdown<T>(String hint, T? value, List<T> items, ValueChanged<T?> onChanged) =>
      DropdownButtonFormField<T>(
        value: value, isDense: true,
        decoration: InputDecoration(labelText: hint, border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
        items: items.map((item) => DropdownMenuItem<T>(value: item,
            child: Text(item?.toString() ?? 'Unknown',
                style: TextStyle(fontSize: item == null ? 11.0 : 15.0,
                    color: item == null ? Colors.grey.shade600 : null),
                overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Landmark visit tile
// ─────────────────────────────────────────────────────────────────────────────
class _LandmarkVisitTile extends StatefulWidget {
  final VisitDate visitDate;
  final int index;
  final String landmarkName;
  final Color themeColor;
  const _LandmarkVisitTile({required this.visitDate, required this.index,
    required this.landmarkName, required this.themeColor});
  @override
  State<_LandmarkVisitTile> createState() => _LandmarkVisitTileState();
}
class _LandmarkVisitTileState extends State<_LandmarkVisitTile> {
  bool _editing = false;
  late final TextEditingController _titleCtrl, _memoCtrl;
  late int? _year, _month, _day;
  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.visitDate.title);
    _memoCtrl = TextEditingController(text: widget.visitDate.memo ?? '');
    _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
    if (widget.visitDate.title.isEmpty && (widget.visitDate.memo ?? '').isEmpty) _editing = true;
  }
  @override
  void dispose() { _titleCtrl.dispose(); _memoCtrl.dispose(); super.dispose(); }
  String get _dateLabel {
    if (_year == null) return 'No date';
    final m = _month != null ? '.${_month.toString().padLeft(2,'0')}' : '';
    final d = _day != null ? '.${_day.toString().padLeft(2,'0')}' : '';
    return '$_year$m$d';
  }
  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context,
        initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
        firstDate: DateTime(1900), lastDate: DateTime(2100),
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: widget.themeColor)), child: child!));
    if (picked != null && mounted) setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
  }
  void _save() {
    context.read<LandmarksProvider>().updateLandmarkVisit(widget.landmarkName, widget.index,
        title: _titleCtrl.text, memo: _memoCtrl.text,
        year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999);
    setState(() => _editing = false);
  }
  @override
  Widget build(BuildContext context) {
    final tc = widget.themeColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: tc),
              const SizedBox(width: 8),
              Expanded(child: Text(_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Visit ${widget.index+1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text(_dateLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() => _editing = !_editing),
                  child: Icon(_editing ? Icons.keyboard_arrow_up : Icons.edit_outlined,
                      size: 18, color: Colors.grey.shade400)),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Delete visit?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () {
                        Navigator.pop(context);
                        context.read<LandmarksProvider>().removeVisitDate(widget.landmarkName, widget.index);
                      }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  )),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300)),
            ])),
        if (_editing) Container(
          padding: const EdgeInsets.fromLTRB(14,0,14,14),
          child: Column(children: [
            GestureDetector(onTap: _pickDate,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: Row(children: [
                      Icon(Icons.edit_calendar, size: 16, color: tc), const SizedBox(width: 8),
                      Text(_dateLabel, style: TextStyle(fontSize: 13,
                          color: _year != null ? Colors.black87 : Colors.grey)),
                      const Spacer(),
                      Text('Tap to change', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]))),
            const SizedBox(height: 8),
            TextField(controller: _titleCtrl,
                decoration: InputDecoration(labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            const SizedBox(height: 8),
            TextField(controller: _memoCtrl, maxLines: 2, minLines: 1,
                decoration: InputDecoration(labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: tc, foregroundColor: Colors.white,
                      elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  child: const Text('Save')),
            ]),
          ]),
        ),
      ]),
    );
  }
}