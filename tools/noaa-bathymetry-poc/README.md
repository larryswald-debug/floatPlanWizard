# NOAA Chart + BlueTopo Relief Proof of Concept

## Purpose

This is an isolated, authenticated FloatPlanWizard proof of concept for evaluating:

- NOAA Chart Display Service nautical-chart context.
- NOAA Office of Coast Survey BlueTopo elevation and hillshade.
- A disposable FPW-style Tampa Bay route and waypoint overlay.
- BlueTopo FeatureInfo source and uncertainty metadata.

It is intentionally not integrated into Route Builder, shared map modules, navigation,
the database, saved routes, membership rules, or production route APIs.

## POC files

- `/demo/noaa-bathymetry-poc.cfm`
- `/assets/css/demo/noaa-bathymetry-poc.css`
- `/assets/js/demo/noaa-bathymetry-poc.js`
- `/tools/noaa-bathymetry-poc/README.md`

## Access

The page uses the existing `includes/require_auth.cfm` guard.

Local URL:

```text
http://localhost:8500/fpw/demo/noaa-bathymetry-poc.cfm
```

The exact host and base path depend on the local FPW ColdFusion configuration.
Unauthenticated visitors are redirected through the existing FPW member-login flow.
The page does not add a navigation link.

## Service architecture

### NOAA Chart Display Service

Chart tiles reuse FPW's existing allow-listed proxy target:

```text
/api/v1/wmsProxy.cfc?method=tile&target=noaa-charts
```

That existing target resolves to NOAA's Chart Display Service WMS:

```text
https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer
```

The POC requests WMS layers `0` through `12` using WMS 1.3.0. The browser does not
call that upstream directly. The existing proxy caches successful GetMap requests for
300 seconds and GetCapabilities requests for 3600 seconds, retries upstream failures,
and returns a diagnostic header with either upstream/cache success or fallback state.

The proxy continues to own:

- The allow-listed NOAA Chart Display upstream URL.
- WMS parameter sanitization.
- Caching.
- Upstream retry behavior.
- Transparent PNG fallback for failed GetMap requests.

The POC does not modify the proxy or the shared NOAA Leaflet helper.

Because failed proxy GetMap calls intentionally return a valid transparent PNG, the
page performs a small Tampa Bay chart-health probe. It uses the proxy's diagnostic
header and inspects the returned image. A fallback or fully transparent health image
produces a visible warning without disabling BlueTopo, route, waypoint, or control
operation.

### BlueTopo relief

The POC directly requests the official NOAA nowCOAST WMTS:

```text
https://nowcoast.noaa.gov/geoserver/gwc/service/wmts/rest/
```

Layers and styles:

- `bluetopo:bathymetry` / `nbs_elevation`
- `bluetopo:hillshade` / `nbs_hillshade`
- Tile matrix set `EPSG:3857`
- Tile format `image/png8`

No BlueTopo data is downloaded, transformed, or stored by FPW. No GDAL or Docker
preprocessing is required for this POC.

The elevation layer uses NOAA's official rendering and official legend. The POC does
not invent a custom elevation-to-color scale.

## Visual modes

The page provides:

1. **NOAA Chart only**
2. **Seafloor Relief only**
3. **Combined view**

The combined mode keeps the chart above relief in a higher Leaflet pane and uses
restrained relief opacity so nautical-chart information remains dominant.

The Leaflet layer control can also independently toggle:

- NOAA Nautical Chart
- NOAA Seafloor Relief (grouped elevation and hillshade)
- Illustrative FPW Route
- FPW Sample Waypoints

OpenStreetMap is a neutral reference basemap for land and place-name context.

## FeatureInfo inspection

Clicking the map sends a direct, CORS-enabled NOAA nowCOAST WMTS FeatureInfo request
using the `bluetopo:source_survey_id` style. This style returns the elevation and
uncertainty values along with contributor metadata.

The panel displays only reported NOAA fields:

- Elevation in meters relative to NAVD88.
- Reported vertical uncertainty in meters.
- `bathy_coverage` classification:
  - true: measured bathymetry.
  - false: interpolated bathymetry.
- Source survey identifier.
- Survey start/end date.
- Source institution.

The POC does not calculate or display an accuracy score.

The service uses 512-pixel WMTS tiles. The client converts a Leaflet click to the
corresponding EPSG:3857 tile matrix, row, column, and 512-pixel `I`/`J` position.

FeatureInfo is deliberately fault-isolated:

- It has its own request timeout and AbortController.
- A new click cancels only the previous FeatureInfo request.
- Failure updates only the inspection panel.
- Failure does not add/remove layers, change visual mode, or affect the map.

## Elevation and navigation limitation

BlueTopo elevation is not labeled as current water depth.

NOAA defines BlueTopo elevation relative to the North American Vertical Datum of 1988
(NAVD88). Negative values indicate locations below NAVD88, but they are not charted
depths, soundings, clearance values, or real-time water depths.

BlueTopo combines sources of varying age and quality and includes measured and
interpolated data. The reported uncertainty and source metadata must be considered
together. This POC is not for navigation or measurement.

Use current official NOAA Electronic Navigational Charts and appropriate navigation
equipment for navigation.

## BlueTopo source metadata

| Field | POC evidence |
| --- | --- |
| NOAA product | Office of Coast Survey BlueTopo bathymetry and hillshade |
| Access method | Direct official nowCOAST WMTS and FeatureInfo requests |
| POC access date | 2026-07-28 |
| Spatial coverage used | Tampa Bay and nearby Gulf Coast sample-route extent |
| Map CRS | EPSG:3857 WMTS tile matrix |
| Vertical datum | NAVD88 |
| Elevation units | Meters |
| Horizontal resolution | Varies by contributing source; the POC does not claim one map-wide resolution |
| Survey/product date | Returned per selected location when NOAA reports it |
| Nodata convention | Not inferred or relabeled by the POC |
| Uncertainty | NOAA-reported vertical uncertainty shown per selected location |
| Measured/interpolated status | NOAA `bathy_coverage` value shown per selected location |
| Local download or processing | None; no source raster is stored or transformed |

The page records its last completed initial map load in the source panel. Source dates
remain location-specific because presenting one date for the combined BlueTopo surface
would overstate the uniformity of its contributing surveys.

## Official references

- NOAA GIS Data and Services:
  https://nauticalcharts.noaa.gov/data/gis-data-and-services.html
- NOAA BlueTopo:
  https://nauticalcharts.noaa.gov/data/bluetopo.html
- NOAA BlueTopo specifications:
  https://nauticalcharts.noaa.gov/data/bluetopo_specs.html
- NOAA BlueTopo FAQ:
  https://nauticalcharts.noaa.gov/data/bluetopo_faq.html
- nowCOAST WMTS capabilities:
  https://nowcoast.noaa.gov/geoserver/gwc/service/wmts?REQUEST=GetCapabilities
- OpenStreetMap attribution:
  https://www.openstreetmap.org/copyright

## Failure behavior

| Failure | Visible behavior | Unaffected features |
| --- | --- | --- |
| Chart proxy transparent fallback | Persistent yellow chart-service warning | Relief, route, waypoints, modes, layer control, FeatureInfo |
| Multiple chart tile errors | Chart status warning | Relief, route, waypoints, modes, layer control, FeatureInfo |
| BlueTopo tile error | Relief status reports partial failure | Chart, route, waypoints, modes, layer control |
| FeatureInfo error/timeout | Inspection panel reports unavailable | Every map layer and control |
| Leaflet unavailable | Page-level map initialization error | Source and limitation content remains visible |

## Validation checklist

After signing into local FPW:

1. Open `/demo/noaa-bathymetry-poc.cfm`.
2. Confirm the chart, relief, route, and waypoint overlays render over Tampa Bay.
3. Select each of the three visual modes.
4. Toggle every overlay independently in the Leaflet control.
5. Confirm the combined view keeps the chart visually dominant.
6. Click BlueTopo coverage and verify all reported metadata fields.
7. Confirm the elevation label says `relative to NAVD88`.
8. Confirm the page never describes elevation as current water depth.
9. Force a FeatureInfo failure and verify the map remains interactive.
10. Verify no browser console errors.
11. Inspect network requests for:
    - Same-origin chart WMS proxy traffic.
    - Direct nowCOAST BlueTopo WMTS tile traffic.
    - Direct nowCOAST FeatureInfo traffic.
12. Test desktop, tablet, and mobile widths.
13. Confirm no Route Builder or saved-route behavior changed.

Repository checks:

```bash
git diff --check
git status --short
```

## Production considerations outside this POC

Before any future production integration, separately evaluate:

- An allow-listed BlueTopo proxy and cache.
- NOAA service monitoring and rate behavior.
- Production Content Security Policy compatibility.
- Long-term WMTS contract/version monitoring.
- Product copy and legal review of attribution and navigation warnings.
- Route Builder UX and performance impact.

Those changes are intentionally outside this POC.
