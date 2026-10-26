"""Refresh assets/economy_data.json from an IMF World Economic Outlook extract.

Input: a text file of `ISO:gdp_nominal|gdp_ppp|population;...` rows (one value set per country,
USD billions, international-dollar billions, millions of people), taken from the IMF DataMapper
indicators NGDPD, PPPGDP and LP for the stated year.

Countries the IMF does not publish (territories) or has no value for keep their previous numbers.
The frozen legacy fingerprint for this dataset is recomputed because this is a reviewed data update.

Usage: python tool/update_economy_imf.py <rows.txt> <year> <edition label> <edition url>
"""
import json
import sys
from pathlib import Path

from statistics_schema import decode_statistics
from verify_statistics_migration import fingerprint

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets" / "economy_data.json"
FIXTURE = ROOT / "test" / "fixtures" / "statistics_legacy_fingerprints.json"
IMF_TO_APP = {"UVK": "KOS", "WBG": "PSE"}
TODAY = "2026-10-24"


def parse_rows(path):
    rows = {}
    for chunk in Path(path).read_text(encoding="utf-8").replace("\n", ";").split(";"):
        chunk = chunk.strip()
        if not chunk:
            continue
        iso, vals = chunk.split(":")
        g, p, l = (float(v) if v != "" else None for v in vals.split("|"))
        rows[IMF_TO_APP.get(iso, iso)] = {"gdp_nominal": g, "gdp_ppp": p, "population": l}
    return rows


def main():
    rows_path, year, edition, url = sys.argv[1:5]
    imf = parse_rows(rows_path)
    raw = ASSET.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    doc = json.loads(raw)

    meta = {"source_url": url, "reference_period": f"{year} ({edition}; current-year estimate/projection)", "updated_at": TODAY}
    doc["metadata"].update(meta)
    table = doc["tables"][0]
    table["metadata"].update(meta)
    units = {"gdp_nominal": "USD billions", "gdp_ppp": "international dollars, billions", "population": "millions of people"}
    for metric in table["metrics"]:
        if metric["id"] in units:
            metric.update(unit=units[metric["id"]], source_url=url, reference_period=str(year), updated_at=TODAY)

    changed = {k: 0 for k in units}
    kept_territories, kept_missing, big_moves = [], [], []
    for rec in table["records"]:
        iso = rec["dimensions"]["iso_a3"]
        src = imf.get(iso)
        if src is None:
            kept_territories.append(iso)
            continue
        for key in units:
            new = src[key]
            old = rec["values"].get(key)
            if new is None:
                kept_missing.append(f"{iso}.{key}")
                continue
            if old and (new / old > 3 or new / old < 1 / 3):
                big_moves.append(f"{iso}.{key}: {old} -> {new}")
            rec["values"][key] = new
            changed[key] += 1

    app_isos = {r["dimensions"]["iso_a3"] for r in table["records"]}
    not_in_app = sorted(set(imf) - app_isos)

    text = json.dumps(doc, ensure_ascii=False, indent=2)
    if crlf:
        text = text.replace("\n", "\r\n")
    if raw.endswith("\n") and not text.endswith("\n"):
        text += "\r\n" if crlf else "\n"
    ASSET.write_bytes(text.encode("utf-8"))

    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    fixture["assets/economy_data.json"] = fingerprint(decode_statistics(doc))
    fx_raw = FIXTURE.read_bytes().decode("utf-8")
    fx_text = json.dumps(fixture, ensure_ascii=False, indent=2)
    if "\r\n" in fx_raw:
        fx_text = fx_text.replace("\n", "\r\n")
    if fx_raw.endswith("\n") and not fx_text.endswith("\n"):
        fx_text += "\r\n" if "\r\n" in fx_raw else "\n"
    FIXTURE.write_bytes(fx_text.encode("utf-8"))

    print("updated values:", changed)
    print("kept old values (not published by IMF):", len(kept_territories), kept_territories)
    print("kept old values (IMF empty for this year):", kept_missing)
    print("IMF countries absent from the app:", not_in_app)
    print("moves beyond 3x (check):", big_moves)


if __name__ == "__main__":
    main()
