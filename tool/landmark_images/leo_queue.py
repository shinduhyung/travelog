"""Work queue for the Leonardo run (one image at a time).

    python leo_queue.py next                 # prints {"file", "name", "prompt"} of the next image to make, or DONE
    python leo_queue.py done <file> <url>    # downloads the image to raw/<stem>.jpg (must be 1024x1024), records it
    python leo_queue.py fail <file> <why>    # records a failure so it is skipped (retried in the QA pass)
    python leo_queue.py status               # counts

Files: prompts.json (from make_prompts.py), generated.json (results). Images land only in raw/ here,
named like Firebase new_countrydex/{iso3}_{snake}.webp, never in the browser's Downloads folder.
"""
import io
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
RAW.mkdir(exist_ok=True)
GEN = HERE / "generated.json"


def load(p, default):
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else default


def save(gen):
    GEN.write_text(json.dumps(gen, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1]
    prompts, gen = load(HERE / "prompts.json", {}), load(GEN, {})
    if cmd == "next":
        nxt = next((v for f, v in prompts.items() if f not in gen), None)
        if not nxt:  # main pass done: one retry for QA failures, with the reviewer's note as a correction
            qa = load(HERE / "qa.json", {})
            for f, d in qa.items():
                if not d.get("pass") and f in prompts and not gen.get(f, {}).get("retried"):
                    fix = d.get("note", "")
                    if d.get("people"):
                        fix += " Remove every person, face, hand and human-like statue."
                    if d.get("text"):
                        fix += " Remove all letters, signs and logos."
                    nxt = {**prompts[f], "prompt": prompts[f]["prompt"] + f" Correction of a previous attempt: {fix}"}
                    gen[f]["retried"] = True
                    qa.pop(f)  # re-check the new image
                    (HERE / "qa.json").write_text(json.dumps(qa, ensure_ascii=False, indent=1), encoding="utf-8")
                    save(gen)
                    break
        print(json.dumps({"file": nxt["file"], "name": nxt["name"], "prompt": nxt["prompt"]}, ensure_ascii=False)
              if nxt else "DONE")
    elif cmd == "done":
        f, url = sys.argv[2], sys.argv[3].split("?")[0]
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        raw = urllib.request.urlopen(req, timeout=60).read()
        size = Image.open(io.BytesIO(raw)).size
        if size != (1024, 1024):
            gen[f] = {"status": "bad_size", "url": url, "size": size}
            save(gen)
            sys.exit(f"STOP: {f} is {size}, not 1024x1024")
        (RAW / (Path(f).stem + ".jpg")).write_bytes(raw)
        gen[f] = {"status": "made", "url": url, "retried": gen.get(f, {}).get("retried", False)}
        save(gen)
        print(f"saved raw/{Path(f).stem}.jpg ({sum(1 for v in gen.values() if v['status'] == 'made')} made)")
    elif cmd == "fail":
        gen[sys.argv[2]] = {"status": "fail", "why": " ".join(sys.argv[3:])}
        save(gen)
        print("noted")
    elif cmd == "status":
        from collections import Counter
        print(len(prompts), "prompts;", dict(Counter(v["status"] for v in gen.values())))
