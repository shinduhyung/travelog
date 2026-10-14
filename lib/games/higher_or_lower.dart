// lib/games/higher_or_lower.dart
//
// Self-contained "Higher or Lower" mini-game: two countries shown, pick
// which one is bigger by the chosen metric (population, or international
// tourist arrivals). Data comes from the data pipeline (see
// data_pipeline/05_higher_or_lower/) -- raw per-country World Bank stats,
// NO pre-baked comparison pairs. Every round is built fresh at RUNTIME via
// rejection sampling: pick two countries, compute ratio = bigger/smaller,
// keep it only if that ratio lands in the requested difficulty band --
// same pattern as border_chain.dart's _RoundPuzzle.generate() and
// timezone_impostor.dart's _TzRound.generate().
//
// Difficulty bands (ratio = larger value / smaller value):
//   Easy:   >= 2.5x
//   Medium: 1.5x - 2.5x
//   Hard:   1.2x - 1.5x
//   Insane: 1.0x - 1.2x
//
// After answering, both real values are revealed WITH the year each one is
// from -- World Bank doesn't have every country's most recent year on
// file, so the two compared countries can (rarely) be a year or two apart.
// That's shown honestly rather than papered over.
//
// The ONLY public symbol is [HigherOrLowerModeScreen]; everything else is
// private to this library on purpose.
//
// SETUP REQUIRED: bundle the pipeline's output as an asset:
//   assets/data/higher_or_lower_countries.json
// and register it in pubspec.yaml:
//   flutter:
//     assets:
//       - assets/data/higher_or_lower_countries.json

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';
import 'package:jidoapp/services/game_insane_trial_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// ============================================================================
// DATA
// ============================================================================

class _Stat {
  final double value;
  final int? year; // null for stats that don't come with a specific year (GDP/area below)

  const _Stat({required this.value, this.year});

  factory _Stat.fromJson(Map<String, dynamic> json) => _Stat(
    value: (json['value'] as num).toDouble(),
    year: json['year'] as int,
  );
}

class _CountryStats {
  final String name;
  final String cc;
  final _Stat? population;
  final _Stat? tourismArrivals;
  final _Stat? gdpPerCapita;
  final _Stat? area;

  const _CountryStats({
    required this.name,
    required this.cc,
    required this.population,
    required this.tourismArrivals,
    this.gdpPerCapita,
    this.area,
  });

  _CountryStats copyWith({_Stat? gdpPerCapita, _Stat? area}) => _CountryStats(
    name: name,
    cc: cc,
    population: population,
    tourismArrivals: tourismArrivals,
    gdpPerCapita: gdpPerCapita ?? this.gdpPerCapita,
    area: area ?? this.area,
  );

  String get flagEmoji {
    final c = cc.toUpperCase();
    if (c.length != 2) return '🏳️';
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory _CountryStats.fromJson(Map<String, dynamic> json) => _CountryStats(
    name: json['name'] as String,
    cc: json['cc'] as String,
    population: json['population'] != null ? _Stat.fromJson(json['population'] as Map<String, dynamic>) : null,
    tourismArrivals: json['tourism_arrivals'] != null
        ? _Stat.fromJson(json['tourism_arrivals'] as Map<String, dynamic>)
        : null,
  );
}

/// GDP per capita + land area -- reused directly from the same dataset
/// Respawn already carries (see respawn.dart's _kCountries), rather than
/// going back to the data pipeline for two more World Bank indicators.
/// No per-country "year" here (that dataset is a single approximate
/// recent-year snapshot, not fetched-per-country like the World Bank JSON
/// below), which is why _Stat.year is nullable.
class _GdpArea {
  final String name;
  final String code;
  final int gdpPerCapitaUsd;
  final int areaKm2;

  const _GdpArea(this.name, this.code, this.gdpPerCapitaUsd, this.areaKm2);
}

const List<_GdpArea> _kGdpAreaData = [
  _GdpArea('China', 'CN', 12600, 9600000),
  _GdpArea('India', 'IN', 2600, 3287000),
  _GdpArea('Indonesia', 'ID', 4900, 1905000),
  _GdpArea('Pakistan', 'PK', 1500, 881000),
  _GdpArea('Bangladesh', 'BD', 2500, 148000),
  _GdpArea('Japan', 'JP', 34000, 378000),
  _GdpArea('Philippines', 'PH', 3800, 300000),
  _GdpArea('Vietnam', 'VN', 4300, 331000),
  _GdpArea('Iran', 'IR', 4500, 1648000),
  _GdpArea('Turkey', 'TR', 10600, 783000),
  _GdpArea('Thailand', 'TH', 7200, 513000),
  _GdpArea('Myanmar', 'MM', 1200, 676000),
  _GdpArea('South Korea', 'KR', 33000, 100000),
  _GdpArea('Iraq', 'IQ', 5900, 435000),
  _GdpArea('Afghanistan', 'AF', 500, 653000),
  _GdpArea('Saudi Arabia', 'SA', 28000, 2150000),
  _GdpArea('Uzbekistan', 'UZ', 2300, 448000),
  _GdpArea('Malaysia', 'MY', 11600, 330000),
  _GdpArea('Yemen', 'YE', 650, 528000),
  _GdpArea('Nepal', 'NP', 1300, 147000),
  _GdpArea('North Korea', 'KP', 1700, 121000),
  _GdpArea('Sri Lanka', 'LK', 3800, 66000),
  _GdpArea('Kazakhstan', 'KZ', 11500, 2725000),
  _GdpArea('Cambodia', 'KH', 1800, 181000),
  _GdpArea('Jordan', 'JO', 4500, 89000),
  _GdpArea('Azerbaijan', 'AZ', 7000, 87000),
  _GdpArea('UAE', 'AE', 49000, 83600),
  _GdpArea('Tajikistan', 'TJ', 1100, 141000),
  _GdpArea('Israel', 'IL', 54000, 22000),
  _GdpArea('Laos', 'LA', 2000, 237000),
  _GdpArea('Lebanon', 'LB', 4100, 10400),
  _GdpArea('Kyrgyzstan', 'KG', 1400, 200000),
  _GdpArea('Turkmenistan', 'TM', 9000, 488000),
  _GdpArea('Singapore', 'SG', 84700, 728),
  _GdpArea('Oman', 'OM', 21000, 309500),
  _GdpArea('Kuwait', 'KW', 33000, 17800),
  _GdpArea('Georgia', 'GE', 7000, 69700),
  _GdpArea('Mongolia', 'MN', 5500, 1564000),
  _GdpArea('Armenia', 'AM', 7000, 29700),
  _GdpArea('Qatar', 'QA', 87000, 11600),
  _GdpArea('Bahrain', 'BH', 29000, 780),
  _GdpArea('Timor-Leste', 'TL', 1700, 14900),
  _GdpArea('Bhutan', 'BT', 3600, 38400),
  _GdpArea('Brunei', 'BN', 32000, 5800),
  _GdpArea('Maldives', 'MV', 12000, 300),
  _GdpArea('Egypt', 'EG', 3800, 1010000),
  _GdpArea('Syria', 'SY', 800, 185000),
  _GdpArea('Nigeria', 'NG', 2100, 924000),
  _GdpArea('Ethiopia', 'ET', 1000, 1104000),
  _GdpArea('DR Congo', 'CD', 650, 2345000),
  _GdpArea('Tanzania', 'TZ', 1200, 947000),
  _GdpArea('South Africa', 'ZA', 6700, 1221000),
  _GdpArea('Kenya', 'KE', 2100, 580000),
  _GdpArea('Uganda', 'UG', 1000, 241000),
  _GdpArea('Algeria', 'DZ', 4200, 2382000),
  _GdpArea('Sudan', 'SD', 600, 1886000),
  _GdpArea('Morocco', 'MA', 3800, 447000),
  _GdpArea('Angola', 'AO', 2900, 1247000),
  _GdpArea('Mozambique', 'MZ', 500, 801000),
  _GdpArea('Ghana', 'GH', 2400, 239000),
  _GdpArea('Madagascar', 'MG', 500, 587000),
  _GdpArea('Cameroon', 'CM', 1700, 475000),
  _GdpArea('Ivory Coast', 'CI', 2600, 322000),
  _GdpArea('Niger', 'NE', 600, 1267000),
  _GdpArea('Burkina Faso', 'BF', 850, 274000),
  _GdpArea('Mali', 'ML', 900, 1240000),
  _GdpArea('Malawi', 'MW', 650, 118000),
  _GdpArea('Zambia', 'ZM', 1500, 752000),
  _GdpArea('Senegal', 'SN', 1700, 197000),
  _GdpArea('Chad', 'TD', 700, 1284000),
  _GdpArea('Somalia', 'SO', 500, 638000),
  _GdpArea('Zimbabwe', 'ZW', 1700, 391000),
  _GdpArea('Guinea', 'GN', 1200, 246000),
  _GdpArea('Rwanda', 'RW', 1000, 26300),
  _GdpArea('Benin', 'BJ', 1400, 115000),
  _GdpArea('Burundi', 'BI', 250, 27800),
  _GdpArea('Tunisia', 'TN', 3900, 163600),
  _GdpArea('South Sudan', 'SS', 1100, 644000),
  _GdpArea('Togo', 'TG', 950, 56800),
  _GdpArea('Sierra Leone', 'SL', 500, 71700),
  _GdpArea('Libya', 'LY', 7000, 1760000),
  _GdpArea('Congo', 'CG', 2400, 342000),
  _GdpArea('Liberia', 'LR', 700, 111000),
  _GdpArea('Central African Republic', 'CF', 500, 623000),
  _GdpArea('Mauritania', 'MR', 2100, 1031000),
  _GdpArea('Eritrea', 'ER', 600, 117600),
  _GdpArea('Namibia', 'NA', 4900, 824000),
  _GdpArea('Gambia', 'GM', 800, 11300),
  _GdpArea('Botswana', 'BW', 7300, 582000),
  _GdpArea('Gabon', 'GA', 8600, 267700),
  _GdpArea('Lesotho', 'LS', 1150, 30400),
  _GdpArea('Guinea-Bissau', 'GW', 800, 36100),
  _GdpArea('Equatorial Guinea', 'GQ', 7000, 28000),
  _GdpArea('Mauritius', 'MU', 11000, 2040),
  _GdpArea('Eswatini', 'SZ', 4400, 17400),
  _GdpArea('Djibouti', 'DJ', 3600, 23200),
  _GdpArea('Comoros', 'KM', 1600, 2235),
  _GdpArea('Cape Verde', 'CV', 4200, 4033),
  _GdpArea('Sao Tome and Principe', 'ST', 2500, 964),
  _GdpArea('Seychelles', 'SC', 16000, 460),
  _GdpArea('Russia', 'RU', 14000, 17098000),
  _GdpArea('Germany', 'DE', 52000, 357600),
  _GdpArea('United Kingdom', 'GB', 46000, 243600),
  _GdpArea('France', 'FR', 44000, 551700),
  _GdpArea('Italy', 'IT', 38000, 301300),
  _GdpArea('Spain', 'ES', 32000, 505900),
  _GdpArea('Poland', 'PL', 22000, 312700),
  _GdpArea('Ukraine', 'UA', 5000, 603500),
  _GdpArea('Romania', 'RO', 17000, 238400),
  _GdpArea('Netherlands', 'NL', 58000, 41500),
  _GdpArea('Belgium', 'BE', 52000, 30500),
  _GdpArea('Czech Republic', 'CZ', 28000, 78900),
  _GdpArea('Greece', 'GR', 22000, 132000),
  _GdpArea('Portugal', 'PT', 26000, 92200),
  _GdpArea('Sweden', 'SE', 57000, 450300),
  _GdpArea('Hungary', 'HU', 19000, 93000),
  _GdpArea('Belarus', 'BY', 7500, 207600),
  _GdpArea('Austria', 'AT', 53000, 83900),
  _GdpArea('Switzerland', 'CH', 93000, 41300),
  _GdpArea('Serbia', 'RS', 10000, 88400),
  _GdpArea('Bulgaria', 'BG', 14000, 111000),
  _GdpArea('Denmark', 'DK', 68000, 43000),
  _GdpArea('Finland', 'FI', 52000, 338400),
  _GdpArea('Slovakia', 'SK', 21000, 49000),
  _GdpArea('Norway', 'NO', 90000, 385000),
  _GdpArea('Ireland', 'IE', 102000, 70300),
  _GdpArea('Croatia', 'HR', 18000, 56600),
  _GdpArea('Bosnia and Herzegovina', 'BA', 7500, 51200),
  _GdpArea('Albania', 'AL', 6500, 28700),
  _GdpArea('Lithuania', 'LT', 26000, 65300),
  _GdpArea('Moldova', 'MD', 5700, 33800),
  _GdpArea('Slovenia', 'SI', 31000, 20300),
  _GdpArea('Latvia', 'LV', 22000, 64600),
  _GdpArea('North Macedonia', 'MK', 7000, 25700),
  _GdpArea('Estonia', 'EE', 29000, 45200),
  _GdpArea('Cyprus', 'CY', 32000, 9250),
  _GdpArea('Montenegro', 'ME', 10500, 13800),
  _GdpArea('Luxembourg', 'LU', 130000, 2590),
  _GdpArea('Malta', 'MT', 34000, 316),
  _GdpArea('Iceland', 'IS', 76000, 103000),
  _GdpArea('United States', 'US', 82000, 9834000),
  _GdpArea('Brazil', 'BR', 10000, 8516000),
  _GdpArea('Mexico', 'MX', 11500, 1964000),
  _GdpArea('Colombia', 'CO', 6600, 1142000),
  _GdpArea('Argentina', 'AR', 13600, 2780000),
  _GdpArea('Peru', 'PE', 7100, 1285000),
  _GdpArea('Venezuela', 'VE', 4600, 916000),
  _GdpArea('Chile', 'CL', 16500, 756000),
  _GdpArea('Ecuador', 'EC', 6300, 257000),
  _GdpArea('Guatemala', 'GT', 5600, 108900),
  _GdpArea('Canada', 'CA', 53000, 9985000),
  _GdpArea('Bolivia', 'BO', 3600, 1099000),
  _GdpArea('Haiti', 'HT', 1700, 27750),
  _GdpArea('Cuba', 'CU', 9500, 109900),
  _GdpArea('Dominican Republic', 'DO', 10400, 48700),
  _GdpArea('Honduras', 'HN', 3000, 112500),
  _GdpArea('Paraguay', 'PY', 6300, 397300),
  _GdpArea('Nicaragua', 'NI', 2400, 130000),
  _GdpArea('El Salvador', 'SV', 4900, 21000),
  _GdpArea('Costa Rica', 'CR', 13300, 51100),
  _GdpArea('Panama', 'PA', 17400, 75400),
  _GdpArea('Uruguay', 'UY', 21600, 176000),
  _GdpArea('Jamaica', 'JM', 5800, 10990),
  _GdpArea('Trinidad and Tobago', 'TT', 18000, 5130),
  _GdpArea('Guyana', 'GY', 50000, 214970),
  _GdpArea('Suriname', 'SR', 6300, 163800),
  _GdpArea('Belize', 'BZ', 6700, 22970),
  _GdpArea('Bahamas', 'BS', 35000, 13880),
  _GdpArea('Barbados', 'BB', 19000, 430),
  _GdpArea('Australia', 'AU', 65000, 7692000),
  _GdpArea('Papua New Guinea', 'PG', 3000, 462840),
  _GdpArea('New Zealand', 'NZ', 48000, 268000),
  _GdpArea('Fiji', 'FJ', 5500, 18270),
];

class _CountryBank {
  static Future<List<_CountryStats>>? _cache;

  static Future<List<_CountryStats>> load() {
    return _cache ??= _loadFromAsset();
  }

  static Future<List<_CountryStats>> _loadFromAsset() async {
    final raw = await rootBundle.loadString('assets/data/higher_or_lower_countries.json');
    final decoded = json.decode(raw) as List;
    final fromJson = decoded.map((e) => _CountryStats.fromJson(e as Map<String, dynamic>)).toList();

    // Merge in GDP/area by country code.
    final byCode = {for (final c in fromJson) c.cc.toUpperCase(): c};
    for (final g in _kGdpAreaData) {
      final code = g.code.toUpperCase();
      final gdpStat = _Stat(value: g.gdpPerCapitaUsd.toDouble());
      final areaStat = _Stat(value: g.areaKm2.toDouble());
      final existing = byCode[code];
      if (existing != null) {
        byCode[code] = existing.copyWith(gdpPerCapita: gdpStat, area: areaStat);
      } else {
        // A country Respawn's dataset has that the World Bank JSON didn't
        // (or didn't have population/tourism data for) -- still worth
        // including so GDP/Area modes have their own full pool.
        byCode[code] = _CountryStats(
          name: g.name,
          cc: code,
          population: null,
          tourismArrivals: null,
          gdpPerCapita: gdpStat,
          area: areaStat,
        );
      }
    }
    return byCode.values.toList();
  }
}

// ============================================================================
// METRIC + DIFFICULTY
// ============================================================================

enum _Metric { population, tourismArrivals, gdpPerCapita, area }

String _metricLabel(_Metric m) {
  switch (m) {
    case _Metric.population:
      return 'Population';
    case _Metric.tourismArrivals:
      return 'Tourist Arrivals';
    case _Metric.gdpPerCapita:
      return 'GDP per Capita';
    case _Metric.area:
      return 'Land Area';
  }
}

IconData _metricIcon(_Metric m) {
  switch (m) {
    case _Metric.population:
      return Icons.groups_rounded;
    case _Metric.tourismArrivals:
      return Icons.luggage_rounded;
    case _Metric.gdpPerCapita:
      return Icons.attach_money_rounded;
    case _Metric.area:
      return Icons.public_rounded;
  }
}

_Stat? _statFor(_CountryStats c, _Metric m) {
  switch (m) {
    case _Metric.population:
      return c.population;
    case _Metric.tourismArrivals:
      return c.tourismArrivals;
    case _Metric.gdpPerCapita:
      return c.gdpPerCapita;
    case _Metric.area:
      return c.area;
  }
}

enum _Difficulty { easy, medium, hard, insane }

(double, double) _bandRange(_Difficulty d) {
  switch (d) {
    case _Difficulty.easy:
      return (2.5, double.infinity);
    case _Difficulty.medium:
      return (1.5, 2.5);
    case _Difficulty.hard:
      return (1.2, 1.5);
    case _Difficulty.insane:
      return (1.0, 1.2);
  }
}

Color _diffColor(_Difficulty d) {
  switch (d) {
    case _Difficulty.easy:
      return const Color(0xFF2FBE73);
    case _Difficulty.medium:
      return const Color(0xFFFF9F1C);
    case _Difficulty.hard:
      return const Color(0xFFFF5A5F);
    case _Difficulty.insane:
      return const Color(0xFF8B5CF6);
  }
}

String _diffLabel(_Difficulty d) {
  switch (d) {
    case _Difficulty.easy:
      return 'Easy';
    case _Difficulty.medium:
      return 'Medium';
    case _Difficulty.hard:
      return 'Hard';
    case _Difficulty.insane:
      return 'Insane';
  }
}

// ============================================================================
// ROUND GENERATION (runtime, rejection-sampled — no pre-baked pairs)
// ============================================================================

class _HolRound {
  final _CountryStats a;
  final _CountryStats b;
  final _Stat statA;
  final _Stat statB;
  final bool aIsBigger;

  const _HolRound({
    required this.a,
    required this.b,
    required this.statA,
    required this.statB,
    required this.aIsBigger,
  });

  static _HolRound? generate(List<_CountryStats> pool, _Metric metric, _Difficulty difficulty, Random rng) {
    final candidates = pool.where((c) => _statFor(c, metric) != null).toList();
    if (candidates.length < 2) return null;

    final (minRatio, maxRatio) = _bandRange(difficulty);

    // Exhaustively scan every pair (O(n^2), ~200 countries -> ~20k pairs, negligible
    // cost once per round) and reservoir-sample a uniformly random valid pair as we
    // go. This guarantees we find a match whenever one exists in the band, instead
    // of the old fixed-80-random-tries approach, which had a real (few-percent)
    // chance of missing a valid pair purely by bad luck on narrow bands like
    // Hard/Insane -- and over a run of many rounds that chance compounds until the
    // game gives up with a "not enough data" error even though valid pairs exist.
    _HolRound? picked;
    var seen = 0;
    for (var i = 0; i < candidates.length; i++) {
      final ca = candidates[i];
      final sa = _statFor(ca, metric)!;
      if (sa.value <= 0) continue;
      for (var j = i + 1; j < candidates.length; j++) {
        final cb = candidates[j];
        final sb = _statFor(cb, metric)!;
        if (sb.value <= 0) continue;

        final hi = max(sa.value, sb.value);
        final lo = min(sa.value, sb.value);
        final ratio = hi / lo;
        if (ratio < minRatio || ratio >= maxRatio) continue;

        seen++;
        if (rng.nextInt(seen) == 0) {
          picked = _HolRound(a: ca, b: cb, statA: sa, statB: sb, aIsBigger: sa.value >= sb.value);
        }
      }
    }
    return picked;
  }
}

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _ScoreRecord {
  final int score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const _ScoreRecord({
    required this.score,
    required this.roundsCompleted,
    required this.maxRounds,
    required this.bestCombo,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'roundsCompleted': roundsCompleted,
    'maxRounds': maxRounds,
    'bestCombo': bestCombo,
    'playedAt': playedAt.toIso8601String(),
  };

  factory _ScoreRecord.fromJson(Map<String, dynamic> json) => _ScoreRecord(
    score: json['score'] as int,
    roundsCompleted: json['roundsCompleted'] as int,
    maxRounds: json['maxRounds'] as int,
    bestCombo: json['bestCombo'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _ScoreService {
  static const int maxStoredRecords = 20;

  Future<List<_ScoreRecord>> loadRecords(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded.map((e) => _ScoreRecord.fromJson(e as Map<String, dynamic>)).toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(String key, _ScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(key);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(key, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }
}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);

class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.4) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _GradientButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final fg = widget.outlined ? widget.color : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: widget.outlined
                ? null
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.18)!],
            ),
            color: widget.outlined ? Colors.white : null,
            border: widget.outlined ? Border.all(color: widget.color.withOpacity(0.35), width: 1.4) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.outlined
                ? null
                : [
              BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ScreenBackground({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withOpacity(0.14), _kSurface],
          stops: const [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}

String _formatValue(double value, _Metric metric) {
  switch (metric) {
    case _Metric.population:
      if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
      if (value >= 1e3) return '${(value / 1e3).round()}K';
      return value.round().toString();
    case _Metric.tourismArrivals:
      if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M visitors';
      if (value >= 1e3) return '${(value / 1e3).round()}K visitors';
      return '${value.round()} visitors';
    case _Metric.gdpPerCapita:
      final v = value.round();
      return '\$${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
    case _Metric.area:
      final km2 = value.round();
      if (km2 >= 1000000) return '${(km2 / 1000000).toStringAsFixed(km2 >= 10000000 ? 1 : 2)}M km²';
      if (km2 >= 1000) return '${(km2 / 1000).toStringAsFixed(km2 >= 100000 ? 0 : 1)}K km²';
      return '$km2 km²';
  }
}

// ============================================================================
// MODE SELECT SCREEN (entry point — the only public symbol in this file)
// ============================================================================

class HigherOrLowerModeScreen extends StatelessWidget {
  const HigherOrLowerModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: const Color(0xFF2563EB),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('CHOOSE A METRIC',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 16),
              for (final m in _Metric.values) ...[
                _MetricCard(
                  metric: m,
                  subtitle: switch (m) {
                    _Metric.population => 'Which country has more people?',
                    _Metric.tourismArrivals => 'Which country gets more international visitors?',
                    _Metric.gdpPerCapita => 'Which country is richer, per person?',
                    _Metric.area => 'Which country covers more land?',
                  },
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _DifficultyScreen(metric: m)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COMPARISON GAME',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
              const Text('Higher or Lower',
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text('Pick which country has more, by the numbers. Choose a metric to start.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  final String subtitle;
  final VoidCallback onTap;

  const _MetricCard({required this.metric, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2563EB);
    return GestureDetector(
      onTap: onTap,
      child: _SoftCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.85), color]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(_metricIcon(metric), color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_metricLabel(metric), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _kInk)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _kMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: _kFaint),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIFFICULTY SCREEN
// ============================================================================

int _diffLevel(_Difficulty d) {
  switch (d) {
    case _Difficulty.easy:
      return 1;
    case _Difficulty.medium:
      return 2;
    case _Difficulty.hard:
      return 3;
    case _Difficulty.insane:
      return 4;
  }
}

class _DifficultyScreen extends StatelessWidget {
  final _Metric metric;

  const _DifficultyScreen({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: _diffColor(_Difficulty.hard),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('CHOOSE A DIFFICULTY',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: _Difficulty.easy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(metric: metric, difficulty: _Difficulty.easy)),
                ),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _Difficulty.medium,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(metric: metric, difficulty: _Difficulty.medium)),
                ),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _Difficulty.hard,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(metric: metric, difficulty: _Difficulty.hard)),
                ),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final isPremium = sub.isPremium;
                  if (isPremium) {
                    return _DifficultyCard(
                      difficulty: _Difficulty.insane,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _LobbyScreen(metric: metric, difficulty: _Difficulty.insane)),
                      ),
                    );
                  }
                  return FutureBuilder<bool>(
                    future: GameInsaneTrialService.instance.hasUsedTrial('higher_or_lower'),
                    builder: (context, snapshot) {
                      final trialUsed = snapshot.data ?? false;
                      return _DifficultyCard(
                        difficulty: _Difficulty.insane,
                        locked: trialUsed,
                        onTap: () async {
                          if (trialUsed) {
                            SubscriptionSheet.show(context, triggerContext: 'higher_or_lower_insane');
                          } else {
                            await GameInsaneTrialService.instance.markTrialUsed('higher_or_lower');
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => _LobbyScreen(metric: metric, difficulty: _Difficulty.insane)),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Icon(_metricIcon(metric), color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HIGHER OR LOWER',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
              Text(_metricLabel(metric),
                  style: const TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text('Two countries, one metric. Pick the bigger one before time runs out.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _Difficulty difficulty;
  final bool locked;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _diffColor(difficulty);
    final level = _diffLevel(difficulty);
    return GestureDetector(
      onTap: onTap,
      child: _SoftCard(
        borderColor: locked ? color.withOpacity(0.3) : null,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.85), color]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_diffLabel(difficulty),
                          style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.2)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 15, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: List.generate(4, (i) {
                      final filled = i < level;
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Container(
                          width: 20,
                          height: 6,
                          decoration: BoxDecoration(
                            color: filled ? color : color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOBBY SCREEN
// ============================================================================

class _LobbyScreen extends StatefulWidget {
  final _Metric metric;
  final _Difficulty difficulty;

  const _LobbyScreen({required this.metric, required this.difficulty});

  @override
  State<_LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<_LobbyScreen> {
  final _service = _ScoreService();
  late Future<List<_ScoreRecord>> _recordsFuture;

  String get _storageKey => 'higher_or_lower_scores_${widget.metric.name}_${widget.difficulty.name}';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(_storageKey);
    });
  }

  Future<void> _startGame() async {
    await GameAdService.instance.requestStartGame();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GameScreen(metric: widget.metric, difficulty: widget.difficulty)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final color = _diffColor(widget.difficulty);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _buildLobbyHeader(color),
                const SizedBox(height: 22),
                Expanded(child: _buildHistory(color)),
                const SizedBox(height: 18),
                _GradientButton(label: 'Start Game', icon: Icons.play_arrow_rounded, color: color, onPressed: _startGame),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyHeader(Color color) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.85), color],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: color.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Icon(_metricIcon(widget.metric), color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_diffLabel(widget.difficulty).toUpperCase()} · ${_metricLabel(widget.metric).toUpperCase()}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kMuted)),
              const SizedBox(height: 2),
              Text('${_diffLabel(widget.difficulty)} Mode',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(Color color) {
    return FutureBuilder<List<_ScoreRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, size: 46, color: _kFaint),
                const SizedBox(height: 12),
                const Text('No runs yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LEADERBOARD',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RecordTile(rank: i + 1, record: records[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  final int rank;
  final _ScoreRecord record;

  const _RecordTile({required this.rank, required this.record});

  static const _medalColors = {1: Color(0xFFFFC93C), 2: Color(0xFFB8C1CC), 3: Color(0xFFD08A5B)};

  @override
  Widget build(BuildContext context) {
    final medal = _medalColors[rank];
    return _SoftCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: medal?.withOpacity(0.5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: (medal ?? _kFaint).withOpacity(medal != null ? 0.18 : 0.12), shape: BoxShape.circle),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record.score}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
                Text('${record.roundsCompleted}/${record.maxRounds} rounds · combo ${record.bestCombo}',
                    style: const TextStyle(fontSize: 11.5, color: _kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GAME SCREEN
// ============================================================================

enum _RoundPhase { loading, error, playing, revealed, complete }

class _GameScreen extends StatefulWidget {
  final _Metric metric;
  final _Difficulty difficulty;

  const _GameScreen({required this.metric, required this.difficulty});

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  static const int _maxRounds = 20;
  static const double _maxScorePerRound = 10.0;
  static const double _timeLimit = 10.0;

  final _rng = Random();
  List<_CountryStats> _pool = [];
  int _roundIndex = 0;
  int _totalScore = 0;
  int _bestRoundScore = 0;
  int _combo = 0;
  bool _recorded = false;

  _RoundPhase _phase = _RoundPhase.loading;
  String? _loadError;
  double _remaining = _timeLimit;
  DateTime? _roundStart;

  _HolRound? _round;
  String? _selectedSide; // 'a' | 'b'
  int? _lastRoundScore;

  Color get _accent => _diffColor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _phase = _RoundPhase.loading;
      _loadError = null;
    });
    try {
      final all = await _CountryBank.load();
      if (!mounted) return;
      final withMetric = all.where((c) => _statFor(c, widget.metric) != null).toList();
      if (withMetric.length < 2) {
        setState(() {
          _phase = _RoundPhase.error;
          _loadError = 'Not enough countries with ${_metricLabel(widget.metric)} data (need at least 2, have ${withMetric.length}).';
        });
        return;
      }
      setState(() => _pool = all);
      _startRound();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _RoundPhase.error;
        _loadError = e.toString();
      });
    }
  }

  void _startRound() {
    final round = _HolRound.generate(_pool, widget.metric, widget.difficulty, _rng);
    if (round == null) {
      setState(() {
        _phase = _RoundPhase.error;
        _loadError =
        "Couldn't find a ${_diffLabel(widget.difficulty)}-difficulty pair for ${_metricLabel(widget.metric)} "
            "in the current data set. Try a lower difficulty, or add more countries to the pipeline's data.";
      });
      return;
    }
    setState(() {
      _round = round;
      _selectedSide = null;
      _lastRoundScore = null;
      _remaining = _timeLimit;
      _phase = _RoundPhase.playing;
      _roundStart = DateTime.now();
    });
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _phase != _RoundPhase.playing) return;
      final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
      final remaining = _timeLimit - elapsed;
      if (remaining <= 0) {
        setState(() => _remaining = 0);
        _reveal(correct: false);
        return;
      }
      setState(() => _remaining = remaining);
      _tick();
    });
  }

  void _onSelect(String side) {
    if (_phase != _RoundPhase.playing) return;
    final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
    final pickedBigger = side == 'a' ? _round!.aIsBigger : !_round!.aIsBigger;

    int? score;
    if (pickedBigger) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = raw.round();
    }

    setState(() {
      _selectedSide = side;
      _lastRoundScore = score;
      if (pickedBigger) {
        _totalScore += score!;
        if (score > _bestRoundScore) _bestRoundScore = score;
        _combo++;
      }
    });

    _reveal(correct: pickedBigger);
  }

  void _reveal({required bool correct}) {
    setState(() => _phase = _RoundPhase.revealed);
    Future.delayed(Duration(milliseconds: correct ? 1600 : 2600), () {
      if (!mounted) return;
      if (!correct) {
        _finish();
        return;
      }
      if (_roundIndex + 1 >= _maxRounds) {
        _finish();
      } else {
        setState(() => _roundIndex++);
        _startRound();
      }
    });
  }

  void _finish() {
    setState(() => _phase = _RoundPhase.complete);
    GameAdService.instance.notifyGameFinished();
    _save();
  }

  Future<void> _save() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _ScoreService().addRecord(
        'higher_or_lower_scores_${widget.metric.name}_${widget.difficulty.name}',
        _ScoreRecord(
          score: _totalScore,
          roundsCompleted: _combo,
          maxRounds: _maxRounds,
          bestCombo: _combo,
          playedAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _combo = 0;
      _recorded = false;
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('${_diffLabel(widget.difficulty)} · ${_metricLabel(widget.metric)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
        actions: (_phase == _RoundPhase.loading || _phase == _RoundPhase.error || _phase == _RoundPhase.complete)
            ? null
            : [_ScoreBadge(score: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: _ScreenBackground(
        accent: _accent,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _RoundPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case _RoundPhase.error:
        return _buildError();
      case _RoundPhase.complete:
        return _buildComplete();
      case _RoundPhase.playing:
      case _RoundPhase.revealed:
        return _buildRound();
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: _kFaint),
            const SizedBox(height: 16),
            const Text("Couldn't build a round", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 8),
            if (_loadError != null)
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            const SizedBox(height: 24),
            _GradientButton(label: 'Retry', color: _accent, onPressed: _init),
          ],
        ),
      ),
    );
  }

  Widget _buildRound() {
    final round = _round!;
    final revealed = _phase == _RoundPhase.revealed;
    final ratio = (_remaining / _timeLimit).clamp(0.0, 1.0);
    final barColor = Color.lerp(const Color(0xFFFF5A5F), const Color(0xFF2FBE73), ratio)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUND ${_roundIndex + 1} / $_maxRounds',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              if (_combo > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFF5A5F).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFFF5A5F)),
                    const SizedBox(width: 3),
                    Text('$_combo', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFFF5A5F))),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!revealed)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            )
          else
            _buildResultBanner(),
          const SizedBox(height: 20),
          Text('WHICH HAS MORE ${_metricLabel(widget.metric).toUpperCase()}?',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildCountryCard('a', round.a, round.statA)),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
                    ]),
                    child: const Text('VS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kMuted)),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(child: _buildCountryCard('b', round.b, round.statB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final pickedBigger = _selectedSide != null &&
        ((_selectedSide == 'a' && _round!.aIsBigger) || (_selectedSide == 'b' && !_round!.aIsBigger));
    final timedOut = _selectedSide == null;
    final color = pickedBigger ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(pickedBigger ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              pickedBigger ? 'Correct! +${_lastRoundScore ?? 0}' : (timedOut ? "Time's up" : 'Wrong'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCard(String side, _CountryStats country, _Stat stat) {
    final revealed = _phase == _RoundPhase.revealed;
    final isBigger = side == 'a' ? _round!.aIsBigger : !_round!.aIsBigger;
    final isSelected = _selectedSide == side;

    Color bg = Colors.white;
    Color fg = _kInk;
    Color sub = _kMuted;
    Color border = Colors.black.withOpacity(0.04);

    if (revealed) {
      if (isBigger) {
        bg = const Color(0xFF2FBE73);
        border = const Color(0xFF2FBE73);
        fg = Colors.white;
        sub = Colors.white70;
      } else if (isSelected) {
        bg = const Color(0xFFFF5A5F);
        border = const Color(0xFFFF5A5F);
        fg = Colors.white;
        sub = Colors.white70;
      }
    }

    return GestureDetector(
      onTap: () => _onSelect(side),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: revealed
                        ? Padding(
                      key: const ValueKey('stat'),
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        stat.year != null
                            ? '${_formatValue(stat.value, widget.metric)} (${stat.year})'
                            : _formatValue(stat.value, widget.metric),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub),
                      ),
                    )
                        : const SizedBox.shrink(key: ValueKey('hidden')),
                  ),
                ],
              ),
            ),
            if (revealed && isBigger)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)
            else if (revealed && isSelected)
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accent.withOpacity(0.85), _accent]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('Run Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text('$_totalScore', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                const Text('TOTAL SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Rounds', value: '$_combo/$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Best', value: '$_bestRoundScore'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Combo', value: '$_combo'),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            _GradientButton(label: 'Play Again', color: _accent, onPressed: _retry),
            const SizedBox(height: 10),
            _GradientButton(label: 'Back to Lobby', color: _accent, outlined: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final int best;
  final Color accent;

  const _ScoreBadge({required this.score, required this.best, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            Text('best $best', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}