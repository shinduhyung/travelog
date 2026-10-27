import json, sys, os, re, io
sys.stdout.reconfigure(encoding="utf-8")
import deepseek_city as dc
CRLF = chr(13)+chr(10)
rows = json.load(open("_rev.json", encoding="utf-8")) if False else None
import openpyxl
wb = openpyxl.load_workbook(os.path.expanduser("~/Desktop/recommended_nights_reviewed.xlsx"))
ws = wb.active
rows = [dict(city=r[0], old=r[6], new=r[2], why=r[3]) for r in ws.iter_rows(min_row=2, values_only=True)]
def nid(s):
    return "day" if s.lower().startswith("day") else s.split()[0] + "n"
chg = [r for r in rows if r["new"] != r["old"]]
missing = [r["city"] for r in chg if not os.path.exists(f"itineraries/{dc.slug(r['city'])}.json")]
print("missing", missing)
# English why in chunks
eng = {}
def label(s): return "a day trip" if s.lower().startswith("day") else s
for i in range(0, len(chg), 30):
    part = chg[i:i+30]
    payload = {r["city"]: {"nights": label(r["new"]), "ko": r["why"]} for r in part}
    out = dc.ask("You write short travel copy. Output only JSON.",
        "For each city, write ONE plain-English sentence (max 30 words, second person, no city-name repetition tricks) explaining why the given stay length suits it, based on the Korean reasoning. The stay length must be stated consistently (e.g. 'One night', 'Two nights', 'A day trip is enough'). Return a JSON object {city: sentence}.\n" + json.dumps(payload, ensure_ascii=False), 6000)
    eng.update(out if isinstance(out, dict) else json.loads(re.search(r"\{.*\}", out, re.S).group(0)))
json.dump(eng, open("_why_en.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for r in chg:
    s = dc.slug(r["city"])
    ip, pp = f"itineraries/{s}.json", f"planner/{s}.json"
    a = json.load(open(ip, encoding="utf-8"))
    t = nid(r["new"])
    assert t in [x["id"] for x in a["lengths"]], (r["city"], t)
    for x in a["lengths"]:
        x.pop("recommended", None)
        if x["id"] == t: x["recommended"] = True
    json.dump(a, open(ip, "w", encoding="utf-8", newline=CRLF), ensure_ascii=False, indent=2)
    p = json.load(open(pp, encoding="utf-8"))
    w = eng.get(r["city"])
    if w: p["recommend"] = {**(p.get("recommend") or {}), "why": w}
    json.dump(p, open(pp, "w", encoding="utf-8", newline=CRLF), ensure_ascii=False, indent=2)
open("_changed.txt", "w", encoding="utf-8").write("\n".join(r["city"] for r in chg))
print("done", len(chg), "why", len(eng))
