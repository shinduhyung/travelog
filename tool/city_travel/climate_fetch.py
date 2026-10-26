"""Measured monthly climate for a city from Open-Meteo's historical archive (one-time, build step).

    python tool/city_travel/climate_fetch.py "London" 51.5072 -0.1276

Prints 12 months of {high, low, rain_days} = 2015-2024 averages of daily max / min temperature (°C)
and days with >= 1 mm precipitation. Writes nothing; facts/<slug>.json copies the result.
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict

URL = "https://archive-api.open-meteo.com/v1/archive"


def monthly(lat, lon, start="2015-01-01", end="2024-12-31"):
    q = urllib.parse.urlencode({"latitude": lat, "longitude": lon, "start_date": start, "end_date": end,
                                "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum", "timezone": "auto"})
    for attempt in range(16):  # the free archive API has an hourly request cap: wait it out
        try:
            with urllib.request.urlopen(f"{URL}?{q}", timeout=120) as r:
                d = json.load(r)["daily"]
            break
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 15:
                raise
            time.sleep(300)
    hi, lo, rain, years = defaultdict(list), defaultdict(list), defaultdict(int), set()
    for t, mx, mn, pr in zip(d["time"], d["temperature_2m_max"], d["temperature_2m_min"], d["precipitation_sum"]):
        m = int(t[5:7]) - 1
        years.add(t[:4])
        if mx is not None:
            hi[m].append(mx)
        if mn is not None:
            lo[m].append(mn)
        if pr is not None and pr >= 1:
            rain[m] += 1
    n = len(years)
    return [{"high": round(sum(hi[m]) / len(hi[m])), "low": round(sum(lo[m]) / len(lo[m])),
             "rain_days": round(rain[m] / n)} for m in range(12)]


if __name__ == "__main__":
    city, lat, lon = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    print(json.dumps({"city": city, "months": monthly(lat, lon)}))
