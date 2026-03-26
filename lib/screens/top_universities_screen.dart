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

  static const Map<String, String> _isoA3ToA2 = {
    'KOR': 'KR', 'SWE': 'SE', 'JPN': 'JP', 'JAP': 'JP',
    'USA': 'US', 'GBR': 'GB', 'UK': 'GB', 'ENG': 'GB',
    'CHN': 'CN', 'CAN': 'CA', 'AUS': 'AU', 'CHE': 'CH',
    'SUI': 'CH', 'IRL': 'IE', 'IRE': 'IE', 'DEU': 'DE',
    'GER': 'DE', 'FRA': 'FR', 'NLD': 'NL', 'NED': 'NL',
    'ITA': 'IT', 'ESP': 'ES', 'SPA': 'ES', 'SGP': 'SG',
    'SIN': 'SG', 'HKG': 'HK', 'HK': 'HK',
  };

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

    if (shortNameMap.containsKey(name)) {
      return shortNameMap[name]!;
    }

    return name
        .replaceAll('University of ', 'U. of ')
        .replaceAll('University', 'Univ.')
        .replaceAll('Institute of Technology', 'Tech')
        .replaceAll('and', '&');
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank <= 5) return const Color(0xFFFFB300);
    if (rank <= 10) return const Color(0xFFFFA000);
    if (rank <= 25) return const Color(0xFF94A3B8);
    if (rank <= 50) return const Color(0xFFCD7F32);
    return const Color(0xFF9CA3AF);
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
            // ── 페이지 헤더 (개선) ───────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 작은 라벨
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B9CAE).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.school_rounded,
                                size: 12, color: Color(0xFF7B9CAE)),
                            SizedBox(width: 4),
                            Text(
                              'QS World Rankings',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7B9CAE),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 메인 타이틀 — "Top 100" 강조
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Top ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: '100',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF7B9CAE),
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: '\nUniversities',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "World's most prestigious institutions",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: const Color(0xFFF3F4F6)),

            // ── 리스트 ────────────────────────────────────────────────
            Expanded(
              child: landmarksProvider.isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF7B9CAE)))
                  : universityList.isEmpty
                  ? const Center(
                  child: Text('No university data found.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                physics: const BouncingScrollPhysics(),
                itemCount: universityList.length,
                itemBuilder: (context, index) {
                  final university = universityList[index];
                  final isVisited = landmarksProvider
                      .visitedLandmarks
                      .contains(university.name);

                  final String isoA3 =
                  university.countriesIsoA3.isNotEmpty
                      ? university.countriesIsoA3[0]
                      .trim()
                      .toUpperCase()
                      : '';
                  String flagIso = _isoA3ToA2[isoA3] ??
                      (isoA3.length >= 2
                          ? isoA3.substring(0, 2)
                          : '');

                  final rankColor =
                  _getRankColor(university.attribute_rank);

                  return GestureDetector(
                    onTap: () => _showLandmarkDetailsModal(context,
                        university, const Color(0xFF7B9CAE)),
                    child: Container(
                      margin:
                      const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isVisited
                            ? Border.all(
                            color: Colors.teal.withOpacity(0.5),
                            width: 1.5)
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
                          // ── 랭크 숫자 (새 스타일) ──────────
                          SizedBox(
                            width: 46,
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              crossAxisAlignment:
                              CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${university.attribute_rank}',
                                  style: TextStyle(
                                    fontSize:
                                    university.attribute_rank >=
                                        100
                                        ? 19
                                        : 23,
                                    fontWeight: FontWeight.w900,
                                    color: rankColor,
                                    letterSpacing: -1.0,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 2,
                                  width: 18,
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.3),
                                    borderRadius:
                                    BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ── 국기 ─────────────────────────
                          if (flagIso.isNotEmpty)
                            ClipRRect(
                              borderRadius:
                              BorderRadius.circular(4),
                              child: SizedBox(
                                width: 32,
                                height: 24,
                                child: CountryFlag.fromCountryCode(
                                    flagIso),
                              ),
                            ),
                          const SizedBox(width: 14),
                          // ── 이름 + 도시 ───────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getShortenedName(university.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${university.city}, ${landmarksProvider.getCountryNames(university.countriesIsoA3)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7B9CAE)
                                        .withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // ── 방문 여부 ─────────────────────
                          if (isVisited)
                            Container(
                              margin:
                              const EdgeInsets.only(left: 12),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 16),
                            )
                          else
                            Container(
                              margin:
                              const EdgeInsets.only(left: 12),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey[300]!),
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

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark,
      Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
        final headerTextColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(
                    top: 16, left: 16, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: headerTextColor,
                                    fontWeight: FontWeight.w600))),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: headerTextColor),
                            child: Text('Done',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: themeColor))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: Text(freshLandmark.name,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                    color: headerTextColor))),
                        if (isVisited)
                          Icon(Icons.check_circle,
                              color: headerTextColor, size: 24),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14,
                            color: headerTextColor.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(locationDisplay,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                    color: headerTextColor.withOpacity(0.8),
                                    fontWeight: FontWeight.normal))),
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
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('Wishlist:'),
                              IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                      isWishlisted
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isWishlisted
                                          ? Colors.red
                                          : Colors.grey),
                                  onPressed: () =>
                                      provider.toggleWishlistStatus(
                                          freshLandmark.name))
                            ]),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('My Rating:'),
                              const SizedBox(width: 8),
                              RatingBar.builder(
                                  initialRating: freshLandmark.rating ?? 0.0,
                                  minRating: 0,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 28.0,
                                  itemBuilder: (context, _) => const Icon(
                                      Icons.star, color: Colors.amber),
                                  onRatingUpdate: (rating) =>
                                      provider.updateLandmarkRating(
                                          freshLandmark.name, rating))
                            ]),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'History (${freshLandmark.visitDates.length} entries)',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleSmall),
                              OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Visit'),
                                  onPressed: () => provider
                                      .addVisitDate(freshLandmark.name))
                            ]),
                        const SizedBox(height: 8),
                        if (freshLandmark.visitDates.isNotEmpty)
                          ...freshLandmark.visitDates
                              .asMap()
                              .entries
                              .map((entry) => _LandmarkVisitEditorCard(
                            key: ValueKey(
                                '${freshLandmark.name}_${entry.key}'),
                            landmarkName: freshLandmark.name,
                            visitDate: entry.value,
                            index: entry.key,
                            onDelete: () =>
                                provider.removeVisitDate(
                                    freshLandmark.name, entry.key),
                            availableLocations:
                            freshLandmark.locations,
                          ))
                        else
                          const Center(child: Text('No visits recorded.')),
                        const Divider(height: 24),
                        LandmarkInfoCard(
                            overview: freshLandmark.overview,
                            historySignificance:
                            freshLandmark.history_significance,
                            highlights: freshLandmark.highlights,
                            themeColor: themeColor),
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

// ─────────────────────────────────────────────────────────────────────────────
// Visit Editor Card  (title/memo 저장 + 날짜 변경 + edit/save/cancel)
// ─────────────────────────────────────────────────────────────────────────────

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
  State<_LandmarkVisitEditorCard> createState() =>
      _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState
    extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;

  late String _displayTitle;
  late String _displayMemo;
  bool _isEditing = false;

  final ExpansionTileController _expansionTileController =
  ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo = widget.visitDate.memo ?? '';

    _titleController = TextEditingController(text: _displayTitle);
    _memoController = TextEditingController(text: _displayMemo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;

    if (_displayTitle.isEmpty &&
        _displayMemo.isEmpty &&
        _currentPhotos.isEmpty) {
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
      widget.landmarkName,
      widget.index,
      title: _titleController.text,
      memo: _memoController.text,
      year: _year ?? -9999,
      month: _month ?? -9999,
      day: _day ?? -9999,
      photos: _currentPhotos,
    );

    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text = _displayMemo;
      _year = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime(
      _year ?? DateTime.now().year,
      _month ?? DateTime.now().month,
      _day ?? DateTime.now().day,
    );
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
        _day = picked.day;
      });
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      setState(() => _currentPhotos.add(pickedFile.path));
    }
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(photoPath), fit: BoxFit.cover),
          ),
        ),
        if (_isEditing)
          Positioned(
            top: -6,
            right: 6,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _currentPhotos.removeAt(index)),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel,
                    color: Colors.red, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(
          _displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Date: $_year-$_month-$_day',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.red, size: 22),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text(
                    'Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Visit Date: $_year-$_month-$_day',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Edit Date'),
                        onPressed: () => _selectDate(context),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Memo',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ] else ...[
                  if (_displayMemo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _displayMemo,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.4),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                if (_currentPhotos.isNotEmpty || _isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          if (_isEditing)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.shade300),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.grey),
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                              ),
                            ),
                          ..._currentPhotos
                              .asMap()
                              .entries
                              .map((e) =>
                              _buildPhotoPreview(e.value, e.key))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isEditing) ...[
                      TextButton(
                        onPressed: _cancelEditing,
                        child: Text('Cancel',
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Record'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(
                              color: themeColor.withOpacity(0.5)),
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
    );
  }
}