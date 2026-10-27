"""Build offline app-derived vectors without AI, preserving missingness.

The 13 AI city/landmark axes are deliberately omitted. This evaluates the
deterministic fallback path, NOT the full online pipeline or type accuracy.
"""
import collections
import json
import math
from pathlib import Path
import re
import statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / 'out'
DNA = ('solo_social', 'nature_culture', 'relaxed_intensive',
       'planned_spontaneous', 'budget_luxury', 'transit_drive',
       'documenter_minimalist', 'morning_night')


def entropy(counts):
    counts = list(counts)
    if not counts:
        return -1.0
    total = sum(counts)
    if not total:
        return 0.0
    if len(counts) <= 1:
        return -1.0
    h = -sum(c / total * math.log2(c / total) for c in counts if c > 0)
    return h / math.log2(len(counts)) * 2 - 1


def parse_minutes(value):
    total = 0
    for part in (value or '').split(' '):
        try:
            if 'h' in part:
                total += int(part.replace('h', '')) * 60
            elif 'm' in part:
                total += int(part.replace('m', ''))
        except ValueError:
            pass
    return total


def flight_time(hours):
    if hours <= 1: return -1.0
    if hours <= 1.5: return -0.8
    if hours <= 2: return -0.6
    if hours <= 2.5: return -0.4 + (hours - 2) / .5 * .4
    if hours <= 3: return (hours - 2.5) / .5 * .2
    for boundary, value in [(4,.2),(6,.4),(8,.6),(10,.8)]:
        if hours <= boundary: return value
    return 1.0


def transfer_score(ratio, airport=False):
    cuts = [0,5,10,15,18,22,25,30,40,50] if airport else [0,5,10,20,25,28,30,35,45,55]
    return next((-1 + i * .2 for i, boundary in enumerate(cuts) if ratio <= boundary), 1.0)


def main():
    src = (ROOT / 'lib/services/travel_persona_engine.dart').read_text(encoding='utf8')
    protos = json.loads(re.search(r"_archetypePrototypesJson = r'''(.*?)'''", src, re.S)[1])
    (OUT / 'prototypes.json').write_text(json.dumps(protos), encoding='utf8')
    maps_src = (ROOT / 'lib/services/travel_quantifier.dart').read_text(encoding='utf8')
    traits = {}
    for axis, name in [('countryWealth','Wealth'),('countryType','Type'),('countryNightlife','Nightlife')]:
        body = re.search(r'_country' + name + r'Scores = \{(.*?)\};', maps_src, re.S)[1]
        traits[axis] = {k: float(v) for k,v in re.findall(r'"([A-Z]+)":\s*(-?[\d.]+)', body)}
    countries = {}
    light = json.loads((ROOT / 'assets/countries_light.json').read_text(encoding='utf8'))
    for c in light:
        countries[c['name']] = {'iso': c['iso_a3'], 'continent': 'Unknown'}
    geo = json.loads((ROOT / 'assets/custom.geo.json').read_text(encoding='utf8'))
    for feature in geo['features']:
        p = feature['properties']
        iso = p.get('adm0_a3')
        for name in [p.get('name'), p.get('admin'), p.get('name_long')]:
            if name:
                countries[name] = {'iso': iso, 'continent': p.get('continent', 'Unknown')}
        for c in countries.values():
            if c['iso'] == iso:
                c['continent'] = p.get('continent', 'Unknown')
    questions = json.loads((ROOT / 'assets/personality_questions.json').read_text(encoding='utf8'))
    max_raw = {k: sum(3 * abs(q['weights'].get(k, 0)) for q in questions) for k in DNA}
    stats = collections.Counter()
    missing_country_names = collections.Counter()
    unique_axes = collections.defaultdict(list)
    output = (OUT / 'vectors.jsonl').open('w', encoding='utf8')
    for line in (OUT / 'users_reduced.jsonl').open(encoding='utf8'):
        r = json.loads(line)
        # Match CityProvider.isVisited (nonempty ranges), excluding home/lived.
        valid_cities = {k:v for k,v in r['cities'].items() if v['recorded_visits'] > 0
                        and k != r.get('homeCityName') and not v.get('hasLived', False)}
        valid_countries = {k:v for k,v in r['countries'].items() if v.get('isVisited')
                           and not v.get('hasLived') and
                           countries.get(k, {}).get('iso') != r.get('homeCountryIsoA3', '__unset__')}
        for k in valid_countries:
            if k not in countries: missing_country_names[k] += 1
        flights = [f for f in r['flights'] if not f.get('isCanceled', False)]
        airports = r['airport_visit_counts']
        stored_dna = {k:(r['dna_scores'][k] - 50) / 50 for k in DNA if k in r['dna_scores']} if r['dna_complete'] else {}
        dna = stored_dna if r['dna_responses'] else {}
        if r['dna_complete']: stats['dna_complete'] += 1
        if stored_dna and not r['dna_responses']: stats['complete_flag_but_no_responses'] += 1
        responses = r['dna_responses']
        recomputed = {k: 50 + 50 * sum((responses.get(str(q['id']), 4) - 4) * q['weights'].get(k, 0)
                                      for q in questions) / max_raw[k] for k in DNA}
        mismatch = max((abs(recomputed[k] - r['dna_scores'][k]) for k in DNA if k in r['dna_scores']), default=0)
        if dna and mismatch > .01: stats['stored_dna_differs_from_current_questions'] += 1
        if dna and len(responses) < len(questions): stats['complete_flag_but_partial_responses'] += 1
        if stored_dna and not any(abs(x) > 1e-9 for x in stored_dna.values()): stats['neutral_dna'] += 1
        all_ratings = [v.get('rating',0) for v in [*valid_countries.values(),*valid_cities.values()] if v.get('rating',0) > 0]
        mean = statistics.mean(all_ratings) if all_ratings else 0
        sd = statistics.pstdev(all_ratings) if all_ratings else 1
        sd = sd or 1
        def weight(v):
            rating = v.get('rating', 0)
            if rating <= 0: return 1
            z = (rating - mean) / sd
            return 2 if z >= 2 else 1.5 if z >= 1 else -2 if z <= -2 else 0 if z <= -1 else 1
        continent = collections.Counter(countries.get(k, {}).get('continent','Unknown') for k in valid_countries)
        travel = {
            'continentDistribution': entropy(continent.values()),
            'countryDistribution': entropy(v.get('visitCount',0) for v in valid_countries.values()),
            'cityDistribution': entropy([1] * len(valid_cities)),
            'airportDistribution': entropy(airports.values()),
            'airlineDistribution': entropy(collections.Counter(f.get('airlineCode') or 'Unknown' for f in flights).values()),
        }
        observed = {}
        if valid_countries:
            observed.update({k:v for k,v in travel.items() if k in ('continentDistribution','countryDistribution')})
        if valid_cities:
            # Revised quantifier uses actual repeat visits rather than all ones.
            observed['cityDistribution'] = entropy(v['recorded_visits'] for v in valid_cities.values())
        if airports: observed['airportDistribution'] = travel['airportDistribution']
        if flights: observed['airlineDistribution'] = travel['airlineDistribution']
        for axis, mapping in traits.items():
            known = [(mapping[countries[k]['iso']],weight(v)) for k,v in valid_countries.items()
                     if k in countries and countries[k]['iso'] in mapping]
            # Existing quantifier treats unknown trait scores as 0 (reported separately).
            denom = sum(abs(weight(v)) for k,v in valid_countries.items() if k in countries)
            val = max(-1,min(1,sum(s*w for s,w in known) / denom)) if denom else 0.0
            travel[axis] = val
            if known and sum(abs(w) for _,w in known) > 0: observed[axis] = val
            if any(w < 0 for _,w in known): stats['negative_rating_weight_' + axis] += 1
        timed = [(parse_minutes(f.get('duration')),f.get('times',1)) for f in flights if parse_minutes(f.get('duration')) > 0]
        n = sum(times for _,times in timed)
        travel['airlineTime'] = flight_time(sum(m*t for m,t in timed) / n / 60) if n > 0 else 0.0
        travel['transferAirportScore'] = transfer_score(r['transfer_airport_count'] / len(airports) * 100, True) if airports else 0.0
        travel['transferFlightScore'] = transfer_score(r['transfer_flight_count'] / len(flights) * 100) if flights else 0.0
        if n > 0: observed['airlineTime'] = travel['airlineTime']
        if airports: observed['transferAirportScore'] = travel['transferAirportScore']
        if flights: observed['transferFlightScore'] = travel['transferFlightScore']
        legacy = {k:stored_dna.get(k,0.0) for k in DNA}
        legacy.update(travel)
        combined = {**dna, **observed}
        for k,v in combined.items(): unique_axes[k].append(v)
        if not combined: stats['no_observed_axes'] += 1
        if dna and observed: stats['dna_and_observed_travel'] += 1
        stats['users'] += 1
        output.write(json.dumps({'person_id':r['person_id'], 'dna':dna,'travel':observed,
                                 'combined':combined,'legacy':legacy,
                                 'counts': {'countries':len(valid_countries),'cities':len(valid_cities), 'flights':len(flights)},
                                 'dna_mismatch':mismatch},separators=(',',':')) + '\n')
    output.close()
    profile = {'counts':dict(stats),'question_count':len(questions),
               'country_lookup_unmatched_records':sum(missing_country_names.values()),
               'axis_stats':{k:{'n':len(v),'mean':statistics.mean(v),'sd':statistics.pstdev(v),
                                'unique_rounded':len(set(round(x,6) for x in v))} for k,v in unique_axes.items()},
               'limitations':['13 AI axes omitted; this is the deterministic fallback audit.',
                              'Country mapping uses bundled light/GeoJSON assets; runtime alias/territory normalization may differ.',
                              'Stored scores compared with current bundled questions; export is older than current app.',
                              'No ground-truth traveler labels. Agreement/stability are not accuracy.']}
    (OUT / 'data_profile.json').write_text(json.dumps(profile,indent=2),encoding='utf8')
    print(json.dumps(profile,indent=2))


if __name__ == '__main__':
    main()
