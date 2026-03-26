// lib/screens/world_wonders_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:country_flags/country_flags.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart';

class WorldWondersScreen extends StatefulWidget {
  const WorldWondersScreen({super.key});

  @override
  State<WorldWondersScreen> createState() => _WorldWondersScreenState();
}

class _WorldWondersScreenState extends State<WorldWondersScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimController;
  late AnimationController _listAnimController;
  late AnimationController _glowController;

  // 각 wonder별 아이콘 매핑
  static const Map<String, String> _wonderIcons = {
    'Great Wall of China': 'assets/icons/great_wall.png',
    'Petra':               'assets/icons/petra.png',
    'Colosseum':           'assets/icons/colosseum.png',
    'Chichen Itza':        'assets/icons/chichen_itza.png',
    'Machu Picchu':        'assets/icons/machu_picchu.png',
    'Taj Mahal':           'assets/icons/taj_mahal.png',
    'Christ the Redeemer': 'assets/icons/christ_redeemer.png',
  };

  final List<Map<String, String>> _wondersList = [
    {'name': 'Great Wall of China', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fgreat_wall.png?alt=media',     'iso': 'CN', 'location': 'China'},
    {'name': 'Petra',               'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fpetra.png?alt=media',         'iso': 'JO', 'location': 'Jordan'},
    {'name': 'Colosseum',           'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fcolosseum.png?alt=media',     'iso': 'IT', 'location': 'Italy'},
    {'name': 'Chichen Itza',        'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fchichen_itza.png?alt=media',  'iso': 'MX', 'location': 'Mexico'},
    {'name': 'Machu Picchu',        'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fmachu_picchu.png?alt=media',  'iso': 'PE', 'location': 'Peru'},
    {'name': 'Taj Mahal',           'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Ftaj_mahal.png?alt=media',     'iso': 'IN', 'location': 'India'},
    {'name': 'Christ the Redeemer', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fchrist_redeemer.png?alt=media','iso': 'BR', 'location': 'Brazil'},
  ];

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _listAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks = landmarksProvider.allLandmarks;
    final visitedCount = _wondersList
        .where((w) => landmarksProvider.visitedLandmarks.contains(w['name']))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 헤더 ──
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(
                  parent: _headerAnimController, curve: Curves.easeOut),
              child: _buildHeader(visitedCount, landmarksProvider),
            ),
          ),
          // ── 카드 리스트 ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final data = _wondersList[index];
                  final name = data['name']!;
                  final imageUrl = data['image']!;
                  final iso = data['iso']!;
                  final location = data['location']!;
                  final isVisited =
                  landmarksProvider.visitedLandmarks.contains(name);
                  final landmark =
                  allLandmarks.firstWhereOrNull((l) => l.name == name);
                  final iconPath = _wonderIcons[name] ?? 'assets/icons/petra.png';

                  return _AnimatedWonderCard(
                    index: index,
                    controller: _listAnimController,
                    child: _buildWonderCard(
                      name, imageUrl, iso, location, iconPath, isVisited, landmark,
                    ),
                  );
                },
                childCount: _wondersList.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 헤더 ─────────────────────────────────────────────────
  Widget _buildHeader(int visitedCount, LandmarksProvider provider) {
    return Container(
      color: const Color(0xFFF5F4F0),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 라인
          const Divider(color: Color(0xFF1A1A1A), thickness: 1, height: 1),
          const SizedBox(height: 14),

          // 타이틀 + 큰 숫자
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  'World\nWonders',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
              ),
              const Text(
                '7',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFCDCAB8),
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 하단 라인
          const Divider(color: Color(0xFF1A1A1A), thickness: 1, height: 1),
          const SizedBox(height: 10),

          // 서브타이틀 + 방문 수
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Humanity's greatest achievements",
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500], letterSpacing: 0.2),
              ),
              Text(
                '$visitedCount VISITED',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 아이콘 7개 행
          Row(
            children: _wondersList.map((w) {
              final name = w['name']!;
              final iconPath = _wonderIcons[name] ?? 'assets/icons/petra.png';
              final isVisited = provider.visitedLandmarks.contains(name);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _WonderIconBadge(
                    iconPath: iconPath,
                    isVisited: isVisited,
                    glowController: _glowController,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 카드 ─────────────────────────────────────────────────
  Widget _buildWonderCard(
      String name,
      String imageUrl,
      String iso,
      String location,
      String iconPath,
      bool isVisited,
      Landmark? landmark,
      ) {
    return GestureDetector(
      onTap: () {
        if (landmark != null) {
          _showLandmarkDetailsModal(
              context, landmark, const Color(0xFF1A1A1A));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 210,
                      color: const Color(0xFFEEEDEA),
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 210,
                      color: const Color(0xFFEEEDEA),
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                  // 하단 그라데이션
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.32),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Visited 뱃지
                  if (isVisited)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2ECC71), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'VISITED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // 하단 정보
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    // 아이콘 (헤더 스타일과 동일, 글로우 포함)
                    _CardIconBadge(
                      iconPath: iconPath,
                      isVisited: isVisited,
                      glowController: _glowController,
                    ),
                    const SizedBox(width: 14),
                    // 이름 + 국가
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: SizedBox(
                                  width: 18,
                                  height: 13,
                                  child: CountryFlag.fromCountryCode(iso),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                location,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 화살표 버튼
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F4F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 15, color: Color(0xFF1A1A1A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 모달 ─────────────────────────────────────────────────
  void _showLandmarkDetailsModal(
      BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark =
        provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited =
        provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted =
        provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames =
        provider.getCountryNames(freshLandmark.countriesIsoA3);

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' &&
            freshLandmark.city != 'Unknown City') {
          locationDisplay = '${freshLandmark.city}, $countryNames';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                    (c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            landmarkThemeColor = country.themeColor;
          } catch (e) {
            landmarkThemeColor = null;
          }
        }

        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // 드래그 핸들
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: headerTextColor.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerTextColor,
                              foregroundColor: themeColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Done',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: themeColor,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              freshLandmark.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                color: headerTextColor,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (isVisited)
                            Icon(Icons.check_circle_rounded,
                                color: headerTextColor, size: 22),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13,
                              color: headerTextColor.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationDisplay,
                              style: TextStyle(
                                color: headerTextColor.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 바디
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => provider
                                        .toggleWishlistStatus(freshLandmark.name),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isWishlisted
                                            ? const Color(0xFFFFEBEB)
                                            : Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isWishlisted
                                              ? const Color(0xFFFFCDD2)
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Icon(
                                        isWishlisted
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isWishlisted
                                            ? Colors.red[400]
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isWishlisted ? 'Wishlisted' : 'Wishlist',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isWishlisted
                                          ? Colors.red[400]
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              RatingBar.builder(
                                initialRating: freshLandmark.rating ?? 0.0,
                                minRating: 0,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemSize: 26.0,
                                itemBuilder: (context, _) => const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB800)),
                                onRatingUpdate: (rating) =>
                                    provider.updateLandmarkRating(
                                        freshLandmark.name, rating),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Visit History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  provider.addVisitDate(freshLandmark.name),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Add Visit',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (freshLandmark.visitDates.isNotEmpty)
                          ...freshLandmark.visitDates
                              .asMap()
                              .entries
                              .map((entry) => LandmarkVisitEditorCard(
                            key: ValueKey(
                                '${freshLandmark.name}_${entry.key}'),
                            landmarkName: freshLandmark.name,
                            visitDate: entry.value,
                            index: entry.key,
                            onDelete: () => provider.removeVisitDate(
                                freshLandmark.name, entry.key),
                            availableLocations: freshLandmark.locations,
                          ))
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            alignment: Alignment.center,
                            child: Text('No visits recorded yet',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 13)),
                          ),
                        const SizedBox(height: 8),
                        const Divider(height: 24),
                        LandmarkInfoCard(
                          overview: freshLandmark.overview,
                          historySignificance:
                          freshLandmark.history_significance,
                          highlights: freshLandmark.highlights,
                          themeColor: themeColor,
                        ),
                        const SizedBox(height: 40),
                      ],
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
}

// ── 헤더 아이콘 뱃지 (글로우 애니메이션 포함) ─────────────────
class _WonderIconBadge extends StatelessWidget {
  final String iconPath;
  final bool isVisited;
  final AnimationController glowController;

  const _WonderIconBadge({
    required this.iconPath,
    required this.isVisited,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisited) {
      return Column(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEECE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFFCDCAB8),
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        final glow = glowController.value;
        return Column(
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE8C84A), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8C84A)
                          .withOpacity(0.2 + glow * 0.25),
                      blurRadius: 6 + glow * 10,
                      spreadRadius: glow * 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      iconPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFE8C84A),
                  const Color(0xFFF5D76E),
                  glow,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8C84A)
                        .withOpacity(0.5 + glow * 0.3),
                    blurRadius: 4 + glow * 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 카드 아이콘 뱃지 (글로우 포함) ───────────────────────────
class _CardIconBadge extends StatelessWidget {
  final String iconPath;
  final bool isVisited;
  final AnimationController glowController;

  const _CardIconBadge({
    required this.iconPath,
    required this.isVisited,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisited) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F4F0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(iconPath, fit: BoxFit.contain),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        final glow = glowController.value;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE8C84A), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8C84A)
                    .withOpacity(0.2 + glow * 0.25),
                blurRadius: 6 + glow * 10,
                spreadRadius: glow * 2,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(iconPath, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}

// ── 리스트 입장 애니메이션 ────────────────────────────────────
class _AnimatedWonderCard extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedWonderCard({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index * 0.1;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.clamp(0.0, 0.8),
        (delay + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}