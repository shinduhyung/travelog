import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jidoapp/screens/daily_quiz_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:jidoapp/screens/login_screen.dart';
import 'package:jidoapp/screens/onboarding_tutorial_screen.dart';
import 'package:jidoapp/screens/welcome_screen.dart';
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
import 'package:jidoapp/providers/city_info_provider.dart';
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
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/services/game_scores_sync_service.dart';

import 'package:jidoapp/screens/badge_collected_screen.dart';
import 'package:jidoapp/screens/rank_collected_screen.dart';
import 'package:jidoapp/screens/badges_screen.dart';
import 'package:jidoapp/screens/badge_share.dart';
import 'package:jidoapp/screens/countries_share.dart'; // TODO: 테스트용
import 'package:screenshot/screenshot.dart'; // TODO: 테스트용
import 'package:flutter_map/flutter_map.dart'; // TODO: 테스트용
import 'package:latlong2/latlong.dart'; // TODO: 테스트용

import 'package:timezone/data/latest.dart' as tz;
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

// FCM 백그라운드 메시지 핸들러 (top-level 필수)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 [FCM] 백그라운드 메시지: \${message.messageId}');
}

// FCM 토큰 Firestore 저장
Future<void> _saveFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token == null) return;

    final user = await FirebaseMessaging.instance.getToken();
    debugPrint('📱 [FCM] 토큰: \$token');

    // DailyQuizScreen에서 저장해둔 기본 모드(Normal/Expert)를 함께 실어 보내서
    // Cloud Functions가 이 기기에 어느 쪽 일일 퀴즈 알림을 보낼지 판단하게 함.
    final prefs = await SharedPreferences.getInstance();
    final quizMode = prefs.getString('daily_quiz_default_mode') == 'expert' ? 'expert' : 'normal';

    await FirebaseFirestore.instance
        .collection('fcm_tokens')
        .doc(token)
        .set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': 'android',
      'quizMode': quizMode,
    }, SetOptions(merge: true));

    messaging.onTokenRefresh.listen((newToken) async {
      final refreshedPrefs = await SharedPreferences.getInstance();
      final refreshedQuizMode =
      refreshedPrefs.getString('daily_quiz_default_mode') == 'expert' ? 'expert' : 'normal';
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(newToken)
          .set({
        'token': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
        'quizMode': refreshedQuizMode,
      }, SetOptions(merge: true));
    });
  } catch (e) {
    debugPrint('⚠️ [FCM] 토큰 저장 오류: \$e');
  }
}

// 알림 탭 → DailyQuizScreen 딥링크
void _handleNotificationTap(RemoteMessage message) {
  final date = message.data['date'] as String?;
  final mode = message.data['mode'] as String?;
  final isExpert = mode == 'expert';
  final context = navigatorKey.currentContext;
  if (context == null) return;

  debugPrint('🔔 [FCM] 알림 탭 → date: \$date, mode: \$mode');

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DailyQuizScreen(
        initialDate: date,
        initialExpert: isExpert,
      ),
    ),
  );
}

bool isOnboardingActive = true;

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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await _saveFcmToken();

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(initialMessage);
    });
  }

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

  await MobileAds.instance.initialize();

  await SubscriptionService.instance.initialize();

  await AdService.instance.initialize();

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

// 🔥 FIX: provider 패키지의 ProxyProviderX는 6개까지만 지원합니다.
// BadgeProvider가 참조해야 하는 CountryProvider/EconomyProvider/CityProvider/
// AirlineProvider/AirportProvider/LandmarksProvider 6개를 하나로 묶어 넘기기
// 위한 순수 데이터 컨테이너입니다. ChangeNotifier가 아니며, 값만 담아
// 다음 단계(ChangeNotifierProxyProvider2)로 전달하는 용도입니다.
class _BadgeCoreDeps {
  final CountryProvider countryProvider;
  final EconomyProvider economyProvider;
  final CityProvider cityProvider;
  final AirlineProvider airlineProvider;
  final AirportProvider airportProvider;
  final LandmarksProvider landmarksProvider;

  _BadgeCoreDeps({
    required this.countryProvider,
    required this.economyProvider,
    required this.cityProvider,
    required this.airlineProvider,
    required this.airportProvider,
    required this.landmarksProvider,
  });
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

class AuthGateRoot extends StatefulWidget {
  const AuthGateRoot({super.key});

  @override
  State<AuthGateRoot> createState() => _AuthGateRootState();
}

class _AuthGateRootState extends State<AuthGateRoot> {
  int _sessionKey = 0;
  bool _wasAuthenticated = false;

  // [FIX] 기존 계정으로 "다시" 로그인(reload 케이스)했을 때, 같은 uid에 대해
  // 리마운트를 중복 트리거하지 않기 위한 가드. uid가 바뀌거나 reload 액션이
  // 새로 세팅될 때만 다시 동작해야 하므로 uid를 키로 기억해둔다.
  String? _lastHandledReloadUid;

  // [DEBUG] build()는 sessionKey가 안 바뀌어도 AuthProvider의 다른 상태
  // 변화(예: isSigningIn 토글)만으로도 계속 호출된다. 실제 "트리 재생성"과
  // 헷갈리지 않도록, sessionKey가 실제로 바뀐 경우에만 로그를 찍기 위한 값.
  int? _lastLoggedSessionKey;

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

        if (auth.isAuthReady) {
          if (_wasAuthenticated && !auth.isAuthenticated) {
            // 로그아웃 → 프로바이더 트리 리마운트 (기존 로직)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // [DEBUG] 리마운트 원인 추적용
                debugPrint(
                    '🔁 [AuthGateRoot] remount triggered: reason=logout, prevSessionKey=$_sessionKey');
                setState(() => _sessionKey++);
              }
            });
          }
          _wasAuthenticated = auth.isAuthenticated;

          // [FIX] 기존 계정으로 로그인(케이스 2, pendingLoginAction == 'reload')한
          // 경우에도 프로바이더 트리를 통째로 새로 만든다.
          //
          // 왜 필요한가:
          // 로그아웃/재설치/새 기기 상태에서 앱이 뜨면 CityProvider/CountryProvider
          // 생성자가 곧바로 (로그인 전 상태 기준으로) _initializeData()를 백그라운드로
          // 시작한다. 이 로딩이 채 끝나기 전에 사용자가 기존 계정으로 로그인하면,
          // 예전 코드는 reloadFromServer()만 별도로 호출했는데 — 이 두 비동기 작업이
          // 동시에 같은 provider state를 건드리면서 경쟁(race condition)이 생겼다.
          // 운이 나쁘면 뒤늦게 끝난 _initializeData()가 reloadFromServer()가 채워넣은
          // 정상 데이터를 다시 (로그인 전 빈 상태로) 덮어써서 방문 기록이 안 보이는
          // 현상이 발생했다. 앱을 완전히 재시작하면 _initializeData()가 이미 로그인된
          // 상태로 딱 한 번만 깨끗하게 실행되므로 정상으로 보였던 것.
          //
          // 해결책: 로그아웃 때와 동일하게, 기존 계정 로그인 순간에도 _sessionKey를
          // 올려서 MultiProvider를 통째로 새로 만든다. 그러면 새로 생성되는
          // CityProvider/CountryProvider 등은 처음부터 "로그인된 상태"로 생성자가
          // 돌기 때문에 경쟁 자체가 발생하지 않는다. 개별 provider 파일들을 전부
          // 수정할 필요가 없다.
          //
          // auth.isAuthenticated를 함께 확인하는 이유: pendingLoginAction은
          // AuthProvider._prepareLoginAction()에서 Firebase 로그인이 완전히
          // 끝나기 *전*에 미리 세팅된다 (UID로 Firestore를 먼저 조회해서 케이스를
          // 판단하기 때문). 그래서 isAuthenticated가 true가 되기 전에 리마운트하면
          // 새로 생성된 provider들이 여전히 "로그인 안 된" _auth.currentUser를
          // 참조하게 될 수 있다. 따라서 실제 Firebase 인증 전환이 끝난 뒤에만
          // 리마운트해야 한다.
          if (auth.isAuthenticated &&
              auth.pendingLoginAction == 'reload' &&
              _lastHandledReloadUid != auth.user!.uid) {
            final String newUid = auth.user!.uid;
            _lastHandledReloadUid = newUid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // [DEBUG] 리마운트 원인 추적용 — 기존 계정 로그인(reload)으로
                // 트리거된 경우. 계정 전환 테스트 시 이 로그가 정확히
                // "몇 번, 어떤 uid로" 찍히는지가 핵심 확인 포인트.
                debugPrint(
                    '🔁 [AuthGateRoot] remount triggered: reason=reload, uid=$newUid, prevSessionKey=$_sessionKey');
                setState(() => _sessionKey++);
                auth.clearPendingLoginAction();
              }
            });
          }

          // uid가 로그아웃 등으로 사라지면 다음에 같은 계정이 다시 로그인했을 때도
          // 정상적으로 다시 트리거되도록 가드를 초기화.
          if (!auth.isAuthenticated) {
            _lastHandledReloadUid = null;
          }
        }

        // [DEBUG] sessionKey가 실제로 바뀐 경우에만 찍음 — build()는 다른
        // 이유(isSigningIn 토글 등)로도 자주 호출되므로, sessionKey 변화
        // 여부로 필터링해야 "진짜 리마운트 횟수"와 로그 개수가 일치한다.
        if (_lastLoggedSessionKey != _sessionKey) {
          _lastLoggedSessionKey = _sessionKey;
          debugPrint(
              '🌳 [AuthGateRoot] provider tree (re)built: sessionKey=$_sessionKey, uid=${auth.user?.uid}');
        }

        return KeyedSubtree(
          key: ValueKey(_sessionKey),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<SubscriptionService>.value(
                value: SubscriptionService.instance,
              ),
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
              ChangeNotifierProvider(
                create: (_) => CityInfoProvider(),
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
              // 🔥 FIX: provider 패키지는 ProxyProvider6까지만 제공하고
              // ProxyProvider7은 존재하지 않습니다. BadgeProvider가
              // UnescoProvider까지 총 7개 의존성을 참조해야 하므로,
              // 앞의 6개를 먼저 하나의 번들(_BadgeCoreDeps)로 묶은 뒤
              // 그 번들 + UnescoProvider 두 개만으로 BadgeProvider를
              // 최종 생성하는 2단계 구조로 나눕니다.
              ProxyProvider6<
                  CountryProvider,
                  EconomyProvider,
                  CityProvider,
                  AirlineProvider,
                  AirportProvider,
                  LandmarksProvider,
                  _BadgeCoreDeps>(
                update: (context, countryProvider, economyProvider,
                    cityProvider, airlineProvider, airportProvider,
                    landmarksProvider, _) {
                  return _BadgeCoreDeps(
                    countryProvider: countryProvider,
                    economyProvider: economyProvider,
                    cityProvider: cityProvider,
                    airlineProvider: airlineProvider,
                    airportProvider: airportProvider,
                    landmarksProvider: landmarksProvider,
                  );
                },
              ),
              ChangeNotifierProxyProvider2<_BadgeCoreDeps, UnescoProvider,
                  BadgeProvider>(
                create: (_) => BadgeProvider(),
                update: (context, coreDeps, unescoProvider, badgeProvider) {
                  badgeProvider ??= BadgeProvider();

                  // 🔥 FIX: 이전에는 UnescoProvider가 이 의존성 그래프에
                  // 아예 포함되지 않아서, 유네스코 방문 체크를 해도
                  // 뱃지 재계산 자체가 트리거되지 않았습니다. 그 결과
                  // 진행률(10/10)은 정확히 표시되지만 unlock 판정 로직은
                  // 항상 스킵되는 상태였습니다. 이제 UnescoProvider 변경도
                  // 감지하고, 로딩이 끝난 뒤에만 재계산합니다.
                  if (!coreDeps.cityProvider.isLoading &&
                      !coreDeps.landmarksProvider.isLoading &&
                      !unescoProvider.isLoading) {
                    badgeProvider.updateBadges(
                      coreDeps.countryProvider,
                      coreDeps.economyProvider.economyData,
                      cityProvider: coreDeps.cityProvider,
                      airlineProvider: coreDeps.airlineProvider,
                      airportProvider: coreDeps.airportProvider,
                      landmarksProvider: coreDeps.landmarksProvider,
                      unescoProvider: unescoProvider,
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

  bool? _showTutorial;
  bool _showWelcome = false;

  static const String _tutorialVersion = '1.0';
  static const String _prefKey = 'onboarding_tutorial_version';

  // [FIX] addListener로 등록한 콜백을 dispose에서 정확히 removeListener 하려면
  // 익명 함수가 아니라 이 필드에 저장해둔 같은 참조를 넘겨야 한다.
  // (이전 코드는 dispose를 아예 오버라이드하지 않아서, 이 위젯이 리마운트될
  // 때마다 — 로그아웃, 그리고 이번에 추가된 reload 리마운트 포함 — 이전
  // AuthProvider 리스너가 계속 쌓이는 누수가 있었다.)
  AuthProvider? _listenedAuthProvider;
  void Function()? _authListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAuthChanges();
      _initTutorialCheck();
    });
  }

  @override
  void dispose() {
    // [FIX] 리스너 정리 — 위젯이 리마운트/dispose될 때 등록해뒀던
    // AuthProvider 리스너를 반드시 제거한다.
    if (_listenedAuthProvider != null && _authListener != null) {
      _listenedAuthProvider!.removeListener(_authListener!);
    }
    super.dispose();
  }

  Future<void> _initTutorialCheck() async {
    final authProvider = context.read<AuthProvider>();
    int waited = 0;
    while (!authProvider.isAuthReady && waited < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }
    _checkTutorial();
  }

  void _listenToAuthChanges() {
    final authProvider = context.read<AuthProvider>();
    _authListener = () => _handlePendingLoginAction(authProvider);
    authProvider.addListener(_authListener!);
    _listenedAuthProvider = authProvider;
  }

  bool _isHandlingAction = false;

  Future<void> _handlePendingLoginAction(AuthProvider authProvider) async {
    final action = authProvider.pendingLoginAction;
    debugPrint(
        '🔍 [_handlePendingLoginAction] called, action=$action, _isHandlingAction=$_isHandlingAction, mounted=$mounted');
    if (action == null || !mounted) return;

    if (_isHandlingAction) return;
    _isHandlingAction = true;

    try {
      final authProvider2 = context.read<AuthProvider>();
      int waited = 0;
      while (authProvider2.user == null && waited < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }
      debugPrint(
          '🔍 [LoginAction] user=${authProvider2.user?.uid}, waited=${waited * 100}ms');

      if (action == 'upload') {
        debugPrint('🔼 [LoginAction] upload: 로컬 → Firestore');
        await Future.wait([
          context.read<CountryProvider>().uploadLocalToFirestore(),
          context.read<CityProvider>().uploadLocalToFirestore(),
          context.read<AirportProvider>().uploadLocalToFirestore(),
          context.read<AirlineProvider>().uploadLocalToFirestore(),
          context.read<LandmarksProvider>().uploadLocalToFirestore(),
          context.read<UnescoProvider>().uploadLocalToFirestore(),
          context.read<SubregionProvider>().uploadLocalToFirestore(),
          context.read<CalendarProvider>().uploadLocalToFirestore(),
          context.read<ItineraryProvider>().uploadLocalToFirestore(),
          context.read<FlightMapSettingsProvider>().uploadLocalToFirestore(),
          context.read<PersonalityProvider>().uploadLocalToFirestore(),
          context.read<PassportProvider>().uploadLocalToFirestore(),
          context.read<VisaProvider>().uploadLocalToFirestore(),
          context.read<TripLogProvider>().uploadLocalToFirestore(),
          // [추가] 미니게임 리더보드/설정(Respawn 홈 국가, Insane 1회
          // 체험 사용 여부 포함) — Provider가 아닌 단순 싱글턴이라
          // context.read 없이 바로 호출.
          GameScoresSyncService.instance.uploadLocalToFirestore(),
        ]);
        authProvider.clearPendingLoginAction();
      }
      // [FIX] 'reload' 분기는 여기서 제거했습니다.
      // 기존 계정 로그인(케이스 2)은 이제 AuthGateRoot에서 MultiProvider
      // 트리 자체를 새로 만드는 방식으로 처리합니다 (main.dart의
      // _AuthGateRootState 참고). 그러면 새로 생성되는 각 Provider가
      // 생성자에서부터 이미 로그인된 유저 기준으로 깨끗하게 초기화되므로,
      // 여기서 개별 reloadFromServer()를 호출해 기존 초기화 작업과
      // 경쟁시킬 필요가 없어집니다. pendingLoginAction 정리(clear)도
      // AuthGateRoot 쪽에서 리마운트 직후에 수행합니다.
    } finally {
      _isHandlingAction = false;
      debugPrint('🔍 [_handlePendingLoginAction] DONE, action=$action');
    }
  }

  Future<void> _checkTutorial() async {
    final authProvider = context.read<AuthProvider>();

    // 1. 이미 로그인된 상태이면 튜토리얼 및 Welcome 화면 패스
    if (authProvider.isAuthenticated) {
      isOnboardingActive = false;
      if (mounted) {
        setState(() {
          _showTutorial = false;
          _showWelcome = false;
        });
      }
      return;
    }

    // 2. 비로그인 상태라도 온보딩(튜토리얼)을 이미 완료했는지 확인
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getString(_prefKey);

    if (completed == _tutorialVersion) {
      isOnboardingActive = false;
      if (mounted) {
        setState(() {
          _showTutorial = false;
          _showWelcome = false;
        });
      }
      return;
    }

    // 3. 로그인도 안 되어 있고 튜토리얼도 안 했다면 Welcome Screen 띄우기
    isOnboardingActive = true;
    if (mounted) {
      setState(() {
        _showTutorial = false;
        _showWelcome = true;
      });
    }
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _tutorialVersion);
    isOnboardingActive = false;
    if (mounted) setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showTutorial == null && !_showWelcome) {
      return const Scaffold(backgroundColor: Color(0xFF1ABFBC));
    }

    if (_showWelcome) {
      return WelcomeScreen(
        onStartTutorial: () {
          setState(() => _showWelcome = false);
          setState(() => _showTutorial = true);
        },
      );
    }

    if (_showTutorial == true) {
      return OnboardingTutorialScreen(
        onComplete: _completeTutorial,
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

    // 모든 과정 완료 또는 생략 시 My Trips 탭 (initialIndex: 0) 으로 진입
    return const MainScreen(initialIndex: 0);
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

/// [추가] 전면광고 "화면 전환 시점 노출" 실험용 NavigatorObserver.
///
/// pending 광고(조건은 충족됐지만 아직 안 띄운 광고)가 있을 때, 실제
/// 페이지 화면이 바뀌는 순간에만 AdService.instance.onScreenTransition()을
/// 호출해서 광고를 내보낸다.
///
/// 주의:
/// - showDialog()/showModalBottomSheet() 등 PopupRoute는 여기서 절대
///   화면 전환으로 취급하지 않는다(route가 PageRoute일 때만 반응).
/// - 앱 최초 실행으로 첫 route가 push되는 경우(previousRoute == null)도
///   화면 "전환"이 아니므로 무시한다.
class AdNavigatorObserver extends NavigatorObserver {
  void _notifyIfPageTransition({
    required Route<dynamic>? route,
    required Route<dynamic>? previousRoute,
  }) {
    if (route is! PageRoute) return; // Dialog/BottomSheet 등 PopupRoute 무시
    if (previousRoute == null) return; // 앱 최초 route 생성은 전환으로 취급 X
    AdService.instance.onScreenTransition();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notifyIfPageTransition(route: route, previousRoute: previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // pop 이후 실제로 "다시 보이게 되는" 화면은 route가 아니라
    // previousRoute이므로, 그 쪽이 PageRoute인지로 판단한다.
    if (previousRoute is! PageRoute) return;
    AdService.instance.onScreenTransition();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notifyIfPageTransition(route: newRoute, previousRoute: oldRoute);
  }

// didRemove는 의도적으로 훅하지 않음: Navigator.removeRoute()는 보통
// 애니메이션 없이 이력만 조용히 정리하는 용도라, 이걸 "화면 전환"으로
// 취급하면 사용자가 인지하지 못하는 시점에 광고가 부자연스럽게 뜰 수 있다.
}

Widget _buildAppShell(Widget home, {GlobalKey<NavigatorState>? navKey}) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: _defaultSystemUiOverlayStyle,
    child: MaterialApp(
      navigatorKey: navKey,
      navigatorObservers: [
        AdNavigatorObserver(),
      ],
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
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            AdService.instance.recordGlobalTouch();
          },
          child: BadgeGlobalListener(
            child: child ?? const SizedBox.shrink(),
          ),
        );
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

  // [추가] 앱 업데이트로 뱃지 400개가 새로 추가된 것을 안내하는 1회성 팝업 처리용.
  // 기존 설치자(이전 빌드 번호 < _currentBuildNumber)에게만, 세션당 한 번만 체크한다.
  static const int _currentBuildNumber = 75;
  static const String _lastSeenBuildKey = 'last_seen_build_number';
  bool _buildExpansionCheckDone = false;

  // [디버깅용] true로 두면 74 이하 유저에게 1회성 제한 없이 세션마다 계속
  // "500+ New Badges" 팝업이 뜬다. 확인 끝나면 반드시 false로 되돌릴 것.
  static const bool _debugAlwaysShowBadgeExpansionPromo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotifications();
    });
  }

  Future<void> _checkNotifications() async {
    if (!mounted || _isShowingDialog) return;
    if (isOnboardingActive) return;

    try {
      final badgeProvider = context.read<BadgeProvider>();
      final overlayContext = navigatorKey.currentContext;
      if (overlayContext == null) return;

      // [추가] 뱃지 400개 추가 안내 팝업 (기존 설치자 전용, 딱 한 번만)
      if (!_buildExpansionCheckDone) {
        _buildExpansionCheckDone = true;
        final prefs = await SharedPreferences.getInstance();
        final lastSeenBuild = prefs.getInt(_lastSeenBuildKey);

        if (lastSeenBuild == null && !_debugAlwaysShowBadgeExpansionPromo) {
          // 최초 설치 — 프로모 없이 현재 빌드 번호만 기준으로 저장
          await prefs.setInt(_lastSeenBuildKey, _currentBuildNumber);
        } else if (_debugAlwaysShowBadgeExpansionPromo ||
            (lastSeenBuild != null && lastSeenBuild < _currentBuildNumber)) {
          // [디버깅용] 플래그가 켜져 있으면 seen 처리를 저장하지 않아서
          // 앱을 재시작할 때마다(세션마다) 계속 뜬다.
          if (!_debugAlwaysShowBadgeExpansionPromo) {
            await prefs.setInt(_lastSeenBuildKey, _currentBuildNumber);
          }
          if (!mounted) return;

          _isShowingDialog = true;
          final goToBadges = await showDialog<bool>(
            context: overlayContext,
            barrierDismissible: false,
            builder: (ctx) => const _NewBadgesExpansionDialog(newBadgeLabel: '500+'),
          );
          _isShowingDialog = false;

          if (goToBadges == true) {
            // 뒤이어 새로 획득한 뱃지들을 하나씩 팝업으로 띄우지 않고 조용히 seen 처리
            badgeProvider.clearNewlyUnlocked();
            final navState = navigatorKey.currentState;
            if (mounted && navState != null) {
              navState.push(
                MaterialPageRoute(builder: (_) => const BadgesScreen()),
              );
            }
            return; // 아래 랭크/뱃지 체인은 건너뜀
          }
          // '닫기'를 선택했으면 아래 로직으로 그대로 이어져서 기존 체인이 진행됨
        }
      }

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
        ).then((_) async {
          if (mounted) {
            _isShowingDialog = false;
            badgeProvider.markBadgeAsSeen(newBadge);

            // 뱃지 공유 프로모 팝업 조건:
            // 1) 기기당 1회만
            // 2) 프리미엄 유저 제외
            final prefs = await SharedPreferences.getInstance();
            final alreadyShown = prefs.getBool('badge_share_promo_shown') ?? false;
            final isPremium = SubscriptionService.instance.isPremium;
            if (!alreadyShown && !isPremium && mounted) {
              final ctx = navigatorKey.currentContext;
              if (ctx != null) {
                await prefs.setBool('badge_share_promo_shown', true);
                showDialog(
                  context: ctx,
                  builder: (_) => _BadgeSharePromoDialog(achievement: newBadge),
                );
              }
            }
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

// TODO: 테스트용 - 나중에 제거
class _PromoTestDialog extends StatefulWidget {
  final BuildContext parentContext;
  const _PromoTestDialog({required this.parentContext});

  @override
  State<_PromoTestDialog> createState() => _PromoTestDialogState();
}

class _PromoTestDialogState extends State<_PromoTestDialog> {
  bool _isSharing = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final provider = Provider.of<CountryProvider>(widget.parentContext, listen: false);
      final visitedCountries = provider.allCountries
          .where((c) => provider.visitedCountries.contains(c.name))
          .toList();

      final Uint8List? mapImage = await _screenshotController.capture();

      if (!mounted) return;

      await CountriesShare.share(
        context: widget.parentContext,
        mapImage: mapImage ?? Uint8List(0),
        visitedCountries: visitedCountries,
      );
    } catch (e) {
      debugPrint('PromoTestDialog share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Consumer<CountryProvider>(
            builder: (context, countryProvider, _) => Positioned(
              left: -9999,
              top: 0,
              width: 600,
              height: 300,
              child: Screenshot(
                controller: _screenshotController,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(20, 0),
                      initialZoom: 0.3,
                      interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(urlTemplate: '', backgroundColor: Colors.white),
                      PolygonLayer(
                        polygons: countryProvider.allCountries.expand((country) {
                          final isVisited = countryProvider.visitedCountries.contains(country.name);
                          final color = isVisited
                              ? (countryProvider.continentColors[country.continent] ?? Colors.grey)
                              : Colors.grey.withOpacity(0.15);
                          return country.polygonsData.map((polygonData) => Polygon(
                            points: polygonData.first,
                            holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                            color: color,
                            borderColor: Colors.white,
                            borderStrokeWidth: 0.5,
                            isFilled: true,
                          ));
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF999999)),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB347).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.5),
                                children: [
                                  TextSpan(
                                    text: 'Try 30 days for FREE!\n',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E)),
                                  ),
                                  TextSpan(text: 'Post your map on '),
                                  TextSpan(text: 'Instagram', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE1306C))),
                                  TextSpan(text: ' or '),
                                  TextSpan(text: 'Facebook', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1877F2))),
                                  TextSpan(text: ' and send a screenshot to '),
                                  TextSpan(text: 'leeahn137@gmail.com', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3DDAD7))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _handleShare,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFB347), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB347).withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isSharing
                                  ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB347)),
                                ),
                              )
                                  : const Icon(Icons.share_rounded, size: 18, color: Color(0xFFFFB347)),
                              const SizedBox(width: 8),
                              const Text(
                                'Share My Map',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFB347)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Maybe later', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],        // Column children
            ),
          ),
        ],          // Stack children
      ),            // Stack
    );
  }
}

// ─────────────────────────────────────────────
// 뱃지 400개 추가 안내 팝업 (앱 업데이트 시 기존 설치자 전용, 1회성)
// ─────────────────────────────────────────────

class _NewBadgesExpansionDialog extends StatelessWidget {
  final String newBadgeLabel; // 예: '500+'

  const _NewBadgesExpansionDialog({required this.newBadgeLabel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3DDAD7).withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "NEW" 스탬프
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF3DDAD7), Color(0xFFFFD54F)],
                    ).createShader(bounds),
                    child: Text(
                      newBadgeLabel,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'New Badges Just Landed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Countries, cities, landmarks, and flights — a huge batch of new achievements is ready to collect. A few might already be unlocked from your past trips.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withOpacity(0.65),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDAD7),
                        foregroundColor: const Color(0xFF1A1A2E),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View New Badges',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 상단 왕관 아이콘 배지
            Positioned(
              top: -28,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DDAD7), Color(0xFF2BA6A3)],
                    ),
                    border: Border.all(color: const Color(0xFF1A1A2E), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3DDAD7).withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeSharePromoDialog extends StatefulWidget {
  final dynamic achievement;
  const _BadgeSharePromoDialog({required this.achievement});

  @override
  State<_BadgeSharePromoDialog> createState() => _BadgeSharePromoDialogState();
}

class _BadgeSharePromoDialogState extends State<_BadgeSharePromoDialog> {
  bool _isSharing = false;

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await BadgeShare.share(
        context: context,
        achievement: widget.achievement,
        progress: 1.0,
        progressDetailText: 'Completed',
      );
    } catch (e) {
      debugPrint('BadgeSharePromo error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF999999)),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB347).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.5),
                            children: [
                              TextSpan(
                                text: 'Try 30 days for FREE!\n',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E)),
                              ),
                              TextSpan(text: 'Post your badge on '),
                              TextSpan(text: 'Instagram', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE1306C))),
                              TextSpan(text: ' or '),
                              TextSpan(text: 'Facebook', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1877F2))),
                              TextSpan(text: ' and send a screenshot to '),
                              TextSpan(text: 'leeahn137@gmail.com', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3DDAD7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _handleShare,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB347), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB347).withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isSharing
                              ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB347))),
                          )
                              : const Icon(Icons.share_rounded, size: 18, color: Color(0xFFFFB347)),
                          const SizedBox(width: 8),
                          const Text('Share My Badge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFB347))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Maybe later', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}