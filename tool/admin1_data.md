# Worldwide region boundary data

The app retains the original 30-country geometry, names, and ISO visit keys.
`assets/admin1_regions.geojson` is a collection of country datasets: 213 countries/territories with 4,563 named subdivisions, plus 25 explicit whole-area outlines. Outlines do not support region visits or progress counts. These are source coverage figures, not a guarantee of current legal administrative divisions. Natural Earth includes different administrative levels in different countries. Existing 30-country data (including duplicate source codes) is deliberately preserved.

`assets/admin1_coverage.json` lists coverage per country, supplement provenance, and the original name/code checksum. `assets/admin1_sources.txt` contains licenses and attribution with compact attribution on the region world maps. No account visit data is rewritten. New countries with duplicate ISO codes use the Natural Earth feature ID as their storage key. Somaliland matches the app's existing `XX` code.

## Sources and licenses

- Natural Earth Admin-1: public domain, https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/
- Natural Earth GeoJSON: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson
- Country outlines: existing `assets/custom.geo.json` (Natural Earth).
- geoBoundaries, William & Mary geoLab and contributors: https://www.geoboundaries.org/ ; Runfola et al. (2020), https://doi.org/10.1371/journal.pone.0231866
- Kiribati/Tuvalu: OpenStreetMap contributors and Wambacher via geoBoundaries, represented in 2017, ODbL 1.0. These country datasets and their adaptations retain ODbL 1.0. They may be extracted from the combined asset by `properties.iso_a2` (KI/TV).
- Niue: Pacific Data Hub via geoBoundaries, represented in 2020, CC BY 4.0. https://pacificdata.org/data/dataset/2011_niu_phc_admin_boundaries
- Country supplement download links and detailed licenses are in `admin1_coverage.json`.

The combined file is a collection: each underlying dataset retains the above license. App code is separate. Original source files and reproducible transformation instructions are provided here and in the manifest.

## Regenerate

From the project root in PowerShell, download the Natural Earth GeoJSON to `build/admin1/natural_earth_admin1.geojson`. Download https://www.geoboundaries.org/api/current/gbOpen/ALL/ADM1/ to `build/admin1/geoboundaries_adm1_catalog.json`. For KIR, TUV, NIU, download that country's `simplifiedGeometryGeoJSON` URL from the catalog to `build/admin1/gb_KIR.geojson`, `gb_TUV.geojson`, `gb_NIU.geojson`. For exact supplement versions, use the pinned links in the committed coverage manifest (geoBoundaries commit 9469f09).

```powershell
npm.cmd install --prefix build/admin1 mapshaper@0.7.86 --ignore-scripts --no-audit --no-fund
node build/admin1/node_modules/mapshaper/bin/mapshaper build/admin1/natural_earth_admin1.geojson -simplify 8% keep-shapes -filter-fields admin,iso_a2,name,iso_3166_2,type_en,adm1_code -o format=geojson precision=0.0001 build/admin1/world_simplified.geojson
python -X utf8 tool/build_admin1_asset.py
flutter test test/admin_region_repository_test.dart
```

The builder keeps the original 30 countries from the existing asset, normalizes optional source fields, resolves new ISO-code collisions, validates polygon rings/coordinates, and writes the asset/manifest. An explicit `--existing` path can select a backup. All download/tool intermediate files stay under ignored `build/admin1/`. No extra runtime package is required.

## Known coverage gaps

Whole-area outlines: AW, BL, CW, EH, FK, FO, GG, GI, GS, GU, HM, IM, IO, JE, KY, MC, MF, MO, NF, PN, PR, SX, VA, VG, XX. Some have real subdivisions, but reliable compatible boundaries have not been supplied by the chosen datasets. For each future supplement, obtain an openly licensed boundary dataset, record source/version/license, map ISO codes, remove its whole-area placeholder, and update the coverage manifest. Do not invent subdivisions from country polygons.

CountryProvider hides Antarctica, Northern Cyprus, Siachen Glacier and two Australian offshore entries, so those do not become separate region screens. Mainland camera overrides cover existing US/FR/RU/etc. and new NZ/FJ/KI dateline-spanning maps; outlying areas remain reachable on the full map and in the list.
