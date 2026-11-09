"""Second, looser QA pass for images that failed qa.py (user rule, 2026-11-03):
statues, sculptures and figures inside an artwork are fine (only real people count); the place's own real
signage or name (a Starbucks sign on a Starbucks) is fine; small inaccuracies are fine, only a clearly
different or badly wrong building fails. Updates {PRE}qa.json in place.

    LEO_SET=miss python requa.py
"""
import json
import sys
from concurrent.futures import ThreadPoolExecutor

import qa

qa.ASK = """This is a generated travel-app illustration of "{name}" ({city}). Reply with JSON only:
{{"people": <true ONLY if real living people (visitors, pedestrians, crowds) are visible. Statues, sculptures, monuments, and figures that are part of a painting or artwork do NOT count>,
"subject_ok": <false ONLY if it clearly shows a different place, the wrong kind of place, or the landmark is so wrong a visitor would not recognise it. Simplified details, missing ornaments, slightly different proportions are fine>,
"text": <true ONLY if there is gibberish lettering, watermarks, or unrelated brand logos. The place's own real name or signage (e.g. a Starbucks sign on a Starbucks) does NOT count>,
"note": "<max 15 words on what is wrong, empty if fine>"}}"""

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    prompts = json.loads((qa.HERE / f"{qa.PRE}prompts.json").read_text(encoding="utf-8"))
    res = json.loads(qa.QA.read_text(encoding="utf-8"))
    todo = [(f, prompts[f]) for f, d in res.items() if not d["pass"] and f in prompts]
    with ThreadPoolExecutor(6) as pool:
        for f, d in pool.map(qa.check, todo):
            if d:
                res[f] = {**d, "relaxed": True}
    qa.QA.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    still = [f for f, _ in todo if not res[f]["pass"]]
    print(f"rechecked {len(todo)}: now pass {len(todo) - len(still)}, still fail {len(still)}")
    for f in still:
        print(f[:-5], "|", res[f]["note"])
