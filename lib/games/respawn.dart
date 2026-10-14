// lib/games/respawn.dart
//
// Self-contained "Respawn" mini-game: get randomly reborn as a citizen of
// a random country, weighted by that country's annual births (so populous
// countries come up more often — matching how being "born" actually works
// probability-wise), and see how it stacks up against a country you set as
// home. Several draw modes beyond the plain random one let you specifically
// pull a country richer/poorer, more/less populous, or bigger/smaller than
// home, gacha-style.
//
// The ONLY public symbol is [RespawnModeScreen]; everything else is
// private to this library on purpose.
//
// DATA CAVEAT (important, read this before shipping): population, GDP per
// capita, land area, and birth rate below are APPROXIMATE recent-year
// estimates (~2023-2024 vintage) from general knowledge, not a live feed —
// population and area are fairly stable and reliable, but GDP per capita
// and birth rate are the most volatile figures and drift year to year
// (currency swings, revisions, crises). Coverage is 173 countries, ~97% of
// world population and ~130M/~132M of annual global births — good enough
// for realistic weighting, not a substitute for an official source if this
// ever needs to be authoritative. If you want it to stay accurate, the
// cleanest fix is swapping [_kCountries] for a periodically-refreshed pull
// from the World Bank or UN Population Division APIs instead of hardcoded
// numbers.
//
// GAME LOOP:
//   - Each mode draws a random country weighted by annual births FROM
//     WHATEVER CANDIDATE POOL that mode uses — the full list for Random
//     Respawn, or a filtered subset (e.g. "richer than home") for the
//     comparison modes. Weighting by births (not raw population) matches
//     the "you're being born" framing directly.
//   - "My Country" is a persisted home-country setting used for every
//     comparison line and every filtered mode. It has to be set before the
//     comparison modes unlock; Random Respawn works either way.
//   - Every draw is appended to that mode's history (capped, persisted),
//     which powers both the "recent respawns" list and a running average
//     of population / GDP per capita / area across your history in that
//     mode — the running-average-stats feature.
//   - There's no score, win, or loss here — like the reference app this is
//     based on, it's an explore/discover toy, not a quiz.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';

// ============================================================================
// DATA
// ============================================================================

class _CountryStats {
  final String name;
  final String code;
  final double populationMillions;
  final double birthRatePer1000;
  final int gdpPerCapitaUsd;
  final int areaKm2;

  const _CountryStats(
      this.name,
      this.code,
      this.populationMillions,
      this.birthRatePer1000,
      this.gdpPerCapitaUsd,
      this.areaKm2,
      );

  /// Annual births, in millions — population × crude birth rate. This is
  /// what every weighted draw uses.
  double get annualBirthsMillions => populationMillions * birthRatePer1000 / 1000;

  String get emoji {
    final c = code.toUpperCase();
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

const List<_CountryStats> _kCountries = [
  _CountryStats('China', 'CN', 1410.0, 6.4, 12600, 9600000),
  _CountryStats('India', 'IN', 1428.0, 16.5, 2600, 3287000),
  _CountryStats('Indonesia', 'ID', 279.0, 15.5, 4900, 1905000),
  _CountryStats('Pakistan', 'PK', 240.0, 26.0, 1500, 881000),
  _CountryStats('Bangladesh', 'BD', 173.0, 17.0, 2500, 148000),
  _CountryStats('Japan', 'JP', 124.0, 6.3, 34000, 378000),
  _CountryStats('Philippines', 'PH', 117.0, 19.0, 3800, 300000),
  _CountryStats('Vietnam', 'VN', 99.0, 14.5, 4300, 331000),
  _CountryStats('Iran', 'IR', 89.0, 15.0, 4500, 1648000),
  _CountryStats('Turkey', 'TR', 85.0, 14.0, 10600, 783000),
  _CountryStats('Thailand', 'TH', 71.0, 9.0, 7200, 513000),
  _CountryStats('Myanmar', 'MM', 54.0, 17.0, 1200, 676000),
  _CountryStats('South Korea', 'KR', 51.7, 4.5, 33000, 100000),
  _CountryStats('Iraq', 'IQ', 45.0, 27.0, 5900, 435000),
  _CountryStats('Afghanistan', 'AF', 42.0, 31.0, 500, 653000),
  _CountryStats('Saudi Arabia', 'SA', 36.0, 14.0, 28000, 2150000),
  _CountryStats('Uzbekistan', 'UZ', 36.0, 22.0, 2300, 448000),
  _CountryStats('Malaysia', 'MY', 34.0, 15.0, 11600, 330000),
  _CountryStats('Yemen', 'YE', 34.0, 29.0, 650, 528000),
  _CountryStats('Nepal', 'NP', 30.0, 18.0, 1300, 147000),
  _CountryStats('North Korea', 'KP', 26.0, 14.0, 1700, 121000),
  _CountryStats('Sri Lanka', 'LK', 22.0, 13.0, 3800, 66000),
  _CountryStats('Kazakhstan', 'KZ', 20.0, 19.0, 11500, 2725000),
  _CountryStats('Cambodia', 'KH', 17.0, 19.0, 1800, 181000),
  _CountryStats('Jordan', 'JO', 11.3, 21.0, 4500, 89000),
  _CountryStats('Azerbaijan', 'AZ', 10.4, 13.0, 7000, 87000),
  _CountryStats('UAE', 'AE', 9.5, 10.0, 49000, 83600),
  _CountryStats('Tajikistan', 'TJ', 10.4, 24.0, 1100, 141000),
  _CountryStats('Israel', 'IL', 9.7, 18.0, 54000, 22000),
  _CountryStats('Laos', 'LA', 7.6, 19.0, 2000, 237000),
  _CountryStats('Lebanon', 'LB', 5.5, 13.0, 4100, 10400),
  _CountryStats('Kyrgyzstan', 'KG', 7.0, 24.0, 1400, 200000),
  _CountryStats('Turkmenistan', 'TM', 6.4, 24.0, 9000, 488000),
  _CountryStats('Singapore', 'SG', 5.9, 8.0, 84700, 728),
  _CountryStats('Oman', 'OM', 4.6, 22.0, 21000, 309500),
  _CountryStats('Kuwait', 'KW', 4.3, 16.0, 33000, 17800),
  _CountryStats('Georgia', 'GE', 3.7, 13.0, 7000, 69700),
  _CountryStats('Mongolia', 'MN', 3.4, 22.0, 5500, 1564000),
  _CountryStats('Armenia', 'AM', 3.0, 11.5, 7000, 29700),
  _CountryStats('Qatar', 'QA', 2.7, 9.0, 87000, 11600),
  _CountryStats('Bahrain', 'BH', 1.5, 12.0, 29000, 780),
  _CountryStats('Timor-Leste', 'TL', 1.4, 29.0, 1700, 14900),
  _CountryStats('Bhutan', 'BT', 0.79, 15.0, 3600, 38400),
  _CountryStats('Brunei', 'BN', 0.45, 14.0, 32000, 5800),
  _CountryStats('Maldives', 'MV', 0.52, 14.0, 12000, 300),
  _CountryStats('Egypt', 'EG', 112.0, 22.0, 3800, 1010000),
  _CountryStats('Syria', 'SY', 23.0, 22.0, 800, 185000),
  _CountryStats('Nigeria', 'NG', 227.0, 35.0, 2100, 924000),
  _CountryStats('Ethiopia', 'ET', 128.0, 30.0, 1000, 1104000),
  _CountryStats('DR Congo', 'CD', 102.0, 40.0, 650, 2345000),
  _CountryStats('Tanzania', 'TZ', 67.0, 35.0, 1200, 947000),
  _CountryStats('South Africa', 'ZA', 60.0, 19.0, 6700, 1221000),
  _CountryStats('Kenya', 'KE', 55.0, 27.0, 2100, 580000),
  _CountryStats('Uganda', 'UG', 48.0, 36.0, 1000, 241000),
  _CountryStats('Algeria', 'DZ', 45.0, 21.0, 4200, 2382000),
  _CountryStats('Sudan', 'SD', 48.0, 32.0, 600, 1886000),
  _CountryStats('Morocco', 'MA', 37.0, 17.0, 3800, 447000),
  _CountryStats('Angola', 'AO', 36.0, 40.0, 2900, 1247000),
  _CountryStats('Mozambique', 'MZ', 33.0, 37.0, 500, 801000),
  _CountryStats('Ghana', 'GH', 33.0, 28.0, 2400, 239000),
  _CountryStats('Madagascar', 'MG', 30.0, 30.0, 500, 587000),
  _CountryStats('Cameroon', 'CM', 28.0, 34.0, 1700, 475000),
  _CountryStats('Ivory Coast', 'CI', 29.0, 32.0, 2600, 322000),
  _CountryStats('Niger', 'NE', 27.0, 45.0, 600, 1267000),
  _CountryStats('Burkina Faso', 'BF', 23.0, 33.0, 850, 274000),
  _CountryStats('Mali', 'ML', 23.0, 40.0, 900, 1240000),
  _CountryStats('Malawi', 'MW', 21.0, 30.0, 650, 118000),
  _CountryStats('Zambia', 'ZM', 20.0, 33.0, 1500, 752000),
  _CountryStats('Senegal', 'SN', 18.0, 30.0, 1700, 197000),
  _CountryStats('Chad', 'TD', 19.0, 42.0, 700, 1284000),
  _CountryStats('Somalia', 'SO', 18.0, 38.0, 500, 638000),
  _CountryStats('Zimbabwe', 'ZW', 16.0, 29.0, 1700, 391000),
  _CountryStats('Guinea', 'GN', 14.0, 33.0, 1200, 246000),
  _CountryStats('Rwanda', 'RW', 14.0, 27.0, 1000, 26300),
  _CountryStats('Benin', 'BJ', 13.7, 32.0, 1400, 115000),
  _CountryStats('Burundi', 'BI', 13.2, 28.0, 250, 27800),
  _CountryStats('Tunisia', 'TN', 12.5, 15.0, 3900, 163600),
  _CountryStats('South Sudan', 'SS', 11.0, 32.0, 1100, 644000),
  _CountryStats('Togo', 'TG', 8.9, 30.0, 950, 56800),
  _CountryStats('Sierra Leone', 'SL', 8.6, 30.0, 500, 71700),
  _CountryStats('Libya', 'LY', 7.0, 17.0, 7000, 1760000),
  _CountryStats('Congo', 'CG', 6.0, 33.0, 2400, 342000),
  _CountryStats('Liberia', 'LR', 5.4, 30.0, 700, 111000),
  _CountryStats('Central African Republic', 'CF', 5.5, 33.0, 500, 623000),
  _CountryStats('Mauritania', 'MR', 4.9, 31.0, 2100, 1031000),
  _CountryStats('Eritrea', 'ER', 3.7, 28.0, 600, 117600),
  _CountryStats('Namibia', 'NA', 2.6, 25.0, 4900, 824000),
  _CountryStats('Gambia', 'GM', 2.7, 29.0, 800, 11300),
  _CountryStats('Botswana', 'BW', 2.5, 21.0, 7300, 582000),
  _CountryStats('Gabon', 'GA', 2.3, 25.0, 8600, 267700),
  _CountryStats('Lesotho', 'LS', 2.3, 24.0, 1150, 30400),
  _CountryStats('Guinea-Bissau', 'GW', 2.1, 32.0, 800, 36100),
  _CountryStats('Equatorial Guinea', 'GQ', 1.7, 28.0, 7000, 28000),
  _CountryStats('Mauritius', 'MU', 1.3, 9.0, 11000, 2040),
  _CountryStats('Eswatini', 'SZ', 1.2, 23.0, 4400, 17400),
  _CountryStats('Djibouti', 'DJ', 1.1, 22.0, 3600, 23200),
  _CountryStats('Comoros', 'KM', 0.87, 27.0, 1600, 2235),
  _CountryStats('Cape Verde', 'CV', 0.6, 19.0, 4200, 4033),
  _CountryStats('Sao Tome and Principe', 'ST', 0.22, 30.0, 2500, 964),
  _CountryStats('Seychelles', 'SC', 0.1, 14.0, 16000, 460),
  _CountryStats('Russia', 'RU', 144.0, 9.0, 14000, 17098000),
  _CountryStats('Germany', 'DE', 84.0, 8.5, 52000, 357600),
  _CountryStats('United Kingdom', 'GB', 68.0, 10.0, 46000, 243600),
  _CountryStats('France', 'FR', 68.0, 10.5, 44000, 551700),
  _CountryStats('Italy', 'IT', 59.0, 6.5, 38000, 301300),
  _CountryStats('Spain', 'ES', 48.0, 7.5, 32000, 505900),
  _CountryStats('Poland', 'PL', 37.0, 9.0, 22000, 312700),
  _CountryStats('Ukraine', 'UA', 36.0, 7.0, 5000, 603500),
  _CountryStats('Romania', 'RO', 19.0, 9.0, 17000, 238400),
  _CountryStats('Netherlands', 'NL', 18.0, 9.5, 58000, 41500),
  _CountryStats('Belgium', 'BE', 11.8, 10.0, 52000, 30500),
  _CountryStats('Czech Republic', 'CZ', 10.9, 9.5, 28000, 78900),
  _CountryStats('Greece', 'GR', 10.4, 7.5, 22000, 132000),
  _CountryStats('Portugal', 'PT', 10.3, 8.0, 26000, 92200),
  _CountryStats('Sweden', 'SE', 10.6, 10.5, 57000, 450300),
  _CountryStats('Hungary', 'HU', 9.6, 9.0, 19000, 93000),
  _CountryStats('Belarus', 'BY', 9.2, 9.0, 7500, 207600),
  _CountryStats('Austria', 'AT', 9.0, 9.0, 53000, 83900),
  _CountryStats('Switzerland', 'CH', 8.8, 9.5, 93000, 41300),
  _CountryStats('Serbia', 'RS', 6.6, 9.0, 10000, 88400),
  _CountryStats('Bulgaria', 'BG', 6.4, 9.0, 14000, 111000),
  _CountryStats('Denmark', 'DK', 6.0, 10.5, 68000, 43000),
  _CountryStats('Finland', 'FI', 5.6, 8.0, 52000, 338400),
  _CountryStats('Slovakia', 'SK', 5.4, 10.0, 21000, 49000),
  _CountryStats('Norway', 'NO', 5.5, 10.5, 90000, 385000),
  _CountryStats('Ireland', 'IE', 5.2, 11.0, 102000, 70300),
  _CountryStats('Croatia', 'HR', 3.9, 9.0, 18000, 56600),
  _CountryStats('Bosnia and Herzegovina', 'BA', 3.2, 8.0, 7500, 51200),
  _CountryStats('Albania', 'AL', 2.8, 11.0, 6500, 28700),
  _CountryStats('Lithuania', 'LT', 2.7, 9.5, 26000, 65300),
  _CountryStats('Moldova', 'MD', 2.5, 9.0, 5700, 33800),
  _CountryStats('Slovenia', 'SI', 2.1, 9.0, 31000, 20300),
  _CountryStats('Latvia', 'LV', 1.8, 9.0, 22000, 64600),
  _CountryStats('North Macedonia', 'MK', 1.8, 10.0, 7000, 25700),
  _CountryStats('Estonia', 'EE', 1.3, 9.5, 29000, 45200),
  _CountryStats('Cyprus', 'CY', 1.3, 10.0, 32000, 9250),
  _CountryStats('Montenegro', 'ME', 0.62, 11.0, 10500, 13800),
  _CountryStats('Luxembourg', 'LU', 0.66, 10.0, 130000, 2590),
  _CountryStats('Malta', 'MT', 0.53, 9.0, 34000, 316),
  _CountryStats('Iceland', 'IS', 0.39, 12.0, 76000, 103000),
  _CountryStats('United States', 'US', 335.0, 11.0, 82000, 9834000),
  _CountryStats('Brazil', 'BR', 216.0, 13.0, 10000, 8516000),
  _CountryStats('Mexico', 'MX', 128.0, 16.0, 11500, 1964000),
  _CountryStats('Colombia', 'CO', 52.0, 14.0, 6600, 1142000),
  _CountryStats('Argentina', 'AR', 46.0, 14.0, 13600, 2780000),
  _CountryStats('Peru', 'PE', 34.0, 17.0, 7100, 1285000),
  _CountryStats('Venezuela', 'VE', 28.6, 15.5, 4600, 916000),
  _CountryStats('Chile', 'CL', 19.6, 12.0, 16500, 756000),
  _CountryStats('Ecuador', 'EC', 18.0, 16.0, 6300, 257000),
  _CountryStats('Guatemala', 'GT', 18.0, 22.0, 5600, 108900),
  _CountryStats('Canada', 'CA', 39.0, 9.5, 53000, 9985000),
  _CountryStats('Bolivia', 'BO', 12.2, 22.0, 3600, 1099000),
  _CountryStats('Haiti', 'HT', 11.6, 23.0, 1700, 27750),
  _CountryStats('Cuba', 'CU', 11.0, 9.0, 9500, 109900),
  _CountryStats('Dominican Republic', 'DO', 11.3, 18.0, 10400, 48700),
  _CountryStats('Honduras', 'HN', 10.6, 20.0, 3000, 112500),
  _CountryStats('Paraguay', 'PY', 6.9, 19.0, 6300, 397300),
  _CountryStats('Nicaragua', 'NI', 6.9, 18.0, 2400, 130000),
  _CountryStats('El Salvador', 'SV', 6.3, 15.0, 4900, 21000),
  _CountryStats('Costa Rica', 'CR', 5.2, 12.0, 13300, 51100),
  _CountryStats('Panama', 'PA', 4.4, 17.0, 17400, 75400),
  _CountryStats('Uruguay', 'UY', 3.4, 12.0, 21600, 176000),
  _CountryStats('Jamaica', 'JM', 2.8, 14.0, 5800, 10990),
  _CountryStats('Trinidad and Tobago', 'TT', 1.5, 11.0, 18000, 5130),
  _CountryStats('Guyana', 'GY', 0.81, 19.0, 50000, 214970),
  _CountryStats('Suriname', 'SR', 0.63, 15.0, 6300, 163800),
  _CountryStats('Belize', 'BZ', 0.4, 19.0, 6700, 22970),
  _CountryStats('Bahamas', 'BS', 0.4, 13.0, 35000, 13880),
  _CountryStats('Barbados', 'BB', 0.28, 11.0, 19000, 430),
  _CountryStats('Australia', 'AU', 26.6, 11.0, 65000, 7692000),
  _CountryStats('Papua New Guinea', 'PG', 10.3, 24.0, 3000, 462840),
  _CountryStats('New Zealand', 'NZ', 5.2, 11.5, 48000, 268000),
  _CountryStats('Fiji', 'FJ', 0.93, 17.0, 5500, 18270),
];

final Map<String, _CountryStats> _kCountriesByCode = {
  for (final c in _kCountries) c.code: c,
};

// ============================================================================
// WEIGHTED DRAW
// ============================================================================

_CountryStats _drawWeighted(List<_CountryStats> candidates, Random rng) {
  final totalWeight = candidates.fold<double>(0, (sum, c) => sum + c.annualBirthsMillions);
  if (totalWeight <= 0) return candidates[rng.nextInt(candidates.length)];
  final r = rng.nextDouble() * totalWeight;
  double cumulative = 0;
  for (final c in candidates) {
    cumulative += c.annualBirthsMillions;
    if (r <= cumulative) return c;
  }
  return candidates.last; // floating-point rounding fallback
}

// ============================================================================
// MODES
// ============================================================================

enum _RespawnModeId {
  normal,
  richerGdp,
  poorerGdp,
  morePop,
  lessPop,
  biggerArea,
  smallerArea,
}

Color _modeColor(_RespawnModeId id) {
  switch (id) {
    case _RespawnModeId.normal:
      return const Color(0xFFFF6B81);
    case _RespawnModeId.richerGdp:
      return const Color(0xFF2FBE73);
    case _RespawnModeId.poorerGdp:
      return const Color(0xFFFF9F1C);
    case _RespawnModeId.morePop:
      return const Color(0xFF3E63DD);
    case _RespawnModeId.lessPop:
      return const Color(0xFF8B5CF6);
    case _RespawnModeId.biggerArea:
      return const Color(0xFF0D9488);
    case _RespawnModeId.smallerArea:
      return const Color(0xFFFF5A5F);
  }
}

class _RespawnMode {
  final _RespawnModeId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool requiresHome;
  final List<_CountryStats> Function(_CountryStats? home) candidates;
  final String Function(_CountryStats drawn) resultLine;

  /// Null for Random Respawn (no pass/fail concept there). For every other
  /// mode, this checks whether THIS PARTICULAR draw happened to satisfy the
  /// mode's comparison against home -- draws now come from the full country
  /// pool rather than a pre-filtered "guaranteed match" pool, so success
  /// is real, variable, and worth tracking a rate for.
  final bool Function(_CountryStats drawn, _CountryStats home)? isSuccess;

  const _RespawnMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.requiresHome,
    required this.candidates,
    required this.resultLine,
    this.isSuccess,
  });

  String get storageKey => 'respawn_history_${id.name}';
}

String _fmtPop(double millions) {
  if (millions >= 1000) return '${(millions / 1000).toStringAsFixed(2)}B';
  if (millions >= 1) return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  return '${(millions * 1000).toStringAsFixed(0)}K';
}

String _fmtGdp(int usd) => '\$${usd.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
)}';

String _fmtArea(int km2) {
  if (km2 >= 1000000) return '${(km2 / 1000000).toStringAsFixed(km2 >= 10000000 ? 1 : 2)}M km²';
  if (km2 >= 1000) return '${(km2 / 1000).toStringAsFixed(km2 >= 100000 ? 0 : 1)}K km²';
  return '$km2 km²';
}

final List<_RespawnMode> _kModes = [
  _RespawnMode(
    id: _RespawnModeId.normal,
    title: 'Random Respawn',
    subtitle: 'Weighted by annual births — realistic odds',
    icon: Icons.casino_rounded,
    requiresHome: false,
    candidates: (home) => _kCountries,
    resultLine: (drawn) => 'You were reborn in ${drawn.name}.',
  ),
  _RespawnMode(
    id: _RespawnModeId.richerGdp,
    title: 'Richer Country',
    subtitle: 'Try for a higher GDP per capita than home',
    icon: Icons.trending_up_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.gdpPerCapitaUsd > home.gdpPerCapitaUsd,
    resultLine: (drawn) => '${drawn.name}',
  ),
  _RespawnMode(
    id: _RespawnModeId.poorerGdp,
    title: 'Poorer Country',
    subtitle: 'Try for a lower GDP per capita than home',
    icon: Icons.trending_down_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.gdpPerCapitaUsd < home.gdpPerCapitaUsd,
    resultLine: (drawn) => '${drawn.name}',
  ),
  _RespawnMode(
    id: _RespawnModeId.morePop,
    title: 'Bigger Population',
    subtitle: 'Try for more people than home',
    icon: Icons.groups_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.populationMillions > home.populationMillions,
    resultLine: (drawn) => '${drawn.name}',
  ),
  _RespawnMode(
    id: _RespawnModeId.lessPop,
    title: 'Smaller Population',
    subtitle: 'Try for fewer people than home',
    icon: Icons.person_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.populationMillions < home.populationMillions,
    resultLine: (drawn) => '${drawn.name}',
  ),
  _RespawnMode(
    id: _RespawnModeId.biggerArea,
    title: 'Larger Area',
    subtitle: 'Try for a bigger land area than home',
    icon: Icons.map_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.areaKm2 > home.areaKm2,
    resultLine: (drawn) => '${drawn.name}',
  ),
  _RespawnMode(
    id: _RespawnModeId.smallerArea,
    title: 'Smaller Area',
    subtitle: 'Try for a smaller land area than home',
    icon: Icons.zoom_in_map_rounded,
    requiresHome: true,
    candidates: (home) => _kCountries,
    isSuccess: (drawn, home) => drawn.areaKm2 < home.areaKm2,
    resultLine: (drawn) => '${drawn.name}',
  ),
];

// ============================================================================
// PERSISTENCE
// ============================================================================

class _RespawnRecord {
  final String countryCode;
  final DateTime drawnAt;
  final bool? success;

  const _RespawnRecord({required this.countryCode, required this.drawnAt, this.success});
}

class _RespawnStore {
  static const String _homeKey = 'respawn_home_country_code';

  Future<String?> loadHomeCountryCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_homeKey);
  }

  Future<void> setHomeCountryCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeKey, code);
  }

// NOTE: "recent respawns" history is intentionally NOT persisted anymore
// -- it's an in-memory, per-visit list on _RespawnGameScreenState now, so
// it naturally clears the moment you leave the screen. Only the home
// country choice (a setting, not history) is saved across sessions.

}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);
const Color _kAccent = Color(0xFFFF6B81); // warm coral-pink, "birth/life" themed

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
              BoxShadow(
                  color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
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
  final Widget child;

  const _ScreenBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1FFF6B81), _kSurface],
          stops: [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}

/// Search-to-pick country list, reused for the home-country setting.
class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet();

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final options = _kCountries.where((c) => q.isEmpty || c.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _kFaint, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 16),
              const Text('Choose your country',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search_rounded, color: _kFaint),
                  filled: true,
                  fillColor: _kSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final c = options[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(c.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                      onTap: () => Navigator.pop(context, c.code),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// MODE SELECT SCREEN (entry point — the only public symbol in this file)
// ============================================================================

class RespawnModeScreen extends StatefulWidget {
  const RespawnModeScreen({super.key});

  @override
  State<RespawnModeScreen> createState() => _RespawnModeScreenState();
}

class _RespawnModeScreenState extends State<RespawnModeScreen> {
  final _store = _RespawnStore();
  String? _homeCode;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    GameAdService.instance.enterRespawn();
    _load();
  }

  /// Leaving Respawn (back gesture/button) — shows one ad first if at
  /// least one respawn was drawn this visit, then lets the pop proceed.
  Future<bool> _handleWillPop() async {
    await GameAdService.instance.exitRespawn();
    return true;
  }

  Future<void> _load() async {
    final code = await _store.loadHomeCountryCode();
    if (!mounted) return;
    setState(() {
      _homeCode = code;
      _loaded = true;
    });
  }

  Future<void> _pickHomeCountry() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountrySearchSheet(),
    );
    if (code == null) return;
    await _store.setHomeCountryCode(code);
    if (!mounted) return;
    setState(() => _homeCode = code);
  }

  void _openMode(_RespawnMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _RespawnGameScreen(mode: mode)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final home = _homeCode != null ? _kCountriesByCode[_homeCode] : null;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: _kSurface,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: _kInk),
        ),
        body: _ScreenBackground(
          child: SafeArea(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _pickHomeCountry,
                  child: _SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                          child: Text(home?.emoji ?? '🏠', style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MY COUNTRY',
                                  style: TextStyle(
                                      fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: _kMuted)),
                              const SizedBox(height: 2),
                              Text(home?.name ?? 'Not set — tap to choose',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: home != null ? _kInk : _kAccent)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: _kFaint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_kAccent, Color.lerp(_kAccent, Colors.black, 0.3)!]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('CHOOSE A MODE',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                  ],
                ),
                const SizedBox(height: 16),
                for (final mode in _kModes) ...[
                  _ModeCard(
                    mode: mode,
                    locked: mode.requiresHome && home == null,
                    onTap: () {
                      if (mode.requiresHome && home == null) {
                        _pickHomeCountry();
                      } else {
                        _openMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kAccent, Color.lerp(_kAccent, Colors.black, 0.3)!],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _kAccent.withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.casino_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RANDOM REBIRTH',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
              const Text('Respawn',
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text('Get reborn somewhere random, weighted by real odds — then see how it stacks up against home.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _RespawnMode mode;
  final bool locked;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _modeColor(mode.id);
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.85), color],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(mode.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(mode.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.2)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 15, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(locked ? 'Set your country first' : mode.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _kMuted, fontWeight: FontWeight.w600)),
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
// GAME SCREEN
// ============================================================================

class _RespawnGameScreen extends StatefulWidget {
  final _RespawnMode mode;

  const _RespawnGameScreen({required this.mode});

  @override
  State<_RespawnGameScreen> createState() => _RespawnGameScreenState();
}

class _RespawnGameScreenState extends State<_RespawnGameScreen> {
  static const int _maxHistoryShown = 30;

  final _store = _RespawnStore();
  final _rng = Random();

  _CountryStats? _home;
  _CountryStats? _current;
  bool? _currentSuccess; // null = mode has no success/fail concept (Random Respawn)

  // In-memory only, on purpose -- this is "this visit's" respawns, not
  // saved anywhere, so it's naturally empty again next time you open this
  // mode. Newest first.
  final List<_RespawnRecord> _history = [];

  bool _loaded = false;

  List<_CountryStats> get _candidates => widget.mode.candidates(_home);

  int get _successCount => _history.where((r) => r.success == true).length;
  int get _attemptCount => _history.where((r) => r.success != null).length;
  double? get _successRate => _attemptCount == 0 ? null : _successCount / _attemptCount * 100;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final homeCode = await _store.loadHomeCountryCode();
    if (!mounted) return;
    setState(() {
      _home = homeCode != null ? _kCountriesByCode[homeCode] : null;
      _loaded = true;
    });
    _respawn();
  }

  void _respawn() {
    final candidates = _candidates;
    final drawn = _drawWeighted(candidates, _rng);
    final success = (widget.mode.isSuccess != null && _home != null) ? widget.mode.isSuccess!(drawn, _home!) : null;

    final record = _RespawnRecord(countryCode: drawn.code, drawnAt: DateTime.now(), success: success);

    GameAdService.instance.notifyRespawnPlayed();

    setState(() {
      _current = drawn;
      _currentSuccess = success;
      _history.insert(0, record);
      if (_history.length > _maxHistoryShown) {
        _history.removeRange(_maxHistoryShown, _history.length);
      }
    });
  }

  double _probabilityPercent(_CountryStats country) {
    final pool = _candidates;
    final total = pool.fold<double>(0, (sum, c) => sum + c.annualBirthsMillions);
    if (total <= 0) return 0;
    return country.annualBirthsMillions / total * 100;
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
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(widget.mode.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        child: SafeArea(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_current == null) return const SizedBox.shrink();
    final drawn = _current!;
    final count = _history.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 92, 20, 32),
      children: [
        _buildResultCard(drawn, count),
        const SizedBox(height: 16),
        _GradientButton(
          label: 'Respawn Again',
          icon: Icons.casino_rounded,
          color: _kAccent,
          onPressed: _respawn,
        ),
        if (_home != null) ...[
          const SizedBox(height: 20),
          _buildComparisonCard(drawn, _home!),
        ],
        const SizedBox(height: 20),
        _buildAverageCard(),
        const SizedBox(height: 20),
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildResultCard(_CountryStats drawn, int count) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_currentSuccess != null) ...[
            _buildOutcomeBadge(_currentSuccess!),
            const SizedBox(height: 14),
          ],
          Text(drawn.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 10),
          Text(drawn.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
          const SizedBox(height: 4),
          Text(widget.mode.resultLine(drawn),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Population', value: _fmtPop(drawn.populationMillions))),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'GDP/capita', value: _fmtGdp(drawn.gdpPerCapitaUsd))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Area', value: _fmtArea(drawn.areaKm2))),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatChip(
                      label: 'Odds', value: '${_probabilityPercent(drawn).toStringAsFixed(2)}%')),
            ],
          ),
          if (_successRate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _StatChip(
                        label: 'Success rate',
                        value: '${_successRate!.toStringAsFixed(0)}% ($_successCount/$_attemptCount)')),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('Respawn #$count in this mode',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kFaint)),
        ],
      ),
    );
  }

  Widget _buildOutcomeBadge(bool success) {
    final color = success ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            success ? 'SUCCESS' : 'FAIL',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(_CountryStats drawn, _CountryStats home) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(home.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('VS YOUR COUNTRY (${home.name.toUpperCase()})',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 14),
          _ComparisonRow(label: 'Population', drawnValue: drawn.populationMillions, homeValue: home.populationMillions),
          const SizedBox(height: 10),
          _ComparisonRow(
              label: 'GDP per capita',
              drawnValue: drawn.gdpPerCapitaUsd.toDouble(),
              homeValue: home.gdpPerCapitaUsd.toDouble()),
          const SizedBox(height: 10),
          _ComparisonRow(label: 'Land area', drawnValue: drawn.areaKm2.toDouble(), homeValue: home.areaKm2.toDouble()),
        ],
      ),
    );
  }

  Widget _buildAverageCard() {
    final stats = _history
        .map((r) => _kCountriesByCode[r.countryCode])
        .whereType<_CountryStats>()
        .toList();
    if (stats.isEmpty) return const SizedBox.shrink();

    final avgPop = stats.fold<double>(0, (s, c) => s + c.populationMillions) / stats.length;
    final avgGdp = stats.fold<double>(0, (s, c) => s + c.gdpPerCapitaUsd) / stats.length;
    final avgArea = stats.fold<double>(0, (s, c) => s + c.areaKm2) / stats.length;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // For every mode except Random Respawn, the success rate is the
          // single most important number on this screen -- shown big, in
          // color, before anything else in the card.
          if (_successRate != null) ...[
            _buildSuccessRateBanner(),
            const SizedBox(height: 14),
          ],
          Text('YOUR AVERAGE RESPAWN (last ${stats.length})',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _kMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Avg. Pop', value: _fmtPop(avgPop))),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Avg. GDP/cap', value: _fmtGdp(avgGdp.round()))),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Avg. Area', value: _fmtArea(avgArea.round()))),
            ],
          ),
          if (_home != null) ...[
            const SizedBox(height: 10),
            _ComparisonRow(label: 'Avg. vs home (Pop)', drawnValue: avgPop, homeValue: _home!.populationMillions),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessRateBanner() {
    final rate = _successRate!;
    final color = rate >= 50 ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 26, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rate.toStringAsFixed(0)}% SUCCESS RATE',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
                Text('$_successCount of $_attemptCount respawns this visit',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('RECENT RESPAWNS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _kMuted)),
              ),
              const Text('this visit only',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kFaint)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _history.take(15).map((r) {
              final c = _kCountriesByCode[r.countryCode];
              if (c == null) return const SizedBox.shrink();
              final outcomeColor = r.success == null
                  ? null
                  : (r.success! ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: outcomeColor != null ? Border.all(color: outcomeColor.withOpacity(0.45)) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (outcomeColor != null) ...[
                      Icon(r.success! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 13, color: outcomeColor),
                      const SizedBox(width: 4),
                    ],
                    Text(c.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kInk)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double drawnValue;
  final double homeValue;

  const _ComparisonRow({required this.label, required this.drawnValue, required this.homeValue});

  @override
  Widget build(BuildContext context) {
    if (homeValue <= 0 || drawnValue <= 0) {
      return Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kInk))),
          const Text('—', style: TextStyle(fontSize: 12, color: _kFaint)),
        ],
      );
    }
    final bigger = drawnValue >= homeValue;
    final ratio = bigger ? drawnValue / homeValue : homeValue / drawnValue;
    final color = ratio < 1.05 ? _kMuted : (bigger ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F));
    final ratioText = ratio < 1.05 ? 'about the same' : '${ratio.toStringAsFixed(ratio >= 10 ? 0 : 1)}× ${bigger ? 'more' : 'less'}';

    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kInk))),
        Row(
          children: [
            if (ratio >= 1.05)
              Icon(bigger ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color),
            const SizedBox(width: 3),
            Text(ratioText, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: _kMuted)),
        ],
      ),
    );
  }
}