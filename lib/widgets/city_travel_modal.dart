// lib/widgets/city_travel_modal.dart
//
// A separate modal from city_detail_modal.dart (which focuses on landmarks/visit history).
// This modal focuses on "trip prep" content — stays, flights, activities, eSIM — for affiliate revenue.
// Section order: Flights & Transportation -> Stays -> Tours -> SIMs -> More -> Tips
//
// TODO (monetization wiring needed):
//  - Sign up for the real affiliate programs — Skyscanner/Trip.com (flights), Agoda/Booking (stays),
//    GetYourGuide/Klook (tours), Airalo (eSIM) — and insert affiliate IDs into each URL
//  - Add url_launcher to pubspec.yaml if it's not already there (dependencies: url_launcher: ^6.x)
//  - Travel tips (_travelTips) are currently generic placeholder text shared across all cities —
//    replace with real per-city data later
//  - The "More" section (rental car/luggage/travel insurance/ground transport) is lower priority on
//    the roadmap, so it's shown as "Coming soon" for now
//  - Price attractiveness scoring (based on yearly avg / same period last year / recent trend) is
//    week-2 scope — not included in this prototype
//  - Destination IATA is matched from assets/top_city_hub_airports.json (city name -> IATA list,
//    first code used). Cities not in that file get a null destIata, shown as "···" and falling back
//    to a name-based search URL
//  - Real flight prices are now wired up via Cloud Functions (getFlightPrice/getFlightBookingLink)
//  - Curated tours are loaded from assets/city_tour_links.json (city name -> tour list).
//    Cities without curated entries fall back to the generic GetYourGuide/Klook search cards

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/services/flight_price_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Loads "city name -> primary (first) IATA code" mapping from assets/top_city_hub_airports.json
// ─────────────────────────────────────────────────────────────────────────────
class _TopCityHubAirports {
  static Map<String, String>? _cache;

  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/top_city_hub_airports.json');
      final List<dynamic> list = json.decode(str);
      final map = <String, String>{};
      for (final item in list) {
        final name = item['name'] as String;
        final iataList = (item['iata'] as List).cast<String>();
        if (iataList.isNotEmpty) map[name] = iataList.first;
      }
      _cache = map;
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loads curated per-city tour links from assets/city_tour_links.json
// (cities without an entry get an empty list -> fall back to the generic GetYourGuide/Klook search)
// ─────────────────────────────────────────────────────────────────────────────
class _CityTour {
  final String title;
  final String provider;
  final String url;
  const _CityTour({required this.title, required this.provider, required this.url});
}

class _CityTourLinks {
  static Map<String, List<_CityTour>>? _cache;

  static Future<Map<String, List<_CityTour>>> load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/city_tour_links.json');
      final List<dynamic> list = json.decode(str);
      final map = <String, List<_CityTour>>{};
      for (final entry in list) {
        final city = entry['city'] as String;
        final tours = (entry['tours'] as List)
            .map((t) => _CityTour(
          title: t['title'] as String,
          provider: t['provider'] as String,
          url: t['url'] as String,
        ))
            .toList();
        map[city] = tours;
      }
      _cache = map;
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
void showCityTravelModal(BuildContext context, City city) {
  final countryProvider = context.read<CountryProvider>();
  final country = countryProvider.allCountries
      .firstWhereOrNull((c) => c.isoA2.toUpperCase() == city.countryIsoA2.toUpperCase());
  final themeColor = country?.themeColor ?? const Color(0xFF1ABFBC);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => _CityTravelSheet(city: city, themeColor: themeColor, scrollController: sc),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CityTravelSheet extends StatelessWidget {
  final City city;
  final Color themeColor;
  final ScrollController scrollController;

  const _CityTravelSheet({
    required this.city,
    required this.themeColor,
    required this.scrollController,
  });

  // Same rule as city_detail_modal.dart's _heroUrl (reuses the hero image)
  String _toSnake(String s) {
    String r = s.toLowerCase();
    r = r.replaceAll(RegExp(r"[''`]"), '');
    r = r.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return r.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  String _toDashSlug(String s) => _toSnake(s).replaceAll('_', '-');

  String get _heroUrl {
    final filename = city.name == 'San José' ? 'san_jose_cr' : _toSnake(city.name);
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/ranked_cities%2F$filename.jpg.jpg?alt=media';
  }

  String _flag(String iso) {
    if (iso.length != 2) return '';
    final a = iso.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = iso.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  // TODO: replace with real affiliate program deep links (insert affiliate ID)
  String get _flightSearchUrl =>
      'https://www.skyscanner.net/transport/flights-to/${_toSnake(city.name)}/';
  String _flightRouteUrl(String originIata, String destIata) =>
      'https://www.skyscanner.net/transport/flights/${originIata.toLowerCase()}/${destIata.toLowerCase()}/';
  String get _hotelSearchUrl =>
      'https://www.booking.com/searchresults.html?ss=${Uri.encodeComponent(city.name)}';
  String get _tourSearchUrlGyg =>
      'https://www.getyourguide.com/s/?q=${Uri.encodeComponent(city.name)}';
  String get _tourSearchUrlKlook =>
      'https://www.klook.com/search/result/?query=${Uri.encodeComponent(city.name)}';
  String get _esimUrl => 'https://www.airalo.com/${_toDashSlug(city.country)}-esim';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const List<Map<String, String>> _stayTypes = [
    {'label': 'Hotels', 'query': 'hotel'},
    {'label': 'Hostels', 'query': 'hostel'},
    {'label': 'Apartments', 'query': 'apartment'},
    {'label': 'Resorts', 'query': 'resort'},
  ];

  static const List<Map<String, dynamic>> _moreItems = [
    {'icon': Icons.directions_car_filled_outlined, 'label': 'Rental Car'},
    {'icon': Icons.luggage_outlined, 'label': 'Luggage Storage'},
    {'icon': Icons.health_and_safety_outlined, 'label': 'Travel Insurance'},
    {'icon': Icons.directions_bus_outlined, 'label': 'Ground Transport'},
  ];

  static const List<Map<String, dynamic>> _travelTips = [
    {'icon': Icons.wb_sunny_outlined, 'title': 'Best time to visit', 'body': 'Check seasonal weather before booking — shoulder seasons often mean better prices and fewer crowds.'},
    {'icon': Icons.directions_bus_filled_outlined, 'title': 'Getting around', 'body': 'Look into local transit passes; they\'re usually cheaper than single tickets for multi-day trips.'},
    {'icon': Icons.payments_outlined, 'title': 'Currency & tipping', 'body': 'Notify your bank before traveling and check local tipping norms — they vary widely by country.'},
    {'icon': Icons.shield_outlined, 'title': 'Safety basics', 'body': 'Keep digital copies of important documents and know your embassy\'s local contact info.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHero(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Flights & Transportation', Icons.flight_takeoff_rounded),
                    const SizedBox(height: 12),
                    _buildFlightCard(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Stays', Icons.bed_outlined),
                    const SizedBox(height: 12),
                    _buildStaySection(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Tours & Activities', Icons.local_activity_outlined),
                    const SizedBox(height: 12),
                    _buildToursSection(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle('SIMs', Icons.sim_card_outlined),
                    const SizedBox(height: 12),
                    _buildEsimBanner(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle('More', Icons.apps_rounded),
                    const SizedBox(height: 12),
                    _buildMoreSection(),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Travel Tips', Icons.tips_and_updates_outlined),
                    const SizedBox(height: 12),
                    ..._travelTips.map((tip) => _buildTipTile(tip)),
                    const SizedBox(height: 20),
                    _buildAffiliateDisclosure(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _heroUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: const Color(0xFFF3F4F6)),
            errorWidget: (context, url, error) => Container(color: const Color(0xFFF3F4F6)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.55)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Row(
              children: [
                Text(_flag(city.countryIsoA2), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        city.country,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: themeColor),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ],
    );
  }

  // ── Flights & Transportation ────────────────────────────────────────────
  Widget _buildFlightCard(BuildContext context) {
    final airportProvider = context.watch<AirportProvider>();
    final hubIata = airportProvider.currentHubIata;
    final hubAirport = hubIata == null
        ? null
        : airportProvider.allAirports.firstWhereOrNull((a) => a.iataCode == hubIata);

    if (hubAirport == null) {
      // No hub airport set -> fall back to the old "Compare flight prices" style card
      return GestureDetector(
        onTap: () => _openUrl(_flightSearchUrl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.search_rounded, color: themeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Compare flight prices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text('Set your home airport to see prices instantly', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
            ],
          ),
        ),
      );
    }

    // Destination IATA is looked up by city name in assets/top_city_hub_airports.json (first code used)
    return FutureBuilder<Map<String, String>>(
      future: _TopCityHubAirports.load(),
      builder: (context, snapshot) {
        final destIata = snapshot.data?[city.name];

        if (destIata == null) {
          // No destination IATA mapping -> can't fetch a real price, fall back to the search link
          return GestureDetector(
            onTap: () => _openUrl(_flightSearchUrl),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${hubAirport.iataCode} → ${city.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Text('Search flights', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
                ],
              ),
            ),
          );
        }

        return _FlightPriceCard(
          originIata: hubAirport.iataCode,
          destinationIata: destIata,
          destinationCityName: city.name,
          themeColor: themeColor,
          fallbackSearchUrl: _flightSearchUrl,
          onOpenUrl: _openUrl,
        );
      },
    );
  }

  // ── Stays ────────────────────────────────────────────────────────────────
  Widget _buildStaySection(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stayTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final type = _stayTypes[index];
          return GestureDetector(
            onTap: () => _openUrl('$_hotelSearchUrl&nflt=ht_id%3D${type['query']}'),
            child: Container(
              width: 108,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (type['query']) {
                      'hostel' => Icons.night_shelter_outlined,
                      'apartment' => Icons.apartment_rounded,
                      'resort' => Icons.beach_access_rounded,
                      _ => Icons.hotel_rounded,
                    },
                    color: themeColor,
                    size: 22,
                  ),
                  const Spacer(),
                  Text(
                    type['label']!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tours & Activities ──────────────────────────────────────────────────
  Widget _buildToursSection(BuildContext context) {
    return FutureBuilder<Map<String, List<_CityTour>>>(
      future: _CityTourLinks.load(),
      builder: (context, snapshot) {
        final curated = snapshot.data?[city.name] ?? const [];

        if (curated.isNotEmpty) {
          return Column(
            children: curated.map((tour) => _curatedTourCard(tour)).toList(),
          );
        }

        // No curated entry for this city -> fall back to the generic search cards
        return Row(
          children: [
            Expanded(
              child: _providerCard(
                label: 'GetYourGuide',
                subtitle: 'Tours & activities',
                icon: Icons.tour_rounded,
                onTap: () => _openUrl(_tourSearchUrlGyg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _providerCard(
                label: 'Klook',
                subtitle: 'Tours & activities',
                icon: Icons.confirmation_number_outlined,
                onTap: () => _openUrl(_tourSearchUrlKlook),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _curatedTourCard(_CityTour tour) {
    return GestureDetector(
      onTap: () => _openUrl(tour.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.local_activity_outlined, color: themeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(tour.provider, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _providerCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: themeColor, size: 22),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── SIMs ─────────────────────────────────────────────────────────────────
  Widget _buildEsimBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(_esimUrl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [themeColor, themeColor.withOpacity(0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.sim_card_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get an eSIM for ${city.name}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Stay connected in ${city.country} from day one',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // -- More (lower priority on the roadmap -- Coming soon) ------------------
  Widget _buildMoreSection() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _moreItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _moreItems[index];
          return Opacity(
            opacity: 0.5,
            child: Container(
              width: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item['icon'] as IconData, color: Colors.grey.shade500, size: 20),
                  const Spacer(),
                  Text(item['label'] as String,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text('Coming soon', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipTile(Map<String, dynamic> tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tip['icon'] as IconData, size: 20, color: themeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text(tip['body'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliateDisclosure() {
    return Text(
      'We may earn a commission from bookings made through links in this app, at no extra cost to you.',
      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real price + Book button (calls the getFlightPrice / getFlightBookingLink Cloud Functions)
// ─────────────────────────────────────────────────────────────────────────────
class _FlightPriceCard extends StatefulWidget {
  final String originIata;
  final String destinationIata;
  final String destinationCityName;
  final Color themeColor;
  final String fallbackSearchUrl;
  final Future<void> Function(String url) onOpenUrl;

  const _FlightPriceCard({
    required this.originIata,
    required this.destinationIata,
    required this.destinationCityName,
    required this.themeColor,
    required this.fallbackSearchUrl,
    required this.onOpenUrl,
  });

  @override
  State<_FlightPriceCard> createState() => _FlightPriceCardState();
}

class _FlightPriceCardState extends State<_FlightPriceCard> {
  late final Future<FlightPriceResult> _priceFuture;
  bool _bookingLoading = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _priceFuture = FlightPriceService.getPrice(
      originIata: widget.originIata,
      destinationIata: widget.destinationIata,
      date: dateStr,
    );
  }

  Future<void> _onBookTap(FlightPriceResult result) async {
    if (result.itineraryId == null || result.sessionId == null) {
      await widget.onOpenUrl(widget.fallbackSearchUrl);
      return;
    }
    setState(() => _bookingLoading = true);
    try {
      final deepLink = await FlightPriceService.getBookingLink(
        itineraryId: result.itineraryId!,
        sessionId: result.sessionId!,
      );
      await widget.onOpenUrl(deepLink);
    } catch (_) {
      // Deep link lookup failed -> fall back to the search link
      await widget.onOpenUrl(widget.fallbackSearchUrl);
    } finally {
      if (mounted) setState(() => _bookingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FlightPriceResult>(
      future: _priceFuture,
      builder: (context, snapshot) {
        final routeLabel = '${widget.originIata} → ${widget.destinationIata}';

        Widget content;
        VoidCallback? onTap;

        if (snapshot.connectionState != ConnectionState.done) {
          content = Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: widget.themeColor),
              ),
              const SizedBox(width: 12),
              Text('Checking today\'s fares…', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          );
        } else if (snapshot.hasError || snapshot.data?.found != true) {
          content = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routeLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text('Price unavailable — tap to search', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
            ],
          );
          onTap = () => widget.onOpenUrl(widget.fallbackSearchUrl);
        } else {
          final result = snapshot.data!;
          content = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text(
                      result.priceFormatted ?? '-',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: widget.themeColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (result.isDirect) 'Direct' else if (result.stopCount != null) '${result.stopCount} stop(s)',
                        if (result.carrier != null) result.carrier!,
                      ].join(' · '),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _bookingLoading ? null : () => _onBookTap(result),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: widget.themeColor, borderRadius: BorderRadius.circular(12)),
                  child: _bookingLoading
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Book', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          );
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: content,
          ),
        );
      },
    );
  }
}