// lib/screens/natural_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/screens/landmarks_list_screen.dart';

class NaturalMenuScreen extends StatelessWidget {
  const NaturalMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final categories = [
      {'title': 'Seas', 'imagePath': 'assets/explore_icons/seas.png', 'attributes': ['Sea']},
      {'title': 'Beaches', 'imagePath': 'assets/explore_icons/beaches.png', 'attributes': ['Beach']},
      {'title': 'Rivers', 'imagePath': 'assets/explore_icons/rivers.png', 'attributes': ['River']},
      {'title': 'Lakes', 'imagePath': 'assets/explore_icons/lakes.png', 'attributes': ['Lake']},
      {'title': 'Waterfalls', 'imagePath': 'assets/explore_icons/falls.png', 'attributes': ['Falls']},
      {'title': 'Islands', 'imagePath': 'assets/explore_icons/islands.png', 'attributes': ['Island']},
      {'title': 'Mountains', 'imagePath': 'assets/explore_icons/mountains.png', 'attributes': ['Mountain']},
      {'title': 'Deserts', 'imagePath': 'assets/explore_icons/deserts.png', 'attributes': ['Desert']},
      {'title': 'Volcanic & Lava', 'imagePath': 'assets/explore_icons/volcanoes.png', 'attributes': ['Volcano']},
      {'title': 'Canyons & Cliffs', 'imagePath': 'assets/explore_icons/canyons.png', 'attributes': ['Canyon']},
      {'title': 'Caves & Underground', 'imagePath': 'assets/explore_icons/caves.png', 'attributes': ['Cave']},
      {'title': 'Geothermal', 'imagePath': 'assets/explore_icons/geothermal.png', 'attributes': ['Geothermal']},
      {'title': 'Glaciers', 'imagePath': 'assets/explore_icons/glaciers.png', 'attributes': ['Glacier']},
      {'title': 'Forests & Jungles', 'imagePath': 'assets/explore_icons/forests.png', 'attributes': ['Jungle']},
      {'title': 'Unique Landscapes', 'imagePath': 'assets/explore_icons/unique_landscapes.png', 'attributes': ['Unique Landscape']},
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
                tr('Natural Wonders'),
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