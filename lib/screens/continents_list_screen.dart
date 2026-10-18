import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:provider/provider.dart';

class ContinentsListScreen extends StatelessWidget {
  const ContinentsListScreen({super.key});

  static const List<Map<String, dynamic>> continents = [
    {'name': 'Asia', 'icon': Icons.language}, {'name': 'Europe', 'icon': Icons.euro}, {'name': 'Africa', 'icon': Icons.public},
    {'name': 'North America', 'icon': Icons.public}, {'name': 'South America', 'icon': Icons.south_america}, {'name': 'Oceania', 'icon': Icons.public},
  ];

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = Provider.of<CountryProvider>(context);

    return Scaffold(
      appBar: AppBar(title:  Text(tr('Continents'))),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: continents.length,
        itemBuilder: (context, index) {
          final continentName = continents[index]['name'];
          final continentIcon = continents[index]['icon'];

          final countriesInContinent = provider.allCountries.where((c) => c.continent == continentName).toList();
          final visitedInContinent = countriesInContinent.where((c) => provider.visitedCountries.contains(c.name)).length;
          final totalInContinent = countriesInContinent.length;
          final percent = totalInContinent > 0 ? (visitedInContinent / totalInContinent * 100) : 0.0;
          final stats = '$visitedInContinent/$totalInContinent (${percent.toStringAsFixed(0)}%)';

          // --- 수정된 부분: ExpansionTile 사용 및 내부 로직 구현 ---
          final Map<String, List<Country>> countriesBySubregion = {};
          for (var country in countriesInContinent) {
            final subregionKey = country.subregion ?? 'Unclassified';
            countriesBySubregion.putIfAbsent(subregionKey, () => []).add(country);
          }
          final sortedSubregions = countriesBySubregion.keys.toList()..sort();

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: Icon(continentIcon, size: 30, color: Theme.of(context).primaryColor),
              title: Text(tr(continentName), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              subtitle: Text(tr(stats), style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(region: continentName))),
                child:  Text(tr('Map')),
              ),
              children: sortedSubregions.map<Widget>((subregion) {
                final subregionCountries = countriesBySubregion[subregion]!;
                subregionCountries.sort((a, b) => a.name.compareTo(b.name));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0, right: 16.0),
                      child: Text(
                        tr(subregion),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ...subregionCountries.map((country) {
                      final isVisited = provider.visitedCountries.contains(country.name);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 24, right: 16),
                        title: Text(tr(country.name), style: const TextStyle(fontSize: 14)),
                        trailing: isVisited
                            ? Icon(Icons.check, color: Theme.of(context).primaryColor, size: 20)
                            : null,
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          );
          // ----------------------------------------------------
        },
      ),
    );
  }
}