// lib/providers/badge_provider.dart

import 'package:flutter/foundation.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'dart:math';
import 'package:jidoapp/models/economy_data_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:jidoapp/services/subscription_service.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


const Map<String, String> airlineAllianceCodes = {
  // SkyTeam
  "AMX": "SkyTeam", // Aeroméxico
  "AEA": "SkyTeam", // Air Europa
  "AFR": "SkyTeam", // Air France
  "CAL": "SkyTeam", // China Airlines
  "CES": "SkyTeam", // China Eastern
  "DAL": "SkyTeam", // Delta Air Lines
  "GIA": "SkyTeam", // Garuda Indonesia
  "KLM": "SkyTeam", // KLM
  "KAL": "SkyTeam", // Korean Air
  "MEA": "SkyTeam", // Middle East Airlines
  "SVA": "SkyTeam", // Saudia
  "SAS": "SkyTeam", // Scandinavian Airlines (SAS)
  "ROT": "SkyTeam", // Tarom
  "HVN": "SkyTeam", // Vietnam Airlines
  "VIR": "SkyTeam", // Virgin Atlantic
  "CXA": "SkyTeam", // Xiamen Airlines
  "KQA": "SkyTeam", // Kenya Airways
  "ARG": "SkyTeam", // Aerolineas Argentinas

  // Star Alliance
  "AEE": "Star Alliance", // Aegean Airlines
  "ACA": "Star Alliance", // Air Canada
  "CCA": "Star Alliance", // Air China
  "AIC": "Star Alliance", // Air India
  "ANZ": "Star Alliance", // Air New Zealand
  "ANA": "Star Alliance", // All Nippon Airways
  "AAR": "Star Alliance", // Asiana Airlines
  "AUA": "Star Alliance", // Austrian Airlines
  "AVA": "Star Alliance", // Avianca
  "BEL": "Star Alliance", // Brussels Airlines
  "CMP": "Star Alliance", // Copa Airlines
  "CTN": "Star Alliance", // Croatia Airlines
  "MSR": "Star Alliance", // EgyptAir
  "ETH": "Star Alliance", // Ethiopian Airlines
  "EVA": "Star Alliance", // EVA Air
  "LOT": "Star Alliance", // LOT Polish Airlines
  "DLH": "Star Alliance", // Lufthansa
  "CSZ": "Star Alliance", // Shenzhen Airlines
  "SIA": "Star Alliance", // Singapore Airlines
  "SAA": "Star Alliance", // South African Airways
  "SWR": "Star Alliance", // SWISS International Air Lines
  "TAP": "Star Alliance", // TAP Air Portugal
  "THA": "Star Alliance", // Thai Airways International
  "THY": "Star Alliance", // Turkish Airlines
  "UAL": "Star Alliance", // United Airlines

  // OneWorld
  "ASA": "OneWorld", // Alaska Airlines
  "AAL": "OneWorld", // American Airlines
  "BAW": "OneWorld", // British Airways
  "CPA": "OneWorld", // Cathay Pacific
  "FJI": "OneWorld", // Fiji Airways
  "FIN": "OneWorld", // Finnair
  "IBE": "OneWorld", // Iberia
  "JAL": "OneWorld", // Japan Airlines
  "MAS": "OneWorld", // Malaysia Airlines
  "OMA": "OneWorld", // Oman Air
  "QFA": "OneWorld", // Qantas
  "QTR": "OneWorld", // Qatar Airways
  "RAM": "OneWorld", // Royal Air Maroc
  "RJA": "OneWorld"  // Royal Jordanian
};

class BadgeProvider with ChangeNotifier {
  List<Achievement> _newlyUnlocked = [];
  List<Achievement> get newlyUnlocked => _newlyUnlocked;

  // [추가] 프리미엄 전용 뱃지 조건을 방금 막 채웠지만 구독이 안 되어 있어
  // 실제로는 잠긴 상태로 남은 것들. "조건 다 채웠는데 구독을 안해서 못 얻은" 순간에
  // 전용 팝업(구독 유도)을 띄우기 위한 큐.
  List<Achievement> _newlyPendingPremiumClaim = [];
  List<Achievement> get newlyPendingPremiumClaim => _newlyPendingPremiumClaim;

  // 랭크 시스템 관련 변수
  String? _newRankUnlocked;
  String? get newRankUnlocked => _newRankUnlocked;
  String _currentRank = 'Rookie';
  String get currentRank => _currentRank;

  // [추가] 초기화 상태 확인용
  bool _isInitialized = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const double _1e9 = 1000000000.0;
  bool _hasDebuggedLandmarks = false;

  static const Set<String> culturalAttributes = {
    'Ancient Site', 'Modern History', 'Archaeological Site', 'Traditional Village',
    'Castle', 'Palace', 'Modern Architecture', 'Tower', 'Skyscraper', 'Bridge',
    'Gate', 'Christian', 'Islamic', 'Buddhist', 'Hindu', 'Other Religion',
    'Tomb', 'Museum', 'Historical Square', 'Old Town', 'Urban Hub', 'University',
    'Market', 'Statue', 'Park', 'Garden', 'Harbor'
  };

  static const Set<String> naturalAttributes = {
    'Sea', 'Beach', 'River', 'Lake', 'Falls', 'Island', 'Mountain',
    'Desert', 'Volcano', 'Canyon', 'Cave', 'Geothermal', 'Glacier',
    'Jungle', 'Unique Landscape'
  };

  bool isCulturalLandmark(List<String> attributes) {
    return attributes.any((attr) => culturalAttributes.contains(attr));
  }

  bool isNaturalLandmark(List<String> attributes) {
    return attributes.any((attr) => naturalAttributes.contains(attr));
  }

  final List<Achievement> _achievements = [
    Achievement(
      id: 'country_home',
      name: 'Home Country',
      description: 'Set at least one country as Home.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/country_home.png',
      category: AchievementCategory.Country,
      requiresHome: true,
    ),
    Achievement(
      id: 'country_rating',
      name: 'Country Reviewer',
      description: 'Rate at least one country.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/country_rating.png',
      category: AchievementCategory.Country,
      requiresRating: true,
    ),
    Achievement(
      id: 'countries_10',
      name: '10 Countries',
      description: 'Visit 10 different countries.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/countries_10.png',
      category: AchievementCategory.Country,
      targetCount: 10,
    ),
    Achievement(
      id: 'countries_50',
      name: '50 Countries',
      description: 'Visit 50 different countries.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 7,
      imagePath: 'assets/badges/countries_50.png',
      category: AchievementCategory.Country,
      targetCount: 50,
    ),
    Achievement(
      id: 'countries_100',
      name: '100 Countries',
      description: 'Visit 100 different countries.',
      difficulty: AchievementDifficulty.Globetrotter,
      points: 30,
      imagePath: 'assets/badges/countries_100.png',
      category: AchievementCategory.Country,
      targetCount: 100,
    ),
    Achievement(
      id: 'continents_3',
      name: '3 Continents',
      description: 'Visit countries in 3 different continents.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/continents_3.png',
      category: AchievementCategory.Country,
      targetCount: 3,
    ),
    Achievement(
      id: 'continents_6',
      name: '6 Continents',
      description: 'Visit countries in all 6 inhabited continents.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/continents_6.png',
      category: AchievementCategory.Country,
      targetCount: 6,
    ),
    Achievement(
      id: 'population_4billion',
      name: '4 Billion Population',
      description: 'Visit countries with a combined population of 4 billion.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/population_4billion.png',
      category: AchievementCategory.Country,
      targetPopulationLimit: 4000000000,
    ),
    Achievement(
      id: 'gdp_50percent',
      name: '60 Trillion GDP',
      description: 'Visit countries with a combined GDP of 60 trillion dollars.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/gdp_50percent.png',
      category: AchievementCategory.Country,
      targetGdpLimit: 60000000000000.0,
    ),
    Achievement(
      id: 'area_50percent',
      name: '75 Million km²',
      description: 'Visit countries covering 75 million km² of land area.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/area_50percent.png',
      category: AchievementCategory.Country,
      targetAreaLimit: 75000000,
    ),
    Achievement(
      id: 'africa_10',
      name: 'Africa',
      description: 'Visit 10 different countries in Africa.',
      difficulty: AchievementDifficulty.Nomad,
      points: 10,
      imagePath: 'assets/badges/africa_10.png',
      category: AchievementCategory.Country,
      targetCount: 10,
    ),
    Achievement(
      id: 'asia_20',
      name: 'Asia',
      description: 'Visit 20 different countries in Asia.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/asia_20.png',
      category: AchievementCategory.Country,
      targetCount: 20,
    ),
    Achievement(
      id: 'europe_20',
      name: 'Europe',
      description: 'Visit 20 different countries in Europe.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/europe_20.png',
      category: AchievementCategory.Country,
      targetCount: 20,
    ),
    Achievement(
      id: 'americas_10',
      name: 'Americas',
      description: 'Visit 10 different countries in the Americas.',
      difficulty: AchievementDifficulty.Nomad,
      points: 10,
      imagePath: 'assets/badges/americas_10.png',
      category: AchievementCategory.Country,
      targetCount: 10,
    ),
    Achievement(
      id: 'benelux',
      name: 'Benelux',
      description: 'Visit Belgium, Netherlands, and Luxembourg.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/benelux.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'BEL', 'NLD', 'LUX'},
    ),
    Achievement(
      id: 'scandinavian',
      name: 'Scandinavia',
      description: 'Visit Denmark, Norway, and Sweden.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/scandinavian.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'DNK', 'NOR', 'SWE'},
    ),
    Achievement(
      id: 'baltic',
      name: 'Baltics',
      description: 'Visit Estonia, Latvia, and Lithuania.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/baltic.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'EST', 'LVA', 'LTU'},
    ),
    Achievement(
      id: 'caucasus',
      name: 'Caucasus',
      description: 'Visit Armenia, Azerbaijan, and Georgia.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/caucasus.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'ARM', 'AZE', 'GEO'},
    ),
    Achievement(
      id: 'microstates',
      name: 'Microstates',
      description: 'Visit Vatican, Monaco, Liechtenstein, Andorra, San Marino, and Malta.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/microstates.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'VAT', 'MCO', 'LIE', 'AND', 'SMR', 'MLT'},
    ),
    Achievement(
      id: 'visitor_top_10',
      name: 'Top Visited',
      description: 'Visit the top 10 most visited countries.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/visitor_top_10.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'FRA', 'ESP', 'USA', 'CHN', 'ITA', 'TUR', 'MEX', 'THA', 'DEU', 'GBR'},
    ),
    Achievement(
      id: 'world_cup',
      name: 'World Cup',
      description: 'Visit all World Cup winning countries.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 7,
      imagePath: 'assets/badges/world_cup.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'URY', 'ITA', 'DEU', 'BRA', 'GBR', 'ARG', 'FRA', 'ESP'},
    ),
    Achievement(
      id: 'un_security',
      name: 'UN Security',
      description: 'Visit all 5 UN Permanent Security Council members.',
      difficulty: AchievementDifficulty.Nomad,
      points: 5,
      imagePath: 'assets/badges/un_security.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'USA', 'CHN', 'RUS', 'FRA', 'GBR'},
    ),
    Achievement(
      id: 'soviet_union',
      name: 'USSR',
      description: 'Visit all 15 former Soviet Union republics.',
      difficulty: AchievementDifficulty.Globetrotter,
      points: 30,
      imagePath: 'assets/badges/soviet_union.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {
        'ARM', 'AZE', 'BLR', 'EST', 'GEO',
        'KAZ', 'KGZ', 'LVA', 'LTU', 'MDA',
        'RUS', 'TJK', 'TKM', 'UKR', 'UZB'
      },
    ),
    Achievement(
      id: 'unified_korea',
      name: 'Unified Korea',
      description: 'Visit both South Korea and North Korea.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/badges/unified_korea.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'KOR', 'PRK'},
    ),
    Achievement(
      id: 'eu_all',
      name: 'European Union',
      description: 'Visit all EU member states.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/eu_all.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {
        'AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA',
        'DEU', 'GRC', 'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD',
        'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE'
      },
    ),
    Achievement(
      id: 'city_home',
      name: 'Home City',
      description: 'Set at least one city as Home.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/city_home.png',
      category: AchievementCategory.City,
      requiresHome: true,
    ),
    Achievement(
      id: 'city_rating',
      name: 'City Reviewer',
      description: 'Rate at least one city.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/city_rating.png',
      category: AchievementCategory.City,
      requiresRating: true,
    ),
    Achievement(
      id: 'both_hemispheres',
      name: 'Both Hemispheres',
      description: 'Visit cities in both Northern and Southern hemispheres.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/both_hemispheres.png',
      category: AchievementCategory.City,
      targetCount: 2,
    ),
    Achievement(
      id: 'top10_visited_cities',
      name: 'Top Destinations',
      description: 'Visit the top 10 most visited cities in the world.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/top10_visited_cities.png',
      category: AchievementCategory.City,
      targetIsoCodes: {
        'Bangkok', 'Istanbul', 'London', 'Hong Kong', 'Mecca',
        'Antalya', 'Dubai', 'Macau', 'Paris', 'Kuala Lumpur'
      },
    ),
    Achievement(
      id: 'gdp_top10_megacities',
      name: 'Global Megacities',
      description: 'Visit the top 10 GDP megacities.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/gdp_top10_megacities.png',
      category: AchievementCategory.City,
      targetIsoCodes: {
        'New York City', 'Tokyo', 'Los Angeles', 'San Francisco', 'Seoul',
        'Paris', 'Chicago', 'Shanghai', 'London', 'Beijing'
      },
    ),
    Achievement(
      id: 'un_headquarters',
      name: 'UN Headquarters',
      description: 'Visit all 4 UN headquarters cities.',
      difficulty: AchievementDifficulty.Nomad,
      points: 10,
      imagePath: 'assets/badges/un_headquarters.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'New York City', 'Geneva', 'Vienna', 'Nairobi'},
    ),
    Achievement(
      id: 'big_three_film_festivals',
      name: 'Film Festivals',
      description: 'Visit the Big Three Film Festival cities.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/big_three_film_festivals.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cannes', 'Venice', 'Berlin'},
    ),
    Achievement(
      id: 'big_four_fashion_weeks',
      name: 'Fashion Week',
      description: 'Visit all Big Four Fashion Week cities.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/big_four_fashion_weeks.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Paris', 'Milan', 'New York City', 'London'},
    ),
    Achievement(
      id: 'nobel_prize_cities',
      name: 'Nobel Prize',
      description: 'Visit all Nobel Prize ceremony cities.',
      difficulty: AchievementDifficulty.Rookie,
      points: 3,
      imagePath: 'assets/badges/nobel_prize_cities.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Stockholm', 'Oslo'},
    ),
    Achievement(
      id: 'north_60_latitude',
      name: 'North 60°',
      description: 'Visit a city above 60°N latitude.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/north_60_latitude.png',
      category: AchievementCategory.City,
      targetCount: 1,
    ),
    Achievement(
      id: 'south_40_latitude',
      name: 'South 40°',
      description: 'Visit a city below 40°S latitude.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/south_40_latitude.png',
      category: AchievementCategory.City,
      targetCount: 1,
    ),
    Achievement(
      id: 'capitals_20',
      name: '20 Capitals',
      description: 'Visit 20 different capital cities.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/capitals_20.png',
      category: AchievementCategory.City,
      targetCount: 20,
    ),
    Achievement(
      id: 'cities_50',
      name: '50 Cities',
      description: 'Visit 50 different cities.',
      difficulty: AchievementDifficulty.Nomad,
      points: 5,
      imagePath: 'assets/badges/cities_50.png',
      category: AchievementCategory.City,
      targetCount: 50,
    ),
    Achievement(
      id: 'cities_100',
      name: '100 Cities',
      description: 'Visit 100 different cities.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 7,
      imagePath: 'assets/badges/cities_100.png',
      category: AchievementCategory.City,
      targetCount: 100,
    ),
    Achievement(
      id: 'cities_300',
      name: '300 Cities',
      description: 'Visit 300 different cities.',
      difficulty: AchievementDifficulty.Globetrotter,
      points: 20,
      imagePath: 'assets/badges/cities_300.png',
      category: AchievementCategory.City,
      targetCount: 300,
    ),
    Achievement(
      id: 'top10_landmarks',
      name: 'Top 10 Landmarks',
      description: 'Visit the top 10 most iconic landmarks.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/top10_landmarks.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Eiffel Tower', 'Great Wall of China', 'Pyramids of Giza', 'Statue of Liberty',
        'Taj Mahal', 'Colosseum', 'Machu Picchu', 'Parthenon', 'Sydney Opera House', 'Big Ben'
      },
    ),
    Achievement(
      id: 'iconic_landmarks_100',
      name: 'Iconic Landmarks',
      description: 'Visit 100 of the world\'s most iconic landmarks.',
      difficulty: AchievementDifficulty.Globetrotter,
      points: 10,
      imagePath: 'assets/badges/iconic_landmarks_100.png',
      category: AchievementCategory.Landmarks,
      targetCount: 100,
      targetIsoCodes: {
        'Eiffel Tower', 'Great Wall of China', 'Pyramids of Giza', 'Statue of Liberty', 'Taj Mahal',
        'Colosseum', 'Machu Picchu', 'Parthenon', 'Sydney Opera House', 'Big Ben',
        'St. Peter\'s Basilica', 'Great Sphinx of Giza', 'Petra', 'Angkor Wat', 'Christ the Redeemer',
        'Stonehenge', 'Leaning Tower of Pisa', 'Burj Khalifa', 'Niagara Falls', 'Notre-Dame de Paris',
        'St. Basil\'s Cathedral', 'Empire State Building', 'Forbidden City', 'Times Square', 'Sagrada Familia',
        'Grand Canyon', 'Louvre Museum', 'Mount Everest', 'Great Barrier Reef', 'Amazon Rainforest',
        'Buckingham Palace', 'Yellowstone National Park', 'Palace of Versailles', 'Central Park', 'Golden Gate Bridge',
        'Mount Fuji', 'Terracotta Army', 'Chichen Itza', 'Tower Bridge', 'Hollywood Sign',
        'Moscow Kremlin', 'Sahara Desert', 'Trevi Fountain', 'The White House', 'Arc de Triomphe',
        'Auschwitz-Birkenau Memorial and Museum', 'Yosemite National Park', 'Iguazu Falls', 'Neuschwanstein Castle', 'Galapagos Islands',
        'Hagia Sophia', 'Victoria Falls', 'Mount Rushmore', 'Easter Island', 'Pompeii',
        'Sydney Harbour Bridge', 'British Museum', 'Tower of London', 'United States Capitol', 'Brandenburg Gate',
        'Brooklyn Bridge', 'Mont-Saint-Michel', 'Pantheon', 'Metropolitan Museum of Art', 'Mount Kilimanjaro',
        'London Eye', 'Alhambra', 'Dead Sea', 'Western Wall', 'Westminster Abbey',
        'Petronas Towers', 'Burj Al Arab', 'Marina Bay Sands', 'Matterhorn', 'Taipei 101',
        'Dome of the Rock', 'Uluru', 'Alcatraz', 'Blue Mosque', 'Lincoln Memorial',
        'Panama Canal', 'Duomo di Milano', 'Valley of the Kings', 'Ha Long Bay', 'Fushimi Inari Taisha',
        'Serengeti National Park', 'Hermitage Museum', 'Shibuya Crossing', 'Pearl Harbor National Memorial', 'Sacré-Cœur Basilica',
        'Park Güell', 'Berlin Wall Memorial', 'Hiroshima Peace Memorial', 'St. Mark\'s Basilica', 'Dubrovnik Old Town',
        'Cappadocia Fairy Chimneys', 'Edinburgh Castle', 'Salar de Uyuni', 'Amalfi Coast', 'Kinkaku-ji',
        'Sheikh Zayed Grand Mosque', 'Prague Castle', 'Teotihuacan', 'The Grand Palace', 'CN Tower',
        'Monument Valley', 'Banff National Park', 'Windsor Castle', 'Tokyo Tower', 'Gardens by the Bay',
        'Schönbrunn Palace', 'Florence Cathedral', 'Mount Vesuvius', 'Hoover Dam', 'Antelope Canyon',
        'Mont Blanc', 'Spanish Steps', 'French Polynesia', 'Space Needle', 'Blue Lagoon',
        'Golden Temple', 'Cape of Good Hope', 'Charles Bridge', 'Cologne Cathedral', 'Potala Palace',
        'Cinque Terre', 'Table Mountain', 'Sugarloaf Mountain', 'Palm Jumeirah', 'Kiyomizu-dera',
        'Borobudur Temple', 'Cliffs of Moher', 'Oia', 'Jungfrau', 'Itsukushima Shrine',
        'Nazca Lines', 'Abu Simbel Temples', 'Lake Titicaca', 'Mount Sinai', 'Rialto Bridge',
        'Casa Batlló', 'Arashiyama Bamboo Grove', 'DMZ', 'The Bund', 'Temple of Heaven',
        'Tokyo Skytree', 'Dolomites', 'Nyhavn', 'Mezquita-Cathedral of Córdoba', 'Tulum Ruins',
        'Seville Cathedral', 'Milford Sound', 'Oriental Pearl Tower', 'Bryce Canyon', 'Cloud Gate',
        'Atacama Desert', 'Gyeongbokgung Palace', 'Angel Falls', 'Death Valley', 'Torres del Paine',
        'Karnak Temple Complex', 'Summer Palace', 'Giant\'s Causeway', 'Grand Place', 'Wat Arun',
        'Perito Moreno Glacier', 'Leshan Giant Buddha', 'Ephesus Archaeological Site', 'Himeji Castle', 'Zion Canyon',
        'Lake Bled', 'Zhangjiajie National Forest', 'Pamukkale Travertine Terraces', 'Osaka Castle', 'Red Fort',
        'Monasteries of Meteora', 'Sanctuary of Olympia', 'Plitvice Lakes', 'Arches National Park', 'Bran Castle',
        'Victoria Peak', 'N Seoul Tower', 'Belém Tower', 'Hobbiton Movie Set', 'Ngorongoro Crater',
        'Denali', 'The Twelve Apostles', 'Pena Palace', 'Batu Caves', 'Hoi An Old Town',
        'Geirangerfjord', 'Sigiriya', 'Shwedagon Pagoda', 'Hallstatt Village', 'Cu Chi Tunnels',
        'Ayutthaya Historical Park', 'Jemaa el-Fnaa', 'Gamla Stan', 'Hohensalzburg Fortress', 'Wadi Rum',
        'Cité de Carcassonne', 'Avenue of the Baobabs', 'Rhodes Old Town', 'Glacier National Park', 'Waitomo Glowworm Caves',
        'Tikal', 'Jiuzhaigou Valley', 'Bagan Archaeological Zone', 'Thingvellir National Park', 'Santa Claus Village',
        'Seongsan Ilchulbong', 'Naqsh-e Jahan Square', 'Mount Roraima', 'Bryggen', 'Warsaw Old Town',
        'Vatnajökull Ice Caves', 'Mount Cook', 'Kinderdijk', 'Recoleta Cemetery', 'Lençóis Maranhenses',
        'Notre Dame Cathedral of Saigon', 'Hampi Group of Monuments', 'Bulguksa Temple', 'Mount Athos', 'Jökulsárlón Glacier Lagoon',
        'Baalbek', 'Fraser Island', 'Mount Rainier', 'Gergeti Trinity Church', 'Temple of Garni',
        'Tiananmen Square', 'Uffizi Gallery', 'Musée d\'Orsay', 'Prado Museum', 'Lake Baikal',
        'Hungarian Parliament Building', 'Prague Astronomical Clock', 'Topkapi Palace', 'Royal Palace of Madrid', 'Casa Milà',
        'Mount Etna', 'Huangshan', 'Hofburg Palace', 'Sanssouci Palace', 'Helsinki Cathedral',
        'Palace of the Parliament', 'Galata Tower', 'Peleș Castle', 'Ancient Agora of Athens', 'Lotte World Tower'
      },
    ),
    Achievement(
      id: 'cultural_heritage',
      name: 'Cultural Heritage',
      description: 'Visit 10 UNESCO Cultural Heritage Sites.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/cultural_heritage.png',
      category: AchievementCategory.Landmarks,
      requiresUnescoCount: 10,
      requiresCulturalUnescoSite: true,
    ),
    Achievement(
      id: 'natural_heritage',
      name: 'Natural Heritage',
      description: 'Visit 10 UNESCO Natural or Mixed Heritage Sites.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/natural_heritage.png',
      category: AchievementCategory.Landmarks,
      requiresUnescoCount: 10,
      requiresNaturalUnescoSite: true,
    ),
    Achievement(
      id: 'unesco_100',
      name: '100 UNESCO',
      description: 'Visit 100 UNESCO World Heritage Sites.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/unesco_100.png',
      category: AchievementCategory.Landmarks,
      targetCount: 100,
    ),
    Achievement(
      id: 'first_cultural_landmark',
      name: 'First Cultural',
      description: 'Visit your first cultural landmark.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/first_cultural.png',
      category: AchievementCategory.Landmarks,
      requiresCulturalLandmark: true,
    ),
    Achievement(
      id: 'first_natural_landmark',
      name: 'First Natural',
      description: 'Visit your first natural landmark.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/first_natural.png',
      category: AchievementCategory.Landmarks,
      requiresNaturalLandmark: true,
    ),
    Achievement(
      id: 'landmark_rating',
      name: 'Landmark Reviewer',
      description: 'Rate at least one landmark.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/landmark_rating.png',
      category: AchievementCategory.Landmarks,
      requiresRating: true,
    ),
    Achievement(
      id: 'museums_10',
      name: 'Museums',
      description: 'Visit 10 different museums.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/museums_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'castles_10',
      name: 'Castles',
      description: 'Visit 10 different castles.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/castles_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'palaces_10',
      name: 'Palaces',
      description: 'Visit 10 different palaces.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/palaces_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'arches_10',
      name: 'Arches',
      description: 'Visit 10 different arches and gates.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/arches_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'christian_10',
      name: 'Christian',
      description: 'Visit 10 different Christian sites.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/christian_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'islamic_10',
      name: 'Islamic',
      description: 'Visit 10 different Islamic sites.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/islamic_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'buddhist_10',
      name: 'Buddhist',
      description: 'Visit 10 different Buddhist sites.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/buddhist_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'hindu_10',
      name: 'Hindu',
      description: 'Visit 10 different Hindu sites.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/badges/hindu_10.png',
      category: AchievementCategory.Landmarks,
      targetCount: 10,
    ),
    Achievement(
      id: 'ivy_league',
      name: 'Ivy League',
      description: 'Visit all 8 Ivy League universities.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/ivy_league.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Brown University', 'Columbia University', 'Cornell University',
        'Dartmouth College', 'Harvard University', 'University of Pennsylvania',
        'Princeton University', 'Yale University'
      },
    ),
    Achievement(
      id: 'universal_studios',
      name: 'Universal Studios',
      description: 'Visit all 5 Universal Studios theme parks.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/universal_studios.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Universal Studios Hollywood', 'Universal Studios Japan',
        'Universal Studios Beijing', 'Universal Studios Florida',
        'Universal Studios Singapore'
      },
    ),
    Achievement(
      id: 'disney_parks',
      name: 'Disney Parks',
      description: 'Visit all 5 Disney theme park resorts.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/disney_parks.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Disneyland Paris', 'Shanghai Disneyland', 'Hong Kong Disneyland',
        'Tokyo Disneyland', 'Walt Disney World Resort'
      },
    ),
    Achievement(
      id: 'starbucks_reserve',
      name: 'Starbucks Reserve',
      description: 'Visit all 6 Starbucks Reserve Roasteries.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/starbucks_reserve.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Starbucks Reserve Roastery Seattle', 'Starbucks Reserve Roastery Shanghai',
        'Starbucks Reserve Roastery Milan', 'Starbucks Reserve Roastery New York',
        'Starbucks Reserve Roastery Tokyo', 'Starbucks Reserve Roastery Chicago'
      },
    ),
    Achievement(
      id: 'epl_big_6',
      name: 'EPL Big 6',
      description: 'Visit all 6 EPL Big 6 stadiums.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/epl_big_6.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Old Trafford', 'Anfield', 'Etihad Stadium',
        'Emirates Stadium', 'Tottenham Hotspur Stadium', 'Stamford Bridge'
      },
    ),
    Achievement(
      id: 'el_clasico',
      name: 'El Clásico',
      description: 'Visit both El Clásico stadiums.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/el_clasico.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Camp Nou', 'Santiago Bernabeu'},
    ),
    Achievement(
      id: 'best_of_paris',
      name: 'Paris',
      description: 'Visit all major Paris landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_paris.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Eiffel Tower', 'Louvre Museum', 'Notre-Dame de Paris',
        'Arc de Triomphe', 'Sacré-Cœur Basilica', 'Musée d\'Orsay', 'Centre Pompidou'
      },
    ),
    Achievement(
      id: 'best_of_london',
      name: 'London',
      description: 'Visit all major London landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_london.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Big Ben', 'Tower of London', 'British Museum', 'Buckingham Palace',
        'Westminster Abbey', 'St Paul\'s Cathedral', 'Tower Bridge'
      },
    ),
    Achievement(
      id: 'best_of_tokyo',
      name: 'Tokyo',
      description: 'Visit all major Tokyo landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_tokyo.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Senso-ji', 'Tokyo Skytree', 'Tokyo Tower', 'Meiji Jingu',
        'Imperial Palace', 'Shibuya Crossing', 'Akihabara'
      },
    ),
    Achievement(
      id: 'best_of_nyc',
      name: 'New York City',
      description: 'Visit all major NYC landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_nyc.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Statue of Liberty', 'Empire State Building', 'Central Park',
        'Times Square', 'The Museum of Modern Art', 'Broadway Theater District', 'Brooklyn Bridge'
      },
    ),
    Achievement(
      id: 'best_of_berlin',
      name: 'Berlin',
      description: 'Visit all major Berlin landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_berlin.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Brandenburg Gate', 'Reichstag Building', 'Berlin Wall Memorial',
        'Checkpoint Charlie', 'Pergamon Museum', 'Sanssouci Palace', 'Berlin Cathedral'
      },
    ),
    Achievement(
      id: 'best_of_moscow',
      name: 'Moscow',
      description: 'Visit all major Moscow landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_moscow.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Red Square', 'Moscow Kremlin', 'St. Basil\'s Cathedral',
        'Lenin\'s Mausoleum', 'Tretyakov Gallery', 'GUM', 'Moscow Metro Stations'
      },
    ),
    Achievement(
      id: 'best_of_beijing',
      name: 'Beijing',
      description: 'Visit all major Beijing landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_beijing.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Forbidden City', 'Great Wall of China', 'Summer Palace',
        'Temple of Heaven', 'Tiananmen Square', 'Bird\'s Nest', 'Lama Temple'
      },
    ),
    Achievement(
      id: 'best_of_singapore',
      name: 'Singapore',
      description: 'Visit all major Singapore landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_singapore.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Marina Bay Sands', 'Gardens by the Bay', 'Merlion Park',
        'Singapore Botanic Gardens', 'Jewel Changi Airport', 'Chinatown Heritage District', 'Buddha Tooth Relic Temple'
      },
    ),
    Achievement(
      id: 'best_of_istanbul',
      name: 'Istanbul',
      description: 'Visit all major Istanbul landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_istanbul.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Hagia Sophia', 'Topkapi Palace', 'Blue Mosque',
        'Basilica Cistern', 'Galata Tower', 'Grand Bazaar', 'Dolmabahce Palace'
      },
    ),
    Achievement(
      id: 'best_of_kyoto',
      name: 'Kyoto',
      description: 'Visit all major Kyoto landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_kyoto.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Kinkaku-ji', 'Kiyomizu-dera', 'Fushimi Inari Taisha',
        'Arashiyama Bamboo Grove', 'Gion District', 'Ginkaku-ji', 'Nijo Castle'
      },
    ),
    Achievement(
      id: 'best_of_mexico_city',
      name: 'Mexico City',
      description: 'Visit all major Mexico City landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_mexico_city.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Zocalo', 'Metropolitan Cathedral of Mexico City', 'National Museum of Anthropology',
        'Frida Kahlo Museum', 'Chapultepec Castle', 'Basilica of Our Lady of Guadalupe', 'Angel of Independence'
      },
    ),
    Achievement(
      id: 'best_of_seoul',
      name: 'Seoul',
      description: 'Visit all major Seoul landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_seoul.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Gyeongbokgung Palace', 'N Seoul Tower', 'Lotte World Tower',
        'Bukchon Hanok Village', 'Myeongdong Cathedral', 'Dongdaemun Design Plaza', 'Gwanghwamun Square'
      },
    ),
    Achievement(
      id: 'best_of_hong_kong',
      name: 'Hong Kong',
      description: 'Visit all major Hong Kong landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_hong_kong.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Victoria Peak', 'Victoria Harbour', 'Tian Tan Buddha',
        'Avenue of Stars', 'Wong Tai Sin Temple', 'Star Ferry', 'Bank of China Tower'
      },
    ),
    Achievement(
      id: 'best_of_buenos_aires',
      name: 'Buenos Aires',
      description: 'Visit all major Buenos Aires landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_buenos_aires.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Obelisco de Buenos Aires', 'Teatro Colon', 'Casa Rosada',
        'Recoleta Cemetery', 'Caminito', 'Plaza de Mayo', 'La Bombonera'
      },
    ),
    Achievement(
      id: 'best_of_rio',
      name: 'Rio de Janeiro',
      description: 'Visit all major Rio de Janeiro landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_rio.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Christ the Redeemer', 'Sugarloaf Mountain Cable Car', 'Copacabana Beach',
        'Ipanema Beach', 'Maracanã', 'Metropolitan Cathedral of Saint Sebastian', 'Escadaria Selarón'
      },
    ),
    Achievement(
      id: 'best_of_vienna',
      name: 'Vienna',
      description: 'Visit all major Vienna landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_vienna.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Schönbrunn Palace', 'Hofburg Palace', 'St Stephen\'s Cathedral',
        'Belvedere Palace', 'Vienna State Opera', 'Albertina', 'Mozarthaus Vienna'
      },
    ),
    Achievement(
      id: 'best_of_dublin',
      name: 'Dublin',
      description: 'Visit all major Dublin landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_dublin.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Guinness Storehouse', 'Trinity College Library', 'Temple Bar',
        'Dublin Castle', 'St Patrick\'s Cathedral', 'Kilmainham Gaol', 'Trinity College Dublin'
      },
    ),
    Achievement(
      id: 'best_of_st_petersburg',
      name: 'Saint Petersburg',
      description: 'Visit all major Saint Petersburg landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_st_petersburg.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Hermitage Museum', 'Church of the Savior on Spilled Blood', 'Peterhof Palace',
        'St. Isaac\'s Cathedral', 'Peter and Paul Fortress', 'Nevsky Prospect', 'Mariinsky Theatre'
      },
    ),
    Achievement(
      id: 'best_of_cape_town',
      name: 'Cape Town',
      description: 'Visit all major Cape Town landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_cape_town.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Table Mountain Aerial Cableway', 'V&A Waterfront', 'Robben Island Prison',
        'Boulders Beach', 'Kirstenbosch National Botanical Garden', 'Bo-Kaap', 'Castle of Good Hope'
      },
    ),
    Achievement(
      id: 'best_of_rome',
      name: 'Rome',
      description: 'Visit all major Rome landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_rome.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Colosseum', 'St. Peter\'s Basilica', 'Trevi Fountain',
        'Pantheon', 'Roman Forum', 'Spanish Steps', 'Piazza Navona'
      },
    ),
    Achievement(
      id: 'best_of_bangkok',
      name: 'Bangkok',
      description: 'Visit all major Bangkok landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_bangkok.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'The Grand Palace', 'Wat Arun', 'Wat Pho',
        'Wat Phra Kaew', 'Damnoen Saduak Floating Market', 'Chatuchak Weekend Market', 'Lumpini Park'
      },
    ),
    Achievement(
      id: 'best_of_barcelona',
      name: 'Barcelona',
      description: 'Visit all major Barcelona landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_barcelona.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Sagrada Familia', 'Park Güell', 'La Rambla',
        'Casa Batlló', 'Gothic Quarter', 'Casa Milà', 'Magic Fountain of Montjuïc'
      },
    ),
    Achievement(
      id: 'best_of_dubai',
      name: 'Dubai',
      description: 'Visit all major Dubai landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_dubai.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Burj Khalifa', 'Dubai Mall', 'Palm Jumeirah',
        'Dubai Fountain', 'Burj Al Arab', 'Museum of the Future', 'The Dubai Frame'
      },
    ),
    Achievement(
      id: 'best_of_sydney',
      name: 'Sydney',
      description: 'Visit all major Sydney landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_sydney.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Sydney Opera House', 'Sydney Harbour Bridge', 'Bondi Beach',
        'Darling Harbour', 'The Rocks', 'Taronga Zoo Sydney', 'Royal Botanic Garden Sydney'
      },
    ),
    Achievement(
      id: 'best_of_los_angeles',
      name: 'Los Angeles',
      description: 'Visit all major Los Angeles landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_los_angeles.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Universal Studios Hollywood', 'Hollywood Sign', 'Griffith Observatory',
        'Santa Monica Pier', 'Hollywood Walk of Fame', 'The Getty Center', 'Venice Beach'
      },
    ),
    Achievement(
      id: 'best_of_shanghai',
      name: 'Shanghai',
      description: 'Visit all major Shanghai landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_shanghai.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'The Bund', 'Yu Garden', 'Oriental Pearl Tower',
        'Shanghai Tower', 'Nanjing Road', 'People\'s Square', 'Shanghai Museum'
      },
    ),
    Achievement(
      id: 'best_of_cairo',
      name: 'Cairo',
      description: 'Visit all major Cairo landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_cairo.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Pyramids of Giza', 'Great Sphinx of Giza','Cairo Citadel', 'Mosque of Muhammad Ali', 'Egyptian Museum',
        'Khan el-Khalili', 'Tahrir Square'
      },
    ),
    Achievement(
      id: 'best_of_amsterdam',
      name: 'Amsterdam',
      description: 'Visit all major Amsterdam landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_amsterdam.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Anne Frank House', 'Van Gogh Museum', 'Rijksmuseum',
        'Canal Ring', 'Red Light District', 'Dam Square', 'Vondelpark'
      },
    ),
    Achievement(
      id: 'best_of_prague',
      name: 'Prague',
      description: 'Visit all major Prague landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_prague.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Charles Bridge', 'Prague Castle', 'Old Town Square',
        'St. Vitus Cathedral', 'Jewish Quarter', 'Wenceslas Square', 'Petřín Lookout Tower'
      },
    ),
    Achievement(
      id: 'best_of_madrid',
      name: 'Madrid',
      description: 'Visit all major Madrid landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_madrid.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Prado Museum', 'Royal Palace of Madrid', 'Plaza Mayor',
        'Retiro Park', 'Puerta del Sol', 'Gran Vía', 'Puerta de Alcalá'
      },
    ),
    Achievement(
      id: 'best_of_taipei',
      name: 'Taipei',
      description: 'Visit all major Taipei landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_taipei.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Taipei 101', 'National Palace Museum', 'Chiang Kai-shek Memorial Hall',
        'Shilin Night Market', 'Longshan Temple', 'Ximending', 'Dihua Street'
      },
    ),
    Achievement(
      id: 'best_of_budapest',
      name: 'Budapest',
      description: 'Visit all major Budapest landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_budapest.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Hungarian Parliament Building', 'Buda Castle', 'Fisherman\'s Bastion',
        'Széchenyi Chain Bridge', 'St. Stephen\'s Basilica', 'Heroes\' Square', 'Széchenyi Thermal Baths'
      },
    ),
    Achievement(
      id: 'best_of_lisbon',
      name: 'Lisbon',
      description: 'Visit all major Lisbon landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_lisbon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Belém Tower', 'Jerónimos Monastery', 'São Jorge Castle',
        'Praça do Comércio', 'Alfama District', 'Padrão dos Descobrimentos', 'Santa Justa Lift'
      },
    ),
    Achievement(
      id: 'best_of_athens',
      name: 'Athens',
      description: 'Visit all major Athens landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_athens.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Parthenon', 'Acropolis Museum', 'Plaka',
        'Ancient Agora of Athens', 'Temple of Olympian Zeus', 'Syntagma Square', 'Panathenaic Stadium'
      },
    ),
    Achievement(
      id: 'best_of_munich',
      name: 'Munich',
      description: 'Visit all major Munich landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_munich.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Marienplatz', 'English Garden', 'BMW Welt & Museum',
        'Nymphenburg Palace', 'Munich Residenz', 'Deutsches Museum', 'Allianz Arena'
      },
    ),
    Achievement(
      id: 'best_of_toronto',
      name: 'Toronto',
      description: 'Visit all major Toronto landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_toronto.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'CN Tower', 'Royal Ontario Museum', 'Distillery District',
        'Ripley\'s Aquarium of Canada', 'St. Lawrence Market', 'Art Gallery of Ontario', 'Casa Loma'
      },
    ),
    Achievement(
      id: 'best_of_kuala_lumpur',
      name: 'Kuala Lumpur',
      description: 'Visit all major Kuala Lumpur landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_kuala_lumpur.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Petronas Towers', 'Batu Caves', 'Merdeka Square',
        'Bukit Bintang', 'KL Tower', 'Thean Hou Temple', 'Islamic Arts Museum Malaysia'
      },
    ),
    Achievement(
      id: 'best_of_copenhagen',
      name: 'Copenhagen',
      description: 'Visit all major Copenhagen landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_copenhagen.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Nyhavn', 'Tivoli Gardens', 'The Little Mermaid',
        'Amalienborg', 'Rosenborg Castle', 'Christiansborg Palace', 'The Round Tower'
      },
    ),
    Achievement(
      id: 'best_of_stockholm',
      name: 'Stockholm',
      description: 'Visit all major Stockholm landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_stockholm.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Vasa Museum', 'Gamla Stan', 'Stockholm Palace',
        'Stockholm City Hall', 'Skansen', 'ABBA The Museum', 'Drottningholm Palace'
      },
    ),
    Achievement(
      id: 'best_of_chicago',
      name: 'Chicago',
      description: 'Visit all major Chicago landmarks.',
      difficulty: AchievementDifficulty.Explorer,
      points: 7,
      imagePath: 'assets/badges/best_of_chicago.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {
        'Cloud Gate', 'Art Institute of Chicago', 'Willis Tower',
        'Magnificent Mile', 'Navy Pier', 'Chicago Architecture Tour', 'Field Museum of Natural History'
      },
    ),
    Achievement(
      id: 'airport_rating',
      name: 'Airport Reviewer',
      description: 'Rate at least one airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/airport_rating.png',
      category: AchievementCategory.Flight,
      requiresAirportRating: true,
    ),
    Achievement(
      id: 'airport_hub',
      name: 'Hub Airport',
      description: 'Set at least one airport as My Hub.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/airport_hub.png',
      category: AchievementCategory.Flight,
      requiresAirportHub: true,
    ),
    Achievement(
      id: 'airline_rating',
      name: 'Airline Reviewer',
      description: 'Rate at least one airline.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badges/airline_rating.png',
      category: AchievementCategory.Flight,
      requiresAirlineRating: true,
    ),
    Achievement(
      id: 'business_class',
      name: 'Business Class',
      description: 'Take at least one Business class flight.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/business_class.png',
      category: AchievementCategory.Flight,
      requiresBusinessClass: true,
    ),
    Achievement(
      id: 'first_class',
      name: 'First Class',
      description: 'Take at least one First class flight.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 20,
      imagePath: 'assets/badges/first_class.png',
      category: AchievementCategory.Flight,
      requiresFirstClass: true,
    ),
    Achievement(
      id: 'flights_10',
      name: '10 Flights',
      description: 'Take 10 flights.',
      difficulty: AchievementDifficulty.Rookie,
      points: 3,
      imagePath: 'assets/badges/flights_10.png',
      category: AchievementCategory.Flight,
      targetCount: 10,
    ),
    Achievement(
      id: 'flights_50',
      name: '50 Flights',
      description: 'Take 50 flights.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/flights_50.png',
      category: AchievementCategory.Flight,
      targetCount: 50,
    ),
    Achievement(
      id: 'flights_100',
      name: '100 Flights',
      description: 'Take 100 flights.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/flights_100.png',
      category: AchievementCategory.Flight,
      targetCount: 100,
    ),
    Achievement(
      id: 'flights_300',
      name: '300 Flights',
      description: 'Take 300 flights.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 30,
      imagePath: 'assets/badges/flights_300.png',
      category: AchievementCategory.Flight,
      targetCount: 300,
    ),
    Achievement(
      id: 'airlines_10',
      name: '10 Airlines',
      description: 'Fly with 10 different airlines.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/airlines_10.png',
      category: AchievementCategory.Flight,
      targetCount: 10,
    ),
    Achievement(
      id: 'airlines_30',
      name: '30 Airlines',
      description: 'Fly with 30 different airlines.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/airlines_30.png',
      category: AchievementCategory.Flight,
      targetCount: 30,
    ),
    Achievement(
      id: 'airlines_50',
      name: '50 Airlines',
      description: 'Fly with 50 different airlines.',
      difficulty: AchievementDifficulty.Globetrotter,
      points: 20,
      imagePath: 'assets/badges/airlines_50.png',
      category: AchievementCategory.Flight,
      targetCount: 50,
    ),
    Achievement(
      id: 'airports_10',
      name: '10 Airports',
      description: 'Visit 10 different airports.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/badges/airports_10.png',
      category: AchievementCategory.Flight,
      targetCount: 10,
    ),
    Achievement(
      id: 'airports_50',
      name: '50 Airports',
      description: 'Visit 50 different airports.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/airports_50.png',
      category: AchievementCategory.Flight,
      targetCount: 50,
    ),
    Achievement(
      id: 'airports_100',
      name: '100 Airports',
      description: 'Visit 100 different airports.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/airports_100.png',
      category: AchievementCategory.Flight,
      targetCount: 100,
    ),
    Achievement(
      id: 'top10_airports',
      name: 'Top 10 Airports',
      description: 'Visit all top 10 airports in the world.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/top10_airports.png',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'SIN', 'DOH', 'HND', 'ICN', 'NRT', 'HKG', 'CDG', 'FCO', 'MUC', 'ZRH'},
    ),
    Achievement(
      id: 'top10_airlines',
      name: 'Top 10 Airlines',
      description: 'Fly with all top 10 airlines in the world.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/top10_airlines.png',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'QR', 'SQ', 'EK', 'NH', 'QF', 'JL', 'TK', 'AF', 'KE', 'LX'},
    ),
    Achievement(
      id: 'skyteam_20',
      name: 'SkyTeam',
      description: 'Fly with all SkyTeam airlines.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 30,
      imagePath: 'assets/badges/skyteam_20.png',
      category: AchievementCategory.Flight,
    ),
    Achievement(
      id: 'oneworld_20',
      name: 'Oneworld',
      description: 'Fly with all Oneworld airlines.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 30,
      imagePath: 'assets/badges/oneworld_20.png',
      category: AchievementCategory.Flight,
    ),
    Achievement(
      id: 'staralliance_20',
      name: 'Star Alliance',
      description: 'Fly with all Star Alliance airlines.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 30,
      imagePath: 'assets/badges/staralliance_20.png',
      category: AchievementCategory.Flight,
    ),
    // ─── Top 250 Landmarks (individual badges, 1pt each) ───────────────
    Achievement(
      id: 'landmark_eiffel_tower',
      requiresSubscription: true,
      name: 'Eiffel Tower',
      description: 'Visit Eiffel Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_eiffel_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Eiffel Tower'},
    ),
    Achievement(
      id: 'landmark_great_wall_of_china',
      requiresSubscription: true,
      name: 'Great Wall of China',
      description: 'Visit Great Wall of China.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_great_wall_of_china.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Great Wall of China'},
    ),
    Achievement(
      id: 'landmark_pyramids_of_giza',
      requiresSubscription: true,
      name: 'Pyramids of Giza',
      description: 'Visit Pyramids of Giza.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pyramids_of_giza.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pyramids of Giza'},
    ),
    Achievement(
      id: 'landmark_statue_of_liberty',
      requiresSubscription: true,
      name: 'Statue of Liberty',
      description: 'Visit Statue of Liberty.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_statue_of_liberty.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Statue of Liberty'},
    ),
    Achievement(
      id: 'landmark_taj_mahal',
      requiresSubscription: true,
      name: 'Taj Mahal',
      description: 'Visit Taj Mahal.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_taj_mahal.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Taj Mahal'},
    ),
    Achievement(
      id: 'landmark_colosseum',
      requiresSubscription: true,
      name: 'Colosseum',
      description: 'Visit Colosseum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_colosseum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Colosseum'},
    ),
    Achievement(
      id: 'landmark_machu_picchu',
      requiresSubscription: true,
      name: 'Machu Picchu',
      description: 'Visit Machu Picchu.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_machu_picchu.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Machu Picchu'},
    ),
    Achievement(
      id: 'landmark_parthenon',
      requiresSubscription: true,
      name: 'Parthenon',
      description: 'Visit Parthenon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_parthenon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Parthenon'},
    ),
    Achievement(
      id: 'landmark_sydney_opera_house',
      requiresSubscription: true,
      name: 'Sydney Opera House',
      description: 'Visit Sydney Opera House.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sydney_opera_house.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sydney Opera House'},
    ),
    Achievement(
      id: 'landmark_big_ben',
      requiresSubscription: true,
      name: 'Big Ben',
      description: 'Visit Big Ben.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_big_ben.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Big Ben'},
    ),
    Achievement(
      id: 'landmark_st_peter_s_basilica',
      requiresSubscription: true,
      name: 'St. Peter\'s Basilica',
      description: 'Visit St. Peter\'s Basilica.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_st_peter_s_basilica.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'St. Peter\'s Basilica'},
    ),
    Achievement(
      id: 'landmark_great_sphinx_of_giza',
      requiresSubscription: true,
      name: 'Great Sphinx of Giza',
      description: 'Visit Great Sphinx of Giza.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_great_sphinx_of_giza.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Great Sphinx of Giza'},
    ),
    Achievement(
      id: 'landmark_petra',
      requiresSubscription: true,
      name: 'Petra',
      description: 'Visit Petra.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_petra.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Petra'},
    ),
    Achievement(
      id: 'landmark_angkor_wat',
      requiresSubscription: true,
      name: 'Angkor Wat',
      description: 'Visit Angkor Wat.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_angkor_wat.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Angkor Wat'},
    ),
    Achievement(
      id: 'landmark_christ_the_redeemer',
      requiresSubscription: true,
      name: 'Christ the Redeemer',
      description: 'Visit Christ the Redeemer.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_christ_the_redeemer.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Christ the Redeemer'},
    ),
    Achievement(
      id: 'landmark_stonehenge',
      requiresSubscription: true,
      name: 'Stonehenge',
      description: 'Visit Stonehenge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_stonehenge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Stonehenge'},
    ),
    Achievement(
      id: 'landmark_leaning_tower_of_pisa',
      requiresSubscription: true,
      name: 'Tower of Pisa',
      description: 'Visit Leaning Tower of Pisa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_leaning_tower_of_pisa.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Leaning Tower of Pisa'},
    ),
    Achievement(
      id: 'landmark_burj_khalifa',
      requiresSubscription: true,
      name: 'Burj Khalifa',
      description: 'Visit Burj Khalifa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_burj_khalifa.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Burj Khalifa'},
    ),
    Achievement(
      id: 'landmark_niagara_falls',
      requiresSubscription: true,
      name: 'Niagara Falls',
      description: 'Visit Niagara Falls.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_niagara_falls.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Niagara Falls'},
    ),
    Achievement(
      id: 'landmark_notre_dame_de_paris',
      requiresSubscription: true,
      name: 'Notre-Dame de Paris',
      description: 'Visit Notre-Dame de Paris.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_notre_dame_de_paris.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Notre-Dame de Paris'},
    ),
    Achievement(
      id: 'landmark_st_basil_s_cathedral',
      requiresSubscription: true,
      name: 'St. Basil\'s Cathedral',
      description: 'Visit St. Basil\'s Cathedral.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_st_basil_s_cathedral.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'St. Basil\'s Cathedral'},
    ),
    Achievement(
      id: 'landmark_empire_state_building',
      requiresSubscription: true,
      name: 'Empire State',
      description: 'Visit Empire State Building.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_empire_state_building.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Empire State Building'},
    ),
    Achievement(
      id: 'landmark_forbidden_city',
      requiresSubscription: true,
      name: 'Forbidden City',
      description: 'Visit Forbidden City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_forbidden_city.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Forbidden City'},
    ),
    Achievement(
      id: 'landmark_times_square',
      requiresSubscription: true,
      name: 'Times Square',
      description: 'Visit Times Square.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_times_square.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Times Square'},
    ),
    Achievement(
      id: 'landmark_sagrada_familia',
      requiresSubscription: true,
      name: 'Sagrada Familia',
      description: 'Visit Sagrada Familia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sagrada_familia.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sagrada Familia'},
    ),
    Achievement(
      id: 'landmark_grand_canyon',
      requiresSubscription: true,
      name: 'Grand Canyon',
      description: 'Visit Grand Canyon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_grand_canyon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Grand Canyon'},
    ),
    Achievement(
      id: 'landmark_louvre_museum',
      requiresSubscription: true,
      name: 'Louvre Museum',
      description: 'Visit Louvre Museum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_louvre_museum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Louvre Museum'},
    ),
    Achievement(
      id: 'landmark_mount_everest',
      requiresSubscription: true,
      name: 'Mount Everest',
      description: 'Visit Mount Everest.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_everest.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Everest'},
    ),
    Achievement(
      id: 'landmark_great_barrier_reef',
      requiresSubscription: true,
      name: 'Great Barrier Reef',
      description: 'Visit Great Barrier Reef.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_great_barrier_reef.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Great Barrier Reef'},
    ),
    Achievement(
      id: 'landmark_amazon_rainforest',
      requiresSubscription: true,
      name: 'Amazon Rainforest',
      description: 'Visit Amazon Rainforest.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_amazon_rainforest.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Amazon Rainforest'},
    ),
    Achievement(
      id: 'landmark_buckingham_palace',
      name: 'Buckingham Palace',
      description: 'Visit Buckingham Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_buckingham_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Buckingham Palace'},
    ),
    Achievement(
      id: 'landmark_yellowstone_national_park',
      name: 'Yellowstone',
      description: 'Visit Yellowstone National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_yellowstone_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Yellowstone National Park'},
    ),
    Achievement(
      id: 'landmark_palace_of_versailles',
      name: 'Palace of Versailles',
      description: 'Visit Palace of Versailles.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_palace_of_versailles.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Palace of Versailles'},
    ),
    Achievement(
      id: 'landmark_central_park',
      name: 'Central Park',
      description: 'Visit Central Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_central_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Central Park'},
    ),
    Achievement(
      id: 'landmark_golden_gate_bridge',
      name: 'Golden Gate Bridge',
      description: 'Visit Golden Gate Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_golden_gate_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Golden Gate Bridge'},
    ),
    Achievement(
      id: 'landmark_mount_fuji',
      name: 'Mount Fuji',
      description: 'Visit Mount Fuji.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_fuji.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Fuji'},
    ),
    Achievement(
      id: 'landmark_terracotta_army',
      name: 'Terracotta Army',
      description: 'Visit Terracotta Army.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_terracotta_army.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Terracotta Army'},
    ),
    Achievement(
      id: 'landmark_chichen_itza',
      name: 'Chichen Itza',
      description: 'Visit Chichen Itza.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_chichen_itza.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Chichen Itza'},
    ),
    Achievement(
      id: 'landmark_tower_bridge',
      name: 'Tower Bridge',
      description: 'Visit Tower Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tower_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tower Bridge'},
    ),
    Achievement(
      id: 'landmark_hollywood_sign',
      name: 'Hollywood Sign',
      description: 'Visit Hollywood Sign.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hollywood_sign.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hollywood Sign'},
    ),
    Achievement(
      id: 'landmark_moscow_kremlin',
      name: 'Moscow Kremlin',
      description: 'Visit Moscow Kremlin.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_moscow_kremlin.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Moscow Kremlin'},
    ),
    Achievement(
      id: 'landmark_sahara_desert',
      name: 'Sahara Desert',
      description: 'Visit Sahara Desert.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sahara_desert.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sahara Desert'},
    ),
    Achievement(
      id: 'landmark_trevi_fountain',
      name: 'Trevi Fountain',
      description: 'Visit Trevi Fountain.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_trevi_fountain.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Trevi Fountain'},
    ),
    Achievement(
      id: 'landmark_the_white_house',
      name: 'The White House',
      description: 'Visit The White House.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_the_white_house.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'The White House'},
    ),
    Achievement(
      id: 'landmark_arc_de_triomphe',
      name: 'Arc de Triomphe',
      description: 'Visit Arc de Triomphe.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_arc_de_triomphe.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Arc de Triomphe'},
    ),
    Achievement(
      id: 'landmark_auschwitz_birkenau_memorial_and_museum',
      name: 'Auschwitz-Birkenau',
      description: 'Visit Auschwitz-Birkenau Memorial and Museum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_auschwitz_birkenau_memorial_and_museum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Auschwitz-Birkenau Memorial and Museum'},
    ),
    Achievement(
      id: 'landmark_yosemite_national_park',
      name: 'Yosemite',
      description: 'Visit Yosemite National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_yosemite_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Yosemite National Park'},
    ),
    Achievement(
      id: 'landmark_iguazu_falls',
      name: 'Iguazu Falls',
      description: 'Visit Iguazu Falls.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_iguazu_falls.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Iguazu Falls'},
    ),
    Achievement(
      id: 'landmark_neuschwanstein_castle',
      name: 'Neuschwanstein',
      description: 'Visit Neuschwanstein Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_neuschwanstein_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Neuschwanstein Castle'},
    ),
    Achievement(
      id: 'landmark_galapagos_islands',
      name: 'Galapagos Islands',
      description: 'Visit Galapagos Islands.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_galapagos_islands.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Galapagos Islands'},
    ),
    Achievement(
      id: 'landmark_hagia_sophia',
      name: 'Hagia Sophia',
      description: 'Visit Hagia Sophia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hagia_sophia.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hagia Sophia'},
    ),
    Achievement(
      id: 'landmark_victoria_falls',
      name: 'Victoria Falls',
      description: 'Visit Victoria Falls.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_victoria_falls.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Victoria Falls'},
    ),
    Achievement(
      id: 'landmark_mount_rushmore',
      name: 'Mount Rushmore',
      description: 'Visit Mount Rushmore.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_rushmore.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Rushmore'},
    ),
    Achievement(
      id: 'landmark_easter_island',
      name: 'Easter Island',
      description: 'Visit Easter Island.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_easter_island.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Easter Island'},
    ),
    Achievement(
      id: 'landmark_pompeii',
      name: 'Pompeii',
      description: 'Visit Pompeii.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pompeii.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pompeii'},
    ),
    Achievement(
      id: 'landmark_sydney_harbour_bridge',
      name: 'Sydney Harbour',
      description: 'Visit Sydney Harbour Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sydney_harbour_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sydney Harbour Bridge'},
    ),
    Achievement(
      id: 'landmark_british_museum',
      name: 'British Museum',
      description: 'Visit British Museum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_british_museum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'British Museum'},
    ),
    Achievement(
      id: 'landmark_tower_of_london',
      name: 'Tower of London',
      description: 'Visit Tower of London.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tower_of_london.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tower of London'},
    ),
    Achievement(
      id: 'landmark_united_states_capitol',
      name: 'US Capitol',
      description: 'Visit United States Capitol.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_united_states_capitol.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'United States Capitol'},
    ),
    Achievement(
      id: 'landmark_brandenburg_gate',
      name: 'Brandenburg Gate',
      description: 'Visit Brandenburg Gate.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_brandenburg_gate.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Brandenburg Gate'},
    ),
    Achievement(
      id: 'landmark_brooklyn_bridge',
      name: 'Brooklyn Bridge',
      description: 'Visit Brooklyn Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_brooklyn_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Brooklyn Bridge'},
    ),
    Achievement(
      id: 'landmark_mont_saint_michel',
      name: 'Mont-Saint-Michel',
      description: 'Visit Mont-Saint-Michel.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mont_saint_michel.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mont-Saint-Michel'},
    ),
    Achievement(
      id: 'landmark_pantheon',
      name: 'Pantheon',
      description: 'Visit Pantheon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pantheon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pantheon'},
    ),
    Achievement(
      id: 'landmark_metropolitan_museum_of_art',
      name: 'The Met',
      description: 'Visit Metropolitan Museum of Art.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_metropolitan_museum_of_art.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Metropolitan Museum of Art'},
    ),
    Achievement(
      id: 'landmark_mount_kilimanjaro',
      name: 'Mount Kilimanjaro',
      description: 'Visit Mount Kilimanjaro.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_kilimanjaro.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Kilimanjaro'},
    ),
    Achievement(
      id: 'landmark_london_eye',
      name: 'London Eye',
      description: 'Visit London Eye.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_london_eye.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'London Eye'},
    ),
    Achievement(
      id: 'landmark_alhambra',
      name: 'Alhambra',
      description: 'Visit Alhambra.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_alhambra.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Alhambra'},
    ),
    Achievement(
      id: 'landmark_dead_sea',
      name: 'Dead Sea',
      description: 'Visit Dead Sea.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_dead_sea.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Dead Sea'},
    ),
    Achievement(
      id: 'landmark_western_wall',
      name: 'Western Wall',
      description: 'Visit Western Wall.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_western_wall.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Western Wall'},
    ),
    Achievement(
      id: 'landmark_westminster_abbey',
      name: 'Westminster Abbey',
      description: 'Visit Westminster Abbey.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_westminster_abbey.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Westminster Abbey'},
    ),
    Achievement(
      id: 'landmark_petronas_towers',
      name: 'Petronas Towers',
      description: 'Visit Petronas Towers.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_petronas_towers.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Petronas Towers'},
    ),
    Achievement(
      id: 'landmark_burj_al_arab',
      name: 'Burj Al Arab',
      description: 'Visit Burj Al Arab.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_burj_al_arab.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Burj Al Arab'},
    ),
    Achievement(
      id: 'landmark_marina_bay_sands',
      name: 'Marina Bay Sands',
      description: 'Visit Marina Bay Sands.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_marina_bay_sands.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Marina Bay Sands'},
    ),
    Achievement(
      id: 'landmark_matterhorn',
      name: 'Matterhorn',
      description: 'Visit Matterhorn.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_matterhorn.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Matterhorn'},
    ),
    Achievement(
      id: 'landmark_taipei_101',
      name: 'Taipei 101',
      description: 'Visit Taipei 101.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_taipei_101.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Taipei 101'},
    ),
    Achievement(
      id: 'landmark_dome_of_the_rock',
      name: 'Dome of the Rock',
      description: 'Visit Dome of the Rock.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_dome_of_the_rock.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Dome of the Rock'},
    ),
    Achievement(
      id: 'landmark_uluru',
      name: 'Uluru',
      description: 'Visit Uluru.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_uluru.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Uluru'},
    ),
    Achievement(
      id: 'landmark_salar_de_uyuni',
      name: 'Salar de Uyuni',
      description: 'Visit Salar de Uyuni.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_salar_de_uyuni.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Salar de Uyuni'},
    ),
    Achievement(
      id: 'landmark_blue_mosque',
      name: 'Blue Mosque',
      description: 'Visit Blue Mosque.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_blue_mosque.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Blue Mosque'},
    ),
    Achievement(
      id: 'landmark_lincoln_memorial',
      name: 'Lincoln Memorial',
      description: 'Visit Lincoln Memorial.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lincoln_memorial.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lincoln Memorial'},
    ),
    Achievement(
      id: 'landmark_panama_canal',
      name: 'Panama Canal',
      description: 'Visit Panama Canal.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_panama_canal.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Panama Canal'},
    ),
    Achievement(
      id: 'landmark_duomo_di_milano',
      name: 'Duomo di Milano',
      description: 'Visit Duomo di Milano.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_duomo_di_milano.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Duomo di Milano'},
    ),
    Achievement(
      id: 'landmark_valley_of_the_kings',
      name: 'Valley of the Kings',
      description: 'Visit Valley of the Kings.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_valley_of_the_kings.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Valley of the Kings'},
    ),
    Achievement(
      id: 'landmark_ha_long_bay',
      name: 'Ha Long Bay',
      description: 'Visit Ha Long Bay.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_ha_long_bay.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Ha Long Bay'},
    ),
    Achievement(
      id: 'landmark_fushimi_inari_taisha',
      name: 'Fushimi Inari Taisha',
      description: 'Visit Fushimi Inari Taisha.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_fushimi_inari_taisha.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Fushimi Inari Taisha'},
    ),
    Achievement(
      id: 'landmark_serengeti_national_park',
      name: 'Serengeti',
      description: 'Visit Serengeti National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_serengeti_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Serengeti National Park'},
    ),
    Achievement(
      id: 'landmark_hermitage_museum',
      name: 'Hermitage Museum',
      description: 'Visit Hermitage Museum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hermitage_museum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hermitage Museum'},
    ),
    Achievement(
      id: 'landmark_shibuya_crossing',
      name: 'Shibuya Crossing',
      description: 'Visit Shibuya Crossing.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_shibuya_crossing.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Shibuya Crossing'},
    ),
    Achievement(
      id: 'landmark_pearl_harbor_national_memorial',
      name: 'Pearl Harbor',
      description: 'Visit Pearl Harbor National Memorial.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pearl_harbor_national_memorial.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pearl Harbor National Memorial'},
    ),
    Achievement(
      id: 'landmark_sacre_cur_basilica',
      name: 'Sacré-Cœur Basilica',
      description: 'Visit Sacré-Cœur Basilica.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sacre_cur_basilica.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sacré-Cœur Basilica'},
    ),
    Achievement(
      id: 'landmark_park_guell',
      name: 'Park Güell',
      description: 'Visit Park Güell.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_park_guell.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Park Güell'},
    ),
    Achievement(
      id: 'landmark_berlin_wall_memorial',
      name: 'Berlin Wall Memorial',
      description: 'Visit Berlin Wall Memorial.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_berlin_wall_memorial.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Berlin Wall Memorial'},
    ),
    Achievement(
      id: 'landmark_hiroshima_peace_memorial',
      name: 'Hiroshima Memorial',
      description: 'Visit Hiroshima Peace Memorial.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hiroshima_peace_memorial.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hiroshima Peace Memorial'},
    ),
    Achievement(
      id: 'landmark_st_mark_s_basilica',
      name: 'St. Mark\'s Basilica',
      description: 'Visit St. Mark\'s Basilica.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_st_mark_s_basilica.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'St. Mark\'s Basilica'},
    ),
    Achievement(
      id: 'landmark_dubrovnik_old_town',
      name: 'Dubrovnik Old Town',
      description: 'Visit Dubrovnik Old Town.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_dubrovnik_old_town.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Dubrovnik Old Town'},
    ),
    Achievement(
      id: 'landmark_cappadocia_fairy_chimneys',
      name: 'Cappadocia',
      description: 'Visit Cappadocia Fairy Chimneys.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cappadocia_fairy_chimneys.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cappadocia Fairy Chimneys'},
    ),
    Achievement(
      id: 'landmark_edinburgh_castle',
      name: 'Edinburgh Castle',
      description: 'Visit Edinburgh Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_edinburgh_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Edinburgh Castle'},
    ),
    Achievement(
      id: 'landmark_gyeongbokgung_palace',
      name: 'Gyeongbokgung',
      description: 'Visit Gyeongbokgung Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_gyeongbokgung_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Gyeongbokgung Palace'},
    ),
    Achievement(
      id: 'landmark_amalfi_coast',
      name: 'Amalfi Coast',
      description: 'Visit Amalfi Coast.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_amalfi_coast.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Amalfi Coast'},
    ),
    Achievement(
      id: 'landmark_kinkaku_ji',
      name: 'Kinkaku-ji',
      description: 'Visit Kinkaku-ji.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_kinkaku_ji.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Kinkaku-ji'},
    ),
    Achievement(
      id: 'landmark_sheikh_zayed_grand_mosque',
      name: 'Abu Dhabi Mosque',
      description: 'Visit Sheikh Zayed Grand Mosque.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sheikh_zayed_grand_mosque.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sheikh Zayed Grand Mosque'},
    ),
    Achievement(
      id: 'landmark_prague_castle',
      name: 'Prague Castle',
      description: 'Visit Prague Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_prague_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Prague Castle'},
    ),
    Achievement(
      id: 'landmark_teotihuacan',
      name: 'Teotihuacan',
      description: 'Visit Teotihuacan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_teotihuacan.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Teotihuacan'},
    ),
    Achievement(
      id: 'landmark_the_grand_palace',
      name: 'The Grand Palace',
      description: 'Visit The Grand Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_the_grand_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'The Grand Palace'},
    ),
    Achievement(
      id: 'landmark_cn_tower',
      name: 'CN Tower',
      description: 'Visit CN Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cn_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'CN Tower'},
    ),
    Achievement(
      id: 'landmark_monument_valley',
      name: 'Monument Valley',
      description: 'Visit Monument Valley.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_monument_valley.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Monument Valley'},
    ),
    Achievement(
      id: 'landmark_banff_national_park',
      name: 'Banff National Park',
      description: 'Visit Banff National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_banff_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Banff National Park'},
    ),
    Achievement(
      id: 'landmark_windsor_castle',
      name: 'Windsor Castle',
      description: 'Visit Windsor Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_windsor_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Windsor Castle'},
    ),
    Achievement(
      id: 'landmark_tokyo_tower',
      name: 'Tokyo Tower',
      description: 'Visit Tokyo Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tokyo_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tokyo Tower'},
    ),
    Achievement(
      id: 'landmark_gardens_by_the_bay',
      name: 'Gardens by the Bay',
      description: 'Visit Gardens by the Bay.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_gardens_by_the_bay.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Gardens by the Bay'},
    ),
    Achievement(
      id: 'landmark_schonbrunn_palace',
      name: 'Schönbrunn Palace',
      description: 'Visit Schönbrunn Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_schonbrunn_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Schönbrunn Palace'},
    ),
    Achievement(
      id: 'landmark_florence_cathedral',
      name: 'Florence Cathedral',
      description: 'Visit Florence Cathedral.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_florence_cathedral.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Florence Cathedral'},
    ),
    Achievement(
      id: 'landmark_mount_vesuvius',
      name: 'Mount Vesuvius',
      description: 'Visit Mount Vesuvius.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_vesuvius.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Vesuvius'},
    ),
    Achievement(
      id: 'landmark_hoover_dam',
      name: 'Hoover Dam',
      description: 'Visit Hoover Dam.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hoover_dam.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hoover Dam'},
    ),
    Achievement(
      id: 'landmark_antelope_canyon',
      name: 'Antelope Canyon',
      description: 'Visit Antelope Canyon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_antelope_canyon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Antelope Canyon'},
    ),
    Achievement(
      id: 'landmark_mont_blanc',
      name: 'Mont Blanc',
      description: 'Visit Mont Blanc.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mont_blanc.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mont Blanc'},
    ),
    Achievement(
      id: 'landmark_spanish_steps',
      name: 'Spanish Steps',
      description: 'Visit Spanish Steps.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_spanish_steps.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Spanish Steps'},
    ),
    Achievement(
      id: 'landmark_french_polynesia',
      name: 'French Polynesia',
      description: 'Visit French Polynesia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_french_polynesia.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'French Polynesia'},
    ),
    Achievement(
      id: 'landmark_space_needle',
      name: 'Space Needle',
      description: 'Visit Space Needle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_space_needle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Space Needle'},
    ),
    Achievement(
      id: 'landmark_blue_lagoon',
      name: 'Blue Lagoon',
      description: 'Visit Blue Lagoon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_blue_lagoon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Blue Lagoon'},
    ),
    Achievement(
      id: 'landmark_golden_temple',
      name: 'Golden Temple',
      description: 'Visit Golden Temple.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_golden_temple.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Golden Temple'},
    ),
    Achievement(
      id: 'landmark_cape_of_good_hope',
      name: 'Cape of Good Hope',
      description: 'Visit Cape of Good Hope.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cape_of_good_hope.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cape of Good Hope'},
    ),
    Achievement(
      id: 'landmark_charles_bridge',
      name: 'Charles Bridge',
      description: 'Visit Charles Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_charles_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Charles Bridge'},
    ),
    Achievement(
      id: 'landmark_cologne_cathedral',
      name: 'Cologne Cathedral',
      description: 'Visit Cologne Cathedral.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cologne_cathedral.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cologne Cathedral'},
    ),
    Achievement(
      id: 'landmark_potala_palace',
      name: 'Potala Palace',
      description: 'Visit Potala Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_potala_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Potala Palace'},
    ),
    Achievement(
      id: 'landmark_cinque_terre',
      name: 'Cinque Terre',
      description: 'Visit Cinque Terre.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cinque_terre.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cinque Terre'},
    ),
    Achievement(
      id: 'landmark_table_mountain',
      name: 'Table Mountain',
      description: 'Visit Table Mountain.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_table_mountain.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Table Mountain'},
    ),
    Achievement(
      id: 'landmark_sugarloaf_mountain',
      name: 'Sugarloaf Mountain',
      description: 'Visit Sugarloaf Mountain.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sugarloaf_mountain.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sugarloaf Mountain'},
    ),
    Achievement(
      id: 'landmark_palm_jumeirah',
      name: 'Palm Jumeirah',
      description: 'Visit Palm Jumeirah.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_palm_jumeirah.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Palm Jumeirah'},
    ),
    Achievement(
      id: 'landmark_kiyomizu_dera',
      name: 'Kiyomizu-dera',
      description: 'Visit Kiyomizu-dera.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_kiyomizu_dera.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Kiyomizu-dera'},
    ),
    Achievement(
      id: 'landmark_borobudur_temple',
      name: 'Borobudur Temple',
      description: 'Visit Borobudur Temple.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_borobudur_temple.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Borobudur Temple'},
    ),
    Achievement(
      id: 'landmark_cliffs_of_moher',
      name: 'Cliffs of Moher',
      description: 'Visit Cliffs of Moher.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cliffs_of_moher.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cliffs of Moher'},
    ),
    Achievement(
      id: 'landmark_oia',
      name: 'Oia',
      description: 'Visit Oia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_oia.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Oia'},
    ),
    Achievement(
      id: 'landmark_jungfrau',
      name: 'Jungfrau',
      description: 'Visit Jungfrau.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_jungfrau.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Jungfrau'},
    ),
    Achievement(
      id: 'landmark_itsukushima_shrine',
      name: 'Itsukushima Shrine',
      description: 'Visit Itsukushima Shrine.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_itsukushima_shrine.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Itsukushima Shrine'},
    ),
    Achievement(
      id: 'landmark_nazca_lines',
      name: 'Nazca Lines',
      description: 'Visit Nazca Lines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_nazca_lines.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Nazca Lines'},
    ),
    Achievement(
      id: 'landmark_abu_simbel_temples',
      name: 'Abu Simbel Temples',
      description: 'Visit Abu Simbel Temples.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_abu_simbel_temples.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Abu Simbel Temples'},
    ),
    Achievement(
      id: 'landmark_lake_titicaca',
      name: 'Lake Titicaca',
      description: 'Visit Lake Titicaca.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lake_titicaca.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lake Titicaca'},
    ),
    Achievement(
      id: 'landmark_mount_sinai',
      name: 'Mount Sinai',
      description: 'Visit Mount Sinai.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_sinai.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Sinai'},
    ),
    Achievement(
      id: 'landmark_rialto_bridge',
      name: 'Rialto Bridge',
      description: 'Visit Rialto Bridge.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_rialto_bridge.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Rialto Bridge'},
    ),
    Achievement(
      id: 'landmark_casa_batllo',
      name: 'Casa Batlló',
      description: 'Visit Casa Batlló.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_casa_batllo.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Casa Batlló'},
    ),
    Achievement(
      id: 'landmark_arashiyama_bamboo_grove',
      name: 'Arashiyama Grove',
      description: 'Visit Arashiyama Bamboo Grove.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_arashiyama_bamboo_grove.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Arashiyama Bamboo Grove'},
    ),
    Achievement(
      id: 'landmark_dmz',
      name: 'DMZ',
      description: 'Visit DMZ.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_dmz.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'DMZ'},
    ),
    Achievement(
      id: 'landmark_the_bund',
      name: 'The Bund',
      description: 'Visit The Bund.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_the_bund.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'The Bund'},
    ),
    Achievement(
      id: 'landmark_temple_of_heaven',
      name: 'Temple of Heaven',
      description: 'Visit Temple of Heaven.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_temple_of_heaven.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Temple of Heaven'},
    ),
    Achievement(
      id: 'landmark_tokyo_skytree',
      name: 'Tokyo Skytree',
      description: 'Visit Tokyo Skytree.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tokyo_skytree.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tokyo Skytree'},
    ),
    Achievement(
      id: 'landmark_dolomites',
      name: 'Dolomites',
      description: 'Visit Dolomites.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_dolomites.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Dolomites'},
    ),
    Achievement(
      id: 'landmark_nyhavn',
      name: 'Nyhavn',
      description: 'Visit Nyhavn.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_nyhavn.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Nyhavn'},
    ),
    Achievement(
      id: 'landmark_mezquita_cathedral_of_cordoba',
      name: 'Mezquita de Córdoba',
      description: 'Visit Mezquita-Cathedral of Córdoba.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mezquita_cathedral_of_cordoba.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mezquita-Cathedral of Córdoba'},
    ),
    Achievement(
      id: 'landmark_tulum_ruins',
      name: 'Tulum Ruins',
      description: 'Visit Tulum Ruins.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tulum_ruins.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tulum Ruins'},
    ),
    Achievement(
      id: 'landmark_seville_cathedral',
      name: 'Seville Cathedral',
      description: 'Visit Seville Cathedral.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_seville_cathedral.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Seville Cathedral'},
    ),
    Achievement(
      id: 'landmark_milford_sound',
      name: 'Milford Sound',
      description: 'Visit Milford Sound.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_milford_sound.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Milford Sound'},
    ),
    Achievement(
      id: 'landmark_oriental_pearl_tower',
      name: 'Oriental Pearl Tower',
      description: 'Visit Oriental Pearl Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_oriental_pearl_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Oriental Pearl Tower'},
    ),
    Achievement(
      id: 'landmark_bryce_canyon',
      name: 'Bryce Canyon',
      description: 'Visit Bryce Canyon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_bryce_canyon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Bryce Canyon'},
    ),
    Achievement(
      id: 'landmark_cloud_gate',
      name: 'Cloud Gate',
      description: 'Visit Cloud Gate.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cloud_gate.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cloud Gate'},
    ),
    Achievement(
      id: 'landmark_atacama_desert',
      name: 'Atacama Desert',
      description: 'Visit Atacama Desert.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_atacama_desert.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Atacama Desert'},
    ),
    Achievement(
      id: 'landmark_alcatraz',
      name: 'Alcatraz',
      description: 'Visit Alcatraz.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_alcatraz.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Alcatraz'},
    ),
    Achievement(
      id: 'landmark_angel_falls',
      name: 'Angel Falls',
      description: 'Visit Angel Falls.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_angel_falls.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Angel Falls'},
    ),
    Achievement(
      id: 'landmark_death_valley',
      name: 'Death Valley',
      description: 'Visit Death Valley.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_death_valley.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Death Valley'},
    ),
    Achievement(
      id: 'landmark_torres_del_paine',
      name: 'Torres del Paine',
      description: 'Visit Torres del Paine.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_torres_del_paine.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Torres del Paine'},
    ),
    Achievement(
      id: 'landmark_karnak_temple_complex',
      name: 'Karnak Temple',
      description: 'Visit Karnak Temple Complex.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_karnak_temple_complex.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Karnak Temple Complex'},
    ),
    Achievement(
      id: 'landmark_summer_palace',
      name: 'Summer Palace',
      description: 'Visit Summer Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_summer_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Summer Palace'},
    ),
    Achievement(
      id: 'landmark_giant_s_causeway',
      name: 'Giant\'s Causeway',
      description: 'Visit Giant\'s Causeway.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_giant_s_causeway.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Giant\'s Causeway'},
    ),
    Achievement(
      id: 'landmark_grand_place',
      name: 'Grand Place',
      description: 'Visit Grand Place.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_grand_place.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Grand Place'},
    ),
    Achievement(
      id: 'landmark_wat_arun',
      name: 'Wat Arun',
      description: 'Visit Wat Arun.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_wat_arun.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Wat Arun'},
    ),
    Achievement(
      id: 'landmark_perito_moreno_glacier',
      name: 'Perito Moreno',
      description: 'Visit Perito Moreno Glacier.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_perito_moreno_glacier.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Perito Moreno Glacier'},
    ),
    Achievement(
      id: 'landmark_leshan_giant_buddha',
      name: 'Leshan Buddha',
      description: 'Visit Leshan Giant Buddha.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_leshan_giant_buddha.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Leshan Giant Buddha'},
    ),
    Achievement(
      id: 'landmark_ephesus_archaeological_site',
      name: 'Ephesus',
      description: 'Visit Ephesus Archaeological Site.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_ephesus_archaeological_site.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Ephesus Archaeological Site'},
    ),
    Achievement(
      id: 'landmark_himeji_castle',
      name: 'Himeji Castle',
      description: 'Visit Himeji Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_himeji_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Himeji Castle'},
    ),
    Achievement(
      id: 'landmark_zion_canyon',
      name: 'Zion Canyon',
      description: 'Visit Zion Canyon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_zion_canyon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Zion Canyon'},
    ),
    Achievement(
      id: 'landmark_lake_bled',
      name: 'Lake Bled',
      description: 'Visit Lake Bled.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lake_bled.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lake Bled'},
    ),
    Achievement(
      id: 'landmark_zhangjiajie_national_forest',
      name: 'Zhangjiajie',
      description: 'Visit Zhangjiajie National Forest.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_zhangjiajie_national_forest.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Zhangjiajie National Forest'},
    ),
    Achievement(
      id: 'landmark_pamukkale_travertine_terraces',
      name: 'Pamukkale',
      description: 'Visit Pamukkale Travertine Terraces.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pamukkale_travertine_terraces.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pamukkale Travertine Terraces'},
    ),
    Achievement(
      id: 'landmark_osaka_castle',
      name: 'Osaka Castle',
      description: 'Visit Osaka Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_osaka_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Osaka Castle'},
    ),
    Achievement(
      id: 'landmark_red_fort',
      name: 'Red Fort',
      description: 'Visit Red Fort.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_red_fort.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Red Fort'},
    ),
    Achievement(
      id: 'landmark_monasteries_of_meteora',
      name: 'Meteora',
      description: 'Visit Monasteries of Meteora.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_monasteries_of_meteora.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Monasteries of Meteora'},
    ),
    Achievement(
      id: 'landmark_sanctuary_of_olympia',
      name: 'Olympia Sanctuary',
      description: 'Visit Sanctuary of Olympia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sanctuary_of_olympia.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sanctuary of Olympia'},
    ),
    Achievement(
      id: 'landmark_plitvice_lakes',
      name: 'Plitvice Lakes',
      description: 'Visit Plitvice Lakes.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_plitvice_lakes.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Plitvice Lakes'},
    ),
    Achievement(
      id: 'landmark_arches_national_park',
      name: 'Arches Natl. Park',
      description: 'Visit Arches National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_arches_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Arches National Park'},
    ),
    Achievement(
      id: 'landmark_bran_castle',
      name: 'Bran Castle',
      description: 'Visit Bran Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_bran_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Bran Castle'},
    ),
    Achievement(
      id: 'landmark_victoria_peak',
      name: 'Victoria Peak',
      description: 'Visit Victoria Peak.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_victoria_peak.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Victoria Peak'},
    ),
    Achievement(
      id: 'landmark_n_seoul_tower',
      name: 'N Seoul Tower',
      description: 'Visit N Seoul Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_n_seoul_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'N Seoul Tower'},
    ),
    Achievement(
      id: 'landmark_belem_tower',
      name: 'Belém Tower',
      description: 'Visit Belém Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_belem_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Belém Tower'},
    ),
    Achievement(
      id: 'landmark_hobbiton_movie_set',
      name: 'Hobbiton Movie Set',
      description: 'Visit Hobbiton Movie Set.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hobbiton_movie_set.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hobbiton Movie Set'},
    ),
    Achievement(
      id: 'landmark_ngorongoro_crater',
      name: 'Ngorongoro Crater',
      description: 'Visit Ngorongoro Crater.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_ngorongoro_crater.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Ngorongoro Crater'},
    ),
    Achievement(
      id: 'landmark_denali',
      name: 'Denali',
      description: 'Visit Denali.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_denali.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Denali'},
    ),
    Achievement(
      id: 'landmark_the_twelve_apostles',
      name: 'The Twelve Apostles',
      description: 'Visit The Twelve Apostles.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_the_twelve_apostles.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'The Twelve Apostles'},
    ),
    Achievement(
      id: 'landmark_pena_palace',
      name: 'Pena Palace',
      description: 'Visit Pena Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_pena_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Pena Palace'},
    ),
    Achievement(
      id: 'landmark_batu_caves',
      name: 'Batu Caves',
      description: 'Visit Batu Caves.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_batu_caves.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Batu Caves'},
    ),
    Achievement(
      id: 'landmark_hoi_an_old_town',
      name: 'Hoi An Old Town',
      description: 'Visit Hoi An Old Town.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hoi_an_old_town.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hoi An Old Town'},
    ),
    Achievement(
      id: 'landmark_geirangerfjord',
      name: 'Geirangerfjord',
      description: 'Visit Geirangerfjord.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_geirangerfjord.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Geirangerfjord'},
    ),
    Achievement(
      id: 'landmark_sigiriya',
      name: 'Sigiriya',
      description: 'Visit Sigiriya.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sigiriya.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sigiriya'},
    ),
    Achievement(
      id: 'landmark_shwedagon_pagoda',
      name: 'Shwedagon Pagoda',
      description: 'Visit Shwedagon Pagoda.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_shwedagon_pagoda.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Shwedagon Pagoda'},
    ),
    Achievement(
      id: 'landmark_hallstatt_village',
      name: 'Hallstatt Village',
      description: 'Visit Hallstatt Village.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hallstatt_village.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hallstatt Village'},
    ),
    Achievement(
      id: 'landmark_cu_chi_tunnels',
      name: 'Cu Chi Tunnels',
      description: 'Visit Cu Chi Tunnels.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cu_chi_tunnels.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cu Chi Tunnels'},
    ),
    Achievement(
      id: 'landmark_ayutthaya_historical_park',
      name: 'Ayutthaya',
      description: 'Visit Ayutthaya Historical Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_ayutthaya_historical_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Ayutthaya Historical Park'},
    ),
    Achievement(
      id: 'landmark_jemaa_el_fnaa',
      name: 'Jemaa el-Fnaa',
      description: 'Visit Jemaa el-Fnaa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_jemaa_el_fnaa.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Jemaa el-Fnaa'},
    ),
    Achievement(
      id: 'landmark_gamla_stan',
      name: 'Gamla Stan',
      description: 'Visit Gamla Stan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_gamla_stan.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Gamla Stan'},
    ),
    Achievement(
      id: 'landmark_hohensalzburg_fortress',
      name: 'Hohensalzburg',
      description: 'Visit Hohensalzburg Fortress.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hohensalzburg_fortress.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hohensalzburg Fortress'},
    ),
    Achievement(
      id: 'landmark_wadi_rum',
      name: 'Wadi Rum',
      description: 'Visit Wadi Rum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_wadi_rum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Wadi Rum'},
    ),
    Achievement(
      id: 'landmark_cite_de_carcassonne',
      name: 'Cité de Carcassonne',
      description: 'Visit Cité de Carcassonne.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_cite_de_carcassonne.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Cité de Carcassonne'},
    ),
    Achievement(
      id: 'landmark_avenue_of_the_baobabs',
      name: 'Baobab Avenue',
      description: 'Visit Avenue of the Baobabs.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_avenue_of_the_baobabs.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Avenue of the Baobabs'},
    ),
    Achievement(
      id: 'landmark_rhodes_old_town',
      name: 'Rhodes Old Town',
      description: 'Visit Rhodes Old Town.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_rhodes_old_town.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Rhodes Old Town'},
    ),
    Achievement(
      id: 'landmark_glacier_national_park',
      name: 'Glacier Natl. Park',
      description: 'Visit Glacier National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_glacier_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Glacier National Park'},
    ),
    Achievement(
      id: 'landmark_waitomo_glowworm_caves',
      name: 'Waitomo Caves',
      description: 'Visit Waitomo Glowworm Caves.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_waitomo_glowworm_caves.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Waitomo Glowworm Caves'},
    ),
    Achievement(
      id: 'landmark_tikal',
      name: 'Tikal',
      description: 'Visit Tikal.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tikal.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tikal'},
    ),
    Achievement(
      id: 'landmark_jiuzhaigou_valley',
      name: 'Jiuzhaigou Valley',
      description: 'Visit Jiuzhaigou Valley.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_jiuzhaigou_valley.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Jiuzhaigou Valley'},
    ),
    Achievement(
      id: 'landmark_bagan_archaeological_zone',
      name: 'Bagan',
      description: 'Visit Bagan Archaeological Zone.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_bagan_archaeological_zone.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Bagan Archaeological Zone'},
    ),
    Achievement(
      id: 'landmark_thingvellir_national_park',
      name: 'Thingvellir',
      description: 'Visit Thingvellir National Park.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_thingvellir_national_park.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Thingvellir National Park'},
    ),
    Achievement(
      id: 'landmark_santa_claus_village',
      name: 'Santa Claus Village',
      description: 'Visit Santa Claus Village.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_santa_claus_village.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Santa Claus Village'},
    ),
    Achievement(
      id: 'landmark_seongsan_ilchulbong',
      name: 'Seongsan Ilchulbong',
      description: 'Visit Seongsan Ilchulbong.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_seongsan_ilchulbong.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Seongsan Ilchulbong'},
    ),
    Achievement(
      id: 'landmark_naqsh_e_jahan_square',
      name: 'Naqsh-e Jahan',
      description: 'Visit Naqsh-e Jahan Square.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_naqsh_e_jahan_square.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Naqsh-e Jahan Square'},
    ),
    Achievement(
      id: 'landmark_mount_roraima',
      name: 'Mount Roraima',
      description: 'Visit Mount Roraima.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_roraima.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Roraima'},
    ),
    Achievement(
      id: 'landmark_bryggen',
      name: 'Bryggen',
      description: 'Visit Bryggen.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_bryggen.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Bryggen'},
    ),
    Achievement(
      id: 'landmark_warsaw_old_town',
      name: 'Warsaw Old Town',
      description: 'Visit Warsaw Old Town.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_warsaw_old_town.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Warsaw Old Town'},
    ),
    Achievement(
      id: 'landmark_vatnajokull_ice_caves',
      name: 'Vatnajökull Caves',
      description: 'Visit Vatnajökull Ice Caves.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_vatnajokull_ice_caves.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Vatnajökull Ice Caves'},
    ),
    Achievement(
      id: 'landmark_mount_cook',
      name: 'Mount Cook',
      description: 'Visit Mount Cook.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_cook.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Cook'},
    ),
    Achievement(
      id: 'landmark_kinderdijk',
      name: 'Kinderdijk',
      description: 'Visit Kinderdijk.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_kinderdijk.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Kinderdijk'},
    ),
    Achievement(
      id: 'landmark_recoleta_cemetery',
      name: 'Recoleta Cemetery',
      description: 'Visit Recoleta Cemetery.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_recoleta_cemetery.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Recoleta Cemetery'},
    ),
    Achievement(
      id: 'landmark_lencois_maranhenses',
      name: 'Lençóis Dunes',
      description: 'Visit Lençóis Maranhenses.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lencois_maranhenses.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lençóis Maranhenses'},
    ),
    Achievement(
      id: 'landmark_notre_dame_cathedral_of_saigon',
      name: 'Saigon Notre Dame',
      description: 'Visit Notre Dame Cathedral of Saigon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_notre_dame_cathedral_of_saigon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Notre Dame Cathedral of Saigon'},
    ),
    Achievement(
      id: 'landmark_hampi_group_of_monuments',
      name: 'Hampi',
      description: 'Visit Hampi Group of Monuments.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hampi_group_of_monuments.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hampi Group of Monuments'},
    ),
    Achievement(
      id: 'landmark_bulguksa_temple',
      name: 'Bulguksa Temple',
      description: 'Visit Bulguksa Temple.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_bulguksa_temple.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Bulguksa Temple'},
    ),
    Achievement(
      id: 'landmark_mount_athos',
      name: 'Mount Athos',
      description: 'Visit Mount Athos.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_athos.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Athos'},
    ),
    Achievement(
      id: 'landmark_jokulsarlon_glacier_lagoon',
      name: 'Jökulsárlón',
      description: 'Visit Jökulsárlón Glacier Lagoon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_jokulsarlon_glacier_lagoon.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Jökulsárlón Glacier Lagoon'},
    ),
    Achievement(
      id: 'landmark_baalbek',
      name: 'Baalbek',
      description: 'Visit Baalbek.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_baalbek.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Baalbek'},
    ),
    Achievement(
      id: 'landmark_fraser_island',
      name: 'Fraser Island',
      description: 'Visit Fraser Island.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_fraser_island.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Fraser Island'},
    ),
    Achievement(
      id: 'landmark_mount_rainier',
      name: 'Mount Rainier',
      description: 'Visit Mount Rainier.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_rainier.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Rainier'},
    ),
    Achievement(
      id: 'landmark_gergeti_trinity_church',
      name: 'Gergeti Church',
      description: 'Visit Gergeti Trinity Church.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_gergeti_trinity_church.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Gergeti Trinity Church'},
    ),
    Achievement(
      id: 'landmark_temple_of_garni',
      name: 'Temple of Garni',
      description: 'Visit Temple of Garni.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_temple_of_garni.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Temple of Garni'},
    ),
    Achievement(
      id: 'landmark_tiananmen_square',
      name: 'Tiananmen Square',
      description: 'Visit Tiananmen Square.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_tiananmen_square.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Tiananmen Square'},
    ),
    Achievement(
      id: 'landmark_uffizi_gallery',
      name: 'Uffizi Gallery',
      description: 'Visit Uffizi Gallery.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_uffizi_gallery.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Uffizi Gallery'},
    ),
    Achievement(
      id: 'landmark_musee_d_orsay',
      name: 'Musée d\'Orsay',
      description: 'Visit Musée d\'Orsay.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_musee_d_orsay.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Musée d\'Orsay'},
    ),
    Achievement(
      id: 'landmark_prado_museum',
      name: 'Prado Museum',
      description: 'Visit Prado Museum.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_prado_museum.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Prado Museum'},
    ),
    Achievement(
      id: 'landmark_lake_baikal',
      name: 'Lake Baikal',
      description: 'Visit Lake Baikal.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lake_baikal.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lake Baikal'},
    ),
    Achievement(
      id: 'landmark_hungarian_parliament_building',
      name: 'Budapest Parliament',
      description: 'Visit Hungarian Parliament Building.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hungarian_parliament_building.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hungarian Parliament Building'},
    ),
    Achievement(
      id: 'landmark_prague_astronomical_clock',
      name: 'Prague Clock Tower',
      description: 'Visit Prague Astronomical Clock.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_prague_astronomical_clock.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Prague Astronomical Clock'},
    ),
    Achievement(
      id: 'landmark_topkapi_palace',
      name: 'Topkapi Palace',
      description: 'Visit Topkapi Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_topkapi_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Topkapi Palace'},
    ),
    Achievement(
      id: 'landmark_royal_palace_of_madrid',
      name: 'Madrid Royal Palace',
      description: 'Visit Royal Palace of Madrid.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_royal_palace_of_madrid.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Royal Palace of Madrid'},
    ),
    Achievement(
      id: 'landmark_casa_mila',
      name: 'Casa Milà',
      description: 'Visit Casa Milà.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_casa_mila.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Casa Milà'},
    ),
    Achievement(
      id: 'landmark_mount_etna',
      name: 'Mount Etna',
      description: 'Visit Mount Etna.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_mount_etna.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Mount Etna'},
    ),
    Achievement(
      id: 'landmark_huangshan',
      name: 'Huangshan',
      description: 'Visit Huangshan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_huangshan.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Huangshan'},
    ),
    Achievement(
      id: 'landmark_hofburg_palace',
      name: 'Hofburg Palace',
      description: 'Visit Hofburg Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_hofburg_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Hofburg Palace'},
    ),
    Achievement(
      id: 'landmark_sanssouci_palace',
      name: 'Sanssouci Palace',
      description: 'Visit Sanssouci Palace.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_sanssouci_palace.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Sanssouci Palace'},
    ),
    Achievement(
      id: 'landmark_helsinki_cathedral',
      name: 'Helsinki Cathedral',
      description: 'Visit Helsinki Cathedral.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_helsinki_cathedral.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Helsinki Cathedral'},
    ),
    Achievement(
      id: 'landmark_palace_of_the_parliament',
      name: 'Romania Parliament',
      description: 'Visit Palace of the Parliament.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_palace_of_the_parliament.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Palace of the Parliament'},
    ),
    Achievement(
      id: 'landmark_galata_tower',
      name: 'Galata Tower',
      description: 'Visit Galata Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_galata_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Galata Tower'},
    ),
    Achievement(
      id: 'landmark_peles_castle',
      name: 'Peleș Castle',
      description: 'Visit Peleș Castle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_peles_castle.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Peleș Castle'},
    ),
    Achievement(
      id: 'landmark_ancient_agora_of_athens',
      name: 'Agora of Athens',
      description: 'Visit Ancient Agora of Athens.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_ancient_agora_of_athens.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Ancient Agora of Athens'},
    ),
    Achievement(
      id: 'landmark_lotte_world_tower',
      name: 'Lotte World Tower',
      description: 'Visit Lotte World Tower.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/top_landmarks_badge/landmark_lotte_world_tower.png',
      category: AchievementCategory.Landmarks,
      targetIsoCodes: {'Lotte World Tower'},
    ),
    // ─── New Country Achievements (Country_New) ───────────────
    Achievement(
      id: 'countries_20',
      name: '20 Countries',
      description: 'Visit 20 different countries.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/countries_20.jpg',
      category: AchievementCategory.Country,
      targetCount: 20,
    ),
    Achievement(
      id: 'countries_30',
      requiresSubscription: true,
      name: '30 Countries',
      description: 'Visit 30 different countries.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/new_country_badges/countries_30.jpg',
      category: AchievementCategory.Country,
      targetCount: 30,
    ),
    Achievement(
      id: 'countries_40',
      requiresSubscription: true,
      name: '40 Countries',
      description: 'Visit 40 different countries.',
      difficulty: AchievementDifficulty.Nomad,
      points: 10,
      imagePath: 'assets/new_country_badges/countries_40.jpg',
      category: AchievementCategory.Country,
      targetCount: 40,
    ),
    Achievement(
      id: 'countries_60',
      requiresSubscription: true,
      name: '60 Countries',
      description: 'Visit 60 different countries.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/new_country_badges/countries_60.jpg',
      category: AchievementCategory.Country,
      targetCount: 60,
    ),
    Achievement(
      id: 'countries_80',
      requiresSubscription: true,
      name: '80 Countries',
      description: 'Visit 80 different countries.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/countries_80.jpg',
      category: AchievementCategory.Country,
      targetCount: 80,
    ),
    Achievement(
      id: 'countries_90',
      requiresSubscription: true,
      name: '90 Countries',
      description: 'Visit 90 different countries.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/countries_90.jpg',
      category: AchievementCategory.Country,
      targetCount: 90,
    ),
    Achievement(
      id: 'continents_2',
      name: '2 Continents',
      description: 'Visit countries in 2 different continents.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/new_country_badges/continents_2.jpg',
      category: AchievementCategory.Country,
      targetCount: 2,
    ),
    Achievement(
      id: 'continents_4',
      requiresSubscription: true,
      name: '4 Continents',
      description: 'Visit countries in 4 different continents.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/new_country_badges/continents_4.jpg',
      category: AchievementCategory.Country,
      targetCount: 4,
    ),
    Achievement(
      id: 'continents_5',
      requiresSubscription: true,
      name: '5 Continents',
      description: 'Visit countries in 5 different continents.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/new_country_badges/continents_5.jpg',
      category: AchievementCategory.Country,
      targetCount: 5,
    ),
    Achievement(
      id: 'africa_5',
      requiresSubscription: true,
      name: '5 African Countries',
      description: 'Visit 5 different countries in Africa.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/africa_5.jpg',
      category: AchievementCategory.Country,
      targetCount: 5,
    ),
    Achievement(
      id: 'asia_10',
      requiresSubscription: true,
      name: '10 Asian Countries',
      description: 'Visit 10 different countries in Asia.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/asia_10.jpg',
      category: AchievementCategory.Country,
      targetCount: 10,
    ),
    Achievement(
      id: 'europe_10',
      requiresSubscription: true,
      name: '10 European Countries',
      description: 'Visit 10 different countries in Europe.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/europe_10.jpg',
      category: AchievementCategory.Country,
      targetCount: 10,
    ),
    Achievement(
      id: 'americas_5',
      requiresSubscription: true,
      name: '5 American Countries',
      description: 'Visit 5 different countries in the Americas.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/americas_5.jpg',
      category: AchievementCategory.Country,
      targetCount: 5,
    ),
    Achievement(
      id: 'indochina',
      requiresSubscription: true,
      name: 'Indochina',
      description: 'Visit Vietnam, Laos, and Cambodia.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/indochina.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'VNM', 'LAO', 'KHM'},
    ),
    Achievement(
      id: 'axis_powers',
      requiresSubscription: true,
      name: 'Axis Powers',
      description: 'Visit Germany, Italy, and Japan.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/new_country_badges/axis_powers.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'DEU', 'ITA', 'JPN'},
    ),
    Achievement(
      id: 'north_america',
      requiresSubscription: true,
      name: 'North America',
      description: 'Visit the United States, Canada, and Mexico.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/new_country_badges/north_america.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'USA', 'CAN', 'MEX'},
    ),
    Achievement(
      id: 'maghreb',
      requiresSubscription: true,
      name: 'Maghreb',
      description: 'Visit Morocco, Algeria, and Tunisia.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/new_country_badges/maghreb.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'MAR', 'DZA', 'TUN'},
    ),
    Achievement(
      id: 'gulf',
      requiresSubscription: true,
      name: 'Gulf States',
      description: 'Visit Saudi Arabia, the UAE, Qatar, Kuwait, Oman, and Bahrain.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/gulf.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'SAU', 'ARE', 'QAT', 'KWT', 'OMN', 'BHR'},
    ),
    Achievement(
      id: 'levant',
      requiresSubscription: true,
      name: 'Levant',
      description: 'Visit Syria, Lebanon, Jordan, Israel, and Palestine.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/levant.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'SYR', 'LBN', 'JOR', 'ISR', 'PSE'},
    ),
    Achievement(
      id: 'polynesia',
      requiresSubscription: true,
      name: 'Polynesia',
      description: 'Visit New Zealand, Samoa, Tonga, and Tuvalu.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/polynesia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'NZL', 'WSM', 'TON', 'TUV'},
    ),
    Achievement(
      id: 'melanesia',
      requiresSubscription: true,
      name: 'Melanesia',
      description: 'Visit Fiji, Papua New Guinea, the Solomon Islands, and Vanuatu.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/melanesia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'FJI', 'PNG', 'SLB', 'VUT'},
    ),
    Achievement(
      id: 'micronesia',
      requiresSubscription: true,
      name: 'Micronesia',
      description: 'Visit the Federated States of Micronesia, Kiribati, the Marshall Islands, Nauru, and Palau.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/micronesia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'FSM', 'KIR', 'MHL', 'NRU', 'PLW'},
    ),
    Achievement(
      id: 'central_asia',
      requiresSubscription: true,
      name: 'Central Asia',
      description: 'Visit Kazakhstan, Uzbekistan, Turkmenistan, Tajikistan, and Kyrgyzstan.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/central_asia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'KAZ', 'UZB', 'TKM', 'TJK', 'KGZ'},
    ),
    Achievement(
      id: 'himalaya',
      requiresSubscription: true,
      name: 'Himalaya',
      description: 'Visit Nepal, Bhutan, India, China, and Pakistan.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/new_country_badges/himalaya.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'NPL', 'BTN', 'IND', 'CHN', 'PAK'},
    ),
    Achievement(
      id: 'five_eyes',
      requiresSubscription: true,
      name: 'Five Eyes',
      description: 'Visit the United States, United Kingdom, Canada, Australia, and New Zealand.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/five_eyes.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'USA', 'GBR', 'CAN', 'AUS', 'NZL'},
    ),
    Achievement(
      id: 'former_yugoslavia',
      requiresSubscription: true,
      name: 'Former Yugoslavia',
      description: 'Visit Serbia, Croatia, Slovenia, Bosnia and Herzegovina, Montenegro, North Macedonia, and Kosovo.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/new_country_badges/former_yugoslavia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'SRB', 'HRV', 'SVN', 'BIH', 'MNE', 'MKD', 'KOS'},
    ),
    Achievement(
      id: 'central_america',
      requiresSubscription: true,
      name: 'Central America',
      description: 'Visit Belize, Guatemala, El Salvador, Honduras, Nicaragua, Costa Rica, and Panama.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/new_country_badges/central_america.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'BLZ', 'GTM', 'SLV', 'HND', 'NIC', 'CRI', 'PAN'},
    ),
    Achievement(
      id: 'alps',
      requiresSubscription: true,
      name: 'The Alps',
      description: 'Visit Austria, France, Germany, Italy, Liechtenstein, Monaco, Slovenia, and Switzerland.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/new_country_badges/alps.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'AUT', 'FRA', 'DEU', 'ITA', 'LIE', 'MCO', 'SVN', 'CHE'},
    ),
    Achievement(
      id: 'iberia',
      requiresSubscription: true,
      name: 'Iberia',
      description: 'Visit Portugal, Spain, Andorra, and Gibraltar.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/iberia.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'PRT', 'ESP', 'AND', 'GIB'},
    ),
    Achievement(
      id: 'dach',
      requiresSubscription: true,
      name: 'DACH',
      description: 'Visit Germany, Austria, and Switzerland.',
      difficulty: AchievementDifficulty.Explorer,
      points: 3,
      imagePath: 'assets/new_country_badges/dach.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'DEU', 'AUT', 'CHE'},
    ),
    Achievement(
      id: 'malay_world',
      requiresSubscription: true,
      name: 'Malay World',
      description: 'Visit Malaysia, Indonesia, and Brunei.',
      difficulty: AchievementDifficulty.Explorer,
      points: 5,
      imagePath: 'assets/new_country_badges/malay_world.png',
      category: AchievementCategory.Country,
      targetIsoCodes: {'MYS', 'IDN', 'BRN'},
    ),
    // ─── Individual Airline Badges (1pt each) ───────────────
    Achievement(
      id: 'airline_qr',
      name: 'Qatar Airways',
      description: 'Fly with Qatar Airways.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/qr.png',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'QR'},
    ),
    Achievement(
      id: 'airline_ek',
      name: 'Emirates',
      description: 'Fly with Emirates.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ek.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'EK'},
    ),
    Achievement(
      id: 'airline_sq',
      name: 'Singapore Airlines',
      description: 'Fly with Singapore Airlines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/sq.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'SQ'},
    ),
    Achievement(
      id: 'airline_af',
      name: 'Air France',
      description: 'Fly with Air France.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/af.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'AF'},
    ),
    Achievement(
      id: 'airline_cx',
      name: 'Cathay Pacific',
      description: 'Fly with Cathay Pacific.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/cx.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'CX'},
    ),
    Achievement(
      id: 'airline_tk',
      name: 'Turkish Airlines',
      description: 'Fly with Turkish Airlines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/tk.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'TK'},
    ),
    Achievement(
      id: 'airline_ba',
      name: 'British Airways',
      description: 'Fly with British Airways.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ba.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'BA'},
    ),
    Achievement(
      id: 'airline_nh',
      name: 'All Nippon Airways',
      description: 'Fly with All Nippon Airways.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/nh.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'NH'},
    ),
    Achievement(
      id: 'airline_jl',
      name: 'Japan Airlines',
      description: 'Fly with Japan Airlines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/jl.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'JL'},
    ),
    Achievement(
      id: 'airline_lh',
      name: 'Lufthansa',
      description: 'Fly with Lufthansa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/lh.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'LH'},
    ),
    Achievement(
      id: 'airline_dl',
      name: 'Delta Air Lines',
      description: 'Fly with Delta Air Lines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/dl.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'DL'},
    ),
    Achievement(
      id: 'airline_ke',
      name: 'Korean Air',
      description: 'Fly with Korean Air.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ke.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'KE'},
    ),
    Achievement(
      id: 'airline_lx',
      name: 'Swiss Air Lines',
      description: 'Fly with Swiss International Air Lines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/lx.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'LX'},
    ),
    Achievement(
      id: 'airline_qf',
      name: 'Qantas',
      description: 'Fly with Qantas.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/qf.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'QF'},
    ),
    Achievement(
      id: 'airline_aa',
      name: 'American Airlines',
      description: 'Fly with American Airlines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/aa.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'AA'},
    ),
    Achievement(
      id: 'airline_ib',
      name: 'Iberia',
      description: 'Fly with Iberia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ib.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'IB'},
    ),
    Achievement(
      id: 'airline_ua',
      name: 'United Airlines',
      description: 'Fly with United Airlines.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ua.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'UA'},
    ),
    Achievement(
      id: 'airline_ey',
      name: 'Etihad Airways',
      description: 'Fly with Etihad Airways.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ey.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'EY'},
    ),
    Achievement(
      id: 'airline_ac',
      name: 'Air Canada',
      description: 'Fly with Air Canada.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/ac.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'AC'},
    ),
    Achievement(
      id: 'airline_br',
      name: 'EVA Air',
      description: 'Fly with EVA Air.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airlines/br.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'BR'},
    ),
    // ─── Individual Airport Badges (1pt each) ───────────────
    Achievement(
      id: 'airport_sin',
      name: 'Changi Airport',
      description: 'Visit Singapore Changi International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/sin.png',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'SIN'},
    ),
    Achievement(
      id: 'airport_hnd',
      name: 'Haneda Airport',
      description: 'Visit Tokyo International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/hnd.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'HND'},
    ),
    Achievement(
      id: 'airport_dxb',
      name: 'Dubai Airport',
      description: 'Visit Dubai International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/dxb.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'DXB'},
    ),
    Achievement(
      id: 'airport_icn',
      name: 'Incheon Airport',
      description: 'Visit Incheon International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/icn.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'ICN'},
    ),
    Achievement(
      id: 'airport_cdg',
      name: 'CDG Airport',
      description: 'Visit Charles de Gaulle International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/cdg.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'CDG'},
    ),
    Achievement(
      id: 'airport_doh',
      name: 'Hamad Airport',
      description: 'Visit Hamad International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/doh.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'DOH'},
    ),
    Achievement(
      id: 'airport_lhr',
      name: 'Heathrow Airport',
      description: 'Visit London Heathrow Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/lhr.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'LHR'},
    ),
    Achievement(
      id: 'airport_ist',
      name: 'Istanbul Airport',
      description: 'Visit Istanbul Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/ist.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'IST'},
    ),
    Achievement(
      id: 'airport_nrt',
      name: 'Narita Airport',
      description: 'Visit Narita International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/nrt.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'NRT'},
    ),
    Achievement(
      id: 'airport_hkg',
      name: 'Hong Kong Airport',
      description: 'Visit Chek Lap Kok International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/hkg.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'HKG'},
    ),
    Achievement(
      id: 'airport_ams',
      name: 'Schiphol Airport',
      description: 'Visit Amsterdam Airport Schiphol.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/ams.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'AMS'},
    ),
    Achievement(
      id: 'airport_fra',
      name: 'Frankfurt Airport',
      description: 'Visit Frankfurt am Main International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/fra.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'FRA'},
    ),
    Achievement(
      id: 'airport_jfk',
      name: 'JFK Airport',
      description: 'Visit John F Kennedy International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/jfk.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'JFK'},
    ),
    Achievement(
      id: 'airport_lax',
      name: 'LAX Airport',
      description: 'Visit Los Angeles International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/lax.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'LAX'},
    ),
    Achievement(
      id: 'airport_muc',
      name: 'Munich Airport',
      description: 'Visit Munich International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/muc.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'MUC'},
    ),
    Achievement(
      id: 'airport_fco',
      name: 'Fiumicino Airport',
      description: 'Visit Leonardo Da Vinci (Fiumicino) International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/fco.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'FCO'},
    ),
    Achievement(
      id: 'airport_atl',
      name: 'Atlanta Airport',
      description: 'Visit Hartsfield Jackson Atlanta International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/atl.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'ATL'},
    ),
    Achievement(
      id: 'airport_mad',
      name: 'Barajas Airport',
      description: 'Visit Madrid Barajas International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/mad.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'MAD'},
    ),
    Achievement(
      id: 'airport_sfo',
      name: 'SFO Airport',
      description: 'Visit San Francisco International Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/sfo.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'SFO'},
    ),
    Achievement(
      id: 'airport_zrh',
      name: 'Zurich Airport',
      description: 'Visit Zurich Airport.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/badge_airports/zrh.jpg',
      category: AchievementCategory.Flight,
      targetIsoCodes: {'ZRH'},
    ),
    // ─── New City Achievements (fixed sets) ───────────────
    Achievement(
      id: 'south_africa_three_capitals',
      requiresSubscription: true,
      name: 'Three Capitals',
      description: 'Visit Pretoria, Cape Town, and Bloemfontein.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/south_africa_three_capitals.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Pretoria', 'Cape Town', 'Bloemfontein'},
    ),
    Achievement(
      id: 'morocco_imperial_cities',
      requiresSubscription: true,
      name: 'Imperial Cities',
      description: 'Visit Fez, Marrakesh, Meknes, and Rabat.',
      difficulty: AchievementDifficulty.Adventurer,
      points: 10,
      imagePath: 'assets/badges/morocco_imperial_cities.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Fez', 'Marrakesh', 'Meknes', 'Rabat'},
    ),
    Achievement(
      id: 'india_golden_triangle',
      requiresSubscription: true,
      name: 'Golden Triangle',
      description: 'Visit Delhi, Agra, and Jaipur.',
      difficulty: AchievementDifficulty.Nomad,
      points: 7,
      imagePath: 'assets/badges/india_golden_triangle.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Delhi', 'Agra', 'Jaipur'},
    ),
    Achievement(
      id: 'china_seven_ancient_capitals',
      requiresSubscription: true,
      name: 'Ancient Capitals',
      description: 'Visit all Seven Great Ancient Capitals of China.',
      difficulty: AchievementDifficulty.Worldmaster,
      points: 20,
      imagePath: 'assets/badges/china_seven_ancient_capitals.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Xi\'an', 'Beijing', 'Luoyang', 'Nanjing', 'Kaifeng', 'Hangzhou', 'Anyang'},
    ),
    // ─── New Individual City Badges (1pt each, from cities_with_prompts.xlsx) ───────────────
    Achievement(
      id: 'jp_tokyo',
      name: 'Tokyo',
      description: 'Visit Tokyo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_tokyo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tokyo'},
    ),
    Achievement(
      id: 'jp_osaka',
      requiresSubscription: true,
      name: 'Osaka',
      description: 'Visit Osaka.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_osaka.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Osaka'},
    ),
    Achievement(
      id: 'jp_kyoto',
      requiresSubscription: true,
      name: 'Kyoto',
      description: 'Visit Kyoto.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_kyoto.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kyoto'},
    ),
    Achievement(
      id: 'jp_fukuoka',
      requiresSubscription: true,
      name: 'Fukuoka',
      description: 'Visit Fukuoka.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_fukuoka.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Fukuoka'},
    ),
    Achievement(
      id: 'jp_hiroshima',
      requiresSubscription: true,
      name: 'Hiroshima',
      description: 'Visit Hiroshima.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_hiroshima.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Hiroshima'},
    ),
    Achievement(
      id: 'jp_sapporo',
      requiresSubscription: true,
      name: 'Sapporo',
      description: 'Visit Sapporo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jp_sapporo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Sapporo'},
    ),
    Achievement(
      id: 'kr_seoul',
      name: 'Seoul',
      description: 'Visit Seoul.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kr_seoul.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Seoul'},
    ),
    Achievement(
      id: 'kr_busan',
      requiresSubscription: true,
      name: 'Busan',
      description: 'Visit Busan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kr_busan.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Busan'},
    ),
    Achievement(
      id: 'kr_gyeongju',
      requiresSubscription: true,
      name: 'Gyeongju',
      description: 'Visit Gyeongju.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kr_gyeongju.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Gyeongju'},
    ),
    Achievement(
      id: 'kr_jeju_city',
      requiresSubscription: true,
      name: 'Jeju City',
      description: 'Visit Jeju City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kr_jeju_city.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Jeju City'},
    ),
    Achievement(
      id: 'cn_beijing',
      name: 'Beijing',
      description: 'Visit Beijing.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_beijing.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Beijing'},
    ),
    Achievement(
      id: 'cn_shanghai',
      requiresSubscription: true,
      name: 'Shanghai',
      description: 'Visit Shanghai.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_shanghai.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Shanghai'},
    ),
    Achievement(
      id: 'cn_chengdu',
      requiresSubscription: true,
      name: 'Chengdu',
      description: 'Visit Chengdu.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_chengdu.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Chengdu'},
    ),
    Achievement(
      id: 'cn_chongqing',
      requiresSubscription: true,
      name: 'Chongqing',
      description: 'Visit Chongqing.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_chongqing.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Chongqing'},
    ),
    Achievement(
      id: 'cn_xi_an',
      requiresSubscription: true,
      name: 'Xi\'an',
      description: 'Visit Xi\'an.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_xi_an.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Xi\'an'},
    ),
    Achievement(
      id: 'cn_hangzhou',
      requiresSubscription: true,
      name: 'Hangzhou',
      description: 'Visit Hangzhou.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cn_hangzhou.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Hangzhou'},
    ),
    Achievement(
      id: 'hk_hong_kong',
      requiresSubscription: true,
      name: 'Hong Kong',
      description: 'Visit Hong Kong.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/hk_hong_kong.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Hong Kong'},
    ),
    Achievement(
      id: 'mo_macau',
      requiresSubscription: true,
      name: 'Macau',
      description: 'Visit Macau.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mo_macau.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Macau'},
    ),
    Achievement(
      id: 'tw_taipei',
      requiresSubscription: true,
      name: 'Taipei',
      description: 'Visit Taipei.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tw_taipei.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Taipei'},
    ),
    Achievement(
      id: 'mn_ulaanbaatar',
      requiresSubscription: true,
      name: 'Ulaanbaatar',
      description: 'Visit Ulaanbaatar.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mn_ulaanbaatar.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ulaanbaatar'},
    ),
    Achievement(
      id: 'th_bangkok',
      name: 'Bangkok',
      description: 'Visit Bangkok.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/th_bangkok.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bangkok'},
    ),
    Achievement(
      id: 'th_phra_nakhon_si_ayutthaya',
      requiresSubscription: true,
      name: 'Ayutthaya',
      description: 'Visit Phra Nakhon Si Ayutthaya.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/th_phra_nakhon_si_ayutthaya.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Phra Nakhon Si Ayutthaya'},
    ),
    Achievement(
      id: 'th_chiang_mai',
      requiresSubscription: true,
      name: 'Chiang Mai',
      description: 'Visit Chiang Mai.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/th_chiang_mai.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Chiang Mai'},
    ),
    Achievement(
      id: 'th_phuket',
      requiresSubscription: true,
      name: 'Phuket',
      description: 'Visit Phuket.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/th_phuket.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Phuket'},
    ),
    Achievement(
      id: 'th_pattaya',
      requiresSubscription: true,
      name: 'Pattaya',
      description: 'Visit Pattaya.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/th_pattaya.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Pattaya'},
    ),
    Achievement(
      id: 'sg_singapore',
      requiresSubscription: true,
      name: 'Singapore',
      description: 'Visit Singapore.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sg_singapore.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Singapore'},
    ),
    Achievement(
      id: 'my_kuala_lumpur',
      requiresSubscription: true,
      name: 'Kuala Lumpur',
      description: 'Visit Kuala Lumpur.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/my_kuala_lumpur.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kuala Lumpur'},
    ),
    Achievement(
      id: 'my_malacca',
      requiresSubscription: true,
      name: 'Malacca',
      description: 'Visit Malacca.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/my_malacca.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Malacca'},
    ),
    Achievement(
      id: 'vn_hanoi',
      name: 'Hanoi',
      description: 'Visit Hanoi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/vn_hanoi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Hanoi'},
    ),
    Achievement(
      id: 'vn_ho_chi_minh_city',
      requiresSubscription: true,
      name: 'Ho Chi Minh City',
      description: 'Visit Ho Chi Minh City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/vn_ho_chi_minh_city.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ho Chi Minh City'},
    ),
    Achievement(
      id: 'vn_hoi_an',
      requiresSubscription: true,
      name: 'Hoi An',
      description: 'Visit Hoi An.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/vn_hoi_an.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Hoi An'},
    ),
    Achievement(
      id: 'vn_da_nang',
      requiresSubscription: true,
      name: 'Da Nang',
      description: 'Visit Da Nang.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/vn_da_nang.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Da Nang'},
    ),
    Achievement(
      id: 'mm_yangon',
      requiresSubscription: true,
      name: 'Yangon',
      description: 'Visit Yangon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mm_yangon.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Yangon'},
    ),
    Achievement(
      id: 'la_vientiane',
      requiresSubscription: true,
      name: 'Vientiane',
      description: 'Visit Vientiane.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/la_vientiane.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Vientiane'},
    ),
    Achievement(
      id: 'la_luang_prabang',
      requiresSubscription: true,
      name: 'Luang Prabang',
      description: 'Visit Luang Prabang.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/la_luang_prabang.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Luang Prabang'},
    ),
    Achievement(
      id: 'kh_phnom_penh',
      requiresSubscription: true,
      name: 'Phnom Penh',
      description: 'Visit Phnom Penh.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kh_phnom_penh.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Phnom Penh'},
    ),
    Achievement(
      id: 'kh_siem_reap',
      requiresSubscription: true,
      name: 'Siem Reap',
      description: 'Visit Siem Reap.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kh_siem_reap.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Siem Reap'},
    ),
    Achievement(
      id: 'ph_manila',
      requiresSubscription: true,
      name: 'Manila',
      description: 'Visit Manila.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ph_manila.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Manila'},
    ),
    Achievement(
      id: 'ph_cebu_city',
      requiresSubscription: true,
      name: 'Cebu City',
      description: 'Visit Cebu City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ph_cebu_city.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cebu City'},
    ),
    Achievement(
      id: 'id_jakarta',
      requiresSubscription: true,
      name: 'Jakarta',
      description: 'Visit Jakarta.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/id_jakarta.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Jakarta'},
    ),
    Achievement(
      id: 'id_ubud',
      requiresSubscription: true,
      name: 'Ubud',
      description: 'Visit Ubud.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/id_ubud.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ubud'},
    ),
    Achievement(
      id: 'in_delhi',
      name: 'Delhi',
      description: 'Visit Delhi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/in_delhi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Delhi'},
    ),
    Achievement(
      id: 'in_mumbai',
      requiresSubscription: true,
      name: 'Mumbai',
      description: 'Visit Mumbai.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/in_mumbai.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Mumbai'},
    ),
    Achievement(
      id: 'in_varanasi',
      requiresSubscription: true,
      name: 'Varanasi',
      description: 'Visit Varanasi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/in_varanasi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Varanasi'},
    ),
    Achievement(
      id: 'in_agra',
      requiresSubscription: true,
      name: 'Agra',
      description: 'Visit Agra.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/in_agra.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Agra'},
    ),
    Achievement(
      id: 'in_jaipur',
      requiresSubscription: true,
      name: 'Jaipur',
      description: 'Visit Jaipur.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/in_jaipur.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Jaipur'},
    ),
    Achievement(
      id: 'lk_colombo',
      requiresSubscription: true,
      name: 'Colombo',
      description: 'Visit Colombo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/lk_colombo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Colombo'},
    ),
    Achievement(
      id: 'pk_lahore',
      requiresSubscription: true,
      name: 'Lahore',
      description: 'Visit Lahore.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pk_lahore.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Lahore'},
    ),
    Achievement(
      id: 'np_kathmandu',
      requiresSubscription: true,
      name: 'Kathmandu',
      description: 'Visit Kathmandu.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/np_kathmandu.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kathmandu'},
    ),
    Achievement(
      id: 'np_pokhara',
      requiresSubscription: true,
      name: 'Pokhara',
      description: 'Visit Pokhara.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/np_pokhara.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Pokhara'},
    ),
    Achievement(
      id: 'kz_almaty',
      requiresSubscription: true,
      name: 'Almaty',
      description: 'Visit Almaty.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/kz_almaty.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Almaty'},
    ),
    Achievement(
      id: 'uz_tashkent',
      requiresSubscription: true,
      name: 'Tashkent',
      description: 'Visit Tashkent.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/uz_tashkent.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tashkent'},
    ),
    Achievement(
      id: 'uz_samarkand',
      requiresSubscription: true,
      name: 'Samarkand',
      description: 'Visit Samarkand.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/uz_samarkand.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Samarkand'},
    ),
    Achievement(
      id: 'tr_istanbul',
      name: 'Istanbul',
      description: 'Visit Istanbul.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tr_istanbul.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Istanbul'},
    ),
    Achievement(
      id: 'tr_antalya',
      requiresSubscription: true,
      name: 'Antalya',
      description: 'Visit Antalya.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tr_antalya.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Antalya'},
    ),
    Achievement(
      id: 'tr_ankara',
      requiresSubscription: true,
      name: 'Ankara',
      description: 'Visit Ankara.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tr_ankara.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ankara'},
    ),
    Achievement(
      id: 'tr_bursa',
      requiresSubscription: true,
      name: 'Bursa',
      description: 'Visit Bursa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tr_bursa.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bursa'},
    ),
    Achievement(
      id: 'tr_izmir',
      requiresSubscription: true,
      name: 'İzmir',
      description: 'Visit İzmir.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tr_izmir.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'İzmir'},
    ),
    Achievement(
      id: 'il_tel_aviv',
      requiresSubscription: true,
      name: 'Tel Aviv',
      description: 'Visit Tel Aviv.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/il_tel_aviv.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tel Aviv'},
    ),
    Achievement(
      id: 'il_jerusalem',
      requiresSubscription: true,
      name: 'Jerusalem',
      description: 'Visit Jerusalem.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/il_jerusalem.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Jerusalem'},
    ),
    Achievement(
      id: 'jo_amman',
      requiresSubscription: true,
      name: 'Amman',
      description: 'Visit Amman.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/jo_amman.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Amman'},
    ),
    Achievement(
      id: 'ir_tehran',
      requiresSubscription: true,
      name: 'Tehran',
      description: 'Visit Tehran.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ir_tehran.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tehran'},
    ),
    Achievement(
      id: 'ir_isfahan',
      requiresSubscription: true,
      name: 'Isfahan',
      description: 'Visit Isfahan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ir_isfahan.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Isfahan'},
    ),
    Achievement(
      id: 'ae_dubai',
      requiresSubscription: true,
      name: 'Dubai',
      description: 'Visit Dubai.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ae_dubai.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Dubai'},
    ),
    Achievement(
      id: 'ae_abu_dhabi',
      requiresSubscription: true,
      name: 'Abu Dhabi',
      description: 'Visit Abu Dhabi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ae_abu_dhabi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Abu Dhabi'},
    ),
    Achievement(
      id: 'ge_tbilisi',
      requiresSubscription: true,
      name: 'Tbilisi',
      description: 'Visit Tbilisi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ge_tbilisi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tbilisi'},
    ),
    Achievement(
      id: 'om_muscat',
      requiresSubscription: true,
      name: 'Muscat',
      description: 'Visit Muscat.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/om_muscat.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Muscat'},
    ),
    Achievement(
      id: 'sa_riyadh',
      requiresSubscription: true,
      name: 'Riyadh',
      description: 'Visit Riyadh.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sa_riyadh.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Riyadh'},
    ),
    Achievement(
      id: 'sa_mecca',
      requiresSubscription: true,
      name: 'Mecca',
      description: 'Visit Mecca.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sa_mecca.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Mecca'},
    ),
    Achievement(
      id: 'sa_madinah',
      requiresSubscription: true,
      name: 'Madinah',
      description: 'Visit Madinah.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sa_madinah.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Madinah'},
    ),
    Achievement(
      id: 'am_yerevan',
      requiresSubscription: true,
      name: 'Yerevan',
      description: 'Visit Yerevan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/am_yerevan.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Yerevan'},
    ),
    Achievement(
      id: 'az_baku',
      requiresSubscription: true,
      name: 'Baku',
      description: 'Visit Baku.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/az_baku.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Baku'},
    ),
    Achievement(
      id: 'qa_doha',
      requiresSubscription: true,
      name: 'Doha',
      description: 'Visit Doha.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/qa_doha.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Doha'},
    ),
    Achievement(
      id: 'au_sydney',
      name: 'Sydney',
      description: 'Visit Sydney.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/au_sydney.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Sydney'},
    ),
    Achievement(
      id: 'au_melbourne',
      requiresSubscription: true,
      name: 'Melbourne',
      description: 'Visit Melbourne.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/au_melbourne.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Melbourne'},
    ),
    Achievement(
      id: 'au_perth',
      requiresSubscription: true,
      name: 'Perth',
      description: 'Visit Perth.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/au_perth.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Perth'},
    ),
    Achievement(
      id: 'au_brisbane',
      requiresSubscription: true,
      name: 'Brisbane',
      description: 'Visit Brisbane.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/au_brisbane.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Brisbane'},
    ),
    Achievement(
      id: 'nz_auckland',
      requiresSubscription: true,
      name: 'Auckland',
      description: 'Visit Auckland.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/nz_auckland.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Auckland'},
    ),
    Achievement(
      id: 'nz_queenstown',
      requiresSubscription: true,
      name: 'Queenstown',
      description: 'Visit Queenstown.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/nz_queenstown.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Queenstown'},
    ),
    Achievement(
      id: 'nz_wellington',
      requiresSubscription: true,
      name: 'Wellington',
      description: 'Visit Wellington.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/nz_wellington.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Wellington'},
    ),
    Achievement(
      id: 'eg_cairo',
      requiresSubscription: true,
      name: 'Cairo',
      description: 'Visit Cairo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/eg_cairo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cairo'},
    ),
    Achievement(
      id: 'eg_luxor',
      requiresSubscription: true,
      name: 'Luxor',
      description: 'Visit Luxor.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/eg_luxor.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Luxor'},
    ),
    Achievement(
      id: 'eg_alexandria',
      requiresSubscription: true,
      name: 'Alexandria',
      description: 'Visit Alexandria.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/eg_alexandria.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Alexandria'},
    ),
    Achievement(
      id: 'ma_marrakesh',
      requiresSubscription: true,
      name: 'Marrakesh',
      description: 'Visit Marrakesh.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ma_marrakesh.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Marrakesh'},
    ),
    Achievement(
      id: 'ma_fes',
      requiresSubscription: true,
      name: 'Fes',
      description: 'Visit Fes.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ma_fes.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Fes'},
    ),
    Achievement(
      id: 'ma_casablanca',
      requiresSubscription: true,
      name: 'Casablanca',
      description: 'Visit Casablanca.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ma_casablanca.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Casablanca'},
    ),
    Achievement(
      id: 'tn_tunis',
      requiresSubscription: true,
      name: 'Tunis',
      description: 'Visit Tunis.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tn_tunis.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tunis'},
    ),
    Achievement(
      id: 'ke_nairobi',
      requiresSubscription: true,
      name: 'Nairobi',
      description: 'Visit Nairobi.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ke_nairobi.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Nairobi'},
    ),
    Achievement(
      id: 'ke_mombasa',
      requiresSubscription: true,
      name: 'Mombasa',
      description: 'Visit Mombasa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ke_mombasa.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Mombasa'},
    ),
    Achievement(
      id: 'tz_zanzibar',
      requiresSubscription: true,
      name: 'Zanzibar',
      description: 'Visit Zanzibar.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/tz_zanzibar.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Zanzibar'},
    ),
    Achievement(
      id: 'et_addis_ababa',
      requiresSubscription: true,
      name: 'Addis Ababa',
      description: 'Visit Addis Ababa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/et_addis_ababa.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Addis Ababa'},
    ),
    Achievement(
      id: 'sn_dakar',
      requiresSubscription: true,
      name: 'Dakar',
      description: 'Visit Dakar.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sn_dakar.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Dakar'},
    ),
    Achievement(
      id: 'gh_accra',
      requiresSubscription: true,
      name: 'Accra',
      description: 'Visit Accra.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gh_accra.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Accra'},
    ),
    Achievement(
      id: 'ng_lagos',
      requiresSubscription: true,
      name: 'Lagos',
      description: 'Visit Lagos.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ng_lagos.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Lagos'},
    ),
    Achievement(
      id: 'za_cape_town',
      requiresSubscription: true,
      name: 'Cape Town',
      description: 'Visit Cape Town.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/za_cape_town.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cape Town'},
    ),
    Achievement(
      id: 'za_johannesburg',
      requiresSubscription: true,
      name: 'Johannesburg',
      description: 'Visit Johannesburg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/za_johannesburg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Johannesburg'},
    ),
    Achievement(
      id: 'us_new_york_city',
      requiresSubscription: true,
      name: 'New York City',
      description: 'Visit New York City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_new_york_city.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'New York City'},
    ),
    Achievement(
      id: 'us_los_angeles',
      requiresSubscription: true,
      name: 'Los Angeles',
      description: 'Visit Los Angeles.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_los_angeles.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Los Angeles'},
    ),
    Achievement(
      id: 'us_san_francisco',
      requiresSubscription: true,
      name: 'San Francisco',
      description: 'Visit San Francisco.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_san_francisco.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'San Francisco'},
    ),
    Achievement(
      id: 'us_chicago',
      requiresSubscription: true,
      name: 'Chicago',
      description: 'Visit Chicago.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_chicago.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Chicago'},
    ),
    Achievement(
      id: 'us_washington_d_c',
      requiresSubscription: true,
      name: 'Washington D.C.',
      description: 'Visit Washington D.C..',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_washington_d_c.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Washington D.C.'},
    ),
    Achievement(
      id: 'us_philadelphia',
      requiresSubscription: true,
      name: 'Philadelphia',
      description: 'Visit Philadelphia.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_philadelphia.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Philadelphia'},
    ),
    Achievement(
      id: 'us_las_vegas',
      requiresSubscription: true,
      name: 'Las Vegas',
      description: 'Visit Las Vegas.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_las_vegas.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Las Vegas'},
    ),
    Achievement(
      id: 'us_miami',
      requiresSubscription: true,
      name: 'Miami',
      description: 'Visit Miami.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_miami.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Miami'},
    ),
    Achievement(
      id: 'us_new_orleans',
      requiresSubscription: true,
      name: 'New Orleans',
      description: 'Visit New Orleans.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_new_orleans.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'New Orleans'},
    ),
    Achievement(
      id: 'us_boston',
      requiresSubscription: true,
      name: 'Boston',
      description: 'Visit Boston.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_boston.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Boston'},
    ),
    Achievement(
      id: 'us_seattle',
      requiresSubscription: true,
      name: 'Seattle',
      description: 'Visit Seattle.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_seattle.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Seattle'},
    ),
    Achievement(
      id: 'us_honolulu',
      requiresSubscription: true,
      name: 'Honolulu',
      description: 'Visit Honolulu.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/us_honolulu.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Honolulu'},
    ),
    Achievement(
      id: 'ca_toronto',
      requiresSubscription: true,
      name: 'Toronto',
      description: 'Visit Toronto.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ca_toronto.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Toronto'},
    ),
    Achievement(
      id: 'ca_vancouver',
      requiresSubscription: true,
      name: 'Vancouver',
      description: 'Visit Vancouver.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ca_vancouver.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Vancouver'},
    ),
    Achievement(
      id: 'ca_quebec',
      requiresSubscription: true,
      name: 'Québec',
      description: 'Visit Québec.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ca_quebec.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Québec'},
    ),
    Achievement(
      id: 'ca_montreal',
      requiresSubscription: true,
      name: 'Montreal',
      description: 'Visit Montreal.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ca_montreal.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Montreal'},
    ),
    Achievement(
      id: 'mx_mexico_city',
      requiresSubscription: true,
      name: 'Mexico City',
      description: 'Visit Mexico City.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mx_mexico_city.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Mexico City'},
    ),
    Achievement(
      id: 'mx_cancun',
      requiresSubscription: true,
      name: 'Cancún',
      description: 'Visit Cancún.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mx_cancun.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cancún'},
    ),
    Achievement(
      id: 'cu_havana',
      requiresSubscription: true,
      name: 'Havana',
      description: 'Visit Havana.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cu_havana.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Havana'},
    ),
    Achievement(
      id: 'pa_panama',
      requiresSubscription: true,
      name: 'Panamá',
      description: 'Visit Panamá.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pa_panama.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Panamá'},
    ),
    Achievement(
      id: 'br_rio_de_janeiro',
      requiresSubscription: true,
      name: 'Rio de Janeiro',
      description: 'Visit Rio de Janeiro.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/br_rio_de_janeiro.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Rio de Janeiro'},
    ),
    Achievement(
      id: 'br_sao_paulo',
      requiresSubscription: true,
      name: 'São Paulo',
      description: 'Visit São Paulo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/br_sao_paulo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'São Paulo'},
    ),
    Achievement(
      id: 'ar_buenos_aires',
      requiresSubscription: true,
      name: 'Buenos Aires',
      description: 'Visit Buenos Aires.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ar_buenos_aires.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Buenos Aires'},
    ),
    Achievement(
      id: 'ar_mendoza',
      requiresSubscription: true,
      name: 'Mendoza',
      description: 'Visit Mendoza.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ar_mendoza.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Mendoza'},
    ),
    Achievement(
      id: 'pe_lima',
      requiresSubscription: true,
      name: 'Lima',
      description: 'Visit Lima.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pe_lima.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Lima'},
    ),
    Achievement(
      id: 'pe_cusco',
      requiresSubscription: true,
      name: 'Cusco',
      description: 'Visit Cusco.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pe_cusco.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cusco'},
    ),
    Achievement(
      id: 'cl_santiago',
      requiresSubscription: true,
      name: 'Santiago',
      description: 'Visit Santiago.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cl_santiago.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Santiago'},
    ),
    Achievement(
      id: 'co_bogota',
      requiresSubscription: true,
      name: 'Bogotá',
      description: 'Visit Bogotá.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/co_bogota.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bogotá'},
    ),
    Achievement(
      id: 'co_cartagena',
      requiresSubscription: true,
      name: 'Cartagena',
      description: 'Visit Cartagena.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/co_cartagena.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Cartagena'},
    ),
    Achievement(
      id: 'ec_quito',
      requiresSubscription: true,
      name: 'Quito',
      description: 'Visit Quito.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ec_quito.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Quito'},
    ),
    Achievement(
      id: 'bo_la_paz',
      requiresSubscription: true,
      name: 'La Paz',
      description: 'Visit La Paz.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/bo_la_paz.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'La Paz'},
    ),
    Achievement(
      id: 'uy_montevideo',
      requiresSubscription: true,
      name: 'Montevideo',
      description: 'Visit Montevideo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/uy_montevideo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Montevideo'},
    ),
    Achievement(
      id: 'gb_london',
      name: 'London',
      description: 'Visit London.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gb_london.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'London'},
    ),
    Achievement(
      id: 'gb_edinburgh',
      requiresSubscription: true,
      name: 'Edinburgh',
      description: 'Visit Edinburgh.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gb_edinburgh.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Edinburgh'},
    ),
    Achievement(
      id: 'gb_liverpool',
      requiresSubscription: true,
      name: 'Liverpool',
      description: 'Visit Liverpool.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gb_liverpool.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Liverpool'},
    ),
    Achievement(
      id: 'ie_dublin',
      requiresSubscription: true,
      name: 'Dublin',
      description: 'Visit Dublin.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ie_dublin.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Dublin'},
    ),
    Achievement(
      id: 'fr_paris',
      name: 'Paris',
      description: 'Visit Paris.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/fr_paris.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Paris'},
    ),
    Achievement(
      id: 'fr_avignon',
      requiresSubscription: true,
      name: 'Avignon',
      description: 'Visit Avignon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/fr_avignon.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Avignon'},
    ),
    Achievement(
      id: 'fr_nice',
      requiresSubscription: true,
      name: 'Nice',
      description: 'Visit Nice.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/fr_nice.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Nice'},
    ),
    Achievement(
      id: 'fr_strasbourg',
      requiresSubscription: true,
      name: 'Strasbourg',
      description: 'Visit Strasbourg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/fr_strasbourg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Strasbourg'},
    ),
    Achievement(
      id: 'nl_amsterdam',
      requiresSubscription: true,
      name: 'Amsterdam',
      description: 'Visit Amsterdam.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/nl_amsterdam.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Amsterdam'},
    ),
    Achievement(
      id: 'be_brussels',
      requiresSubscription: true,
      name: 'Brussels',
      description: 'Visit Brussels.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/be_brussels.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Brussels'},
    ),
    Achievement(
      id: 'be_bruges',
      requiresSubscription: true,
      name: 'Bruges',
      description: 'Visit Bruges.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/be_bruges.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bruges'},
    ),
    Achievement(
      id: 'at_vienna',
      requiresSubscription: true,
      name: 'Vienna',
      description: 'Visit Vienna.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/at_vienna.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Vienna'},
    ),
    Achievement(
      id: 'at_salzburg',
      requiresSubscription: true,
      name: 'Salzburg',
      description: 'Visit Salzburg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/at_salzburg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Salzburg'},
    ),
    Achievement(
      id: 'de_berlin',
      name: 'Berlin',
      description: 'Visit Berlin.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/de_berlin.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Berlin'},
    ),
    Achievement(
      id: 'de_munich',
      requiresSubscription: true,
      name: 'Munich',
      description: 'Visit Munich.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/de_munich.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Munich'},
    ),
    Achievement(
      id: 'de_heidelberg',
      requiresSubscription: true,
      name: 'Heidelberg',
      description: 'Visit Heidelberg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/de_heidelberg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Heidelberg'},
    ),
    Achievement(
      id: 'de_koln',
      requiresSubscription: true,
      name: 'Köln',
      description: 'Visit Köln.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/de_koln.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Köln'},
    ),
    Achievement(
      id: 'de_dresden',
      requiresSubscription: true,
      name: 'Dresden',
      description: 'Visit Dresden.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/de_dresden.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Dresden'},
    ),
    Achievement(
      id: 'ch_zurich',
      requiresSubscription: true,
      name: 'Zurich',
      description: 'Visit Zurich.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ch_zurich.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Zurich'},
    ),
    Achievement(
      id: 'ch_geneva',
      requiresSubscription: true,
      name: 'Geneva',
      description: 'Visit Geneva.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ch_geneva.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Geneva'},
    ),
    Achievement(
      id: 'lu_luxembourg',
      requiresSubscription: true,
      name: 'Luxembourg',
      description: 'Visit Luxembourg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/lu_luxembourg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Luxembourg'},
    ),
    Achievement(
      id: 'dk_copenhagen',
      requiresSubscription: true,
      name: 'Copenhagen',
      description: 'Visit Copenhagen.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/dk_copenhagen.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Copenhagen'},
    ),
    Achievement(
      id: 'se_stockholm',
      requiresSubscription: true,
      name: 'Stockholm',
      description: 'Visit Stockholm.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/se_stockholm.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Stockholm'},
    ),
    Achievement(
      id: 'se_goteborg',
      requiresSubscription: true,
      name: 'Göteborg',
      description: 'Visit Göteborg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/se_goteborg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Göteborg'},
    ),
    Achievement(
      id: 'no_oslo',
      requiresSubscription: true,
      name: 'Oslo',
      description: 'Visit Oslo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/no_oslo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Oslo'},
    ),
    Achievement(
      id: 'no_tromso',
      requiresSubscription: true,
      name: 'Tromsø',
      description: 'Visit Tromsø.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/no_tromso.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tromsø'},
    ),
    Achievement(
      id: 'no_bergen',
      requiresSubscription: true,
      name: 'Bergen',
      description: 'Visit Bergen.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/no_bergen.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bergen'},
    ),
    Achievement(
      id: 'fi_helsinki',
      requiresSubscription: true,
      name: 'Helsinki',
      description: 'Visit Helsinki.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/fi_helsinki.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Helsinki'},
    ),
    Achievement(
      id: 'is_reykjavik',
      requiresSubscription: true,
      name: 'Reykjavík',
      description: 'Visit Reykjavík.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/is_reykjavik.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Reykjavík'},
    ),
    Achievement(
      id: 'ee_tallinn',
      requiresSubscription: true,
      name: 'Tallinn',
      description: 'Visit Tallinn.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ee_tallinn.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Tallinn'},
    ),
    Achievement(
      id: 'lv_riga',
      requiresSubscription: true,
      name: 'Riga',
      description: 'Visit Riga.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/lv_riga.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Riga'},
    ),
    Achievement(
      id: 'lt_vilnius',
      requiresSubscription: true,
      name: 'Vilnius',
      description: 'Visit Vilnius.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/lt_vilnius.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Vilnius'},
    ),
    Achievement(
      id: 'it_rome',
      name: 'Rome',
      description: 'Visit Rome.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_rome.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Rome'},
    ),
    Achievement(
      id: 'it_venice',
      requiresSubscription: true,
      name: 'Venice',
      description: 'Visit Venice.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_venice.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Venice'},
    ),
    Achievement(
      id: 'it_florence',
      requiresSubscription: true,
      name: 'Florence',
      description: 'Visit Florence.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_florence.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Florence'},
    ),
    Achievement(
      id: 'it_milan',
      requiresSubscription: true,
      name: 'Milan',
      description: 'Visit Milan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_milan.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Milan'},
    ),
    Achievement(
      id: 'it_naples',
      requiresSubscription: true,
      name: 'Naples',
      description: 'Visit Naples.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_naples.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Naples'},
    ),
    Achievement(
      id: 'it_bologna',
      requiresSubscription: true,
      name: 'Bologna',
      description: 'Visit Bologna.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/it_bologna.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bologna'},
    ),
    Achievement(
      id: 'es_barcelona',
      name: 'Barcelona',
      description: 'Visit Barcelona.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/es_barcelona.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Barcelona'},
    ),
    Achievement(
      id: 'es_madrid',
      requiresSubscription: true,
      name: 'Madrid',
      description: 'Visit Madrid.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/es_madrid.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Madrid'},
    ),
    Achievement(
      id: 'es_granada',
      requiresSubscription: true,
      name: 'Granada',
      description: 'Visit Granada.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/es_granada.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Granada'},
    ),
    Achievement(
      id: 'es_ibiza',
      requiresSubscription: true,
      name: 'Ibiza',
      description: 'Visit Ibiza.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/es_ibiza.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ibiza'},
    ),
    Achievement(
      id: 'es_sevilla',
      requiresSubscription: true,
      name: 'Sevilla',
      description: 'Visit Sevilla.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/es_sevilla.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Sevilla'},
    ),
    Achievement(
      id: 'pt_lisbon',
      requiresSubscription: true,
      name: 'Lisbon',
      description: 'Visit Lisbon.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pt_lisbon.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Lisbon'},
    ),
    Achievement(
      id: 'pt_sintra',
      requiresSubscription: true,
      name: 'Sintra',
      description: 'Visit Sintra.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pt_sintra.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Sintra'},
    ),
    Achievement(
      id: 'pt_porto',
      requiresSubscription: true,
      name: 'Porto',
      description: 'Visit Porto.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pt_porto.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Porto'},
    ),
    Achievement(
      id: 'gr_athens',
      requiresSubscription: true,
      name: 'Athens',
      description: 'Visit Athens.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gr_athens.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Athens'},
    ),
    Achievement(
      id: 'gr_thessaloniki',
      requiresSubscription: true,
      name: 'Thessaloniki',
      description: 'Visit Thessaloniki.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/gr_thessaloniki.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Thessaloniki'},
    ),
    Achievement(
      id: 'mt_valletta',
      requiresSubscription: true,
      name: 'Valletta',
      description: 'Visit Valletta.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/mt_valletta.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Valletta'},
    ),
    Achievement(
      id: 'hr_dubrovnik',
      requiresSubscription: true,
      name: 'Dubrovnik',
      description: 'Visit Dubrovnik.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/hr_dubrovnik.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Dubrovnik'},
    ),
    Achievement(
      id: 'hr_split',
      requiresSubscription: true,
      name: 'Split',
      description: 'Visit Split.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/hr_split.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Split'},
    ),
    Achievement(
      id: 'cz_prague',
      requiresSubscription: true,
      name: 'Prague',
      description: 'Visit Prague.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cz_prague.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Prague'},
    ),
    Achievement(
      id: 'cz_cesky_krumlov',
      requiresSubscription: true,
      name: 'Český Krumlov',
      description: 'Visit Český Krumlov.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/cz_cesky_krumlov.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Český Krumlov'},
    ),
    Achievement(
      id: 'hu_budapest',
      requiresSubscription: true,
      name: 'Budapest',
      description: 'Visit Budapest.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/hu_budapest.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Budapest'},
    ),
    Achievement(
      id: 'pl_warsaw',
      requiresSubscription: true,
      name: 'Warsaw',
      description: 'Visit Warsaw.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pl_warsaw.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Warsaw'},
    ),
    Achievement(
      id: 'pl_krakow',
      requiresSubscription: true,
      name: 'Kraków',
      description: 'Visit Kraków.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/pl_krakow.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kraków'},
    ),
    Achievement(
      id: 'si_ljubljana',
      requiresSubscription: true,
      name: 'Ljubljana',
      description: 'Visit Ljubljana.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/si_ljubljana.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Ljubljana'},
    ),
    Achievement(
      id: 'sk_bratislava',
      requiresSubscription: true,
      name: 'Bratislava',
      description: 'Visit Bratislava.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/sk_bratislava.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bratislava'},
    ),
    Achievement(
      id: 'ro_bucharest',
      requiresSubscription: true,
      name: 'Bucharest',
      description: 'Visit Bucharest.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ro_bucharest.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Bucharest'},
    ),
    Achievement(
      id: 'ro_brasov',
      requiresSubscription: true,
      name: 'Braşov',
      description: 'Visit Braşov.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ro_brasov.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Braşov'},
    ),
    Achievement(
      id: 'ba_sarajevo',
      requiresSubscription: true,
      name: 'Sarajevo',
      description: 'Visit Sarajevo.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ba_sarajevo.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Sarajevo'},
    ),
    Achievement(
      id: 'me_kotor',
      requiresSubscription: true,
      name: 'Kotor',
      description: 'Visit Kotor.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/me_kotor.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kotor'},
    ),
    Achievement(
      id: 'rs_belgrade',
      requiresSubscription: true,
      name: 'Belgrade',
      description: 'Visit Belgrade.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/rs_belgrade.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Belgrade'},
    ),
    Achievement(
      id: 'ru_moscow',
      name: 'Moscow',
      description: 'Visit Moscow.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ru_moscow.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Moscow'},
    ),
    Achievement(
      id: 'ru_saint_petersburg',
      requiresSubscription: true,
      name: 'Saint Petersburg',
      description: 'Visit Saint Petersburg.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ru_saint_petersburg.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Saint Petersburg'},
    ),
    Achievement(
      id: 'ru_kazan',
      requiresSubscription: true,
      name: 'Kazan',
      description: 'Visit Kazan.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ru_kazan.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kazan'},
    ),
    Achievement(
      id: 'ua_kyiv',
      requiresSubscription: true,
      name: 'Kyiv',
      description: 'Visit Kyiv.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ua_kyiv.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Kyiv'},
    ),
    Achievement(
      id: 'ua_lviv',
      requiresSubscription: true,
      name: 'Lviv',
      description: 'Visit Lviv.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ua_lviv.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Lviv'},
    ),
    Achievement(
      id: 'ua_odesa',
      requiresSubscription: true,
      name: 'Odesa',
      description: 'Visit Odesa.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/ua_odesa.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Odesa'},
    ),
    Achievement(
      id: 'by_minsk',
      requiresSubscription: true,
      name: 'Minsk',
      description: 'Visit Minsk.',
      difficulty: AchievementDifficulty.Rookie,
      points: 1,
      imagePath: 'assets/new_city_badges/by_minsk.png',
      category: AchievementCategory.City,
      targetIsoCodes: {'Minsk'},
    ),
  ];

  List<Achievement> get achievements => _achievements;

  List<Achievement> get newlyUnlockedAchievements => _newlyUnlocked;

  BadgeProvider() {
    _loadUnlockedBadges();
  }

  Future<void> _loadUnlockedBadges() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('[BadgeProvider] No user logged in, skipping badge load');
      return;
    }

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('badges')
          .doc('unlocked')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          // 뱃지 데이터 로드
          if (data['badgeIds'] is List) {
            final List<String> unlockedIds = List<String>.from(data['badgeIds']);
            for (var achievement in _achievements) {
              achievement.isUnlocked = unlockedIds.contains(achievement.id);
            }
          }
          // [추가] 저장된 랭크 데이터 로드
          if (data['currentRank'] != null) {
            _currentRank = data['currentRank'];
          }
          print('[BadgeProvider] Loaded badges and rank ($_currentRank) from Firestore');
        }
      }
      // 로드 완료 표시
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('[BadgeProvider] Error loading badges: $e');
      _isInitialized = true; // 에러가 나도 초기화 시도는 끝난 것으로 간주
    }
  }

  Future<void> _saveUnlockedBadges() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('[BadgeProvider] No user, cannot save badges');
      return;
    }

    try {
      final unlockedIds = _achievements
          .where((a) => a.isUnlocked)
          .map((a) => a.id)
          .toList();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('badges')
          .doc('unlocked')
          .set({
        'badgeIds': unlockedIds,
        'currentRank': _currentRank, // [추가] 현재 랭크도 저장
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[BadgeProvider] Saved ${unlockedIds.length} badges and rank ($_currentRank) to Firestore');
    } catch (e) {
      print('[BadgeProvider] Error saving badges: $e');
    }
  }

  String? getAttributeForAchievement(String achievementId) {
    switch (achievementId) {
      case 'museums_10':
        return 'Museum';
      case 'castles_10':
        return 'Castle';
      case 'palaces_10':
        return 'Palace';
      case 'arches_10':
        return 'Gate';
      case 'christian_10':
        return 'Christian';
      case 'islamic_10':
        return 'Islamic';
      case 'buddhist_10':
        return 'Buddhist';
      case 'hindu_10':
        return 'Hindu';
      default:
        return null;
    }
  }

  Map<String, int> getAchievementProgress(
      Achievement achievement,
      Set<String> visitedIsos,
      List<Country> allCountries,
      List<EconomyData> allEconomyData,
      {Set<String>? visitedCities,
        List<City>? allCities,
        int? totalFlights,
        Set<String>? visitedAirlines,
        Set<String>? visitedAirlineNames,
        Set<String>? visitedAirlineCode3s, // [중요] 3자리 ICAO 코드 확인용
        Set<String>? visitedAirports,
        Set<String>? visitedLandmarks,
        List<Landmark>? allLandmarks,
        dynamic unescoProvider}
      ) {
    if (achievement.requiresHome || achievement.requiresRating ||
        achievement.requiresCulturalLandmark || achievement.requiresNaturalLandmark ||
        achievement.requiresAirportRating || achievement.requiresAirportHub ||
        achievement.requiresAirlineRating || achievement.requiresBusinessClass ||
        achievement.requiresFirstClass) {
      return {
        'current': achievement.isUnlocked ? 1 : 0,
        'total': 1,
      };
    }

    if (achievement.requiresLandmarkCount != null) {
      final current = visitedLandmarks?.length ?? 0;
      return {
        'current': min(current, achievement.requiresLandmarkCount!),
        'total': achievement.requiresLandmarkCount!,
      };
    }

    if (achievement.id == 'unesco_100' || achievement.requiresUnescoCount != null) {
      int current = 0;
      int total = achievement.requiresUnescoCount ?? achievement.targetCount ?? 100;

      if (unescoProvider != null && unescoProvider is UnescoProvider) {
        final List<UnescoSite> allSites = unescoProvider.allSites;
        if (achievement.requiresCulturalUnescoSite) {
          current = unescoProvider.visitedSites.where((siteName) {
            final site = allSites.firstWhereOrNull((s) => s.name == siteName);
            return site != null && site.type == 'Cultural';
          }).length;
        } else if (achievement.requiresNaturalUnescoSite) {
          current = unescoProvider.visitedSites.where((siteName) {
            final site = allSites.firstWhereOrNull((s) => s.name == siteName);
            return site != null && (site.type == 'Natural' || site.type == 'Mixed');
          }).length;
        } else {
          current = unescoProvider.visitedSites.length;
        }
      }
      return {
        'current': min(current, total),
        'total': total,
      };
    }

    if (achievement.category == AchievementCategory.Flight) {
      if (achievement.id == 'top10_airports' && achievement.targetIsoCodes != null) {
        if (visitedAirports != null) {
          final visitedTargets = visitedAirports.intersection(achievement.targetIsoCodes!);
          return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
        }
        return {'current': 0, 'total': achievement.targetIsoCodes!.length};
      }
      if (achievement.id == 'top10_airlines' && achievement.targetIsoCodes != null) {
        if (visitedAirlines != null) {
          final visitedTargets = visitedAirlines.intersection(achievement.targetIsoCodes!);
          return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
        }
        return {'current': 0, 'total': achievement.targetIsoCodes!.length};
      }
      if (achievement.id.startsWith('airline_') && achievement.targetIsoCodes != null) {
        if (visitedAirlines != null) {
          final visitedTargets = visitedAirlines.intersection(achievement.targetIsoCodes!);
          return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
        }
        return {'current': 0, 'total': achievement.targetIsoCodes!.length};
      }
      if (achievement.id.startsWith('airport_') && achievement.targetIsoCodes != null) {
        if (visitedAirports != null) {
          final visitedTargets = visitedAirports.intersection(achievement.targetIsoCodes!);
          return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
        }
        return {'current': 0, 'total': achievement.targetIsoCodes!.length};
      }
      if (achievement.id.startsWith('flights_') && achievement.targetCount != null) {
        return {'current': min(totalFlights ?? 0, achievement.targetCount!), 'total': achievement.targetCount!};
      }
      if (achievement.id.startsWith('airlines_') && achievement.targetCount != null) {
        return {'current': min(visitedAirlines?.length ?? 0, achievement.targetCount!), 'total': achievement.targetCount!};
      }
      if (achievement.id.startsWith('airports_') && achievement.targetCount != null) {
        return {'current': min(visitedAirports?.length ?? 0, achievement.targetCount!), 'total': achievement.targetCount!};
      }

      // [수정] 스카이팀, 원월드, 스타얼라이언스 로직 (Code3 기준 맵 사용)
      if (achievement.id == 'skyteam_20') {
        final totalInAlliance = airlineAllianceCodes.values.where((v) => v == 'SkyTeam').length;
        final count = visitedAirlineCode3s != null
            ? airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'SkyTeam' && visitedAirlineCode3s.contains(code3)).length
            : 0;
        return {'current': min(count, totalInAlliance), 'total': totalInAlliance};
      }
      if (achievement.id == 'oneworld_20') {
        final totalInAlliance = airlineAllianceCodes.values.where((v) => v == 'OneWorld').length;
        final count = visitedAirlineCode3s != null
            ? airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'OneWorld' && visitedAirlineCode3s.contains(code3)).length
            : 0;
        return {'current': min(count, totalInAlliance), 'total': totalInAlliance};
      }
      if (achievement.id == 'staralliance_20') {
        final totalInAlliance = airlineAllianceCodes.values.where((v) => v == 'Star Alliance').length;
        final count = visitedAirlineCode3s != null
            ? airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'Star Alliance' && visitedAirlineCode3s.contains(code3)).length
            : 0;
        return {'current': min(count, totalInAlliance), 'total': totalInAlliance};
      }
    }

    if (achievement.category == AchievementCategory.Landmarks) {
      if (achievement.targetCount != null) {
        final attribute = getAttributeForAchievement(achievement.id);

        if (attribute == null && achievement.targetIsoCodes != null && visitedLandmarks != null) {
          final visitedTargets = visitedLandmarks.intersection(achievement.targetIsoCodes!);
          return {
            'current': min(visitedTargets.length, achievement.targetCount!),
            'total': achievement.targetCount!,
          };
        }

        if (attribute != null && visitedLandmarks != null) {
          int matchedCount = 0;
          if (allLandmarks != null) {
            matchedCount = visitedLandmarks.where((visitedName) {
              final landmark = allLandmarks.firstWhereOrNull((l) => l.name == visitedName);
              return landmark != null && landmark.attributes.contains(attribute);
            }).length;
          } else {
            matchedCount = visitedLandmarks.length;
          }
          return {
            'current': min(matchedCount, achievement.targetCount!),
            'total': achievement.targetCount!,
          };
        }
        return {
          'current': 0,
          'total': achievement.targetCount!,
        };
      }

      if (achievement.targetIsoCodes != null) {
        if (visitedLandmarks != null && allLandmarks != null) {
          final dbLandmarkNames = allLandmarks.map((l) => l.name).toSet();
          final validTargets = achievement.targetIsoCodes!.intersection(dbLandmarkNames);
          final visitedTargets = visitedLandmarks.intersection(validTargets);

          return {
            'current': visitedTargets.length,
            'total': validTargets.length,
          };
        } else if (visitedLandmarks != null) {
          final visitedTargets = visitedLandmarks.intersection(achievement.targetIsoCodes!);
          return {
            'current': visitedTargets.length,
            'total': achievement.targetIsoCodes!.length,
          };
        }
        return {
          'current': 0,
          'total': achievement.targetIsoCodes?.length ?? 1,
        };
      }
    }

    if (achievement.category == AchievementCategory.City && achievement.targetIsoCodes != null) {
      if (visitedCities != null) {
        final visitedTargets = visitedCities.intersection(achievement.targetIsoCodes!);
        return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
      }
      return {'current': 0, 'total': achievement.targetIsoCodes!.length};
    }

    if (achievement.category == AchievementCategory.City && achievement.targetCount != null) {
      if (achievement.id == 'both_hemispheres') {
        if (visitedCities == null || allCities == null) return {'current': 0, 'total': 2};
        final hasNorthern = allCities.any((city) => city != null && visitedCities.contains(city.name) && city.latitude > 0);
        final hasSouthern = allCities.any((city) => city != null && visitedCities.contains(city.name) && city.latitude < 0);
        int count = 0;
        if (hasNorthern) count++;
        if (hasSouthern) count++;
        return {'current': count, 'total': 2};
      }
      if (achievement.id.startsWith('capitals_')) {
        if (visitedCities == null || allCities == null) return {'current': 0, 'total': achievement.targetCount!};
        final capitalCities = allCities.where((city) => city != null && city.capitalStatus != CapitalStatus.none).map((city) => city!.name).toSet();
        final visitedCapitals = visitedCities.intersection(capitalCities);
        return {'current': min(visitedCapitals.length, achievement.targetCount!), 'total': achievement.targetCount!};
      }
      if (achievement.id == 'north_60_latitude') {
        if (visitedCities == null || allCities == null) return {'current': 0, 'total': 1};
        final hasCity = allCities.any((city) => city != null && visitedCities.contains(city.name) && city.latitude >= 60);
        return {'current': hasCity ? 1 : 0, 'total': 1};
      }
      if (achievement.id == 'south_40_latitude') {
        if (visitedCities == null || allCities == null) return {'current': 0, 'total': 1};
        final hasCity = allCities.any((city) => city != null && visitedCities.contains(city.name) && city.latitude <= -40);
        return {'current': hasCity ? 1 : 0, 'total': 1};
      }
      return {'current': min(visitedCities?.length ?? 0, achievement.targetCount!), 'total': achievement.targetCount!};
    }

    if (achievement.targetCount != null) {
      if (achievement.category == AchievementCategory.Country) {
        if (achievement.id == 'africa_10' || achievement.id == 'africa_5') {
          final africaVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Africa').length;
          return {'current': min(africaVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'asia_20' || achievement.id == 'asia_10') {
          final asiaVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Asia').length;
          return {'current': min(asiaVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'europe_20' || achievement.id == 'europe_10') {
          final europeVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Europe').length;
          return {'current': min(europeVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'americas_10' || achievement.id == 'americas_5') {
          final americasVisited = visitedIsos.where((iso) {
            final c = allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first);
            return c.continent == 'North America' || c.continent == 'South America';
          }).length;
          return {'current': min(americasVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6' || achievement.id == 'continents_2' || achievement.id == 'continents_4' || achievement.id == 'continents_5') {
          final continents = <String>{};
          for (var iso in visitedIsos) {
            final country = allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first);
            if (country.continent != null) continents.add(country.continent!);
          }
          return {'current': min(continents.length, achievement.targetCount!), 'total': achievement.targetCount!};
        }
      }
      final current = min(visitedIsos.length, achievement.targetCount!);
      return {'current': current, 'total': achievement.targetCount!};
    }

    if (achievement.targetIsoCodes != null) {
      final visitedTargets = visitedIsos.intersection(achievement.targetIsoCodes!);
      return {'current': visitedTargets.length, 'total': achievement.targetIsoCodes!.length};
    }

    if (achievement.targetPopulationLimit != null) {
      if (allCountries.isEmpty) return {'current': 0, 'total': achievement.targetPopulationLimit!};
      final Map<String, int> populationMap = {for (var country in allCountries) country.isoA3: country.populationEst};
      final int visitedPopulation = visitedIsos.map((iso) => populationMap[iso] ?? 0).fold<int>(0, (prev, pop) => prev + pop);
      return {'current': visitedPopulation, 'total': achievement.targetPopulationLimit!};
    }
    if (achievement.targetAreaLimit != null) {
      if (allCountries.isEmpty) return {'current': 0, 'total': achievement.targetAreaLimit!};
      final Map<String, int> areaMap = {for (var country in allCountries) country.isoA3: country.area.toInt()};
      final int visitedArea = visitedIsos.map((iso) => areaMap[iso] ?? 0).fold<int>(0, (prev, area) => prev + area);
      return {'current': visitedArea, 'total': achievement.targetAreaLimit!};
    }
    if (achievement.targetGdpLimit != null) {
      if (allEconomyData.isEmpty) return {'current': 0, 'total': achievement.targetGdpLimit!.toInt()};
      final Map<String, double> gdpMap = {for (var e in allEconomyData) e.isoA3: e.gdpNominal};
      final double visitedGdp = visitedIsos.map((iso) => (gdpMap[iso] ?? 0.0) * _1e9).fold<double>(0.0, (prev, gdp) => prev + gdp);
      return {'current': visitedGdp.toInt(), 'total': achievement.targetGdpLimit!.toInt()};
    }

    return {'current': 0, 'total': 1};
  }

  void updateBadges(
      CountryProvider countryProvider,
      List<EconomyData> allEconomyData,
      {CityProvider? cityProvider,
        AirlineProvider? airlineProvider,
        AirportProvider? airportProvider,
        LandmarksProvider? landmarksProvider,
        dynamic unescoProvider}
      ) {

    if (landmarksProvider != null && !landmarksProvider.isLoading && !_hasDebuggedLandmarks) {
      debugCheckMissingLandmarks(landmarksProvider);
    }

    if (countryProvider.isLoading) return;
    if (allEconomyData.isEmpty) return;

    bool didChange = false;
    bool shouldSave = false;

    final visitedCountryIsos = countryProvider.visitedCountries
        .map((name) => countryProvider.countryNameToIsoMap[name])
        .where((iso) => iso != null)
        .cast<String>()
        .toSet();

    final visitedCities = cityProvider?.visitedCities.toSet() ?? <String>{};
    final allCities = cityProvider?.allCities ?? [];
    final totalFlights = airlineProvider?.allFlightLogs.fold<int>(0, (sum, log) => sum + log.times) ?? 0;

    final visitedAirlines = airlineProvider?.airlines.where((a) => a.totalTimes > 0).map((a) => a.code).toSet() ?? <String>{};
    final visitedAirlineNames = airlineProvider?.airlines.where((a) => a.totalTimes > 0).map((a) => a.name).toSet() ?? <String>{};
    // [유지] 방문한 항공사의 Code3 목록 추출 (null 제외)
    final visitedAirlineCode3s = airlineProvider?.airlines
        .where((a) => a.totalTimes > 0 && a.code3 != null)
        .map((a) => a.code3!)
        .toSet() ?? <String>{};

    final visitedAirports = airportProvider?.visitedAirports ?? <String>{};
    final visitedLandmarks = landmarksProvider?.visitedLandmarks ?? <String>{};
    final visitedUnesco = unescoProvider?.visitedSites.length ?? 0;
    final visitedCount = visitedCountryIsos.length;

    for (var achievement in _achievements) {
      bool requirementsMet = false;

      if (achievement.category == AchievementCategory.Country) {
        if (achievement.requiresHome) requirementsMet = countryProvider.homeCountryIsoA3 != null;
        if (achievement.requiresRating) requirementsMet = countryProvider.visitDetails.values.any((details) => details.rating != null && details.rating! > 0);
        if (achievement.targetIsoCodes != null) requirementsMet = visitedCountryIsos.containsAll(achievement.targetIsoCodes!);
        if (achievement.targetCount != null) {
          if (achievement.id == 'africa_10' || achievement.id == 'africa_5') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Africa').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'asia_20' || achievement.id == 'asia_10') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Asia').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'europe_20' || achievement.id == 'europe_10') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Europe').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'americas_10' || achievement.id == 'americas_5') {
            final count = visitedCountryIsos.where((iso) => (countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'North America' || countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'South America')).length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6' || achievement.id == 'continents_2' || achievement.id == 'continents_4' || achievement.id == 'continents_5') {
            final continents = <String>{};
            for (var iso in visitedCountryIsos) {
              final country = countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first);
              if (country.continent != null) continents.add(country.continent!);
            }
            requirementsMet = continents.length >= achievement.targetCount!;
          } else {
            requirementsMet = visitedCount >= achievement.targetCount!;
          }
        }
        if (achievement.targetPopulationLimit != null) {
          final Map<String, int> popMap = {for (var c in countryProvider.allCountries) c.isoA3: c.populationEst};
          final int visitedPop = visitedCountryIsos.map((iso) => popMap[iso] ?? 0).fold<int>(0, (prev, pop) => prev + pop);
          requirementsMet = visitedPop >= achievement.targetPopulationLimit!;
        }
        if (achievement.targetAreaLimit != null) {
          final Map<String, int> areaMap = {for (var c in countryProvider.allCountries) c.isoA3: c.area.toInt()};
          final int visitedArea = visitedCountryIsos.map((iso) => areaMap[iso] ?? 0).fold<int>(0, (prev, area) => prev + area);
          requirementsMet = visitedArea >= achievement.targetAreaLimit!;
        }
        if (achievement.targetGdpLimit != null) {
          final Map<String, double> gdpMap = {for (var e in allEconomyData) e.isoA3: e.gdpNominal};
          final double visitedGdp = visitedCountryIsos.map((iso) => (gdpMap[iso] ?? 0.0) * _1e9).fold<double>(0.0, (prev, gdp) => prev + gdp);
          requirementsMet = visitedGdp >= achievement.targetGdpLimit!;
        }
      }

      if (achievement.category == AchievementCategory.Flight) {
        if (achievement.requiresAirportRating && airportProvider != null) requirementsMet = airportProvider.allAirports.any((a) => airportProvider.getRating(a.iataCode) > 0);
        if (achievement.requiresAirportHub && airportProvider != null) requirementsMet = airportProvider.allAirports.any((a) => airportProvider.isHub(a.iataCode));
        if (achievement.requiresAirlineRating && airlineProvider != null) requirementsMet = airlineProvider.airlines.any((a) => a.rating > 0);
        if (achievement.requiresBusinessClass && airlineProvider != null) requirementsMet = airlineProvider.airlines.any((a) => a.logs.any((l) => l.seatClass?.toLowerCase().contains('business') ?? false));
        if (achievement.requiresFirstClass && airlineProvider != null) requirementsMet = airlineProvider.airlines.any((a) => a.logs.any((l) => l.seatClass?.toLowerCase().contains('first') ?? false));
        if (achievement.targetIsoCodes != null) {
          if (achievement.id == 'top10_airports') requirementsMet = visitedAirports.containsAll(achievement.targetIsoCodes!);
          if (achievement.id == 'top10_airlines') requirementsMet = visitedAirlines.containsAll(achievement.targetIsoCodes!);
          if (achievement.id.startsWith('airline_')) requirementsMet = visitedAirlines.containsAll(achievement.targetIsoCodes!);
          if (achievement.id.startsWith('airport_')) requirementsMet = visitedAirports.containsAll(achievement.targetIsoCodes!);
        }
        if (achievement.targetCount != null) {
          if (achievement.id.startsWith('flights_')) requirementsMet = totalFlights >= achievement.targetCount!;
          if (achievement.id.startsWith('airlines_')) requirementsMet = visitedAirlines.length >= achievement.targetCount!;
          if (achievement.id.startsWith('airports_')) requirementsMet = visitedAirports.length >= achievement.targetCount!;
        }
        // [수정] 연맹 뱃지 로직: visitedAirlineCode3s와 ICAO Code 맵 사용
        if (achievement.id == 'skyteam_20') {
          final total = airlineAllianceCodes.values.where((v) => v == 'SkyTeam').length;
          final count = airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'SkyTeam' && visitedAirlineCode3s.contains(code3)).length;
          requirementsMet = count >= total;
        }
        if (achievement.id == 'oneworld_20') {
          final total = airlineAllianceCodes.values.where((v) => v == 'OneWorld').length;
          final count = airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'OneWorld' && visitedAirlineCode3s.contains(code3)).length;
          requirementsMet = count >= total;
        }
        if (achievement.id == 'staralliance_20') {
          final total = airlineAllianceCodes.values.where((v) => v == 'Star Alliance').length;
          final count = airlineAllianceCodes.keys.where((code3) => airlineAllianceCodes[code3] == 'Star Alliance' && visitedAirlineCode3s.contains(code3)).length;
          requirementsMet = count >= total;
        }
      }

      if (achievement.category == AchievementCategory.Landmarks) {
        if (achievement.id == 'unesco_100') requirementsMet = visitedUnesco >= 100;

        if (unescoProvider != null && unescoProvider is UnescoProvider) {
          final List<UnescoSite> allSites = unescoProvider.allSites;
          if (achievement.id == 'cultural_heritage') {
            final culturalCount = unescoProvider.visitedSites.where((siteName) {
              final site = allSites.firstWhereOrNull((s) => s.name == siteName);
              return site != null && site.type == 'Cultural';
            }).length;
            requirementsMet = culturalCount >= 10;
          }
          if (achievement.id == 'natural_heritage') {
            final naturalCount = unescoProvider.visitedSites.where((siteName) {
              final site = allSites.firstWhereOrNull((s) => s.name == siteName);
              return site != null && (site.type == 'Natural' || site.type == 'Mixed');
            }).length;
            requirementsMet = naturalCount >= 10;
          }
        }

        if (achievement.targetIsoCodes != null) {
          if (achievement.targetCount != null) {
            requirementsMet = visitedLandmarks.intersection(achievement.targetIsoCodes!).length >= achievement.targetCount!;
          } else {
            requirementsMet = visitedLandmarks.containsAll(achievement.targetIsoCodes!);
          }
        }

        if (achievement.requiresCulturalLandmark && landmarksProvider != null) requirementsMet = landmarksProvider.allLandmarks.any((l) => l.visitDates.isNotEmpty && isCulturalLandmark(l.attributes));
        if (achievement.requiresNaturalLandmark && landmarksProvider != null) requirementsMet = landmarksProvider.allLandmarks.any((l) => l.visitDates.isNotEmpty && isNaturalLandmark(l.attributes));
        if (achievement.requiresRating && landmarksProvider != null) requirementsMet = landmarksProvider.allLandmarks.any((l) => l.visitDates.isNotEmpty && l.rating != null && l.rating! > 0);
        if (achievement.requiresLandmarkCount != null) requirementsMet = visitedLandmarks.length >= achievement.requiresLandmarkCount!;

        if (achievement.targetCount != null && landmarksProvider != null) {
          final String? attr = getAttributeForAchievement(achievement.id);
          if (attr != null) {
            final catSet = landmarksProvider.allLandmarks
                .where((l) => l.attributes.contains(attr))
                .map((l) => l.name)
                .toSet();
            requirementsMet = visitedLandmarks.intersection(catSet).length >= achievement.targetCount!;
          }
        }
      }

      if (achievement.category == AchievementCategory.City) {
        if (achievement.requiresHome && cityProvider != null) requirementsMet = cityProvider.visitDetails.values.any((d) => d.isHome);
        if (achievement.requiresRating && cityProvider != null) requirementsMet = cityProvider.visitDetails.values.any((d) => d.rating > 0);
        if (achievement.targetIsoCodes != null) requirementsMet = visitedCities.containsAll(achievement.targetIsoCodes!);
        if (achievement.targetCount != null && cityProvider != null) {
          if (achievement.id == 'both_hemispheres') {
            final hasN = cityProvider.allCities.any((c) => c != null && visitedCities.contains(c.name) && c.latitude > 0);
            final hasS = cityProvider.allCities.any((c) => c != null && visitedCities.contains(c.name) && c.latitude < 0);
            requirementsMet = hasN && hasS;
          } else if (achievement.id == 'north_60_latitude') {
            requirementsMet = cityProvider.allCities.any((c) => c != null && visitedCities.contains(c.name) && c.latitude >= 60);
          } else if (achievement.id == 'south_40_latitude') {
            requirementsMet = cityProvider.allCities.any((c) => c != null && visitedCities.contains(c.name) && c.latitude <= -40);
          } else if (achievement.id.startsWith('capitals_')) {
            final caps = cityProvider.allCities.where((c) => c != null && c.capitalStatus != CapitalStatus.none).map((c) => c!.name).toSet();
            requirementsMet = visitedCities.intersection(caps).length >= achievement.targetCount!;
          } else {
            requirementsMet = visitedCities.length >= achievement.targetCount!;
          }
        }
      }

      // [추가] conditionsMet은 구독 여부와 무관하게 실제 조건 충족 여부를 그대로 기록.
      // UI에서 "완료했지만 프리미엄 미구독이라 잠긴" 상태(반짝이는 컬러/흑백 전환)를
      // 구분할 때 이 값을 쓴다.
      final bool wasConditionsMet = achievement.conditionsMet;
      achievement.conditionsMet = requirementsMet;

      // [추가] 프리미엄 전용 뱃지는 조건을 채워도 구독 중이 아니면 실제로는 unlock되지 않는다.
      final bool effectiveUnlock = requirementsMet &&
          (!achievement.requiresSubscription || SubscriptionService.instance.isPremium);

      // [추가] 방금 막 조건을 다 채웠는데(직전엔 안 채워진 상태) 구독이 없어서 실제
      // unlock으로는 못 이어지는 경우 -> "완료했지만 구독 필요" 팝업용 큐에 적재.
      if (!wasConditionsMet && requirementsMet &&
          achievement.requiresSubscription && !effectiveUnlock) {
        _newlyPendingPremiumClaim.add(achievement);
      }

      bool previouslyUnlocked = achievement.isUnlocked;
      if (!previouslyUnlocked && effectiveUnlock) {
        achievement.isUnlocked = true;
        _newlyUnlocked.add(achievement);
        didChange = true;
        shouldSave = true;
      } else if (previouslyUnlocked && !effectiveUnlock) {
        achievement.isUnlocked = false;
        _newlyUnlocked.remove(achievement);
        didChange = true;
        shouldSave = true;
      }
    }

    // [복구] 랭크 시스템 계산 로직
    int totalPoints = _achievements.where((a) => a.isUnlocked).fold(0, (sum, a) => sum + a.points);
    String calculatedRank = _calculateRank(totalPoints);

    // [수정] 랭크가 오를 때 처리 (초기화 완료 후 진짜 상승시에만 팝업 허용)
    if (_getRankValue(calculatedRank) > _getRankValue(_currentRank)) {
      if (_isInitialized) {
        _newRankUnlocked = calculatedRank; // 이 값이 null이 아닐 때만 main.dart에서 팝업을 띄움
      }
      _currentRank = calculatedRank;
      didChange = true;
      shouldSave = true; // 랭크가 바뀌었으니 저장
    }

    if (shouldSave) _saveUnlockedBadges();
    if (didChange) notifyListeners();
  }

  void clearNewlyUnlocked() {
    _newlyUnlocked.clear();
    notifyListeners();
  }

  void clearNewlyPendingPremiumClaim() {
    _newlyPendingPremiumClaim.clear();
    notifyListeners();
  }

  void markPremiumClaimPromptSeen(Achievement achievement) {
    _newlyPendingPremiumClaim.remove(achievement);
    notifyListeners();
  }

  // [복구] 알림창 확인 처리 메서드
  void markBadgeAsSeen(Achievement achievement) {
    _newlyUnlocked.remove(achievement);
    notifyListeners();
  }

  // [복구] 랭크 알림 확인 처리 메서드
  void markRankAsSeen() {
    _newRankUnlocked = null;
    notifyListeners();
  }

  // [복구] 랭크 계산 메서드
  String _calculateRank(int points) {
    if (points >= 600) return 'Legend';
    if (points >= 400) return 'Worldmaster';
    if (points >= 200) return 'Globetrotter';
    if (points >= 100) return 'Adventurer';
    if (points >= 50) return 'Nomad';
    if (points >= 10) return 'Explorer';
    return 'Rookie';
  }

  // [복구] 랭크 비교를 위한 값 변환 메서드
  int _getRankValue(String rank) {
    switch (rank) {
      case 'Legend': return 6;
      case 'Worldmaster': return 5;
      case 'Globetrotter': return 4;
      case 'Adventurer': return 3;
      case 'Nomad': return 2;
      case 'Explorer': return 1;
      default: return 0;
    }
  }

  void debugCheckMissingLandmarks(LandmarksProvider landmarksProvider) {
    if (_hasDebuggedLandmarks) return;
    if (landmarksProvider.allLandmarks.isEmpty) return;
    final dbNames = landmarksProvider.allLandmarks.map((l) => l.name).toSet();
    int missingCount = 0;
    for (var achievement in _achievements) {
      if (achievement.category == AchievementCategory.Landmarks && achievement.targetIsoCodes != null) {
        List<String> missingItems = [];
        for (var targetName in achievement.targetIsoCodes!) {
          if (!dbNames.contains(targetName)) missingItems.add(targetName);
        }
        if (missingItems.isNotEmpty) {
          missingCount++;
        }
      }
    }
    _hasDebuggedLandmarks = true;
  }

  void debugForceUnlock() {
    if (_achievements.isNotEmpty) {
      _newlyUnlocked.add(_achievements.first);
      notifyListeners();
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    // 뱃지는 다른 Provider 상태로 재계산되므로 Firestore에서 잠금 상태만 재로드
    for (var a in _achievements) {
      a.isUnlocked = false;
    }
    _currentRank = 'Rookie';
    _newlyUnlocked.clear();
    _newRankUnlocked = null;
    await _loadUnlockedBadges();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveUnlockedBadges();
  }

}