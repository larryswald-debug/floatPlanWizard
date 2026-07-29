(function (window, document) {
  "use strict";

  var initialStartedAt = window.performance && typeof window.performance.now === "function"
    ? window.performance.now()
    : Date.now();

  var CHART_LAYERS = "0,1,2,3,4,5,6,7,8,9,10,11,12";
  var BLUETOPO_TILE_SIZE = 512;
  var BLUETOPO_MAX_ZOOM = 20;
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

  var SAMPLE_ROUTE = [
    {
      label: "Gulf approach",
      lat: 27.592,
      lng: -82.835,
      type: "start"
    },
    {
      label: "Egmont Channel",
      lat: 27.603,
      lng: -82.745,
      type: "intermediate"
    },
    {
      label: "Skyway Channel",
      lat: 27.625,
      lng: -82.655,
      type: "intermediate"
    },
    {
      label: "Lower Tampa Bay",
      lat: 27.705,
      lng: -82.615,
      type: "end"
    }
  ];

  var state = {
    root: null,
    basePath: "",
    map: null,
    layers: {},
    initialDone: false,
    initial: {
      map: false,
      chart: false,
      elevation: false,
      hillshade: false,
      chartHealth: false
    },
    chartHealthWarning: false,
    chartTileErrors: 0,
    reliefTileErrors: 0,
    modeApplying: false,
    featureController: null,
    featureMarker: null
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function normalizeBasePath(value) {
    var base = String(value || "").trim().replace(/\/+$/, "");
    if (base === "/") return "";
    if (base && base.charAt(0) !== "/") base = "/" + base;
    return base;
  }

  function elapsedMs() {
    var current = window.performance && typeof window.performance.now === "function"
      ? window.performance.now()
      : Date.now();
    return Math.max(0, current - initialStartedAt);
  }

  function setLastMapLoadTime() {
    var element = byId("pocLastMapLoadTime");
    var completedAt;

    if (!element) return;

    completedAt = new Date();
    element.setAttribute("datetime", completedAt.toISOString());
    element.textContent = completedAt.toLocaleString();
  }

  function setChip(id, status, text) {
    var element = byId(id);
    if (!element) return;
    element.setAttribute("data-state", status);
    element.textContent = text;
  }

  function showFatal(message) {
    var fatal = byId("pocFatalError");
    var loading = byId("pocMapLoading");
    if (loading) loading.hidden = true;
    if (!fatal) return;
    fatal.textContent = message;
    fatal.hidden = false;
  }

  function showChartWarning(message) {
    var warning = byId("pocChartHealthWarning");
    var warningText = byId("pocChartHealthWarningText");
    state.chartHealthWarning = true;
    setChip("pocChartStatus", "warning", "Service warning");
    if (warningText) warningText.textContent = message;
    if (warning) warning.hidden = false;
  }

  function maybeFinishInitialRender(force) {
    var ready;
    var loading;
    var perfState;
    var perfText;

    if (state.initialDone) return;

    ready = state.initial.map &&
      state.initial.chart &&
      state.initial.elevation &&
      state.initial.hillshade &&
      state.initial.chartHealth;

    if (!ready && !force) return;

    state.initialDone = true;
    loading = byId("pocMapLoading");
    if (loading) loading.hidden = true;

    perfState = ready ? "ready" : "warning";
    perfText = ready
      ? Math.round(elapsedMs()) + " ms"
      : "Timed out";
    setChip("pocPerformanceStatus", perfState, perfText);
    setLastMapLoadTime();
  }

  function markInitial(key) {
    if (Object.prototype.hasOwnProperty.call(state.initial, key)) {
      state.initial[key] = true;
    }
    maybeFinishInitialRender(false);
  }

  function trackChartLayer(layer) {
    layer.on("loading", function () {
      if (!state.chartHealthWarning) {
        setChip("pocChartStatus", "loading", "Loading…");
      }
    });

    layer.on("load", function () {
      markInitial("chart");
      if (!state.chartHealthWarning && state.initial.chartHealth) {
        setChip("pocChartStatus", "ready", "Available");
      }
    });

    layer.on("tileerror", function () {
      state.chartTileErrors += 1;
      markInitial("chart");
      if (state.chartTileErrors >= 3) {
        showChartWarning(
          "Multiple NOAA chart tiles failed to load. Seafloor relief, route, " +
          "waypoints, and map controls remain available."
        );
      }
    });
  }

  function updateReliefStatus() {
    if (state.reliefTileErrors > 0) {
      setChip("pocReliefStatus", "warning", "Partial failure");
      return;
    }

    if (state.initial.elevation && state.initial.hillshade) {
      setChip("pocReliefStatus", "ready", "Available");
    } else {
      setChip("pocReliefStatus", "loading", "Loading…");
    }
  }

  function trackReliefLayer(layer, initialKey) {
    layer.on("loading", function () {
      updateReliefStatus();
    });

    layer.on("load", function () {
      markInitial(initialKey);
      updateReliefStatus();
    });

    layer.on("tileerror", function () {
      state.reliefTileErrors += 1;
      markInitial(initialKey);
      updateReliefStatus();
    });
  }

  function makeWaypointIcon(point, index) {
    var className = "poc-waypoint-pin";
    if (point.type === "start") className += " poc-waypoint-pin--start";
    if (point.type === "end") className += " poc-waypoint-pin--end";

    return window.L.divIcon({
      className: "poc-waypoint-icon",
      html: '<span class="' + className + '">' + String(index + 1) + "</span>",
      iconSize: [22, 22],
      iconAnchor: [11, 11],
      popupAnchor: [0, -13],
      tooltipAnchor: [0, -13]
    });
  }

  function buildRouteLayers() {
    var coordinates = SAMPLE_ROUTE.map(function (point) {
      return [point.lat, point.lng];
    });
    var routeGroup = window.L.layerGroup();
    var waypointGroup = window.L.layerGroup();

    window.L.polyline(coordinates, {
      pane: "pocRoutePane",
      color: "#ffffff",
      weight: 9,
      opacity: 0.78,
      lineJoin: "round",
      lineCap: "round",
      interactive: false
    }).addTo(routeGroup);

    window.L.polyline(coordinates, {
      pane: "pocRoutePane",
      color: "#e84f47",
      weight: 5,
      opacity: 1,
      lineJoin: "round",
      lineCap: "round",
      interactive: false
    })
      .bindPopup(
        "<strong>Illustrative FPW route</strong><br>" +
        "Disposable POC geometry. Not evaluated for navigational safety."
      )
      .addTo(routeGroup);

    SAMPLE_ROUTE.forEach(function (point, index) {
      var typeLabel = point.type === "start"
        ? "Start"
        : (point.type === "end" ? "End" : "Waypoint");
      var marker = window.L.marker([point.lat, point.lng], {
        pane: "pocWaypointPane",
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
        "Illustrative FPW POC waypoint — not for navigation."
      );
      marker.addTo(waypointGroup);
    });

    return {
      route: routeGroup,
      waypoints: waypointGroup,
      bounds: window.L.latLngBounds(coordinates)
    };
  }

  function setModeRadio(mode) {
    var radios = document.querySelectorAll('input[name="pocVisualMode"]');
    Array.prototype.forEach.call(radios, function (radio) {
      radio.checked = radio.value === mode;
    });
  }

  function setModeLabel(mode) {
    var labels = {
      chart: "NOAA Chart",
      relief: "Seafloor Relief",
      combined: "Combined",
      custom: "Custom"
    };
    setChip("pocModeStatus", "ready", labels[mode] || labels.custom);
  }

  function setLayerVisible(layer, visible) {
    if (!state.map || !layer) return;
    if (visible && !state.map.hasLayer(layer)) {
      state.map.addLayer(layer);
    } else if (!visible && state.map.hasLayer(layer)) {
      state.map.removeLayer(layer);
    }
  }

  function applyLayerOpacity(mode) {
    if (!state.layers.chart || !state.layers.elevation || !state.layers.hillshade) return;

    if (mode === "combined") {
      state.layers.chart.setOpacity(0.94);
      state.layers.elevation.setOpacity(0.46);
      state.layers.hillshade.setOpacity(0.28);
      return;
    }

    if (mode === "relief") {
      state.layers.elevation.setOpacity(0.84);
      state.layers.hillshade.setOpacity(0.42);
      return;
    }

    state.layers.chart.setOpacity(1);
  }

  function applyMode(mode) {
    if (!state.map || !state.layers.chart || !state.layers.relief) return;
    if (["chart", "relief", "combined"].indexOf(mode) === -1) return;

    state.modeApplying = true;
    setLayerVisible(state.layers.chart, mode === "chart" || mode === "combined");
    setLayerVisible(state.layers.relief, mode === "relief" || mode === "combined");
    applyLayerOpacity(mode);
    state.modeApplying = false;

    setModeRadio(mode);
    setModeLabel(mode);
  }

  function syncModeFromLayerControl() {
    var chartVisible;
    var reliefVisible;
    var mode;

    if (state.modeApplying || !state.map) return;

    chartVisible = state.map.hasLayer(state.layers.chart);
    reliefVisible = state.map.hasLayer(state.layers.relief);

    if (chartVisible && reliefVisible) {
      mode = "combined";
    } else if (chartVisible) {
      mode = "chart";
    } else if (reliefVisible) {
      mode = "relief";
    } else {
      mode = "custom";
    }

    if (mode === "custom") {
      setModeRadio("");
      setModeLabel("custom");
      return;
    }

    applyLayerOpacity(mode);
    setModeRadio(mode);
    setModeLabel(mode);
  }

  function bindModeControls() {
    var radios = document.querySelectorAll('input[name="pocVisualMode"]');
    Array.prototype.forEach.call(radios, function (radio) {
      radio.addEventListener("change", function () {
        if (radio.checked) applyMode(radio.value);
      });
    });
  }

  function projectWebMercator(lng, lat) {
    var originShift = 20037508.342789244;
    var boundedLat = Math.max(-85.05112878, Math.min(85.05112878, lat));
    var x = lng * originShift / 180;
    var y = Math.log(Math.tan((90 + boundedLat) * Math.PI / 360)) / (Math.PI / 180);
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
        var imageData;
        var index;
        var hasVisiblePixel = false;

        try {
          canvas = document.createElement("canvas");
          canvas.width = Math.max(1, Math.min(64, image.naturalWidth || 1));
          canvas.height = Math.max(1, Math.min(64, image.naturalHeight || 1));
          context = canvas.getContext("2d", { willReadFrequently: true });
          context.drawImage(image, 0, 0, canvas.width, canvas.height);
          imageData = context.getImageData(0, 0, canvas.width, canvas.height).data;

          for (index = 3; index < imageData.length; index += 16) {
            if (imageData[index] > 0) {
              hasVisiblePixel = true;
              break;
            }
          }

          cleanup();
          resolve(!hasVisiblePixel);
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
    var southwest = projectWebMercator(-82.86, 27.5);
    var northeast = projectWebMercator(-82.45, 27.9);
    var cacheNudge = (Date.now() % 100000) / 10000;
    var params = new URLSearchParams();

    /*
     * A tiny BBOX nudge prevents a cached transparent fallback from being
     * indistinguishable from a normal proxy cache hit during this health probe.
     */
    northeast.x += cacheNudge;

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
    var fetchOptions = {
      method: "GET",
      credentials: "same-origin",
      cache: "no-store",
      headers: {
        "Accept": "image/png,application/json"
      }
    };

    if (controller) fetchOptions.signal = controller.signal;

    return window.fetch(chartHealthUrl(), fetchOptions)
      .then(function (response) {
        var diagnostic = String(response.headers.get("X-FPW-WMSProxy") || "");
        var contentType = String(response.headers.get("Content-Type") || "").toLowerCase();

        if (!response.ok) {
          throw new Error("Chart proxy health request returned HTTP " + response.status + ".");
        }

        if (diagnostic.toLowerCase().indexOf("fallback") === 0) {
          return {
            transparentFallback: true,
            reason: "The NOAA chart proxy reported " + diagnostic + "."
          };
        }

        if (contentType.indexOf("json") !== -1) {
          return response.json().then(function (payload) {
            return {
              transparentFallback: payload && payload.success === false,
              reason: payload && payload.message
                ? payload.message
                : "The NOAA chart proxy returned its transparent fallback response."
            };
          });
        }

        return response.blob().then(function (blob) {
          return imageIsTransparent(blob).then(function (transparent) {
            return {
              transparentFallback: transparent,
              reason: transparent
                ? "The NOAA chart proxy returned a fully transparent image during the Tampa Bay health probe."
                : ""
            };
          });
        });
      })
      .then(function (result) {
        window.clearTimeout(timeoutId);
        markInitial("chartHealth");

        if (result.transparentFallback) {
          showChartWarning(
            result.reason + " Seafloor relief, route, waypoints, and map controls remain available."
          );
          return;
        }

        if (!state.chartHealthWarning) {
          setChip("pocChartStatus", state.initial.chart ? "ready" : "loading",
            state.initial.chart ? "Available" : "Loading…");
        }
      })
      .catch(function (error) {
        window.clearTimeout(timeoutId);
        markInitial("chartHealth");
        showChartWarning(
          "The NOAA chart service health check could not be confirmed" +
          (error && error.message ? ": " + error.message : ".") +
          " Seafloor relief, route, waypoints, and map controls remain available."
        );
      });
  }

  function tileCoordinates(lat, lng, zoom) {
    var z = Math.max(0, Math.min(BLUETOPO_MAX_ZOOM, Math.round(zoom)));
    var boundedLat = Math.max(-85.05112878, Math.min(85.05112878, lat));
    var normalizedLng = normalizeLongitude(lng);
    var latRadians = boundedLat * Math.PI / 180;
    var scale = Math.pow(2, z);
    var x = (normalizedLng + 180) / 360 * scale;
    var y = (
      1 -
      Math.log(Math.tan(latRadians) + (1 / Math.cos(latRadians))) / Math.PI
    ) / 2 * scale;
    var column = Math.floor(x);
    var row = Math.floor(y);
    var pixelX = Math.max(0, Math.min(
      BLUETOPO_TILE_SIZE - 1,
      Math.floor((x - column) * BLUETOPO_TILE_SIZE)
    ));
    var pixelY = Math.max(0, Math.min(
      BLUETOPO_TILE_SIZE - 1,
      Math.floor((y - row) * BLUETOPO_TILE_SIZE)
    ));

    return {
      zoom: z,
      column: column,
      row: row,
      pixelX: pixelX,
      pixelY: pixelY
    };
  }

  function normalizeLongitude(lng) {
    var numericLng = Number(lng);
    if (!Number.isFinite(numericLng)) return 0;
    return ((numericLng + 180) % 360 + 360) % 360 - 180;
  }

  function featureInfoUrl(latlng) {
    var tile = tileCoordinates(latlng.lat, latlng.lng, state.map.getZoom());
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
    var target;
    var index;
    var keyIndex;

    for (index = 0; index < names.length; index += 1) {
      target = String(names[index]).toLowerCase();
      for (keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
        if (String(keys[keyIndex]).toLowerCase() === target) {
          return properties[keys[keyIndex]];
        }
      }
    }
    return null;
  }

  function finiteNumber(value) {
    var number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  function formatSurveyDate(start, end) {
    var cleanStart = String(start || "").trim();
    var cleanEnd = String(end || "").trim();

    if (cleanStart && cleanEnd && cleanStart !== cleanEnd) {
      return cleanStart + " to " + cleanEnd;
    }
    return cleanEnd || cleanStart || "Not reported";
  }

  function setInspectField(id, value) {
    var element = byId(id);
    if (element) element.textContent = value;
  }

  function resetInspectDetails() {
    [
      "pocInspectElevation",
      "pocInspectUncertainty",
      "pocInspectCoverage",
      "pocInspectSource",
      "pocInspectSurveyDate",
      "pocInspectInstitution"
    ].forEach(function (id) {
      setInspectField(id, "—");
    });
  }

  function setInspectMessage(message, isError) {
    var element = byId("pocInspectMessage");
    if (!element) return;
    element.textContent = message;
    element.setAttribute("data-state", isError ? "error" : "ready");
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

  function renderFeatureInfo(latlng, properties) {
    var elevation = finiteNumber(propertyValue(properties, ["ELEVATION"]));
    var uncertainty = finiteNumber(propertyValue(properties, ["UNCERTAINTY"]));
    var bathyCoverage = propertyValue(properties, ["bathy_coverage"]);
    var source = propertyValue(properties, ["source_survey_id"]);
    var institution = propertyValue(properties, ["source_institution"]);
    var surveyStart = propertyValue(properties, ["survey_date_start"]);
    var surveyEnd = propertyValue(properties, ["survey_date_end"]);

    setInspectField(
      "pocInspectLocation",
      latlng.lat.toFixed(5) + ", " + latlng.lng.toFixed(5)
    );
    setInspectField(
      "pocInspectElevation",
      elevation === null
        ? "Not reported"
        : elevation.toFixed(2) + " m relative to NAVD88"
    );
    setInspectField(
      "pocInspectUncertainty",
      uncertainty === null ? "Not reported" : uncertainty.toFixed(2) + " m"
    );
    setInspectField("pocInspectCoverage", coverageLabel(bathyCoverage));
    setInspectField("pocInspectSource", String(source || "Not reported"));
    setInspectField(
      "pocInspectSurveyDate",
      formatSurveyDate(surveyStart, surveyEnd)
    );
    setInspectField("pocInspectInstitution", String(institution || "Not reported"));

    setChip("pocInspectState", "ready", "Data returned");
    setInspectMessage(
      "Official BlueTopo source metadata returned. Elevation and uncertainty are " +
      "planning context only and are not charted navigational soundings.",
      false
    );
  }

  function setInspectionMarker(latlng) {
    var icon;
    if (!state.map) return;

    if (!state.featureMarker) {
      icon = window.L.divIcon({
        className: "poc-inspect-icon",
        html: '<span class="poc-inspect-dot"></span>',
        iconSize: [15, 15],
        iconAnchor: [7.5, 7.5]
      });
      state.featureMarker = window.L.marker(latlng, {
        pane: "pocInspectPane",
        icon: icon,
        keyboard: false,
        interactive: false
      }).addTo(state.map);
      return;
    }

    state.featureMarker.setLatLng(latlng);
  }

  function inspectBlueTopo(latlng) {
    var controller;
    var timeoutId;
    var queryLatLng;
    var options = {
      method: "GET",
      mode: "cors",
      credentials: "omit",
      cache: "no-store",
      headers: {
        "Accept": "application/json"
      }
    };

    if (!latlng || !state.map) return;

    queryLatLng = {
      lat: latlng.lat,
      lng: normalizeLongitude(latlng.lng)
    };

    if (state.featureController) {
      state.featureController.abort();
    }

    controller = typeof window.AbortController === "function"
      ? new window.AbortController()
      : null;
    state.featureController = controller;
    if (controller) options.signal = controller.signal;

    timeoutId = window.setTimeout(function () {
      if (controller) controller.abort();
    }, 12000);

    setInspectionMarker(latlng);
    resetInspectDetails();
    setInspectField(
      "pocInspectLocation",
      queryLatLng.lat.toFixed(5) + ", " + queryLatLng.lng.toFixed(5)
    );
    setChip("pocInspectState", "loading", "Querying…");
    setInspectMessage("Requesting BlueTopo FeatureInfo from NOAA nowCOAST…", false);

    window.fetch(featureInfoUrl(queryLatLng), options)
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
        var properties;

        window.clearTimeout(timeoutId);

        if (!features.length || !features[0] || !features[0].properties) {
          throw new Error("No BlueTopo source metadata is available at this location.");
        }

        properties = features[0].properties;
        renderFeatureInfo(queryLatLng, properties);
      })
      .catch(function (error) {
        window.clearTimeout(timeoutId);

        if (error && error.name === "AbortError" && state.featureController !== controller) {
          return;
        }

        setChip("pocInspectState", "error", "Unavailable");
        setInspectMessage(
          (error && error.name === "AbortError")
            ? "The BlueTopo FeatureInfo request timed out. The map and all layers remain available."
            : (
              (error && error.message ? error.message : "BlueTopo FeatureInfo failed.") +
              " The map and all layers remain available."
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

  function initializeMap() {
    var chartProxyUrl;
    var openStreetMap;
    var chart;
    var elevation;
    var hillshade;
    var reliefGroup;
    var routeLayers;
    var layerControl;

    if (!window.L || typeof window.L.map !== "function" ||
        !window.L.tileLayer || typeof window.L.tileLayer.wms !== "function") {
      showFatal("Leaflet 1.9.4 or its WMS support did not load. No map requests were started.");
      return;
    }

    chartProxyUrl = state.basePath +
      "/api/v1/wmsProxy.cfc?method=tile&target=noaa-charts";

    state.map = window.L.map("pocMap", {
      center: [27.65, -82.71],
      zoom: 10,
      minZoom: 6,
      maxZoom: 18,
      zoomControl: true,
      preferCanvas: true
    });

    state.map.createPane("pocReliefPane");
    state.map.getPane("pocReliefPane").style.zIndex = "300";
    state.map.createPane("pocHillshadePane");
    state.map.getPane("pocHillshadePane").style.zIndex = "310";
    state.map.createPane("pocChartPane");
    state.map.getPane("pocChartPane").style.zIndex = "430";
    state.map.createPane("pocRoutePane");
    state.map.getPane("pocRoutePane").style.zIndex = "620";
    state.map.createPane("pocWaypointPane");
    state.map.getPane("pocWaypointPane").style.zIndex = "640";
    state.map.createPane("pocInspectPane");
    state.map.getPane("pocInspectPane").style.zIndex = "660";

    openStreetMap = window.L.tileLayer(
      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      {
        maxZoom: 19,
        crossOrigin: true,
        attribution: "&copy; OpenStreetMap contributors"
      }
    );

    chart = window.L.tileLayer.wms(chartProxyUrl, {
      pane: "pocChartPane",
      layers: CHART_LAYERS,
      styles: "",
      format: "image/png",
      transparent: true,
      version: "1.3.0",
      opacity: 0.94,
      minZoom: 6,
      maxZoom: 18,
      updateWhenIdle: true,
      keepBuffer: 2,
      attribution: "NOAA Office of Coast Survey Chart Display Service"
    });

    elevation = window.L.tileLayer(BLUETOPO_ELEVATION_URL, {
      pane: "pocReliefPane",
      minZoom: 0,
      maxZoom: BLUETOPO_MAX_ZOOM,
      maxNativeZoom: BLUETOPO_MAX_ZOOM,
      opacity: 0.46,
      crossOrigin: true,
      updateWhenIdle: true,
      keepBuffer: 2,
      attribution: "NOAA Office of Coast Survey BlueTopo via nowCOAST"
    });

    hillshade = window.L.tileLayer(BLUETOPO_HILLSHADE_URL, {
      pane: "pocHillshadePane",
      minZoom: 0,
      maxZoom: BLUETOPO_MAX_ZOOM,
      maxNativeZoom: BLUETOPO_MAX_ZOOM,
      opacity: 0.28,
      crossOrigin: true,
      updateWhenIdle: true,
      keepBuffer: 2,
      attribution: "NOAA BlueTopo hillshade via nowCOAST"
    });

    reliefGroup = window.L.layerGroup([elevation, hillshade]);
    routeLayers = buildRouteLayers();

    state.layers = {
      base: openStreetMap,
      chart: chart,
      elevation: elevation,
      hillshade: hillshade,
      relief: reliefGroup,
      route: routeLayers.route,
      waypoints: routeLayers.waypoints
    };

    trackChartLayer(chart);
    trackReliefLayer(elevation, "elevation");
    trackReliefLayer(hillshade, "hillshade");

    openStreetMap.addTo(state.map);
    reliefGroup.addTo(state.map);
    chart.addTo(state.map);
    routeLayers.route.addTo(state.map);
    routeLayers.waypoints.addTo(state.map);

    layerControl = window.L.control.layers(
      {
        "OpenStreetMap reference": openStreetMap
      },
      {
        "NOAA Nautical Chart": chart,
        "NOAA Seafloor Relief (BlueTopo)": reliefGroup,
        "Illustrative FPW Route": routeLayers.route,
        "FPW Sample Waypoints": routeLayers.waypoints
      },
      {
        collapsed: window.matchMedia("(max-width: 760px)").matches,
        position: "topright"
      }
    );
    layerControl.addTo(state.map);

    window.L.control.scale({
      imperial: true,
      metric: true,
      maxWidth: 150
    }).addTo(state.map);

    state.map.fitBounds(routeLayers.bounds, {
      padding: [46, 46],
      maxZoom: 10
    });

    state.map.on("overlayadd overlayremove", syncModeFromLayerControl);
    state.map.on("click", function (event) {
      /*
       * FeatureInfo is intentionally not awaited by any map/layer operation.
       * Its own error path updates only the inspection panel.
       */
      inspectBlueTopo(event.latlng);
    });

    state.map.whenReady(function () {
      markInitial("map");
      window.setTimeout(function () {
        state.map.invalidateSize(false);
      }, 0);
    });

    bindModeControls();
    applyMode("combined");
    runChartHealthCheck();

    window.setTimeout(function () {
      maybeFinishInitialRender(true);
    }, 15000);
  }

  function init() {
    state.root = byId("noaaBathymetryPoc");
    if (!state.root) return;

    state.basePath = normalizeBasePath(
      state.root.getAttribute("data-fpw-base") ||
      (Object.prototype.hasOwnProperty.call(window, "FPW_BASE") ? window.FPW_BASE : "")
    );

    try {
      initializeMap();
    } catch (error) {
      showFatal(
        "The isolated NOAA map proof of concept could not initialize" +
        (error && error.message ? ": " + error.message : ".")
      );
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})(window, document);
