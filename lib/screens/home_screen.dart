// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/screens/cities_menu_screen.dart';
import 'package:jidoapp/screens/countries_menu_screen.dart';
import 'package:jidoapp/screens/explore_menu_screen.dart';
import 'package:jidoapp/screens/flights_menu_screen.dart';
import 'package:jidoapp/screens/my_trips_tab_screen.dart'; // <<< 수정된 부분
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Consumer<BadgeProvider>(
      builder: (context, badgeProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (badgeProvider.newlyUnlockedAchievements.isNotEmpty && context.mounted) {
            for (var achievement in badgeProvider.newlyUnlockedAchievements) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('🎉 ${achievement.name} Unlocked!')),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            badgeProvider.clearNewlyUnlocked();
          }
        });
        return child!;
      },
      child: Scaffold(
        appBar: AppBar(
          title:  Text(tr('jidoapp'), style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1564419429381-98dbcf916478?q=80&w=2574&auto=format&fit=crop'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuButton(context, 'Countries', Icons.public, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CountriesMenuScreen()));
                  }),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'Cities', Icons.location_city, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CitiesMenuScreen()));
                  }),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'Explore', Icons.explore, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ExploreMenuScreen()));
                  }),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'Transports', Icons.flight, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => FlightsMenuScreen()));
                  }),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'My Trips', Icons.card_travel, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTripsTabScreen())); // <<< 수정된 부분
                  }),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'Settings', Icons.settings, () {
                    // TODO: Settings 기능 구현
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(tr(title), style: const TextStyle(fontSize: 18, color: Colors.white)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.5),
        minimumSize: const Size(250, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Colors.white70),
      ),
    );
  }
}