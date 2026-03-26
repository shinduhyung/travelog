// lib/screens/language_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/language_family_provider.dart';
import 'package:jidoapp/providers/language_provider.dart';
import 'package:jidoapp/screens/language_family_map_screen.dart';
import 'package:jidoapp/screens/language_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 임포트 추가
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

// Helper: ISO A2 → 국기 이모지
String flagEmoji(String isoA2) {
  if (isoA2.length != 2) return '';
  final base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + isoA2.codeUnitAt(0)) +
      String.fromCharCode(base + isoA2.codeUnitAt(1));
}

// Helper: 국가 클릭시 CountryDetailScreen으로 이동
void navigateToCountryDetail(BuildContext context, Country country) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
  );
}

// isDominant 헬퍼 함수
bool isDominant(String language, Country country) {
  const nonDominantMap = {
    'English': {'CMR', 'SGP', 'CAN', 'ZAF'},
    'Chinese': {'MYS', 'SGP'},
    'Spanish': {'BLZ', 'GNQ'},
    'French': {'BEL', 'CMR', 'CAN', 'LUX', 'CHE'},
    'Arabic': {'DZA', 'IRQ', 'MAR', 'TUN'},
    'Portuguese': {'AGO', 'GNB', 'MOZ', 'TLS'},
    'German': {'CHE', 'LUX'},
  };

  if (language == 'Dutch') return country.isoA3 == 'NLD';
  if (language == 'Russian') return country.isoA3 == 'RUS';
  if (nonDominantMap.containsKey(language)) {
    return !nonDominantMap[language]!.contains(country.isoA3);
  }
  return true;
}

enum LanguageStatView { languages, families }

class LanguageStatsScreen extends StatefulWidget {
  const LanguageStatsScreen({super.key});

  @override
  State<LanguageStatsScreen> createState() => _LanguageStatsScreenState();
}

class _LanguageStatsScreenState extends State<LanguageStatsScreen> {
  LanguageStatView _currentView = LanguageStatView.languages;
  bool _includeNonDominant = true;
  bool _isLoadingSettings = true;
  String? _expandedLanguage = null;
  Set<String> _expandedFamilies = {};

  final Map<String, Color> _languageColors = {
    'English': const Color(0xFFA0522D), 'French': const Color(0xFF000080),
    'Spanish': const Color(0xFFFFD700), 'Portuguese': const Color(0xFF87CEEB),
    'Arabic': const Color(0xFF2E8B57), 'Russian': const Color(0xFF2F4F4F),
    'Chinese': const Color(0xFFFF0000),
    'German': const Color(0xFF9966CC),
    'Dutch': const Color(0xFFFFA500),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _includeNonDominant = prefs.getBool('includeNonDominantLanguages') ?? true;
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('includeNonDominantLanguages', _includeNonDominant);
  }

  void _toggleLanguageExpanded(String itemName) {
    setState(() {
      if (_expandedLanguage == itemName) {
        _expandedLanguage = null;
      } else {
        _expandedLanguage = itemName;
      }
    });
  }

  void _toggleFamilyExpanded(String familyName) {
    setState(() {
      if (_expandedFamilies.contains(familyName)) {
        _expandedFamilies.remove(familyName);
      } else {
        _expandedFamilies.add(familyName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer3<CountryProvider, LanguageProvider, LanguageFamilyProvider>(
        builder: (context, countryProvider, languageProvider, langFamilyProvider, child) {
          if (countryProvider.isLoading || languageProvider.isLoading || langFamilyProvider.isLoading || _isLoadingSettings) {
            return const Center(child: CircularProgressIndicator());
          }

          // Families 뷰인지 확인 (스위치 활성화 여부 결정용)
          final bool isLanguagesView = _currentView == LanguageStatView.languages;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    // 1. Languages / Families 세그먼트 버튼 (왼쪽 배치)
                    Expanded(
                      child: SegmentedButton<LanguageStatView>(
                        segments: const [
                          ButtonSegment(value: LanguageStatView.languages, label: Text('Languages')),
                          ButtonSegment(value: LanguageStatView.families, label: Text('Families')),
                        ],
                        selected: {_currentView},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _currentView = newSelection.first;
                            _expandedLanguage = null;
                            _expandedFamilies.clear();
                          });
                        },
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          selectedForegroundColor: Colors.black87,
                          selectedBackgroundColor: Colors.grey.shade300,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),

                    // 2. Non-dominant 스위치 (항상 표시하되 Families 뷰에서는 비활성화)
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Non-dominant',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLanguagesView ? Colors.grey.shade700 : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _includeNonDominant,
                            onChanged: isLanguagesView
                                ? (value) {
                              setState(() {
                                _includeNonDominant = value;
                                _expandedLanguage = null;
                              });
                              _saveSettings();
                            }
                                : null, // null이면 비활성화됨
                            activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
                            activeColor: Theme.of(context).primaryColor,
                            inactiveThumbColor: Colors.grey.shade500,
                            inactiveTrackColor: Colors.grey.shade300,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _buildMapButton(),

              const Divider(height: 1),
              Expanded(
                child: _currentView == LanguageStatView.languages
                    ? _buildLanguagesList(countryProvider, languageProvider)
                    : _buildFamiliesList(context, countryProvider, langFamilyProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapButton() {
    bool isFamilyView = _currentView == LanguageStatView.families;
    final IconData mapIcon = isFamilyView ? Icons.account_tree : Icons.language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.lightBlue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          icon: Icon(mapIcon, color: Colors.white, size: 20),
          label: Text(
            isFamilyView ? 'Language Family Map' : 'Global Language Map',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          onPressed: () {
            if (isFamilyView) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageFamilyMapScreen()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageMapScreen()))
                  .then((_) => _loadSettings());
            }
          },
        ),
      ),
    );
  }

  Widget _buildLanguagesList(CountryProvider countryProvider, LanguageProvider languageProvider) {
    final Map<String, List<Country>> countriesByLanguage = {};
    for (var country in countryProvider.allCountries) {
      final langInfo = languageProvider.languageDataMap[country.isoA3];
      if (langInfo != null) {
        for (var lang in langInfo.languages) {
          countriesByLanguage.putIfAbsent(lang.language, () => []).add(country);
        }
      }
    }
    final languagesToShow = [
      'English', 'Chinese', 'Spanish', 'French', 'Arabic',
      'Portuguese', 'German', 'Dutch', 'Russian'
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: languagesToShow.length,
      itemBuilder: (context, index) {
        final langName = languagesToShow[index];
        final allCountriesForLang = countriesByLanguage[langName] ?? [];
        if (allCountriesForLang.isEmpty) return const SizedBox.shrink();

        final countriesToShow = _includeNonDominant
            ? allCountriesForLang
            : allCountriesForLang.where((c) => isDominant(langName, c)).toList();
        if (countriesToShow.isEmpty) return const SizedBox.shrink();

        countriesToShow.sort((a, b) => a.name.compareTo(b.name));

        return _LanguageStatTile(
          title: langName,
          countries: countriesToShow,
          visitedNames: countryProvider.visitedCountries,
          langColor: _languageColors[langName] ?? Theme.of(context).primaryColor,
          isExpanded: _expandedLanguage == langName,
          onToggle: _toggleLanguageExpanded,
        );
      },
    );
  }

  Widget _buildFamiliesList(BuildContext context, CountryProvider countryProvider, LanguageFamilyProvider langFamilyProvider) {
    final countries = countryProvider.allCountries;
    final visited = countryProvider.visitedCountries;
    final langFamilyData = langFamilyProvider.languageFamilyDataMap;

    final groupedData = groupBy(
        countries.where((c) => langFamilyData.containsKey(c.isoA3)),
            (Country c) => langFamilyData[c.isoA3]!.family
    ).map((family, familyCountries) {
      return MapEntry(family, groupBy(
          familyCountries,
              (Country c) => langFamilyData[c.isoA3]!.subbranch
      ).map((branch, branchCountries) {
        return MapEntry(branch, groupBy(
            branchCountries,
                (Country c) => langFamilyData[c.isoA3]!.subsubbranch
        ));
      }));
    });

    final sortedFamilies = groupedData.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedFamilies.length,
      itemBuilder: (context, index) {
        final familyName = sortedFamilies[index];
        final branches = groupedData[familyName]!;

        final List<Country> familyCountries = branches.values
            .expand((subBranchMap) => subBranchMap.values)
            .expand((countryList) => countryList)
            .toList()
            .cast<Country>();

        bool isFamilyTerminal = branches.length <= 1 ||
            familyName == 'Mongolic' || familyName == 'Koreanic' || familyName == 'Japonic';

        return _FamilyStatTile(
          id: familyName,
          title: familyName,
          countries: familyCountries,
          visitedNames: visited,
          itemColor: langFamilyProvider.familyColors[familyName]!,
          onMapTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LanguageFamilyMapScreen(familyFilter: familyName))),
          isExpanded: _expandedFamilies.contains(familyName),
          onToggle: isFamilyTerminal ? null : _toggleFamilyExpanded,
          isTerminal: isFamilyTerminal,
          isSubItem: false,
          child: isFamilyTerminal ? const SizedBox.shrink() : Column(
            children: (branches.keys.toList()..sort()).map((branchName) {
              final subbranches = branches[branchName]!;

              final List<Country> branchCountries = subbranches.values
                  .expand((countryList) => countryList)
                  .toList()
                  .cast<Country>();

              bool isBranchTerminal = subbranches.length <= 1 || branchName == 'Indo-Aryan';

              return _FamilyStatTile(
                id: branchName,
                title: branchName,
                countries: branchCountries,
                visitedNames: visited,
                itemColor: langFamilyProvider.subbranchColors[branchName]!,
                onMapTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LanguageFamilyMapScreen(subbranchFilter: branchName))),
                isSubItem: true,
                isExpanded: _expandedFamilies.contains(branchName),
                onToggle: isBranchTerminal ? null : _toggleFamilyExpanded,
                isTerminal: isBranchTerminal,
                child: isBranchTerminal ? const SizedBox.shrink() : Column(
                  children: (subbranches.keys.toList()..sort()).map((subbranchName) {
                    final subbranchCountries = subbranches[subbranchName]!;

                    String displaySubbranchName = subbranchName;
                    if (branchName == 'Romance' && subbranchName.endsWith('-Romance')) {
                      displaySubbranchName = subbranchName.substring(0, subbranchName.length - '-Romance'.length);
                    } else if (subbranchName.endsWith(" $branchName") && subbranchName.length > branchName.length + 1) {
                      displaySubbranchName = subbranchName.substring(0, subbranchName.length - " $branchName".length);
                    }

                    return _FamilyStatTile(
                      id: subbranchName,
                      title: displaySubbranchName,
                      countries: subbranchCountries,
                      visitedNames: visited,
                      itemColor: langFamilyProvider.subsubbranchColors[subbranchName]!,
                      onMapTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LanguageFamilyMapScreen(subsubbranchFilter: subbranchName))),
                      isSubItem: true,
                      isExpanded: _expandedFamilies.contains(subbranchName),
                      onToggle: _toggleFamilyExpanded,
                      child: const SizedBox.shrink(),
                      isTerminal: true,
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _LanguageStatTile({
    required String title,
    required List<Country> countries,
    required Set<String> visitedNames,
    required Color langColor,
    required bool isExpanded,
    required Function(String) onToggle,
  }) {
    final total = countries.length;
    final visited = countries.where((c) => visitedNames.contains(c.name)).length;
    final percentage = total > 0 ? (visited / total) : 0.0;
    final theme = Theme.of(context);
    List<Country> sortedCountries = List.from(countries)..sort((a,b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? langColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isExpanded ? langColor.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isExpanded ? langColor.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => onToggle(title),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isExpanded ? FontWeight.w900 : FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: langColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 8,
                              backgroundColor: langColor.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(langColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$visited / $total Countries',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                child: !isExpanded ? null : Column(
                  children: [
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 5.5,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: sortedCountries.length,
                        itemBuilder: (context, index) {
                          final country = sortedCountries[index];
                          final isVisited = visitedNames.contains(country.name);
                          return InkWell( // 클릭 시 상세 화면 이동
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => navigateToCountryDetail(context, country),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: isVisited ? langColor : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    country.name,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: Icon(Icons.map_outlined, color: langColor),
                          label: Text('View on Map', style: TextStyle(color: langColor)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LanguageMapScreen(languageFilter: title))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _FamilyStatTile({
    required String id,
    required String title,
    required List<Country> countries,
    required Set<String> visitedNames,
    required Color itemColor,
    required VoidCallback onMapTap,
    required bool isExpanded,
    required Function(String)? onToggle,
    required Widget child,
    required bool isTerminal,
    required bool isSubItem,
  }) {
    final total = countries.length;
    final visited = countries.where((c) => visitedNames.contains(c.name)).length;
    final percentage = total > 0 ? (visited / total) : 0.0;
    final theme = Theme.of(context);
    List<Country> sortedCountries = List.from(countries)..sort((a,b) => a.name.compareTo(b.name));

    double leftMargin = isSubItem ? 16.0 : 0.0;
    double innerLeftPadding = isSubItem ? 0.0 : 4.0;
    if (isSubItem && !isTerminal) leftMargin = 32.0;

    String displayTitle = title;
    TextStyle titleStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: isExpanded ? FontWeight.w900 : FontWeight.bold,
      fontSize: 16,
      color: Colors.black87,
    );
    if (!isSubItem) {
      titleStyle = theme.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.black87,
      );
    }
    if (title == 'Malayo-Polynesian') displayTitle = 'Malayo-Poly.';

    return Padding(
      padding: EdgeInsets.fromLTRB(leftMargin, 0, 0, 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? itemColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isExpanded ? itemColor.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isExpanded ? itemColor.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: total > 0 && onToggle != null ? () => onToggle(id) : null,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16 + innerLeftPadding, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(displayTitle, style: titleStyle, overflow: TextOverflow.ellipsis),
                        ),
                        if (total > 0)
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: itemColor,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (total > 0)
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 8,
                                backgroundColor: itemColor.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(itemColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$visited / $total Countries',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!isTerminal)
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            )
                          else
                            const SizedBox(width: 24),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('No countries in this group.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                      )
                  ],
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                child: !isExpanded ? null : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    if (isTerminal && countries.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 5.5,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: sortedCountries.length,
                          itemBuilder: (context, index) {
                            final country = sortedCountries[index];
                            final isVisited = visitedNames.contains(country.name);
                            return InkWell( // 클릭 시 상세 화면 이동
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => navigateToCountryDetail(context, country),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 16,
                                    color: isVisited ? itemColor : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      country.name,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (total > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: Icon(Icons.map_outlined, color: itemColor),
                            label: Text('View on Map', style: TextStyle(color: itemColor)),
                            onPressed: onMapTap,
                          ),
                        ),
                      ),
                    if (!isTerminal)
                      child,
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}