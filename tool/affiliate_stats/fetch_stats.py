"""Pull daily clicks / conversions / commission from every affiliate program into one file.

Automated (API):  Impact (Airalo, Omio), Partnerize (Hotels.com, Vrbo).
Manual:           GetYourGuide, Trip.com, Bounce -> add rows to manual.csv
                  (date,program,clicks,conversions,commission_usd) from each dashboard.

Usage:  python tool/affiliate_stats/fetch_stats.py [--days 30]
Output: tool/affiliate_stats/out/stats.json and stats.csv
Credentials: tool/affiliate_stats/.env (gitignored), see .env.example.
"""
import argparse
import base64
import csv
import json
import sys
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
MANUAL_PROGRAMS = ["GetYourGuide", "Trip.com", "Bounce"]


def load_env():
    env = {}
    path = HERE / ".env"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"')
    return env


def get_json(url, user, password):
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    req = urllib.request.Request(url, headers={"Authorization": f"Basic {token}", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def blank():
    return {"clicks": 0, "conversions": 0, "commission_usd": 0.0}


def fetch_impact(env, start, end, rows):
    sid, tok = env.get("IMPACT_ACCOUNT_SID"), env.get("IMPACT_AUTH_TOKEN")
    if not sid or not tok:
        return "skipped: IMPACT_ACCOUNT_SID / IMPACT_AUTH_TOKEN missing"
    base = f"https://api.impact.com/Mediapartners/{sid}"
    # Campaign id -> name, so Airalo and Omio show separately.
    names = {}
    try:
        for c in get_json(f"{base}/Campaigns?PageSize=100", sid, tok).get("Campaigns", []):
            names[str(c.get("CampaignId"))] = c.get("CampaignName") or c.get("AdvertiserName")
    except Exception as e:  # names are cosmetic
        print("impact campaigns:", e, file=sys.stderr)

    # Conversions + commission from Actions (paged).
    page = f"{base}/Actions?ActionDateStart={start}T00:00:00Z&ActionDateEnd={end}T23:59:59Z&PageSize=1000"
    while page:
        data = get_json(page, sid, tok)
        for a in data.get("Actions", []):
            if a.get("State") == "REVERSED":
                continue
            d = (a.get("EventDate") or a.get("CreationDate") or "")[:10]
            prog = "Impact: " + (names.get(str(a.get("CampaignId"))) or a.get("CampaignName") or "?")
            r = rows[(d, prog)]
            r["conversions"] += 1
            r["commission_usd"] += float(a.get("Payout") or 0)
        nxt = data.get("@nextpageuri")
        page = f"https://api.impact.com{nxt}" if nxt else None

    # Clicks: one call per campaign per day keeps it simple at this volume.
    for cid, cname in names.items():
        d = date.fromisoformat(start)
        while d <= date.fromisoformat(end):
            try:
                q = urllib.parse.urlencode({"CampaignId": cid, "Date": d.isoformat()})
                n = get_json(f"{base}/Clicks?{q}", sid, tok).get("@total", 0)
                rows[(d.isoformat(), "Impact: " + cname)]["clicks"] += int(n or 0)
            except Exception as e:
                print(f"impact clicks {cname} {d}: {e}", file=sys.stderr)
                break
            d += timedelta(days=1)
    return "ok"


def fetch_partnerize(env, start, end, rows):
    app, key, pub = (env.get(k) for k in ("PARTNERIZE_APP_KEY", "PARTNERIZE_API_KEY", "PARTNERIZE_PUBLISHER_ID"))
    if not (app and key and pub):
        return "skipped: PARTNERIZE_APP_KEY / PARTNERIZE_API_KEY / PARTNERIZE_PUBLISHER_ID missing"
    base = f"https://api.partnerize.com/reporting/report_publisher/publisher/{pub}"
    q = urllib.parse.urlencode({"start_date": f"{start} 00:00:00", "end_date": f"{end} 23:59:59", "limit": 300})
    data = get_json(f"{base}/conversion.json?{q}", app, key)
    for item in data.get("conversions", []):
        c = item.get("conversion_data", item)
        if c.get("conversion_status") == "rejected":
            continue
        d = (c.get("conversion_time") or "")[:10]
        prog = "Expedia: " + (c.get("campaign_title") or "?")
        r = rows[(d, prog)]
        r["conversions"] += 1
        r["commission_usd"] += float(c.get("publisher_commission") or 0)  # campaign currency
    try:
        data = get_json(f"{base}/click.json?{q}", app, key)
        for item in data.get("clicks", []):
            c = item.get("click", item)
            d = (c.get("set_time") or "")[:10]
            rows[(d, "Expedia: " + (c.get("campaign_title") or "?"))]["clicks"] += 1
    except Exception as e:
        print("partnerize clicks:", e, file=sys.stderr)
    return "ok"


def read_manual(start, end, rows):
    path = HERE / "manual.csv"
    if not path.exists():
        return
    with path.open(encoding="utf-8") as f:
        for m in csv.DictReader(f):
            if not (start <= m["date"] <= end):
                continue
            r = rows[(m["date"], m["program"])]
            r["clicks"] += int(m.get("clicks") or 0)
            r["conversions"] += int(m.get("conversions") or 0)
            r["commission_usd"] += float(m.get("commission_usd") or 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    args = ap.parse_args()
    end = date.today()
    start = end - timedelta(days=args.days - 1)
    s, e = start.isoformat(), end.isoformat()
    env = load_env()
    rows = defaultdict(blank)
    status = {}
    for name, fn in (("Impact", fetch_impact), ("Partnerize", fetch_partnerize)):
        try:
            status[name] = fn(env, s, e, rows)
        except Exception as ex:
            status[name] = f"error: {ex}"
    read_manual(s, e, rows)
    for p in MANUAL_PROGRAMS:
        status[p] = "manual (manual.csv)"

    out = sorted(({"date": d, "program": p, **v} for (d, p), v in rows.items() if d), key=lambda r: (r["date"], r["program"]))
    for r in out:
        r["commission_usd"] = round(r["commission_usd"], 2)
    OUT.mkdir(exist_ok=True)
    payload = {"generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
               "start": s, "end": e, "status": status, "rows": out}
    (OUT / "stats.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    with (OUT / "stats.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["date", "program", "clicks", "conversions", "commission_usd"])
        w.writeheader()
        w.writerows(out)
    programs = [("Impact", "Airalo, Omio", "API"), ("Partnerize", "Hotels.com, Vrbo", "API"),
                ("GetYourGuide", "Tours", "수동"), ("Trip.com", "Flights/hotels", "수동"), ("Bounce", "Luggage", "수동")]
    with (OUT / "programs.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["source", "brands", "method", "status", "checked_at"])
        for src, brands, method in programs:
            w.writerow([src, brands, method, status[src], payload["generated_at"]])
    for k, v in status.items():
        print(f"{k:12} {v}")
    print(f"{len(out)} rows -> {OUT / 'stats.json'}")


if __name__ == "__main__":
    main()
