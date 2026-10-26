# Hotel price signals (trial)

Popular hotels per city, their 1-year price calendar from Google Hotels (via DataForSEO),
and a green / neutral / red signal for "is now a good price for this hotel".
Trial city: Abu Dhabi. The app doesn't use this yet.

## One-time setup
1. Sign up at dataforseo.com and add funds (pay-as-you-go).
2. Dashboard -> **API Access**: copy the API login and API password.
3. Create `tool/hotel_prices/.env` (git-ignored):
   ```
   DATAFORSEO_LOGIN=you@example.com
   DATAFORSEO_PASSWORD=xxxxxxxxxxxx
   ```

## Run
```
python tool/hotel_prices/fetch_prices.py --city "Abu Dhabi" --dry-run   # cost only
python tool/hotel_prices/fetch_prices.py --city "Abu Dhabi"             # ~ $0.26 first run
python tool/hotel_prices/analyze_prices.py --city "Abu Dhabi"
```
- First fetch saves the hotel list to `hotels/abu_dhabi.json` (30 most-reviewed, ads excluded).
  Later runs reuse it so the same hotels are compared over time.
- Each fetch adds `data/abu_dhabi/<date>.json`. Run it again on later days to get trends.
- `analyze_prices.py` writes `data/abu_dhabi/report.json` and prints a table.

## Location score (no API cost)
```
python tool/hotel_prices/location_scores.py --city "Abu Dhabi"
```
0-10 per hotel from our own data: 60% the 3 nearest sights in `assets/all_landmarks.json`,
20% distance to the city center (`assets/cities.json`), 20% to the airport (`assets/airports.json`).
Straight-line km. Also labels the district when within 3 km of a known district center.
Saved to `hotels/<city>_location.json`; `analyze_prices.py` adds it to the report.
Only as good as the landmark list (Abu Dhabi has 6 spots, no beaches yet).

## Guests per room
Tracking stays at 2 adults. Test (Oct 2026, ibis / Novotel / Emirates Palace): 1 adult = 2 adults price;
3-4 adults ~2x (two rooms or a suite) with fewer dates priced. Try others with
`--adults N --sample-per-star 1`; test runs go to `data/<city>/tests/`, outside the tracked history.

## What the signal means
Fixed conditions: 2 adults, 1 night, USD. Prices are Google Hotels' lowest across sites,
so they can differ from what Hotels.com shows; show relative signals, not "lowest price".
- **position**: where that night sits among the hotel's own same-weekday prices for the next
  180 days (0% cheapest). Green <= 25%, red >= 75%.
- **trend**: change since the first snapshot that priced the same night (needs 2+ days of runs).
- **vs peers**: vs the median of same-star hotels that night.

## Cost (live mode, Oct 2026 pricing)
Hotel search $0.004 per 18 results; hotel info $0.004, doubled with the price calendar.
30 hotels = ~$0.24 per snapshot. All 192 app cities x 30 hotels = ~$46 per full snapshot
in live mode; the standard queue is ~5x cheaper but asynchronous (not implemented yet).
