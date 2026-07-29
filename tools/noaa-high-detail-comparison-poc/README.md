# NOAA High-Detail Seafloor Comparison POC

This is an isolated, authenticated proof of concept for comparing NOAA Chart
Display, NOAA BlueTopo, and one native-resolution NOAA NGS Southern Tampa Bay
topobathymetry zone. It is not linked from production navigation and is not used
by Route Builder or any production map.

Page:

`/demo/noaa-high-detail-comparison-poc.cfm`

## Scope boundary

The POC is limited to the approved 2 km by 2 km Southern Tampa Bay window. It
does not:

- change the existing NOAA chart proxy;
- change a shared production map helper;
- use member route data;
- add a database record or schema;
- calculate a datum conversion;
- calculate current depth, clearance, or route safety;
- modify membership, billing, float-plan, Active Cruise, weather, pricing, or
  navigation behavior.

## Sources and datum warning

### Native South Tampa relief

| Field | Value |
| --- | --- |
| Product | 2021 NOAA NGS Topobathy Lidar DEM Southern Tampa Bay, Florida |
| Source tile | `2021_339000e_3067000n_dem.tif` |
| Source agency | NOAA National Geodetic Survey; distributed by NOAA Office for Coastal Management |
| Survey dates | 2021-01-26 through 2021-02-27 |
| Horizontal CRS | NAD83(2011) / UTM zone 17N, EPSG:6346 |
| Vertical datum | NAVD88, Geoid18 |
| Units | metres |
| Native cell size | 1 metre |
| Approved UTM bounds | west 339267, east 341267, south 3064121, north 3066121 |
| Approved valid coverage | 99.97035% |
| Dataset QA | Bathymetric RMSEz 15.5 cm; bathymetric vertical accuracy ±30.4 cm at 95% confidence |

The QA figures are dataset-level results from four submerged checkpoints. They
are not per-cell guarantees. The metadata warns that temporal change may have
occurred, that outliers or false returns may be present, and that some returns
may be misclassified. NOAA describes the product as not intended for mapping,
charting, or navigation.

The native layer displays **bathymetric elevation relative to NAVD88**. It does
not represent current water depth.

### NOAA BlueTopo

The POC loads BlueTopo elevation and hillshade directly from NOAA nowCOAST.
BlueTopo elevation is also referenced to NAVD88. A click requests NOAA
FeatureInfo independently and, where NOAA returns it, displays:

- elevation in metres relative to NAVD88;
- NOAA-reported uncertainty;
- source survey identity and institution;
- survey date range;
- measured-versus-interpolated status.

FeatureInfo failure affects only the inspection panel. No accuracy score is
invented.

### NOAA Chart Display

The chart overlay uses FPW's existing allowlisted `noaa-charts` WMS proxy.
The POC follows NOAA's live Chart Display Service subject to the proxy's
300-second GetMap cache.
**NOAA charted depths are relative to MLLW.** They are not numerically compared
with either NAVD88 relief source.

The proxy can return a valid but fully transparent PNG when its upstream service
is unavailable. This POC performs an independent same-area image request and
examines the decoded alpha channel. HTTP 200 and the proxy diagnostic header are
not treated as sufficient proof of a visible chart.

**Neither relief layer represents current water depth.**

## Approved extent

Center:

`27.7009075652856, -82.6200072680348`

Corners:

| Corner | Latitude | Longitude |
| --- | ---: | ---: |
| Northwest | 27.7098125683432 | -82.6302800675715 |
| Northeast | 27.7100499393613 | -82.6100010567928 |
| Southeast | 27.6920017176445 | -82.6097361351387 |
| Southwest | 27.6917645274034 | -82.6300118126363 |

## Source preparation

Only the approved source tile is downloaded:

`https://noaa-nos-coastal-lidar-pds.s3.amazonaws.com/dem/NGS_South_TampBay_Topobathy_2021_9481/2021_339000e_3067000n_dem.tif`

Expected integrity:

- size: `102303312` bytes;
- SHA-256:
  `4d943093c0f88b72007d0f99e3e325395a8d0ec21c8be01baba1e7d87de43c90`.

All GIS work runs in this pinned temporary container:

`ghcr.io/osgeo/gdal@sha256:a0dcafba68b64c19a97b718767bcb3f245d1aac94714fea397201d6cdb763f8b`

No GIS package is installed into the host, ColdFusion container, or main
application image.

From the repository root:

```sh
./tools/noaa-high-detail-comparison-poc/process-source.sh
```

The script:

1. creates a temporary work directory;
2. downloads only the named NOAA GeoTIFF;
3. hard-checks the known size and SHA-256;
4. records `gdalinfo` source metadata;
5. clips exactly to the approved UTM bounds at the native 1 m grid;
6. applies the official BlueTopo `nbs_elevation` color-map breakpoints;
7. creates multidirectional hillshade using `z=2.0` and edge computation;
8. combines color and shade without sharpening or smoothing;
9. copies the source-validity alpha unchanged;
10. creates static XYZ PNG tiles at zooms 14–17 with nearest-neighbor spatial
    resampling and transparent-tile exclusion;
11. validates count, zoom structure, PNG decoding, and nodata alpha;
12. writes a public manifest beside the tiles; and
13. removes the temporary source and intermediate rasters.

No source GeoTIFF or intermediate raster is published under `/assets`.

## Processing parameters

- exact clip: `339267 3066121 341267 3064121`, EPSG:6346;
- native output grid: 2000 by 2000 cells at 1 m;
- source nodata remains nodata and becomes alpha 0;
- official BlueTopo `nbs_elevation` breakpoints;
- `gdaldem hillshade -multidirectional -compute_edges -z 2.0`;
- combined RGB:
  `color RGB × (0.65 + 0.35 × hillshade / 255)`;
- combined alpha: color-relief alpha copied unchanged;
- no sharpening;
- no smoothing;
- no nodata filling;
- no interpolation across nodata;
- tile driver: PNG;
- opaque tiles may be PNG RGB, while tiles containing nodata remain PNG RGBA
  with binary alpha;
- tile scheme: XYZ;
- tile size: 256 px;
- spatial resampling: nearest neighbour;
- tile zooms: 14–17.

At the approved latitude, zoom 17 is about 1.057 m per CSS pixel and is the
closest Web Mercator zoom to the native 1 m grid. Zoom 18 would be about
0.529 m per pixel and would oversample the source. The map allows zoom 18 only
as explicitly labeled digital enlargement; `maxNativeZoom` remains 17.

Expected tile structure:

| Zoom | Approx. ground resolution | XYZ range | Tiles |
| --- | ---: | --- | ---: |
| 14 | 8.45954 m/px | x 4431–4432, y 6878–6879 | 4 |
| 15 | 4.22977 m/px | x 8862–8864, y 13757–13759 | 9 |
| 16 | 2.11488 m/px | x 17725–17729, y 27514–27518 | 25 |
| 17 | 1.05744 m/px | x 35451–35458, y 55029–55036 | 64 |
| Total |  |  | 102 |

The processor requires transparent pixels somewhere in the complete tile set,
so nodata transparency cannot be silently lost. Fully transparent tiles are
excluded. The manifest also records a verified alpha-zero output-pixel center
near the representative natural source nodata cell; use that post-reprojection
coordinate for deterministic browser fallback proof.

The generated tiles and processing manifest are isolated under:

`/assets/maps/poc/south-tampa-high-detail/`

## Interactive design

Desktop uses two synchronized Leaflet maps:

- left: BlueTopo plus NOAA Chart in the default comparison;
- right: native South Tampa relief plus the same NOAA Chart.

The implementation uses independently instantiated layers on each map and a
re-entry guard for pan/zoom synchronization. On a viewport at or below 920 px,
the page rebuilds as one map to avoid hidden-map geometry, doubled tile traffic,
and unusable narrow map columns. Center and zoom are preserved.

Modes:

1. Side-by-side comparison;
2. NOAA Chart only;
3. BlueTopo relief only;
4. BlueTopo with NOAA Chart;
5. Native 1 m South Tampa relief only;
6. Native 1 m South Tampa relief with NOAA Chart;
7. Native 1 m South Tampa relief with BlueTopo fallback and NOAA Chart.

The route, waypoints, and optional neutral debugging basemap are independent
native-form toggles.

Final display opacities:

| Layer/context | Opacity |
| --- | ---: |
| NOAA Chart in combined modes | 0.88 |
| BlueTopo elevation under chart | 0.56 |
| BlueTopo hillshade under chart | 0.24 |
| Native relief under chart | 0.82 |
| Native relief in fallback mode | 0.88 |
| Native relief alone | 0.96 |

These values keep chart symbols and labels dominant while retaining seafloor
texture for comparison.

## Disposable route

The POC route uses fixed coordinates and no production-member data:

| Point | Latitude | Longitude |
| --- | ---: | ---: |
| GIWW west approach | 27.69578 | -82.62820 |
| Gulf Intracoastal Waterway | 27.69595 | -82.61920 |
| Cut-A junction | 27.69635 | -82.61055 |
| St. Petersburg Harbor Cut-A | 27.70625 | -82.61018 |

The geometry was checked against NOAA's Coastal Maintained Channels feature
layer. It intersects the Gulf Intracoastal Waterway polygon and the St.
Petersburg Harbor Cut-A polygons whose fairway is identified as Saint Petersburg
Channel.

It is labeled:

`Illustrative planning route — not a validated safe route`

## Fault isolation

| Failure | Visible effect | What remains available |
| --- | --- | --- |
| NOAA Chart transparent/unavailable | Exact chart-context warning | Both relief sources, route, waypoints, controls |
| BlueTopo tile failure | BlueTopo warning/status | Native relief, chart, route, waypoints |
| Native local tile failure | Native partial-failure warning | BlueTopo fallback, chart, route, waypoints |
| FeatureInfo failure | Inspection-panel error only | All maps, layers, overlays, and controls |
| Route build failure | Route status only | Maps, raster layers, waypoints |
| Waypoint build failure | Waypoint status only | Maps, raster layers, route |
| Leaflet initialization failure | Page-level map alert | Source, datum, attribution, and disclaimer text |
| Zoom above 17 | Digital-enlargement warning | Map remains usable without implying more detail |

### Isolated validation hooks

The authenticated POC accepts one optional `pocFault` query value solely for
repeatable browser validation:

- `chart-transparent`
- `bluetopo`
- `native`
- `featureinfo`
- `route`
- `waypoints`
- `map-init`

These values are allowlisted, inert by default, confined to this demo page, and
do not change the shared chart proxy, shared map files, or source data.

`pocFocus=nodata` is a separate inert validation view. It centers zoom 18 on
the manifest's verified post-reprojection alpha-zero pixel so native-only and
fallback captures use exactly the same view. The normal page remains centered
on the approved comparison area at zoom 16.

## Validation

The final implementation report records:

- source and tile integrity output;
- generated sizes and processing duration;
- authenticated desktop and mobile browser results;
- six identical-view comparison captures plus the route view;
- map synchronization and responsive rebuild checks;
- actual transparent-chart health-warning proof;
- natural nodata transparency and BlueTopo fallback proof;
- local-tile, BlueTopo, and FeatureInfo failure isolation;
- console and network output;
- browser timing, duplicate-request, interaction, and memory observations;
- keyboard, accessibility-tree, touch-target, attribution, and overflow checks;
- original BlueTopo POC regression;
- production helper/proxy/Route Builder checksum regression;
- final Git status and `git diff --check`.

## Disclaimer

The high-detail relief and BlueTopo layers are informational visualizations
derived from NOAA data. They do not represent current water depth and are not
intended for navigation. NOAA charted depths use a different vertical datum.
NOAA does not endorse or certify FloatPlanWizard. Boaters remain responsible for
using current official charts and notices, maintaining a proper lookout,
verifying conditions, and exercising prudent navigation.
