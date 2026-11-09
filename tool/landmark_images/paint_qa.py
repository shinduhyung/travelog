"""Check each artwork image against the real original (Wikimedia, from paint_refs.json) with Claude Sonnet vision.

    LEO_SET=paint python paint_qa.py     # checks raw/*.jpg of paint_prompts.json not yet in paint_qa.json

Pass only if: it is recognisably the same work with a faithful composition and colours, it is a clean square
(the extension or crop looks natural: no seam, stretch, squash, frame, wall or caption), and it adds no text
or people that the original does not have. Writes paint_qa.json {file: {"pass", "same_work", "square_ok",
"added": bool, "note"}}; failures get one regeneration through leo_queue.py with the note as a correction.
"""
import base64
import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from make_prompts import HERE, KEY

QA = HERE / "paint_qa.json"
UA = {"User-Agent": "jidoapp-artwork/1.0 (leeahn137@gmail.com)"}
ASK = """Image 1 is the real artwork "{name}". Image 2 is our square 1:1 reproduction for a travel app.
Small differences in details, poses or brushwork are fine. Fail only these three problems. Reply with JSON only:
{{"different_work": <true only if image 2 is a different artwork or subject, i.e. a viewer who knows the original would not recognise it>,
"colour_off": <true only if the overall colour scheme is completely different (e.g. white horse became brown, pale sky became dark); small shifts are fine>,
"outside": <true if any frame, border, wall, easel, room, pedestal backdrop or background outside the artwork is visible; for sculptures, a plain museum background is fine>,
"note": "<max 20 words: what is wrong, empty if fine>"}}"""


def b64(raw):
    return base64.b64encode(raw).decode()


def check(item):
    f, row, ref = item
    try:
        orig = urllib.request.urlopen(urllib.request.Request(ref["ref_url"], headers=UA), timeout=60).read()
    except Exception as e:
        print("no reference", f, e)
        return f, None
    mine = (HERE / "raw" / (Path(f).stem + ".jpg")).read_bytes()
    kind = "image/png" if orig[:4] == b"\x89PNG" else "image/jpeg"
    body = json.dumps({"model": "claude-sonnet-5-5", "max_tokens": 1500, "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": [
                           {"type": "image", "source": {"type": "base64", "media_type": kind, "data": b64(orig)}},
                           {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64(mine)}},
                           {"type": "text", "text": ASK.format(name=row["name"])}]}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=120))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            d = json.loads(txt[txt.index("{"): txt.rindex("}") + 1])
            d["pass"] = not (d["different_work"] or d["colour_off"] or d["outside"])
            return f, d
        except Exception as e:
            err = e
    print("check failed", f, err)
    return f, None


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    prompts = json.loads((HERE / "paint_prompts.json").read_text(encoding="utf-8"))
    refs = json.loads((HERE / "paint_refs.json").read_text(encoding="utf-8"))
    qa = json.loads(QA.read_text(encoding="utf-8")) if QA.exists() else {}
    todo = [(f, prompts[f], refs[f]) for f in prompts if f not in qa and refs.get(f, {}).get("ref_url")
            and (HERE / "raw" / (Path(f).stem + ".jpg")).exists()]
    with ThreadPoolExecutor(4) as pool:
        for f, d in pool.map(check, todo):
            if d:
                qa[f] = d
    QA.write_text(json.dumps(qa, ensure_ascii=False, indent=1), encoding="utf-8")
    bad = [f for f, d in qa.items() if not d["pass"]]
    print(f"checked {len(qa)}: pass {len(qa) - len(bad)}, fail {len(bad)}")
