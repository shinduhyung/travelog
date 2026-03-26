// lib/screens/disneyland_screen.dart

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

class DisneylandScreen extends StatelessWidget {
  const DisneylandScreen({super.key});

  static final List<Map<String, dynamic>> _disneyParks = [
    {'name': 'Disneyland Paris',       'iso': 'FR'},
    {'name': 'Shanghai Disneyland',    'iso': 'CN'},
    {'name': 'Hong Kong Disneyland',   'iso': 'HK'},
    {'name': 'Tokyo Disneyland',       'iso': 'JP'},
    {'name': 'Walt Disney World Resort','iso': 'US'},
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks      = landmarksProvider.allLandmarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── A 스타일 헤더 ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(children: [
                // 상단 액센트 바
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFf5576c),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(0), topRight: Radius.circular(0)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 액자형 아이콘 박스
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFf5576c), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.castle_outlined, color: Color(0xFFf5576c), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Disneyland Parks',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: Color(0xFFf5576c), letterSpacing: 0.6)),
                          const SizedBox(height: 3),
                          const Text('Disneyland Parks',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827), letterSpacing: -0.5, height: 1.1)),
                          const SizedBox(height: 4),
                          Text('Magical theme parks around the world', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      // seen 뱃지 — progress pill
                      Consumer<LandmarksProvider>(builder: (context, provider, _) {
                        final seen = _disneyParks.where((m) => provider.visitedLandmarks.contains(m['name'])).length;
                        final pct  = 5 > 0 ? seen / 5 : 0.0;
                        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('$seen',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                                    color: Color(0xFFf5576c), height: 1.0)),
                            Padding(
                              padding: const EdgeInsets.only(left: 3, top: 6),
                              child: Text(' / 5',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: const Color(0xFFf5576c).withOpacity(0.45), height: 1.0)),
                            ),
                          ]),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 56,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(children: [
                                Container(height: 4, color: const Color(0xFFf5576c).withOpacity(0.12)),
                                FractionallySizedBox(
                                    widthFactor: pct,
                                    child: Container(height: 4, color: const Color(0xFFf5576c))),
                              ]),
                            ),
                          ),
                        ]);
                      }),
                    ],
                  ),
                ),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _disneyParks.length,
                itemBuilder: (context, index) {
                  final data      = _disneyParks[index];
                  final name      = data['name'] as String;
                  final iso       = data['iso'] as String;
                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark  = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, const Color(0xFFf5576c));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name details not found in database')));
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isVisited
                            ? Border.all(color: const Color(0xFFf5576c).withOpacity(0.5), width: 1.5)
                            : Border.all(color: Colors.grey[200]!),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(5),
                            child: SizedBox(width: 32, height: 24, child: CountryFlag.fromCountryCode(iso))),
                        const SizedBox(width: 16),
                        Expanded(child: Text(name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                            overflow: TextOverflow.ellipsis)),
                        if (isVisited)
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFf5576c).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                              child: Text('Visited',
                                  style: TextStyle(fontSize: 11, color: const Color(0xFFf5576c), fontWeight: FontWeight.w700)))
                        else
                          Container(width: 22, height: 22,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!))),
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
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider        = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();
        final freshLandmark   = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited       = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted    = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames    = provider.getCountryNames(freshLandmark.countriesIsoA3);

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '${countryNames}, ${freshLandmark.city}';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            landmarkThemeColor = country.themeColor;
          } catch (_) {}
        }

        final themeColor      = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

        return FractionallySizedBox(heightFactor: 0.85,
          child: Column(children: [
            Container(color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => Navigator.pop(sheetContext),
                        child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                    ElevatedButton(onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                        child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(freshLandmark.name,
                        style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                    if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(locationDisplay,
                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                  ]),
                ])),
            Expanded(child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'),
                    IconButton(visualDensity: VisualDensity.compact,
                        icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                        onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                  Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8),
                    RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0,
                        direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0,
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
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
                LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance,
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

// ─── Visit Editor Card (title/memo 저장 + 날짜 변경 + edit/save/cancel) ──────

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
      _titleController.text = _displayTitle;
      _memoController.text  = _displayMemo;
      _year  = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
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
    if (picked != null && mounted) setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
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
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Visit Record'),
              content: const Text('Are you sure you want to delete this visit record?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ))),
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
              ] else ...[
                OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(foregroundColor: themeColor, side: BorderSide(color: themeColor.withOpacity(0.5)))),
              ],
            ]),
          ]),
        )],
      ),
    );
  }
}