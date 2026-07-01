# FPW Weather Rewrite Phase 4

## Purpose

Phase 4 adds a ZIP-to-coordinate authority for the standalone Weather page only. It keeps the clean `pageWeather` path and does not reuse legacy weather service logic, does not move Weather page behavior into `dashboard.js`, and does not change Dashboard, Active Cruise, route weather, pricing, Stripe, entitlement, database schema, or provider architecture.

## Selected ZIP Coordinate Authority

Selected authority: U.S. Census Gazetteer ZIP Code Tabulation Area representative coordinates.

Source files and documentation:

- `https://www.census.gov/geographies/reference-files/2025/geo/gazetter-file.html`
- `https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2025_Gazetteer/2025_Gaz_zcta_national.zip`
- `https://www.census.gov/programs-surveys/geography/technical-documentation/records-layout/gaz-record-layouts.html`
- `https://www.census.gov/programs-surveys/geography/guidance/geo-areas/zctas.html`

The Census Gazetteer ZCTA file includes `GEOID`, `INTPTLAT`, and `INTPTLONG`. Phase 4 stores only the fields needed by FPW:

- `zip`
- `lat`
- `lon`

Local data file:

- `api/v1/weather/data/zcta2025_coordinates.csv`
- 33,791 ZCTA rows
- about 890 KB in compact CSV form

## Why Census Gazetteer Was Selected

- It is an official U.S. government source.
- It provides representative coordinates directly in a downloadable static file.
- It avoids external runtime geocoding on Weather page load.
- It avoids inventing coordinates.
- It is simple enough to cache in application scope from a local file.

USPS APIs were not selected because the researched public USPS API material is oriented around address/ZIP validation and does not provide a simple ZIP centroid coordinate authority for this use case. HUD-USPS ZIP Crosswalk files were not selected because they are crosswalks between ZIP and other geographies, not the simplest direct source of representative ZIP/ZCTA coordinates.

## Limitations

ZCTAs are approximate Census geography and are not exact USPS delivery ZIP boundaries. A ZCTA representative coordinate may not match a marina, ramp, dock, or saved home-port location.

User-facing approximation wording:

`Approximate weather for ZIP area 34652. ZIP-area coordinates may not match exact marina or home-port location.`

Service warning:

`ZIP-area coordinates are approximate and may not match exact marina or home-port location.`

## Target Resolution Priority

After Phase 4, `WeatherTargetResolver.cfc` resolves targets in this order:

1. Explicit valid `lat/lon`
2. Stored authenticated member home-port `lat/lng`
3. ZIP-only via Census ZCTA representative coordinate lookup
4. Degraded invalid ZIP / ZIP not found response
5. Fallback degraded response when no target exists

ZIP success target fields:

- `target.sourceType = "zip_zcta"`
- `target.displayName = "ZIP area #####"`
- `target.source = "CENSUS_ZCTA_GAZETTEER"`
- `target.sourceLabel = "U.S. Census Gazetteer ZCTA representative coordinate"`
- `target.isApproximate = true`
- `target.warnings[]` contains the approximation warning

## Cache Behavior

`WeatherZipCoordinateService.cfc` loads the compact local CSV file into application scope and reuses that in-memory index. It does not call Census, USPS, HUD, NOAA, or any other external service at runtime.

Weather provider requests are made only after the resolver returns valid coordinates.

## Runtime Behavior

Valid ZIP:

- resolves to `zip_zcta`
- marks the target approximate
- displays an approximation notice on the Weather page
- allows the normal NOAA/NWS and CO-OPS provider path to run
- enables the map only when valid coordinates are present

Invalid ZIP:

- returns a degraded normalized contract
- does not call providers
- does not initialize the map
- shows `Enter a valid 5-digit ZIP code.`

Unknown ZIP:

- returns a degraded normalized contract
- does not call providers
- does not initialize the map
- shows `No approved ZIP-area coordinate was found for this ZIP code.`

## Validation Results

Validation performed in Phase 4:

- `node --check assets/js/app/weather-page.js`: passed.
- `git diff --check`: passed before browser proof.
- MCPCFC TestBox bundle `fpw.tests.integration.WeatherRewritePhase1Spec`: 21 specs, 21 passed, 0 failed, 0 errored.
- Authenticated browser endpoint smoke on disposable user `fpw-weather-phase4-1782880397603@example.invalid`:
  - `zip=34652`: HTTP 200, `target.sourceType = "zip_zcta"`, `target.source = "CENSUS_ZCTA_GAZETTEER"`, `target.lat = 28.240555`, `target.lon = -82.744353`, `target.isApproximate = true`, provider cache entries present, 12 hourly forecast rows returned.
  - `zip=12ab3`: HTTP 200 degraded contract, `status.reason = "INVALID_ZIP"`, no provider cache entries, no map coordinates.
  - `zip=99999`: HTTP 200 degraded contract, `status.reason = "ZIP_NOT_FOUND"`, no provider cache entries, no map coordinates.
  - `lat=27.7856&lon=-82.7814&zip=34652`: HTTP 200, explicit `coordinates` target wins before ZIP, provider cache entries present, 12 hourly forecast rows returned.
- Authenticated Playwright Weather page smoke on disposable user:
  - ZIP `34652` displayed `ZIP area 34652`.
  - Header label displayed `Approximate ZIP area`.
  - Anchor displayed `28.2406, -82.7444`.
  - Approximation notice displayed the approved ZIP-area copy.
  - Weather page loaded `weather-rewrite-phase4`.
  - Weather page did not load `dashboard.js`.
  - Map layers button was enabled for the valid ZIP target.
  - `#weatherHourlyRows` rendered 12 rows.
  - Clean page console check returned 0 errors.
- Expected priority behavior confirmed: on an existing user with saved home-port coordinates, the resolver uses the stored home-port coordinates before ZIP, per the approved priority order.

## Known Limitations

- ZCTA coordinates are approximate and must not be presented as exact home-port or marina coordinates.
- Census Gazetteer updates should be reviewed annually when new files are published.
- ZIP lookup is U.S. ZCTA-based and does not cover non-ZCTA postal codes.
- NDBC wave/buoy support remains deferred.
- Legacy weather callers are not deleted or changed in Phase 4.

## Phase 5 Recommendation

Phase 5 should stay separate and should only proceed after approval:

- add NDBC wave/buoy support if marine wave data is still needed
- improve marine-specific forecast/wave display after data correctness remains stable
- add an explicit ZIP data refresh/import process if annual data maintenance needs UI or admin tooling
- map all remaining legacy weather callers before any selective deletion
- keep Dashboard, Active Cruise, and route-weather cleanup separate
