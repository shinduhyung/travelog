// lib/screens/landmark_visit_log_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';

enum LogGroupOption { year, country }

const Color _kTheme = Color(0xFF10B981);

class LandmarkVisitLogScreen extends StatefulWidget {
  const LandmarkVisitLogScreen({super.key});

  @override
  State<LandmarkVisitLogScreen> createState() => _LandmarkVisitLogScreenState();
}

class _LandmarkVisitLogScreenState extends State<LandmarkVisitLogScreen> {
  LogGroupOption _logGroupOption = LogGroupOption.year;

  String? _getDisplayIsoA2(Landmark site, CountryProvider cp) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.city.contains('Hong Kong') || site.countriesIsoA3.contains('HKG')) return 'HK';
    if (site.countriesIsoA3.contains('GRL')) return 'GL';
    if (site.countriesIsoA3.contains('PYF')) return 'PF';
    if (site.countriesIsoA3.contains('PRI')) return 'PR';
    if (site.countriesIsoA3.contains('BMU')) return 'BM';
    if (site.countriesIsoA3.contains('GIB')) return 'GI';
    if (site.countriesIsoA3.contains('PCN')) return 'PN';
    if (site.countriesIsoA3.length == 1) {
      return cp.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first)?.isoA2;
    }
    return null;
  }

  Widget _buildFlag(Landmark item, CountryProvider cp) {
    final sorted = List<String>.from(item.countriesIsoA3)
      ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

    if (sorted.length >= 2) {
      final iso1 = cp.allCountries.firstWhereOrNull((c) => c.isoA3 == sorted[0])?.isoA2;
      final iso2 = cp.allCountries.firstWhereOrNull((c) => c.isoA3 == sorted[1])?.isoA2;
      if (iso1 != null && iso2 != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(width: 24, height: 18,
              child: Stack(fit: StackFit.expand, children: [
                CountryFlag.fromCountryCode(iso1),
                ClipPath(clipper: const DiagonalClipper(), child: CountryFlag.fromCountryCode(iso2)),
              ])),
        );
      }
    }

    final iso = _getDisplayIsoA2(item, cp);
    if (iso != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(4),
          child: SizedBox(width: 24, height: 18, child: CountryFlag.fromCountryCode(iso)));
    }
    return const Icon(Icons.place, size: 16, color: Colors.grey);
  }

  // ── Landmark Hero Image (Firebase Storage: new_countrydex/) ─────────────
  // 이름 슬러그(파일명의 나머지 부분)만 뽑아내는 헬퍼.
  String _getLandmarkNameSlug(Landmark landmark) {
    return landmark.name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }

  // 시도할 후보 URL 리스트를 반환.
  // 1) {iso}_{name} (기존 방식, iso 코드가 있을 때만)
  // 2) m_{name} (다국적/미매칭 랜드마크 대비 fallback)
  // 두 후보를 동시에 요청해서 먼저 성공하는 걸 사용한다 (_FallbackNetworkImage 참고).
  List<String> _getLandmarkImageUrlCandidates(Landmark landmark) {
    final snake = _getLandmarkNameSlug(landmark);
    if (snake.isEmpty) return [];

    const base = 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/new_countrydex%2F';
    const suffix = '.webp?alt=media';

    final List<String> fileNames = [];
    if (landmark.countriesIsoA3.isNotEmpty) {
      final iso = landmark.countriesIsoA3.first.toLowerCase();
      fileNames.add('${iso}_$snake');
    }
    fileNames.add('m_$snake');

    return fileNames.map((name) => '$base$name$suffix').toList();
  }

  Widget _buildLandmarkHeroImage(Landmark landmark) {
    final candidates = _getLandmarkImageUrlCandidates(landmark);
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: _FallbackNetworkImage(
            urls: candidates,
            placeholderBuilder: (context) => Container(
              color: Colors.grey.shade100,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            emptyBuilder: (context) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Consumer<LandmarksProvider>(
        builder: (context, provider, child) {
          final freshLandmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == landmark.name) ?? landmark;
          final isVisited    = provider.visitedLandmarks.contains(freshLandmark.name);
          final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
          final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);
          final countryProvider = context.read<CountryProvider>();

          Color? themeColor;
          if (freshLandmark.countriesIsoA3.isNotEmpty) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            themeColor = c?.themeColor;
          }
          final finalColor      = themeColor ?? fallbackThemeColor;
          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(children: [
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
                              colors: [finalColor, finalColor.withOpacity(0.85)],
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
                              colors: [
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: headerTextColor,
                                    foregroundColor: finalColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  ),
                                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(freshLandmark.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  color: headerTextColor,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))],
                                )),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, size: 13, color: headerTextColor.withOpacity(0.9)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          countryNames,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: headerTextColor.withOpacity(0.95),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isVisited) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 13, color: finalColor),
                                        const SizedBox(width: 4),
                                        Text('Visited',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: finalColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLandmarkHeroImage(freshLandmark),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        const Text('Wishlist:'),
                        IconButton(
                            icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border,
                                color: isWishlisted ? Colors.red : Colors.grey),
                            onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)),
                      ]),
                      RatingBar.builder(
                          initialRating: freshLandmark.rating ?? 0.0,
                          allowHalfRating: true, itemSize: 28,
                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                    ]),
                    const Divider(height: 20),

                    // ── Visit History ───────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('History (${freshLandmark.visitDates.length} entries)',
                          style: Theme.of(sheetContext).textTheme.titleSmall),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Visit'),
                        onPressed: () => provider.addVisitDate(freshLandmark.name),
                      ),
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
                    else
                      const Center(child: Text('No visits recorded.')),

                    const Divider(height: 24),
                    LandmarkInfoCard(
                        overview: freshLandmark.overview,
                        historySignificance: freshLandmark.history_significance,
                        highlights: freshLandmark.highlights,
                        themeColor: finalColor),
                  ]),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider        = context.watch<LandmarksProvider>();
    final countryProvider = context.read<CountryProvider>();

    // 로그 집계
    List<_VisitLogItem> logs = [];
    for (var site in provider.allLandmarks) {
      final total = site.visitDates.length;
      for (int i = 0; i < total; i++) {
        logs.add(_VisitLogItem(site: site, visit: site.visitDates[i], nthVisit: total - i));
      }
    }
    logs.sort((a, b) {
      final da = DateTime(a.visit.year ?? 0, a.visit.month ?? 1, a.visit.day ?? 1);
      final db = DateTime(b.visit.year ?? 0, b.visit.month ?? 1, b.visit.day ?? 1);
      return db.compareTo(da);
    });

    Map<String, List<_VisitLogItem>> grouped = {};
    if (_logGroupOption == LogGroupOption.year) {
      for (var log in logs) {
        grouped.putIfAbsent(log.visit.year.toString(), () => []).add(log);
      }
    } else {
      for (var log in logs) {
        final iso  = log.site.countriesIsoA3.isNotEmpty ? log.site.countriesIsoA3.first : 'Other';
        final name = countryProvider.isoToCountryNameMap[iso] ?? iso;
        grouped.putIfAbsent(name, () => []).add(log);
      }
    }

    final keys = grouped.keys.toList();
    if (_logGroupOption == LogGroupOption.year) {
      keys.sort((a, b) => b.compareTo(a));
    } else {
      keys.sort();
    }

    final totalLogs = logs.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 헤더 ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _kTheme,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Visit Log',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: Color(0xFF111827), letterSpacing: -0.6, height: 1.1)),
                      Text('$totalLogs total entries',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                    ])),
                    // 그룹 토글 — 작은 세그먼트 형태
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _buildToggle('Year', _logGroupOption == LogGroupOption.year,
                                () => setState(() => _logGroupOption = LogGroupOption.year)),
                        _buildToggle('Country', _logGroupOption == LogGroupOption.country,
                                () => setState(() => _logGroupOption = LogGroupOption.country)),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ─────────────────────────────────────────────────
            Expanded(
              child: logs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_edu_rounded, size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No visits recorded yet', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ]))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final key   = keys[index];
                  final items = grouped[key]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 그룹 헤더
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                        child: Row(children: [
                          Container(width: 3, height: 16,
                              decoration: BoxDecoration(color: _kTheme, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(key,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827), letterSpacing: -0.3)),
                          const SizedBox(width: 8),
                          Text('${items.length}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        ]),
                      ),
                      ...items.map((log) => _buildLogTile(log, countryProvider)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))] : [],
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? _kTheme : Colors.grey[500],
            )),
      ),
    );
  }

  Widget _buildLogTile(_VisitLogItem item, CountryProvider cp) {
    String dateStr = '${item.visit.year}';
    if (item.visit.month != null && item.visit.month != -9999) {
      dateStr += '-${item.visit.month.toString().padLeft(2, '0')}';
      if (item.visit.day != null && item.visit.day != -9999) {
        dateStr += '-${item.visit.day.toString().padLeft(2, '0')}';
      }
    }

    final hasTitle = item.visit.title.isNotEmpty;

    return InkWell(
      onTap: () => _showLandmarkDetailsModal(context, item.site, _kTheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          // 국기
          SizedBox(width: 28, child: _buildFlag(item.site, cp)),
          const SizedBox(width: 12),
          // 텍스트
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.site.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(
              hasTitle ? '${item.visit.title}  ·  $dateStr' : dateStr,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ])),
          const SizedBox(width: 8),
          // 별점
          if (item.site.rating != null && item.site.rating! > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
              const SizedBox(width: 2),
              Text(item.site.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151))),
            ]),
        ]),
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────

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
  @override bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─── Visit Editor Card (title/memo 저장 + 날짜 변경 + edit/save/cancel) ─────────

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
        year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999, photos: _currentPhotos);
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

  Widget _buildPhotoPreview(String path, int i) => Stack(clipBehavior: Clip.none, children: [
    Container(width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover))),
    if (_isEditing) Positioned(top: -6, right: 6,
        child: GestureDetector(onTap: () => setState(() => _currentPhotos.removeAt(i)),
            child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.cancel, color: Colors.red, size: 22)))),
  ]);

  @override
  Widget build(BuildContext context) {
    final tc = _kTheme;
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController, initiallyExpanded: _isEditing,
        title: Text(_displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text('Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                      child: const Text('Delete', style: TextStyle(color: Colors.red))),
                ]))),
        children: [Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isEditing) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: tc, foregroundColor: Colors.white, elevation: 0)),
              ] else
                OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(foregroundColor: tc,
                        side: BorderSide(color: tc.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}

/// 여러 후보 URL을 동시에 요청해서, 먼저 성공하는 것을 보여주는 위젯.
/// 후보 파일들은 서로 배타적으로만 존재한다는 전제(iso와 m이 동시에 있지 않음).
class _FallbackNetworkImage extends StatefulWidget {
  final List<String> urls;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder emptyBuilder;

  const _FallbackNetworkImage({
    required this.urls,
    required this.placeholderBuilder,
    required this.emptyBuilder,
  });

  @override
  State<_FallbackNetworkImage> createState() => _FallbackNetworkImageState();
}

class _FallbackNetworkImageState extends State<_FallbackNetworkImage> {
  Set<String> _failed = {};

  @override
  void didUpdateWidget(covariant _FallbackNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 랜드마크(후보 리스트)가 바뀌면 실패 기록 초기화
    if (!listEquals(oldWidget.urls, widget.urls)) {
      _failed = {};
    }
  }

  void _markFailed(String url) {
    if (!_failed.contains(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _failed = {..._failed, url});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return widget.emptyBuilder(context);

    final allFailed = widget.urls.every(_failed.contains);
    if (allFailed) {
      return widget.emptyBuilder(context);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 모두 로딩/실패 상태일 때 보일 기본 배경 (스피너)
        widget.placeholderBuilder(context),
        // 후보들을 동시에 겹쳐서 요청 — 성공한 것만 위에 그려짐
        for (final url in widget.urls)
          if (!_failed.contains(url))
            CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (context, _) => const SizedBox.shrink(),
              errorWidget: (context, _, __) {
                _markFailed(url);
                return const SizedBox.shrink();
              },
            ),
      ],
    );
  }
}