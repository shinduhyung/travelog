"""Write one Leonardo prompt per landmark in targets.json with Claude Haiku (API key: ANTHROPIC_API_KEY in .env).

    python tool/landmark_images/make_prompts.py        # -> prompts.json (resumes; existing entries kept)

Haiku only writes the one-line visual description and the view; the style text and the no-people clause are
fixed here so every image follows the existing set (PIPELINE.md section 7).
"""
import json
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
KEY = next(l.split("=", 1)[1].strip() for l in (ROOT / ".env").read_text(encoding="utf-8").splitlines()
           if l.startswith("ANTHROPIC_API_KEY="))
OUT = HERE / "prompts.json"

# Fixed text copied from the prompts of the published set (tool/city_travel/images/*/prompts.json).
STYLE = ("Create one square 1:1 landmark illustration for a travel app. Match ONLY the painting style of the attached "
         "reference images: soft detailed hand-painted watercolor and gouache, fine matte paper grain, warm sunlight, "
         "slightly faded cream and pastel colours, carefully observed architectural details and gentle shadows. Do not "
         "copy the reference buildings or landscapes. {name}, {city}: {desc} {view}. {avoid}Keep the subject clearly "
         "identifiable and well composed, fully inside the square with breathing room. For outdoor scenes use pale blue "
         "sky and large soft cream-white clouds. For indoor/art/food subjects keep their appropriate setting instead, "
         "with the space completely empty. No text, letters, labels, watermark or border; no people anywhere, including "
         "tiny background figures, silhouettes, portraits or reflections. This must be a single finished illustration, "
         "not a collage.")
FOOD = ("Create ONE square 1024x1024 travel food illustration. Match ONLY the painting style of the six attached "
        "references: detailed hand-painted watercolor and gouache, matte paper texture, warm natural sunlight, softly "
        "faded pastel colours, delicate brushwork. Show a culturally authentic, appetizing serving of {name} ({city}): "
        "{desc} Close three-quarter tabletop view, food is the clear main subject, traditional simple ceramic plate or "
        "bowl and restrained local table setting, believable ingredients and textures. No landscape, landmark buildings "
        "or scenery from the references. STRICTLY NO PEOPLE anywhere, no hands, faces, silhouettes, human reflections, "
        "portraits or figurines. No text, letters, labels, logos, watermark or border. One finished image, not a collage. "
        "Food catalogue item: {name}.")
PEOPLE = re.compile(r"\b(people|person|visitors?|tourists?|crowds?|pedestrians?|figures?|silhouettes?|worshippers?|"
                    r"pilgrims?|shoppers?|swimmers?|surfers?|locals?|families|children|guards?|vendors?|diners?)\b", re.I)


def clean(desc):
    """Drop any sentence that brings people into the picture (the SeaWorld prompt asked for visitor silhouettes)."""
    keep = [s for s in re.split(r"(?<=[.!?])\s+", desc) if s and not PEOPLE.search(s)]
    return " ".join(keep) or desc


ASK = """Landmark: {name} ({city}). Category: {attrs}. Notes: {overview}
Reply with JSON only: {{"desc": "<1-2 sentences: the real subject's shape, materials, colours and surroundings as a painter must draw it to be recognisable; max 45 words>",
"view": "<e.g. A gentle elevated three-quarter view showing the whole building | An eye-level view across the plaza | A close three-quarter tabletop view>",
"avoid": "<optional: one short 'No ...' sentence against a likely wrong depiction, e.g. No mountains or domes. Empty string if none>"}}
Describe only physical things. Never mention people, visitors, crowds, silhouettes or figures, not even for scale."""


def ask(row):
    body = json.dumps({"model": "claude-haiku-5-5", "max_tokens": 2000, "output_config": {"effort": "low"},
                       "messages": [{"role": "user", "content": ASK.format(name=row["name"], city=row["city"],
                                     attrs=", ".join(row["attributes"] or []), overview=row["overview"][:400])}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
        "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=60))
            txt = "".join(b.get("text", "") for b in r["content"] if b["type"] == "text")
            d = json.loads(txt[txt.index("{"): txt.rindex("}") + 1])
            food = any(a in ("Food", "Fast Food", "Restaurant", "Cafe") for a in row["attributes"] or [])
            avoid = clean(d.get("avoid", "")).strip()
            prompt = (FOOD if food else STYLE).format(name=row["name"], city=row["city"],
                                                      desc=clean(d["desc"]).rstrip(".") + ".",
                                                      view=clean(d["view"]).rstrip("."), avoid=(avoid + " ") if avoid else "")
            return row["file"], {**row, "prompt": prompt}
        except Exception as e:  # retry, then leave it for the next run
            err = e
    print("failed", row["name"], err)
    return row["file"], None


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    rows = json.loads((HERE / "targets.json").read_text(encoding="utf-8"))
    done = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    todo = [r for r in rows if r["file"] not in done]
    with ThreadPoolExecutor(8) as pool:
        for i, (f, v) in enumerate(pool.map(ask, todo), 1):
            if v:
                done[f] = v
            if i % 20 == 0:  # save as we go so the Leonardo run can start on the first prompts
                OUT.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
    OUT.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"prompts: {len(done)}/{len(rows)}")
