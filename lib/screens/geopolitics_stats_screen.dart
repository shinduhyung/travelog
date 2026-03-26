// lib/screens/geopolitics_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:flutter/services.dart'; // rootBundle
import 'dart:convert'; // json.decode
import 'package:collection/collection.dart'; // for list.firstWhereOrNull
import 'dart:math' as math; // For math.max



// Helper: ISO A2 → 국기 이모지
String flagEmoji(String isoA2) {
  if (isoA2.length != 2) return '';
  final base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + isoA2.codeUnitAt(0)) +
      String.fromCharCode(base + isoA2.codeUnitAt(1));
}

// Helper: 국가 클릭 → CountryDetailScreen
void navigateToCountryDetail(BuildContext context, Country country) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
  );
}

// Data Class: Membership/Group Info (Icon added)
class GroupInfo {
  final String title;
  final IconData icon;
  final List<String> memberCodes;
  final Color themeColor;
  final String mapLegend;
  final List<String>? subMemberCodes;
  final Color? subThemeColor;
  final String? subMapLegend;
  final String? note;

  GroupInfo({
    required this.title,
    required this.icon,
    required this.memberCodes,
    required this.themeColor,
    required this.mapLegend,
    this.subMemberCodes,
    this.subThemeColor,
    this.subMapLegend,
    this.note,
  });
}

// GeopoliticsStatsScreen: Acts as the tab screen inside the World Stats wrapper.
class GeopoliticsStatsScreen extends StatelessWidget {
  const GeopoliticsStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);

    if (countryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCountries = countryProvider.filteredCountries;
    final visitedCountryNames = countryProvider.visitedCountries;

    // Scaffold and AppBar are handled by the wrapper (MilitaryStatsScreen)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ColdWarGeopoliticsSection(
            countriesToDisplay: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),
          // Combined Membership Card
          _CombinedMembershipCard(
            allCountries: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),
          // Combined Recognition Card
          _CombinedRecognitionCard(
            allCountries: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
        ],
      ),
    );
  }
}

// Combined Membership Card Widget
class _CombinedMembershipCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedMembershipCard({
    required this.allCountries,
    required this.visitedCountryNames,
  });

  @override
  State<_CombinedMembershipCard> createState() =>
      _CombinedMembershipCardState();
}

class _CombinedMembershipCardState extends State<_CombinedMembershipCard> {
  late final List<GroupInfo> _groups;
  late GroupInfo _selectedGroup;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _groups = [
      GroupInfo(
        title: 'UN',
        icon: Icons.public,
        memberCodes: const ['AFG', 'ALB', 'DZA', 'AND', 'AGO', 'ATG', 'ARG', 'ARM', 'AUS', 'AUT', 'AZE', 'BHS', 'BHR', 'BGD', 'BRB', 'BLR', 'BEL', 'BLZ', 'BEN', 'BTN', 'BOL', 'BIH', 'BWA', 'BRA', 'BRN', 'BGR', 'BFA', 'BDI', 'CPV', 'KHM', 'CMR', 'CAN', 'CAF', 'TCD', 'CHL', 'CHN', 'COL', 'COM', 'COG', 'CRI', 'CIV', 'HRV', 'CUB', 'CYP', 'CZE', 'PRK', 'COD', 'DNK', 'DJI', 'DMA', 'DOM', 'ECU', 'EGY', 'SLV', 'GNQ', 'ERI', 'EST', 'SWZ', 'ETH', 'FJI', 'FIN', 'FRA', 'GAB', 'GMB', 'GEO', 'DEU', 'GHA', 'GRC', 'GRD', 'GTM', 'GIN', 'GNB', 'GUY', 'HTI', 'HND', 'HUN', 'ISL', 'IND', 'IDN', 'IRN', 'IRQ', 'IRL', 'ISR', 'ITA', 'JAM', 'JPN', 'JOR', 'KAZ', 'KEN', 'KIR', 'KWT', 'KGZ', 'LAO', 'LVA', 'LBN', 'LSO', 'LBR', 'LBY', 'LIE', 'LTU', 'LUX', 'MDG', 'MWI', 'MYS', 'MDV', 'MLI', 'MLT', 'MHL', 'MRT', 'MUS', 'MEX', 'FSM', 'MCO', 'MNG', 'MNE', 'MAR', 'MOZ', 'MMR', 'NAM', 'NRU', 'NPL', 'NLD', 'NZL', 'NIC', 'NER', 'NGA', 'NIU', 'MKD', 'NOR', 'OMN', 'PAK', 'PLW', 'PAN', 'PNG', 'PRY', 'PER', 'PHL', 'POL', 'PRT', 'QAT', 'KOR', 'MDA', 'ROU', 'RUS', 'RWA', 'KNA', 'LCA', 'WSM', 'SMR', 'STP', 'SAU', 'SEN', 'SRB', 'SYC', 'SLE', 'SGP', 'SVK', 'SVN', 'SLB', 'SOM', 'ZAF', 'SSD', 'ESP', 'LKA', 'SDN', 'SUR', 'SWE', 'CHE', 'SYR', 'TJK', 'TZA', 'THA', 'TLS', 'TGO', 'TON', 'TTO', 'TUN', 'TUR', 'TKM', 'TUV', 'UGA', 'UKR', 'ARE', 'GBR', 'USA', 'URY', 'UZB', 'VUT', 'VEN', 'VNM', 'YEM', 'ZMB', 'ZWE'],
        subMemberCodes: const ['CHN', 'FRA', 'RUS', 'GBR', 'USA'],
        themeColor: Colors.blue.shade700,
        subThemeColor: Colors.teal.shade700,
        mapLegend: 'UN Member',
        subMapLegend: 'Permanent Member (*)',
        note: '(*) UN Security Council Permanent Member',
      ),
      GroupInfo(
        title: 'Five Eyes',
        icon: Icons.visibility,
        memberCodes: const ['USA', 'GBR', 'CAN', 'AUS', 'NZL'],
        themeColor: Colors.teal.shade800,
        mapLegend: 'Five Eyes Member',
      ),
      GroupInfo(
        title: 'G7 / G20',
        icon: Icons.groups,
        memberCodes: const ['ARG', 'AUS', 'BRA', 'CAN', 'CHN', 'FRA', 'DEU', 'IND', 'IDN', 'ITA', 'JPN', 'KOR', 'MEX', 'RUS', 'SAU', 'ZAF', 'TUR', 'GBR', 'USA'],
        themeColor: Colors.indigo.shade500,
        mapLegend: 'G20 Member',
        subMemberCodes: const ['CAN', 'FRA', 'DEU', 'ITA', 'JPN', 'GBR', 'USA'],
        subThemeColor: Colors.deepOrange.shade500,
        subMapLegend: 'G7 Member (*)',
        note: '(*) G7 Member (also part of G20)',
      ),
      GroupInfo(
        title: 'NATO',
        icon: Icons.shield,
        memberCodes: const ['ALB', 'BEL', 'BGR', 'CAN', 'HRV', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'ISL', 'ITA', 'LVA', 'LTU', 'LUX', 'MNE', 'NLD', 'MKD', 'NOR', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE', 'TUR', 'GBR', 'USA'],
        themeColor: Colors.blueGrey.shade700,
        mapLegend: 'NATO Member',
      ),
      GroupInfo(
        title: 'EU',
        icon: Icons.euro_symbol,
        memberCodes: const ['AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE'],
        themeColor: Colors.blue.shade400,
        mapLegend: 'EU Member',
      ),
      GroupInfo(
        title: 'Schengen Area',
        icon: Icons.airplanemode_active,
        memberCodes: const ['AUT', 'BEL', 'BGR', 'HRV', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'ISL', 'ITA', 'LVA', 'LIE', 'LTU', 'LUX', 'MLT', 'NLD', 'NOR', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'ESP', 'SWE', 'CHE'],
        themeColor: Colors.indigo.shade300,
        mapLegend: 'Schengen Member (EU)',
        subMemberCodes: const ['ISL', 'LIE', 'NOR', 'CHE'],
        subThemeColor: Colors.deepPurple.shade300,
        subMapLegend: 'Schengen Member (Non-EU)*',
        note: '(*) Non-EU Schengen Member',
      ),
      GroupInfo(
        title: 'OECD',
        icon: Icons.business,
        memberCodes: const ['AUS', 'AUT', 'BEL', 'CAN', 'CHL', 'COL', 'CRI', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', 'HUN', 'ISL', 'IRL', 'ISR', 'ITA', 'JPN', 'KOR', 'LVA', 'LTU', 'LUX', 'MEX', 'NLD', 'NZL', 'NOR', 'POL', 'PRT', 'SVK', 'SVN', 'ESP', 'SWE', 'CHE', 'TUR', 'GBR', 'USA'],
        themeColor: Colors.purple.shade500,
        mapLegend: 'OECD Member',
      ),
      GroupInfo(
        title: 'BRICS',
        icon: Icons.handshake,
        memberCodes: const ['BRA', 'RUS', 'IND', 'CHN', 'ZAF', 'EGY', 'ETH', 'IRN', 'SAU', 'ARE'],
        themeColor: Colors.green.shade700,
        mapLegend: 'BRICS Member',
      ),
      GroupInfo(
        title: 'APEC',
        icon: Icons.lan,
        memberCodes: const ['AUS', 'BRN', 'CAN', 'CHL', 'CHN', 'HKG', 'IDN', 'JPN', 'KOR', 'MYS', 'MEX', 'NZL', 'PNG', 'PER', 'PHL', 'RUS', 'SGP', 'TWN', 'THA', 'USA', 'VNM'],
        themeColor: Colors.blueGrey.shade300,
        mapLegend: 'APEC Member',
      ),
      GroupInfo(
        title: 'QUAD',
        icon: Icons.security,
        memberCodes: const ['AUS', 'IND', 'JPN', 'USA'],
        themeColor: Colors.blueAccent.shade700,
        mapLegend: 'QUAD Member',
      ),
      GroupInfo(
        title: 'SCO',
        icon: Icons.sync,
        memberCodes: const ['CHN', 'IND', 'IRN', 'KAZ', 'KGZ', 'PAK', 'RUS', 'TJK', 'UZB'],
        themeColor: Colors.cyan.shade700,
        mapLegend: 'SCO Member',
      ),
      GroupInfo(
        title: 'ASEAN',
        icon: Icons.holiday_village,
        memberCodes: const ['BRN', 'KHM', 'IDN', 'LAO', 'MYS', 'MMR', 'PHL', 'SGP', 'THA', 'VNM'],
        themeColor: Colors.orange.shade700,
        mapLegend: 'ASEAN Member',
      ),
      GroupInfo(
        title: 'OPEC',
        icon: Icons.oil_barrel,
        memberCodes: const ['DZA', 'COG', 'GNQ', 'GAB', 'IRN', 'IRQ', 'KWT', 'LBY', 'NGA', 'SAU', 'ARE', 'VEN'],
        themeColor: Colors.red.shade700,
        mapLegend: 'OPEC Member',
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((country) =>
        _selectedGroup.memberCodes.contains(country.isoA3)
    ).toList();

    final total = currentCountries.length;
    final visited = currentCountries.where((country) =>
        widget.visitedCountryNames.contains(country.name)
    ).length;
    final percentage = total > 0 ? (visited / total) : 0.0;

    final sortedCountries = List<Country>.from(currentCountries)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<GroupInfo>(
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) {
                  return DropdownMenuItem<GroupInfo>(
                    value: group,
                    child: Row(
                      children: [
                        Icon(group.icon, color: group.themeColor),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (GroupInfo? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedGroup = newValue;
                      _isExpanded = false;
                    });
                  }
                },
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Visited", style: textTheme.bodyLarge),
                            Text.rich(
                                TextSpan(
                                    text: '$visited',
                                    style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                          text: ' / $total',
                                          style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)
                                      ),
                                    ]
                                )
                            )
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final Set<String> currentFilteredIsoA3s = widget.allCountries.map((c) => c.isoA3).toSet();
                            final List<HighlightGroup> groups = [];
                            final mainMembers = _selectedGroup.memberCodes.where((c) => currentFilteredIsoA3s.contains(c)).toList();
                            final subMembers = _selectedGroup.subMemberCodes?.where((c) => currentFilteredIsoA3s.contains(c)).toList() ?? [];

                            groups.add(HighlightGroup(
                                name: _selectedGroup.mapLegend,
                                color: _selectedGroup.themeColor,
                                countryCodes: mainMembers.where((c) => !subMembers.contains(c)).toList()));

                            if (subMembers.isNotEmpty) {
                              groups.add(HighlightGroup(
                                  name: _selectedGroup.subMapLegend!,
                                  color: _selectedGroup.subThemeColor!,
                                  countryCodes: subMembers));
                            }

                            Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedGroup.themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _selectedGroup.themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(_selectedGroup.themeColor),
                        ),
                      ),
                    ),
                  ],
                )
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: sortedCountries.length,
                    itemBuilder: (context, index) {
                      final country = sortedCountries[index];
                      final isVisited = widget.visitedCountryNames.contains(country.name);
                      final isSubMember = _selectedGroup.subMemberCodes?.contains(country.isoA3) ?? false;

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => navigateToCountryDetail(context, country),
                        child: Row(
                          children: [
                            Icon(
                              isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: isVisited ? _selectedGroup.themeColor : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                country.name,
                                style: textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSubMember)
                              Icon(Icons.star, size: 16, color: _selectedGroup.subThemeColor),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedGroup.note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Text(_selectedGroup.note!, style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Combined Recognition Card Widget
class _CombinedRecognitionCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedRecognitionCard({
    required this.allCountries,
    required this.visitedCountryNames,
  });

  @override
  State<_CombinedRecognitionCard> createState() => _CombinedRecognitionCardState();
}

class _CombinedRecognitionCardState extends State<_CombinedRecognitionCard> {
  late final List<GroupInfo> _groups;
  late GroupInfo _selectedGroup;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _groups = [
      GroupInfo(
        title: 'Israel Recognition',
        icon: Icons.star,
        memberCodes: const ['IND', 'CHN', 'USA', 'NGA', 'BRA', 'RUS', 'ETH', 'MEX', 'JPN', 'EGY', 'PHL', 'COD', 'VNM', 'TUR', 'DEU', 'THA', 'TZA', 'GBR', 'FRA', 'ZAF', 'ITA', 'KEN', 'MMR', 'KOR', 'SDN', 'UGA', 'ESP', 'ARG', 'CAN', 'AGO', 'UKR', 'MAR', 'POL', 'UZB', 'MOZ', 'GHA', 'PER', 'MDG', 'CIV', 'CMR', 'NPL', 'AUS', 'BFA', 'LKA', 'MWI', 'ZMB', 'TCD', 'KAZ', 'CHL', 'SEN', 'ROU', 'GTM', 'NLD', 'ECU', 'KHM', 'ZWE', 'GIN', 'BEN', 'RWA', 'BDI', 'SSD', 'HTI', 'BEL', 'JOR', 'DOM', 'ARE', 'HND', 'TJK', 'PNG', 'SWE', 'CZE', 'PRT', 'AZE', 'GRC', 'TGO', 'HUN', 'AUT', 'BLR', 'CHE', 'SLE', 'LAO', 'TKM', 'KGZ', 'PRY', 'BGR', 'SRB', 'COG', 'SLV', 'DNK', 'SGP', 'LBR', 'FIN', 'NOR', 'PSE', 'CAF', 'SVK', 'IRL', 'NZL', 'CRI', 'PAN', 'HRV', 'GEO', 'ERI', 'MNG', 'URY', 'BIH', 'NAM', 'MDA', 'ARM', 'JAM', 'LTU', 'GMB', 'ALB', 'GAB', 'BWA', 'LSO', 'GNB', 'SVN', 'GNQ', 'LVA', 'MKD', 'BHR', 'TTO', 'TLS', 'CYP', 'EST', 'MUS', 'SWZ', 'FJI', 'SLB', 'GUY', 'BTN', 'LUX', 'SUR', 'MNE', 'MLT', 'CPV', 'BHS', 'ISL', 'VUT', 'BRB', 'STP', 'WSM', 'LCA', 'KIR', 'SYC', 'GRD', 'FSM', 'TON', 'VCT', 'ATG', 'AND', 'DMA', 'KNA', 'LIE', 'MCO', 'MHL', 'SMR', 'PLW', 'COK', 'NRU', 'TUV', 'VAT'],
        themeColor: Colors.blue.shade600,
        mapLegend: 'Recognizes Israel',
      ),
      GroupInfo(
        title: 'Kosovo Recognition',
        icon: Icons.flag_circle_outlined,
        memberCodes: const ['USA', 'PAK', 'BGD', 'JPN', 'EGY', 'TUR', 'DEU', 'THA', 'TZA', 'GBR', 'FRA', 'ITA', 'COL', 'KOR', 'AFG', 'YEM', 'CAN', 'POL', 'MYS', 'PER', 'SAU', 'CIV', 'NER', 'AUS', 'BFA', 'TWN', 'MWI', 'TCD', 'SOM', 'SEN', 'NLD', 'GIN', 'BEN', 'HTI', 'BEL', 'JOR', 'DOM', 'ARE', 'HND', 'SWE', 'CZE', 'PRT', 'HUN', 'ISR', 'AUT', 'CHE', 'LBY', 'BGR', 'SLV', 'DNK', 'SGP', 'LBR', 'FIN', 'NOR', 'MRT', 'IRL', 'NZL', 'CRI', 'KWT', 'PAN', 'HRV', 'QAT', 'LTU', 'GMB', 'ALB', 'GAB', 'SVN', 'LVA', 'MKD', 'BHR', 'TLS', 'EST', 'SWZ', 'DJI', 'FJI', 'GUY', 'LUX', 'MNE', 'MLT', 'MDV', 'BRN', 'BLZ', 'ISL', 'VUT', 'BRB', 'WSM', 'LCA', 'KIR', 'FSM', 'AND', 'LIE', 'MCO', 'MHL', 'SMR', 'COK', 'TUV'],
        themeColor: Colors.indigoAccent.shade200,
        mapLegend: 'Recognizes Kosovo',
      ),
      GroupInfo(
        title: 'Taiwan Recognition',
        icon: Icons.flag_circle,
        memberCodes: const ['BLZ', 'GTM', 'HTI', 'VAT', 'MHL', 'PLW', 'PRY', 'KNA', 'LCA', 'VCT', 'SWZ', 'TUV'],
        themeColor: Colors.deepPurple.shade300,
        mapLegend: 'Recognizes Taiwan',
      ),
      GroupInfo(
        title: 'Palestine Recognition',
        icon: Icons.flag,
        memberCodes: const ['AFG', 'ALB', 'DZA', 'AGO', 'ATG', 'ARG', 'ARM', 'AZE', 'BHS', 'BHR', 'BGD', 'BRB', 'BLR', 'BLZ', 'BEN', 'BTN', 'BOL', 'BIH', 'BWA', 'BRA', 'BRN', 'BGR', 'BFA', 'BDI', 'KHM', 'CPV', 'CAF', 'TCD', 'CHL', 'CHN', 'COL', 'COM', 'COG', 'CRI', 'CIV', 'CUB', 'CYP', 'CZE', 'PRK', 'COD', 'DJI', 'DMA', 'DOM', 'ECU', 'EGY', 'SLV', 'GNQ', 'ERI', 'ETH', 'GAB', 'GMB', 'GEO', 'GHA', 'GRD', 'GTM', 'GIN', 'GNB', 'GUY', 'HTI', 'VAT', 'HND', 'HUN', 'ISL', 'IND', 'IDN', 'IRN', 'IRQ', 'IRL', 'JAM', 'JOR', 'KAZ', 'KEN', 'KWT', 'KGZ', 'LAO', 'LBN', 'LSO', 'LBR', 'LBY', 'MDG', 'MWI', 'MYS', 'MDV', 'MLI', 'MLT', 'MRT', 'MUS', 'MEX', 'MNG', 'MNE', 'MAR', 'MOZ', 'MMR', 'NAM', 'NPL', 'NIC', 'NER', 'NGA', 'NOR', 'OMN', 'PAK', 'PNG', 'PER', 'PHL', 'POL', 'QAT', 'ROU', 'RUS', 'RWA', 'KNA', 'LCA', 'VCT', 'WSM', 'SMR', 'STP', 'SAU', 'SEN', 'SRB', 'SYC', 'SLE', 'SGP', 'SVK', 'SVN', 'SOM', 'ZAF', 'SSD', 'ESP', 'LKA', 'SDN', 'SUR', 'SWE', 'SYR', 'TJK', 'TZA', 'THA', 'TLS', 'TGO', 'TTO', 'TUN', 'TUR', 'TKM', 'UGA', 'UKR', 'ARE', 'URY', 'UZB', 'VEN', 'VNM', 'YEM', 'ZMB', 'ZWE'],
        themeColor: Colors.brown.shade500,
        mapLegend: 'Recognizes Palestine',
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((country) =>
        _selectedGroup.memberCodes.contains(country.isoA3)
    ).toList();

    final total = currentCountries.length;
    final visited = currentCountries.where((country) =>
        widget.visitedCountryNames.contains(country.name)
    ).length;
    final percentage = total > 0 ? (visited / total) : 0.0;

    final sortedCountries = List<Country>.from(currentCountries)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<GroupInfo>(
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) {
                  return DropdownMenuItem<GroupInfo>(
                    value: group,
                    child: Row(
                      children: [
                        Icon(group.icon, color: group.themeColor),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (GroupInfo? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedGroup = newValue;
                      _isExpanded = false;
                    });
                  }
                },
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Visited", style: textTheme.bodyLarge),
                            Text.rich(
                                TextSpan(
                                    text: '$visited',
                                    style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                          text: ' / $total',
                                          style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)
                                      ),
                                    ]
                                )
                            )
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final Set<String> currentFilteredIsoA3s = widget.allCountries.map((c) => c.isoA3).toSet();
                            final List<String> membersInFilter = _selectedGroup.memberCodes
                                .where((code) => currentFilteredIsoA3s.contains(code))
                                .toList();
                            final groups = [
                              HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: membersInFilter),
                            ];
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedGroup.themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _selectedGroup.themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(_selectedGroup.themeColor),
                        ),
                      ),
                    ),
                  ],
                )
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: sortedCountries.length,
                    itemBuilder: (context, index) {
                      final country = sortedCountries[index];
                      final isVisited = widget.visitedCountryNames.contains(country.name);
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => navigateToCountryDetail(context, country),
                        child: Row(
                          children: [
                            Icon(
                              isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: isVisited ? _selectedGroup.themeColor : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                country.name,
                                style: textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ColdWarGeopoliticsSection: Single expansion logic
class _ColdWarGeopoliticsSection extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _ColdWarGeopoliticsSection({
    required this.countriesToDisplay,
    required this.visitedCountryNames,
  });

  @override
  State<_ColdWarGeopoliticsSection> createState() =>
      _ColdWarGeopoliticsSectionState();
}

class _ColdWarGeopoliticsSectionState
    extends State<_ColdWarGeopoliticsSection> {
  Map<String, String> _coldWarData = {};
  bool _isLoadingColdWarData = true;
  // Single expansion status
  String? _expandedStatus;

  final Map<String, Color> _coldWarColors = {
    '1st World': Colors.blue,
    '2nd World': Colors.red,
    '3rd World': Colors.green,
    'Divided Nation': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _loadColdWarData();
  }

  Future<void> _loadColdWarData() async {
    try {
      final String response =
      await rootBundle.loadString('assets/cold_war.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _coldWarData = {
          for (var item in data)
            item['iso_a3'] as String: _mapColdWarStatus(item['cold'] as String)
        };
      });
    } finally {
      setState(() {
        _isLoadingColdWarData = false;
      });
    }
  }

  String _mapColdWarStatus(String coldStatus) {
    switch (coldStatus) {
      case '1':
        return '1st World';
      case '2':
        return '2nd World';
      case '3':
        return '3rd World';
      case '4':
        return 'Divided Nation';
      default:
        return 'Unknown';
    }
  }

  // Toggle status expansion
  void _toggleStatusExpanded(String statusName) {
    setState(() {
      if (_expandedStatus == statusName) {
        _expandedStatus = null;
      } else {
        _expandedStatus = statusName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingColdWarData) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, List<Country>> groupedByColdWarStatus = {};
    for (var type in _coldWarColors.keys) {
      groupedByColdWarStatus[type] = [];
    }

    for (var country in widget.countriesToDisplay) {
      final coldWarStatus = _coldWarData[country.isoA3];
      if (coldWarStatus != null &&
          groupedByColdWarStatus.containsKey(coldWarStatus)) {
        groupedByColdWarStatus[coldWarStatus]!.add(country);
      }
    }

    final List<String> relevantStatuses = _coldWarColors.keys
        .where((status) => groupedByColdWarStatus[status]!.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.public, color: Colors.white, size: 20),
              label: const Text(
                'Cold War Geopolitics Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                final List<HighlightGroup> highlightGroups = [];
                final Set<String> allRelevantColdWarCountryCodes =
                relevantStatuses
                    .expand((statusName) => groupedByColdWarStatus[
                statusName]!
                    .map((c) => c.isoA3))
                    .toSet();

                for (var type in relevantStatuses) {
                  final countries = groupedByColdWarStatus[type];
                  if (countries != null && countries.isNotEmpty) {
                    highlightGroups.add(HighlightGroup(
                      name: type,
                      color: _coldWarColors[type] ?? Colors.grey,
                      countryCodes: countries.map((c) => c.isoA3).toList(),
                    ));
                  }
                }

                final Set<String> allFilteredCountryIsoA3s =
                widget.countriesToDisplay.map((c) => c.isoA3).toSet();
                final List<String> otherCountriesFaded = allFilteredCountryIsoA3s
                    .where((code) => !allRelevantColdWarCountryCodes.contains(code))
                    .toList();
                if (otherCountriesFaded.isNotEmpty) {
                  highlightGroups.add(HighlightGroup(
                    name: 'Other Countries',
                    color: Colors.grey.withOpacity(0.35),
                    countryCodes: otherCountriesFaded,
                  ));
                }

                final List<HighlightGroup> finalGroups = [
                  ...highlightGroups.where((g) => g.name == 'Other Countries'),
                  ...highlightGroups.where((g) => g.name == '1st World'),
                  ...highlightGroups.where((g) => g.name == '2nd World'),
                  ...highlightGroups.where((g) => g.name == '3rd World'),
                  ...highlightGroups.where((g) => g.name == 'Divided Nation'),
                ];

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            CountriesMapScreen(highlightGroups: finalGroups)));
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: relevantStatuses.map((title) {
              final countries = groupedByColdWarStatus[title] ?? [];
              final total = countries.length;
              final visited = countries
                  .where((c) => widget.visitedCountryNames.contains(c.name))
                  .length;
              final percentage = total > 0 ? (visited / total) : 0.0;
              final isExpanded = _expandedStatus == title;
              final theme = Theme.of(context);
              final statusColor = _coldWarColors[title] ?? theme.primaryColor;

              List<Country> sortedCountries = List.from(countries);
              sortedCountries.sort((a, b) => a.name.compareTo(b.name));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                child: _ColdWarStatusTile(
                  title: title,
                  countries: countries,
                  visitedNames: widget.visitedCountryNames,
                  percentage: percentage,
                  color: statusColor,
                  isExpanded: isExpanded,
                  onToggle: _toggleStatusExpanded,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// _ColdWarStatusTile Widget
class _ColdWarStatusTile extends StatelessWidget {
  final String title;
  final List<Country> countries;
  final Set<String> visitedNames;
  final double percentage;
  final Color color;
  final bool isExpanded;
  final Function(String) onToggle;

  const _ColdWarStatusTile({
    required this.title,
    required this.countries,
    required this.visitedNames,
    required this.percentage,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = countries.length;
    final visited = countries.where((c) => visitedNames.contains(c.name)).length;
    List<Country> sortedCountries = List.from(countries)..sort((a,b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(
        color: isExpanded ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpanded ? color.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? color.withOpacity(0.1) : Colors.black.withOpacity(0.05),
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
                      // Title
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
                      // Percentage
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Progress bar and count
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: color.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
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

          // Expandable country list
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
                        childAspectRatio: 4.5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: sortedCountries.length,
                      itemBuilder: (context, index) {
                        final country = sortedCountries[index];
                        final isVisited = visitedNames.contains(country.name);
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => navigateToCountryDetail(context, country),
                          child: Row(
                            children: [
                              Icon(
                                isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: isVisited ? color : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}