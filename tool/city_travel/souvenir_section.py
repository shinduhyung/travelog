"""Souvenirs section for build_page.py, from souvenirs/<slug>.json.

Each item: name, file (photo in Firebase storage souvenir/<file>, 512 px), unit, currency, low, high,
where, about, tip, basis. Cities with no file get no section.
"""
import html
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
e = html.escape

CSS = """
.souv { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; }
.souv article { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; overflow: hidden; display: flex; flex-direction: column; }
.souv .pic { width: 100%; aspect-ratio: 1; }
.souv .body { padding: 14px 16px 16px; display: flex; flex-direction: column; gap: 8px; }
.souv h3 { margin: 0; font: 700 18px/1.3 var(--font-display); }
.souv .price { font: 800 20px/1.2 var(--font-display); color: var(--accent); }
.souv .price small { font: 500 13px/1.3 var(--font-body, inherit); color: var(--muted); margin-left: 6px; }
.souv p { margin: 0; font-size: 14px; line-height: 1.5; }
.souv .where { font-size: 13px; color: var(--muted); }
.souv .tip { font-size: 13px; padding: 8px 10px; background: var(--accent-soft); border-radius: 10px; }
"""


def render(slug, photo):
    """photo(storage_path, width) -> data URI or None."""
    f = HERE / "souvenirs" / f"{slug}.json"
    if not f.is_file():
        return ""
    cards = []
    for it in json.loads(f.read_text(encoding="utf-8")):
        it = {k: "" if v is None else v for k, v in it.items()}   # DeepSeek leaves a field null now and then
        src = it["file"] and photo(f"souvenir%2F{it['file']}", 480)
        img = f'<img src="{src}" alt="">' if src else '<span class="pic" aria-hidden="true"></span>'
        price = f"{e(it['currency'])} {it['low']}" + (f"–{it['high']}" if it['high'] not in (None, "", it['low']) else "")
        cards.append(
            f'<article>{img}<div class="body"><h3>{e(it["name"])}</h3>'
            f'<div class="price">{price}<small>{e(it["unit"])} · {e(it["basis"]).lower()}</small></div>'
            f'<p>{e(it["about"])}</p><div class="where">Where: {e(it["where"])}</div>' +
            (f'<div class="tip">{e(it["tip"])}</div>' if it["tip"] else '') + f'</div></article>')
    return (f'<section aria-labelledby="h-souvenirs"><h2 id="h-souvenirs">Souvenirs</h2>'
            f'<div class="souv">{"".join(cards)}</div></section>')
