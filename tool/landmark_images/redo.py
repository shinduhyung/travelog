"""Second pass for images that were skipped (stub/brand prompts) or failed QA: rewrite each prompt from scratch.

Iconic signage that IS the landmark's identity (Hollywood Sign, Chicago Theatre marquee, a famous neon sign) is kept
and flagged allow_text, so qa.py does not fail it for lettering; ordinary brand logos stay forbidden.
Rewritten entries are removed from generated.json / qa.json so leo_queue.py makes them again.

    python redo.py
"""
import json
import sys
from concurrent.futures import ThreadPoolExecutor

from make_prompts import FOOD, HERE, KEY, STYLE, clean
import urllib.request

ASK = """Landmark for a travel app illustration: {name} ({city}). Category: {attrs}. Notes: {overview}
A previous prompt failed: {why}
Previous description: {old}

Describe what it really looks like, from your knowledge. Return only JSON:
{{"desc": "<2-3 sentences of concrete visual detail: shape, materials, colours, setting; for food the dish itself>",
 "view": "<one camera view sentence>", "avoid": "<one sentence of things NOT to draw, or empty>",
 "sign": "<if a famous sign, marquee or logo is the thing people recognise this place by (e.g. Hollywood Sign, Chicago Theatre marquee, Moulin Rouge sign, Shibuya 109), its exact wording; otherwise empty>",
 "closed": <true only if it no longer exists>}}
Never mention people. Do not invent brand logos."""


def ask(item):
    f, row, why = item
    old = row["prompt"].split(f"{row['name']}, {row['city']}:", 1)[-1][:600]
    body = json.dumps({"model": "claude-sonnet-5-5", "max_tokens": 1500, "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": ASK.format(
                           name=row["name"], city=row["city"], attrs=", ".join(row["attributes"] or []),
                           overview=row["overview"][:400], why=why, old=old)}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=90))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            d = json.loads(txt[txt.index("{"): txt.rindex("}") + 1])
            if d.get("closed"):
                return f, None
            food = any(a in ("Food", "Fast Food", "Restaurant", "Cafe") for a in row["attributes"] or [])
            avoid = clean(d.get("avoid", "")).strip()
            p = (FOOD if food else STYLE).format(name=row["name"], city=row["city"], desc=clean(d["desc"]).rstrip(".") + ".",
                                                 view=clean(d["view"]).rstrip("."), avoid=(avoid + " ") if avoid else "")
            sign = str(d.get("sign") or "").strip()
            if sign and not food:
                p = p.replace("No text, letters, labels, watermark or border;",
                              f'The only lettering allowed is the famous "{sign}" sign, exactly as it really appears; '
                              "no other text, labels, logos, watermark or border;")
            return f, {**row, "prompt": p, "allow_text": bool(sign and not food)}
        except Exception as e:
            err = e
    print("failed", f, err)
    return f, None


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    P = lambda n: HERE / n
    prompts, gen = json.loads(P("prompts.json").read_text("utf-8")), json.loads(P("generated.json").read_text("utf-8"))
    qa = json.loads(P("qa.json").read_text("utf-8"))
    items = [(f, prompts[f], v.get("why", "")) for f, v in gen.items()
             if v["status"] == "fail" and "closed" not in v.get("why", "") and f in prompts]
    items += [(f, prompts[f], "QA: " + d.get("note", "")) for f, d in qa.items() if not d["pass"] and f in prompts]
    print("rewriting", len(items))
    n = 0
    with ThreadPoolExecutor(8) as pool:
        for f, v in pool.map(ask, items):
            if v:
                prompts[f] = v
                gen.pop(f, None)
                qa.pop(f, None)
                n += 1
    for name, obj in (("prompts.json", prompts), ("generated.json", gen), ("qa.json", qa)):
        P(name).write_text(json.dumps(obj, ensure_ascii=False, indent=1), encoding="utf-8")
    print("requeued", n, "| with sign:", sum(1 for f, v in prompts.items() if v.get("allow_text") and f not in gen))
