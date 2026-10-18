"""Shared lossless codec for bundled statistics (no value corrections)."""
SCHEMA_VERSION = 1
DIMENSION_KEYS = frozenset({
    'iso_a3', 'iso_a2', 'country_iso', 'country_code', 'country', 'country_name',
    'city', 'name', 'iata_code', 'icao_code', 'airline', 'airport',
})
DATASETS = '''area_data climate_data geography_data latitude_data
updated_country_populations fertility_rate homicide_rate life_expectancy
immigration_rate hdi_data obesity_rate power_index military_expenditure
armed_forces nukes aircraft_carries navy_ships aircrafts tanks iq height novel
democracy olympics health bald technology average_age religion_population
casualties economy_data economics_trivia gold gini_data millionaire starbucks
immigrants student average_price hollywood traffic surveillance pollution
city_homicide_rate safety liveability skyscraper largest oldest stations
financial_index city_tourist_ratio summer_olympics_cities winter_olympics_cities
nhl_cities nba_cities mlb_cities nfl_cities mls_cities gawc top_airports
top_airlines gov sports cold_war cities city_stats country_popularity transportation'''.split()


def metadata():
    # Unknown is explicitly null; migration date is not the observation date.
    return {'source_url': None, 'reference_period': None, 'updated_at': None}


def encode_statistics(dataset_id, original):
    if isinstance(original, dict) and original.get('schema_version') == 1:
        return original
    layout = 'list' if isinstance(original, list) else 'sections'
    groups = {'main': original} if layout == 'list' else original
    if not isinstance(groups, dict):
        raise ValueError(f'{dataset_id}: expected list or section map')
    tables = []
    for table_id, rows in groups.items():
        if not isinstance(rows, list) or any(not isinstance(r, dict) for r in rows):
            raise ValueError(f'{dataset_id}/{table_id}: expected object records')
        dimensions = list(dict.fromkeys(k for row in rows for k in row if k in DIMENSION_KEYS))
        metrics = list(dict.fromkeys(k for row in rows for k in row if k not in DIMENSION_KEYS))
        tables.append({
            'id': table_id,
            'metadata': metadata(),
            'dimensions': dimensions,
            'metrics': [{'id': k, 'unit': None, **metadata()} for k in metrics],
            'records': [{'dimensions': {k: v for k, v in row.items() if k in DIMENSION_KEYS},
                         'values': {k: v for k, v in row.items() if k not in DIMENSION_KEYS}}
                        for row in rows],
        })
    return {'schema_version': SCHEMA_VERSION, 'dataset_id': dataset_id,
            'metadata': metadata(), 'legacy_layout': layout, 'tables': tables}


def decode_statistics(data):
    if not isinstance(data, dict) or 'schema_version' not in data:
        return data
    if data['schema_version'] != SCHEMA_VERSION:
        raise ValueError('Unsupported statistics schema')
    tables = {t['id']: [{**r['dimensions'], **r['values']} for r in t['records']]
              for t in data['tables']}
    if data['legacy_layout'] == 'list':
        if list(tables) != ['main']:
            raise ValueError('List layout requires one main table')
        return tables['main']
    if data['legacy_layout'] != 'sections':
        raise ValueError('Unsupported statistics layout')
    return tables


def validate_statistics(data):
    """Validate the same contract as the Dart model; do not coerce types."""
    def identifier(value):
        if not isinstance(value, str) or not value.strip():
            raise ValueError('Expected nonempty statistics identifier')
        return value

    def check_metadata(value):
        if not isinstance(value, dict):
            raise ValueError('Expected metadata object')
        for key in metadata():
            if key not in value or (value[key] is not None and not isinstance(value[key], str)):
                raise ValueError(f'Invalid metadata: {key}')

    if type(data.get('schema_version')) is not int or data['schema_version'] != SCHEMA_VERSION:
        raise ValueError('Unsupported statistics schema')
    identifier(data['dataset_id'])
    check_metadata(data['metadata'])
    if not isinstance(data['tables'], list):
        raise ValueError('Expected tables array')
    table_ids = set()
    for table in data['tables']:
        table_id = identifier(table['id'])
        if table_id in table_ids:
            raise ValueError('Duplicate table id')
        table_ids.add(table_id)
        check_metadata(table['metadata'])
        for key in ['dimensions', 'metrics', 'records']:
            if not isinstance(table[key], list):
                raise ValueError(f'Expected {key} array')
        dimensions = [identifier(d) for d in table['dimensions']]
        metric_ids = []
        for metric in table['metrics']:
            metric_ids.append(identifier(metric['id']))
            check_metadata(metric)
            if 'unit' not in metric or (metric['unit'] is not None and not isinstance(metric['unit'], str)):
                raise ValueError('Invalid metric unit')
        if len(set(dimensions)) != len(dimensions) or len(set(metric_ids)) != len(metric_ids) or set(dimensions) & set(metric_ids):
            raise ValueError('Duplicate dimensions or metrics')
        for row in table['records']:
            for key, declared in [('dimensions', dimensions), ('values', metric_ids)]:
                if not isinstance(row[key], dict) or set(row[key]) - set(declared):
                    raise ValueError('Undeclared statistics field')
    decode_statistics(data)  # Also validates the compatibility layout.
