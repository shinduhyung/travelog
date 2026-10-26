"""Upload QA-passed images to Firebase Storage new_countrydex/ (never replaces an existing object).

    python upload.py          # every qa.json pass not yet in uploaded.json

raw/<stem>.jpg -> webp/<stem>.webp (1024x1024, quality 90) -> gs://.../new_countrydex/<stem>.webp with
`gcloud storage cp --no-clobber`, the same command and bucket as tool/city_travel/images/publish_images.py.
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
BUCKET = "gs://proboscis-2025.firebasestorage.app/new_countrydex/"
WEBP = HERE / "webp"
WEBP.mkdir(exist_ok=True)
DONE = HERE / "uploaded.json"

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    qa = json.loads((HERE / "qa.json").read_text(encoding="utf-8"))
    done = json.loads(DONE.read_text(encoding="utf-8")) if DONE.exists() else {}
    todo = [f for f, d in qa.items() if d.get("pass") and f not in done]
    files = []
    for f in todo:
        img = Image.open(HERE / "raw" / (Path(f).stem + ".jpg")).convert("RGB")
        if img.size != (1024, 1024):
            print("skip size", f, img.size)
            continue
        out = WEBP / f
        img.save(out, "WEBP", quality=90, method=6)
        files.append(out)
    for i in range(0, len(files), 50):
        chunk = files[i:i + 50]
        r = subprocess.run(["gcloud.cmd", "storage", "cp", "--no-clobber", "--content-type=image/webp",
                            *[str(p) for p in chunk], BUCKET], capture_output=True, text=True)
        if r.returncode:
            sys.exit("upload failed: " + (r.stderr or r.stdout)[-400:])
        for p in chunk:
            done[p.name] = BUCKET + p.name
        DONE.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"uploaded {len(files)} (total {len(done)})")
