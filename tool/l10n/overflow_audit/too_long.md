# Translations to shorten (labels in tight spaces)

Reported by the static fix agents; shorten these in reviewed.tsv per language if they still look bad on device.

## G1
- lib/screens/city_map_screen.dart:118-120 "Size by Population" / "Size by Duration" / "Size by Visit Count"
- lib/screens/top_paintings_screen.dart:282, top_public_squares_screen.dart:227 "My Rating:"
- lib/widgets/city_tour_navigation.dart:76,78 "Info", "Tour"
- lib/social/widgets/cards.dart:274 rank labels ("Globetrotter", "Worldmaster"; max 96px)
## G6
- lib/screens/flight_log_list_screen.dart:~916 "Arr. Terminal" / "Arr. Gate"
- lib/screens/seat_class_stats_screen.dart:510 "Total Flights" (donut)
- lib/games/border_chain.dart:~1466 "START" / "TARGET"
- lib/screens/daily_quiz_screen.dart:1362 "visited" (9pt badge)
- lib/screens/city_economy_screen.dart:231 metric tab titles
## G9
- flight_checklist.dart:233 "Add Photo"; :579-637 "Transfer", "Layover", "Stopover", "Lounge Use"
- airport_code.dart:1190, flag_guess.dart:2350 "Rounds" / "Best" / "Combo"
- language_stats_screen.dart:141 "Languages" / "Families"
## G5
- tourism_screen.dart:103 "Annual Visitors"; explore_menu_screen.dart:426 "Top Picks", :404 "Cultural", :315 "Map", :325 "Stats"
- duel_game_screen.dart:676,1423 "VS"; countrydex_screen.dart:276 "Newest First" / "Oldest First"
- airline_detail_screen.dart:370 "Total Cash Spent:"
## G10
- compare/overview_tab.dart:52 "Landmarks"; social stats_screen.dart:1074 "Stats"
- city_specials_screen.dart:681 "Skyscraper Count", :688 "Hollywood Filming", :1122 "Remaining"
- city_transportation_screen.dart:75 "Traffic (per 10km)", "Metro Stations"; language_family_map_screen.dart:155 "Subbranch"
## G11
- countries_menu_screen.dart:134 "NEW"; city_travel_modal.dart:715 "Hotels", "Apartments", :1255 "Rental Car", "Travel Insurance", "Ground Transport"
- city_tiers_screen.dart:187, country_tiers_screen.dart:166 metric labels (85px column); "TIERS" / "TABLE" / "CHART"
- subscription_sheet.dart:898 "MOST POPULAR"
## G3
- cities_screen.dart:2432 "Defaults", :2532 "Cancel", :2545 "Done"; discover_quiz_screen.dart:402 "Back"
- city_climate_screen.dart:310 "Avg Temperature", :317 "Avg Precipitation"; cities_screen.dart:1623,3467 "Lived:"
## G12 (stopped early: 15 files not done; another session edited them)
## G4 (country_detail_screen skipped: being edited by the fork session)
- add_flight_log_screen.dart:1009 "Unknown"; film_festivals_screen.dart:245, top_universities_screen.dart:598 "My Rating:" (next to fixed 140px RatingBar)
- timezone_impostor.dart:1304 "Rounds" / "Best" / "Combo", :1347 "best $best"
- TODO country_detail_screen.dart "Wishlist:/My Rating:" row: both halves Flexible → "My Rating:" ~40px, truncates even in English. Make only Wishlist half Flexible.
## G2
- home_tab_screen.dart:391 "Set", :359 "Badges"; aircraft_stats_screen.dart:557 "Total Flights", airline_stats_screen.dart:932 "Flights" (pie hole)
- ranking_card.dart:101 "follow @travelog_travel_map for more travel stats"; flight_log_actions.dart "Save Changes" / "Save Log"
- social/widgets/charts.dart:152 radar axis labels (painted, no width limit)
## G7
- new_tag.dart:26 "NEW"; social/widgets/avatar.dart:129 plan labels; travelog_polls_screen.dart:278 "THIS WEEK"
- stat_lock_guard.dart:144 "Watch a video to unlock this for now"; badge_detail_screen.dart:470 "Subscribe to Claim"
- geopolitics_stats_screen.dart:813 "Cold War Geopolitics Map"
## G8
- geography_stats_screen.dart:1200 "Visited" / "World" (60px); main_screen.dart:49 bottom nav labels (11px)
- tourist_footprint_result.dart:88 "Local side" / "Tourist side"; military_stats_screen.dart:432 "Stronger" / "Weaker"
