'use strict';

function decode(value) {
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch (_) { return null; }
}
function object(value) {
  const result = decode(value);
  return result && typeof result === 'object' && !Array.isArray(result) ? result : {};
}
function strings(value) {
  const result = decode(value);
  return Array.isArray(result) ? [...new Set(result.filter(v => typeof v === 'string' && v.trim()))].sort() : [];
}
function countries(value, aliases) {
  return [...new Set(Object.entries(object(value))
    .filter(([, v]) => v && v.isVisited === true)
    .map(([name]) => aliases[name.toLowerCase().trim()]).filter(Boolean))].sort();
}
function cities(value) {
  return Object.entries(object(value)).filter(([, raw]) => {
    const v = object(raw);
    return v.isWishlisted !== true && ((v.visitCount || 0) > 0 ||
      (Array.isArray(v.visitDateRanges) && v.visitDateRanges.length > 0) ||
      v.hasLived === true || v.isHome === true || v.isVisited === true);
  }).map(([name]) => name).sort();
}
function closest(visited, rows, self) {
  const mine = new Set(visited);
  let best = null;
  let compared = 0;
  for (const row of rows) {
    if (row.uid === self || row.countries.length === 0) continue;
    compared++;
    const shared = row.countries.filter(c => mine.has(c)).length;
    if (!shared) continue;
    const similarity = shared / (mine.size + row.countries.length - shared);
    if (!best || similarity > best.similarity ||
        (similarity === best.similarity && shared > best.shared) ||
        (similarity === best.similarity && shared === best.shared && row.uid < best.row.uid)) {
      best = {row, similarity, shared};
    }
  }
  return {best, compared};
}
function anonymousResult(raw, badge, privacy, aliases, badgePoints) {
  const ids = strings(badge?.badgeIds);
  return {
    countries: countries(raw.country_visits_v2, aliases),
    cities: privacy?.cities === false ? null : cities(raw.city_visit_details_v3),
    landmarks: strings(raw.visited_landmarks),
    unesco: strings(raw.unesco_visited_sites),
    badgeCount: badge ? ids.length : null,
    badgeScore: badge ? ids.reduce((sum, id) => sum + (badgePoints[id] || 0), 0) : null,
  };
}
function travel(raw, aliases, privacy) {
  return {countries: countries(raw.country_visits_v2, aliases),
    cities: privacy?.cities === false ? null : cities(raw.city_visit_details_v3),
    landmarks: strings(raw.visited_landmarks), unesco: strings(raw.unesco_visited_sites)};
}
function closestTravel(mine, rows, self) {
  let best = null, compared = 0;
  for (const row of rows) {
    if (row.uid === self) continue;
    let score = 0, weight = 0, shared = 0;
    for (const [key, w] of [['countries', 4], ['cities', 3], ['landmarks', 2], ['unesco', 1]]) {
      if (!Array.isArray(mine[key]) || !Array.isArray(row[key])) continue;
      const a = new Set(mine[key]), b = new Set(row[key]);
      const overlap = [...a].filter(v => b.has(v)).length;
      const union = a.size + b.size - overlap;
      if (!union) continue;
      score += w * overlap / union; weight += w; shared += overlap;
    }
    if (!weight) continue;
    compared++;
    const similarity = score / weight;
    if (!shared) continue;
    if (!best || similarity > best.similarity || (similarity === best.similarity &&
      (shared > best.shared || (shared === best.shared && row.uid < best.row.uid)))) {
      best = {row, similarity, shared};
    }
  }
  return {best, compared};
}
module.exports = {countries, cities, closest, anonymousResult, travel, closestTravel};

function travelerType(raw, profile) {
  if (profile?.privacy?.dna === false) return null;
  const analysis = object(raw?.ai_analysis_result);
  const scores = analysis.summary?.persona_scores;
  if (Array.isArray(scores) && scores.length) {
    const top = [...scores].filter(s => typeof s.label === 'string' && Number.isFinite(s.score)).sort((a,b) => b.score-a.score)[0];
    if (top) return top.label.slice(0,80);
  }
  return typeof profile?.travelerType === 'string' ? profile.travelerType.slice(0,80) : null;
}
module.exports.travelerType = travelerType;
