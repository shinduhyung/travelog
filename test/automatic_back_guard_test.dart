import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/widgets/automatic_back_guard.dart';
class Observer extends NavigatorObserver with ChangeNotifier {
 Route<dynamic>? route;
 @override void didPush(Route<dynamic> r,Route<dynamic>? old){route=r;notifyListeners();}
 @override void didPop(Route<dynamic> r,Route<dynamic>? old){route=old;notifyListeners();}
}
void main(){testWidgets('Legacy back hides for app bars and remains on plain screens',(tester)async{
 final key=GlobalKey<NavigatorState>(),obs=Observer();
 await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[obs],builder:(c,child)=>Stack(children:[child!,AutomaticBackGuard(navigatorKey:key,changes:obs,currentRoute:()=>obs.route,child:const Text('legacy back'))]),home:const Scaffold(body:Text('root'))));await tester.pumpAndSettle();
 key.currentState!.push(MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Native')),body:const SizedBox())));await tester.pumpAndSettle();
 expect(find.text('legacy back'),findsNothing);expect(find.byType(BackButton),findsOneWidget);
 key.currentState!.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('plain'))));await tester.pumpAndSettle();expect(find.text('legacy back'),findsOneWidget);
 key.currentState!.pop();await tester.pumpAndSettle();expect(find.text('legacy back'),findsNothing);
 });}
