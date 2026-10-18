// lib/screens/country_tiers_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:country_flags/country_flags.dart';
import 'package:collection/collection.dart';

class TabState {
  String filter1 = 'all';
  List<String> countries = [];
  bool isInitialized = false;
  Set<String> selectedMetrics = {};
  String selectedMetric = 'Rating';

  // Sorting for Table
  String sortColumn = 'Rating';
  bool isAscending = false;

  // Chart Custom Colors
  Map<String, Color> chartColors = {};
}

class CountryTiersScreen extends StatefulWidget {
  const CountryTiersScreen({super.key});

  @override
  State<CountryTiersScreen> createState() => _CountryTiersScreenState();
}

class _CountryTiersScreenState extends State<CountryTiersScreen> {
  String _viewMode = 'tiers';
  bool _isHeaderVisible = true;

  final TabState _tiersState = TabState();
  final TabState _tableState = TabState();
  final TabState _chartState = TabState();

  final List<String> _metricNames = [
    'Rating', 'Affordability', 'Safety', 'Food Quality', 'Transport',
    'English', 'Cleanliness', 'Attraction', 'Vibrancy', 'Connectivity',
  ];

  final Map<String, String> _metricEmojis = {
    'Rating': '⭐', 'Affordability': '💸', 'Safety': '🛡️', 'Food Quality': '🍽️',
    'Transport': '🚆', 'English': '💬', 'Cleanliness': '✨', 'Attraction': '🏛️',
    'Vibrancy': '🎉', 'Connectivity': '✈️',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  TabState get _currentState {
    if (_viewMode == 'tiers') return _tiersState;
    if (_viewMode == 'table') return _tableState;
    return _chartState;
  }

  Widget _buildFlag(String isoA2, {double size = 16}) {
    if (isoA2.isEmpty || isoA2 == 'N/A') return const SizedBox.shrink();
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: CountryFlag.fromCountryCode(isoA2.toUpperCase()),
      ),
    );
  }

  double _getMetricValue(VisitDetails? details, String metric) {
    if (details == null) return 0.0;
    switch (metric) {
      case 'Rating': return details.rating;
      case 'Affordability': return details.affordability;
      case 'Safety': return details.safety;
      case 'Food Quality': return details.foodQuality;
      case 'Transport': return details.transport;
      case 'English': return details.englishProficiency;
      case 'Cleanliness': return details.cleanliness;
      case 'Attraction': return details.attractionDensity;
      case 'Vibrancy': return details.vibrancy;
      case 'Connectivity': return details.accessibility;
      default: return 0.0;
    }
  }

  bool _hasAnyData(VisitDetails? details) {
    if (details == null) return false;
    return details.rating > 0 || details.affordability > 0 || details.safety > 0 ||
        details.foodQuality > 0 || details.transport > 0 || details.englishProficiency > 0 ||
        details.cleanliness > 0 || details.attractionDensity > 0 || details.vibrancy > 0 || details.accessibility > 0;
  }

  void _initTabStateIfNeeded(TabState state, CountryProvider provider) {
    if (state.selectedMetrics.isEmpty) state.selectedMetrics = Set.from(_metricNames);
    if (!state.isInitialized) {
      state.countries = provider.allCountries
          .where((c) => _hasAnyData(provider.visitDetails[c.name]))
          .map((c) => c.name).toList();
      state.isInitialized = true;
    }
  }

  void _applyFilters(TabState state, CountryProvider provider) {
    if (state.filter1 == 'custom') return;
    state.countries = provider.allCountries.where((c) {
      final details = provider.visitDetails[c.name];
      if (!_hasAnyData(details)) return false;
      final isVis = details?.isVisited ?? false;
      if (state.filter1 == 'mark_visited' && !isVis) return false;
      if (state.filter1 == 'unvisited' && isVis) return false;
      return true;
    }).map((c) => c.name).toList();
  }

  Widget _buildStarRating(double rating, {double size = 11}) {
    if (rating <= 0) return Text(tr('-'), style: TextStyle(fontSize: size));
    int fullStars = (rating / 2).floor();
    bool hasHalfStar = (rating / 2 - fullStars) >= 0.25;
    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) stars.add(Icon(Icons.star, color: Colors.amber, size: size + 2));
    if (hasHalfStar) stars.add(Icon(Icons.star_half, color: Colors.amber, size: size + 2));
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  // --- Dialogs ---

  void _showEditSlidersDialog(Country c, CountryProvider provider) {
    final details = provider.visitDetails[c.name];
    double rat = details?.rating ?? 0.0;
    double aff = details?.affordability ?? 0.0;
    double saf = details?.safety ?? 0.0;
    double foo = details?.foodQuality ?? 0.0;
    double tra = details?.transport ?? 0.0;
    double eng = details?.englishProficiency ?? 0.0;
    double cle = details?.cleanliness ?? 0.0;
    double att = details?.attractionDensity ?? 0.0;
    double vib = details?.vibrancy ?? 0.0;
    double acc = details?.accessibility ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) {
          Widget buildS(String m, double v, Function(double) onC) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Row(children: [
              SizedBox(width: 85, child: Text(tr("${_metricEmojis[m]} $m"), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)), child: Slider(value: v, min: 0, max: 10, divisions: 20, onChanged: (val) => setDS(() => onC(val))))),
              SizedBox(width: 25, child: Text(tr(v.toStringAsFixed(1)), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 5),
            titlePadding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            title: Row(children: [
              _buildFlag(c.isoA2, size: 22), const SizedBox(width: 8),
              Expanded(child: Text(tr(c.name), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              Row(children: List.generate(5, (index) {
                double starValue = (index + 1) * 2.0;
                IconData icon = (rat >= starValue) ? Icons.star : (rat >= starValue - 1.0 ? Icons.star_half : Icons.star_border);
                return GestureDetector(onTapDown: (d) => setDS(() => rat = d.localPosition.dx < 12 ? starValue - 1.0 : starValue), child: Icon(icon, color: Colors.amber, size: 22));
              })),
            ]),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          buildS('Affordability', aff, (nv) => aff = nv), buildS('Safety', saf, (nv) => saf = nv), buildS('Food Quality', foo, (nv) => foo = nv),
                          buildS('Transport', tra, (nv) => tra = nv), buildS('English', eng, (nv) => eng = nv), buildS('Cleanliness', cle, (nv) => cle = nv),
                          buildS('Attraction', att, (nv) => att = nv), buildS('Vibrancy', vib, (nv) => vib = nv), buildS('Connectivity', acc, (nv) => acc = nv),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(0, 0, 15, 6),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child:  Text(tr('Cancel'), style: TextStyle(fontSize: 11, color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(50, 28), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: () {
                  provider.updateUserMetrics(c.name, rating: rat, affordability: aff, safety: saf, foodQuality: foo, transport: tra, englishProficiency: eng, cleanliness: cle, attractionDensity: att, vibrancy: vib, accessibility: acc);
                  Navigator.pop(context);
                  setState(() {});
                },
                child:  Text(tr('Save'), style: TextStyle(fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCountryDialog(BuildContext context, CountryProvider provider) {
    String q = '';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {
      final list = provider.allCountries.where((c) => !_currentState.countries.contains(c.name) && (q.isEmpty || AppLocale.instance.matchesCountry(c.name, q))).toList();
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text(tr('Add Country'), style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(width: 300, height: 350, child: Column(children: [
          TextField(decoration:  InputDecoration(hintText: tr('Search...'), prefixIcon: Icon(Icons.search)), onChanged: (v) => setDS(() => q = v)),
          Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, idx) => ListTile(dense: true, leading: _buildFlag(list[idx].isoA2), title: Text(tr(list[idx].name)), onTap: () {
            setState(() { _currentState.countries.add(list[idx].name); _currentState.filter1 = 'custom'; });
            Navigator.pop(ctx);
            if (!_hasAnyData(provider.visitDetails[list[idx].name])) _showEditSlidersDialog(list[idx], provider);
          }))),
        ])),
      );
    }));
  }

  void _showCountrySelector(int replaceIndex, CountryProvider provider) {
    String q = '';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {
      final existing = provider.allCountries.where((c) => _hasAnyData(provider.visitDetails[c.name]) && !_chartState.countries.contains(c.name) && (q.isEmpty || AppLocale.instance.matchesCountry(c.name, q))).toList();
      final others = provider.allCountries.where((c) => !_hasAnyData(provider.visitDetails[c.name]) && !_chartState.countries.contains(c.name) && (q.isEmpty || AppLocale.instance.matchesCountry(c.name, q))).toList();

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text(tr('Select Country'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(width: 300, height: 400, child: Column(children: [
          TextField(decoration:  InputDecoration(hintText: tr('Search...'), prefixIcon: Icon(Icons.search)), onChanged: (v) => setDS(() => q = v)),
          Expanded(child: ListView(children: [
            if (existing.isNotEmpty) ...[ Padding(padding: EdgeInsets.all(8), child: Text(tr('Existing Data'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))), ...existing.map((c) => ListTile(dense: true, leading: _buildFlag(c.isoA2), title: Text(tr(c.name)), onTap: () { setState(() => _chartState.countries[replaceIndex] = c.name); Navigator.pop(ctx); }))],
            if (others.isNotEmpty) ...[ Padding(padding: EdgeInsets.all(8), child: Text(tr('Others'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))), ...others.map((c) => ListTile(dense: true, leading: _buildFlag(c.isoA2), title: Text(tr(c.name)), onTap: () { setState(() => _chartState.countries[replaceIndex] = c.name); Navigator.pop(ctx); _showEditSlidersDialog(c, provider); }))]
          ])),
        ])),
      );
    }));
  }

  // 🆕 수정: 지표 선택 다이얼로그 (요청하신 스타일 적용)
  void _showMetricsDialog() {
    final state = _currentState;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title:  Text(tr('Select Metrics'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              contentPadding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
              content: SizedBox(
                width: 220,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _metricNames.map((m) {
                      if (_viewMode == 'tiers') {
                        return RadioListTile<String>(
                          visualDensity: VisualDensity.compact,
                          title: Text(tr("${_metricEmojis[m]} $m"), style: const TextStyle(fontSize: 13)),
                          value: m,
                          groupValue: state.selectedMetric,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                state.selectedMetric = val;
                                _applyFilters(state, Provider.of<CountryProvider>(context, listen: false));
                              });
                              Navigator.pop(context);
                            }
                          },
                        );
                      } else {
                        return CheckboxListTile(
                          visualDensity: VisualDensity.compact,
                          title: Text(tr("${_metricEmojis[m]} $m"), style: const TextStyle(fontSize: 13)),
                          value: state.selectedMetrics.contains(m),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) state.selectedMetrics.add(m);
                              else state.selectedMetrics.remove(m);
                            });
                            setState(() { _applyFilters(state, Provider.of<CountryProvider>(context, listen: false)); });
                          },
                        );
                      }
                    }).toList(),
                  ),
                ),
              ),
              actions: _viewMode == 'tiers' ? null : [
                TextButton(onPressed: () => Navigator.pop(context), child:  Text(tr('Done'), style: TextStyle(fontSize: 13))),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorPicker(String cName) {
    final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.lime, Colors.green, Colors.teal, Colors.cyan, Colors.blue, Colors.indigo, Colors.purple, Colors.pink, Colors.grey];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title:  Text(tr('Pick Color'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      content: SizedBox(width: 240, child: GridView.count(shrinkWrap: true, crossAxisCount: 6, mainAxisSpacing: 10, crossAxisSpacing: 10, children: colors.map((col) => GestureDetector(onTap: () { setState(() => _chartState.chartColors[cName] = col); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: col, radius: 15))).toList())),
    ));
  }

  // --- View Builders ---

  Widget _buildTiersView(CountryProvider provider) {
    final state = _tiersState;
    if (state.countries.isEmpty) return  Center(child: Text(tr('No data found.')));
    final Map<double, List<Country>> grouped = {};
    for (var n in state.countries) {
      final c = provider.allCountries.firstWhere((x) => x.name == n, orElse: () => provider.allCountries.first);
      double v = _getMetricValue(provider.visitDetails[n], state.selectedMetric);
      if (v > 0) grouped.putIfAbsent(v, () => []).add(c);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: sortedKeys.length, itemBuilder: (ctx, idx) {
      final v = sortedKeys[idx];
      return Column(children: [
        Row(children: [
          SizedBox(width: 80, child: state.selectedMetric == 'Rating' ? _buildStarRating(v) : Text(tr("${_metricEmojis[state.selectedMetric]} ${v.toStringAsFixed(1)}"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(
            child: Wrap(
              spacing: 4, runSpacing: 4,
              children: grouped[v]!.map((c) => Tooltip(
                message: tr(c.name),
                triggerMode: TooltipTriggerMode.tap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _buildFlag(c.isoA2, size: 22),
                ),
              )).toList(),
            ),
          ),
        ]),
        const Divider(height: 12),
      ]);
    });
  }

  Widget _buildTableView(CountryProvider provider) {
    final state = _tableState;
    if (state.countries.isEmpty) return  Center(child: Text(tr('Table is empty.')));
    final active = _metricNames.where((m) => state.selectedMetrics.contains(m)).toList();

    List<String> sortedNames = List.from(state.countries);
    sortedNames.sort((a, b) {
      final valA = _getMetricValue(provider.visitDetails[a], state.sortColumn), valB = _getMetricValue(provider.visitDetails[b], state.sortColumn);
      return state.isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 8, columnSpacing: 16, headingRowHeight: 40, dataRowMinHeight: 32, dataRowMaxHeight: 42,
          columns: [
            DataColumn(label: InkWell(onTap: () => setState(() { if (state.sortColumn == 'Rating') state.isAscending = !state.isAscending; else { state.sortColumn = 'Rating'; state.isAscending = false; } }), child: Row(children: [
              Text(tr(_metricEmojis[state.sortColumn]!), style: const TextStyle(fontSize: 16)),
              Icon(state.isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: Colors.blueAccent),
            ]))),
            ...active.map((m) => DataColumn(label: InkWell(onTap: () => setState(() { if (state.sortColumn == m) state.isAscending = !state.isAscending; else { state.sortColumn = m; state.isAscending = false; } }), child: Text(tr(_metricEmojis[m]!), style: const TextStyle(fontSize: 18))))),
            const DataColumn(label: SizedBox(width: 30)),
          ],
          rows: sortedNames.map((n) {
            final c = provider.allCountries.firstWhere((x) => x.name == n);
            return DataRow(cells: [
              DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Row(children: [_buildFlag(c.isoA2), const SizedBox(width: 8), Text(tr(c.name), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)]))),
              ...active.map((m) => DataCell(m == 'Rating' ? _buildStarRating(_getMetricValue(provider.visitDetails[n], m)) : Text(tr(_getMetricValue(provider.visitDetails[n], m).toStringAsFixed(1)), style: const TextStyle(fontSize: 12)))),
              DataCell(PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                onSelected: (v) {
                  if (v == 'edit') _showEditSlidersDialog(c, provider);
                  else if (v == 'remove') setState(() { state.countries.remove(n); state.filter1 = 'custom'; });
                  else { provider.updateUserMetrics(n, rating: 0, affordability: 0, safety: 0, foodQuality: 0, transport: 0, englishProficiency: 0, cleanliness: 0, attractionDensity: 0, vibrancy: 0, accessibility: 0); setState(() { state.countries.remove(n); state.filter1 = 'custom'; }); }
                },
                itemBuilder: (ctx) => [
                   PopupMenuItem(value: 'remove', child: Text(tr('Remove from view'), style: TextStyle(fontSize: 12))),
                   PopupMenuItem(value: 'edit', child: Text(tr('Edit'), style: TextStyle(fontSize: 12))),
                   PopupMenuItem(value: 'delete', child: Text(tr('Reset Data'), style: TextStyle(fontSize: 12, color: Colors.red))),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChartView(CountryProvider provider) {
    final state = _chartState;
    if (state.countries.isEmpty) return  Center(child: Text(tr('Chart is empty.')));
    final active = _metricNames.where((m) => state.selectedMetrics.contains(m) && m != 'Rating').toList();
    if (active.length < 3) return  Center(child: Text(tr('Select 3+ metrics.')));

    final chartList = state.countries.take(5).toList();
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(children: [
      SizedBox(width: screenWidth * 0.08),
      Container(
        width: 250,
        height: 250,
        child: RadarChart(RadarChartData(
          dataSets: chartList.map((n) {
            final c = provider.allCountries.firstWhere((x) => x.name == n);
            final col = state.chartColors[n] ?? c.themeColor ?? Colors.blue;
            return RadarDataSet(borderColor: col, fillColor: col.withOpacity(0.1), entryRadius: 2, dataEntries: active.map((m) => RadarEntry(value: _getMetricValue(provider.visitDetails[n], m))).toList());
          }).toList(),
          getTitle: (idx, angle) => RadarChartTitle(text: _metricEmojis[active[idx]]!, angle: angle),
          titleTextStyle: const TextStyle(fontSize: 16), titlePositionPercentageOffset: 0.15, tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent), gridBorderData: const BorderSide(color: Colors.black12), tickBorderData: const BorderSide(color: Colors.black12),
        )),
      ),
      Expanded(
        child: Container(
          padding: EdgeInsets.only(left: screenWidth * 0.05 + 20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(chartList.length, (idx) {
            final n = chartList[idx], c = provider.allCountries.firstWhere((x) => x.name == n);
            final col = state.chartColors[n] ?? c.themeColor ?? Colors.blue;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFlag(c.isoA2, size: 18),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Text(tr(n), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                IconButton(icon: const Icon(Icons.sync, size: 14, color: Colors.blueGrey), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => _showCountrySelector(idx, provider)),
                IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.grey), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => _showEditSlidersDialog(c, provider)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 14, color: Colors.redAccent),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      state.countries.remove(n);
                      state.filter1 = 'custom';
                    });
                  },
                ),
                const SizedBox(width: 6),
                GestureDetector(onTap: () => _showColorPicker(n), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: col, shape: BoxShape.circle))),
              ],
            ));
          })),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = Provider.of<CountryProvider>(context);
    _initTabStateIfNeeded(_tiersState, provider);
    _initTabStateIfNeeded(_tableState, provider);
    _initTabStateIfNeeded(_chartState, provider);
    final state = _currentState;

    return Scaffold(
      body: SafeArea(child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: _isHeaderVisible ? 48 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [
            Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.all(3), child: Row(children: ['tiers', 'table', 'chart'].map((m) => GestureDetector(onTap: () => setState(() => _viewMode = m), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), decoration: BoxDecoration(color: _viewMode == m ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(18), boxShadow: _viewMode == m ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : []), child: Text(tr(m.toUpperCase()), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _viewMode == m ? Colors.blueAccent : Colors.blueGrey))))).toList())),
            const Spacer(),
            Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(borderRadius: BorderRadius.circular(16), value: state.filter1, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold), items:  [DropdownMenuItem(value: 'all', child: Text(tr('All'))), DropdownMenuItem(value: 'mark_visited', child: Text(tr('Visited'))), DropdownMenuItem(value: 'unvisited', child: Text(tr('Unvisited'))), DropdownMenuItem(value: 'custom', child: Text(tr('Custom')))], onChanged: (v) { if (v != null) setState(() { state.filter1 = v; _applyFilters(state, provider); }); }))),
            // 🆕 수정: Checklist 아이콘과 metrics 다이얼로그 호출
            IconButton(icon: const Icon(Icons.checklist, size: 18), onPressed: _showMetricsDialog),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue), onPressed: () => _showAddCountryDialog(context, provider)),
          ])),
        ),
        GestureDetector(
          onTap: () => setState(() => _isHeaderVisible = !_isHeaderVisible),
          child: Container(width: double.infinity, height: 18, color: Colors.transparent, alignment: Alignment.topRight, padding: const EdgeInsets.only(right: 12), child: Icon(_isHeaderVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey)),
        ),
        const Divider(height: 1),
        Expanded(child: _viewMode == 'tiers' ? _buildTiersView(provider) : _viewMode == 'table' ? _buildTableView(provider) : _buildChartView(provider)),
      ])),
    );
  }
}