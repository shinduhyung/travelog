// lib/screens/login_prompt_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/main_screen.dart';

class LoginPromptScreen extends StatefulWidget {
  const LoginPromptScreen({super.key});

  @override
  State<LoginPromptScreen> createState() => _LoginPromptScreenState();
}

class _LoginPromptScreenState extends State<LoginPromptScreen> {
  @override
  void initState() {
    super.initState();
    AdService.instance.setUiOverlayActive();
  }

  @override
  void dispose() {
    AdService.instance.clearUiOverlayActive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 기기의 실제 상단 상태바 높이를 가져옵니다
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // 모달 환경 등에서 높이가 0으로 잡힐 때를 대비한 최소 여백(40) 확보
    final double safeTopPadding = statusBarHeight > 0 ? statusBarHeight : 40.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태바 높이만큼 강제로 빈 공간을 만들어 겹침을 방지합니다
          SizedBox(height: safeTopPadding),

          // 닫기(X) 버튼
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF4A4A4A)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // 스크롤 가능한 본문 영역
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 앱 로고
                  Image.asset(
                    'assets/icons/app_logo_large.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.airplanemode_active_rounded,
                        size: 70,
                        color: Color(0xFFB0C4DE),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 헤더 텍스트
                  const Text(
                    "Sign in to continue",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C3E50),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey,
                        height: 1.6,
                      ),
                      children: [
                        TextSpan(text: "Sign in to enjoy "),
                        TextSpan(
                          text: "Travelog",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF5B8DEF),
                          ),
                        ),
                        TextSpan(text: " for "),
                        TextSpan(
                          text: "free",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D9E75),
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(text: ".\nNo payment needed to get started."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 혜택 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "WHY SIGN IN?",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _BenefitRow(
                          iconColor: Color(0xFFE8F4FF),
                          icon: Icons.check_circle_outline_rounded,
                          iconTint: Color(0xFF378ADD),
                          title: "Free to use, no card required",
                          subtitle: "Core features are always free",
                        ),
                        const SizedBox(height: 14),
                        const _BenefitRow(
                          iconColor: Color(0xFFEAF5EE),
                          icon: Icons.devices_rounded,
                          iconTint: Color(0xFF1D9E75),
                          title: "Synced across all devices",
                          subtitle: "Switch phones without losing your data",
                        ),
                        const SizedBox(height: 14),
                        const _BenefitRow(
                          iconColor: Color(0xFFF5EEFF),
                          icon: Icons.people_alt_outlined,
                          iconTint: Color(0xFF7F77DD),
                          title: "Compare with other travelers",
                          subtitle: "See how your stats stack up globally",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Google 로그인 버튼 (항상)
                  const _GoogleSignInButton(),
                  const SizedBox(height: 12),

                  // Apple 로그인 버튼
                  const _AppleSignInButton(),
                  const SizedBox(height: 16),

                  // 약관 안내
                  const Text(
                    "By signing in you agree to our Terms & Privacy Policy",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final Color iconColor;
  final IconData icon;
  final Color iconTint;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.iconColor,
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconTint, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () async {
        try {
          await authProvider.signInWithGoogle();
          if (!context.mounted) return;

          // 케이스 1/2: pendingLoginAction 처리 완료까지 로딩 표시
          if (authProvider.isHandlingLoginAction ||
              authProvider.pendingLoginAction != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
            // 처리 완료 대기
            while (authProvider.isHandlingLoginAction ||
                authProvider.pendingLoginAction != null) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (context.mounted) Navigator.of(context).pop(); // 로딩 닫기
          }

          if (context.mounted) {
            // My Trips 탭으로 강제 이동
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainScreen(initialIndex: 0),
              ),
                  (route) => false,
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Login failed: $e")),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "G",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'Roboto',
                color: Color(0xFF4285F4),
              ),
            ),
            SizedBox(width: 12),
            Text(
              "Sign in with Google",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () async {
        try {
          await authProvider.signInWithApple();
          if (!context.mounted) return;

          // 케이스 1/2: pendingLoginAction 처리 완료까지 로딩 표시
          if (authProvider.isHandlingLoginAction ||
              authProvider.pendingLoginAction != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
            // 처리 완료 대기
            while (authProvider.isHandlingLoginAction ||
                authProvider.pendingLoginAction != null) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (context.mounted) Navigator.of(context).pop(); // 로딩 닫기
          }

          if (context.mounted) {
            // My Trips 탭으로 강제 이동
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainScreen(initialIndex: 3),
              ),
                  (route) => false,
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Apple Login failed: $e")),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apple,
              color: Colors.white,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              "Sign in with Apple",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}