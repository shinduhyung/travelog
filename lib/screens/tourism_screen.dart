// lib/screens/tourism_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/screens/city_transportation_screen.dart';
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'dart:math' as math;

String _fe(String? code){if(code==null)return'';final c=code.trim().toUpperCase();if(c.length!=2)return'';final a=c.codeUnitAt(0),b=c.codeUnitAt(1);if(a<65||a>90||b<65||b>90)return'';return String.fromCharCode(0x1F1E6+(a-65))+String.fromCharCode(0x1F1E6+(b-65));}
String _cf(City city){final iso=city.countryIsoA2.trim();return iso.length==2?_fe(iso):_fe(_im[city.country.trim()]);}
const Map<String,String> _im={'Afghanistan':'AF','Albania':'AL','Algeria':'DZ','Argentina':'AR','Armenia':'AM','Australia':'AU','Austria':'AT','Azerbaijan':'AZ','Bahrain':'BH','Bangladesh':'BD','Belarus':'BY','Belgium':'BE','Bolivia':'BO','Brazil':'BR','Bulgaria':'BG','Cambodia':'KH','Canada':'CA','Chile':'CL','China':'CN','Colombia':'CO','Croatia':'HR','Cuba':'CU','Czech Republic':'CZ','Czechia':'CZ','Denmark':'DK','Ecuador':'EC','Egypt':'EG','Ethiopia':'ET','Finland':'FI','France':'FR','Georgia':'GE','Germany':'DE','Ghana':'GH','Greece':'GR','Guatemala':'GT','Hong Kong':'HK','Hungary':'HU','India':'IN','Indonesia':'ID','Iran':'IR','Iraq':'IQ','Ireland':'IE','Israel':'IL','Italy':'IT','Jamaica':'JM','Japan':'JP','Jordan':'JO','Kazakhstan':'KZ','Kenya':'KE','Kuwait':'KW','Lebanon':'LB','Libya':'LY','Malaysia':'MY','Mexico':'MX','Morocco':'MA','Myanmar':'MM','Nepal':'NP','Netherlands':'NL','New Zealand':'NZ','Nigeria':'NG','Norway':'NO','Pakistan':'PK','Panama':'PA','Paraguay':'PY','Peru':'PE','Philippines':'PH','Poland':'PL','Portugal':'PT','Qatar':'QA','Romania':'RO','Russia':'RU','Saudi Arabia':'SA','Senegal':'SN','Serbia':'RS','Singapore':'SG','Slovakia':'SK','Slovenia':'SI','South Africa':'ZA','South Korea':'KR','Korea':'KR','Republic of Korea':'KR','Spain':'ES','Sri Lanka':'LK','Sudan':'SD','Sweden':'SE','Switzerland':'CH','Syria':'SY','Taiwan':'TW','Tanzania':'TZ','Thailand':'TH','Tunisia':'TN','Turkey':'TR','Turkiye':'TR','Ukraine':'UA','United Arab Emirates':'AE','UAE':'AE','United Kingdom':'GB','UK':'GB','United States':'US','USA':'US','United States of America':'US','Uruguay':'UY','Uzbekistan':'UZ','Venezuela':'VE','Vietnam':'VN','Yemen':'YE','Zimbabwe':'ZW','North Korea':'KP','Democratic Republic of the Congo':'CD','Congo':'CG','Ivory Coast':'CI','Dominican Republic':'DO','El Salvador':'SV','Costa Rica':'CR','Honduras':'HN','Nicaragua':'NI','Puerto Rico':'PR'};

class _C{static const Color bg=Color(0xFFF7F7F5),surface=Colors.white,ink=Color(0xFF141414),inkMid=Color(0xFF5C5C5C),inkLight=Color(0xFFAAAAAA),divider=Color(0xFFE8E8E4);}
const Map<String,Color> _cc={'Asia':Color(0xFFF48FB1),'Europe':Color(0xFFFFCA28),'Africa':Color(0xFF8D6E63),'North America':Color(0xFF90CAF9),'South America':Color(0xFF66BB6A),'Oceania':Color(0xFFCE93D8)};

class RankingInfo{
  final String title,metricKey;final IconData icon;final Color themeColor;final num Function(City) valueAccessor;
  RankingInfo({required this.title,required this.icon,required this.themeColor,required this.metricKey,required this.valueAccessor});
}

class TourismScreen extends StatelessWidget{
  const TourismScreen({super.key});
  // kept for external references
  static final Map<String,Color> continentColors=Map.from(_cc);

  @override
  Widget build(BuildContext context){
    return Theme(data:Theme.of(context).copyWith(scaffoldBackgroundColor:_C.bg,cardColor:_C.surface),
        child:DefaultTabController(length:2,child:Scaffold(backgroundColor:_C.bg,appBar:_TourAppBar(),
            body:const TabBarView(children:[_TourismTab(),CityTransportationScreen()]))));
  }
}

class _TourAppBar extends StatelessWidget implements PreferredSizeWidget{
  @override Size get preferredSize=>const Size.fromHeight(56);
  @override Widget build(BuildContext context)=>AppBar(backgroundColor:_C.surface,elevation:0,automaticallyImplyLeading:false,titleSpacing:0,
      bottom:PreferredSize(preferredSize:const Size.fromHeight(1),child:Container(height:1,color:_C.divider)),
      title:TabBar(tabs:const[Tab(text:'Tourism'),Tab(text:'Transportation')],
          labelStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,letterSpacing:0.5),
          unselectedLabelStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w400,letterSpacing:0.5),
          labelColor:_C.ink,unselectedLabelColor:_C.inkLight,
          indicator:const UnderlineTabIndicator(borderSide:BorderSide(color:_C.ink,width:2),insets:EdgeInsets.symmetric(horizontal:24)),
          indicatorSize:TabBarIndicatorSize.tab));
}

class _TourismTab extends StatelessWidget{
  const _TourismTab();
  @override
  Widget build(BuildContext context){
    return Consumer<CityProvider>(builder:(context,provider,child){
      if(provider.isLoading)return const Center(child:CircularProgressIndicator(strokeWidth:2,color:_C.ink));
      final visited=provider.visitedCities;
      final instaCities=provider.instagramCities;
      final instaVisited=instaCities.where((c)=>visited.contains(c.name)).length;
      final instaCompleted=instaCities.isNotEmpty&&instaCities.every((c)=>visited.contains(c.name))?1:0;
      final instaPct=instaCities.isNotEmpty?instaVisited/instaCities.length:0.0;

      return SingleChildScrollView(physics:const BouncingScrollPhysics(),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const _SH(label:'RANKINGS'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_TourRankCard(provider:provider)),
        const _SH(label:'COLLECTIONS'),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:_C.ink,borderRadius:BorderRadius.circular(14)),
          child:Row(children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('$instaCompleted of 1 collections',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:-0.5)),
              const SizedBox(height:4),
              Text(instaCompleted==0?'No collections fully completed yet':'All collections completed! 🎉',style:const TextStyle(fontSize:12,color:Color(0xFF888888))),
              const SizedBox(height:14),
              ClipRRect(borderRadius:BorderRadius.circular(4),child:SizedBox(height:6,child:Stack(children:[Container(color:const Color(0xFF2E2E2E)),FractionallySizedBox(widthFactor:instaPct,child:Container(color:const Color(0xFFD64545)))]))),
            ])),
            const SizedBox(width:20),
            _AP(value:instaPct),
          ]),
        )),
        const SizedBox(height:16),
        Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:_InstaCard(cities:instaCities,visitedNames:visited)),
        const SizedBox(height:32),
      ]));
    });
  }
}

class _SH extends StatelessWidget{final String label;const _SH({required this.label});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,24,16,12),child:Row(children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,letterSpacing:2.0,color:_C.inkLight)),const SizedBox(width:12),Expanded(child:Container(height:1,color:_C.divider))]));}

// ── Tourism Ranking Card
class _TourRankCard extends StatefulWidget{final CityProvider provider;const _TourRankCard({required this.provider});@override State<_TourRankCard> createState()=>_TourRankCardState();}
class _TourRankCardState extends State<_TourRankCard>{
  late final List<RankingInfo> _ranks;late RankingInfo _sel;String _cont='World';List<City> _list=[];
  final List<String> _conts=['World','Asia','Europe','Africa','North America','South America','Oceania'];
  @override void initState(){super.initState();
  _ranks=[
    RankingInfo(title:'Annual Visitors',icon:Icons.group_outlined,themeColor:const Color(0xFFD66B2A),metricKey:'visitors',valueAccessor:(c)=>c.annualVisitors),
    RankingInfo(title:'Starbucks',icon:Icons.local_cafe_outlined,themeColor:const Color(0xFF2A8C74),metricKey:'starbucks',valueAccessor:(c)=>c.starbucksCount),
    RankingInfo(title:'Tourists',icon:Icons.person_pin_circle_outlined,themeColor:const Color(0xFF6B3D99),metricKey:'ratio',valueAccessor:(c)=>c.cityTouristRatio),
  ];
  _sel=_ranks.first;_prep();
  }
  void _prep(){
    List<City> l;
    if(_sel.metricKey=='visitors'){
      l=List.from(widget.provider.allCities);
      if(_cont!='World')l=l.where((c)=>c.continent==_cont).toList();
      l.sort((a,b)=>_sel.valueAccessor(b).compareTo(_sel.valueAccessor(a)));
      l=l.where((c)=>_sel.valueAccessor(c)>0).toList();
    }else if(_sel.metricKey=='starbucks'){
      l=List.from(widget.provider.starbucksCities);
      l.sort((a,b)=>_sel.valueAccessor(b).compareTo(_sel.valueAccessor(a)));
    }else{
      l=widget.provider.allCities.where((c)=>c.cityTouristRatio>0.0).toList();
      l.sort((a,b)=>_sel.valueAccessor(b).compareTo(_sel.valueAccessor(a)));
    }
    final takeCount=(_sel.metricKey=='visitors'&&_cont!='World')?10:30;
    setState(()=>_list=l.take(takeCount).toList());
  }
  @override
  Widget build(BuildContext context){
    final fmt=NumberFormat.compact();final dec=NumberFormat('0.00');
    final top=_list.isNotEmpty?_sel.valueAccessor(_list.first):1;
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        Container(padding:const EdgeInsets.all(12),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_C.divider))),
          child:Column(children:[
            Row(children:[
              ..._ranks.map((r){
                final active=r==_sel;
                return Expanded(child:GestureDetector(onTap:()=>setState((){_sel=r;_cont='World';_prep();}),
                    child:AnimatedContainer(duration:const Duration(milliseconds:200),padding:const EdgeInsets.symmetric(vertical:10),margin:const EdgeInsets.symmetric(horizontal:3),
                        decoration:BoxDecoration(color:active?_C.ink:Colors.transparent,borderRadius:BorderRadius.circular(8)),
                        child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(r.icon,size:15,color:active?Colors.white:_C.inkLight),const SizedBox(width:6),Text(r.title,style:TextStyle(fontSize:11,fontWeight:active?FontWeight.w700:FontWeight.w400,color:active?Colors.white:_C.inkLight))]))));
              }),
            ]),
            if(_sel.metricKey=='visitors')...[
              const SizedBox(height:8),
              Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                Container(height:32,padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:_C.bg,borderRadius:BorderRadius.circular(8),border:Border.all(color:_C.divider)),
                    child:DropdownButtonHideUnderline(child:DropdownButton<String>(value:_cont,icon:const Icon(Icons.keyboard_arrow_down_rounded,size:16,color:_C.inkMid),style:const TextStyle(fontSize:12,color:_C.ink,fontWeight:FontWeight.w600),items:_conts.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)setState((){_cont=v;_prep();}); }))),
              ]),
            ],
          ]),
        ),
        SizedBox(height:360,child:_list.isEmpty
            ?const Center(child:Text('No data',style:TextStyle(color:_C.inkLight)))
            :ListView.builder(physics:const BouncingScrollPhysics(),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),itemCount:_list.length,itemBuilder:(context,index){
          final item=_list[index];final isV=widget.provider.visitedCities.contains(item.name);final rank=index+1;
          final val=_sel.valueAccessor(item);
          final barFrac=top==0?0.0:(val/top).toDouble().clamp(0.0,1.0);
          final barColor=widget.provider.useDefaultCityRankingBarColor?_sel.themeColor:(_cc[item.continent]??_sel.themeColor);
          final dStr=_sel.metricKey=='ratio'?dec.format(val):fmt.format(val);
          return GestureDetector(onTap:()=>showExternalCityDetailsModal(context,item),
              child:Container(margin:const EdgeInsets.symmetric(vertical:3),padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
                  decoration:BoxDecoration(color:isV?_sel.themeColor.withOpacity(0.05):Colors.transparent,borderRadius:BorderRadius.circular(8),border:Border(left:BorderSide(color:isV?_sel.themeColor:Colors.transparent,width:2.5))),
                  child:Row(children:[
                    SizedBox(width:28,child:Text(rank<=3?(rank==1?'🥇':rank==2?'🥈':'🥉'):'$rank',style:TextStyle(fontSize:rank<=3?16:12,fontWeight:FontWeight.w700,color:_C.inkLight),textAlign:TextAlign.center)),
                    const SizedBox(width:10),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Row(children:[Expanded(child:Text(item.name,style:TextStyle(fontSize:13,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:_C.ink),overflow:TextOverflow.ellipsis)),if(isV)...[const SizedBox(width:4),Icon(Icons.check_circle_rounded,size:14,color:_sel.themeColor)],const SizedBox(width:6),Text(dStr,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_C.ink))]),
                      const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(3),child:LinearProgressIndicator(value:barFrac,minHeight:3,backgroundColor:_C.divider,valueColor:AlwaysStoppedAnimation<Color>(barColor))),
                      const SizedBox(height:3),Row(children:[Text(_cf(item),style:const TextStyle(fontSize:11)),const SizedBox(width:4),Text(item.country,style:const TextStyle(fontSize:10,color:_C.inkLight))]),
                    ])),
                  ])));
        }),
        ),
      ]),
    );
  }
}

// ── Instagram Collection Card
class _InstaCard extends StatefulWidget{
  final List<City> cities;final Set<String> visitedNames;
  const _InstaCard({required this.cities,required this.visitedNames});
  @override State<_InstaCard> createState()=>_InstaCardState();
}
class _InstaCardState extends State<_InstaCard> with SingleTickerProviderStateMixin{
  bool _exp=false;late AnimationController _ctrl;late Animation<double> _rA,_fA;
  static const Color _accent=Color(0xFFD64545);
  @override void initState(){super.initState();_ctrl=AnimationController(duration:const Duration(milliseconds:250),vsync:this);_rA=Tween(begin:0.0,end:0.5).animate(CurvedAnimation(parent:_ctrl,curve:Curves.easeInOut));_fA=CurvedAnimation(parent:_ctrl,curve:Curves.easeIn);}
  @override void dispose(){_ctrl.dispose();super.dispose();}
  void _toggle(){setState((){_exp=!_exp;_exp?_ctrl.forward():_ctrl.reverse();});}
  @override
  Widget build(BuildContext context){
    final total=widget.cities.length;
    final vis=widget.cities.where((c)=>widget.visitedNames.contains(c.name)).length;
    final pct=total>0?vis/total:0.0;
    return Container(decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),child:Column(children:[
      InkWell(onTap:_toggle,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        Container(width:42,height:42,decoration:BoxDecoration(color:_accent.withOpacity(0.10),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.camera_alt_outlined,size:20,color:_accent)),
        const SizedBox(width:14),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('SOCIAL',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5,color:_accent)),
          SizedBox(height:2),
          Text('Top Instagram Posted',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:_C.ink,letterSpacing:-0.2)),
        ])),
        GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CityStatsMapScreen(cities:widget.cities,title:'Top Instagram Posted',markerColor:_accent))),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:_C.bg,borderRadius:BorderRadius.circular(8),border:Border.all(color:_C.divider)),child:Row(mainAxisSize:MainAxisSize.min,children:const[Icon(Icons.map_outlined,size:14,color:_C.inkMid),SizedBox(width:4),Text('Map',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:_C.inkMid))]))),
        const SizedBox(width:4),
        RotationTransition(turns:_rA,child:const Icon(Icons.keyboard_arrow_down_rounded,size:22,color:_C.inkLight)),
      ]))),
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14),child:Column(children:[
        ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:pct,minHeight:5,backgroundColor:_C.divider,valueColor:const AlwaysStoppedAnimation<Color>(_accent))),
        const SizedBox(height:8),
        Row(children:[_Ch(label:'Visited',value:'$vis',color:_accent),const SizedBox(width:8),_Ch(label:'Remaining',value:'${total-vis}',color:_C.inkLight),const Spacer(),Text('${(pct*100).round()}%',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:pct>0?_accent:_C.inkLight,letterSpacing:-0.5))]),
      ])),
      AnimatedSize(duration:const Duration(milliseconds:280),curve:Curves.easeInOut,child:_exp
          ?FadeTransition(opacity:_fA,child:Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(16,4,16,16),decoration:const BoxDecoration(border:Border(top:BorderSide(color:_C.divider))),
        child:Wrap(spacing:7,runSpacing:7,children:widget.cities.map((city){
          final isV=widget.visitedNames.contains(city.name);
          final flag=_cf(city);
          return GestureDetector(onTap:()=>showExternalCityDetailsModal(context,city),
              child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),decoration:BoxDecoration(color:isV?_accent:_C.bg,borderRadius:BorderRadius.circular(20),border:Border.all(color:isV?_accent:_C.divider)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[if(flag.isNotEmpty)...[Text(flag,style:const TextStyle(fontSize:11)),const SizedBox(width:5)],Text(city.name,style:TextStyle(fontSize:12,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:isV?Colors.white:_C.inkMid))])));
        }).toList()),
      ))
          :const SizedBox.shrink(),
      ),
    ]));
  }
}

class _AP extends StatelessWidget{final double value;const _AP({required this.value});@override Widget build(BuildContext context)=>SizedBox(width:68,height:68,child:Stack(alignment:Alignment.center,children:[CustomPaint(size:const Size(68,68),painter:_APainter(value:value)),Column(mainAxisSize:MainAxisSize.min,children:[Text('${(value*100).round()}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:Colors.white,height:1)),const Text('%',style:TextStyle(fontSize:10,color:Color(0xFF888888)))])]));}
class _APainter extends CustomPainter{final double value;const _APainter({required this.value});@override void paint(Canvas canvas,Size size){final c=Offset(size.width/2,size.height/2);final r=size.width/2-4;canvas.drawCircle(c,r,Paint()..color=const Color(0xFF2E2E2E)..style=PaintingStyle.stroke..strokeWidth=4.0);if(value>0)canvas.drawArc(Rect.fromCircle(center:c,radius:r),-math.pi/2,2*math.pi*value,false,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=4.0..strokeCap=StrokeCap.round);}@override bool shouldRepaint(_APainter old)=>old.value!=value;}
class _Ch extends StatelessWidget{final String label,value;final Color color;const _Ch({required this.label,required this.value,required this.color});@override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.baseline,textBaseline:TextBaseline.alphabetic,children:[Text(value,style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:color)),const SizedBox(width:3),Text(label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w500,color:_C.inkLight,letterSpacing:0.3))]);}