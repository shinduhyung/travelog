import 'package:jidoapp/social/data/geo_data.dart';
import 'package:jidoapp/widgets/soulmate_comparison.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class CountryTwinResult extends StatelessWidget {
  final Map<String, dynamic> match;
  final Map<String, String> names;
  final List<String> mine;
  final Map<String, dynamic> mineRecords;
  final VoidCallback? onAddFriend;
  final String friendState;
  final bool sending;
  const CountryTwinResult({
    super.key,
    required this.match,
    required this.names,
    required this.mine,
    this.mineRecords = const {},
    this.onAddFriend,
    this.friendState = 'none',
    this.sending = false,
  });

  String? get _nationality {
    final raw = match['nationality'] as String?;
    if (raw == null || !GeoData.isLoaded) return null;
    return GeoData.I.countryByIso3(raw.toUpperCase())?.iso2 ??
        GeoData.I.countryByIso2(raw.toUpperCase())?.iso2;
  }

  static const teal = Color(0xFF008F83);
  Widget _flag(String code, {double width = 28}) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox(
      width: width,
      height: width * .7,
      child: CountryFlag.fromCountryCode(code),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final countries = (match['countries'] as List).cast<String>();
    final cities = (match['cities'] as List?)?.cast<String>();
    final landmarks = (match['landmarks'] as List).cast<String>();
    final unesco = (match['unesco'] as List).cast<String>();
    final shared = countries.where(mine.contains).toList();
    final stats = <(String, int?, IconData, Color)>[
      ('Countries', countries.length, Icons.public_rounded, teal),
      (
        'Cities',
        cities?.length,
        Icons.location_city_rounded,
        const Color(0xFF7C3AED),
      ),
      (
        'Landmarks',
        landmarks.length,
        Icons.attractions_rounded,
        const Color(0xFFE76A24),
      ),
      (
        'UNESCO',
        unesco.length,
        Icons.account_balance_rounded,
        const Color(0xFF2563EB),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF064E4A), Color(0xFF009D90)],
            ),
            boxShadow: [
              BoxShadow(
                color: teal.withValues(alpha: .18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -38,
                top: -35,
                child: Icon(
                  Icons.public_rounded,
                  size: 220,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.public_rounded,
                          color: Color(0xFF99F6E4),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tr('YOUR TRAVEL SOULMATE'),
                            style: const TextStyle(
                              color: Color(0xFF99F6E4),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_nationality case final String code)
                          _flag(code, width: 40)
                        else
                          const Icon(
                            Icons.public_rounded,
                            color: Colors.white70,
                            size: 30,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              match['travelerType'] as String? ??
                                  'Traveler type not set',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${((match['similarity'] as num) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 60,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 86,
                          height: 66,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                child: _avatar(
                                  Icons.person_rounded,
                                  const Color(0xFF99F6E4),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: _avatar(
                                  Icons.person_outline_rounded,
                                  const Color(0xFFC4B5FD),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('Your closest travel match.'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${match['shared']} ${tr('shared countries')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (shared.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final code in shared.take(7)) _flag(code),
                                if (shared.length > 7)
                                  Text(
                                    '+${shared.length - 7}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onAddFriend != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: sending || friendState != 'none' ? null : onAddFriend,
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: Icon(
              friendState == 'none'
                  ? Icons.person_add_alt_1
                  : Icons.check_rounded,
            ),
            label: Text(
              tr(
                sending
                    ? 'Sending...'
                    : friendState == 'friends'
                    ? 'Already friends'
                    : friendState == 'sent'
                    ? 'Request sent'
                    : 'Send friend request',
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Text(
          tr('Their travel passport'),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Color(0xFF173B3A),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: stat.$4.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: stat.$4.withValues(alpha: .12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(stat.$3, color: stat.$4, size: 25),
                        const SizedBox(height: 12),
                        Text(
                          stat.$2?.toString() ?? '—',
                          style: TextStyle(
                            color: stat.$4,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(stat.$1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: const LinearGradient(
              colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFDE68A),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match['badgeScore'] ?? '—'} ${tr('Badge points')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    Text(
                      '${match['badgeCount'] ?? '—'} ${tr('Badges')}',
                      style: const TextStyle(
                        color: Color(0xFFDDD6FE),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SoulmateComparison(
          match: match,
          mine: {'countries': mine, ...mineRecords},
          names: names,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _avatar(IconData icon, Color color) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF08746B), width: 3),
    ),
    child: Icon(icon, size: 31, color: const Color(0xFF134E4A)),
  );
}
