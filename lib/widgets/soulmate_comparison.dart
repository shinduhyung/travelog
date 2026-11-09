import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/social/data/geo_data.dart';
import 'package:country_flags/country_flags.dart';

class SoulmateComparison extends StatelessWidget {
  final Map<String, dynamic> match, mine;
  final Map<String, String> names;
  const SoulmateComparison({
    super.key,
    required this.match,
    required this.mine,
    required this.names,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr('Your travels, side by side'),
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: Color(0xFF173B3A),
        ),
      ),
      const SizedBox(height: 16),
      for (final spec in <(String, String, IconData, Color)>[
        ('Countries', 'countries', Icons.public_rounded, Color(0xFF008F83)),
        ('Cities', 'cities', Icons.location_city_rounded, Color(0xFF7C3AED)),
        (
          'Landmarks',
          'landmarks',
          Icons.attractions_rounded,
          Color(0xFFE76A24),
        ),
        ('UNESCO', 'unesco', Icons.account_balance_rounded, Color(0xFF2563EB)),
      ])
        if (match[spec.$2] is List)
          _domain(context, spec.$1, spec.$2, spec.$3, spec.$4)
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tr('City list is not shared by this member.')),
          ),
    ],
  );
  String _country(String domain, String value) {
    if (domain == 'countries') return value;
    if (!GeoData.isLoaded) return '';
    final g = GeoData.I;
    return switch (domain) {
      'cities' => g.countryOfCity(value)?.iso2 ?? '',
      'landmarks' => g.countryOfLandmark(value)?.iso2 ?? '',
      'unesco' => g.countryOfUnesco(value)?.iso2 ?? '',
      _ => '',
    };
  }

  Widget _domain(
    BuildContext context,
    String title,
    String domain,
    IconData icon,
    Color color,
  ) {
    final yours = (mine[domain] as List? ?? []).cast<String>().toSet();
    final theirs = (match[domain] as List).cast<String>().toSet();
    final sets = [
      yours.intersection(theirs),
      yours.difference(theirs),
      theirs.difference(yours),
    ];
    var selected = 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: .16)),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: color),
          title: Text(
            tr(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Text(
                '${tr('You')} ${yours.length}  /  ${tr('Them')} ${theirs.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: yours.union(theirs).isEmpty
                      ? 0
                      : sets[0].length / yours.union(theirs).length,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .10),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${sets[0].length} ${tr('in common')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            StatefulBuilder(
              builder: (context, update) {
                final groups = <String, List<String>>{};
                for (final value in sets[selected]) {
                  groups
                      .putIfAbsent(_country(domain, value), () => [])
                      .add(value);
                }
                final codes = groups.keys.toList()
                  ..sort((a, b) => (names[a] ?? a).compareTo(names[b] ?? b));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        for (var i = 0; i < 3; i++)
                          ChoiceChip(
                            label: Text(
                              '${tr(['Together', 'Only you', 'Only them'][i])} ${sets[i].length}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: selected == i,
                            onSelected: (_) => update(() => selected = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (groups.isEmpty)
                      Text(
                        tr('No recorded visits'),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    for (final code in codes) ...[
                      Row(
                        children: [
                          if (code.length == 2) ...[
                            SizedBox(
                              width: 24,
                              height: 17,
                              child: CountryFlag.fromCountryCode(code),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              code.isEmpty
                                  ? tr('Other places')
                                  : names[code] ?? code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${groups[code]!.length}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 7,
                        children: [
                          for (final value in (groups[code]!..sort()))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                domain == 'countries'
                                    ? names[value] ?? value
                                    : value,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
