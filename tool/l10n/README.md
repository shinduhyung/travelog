# App translations

English is the source language. Each other language lives in its own folder
here. `build.py` turns those folders into one catalog per language, and
`publish.py` uploads them to Firebase Storage (`l10n/` in the
`proboscis-2025` bucket). The app ships only a small manifest
(`assets/l10n/languages.json`), downloads the selected language once, checks
its SHA-256 and saves it on the device. Until then it shows English. Adding a
language needs no Dart changes and does not grow the app.

At startup the app also fetches the published manifest. If it is newer than
the bundled one, new languages and translation fixes reach installed apps
without a store update. A language with `"bundled": true` in its `meta.json`
is also packed into the app, for languages that must work offline on first
launch.

```
tool/l10n/
  build.py           builds assets/l10n/* and registers languages with iOS
  translate.py       prepares/merges bulk translation chunks
  GUIDE.md           rules for whoever translates the chunks
  <lang>/
    meta.json        native name, English name, Natural Earth name field
    translated.json  English → translation (bulk)
    reviewed.tsv     hand-reviewed UI strings; these win over translated.json
    countries.json   optional country-name overrides
    style.md         optional language-specific style rules
    InfoPlist.strings  optional iOS permission prompts
```

Language codes are BCP 47: `ja`, `es`, `zh-Hans`, `zh-Hant`, `pt-BR`.

## Adding a language

1. `python tool/l10n/translate.py prepare ja`
   creates `ja/meta.json` (fill in the names) and `ja/work/in/*.json`.
2. Translate every chunk into `ja/work/out/` following `GUIDE.md`
   (optionally add `ja/style.md`). Translate
   `ios/Runner/en.lproj/InfoPlist.strings` into `ja/InfoPlist.strings`.
3. `python tool/l10n/translate.py merge ja`
   validates the output and writes `ja/translated.json`. Fix anything it
   reports, then rerun.
4. `python tool/l10n/build.py --check`
   writes the catalogs to `build/l10n/`, updates the bundled manifest, adds
   the language to iOS and lists any UI strings still untranslated.
5. `python tool/l10n/publish.py` uploads changed catalogs, then the manifest
   (needs `gcloud auth login` with write access). Already-uploaded files are
   skipped.
6. Check the app with the new language selected in Settings.

`flutter test test/l10n_live_firebase_test.dart --tags live --run-skipped`
checks the published Korean catalog end to end against the real bucket.

Country names come from `assets/custom.geo.json` (Natural Earth), which has
names for about 25 languages. Set `geo_field` in `meta.json` accordingly.

## Updating after content changes

New landmarks or new `tr('...')` strings: run `translate.py prepare <lang>`
again. It only prepares strings that language is still missing. Then do
steps 2–4.

## Things to check per language

- Plurals: code like `'$n ${n == 1 ? 'city' : 'cities'}'` is English-only
  grammar. Languages with several plural forms (ru, pl, ar) need these
  rewritten.
- Right-to-left scripts (ar, he, fa, ur) need a layout pass.
- Fonts: Poppins has no Thai, Devanagari or Arabic glyphs.
