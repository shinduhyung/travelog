// lib/screens/landmarks_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/screens/landmarks_list_screen.dart';

class LandmarksMenuScreen extends StatelessWidget {
  const LandmarksMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final categories = [
      {'title': 'Ancient & Medieval', 'imagePath': 'assets/explore_icons/ancient_ruins.png', 'attributes': ['Ancient Site']},
      {'title': 'Modern History', 'imagePath': 'assets/explore_icons/historical_sites.png', 'attributes': ['Modern History']},
      {'title': 'Archaeological Sites', 'imagePath': 'assets/explore_icons/archaeological_sites.png', 'attributes': ['Archaeological Site']},
      {'title': 'Traditional Villages', 'imagePath': 'assets/explore_icons/traditional_villages.png', 'attributes': ['Traditional Village']},
      {'title': 'Castles & Forts', 'imagePath': 'assets/explore_icons/castles.png', 'attributes': ['Castle']},
      {'title': 'Palaces', 'imagePath': 'assets/explore_icons/palaces.png', 'attributes': ['Palace']},
      {'title': 'Modern Architecture', 'imagePath': 'assets/explore_icons/modern_architecture.png', 'attributes': ['Modern Architecture']},
      {'title': 'Towers', 'imagePath': 'assets/explore_icons/towers_skyscrapers.png', 'attributes': ['Tower', 'Skyscraper']},
      {'title': 'Bridges', 'imagePath': 'assets/explore_icons/bridges.png', 'attributes': ['Bridge']},
      {'title': 'Arches & Gates', 'imagePath': 'assets/explore_icons/gates.png', 'attributes': ['Gate']},
      {'title': 'Christian', 'imagePath': 'assets/explore_icons/christian.png', 'attributes': ['Christian']},
      {'title': 'Islamic', 'imagePath': 'assets/explore_icons/islamic.png', 'attributes': ['Islamic']},
      {'title': 'Buddhist', 'imagePath': 'assets/explore_icons/buddhist.png', 'attributes': ['Buddhist']},
      {'title': 'Hindu', 'imagePath': 'assets/explore_icons/hindu.png', 'attributes': ['Hindu']},
      {'title': 'Other Religions', 'imagePath': 'assets/explore_icons/other_religion.png', 'attributes': ['Other Religion']},
      {'title': 'Tombs & Cemeteries', 'imagePath': 'assets/explore_icons/tombs.png', 'attributes': ['Tomb']},
      {'title': 'Museums & Galleries', 'imagePath': 'assets/explore_icons/museums.png', 'attributes': ['Museum']},
      {'title': 'Squares & Old Towns', 'imagePath': 'assets/explore_icons/historical_squares.png', 'attributes': ['Historical Square', 'Old Town']},
      {'title': 'Urban Hubs', 'imagePath': 'assets/explore_icons/urban_hubs.png', 'attributes': ['Urban Hub']},
      {'title': 'Universities', 'imagePath': 'assets/explore_icons/universities.png', 'attributes': ['University']},
      {'title': 'Markets', 'imagePath': 'assets/explore_icons/markets.png', 'attributes': ['Market']},
      {'title': 'Statues', 'imagePath': 'assets/explore_icons/statues.png', 'attributes': ['Statue']},
      {'title': 'Parks & Gardens', 'imagePath': 'assets/explore_icons/parks.png', 'attributes': ['Park', 'Garden']},
      {'title': 'Harbors & Waterfronts', 'imagePath': 'assets/explore_icons/harbors.png', 'attributes': ['Harbor']},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child:  Text(
                tr('Cultural Wonders'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
            ),

            // Grid - 3 columns
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) => _buildCard(context, categories[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item) {
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: Image.asset(
                  item['imagePath'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[100],
                    child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 28),
                  ),
                ),
              ),
              // Gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  tr(item['title'] as String),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}