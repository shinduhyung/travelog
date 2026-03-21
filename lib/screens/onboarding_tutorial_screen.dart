// lib/screens/onboarding_tutorial_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:country_flags/country_flags.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
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
  {'name': 'New York City', 'country': 'US'},
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
  {'name': 'Moscow', 'country': 'RU'},
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
  Country? _selectedHomeCountry;
  String _searchQuery = '';
  final Set<String> _visitedHighlights = {};
  final Set<String> _visitedPopular = {};
  final Set<String> _visitedGawcCities = {};
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
    for (final lmName in _visitedHighlights) {
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
            final available = filtered.where((c) => !_popularList.contains(c.name)).toList();

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
          onSelect: (c) => setState(() => _selectedHomeCountry = c),
          onNext: _animateToNext,
        );
      case 1:
        return _Step1Highlights(
          country: _selectedHomeCountry!,
          visitedHighlights: _visitedHighlights,
          onToggle: (name) => setState(() => _visitedHighlights.contains(name)
              ? _visitedHighlights.remove(name) : _visitedHighlights.add(name)),
          onNext: _animateToNext,
        );
      case 2:
        return _Step2PopularCountries(
          popularList: _popularList,
          visitedPopular: _visitedPopular,
          homeCountryName: _selectedHomeCountry?.name,
          onToggle: (name) => setState(() => _visitedPopular.contains(name)
              ? _visitedPopular.remove(name) : _visitedPopular.add(name)),
          onAddCountry: _showAddCountryDialog,
          onFinish: _animateToNext,
        );
      case 3:
        return _Step3GawcCities(
          visitedCities: _visitedGawcCities,
          onToggle: (name) => setState(() => _visitedGawcCities.contains(name)
              ? _visitedGawcCities.remove(name) : _visitedGawcCities.add(name)),
          onFinish: _finishOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step 0 ──────────────────────────────────────────────────────────────────
class _Step0HomeCountry extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Country? selectedCountry;
  final ValueChanged<Country> onSelect;
  final VoidCallback onNext;

  const _Step0HomeCountry({
    required this.searchQuery, required this.onSearchChanged,
    required this.selectedCountry, required this.onSelect, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final allCountries = context.watch<CountryProvider>().allCountries;
    final filtered = searchQuery.isEmpty ? allCountries
        : allCountries.where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const _AnimatedTitle(title: 'Where are you from?', subtitle: 'Select your home country'),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SearchField(hint: 'Search country...', onChanged: onSearchChanged),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                return _CountryListTile(
                  country: c,
                  isSelected: selectedCountry?.isoA2 == c.isoA2,
                  onTap: () => onSelect(c),
                );
              },
            ),
          ),
          _BottomButton(
            label: 'CONTINUE',
            enabled: selectedCountry != null,
            onTap: selectedCountry != null ? onNext : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 1 ──────────────────────────────────────────────────────────────────
class _Step1Highlights extends StatelessWidget {
  final Country country;
  final Set<String> visitedHighlights;
  final ValueChanged<String> onToggle;
  final VoidCallback onNext;

  const _Step1Highlights({
    required this.country, required this.visitedHighlights,
    required this.onToggle, required this.onNext,
  });

  List<Landmark> _getHighlights(BuildContext context) {
    final provider = context.read<LandmarksProvider>();
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
    final highlights = _getHighlights(context);
    final themeColor = country.themeColor ?? const Color(0xFF3DDAD7);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          _AnimatedTitle(title: 'Highlights in\n${country.name}', subtitle: 'Which of these have you visited?'),
          const SizedBox(height: 20),
          Expanded(
            child: highlights.isEmpty
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
            enabled: true,
            subLabel: visitedHighlights.isEmpty ? 'Skip if none' : null,
            onTap: onNext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Step 2 ──────────────────────────────────────────────────────────────────
class _Step2PopularCountries extends StatelessWidget {
  final List<String> popularList;
  final Set<String> visitedPopular;
  final String? homeCountryName;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCountry;
  final VoidCallback onFinish;

  const _Step2PopularCountries({
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

    // 홈국 맨 위
    final sortedList = List<String>.from(popularList);
    if (homeCountryName != null && sortedList.contains(homeCountryName)) {
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

          _BottomButton(label: "LET'S GO!", enabled: true, onTap: onFinish),
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
          initialCenter: LatLng(15, 0),
          initialZoom: 0.3,
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
class _Step3GawcCities extends StatelessWidget {
  final Set<String> visitedCities;
  final ValueChanged<String> onToggle;
  final VoidCallback onFinish;

  const _Step3GawcCities({
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
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _gawcTopCities.length,
              itemBuilder: (context, i) {
                final city = _gawcTopCities[i];
                final name = city['name']!;
                final countryCode = city['country']!;
                final isVisited = visitedCities.contains(name);
                return _GawcCityCard(
                  name: name,
                  countryCode: countryCode,
                  isVisited: isVisited,
                  onTap: () => onToggle(name),
                );
              },
            ),
          ),
          _BottomButton(
            label: "START EXPLORING!",
            enabled: true,
            subLabel: visitedCities.isEmpty ? 'Skip if none' : null,
            onTap: onFinish,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GawcCityCard extends StatelessWidget {
  final String name;
  final String countryCode;
  final bool isVisited;
  final VoidCallback onTap;

  const _GawcCityCard({
    required this.name,
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
        child: Stack(
          children: [
            // 도시 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_city_outlined, color: Colors.white38, size: 40),
                ),
              ),
            ),

            // 하단 그라디언트
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // 국기 + 도시명
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 18,
                      height: 13,
                      child: CountryFlag.fromCountryCode(countryCode),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final String? subLabel;
  final VoidCallback? onTap;

  const _BottomButton({required this.label, required this.enabled, this.subLabel, this.onTap});

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
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onTap,
              child: Text(subLabel!, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.65), fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}