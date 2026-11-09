"""Writes souvenirs/<slug>.json for every city in city_souvenirs_final.xlsx (DeepSeek translates the Korean notes).

Photos: souvenir_prompts.json, matched by city + Korean item name. Existing files are kept (muscat is hand-written).
"""
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import openpyxl

import deepseek_city as ds
from build_page import slug

HERE = Path(__file__).resolve().parent
DESK = Path.home() / "Desktop"
BASIS = {"판매가 참고": "Shop prices"}
SYS = ("Translate souvenir notes for an English travel page. Reply with JSON {\"items\": [...]} in the same order, "
       "each {name, unit, where, about, tip}. name: short English item name. about: one sentence on what it is "
       "and why it belongs to this city. tip: one short practical buying tip from the notes. Plain, short sentences.")

prompts = json.loads((DESK / "souvenir_prompts.json").read_text(encoding="utf-8"))
pic = {(p["city"], p["item_ko"]): p["file"] for p in prompts}
rows = list(openpyxl.load_workbook(DESK / "city_souvenirs_final.xlsx")["도시별 기념품 최종"].iter_rows(values_only=True))[1:]
cities = {}
for r in rows:
    if r[0]:
        cities.setdefault(r[0].split("\n")[-1].strip(), []).append(r)


def one(city):
    out = HERE / "souvenirs" / f"{slug(city)}.json"
    if out.exists():
        return
    rs = cities[city]
    src = [{"item": r[2], "unit": r[3], "where": r[7], "notes": r[8]} for r in rs]
    got = ds.ask(SYS, f"City: {city}\n" + json.dumps(src, ensure_ascii=False), 3000)["items"]
    items = []
    for r, g in zip(rs, got):
        f = pic.get((city, r[2]))
        if not f:
            print("  no photo:", city, r[2])
        items.append({"name": g["name"], "file": f, "unit": g["unit"], "currency": r[4], "low": r[5], "high": r[6],
                      "where": g["where"], "about": g["about"], "tip": g["tip"], "basis": BASIS.get(r[9], "Estimate")})
    out.write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print("ok", city)


(HERE / "souvenirs").mkdir(exist_ok=True)
with ThreadPoolExecutor(8) as ex:
    list(ex.map(one, cities))
