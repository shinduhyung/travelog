// functions/flight_functions.js
//
// Flight price proxy backed by Air Scrapper (formerly Sky-scrapper) on RapidAPI.
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

function rapidHeaders() {
  return {
    'X-RapidAPI-Key': RAPIDAPI_KEY.value(),
    'X-RapidAPI-Host': RAPIDAPI_HOST,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// IATA -> Skyscanner's internal skyId/entityId mapping (airport codes never
// change, so this is cached permanently).
// ─────────────────────────────────────────────────────────────────────────
async function getAirportSkyId(iata) {
  const ref = db.collection('airport_sky_ids').doc(iata);
  const snap = await ref.get();
  if (snap.exists) return snap.data();

  const resp = await axios.get(
    `https://${RAPIDAPI_HOST}/api/v1/flights/searchAirport`,
    {params: {query: iata, locale: 'en-US'}, headers: rapidHeaders()}
  );

  // Response is an array, and the first entry can be a CITY rather than an
  // airport, so find the AIRPORT entry whose skyId matches the IATA code
  // (confirmed shape: data[i].navigation.relevantFlightParams).
  const list = resp.data?.data ?? [];
  const match =
    list.find((item) => item.navigation?.relevantFlightParams?.skyId?.toUpperCase() === iata.toUpperCase()) ??
    list.find((item) => item.navigation?.relevantFlightParams?.flightPlaceType === 'AIRPORT');

  if (!match) {
    throw new HttpsError('not-found', `Could not resolve a skyId for airport code ${iata}.`);
  }

  const result = {
    skyId: match.navigation.relevantFlightParams.skyId,
    entityId: match.navigation.relevantFlightParams.entityId,
  };

  await ref.set(result);
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// Price lookup (24h Firestore cache)
// ─────────────────────────────────────────────────────────────────────────
exports.getFlightPrice = onCall({secrets: [RAPIDAPI_KEY]}, async (request) => {
  const {originIata, destinationIata, date, stops} = request.data || {};

  if (!originIata || !destinationIata || !date) {
    throw new HttpsError('invalid-argument', 'originIata, destinationIata, and date are required.');
  }

  const cacheKey = `${originIata}_${destinationIata}_${date}_${stops ?? 'any'}`;
  const cacheRef = db.collection('flight_price_cache').doc(cacheKey);

  const cachedSnap = await cacheRef.get();
  if (cachedSnap.exists) {
    const cached = cachedSnap.data();
    if (Date.now() - cached.updatedAt < CACHE_TTL_MS) {
      return cached;
    }
  }

  const [origin, destination] = await Promise.all([
    getAirportSkyId(originIata),
    getAirportSkyId(destinationIata),
  ]);

  const resp = await axios.get(
    `https://${RAPIDAPI_HOST}/api/v1/flights/searchFlights`,
    {
      params: {
        originSkyId: origin.skyId,
        destinationSkyId: destination.skyId,
        originEntityId: origin.entityId,
        destinationEntityId: destination.entityId,
        date,
        adults: 1,
        currency: 'KRW', // TODO: make this dynamic (request param) if needed
        market: 'en-US',
        countryCode: 'KR',
        // TODO: add the stops filter param once its exact name is confirmed
        // (currently filtered client-side below instead)
      },
      headers: rapidHeaders(),
    }
  );

  let itineraries = resp.data?.data?.itineraries ?? [];

  if (stops === 'direct') {
    itineraries = itineraries.filter((it) => (it.legs?.[0]?.stopCount ?? 99) === 0);
  }

  if (itineraries.length === 0) {
    const empty = {found: false, updatedAt: Date.now()};
    await cacheRef.set(empty);
    return empty;
  }

  // The response order isn't guaranteed to be price-sorted, so compute the
  // cheapest itinerary explicitly.
  const cheapest = itineraries.reduce((min, it) =>
    (it.price?.raw ?? Infinity) < (min.price?.raw ?? Infinity) ? it : min
  );
  const leg = cheapest.legs?.[0];

  const result = {
    found: true,
    priceRaw: cheapest.price?.raw ?? null,
    priceFormatted: cheapest.price?.formatted ?? null,
    stopCount: leg?.stopCount ?? null,
    durationInMinutes: leg?.durationInMinutes ?? null,
    carrier: leg?.carriers?.marketing?.[0]?.name ?? null,
    itineraryId: cheapest.id ?? null,        // TODO: confirm actual field name
    sessionId: resp.data?.sessionId ?? null, // TODO: confirm actual location
    updatedAt: Date.now(),
  };

  await cacheRef.set(result);
  return result;
});

// ─────────────────────────────────────────────────────────────────────────
// Booking deep link lookup (no caching — always fetched fresh on tap)
// ─────────────────────────────────────────────────────────────────────────
exports.getFlightBookingLink = onCall({secrets: [RAPIDAPI_KEY]}, async (request) => {
  const {itineraryId, sessionId} = request.data || {};

  if (!itineraryId || !sessionId) {
    throw new HttpsError('invalid-argument', 'itineraryId and sessionId are required.');
  }

  const resp = await axios.get(
    `https://${RAPIDAPI_HOST}/api/v1/flights/getFlightDetails`,
    {params: {itineraryId, sessionId}, headers: rapidHeaders()}
  );

  // TODO: confirm the exact path of deepLink in the real response
  const deepLink =
    resp.data?.data?.itinerary?.deepLink ?? resp.data?.data?.deepLink ?? null;

  if (!deepLink) {
    throw new HttpsError('not-found', 'Could not find a booking link for this itinerary.');
  }

  // TODO: once approved for the Skyscanner Affiliates Program (via Impact.com),
  //       wrap deepLink with the mediaPartnerId tracking link here so clicks earn commission.
  //       For now this returns the raw deepLink with no affiliate tracking applied.
  return {deepLink};
});