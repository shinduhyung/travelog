import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool get isAuthReady => _isAuthReady;
  bool get isSigningIn => _isSigningIn;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    print("🚀 AUTH CHANGED");
    print(" currentUser.uid = ${firebaseUser?.uid}");

    _user = firebaseUser;

    // ✅ [수정] Firestore 저장을 기다리지 않고 즉시 준비 완료 처리
    _isAuthReady = true;

    // ✅ [수정] 인터넷이 없어도 일단 UI를 먼저 그리도록 알림을 먼저 보냄
    notifyListeners();

    // 로그인된 상태라면 백그라운드에서 Firestore 업데이트 시도
    if (_user != null) {
      // ❌ await를 제거했습니다. 인터넷이 연결되면 알아서 업데이트됩니다.
      _saveUserToFirestore(_user!);
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      // Firestore는 오프라인 상태에서도 자체적으로 데이터를 큐에 쌓아두었다가
      // 인터넷이 연결되면 자동으로 서버에 전송합니다.
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastSignInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ Firestore 저장 시도 완료 (UID = ${user.uid})");
    } catch (e) {
      // 인터넷이 없으면 이 에러조차 바로 뜨지 않을 수 있지만,
      // await 없이 호출하므로 앱 실행에는 지장을 주지 않습니다.
      print("⚠️ Firestore user 저장 시도 중 에러: $e");
    }
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
      // 1. 기기에 남은 이전 사용자의 로컬 캐시(SharedPreferences) 모두 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("✅ SharedPreferences 로컬 데이터 초기화 완료");

      // 2. SQLite 내부 DB (여행기, AI 일정 등) 초기화
      await StorageService.instance.clearLocalDatabase();
      print("✅ 로컬 데이터베이스 완전 초기화 완료");

      // 3. Google 로그아웃
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print("⚠️ GoogleSignIn 로그아웃 실패: $e");
      }

      // 4. Firebase 로그아웃
      await _auth.signOut();
    } catch (e, st) {
      print("❌ 로그아웃 실패: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}