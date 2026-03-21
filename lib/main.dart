import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:jidoapp/screens/login_screen.dart';
import 'package:jidoapp/screens/onboarding_tutorial_screen.dart';
import 'package:jidoapp/main_screen.dart';

import 'package:jidoapp/widgets/plane_loading_logo.dart';

import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/religion_provider.dart';
import 'package:jidoapp/providers/language_provider.dart';
import 'package:jidoapp/providers/language_family_provider.dart';
import 'package:jidoapp/providers/history_provider.dart';
import 'package:jidoapp/providers/economy_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/providers/country_info_provider.dart';
import 'package:jidoapp/providers/itinerary_provider.dart';
import 'package:jidoapp/providers/passport_provider.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/providers/visa_provider.dart';
import 'package:jidoapp/providers/flight_map_settings_provider.dart';
import 'package:jidoapp/providers/calendar_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/services/ai_service.dart';
import 'package:jidoapp/services/home_widget_service.dart';

import 'package:jidoapp/screens/badge_collected_screen.dart';
import 'package:jidoapp/screens/rank_collected_screen.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const MaterialColor mintSwatch = MaterialColor(
  0xFF3DDAD7,
  <int, Color>{
    50: Color(0xFFE0F7F7),
    100: Color(0xFFB3EAEA),
    200: Color(0xFF80DDDC),
    300: Color(0xFF4DD0CD),
    400: Color(0xFF26C6C4),
    500: Color(0xFF3DDAD7),
    600: Color(0xFF00B3B0),
    700: Color(0xFF00A39F),
    800: Color(0xFF00938E),
    900: Color(0xFF007A70),
  },
);

const SystemUiOverlayStyle _defaultSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
);

void _setSystemUiMode() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_defaultSystemUiOverlayStyle);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setSystemUiMode();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ko_KR', null);
  tz.initializeTimeZones();

  await _debugCheckLandmarkData();

  runApp(const JidoRoot());
}

Future<void> _debugCheckLandmarkData() async {
  print('\n🚀 [START] main.dart :: 랜드마크 데이터 무결성 검사 시작\n');
  try {
    final String response =
    await rootBundle.loadString('assets/all_landmarks.json');
    final data = await json.decode(response);
    final List<dynamic> allLandmarks = data as List;

    print('DEBUG: Successfully loaded ${allLandmarks.length} landmarks.');

    try {
      final bracketLandmarks = allLandmarks.where((item) {
        final String name = item['name'] ?? '';
        return name.contains('(') || name.contains(')');
      }).toList();

      print('\n[Landmarks with Parentheses in Name Check]');
      if (bracketLandmarks.isEmpty) {
        print('결과: 이름에 괄호가 포함된 랜드마크가 데이터셋에 하나도 없습니다.');
      } else {
        print('총 ${bracketLandmarks.length}개 발견:');
        for (var l in bracketLandmarks) {
          print('- ${l['name']}');
        }
      }
    } catch (e) {
      print('Error during parentheses check: $e');
    }

    try {
      final List<dynamic> globalRankedList = allLandmarks.where((item) {
        final int r = item['global_rank'] ?? 0;
        return r >= 1 && r <= 100;
      }).toList();

      globalRankedList.sort((a, b) =>
          (a['global_rank'] as int).compareTo(b['global_rank'] as int));

      print('\n[Global Rank 1-100]');
      for (var item in globalRankedList) {
        print('Rank ${item['global_rank']}: ${item['name']}');
      }
    } catch (e) {
      print('Error printing global ranks: $e');
    }
  } catch (e) {
    print('❌ [ERROR] 데이터 로딩 실패: $e');
  }
  print('\n✅ [END] main.dart :: 랜드마크 데이터 검사 종료\n');
}

class JidoRoot extends StatelessWidget {
  const JidoRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const AuthGateRoot(),
    );
  }
}

class AuthGateRoot extends StatelessWidget {
  const AuthGateRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthReady) {
          return _buildAppShell(
            const Scaffold(
              backgroundColor: Colors.white,
              body: PlaneLoadingLogo(),
            ),
          );
        }

        if (!auth.isAuthenticated) {
          return _buildAppShell(const LoginScreen());
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CountryProvider()),
            ChangeNotifierProxyProvider<CountryProvider, CityProvider>(
              create: (context) => CityProvider(),
              update: (context, countryProvider, cityProvider) {
                cityProvider ??= CityProvider();
                cityProvider.updateCountryProvider(countryProvider);
                return cityProvider;
              },
            ),
            ChangeNotifierProvider(create: (_) => AirlineProvider()),
            ChangeNotifierProvider(create: (_) => AirportProvider()),
            ChangeNotifierProxyProvider2<CountryProvider, CityProvider,
                LandmarksProvider>(
              lazy: false,
              create: (_) => LandmarksProvider(),
              update: (context, countryProvider, cityProvider,
                  landmarksProvider) {
                landmarksProvider ??= LandmarksProvider();
                landmarksProvider.updateProviders(
                  countryProvider,
                  cityProvider,
                );
                return landmarksProvider;
              },
            ),
            ChangeNotifierProvider(
              create: (_) => UnescoProvider(),
              lazy: false,
            ),
            ChangeNotifierProvider(create: (_) => ReligionProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => LanguageFamilyProvider()),
            ChangeNotifierProvider(create: (_) => HistoryProvider()),
            ChangeNotifierProvider(create: (_) => EconomyProvider()),
            ChangeNotifierProvider(
              create: (_) => CountryInfoProvider(),
              lazy: false,
            ),
            ChangeNotifierProvider(create: (_) => PassportProvider()),
            ChangeNotifierProvider(create: (_) => SubregionProvider()),
            ChangeNotifierProvider(create: (_) => VisaProvider()),
            ChangeNotifierProvider(
              create: (_) => FlightMapSettingsProvider(),
            ),
            ChangeNotifierProvider(create: (_) => CalendarProvider()),
            ChangeNotifierProvider(create: (_) => PersonalityProvider()),
            Provider<AiService>(create: (_) => AiService()),
            ChangeNotifierProxyProvider<CountryProvider, TripLogProvider>(
              create: (context) => TripLogProvider(context.read<AiService>()),
              update: (context, countryProvider, tripLogProvider) {
                tripLogProvider ??=
                    TripLogProvider(context.read<AiService>());
                tripLogProvider.updateCountryData(
                  countryProvider.countryNameToIsoMap,
                );
                return tripLogProvider;
              },
            ),
            ChangeNotifierProvider(
              create: (context) => ItineraryProvider(
                context.read<AiService>(),
              ),
            ),
            ChangeNotifierProxyProvider6<
                CountryProvider,
                EconomyProvider,
                CityProvider,
                AirlineProvider,
                AirportProvider,
                LandmarksProvider,
                BadgeProvider>(
              create: (_) => BadgeProvider(),
              update: (context, countryProvider, economyProvider, cityProvider,
                  airlineProvider, airportProvider, landmarksProvider,
                  badgeProvider) {
                badgeProvider ??= BadgeProvider();

                if (!cityProvider.isLoading && !landmarksProvider.isLoading) {
                  badgeProvider.updateBadges(
                    countryProvider,
                    economyProvider.economyData,
                    cityProvider: cityProvider,
                    airlineProvider: airlineProvider,
                    airportProvider: airportProvider,
                    landmarksProvider: landmarksProvider,
                  );
                }

                return badgeProvider;
              },
            ),
          ],
          child: _buildAppShell(
            const WidgetUpdateWrapper(),
            navKey: navigatorKey,
          ),
        );
      },
    );
  }
}

class WidgetUpdateWrapper extends StatefulWidget {
  const WidgetUpdateWrapper({super.key});

  @override
  State<WidgetUpdateWrapper> createState() => _WidgetUpdateWrapperState();
}

class _WidgetUpdateWrapperState extends State<WidgetUpdateWrapper> {
  bool _widgetUpdated = false;

  // TODO: 출시 후 SharedPreferences 로 한 번만 뜨도록 변경
  bool _showTutorial = true;

  @override
  Widget build(BuildContext context) {
    if (_showTutorial) {
      return OnboardingTutorialScreen(
        onComplete: () {
          setState(() => _showTutorial = false);
        },
      );
    }

    final countryProvider = context.watch<CountryProvider>();

    if (!_widgetUpdated &&
        countryProvider.allCountries.isNotEmpty &&
        countryProvider.visitedCountries.isNotEmpty) {
      _widgetUpdated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerWidgetUpdate(countryProvider);
      });
    }

    return const MainScreen();
  }

  void _triggerWidgetUpdate(CountryProvider countryProvider) {
    final visitedNames = countryProvider.visitedCountries;
    final visitedList = countryProvider.allCountries
        .where((c) => visitedNames.contains(c.name))
        .toList();

    debugPrint('✅ Widget update: ${visitedList.length}개 국가');

    HomeWidgetService.updateWidget(
      widgetImage: null,
      widgetType: WidgetType.countries,
    );
  }
}

Widget _buildAppShell(Widget home, {GlobalKey<NavigatorState>? navKey}) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: _defaultSystemUiOverlayStyle,
    child: MaterialApp(
      navigatorKey: navKey,
      title: 'Travelog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: mintSwatch,
        primaryColor: const Color(0xFF3DDAD7),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDAD7),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return BadgeGlobalListener(child: child ?? const SizedBox.shrink());
      },
      home: home,
    ),
  );
}

class BadgeGlobalListener extends StatefulWidget {
  final Widget? child;
  const BadgeGlobalListener({Key? key, this.child}) : super(key: key);

  @override
  State<BadgeGlobalListener> createState() => _BadgeGlobalListenerState();
}

class _BadgeGlobalListenerState extends State<BadgeGlobalListener> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotifications();
    });
  }

  void _checkNotifications() {
    if (!mounted || _isShowingDialog) return;

    try {
      final badgeProvider = context.read<BadgeProvider>();
      final overlayContext = navigatorKey.currentContext;
      if (overlayContext == null) return;

      if (badgeProvider.newRankUnlocked != null) {
        _isShowingDialog = true;
        final rankName = badgeProvider.newRankUnlocked!;

        showDialog(
          context: overlayContext,
          barrierDismissible: false,
          builder: (ctx) => RankCollectedScreen(
            rankName: rankName,
          ),
        ).then((_) {
          if (mounted) {
            _isShowingDialog = false;
            badgeProvider.markRankAsSeen();
          }
        });
        return;
      }

      if (badgeProvider.newlyUnlocked.isNotEmpty) {
        final newBadge = badgeProvider.newlyUnlocked.first;
        _isShowingDialog = true;

        showDialog(
          context: overlayContext,
          barrierDismissible: false,
          builder: (ctx) => BadgeCollectedScreen(achievement: newBadge),
        ).then((_) {
          if (mounted) {
            _isShowingDialog = false;
            badgeProvider.markBadgeAsSeen(newBadge);
          }
        });
      }
    } catch (e) {
      debugPrint('Notification check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final badgeProvider = context.watch<BadgeProvider>();

      if ((badgeProvider.newlyUnlocked.isNotEmpty ||
          badgeProvider.newRankUnlocked != null) &&
          !_isShowingDialog) {
        WidgetsBinding.instance.addPostFrameCallback(
              (_) => _checkNotifications(),
        );
      }
    } catch (e) {}

    return widget.child ?? const SizedBox.shrink();
  }
}