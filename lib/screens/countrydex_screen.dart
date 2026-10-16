// lib/screens/countrydex_screen.dart

import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortOption {
  alphabet,
  continent,
  visitCount,
  visitOrder,
  visitDuration,
  favorites,
}

class CountryDexScreen extends StatefulWidget {
  const CountryDexScreen({super.key});

  @override
  State<CountryDexScreen> createState() => _CountryDexScreenState();
}

class _CountryDexScreenState extends State<CountryDexScreen> {
  // Default Sort Option
  SortOption _sortOption = SortOption.visitCount;
  bool _visitOrderIsNewestFirst = true; // Default: Newest first
  String _searchQuery = ''; // Search query state

  // Controller to manage the text inside the search bar
  final TextEditingController _searchController = TextEditingController();

  // SharedPreferences Keys
  static const _sortOptionKey = 'countryDexSortOption';
  static const _visitOrderDirectionKey = 'countryDexVisitOrderDirection';

  // Mint Theme Colors
  static const Color mintPrimary = Color(0xFF4ECDC4);
  static const Color mintLight = Color(0xFF95E1D3);
  static const Color mintDark = Color(0xFF2C9A92);
  static const Color mintBackground = Color(0xFFF0FDFC);
  static const Color mintCard = Color(0xFFE0F9F6);

  // 국가(iso_a2) → 주/도 목록. 이름 옆 "x/y" 방문 지역 표시용.
  Map<String, List<AdminRegion>> _regionsByIsoA2 = {};

  @override
  void initState() {
    super.initState();
    _loadSortOption(); // Load saved sort option
    AdminRegionRepository.loadAll().then((regions) {
      if (mounted) {
        setState(
          () => _regionsByIsoA2 = regions.map(
            (iso, list) =>
                MapEntry(iso, list.where((r) => !r.isWholeArea).toList()),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller when screen is closed
    super.dispose();
  }

  // Function to load saved sort options
  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultSortIndex =
        prefs.getInt(_sortOptionKey) ?? SortOption.visitCount.index;
    final defaultVisitOrderDirection =
        prefs.getBool(_visitOrderDirectionKey) ?? true;

    if (mounted) {
      setState(() {
        _sortOption = SortOption.values[defaultSortIndex];
        _visitOrderIsNewestFirst = defaultVisitOrderDirection;
      });
    }
  }

  // Function to save sort options
  Future<void> _saveSortOption(SortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortOptionKey, option.index);
  }

  // Function to save visit order direction
  Future<void> _saveVisitOrderDirection(bool isNewestFirst) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visitOrderDirectionKey, isNewestFirst);
  }

  int _calculateTotalVisitDays(VisitDetails? details) {
    if (details == null || details.visitDateRanges.isEmpty) {
      return 0;
    }
    int totalDays = 0;
    for (var range in details.visitDateRanges) {
      if (range.userDefinedDuration != null) {
        totalDays += range.userDefinedDuration!;
        continue;
      }

      final arrival = range.arrival;
      final departure = range.departure;

      if (arrival != null &&
          departure != null &&
          !departure.isBefore(arrival)) {
        totalDays += departure.difference(arrival).inDays + 1;
      }
    }
    return totalDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // 이 부분이 뒤로가기 버튼을 제거합니다.
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [mintPrimary, mintLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'CountryDex',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: mintCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<SortOption>(
              icon: const Icon(Icons.tune_rounded, color: mintDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (SortOption result) {
                setState(() => _sortOption = result);
                _saveSortOption(result);
              },
              itemBuilder: (BuildContext context) => [
                _buildMenuItem(SortOption.alphabet, '🔤 Alphabetical'),
                _buildMenuItem(SortOption.continent, '🌍 By Continent'),
                _buildMenuItem(SortOption.visitCount, '🎯 By Number of Visits'),
                _buildMenuItem(SortOption.visitOrder, '📅 By First Visit Date'),
                _buildMenuItem(
                  SortOption.visitDuration,
                  '⏱️ By Total Visit Days',
                ),
                _buildMenuItem(SortOption.favorites, '❤️ Favorites (Wishlist)'),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // 1. Country Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController, // Attached the controller here
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search Country...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: mintDark),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear(); // Clear the text visually
                        setState(() {
                          _searchQuery = ''; // Reset the search query state
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 20,
              ),
            ),
          ),
        ),

        // 2. Visit Order Sort Direction Button
        if (_sortOption == SortOption.visitOrder)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: mintPrimary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white,
                selectedBackgroundColor: mintPrimary,
                selectedForegroundColor: Colors.white,
                foregroundColor: Colors.grey.shade600,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text(
                    'Newest First',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(
                    'Oldest First',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              selected: {_visitOrderIsNewestFirst},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _visitOrderIsNewestFirst = newSelection.first;
                  _saveVisitOrderDirection(newSelection.first);
                });
              },
            ),
          ),

        // 3. Country List
        Expanded(
          child: Consumer<CountryProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: mintPrimary),
                      const SizedBox(height: 16),
                      Text(
                        'Loading countries...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              // 1st Filtering: Provider's filter + Search Query
              List<Country> countriesToDisplay = provider.filteredCountries
                  .where((c) => c.name.toLowerCase().contains(_searchQuery))
                  .toList();

              final visitDetailsMap = provider.visitDetails;
              final homeCountryIso = provider.homeCountryIsoA3;

              // 2nd Filtering & Sorting: Apply SortOption
              if (_sortOption == SortOption.favorites) {
                final Set<String> wishlistedNames =
                    provider.wishlistedCountries;
                countriesToDisplay = countriesToDisplay
                    .where((c) => wishlistedNames.contains(c.name))
                    .toList();
                countriesToDisplay.sort((a, b) => a.name.compareTo(b.name));
                return _buildListView(
                  countriesToDisplay,
                  visitDetailsMap,
                  homeCountryIso,
                );
              }

              if (_sortOption != SortOption.alphabet) {
                // Grouped Sorting
                return _buildGroupedView(
                  context,
                  provider,
                  countriesToDisplay,
                  _sortOption,
                  homeCountryIso,
                );
              } else {
                // Alphabetical Sorting
                countriesToDisplay.sort((a, b) => a.name.compareTo(b.name));
                return _buildListView(
                  countriesToDisplay,
                  visitDetailsMap,
                  homeCountryIso,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<SortOption> _buildMenuItem(SortOption value, String text) {
    final isSelected = _sortOption == value;
    return PopupMenuItem(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? mintPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? mintPrimary : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? mintDark : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedView(
    BuildContext context,
    CountryProvider provider,
    List<Country> countries,
    SortOption sortOption,
    String? homeCountryIso,
  ) {
    final Map<String, List<Country>> groupedData = {};

    switch (sortOption) {
      case SortOption.continent:
        for (var country in countries) {
          final key = country.continent ?? 'Others';
          groupedData.putIfAbsent(key, () => []).add(country);
        }
        break;

      case SortOption.visitCount:
        for (var country in countries) {
          final details = provider.visitDetails[country.name];
          final isHome = homeCountryIso == country.isoA3;
          final isLived = details?.hasLived ?? false;

          if (isHome || isLived) {
            groupedData.putIfAbsent('Home / Lived', () => []).add(country);
          } else {
            final count = details?.visitCount ?? 0;
            final String key;
            if (count >= 5)
              key = '5+ Visits';
            else if (count >= 2)
              key = '2 - 4 Visits';
            else if (count == 1)
              key = '1 Visit';
            else
              key = 'Unvisited';
            groupedData.putIfAbsent(key, () => []).add(country);
          }
        }
        break;

      case SortOption.visitOrder:
        for (var country in countries) {
          final details = provider.visitDetails[country.name];
          final isHome = homeCountryIso == country.isoA3;
          final isLived = details?.hasLived ?? false;

          // 우선순위 로직: Home 또는 Lived는 별도의 강력한 그룹으로 분류
          if (isHome || isLived) {
            groupedData.putIfAbsent('Living / Lived', () => []).add(country);
          } else if (details == null || details.visitDateRanges.isEmpty) {
            groupedData.putIfAbsent('Unvisited', () => []).add(country);
          } else {
            final allArrivalDates = details.visitDateRanges
                .map((r) => r.arrival)
                .where((d) => d != null)
                .cast<DateTime>()
                .toList();

            if (allArrivalDates.isEmpty) {
              groupedData.putIfAbsent('Unknown Date', () => []).add(country);
            } else {
              allArrivalDates.sort();
              final firstVisitDate = allArrivalDates.first;
              final key = firstVisitDate.year.toString();
              groupedData.putIfAbsent(key, () => []).add(country);
            }
          }
        }
        break;

      case SortOption.visitDuration:
        for (var country in countries) {
          final totalDays = _calculateTotalVisitDays(
            provider.visitDetails[country.name],
          );
          final String key;
          if (totalDays >= 30) {
            key = '30+ days';
          } else if (totalDays >= 10) {
            key = '10-29 days';
          } else if (totalDays >= 4) {
            key = '4-9 days';
          } else if (totalDays >= 2) {
            key = '2-3 days';
          } else if (totalDays == 1) {
            key = '1 day';
          } else {
            key = '0 or Unknown';
          }
          groupedData.putIfAbsent(key, () => []).add(country);
        }
        break;
      default:
        break;
    }

    final groupTitles = groupedData.keys.toList();
    switch (sortOption) {
      case SortOption.continent:
        groupTitles.sort();
        break;
      case SortOption.visitCount:
        // 수정됨: Living / Lived를 맨 앞에 추가
        const order = [
          'Living / Lived',
          '5+ Visits',
          '2 - 4 Visits',
          '1 Visit',
          'Unvisited',
        ];
        groupTitles.sort((a, b) {
          final indexA = order.indexOf(a);
          final indexB = order.indexOf(b);
          if (indexA == -1 && indexB == -1) return a.compareTo(b);
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });
        break;
      case SortOption.visitOrder:
        groupTitles.sort((a, b) {
          // Living / Lived는 무조건 맨 위
          if (a == 'Living / Lived') return -1;
          if (b == 'Living / Lived') return 1;

          if (a == 'Unvisited') return 1;
          if (b == 'Unvisited') return -1;
          if (a == 'Unknown Date') return 1;
          if (b == 'Unknown Date') return -1;
          return _visitOrderIsNewestFirst ? b.compareTo(a) : a.compareTo(b);
        });
        break;
      case SortOption.visitDuration:
        const order = [
          '30+ days',
          '10-29 days',
          '4-9 days',
          '2-3 days',
          '1 day',
          '0 or Unknown',
        ];
        groupTitles.sort(
          (a, b) => order.indexOf(a).compareTo(order.indexOf(b)),
        );
        break;
      default:
        break;
    }

    groupedData.forEach((key, value) {
      value.sort((a, b) => a.name.compareTo(b.name));
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupTitles.length,
      itemBuilder: (context, index) {
        final title = groupTitles[index];
        final groupCountries = groupedData[title]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    mintPrimary.withOpacity(0.1),
                    mintLight.withOpacity(0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: mintPrimary, width: 4)),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mintDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: mintPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${groupCountries.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildListView(
              groupCountries,
              provider.visitDetails,
              homeCountryIso,
              isShrunk: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView(
    List<Country> countries,
    Map<String, VisitDetails> visitDetailsMap,
    String? homeCountryIso, {
    bool isShrunk = false,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: isShrunk,
      physics: isShrunk ? const NeverScrollableScrollPhysics() : null,
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final details = visitDetailsMap[country.name];
        return _buildListTile(country, details, homeCountryIso);
      },
    );
  }

  Widget _buildListTile(
    Country country,
    VisitDetails? details,
    String? homeCountryIso,
  ) {
    final flagUrl =
        'https://flagcdn.com/w160/${country.isoA2.toLowerCase()}.png';

    // Status checks
    final isHome = homeCountryIso == country.isoA3;
    final isLived = details?.hasLived ?? false;
    final isVisited = details?.isVisited ?? false;
    final isWishlisted = details?.isWishlisted ?? false;
    final rating = details?.rating ?? 0.0;
    final visitCount = details?.visitCount ?? 0;
    final totalDays = _calculateTotalVisitDays(details);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isVisited || isHome || isLived)
              ? mintPrimary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: (isVisited || isHome || isLived) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isVisited || isHome || isLived)
                ? mintPrimary.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountryDetailScreen(country: country),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Flag Image
                Hero(
                  tag: 'flag-${country.isoA2}',
                  child: Container(
                    width: 64,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Opacity(
                      opacity: isVisited || isWishlisted || isHome || isLived
                          ? 1.0
                          : 0.5,
                      child: Image.network(
                        flagUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: mintPrimary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.flag_outlined,
                            color: Colors.grey[400],
                            size: 28,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Country Info & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Row with Stars
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              country.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: (isVisited || isHome || isLived)
                                    ? Colors.black87
                                    : Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_regionsByIsoA2[country.isoA2]?.isNotEmpty ??
                              false) ...[
                            const SizedBox(width: 6),
                            _buildRegionCountChip(
                              country,
                              _regionsByIsoA2[country.isoA2]!,
                            ),
                          ],
                          if (rating > 0) ...[
                            const SizedBox(width: 8),
                            _buildStarRating(rating),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Status Badges (Modified Logic)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // 1. Home Badge (Highest Priority)
                          if (isHome)
                            _buildBadge(
                              text: 'Home',
                              icon: Icons.home_rounded,
                              backgroundColor: Colors.blue.shade50,
                              contentColor: Colors.blue.shade700,
                            )
                          // 2. Lived Badge (Second Highest Priority)
                          else if (isLived)
                            _buildBadge(
                              text: 'Lived',
                              icon: Icons.apartment_rounded,
                              backgroundColor: Colors.orange.shade50,
                              contentColor: Colors.orange.shade800,
                            )
                          // 3. Visit Record (Only shown if NOT Home AND NOT Lived)
                          else if (isVisited && visitCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    mintPrimary.withOpacity(0.2),
                                    mintLight.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: mintDark,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$visitCount time${visitCount > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mintDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (totalDays > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• $totalDays days',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: mintDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          // 4. Wishlisted
                          else if (isWishlisted && !isVisited)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.pink.shade400,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Wishlisted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.pink.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // 5. Unvisited
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Unvisited',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow only (Rating moved to name row)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: mintCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: mintDark,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 방문한 주/도 수 "x/y" — 0개면 회색, 1개 이상이면 민트색
  Widget _buildRegionCountChip(Country country, List<AdminRegion> regions) {
    return AnimatedBuilder(
      animation: SubscriptionService.instance,
      builder: (context, _) {
        if (!CountryRegionAccess.isUnlocked(country.isoA2)) {
          return InkWell(
            onTap: () => showCountryRegionsPremiumDialog(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12),
                  SizedBox(width: 3),
                  Text('Premium', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          );
        }
        return _buildUnlockedRegionCountChip(country, regions);
      },
    );
  }

  Widget _buildUnlockedRegionCountChip(
    Country country,
    List<AdminRegion> regions,
  ) {
    return Selector<SubregionProvider, int>(
      selector: (_, provider) =>
          provider.visitedRegionCount(country.isoA3, regions),
      builder: (context, visited, _) {
        final active = visited > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active ? mintCard : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 12,
                color: active ? mintDark : Colors.grey.shade500,
              ),
              const SizedBox(width: 3),
              Text(
                '$visited/${regions.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? mintDark : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to build star icons
  Widget _buildStarRating(double rating) {
    int fullStars = rating.round(); // 반올림해서 별 개수 결정
    if (fullStars > 5) fullStars = 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(fullStars, (index) {
        return const Padding(
          padding: EdgeInsets.only(right: 1.0),
          child: Icon(Icons.star, color: Colors.amber, size: 16),
        );
      }),
    );
  }

  Widget _buildBadge({
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color contentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: contentColor, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: contentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
