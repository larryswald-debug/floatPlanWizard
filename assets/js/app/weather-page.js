(function (window, document) {
  "use strict";

  var WEATHER_VERSION = "weather-rewrite-phase4";
  var state = {
    lastModel: null,
    loadingTimer: 0,
    loadingStartedAt: 0,
    abortController: null,
    map: null,
    mapMarker: null,
    mapOverlayController: null,
    tideRange: "today"
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

  function hasNumber(value) {
    return !(value === null || value === undefined || value === "" || !isFinite(Number(value)));
  }

  function numberTextOr(value, unit, digits, fallback) {
    return hasNumber(value) ? numberText(value, unit, digits) : fallback;
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

  function setApproxBox(target) {
    var box = byId("weatherApproxBox");
    if (!box) return;
    target = target || {};
    var warnings = safeArray(target.warnings);
    var isApproximate = !!target.isApproximate || warnings.some(function (warning) {
      return String(warning || "").toLowerCase().indexOf("zip-area coordinates are approximate") >= 0;
    });
    if (!isApproximate) {
      box.classList.add("d-none");
      box.setAttribute("hidden", "hidden");
      return;
    }
    var message = byId("weatherApproxMessage");
    if (message) {
      message.textContent = "Approximate weather for ZIP area " + display(target.zip, "selected") + ". ZIP-area coordinates may not match exact marina or home-port location.";
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
    setApproxBox(model.target);
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
    model.visibilityFallback = model.visibilityFallback || {};
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
    if (reason === "ZIP_NOT_FOUND") {
      setStateBox({
        title: "ZIP was not found",
        message: firstStatusMessage(model, "No approved ZIP-area coordinate was found for this ZIP code.")
      });
      return;
    }
    if (reason === "INVALID_ZIP") {
      setStateBox({
        title: "ZIP needs attention",
        message: firstStatusMessage(model, "Enter a valid 5-digit ZIP code.")
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
    text("weatherLocationDetailLabel", target.isApproximate ? "Approximate ZIP area" : (target.sourceType || "weather target"));
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
    var risk = marine.riskLevel || marine.RISKLEVEL || "Unknown";
    if (panel) {
      panel.classList.remove("marine-risk-good", "marine-risk-caution", "marine-risk-high");
      panel.classList.add("marine-risk-" + risk.toLowerCase());
    }
    text("weatherRiskValue", risk);
    text("weatherRiskSubtext", risk === "Unknown" ? "Weather data is not ready." : (risk === "Good" ? "Favorable for nearshore boating" : "Use caution for small craft"));
    text("weatherRiskWind", current.windMph ? "Wind " + numberText(current.windMph, "mph") : "Wind —");
    text("weatherRiskGusts", hasNumber(current.gustMph) ? "Gusts up to " + numberText(current.gustMph, "mph") : "Gusts not reported");
    text("weatherRiskSeas", marine.seasFt || marine.waveHeightFt ? "Seas " + numberText(marine.seasFt || marine.waveHeightFt, "ft", 1) : "Seas —");
    text("weatherRiskSeasNote", marine.wavePeriodSec ? "Period " + numberText(marine.wavePeriodSec, "sec") : "—");
    var visibilityFallback = model.visibilityFallback || {};
    var visibilityValue = hasNumber(current.visibilityMi) ? current.visibilityMi : (hasNumber(visibilityFallback.visibilityMi) ? visibilityFallback.visibilityMi : null);
    var visibilityFromFallback = !hasNumber(current.visibilityMi) && hasNumber(visibilityFallback.visibilityMi);
    text("weatherRiskVisibility", hasNumber(visibilityValue) ? "Visibility " + numberText(visibilityValue, "mi", 1) : "Visibility —");
    text("weatherRiskVisibilityNote", hasNumber(visibilityValue) ? (visibilityFromFallback ? "From " + (visibilityFallback.stationId || "nearby station") : "Station " + (current.stationId || "current")) : "Not reported");
    text("weatherRiskAlerts", alerts.length ? alerts.length + " active" : "None active");
    text("weatherRiskRecommendation", marine.recommendation || marine.RECOMMENDATION || "Review official NOAA conditions before departure.");
  }

  function renderCurrent(current) {
    text("weatherConditionText", current.available ? (current.condition || "Current conditions available") : "Current conditions temporarily unavailable.");
    text("weatherConditionIcon", conditionIcon(current.condition));
    text("weatherCurrentTemp", numberText(current.tempF, "°F"));
    text("weatherFeelsLike", numberText(current.feelsLikeF, "°F"));
    text("weatherCurrentWind", current.windMph ? windText(current) : "—");
    text("weatherCurrentGusts", numberTextOr(current.gustMph, "mph", undefined, "Not reported"));
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
    text("weatherWaveDirection", marine.waveDirectionLabel || marine.WAVEDIRECTIONLABEL || (hasNumber(marine.waveDirectionDeg) ? numberText(marine.waveDirectionDeg, "°") : "Not issued"));
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
    alerts = sortAlertsForDisplay(safeArray(alerts));
    var count = alerts.length;
    var icon = byId("weatherAlertIcon");
    var activeList = byId("weatherAlertsActiveNow");
    var highestEl = byId("weatherAlertHighest");
    var stateEl = byId("weatherAlertsPanelState");
    var list = byId("activeNoaaAlertsList");

    text("weatherAlertStatus", count ? count + " Active" : "No Active Alerts");
    text("weatherAlertSummary", count ? "Review active NOAA marine alerts" : "No active NOAA alerts for this location.");
    if (highestEl) {
      highestEl.textContent = count ? "Highest Risk: " + alertName(alerts[0]) : "";
    }
    text("weatherAlertsCheckedAt", model.generatedAtUtc ? formatTime(model.generatedAtUtc) : "—");
    if (icon) {
      icon.textContent = count ? "!" : "✓";
    }
    if (activeList) {
      activeList.innerHTML = count ? alerts.slice(0, 4).map(renderAlertMiniRow).join("") : "<li>No active NOAA alerts.</li>";
    }
    text("weatherAlertsPanelTitle", count ? "Active NOAA Alerts for " + alertPanelLocation(model) : "No Active NOAA Alerts");
    text("weatherAlertsPanelBadge", count ? count + " Active" : "No Active Alerts");
    if (stateEl) {
      stateEl.innerHTML = count ? "" : "<strong>No active NOAA alerts for this location.</strong><span>Conditions can change quickly. Review the latest marine forecast before departure.</span>";
    }
    if (list) {
      list.innerHTML = count ? alerts.map(function (alert, index) { return renderAlertCard(alert, index + 1); }).join("") : "";
    }
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
    var maxGust = maxForecastNumber(rows, "gustMph");
    var maxRain = maxForecastNumber(rows, "precipChancePct");
    tbody.innerHTML = rows.map(function (row) {
      var riskLabel = riskBadgeDisplay(row.riskLabel || "Unknown");
      return "<tr>"
        + "<td>" + escapeHtml(formatHour(row.timeLabel)) + "</td>"
        + "<td>" + escapeHtml(hasNumber(row.windMph) ? row.windDirectionLabel + " " + numberText(row.windMph, "mph") : "Not reported") + "</td>"
        + "<td>" + escapeHtml(numberTextOr(row.gustMph, "mph", undefined, "Not reported")) + "</td>"
        + "<td>" + escapeHtml(numberText(row.seasFt, "", 1)) + "</td>"
        + "<td>" + escapeHtml(forecastPercentText(row.precipChancePct, "Not issued")) + "</td>"
        + "<td>" + escapeHtml(forecastTempText(row.tempF)) + "</td>"
        + "<td>" + escapeHtml(forecastSkyIcon(row.condition)) + "</td>"
        + "<td><span class=\"risk-badge " + riskBadgeClass(riskLabel) + "\">" + escapeHtml(riskLabel) + "</span></td>"
        + "</tr>";
    }).join("");
    text("weatherHourlySummary", "Wind easing this evening • Gusts peak near " + (hasNumber(maxGust) ? numberText(maxGust, "mph") : "—") + " • " + (hasNumber(maxRain) ? "Rain risk up to " + forecastPercentText(maxRain, "—") : "No rain expected"));
  }

  function renderTide(marine) {
    var tideWarning = safeArray(marine.warnings)[0] || "Tide data is temporarily unavailable for this location.";
    var rangeItems = tideItemsForRange(marine, state.tideRange);
    var hasTideSeries = rangeItems.length > 0;
    var highItem = highestTide(rangeItems);
    var lowItem = lowestTide(rangeItems);
    var nextHigh = marine.nextHigh || nextHighTide(rangeItems, state.tideRange) || highItem;
    var firstItem = rangeItems[0] || null;

    text("weatherTideChartStation", marine.tideStation || "—");
    text("tideGraphTitle", "Tide (ft)");
    text("tideGraphNowValue", "Now " + numberText(marine.tideLevelFt, "ft", 2));
    text("tideGraphStation", marine.tideStation || "");
    text("tideGraphStart", hasTideSeries ? tideTime(rangeItems[0]) : "—");
    text("tideGraphEnd", hasTideSeries ? tideTime(rangeItems[rangeItems.length - 1]) : "—");
    text("weatherTideSummaryCurrentLabel", state.tideRange === "tomorrow" ? "First" : "Current");
    text("weatherTideSummaryCurrent", state.tideRange === "tomorrow" ? tideHeight(firstItem) : numberText(marine.tideLevelFt, "ft", 2));
    text("weatherTideSummaryCurrentTrend", state.tideRange === "tomorrow" ? tideTimeOnly(firstItem) : (marine.tideTrend || "—"));
    text("weatherTideSummaryHighTime", tideTimeOnly(highItem || marine.nextHigh));
    text("weatherTideSummaryHighHeight", tideHeight(highItem || marine.nextHigh));
    text("weatherTideSummaryLowTime", tideTimeOnly(lowItem || marine.nextLow));
    text("weatherTideSummaryLowHeight", tideHeight(lowItem || marine.nextLow));
    text("weatherTideSummaryNextHighTime", tideTimeOnly(nextHigh));
    text("weatherTideSummaryNextHighHeight", tideHeight(nextHigh));
    text("weatherTidePlanningNote", hasTideSeries ? tidePlanningNote(marine, nextHigh, lowItem) : tideWarning);
    text("tideGraphEmpty", tideWarning);
    updateTideRangeButtons();
    setHidden("tideGraph", !hasTideSeries);
    setHidden("tideGraphEmpty", hasTideSeries);
    drawTideGraph(rangeItems, marine);
  }

  function tidePredictionItems(marine) {
    marine = marine || {};
    var raw = safeArray(marine.tidePredictions);
    if (!raw.length) raw = safeArray(marine.TIDEPREDICTIONS);
    if (!raw.length) {
      raw = [marine.nextLow, marine.nextHigh].filter(Boolean);
    }
    return raw.map(function (item) {
      item = item || {};
      return {
        timeUtc: item.timeUtc || item.TIMEUTC || item.t || item.T || "",
        heightFt: item.heightFt !== undefined ? item.heightFt : (item.HEIGHTFT !== undefined ? item.HEIGHTFT : item.v),
        type: item.type || item.TYPE || ""
      };
    }).filter(function (item) {
      return item.timeUtc && hasNumber(item.heightFt);
    }).sort(function (a, b) {
      return tideDate(a).getTime() - tideDate(b).getTime();
    });
  }

  function tideItemsForRange(marine, range) {
    var items = tidePredictionItems(marine);
    var target = new Date();
    if (range === "tomorrow") {
      target = new Date(target.getFullYear(), target.getMonth(), target.getDate() + 1);
    }
    var filtered = items.filter(function (item) {
      var itemDate = tideDate(item);
      return !isNaN(itemDate.getTime()) && sameDay(itemDate, target);
    });
    if (!filtered.length && range === "today" && items.length) {
      return items.slice(0, Math.min(items.length, 4));
    }
    return filtered;
  }

  function tideDate(item) {
    var value = item && item.timeUtc ? String(item.timeUtc) : "";
    var date = new Date(value.replace(" ", "T"));
    return date;
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  function tideGraphSeriesBounds(items) {
    var dates = safeArray(items).map(function (item) {
      return tideDate(item);
    }).filter(function (date) {
      return date && !isNaN(date.getTime());
    }).sort(function (a, b) {
      return a.getTime() - b.getTime();
    });
    if (dates.length < 2) return null;
    return {
      startMs: dates[0].getTime(),
      endMs: dates[dates.length - 1].getTime()
    };
  }

  function highestTide(items) {
    return tideExtreme(items, 1);
  }

  function lowestTide(items) {
    return tideExtreme(items, -1);
  }

  function tideExtreme(items, direction) {
    items = safeArray(items).filter(function (item) { return hasNumber(item.heightFt); });
    if (!items.length) return null;
    return items.reduce(function (best, item) {
      return direction > 0
        ? (Number(item.heightFt) > Number(best.heightFt) ? item : best)
        : (Number(item.heightFt) < Number(best.heightFt) ? item : best);
    }, items[0]);
  }

  function nextHighTide(items, range) {
    var now = new Date();
    var highs = safeArray(items).filter(function (item) {
      return String(item.type || "").toUpperCase() === "H";
    });
    if (range === "today") {
      var upcoming = highs.filter(function (item) {
        return tideDate(item).getTime() >= now.getTime();
      });
      if (upcoming.length) return upcoming[0];
    }
    return highs.length ? highs[0] : null;
  }

  function tidePlanningNote(marine, highItem, lowItem) {
    if (highItem && lowItem) {
      return "Review low tide around " + tideTime(lowItem) + " and high tide around " + tideTime(highItem) + " before planning shallow-water routes.";
    }
    if (highItem) {
      return "Review the next high tide around " + tideTime(highItem) + " before departure.";
    }
    if (lowItem) {
      return "Review the next low tide around " + tideTime(lowItem) + " before departure.";
    }
    return marine.available ? "Review tide timing for shallow-water routes before departure." : "Tide data is temporarily unavailable for this location.";
  }

  function drawTideGraph(items, marine) {
    var svg = byId("tideGraphSvg");
    if (!svg) return;
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    items = safeArray(items);
    if (!items.length) return;

    var rect = svg.getBoundingClientRect ? svg.getBoundingClientRect() : null;
    var width = Math.round((rect && rect.width) ? rect.width : (svg.clientWidth || 320));
    var height = Math.round((rect && rect.height) ? rect.height : (svg.clientHeight || 150));
    if (width < 160) width = 320;
    if (height < 80) height = 150;
    svg.setAttribute("viewBox", "0 0 " + width + " " + height);

    var padLeft = 30;
    var padRight = 30;
    var padTop = 8;
    var padBottom = 16;
    var plotWidth = width - padLeft - padRight;
    var plotHeight = height - padTop - padBottom;
    var values = items.map(function (item) { return Number(item.heightFt); });
    if (state.tideRange === "today" && hasNumber(marine.tideLevelFt)) {
      values.push(Number(marine.tideLevelFt));
    }
    var min = Math.min.apply(Math, values);
    var max = Math.max.apply(Math, values);
    if (min === max) {
      min -= 0.5;
      max += 0.5;
    }
    var pad = Math.max(0.25, (max - min) * 0.15);
    min -= pad;
    max += pad;

    var bounds = tideGraphSeriesBounds(items);
    var dx = items.length > 1 ? plotWidth / (items.length - 1) : 0;
    function y(value) {
      return padTop + plotHeight * (1 - ((Number(value) - min) / (max - min)));
    }

    var points = items.map(function (item, index) {
      var date = tideDate(item);
      var x = padLeft + (dx * index);
      if (bounds && date && !isNaN(date.getTime()) && bounds.endMs > bounds.startMs) {
        var ratio = (date.getTime() - bounds.startMs) / (bounds.endMs - bounds.startMs);
        x = padLeft + (plotWidth * clampNumber(ratio, 0, 1));
      }
      return {
        item: item,
        h: Number(item.heightFt),
        dt: date,
        x: x,
        y: y(item.heightFt)
      };
    }).filter(function (point) {
      return Number.isFinite(point.h);
    });
    if (!points.length) return;

    function pathPoint(point, index) {
      return (index === 0 ? "M" : "L") + roundSvg(point.x) + " " + roundSvg(point.y) + " ";
    }
    var path = points.map(pathPoint).join("");
    var areaPath = path + "L " + roundSvg(points[points.length - 1].x) + " " + roundSvg(height - padBottom)
      + " L " + roundSvg(points[0].x) + " " + roundSvg(height - padBottom) + " Z";

    var defs = appendSvg(svg, "defs", {});
    var gradient = appendSvg(defs, "linearGradient", { id: "weatherTideFill", x1: "0", y1: "0", x2: "0", y2: "1" });
    appendSvg(gradient, "stop", { offset: "0%", "stop-color": "rgba(59,130,246,.45)" });
    appendSvg(gradient, "stop", { offset: "100%", "stop-color": "rgba(59,130,246,0)" });

    var xAxisY = height - padBottom;
    appendSvg(svg, "line", { class: "fpw-wx__tideAxisLine", x1: padLeft, y1: padTop, x2: padLeft, y2: xAxisY });
    appendSvg(svg, "line", { class: "fpw-wx__tideAxisLine", x1: padLeft, y1: xAxisY, x2: width - padRight, y2: xAxisY });

    for (var yi = 0; yi <= 4; yi++) {
      var fracY = yi / 4;
      var yVal = max - ((max - min) * fracY);
      var yPos = padTop + (plotHeight * fracY);
      appendSvg(svg, "line", { class: "fpw-wx__tideAxisTick", x1: padLeft - 4, y1: yPos, x2: padLeft, y2: yPos });
      appendSvg(svg, "text", { class: "fpw-wx__tideAxisLabel y", x: padLeft - 6, y: yPos + 3 }, yVal.toFixed(1));
    }

    var xTickCount = Math.min(5, points.length);
    for (var xi = 0; xi < xTickCount; xi++) {
      var pointIndex = Math.round((xi * (points.length - 1)) / Math.max(1, xTickCount - 1));
      var tickPoint = points[Math.max(0, Math.min(points.length - 1, pointIndex))];
      appendSvg(svg, "line", { class: "fpw-wx__tideAxisTick", x1: tickPoint.x, y1: xAxisY, x2: tickPoint.x, y2: xAxisY + 4 });
      appendSvg(svg, "text", { class: "fpw-wx__tideAxisLabel x", x: tickPoint.x, y: height - 1 }, formatTideAxisHour(tickPoint.item));
    }

    appendSvg(svg, "path", { d: areaPath, fill: "url(#weatherTideFill)" });
    appendSvg(svg, "path", { d: path, fill: "none", stroke: "rgba(59,130,246,.9)", "stroke-width": 2 });

    if (state.tideRange === "today" && hasNumber(marine.tideLevelFt)) {
      var currentPoint = tideCurrentPoint(points, marine.tideLevelFt);
      if (currentPoint) {
        appendSvg(svg, "line", {
          class: "fpw-wx__tideGuide",
          x1: padLeft,
          y1: currentPoint.y,
          x2: width - padRight,
          y2: currentPoint.y
        });
        appendSvg(svg, "circle", { class: "fpw-wx__tideNowHalo", cx: currentPoint.x, cy: currentPoint.y, r: 6 });
        appendSvg(svg, "circle", { class: "fpw-wx__tideNowDot", cx: currentPoint.x, cy: currentPoint.y, r: 3 });
      }
    }

    var highPoint = points.reduce(function (best, point) {
      return point.h > best.h ? point : best;
    }, points[0]);
    var lowPoint = points.reduce(function (best, point) {
      return point.h < best.h ? point : best;
    }, points[0]);
    appendTideExtrema(svg, highPoint, "high", true, padLeft, width - padRight, padTop, height - padBottom);
    appendTideExtrema(svg, lowPoint, "low", highPoint && Math.abs(highPoint.x - lowPoint.x) < 44, padLeft, width - padRight, padTop, height - padBottom);
  }

  function tideCurrentPoint(points, tideLevelFt) {
    var nowMs = Date.now();
    for (var i = 0; i < points.length - 1; i++) {
      var a = points[i];
      var b = points[i + 1];
      if (!a.dt || !b.dt || isNaN(a.dt.getTime()) || isNaN(b.dt.getTime())) continue;
      var aMs = a.dt.getTime();
      var bMs = b.dt.getTime();
      if (bMs <= aMs) continue;
      if (nowMs >= aMs && nowMs <= bMs) {
        var ratio = (nowMs - aMs) / (bMs - aMs);
        return {
          x: a.x + ((b.x - a.x) * ratio),
          y: a.y + ((b.y - a.y) * ratio)
        };
      }
    }
    var nearest = null;
    points.forEach(function (point) {
      if (!point.dt || isNaN(point.dt.getTime())) return;
      var diff = Math.abs(nowMs - point.dt.getTime());
      if (!nearest || diff < nearest.diff) {
        nearest = { diff: diff, point: point };
      }
    });
    if (nearest) {
      return {
        x: nearest.point.x,
        y: nearest.point.y
      };
    }
    return null;
  }

  function appendTideExtrema(svg, point, type, preferAbove, minX, maxX, minY, maxY) {
    if (!point) return;
    var label = point.h.toFixed(1) + " ft";
    var labelWidth = Math.max(46, label.length * 4.2);
    var x = clampNumber(point.x - (labelWidth / 2), minX + 2, maxX - labelWidth - 2);
    var y = point.y + (preferAbove ? -7 : 11);
    if (preferAbove && y < minY + 7) y = point.y + 11;
    if (!preferAbove && y > maxY - 2) y = point.y - 7;
    appendSvg(svg, "circle", { class: "fpw-wx__tideExtDot " + type, cx: point.x, cy: point.y, r: 2.8 });
    appendSvg(svg, "text", { class: "fpw-wx__tideExtLabel " + type, x: x, y: y }, label);
  }

  function formatTideAxisHour(item) {
    var date = tideDate(item);
    if (!date || isNaN(date.getTime())) return "";
    var hour24 = date.getHours();
    var hour = hour24 % 12;
    var minute = date.getMinutes();
    var minuteText = minute < 10 ? "0" + minute : String(minute);
    return String(hour === 0 ? 12 : hour) + ":" + minuteText + (hour24 < 12 ? "a" : "p");
  }

  function clampNumber(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function appendSvg(svg, tag, attrs, content) {
    var node = document.createElementNS("http://www.w3.org/2000/svg", tag);
    Object.keys(attrs || {}).forEach(function (key) {
      node.setAttribute(key, attrs[key]);
    });
    if (content !== undefined) node.textContent = content;
    svg.appendChild(node);
    return node;
  }

  function roundSvg(value) {
    return Math.round(Number(value) * 10) / 10;
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

  function zoneForecastCacheEntry(model) {
    var entries = safeArray(model && model.cache ? model.cache.entries : []);
    for (var i = 0; i < entries.length; i += 1) {
      var entry = entries[i] || {};
      var key = entry.key || entry.KEY || "";
      if (String(key).indexOf("nws:cwf:") === 0) {
        return entry;
      }
    }
    return {};
  }

  function zoneCacheStatusLabel(status) {
    var value = String(status || "").toLowerCase();
    if (value === "miss" || value === "fresh_fetch" || value === "stale-refresh") return "Live fetch";
    if (value === "hit" || value === "cache_hit") return "Cached";
    if (value === "bypass") return "Cache bypassed";
    if (value === "error") return "Error";
    return status ? display(status, "Unknown") : "Unknown";
  }

  function zoneProductUrl(office) {
    var code = String(office || "").trim();
    return code ? "https://forecast.weather.gov/product.php?issuedby=" + encodeURIComponent(code) + "&product=CWF&site=NWS" : "";
  }

  function zonePeriodTitle(value) {
    return display(value, "Forecast").toLowerCase().replace(/(^|[\s/-])([a-z])/g, function (match, prefix, letter) {
      return prefix + letter.toUpperCase();
    });
  }

  function renderZone(zone, model) {
    var sourceLabel = "NOAA/NWS Coastal Waters Forecast";
    var office = zone.office || "";
    var cacheEntry = zoneForecastCacheEntry(model);
    var expiresAt = cacheEntry.expiresAtUtc || cacheEntry.EXPIRESATUTC || "";
    var sourceEl = byId("weatherZoneForecastSource");
    var sourceUrl = zoneProductUrl(office);

    text("weatherZoneForecastMeta", zone.available ? [zone.zoneId, zone.zoneName].filter(Boolean).join(" · ") : (zone.reason || "—"));
    text("weatherZoneForecastOffice", zone.available && office ? "Issued by NWS " + office : "Source: " + sourceLabel);
    text("weatherZoneForecastSynopsis", zone.synopsis || "—");
    text("weatherZoneForecastCacheMeta", "Provider updated: " + (zone.issuedAt || zone.updatedAt || (model.generatedAtUtc ? formatTime(model.generatedAtUtc) : "—")) + " • Cache: " + zoneCacheStatusLabel(cacheEntry.status || cacheEntry.STATUS || "") + " • Expires: " + (expiresAt ? formatTime(expiresAt) : "—"));
    if (sourceEl) {
      sourceEl.innerHTML = sourceUrl
        ? "Source: <a href=\"" + escapeHtml(sourceUrl) + "\" target=\"_blank\" rel=\"noopener\">" + escapeHtml(sourceLabel) + "</a>"
        : "Source: " + escapeHtml(sourceLabel);
    }
    var periods = byId("weatherZoneForecastPeriods");
    if (periods) {
      periods.innerHTML = zone.available && zone.periods && zone.periods.length
        ? zone.periods.map(function (p) { return "<article class=\"zone-forecast-period\"><h3>" + escapeHtml(zonePeriodTitle(p.name || "Forecast")) + "</h3><p>" + escapeHtml(p.forecast || "") + "</p></article>"; }).join("")
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
    bindTideRangeButtons();
    bindAlertsAccordion();
    bindMapModal();
    syncLocationMode();
  }

  function bindTideRangeButtons() {
    var buttons = document.querySelectorAll("[data-tide-range]");
    Array.prototype.forEach.call(buttons, function (button) {
      button.addEventListener("click", function () {
        var range = button.getAttribute("data-tide-range") || "today";
        if (range !== "today" && range !== "tomorrow") {
          return;
        }
        state.tideRange = range;
        updateTideRangeButtons();
        if (state.lastModel && state.lastModel.marine) {
          renderTide(state.lastModel.marine);
        }
      });
    });
    updateTideRangeButtons();
  }

  function updateTideRangeButtons() {
    var buttons = document.querySelectorAll("[data-tide-range]");
    Array.prototype.forEach.call(buttons, function (button) {
      var active = (button.getAttribute("data-tide-range") || "today") === state.tideRange;
      button.classList.toggle("toggle-active", active);
      button.setAttribute("aria-pressed", active ? "true" : "false");
    });
  }

  function setAlertsPanelExpanded(expanded) {
    var panel = byId("activeNoaaAlertsPanel");
    var body = byId("activeNoaaAlertsBody");
    var toggle = byId("activeNoaaAlertsToggle");
    var trigger = byId("weatherDetailsLink");
    if (!panel || !body || !toggle) return;

    body.hidden = !expanded;
    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    toggle.setAttribute("aria-label", expanded ? "Hide active NOAA alerts" : "Show active NOAA alerts");
    panel.classList.toggle("weather-alerts-panel--expanded", expanded);
    panel.classList.toggle("weather-alerts-panel--collapsed", !expanded);
    if (trigger) trigger.setAttribute("aria-expanded", expanded ? "true" : "false");
  }

  function showAlertsPanel() {
    var panel = byId("activeNoaaAlertsPanel");
    if (!panel) return;
    panel.hidden = false;
    panel.classList.remove("d-none");
    setAlertsPanelExpanded(true);
    if (typeof panel.scrollIntoView === "function") {
      panel.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  function bindAlertsAccordion() {
    var trigger = byId("weatherDetailsLink");
    var panel = byId("activeNoaaAlertsPanel");
    var header = byId("activeNoaaAlertsHeader");
    var toggle = byId("activeNoaaAlertsToggle");

    if (trigger && trigger.dataset.bound !== "true") {
      trigger.dataset.bound = "true";
      trigger.addEventListener("click", function (event) {
        event.preventDefault();
        showAlertsPanel();
      });
    }

    if (toggle && toggle.dataset.bound !== "true") {
      toggle.dataset.bound = "true";
      toggle.addEventListener("click", function (event) {
        var expanded = toggle.getAttribute("aria-expanded") === "true";
        event.preventDefault();
        event.stopPropagation();
        setAlertsPanelExpanded(!expanded);
      });
    }

    if (header && header.dataset.bound !== "true") {
      header.dataset.bound = "true";
      header.addEventListener("click", function (event) {
        var toggleButton = byId("activeNoaaAlertsToggle");
        var expanded = toggleButton && toggleButton.getAttribute("aria-expanded") === "true";
        if (event.target && event.target.closest && event.target.closest("button")) return;
        setAlertsPanelExpanded(!expanded);
      });
    }

    if (panel && panel.dataset.bound !== "true") {
      panel.dataset.bound = "true";
      panel.addEventListener("click", function (event) {
        var button = event.target && event.target.closest ? event.target.closest("[data-weather-alert-detail]") : null;
        var detailId = "";
        var detail = null;
        var isOpen = false;
        if (!button) return;
        detailId = button.getAttribute("aria-controls") || "";
        detail = detailId ? byId(detailId) : null;
        if (!detail) return;
        isOpen = detail.hidden;
        detail.hidden = !isOpen;
        button.setAttribute("aria-expanded", isOpen ? "true" : "false");
      });
    }
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
    var mapEl = byId("weatherLeafletMap");
    if (!window.L || !hasCoords(target) || !mapEl) return;
    if (!state.map) {
      state.map = window.L.map(mapEl).setView([target.lat, target.lon], 9);
      window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors"
      }).addTo(state.map);
      if (window.FPW && typeof window.FPW.attachLeafletWeatherOverlays === "function") {
        state.mapOverlayController = window.FPW.attachLeafletWeatherOverlays({
          map: state.map,
          mode: "weather"
        });
      }
      mapEl.__fpwWeatherMap = state.map;
      mapEl.__fpwWeatherOverlayController = state.mapOverlayController;
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

  function forecastSkyIcon(condition) {
    condition = String(condition || "").toLowerCase();
    if (condition.indexOf("rain") >= 0 || condition.indexOf("shower") >= 0 || condition.indexOf("storm") >= 0) return "☔";
    if (condition.indexOf("cloud") >= 0 || condition.indexOf("overcast") >= 0) return "☁";
    if (condition.indexOf("night") >= 0 || (condition.indexOf("clear") >= 0 && condition.indexOf("sun") < 0)) return "☾";
    return "☀";
  }

  function forecastPercentText(value, fallback) {
    return hasNumber(value) ? Math.round(Number(value)) + "%" : fallback;
  }

  function forecastTempText(value) {
    return hasNumber(value) ? Math.round(Number(value)) + "°" : "—";
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
    if (label === "extreme" || label === "high") return "risk-high";
    if (label === "caution" || label === "moderate") return "risk-caution";
    if (label === "good" || label === "low") return "risk-good";
    return "risk-low";
  }

  function riskBadgeDisplay(label) {
    return String(label || "").toLowerCase() === "low" ? "Good" : display(label, "—");
  }

  function tideHeight(item) {
    return item && item.heightFt !== null && item.heightFt !== undefined ? numberText(item.heightFt, "ft", 2) : "—";
  }

  function tideTime(item) {
    return item && item.timeUtc ? formatTime(item.timeUtc) : "—";
  }

  function tideTimeOnly(item) {
    if (!item || !item.timeUtc) return "—";
    var date = new Date(String(item.timeUtc).replace(" ", "T"));
    if (isNaN(date.getTime())) return item.timeUtc;
    return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  }

  function alertField(alert, keys, fallback) {
    alert = alert || {};
    for (var i = 0; i < keys.length; i++) {
      var value = alert[keys[i]];
      if (value !== null && value !== undefined && value !== "") {
        return String(value);
      }
    }
    return fallback !== undefined ? fallback : "";
  }

  function alertName(alert) {
    return alertField(alert, ["event", "EVENT", "name", "NAME", "headline", "HEADLINE"], "Marine alert");
  }

  function alertRiskRank(alert) {
    var eventName = alertField(alert, ["event", "EVENT", "name", "NAME"], "").toLowerCase();
    var order = [
      "special marine warning",
      "gale warning",
      "storm warning",
      "hurricane warning",
      "tropical storm warning",
      "small craft advisory",
      "dense fog advisory",
      "coastal flood warning",
      "coastal flood advisory",
      "thunderstorm warning",
      "thunderstorm watch",
      "special weather statement",
      "marine weather statement"
    ];
    for (var i = 0; i < order.length; i++) {
      if (eventName.indexOf(order[i]) >= 0) return i;
    }
    return order.length + 1;
  }

  function alertSeverityRank(alert) {
    var severity = alertField(alert, ["severity", "SEVERITY"], "").toLowerCase();
    if (severity === "extreme") return 0;
    if (severity === "severe") return 1;
    if (severity === "moderate") return 2;
    if (severity === "minor") return 3;
    return 4;
  }

  function alertUrgencyRank(alert) {
    var urgency = alertField(alert, ["urgency", "URGENCY"], "").toLowerCase();
    if (urgency === "immediate") return 0;
    if (urgency === "expected") return 1;
    if (urgency === "future") return 2;
    if (urgency === "past") return 3;
    return 4;
  }

  function alertEffectiveTime(alert) {
    var raw = alertField(alert, ["effective", "EFFECTIVE", "onset", "ONSET", "sent", "SENT"], "");
    var parsed = raw ? Date.parse(raw) : NaN;
    return Number.isFinite(parsed) ? parsed : Number.MAX_SAFE_INTEGER;
  }

  function sortAlertsForDisplay(alerts) {
    return safeArray(alerts).slice().sort(function (a, b) {
      var rankDelta = alertRiskRank(a) - alertRiskRank(b);
      var severityDelta = alertSeverityRank(a) - alertSeverityRank(b);
      var urgencyDelta = alertUrgencyRank(a) - alertUrgencyRank(b);
      if (rankDelta) return rankDelta;
      if (severityDelta) return severityDelta;
      if (urgencyDelta) return urgencyDelta;
      return alertEffectiveTime(a) - alertEffectiveTime(b);
    });
  }

  function alertRiskClass(alert) {
    var rank = alertRiskRank(alert);
    var severity = alertSeverityRank(alert);
    if (rank <= 4 || severity <= 1) return "alert-risk-high";
    if (rank <= 8 || severity === 2) return "alert-risk-caution";
    return "alert-risk-low";
  }

  function alertExpiresValue(alert) {
    return alertField(alert, ["expiresUtc", "EXPIRESUTC", "expires", "EXPIRES", "ends", "ENDS"], "");
  }

  function formatAlertShortTime(value) {
    if (!value) return "—";
    var date = new Date(String(value).replace(" ", "T"));
    if (isNaN(date.getTime())) return value;
    return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  }

  function renderAlertMiniRow(alert) {
    var expiresValue = alertExpiresValue(alert);
    return "<li><span class=\"weather-alert-dot " + alertRiskClass(alert) + "\"></span>"
      + "<span class=\"weather-alert-mini-name\">" + escapeHtml(alertName(alert)) + "</span>"
      + "<span class=\"weather-alert-mini-expire\">" + escapeHtml(expiresValue ? "Expires " + formatAlertShortTime(expiresValue) : "Expires —") + "</span></li>";
  }

  function alertPanelLocation(model) {
    var target = model && model.target ? model.target : {};
    var name = String(target.displayName || target.DISPLAYNAME || "").trim();
    var zip = String(target.zip || target.ZIP || "").trim();
    if (name && zip && name.indexOf(zip) < 0) return name + " / ZIP " + zip;
    if (name) return name;
    return zip ? "ZIP " + zip : "selected location";
  }

  function alertWeb(alert) {
    return alertField(alert, ["web", "WEB", "url", "URL"], "");
  }

  function alertEffectiveValue(alert) {
    return alertField(alert, ["effective", "EFFECTIVE", "effectiveUtc", "EFFECTIVEUTC", "onset", "ONSET", "sent", "SENT"], "");
  }

  function formatAlertDetailTime(value) {
    if (!value) return "—";
    var date = new Date(String(value).replace(" ", "T"));
    if (isNaN(date.getTime())) return value;
    return date.toLocaleDateString([], { month: "short", day: "numeric" })
      + " at " + date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  }

  function renderAlertMeta(label, value, className) {
    return "<div" + (className ? " class=\"" + className + "\"" : "") + "><dt>" + escapeHtml(label) + "</dt><dd>" + escapeHtml(value || "—") + "</dd></div>";
  }

  function renderAlertDetailField(label, value, className) {
    return "<div" + (className ? " class=\"" + className + "\"" : "") + "><h4>" + escapeHtml(label) + "</h4><p>" + escapeHtml(value || "—") + "</p></div>";
  }

  function renderAlertDetailBlock(alert, detailId) {
    var description = alertField(alert, ["description", "DESCRIPTION"], "—");
    var instruction = alertField(alert, ["instruction", "INSTRUCTION"], "—");
    var headline = alertField(alert, ["headline", "HEADLINE"], alertName(alert));
    var source = alertField(alert, ["senderName", "SENDERNAME", "sender", "SENDER"], "—");
    var area = alertField(alert, ["areaDesc", "AREADESC"], "—");
    return "<div class=\"weather-alert-detail\" id=\"" + escapeHtml(detailId) + "\" hidden>"
      + "<div class=\"weather-alert-detail-grid\">"
      + renderAlertDetailField("Headline", headline)
      + renderAlertDetailField("Instruction", instruction)
      + renderAlertDetailField("Source", source)
      + renderAlertDetailField("Effective", formatAlertDetailTime(alertEffectiveValue(alert)))
      + renderAlertDetailField("Expires", formatAlertDetailTime(alertExpiresValue(alert)))
      + renderAlertDetailField("Area", area)
      + renderAlertDetailField("Description", description, "weather-alert-detail-wide")
      + "</div><div class=\"weather-alert-disclaimer\">Use official NOAA/NWS sources and local marine safety channels for final go/no-go decisions.</div>"
      + "</div>";
  }

  function renderAlertCard(alert, index) {
    var name = alertName(alert);
    var headline = alertField(alert, ["headline", "HEADLINE", "description", "DESCRIPTION"], "");
    var severity = alertField(alert, ["severity", "SEVERITY"], "Unknown");
    var urgency = alertField(alert, ["urgency", "URGENCY"], "Unknown");
    var certainty = alertField(alert, ["certainty", "CERTAINTY"], "Unknown");
    var effective = formatAlertDetailTime(alertEffectiveValue(alert));
    var expires = formatAlertDetailTime(alertExpiresValue(alert));
    var area = alertField(alert, ["areaDesc", "AREADESC"], "—");
    var web = alertWeb(alert);
    var detailId = "weatherAlertDetail" + index;
    return "<article class=\"weather-alert-row " + alertRiskClass(alert) + "\">"
      + "<div class=\"weather-alert-row__main\"><div><h3>" + escapeHtml(name) + "</h3><p>" + escapeHtml(headline) + "</p></div>"
      + "<dl class=\"weather-alert-meta-grid\">"
      + renderAlertMeta("Severity", severity)
      + renderAlertMeta("Urgency", urgency)
      + renderAlertMeta("Certainty", certainty)
      + renderAlertMeta("Effective", effective)
      + renderAlertMeta("Expires", expires)
      + renderAlertMeta("Area", area, "weather-alert-area")
      + "</dl><div class=\"weather-alert-row__actions\"><button type=\"button\" class=\"weather-alert-detail-btn\" aria-expanded=\"false\" aria-controls=\"" + escapeHtml(detailId) + "\" data-weather-alert-detail=\"1\">Details</button>"
      + (web ? "<a class=\"weather-alert-official-link\" href=\"" + escapeHtml(web) + "\" target=\"_blank\" rel=\"noopener noreferrer\" hidden aria-hidden=\"true\" tabindex=\"-1\">Official NOAA Alert</a>" : "")
      + "</div></div>"
      + renderAlertDetailBlock(alert, detailId)
      + "</article>";
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

  function maxForecastNumber(rows, key) {
    var values = rows.map(function (row) { return row[key]; }).filter(hasNumber).map(function (value) { return Number(value); });
    return values.length ? Math.max.apply(Math, values) : null;
  }

  function maxValue(rows, key, unit) {
    var values = rows.map(function (row) { return row[key]; }).filter(hasNumber).map(function (value) { return Number(value); });
    if (!values.length) return "—";
    return Math.max.apply(Math, values) + unit;
  }

  function maxValueOr(rows, key, unit, fallback) {
    var value = maxValue(rows, key, unit);
    return value === "—" ? fallback : "peak near " + value;
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








