// lib/games/flag_guess.dart
//
// Self-contained "Flag Guess" mini-game.
//
// Everything the game needs -- data (country/flag pools, trap pairings,
// historical & regional flags), local score persistence, a small shared UI
// kit, and all three screens (difficulty picker, lobby/leaderboard, and the
// game itself) -- lives in this single file.
//
// The ONLY public symbol is [FlagGuessDifficultyScreen]; everything else is
// private to this library (leading underscore) on purpose, so this file
// never collides with any other game file even if several are imported into
// the same place. To add this game somewhere, just:
//
//   import 'package:jidoapp/games/flag_guess.dart';
//   ...
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => const FlagGuessDifficultyScreen(),
//   ));
//
// Dependencies: providers, shared_preferences (see pubspec.yaml).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';
import 'package:jidoapp/services/game_insane_trial_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// ============================================================================
// DATA
// ============================================================================

enum _FlagGuessDifficulty { easy, medium, hard, insane }

/// A single guessable flag.
///
/// Rendering priority:
///   1. [assetPath] — a bundled local image (assets/...), the most reliable
///      option: no network dependency, always loads instantly. This is
///      what you want to fill in once you've saved your own copies of the
///      historical/regional flags.
///   2. [imageUrl] — a real flag image fetched over the network, used for
///      entries with no emoji support that don't have a bundled asset yet.
///   3. [emoji] (explicit override) — the UK home-nation tag-sequence flags.
///   4. derived from [code] via [_countryFlagEmoji] — the default for ISO
///      3166-1 alpha-2 country codes.
///
/// [code] is an ISO 3166-1 alpha-2 code for real countries. Non-ISO entries
/// (regional/historical) use a readable pseudo-code purely as a unique id.
class _FlagCountry {
  final String name;
  final String code;
  final String? assetPath;
  final String? imageUrl;
  final String? era;
  final String? _emojiOverride;

  const _FlagCountry(this.name, this.code,
      {String? emoji, this.assetPath, this.imageUrl, this.era})
      : _emojiOverride = emoji;

  /// Emoji to render, or null if this entry renders from an image instead.
  String? get emoji {
    if (assetPath != null || imageUrl != null) return null;
    return _emojiOverride ?? _countryFlagEmoji(code);
  }

  /// Always computes an emoji, even for entries that normally render from
  /// an image — used as the LAST-resort fallback when both the local
  /// asset and the network image fail to load (e.g. a mistyped/renamed
  /// Wikimedia Commons file title), so a bad image never shows a broken
  /// icon when a perfectly good emoji flag was available all along.
  String get emojiFallback => _emojiOverride ?? _countryFlagEmoji(code);

  bool get hasImage => assetPath != null || imageUrl != null;

  /// True once a bundled local copy exists — [_FlagGuessGameScreen] uses
  /// this to skip the network image entirely rather than falling back to it.
  bool get hasLocalAsset => assetPath != null;
}

/// Converts an ISO 3166-1 alpha-2 code (e.g. "JP") into its flag emoji (🇯🇵).
/// Only valid for real 2-letter country codes.
String _countryFlagEmoji(String isoCode) {
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
final List<_FlagCountry> _kEasyCountries = [
  _FlagCountry('Japan', 'JP',
      assetPath: 'assets/images/flags/JP.png', imageUrl: _commons('Flag of Japan.svg')),
  _FlagCountry('United States', 'US',
      assetPath: 'assets/images/flags/US.png', imageUrl: _commons('Flag of the United States.svg')),
  _FlagCountry('United Kingdom', 'GB',
      assetPath: 'assets/images/flags/GB.png', imageUrl: _commons('Flag of the United Kingdom.svg')),
  _FlagCountry('France', 'FR',
      assetPath: 'assets/images/flags/FR.png', imageUrl: _commons('Flag of France.svg')),
  _FlagCountry('Germany', 'DE',
      assetPath: 'assets/images/flags/DE.png', imageUrl: _commons('Flag of Germany.svg')),
  _FlagCountry('Italy', 'IT',
      assetPath: 'assets/images/flags/IT.png', imageUrl: _commons('Flag of Italy.svg')),
  _FlagCountry('Spain', 'ES',
      assetPath: 'assets/images/flags/ES.png', imageUrl: _commons('Flag of Spain.svg')),
  _FlagCountry('Portugal', 'PT',
      assetPath: 'assets/images/flags/PT.png', imageUrl: _commons('Flag of Portugal.svg')),
  _FlagCountry('Brazil', 'BR',
      assetPath: 'assets/images/flags/BR.png', imageUrl: _commons('Flag of Brazil.svg')),
  _FlagCountry('Argentina', 'AR',
      assetPath: 'assets/images/flags/AR.png', imageUrl: _commons('Flag of Argentina.svg')),
  _FlagCountry('Canada', 'CA',
      assetPath: 'assets/images/flags/CA.png', imageUrl: _commons('Flag of Canada.svg')),
  _FlagCountry('Mexico', 'MX',
      assetPath: 'assets/images/flags/MX.png', imageUrl: _commons('Flag of Mexico.svg')),
  _FlagCountry('China', 'CN',
      assetPath: 'assets/images/flags/CN.png', imageUrl: _commons('Flag of China.svg')),
  _FlagCountry('South Korea', 'KR',
      assetPath: 'assets/images/flags/KR.png', imageUrl: _commons('Flag of South Korea.svg')),
  _FlagCountry('India', 'IN',
      assetPath: 'assets/images/flags/IN.png', imageUrl: _commons('Flag of India.svg')),
  _FlagCountry('Russia', 'RU',
      assetPath: 'assets/images/flags/RU.png', imageUrl: _commons('Flag of Russia.svg')),
  _FlagCountry('Australia', 'AU',
      assetPath: 'assets/images/flags/AU.png', imageUrl: _commons('Flag of Australia.svg')),
  _FlagCountry('New Zealand', 'NZ',
      assetPath: 'assets/images/flags/NZ.png', imageUrl: _commons('Flag of New Zealand.svg')),
  _FlagCountry('South Africa', 'ZA',
      assetPath: 'assets/images/flags/ZA.png', imageUrl: _commons('Flag of South Africa.svg')),
  _FlagCountry('Egypt', 'EG',
      assetPath: 'assets/images/flags/EG.png', imageUrl: _commons('Flag of Egypt.svg')),
  _FlagCountry('Turkey', 'TR',
      assetPath: 'assets/images/flags/TR.png', imageUrl: _commons('Flag of Turkey.svg')),
  _FlagCountry('Greece', 'GR',
      assetPath: 'assets/images/flags/GR.png', imageUrl: _commons('Flag of Greece.svg')),
  _FlagCountry('Sweden', 'SE',
      assetPath: 'assets/images/flags/SE.png', imageUrl: _commons('Flag of Sweden.svg')),
  _FlagCountry('Norway', 'NO',
      assetPath: 'assets/images/flags/NO.png', imageUrl: _commons('Flag of Norway.svg')),
  _FlagCountry('Denmark', 'DK',
      assetPath: 'assets/images/flags/DK.png', imageUrl: _commons('Flag of Denmark.svg')),
  _FlagCountry('Finland', 'FI',
      assetPath: 'assets/images/flags/FI.png', imageUrl: _commons('Flag of Finland.svg')),
  _FlagCountry('Switzerland', 'CH',
      assetPath: 'assets/images/flags/CH.png', imageUrl: _commons('Flag of Switzerland.svg')),
  _FlagCountry('Austria', 'AT',
      assetPath: 'assets/images/flags/AT.png', imageUrl: _commons('Flag of Austria.svg')),
  _FlagCountry('Netherlands', 'NL',
      assetPath: 'assets/images/flags/NL.png', imageUrl: _commons('Flag of the Netherlands.svg')),
  _FlagCountry('Belgium', 'BE',
      assetPath: 'assets/images/flags/BE.png', imageUrl: _commons('Flag of Belgium.svg')),
  _FlagCountry('Poland', 'PL',
      assetPath: 'assets/images/flags/PL.png', imageUrl: _commons('Flag of Poland.svg')),
  _FlagCountry('Ukraine', 'UA',
      assetPath: 'assets/images/flags/UA.png', imageUrl: _commons('Flag of Ukraine.svg')),
  _FlagCountry('Israel', 'IL',
      assetPath: 'assets/images/flags/IL.png', imageUrl: _commons('Flag of Israel.svg')),
  _FlagCountry('Saudi Arabia', 'SA',
      assetPath: 'assets/images/flags/SA.png', imageUrl: _commons('Flag of Saudi Arabia.svg')),
  _FlagCountry('United Arab Emirates', 'AE',
      assetPath: 'assets/images/flags/AE.png', imageUrl: _commons('Flag of the United Arab Emirates.svg')),
  _FlagCountry('Pakistan', 'PK',
      assetPath: 'assets/images/flags/PK.png', imageUrl: _commons('Flag of Pakistan.svg')),
  _FlagCountry('Bangladesh', 'BD',
      assetPath: 'assets/images/flags/BD.png', imageUrl: _commons('Flag of Bangladesh.svg')),
  _FlagCountry('Thailand', 'TH',
      assetPath: 'assets/images/flags/TH.png', imageUrl: _commons('Flag of Thailand.svg')),
  _FlagCountry('Vietnam', 'VN',
      assetPath: 'assets/images/flags/VN.png', imageUrl: _commons('Flag of Vietnam.svg')),
  _FlagCountry('Philippines', 'PH',
      assetPath: 'assets/images/flags/PH.png', imageUrl: _commons('Flag of the Philippines.svg')),
  _FlagCountry('Malaysia', 'MY',
      assetPath: 'assets/images/flags/MY.png', imageUrl: _commons('Flag of Malaysia.svg')),
  _FlagCountry('Singapore', 'SG',
      assetPath: 'assets/images/flags/SG.png', imageUrl: _commons('Flag of Singapore.svg')),
  _FlagCountry('Indonesia', 'ID',
      assetPath: 'assets/images/flags/ID.png', imageUrl: _commons('Flag of Indonesia.svg')),
  _FlagCountry('Nigeria', 'NG',
      assetPath: 'assets/images/flags/NG.png', imageUrl: _commons('Flag of Nigeria.svg')),
  _FlagCountry('Kenya', 'KE',
      assetPath: 'assets/images/flags/KE.png', imageUrl: _commons('Flag of Kenya.svg')),
  _FlagCountry('Morocco', 'MA',
      assetPath: 'assets/images/flags/MA.png', imageUrl: _commons('Flag of Morocco.svg')),
  _FlagCountry('Algeria', 'DZ',
      assetPath: 'assets/images/flags/DZ.png', imageUrl: _commons('Flag of Algeria.svg')),
  _FlagCountry('Colombia', 'CO',
      assetPath: 'assets/images/flags/CO.png', imageUrl: _commons('Flag of Colombia.svg')),
  _FlagCountry('Chile', 'CL',
      assetPath: 'assets/images/flags/CL.png', imageUrl: _commons('Flag of Chile.svg')),
  _FlagCountry('Peru', 'PE',
      assetPath: 'assets/images/flags/PE.png', imageUrl: _commons('Flag of Peru.svg')),
];

// ── World pool: Medium / Hard draw from here ────────────────────────────────
final List<_FlagCountry> _additionalWorldCountries = [
  // Africa
  _FlagCountry('Ethiopia', 'ET',
      assetPath: 'assets/images/flags/ET.png', imageUrl: _commons('Flag of Ethiopia.svg')),
  _FlagCountry('Ghana', 'GH',
      assetPath: 'assets/images/flags/GH.png', imageUrl: _commons('Flag of Ghana.svg')),
  _FlagCountry('Tanzania', 'TZ',
      assetPath: 'assets/images/flags/TZ.png', imageUrl: _commons('Flag of Tanzania.svg')),
  _FlagCountry('Uganda', 'UG',
      assetPath: 'assets/images/flags/UG.png', imageUrl: _commons('Flag of Uganda.svg')),
  _FlagCountry('Zambia', 'ZM',
      assetPath: 'assets/images/flags/ZM.png', imageUrl: _commons('Flag of Zambia.svg')),
  _FlagCountry('Zimbabwe', 'ZW',
      assetPath: 'assets/images/flags/ZW.png', imageUrl: _commons('Flag of Zimbabwe.svg')),
  _FlagCountry('Botswana', 'BW',
      assetPath: 'assets/images/flags/BW.png', imageUrl: _commons('Flag of Botswana.svg')),
  _FlagCountry('Namibia', 'NA',
      assetPath: 'assets/images/flags/NA.png', imageUrl: _commons('Flag of Namibia.svg')),
  _FlagCountry('Angola', 'AO',
      assetPath: 'assets/images/flags/AO.png', imageUrl: _commons('Flag of Angola.svg')),
  _FlagCountry('Mozambique', 'MZ',
      assetPath: 'assets/images/flags/MZ.png', imageUrl: _commons('Flag of Mozambique.svg')),
  _FlagCountry('Cameroon', 'CM',
      assetPath: 'assets/images/flags/CM.png', imageUrl: _commons('Flag of Cameroon.svg')),
  _FlagCountry('DR Congo', 'CD',
      assetPath: 'assets/images/flags/CD.png', imageUrl: _commons('Flag of the Democratic Republic of the Congo.svg')),
  _FlagCountry('Congo', 'CG',
      assetPath: 'assets/images/flags/CG.png', imageUrl: _commons('Flag of the Republic of the Congo.svg')),
  _FlagCountry('Rwanda', 'RW',
      assetPath: 'assets/images/flags/RW.png', imageUrl: _commons('Flag of Rwanda.svg')),
  _FlagCountry('Somalia', 'SO',
      assetPath: 'assets/images/flags/SO.png', imageUrl: _commons('Flag of Somalia.svg')),
  _FlagCountry('Ivory Coast', 'CI',
      assetPath: 'assets/images/flags/CI.png', imageUrl: _commons('Flag of Côte d\'Ivoire.svg')),
  _FlagCountry('Senegal', 'SN',
      assetPath: 'assets/images/flags/SN.png', imageUrl: _commons('Flag of Senegal.svg')),
  _FlagCountry('Mali', 'ML',
      assetPath: 'assets/images/flags/ML.png', imageUrl: _commons('Flag of Mali.svg')),
  _FlagCountry('Guinea', 'GN',
      assetPath: 'assets/images/flags/GN.png', imageUrl: _commons('Flag of Guinea.svg')),
  _FlagCountry('Benin', 'BJ',
      assetPath: 'assets/images/flags/BJ.png', imageUrl: _commons('Flag of Benin.svg')),
  _FlagCountry('Togo', 'TG',
      assetPath: 'assets/images/flags/TG.png', imageUrl: _commons('Flag of Togo.svg')),
  _FlagCountry('Sierra Leone', 'SL',
      assetPath: 'assets/images/flags/SL.png', imageUrl: _commons('Flag of Sierra Leone.svg')),
  _FlagCountry('Gambia', 'GM',
      assetPath: 'assets/images/flags/GM.png', imageUrl: _commons('Flag of the Gambia.svg')),
  _FlagCountry('Guinea-Bissau', 'GW',
      assetPath: 'assets/images/flags/GW.png', imageUrl: _commons('Flag of Guinea-Bissau.svg')),
  _FlagCountry('Burkina Faso', 'BF',
      assetPath: 'assets/images/flags/BF.png', imageUrl: _commons('Flag of Burkina Faso.svg')),
  _FlagCountry('Cape Verde', 'CV',
      assetPath: 'assets/images/flags/CV.png', imageUrl: _commons('Flag of Cape Verde.svg')),
  _FlagCountry('Eswatini', 'SZ',
      assetPath: 'assets/images/flags/SZ.png', imageUrl: _commons('Flag of Eswatini.svg')),
  _FlagCountry('Lesotho', 'LS',
      assetPath: 'assets/images/flags/LS.png', imageUrl: _commons('Flag of Lesotho.svg')),
  _FlagCountry('Madagascar', 'MG',
      assetPath: 'assets/images/flags/MG.png', imageUrl: _commons('Flag of Madagascar.svg')),
  _FlagCountry('Mauritius', 'MU',
      assetPath: 'assets/images/flags/MU.png', imageUrl: _commons('Flag of Mauritius.svg')),
  _FlagCountry('Seychelles', 'SC',
      assetPath: 'assets/images/flags/SC.png', imageUrl: _commons('Flag of Seychelles.svg')),
  _FlagCountry('Comoros', 'KM',
      assetPath: 'assets/images/flags/KM.png', imageUrl: _commons('Flag of the Comoros.svg')),
  _FlagCountry('Djibouti', 'DJ',
      assetPath: 'assets/images/flags/DJ.png', imageUrl: _commons('Flag of Djibouti.svg')),
  _FlagCountry('Eritrea', 'ER',
      assetPath: 'assets/images/flags/ER.png', imageUrl: _commons('Flag of Eritrea.svg')),
  _FlagCountry('South Sudan', 'SS',
      assetPath: 'assets/images/flags/SS.png', imageUrl: _commons('Flag of South Sudan.svg')),
  _FlagCountry('Central African Republic', 'CF',
      assetPath: 'assets/images/flags/CF.png', imageUrl: _commons('Flag of the Central African Republic.svg')),
  _FlagCountry('Gabon', 'GA',
      assetPath: 'assets/images/flags/GA.png', imageUrl: _commons('Flag of Gabon.svg')),
  _FlagCountry('Equatorial Guinea', 'GQ',
      assetPath: 'assets/images/flags/GQ.png', imageUrl: _commons('Flag of Equatorial Guinea.svg')),
  _FlagCountry('Sao Tome and Principe', 'ST',
      assetPath: 'assets/images/flags/ST.png', imageUrl: _commons('Flag of São Tomé and Príncipe.svg')),
  _FlagCountry('Malawi', 'MW',
      assetPath: 'assets/images/flags/MW.png', imageUrl: _commons('Flag of Malawi.svg')),
  _FlagCountry('Chad', 'TD',
      assetPath: 'assets/images/flags/TD.png', imageUrl: _commons('Flag of Chad.svg')),
  _FlagCountry('Niger', 'NE',
      assetPath: 'assets/images/flags/NE.png', imageUrl: _commons('Flag of Niger.svg')),
  _FlagCountry('Tunisia', 'TN',
      assetPath: 'assets/images/flags/TN.png', imageUrl: _commons('Flag of Tunisia.svg')),
  _FlagCountry('Libya', 'LY',
      assetPath: 'assets/images/flags/LY.png', imageUrl: _commons('Flag of Libya.svg')),
  _FlagCountry('Sudan', 'SD',
      assetPath: 'assets/images/flags/SD.png', imageUrl: _commons('Flag of Sudan.svg')),
  // Middle East / Central Asia
  _FlagCountry('Kazakhstan', 'KZ',
      assetPath: 'assets/images/flags/KZ.png', imageUrl: _commons('Flag of Kazakhstan.svg')),
  _FlagCountry('Uzbekistan', 'UZ',
      assetPath: 'assets/images/flags/UZ.png', imageUrl: _commons('Flag of Uzbekistan.svg')),
  _FlagCountry('Turkmenistan', 'TM',
      assetPath: 'assets/images/flags/TM.png', imageUrl: _commons('Flag of Turkmenistan.svg')),
  _FlagCountry('Kyrgyzstan', 'KG',
      assetPath: 'assets/images/flags/KG.png', imageUrl: _commons('Flag of Kyrgyzstan.svg')),
  _FlagCountry('Tajikistan', 'TJ',
      assetPath: 'assets/images/flags/TJ.png', imageUrl: _commons('Flag of Tajikistan.svg')),
  _FlagCountry('Mongolia', 'MN',
      assetPath: 'assets/images/flags/MN.png', imageUrl: _commons('Flag of Mongolia.svg')),
  _FlagCountry('Afghanistan', 'AF',
      assetPath: 'assets/images/flags/AF.png', imageUrl: _commons('Flag of Afghanistan.svg')),
  _FlagCountry('Iran', 'IR',
      assetPath: 'assets/images/flags/IR.png', imageUrl: _commons('Flag of Iran.svg')),
  _FlagCountry('Iraq', 'IQ',
      assetPath: 'assets/images/flags/IQ.png', imageUrl: _commons('Flag of Iraq.svg')),
  _FlagCountry('Syria', 'SY',
      assetPath: 'assets/images/flags/SY.png', imageUrl: _commons('Flag of Syria.svg')),
  _FlagCountry('Lebanon', 'LB',
      assetPath: 'assets/images/flags/LB.png', imageUrl: _commons('Flag of Lebanon.svg')),
  _FlagCountry('Jordan', 'JO',
      assetPath: 'assets/images/flags/JO.png', imageUrl: _commons('Flag of Jordan.svg')),
  _FlagCountry('Kuwait', 'KW',
      assetPath: 'assets/images/flags/KW.png', imageUrl: _commons('Flag of Kuwait.svg')),
  _FlagCountry('Qatar', 'QA',
      assetPath: 'assets/images/flags/QA.png', imageUrl: _commons('Flag of Qatar.svg')),
  _FlagCountry('Bahrain', 'BH',
      assetPath: 'assets/images/flags/BH.png', imageUrl: _commons('Flag of Bahrain.svg')),
  _FlagCountry('Oman', 'OM',
      assetPath: 'assets/images/flags/OM.png', imageUrl: _commons('Flag of Oman.svg')),
  _FlagCountry('Yemen', 'YE',
      assetPath: 'assets/images/flags/YE.png', imageUrl: _commons('Flag of Yemen.svg')),
  _FlagCountry('Georgia', 'GE',
      assetPath: 'assets/images/flags/GE.png', imageUrl: _commons('Flag of Georgia.svg')),
  _FlagCountry('Armenia', 'AM',
      assetPath: 'assets/images/flags/AM.png', imageUrl: _commons('Flag of Armenia.svg')),
  _FlagCountry('Azerbaijan', 'AZ',
      assetPath: 'assets/images/flags/AZ.png', imageUrl: _commons('Flag of Azerbaijan.svg')),
  // South / Southeast / East Asia
  _FlagCountry('Nepal', 'NP',
      assetPath: 'assets/images/flags/NP.png', imageUrl: _commons('Flag of Nepal.svg')),
  _FlagCountry('Sri Lanka', 'LK',
      assetPath: 'assets/images/flags/LK.png', imageUrl: _commons('Flag of Sri Lanka.svg')),
  _FlagCountry('Myanmar', 'MM',
      assetPath: 'assets/images/flags/MM.png', imageUrl: _commons('Flag of Myanmar.svg')),
  _FlagCountry('Cambodia', 'KH',
      assetPath: 'assets/images/flags/KH.png', imageUrl: _commons('Flag of Cambodia.svg')),
  _FlagCountry('Laos', 'LA',
      assetPath: 'assets/images/flags/LA.png', imageUrl: _commons('Flag of Laos.svg')),
  _FlagCountry('Brunei', 'BN',
      assetPath: 'assets/images/flags/BN.png', imageUrl: _commons('Flag of Brunei.svg')),
  _FlagCountry('Timor-Leste', 'TL',
      assetPath: 'assets/images/flags/TL.png', imageUrl: _commons('Flag of East Timor.svg')),
  _FlagCountry('North Korea', 'KP',
      assetPath: 'assets/images/flags/KP.png', imageUrl: _commons('Flag of North Korea.svg')),
  _FlagCountry('Taiwan', 'TW',
      assetPath: 'assets/images/flags/TW.png', imageUrl: _commons('Flag of Taiwan.svg')),
  _FlagCountry('Bhutan', 'BT',
      assetPath: 'assets/images/flags/BT.png', imageUrl: _commons('Flag of Bhutan.svg')),
  _FlagCountry('Maldives', 'MV',
      assetPath: 'assets/images/flags/MV.png', imageUrl: _commons('Flag of Maldives.svg')),
  // Europe
  _FlagCountry('Romania', 'RO',
      assetPath: 'assets/images/flags/RO.png', imageUrl: _commons('Flag of Romania.svg')),
  _FlagCountry('Bulgaria', 'BG',
      assetPath: 'assets/images/flags/BG.png', imageUrl: _commons('Flag of Bulgaria.svg')),
  _FlagCountry('Hungary', 'HU',
      assetPath: 'assets/images/flags/HU.png', imageUrl: _commons('Flag of Hungary.svg')),
  _FlagCountry('Czech Republic', 'CZ',
      assetPath: 'assets/images/flags/CZ.png', imageUrl: _commons('Flag of the Czech Republic.svg')),
  _FlagCountry('Slovakia', 'SK',
      assetPath: 'assets/images/flags/SK.png', imageUrl: _commons('Flag of Slovakia.svg')),
  _FlagCountry('Slovenia', 'SI',
      assetPath: 'assets/images/flags/SI.png', imageUrl: _commons('Flag of Slovenia.svg')),
  _FlagCountry('Croatia', 'HR',
      assetPath: 'assets/images/flags/HR.png', imageUrl: _commons('Flag of Croatia.svg')),
  _FlagCountry('Serbia', 'RS',
      assetPath: 'assets/images/flags/RS.png', imageUrl: _commons('Flag of Serbia.svg')),
  _FlagCountry('Bosnia and Herzegovina', 'BA',
      assetPath: 'assets/images/flags/BA.png', imageUrl: _commons('Flag of Bosnia and Herzegovina.svg')),
  _FlagCountry('Albania', 'AL',
      assetPath: 'assets/images/flags/AL.png', imageUrl: _commons('Flag of Albania.svg')),
  _FlagCountry('North Macedonia', 'MK',
      assetPath: 'assets/images/flags/MK.png', imageUrl: _commons('Flag of North Macedonia.svg')),
  _FlagCountry('Montenegro', 'ME',
      assetPath: 'assets/images/flags/ME.png', imageUrl: _commons('Flag of Montenegro.svg')),
  _FlagCountry('Lithuania', 'LT',
      assetPath: 'assets/images/flags/LT.png', imageUrl: _commons('Flag of Lithuania.svg')),
  _FlagCountry('Latvia', 'LV',
      assetPath: 'assets/images/flags/LV.png', imageUrl: _commons('Flag of Latvia.svg')),
  _FlagCountry('Estonia', 'EE',
      assetPath: 'assets/images/flags/EE.png', imageUrl: _commons('Flag of Estonia.svg')),
  _FlagCountry('Belarus', 'BY',
      assetPath: 'assets/images/flags/BY.png', imageUrl: _commons('Flag of Belarus.svg')),
  _FlagCountry('Moldova', 'MD',
      assetPath: 'assets/images/flags/MD.png', imageUrl: _commons('Flag of Moldova.svg')),
  _FlagCountry('Iceland', 'IS',
      assetPath: 'assets/images/flags/IS.png', imageUrl: _commons('Flag of Iceland.svg')),
  _FlagCountry('Ireland', 'IE',
      assetPath: 'assets/images/flags/IE.png', imageUrl: _commons('Flag of Ireland.svg')),
  _FlagCountry('Luxembourg', 'LU',
      assetPath: 'assets/images/flags/LU.png', imageUrl: _commons('Flag of Luxembourg.svg')),
  _FlagCountry('Monaco', 'MC',
      assetPath: 'assets/images/flags/MC.png', imageUrl: _commons('Flag of Monaco.svg')),
  _FlagCountry('Malta', 'MT',
      assetPath: 'assets/images/flags/MT.png', imageUrl: _commons('Flag of Malta.svg')),
  _FlagCountry('Cyprus', 'CY',
      assetPath: 'assets/images/flags/CY.png', imageUrl: _commons('Flag of Cyprus.svg')),
  // Americas
  _FlagCountry('Guatemala', 'GT',
      assetPath: 'assets/images/flags/GT.png', imageUrl: _commons('Flag of Guatemala.svg')),
  _FlagCountry('Belize', 'BZ',
      assetPath: 'assets/images/flags/BZ.png', imageUrl: _commons('Flag of Belize.svg')),
  _FlagCountry('Honduras', 'HN',
      assetPath: 'assets/images/flags/HN.png', imageUrl: _commons('Flag of Honduras.svg')),
  _FlagCountry('El Salvador', 'SV',
      assetPath: 'assets/images/flags/SV.png', imageUrl: _commons('Flag of El Salvador.svg')),
  _FlagCountry('Nicaragua', 'NI',
      assetPath: 'assets/images/flags/NI.png', imageUrl: _commons('Flag of Nicaragua.svg')),
  _FlagCountry('Costa Rica', 'CR',
      assetPath: 'assets/images/flags/CR.png', imageUrl: _commons('Flag of Costa Rica.svg')),
  _FlagCountry('Panama', 'PA',
      assetPath: 'assets/images/flags/PA.png', imageUrl: _commons('Flag of Panama.svg')),
  _FlagCountry('Cuba', 'CU',
      assetPath: 'assets/images/flags/CU.png', imageUrl: _commons('Flag of Cuba.svg')),
  _FlagCountry('Dominican Republic', 'DO',
      assetPath: 'assets/images/flags/DO.png', imageUrl: _commons('Flag of the Dominican Republic.svg')),
  _FlagCountry('Haiti', 'HT',
      assetPath: 'assets/images/flags/HT.png', imageUrl: _commons('Flag of Haiti.svg')),
  _FlagCountry('Jamaica', 'JM',
      assetPath: 'assets/images/flags/JM.png', imageUrl: _commons('Flag of Jamaica.svg')),
  _FlagCountry('Trinidad and Tobago', 'TT',
      assetPath: 'assets/images/flags/TT.png', imageUrl: _commons('Flag of Trinidad and Tobago.svg')),
  _FlagCountry('Bahamas', 'BS',
      assetPath: 'assets/images/flags/BS.png', imageUrl: _commons('Flag of the Bahamas.svg')),
  _FlagCountry('Barbados', 'BB',
      assetPath: 'assets/images/flags/BB.png', imageUrl: _commons('Flag of Barbados.svg')),
  _FlagCountry('Bolivia', 'BO',
      assetPath: 'assets/images/flags/BO.png', imageUrl: _commons('Flag of Bolivia.svg')),
  _FlagCountry('Paraguay', 'PY',
      assetPath: 'assets/images/flags/PY.png', imageUrl: _commons('Flag of Paraguay.svg')),
  _FlagCountry('Uruguay', 'UY',
      assetPath: 'assets/images/flags/UY.png', imageUrl: _commons('Flag of Uruguay.svg')),
  _FlagCountry('Venezuela', 'VE',
      assetPath: 'assets/images/flags/VE.png', imageUrl: _commons('Flag of Venezuela.svg')),
  _FlagCountry('Ecuador', 'EC',
      assetPath: 'assets/images/flags/EC.png', imageUrl: _commons('Flag of Ecuador.svg')),
  _FlagCountry('Guyana', 'GY',
      assetPath: 'assets/images/flags/GY.png', imageUrl: _commons('Flag of Guyana.svg')),
  _FlagCountry('Suriname', 'SR',
      assetPath: 'assets/images/flags/SR.png', imageUrl: _commons('Flag of Suriname.svg')),
  _FlagCountry('Liberia', 'LR',
      assetPath: 'assets/images/flags/LR.png', imageUrl: _commons('Flag of Liberia.svg')),
  // Oceania
  _FlagCountry('Fiji', 'FJ',
      assetPath: 'assets/images/flags/FJ.png', imageUrl: _commons('Flag of Fiji.svg')),
  _FlagCountry('Papua New Guinea', 'PG',
      assetPath: 'assets/images/flags/PG.png', imageUrl: _commons('Flag of Papua New Guinea.svg')),
];

/// Full country pool for Medium / Hard, de-duplicated by code.
final List<_FlagCountry> _kWorldCountries = () {
  final byCode = <String, _FlagCountry>{
    for (final c in _kEasyCountries) c.code: c,
    for (final c in _additionalWorldCountries) c.code: c,
  };
  return byCode.values.toList();
}();

// ── Trap flags: countries with a well-known lookalike (Hard only) ──────────
const Map<String, List<String>> _kSimilarFlagGroups = {
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

/// Countries that appear as a key in [_kSimilarFlagGroups] — the pool Hard
/// samples from first when building the round order.
final List<_FlagCountry> _kTrapCountries = _kSimilarFlagGroups.keys
    .map((code) => _kWorldCountries.firstWhere((c) => c.code == code))
    .toList();

// ── Historical (defunct-state) flags — Insane only ──────────────────────────
// No emoji exists for any of these — rendered from real Wikimedia Commons
// images (public-domain / CC-licensed national-flag files).
final List<_FlagCountry> _kHistoricalFlags = [
  _FlagCountry('Soviet Union', 'HIST-USSR',
      assetPath: 'assets/images/flags_insane/HIST-USSR.png', imageUrl: _commons('Flag of the Soviet Union.svg'), era: '1922–1991'),
  _FlagCountry('German Empire', 'HIST-DE-EMPIRE',
      assetPath: 'assets/images/flags_insane/HIST-DE-EMPIRE.png', imageUrl: _commons('Flag of the German Empire.svg'), era: '1871–1918'),
  _FlagCountry('East Germany', 'HIST-DDR',
      assetPath: 'assets/images/flags_insane/HIST-DDR.png', imageUrl: _commons('Flag of East Germany.svg'), era: '1949–1990'),
  _FlagCountry('Austria-Hungary', 'HIST-AUHU',
      assetPath: 'assets/images/flags_insane/HIST-AUHU.png', imageUrl: _commons('Flag of Austria-Hungary (1869-1918).svg'), era: '1867–1918'),
  _FlagCountry('Austrian Empire', 'HIST-AT-EMPIRE',
      assetPath: 'assets/images/flags_insane/HIST-AT-EMPIRE.png', imageUrl: _commons('Flag of the Habsburg Monarchy.svg'), era: '1804–1867'),
  _FlagCountry('Ottoman Empire', 'HIST-OTTOMAN',
      assetPath: 'assets/images/flags_insane/HIST-OTTOMAN.png', imageUrl: _commons('Flag of the Ottoman Empire.svg'), era: '1844–1922'),
  _FlagCountry('Kingdom of Hawaii', 'HIST-HAWAII',
      assetPath: 'assets/images/flags_insane/HIST-HAWAII.png', imageUrl: _commons('Flag of Hawaii.svg'), era: '1845–1893'),
  _FlagCountry('Republic of Texas', 'HIST-TEXAS',
      assetPath: 'assets/images/flags_insane/HIST-TEXAS.png', imageUrl: _commons('Flag of Texas.svg'), era: '1836–1845'),
  _FlagCountry('Tibet', 'HIST-TIBET',
      assetPath: 'assets/images/flags_insane/HIST-TIBET.png', imageUrl: _commons('Flag of Tibet.svg'), era: 'de facto 1912–1951'),
  _FlagCountry('Yugoslavia (SFRY)', 'HIST-YUGO',
      assetPath: 'assets/images/flags_insane/HIST-YUGO.png', imageUrl: _commons('Flag of Yugoslavia (1946-1992).svg'), era: '1946–1992'),
  _FlagCountry('Czechoslovakia', 'HIST-CZS',
      assetPath: 'assets/images/flags_insane/HIST-CZS.png', imageUrl: _commons('Flag of Czechoslovakia.svg'), era: '1918–1992'),
  _FlagCountry('Kingdom of Italy', 'HIST-ITALY-KGD',
      assetPath: 'assets/images/flags_insane/HIST-ITALY-KGD.png', imageUrl: _commons('Flag of Italy (1861-1946).svg'), era: '1861–1946'),
  _FlagCountry('Kingdom of Prussia', 'HIST-PRUSSIA',
      assetPath: 'assets/images/flags_insane/HIST-PRUSSIA.png', imageUrl: _commons('Flag of Prussia (1892-1918).svg'), era: '1701–1918'),
  _FlagCountry('Manchukuo', 'HIST-MANCHUKUO',
      assetPath: 'assets/images/flags_insane/HIST-MANCHUKUO.png', imageUrl: _commons('Flag of Manchukuo.svg'), era: '1932–1945'),
  _FlagCountry('Republic of China (early)', 'HIST-ROC-EARLY',
      assetPath: 'assets/images/flags_insane/HIST-ROC-EARLY.png', imageUrl: _commons('Flag of the Republic of China (1912-1928).svg'), era: '1912–1928'),
  _FlagCountry('South Vietnam', 'HIST-SVIETNAM',
      assetPath: 'assets/images/flags_insane/HIST-SVIETNAM.png', imageUrl: _commons('Flag of South Vietnam.svg'), era: '1955–1975'),
  _FlagCountry('United Arab Republic', 'HIST-UAR',
      assetPath: 'assets/images/flags_insane/HIST-UAR.png', imageUrl: _commons('Flag of the United Arab Republic.svg'), era: '1958–1961'),
  _FlagCountry('Zaire', 'HIST-ZAIRE',
      assetPath: 'assets/images/flags_insane/HIST-ZAIRE.png', imageUrl: _commons('Flag of Zaire (1971–1997).svg'), era: '1971–1997'),
  _FlagCountry('Rhodesia', 'HIST-RHODESIA',
      assetPath: 'assets/images/flags_insane/HIST-RHODESIA.png', imageUrl: _commons('Flag of Rhodesia.svg'), era: '1965–1979'),
  _FlagCountry('Empire of Brazil', 'HIST-BRAZIL-EMPIRE',
      assetPath: 'assets/images/flags_insane/HIST-BRAZIL-EMPIRE.png', imageUrl: _commons('Flag of Brazil (1853-1889).svg'), era: '1822–1889'),
  _FlagCountry('Confederate States of America', 'HIST-CSA',
      assetPath: 'assets/images/flags_insane/HIST-CSA.png', imageUrl: _commons('Flag of the Confederate States (1861-1863).svg'), era: '1861–1865'),
  _FlagCountry('Kingdom of the Two Sicilies', 'HIST-TWOSICILIES',
      assetPath: 'assets/images/flags_insane/HIST-TWOSICILIES.png', imageUrl: _commons('Flag of the Two Sicilies.svg'), era: '1816–1861'),
  _FlagCountry('Republic of Venice', 'HIST-VENICE',
      assetPath: 'assets/images/flags_insane/HIST-VENICE.png', imageUrl: _commons('Flag of Most Serene Republic of Venice.svg'), era: '697–1797'),
  _FlagCountry('Republic of Genoa', 'HIST-GENOA',
      assetPath: 'assets/images/flags_insane/HIST-GENOA.png', imageUrl: _commons('Flag of Genoa.svg'), era: '1099–1797'),
  _FlagCountry('Kingdom of Hanover', 'HIST-HANOVER',
      assetPath: 'assets/images/flags_insane/HIST-HANOVER.png', imageUrl: _commons('Flag of Hanover.svg'), era: '1814–1866'),
  _FlagCountry('Kingdom of Serbia', 'HIST-SERBIA-KGD',
      assetPath: 'assets/images/flags_insane/HIST-SERBIA-KGD.png', imageUrl: _commons('Flag of Serbia (1882-1918).svg'), era: '1882–1918'),
  _FlagCountry('Kingdom of Yugoslavia', 'HIST-YUGO-KGD',
      assetPath: 'assets/images/flags_insane/HIST-YUGO-KGD.png', imageUrl: _commons('Flag of Yugoslavia (1918-1943).svg'), era: '1918–1941'),
  _FlagCountry('Kingdom of Egypt', 'HIST-EGYPT-KGD',
      assetPath: 'assets/images/flags_insane/HIST-EGYPT-KGD.png', imageUrl: _commons('Flag of the Kingdom of Egypt.svg'), era: '1922–1953'),
  _FlagCountry('Democratic Kampuchea', 'HIST-KAMPUCHEA',
      assetPath: 'assets/images/flags_insane/HIST-KAMPUCHEA.png', imageUrl: _commons('Flag of Democratic Kampuchea 1976.svg'), era: '1975–1979'),
  _FlagCountry('Congo Free State', 'HIST-CONGOFREE',
      assetPath: 'assets/images/flags_insane/HIST-CONGOFREE.png', imageUrl: _commons('Flag of Congo Free State.svg'), era: '1885–1908'),
  _FlagCountry('Orange Free State', 'HIST-ORANGEFS',
      assetPath: 'assets/images/flags_insane/HIST-ORANGEFS.png', imageUrl: _commons('Flag of Orange Free State.svg'), era: '1854–1902'),
  _FlagCountry('South African Republic', 'HIST-TRANSVAAL',
      assetPath: 'assets/images/flags_insane/HIST-TRANSVAAL.png', imageUrl: _commons('Flag of South African Republic.svg'), era: '1857–1902'),
  _FlagCountry('Republic of Hatay', 'HIST-HATAY',
      assetPath: 'assets/images/flags_insane/HIST-HATAY.png', imageUrl: _commons('Flag of Hatay State.svg'), era: '1938–1939'),
  _FlagCountry('Kingdom of Montenegro', 'HIST-MONTENEGRO-KGD',
      assetPath: 'assets/images/flags_insane/HIST-MONTENEGRO-KGD.png', imageUrl: _commons('Flag of Montenegro (1905-1918).svg'), era: '1910–1918'),
  _FlagCountry('Kingdom of Portugal', 'HIST-PORTUGAL-KGD',
      assetPath: 'assets/images/flags_insane/HIST-PORTUGAL-KGD.png', imageUrl: _commons('Flag of Portugal (1830-1910).svg'), era: '1139–1910'),
  _FlagCountry('Empire of Ethiopia', 'HIST-ETHIOPIA-EMPIRE',
      assetPath: 'assets/images/flags_insane/HIST-ETHIOPIA-EMPIRE.png', imageUrl: _commons('Flag of Ethiopia (1897-1936).svg'), era: '1270–1974'),
  _FlagCountry('Union of South Africa', 'HIST-SOUTHAFRICA-UNION',
      assetPath: 'assets/images/flags_insane/HIST-SOUTHAFRICA-UNION.png', imageUrl: _commons('Flag of South Africa (1928-1994).svg'), era: '1928–1994'),
  _FlagCountry('Kingdom of Laos', 'HIST-LAOS-KGD',
      assetPath: 'assets/images/flags_insane/HIST-LAOS-KGD.png', imageUrl: _commons('Flag of Laos (1952-1975).svg'), era: '1953–1975'),
  _FlagCountry('Kingdom of Iraq', 'HIST-IRAQ-KGD',
      assetPath: 'assets/images/flags_insane/HIST-IRAQ-KGD.png', imageUrl: _commons('Flag of Iraq (1924-1959).svg'), era: '1932–1958'),
  _FlagCountry('Kingdom of Libya', 'HIST-LIBYA-KGD',
      assetPath: 'assets/images/flags_insane/HIST-LIBYA-KGD.png', imageUrl: _commons('Flag of Libya (1951-1969).svg'), era: '1951–1969'),
  _FlagCountry('Republic of Katanga', 'HIST-KATANGA',
      assetPath: 'assets/images/flags_insane/HIST-KATANGA.png', imageUrl: _commons('Flag of Katanga.svg'), era: '1960–1963'),
  _FlagCountry('Kingdom of Sikkim', 'HIST-SIKKIM',
      assetPath: 'assets/images/flags_insane/HIST-SIKKIM.png', imageUrl: _commons('Flag of Sikkim.svg'), era: '1642–1975'),
  _FlagCountry('Kingdom of Greece', 'HIST-GREECE-KGD',
      assetPath: 'assets/images/flags_insane/HIST-GREECE-KGD.png', imageUrl: _commons('Flag of Greece (1970-1975).svg'), era: '1832–1973'),
  _FlagCountry('Kingdom of Naples', 'HIST-NAPLES',
      assetPath: 'assets/images/flags_insane/HIST-NAPLES.png', imageUrl: _commons('Flag of the Kingdom of Naples.svg'), era: '1282–1816'),
  _FlagCountry('Republic of Ragusa', 'HIST-RAGUSA',
      assetPath: 'assets/images/flags_insane/HIST-RAGUSA.png', imageUrl: _commons('Flag of Ragusa.svg'), era: '1358–1808'),
  _FlagCountry('Duchy of Warsaw', 'HIST-WARSAW-DUCHY',
      assetPath: 'assets/images/flags_insane/HIST-WARSAW-DUCHY.png', imageUrl: _commons('Flag of the Duchy of Warsaw.svg'), era: '1807–1815'),
  _FlagCountry('Kingdom of Saxony', 'HIST-SAXONY-KGD',
      assetPath: 'assets/images/flags_insane/HIST-SAXONY-KGD.png', imageUrl: _commons('Flag of Saxony.svg'), era: '1806–1918'),
  _FlagCountry('Kingdom of Württemberg', 'HIST-WURTTEMBERG',
      assetPath: 'assets/images/flags_insane/HIST-WURTTEMBERG.png', imageUrl: _commons('Flag of Wurttemberg.svg'), era: '1806–1918'),
  _FlagCountry('Grand Duchy of Baden', 'HIST-BADEN',
      assetPath: 'assets/images/flags_insane/HIST-BADEN.png', imageUrl: _commons('Flag of the Grand Duchy of Baden.svg'), era: '1806–1918'),
  _FlagCountry('Kingdom of Sardinia', 'HIST-SARDINIA-KGD',
      assetPath: 'assets/images/flags_insane/HIST-SARDINIA-KGD.png', imageUrl: _commons('Flag of the Kingdom of Sardinia.svg'), era: '1720–1861'),
  _FlagCountry('Kingdom of Bavaria', 'HIST-BAVARIA-KGD',
      assetPath: 'assets/images/flags_insane/HIST-BAVARIA-KGD.png', imageUrl: _commons('Flag of Bavaria (lozengy).svg'), era: '1806–1918'),
  _FlagCountry('California Republic', 'HIST-CALIFORNIA-REP',
      assetPath: 'assets/images/flags_insane/HIST-CALIFORNIA-REP.png', imageUrl: _commons('Flag of the Bear Flag Revolt.svg'), era: '1846'),
  _FlagCountry('Vermont Republic', 'HIST-VERMONT-REP',
      assetPath: 'assets/images/flags_insane/HIST-VERMONT-REP.png', imageUrl: _commons('Flag of the Vermont Republic.svg'), era: '1777–1791'),
  _FlagCountry('Republic of West Florida', 'HIST-WESTFLORIDA',
      assetPath: 'assets/images/flags_insane/HIST-WESTFLORIDA.png', imageUrl: _commons('Flag of West Florida.svg'), era: '1810'),
  _FlagCountry('Republic of Yucatán', 'HIST-YUCATAN',
      assetPath: 'assets/images/flags_insane/HIST-YUCATAN.png', imageUrl: _commons('Flag of Yucatan.svg'), era: '1841–1848'),
  _FlagCountry('Gran Colombia', 'HIST-GRANCOLOMBIA',
      assetPath: 'assets/images/flags_insane/HIST-GRANCOLOMBIA.png', imageUrl: _commons('Flag of Gran Colombia.svg'), era: '1819–1831'),
  _FlagCountry('Federal Republic of Central America', 'HIST-CENTRALAMERICA',
      assetPath: 'assets/images/flags_insane/HIST-CENTRALAMERICA.png', imageUrl: _commons('Flag of the Federal Republic of Central America.svg'), era: '1823–1841'),
  _FlagCountry('First Mexican Empire', 'HIST-MEXICO-EMPIRE1',
      assetPath: 'assets/images/flags_insane/HIST-MEXICO-EMPIRE1.png', imageUrl: _commons('Flag of the First Mexican Empire (10 rays version).svg'), era: '1821–1823'),
  _FlagCountry('Second Mexican Empire', 'HIST-MEXICO-EMPIRE2',
      assetPath: 'assets/images/flags_insane/HIST-MEXICO-EMPIRE2.png', imageUrl: _commons('Flag of the Second Mexican Empire.svg'), era: '1864–1867'),
  _FlagCountry('Republic of Formosa', 'HIST-FORMOSA',
      assetPath: 'assets/images/flags_insane/HIST-FORMOSA.png', imageUrl: _commons('Flag of the Republic of Formosa (1895).svg'), era: '1895'),
  _FlagCountry('First Philippine Republic', 'HIST-PHILIPPINES-1ST',
      assetPath: 'assets/images/flags_insane/HIST-PHILIPPINES-1ST.png', imageUrl: _commons('Flag of the Philippines (1898-1901, square).svg'), era: '1899–1901'),
  _FlagCountry('Republic of Ezo', 'HIST-EZO',
      assetPath: 'assets/images/flags_insane/HIST-EZO.png', imageUrl: _commons('Flag of the Republic of Ezo.svg'), era: '1869'),
  _FlagCountry('Mengjiang', 'HIST-MENGJIANG',
      assetPath: 'assets/images/flags_insane/HIST-MENGJIANG.png', imageUrl: _commons('Flag of the Mengjiang.svg'), era: '1936–1945'),
  _FlagCountry('Aden Colony', 'HIST-ADEN',
      assetPath: 'assets/images/flags_insane/HIST-ADEN.png', imageUrl: _commons('Flag of Colony of Aden.svg'), era: '1937–1963'),
  _FlagCountry('Federation of South Arabia', 'HIST-SOUTHARABIA',
      assetPath: 'assets/images/flags_insane/HIST-SOUTHARABIA.png', imageUrl: _commons('Flag of the Federation of South Arabia.svg'), era: '1962–1967'),
  _FlagCountry('South Yemen', 'HIST-SOUTHYEMEN',
      assetPath: 'assets/images/flags_insane/HIST-SOUTHYEMEN.png', imageUrl: _commons('Flag of South Yemen.svg'), era: '1967–1990'),
  _FlagCountry('North Yemen', 'HIST-NORTHYEMEN',
      assetPath: 'assets/images/flags_insane/HIST-NORTHYEMEN.png', imageUrl: _commons('Flag of North Yemen.svg'), era: '1962–1990'),
  _FlagCountry('Kingdom of Araucanía and Patagonia', 'HIST-ARAUCANIA',
      assetPath: 'assets/images/flags_insane/HIST-ARAUCANIA.png', imageUrl: _commons('Flag of the Kingdom of Araucanía and Patagonia.svg'), era: '1860–1862'),
  _FlagCountry('Sovereign Military Order of Malta', 'HIST-SMOM',
      assetPath: 'assets/images/flags_insane/HIST-SMOM.png', imageUrl: _commons('Flag of the Sovereign Military Order of Malta.svg'), era: '1113–present'),
  _FlagCountry('Cretan State', 'HIST-CRETE',
      assetPath: 'assets/images/flags_insane/HIST-CRETE.png', imageUrl: _commons('Flag of Crete (1898-1913).svg'), era: '1898–1913'),
  _FlagCountry('Empire of Vietnam', 'HIST-VIETNAM-EMPIRE',
      assetPath: 'assets/images/flags_insane/HIST-VIETNAM-EMPIRE.png', imageUrl: _commons('Flag of Vietnam (1945).svg'), era: '1945'),
  _FlagCountry('State of Vietnam', 'HIST-VIETNAM-STATE',
      assetPath: 'assets/images/flags_insane/HIST-VIETNAM-STATE.png', imageUrl: _commons('Flag of the State of Vietnam.svg'), era: '1949–1955'),
  _FlagCountry('Azad Hind', 'HIST-AZADHIND',
      assetPath: 'assets/images/flags_insane/HIST-AZADHIND.png', imageUrl: _commons('Flag of Azad Hind.svg'), era: '1943–1945'),
  _FlagCountry('Sultanate of Zanzibar', 'HIST-ZANZIBAR-SULTANATE',
      assetPath: 'assets/images/flags_insane/HIST-ZANZIBAR-SULTANATE.png', imageUrl: _commons('Flag of Zanzibar (1856-1963).svg'), era: '1963–1964'),
  _FlagCountry('Kingdom of Burundi', 'HIST-BURUNDI-KGD',
      assetPath: 'assets/images/flags_insane/HIST-BURUNDI-KGD.png', imageUrl: _commons('Flag of Burundi (1962-1966).svg'), era: '1962–1966'),
  _FlagCountry('Kingdom of Rwanda', 'HIST-RWANDA-KGD',
      assetPath: 'assets/images/flags_insane/HIST-RWANDA-KGD.png', imageUrl: _commons('Flag of Rwanda (1959-1961).svg'), era: '1959–1961'),
  _FlagCountry('Republic of Biafra', 'HIST-BIAFRA',
      assetPath: 'assets/images/flags_insane/HIST-BIAFRA.png', imageUrl: _commons('Flag of Biafra.svg'), era: '1967–1970'),
];

// ── Current subnational / territorial flags without emoji support ──────────
// Insane only. Apolitical, well-documented regional and territorial flags.
final List<_FlagCountry> _kRegionalImageFlags = [
  _FlagCountry('England', 'REG-ENGLAND',
      assetPath: 'assets/images/flags_insane/REG-ENGLAND.png', imageUrl: _commons('Flag of England.svg')),
  _FlagCountry('Scotland', 'REG-SCOTLAND',
      assetPath: 'assets/images/flags_insane/REG-SCOTLAND.png', imageUrl: _commons('Flag of Scotland.svg')),
  _FlagCountry('Bavaria', 'REG-BAVARIA',
      assetPath: 'assets/images/flags_insane/REG-BAVARIA.png', imageUrl: _commons('Flag of Bavaria (striped).svg')),
  _FlagCountry('Hong Kong', 'REG-HK',
      assetPath: 'assets/images/flags_insane/REG-HK.png', imageUrl: _commons('Flag of Hong Kong.svg')),
  _FlagCountry('Sicily', 'REG-SICILY',
      assetPath: 'assets/images/flags_insane/REG-SICILY.png', imageUrl: _commons('Flag of Sicily.svg')),
  _FlagCountry('Quebec', 'REG-QUEBEC',
      assetPath: 'assets/images/flags_insane/REG-QUEBEC.png', imageUrl: _commons('Flag of Quebec.svg')),
  _FlagCountry('Greenland', 'REG-GREENLAND',
      assetPath: 'assets/images/flags_insane/REG-GREENLAND.png', imageUrl: _commons('Flag of Greenland.svg')),
  _FlagCountry('Faroe Islands', 'REG-FAROE',
      assetPath: 'assets/images/flags_insane/REG-FAROE.png', imageUrl: _commons('Flag of the Faroe Islands.svg')),
  _FlagCountry('Bermuda', 'REG-BERMUDA',
      assetPath: 'assets/images/flags_insane/REG-BERMUDA.png', imageUrl: _commons('Flag of Bermuda.svg')),
  _FlagCountry('Gibraltar', 'REG-GIBRALTAR',
      assetPath: 'assets/images/flags_insane/REG-GIBRALTAR.png', imageUrl: _commons('Flag of Gibraltar.svg')),
  _FlagCountry('Isle of Man', 'REG-IOM',
      assetPath: 'assets/images/flags_insane/REG-IOM.png', imageUrl: _commons('Flag of the Isle of Man.svg')),
  _FlagCountry('Puerto Rico', 'REG-PR',
      assetPath: 'assets/images/flags_insane/REG-PR.png', imageUrl: _commons('Flag of Puerto Rico.svg')),
  _FlagCountry('Guam', 'REG-GUAM',
      assetPath: 'assets/images/flags_insane/REG-GUAM.png', imageUrl: _commons('Flag of Guam.svg')),
  _FlagCountry('American Samoa', 'REG-ASAMOA',
      assetPath: 'assets/images/flags_insane/REG-ASAMOA.png', imageUrl: _commons('Flag of American Samoa.svg')),
  _FlagCountry('Åland Islands', 'REG-ALAND',
      assetPath: 'assets/images/flags_insane/REG-ALAND.png', imageUrl: _commons('Flag of Åland.svg')),
  _FlagCountry('Sardinia', 'REG-SARDINIA',
      assetPath: 'assets/images/flags_insane/REG-SARDINIA.png', imageUrl: _commons('Flag of Sardinia.svg')),
  _FlagCountry('Corsica', 'REG-CORSICA',
      assetPath: 'assets/images/flags_insane/REG-CORSICA.png', imageUrl: _commons('Flag of Corsica.svg')),
  _FlagCountry('Saxony', 'REG-SAXONY',
      assetPath: 'assets/images/flags_insane/REG-SAXONY.png', imageUrl: _commons('Flag of Saxony.svg')),
  _FlagCountry('Cornwall', 'REG-CORNWALL',
      assetPath: 'assets/images/flags_insane/REG-CORNWALL.png', imageUrl: _commons('Flag of Cornwall.svg')),
  _FlagCountry('Catalonia', 'REG-CATALONIA',
      assetPath: 'assets/images/flags_insane/REG-CATALONIA.png', imageUrl: _commons('Flag of Catalonia.svg')),
  _FlagCountry('Basque Country', 'REG-BASQUE',
      assetPath: 'assets/images/flags_insane/REG-BASQUE.png', imageUrl: _commons('Flag of the Basque Country.svg')),
  _FlagCountry('Galicia', 'REG-GALICIA',
      assetPath: 'assets/images/flags_insane/REG-GALICIA.png', imageUrl: _commons('Flag of Galicia (Spain).svg')),
  _FlagCountry('Andalusia', 'REG-ANDALUSIA',
      assetPath: 'assets/images/flags_insane/REG-ANDALUSIA.png', imageUrl: _commons('Flag of Andalusia.svg')),
  _FlagCountry('Brittany', 'REG-BRITTANY',
      assetPath: 'assets/images/flags_insane/REG-BRITTANY.png', imageUrl: _commons('Flag of Brittany.svg')),
  _FlagCountry('Tyrol', 'REG-TYROL',
      assetPath: 'assets/images/flags_insane/REG-TYROL.png', imageUrl: _commons('Flag of Tirol.svg')),
  _FlagCountry('Wallonia', 'REG-WALLONIA',
      assetPath: 'assets/images/flags_insane/REG-WALLONIA.png', imageUrl: _commons('Flag of Wallonia.svg')),
  _FlagCountry('Flanders', 'REG-FLANDERS',
      assetPath: 'assets/images/flags_insane/REG-FLANDERS.png', imageUrl: _commons('Flag of Flanders.svg')),
  _FlagCountry('Northern Mariana Islands', 'REG-NMI',
      assetPath: 'assets/images/flags_insane/REG-NMI.png', imageUrl: _commons('Flag of the Northern Mariana Islands.svg')),
  _FlagCountry('U.S. Virgin Islands', 'REG-USVI',
      assetPath: 'assets/images/flags_insane/REG-USVI.png', imageUrl: _commons('Flag of the United States Virgin Islands.svg')),
  _FlagCountry('British Virgin Islands', 'REG-BVI',
      assetPath: 'assets/images/flags_insane/REG-BVI.png', imageUrl: _commons('Flag of the British Virgin Islands.svg')),
  _FlagCountry('Cayman Islands', 'REG-CAYMAN',
      assetPath: 'assets/images/flags_insane/REG-CAYMAN.png', imageUrl: _commons('Flag of the Cayman Islands.svg')),
  _FlagCountry('Falkland Islands', 'REG-FALKLAND',
      assetPath: 'assets/images/flags_insane/REG-FALKLAND.png', imageUrl: _commons('Flag of the Falkland Islands.svg')),
  _FlagCountry('Turks and Caicos Islands', 'REG-TURKSCAICOS',
      assetPath: 'assets/images/flags_insane/REG-TURKSCAICOS.png', imageUrl: _commons('Flag of the Turks and Caicos Islands.svg')),
  _FlagCountry('Anguilla', 'REG-ANGUILLA',
      assetPath: 'assets/images/flags_insane/REG-ANGUILLA.png', imageUrl: _commons('Flag of Anguilla.svg')),
  _FlagCountry('Montserrat', 'REG-MONTSERRAT',
      assetPath: 'assets/images/flags_insane/REG-MONTSERRAT.png', imageUrl: _commons('Flag of Montserrat.svg')),
  _FlagCountry('Aruba', 'REG-ARUBA',
      assetPath: 'assets/images/flags_insane/REG-ARUBA.png', imageUrl: _commons('Flag of Aruba.svg')),
  _FlagCountry('Curaçao', 'REG-CURACAO',
      assetPath: 'assets/images/flags_insane/REG-CURACAO.png', imageUrl: _commons('Flag of Curaçao.svg')),
  _FlagCountry('Sint Maarten', 'REG-SINTMAARTEN',
      assetPath: 'assets/images/flags_insane/REG-SINTMAARTEN.png', imageUrl: _commons('Flag of Sint Maarten.svg')),
  _FlagCountry('Cook Islands', 'REG-COOKISLANDS',
      assetPath: 'assets/images/flags_insane/REG-COOKISLANDS.png', imageUrl: _commons('Flag of the Cook Islands.svg')),
  _FlagCountry('Niue', 'REG-NIUE',
      assetPath: 'assets/images/flags_insane/REG-NIUE.png', imageUrl: _commons('Flag of Niue.svg')),
  _FlagCountry('French Polynesia', 'REG-FRENCHPOLYNESIA',
      assetPath: 'assets/images/flags_insane/REG-FRENCHPOLYNESIA.png', imageUrl: _commons('Flag of French Polynesia.svg')),
  _FlagCountry('Ceuta', 'REG-CEUTA',
      assetPath: 'assets/images/flags_insane/REG-CEUTA.png', imageUrl: _commons('Flag of Ceuta.svg')),
  _FlagCountry('Melilla', 'REG-MELILLA',
      assetPath: 'assets/images/flags_insane/REG-MELILLA.png', imageUrl: _commons('Flag of Melilla.svg')),
  _FlagCountry('South Tyrol', 'REG-SOUTHTYROL',
      assetPath: 'assets/images/flags_insane/REG-SOUTHTYROL.png', imageUrl: _commons('Flag of South Tyrol.svg')),
  _FlagCountry('Aosta Valley', 'REG-AOSTA',
      assetPath: 'assets/images/flags_insane/REG-AOSTA.png', imageUrl: _commons('Flag of Aosta Valley.svg')),
  _FlagCountry('Friuli-Venezia Giulia', 'REG-FRIULI',
      assetPath: 'assets/images/flags_insane/REG-FRIULI.png', imageUrl: _commons('Flag of Friuli-Venezia Giulia.svg')),
  _FlagCountry('Veneto', 'REG-VENETO',
      assetPath: 'assets/images/flags_insane/REG-VENETO.png', imageUrl: _commons('Flag of Veneto.svg')),
  _FlagCountry('Lombardy', 'REG-LOMBARDY',
      assetPath: 'assets/images/flags_insane/REG-LOMBARDY.png', imageUrl: _commons('Flag of Lombardy.svg')),
  _FlagCountry('Piedmont', 'REG-PIEDMONT',
      assetPath: 'assets/images/flags_insane/REG-PIEDMONT.png', imageUrl: _commons('Flag of Piedmont.svg')),
  _FlagCountry('Tuscany', 'REG-TUSCANY',
      assetPath: 'assets/images/flags_insane/REG-TUSCANY.png', imageUrl: _commons('Flag of Tuscany.svg')),
  _FlagCountry('Alsace', 'REG-ALSACE',
      assetPath: 'assets/images/flags_insane/REG-ALSACE.png', imageUrl: _commons('Flag of Alsace.svg')),
  _FlagCountry('Normandy', 'REG-NORMANDY',
      assetPath: 'assets/images/flags_insane/REG-NORMANDY.png', imageUrl: _commons('Flag of Normandy.svg')),
  _FlagCountry('Friesland', 'REG-FRIESLAND',
      assetPath: 'assets/images/flags_insane/REG-FRIESLAND.png', imageUrl: _commons('Flag of Friesland.svg')),
  _FlagCountry('Zeeland', 'REG-ZEELAND',
      assetPath: 'assets/images/flags_insane/REG-ZEELAND.png', imageUrl: _commons('Flag of Zeeland.svg')),
  _FlagCountry('Zanzibar', 'REG-ZANZIBAR',
      assetPath: 'assets/images/flags_insane/REG-ZANZIBAR.png', imageUrl: _commons('Flag of Zanzibar.svg')),
  _FlagCountry('Nunavut', 'REG-NUNAVUT',
      assetPath: 'assets/images/flags_insane/REG-NUNAVUT.png', imageUrl: _commons('Flag of Nunavut.svg')),
  _FlagCountry('Northwest Territories', 'REG-NWT',
      assetPath: 'assets/images/flags_insane/REG-NWT.png', imageUrl: _commons('Flag of the Northwest Territories.svg')),
  _FlagCountry('Yukon', 'REG-YUKON',
      assetPath: 'assets/images/flags_insane/REG-YUKON.png', imageUrl: _commons('Flag of Yukon.svg')),
  _FlagCountry('Prince Edward Island', 'REG-PEI',
      assetPath: 'assets/images/flags_insane/REG-PEI.png', imageUrl: _commons('Flag of Prince Edward Island.svg')),
  _FlagCountry('Nova Scotia', 'REG-NOVASCOTIA',
      assetPath: 'assets/images/flags_insane/REG-NOVASCOTIA.png', imageUrl: _commons('Flag of Nova Scotia.svg')),
  _FlagCountry('New Brunswick', 'REG-NEWBRUNSWICK',
      assetPath: 'assets/images/flags_insane/REG-NEWBRUNSWICK.png', imageUrl: _commons('Flag of New Brunswick.svg')),
  _FlagCountry('Newfoundland and Labrador', 'REG-NEWFOUNDLAND',
      assetPath: 'assets/images/flags_insane/REG-NEWFOUNDLAND.png', imageUrl: _commons('Flag of Newfoundland and Labrador.svg')),
  _FlagCountry('Ontario', 'REG-ONTARIO',
      assetPath: 'assets/images/flags_insane/REG-ONTARIO.png', imageUrl: _commons('Flag of Ontario.svg')),
  _FlagCountry('British Columbia', 'REG-BRITISHCOLUMBIA',
      assetPath: 'assets/images/flags_insane/REG-BRITISHCOLUMBIA.png', imageUrl: _commons('Flag of British Columbia.svg')),
  _FlagCountry('Alberta', 'REG-ALBERTA',
      assetPath: 'assets/images/flags_insane/REG-ALBERTA.png', imageUrl: _commons('Flag of Alberta.svg')),
  _FlagCountry('Manitoba', 'REG-MANITOBA',
      assetPath: 'assets/images/flags_insane/REG-MANITOBA.png', imageUrl: _commons('Flag of Manitoba.svg')),
  _FlagCountry('Saskatchewan', 'REG-SASKATCHEWAN',
      assetPath: 'assets/images/flags_insane/REG-SASKATCHEWAN.png', imageUrl: _commons('Flag of Saskatchewan.svg')),
  _FlagCountry('Texas', 'REG-TEXAS-STATE',
      assetPath: 'assets/images/flags_insane/REG-TEXAS-STATE.png', imageUrl: _commons('Flag of Texas.svg')),
  _FlagCountry('Hawaii', 'REG-HAWAII-STATE',
      assetPath: 'assets/images/flags_insane/REG-HAWAII-STATE.png', imageUrl: _commons('Flag of Hawaii.svg')),
  _FlagCountry('Alaska', 'REG-ALASKA-STATE',
      assetPath: 'assets/images/flags_insane/REG-ALASKA-STATE.png', imageUrl: _commons('Flag of Alaska.svg')),
  _FlagCountry('Tibet Autonomous Region', 'REG-TIBET-CURRENT',
      assetPath: 'assets/images/flags_insane/REG-TIBET-CURRENT.png', imageUrl: _commons('Flag of the Tibet Autonomous Region (PRC).svg')),
  _FlagCountry('Chechnya', 'REG-CHECHNYA',
      assetPath: 'assets/images/flags_insane/REG-CHECHNYA.png', imageUrl: _commons('Flag of the Chechen Republic.svg')),
  _FlagCountry('Tatarstan', 'REG-TATARSTAN',
      assetPath: 'assets/images/flags_insane/REG-TATARSTAN.png', imageUrl: _commons('Flag of Tatarstan.svg')),
  _FlagCountry('Bashkortostan', 'REG-BASHKORTOSTAN',
      assetPath: 'assets/images/flags_insane/REG-BASHKORTOSTAN.png', imageUrl: _commons('Flag of Bashkortostan.svg')),
  _FlagCountry('Yakutia (Sakha)', 'REG-SAKHA',
      assetPath: 'assets/images/flags_insane/REG-SAKHA.png', imageUrl: _commons('Flag of Sakha.svg')),
];

/// Every flag Insane can draw from — historical + regional, and ONLY that;
/// no current sovereign-country flags are mixed in at all.
final List<_FlagCountry> _kExtraFlags = [
  ..._kHistoricalFlags,
  ..._kRegionalImageFlags,
];

/// All guessable flags across every tier, de-duplicated by code.
final Map<String, _FlagCountry> _kAllCountriesByCode = {
  for (final c in [..._kWorldCountries, ..._kExtraFlags]) c.code: c,
};

/// Static reference pool for a difficulty (unordered). For actual gameplay
/// round order, use [_buildRoundOrder].
List<_FlagCountry> _countriesForDifficulty(_FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case _FlagGuessDifficulty.easy:
      return _kEasyCountries;
    case _FlagGuessDifficulty.medium:
    case _FlagGuessDifficulty.hard:
      return _kWorldCountries;
    case _FlagGuessDifficulty.insane:
      return _kExtraFlags;
  }
}

/// The pool wrong-answer choices are drawn from for a difficulty.
List<_FlagCountry> _distractorPoolFor(_FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case _FlagGuessDifficulty.easy:
      return _kEasyCountries;
    case _FlagGuessDifficulty.medium:
    case _FlagGuessDifficulty.hard:
      return _kWorldCountries;
    case _FlagGuessDifficulty.insane:
      return _kExtraFlags;
  }
}

/// Builds the ordered list of flags a round will draw from, one per index.
///   - Easy/Medium: a plain shuffle of their pool.
///   - Hard: every known trap country first (shuffled among themselves),
///     then the rest of the world pool — so trap flags actually get asked
///     about, not just offered as wrong answers.
///   - Insane: historical + regional flags ONLY, shuffled — never a current
///     country.
List<_FlagCountry> _buildRoundOrder(_FlagGuessDifficulty difficulty) {
  switch (difficulty) {
    case _FlagGuessDifficulty.easy:
      return (List<_FlagCountry>.from(_kEasyCountries)..shuffle());
    case _FlagGuessDifficulty.medium:
      return (List<_FlagCountry>.from(_kWorldCountries)..shuffle());
    case _FlagGuessDifficulty.hard:
      final traps = List<_FlagCountry>.from(_kTrapCountries)..shuffle();
      final rest = _kWorldCountries
          .where((c) => !traps.any((t) => t.code == c.code))
          .toList()
        ..shuffle();
      return [...traps, ...rest];
    case _FlagGuessDifficulty.insane:
      return (List<_FlagCountry>.from(_kExtraFlags)..shuffle());
  }
}

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _FlagGuessScoreRecord {
  final double score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const _FlagGuessScoreRecord({
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

  factory _FlagGuessScoreRecord.fromJson(Map<String, dynamic> json) => _FlagGuessScoreRecord(
    score: (json['score'] as num).toDouble(),
    roundsCompleted: json['roundsCompleted'] as int,
    maxRounds: json['maxRounds'] as int,
    bestCombo: json['bestCombo'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _FlagGuessScoreService {
  static const int maxStoredRecords = 20;

  String _keyFor(_FlagGuessDifficulty difficulty) => 'flag_guess_scores_${difficulty.name}';

  /// Records for a difficulty, best score first.
  Future<List<_FlagGuessScoreRecord>> loadRecords(_FlagGuessDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(difficulty));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded
          .map((e) => _FlagGuessScoreRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      // Corrupt or outdated local data shouldn't crash the lobby screen.
      return [];
    }
  }

  /// Appends a finished run and trims to [maxStoredRecords] (dropping the
  /// lowest scores first).
  Future<void> addRecord(_FlagGuessDifficulty difficulty, _FlagGuessScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(difficulty);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(
      _keyFor(difficulty),
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }
}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);

Color _accentFor(_FlagGuessDifficulty d) {
  switch (d) {
    case _FlagGuessDifficulty.easy:
      return const Color(0xFF2FBE73);
    case _FlagGuessDifficulty.medium:
      return const Color(0xFFFF9F1C);
    case _FlagGuessDifficulty.hard:
      return const Color(0xFFFF5A5F);
    case _FlagGuessDifficulty.insane:
      return const Color(0xFF9B5DE5);
  }
}

String _labelFor(_FlagGuessDifficulty d) {
  switch (d) {
    case _FlagGuessDifficulty.easy:
      return 'Easy';
    case _FlagGuessDifficulty.medium:
      return 'Medium';
    case _FlagGuessDifficulty.hard:
      return 'Hard';
    case _FlagGuessDifficulty.insane:
      return 'Insane';
  }
}

/// A soft, elevated white card — the base building block for nearly every
/// piece of chrome in this feature.
class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const _SoftCard({
    super.key,
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

/// A gradient, tactile primary button with a subtle press-scale animation.
class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _GradientButton({
    super.key,
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

/// Tinted gradient wash behind a screen — subtle, accent-colored at the top,
/// fading to the base surface color.
class _ScreenBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ScreenBackground({super.key, required this.accent, required this.child});

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

// ============================================================================
// DIFFICULTY SCREEN (entry point — the only public symbol in this file)
// ============================================================================

/// Difficulty picker for Flag Guess. Easy / Medium / Hard are always
/// playable; Insane is gated behind Premium and opens the paywall sheet
/// when tapped by a non-subscriber.
class FlagGuessDifficultyScreen extends StatelessWidget {
  const FlagGuessDifficultyScreen({super.key});

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
        accent: _accentFor(_FlagGuessDifficulty.hard),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF5A5F), Color(0xFF3E63DD)]),
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
                difficulty: _FlagGuessDifficulty.easy,
                icon: Icons.sentiment_satisfied_alt_rounded,
                onTap: () => _openLobby(context, _FlagGuessDifficulty.easy),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _FlagGuessDifficulty.medium,
                icon: Icons.sentiment_neutral_rounded,
                onTap: () => _openLobby(context, _FlagGuessDifficulty.medium),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _FlagGuessDifficulty.hard,
                icon: Icons.sentiment_very_dissatisfied_rounded,
                onTap: () => _openLobby(context, _FlagGuessDifficulty.hard),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final isPremium = sub.isPremium;
                  if (isPremium) {
                    return _DifficultyCard(
                      difficulty: _FlagGuessDifficulty.insane,
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => _openLobby(context, _FlagGuessDifficulty.insane),
                    );
                  }
                  return FutureBuilder<bool>(
                    future: GameInsaneTrialService.instance.hasUsedTrial('flag_guess'),
                    builder: (context, snapshot) {
                      final trialUsed = snapshot.data ?? false;
                      return _DifficultyCard(
                        difficulty: _FlagGuessDifficulty.insane,
                        icon: Icons.local_fire_department_rounded,
                        locked: trialUsed,
                        onTap: () async {
                          if (trialUsed) {
                            SubscriptionSheet.show(context, triggerContext: 'flag_guess_insane');
                          } else {
                            await GameInsaneTrialService.instance.markTrialUsed('flag_guess');
                            if (context.mounted) _openLobby(context, _FlagGuessDifficulty.insane);
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
              colors: [Color(0xFFFF5A5F), Color(0xFF3E63DD)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.emoji_flags_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FLAG QUIZ',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
              const Text('Flag Guess',
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text('Name the country from its flag before time runs out.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  void _openLobby(BuildContext context, _FlagGuessDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FlagGuessLobbyScreen(difficulty: difficulty)),
    );
  }
}

int _diffLevel(_FlagGuessDifficulty d) {
  switch (d) {
    case _FlagGuessDifficulty.easy:
      return 1;
    case _FlagGuessDifficulty.medium:
      return 2;
    case _FlagGuessDifficulty.hard:
      return 3;
    case _FlagGuessDifficulty.insane:
      return 4;
  }
}

class _DifficultyCard extends StatelessWidget {
  final _FlagGuessDifficulty difficulty;
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
                      Text(_labelFor(difficulty),
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

class _FlagGuessLobbyScreen extends StatefulWidget {
  final _FlagGuessDifficulty difficulty;

  const _FlagGuessLobbyScreen({super.key, required this.difficulty});

  @override
  State<_FlagGuessLobbyScreen> createState() => _FlagGuessLobbyScreenState();
}

class _FlagGuessLobbyScreenState extends State<_FlagGuessLobbyScreen> {
  final _service = _FlagGuessScoreService();
  late Future<List<_FlagGuessScoreRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(widget.difficulty);
    });
  }

  Future<void> _startGame() async {
    await GameAdService.instance.requestStartGame();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FlagGuessGameScreen(difficulty: widget.difficulty)),
    );
    // The game screen saves its record on game-over before popping back
    // here, so a fresh load will include the just-finished run.
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(widget.difficulty);
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
        accent: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _buildLobbyHeader(accent),
                const SizedBox(height: 22),
                Expanded(child: _buildHistory(accent)),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Start Game',
                  icon: Icons.play_arrow_rounded,
                  color: accent,
                  onPressed: _startGame,
                ),
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
          child: const Icon(Icons.emoji_flags_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DIFFICULTY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _kMuted)),
              const SizedBox(height: 2),
              Text('${_labelFor(widget.difficulty)} Mode',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(Color accent) {
    return FutureBuilder<List<_FlagGuessScoreRecord>>(
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
                const Text('No runs yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                const SizedBox(height: 4),
                Text('Play a round to start your leaderboard',
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
                Text('LEADERBOARD',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                Text('${records.length} run${records.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: _kFaint, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RecordTile(
                  rank: i + 1,
                  record: records[i],
                  accent: accent,
                ),
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
  final _FlagGuessScoreRecord record;
  final Color accent;

  const _RecordTile({required this.rank, required this.record, required this.accent});

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
                : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.score.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
                const SizedBox(height: 2),
                Text(
                  '${record.roundsCompleted}/${record.maxRounds} rounds · combo ${record.bestCombo} · ${_formatDate(record.playedAt)}',
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

enum _RoundPhase { prep, playing, revealed }

class _FlagGuessGameScreen extends StatefulWidget {
  final _FlagGuessDifficulty difficulty;

  const _FlagGuessGameScreen({super.key, required this.difficulty});

  @override
  State<_FlagGuessGameScreen> createState() => _FlagGuessGameScreenState();
}

class _FlagGuessGameScreenState extends State<_FlagGuessGameScreen> {
  static const int _maxRoundsCap = 30;
  static const double _maxScorePerRound = 10.0;

  // How long the post-answer "revealed" state stays up before advancing.
  // Wrong answers get longer so the correct answer is actually readable.
  static const Duration _correctRevealDuration = Duration(milliseconds: 1400);
  static const Duration _wrongRevealDuration = Duration(milliseconds: 2200);

  late List<_FlagCountry> _rounds;
  late final int _maxRounds;

  int _roundIndex = 0;
  double _totalScore = 0;
  double _bestRoundScore = 0;
  int _combo = 0;

  _RoundPhase _phase = _RoundPhase.prep;
  int _prepCountdown = 3;
  Timer? _prepTimer;

  double _timeLimit = 10;
  double _remaining = 10;
  Timer? _playTimer;
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _revealTimer;

  _FlagCountry? _answer;
  List<_FlagCountry> _choices = [];
  _FlagCountry? _selected;
  double? _lastRoundScore;

  bool _gameOver = false;
  String? _endReason; // 'wrong' | 'timeout' | 'complete'
  bool _recorded = false;

  Color get _accent => _accentFor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    final order = _buildRoundOrder(widget.difficulty);
    _maxRounds = min(_maxRoundsCap, order.length);
    _rounds = order.take(_maxRounds).toList();
    _beginPrep();
    // Kick off every image-backed flag's download right away instead of
    // waiting for each round to need it — by the time a round actually
    // shows an image flag it's very likely already sitting in Flutter's
    // image cache, so it appears instantly instead of loading live.
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheRoundImages());
  }

  void _precacheRoundImages() {
    if (!mounted) return;
    for (final country in _rounds) {
      // Bundled assets render instantly already — nothing to precache.
      if (country.hasLocalAsset || !country.hasImage) continue;
      precacheImage(NetworkImage(country.imageUrl!), context).catchError((_) {
        // A single bad/slow URL shouldn't block the others — the in-round
        // errorBuilder still covers a genuine failure at display time.
      });
    }
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _playTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  /// 10s -> -1s per round, floored per difficulty. Easy stays fixed at 10s.
  double _timeLimitForRound(int index) {
    switch (widget.difficulty) {
      case _FlagGuessDifficulty.easy:
        return 10.0;
      case _FlagGuessDifficulty.medium:
        return max(2.0, 10.0 - index);
      case _FlagGuessDifficulty.hard:
      case _FlagGuessDifficulty.insane:
        return max(1.0, 10.0 - index);
    }
  }

  // ── Round lifecycle ─────────────────────────────────────────────────────

  void _beginPrep() {
    setState(() {
      _phase = _RoundPhase.prep;
      _prepCountdown = 3;
    });
    _prepTimer?.cancel();
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _prepCountdown--);
      if (_prepCountdown <= 0) {
        t.cancel();
        _startRound();
      }
    });
  }

  void _startRound() {
    final answer = _rounds[_roundIndex];
    final choices = _buildChoices(answer);
    final limit = _timeLimitForRound(_roundIndex);

    setState(() {
      _answer = answer;
      _choices = choices;
      _selected = null;
      _lastRoundScore = null;
      _timeLimit = limit;
      _remaining = limit;
      _phase = _RoundPhase.playing;
    });

    _stopwatch
      ..reset()
      ..start();
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
      final remaining = _timeLimit - elapsed;
      if (remaining <= 0) {
        t.cancel();
        _stopwatch.stop();
        setState(() => _remaining = 0);
        _enterReveal(correct: false);
        return;
      }
      setState(() => _remaining = remaining);
    });
  }

  /// Correct answer + up to 3 wrong ones, biased toward lookalike traps
  /// where the data has them (Hard's country pairs).
  List<_FlagCountry> _buildChoices(_FlagCountry answer) {
    final chosen = <_FlagCountry>[answer];

    final similar = _kSimilarFlagGroups[answer.code] ?? const <String>[];
    for (final code in similar) {
      if (chosen.length >= 4) break;
      final c = _kAllCountriesByCode[code];
      if (c != null && !chosen.any((x) => x.code == c.code)) chosen.add(c);
    }
    if (chosen.length < 4) {
      for (final entry in _kSimilarFlagGroups.entries) {
        if (chosen.length >= 4) break;
        if (entry.value.contains(answer.code)) {
          final c = _kAllCountriesByCode[entry.key];
          if (c != null && !chosen.any((x) => x.code == c.code)) chosen.add(c);
        }
      }
    }

    final rest = _distractorPoolFor(widget.difficulty)
        .where((c) => !chosen.any((x) => x.code == c.code))
        .toList()
      ..shuffle();
    for (final c in rest) {
      if (chosen.length >= 4) break;
      chosen.add(c);
    }

    chosen.shuffle();
    return chosen;
  }

  void _onSelect(_FlagCountry choice) {
    if (_phase != _RoundPhase.playing) return;
    _playTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
    final correct = choice.code == _answer!.code;

    double? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = double.parse(raw.toStringAsFixed(1));
    }

    setState(() {
      _selected = choice;
      _lastRoundScore = score;
      if (correct) {
        _totalScore += score!;
        if (score > _bestRoundScore) _bestRoundScore = score;
        _combo++;
      }
    });

    HapticFeedback.selectionClick();
    _enterReveal(correct: correct);
  }

  /// Holds the flag + result on screen for a fixed, clearly-visible duration,
  /// then advances to the next round (or ends the game on a miss).
  void _enterReveal({required bool correct}) {
    setState(() => _phase = _RoundPhase.revealed);
    _revealTimer?.cancel();
    _revealTimer = Timer(correct ? _correctRevealDuration : _wrongRevealDuration, () {
      if (!mounted) return;
      if (!correct) {
        _finishGame('wrong');
        return;
      }
      if (_roundIndex + 1 >= _maxRounds) {
        _finishGame('complete');
      } else {
        setState(() => _roundIndex++);
        _beginPrep();
      }
    });
  }

  void _finishGame(String reason) {
    if (_gameOver) return;
    _prepTimer?.cancel();
    _playTimer?.cancel();
    _revealTimer?.cancel();
    setState(() {
      _gameOver = true;
      _endReason = reason;
    });
    GameAdService.instance.notifyGameFinished();
    _saveRecord(reason);
  }

  Future<void> _saveRecord(String reason) async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _FlagGuessScoreService().addRecord(
        widget.difficulty,
        _FlagGuessScoreRecord(
          score: double.parse(_totalScore.toStringAsFixed(1)),
          roundsCompleted: reason == 'complete' ? _maxRounds : _roundIndex,
          maxRounds: _maxRounds,
          bestCombo: _combo,
          playedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Local-storage hiccups shouldn't block showing the result screen.
    }
  }

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _combo = 0;
      _gameOver = false;
      _endReason = null;
      _recorded = false;
      _rounds = _buildRoundOrder(widget.difficulty).take(_maxRounds).toList();
    });
    _beginPrep();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheRoundImages());
  }

  // ── UI ───────────────────────────────────────────────────────────────────

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
            Text('${_labelFor(widget.difficulty)} Mode',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
        actions: [_ScoreBadge(total: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: _ScreenBackground(
        accent: _accent,
        child: SafeArea(
          child: _gameOver ? _buildGameOver() : _buildPlayArea(),
        ),
      ),
    );
  }

  Widget _buildPlayArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 56, 0, 0),
      child: _phase == _RoundPhase.prep ? _buildPrep() : _buildRound(),
    );
  }

  Widget _buildPrep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ROUND ${_roundIndex + 1} OF $_maxRounds',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            key: ValueKey(_prepCountdown),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent.withOpacity(0.85), _accent],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Text(
                _prepCountdown > 0 ? '$_prepCountdown' : 'GO',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Get ready...', style: TextStyle(fontSize: 14, color: _kMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRound() {
    final ratio = (_remaining / _timeLimit).clamp(0.0, 1.0);
    final barColor = Color.lerp(const Color(0xFFFF5A5F), const Color(0xFF2FBE73), ratio)!;
    final revealed = _phase == _RoundPhase.revealed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUND ${_roundIndex + 1} / $_maxRounds',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              if (_combo > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFFF5A5F)),
                    const SizedBox(width: 3),
                    Text('$_combo',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFFF5A5F))),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: revealed
                ? _buildResultBanner(key: const ValueKey('result'))
                : _buildTimerBar(ratio, barColor, key: const ValueKey('timer')),
          ),
          const SizedBox(height: 18),
          Expanded(child: Center(child: _buildFlagVisual())),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: _choices.map((c) => _buildChoiceButton(c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(double ratio, Color barColor, {Key? key}) {
    return Column(
      key: key,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            backgroundColor: Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${_remaining.toStringAsFixed(1)}s',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: barColor)),
        ),
      ],
    );
  }

  /// Clear, high-contrast result banner shown while `_phase == revealed`.
  /// States the correct answer by name on a miss — no emoji clutter, the
  /// flag itself is already on screen.
  Widget _buildResultBanner({Key? key}) {
    final correct = _selected != null && _selected!.code == _answer!.code;
    final color = correct ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);

    return TweenAnimationBuilder<double>(
      key: key,
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
              child: Icon(correct ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? 'Correct! +${_lastRoundScore!.toStringAsFixed(1)}' : 'Wrong',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 2),
                    Text('Answer: ${_answer!.name}',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a country's flag with a three-way fallback chain:
  ///   1. Local bundled asset, if one exists (instant, offline) --
  ///      see download_insane_flags.py for how to generate these.
  ///   2. If the asset is missing (script hasn't been run yet) or fails to
  ///      load for any reason, falls back to the network image instead of
  ///      just showing a broken-flag icon -- so nothing regresses for
  ///      anyone who hasn't run the download script.
  ///   3. If there's no image at all, the emoji.
  static Widget _buildFlagImageOrEmoji(
      _FlagCountry country, {
        required double width,
        required double height,
        required double emojiSize,
      }) {
    Widget emojiFallback() => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Text(country.emojiFallback, style: TextStyle(fontSize: emojiSize)),
    );

    Widget networkFallback() {
      if (!country.hasImage) return emojiFallback();
      return Image.network(
        country.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        // Last resort: a mistyped/renamed Commons file title shouldn't
        // show a generic broken-image icon when a real emoji flag was
        // available the whole time -- fall all the way back to that.
        errorBuilder: (context, error, stack) => emojiFallback(),
      );
    }

    if (country.hasLocalAsset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          country.assetPath!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stack) => networkFallback(),
        ),
      );
    }
    if (country.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: networkFallback(),
      );
    }
    return Text(country.emojiFallback, style: TextStyle(fontSize: emojiSize));
  }

  Widget _buildFlagVisual() {
    final country = _answer!;
    final Widget visual = _buildFlagImageOrEmoji(country, width: 220, height: 147, emojiSize: 92);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(country.hasImage ? 18 : 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(country.hasImage ? 24 : 200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 28, offset: const Offset(0, 12)),
            ],
          ),
          child: visual,
        ),
        if (country.era != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: _kInk.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
            child: Text(country.era!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceButton(_FlagCountry choice) {
    Color bg = Colors.white;
    Color fg = _kInk;
    Color border = Colors.black.withOpacity(0.04);

    if (_phase == _RoundPhase.revealed) {
      final isAnswer = choice.code == _answer!.code;
      final isSelected = _selected?.code == choice.code;
      if (isAnswer) {
        bg = const Color(0xFF2FBE73);
        border = const Color(0xFF2FBE73);
        fg = Colors.white;
      } else if (isSelected) {
        bg = const Color(0xFFFF5A5F);
        border = const Color(0xFFFF5A5F);
        fg = Colors.white;
      }
    }

    return GestureDetector(
      onTap: () => _onSelect(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(choice.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }

  Widget _buildGameOver() {
    final completed = _endReason == 'complete';
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
              child: Icon(completed ? Icons.emoji_events_rounded : Icons.flag_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(completed ? 'All Rounds Complete!' : 'Game Over',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 6),
            if (!completed && _answer != null)
              Text('Answer: ${_answer!.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kMuted)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text(_totalScore.toStringAsFixed(1),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                const Text('TOTAL SCORE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Rounds', value: '${completed ? _maxRounds : _roundIndex}/$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Best', value: _bestRoundScore.toStringAsFixed(1)),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Combo', value: '$_combo'),
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
  final double total;
  final double best;
  final Color accent;

  const _ScoreBadge({required this.total, required this.best, required this.accent});

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
            Text(total.toStringAsFixed(1),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            Text('best ${best.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
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
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}