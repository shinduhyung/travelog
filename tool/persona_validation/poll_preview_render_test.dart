import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/screens/travelog_poll_history_screen.dart';
import 'package:jidoapp/screens/travelog_polls_screen.dart';
import 'package:jidoapp/services/travelog_poll_preview.dart';
void main() {
 testWidgets('render poll result preview', (tester) async {
  tester.view.physicalSize=const Size(384,832);tester.view.devicePixelRatio=1;
  final root=File(Platform.resolvedExecutable).parent.parent.parent.path;
  final fonts=FontLoader('Roboto');
  for(final f in ['roboto-regular.ttf','roboto-medium.ttf','roboto-bold.ttf']) fonts.addFont(Future.value(ByteData.sublistView(File('$root/material_fonts/$f').readAsBytesSync())));
  await fonts.load();
  final icons=FontLoader('MaterialIcons');
  icons.addFont(Future.value(ByteData.sublistView(File('$root/material_fonts/materialicons-regular.otf').readAsBytesSync())));
  await icons.load();
  const key=ValueKey('preview-capture');
  await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'Roboto'),home:const TravelogPollHistoryScreen(polls:[],showPreview:true))));
  await tester.pumpAndSettle();
  Future<void> capture(String name) async {
    await tester.runAsync(() async {
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final picture=await boundary.toImage(pixelRatio:2);
      final bytes=await picture.toByteData(format:ui.ImageByteFormat.png);
      await File('tool/persona_validation/out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }
  await capture('nov5_history_list_render');
  await tester.tap(find.text('Which country has the best food?'));await tester.pumpAndSettle();
  await capture('nov5_result_detail_render');
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'Roboto'),home:TravelogPollsScreen(gateway:TravelogPollWeekPreview()))));
  await tester.pumpAndSettle();
  await capture('nov5_ballot_render');
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
 });
}
