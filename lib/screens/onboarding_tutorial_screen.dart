// lib/screens/onboarding_tutorial_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:country_flags/country_flags.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/passport_provider.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';

const List<String> _defaultPopularCountries = [
  'France', 'United States', 'Spain', 'China', 'Italy',
  'United Kingdom', 'Germany', 'Mexico', 'Thailand', 'Turkey',
  'Austria', 'Malaysia', 'Hong Kong', 'Greece', 'Russia',
  'Japan', 'Canada', 'Saudi Arabia', 'Poland', 'South Korea',
];

String _landmarkImageUrl(String name) {
  final snake = name
      .toLowerCase()
      .replaceAll(RegExp(r"[''`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/countrydex%2F$snake.jpg?alt=media';
}

String _cityImageUrl(String name) {
  final snake = name
      .toLowerCase()
      .replaceAll(RegExp(r"[''`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/top_cities%2F$snake.png?alt=media';
}

// GAWC Alpha++ / Alpha+ 도시 목록 (상위 티어만)
const List<Map<String, String>> _gawcTopCities = [
  {'name': 'New York City', 'country': 'US', 'display': 'New York'},
  {'name': 'London', 'country': 'GB'},
  {'name': 'Singapore', 'country': 'SG'},
  {'name': 'Hong Kong', 'country': 'HK'},
  {'name': 'Dubai', 'country': 'AE'},
  {'name': 'Paris', 'country': 'FR'},
  {'name': 'Tokyo', 'country': 'JP'},
  {'name': 'Sydney', 'country': 'AU'},
  {'name': 'Beijing', 'country': 'CN'},
  {'name': 'Shanghai', 'country': 'CN'},
  {'name': 'Chicago', 'country': 'US'},
  {'name': 'Los Angeles', 'country': 'US'},
  {'name': 'Milan', 'country': 'IT'},
  {'name': 'Kuala Lumpur', 'country': 'MY', 'display': 'K.L.'},
  {'name': 'Toronto', 'country': 'CA'},
  {'name': 'Frankfurt', 'country': 'DE'},
  {'name': 'Amsterdam', 'country': 'NL'},
  {'name': 'Seoul', 'country': 'KR'},
  {'name': 'Madrid', 'country': 'ES'},
  {'name': 'Mexico City', 'country': 'MX'},
  {'name': 'São Paulo', 'country': 'BR'},
  {'name': 'Zurich', 'country': 'CH'},
  {'name': 'Mumbai', 'country': 'IN'},
  {'name': 'Istanbul', 'country': 'TR'},
];

class OnboardingTutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingTutorialScreen({super.key, required this.onComplete});

  @override
  State<OnboardingTutorialScreen> createState() =>
      _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState extends State<OnboardingTutorialScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  _LightCountry? _selectedHomeCountry;
  String _searchQuery = '';
  String? _selectedPassportIso; // 홈 국가 자동 설정, 별도 변경 가능
  final Set<String> _visitedHighlights = {};
  final Set<String> _visitedTopLandmarks = {}; // Step5: 글로벌 Top 50
  final Set<String> _visitedPopular = {};
  final Set<String> _visitedGawcCities = {};
  String? _selectedHubAirport; // Step 1: 홈 공항 선택
  final List<String> _popularList = List.from(_defaultPopularCountries);

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _animateToNext() {
    _fadeCtrl.reverse().then((_) {
      setState(() => _step++);
      _searchQuery = '';
      _fadeCtrl.forward();
      _slideCtrl..reset()..forward();
    });
  }

  void _finishOnboarding() {
    final countryProvider = context.read<CountryProvider>();
    final landmarksProvider = context.read<LandmarksProvider>();
    final cityProvider = context.read<CityProvider>();

    if (_selectedHomeCountry != null) {
      countryProvider.setVisitedStatus(_selectedHomeCountry!.name, true);
    }
    // 여권 선택 저장
    if (_selectedPassportIso != null) {
      final passportProvider = context.read<PassportProvider>();
      passportProvider.setSelectedPassport(_selectedPassportIso!);
    }
    // 허브 공항 저장
    if (_selectedHubAirport != null) {
      final airportProvider = context.read<AirportProvider>();
      airportProvider.updateHubStatus(_selectedHubAirport!, true);
      if (!airportProvider.isVisited(_selectedHubAirport!)) {
        airportProvider.addVisitEntry(_selectedHubAirport!);
      }
    }
    for (final lmName in _visitedHighlights) {
      if (!landmarksProvider.visitedLandmarks.contains(lmName)) {
        landmarksProvider.toggleVisitedStatus(lmName);
      }
    }
    for (final lmName in _visitedTopLandmarks) {
      if (!landmarksProvider.visitedLandmarks.contains(lmName)) {
        landmarksProvider.toggleVisitedStatus(lmName);
      }
    }
    for (final name in _visitedPopular) {
      countryProvider.setVisitedStatus(name, true);
    }
    for (final cityName in _visitedGawcCities) {
      if (!cityProvider.isVisited(cityName)) {
        cityProvider.setVisitedStatus(cityName, true);
      }
    }

    // 온보딩 완료 → 인앱 튜토리얼 대기 플래그 설정
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('pending_in_app_tutorial', true);
    });

    widget.onComplete();
  }

  void _showAddCountryDialog() {
    final countryProvider = context.read<CountryProvider>();
    String searchText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final all = countryProvider.allCountries;
            final filtered = searchText.isEmpty
                ? all
                : all.where((c) => c.name.toLowerCase().contains(searchText.toLowerCase())).toList();
            final available = (filtered.where((c) => !_popularList.contains(c.name)).toList()
              ..sort((a, b) => a.name.compareTo(b.name)));

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0FA8A5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Add a country',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setModalState(() => searchText = v),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          hintStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final c = available[i];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _popularList.add(c.name);
                              _visitedPopular.add(c.name);
                            });
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: SizedBox(width: 28, height: 19,
                                      child: CountryFlag.fromCountryCode(c.isoA2)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(c.name,
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14))),
                                const Icon(Icons.add, color: Colors.white70, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1ABFBC),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step0HomeCountry(
          searchQuery: _searchQuery,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          selectedCountry: _selectedHomeCountry,
          selectedPassportIso: _selectedPassportIso,
          onSelect: (c) {
            setState(() {
              _selectedHomeCountry = c;
              // 홈국 선택 시 여권 자동 설정
              _selectedPassportIso = c.isoA3;
            });
          },
          onPassportChanged: (iso) => setState(() => _selectedPassportIso = iso),
          onNext: _animateToNext,
        );
      case 1:
        return _Step1PassportAirport(
          country: _selectedHomeCountry!,
          selectedHubAirport: _selectedHubAirport,
          onSelectAirport: (iata) => setState(() => _selectedHubAirport = iata),
          onNext: _animateToNext,
        );
      case 2:
        return _Step2Highlights(
          country: _selectedHomeCountry!,
          visitedHighlights: _visitedHighlights,
          onToggle: (name) => setState(() => _visitedHighlights.contains(name)
              ? _visitedHighlights.remove(name) : _visitedHighlights.add(name)),
          onNext: _animateToNext,
        );
      case 3:
        return _Step3PopularCountries(
          popularList: _popularList,
          visitedPopular: _visitedPopular,
          homeCountryName: _selectedHomeCountry?.name,
          onToggle: (name) => setState(() => _visitedPopular.contains(name)
              ? _visitedPopular.remove(name) : _visitedPopular.add(name)),
          onAddCountry: _showAddCountryDialog,
          onFinish: _animateToNext,
        );
      case 4:
        return _Step4GawcCities(
          visitedCities: _visitedGawcCities,
          onToggle: (name) => setState(() => _visitedGawcCities.contains(name)
              ? _visitedGawcCities.remove(name) : _visitedGawcCities.add(name)),
          onFinish: _animateToNext,
        );
      case 5:
        return _Step5TopLandmarks(
          visitedLandmarks: _visitedTopLandmarks,
          onToggle: (name) => setState(() => _visitedTopLandmarks.contains(name)
              ? _visitedTopLandmarks.remove(name) : _visitedTopLandmarks.add(name)),
          onFinish: _finishOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step 1 ── 여권 + 홈 공항 선택 ──────────────────────────────────────────
class _Step1PassportAirport extends StatefulWidget {
  final _LightCountry country;
  final String? selectedHubAirport;
  final ValueChanged<String?> onSelectAirport;
  final VoidCallback onNext;

  const _Step1PassportAirport({
    required this.country,
    required this.selectedHubAirport,
    required this.onSelectAirport,
    required this.onNext,
  });

  @override
  State<_Step1PassportAirport> createState() => _Step1PassportAirportState();
}

class _Step1PassportAirportState extends State<_Step1PassportAirport> {
  Map<String, List<String>> _hubAirports = {};
  bool _loadingHub = true;

  @override
  void initState() {
    super.initState();
    _loadHubAirports();
  }

  Future<void> _loadHubAirports() async {
    try {
      final String jsonStr =
      await rootBundle.loadString('assets/hub_airport.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      setState(() {
        _hubAirports = data.map((k, v) =>
            MapEntry(k, List<String>.from(v as List)));
        _loadingHub = false;
      });
    } catch (e) {
      setState(() => _loadingHub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isoA3 = widget.country.isoA3;
    final airportList = _hubAirports[isoA3] ?? [];
    final airportProvider = context.read<AirportProvider>();

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          _AnimatedTitle(
            title: 'Home airport',
            subtitle: 'Select your most-used airport in ${widget.country.name}',
          ),
          const SizedBox(height: 16),

          // ── 공항 리스트 ──
          Expanded(
            child: _loadingHub
                ? const Center(
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2))
                : airportList.isEmpty
                ? Center(
                child: Text('No airports found',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 14)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              itemCount: airportList.length,
              itemBuilder: (context, i) {
                final iata = airportList[i];
                final isSelected =
                    widget.selectedHubAirport == iata;

                // airport 이름 찾기
                Airport? airport;
                try {
                  airport = airportProvider.allAirports
                      .firstWhere((a) => a.iataCode == iata);
                } catch (_) {}

                return GestureDetector(
                  onTap: () => widget.onSelectAirport(
                      isSelected ? null : iata),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.28)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withOpacity(0.7)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              iata,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                airport?.name ?? iata,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          _BottomButton(
            label: 'CONTINUE',
            enabled: widget.selectedHubAirport != null,
            subLabel: widget.selectedHubAirport == null ? 'Skip if none' : null,
            onTap: widget.onNext,
            onSkip: widget.onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 0 ──────────────────────────────────────────────────────────────────
class _Step0HomeCountry extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final _LightCountry? selectedCountry;
  final String? selectedPassportIso;
  final ValueChanged<_LightCountry> onSelect;
  final ValueChanged<String> onPassportChanged;
  final VoidCallback onNext;

  const _Step0HomeCountry({
    required this.searchQuery, required this.onSearchChanged,
    required this.selectedCountry, required this.selectedPassportIso,
    required this.onSelect, required this.onPassportChanged,
    required this.onNext,
  });

  @override
  State<_Step0HomeCountry> createState() => _Step0HomeCountryState();
}

class _Step0HomeCountryState extends State<_Step0HomeCountry> {
  // 경량 국가 데이터 — CountryProvider 완료 전에도 즉시 표시
  List<_LightCountry> _lightCountries = [];
  bool _lightLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLightCountries();
  }

  Future<void> _loadLightCountries() async {
    try {
      final String jsonStr =
      await rootBundle.loadString('assets/countries_light.json');
      final List<dynamic> data = json.decode(jsonStr);
      if (mounted) {
        setState(() {
          _lightCountries = data
              .map((e) => _LightCountry(
            name: e['name'] as String,
            isoA2: e['iso_a2'] as String,
            isoA3: e['iso_a3'] as String,
          ))
              .toList();
          _lightLoading = false;
        });
      }
    } catch (e) {
      // fallback: CountryProvider 데이터 사용
      if (mounted) setState(() => _lightLoading = false);
    }
  }
  void _showPassportPicker(BuildContext context) {
    final passportProvider = context.read<PassportProvider>();
    final countryProvider = context.read<CountryProvider>();

    // 로딩 중이면 스피너만 표시
    if (passportProvider.isLoading) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF0FA8A5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
        ),
      );
      return;
    }

    final entries = passportProvider.passportDataMap.entries.toList()
      ..sort((a, b) {
        final nameA = countryProvider.isoToCountryNameMap[a.key] ?? a.value.passportName;
        final nameB = countryProvider.isoToCountryNameMap[b.key] ?? b.value.passportName;
        return nameA.compareTo(nameB);
      });
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final query = searchController.text.toLowerCase();
          final filtered = query.isEmpty
              ? entries
              : entries.where((e) {
            final name = countryProvider.isoToCountryNameMap[e.key] ?? e.value.passportName;
            return name.toLowerCase().contains(query);
          }).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFF0FA8A5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Text('Select Passport', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setModal(() {}),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search passport...',
                        hintStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.white60, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final name = countryProvider.isoToCountryNameMap[e.key] ?? e.value.passportName;
                      final isSelected = e.key == widget.selectedPassportIso;
                      return GestureDetector(
                        onTap: () { widget.onPassportChanged(e.key); Navigator.pop(ctx); },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.white.withOpacity(0.6) : Colors.transparent),
                          ),
                          child: Row(children: [
                            Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                            const Spacer(),
                            if (isSelected) const Icon(Icons.check, color: Colors.white, size: 16),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 경량 JSON 로딩 완료 시 사용, 실패 시 CountryProvider fallback
    final countryProvider = context.watch<CountryProvider>();
    final bool isLoading = _lightLoading;
    final List<_LightCountry> source = _lightCountries.isNotEmpty
        ? _lightCountries
        : countryProvider.allCountries
        .map((c) => _LightCountry(name: c.name, isoA2: c.isoA2, isoA3: c.isoA3))
        .toList();
    final filtered = widget.searchQuery.isEmpty
        ? source
        : source.where((c) =>
        c.name.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    final sorted = List<_LightCountry>.from(filtered)
      ..sort((a, b) => a.name.compareTo(b.name));
    final passportIso = widget.selectedPassportIso;
    final passportImageUrl = passportIso != null
        ? 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/passports%2F$passportIso.png?alt=media'
        : null;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const _AnimatedTitle(title: 'Where are you from?', subtitle: 'Select your home country'),
          const SizedBox(height: 14),

          // ── 여권 미리보기 (국가 선택 후) ──
          if (widget.selectedCountry != null && passportImageUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56, height: 78,
                      child: CachedNetworkImage(
                        imageUrl: passportImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.15),
                            child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 1.5))),
                        errorWidget: (_, __, ___) => Container(color: Colors.white.withOpacity(0.15),
                            child: const Icon(Icons.book_outlined, color: Colors.white38, size: 24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Passport', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.65), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          countryProvider.isoToCountryNameMap[passportIso] ?? passportIso ?? '',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showPassportPicker(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.35)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.swap_horiz, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text('Change passport', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SearchField(hint: 'Search country...', onChanged: widget.onSearchChanged),
          ),
          const SizedBox(height: 8),

          // 국가 리스트 or 로딩
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final c = sorted[i];
                return _LightCountryListTile(
                  country: c,
                  isSelected: widget.selectedCountry?.isoA2 == c.isoA2,
                  onTap: () => widget.onSelect(c),
                );
              },
            ),
          ),

          _BottomButton(
            label: 'CONTINUE',
            enabled: widget.selectedCountry != null,
            onTap: widget.selectedCountry != null ? widget.onNext : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 1 ──────────────────────────────────────────────────────────────────
// ─── Step 2 ── Highlights ────────────────────────────────────────────────────
class _Step2Highlights extends StatelessWidget {
  final _LightCountry country;
  final Set<String> visitedHighlights;
  final ValueChanged<String> onToggle;
  final VoidCallback onNext;

  const _Step2Highlights({
    required this.country, required this.visitedHighlights,
    required this.onToggle, required this.onNext,
  });

  List<Landmark> _getHighlights(BuildContext context) {
    final provider = context.watch<LandmarksProvider>();
    final iso = country.isoA3;
    final filtered = provider.allLandmarks
        .where((l) => l.countriesIsoA3.contains(iso))
        .where((l) { int rank = l.getRankForCountry(iso); return rank >= 1 && rank <= 10; })
        .toList()
      ..sort((a, b) => a.getRankForCountry(iso).compareTo(b.getRankForCountry(iso)));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final highlights = _getHighlights(context);
    final themeColor = const Color(0xFF3DDAD7);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          _AnimatedTitle(title: 'Highlights in\n${country.name}', subtitle: 'Which of these have you visited?'),
          const SizedBox(height: 20),
          Expanded(
            child: landmarksProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                : highlights.isEmpty
                ? Center(child: Text('No highlights found', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 15)))
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.82,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: highlights.length,
              itemBuilder: (context, i) {
                final lm = highlights[i];
                return _LandmarkCard(
                  landmark: lm,
                  isVisited: visitedHighlights.contains(lm.name),
                  themeColor: themeColor,
                  onTap: () => onToggle(lm.name),
                );
              },
            ),
          ),
          _BottomButton(
            label: 'CONTINUE',
            enabled: visitedHighlights.isNotEmpty,
            subLabel: visitedHighlights.isEmpty ? 'Skip if none' : null,
            onTap: onNext,
            onSkip: onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 2 ──────────────────────────────────────────────────────────────────
class _Step3PopularCountries extends StatelessWidget {
  final List<String> popularList;
  final Set<String> visitedPopular;
  final String? homeCountryName;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCountry;
  final VoidCallback onFinish;

  const _Step3PopularCountries({
    required this.popularList, required this.visitedPopular,
    required this.homeCountryName, required this.onToggle,
    required this.onAddCountry, required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final countryProvider = context.watch<CountryProvider>();

    final allVisitedNames = <String>{
      ...visitedPopular,
      if (homeCountryName != null) homeCountryName!,
    };

    // 홈국 항상 맨 위 (20개 목록에 없어도)
    final sortedList = List<String>.from(popularList);
    if (homeCountryName != null) {
      sortedList.remove(homeCountryName);
      sortedList.insert(0, homeCountryName!);
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          const _AnimatedTitle(
            title: 'Countries you\'ve\nvisited',
            subtitle: 'Toggle the ones you\'ve been to',
          ),
          const SizedBox(height: 12),

          // ── countries_menu_screen 과 동일한 지도 렌더링 ──
          _WorldMap(allVisitedNames: allVisitedNames, countryProvider: countryProvider),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              itemCount: sortedList.length + 1,
              itemBuilder: (context, i) {
                if (i == sortedList.length) {
                  return _AddCountryButton(onTap: onAddCountry);
                }
                final name = sortedList[i];
                final isHome = name == homeCountryName;
                final isOn = isHome || visitedPopular.contains(name);
                Country? matched;
                try { matched = countryProvider.allCountries.firstWhere((c) => c.name == name); } catch (_) {}
                return _PopularCountryTile(
                  name: name, isoA2: matched?.isoA2 ?? '',
                  isOn: isOn, isHome: isHome,
                  onToggle: isHome ? null : () => onToggle(name),
                );
              },
            ),
          ),

          _BottomButton(
            label: 'CONTINUE',
            enabled: visitedPopular.isNotEmpty || homeCountryName != null,
            onTap: onFinish,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── 세계지도 (countries_menu_screen 동일 방식) ───────────────────────────────
class _WorldMap extends StatelessWidget {
  final Set<String> allVisitedNames;
  final CountryProvider countryProvider;

  const _WorldMap({required this.allVisitedNames, required this.countryProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(35, 0),
          initialZoom: 0.25,
          interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(urlTemplate: '', backgroundColor: Colors.white),
          PolygonLayer(
            polygons: countryProvider.allCountries.expand((country) {
              final isVisited = allVisitedNames.contains(country.name);
              final color = isVisited
                  ? (countryProvider.continentColors[country.continent] ?? Colors.grey)
                  : Colors.grey.withOpacity(0.15);
              return country.polygonsData.map((polygonData) => Polygon(
                points: polygonData.first,
                holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                color: color,
                borderColor: Colors.white,
                borderStrokeWidth: 0.5,
                isFilled: true,
              ));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── + 버튼 ──────────────────────────────────────────────────────────────────
class _AddCountryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCountryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Add another country',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── 경량 국가 모델 ────────────────────────────────────────────────────────────
class _LightCountry {
  final String name;
  final String isoA2;
  final String isoA3;
  const _LightCountry({required this.name, required this.isoA2, required this.isoA3});
}

class _LightCountryListTile extends StatelessWidget {
  final _LightCountry country;
  final bool isSelected;
  final VoidCallback onTap;
  const _LightCountryListTile({required this.country, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.7) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(width: 32, height: 22, child: CountryFlag.fromCountryCode(country.isoA2)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(country.name,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── 공통 위젯들 ───────────────────────────────────────────────────────────────
class _AnimatedTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AnimatedTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _CountryListTile extends StatelessWidget {
  final Country country;
  final bool isSelected;
  final VoidCallback onTap;
  const _CountryListTile({required this.country, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.7) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(width: 32, height: 22, child: CountryFlag.fromCountryCode(country.isoA2)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(country.name,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final bool isVisited;
  final Color themeColor;
  final VoidCallback onTap;
  const _LandmarkCard({required this.landmark, required this.isVisited, required this.themeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _landmarkImageUrl(landmark.name);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isVisited ? Colors.white.withOpacity(0.9) : Colors.transparent, width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: imageUrl, fit: BoxFit.cover,
                width: double.infinity, height: double.infinity,
                placeholder: (_, __) => Container(
                  color: Colors.white.withOpacity(0.12),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.landscape_outlined, color: Colors.white38, size: 40),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10, left: 10, right: 10,
              child: Text(landmark.name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (isVisited)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                  ),
                  child: Icon(Icons.check, color: themeColor, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PopularCountryTile extends StatelessWidget {
  final String name;
  final String isoA2;
  final bool isOn;
  final bool isHome;
  final VoidCallback? onToggle;

  const _PopularCountryTile({
    required this.name, required this.isoA2,
    required this.isOn, required this.isHome, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isOn ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isOn ? Colors.white.withOpacity(0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            if (isoA2.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(width: 30, height: 20, child: CountryFlag.fromCountryCode(isoA2)),
              )
            else
              const SizedBox(width: 30, height: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 14,
                      fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
                  if (isHome) Text('Your home country',
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                ],
              ),
            ),
            if (isHome)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                child: Text('Home', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 26,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isOn ? Colors.white : Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: isOn ? const Color(0xFF1ABFBC) : Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3 ── GAWC 세계 주요 도시 방문 여부 ────────────────────────────────
class _Step4GawcCities extends StatelessWidget {
  final Set<String> visitedCities;
  final ValueChanged<String> onToggle;
  final VoidCallback onFinish;

  const _Step4GawcCities({
    required this.visitedCities,
    required this.onToggle,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const _AnimatedTitle(
            title: 'Major cities\nyou\'ve visited',
            subtitle: 'Tap the cities you\'ve been to',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _gawcTopCities.length,
              itemBuilder: (context, i) {
                final city = _gawcTopCities[i];
                final name = city['name']!;
                final displayName = city['display'] ?? name;
                final countryCode = city['country']!;
                final isVisited = visitedCities.contains(name);
                return _GawcCityCard(
                  name: name,
                  displayName: displayName,
                  countryCode: countryCode,
                  isVisited: isVisited,
                  onTap: () => onToggle(name),
                );
              },
            ),
          ),
          _BottomButton(
            label: 'CONTINUE',
            enabled: visitedCities.isNotEmpty,
            subLabel: visitedCities.isEmpty ? 'Skip if none' : null,
            onTap: onFinish,
            onSkip: onFinish,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GawcCityCard extends StatelessWidget {
  final String name;
  final String displayName;
  final String countryCode;
  final bool isVisited;
  final VoidCallback onTap;

  const _GawcCityCard({
    required this.name,
    required this.displayName,
    required this.countryCode,
    required this.isVisited,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _cityImageUrl(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isVisited ? Colors.white.withOpacity(0.9) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 이미지 영역 (전체 공간의 대부분)
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(
                        color: Colors.white.withOpacity(0.12),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white.withOpacity(0.12),
                        child: const Icon(Icons.location_city_outlined, color: Colors.white38, size: 40),
                      ),
                    ),
                  ),
                  // 체크 뱃지
                  if (isVisited)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                        ),
                        child: const Icon(Icons.check, color: Color(0xFF1ABFBC), size: 14),
                      ),
                    ),
                ],
              ),
            ),
            // 텍스트 영역 - 이미지 아래 고정 (2줄)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 14,
                      height: 10,
                      child: CountryFlag.fromCountryCode(countryCode),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 5 ── Top 50 Global Landmarks ───────────────────────────────────────
class _Step5TopLandmarks extends StatelessWidget {
  final Set<String> visitedLandmarks;
  final ValueChanged<String> onToggle;
  final VoidCallback onFinish;

  const _Step5TopLandmarks({
    required this.visitedLandmarks,
    required this.onToggle,
    required this.onFinish,
  });

  String _imageUrl(String name) {
    final snake = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/top_landmarks%2F$snake.jpg?alt=media';
  }

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();

    // global_rank 1~50 필터 + 정렬
    final top50 = landmarksProvider.allLandmarks
        .where((l) => l.global_rank >= 1 && l.global_rank <= 50)
        .toList()
      ..sort((a, b) => a.global_rank.compareTo(b.global_rank));

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const _AnimatedTitle(
            title: 'World\'s top landmarks',
            subtitle: 'Tap the ones you\'ve visited',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: landmarksProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                : top50.isEmpty
                ? Center(child: Text('No data', style: GoogleFonts.poppins(color: Colors.white70)))
                : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 2.4,
                mainAxisSpacing: 10,
              ),
              itemCount: top50.length,
              itemBuilder: (context, i) {
                final lm = top50[i];
                final isVisited = visitedLandmarks.contains(lm.name);
                return _TopLandmarkCard(
                  landmark: lm,
                  isVisited: isVisited,
                  imageUrl: _imageUrl(lm.name),
                  onTap: () => onToggle(lm.name),
                );
              },
            ),
          ),
          _BottomButton(
            label: 'START EXPLORING!',
            enabled: visitedLandmarks.isNotEmpty,
            subLabel: visitedLandmarks.isEmpty ? 'Skip if none' : null,
            onTap: onFinish,
            onSkip: onFinish,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TopLandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final bool isVisited;
  final String imageUrl;
  final VoidCallback onTap;

  const _TopLandmarkCard({
    required this.landmark,
    required this.isVisited,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isVisited ? Colors.white.withOpacity(0.9) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            // 이미지 전체
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: imageUrl, fit: BoxFit.cover,
                width: double.infinity, height: double.infinity,
                placeholder: (_, __) => Container(
                    color: Colors.white.withOpacity(0.12),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))),
                errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withOpacity(0.12),
                    child: const Icon(Icons.landscape_outlined, color: Colors.white38, size: 40)),
              ),
            ),
            // 오른쪽 그라디언트 + 텍스트
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            // 랭크 뱃지 (좌상단)
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#${landmark.global_rank}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            // 이름 (우측 세로 중앙)
            Positioned(
              right: 12, top: 0, bottom: 0,
              width: 130,
              child: Center(
                child: Text(landmark.name,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
              ),
            ),
            // 체크 뱃지 (우하단)
            if (isVisited)
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF1ABFBC), size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final String? subLabel;
  final VoidCallback? onTap;
  final VoidCallback? onSkip; // subLabel 전용 — 항상 작동

  const _BottomButton({required this.label, required this.enabled, this.subLabel, this.onTap, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(28),
                boxShadow: enabled ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))] : [],
              ),
              child: Center(
                child: Text(label, style: GoogleFonts.poppins(
                    color: enabled ? const Color(0xFF1ABFBC) : Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_next_rounded, color: Colors.white.withOpacity(0.9), size: 16),
                    const SizedBox(width: 6),
                    Text(subLabel!,
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}