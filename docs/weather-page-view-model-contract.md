# Weather Page ViewModel Contract

Phase: 2 controlled backend ViewModel wiring.

Status: the live Weather page is not switched to this contract. The existing weather endpoint can emit this normalized contract only when explicitly requested with `viewModel=weatherPage`.

## Current Authority

- Page markup and UI targets: `app/weather.cfm`
- Current client renderer and hydration orchestration: `assets/js/app/dashboard.js`
- Current weather endpoint/provider aggregation: `api/v1/weather.cfc`
- Current cache helper: `api/services/weatherCache.cfc`

## Phase 2 Endpoint Opt-In

The current endpoint remains legacy by default:

- `api/v1/weather.cfc?method=handle&action=search&zip=34652&marineMode=summary`
- `api/v1/weather.cfc?method=handle&action=search&zip=34652&marineOnly=1&marineMode=full&marineDetail=marine`
- `api/v1/weather.cfc?method=handle&action=search&zip=34652&marineOnly=1&marineMode=full&marineDetail=zoneForecast`

To request the normalized contract during Phase 2, add:

```text
viewModel=weatherPage
```

The Phase 2 endpoint path still uses the existing provider/cache aggregation and legacy mixed envelope first, then passes that envelope through `api/v1/WeatherPageViewModelService.cfc`. No Weather page JavaScript or renderer is switched in Phase 2.

## Target Contract

The future Weather page should render one normalized Weather Page ViewModel:

```json
{
  "ok": true,
  "requestId": "",
  "generatedAtUtc": "",
  "target": {
    "mode": "",
    "displayName": "",
    "zip": "",
    "lat": null,
    "lon": null,
    "timezone": "",
    "anchorLabel": ""
  },
  "status": {
    "summaryReady": false,
    "marineReady": false,
    "zoneReady": false,
    "degraded": false,
    "messages": []
  },
  "current": {
    "observedAtUtc": "",
    "stationId": "",
    "condition": "",
    "tempF": null,
    "feelsLikeF": null,
    "windMph": null,
    "windDirection": "",
    "gustMph": null,
    "pressureInHg": null,
    "visibilityMi": null,
    "humidityPct": null,
    "dewpointF": null
  },
  "marine": {
    "riskLevel": "",
    "riskScore": null,
    "recommendation": "",
    "seasFt": null,
    "wavePeriodSec": null,
    "waveDirectionDeg": null,
    "tideLevelFt": null,
    "tideTrend": "",
    "nextHigh": null,
    "nextLow": null,
    "tideStation": "",
    "waterLevelStation": ""
  },
  "forecast12h": [],
  "alerts": [],
  "zoneForecast": {
    "available": false,
    "reason": "",
    "zoneId": "",
    "zoneName": "",
    "office": "",
    "synopsis": "",
    "periods": [],
    "sourceUrl": ""
  },
  "map": {
    "center": {
      "lat": null,
      "lon": null
    },
    "layers": []
  },
  "cache": {
    "forecast": null,
    "alerts": null,
    "surface": null,
    "marine": null,
    "tide": null,
    "zoneForecast": null
  },
  "sources": [],
  "diagnostics": {
    "timingsMs": {},
    "warnings": []
  }
}
```

## Weather Page Data Inventory

| Section | Current UI target | Status | Current source | Future normalized field | Fallback behavior |
| --- | --- | --- | --- | --- | --- |
| Header/location | `weatherResolvedLocation` | required | `META.resolved_location`, `META.anchor.label`, request ZIP | `target.displayName` | Show configured ZIP/coordinates label or empty string. |
| Header/location | `weatherZipDisplay` | optional | request ZIP, geocoder metadata | `target.zip` | Hide ZIP-specific text when empty. |
| Header/location | `weatherAnchorMeta` | optional | `META.anchor.lat/lon` | `target.lat`, `target.lon`, `target.anchorLabel` | Show no anchor detail when coordinates are missing. |
| Header/source | `weatherProviderBadge` | optional | `META.provider`, source labels | `sources[]` | Default display remains NOAA/NWS. |
| Header/source | `weatherUpdatedAt` | optional | `META.generated_at_utc`, provider timestamps | `generatedAtUtc` | Show "Updated unknown" when empty. |
| Header/source | `weatherMetarStation` | optional | `surface.station_id`, `surface.station` | `current.stationId` | Hide station label when empty. |
| Current conditions | `weatherConditionText` | required | `SUMMARY.condition`, `surface.condition` | `current.condition` | Use empty condition text. |
| Current conditions | `weatherCurrentTemp` | optional | `SUMMARY.temp_f`, `surface.temperature_f` | `current.tempF` | Show placeholder when null. |
| Current conditions | `weatherFeelsLike` | optional | `SUMMARY.feels_like_f`, `surface.feels_like_f` | `current.feelsLikeF` | Show placeholder when null. |
| Current conditions | `weatherCurrentWind` | optional | `SUMMARY.wind_mph`, `surface.wind_mph` | `current.windMph`, `current.windDirection` | Show placeholder when null. |
| Current conditions | `weatherCurrentGusts` | optional | `SUMMARY.gust_mph`, forecast gusts | `current.gustMph` | Show placeholder when null. |
| Current conditions | `weatherPressure` | optional | `surface.pressure_inhg` | `current.pressureInHg` | Show placeholder when null. |
| Current conditions | `weatherVisibility` | optional | `surface.visibility_mi`, `MARINE.visibility_mi` | `current.visibilityMi` | Show placeholder when null. |
| Current conditions | `weatherHumidity` | optional | `surface.humidity_pct` | `current.humidityPct` | Show placeholder when null. |
| Current conditions | `weatherDewPoint` | optional | `surface.dewpoint_f` | `current.dewpointF` | Show placeholder when null. |
| Current conditions | `weatherObservedAt` | optional | `surface.observed_at_utc` | `current.observedAtUtc` | Show placeholder when empty. |
| Marine risk | `weatherRiskValue` | required | client calculation from forecast, alerts, marine | `marine.riskLevel` | Use "Unknown" or equivalent safe label. |
| Marine risk | `weatherRiskSubtext` | optional | client calculation | `marine.recommendation` | Show neutral guidance. |
| Marine risk | `weatherRiskWind` | optional | forecast/current wind | `current.windMph`, `forecast12h[]` | Show placeholder when null. |
| Marine risk | `weatherRiskGusts` | optional | forecast/current gusts | `current.gustMph`, `forecast12h[]` | Show placeholder when null. |
| Marine risk | `weatherRiskSeas` | optional | `MARINE.wave_height_ft` | `marine.seasFt` | Show placeholder when null. |
| Marine risk | `weatherRiskVisibility` | optional | `surface.visibility_mi`, `MARINE.visibility_mi` | `current.visibilityMi` | Show placeholder when null. |
| Marine risk | `weatherRiskAlerts` | optional | `ALERTS` | `alerts[]` | Show "None active" when empty. |
| Waves/seas | `weatherWaveHeight` | optional | `MARINE.wave_height_ft` | `marine.seasFt` | Show placeholder when null. |
| Waves/seas | `weatherWavePeriod` | optional | `MARINE.wave_period_sec` | `marine.wavePeriodSec` | Show placeholder when null. |
| Waves/seas | `weatherWaveDirection` | optional | `MARINE.wave_direction_deg` | `marine.waveDirectionDeg` | Show placeholder when null. |
| Waves/seas | `weatherWaveLevel` | optional | client level classification | `marine.riskLevel` or future marine wave level | Show placeholder when null. |
| Tide | `weatherCurrentTide` | optional | `MARINE.tide.current`, CO-OPS water level | `marine.tideLevelFt` | Show placeholder when null. |
| Tide | `weatherTideDirection` | optional | client trend calculation or provider trend | `marine.tideTrend` | Show placeholder when empty. |
| Tide | `weatherNextHighTideHeight` | optional | `MARINE.tide.next_high` | `marine.nextHigh.heightFt` | Show placeholder when null. |
| Tide | `weatherNextHighTideTime` | optional | `MARINE.tide.next_high` | `marine.nextHigh.timeUtc` | Show placeholder when empty. |
| Tide | `weatherNextLowTideHeight` | optional | `MARINE.tide.next_low` | `marine.nextLow.heightFt` | Show placeholder when null. |
| Tide | `weatherNextLowTideTime` | optional | `MARINE.tide.next_low` | `marine.nextLow.timeUtc` | Show placeholder when empty. |
| Tide | `weatherTideStation` | optional | CO-OPS tide station | `marine.tideStation` | Show "station unavailable" when empty. |
| Tide graph | `tideGraphSvg` | optional | `MARINE.tide.series` | future `marine.tideSeries[]` if added | Hide/empty graph when no series. |
| Alerts | `weatherAlertStatus` | required | `ALERTS` | `alerts[]` | Show "None active" when empty. |
| Alerts | `activeNoaaAlertsList` | optional | `ALERTS.features`, parsed alert array | `alerts[]` | Show empty state. |
| Next 12 hours | `weatherHourlyRows` | required | `FORECAST.periods` | `forecast12h[]` | Show empty state if no periods. |
| Zone forecast | `weatherZoneForecastContent` | optional | `ZONE_FORECAST` | `zoneForecast` | Show unavailable state and reason. |
| Map | `weatherMapLayerList` | optional | `MAP_LAYERS`, client defaults | `map.layers[]` | Show no available layers. |
| Map | `weatherLeafletMap` | optional | `META.anchor`, target coordinates | `map.center.lat`, `map.center.lon` | Do not initialize map without coordinates. |
| Diagnostics/source | `weatherSourceCacheStatus` | optional | `CACHE`, `META.cache_report` | `cache` | Show unknown cache status. |
| Diagnostics/source | `weatherSourceDataUpdated` | optional | provider timestamps | `sources[]`, `generatedAtUtc` | Show unknown update time. |
| Diagnostics/source | missing source cache rows | deprecated | `dashboard.js` references IDs not present in `app/weather.cfm` | `diagnostics` | Do not require these for the future contract. |

## Required Fields

Required for a clean first render:

- `ok`
- `target.displayName`
- `status.summaryReady`
- `status.degraded`
- `current.condition`
- `marine.riskLevel`
- `forecast12h`
- `alerts`
- `zoneForecast.available`
- `map.center`
- `cache`
- `diagnostics.warnings`

Required fields may still contain empty strings, empty arrays, or null numeric values when a provider is unavailable. The page should render a known empty/degraded state rather than interpreting raw provider payloads.

## Optional Fields

Most numeric provider values are optional because NOAA, CO-OPS, NDBC, METAR, or CWF data can be absent or stale. Optional values should normalize to null or empty strings and include a warning when relevant.

## Deprecated Or Removable Candidates

- DOM targets referenced by `dashboard.js` but absent from `app/weather.cfm`, such as `weatherSourceCacheRows`, `weatherSourceCachedAt`, `weatherSourceCacheExpires`, `weatherSourceDataAge`, and `weatherSourceRefreshWindow`.
- Active Cruise add-on render targets referenced from the Weather page render flow but not present in the Weather page markup.
- Client-side fabrication of default map layer labels when no backend layer contract exists.
- Raw provider casing fallbacks after the backend emits a stable normalized contract.

Removal is not approved in Phase 1.

## Phase 2 Handoff

Recommended Phase 2 work:

1. Keep the existing Weather page endpoint and provider calls unchanged.
2. Build `WeatherPageViewModelService` into a full backend normalizer used behind `api/v1/weather.cfc`.
3. Add an opt-in endpoint or response flag that returns the normalized view model beside the current mixed envelope.
4. Compare normalized output against Phase 1 fixtures and live summary/hydration responses.
5. Switch only the Weather page renderer after parity is proven.

Do not rewrite provider clients, cache behavior, Dashboard weather, Active Cruise weather, route weather factors, or UI layout as part of Phase 2 unless separately approved.


