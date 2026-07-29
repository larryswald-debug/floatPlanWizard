# FPW Weather Rewrite Phase 3

## Purpose

Phase 3 polishes the standalone Weather page runtime states while preserving the clean `pageWeather` rewrite path. It does not reuse legacy weather service logic, does not move Weather page rendering into `dashboard.js`, and does not change Dashboard, Active Cruise, route weather, database schema, provider architecture, or cache architecture.

## Degraded States Implemented

- Missing home-port coordinates:
  - User copy: `Weather needs a saved home-port location with coordinates.`
  - CTA: `/fpw/app/account.cfm`
  - Guidance: update the Home Port latitude and longitude fields.
- ZIP-only fallback unavailable:
  - User copy: `ZIP-only weather lookup is not enabled yet. Save a home port with coordinates to view local marine weather.`
  - CTA: `/fpw/app/account.cfm`
- Invalid coordinates:
  - User copy: `The coordinates entered were not valid.`
- Optional tide/water-level unavailable:
  - User copy: `Tide data is temporarily unavailable for this location.`
  - NOAA/NWS current conditions and forecast can still render.
- Empty hourly forecast:
  - User copy: `Hourly forecast is temporarily unavailable.`
- Empty alerts:
  - User copy: `No active weather alerts for this location.`
- Map unavailable:
  - The map button is disabled until valid coordinates are available.
  - User copy: `Map layers need a weather location with valid coordinates.`

## Loading Behavior

The existing Weather page loading console remains in place. One `action=pageWeather` request is made on initial page load. Transport and timeout failures show a generic user-safe message rather than raw provider or endpoint details.

## Contract Support

Small additive contract fields were added:

- `status.reason`
- `target.reason`

Provider and resolver details remain available in diagnostics, but user-facing status messages are normalized so raw provider errors do not display in the Weather page.

## Runtime Validation Results

Validated in Phase 3:

- MCPCFC TestBox bundle `fpw.tests.integration.WeatherRewritePhase1Spec`: 18 specs, 18 passed, 0 failed, 0 errors.
- Authenticated Playwright browser check at `/fpw/app/weather.cfm`: Weather page loaded `assets/js/app/weather-page.js?v=20260630-weather-rewrite-phase3` and did not load `assets/js/app/dashboard.js`.
- Authenticated Playwright missing-home-port check: state box rendered `Weather needs home-port coordinates`, CTA linked to `/fpw/app/account.cfm`, anchor displayed `Anchor: —`, and the NOAA map button was disabled.
- Authenticated Playwright coordinate-mode check using `27.7856, -82.7814`: current condition rendered `Clear`, current temperature rendered `81 °F`, 12 hourly forecast rows rendered, and the NOAA map button was enabled.
- Authenticated Playwright ZIP-only check using `34652`: state box rendered `ZIP-only weather is not enabled`, CTA linked to `/fpw/app/account.cfm`, hourly forecast rendered the temporary-unavailable row, and the NOAA map button was disabled.
- Playwright console check after Weather page validation: 0 browser console errors.
- `node --check assets/js/app/weather-page.js`: passed.
- `git diff --check` for the Phase 3 file set: passed.

## Known Limitations

- ZIP-only weather still cannot produce live data until an approved coordinate authority is selected.
- The account page has a Home Port form but no stable `#home-port` anchor, so the Weather page CTA links to `/fpw/app/account.cfm`.
- CO-OPS station coverage is location-dependent and may remain unavailable for some coordinates.
- NDBC wave data remains deferred.

## Phase 4 Recommendation

Phase 4 should stay separate and should only proceed after approval:

- choose and implement an approved ZIP coordinate authority if ZIP-only weather is needed
- add NDBC wave data only if needed and performance-safe
- consider Weather page display refinements after data flow remains stable
- map all remaining legacy weather callers before any deletion
- keep Dashboard, Active Cruise, and route-weather cleanup separate

