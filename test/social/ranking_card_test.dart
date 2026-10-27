import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/models/global_stats.dart';
import 'package:jidoapp/social/widgets/ranking_card.dart';

void main() {
  final data = RankingData(
    titleTop: 'Biggest Current',
    titleBottom: 'Account Surpluses',
    subtitle: 'Current account surplus, % of GDP, 2026',
    rows: [
      for (var i = 0; i < 10; i++)
        RankRow(label: 'Papua New Guinea and a very long name $i', value: 35.0 - i * 2, valueText: '~\$${(35 - i * 2)}.0B t'),
    ],
  );

  for (final w in [320.0, 412.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('ranking card ${w.toInt()}w x$scale has no overflow', (tester) async {
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: Center(child: SizedBox(width: w, child: RankingCard(data: data)))),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        FlutterError.onError = old;
        expect(errors, isEmpty, reason: errors.join('\n---\n'));
        expect(find.text('Account Surpluses'), findsOneWidget);
      });
    }
  }
}
