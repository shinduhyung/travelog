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

class TopOrchestrasScreen extends StatelessWidget {
  const TopOrchestrasScreen({super.key});

  static final List<Map<String, dynamic>> _topOrchestras = [
    {'rank': 1, 'name': 'Berlin Philharmonie', 'orchestra': 'Berlin Philharmonic', 'iso': 'DE'},
    {'rank': 2, 'name': 'Musikverein', 'orchestra': 'Vienna Philharmonic', 'iso': 'AT'},
    {'rank': 3, 'name': 'Royal Concertgebouw', 'orchestra': 'Royal Concertgebouw Orchestra', 'iso': 'NL'},
    {'rank': 4, 'name': 'Herkulessaal', 'orchestra': 'Bavarian Radio Symphony Orchestra', 'iso': 'DE'},
    {'rank': 5, 'name': 'Barbican Centre', 'orchestra': 'London Symphony Orchestra', 'iso': 'GB'},
    {'rank': 6, 'name': 'Symphony Center', 'orchestra': 'Chicago Symphony Orchestra', 'iso': 'US'},
    {'rank': 7, 'name': 'Severance Hall', 'orchestra': 'Cleveland Orchestra', 'iso': 'US'},
    {'rank': 8, 'name': 'Symphony Hall', 'orchestra': 'Boston Symphony Orchestra', 'iso': 'US'},
    {'rank': 9, 'name': 'Gewandhaus', 'orchestra': 'Leipzig Gewandhaus Orchestra', 'iso': 'DE'},
    {'rank': 10, 'name': 'Semperoper', 'orchestra': 'Staatskapelle Dresden', 'iso': 'DE'},
    {'rank': 11, 'name': 'David Geffen Hall', 'orchestra': 'New York Philharmonic', 'iso': 'US'},
    {'rank': 12, 'name': 'Walt Disney Concert Hall', 'orchestra': 'Los Angeles Philharmonic', 'iso': 'US'},
    {'rank': 13, 'name': 'Mariinsky Theatre', 'orchestra': 'Mariinsky Theatre Orchestra', 'iso': 'RU'},
    {'rank': 14, 'name': 'NHK Hall', 'orchestra': 'NHK Symphony Orchestra', 'iso': 'JP'},
    {'rank': 15, 'name': 'Müpa Budapest', 'orchestra': 'Budapest Festival Orchestra', 'iso': 'HU'},
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
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.music_note_outlined,
                          color: Color(0xFF6B4EFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Best Orchestras',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'World\'s finest symphony orchestras',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                physics: const BouncingScrollPhysics(),
                itemCount: _topOrchestras.length,
                itemBuilder: (context, index) {
                  final data = _topOrchestras[index];
                  final name = data['name'] as String;
                  final orchestra = data['orchestra'] as String;
                  final iso = data['iso'] as String;
                  final rank = data['rank'] as int;

                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, const Color(0xFF6B4EFF));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("$name details not found in database")),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isVisited
                            ? Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5)
                            : Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: rank <= 3
                                    ? [const Color(0xFF6B4EFF), const Color(0xFF8B6EFF)]
                                    : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: rank <= 3 ? Colors.white : const Color(0xFF6B6B6B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orchestra,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 32,
                              height: 24,
                              child: CountryFlag.fromCountryCode(iso),
                            ),
                          ),
                          if (isVisited) ...[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ],
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

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color themeColor) {
    final provider = context.read<LandmarksProvider>();
    final countryProvider = context.read<CountryProvider>();
    final isVisited = provider.visitedLandmarks.contains(landmark.name);
    final isWishlisted = provider.wishlistedLandmarks.contains(landmark.name);

    final countryNames = provider.getCountryNames(landmark.countriesIsoA3);
    final locationDisplay = countryNames.isNotEmpty
        ? '${landmark.city}, $countryNames'
        : landmark.city;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final headerTextColor = Colors.white;

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [themeColor, themeColor.withOpacity(0.8)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)),
                              style: ElevatedButton.styleFrom(backgroundColor: headerTextColor)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: Text(freshLandmark.name,
                                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                          if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(locationDisplay,
                                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                      color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                                Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                              ],
                            ),
                            const Divider(height: 20),
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
                            LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
    _memoController = TextEditingController(text: widget.visitDate.memo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(pickedFile.path);
      setState(() => _currentPhotos = newPhotos);
      context.read<LandmarksProvider>().updateLandmarkVisit(
          widget.landmarkName, widget.index, photos: newPhotos
      );
    }
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Container(
        width: 60, height: 60, margin: const EdgeInsets.only(right: 8), color: Colors.grey[300],
        child: Image.file(File(photoPath), fit: BoxFit.cover));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LandmarksProvider>();
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record'),
        subtitle: Text('Date: $_year-$_month-$_day'),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: widget.onDelete),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', isDense: true), onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text)),
                  const SizedBox(height: 8),
                  TextField(controller: _memoController, decoration: const InputDecoration(labelText: 'Memo', isDense: true), onEditingComplete: () => provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(ImageSource.gallery)), ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList()])),
                ]),
          )
        ],
      ),
    );
  }
}