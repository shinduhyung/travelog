// lib/screens/top_picks_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/screens/landmarks_list_screen.dart';
import 'package:jidoapp/screens/instagram_ranking_screen.dart';
import 'package:jidoapp/screens/top_landmarks_screen.dart';
import 'package:jidoapp/screens/top_buildings_screen.dart';
import 'package:jidoapp/screens/top_bridges_screen.dart';
import 'package:jidoapp/screens/top_statues_screen.dart';
import 'package:jidoapp/screens/top_falls_screen.dart';
import 'package:jidoapp/screens/top_mountains_screen.dart';
import 'package:jidoapp/screens/top_rivers_screen.dart';
import 'package:jidoapp/screens/top_lakes_screen.dart';
import 'package:jidoapp/screens/top_museums_screen.dart';
import 'package:jidoapp/screens/top_public_squares_screen.dart';
import 'package:jidoapp/screens/landmark_cities_screen.dart';
import 'package:jidoapp/screens/top_universities_screen.dart';
import 'package:jidoapp/screens/world_wonders_screen.dart';

class TopPicksMenuScreen extends StatelessWidget {
  const TopPicksMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Consumer<LandmarksProvider>(
          builder: (context, landmarksProvider, child) {
            // Global Rank가 0보다 큰 모든 아이템을 가져옵니다.
            final globalTopItems = landmarksProvider.allLandmarks
                .where((l) => l.global_rank > 0)
                .toList();
            final globalTotal = globalTopItems.length;
            final globalVisited = globalTopItems
                .where((l) => landmarksProvider.visitedLandmarks.contains(l.name))
                .length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Picks',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Explore the world\'s finest landmarks',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Global Top Attractions — 로그인 없이 접근 가능
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: _buildHeroCard(
                      context,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TopLandmarksScreen(),
                          ),
                        );
                      },
                      visited: globalVisited,
                      total: globalTotal,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Quick Access 카드들 — 로그인 필요
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Builder(builder: (context) {
                      void gated(VoidCallback action) {
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
                        action();
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              title: 'Cities',
                              icon: Icons.location_city_rounded,
                              color: const Color(0xFF4A5568),
                              attributes: ['City'],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LandmarkCitiesScreen()))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              title: 'Instagram',
                              iconAsset: 'assets/icons/instagram_icon.webp',
                              color: const Color(0xFFB87E7E),
                              attributes: [],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstagramRankingScreen()))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildQuickAccessCard(
                              context,
                              title: '7 Wonders',
                              icon: Icons.auto_awesome,
                              color: const Color(0xFFD4AF37),
                              attributes: [],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorldWondersScreen()))),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Cultural Wonders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Builder(builder: (context) {
                        void gated(VoidCallback action) {
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
                          action();
                        }
                        return Column(
                          children: [
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Highest Buildings',
                              icon: Icons.apartment_rounded,
                              color: const Color(0xFFB5838D),
                              attributes: ['Tower', 'Skyscraper'],
                              filterBySpecificNames: [
                                'Burj Khalifa',
                                'Merdeka 118',
                                'Shanghai Tower',
                                'Abraj Al Bait',
                                'Ping An International Finance Centre',
                                'Lotte World Tower',
                                'One World Trade Center',
                                'Guangzhou CTF Finance Centre',
                                'Tianjin CTF Finance Centre',
                                'China Zun',
                                'Taipei 101',
                                'Shanghai World Financial Center',
                                'International Commerce Centre',
                                'Wuhan Greenland Center',
                                'Central Park Tower',
                                'Lakhta Center',
                                'Landmark 81',
                                'Chongqing International Land-Sea Center',
                                'The Exchange 106',
                                'Changsha IFS Tower T1',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopBuildingsScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Top Museums',
                              icon: Icons.museum_rounded,
                              color: const Color(0xFF6B9B9E),
                              attributes: ['Museum'],
                              filterBySpecificNames: [
                                'Louvre Museum',
                                'Metropolitan Museum of Art',
                                'British Museum',
                                'Hermitage Museum',
                                'Prado Museum',
                                'The Museum of Modern Art',
                                'Pergamon Museum',
                                'Uffizi Gallery',
                                'Musée d\'Orsay',
                                'Rijksmuseum',
                                'National Palace Museum',
                                'National Gallery',
                                'Kunsthistorisches Museum',
                                'National Gallery of Art',
                                'National Museum of Anthropology',
                                'Smithsonian National Museum of Natural History',
                                'Art Institute of Chicago',
                                'Tate Modern',
                                'Acropolis Museum',
                                'Victoria and Albert Museum',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopMuseumsScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Top Universities',
                              icon: Icons.school_rounded,
                              color: const Color(0xFF7B9CAE),
                              attributes: ['University'],
                              useAttributeRankFilter: true,
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUniversitiesScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Best Public Squares',
                              icon: Icons.people_rounded,
                              color: const Color(0xFFB88080),
                              attributes: ['Square', 'Plaza'],
                              filterBySpecificNames: [
                                'Times Square',
                                'Red Square',
                                'Tiananmen Square',
                                'St. Mark\'s Square',
                                'Place de la Concorde',
                                'Plaza Mayor',
                                'Piazza del Duomo',
                                'St. Peter\'s Square',
                                'Trafalgar Square',
                                'Grand Place',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopPublicSquaresScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Tallest Statues',
                              icon: Icons.account_balance_rounded,
                              color: const Color(0xFF8E7BA3),
                              attributes: ['Statue'],
                              filterBySpecificNames: [
                                'Statue of Unity',
                                'Spring Temple Buddha',
                                'Laykyun Sekkya',
                                'Vishwas Swaroopam',
                                'Ushiku Daibutsu',
                                'Sendai Daikannon',
                                'Guanyin of Nanshan',
                                'Great Buddha of Thailand',
                                'Dai Kannon of Kita no Miyako Park',
                                'Mamayev Kurgan',
                                'Awaji Kannon',
                                'Grand Buddha at Ling Shan',
                                'Leshan Giant Buddha',
                                'African Renaissance Monument',
                                'Statue of Liberty',
                                'Ataturk Mask',
                                'Lord Murugan Statue',
                                'Genghis Khan Statue Complex',
                                'Christ the Redeemer',
                                'Adiyogi Shiva Statue',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopStatuesScreen()))),
                            ),
                          ],
                        );
                      }),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Natural Wonders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Builder(builder: (context) {
                        void gated(VoidCallback action) {
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
                          action();
                        }
                        return Column(
                          children: [
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Highest Mountains',
                              icon: Icons.terrain_rounded,
                              color: const Color(0xFF4A5662),
                              attributes: ['Mountain'],
                              filterBySpecificNames: [
                                'Mount Everest',
                                'K2',
                                'Kangchenjunga',
                                'Lhotse',
                                'Makalu',
                                'Cho Oyu',
                                'Dhaulagiri',
                                'Manaslu',
                                'Nanga Parbat',
                                'Annapurna'
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopMountainsScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Longest Rivers',
                              icon: Icons.waves_rounded,
                              color: const Color(0xFF5B8FA3),
                              attributes: ['River'],
                              filterBySpecificNames: [
                                'Nile River',
                                'Amazon River',
                                'Yangtze River',
                                'Mississippi River',
                                'Yenisei River',
                                'Yellow River',
                                'Ob River',
                                'Parana River',
                                'Congo River',
                                'Amur River',
                                'Lena River',
                                'Mekong River',
                                'Mackenzie River',
                                'Niger River',
                                'Murray River',
                                'Volga River'
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopRiversScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Largest Lakes',
                              icon: Icons.water_rounded,
                              color: const Color(0xFF6B9DB8),
                              attributes: ['Lake'],
                              filterBySpecificNames: [
                                'Caspian Sea',
                                'Lake Superior',
                                'Lake Victoria',
                                'Lake Huron',
                                'Lake Michigan',
                                'Lake Tanganyika',
                                'Lake Baikal',
                                'Great Bear Lake',
                                'Lake Malawi',
                                'Great Slave Lake',
                                'Lake Erie',
                                'Lake Winnipeg',
                                'Lake Ontario',
                                'Lake Ladoga',
                                'Lake Balkhash',
                                'Lake Vostok',
                                'Lake Onega',
                                'Lake Titicaca',
                                'Lake Nicaragua',
                                'Lake Athabasca',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopLakesScreen()))),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactCard(
                              context,
                              landmarksProvider,
                              title: 'Highest Falls',
                              icon: Icons.water_drop_rounded,
                              color: const Color(0xFF6B9AB8),
                              attributes: ['Waterfall'],
                              filterBySpecificNames: [
                                'Angel Falls',
                                'Tugela Falls',
                                'Tres Hermanas Falls',
                                'Olo\'upena Falls',
                                'Yumbilla Falls',
                                'Vinnufossen',
                                'Skorga',
                                'Pu\'uka\'oku Falls',
                                'James Bruce Falls',
                                'Browne Falls',
                                'Strupenfossen',
                                'Ramnefjellsfossen',
                                'Waihilau Falls',
                                'Colonial Creek Falls',
                                'Mongefossen',
                                'Gocta Falls',
                                'Mutarazi Falls',
                                'Kjelfossen',
                                'Johannesburg Falls',
                                'Yosemite Falls',
                              ],
                              customOnTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopFallsScreen()))),
                            ),
                          ],
                        );
                      }),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {
    required VoidCallback onTap,
    required int visited,
    required int total,
  }) {
    final progress = total > 0 ? visited / total : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFEC4899),
                              Color(0xFFF97316),
                              Color(0xFFF59E0B),
                              Color(0xFF22C55E),
                              Color(0xFF0EA5E9),
                              Color(0xFF8B5CF6),
                            ],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Global Top Attractions',
                            style: TextStyle(
                              fontSize: 19, // 제목이 길어져 폰트 크기를 약간 조정함
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'World\'s Most Iconic',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$visited / $total',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Color(0xFF2C3E50),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
      BuildContext context, {
        required String title,
        IconData? icon,
        String? iconAsset,
        required Color color,
        required List<String> attributes,
        VoidCallback? customOnTap,
      }) {
    return GestureDetector(
      onTap: customOnTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LandmarksListScreen(
              title: 'Top $title',
              attributes: attributes,
            ),
          ),
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: iconAsset != null
                    ? Center(
                  child: Image.asset(
                    iconAsset,
                    width: 20,
                    height: 20,
                    color: color,
                  ),
                )
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(
      BuildContext context,
      LandmarksProvider provider, {
        required String title,
        required IconData icon,
        required Color color,
        required List<String> attributes,
        List<String>? filterBySpecificNames,
        bool useAttributeRankFilter = false,
        VoidCallback? customOnTap,
      }) {

    final List<Landmark> items;
    if (filterBySpecificNames != null) {
      items = provider.allLandmarks
          .where((l) => filterBySpecificNames.contains(l.name))
          .toList();
    } else if (useAttributeRankFilter) {
      items = provider.allLandmarks.where((l) {
        final bool hasAttr = attributes.any((attr) => l.attributes.contains(attr));
        final int rank = l.attribute_rank;
        return hasAttr && rank >= 1 && rank <= 100;
      }).toList();
    } else {
      items = provider.getLandmarksByAttributes(attributes);
    }

    final total = useAttributeRankFilter ? 100 : (filterBySpecificNames?.length ?? items.length);
    final visited = items.where((l) => provider.visitedLandmarks.contains(l.name)).length;
    final progress = total > 0 ? visited / total : 0.0;

    return GestureDetector(
      onTap: customOnTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LandmarksListScreen(
              title: title,
              attributes: attributes,
            ),
          ),
        );
      },
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$visited of $total',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}