"""Prompts for the 15 day-trip cruise/boat tours that have no photo, added to miss_prompts.json (LEO_SET=miss).

    python cruise_prompts.py
"""
import json
import re
import sys
import unicodedata
from concurrent.futures import ThreadPoolExecutor

from redo import ask, HERE

NAMES = sys.argv[1:] or ["Bruges Canal Boat Tour", "Jungle Queen Riverboat", "Lake Annecy Cruise", "Lake Brienz & Thun Cruise",
         "Lake Como Ferry", "Lake Lucerne Panoramic Yacht", "Leie River Cruise", "Maid of the Mist",
         "Mekong Delta Sampan", "Melaka River Cruise", "Moliceiro Boat Tour", "Neckar River Solar Boat",
         "Punting on the Cam", "Rideau Canal Cruise", "Trang An Boat Tour"]


def snake(name):  # lib/utils/storage_name.dart foldedSnake
    s = unicodedata.normalize("NFKD", name.lower()).encode("ascii", "ignore").decode()
    s = re.sub(r"['`’]", "", s)
    s = re.sub(r"[^a-z0-9\s]", "", s)
    return re.sub(r"\s+", "_", s.strip())


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    lms = {l["name"]: l for l in json.loads((HERE / "../../assets/all_landmarks.json").read_text("utf-8"))}
    out_p = HERE / "miss_prompts.json"
    out = json.loads(out_p.read_text("utf-8"))
    items = []
    for n in NAMES:
        l = lms[n]
        iso = (l.get("countriesIsoA3") or ["m"])[0].lower()
        f = f"{iso}_{snake(n)}.webp"
        row = {"name": n, "city": l.get("city"), "iso3": iso, "file": f, "attributes": l.get("attributes") or [],
               "overview": l.get("overview", "") or "", "prompt": ""}
        why = "Show the boat on the water with the place's signature scenery; no passengers' faces" if not sys.argv[1:] else "show the place itself, empty, with its signature features; for an event show its setting and decorations with no crowds; for a painting show the artwork itself"
        items.append((f, row, "none yet, write it fresh. " + why))
    with ThreadPoolExecutor(5) as pool:
        for f, v in pool.map(ask, items):
            if v:
                out[f] = v
                print("ok", f)
            else:
                print("skip", f)
    out_p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
