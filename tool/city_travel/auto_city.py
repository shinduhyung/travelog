"""Run the whole DeepSeek pipeline for new cities, several at a time.

    python tool/city_travel/auto_city.py Lisbon Rome ...

Per city: deepseek_prep (status, signature, costs, tours) -> deepseek_facts (facts/<slug>.json) ->
deepseek_city places -> tour covers from the places' landmarks -> frame -> plans -> merge_city.
Logs go to logs/<slug>.txt. Claude then reads only: deepseek_prep --summary, the facts "problems",
merge errors and the landmarks without photos; build_page + publish come after that review.
"""
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import deepseek_city as ds

HERE = ds.HERE
LOGS = HERE / "logs"
LOGS.mkdir(exist_ok=True)


def run(city, log, *args):
    r = subprocess.run([sys.executable, *args], cwd=HERE, capture_output=True, text=True, encoding="utf-8",
                       env={**__import__("os").environ, "PYTHONIOENCODING": "utf-8"})
    log.write(f"$ {' '.join(args)}\n{r.stdout}{r.stderr}\n")
    if r.returncode:
        raise RuntimeError(f"{args[0]} failed: {(r.stderr or r.stdout).strip().splitlines()[-1:]}")
    return r.stdout


def covers(city):
    s = ds.slug(city)
    fp = HERE / "facts" / f"{s}.json"
    f = json.loads(fp.read_text(encoding="utf-8"))
    places = json.loads((ds.DRAFTS / f"{s}.places.json").read_text(encoding="utf-8"))["places"]
    by_lm = {p.get("landmark"): pid for pid, p in places.items() if p.get("landmark")}
    for t in f.get("tours", []):
        t["covers"] = [by_lm[n] for n in t.get("landmarks", []) if n in by_lm]
    f["tours"] = [t for t in f.get("tours", []) if t["covers"]]
    fp.write_text(json.dumps(f, ensure_ascii=False, indent=2), encoding="utf-8")


def tidy(city):
    """Mechanical fixes merge_city would reject: unknown traveler types dropped, ids made valid."""
    import re
    s = ds.slug(city)
    f = json.loads((HERE / "facts" / f"{s}.json").read_text(encoding="utf-8"))
    ok = {t["id"] for t in f["types"]}
    pp = ds.DRAFTS / f"{s}.places.json"
    d = json.loads(pp.read_text(encoding="utf-8"))
    ren = {}
    for pid in list(d["places"]):
        new = re.sub(r"[^a-z0-9_-]", "", pid.lower())
        if not re.match(r"[a-z]", new):
            new = "p" + new
        new = new[:30]
        if new != pid:
            ren[pid] = new
            d["places"][new] = d["places"].pop(pid)
    for p in d["places"].values():
        p["types"] = [t for t in p.get("types", []) if t in ok] or [next(iter(ok))]
    pp.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    if ren:
        for name in ("plans",):
            fp = ds.DRAFTS / f"{s}.{name}.json"
            if fp.exists():
                txt = fp.read_text(encoding="utf-8")
                for a, b in ren.items():
                    txt = txt.replace(f'"{a}"', f'"{b}"')
                fp.write_text(txt, encoding="utf-8")


def one(city, start="prep"):
    s = ds.slug(city)
    with open(LOGS / f"{s}.txt", "w", encoding="utf-8") as log:
        try:
            steps = ["prep", "facts", "places", "frame", "plans"]
            for st in steps[steps.index(start):]:
                if st == "prep":
                    run(city, log, "deepseek_prep.py", city)
                elif st == "facts":
                    run(city, log, "deepseek_facts.py", city)
                else:
                    run(city, log, "deepseek_city.py", city, "--stage", st)
                if st == "places":
                    covers(city)
            tidy(city)
            out = run(city, log, "merge_city.py", city)
            return f"{city}: " + out.strip().splitlines()[-2] if len(out.strip().splitlines()) > 1 else out.strip()
        except Exception as err:
            return f"{city}: FAILED {err}"


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    start = "prep"
    if args and args[0].startswith("--from="):
        start = args.pop(0).split("=", 1)[1]
    with ThreadPoolExecutor(5) as pool:
        for line in pool.map(lambda c: one(c, start), args):
            print(line, flush=True)
