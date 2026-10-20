import 'package:flutter/material.dart';
import '../screens/login_prompt_screen.dart' as s0;
import '../screens/onboarding_tutorial_screen.dart' as s1;
import '../screens/welcome_screen.dart' as s2;
import '../screens/profile_screen.dart' as s3;
import '../screens/settings_screen.dart' as s4;
import '../screens/badges_screen.dart' as s5;
import '../screens/badge_collected_screen.dart' as s6;
import '../screens/badge_detail_screen.dart' as s7;
import '../screens/rank_collected_screen.dart' as s8;
import '../screens/daily_quiz_screen.dart' as s9;
import '../screens/travelog_games_screen.dart' as s10;
import '../screens/calendar_screen.dart' as s11;
import '../screens/edit_trip_log_screen.dart' as s12;
import '../screens/my_trips_tab_screen.dart' as s13;
import '../screens/trip_dna_screen.dart' as s14;
import '../screens/trip_log_detail_screen.dart' as s15;
import '../screens/trip_log_list_screen.dart' as s16;
import '../screens/trip_map_screen.dart' as s17;
import '../screens/ai_itinerary_view.dart' as s18;
import '../screens/ai_summary_screen.dart' as s19;
import '../screens/recommendations_screen.dart' as s20;
import '../screens/traveler_type_ai_screen.dart' as s21;
import '../screens/traveler_type_selector_screen.dart' as s22;
import '../screens/passport_screen.dart' as s23;
import '../screens/passport_visa_detail_screen.dart' as s24;
import '../screens/visa_screen.dart' as s25;
import '../screens/favorites_screen.dart' as s26;
import '../screens/city_tiers_screen.dart' as s27;
import '../screens/countries_map_screen.dart' as s28;
import '../screens/countries_menu_screen.dart' as s29;
import '../screens/country_selection_screen.dart' as s30;
import '../screens/country_tiers_screen.dart' as s31;
import '../screens/countrydex_screen.dart' as s32;
import '../screens/country_detail_screen.dart' as s33;
import '../screens/alexander_empire_map_screen.dart' as s34;
import '../screens/mongol_empire_map_screen.dart' as s35;
import '../screens/ottoman_empire_map_screen.dart' as s36;
import '../screens/roman_empire_map_screen.dart' as s37;
import '../screens/area_stats_screen.dart' as s38;
import '../screens/overview_stats_screen.dart' as s39;
import '../screens/history_stats_screen.dart' as s40;
import '../screens/military_stats_screen.dart' as s41;
import '../screens/language_family_map_screen.dart' as s42;
import '../screens/language_map_screen.dart' as s43;
import '../screens/language_stats_screen.dart' as s44;
import '../screens/religion_stats_screen.dart' as s45;
import '../screens/specials_stats_screen.dart' as s46;
import '../screens/economy_stats_screen.dart' as s47;
import '../screens/geography_stats_screen.dart' as s48;
import '../screens/geopolitics_stats_screen.dart' as s49;
import '../screens/society_stats_screen.dart' as s50;
import '../screens/climate_stats_screen.dart' as s51;
import '../screens/sports_stats_screen.dart' as s52;
import '../screens/cities_menu_screen.dart' as s53;
import '../screens/cities_screen.dart' as s54;
import '../screens/city_overview_stats_screen.dart' as s55;
import '../screens/city_stats_map_screen.dart' as s56;
import '../screens/city_climate_screen.dart' as s57;
import '../screens/city_economy_screen.dart' as s58;
import '../screens/city_geography_screen.dart' as s59;
import '../screens/city_history_screen.dart' as s60;
import '../screens/city_society_screen.dart' as s61;
import '../screens/city_specials_screen.dart' as s62;
import '../screens/city_sports_screen.dart' as s63;
import '../screens/city_transportation_screen.dart' as s64;
import '../screens/top_cities_screen.dart' as s65;
import '../screens/populations_screen.dart' as s66;
import '../screens/population_stats_screen.dart' as s67;
import '../screens/capitals_screen.dart' as s68;
import '../screens/landmarks_list_screen.dart' as s69;
import '../screens/landmarks_menu_screen.dart' as s70;
import '../screens/landmark_map_screen.dart' as s71;
import '../screens/explore_menu_screen.dart' as s72;
import '../screens/natural_menu_screen.dart' as s73;
import '../screens/activities_menu_screen.dart' as s74;
import '../screens/top_activities_menu_screen.dart' as s75;
import '../screens/landmark_stats_screen.dart' as s76;
import '../screens/landmark_cities_screen.dart' as s77;
import '../screens/landmark_visit_log_screen.dart' as s78;
import '../screens/top_buildings_screen.dart' as s79;
import '../screens/top_falls_screen.dart' as s80;
import '../screens/top_lakes_screen.dart' as s81;
import '../screens/top_landmarks_screen.dart' as s82;
import '../screens/top_mountains_screen.dart' as s83;
import '../screens/top_museums_screen.dart' as s84;
import '../screens/top_orchestras_screen.dart' as s85;
import '../screens/top_paintings_screen.dart' as s86;
import '../screens/top_picks_menu_screen.dart' as s87;
import '../screens/top_public_squares_screen.dart' as s88;
import '../screens/top_rivers_screen.dart' as s89;
import '../screens/top_statues_screen.dart' as s90;
import '../screens/top_universities_screen.dart' as s91;
import '../screens/disneyland_screen.dart' as s92;
import '../screens/universal_studios_screen.dart' as s93;
import '../screens/tourism_screen.dart' as s94;
import '../screens/world_wonders_screen.dart' as s95;
import '../screens/film_festivals_screen.dart' as s96;
import '../screens/instagram_ranking_screen.dart' as s97;
import '../screens/champions_league_teams_screen.dart' as s98;
import '../screens/unesco_map_screen.dart' as s99;
import '../screens/unesco_sites_screen.dart' as s100;
import '../screens/unesco_stats_screen.dart' as s101;
import '../screens/add_flight_log_screen.dart' as s102;
import '../screens/airlines_list_screen.dart' as s103;
import '../screens/airline_detail_screen.dart' as s104;
import '../screens/airports_screen.dart' as s105;
import '../screens/flights_menu_screen.dart' as s106;
import '../screens/flight_connection_screen.dart' as s107;
import '../screens/flight_hub_screen.dart' as s108;
import '../screens/flight_log_list_screen.dart' as s109;
import '../screens/flight_route_map_screen.dart' as s110;
import '../screens/aircraft_stats_screen.dart' as s111;
import '../screens/airline_stats_screen.dart' as s112;
import '../screens/airport_stats_screen.dart' as s113;
import '../screens/flights_lounge_stats_screen.dart' as s114;
import '../screens/flight_frequency_stats_screen.dart' as s115;
import '../screens/flight_overview_stats_screen.dart' as s116;
import '../screens/flight_transfer_stats_screen.dart' as s117;
import '../screens/seat_class_stats_screen.dart' as s118;
import '../screens/purchase_stats_screen.dart' as s119;

/// Typed mapping of the widget Flutter has ALREADY built. No builder replay,
/// element-tree polling, string class names, route replacement, or title matching.
const Map<Type, String> screenWidgetNames = {
  s0.LoginPromptScreen: 'login_prompt',
  s1.OnboardingTutorialScreen: 'onboarding_tutorial',
  s2.WelcomeScreen: 'welcome',
  s3.ProfileScreen: 'profile',
  s4.SettingsScreen: 'settings',
  s5.BadgesScreen: 'badges',
  s6.BadgeCollectedScreen: 'badge_collected',
  s7.BadgeDetailScreen: 'badge_detail',
  s8.RankCollectedScreen: 'rank_collected',
  s9.DailyQuizScreen: 'daily_quiz',
  s10.TravelogGamesScreen: 'travelog_games',
  s11.CalendarScreen: 'calendar',
  s12.EditTripLogScreen: 'edit_trip_log',
  s13.MyTripsTabScreen: 'my_trips_tab',
  s14.TripDnaScreen: 'trip_dna',
  s15.TripLogDetailScreen: 'trip_log_detail',
  s16.TripLogListScreen: 'trip_log_list',
  s17.TripMapScreen: 'trip_map',
  s18.AiItineraryView: 'ai_itinerary_view',
  s19.AiSummaryScreen: 'ai_summary',
  s20.RecommendationsScreen: 'recommendations',
  s21.TravelerTypeAiScreen: 'traveler_type_ai',
  s22.TravelerTypeSelectorScreen: 'traveler_type_selector',
  s23.PassportScreen: 'passport',
  s24.PassportVisaDetailScreen: 'passport_visa_detail',
  s25.VisaScreen: 'visa',
  s26.FavoritesScreen: 'favorites',
  s27.CityTiersScreen: 'city_tiers',
  s28.CountriesMapScreen: 'countries_map',
  s29.CountriesMenuScreen: 'countries_menu',
  s30.CountrySelectionScreen: 'country_selection',
  s31.CountryTiersScreen: 'country_tiers',
  s32.CountryDexScreen: 'countrydex',
  s33.CountryDetailScreen: 'country_detail',
  s34.AlexanderEmpireMapScreen: 'alexander_empire_map',
  s35.MongolEmpireMapScreen: 'mongol_empire_map',
  s36.OttomanEmpireMapScreen: 'ottoman_empire_map',
  s37.RomanEmpireMapScreen: 'roman_empire_map',
  s38.AreaStatsScreen: 'area_stats',
  s39.OverviewStatsScreen: 'overview_stats',
  s40.HistoryStatsScreen: 'history_stats',
  s41.MilitaryStatsScreen: 'military_stats',
  s42.LanguageFamilyMapScreen: 'language_family_map',
  s43.LanguageMapScreen: 'language_map',
  s44.LanguageStatsScreen: 'language_stats',
  s45.ReligionStatsScreen: 'religion_stats',
  s46.SpecialsStatsScreen: 'specials_stats',
  s47.EconomyStatsScreen: 'economy_stats',
  s48.GeographyStatsScreen: 'geography_stats',
  s49.GeopoliticsStatsScreen: 'geopolitics_stats',
  s50.SocietyStatsScreen: 'society_stats',
  s51.ClimateStatsScreen: 'climate_stats',
  s52.SportsStatsScreen: 'sports_stats',
  s53.CitiesMenuScreen: 'cities_menu',
  s54.CitiesScreen: 'cities',
  s55.CityOverviewStatsScreen: 'city_overview_stats',
  s56.CityStatsMapScreen: 'city_stats_map',
  s57.CityClimateTabScreen: 'city_climate',
  s58.CityEconomyScreen: 'city_economy',
  s59.CityGeographyStatsScreen: 'city_geography',
  s60.CityHistoryTabScreen: 'city_history',
  s61.CitySocietyScreen: 'city_society',
  s62.CitySpecialsScreen: 'city_specials',
  s63.CitySportsScreen: 'city_sports',
  s64.CityTransportationScreen: 'city_transportation',
  s65.TopCitiesScreen: 'top_cities',
  s66.PopulationsScreen: 'populations',
  s67.PopulationStatsScreen: 'population_stats',
  s68.CapitalsScreen: 'capitals',
  s69.LandmarksListScreen: 'landmarks_list',
  s70.LandmarksMenuScreen: 'landmarks_menu',
  s71.LandmarkMapScreen: 'landmark_map',
  s72.ExploreMenuScreen: 'explore_menu',
  s73.NaturalMenuScreen: 'natural_menu',
  s74.ActivitiesMenuScreen: 'activities_menu',
  s75.TopActivitiesMenuScreen: 'top_activities_menu',
  s76.LandmarkStatsScreen: 'landmark_stats',
  s77.LandmarkCitiesScreen: 'landmark_cities',
  s78.LandmarkVisitLogScreen: 'landmark_visit_log',
  s79.TopBuildingsScreen: 'top_buildings',
  s80.TopFallsScreen: 'top_falls',
  s81.TopLakesScreen: 'top_lakes',
  s82.TopLandmarksScreen: 'top_landmarks',
  s83.TopMountainsScreen: 'top_mountains',
  s84.TopMuseumsScreen: 'top_museums',
  s85.TopOrchestrasScreen: 'top_orchestras',
  s86.TopPaintingsScreen: 'top_paintings',
  s87.TopPicksMenuScreen: 'top_picks_menu',
  s88.TopPublicSquaresScreen: 'top_public_squares',
  s89.TopRiversScreen: 'top_rivers',
  s90.TopStatuesScreen: 'top_statues',
  s91.TopUniversitiesScreen: 'top_universities',
  s92.DisneylandScreen: 'disneyland',
  s93.UniversalStudiosScreen: 'universal_studios',
  s94.TourismScreen: 'tourism',
  s95.WorldWondersScreen: 'world_wonders',
  s96.FilmFestivalsScreen: 'film_festivals',
  s97.InstagramRankingScreen: 'instagram_ranking',
  s98.ChampionsLeagueTeamsScreen: 'champions_league_teams',
  s99.UnescoMapScreen: 'unesco_map',
  s100.UnescoSitesScreen: 'unesco_sites',
  s101.UnescoStatsScreen: 'unesco_stats',
  s102.AddFlightLogScreen: 'add_flight_log',
  s103.AirlinesListScreen: 'airlines_list',
  s104.AirlineDetailScreen: 'airline_detail',
  s105.AirportsScreen: 'airports',
  s106.FlightsMenuScreen: 'flights_menu',
  s107.FlightConnectionScreen: 'flight_connection',
  s108.FlightHubScreen: 'flight_hub',
  s109.FlightLogListScreen: 'flight_log_list',
  s110.FlightRouteMapScreen: 'flight_route_map',
  s111.AircraftStatsScreen: 'aircraft_stats',
  s112.AirlineStatsScreen: 'airline_stats',
  s113.AirportStatsScreen: 'airport_stats',
  s114.LoungeStatsScreen: 'flights_lounge_stats',
  s115.FlightFrequencyStatsScreen: 'flight_frequency_stats',
  s116.FlightOverviewStatsScreen: 'flight_overview_stats',
  s117.FlightTransferStatsScreen: 'flight_transfer_stats',
  s118.SeatClassStatsScreen: 'seat_class_stats',
  s119.PurchaseStatsScreen: 'purchase_stats',
};

String? screenNameForWidget(Widget widget) =>
    screenWidgetNames[widget.runtimeType];
