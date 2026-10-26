// TODO(old-map): 고지도(이드리시) 벡터 지도 위젯. 되살릴 때 아래 전체의 `// ` 접두사를 제거한다.
// 데이터/스크립트: tool/old_maps/idrisi, 에셋: assets/old_maps/idrisi_vector.json (pubspec 등록도 주석 해제)

// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
//
// /// 고지도에서 추출한 좌표(벡터)만으로 그리는 세계 지도 뷰.
// ///
// /// 데이터는 `tool/old_maps/idrisi`에서 만든다: 고지도의 육지 윤곽과, 현대 국가
// /// 폴리곤을 고지도 좌표로 변환해 육지 안으로 잘라낸 것. 이미지는 쓰지 않으며
// /// 색·질감은 [OldMapStyle]로 나중에 확장한다.
// class OldMapSpec {
//   final String vectorAsset;
//
//   const OldMapSpec({required this.vectorAsset});
//
//   static const idrisi = OldMapSpec(
//     vectorAsset: 'assets/old_maps/idrisi_vector.json',
//   );
// }
//
// class OldMapStyle {
//   final Color sea;
//   final Color land;
//   final Color landOutline;
//   final Color border;
//
//   const OldMapStyle({
//     this.sea = const Color(0xFF243444),
//     this.land = const Color(0xFFE9D9A6),
//     this.landOutline = const Color(0xFF785A32),
//     this.border = const Color(0x556E502D),
//   });
// }
//
// class _OldMapData {
//   final double width;
//   final double height;
//   final Path land;
//   final Map<String, Path> countries;
//
//   _OldMapData(this.width, this.height, this.land, this.countries);
//
//   static final _cache = <OldMapSpec, Future<_OldMapData>>{};
//
//   static Future<_OldMapData> load(OldMapSpec spec) =>
//       _cache.putIfAbsent(spec, () async {
//         final json = jsonDecode(await rootBundle.loadString(spec.vectorAsset))
//             as Map<String, dynamic>;
//         final countries = <String, Path>{};
//         (json['countries'] as Map<String, dynamic>).forEach((iso, value) {
//           countries[iso] = _toPath((value as Map)['polygons'] as List);
//         });
//         return _OldMapData(
//           (json['width'] as num).toDouble(),
//           (json['height'] as num).toDouble(),
//           _toPath(json['land'] as List),
//           countries,
//         );
//       });
//
//   /// polygons: [[outer, hole, ...], ...], 각 링은 [[x, y], ...]. 구멍은 evenOdd로 뚫는다.
//   static Path _toPath(List polygons) {
//     final path = Path()..fillType = PathFillType.evenOdd;
//     for (final polygon in polygons) {
//       for (final ring in polygon as List) {
//         path.addPolygon([
//           for (final p in ring as List)
//             Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
//         ], true);
//       }
//     }
//     return path;
//   }
// }
//
// class OldMapView extends StatefulWidget {
//   final OldMapSpec spec;
//   final OldMapStyle style;
//
//   /// ISO A3 코드에 대한 칠할 색. null이면 칠하지 않는다.
//   final Color? Function(String isoA3) colorFor;
//
//   /// 시작 배율. 1이면 지도 전체가 보인다.
//   final double initialScale;
//
//   /// true면 뷰 전체를 바다색으로 채우고, false면 지도 영역만 둥근 모서리로 그린다(카드용).
//   final bool fillBackground;
//
//   const OldMapView({
//     super.key,
//     this.spec = OldMapSpec.idrisi,
//     this.style = const OldMapStyle(),
//     this.initialScale = 2.0,
//     this.fillBackground = true,
//     required this.colorFor,
//   });
//
//   @override
//   State<OldMapView> createState() => _OldMapViewState();
// }
//
// class _OldMapViewState extends State<OldMapView> {
//   // 가로로 긴 지도라 세로 화면에서는 작게 보이므로, 기본은 확대한 상태로 시작한다.
//   static const _initialFocusX = 0.45; // 지도 가로 비율(유럽~서아시아가 중앙에 오도록)
//   double get _initialScale => widget.initialScale;
//
//   final _controller = TransformationController();
//   Size? _initializedFor;
//
//   OldMapSpec get spec => widget.spec;
//   OldMapStyle get style => widget.style;
//   Color? Function(String) get colorFor => widget.colorFor;
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   void _applyInitialZoom(Size viewport) {
//     if (_initializedFor == viewport) return;
//     _initializedFor = viewport;
//     final tx = viewport.width / 2 - viewport.width * _initialFocusX * _initialScale;
//     final ty = viewport.height / 2 * (1 - _initialScale);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         _controller.value = Matrix4.identity()
//           ..translate(tx, ty)
//           ..scale(_initialScale);
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<_OldMapData>(
//       future: _OldMapData.load(spec),
//       builder: (context, snapshot) {
//         final data = snapshot.data;
//         if (data == null) {
//           return ColoredBox(
//             color: widget.fillBackground ? style.sea : Colors.transparent,
//             child: const Center(child: CircularProgressIndicator()),
//           );
//         }
//         final colors = <String, Color>{};
//         for (final iso in data.countries.keys) {
//           final c = colorFor(iso);
//           if (c != null) colors[iso] = c;
//         }
//         return ColoredBox(
//           color: widget.fillBackground ? style.sea : Colors.transparent,
//           child: LayoutBuilder(
//             builder: (context, constraints) {
//               _applyInitialZoom(constraints.biggest);
//               return InteractiveViewer(
//                 transformationController: _controller,
//                 minScale: 1,
//                 maxScale: 10,
//                 child: Center(
//                   child: AspectRatio(
//                     aspectRatio: data.width / data.height,
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(
//                         widget.fillBackground ? 0 : 16,
//                       ),
//                       child: CustomPaint(
//                         painter: _OldMapPainter(data, style, colors),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _OldMapPainter extends CustomPainter {
//   final _OldMapData data;
//   final OldMapStyle style;
//   final Map<String, Color> colors;
//
//   _OldMapPainter(this.data, this.style, this.colors);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final s = size.width / data.width;
//     canvas.clipRect(Offset.zero & size);
//     canvas.scale(s);
//     canvas.drawRect(
//       Rect.fromLTWH(0, 0, data.width, data.height),
//       Paint()..color = style.sea,
//     );
//     canvas.drawPath(data.land, Paint()..color = style.land);
//
//     final border = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 0.5
//       ..strokeJoin = StrokeJoin.round
//       ..color = style.border;
//     final fill = Paint()..style = PaintingStyle.fill;
//     for (final entry in data.countries.entries) {
//       final color = colors[entry.key];
//       if (color != null) {
//         fill.color = color.withValues(alpha: 0.8);
//         canvas.drawPath(entry.value, fill);
//       }
//       canvas.drawPath(entry.value, border);
//     }
//     canvas.drawPath(
//       data.land,
//       Paint()
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 0.9
//         ..strokeJoin = StrokeJoin.round
//         ..color = style.landOutline,
//     );
//   }
//
//   @override
//   bool shouldRepaint(_OldMapPainter old) =>
//       old.data != data || old.style != style || !_sameColors(old.colors, colors);
//
//   static bool _sameColors(Map<String, Color> a, Map<String, Color> b) {
//     if (a.length != b.length) return false;
//     for (final e in a.entries) {
//       if (b[e.key] != e.value) return false;
//     }
//     return true;
//   }
// }
