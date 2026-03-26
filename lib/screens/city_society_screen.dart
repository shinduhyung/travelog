// lib/screens/city_society_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/screens/city_history_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'dart:math' as math;

String _fe(String? code){if(code==null)return'';final c=code.trim().toUpperCase();if(c.length!=2)return'';final a=c.codeUnitAt(0),b=c.codeUnitAt(1);if(a<65||a>90||b<65||b>90)return'';return String.fromCharCode(0x1F1E6+(a-65))+String.fromCharCode(0x1F1E6+(b-65));}
String _cf(City city){final iso=city.countryIsoA2.trim();return iso.length==2?_fe(iso):_fe(_im[city.country.trim()]);}
const Map<String,String> _im={'Afghanistan':'AF','Albania':'AL','Algeria':'DZ','Argentina':'AR','Armenia':'AM','Australia':'AU','Austria':'AT','Azerbaijan':'AZ','Bahrain':'BH','Bangladesh':'BD','Belarus':'BY','Belgium':'BE','Bolivia':'BO','Brazil':'BR','Bulgaria':'BG','Cambodia':'KH','Canada':'CA','Chile':'CL','China':'CN','Colombia':'CO','Croatia':'HR','Cuba':'CU','Czech Republic':'CZ','Czechia':'CZ','Denmark':'DK','Ecuador':'EC','Egypt':'EG','Ethiopia':'ET','Finland':'FI','France':'FR','Georgia':'GE','Germany':'DE','Ghana':'GH','Greece':'GR','Guatemala':'GT','Hong Kong':'HK','Hungary':'HU','India':'IN','Indonesia':'ID','Iran':'IR','Iraq':'IQ','Ireland':'IE','Israel':'IL','Italy':'IT','Jamaica':'JM','Japan':'JP','Jordan':'JO','Kazakhstan':'KZ','Kenya':'KE','Kuwait':'KW','Lebanon':'LB','Libya':'LY','Malaysia':'MY','Mexico':'MX','Morocco':'MA','Myanmar':'MM','Nepal':'NP','Netherlands':'NL','New Zealand':'NZ','Nigeria':'NG','Norway':'NO','Pakistan':'PK','Panama':'PA','Paraguay':'PY','Peru':'PE','Philippines':'PH','Poland':'PL','Portugal':'PT','Qatar':'QA','Romania':'RO','Russia':'RU','Saudi Arabia':'SA','Senegal':'SN','Serbia':'RS','Singapore':'SG','Slovakia':'SK','Slovenia':'SI','South Africa':'ZA','South Korea':'KR','Korea':'KR','Republic of Korea':'KR','Spain':'ES','Sri Lanka':'LK','Sudan':'SD','Sweden':'SE','Switzerland':'CH','Syria':'SY','Taiwan':'TW','Tanzania':'TZ','Thailand':'TH','Tunisia':'TN','Turkey':'TR','Turkiye':'TR','Ukraine':'UA','United Arab Emirates':'AE','UAE':'AE','United Kingdom':'GB','UK':'GB','United States':'US','USA':'US','United States of America':'US','Uruguay':'UY','Uzbekistan':'UZ','Venezuela':'VE','Vietnam':'VN','Yemen':'YE','Zimbabwe':'ZW','North Korea':'KP','Democratic Republic of the Congo':'CD','Congo':'CG','Ivory Coast':'CI','Dominican Republic':'DO','El Salvador':'SV','Costa Rica':'CR','Honduras':'HN','Nicaragua':'NI','Puerto Rico':'PR'};

class _C{static const Color bg=Color(0xFFF7F7F5),surface=Colors.white,ink=Color(0xFF141414),inkMid=Color(0xFF5C5C5C),inkLight=Color(0xFFAAAAAA),divider=Color(0xFFE8E8E4);}
const Map<String,Color> _cc={'Asia':Color(0xFFF48FB1),'Europe':Color(0xFFFFCA28),'Africa':Color(0xFF8D6E63),'North America':Color(0xFF90CAF9),'South America':Color(0xFF66BB6A),'Oceania':Color(0xFFCE93D8)};

class RankingInfo{
  final String title,dataSourceKey;final IconData icon;final Color themeColor;
  final num Function(City) valueAccessor;final bool isAscendingBetter;
  const RankingInfo({required this.title,required this.icon,required this.themeColor,required this.valueAccessor,required this.dataSourceKey,this.isAscendingBetter=false});
}

class CitySocietyScreen extends StatelessWidget{
  const CitySocietyScreen({super.key});
  @override
  Widget build(BuildContext context){
    return Theme(data:Theme.of(context).copyWith(scaffoldBackgroundColor:_C.bg,cardColor:_C.surface),
        child:DefaultTabController(length:2,child:Scaffold(backgroundColor:_C.bg,appBar:_AppBar(),
            body:const TabBarView(children:[CitySocietyTabScreen(),CityHistoryTabScreen()]))));
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget{
  @override Size get preferredSize=>const Size.fromHeight(56);
  @override Widget build(BuildContext context)=>AppBar(backgroundColor:_C.surface,elevation:0,automaticallyImplyLeading:false,titleSpacing:0,
      bottom:PreferredSize(preferredSize:const Size.fromHeight(1),child:Container(height:1,color:_C.divider)),
      title:TabBar(tabs:const[Tab(text:'Society'),Tab(text:'History')],
          labelStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,letterSpacing:0.5),
          unselectedLabelStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w400,letterSpacing:0.5),
          labelColor:_C.ink,unselectedLabelColor:_C.inkLight,
          indicator:const UnderlineTabIndicator(borderSide:BorderSide(color:_C.ink,width:2),insets:EdgeInsets.symmetric(horizontal:24)),
          indicatorSize:TabBarIndicatorSize.tab));
}

class CitySocietyTabScreen extends StatelessWidget{
  const CitySocietyTabScreen({super.key});
  @override
  Widget build(BuildContext context)=>Consumer<CityProvider>(builder:(context,provider,child){
    if(provider.isLoading)return const Center(child:CircularProgressIndicator(strokeWidth:2,color:_C.ink));
    return SingleChildScrollView(physics:const BouncingScrollPhysics(),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _SH(label:'RANKINGS'),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_RankCard(provider:provider)),
      const SizedBox(height:32),
    ]));
  });
}

class _SH extends StatelessWidget{final String label;const _SH({required this.label});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,24,16,12),child:Row(children:[Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,letterSpacing:2.0,color:_C.inkLight)),const SizedBox(width:12),Expanded(child:Container(height:1,color:_C.divider))]));}

class _RankCard extends StatefulWidget{final CityProvider provider;const _RankCard({required this.provider});@override State<_RankCard> createState()=>_RankCardState();}
class _RankCardState extends State<_RankCard>{
  late final List<RankingInfo> _ranks;late RankingInfo _sel;List<City> _list=[];
  @override void initState(){super.initState();
  _ranks=const[
    RankingInfo(title:'QS Student Cities',icon:Icons.school_outlined,themeColor:Color(0xFFD66B2A),valueAccessor:_vs,dataSourceKey:'student'),
    RankingInfo(title:'Safety Ranking',icon:Icons.security_outlined,themeColor:Color(0xFF3B5C7A),valueAccessor:_vsa,dataSourceKey:'safety'),
    RankingInfo(title:'Liveability',icon:Icons.favorite_outline,themeColor:Color(0xFFD64545),valueAccessor:_vl,dataSourceKey:'liveability'),
    RankingInfo(title:'Homicide Rate',icon:Icons.personal_injury_outlined,themeColor:Color(0xFF7A2A2A),valueAccessor:_vh,dataSourceKey:'homicide'),
    RankingInfo(title:'Surveillance',icon:Icons.videocam_outlined,themeColor:Color(0xFF5C5C5C),valueAccessor:_vsc,dataSourceKey:'surveillance'),
    RankingInfo(title:'Pollution',icon:Icons.cloud_off_outlined,themeColor:Color(0xFF7A5C3C),valueAccessor:_vp,dataSourceKey:'pollution'),
  ];
  _sel=_ranks.first;_prep();
  }
  static num _vs(City c)=>c.studentScore;static num _vsa(City c)=>c.safetyScore;static num _vl(City c)=>c.liveabilityScore;
  static num _vh(City c)=>c.homicideRate;static num _vsc(City c)=>c.surveillanceCameraCount;static num _vp(City c)=>c.pollutionScore;

  void _prep(){
    List<City> l;
    switch(_sel.dataSourceKey){
      case'student':l=widget.provider.studentCities.where((c)=>c.studentScore!=0).toList();break;
      case'safety':l=widget.provider.safetyCities.where((c)=>c.safetyScore!=0).toList();break;
      case'liveability':l=widget.provider.liveabilityCities.where((c)=>c.liveabilityScore!=0).toList();break;
      case'homicide':l=widget.provider.homicideCities.where((c)=>c.homicideRate!=0).toList();break;
      case'surveillance':l=widget.provider.surveillanceCities.where((c)=>c.surveillanceCameraCount!=0).toList();break;
      case'pollution':l=widget.provider.pollutionCities.where((c)=>c.pollutionScore!=0).toList();break;
      default:l=[];
    }
    l.sort((a,b)=>_sel.isAscendingBetter?_sel.valueAccessor(a).compareTo(_sel.valueAccessor(b)):_sel.valueAccessor(b).compareTo(_sel.valueAccessor(a)));
    setState(()=>_list=l.take(30).toList());
  }

  @override
  Widget build(BuildContext context){
    final topVal=_list.isNotEmpty?_sel.valueAccessor(_list.first).toDouble():1.0;
    return Container(
      decoration:BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.divider)),
      child:Column(children:[
        Container(padding:const EdgeInsets.all(12),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_C.divider))),
          child:Wrap(spacing:6,runSpacing:6,children:_ranks.map((r){
            final active=r==_sel;
            return GestureDetector(onTap:()=>setState((){_sel=r;_prep();}),
                child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                    decoration:BoxDecoration(color:active?_C.ink:Colors.transparent,borderRadius:BorderRadius.circular(8),border:Border.all(color:active?_C.ink:_C.divider)),
                    child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(r.icon,size:14,color:active?Colors.white:_C.inkLight),const SizedBox(width:6),Text(r.title,style:TextStyle(fontSize:12,fontWeight:active?FontWeight.w700:FontWeight.w400,color:active?Colors.white:_C.inkLight))])));
          }).toList()),
        ),
        SizedBox(height:360,child:_list.isEmpty
            ?const Center(child:Text('No data',style:TextStyle(color:_C.inkLight)))
            :ListView.builder(physics:const BouncingScrollPhysics(),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),itemCount:_list.length,itemBuilder:(context,index){
          final item=_list[index];final isV=widget.provider.visitedCities.contains(item.name);final rank=index+1;
          final val=_sel.valueAccessor(item);
          double barFrac=(val.toDouble()/topVal).clamp(0.0,1.0);
          if(_sel.isAscendingBetter)barFrac=1.0-barFrac;
          final barColor=widget.provider.useDefaultCityRankingBarColor?_sel.themeColor:(_cc[item.continent]??_sel.themeColor);
          return GestureDetector(onTap:()=>showExternalCityDetailsModal(context,item),
            child:Container(margin:const EdgeInsets.symmetric(vertical:3),padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
                decoration:BoxDecoration(color:isV?_sel.themeColor.withOpacity(0.05):Colors.transparent,borderRadius:BorderRadius.circular(8),border:Border(left:BorderSide(color:isV?_sel.themeColor:Colors.transparent,width:2.5))),
                child:Row(children:[
                  SizedBox(width:28,child:Text(rank<=3?(rank==1?'🥇':rank==2?'🥈':'🥉'):'$rank',style:TextStyle(fontSize:rank<=3?16:12,fontWeight:FontWeight.w700,color:_C.inkLight),textAlign:TextAlign.center)),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[Expanded(child:Text(item.name,style:TextStyle(fontSize:13,fontWeight:isV?FontWeight.w700:FontWeight.w500,color:_C.ink),overflow:TextOverflow.ellipsis)),if(isV)...[const SizedBox(width:4),Icon(Icons.check_circle_rounded,size:14,color:_sel.themeColor)],const SizedBox(width:6),Text(val.toStringAsFixed(1),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_C.ink))]),
                    const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(3),child:LinearProgressIndicator(value:barFrac,minHeight:3,backgroundColor:_C.divider,valueColor:AlwaysStoppedAnimation<Color>(barColor))),
                    const SizedBox(height:3),Row(children:[Text(_cf(item),style:const TextStyle(fontSize:11)),const SizedBox(width:4),Text(item.country,style:const TextStyle(fontSize:10,color:_C.inkLight))]),
                  ])),
                ])),
          );
        }),
        ),
      ]),
    );
  }
}