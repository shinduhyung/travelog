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

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user == null; // ✅ 게스트 여부
  bool get isAuthReady => _isAuthReady;
  bool get isSigningIn => _isSigningIn;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    print("🚀 AUTH CHANGED");
    print(" currentUser.uid = ${firebaseUser?.uid}");

    _user = firebaseUser;

    _isAuthReady = true;
    notifyListeners();

    if (_user != null) {
      _saveUserToFirestore(_user!);
    }
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
        // 안드로이드: Firebase의 자체 OAuth provider 사용 (Glitch 서버 불필요)
        final provider = OAuthProvider("apple.com");
        provider.addScope('email');
        provider.addScope('name');

        await _auth.signInWithProvider(provider);
      } else {
        // iOS: 기존과 동일하게 네이티브 Apple 로그인 사용
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