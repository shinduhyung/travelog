"""DeepSeek batch drafts for a city page (the repetitive writing; facts are checked separately).

    python tool/city_travel/deepseek_city.py "London"            # all stages
    python tool/city_travel/deepseek_city.py "London" --stage plans

Inputs (made by Claude first — see PIPELINE.md "Who does what"):
  facts/<slug>.json   currency, usd rate, center, climate months, airports, taxi, transit facts,
                      landmark names to build places from, tours (with covered places)
Outputs (drafts, then validated by validate_city.py and reviewed):
  drafts/<slug>.places.json     places (itinerary fields + planner metadata)
  drafts/<slug>.frame.json      styles, lengths, types, fit, best_for, stays, food, tips, transit text, climate guide
  drafts/<slug>.plans.json      ready-made plans per length x style
merge_city.py then writes itineraries/<slug>.json and planner/<slug>.json.

Abu Dhabi's reviewed files are sent as the example of shape and tone. Coordinates are never
taken from the model for landmarks: they are copied from all_landmarks.json afterwards.
"""
import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DRAFTS = HERE / "drafts"
API = "https://api.deepseek.com/chat/completions"
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")


def key():
    k = os.environ.get("DEEPSEEK_API_KEY")
    if not k and (ROOT / ".env").exists():
        for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "DEEPSEEK_API_KEY":
                k = value.strip().strip('"')
    if not k:
        sys.exit("DEEPSEEK_API_KEY missing (.env at the repo root)")
    return k


SLUG_OVERRIDE = {"San José": "san-jose-cr"}  # San Jose (USA) is also an app city


def slug(city):
    if city in SLUG_OVERRIDE:
        return SLUG_OVERRIDE[city]
    import re
    import unicodedata
    s = unicodedata.normalize("NFKD", city).encode("ascii", "ignore").decode().lower()
    return re.sub(r"\s+", "-", re.sub(r"[^a-z0-9\s]", "", s).strip())


def env(name):
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        k, _, v = line.partition("=")
        if k.strip() == name:
            return v.strip().strip('"')
    return os.environ.get(name)


DEEPSEEK_DEAD = False  # set once DeepSeek rejects the key (401); later calls go straight to Claude


def ask_claude(system, user, max_tokens=8000):
    """Same contract as ask() (returns a dict parsed from JSON), on Claude Haiku via ANTHROPIC_API_KEY."""
    body = json.dumps({"model": "claude-haiku-5-5", "max_tokens": max_tokens, "system": system,
                       "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": user + "\n\nReply with one JSON object only."}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": env("ANTHROPIC_API_KEY"), "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.load(r)
            u = out.get("usage", {})
            print(f"  claude tokens in {u.get('input_tokens')} out {u.get('output_tokens')}")
            txt = "".join(b.get("text", "") for b in out["content"] if b["type"] == "text")
            txt = txt[txt.index("{"): txt.rindex("}") + 1]
            try:
                return json.loads(txt)
            except json.JSONDecodeError:
                import json_repair
                return json_repair.loads(txt)
        except (urllib.error.URLError, ValueError, KeyError) as e:
            print(f"  claude retry {attempt + 1}: {e}")
            time.sleep(5 * (attempt + 1))
    sys.exit("Claude failed 3 times")


def ask(system, user, max_tokens=8000):
    global DEEPSEEK_DEAD
    if DEEPSEEK_DEAD:
        return ask_claude(system, user, max_tokens)
    body = json.dumps({"model": MODEL, "temperature": 0.4, "max_tokens": max_tokens,
                       "response_format": {"type": "json_object"},
                       "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}).encode()
    req = urllib.request.Request(API, data=body, headers={"Authorization": f"Bearer {key()}",
                                                          "Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.load(r)
            usage = out.get("usage", {})
            print(f"  tokens in {usage.get('prompt_tokens')} out {usage.get('completion_tokens')}")
            txt = out["choices"][0]["message"]["content"]
            try:
                return json.loads(txt)
            except json.JSONDecodeError:
                import json_repair   # DeepSeek sometimes leaves a stray quote or comma in long replies
                fixed = json_repair.loads(txt)
                if isinstance(fixed, dict) and fixed:
                    print("  repaired JSON")
                    return fixed
                raise
        except urllib.error.HTTPError as e:
            if e.code in (401, 402):  # key rejected / no balance: switch to Claude for the rest of the run
                print(f"  DeepSeek {e.code}; using Claude Haiku")
                DEEPSEEK_DEAD = True
                return ask_claude(system, user, max_tokens)
            print(f"  retry {attempt + 1}: {e}")
            time.sleep(5 * (attempt + 1))
        except (urllib.error.URLError, json.JSONDecodeError, KeyError) as e:
            print(f"  retry {attempt + 1}: {e}")
            time.sleep(5 * (attempt + 1))
    sys.exit("DeepSeek failed 3 times")


SYSTEM = ("You write travel-planning data for a trip-prep web page. Reply with one JSON object only. "
          "Be concrete and practical, write for first-time visitors, English, short sentences. "
          "Never invent exact facts you are unsure of: give ranges or say 'check on the day'. "
          "Prices in the city's local currency.")


def example(name):
    return (HERE / name).read_text(encoding="utf-8")


def stage_places(city, facts):
    ad_it = json.loads(example("itineraries/abu-dhabi.json"))
    ad_pl = json.loads(example("planner/abu-dhabi.json"))
    sample = {k: {**ad_it["places"][k], **ad_pl["places"].get(k, {})} for k in ["mosque", "louvre", "corniche", "safari"]}
    user = f"""City: {city}. Currency: {facts['currency']}.
Landmarks to turn into places (use these exact names as "landmark"; keep the order of importance):
{json.dumps(facts['place_landmarks'], ensure_ascii=False)}
Also add up to 6 non-landmark places a visitor needs (a food market, a viewpoint, a classic activity
or tour, a neighbourhood walk) with "landmark": null and approximate "lat"/"lon".

For each place give: name, landmark (exact name or null), kind (sight|museum|park|food|activity|tour|beach|show),
price (number in {facts['currency']}, or null), price_text, hours, tip (one sentence), source (official URL if you know it, else ""),
types (subset of {json.dumps([t['id'] for t in facts['types']])}), minutes, setting (indoor|outdoor|mixed),
best (time of day / season advice), area (one of {json.dumps(facts['areas'])}), popularity (1-5, overall visitor popularity).
Example entries (Abu Dhabi, reviewed): {json.dumps(sample, ensure_ascii=False)}
Reply: {{"places": {{"<short_id>": {{...}}}}}} with 15-25 places, short lowercase ids."""
    return ask(SYSTEM, user, 12000)


def stage_frame(city, facts):
    ad_pl = json.loads(example("planner/abu-dhabi.json"))
    ad_it = json.loads(example("itineraries/abu-dhabi.json"))
    ex = {"styles": ad_it["styles"], "lengths": ad_it["lengths"], "stays": ad_it["stays"], "food": ad_it.get("food"),
          "more_time": ad_it["more_time"], "type_month_fit": ad_pl["type_month_fit"], "best_for": ad_pl["best_for"],
          "recommend": ad_pl["recommend"], "climate_guide": ad_pl["climate_guide"], "transit": ad_pl["transit"]}
    user = f"""City: {city}. Currency: {facts['currency']}.
Traveler types (fixed ids, one-word labels you may adjust to the city): {json.dumps(facts['types'], ensure_ascii=False)}
Monthly climate (measured averages, use these numbers, do not change them): {json.dumps(facts['climate_months'])}
Transit facts (checked): {json.dumps(facts['transit_facts'], ensure_ascii=False)}
Hotel areas to describe: {json.dumps(facts['areas'])}

Produce, in the same shape as the Abu Dhabi example:
- styles: exactly 3 ready-made plan styles (ids from the traveler type ids), label one word, blurb one line
- lengths: day / 1n / 2n / 3n ... up to what the city deserves; mark one "recommended": true
- stays: one per hotel area: area, range [low, high] nightly in {facts['currency']}, why, center [lat, lon]
- food: 5 tips; more_time: 3 swap ideas
- type_month_fit: per type id, 12 numbers 0-1 (weather/season fit)
- best_for: the 2-3 type ids the city is objectively strongest at (be honest, not every type)
- recommend: {{"why": one sentence}}
- month_notes: 12 short notes (one per month, Jan..Dec) for travelers, from the climate numbers
- climate_guide: summary + 6 items with emoji icon, title, text, written from the climate numbers above
- transit: best (one line) + modes [Metro, Bus, Taxi / ride apps, Rental car, Walking, + any city-specific
  like Train/Ferry/Tuk-tuk] each with has (true/false), best (true for the 1-2 best), text — only from the facts given
Abu Dhabi example: {json.dumps(ex, ensure_ascii=False)}
Reply: {{"styles":[], "lengths":[], "stays":[], "food":[], "more_time":[], "type_month_fit":{{}}, "best_for":[],
"recommend":{{}}, "month_notes":[], "climate_guide":{{}}, "transit":{{}}}}"""
    return ask(SYSTEM, user, 8000)


def stage_plans(city, facts, places, frame):
    ad_it = json.loads(example("itineraries/abu-dhabi.json"))
    slim = {k: {f: v.get(f) for f in ("name", "area", "minutes", "hours", "setting", "best", "types")} for k, v in places.items()}
    user = f"""City: {city}.
Places (ids are the only valid "place" values): {json.dumps(slim, ensure_ascii=False)}
Tours (index = "tour" value; a tour stop lists the place ids it covers): {json.dumps(facts.get('tours', []), ensure_ascii=False)}
Lengths: {json.dumps(frame['lengths'])}  Styles: {json.dumps(frame['styles'])}
Write one plan per length x style. Each plan: id "<length>-<style>", length, style, nights, for (one line),
days: [{{title, stops: [{{place: id | tour: index + covers: [ids], at: "HH:MM", minutes, note}}]}}].
Respect opening hours and weekdays, group by area, 3-5 stops a day plus a meal stop when useful.
Example plan (Abu Dhabi): {json.dumps(ad_it['plans'][3], ensure_ascii=False)}
Reply: {{"plans": [...]}}"""
    return ask(SYSTEM, user, 16000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("city")
    ap.add_argument("--stage", choices=["places", "frame", "plans"])
    a = ap.parse_args()
    s = slug(a.city)
    facts = json.loads((HERE / "facts" / f"{s}.json").read_text(encoding="utf-8"))
    DRAFTS.mkdir(exist_ok=True)
    out = lambda n: DRAFTS / f"{s}.{n}.json"
    if a.stage in (None, "places"):
        print(f"{a.city}: places")
        out("places").write_text(json.dumps(stage_places(a.city, facts), ensure_ascii=False, indent=2), encoding="utf-8")
    if a.stage in (None, "frame"):
        print(f"{a.city}: frame")
        out("frame").write_text(json.dumps(stage_frame(a.city, facts), ensure_ascii=False, indent=2), encoding="utf-8")
    if a.stage in (None, "plans"):
        print(f"{a.city}: plans")
        places = json.loads(out("places").read_text(encoding="utf-8"))["places"]
        frame = json.loads(out("frame").read_text(encoding="utf-8"))
        plans = []
        for length in frame["lengths"]:   # one call per trip length keeps each reply short
            print(f"  plans for {length['id']}")
            part = dict(frame, lengths=[length])
            plans += stage_plans(a.city, facts, places, part)["plans"]
        out("plans").write_text(json.dumps({"plans": plans}, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
