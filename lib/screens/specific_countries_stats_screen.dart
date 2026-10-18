// lib/screens/specific_countries_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/country_subregions_screen.dart'; // 🆕 곧 만들 파일
import 'package:provider/provider.dart';

// 'World Statistics'의 'Countries' 탭에 표시될 내용입니다.
class SpecificCountriesStatsScreen extends StatelessWidget {
  const SpecificCountriesStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);
    if (countryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🆕 국가 목록 필터링: 'United States'와 'South Korea'만 선택
    final List<String> targetCountryNames = ['United States', 'South Korea'];
    final countries = countryProvider.filteredCountries
        .where((country) => targetCountryNames.contains(country.name))
        .toList();

    // 국가 목록을 가져와 알파벳순으로 정렬
    countries.sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        return ListTile(
          title: Text(tr(country.name)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // 탭하면 해당 국가의 세부 지역 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CountrySubregionsScreen(country: country),
              ),
            );
          },
        );
      },
    );
  }
}