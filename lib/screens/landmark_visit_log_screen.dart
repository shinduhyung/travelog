// lib/screens/landmark_visit_log_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart'; // 공통 위젯 추가

enum LogGroupOption { year, country }

class LandmarkVisitLogScreen extends StatefulWidget {
  const LandmarkVisitLogScreen({super.key});

  @override
  State<LandmarkVisitLogScreen> createState() => _LandmarkVisitLogScreenState();
}

class _LandmarkVisitLogScreenState extends State<LandmarkVisitLogScreen> {
  LogGroupOption _logGroupOption = LogGroupOption.year;

  // 이 화면의 기본 테마 색상 (녹색)
  final Color _themeColor = const Color(0xFF10B981);

  String? _getDisplayIsoA2(Landmark site, CountryProvider countryProvider) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.city.contains('Hong Kong') || site.countriesIsoA3.contains('HKG')) return 'HK';
    if (site.countriesIsoA3.length == 1) {
      try {
        final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first);
        return c?.isoA2;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LandmarksProvider>();
    final cp = context.watch<CountryProvider>();

    if (lp.isLoading || cp.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. 모든 방문 기록을 평탄화(Flatten)하여 수집
    List<_VisitLogItem> allLogs = [];
    for (var site in lp.allLandmarks) {
      for (int i = 0; i < site.visitDates.length; i++) {
        allLogs.add(_VisitLogItem(
          site: site,
          visit: site.visitDates[i],
          nthVisit: i + 1,
        ));
      }
    }

    // 2. 그룹화 처리
    Map<String, List<_VisitLogItem>> groupedLogs = {};
    if (_logGroupOption == LogGroupOption.year) {
      for (var item in allLogs) {
        String year = (item.visit.year != null && item.visit.year! > 0) ? item.visit.year.toString() : "Unknown Year";
        groupedLogs.putIfAbsent(year, () => []).add(item);
      }
    } else {
      for (var item in allLogs) {
        String country = item.site.countriesIsoA3.isNotEmpty ? (cp.isoToCountryNameMap[item.site.countriesIsoA3.first] ?? "Unknown") : "Unknown";
        groupedLogs.putIfAbsent(country, () => []).add(item);
      }
    }

    // 3. 그룹 및 그룹 내 아이템 정렬
    var sortedKeys = groupedLogs.keys.toList();
    if (_logGroupOption == LogGroupOption.year) {
      sortedKeys.sort((a, b) => b.compareTo(a)); // 최신 연도부터
    } else {
      sortedKeys.sort(); // 국가명 가나다순
    }

    // 그룹 내에서는 날짜 기준 내림차순
    for (var key in sortedKeys) {
      groupedLogs[key]!.sort((a, b) {
        final dateA = DateTime(a.visit.year ?? 0, a.visit.month ?? 1, a.visit.day ?? 1);
        final dateB = DateTime(b.visit.year ?? 0, b.visit.month ?? 1, b.visit.day ?? 1);
        return dateB.compareTo(dateA);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Visit History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<LogGroupOption>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) => setState(() => _logGroupOption = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: LogGroupOption.year, child: Text("Group by Year")),
              const PopupMenuItem(value: LogGroupOption.country, child: Text("Group by Country")),
            ],
          ),
        ],
      ),
      body: allLogs.isEmpty
          ? const Center(child: Text("No visit records found."))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          String key = sortedKeys[index];
          List<_VisitLogItem> logs = groupedLogs[key]!;
          return _buildGroupSection(key, logs, cp);
        },
      ),
    );
  }

  Widget _buildGroupSection(String title, List<_VisitLogItem> logs, CountryProvider cp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
        ),
        ...logs.map((item) => _buildVisitCard(item, cp)).toList(),
      ],
    );
  }

  Widget _buildVisitCard(_VisitLogItem item, CountryProvider cp) {
    String? iso = _getDisplayIsoA2(item.site, cp);
    String dateStr = "${item.visit.year ?? '?'}.${item.visit.month?.toString().padLeft(2, '0') ?? '?'}.${item.visit.day?.toString().padLeft(2, '0') ?? '?'}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: iso != null
                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 28, height: 20, child: CountryFlag.fromCountryCode(iso)))
                : const Icon(Icons.place_rounded, color: Color(0xFF10B981)),
          ),
        ),
        title: Text(
          item.site.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827)),
        ),
        subtitle: Text(
          "$dateStr • Visit #${item.nthVisit}",
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: item.site.rating != null && item.site.rating! > 0
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
            const SizedBox(width: 2),
            Text(item.site.rating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151))),
          ],
        )
            : null,
        onTap: () => _showLandmarkDetailsModal(context, item.site, _themeColor),
      ),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            landmarkThemeColor = country.themeColor;
          } catch (e) { landmarkThemeColor = null; }
        }

        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(sheetContext), child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                        ElevatedButton(onPressed: () => Navigator.pop(sheetContext), child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)), style: ElevatedButton.styleFrom(backgroundColor: headerTextColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text(freshLandmark.name, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                        if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(locationDisplay, style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name))]),
                        const SizedBox(height: 8),
                        if (freshLandmark.visitDates.isNotEmpty) ...freshLandmark.visitDates.asMap().entries.map((entry) => LandmarkVisitEditorCard(
                          key: ValueKey('${freshLandmark.name}_${entry.key}'),
                          landmarkName: freshLandmark.name,
                          visitDate: entry.value,
                          index: entry.key,
                          onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                          availableLocations: freshLandmark.locations,
                        )) else const Center(child: Text('No visits recorded.')),
                        const Divider(height: 24),
                        LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisitLogItem {
  final Landmark site;
  final VisitDate visit;
  final int nthVisit;
  _VisitLogItem({required this.site, required this.visit, required this.nthVisit});
}

class DiagonalClipper extends CustomClipper<Path> {
  const DiagonalClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0.0);
    path.lineTo(size.width, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}