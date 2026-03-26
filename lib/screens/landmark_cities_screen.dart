// lib/screens/landmark_cities_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/screens/cities_screen.dart'; // showExternalCityDetailsModal

const Color _kTheme = Color(0xFF4A5568);

class LandmarkCitiesScreen extends StatelessWidget {
  const LandmarkCitiesScreen({super.key});

  String _getLandmarkImageUrl(String name) {
    final snake = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/city_landmark%2F$snake.png?alt=media';
  }

  static final List<Map<String, dynamic>> _citiesData = [
    { 'city': 'Paris', 'iso': 'FR', 'desc': 'The global center for art, fashion, gastronomy, and culture.', 'landmarks': [ 'Eiffel Tower', 'Louvre Museum', 'Notre-Dame de Paris', 'Arc de Triomphe', 'Sacré-Cœur Basilica', 'Musée d\'Orsay', 'Centre Pompidou' ] },
    { 'city': 'London', 'iso': 'GB', 'desc': 'A 21st-century city with history stretching back to Roman times.', 'landmarks': [ 'Big Ben', 'Tower of London', 'British Museum', 'Buckingham Palace', 'Westminster Abbey', 'St Paul\'s Cathedral', 'Tower Bridge' ] },
    { 'city': 'Tokyo', 'iso': 'JP', 'desc': 'Japan\'s busy capital, mixes the ultramodern and the traditional.', 'landmarks': [ 'Senso-ji', 'Tokyo Skytree', 'Tokyo Tower', 'Meiji Jingu', 'Imperial Palace', 'Shibuya Crossing', 'Akihabara' ] },
    { 'city': 'New York City', 'iso': 'US', 'desc': 'An iconic global center of finance, culture, and entertainment.', 'landmarks': [ 'Statue of Liberty', 'Empire State Building', 'Central Park', 'Times Square', 'The Museum of Modern Art', 'Broadway Theater District', 'Brooklyn Bridge' ] },
    { 'city': 'Berlin', 'iso': 'DE', 'desc': 'Known for its art scene and modern landmarks, as well as reminders of its turbulent 20th-century history.', 'landmarks': [ 'Brandenburg Gate', 'Reichstag Building', 'Berlin Wall Memorial', 'Checkpoint Charlie', 'Pergamon Museum', 'Sanssouci Palace', 'Berlin Cathedral' ] },
    { 'city': 'Moscow', 'iso': 'RU', 'desc': 'The cosmopolitan capital of Russia, featuring historic core and modern architecture.', 'landmarks': [ 'Red Square', 'Moscow Kremlin', 'St. Basil\'s Cathedral', 'Lenin\'s Mausoleum', 'Tretyakov Gallery', 'GUM', 'Moscow Metro Stations' ] },
    { 'city': 'Beijing', 'iso': 'CN', 'desc': 'The sprawling capital of China, dating back 3 millennia.', 'landmarks': [ 'Forbidden City', 'Great Wall of China', 'Summer Palace', 'Temple of Heaven', 'Tiananmen Square', 'Bird\'s Nest', 'Lama Temple' ] },
    { 'city': 'Singapore', 'iso': 'SG', 'desc': 'An island city-state off southern Malaysia, a global financial center with a tropical climate.', 'landmarks': [ 'Marina Bay Sands', 'Gardens by the Bay', 'Merlion Park', 'Singapore Botanic Gardens', 'Jewel Changi Airport', 'Chinatown Heritage District', 'Buddha Tooth Relic Temple' ] },
    { 'city': 'Istanbul', 'iso': 'TR', 'desc': 'A major city in Turkey that straddles Europe and Asia across the Bosphorus Strait.', 'landmarks': [ 'Hagia Sophia', 'Topkapi Palace', 'Sultan Ahmed Mosque', 'Basilica Cistern', 'Galata Tower', 'Grand Bazaar', 'Dolmabahce Palace' ] },
    { 'city': 'Kyoto', 'iso': 'JP', 'desc': 'Famous for its numerous classical Buddhist temples, gardens, and imperial palaces.', 'landmarks': [ 'Kinkaku-ji', 'Kiyomizu-dera', 'Fushimi Inari Taisha', 'Arashiyama Bamboo Grove', 'Gion District', 'Ginkaku-ji', 'Nijo Castle' ] },
    { 'city': 'Mexico City', 'iso': 'MX', 'desc': 'The densely populated, high-altitude capital of Mexico.', 'landmarks': [ 'Zocalo', 'Metropolitan Cathedral of Mexico City', 'National Museum of Anthropology', 'Frida Kahlo Museum', 'Chapultepec Castle', 'Basilica of Our Lady of Guadalupe', 'Angel of Independence' ] },
    { 'city': 'Seoul', 'iso': 'KR', 'desc': 'A huge metropolis where modern skyscrapers meet Buddhist temples, palaces and street markets.', 'landmarks': [ 'Gyeongbokgung Palace', 'N Seoul Tower', 'Lotte World Tower', 'Bukchon Hanok Village', 'Myeongdong Cathedral', 'Dongdaemun Design Plaza', 'Gwanghwamun Square' ] },
    { 'city': 'Hong Kong', 'iso': 'HK', 'desc': 'A major global financial hub and shopping destination known for its tower-studded skyline.', 'landmarks': [ 'Victoria Peak', 'Victoria Harbour', 'Tian Tan Buddha', 'Avenue of Stars', 'Wong Tai Sin Temple', 'Star Ferry', 'Bank of China Tower' ] },
    { 'city': 'Buenos Aires', 'iso': 'AR', 'desc': 'Argentina\'s big, cosmopolitan capital city, known for its European atmosphere and tango.', 'landmarks': [ 'Obelisco de Buenos Aires', 'Teatro Colon', 'Casa Rosada', 'Recoleta Cemetery', 'Caminito', 'Plaza de Mayo', 'La Bombonera' ] },
    { 'city': 'Rio de Janeiro', 'iso': 'BR', 'desc': 'A huge seaside city in Brazil, famous for its beaches and Christ the Redeemer.', 'landmarks': [ 'Christ the Redeemer', 'Sugarloaf Mountain Cable Car', 'Copacabana Beach', 'Ipanema Beach', 'Maracanã', 'Metropolitan Cathedral of Saint Sebastian', 'Escadaria Selarón' ] },
    { 'city': 'Vienna', 'iso': 'AT', 'desc': 'Austria\'s capital, lying on the Danube River, shaped by its artistic and intellectual legacy.', 'landmarks': [ 'Schönbrunn Palace', 'Hofburg Palace', 'St Stephen\'s Cathedral', 'Belvedere Palace', 'Vienna State Opera', 'Albertina', 'Mozarthaus Vienna' ] },
    { 'city': 'Dublin', 'iso': 'IE', 'desc': 'The capital of Ireland, located on the east coast at the mouth of the River Liffey.', 'landmarks': [ 'Guinness Storehouse', 'Trinity College Library', 'Temple Bar', 'Dublin Castle', 'St Patrick\'s Cathedral', 'Kilmainham Gaol', 'Trinity College Dublin' ] },
    { 'city': 'Saint Petersburg', 'iso': 'RU', 'desc': 'A Russian port city on the Baltic Sea, founded in 1703 by Peter the Great.', 'landmarks': [ 'Hermitage Museum', 'Church of the Savior on Spilled Blood', 'Peterhof Palace', 'St. Isaac\'s Cathedral', 'Peter and Paul Fortress', 'Nevsky Prospect', 'Mariinsky Theatre' ] },
    { 'city': 'Cape Town', 'iso': 'ZA', 'desc': 'A port city on South Africa\'s southwest coast beneath the imposing Table Mountain.', 'landmarks': [ 'Table Mountain Aerial Cableway', 'V&A Waterfront', 'Robben Island Prison', 'Boulders Beach', 'Kirstenbosch National Botanical Garden', 'Bo-Kaap', 'Castle of Good Hope' ] },
    { 'city': 'Rome', 'iso': 'IT', 'desc': 'The Eternal City, famed for its nearly 3,000 years of globally influential art, architecture, and culture.', 'landmarks': [ 'Colosseum', 'St. Peter\'s Basilica', 'Trevi Fountain', 'Pantheon', 'Roman Forum', 'Spanish Steps', 'Piazza Navona' ] },
    { 'city': 'Bangkok', 'iso': 'TH', 'desc': 'A vibrant metropolis known for its ornate shrines, bustling street life, and cultural landmarks.', 'landmarks': [ 'The Grand Palace', 'Wat Arun', 'Wat Pho', 'Wat Phra Kaew', 'Damnoen Saduak Floating Market', 'Chatuchak Weekend Market', 'Lumpini Park' ] },
    { 'city': 'Barcelona', 'iso': 'ES', 'desc': 'The cosmopolitan capital of Spain\'s Catalonia region, defined by its quirky Gaudí architecture.', 'landmarks': [ 'Sagrada Familia', 'Park Güell', 'La Rambla', 'Casa Batlló', 'Gothic Quarter', 'Casa Milà', 'Magic Fountain of Montjuïc' ] },
    { 'city': 'Dubai', 'iso': 'AE', 'desc': 'A city of superlatives, known for luxury shopping, ultramodern architecture, and a lively nightlife scene.', 'landmarks': [ 'Burj Khalifa', 'Dubai Mall', 'Palm Jumeirah', 'Dubai Fountain', 'Burj Al Arab', 'Museum of the Future', 'The Dubai Frame' ] },
    { 'city': 'Sydney', 'iso': 'AU', 'desc': 'Australia\'s largest city, famous for its magnificent harborfront and iconic Opera House.', 'landmarks': [ 'Sydney Opera House', 'Sydney Harbour Bridge', 'Bondi Beach', 'Darling Harbour', 'The Rocks', 'Taronga Zoo Sydney', 'Royal Botanic Garden Sydney' ] },
    { 'city': 'Los Angeles', 'iso': 'US', 'desc': 'The sprawling center of the world\'s film and television industry, home to iconic Hollywood landmarks.', 'landmarks': [ 'Universal Studios Hollywood', 'Hollywood Sign', 'Griffith Observatory', 'Santa Monica Pier', 'Hollywood Walk of Fame', 'The Getty Center', 'Venice Beach' ] },
    { 'city': 'Shanghai', 'iso': 'CN', 'desc': 'China\'s financial hub, where a futuristic skyline meets historic colonial architecture along the Bund.', 'landmarks': [ 'The Bund', 'Yu Garden', 'Oriental Pearl Tower', 'Shanghai Tower', 'Nanjing Road', 'People\'s Square', 'Shanghai Museum' ] },
    { 'city': 'Cairo', 'iso': 'EG', 'desc': 'Set on the Nile River, famous for its history and monuments of the pharaonic era.', 'landmarks': [ 'Pyramids of Giza', 'Great Sphinx of Giza', 'Cairo Citadel', 'Mosque of Muhammad Ali', 'Egyptian Museum', 'Khan el-Khalili', 'Tahrir Square' ] },
    { 'city': 'Amsterdam', 'iso': 'NL', 'desc': 'Known for its artistic heritage, elaborate canal system, and narrow houses with gabled facades.', 'landmarks': [ 'Anne Frank House', 'Van Gogh Museum', 'Rijksmuseum', 'Canal Ring', 'Red Light District', 'Dam Square', 'Vondelpark' ] },
    { 'city': 'Prague', 'iso': 'CZ', 'desc': 'The "City of a Hundred Spires," known for its Old Town Square and colorful Baroque buildings.', 'landmarks': [ 'Charles Bridge', 'Prague Castle', 'Old Town Square', 'St. Vitus Cathedral', 'Jewish Quarter', 'Wenceslas Square', 'Petřín Lookout Tower' ] },
    { 'city': 'Madrid', 'iso': 'ES', 'desc': 'Spain\'s central capital, renowned for its elegant boulevards and expansive, manicured parks.', 'landmarks': [ 'Prado Museum', 'Royal Palace of Madrid', 'Plaza Mayor', 'Retiro Park', 'Puerta del Sol', 'Gran Vía', 'Puerta de Alcalá' ] },
    { 'city': 'Taipei', 'iso': 'TW', 'desc': 'A modern metropolis with Japanese colonial lanes, busy shopping streets, and contemporary skyscrapers.', 'landmarks': [ 'Taipei 101', 'National Palace Museum', 'Chiang Kai-shek Memorial Hall', 'Shilin Night Market', 'Longshan Temple', 'Ximending', 'Dihua Street' ] },
    { 'city': 'Budapest', 'iso': 'HU', 'desc': 'Hungary\'s capital, bisected by the River Danube and famous for its stunning architecture and thermal baths.', 'landmarks': [ 'Hungarian Parliament Building', 'Buda Castle', 'Fisherman\'s Bastion', 'Széchenyi Chain Bridge', 'St. Stephen\'s Basilica', 'Heroes\' Square', 'Széchenyi Thermal Baths' ] },
    { 'city': 'Lisbon', 'iso': 'PT', 'desc': 'Portugal\'s hilly, coastal capital city, known for its cafe culture and soulful Fado music.', 'landmarks': [ 'Belém Tower', 'Jerónimos Monastery', 'São Jorge Castle', 'Praça do Comércio', 'Alfama District', 'Padrão dos Descobrimentos', 'Santa Justa Lift' ] },
    { 'city': 'Athens', 'iso': 'GR', 'desc': 'The birthplace of democracy, dominated by 5th-century BC landmarks like the Acropolis.', 'landmarks': [ 'Parthenon', 'Acropolis Museum', 'Plaka', 'Ancient Agora of Athens', 'Temple of Olympian Zeus', 'Syntagma Square', 'Panathenaic Stadium' ] },
    { 'city': 'Munich', 'iso': 'DE', 'desc': 'Bavaria\'s capital, home to centuries-old buildings and numerous world-class museums.', 'landmarks': [ 'Marienplatz', 'English Garden', 'BMW Welt & Museum', 'Nymphenburg Palace', 'Munich Residenz', 'Deutsches Museum', 'Allianz Arena' ] },
    { 'city': 'Toronto', 'iso': 'CA', 'desc': 'A dynamic metropolis with a core of soaring skyscrapers, all overtopped by the iconic CN Tower.', 'landmarks': [ 'CN Tower', 'Royal Ontario Museum', 'Distillery District', 'Ripley\'s Aquarium of Canada', 'St. Lawrence Market', 'Art Gallery of Ontario', 'Casa Loma' ] },
    { 'city': 'Kuala Lumpur', 'iso': 'MY', 'desc': 'The capital of Malaysia, defined by its modern skyline and the iconic Petronas Twin Towers.', 'landmarks': [ 'Petronas Towers', 'Batu Caves', 'Merdeka Square', 'Bukit Bintang', 'KL Tower', 'Thean Hou Temple', 'Islamic Arts Museum Malaysia' ] },
    { 'city': 'Copenhagen', 'iso': 'DK', 'desc': 'The capital of Denmark, known for its picturesque canals, cycling culture, and the historic Tivoli Gardens.', 'landmarks': [ 'Nyhavn', 'Tivoli Gardens', 'The Little Mermaid', 'Amalienborg', 'Rosenborg Castle', 'Christiansborg Palace', 'The Round Tower' ] },
    { 'city': 'Stockholm', 'iso': 'SE', 'desc': 'The capital of Sweden, built on 14 islands and known for its well-preserved medieval old town.', 'landmarks': [ 'Vasa Museum', 'Gamla Stan', 'Stockholm Palace', 'Stockholm City Hall', 'Skansen', 'ABBA The Museum', 'Drottningholm Palace' ] },
    { 'city': 'Chicago', 'iso': 'US', 'desc': 'Set on Lake Michigan, famous for its bold architecture and world-renowned museums.', 'landmarks': [ 'Cloud Gate', 'Art Institute of Chicago', 'Willis Tower', 'Magnificent Mile', 'Navy Pier', 'Chicago Architecture Tour', 'Field Museum of Natural History' ] },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer3<LandmarksProvider, CityProvider, CountryProvider>(
      builder: (context, landmarksProvider, cityProvider, countryProvider, _) {
        final visitedLandmarks = landmarksProvider.visitedLandmarks;
        final totalCities = _citiesData.length;

        // 방문한 도시 수 (city provider 기준)
        final visitedCityCount = _citiesData
            .where((c) => cityProvider.isVisited(c['city'] as String))
            .length;

        // 7개 랜드마크 모두 완성한 도시 수
        final completedCityCount = _citiesData.where((cityData) {
          final landmarks = cityData['landmarks'] as List<String>;
          return landmarks.every((l) => visitedLandmarks.contains(l));
        }).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 헤더 ──────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 타이틀: 아이콘 박스 + 텍스트
                            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: _kTheme,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Iconic Cities',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827), letterSpacing: -0.6, height: 1.1)),
                                Text('$totalCities cities · 7 landmarks each',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                              ]),
                            ]),
                            const SizedBox(height: 20),
                            // 방문 진행 바
                            _StatBar(
                              label: 'Cities visited',
                              value: visitedCityCount,
                              total: totalCities,
                              color: _kTheme,
                            ),
                            const SizedBox(height: 10),
                            // 완성 진행 바
                            _StatBar(
                              label: 'Fully completed  7/7 ★',
                              value: completedCityCount,
                              total: totalCities,
                              color: const Color(0xFFD97706),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: const Color(0xFFF3F4F6)),

                // ── 리스트 ─────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: _citiesData.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 32),
                    itemBuilder: (context, index) {
                      final cityData = _citiesData[index];
                      return _buildCitySection(context, cityData, landmarksProvider, cityProvider, countryProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCitySection(
      BuildContext context,
      Map<String, dynamic> cityData,
      LandmarksProvider landmarksProvider,
      CityProvider cityProvider,
      CountryProvider countryProvider,
      ) {
    final cityName      = cityData['city'] as String;
    final iso           = cityData['iso'] as String;
    final description   = cityData['desc'] as String;
    final landmarkNames = cityData['landmarks'] as List<String>;

    final country     = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == iso);
    final themeColor  = country?.themeColor ?? const Color(0xFF2C3E50);
    final isCityVisited = cityProvider.isVisited(cityName);

    // 이 도시의 방문한 랜드마크 수
    final visitedCount = landmarkNames.where((l) => landmarksProvider.visitedLandmarks.contains(l)).length;
    final isCompleted  = visitedCount == landmarkNames.length;

    // city provider 에서 City 객체 찾기 (도시 모달용)
    final cityObj = cityProvider.allCities.firstWhereOrNull((c) =>
    c.name.toLowerCase() == cityName.toLowerCase() ||
        c.name.toLowerCase().contains(cityName.toLowerCase().split(' ').first));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── City Header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // 국기
                GestureDetector(
                  onTap: () {
                    if (cityObj != null) {
                      showExternalCityDetailsModal(context, cityObj);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(width: 32, height: 24, child: CountryFlag.fromCountryCode(iso)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 도시 이름 (탭하면 도시 모달)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (cityObj != null) {
                        showExternalCityDetailsModal(context, cityObj);
                      }
                    },
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          cityName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5),
                        ),
                      ),
                      // 도시 탭 힌트 아이콘
                      if (cityObj != null)
                        Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // 방문 토글 버튼
                GestureDetector(
                  onTap: () => cityProvider.toggleVisitedStatus(cityName),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isCityVisited ? themeColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isCityVisited ? themeColor : Colors.grey.shade300, width: 2),
                    ),
                    child: Icon(Icons.check, color: isCityVisited ? Colors.white : Colors.transparent, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // 완성 뱃지 or 진행 수
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFF59E0B).withOpacity(0.15)
                        : (visitedCount > 0 ? themeColor.withOpacity(0.1) : Colors.grey[100]!),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFFF59E0B).withOpacity(0.5)
                          : (visitedCount > 0 ? themeColor.withOpacity(0.3) : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    isCompleted ? '★ 7/7' : '$visitedCount / ${landmarkNames.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isCompleted ? const Color(0xFFD97706) : (visitedCount > 0 ? themeColor : Colors.grey[500]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // 설명 + 세로 바
              IntrinsicHeight(
                child: Row(children: [
                  Container(width: 3, decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(description,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5, letterSpacing: -0.2)),
                  ),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Horizontal Landmarks ─────────────────────────────────────
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: landmarkNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return _buildLandmarkCard(context, landmarkNames[index], themeColor, landmarksProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLandmarkCard(BuildContext context, String landmarkName, Color themeColor, LandmarksProvider landmarksProvider) {
    final landmark  = landmarksProvider.allLandmarks.firstWhereOrNull((l) => l.name == landmarkName);
    final isVisited = landmarksProvider.visitedLandmarks.contains(landmarkName);
    final imageUrl  = _getLandmarkImageUrl(landmarkName);

    return GestureDetector(
      onTap: () {
        if (landmark != null) {
          _showLandmarkDetailsModal(context, landmark, themeColor);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$landmarkName not found in database')));
        }
      },
      child: SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isVisited ? themeColor : Colors.transparent, width: isVisited ? 2.5 : 0),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isVisited ? 14 : 16),
                child: Stack(children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                  ),
                  if (isVisited)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: themeColor, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            landmarkName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
              color: isVisited ? const Color(0xFF111827) : Colors.grey[700],
              height: 1.2,
            ),
          ),
        ]),
      ),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider        = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark   = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited       = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted    = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final countryNames    = provider.getCountryNames(freshLandmark.countriesIsoA3);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount   = freshLandmark.locations?.length ?? 0;

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            landmarkThemeColor = country.themeColor;
          } catch (_) {}
        }

        final themeColor      = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(children: [
            Container(
              color: themeColor,
              padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton(onPressed: () => Navigator.pop(sheetContext),
                      child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                  ElevatedButton(onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                      child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text(freshLandmark.name,
                      style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                  if (isVisited || visitedSubCount > 0) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(locationDisplay,
                      style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                ]),
              ]),
            ),
            Expanded(child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Wishlist:'),
                    IconButton(visualDensity: VisualDensity.compact,
                        icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                        onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('My Rating:'),
                    const SizedBox(width: 8),
                    RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0,
                        direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0,
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                  ]),
                ]),
                const Divider(height: 20),
                if (totalSubCount > 1) ...[
                  Text('Components / Locations',
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Column(children: freshLandmark.locations!.map((loc) {
                      final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                      return CheckboxListTile(
                        title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                        value: isLocVisited, activeColor: themeColor, dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (_) => provider.toggleSubLocation(freshLandmark.name, loc.name),
                      );
                    }).toList()),
                  ),
                  const Divider(height: 24),
                ],
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('History (${freshLandmark.visitDates.length} entries)',
                      style: Theme.of(sheetContext).textTheme.titleSmall),
                  OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'),
                      onPressed: () => provider.addVisitDate(freshLandmark.name)),
                ]),
                const SizedBox(height: 8),
                if (freshLandmark.visitDates.isNotEmpty)
                  ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                    key: ValueKey('${freshLandmark.name}_${entry.key}'),
                    landmarkName: freshLandmark.name,
                    visitDate: entry.value,
                    index: entry.key,
                    onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                    availableLocations: freshLandmark.locations,
                  ))
                else const Center(child: Text('No visits recorded.')),
                const Divider(height: 24),
                LandmarkInfoCard(overview: freshLandmark.overview,
                    historySignificance: freshLandmark.history_significance,
                    highlights: freshLandmark.highlights, themeColor: themeColor),
                const SizedBox(height: 40),
              ]),
            ))),
          ]),
        );
      },
    ).then((_) {});
  }
}


// ─── Stat Bar Widget ──────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final pct   = (ratio * 100).toStringAsFixed(0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ),
        Text('$value',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        Text('  $pct%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.withOpacity(0.6))),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          Container(height: 6, color: Colors.grey[100]),
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─── Visit Editor Card (title/memo 저장 + 날짜 변경 + edit/save/cancel) ─────────

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    this.availableLocations,
  });

  @override
  State<_LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;

  late String _displayTitle;
  late String _displayMemo;
  bool _isEditing = false;

  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo  = widget.visitDate.memo ?? '';
    _titleController = TextEditingController(text: _displayTitle);
    _memoController  = TextEditingController(text: _displayMemo);
    _currentPhotos   = List.from(widget.visitDate.photos);
    _year  = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day   = widget.visitDate.day;
    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) {
      _isEditing = true;
    }
  }

  @override
  void dispose() { _titleController.dispose(); _memoController.dispose(); super.dispose(); }

  void _saveChanges() {
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName, widget.index,
      title: _titleController.text, memo: _memoController.text,
      year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999,
      photos: _currentPhotos,
    );
    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo  = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text  = _displayMemo;
      _year  = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day   = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
      firstDate: DateTime(1900), lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() { _year = picked.year; _month = picked.month; _day = picked.day; });
    }
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
  }

  Widget _buildPhotoPreview(String path, int i) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover)),
      ),
      if (_isEditing)
        Positioned(top: -6, right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _currentPhotos.removeAt(i)),
              child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 22)),
            )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(_displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text('Date: $_year-$_month-$_day',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () => showDialog(context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text('Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                      child: const Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              )),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50],
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isEditing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Visit Date: $_year-$_month-$_day',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                      onPressed: () => _selectDate(context),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _titleController,
                    decoration: InputDecoration(labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: _memoController, maxLines: 3, minLines: 1,
                    decoration: InputDecoration(labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
              ] else ...[
                if (_displayMemo.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_displayMemo, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4))),
              ],
              const SizedBox(height: 12),
              if (_currentPhotos.isNotEmpty || _isEditing)
                Padding(padding: const EdgeInsets.only(top: 8),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none,
                        child: Row(children: [
                          if (_isEditing)
                            Container(margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300)),
                                child: IconButton(icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                    onPressed: () => _pickImage(ImageSource.gallery))),
                          ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                        ]))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_isEditing) ...[
                  TextButton(onPressed: _cancelEditing,
                      child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(onPressed: _saveChanges,
                      icon: const Icon(Icons.save, size: 18), label: const Text('Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0)),
                ] else ...[
                  OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                      style: OutlinedButton.styleFrom(foregroundColor: themeColor, side: BorderSide(color: themeColor.withOpacity(0.5)))),
                ],
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}