// lib/screens/world_discover_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/city_travel_modal.dart';

/// World Discover — a separate exploration screen from the existing Recommendations (AI Match).
/// The list uses CityProvider's real GaWC city data, same as top_cities_screen.
/// Tapping a card opens city_travel_modal.dart (stays/flights/tips, for affiliate revenue).
/// (Note: card thumbnail images reuse city_detail_modal.dart's _heroUrl rule.)
class WorldDiscoverScreen extends StatefulWidget {
  const WorldDiscoverScreen({super.key});

  @override
  State<WorldDiscoverScreen> createState() => _WorldDiscoverScreenState();
}

class _WorldDiscoverScreenState extends State<WorldDiscoverScreen> {
  static const Color mint = Color(0xFF1ABFBC);
  static const Color darkMint = Color(0xFF009688);

  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Trending',
    'Nature',
    'Culture',
    'Food',
    'Hidden Gems',
  ];

  // Same image source rule as city_detail_modal.dart's _heroUrl
  String _toSnake(String s) {
    String r = s.toLowerCase();
    r = r.replaceAll(RegExp(r"[''`]"), '');
    r = r.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return r.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  String _getCityImageUrl(String cityName) {
    // Exception: San José (Costa Rica) vs San Jose (USA) — same as city_detail_modal.dart
    String filename;
    if (cityName == 'San José') {
      filename = 'san_jose_cr';
    } else {
      filename = _toSnake(cityName);
    }
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/ranked_cities%2F$filename.jpg.jpg?alt=media';
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Consumer2<CityProvider, CountryProvider>(
          builder: (context, cityProvider, countryProvider, _) {
            if (cityProvider.isLoading || countryProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Same real GaWC global city list as top_cities_screen
            final List<City> cities = cityProvider.gawcCities
                .where((c) => c.gawcTier != 'N/A')
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFFF7F8FA),
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'Discover',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  centerTitle: false,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildCategoryChips(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 36,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.92,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildDestinationCard(context, cities[index]),
                      childCount: cities.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 10),
          Text(
            'Search destinations',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? mint : Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: isSelected
                    ? []
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Same layout as top_cities_screen.dart's Photo Grid card
  Widget _buildDestinationCard(BuildContext context, City city) {
    return GestureDetector(
      onTap: () => showCityTravelModal(context, city),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _getCityImageUrl(city.name),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: const Color(0xFFF3F4F6)),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: Icon(Icons.image_rounded, color: Colors.grey.shade300, size: 28),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _getFlagEmoji(city.countryIsoA2),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  city.name,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            city.country,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}