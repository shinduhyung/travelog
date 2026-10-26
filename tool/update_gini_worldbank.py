"""Refresh assets/gini_data.json from the World Bank SI.POV.GINI indicator.

Each country gets its most recent non-empty observation (World Bank `mrnev=1`) and the survey year
is stored next to it as `survey_year`, because the years differ per country. Countries the World
Bank does not publish keep their previous value and get no survey year.
The frozen legacy fingerprint for this dataset is recomputed because this is a reviewed data update.
"""
import json
import urllib.request
from pathlib import Path

from statistics_schema import decode_statistics
from verify_statistics_migration import fingerprint

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets" / "gini_data.json"
FIXTURE = ROOT / "test" / "fixtures" / "statistics_legacy_fingerprints.json"
URL = "https://api.worldbank.org/v2/country/all/indicator/SI.POV.GINI?format=json&mrnev=1&per_page=400"
SOURCE = "https://data.worldbank.org/indicator/SI.POV.GINI"
WB_TO_APP = {"XKX": "KOS"}
TODAY = "2026-10-24"


def read_text(path):
    raw = path.read_bytes().decode("utf-8")
    return raw, "\r\n" in raw


def write_json(path, obj, like_raw, crlf):
    text = json.dumps(obj, ensure_ascii=False, indent=2)
    if crlf:
        text = text.replace("\n", "\r\n")
    if like_raw.endswith("\n") and not text.endswith("\n"):
        text += "\r\n" if crlf else "\n"
    path.write_bytes(text.encode("utf-8"))


def main():
    with urllib.request.urlopen(URL, timeout=60) as r:
        meta, rows = json.load(r)
    last_updated = meta["lastupdated"]
    wb = {}
    for row in rows:
        iso = WB_TO_APP.get(row["countryiso3code"], row["countryiso3code"])
        if iso and row["value"] is not None:
            wb[iso] = (round(float(row["value"]), 1), int(row["date"]))

    raw, crlf = read_text(ASSET)
    doc = json.loads(raw)
    table = doc["tables"][0]
    stamp = {"source_url": SOURCE, "reference_period": None, "updated_at": TODAY}
    years = sorted({y for _, y in wb.values()})
    period = f"most recent survey per country, {years[0]}-{years[-1]} (World Bank data last updated {last_updated})"
    stamp["reference_period"] = period
    doc["metadata"].update(stamp)
    table["metadata"].update(stamp)
    for metric in table["metrics"]:
        if metric["id"] == "gini_index":
            metric.update(unit="index 0-100", source_url=SOURCE, reference_period=period, updated_at=TODAY)
    if not any(m["id"] == "survey_year" for m in table["metrics"]):
        table["metrics"].insert(
            1,
            {"id": "survey_year", "unit": "year", "source_url": SOURCE, "reference_period": period, "updated_at": TODAY},
        )

    changed, same, kept, diffs = 0, 0, [], []
    app_isos = set()
    for rec in table["records"]:
        iso = rec["dimensions"]["iso_a3"]
        app_isos.add(iso)
        new = wb.get(iso)
        if new is None:
            kept.append(iso)
            continue
        old = rec["values"].get("gini_index")
        value, year = new
        if old is not None and abs(old - value) < 1e-9:
            same += 1
        else:
            changed += 1
            diffs.append((abs((old or 0) - value), iso, old, value))
        # keep key order: gini_index, survey_year, continent
        rec["values"] = {"gini_index": value, "survey_year": year, "continent": rec["values"]["continent"]}

    write_json(ASSET, doc, raw, crlf)
    fx_raw, fx_crlf = read_text(FIXTURE)
    fixture = json.loads(fx_raw)
    fixture["assets/gini_data.json"] = fingerprint(decode_statistics(doc))
    write_json(FIXTURE, fixture, fx_raw, fx_crlf)

    diffs.sort(reverse=True)
    print(f"World Bank countries with values: {len(wb)}; years {years[0]}-{years[-1]}; last updated {last_updated}")
    print(f"unchanged value: {same}; changed value: {changed}; kept old (no World Bank value): {len(kept)} {kept}")
    print("World Bank countries not in the app:", sorted(set(wb) - app_isos))
    print("largest changes (iso, old -> new):", [(i, o, n) for _, i, o, n in diffs[:10]])
    from collections import Counter
    print("survey years:", dict(sorted(Counter(y for _, y in wb.values()).items())))


if __name__ == "__main__":
    main()
