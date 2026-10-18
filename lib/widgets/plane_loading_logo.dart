// lib/widgets/plane_loading_logo.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

class PlaneLoadingLogo extends StatefulWidget {
  final double? size;

  const PlaneLoadingLogo({super.key, this.size});

  @override
  State<PlaneLoadingLogo> createState() => _PlaneLoadingLogoState();
}

class _PlaneLoadingLogoState extends State<PlaneLoadingLogo> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/loading.mp4');
      await _controller.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      _controller.setVolume(0.0);
      _controller.setLooping(true);
      _controller.play();

    } catch (e) {
      debugPrint("❌ Video Loading Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 1. 에러 처리
    if (_hasError) {
      return Container(
        color: Colors.white,
        child:  Center(
          child: Text(
            tr("VIDEO LOAD ERROR\n(Check pubspec.yaml)"),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // 2. 로딩 중 처리
    if (!_isInitialized) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3DDAD7),
          ),
        ),
      );
    }

    // 3. 정상 재생: 비율 유지(cover) + 1.15배 확대(scale)
    return SizedBox.expand(
      child: Transform.scale(
        scale: 1.15, // ⭐️ [핵심] 1.15배 확대하여 가장자리를 확실하게 채움
        child: FittedBox(
          fit: BoxFit.cover, // 비율 유지하며 꽉 채우기
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}