"""Country-level overrides on top of the Natural Earth admin-1 data.

Decided in reports/region_plan_2026-11-24.md:
  * Malta: 68 local councils -> 6 NSO statistical districts (mt_districts.json)
  * Crimea (UA-43) and Sevastopol (UA-40): Ukraine, not Russia

`apply(features, existing)` is idempotent and is called by
tool/build_admin1_asset.py. Run this file directly to apply the overrides to
the committed asset and to regenerate assets/admin1_key_migration.json:

    python -X utf8 tool/admin1_overrides/apply.py
"""
import json
from pathlib import Path

from shapely import set_precision
from shapely.geometry import mapping, shape
from shapely.ops import unary_union

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CRIMEA = {'UA-43', 'UA-40'}
MIGRATION_VERSION = 1


def _mt_config():
    return json.loads((HERE / 'mt_districts.json').read_text(encoding='utf-8'))


def _geometry(geom):
    geom = set_precision(geom, 0.0001)
    g = mapping(geom)
    out = {'type': g['type'], 'coordinates': json.loads(json.dumps(g['coordinates']))}
    if out['type'] == 'GeometryCollection':
        raise ValueError('dissolve produced a GeometryCollection')
    return out


def _malta(features):
    councils = [f for f in features if f['properties'].get('iso_a2') == 'MT']
    if not councils or all(f['properties'].get('storage_key', '').startswith('MT::') for f in councils):
        return features  # already applied
    cfg = _mt_config()
    mapping_ = cfg['councils']
    codes = {f['properties'].get('iso_3166_2') for f in councils}
    assert codes == set(mapping_), sorted(codes ^ set(mapping_))
    groups = {}
    for f in councils:
        groups.setdefault(mapping_[f['properties']['iso_3166_2']], []).append(shape(f['geometry']))
    admin = councils[0]['properties'].get('admin', 'Malta')
    districts = []
    for key, name in cfg['districts'].items():
        geom = unary_union(groups[key])
        districts.append({'type': 'Feature', 'properties': {
            'admin': admin, 'iso_a2': 'MT', 'name': name, 'iso_3166_2': '',
            'type_en': 'District', 'storage_key': key}, 'geometry': _geometry(geom)})
    # Gozo and Comino must lie on Gozo/Comino (north-west of Malta island).
    gozo = shape(next(d for d in districts if d['properties']['name'] == 'Gozo and Comino')['geometry'])
    assert gozo.bounds[1] > 35.98 and gozo.bounds[2] < 14.36, gozo.bounds
    rest = [f for f in features if f['properties'].get('iso_a2') != 'MT']
    return rest + districts


def _crimea(features, existing):
    have = [f for f in features if f['properties'].get('iso_3166_2') in CRIMEA]
    if len(have) < len(CRIMEA) and existing:
        # The builder only keeps Russia from the existing asset; Crimea now
        # lives under Ukraine there, so carry it over from the existing asset.
        keys = {f['properties']['iso_3166_2'] for f in have}
        have += [f for f in existing if f['properties'].get('iso_3166_2') in CRIMEA - keys]
        features = features + [f for f in have if f not in features]
    assert len([f for f in features if f['properties'].get('iso_3166_2') in CRIMEA]) == len(CRIMEA)
    for f in features:
        p = f['properties']
        if p.get('iso_3166_2') in CRIMEA:
            p['iso_a2'] = 'UA'
            p['admin'] = 'Ukraine'
    return features


def apply(features, existing=None):
    features = _malta(features)
    features = _crimea(features, existing)
    return features


def key_migration():
    """Old saved region keys -> new keys, per country (visited_subregions is
    keyed by ISO A3). Names are included for the legacy name-keyed data."""
    mt = dict(_mt_config()['councils'])
    return {
        'version': MIGRATION_VERSION,
        'moves': [
            {'from': 'MLT', 'to': 'MLT', 'keys': mt},
            {'from': 'RUS', 'to': 'UKR', 'keys': {
                'UA-43': 'UA-43', 'UA-40': 'UA-40', 'Crimea': 'UA-43', 'Sevastopol': 'UA-40'}},
        ],
    }


def _mt_name_keys(features):
    """Unique Malta council names -> district key (duplicate names skipped)."""
    cfg = _mt_config()
    names = {}
    for f in features:
        p = f['properties']
        if p.get('iso_a2') == 'MT' and p.get('iso_3166_2') in cfg['councils']:
            names.setdefault(p['name'], set()).add(cfg['councils'][p['iso_3166_2']])
    return {n: next(iter(v)) for n, v in names.items() if len(v) == 1}


def update_coverage(coverage, features):
    counts = {}
    for f in features:
        p = f['properties']
        if p.get('name') and not p.get('whole_area'):
            counts[p['iso_a2']] = counts.get(p['iso_a2'], 0) + 1
    for iso in ('MT', 'RU', 'UA'):
        coverage['countries'][iso]['count'] = counts[iso]
    coverage['countries']['MT']['source'] = 'Natural Earth, dissolved to NSO statistical districts'
    coverage['subdivision_count'] = sum(r['count'] for r in coverage['countries'].values())
    coverage['overrides'] = 'tool/admin1_overrides (Malta districts; Crimea/Sevastopol under Ukraine)'
    return coverage


def main():
    asset = ROOT / 'assets/admin1_regions.geojson'
    data = json.loads(asset.read_text(encoding='utf-8'))
    before = data['features']
    name_keys = _mt_name_keys(before)
    data['features'] = apply(before)
    asset.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')

    cov_path = ROOT / 'assets/admin1_coverage.json'
    cov = json.loads(cov_path.read_text(encoding='utf-8'))
    cov_path.write_text(json.dumps(update_coverage(cov, data['features']), ensure_ascii=False,
                                   separators=(',', ':')) + '\n', encoding='utf-8')

    mig = key_migration()
    if name_keys:
        mig['moves'][0]['keys'].update(name_keys)
    else:
        old = json.loads((ROOT / 'assets/admin1_key_migration.json').read_text(encoding='utf-8'))
        mig['moves'][0]['keys'] = old['moves'][0]['keys']
    (ROOT / 'assets/admin1_key_migration.json').write_text(
        json.dumps(mig, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    by = {}
    for f in data['features']:
        if not f['properties'].get('whole_area') and f['properties'].get('name'):
            by[f['properties']['iso_a2']] = by.get(f['properties']['iso_a2'], 0) + 1
    print('MT', by['MT'], 'RU', by['RU'], 'UA', by['UA'], 'total', sum(by.values()))


if __name__ == '__main__':
    main()
