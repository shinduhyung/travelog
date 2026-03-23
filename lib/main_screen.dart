// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/screens/cities_menu_screen.dart';
import 'package:jidoapp/screens/countries_menu_screen.dart';
import 'package:jidoapp/screens/explore_menu_screen.dart';
import 'package:jidoapp/screens/flights_menu_screen.dart';
import 'package:jidoapp/screens/my_trips_tab_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    const MyTripsTabScreen(),
    const CountriesMenuScreen(),
    const CitiesMenuScreen(),
    const ExploreMenuScreen(),
    FlightsMenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  final List<IconData> _icons = [
    Icons.card_travel,
    Icons.public,
    Icons.add_location_alt_rounded,
    Icons.explore,
    Icons.flight_takeoff_rounded,
  ];

  final List<String> _labels = [
    'My Trips',
    'Countries',
    'Cities',
    'Explore',
    'Flights',
  ];

  final Color mintColor = const Color(0xFF3DDAD7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_icons.length, (index) {
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () => _onItemTapped(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? mintColor.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icons[index],
                              size: isSelected ? 28 : 24,
                              color: isSelected ? mintColor : Colors.grey),
                          const SizedBox(height: 4),
                          Text(_labels[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? mintColor : Colors.grey,
                              )),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}