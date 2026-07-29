# FPW Weather Rewrite Phase 1

## Purpose

Phase 1 starts the Weather page over with a clean contract and a dedicated page service. The existing `app/weather.cfm` display structure is preserved, but the standalone Weather page no longer uses `assets/js/app/dashboard.js` as its renderer.

## Official Sources Consulted

- National Weather Service API documentation: `https://www.weather.gov/documentation/services-web-api`
- National Weather Service OpenAPI specification: `https://api.weather.gov/openapi.json`
- NOAA CO-OPS Data API: `https://api.tidesandcurrents.noaa.gov/api/prod/`
- NOAA CO-OPS Metadata API: `https://api.tidesandcurrents.noaa.gov/mdapi/prod/`
- National Data Buoy Center realtime access documentation: `https://www.ndbc.noaa.gov/faq/rt_data_access.shtml`
- U.S. Census Geocoder: `https://geocoding.geo.census.gov/geocoder/`

## Source Ownership

- Target resolution:
  - Member home-port coordinates from `users_address.lat` and `users_address.lng`.
  - Manual ZIP coordinates from the official U.S. Census Geocoder because NWS point lookup requires coordinates.
- Current conditions:
  - NWS observation station latest observation.
- Forecast:
  - NWS point metadata and hourly forecast URL.
- Alerts:
  - NWS active alerts by point.
- Tides and water level:
  - NOAA CO-OPS station metadata and data products.
- Waves:
  - Not blocking in Phase 1. NDBC was researched as the official wave-observation source, but executable NDBC station discovery and normalization are deferred until Phase 2 because the minimum page contract can safely degrade wave fields.
- Zone forecast:
  - NWS marine zone lookup by point, then NWS zone forecast when a matching marine zone exists.

## Endpoint

The new standalone Weather page path is:

```text
/fpw/api/v1/weather.cfc?method=handle&action=pageWeather
```

Existing `get`, `zip`, and `search` actions remain in place for legacy Dashboard, Active Cruise, and route-weather callers.

## Normalized Contract

The new service returns only the clean Phase 1 Weather page contract:

- `ok`
- `requestId`
- `generatedAtUtc`
- `target`
- `status`
- `current`
- `marine`
- `forecast12h`
- `alerts`
- `zoneForecast`
- `map`
- `cache`
- `sources`
- `diagnostics`

Legacy `SUCCESS` / `DATA` envelopes are not used by `action=pageWeather`.

## Cache Strategy

The new cache lives in application scope through `WeatherCache.cfc` with typed keys.

- NWS point metadata: 24 hours
- NWS hourly forecast: 15 minutes
- NWS observation stations: 6 hours
- NWS latest observation: 5 minutes
- NWS alerts: 3 minutes
- NWS marine zone lookup: 6 hours
- NWS zone forecast: 30 minutes
- CO-OPS station metadata: 24 hours
- Failed provider fetches: 45 seconds

## Performance Strategy

- One page request from the browser to FPW.
- Short provider timeouts.
- Optional marine/tide/zone data degrades instead of blocking the page indefinitely.
- The browser consumes only the normalized FPW contract.
- The Weather page no longer performs dashboard-coupled hydration calls.

## Phase 1 Limits

- NDBC is not implemented in the Phase 1 executable service path. Wave fields degrade safely until Phase 2 adds buoy station selection and normalization behind the same contract.
- CO-OPS nearest-station lookup caches the official station list and chooses the nearest local station in FPW.
- The map only initializes when valid coordinates are present.
- Runtime validation showed the U.S. Census Geocoder is not a reliable ZIP-only centroid source for the current dev ZIP fallback. Phase 2 should use stored home-port latitude/longitude first and only add a ZIP resolver after an approved canonical ZIP coordinate authority is selected.
- The legacy Weather service remains in the repo for existing callers until Phase 2 proves replacement coverage.

## Phase 2 Recommendation

Phase 2 should expand live-provider coverage behind the same normalized contract, add authenticated browser regression coverage for the Weather page, and then identify legacy weather functions that are no longer called by any route.



