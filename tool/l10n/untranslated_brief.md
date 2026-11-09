# Brief: find and fix UI text that stays English in other languages

Flutter app at C:\Users\ahnlee123\Desktop\jidoapp. UI text is translated at display
time: `tr('English')` for UI strings and `AppLocale.instance.countryName(name)` for
country names (lib/l10n/app_localizations.dart). `tr()` also works on variables
(`tr(item.title)`), and the catalogs already contain almost every English string.
`trSeatClass()` exists for cabin classes.

`tool/l10n/untranslated_report.md` (from `python -I tool/l10n/scan_untranslated.py`)
lists, per file:
- section C: places that draw a variable raw, e.g. `Text(item.title)`.
- section B2: English literals that are NOT wrapped in tr() where they are written,
  e.g. `title: 'GDP'` in a data list. They are in the catalog, so they are fine IF the
  place that displays them calls tr() on the value — and a bug if it doesn't.

`tool/l10n/untranslated_groups.json` assigns files to groups. Work ONLY on the files
of your group (other agents own the other groups at the same time), plus the widget
files that display your group's data if they're not in another group — if a display
site is in another group's file, list it in your report instead of editing it.

For each flagged item decide:
- BUG: the user sees English UI text in another language → wrap at the DISPLAY site:
  `Text(tr(item.title))`, `Text(countryName(c))`. Prefer fixing the one display site over
  wrapping hundreds of data literals.
- OK: already translated where displayed, or it's a proper/entity name that must stay as
  is (city names, landmark names, airport/airline names, person names, brands like
  Starbucks/Klook, acronyms like BRICS/ASEAN/GDP if the catalog has no entry, IATA codes,
  user-written text).
- Never tr() values that are used as keys, ids, filters, sort/compare values, map
  lookups, Firestore fields, or anything persisted — only the String handed to Text /
  label / tooltip / hint. If a value is both shown and compared, translate only in the
  Text.

Rules: minimal edits in the surrounding style; keep each file's line endings (many are
CRLF — edit with a byte-safe method; never `sed -i`); no builds, no git, no catalog
edits. Run `flutter analyze <your changed files>` at the end and fix errors you caused.

Report (under 250 words): number of BUG sites fixed with file:line, display sites in
other groups' files you found, anything unsure, analyzer result.
