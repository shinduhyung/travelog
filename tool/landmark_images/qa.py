"""Check each generated image with Claude Sonnet (vision): people, right subject, text/logos.

    python qa.py            # checks raw/*.jpg not yet in qa.json; prints pass/fail counts
    python qa.py --loop     # keeps checking new images every 2 minutes until the Leonardo run is done

Writes qa.json {file: {"pass": bool, "people": bool, "subject_ok": bool, "text": bool, "note": str}}.
Failed images are listed for one regeneration; nothing is uploaded from here.
"""
import base64
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
KEY = next(l.split("=", 1)[1].strip() for l in (ROOT / ".env").read_text(encoding="utf-8").splitlines()
           if l.startswith("ANTHROPIC_API_KEY="))
QA = HERE / "qa.json"
ASK = """This is a generated travel-app illustration of "{name}" ({city}). Check it strictly and reply with JSON only:
{{"people": <true if ANY person, human figure, silhouette, face, hand or human reflection is visible, even tiny or distant>,
"subject_ok": <false ONLY if it clearly shows a different specific landmark (e.g. another famous bridge), the wrong kind of place, or a well-known landmark drawn clearly wrong (wrong shape or structure). A generic but plausible picture of a little-known place is true>,
"text": <true if any letters, words, numbers, logos or watermarks are visible>,
"note": "<max 15 words on what is wrong, empty if fine>"}}"""


def check(item):
    f, row = item
    img = base64.b64encode((HERE / "raw" / (Path(f).stem + ".jpg")).read_bytes()).decode()
    body = json.dumps({"model": "claude-sonnet-5-5", "max_tokens": 2000, "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": [
                           {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": img}},
                           {"type": "text", "text": ASK.format(name=row["name"], city=row["city"])}]}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=90))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            d = json.loads(txt[txt.index("{"): txt.rindex("}") + 1])
            d["pass"] = (not d["people"]) and d["subject_ok"] and not d["text"]
            return f, d
        except Exception as e:  # retry, then leave it for the next pass
            err = e
    print("qa failed", f, err)
    return f, None


def run():
    prompts = json.loads((HERE / "prompts.json").read_text(encoding="utf-8"))
    qa = json.loads(QA.read_text(encoding="utf-8")) if QA.exists() else {}
    todo = [(f, prompts[f]) for f in prompts if f not in qa and (HERE / "raw" / (Path(f).stem + ".jpg")).exists()]
    with ThreadPoolExecutor(4) as pool:
        for f, d in pool.map(check, todo):
            if d:
                qa[f] = d
    QA.write_text(json.dumps(qa, ensure_ascii=False, indent=1), encoding="utf-8")
    bad = [f for f, d in qa.items() if not d["pass"]]
    print(f"checked {len(qa)}: pass {len(qa) - len(bad)}, fail {len(bad)}")
    return len(todo)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if "--loop" in sys.argv:
        idle = 0
        while idle < 30:  # stop after an hour with nothing new
            idle = 0 if run() else idle + 1
            time.sleep(120)
    else:
        run()
