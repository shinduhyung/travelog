"""After auto_city.py: fix what scripts can fix, then write one issue report for Claude to read.

    python all_cities.py <cities.txt>      # one city per line

Per city:
  1. status: capital from city_records (cities.json is the app's truth); largest=True when largest_city is the city.
  2. merge errors "landmark 'X' not in all_landmarks.json": link to an existing landmark when the name matches
     loosely (accents, case, "The", punctuation); otherwise queue X to be added.
  3. add the prep "missing" must-sees + queued names (add_landmarks: OSM coords, DeepSeek text and attribute).
  4. if landmarks were added: redraft deepseek_prep (signature picks), re-merge.
  5. drop signature picks whose main attribute is food / painting / filming location / festival.
  6. deepseek_prep --apply.
Then the report (logs/_issues.md): every facts problem, merge error/warning, status change, skipped landmark,
dropped signature, failed step, and cities with few landmarks.
"""
import contextlib
import io
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import add_landmarks
import city_records
import deepseek_city as ds

HERE = ds.HERE
FAR_KM = 300
BAD_SIG = {"Food", "Fast Food", "Restaurant", "Cafe", "Painting", "Filming Location", "Festival"}


def norm(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"^the\s+", "", s)
    return re.sub(r"[^a-z0-9]+", "", s)


def py(*args):
    r = subprocess.run([sys.executable, *args], cwd=HERE, capture_output=True, text=True, encoding="utf-8",
                       env={**__import__("os").environ, "PYTHONIOENCODING": "utf-8"})
    return (r.stdout or "") + (r.stderr or "")


def main(path):
    cities = [c for c in open(path, encoding="utf-8").read().splitlines() if c.strip()]
    recs = city_records.load_cities()
    lms = json.loads(add_landmarks.LM.read_text(encoding="utf-8"))
    by_norm = {norm(l["name"]): l["name"] for l in lms}
    attr = {l["name"]: (l.get("attributes") or [""])[0] for l in lms}
    rep = {c: [] for c in cities}
    queue = {}
    for c in cities:
        s = ds.slug(c)
        log = (HERE / "logs" / f"{s}.txt").read_text(encoding="utf-8") if (HERE / "logs" / f"{s}.txt").exists() else ""
        pp = ds.DRAFTS / f"{s}.prep.json"
        if "FAILED" in log or not pp.exists() or not (ds.DRAFTS / f"{s}.plans.json").exists():
            rep[c].append("FAILED pipeline: " + (log.strip().splitlines()[-1:] or ["no log"])[0][:200])
            continue
        d = json.loads(pp.read_text(encoding="utf-8"))
        st = d.get("status") or {}
        cap = bool(recs[c]["values"].get("isCapital"))
        if st.get("capital") != cap:
            rep[c].append(f"status capital {st.get('capital')} -> {cap} (cities data)")
            st["capital"] = cap
        if not st.get("largest") and st.get("largest_city") == c:
            rep[c].append("status largest False -> True (largest_city is the city itself)")
            st["largest"] = True
        d["status"] = st
        pp.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
        fx = HERE / "facts" / f"{s}.json"
        for p in (json.loads(fx.read_text(encoding="utf-8")).get("problems", []) if fx.exists() else []):
            rep[c].append("facts: " + p)
        names = list(d.get("missing", []))
        places = ds.DRAFTS / f"{s}.places.json"
        for m in re.findall(r"ERROR\s+\S+: landmark '([^']+)' not in all_landmarks", log):
            hit = by_norm.get(norm(m))
            if hit and places.exists():
                t = places.read_text(encoding="utf-8").replace(f'"landmark": "{m}"', f'"landmark": "{hit}"')
                places.write_text(t, encoding="utf-8")
                rep[c].append(f"linked '{m}' -> existing '{hit}'")
            else:
                names.append(m)
        names = [n for n in dict.fromkeys(names) if norm(n) not in by_norm and "(" not in n and len(n) < 60]
        if names:
            queue[c] = [[n, ""] for n in names]

    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        add_landmarks.add(queue)
    for line in out.getvalue().splitlines():
        m = re.match(r"(.+?): (added|skip) (.+)", line)
        if m and m.group(1) in rep:
            rep[m.group(1)].append(f"landmark {m.group(2)} {m.group(3)}")
    added = {c for c in rep if any(x.startswith("landmark added") for x in rep[c])}

    lms = json.loads(add_landmarks.LM.read_text(encoding="utf-8"))
    attr = {l["name"]: (l.get("attributes") or [""])[0] for l in lms}
    coords = {l["name"]: (l.get("latitude"), l.get("longitude")) for l in lms}
    for c in cities:
        if any(x.startswith("FAILED") for x in rep[c]):
            continue
        s = ds.slug(c)
        pp = ds.DRAFTS / f"{s}.prep.json"
        if c in added:
            keep = json.loads(pp.read_text(encoding="utf-8"))["status"]
            py("deepseek_prep.py", c)
            d = json.loads(pp.read_text(encoding="utf-8"))
            d["status"] = keep
            pp.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
        places = ds.DRAFTS / f"{s}.places.json"
        plans = (ds.DRAFTS / f"{s}.plans.json").read_text(encoding="utf-8")
        pd = json.loads(places.read_text(encoding="utf-8"))
        center = (recs[c]["values"]["latitude"], recs[c]["values"]["longitude"])
        def pos(p):
            if p.get("lat") is not None and p.get("lon") is not None:
                return p["lat"], p["lon"]
            lm = coords.get(p.get("landmark"))
            return lm if lm and None not in lm else None
        far = [pid for pid, p in pd["places"].items() if pos(p) and add_landmarks.km(center, pos(p)) > FAR_KM
               and f'"{pid}"' not in plans]
        if far:  # a same-name place in another country (Bristol -> Lake Compounce, Connecticut)
            for pid in far:
                rep[c].append(f"place removed: {pd['places'][pid].get('name', pid)} (> {FAR_KM} km, not in any plan)")
                del pd["places"][pid]
            places.write_text(json.dumps(pd, ensure_ascii=False, indent=2), encoding="utf-8")
        alien = [l["name"] for l in lms if l.get("city") == c and l.get("latitude") is not None
                 and add_landmarks.km(center, (l["latitude"], l["longitude"])) > FAR_KM]
        if alien:  # same city name elsewhere (Athens, Georgia)
            sp = HERE / "landmark_scope.json"
            scope = json.loads(sp.read_text(encoding="utf-8"))
            ex = scope.setdefault("exclude", {}).setdefault(c, [])
            new = [n for n in alien if n not in ex]
            if new:
                ex += new
                sp.write_text(json.dumps(scope, ensure_ascii=False, indent=2), encoding="utf-8")
                rep[c].append(f"landmarks excluded (> {FAR_KM} km, same city name elsewhere): " + ", ".join(new))
        merged = py("merge_city.py", c)
        for line in merged.splitlines():
            if line.startswith(("ERROR", "WARN")):
                rep[c].append("merge: " + line)
        d = json.loads(pp.read_text(encoding="utf-8"))
        drop = [x["name"] for x in d["signature"] if attr.get(x["name"]) in BAD_SIG]
        if drop:
            d["signature"] = [x for x in d["signature"] if x["name"] not in drop]
            rep[c].append("signature dropped: " + ", ".join(f"{n} [{attr[n]}]" for n in drop))
        if len(d["signature"]) < 3:
            rep[c].append(f"only {len(d['signature'])} signature landmarks: " + "; ".join(x["name"] for x in d["signature"]))
        if d.get("n_landmarks", 0) < 5:
            rep[c].append(f"few landmarks ({d.get('n_landmarks')}) before additions")
        pp.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
        py("deepseek_prep.py", "--apply", c)

    lines = ["# Issues", ""]
    for c in cities:
        lines.append(f"## {c}")
        lines += [f"- {x}" for x in rep[c]] or ["- (none)"]
        lines.append("")
    (HERE / "logs" / f"_issues_{Path(path).stem}.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"report: logs/_issues_{Path(path).stem}.md ({sum(len(v) for v in rep.values())} lines, "
          f"{sum(1 for v in rep.values() if any(x.startswith('FAILED') for x in v))} failed)")


if __name__ == "__main__":
    main(sys.argv[1])
