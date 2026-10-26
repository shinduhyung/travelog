# City page pipeline (Abu Dhabi is the reference)

How a city's trip-prep page is produced, in order. Every step writes a plain JSON file, so each one
can be done by a person, by Claude, or by a DeepSeek batch job (`LLM` = can be generated, then
validated by the checks listed). Build with `python tool/city_travel/build_page.py "<City>"`.

## Who does what (agreed 2026-10-23)
- **Claude (directly):** pipeline scripts, prompts, output schemas and the validator; finding existing
  landmarks and city scope; **picking missing must-see landmarks and writing their records**
  (exact format and existing attributes matter too much to batch); fact checks (coordinates,
  airport transfers, prices, hours) by web search; monthly climate numbers (Open-Meteo); tour
  selection on GetYourGuide; hotel prices and location scores; reviewing DeepSeek output; build,
  check, publish; updating this file after each pilot.
- **DeepSeek (batch):** place metadata (minutes, indoor/outdoor, best time, popularity), traveler
  types / best_for / recommended length, itinerary plans, transport summary, climate guide text
  from given numbers, food and travel tips, image prompts.
- **At the very end, for all cities at once:** Leonardo images + checking each one matches its
  landmark, duplicate / attribute clean-up, hotel calendar refresh setup, app data release.

## Commands (pilot, 2026-10-23)
1. Claude: landmarks (add missing to all_landmarks.json), `climate_fetch.py`, facts/<slug>.json
   (currency, center, types, areas, place_landmarks, airports, taxi, transit facts, climate), tours.
2. `python tool/city_travel/deepseek_city.py "<City>"` → drafts/<slug>.{places,frame,plans}.json
   (stages places → frame → plans; plans run one trip length per call).
3. `python tool/city_travel/merge_city.py "<City>"` → validates, writes itineraries/ and planner/.
4. Hotels: `tool/hotel_prices` (add the city to CITIES in fetch_prices.py).
5. `python tool/city_travel/build_page.py "<City>"` → out/<slug>.html → publish.

## Batch mode (2026-10-24, used for the remaining cities)
1. `python tool/city_travel/auto_city.py <City> ...` (5 in parallel; `--from=frame|plans` to resume) runs
   deepseek_prep -> deepseek_facts -> places -> covers -> frame -> plans -> tidy -> merge. Logs: `logs/<slug>.txt`.
2. Claude review (short): `python deepseek_prep.py --summary <cities>` (status, signature, missing),
   facts "problems". Check "missing" against all_landmarks.json first (most already exist); add truly missing
   ones by hand (scratchpad pattern: insert next to a city record, json.loads check). Fix drafts, then
   `python deepseek_prep.py --apply <cities>` (writes signature.json; tours left empty for now).
3. Costs from real prices: `python cost_data.py <cities>` then `python cost_data.py --rate-write`
   (Numbeo food/transport, BudgetYourTrip stay; REF centres; check printed averages stay ~3).
4. Build: `build_page.py` (xargs -P 4), publish each page right away (capabilities sample, icon map).
Deferred to the very end: GYG tours (lower model, browse one city page at a time; Cloudflare blocks fast
scripted fetches — never bypass), Leonardo images, hotel prices (DataForSEO, user tops up), app release.

## 0. Identity
- City name must match `assets/cities.json` exactly (it is the key everywhere).
- Hub airport: `assets/top_city_hub_airport.json` → `assets/airports.json` (`tz` = IANA zone, used for
  the live local time and the time difference from the viewer's device).

## 1. Landmarks (`assets/all_landmarks.json`)
1. **Find** what exists, never by exact name alone:
   - `city` field variants (district / island names, "City, Region" spellings);
   - everything within ~30 km of the city center by coordinates;
   - similar names (strip "The", "Abu Dhabi", punctuation).
2. **Scope** (`landmark_scope.json`): within `radius_km` counts unless filed under another app city;
   `attach` adds day-trip places everyone visits from the city (Paris→Versailles, Berlin→Potsdam,
   Seoul→Suwon, Rome→Vatican City). Never attach separate destinations (Amman→Petra, Abu Dhabi→Dubai).
3. **Add missing must-sees** (LLM): sights in the city's top lists, tour stops, the itinerary's places.
   Record format (copy exactly):
   ```json
   {"name": "...", "latitude": 24.4583, "longitude": 54.321, "global_rank": 0, "local_rank": 0,
    "attribute_rank": 0, "countriesIsoA3": ["ARE"], "city": "<City>", "attributes": ["Skyscraper"],
    "overview": "1-2 sentences.", "history_significance": "1-2 sentences.",
    "highlights": "Point one.\n Point two.\n Point three."}
   ```
   - `attributes`: only names already used in the file (70 in use; pick what similar landmarks use —
     forts→Castle, palace hotels→Modern Architecture+Hotel, mangroves→Jungle, interfaith→Other Religion).
     Skip a landmark if nothing fits rather than inventing one.
   - Insert as text next to the city's other records (don't re-serialize the 4.8 MB file).
   - Checks: name not already present (any variant), coordinates inside the city area, attribute in
     the existing set, JSON parses.
4. **Photos**: the app (country screen) loads `new_countrydex/{iso3}_{snake}.webp`, else
   `new_countrydex/m_{snake}.webp`. `countrydex/{snake}.jpg` is only the country top-30 set.
   `build_page.py` prints "landmarks without a photo" — that list is the image to-do (step 7).

## 2. Tours (`assets/city_tour_links.json`)
- Pick GetYourGuide tours a real visitor would book: high rating (≥4.7) with many reviews, and no
  overlap with tours already listed. Check the live listing (rating, review count, price, duration).
- URL gets `partner_id=EMZVISH&utm_medium=online_publisher`.
- `landmarks`: exact `name`s from all_landmarks.json (add the landmark first if missing) — these are
  the "landmark quests" the tour unlocks in the app.

## 3. Itinerary + planner data (LLM, then human check)
- `itineraries/<slug>.json`: places (coords, hours, prices with sources, `landmark` = linked landmark
  name), transport (taxi fare formula, notes), stays areas, plans per length/style, food tips.
  Lengths shown: up to recommended + 1 day.
- `planner/<slug>.json`: traveler types (one word each), place metadata (minutes, indoor/outdoor,
  best time, popularity 1-5), `best_for` (what the city is objectively strong at), airports with
  transfer options (price/time ranges, sources), `transit` (metro / bus / taxi+apps / car / walking,
  ✓/✗ and a best pick), monthly climate (high/low/sea/rain days), `climate_guide` (summary + 6 icon
  cards for travelers).
- Prices: ranges without "≈"; single estimates keep "≈". Dates on the page are English.

## 4. Hotel prices (`tool/hotel_prices`, DataForSEO, ~$0.25 per 30 hotels)
`fetch_prices.py` → `location_scores.py` → `analyze_prices.py`. Page shows the 3 most-reviewed
hotels, all 30 behind "See all", colors per the traveler's own nights.

## 5. Affiliates (all wired in build_page / planner / flights.py)
Trip.com flights (route search, origin = user hub or blank), Hotels.com, GetYourGuide, Airalo
(Impact deep link), Bounce (city page with ref). See memory: affiliate programs status.

## 6. Build + publish
`build_page.py "<City>"` → `out/<slug>.html`; publish to the city's artifact (capabilities `sample`
for Run AI).

## 7. Landmark images (Leonardo AI, later)
Style — match the existing set (soft watercolor/gouache illustration):
- square 1:1, the landmark centered and fully in frame, eye-level or gentle aerial view;
- bright pastel-blue sky with big fluffy cream clouds, warm soft sunlight, gentle shadows;
- fine painterly brush texture, slightly faded warm palette, crisp architectural detail;
- a little context (palms, gardens, water, skyline) but no text, logos, watermarks or close-up people.

Prompt template:
```
Watercolor and gouache illustration of {landmark}, {city}, {one-line visual description: shape,
materials, setting}. Square composition, the {landmark} centered and fully visible, {view}.
Bright pastel blue sky with large fluffy cream clouds, warm soft sunlight, delicate painterly
brush texture, slightly faded warm color palette, detailed architecture, {setting details}.
No text, no logos, no watermark.
```
Use the reference images already loaded in Leonardo; aspect 1:1. Export → convert to `.webp` →
upload to Firebase Storage as `new_countrydex/{iso3}_{snake}.webp` (`snake` = lowercase, drop
apostrophes and non-alphanumerics, spaces → `_`, same as the app's `_getLandmarkNameSlug`).

Image generation: exactly ONE image per landmark. Before every Generate, confirm the quantity is 1 and check the displayed token cost. Reuse completed generations; no batches of alternative copies.

Landmark image acceptance: NO people anywhere, including background figures, silhouettes, human reflections or portraits. Check full-resolution output before publication. Reject unrelated city architecture. Do not treat an artwork assigned to a museum as a verified visitable attraction; exclusions live in landmark_scope.json.

MANDATORY COST LIMIT: Leonardo GPT Image 2, LOW quality, SMALL 1024x1024, square, quantity=1. The visible Generate cost must be exactly 8 credits. Abort before clicking if the cost differs. Never switch to Medium/High without an explicit user request. Existing higher-cost generations must be reused, not regenerated.

Painting pilot exception: characters originally depicted in a painting must remain. No added visitors/museum setting. Disable unrelated landscape/food references; preserve original composition, palette, technique and aspect ratio. AI studies must not be presented as exact originals. Current 5-image pilot spent exactly 40 credits (8 each), remains local for review, and is not approved for Firebase publication. See images/painting-pilot/review.json.
