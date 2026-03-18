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

class TopUniversitiesScreen extends StatelessWidget {
  const TopUniversitiesScreen({super.key});

  // ISO A3 -> A2 맵 (국기 오류 수정본)
  static const Map<String, String> _isoA3ToA2 = {
    'KOR': 'KR', 'SWE': 'SE', 'JPN': 'JP', 'JAP': 'JP',
    'USA': 'US', 'GBR': 'GB', 'UK': 'GB', 'ENG': 'GB',
    'CHN': 'CN', 'CAN': 'CA', 'AUS': 'AU', 'CHE': 'CH',
    'SUI': 'CH', 'IRL': 'IE', 'IRE': 'IE', 'DEU': 'DE',
    'GER': 'DE', 'FRA': 'FR', 'NLD': 'NL', 'NED': 'NL',
    'ITA': 'IT', 'ESP': 'ES', 'SPA': 'ES', 'SGP': 'SG',
    'SIN': 'SG', 'HKG': 'HK', 'HK': 'HK',
  };

  // 요청하신 데이터 기반 대학교 이름 축약 메서드
  String _getShortenedName(String name) {
    final Map<String, String> shortNameMap = {
      'Massachusetts Institute of Technology (MIT)': 'MIT',
      'Imperial College London': 'Imperial College',
      'Stanford University': 'Stanford',
      'University of Oxford': 'Oxford',
      'Harvard University': 'Harvard',
      'University of Cambridge': 'Cambridge',
      'ETH Zurich': 'ETH Zurich',
      'National University of Singapore (NUS)': 'NUS',
      'University College London (UCL)': 'UCL',
      'California Institute of Technology (Caltech)': 'Caltech',
      'University of Hong Kong (HKU)': 'HKU',
      'Nanyang Technological University (NTU)': 'NTU',
      'University of Chicago': 'Chicago',
      'Peking University': 'Peking',
      'University of Pennsylvania': 'UPenn',
      'Cornell University': 'Cornell',
      'University of California, Berkeley (UC Berkeley)': 'UC Berkeley',
      'Tsinghua University': 'Tsinghua',
      'University of Melbourne': 'Melbourne',
      'University of New South Wales (UNSW Sydney)': 'UNSW Sydney',
      'Yale University': 'Yale',
      'EPFL (École Polytechnique Fédérale de Lausanne)': 'EPFL',
      'Technical University of Munich (TUM)': 'TUM',
      'Johns Hopkins University': 'Johns Hopkins',
      'Princeton University': 'Princeton',
      'University of Sydney': 'Sydney',
      'McGill University': 'McGill',
      'Paris Sciences et Lettres (PSL University)': 'PSL',
      'University of Toronto': 'Toronto',
      'Fudan University': 'Fudan',
      'King\'s College London': 'KCL',
      'Chinese University of Hong Kong (CUHK)': 'CUHK',
      'Australian National University (ANU)': 'ANU',
      'University of Edinburgh': 'Edinburgh',
      'University of Manchester': 'Manchester',
      'Monash University': 'Monash',
      'University of Tokyo': 'Tokyo',
      'Columbia University': 'Columbia',
      'Seoul National University': 'SNU',
      'University of British Columbia (UBC)': 'UBC',
      'École Polytechnique': 'École Polytechnique',
      'Northwestern University': 'Northwestern',
      'University of Queensland': 'Queensland',
      'Hong Kong University of Science and Technology (HKUST)': 'HKUST',
      'University of Michigan': 'Michigan',
      'UCLA (University of California, Los Angeles)': 'UCLA',
      'Delft University of Technology': 'TU Delft',
      'Shanghai Jiao Tong University': 'SJTU',
      'Zhejiang University': 'Zhejiang',
      'Yonsei University': 'Yonsei',
      'University of Bristol': 'Bristol',
      'Carnegie Mellon University': 'CMU',
      'University of Amsterdam': 'Amsterdam',
      'Hong Kong Polytechnic University': 'PolyU',
      'New York University': 'NYU',
      'London School of Economics': 'LSE',
      'Kyoto University': 'Kyoto',
      'Ludwig Maximilian University of Munich': 'LMU Munich',
      'Universiti Malaya': 'Malaya',
      'KU Leuven': 'KU Leuven',
      'Korea University': 'Korea',
      'Duke University': 'Duke',
      'City University of Hong Kong': 'CityU HK',
      'National Taiwan University': 'NTU Taiwan',
      'University of Auckland': 'Auckland',
      'University of California, San Diego (UCSD)': 'UCSD',
      'King Fahd University of Petroleum & Minerals (KFUPM)': 'KFUPM',
      'University of Texas at Austin': 'UT Austin',
      'Brown University': 'Brown',
      'University of Illinois Urbana-Champaign': 'UIUC',
      'Paris-Saclay University': 'Paris-Saclay',
      'Lund University': 'Lund',
      'Sorbonne University': 'Sorbonne',
      'University of Warwick': 'Warwick',
      'Trinity College Dublin': 'Trinity College',
      'University of Birmingham': 'Birmingham',
      'University of Western Australia': 'UWA',
      'KTH Royal Institute of Technology': 'KTH',
      'University of Glasgow': 'Glasgow',
      'Heidelberg University': 'Heidelberg',
      'University of Washington': 'Washington',
      'University of Adelaide': 'Adelaide',
      'Pennsylvania State University': 'Penn State',
      'University of Buenos Aires': 'UBA',
      'Tokyo Institute of Technology': 'Tokyo Tech',
      'University of Leeds': 'Leeds',
      'University of Southampton': 'Southampton',
      'Boston University': 'Boston',
      'Free University of Berlin': 'FU Berlin',
      'Purdue University': 'Purdue',
      'Osaka University': 'Osaka',
      'University of Sheffield': 'Sheffield',
      'Uppsala University': 'Uppsala',
      'Durham University': 'Durham',
      'University of Alberta': 'Alberta',
      'University of Technology Sydney (UTS)': 'UTS',
      'University of Nottingham': 'Nottingham',
      'Karlsruhe Institute of Technology (KIT)': 'KIT',
      'Politecnico di Milano': 'Polimi',
      'University of Zurich': 'Zurich',
    };

    // 맵에 있으면 짧은 이름 반환, 없으면 기본 일괄 축약 규칙 적용
    if (shortNameMap.containsKey(name)) {
      return shortNameMap[name]!;
    }

    return name
        .replaceAll('University of ', 'U. of ')
        .replaceAll('University', 'Univ.')
        .replaceAll('Institute of Technology', 'Tech')
        .replaceAll('and', '&');
  }

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks = landmarksProvider.allLandmarks;

    final List<Landmark> universityList = allLandmarks.where((l) {
      final bool isUniversity = l.attributes.contains('University');
      final int rank = l.attribute_rank;
      return isUniversity && rank >= 1 && rank <= 100;
    }).toList();

    universityList.sort((a, b) => a.attribute_rank.compareTo(b.attribute_rank));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Text(
                'Top 100 Universities',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: landmarksProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B9CAE)))
                  : universityList.isEmpty
                  ? const Center(child: Text('No university data found.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                physics: const BouncingScrollPhysics(),
                itemCount: universityList.length,
                itemBuilder: (context, index) {
                  final university = universityList[index];
                  final isVisited = landmarksProvider.visitedLandmarks.contains(university.name);

                  final String isoA3 = university.countriesIsoA3.isNotEmpty
                      ? university.countriesIsoA3[0].trim().toUpperCase()
                      : '';
                  String flagIso = _isoA3ToA2[isoA3] ?? (isoA3.length >= 2 ? isoA3.substring(0, 2) : '');

                  return GestureDetector(
                    onTap: () {
                      _showLandmarkDetailsModal(context, university, const Color(0xFF7B9CAE));
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
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#${university.attribute_rank}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (flagIso.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 32,
                                height: 24,
                                child: CountryFlag.fromCountryCode(flagIso),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getShortenedName(university.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${university.city}, ${landmarksProvider.getCountryNames(university.countriesIsoA3)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF7B9CAE).withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isVisited)
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[300]!),
                              ),
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

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (e) {
            landmarkThemeColor = null;
          }
        }

        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
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
                        Expanded(child: Text(locationDisplay, style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
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
            ],
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