import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

// Models
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';

// Providers
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';

// Widgets
import 'package:jidoapp/widgets/landmark_info_card.dart';

// Screens
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  final Color primaryPink = const Color(0xFFEC4899);
  final Color bgLight = const Color(0xFFF8FAFC);
  final Color primaryBlue = const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final countryProvider = context.watch<CountryProvider>();
    final cityProvider = context.watch<CityProvider>();
    final landmarkProvider = context.watch<LandmarksProvider>();
    final airlineProvider = context.watch<AirlineProvider>();
    final airportProvider = context.watch<AirportProvider>();

    final favoriteCountries = countryProvider.allCountries
        .where((c) => countryProvider.wishlistedCountries.contains(c.name))
        .toList();

    final favoriteCities = cityProvider.allCities
        .where((c) => cityProvider.visitDetails[c.name]?.isWishlisted ?? false)
        .toList();

    final favoriteLandmarks = landmarkProvider.allLandmarks
        .where((l) => landmarkProvider.wishlistedLandmarks.contains(l.name))
        .toList();

    final favoriteAirports = airportProvider.allAirports
        .where((a) => airportProvider.isFavorite(a.iataCode))
        .toList();

    final favoriteAirlines = airlineProvider.airlines
        .where((a) => a.isFavorite)
        .toList();

    final bool isEmpty = favoriteCountries.isEmpty &&
        favoriteCities.isEmpty &&
        favoriteLandmarks.isEmpty &&
        favoriteAirports.isEmpty &&
        favoriteAirlines.isEmpty;

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 48),
              if (isEmpty)
                _buildEmptyState()
              else ...[
                _buildSection('Countries', Icons.public_outlined, favoriteCountries, (item) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CountryDetailScreen(country: item as Country),
                    ),
                  );
                }),
                const SizedBox(height: 56),
                _buildSection('Cities', Icons.location_city_outlined, favoriteCities, (item) {
                  if (item is City) {
                    _showCityDetailSheet(context, item.name, item.countryIsoA2);
                  }
                }),
                const SizedBox(height: 56),
                _buildSection('Landmarks', Icons.explore_outlined, favoriteLandmarks, (item) {
                  if (item is Landmark) {
                    _showLandmarkDetailsModal(context, item, primaryPink);
                  }
                }),
                const SizedBox(height: 56),
                _buildSection('Airports', Icons.local_airport_outlined, favoriteAirports, (item) {
                  // Airport implementation placeholder
                }),
                const SizedBox(height: 56),
                _buildSection('Airlines', Icons.flight_takeoff_outlined, favoriteAirlines, (item) {
                  // Airline implementation placeholder
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'My Favorites',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: primaryPink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No favorites added yet.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<dynamic> items, Function(dynamic) onTap) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildFavoriteCard(item, onTap);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(dynamic item, Function(dynamic) onTap) {
    String name = '';
    String? countryCode;
    String? imageAsset;
    Color? accentColor;

    if (item is Country) {
      name = item.name;
      countryCode = item.isoA2;
      accentColor = item.themeColor;
    } else if (item is City) {
      name = item.name;
      countryCode = item.countryIsoA2;
    } else if (item is Landmark) {
      name = item.name;
      countryCode = item.countriesIsoA3.isNotEmpty ? item.countriesIsoA3.first : null;
    } else if (item is Airport) {
      name = item.name;
      countryCode = item.country;
    } else if (item is Airline) {
      name = item.name;
      imageAsset = 'assets/av/${item.code3}.png';
    }

    return GestureDetector(
      onTap: () => onTap(item),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _buildCardContent(name, countryCode, imageAsset, accentColor),
      ),
    );
  }

  Widget _buildCardContent(String name, String? countryCode, String? imageAsset, Color? accentColor) {
    if (imageAsset != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.flight,
                    color: Colors.grey.shade300,
                    size: 40,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (countryCode != null)
              Container(
                width: 36,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CountryFlag.fromCountryCode(countryCode),
                ),
              )
            else if (accentColor != null)
              Icon(Icons.stars, color: accentColor, size: 24)
            else
              const Icon(Icons.favorite, color: Colors.pink, size: 24),
          ],
        ),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  void _showCityDetailSheet(BuildContext context, String cityName, String countryCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<CityProvider>(
        builder: (context, provider, child) {
          final cityVisitDetail = provider.getCityVisitDetail(cityName) ??
              CityVisitDetail(name: cityName, arrivalDate: '', departureDate: '', duration: '');
          final countryProvider = context.read<CountryProvider>();
          final countryModel = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == countryCode);
          final cityModel = provider.allCities.firstWhereOrNull((c) => c.name == cityName);
          final themeColor = countryModel?.themeColor ?? primaryBlue;

          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
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
                                colors: [
                                  themeColor,
                                  themeColor.withOpacity(0.9),
                                ],
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
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold))
                                    ),
                                    if (countryModel != null)
                                      Container(
                                          width: 40,
                                          height: 28,
                                          decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: headerTextColor.withOpacity(0.3))
                                          ),
                                          child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: CountryFlag.fromCountryCode(countryModel.isoA2)
                                          )
                                      ),
                                  ]
                              ),
                              const SizedBox(height: 12),
                              Row(
                                  children: [
                                    Expanded(
                                        child: Text(
                                            cityName,
                                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: headerTextColor)
                                        )
                                    ),
                                    if (cityVisitDetail.visitDateRanges.isNotEmpty)
                                      const Icon(Icons.verified, color: headerTextColor, size: 28),
                                  ]
                              ),
                              Text(
                                  countryModel?.name ?? countryCode,
                                  style: TextStyle(fontSize: 16, color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('My Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 4),
                              RatingBar.builder(initialRating: cityVisitDetail.rating, allowHalfRating: true, itemCount: 5, itemSize: 24, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(rating: rating))),
                            ]),
                            IconButton(icon: Icon(cityVisitDetail.isWishlisted ? Icons.favorite : Icons.favorite_border, color: cityVisitDetail.isWishlisted ? Colors.red : Colors.grey, size: 30), onPressed: () => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(isWishlisted: !cityVisitDetail.isWishlisted))),
                          ]),
                          const Divider(height: 40),
                          if (cityModel != null) ...[
                            _buildCityStatRow('Population', NumberFormat('#,###').format(cityModel.population), Icons.people_outline, themeColor),
                            const Divider(height: 40),
                          ],
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Visits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add'), onPressed: () {
                              final updated = cityVisitDetail.copyWith(visitDateRanges: [...cityVisitDetail.visitDateRanges, DateRange()]);
                              provider.updateCityVisitDetail(cityName, updated);
                            }),
                          ]),
                          const SizedBox(height: 8),
                          if (cityVisitDetail.visitDateRanges.isNotEmpty)
                            ...cityVisitDetail.visitDateRanges.asMap().entries.map((entry) => _FavoritesCityVisitCard(
                              key: ValueKey('${cityName}_visit_${entry.key}'),
                              range: entry.value,
                              onSave: (updated) => provider.updateCityDateRange(cityName, entry.key, updated),
                              onDelete: () => provider.removeCityDateRange(cityName, entry.key),
                            ))
                          else
                            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No visits recorded.'))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCityStatRow(String label, String value, IconData icon, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [
        Icon(icon, size: 20, color: themeColor),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Consumer<LandmarksProvider>(
        builder: (context, provider, child) {
          final freshLandmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == landmark.name) ?? landmark;
          final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
          final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
          final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);
          final countryProvider = context.read<CountryProvider>();
          Color? themeColor;
          if (freshLandmark.countriesIsoA3.isNotEmpty) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            themeColor = c?.themeColor;
          }
          final finalColor = themeColor ?? fallbackThemeColor;

          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                  children: [
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
                                    colors: [
                                      finalColor,
                                      finalColor.withOpacity(0.9),
                                    ],
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
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(sheetContext),
                                              child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))
                                          ),
                                          ElevatedButton(
                                              onPressed: () => Navigator.pop(sheetContext),
                                              style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                                              child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: finalColor))
                                          ),
                                        ]
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                        children: [
                                          Expanded(
                                              child: Text(
                                                  freshLandmark.name,
                                                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor)
                                              )
                                          ),
                                          if (isVisited)
                                            const Icon(Icons.check_circle, color: headerTextColor, size: 24)
                                        ]
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                              child: Text(
                                                  countryNames,
                                                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8))
                                              )
                                          )
                                        ]
                                    ),
                                  ]
                              ),
                            ),
                          ]
                      ),
                    ),
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                            children: [
                                              const Text('Wishlist:'),
                                              IconButton(
                                                  icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                                                  onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)
                                              )
                                            ]
                                        ),
                                        RatingBar.builder(
                                            initialRating: freshLandmark.rating ?? 0.0,
                                            allowHalfRating: true,
                                            itemSize: 28,
                                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                            onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)
                                        ),
                                      ]
                                  ),
                                  const Divider(height: 20),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Expanded(child: Text('History (${freshLandmark.visitDates.length} entries)',
                                        style: Theme.of(sheetContext).textTheme.titleSmall,
                                        overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
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
                                    ))
                                  else const Center(child: Text('No visits recorded.')),
                                  const Divider(height: 24),
                                  LandmarkInfoCard(
                                      overview: freshLandmark.overview,
                                      historySignificance: freshLandmark.history_significance,
                                      highlights: freshLandmark.highlights,
                                      themeColor: finalColor
                                  ),
                                ]
                            )
                        )
                    )
                  ]
              ),
            ),
          );
        },
      ),
    );
  }
}


// ─── Landmark Visit Editor Card ───────────────────────────────────────────────

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
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
      year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999,
      photos: _currentPhotos,
    );
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
    final tc = Theme.of(context).primaryColor;
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
                    style: OutlinedButton.styleFrom(foregroundColor: tc, side: BorderSide(color: tc.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}

class _FavoritesCityVisitCard extends StatelessWidget {
  final DateRange range;
  final Function(DateRange) onSave;
  final VoidCallback onDelete;

  const _FavoritesCityVisitCard({super.key, required this.range, required this.onSave, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    String displayDate = 'Select Dates';
    if (range.arrival != null || range.departure != null) {
      String arrival = range.arrival != null ? dateFormat.format(range.arrival!) : '...';
      String departure = range.departure != null ? dateFormat.format(range.departure!) : '...';
      displayDate = '$arrival - $departure';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
        title: Text(displayDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: range.userDefinedDuration != null ? Text('${range.userDefinedDuration} days') : null,
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            initialDateRange: (range.arrival != null && range.departure != null) ? DateTimeRange(start: range.arrival!, end: range.departure!) : null,
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            onSave(range.copyWith(arrival: picked.start, departure: picked.end, userDefinedDuration: picked.end.difference(picked.start).inDays + 1));
          }
        },
      ),
    );
  }
}