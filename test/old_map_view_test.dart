// TODO(old-map): 고지도 위젯을 되살릴 때 아래 주석을 해제한다.
// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:jidoapp/widgets/old_map_view.dart';
//
// void main() {
//   testWidgets('OldMapView draws the vector map and asks for country colors', (tester) async {
//     final asked = <String>[];
//     await tester.pumpWidget(MaterialApp(
//       home: SizedBox(
//         width: 720,
//         height: 400,
//         child: OldMapView(colorFor: (iso) {
//           asked.add(iso);
//           return iso == 'EGY' ? Colors.red : null;
//         }),
//       ),
//     ));
//     await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
//     await tester.pump();
//     expect(tester.takeException(), isNull);
//     expect(asked, containsAll(['EGY', 'FRA', 'ITA']));
//     expect(find.byType(CustomPaint), findsWidgets);
//   });
// }

void main() {}
