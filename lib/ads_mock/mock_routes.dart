// BANNER MOCK ONLY: open a real screen by its analytics name, for capture.
// `adb shell run-as <pkg> sh -c 'echo NAME > files/goto'` pushes it; `echo home`
// pops to the first route.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jidoapp/main.dart' show navigatorKey;
import 'package:jidoapp/ads_mock/banner_mock.dart' show kBannerMock;
import 'package:jidoapp/screens/cities_screen.dart' as r0;
import 'package:jidoapp/screens/countries_map_screen.dart' as r1;
import 'package:jidoapp/screens/top_landmarks_screen.dart' as r2;
import 'package:jidoapp/screens/countrydex_screen.dart' as r3;
import 'package:jidoapp/screens/top_cities_screen.dart' as r4;
import 'package:jidoapp/screens/unesco_sites_screen.dart' as r5;
import 'package:jidoapp/screens/landmark_visit_log_screen.dart' as r6;
import 'package:jidoapp/screens/landmark_cities_screen.dart' as r7;
import 'package:jidoapp/screens/trip_dna_screen.dart' as r8;
import 'package:jidoapp/screens/flight_log_list_screen.dart' as r9;
import 'package:jidoapp/screens/badges_screen.dart' as r10;
import 'package:jidoapp/screens/capitals_screen.dart' as r11;
import 'package:jidoapp/screens/landmarks_menu_screen.dart' as r12;
import 'package:jidoapp/screens/flight_hub_screen.dart' as r13;
import 'package:jidoapp/screens/daily_quiz_screen.dart' as r14;
import 'package:jidoapp/screens/trip_log_list_screen.dart' as r15;
import 'package:jidoapp/screens/traveler_type_selector_screen.dart' as r16;
import 'package:jidoapp/screens/airlines_list_screen.dart' as r17;
import 'package:jidoapp/screens/activities_menu_screen.dart' as r18;
import 'package:jidoapp/screens/natural_menu_screen.dart' as r19;
import 'package:jidoapp/screens/settings_screen.dart' as r20;
import 'package:jidoapp/screens/top_picks_menu_screen.dart' as r21;
import 'package:jidoapp/screens/passport_screen.dart' as r22;
import 'package:jidoapp/screens/airports_screen.dart' as r23;
import 'package:jidoapp/screens/city_overview_stats_screen.dart' as r24;
import 'package:jidoapp/screens/calendar_screen.dart' as r25;
import 'package:jidoapp/screens/visa_screen.dart' as r26;
import 'package:jidoapp/screens/favorites_screen.dart' as r27;
import 'package:jidoapp/screens/travelog_games_screen.dart' as r28;
import 'package:jidoapp/screens/discover_screen.dart' as r29;
import 'package:jidoapp/screens/country_twin_screen.dart' as r30;
import 'package:jidoapp/screens/tourist_local_screen.dart' as r31;
import 'package:jidoapp/screens/travelog_polls_screen.dart' as r32;
import 'package:jidoapp/screens/discover_quiz_screen.dart' as r33;
import 'package:jidoapp/games/flag_guess.dart' as r34;
import 'package:jidoapp/games/which_is_farther.dart' as r35;
import 'package:jidoapp/games/border_chain.dart' as r36;
import 'package:jidoapp/games/respawn.dart' as r37;
import 'package:jidoapp/games/timezone_impostor.dart' as r38;
import 'package:jidoapp/games/higher_or_lower.dart' as r39;

final Map<String, WidgetBuilder> kMockRoutes = {
  'cities': (_) => r0.CitiesScreen(),
  'countries_map': (_) => r1.CountriesMapScreen(),
  'top_landmarks': (_) => r2.TopLandmarksScreen(),
  'countrydex': (_) => r3.CountryDexScreen(),
  'top_cities': (_) => r4.TopCitiesScreen(),
  'unesco_sites': (_) => r5.UnescoSitesScreen(),
  'landmark_visit_log': (_) => r6.LandmarkVisitLogScreen(),
  'landmark_cities': (_) => r7.LandmarkCitiesScreen(),
  'trip_dna': (_) => r8.TripDnaScreen(),
  'flight_log_list': (_) => r9.FlightLogListScreen(),
  'badges': (_) => r10.BadgesScreen(),
  'capitals': (_) => r11.CapitalsScreen(),
  'landmarks_menu': (_) => r12.LandmarksMenuScreen(),
  'flight_hub': (_) => r13.FlightHubScreen(),
  'daily_quiz': (_) => r14.DailyQuizScreen(useSavedDefaultMode: true),
  'trip_log_list': (_) => r15.TripLogListScreen(),
  'traveler_type_selector': (_) => r16.TravelerTypeSelectorScreen(),
  'airlines_list': (_) => r17.AirlinesListScreen(),
  'activities_menu': (_) => r18.ActivitiesMenuScreen(),
  'natural_menu': (_) => r19.NaturalMenuScreen(),
  'settings': (_) => r20.SettingsScreen(),
  'top_picks_menu': (_) => r21.TopPicksMenuScreen(),
  'passport': (_) => r22.PassportScreen(),
  'airports': (_) => r23.AirportsScreen(),
  'city_overview_stats': (_) => r24.CityOverviewStatsScreen(),
  'calendar': (_) => r25.CalendarScreen(),
  'visa': (_) => r26.VisaScreen(),
  'favorites': (_) => r27.FavoritesScreen(),
  'travelog_games': (_) => r28.TravelogGamesScreen(),
  'discover': (_) => r29.DiscoverScreen(),
  'country_twin': (_) => r30.CountryTwinScreen(),
  'tourist_local': (_) => r31.TouristLocalScreen(),
  'travelog_polls': (_) => r32.TravelogPollsScreen(),
  'discover_quiz': (_) => r33.DiscoverQuizScreen(quizId: 'survival'),
  'flag_guess_difficulty': (_) => r34.FlagGuessDifficultyScreen(),
  'which_is_farther_difficulty': (_) => r35.WhichIsFartherDifficultyScreen(),
  'border_chain_difficulty': (_) => r36.BorderChainDifficultyScreen(),
  'respawn_mode': (_) => r37.RespawnModeScreen(),
  'timezone_impostor_difficulty': (_) => r38.TimezoneImpostorDifficultyScreen(),
  'higher_or_lower_mode': (_) => r39.HigherOrLowerModeScreen(),
};

Timer? _gotoPoll;
void startMockGoto() {
  if (!kBannerMock || _gotoPoll != null) return;
  getApplicationSupportDirectory().then((dir) {
    final f = File('${dir.path}/goto');
    _gotoPoll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!f.existsSync()) return;
      final name = f.readAsStringSync().trim();
      f.deleteSync();
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      if (name == 'home') {
        nav.popUntil((r) => r.isFirst);
        return;
      }
      final b = kMockRoutes[name];
      if (b == null) {
        debugPrint('[MockGoto] unknown $name');
        return;
      }
      nav.push(MaterialPageRoute(builder: b));
    });
  });
}
