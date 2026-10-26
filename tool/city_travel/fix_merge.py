"""Fix the mechanical merge errors DeepSeek drafts leave, then re-merge.

    python fix_merge.py <City> ...

- plan stop "unknown place 'x'": point it at the closest existing place id (difflib, cutoff 0.6);
- place "kind 'x'": map to the nearest allowed kind (nature -> park, shopping -> activity, ...);
- anything left (unknown length/style, missing stops, no close id): regenerate the plans stage once.
Prints one line per city with what it did and the merge result.
"""
import difflib
import json
import re
import subprocess
import sys

import deepseek_city as ds

HERE = ds.HERE
KIND = {"nature": "park", "garden": "park", "viewpoint": "sight", "shopping": "activity", "market": "food",
        "nightlife": "activity", "religious": "sight", "neighborhood": "sight", "neighbourhood": "sight",
        "landmark": "sight", "historic": "sight", "zoo": "activity", "theme park": "activity", "entertainment": "show"}


def run(*args):
    r = subprocess.run([sys.executable, *args], cwd=HERE, capture_output=True, text=True, encoding="utf-8",
                       env={**__import__("os").environ, "PYTHONIOENCODING": "utf-8"})
    return (r.stdout or "") + (r.stderr or "")


def fix(city):
    s = ds.slug(city)
    pp, lp = ds.DRAFTS / f"{s}.places.json", ds.DRAFTS / f"{s}.plans.json"
    out = run("merge_city.py", city)
    did = []
    places = json.loads(pp.read_text(encoding="utf-8"))
    ids = list(places["places"])
    plans = lp.read_text(encoding="utf-8")
    for bad in sorted(set(re.findall(r"unknown place '([^']+)'", out))):
        hit = difflib.get_close_matches(bad, ids, n=1, cutoff=0.6)
        if hit:
            plans = plans.replace(f'"{bad}"', f'"{hit[0]}"')
            did.append(f"{bad}->{hit[0]}")
    lp.write_text(plans, encoding="utf-8")
    for pid, kind in re.findall(r"ERROR\s+(\S+): kind '([^']*)'", out):
        if pid in places["places"]:
            places["places"][pid]["kind"] = KIND.get(kind.lower(), "sight")
            did.append(f"{pid} kind {kind}->{places['places'][pid]['kind']}")
    pp.write_text(json.dumps(places, ensure_ascii=False, indent=2), encoding="utf-8")
    out = run("merge_city.py", city)
    if "ERROR" in out or "Traceback" in out:
        run("deepseek_city.py", city, "--stage", "plans")
        did.append("plans regenerated")
        out = run("merge_city.py", city)
    if "ERROR" in out:  # still failing after one regeneration: drop what cannot be linked
        plans = json.loads(lp.read_text(encoding="utf-8"))
        bad_pl = set(re.findall(r"ERROR plan (\S+): unknown length/style", out))
        bad_pid = set(re.findall(r"unknown place '([^']+)'", out))
        plans["plans"] = [p for p in plans["plans"] if p.get("id") not in bad_pl]
        for p in plans["plans"]:
            for d in p.get("days", []):
                d["stops"] = [x for x in d.get("stops", []) if x.get("place") not in bad_pid]
        lp.write_text(json.dumps(plans, ensure_ascii=False, indent=2), encoding="utf-8")
        did += [f"dropped plan {x}" for x in bad_pl] + [f"dropped stops at {x}" for x in bad_pid]
        far = set(re.findall(r"ERROR stay '([^']+)' center \d+ km away", out))
        fp = ds.DRAFTS / f"{s}.frame.json"
        if far and fp.exists():
            fr = json.loads(fp.read_text(encoding="utf-8"))
            for k in ("stays", "stay"):
                if isinstance(fr.get(k), list):
                    fr[k] = [x for x in fr[k] if x.get("area") not in far]
            fp.write_text(json.dumps(fr, ensure_ascii=False, indent=2), encoding="utf-8")
            did += [f"dropped stay area {x}" for x in far]
        out = run("merge_city.py", city)
    last = [l for l in out.strip().splitlines() if "places" in l and "plans" in l][-1:] or out.strip().splitlines()[-1:]
    errs = [l.strip() for l in out.splitlines() if l.startswith("ERROR")][:5]
    print(f"{city}: {'; '.join(did) or 'nothing to fix'} | {last[0] if last else ''}" + (f" | {errs}" if errs else ""))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    for c in sys.argv[1:]:
        fix(c)
