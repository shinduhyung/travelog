// lib/screens/airports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/airport_stats_screen.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:collection/collection.dart';

// Map color mode enum
enum AirportColorMode { singleColor, byUseCount, byRating }

// Sorting options enum
enum AirportSortOption {
  alphabetical,
  byCounts,
  lastVisitDate,
  byRatings,
  myHubs,
  favorites,
}

// --- Data Model Classes ---
class UseCountRange {
  int from;
  Color color;
  TextEditingController controller;

  UseCountRange({required this.from, required this.color})
      : controller = TextEditingController(text: from.toString());

  UseCountRange copyWith({int? from, Color? color}) {
    return UseCountRange(
      from: from ?? this.from,
      color: color ?? this.color,
    );
  }
}

class RatingCategory {
  double rating;
  Color color;

  RatingCategory({required this.rating, required this.color});

  RatingCategory copyWith({double? rating, Color? color}) {
    return RatingCategory(
      rating: rating ?? this.rating,
      color: color ?? this.color,
    );
  }
}

class AirportsScreen extends StatefulWidget {
  final String? initialAirportIata;

  const AirportsScreen({super.key, this.initialAirportIata});

  @override
  State<AirportsScreen> createState() => _AirportsScreenState();
}

class _AirportsScreenState extends State<AirportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final MapController _mapController = MapController();
  LatLngBounds? _currentMapBounds;

  AirportColorMode _colorMode = AirportColorMode.byUseCount;
  AirportSortOption _currentSortOption = AirportSortOption.byCounts;

  // --- Default Values ---
  Color _getDefaultSingleUseColor() => Colors.brown.shade400;
  Color _getDefaultHubColor() => Colors.black;
  bool _isHubColorEnabled = true;
  final Color _wineColor = Colors.red.shade800;

  List<UseCountRange> _getDefaultUseCountRanges() => [
    UseCountRange(from: 1, color: Colors.blue.shade200),
    UseCountRange(from: 2, color: Colors.blue.shade400),
    UseCountRange(from: 3, color: Colors.blue.shade600),
    UseCountRange(from: 4, color: Colors.blue.shade800),
    UseCountRange(from: 5, color: Colors.indigo.shade900),
  ];

  List<RatingCategory> _getDefaultRatingCategories() => [
    RatingCategory(rating: 1.0, color: Colors.red.shade300),
    RatingCategory(rating: 2.0, color: Colors.orange.shade400),
    RatingCategory(rating: 3.0, color: Colors.yellow.shade600),
    RatingCategory(rating: 4.5, color: Colors.green.shade700),
  ];

  late Color _singleUseColor;
  late List<UseCountRange> _useCountRanges;
  late List<RatingCategory> _ratingCategories;
  late Color _hubColor;

  bool _initialModalShown = false;

  @override
  void initState() {
    super.initState();
    _singleUseColor = _getDefaultSingleUseColor();
    _useCountRanges = _getDefaultUseCountRanges();
    _ratingCategories = _getDefaultRatingCategories();
    _hubColor = _getDefaultHubColor();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialAirportIata != null && !_initialModalShown) {
      final provider = Provider.of<AirportProvider>(context, listen: false);
      if (!provider.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final airport = provider.allAirports.firstWhereOrNull(
                    (a) => a.iataCode == widget.initialAirportIata
            );
            if (airport != null) {
              _showAirportDetailsModal(airport);
              setState(() {
                _initialModalShown = true;
              });
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    for (var range in _useCountRanges) {
      range.controller.dispose();
    }
    super.dispose();
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  Color _getAirportColor(Airport airport, AirportProvider provider) {
    final isHub = provider.isHub(airport.iataCode);
    final isVisited = provider.isVisited(airport.iataCode);

    if (!isVisited) return Colors.transparent;

    if (isHub && _isHubColorEnabled) {
      return _hubColor;
    }

    return Colors.blue.shade200;
  }

  Widget _buildMap(AirportProvider airportProvider, CountryProvider countryProvider) {
    final usedAirports = airportProvider.allAirports
        .where((airport) => airportProvider.isVisited(airport.iataCode))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 220,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),
            Positioned(
              top: -20,
              left: -20,
              right: -20,
              bottom: -50,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(30, 0),
                  initialZoom: 0.3,
                  minZoom: 0.3,
                  maxZoom: 0.3,
                  backgroundColor: Colors.white,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  onMapReady: () {
                    setState(() {
                      _currentMapBounds = _mapController.camera.visibleBounds;
                    });
                  },
                  onPositionChanged: (position, hasGesture) {
                    setState(() {
                      _currentMapBounds = _mapController.camera.visibleBounds;
                    });
                  },
                ),
                children: [
                  PolygonLayer(
                    polygons: countryProvider.allCountries.expand((country) {
                      return country.polygonsData.map((polygonData) => Polygon(
                        points: polygonData.first,
                        holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                        color: Colors.grey.withOpacity(0.25),
                        borderColor: Colors.grey.withOpacity(0.3),
                        borderStrokeWidth: 0.3,
                        isFilled: true,
                      ));
                    }).toList(),
                  ),
                  MarkerLayer(
                    markers: usedAirports.map((airport) {
                      final color = _getAirportColor(airport, airportProvider);
                      return Marker(
                        width: 40.0,
                        height: 40.0,
                        point: LatLng(airport.latitude, airport.longitude),
                        child: Center(
                          child: Container(
                            width: 3.0,
                            height: 3.0,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemoAndPhotoDialog(BuildContext context, String iataCode, {int? useIndex, bool isForLounge = false}) {
    final provider = Provider.of<AirportProvider>(context, listen: false);

    final isPerUseMemo = useIndex != null;
    String initialMemo = '';
    List<String> initialPhotos = [];
    AirportVisitEntry? visitEntry;

    if (isForLounge && isPerUseMemo) {
      visitEntry = provider.getVisitEntries(iataCode)[useIndex - 1];
      initialMemo = visitEntry.loungeMemo ?? '';
      initialPhotos = visitEntry.loungePhotos;
    } else if (isPerUseMemo) {
      initialMemo = '';
      initialPhotos = [];
    } else {
      initialMemo = provider.getMemo(iataCode);
      initialPhotos = provider.getPhotos(iataCode);
    }

    final TextEditingController memoController = TextEditingController(text: initialMemo);
    List<String> currentPhotos = List.from(initialPhotos);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void _pickImage(ImageSource source) async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: source);

              if (pickedFile != null) {
                setStateDialog(() {
                  currentPhotos.add(pickedFile.path);
                });
              }
            }

            Widget _buildPhotoPreview(String photoPath, int index) {
              final file = File(photoPath);
              bool fileExists = file.existsSync();

              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400)
                    ),
                    child: fileExists
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Center(
                      child: Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                      onPressed: () {
                        setStateDialog(() {
                          currentPhotos.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(isForLounge && isPerUseMemo
                  ? 'Lounge Memo & Photos for Visit #${useIndex}'
                  : (isPerUseMemo ? 'Memo & Photos for Use #$useIndex' : 'Memo & Photos for $iataCode')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Memo:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: memoController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write your thoughts here...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext modalContext) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title: const Text('Photo Library'),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_camera),
                                        title: const Text('Camera'),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.blue),
                                  Text('Add Photo', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ...currentPhotos.asMap().entries.map((entry) {
                          return _buildPhotoPreview(entry.value, entry.key);
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    if (isForLounge && isPerUseMemo) {
                      provider.updateVisitEntry(
                        iataCode,
                        useIndex - 1,
                        loungeMemo: memoController.text,
                        loungePhotos: currentPhotos,
                      );
                    } else if (!isPerUseMemo) {
                      provider.updateMemoAndPhotos(
                          iataCode,
                          memoController.text,
                          currentPhotos
                      );
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown<T>(
      String hint, T? value, List<T?> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      items: items
          .map((item) => DropdownMenuItem<T>(
        value: item as T?,
        child: Text(
          item?.toString() ?? 'Unknown',
          style: TextStyle(
            fontSize: (item == null) ? 11.0 : 15.0,
            color: (item == null) ? Colors.grey.shade600 : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateSection(BuildContext context, AirportVisitEntry use, int index, AirportProvider provider) {
    int? year = use.year;
    int? month = use.month;
    int? day = use.day;

    final years = [
      null,
      ...List.generate(80, (i) => DateTime.now().year - i)
    ];
    final months = [null, ...List.generate(12, (i) => i + 1)];
    final days = [null, ...List.generate(31, (i) => i + 1)];

    final iataCode = provider.allAirports.firstWhere((a) => provider.getVisitEntries(a.iataCode).contains(use)).iataCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Visit Date', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                provider.updateVisitEntry(
                    iataCode,
                    index,
                    year: null,
                    month: null,
                    day: null
                );
              },
              tooltip: 'Clear Date',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildDropdown<int>(
                    'Year',
                    year,
                    years.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        year: val,
                      );
                    }
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Month',
                    month,
                    months.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        month: val,
                      );
                    }
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Day',
                    day,
                    days.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        day: val,
                      );
                    }
                )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUseDetails(BuildContext context, Airport airport, AirportProvider provider) {
    final uses = provider.getVisitEntries(airport.iataCode);
    final currentRating = provider.getRating(airport.iataCode);
    final isHub = provider.isHub(airport.iataCode);
    final isFavorite = provider.isFavorite(airport.iataCode);
    final loungeVisitCount = provider.getLoungeVisitCount(airport.iataCode);
    final averageLoungeRating = provider.getAverageLoungeRating(airport.iataCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text('My Hub'),
                  Checkbox(
                    value: isHub,
                    onChanged: (bool? value) {
                      provider.updateHubStatus(airport.iataCode, value ?? false);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Favorite'),
                  Checkbox(
                    value: isFavorite,
                    onChanged: (bool? value) {
                      provider.updateFavoriteStatus(airport.iataCode, value ?? false);
                    },
                  ),
                ],
              ),
              const Divider(height: 10),
              Row(
                children: [
                  Icon(Icons.wine_bar, color: _wineColor),
                  const SizedBox(width: 8),
                  Text('Business Lounge: $loungeVisitCount Visits'),
                ],
              ),
              if (loungeVisitCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Text('Average Rating: ', style: Theme.of(context).textTheme.bodySmall),
                      Icon(Icons.wine_bar, color: _wineColor, size: 20),
                      Text(
                        ' (${averageLoungeRating.toStringAsFixed(1)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Rating', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode),
                tooltip: 'Add Memo and Photos',
              ),
            ],
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 0,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 28.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.airplanemode_active,
              color: Colors.blue,
            ),
            onRatingUpdate: (rating) {
              provider.updateRating(airport.iataCode, rating);
            },
          ),
          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History (${uses.length} uses)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Use'),
                onPressed: () {
                  provider.addVisitEntry(airport.iataCode);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (uses.isNotEmpty)
            ...uses.asMap().entries.map((entry) {
              final index = entry.key;
              final use = entry.value;

              final isYearUnknown = use.year == null;
              final isMonthUnknown = use.month == null;
              final isDayUnknown = use.day == null;

              final dateText = (isYearUnknown ? '????' : use.year.toString()) +
                  '/' +
                  (isMonthUnknown ? '??' : use.month!.toString().padLeft(2, '0')) +
                  '/' +
                  (isDayUnknown ? '??' : use.day!.toString().padLeft(2, '0'));

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateSection(context, use, index, provider),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${index + 1}: ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                dateText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode, useIndex: index + 1),
                                tooltip: 'Add Memo for this Use',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'Remove this use',
                                onPressed: () {
                                  provider.removeVisitEntry(airport.iataCode, index);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Transfer', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isTransfer,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isTransfer: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Layover', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLayover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLayover: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Stopover', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isStopover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isStopover: value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.9,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Lounge Use', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      secondary: Icon(Icons.wine_bar, color: _wineColor, size: 16),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLoungeUsed,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLoungeUsed: value);
                                      },
                                    ),
                                  ),
                                ),
                                if (use.isLoungeUsed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: RatingBar.builder(
                                                initialRating: use.loungeRating ?? 0.0,
                                                minRating: 0,
                                                direction: Axis.horizontal,
                                                allowHalfRating: true,
                                                itemCount: 5,
                                                itemSize: 20.0,
                                                itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                                                itemBuilder: (context, _) => Icon(Icons.wine_bar, color: _wineColor),
                                                onRatingUpdate: (rating) {
                                                  provider.updateVisitEntry(airport.iataCode, index, loungeRating: rating);
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.note_alt_outlined, color: Colors.grey, size: 20),
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _showMemoAndPhotoDialog(
                                                context,
                                                airport.iataCode,
                                                useIndex: index + 1,
                                                isForLounge: true,
                                              ),
                                              tooltip: 'Add Lounge Memo & Photos for this visit',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Builder(
                                            builder: (context) {
                                              final totalMinutes = use.loungeDurationInMinutes ?? 0;
                                              final hours = totalMinutes ~/ 60;
                                              final minutes = totalMinutes % 60;

                                              final hourController = TextEditingController(text: hours == 0 ? '' : hours.toString());
                                              final minuteController = TextEditingController(text: minutes == 0 ? '' : minutes.toString());

                                              hourController.selection = TextSelection.fromPosition(TextPosition(offset: hourController.text.length));
                                              minuteController.selection = TextSelection.fromPosition(TextPosition(offset: minuteController.text.length));

                                              void updateDuration() {
                                                final h = int.tryParse(hourController.text) ?? 0;
                                                final m = int.tryParse(minuteController.text) ?? 0;
                                                final newTotalMinutes = (h * 60) + m;

                                                if (use.loungeDurationInMinutes != newTotalMinutes) {
                                                  provider.updateVisitEntry(
                                                    airport.iataCode,
                                                    index,
                                                    loungeDurationInMinutes: newTotalMinutes > 0 ? newTotalMinutes : null,
                                                  );
                                                }
                                              }

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: hourController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration: const InputDecoration(labelText: 'H', isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: minuteController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration: const InputDecoration(labelText: 'M', isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

          if (uses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(child: Text('No uses recorded yet. Press "Add Use" to start.')),
            ),
        ],
      ),
    );
  }

  void _showAirportDetailsModal(Airport airport) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext sheetContext) {
        return Consumer2<AirportProvider, CountryProvider>(
          builder: (context, airportProvider, countryProvider, child) {
            final useCount = airportProvider.getVisitCount(airport.iataCode);

            String countryName = airport.country;
            try {
              final matchedCountry = countryProvider.allCountries.firstWhere(
                      (c) => c.isoA2.toUpperCase() == airport.country.toUpperCase()
              );
              countryName = matchedCountry.name;
            } catch (_) {}

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                children: [
                  Container(
                    color: Colors.blue.shade800,
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${airport.name} (${airport.iataCode})',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                countryName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$useCount',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'uses',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildUseDetails(context, airport, airportProvider),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAirportExpansionTile(BuildContext context, Airport airport, AirportProvider provider) {
    final useCount = provider.getVisitCount(airport.iataCode);
    final isUsed = useCount > 0;
    final rating = provider.getRating(airport.iataCode);
    final isHub = provider.isHub(airport.iataCode);
    final isFavorite = provider.isFavorite(airport.iataCode);

    final tileBorderColor = isUsed ? Colors.blue.shade200 : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tileBorderColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAirportDetailsModal(airport),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getFlagEmoji(airport.country),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            airport.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isUsed ? Colors.grey.shade900 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  airport.iataCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isUsed) ...[
                                Icon(Icons.flight_takeoff, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '$useCount ${useCount == 1 ? 'use' : 'uses'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (rating > 0) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ] else
                                Text(
                                  'Not visited',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if ((isHub && _isHubColorEnabled) || isFavorite)
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                children: [
                  if (isFavorite)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.only(
                          bottomLeft: const Radius.circular(12),
                          topRight: (isHub && _isHubColorEnabled)
                              ? Radius.zero
                              : const Radius.circular(16),
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  if (isHub && _isHubColorEnabled)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _sortList(List<Airport> list, AirportSortOption option, AirportProvider provider) {
    switch (option) {
      case AirportSortOption.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case AirportSortOption.byCounts:
        list.sort((a, b) {
          final countA = provider.getVisitCount(a.iataCode);
          final countB = provider.getVisitCount(b.iataCode);
          return countB.compareTo(countA);
        });
        break;
      case AirportSortOption.lastVisitDate:
        list.sort((a, b) {
          final entriesA = provider.getVisitEntries(a.iataCode);
          final entriesB = provider.getVisitEntries(b.iataCode);

          if (entriesA.isEmpty && entriesB.isEmpty) return 0;
          if (entriesA.isEmpty) return 1;
          if (entriesB.isEmpty) return -1;

          final dateA = entriesA.map((e) => e.date ?? DateTime(1900)).reduce((d1, d2) => d1.isAfter(d2) ? d1 : d2);
          final dateB = entriesB.map((e) => e.date ?? DateTime(1900)).reduce((d1, d2) => d1.isAfter(d2) ? d1 : d2);

          return dateB.compareTo(dateA);
        });
        break;
      case AirportSortOption.byRatings:
        list.sort((a, b) {
          final ratingA = provider.getRating(a.iataCode);
          final ratingB = provider.getRating(b.iataCode);
          return ratingB.compareTo(ratingA);
        });
        break;
      case AirportSortOption.myHubs:
        list.sort((a, b) {
          final isHubA = provider.isHub(a.iataCode);
          final isHubB = provider.isHub(b.iataCode);

          if (isHubA && !isHubB) return -1;
          if (!isHubA && isHubB) return 1;
          return a.name.compareTo(b.name);
        });
        break;
      case AirportSortOption.favorites:
        list.sort((a, b) {
          final isFavA = provider.isFavorite(a.iataCode);
          final isFavB = provider.isFavorite(b.iataCode);

          if (isFavA && !isFavB) return -1;
          if (!isFavA && isFavB) return 1;
          return a.name.compareTo(b.name);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<AirportProvider, CountryProvider>(
        builder: (context, airportProvider, countryProvider, child) {
          if (airportProvider.isLoading || countryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (airportProvider.error != null) {
            return Center(child: Text('Error: ${airportProvider.error}'));
          }

          List<Airport> filteredList = airportProvider.allAirports.where((airport) {
            final query = _searchQuery.toLowerCase();
            final latLng = LatLng(airport.latitude, airport.longitude);
            final isInVisibleBounds = _currentMapBounds == null || _currentMapBounds!.contains(latLng);
            final matchesSearchQuery = query.isEmpty ||
                airport.name.toLowerCase().contains(query) ||
                airport.iataCode.toLowerCase().contains(query);

            final isMyHubMode = _currentSortOption == AirportSortOption.myHubs;
            final matchesMyHub = !isMyHubMode || airportProvider.isHub(airport.iataCode);

            final isFavoriteMode = _currentSortOption == AirportSortOption.favorites;
            final matchesFavorite = !isFavoriteMode || airportProvider.isFavorite(airport.iataCode);

            return isInVisibleBounds && matchesSearchQuery && matchesMyHub && matchesFavorite;
          }).toList();

          _sortList(filteredList, _currentSortOption, airportProvider);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  title: const Text(
                    'Airports',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 28,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[100]!.withOpacity(0.3),
                          Colors.cyan[50]!.withOpacity(0.2),
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        if (auth.user == null) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const LoginPromptScreen(),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AirportStatsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.analytics,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'View Statistics',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Explore your airport data',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _buildMap(airportProvider, countryProvider),
              ),

              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.grey[50],
                scrolledUnderElevation: 0,
                elevation: 0,
                automaticallyImplyLeading: false,
                toolbarHeight: 150,
                titleSpacing: 0,
                title: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: Colors.grey[50],
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search airports',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 24),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[500]),
                              onPressed: () => _searchController.clear(),
                            )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AirportSortOption>(
                            value: _currentSortOption,
                            icon: Icon(Icons.expand_more, color: Colors.grey[600]),
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: AirportSortOption.alphabetical,
                                child: Row(
                                  children: [
                                    Icon(Icons.sort_by_alpha, size: 20, color: Colors.grey),
                                    SizedBox(width: 10),
                                    Text('A-Z'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: AirportSortOption.byCounts,
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_up, size: 20, color: Colors.blue),
                                    SizedBox(width: 10),
                                    Text('Most Uses'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: AirportSortOption.lastVisitDate,
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 20, color: Colors.grey),
                                    SizedBox(width: 10),
                                    Text('Recent Visit'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: AirportSortOption.byRatings,
                                child: Row(
                                  children: [
                                    Icon(Icons.star, size: 20, color: Colors.amber),
                                    SizedBox(width: 10),
                                    Text('Top Rated'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: AirportSortOption.myHubs,
                                child: Row(
                                  children: [
                                    Icon(Icons.home, size: 20, color: Colors.black),
                                    SizedBox(width: 10),
                                    Text('My Hubs Only'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: AirportSortOption.favorites,
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite, size: 20, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Favorites Only'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (AirportSortOption? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _currentSortOption = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final airport = filteredList[index];
                    return _buildAirportExpansionTile(context, airport, airportProvider);
                  },
                  childCount: filteredList.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}