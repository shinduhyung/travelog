// lib/screens/top_falls_screen.dart

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

const Color _kTheme = Color(0xFF6B9AB8);

class TopFallsScreen extends StatelessWidget {
  const TopFallsScreen({super.key});

  static final List<Map<String, dynamic>> _top20Falls = [
    {'rank': 1,  'name': 'Angel Falls',             'height': '979 m', 'iso': 'VE'},
    {'rank': 2,  'name': 'Tugela Falls',            'height': '948 m', 'iso': 'ZA'},
    {'rank': 3,  'name': 'Tres Hermanas Falls',     'height': '914 m', 'iso': 'PE'},
    {'rank': 4,  'name': 'Olo\'upena Falls',       'height': '900 m', 'iso': 'US'},
    {'rank': 5,  'name': 'Yumbilla Falls',          'height': '896 m', 'iso': 'PE'},
    {'rank': 6,  'name': 'Vinnufossen',             'height': '860 m', 'iso': 'NO'},
    {'rank': 7,  'name': 'Skorga',                  'height': '864 m', 'iso': 'NO'},
    {'rank': 8,  'name': 'Pu\'uka\'oku Falls',      'height': '840 m', 'iso': 'US'},
    {'rank': 9,  'name': 'James Bruce Falls',       'height': '840 m', 'iso': 'CA'},
    {'rank': 10, 'name': 'Browne Falls',            'height': '836 m', 'iso': 'NZ'},
    {'rank': 11, 'name': 'Strupenfossen',           'height': '820 m', 'iso': 'NO'},
    {'rank': 12, 'name': 'Ramnefjellsfossen',       'height': '818 m', 'iso': 'NO'},
    {'rank': 13, 'name': 'Waihilau Falls',          'height': '792 m', 'iso': 'US'},
    {'rank': 14, 'name': 'Colonial Creek Falls',    'height': '788 m', 'iso': 'US'},
    {'rank': 15, 'name': 'Mongefossen',             'height': '773 m', 'iso': 'NO'},
    {'rank': 16, 'name': 'Gocta Falls',             'height': '771 m', 'iso': 'PE'},
    {'rank': 17, 'name': 'Mutarazi Falls',          'height': '762 m', 'iso': 'ZW'},
    {'rank': 18, 'name': 'Kjelfossen',              'height': '755 m', 'iso': 'NO'},
    {'rank': 19, 'name': 'Johannesburg Falls',      'height': '752 m', 'iso': 'CA'},
    {'rank': 20, 'name': 'Yosemite Falls',          'height': '739 m', 'iso': 'US'},
  ];

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank <= 3) return const Color(0xFF94A3B8);
    if (rank <= 5) return const Color(0xFFCD7F32);
    return const Color(0xFF9CA3AF);
  }

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
            // ── 헤더 ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(0, 24, 24, 20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 5, height: 80,
                  margin: const EdgeInsets.only(right: 20),
                  decoration: const BoxDecoration(
                    color: _kTheme,
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                  ),
                ),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.water_drop_rounded, size: 14, color: _kTheme),
                    const SizedBox(width: 5),
                    const Text('Highest Falls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTheme, letterSpacing: 0.3)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Top 20 Highest',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -1.0, height: 1.1)),
                  const SizedBox(height: 4),
                  Text('The world\'s tallest waterfalls', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ])),
                Consumer<LandmarksProvider>(builder: (context, provider, _) {
                  final visited = _top20Falls.where((m) => provider.visitedLandmarks.contains(m['name'])).length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kTheme.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kTheme.withOpacity(0.2)),
                    ),
                    child: Column(children: [
                      Text('$visited', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kTheme, height: 1.0)),
                      const Text('/ 20', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTheme, height: 1.2)),
                      const SizedBox(height: 2),
                      const Text('visited', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _kTheme)),
                    ]),
                  );
                }),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ──────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _top20Falls.length,
                itemBuilder: (context, index) {
                  final data      = _top20Falls[index];
                  final name      = data['name'] as String;
                  final stat      = data['height'] as String;
                  final iso       = data['iso'] as String;
                  final rank      = data['rank'] as int;
                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark  = allLandmarks.firstWhereOrNull((l) => l.name == name);
                  final rankColor = _getRankColor(rank);
                  final rawNum    = double.tryParse(stat.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                  final barRatio  = (rawNum / 979).clamp(0.0, 1.0);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, _kTheme);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name details not found in database')));
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isVisited ? _kTheme.withOpacity(0.45) : Colors.grey[200]!, width: isVisited ? 1.5 : 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(children: [
                        Row(children: [
                          SizedBox(width: 36, child: Text('$rank',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: rank <= 3 ? 22 : 20, fontWeight: FontWeight.w900, color: rankColor, letterSpacing: -0.5, height: 1.0))),
                          const SizedBox(width: 10),
                          ClipRRect(borderRadius: BorderRadius.circular(4),
                              child: SizedBox(width: 30, height: 22, child: CountryFlag.fromCountryCode(iso))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Text('', style: TextStyle(color: _kTheme)), // spacer trick
                          Text(stat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTheme)),
                          const SizedBox(width: 10),
                          if (isVisited)
                            Container(padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 14))
                          else
                            Container(width: 22, height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const SizedBox(width: 46),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                              child: Stack(children: [
                                Container(height: 4, color: Colors.grey[100]),
                                FractionallySizedBox(widthFactor: barRatio,
                                    child: Container(height: 4,
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [_kTheme.withOpacity(0.5), _kTheme]),
                                            borderRadius: BorderRadius.circular(3)))),
                              ]))),
                        ]),
                      ]),
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
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider        = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();
        final freshLandmark   = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited       = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted    = provider.wishlistedLandmarks.contains(freshLandmark.name);
        const themeColor      = _kTheme;
        const headerTextColor = Colors.white;

        Widget buildFlags() {
          final isoA2List = freshLandmark.countriesIsoA3
              .map((a3) => countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == a3)?.isoA2)
              .whereType<String>().toList();
          if (isoA2List.isEmpty) return const SizedBox.shrink();
          return Wrap(spacing: 6, runSpacing: 4, children: isoA2List.map((a2) =>
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))]),
                child: ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: SizedBox(width: 32, height: 22, child: CountryFlag.fromCountryCode(a2))),
              )).toList());
        }

        return FractionallySizedBox(heightFactor: 0.85,
          child: Column(children: [
            Container(color: themeColor,
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
                    if (isVisited) const Padding(padding: EdgeInsets.only(left: 8, top: 4),
                        child: Icon(Icons.check_circle, color: headerTextColor, size: 24)),
                  ]),
                  const SizedBox(height: 10),
                  buildFlags(),
                ])),
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
                    RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0,
                        direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0,
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                  ]),
                ]),
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall),
                  OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'),
                      onPressed: () => provider.addVisitDate(freshLandmark.name)),
                ]),
                const SizedBox(height: 8),
                if (freshLandmark.visitDates.isNotEmpty)
                  ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                      key: ValueKey('${freshLandmark.name}_${entry.key}'),
                      landmarkName: freshLandmark.name, visitDate: entry.value, index: entry.key,
                      onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                      availableLocations: freshLandmark.locations))
                else const Center(child: Text('No visits recorded.')),
                const Divider(height: 24),
                LandmarkInfoCard(overview: freshLandmark.overview,
                    historySignificance: freshLandmark.history_significance,
                    highlights: freshLandmark.highlights, themeColor: themeColor),
                const SizedBox(height: 40),
              ]),
            ))),
          ]),
        );
      },
    );
  }
}

// ── Visit Editor Card ──────────────────────────────────────────────────────────

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;
  const _LandmarkVisitEditorCard({super.key, required this.landmarkName, required this.visitDate,
    required this.index, required this.onDelete, this.availableLocations});
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
    _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
  }

  @override void dispose() { _titleController.dispose(); _memoController.dispose(); super.dispose(); }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(context: context,
        initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
        firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (picked != null && mounted) {
      setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
      context.read<LandmarksProvider>().updateLandmarkVisit(widget.landmarkName, widget.index,
          year: picked.year, month: picked.month, day: picked.day);
    }
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(f.path);
      setState(() => _currentPhotos = newPhotos);
      context.read<LandmarksProvider>().updateLandmarkVisit(widget.landmarkName, widget.index, photos: newPhotos);
    }
  }

  Widget _buildPhotoPreview(String p, int i) => Container(
      width: 60, height: 60, margin: const EdgeInsets.only(right: 8), color: Colors.grey[300],
      child: Image.file(File(p), fit: BoxFit.cover));

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LandmarksProvider>();
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.edit_calendar_outlined, size: 13, color: Colors.grey[400]),
          ]),
        ),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: widget.onDelete),
        children: [Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', isDense: true),
                onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text),
                onTapOutside: (_) => provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text)),
            const SizedBox(height: 8),
            TextField(controller: _memoController, decoration: const InputDecoration(labelText: 'Memo', isDense: true),
                onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text),
                onTapOutside: (_) => provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_calendar, size: 16),
              label: Text('Change Date  ($_year-$_month-$_day)'),
              onPressed: () => _selectDate(context),
              style: OutlinedButton.styleFrom(foregroundColor: _kTheme, side: const BorderSide(color: _kTheme), visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(ImageSource.gallery)),
                  ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                ])),
          ]),
        )],
      ),
    );
  }
}