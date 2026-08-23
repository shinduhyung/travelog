// lib/data/flag_guess_data.dart
//
// Static data for the "Flag Guess" mini-game.
//
// Pools:
//   - kEasyCountries    : 50 instantly-recognizable current flags (Easy).
//   - kWorldCountries   : ~160-country pool for Medium / Hard.
//   - kTrapCountries    : subset of kWorldCountries with a known lookalike.
//                         Hard biases TARGET selection toward this list (not
//                         just wrong-answer choices).
//   - kExtraFlags       : historical (defunct-state) and regional/
//                         subnational flags. Insane draws EXCLUSIVELY from
//                         this pool — no current sovereign-country flags at
//                         all. None of these have emoji support, so they're
//                         rendered from real Wikimedia Commons flag images
//                         (public-domain / CC-licensed), requested at a
//                         fixed pixel width so they render crisp instead of
//                         the browser guessing a size.

/// Difficulty tiers for Flag Guess.
enum FlagGuessDifficulty { easy, medium, hard, insane }

/// A single guessable flag.
///
/// Exactly one of these renders the flag:
///   1. [imageUrl] — a real flag image, for entries with no emoji support
///   2. [emoji] (explicit override) — the UK home-nation tag-sequence flags
///   3. derived from [code] via [countryFlagEmoji] — the default for ISO
///      3166-1 alpha-2 country codes.
///
/// [code] is an ISO 3166-1 alpha-2 code for real countries. Non-ISO entries
/// (regional/historical) use a readable pseudo-code purely as a unique id.
class FlagCountry {
  final String name;
  final String code;
  final String? imageUrl;
  final String? era;
  final String? _emojiOverride;

  const FlagCountry(this.name, this.code, {String? emoji, this.imageUrl, this.era})
      : _emojiOverride = emoji;

  /// Emoji to render, or null if this entry renders from [imageUrl] instead.
  String? get emoji {
    if (imageUrl != null) return null;
    return _emojiOverride ?? countryFlagEmoji(code);
  }

  bool get hasImage => imageUrl != null;
}

/// Converts an ISO 3166-1 alpha-2 code (e.g. "JP") into its flag emoji (🇯🇵).
/// Only valid for real 2-letter country codes.
String countryFlagEmoji(String isoCode) {
  final code = isoCode.toUpperCase();
  if (code.length != 2) return '🏳️';
  final first = 0x1F1E6 + (code.codeUnitAt(0) - 0x41);
  final second = 0x1F1E6 + (code.codeUnitAt(1) - 0x41);
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// Stable Wikimedia Commons image link for a file title (e.g. "Flag of the
/// Soviet Union.svg"), requested at a fixed pixel width so Commons returns a
/// crisp rasterized thumbnail (Flutter's Image widget can't decode SVG
/// directly — this asks Commons to do it server-side) instead of leaving
/// the client to stretch a low-res fallback. Special:FilePath also always
/// resolves to the current file regardless of the underlying hashed storage
/// path, so this doesn't go stale like a direct upload.wikimedia.org link.
String _commons(String fileTitle, {int width = 480}) {
  final encoded = Uri.encodeComponent(fileTitle.replaceAll(' ', '_'));
  return 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=$width';
}

// ── Easy: 50 instantly-recognizable flags ──────────────────────────────────
const List<FlagCountry> kEasyCountries = [
  FlagCountry('Japan', 'JP'),
  FlagCountry('United States', 'US'),
  FlagCountry('United Kingdom', 'GB'),
  FlagCountry('France', 'FR'),
  FlagCountry('Germany', 'DE'),
  FlagCountry('Italy', 'IT'),
  FlagCountry('Spain', 'ES'),
  FlagCountry('Portugal', 'PT'),
  FlagCountry('Brazil', 'BR'),
  FlagCountry('Argentina', 'AR'),
  FlagCountry('Canada', 'CA'),
  FlagCountry('Mexico', 'MX'),
  FlagCountry('China', 'CN'),
  FlagCountry('South Korea', 'KR'),
  FlagCountry('India', 'IN'),
  FlagCountry('Russia', 'RU'),
  FlagCountry('Australia', 'AU'),
  FlagCountry('New Zealand', 'NZ'),
  FlagCountry('South Africa', 'ZA'),
  FlagCountry('Egypt', 'EG'),
  FlagCountry('Turkey', 'TR'),
  FlagCountry('Greece', 'GR'),
  FlagCountry('Sweden', 'SE'),
  FlagCountry('Norway', 'NO'),
  FlagCountry('Denmark', 'DK'),
  FlagCountry('Finland', 'FI'),
  FlagCountry('Switzerland', 'CH'),
  FlagCountry('Austria', 'AT'),
  FlagCountry('Netherlands', 'NL'),
  FlagCountry('Belgium', 'BE'),
  FlagCountry('Poland', 'PL'),
  FlagCountry('Ukraine', 'UA'),
  FlagCountry('Israel', 'IL'),
  FlagCountry('Saudi Arabia', 'SA'),
  FlagCountry('United Arab Emirates', 'AE'),
  FlagCountry('Pakistan', 'PK'),
  FlagCountry('Bangladesh', 'BD'),
  FlagCountry('Thailand', 'TH'),
  FlagCountry('Vietnam', 'VN'),
  FlagCountry('Philippines', 'PH'),
  FlagCountry('Malaysia', 'MY'),
  FlagCountry('Singapore', 'SG'),
  FlagCountry('Indonesia', 'ID'),
  FlagCountry('Nigeria', 'NG'),
  FlagCountry('Kenya', 'KE'),
  FlagCountry('Morocco', 'MA'),
  FlagCountry('Algeria', 'DZ'),
  FlagCountry('Colombia', 'CO'),
  FlagCountry('Chile', 'CL'),
  FlagCountry('Peru', 'PE'),
];

// ── World pool: Medium / Hard draw from here ────────────────────────────────
const List<FlagCountry> _additionalWorldCountries = [
  // Africa
  FlagCountry('Ethiopia', 'ET'),
  FlagCountry('Ghana', 'GH'),
  FlagCountry('Tanzania', 'TZ'),
  FlagCountry('Uganda', 'UG'),
  FlagCountry('Zambia', 'ZM'),
  FlagCountry('Zimbabwe', 'ZW'),
  FlagCountry('Botswana', 'BW'),
  FlagCountry('Namibia', 'NA'),
  FlagCountry('Angola', 'AO'),
  FlagCountry('Mozambique', 'MZ'),
  FlagCountry('Cameroon', 'CM'),
  FlagCountry('DR Congo', 'CD'),
  FlagCountry('Congo', 'CG'),
  FlagCountry('Rwanda', 'RW'),
  FlagCountry('Somalia', 'SO'),
  FlagCountry('Ivory Coast', 'CI'),
  FlagCountry('Senegal', 'SN'),
  FlagCountry('Mali', 'ML'),
  FlagCountry('Guinea', 'GN'),
  FlagCountry('Benin', 'BJ'),
  FlagCountry('Togo', 'TG'),
  FlagCountry('Sierra Leone', 'SL'),
  FlagCountry('Gambia', 'GM'),
  FlagCountry('Guinea-Bissau', 'GW'),
  FlagCountry('Burkina Faso', 'BF'),
  FlagCountry('Cape Verde', 'CV'),
  FlagCountry('Eswatini', 'SZ'),
  FlagCountry('Lesotho', 'LS'),
  FlagCountry('Madagascar', 'MG'),
  FlagCountry('Mauritius', 'MU'),
  FlagCountry('Seychelles', 'SC'),
  FlagCountry('Comoros', 'KM'),
  FlagCountry('Djibouti', 'DJ'),
  FlagCountry('Eritrea', 'ER'),
  FlagCountry('South Sudan', 'SS'),
  FlagCountry('Central African Republic', 'CF'),
  FlagCountry('Gabon', 'GA'),
  FlagCountry('Equatorial Guinea', 'GQ'),
  FlagCountry('Sao Tome and Principe', 'ST'),
  FlagCountry('Malawi', 'MW'),
  FlagCountry('Chad', 'TD'),
  FlagCountry('Niger', 'NE'),
  FlagCountry('Tunisia', 'TN'),
  FlagCountry('Libya', 'LY'),
  FlagCountry('Sudan', 'SD'),
  // Middle East / Central Asia
  FlagCountry('Kazakhstan', 'KZ'),
  FlagCountry('Uzbekistan', 'UZ'),
  FlagCountry('Turkmenistan', 'TM'),
  FlagCountry('Kyrgyzstan', 'KG'),
  FlagCountry('Tajikistan', 'TJ'),
  FlagCountry('Mongolia', 'MN'),
  FlagCountry('Afghanistan', 'AF'),
  FlagCountry('Iran', 'IR'),
  FlagCountry('Iraq', 'IQ'),
  FlagCountry('Syria', 'SY'),
  FlagCountry('Lebanon', 'LB'),
  FlagCountry('Jordan', 'JO'),
  FlagCountry('Kuwait', 'KW'),
  FlagCountry('Qatar', 'QA'),
  FlagCountry('Bahrain', 'BH'),
  FlagCountry('Oman', 'OM'),
  FlagCountry('Yemen', 'YE'),
  FlagCountry('Georgia', 'GE'),
  FlagCountry('Armenia', 'AM'),
  FlagCountry('Azerbaijan', 'AZ'),
  // South / Southeast / East Asia
  FlagCountry('Nepal', 'NP'),
  FlagCountry('Sri Lanka', 'LK'),
  FlagCountry('Myanmar', 'MM'),
  FlagCountry('Cambodia', 'KH'),
  FlagCountry('Laos', 'LA'),
  FlagCountry('Brunei', 'BN'),
  FlagCountry('Timor-Leste', 'TL'),
  FlagCountry('North Korea', 'KP'),
  FlagCountry('Taiwan', 'TW'),
  FlagCountry('Bhutan', 'BT'),
  FlagCountry('Maldives', 'MV'),
  // Europe
  FlagCountry('Romania', 'RO'),
  FlagCountry('Bulgaria', 'BG'),
  FlagCountry('Hungary', 'HU'),
  FlagCountry('Czech Republic', 'CZ'),
  FlagCountry('Slovakia', 'SK'),
  FlagCountry('Slovenia', 'SI'),
  FlagCountry('Croatia', 'HR'),
  FlagCountry('Serbia', 'RS'),
  FlagCountry('Bosnia and Herzegovina', 'BA'),
  FlagCountry('Albania', 'AL'),
  FlagCountry('North Macedonia', 'MK'),
  FlagCountry('Montenegro', 'ME'),
  FlagCountry('Lithuania', 'LT'),
  FlagCountry('Latvia', 'LV'),
  FlagCountry('Estonia', 'EE'),
  FlagCountry('Belarus', 'BY'),
  FlagCountry('Moldova', 'MD'),
  FlagCountry('Iceland', 'IS'),
  FlagCountry('Ireland', 'IE'),
  FlagCountry('Luxembourg', 'LU'),
  FlagCountry('Monaco', 'MC'),
  FlagCountry('Malta', 'MT'),
  FlagCountry('Cyprus', 'CY'),
  // Americas
  FlagCountry('Guatemala', 'GT'),
  FlagCountry('Belize', 'BZ'),
  FlagCountry('Honduras', 'HN'),
  FlagCountry('El Salvador', 'SV'),
  FlagCountry('Nicaragua', 'NI'),
  FlagCountry('Costa Rica', 'CR'),
  FlagCountry('Panama', 'PA'),
  FlagCountry('Cuba', 'CU'),
  FlagCountry('Dominican Republic', 'DO'),
  FlagCountry('Haiti', 'HT'),
  FlagCountry('Jamaica', 'JM'),
  FlagCountry('Trinidad and Tobago', 'TT'),
  FlagCountry('Bahamas', 'BS'),
  FlagCountry('Barbados', 'BB'),
  FlagCountry('Bolivia', 'BO'),
  FlagCountry('Paraguay', 'PY'),
  FlagCountry('Uruguay', 'UY'),
  FlagCountry('Venezuela', 'VE'),
  FlagCountry('Ecuador', 'EC'),
  FlagCountry('Guyana', 'GY'),
  FlagCountry('Suriname', 'SR'),
  FlagCountry('Liberia', 'LR'),
  // Oceania
  FlagCountry('Fiji', 'FJ'),
  FlagCountry('Papua New Guinea', 'PG'),
];

/// Full country pool for Medium / Hard, de-duplicated by code.
final List<FlagCountry> kWorldCountries = () {
  final byCode = <String, FlagCountry>{
    for (final c in kEasyCountries) c.code: c,
    for (final c in _additionalWorldCountries) c.code: c,
  };
  return byCode.values.toList();
}();

// ── Trap flags: countries with a well-known lookalike (Hard only) ──────────
const Map<String, List<String>> kSimilarFlagGroups = {
  'TD': ['RO', 'MD'],
  'RO': ['TD', 'MD'],
  'MD': ['RO', 'TD'],
  'MC': ['ID', 'PL'],
  'ID': ['MC', 'PL'],
  'PL': ['ID', 'MC'],
  'IE': ['CI'],
  'CI': ['IE'],
  'NL': ['LU'],
  'LU': ['NL'],
  'NZ': ['AU'],
  'AU': ['NZ'],
  'SI': ['SK', 'RU'],
  'SK': ['SI'],
  'RU': ['SI'],
  'CO': ['EC', 'VE'],
  'EC': ['CO', 'VE'],
  'VE': ['CO', 'EC'],
  'ML': ['SN', 'GN'],
  'SN': ['ML', 'GN'],
  'GN': ['ML', 'SN'],
  'QA': ['BH'],
  'BH': ['QA'],
  'NE': ['IN'],
  'IN': ['NE'],
  'NI': ['SV', 'HN'],
  'SV': ['NI', 'HN'],
  'HN': ['NI', 'SV'],
  'MY': ['US'],
  'US': ['MY', 'LR'],
  'LR': ['US'],
  'YE': ['EG', 'SY', 'IQ'],
  'EG': ['YE', 'SY', 'IQ'],
  'SY': ['YE', 'EG', 'IQ'],
  'IQ': ['YE', 'EG', 'SY'],
  'NO': ['IS'],
  'IS': ['NO'],
  'HU': ['BG'],
  'BG': ['HU'],
};

/// Countries that appear as a key in [kSimilarFlagGroups] — the pool Hard
/// samples from first when building the round order.
final List<FlagCountry> kTrapCountries = kSimilarFlagGroups.keys
    .map((code) => kWorldCountries.firstWhere((c) => c.code == code))
    .toList();

// ── Regional flags with real emoji support ──────────────────────────────────
// Unicode "tag sequence" subdivision flags — genuinely supported by major
// platforms, unlike arbitrary ISO 3166-2 codes (which mostly render as a
// plain black flag).
const List<FlagCountry> kRegionalEmojiFlags = [
  FlagCountry('England', 'GB-ENG',
      emoji: '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}'),
  FlagCountry('Scotland', 'GB-SCT',
      emoji: '\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}'),
  FlagCountry('Wales', 'GB-WLS',
      emoji: '\u{1F3F4}\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}'),
];

// ── Historical (defunct-state) flags — Insane only ──────────────────────────
// No emoji exists for any of these — rendered from real Wikimedia Commons
// images (public-domain / CC-licensed national-flag files).
final List<FlagCountry> kHistoricalFlags = [
  FlagCountry('Soviet Union', 'HIST-USSR',
      imageUrl: _commons('Flag of the Soviet Union.svg'), era: '1922–1991'),
  FlagCountry('German Empire', 'HIST-DE-EMPIRE',
      imageUrl: _commons('Flag of the German Empire.svg'), era: '1871–1918'),
  FlagCountry('East Germany', 'HIST-DDR',
      imageUrl: _commons('Flag of East Germany.svg'), era: '1949–1990'),
  FlagCountry('Austria-Hungary', 'HIST-AUHU',
      imageUrl: _commons('Flag of Austria-Hungary (1869-1918).svg'), era: '1867–1918'),
  FlagCountry('Austrian Empire', 'HIST-AT-EMPIRE',
      imageUrl: _commons('Flag of the Habsburg Monarchy.svg'), era: '1804–1867'),
  FlagCountry('Ottoman Empire', 'HIST-OTTOMAN',
      imageUrl: _commons('Flag of the Ottoman Empire.svg'), era: '1844–1922'),
  FlagCountry('Kingdom of Hawaii', 'HIST-HAWAII',
      imageUrl: _commons('Flag of Hawaii.svg'), era: '1845–1893'),
  FlagCountry('Republic of Texas', 'HIST-TEXAS',
      imageUrl: _commons('Flag of Texas.svg'), era: '1836–1845'),
  FlagCountry('Tibet', 'HIST-TIBET',
      imageUrl: _commons('Flag of Tibet.svg'), era: 'de facto 1912–1951'),
  FlagCountry('Yugoslavia (SFRY)', 'HIST-YUGO',
      imageUrl: _commons('Flag of Yugoslavia (1946-1992).svg'), era: '1946–1992'),
  FlagCountry('Czechoslovakia', 'HIST-CZS',
      imageUrl: _commons('Flag of Czechoslovakia.svg'), era: '1918–1992'),
  FlagCountry('Kingdom of Italy', 'HIST-ITALY-KGD',
      imageUrl: _commons('Flag of Italy (1861-1946).svg'), era: '1861–1946'),
  FlagCountry('Kingdom of Prussia', 'HIST-PRUSSIA',
      imageUrl: _commons('Flag of the Kingdom of Prussia (1892-1918).svg'), era: '1701–1918'),
  FlagCountry('Manchukuo', 'HIST-MANCHUKUO',
      imageUrl: _commons('Flag of Manchukuo.svg'), era: '1932–1945'),
  FlagCountry('Republic of China (early)', 'HIST-ROC-EARLY',
      imageUrl: _commons('Flag of the Republic of China (1912-1928).svg'), era: '1912–1928'),
  FlagCountry('South Vietnam', 'HIST-SVIETNAM',
      imageUrl: _commons('Flag of South Vietnam.svg'), era: '1955–1975'),
  FlagCountry('United Arab Republic', 'HIST-UAR',
      imageUrl: _commons('Flag of the United Arab Republic.svg'), era: '1958–1961'),
  FlagCountry('Zaire', 'HIST-ZAIRE',
      imageUrl: _commons('Flag of Zaire (1971–1997).svg'), era: '1971–1997'),
  FlagCountry('Rhodesia', 'HIST-RHODESIA',
      imageUrl: _commons('Flag of Rhodesia.svg'), era: '1965–1979'),
  FlagCountry('Empire of Brazil', 'HIST-BRAZIL-EMPIRE',
      imageUrl: _commons('Flag of the Empire of Brazil (1870-1889).svg'), era: '1822–1889'),
];

// ── Current subnational / territorial flags without emoji support ──────────
// Insane only. Apolitical, well-documented regional and territorial flags.
final List<FlagCountry> kRegionalImageFlags = [
  FlagCountry('Bavaria', 'REG-BAVARIA', imageUrl: _commons('Flag of Bavaria (striped).svg')),
  FlagCountry('Hong Kong', 'REG-HK', imageUrl: _commons('Flag of Hong Kong.svg')),
  FlagCountry('Sicily', 'REG-SICILY', imageUrl: _commons('Flag of Sicily.svg')),
  FlagCountry('Quebec', 'REG-QUEBEC', imageUrl: _commons('Flag of Quebec.svg')),
  FlagCountry('Greenland', 'REG-GREENLAND', imageUrl: _commons('Flag of Greenland.svg')),
  FlagCountry('Faroe Islands', 'REG-FAROE', imageUrl: _commons('Flag of the Faroe Islands.svg')),
  FlagCountry('Bermuda', 'REG-BERMUDA', imageUrl: _commons('Flag of Bermuda.svg')),
  FlagCountry('Gibraltar', 'REG-GIBRALTAR', imageUrl: _commons('Flag of Gibraltar.svg')),
  FlagCountry('Isle of Man', 'REG-IOM', imageUrl: _commons('Flag of the Isle of Man.svg')),
  FlagCountry('Puerto Rico', 'REG-PR', imageUrl: _commons('Flag of Puerto Rico.svg')),
  FlagCountry('Guam', 'REG-GUAM', imageUrl: _commons('Flag of Guam.svg')),
  FlagCountry('American Samoa', 'REG-ASAMOA', imageUrl: _commons('Flag of American Samoa.svg')),
  FlagCountry('Åland Islands', 'REG-ALAND', imageUrl: _commons('Flag of Åland.svg')),
  FlagCountry('Sardinia', 'REG-SARDINIA', imageUrl: _commons('Flag of Sardinia.svg')),
  FlagCountry('Corsica', 'REG-CORSICA', imageUrl: _commons('Flag of Corsica.svg')),
  FlagCountry('Saxony', 'REG-SAXONY', imageUrl: _commons('Flag of Saxony.svg')),
  FlagCountry('Cornwall', 'REG-CORNWALL', imageUrl: _commons('Flag of Cornwall.svg')),
];

/// Every flag Insane can draw from — historical + regional, and ONLY that;
/// no current sovereign-country flags are mixed in at all.
final List<FlagCountry> kExtraFlags = [
  ...kRegionalEmojiFlags,
  ...kHistoricalFlags,
  ...kRegionalImageFlags,
];

/// All guessable flags across every tier, de-duplicated by code.
final Map<String, FlagCountry> kAllCountriesByCode = {
  for (final c in [...kWorldCountries, ...kExtraFlags]) c.code: c,
};

/// Static reference pool for a difficulty (unordered). For actual gameplay
/// round order, use [buildRoundOrder].
List<FlagCountry> countriesForDifficulty(FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case FlagGuessDifficulty.easy:
      return kEasyCountries;
    case FlagGuessDifficulty.medium:
    case FlagGuessDifficulty.hard:
      return kWorldCountries;
    case FlagGuessDifficulty.insane:
      return kExtraFlags;
  }
}

/// The pool wrong-answer choices are drawn from for a difficulty.
List<FlagCountry> distractorPoolFor(FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case FlagGuessDifficulty.easy:
      return kEasyCountries;
    case FlagGuessDifficulty.medium:
    case FlagGuessDifficulty.hard:
      return kWorldCountries;
    case FlagGuessDifficulty.insane:
      return kExtraFlags;
  }
}

/// Builds the ordered list of flags a round will draw from, one per index.
///   - Easy/Medium: a plain shuffle of their pool.
///   - Hard: every known trap country first (shuffled among themselves),
///     then the rest of the world pool — so trap flags actually get asked
///     about, not just offered as wrong answers.
///   - Insane: historical + regional flags ONLY, shuffled — never a current
///     country.
List<FlagCountry> buildRoundOrder(FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case FlagGuessDifficulty.easy:
      return (List<FlagCountry>.from(kEasyCountries)..shuffle());
    case FlagGuessDifficulty.medium:
      return (List<FlagCountry>.from(kWorldCountries)..shuffle());
    case FlagGuessDifficulty.hard:
      final traps = List<FlagCountry>.from(kTrapCountries)..shuffle();
      final rest = kWorldCountries
          .where((c) => !traps.any((t) => t.code == c.code))
          .toList()
        ..shuffle();
      return [...traps, ...rest];
    case FlagGuessDifficulty.insane:
      return (List<FlagCountry>.from(kExtraFlags)..shuffle());
  }
}