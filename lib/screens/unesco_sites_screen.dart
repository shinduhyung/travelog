// lib/screens/unesco_sites_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:io';
import 'dart:ui'; // BackdropFilter, ImageFilter 사용을 위해 추가
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/screens/unesco_map_screen.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/models/country_model.dart';

enum SiteSortOption { nameAsc, inscriptionYearAsc, countryAsc }
enum LogSortOption { newest, oldest }
enum LogGroupOption { year, country }

class UnescoSitesScreen extends StatefulWidget {
  const UnescoSitesScreen({super.key});

  @override
  State<UnescoSitesScreen> createState() => _UnescoSitesScreenState();
}

class _UnescoSitesScreenState extends State<UnescoSitesScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Default sort option is Country
  SiteSortOption _sortOption = SiteSortOption.countryAsc;

  // Filter States
  bool _showVisitedOnly = false;
  bool _showCultural = true;
  bool _showNatural = true;
  bool _showMixed = true;

  // Visit Log States
  bool _isLogExpanded = true;
  LogSortOption _logSortOption = LogSortOption.newest;
  LogGroupOption _logGroupOption = LogGroupOption.country; // Default 변경됨

  // Cached grouped list
  Map<String, List<UnescoSite>>? _cachedGroupedList;
  List<String>? _cachedSortedKeys;

  // Track the currently expanded group index to allow only one open at a time
  int? _expandedGroupIndex;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _cachedGroupedList = null;
      _cachedSortedKeys = null;
      _expandedGroupIndex = null;
    });
  }

  // --- Theme Helpers ---

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Natural': return Colors.green;
      case 'Mixed': return Colors.teal;
      case 'Cultural': default: return Colors.orange;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Natural': return Icons.landscape;
      case 'Mixed': return Icons.auto_awesome;
      case 'Cultural': default: return Icons.account_balance;
    }
  }

  // --- Filtering and Sorting Logic ---

  void _updateGroupedListIfNeeded(UnescoProvider provider, CountryProvider countryProvider) {
    if (_sortOption == SiteSortOption.nameAsc &&
        _searchController.text.trim().isEmpty &&
        !_showVisitedOnly) {
      _cachedGroupedList = {};
      _cachedSortedKeys = [];
      return;
    }

    if (_cachedGroupedList != null && _cachedSortedKeys != null) return;

    List<UnescoSite> filteredList = provider.allSites.where((item) {
      final searchQuery = _searchController.text.toLowerCase();
      if (searchQuery.isNotEmpty) {
        final matchesSiteName = item.name.toLowerCase().contains(searchQuery);
        final matchesCity = item.city.toLowerCase().contains(searchQuery);
        final matchesSubLocation = item.locations.any((loc) =>
            loc.name.toLowerCase().contains(searchQuery));
        final matchesCountry = item.countriesIsoA3.any((iso) {
          final countryName = countryProvider.isoToCountryNameMap[iso]?.toLowerCase() ?? '';
          return countryName.contains(searchQuery) || iso.toLowerCase().contains(searchQuery);
        });

        if (!matchesSiteName && !matchesCity && !matchesSubLocation && !matchesCountry) {
          return false;
        }
      }

      if (_showVisitedOnly) {
        final isMainVisited = provider.visitedSites.contains(item.name);
        final isSubVisited = provider.getVisitedSubLocationCount(item.name) > 0;
        if (!isMainVisited && !isSubVisited) return false;
      }

      if (item.type == 'Cultural' && !_showCultural) return false;
      if (item.type == 'Natural' && !_showNatural) return false;
      if (item.type == 'Mixed' && !_showMixed) return false;

      return true;
    }).toList();

    filteredList.sort((a, b) => a.name.compareTo(b.name));

    Map<String, List<UnescoSite>> groupedMap = {};

    if (_sortOption == SiteSortOption.nameAsc) {
      groupedMap['All Sites'] = filteredList;
    } else {
      for (var item in filteredList) {
        String groupKey;
        if (_sortOption == SiteSortOption.inscriptionYearAsc) {
          groupKey = item.inscription ?? 'Unknown Year';
        } else if (_sortOption == SiteSortOption.countryAsc) {
          final primaryIso = item.countriesIsoA3.isNotEmpty ? item.countriesIsoA3.first : 'Other';
          groupKey = countryProvider.isoToCountryNameMap[primaryIso] ?? primaryIso;
        } else {
          groupKey = 'Other';
        }
        groupedMap.putIfAbsent(groupKey, () => []).add(item);
      }
    }

    final sortedKeys = groupedMap.keys.toList();
    if (_sortOption == SiteSortOption.countryAsc || _sortOption == SiteSortOption.inscriptionYearAsc) {
      sortedKeys.sort((a, b) {
        if (a == 'Unknown Year') return 1;
        if (b == 'Unknown Year') return -1;
        return a.compareTo(b);
      });
    }

    Map<String, List<UnescoSite>> finalGroupedMap = {};
    for (var key in sortedKeys) {
      finalGroupedMap[key] = groupedMap[key]!;
    }

    _cachedGroupedList = finalGroupedMap;
    _cachedSortedKeys = sortedKeys;
  }

  void _filterAndSortList() {
    setState(() {
      _cachedGroupedList = null;
      _cachedSortedKeys = null;
      _expandedGroupIndex = null;
    });
  }

  String? _getDisplayIsoA2(UnescoSite site, CountryProvider countryProvider) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.countriesIsoA3.contains('GRL')) return 'GL';
    if (site.countriesIsoA3.contains('PYF')) return 'PF';
    if (site.countriesIsoA3.contains('PRI')) return 'PR';
    if (site.countriesIsoA3.contains('BMU')) return 'BM';
    if (site.countriesIsoA3.contains('GIB')) return 'GI';
    if (site.countriesIsoA3.contains('PCN')) return 'PN';

    if (site.countriesIsoA3.length > 1) {
      return null;
    } else if (site.countriesIsoA3.isNotEmpty) {
      try {
        final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first);
        return c?.isoA2;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _navigateToDetailsModal(BuildContext context, UnescoSite selectedSite) {
    _showUnescoSiteDetailsModal(context, selectedSite, _getTypeColor(selectedSite.type));
  }

  void _showUnescoSiteDetailsModal(BuildContext context, UnescoSite site, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 투명 배경 추가
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<UnescoProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();
        final freshSite = provider.allSites.firstWhere((l) => l.name == site.name);
        final isVisited = provider.visitedSites.contains(freshSite.name);
        final isWishlisted = provider.wishlistedSites.contains(freshSite.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshSite.name);
        final totalSubCount = freshSite.locations.length;

        final themeColor = _getTypeColor(freshSite.type);
        const headerTextColor = Colors.white;

        String? modalFlagIso = _getDisplayIsoA2(freshSite, countryProvider);
        List<String> displayIsos = [];

        final List<String> sortedIsoA3 = List.from(freshSite.countriesIsoA3)
          ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

        if (modalFlagIso != null) {
          displayIsos = [modalFlagIso];
        } else {
          for (var isoA3 in sortedIsoA3) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
            if (c != null) displayIsos.add(c.isoA2);
          }
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                // 그라데이션 및 오버레이 헤더 적용
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [themeColor, themeColor.withOpacity(0.9)],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                                  child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    freshSite.name,
                                    style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                if (isVisited || visitedSubCount > 0)
                                  const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (displayIsos.isNotEmpty)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: displayIsos.map((isoA2) => Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Container(
                                      height: 24,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: headerTextColor.withOpacity(0.3), width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: CountryFlag.fromCountryCode(isoA2),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ),
                            if (totalSubCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  "$visitedSubCount / $totalSubCount visited",
                                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                    color: headerTextColor.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Wishlist: '),
                                IconButton(
                                  icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                                  onPressed: () => provider.toggleWishlistStatus(freshSite.name),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('My Rating: '),
                                RatingBar.builder(
                                  initialRating: freshSite.rating ?? 0.0,
                                  minRating: 0,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 20.0,
                                  itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                  onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        if (totalSubCount > 1) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: freshSite.locations.map((loc) {
                                final isLocVisited = provider.isSubLocationVisited(freshSite.name, loc.name);
                                return CheckboxListTile(
                                  title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                  value: isLocVisited,
                                  activeColor: themeColor,
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (val) {
                                    provider.toggleSubLocation(freshSite.name, loc.name);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 24),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Visit'),
                          onPressed: () => provider.addVisitDate(freshSite.name),
                        ),
                        const SizedBox(height: 10),
                        if (freshSite.visitDates.isNotEmpty)
                          ...freshSite.visitDates.asMap().entries.map((entry) => _UnescoVisitEditorCard(
                            key: ValueKey('${freshSite.name}_${entry.key}'),
                            siteName: freshSite.name,
                            visitDate: entry.value,
                            index: entry.key,
                            onDelete: () => provider.removeVisitDate(freshSite.name, entry.key),
                            availableLocations: freshSite.locations,
                          )),
                        const SizedBox(height: 20),
                        LandmarkInfoCard(
                          overview: freshSite.overview,
                          historySignificance: freshSite.history_significance,
                          highlights: freshSite.highlights,
                          themeColor: themeColor,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    final countryProvider = context.read<CountryProvider>();

    return Consumer<UnescoProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoading;
        _updateGroupedListIfNeeded(provider, countryProvider);
        final groupedItems = _cachedGroupedList ?? {};
        final sortedGroupKeys = _cachedSortedKeys ?? [];

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (provider.allSites.isEmpty
                ? const Center(child: Text('No UNESCO Sites Loaded'))
                : _buildBody(context, provider, groupedItems, sortedGroupKeys)),
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context,
      UnescoProvider provider,
      Map<String, List<UnescoSite>> groupedItems,
      List<String> sortedGroupKeys) {

    final allItems = provider.allSites;
    final visitedItems = provider.visitedSites;
    final visitedCount = allItems.where((item) => visitedItems.contains(item.name)).length;
    final totalCount = allItems.length;
    final percentage = totalCount > 0 ? (visitedCount / totalCount) : 0.0;
    final mainThemeColor = Colors.orange;

    return CustomScrollView(
      slivers: [
        // Header Section
        SliverToBoxAdapter(
          child: _buildHeader(context, percentage, visitedCount, totalCount, mainThemeColor),
        ),

        // Visit Log Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildVisitLogSection(context, provider, mainThemeColor),
          ),
        ),

        // Controls Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildControls(context, mainThemeColor),
          ),
        ),

        // List Section
        if (_sortOption != SiteSortOption.nameAsc || _searchController.text.trim().isNotEmpty || _showVisitedOnly)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final groupKey = sortedGroupKeys[index];
                  final groupItems = groupedItems[groupKey]!;

                  if (_sortOption == SiteSortOption.nameAsc) {
                    return Column(
                      children: groupItems.map((item) => _buildSiteCard(context, provider, item, showLeading: true)).toList(),
                    );
                  }
                  else {
                    final visitedInGroup = groupItems.where((item) => provider.visitedSites.contains(item.name) || provider.getVisitedSubLocationCount(item.name) > 0).length;
                    final countryProvider = context.read<CountryProvider>();
                    Widget? headerBadge;

                    if (_sortOption == SiteSortOption.countryAsc) {
                      String? headerIso;
                      try {
                        final country = countryProvider.allCountries.firstWhere((c) => c.name == groupKey);
                        headerIso = country.isoA2;
                      } catch(e) {}
                      if (headerIso != null) {
                        headerBadge = ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 28, height: 20, child: CountryFlag.fromCountryCode(headerIso)));
                      } else {
                        headerBadge = const Icon(Icons.flag, size: 20, color: Colors.grey);
                      }
                    } else {
                      headerBadge = Text('${groupItems.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: mainThemeColor));
                    }

                    final bool isExpanded = _expandedGroupIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: Key('group_${_sortOption}_$index${isExpanded ? '_open' : ''}'),
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (isOpen) {
                              if (isOpen) {
                                setState(() {
                                  _expandedGroupIndex = index;
                                });
                              }
                            },
                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: mainThemeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: headerBadge,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(child: Text(groupKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      Text('($visitedInGroup/${groupItems.length})', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            children: isExpanded
                                ? groupItems.map((item) => _buildSiteCard(context, provider, item, showLeading: false)).toList()
                                : [],
                          ),
                        ),
                      ),
                    );
                  }
                },
                childCount: sortedGroupKeys.length,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      "Search to find UNESCO sites",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildVisitLogSection(BuildContext context, UnescoProvider provider, Color themeColor) {
    if (provider.visitedSites.isEmpty) return const SizedBox.shrink();

    List<_VisitLogItem> logs = [];
    for (var site in provider.allSites) {
      int totalVisits = site.visitDates.length;
      for (int i = 0; i < totalVisits; i++) {
        final visit = site.visitDates[i];
        if (visit.year != null && visit.year != -9999) {
          logs.add(_VisitLogItem(site: site, visit: visit, nthVisit: totalVisits - i));
        }
      }
    }
    if (logs.isEmpty) return const SizedBox.shrink();

    logs.sort((a, b) {
      final dateA = DateTime(a.visit.year ?? 0, a.visit.month ?? 1, a.visit.day ?? 1);
      final dateB = DateTime(b.visit.year ?? 0, b.visit.month ?? 1, b.visit.day ?? 1);
      return dateB.compareTo(dateA);
    });

    Map<String, List<_VisitLogItem>> groupedLogs = {};
    if (_logGroupOption == LogGroupOption.year) {
      for (var log in logs) {
        groupedLogs.putIfAbsent(log.visit.year.toString(), () => []).add(log);
      }
    } else if (_logGroupOption == LogGroupOption.country) {
      final countryProvider = context.read<CountryProvider>();
      for (var log in logs) {
        final iso = log.site.countriesIsoA3.isNotEmpty ? log.site.countriesIsoA3.first : 'Other';
        final name = countryProvider.isoToCountryNameMap[iso] ?? iso;
        groupedLogs.putIfAbsent(name, () => []).add(log);
      }
    }

    final sortedLogKeys = groupedLogs.keys.toList();
    if (_logGroupOption == LogGroupOption.year) {
      sortedLogKeys.sort((a, b) => b.compareTo(a));
    } else {
      sortedLogKeys.sort();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history_edu, color: themeColor),
                const SizedBox(width: 8),
                const Text("Visit Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isLogExpanded) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LogGroupOption>(
                        value: _logGroupOption,
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down, size: 18, color: themeColor),
                        style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600),
                        onChanged: (LogGroupOption? newValue) {
                          if (newValue != null) setState(() => _logGroupOption = newValue);
                        },
                        items: const [
                          DropdownMenuItem(value: LogGroupOption.year, child: Text('By Year')),
                          DropdownMenuItem(value: LogGroupOption.country, child: Text('By Country')),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            IconButton(
              icon: Icon(_isLogExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isLogExpanded = !_isLogExpanded),
            ),
          ],
        ),
        if (_isLogExpanded) ...[
          const SizedBox(height: 12),
          if (_logGroupOption == LogGroupOption.country)
            ...sortedLogKeys.map((key) => _buildCountryLogGroup(context, key, groupedLogs[key]!)).toList()
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: sortedLogKeys.length,
                itemBuilder: (ctx, index) {
                  final key = sortedLogKeys[index];
                  final items = groupedLogs[key]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(key, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                      ),
                      ...items.map((log) => _buildLogItem(log, themeColor)).toList(),
                      if (index < sortedLogKeys.length - 1) const Divider(height: 1),
                    ],
                  );
                },
              ),
            ),
        ]
      ],
    );
  }

  Widget _buildCountryLogGroup(BuildContext context, String countryName, List<_VisitLogItem> items) {
    final countryProvider = context.read<CountryProvider>();
    Color themeColor = Colors.blueGrey;
    String? isoA2;

    try {
      final country = countryProvider.allCountries.firstWhere((c) => c.name == countryName);
      if (country.themeColor != null) themeColor = country.themeColor!;
      isoA2 = country.isoA2;
    } catch(e) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      if (isoA2 != null) ...[
                        SizedBox(width: 16, height: 12, child: CountryFlag.fromCountryCode(isoA2)),
                        const SizedBox(width: 6),
                      ],
                      Text(countryName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                const Spacer(),
                Text("${items.length} visits", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          ...items.map((log) => _buildLogItem(log, themeColor)).toList(),
        ],
      ),
    );
  }

  Widget _buildLogItem(_VisitLogItem item, Color themeColor) {
    String dateStr = "${item.visit.year}";
    if (item.visit.month != -9999) {
      dateStr += "-${item.visit.month.toString().padLeft(2, '0')}";
      if (item.visit.day != -9999) {
        dateStr += "-${item.visit.day.toString().padLeft(2, '0')}";
      }
    }
    String ordinal = "th";
    if (item.nthVisit % 10 == 1 && item.nthVisit != 11) ordinal = "st";
    else if (item.nthVisit % 10 == 2 && item.nthVisit != 12) ordinal = "nd";
    else if (item.nthVisit % 10 == 3 && item.nthVisit != 13) ordinal = "rd";

    Color typeColor = _getTypeColor(item.site.type);

    return ListTile(
      dense: true,
      leading: Container(
        width: 10, height: 10,
        margin: const EdgeInsets.only(left: 4, right: 4),
        decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
      ),
      title: Text(item.site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: Colors.grey),
          const SizedBox(width: 8),
          Text("${item.nthVisit}$ordinal visit", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ],
      ),
      trailing: item.site.rating != null && item.site.rating! > 0
          ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 14, color: Colors.amber), Text(item.site.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])
          : null,
      onTap: () => _navigateToDetailsModal(context, item.site),
    );
  }

  Widget _buildHeader(BuildContext context, double percentage, int visitedCount, int totalCount, Color themeColor) {
    return Container(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UNESCO — big, proud, fills the space
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'UNESCO',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: themeColor,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                // small dot separator
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'World Heritage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Thin accent underline only under UNESCO
            Row(
              children: [
                Container(
                  width: 120,
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor, themeColor.withOpacity(0)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInlineProgress(context, percentage, visitedCount, totalCount, themeColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineProgress(BuildContext context, double percentage, int visitedCount, int totalCount, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Count info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$visitedCount',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: ' / $totalCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'sites explored',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Thin vertical divider
          Container(width: 1, height: 36, color: Colors.grey[100]),
          const SizedBox(width: 16),
          // Progress bar + percentage
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: themeColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 4, color: Colors.grey[100]),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [themeColor, themeColor.withOpacity(0.6)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, double percentage, int visitedCount, int totalCount, Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Colors.white.withOpacity(0.95)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4)],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(0.05)))),
          Positioned(left: -10, bottom: -10, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withOpacity(0.03)))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: [themeColor, themeColor.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.emoji_events_rounded, size: 20, color: Colors.white)),
                            const SizedBox(width: 12),
                            const Text('My Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.3)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(padding: const EdgeInsets.only(left: 52), child: Text('Keep exploring!', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
                      ],
                    ),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(gradient: LinearGradient(colors: [themeColor.withOpacity(0.15), themeColor.withOpacity(0.08)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5)), child: Text('${(percentage * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: -0.5))),
                  ],
                ),
                const SizedBox(height: 24),
                Stack(
                  children: [
                    Container(height: 14, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10))),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: ShaderMask(shaderCallback: (bounds) => LinearGradient(colors: [themeColor, themeColor.withOpacity(0.8)]).createShader(bounds), child: Container(height: 14, width: MediaQuery.of(context).size.width * percentage, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor)), const SizedBox(width: 8), Text('$visitedCount visited', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600))]),
                    Text('$totalCount sites', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(hintText: 'Search sites or countries...', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15), prefixIcon: Icon(Icons.search, color: Colors.grey[400]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), filled: true, fillColor: Colors.white, suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400]), onPressed: () => _searchController.clear()) : null),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SiteSortOption>(
              value: _sortOption,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              onChanged: (SiteSortOption? newValue) { if (newValue != null) setState(() { _sortOption = newValue; _filterAndSortList(); }); },
              items: const [
                DropdownMenuItem(value: SiteSortOption.nameAsc, child: Text('Name', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: SiteSortOption.countryAsc, child: Text('Country', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: SiteSortOption.inscriptionYearAsc, child: Text('Inscription Year', style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Wrap(spacing: 8.0, children: [
              FilterChip(label: const Text('Cult.', style: TextStyle(fontSize: 12)), selected: _showCultural, onSelected: (val) => setState(() { _showCultural = val; _filterAndSortList(); }), visualDensity: VisualDensity.compact, selectedColor: Colors.orange.withOpacity(0.2), checkmarkColor: Colors.orange, backgroundColor: Colors.white, side: BorderSide(color: _showCultural ? Colors.orange : Colors.grey[200]!)),
              FilterChip(label: const Text('Nat.', style: TextStyle(fontSize: 12)), selected: _showNatural, onSelected: (val) => setState(() { _showNatural = val; _filterAndSortList(); }), visualDensity: VisualDensity.compact, selectedColor: Colors.green.withOpacity(0.2), checkmarkColor: Colors.green, backgroundColor: Colors.white, side: BorderSide(color: _showNatural ? Colors.green : Colors.grey[200]!)),
              FilterChip(label: const Text('Mix', style: TextStyle(fontSize: 12)), selected: _showMixed, onSelected: (val) => setState(() { _showMixed = val; _filterAndSortList(); }), visualDensity: VisualDensity.compact, selectedColor: Colors.teal.withOpacity(0.2), checkmarkColor: Colors.teal, backgroundColor: Colors.white, side: BorderSide(color: _showMixed ? Colors.teal : Colors.grey[200]!)),
            ]),
            const Spacer(),
            FilterChip(label: const Text('Visited', style: TextStyle(fontSize: 13)), selected: _showVisitedOnly, onSelected: (bool selected) => setState(() { _showVisitedOnly = selected; _filterAndSortList(); }), backgroundColor: Colors.white, selectedColor: themeColor.withOpacity(0.15), checkmarkColor: themeColor, side: BorderSide(color: Colors.grey[200]!), labelStyle: TextStyle(color: _showVisitedOnly ? themeColor : Colors.grey[700], fontWeight: _showVisitedOnly ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSiteToggle(BuildContext context, UnescoSite item, bool isVisited, UnescoProvider provider) async {
    if (isVisited) {
      if (item.visitDates.isNotEmpty) {
        final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirm Removal'), content: Text('Are you sure you want to remove all visit records for ${item.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Remove', style: TextStyle(color: Colors.red)))]));
        if (confirm == true) provider.toggleVisitedStatus(item.name);
      } else {
        provider.toggleVisitedStatus(item.name);
      }
    } else {
      provider.toggleVisitedStatus(item.name);
    }
  }

  Widget _buildSiteCard(BuildContext context, UnescoProvider provider, UnescoSite item, {required bool showLeading}) {
    final isVisited = provider.visitedSites.contains(item.name);
    final isWishlisted = provider.wishlistedSites.contains(item.name);
    final visitedSubCount = provider.getVisitedSubLocationCount(item.name);
    final typeColor = _getTypeColor(item.type);
    Color statusColor = (isVisited || visitedSubCount > 0) ? typeColor : Colors.grey[400]!;
    final countryProvider = context.read<CountryProvider>();
    Widget? leadingWidget;

    final List<String> sortedIsoA3 = List.from(item.countriesIsoA3)
      ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

    if (showLeading) {
      String? territoryIsoA2 = _getDisplayIsoA2(item, countryProvider);

      if (territoryIsoA2 != null) {
        leadingWidget = ClipRRect(borderRadius: BorderRadius.circular(12), child: CountryFlag.fromCountryCode(territoryIsoA2));
      }
      else if (sortedIsoA3.length == 2) {
        String? iso1, iso2;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48, height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CountryFlag.fromCountryCode(iso1),
                  ClipPath(clipper: const DiagonalClipper(), child: CountryFlag.fromCountryCode(iso2)),
                ],
              ),
            ),
          );
        } else {
          leadingWidget = Icon(Icons.public, color: statusColor, size: 24);
        }
      }
      else if (sortedIsoA3.length == 3) {
        String? iso1, iso2, iso3;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
          iso3 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[2])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null && iso3 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 48, height: 48, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso1)), Expanded(child: CountryFlag.fromCountryCode(iso2)), Expanded(child: CountryFlag.fromCountryCode(iso3))])),
          );
        } else {
          leadingWidget = Icon(Icons.public, color: statusColor, size: 24);
        }
      }
      else if (sortedIsoA3.length >= 4) {
        String? iso1, iso2, iso3, iso4;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
          iso3 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[2])?.isoA2;
          iso4 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[3])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null && iso3 != null && iso4 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 48, height: 48, child: Column(children: [Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso1)), Expanded(child: CountryFlag.fromCountryCode(iso2))])), Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso3)), Expanded(child: CountryFlag.fromCountryCode(iso4))]))])),
          );
        } else {
          leadingWidget = Icon(Icons.public, color: statusColor, size: 24);
        }
      }
      else if (sortedIsoA3.isNotEmpty) {
        String? isoA2;
        try {
          final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3.first);
          isoA2 = c?.isoA2;
        } catch (e) { isoA2 = null; }
        if (isoA2 != null) {
          leadingWidget = ClipRRect(borderRadius: BorderRadius.circular(12), child: CountryFlag.fromCountryCode(isoA2));
        } else {
          leadingWidget = Icon(Icons.flag, color: statusColor, size: 24);
        }
      } else {
        leadingWidget = Icon(Icons.flag, color: statusColor, size: 24);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (isVisited || visitedSubCount > 0) ? typeColor.withOpacity(0.3) : Colors.grey[200]!, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToDetailsModal(context, item),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (showLeading && leadingWidget != null) ...[
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: leadingWidget)),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: Container(height: 42, alignment: Alignment.centerLeft, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis))),
                  const SizedBox(width: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey[400], size: 22), onPressed: () => provider.toggleWishlistStatus(item.name)), SizedBox(width: 36, height: 36, child: Transform.scale(scale: 1.1, child: Checkbox(value: isVisited, activeColor: typeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), onChanged: (bool? value) => _handleSiteToggle(context, item, isVisited, provider))))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitLogItem {
  final UnescoSite site;
  final VisitDate visit;
  final int nthVisit;
  _VisitLogItem({required this.site, required this.visit, required this.nthVisit});
}

class _UnescoVisitEditorCard extends StatefulWidget {
  final String siteName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<UnescoSubLocation> availableLocations;
  const _UnescoVisitEditorCard({super.key, required this.siteName, required this.visitDate, required this.index, required this.onDelete, required this.availableLocations});
  @override
  State<_UnescoVisitEditorCard> createState() => _UnescoVisitEditorCardState();
}

class _UnescoVisitEditorCardState extends State<_UnescoVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;
  final ExpansionTileController _expansionTileController = ExpansionTileController();
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.visitDate.title);
    _memoController = TextEditingController(text: widget.visitDate.memo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;
  }
  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(pickedFile.path);
      setState(() => _currentPhotos = newPhotos);
      context.read<UnescoProvider>().updateLandmarkVisit(widget.siteName, widget.index, photos: newPhotos);
    }
  }
  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<UnescoProvider>();
    List<String> currentDetails = List.from(widget.visitDate.visitedDetails);
    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.siteName, locName)) provider.toggleSubLocation(widget.siteName, locName);
      }
    } else {
      currentDetails.remove(locName);
    }
    provider.updateLandmarkVisit(widget.siteName, widget.index, visitedDetails: currentDetails);
    setState(() {});
  }
  Widget _buildPhotoPreview(String photoPath, int index) {
    return Container(width: 80, height: 80, margin: const EdgeInsets.only(right: 8), color: Colors.grey, child: Image.file(File(photoPath), fit: BoxFit.cover));
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.read<UnescoProvider>();
    final themeColor = Theme.of(context).primaryColor;
    return Card(
      child: ExpansionTile(
        controller: _expansionTileController,
        title: Text(widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record'),
        subtitle: Text('Date: $_year-$_month-$_day'),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Delete Visit Record'), content: const Text('Are you sure you want to delete this visit record?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { Navigator.pop(context); widget.onDelete(); }, child: const Text('Delete', style: TextStyle(color: Colors.red)))])); }),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title'), onEditingComplete: () => provider.updateLandmarkVisit(widget.siteName, widget.index, title: _titleController.text)),
              TextField(controller: _memoController, decoration: const InputDecoration(labelText: 'Memo'), onEditingComplete: () => provider.updateLandmarkVisit(widget.siteName, widget.index, memo: _memoController.text)),
              const SizedBox(height: 16),
              if (widget.availableLocations.length > 1) ...[
                const Text("Locations included in this visit:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(spacing: 8.0, runSpacing: 4.0, children: widget.availableLocations.map((loc) { final isChecked = widget.visitDate.visitedDetails.contains(loc.name); return FilterChip(label: Text(loc.name, style: const TextStyle(fontSize: 11)), selected: isChecked, selectedColor: themeColor.withOpacity(0.2), checkmarkColor: themeColor, onSelected: (bool selected) { _toggleLocationInVisit(loc.name, selected); }); }).toList()),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(ImageSource.gallery)), ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList()])),
            ]),
          )
        ],
      ),
    );
  }
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