import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:provider/provider.dart';

class GeolocationStatsScreen extends StatelessWidget {
  const GeolocationStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      appBar: AppBar(
        title:  Text(tr('Geolocation Statistics')),
        elevation: 1,
      ),
      body: Consumer<CountryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _EquatorStatsCard(
                  allCountries: provider.allCountries,
                  visitedCountryNames: provider.visitedCountries,
                ),
                const SizedBox(height: 24),
                _LatitudeRankingCard(
                  allCountries: provider.allCountries,
                  visitedCountryNames: provider.visitedCountries,
                ),
                const SizedBox(height: 24),
                _IslandRankingCard(
                  allCountries: provider.allCountries,
                  visitedCountryNames: provider.visitedCountries,
                ),
                const SizedBox(height: 24),
                _CoastlineRankingCard(
                  allCountries: provider.allCountries,
                  visitedCountryNames: provider.visitedCountries,
                ),
                const SizedBox(height: 24),
                _ElevationRankingCard(
                  allCountries: provider.allCountries,
                  visitedCountryNames: provider.visitedCountries,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EquatorStatsCard extends StatelessWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _EquatorStatsCard({required this.allCountries, required this.visitedCountryNames});

  static const List<String> equatorCountryCodes = [
    'BRA', 'COL', 'ECU', 'STP', 'GAB', 'COG', 'COD', 'UGA', 'KEN', 'SOM', 'MDV', 'IDN', 'KIR'
  ];

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final equatorCountries = allCountries.where((c) => equatorCountryCodes.contains(c.isoA3)).toList();
    final total = equatorCountries.length;
    final visited = equatorCountries.where((c) => visitedCountryNames.contains(c.name)).length;
    final percentage = total > 0 ? (visited / total) : 0.0;

    final sortedCountries = List<Country>.from(equatorCountries)..sort((a,b) => a.name.compareTo(b.name));

    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Countries on the Equator'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage,
                    borderRadius: BorderRadius.circular(5),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(width: 16),
                Text(tr('$visited / $total (${(percentage * 100).toStringAsFixed(0)}%)')),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () {
            final highlightGroup = HighlightGroup(
              name: 'Equator',
              color: Colors.brown,
              countryCodes: equatorCountryCodes,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountriesMapScreen(
                  highlightGroups: [highlightGroup],
                ),
              ),
            );
          },
          icon: const Icon(Icons.map_outlined),
          label:  Text(tr('See Map')),
        ),
        children: sortedCountries.map((country) {
          final isVisited = visitedCountryNames.contains(country.name);
          return ListTile(
            dense: true,
            title: Text(tr(country.name)),
            trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
          );
        }).toList(),
      ),
    );
  }
}

class _LatitudeRankingCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _LatitudeRankingCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_LatitudeRankingCard> createState() => _LatitudeRankingCardState();
}

class _LatitudeRankingCardState extends State<_LatitudeRankingCard> {
  int _highLowSegment = 0;
  int _avgMaxSegment = 0;
  List<Country> _rankedList = [];

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  void _prepareList() {
    List<Country> listToRank = widget.allCountries.where((c) => c.centroidLat != 0.0 || c.northLat != 0.0).toList();
    if (_avgMaxSegment == 0) {
      listToRank.sort((a, b) => b.centroidLat.abs().compareTo(a.centroidLat.abs()));
    } else {
      listToRank.sort((a, b) => b.northLat.abs().compareTo(a.northLat.abs()));
    }
    if (_highLowSegment == 1) {
      listToRank = listToRank.reversed.toList();
    }
    setState(() {
      _rankedList = listToRank.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(tr('Latitude Ranking (Top 10)'), style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments:  [
                    ButtonSegment<int>(value: 0, label: Text(tr('High'))),
                    ButtonSegment<int>(value: 1, label: Text(tr('Low'))),
                  ],
                  selected: {_highLowSegment},
                  onSelectionChanged: (s) => setState(() { _highLowSegment = s.first; _prepareList(); }),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments:  [
                    ButtonSegment<int>(value: 0, label: Text(tr('Average'))),
                    ButtonSegment<int>(value: 1, label: Text(tr('Highest Pt.'))),
                  ],
                  selected: {_avgMaxSegment},
                  onSelectionChanged: (s) => setState(() { _avgMaxSegment = s.first; _prepareList(); }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rankedList.length,
            itemBuilder: (context, index) {
              final item = _rankedList[index];
              final isVisited = widget.visitedCountryNames.contains(item.name);
              final value = _avgMaxSegment == 0 ? item.centroidLat : (_highLowSegment == 0 ? item.northLat : item.southLat);
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Text(tr('#${index + 1}'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ),
                title: Text(tr(item.name)),
                subtitle: Text(tr('Latitude: ${value.toStringAsFixed(2)}°')),
                trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
          ),
        ],
      ),
    );
  }
}

class _IslandRankingCard extends StatelessWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;
  final NumberFormat formatter = NumberFormat.decimalPattern('en_US');

  _IslandRankingCard({required this.allCountries, required this.visitedCountryNames});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final listToRank = allCountries.where((c) => c.islandCount > 0).toList();
    listToRank.sort((a, b) => b.islandCount.compareTo(a.islandCount));
    final rankedList = listToRank.take(10).toList();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(tr('Island Count (Top 10)'), style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rankedList.length,
            itemBuilder: (context, index) {
              final item = rankedList[index];
              final isVisited = visitedCountryNames.contains(item.name);
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Text(tr('#${index + 1}'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ),
                title: Text(tr(item.name)),
                subtitle: Text(tr('Islands: ${formatter.format(item.islandCount)}')),
                trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
          ),
        ],
      ),
    );
  }
}

class _CoastlineRankingCard extends StatelessWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;
  final NumberFormat formatter = NumberFormat.decimalPattern('en_US');

  _CoastlineRankingCard({required this.allCountries, required this.visitedCountryNames});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final listToRank = allCountries.where((c) => c.coastlineLength > 0).toList();
    listToRank.sort((a, b) => b.coastlineLength.compareTo(a.coastlineLength));
    final rankedList = listToRank.take(10).toList();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(tr('Coastline Length (Top 10)'), style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rankedList.length,
            itemBuilder: (context, index) {
              final item = rankedList[index];
              final isVisited = visitedCountryNames.contains(item.name);
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Text(tr('#${index + 1}'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ),
                title: Text(tr(item.name)),
                subtitle: Text(tr('Coastline: ${formatter.format(item.coastlineLength)} km')),
                trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
          ),
        ],
      ),
    );
  }
}

class _ElevationRankingCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _ElevationRankingCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_ElevationRankingCard> createState() => _ElevationRankingCardState();
}

class _ElevationRankingCardState extends State<_ElevationRankingCard> {
  int _selectedSegment = 0;
  List<Country> _rankedList = [];
  final NumberFormat formatter = NumberFormat.decimalPattern('en_US');

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  void _prepareList() {
    List<Country> listToRank;

    if (_selectedSegment == 0) {
      listToRank = widget.allCountries.where((c) => c.elevationHighest > 0).toList();
      listToRank.sort((a, b) => b.elevationHighest.compareTo(a.elevationHighest));
    } else {
      listToRank = widget.allCountries.where((c) => c.elevationAverage > 0).toList();
      listToRank.sort((a, b) => b.elevationAverage.compareTo(a.elevationAverage));
    }
    setState(() {
      _rankedList = listToRank.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(tr('Elevation (Top 10)'), style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments:  [
                ButtonSegment<int>(value: 0, label: Text(tr('Highest'))),
                ButtonSegment<int>(value: 1, label: Text(tr('Average'))),
              ],
              selected: {_selectedSegment},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedSegment = newSelection.first;
                  _prepareList();
                });
              },
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rankedList.length,
            itemBuilder: (context, index) {
              final item = _rankedList[index];
              final isVisited = widget.visitedCountryNames.contains(item.name);
              final value = _selectedSegment == 0 ? item.elevationHighest : item.elevationAverage;
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Text(tr('#${index + 1}'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ),
                title: Text(tr(item.name)),
                subtitle: Text(tr('Elevation: ${formatter.format(value)} m')),
                trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
          ),
        ],
      ),
    );
  }
}