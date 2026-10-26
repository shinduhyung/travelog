import 'dart:async';
import 'package:jidoapp/services/screen_tracking.dart';
import 'package:jidoapp/services/screen_registry.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:jidoapp/l10n/app_localizations.dart';
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
import 'package:jidoapp/widgets/badge_summary_dialog.dart';

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
import 'package:jidoapp/screens/countries_share.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:jidoapp/social/social_hub.dart' show socialRouteName;

const MaterialColor mintSwatch = MaterialColor(0xFF3DDAD7, <int, Color>{
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
});

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

// ── 상시 뒤로가기 버튼용 Observer/위젯 ──────────────────────────────
// 라우트가 push/pop/replace 될 때마다 알림을 보내서 버튼의 표시 여부(투명도)를
// 갱신할 수 있게 해줍니다.
class _AppNavObserver extends NavigatorObserver with ChangeNotifier {
  // 맨 위 화면 (다이얼로그/바텀시트는 제외). 소셜 화면은 자체 뒤로가기가 있어서 버튼을 숨긴다.
  Route? _topPage;
  bool get onSocialPage => _topPage?.settings.name == socialRouteName;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is! PopupRoute) _topPage = route;
    notifyListeners();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is! PopupRoute) _topPage = previousRoute;
    notifyListeners();
  }

  @override
  void didRemove(Route route, Route? previousRoute) => notifyListeners();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute is! PopupRoute) _topPage = newRoute;
    notifyListeners();
  }
}

final _appNavObserver = _AppNavObserver();

class _FloatingBackButton extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const _FloatingBackButton({required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return AnimatedBuilder(
      animation: _appNavObserver,
      builder: (context, _) {
        final canPop = (navigatorKey.currentState?.canPop() ?? false) && !_appNavObserver.onSocialPage;
        return SafeArea(
          child: AnimatedOpacity(
            opacity: canPop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !canPop,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Material(
                  color: Colors.black.withOpacity(0.28),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (navigatorKey.currentState?.canPop() ?? false) {
                        navigatorKey.currentState!.pop();
                      }
                    },
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// ── 상시 뒤로가기 버튼용 코드 끝 ─────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 [FCM] Background message: ${message.messageId}');
}

Future<void> _saveFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token == null) return;

    debugPrint('📱 [FCM] Token: $token');

    final String platform = Platform.isIOS ? 'ios' : 'android';
    final prefs = await SharedPreferences.getInstance();
    final quizMode = prefs.getString('daily_quiz_default_mode') == 'expert'
        ? 'expert'
        : 'normal';

    await FirebaseFirestore.instance.collection('fcm_tokens').doc(token).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': platform,
      'quizMode': quizMode,
    }, SetOptions(merge: true));

    messaging.onTokenRefresh.listen((newToken) async {
      final refreshedPrefs = await SharedPreferences.getInstance();
      final refreshedQuizMode =
          refreshedPrefs.getString('daily_quiz_default_mode') == 'expert'
          ? 'expert'
          : 'normal';
      await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(newToken)
          .set({
            'token': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': platform,
            'quizMode': refreshedQuizMode,
          }, SetOptions(merge: true));
    });
  } catch (e) {
    debugPrint('⚠️ [FCM] Token save error: $e');
  }
}

void _navigateToQuiz(
  String? date, {
  bool isExpert = false,
  int retryCount = 0,
}) {
  final context = navigatorKey.currentContext;

  if (context == null) {
    if (retryCount < 20) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _navigateToQuiz(date, isExpert: isExpert, retryCount: retryCount + 1);
      });
      debugPrint('🔔 [FCM] navigator not ready, retry $retryCount...');
    } else {
      debugPrint('🔔 [FCM] navigator still null after retries, giving up');
    }
    return;
  }

  debugPrint(
    '🔔 [FCM] Navigating to DailyQuizScreen → date: $date, expert: $isExpert',
  );
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          DailyQuizScreen(initialDate: date, initialExpert: isExpert),
    ),
  );
}

void _handleNotificationTap(RemoteMessage message) {
  final date = message.data['date'] as String?;
  final mode = message.data['mode'] as String?;
  final isExpert = mode == 'expert';
  debugPrint('🔔 [FCM] Notification tapped → date: $date, mode: $mode');
  _navigateToQuiz(date, isExpert: isExpert);
}

bool isOnboardingActive = true;

void main() {
  // ── DEBUG: 전역 에러 핸들러 ─────────────────────────────────────
  // 여기서부터가 진단용으로 추가된 코드입니다.
  // Flutter 프레임워크 레벨 에러(위젯 빌드 중 예외 등)를 잡습니다.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴🔴🔴 [FlutterError] ${details.exceptionAsString()}');
    debugPrint('🔴 [FlutterError] Stack:\n${details.stack}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(
    () async {
      // Dart 레벨 uncaught 예외(async 함수 안에서 던져진 에러 등)를 잡습니다.
      debugPrint('🟢 [DEBUG] main() zone 진입');

      WidgetsFlutterBinding.ensureInitialized();
      await AppLocale.instance.load();
      debugPrint('🟢 [DEBUG] 1) WidgetsFlutterBinding.ensureInitialized 완료');

      // 플랫폼 레벨(네이티브 채널 등) uncaught 에러를 잡습니다.
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('🔴🔴🔴 [PlatformDispatcher] $error');
        debugPrint('🔴 [PlatformDispatcher] Stack:\n$stack');
        return true; // 에러를 처리했다고 표시해서 앱이 죽지 않게 함
      };
      debugPrint('🟢 [DEBUG] 2) PlatformDispatcher.onError 등록 완료');

      _setSystemUiMode();
      debugPrint('🟢 [DEBUG] 3) _setSystemUiMode 완료');

      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        debugPrint('🟢 [DEBUG] 4) setPreferredOrientations 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 4) setPreferredOrientations 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('🟢 [DEBUG] 5) Firebase.initializeApp 완료');
        debugPrint(
          '🔥 [FIREBASE CONFIG] projectId=${DefaultFirebaseOptions.currentPlatform.projectId}',
        );
        debugPrint(
          '🔥 [FIREBASE CONFIG] storageBucket=${DefaultFirebaseOptions.currentPlatform.storageBucket}',
        );
        debugPrint(
          '🔥 [FIREBASE CONFIG] appId=${DefaultFirebaseOptions.currentPlatform.appId}',
        );
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 5) Firebase.initializeApp 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        debugPrint('🟢 [DEBUG] 6) onBackgroundMessage 등록 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 6) onBackgroundMessage 등록 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🟢 [DEBUG] 7) FCM requestPermission 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 7) FCM requestPermission 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await _saveFcmToken();
        debugPrint('🟢 [DEBUG] 8) _saveFcmToken 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 8) _saveFcmToken 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
        debugPrint(
          '🟢 [DEBUG] 9) setForegroundNotificationPresentationOptions 완료',
        );
      } catch (e, st) {
        debugPrint(
          '🔴 [DEBUG] 9) setForegroundNotificationPresentationOptions 실패: $e',
        );
        debugPrint('🔴 Stack:\n$st');
      }

      // MobileAds.initialize()는 여기서 호출하지 않는다 — UMP 동의(와 iOS ATT)가
      // 끝난 뒤 AdService가 직접 호출한다 (AdService._finishConsentFlow).

      try {
        await SubscriptionService.instance.initialize();
        debugPrint('🟢 [DEBUG] 11) SubscriptionService.initialize 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 11) SubscriptionService.initialize 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await AdService.instance.initialize();
        debugPrint('🟢 [DEBUG] 12) AdService.initialize 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 12) AdService.initialize 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await dotenv.load(fileName: ".env");
        debugPrint('🟢 [DEBUG] 13) dotenv.load 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 13) dotenv.load 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        await initializeDateFormatting('ko_KR', null);
        debugPrint('🟢 [DEBUG] 14) initializeDateFormatting 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 14) initializeDateFormatting 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      try {
        tz.initializeTimeZones();
        debugPrint('🟢 [DEBUG] 15) tz.initializeTimeZones 완료');
      } catch (e, st) {
        debugPrint('🔴 [DEBUG] 15) tz.initializeTimeZones 실패: $e');
        debugPrint('🔴 Stack:\n$st');
      }

      debugPrint('🟢 [DEBUG] 16) runApp 직전 — 여기까지 왔으면 초기화 단계는 전부 통과');
      ScreenTracking.instance.start();
      runApp(const JidoRoot());
      debugPrint('🟢 [DEBUG] 17) runApp 호출 완료');
    },
    (error, stack) {
      // runZonedGuarded가 잡는 모든 uncaught 예외는 여기로 옵니다.
      // "Lost connection to device"의 진짜 원인이 Dart 예외라면 여기 찍힙니다.
      debugPrint('🔴🔴🔴🔴🔴 [UNCAUGHT ZONE ERROR] $error');
      debugPrint('🔴 Stack:\n$stack');
    },
  );
  // ── DEBUG 코드 끝 ─────────────────────────────────────────────
}

Future<void> _debugCheckLandmarkData() async {
  print('\n🚀 [START] main.dart :: Landmark data integrity check\n');
  try {
    final String response = await rootBundle.loadString(
      'assets/all_landmarks.json',
    );
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
        print('Result: No landmarks with parentheses in the dataset.');
      } else {
        print('Total ${bracketLandmarks.length} found:');
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

      globalRankedList.sort(
        (a, b) => (a['global_rank'] as int).compareTo(b['global_rank'] as int),
      );

      print('\n[Global Rank 1-100]');
      for (var item in globalRankedList) {
        print('Rank ${item['global_rank']}: ${item['name']}');
      }
    } catch (e) {
      print('Error printing global ranks: $e');
    }
  } catch (e) {
    print('❌ [ERROR] Data load failed: $e');
  }
  print('\n✅ [END] main.dart :: Landmark data check completed\n');
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
    Localizations.maybeLocaleOf(context);
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
    Localizations.maybeLocaleOf(context);
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
                  '🔁 [AuthGateRoot] remount triggered: reason=logout, prevSessionKey=$_sessionKey',
                );
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
                  '🔁 [AuthGateRoot] remount triggered: reason=reload, uid=$newUid, prevSessionKey=$_sessionKey',
                );
                setState(() => _sessionKey++);
                unawaited(GameScoresSyncService.instance.reloadFromServer());
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
            '🌳 [AuthGateRoot] provider tree (re)built: sessionKey=$_sessionKey, uid=${auth.user?.uid}',
          );
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
              ChangeNotifierProxyProvider2<
                CountryProvider,
                CityProvider,
                LandmarksProvider
              >(
                lazy: false,
                create: (_) => LandmarksProvider(),
                update:
                    (
                      context,
                      countryProvider,
                      cityProvider,
                      landmarksProvider,
                    ) {
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
                  tripLogProvider ??= TripLogProvider(
                    context.read<AiService>(),
                  );
                  tripLogProvider.updateCountryData(
                    countryProvider.countryNameToIsoMap,
                  );
                  return tripLogProvider;
                },
              ),
              ChangeNotifierProvider(
                create: (context) =>
                    ItineraryProvider(context.read<AiService>()),
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
                _BadgeCoreDeps
              >(
                update:
                    (
                      context,
                      countryProvider,
                      economyProvider,
                      cityProvider,
                      airlineProvider,
                      airportProvider,
                      landmarksProvider,
                      _,
                    ) {
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
              ChangeNotifierProxyProvider2<
                _BadgeCoreDeps,
                UnescoProvider,
                BadgeProvider
              >(
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

  static final facebookAppEvents = FacebookAppEvents();
  // [FIX] addListener로 등록한 콜백을 dispose에서 정확히 removeListener 하려면
  // 익명 함수가 아니라 이 필드에 저장해둔 같은 참조를 넘겨야 한다.
  // (이전 코드는 dispose를 아예 오버라이드하지 않아서, 이 위젯이 리마운트될
  // 때마다 — 로그아웃, 그리고 이번에 추가된 reload 리마운트 포함 — 이전
  // AuthProvider 리스너가 계속 쌓이는 누수가 있었다.)
  AuthProvider? _listenedAuthProvider;
  void Function()? _authListener;
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAuthChanges();
      _initTutorialCheck();
      _initATTAndMetaSDK();
      _initNotificationHandlers();
    });
  }

  Future<void> _initNotificationHandlers() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 [FCM] Cold start message detected');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _handleNotificationTap(initialMessage);
    }

    _notificationSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      debugPrint('🔔 [FCM] onMessageOpenedApp');
      if (mounted) _handleNotificationTap(message);
    });
  }

  Future<void> _initATTAndMetaSDK() async {
    if (!Platform.isIOS) return;
    try {
      // ATT 프롬프트는 AdService가 UMP 동의 이후에 띄운다(두 화면이 겹치지
      // 않게 하기 위함). 여기서는 그 흐름이 끝나길 기다렸다가 결과만 반영한다.
      await AdService.instance.consentFlowDone.timeout(
        const Duration(seconds: 45),
        onTimeout: () {},
      );

      TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      // 동의 흐름이 타임아웃/실패해서 아직 한 번도 안 물어봤다면 여기서 폴백.
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }

      if (status == TrackingStatus.authorized) {
        await facebookAppEvents.setAdvertiserTracking(enabled: true);
        await facebookAppEvents.activateApp();
        debugPrint("✅ ATT already authorized: Meta SDK tracking active");
      } else {
        await facebookAppEvents.setAdvertiserTracking(enabled: false);
        debugPrint("🚫 ATT status: $status — tracking disabled");
      }
    } catch (e) {
      debugPrint("ATT Error: $e");
    }
  }

  @override
  void dispose() {
    // [FIX] 리스너 정리 — 위젯이 리마운트/dispose될 때 등록해뒀던
    // AuthProvider 리스너를 반드시 제거한다.
    if (_listenedAuthProvider != null && _authListener != null) {
      _listenedAuthProvider!.removeListener(_authListener!);
    }
    _notificationSubscription?.cancel();
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
      '🔍 [_handlePendingLoginAction] called, action=$action, _isHandlingAction=$_isHandlingAction, mounted=$mounted',
    );
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
        '🔍 [LoginAction] user=${authProvider2.user?.uid}, waited=${waited * 100}ms',
      );

      if (action == 'upload') {
        debugPrint('🔼 [LoginAction] upload: Local → Firestore');
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
    Localizations.maybeLocaleOf(context);
    if (_showTutorial == null && !_showWelcome) {
      return const Scaffold(backgroundColor: Color(0xFF1ABFBC));
    }

    if (_showWelcome) {
      return AnalyticsScreen(
        name: 'welcome',
        child: WelcomeScreen(
          onStartTutorial: () {
            setState(() => _showWelcome = false);
            setState(() => _showTutorial = true);
          },
        ),
      );
    }

    if (_showTutorial == true) {
      return AnalyticsScreen(
        name: 'onboarding_tutorial',
        child: OnboardingTutorialScreen(onComplete: _completeTutorial),
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

    return const MainScreen(initialIndex: 0);
  }

  void _triggerWidgetUpdate(CountryProvider countryProvider) {
    if (!HomeWidgetService.isSupported) return;

    final visitedNames = countryProvider.visitedCountries;
    final visitedList = countryProvider.allCountries
        .where((c) => visitedNames.contains(c.name))
        .toList();

    debugPrint('✅ Widget update: ${visitedList.length} countries');

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
/// 기존 _AppNavObserver(상시 뒤로가기 버튼용)와는 목적이 달라 별도
/// 클래스로 분리했다 — _AppNavObserver는 PopupRoute를 포함한 모든 route
/// 변화에 반응해야 하지만(뒤로가기 버튼은 다이얼로그 위에서도 필요할 수
/// 있음), 광고는 반드시 PageRoute 전환에만 반응해야 하기 때문이다.
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
  return AnimatedBuilder(
    animation: AppLocale.instance,
    builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: _defaultSystemUiOverlayStyle,
    child: MaterialApp(
      locale: AppLocale.instance.locale,
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
      navigatorKey: navKey,
      navigatorObservers: [
        _appNavObserver,
        AdNavigatorObserver(),
        ScreenTrackingObserver(resolve: screenNameForWidget),
      ],
      title: 'Travelog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: mintSwatch,
        primaryColor: const Color(0xFF3DDAD7),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3DDAD7)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            AdService.instance.recordGlobalTouch();
          },
          child: BadgeGlobalListener(
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (navKey != null) _FloatingBackButton(navigatorKey: navKey),
              ],
            ),
          ),
        );
      },
      home: home,
    ),
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

  static const int _currentBuildNumber = 75;
  static const String _lastSeenBuildKey = 'last_seen_build_number';
  bool _buildExpansionCheckDone = false;

  static const bool _debugAlwaysShowBadgeExpansionPromo = false;
  static const int _maxIndividualBadgePopups = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotifications();
    });
  }

  Future<void> _checkNotifications() async {
    debugPrint('');
    debugPrint('════════════════════════════════════════════════════');
    debugPrint('🏅 [BADGE DEBUG] _checkNotifications ENTER');
    debugPrint('🏅 mounted=$mounted');
    debugPrint('🏅 _isShowingDialog=$_isShowingDialog');
    debugPrint('🏅 isOnboardingActive=$isOnboardingActive');

    if (!mounted) {
      debugPrint('🟠 [BADGE DEBUG] STOP: widget not mounted');
      debugPrint('════════════════════════════════════════════════════');
      return;
    }

    if (_isShowingDialog) {
      debugPrint('🟠 [BADGE DEBUG] STOP: dialog already showing');
      debugPrint('════════════════════════════════════════════════════');
      return;
    }

    if (isOnboardingActive) {
      debugPrint('🟠 [BADGE DEBUG] STOP: onboarding active');
      debugPrint('════════════════════════════════════════════════════');
      return;
    }

    try {
      final badgeProvider = context.read<BadgeProvider>();

      debugPrint('🏅 [BADGE DEBUG] provider read success');
      debugPrint(
        '🏅 newlyUnlocked.length=${badgeProvider.newlyUnlocked.length}',
      );
      debugPrint('🏅 newRankUnlocked=${badgeProvider.newRankUnlocked}');

      if (badgeProvider.newlyUnlocked.isNotEmpty) {
        for (int i = 0; i < badgeProvider.newlyUnlocked.length; i++) {
          final b = badgeProvider.newlyUnlocked[i];
          try {
            debugPrint(
              '🏅 [BADGE DEBUG] unlocked[$i] '
              'name=${b.name} | imagePath=${b.imagePath} | '
              'category=${b.category} | description=${b.description}',
            );
          } catch (e) {
            debugPrint('🔴 [BADGE DEBUG] unlocked[$i] field log failed: $e');
            debugPrint('🔴 [BADGE DEBUG] unlocked[$i] raw=$b');
          }
        }
      }

      final overlayContext = navigatorKey.currentContext;
      debugPrint(
        '🏅 [BADGE DEBUG] navigatorKey.currentContext=$overlayContext',
      );

      if (overlayContext == null) {
        debugPrint('🔴 [BADGE DEBUG] STOP: navigator overlay context is null');
        debugPrint('════════════════════════════════════════════════════');
        return;
      }

      if (!_buildExpansionCheckDone) {
        _buildExpansionCheckDone = true;
        final prefs = await SharedPreferences.getInstance();
        final lastSeenBuild = prefs.getInt(_lastSeenBuildKey);

        if (lastSeenBuild == null && !_debugAlwaysShowBadgeExpansionPromo) {
          await prefs.setInt(_lastSeenBuildKey, _currentBuildNumber);
        } else if (_debugAlwaysShowBadgeExpansionPromo ||
            (lastSeenBuild != null && lastSeenBuild < _currentBuildNumber)) {
          if (!_debugAlwaysShowBadgeExpansionPromo) {
            await prefs.setInt(_lastSeenBuildKey, _currentBuildNumber);
          }
          if (!mounted) return;

          _isShowingDialog = true;
          final goToBadges = await showDialog<bool>(
            context: overlayContext,
            barrierDismissible: false,
            builder: (ctx) =>
                const _NewBadgesExpansionDialog(newBadgeLabel: '500+'),
          );
          _isShowingDialog = false;

          if (goToBadges == true) {
            badgeProvider.clearNewlyUnlocked();
            final navState = navigatorKey.currentState;
            if (mounted && navState != null) {
              navState.push(
                MaterialPageRoute(builder: (_) => const BadgesScreen()),
              );
            }
            return;
          }
        }
      }

      if (badgeProvider.newRankUnlocked != null) {
        _isShowingDialog = true;
        final rankName = badgeProvider.newRankUnlocked!;

        debugPrint('🏆 [BADGE DEBUG] rank unlock dialog OPEN: $rankName');

        showDialog(
          context: overlayContext,
          barrierDismissible: false,
          builder: (ctx) => AnalyticsScreen(
            name: 'rank_collected',
            child: RankCollectedScreen(rankName: rankName),
          ),
        ).then((_) {
          debugPrint('🏆 [BADGE DEBUG] rank unlock dialog CLOSED: $rankName');
          if (mounted) {
            _isShowingDialog = false;
            badgeProvider.markRankAsSeen();
            debugPrint('🏆 [BADGE DEBUG] markRankAsSeen complete');
          }
        });
        return;
      }

      // 한꺼번에 많은 뱃지가 해제되면(앱 업데이트로 신규 뱃지가 추가된 직후 등)
      // 뱃지마다 팝업을 띄우지 않고 요약 팝업 하나로 대체한다.
      if (badgeProvider.newlyUnlocked.length > _maxIndividualBadgePopups) {
        final count = badgeProvider.newlyUnlocked.length;
        _isShowingDialog = true;
        debugPrint('🏅 [BADGE DEBUG] summary dialog OPEN: $count badges');
        final goToBadges =
            await BadgeSummaryDialog.show(overlayContext, badgeProvider.newlyUnlocked);
        _isShowingDialog = false;
        badgeProvider.clearNewlyUnlocked();
        if (goToBadges == true && mounted) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const BadgesScreen()),
          );
        }
        return;
      }

      if (badgeProvider.newlyUnlocked.isNotEmpty) {
        final newBadge = badgeProvider.newlyUnlocked.first;
        _isShowingDialog = true;

        debugPrint('');
        debugPrint('🚨🚨🚨 [BADGE DEBUG] ABOUT TO OPEN BADGE DIALOG');
        try {
          debugPrint('🚨 name=${newBadge.name}');
          debugPrint('🚨 description=${newBadge.description}');
          debugPrint('🚨 imagePath=${newBadge.imagePath}');
          debugPrint('🚨 category=${newBadge.category}');
          final rawPath = newBadge.imagePath.toString();
          final relPath = rawPath.startsWith('assets/')
              ? rawPath.substring(7)
              : rawPath;
          debugPrint('🚨 expectedStoragePath=badge_images/$relPath');
        } catch (e, st) {
          debugPrint('🔴 [BADGE DEBUG] newBadge inspection failed: $e');
          debugPrint('🔴 [BADGE DEBUG] stack=$st');
        }
        debugPrint('🚨🚨🚨 [BADGE DEBUG] OPENING BadgeCollectedScreen');

        final pendingCount = badgeProvider.newlyUnlocked.length;
        showDialog<String>(
          context: overlayContext,
          barrierDismissible: false,
          builder: (ctx) {
            debugPrint('🏅 [BADGE DEBUG] BadgeCollectedScreen builder called');
            return AnalyticsScreen(
              name: 'badge_collected',
              child: BadgeCollectedScreen(
                achievement: newBadge,
                pendingCount: pendingCount,
              ),
            );
          },
        ).then((result) async {
          debugPrint('🏅 [BADGE DEBUG] BadgeCollectedScreen CLOSED');
          if (mounted) {
            _isShowingDialog = false;
            if (result == 'all') {
              badgeProvider.clearNewlyUnlocked();
              return;
            }
            badgeProvider.markBadgeAsSeen(newBadge);
            debugPrint(
              '🏅 [BADGE DEBUG] markBadgeAsSeen complete for ${newBadge.name}',
            );

            final prefs = await SharedPreferences.getInstance();
            final alreadyShown =
                prefs.getBool('badge_share_promo_shown') ?? false;
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
    } catch (e, st) {
      debugPrint('🔴🔴🔴 [BADGE DEBUG] Notification check error: $e');
      debugPrint('🔴 [BADGE DEBUG] stack=$st');
    } finally {
      debugPrint('🏅 [BADGE DEBUG] _checkNotifications EXIT');
      debugPrint('════════════════════════════════════════════════════');
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    try {
      final badgeProvider = context.watch<BadgeProvider>();

      if ((badgeProvider.newlyUnlocked.isNotEmpty ||
              badgeProvider.newRankUnlocked != null) &&
          !_isShowingDialog) {
        debugPrint(
          '🏅 [BADGE DEBUG] build detected pending unlock '
          'badges=${badgeProvider.newlyUnlocked.length}, '
          'rank=${badgeProvider.newRankUnlocked}, '
          '_isShowingDialog=$_isShowingDialog',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _checkNotifications(),
        );
      }
    } catch (e) {}

    return widget.child ?? const SizedBox.shrink();
  }
}

class _NewBadgesExpansionDialog extends StatelessWidget {
  final String newBadgeLabel;

  const _NewBadgesExpansionDialog({required this.newBadgeLabel});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
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
                    child:  Text(
                      tr('NEW'),
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
                      tr(newBadgeLabel),
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
                   Text(
                    tr('New Badges Just Landed'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('Countries, cities, landmarks, and flights — a huge batch of new achievements is ready to collect. A few might already be unlocked from your past trips.'),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child:  Text(
                        tr('View New Badges'),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      tr('Close'),
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
                    border: Border.all(
                      color: const Color(0xFF1A1A2E),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3DDAD7).withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
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
    Localizations.maybeLocaleOf(context);
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
                child: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFF999999),
                ),
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
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 22,
                        color: Color(0xFFFFB347),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text:  TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF444444),
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(
                                text: tr('Try 30 days for FREE!\n'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              TextSpan(text: tr('Post your badge on ')),
                              TextSpan(
                                text: tr('Instagram'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE1306C),
                                ),
                              ),
                              TextSpan(text: tr(' or ')),
                              TextSpan(
                                text: tr('Facebook'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1877F2),
                                ),
                              ),
                              TextSpan(text: tr(' and send a screenshot to ')),
                              TextSpan(
                                text: tr('leeahn137@gmail.com'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3DDAD7),
                                ),
                              ),
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
                        border: Border.all(
                          color: const Color(0xFFFFB347),
                          width: 1.2,
                        ),
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFB347),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.share_rounded,
                                  size: 18,
                                  color: Color(0xFFFFB347),
                                ),
                          const SizedBox(width: 8),
                           Text(
                            tr('Share My Badge'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFB347),
                            ),
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
                child:  Text(
                  tr('Maybe later'),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
