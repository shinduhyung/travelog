"""Prompts for the user's missing-photo list (Desktop/사진누락_랜드마크_파일명.xlsx), keyed by the Excel file name.

Earlier QA fails are rewritten with redo.ask; landmarks never prompted are written fresh the same way.
Results are appended to miss_prompts.json as they finish, so LEO_SET=miss leo_queue.py can generate meanwhile.

    python miss_prompts.py
"""
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

import openpyxl

from redo import ask, HERE

XLSX = r"C:\Users\ahnlee123\Desktop\사진누락_랜드마크_파일명.xlsx"
OUT = HERE / "miss_prompts.json"
lock = threading.Lock()

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    rows = list(openpyxl.load_workbook(XLSX).active.iter_rows(values_only=True))[1:]
    prompts = json.loads((HERE / "prompts.json").read_text("utf-8"))
    qa = json.loads((HERE / "qa.json").read_text("utf-8"))
    lms = json.loads((HERE / "../../assets/all_landmarks.json").read_text("utf-8"))
    byname = {(v["name"], v["city"]): k for k, v in prompts.items()}
    lmby = {(l["name"], l.get("city")): l for l in lms}
    out = json.loads(OUT.read_text("utf-8")) if OUT.exists() else {}
    old, new = [], []
    for _, name, city, attr, file in rows:
        if not file or file in out:
            continue
        k = file if file in prompts else byname.get((name, city))
        if k and qa.get(k, {}).get("pass"):
            continue  # already uploaded under its Excel name (alias_map.json)
        if k:
            old.append((file, {**prompts[k], "file": file}, "QA: " + qa.get(k, {}).get("note", "")))
        else:
            l = lmby.get((name, city), {})
            attrs = l.get("attributes") or ([attr] if attr else [])
            row = {"name": name, "city": city, "iso3": file.split("_")[0], "file": file, "attributes": attrs,
                   "overview": l.get("overview", "") or "", "prompt": ""}
            new.append((file, row, "none yet, write it fresh"))
    print("rewrite", len(old), "| new", len(new), flush=True)

    def run(item):
        f, v = ask(item)
        with lock:
            if v:
                out[f] = v
                OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
            else:
                print("skip", f, flush=True)

    with ThreadPoolExecutor(4) as pool:
        list(pool.map(run, old + new))
    print("done", len(out))
