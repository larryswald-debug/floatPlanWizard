(function (window, document) {
  "use strict";

  var WEATHER_VERSION = "weather-rewrite-phase3";
  var state = {
    lastModel: null,
    loadingTimer: 0,
    loadingStartedAt: 0,
    abortController: null,
    map: null,
    mapMarker: null
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function text(id, value) {
    var el = byId(id);
    if (el) el.textContent = display(value);
  }

  function htmlList(id, items, emptyText) {
    var el = byId(id);
    if (!el) return;
    items = safeArray(items);
    if (!items || !items.length) {
      el.innerHTML = "<li>" + escapeHtml(emptyText || "—") + "</li>";
      return;
    }
    el.innerHTML = items.map(function (item) {
      return "<li>" + escapeHtml(item) + "</li>";
    }).join("");
  }

  function display(value, fallback) {
    if (value === null || value === undefined || value === "") {
      return fallback || "—";
    }
    return String(value);
  }

  function safeArray(value) {
    return Array.isArray(value) ? value : [];
  }

  function numberText(value, unit, digits) {
    if (value === null || value === undefined || value === "" || !isFinite(Number(value))) {
      return "—";
    }
    var n = Number(value);
    var rounded = typeof digits === "number" ? n.toFixed(digits) : Math.round(n);
    return rounded + (unit ? " " + unit : "");
  }

  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function fpwBase() {
    var path = window.location.pathname || "/fpw/";
    var marker = "/app/";
    var idx = path.indexOf(marker);
    return idx >= 0 ? path.slice(0, idx) : "/fpw";
  }

  function endpointUrl(params) {
    var query = new URLSearchParams();
    query.set("method", "handle");
    query.set("action", "pageWeather");
    Object.keys(params || {}).forEach(function (key) {
      if (params[key] !== null && params[key] !== undefined && String(params[key]).length) {
        query.set(key, params[key]);
      }
    });
    return fpwBase() + "/api/v1/weather.cfc?" + query.toString();
  }

  function setHidden(id, hidden) {
    var el = byId(id);
    if (!el) return;
    el.classList.toggle("d-none", !!hidden);
    if (hidden) {
      el.setAttribute("hidden", "hidden");
    } else {
      el.removeAttribute("hidden");
    }
  }

  function setError(message) {
    var el = byId("weatherError");
    if (!el) return;
    if (message) {
      el.textContent = message;
      el.classList.remove("d-none");
    } else {
      el.textContent = "";
      el.classList.add("d-none");
    }
  }

  function setStateBox(config) {
    var box = byId("weatherStateBox");
    if (!box) return;
    if (!config) {
      box.classList.add("d-none");
      box.setAttribute("hidden", "hidden");
      return;
    }
    var title = byId("weatherStateTitle");
    var message = byId("weatherStateMessage");
    var action = byId("weatherStateAction");
    if (title) title.textContent = display(config.title, "Weather needs a location");
    if (message) message.textContent = display(config.message, "Update your weather location to load local marine weather.");
    if (action) {
      if (config.actionHref) {
        action.href = config.actionHref;
        action.textContent = config.actionLabel || "Update Home Port";
        action.classList.remove("d-none");
        action.removeAttribute("hidden");
      } else {
        action.classList.add("d-none");
        action.setAttribute("hidden", "hidden");
      }
    }
    box.classList.remove("d-none");
    box.removeAttribute("hidden");
  }

  function startLoading(label) {
    var root = byId("weatherLoading");
    var step = byId("weatherScanStep");
    var location = byId("weatherScanLocation");
    if (root) root.classList.remove("d-none");
    if (step) step.textContent = "Building weather briefing…";
    if (location) location.textContent = label || "Checking your selected weather location";
    state.loadingStartedAt = Date.now();
    window.clearInterval(state.loadingTimer);
    state.loadingTimer = window.setInterval(function () {
      var elapsed = byId("weatherScanElapsed");
      if (elapsed) elapsed.textContent = Math.max(0, Math.floor((Date.now() - state.loadingStartedAt) / 1000)) + "s";
    }, 500);
  }

  function stopLoading() {
    window.clearInterval(state.loadingTimer);
    state.loadingTimer = 0;
    var root = byId("weatherLoading");
    if (root) root.classList.add("d-none");
  }

  function collectRequestParams() {
    var modeEl = byId("weatherLocationMode");
    var mode = modeEl ? String(modeEl.value || "zip").toLowerCase() : "zip";
    if (mode === "coords") {
      return {
        lat: byId("weatherLat") ? byId("weatherLat").value.trim() : "",
        lon: byId("weatherLon") ? byId("weatherLon").value.trim() : ""
      };
    }
    return {
      zip: byId("weatherZip") ? byId("weatherZip").value.replace(/\D/g, "").slice(0, 5) : ""
    };
  }

  function syncLocationMode() {
    var modeEl = byId("weatherLocationMode");
    var mode = modeEl ? String(modeEl.value || "zip").toLowerCase() : "zip";
    setHidden("weatherZipBlock", mode !== "zip");
    setHidden("weatherCoordsBlock", mode !== "coords");
    setHidden("weatherCoordsLonBlock", mode !== "coords");
  }

  function loadWeather(params) {
    if (state.abortController) {
      state.abortController.abort();
    }
    state.abortController = window.AbortController ? new AbortController() : null;
    setError("");
    startLoading("Checking " + requestLabel(params));

    var timeoutId = window.setTimeout(function () {
      if (state.abortController) {
        state.abortController.abort();
      }
    }, 12000);

    return fetch(endpointUrl(params || {}), {
      credentials: "same-origin",
      signal: state.abortController ? state.abortController.signal : undefined,
      headers: { "Accept": "application/json" }
    })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Weather endpoint returned HTTP " + response.status + ".");
        }
        return response.json();
      })
      .then(function (model) {
        state.lastModel = model;
        renderWeather(model || {});
      })
      .catch(function (error) {
        var message = "Weather data is temporarily unavailable. Try again in a moment.";
        if (error && error.name === "AbortError") {
          message = "Weather request timed out. Try again in a moment.";
        }
        setError(message);
        renderWeather(emptyModel("REQUEST_FAILED", message));
      })
      .finally(function () {
        window.clearTimeout(timeoutId);
        state.abortController = null;
        stopLoading();
      });
  }

  function requestLabel(params) {
    params = params || {};
    if (params.lat && params.lon) {
      return params.lat + ", " + params.lon;
    }
    if (params.zip) {
      return "ZIP " + params.zip;
    }
    return "your home port";
  }

  function renderWeather(model) {
    model = normalizeModel(model);
    renderPageState(model);
    renderHeader(model);
    renderRisk(model);
    renderCurrent(model.current || {});
    renderMarine(model.marine || {});
    renderAlerts(model.alerts, model);
    renderForecast(model.forecast12h);
    renderTide(model.marine || {});
    renderSources(model);
    renderMap(model);
    renderZone(model.zoneForecast || {}, model);
    renderStatus(model);
  }

  function normalizeModel(model) {
    model = model || {};
    model.target = model.target || {};
    model.status = model.status || { messages: [] };
    model.current = model.current || {};
    model.marine = model.marine || {};
    model.forecast12h = safeArray(model.forecast12h);
    model.alerts = safeArray(model.alerts);
    model.zoneForecast = model.zoneForecast || {};
    model.map = model.map || { layers: [] };
    model.map.layers = safeArray(model.map.layers);
    model.cache = model.cache || {};
    model.diagnostics = model.diagnostics || {};
    return model;
  }

  function renderPageState(model) {
    var reason = statusReason(model);
    if (reason === "HOMEPORT_NO_COORDINATES" || reason === "HOMEPORT_INVALID_COORDINATES" || reason === "NO_HOMEPORT") {
      setStateBox({
        title: "Weather needs home-port coordinates",
        message: "Weather needs a saved home-port location with coordinates. Open your account page and update the Home Port latitude and longitude fields.",
        actionHref: fpwBase() + "/app/account.cfm",
        actionLabel: "Update Home Port"
      });
      return;
    }
    if (reason === "ZIP_COORDINATES_UNAVAILABLE") {
      setStateBox({
        title: "ZIP-only weather is not enabled",
        message: "ZIP-only weather lookup is not enabled yet. Save a home port with coordinates to view local marine weather.",
        actionHref: fpwBase() + "/app/account.cfm",
        actionLabel: "Update Home Port"
      });
      return;
    }
    if (reason === "INVALID_COORDINATES") {
      setStateBox({
        title: "Coordinates need attention",
        message: "The coordinates entered were not valid. Enter latitude and longitude in decimal degrees, then update the briefing."
      });
      return;
    }
    if (!model.ok && reason) {
      setStateBox({
        title: "Weather is temporarily unavailable",
        message: firstStatusMessage(model, "Weather data is temporarily unavailable for this location.")
      });
      return;
    }
    setStateBox(null);
  }

  function statusReason(model) {
    var status = model.status || {};
    var target = model.target || {};
    return String(status.reason || target.reason || "").toUpperCase();
  }

  function firstStatusMessage(model, fallback) {
    var messages = safeArray(model && model.status ? model.status.messages : []);
    return messages.length ? messages[0] : fallback;
  }

  function renderHeader(model) {
    var target = model.target || {};
    var current = model.current || {};
    var marine = model.marine || {};
    text("weatherResolvedLocation", target.displayName || target.zip || "Selected location");
    text("weatherLocationDetailLabel", target.sourceType || "weather target");
    text("weatherZipDisplay", target.zip || "");
    text("weatherProviderBadge", "NOAA/NWS");
    text("weatherUpdatedAt", model.generatedAtUtc ? "Updated " + formatTime(model.generatedAtUtc) : "Updated —");
    text("weatherMetarStation", current.stationId || "—");
    text("weatherTideStationShort", marine.tideStation || "—");
    text("weatherAnchorMeta", hasCoords(target) ? "Anchor: " + numberText(target.lat, "", 4) + ", " + numberText(target.lon, "", 4) : "Anchor: —");
    text("weatherTimezoneLabel", target.timezone || "local provider time");
    text("weatherVersionLabel", " • " + WEATHER_VERSION);

    var zipInput = byId("weatherZip");
    var sourceType = String(target.sourceType || "").toLowerCase();
    if (zipInput && target.zip && !zipInput.value && sourceType.indexOf("zip") >= 0) zipInput.value = target.zip;
    var latInput = byId("weatherLat");
    var lonInput = byId("weatherLon");
    if (latInput && hasCoords(target)) latInput.value = String(target.lat);
    if (lonInput && hasCoords(target)) lonInput.value = String(target.lon);
  }

  function renderRisk(model) {
    var marine = model.marine || {};
    var current = model.current || {};
    var alerts = safeArray(model.alerts);
    var panel = byId("weatherMarineRiskPanel");
    var risk = marine.riskLevel || "Unknown";
    if (panel) {
      panel.classList.remove("marine-risk-good", "marine-risk-caution", "marine-risk-high");
      panel.classList.add("marine-risk-" + risk.toLowerCase());
    }
    text("weatherRiskValue", risk);
    text("weatherRiskSubtext", risk === "Unknown" ? "Weather data is not ready." : (risk === "Good" ? "Favorable for nearshore boating" : "Use caution for small craft"));
    text("weatherRiskWind", current.windMph ? "Wind " + numberText(current.windMph, "mph") : "Wind —");
    text("weatherRiskGusts", current.gustMph ? "Gusts up to " + numberText(current.gustMph, "mph") : "Gusts —");
    text("weatherRiskSeas", marine.seasFt || marine.waveHeightFt ? "Seas " + numberText(marine.seasFt || marine.waveHeightFt, "ft", 1) : "Seas —");
    text("weatherRiskSeasNote", marine.wavePeriodSec ? "Period " + numberText(marine.wavePeriodSec, "sec") : "—");
    text("weatherRiskVisibility", current.visibilityMi ? "Visibility " + numberText(current.visibilityMi, "mi", 1) : "Visibility —");
    text("weatherRiskVisibilityNote", "—");
    text("weatherRiskAlerts", alerts.length ? alerts.length + " active" : "None active");
    text("weatherRiskRecommendation", marine.recommendation || "Review official NOAA conditions before departure.");
  }

  function renderCurrent(current) {
    text("weatherConditionText", current.available ? (current.condition || "Current conditions available") : "Current conditions temporarily unavailable.");
    text("weatherConditionIcon", conditionIcon(current.condition));
    text("weatherCurrentTemp", numberText(current.tempF, "°F"));
    text("weatherFeelsLike", numberText(current.feelsLikeF, "°F"));
    text("weatherCurrentWind", current.windMph ? windText(current) : "—");
    text("weatherCurrentGusts", numberText(current.gustMph, "mph"));
    text("weatherPressure", numberText(current.pressureInHg, "inHg", 2));
    text("weatherVisibility", numberText(current.visibilityMi, "mi", 1));
    text("weatherHumidity", numberText(current.humidityPct, "%"));
    text("weatherDewPoint", numberText(current.dewpointF, "°F"));
    text("weatherObservedAt", current.observedAtUtc ? formatTime(current.observedAtUtc) : "—");
    text("weatherObservedStation", current.stationId || "—");
  }

  function renderMarine(marine) {
    var wave = marine.seasFt || marine.waveHeightFt;
    var marineWarning = safeArray(marine.warnings)[0] || "Tide data is temporarily unavailable for this location.";
    text("weatherWaveHeight", numberText(wave, "", 1));
    text("weatherWaveTrendTop", wave ? "Latest available" : "—");
    text("weatherWavePeriod", numberText(marine.wavePeriodSec, "sec"));
    text("weatherWaveDirection", marine.waveDirectionDeg ? numberText(marine.waveDirectionDeg, "°") : "—");
    text("weatherWaveLevel", waveLevel(wave));
    text("weatherWaveTrend", marine.available ? "Latest" : "—");
    text("weatherWaveNote", marine.available ? "Review latest local marine forecast before departure." : "Wave and sea details are temporarily unavailable from the current providers.");
    text("weatherCurrentTide", numberText(marine.tideLevelFt, "", 2));
    text("weatherTideDirection", marine.tideTrend || "—");
    text("weatherNextHighTideHeight", tideHeight(marine.nextHigh));
    text("weatherNextHighTideTime", tideTime(marine.nextHigh));
    text("weatherNextLowTideHeight", tideHeight(marine.nextLow));
    text("weatherNextLowTideTime", tideTime(marine.nextLow));
    text("weatherTideTrend", marine.tideTrend || "—");
    text("weatherTideStation", marine.tideStation || "—");
    if (!marine.available) {
      text("weatherTideDirection", "Unavailable");
      text("weatherTideTrend", "Unavailable");
      text("weatherTideStation", "—");
      text("weatherCurrentTide", "—");
      text("weatherTidePlanningNote", marineWarning);
    }
  }

  function renderAlerts(alerts, model) {
    alerts = safeArray(alerts);
    var count = alerts.length;
    text("weatherAlertStatus", count ? count + " Active" : "No Active Alerts");
    text("weatherAlertSummary", count ? "Review active NOAA marine alerts" : "No active weather alerts for this location.");
    text("weatherAlertHighest", count ? highestSeverity(alerts) : "—");
    text("weatherAlertsCheckedAt", model.generatedAtUtc ? formatTime(model.generatedAtUtc) : "—");
    htmlList("weatherAlertsActiveNow", alerts.map(function (a) { return a.event || a.headline || "NOAA alert"; }), "No active weather alerts for this location.");
    text("weatherAlertsPanelTitle", count ? "Active NOAA Alerts" : "No Active NOAA Alerts");
    text("weatherAlertsPanelBadge", count ? count + " Active" : "No Active Alerts");
    var list = byId("activeNoaaAlertsList");
    if (list) {
      list.innerHTML = count ? alerts.map(renderAlertCard).join("") : "";
    }
    text("weatherAlertsPanelState", count ? "" : "No active weather alerts for this location.");
  }

  function renderForecast(rows) {
    rows = safeArray(rows);
    var tbody = byId("weatherHourlyRows");
    if (!tbody) return;
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="8">Hourly forecast is temporarily unavailable.</td></tr>';
      text("weatherHourlySummary", "Hourly forecast is temporarily unavailable.");
      return;
    }
    tbody.innerHTML = rows.map(function (row) {
      return "<tr>"
        + "<td>" + escapeHtml(formatHour(row.timeLabel)) + "</td>"
        + "<td>" + escapeHtml(row.windMph ? row.windDirectionLabel + " " + numberText(row.windMph, "mph") : "—") + "</td>"
        + "<td>" + escapeHtml(numberText(row.gustMph, "mph")) + "</td>"
        + "<td>" + escapeHtml(numberText(row.seasFt, "", 1)) + "</td>"
        + "<td>" + escapeHtml(numberText(row.precipChancePct, "%")) + "</td>"
        + "<td>" + escapeHtml(numberText(row.tempF, "°F")) + "</td>"
        + "<td>" + escapeHtml(row.condition || "—") + "</td>"
        + "<td><span class=\"status-badge " + riskBadgeClass(row.riskLabel) + "\">" + escapeHtml(row.riskLabel || "Unknown") + "</span></td>"
        + "</tr>";
    }).join("");
    text("weatherHourlySummary", "Wind easing this evening. Gusts peak near " + maxValue(rows, "gustMph", "mph") + " • Rain risk up to " + maxValue(rows, "precipChancePct", "%"));
  }

  function renderTide(marine) {
    var tideWarning = safeArray(marine.warnings)[0] || "Tide data is temporarily unavailable for this location.";
    text("weatherTideChartStation", marine.tideStation || "—");
    text("tideGraphTitle", "Tide (ft)");
    text("tideGraphNowValue", "Now " + numberText(marine.tideLevelFt, "ft", 2));
    text("tideGraphStation", marine.tideStation || "");
    text("tideGraphStart", tideTime(marine.nextLow || marine.nextHigh));
    text("tideGraphEnd", tideTime(marine.nextHigh || marine.nextLow));
    text("weatherTideSummaryCurrent", numberText(marine.tideLevelFt, "ft", 2));
    text("weatherTideSummaryCurrentTrend", marine.tideTrend || "—");
    text("weatherTideSummaryHighTime", tideTime(marine.nextHigh));
    text("weatherTideSummaryHighHeight", tideHeight(marine.nextHigh));
    text("weatherTideSummaryLowTime", tideTime(marine.nextLow));
    text("weatherTideSummaryLowHeight", tideHeight(marine.nextLow));
    text("weatherTideSummaryNextHighTime", tideTime(marine.nextHigh));
    text("weatherTideSummaryNextHighHeight", tideHeight(marine.nextHigh));
    text("weatherTidePlanningNote", marine.available ? "Review tide timing for shallow-water routes before departure." : tideWarning);
    text("tideGraphEmpty", tideWarning);
    setHidden("tideGraph", !marine.available);
    setHidden("tideGraphEmpty", marine.available);
  }

  function renderSources(model) {
    var target = model.target || {};
    var current = model.current || {};
    var marine = model.marine || {};
    text("weatherSourceName", "NOAA/NWS");
    text("weatherForecastType", "Hourly point forecast");
    text("weatherSourceResolvedLocation", target.displayName || "—");
    text("weatherSourceAnchor", hasCoords(target) ? numberText(target.lat, "", 4) + ", " + numberText(target.lon, "", 4) : "—");
    text("weatherSourceZip", target.zip || "—");
    text("weatherSourceObservationStation", current.stationId || "—");
    text("weatherSourceTideStation", marine.tideStation || "—");
    text("weatherSourceDataUpdated", model.generatedAtUtc ? formatTime(model.generatedAtUtc) : "—");
    text("weatherSourceCacheStatus", model.cache && model.cache.summary ? model.cache.summary : "—");
  }

  function renderMap(model) {
    var target = model.target || {};
    var map = model.map || {};
    var layers = safeArray(map.layers);
    var hasMapCenter = hasCoords(target) && map.center && hasCoords(map.center);
    var button = byId("weatherMapLayersButton");
    if (!hasMapCenter) {
      htmlList("weatherMapLayerList", [], "Map unavailable until a weather location with coordinates is available.");
      text("weatherMapPanelCopy", "Map layers need a weather location with valid coordinates.");
      text("weatherMapPreviewLabel", "Map Unavailable");
      text("weatherMapPreviewHelper", "Save a home port with coordinates or use coordinate mode to enable the map.");
      if (button) {
        button.disabled = true;
        button.setAttribute("aria-label", "NOAA map unavailable until valid coordinates are available.");
      }
      return;
    }
    htmlList("weatherMapLayerList", layers.filter(function (l) { return l.available; }).map(function (l) { return l.label; }), "No map layers delivered for this location.");
    text("weatherMapPanelCopy", "NOAA nowCOAST layers are available for this location.");
    text("weatherMapPreviewLabel", "Open NOAA Map");
    text("weatherMapPreviewHelper", "View radar and marine warning layers in a full-screen map.");
    if (button) {
      button.disabled = false;
      button.setAttribute("aria-label", "Open NOAA map. View radar and marine warning layers in a full-screen map.");
    }
  }

  function renderZone(zone, model) {
    text("weatherZoneForecastMeta", zone.available ? [zone.zoneId, zone.zoneName].filter(Boolean).join(" • ") : (zone.reason || "—"));
    text("weatherZoneForecastOffice", zone.office ? "Source: NOAA/NWS " + zone.office : "Source: NOAA/NWS Coastal Waters Forecast");
    text("weatherZoneForecastSynopsis", zone.synopsis || "—");
    text("weatherZoneForecastCacheMeta", "Provider updated: " + (model.generatedAtUtc ? formatTime(model.generatedAtUtc) : "—") + " • Cache: " + (model.cache && model.cache.summary ? model.cache.summary : "—"));
    text("weatherZoneForecastSource", zone.sourceUrl || "Source: NOAA/NWS Coastal Waters Forecast");
    var periods = byId("weatherZoneForecastPeriods");
    if (periods) {
      periods.innerHTML = zone.available && zone.periods && zone.periods.length
        ? zone.periods.map(function (p) { return "<article><h3>" + escapeHtml(p.name || "Forecast") + "</h3><p>" + escapeHtml(p.forecast || "") + "</p></article>"; }).join("")
        : "";
    }
    setHidden("weatherZoneForecastUnavailable", zone.available);
    setHidden("weatherZoneForecastContent", !zone.available);
  }

  function renderStatus(model) {
    if (model && model.ok) {
      setError("");
    }
  }

  function bindEvents() {
    var mode = byId("weatherLocationMode");
    var refresh = byId("weatherRefreshBtn");
    if (mode) {
      mode.addEventListener("change", syncLocationMode);
    }
    if (refresh) {
      refresh.addEventListener("click", function () {
        loadWeather(collectRequestParams());
      });
    }
    bindAlertsAccordion();
    bindMapModal();
    syncLocationMode();
  }

  function bindAlertsAccordion() {
    var details = byId("weatherDetailsLink");
    var panel = byId("activeNoaaAlertsPanel");
    var body = byId("activeNoaaAlertsBody");
    function toggle() {
      if (!panel || !body) return;
      var open = panel.classList.contains("d-none") || panel.hasAttribute("hidden");
      panel.classList.toggle("d-none", !open);
      body.hidden = !open;
      panel.hidden = !open;
      if (details) details.setAttribute("aria-expanded", open ? "true" : "false");
    }
    if (details) details.addEventListener("click", toggle);
    var toggleBtn = byId("activeNoaaAlertsToggle");
    if (toggleBtn) toggleBtn.addEventListener("click", toggle);
  }

  function bindMapModal() {
    var openBtn = byId("weatherMapLayersButton");
    var modal = byId("weatherMapModal");
    var closeBtn = byId("weatherMapModalClose");
    if (!openBtn || !modal) return;
    openBtn.addEventListener("click", function () {
      var target = state.lastModel && state.lastModel.target ? state.lastModel.target : {};
      if (openBtn.disabled) {
        return;
      }
      if (!hasCoords(target)) {
        setStateBox({
          title: "Map unavailable",
          message: "Map layers need a weather location with valid coordinates."
        });
        return;
      }
      modal.hidden = false;
      modal.setAttribute("aria-hidden", "false");
      initMap(target);
    });
    function close() {
      modal.hidden = true;
      modal.setAttribute("aria-hidden", "true");
    }
    if (closeBtn) closeBtn.addEventListener("click", close);
    modal.addEventListener("click", function (event) {
      if (event.target && event.target.hasAttribute("data-weather-map-close")) close();
    });
  }

  function initMap(target) {
    if (!window.L || !hasCoords(target)) return;
    if (!state.map) {
      state.map = window.L.map("weatherLeafletMap").setView([target.lat, target.lon], 9);
      window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors"
      }).addTo(state.map);
    } else {
      state.map.setView([target.lat, target.lon], 9);
    }
    if (state.mapMarker) {
      state.mapMarker.setLatLng([target.lat, target.lon]);
    } else {
      state.mapMarker = window.L.marker([target.lat, target.lon]).addTo(state.map);
    }
    window.setTimeout(function () { state.map.invalidateSize(); }, 50);
  }

  function emptyModel(reason, message) {
    return {
      ok: false,
      target: {},
      status: { ready: false, degraded: true, reason: reason || "", messages: message ? [message] : [] },
      current: {},
      marine: {},
      forecast12h: [],
      alerts: [],
      zoneForecast: {},
      map: { layers: [] },
      cache: {},
      diagnostics: {}
    };
  }

  function hasCoords(target) {
    if (!target) return false;
    if (target.lat === null || target.lat === undefined || target.lon === null || target.lon === undefined) return false;
    if (String(target.lat).trim() === "" || String(target.lon).trim() === "") return false;
    return isFinite(Number(target.lat)) && isFinite(Number(target.lon));
  }

  function windText(current) {
    return [current.windDirectionLabel, numberText(current.windMph, "mph")].filter(Boolean).join(" ");
  }

  function conditionIcon(condition) {
    condition = String(condition || "").toLowerCase();
    if (condition.indexOf("thunder") >= 0) return "⛈";
    if (condition.indexOf("rain") >= 0 || condition.indexOf("shower") >= 0) return "☔";
    if (condition.indexOf("cloud") >= 0 || condition.indexOf("overcast") >= 0) return "☁";
    return "☀";
  }

  function waveLevel(value) {
    if (!isFinite(Number(value))) return "—";
    value = Number(value);
    if (value >= 6) return "High";
    if (value >= 3) return "Caution";
    return "Good";
  }

  function riskBadgeClass(label) {
    label = String(label || "").toLowerCase();
    if (label === "good") return "badge-good";
    if (label === "high") return "badge-danger";
    return "badge-caution";
  }

  function tideHeight(item) {
    return item && item.heightFt !== null && item.heightFt !== undefined ? numberText(item.heightFt, "ft", 2) : "—";
  }

  function tideTime(item) {
    return item && item.timeUtc ? formatTime(item.timeUtc) : "—";
  }

  function highestSeverity(alerts) {
    var order = ["Extreme", "Severe", "Moderate", "Minor", "Unknown"];
    for (var i = 0; i < order.length; i++) {
      if (alerts.some(function (a) { return a.severity === order[i]; })) {
        return "Highest: " + order[i];
      }
    }
    return "—";
  }

  function renderAlertCard(alert) {
    return "<article class=\"weather-alert-item\"><h3>" + escapeHtml(alert.event || alert.headline || "NOAA Alert") + "</h3>"
      + "<p>" + escapeHtml(alert.headline || alert.description || "") + "</p>"
      + "<small>" + escapeHtml(alert.severity || "Unknown") + " • Expires " + escapeHtml(formatTime(alert.expiresUtc)) + "</small></article>";
  }

  function formatTime(value) {
    if (!value) return "—";
    var date = new Date(value.replace(" ", "T"));
    if (isNaN(date.getTime())) return value;
    return date.toLocaleString([], { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
  }

  function formatHour(value) {
    if (!value) return "—";
    var date = new Date(value);
    if (isNaN(date.getTime())) return value;
    return date.toLocaleTimeString([], { hour: "numeric" });
  }

  function maxValue(rows, key, unit) {
    var values = rows.map(function (row) { return Number(row[key]); }).filter(function (value) { return isFinite(value); });
    if (!values.length) return "—";
    return Math.max.apply(Math, values) + unit;
  }

  function init() {
    var pageName = document.body ? String(document.body.getAttribute("data-fpw-page") || "").toLowerCase() : "";
    if (pageName !== "weather" && !byId("fpwWeatherPage")) {
      return;
    }
    bindEvents();
    loadWeather({});
  }

  document.addEventListener("DOMContentLoaded", init);
})(window, document);
