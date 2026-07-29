(function (window, document) {
  "use strict";

  var startedAt = window.performance && typeof window.performance.now === "function"
    ? window.performance.now()
    : Date.now();

  var CHART_LAYERS = "0,1,2,3,4,5,6,7,8,9,10,11,12";
  var CHART_OPACITY = 0.88;
  var BLUETOPO_TILE_SIZE = 512;
  var BLUETOPO_MAX_ZOOM = 20;
  var NATIVE_MIN_ZOOM = 14;
  var NATIVE_MAX_ZOOM = 17;
  var MAP_MAX_ZOOM = 18;
  var DEFAULT_MOBILE_BREAKPOINT = 920;
  var CHART_UNAVAILABLE_MESSAGE =
    "NOAA Chart Display is currently unavailable. Relief layers may still be shown, " +
    "but the official chart context is missing.";

  var BLUETOPO_ELEVATION_URL =
    "https://nowcoast.noaa.gov/geoserver/gwc/service/wmts/rest/" +
    "bluetopo:bathymetry/nbs_elevation/EPSG:3857/EPSG:3857:{z}/{y}/{x}" +
    "?format=image/png8";
  var BLUETOPO_HILLSHADE_URL =
    "https://nowcoast.noaa.gov/geoserver/gwc/service/wmts/rest/" +
    "bluetopo:hillshade/nbs_hillshade/EPSG:3857/EPSG:3857:{z}/{y}/{x}" +
    "?format=image/png8";
  var BLUETOPO_FEATURE_INFO_ROOT =
    "https://nowcoast.noaa.gov/geoserver/gwc/service/wmts/rest/" +
    "bluetopo:bathymetry/bluetopo:source_survey_id/EPSG:3857/";

  var APPROVED_CENTER = [27.7009075652856, -82.6200072680348];
  var APPROVED_BOUNDS = [
    [27.6917645274034, -82.6302800675715],
    [27.7100499393613, -82.6097361351387]
  ];

  /*
   * Geometry is disposable POC data, not member route data. The maintained-area
   * intersections were checked against NOAA's Coastal Maintained Channels layer:
   * GIWW west-to-east, then St. Petersburg Harbor Cut-A northbound.
   */
  var SAMPLE_ROUTE = [
    {
      label: "GIWW west approach",
      lat: 27.69578,
      lng: -82.62820,
      type: "start"
    },
    {
      label: "Gulf Intracoastal Waterway",
      lat: 27.69595,
      lng: -82.61920,
      type: "intermediate"
    },
    {
      label: "Cut-A junction",
      lat: 27.69635,
      lng: -82.61055,
      type: "intermediate"
    },
    {
      label: "St. Petersburg Harbor Cut-A",
      lat: 27.70625,
      lng: -82.61018,
      type: "end"
    }
  ];

  var state = {
    root: null,
    basePath: "",
    faultMode: "",
    focusMode: "",
    mode: "compare",
    layout: "",
    maps: {},
    bundles: {},
    mobileMedia: null,
    syncGuard: false,
    syncCount: 0,
    routeVisible: true,
    waypointsVisible: true,
    basemapVisible: false,
    chartHealthWarning: false,
    chartTileErrors: 0,
    blueTopoTileErrors: 0,
    nativeTileErrors: 0,
    routeErrors: 0,
    waypointErrors: 0,
    featureController: null,
    featureMarker: null,
    featureMarkerMapKey: "",
    manifest: null,
    manifestError: "",
    chartHealthPassed: false,
    chartTileFailures: {},
    nativeTileTemplate: "",
    manifestUrl: "",
    mobileBreakpoint: DEFAULT_MOBILE_BREAKPOINT,
    timings: {
      mapReadyMs: null,
      firstChartTileMs: null,
      chartVisibleConfirmedMs: null,
      firstBlueTopoTileMs: null,
      firstNativeTileMs: null,
      chartHealthMs: null,
      lastModeSwitchMs: null
    },
    currentModeStartedAt: null,
    rebuildTimer: null,
    initialTimeout: null
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function nowMs() {
    var current = window.performance && typeof window.performance.now === "function"
      ? window.performance.now()
      : Date.now();
    return Math.max(0, current - startedAt);
  }

  function normalizeBasePath(value) {
    var base = String(value || "").trim().replace(/\/+$/, "");
    if (base === "/") return "";
    if (base && base.charAt(0) !== "/") base = "/" + base;
    return base;
  }

  function normalizeLongitude(lng) {
    var numericLng = Number(lng);
    if (!Number.isFinite(numericLng)) return 0;
    return ((numericLng + 180) % 360 + 360) % 360 - 180;
  }

  function setText(id, value) {
    var element = byId(id);
    if (element) element.textContent = value;
  }

  function setChip(id, status, text) {
    var element = byId(id);
    if (!element) return;
    element.setAttribute("data-state", status);
    element.textContent = text;
  }

  function setWarning(prefix, message, visible) {
    var warning = byId(prefix);
    var text = byId(prefix + "-text");
    if (text && message) text.textContent = message;
    if (warning) warning.hidden = !visible;
  }

  function showFatal(message) {
    var fatal = byId("high-detail-poc-fatal-error");
    hideAllLoading();
    if (!fatal) return;
    fatal.textContent = message;
    fatal.hidden = false;
  }

  function showChartWarning(reason) {
    var message = CHART_UNAVAILABLE_MESSAGE;
    state.chartHealthWarning = true;
    if (reason) message += " " + reason;
    setChip("high-detail-poc-chart-status", "warning", "Unavailable");
    setWarning("high-detail-poc-chart-warning", message, true);
  }

  function showBlueTopoWarning(message) {
    setChip("high-detail-poc-bluetopo-status", "warning", "Partial or unavailable");
    setWarning(
      "high-detail-poc-bluetopo-warning",
      message + " Native relief, NOAA chart, route, waypoints, and controls remain independent.",
      true
    );
  }

  function nativeWarningMessage() {
    var bundle = firstBundle();
    var zoom = bundle && bundle.map ? bundle.map.getZoom() : NATIVE_MAX_ZOOM;

    if (state.manifestError) {
      return state.manifestError + " Static tiles will still be attempted independently.";
    }
    if (state.nativeTileErrors > 0) {
      return "One or more local native-relief tiles failed. BlueTopo fallback, NOAA chart, " +
        "route, waypoints, and controls remain available.";
    }
    if (bundle && bundle.map && modeUsesNative(state.mode) &&
        !bundle.map.getBounds().intersects(window.L.latLngBounds(APPROVED_BOUNDS))) {
      return "The current map view is outside the approved 2 km native-relief extent.";
    }
    if (bundle && bundle.map && modeUsesNative(state.mode) &&
        !window.L.latLngBounds(APPROVED_BOUNDS).contains(bundle.map.getBounds())) {
      return "The current view extends beyond the approved native-relief extent. " +
        "Transparent areas reveal BlueTopo only in fallback mode.";
    }
    return "";
  }

  function updateNativeWarning() {
    var message = nativeWarningMessage();
    var bundle = firstBundle();
    var zoom = bundle && bundle.map ? bundle.map.getZoom() : NATIVE_MAX_ZOOM;
    var zoomMessage = zoom > NATIVE_MAX_ZOOM && modeUsesNative(state.mode)
      ? "Native relief is digitally enlarged above zoom 17. No additional source " +
        "resolution or sub-metre accuracy is implied."
      : "";

    setText("high-detail-poc-zoom-warning", zoomMessage);
    if (byId("high-detail-poc-zoom-warning")) {
      byId("high-detail-poc-zoom-warning").hidden = !zoomMessage;
    }

    if (message) {
      setChip("high-detail-poc-native-status", "warning", "Limited");
      setWarning("high-detail-poc-native-warning", message, true);
      return;
    }

    setWarning("high-detail-poc-native-warning", "", false);
    if (state.timings.firstNativeTileMs !== null) {
      setChip("high-detail-poc-native-status", "ready", "Available");
    } else {
      setChip("high-detail-poc-native-status", "loading", "Loading…");
    }
  }

  function loadingIdFor(key) {
    return "high-detail-poc-" + key + "-loading";
  }

  function hideLoading(key) {
    var loading = byId(loadingIdFor(key));
    if (loading) loading.hidden = true;
  }

  function showLoading(key) {
    var loading = byId(loadingIdFor(key));
    if (loading) loading.hidden = false;
  }

  function markBundleRasterResult(bundle) {
    if (!bundle) return;
    bundle.hasRasterResult = true;
    if (bundle.ready) hideLoading(bundle.key);
  }

  function hideAllLoading() {
    ["left", "right", "mobile"].forEach(hideLoading);
  }

  function markTiming(name) {
    if (Object.prototype.hasOwnProperty.call(state.timings, name) &&
        state.timings[name] === null) {
      state.timings[name] = Math.round(nowMs());
    }
    updatePerformanceStatus();
  }

  function updatePerformanceStatus() {
    var parts = [];
    if (state.timings.mapReadyMs !== null) {
      parts.push("map " + state.timings.mapReadyMs + " ms");
    }
    if (state.timings.firstChartTileMs !== null) {
      parts.push("chart " + state.timings.firstChartTileMs + " ms");
    }
    if (state.timings.firstBlueTopoTileMs !== null) {
      parts.push("BlueTopo " + state.timings.firstBlueTopoTileMs + " ms");
    }
    if (state.timings.firstNativeTileMs !== null) {
      parts.push("native " + state.timings.firstNativeTileMs + " ms");
    }

    if (!parts.length) {
      setChip("high-detail-poc-performance-status", "loading", "Measuring…");
      return;
    }

    setChip(
      "high-detail-poc-performance-status",
      state.timings.mapReadyMs !== null ? "ready" : "loading",
      parts.join(" · ")
    );
  }

  function updateMapReady() {
    var bundles = bundleList();
    var expectedCount = state.layout === "desktop" ? 2 : 1;
    if (bundles.length !== expectedCount) return;
    if (bundles.every(function (bundle) { return bundle.ready; })) {
      markTiming("mapReadyMs");
      setChip(
        "high-detail-poc-sync-status",
        state.layout === "desktop" ? "ready" : "ready",
        state.layout === "desktop" ? "Aligned" : "Single-map mobile"
      );
    }
  }

  function modeUsesNative(mode) {
    return ["native", "native-chart", "native-fallback", "compare"].indexOf(mode) !== -1;
  }

  function modeUsesBlueTopo(mode) {
    return ["bluetopo", "bluetopo-chart", "native-fallback", "compare"].indexOf(mode) !== -1;
  }

  function modeLabel(mode) {
    var labels = {
      compare: "Side-by-side comparison",
      chart: "NOAA Chart only",
      bluetopo: "BlueTopo relief only",
      "bluetopo-chart": "BlueTopo with NOAA Chart",
      native: "Native 1 m relief only",
      "native-chart": "Native 1 m with NOAA Chart",
      "native-fallback": "Native 1 m, BlueTopo fallback, and NOAA Chart"
    };
    return labels[mode] || "Custom";
  }

  function setModeRadio(mode) {
    var radios = document.querySelectorAll('input[name="high-detail-poc-mode"]');
    Array.prototype.forEach.call(radios, function (radio) {
      radio.checked = radio.value === mode;
    });
  }

  function setModeStatus() {
    var text = modeLabel(state.mode);
    if (state.layout === "mobile" && state.mode === "compare") {
      text += " (native side shown; switch modes for A/B)";
    }
    setChip("high-detail-poc-mode-status", "ready", text);
    if (state.layout === "mobile") {
      setText("high-detail-poc-mobile-mode-label", text);
    }
  }

  function firstBundle() {
    var keys = Object.keys(state.bundles);
    return keys.length ? state.bundles[keys[0]] : null;
  }

  function bundleList() {
    return Object.keys(state.bundles).map(function (key) {
      return state.bundles[key];
    });
  }

  function setLayerVisible(bundle, layer, visible) {
    if (!bundle || !bundle.map || !layer) return;
    if (visible && !bundle.map.hasLayer(layer)) {
      bundle.map.addLayer(layer);
    } else if (!visible && bundle.map.hasLayer(layer)) {
      bundle.map.removeLayer(layer);
    }
  }

  function desiredLayers(bundle, mode) {
    var desired = {
      chart: false,
      blueTopo: false,
      native: false
    };

    if (mode === "compare") {
      if (state.layout === "mobile") {
        desired.chart = true;
        desired.native = true;
      } else if (bundle.key === "left") {
        desired.chart = true;
        desired.blueTopo = true;
      } else {
        desired.chart = true;
        desired.native = true;
      }
      return desired;
    }

    desired.chart = ["chart", "bluetopo-chart", "native-chart", "native-fallback"]
      .indexOf(mode) !== -1;
    desired.blueTopo = ["bluetopo", "bluetopo-chart", "native-fallback"]
      .indexOf(mode) !== -1;
    desired.native = ["native", "native-chart", "native-fallback"]
      .indexOf(mode) !== -1;
    return desired;
  }

  function applyOpacity(bundle, desired) {
    if (!bundle || !bundle.layers) return;

    bundle.layers.chart.setOpacity(
      desired.chart && !desired.blueTopo && !desired.native ? 1 : CHART_OPACITY
    );

    if (desired.chart) {
      bundle.layers.blueTopoElevation.setOpacity(0.56);
      bundle.layers.blueTopoHillshade.setOpacity(0.24);
      bundle.layers.native.setOpacity(
        state.mode === "native-fallback" ? 0.88 : 0.82
      );
    } else {
      bundle.layers.blueTopoElevation.setOpacity(0.84);
      bundle.layers.blueTopoHillshade.setOpacity(0.36);
      bundle.layers.native.setOpacity(0.96);
    }
  }

  function updateBundleSourceLabel(bundle, desired) {
    var label;
    var heading;
    if (desired.native && desired.blueTopo) {
      heading = "Native 1 m + BlueTopo fallback";
      label = "Native 1 m South Tampa relief · BlueTopo fallback";
    } else if (desired.native) {
      heading = "Native 1 m South Tampa relief";
      label = "Native 1 m South Tampa relief";
    } else if (desired.blueTopo) {
      heading = "NOAA BlueTopo";
      label = "NOAA BlueTopo relief";
    } else if (desired.chart) {
      heading = "NOAA Chart Display";
      label = "NOAA Chart Display";
    } else {
      heading = "Comparison map";
      label = "No primary source selected";
    }
    if (desired.chart && (desired.native || desired.blueTopo)) {
      label += " · NOAA Chart overlay";
    }
    setText("high-detail-poc-" + bundle.key + "-heading", heading);
    setText("high-detail-poc-" + bundle.key + "-mode-label", label);

    var mapContainer = byId("high-detail-poc-" + bundle.key + "-map");
    if (mapContainer) {
      mapContainer.setAttribute(
        "aria-label",
        (bundle.key === "mobile" ? "Responsive" : (
          bundle.key === "left" ? "Left synchronized" : "Right synchronized"
        )) +
          " map showing " + label +
          " with an illustrative planning route and waypoints"
      );
    }
  }

  function applyMode(mode) {
    var validModes = [
      "compare",
      "chart",
      "bluetopo",
      "bluetopo-chart",
      "native",
      "native-chart",
      "native-fallback"
    ];
    if (validModes.indexOf(mode) === -1) return;

    var modeStartedAt = nowMs();
    state.mode = mode;
    state.currentModeStartedAt = modeStartedAt;

    bundleList().forEach(function (bundle) {
      var desired = desiredLayers(bundle, mode);
      setLayerVisible(bundle, bundle.layers.blueTopoGroup, desired.blueTopo);
      setLayerVisible(bundle, bundle.layers.native, desired.native);
      setLayerVisible(bundle, bundle.layers.chart, desired.chart);
      applyOpacity(bundle, desired);
      updateBundleSourceLabel(bundle, desired);
    });

    setModeRadio(mode);
    setModeStatus();
    updateNativeWarning();

    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(function () {
        if (state.currentModeStartedAt === modeStartedAt) {
          state.timings.lastModeSwitchMs = Math.round(nowMs() - modeStartedAt);
        }
      });
    });
  }

  function applyOverlayVisibility() {
    bundleList().forEach(function (bundle) {
      setLayerVisible(bundle, bundle.layers.route, state.routeVisible);
      setLayerVisible(bundle, bundle.layers.waypoints, state.waypointsVisible);
      setLayerVisible(bundle, bundle.layers.neutral, state.basemapVisible);
    });
  }

  function bindControls() {
    var radios = document.querySelectorAll('input[name="high-detail-poc-mode"]');
    var routeToggle = byId("high-detail-poc-route-toggle");
    var waypointToggle = byId("high-detail-poc-waypoint-toggle");
    var basemapToggle = byId("high-detail-poc-basemap-toggle");

    Array.prototype.forEach.call(radios, function (radio) {
      radio.addEventListener("change", function () {
        if (radio.checked) applyMode(radio.value);
      });
    });

    if (routeToggle) {
      state.routeVisible = routeToggle.checked;
      routeToggle.addEventListener("change", function () {
        state.routeVisible = routeToggle.checked;
        applyOverlayVisibility();
      });
    }

    if (waypointToggle) {
      state.waypointsVisible = waypointToggle.checked;
      waypointToggle.addEventListener("change", function () {
        state.waypointsVisible = waypointToggle.checked;
        applyOverlayVisibility();
      });
    }

    if (basemapToggle) {
      state.basemapVisible = basemapToggle.checked;
      basemapToggle.addEventListener("change", function () {
        state.basemapVisible = basemapToggle.checked;
        applyOverlayVisibility();
      });
    }
  }

  function makeWaypointIcon(point, index) {
    var className = "high-detail-poc-waypoint-pin";
    if (point.type === "start") className += " high-detail-poc-waypoint-pin--start";
    if (point.type === "end") className += " high-detail-poc-waypoint-pin--end";

    return window.L.divIcon({
      className: "high-detail-poc-waypoint-icon",
      html: '<span class="' + className + '">' + String(index + 1) + "</span>",
      iconSize: [26, 26],
      iconAnchor: [13, 13],
      popupAnchor: [0, -15],
      tooltipAnchor: [0, -15]
    });
  }

  function routeCoordinates() {
    return SAMPLE_ROUTE.map(function (point) {
      return [point.lat, point.lng];
    });
  }

  function buildRouteLayer() {
    var coordinates = routeCoordinates();
    var routeGroup = window.L.layerGroup();

    window.L.polyline(coordinates, {
      pane: "highDetailPocRoutePane",
      color: "#ffffff",
      weight: 9,
      opacity: 0.82,
      lineJoin: "round",
      lineCap: "round",
      interactive: false
    }).addTo(routeGroup);

    window.L.polyline(coordinates, {
      pane: "highDetailPocRoutePane",
      color: "#5ab3ff",
      weight: 5,
      opacity: 0.98,
      lineJoin: "round",
      lineCap: "round",
      keyboard: true
    })
      .bindPopup(
        "<strong>Illustrative planning route — not a validated safe route</strong><br>" +
        "Disposable POC geometry through NOAA-maintained-area context. Not for navigation."
      )
      .addTo(routeGroup);

    return routeGroup;
  }

  function buildWaypointLayer() {
    var waypointGroup = window.L.layerGroup();

    SAMPLE_ROUTE.forEach(function (point, index) {
      var typeLabel = point.type === "start"
        ? "Start"
        : (point.type === "end" ? "End" : "Waypoint");
      var marker = window.L.marker([point.lat, point.lng], {
        pane: "highDetailPocWaypointPane",
        icon: makeWaypointIcon(point, index),
        keyboard: true,
        title: typeLabel + ": " + point.label
      });

      marker.bindTooltip(typeLabel + ": " + point.label, {
        direction: "top",
        opacity: 0.96
      });
      marker.bindPopup(
        "<strong>" + typeLabel + ": " + point.label + "</strong><br>" +
        "Illustrative planning route — not a validated safe route."
      );
      marker.addTo(waypointGroup);
    });

    return waypointGroup;
  }

  function maybeMarkVisibleChart() {
    if (state.chartHealthPassed && state.timings.firstChartTileMs !== null) {
      markTiming("chartVisibleConfirmedMs");
    }
  }

  function trackChartLayer(layer, bundle) {
    layer.on("loading", function () {
      if (!state.chartHealthWarning) {
        setChip("high-detail-poc-chart-status", "loading", "Loading…");
      }
    });
    layer.on("tileload", function () {
      markTiming("firstChartTileMs");
      maybeMarkVisibleChart();
      markBundleRasterResult(bundle);
    });
    layer.on("load", function () {
      if (!state.chartHealthWarning) {
        setChip(
          "high-detail-poc-chart-status",
          state.chartTileErrors > 0 ? "warning" : "ready",
          state.chartTileErrors > 0 ? "Partial tile failure" : "Available"
        );
      }
    });
    layer.on("tileerror", function (event) {
      var url = event && event.tile ? String(event.tile.src || "") : "";
      state.chartTileErrors += 1;
      state.chartTileFailures[url || ("unknown-" + state.chartTileErrors)] = true;
      markBundleRasterResult(bundle);
      setChip("high-detail-poc-chart-status", "warning", "Partial tile failure");
      setWarning(
        "high-detail-poc-chart-warning",
        "One or more NOAA chart tiles failed. Relief is not authoritative chart " +
          "context; independent chart health verification remains active.",
        true
      );
    });
  }

  function trackBlueTopoLayer(layer, isPrimary, bundle) {
    layer.on("loading", function () {
      if (!state.blueTopoTileErrors) {
        setChip("high-detail-poc-bluetopo-status", "loading", "Loading…");
      }
    });
    layer.on("tileload", function () {
      if (isPrimary) markTiming("firstBlueTopoTileMs");
      markBundleRasterResult(bundle);
    });
    layer.on("load", function () {
      if (!state.blueTopoTileErrors && state.timings.firstBlueTopoTileMs !== null) {
        setChip("high-detail-poc-bluetopo-status", "ready", "Available");
      }
    });
    layer.on("tileerror", function () {
      state.blueTopoTileErrors += 1;
      markBundleRasterResult(bundle);
      showBlueTopoWarning("One or more NOAA BlueTopo tiles failed to load.");
    });
  }

  function trackNativeLayer(layer, bundle) {
    layer.on("loading", function () {
      if (!state.nativeTileErrors) {
        setChip("high-detail-poc-native-status", "loading", "Loading…");
      }
    });
    layer.on("tileload", function () {
      markTiming("firstNativeTileMs");
      markBundleRasterResult(bundle);
      updateNativeWarning();
    });
    layer.on("load", updateNativeWarning);
    layer.on("tileerror", function () {
      state.nativeTileErrors += 1;
      markBundleRasterResult(bundle);
      updateNativeWarning();
    });
  }

  function createPanes(map) {
    [
      ["highDetailPocNeutralPane", "200"],
      ["highDetailPocBlueTopoPane", "280"],
      ["highDetailPocBlueTopoShadePane", "290"],
      ["highDetailPocNativePane", "320"],
      ["highDetailPocChartPane", "430"],
      ["highDetailPocRoutePane", "620"],
      ["highDetailPocWaypointPane", "640"],
      ["highDetailPocInspectPane", "660"]
    ].forEach(function (entry) {
      map.createPane(entry[0]);
      map.getPane(entry[0]).style.zIndex = entry[1];
    });
  }

  function createBundle(key, view) {
    var chartProxyUrl = state.basePath +
      "/api/v1/wmsProxy.cfc?method=tile&target=noaa-charts";
    var nativeTileUrl = state.faultMode === "native"
      ? state.basePath + "/assets/maps/poc/__forced_missing_native__/{z}/{x}/{y}.png"
      : (
        state.nativeTileTemplate || (
          state.basePath +
          "/assets/maps/poc/south-tampa-high-detail/{z}/{x}/{y}.png"
        )
      );
    var blueTopoElevationUrl = state.faultMode === "bluetopo"
      ? state.basePath + "/assets/maps/poc/__forced_missing_bluetopo__/{z}/{x}/{y}.png"
      : BLUETOPO_ELEVATION_URL;
    var blueTopoHillshadeUrl = state.faultMode === "bluetopo"
      ? state.basePath + "/assets/maps/poc/__forced_missing_bluetopo_shade__/{z}/{x}/{y}.png"
      : BLUETOPO_HILLSHADE_URL;
    var map = window.L.map("high-detail-poc-" + key + "-map", {
      center: view.center,
      zoom: view.zoom,
      minZoom: NATIVE_MIN_ZOOM,
      maxZoom: MAP_MAX_ZOOM,
      zoomControl: true,
      preferCanvas: true
    });
    var bundle;

    createPanes(map);

    bundle = {
      key: key,
      map: map,
      ready: false,
      hasRasterResult: false,
      layers: {}
    };

    state.maps[key] = map;
    state.bundles[key] = bundle;
    showLoading(key);

    bundle.layers.neutral = window.L.tileLayer(
      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      {
        pane: "highDetailPocNeutralPane",
        minZoom: NATIVE_MIN_ZOOM,
        maxZoom: 19,
        crossOrigin: true,
        updateWhenIdle: true,
        keepBuffer: 1,
        attribution: "&copy; OpenStreetMap contributors (debug reference only)"
      }
    );

    bundle.layers.blueTopoElevation = window.L.tileLayer(blueTopoElevationUrl, {
      pane: "highDetailPocBlueTopoPane",
      minZoom: NATIVE_MIN_ZOOM,
      maxZoom: BLUETOPO_MAX_ZOOM,
      maxNativeZoom: BLUETOPO_MAX_ZOOM,
      opacity: 0.48,
      crossOrigin: true,
      updateWhenIdle: true,
      keepBuffer: 1,
      attribution: "NOAA Office of Coast Survey BlueTopo via nowCOAST"
    });

    bundle.layers.blueTopoHillshade = window.L.tileLayer(blueTopoHillshadeUrl, {
      pane: "highDetailPocBlueTopoShadePane",
      minZoom: NATIVE_MIN_ZOOM,
      maxZoom: BLUETOPO_MAX_ZOOM,
      maxNativeZoom: BLUETOPO_MAX_ZOOM,
      opacity: 0.22,
      crossOrigin: true,
      updateWhenIdle: true,
      keepBuffer: 1,
      attribution: "NOAA BlueTopo hillshade via nowCOAST"
    });

    bundle.layers.blueTopoGroup = window.L.layerGroup([
      bundle.layers.blueTopoElevation,
      bundle.layers.blueTopoHillshade
    ]);

    bundle.layers.native = window.L.tileLayer(nativeTileUrl, {
      pane: "highDetailPocNativePane",
      bounds: window.L.latLngBounds(APPROVED_BOUNDS),
      minZoom: NATIVE_MIN_ZOOM,
      maxZoom: MAP_MAX_ZOOM,
      maxNativeZoom: NATIVE_MAX_ZOOM,
      opacity: 0.72,
      noWrap: true,
      updateWhenIdle: true,
      keepBuffer: 1,
      attribution: "NOAA NGS 2021 Southern Tampa Bay Topobathy DEM"
    });

    bundle.layers.chart = window.L.tileLayer.wms(chartProxyUrl, {
      pane: "highDetailPocChartPane",
      layers: CHART_LAYERS,
      styles: "",
      format: "image/png",
      transparent: true,
      version: "1.3.0",
      opacity: CHART_OPACITY,
      minZoom: NATIVE_MIN_ZOOM,
      maxZoom: MAP_MAX_ZOOM,
      updateWhenIdle: true,
      keepBuffer: 1,
      attribution: "NOAA Office of Coast Survey Chart Display Service"
    });

    try {
      if (state.faultMode === "route") {
        throw new Error("Isolated route validation fault.");
      }
      bundle.layers.route = buildRouteLayer();
      setChip("high-detail-poc-route-status", "ready", "Available");
    } catch (error) {
      state.routeErrors += 1;
      bundle.layers.route = window.L.layerGroup();
      setChip("high-detail-poc-route-status", "warning", "Unavailable");
    }

    try {
      if (state.faultMode === "waypoints") {
        throw new Error("Isolated waypoint validation fault.");
      }
      bundle.layers.waypoints = buildWaypointLayer();
      setChip("high-detail-poc-waypoint-status", "ready", "Available");
    } catch (error) {
      state.waypointErrors += 1;
      bundle.layers.waypoints = window.L.layerGroup();
      setChip("high-detail-poc-waypoint-status", "warning", "Unavailable");
    }

    trackChartLayer(bundle.layers.chart, bundle);
    trackBlueTopoLayer(bundle.layers.blueTopoElevation, true, bundle);
    trackBlueTopoLayer(bundle.layers.blueTopoHillshade, false, bundle);
    trackNativeLayer(bundle.layers.native, bundle);

    window.L.control.scale({
      imperial: true,
      metric: true,
      maxWidth: 130
    }).addTo(map);

    map.on("click", function (event) {
      /*
       * FeatureInfo is deliberately independent: its promise is never awaited
       * by layer, route, waypoint, synchronization, or mode-switch operations.
       */
      inspectBlueTopo(event.latlng, bundle);
    });

    map.on("zoomend moveend", updateNativeWarning);
    map.whenReady(function () {
      bundle.ready = true;
      if (bundle.hasRasterResult) hideLoading(key);
      window.setTimeout(function () {
        if (bundle.map) bundle.map.invalidateSize(false);
      }, 0);
      updateMapReady();
    });

    return bundle;
  }

  function centersEqual(first, second) {
    return Math.abs(first.lat - second.lat) < 0.0000001 &&
      Math.abs(normalizeLongitude(first.lng) - normalizeLongitude(second.lng)) < 0.0000001;
  }

  function bindDesktopSynchronization(left, right) {
    function mirror(source, target) {
      var sourceCenter;
      var targetCenter;
      var sourceZoom;

      if (state.syncGuard || !source || !target) return;
      sourceCenter = source.getCenter();
      targetCenter = target.getCenter();
      sourceZoom = source.getZoom();

      if (sourceZoom === target.getZoom() && centersEqual(sourceCenter, targetCenter)) {
        return;
      }

      state.syncGuard = true;
      state.syncCount += 1;
      target.setView(sourceCenter, sourceZoom, {
        animate: false,
        reset: false
      });
      state.syncGuard = false;
      setChip("high-detail-poc-sync-status", "ready", "Aligned");
    }

    left.on("move", function () { mirror(left, right); });
    right.on("move", function () { mirror(right, left); });
  }

  function currentView() {
    var bundle = firstBundle();
    if (!bundle || !bundle.map) {
      return {
        center: state.focusMode === "nodata"
          ? [27.708773212265893, -82.6219242811203]
          : APPROVED_CENTER,
        zoom: state.focusMode === "nodata" ? 18 : 16
      };
    }
    return {
      center: bundle.map.getCenter(),
      zoom: bundle.map.getZoom()
    };
  }

  function destroyMaps() {
    if (state.featureController) {
      state.featureController.abort();
      state.featureController = null;
    }
    state.featureMarker = null;
    state.featureMarkerMapKey = "";

    bundleList().forEach(function (bundle) {
      if (bundle.map) {
        bundle.map.off();
        bundle.map.remove();
      }
      var container = byId("high-detail-poc-" + bundle.key + "-map");
      if (container) container.innerHTML = "";
    });

    state.maps = {};
    state.bundles = {};
    state.syncGuard = false;
  }

  function setWorkspaceVisibility(layout) {
    var desktop = byId("high-detail-poc-desktop-workspace");
    var mobile = byId("high-detail-poc-mobile-workspace");
    if (desktop) desktop.hidden = layout !== "desktop";
    if (mobile) mobile.hidden = layout !== "mobile";
  }

  function rebuildMaps(force) {
    var nextLayout = state.mobileMedia && state.mobileMedia.matches
      ? "mobile"
      : "desktop";
    var view = currentView();
    var left;
    var right;

    if (!force && state.layout === nextLayout) {
      bundleList().forEach(function (bundle) {
        bundle.map.invalidateSize(false);
      });
      return;
    }

    destroyMaps();
    state.layout = nextLayout;
    setWorkspaceVisibility(nextLayout);

    if (nextLayout === "mobile") {
      createBundle("mobile", view);
    } else {
      left = createBundle("left", view);
      right = createBundle("right", view);
      bindDesktopSynchronization(left.map, right.map);
    }

    applyMode(state.mode);
    applyOverlayVisibility();
  }

  function queueLayoutCheck() {
    window.clearTimeout(state.rebuildTimer);
    state.rebuildTimer = window.setTimeout(function () {
      try {
        rebuildMaps(false);
      } catch (error) {
        showFatal(
          "The responsive map layout could not be rebuilt" +
          (error && error.message ? ": " + error.message : ".")
        );
      }
    }, 120);
  }

  function projectWebMercator(lng, lat) {
    var originShift = 20037508.342789244;
    var boundedLat = Math.max(-85.05112878, Math.min(85.05112878, lat));
    var x = lng * originShift / 180;
    var y = Math.log(Math.tan((90 + boundedLat) * Math.PI / 360)) /
      (Math.PI / 180);
    y = y * originShift / 180;
    return { x: x, y: y };
  }

  function imageIsTransparent(blob) {
    return new Promise(function (resolve, reject) {
      var image = new Image();
      var objectUrl = window.URL.createObjectURL(blob);

      function cleanup() {
        window.URL.revokeObjectURL(objectUrl);
      }

      image.onload = function () {
        var canvas;
        var context;
        var data;
        var index;
        var visible = false;

        try {
          canvas = document.createElement("canvas");
          canvas.width = Math.max(1, Math.min(64, image.naturalWidth || 1));
          canvas.height = Math.max(1, Math.min(64, image.naturalHeight || 1));
          context = canvas.getContext("2d", { willReadFrequently: true });
          context.drawImage(image, 0, 0, canvas.width, canvas.height);
          data = context.getImageData(0, 0, canvas.width, canvas.height).data;

          for (index = 3; index < data.length; index += 4) {
            if (data[index] > 0) {
              visible = true;
              break;
            }
          }

          cleanup();
          resolve(!visible);
        } catch (error) {
          cleanup();
          reject(error);
        }
      };

      image.onerror = function () {
        cleanup();
        reject(new Error("The chart health image could not be decoded."));
      };
      image.src = objectUrl;
    });
  }

  function chartHealthUrl() {
    var southwest = projectWebMercator(
      APPROVED_BOUNDS[0][1],
      APPROVED_BOUNDS[0][0]
    );
    var northeast = projectWebMercator(
      APPROVED_BOUNDS[1][1],
      APPROVED_BOUNDS[1][0]
    );
    var params = new URLSearchParams();

    if (state.faultMode === "chart-transparent") {
      southwest = { x: -20037508.0, y: -20037508.0 };
      northeast = { x: -20037008.0, y: -20037008.0 };
    }
    northeast.x += (Date.now() % 100000) / 10000;
    params.set("method", "tile");
    params.set("target", "noaa-charts");
    params.set("SERVICE", "WMS");
    params.set("REQUEST", "GetMap");
    params.set("VERSION", "1.3.0");
    params.set("LAYERS", CHART_LAYERS);
    params.set("STYLES", "");
    params.set("FORMAT", "image/png");
    params.set("TRANSPARENT", "TRUE");
    params.set("CRS", "EPSG:3857");
    params.set(
      "BBOX",
      [
        southwest.x.toFixed(3),
        southwest.y.toFixed(3),
        northeast.x.toFixed(3),
        northeast.y.toFixed(3)
      ].join(",")
    );
    params.set("WIDTH", "64");
    params.set("HEIGHT", "64");
    params.set("debug", "1");

    return state.basePath + "/api/v1/wmsProxy.cfc?" + params.toString();
  }

  function runChartHealthCheck() {
    var controller = typeof window.AbortController === "function"
      ? new window.AbortController()
      : null;
    var timeoutId = window.setTimeout(function () {
      if (controller) controller.abort();
    }, 12000);
    var options = {
      method: "GET",
      credentials: "same-origin",
      cache: "no-store",
      headers: {
        "Accept": "image/png,application/json"
      }
    };

    if (controller) options.signal = controller.signal;

    window.fetch(chartHealthUrl(), options)
      .then(function (response) {
        var diagnostic = String(response.headers.get("X-FPW-WMSProxy") || "");
        var contentType = String(response.headers.get("Content-Type") || "").toLowerCase();

        if (!response.ok) {
          throw new Error("Chart health request returned HTTP " + response.status + ".");
        }
        if (diagnostic.toLowerCase().indexOf("fallback") === 0) {
          return {
            unavailable: true,
            reason: "The chart proxy reported " + diagnostic + "."
          };
        }
        if (contentType.indexOf("json") !== -1) {
          return response.json().then(function (payload) {
            return {
              unavailable: !payload || payload.success === false,
              reason: payload && payload.message
                ? payload.message
                : "The chart proxy returned a non-image fallback."
            };
          });
        }
        return response.blob().then(function (blob) {
          return imageIsTransparent(blob).then(function (transparent) {
            return {
              unavailable: transparent,
              reason: transparent
                ? "The health probe returned a fully transparent image despite an HTTP response."
                : ""
            };
          });
        });
      })
      .then(function (result) {
        window.clearTimeout(timeoutId);
        state.timings.chartHealthMs = Math.round(nowMs());
        if (result.unavailable) {
          showChartWarning(result.reason);
        } else if (!state.chartHealthWarning) {
          state.chartHealthPassed = true;
          maybeMarkVisibleChart();
          setChip(
            "high-detail-poc-chart-status",
            state.timings.firstChartTileMs === null
              ? "loading"
              : (state.chartTileErrors > 0 ? "warning" : "ready"),
            state.timings.firstChartTileMs === null
              ? "Loading…"
              : (state.chartTileErrors > 0 ? "Partial tile failure" : "Available")
          );
        }
      })
      .catch(function (error) {
        window.clearTimeout(timeoutId);
        state.timings.chartHealthMs = Math.round(nowMs());
        showChartWarning(
          "The independent chart health check could not be confirmed" +
          (error && error.message ? ": " + error.message : ".")
        );
      });
  }

  function tileCoordinates(lat, lng, zoom) {
    var z = Math.max(0, Math.min(BLUETOPO_MAX_ZOOM, Math.round(zoom)));
    var boundedLat = Math.max(-85.05112878, Math.min(85.05112878, lat));
    var normalizedLng = normalizeLongitude(lng);
    var latitudeRadians = boundedLat * Math.PI / 180;
    var scale = Math.pow(2, z);
    var x = (normalizedLng + 180) / 360 * scale;
    var y = (
      1 -
      Math.log(Math.tan(latitudeRadians) + (1 / Math.cos(latitudeRadians))) / Math.PI
    ) / 2 * scale;
    var column = Math.floor(x);
    var row = Math.floor(y);

    return {
      zoom: z,
      column: column,
      row: row,
      pixelX: Math.max(0, Math.min(
        BLUETOPO_TILE_SIZE - 1,
        Math.floor((x - column) * BLUETOPO_TILE_SIZE)
      )),
      pixelY: Math.max(0, Math.min(
        BLUETOPO_TILE_SIZE - 1,
        Math.floor((y - row) * BLUETOPO_TILE_SIZE)
      ))
    };
  }

  function featureInfoUrl(latlng, zoom) {
    var tile = tileCoordinates(latlng.lat, latlng.lng, zoom);
    return BLUETOPO_FEATURE_INFO_ROOT +
      "EPSG:3857:" + String(tile.zoom) + "/" +
      String(tile.row) + "/" +
      String(tile.column) + "/" +
      String(tile.pixelY) + "/" +
      String(tile.pixelX) +
      "?format=application/json";
  }

  function propertyValue(properties, names) {
    var keys = Object.keys(properties || {});
    var nameIndex;
    var keyIndex;
    for (nameIndex = 0; nameIndex < names.length; nameIndex += 1) {
      for (keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
        if (String(keys[keyIndex]).toLowerCase() ===
            String(names[nameIndex]).toLowerCase()) {
          return properties[keys[keyIndex]];
        }
      }
    }
    return null;
  }

  function finiteNumber(value) {
    if (value === null || typeof value === "undefined" ||
        (typeof value === "string" && !value.trim())) {
      return null;
    }
    var numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
  }

  function coverageLabel(value) {
    if (value === true || value === 1 || value === "1") {
      return "Measured bathymetry (bathy_coverage = true)";
    }
    if (value === false || value === 0 || value === "0") {
      return "Interpolated bathymetry (bathy_coverage = false)";
    }
    return "Not reported";
  }

  function formatSurveyDate(start, end) {
    var cleanStart = String(start || "").trim();
    var cleanEnd = String(end || "").trim();
    if (cleanStart && cleanEnd && cleanStart !== cleanEnd) {
      return cleanStart + " to " + cleanEnd;
    }
    return cleanEnd || cleanStart || "Not reported";
  }

  function setInspectMessage(message, isError) {
    var element = byId("high-detail-poc-inspect-message");
    if (!element) return;
    element.textContent = message;
    element.setAttribute("data-state", isError ? "error" : "ready");
  }

  function resetInspectDetails() {
    [
      "high-detail-poc-inspect-elevation",
      "high-detail-poc-inspect-uncertainty",
      "high-detail-poc-inspect-coverage",
      "high-detail-poc-inspect-source",
      "high-detail-poc-inspect-survey-date",
      "high-detail-poc-inspect-institution"
    ].forEach(function (id) {
      setText(id, "—");
    });
  }

  function renderFeatureInfo(latlng, properties) {
    var elevation = finiteNumber(propertyValue(properties, ["ELEVATION"]));
    var uncertainty = finiteNumber(propertyValue(properties, ["UNCERTAINTY"]));
    var coverage = propertyValue(properties, ["bathy_coverage"]);
    var source = propertyValue(properties, ["source_survey_id"]);
    var institution = propertyValue(properties, ["source_institution"]);
    var surveyStart = propertyValue(properties, ["survey_date_start"]);
    var surveyEnd = propertyValue(properties, ["survey_date_end"]);

    setText(
      "high-detail-poc-inspect-location",
      latlng.lat.toFixed(5) + ", " + latlng.lng.toFixed(5)
    );
    setText(
      "high-detail-poc-inspect-elevation",
      elevation === null
        ? "Not reported"
        : elevation.toFixed(2) + " m — bathymetric elevation relative to NAVD88"
    );
    setText(
      "high-detail-poc-inspect-uncertainty",
      uncertainty === null ? "Not reported" : uncertainty.toFixed(2) + " m"
    );
    setText("high-detail-poc-inspect-coverage", coverageLabel(coverage));
    setText("high-detail-poc-inspect-source", String(source || "Not reported"));
    setText(
      "high-detail-poc-inspect-survey-date",
      formatSurveyDate(surveyStart, surveyEnd)
    );
    setText(
      "high-detail-poc-inspect-institution",
      String(institution || "Not reported")
    );
    setChip("high-detail-poc-inspect-status", "ready", "Data returned");
    setInspectMessage(
      "BlueTopo metadata returned independently. The native display is not queried " +
      "and no elevation is estimated from its colors.",
      false
    );
  }

  function setInspectionMarker(latlng, bundle) {
    var icon;
    if (!bundle || !bundle.map) return;

    if (state.featureMarker && state.featureMarkerMapKey !== bundle.key) {
      var oldBundle = state.bundles[state.featureMarkerMapKey];
      if (oldBundle && oldBundle.map.hasLayer(state.featureMarker)) {
        oldBundle.map.removeLayer(state.featureMarker);
      }
      state.featureMarker = null;
    }

    if (!state.featureMarker) {
      icon = window.L.divIcon({
        className: "high-detail-poc-inspect-icon",
        html: '<span class="high-detail-poc-inspect-dot"></span>',
        iconSize: [16, 16],
        iconAnchor: [8, 8]
      });
      state.featureMarker = window.L.marker(latlng, {
        pane: "highDetailPocInspectPane",
        icon: icon,
        keyboard: false,
        interactive: false
      }).addTo(bundle.map);
      state.featureMarkerMapKey = bundle.key;
      return;
    }
    state.featureMarker.setLatLng(latlng);
  }

  function inspectBlueTopo(latlng, bundle) {
    var controller;
    var timeoutId;
    var query;
    var options = {
      method: "GET",
      mode: "cors",
      credentials: "omit",
      cache: "no-store",
      headers: {
        "Accept": "application/json"
      }
    };

    if (!latlng || !bundle || !bundle.map) return;
    query = {
      lat: latlng.lat,
      lng: normalizeLongitude(latlng.lng)
    };

    if (state.featureController) state.featureController.abort();
    controller = typeof window.AbortController === "function"
      ? new window.AbortController()
      : null;
    state.featureController = controller;
    if (controller) options.signal = controller.signal;

    timeoutId = window.setTimeout(function () {
      if (controller) controller.abort();
    }, 12000);

    var request;
    try {
      setInspectionMarker(latlng, bundle);
      resetInspectDetails();
      setText(
        "high-detail-poc-inspect-location",
        query.lat.toFixed(5) + ", " + query.lng.toFixed(5)
      );
      setChip("high-detail-poc-inspect-status", "loading", "Querying…");
      setInspectMessage(
        "Requesting BlueTopo FeatureInfo. Native relief remains a static visualization.",
        false
      );
      request = state.faultMode === "featureinfo"
        ? Promise.reject(new Error("Isolated FeatureInfo validation fault."))
        : window.fetch(featureInfoUrl(query, bundle.map.getZoom()), options);
    } catch (error) {
      window.clearTimeout(timeoutId);
      if (state.featureController === controller) state.featureController = null;
      setChip("high-detail-poc-inspect-status", "error", "Unavailable");
      setInspectMessage(
        (error && error.message ? error.message : "BlueTopo FeatureInfo failed.") +
          " All map functions remain available.",
        true
      );
      return;
    }

    request
      .then(function (response) {
        if (!response.ok) {
          throw new Error("NOAA FeatureInfo returned HTTP " + response.status + ".");
        }
        return response.json();
      })
      .then(function (payload) {
        var features = payload && Array.isArray(payload.features)
          ? payload.features
          : [];
        window.clearTimeout(timeoutId);
        if (!features.length || !features[0] || !features[0].properties) {
          throw new Error("No BlueTopo source metadata is available at this location.");
        }
        renderFeatureInfo(query, features[0].properties);
      })
      .catch(function (error) {
        window.clearTimeout(timeoutId);
        if (error && error.name === "AbortError" &&
            state.featureController !== controller) {
          return;
        }
        setChip("high-detail-poc-inspect-status", "error", "Unavailable");
        setInspectMessage(
          (error && error.name === "AbortError")
            ? "The BlueTopo FeatureInfo request timed out. All map functions remain available."
            : (
              (error && error.message ? error.message : "BlueTopo FeatureInfo failed.") +
              " All map functions remain available."
            ),
          true
        );
      })
      .finally(function () {
        if (state.featureController === controller) {
          state.featureController = null;
        }
      });
  }

  function loadManifest() {
    var url = state.manifestUrl || (
      state.basePath +
      "/assets/maps/poc/south-tampa-high-detail/manifest.json"
    );
    window.fetch(url, {
      method: "GET",
      credentials: "same-origin",
      cache: "no-store",
      headers: {
        "Accept": "application/json"
      }
    })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Native tile manifest returned HTTP " + response.status + ".");
        }
        return response.json();
      })
      .then(function (manifest) {
        state.manifest = manifest;
        state.manifestError = "";
        setText(
          "high-detail-poc-processing-date",
          String(
            manifest.processing_date_utc ||
            manifest.generated_at_utc ||
            manifest.processing_utc ||
            (manifest.processing && manifest.processing.generated_at_utc) ||
            "Not reported"
          )
        );
      })
      .catch(function (error) {
        state.manifestError = error && error.message
          ? error.message
          : "Native tile metadata is unavailable.";
        updateNativeWarning();
      });
  }

  function diagnosticsSnapshot() {
    var maps = {};
    bundleList().forEach(function (bundle) {
      var desired = desiredLayers(bundle, state.mode);
      maps[bundle.key] = {
        center: bundle.map.getCenter(),
        zoom: bundle.map.getZoom(),
        chart: bundle.map.hasLayer(bundle.layers.chart),
        blueTopo: bundle.map.hasLayer(bundle.layers.blueTopoGroup),
        native: bundle.map.hasLayer(bundle.layers.native),
        route: bundle.map.hasLayer(bundle.layers.route),
        waypoints: bundle.map.hasLayer(bundle.layers.waypoints),
        neutral: bundle.map.hasLayer(bundle.layers.neutral),
        intended: desired
      };
    });

    return {
      layout: state.layout,
      mode: state.mode,
      maps: maps,
      syncCount: state.syncCount,
      syncGuard: state.syncGuard,
      opacities: {
        chartOnly: 1,
        chartCombined: CHART_OPACITY,
        blueTopoWithChart: {
          elevation: 0.56,
          hillshade: 0.24
        },
        nativeWithChart: 0.82,
        nativeFallback: 0.88,
        nativeOnly: 0.96
      },
      timings: Object.assign({}, state.timings),
      errors: {
        chartTiles: state.chartTileErrors,
        blueTopoTiles: state.blueTopoTileErrors,
        nativeTiles: state.nativeTileErrors,
        route: state.routeErrors,
        waypoints: state.waypointErrors
      },
      chartHealthWarning: state.chartHealthWarning,
      manifest: state.manifest
    };
  }

  function initialize() {
    state.root = byId("high-detail-poc-root");
    if (!state.root) return;

    state.basePath = normalizeBasePath(
      state.root.getAttribute("data-fpw-base") ||
      (Object.prototype.hasOwnProperty.call(window, "FPW_BASE")
        ? window.FPW_BASE
        : "")
    );
    state.faultMode = String(
      state.root.getAttribute("data-poc-fault") || ""
    ).toLowerCase();
    state.focusMode = String(
      state.root.getAttribute("data-poc-focus") || ""
    ).toLowerCase();
    state.nativeTileTemplate = String(
      state.root.getAttribute("data-native-tile-template") || ""
    );
    state.manifestUrl = String(
      state.root.getAttribute("data-native-manifest-url") || ""
    );
    var configuredBreakpoint = Number(
      state.root.getAttribute("data-mobile-breakpoint")
    );
    if (Number.isFinite(configuredBreakpoint) &&
        configuredBreakpoint >= 480 &&
        configuredBreakpoint <= 1600) {
      state.mobileBreakpoint = configuredBreakpoint;
    }

    if (state.faultMode === "map-init") {
      showFatal(
        "Isolated map-initialization validation fault. Source notes and " +
        "disclaimers remain available, but no map requests were started."
      );
      return;
    }

    if (!window.L || typeof window.L.map !== "function" ||
        !window.L.tileLayer || typeof window.L.tileLayer.wms !== "function") {
      showFatal(
        "Leaflet 1.9.4 or its WMS support did not load. Source notes and " +
        "disclaimers remain available, but no map requests were started."
      );
      return;
    }

    try {
      bindControls();
      state.mobileMedia = window.matchMedia(
        "(max-width: " + String(state.mobileBreakpoint) + "px)"
      );
      if (typeof state.mobileMedia.addEventListener === "function") {
        state.mobileMedia.addEventListener("change", queueLayoutCheck);
      } else if (typeof state.mobileMedia.addListener === "function") {
        state.mobileMedia.addListener(queueLayoutCheck);
      }
      window.addEventListener("resize", queueLayoutCheck);

      rebuildMaps(true);
      runChartHealthCheck();
      loadManifest();

      state.initialTimeout = window.setTimeout(function () {
        hideAllLoading();
        if (state.timings.mapReadyMs === null) {
          setChip("high-detail-poc-performance-status", "warning", "Initial render timed out");
        }
      }, 15000);

      window.FPWHighDetailPocDiagnostics = {
        getSnapshot: diagnosticsSnapshot,
        setMode: applyMode,
        setView: function (center, zoom) {
          bundleList().forEach(function (bundle) {
            bundle.map.setView(center, zoom, { animate: false });
          });
        }
      };
    } catch (error) {
      showFatal(
        "The isolated NOAA comparison could not initialize" +
        (error && error.message ? ": " + error.message : ".")
      );
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize, { once: true });
  } else {
    initialize();
  }
})(window, document);
