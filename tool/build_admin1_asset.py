"""Build worldwide region asset; see tool/admin1_data.md for regeneration."""
import argparse, collections, hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
LEGACY = set('AE AR AT AU BR CA CH CN DE EG ES FR GB GR ID IN IT JP KR MX MY NL PH PT RU TH TR US VN ZA'.split())
EXCLUDED = {'Indian Ocean Ter.', 'Siachen Glacier', 'Antarctica', 'N. Cyprus', 'Northern Cyprus', 'Ashmore and Cartier Is.'}
SUPPLEMENTS = {'KI': 'KIR', 'TV': 'TUV', 'NU': 'NIU'}
def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))
def write(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
def identity_hash(features):
    rows = sorted((f['properties']['iso_a2'],f['properties']['name'],f['properties'].get('iso_3166_2') or '') for f in features if f['properties'].get('name'))
    return hashlib.sha256(json.dumps(rows,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
def validate_geometry(g):
    assert g['type'] in {'Polygon','MultiPolygon'}
    polygons = [g['coordinates']] if g['type']=='Polygon' else g['coordinates']
    assert polygons
    for polygon in polygons:
        assert polygon
        for ring in polygon:
            assert len(ring)>=4 and ring[0]==ring[-1], 'Invalid ring'
            for x,y,*_ in ring:
                assert -180<=x<=180 and -90<=y<=90

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'build/admin1/world_simplified.geojson')
    parser.add_argument('--existing',type=Path,default=ROOT/'assets/admin1_regions.geojson')
    parser.add_argument('--supplements',type=Path,default=ROOT/'build/admin1')
    args=parser.parse_args()
    legacy=[f for f in read(args.existing)['features'] if f['properties']['iso_a2'] in LEGACY]
    assert {f['properties']['iso_a2'] for f in legacy}==LEGACY
    countries={f['properties']['iso_a2']:f for f in read(ROOT/'assets/custom.geo.json')['features'] if f['properties']['name'] not in EXCLUDED}
    grouped=collections.defaultdict(list)
    for f in read(args.source)['features']:
        p=f['properties']; iso=p['iso_a2']
        if p.get('admin')=='Somaliland': iso='XX'
        if iso not in countries or iso in LEGACY or not p.get('name'): continue
        p['iso_a2']=iso; p['type_en']=p.get('type_en') or 'Region'
        grouped[iso].append(f)
    catalog={m['boundaryISO']:m for m in read(args.supplements/'geoboundaries_adm1_catalog.json')}
    sources={}
    for iso,a3 in SUPPLEMENTS.items():
        m=catalog[a3]; regions=[]
        for f in read(args.supplements/f'gb_{a3}.geojson')['features']:
            p=f['properties']
            regions.append({'type':'Feature','properties':{'admin':countries[iso]['properties']['admin'],'iso_a2':iso,'name':p['shapeName'],'iso_3166_2':p.get('shapeISO') or '', 'type_en':'Village' if iso=='NU' else 'Island group' if iso=='KI' else 'Island council','adm1_code':p['shapeID'],'source':'geoBoundaries'},'geometry':f['geometry']})
        grouped[iso]=regions
        sources[iso]={k:m[k] for k in ['boundaryID','boundaryYearRepresented','boundarySource','boundaryLicense','licenseSource','simplifiedGeometryGeoJSON']}
    output=list(legacy); report={}; collisions=0
    for iso,country in sorted(countries.items()):
        if iso in LEGACY:
            regions=[f for f in legacy if f['properties']['iso_a2']==iso and f['properties'].get('name')]
            report[iso]={'name':country['properties']['name'],'status':'subdivisions','count':len(regions),'source':'Natural Earth (preserved)'}
            continue
        regions=grouped[iso]
        # Single source polygons may be whole countries or incomplete groupings.
        # Use the app's entire country outline and explicitly mark no subdivisions.
        whole=len(regions)<=1
        if whole:
            regions=[{'type':'Feature','properties':{'admin':country['properties']['admin'],'iso_a2':iso,'name':country['properties']['name'],'iso_3166_2':'','type_en':'Whole area','whole_area':True},'geometry':country['geometry']}]
        keys=collections.Counter(f['properties'].get('iso_3166_2') or iso+'::'+f['properties']['name'] for f in regions)
        seen=set()
        for f in regions:
            p=f['properties']; key=p.get('iso_3166_2') or iso+'::'+p['name']
            if keys[key]>1:
                p['storage_key']=iso+'::NE::'+p['adm1_code']; collisions+=1
            key=p.get('storage_key') or key
            assert key not in seen,(iso,key)
            seen.add(key); p.pop('adm1_code',None)
            validate_geometry(f['geometry'])
        output.extend(regions)
        report[iso]={'name':country['properties']['name'],'status':'whole_area' if whole else 'subdivisions','count':0 if whole else len(regions),'source':'geoBoundaries' if iso in SUPPLEMENTS else 'Natural Earth'}
    for f in legacy: validate_geometry(f['geometry'])
    assert identity_hash(legacy)==identity_hash([f for f in output if f['properties']['iso_a2'] in LEGACY])
    asset=ROOT/'assets/admin1_regions.geojson'
    write(asset,{'type':'FeatureCollection','features':output})
    manifest={'natural_earth_url':'https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_admin_1_states_provinces.geojson','source_sha256':hashlib.sha256(args.source.read_bytes()).hexdigest(),'natural_earth_raw_sha256':hashlib.sha256((args.source.parent/'natural_earth_admin1.geojson').read_bytes()).hexdigest() if (args.source.parent/'natural_earth_admin1.geojson').exists() else None,'mapshaper_version':'0.7.86','simplification':'8% keep-shapes; precision=0.0001; original 30 countries preserved','legacy_identity_sha256':identity_hash(legacy),'legacy_feature_count':len(legacy),'legacy_countries':sorted(LEGACY),'country_count':len(report),'subdivision_country_count':sum(r['status']=='subdivisions' for r in report.values()),'subdivision_count':sum(r['count'] for r in report.values()),'new_collision_features_resolved':collisions,'supplement_sources':sources,'countries':report}
    write(ROOT/'assets/admin1_coverage.json',manifest)
    print(json.dumps({k:manifest[k] for k in ['country_count','subdivision_country_count','subdivision_count','new_collision_features_resolved']}))
    print(f'Asset: {asset.stat().st_size:,} bytes')
    print('Whole-area only:',', '.join(iso for iso,r in report.items() if r['status']=='whole_area'))
if __name__=='__main__': main()
