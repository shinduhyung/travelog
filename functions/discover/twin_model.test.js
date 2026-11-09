const {test} = require('node:test');
const assert = require('node:assert/strict');
const {countries, cities, closest, anonymousResult} = require('./twin_model');

test('country overlap has no rating gate, excludes self and duplicate countries', () => {
  const result = closest(['FR'], [
    {uid: 'self', countries: ['FR']},
    {uid: 'one', countries: ['FR', 'JP']},
    {uid: 'two', countries: ['FR']},
  ], 'self');
  assert.equal(result.best.row.uid, 'two');
  assert.equal(result.best.similarity, 1);
  assert.equal(result.compared, 2);
  assert.equal(closest(['FR'], [{uid: 'other', countries: ['JP']}], 'self').best, null);
  assert.equal(closest(['FR', 'FR'], [{uid: 'other', countries: ['FR']}], 'self').best.similarity, 1);
});

test('legacy JSON, wishlist exclusion, unique badges and strict response fields', () => {
  const aliases = {france: 'FR', japan: 'JP'};
  const raw = {email: 'private', displayName: 'private', uid: 'private',
    country_visits_v2: JSON.stringify({France: {isVisited: true}, Japan: {isVisited: false}}),
    city_visit_details_v3: {Paris: {visitDateRanges: [{}]}, Kyoto: {isWishlisted: true},
      Empty: {visitDateRanges: []}},
    visited_landmarks: ['Tower', 'Tower'], unesco_visited_sites: '[]'};
  assert.deepEqual(countries(raw.country_visits_v2, aliases), ['FR']);
  assert.deepEqual(cities(raw.city_visit_details_v3), ['Paris']);
  const result = anonymousResult(raw, {badgeIds: ['a', 'a', 'b']}, {}, aliases, {a: 10, b: 25});
  assert.equal(result.badgeScore, 35);
  assert.deepEqual(Object.keys(result).sort(), ['countries', 'cities', 'landmarks', 'unesco', 'badgeCount', 'badgeScore'].sort());
  assert.equal(JSON.stringify(result).includes('private'), false);
  assert.equal(anonymousResult(raw, null, {cities: false}, aliases, {}).cities, null);
  assert.equal(anonymousResult(raw, null, {}, aliases, {}).badgeScore, null);
});

test('Jaccard penalizes unmatched countries and ties do not depend on input order', () => {
  const pool = [{uid: 'a', countries: ['FR', 'JP']}, {uid: 'b', countries: ['FR', 'US', 'CA']}];
  assert.equal(closest(['FR', 'JP'], pool, 'self').best.row.uid, 'a');
  assert.equal(closest(['FR', 'JP'], pool.reverse(), 'self').best.row.uid, 'a');
});
