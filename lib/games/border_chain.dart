// lib/games/border_chain.dart
//
// Self-contained "Border Chain" mini-game: given a start country A and a
// destination country B, name the SHORTEST land-border path between them.
// Ties are fine -- any neighbor that keeps you on a shortest path to B is
// accepted, not just one specific "canonical" route.
//
// Everything (the full land-border graph, scoring persistence, shared UI
// kit, and the lobby + game screens) lives in this single file, same
// pattern as the other games/*.dart files.
//
// The ONLY public symbol is [BorderChainLobbyScreen]; everything else is
// private to this library on purpose.
//
// GAME LOOP:
//   - Each round, A and B are picked randomly from the SAME connected
//     component (so a path is guaranteed to exist), with a shortest
//     distance of 2-5 hops -- long enough to be an actual puzzle, short
//     enough to stay readable on a phone screen.
//   - Shortest distance from every country to B is precomputed once via
//     BFS ([_bfsDistances]), which also naturally finds ties: any neighbor
//     whose distance-to-B is exactly one less than the current country's
//     is a valid next step, which is exactly how ties for "shortest" are
//     naturally allowed -- more than one neighbor can satisfy that check.
//   - At each step, the player sees the CURRENT country's real neighbors
//     (from the graph) as tap targets -- not a global search box, since
//     the valid answer set is naturally small here. Tapping a neighbor
//     that's geographically real but NOT on any shortest path to B ends
//     the round immediately (it's a valid border, just not an optimal
//     move) -- same strictness as the original "one wrong link ends it"
//     rule, just redefined around optimality instead of mere adjacency.
//   - A run is a fixed number of A→B rounds (not one open-ended chain).
//     Score per solved round = the shortest distance itself (hops), so
//     harder (longer) puzzles are worth more -- a direct extension of the
//     original "+1 point per connection" rule to a round that requires
//     several connections in a row.
//
// DATA SCOPE (decided explicitly, see the graph below):
//   - Pure island nations with zero land borders are excluded entirely —
//     they can never start or extend a chain.
//   - Non-sovereign territories/dependencies are excluded as their own
//     entities (Gibraltar, Hong Kong, Greenland, French Polynesia, etc).
//   - Contested/partially-recognized entities are excluded UNIFORMLY
//     (Western Sahara, Kosovo, Palestine, Taiwan) to avoid taking a
//     position on any specific dispute, rather than picking and choosing.
//   - A country's overseas exclaves/territories do NOT extend its border
//     list, even where a real fence/checkpoint exists (Morocco–Spain via
//     Ceuta/Melilla, France via French Guiana) — this follows the same
//     "exclude dependencies/territories" rule consistently rather than
//     carving out exceptions for cases that technically have a land
//     crossing. Kaliningrad is the one deliberate exception kept below:
//     Russia–Poland and Russia–Lithuania stay, since Kaliningrad is not a
//     separate territory but ordinary Russian sovereign soil, just non-
//     contiguous — if you'd rather drop those two as well for full
//     consistency, delete "PL" from RU's list (and RU from PL's), and "LT"
//     from RU's list (and RU from LT's).
//   - Countries connected to their only "neighbor" purely by a bridge or
//     causeway (Singapore–Malaysia, Bahrain–Saudi Arabia) are excluded, per
//     the spec's rule that bridge/tunnel-only links don't count as a land
//     border — they'd have zero genuine land neighbors anyway.
//   - 155 countries, 311 border edges total. Verified programmatically for
//     symmetry (if A borders B, B borders A), no self-loops, no duplicate
//     edges, and no isolated nodes before being hand-copied in here.
//
// SCORING: see the GAME LOOP note above. Total score across a run (plus
// rounds solved and best single-round path length) is what's saved to the
// leaderboard.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';
import 'package:jidoapp/services/game_insane_trial_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// ============================================================================
// DATA
// ============================================================================

class _BorderCountry {
  final String name;
  final String code;
  final List<String> neighbors;

  const _BorderCountry(this.name, this.code, this.neighbors);

  String get emoji {
    final c = code.toUpperCase();
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

final Map<String, _BorderCountry> _kCountries = {
  'AD': _BorderCountry('Andorra', 'AD', ['ES', 'FR']),
  'AE': _BorderCountry('United Arab Emirates', 'AE', ['SA', 'OM']),
  'AF': _BorderCountry('Afghanistan', 'AF', ['TM', 'UZ', 'TJ', 'CN', 'PK', 'IR']),
  'AL': _BorderCountry('Albania', 'AL', ['ME', 'RS', 'MK', 'GR']),
  'AM': _BorderCountry('Armenia', 'AM', ['GE', 'AZ', 'IR', 'TR']),
  'AO': _BorderCountry('Angola', 'AO', ['CG', 'CD', 'ZM', 'NA']),
  'AR': _BorderCountry('Argentina', 'AR', ['CL', 'BO', 'PY', 'BR', 'UY']),
  'AT': _BorderCountry('Austria', 'AT', ['CH', 'LI', 'DE', 'CZ', 'SK', 'HU', 'SI', 'IT']),
  'AZ': _BorderCountry('Azerbaijan', 'AZ', ['RU', 'GE', 'AM', 'IR', 'TR']),
  'BA': _BorderCountry('Bosnia and Herzegovina', 'BA', ['HR', 'RS', 'ME']),
  'BD': _BorderCountry('Bangladesh', 'BD', ['IN', 'MM']),
  'BE': _BorderCountry('Belgium', 'BE', ['FR', 'NL', 'DE', 'LU']),
  'BF': _BorderCountry('Burkina Faso', 'BF', ['ML', 'NE', 'BJ', 'TG', 'GH', 'CI']),
  'BG': _BorderCountry('Bulgaria', 'BG', ['RO', 'RS', 'MK', 'GR', 'TR']),
  'BI': _BorderCountry('Burundi', 'BI', ['RW', 'TZ', 'CD']),
  'BJ': _BorderCountry('Benin', 'BJ', ['TG', 'BF', 'NE', 'NG']),
  'BN': _BorderCountry('Brunei', 'BN', ['MY']),
  'BO': _BorderCountry('Bolivia', 'BO', ['PE', 'BR', 'PY', 'AR', 'CL']),
  'BR': _BorderCountry('Brazil', 'BR', ['GY', 'SR', 'VE', 'CO', 'PE', 'BO', 'PY', 'AR', 'UY']),
  'BT': _BorderCountry('Bhutan', 'BT', ['IN', 'CN']),
  'BW': _BorderCountry('Botswana', 'BW', ['NA', 'ZM', 'ZW', 'ZA']),
  'BY': _BorderCountry('Belarus', 'BY', ['PL', 'LT', 'LV', 'RU', 'UA']),
  'BZ': _BorderCountry('Belize', 'BZ', ['MX', 'GT']),
  'CA': _BorderCountry('Canada', 'CA', ['US']),
  'CD': _BorderCountry('DR Congo', 'CD', ['CG', 'CF', 'SS', 'UG', 'RW', 'BI', 'TZ', 'ZM', 'AO']),
  'CF': _BorderCountry('Central African Republic', 'CF', ['TD', 'SD', 'SS', 'CD', 'CG', 'CM']),
  'CG': _BorderCountry('Congo', 'CG', ['GA', 'CM', 'CF', 'CD', 'AO']),
  'CH': _BorderCountry('Switzerland', 'CH', ['FR', 'DE', 'AT', 'LI', 'IT']),
  'CI': _BorderCountry('Ivory Coast', 'CI', ['LR', 'GN', 'ML', 'BF', 'GH']),
  'CL': _BorderCountry('Chile', 'CL', ['PE', 'BO', 'AR']),
  'CM': _BorderCountry('Cameroon', 'CM', ['NG', 'TD', 'CF', 'GQ', 'GA', 'CG']),
  'CN': _BorderCountry('China', 'CN', ['RU', 'MN', 'KZ', 'KG', 'TJ', 'AF', 'PK', 'IN', 'NP', 'BT', 'MM', 'LA', 'VN', 'KP']),
  'CO': _BorderCountry('Colombia', 'CO', ['PA', 'VE', 'BR', 'PE', 'EC']),
  'CR': _BorderCountry('Costa Rica', 'CR', ['NI', 'PA']),
  'CZ': _BorderCountry('Czech Republic', 'CZ', ['DE', 'PL', 'SK', 'AT']),
  'DE': _BorderCountry('Germany', 'DE', ['FR', 'CH', 'AT', 'CZ', 'PL', 'DK', 'NL', 'BE', 'LU']),
  'DJ': _BorderCountry('Djibouti', 'DJ', ['ER', 'ET', 'SO']),
  'DK': _BorderCountry('Denmark', 'DK', ['DE']),
  'DO': _BorderCountry('Dominican Republic', 'DO', ['HT']),
  'DZ': _BorderCountry('Algeria', 'DZ', ['MA', 'TN', 'LY', 'NE', 'ML', 'MR']),
  'EC': _BorderCountry('Ecuador', 'EC', ['CO', 'PE']),
  'EE': _BorderCountry('Estonia', 'EE', ['LV', 'RU']),
  'EG': _BorderCountry('Egypt', 'EG', ['LY', 'SD', 'IL']),
  'ER': _BorderCountry('Eritrea', 'ER', ['SD', 'ET', 'DJ']),
  'ES': _BorderCountry('Spain', 'ES', ['PT', 'FR', 'AD']),
  'ET': _BorderCountry('Ethiopia', 'ET', ['ER', 'DJ', 'SO', 'KE', 'SS', 'SD']),
  'FI': _BorderCountry('Finland', 'FI', ['NO', 'SE', 'RU']),
  'FR': _BorderCountry('France', 'FR', ['ES', 'AD', 'MC', 'IT', 'CH', 'DE', 'LU', 'BE']),
  'GA': _BorderCountry('Gabon', 'GA', ['GQ', 'CM', 'CG']),
  'GB': _BorderCountry('United Kingdom', 'GB', ['IE']),
  'GE': _BorderCountry('Georgia', 'GE', ['RU', 'AZ', 'AM', 'TR']),
  'GH': _BorderCountry('Ghana', 'GH', ['CI', 'BF', 'TG']),
  'GM': _BorderCountry('Gambia', 'GM', ['SN']),
  'GN': _BorderCountry('Guinea', 'GN', ['SN', 'ML', 'CI', 'LR', 'SL', 'GW']),
  'GQ': _BorderCountry('Equatorial Guinea', 'GQ', ['CM', 'GA']),
  'GR': _BorderCountry('Greece', 'GR', ['AL', 'MK', 'BG', 'TR']),
  'GT': _BorderCountry('Guatemala', 'GT', ['MX', 'BZ', 'HN', 'SV']),
  'GW': _BorderCountry('Guinea-Bissau', 'GW', ['SN', 'GN']),
  'GY': _BorderCountry('Guyana', 'GY', ['VE', 'BR', 'SR']),
  'HN': _BorderCountry('Honduras', 'HN', ['GT', 'SV', 'NI']),
  'HR': _BorderCountry('Croatia', 'HR', ['SI', 'HU', 'RS', 'BA', 'ME']),
  'HT': _BorderCountry('Haiti', 'HT', ['DO']),
  'HU': _BorderCountry('Hungary', 'HU', ['AT', 'SK', 'UA', 'RO', 'RS', 'HR', 'SI']),
  'ID': _BorderCountry('Indonesia', 'ID', ['MY', 'PG', 'TL']),
  'IE': _BorderCountry('Ireland', 'IE', ['GB']),
  'IL': _BorderCountry('Israel', 'IL', ['LB', 'SY', 'JO', 'EG']),
  'IN': _BorderCountry('India', 'IN', ['PK', 'CN', 'NP', 'BT', 'BD', 'MM']),
  'IQ': _BorderCountry('Iraq', 'IQ', ['TR', 'IR', 'KW', 'SA', 'JO', 'SY']),
  'IR': _BorderCountry('Iran', 'IR', ['AM', 'AZ', 'TM', 'AF', 'PK', 'IQ', 'TR']),
  'IT': _BorderCountry('Italy', 'IT', ['FR', 'CH', 'AT', 'SI', 'SM', 'VA']),
  'JO': _BorderCountry('Jordan', 'JO', ['SY', 'IQ', 'SA', 'IL']),
  'KE': _BorderCountry('Kenya', 'KE', ['ET', 'SO', 'TZ', 'UG', 'SS']),
  'KG': _BorderCountry('Kyrgyzstan', 'KG', ['KZ', 'CN', 'TJ', 'UZ']),
  'KH': _BorderCountry('Cambodia', 'KH', ['TH', 'LA', 'VN']),
  'KP': _BorderCountry('North Korea', 'KP', ['CN', 'RU', 'KR']),
  'KR': _BorderCountry('South Korea', 'KR', ['KP']),
  'KW': _BorderCountry('Kuwait', 'KW', ['IQ', 'SA']),
  'KZ': _BorderCountry('Kazakhstan', 'KZ', ['RU', 'CN', 'KG', 'UZ', 'TM']),
  'LA': _BorderCountry('Laos', 'LA', ['CN', 'VN', 'KH', 'TH', 'MM']),
  'LB': _BorderCountry('Lebanon', 'LB', ['SY', 'IL']),
  'LI': _BorderCountry('Liechtenstein', 'LI', ['CH', 'AT']),
  'LR': _BorderCountry('Liberia', 'LR', ['SL', 'GN', 'CI']),
  'LS': _BorderCountry('Lesotho', 'LS', ['ZA']),
  'LT': _BorderCountry('Lithuania', 'LT', ['PL', 'RU', 'BY', 'LV']),
  'LU': _BorderCountry('Luxembourg', 'LU', ['FR', 'DE', 'BE']),
  'LV': _BorderCountry('Latvia', 'LV', ['LT', 'BY', 'RU', 'EE']),
  'LY': _BorderCountry('Libya', 'LY', ['TN', 'DZ', 'NE', 'TD', 'SD', 'EG']),
  'MA': _BorderCountry('Morocco', 'MA', ['DZ']),
  'MC': _BorderCountry('Monaco', 'MC', ['FR']),
  'MD': _BorderCountry('Moldova', 'MD', ['RO', 'UA']),
  'ME': _BorderCountry('Montenegro', 'ME', ['HR', 'BA', 'RS', 'AL']),
  'MK': _BorderCountry('North Macedonia', 'MK', ['RS', 'BG', 'GR', 'AL']),
  'ML': _BorderCountry('Mali', 'ML', ['DZ', 'NE', 'BF', 'CI', 'GN', 'SN', 'MR']),
  'MM': _BorderCountry('Myanmar', 'MM', ['IN', 'BD', 'CN', 'LA', 'TH']),
  'MN': _BorderCountry('Mongolia', 'MN', ['RU', 'CN']),
  'MR': _BorderCountry('Mauritania', 'MR', ['DZ', 'ML', 'SN']),
  'MW': _BorderCountry('Malawi', 'MW', ['TZ', 'MZ', 'ZM']),
  'MX': _BorderCountry('Mexico', 'MX', ['US', 'GT', 'BZ']),
  'MY': _BorderCountry('Malaysia', 'MY', ['TH', 'ID', 'BN']),
  'MZ': _BorderCountry('Mozambique', 'MZ', ['TZ', 'MW', 'ZM', 'ZW', 'SZ', 'ZA']),
  'NA': _BorderCountry('Namibia', 'NA', ['AO', 'ZM', 'BW', 'ZA']),
  'NE': _BorderCountry('Niger', 'NE', ['DZ', 'LY', 'TD', 'NG', 'BJ', 'BF', 'ML']),
  'NG': _BorderCountry('Nigeria', 'NG', ['BJ', 'NE', 'TD', 'CM']),
  'NI': _BorderCountry('Nicaragua', 'NI', ['HN', 'CR']),
  'NL': _BorderCountry('Netherlands', 'NL', ['DE', 'BE']),
  'NO': _BorderCountry('Norway', 'NO', ['SE', 'FI', 'RU']),
  'NP': _BorderCountry('Nepal', 'NP', ['IN', 'CN']),
  'OM': _BorderCountry('Oman', 'OM', ['SA', 'AE', 'YE']),
  'PA': _BorderCountry('Panama', 'PA', ['CR', 'CO']),
  'PE': _BorderCountry('Peru', 'PE', ['EC', 'CO', 'BR', 'BO', 'CL']),
  'PG': _BorderCountry('Papua New Guinea', 'PG', ['ID']),
  'PK': _BorderCountry('Pakistan', 'PK', ['AF', 'CN', 'IN', 'IR']),
  'PL': _BorderCountry('Poland', 'PL', ['DE', 'CZ', 'SK', 'UA', 'BY', 'LT', 'RU']),
  'PT': _BorderCountry('Portugal', 'PT', ['ES']),
  'PY': _BorderCountry('Paraguay', 'PY', ['BO', 'BR', 'AR']),
  'QA': _BorderCountry('Qatar', 'QA', ['SA']),
  'RO': _BorderCountry('Romania', 'RO', ['HU', 'UA', 'MD', 'BG', 'RS']),
  'RS': _BorderCountry('Serbia', 'RS', ['HU', 'RO', 'BG', 'MK', 'AL', 'ME', 'BA', 'HR']),
  'RU': _BorderCountry('Russia', 'RU', ['NO', 'FI', 'EE', 'LV', 'LT', 'PL', 'BY', 'UA', 'GE', 'AZ', 'KZ', 'MN', 'CN', 'KP']),
  'RW': _BorderCountry('Rwanda', 'RW', ['UG', 'TZ', 'BI', 'CD']),
  'SA': _BorderCountry('Saudi Arabia', 'SA', ['JO', 'IQ', 'KW', 'QA', 'AE', 'OM', 'YE']),
  'SD': _BorderCountry('Sudan', 'SD', ['EG', 'LY', 'TD', 'CF', 'SS', 'ET', 'ER']),
  'SE': _BorderCountry('Sweden', 'SE', ['NO', 'FI']),
  'SI': _BorderCountry('Slovenia', 'SI', ['IT', 'AT', 'HU', 'HR']),
  'SK': _BorderCountry('Slovakia', 'SK', ['CZ', 'PL', 'UA', 'HU', 'AT']),
  'SL': _BorderCountry('Sierra Leone', 'SL', ['GN', 'LR']),
  'SM': _BorderCountry('San Marino', 'SM', ['IT']),
  'SN': _BorderCountry('Senegal', 'SN', ['MR', 'ML', 'GN', 'GW', 'GM']),
  'SO': _BorderCountry('Somalia', 'SO', ['DJ', 'ET', 'KE']),
  'SR': _BorderCountry('Suriname', 'SR', ['GY', 'BR']),
  'SS': _BorderCountry('South Sudan', 'SS', ['SD', 'CF', 'CD', 'UG', 'KE', 'ET']),
  'SV': _BorderCountry('El Salvador', 'SV', ['GT', 'HN']),
  'SY': _BorderCountry('Syria', 'SY', ['TR', 'IQ', 'JO', 'IL', 'LB']),
  'SZ': _BorderCountry('Eswatini', 'SZ', ['ZA', 'MZ']),
  'TD': _BorderCountry('Chad', 'TD', ['LY', 'SD', 'CF', 'CM', 'NG', 'NE']),
  'TG': _BorderCountry('Togo', 'TG', ['GH', 'BF', 'BJ']),
  'TH': _BorderCountry('Thailand', 'TH', ['MM', 'LA', 'KH', 'MY']),
  'TJ': _BorderCountry('Tajikistan', 'TJ', ['KG', 'CN', 'AF', 'UZ']),
  'TL': _BorderCountry('Timor-Leste', 'TL', ['ID']),
  'TM': _BorderCountry('Turkmenistan', 'TM', ['KZ', 'UZ', 'AF', 'IR']),
  'TN': _BorderCountry('Tunisia', 'TN', ['DZ', 'LY']),
  'TR': _BorderCountry('Turkey', 'TR', ['GR', 'BG', 'GE', 'AM', 'AZ', 'IR', 'IQ', 'SY']),
  'TZ': _BorderCountry('Tanzania', 'TZ', ['KE', 'UG', 'RW', 'BI', 'CD', 'ZM', 'MW', 'MZ']),
  'UA': _BorderCountry('Ukraine', 'UA', ['PL', 'SK', 'HU', 'RO', 'MD', 'RU', 'BY']),
  'UG': _BorderCountry('Uganda', 'UG', ['SS', 'KE', 'TZ', 'RW', 'CD']),
  'US': _BorderCountry('United States', 'US', ['CA', 'MX']),
  'UY': _BorderCountry('Uruguay', 'UY', ['BR', 'AR']),
  'UZ': _BorderCountry('Uzbekistan', 'UZ', ['KZ', 'TM', 'AF', 'TJ', 'KG']),
  'VA': _BorderCountry('Vatican City', 'VA', ['IT']),
  'VE': _BorderCountry('Venezuela', 'VE', ['CO', 'BR', 'GY']),
  'VN': _BorderCountry('Vietnam', 'VN', ['CN', 'LA', 'KH']),
  'YE': _BorderCountry('Yemen', 'YE', ['SA', 'OM']),
  'ZA': _BorderCountry('South Africa', 'ZA', ['NA', 'BW', 'ZW', 'MZ', 'SZ', 'LS']),
  'ZM': _BorderCountry('Zambia', 'ZM', ['CD', 'TZ', 'MW', 'MZ', 'ZW', 'BW', 'NA', 'AO']),
  'ZW': _BorderCountry('Zimbabwe', 'ZW', ['ZM', 'MZ', 'ZA', 'BW']),
};

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _BorderScoreRecord {
  final int score; // sum of hop-counts across every solved round this run
  final int roundsSolved;
  final int maxRounds;
  final int bestPathLength; // longest single shortest-path solved (hops)
  final DateTime playedAt;

  const _BorderScoreRecord({
    required this.score,
    required this.roundsSolved,
    required this.maxRounds,
    required this.bestPathLength,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'roundsSolved': roundsSolved,
    'maxRounds': maxRounds,
    'bestPathLength': bestPathLength,
    'playedAt': playedAt.toIso8601String(),
  };

  factory _BorderScoreRecord.fromJson(Map<String, dynamic> json) => _BorderScoreRecord(
    score: json['score'] as int,
    roundsSolved: json['roundsSolved'] as int,
    maxRounds: json['maxRounds'] as int,
    bestPathLength: json['bestPathLength'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _BorderScoreService {
  static const int maxStoredRecords = 20;

  Future<List<_BorderScoreRecord>> loadRecords(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records =
      decoded.map((e) => _BorderScoreRecord.fromJson(e as Map<String, dynamic>)).toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(String storageKey, _BorderScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(storageKey);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(storageKey, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }
}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);
const Color _kAccent = Color(0xFF0D9488); // teal — distinct from the other games' accents

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
    Localizations.maybeLocaleOf(context);
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
    Localizations.maybeLocaleOf(context);
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
              Text(tr(widget.label),
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
    Localizations.maybeLocaleOf(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1F0D9488), _kSurface],
          stops: [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}


// ============================================================================
// PATHFINDING
// ============================================================================

/// BFS shortest-hop distance from [fromCode] to every reachable country.
/// The graph is undirected, so this doubles as "distance TO fromCode" when
/// used the other way around — which is exactly how the round validates
/// each move (distance-to-target must shrink by exactly 1 per step).
Map<String, int> _bfsDistances(String fromCode) {
  final dist = <String, int>{fromCode: 0};
  final queue = <String>[fromCode];
  var head = 0;
  while (head < queue.length) {
    final current = queue[head++];
    final currentDist = dist[current]!;
    for (final neighbor in _kCountries[current]!.neighbors) {
      if (!dist.containsKey(neighbor)) {
        dist[neighbor] = currentDist + 1;
        queue.add(neighbor);
      }
    }
  }
  return dist;
}

/// Picks a random (A, B) pair in the same connected component with a
/// shortest distance in [minHops, maxHops]. Retries with a fresh A a
/// handful of times if the first pick has no candidates in range (rare,
/// but some low-connectivity corners of the graph can come up short).
class _RoundPuzzle {
  final String startCode;
  final String targetCode;
  final Map<String, int> distToTarget;
  final int shortestDistance;

  const _RoundPuzzle({
    required this.startCode,
    required this.targetCode,
    required this.distToTarget,
    required this.shortestDistance,
  });

  static _RoundPuzzle generate({
    int minHops = 2,
    int maxHops = 5,
    bool avoidTrivialHops = true,
  }) {
    final allCodes = _kCountries.keys.toList();
    for (var attempt = 0; attempt < 40; attempt++) {
      allCodes.shuffle();
      final start = allCodes.first;
      final distFromStart = _bfsDistances(start);
      final candidates = distFromStart.entries
          .where((e) => e.value >= minHops && e.value <= maxHops)
          .map((e) => e.key)
          .toList();
      if (candidates.isEmpty) continue;
      candidates.shuffle();

      for (final target in candidates) {
        final distToTarget = _bfsDistances(target); // symmetric: distance-to-target from anywhere
        final shortestDistance = distFromStart[target]!;

        if (avoidTrivialHops) {
          // Reject this start/target pair if ANY country that could appear
          // as a stop along a shortest path (the start included, the
          // target excluded -- the target doesn't need onward candidates)
          // has only one real border in total. A country with exactly one
          // neighbor (e.g. Portugal only borders Spain) makes that hop a
          // free pass with nothing to actually decide -- boring regardless
          // of which tied shortest path the player ends up walking.
          final hasTrivialHop = _kCountries.keys.any((code) {
            if (code == target) return false;
            final df = distFromStart[code];
            final dt = distToTarget[code];
            if (df == null || dt == null) return false;
            if (df + dt != shortestDistance) return false; // not on any shortest path
            return _kCountries[code]!.neighbors.length <= 1;
          });
          if (hasTrivialHop) continue;
        }

        return _RoundPuzzle(
          startCode: start,
          targetCode: target,
          distToTarget: distToTarget,
          shortestDistance: shortestDistance,
        );
      }
    }
    // Extremely unlikely fallback: just connect two direct neighbors. (Only
    // reachable if avoidTrivialHops rejected every candidate 40 times in a
    // row, which would mean the country graph itself is unusually sparse.)
    final start = allCodes.first;
    final target = _kCountries[start]!.neighbors.first;
    final distToTarget = _bfsDistances(target);
    return _RoundPuzzle(
      startCode: start,
      targetCode: target,
      distToTarget: distToTarget,
      shortestDistance: 1,
    );
  }
}

// ============================================================================
// DIFFICULTY
// ============================================================================

/// Easy shows the current country's real neighbors as tap targets — you're
/// choosing among options you can already see are valid borders, and the
/// exact hop count to the target is shown. Hard removes both crutches: you
/// search the full country list yourself (nothing narrowed down to "real
/// neighbors" for you), and the shortest-path length is kept secret — you're
/// only told to get there as fast as possible, not how fast that is.
/// Easy/Medium/Hard all show tap targets for the current country — you're
/// choosing among options, never typing blind. What changes between them is
/// (a) how many hops the shortest path is, and (b) how many decoy (real,
/// but NOT-a-border) countries get mixed in alongside the real neighbors,
/// so recognizing "is this actually adjacent?" gets progressively harder
/// even though it's still a tap-based pick.
///
/// Insane is the odd one out and unchanged from the original "Hard" mode:
/// no candidates shown at all, full country search, hop count hidden.
enum _BorderChainDifficulty { easy, medium, hard, insane }

(int minHops, int maxHops, int decoyCount) _tierConfig(_BorderChainDifficulty d) {
  switch (d) {
    case _BorderChainDifficulty.easy:
      return (2, 3, 0);
    case _BorderChainDifficulty.medium:
      return (3, 4, 3);
    case _BorderChainDifficulty.hard:
      return (4, 6, 6);
    case _BorderChainDifficulty.insane:
      return (2, 7, 0); // decoy count is irrelevant -- Insane doesn't show candidates at all
  }
}

Color _accentFor(_BorderChainDifficulty d) {
  switch (d) {
    case _BorderChainDifficulty.easy:
      return const Color(0xFF2FBE73); // green
    case _BorderChainDifficulty.medium:
      return const Color(0xFFFF9F1C); // yellow/amber
    case _BorderChainDifficulty.hard:
      return const Color(0xFFFF5A5F); // red
    case _BorderChainDifficulty.insane:
      return const Color(0xFF8B5CF6); // purple
  }
}

String _labelFor(_BorderChainDifficulty d) {
  switch (d) {
    case _BorderChainDifficulty.easy:
      return 'Easy';
    case _BorderChainDifficulty.medium:
      return 'Medium';
    case _BorderChainDifficulty.hard:
      return 'Hard';
    case _BorderChainDifficulty.insane:
      return 'Insane';
  }
}

String _storageKeyFor(_BorderChainDifficulty d) => 'border_chain_scores_${d.name}';

// ============================================================================
// DIFFICULTY SCREEN (entry point — the only public symbol in this file)
// ============================================================================

int _diffLevel(_BorderChainDifficulty d) {
  switch (d) {
    case _BorderChainDifficulty.easy:
      return 1;
    case _BorderChainDifficulty.medium:
      return 2;
    case _BorderChainDifficulty.hard:
      return 3;
    case _BorderChainDifficulty.insane:
      return 4;
  }
}

class BorderChainDifficultyScreen extends StatelessWidget {
  const BorderChainDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
                      gradient: const LinearGradient(colors: [Color(0xFFFF5A5F), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                   Text(tr('CHOOSE A DIFFICULTY'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: _BorderChainDifficulty.easy,
                icon: Icons.sentiment_satisfied_alt_rounded,
                onTap: () => _openLobby(context, _BorderChainDifficulty.easy),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _BorderChainDifficulty.medium,
                icon: Icons.sentiment_neutral_rounded,
                onTap: () => _openLobby(context, _BorderChainDifficulty.medium),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _BorderChainDifficulty.hard,
                icon: Icons.sentiment_very_dissatisfied_rounded,
                onTap: () => _openLobby(context, _BorderChainDifficulty.hard),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final isPremium = sub.isPremium;
                  if (isPremium) {
                    return _DifficultyCard(
                      difficulty: _BorderChainDifficulty.insane,
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => _openLobby(context, _BorderChainDifficulty.insane),
                    );
                  }
                  return FutureBuilder<bool>(
                    future: GameInsaneTrialService.instance.hasUsedTrial('border_chain'),
                    builder: (context, snapshot) {
                      final trialUsed = snapshot.data ?? false;
                      return _DifficultyCard(
                        difficulty: _BorderChainDifficulty.insane,
                        icon: Icons.local_fire_department_rounded,
                        locked: trialUsed,
                        onTap: () async {
                          if (trialUsed) {
                            SubscriptionSheet.show(context, triggerContext: 'border_chain_insane');
                          } else {
                            await GameInsaneTrialService.instance.markTrialUsed('border_chain');
                            if (context.mounted) _openLobby(context, _BorderChainDifficulty.insane);
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
              colors: [Color(0xFFFF5A5F), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.link_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(tr('BORDER PUZZLE'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
               Text(tr('Border Chain'),
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text(tr('Link neighboring countries along the shortest path. Chains get longer, decoys get sneakier.'),
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  void _openLobby(BuildContext context, _BorderChainDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _BorderChainLobbyScreen(difficulty: difficulty)),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _BorderChainDifficulty difficulty;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.icon,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final color = _accentFor(difficulty);
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
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tr(_labelFor(difficulty)),
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

/// Leaderboard + start button for one difficulty of Border Chain.
class _BorderChainLobbyScreen extends StatefulWidget {
  final _BorderChainDifficulty difficulty;

  const _BorderChainLobbyScreen({required this.difficulty});

  @override
  State<_BorderChainLobbyScreen> createState() => _BorderChainLobbyScreenState();
}

class _BorderChainLobbyScreenState extends State<_BorderChainLobbyScreen> {
  final _service = _BorderScoreService();
  late Future<List<_BorderScoreRecord>> _recordsFuture;

  Color get _accent => _accentFor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(_storageKeyFor(widget.difficulty));
    });
  }

  Future<void> _startGame() async {
    await GameAdService.instance.requestStartGame();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _BorderChainGameScreen(difficulty: widget.difficulty)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _buildLobbyHeader(),
                const SizedBox(height: 18),
                _SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _accent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.alt_route_rounded, color: _accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tr(switch (widget.difficulty) {
                            _BorderChainDifficulty.easy =>
                            'Tap a real neighbor each step. Only real borders shown. Hop count to the target is visible.',
                            _BorderChainDifficulty.medium =>
                            'Tap a real neighbor each step — but a few decoy countries are mixed in now. Hop count is visible.',
                            _BorderChainDifficulty.hard =>
                            'Still tap-to-pick, but with lots of decoys and longer chains. Hop count is visible.',
                            _BorderChainDifficulty.insane =>
                            'Search and pick any country yourself. Hop count is kept secret — just find the shortest path.',
                          }),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildHistory()),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Start Game',
                  icon: Icons.play_arrow_rounded,
                  color: _accent,
                  onPressed: _startGame,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyHeader() {
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
              colors: [_accent.withOpacity(0.85), _accent],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.link_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(tr('DIFFICULTY'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _kMuted)),
              const SizedBox(height: 2),
              Text(tr('${_labelFor(widget.difficulty)} Mode'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return FutureBuilder<List<_BorderScoreRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, size: 46, color: _kFaint),
                const SizedBox(height: 12),
                 Text(tr('No runs yet'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                const SizedBox(height: 4),
                 Text(tr('Play a round to start your leaderboard'),
                    style: TextStyle(fontSize: 12.5, color: _kMuted)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(tr('LEADERBOARD'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                Text(tr('${records.length} run${records.length == 1 ? '' : 's'}'),
                    style: const TextStyle(fontSize: 12, color: _kFaint, fontWeight: FontWeight.w600)),
              ],
            ),
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
  final _BorderScoreRecord record;

  const _RecordTile({required this.rank, required this.record});

  static const _medalColors = {1: Color(0xFFFFC93C), 2: Color(0xFFB8C1CC), 3: Color(0xFFD08A5B)};

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
            decoration: BoxDecoration(
              color: (medal ?? _kFaint).withOpacity(medal != null ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text(tr('$rank'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('${record.score} pts'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kInk)),
                const SizedBox(height: 2),
                Text(
                  tr('${record.roundsSolved}/${record.maxRounds} solved · longest path ${record.bestPathLength} · ${_formatDate(record.playedAt)}'),
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
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

enum _RoundOutcome { none, solved, wrongMove }

class _BorderChainGameScreen extends StatefulWidget {
  final _BorderChainDifficulty difficulty;

  const _BorderChainGameScreen({required this.difficulty});

  @override
  State<_BorderChainGameScreen> createState() => _BorderChainGameScreenState();
}

class _BorderChainGameScreenState extends State<_BorderChainGameScreen> {
  static const int _maxRounds = 12;

  late _RoundPuzzle _puzzle;
  final List<String> _path = []; // includes the start country
  int _roundIndex = 0;
  int _totalScore = 0;
  int _roundsSolved = 0;
  int _bestPathLength = 0;
  bool _recorded = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  _RoundOutcome _outcome = _RoundOutcome.none;
  String? _wrongPickCode;
  bool _wrongPickWasRealBorder = false;
  bool _finished = false;

  // Cached for the current hop only -- recomputed in _refreshOptions(),
  // called whenever _current changes (new round, or a successful pick).
  // Building this fresh inside build() would re-shuffle the decoys on
  // every rebuild (e.g. the once-a-second timer tick elsewhere on this
  // screen), making the options visibly jump around mid-hop.
  List<_BorderCountry> _currentOptions = [];

  /// Easy/Medium/Hard all show tap targets (with a growing number of
  /// decoys); only Insane drops to free search with the hop count hidden.
  bool get _usesTapOptions => widget.difficulty != _BorderChainDifficulty.insane;
  bool get _isEasy => _usesTapOptions; // kept for the layout code below, which only cares "tap mode vs search mode"

  _BorderCountry get _current => _kCountries[_path.last]!;
  _BorderCountry get _start => _kCountries[_puzzle.startCode]!;
  _BorderCountry get _target => _kCountries[_puzzle.targetCode]!;
  int get _remaining => _puzzle.distToTarget[_path.last] ?? -1;

  Color get _accent => _accentFor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _newRound() {
    final (minHops, maxHops, _) = _tierConfig(widget.difficulty);
    final puzzle = _RoundPuzzle.generate(
      minHops: minHops,
      maxHops: maxHops,
      // Insane doesn't show tap candidates at all, so the "only one real
      // neighbor" boredom problem this guards against doesn't apply there
      // the same way -- typing "Spain" when standing in Portugal is still
      // a genuine recall task, not a free pass.
      avoidTrivialHops: widget.difficulty != _BorderChainDifficulty.insane,
    );
    setState(() {
      _puzzle = puzzle;
      _path
        ..clear()
        ..add(puzzle.startCode);
      _outcome = _RoundOutcome.none;
      _wrongPickCode = null;
      _wrongPickWasRealBorder = false;
      _searchController.clear();
      _query = '';
    });
    _refreshOptions();
  }

  /// Recomputes the tap-mode candidate list (real neighbors + a
  /// difficulty-sized batch of decoys) for whatever country is now
  /// current. Called once per hop -- never from inside build() -- so the
  /// decoy set stays put for the whole time the player is looking at it.
  void _refreshOptions() {
    if (!_usesTapOptions) return;
    final (_, _, decoyCount) = _tierConfig(widget.difficulty);
    final realNeighbors = _current.neighbors.map((code) => _kCountries[code]!).toList();
    final decoyPool = _kCountries.values
        .where((c) => c.code != _current.code && !_current.neighbors.contains(c.code))
        .toList()
      ..shuffle();
    final decoys = decoyPool.take(decoyCount).toList();
    setState(() {
      _currentOptions = [...realNeighbors, ...decoys]..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  void _onPick(_BorderCountry picked) {
    if (_outcome != _RoundOutcome.none) return;
    // Must be BOTH a real border of the current country AND exactly one hop
    // closer to the target than the current country is. Checking distance
    // alone isn't enough once Hard mode allows picking from the full
    // country list instead of only the current country's actual neighbors —
    // a country could coincidentally be "one hop closer to the target" on
    // its own without being reachable from here in a single step.
    final isRealNeighbor = _current.neighbors.contains(picked.code);
    final targetDist = _puzzle.distToTarget[picked.code];
    final isOnShortestPath = isRealNeighbor && targetDist != null && targetDist == _remaining - 1;


    if (isOnShortestPath) {
      setState(() => _path.add(picked.code));
      if (picked.code == _puzzle.targetCode) {
        final hops = _path.length - 1;
        setState(() {
          _outcome = _RoundOutcome.solved;
          _totalScore += hops;
          _roundsSolved++;
          if (hops > _bestPathLength) _bestPathLength = hops;
        });
        _advanceAfterDelay();
      } else {
        _refreshOptions(); // moved to a new country -- get its own candidate set
      }
    } else {
      setState(() {
        _outcome = _RoundOutcome.wrongMove;
        _wrongPickCode = picked.code;
        _wrongPickWasRealBorder = isRealNeighbor;
      });
      _advanceAfterDelay();
    }
  }

  void _advanceAfterDelay() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_roundIndex + 1 >= _maxRounds) {
        _finishRun();
      } else {
        setState(() => _roundIndex++);
        _newRound();
      }
    });
  }

  void _finishRun() {
    setState(() => _finished = true);
    GameAdService.instance.notifyGameFinished();
    _saveRecord();
  }

  Future<void> _saveRecord() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _BorderScoreService().addRecord(_storageKeyFor(widget.difficulty), _BorderScoreRecord(
        score: _totalScore,
        roundsSolved: _roundsSolved,
        maxRounds: _maxRounds,
        bestPathLength: _bestPathLength,
        playedAt: DateTime.now(),
      ));
    } catch (_) {
      // Local-storage hiccups shouldn't block showing the result screen.
    }
  }

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _roundsSolved = 0;
      _bestPathLength = 0;
      _recorded = false;
      _finished = false;
    });
    _newRound();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
            Text(tr('${_labelFor(widget.difficulty)} Mode'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
        actions: _finished ? null : [_ScoreBadge(score: _totalScore)],
      ),
      body: _ScreenBackground(
        child: SafeArea(
          child: _finished ? _buildFinished() : _buildRound(),
        ),
      ),
    );
  }

  Widget _buildRound() {
    final resolved = _outcome != _RoundOutcome.none;
    // When the Hard-mode search field has focus, the keyboard eats a large
    // chunk of vertical space. The goal card + path trail were a fixed
    // height regardless, so on smaller screens the search results list
    // (which needs real room to be usable) had nowhere left to go and
    // overflowed. Collapsing the decorative bits while the keyboard is up
    // fixes it without losing any information you actually need while typing.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final compact = !_isEasy && keyboardOpen && !resolved;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('ROUND ${_roundIndex + 1} / $_maxRounds'),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              Text(
                tr(_isEasy ? 'SHORTEST PATH: ${_puzzle.shortestDistance} HOPS' : 'SHORTEST PATH: ??? HOPS'),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _accent),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            _buildGoalCard(),
            const SizedBox(height: 12),
            _buildPathTrail(),
          ],
          const SizedBox(height: 12),
          if (resolved)
            _buildResultBanner()
          else if (compact)
            _buildCompactCurrentRow()
          else
            _buildCurrentCard(),
          const SizedBox(height: 12),
          if (!resolved) ...[
            if (!compact)
              Text(
                _isEasy ? 'WHICH COUNTRY BORDERS ${_current.name.toUpperCase()}?' : 'SEARCH FOR A COUNTRY BORDERING ${_current.name.toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _kMuted),
              ),
            if (!compact) const SizedBox(height: 8),
            Expanded(child: _isEasy ? _buildNeighborOptions() : _buildSearchPicker()),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// A single-line stand-in for _buildCurrentCard() used only while the
  /// keyboard is open in Hard mode -- keeps the "which country am I
  /// searching neighbors for" context visible without the full card's height.
  Widget _buildCompactCurrentRow() {
    return Row(
      children: [
        Text(tr(_current.emoji), style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr('Searching neighbors of ${_current.name}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildEndpointChip(_start, 'START'),
          Expanded(
            child: Icon(Icons.arrow_forward_rounded, color: _accent, size: 18),
          ),
          _buildEndpointChip(_target, 'TARGET'),
        ],
      ),
    );
  }

  Widget _buildEndpointChip(_BorderCountry country, String label) {
    return Column(
      children: [
        Text(tr(country.emoji), style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 2),
        Text(tr(country.name),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kInk)),
        Text(tr(label),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _accent)),
      ],
    );
  }

  Widget _buildPathTrail() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _path.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: _kFaint),
        ),
        itemBuilder: (context, i) {
          final c = _kCountries[_path[i]]!;
          final isLast = i == _path.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isLast ? _accent.withOpacity(0.14) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isLast ? Border.all(color: _accent.withOpacity(0.4)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(c.emoji), style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(c.name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                        color: isLast ? _accent : _kMuted)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentCard() {
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Row(
        children: [
          Text(tr(_current.emoji), style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(tr('CURRENTLY IN'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: _kMuted)),
                const SizedBox(height: 2),
                Text(_current.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk)),
              ],
            ),
          ),
          if (_isEasy)
            Text(tr('$_remaining hop${_remaining == 1 ? '' : 's'} left'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
        ],
      ),
    );
  }

  Widget _buildNeighborOptions() {
    // _currentOptions is computed once per hop by _refreshOptions() --
    // never recomputed here, so it doesn't reshuffle on every rebuild.
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: _currentOptions.map((c) {
        return GestureDetector(
          onTap: () => _onPick(c),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr(c.emoji), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(c.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchPicker() {
    final path = _path.toSet();
    final q = _query.trim().toLowerCase();
    final options = _kCountries.values.where((c) => !path.contains(c.code)).where((c) {
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: tr('Search a country…'),
            prefixIcon: const Icon(Icons.search_rounded, color: _kFaint),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: options.isEmpty
              ? Center(
            child: Text(tr('No countries match "$_query"'),
                style: const TextStyle(fontSize: 13, color: _kMuted)),
          )
              : ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = options[i];
              return GestureDetector(
                onTap: () => _onPick(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(tr(c.emoji), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(c.name,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kInk)),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: _kFaint),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _wrongMoveExplanation(_BorderCountry wrongCountry) {
    if (!_wrongPickWasRealBorder) {
      return "${wrongCountry.name} doesn't even border ${_current.name} — not a valid move at all.";
    }
    if (_isEasy) {
      return "${wrongCountry.name} is a real neighbor, but it doesn't lead to ${_target.name} in $_remaining more hop${_remaining == 1 ? '' : 's'}.";
    }
    return "${wrongCountry.name} is a real neighbor, but it's not on the shortest path to ${_target.name}.";
  }

  Widget _buildResultBanner() {
    final solved = _outcome == _RoundOutcome.solved;
    final color = solved ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);
    final wrongCountry = _wrongPickCode != null ? _kCountries[_wrongPickCode]! : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(solved ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(solved ? 'Shortest path found! +${_puzzle.shortestDistance}' : 'Not the shortest path'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  if (!solved && wrongCountry != null)
                    Text(
                      tr(_wrongMoveExplanation(wrongCountry)),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished() {
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
             Text(tr('Run Complete!'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
              child: Column(children: [
                Text(tr('$_totalScore'),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                 Text(tr('TOTAL SCORE'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Solved', value: '$_roundsSolved/$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Longest', value: '$_bestPathLength'),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            _GradientButton(label: 'Play Again', color: _accent, onPressed: _retry),
            const SizedBox(height: 10),
            _GradientButton(
              label: 'Back to Lobby',
              color: _accent,
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route_rounded, size: 14, color: _kAccent),
            const SizedBox(width: 4),
            Text(tr('$score'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kAccent)),
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
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(tr(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        const SizedBox(height: 2),
        Text(tr(label.toUpperCase()),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}