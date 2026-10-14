// lib/my_tile_layer.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

// ⭐️ Stadia Maps Alidade Smooth 타일 사용 - 깔끔한 하얀 배경
class MyTileLayer extends StatelessWidget {
  // ⭐️ [DEBUG] 타일 로드 실패 시 호출되는 콜백. 기본값 null이면 기존과 동일하게 동작.
  final void Function(TileImage tile, Object error, StackTrace? stackTrace)?
  onTileError;

  const MyTileLayer({super.key, this.onTileError});

  @override
  Widget build(BuildContext context) {
    // ⭐️ [FIX] CartoDB(basemaps.cartocdn.com)가 API 키를 요구하게 되어
    // Stadia Maps로 교체함. alidade_smooth 스타일이 기존 Voyager와 비슷한
    // 깔끔한 흰 배경 느낌을 줌.
    const String stadiaApiKey = '8d9872cc-0cc6-4829-837f-d69f297f6576';
    const String whiteMapUrl =
        'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=$stadiaApiKey';
    const String myAppName = 'com.ahnlee.jidoapp';

    return TileLayer(
      urlTemplate: whiteMapUrl,
      userAgentPackageName: myAppName,
      backgroundColor: Colors.white,
      // ⭐️ [DEBUG] 타일 실패 시 콜백 호출 (원래는 조용히 무시되던 부분)
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('[MyTileLayer] tile load error: $error');
        onTileError?.call(tile, error, stackTrace);
      },
    );
  }
}