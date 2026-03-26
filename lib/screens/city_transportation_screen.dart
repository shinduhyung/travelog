// lib/screens/city_transportation_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
import 'package:jidoapp/screens/cities_screen.dart';

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
class _TC{static const Color metro=Color(0xFF6B3D99),traffic=Color(0xFFD64545),subway=Color(0xFF3B5C7A),transit=Color(0xFF2A8C74),airport=Color(0xFF3D9EC4);}

class RankingInfo{final String title,metricKey;final IconData icon;final Color themeColor;final num Function(City) valueAccessor;RankingInfo({required this.title,required this.icon,required this.themeColor,required this.metricKey,required this.valueAccessor});}

class CityTransportationScreen extends StatelessWidget{
  const CityTransportationScreen({super.key});
  @override
  Widget build(BuildContext context){
    return Consumer<CityProvider>(builder:(context,provider,child){
      if(provider.isLoading)return const Center(child:CircularProgressIndicator(strokeWidth:2,color:_C.ink));
      final subwayCities=List<City>.from(provider.transportationCities)..sort((a,b)=>a.name.compareTo(b.name));
      final visited=provider.visitedCities;
      final groups=[
        _TG(title:'Cities with Subway',label:'TRANSIT',icon:Icons.train_outlined,color:_TC.subway,cities:subwayCities,names:null),
        _TG(title:'Cities with All Major Transit',label:'TRANSIT',icon:Icons.directions_bus_outlined,color:_TC.transit,cities:provider.allTransitCities,names:null),
        _TG(title:'Cities with 4+ Airports',label:'AIR',icon:Icons.flight_outlined,color:_TC.airport,cities:null,names:const['New York City','London','Los Angeles','Melbourne','Paris','Moscow','Tokyo','Manila','Stockholm','San Francisco','Dubai','Boston']),
      ];
      final completed=groups.where((g){final ns=g.names??g.cities!.map((c)=>c.name).toList();return ns.isNotEmpty&&ns.every((n)=>visited.contains(n));}).length;
      return SingleChildScrollView(physics:const BouncingScrollPhysics(),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _SH(label:'RANKINGS'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_RCard(provider:provider)),
        const _SH(label:'COLLECTIONS'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_SumBar(groups:groups,visited:visited,completed:completed)),
        const SizedBox(height:16),
        ...groups.map((g)=>Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:_ColCard(data:g,visitedNames:visited,provider:provider))),
        const SizedBox(height:32),
      ]));
    });
  }
}

class _SH extends StatelessWidget{final String label;const _SH({required this.label});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,24,16,12),child:Row(children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,letterSpacing:2.0,color:_C.inkLight)),const SizedBox(width:12),Expanded(child:Container(height:1,color:_C.divider))]));}

// ── Ranking Card
class _RCard extends StatefulWidget{final CityProvider provider;const _RCard({required this.provider});@override State<_RCard> createState()=>_RCardState();}
class _RCardState extends State<_RCard>{
  late final List<RankingInfo> _ranks;late RankingInfo _sel;List<City> _list=[];
  String _ft(double m){if(m<0.01)return'0s';final s=(m*60).round();final mn=s~/60,sc=s%60;return mn>0?'${mn}min ${sc}s':'${sc}s';}
  @override void initState(){super.initState();_ranks=[
    RankingInfo(title:'Metro Stations',icon:Icons.train_outlined,themeColor:_TC.metro,metricKey:'station',valueAccessor:(c)=>c.stationsCount),
    RankingInfo(title:'Traffic (per 10km)',icon:Icons.traffic_outlined,themeColor:_TC.traffic,metricKey:'traffic',valueAccessor:(c)=>c.trafficTimeMinutes),
  ];_sel=_ranks.first;_prep();}
  void _prep(){
    final f=_sel.metricKey=='station'
        ?widget.provider.stationCities.where((c)=>c.stationsCount!=0).toList()
        :widget.provider.trafficCities.where((c)=>c.trafficTimeMinutes!=0).toList();
    f.sort((a,b)=>_sel.valueAccessor(b).compareTo(_sel.valueAccessor(a)));
    setState(()=>_list=f.take(30).toList());
  }
  @override
  Widget build(BuildContext context){
    final fmt=NumberFormat.compact();
    final top=_list.isNotEmpty?_sel.valueAccessor(_list.first):1;
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        Container(
          padding:const EdgeInsets.all(12),
          decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_C.divider))),
          child:Row(
            children:_ranks.map((r){
              final active=r==_sel;
              return Expanded(
                child:GestureDetector(
                  onTap:()=>setState((){_sel=r;_prep();}),
                  child:AnimatedContainer(
                    duration:const Duration(milliseconds:200),
                    padding:const EdgeInsets.symmetric(vertical:10),
                    margin:const EdgeInsets.symmetric(horizontal:3),
                    decoration:BoxDecoration(color:active?_C.ink:Colors.transparent,borderRadius:BorderRadius.circular(8)),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(r.icon,size:15,color:active?Colors.white:_C.inkLight),
                      const SizedBox(width:6),
                      Text(r.title,style:TextStyle(fontSize:12,fontWeight:active?FontWeight.w700:FontWeight.w400,color:active?Colors.white:_C.inkLight)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height:360,child:_list.isEmpty
            ?const Center(child:Text('No data',style:TextStyle(color:_C.inkLight)))
            :ListView.builder(
          physics:const BouncingScrollPhysics(),
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          itemCount:_list.length,
          itemBuilder:(context,index){
            final item=_list[index];
            final isVisited=widget.provider.visitedCities.contains(item.name);
            final rank=index+1;
            final value=_sel.valueAccessor(item);
            final barFrac=top==0?0.0:(value/top).toDouble().clamp(0.0,1.0);
            final barColor=widget.provider.useDefaultCityRankingBarColor?_sel.themeColor:(_cc[item.continent]??_sel.themeColor);
            final dStr=_sel.metricKey=='traffic'?_ft(value.toDouble()):fmt.format(value);
            return GestureDetector(
              onTap:()=>_showCityModal(context,item),
              child:Container(
                margin:const EdgeInsets.symmetric(vertical:3),
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
                decoration:BoxDecoration(
                  color:isVisited?_sel.themeColor.withOpacity(0.05):Colors.transparent,
                  borderRadius:BorderRadius.circular(8),
                  border:Border(left:BorderSide(color:isVisited?_sel.themeColor:Colors.transparent,width:2.5)),
                ),
                child:Row(children:[
                  SizedBox(width:28,child:Text(rank<=3?(rank==1?'🥇':rank==2?'🥈':'🥉'):'$rank',
                      style:TextStyle(fontSize:rank<=3?16:12,fontWeight:FontWeight.w700,color:_C.inkLight),textAlign:TextAlign.center)),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[
                      Expanded(child:Text(item.name,style:TextStyle(fontSize:13,fontWeight:isVisited?FontWeight.w700:FontWeight.w500,color:_C.ink),overflow:TextOverflow.ellipsis)),
                      if(isVisited)...[const SizedBox(width:4),Icon(Icons.check_circle_rounded,size:14,color:_sel.themeColor)],
                      const SizedBox(width:6),
                      Text(dStr,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_C.ink)),
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
        ),
        ),
      ]),
    );
  }
}

class _TG{final String title,label;final IconData icon;final Color color;final List<City>? cities;final List<String>? names;const _TG({required this.title,required this.label,required this.icon,required this.color,this.cities,this.names});}

class _SumBar extends StatelessWidget{
  final List<_TG> groups;final Set<String> visited;final int completed;
  const _SumBar({required this.groups,required this.visited,required this.completed});
  @override Widget build(BuildContext context){
    final total=groups.length;final pct=total>0?completed/total:0.0;
    return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_C.ink,borderRadius:BorderRadius.circular(14)),child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$completed of $total collections',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:-0.5)),
        const SizedBox(height:4),
        Text(completed==0?'No collections fully completed yet':completed==total?'All collections completed! 🎉':'${total-completed} remaining to complete',style:const TextStyle(fontSize:12,color:Color(0xFF888888))),
        const SizedBox(height:14),
        _SegBar(groups:groups,visited:visited),
      ])),
      const SizedBox(width:20),
      _AP(value:pct),
    ]));
  }
}

class _SegBar extends StatelessWidget{
  final List<_TG> groups;final Set<String> visited;
  const _SegBar({required this.groups,required this.visited});
  @override Widget build(BuildContext context){
    final total=groups.fold<int>(0,(s,g)=>s+(g.names?.length??g.cities?.length??0));
    if(total==0)return const SizedBox.shrink();
    return ClipRRect(borderRadius:BorderRadius.circular(4),child:SizedBox(height:6,child:Row(children:groups.map((g){
      final ns=g.names??g.cities!.map((c)=>c.name).toList();
      final frac=ns.length/total;final vis=ns.where((n)=>visited.contains(n)).length;
      final vf=ns.isNotEmpty?vis/ns.length:0.0;
      return Expanded(flex:(frac*1000).round(),child:Container(margin:const EdgeInsets.symmetric(horizontal:1),child:Stack(children:[Container(color:const Color(0xFF2E2E2E)),FractionallySizedBox(widthFactor:vf,child:Container(color:g.color))])));
    }).toList())));
  }
}

class _AP extends StatelessWidget{final double value;const _AP({required this.value});@override Widget build(BuildContext context)=>SizedBox(width:68,height:68,child:Stack(alignment:Alignment.center,children:[CustomPaint(size:const Size(68,68),painter:_APainter(value:value)),Column(mainAxisSize:MainAxisSize.min,children:[Text('${(value*100).round()}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Colors.white,height:1)),const Text('%',style:TextStyle(fontSize:10,color:Color(0xFF888888)))])]));}
class _APainter extends CustomPainter{final double value;const _APainter({required this.value});@override void paint(Canvas canvas,Size size){final c=Offset(size.width/2,size.height/2);final r=size.width/2-4;canvas.drawCircle(c,r,Paint()..color=const Color(0xFF2E2E2E)..style=PaintingStyle.stroke..strokeWidth=4.0);if(value>0)canvas.drawArc(Rect.fromCircle(center:c,radius:r),-math.pi/2,2*math.pi*value,false,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=4.0..strokeCap=StrokeCap.round);}@override bool shouldRepaint(_APainter old)=>old.value!=value;}
class _Ch extends StatelessWidget{final String label,value;final Color color;const _Ch({required this.label,required this.value,required this.color});@override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.baseline,textBaseline:TextBaseline.alphabetic,children:[Text(value,style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:color)),const SizedBox(width:3),Text(label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w500,color:_C.inkLight,letterSpacing:0.3))]);}

class _ColCard extends StatefulWidget{final _TG data;final Set<String> visitedNames;final CityProvider provider;const _ColCard({required this.data,required this.visitedNames,required this.provider});@override State<_ColCard> createState()=>_ColCardState();}
class _ColCardState extends State<_ColCard> with SingleTickerProviderStateMixin{
  bool _exp=false;late AnimationController _ctrl;late Animation<double> _rA,_fA;
  @override void initState(){super.initState();_ctrl=AnimationController(duration:const Duration(milliseconds:250),vsync:this);_rA=Tween(begin:0.0,end:0.5).animate(CurvedAnimation(parent:_ctrl,curve:Curves.easeInOut));_fA=CurvedAnimation(parent:_ctrl,curve:Curves.easeIn);}
  @override void dispose(){_ctrl.dispose();super.dispose();}
  void _toggle(){setState((){_exp=!_exp;_exp?_ctrl.forward():_ctrl.reverse();});}
  @override
  Widget build(BuildContext context){
    final g=widget.data;
    final ns=g.names??g.cities!.map((c)=>c.name).toList();
    final total=ns.length;
    final vis=ns.where((n)=>widget.visitedNames.contains(n)).length;
    final pct=total>0?vis/total:0.0;
    final mapC=g.cities??ns.map((n)=>widget.provider.allCities.firstWhereOrNull((c)=>c.name==n)).whereType<City>().toList();
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        InkWell(onTap:_toggle,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:g.color.withOpacity(0.10),borderRadius:BorderRadius.circular(10)),child:Icon(g.icon,size:20,color:g.color)),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(g.label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5,color:g.color)),
            const SizedBox(height:2),
            Text(g.title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:_C.ink,letterSpacing:-0.2)),
          ])),
          GestureDetector(
            onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CityStatsMapScreen(cities:mapC,title:g.title,markerColor:g.color))),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:_C.bg,borderRadius:BorderRadius.circular(8),border:Border.all(color:_C.divider)),
                child:Row(mainAxisSize:MainAxisSize.min,children:const[Icon(Icons.map_outlined,size:14,color:_C.inkMid),SizedBox(width:4),Text('Map',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:_C.inkMid))])),
          ),
          const SizedBox(width:4),
          RotationTransition(turns:_rA,child:const Icon(Icons.keyboard_arrow_down_rounded,size:22,color:_C.inkLight)),
        ]))),
        Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14),child:Column(children:[
          ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:pct,minHeight:5,backgroundColor:_C.divider,valueColor:AlwaysStoppedAnimation<Color>(g.color))),
          const SizedBox(height:8),
          Row(children:[_Ch(label:'Visited',value:'$vis',color:g.color),const SizedBox(width:8),_Ch(label:'Remaining',value:'${total-vis}',color:_C.inkLight),const Spacer(),Text('${(pct*100).round()}%',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:pct>0?g.color:_C.inkLight,letterSpacing:-0.5))]),
        ])),
        AnimatedSize(duration:const Duration(milliseconds:280),curve:Curves.easeInOut,child:_exp
            ?FadeTransition(opacity:_fA,child:Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(16,4,16,16),decoration:const BoxDecoration(border:Border(top:BorderSide(color:_C.divider))),
          child:Wrap(spacing:7,runSpacing:7,children:ns.map((name){
            final isV=widget.visitedNames.contains(name);
            final cityObj=g.cities?.firstWhereOrNull((c)=>c.name==name)??widget.provider.allCities.firstWhereOrNull((c)=>c.name==name);
            final flag=cityObj!=null?_cf(cityObj):'';
            return GestureDetector(
              onTap:cityObj!=null?()=>_showCityModal(context,cityObj):null,
              child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),decoration:BoxDecoration(color:isV?g.color:_C.bg,borderRadius:BorderRadius.circular(20),border:Border.all(color:isV?g.color:_C.divider)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[if(flag.isNotEmpty)...[Text(flag,style:const TextStyle(fontSize:11)),const SizedBox(width:5)],Text(name,style:TextStyle(fontSize:12,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:isV?Colors.white:_C.inkMid))])),
            );
          }).toList()),
        ))
            :const SizedBox.shrink(),
        ),
      ]),
    );
  }
}