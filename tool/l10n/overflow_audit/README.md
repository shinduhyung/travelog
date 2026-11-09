# Overflow & untranslated audit (all languages)

Checks every screen, tab, dialog and bottom sheet of the app in all 24
languages on a real phone, and records each `RenderFlex overflowed` with the
widget's file:line, plus on-screen text still in English.

## How it works

- Debug build only. `lib/l10n/l10n_audit.dart` watches
  `<app support>/l10n_audit_cmd`; writing a language code there switches the
  app language in place (navigation kept), reassembles so every Row/Column
  reports overflow again, and logs `[AUDIT] ready <code>`.
- `lib/main.dart` FlutterError handler logs `[OVERFLOW] ... @ lib/...:line`.
- `screens*.json` — inventory: how to reach each screen from the main tabs
  (English labels), whether to scroll, static risk notes.
- `drive.py` — follows each path in English, then cycles all languages on that
  screen, swipes through it, and appends results to `results.jsonl`.
  Resumable: entries already in `results.jsonl` are skipped.

## Setup on the phone (192.168.0.6)

1. `AppLocale.englishOnly = false` locally (do not commit while unpublished).
2. `python tool/l10n/build.py --check`, `flutter build apk --debug`, install.
3. Push `build/l10n/*.json` into `files/l10n/` of the app (run-as).

## Progress

See `PROGRESS.md` (updated as the audit runs).
