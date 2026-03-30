import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:jidoapp/services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final GoogleSignIn _googleSignIn = _createGoogleSignIn();

  GoogleSignIn _createGoogleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(
        clientId: '127546533956-dgquefldu0671hkjbd0obr357ke078he.apps.googleusercontent.com',
      );
    } else if (Platform.isIOS) {
      return GoogleSignIn(
        clientId: '127546533956-i1o2tnjc9uf65m6t0p4lp7hl2tak15s5.apps.googleusercontent.com',
        serverClientId: '127546533956-dgquefldu0671hkjbd0obr357ke078he.apps.googleusercontent.com',
      );
    } else {
      return GoogleSignIn();
    }
  }

  User? _user;
  bool _isAuthReady = false;
  bool _isSigningIn = false;

  // 로그인 후 Provider들이 처리해야 할 액션을 담는 변수
  // 'upload': 로컬 데이터를 Firestore로 업로드 (케이스 1 - 새 계정)
  // 'reload': Firestore 데이터로 로컬 덮어씌우기 (케이스 2 - 기존 계정)
  // null: 액션 없음
  String? _pendingLoginAction;
  String? get pendingLoginAction => _pendingLoginAction;

  // 케이스 1/2 처리 완료 여부 — login_prompt_screen에서 대기용
  bool _isHandlingLoginAction = false;
  bool get isHandlingLoginAction => _isHandlingLoginAction;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user == null;
  bool get isAuthReady => _isAuthReady;
  bool get isSigningIn => _isSigningIn;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    print("🚀 AUTH CHANGED");
    print(" currentUser.uid = ${firebaseUser?.uid}");

    final bool wasGuest = _user == null;
    final bool isNowLoggedIn = firebaseUser != null;

    _user = firebaseUser;

    if (isNowLoggedIn) {
      _saveUserToFirestore(firebaseUser);

      // 비로그인 → 로그인 전환인 경우에만 케이스 1/2 판단
      if (wasGuest) {
        await _handleGuestToLoginTransition(firebaseUser.uid);
      }
    }

    _isAuthReady = true;
    notifyListeners();
  }

  // 비로그인 → 로그인 시 케이스 1/2 판단
  Future<void> _handleGuestToLoginTransition(String uid) async {
    _isHandlingLoginAction = true;
    notifyListeners();

    try {
      final bool firestoreHasData = await _checkFirestoreHasUserData(uid);

      if (firestoreHasData) {
        print("✅ 기존 계정 감지 → Firestore 데이터로 덮어씌우기 (케이스 2)");
        _pendingLoginAction = 'reload';
      } else {
        print("✅ 새 계정 감지 → 로컬 데이터를 Firestore로 업로드 (케이스 1)");
        _pendingLoginAction = 'upload';
      }
    } catch (e) {
      print("⚠️ 게스트→로그인 전환 처리 중 오류: $e");
      _pendingLoginAction = 'reload';
    }
    // _isHandlingLoginAction은 clearPendingLoginAction()에서 false로 변경
    notifyListeners();
  }

  // Firestore에 유저 데이터가 있는지 확인
  // 주요 데이터 필드 하나라도 있으면 true 반환
  Future<bool> _checkFirestoreHasUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // 핵심 여행 데이터 필드 중 하나라도 있으면 기존 계정으로 판단
      const dataFields = [
        'country_visits_v2',
        'city_visit_details_v3',
        'airport_visit_history',
        'saved_airlines_data',
        'visited_landmarks',
        'visited_unesco_sites',
      ];

      return dataFields.any((field) => data.containsKey(field));
    } catch (e) {
      print("⚠️ Firestore 데이터 확인 오류: $e");
      return false;
    }
  }

  // Provider들이 pendingLoginAction을 처리한 후 호출하여 초기화
  void clearPendingLoginAction() {
    _pendingLoginAction = null;
    _isHandlingLoginAction = false;
    notifyListeners();
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastSignInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ Firestore 저장 시도 완료 (UID = ${user.uid})");
    } catch (e) {
      print("⚠️ Firestore user 저장 시도 중 에러: $e");
    }
  }

  // 🍎 Apple 로그인
  Future<void> signInWithApple() async {
    try {
      if (Platform.isAndroid) {
        final provider = OAuthProvider("apple.com");
        provider.addScope('email');
        provider.addScope('name');
        await _auth.signInWithProvider(provider);
      } else {
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        final OAuthCredential credential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );

        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 🔐 Google 로그인
  Future<void> signInWithGoogle() async {
    if (_isSigningIn) return;
    _isSigningIn = true;
    notifyListeners();

    try {
      print("🔥 Google 로그인 시작 (kIsWeb=$kIsWeb)");

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("⚠️ Google 로그인 취소됨");
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print(" Firebase 로그인 성공: ${userCredential.user?.email}");
    } catch (e, st) {
      print("❌ Google 로그인 실패: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  // 🔥 로그아웃
  // 케이스 3: SharedPreferences + SQLite 초기화 후 로그아웃
  // → _onAuthStateChanged(null)이 호출되고 main.dart에서 앱을 재시작하여
  //   Provider 인스턴스가 새로 생성되므로 메모리도 자동 초기화됨
  Future<void> signOut() async {
    print("🔥 로그아웃 실행 및 로컬 캐시 초기화");
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("✅ SharedPreferences 로컬 데이터 초기화 완료");

      await StorageService.instance.clearLocalDatabase();
      print("✅ 로컬 데이터베이스 완전 초기화 완료");

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print("⚠️ GoogleSignIn 로그아웃 실패: $e");
      }

      await _auth.signOut();
    } catch (e, st) {
      print("❌ 로그아웃 실패: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}