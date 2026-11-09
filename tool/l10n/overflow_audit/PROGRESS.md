# Audit progress

Started 2026-11-05. Continue from the first unchecked step.

- [x] Quiz card subtitle shortened in all 24 languages (reviewed.tsv) — "Today's quiz is waiting!" / "Completed today!"
- [x] Debug hooks: `[OVERFLOW]` log in main.dart, `lib/l10n/l10n_audit.dart`
- [ ] Inventory: screens_trips.json, screens_countries.json, screens_explore_flights.json
- [ ] drive.py run over every inventory entry × 24 languages → results.jsonl
- [ ] Fix every overflow location (file:line) found
- [ ] Re-run flagged entries, confirm 0 overflows
- [ ] Revert `englishOnly` to true before committing (translations not published yet)

- [ ] Code-side pass: 12 agents overflow-proofing lib/ files in groups (fix_brief in session scratchpad; groups = all UI files split by size). Build only after all finish.

## Notes
- 2026-11-05: 12 parallel agents applied static overflow-proofing (Flexible/ellipsis/FittedBox) across ~230 UI files, split into groups by size. Their "translation too long" lists go in `too_long.md`.
- Phone must stay unlocked with Travelog in front (Developer options → Stay awake while charging). drive.py waits if locked.
- First device pass: `screens_main.json` (5 main tabs) × 24 languages.
- 2026-11-06 01:30: all 12 static fix groups finished (G12 covered only 4 of its files; the fork session fixed the rest). Build compiles. Device audit runs in tiers:
  - `drive.py --tier 1` = el, fr, de, id, ru, vi, th, ar on every runnable entry (high risk first). Log: `run_tier1.log`.
  - then `drive.py --tier 2` = the other 16 languages on high-risk entries (`--all` for every entry).
  - Entries whose path has `tap_desc` / `tap_first_list_item` steps wait for `calib.json` coordinates (15 calibrated so far; ~90 descriptions left).
  - The fork session also ran drive.py 00:45–01:21 (now stopped). Results from that window may be mixed; re-run with `--retry` at the end.
- `too_long.md`: labels in tight spaces; 457 translations shortened in reviewed.tsv (done).
- 02:00: untranslated sweep (33 display sites, 24 new keys) and dropdown isExpanded sweep (28 dropdowns) done. Fixed cities_screen.dart add-city dialog dropdowns (first device-found overflow). New APK + catalogs installed; tier-1 run resumed (driver output appended to run_tier1.log).
- `python -I summary.py` groups results by overflow location (file:line), untranslated text and nav failures.
- After tier 1 finishes: `drive.py --tier 1` again (picks up newly resolvable entries), then `--retry` for entries with overflows after fixing, then `--tier 2`.
- 2026-11-05: a build run while agents were editing failed, and `adb install` then put the OLD apk (no audit hook) on the phone. Always check the build printed "Built ..." before installing.
- The driver detects app start by switching to English (`[AUDIT] ready en`), since the saved language can be anything.
- Keep the phone on charger with the app in front; the driver waits if the phone is locked and never unlocks it.
- 02:30: `tap_first_list_item` heuristic was tapping the sort dropdown (open dropdown menus keep the old language → false "untranslated"). Tightened to wide+tall cards; results of those entries removed and re-run.
- Visual (not an overflow error, check in English too): UNESCO sites screen — the big "UNESCO" title sits under the round back button at top-left.
- 03:10: nav-path agent fixed 15 failing entries, made 5 unsafe, rewrote 149 icon steps to heuristic-friendly descriptions (46 still need calibration). Fixed-height sweep: 5 fixes (travelog_games, flight_hub, cities_share, countries_share, world_discover). top_picks_menu row height → minHeight (ar/th 3px overflow).
- drive.py now supports {"type_text": "..."} for search fields.
- NEXT after current tier-1 pass: rebuild APK (new fixes since 02:00 build), install, then `drive.py --tier 1 --retry`.
- 06:00: second nav pass fixed ~41 entries (tiers screens open from the add icon next to "Rating Tiers" — earlier tiers "passes" were false passes, re-run them), 28 still need calib.json coordinates (FABs, inner-list swipes, dialog radios). FAB heuristic y window widened to 2250.
- So far 0 open overflow locations after fixes (cities add-city dialog, top_picks row both re-checked clean). "Untranslated" hits from open dropdown menus are artifacts (a popup route keeps the language it opened in).

## Paused 2026-11-06 (user asked to stop; resume later)
State: tier-1 `--retry` pass stopped partway (≈190 results kept in results.jsonl). All fixes so far are uncommitted in the working tree; `englishOnly` is still false locally.
To resume:
1. `adb connect 192.168.0.6:5555`; phone on charger, Travelog in front.
2. Free disk space on C: first (it hit 0 bytes once; ~670 MB free when paused). The debug APK was deleted to free space — rebuild: `flutter build apk --debug`, install, push `build/l10n/*.json` to the app's `files/l10n/` (see README).
3. `python -I tool/l10n/overflow_audit/drive.py --tier 1 --retry >> tool/l10n/overflow_audit/run_tier1.log 2>&1` (skips finished entries).
4. Add calib.json coordinates for the ~28 entries flagged needs_calibration, then `--retry` again.
5. `--tier 2` (other 16 languages, high-risk entries; `--all` for everything).
6. Fix any overflow from `summary.py`, re-run those with `--only`.
7. Before committing: set `englishOnly = true` again (translations not published), drop the debug-only hooks only if unwanted (they're kDebugMode-guarded).

## Handoff 2026-11-06 17:30 (emulators instead of the phone; the user needs the phone)
- Language switch speed-up: `AppLocale.keepCatalogs` (debug-only, set by `L10nAudit.start`) keeps applied catalogs in memory, so a switch back skips the multi-MB parse. Analyzer clean; not yet measured on a device.
- drive.py: `--shard i/n` splits the entry list across devices; device serial via env `AUDIT_DEVICE` (default is the old phone IP). Plan: 3 emulators, each `--shard i/3` (see the tier commands below).
- AVDs audit1..audit4 exist in `%USERPROFILE%\.android\avd` (android-36.1 google_apis_playstore x86_64, 1080x2340, RAM 2560MB, 3 cores). Set `ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk` before starting the emulator — the system env points at a wrong C:\AndroidSDK_New. Ports 5554/5556/5558. After boot: `wm density 450`, animations 0, `svc power stayon true`.
- `build/overflow_audit/appdata.tar` = the phone's app data (no caches). Firebase sign-in does NOT carry over (keystore-encrypted), so the user signs in with Google on each emulator.
- `setup_emu.sh <serial>` (Git Bash): install APK, unpack appdata.tar, push catalogs to files/l10n, launch.
- PC memory is tight (27GB, uptime since 10-20, ~3-4GB available). Running the Gradle build together with emulators stalled it for hours: build first, then start emulators. A reboot frees a lot.
- APK: `android/gradlew assembleDebug` was running at handoff; if `build/app/outputs/flutter-apk/app-debug.apk` is missing, run `flutter build apk --debug` with no emulators running.
- Calibration (calib.json) coordinates were taken on the phone at 1080x2340/450dpi; emulators use the same size+density, but spot-check one tap_desc entry first.
- Results kept at handoff (results.jsonl): 178 entries — 129 checked OK in the 8 tier-1 languages (el fr de id ru vi th ar), 49 navigation failures (paths since fixed; need `--retry`), 0 open overflows. The 2 overflows found earlier (cities_screen add-city dropdowns, top_picks_menu row height) are fixed and re-checked. ~230 UI files of static fixes + 457 shortened translations + 24 new keys are in the working tree, uncommitted.
- Do NOT re-run those 129 with all languages. Run per shard: `--tier 1 --retry --shard i/3` (remaining tier-1 entries + nav failures), then `--tier 2 --all --shard i/3` (the other 16 languages on every entry). Tier keys keep the two passes separate in results.jsonl.
- **STATUS.md is the per-screen source of truth**: every one of the 647 entries by state (overflow / nav_failed / needs_calibration / partial with checked+missing languages / not_started / done / unsafe / no_path). Regenerate with `python -I tool/l10n/overflow_audit/status.py` after every run. At handoff: 0 overflow, 46 nav_failed, 36 needs_calibration, 127 partial (8 tier-1 langs), 382 not_started, 2 done, 47 unsafe, 7 no_path.
- `build/l10n/` had been wiped; regenerated with `python -I tool/l10n/build.py` (same hashes as the bundled manifest). drive.py and the catalog push need it.

## 2026-11-06 20:45 — RAM cleanup, PC reboot
- status.py re-run: counts unchanged from the handoff above. APK exists (17:14); `lib/screens/badge_share.dart` changed at 17:16 is NOT in it → re-check that screen with `--only` after the next rebuild.
- RAM was 1.2 GB free: IPinside LWS (I3GMainSvc, 208k handles) leaked ~6.5 GB of kernel pool. Uninstalled 11 Korean banking security modules (IPinside, Veraport, Wizvera PM, AhnLab Safe Tx, INISAFE, CrossEX, AnySign, MagicLine, NTSMagicXML, MarkAny, RAON K, Rexpert). TouchEn nxKey uninstaller failed — remove after reboot via Settings → Apps.
- After reboot: emulators run (audit2 lost its virtual Wi-Fi once; fixed with `cmd wifi connect-network AndroidWifi open`). The user signs in with the premium account, so no ad code is needed.
- New user rules (also failures, not just overflow): (1) labels that render tiny because FittedBox/scaleDown shrinks a long translation (bg menu tile "Дневник на пътуването") get a shorter natural rewrite; (2) feature names left in English ("CountryDex" in zh) get localized/paraphrased (国家图鉴). A background agent is doing a static pass over reviewed.tsv for both.
- 22:20: running the phone and an emulator at the same time stalls the emulator (user found this). Plan: phone alone at night, emulator-5558 alone in the daytime. The phone runs tier 1 --retry then tier 2 --all (no shard); switch to emulator-5558 only when the user says so (stop the phone driver first, then `AUDIT_DEVICE=emulator-5558` with the same commands). `night_then_emu.sh` (timed switch) exists but the user doesn't want a timed switch. Logs: run_phone.log, run_emu5558.log. calib.json gained the Countries stat-card arrow (905,1830); next to calibrate: city stat-card arrow (32 entries), trip-card sparkle (17), Rating Tiers + (13).
- 22:50 NEW METHOD (user's idea): `screen_pass.sh` = every screen once with `max` (make_max.py: widest translation of each string across all languages, loaded by a debug hook `AppLocale.debugShowCatalog` via l10n_audit_cmd "max"), `ar` and `th` (results tier 3), then only overflowing screens in all 23 languages. ~47 s/screen, 553 screens ≈ 7 h. drive.py `find()` now falls back to whole-word match (merged Flutter labels like "Next Adventure"), and failed/icon-description entries run last. New APK (22:47, includes translation fixes) + catalogs installed on the phone. Log: run_192.168.0.6.log. Run: `AUDIT_DEVICE=<serial> sh tool/l10n/overflow_audit/screen_pass.sh` (skips done screens).
- Rebooting the PC now. Next: steps 2–9 of the original plan (start audit1–3 on 5554/5556/5558, setup_emu.sh, Google sign-in by the user, calib spot-check, `--tier 1 --retry --shard i/3`, then `--tier 2 --all --shard i/3`).

## 2026-11-09 — paused by the user (resume when they say "ㄱㄱ")
- Screen pass (max,ar,th) over 553 screens finished 11-07 07:06: 411 reached, 0 overflow; 143 nav failures (24 icon steps, 119 "not found"). status.py does not count tier 3 yet (shows them as not_started).
- Phone on wireless adb via its hotspot: `172.25.51.45:5555` (USB serial R5KL20LRNSN). If the phone rebooted, plug USB and `adb tcpip 5555; adb connect 172.25.51.45:5555`.
- drive.py: find() now also matches the `hint` attribute and case-insensitively; when vertical search fails it returns to the top and swipes each wide horizontal scrollable left (`find_sideways`). Slow (up to ~3 min/screen).
- Test of 5 failed screens (stopped partway): unesco_stats_continent_s_america ✅, activities_list_zoos ✅ (182 s), 0 overflow; country_detail, cities_screen_search, landmarks_list_sort_dropdown not yet run.
- 91 "untranslated" hits: all 91 exist in the catalogs (63 messages, 28 country names) → code-side display sites or popup artifacts. A background agent is checking/fixing the display sites (respawn, border_chain, which_is_farther, social badges, flight frequency, ...).
- RESUME: `cd /c/Users/ahnlee123/Desktop/jidoapp && AUDIT_DEVICE=172.25.51.45:5555 python -I tool/l10n/overflow_audit/drive.py --langs max,ar,th --retry >> tool/l10n/overflow_audit/run_172.25.51.45.log 2>&1` (re-runs only the failed tier-3 screens). Then calibrate the remaining icon steps, rebuild APK for the agent's tr() fixes + badge_share, re-check those screens, set englishOnly=true, commit.
- Untranslated agent done: real fixes (countryName()/tr() at display only) in respawn.dart, border_chain.dart (+ "WHICH COUNTRY BORDERS" prompt tr), recommendations_screen.dart, landmarks_list_screen.dart (islands), social badges_screen.dart, social category_list_screen.dart, country_selection_screen.dart (continent header). Analyzer: 0 errors. Artifacts (open popups) / intentional (city names, university short names, native language names) left as is. which_is_farther strings all use tr() — unexplained; re-check on device after the next APK build.

## 2026-11-09 ~11:45 — paused again by the user
- New APK (11:15, includes the untranslated fixes) installed on the phone.
- Blind `--retry` stopped after 1 screen (paths are wrong, not just off-screen). A path-fix agent drove the phone for ~25 min: fixed paths in screens_*.json / calib.json / unsafe marks; 13 new tier-3 runs, 11 screens newly reached, 0 overflow. Still failing (latest tier-3 per id): 135.
- RESUME: continue the path fixing on the phone (same approach: read the screen's file, find the real route on the phone, rewrite `path`, verify with `drive.py --langs max,ar,th --only <ids>`, mark non-premium/needs-friend/destructive screens unsafe with unsafe_reason).

## 2026-11-09 13:15 — untranslated-text pass done
- `tool/l10n/scan_untranslated.py` → `tool/l10n/untranslated_report.md`: literal tr() without translation 0; literals missing from the catalog 15 (brands/acronyms/parser noise); ~1,300 data literals + raw-variable display sites reviewed by 4 agents (badges/stats/games/other, brief in tool/l10n/untranslated_brief.md).
- 16 display-site fixes (map_lab country picker + localized search, flag_guess displayName, social badges level chip, passport_visa_detail, onboarding picker, historical_empire title, ai_summary ×3, flight_frequency_stats ×3, flight_overview_stats tooltip, overview_stats tooltip) + the earlier 9. Analyzer 0 errors.
- reviewed.tsv in all 24 languages: 52 historical/regional flag names, N/A, Decor (ko 인테리어 → 장식). build.py --check: 0 untranslated.
- New APK 12:06 + catalogs installed on the phone. Verified 44 screens using the fixed files in ko (untranslated) + de (overflow): 44/44 reached, 0 untranslated, 0 overflow.
- Still open: overflow nav failures (~135, path fixing on the phone), englishOnly=true before commit, publish.py not run, nothing committed.
