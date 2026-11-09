import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/screens/travelog_poll_history_screen.dart';

void main() {
  testWidgets('Sample reveal animates to requested percentages and stable tie order', (tester) async {
    tester.view.physicalSize = const Size(384, 832);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TravelogPollHistoryScreen(polls: [], showPreview: true)));
    await tester.pumpAndSettle();
    expect(find.text('Italy'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.text('Which country has the best food?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining(RegExp(r'^\d+%$')), findsWidgets);
    expect(find.text('32%'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('32%'), findsOneWidget);
    expect(find.text('Italy'), findsOneWidget);
    expect(find.text('22%'), findsOneWidget);
    expect(find.text('17%'), findsNWidgets(2));
    expect(find.text('12%'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Mexico')).dy, lessThan(tester.getTopLeft(find.text('France')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Normal history never invents votes or sample results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TravelogPollHistoryScreen(polls: [])));
    await tester.pumpAndSettle();
    expect(find.text('No results revealed yet'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
}
