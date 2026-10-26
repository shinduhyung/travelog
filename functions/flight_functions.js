// functions/flight_functions.js
//
// Flight price proxy backed by Air Scrapper (formerly Sky-scrapper) on RapidAPI.
// Uses searchFlights v2 (v1 is marked "Deprecated - DON'T USE" on RapidAPI) and
// getPriceCalendar for the "how cheap is this date" insight (getFlightInsight).
// Wire it into functions/index.js like this:
//
//   const flightFunctions = require('./flight_functions');
//   exports.getFlightPrice = flightFunctions.getFlightPrice;
//   exports.getFlightBookingLink = flightFunctions.getFlightBookingLink;
//
// TODO (verify against RapidAPI dashboard "Test Endpoint" before shipping):
//  [confirmed] RAPIDAPI_HOST = "sky-scrapper.p.rapidapi.com"
//  [confirmed] searchAirport response shape = data[i].navigation.relevantFlightParams.{skyId, entityId}
//              (data[0] can be a CITY entry, so we match the AIRPORT entry whose skyId equals the IATA code)
//  1. Exact location of itineraries[].id and sessionId in the searchFlights response — not yet confirmed
//     (the code below assumes a common schema — if the real response differs, only this file needs updating)
//  2. Exact path of the deepLink field in the getFlightDetails response — not yet confirmed
//  3. Exact param name/values for the stops filter — currently not sent to the API, filtered client-side instead
//
// One-time Firebase secret setup:
//   firebase functions:secrets:set RAPIDAPI_KEY
//
// ── DEBUG BUILD ──────────────────────────────────────────────────────────
// Every step below logs to Firebase Functions logs (console.log/console.error
// show up in `firebase functions:log` and the Firebase console). Axios errors
// are unwrapped so the actual RapidAPI HTTP status + response body is visible
// instead of a generic "internal" error — that's almost always where a
// silent "price unavailable" traces back to (wrong host, not-subscribed key,
// wrong param names, etc).
// ─────────────────────────────────────────────────────────────────────────

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const axios = require('axios');

// admin.initializeApp() is already called in index.js — calling it again here
// would throw a duplicate-app-initialization error.
const db = admin.firestore();

const RAPIDAPI_KEY = defineSecret('RAPIDAPI_KEY');
const RAPIDAPI_HOST = 'sky-scrapper.p.rapidapi.com'; // confirmed

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const EMPTY_CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes for "no flights found"

function rapidHeaders() {
  const key = RAPIDAPI_KEY.value();
  // Never log the full key — just enough to confirm the secret actually
  // resolved to something non-empty at runtime.
  console.log(`[flight] RAPIDAPI_KEY resolved: ${key ? `present, length=${key.length}, starts="${key.slice(0, 4)}..."` : 'MISSING/EMPTY'}`);
  console.log(`[flight] RAPIDAPI_HOST = "${RAPIDAPI_HOST}"`);
  return {
    'X-RapidAPI-Key': key,
    'X-RapidAPI-Host': RAPIDAPI_HOST,
  };
}

// This free/basic-tier RapidAPI mirror has shown two kinds of transient
// failure during testing: HTTP 429 (rate limited) and a 200 OK with
// {"status": false, "message": "Something went wrong..."} (their backend's
// own generic error). Both are worth a short retry instead of failing
// immediately — real outages will still fail after maxRetries.
async function fetchWithRetry(url, params, headers, label, {maxRetries = 3, baseDelayMs = 800} = {}) {
  let lastErr;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const resp = await axios.get(url, {params, headers});
      if (resp.data?.status === false) {
        const msg = resp.data?.message ?? 'unknown error';
        console.warn(`[flight] ${label} — attempt ${attempt}/${maxRetries}: API returned status:false — "${msg}"`);
        if (attempt < maxRetries) {
          const delay = baseDelayMs * attempt;
          console.log(`[flight] ${label} — retrying in ${delay}ms...`);
          await new Promise((r) => setTimeout(r, delay));
          continue;
        }
        throw new Error(`RapidAPI returned status:false after ${maxRetries} attempts — "${msg}"`);
      }
      if (attempt > 1) console.log(`[flight] ${label} — succeeded on retry attempt ${attempt}`);
      return resp;
    } catch (err) {
      const httpStatus = err.response?.status;
      const retryable = httpStatus === 429 || (httpStatus >= 500 && httpStatus < 600) || !err.response;
      lastErr = err;
      if (retryable && attempt < maxRetries) {
        const delay = baseDelayMs * attempt * (httpStatus === 429 ? 2 : 1);
        console.warn(`[flight] ${label} — attempt ${attempt}/${maxRetries} failed (HTTP ${httpStatus ?? 'network/no-response'}), retrying in ${delay}ms...`);
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      throw err;
    }
  }
  throw lastErr;
}

// Logs the real HTTP status + response body from a failed axios call — this
// is the single most useful piece of information for diagnosing RapidAPI
// failures (403 = not subscribed to this exact API/host, 404 = wrong path,
// 429 = rate limited, etc). Without this, a failed axios call just looks
// like an opaque "internal" error to the Flutter client.
function logAxiosError(label, err) {
  if (err.response) {
    console.error(`[flight] ${label} FAILED — RapidAPI responded with status ${err.response.status}`);
    console.error(`[flight] ${label} response headers:`, JSON.stringify(err.response.headers));
    console.error(`[flight] ${label} response body:`, JSON.stringify(err.response.data)?.slice(0, 2000));
    console.error(`[flight] ${label} request URL:`, err.config?.url);
    console.error(`[flight] ${label} request params:`, JSON.stringify(err.config?.params));
  } else if (err.request) {
    console.error(`[flight] ${label} FAILED — no response received (network/timeout). ` +
      `Request URL: ${err.config?.url}, params: ${JSON.stringify(err.config?.params)}`);
    console.error(`[flight] ${label} error message:`, err.message);
  } else {
    console.error(`[flight] ${label} FAILED before the request was even sent:`, err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Trip.com-specific price extraction.
//
// The searchFlights response aggregates fares from many OTAs (not just
// Trip.com), so "cheapest across all of them" — what the code used before —
// naturally won't match what Trip.com itself quotes. Most Skyscanner-family
// APIs attach a per-agent breakdown to each itinerary
// (itinerary.pricingOptions[], each with either an embedded agent object or
// an agentIds[] that references a top-level agents lookup). This searches
// that breakdown for an agent named "Trip.com" and prefers its price.
//
// Schema is NOT confirmed for this specific API mirror — the logging around
// every call site here shows exactly what shape actually comes back, so if
// this never matches, the logs will show why (no pricingOptions at all? no
// agents dictionary? Trip.com just not present as a source in this market?).
// ─────────────────────────────────────────────────────────────────────────
function buildAgentsLookup(respData) {
  const raw = respData?.agents ?? respData?.data?.agents ?? null;
  if (!raw) return null;
  if (Array.isArray(raw)) {
    const map = {};
    raw.forEach((a) => {
      if (a?.id != null) map[a.id] = a;
    });
    return map;
  }
  return raw; // already an id -> agent object map
}

function extractAgentName(agentRef, agentsLookup) {
  if (agentRef == null) return null;
  if (typeof agentRef === 'string' || typeof agentRef === 'number') {
    const found = agentsLookup?.[agentRef];
    return found?.name ?? (typeof found === 'string' ? found : null);
  }
  if (typeof agentRef === 'object') {
    return agentRef.name ?? null;
  }
  return null;
}

function findTripComOption(itineraries, agentsLookup) {
  const TRIP_COM_RE = /trip\.?com/i;
  let best = null; // {priceRaw, priceFormatted, itinerary, agentName}

  for (const it of itineraries) {
    const options = it.pricingOptions ?? [];
    for (const opt of options) {
      // Agent info shows up a few different ways depending on the API mirror:
      // opt.agentIds = ['123'] (needs agentsLookup), or opt.agents = [{name:...}] embedded directly.
      const agentRefs = opt.agentIds ?? opt.agents ?? [];
      const refs = Array.isArray(agentRefs) ? agentRefs : [agentRefs];
      for (const ref of refs) {
        const name = extractAgentName(ref, agentsLookup);
        if (name && TRIP_COM_RE.test(name)) {
          const priceRaw = opt.price?.amount ?? opt.price?.raw ?? opt.totalPrice ?? null;
          if (priceRaw != null && (!best || priceRaw < best.priceRaw)) {
            best = {
              priceRaw,
              priceFormatted: opt.price?.formatted ?? null,
              itinerary: it,
              agentName: name,
            };
          }
        }
      }
    }
  }
  return best;
}

// ─────────────────────────────────────────────────────────────────────────
// searchFlights (v2) runs the search asynchronously: the first response can
// come back with data.context.status = "incomplete" and only part of the
// itineraries. Per the API docs, poll GET /api/v2/flights/searchIncomplete
// with data.context.sessionId until status = "complete". Each poll returns
// the cumulative list, not a delta.
// Observed 2026-10-20: searchIncomplete v2 answers {status:false, "Something went
// wrong"} every time, while searchFlights v2 already returns most itineraries
// (8 of 10 for ICN->AUH). So a failed poll keeps what we have instead of
// counting as "complete", and an empty first search is retried.
// ─────────────────────────────────────────────────────────────────────────
const SEARCH_URL = `https://${RAPIDAPI_HOST}/api/v2/flights/searchFlights`;
const INCOMPLETE_URL = `https://${RAPIDAPI_HOST}/api/v2/flights/searchIncomplete`;
const CALENDAR_URL = `https://${RAPIDAPI_HOST}/api/v1/flights/getPriceCalendar`;

async function pollUntilComplete(initialResp, headers, originalParams, maxAttempts = 6, delayMs = 1200) {
  let status = initialResp.data?.data?.context?.status ?? null;
  let itineraries = initialResp.data?.data?.itineraries ?? [];
  const sessionId = initialResp.data?.data?.context?.sessionId ?? null;
  console.log(`[flight] pollUntilComplete — initial status="${status}", itineraries=${itineraries.length}`);

  if (status !== 'incomplete') return itineraries;
  if (!sessionId) {
    console.warn('[flight] pollUntilComplete — "incomplete" but no data.context.sessionId; using the partial result set.');
    return itineraries;
  }

  // keep currency/market/country identical to the original search
  const pollParams = {
    sessionId,
    currency: originalParams.currency,
    market: originalParams.market,
    countryCode: originalParams.countryCode,
  };
  for (let attempt = 1; status === 'incomplete' && attempt <= maxAttempts; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    let resp;
    try {
      resp = await axios.get(INCOMPLETE_URL, {params: pollParams, headers});
    } catch (err) {
      logAxiosError(`searchIncomplete attempt ${attempt}`, err);
      break;
    }
    if (resp.data?.status === false || !resp.data?.data?.context) {
      console.warn(`[flight] pollUntilComplete — attempt ${attempt}: API error "${resp.data?.message ?? 'no data'}"; keeping ${itineraries.length} itineraries.`);
      break;
    }
    status = resp.data.data.context.status ?? 'complete';
    const polled = resp.data.data.itineraries ?? [];
    if (polled.length > 0) itineraries = polled;
    console.log(`[flight] pollUntilComplete — attempt ${attempt}: status="${status}", itineraries=${itineraries.length}`);
  }
  if (status === 'incomplete') {
    console.warn(`[flight] pollUntilComplete — still incomplete; using the ${itineraries.length} itineraries collected so far.`);
  }
  return itineraries;
}

// ─────────────────────────────────────────────────────────────────────────
// IATA -> Skyscanner's internal skyId/entityId mapping (airport codes never
// change, so this is cached permanently).
// ─────────────────────────────────────────────────────────────────────────
async function getAirportSkyId(iata) {
  console.log(`[flight] getAirportSkyId("${iata}") — checking Firestore cache...`);
  const ref = db.collection('airport_sky_ids').doc(iata);
  const snap = await ref.get();
  if (snap.exists) {
    console.log(`[flight] getAirportSkyId("${iata}") — CACHE HIT:`, JSON.stringify(snap.data()));
    return snap.data();
  }
  console.log(`[flight] getAirportSkyId("${iata}") — cache miss, calling searchAirport...`);

  const url = `https://${RAPIDAPI_HOST}/api/v1/flights/searchAirport`;
  const params = {query: iata, locale: 'en-US'};
  console.log(`[flight] getAirportSkyId("${iata}") — GET ${url}`, JSON.stringify(params));

  let resp;
  try {
    resp = await fetchWithRetry(url, params, rapidHeaders(), `searchAirport("${iata}")`);
  } catch (err) {
    logAxiosError(`searchAirport("${iata}")`, err);
    throw new HttpsError('internal',
      `searchAirport request failed for "${iata}": ` +
      (err.response ? `RapidAPI returned HTTP ${err.response.status}` : err.message));
  }

  console.log(`[flight] getAirportSkyId("${iata}") — searchAirport HTTP ${resp.status}, ` +
    `response keys: ${Object.keys(resp.data || {}).join(', ')}`);

  // Response is an array, and the first entry can be a CITY rather than an
  // airport, so find the AIRPORT entry whose skyId matches the IATA code
  // (confirmed shape: data[i].navigation.relevantFlightParams).
  const list = resp.data?.data ?? [];
  console.log(`[flight] getAirportSkyId("${iata}") — ${list.length} entries returned. ` +
    `Full response (truncated): ${JSON.stringify(resp.data)?.slice(0, 1500)}`);

  const match =
    list.find((item) => item.navigation?.relevantFlightParams?.skyId?.toUpperCase() === iata.toUpperCase()) ??
    list.find((item) => item.navigation?.relevantFlightParams?.flightPlaceType === 'AIRPORT');

  if (!match) {
    console.error(`[flight] getAirportSkyId("${iata}") — NO MATCHING ENTRY. ` +
      `Entry types seen: ${list.map((i) => i.navigation?.relevantFlightParams?.flightPlaceType).join(', ')}`);
    throw new HttpsError('not-found', `Could not resolve a skyId for airport code ${iata}.`);
  }

  const result = {
    skyId: match.navigation.relevantFlightParams.skyId,
    entityId: match.navigation.relevantFlightParams.entityId,
  };
  console.log(`[flight] getAirportSkyId("${iata}") — MATCHED:`, JSON.stringify(result));

  await ref.set(result);
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// Price lookup (24h Firestore cache)
// ─────────────────────────────────────────────────────────────────────────
exports.getFlightPrice = onCall({secrets: [RAPIDAPI_KEY], timeoutSeconds: 120}, async (request) => {
  const {originIata, destinationIata, date, stops} = request.data || {};
  // Optional (newer clients): round trip, cabin and party size. Older app builds omit them.
  const returnDate = request.data?.returnDate || null;
  const cabinClass = ['economy', 'premium_economy', 'business', 'first'].includes(request.data?.cabinClass)
    ? request.data.cabinClass : 'economy';
  const adults = Math.min(9, Math.max(1, parseInt(request.data?.adults, 10) || 1));
  console.log(`[flight] getFlightPrice called with originIata=${originIata}, ` +
    `destinationIata=${destinationIata}, date=${date}, stops=${stops}`);

  if (!originIata || !destinationIata || !date) {
    console.error('[flight] getFlightPrice — missing required argument(s)');
    throw new HttpsError('invalid-argument', 'originIata, destinationIata, and date are required.');
  }

  const cacheKey = `${originIata}_${destinationIata}_${date}_${stops ?? 'any'}` +
    (returnDate || cabinClass !== 'economy' || adults !== 1 ? `_${returnDate ?? 'ow'}_${cabinClass}_${adults}` : '');
  const cacheRef = db.collection('flight_price_cache').doc(cacheKey);

  const cachedSnap = await cacheRef.get();
  if (cachedSnap.exists) {
    const cached = cachedSnap.data();
    const ageMs = Date.now() - cached.updatedAt;
    console.log(`[flight] getFlightPrice — cache entry found for "${cacheKey}", age=${Math.round(ageMs / 1000)}s`);
    // "nothing found" is often a transient API miss, so it only sticks for 15 minutes
    if (ageMs < (cached.found === false ? EMPTY_CACHE_TTL_MS : CACHE_TTL_MS)) {
      console.log(`[flight] getFlightPrice — returning CACHED result:`, JSON.stringify(cached));
      return cached;
    }
    console.log('[flight] getFlightPrice — cache expired, refetching');
  } else {
    console.log(`[flight] getFlightPrice — no cache entry for "${cacheKey}"`);
  }

  let origin, destination;
  try {
    [origin, destination] = await Promise.all([
      getAirportSkyId(originIata),
      getAirportSkyId(destinationIata),
    ]);
  } catch (err) {
    console.error('[flight] getFlightPrice — airport skyId resolution failed:', err.message);
    throw err; // already an HttpsError from getAirportSkyId, re-throw as-is
  }

  const url = SEARCH_URL;
  const params = {
    originSkyId: origin.skyId,
    destinationSkyId: destination.skyId,
    originEntityId: origin.entityId,
    destinationEntityId: destination.entityId,
    date,
    ...(returnDate ? {returnDate} : {}),
    cabinClass,
    adults,
    currency: 'KRW', // TODO: make this dynamic (request param) if needed
    market: 'en-US',
    countryCode: 'KR',
    // TODO: add the stops filter param once its exact name is confirmed
    // (currently filtered client-side below instead)
  };
  console.log(`[flight] getFlightPrice — GET ${url}`, JSON.stringify(params));

  let resp;
  try {
    resp = await fetchWithRetry(url, params, rapidHeaders(), 'searchFlights');
  } catch (err) {
    logAxiosError('searchFlights', err);
    throw new HttpsError('internal',
      `searchFlights request failed: ` +
      (err.response ? `RapidAPI returned HTTP ${err.response.status} — ${JSON.stringify(err.response.data)?.slice(0, 300)}` : err.message));
  }

  console.log(`[flight] getFlightPrice — searchFlights HTTP ${resp.status}, ` +
    `top-level response keys: ${Object.keys(resp.data || {}).join(', ')}`);
  console.log(`[flight] getFlightPrice — resp.data.data keys (siblings of itineraries — ` +
    `look for pagination/context/status hints here): ${Object.keys(resp.data?.data || {}).join(', ')}`);
  if (resp.data?.data?.context) {
    console.log(`[flight] getFlightPrice — resp.data.data.context: ${JSON.stringify(resp.data.data.context)}`);
  }

  // Poll for the complete result set if the initial response is "incomplete"
  // (see pollUntilComplete's comment above for why this matters).
  let itineraries = await pollUntilComplete(resp, rapidHeaders(), params);
  // The first call sometimes comes back empty while the search warms up; ask again.
  for (let retry = 1; itineraries.length === 0 && retry <= 2; retry++) {
    await new Promise((r) => setTimeout(r, 2000));
    try {
      resp = await fetchWithRetry(url, params, rapidHeaders(), `searchFlights retry ${retry}`);
      itineraries = resp.data?.data?.itineraries ?? [];
      console.log(`[flight] getFlightPrice — searchFlights retry ${retry}: ${itineraries.length} itineraries`);
    } catch (err) {
      logAxiosError(`searchFlights retry ${retry}`, err);
      break;
    }
  }
  console.log(`[flight] getFlightPrice — ${itineraries.length} itineraries returned before stop filtering. ` +
    (itineraries.length === 0
      ? `Full response (truncated): ${JSON.stringify(resp.data)?.slice(0, 1500)}`
      : ''));

  // Dump EVERY itinerary's price + stop count + times so we can see whether
  // the truly cheapest/direct option is even present in this result set, or
  // whether the API is only handing back a partial/relevance-sorted subset
  // (common with Skyscanner-style "live" search APIs that need a follow-up
  // poll to get the complete, price-sorted result set).
  itineraries.forEach((it, idx) => {
    const leg = it.legs?.[0];
    console.log(`[flight] getFlightPrice — itinerary[${idx}] id=${it.id} price.raw=${it.price?.raw} ` +
      `(${it.price?.formatted}) stopCount=${leg?.stopCount} duration=${leg?.durationInMinutes}min ` +
      `depart=${leg?.departure} arrive=${leg?.arrival} carrier=${leg?.carriers?.marketing?.[0]?.name}`);
  });

  if (stops === 'direct') {
    const before = itineraries.length;
    itineraries = itineraries.filter((it) => (it.legs?.[0]?.stopCount ?? 99) === 0);
    console.log(`[flight] getFlightPrice — filtered to direct-only: ${before} -> ${itineraries.length}`);
  }

  if (itineraries.length === 0) {
    console.warn(`[flight] getFlightPrice — NO ITINERARIES FOUND for ${cacheKey}. ` +
      `This means the API call succeeded (HTTP ${resp.status}) but returned zero usable results — ` +
      `check the "Full response" logged above for clues (empty data.itineraries, different field name, ` +
      `error message embedded in a 200 response, etc).`);
    const empty = {found: false, updatedAt: Date.now()};
    await cacheRef.set(empty);
    return empty;
  }

  // ── Try to find a Trip.com-specific price among this itinerary's pricing
  // options, instead of just "cheapest across every agent" (which is what
  // was causing the mismatch — the RapidAPI feed aggregates many OTAs, not
  // just Trip.com, so its "cheapest" often isn't what Trip.com itself quotes).
  //
  // Schema is unconfirmed for this API mirror, so this logs everything it
  // sees along the way. If pricingOptions/agents aren't present at all, or
  // no agent is ever named "Trip.com", the log output below will make that
  // obvious and we fall back to the old cheapest-across-all-agents behavior.
  const agentsLookup = buildAgentsLookup(resp.data);
  console.log(`[flight] getFlightPrice — agentsLookup: ${agentsLookup ? `${Object.keys(agentsLookup).length} agents found` : 'NONE (no top-level agents dictionary in response)'}`);
  if (agentsLookup) {
    console.log(`[flight] getFlightPrice — agent names seen: ${Object.values(agentsLookup).map((a) => a?.name).filter(Boolean).join(', ')}`);
  }
  console.log(`[flight] getFlightPrice — itineraries[0].pricingOptions (truncated): ${JSON.stringify(itineraries[0]?.pricingOptions)?.slice(0, 1000)}`);

  const tripComMatch = findTripComOption(itineraries, agentsLookup);

  let chosen; // {priceRaw, priceFormatted, itinerary, source}
  if (tripComMatch) {
    console.log(`[flight] getFlightPrice — FOUND Trip.com pricing option: ` +
      `agentName="${tripComMatch.agentName}", priceRaw=${tripComMatch.priceRaw}`);
    chosen = {
      priceRaw: tripComMatch.priceRaw,
      priceFormatted: tripComMatch.priceFormatted,
      itinerary: tripComMatch.itinerary,
      source: 'trip.com',
    };
  } else {
    // The response order isn't guaranteed to be price-sorted, so compute the
    // cheapest itinerary explicitly.
    const cheapest = itineraries.reduce((min, it) =>
      (it.price?.raw ?? Infinity) < (min.price?.raw ?? Infinity) ? it : min
    );
    console.log(`[flight] getFlightPrice — no Trip.com pricing option found anywhere in ` +
      `${itineraries.length} itineraries. Falling back to cheapest-across-all-agents: ` +
      `raw=${cheapest.price?.raw}, id=${cheapest.id}`);
    chosen = {
      priceRaw: cheapest.price?.raw ?? null,
      priceFormatted: cheapest.price?.formatted ?? null,
      itinerary: cheapest,
      source: 'lowest-available',
    };
  }

  const leg = chosen.itinerary.legs?.[0];
  console.log(`[flight] getFlightPrice — chosen result source="${chosen.source}", ` +
    `priceRaw=${chosen.priceRaw}, id=${chosen.itinerary.id}, sessionId in top-level response=${resp.data?.sessionId}`);

  const result = {
    found: true,
    priceRaw: chosen.priceRaw,
    priceFormatted: chosen.priceFormatted,
    priceSource: chosen.source, // 'trip.com' | 'lowest-available' — client can label accordingly
    stopCount: leg?.stopCount ?? null,
    durationInMinutes: leg?.durationInMinutes ?? null,
    carrier: leg?.carriers?.marketing?.[0]?.name ?? null,
    itineraryId: chosen.itinerary.id ?? null,        // TODO: confirm actual field name
    sessionId: resp.data?.sessionId ?? null, // TODO: confirm actual location
    updatedAt: Date.now(),
  };
  console.log('[flight] getFlightPrice — RESULT:', JSON.stringify(result));

  await cacheRef.set(result);
  return result;
});

// ─────────────────────────────────────────────────────────────────────────
// Fare insight from getPriceCalendar: the approximate one-way fare for a date
// and how cheap it is. The calendar lists the cheapest fare per day for months
// ahead, each tagged by Skyscanner as "low" / "medium" / "high" for that route,
// so one call per route per day (cached) serves every date a user picks.
// Exact prices still come from the booking site.
// ─────────────────────────────────────────────────────────────────────────
const IATA_RE = /^[A-Z]{3}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

async function getRouteCalendar(originIata, destinationIata) {
  const today = new Date().toISOString().slice(0, 10);
  const cacheRef = db.collection('flight_calendar_cache').doc(`${originIata}_${destinationIata}`);
  const snap = await cacheRef.get();
  if (snap.exists && snap.data().fetchedOn === today && Date.now() - snap.data().updatedAt < CACHE_TTL_MS) {
    return snap.data();
  }
  const [origin, destination] = await Promise.all([getAirportSkyId(originIata), getAirportSkyId(destinationIata)]);
  const params = {originSkyId: origin.skyId, destinationSkyId: destination.skyId, fromDate: today, currency: 'USD'};
  let resp;
  try {
    resp = await fetchWithRetry(CALENDAR_URL, params, rapidHeaders(), 'getPriceCalendar');
  } catch (err) {
    logAxiosError('getPriceCalendar', err);
    throw new HttpsError('internal', 'getPriceCalendar request failed: ' +
      (err.response ? `RapidAPI returned HTTP ${err.response.status}` : err.message));
  }
  // documented shape: data.flights.days[] = {day: 'YYYY-MM-DD', group: 'low'|'medium'|'high', price}
  const days = (resp.data?.data?.flights?.days ?? [])
    .filter((d) => d?.day && Number(d.price) > 0)
    .map((d) => ({d: d.day, p: Math.round(Number(d.price) * 100) / 100, g: d.group ?? null}));
  console.log(`[flight] getRouteCalendar ${originIata}->${destinationIata}: ${days.length} priced days`);
  const doc = {days, currency: 'USD', fetchedOn: today, updatedAt: Date.now()};
  await cacheRef.set(doc);
  return doc;
}

exports.getFlightInsight = onCall({secrets: [RAPIDAPI_KEY], timeoutSeconds: 60}, async (request) => {
  const originIata = String(request.data?.originIata || '').toUpperCase();
  const destinationIata = String(request.data?.destinationIata || '').toUpperCase();
  const date = String(request.data?.date || '');
  if (!IATA_RE.test(originIata) || !IATA_RE.test(destinationIata) || !DATE_RE.test(date) || originIata === destinationIata) {
    throw new HttpsError('invalid-argument', 'originIata, destinationIata (3-letter codes) and date (YYYY-MM-DD) are required.');
  }

  const cal = await getRouteCalendar(originIata, destinationIata);
  const days = cal.days;
  const chosen = days.find((d) => d.d === date);
  const base = {originIata, destinationIata, date, currency: cal.currency, source: 'skyscanner-calendar', updatedAt: cal.updatedAt};
  if (!chosen) return {...base, found: false};

  const t = Date.parse(date);
  const within = (n) => days.filter((d) => Math.abs(Date.parse(d.d) - t) <= n * 864e5);
  const month = within(30);                      // the month around the date
  const near = within(3);                        // ±3 days
  const cheapest = (list) => list.reduce((a, b) => (b.p < a.p ? b : a));
  const monthMin = cheapest(month);
  const nearMin = cheapest(near);
  // share of the surrounding days that cost more than (or the same as) this date
  const cheaperThanPct = Math.round(100 * month.filter((d) => d.p >= chosen.p).length / month.length);
  const level = ['low', 'medium', 'high'].includes(chosen.g)
    ? chosen.g
    : (cheaperThanPct >= 67 ? 'low' : cheaperThanPct >= 33 ? 'medium' : 'high');

  return {
    ...base,
    found: true,
    price: chosen.p,
    level,                                       // 'low' | 'medium' | 'high'
    cheaperThanPct,                              // vs. days within ±30 days
    vsMonthLowPct: Math.round(100 * (chosen.p - monthMin.p) / monthMin.p),
    monthLow: {date: monthMin.d, price: monthMin.p},
    betterNearby: nearMin.p < chosen.p ? {date: nearMin.d, price: nearMin.p} : null,
  };
});

// ─────────────────────────────────────────────────────────────────────────
// Booking deep link lookup (no caching — always fetched fresh on tap)
// ─────────────────────────────────────────────────────────────────────────
exports.getFlightBookingLink = onCall({secrets: [RAPIDAPI_KEY]}, async (request) => {
  const {itineraryId, sessionId} = request.data || {};
  console.log(`[flight] getFlightBookingLink called with itineraryId=${itineraryId}, sessionId=${sessionId}`);

  if (!itineraryId || !sessionId) {
    console.error('[flight] getFlightBookingLink — missing required argument(s)');
    throw new HttpsError('invalid-argument', 'itineraryId and sessionId are required.');
  }

  const url = `https://${RAPIDAPI_HOST}/api/v1/flights/getFlightDetails`;
  const params = {itineraryId, sessionId};
  console.log(`[flight] getFlightBookingLink — GET ${url}`, JSON.stringify(params));

  let resp;
  try {
    resp = await fetchWithRetry(url, params, rapidHeaders(), 'getFlightDetails');
  } catch (err) {
    logAxiosError('getFlightDetails', err);
    throw new HttpsError('internal',
      `getFlightDetails request failed: ` +
      (err.response ? `RapidAPI returned HTTP ${err.response.status}` : err.message));
  }

  console.log(`[flight] getFlightBookingLink — getFlightDetails HTTP ${resp.status}`);

  // TODO: confirm the exact path of deepLink in the real response
  const deepLink =
    resp.data?.data?.itinerary?.deepLink ?? resp.data?.data?.deepLink ?? null;

  if (!deepLink) {
    console.error(`[flight] getFlightBookingLink — NO deepLink FIELD FOUND. ` +
      `Full response (truncated): ${JSON.stringify(resp.data)?.slice(0, 1500)}`);
    throw new HttpsError('not-found', 'Could not find a booking link for this itinerary.');
  }

  console.log(`[flight] getFlightBookingLink — deepLink found: ${deepLink.slice(0, 100)}...`);

  // TODO: once approved for the Skyscanner Affiliates Program (via Impact.com),
  //       wrap deepLink with the mediaPartnerId tracking link here so clicks earn commission.
  //       For now this returns the raw deepLink with no affiliate tracking applied.
  return {deepLink};
});