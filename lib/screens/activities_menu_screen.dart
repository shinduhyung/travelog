// lib/screens/activities_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/screens/landmarks_list_screen.dart';
import 'package:jidoapp/screens/top_activities_menu_screen.dart';

class ActivitiesMenuScreen extends StatelessWidget {
  const ActivitiesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cultureAndArtsItems = [
      {'title': 'Painting & Artworks', 'imagePath': 'assets/explore_icons/paintings.png', 'attributes': ['Painting', 'Artwork']},
      {'title': 'Libraries & Bookstores', 'imagePath': 'assets/explore_icons/library.png', 'attributes': ['Library', 'Bookstore']},
      {'title': 'Filming Locations', 'imagePath': 'assets/explore_icons/filming_locations.png', 'attributes': ['Filming Location']},
      {'title': 'Theaters', 'imagePath': 'assets/explore_icons/theaters.png', 'attributes': ['Theater', 'Performing Art']},
    ];

    final lifestyleItems = [
      {'title': 'National Dishes', 'imagePath': 'assets/explore_icons/food.png', 'attributes': ['Food']},
      {'title': 'Restaurants', 'imagePath': 'assets/explore_icons/restaurants.png', 'attributes': ['Restaurant']},
      {'title': 'Breweries', 'imagePath': 'assets/explore_icons/brewery.png', 'attributes': ['Brewery', 'Winery']},
      {'title': 'Starbucks Reserve', 'imagePath': 'assets/explore_icons/starbucks.png', 'attributes': ['Cafe']},
      {'title': 'Fast Food', 'imagePath': 'assets/explore_icons/fast_food.png', 'attributes': ['Fast Food']},
    ];

    final leisureItems = [
      {'title': 'Festivals & Events', 'imagePath': 'assets/explore_icons/festival.png', 'attributes': ['Festival', 'Event']},
      {'title': 'Amusement Parks', 'imagePath': 'assets/explore_icons/amusement_parks.png', 'attributes': ['Amusement Park']},
      {'title': 'Football Stadiums', 'imagePath': 'assets/explore_icons/football_stadiums.png', 'attributes': ['Football Stadium']},
      {'title': 'Zoos', 'imagePath': 'assets/explore_icons/zoo.png', 'attributes': ['Zoo']},
      {'title': 'Aquariums', 'imagePath': 'assets/explore_icons/aquarium.png', 'attributes': ['Aquarium']},
      {'title': 'Cruise Tours', 'imagePath': 'assets/explore_icons/cruise_tours.png', 'attributes': ['Cruise Tour']},
      {'title': 'Cable Cars', 'imagePath': 'assets/explore_icons/cable_car.png', 'attributes': ['Cable Car']},
    ];

    final Color bgColor = const Color(0xFFF8F9FA);
    final Color primaryAccent = const Color(0xFF6366F1);
    final Color accentBlack = const Color(0xFF0F172A);
    final Color cultureColor = const Color(0xFFEC4899);
    final Color lifestyleColor = const Color(0xFFF59E0B);
    final Color leisureColor = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explore',
                                style: TextStyle(
                                  fontSize: 37,
                                  fontWeight: FontWeight.w900,
                                  color: accentBlack,
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Activities',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: primaryAccent,
                                  letterSpacing: -0.5,
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
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Top Picks
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    if (authProvider.user == null) {
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
                      MaterialPageRoute(builder: (_) => const TopActivitiesMenuScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryAccent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Picks',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: accentBlack,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Must-visit destinations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: accentBlack.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryAccent,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // Culture & Arts
            SliverToBoxAdapter(
              child: _buildCategorySection(
                context,
                'Culture & Arts',
                cultureAndArtsItems,
                cultureColor,
                accentBlack,
                Icons.palette_outlined,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),

            // Lifestyle
            SliverToBoxAdapter(
              child: _buildCategorySection(
                context,
                'Lifestyle',
                lifestyleItems,
                lifestyleColor,
                accentBlack,
                Icons.restaurant_outlined,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),

            // Leisure & Entertainment
            SliverToBoxAdapter(
              child: _buildCategorySection(
                context,
                'Leisure & Entertainment',
                leisureItems,
                leisureColor,
                accentBlack,
                Icons.celebration_outlined,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> items,
      Color accentColor,
      Color textColor,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withOpacity(0.15),
                      accentColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 16),
              child: _buildActivityCard(context, items[index], accentColor, textColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(
      BuildContext context,
      Map<String, dynamic> item,
      Color accentColor,
      Color textColor,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LandmarksListScreen(
              title: item['title'] as String,
              attributes: item['attributes'] as List<String>,
            ),
          ),
        );
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      item['imagePath'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 36),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                item['title'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.3,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}