import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/data/geo_data.dart';
import 'package:jidoapp/widgets/soulmate_comparison.dart';
void main(){
 testWidgets('Shared and unique visits stay grouped under their country',(tester)async{
  GeoData.setForTest(GeoData.fromJsonStrings([
    jsonEncode({'FRA':{'n':'France','a2':'FR','p':[]},'JPN':{'n':'Japan','a2':'JP','p':[]}}),
    jsonEncode({'Paris':['FR',0,0,1,0],'Tokyo':['JP',0,0,1,0],'Lyon':['FR',0,0,1,0]}),
    '{}','{}','{}','{}','{}',
  ]));
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:SoulmateComparison(names:{'FR':'France','JP':'Japan'},mine:{'cities':['Paris','Lyon']},match:{'countries':<String>[],'cities':['Paris','Tokyo'],'landmarks':<String>[],'unesco':<String>[]})))));
  await tester.tap(find.text('Cities'));await tester.pumpAndSettle();
  expect(find.text('France'),findsOneWidget);expect(find.text('Paris'),findsOneWidget);expect(find.text('Tokyo'),findsNothing);
  await tester.tap(find.text('Only them 1'));await tester.pumpAndSettle();
  expect(find.text('Japan'),findsOneWidget);expect(find.text('Tokyo'),findsOneWidget);expect(find.text('Paris'),findsNothing);
  await tester.tap(find.text('Only you 1'));await tester.pumpAndSettle();
  expect(find.text('France'),findsOneWidget);expect(find.text('Lyon'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
