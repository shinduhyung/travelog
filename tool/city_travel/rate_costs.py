"""Re-rate food / stay / transport for many cities in ONE DeepSeek call, so each category is ranked
against the other cities of the world (1 = among the cheapest cities for that category, 5 = among the
most expensive) instead of against the city's other categories.

    python tool/city_travel/rate_costs.py Lisbon Rome ...      # writes costs into signature.json
"""
import json
import sys

import deepseek_city as ds

SYSTEM = "You compare travel costs between world cities. Reply with one JSON object only."
PROMPT = """Rate each city in three categories on a 1-5 scale where each category is compared with OTHER CITIES
OF THE WORLD (not with the city's other categories):
- food: what a visitor pays for everyday meals. 1 = Bangkok/Hanoi/Mexico City street food level, 3 = Lisbon/Istanbul, 5 = Zurich/Oslo/New York.
- stay: a good central 3-4* hotel. 1 = Hanoi/Cairo, 3 = Lisbon/Prague, 5 = London/New York/Zurich.
- transport: public transport + taxi fares. 1 = Cairo/Mexico City/Bangkok, 3 = Rome/Seoul/Lisbon, 5 = London/Zurich/Oslo/Copenhagen.
Use the full scale across this list. Give a one-line example in US dollars for each.
Cities: {cities}
Reply: {{"<city>": {{"food": [n, "<example>"], "stay": [n, "<example>"], "transport": [n, "<example>"]}}}}"""

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    cities = sys.argv[1:]
    out = ds.ask(SYSTEM, PROMPT.format(cities=", ".join(cities)), 6000)
    p = ds.HERE / "signature.json"
    sig = json.loads(p.read_text(encoding="utf-8"))
    for c in cities:
        r = out.get(c)
        if not r:
            print(f"{c}: missing")
            continue
        sig.setdefault(c, {})["costs"] = r
        print(f"{c:15} food {r['food'][0]}  stay {r['stay'][0]}  transport {r['transport'][0]}   | {r['transport'][1]}")
    p.write_text(json.dumps(sig, ensure_ascii=False, indent=2), encoding="utf-8")
