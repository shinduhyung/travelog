import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/screens/flight_log_list_screen.dart';
import 'package:jidoapp/widgets/flight_log_actions.dart';

class Flights extends ChangeNotifier implements AirlineProvider {
  final logs = [for(var i=0;i<2;i++) FlightLog(id:'$i',flightNumber:'KE${i+1}',date:'2026-01-01',departureIata:'ICN',arrivalIata:'NRT',airlineCode:'KE',airlineName:'Korean Air')];
  @override bool get isLoading=>false;
  @override List<FlightLog> get allFlightLogs=>logs;
  @override List<Airline> get airlines=>[];
  @override List<FlightConnection> get flightConnections=>[];
  @override void removeFlightLog(FlightLog log){logs.removeWhere((v)=>v.id==log.id);notifyListeners();}
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
 testWidgets('Compact footer fits at 320 with large text, in delete cancel save order',(tester)async{
  tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(builder:(c,w)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:const TextScaler.linear(1.5)),child:w!),home:Scaffold(bottomNavigationBar:FlightLogActions(onDelete:(){},onCancel:(){},onSave:(){},busy:false))));
  expect(tester.getCenter(find.text('Delete')).dx,lessThan(tester.getCenter(find.text('Cancel')).dx));
  expect(tester.getCenter(find.text('Cancel')).dx,lessThan(tester.getCenter(find.text('Save Changes')).dx));
  expect(tester.takeException(),isNull);
 });
 testWidgets('View toggle restores cards; delete mode never bulk deletes',(tester)async{
  final flights=Flights();
  await tester.pumpWidget(ChangeNotifierProvider<AirlineProvider>.value(value:flights,child:const MaterialApp(home:FlightLogListScreen())));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('flight-view-toggle')));await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('compact-flight-0')),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('flight-view-toggle')));await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('compact-flight-0')),findsNothing);
  await tester.tap(find.byKey(const ValueKey('flight-delete-mode')));await tester.pumpAndSettle();
  expect(flights.logs.length,2);expect(find.byKey(const ValueKey('delete-flight-0')),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('delete-flight-0')));await tester.pumpAndSettle();
  await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(flights.logs.length,2);
  await tester.tap(find.byKey(const ValueKey('delete-flight-0')));await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));await tester.pumpAndSettle();
  expect(flights.logs.map((l)=>l.id),['1']);expect(tester.takeException(),isNull);
 });
}
