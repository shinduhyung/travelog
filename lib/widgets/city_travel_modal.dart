// lib/widgets/city_travel_modal.dart
//
// A separate modal from city_detail_modal.dart (which focuses on landmarks/visit history).
// This modal focuses on "trip prep" content — stays, flights, activities, eSIM — for affiliate revenue.
// Section order: Flights & Transportation -> Stays -> Tours -> SIMs -> More -> Tips
//
// TODO (monetization wiring needed):
//  - Flights: Trip.com affiliate program is wired up (Skyscanner's application was rejected).
//    GetYourGuide is wired up (partner_id=EMZVISH on the search link; curated tour links get it
//    from tool/city_travel). Stays go to Hotels.com / Vrbo via Expedia Group (_hotelsComCamref).
//    Sign up for the remaining real affiliate programs — Booking.com (stays), Klook (tours) —
//    and insert affiliate IDs into each URL. Airalo (eSIM) is wired up
//    through Impact (_airaloTrackingUrl); luggage storage goes to Bounce (_bounceRef).
//  - Add url_launcher to pubspec.yaml if it's not already there (dependencies: url_launcher: ^6.x)
//  - Travel tips (_travelTips) are currently generic placeholder text shared across all cities —
//    replace with real per-city data later
//  - The "More" section (rental car/travel insurance/ground transport) is lower priority on
//    the roadmap, so it's shown as "Coming soon" for now. Luggage storage has its own section (Bounce)
//    (city pages listed in assets/bounce_city_pages.json, generic affiliate link otherwise)
//  - Price attractiveness scoring (based on yearly avg / same period last year / recent trend) is
//    week-2 scope — not included in this prototype
//  - Destination IATA is matched from assets/top_city_hub_airport.json (city name -> IATA list,
//    first code used). Cities not in that file get a null destIata, shown as "···" and falling back
//    to a name-based search URL
//  - Real flight prices are now wired up via Cloud Functions (getFlightPrice/getFlightBookingLink)
//  - Curated tours are loaded from assets/city_tour_links.json (city name -> tour list).
//    Cities without curated entries fall back to the generic GetYourGuide/Klook search cards

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/services/flight_price_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Trip.com affiliate flight links.
//
// Skyscanner's own affiliate/partner application was rejected, so flight
// bookings now route through Trip.com's affiliate program instead. This
// mirrors a link generated in Trip.com's Affiliate Platform
// (affiliates.trip.com -> Affiliate Link -> Custom link -> paste a
// trip.com/flights/showfarefirst?... URL -> Create an affiliate link).
//
// IMPORTANT: Allianceid/SID/trip_sub3 below are copied from that generated
// link. If the affiliate account, sub-ID scheme, or link ever changes,
// regenerate a link on affiliates.trip.com and update these three constants.
// ─────────────────────────────────────────────────────────────────────────────
const String _tripComAllianceId = '8685083';
const String _tripComSid = '319520097';
const String _tripComSubId = 'D1919_3743'; // trip_sub3 — free-form tracking tag; safe to change per placement

// Airalo affiliate tracking link from Impact (app.impact.com -> Create a link -> Airalo,
// "Regular" link format). Append ?u=<encoded airalo.com URL> to land on a specific page.
const String _airaloTrackingUrl = 'https://airalo.pxf.io/c/7592796/1268485/15608';

// Expedia Group Travel Creator Program (Partnerize) affiliate refs, from the Creator Hub
// Link builder (creator.expediagroup.com -> Link builder, "Shorten links" off). camref and
// creativeref are fixed per brand; the per-link adref it adds is optional.
const String _hotelsComCamref = '1011l6uqXc';
const String _hotelsComCreativeref = '1011l66481';
const String _vrboCamref = '1011l6uqXe';
const String _vrboCreativeref = '1101l63118';

String _expediaGroupAffiliateUrl(String host, String landingPage, String camref, String creativeref) =>
    'https://$host/affiliate?landingPage=${Uri.encodeComponent(landingPage)}&camref=$camref&creativeref=$creativeref';

// Bounce (luggage storage) affiliate referral code from partner.bounce.com.
// bounce.com city pages accept ?ref= and carry it into their booking links.
const String _bounceRef = 'TRAVELOG999083578969';

// "city name -> bounce.com/luggage-storage/<slug>" from assets/bounce_city_pages.json.
// Only checked slugs go in there (Bounce slugs aren't always the plain city name);
// other cities fall back to the generic affiliate link.
class _BounceCityPages {
  static Map<String, String>? _cache;

  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/bounce_city_pages.json');
      _cache = Map<String, String>.from(json.decode(str) as Map);
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }
}

// "city name -> published trip guide page" from assets/city_trip_pages.json
// (built from tool/city_travel/logs/_pub_map.txt).
class _TripGuidePages {
  static Map<String, String>? _cache;

  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/city_trip_pages.json');
      _cache = Map<String, String>.from(json.decode(str) as Map);
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }
}

String buildTripComFlightUrl(
    String originIata,
    String destIata,
    DateTime departDate, {
      DateTime? returnDate,
    }) {
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final params = <String, String>{
    'dcity': originIata.toLowerCase(),
    'acity': destIata.toLowerCase(),
    'ddate': fmt(departDate),
    if (returnDate != null) 'rdate': fmt(returnDate),
    'triptype': returnDate != null ? 'rt' : 'ow',
    'class': 'y',
    'lowpricesource': 'searchform',
    'quantity': '1',
    'searchboxarg': 't',
    'nonstoponly': 'off',
    'sort': 'price',
    // Trip.com's affiliate params are case-sensitive — keep exact casing.
    'Allianceid': _tripComAllianceId,
    'SID': _tripComSid,
    'trip_sub1': '',
    'trip_sub3': _tripComSubId,
  };
  final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return 'https://www.trip.com/flights/showfarefirst?$query';
}

// Fallback for when we don't have a specific route yet (no destIata match) —
// still points at Trip.com with the affiliate id/SID attached, just without a
// pre-filled route, so a booking made during that visit is still attributed.
String get _tripComHomeUrl =>
    'https://www.trip.com/?Allianceid=$_tripComAllianceId&SID=$_tripComSid&trip_sub1=&trip_sub3=$_tripComSubId';

// ─────────────────────────────────────────────────────────────────────────────
// Loads "city name -> primary (first) IATA code" mapping from assets/top_city_hub_airport.json
// ─────────────────────────────────────────────────────────────────────────────
class _TopCityHubAirports {
  static Map<String, String>? _cache;

  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final str = await rootBundle.loadString('assets/top_city_hub_airport.json');
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
  // Optional "why this is worth it" data — all nullable/empty-safe so entries
  // in city_tour_links.json can omit them and still fall back gracefully.
  final double? rating;
  final int? reviewCount;
  final String? price;
  final String? originalPrice; // shown struck-through next to `price`, if present
  final String? duration;
  final List<String> badges; // short pills, e.g. "Pickup included", "Free cancellation"
  final List<String> highlights; // 2-4 short "why buy" reasons
  // Landmark names this tour visits, matched 1:1 against Landmark.name in
  // landmarks_provider so we can show "landmarks unlocked by this tour".
  // IMPORTANT: these strings must exactly match the `name` field in the
  // app's landmark dataset (all_landmarks.json) — verify/adjust per city.
  final List<String> landmarks;

  const _CityTour({
    required this.title,
    required this.provider,
    required this.url,
    this.rating,
    this.reviewCount,
    this.price,
    this.originalPrice,
    this.duration,
    this.badges = const [],
    this.highlights = const [],
    this.landmarks = const [],
  });
}

class _CityTourLinks {
  static Map<String, List<_CityTour>>? _cache;

  static Future<void> _debugDumpAssetManifest() async {
    // AssetManifest.json isn't shipped anymore on this Flutter SDK (only
    // AssetManifest.bin, which is binary). Use the official AssetManifest
    // API instead — it decodes .bin transparently and gives us the real,
    // definitive list of every asset Flutter actually bundled at build time.
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();
      final jsonAssets = allAssets.where((a) => a.toLowerCase().endsWith('.json')).toList()..sort();
      debugPrint('[ToursDEBUG] AssetManifest loaded via AssetManifest.loadFromAssetBundle — ${allAssets.length} total assets bundled');
      debugPrint('[ToursDEBUG] ALL bundled .json assets: $jsonAssets');
      debugPrint('[ToursDEBUG] contains "assets/city_tour_links.json"? ${allAssets.contains('assets/city_tour_links.json')}');
    } catch (e) {
      debugPrint('[ToursDEBUG] AssetManifest.loadFromAssetBundle failed: $e');
    }
  }

  static Future<void> _debugProbeAlternatePaths() async {
    // If the primary path 404s, try the most common mistakes: missing
    // 'assets/' prefix, or nested under a subfolder.
    final candidates = [
      'city_tour_links.json',
      'assets/data/city_tour_links.json',
      'assets/json/city_tour_links.json',
      'assets/city_tour_links.json ', // stray trailing space in pubspec.yaml
    ];
    for (final path in candidates) {
      try {
        final s = await rootBundle.loadString(path);
        debugPrint('[ToursDEBUG] ALTERNATE PATH WORKED: "$path" (${s.length} chars) <-- fix the load() path to this!');
      } catch (_) {
        debugPrint('[ToursDEBUG] alternate path "$path" also not found');
      }
    }
  }

  static Future<Map<String, List<_CityTour>>> load() async {
    if (_cache != null) {
      debugPrint('[ToursDEBUG] using cached tour data, ${_cache!.length} cities, keys=${_cache!.keys.toList()}');
      return _cache!;
    }
    await _debugDumpAssetManifest();
    try {
      debugPrint('[ToursDEBUG] loading assets/city_tour_links.json ...');
      final str = await rootBundle.loadString('assets/city_tour_links.json');
      debugPrint('[ToursDEBUG] raw asset loaded, length=${str.length} chars');
      final List<dynamic> list = json.decode(str);
      debugPrint('[ToursDEBUG] JSON decoded, ${list.length} city entries');
      final map = <String, List<_CityTour>>{};
      for (final entry in list) {
        final city = entry['city'] as String;
        final tours = (entry['tours'] as List).map((t) {
          final m = t as Map<String, dynamic>;
          double? parseRating(dynamic v) => v == null ? null : (v as num).toDouble();
          int? parseCount(dynamic v) => v == null ? null : (v as num).toInt();
          List<String> parseStrList(dynamic v) =>
              v == null ? const [] : List<String>.from(v as List);

          return _CityTour(
            title: m['title'] as String,
            provider: m['provider'] as String,
            url: m['url'] as String,
            rating: parseRating(m['rating']),
            reviewCount: parseCount(m['reviewCount']),
            price: m['price']?.toString(),
            originalPrice: m['originalPrice']?.toString(),
            duration: m['duration']?.toString(),
            badges: parseStrList(m['badges']),
            highlights: parseStrList(m['highlights']),
            landmarks: parseStrList(m['landmarks']),
          );
        }).toList();
        map[city] = tours;
        debugPrint('[ToursDEBUG] parsed city="$city" -> ${tours.length} tour(s): ${tours.map((t) => t.title).toList()}');
      }
      _cache = map;
      debugPrint('[ToursDEBUG] load() SUCCESS, total cities=${map.length}');
    } catch (e, st) {
      debugPrint('[ToursDEBUG] load() FAILED with error: $e');
      debugPrint('[ToursDEBUG] stack trace:\n$st');
      await _debugProbeAlternatePaths();
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
  String get _flightSearchUrl => _tripComHomeUrl;
  String _flightRouteUrl(String originIata, String destIata) =>
      buildTripComFlightUrl(originIata, destIata, DateTime.now());
  String get _hotelSearchUrl => _expediaGroupAffiliateUrl(
      'www.hotels.com', 'https://www.hotels.com/Hotel-Search?destination=${Uri.encodeComponent(city.name)}',
      _hotelsComCamref, _hotelsComCreativeref);
  String get _rentalSearchUrl => _expediaGroupAffiliateUrl(
      'vrbo.com', 'https://www.vrbo.com/search?destination=${Uri.encodeComponent(city.name)}',
      _vrboCamref, _vrboCreativeref);
  String get _tourSearchUrlGyg =>
      'https://www.getyourguide.com/s/?q=${Uri.encodeComponent(city.name)}&partner_id=EMZVISH&utm_medium=online_publisher';
  String get _tourSearchUrlKlook =>
      'https://www.klook.com/search/result/?query=${Uri.encodeComponent(city.name)}';
  Future<void> _openBounce() async {
    final slug = (await _BounceCityPages.load())[city.name];
    await _openUrl(slug == null
        ? 'https://go.bounce.com/$_bounceRef'
        : 'https://bounce.com/luggage-storage/$slug?ref=$_bounceRef&utm_source=affiliates&utm_medium=link');
  }

  // Airalo via Impact: the tracking link's `u` param deep-links to the country eSIM page.
  String get _esimUrl =>
      '$_airaloTrackingUrl?u=${Uri.encodeComponent('https://www.airalo.com/${_toDashSlug(city.country)}-esim')}';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Hotels.com's search only filters hotel vs. home, so stays are split by brand instead.
  static const List<Map<String, String>> _stayTypes = [
    {'label': 'Hotels', 'query': 'hotel', 'provider': 'Hotels.com'},
    {'label': 'Apartments', 'query': 'apartment', 'provider': 'Vrbo'},
  ];

  static const List<Map<String, dynamic>> _moreItems = [
    {'icon': Icons.directions_car_filled_outlined, 'label': 'Rental Car'},
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
    Localizations.maybeLocaleOf(context);
    debugPrint('[ToursDEBUG] _CityTravelSheet.build() for city="${city.name}"');
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
                    _buildTripGuideCard(),
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
                    Builder(builder: (context) {
                      debugPrint('[ToursDEBUG] about to call _buildToursSection');
                      return _buildToursSection(context);
                    }),
                    const SizedBox(height: 28),
                    _buildSectionTitle('SIMs', Icons.sim_card_outlined),
                    const SizedBox(height: 12),
                    _buildEsimBanner(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Luggage Storage', Icons.luggage_outlined),
                    const SizedBox(height: 12),
                    _buildBounceCard(),
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
                Text(tr(_flag(city.countryIsoA2)), style: const TextStyle(fontSize: 22)),
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
                        tr(city.country),
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
        Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
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

    debugPrint('[FlightCard DEBUG] currentHubIata=$hubIata, hubAirport=${hubAirport?.iataCode}');

    if (hubAirport == null) {
      debugPrint('[FlightCard DEBUG] BRANCH A: no hub airport set -> hub setup prompt card');
      // No hub airport set -> let the user set one right here instead of leaving the modal
      return GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _TravelModalHubSetupSheet(
            airportProvider: airportProvider,
            themeColor: themeColor,
          ),
        ),
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
                child: Icon(Icons.add_location_alt_rounded, color: themeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(tr('Set your home airport'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text(tr('Tap to set your hub and see prices instantly'), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
            ],
          ),
        ),
      );
    }

    // Destination IATA is looked up by city name in assets/top_city_hub_airport.json (first code used)
    return FutureBuilder<Map<String, String>>(
      future: _TopCityHubAirports.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          debugPrint('[FlightCard DEBUG] top_city_hub_airport.json still loading...');
        } else if (snapshot.hasError) {
          debugPrint('[FlightCard DEBUG] top_city_hub_airport.json load ERROR: ${snapshot.error}');
        } else {
          debugPrint('[FlightCard DEBUG] top_city_hub_airport.json loaded, ${snapshot.data?.length ?? 0} entries. '
              'Looking up city.name="${city.name}" -> found=${snapshot.data?[city.name]}');
        }

        final destIata = snapshot.data?[city.name];

        if (destIata == null) {
          debugPrint('[FlightCard DEBUG] BRANCH B: no destIata match for "${city.name}" -> name-based fallback card');
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
                        Text(tr('Search flights'), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
                ],
              ),
            ),
          );
        }

        debugPrint('[FlightCard DEBUG] BRANCH C: rendering _FlightSearchCard origin=${hubAirport.iataCode} dest=$destIata');
        return _FlightSearchCard(
          initialOriginIata: hubAirport.iataCode,
          initialDestinationIata: destIata,
          airportProvider: airportProvider,
          themeColor: themeColor,
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
            onTap: () => _openUrl(type['query'] == 'apartment' ? _rentalSearchUrl : _hotelSearchUrl),
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
                    type['query'] == 'apartment' ? Icons.apartment_rounded : Icons.hotel_rounded,
                    color: themeColor,
                    size: 22,
                  ),
                  const Spacer(),
                  Text(
                    tr(type['label']!),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  Text(type['provider']!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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
        if (snapshot.connectionState != ConnectionState.done) {
          debugPrint('[ToursDEBUG] FutureBuilder still waiting for city_tour_links.json...');
        } else if (snapshot.hasError) {
          debugPrint('[ToursDEBUG] FutureBuilder ERROR: ${snapshot.error}');
        } else {
          debugPrint('[ToursDEBUG] FutureBuilder done. Loaded cities=${snapshot.data?.keys.toList()}. '
              'Looking up city.name="${city.name}" -> found=${snapshot.data?.containsKey(city.name)}');
        }

        final curated = snapshot.data?[city.name] ?? const [];
        debugPrint('[ToursDEBUG] curated.length=${curated.length} for city="${city.name}"');

        if (curated.isNotEmpty) {
          return Column(
            children: curated.map((tour) => _curatedTourCard(context, tour)).toList(),
          );
        }

        debugPrint('[ToursDEBUG] falling back to generic GetYourGuide/Klook search cards');
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

  // Landmark image url, mirroring city_detail_modal.dart's _lmUrl
  String _tourLmUrl(String name) =>
      'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/countrydex%2F${_toSnake(name)}.jpg?alt=media';

  // context.watch<LandmarksProvider>() throws if no Provider<LandmarksProvider>
  // exists above this widget in the tree. That's likely why nothing in this
  // section rendered — a missing provider used to take down the whole card
  // instead of just the landmark chips. Guard it so the rest of the card
  // always renders regardless.
  LandmarksProvider? _tryWatchLandmarks(BuildContext context) {
    try {
      final lp = context.watch<LandmarksProvider>();
      debugPrint('[ToursDEBUG] LandmarksProvider found OK, allLandmarks.length=${lp.allLandmarks.length}');
      return lp;
    } catch (e) {
      debugPrint('[ToursDEBUG] LandmarksProvider NOT FOUND in context: $e');
      return null;
    }
  }

  // Compact info modal for a single landmark, launched from the tiny info
  // button on a tour's landmark chip. Reuses the app's existing
  // LandmarkInfoCard content widget rather than duplicating copy/formatting.
  void _showTourLandmarkModal(BuildContext context, Landmark landmark) {
    final lp = _tryWatchLandmarks(context);
    final isVisited = lp?.visitedLandmarks.contains(landmark.name) ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: _tourLmUrl(landmark.name),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: themeColor.withOpacity(0.1)),
                              errorWidget: (_, __, ___) => Container(
                                color: themeColor.withOpacity(0.15),
                                child: Icon(Icons.landscape_outlined, color: themeColor.withOpacity(0.5), size: 40),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.6)],
                                  stops: const [0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12, right: 12,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(sheetContext),
                              child: const CircleAvatar(
                                radius: 15, backgroundColor: Colors.black38,
                                child: Icon(Icons.close, color: Colors.white, size: 17),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16, right: 16, bottom: 14,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    landmark.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (isVisited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 13, color: themeColor),
                                        const SizedBox(width: 4),
                                        Text(tr('Visited'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: themeColor)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: LandmarkInfoCard(
                      overview: landmark.overview,
                      historySignificance: landmark.history_significance,
                      highlights: landmark.highlights,
                      themeColor: themeColor,
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

  Widget _curatedTourCard(BuildContext context, _CityTour tour) {
    debugPrint('[ToursDEBUG] building card for tour="${tour.title}" landmarks=${tour.landmarks}');
    final lp = _tryWatchLandmarks(context);
    final visited = lp?.visitedLandmarks ?? const <String>{};
    // Match this tour's landmark names against the real dataset — names that
    // don't exist yet in all_landmarks.json (or if LandmarksProvider isn't
    // available here) are silently skipped rather than shown broken, since
    // curated JSON is hand-written and can drift.
    final matchedLandmarks = lp == null
        ? const <Landmark>[]
        : tour.landmarks
        .map((n) => lp.allLandmarks.firstWhereOrNull((l) => l.name == n))
        .whereType<Landmark>()
        .toList();
    debugPrint('[ToursDEBUG] matchedLandmarks=${matchedLandmarks.map((l) => l.name).toList()} '
        '(requested ${tour.landmarks.length}, matched ${matchedLandmarks.length})');
    final unvisitedCount = matchedLandmarks.where((l) => !visited.contains(l.name)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── landmarks lead the card: "you take this tour to get to these" ──
          if (matchedLandmarks.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.flag_circle_rounded, size: 18, color: themeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr(unvisitedCount > 0
                        ? 'Take this tour to unlock $unvisitedCount new landmark quest${unvisitedCount > 1 ? 's' : ''}'
                        : 'You\'ve already visited all ${matchedLandmarks.length} landmarks on this tour'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF111827), height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matchedLandmarks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final lm = matchedLandmarks[i];
                  final isVisited = visited.contains(lm.name);
                  // Tapping ANYWHERE on a landmark item opens its info modal —
                  // not the booking link. This GestureDetector wins the tap
                  // over the card's own "open tour.url" tap below since it's
                  // the deeper/innermost recognizer in the hit-test chain.
                  return GestureDetector(
                    onTap: () => _showTourLandmarkModal(context, lm),
                    child: SizedBox(
                      width: 84,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: _tourLmUrl(lm.name),
                                  width: 84, height: 64, fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(width: 84, height: 64, color: themeColor.withOpacity(0.12)),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 84, height: 64, color: themeColor.withOpacity(0.12),
                                    child: Icon(Icons.landscape_outlined, color: themeColor.withOpacity(0.4), size: 20),
                                  ),
                                ),
                              ),
                              if (isVisited)
                                Positioned(
                                  bottom: 4, left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Icon(Icons.check_circle, color: themeColor, size: 15),
                                  ),
                                ),
                              // Purely decorative "tap for info" affordance — the
                              // whole item is already tappable, this isn't a
                              // separate gesture target.
                              Positioned(
                                top: 4, right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                                  child: const Icon(Icons.info_outline_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lm.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF374151), height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── everything below here opens the booking link when tapped ──
          GestureDetector(
            onTap: () => _openUrl(tour.url),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── why this tour gets you there ──────────────────────────
                if (tour.highlights.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: tour.highlights.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: themeColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(tr(h), style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151), height: 1.35)),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── badges (free cancellation, pickup included, etc.) ─────
                if (tour.badges.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tour.badges.map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tr(b), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: themeColor)),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── compact tour meta — secondary, not the headline ───────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(tour.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(tr(tour.provider), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    if (tour.rating != null) ...[
                      Text(tr('·'), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600),
                      Text(
                        tr(tour.reviewCount != null ? '${tour.rating} (${tour.reviewCount})' : '${tour.rating}'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                    ],
                    if (tour.duration != null) ...[
                      Text(tr('·'), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      Text(tr(tour.duration!), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ],
                ),

                // ── slim booking footer ───────────────────────────────────
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (tour.price != null) ...[
                      if (tour.originalPrice != null) ...[
                        Text(
                          tr(tour.originalPrice!),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tr(tour.price!),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('View tour'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: themeColor)),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: themeColor),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            Text(tr(label), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(tr(subtitle), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                  Text(tr('Get an eSIM for ${city.name}', entities: [city.name]),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(tr('Stay connected in ${city.country} from day one'),
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
                  Text(tr(item['label'] as String),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(tr('Coming soon'), style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Trip guide page (tool/city_travel output) ─────────────────────────
  Widget _buildTripGuideCard() {
    return FutureBuilder<Map<String, String>>(
      future: _TripGuidePages.load(),
      builder: (context, snap) {
        final url = snap.data?[city.name];
        if (url == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: GestureDetector(
            onTap: () => _openUrl(url),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.map_rounded, color: themeColor, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('${city.name} trip guide', entities: [city.name]),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        const SizedBox(height: 2),
                        Text(tr('Itineraries, getting around, costs, weather and hotels'),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Luggage Storage (Bounce) ──────────────────────────────────────────
  Widget _buildBounceCard() {
    return GestureDetector(
      onTap: _openBounce,
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
              child: Icon(Icons.luggage_rounded, color: themeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Store your bags in ${city.name}', entities: [city.name]),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(tr('Drop luggage at nearby shops and hotels with Bounce'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ],
        ),
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
                Text(tr(tip['title'] as String), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text(tr(tip['body'] as String), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliateDisclosure() {
    return Text(
      tr('We may earn a commission from bookings made through links in this app, at no extra cost to you.'),
      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable flight search card: origin, date, and stops filter can all be
// changed in-app; each change re-triggers getFlightPrice. Calls the
// getFlightPrice / getFlightBookingLink Cloud Functions.
// ─────────────────────────────────────────────────────────────────────────────
class _FlightSearchCard extends StatefulWidget {
  final String initialOriginIata;
  final String initialDestinationIata;
  final AirportProvider airportProvider;
  final Color themeColor;
  final Future<void> Function(String url) onOpenUrl;

  const _FlightSearchCard({
    required this.initialOriginIata,
    required this.initialDestinationIata,
    required this.airportProvider,
    required this.themeColor,
    required this.onOpenUrl,
  });

  @override
  State<_FlightSearchCard> createState() => _FlightSearchCardState();
}

class _FlightSearchCardState extends State<_FlightSearchCard> {
  late String _originIata;
  late String _destinationIata;
  late DateTime _date;
  String? _stops; // null = any, 'direct' = direct only
  bool _bookingLoading = false;
  late Future<FlightPriceResult> _priceFuture;

  @override
  void initState() {
    super.initState();
    _originIata = widget.initialOriginIata;
    _destinationIata = widget.initialDestinationIata;
    _date = DateTime.now();
    _fetchPrice();
  }

  @override
  void didUpdateWidget(covariant _FlightSearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the persisted hub airport changes (e.g. user just set/changed it),
    // reflect that in the search origin automatically.
    if (widget.initialOriginIata != oldWidget.initialOriginIata) {
      setState(() {
        _originIata = widget.initialOriginIata;
        _fetchPrice();
      });
    }
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  // Built from current state (not the stale value captured when this widget
  // was first constructed), so it stays correct as origin/dest/date change.
  String get _currentFallbackUrl => buildTripComFlightUrl(_originIata, _destinationIata, _date);

  Airport? _airportFor(String iata) =>
      widget.airportProvider.allAirports.firstWhereOrNull((a) => a.iataCode == iata);

  void _fetchPrice() {
    debugPrint('[FlightSearchCard DEBUG] calling getFlightPrice(origin=$_originIata, '
        'dest=$_destinationIata, date=$_dateStr, stops=$_stops)');
    _priceFuture = FlightPriceService.getPrice(
      originIata: _originIata,
      destinationIata: _destinationIata,
      date: _dateStr,
      stops: _stops,
    ).then((result) {
      debugPrint('[FlightSearchCard DEBUG] getFlightPrice SUCCESS: found=${result.found}, '
          'price=${result.priceFormatted}, priceSource=${result.priceSource}, itineraryId=${result.itineraryId}, sessionId=${result.sessionId}');
      return result;
    }).catchError((e, st) {
      if (e is FirebaseFunctionsException) {
        debugPrint('[FlightSearchCard DEBUG] getFlightPrice THREW FirebaseFunctionsException — '
            'code=${e.code}, message=${e.message}, details=${e.details}');
      } else {
        debugPrint('[FlightSearchCard DEBUG] getFlightPrice THREW (non-Functions error): $e');
      }
      throw e;
    });
  }

  Future<void> _pickOrigin() async {
    final picked = await showModalBottomSheet<Airport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AirportPickerSheet(
        title: 'Flying from',
        airportProvider: widget.airportProvider,
        themeColor: widget.themeColor,
      ),
    );
    if (picked != null) {
      setState(() {
        _originIata = picked.iataCode;
        _fetchPrice();
      });
    }
  }

  Future<void> _pickDestination() async {
    final picked = await showModalBottomSheet<Airport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AirportPickerSheet(
        title: 'Flying to',
        airportProvider: widget.airportProvider,
        themeColor: widget.themeColor,
      ),
    );
    if (picked != null) {
      setState(() {
        _destinationIata = picked.iataCode;
        _fetchPrice();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _fetchPrice();
      });
    }
  }

  void _setStops(String? stops) {
    if (_stops == stops) return;
    setState(() {
      _stops = stops;
      _fetchPrice();
    });
  }

  Future<void> _onBookTap(FlightPriceResult result) async {
    // Previously tried FlightPriceService.getBookingLink() first (a Skyscanner
    // deep link via itineraryId/sessionId) and only fell back to a plain
    // search URL if that failed. Skyscanner's affiliate application was
    // rejected, so that deep link no longer earns commission — booking now
    // goes straight to the Trip.com affiliate URL instead. getFlightPrice()
    // (the price estimate shown above) is untouched; only the destination of
    // the "Book" tap changed.
    await widget.onOpenUrl(_currentFallbackUrl);
  }

  Widget _chip({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: widget.themeColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.themeColor.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: widget.themeColor),
            const SizedBox(width: 5),
            Text(tr(label), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.themeColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow() {
    final originAirport = _airportFor(_originIata);
    final destAirport = _airportFor(_destinationIata);
    final dateLabel = '${_date.month}/${_date.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              icon: Icons.flight_takeoff_rounded,
              label: originAirport?.iataCode ?? _originIata,
              onTap: _pickOrigin,
            ),
            _chip(
              icon: Icons.flight_land_rounded,
              label: destAirport?.iataCode ?? _destinationIata,
              onTap: _pickDestination,
            ),
            _chip(icon: Icons.calendar_today_rounded, label: dateLabel, onTap: _pickDate),
            GestureDetector(
              onTap: () => _setStops(_stops == 'direct' ? null : 'direct'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _stops == 'direct' ? widget.themeColor : widget.themeColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.themeColor.withOpacity(0.15)),
                ),
                child: Text(
                  tr(_stops == 'direct' ? 'Direct only' : 'Any stops'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _stops == 'direct' ? Colors.white : widget.themeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Always-visible entry point to add/change the persisted home hub airport
        // (same picker used when no hub is set at all, opened here on demand).
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _TravelModalHubSetupSheet(
              airportProvider: widget.airportProvider,
              themeColor: widget.themeColor,
            ),
          ),
          child: Text(
            tr('Change home airport'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.themeColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final routeLabel = '$_originIata → $_destinationIata';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildControlsRow(),
          const SizedBox(height: 14),
          FutureBuilder<FlightPriceResult>(
            future: _priceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.themeColor),
                    ),
                    const SizedBox(width: 12),
                    Text(tr('Checking fares for $routeLabel…'), style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                );
              }

              if (snapshot.hasError || snapshot.data?.found != true) {
                if (snapshot.hasError) {
                  // TEMP DEBUG: remove once flight price fetching is confirmed working
                  debugPrint('[FlightSearchCard] getFlightPrice failed: ${snapshot.error}');
                }
                return GestureDetector(
                  onTap: () => widget.onOpenUrl(_currentFallbackUrl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(tr('Price unavailable for this date — tap to search'),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
                    ],
                  ),
                );
              }

              final result = snapshot.data!;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tr(result.priceFormatted ?? '-'),
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.themeColor),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (result.isTripComPrice ? widget.themeColor : Colors.grey.shade400).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tr(result.isTripComPrice ? 'Trip.com price' : 'Estimated'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: result.isTripComPrice ? widget.themeColor : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr([
                            if (result.isDirect) 'Direct' else if (result.stopCount != null) '${result.stopCount} stop(s)',
                            if (result.carrier != null) result.carrier!,
                          ].join(' · ')),
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
                          :  Text(tr('Book'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic one-off airport picker (does NOT touch the persisted hub — used for
// changing the origin/destination of a single search within _FlightSearchCard).
// ─────────────────────────────────────────────────────────────────────────────
class _AirportPickerSheet extends StatefulWidget {
  final String title;
  final AirportProvider airportProvider;
  final Color themeColor;

  const _AirportPickerSheet({
    required this.title,
    required this.airportProvider,
    required this.themeColor,
  });

  @override
  State<_AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<_AirportPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Airport> _filteredAirports() {
    final all = widget.airportProvider.allAirports;
    if (_query.trim().isEmpty) return const [];
    final q = _query.trim().toLowerCase();
    final results = all.where((a) {
      return a.name.toLowerCase().contains(q) || a.iataCode.toLowerCase().contains(q);
    }).toList();
    results.sort((a, b) {
      final aExact = a.iataCode.toLowerCase() == q ? 0 : 1;
      final bExact = b.iataCode.toLowerCase() == q ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      return a.name.compareTo(b.name);
    });
    return results.take(30).toList();
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final a = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final results = _filteredAirports();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(tr(widget.title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: tr('e.g. ICN, Incheon International'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _query.trim().isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(tr('Start typing to find an airport'), style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                      : results.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(tr('No matching airports found'), style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                      : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final airport = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tr(_flagEmoji(airport.country)), style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(
                          airport.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(airport.iataCode),
                        onTap: () => Navigator.of(context).pop(airport),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Hub airport setup sheet (same behavior as flights_menu_screen.dart's hub setup,
// reimplemented here since that one is private to its own file). Selecting an
// airport calls AirportProvider.updateHubStatus, which notifies listeners — the
// flight card in this modal is already watching AirportProvider, so it updates
// to the real price card immediately after selection.
// ─────────────────────────────────────────────────────────────────────────────
class _TravelModalHubSetupSheet extends StatefulWidget {
  final AirportProvider airportProvider;
  final Color themeColor;

  const _TravelModalHubSetupSheet({
    required this.airportProvider,
    required this.themeColor,
  });

  @override
  State<_TravelModalHubSetupSheet> createState() => _TravelModalHubSetupSheetState();
}

class _TravelModalHubSetupSheetState extends State<_TravelModalHubSetupSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Airport> _filteredAirports() {
    final all = widget.airportProvider.allAirports;
    if (_query.trim().isEmpty) return const [];
    final q = _query.trim().toLowerCase();
    // Matches by airport name or IATA code only (no city field on the Airport model)
    final results = all.where((a) {
      return a.name.toLowerCase().contains(q) || a.iataCode.toLowerCase().contains(q);
    }).toList();
    results.sort((a, b) {
      final aExact = a.iataCode.toLowerCase() == q ? 0 : 1;
      final bExact = b.iataCode.toLowerCase() == q ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      return a.name.compareTo(b.name);
    });
    return results.take(30).toList();
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final a = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final b = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  void _selectHub(Airport airport) {
    widget.airportProvider.updateHubStatus(airport.iataCode, true);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('${airport.name} is now set as your Hub', entities: [airport.name])),
        backgroundColor: widget.themeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final results = _filteredAirports();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_location_alt, color: widget.themeColor),
                      ),
                      const SizedBox(width: 12),
                       Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Set Your Hub'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text(tr('Search by airport name or IATA code'),
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: tr('e.g. ICN, Incheon International'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _query.trim().isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(tr('Start typing to find your airport'), style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                      : results.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(tr('No matching airports found'), style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                      : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final airport = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tr(_flagEmoji(airport.country)), style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(
                          airport.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(airport.iataCode),
                        onTap: () => _selectHub(airport),
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
}
