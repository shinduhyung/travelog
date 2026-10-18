import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:provider/provider.dart';

class ItemListScreen extends StatelessWidget {
  final String title;
  final List<Country> countries;

  const ItemListScreen({
    super.key,
    required this.title,
    required this.countries,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final visitedCountryNames = Provider.of<CountryProvider>(context, listen: false).visitedCountries;

    // 국가 목록을 이름순으로 정렬
    final sortedCountries = List<Country>.from(countries)..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(title)),
      ),
      body: ListView.builder(
        itemCount: sortedCountries.length,
        itemBuilder: (context, index) {
          final country = sortedCountries[index];
          final isVisited = visitedCountryNames.contains(country.name);
          return ListTile(
            title: Text(tr(country.name)),
            trailing: isVisited ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
          );
        },
      ),
    );
  }
}