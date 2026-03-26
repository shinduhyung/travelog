// lib/screens/landmark_stats_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 저장 기능을 위해 추가
import 'package:country_flags/country_flags.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';

class CountryLandmarkStats {
  final Country country;
  final int totalLandmarks;
  final int visitedLandmarks;
  final double visitedPercentage;

  CountryLandmarkStats({
    required this.country,
    required this.totalLandmarks,
    required this.visitedLandmarks,
  }) : visitedPercentage = (totalLandmarks > 0) ? (visitedLandmarks / totalLandmarks * 100) : 0.0;
}

class AttributeStatData {
  final String name;
  final int visitedCount;
  final int totalCount;
  final double percentage;

  AttributeStatData({
    required this.name,
    required this.visitedCount,
    required this.totalCount,
  }) : percentage = (totalCount > 0) ? (visitedCount / totalCount * 100) : 0.0;
}

class LandmarkStatsScreen extends StatefulWidget {
  const LandmarkStatsScreen({super.key});

  static final List<Map<String, Object>> continentsData = [
    {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': Color(0xFFF48FB1)},
    {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': Color(0xFFFFC107)},
    {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': Color(0xFF795548)},
    {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': Color(0xFF90CAF9)},
    {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': Color(0xFF4CAF50)},
    {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': Color(0xFF9C27B0)},
  ];

  @override
  State<LandmarkStatsScreen> createState() => _LandmarkStatsScreenState();
}

class _LandmarkStatsScreenState extends State<LandmarkStatsScreen> {
  // 모든 메뉴 파일의 속성을 통합한 리스트
  final Map<String, List<String>> _attributeGroups = {
    'Cultural': [
      'Ancient Site', 'Modern History', 'Archaeological Site', 'Traditional Village',
      'Castle', 'Palace', 'Modern Architecture', 'Tower', 'Skyscraper',
      'Bridge', 'Gate', 'Christian', 'Islamic', 'Buddhist', 'Hindu', 'Other Religion',
      'Tomb', 'Museum', 'Historical Square', 'Old Town', 'Urban Hub', 'University',
      'Market', 'Statue', 'Park', 'Garden', 'Harbor'
    ],
    'Natural': [
      'Sea', 'Beach', 'River', 'Lake', 'Falls', 'Island', 'Mountain',
      'Desert', 'Volcano', 'Canyon', 'Cave', 'Geothermal', 'Glacier',
      'Jungle', 'Unique Landscape'
    ],
    'Activities': [
      'Painting', 'Artwork', 'Library', 'Bookstore', 'Filming Location',
      'Theater', 'Performing Art', 'Food', 'Restaurant', 'Brewery', 'Winery',
      'Cafe', 'Fast Food', 'Festival', 'Event', 'Amusement Park',
      'Football Stadium', 'Zoo', 'Aquarium', 'Cruise Tour', 'Cable Car'
    ]
  };

  late Set<String> _selectedAttributes;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _selectedAttributes = {};
    _loadSavedFilters(); // 저장된 필터 불러오기
  }

  // SharedPreferences에서 필터 설정 불러오기
  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('stat_selected_attributes');

    setState(() {
      if (savedList != null) {
        // 1. 저장된 값이 있다면 그것을 사용
        _selectedAttributes = savedList.toSet();
      } else {
        // 2. 저장된 값이 없다면(최초 실행) 기본 로직 적용
        // Cultural: 모두 포함
        _selectedAttributes.addAll(_attributeGroups['Cultural']!);

        // Natural: Sea, River, Jungle 제외하고 포함
        for (var attr in _attributeGroups['Natural']!) {
          if (attr != 'Sea' && attr != 'River' && attr != 'Jungle') {
            _selectedAttributes.add(attr);
          }
        }

        // Activities: 기본적으로 모두 제외 (아무것도 추가하지 않음)
      }
      _isInit = true;
    });
  }

  // 필터 변경 시 저장
  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('stat_selected_attributes', _selectedAttributes.toList());
  }

  void _showFilterSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Text('Select Landmark Types', style: TextStyle(fontWeight: FontWeight.w800)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _attributeGroups.entries.map((group) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                  group.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 16,
                                  )
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: group.value.map((attr) {
                                final isSelected = _selectedAttributes.contains(attr);
                                return FilterChip(
                                  label: Text(attr, style: const TextStyle(fontSize: 12)),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) _selectedAttributes.add(attr);
                                      else _selectedAttributes.remove(attr);
                                    });
                                    _saveFilters(); // 변경 즉시 저장
                                    setDialogState(() {});
                                  },
                                );
                              }).toList(),
                            ),
                            const Divider(height: 30),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나 아직 설정을 불러오지 못했으면 로딩 표시
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final landmarksProvider = context.watch<LandmarksProvider>();
    final countryProvider = context.watch<CountryProvider>();

    if (landmarksProvider.isLoading || countryProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final visitedLandmarksSet = landmarksProvider.visitedLandmarks;
    final allRawLandmarks = landmarksProvider.allLandmarks;

    // 선택된 속성이 하나라도 포함된 랜드마크만 필터링
    final List<Landmark> targetLandmarks = allRawLandmarks.where((l) {
      return l.attributes.any((attr) => _selectedAttributes.contains(attr));
    }).toList();

    final int totalLandmarks = targetLandmarks.length;
    final int visitedLandmarksCount = targetLandmarks
        .where((l) => visitedLandmarksSet.contains(l.name))
        .length;

    final List<CountryLandmarkStats> statsList = _calculateCountryStats(
      landmarks: targetLandmarks,
      visitedSet: visitedLandmarksSet,
      countries: countryProvider.allCountries,
    );

    final Map<String, int> totalCountPerAttribute = {};
    final Map<String, int> visitedCountPerAttribute = {};
    final Set<String> allAttributes = {};

    final visitedTargetLandmarks = targetLandmarks
        .where((l) => visitedLandmarksSet.contains(l.name));
    final int totalVisitedItems = visitedTargetLandmarks.length;

    // 통계 계산: 선택된 Attribute에 대해서만 카운트
    for (final landmark in targetLandmarks) {
      for (final attr in landmark.attributes) {
        if (_selectedAttributes.contains(attr)) {
          allAttributes.add(attr);
          totalCountPerAttribute[attr] = (totalCountPerAttribute[attr] ?? 0) + 1;
        }
      }
    }

    for (final landmark in visitedTargetLandmarks) {
      for (final attr in landmark.attributes) {
        if (_selectedAttributes.contains(attr)) {
          visitedCountPerAttribute[attr] = (visitedCountPerAttribute[attr] ?? 0) + 1;
        }
      }
    }

    final List<AttributeStatData> attributeStatsList = [];
    for (final attr in allAttributes) {
      if ((totalCountPerAttribute[attr] ?? 0) > 0) {
        attributeStatsList.add(AttributeStatData(
          name: attr,
          visitedCount: visitedCountPerAttribute[attr] ?? 0,
          totalCount: totalCountPerAttribute[attr] ?? 0,
        ));
      }
    }

    final visitedCountryNames = countryProvider.visitedCountries;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 80.0),
          child: Column(
            children: [
              _buildCreativeHeader(
                context: context,
                visited: visitedLandmarksCount,
                total: totalLandmarks,
                color: primaryColor,
              ),
              const SizedBox(height: 24),
              _LandmarkRankingCard(
                key: const ValueKey('all_ranking'),
                countryStats: statsList,
                visitedCountryNames: visitedCountryNames,
                onSettingsPressed: _showFilterSettings,
              ),
              const SizedBox(height: 24),
              _SiteRankingCard(
                key: const ValueKey('landmark_site_ranking'),
                landmarks: targetLandmarks,
              ),
              const SizedBox(height: 24),
              _AttributeStatsCard(
                attributeStats: attributeStatsList,
                visitedAttributeCounts: visitedCountPerAttribute,
                totalVisitedItems: totalVisitedItems,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),
              _LandmarkBrowserCard(selectedAttributes: _selectedAttributes),
            ],
          ),
        ),
      ),
    );
  }

  List<CountryLandmarkStats> _calculateCountryStats({
    required List<Landmark> landmarks,
    required Set<String> visitedSet,
    required List<Country> countries,
  }) {
    final Map<String, int> totalByCountry = {};
    for (final landmark in landmarks) {
      for (final countryCode in landmark.countriesIsoA3) {
        totalByCountry[countryCode] = (totalByCountry[countryCode] ?? 0) + 1;
      }
    }
    final Map<String, int> visitedByCountry = {};
    for (final landmark in landmarks.where((l) => visitedSet.contains(l.name))) {
      for (final countryCode in landmark.countriesIsoA3) {
        visitedByCountry[countryCode] = (visitedByCountry[countryCode] ?? 0) + 1;
      }
    }

    final List<CountryLandmarkStats> statsList = [];
    for (final country in countries) {
      final isoA3 = country.isoA3;
      final total = totalByCountry[isoA3] ?? 0;
      if (total > 0) {
        final visited = visitedByCountry[isoA3] ?? 0;
        statsList.add(CountryLandmarkStats(
          country: country,
          totalLandmarks: total,
          visitedLandmarks: visited,
        ));
      }
    }
    return statsList;
  }

  Widget _buildCreativeHeader({
    required BuildContext context,
    required int visited,
    required int total,
    required Color color,
  }) {
    final double percentage = total > 0 ? (visited / total) : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DISCOVERY STATUS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[400],
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(percentage * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      NumberFormat.decimalPattern('en_US').format(visited),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ ${NumberFormat.decimalPattern('en_US').format(total)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 12,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

Widget _buildRankBadge(int rank) {
  Color bgColor = Colors.grey[100]!;
  Color textColor = Colors.grey[600]!;
  if (rank == 1) {
    bgColor = const Color(0xFFFFD700).withOpacity(0.2);
    textColor = const Color(0xFFB8860B);
  } else if (rank == 2) {
    bgColor = const Color(0xFFC0C0C0).withOpacity(0.2);
    textColor = const Color(0xFF708090);
  } else if (rank == 3) {
    bgColor = const Color(0xFFCD7F32).withOpacity(0.2);
    textColor = const Color(0xFF8B4513);
  }

  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: bgColor,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      rank.toString(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: textColor,
      ),
    ),
  );
}

class _LandmarkRankingCard extends StatefulWidget {
  final List<CountryLandmarkStats> countryStats;
  final Set<String> visitedCountryNames;
  final VoidCallback onSettingsPressed;

  const _LandmarkRankingCard({
    super.key,
    required this.countryStats,
    required this.visitedCountryNames,
    required this.onSettingsPressed,
  });

  @override
  State<_LandmarkRankingCard> createState() => _LandmarkRankingCardState();
}

class _LandmarkRankingCardState extends State<_LandmarkRankingCard> {
  final List<String> _sortMetrics = ['By Visit Count', 'By Visit Percentage', 'By Number of Sites'];
  late String _sortMetric;
  int _displaySegment = 0;
  int _sortOrderSegment = 0;
  List<CountryLandmarkStats> _rankedList = [];

  @override
  void initState() {
    super.initState();
    _sortMetric = _sortMetrics.first;
    _prepareList();
  }

  void _prepareList() {
    List<CountryLandmarkStats> listToRank = _displaySegment == 0
        ? List.from(widget.countryStats)
        : widget.countryStats.where((s) => widget.visitedCountryNames.contains(s.country.name)).toList();

    listToRank.sort((a, b) {
      num valA, valB;
      switch (_sortMetric) {
        case 'By Visit Percentage': valA = a.visitedPercentage; valB = b.visitedPercentage; break;
        case 'By Number of Sites': valA = a.totalLandmarks; valB = b.totalLandmarks; break;
        default: valA = a.visitedLandmarks; valB = b.visitedLandmarks;
      }
      int compare = valA.compareTo(valB);
      return compare == 0 ? a.country.name.compareTo(b.country.name) : compare;
    });

    _rankedList = _sortOrderSegment == 0 ? listToRank.reversed.toList() : listToRank;
    if(mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _LandmarkRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareList();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF3B82F6);
    final Map<String, Color> continentColors = {
      for (var data in LandmarkStatsScreen.continentsData)
        data['fullName'] as String: data['color'] as Color
    };

    // Calculate maximum values for normalization
    int maxVisited = 0;
    int maxTotal = 0;
    for (var s in _rankedList) {
      if (s.visitedLandmarks > maxVisited) maxVisited = s.visitedLandmarks;
      if (s.totalLandmarks > maxTotal) maxTotal = s.totalLandmarks;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.leaderboard_rounded, color: primaryBlue),
                        SizedBox(width: 12),
                        Text('Country Rankings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                      ],
                    ),
                    IconButton(
                      onPressed: widget.onSettingsPressed,
                      icon: Icon(Icons.settings, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sortMetric,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: _sortMetrics.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) { if (v != null) { setState(() { _sortMetric = v; _prepareList(); }); } },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SegmentedButton<int>(showSelectedIcon: false, segments: const [ButtonSegment(value: 0, label: Text('All')), ButtonSegment(value: 1, label: Text('Visited'))], selected: {_displaySegment}, onSelectionChanged: (s) { _displaySegment = s.first; _prepareList(); })),
                    const SizedBox(width: 8),
                    Expanded(child: SegmentedButton<int>(showSelectedIcon: false, segments: const [ButtonSegment(value: 0, label: Text('High')), ButtonSegment(value: 1, label: Text('Low'))], selected: {_sortOrderSegment}, onSelectionChanged: (s) { _sortOrderSegment = s.first; _prepareList(); })),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 400,
            child: _rankedList.isEmpty
                ? const Center(child: Text('No data found.'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final stat = _rankedList[index];
                final barColor = continentColors[stat.country.continent] ?? primaryBlue;

                // Determine progressValue based on sort metric
                double progressValue;
                if (_sortMetric == 'By Visit Percentage') {
                  progressValue = stat.totalLandmarks > 0 ? stat.visitedLandmarks / stat.totalLandmarks : 0.0;
                } else if (_sortMetric == 'By Number of Sites') {
                  progressValue = maxTotal > 0 ? stat.totalLandmarks / maxTotal : 0.0;
                } else {
                  // By Visit Count
                  progressValue = maxVisited > 0 ? stat.visitedLandmarks / maxVisited : 0.0;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _buildRankBadge(index + 1),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(stat.country.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                                Row(
                                  children: [
                                    Text(
                                      _sortMetric == 'By Visit Percentage' ? '${stat.visitedPercentage.toStringAsFixed(1)}%' : '${stat.visitedLandmarks}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('(${stat.visitedLandmarks}/${stat.totalLandmarks})', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor: const Color(0xFFF3F4F6),
                                color: barColor,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRankingCard extends StatefulWidget {
  final List<Landmark> landmarks;
  const _SiteRankingCard({super.key, required this.landmarks});

  @override
  State<_SiteRankingCard> createState() => _SiteRankingCardState();
}

class _SiteRankingCardState extends State<_SiteRankingCard> {
  static const String _sortByVisits = 'By Number of Visits';
  static const String _sortByRating = 'By Ratings';
  final List<String> _sortMetrics = [_sortByVisits, _sortByRating];
  late String _sortMetric;
  List<Landmark> _rankedList = [];

  @override
  void initState() {
    super.initState();
    _sortMetric = _sortMetrics.first;
    _prepareList();
  }

  void _prepareList() {
    List<Landmark> filteredList;
    if (_sortMetric == _sortByVisits) {
      filteredList = widget.landmarks.where((l) => l.visitDates.isNotEmpty).toList()..sort((a, b) => b.visitDates.length.compareTo(a.visitDates.length));
    } else {
      filteredList = widget.landmarks.where((l) => l.rating != null && l.rating! > 0).toList()..sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
    }
    if (mounted) setState(() => _rankedList = filteredList);
  }

  @override
  void didUpdateWidget(covariant _SiteRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareList();
  }

  // Helper Methods for Landmark Details Modal
  bool _isItemCategory(Landmark item, String category) => item.attributes.contains(category);

  bool _isItemNatural(Landmark item) {
    return item.attributes.any((a) => [
      'Mountain', 'Waterfall', 'Falls', 'River', 'Lake', 'Sea', 'Beach', 'Island', 'Unique Landscape'
    ].contains(a));
  }

  String _getMetricText(Landmark item) {
    final fmt = NumberFormat('#,###');
    if (_isItemCategory(item, 'Mountain') || item.attributes.contains('Falls') || item.attributes.contains('Waterfall')) {
      if (item.height != null) return '${fmt.format(item.height)} m';
    } else if (_isItemCategory(item, 'River')) {
      if (item.length != null) return '${item.length} km';
    } else if (_isItemCategory(item, 'Lake')) {
      if (item.area != null) return '${fmt.format(item.area)} km²';
    }
    return '';
  }

  String? _getDisplayIsoA2(Landmark site, CountryProvider countryProvider) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.city.contains('Hong Kong') || site.countriesIsoA3.contains('HKG')) return 'HK';
    if (site.countriesIsoA3.contains('GRL')) return 'GL';
    if (site.countriesIsoA3.contains('PYF')) return 'PF';
    if (site.countriesIsoA3.contains('PRI')) return 'PR';
    if (site.countriesIsoA3.contains('BMU')) return 'BM';
    if (site.countriesIsoA3.contains('GIB')) return 'GI';
    if (site.countriesIsoA3.contains('PCN')) return 'PN';

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

  Widget _buildInfoText(String title, String content, Color themeColor) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
          const SizedBox(height: 4),
          Text(content, style: TextStyle(color: Colors.grey[800], height: 1.4)),
          const SizedBox(height: 16)
        ]
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount = freshLandmark.locations?.length ?? 0;

        String locationDisplay = countryNames;
        if (_isItemNatural(freshLandmark)) {
          locationDisplay = countryNames;
        }
        else if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        if (_isItemCategory(freshLandmark, 'Filming Location') && freshLandmark.location != null) {
          locationDisplay += ' (${freshLandmark.location})';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (e) {
            landmarkThemeColor = null;
          }
        }

        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        const headerTextColor = Colors.white;

        Widget? customHeaderWidget;

        if ((_isItemCategory(freshLandmark, 'Brewery') && freshLandmark.brand != null) ||
            (_isItemCategory(freshLandmark, 'Football Stadium') && freshLandmark.team != null)) {

          final text = _isItemCategory(freshLandmark, 'Football Stadium')
              ? freshLandmark.team!
              : freshLandmark.brand!;

          final openedText = (_isItemCategory(freshLandmark, 'Football Stadium') && freshLandmark.opened != null)
              ? "Opened ${freshLandmark.opened}"
              : null;

          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: headerTextColor.withOpacity(0.6), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
                if (openedText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      openedText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: headerTextColor.withOpacity(0.9),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        else if (_isItemCategory(freshLandmark, 'Filming Location')) {
          List<String> subInfos = [];
          if (freshLandmark.director != null) subInfos.add('Directed by ${freshLandmark.director}');
          if (freshLandmark.releaseDate != null) subInfos.add(freshLandmark.releaseDate!);

          if (subInfos.isNotEmpty) {
            customHeaderWidget = Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                subInfos.join(' • '),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: headerTextColor.withOpacity(0.9),
                    fontStyle: FontStyle.italic
                ),
              ),
            );
          }
        }
        else if (_isItemCategory(freshLandmark, 'Festival') && freshLandmark.month != null) {
          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              freshLandmark.month!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: headerTextColor.withOpacity(0.95),
              ),
            ),
          );
        }
        else if (_isItemCategory(freshLandmark, 'Fast Food')) {
          String text = "";
          if (freshLandmark.type != null) text += freshLandmark.type!;
          if (freshLandmark.numberOfLocations != null) {
            String locText = "${NumberFormat('#,###').format(freshLandmark.numberOfLocations)} locations";
            if (text.isNotEmpty) {
              text += " • $locText";
            } else {
              text = locText;
            }
          }
          if (text.isNotEmpty) {
            customHeaderWidget = Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: headerTextColor.withOpacity(0.95),
                ),
              ),
            );
          }
        }
        else if (freshLandmark.type != null && freshLandmark.type!.isNotEmpty) {
          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              freshLandmark.type!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: headerTextColor.withOpacity(0.95),
              ),
            ),
          );
        }

        String metricLabel = _getMetricText(freshLandmark);

        String? modalFlagIso = _getDisplayIsoA2(freshLandmark, countryProvider);
        List<String> displayIsos = [];

        // Sort countries to ensure China (CHN) comes first visually
        final List<String> sortedIsoA3 = List.from(freshLandmark.countriesIsoA3)
          ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

        if (modalFlagIso == null || sortedIsoA3.length > 1) {
          for (var isoA3 in sortedIsoA3) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
            if (c != null) displayIsos.add(c.isoA2);
          }
        } else {
          displayIsos = [modalFlagIso];
        }

        String displayTitle = freshLandmark.name;
        if (_isItemCategory(freshLandmark, 'Cafe') && freshLandmark.opened != null) {
          displayTitle += ' (${freshLandmark.opened})';
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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      // Base theme color gradient
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                themeColor,
                                themeColor.withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Dark gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content
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
                                    displayTitle,
                                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                if (isVisited || visitedSubCount > 0)
                                  const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                              ],
                            ),
                            if (metricLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  metricLabel,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor.withOpacity(0.95),
                                  ),
                                ),
                              ),

                            if (customHeaderWidget != null) customHeaderWidget,

                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationDisplay,
                                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                      color: headerTextColor.withOpacity(0.8),
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isItemCategory(freshLandmark, 'Painting') || _isItemCategory(freshLandmark, 'Artwork')) ...[
                            if (freshLandmark.artist != null) Text(freshLandmark.artist!, style: Theme.of(sheetContext).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 32)),
                            if (freshLandmark.created != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(freshLandmark.created!, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(color: Colors.black54, fontStyle: FontStyle.italic))),
                            if (freshLandmark.museum != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(Icons.museum_outlined, color: themeColor, size: 20), const SizedBox(width: 8), Text(freshLandmark.museum!, style: Theme.of(sheetContext).textTheme.titleMedium)])),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1)),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                              Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                            ],
                          ),
                          const Divider(height: 20),

                          if (totalSubCount > 1) ...[
                            Text("Components / Locations",
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: freshLandmark.locations!.map((loc) {
                                  final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                  return CheckboxListTile(
                                    title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                    value: isLocVisited,
                                    activeColor: themeColor,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (val) {
                                      provider.toggleSubLocation(freshLandmark.name, loc.name);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const Divider(height: 24),
                          ],

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name))]),
                          const SizedBox(height: 8),
                          if (freshLandmark.visitDates.isNotEmpty) ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                            key: ValueKey('${freshLandmark.name}_${entry.key}'),
                            landmarkName: freshLandmark.name,
                            visitDate: entry.value,
                            index: entry.key,
                            onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                            availableLocations: freshLandmark.locations,
                          )) else const Center(child: Text('No visits recorded.')),
                          const Divider(height: 24),

                          if (_isItemCategory(freshLandmark, 'Food')) ...[
                            if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                            if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                            if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                          ]
                          else if (_isItemCategory(freshLandmark, 'Restaurant')) ...[
                            if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                            if (freshLandmark.bestDishes != null) _buildInfoText('Best Dishes', freshLandmark.bestDishes!, themeColor),
                            if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                          ]
                          else if (_isItemCategory(freshLandmark, 'Festival')) ...[
                              if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                              if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                            ]
                            else if (_isItemCategory(freshLandmark, 'Football Stadium')) ...[
                                if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                              ]
                              else if (_isItemCategory(freshLandmark, 'Brewery')) ...[
                                  if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                                  if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                ]
                                else if (_isItemCategory(freshLandmark, 'Fast Food')) ...[
                                    if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                  ]
                                  else if (_isItemCategory(freshLandmark, 'Cafe')) ...[
                                      if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                      if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                    ]
                                    else if (_isItemNatural(freshLandmark)) ...[
                                        if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                        if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                      ]
                                      else if (_isItemCategory(freshLandmark, 'Filming Location')) ...[
                                          if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                          if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                        ]
                                        else ...[
                                            LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber),
                    SizedBox(width: 12),
                    Text('Top Landmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _sortMetric,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: _sortMetrics.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) { if (v != null) { setState(() { _sortMetric = v; _prepareList(); }); } },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            child: _rankedList.isEmpty
                ? const Center(child: Text('No data available.'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final landmark = _rankedList[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: _buildRankBadge(index + 1),
                  title: Text(landmark.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: _sortMetric == _sortByRating
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                    RatingBarIndicator(rating: landmark.rating ?? 0.0, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 14.0),
                    const SizedBox(width: 4),
                    Text((landmark.rating ?? 0).toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ])
                      : Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${landmark.visitDates.length} visits', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)))),
                  onTap: () => _showLandmarkDetailsModal(context, landmark, Theme.of(context).primaryColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeStatsCard extends StatelessWidget {
  final List<AttributeStatData> attributeStats;
  final Map<String, int> visitedAttributeCounts;
  final int totalVisitedItems;
  final Color primaryColor;

  const _AttributeStatsCard({required this.attributeStats, required this.visitedAttributeCounts, required this.totalVisitedItems, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final visitedEntries = visitedAttributeCounts.entries.toList()..removeWhere((e) => e.value == 0)..sort((a, b) => b.value.compareTo(a.value));
    final int maxVisitedCount = visitedEntries.isNotEmpty ? visitedEntries.first.value : 1;
    final int totalVisitedAttributes = visitedEntries.fold(0, (sum, e) => sum + e.value);
    final progressEntries = List<AttributeStatData>.from(attributeStats)..sort((a, b) => b.percentage.compareTo(a.percentage));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(children: [Icon(Icons.pie_chart_rounded, color: Color(0xFF10B981)), SizedBox(width: 12), Text('Attribute Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Visit Count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: visitedEntries.isEmpty ? const Center(child: Text('No data.')) : ListView.builder(itemCount: visitedEntries.length, itemBuilder: (ctx, i) {
                    final e = visitedEntries[i];
                    return _buildStatRow(label: e.key, value: e.value, maxValue: maxVisitedCount, info: '${(e.value / totalVisitedAttributes * 100).toStringAsFixed(1)}%', color: const Color(0xFF10B981));
                  }),
                ),
                const SizedBox(height: 32),
                const Text('Visit Progress (%)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: progressEntries.isEmpty ? const Center(child: Text('No attributes found.')) : ListView.builder(itemCount: progressEntries.length, itemBuilder: (ctx, i) {
                    final s = progressEntries[i];
                    return _buildStatRow(label: s.name, value: s.visitedCount, maxValue: s.totalCount, info: '${s.percentage.toStringAsFixed(1)}%', color: primaryColor);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({required String label, required int value, required int maxValue, required String info, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))), Text('$value ($info)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)))]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (ctx, constraints) => Stack(children: [
          Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(3))),
          Container(height: 6, width: constraints.maxWidth * (maxValue > 0 ? value / maxValue : 0), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        ])),
      ]),
    );
  }
}

class _LandmarkBrowserCard extends StatefulWidget {
  final Set<String> selectedAttributes;
  const _LandmarkBrowserCard({super.key, required this.selectedAttributes});

  @override
  State<_LandmarkBrowserCard> createState() => _LandmarkBrowserCardState();
}

class _LandmarkBrowserCardState extends State<_LandmarkBrowserCard> {
  String? _selectedContinent;
  String? _selectedCountryIsoA3;
  bool _sortAlphabetically = false;

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CountryProvider>();
    final lp = context.watch<LandmarksProvider>();
    final continents = LandmarkStatsScreen.continentsData.map((d) => d['fullName'] as String).toList();
    final countries = _selectedContinent == null ? <Country>[] : cp.allCountries.where((c) => c.continent == _selectedContinent).toList()..sort((a, b) => a.name.compareTo(b.name));
    final landmarks = _selectedCountryIsoA3 == null ? <Landmark>[] : lp.allLandmarks.where((l) => l.countriesIsoA3.contains(_selectedCountryIsoA3) && l.attributes.any((a) => widget.selectedAttributes.contains(a))).toList();
    if (_sortAlphabetically) landmarks.sort((a, b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.travel_explore_rounded, color: Color(0xFF6366F1)),
                    SizedBox(width: 12),
                    Text('Landmark Explorer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedContinent,
                  isExpanded: true,
                  hint: const Text('Select Continent'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: continents.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) { setState(() { _selectedContinent = v; _selectedCountryIsoA3 = null; }); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCountryIsoA3,
                  isExpanded: true,
                  hint: const Text('Select Country'),
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  disabledHint: Text(_selectedContinent == null ? 'Select continent first' : 'No countries'),
                  items: countries.map((c) => DropdownMenuItem(value: c.isoA3, child: Text(c.name))).toList(),
                  onChanged: countries.isEmpty ? null : (v) { setState(() { _selectedCountryIsoA3 = v; }); },
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: SegmentedButton<bool>(showSelectedIcon: false, segments: const [ButtonSegment(value: false, label: Text('Default')), ButtonSegment(value: true, label: Text('Alphabet'))], selected: {_sortAlphabetically}, onSelectionChanged: (s) { setState(() { _sortAlphabetically = s.first; }); })),
              ],
            ),
          ),
          const Divider(height: 1),
          if (landmarks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(children: landmarks.map((l) {
                final isVisited = lp.visitedLandmarks.contains(l.name);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InkWell(
                    onTap: () async {
                      if (isVisited) {
                        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirm Removal'), content: Text('Remove all records for ${l.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red)))]));
                        if (confirm == true) lp.toggleVisitedStatus(l.name);
                      } else { lp.toggleVisitedStatus(l.name); }
                    },
                    child: Icon(isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isVisited ? const Color(0xFF10B981) : const Color(0xFFD1D5DB), size: 26),
                  ),
                  title: Text(l.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                );
              }).toList()),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// 랜드마크 방문 기록 에디터 카드 추가
class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    this.availableLocations,
  });

  @override
  State<_LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;
  late String _displayTitle, _displayMemo;
  bool _isEditing = false;
  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo  = widget.visitDate.memo ?? '';
    _titleController = TextEditingController(text: _displayTitle);
    _memoController  = TextEditingController(text: _displayMemo);
    _currentPhotos   = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) _isEditing = true;
  }

  @override void dispose() { _titleController.dispose(); _memoController.dispose(); super.dispose(); }

  void _saveChanges() {
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName, widget.index,
      title: _titleController.text, memo: _memoController.text,
      year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999,
      photos: _currentPhotos,
    );
    setState(() { _displayTitle = _titleController.text; _displayMemo = _memoController.text; _isEditing = false; });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle; _memoController.text = _displayMemo;
      _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos); _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final p = await showDatePicker(context: context,
        initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
        firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (p != null && mounted) setState(() { _year = p.year; _month = p.month; _day = p.day; });
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
  }

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<LandmarksProvider>();
    List<String> currentDetails = List.from(widget.visitDate.visitedDetails);
    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.landmarkName, locName)) {
          provider.toggleSubLocation(widget.landmarkName, locName);
        }
      }
    } else {
      currentDetails.remove(locName);
    }
    provider.updateLandmarkVisit(widget.landmarkName, widget.index, visitedDetails: currentDetails);
    setState(() {});
  }

  Widget _buildPhotoPreview(String path, int i) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover))),
      if (_isEditing) Positioned(top: -6, right: 6,
          child: GestureDetector(onTap: () => setState(() => _currentPhotos.removeAt(i)),
              child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 22)))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(_displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Visit Record'),
              content: const Text('Are you sure you want to delete this visit record?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ])),
        ),
        children: [Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isEditing) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Visit Date: $_year-$_month-$_day',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: _memoController, maxLines: 3, minLines: 1,
                  decoration: InputDecoration(labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            ] else if (_displayMemo.isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_displayMemo, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4))),

            const SizedBox(height: 12),

            if (widget.availableLocations != null && widget.availableLocations!.length > 1) ...[
              const Text("Locations included in this visit:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              IgnorePointer(
                ignoring: !_isEditing,
                child: Wrap(spacing: 8.0, runSpacing: 4.0,
                    children: widget.availableLocations!.map((loc) {
                      final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                      return FilterChip(
                        label: Text(loc.name, style: const TextStyle(fontSize: 11)),
                        selected: isChecked,
                        selectedColor: themeColor.withOpacity(0.2),
                        checkmarkColor: themeColor,
                        onSelected: (bool selected) => _toggleLocationInVisit(loc.name, selected),
                      );
                    }).toList()),
              ),
              const SizedBox(height: 16),
            ],

            if (_currentPhotos.isNotEmpty || _isEditing)
              Padding(padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none,
                      child: Row(children: [
                        if (_isEditing) Container(margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)),
                            child: IconButton(icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                onPressed: () => _pickImage(ImageSource.gallery))),
                        ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                      ]))),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_isEditing) ...[
                TextButton(onPressed: _cancelEditing,
                    child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _saveChanges,
                    icon: const Icon(Icons.save, size: 18), label: const Text('Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0)),
              ] else
                OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(foregroundColor: themeColor,
                        side: BorderSide(color: themeColor.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}