"""Local-only reduction of users export; never calls an AI or network service.

Usage: python tool/persona_validation/extract_users.py <export.json>
Outputs contain sensitive travel histories despite removing direct identifiers.
"""
import argparse
import collections
import datetime as dt
import json
import math
from pathlib import Path
import random
import time

DNA = ('solo_social', 'nature_culture', 'relaxed_intensive',
       'planned_spontaneous', 'budget_luxury', 'transit_drive',
       'documenter_minimalist', 'morning_night')
FLIGHT_KEYS = ('airlineCode', 'departureIata', 'arrivalIata', 'duration',
               'rating', 'seatClass', 'isCanceled', 'times')


def numeric(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def select(obj, keys):
    return {k: obj[k] for k in keys if k in obj and
            (obj[k] is None or isinstance(obj[k], (str, bool, int, float)))}


def duration_days(a, b):
    try:
        days = (dt.datetime.fromisoformat(b.replace('Z', '+00:00')) -
                dt.datetime.fromisoformat(a.replace('Z', '+00:00'))).total_seconds() / 86400
        return round(days, 2) if days >= 0 else None
    except (ValueError, TypeError, AttributeError):
        return None


def visits(source, city=False):
    result = {}
    if not isinstance(source, dict):
        return result
    for name, value in source.items():
        if not isinstance(value, dict):
            continue
        ranges = value.get('visitDateRanges', [])
        ranges = ranges if isinstance(ranges, list) else []
        if not city and not value.get('isVisited') and not value.get('hasLived'):
            continue
        # Keep city entries, including unknown-date visits; explicitly flag wishlist-only.
        entry = select(value, ('isVisited', 'hasLived', 'isHome', 'isWishlisted',
                               'rating', 'visitCount'))
        entry['recorded_visits'] = len(ranges)
        entry['memo_chars'] = len(value.get('memo') or '')
        entry['photo_count'] = len(value.get('photos') or [])
        stays = []
        for visit in ranges:
            if not isinstance(visit, dict):
                continue
            stay = select(visit, ('isLayover', 'isTransfer', 'isDurationUnknown',
                                 'userDefinedDuration'))
            days = duration_days(visit.get('arrival'), visit.get('departure'))
            if days is not None:
                stay['days'] = days
            entry['memo_chars'] += len(visit.get('memo') or '')
            entry['photo_count'] += len(visit.get('photos') or [])
            stays.append(stay)
        if stays:
            entry['stays'] = stays
        if city:
            days = duration_days(value.get('arrivalDate'), value.get('departureDate'))
            if days is not None:
                entry['legacy_stay_days'] = days
        result[name] = entry
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--out', type=Path, default=Path(__file__).parent / 'out')
    args = parser.parse_args()
    started = time.monotonic()
    with args.source.open(encoding='utf-8-sig') as f:
        root = json.load(f)
    users = root['users']
    if not isinstance(users, dict):
        raise ValueError('Expected root.users to be a map')
    args.out.mkdir(parents=True, exist_ok=True)
    errors = collections.Counter()
    fields = collections.Counter()
    rows, summaries = [], []

    def decode(user, key, fallback):
        value = user.get(key, fallback)
        if isinstance(value, str):
            try:
                return json.loads(value)
            except (ValueError, TypeError):
                errors[key] += 1
                return fallback
        return value

    for index, user in enumerate(users.values(), 1):
        if not isinstance(user, dict):
            errors['non_object_user'] += 1
            continue
        fields.update(user.keys())
        # Sequence ID deliberately has no exported UID or identity mapping.
        row = {'person_id': f'p{index:05d}'}
        scores = decode(user, 'dna_final_scores', {})
        row['dna_scores'] = {k: v for k, v in scores.items()
                             if k in DNA and numeric(v) and 0 <= v <= 100} if isinstance(scores, dict) else {}
        responses = decode(user, 'dna_responses', {})
        row['dna_responses'] = {k: v for k, v in responses.items()
                                if str(k).isdigit() and numeric(v) and int(v) == v and 1 <= v <= 7} if isinstance(responses, dict) else {}
        row['dna_complete'] = user.get('dna_is_calculated') is True and len(row['dna_scores']) == 8
        row['countries'] = visits(decode(user, 'country_visits_v2', {}))
        row['cities'] = visits(decode(user, 'city_visit_details_v3', {}), city=True)
        row.update(select(user, ('homeCountryIsoA3', 'homeCityName')))
        flights = []
        airlines = decode(user, 'saved_airlines_data', [])
        if isinstance(airlines, list):
            for airline in airlines:
                if not isinstance(airline, dict):
                    continue
                logs = airline.get('logs', [])
                if not isinstance(logs, list):
                    continue
                for log in logs:
                    if isinstance(log, dict):
                        flight = select(log, FLIGHT_KEYS)
                        # AirlineProvider overrides stale/null per-log airline codes.
                        flight['airlineCode'] = airline.get('code')
                        flights.append(flight)
        row['flights'] = flights
        history = decode(user, 'airport_visit_history', {})
        row['airport_visit_counts'] = {k: len(v) for k, v in history.items() if isinstance(v, list)} if isinstance(history, dict) else {}
        row['transfer_airport_count'] = sum(
            any(isinstance(e, dict) and any(e.get(flag) is True for flag in
                ('isTransfer', 'isLayover', 'isStopover')) for e in entries)
            for entries in history.values() if isinstance(entries, list)
        ) if isinstance(history, dict) else 0
        row['airport_ratings'] = {k: v for k, v in (decode(user, 'airport_ratings', {}) or {}).items() if numeric(v)}
        # Landmark IDs, ratings and visit frequencies only; no free text/dates.
        for prefix, visited_key in [('landmark', 'visited_landmarks'), ('unesco', 'unesco_visited_sites')]:
            ids = user.get(visited_key, [])
            row[prefix + '_visited'] = [v for v in ids if isinstance(v, (str, int))] if isinstance(ids, list) else []
            ratings = decode(user, prefix + '_ratings', {})
            row[prefix + '_ratings'] = {k: v for k, v in ratings.items() if numeric(v)} if isinstance(ratings, dict) else {}
        connections = decode(user, 'saved_flight_connections', [])
        row['connections'] = []
        transfer_ids = set()
        if isinstance(connections, list):
            for connection in connections:
                if isinstance(connection, dict):
                    transfer_ids.update(connection.get('flightLogIds', []))
                    legs = connection.get('connections', [])
                    row['connections'].extend(select(v, ('duration', 'type')) for v in legs if isinstance(v, dict))
        # Preserve membership as an aggregate only, never write account-specific log IDs.
        row['transfer_flight_count'] = sum(
            log.get('id') in transfer_ids and not log.get('isCanceled', False)
            for airline in airlines if isinstance(airline, dict)
            for log in airline.get('logs', []) if isinstance(log, dict)
        ) if isinstance(airlines, list) else 0
        n_country = sum(v.get('isVisited') is True and not v.get('hasLived', False) for v in row['countries'].values())
        n_city = sum(not v.get('hasLived', False) and not v.get('isHome', False) and not v.get('isWishlisted', False) for v in row['cities'].values())
        n_flight = sum(not v.get('isCanceled', False) for v in flights)
        bucket = 'no_travel' if n_country + n_city + n_flight == 0 else 'light' if n_country < 5 and n_city < 10 else 'medium' if n_country < 20 and n_city < 50 else 'heavy'
        summary = {'person_id': row['person_id'], 'dna_complete': row['dna_complete'],
                   'dna_response_count': len(row['dna_responses']), 'countries': n_country,
                   'city_records_proxy': n_city, 'flights': n_flight,
                   'landmarks': len(row['landmark_visited']), 'unesco': len(row['unesco_visited']),
                   'rated_countries': sum(numeric(v.get('rating')) and v['rating'] > 0 for v in row['countries'].values()),
                   'rated_cities': sum(numeric(v.get('rating')) and v['rating'] > 0 for v in row['cities'].values()),
                   'activity_group': bucket}
        summaries.append(summary)
        rows.append(row)

    def write_lines(name, values):
        path = args.out / name
        with path.open('w', encoding='utf-8') as f:
            for value in values:
                f.write(json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False) + '\n')
        return path.stat().st_size

    sizes = {'users_reduced.jsonl': write_lines('users_reduced.jsonl', rows),
             'users_summary.jsonl': write_lines('users_summary.jsonl', summaries)}
    # Round-robin across observed activity/DNA groups, deterministic sampling.
    groups = collections.defaultdict(list)
    by_id = {r['person_id']: r for r in rows}
    for s in summaries:
        if s['countries'] + s['city_records_proxy'] + s['flights'] > 0 or s['dna_complete']:
            groups[(s['dna_complete'], s['activity_group'])].append(s['person_id'])
    rng = random.Random(20261016)
    for values in groups.values():
        rng.shuffle(values)
    sample = []
    while len(sample) < 30 and any(groups.values()):
        for key in sorted(groups):
            if groups[key] and len(sample) < 30:
                sample.append(by_id[groups[key].pop()])
    sizes['sample_30.jsonl'] = write_lines('sample_30.jsonl', sample)
    report = {
        'source_bytes': args.source.stat().st_size, 'users': len(rows),
        'dna_field_present': fields['dna_final_scores'],
        'dna_complete_users': sum(s['dna_complete'] for s in summaries),
        'users_with_country_visits': sum(s['countries'] > 0 for s in summaries),
        'users_with_city_records_proxy': sum(s['city_records_proxy'] > 0 for s in summaries),
        'users_with_flights': sum(s['flights'] > 0 for s in summaries),
        'users_with_dna_and_travel': sum(s['dna_complete'] and s['countries'] + s['city_records_proxy'] + s['flights'] > 0 for s in summaries),
        'activity_groups': dict(collections.Counter(s['activity_group'] for s in summaries)),
        'decode_errors_by_field': dict(errors), 'output_bytes': sizes,
        'sample_users': len(sample), 'elapsed_seconds': round(time.monotonic() - started, 2),
        'notes': [
            'Local extraction only; no API calls or model tokens.',
            'Direct account identifiers, names, emails, photos, free text and exact dates removed. Travel histories remain sensitive.',
            'city_records_proxy is a screening heuristic, not the app city visit predicate; home-country visits remain in counts.',
            'No trip_logs subcollection in this export. No independent self-labelled traveler types.',
            'Reduced export is for validation preparation, not a lossless app database backup.',
            'AI cached results excluded to prevent previous predictions being used as ground truth.',
        ],
    }
    (args.out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == '__main__':
    main()
