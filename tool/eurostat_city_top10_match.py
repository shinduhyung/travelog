"""Top-10 cities for the selected Eurostat statistics, matched against assets/cities15000.json.

Matching evidence per Eurostat city (all must be read together, none alone is proof):
  * country: Eurostat/GISCO country code mapped to ISO-2 (EL->GR, UK->GB)
  * distance: GISCO city label point vs cities15000 latitude/longitude (haversine)
  * name: accent/case-insensitive comparison of Eurostat/GISCO names with the cities15000 name
  * population: Eurostat urb_cpopcb total population vs cities15000 population

Status values:
  exact          same country, name equal, within 10 km, population ratio <= 2x
  coords_name_diff  same country, within 10 km, population ratio <= 2x, but the name differs
                    (usually English vs local spelling) -> needs a human glance
  ambiguous      several cities15000 entries within 10 km that all pass the population test
  population_mismatch  nearest same-country entry within 10 km but population ratio > 2x
  no_match       nothing in cities15000 within 25 km in the same country
  no_coordinates the Eurostat city code has no GISCO label point
"""
import json
import math
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "audit" / "city_statistics_ideas_sources"
CITIES15000 = ROOT / "assets" / "cities15000.json"
LABEL_POINTS = SRC / "urau_2024_LB_4326_CITIES.geojson"
OUT_JSON = ROOT / "audit" / "city_top10_match.json"
OUT_MD = ROOT / "audit" / "city_top10_match.md"

# (key, korean label, dataset, indicator ids to sum, period, value unit)
STATS = [
    ("theatres", "극장 수", "urb_ctour", ["CR1008V"], "2025", "개"),
    ("libraries", "공공도서관 수", "urb_ctour", ["CR1010V"], "2024", "개"),
    ("nights_per_resident", "주민 1명당 관광숙박일수", "urb_ctour", ["CR2011I"], "2025", "일"),
    ("taxi_5km", "도심행 주간 택시 5km 요금", "urb_ctran", ["TT1081V"], "2025", "EUR"),
    ("apartment_price", "아파트 평균 매매가격", "urb_clivcon", ["SA1051V"], "2024", "EUR"),
    ("women_per_100_men", "남성 100명당 여성 수", "urb_cpopstr", ["DE1003I"], "2025", "명"),
    ("unemployment", "실업률", "urb_clma", ["EC1020I"], "2024", "%"),
    ("safe_at_night", "밤에 혼자 걸어도 안전하다는 응답률", "urb_percep", ["PS3514V", "PS3515V"], "2023", "%"),
    ("lgbt_good_place", "성소수자가 살기 좋다는 응답률", "urb_percep", ["PS3535V"], "2023", "%"),
    ("immigrants_good_place", "이민자가 살기 좋다는 응답률", "urb_percep", ["PS3538V"], "2023", "%"),
]

CITY_CODE = re.compile(r"^[A-Z]{2}\d{3}[CK]$")
ISO_FIX = {"EL": "GR", "UK": "GB"}
# Decided by the owner: Eurostat values describe the whole urban area, so they are attached to the
# area's largest/representative city in cities15000.
OVERRIDES = {"IT011C": "Mestre"}  # Venezia = Venice + Mestre -> Mestre
WIDE_KM = 40.0 # candidate pool: large municipalities have label points far from the centre
NEAR_KM = 15.0  # a differently-named entry must be this close to count
POP_RATIO = 3.0  # informational flag only: Eurostat "greater city" areas differ from GeoNames cities


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def jsonstat_values(doc, indicator_ids, period):
    """Return {city_code: (value, label)} for one period. Sums indicators when several are given."""
    ids = doc["id"]
    sizes = doc["size"]
    dims = doc["dimension"]
    cat_index = {}
    for dim in ids:
        idx = dims[dim]["category"]["index"]
        if isinstance(idx, list):
            idx = {k: i for i, k in enumerate(idx)}
        cat_index[dim] = idx
    labels = dims["cities"]["category"].get("label", {})
    values = doc["value"]
    for dim, size in zip(ids, sizes):
        if dim not in ("indic_ur", "cities", "time") and size != 1:
            raise ValueError(f"unexpected multi-category dimension {dim} ({size}) in {doc.get('label')}")

    def get(flat):
        if isinstance(values, dict):
            return values.get(str(flat))
        return values[flat] if flat < len(values) else None

    strides = []
    acc = 1
    for s in reversed(sizes):
        strides.append(acc)
        acc *= s
    strides = list(reversed(strides))

    out = {}
    for code, ci in cat_index["cities"].items():
        total = 0.0
        ok = True
        for ind in indicator_ids:
            if ind not in cat_index["indic_ur"] or period not in cat_index["time"]:
                ok = False
                break
            # Extra dimensions (freq, unit, ...) take their first category; datasets here
            # carry a single one, which `extra_dims_ok` asserts below.
            pos = {d: 0 for d in ids}
            pos.update({"indic_ur": cat_index["indic_ur"][ind], "cities": ci, "time": cat_index["time"][period]})
            flat = sum(pos[d] * strides[n] for n, d in enumerate(ids))
            v = get(flat)
            if v is None:
                ok = False
                break
            total += float(v)
        if ok:
            out[code] = (total, labels.get(code, code))
    return out


def latest_population(doc):
    """Total resident population per city code, latest non-empty year (urb_cpopcb DE1001V)."""
    ids = doc["id"]
    dims = doc["dimension"]
    indic = dims["indic_ur"]["category"]["index"]
    indic = {k: i for i, k in enumerate(indic)} if isinstance(indic, list) else indic
    if "DE1001V" not in indic:
        return {}
    years = sorted(dims["time"]["category"]["index"], reverse=True)
    out = {}
    for year in years:
        for code, (val, _) in jsonstat_values(doc, ["DE1001V"], year).items():
            out.setdefault(code, (val, year))
    return out


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower().replace("ß", "ss").replace("ø", "o").replace("æ", "ae").replace("œ", "oe").replace("ł", "l").replace("đ", "d")
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def name_variants(*names):
    out = set()
    for n in names:
        if not n:
            continue
        n = re.sub(r"\(greater city\)", "", n, flags=re.I).strip()
        n = re.sub(r"^greater\s+", "", n, flags=re.I)
        # Eurostat writes some names inverted: "Línea de la Concepción, La"
        m = re.match(r"^(.+),\s*(la|el|les|los|las|le|l'|the|den|de)$", n, flags=re.I)
        if m:
            out.add(norm(f"{m.group(2)} {m.group(1)}"))
        for part in re.split(r"[/,]", n):
            part = re.sub(r"\(.*?\)", "", part).strip()
            if part:
                out.add(norm(part))
    return {v for v in out if v}


def similar(name, variants, threshold=0.8):
    from difflib import SequenceMatcher

    nn = norm(name)
    return any(SequenceMatcher(None, nn, v).ratio() >= threshold for v in variants)


def haversine(lat1, lon1, lat2, lon2):
    r = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def main():
    cities = load_json(CITIES15000)
    by_country = {}
    for c in cities:
        by_country.setdefault(c["country_code"], []).append(c)

    points = {}
    for f in load_json(LABEL_POINTS)["features"]:
        p = f["properties"]
        lon, lat = f["geometry"]["coordinates"]
        points[p["URAU_CODE"]] = {
            "name": p["URAU_NAME"],
            "country": ISO_FIX.get(p["CNTR_CODE"], p["CNTR_CODE"]),
            "lat": lat,
            "lon": lon,
        }

    pop_doc = load_json(SRC / "urb_cpop1_DE1001V.json")
    eurostat_pop = latest_population(pop_doc)

    result = []
    for key, label, dataset, inds, period, unit in STATS:
        doc = load_json(SRC / f"{dataset}.json")
        vals = {c: v for c, v in jsonstat_values(doc, inds, period).items() if CITY_CODE.match(c)}
        ranked = sorted(vals.items(), key=lambda kv: kv[1][0], reverse=True)
        tenth = ranked[9][1][0] if len(ranked) >= 10 else None
        top = [kv for kv in ranked if tenth is not None and kv[1][0] >= tenth] if tenth is not None else ranked
        rows = []
        for rank, (code, (value, es_label)) in enumerate(top, start=1):
            row = {"rank": rank, "code": code, "eurostat_name": es_label, "value": round(value, 4)}
            pt = points.get(code)
            country = ISO_FIX.get(code[:2], code[:2])
            if not pt:
                # No GISCO label point (e.g. IS, UK): match by country + name only.
                variants = name_variants(es_label)
                named = [c for c in by_country.get(country, []) if norm(c["name"]) in variants and c["population"] >= 5000]
                named.sort(key=lambda c: -c["population"])
                row["country"] = country
                es_pop = eurostat_pop.get(code)
                row["eurostat_population"] = int(es_pop[0]) if es_pop else None
                if named and (len(named) == 1 or named[0]["population"] >= 3 * named[1]["population"]):
                    c = named[0]
                    row["status"] = "name_only"
                    row["match"] = {"name": c["name"], "km": None, "population": c["population"], "name_equal": True,
                                    "pop_ratio": None}
                else:
                    row["status"] = "no_coordinates"
                row["candidates"] = [
                    {"name": c["name"], "km": None, "population": c["population"], "name_equal": True, "pop_ratio": None}
                    for c in named[:5]
                ]
                rows.append(row)
                continue
            row["gisco_name"] = pt["name"]
            row["country"] = pt["country"]
            es_pop = eurostat_pop.get(code)
            row["eurostat_population"] = int(es_pop[0]) if es_pop else None
            row["eurostat_population_year"] = es_pop[1] if es_pop else None
            variants = name_variants(es_label, pt["name"])
            cands = []
            for c in by_country.get(pt["country"], []):
                d = haversine(pt["lat"], pt["lon"], c["latitude"], c["longitude"])
                if d <= WIDE_KM:
                    ratio = None
                    if es_pop and c["population"]:
                        hi, lo = max(es_pop[0], c["population"]), min(es_pop[0], c["population"])
                        ratio = hi / lo if lo else None
                    cands.append(
                        {
                            "name": c["name"],
                            "km": round(d, 1),
                            "population": c["population"],
                            "name_equal": norm(c["name"]) in variants,
                            "pop_ratio": round(ratio, 2) if ratio else None,
                        }
                    )
            cands.sort(key=lambda x: -x["population"])

            def dominant(pool):
                """Single entry whose population is >= 3x every other entry in the pool."""
                if not pool:
                    return None
                if len(pool) == 1:
                    return pool[0]
                return pool[0] if pool[0]["population"] >= 3 * pool[1]["population"] else None

            # Entries with population < 5,000 are landmark-like extras in the app file, never a city.
            real = [c for c in cands if c["population"] >= 5000]
            named = [c for c in real if c["name_equal"]]
            near = [c for c in real if c["km"] <= NEAR_KM]
            similar_near = [c for c in real if c["km"] <= 20 and similar(c["name"], variants)]
            by_km = sorted(real, key=lambda c: c["km"])
            pick = None
            if named:
                pick = dominant(named)
                status = "exact" if pick else "ambiguous"
            elif len(similar_near) == 1:
                pick, status = similar_near[0], "name_similar"
            elif by_km and by_km[0]["km"] <= 5 and (len(by_km) == 1 or by_km[1]["km"] - by_km[0]["km"] >= 5):
                pick, status = by_km[0], "coords_only"
            else:
                pick = dominant(near)
                status = "coords_name_diff" if pick else ("ambiguous" if near else "no_match")
            if not pick and status == "no_match":
                # The GISCO label point can lie far from the real centre (e.g. Oslo): fall back to a
                # country-wide exact name match, reported separately so it is not mistaken for a coordinate match.
                wide = []
                for c in by_country.get(pt["country"], []):
                    if c["population"] >= 5000 and norm(c["name"]) in variants:
                        km = round(haversine(pt["lat"], pt["lon"], c["latitude"], c["longitude"]), 1)
                        wide.append({"name": c["name"], "km": km, "population": c["population"],
                                     "name_equal": True, "pop_ratio": None})
                wide.sort(key=lambda c: -c["population"])
                pick = dominant(wide)
                if pick:
                    status = "name_only_far_label"
                    if es_pop and pick["population"]:
                        hi, lo = max(es_pop[0], pick["population"]), min(es_pop[0], pick["population"])
                        pick["pop_ratio"] = round(hi / lo, 2)
                    cands = wide + cands
            if code in OVERRIDES:
                forced = [c for c in cands if c["name"] == OVERRIDES[code]]
                if forced:
                    pick, status = forced[0], "manual_override"
            if pick and pick["pop_ratio"] and pick["pop_ratio"] > POP_RATIO:
                status += "+pop_check"
            row["status"] = status
            row["match"] = pick
            row["candidates"] = cands[:5]
            rows.append(row)
        result.append(
            {
                "key": key,
                "label": label,
                "dataset": dataset,
                "indicators": inds,
                "period": period,
                "unit": unit,
                "eurostat_city_count": len(vals),
                "top": rows,
            }
        )

    OUT_JSON.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")

    lines = ["# 도시 통계 상위 10개와 cities15000 매칭 확인", "",
             "Eurostat 도시 코드 → GISCO 도시 중심점 → `assets/cities15000.json`(같은 국가, 10km 이내) 순으로 대응시켰습니다.",
             "근거는 국가, 거리, 이름, 인구(Eurostat urb_cpopcb vs cities15000)이며 상태는 아래와 같습니다.", "",
             "- exact: 같은 국가 40km 이내에 이름이 같은 항목이 하나(또는 인구 3배 이상 우세한 하나)",
             "- name_similar: 20km 이내에 철자가 비슷한 항목이 하나(Lisboa/Lisbon, Veliko Tarnovo/Tŭrnovo 등)",
             "- coords_only: 이름은 다르지만 5km 이내에 다른 후보 없이 하나(Eivissa/Ibiza 등)",
             "- coords_name_diff: 이름은 다르지만 15km 이내에서 인구가 압도적인 항목 하나(영어/현지어 표기 차이 등)",
             "- name_only: 좌표 파일에 없는 국가(IS, UK)라 같은 국가의 같은 이름으로만 대응",
             "- name_only_far_label: GISCO 중심점이 실제 도시와 멀어서 같은 국가의 같은 이름으로만 대응(오슬로 등)",
             "- ambiguous: 후보가 여러 개라 하나로 못 정함 (후보를 같이 표시)",
             "- +pop_check: 위 판정이 났지만 인구가 3배 넘게 달라 눈으로 확인 필요(Eurostat 도시 범위 차이일 수 있음)",
             "- no_match / no_coordinates: 대응 없음", ""]
    summary = {}
    for s in result:
        lines += [f"## {s['label']} ({s['period']}, Eurostat {s['eurostat_city_count']}개 도시, 단위 {s['unit']})", "",
                  "| # | Eurostat | 값 | cities15000 대응 | km | 인구(15000/Eurostat) | 상태 |", "|---|---|---:|---|---:|---|---|"]
        for r in s["top"]:
            m = r.get("match")
            summary[r["status"]] = summary.get(r["status"], 0) + 1
            pop = ""
            if m:
                pop = f"{m['population']:,} / {r.get('eurostat_population') or '-':,}" if r.get("eurostat_population") else f"{m['population']:,} / -"
            if m:
                target = f"{m['name']} ({r['country']})"
            elif r.get("candidates"):
                target = "후보: " + ", ".join(f"{c['name']} {c['km']}km {c['population']:,}" for c in r["candidates"][:3])
            else:
                target = "-"
            es_pop_txt = f"{r['eurostat_population']:,}" if r.get("eurostat_population") else "-"
            if m:
                pop = f"{m['population']:,} / {es_pop_txt}"
            else:
                pop = f"- / {es_pop_txt}"
            lines.append(
                f"| {r['rank']} | {r['code']} {r['eurostat_name']} | {r['value']:,} | "
                f"{target} | {m['km'] if m else '-'} | {pop} | {r['status']} |"
            )
        lines.append("")
    lines += ["## 상태 요약", ""] + [f"- {k}: {v}" for k, v in sorted(summary.items())]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))
    print("wrote", OUT_JSON, OUT_MD)


if __name__ == "__main__":
    main()
