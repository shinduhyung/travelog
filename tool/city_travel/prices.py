"""One file for the whole price system: prices.json (per city: USD/day per category, level 1-5, source, note).

Per category the value comes from the first source that has it:
  food       Numbeo city  > BudgetYourTrip city > country median of the above
  transport  Numbeo city  > country median of Numbeo cities > BudgetYourTrip city (BYT "local transport"
             is noisy for small samples: Nanjing $41/day vs Beijing $8, so it is used last)
  stay       BudgetYourTrip city > country median
  otherwise the earlier hand/model level in signature.json is kept, marked source "estimate".
Levels: value / REF per category, cut by BANDS (cost_data.py), so a typical tourist city is $$$.
Writes prices.json and the "costs" of signature.json (what build_page.py shows).

    python tool/city_travel/prices.py
"""
import json
import statistics
from pathlib import Path

from cost_data import BANDS, MANUAL, REF, level

HERE = Path(__file__).resolve().parent
KEYS = ("food", "stay", "transport")
NOTE = {"food": "About ${:.0f} a day for two cheap meals and one mid-range dinner",
        "stay": "Mid-range hotel about ${:.0f} a night for two",
        "transport": "About ${:.0f} a day: 4 transit rides and one 6 km taxi"}


def city_values(d):
    n, b = d.get("numbeo") or {}, d.get("byt") or {}
    food_n = 2 * n["meal"] + n["meal2"] / 2 if n.get("meal") and n.get("meal2") else None
    tr_n = 4 * n["ticket"] + n["taxi_start"] + 6 * n["taxi_km"] if all(n.get(k) for k in ("ticket", "taxi_start", "taxi_km")) else None
    return {"food": [(food_n, "Numbeo"), (b.get("food"), "BudgetYourTrip")],
            "transport": [(tr_n, "Numbeo")],
            "stay": [(b.get("stay"), "BudgetYourTrip")]}, b.get("transport")


def main():
    data = json.loads((HERE / "cost_data.json").read_text(encoding="utf-8"))
    sig_p = HERE / "signature.json"
    sig = json.loads(sig_p.read_text(encoding="utf-8"))
    country = {c: (d.get("byt_path") or "").split("/")[0] for c, d in data.items() if isinstance(d, dict)}
    vals, byt_tr = {}, {}
    for c, d in data.items():
        if isinstance(d, dict):
            vals[c], byt_tr[c] = city_values(d)
    # country medians from city-level values
    med = {}
    for k in KEYS:
        by = {}
        for c, v in vals.items():
            x = next((x for x, _ in v[k] if x), None)
            if x and country[c]:
                by.setdefault(country[c], []).append(x)
        med[k] = {co: statistics.median(xs) for co, xs in by.items()}
    out = {}
    for c, s in sig.items():
        if not isinstance(s, dict) or not s.get("costs"):
            continue
        row = {"country": country.get(c, "")}
        for k in KEYS:
            cands = list(vals.get(c, {}).get(k, []))
            co = country.get(c)
            if co in med[k]:
                cands.append((med[k][co], f"country median ({co})"))
            if k == "transport" and byt_tr.get(c):
                cands.append((byt_tr[c], "BudgetYourTrip"))
            usd, src = next(((x, s_) for x, s_ in cands if x), (None, None))
            if (c, k) in MANUAL:
                row[k] = {"usd": None, "level": MANUAL[(c, k)], "source": "manual", "note": s["costs"][k][1]}
            elif usd:
                shown = usd * 2 if k == "stay" else usd
                row[k] = {"usd": round(usd, 1), "level": level(usd, REF[k]), "source": src, "note": NOTE[k].format(shown)}
            else:
                row[k] = {"usd": None, "level": s["costs"][k][0], "source": "estimate", "note": s["costs"][k][1]}
        out[c] = row
        s["costs"] = {k: [row[k]["level"], row[k]["note"]] for k in KEYS}
    meta = {"_rules": __doc__.strip().splitlines()[2:9], "_ref_usd": REF, "_bands": BANDS}
    (HERE / "prices.json").write_text(json.dumps({**meta, "cities": out}, ensure_ascii=False, indent=1), encoding="utf-8")
    sig_p.write_text(json.dumps(sig, ensure_ascii=False, indent=2), encoding="utf-8")
    from collections import Counter
    print({k: Counter(r[k]["source"].split(" (")[0] for r in out.values()) for k in KEYS})
    for c in ("Nanjing", "Tianjin", "Suzhou", "Wuhan", "Beijing", "Tokyo", "Paris", "Muscat"):
        r = out.get(c)
        if r: print(c, {k: (r[k]["level"], r[k]["usd"], r[k]["source"]) for k in KEYS})


if __name__ == "__main__":
    main()
