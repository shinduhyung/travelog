// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';
import 'package:jidoapp/services/ad_service.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onStartTutorial;

  const WelcomeScreen({super.key, required this.onStartTutorial});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    AdService.instance.setTutorialActive();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    AdService.instance.clearTutorialActive();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openLoginPrompt() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginPromptScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1ABFBC),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // 로고
                    Image.asset(
                      'assets/icons/airplane_cutout_transparent.png',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.airplanemode_active_rounded,
                        size: 100,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 앱 이름
                    Text(
                      'Travelog',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 슬로건
                    Text(
                      'Your journey, beautifully tracked.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),

                    const Spacer(flex: 4),

                    // 신규 유저 버튼
                    _PrimaryButton(
                      label: "Get Started",
                      onTap: widget.onStartTutorial,
                    ),
                    const SizedBox(height: 14),

                    // 기존 유저 로그인 버튼
                    _SecondaryButton(
                      label: "I already have an account",
                      onTap: _openLoginPrompt,
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1ABFBC),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}