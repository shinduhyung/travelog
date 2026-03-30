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
        if (achievement.id == 'africa_10') {
          final africaVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Africa').length;
          return {'current': min(africaVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'asia_20') {
          final asiaVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Asia').length;
          return {'current': min(asiaVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'europe_20') {
          final europeVisited = visitedIsos.where((iso) => allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first).continent == 'Europe').length;
          return {'current': min(europeVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'americas_10') {
          final americasVisited = visitedIsos.where((iso) {
            final c = allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => allCountries.first);
            return c.continent == 'North America' || c.continent == 'South America';
          }).length;
          return {'current': min(americasVisited, achievement.targetCount!), 'total': achievement.targetCount!};
        } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6') {
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
          if (achievement.id == 'africa_10') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Africa').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'asia_20') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Asia').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'europe_20') {
            final count = visitedCountryIsos.where((iso) => countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'Europe').length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'americas_10') {
            final count = visitedCountryIsos.where((iso) => (countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'North America' || countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso, orElse: () => countryProvider.allCountries.first).continent == 'South America')).length;
            requirementsMet = count >= achievement.targetCount!;
          } else if (achievement.id == 'continents_3' || achievement.id == 'continents_6') {
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

      bool previouslyUnlocked = achievement.isUnlocked;
      if (!previouslyUnlocked && requirementsMet) {
        achievement.isUnlocked = true;
        _newlyUnlocked.add(achievement);
        didChange = true;
        shouldSave = true;
      } else if (previouslyUnlocked && !requirementsMet) {
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