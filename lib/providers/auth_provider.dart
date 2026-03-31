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

    _user = firebaseUser;

    if (firebaseUser != null) {
      _saveUserToFirestore(firebaseUser);
    }

    _isAuthReady = true;
    notifyListeners();
  }

  // Firebase 로그인 전에 호출 — UID로 Firestore 조회해서 케이스 1/2 판단
  Future<void> _prepareLoginAction(String uid) async {
    _isHandlingLoginAction = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      final bool isExistingUser =
          doc.exists && (doc.data()?['onboardingCompleted'] == true);
      print("🔍 [_prepareLoginAction] doc.exists=${doc.exists}, onboardingCompleted=${doc.data()?['onboardingCompleted']}, isExistingUser=$isExistingUser");

      if (isExistingUser) {
        print("✅ 기존 계정 확인 (onboardingCompleted=true) → reload 예약 (케이스 2)");
        _pendingLoginAction = 'reload';
      } else {
        print("✅ 새 계정 확인 (onboardingCompleted 없음) → upload 예약 (케이스 1)");
        _pendingLoginAction = 'upload';
        // 플래그 저장 — 이후 로그인부터는 기존 계정으로 처리
        await _firestore.collection('users').doc(uid).set({
          'onboardingCompleted': true,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("⚠️ 케이스 판단 오류: $e → 안전하게 reload");
      _pendingLoginAction = 'reload';
    }
    notifyListeners();
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
        // Android: signInWithProvider 결과로 UID 확인 후 케이스 판단
        final userCredential = await _auth.signInWithProvider(provider);
        if (userCredential.user != null) {
          await _prepareLoginAction(userCredential.user!.uid);
          notifyListeners();
        }
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

        // iOS: userIdentifier가 Firebase UID와 동일
        final String appleUid = appleCredential.userIdentifier ?? "";
        if (appleUid.isNotEmpty) {
          await _prepareLoginAction(appleUid);
        }

        final OAuthCredential credential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );

        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      _pendingLoginAction = null;
      _isHandlingLoginAction = false;
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

      // Firebase 로그인 전에 UID로 Firestore 조회 → 케이스 1/2 미리 판단
      await _prepareLoginAction(googleUser.id);

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
      _pendingLoginAction = null;
      _isHandlingLoginAction = false;
      rethrow;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  // 🔥 로그아웃
  // 케이스 3: 로그아웃
  // → _onAuthStateChanged(null) 호출 → main.dart에서 _sessionKey++ → MultiProvider 재생성
  // → 메모리는 Provider 재생성으로 초기화됨
  // → 로컬 SharedPreferences/SQLite는 지우지 않음
  //   (재로그인 시 reloadFromServer()가 Firestore로 덮어씌우기 때문)
  Future<void> signOut() async {
    print("🔥 로그아웃 실행");
    try {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print("⚠️ GoogleSignIn 로그아웃 실패: $e");
      }

      await _auth.signOut();
      print("✅ 로그아웃 완료");
    } catch (e, st) {
      print("❌ 로그아웃 실패: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}