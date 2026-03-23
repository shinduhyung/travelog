// lib/screens/airlines_list_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/screens/airline_detail_screen.dart';
import 'package:jidoapp/screens/airline_stats_screen.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:ui';

// ⭐️ [수정] 항공사 이름 대신 ICAO (Code3) 코드로 매핑된 Alliance Map 적용
const Map<String, String> airlineAlliances = {
  // SkyTeam
  "AMX": "SkyTeam", // Aeroméxico
  "AEA": "SkyTeam", // Air Europa
  "AFR": "SkyTeam", // Air France
  "CAL": "SkyTeam", // China Airlines
  "CES": "SkyTeam", // China Eastern
  "DAL": "SkyTeam", // Delta Air Lines
  "GIA": "SkyTeam", // Garuda Indonesia
  "KLM": "SkyTeam", // KLM
  "KAL": "SkyTeam", // Korean Air
  "MEA": "SkyTeam", // Middle East Airlines
  "SVA": "SkyTeam", // Saudia
  "SAS": "SkyTeam", // Scandinavian Airlines (SAS)
  "ROT": "SkyTeam", // Tarom
  "HVN": "SkyTeam", // Vietnam Airlines
  "VIR": "SkyTeam", // Virgin Atlantic
  "CXA": "SkyTeam", // Xiamen Airlines
  "KQA": "SkyTeam", // Kenya Airways
  "ARG": "SkyTeam", // Aerolineas Argentinas

  // Star Alliance
  "AEE": "Star Alliance", // Aegean Airlines
  "ACA": "Star Alliance", // Air Canada
  "CCA": "Star Alliance", // Air China
  "AIC": "Star Alliance", // Air India
  "ANZ": "Star Alliance", // Air New Zealand
  "ANA": "Star Alliance", // All Nippon Airways
  "AAR": "Star Alliance", // Asiana Airlines
  "AUA": "Star Alliance", // Austrian Airlines
  "AVA": "Star Alliance", // Avianca
  "BEL": "Star Alliance", // Brussels Airlines
  "CMP": "Star Alliance", // Copa Airlines
  "CTN": "Star Alliance", // Croatia Airlines
  "MSR": "Star Alliance", // EgyptAir
  "ETH": "Star Alliance", // Ethiopian Airlines
  "EVA": "Star Alliance", // EVA Air
  "LOT": "Star Alliance", // LOT Polish Airlines
  "DLH": "Star Alliance", // Lufthansa
  "CSZ": "Star Alliance", // Shenzhen Airlines
  "SIA": "Star Alliance", // Singapore Airlines
  "SAA": "Star Alliance", // South African Airways
  "SWR": "Star Alliance", // SWISS International Air Lines
  "TAP": "Star Alliance", // TAP Air Portugal
  "THA": "Star Alliance", // Thai Airways International
  "THY": "Star Alliance", // Turkish Airlines
  "UAL": "Star Alliance", // United Airlines

  // OneWorld
  "ASA": "OneWorld", // Alaska Airlines
  "AAL": "OneWorld", // American Airlines
  "BAW": "OneWorld", // British Airways
  "CPA": "OneWorld", // Cathay Pacific
  "FJI": "OneWorld", // Fiji Airways
  "FIN": "OneWorld", // Finnair
  "IBE": "OneWorld", // Iberia
  "JAL": "OneWorld", // Japan Airlines
  "MAS": "OneWorld", // Malaysia Airlines
  "OMA": "OneWorld", // Oman Air
  "QFA": "OneWorld", // Qantas
  "QTR": "OneWorld", // Qatar Airways
  "RAM": "OneWorld", // Royal Air Maroc
  "RJA": "OneWorld"  // Royal Jordanian
};

enum SortOption {
  alphabetical,
  byCounts,
  lastFlightDate,
  byRatings,
  favorites,
}

enum AllianceFilter { all, star, skyteam, oneworld, other }

class AirlinesListScreen extends StatefulWidget {
  const AirlinesListScreen({super.key});

  @override
  State<AirlinesListScreen> createState() => _AirlinesListScreenState();
}

class _AirlinesListScreenState extends State<AirlinesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  SortOption _currentSortOption = SortOption.byCounts;
  bool _showFlownOnly = false;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _showFlownOnly = false;
      _showFavoritesOnly = false;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter sheetSetState) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[400]!, Colors.green[700]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.filter_alt, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'FILTER BY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildModernFilterChip(
                            'Flown Only',
                            Icons.flight_takeoff,
                            _showFlownOnly,
                                (selected) {
                              setState(() => _showFlownOnly = selected);
                              sheetSetState(() => _showFlownOnly = selected);
                            },
                          ),
                          _buildModernFilterChip(
                            'Favorites',
                            Icons.favorite,
                            _showFavoritesOnly,
                                (selected) {
                              setState(() => _showFavoritesOnly = selected);
                              sheetSetState(() => _showFavoritesOnly = selected);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey[300]!, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {
                                _clearAllFilters();
                                sheetSetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildModernFilterChip(
      String label,
      IconData icon,
      bool selected,
      Function(bool) onSelected,
      ) {
    return InkWell(
      onTap: () => onSelected(!selected),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
            colors: [Colors.green[400]!, Colors.green[600]!],
          )
              : null,
          color: selected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.green[700]! : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: Colors.green[800],
      unselectedLabelColor: Colors.grey[500],
      indicatorColor: Colors.green[800],
      indicatorWeight: 4.0,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      tabs: const [
        Tab(text: 'ALL'),
        Tab(text: '★ STAR'),
        Tab(text: '☁ SKYTEAM'),
        Tab(text: '🌍 ONEWORLD'),
        Tab(text: '✈ OTHER'),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 160.0,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                title: const Text(
                  'Airlines',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 28,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green[100]!.withOpacity(0.3),
                        Colors.blue[50]!.withOpacity(0.2),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green[200]!.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue[200]!.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 통계 버튼
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      if (auth.user == null) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const LoginPromptScreen(),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AirlineStatsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'View Statistics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Explore your flight data',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 검색 및 정렬 바
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.grey[50],
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              toolbarHeight: 135,
              titleSpacing: 0,
              title: Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // 검색 바
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search airlines',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 24),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[500]),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 정렬 및 필터 버튼
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<SortOption>(
                                value: _currentSortOption,
                                icon: Icon(Icons.expand_more, color: Colors.grey[600]),
                                isExpanded: true,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: SortOption.alphabetical,
                                    child: Row(
                                      children: [
                                        Icon(Icons.sort_by_alpha, size: 20),
                                        SizedBox(width: 10),
                                        Text('A-Z'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: SortOption.byCounts,
                                    child: Row(
                                      children: [
                                        Icon(Icons.trending_up, size: 20),
                                        SizedBox(width: 10),
                                        Text('Most Flown'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: SortOption.lastFlightDate,
                                    child: Row(
                                      children: [
                                        Icon(Icons.schedule, size: 20),
                                        SizedBox(width: 10),
                                        Text('Recent'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: SortOption.byRatings,
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, size: 20),
                                        SizedBox(width: 10),
                                        Text('Top Rated'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: SortOption.favorites,
                                    child: Row(
                                      children: [
                                        Icon(Icons.favorite, size: 20, color: Colors.pink),
                                        SizedBox(width: 10),
                                        Text('Favorites'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (SortOption? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _currentSortOption = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: (_showFlownOnly || _showFavoritesOnly)
                                ? LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[700]!],
                            )
                                : null,
                            color: (_showFlownOnly || _showFavoritesOnly)
                                ? null
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_showFlownOnly || _showFavoritesOnly)
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.filter_alt,
                              color: (_showFlownOnly || _showFavoritesOnly)
                                  ? Colors.white
                                  : Colors.grey[600],
                              size: 24,
                            ),
                            tooltip: 'Filters',
                            onPressed: _showFilterBottomSheet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 탭바
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(tabBar),
              pinned: true,
            ),
          ];
        },
        body: Consumer<AirlineProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.green[700],
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading airlines...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildAirlineList(context, provider, AllianceFilter.all),
                _buildAirlineList(context, provider, AllianceFilter.star),
                _buildAirlineList(context, provider, AllianceFilter.skyteam),
                _buildAirlineList(context, provider, AllianceFilter.oneworld),
                _buildAirlineList(context, provider, AllianceFilter.other),
              ],
            );
          },
        ),
      ),
    );
  }

  // GridView -> ListView로 변경
  Widget _buildAirlineList(BuildContext context, AirlineProvider provider, AllianceFilter filter) {
    List<Airline> filteredList = provider.airlines.where((airline) {
      bool matchesSearch = _searchQuery.isEmpty ||
          airline.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          airline.code.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesAlliance = true;
      if (filter != AllianceFilter.all) {
        // ⭐️ [수정] airline.name 대신 airline.code3를 사용하여 매칭
        final allianceName = airlineAlliances[airline.code3];
        switch (filter) {
          case AllianceFilter.star:
            matchesAlliance = allianceName == 'Star Alliance';
            break;
          case AllianceFilter.skyteam:
            matchesAlliance = allianceName == 'SkyTeam';
            break;
          case AllianceFilter.oneworld:
            matchesAlliance = allianceName == 'OneWorld';
            break;
          case AllianceFilter.other:
            matchesAlliance = allianceName == null;
            break;
          default:
            matchesAlliance = true;
        }
      }

      bool matchesFlown = !_showFlownOnly || airline.totalTimes > 0;

      bool isFavoriteMode = _showFavoritesOnly || _currentSortOption == SortOption.favorites;
      bool matchesFavorite = !isFavoriteMode || airline.isFavorite;

      return matchesSearch && matchesAlliance && matchesFlown && matchesFavorite;
    }).toList();

    _sortList(filteredList, _currentSortOption);

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No airlines found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // ListView.separated를 사용하여 리스트 형태로 출력
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildAirlineListCard(context, filteredList[index], provider);
      },
    );
  }

  void _sortList(List<Airline> list, SortOption option) {
    switch (option) {
      case SortOption.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.byCounts:
        list.sort((a, b) => b.totalTimes.compareTo(a.totalTimes));
        break;
      case SortOption.lastFlightDate:
        list.sort((a, b) {
          final dateA = DateTime.tryParse(a.lastFlightDate);
          final dateB = DateTime.tryParse(b.lastFlightDate);
          if (a.logs.isEmpty && b.logs.isEmpty) return 0;
          if (a.logs.isEmpty) return 1;
          if (b.logs.isEmpty) return -1;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        break;
      case SortOption.byRatings:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.favorites:
      // 즐겨찾기 모드일 때의 정렬 (기본적으로 이름순으로 정렬)
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }

  // ⭐️ 새로운 리스트형 카드 디자인
  Widget _buildAirlineListCard(BuildContext context, Airline airline, AirlineProvider provider) {
    final totalFlights = airline.totalTimes;
    final hasFlights = totalFlights > 0;
    // ⭐️ [수정] airline.name 대신 airline.code3를 사용하여 매칭
    final allianceName = airlineAlliances[airline.code3];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AirlineDetailScreen(airlineName: airline.name),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. 로고 섹션
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Image.asset(
                    'assets/avcodes_banners/${airline.code3}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.flight,
                        color: Colors.grey[300],
                        size: 30,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // 2. 항공사 이름 및 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        airline.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (allianceName != null) ...[
                            Text(
                              allianceName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          if (airline.rating > 0)
                            Row(
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                const SizedBox(width: 2),
                                Text(
                                  airline.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'No Rating',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. 우측 액션 버튼 및 통계
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 하트 버튼
                    InkWell(
                      onTap: () {
                        provider.toggleFavoriteStatus(airline.name);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          airline.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: airline.isFavorite ? Colors.red : Colors.grey[300],
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 탑승 횟수 뱃지
                    if (hasFlights)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Text(
                          '${totalFlights} flights',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}