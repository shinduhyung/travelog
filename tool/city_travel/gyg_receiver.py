"""Tiny local receiver for the GetYourGuide harvest.

GetYourGuide blocks scripted requests (403), so the harvest runs inside a normal browser tab on
getyourguide.com (tour_harvest.js) and POSTs each city's compact tour list here; this saves it to
gyg/<slug>.json. Run: python tool/city_travel/gyg_receiver.py  (port 8766)
"""
import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer as HTTPServer
from pathlib import Path

OUT = Path(__file__).resolve().parent / "gyg"
OUT.mkdir(exist_ok=True)
HOTELS = Path(__file__).resolve().parents[1] / "hotel_prices" / "live"
HOTELS.mkdir(exist_ok=True)


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            d = json.loads(body)
            name = re.sub(r"[^a-z0-9-]+", "-", d["city"].lower()).strip("-")
            (OUT / f"{name}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
            print("saved", name, len(d.get("tours", [])))
        except Exception as err:
            print("bad post", err)
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_GET(self):
        # The page's CSP blocks fetch() to localhost, but a top-level navigation is allowed:
        # the harvest ends with location.href = "http://127.0.0.1:8766/save?d=<json list of cities>".
        from urllib.parse import parse_qs, urlparse
        q = parse_qs(urlparse(self.path).query)
        n = 0
        for d in json.loads(q.get("d", ["[]"])[0]):
            name = re.sub(r"[^a-z0-9-]+", "-", d["city"].lower()).strip("-")
            out = HOTELS if d.get("kind") == "hotels" else OUT  # hotel_harvest.js (Google Hotels list prices)
            (out / f"{name}.json").write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
            n += 1
        print("saved", n, "cities")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(f"saved {n} cities".encode())

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", 8766), H).serve_forever()
