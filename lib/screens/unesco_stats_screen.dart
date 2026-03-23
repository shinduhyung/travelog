// lib/screens/unesco_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/visit_date_model.dart'; // [Fix] Undefined class VisitDate 해결
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/unesco_visit_editor_card.dart'; // [Update] 공통 위젯 적용

class CountryUnescoStats {
  final Country country;
  final int totalSites;
  final int visitedSites;
  final double visitedPercentage;

  CountryUnescoStats({
    required this.country,
    required this.totalSites,
    required this.visitedSites,
  }) : visitedPercentage = (totalSites > 0) ? (visitedSites / totalSites * 100) : 0.0;
}

class TypeStatData {
  final String name;
  final int visitedCount;
  final int totalCount;
  final double percentage;
  final Color color;

  TypeStatData({
    required this.name,
    required this.visitedCount,
    required this.totalCount,
    required this.color,
  }) : percentage = (totalCount > 0) ? (visitedCount / totalCount * 100) : 0.0;
}

class UnescoStatsScreen extends StatefulWidget {
  const UnescoStatsScreen({super.key});

  static final List<Map<String, Object>> continentsData = [
    {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': const Color(0xFFF48FB1)},
    {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': const Color(0xFFFFC107)},
    {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': const Color(0xFF795548)},
    {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': const Color(0xFF90CAF9)},
    {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': const Color(0xFF4CAF50)},
    {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': const Color(0xFF9C27B0)},
  ];

  @override
  State<UnescoStatsScreen> createState() => _UnescoStatsScreenState();
}

class _UnescoStatsScreenState extends State<UnescoStatsScreen> with TickerProviderStateMixin {
  String? _selectedContinent;
  final ScrollController _mainScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final unescoProvider = context.watch<UnescoProvider>();
    final countryProvider = context.watch<CountryProvider>();

    if (unescoProvider.isLoading || countryProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final visitedSitesSet = unescoProvider.visitedSites;
    final allSites = unescoProvider.allSites;
    final int totalSites = allSites.length;
    final int visitedSitesCount = allSites
        .where((s) => visitedSitesSet.contains(s.name) || unescoProvider.getVisitedSubLocationCount(s.name) > 0)
        .length;

    final List<CountryUnescoStats> statsList = _calculateCountryStats(
      sites: allSites,
      visitedSet: visitedSitesSet,
      provider: unescoProvider,
      countries: countryProvider.allCountries,
    );

    final typeStats = _calculateTypeStats(allSites, visitedSitesSet, unescoProvider);
    final visitedCountryNames = countryProvider.visitedCountries;
    final primaryColor = Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _mainScrollController,
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 80.0),
          child: Column(
            children: [
              _buildCreativeHeader(context: context, visited: visitedSitesCount, total: totalSites, color: primaryColor),
              const SizedBox(height: 24),

              _buildContinentNav(primaryColor),
              const SizedBox(height: 24),

              if (_selectedContinent != null) ...[
                _buildContinentDetailSection(
                  continentName: _selectedContinent!,
                  allSites: allSites,
                  unescoProvider: unescoProvider,
                  countryProvider: countryProvider,
                ),
                const SizedBox(height: 24),
              ],

              _UnescoRankingCard(key: const ValueKey('unesco_country_ranking'), countryStats: statsList, visitedCountryNames: visitedCountryNames),
              const SizedBox(height: 24),
              _SiteRankingCard(key: const ValueKey('unesco_site_ranking'), allSites: allSites),
              const SizedBox(height: 24),
              _TypeStatsCard(typeStats: typeStats, primaryColor: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  List<CountryUnescoStats> _calculateCountryStats({required List<UnescoSite> sites, required Set<String> visitedSet, required UnescoProvider provider, required List<Country> countries}) {
    final Map<String, int> totalByCountry = {};
    for (final site in sites) { for (final countryCode in site.countriesIsoA3) { totalByCountry[countryCode] = (totalByCountry[countryCode] ?? 0) + 1; } }
    final Map<String, int> visitedByCountry = {};
    for (final site in sites) {
      final isVisited = visitedSet.contains(site.name) || provider.getVisitedSubLocationCount(site.name) > 0;
      if (isVisited) { for (final countryCode in site.countriesIsoA3) { visitedByCountry[countryCode] = (visitedByCountry[countryCode] ?? 0) + 1; } }
    }
    final List<CountryUnescoStats> statsList = [];
    for (final country in countries) {
      final isoA3 = country.isoA3;
      final total = totalByCountry[isoA3] ?? 0;
      if (total > 0) { statsList.add(CountryUnescoStats(country: country, totalSites: total, visitedSites: visitedByCountry[isoA3] ?? 0)); }
    }
    return statsList;
  }

  List<TypeStatData> _calculateTypeStats(List<UnescoSite> allSites, Set<String> visitedSet, UnescoProvider provider) {
    int cultT = 0, cultV = 0, natT = 0, natV = 0, mixT = 0, mixV = 0;
    for (var site in allSites) {
      final isV = visitedSet.contains(site.name) || provider.getVisitedSubLocationCount(site.name) > 0;
      if (site.type == 'Cultural') { cultT++; if (isV) cultV++; }
      else if (site.type == 'Natural') { natT++; if (isV) natV++; }
      else if (site.type == 'Mixed') { mixT++; if (isV) mixV++; }
    }
    return [
      TypeStatData(name: 'Cultural', visitedCount: cultV, totalCount: cultT, color: Colors.orange),
      TypeStatData(name: 'Natural', visitedCount: natV, totalCount: natT, color: Colors.green),
      TypeStatData(name: 'Mixed', visitedCount: mixV, totalCount: mixT, color: Colors.teal),
    ];
  }

  // [Update] 모달 출력 로직 추가 (Continent 섹션에서 사용)
  void _showUnescoSiteDetailsModal(BuildContext context, UnescoSite site) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<UnescoProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();
        final freshSite = provider.allSites.firstWhere((l) => l.name == site.name);
        final isVisited = provider.visitedSites.contains(freshSite.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshSite.name);
        final totalSubCount = freshSite.locations.length;
        final isWishlisted = provider.wishlistedSites.contains(freshSite.name);

        final themeColor = (freshSite.type == 'Natural') ? Colors.green : (freshSite.type == 'Mixed' ? Colors.teal : Colors.orange);
        const headerTextColor = Colors.white;

        List<String> displayIsos = [];
        final List<String> sortedIsoA3 = List.from(freshSite.countriesIsoA3)..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));
        for (var isoA3 in sortedIsoA3) {
          final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
          if (c != null) displayIsos.add(c.isoA2);
        }

        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [themeColor, themeColor.withOpacity(0.9)])))),
                    Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)])))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                            ElevatedButton(onPressed: () => Navigator.pop(sheetContext), style: ElevatedButton.styleFrom(backgroundColor: headerTextColor), child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [Expanded(child: Text(freshSite.name, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor))), if (isVisited || visitedSubCount > 0) const Icon(Icons.check_circle, color: headerTextColor, size: 24)]),
                          const SizedBox(height: 12),
                          if (displayIsos.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: displayIsos.map((isoA2) => Padding(padding: const EdgeInsets.only(right: 12.0), child: Container(height: 24, width: 32, decoration: BoxDecoration(border: Border.all(color: headerTextColor.withOpacity(0.3), width: 1), borderRadius: BorderRadius.circular(4)), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CountryFlag.fromCountryCode(isoA2))))).toList())),
                          if (totalSubCount > 1) Padding(padding: const EdgeInsets.only(top: 12.0), child: Text("$visitedSubCount / $totalSubCount visited", style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: headerTextColor.withOpacity(0.9), fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [const Text('Wishlist: '), IconButton(icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshSite.name))]),
                        Row(children: [const Text('My Rating: '), RatingBar.builder(initialRating: freshSite.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 20.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating))]),
                      ]),
                      const Divider(),
                      if (totalSubCount > 1) ...[
                        Align(alignment: Alignment.centerLeft, child: Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 4),
                        Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Column(children: freshSite.locations.map((loc) {
                          final isLocVisited = provider.isSubLocationVisited(freshSite.name, loc.name);
                          return CheckboxListTile(title: Text(loc.name, style: const TextStyle(fontSize: 14)), value: isLocVisited, activeColor: themeColor, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => provider.toggleSubLocation(freshSite.name, loc.name));
                        }).toList())),
                        const Divider(height: 24),
                      ],
                      OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshSite.name)),
                      const SizedBox(height: 20),
                      if (freshSite.visitDates.isNotEmpty)
                        ...freshSite.visitDates.asMap().entries.map((entry) => UnescoVisitEditorCard(
                          key: ValueKey('${freshSite.name}_${entry.key}'),
                          siteName: freshSite.name,
                          visitDate: entry.value,
                          index: entry.key,
                          onDelete: () => provider.removeVisitDate(freshSite.name, entry.key),
                          availableLocations: freshSite.locations,
                        )),
                      LandmarkInfoCard(overview: freshSite.overview, historySignificance: freshSite.history_significance, highlights: freshSite.highlights, themeColor: themeColor),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  Widget _buildCreativeHeader({required BuildContext context, required int visited, required int total, required Color color}) {
    final double percentage = total > 0 ? (visited / total) : 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('UNESCO DISCOVERY STATUS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.5)),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${(percentage * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color))),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(NumberFormat.decimalPattern('en_US').format(visited), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), height: 1)),
                  const SizedBox(width: 8),
                  Text('/ ${NumberFormat.decimalPattern('en_US').format(total)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey[300])),
                ]),
              ],
            ),
          ),
          Container(height: 12, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 28), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: percentage, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation<Color>(color)))),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildContinentNav(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 8.0, bottom: 12.0), child: Text('EXPLORE BY CONTINENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.2))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: UnescoStatsScreen.continentsData.map((data) {
              final String fullName = data['fullName'] as String;
              final Color color = data['color'] as Color;
              final bool isSelected = _selectedContinent == fullName;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedContinent = isSelected ? null : fullName),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: isSelected ? color : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)) else BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Row(children: [Text(data['name'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.grey[800], fontSize: 14)), if (isSelected) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.white, size: 16)]]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildContinentDetailSection({required String continentName, required List<UnescoSite> allSites, required UnescoProvider unescoProvider, required CountryProvider countryProvider}) {
    final continentSites = allSites.where((site) => site.countriesIsoA3.any((iso) => countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == iso)?.continent == continentName)).toList();
    if (continentSites.isEmpty) return const SizedBox.shrink();
    final visitedCount = continentSites.where((s) => unescoProvider.visitedSites.contains(s.name) || unescoProvider.getVisitedSubLocationCount(s.name) > 0).length;
    final color = (UnescoStatsScreen.continentsData.firstWhere((d) => d['fullName'] == continentName)['color'] as Color);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: color.withOpacity(0.2), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(continentName.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0)), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('$visitedCount / ${continentSites.length}', style: TextStyle(fontWeight: FontWeight.bold, color: color)))]),
          const SizedBox(height: 20),
          const Text('Recent Discoveries', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          // [Fix] ListTile에 onTap 추가하여 상세 모달 출력
          ...continentSites.where((s) => unescoProvider.visitedSites.contains(s.name)).take(3).map((s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome, color: color, size: 18),
            title: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            dense: true,
            onTap: () => _showUnescoSiteDetailsModal(context, s),
          )),
          if (continentSites.where((s) => unescoProvider.visitedSites.contains(s.name)).isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('No sites visited yet in this continent.', style: TextStyle(fontSize: 13, color: Colors.grey))),
        ],
      ),
    );
  }
}

// --- Ranking Cards 및 상세 로직 ---

Widget _buildRankBadge(int rank) {
  Color bgColor = Colors.grey[100]!; Color textColor = Colors.grey[600]!;
  if (rank == 1) { bgColor = const Color(0xFFFFD700).withOpacity(0.2); textColor = const Color(0xFFB8860B); }
  else if (rank == 2) { bgColor = const Color(0xFFC0C0C0).withOpacity(0.2); textColor = const Color(0xFF708090); }
  else if (rank == 3) { bgColor = const Color(0xFFCD7F32).withOpacity(0.2); textColor = const Color(0xFF8B4513); }
  return Container(width: 32, height: 32, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), alignment: Alignment.center, child: Text(rank.toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)));
}

class _UnescoRankingCard extends StatefulWidget {
  final List<CountryUnescoStats> countryStats;
  final Set<String> visitedCountryNames;
  const _UnescoRankingCard({super.key, required this.countryStats, required this.visitedCountryNames});
  @override State<_UnescoRankingCard> createState() => _UnescoRankingCardState();
}

class _UnescoRankingCardState extends State<_UnescoRankingCard> {
  final List<String> _sortMetrics = ['By Visit Percentage', 'By Visit Count', 'By Number of Sites'];
  late String _sortMetric; int _displaySegment = 0; List<CountryUnescoStats> _rankedList = [];
  @override void initState() { super.initState(); _sortMetric = _sortMetrics.first; _prepareList(); }
  void _prepareList() {
    List<CountryUnescoStats> listToRank = _displaySegment == 0 ? List.from(widget.countryStats) : widget.countryStats.where((s) => widget.visitedCountryNames.contains(s.country.name)).toList();
    listToRank.sort((a, b) {
      num valA, valB;
      switch (_sortMetric) { case 'By Visit Percentage': valA = a.visitedPercentage; valB = b.visitedPercentage; break; case 'By Number of Sites': valA = a.totalSites; valB = b.totalSites; break; default: valA = a.visitedSites; valB = b.visitedSites; }
      int compare = valB.compareTo(valA); return compare == 0 ? a.country.name.compareTo(b.country.name) : compare;
    });
    if (mounted) setState(() => _rankedList = listToRank);
  }
  @override void didUpdateWidget(covariant _UnescoRankingCard oldWidget) { super.didUpdateWidget(oldWidget); _prepareList(); }
  @override Widget build(BuildContext context) {
    const primaryOrange = Colors.orange;
    final Map<String, Color> continentColors = { for (var data in UnescoStatsScreen.continentsData) data['fullName'] as String: data['color'] as Color };
    int maxTotal = 0, maxVisited = 0;
    for (var s in _rankedList) { if (s.totalSites > maxTotal) maxTotal = s.totalSites; if (s.visitedSites > maxVisited) maxVisited = s.visitedSites; }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.leaderboard_rounded, color: primaryOrange), SizedBox(width: 12), Text('Country Rankings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)))]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _sortMetric, isExpanded: true, borderRadius: BorderRadius.circular(16), decoration: InputDecoration(labelText: 'Sort by', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))), items: _sortMetrics.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(), onChanged: (v) { if (v != null) { setState(() { _sortMetric = v; _prepareList(); }); } }),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: SegmentedButton<int>(showSelectedIcon: false, segments: const [ButtonSegment(value: 0, label: Text('All')), ButtonSegment(value: 1, label: Text('Visited'))], selected: {_displaySegment}, onSelectionChanged: (s) { _displaySegment = s.first; _prepareList(); })),
        ])),
        const Divider(height: 1),
        SizedBox(height: 400, child: _rankedList.isEmpty ? const Center(child: Text('No data found.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _rankedList.length, itemBuilder: (context, index) {
          final stat = _rankedList[index]; final barColor = continentColors[stat.country.continent] ?? primaryOrange; final bool isV = widget.visitedCountryNames.contains(stat.country.name);
          double progressValue = 0.0;
          if (_sortMetric == 'By Visit Percentage') { progressValue = stat.totalSites > 0 ? stat.visitedSites / stat.totalSites : 0.0; } else if (_sortMetric == 'By Number of Sites') { progressValue = maxTotal > 0 ? stat.totalSites / maxTotal : 0.0; } else { progressValue = maxVisited > 0 ? stat.visitedSites / maxVisited : 0.0; }
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            _buildRankBadge(index + 1), const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(padding: isV ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero, decoration: isV ? BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)) : null, child: Text(stat.country.name, style: TextStyle(fontSize: 15, fontWeight: isV ? FontWeight.w800 : FontWeight.w700, color: isV ? Colors.orange[900] : const Color(0xFF374151)))),
                Row(children: [Text(_sortMetric == 'By Visit Percentage' ? '${stat.visitedPercentage.toStringAsFixed(1)}%' : '${stat.visitedSites}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))), const SizedBox(width: 4), Text('(${stat.visitedSites}/${stat.totalSites})', style: TextStyle(fontSize: 11, color: Colors.grey[400]))]),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: progressValue, backgroundColor: const Color(0xFFF3F4F6), color: barColor, minHeight: 4)),
            ])),
          ]));
        })),
      ]),
    );
  }
}

class _SiteRankingCard extends StatefulWidget {
  final List<UnescoSite> allSites;
  const _SiteRankingCard({super.key, required this.allSites});
  @override State<_SiteRankingCard> createState() => _SiteRankingCardState();
}

class _SiteRankingCardState extends State<_SiteRankingCard> {
  static const String _sortByVisits = 'By Number of Visits'; static const String _sortByRating = 'By Ratings';
  final List<String> _sortMetrics = [_sortByVisits, _sortByRating]; late String _sortMetric; List<UnescoSite> _rankedList = [];
  @override void initState() { super.initState(); _sortMetric = _sortMetrics.first; _prepareList(); }
  void _prepareList() {
    List<UnescoSite> filteredList = _sortMetric == _sortByVisits ? (widget.allSites.where((s) => s.visitDates.isNotEmpty).toList()..sort((a, b) => b.visitDates.length.compareTo(a.visitDates.length))) : (widget.allSites.where((s) => s.rating != null && s.rating! > 0).toList()..sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0)));
    if (mounted) setState(() => _rankedList = filteredList);
  }
  @override void didUpdateWidget(covariant _SiteRankingCard oldWidget) { super.didUpdateWidget(oldWidget); _prepareList(); }

  void _showUnescoSiteDetailsModal(BuildContext context, UnescoSite site) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (BuildContext sheetContext) {
      final provider = sheetContext.watch<UnescoProvider>(); final countryProvider = sheetContext.read<CountryProvider>(); final freshSite = provider.allSites.firstWhere((l) => l.name == site.name); final isVisited = provider.visitedSites.contains(freshSite.name); final isWishlisted = provider.wishlistedSites.contains(freshSite.name); final visitedSubCount = provider.getVisitedSubLocationCount(freshSite.name); final totalSubCount = freshSite.locations.length; final themeColor = (freshSite.type == 'Natural') ? Colors.green : (freshSite.type == 'Mixed' ? Colors.teal : Colors.orange); const headerTextColor = Colors.white; List<String> displayIsos = []; final List<String> sortedIsoA3 = List.from(freshSite.countriesIsoA3)..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0)); for (var isoA3 in sortedIsoA3) { final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3); if (c != null) displayIsos.add(c.isoA2); }
      return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: FractionallySizedBox(heightFactor: 0.85, child: Column(children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: Stack(children: [
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [themeColor, themeColor.withOpacity(0.9)])))),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)])))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))), ElevatedButton(onPressed: () => Navigator.pop(sheetContext), style: ElevatedButton.styleFrom(backgroundColor: headerTextColor), child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)))]),
            const SizedBox(height: 12), Row(children: [Expanded(child: Text(freshSite.name, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor))), if (isVisited || visitedSubCount > 0) const Icon(Icons.check_circle, color: headerTextColor, size: 24)]),
            const SizedBox(height: 12), if (displayIsos.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: displayIsos.map((isoA2) => Padding(padding: const EdgeInsets.only(right: 12.0), child: Container(height: 24, width: 32, decoration: BoxDecoration(border: Border.all(color: headerTextColor.withOpacity(0.3), width: 1), borderRadius: BorderRadius.circular(4)), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CountryFlag.fromCountryCode(isoA2))))).toList())),
            if (totalSubCount > 1) Padding(padding: const EdgeInsets.only(top: 12.0), child: Text("$visitedSubCount / $totalSubCount visited", style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: headerTextColor.withOpacity(0.9), fontWeight: FontWeight.bold))),
          ])),
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [const Text('Wishlist: '), IconButton(icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshSite.name))]),
            Row(children: [const Text('My Rating: '), RatingBar.builder(initialRating: freshSite.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 20.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating))]),
          ]),
          const Divider(),
          if (totalSubCount > 1) ...[Align(alignment: Alignment.centerLeft, child: Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))), const SizedBox(height: 4), Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Column(children: freshSite.locations.map((loc) { final isLocVisited = provider.isSubLocationVisited(freshSite.name, loc.name); return CheckboxListTile(title: Text(loc.name, style: const TextStyle(fontSize: 14)), value: isLocVisited, activeColor: themeColor, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: (val) { provider.toggleSubLocation(freshSite.name, loc.name); }); }).toList())), const Divider(height: 24)],
          OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshSite.name)),
          const SizedBox(height: 20),
          if (freshSite.visitDates.isNotEmpty)
            ...freshSite.visitDates.asMap().entries.map((entry) => UnescoVisitEditorCard(
              key: ValueKey('${freshSite.name}_${entry.key}'),
              siteName: freshSite.name,
              visitDate: entry.value,
              index: entry.key,
              onDelete: () => provider.removeVisitDate(freshSite.name, entry.key),
              availableLocations: freshSite.locations,
            )),
          LandmarkInfoCard(overview: freshSite.overview, historySignificance: freshSite.history_significance, highlights: freshSite.highlights, themeColor: themeColor),
          const SizedBox(height: 40),
        ])))
      ])));
    }).then((_) => setState(() {}));
  }

  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.star_rounded, color: Colors.amber), SizedBox(width: 12), Text('Top UNESCO Sites', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)))]),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(value: _sortMetric, isExpanded: true, borderRadius: BorderRadius.circular(16), decoration: InputDecoration(labelText: 'Sort by', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))), items: _sortMetrics.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(), onChanged: (v) { if (v != null) { setState(() { _sortMetric = v; _prepareList(); }); } }),
        ])),
        const Divider(height: 1),
        SizedBox(height: 300, child: _rankedList.isEmpty ? const Center(child: Text('No data available.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _rankedList.length, itemBuilder: (context, index) {
          final site = _rankedList[index];
          return ListTile(onTap: () => _showUnescoSiteDetailsModal(context, site), contentPadding: const EdgeInsets.symmetric(horizontal: 8), leading: _buildRankBadge(index + 1), title: Text(site.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis), trailing: _sortMetric == _sortByRating ? Row(mainAxisSize: MainAxisSize.min, children: [RatingBarIndicator(rating: site.rating ?? 0.0, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 14.0), const SizedBox(width: 4), Text((site.rating ?? 0).toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]) : Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${site.visitDates.length} visits', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.orange))));
        })),
      ]),
    );
  }
}

class _TypeStatsCard extends StatelessWidget {
  final List<TypeStatData> typeStats; final Color primaryColor;
  const _TypeStatsCard({required this.typeStats, required this.primaryColor});
  @override Widget build(BuildContext context) {
    final progressEntries = List<TypeStatData>.from(typeStats)..sort((a, b) => b.percentage.compareTo(a.percentage));
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(24), child: Row(children: [Icon(Icons.pie_chart_rounded, color: Colors.blueGrey[600]), const SizedBox(width: 12), const Text('Type Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(24.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Visit Progress (%)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)), const SizedBox(height: 20),
          ...progressEntries.map((s) => _buildStatRow(label: s.name, value: s.visitedCount, maxValue: s.totalCount, info: '${s.percentage.toStringAsFixed(1)}%', color: s.color)),
        ])),
      ]),
    );
  }
  Widget _buildStatRow({required String label, required int value, required int maxValue, required String info, required Color color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))), Text('$value / $maxValue ($info)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)))]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (ctx, constraints) => Stack(children: [Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(3))), Container(height: 6, width: constraints.maxWidth * (maxValue > 0 ? value / maxValue : 0), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))]))
    ]));
  }
}