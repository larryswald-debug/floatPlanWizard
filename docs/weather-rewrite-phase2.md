# FPW Weather Rewrite Phase 2

## Purpose

Phase 2 makes the clean `pageWeather` endpoint resolve a reliable Weather page target before any provider calls. It keeps the Phase 1 display structure and clean contract, and it does not reuse legacy weather service logic.

## Target Resolution Priority

`WeatherTargetResolver.cfc` resolves targets in this order:

1. Explicit valid `lat` and `lon` request parameters.
2. Stored authenticated member home-port latitude and longitude.
3. Stored authenticated member home-port ZIP and display label only when stored coordinates are also usable.
4. Explicit ZIP only as a degraded target unless an approved ZIP coordinate authority is added later.
5. Safe degraded response when no usable coordinates are available.

Latitude and longitude must be numeric, within normal coordinate ranges, and not `0,0`.

## Home-Port Coordinate Source

The canonical home-port source is `users_address`.

- Home-port rows are selected with `userId = :userId` and `isHomePort = 1`.
- Location fields used by Weather:
  - `city`
  - `state`
  - `zip`
  - `lat`
  - `lng`
  - `isHomePort`
- The public read/write authority for this data is `api/v1/homeport.cfc`.
- `app/account.cfm` and `assets/js/app/account.js` expose and save latitude/longitude fields through that endpoint.
- Latitude and longitude are optional at save time, so the Weather page must degrade cleanly when they are missing.

## ZIP Fallback Policy

Phase 2 does not use ZIP-only lookup for provider calls. No reliable approved ZIP centroid authority exists inside FPW today, and the Phase 1 Census ZIP attempt was not reliable for the current dev target.

ZIP-only requests now return a normalized degraded response with `target.sourceType = "manual ZIP"` and no provider calls.

## Provider Calls

The clean path uses:

- NOAA/NWS API for point metadata, hourly forecast, observation stations, latest observation, alerts, marine zone lookup, and zone forecast.
- NOAA CO-OPS API for tide predictions and water level where a nearby station is available.

NDBC remains deferred. It is not required for Phase 2 target resolution or live Weather page proof.

## Cache Strategy

The Weather rewrite cache remains `WeatherCache.cfc`, keyed by provider and data type.

Phase 2 cache entries include:

- `nws:point:<lat>,<lon>`
- `nws:hourly:<forecastHourlyUrl>`
- `nws:stations:<observationStationsUrl>`
- `nws:observation:<stationId>`
- `nws:alerts:<lat>,<lon>`
- `nws:marine-zones:<lat>,<lon>`
- `nws:zone-forecast:<zoneId>`
- `coops:stations:<stationType>`
- `coops:predictions:<stationId>:<yyyymmdd>`
- `coops:waterlevel:<stationId>`

Cache metadata is returned in the clean contract under `cache.entries`. Failed provider refreshes can reuse stale cached data when stale data exists.

## Degraded Response Behavior

The endpoint returns the clean contract shape for all target and provider outcomes.

- Missing or invalid coordinates: no provider calls, `ok = false`, degraded status message.
- ZIP-only target: no provider calls, `ok = false`, degraded ZIP policy message.
- Required NWS point metadata failure: degraded response.
- Optional CO-OPS failure: current/forecast/alerts can still make the response useful.

## Known Limitations

- ZIP-only weather cannot produce live data until an approved ZIP coordinate authority is selected.
- Home-port latitude and longitude are optional account fields today.
- CO-OPS station lookup is nearest-station based and may not find a station for every inland coordinate.
- NDBC wave data is still deferred.

## Runtime Validation Results

Phase 2 validation proved:

- The TestBox bundle `fpw.tests.integration.WeatherRewritePhase1Spec` ran 15 specs with 15 passing, 0 failures, and 0 errors.
- `assets/js/app/weather-page.js` passed `node --check`.
- `git diff --check` passed.
- An authenticated browser load of `/fpw/app/weather.cfm` used `weather-page.js` and did not load `dashboard.js`.
- A logged-in member home-port without usable coordinates produced a clean degraded Weather page message instead of calling providers.
- A coordinate-mode Weather page request for `27.7856,-82.7814` rendered live NOAA/NWS data: current condition `Clear`, temperature `81 °F`, observation station `KSPG`, and 12 hourly rows.
- The same browser run reported no console errors.
- CO-OPS tide data was unavailable for the tested coordinate and degraded as optional data without blocking the NOAA/NWS weather render.

## Phase 3 Recommendation

Phase 3 should polish Weather page runtime and UI states after reliable target data is proven:

- improve missing-coordinate/home-port setup copy
- add a clear account/home-port setup CTA if needed
- optionally add an approved ZIP coordinate source
- improve map/layer display if reliable
- add NDBC wave data only if needed and performant
- keep legacy deletion out of scope until all callers are mapped

