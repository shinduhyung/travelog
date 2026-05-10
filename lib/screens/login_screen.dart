// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 이미지 자산 (에러 해결을 위해 pubspec.yaml 확인 필수)
              Image.asset(
                'assets/splash_image.png', // 파일명 철자(spash vs splash) 확인해주세요!
                height: 120, // 이미지 크기를 조금 줄여서 부담스럽지 않게 조정
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지를 못 찾을 경우 엑박 대신 아이콘을 보여주는 안전 장치
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 100,
                    color: Colors.grey,
                  );
                },
              ),
              const SizedBox(height: 25),

              // 2. 부드럽고 Cursive한 느낌의 텍스트 스타일
              const Text(
                "Travelog",
                style: TextStyle(
                  fontSize: 40,
                  // 과한 굵기(Bold) 대신 가벼운 느낌
                  fontWeight: FontWeight.w400,
                  // 이탤릭체로 흘림 효과 (Cursive 느낌)
                  fontStyle: FontStyle.italic,
                  // 명조 계열(Serif)을 사용하여 감성적인 분위기
                  fontFamily: 'Serif',
                  color: Color(0xFF2C3E50), // 찐한 검정 대신 부드러운 다크 네이비/그레이
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "AI Travel Journal",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300, // 얇게 처리하여 세련됨 강조
                  color: Colors.grey,
                  letterSpacing: 3.0, // 여유로운 자간
                ),
              ),
              const SizedBox(height: 60),
              _GoogleSignInButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return InkWell(
      onTap: () async {
        try {
          await authProvider.signInWithGoogle();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login Failed: $e")),
          );
        }
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)), // 아주 연한 테두리
          borderRadius: BorderRadius.circular(40), // 더 둥글게 처리
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1), // 그림자도 아주 연하게
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 로고 텍스트 대신 깔끔한 디자인
            const Text(
              "G",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                fontFamily: 'Roboto', // 구글 로고 느낌
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Sign in with Google",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500, // 너무 두껍지 않게
                color: Color(0xFF4A4A4A), // 부드러운 텍스트 색상
              ),
            ),
          ],
        ),
      ),
    );
  }
}