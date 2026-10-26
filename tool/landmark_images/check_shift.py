"""Detect off-by-one naming shifts: duplicate image URLs/files, and runs of consecutive QA subject failures."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).parent
gen = json.loads((HERE / "generated.json").read_text(encoding="utf-8"))
qa = json.loads((HERE / "qa.json").read_text(encoding="utf-8")) if (HERE / "qa.json").exists() else {}

made = [(k, v) for k, v in gen.items() if isinstance(v, dict) and v.get("url") not in (None, "", "test")]
urls, hashes = {}, {}
for k, v in made:
    urls.setdefault(v["url"], []).append(k)
    f = HERE / "raw" / (Path(k).stem + ".jpg")
    if f.is_file():
        hashes.setdefault(hashlib.md5(f.read_bytes()).hexdigest(), []).append(k)
dup = [ks for ks in urls.values() if len(ks) > 1] + [ks for ks in hashes.values() if len(ks) > 1]
print("made", len(made), "| duplicate url/file groups:", len(dup))
for ks in dup:
    print("  DUP", ks)

run, worst = [], []
for k, _ in made:
    r = qa.get(k)
    if r and not r.get("subject_ok", True):
        run.append(k)
        worst = max(worst, run, key=len)
    elif r:
        run = []
print("longest run of consecutive wrong-subject:", len(worst), worst[:6])
