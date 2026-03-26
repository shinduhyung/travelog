// lib/screens/city_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;

// ====================================================================
// 모달 헬퍼 (allCities에서 풀 데이터 City 조회 → 국가 테마색 보장)
// ====================================================================

void _showCityModal(BuildContext context, City city) {
  final provider = Provider.of<CityProvider>(context, listen: false);
  final fullCity = provider.allCities.firstWhere(
        (c) => c.name == city.name && c.countryIsoA2.isNotEmpty,
    orElse: () => city,
  );
  showExternalCityDetailsModal(context, fullCity);
}

String _fe(String? code){if(code==null)return'';final c=code.trim().toUpperCase();if(c.length!=2)return'';final a=c.codeUnitAt(0),b=c.codeUnitAt(1);if(a<65||a>90||b<65||b>90)return'';return String.fromCharCode(0x1F1E6+(a-65))+String.fromCharCode(0x1F1E6+(b-65));}
String _cf(City city){final iso=city.countryIsoA2.trim();return iso.length==2?_fe(iso):_fe(_im[city.country.trim()]);}
const Map<String,String> _im={'Afghanistan':'AF','Albania':'AL','Algeria':'DZ','Argentina':'AR','Armenia':'AM','Australia':'AU','Austria':'AT','Azerbaijan':'AZ','Bahrain':'BH','Bangladesh':'BD','Belarus':'BY','Belgium':'BE','Bolivia':'BO','Brazil':'BR','Bulgaria':'BG','Cambodia':'KH','Canada':'CA','Chile':'CL','China':'CN','Colombia':'CO','Croatia':'HR','Cuba':'CU','Czech Republic':'CZ','Czechia':'CZ','Denmark':'DK','Ecuador':'EC','Egypt':'EG','Ethiopia':'ET','Finland':'FI','France':'FR','Georgia':'GE','Germany':'DE','Ghana':'GH','Greece':'GR','Guatemala':'GT','Hong Kong':'HK','Hungary':'HU','India':'IN','Indonesia':'ID','Iran':'IR','Iraq':'IQ','Ireland':'IE','Israel':'IL','Italy':'IT','Jamaica':'JM','Japan':'JP','Jordan':'JO','Kazakhstan':'KZ','Kenya':'KE','Kuwait':'KW','Lebanon':'LB','Libya':'LY','Malaysia':'MY','Mexico':'MX','Morocco':'MA','Myanmar':'MM','Nepal':'NP','Netherlands':'NL','New Zealand':'NZ','Nigeria':'NG','Norway':'NO','Pakistan':'PK','Panama':'PA','Paraguay':'PY','Peru':'PE','Philippines':'PH','Poland':'PL','Portugal':'PT','Qatar':'QA','Romania':'RO','Russia':'RU','Saudi Arabia':'SA','Senegal':'SN','Serbia':'RS','Singapore':'SG','Slovakia':'SK','Slovenia':'SI','South Africa':'ZA','South Korea':'KR','Korea':'KR','Republic of Korea':'KR','Spain':'ES','Sri Lanka':'LK','Sudan':'SD','Sweden':'SE','Switzerland':'CH','Syria':'SY','Taiwan':'TW','Tanzania':'TZ','Thailand':'TH','Tunisia':'TN','Turkey':'TR','Turkiye':'TR','Ukraine':'UA','United Arab Emirates':'AE','UAE':'AE','United Kingdom':'GB','UK':'GB','United States':'US','USA':'US','United States of America':'US','Uruguay':'UY','Uzbekistan':'UZ','Venezuela':'VE','Vietnam':'VN','Yemen':'YE','Zimbabwe':'ZW','North Korea':'KP','Democratic Republic of the Congo':'CD','Congo':'CG','Ivory Coast':'CI','Dominican Republic':'DO','El Salvador':'SV','Costa Rica':'CR','Honduras':'HN','Nicaragua':'NI','Puerto Rico':'PR'};

class _C{static const Color bg=Color(0xFFF7F7F5),surface=Colors.white,ink=Color(0xFF141414),inkMid=Color(0xFF5C5C5C),inkLight=Color(0xFFAAAAAA),divider=Color(0xFFE8E8E4);}
const Map<String,Color> _cc={'Asia':Color(0xFFF48FB1),'Europe':Color(0xFFFFCA28),'Africa':Color(0xFF8D6E63),'North America':Color(0xFF90CAF9),'South America':Color(0xFF66BB6A),'Oceania':Color(0xFFCE93D8)};
class _HC{static const Color history=Color(0xFF7A5C3C),imperial=Color(0xFF6B3D99);}

class CityHistoryTabScreen extends StatelessWidget{
  const CityHistoryTabScreen({super.key});
  @override
  Widget build(BuildContext context){
    return Consumer<CityProvider>(builder:(context,provider,child){
      if(provider.isLoading)return const Center(child:CircularProgressIndicator(strokeWidth:2,color:_C.ink));
      final allOldest=provider.oldestCities.where((c)=>c.altitude!=0).toList();
      final visited=provider.visitedCities;
      const imperialNames=['Rome','Istanbul','Beijing',"Xi'an",'Baghdad','Damascus','Cairo','Alexandria','Athens','Vienna','Saint Petersburg','Moscow','Berlin','Paris','London','Madrid','Tokyo'];
      final imperialVisited=imperialNames.where((n)=>visited.contains(n)).length;
      final imperialCities=imperialNames.map((n)=>provider.allCities.firstWhereOrNull((c)=>c.name==n)).whereType<City>().toList();
      // Collections: 1개 있고 완료 여부만 카운트
      final imperialCompleted=imperialNames.every((n)=>visited.contains(n))?1:0;
      final pct=imperialNames.isNotEmpty?imperialVisited/imperialNames.length:0.0;

      return SingleChildScrollView(physics:const BouncingScrollPhysics(),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _SH(label:'RANKINGS'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_OldestCard(allData:allOldest,visitedNames:visited,useDefaultColor:provider.useDefaultCityRankingBarColor)),
        const _SH(label:'COLLECTIONS'),
        // Summary bar: "0 of 1 collections" (단 1개)
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:_C.ink,borderRadius:BorderRadius.circular(14)),
          child:Row(children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('$imperialCompleted of 1 collections',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:-0.5)),
              const SizedBox(height:4),
              Text(imperialCompleted==0?'No collections fully completed yet':'All collections completed! 🎉',style:const TextStyle(fontSize:12,color:Color(0xFF888888))),
              const SizedBox(height:14),
              ClipRRect(borderRadius:BorderRadius.circular(4),child:SizedBox(height:6,child:Stack(children:[Container(color:const Color(0xFF2E2E2E)),FractionallySizedBox(widthFactor:pct,child:Container(color:_HC.imperial))]))),
            ])),
            const SizedBox(width:20),
            _AP(value:pct),
          ]),
        )),
        const SizedBox(height:16),
        Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:_ImperialCard(visitedNames:visited,provider:provider,cities:imperialCities,names:imperialNames)),
        const SizedBox(height:32),
      ]));
    });
  }
}

class CityHistoryScreen extends StatelessWidget{
  const CityHistoryScreen({super.key});
  @override Widget build(BuildContext context)=>const CityHistoryTabScreen();
}

class _SH extends StatelessWidget{final String label;const _SH({required this.label});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,24,16,12),child:Row(children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,letterSpacing:2.0,color:_C.inkLight)),const SizedBox(width:12),Expanded(child:Container(height:1,color:_C.divider))]));}

class _OldestCard extends StatefulWidget{
  final List<City> allData;final Set<String> visitedNames;final bool useDefaultColor;
  const _OldestCard({required this.allData,required this.visitedNames,required this.useDefaultColor});
  @override State<_OldestCard> createState()=>_OldestCardState();
}
class _OldestCardState extends State<_OldestCard>{
  List<City> _list=[];String _cont='World';
  final List<String> _conts=['World','Asia','Europe','Africa','North America','South America','Oceania'];
  @override void initState(){super.initState();_prep();}
  void _prep(){
    List<City> l=_cont=='World'?List.from(widget.allData):widget.allData.where((c)=>c.continent==_cont).toList();
    l.sort((a,b)=>a.altitude.compareTo(b.altitude));
    setState(()=>_list=l.take(_cont=='World'?30:10).toList());
  }
  @override
  Widget build(BuildContext context){
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        Container(padding:const EdgeInsets.all(12),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_C.divider))),
          child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:_HC.history.withOpacity(0.10),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.history_edu_outlined,size:20,color:_HC.history)),
            const SizedBox(width:12),
            const Expanded(child:Text('Oldest Cities',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:_C.ink,letterSpacing:-0.2))),
            Container(height:36,padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:_C.bg,borderRadius:BorderRadius.circular(8),border:Border.all(color:_C.divider)),
                child:DropdownButtonHideUnderline(child:DropdownButton<String>(value:_cont,icon:const Icon(Icons.keyboard_arrow_down_rounded,size:16,color:_C.inkMid),style:const TextStyle(fontSize:12,color:_C.ink,fontWeight:FontWeight.w600),items:_conts.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)setState((){_cont=v;_prep();}); }))),
          ]),
        ),
        SizedBox(height:360,child:ListView.builder(
          physics:const BouncingScrollPhysics(),
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          itemCount:_list.length,
          itemBuilder:(context,index){
            final item=_list[index];final isV=widget.visitedNames.contains(item.name);final rank=index+1;
            final age=item.altitude;
            final topVal=_list.isNotEmpty?_list.first.altitude.abs():1;
            final barFrac=topVal==0?0.0:(age.abs()/topVal).toDouble().clamp(0.0,1.0);
            final barColor=widget.useDefaultColor?_HC.history:(_cc[item.continent]??_HC.history);
            final ageStr=age<0?'${age.abs()} BC':'$age AD';
            return GestureDetector(
              onTap:()=>_showCityModal(context,item),
              child:Container(
                margin:const EdgeInsets.symmetric(vertical:3),
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
                decoration:BoxDecoration(color:isV?_HC.history.withOpacity(0.05):Colors.transparent,borderRadius:BorderRadius.circular(8),border:Border(left:BorderSide(color:isV?_HC.history:Colors.transparent,width:2.5))),
                child:Row(children:[
                  SizedBox(width:28,child:Text(rank<=3?(rank==1?'🥇':rank==2?'🥈':'🥉'):'$rank',style:TextStyle(fontSize:rank<=3?16:12,fontWeight:FontWeight.w700,color:_C.inkLight),textAlign:TextAlign.center)),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[
                      Expanded(child:Text(item.name,style:TextStyle(fontSize:13,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:_C.ink),overflow:TextOverflow.ellipsis)),
                      if(isV)...[const SizedBox(width:4),const Icon(Icons.check_circle_rounded,size:14,color:_HC.history)],
                      const SizedBox(width:6),
                      Text(ageStr,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_C.ink)),
                    ]),
                    const SizedBox(height:5),
                    ClipRRect(borderRadius:BorderRadius.circular(3),child:LinearProgressIndicator(value:barFrac,minHeight:3,backgroundColor:_C.divider,valueColor:AlwaysStoppedAnimation<Color>(barColor))),
                    const SizedBox(height:3),
                    Row(children:[Text(_cf(item),style:const TextStyle(fontSize:11)),const SizedBox(width:4),Text(item.country,style:const TextStyle(fontSize:10,color:_C.inkLight))]),
                  ])),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }
}

class _ImperialCard extends StatefulWidget{
  final Set<String> visitedNames;final CityProvider provider;final List<City> cities;final List<String> names;
  const _ImperialCard({required this.visitedNames,required this.provider,required this.cities,required this.names});
  @override State<_ImperialCard> createState()=>_ImperialCardState();
}
class _ImperialCardState extends State<_ImperialCard> with SingleTickerProviderStateMixin{
  bool _exp=false;late AnimationController _ctrl;late Animation<double> _rA,_fA;
  @override void initState(){super.initState();_ctrl=AnimationController(duration:const Duration(milliseconds:250),vsync:this);_rA=Tween(begin:0.0,end:0.5).animate(CurvedAnimation(parent:_ctrl,curve:Curves.easeInOut));_fA=CurvedAnimation(parent:_ctrl,curve:Curves.easeIn);}
  @override void dispose(){_ctrl.dispose();super.dispose();}
  void _toggle(){setState((){_exp=!_exp;_exp?_ctrl.forward():_ctrl.reverse();});}
  @override
  Widget build(BuildContext context){
    final total=widget.names.length;
    final vis=widget.names.where((n)=>widget.visitedNames.contains(n)).length;
    final pct=total>0?vis/total:0.0;
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        InkWell(onTap:_toggle,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:_HC.imperial.withOpacity(0.10),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.account_balance_outlined,size:20,color:_HC.imperial)),
          const SizedBox(width:14),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('HISTORY',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5,color:_HC.imperial)),
            SizedBox(height:2),
            Text('Former Imperial Capitals',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:_C.ink,letterSpacing:-0.2)),
          ])),
          GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CityStatsMapScreen(cities:widget.cities,title:'Imperial Capitals',markerColor:_HC.imperial))),
              child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:_C.bg,borderRadius:BorderRadius.circular(8),border:Border.all(color:_C.divider)),child:Row(mainAxisSize:MainAxisSize.min,children:const[Icon(Icons.map_outlined,size:14,color:_C.inkMid),SizedBox(width:4),Text('Map',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:_C.inkMid))]))),
          const SizedBox(width:4),
          RotationTransition(turns:_rA,child:const Icon(Icons.keyboard_arrow_down_rounded,size:22,color:_C.inkLight)),
        ]))),
        Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14),child:Column(children:[
          ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:pct,minHeight:5,backgroundColor:_C.divider,valueColor:const AlwaysStoppedAnimation<Color>(_HC.imperial))),
          const SizedBox(height:8),
          Row(children:[_Ch(label:'Visited',value:'$vis',color:_HC.imperial),const SizedBox(width:8),_Ch(label:'Remaining',value:'${total-vis}',color:_C.inkLight),const Spacer(),Text('${(pct*100).round()}%',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:pct>0?_HC.imperial:_C.inkLight,letterSpacing:-0.5))]),
        ])),
        AnimatedSize(duration:const Duration(milliseconds:280),curve:Curves.easeInOut,child:_exp
            ?FadeTransition(opacity:_fA,child:Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(16,4,16,16),decoration:const BoxDecoration(border:Border(top:BorderSide(color:_C.divider))),
          child:Wrap(spacing:7,runSpacing:7,children:widget.names.map((name){
            final isV=widget.visitedNames.contains(name);
            final cityObj=widget.provider.allCities.firstWhereOrNull((c)=>c.name==name);
            final flag=cityObj!=null?_cf(cityObj):'';
            return GestureDetector(onTap:cityObj!=null?()=>_showCityModal(context,cityObj):null,
                child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),decoration:BoxDecoration(color:isV?_HC.imperial:_C.bg,borderRadius:BorderRadius.circular(20),border:Border.all(color:isV?_HC.imperial:_C.divider)),
                    child:Row(mainAxisSize:MainAxisSize.min,children:[if(flag.isNotEmpty)...[Text(flag,style:const TextStyle(fontSize:11)),const SizedBox(width:5)],Text(name,style:TextStyle(fontSize:12,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:isV?Colors.white:_C.inkMid))])));
          }).toList()),
        ))
            :const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _AP extends StatelessWidget{final double value;const _AP({required this.value});@override Widget build(BuildContext context)=>SizedBox(width:68,height:68,child:Stack(alignment:Alignment.center,children:[CustomPaint(size:const Size(68,68),painter:_APainter(value:value)),Column(mainAxisSize:MainAxisSize.min,children:[Text('${(value*100).round()}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Colors.white,height:1)),const Text('%',style:TextStyle(fontSize:10,color:Color(0xFF888888)))])]));}
class _APainter extends CustomPainter{final double value;const _APainter({required this.value});@override void paint(Canvas canvas,Size size){final c=Offset(size.width/2,size.height/2);final r=size.width/2-4;canvas.drawCircle(c,r,Paint()..color=const Color(0xFF2E2E2E)..style=PaintingStyle.stroke..strokeWidth=4.0);if(value>0)canvas.drawArc(Rect.fromCircle(center:c,radius:r),-math.pi/2,2*math.pi*value,false,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=4.0..strokeCap=StrokeCap.round);}@override bool shouldRepaint(_APainter old)=>old.value!=value;}
class _Ch extends StatelessWidget{final String label,value;final Color color;const _Ch({required this.label,required this.value,required this.color});@override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.baseline,textBaseline:TextBaseline.alphabetic,children:[Text(value,style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:color)),const SizedBox(width:3),Text(label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w500,color:_C.inkLight,letterSpacing:0.3))]);}