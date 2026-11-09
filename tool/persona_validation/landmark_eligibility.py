"""Shared public eligibility policy: excluded places must never enter scoring."""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / 'assets/traveler_type/landmark_eligibility.json'
POLICY = json.loads(PATH.read_text(encoding='utf8'))


def key(name):
    return ' '.join(name.casefold().split())


def eligible(place):
    name = key(place['name'])
    tags = set(place.get('attributes', []))
    if name in {key(n) for n in POLICY['excluded_catalog_names']}:
        return False
    if tags & set(POLICY['excluded_attributes']):
        return False
    return all(tag not in tags or name in {key(n) for n in POLICY[list_key]}
               for tag, list_key in [('Lake', 'lake_allowlist'), ('Island', 'island_allowlist')])


def refresh_catalog_exclusions(rows):
    """Refresh derived exclusions without letting the old derived list affect decisions."""
    previous = POLICY['excluded_catalog_names']
    POLICY['excluded_catalog_names'] = []
    try:
        names = sorted({r['name'] for r in rows if not eligible(r)})
    finally:
        POLICY['excluded_catalog_names'] = previous
    POLICY['excluded_catalog_names'] = names
    PATH.write_text(json.dumps(POLICY, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
