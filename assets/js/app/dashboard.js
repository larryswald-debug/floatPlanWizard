// Updated to launch the float plan wizard in a modal and refresh after save.
(function (window, document) {
  "use strict";
  // Boater-first weather view: prioritize summary, alerts, and readable forecast cards.

  window.FPW = window.FPW || {};
  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var modules = window.FPW.DashboardModules || {};

  var BASE_PATH = window.FPW_BASE || "";
  var FALLBACK_LOGIN_URL = BASE_PATH + "/index.cfm";
  var WEATHER_BASE_URL = "http://localhost:8500///fpw/api/v1/weather.cfc?method=handle&action=zip&zip=";

  function getLoginUrl() {
    if (window.AppAuth && window.AppAuth.loginUrl) {
      return window.AppAuth.loginUrl;
    }
    return FALLBACK_LOGIN_URL;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = getLoginUrl();
  }

  function populateUserInfo(user) {
    var nameEl = document.getElementById("userName");
    var emailEl = document.getElementById("userEmail");

    if (nameEl) {
      nameEl.textContent = (user && user.NAME) ? user.NAME : "";
    }

    if (emailEl) {
      emailEl.textContent = (user && user.EMAIL) ? user.EMAIL : "";
    }
  }

  function toggleHidden(el, isHidden) {
    if (!el) return;
    if (isHidden) {
      el.classList.add("d-none");
    } else {
      el.classList.remove("d-none");
    }
  }

  function setWeatherError(message) {
    var errorEl = document.getElementById("weatherError");
    if (!errorEl) return;
    errorEl.textContent = message || "We couldn't load weather right now. Please try again.";
    toggleHidden(errorEl, false);
  }

  function clearWeatherError() {
    var errorEl = document.getElementById("weatherError");
    if (!errorEl) return;
    errorEl.textContent = "";
    toggleHidden(errorEl, true);
  }

  function mapAlertSeverity(severity) {
    var normalized = (severity || "").toString().toLowerCase();
    if (normalized === "extreme" || normalized === "severe") {
      return "critical";
    }
    if (normalized === "moderate") {
      return "warning";
    }
    return "info";
  }

  function renderWeatherAlerts(alerts) {
    var listEl = document.getElementById("weatherAlertsList");
    var emptyEl = document.getElementById("weatherAlertsEmpty");
    if (!listEl || !emptyEl) return;

    listEl.innerHTML = "";
    var items = Array.isArray(alerts) ? alerts.slice(0, 2) : [];
    if (!items.length) {
      toggleHidden(emptyEl, false);
      return;
    }
    toggleHidden(emptyEl, true);

    items.forEach(function (alert) {
      var severity = alert && alert.severity ? alert.severity : "";
      var label = severity ? severity.toString().toUpperCase() : "INFO";
      var title = (alert && (alert.headline || alert.event)) ? (alert.headline || alert.event) : "Marine alert";
      var instruction = (alert && alert.instruction) ? alert.instruction : "";
      var severityClass = "fpw-badge--" + mapAlertSeverity(severity);

      var li = document.createElement("li");
      li.className = "fpw-alert fpw-alert--" + mapAlertSeverity(severity);

      var stripe = document.createElement("div");
      stripe.className = "fpw-alert__stripe";

      var main = document.createElement("div");
      main.className = "fpw-alert__main";

      var meta = document.createElement("div");
      meta.className = "d-flex align-items-center gap-2";

      var badge = document.createElement("span");
      badge.className = "fpw-badge " + severityClass;
      badge.textContent = label;
      meta.appendChild(badge);

      var titleEl = document.createElement("div");
      titleEl.className = "fpw-alert__title";
      titleEl.textContent = title;

      main.appendChild(meta);
      main.appendChild(titleEl);

      if (instruction) {
        var instructionEl = document.createElement("div");
        instructionEl.className = "fpw-alert__message";
        instructionEl.textContent = instruction;
        main.appendChild(instructionEl);
      }

      li.appendChild(stripe);
      li.appendChild(main);
      listEl.appendChild(li);
    });
  }

  function renderWeatherForecast(forecast) {
    var bodyEl = document.getElementById("weatherForecastBody");
    var emptyEl = document.getElementById("weatherForecastEmpty");
    var hiLoEl = document.getElementById("weatherHiLo");
    var summaryEl = document.getElementById("weatherSummary");
    if (!bodyEl || !emptyEl) return;

    bodyEl.innerHTML = "";
    var rows = Array.isArray(forecast) ? forecast.slice(0, 6) : [];
    var allPeriods = Array.isArray(forecast) ? forecast : [];
    if (hiLoEl) {
      renderWeatherHiLow(allPeriods, hiLoEl, summaryEl);
    }
    if (!rows.length) {
      toggleHidden(emptyEl, false);
      return;
    }
    toggleHidden(emptyEl, true);

    rows.forEach(function (period) {
      var name = period && period.name ? period.name : "";
      var startTime = period && period.startTime ? period.startTime : "";
      var when = name || formatForecastWhen(startTime);
      if (!when) {
        when = "—";
      }

      var temp = (period && period.temperature !== undefined && period.temperature !== null)
        ? (period.temperature + " " + (period.temperatureUnit || ""))
        : "—";

      var wind = (period && (period.windSpeed || period.windDirection))
        ? (period.windDirection ? (period.windDirection + " ") : "") + (period.windSpeed || "—")
        : "—";

      var conditions = period && period.shortForecast ? period.shortForecast : "—";

      var card = document.createElement("div");
      card.className = "card border-0 shadow-sm";
      card.style.minWidth = "180px";

      var cardBody = document.createElement("div");
      cardBody.className = "card-body p-2";

      var whenEl = document.createElement("div");
      whenEl.className = "small text-muted";
      whenEl.textContent = when;

      var tempEl = document.createElement("div");
      tempEl.className = "h4 mb-1";
      tempEl.textContent = temp.trim();

      var windEl = document.createElement("div");
      windEl.className = "small fw-semibold";
      windEl.textContent = "Wind: " + wind.trim();

      var condEl = document.createElement("div");
      condEl.className = "small text-muted";
      condEl.textContent = conditions;

      cardBody.appendChild(whenEl);
      cardBody.appendChild(tempEl);
      cardBody.appendChild(windEl);
      cardBody.appendChild(condEl);
      card.appendChild(cardBody);
      bodyEl.appendChild(card);
    });
  }

  function renderWeatherSummary(summary, message) {
    var summaryEl = document.getElementById("weatherSummary");
    if (!summaryEl) return;
    var text = summary || message || "Forecast unavailable.";
    summaryEl.dataset.baseSummary = text;
    applySummaryDecoration(summaryEl);
  }

  function renderWeatherHiLow(forecast, hiLoEl, summaryEl) {
    if (!hiLoEl) return;
    var temps = [];
    if (Array.isArray(forecast)) {
      forecast.forEach(function (p) {
        if (p && p.temperature !== undefined && p.temperature !== null && !isNaN(parseFloat(p.temperature))) {
          temps.push(parseFloat(p.temperature));
        }
      });
    }
    if (!temps.length) {
      hiLoEl.textContent = "";
      if (summaryEl) {
        summaryEl.dataset.hi = "";
        summaryEl.dataset.lo = "";
        applySummaryDecoration(summaryEl);
      }
      return;
    }
    var hi = Math.max.apply(null, temps);
    var lo = Math.min.apply(null, temps);
    hiLoEl.textContent = hi + "° / " + lo + "°";
    if (summaryEl) {
      summaryEl.dataset.hi = hi;
      summaryEl.dataset.lo = lo;
      applySummaryDecoration(summaryEl);
    }
  }

  function renderWeatherAnchor(meta) {
    var metaEl = document.getElementById("weatherAnchorMeta");
    if (!metaEl) return;
    if (meta && meta.anchor && meta.anchor.lat !== undefined && meta.anchor.lon !== undefined) {
      var lat = parseFloat(meta.anchor.lat);
      var lon = parseFloat(meta.anchor.lon);
      if (!Number.isNaN(lat) && !Number.isNaN(lon)) {
        metaEl.textContent = "Anchor: " + lat.toFixed(2) + ", " + lon.toFixed(2);
        return;
      }
    }
    metaEl.textContent = "";
  }

  function formatForecastWhen(startTime) {
    if (!startTime) {
      return "";
    }
    var parsed = new Date(startTime);
    if (isNaN(parsed.getTime())) {
      return startTime;
    }
    try {
      return parsed.toLocaleString(undefined, {
        weekday: "short",
        hour: "numeric",
        minute: "2-digit"
      });
    } catch (e) {
      return parsed.toString();
    }
  }

  function applySummaryDecoration(summaryEl) {
    if (!summaryEl) return;
    var base = summaryEl.dataset.baseSummary || summaryEl.textContent || "";
    var dateStr = formatSummaryDate(new Date());
    var hi = summaryEl.dataset.hi;
    var lo = summaryEl.dataset.lo;
    var parts = [];
    if (base) {
      parts.push(base);
    }
    if (hi && lo) {
      parts.push( hi + "°/" + lo + "°");
    }
    if (dateStr) {
      parts.push(dateStr);
    }
    summaryEl.textContent = parts.join(" • ");
  }

  function formatSummaryDate(dateObj) {
    if (!dateObj) return "";
    try {
      return dateObj.toLocaleDateString(undefined, {
        weekday: "short",
        month: "short",
        day: "numeric"
      });
    } catch (e) {
      return "";
    }
  }

  function updateWeatherTitleDate() {
    var titleEl = document.getElementById("weatherPanelTitle");
    if (!titleEl) return;
    var dateStr = formatSummaryDate(new Date());
    titleEl.textContent = dateStr || "—";
  }


  function normalizeZip(value) {
    return (value || "")
      .toString()
      .replace(/\D/g, "")
      .slice(0, 5);
  }

  function isValidZip(zip) {
    return zip && zip.length === 5;
  }

  function loadWeather(zip) {
    var loadingEl = document.getElementById("weatherLoading");
    if (!loadingEl) {
      return;
    }

    toggleHidden(loadingEl, false);
    clearWeatherError();

    return fetch(WEATHER_BASE_URL + encodeURIComponent(zip) + "&returnformat=json", { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Request failed with status " + response.status);
        }
        return response.json();
      })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          var message = payload && payload.MESSAGE ? payload.MESSAGE : null;
          throw new Error(message || "Weather data unavailable.");
        }

        var data = payload.DATA || {};
        renderWeatherSummary(data.SUMMARY, payload.MESSAGE);
        renderWeatherAnchor(data.META);
        renderWeatherAlerts(data.ALERTS);
        renderWeatherForecast(data.FORECAST);
      })
      .catch(function (err) {
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        setWeatherError((err && err.message) ? err.message : null);
      })
      .finally(function () {
        toggleHidden(loadingEl, true);
      });
  }

  function initWeatherPanel() {
    var refreshBtn = document.getElementById("weatherRefreshBtn");
    var zipInput = document.getElementById("weatherZip");
    if (!refreshBtn) {
      return;
    }

    updateWeatherTitleDate();

    function requestWeatherFromInput() {
      var zip = normalizeZip(zipInput ? zipInput.value : "");
      if (zipInput) {
        zipInput.value = zip;
      }

      if (!isValidZip(zip)) {
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        setWeatherError("Enter a valid 5-digit ZIP code.");
        return;
      }

      loadWeather(zip);
    }

    refreshBtn.addEventListener("click", function () {
      requestWeatherFromInput();
    });

    requestWeatherFromInput();
  }

  function initDashboard() {
    if (utils.clearDashboardAlert) {
      utils.clearDashboardAlert();
    }
    if (utils.ensureConfirmModal) {
      utils.ensureConfirmModal();
    }
    if (utils.ensureAlertModal) {
      utils.ensureAlertModal();
    }

    if (modules.floatplans && modules.floatplans.init) {
      modules.floatplans.init();
    }
    if (modules.vessels && modules.vessels.init) {
      modules.vessels.init();
    }
    if (modules.contacts && modules.contacts.init) {
      modules.contacts.init();
    }
    if (modules.passengers && modules.passengers.init) {
      modules.passengers.init();
    }
    if (modules.operators && modules.operators.init) {
      modules.operators.init();
    }
    if (modules.waypoints && modules.waypoints.init) {
      modules.waypoints.init();
    }
    if (modules.alerts && modules.alerts.init) {
      modules.alerts.init();
    }
    // TODO: call /api/v1/floatplans.cfc?method=getMonitoredPlans every 60s and render counts/list.

    Api.getCurrentUser()
      .then(function (data) {
        // data.SUCCESS already checked in Api.request
        if (utils.ensureAuthResponse && !utils.ensureAuthResponse(data)) {
          return;
        }

        if (!data.USER) {
          redirectToLogin();
          return;
        }

        populateUserInfo(data.USER);
        if (utils.resolveHomePortLatLng) {
          state.homePortLatLng = utils.resolveHomePortLatLng(data.USER);
        }

        var readyEvent = null;
        if (typeof Event === "function") {
          readyEvent = new Event("fpw:dashboard:user-ready");
        } else {
          readyEvent = document.createEvent("Event");
          readyEvent.initEvent("fpw:dashboard:user-ready", true, true);
        }
        document.dispatchEvent(readyEvent);
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        redirectToLogin();
      });

    // Wire up logout
    var logoutBtn = document.getElementById("logoutButton");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", function () {
        Api.logout()
          .catch(function (err) {
            console.error("Logout failed:", err);
            // Ignore errors, just send them to login
          })
          .finally(function () {
            redirectToLogin();
          });
      });
    }

    initWeatherPanel();
  }

  window.FPW_DASHBOARD_VERSION = "20251227r";
  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
