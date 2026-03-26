// lib/screens/instagram_ranking_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:country_flags/country_flags.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';

// Instagram 핑크-퍼플 그라디언트 테마
const Color _kThemePink   = Color(0xFFE1306C);
const Color _kThemePurple = Color(0xFF833AB4);
const Color _kThemeOrange = Color(0xFFF77737);

class InstagramRankingScreen extends StatefulWidget {
  const InstagramRankingScreen({super.key});

  @override
  State<InstagramRankingScreen> createState() => _InstagramRankingScreenState();
}

class _InstagramRankingScreenState extends State<InstagramRankingScreen> {
  final List<Map<String, String>> _top10List = [
    {'name': 'Eiffel Tower',        'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Feiffel_tower.png?alt=media',    'iso': 'FR'},
    {'name': 'Big Ben',             'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fbig_ben.png?alt=media',         'iso': 'GB'},
    {'name': 'Louvre Museum',       'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Flouvre.png?alt=media',          'iso': 'FR'},
    {'name': 'Empire State Building','image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fempire_state.png?alt=media',   'iso': 'US'},
    {'name': 'Burj Khalifa',        'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fburj_khalifa.png?alt=media',    'iso': 'AE'},
    {'name': 'Notre-Dame de Paris', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fnotre_dame.png?alt=media',      'iso': 'FR'},
    {'name': "St. Peter's Basilica",'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fst_peters.png?alt=media',      'iso': 'VA'},
    {'name': 'Times Square',        'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Ftimes_square.png?alt=media',    'iso': 'US'},
    {'name': 'Sagrada Familia',     'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fsagrada_familia.png?alt=media', 'iso': 'ES'},
    {'name': 'Colosseum',           'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/instagram%2Fcolosseum.png?alt=media',       'iso': 'IT'},
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks      = landmarksProvider.allLandmarks;
    final visitedSet        = landmarksProvider.visitedLandmarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 20), // 수정: 왼쪽 패딩 추가
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // 왼쪽 그라디언트 세로 바
                Container(
                  width: 6, height: 60, // 수정: 굵기, 높이 변경
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration( // const 제거 (BorderRadius.circular 사용을 위해)
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kThemeOrange, _kThemePink, _kThemePurple],
                    ),
                    borderRadius: BorderRadius.circular(10), // 수정: 완전 둥글게
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(5), // 수정: 패딩 줄임
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [_kThemeOrange, _kThemePink, _kThemePurple],
                          ),
                          borderRadius: BorderRadius.circular(6), // 수정: 덜 둥글게
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12), // 수정: 아이콘 크기 줄임
                      ),
                      const SizedBox(width: 8), // 수정: 간격 늘림
                      const Text('Most Instagrammed',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, // 수정: 폰트 크기 줄임, 굵기 늘림
                              color: _kThemePink, letterSpacing: 0.1)), // 수정: letterSpacing 줄임
                    ]),
                    const SizedBox(height: 8), // 수정: 간격 늘림
                    const Text('Top 10 Landmarks',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, // 수정: 폰트 크기 줄임, 굵기 줄임
                            color: Color(0xFF111827), letterSpacing: -0.8, height: 1.0)), // 수정: letterSpacing, height 줄임
                    const SizedBox(height: 4),
                    Text('Most tagged places on Instagram',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ]),
                ),
                // 방문 카운터
                Consumer<LandmarksProvider>(builder: (context, provider, _) {
                  final visited = _top10List.where((m) => provider.visitedLandmarks.contains(m['name'])).length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 수정: 패딩 늘림
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kThemePink.withOpacity(0.08), _kThemePurple.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(16), // 수정: 더 둥글게
                      border: Border.all(color: _kThemePink.withOpacity(0.15)), // 수정: 테두리 색상 연하게
                    ),
                    child: Column(children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                            colors: [_kThemePink, _kThemePurple]).createShader(b),
                        child: Text('$visited',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                      ),
                      Text('/ 10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _kThemePink.withOpacity(0.7), height: 1.2)),
                      const SizedBox(height: 2),
                      Text('visited', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                          color: _kThemePink.withOpacity(0.5))),
                    ]),
                  );
                }),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _top10List.length,
                itemBuilder: (context, index) {
                  final itemData  = _top10List[index];
                  final rank      = index + 1;
                  final name      = itemData['name']!;
                  final imagePath = itemData['image']!;
                  final isoCode   = itemData['iso']!;

                  final landmark  = allLandmarks.firstWhereOrNull((l) => l.name == name);
                  final isVisited = visitedSet.contains(name);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, _kThemePink, imagePath);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Landmark data not found for $name')),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: isVisited
                            ? Border.all(color: _kThemePink.withOpacity(0.6), width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isVisited
                                ? _kThemePink.withOpacity(0.12)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 이미지 섹션
                          Stack(children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: CachedNetworkImage(
                                  imageUrl: imagePath,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text('Image not available', style: TextStyle(color: Colors.grey[500])),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                            // 상단 그라디언트 오버레이
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                                      stops: const [0.0, 0.5],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 랭크 뱃지 (그라디언트)
                            Positioned(
                              top: 12, left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_kThemeOrange, _kThemePink],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: _kThemePink.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Text('#$rank',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.3)),
                              ),
                            ),
                            // 방문 체크
                            if (isVisited)
                              Positioned(
                                top: 12, right: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [_kThemePink, _kThemePurple],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: _kThemePink.withOpacity(0.4), blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                          ]),

                          // 하단 정보 행
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: SizedBox(width: 30, height: 22, child: CountryFlag.fromCountryCode(isoCode)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.3)),
                              ),
                              // 인스타 그라디언트 화살표
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [_kThemePink, _kThemePurple],
                                ).createShader(bounds),
                                child: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.white),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor, String imagePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final provider        = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark   = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited       = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted    = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount   = freshLandmark.locations?.length ?? 0;

        // 국기 목록
        final displayIsos = freshLandmark.countriesIsoA3
            .map((a3) => countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == a3)?.isoA2)
            .whereType<String>().toList();

        // 항상 인스타 핑크 테마 고정
        const themeColor      = _kThemePink;
        const headerTextColor = Colors.white;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(children: [
              // ── 모달 헤더: 이미지 배경 ──────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(children: [
                    // 배경 이미지
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: imagePath,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1A0A2E), _kThemePurple],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 그라디언트 오버레이
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.75),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Cancel / Done 버튼
                    Positioned(
                      top: 12, left: 8, right: 8,
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          label: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        if (isVisited)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_kThemePink, _kThemePurple]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          ),
                      ]),
                    ),
                    // 제목 + 국기 하단
                    Positioned(
                      bottom: 16, left: 16, right: 16,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(freshLandmark.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: headerTextColor, letterSpacing: -0.5, height: 1.2)),
                        const SizedBox(height: 8),
                        if (displayIsos.isNotEmpty)
                          Row(children: displayIsos.map((a2) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(width: 30, height: 20, child: CountryFlag.fromCountryCode(a2)),
                            ),
                          )).toList()),
                      ]),
                    ),
                  ]),
                ),
              ),

              // ── 모달 바디 ───────────────────────────────────────────
              Expanded(child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Wishlist + Rating
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Wishlist:'),
                        IconButton(visualDensity: VisualDensity.compact,
                            icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                            onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('My Rating:'),
                        const SizedBox(width: 8),
                        RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0,
                            direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0,
                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                      ]),
                    ]),
                    const Divider(height: 20),

                    // Sub-locations
                    if (totalSubCount > 1) ...[
                      Text('Components / Locations',
                          style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Column(children: freshLandmark.locations!.map((loc) {
                          final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                          return CheckboxListTile(
                            title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                            value: isLocVisited, activeColor: themeColor, dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) => provider.toggleSubLocation(freshLandmark.name, loc.name),
                          );
                        }).toList()),
                      ),
                      const Divider(height: 24),
                    ],

                    // Visit history
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('History (${freshLandmark.visitDates.length} entries)',
                          style: Theme.of(sheetContext).textTheme.titleSmall),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Visit'),
                        onPressed: () => provider.addVisitDate(freshLandmark.name),
                        style: OutlinedButton.styleFrom(foregroundColor: themeColor, side: const BorderSide(color: themeColor)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (freshLandmark.visitDates.isNotEmpty)
                      ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                        key: ValueKey('${freshLandmark.name}_${entry.key}'),
                        landmarkName: freshLandmark.name,
                        visitDate: entry.value,
                        index: entry.key,
                        themeColor: themeColor,
                        onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                        availableLocations: freshLandmark.locations,
                      ))
                    else const Center(child: Text('No visits recorded.')),
                    const Divider(height: 24),

                    LandmarkInfoCard(
                      overview: freshLandmark.overview,
                      historySignificance: freshLandmark.history_significance,
                      highlights: freshLandmark.highlights,
                      themeColor: themeColor,
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              )),
            ]),
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  bool _isItemCategory(Landmark item, String category) => item.attributes.contains(category);

  bool _isItemNatural(Landmark item) {
    return item.attributes.any((a) => ['Mountain', 'Waterfall', 'Falls', 'River', 'Lake', 'Sea', 'Beach', 'Island', 'Unique Landscape'].contains(a));
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
      return countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first)?.isoA2;
    }
    return null;
  }
}

// ─── Visit Editor Card (title/memo 저장 + 날짜 변경 + edit/save/cancel) ─────────

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final Color themeColor;
  final List<LandmarkSubLocation>? availableLocations;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    required this.themeColor,
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

  late String _displayTitle;
  late String _displayMemo;
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
    _year  = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day   = widget.visitDate.day;
    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName, widget.index,
      title: _titleController.text,
      memo: _memoController.text,
      year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999,
      photos: _currentPhotos,
    );
    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo  = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text  = _displayMemo;
      _year  = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day   = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
      firstDate: DateTime(1900), lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
    }
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
  }

  Widget _buildPhotoPreview(String path, int i) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover)),
      ),
      if (_isEditing)
        Positioned(top: -6, right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _currentPhotos.removeAt(i)),
              child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 22)),
            )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.themeColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(
          _displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Date: $_year-$_month-$_day',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Visit Record'),
              content: const Text('Are you sure you want to delete this visit record?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isEditing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Visit Date: $_year-$_month-$_day',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  maxLines: 3, minLines: 1,
                  decoration: InputDecoration(labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                ),
              ] else ...[
                if (_displayMemo.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_displayMemo, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4))),
              ],
              const SizedBox(height: 12),
              if (_currentPhotos.isNotEmpty || _isEditing)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none,
                    child: Row(children: [
                      if (_isEditing)
                        Container(margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)),
                            child: IconButton(icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                onPressed: () => _pickImage(ImageSource.gallery))),
                      ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                    ]),
                  ),
                ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_isEditing) ...[
                  TextButton(onPressed: _cancelEditing,
                      child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(onPressed: _saveChanges,
                      icon: const Icon(Icons.save, size: 18), label: const Text('Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0)),
                ] else ...[
                  OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                      style: OutlinedButton.styleFrom(foregroundColor: themeColor,
                          side: BorderSide(color: themeColor.withOpacity(0.5)))),
                ],
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}