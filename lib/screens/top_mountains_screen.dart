// lib/screens/top_mountains_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// top_picks_menu 기준 mountains 테마색
const Color _kTheme = Color(0xFF52796F);

class TopMountainsScreen extends StatelessWidget {
  const TopMountainsScreen({super.key});

  static final List<Map<String, dynamic>> _top10Mountains = [
    {'rank': 1,  'name': 'Mount Everest',  'height': '8,848 m', 'iso': 'NP'},
    {'rank': 2,  'name': 'K2',             'height': '8,611 m', 'iso': 'PK'},
    {'rank': 3,  'name': 'Kangchenjunga', 'height': '8,586 m', 'iso': 'NP'},
    {'rank': 4,  'name': 'Lhotse',         'height': '8,516 m', 'iso': 'NP'},
    {'rank': 5,  'name': 'Makalu',         'height': '8,485 m', 'iso': 'NP'},
    {'rank': 6,  'name': 'Cho Oyu',        'height': '8,188 m', 'iso': 'NP'},
    {'rank': 7,  'name': 'Dhaulagiri',     'height': '8,167 m', 'iso': 'NP'},
    {'rank': 8,  'name': 'Manaslu',        'height': '8,163 m', 'iso': 'NP'},
    {'rank': 9,  'name': 'Nanga Parbat',   'height': '8,126 m', 'iso': 'PK'},
    {'rank': 10, 'name': 'Annapurna',      'height': '8,091 m', 'iso': 'NP'},
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks = landmarksProvider.allLandmarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더: 미니멀 + 왼쪽 컬러 바 스타일 ──────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(0, 24, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 왼쪽 세로 컬러 바
                  Container(
                    width: 5,
                    height: 80,
                    margin: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: _kTheme,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.terrain_rounded, size: 14, color: _kTheme),
                          const SizedBox(width: 5),
                          Text('Highest Mountains',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTheme, letterSpacing: 0.3)),
                        ]),
                        const SizedBox(height: 6),
                        RichText(text: const TextSpan(children: [
                          TextSpan(text: 'Top ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.8, height: 1.1)),
                          TextSpan(text: '10', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _kTheme, letterSpacing: -1.5, height: 1.0)),
                          TextSpan(text: ' Peaks', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.8, height: 1.1)),
                        ])),
                        const SizedBox(height: 4),
                        Text('8,000+ metre summits', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // 방문 카운트
                  Consumer<LandmarksProvider>(
                    builder: (context, provider, _) {
                      final visited = _top10Mountains.where((m) => provider.visitedLandmarks.contains(m['name'])).length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kTheme.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kTheme.withOpacity(0.2)),
                        ),
                        child: Column(children: [
                          Text('$visited', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kTheme, height: 1.0)),
                          Text('/ 10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTheme.withOpacity(0.6))),
                          const SizedBox(height: 2),
                          Text('visited', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _kTheme.withOpacity(0.5))),
                        ]),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _top10Mountains.length,
                itemBuilder: (context, index) {
                  final data   = _top10Mountains[index];
                  final name   = data['name'] as String;
                  final height = data['height'] as String;
                  final iso    = data['iso'] as String;
                  final rank   = data['rank'] as int;

                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark  = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  // 높이에 따른 바 길이 비율 (Everest 기준)
                  final double barRatio = (int.parse(height.replaceAll(',', '').replaceAll(' m', '')) / 8848).clamp(0.0, 1.0);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, _kTheme);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name details not found in database')),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isVisited ? _kTheme.withOpacity(0.45) : Colors.grey[200]!,
                          width: isVisited ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(children: [
                            // 랭크 숫자
                            SizedBox(
                              width: 36,
                              child: Text(
                                '$rank',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: rank == 1 ? 22 : 20,
                                  fontWeight: FontWeight.w900,
                                  color: rank == 1
                                      ? const Color(0xFFFFD700)
                                      : rank <= 3
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[400]!,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 국기
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(width: 30, height: 22, child: CountryFlag.fromCountryCode(iso)),
                            ),
                            const SizedBox(width: 12),
                            // 이름
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 높이 텍스트
                            Text(
                              height,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTheme),
                            ),
                            const SizedBox(width: 10),
                            // 방문 여부
                            if (isVisited)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              )
                            else
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          // 높이 비례 바
                          Row(children: [
                            const SizedBox(width: 36 + 10), // rank width + gap
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Stack(children: [
                                  Container(height: 4, color: Colors.grey[100]),
                                  FractionallySizedBox(
                                    widthFactor: barRatio,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [_kTheme.withOpacity(0.5), _kTheme],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ]),
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

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider      = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited     = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted  = provider.wishlistedLandmarks.contains(freshLandmark.name);

        // 항상 해당 카테고리 테마색 사용 (국가색 무시)
        const themeColor = _kTheme;
        const headerTextColor = Colors.white;

        // 국기 위젯 빌더
        Widget buildFlags() {
          final isoA2List = freshLandmark.countriesIsoA3.map((isoA3) {
            return countryProvider.allCountries
                .firstWhereOrNull((c) => c.isoA3 == isoA3)?.isoA2;
          }).whereType<String>().toList();

          if (isoA2List.isEmpty) return const SizedBox.shrink();

          return Wrap(
            spacing: 6,
            runSpacing: 4,
            children: isoA2List.map((a2) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(width: 32, height: 22, child: CountryFlag.fromCountryCode(a2)),
              ),
            )).toList(),
          );
        }

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(children: [
            Container(
              color: themeColor,
              padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton(onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                  ElevatedButton(onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(freshLandmark.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: headerTextColor, letterSpacing: -0.5, height: 1.2))),
                  if (isVisited) const Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: Icon(Icons.check_circle, color: headerTextColor, size: 24),
                  ),
                ]),
                const SizedBox(height: 10),
                buildFlags(),
              ]),
            ),
            Expanded(child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0,
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                  ]),
                ]),
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall),
                  OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name)),
                ]),
                const SizedBox(height: 8),
                if (freshLandmark.visitDates.isNotEmpty)
                  ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                    key: ValueKey('${freshLandmark.name}_${entry.key}'),
                    landmarkName: freshLandmark.name,
                    visitDate: entry.value,
                    index: entry.key,
                    onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                    availableLocations: freshLandmark.locations,
                  ))
                else const Center(child: Text('No visits recorded.')),
                const Divider(height: 24),
                LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                const SizedBox(height: 40),
              ]),
            ))),
          ]),
        );
      },
    );
  }
}

// ─── Visit Editor Card (title 저장 + 날짜 변경만) ─────────────────────────────

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.visitDate.title);
    _memoController  = TextEditingController(text: widget.visitDate.memo);
    _currentPhotos   = List.from(widget.visitDate.photos);
    _year  = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day   = widget.visitDate.day;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
      context.read<LandmarksProvider>().updateLandmarkVisit(
        widget.landmarkName, widget.index,
        year: picked.year, month: picked.month, day: picked.day,
      );
    }
  }

  void _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(pickedFile.path);
      setState(() => _currentPhotos = newPhotos);
      context.read<LandmarksProvider>().updateLandmarkVisit(widget.landmarkName, widget.index, photos: newPhotos);
    }
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Container(
      width: 60, height: 60, margin: const EdgeInsets.only(right: 8), color: Colors.grey[300],
      child: Image.file(File(photoPath), fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LandmarksProvider>();
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.edit_calendar_outlined, size: 13, color: Colors.grey[400]),
          ]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: widget.onDelete,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title 필드 — 포커스 잃을 때 저장
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', isDense: true),
                onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text),
                onTapOutside: (_) => provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text),
              ),
              const SizedBox(height: 8),
              // Memo 필드
              TextField(
                controller: _memoController,
                decoration: const InputDecoration(labelText: 'Memo', isDense: true),
                onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text),
                onTapOutside: (_) => provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text),
              ),
              const SizedBox(height: 12),
              // 날짜 변경 버튼
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: Text('Change Date  ($_year-$_month-$_day)'),
                onPressed: () => _selectDate(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTheme,
                  side: BorderSide(color: _kTheme.withOpacity(0.4)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 12),
              // 사진
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(ImageSource.gallery)),
                  ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}