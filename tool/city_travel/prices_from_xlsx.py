"""Load the reviewed city costs (Desktop/city_costs_corrected.xlsx, sheet "City costs") into prices.json and signature.json.

The sheet's levels, including Overall, are final; build_page.py shows "overall" as is instead of the weighted mix.

    python tool/city_travel/prices_from_xlsx.py
"""
import json
from pathlib import Path

import openpyxl

HERE = Path(__file__).resolve().parent
SRC = Path.home() / "Desktop" / "city_costs_corrected.xlsx"
NOTE = {"food": "About ${:.0f} a day: light breakfast, cheap lunch, mid-range dinner",
        "stay": "3-star hotel about ${:.0f} a night for two",
        "transport": "About ${:.1f} a day: 4 public transit rides"}

rows = list(openpyxl.load_workbook(SRC, data_only=True)["City costs"].iter_rows(values_only=True))[1:]
sig_p = HERE / "signature.json"
sig = json.loads(sig_p.read_text(encoding="utf-8"))
out, missing = {}, []
for city, country, f_usd, f_lv, s_usd, s_lv, t_usd, t_lv, overall in rows:
    if not city:
        continue
    row = {"country": country, "overall": overall,
           "food": {"usd": f_usd, "level": f_lv}, "stay": {"usd": s_usd, "level": s_lv}, "transport": {"usd": t_usd, "level": t_lv}}
    out[city] = row
    if city not in sig:
        missing.append(city)
        continue
    sig[city]["costs"] = {k: [row[k]["level"], NOTE[k].format(row[k]["usd"] * (2 if k == "stay" else 1))] for k in ("food", "stay", "transport")}
    sig[city]["costs"]["overall"] = overall
(HERE / "prices.json").write_text(json.dumps({"_source": str(SRC.name), "cities": out}, ensure_ascii=False, indent=1), encoding="utf-8")
sig_p.write_text(json.dumps(sig, ensure_ascii=False, indent=2), encoding="utf-8")
print(len(out), "cities; not in signature:", missing)
