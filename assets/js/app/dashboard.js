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
  var WEATHER_BASE_URL = (function () {
    var base = (BASE_PATH || "").toString();
    var pathname = "";
    var appIdx = -1;
    if (!base && window.location && window.location.pathname) {
      pathname = String(window.location.pathname || "");
      appIdx = pathname.toLowerCase().indexOf("/app/");
      if (appIdx > 0) {
        base = pathname.slice(0, appIdx);
      } else if (appIdx === 0) {
        base = "";
      }
    }
    base = base.replace(/\/+$/, "");
    return base + "/api/v1/weather.cfc";
  })();
  var tideResizeObserver = null;
  var tideLastMarine = null;
  var tideLastWrapWidth = 0;
  var weatherRequestSeq = 0;
  var AUTO_LOAD_HOME_PORT_WEATHER = true;
  var seaStateLastWaveHeight = null;
  var monitoringPollTimer = 0;
  var derivedSignalsPollTimer = 0;
  var dashboardSignals = {
    routeName: "No routes yet",
    routeSummary: "Create your first route.",
    routeProgressPct: 0,
    floatPlans: {
      active: 0,
      total: 0
    },
    monitoring: {
      active: 0,
      overdue: 0,
      escalated: 0,
      loaded: false,
      message: "Waiting for monitored plans."
    },
    weather: {
      risk: "—",
      alertCount: 0,
      alertLabel: "None",
      summary: "Forecast unavailable."
    },
    setup: {
      vessels: 0,
      contacts: 0,
      passengers: 0,
      operators: 0,
      waypoints: 0
    }
  };
  var missionSummaryState = {
    lastRecomputedAt: null
  };
  var MISSION_SUMMARY_TILE_LABELS = {
    activeRoute: "Active Route",
    routeProgress: "Route Progress",
    floatPlans: "Float Plans",
    monitoring: "Monitoring",
    weatherRisk: "Weather Risk",
    setup: "Boat & Trip Setup"
  };

  function setText(id, value) {
    var el = document.getElementById(id);
    if (!el) return;
    el.textContent = value;
  }

  function formatDashboardTime(dateObj) {
    if (!dateObj || isNaN(dateObj.getTime())) return "";
    try {
      return dateObj.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
    } catch (e) {
      return "";
    }
  }

  function parseRouteProgressPct(value) {
    var pct = parseFloat(value);
    if (!Number.isFinite(pct)) return 0;
    return clamp(pct, 0, 100);
  }

  function formatMissionSummaryUpdatedAt(dateObj) {
    var timeLabel = formatDashboardTime(dateObj);
    return timeLabel ? ("Updated " + timeLabel) : "Updated just now";
  }

  function normalizeMissionText(value, fallback, maxLength) {
    var text = "";
    var limit = Number.isFinite(maxLength) ? Math.max(0, parseInt(maxLength, 10)) : 0;
    if (value !== null && value !== undefined) {
      text = String(value).replace(/\s+/g, " ").trim();
    }
    if (text === "—" || text === "--") {
      text = "";
    }
    if (!text) {
      text = fallback || "";
    }
    if (limit > 0 && text.length > limit) {
      text = text.slice(0, Math.max(0, limit - 1)).replace(/\s+$/, "") + "…";
    }
    return text;
  }

  function normalizeMissionCount(value) {
    var parsed = parseInt(value, 10);
    if (!Number.isFinite(parsed) || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  function isMissionRouteUnavailable(value) {
    var normalized = normalizeMissionText(value, "", 120).toLowerCase();
    if (!normalized) return true;
    return normalized === "no routes yet"
      || normalized === "no active route"
      || normalized === "route"
      || normalized === "not available";
  }

  function isMissionSummaryPlaceholder(text) {
    var normalized = normalizeMissionText(text, "", 140).toLowerCase();
    if (!normalized) return true;
    return normalized === "create your first route."
      || normalized === "create your first route"
      || normalized === "waiting for route data"
      || normalized === "no active route"
      || normalized === "no routes yet"
      || normalized === "no data";
  }

  function collectMissionSummaryData() {
    return {
      route: {
        name: dashboardSignals.routeName,
        summary: dashboardSignals.routeSummary,
        progressPct: dashboardSignals.routeProgressPct
      },
      floatPlans: {
        active: dashboardSignals.floatPlans ? dashboardSignals.floatPlans.active : 0,
        total: dashboardSignals.floatPlans ? dashboardSignals.floatPlans.total : 0
      },
      monitoring: {
        active: dashboardSignals.monitoring ? dashboardSignals.monitoring.active : 0,
        overdue: dashboardSignals.monitoring ? dashboardSignals.monitoring.overdue : 0,
        escalated: dashboardSignals.monitoring ? dashboardSignals.monitoring.escalated : 0,
        loaded: dashboardSignals.monitoring ? dashboardSignals.monitoring.loaded : false,
        message: dashboardSignals.monitoring ? dashboardSignals.monitoring.message : ""
      },
      weather: {
        risk: dashboardSignals.weather ? dashboardSignals.weather.risk : "",
        alertLabel: dashboardSignals.weather ? dashboardSignals.weather.alertLabel : ""
      },
      setup: {
        vessels: dashboardSignals.setup ? dashboardSignals.setup.vessels : 0,
        contacts: dashboardSignals.setup ? dashboardSignals.setup.contacts : 0,
        waypoints: dashboardSignals.setup ? dashboardSignals.setup.waypoints : 0,
        passengers: dashboardSignals.setup ? dashboardSignals.setup.passengers : 0,
        operators: dashboardSignals.setup ? dashboardSignals.setup.operators : 0
      }
    };
  }

  function buildMissionSummaryModel(source, recomputedAt) {
    var payload = source || {};
    var route = payload.route || {};
    var floatPlans = payload.floatPlans || {};
    var monitoring = payload.monitoring || {};
    var weather = payload.weather || {};
    var setup = payload.setup || {};
    var routeName = normalizeMissionText(route.name, "", 56);
    var routeSummary = normalizeMissionText(route.summary, "", 84);
    var hasActiveRoute = !isMissionRouteUnavailable(routeName);
    var routeProgress = parseFloat(route.progressPct);
    var routePctLabel = Number.isFinite(routeProgress) ? (Math.round(clamp(routeProgress, 0, 100)) + "% complete") : "No data";
    var floatActive = normalizeMissionCount(floatPlans.active);
    var floatTotal = normalizeMissionCount(floatPlans.total);
    var monitoringActive = normalizeMissionCount(monitoring.active);
    var monitoringOverdue = normalizeMissionCount(monitoring.overdue);
    var monitoringEscalated = normalizeMissionCount(monitoring.escalated);
    var monitoringLoaded = monitoring.loaded === true;
    var monitoringMessage = normalizeMissionText(monitoring.message, "No data", 84);
    var weatherRisk = normalizeMissionText(weather.risk, "", 30);
    var weatherAlerts = normalizeMissionText(weather.alertLabel, "None", 34);
    var vessels = normalizeMissionCount(setup.vessels);
    var contacts = normalizeMissionCount(setup.contacts);
    var waypoints = normalizeMissionCount(setup.waypoints);
    var crew = normalizeMissionCount(setup.passengers) + normalizeMissionCount(setup.operators);
    var summaryDate = (recomputedAt && !Number.isNaN(recomputedAt.getTime()))
      ? recomputedAt
      : (missionSummaryState.lastRecomputedAt || new Date());
    var routeMeta = "No data";
    var progressMeta = "No data";

    if (hasActiveRoute && !isMissionSummaryPlaceholder(routeSummary)) {
      routeMeta = routeSummary;
      progressMeta = routeSummary;
    } else if (hasActiveRoute) {
      progressMeta = Number.isFinite(routeProgress) ? "No data" : "No progress data";
    } else {
      progressMeta = "No active route";
    }

    if (!weatherRisk || weatherRisk.toLowerCase() === "forecast unavailable.") {
      weatherRisk = "Not available";
    }

    if (!weatherAlerts || weatherAlerts.toLowerCase() === "not available") {
      weatherAlerts = "None";
    }

    return {
      updatedAtLabel: formatMissionSummaryUpdatedAt(summaryDate),
      tiles: {
        activeRoute: {
          label: MISSION_SUMMARY_TILE_LABELS.activeRoute,
          value: hasActiveRoute ? routeName : "No active route",
          meta: routeMeta
        },
        routeProgress: {
          label: MISSION_SUMMARY_TILE_LABELS.routeProgress,
          value: hasActiveRoute ? routePctLabel : "No data",
          meta: progressMeta
        },
        floatPlans: {
          label: MISSION_SUMMARY_TILE_LABELS.floatPlans,
          value: floatTotal > 0 ? (floatActive + " active") : "No plans",
          meta: floatTotal + " total"
        },
        monitoring: {
          label: MISSION_SUMMARY_TILE_LABELS.monitoring,
          value: monitoringLoaded ? (monitoringActive + " active / " + monitoringOverdue + " overdue") : "No data",
          meta: monitoringLoaded ? ("Escalated: " + monitoringEscalated) : monitoringMessage
        },
        weatherRisk: {
          label: MISSION_SUMMARY_TILE_LABELS.weatherRisk,
          value: weatherRisk,
          meta: "Alerts: " + weatherAlerts
        },
        setup: {
          label: MISSION_SUMMARY_TILE_LABELS.setup,
          value: vessels + " vessels • " + contacts + " contacts",
          meta: waypoints + " waypoints • " + crew + " crew"
        }
      }
    };
  }

  function updateSetupIntroMetrics() {
    setText("setupMetricVessels", "Vessels: " + dashboardSignals.setup.vessels);
    setText("setupMetricContacts", "Contacts: " + dashboardSignals.setup.contacts);
    setText("setupMetricPassengers", "Crew: " + dashboardSignals.setup.passengers);
    setText("setupMetricOperators", "Operators: " + dashboardSignals.setup.operators);
    setText("setupMetricWaypoints", "Waypoints: " + dashboardSignals.setup.waypoints);
  }

  function renderRouteStatusPanel() {
    var pct = parseRouteProgressPct(dashboardSignals.routeProgressPct);
    var progressBar = document.getElementById("routeStatusProgressBar");
    setText("routeStatusName", dashboardSignals.routeName || "No routes yet");
    setText("routeStatusMeta", dashboardSignals.routeSummary || "Create your first route.");
    setText("routeStatusProgressLabel", Math.round(pct) + "% complete");
    if (progressBar) {
      progressBar.style.width = pct + "%";
    }
  }

  function renderMissionSummary(model) {
    var summaryModel = model && model.tiles ? model : buildMissionSummaryModel(collectMissionSummaryData(), missionSummaryState.lastRecomputedAt || new Date());
    var tiles = summaryModel.tiles || {};
    var mapping = [
      { key: "activeRoute", valueId: "missionRouteValue", metaId: "missionRouteMeta" },
      { key: "routeProgress", valueId: "missionProgressValue", metaId: "missionProgressMeta" },
      { key: "floatPlans", valueId: "missionFloatPlansValue", metaId: "missionFloatPlansMeta" },
      { key: "monitoring", valueId: "missionMonitoringValue", metaId: "missionMonitoringMeta" },
      { key: "weatherRisk", valueId: "missionWeatherValue", metaId: "missionWeatherMeta" },
      { key: "setup", valueId: "missionSetupValue", metaId: "missionSetupMeta" }
    ];
    var i = 0;
    var mapItem = null;
    var tile = null;

    for (i = 0; i < mapping.length; i += 1) {
      mapItem = mapping[i];
      tile = tiles[mapItem.key] || {};
      setText(mapItem.valueId, normalizeMissionText(tile.value, "No data", 64));
      setText(mapItem.metaId, normalizeMissionText(tile.meta, "No data", 96));
    }

    setText("missionSummaryUpdatedAt", normalizeMissionText(summaryModel.updatedAtLabel, "Updated just now", 42));
  }

  function refreshMissionSummary() {
    var recomputedAt = new Date();
    var model = buildMissionSummaryModel(collectMissionSummaryData(), recomputedAt);
    missionSummaryState.lastRecomputedAt = recomputedAt;
    renderMissionSummary(model);
    return model;
  }

  function renderWeatherPreview() {
    var windValueEl = document.getElementById("weatherWindSpeed");
    var windCondEl = document.getElementById("weatherWindCond");
    var waveValueEl = document.getElementById("wxWaveHeight");
    var waveTrendEl = document.getElementById("seaWaveTrendValue");
    var windValue = windValueEl ? (windValueEl.textContent || "").trim() : "";
    var windMeta = windCondEl ? (windCondEl.textContent || "").trim() : "";
    var waveValue = waveValueEl ? (waveValueEl.textContent || "").trim() : "";
    var waveMeta = waveTrendEl ? (waveTrendEl.textContent || "").trim() : "";
    var summaryText = dashboardSignals.weather.summary || "Forecast unavailable.";
    var updatedAt = formatDashboardTime(new Date());

    if (!windValue || windValue === "--") {
      windValue = "—";
    }
    if (!windMeta || windMeta === "--") {
      windMeta = "Current wind";
    }
    if (!waveValue || waveValue === "--" || waveValue === "—") {
      waveValue = "—";
    } else {
      waveValue = waveValue + " ft";
    }
    if (!waveMeta || waveMeta === "--") {
      waveMeta = "Current seas";
    }

    setText("weatherPreviewRiskValue", dashboardSignals.weather.risk || "—");
    setText("weatherPreviewAlertsValue", dashboardSignals.weather.alertLabel || "None");
    setText("weatherPreviewWindValue", windValue);
    setText("weatherPreviewWindMeta", windMeta);
    setText("weatherPreviewWavesValue", waveValue);
    setText("weatherPreviewWavesMeta", waveMeta);
    setText("weatherPreviewSummary", summaryText);
    setText("weatherPreviewUpdatedAt", updatedAt ? ("Updated " + updatedAt) : "Updated just now");
  }

  function renderMonitoringSummary() {
    var block = document.getElementById("monitoringSummaryBlock");
    var messageEl = document.getElementById("monitoringSummaryMessage");
    var metaEl = document.getElementById("monitoringSummaryMeta");
    var mon = dashboardSignals.monitoring || {};
    if (!block || !messageEl) return;

    if (!mon.loaded) {
      toggleHidden(block, true);
      messageEl.textContent = mon.message || "Loading monitoring summary…";
      toggleHidden(messageEl, false);
      return;
    }

    setText("monitoringActiveCount", mon.active);
    setText("monitoringOverdueCount", mon.overdue);
    setText("monitoringEscalatedCount", mon.escalated);

    if (metaEl) {
      var nowLabel = formatDashboardTime(new Date());
      metaEl.textContent = nowLabel ? ("Monitoring summary updated " + nowLabel + ".") : "Monitoring summary updated.";
    }

    toggleHidden(messageEl, true);
    toggleHidden(block, false);
  }

  function openWeatherPanelFromDashboard() {
    var weatherCard = document.querySelector(".fpw-card.fpw-alerts");
    var weatherCollapse = document.getElementById("alertsCollapse");
    var appTopbar = document.querySelector(".topbar.nav--app");
    var navHeight = appTopbar ? Math.round(appTopbar.getBoundingClientRect().height) : 0;
    var topGap = 22;

    if (weatherCollapse) {
      if (window.bootstrap && window.bootstrap.Collapse) {
        window.bootstrap.Collapse.getOrCreateInstance(weatherCollapse, { toggle: false }).show();
      } else {
        weatherCollapse.classList.add("show");
      }
    }

    if (weatherCard && typeof weatherCard.getBoundingClientRect === "function") {
      window.requestAnimationFrame(function () {
        var top = weatherCard.getBoundingClientRect().top + window.pageYOffset - navHeight - topGap;
        window.scrollTo({
          top: Math.max(0, Math.round(top)),
          behavior: "smooth"
        });
      });
    }
  }

  function scrollToPanel(selector) {
    var panel = document.querySelector(selector);
    var appTopbar = document.querySelector(".topbar.nav--app");
    var navHeight = appTopbar ? Math.round(appTopbar.getBoundingClientRect().height) : 0;
    if (!panel || typeof panel.getBoundingClientRect !== "function") return;
    window.requestAnimationFrame(function () {
      var top = panel.getBoundingClientRect().top + window.pageYOffset - navHeight - 22;
      window.scrollTo({
        top: Math.max(0, Math.round(top)),
        behavior: "smooth"
      });
    });
  }

  function triggerExistingButton(buttonId) {
    var btn = document.getElementById(buttonId);
    if (!btn || typeof btn.click !== "function") return false;
    btn.click();
    return true;
  }

  function onQuickAction(action) {
    if (action === "generate-route") {
      if (!triggerExistingButton("openRouteBuilderBtn")) {
        scrollToPanel("#expeditionTimelinePanel");
      }
      return;
    }
    if (action === "new-float-plan") {
      if (!triggerExistingButton("addFloatPlanBtn")) {
        scrollToPanel("#floatPlansPanel");
      }
      return;
    }
    if (action === "add-vessel") {
      if (!triggerExistingButton("addVesselBtn")) {
        scrollToPanel("#vesselsPanel");
      }
      return;
    }
    if (action === "add-contact") {
      if (!triggerExistingButton("addContactBtn")) {
        scrollToPanel("#contactsPanel");
      }
      return;
    }
    if (action === "add-operator") {
      if (!triggerExistingButton("addOperatorBtn")) {
        scrollToPanel("#operatorsPanel");
      }
      return;
    }
    if (action === "add-waypoint") {
      if (!triggerExistingButton("addWaypointBtn")) {
        scrollToPanel("#waypointsPanel");
      }
      return;
    }
    if (action === "open-weather") {
      openWeatherPanelFromDashboard();
      return;
    }
    if (action === "open-float-plans") {
      scrollToPanel("#floatPlansPanel");
      return;
    }
    if (action === "open-expedition") {
      scrollToPanel("#expeditionTimelinePanel");
    }
  }

  function bindPanelQuickActions(panelId) {
    var panel = document.getElementById(panelId);
    if (!panel || panel.dataset.bound === "true") return;
    panel.addEventListener("click", function (event) {
      var btn = event.target && event.target.closest ? event.target.closest("[data-quick-action]") : null;
      if (!btn) return;
      if (event && typeof event.preventDefault === "function") {
        event.preventDefault();
      }
      onQuickAction(btn.getAttribute("data-quick-action") || "");
    });
    panel.dataset.bound = "true";
  }

  function bindQuickActions() {
    bindPanelQuickActions("quickActionsPanel");
  }

  function bindNextStepsActions() {
    bindPanelQuickActions("recommendedNextStepsPanel");
  }

  function bindWeatherPreviewActions() {
    bindPanelQuickActions("weatherPreviewPanel");
  }

  function bindRouteStatusActions() {
    var openBtn = document.getElementById("routeStatusOpenRouteBuilderBtn");
    var timelineBtn = document.getElementById("routeStatusTimelineBtn");
    var refreshBtn = document.getElementById("routeStatusRefreshBtn");
    if (openBtn && openBtn.dataset.bound !== "true") {
      openBtn.addEventListener("click", function () {
        triggerExistingButton("openRouteBuilderBtn");
      });
      openBtn.dataset.bound = "true";
    }
    if (timelineBtn && timelineBtn.dataset.bound !== "true") {
      timelineBtn.addEventListener("click", function () {
        scrollToPanel("#expeditionTimelinePanel");
      });
      timelineBtn.dataset.bound = "true";
    }
    if (refreshBtn && refreshBtn.dataset.bound !== "true") {
      refreshBtn.addEventListener("click", function () {
        if (modules.expeditionTimeline && typeof modules.expeditionTimeline.load === "function") {
          modules.expeditionTimeline.load();
        }
        loadMonitoringSummary();
      });
      refreshBtn.dataset.bound = "true";
    }
  }

  function normalizeStatusUpper(value) {
    return (value || "").toString().trim().toUpperCase();
  }

  function refreshDerivedSignalsFromState() {
    var plans = (state.floatPlanState && Array.isArray(state.floatPlanState.all)) ? state.floatPlanState.all : [];
    var activePlans = 0;
    var i = 0;
    var status = "";

    for (i = 0; i < plans.length; i += 1) {
      status = normalizeStatusUpper(plans[i] && (plans[i].STATUS || plans[i].status));
      if (status === "ACTIVE" || status === "OPEN") {
        activePlans += 1;
      }
    }
    dashboardSignals.floatPlans.active = activePlans;
    dashboardSignals.floatPlans.total = plans.length;

    dashboardSignals.setup.vessels = (state.vesselState && Array.isArray(state.vesselState.all)) ? state.vesselState.all.length : 0;
    dashboardSignals.setup.contacts = (state.contactState && Array.isArray(state.contactState.all)) ? state.contactState.all.length : 0;
    dashboardSignals.setup.passengers = (state.passengerState && Array.isArray(state.passengerState.all)) ? state.passengerState.all.length : 0;
    dashboardSignals.setup.operators = (state.operatorState && Array.isArray(state.operatorState.all)) ? state.operatorState.all.length : 0;
    dashboardSignals.setup.waypoints = (state.waypointState && Array.isArray(state.waypointState.all)) ? state.waypointState.all.length : 0;

    updateSetupIntroMetrics();
    refreshMissionSummary();
    renderRecommendedNextSteps();
  }

  function loadMonitoringSummary() {
    var url = BASE_PATH + "/api/v1/floatplans.cfc?method=getMonitoredPlans&returnformat=json";
    dashboardSignals.monitoring.message = "Loading monitoring summary…";
    renderMonitoringSummary();

    return fetch(url, { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Monitoring request failed with status " + response.status);
        }
        return response.json();
      })
      .then(function (payload) {
        if (utils.ensureAuthResponse && !utils.ensureAuthResponse(payload)) {
          return;
        }
        if (!payload || payload.SUCCESS !== true) {
          throw new Error(payload && payload.MESSAGE ? payload.MESSAGE : "Monitoring summary unavailable.");
        }

        var data = payload.DATA || {};
        var counts = data.counts || {};
        dashboardSignals.monitoring.active = Number.isFinite(parseInt(counts.active, 10)) ? parseInt(counts.active, 10) : 0;
        dashboardSignals.monitoring.overdue = Number.isFinite(parseInt(counts.overdue, 10)) ? parseInt(counts.overdue, 10) : 0;
        dashboardSignals.monitoring.escalated = Number.isFinite(parseInt(counts.escalated, 10)) ? parseInt(counts.escalated, 10) : 0;
        dashboardSignals.monitoring.loaded = true;
        dashboardSignals.monitoring.message = "Monitoring summary updated.";

        renderMonitoringSummary();
        refreshMissionSummary();
        renderRecommendedNextSteps();
      })
      .catch(function (err) {
        dashboardSignals.monitoring.loaded = false;
        dashboardSignals.monitoring.message = (err && err.message) ? err.message : "Monitoring summary unavailable.";
        renderMonitoringSummary();
        refreshMissionSummary();
        renderRecommendedNextSteps();
      });
  }

  function startMonitoringPolling() {
    loadMonitoringSummary();
    if (monitoringPollTimer) {
      window.clearInterval(monitoringPollTimer);
    }
    monitoringPollTimer = window.setInterval(function () {
      loadMonitoringSummary();
    }, 60000);
  }

  function startDerivedSignalsPolling() {
    refreshDerivedSignalsFromState();
    if (derivedSignalsPollTimer) {
      window.clearInterval(derivedSignalsPollTimer);
    }
    derivedSignalsPollTimer = window.setInterval(function () {
      refreshDerivedSignalsFromState();
    }, 5000);
  }

  function setRouteSignals(routeName, summaryText, progressPct) {
    dashboardSignals.routeName = routeName || "No routes yet";
    dashboardSignals.routeSummary = summaryText || "Create your first route.";
    dashboardSignals.routeProgressPct = parseRouteProgressPct(progressPct);
    renderRouteStatusPanel();
    refreshMissionSummary();
    renderRecommendedNextSteps();
  }

  function renderRecommendedNextSteps() {
    var listEl = document.getElementById("nextStepsList");
    var emptyEl = document.getElementById("nextStepsEmpty");
    var steps = [];
    var markup = "";

    if (!listEl || !emptyEl) return;

    if ((dashboardSignals.floatPlans.total || 0) === 0) {
      steps.push({
        title: "Create your first float plan",
        meta: "No float plans are available for this account.",
        action: "new-float-plan",
        actionLabel: "Open Float Plan"
      });
    }

    if (dashboardSignals.monitoring.loaded && (dashboardSignals.monitoring.overdue || 0) > 0) {
      steps.push({
        title: "Review overdue monitoring plans",
        meta: dashboardSignals.monitoring.overdue + " monitored plan(s) are currently overdue.",
        action: "open-float-plans",
        actionLabel: "Review Plans"
      });
    }

    if ((dashboardSignals.setup.contacts || 0) === 0) {
      steps.push({
        title: "Add emergency contacts",
        meta: "Contacts are required for notification workflows in float plans.",
        action: "add-contact",
        actionLabel: "Add Contact"
      });
    }

    if ((dashboardSignals.setup.vessels || 0) === 0) {
      steps.push({
        title: "Add a vessel profile",
        meta: "Route and float-plan workflows rely on a vessel profile.",
        action: "add-vessel",
        actionLabel: "Add Vessel"
      });
    }

    if ((dashboardSignals.weather.alertCount || 0) > 0) {
      steps.push({
        title: "Review current marine alerts",
        meta: dashboardSignals.weather.alertCount + " active weather alert(s) are posted.",
        action: "open-weather",
        actionLabel: "Open Weather"
      });
    }

    if (!steps.length) {
      listEl.innerHTML = "";
      toggleHidden(emptyEl, false);
      return;
    }

    toggleHidden(emptyEl, true);
    markup = steps.slice(0, 5).map(function (step) {
      return ''
        + '<article class="next-step-item">'
        + '  <div class="next-step-main">'
        + '    <p class="next-step-title">' + escapeHtml(step.title) + '</p>'
        + '    <p class="next-step-meta">' + escapeHtml(step.meta) + '</p>'
        + '  </div>'
        + '  <button type="button" class="btn-secondary" data-quick-action="' + escapeHtml(step.action) + '">'
        + escapeHtml(step.actionLabel)
        + '</button>'
        + '</article>';
    }).join("");
    listEl.innerHTML = markup;
  }

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

  function clamp(n, min, max) {
    n = parseFloat(n);
    if (isNaN(n)) return min;
    return Math.max(min, Math.min(max, n));
  }

  function tempColorAtF(tempF, alpha) {
    var scale = [
      { t: -10, c: [52, 111, 255] },  // deep cold blue
      { t: 32, c: [74, 168, 255] },   // freezing blue
      { t: 50, c: [74, 204, 154] },   // mild green
      { t: 68, c: [243, 204, 84] },   // warm yellow
      { t: 80, c: [245, 149, 62] },   // hot orange
      { t: 95, c: [227, 74, 58] }     // very hot red
    ];
    var i = 0;
    var lo = null;
    var hi = null;
    var mix = 0;
    var r = 0;
    var g = 0;
    var b = 0;
    var a = Number.isFinite(alpha) ? alpha : 1;
    var tVal = Number.isFinite(tempF) ? tempF : 50;

    if (tVal <= scale[0].t) {
      return "rgba(" + scale[0].c[0] + "," + scale[0].c[1] + "," + scale[0].c[2] + "," + a + ")";
    }
    if (tVal >= scale[scale.length - 1].t) {
      return "rgba(" + scale[scale.length - 1].c[0] + "," + scale[scale.length - 1].c[1] + "," + scale[scale.length - 1].c[2] + "," + a + ")";
    }

    for (i = 0; i < scale.length - 1; i += 1) {
      if (tVal >= scale[i].t && tVal <= scale[i + 1].t) {
        lo = scale[i];
        hi = scale[i + 1];
        break;
      }
    }
    if (!lo || !hi) {
      lo = scale[0];
      hi = scale[1];
    }

    mix = (tVal - lo.t) / (hi.t - lo.t);
    r = Math.round(lo.c[0] + ((hi.c[0] - lo.c[0]) * mix));
    g = Math.round(lo.c[1] + ((hi.c[1] - lo.c[1]) * mix));
    b = Math.round(lo.c[2] + ((hi.c[2] - lo.c[2]) * mix));
    return "rgba(" + r + "," + g + "," + b + "," + a + ")";
  }

  function compassToDegrees(dir) {
    if (!dir) return 0;
    var d = dir.toString().trim().toUpperCase();

    // Normalize common NWS values
    if (d === "CALM") return 0;
    if (d === "VAR" || d === "VARIABLE") return 0;

    var map = {
      N: 0, NNE: 22.5, NE: 45, ENE: 67.5,
      E: 90, ESE: 112.5, SE: 135, SSE: 157.5,
      S: 180, SSW: 202.5, SW: 225, WSW: 247.5,
      W: 270, WNW: 292.5, NW: 315, NNW: 337.5
    };
    if (map[d] !== undefined) return map[d];

    // Sometimes comes as "NW" etc already handled; fallback: try first 3 letters
    var t = d.replace(/[^A-Z]/g, "");
    if (map[t] !== undefined) return map[t];
    if (t.length > 3 && map[t.substring(0, 3)] !== undefined) return map[t.substring(0, 3)];
    if (t.length > 2 && map[t.substring(0, 2)] !== undefined) return map[t.substring(0, 2)];
    return 0;
  }

  function parseWindSpeed(windSpeedRaw) {
    // NWS examples: "7 mph", "5 to 10 mph", "10 to 15 mph", "15 mph"
    var txt = (windSpeedRaw || "").toString().toLowerCase();
    var nums = txt.match(/(\d+(\.\d+)?)/g) || [];
    var a = nums.length ? parseFloat(nums[0]) : 0;
    var b = (nums.length >= 2) ? parseFloat(nums[1]) : a;

    // Treat the upper end as an estimated gust
    var speed = a || 0;
    var gust = Math.max(a || 0, b || 0);

    return { speed: speed, gust: gust };
  }

  function parseApiGustMph(period) {
    if (!period) return null;
    var raw = null;
    if (period.gustMph !== undefined && period.gustMph !== null && period.gustMph !== "") {
      raw = period.gustMph;
    } else if (period.GUSTMPH !== undefined && period.GUSTMPH !== null && period.GUSTMPH !== "") {
      raw = period.GUSTMPH;
    }
    if (raw === null) return null;
    var n = parseFloat(raw);
    return Number.isFinite(n) ? n : null;
  }

  function resolveGustMph(period, parsedWind) {
    var apiGust = parseApiGustMph(period);
    if (apiGust !== null && apiGust >= 0) {
      return apiGust;
    }
    return (parsedWind && parsedWind.gust) ? parsedWind.gust : ((parsedWind && parsedWind.speed) ? parsedWind.speed : 0);
  }

  function formatTimeOfDay(iso) {
    if (!iso) return "";
    try {
      var d = new Date(iso);
      if (isNaN(d.getTime())) return "";
      var hrs = d.getHours();
      var mins = d.getMinutes();
      var ap = hrs >= 12 ? "PM" : "AM";
      var h12 = hrs % 12; if (h12 === 0) h12 = 12;
      return mins ? (h12 + ":" + String(mins).padStart(2, "0") + " " + ap) : (h12 + " " + ap);
    } catch (e) { return ""; }
  }

  function formatHourOnly(iso) {
    if (!iso) return "";
    try {
      var d = new Date(iso);
      if (isNaN(d.getTime())) return "";
      var h = d.getHours() % 12;
      return String(h === 0 ? 12 : h);
    } catch (e) { return ""; }
  }


  function abbreviateWhen(label) {
    if (!label) return "";
    var s = label.toString();

    // Common NWS names: "Tonight", "This Afternoon", "Wednesday", "Wednesday Night"
    s = s.replace(/^This\s+/i, "");
    s = s.replace(/\s+Night$/i, " N");
    s = s.replace(/\s+Afternoon$/i, " PM");
    s = s.replace(/\s+Morning$/i, " AM");
    s = s.replace(/\s+Evening$/i, " Eve");
    return s;
  }

  function inferRainPct(period) {
    // Prefer NWS probabilityOfPrecipitation.value if present
    try {
      if (period && period.probabilityOfPrecipitation && period.probabilityOfPrecipitation.value !== undefined && period.probabilityOfPrecipitation.value !== null) {
        var v = parseFloat(period.probabilityOfPrecipitation.value);
        if (!isNaN(v)) return clamp(v, 0, 100);
      }
    } catch (e) {}

    // Otherwise infer from text
    var txt = (period && (period.shortForecast || period.detailedForecast)) ? (period.shortForecast || period.detailedForecast) : "";
    txt = (txt || "").toString().toLowerCase();
    if (!txt) return 0;
    if (txt.indexOf("thunder") >= 0) return 70;
    if (txt.indexOf("rain") >= 0 || txt.indexOf("shower") >= 0) return 55;
    if (txt.indexOf("drizzle") >= 0) return 35;
    if (txt.indexOf("snow") >= 0 || txt.indexOf("sleet") >= 0) return 40;
    if (txt.indexOf("cloud") >= 0) return 10;
    return 0;
  }

  function buildMeterRow(type, pct, labelText) {
    var row = document.createElement("div");
    row.className = "fpw-wx__meterRow";

    var fill = document.createElement("div");
    fill.className = "fpw-wx__meterFill " + type;
    fill.style.width = clamp(pct, 0, 100) + "%";

    row.appendChild(fill);

    if (labelText !== undefined && labelText !== null && labelText !== "") {
      var val = document.createElement("div");
      val.className = "val";
      val.textContent = labelText;
      row.appendChild(val);
    }

    return row;
  }

  function classifyWindRisk(mph) {
    var v = parseFloat(mph) || 0;
    // Simple, marine-friendly thresholds (tune later):
    // <10 Low, 10-14 Caution, 15-19 High, >=20 Extreme
    if (v >= 20) return { level: 4, label: "Extreme", haloColor: "239,68,68", haloOpacity: 0.55 };
    if (v >= 15) return { level: 3, label: "High", haloColor: "250,204,21", haloOpacity: 0.45 };
    if (v >= 10) return { level: 2, label: "Caution", haloColor: "59,130,246", haloOpacity: 0.35 };
    return { level: 1, label: "Low", haloColor: "45,212,191", haloOpacity: 0.28 };
  }


  function renderWeatherAlerts(alerts) {
    var listEl = document.getElementById("weatherAlertsList");
    var emptyEl = document.getElementById("weatherAlertsEmpty");
    var statusDot = document.getElementById("weatherStatusDot");
    var alertLabelEl = document.getElementById("weatherAlertLabel");

    var items = Array.isArray(alerts) ? alerts : [];
    var topItems = items.slice(0, 2);

    if (alertLabelEl) {
      alertLabelEl.textContent = items.length ? (items.length + " active") : "None";
    }
    dashboardSignals.weather.alertCount = items.length;
    dashboardSignals.weather.alertLabel = items.length ? (items.length + " active") : "None";

    // Determine highest severity for status dot
    var worst = "ok";
    items.forEach(function (a) {
      var sev = mapAlertSeverity(a && a.severity ? a.severity : "");
      if (sev === "critical") worst = "danger";
      else if (sev === "warning" && worst !== "danger") worst = "warn";
      else if (sev === "info" && worst === "ok") worst = "ok";
    });

    if (statusDot) {
      statusDot.classList.remove("ok", "warn", "danger");
      statusDot.classList.add(worst);
    }

    if (!listEl || !emptyEl) return;

    listEl.innerHTML = "";

    if (!topItems.length) {
      toggleHidden(emptyEl, false);
      refreshMissionSummary();
      renderRecommendedNextSteps();
      return;
    }
    toggleHidden(emptyEl, true);

    topItems.forEach(function (alert) {
      var severity = alert && alert.severity ? alert.severity : "";
      var sevClass = mapAlertSeverity(severity); // info | warning | critical
      var label = severity ? severity.toString().toUpperCase() : "INFO";
      var title = (alert && (alert.headline || alert.event)) ? (alert.headline || alert.event) : "Marine alert";
      var instruction = (alert && alert.instruction) ? alert.instruction : "";

      var li = document.createElement("li");
      li.className = "fpw-wx__alertItem";

      var head = document.createElement("div");
      head.className = "fpw-wx__alertHead";

      var badge = document.createElement("span");
      badge.className = "fpw-wx__alertBadge " + sevClass;
      badge.textContent = label;

      var titleEl = document.createElement("div");
      titleEl.className = "fpw-wx__alertTitle";
      titleEl.textContent = title;

      head.appendChild(badge);
      head.appendChild(titleEl);

      li.appendChild(head);

      if (instruction) {
        var msg = document.createElement("div");
        msg.className = "fpw-wx__alertMsg";
        msg.textContent = instruction;
        li.appendChild(msg);
      }

      listEl.appendChild(li);
    });
    refreshMissionSummary();
    renderRecommendedNextSteps();
  }

  
  function parseDateAny(val) {
    if (!val) return null;
    if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
    var s = val.toString().trim();
    if (!s) return null;

    // MySQL-ish "YYYY-MM-DD HH:MM:SS" -> "YYYY-MM-DDTHH:MM:SS"
    if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(s) && s.indexOf("T") === -1) {
      s = s.replace(" ", "T");
    }
    var d = new Date(s);
    if (!isNaN(d.getTime())) return d;

    // Epoch ms
    var n = parseInt(s, 10);
    if (!isNaN(n) && n > 1000000000) {
      d = new Date(n);
      if (!isNaN(d.getTime())) return d;
    }
    return null;
  }

  function fmtShortTime(d) {
    if (!d || isNaN(d.getTime())) return "—";
    var hrs = d.getHours();
    var mins = d.getMinutes();
    var ap = hrs >= 12 ? "PM" : "AM";
    var h12 = hrs % 12; if (h12 === 0) h12 = 12;
    return mins ? (h12 + ":" + String(mins).padStart(2, "0") + " " + ap) : (h12 + " " + ap);
  }

  function resolveActivePlanWindow() {
    var candidates = [];
    try {
      if (state) {
        if (state.activeFloatPlan) candidates.push(state.activeFloatPlan);
        if (state.selectedFloatPlan) candidates.push(state.selectedFloatPlan);
        if (state.currentFloatPlan) candidates.push(state.currentFloatPlan);
        if (state.floatPlan) candidates.push(state.floatPlan);
        if (state.floatPlanContext) candidates.push(state.floatPlanContext);
        if (state.lastOpenedFloatPlan) candidates.push(state.lastOpenedFloatPlan);
      }
      if (window.FPW && window.FPW.ActiveFloatPlan) candidates.push(window.FPW.ActiveFloatPlan);
    } catch (e) {}

    var plan = null;
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i] && typeof candidates[i] === "object") { plan = candidates[i]; break; }
    }
    if (!plan) return null;

    var dep = plan.departureTimeUTC || plan.DEPARTURETIMEUTC || plan.departureTimeUtc || plan.DEPARTURE_TIME_UTC
           || plan.departureTime || plan.DEPARTURETIME || plan.departingTime || plan.DEPARTINGTIME
           || plan.departure || plan.DEPARTURE;

    var ret = plan.returnTimeUTC || plan.RETURNTIMEUTC || plan.returnTimeUtc || plan.RETURN_TIME_UTC
           || plan.returnTime || plan.RETURNTIME || plan.returningTime || plan.RETURNINGTIME
           || plan.return || plan.RETURN;

    var depD = parseDateAny(dep);
    var retD = parseDateAny(ret);
    if (!depD || !retD) return null;

    if (retD.getTime() < depD.getTime()) { var t = depD; depD = retD; retD = t; }

    return { start: depD, end: retD, plan: plan };
  }

  function renderPlanOverlay(rows) {
    var overlay = document.getElementById("weatherPlanOverlay");
    var pill = document.getElementById("weatherPlanPill");
    if (!overlay) return;

    overlay.innerHTML = "";
    var win = resolveActivePlanWindow();
    if (!win || !rows || !rows.length) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var t0 = parseDateAny(rows[0] && rows[0].startTime ? rows[0].startTime : null);
    var t1 = parseDateAny(rows[rows.length - 1] && rows[rows.length - 1].endTime ? rows[rows.length - 1].endTime : null);
    if (!t0 || !t1) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var a = win.start.getTime();
    var b = win.end.getTime();
    var s = t0.getTime();
    var e = t1.getTime();

    if (b <= s || a >= e) {
      overlay.classList.add("d-none");
      if (pill) pill.classList.add("d-none");
      return;
    }

    var leftPct = ((Math.max(a, s) - s) / (e - s)) * 100;
    var rightPct = ((Math.min(b, e) - s) / (e - s)) * 100;
    var widthPct = Math.max(1, rightPct - leftPct);

    var band = document.createElement("div");
    band.className = "fpw-wx__planBand";
    band.style.left = leftPct + "%";
    band.style.width = widthPct + "%";

    var lbl = document.createElement("div");
    lbl.className = "fpw-wx__planLabel";
    lbl.textContent = "Float plan window " + fmtShortTime(win.start) + "–" + fmtShortTime(win.end);
    band.appendChild(lbl);

    overlay.appendChild(band);
    overlay.classList.remove("d-none");

    if (pill) {
      pill.textContent = "Plan window: " + fmtShortTime(win.start) + "–" + fmtShortTime(win.end);
      pill.classList.remove("d-none");
    }
  }

  function renderWeatherForecast(forecast) {
    var timelineEl = document.getElementById("weatherTimeline");
    var gustSpikesEl = document.getElementById("weatherGustSpikes");
    var gustLabelsEl = document.getElementById("weatherGustLabels");
    var tempValueEl = document.getElementById("weatherTempValue");
    var tempHiLoEl = document.getElementById("weatherTempHiLo");
    var tempLoLabelEl = document.getElementById("weatherTempLoLabel");
    var tempHiLabelEl = document.getElementById("weatherTempHiLabel");
    var nowWhenEl = document.getElementById("weatherNowWhen");
    var windSpeedEl = document.getElementById("weatherWindSpeed");
    var windDirEl = document.getElementById("weatherWindDir");
    var windNeedleEl = document.getElementById("weatherWindNeedle");
    var windGustEl = document.getElementById("weatherWindGust");
    var windCondEl = document.getElementById("weatherWindCond");
    var riskLabelEl = document.getElementById("weatherRiskLabel");
    var gustValueEl = document.getElementById("weatherGustValue");
    var gustHaloEl = document.getElementById("weatherGustHalo");

    var periods = Array.isArray(forecast) ? forecast : [];
    var rows = periods.slice(0, 12);

    // HI/LO (reuse old helper logic but also drive cockpit temp gauge)
    var hiLoEl = document.getElementById("weatherHiLo");
    var summaryEl = document.getElementById("weatherSummary");
    if (hiLoEl) {
      renderWeatherHiLow(periods, hiLoEl, summaryEl);
    }

    // Temp gauge hi/lo line
    if (tempHiLoEl && hiLoEl) {
      tempHiLoEl.textContent = hiLoEl.textContent ? ("Hi/Lo " + hiLoEl.textContent) : "—";
    }

    // If nothing, clear cockpit visuals
    if (!rows.length) {
      if (timelineEl) timelineEl.innerHTML = "";
      if (gustSpikesEl) gustSpikesEl.innerHTML = "";
      if (tempValueEl) tempValueEl.textContent = "—";
      if (nowWhenEl) nowWhenEl.textContent = "—";
      if (windSpeedEl) windSpeedEl.textContent = "—";
      if (windDirEl) windDirEl.textContent = "—";
      if (windGustEl) windGustEl.textContent = "Gust —";
      if (windCondEl) windCondEl.textContent = "—";
      if (riskLabelEl) riskLabelEl.textContent = "—";
      dashboardSignals.weather.risk = "—";
      if (gustValueEl) gustValueEl.textContent = "—";
    if (windNeedleEl) windNeedleEl.style.setProperty("--dir", "0deg");
    if (gustHaloEl) gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10)";
    var tempWrap = document.querySelector(".fpw-wx__temp");
    if (tempWrap) tempWrap.style.setProperty("--pct", "50");
    renderTideGraph(null);
    refreshMissionSummary();
    renderRecommendedNextSteps();
    return;
  }

    var now = rows[0];
    var nowWhen = (now && now.name) ? now.name : formatForecastWhen(now && now.startTime ? now.startTime : "");
    if (nowWhenEl) nowWhenEl.textContent = nowWhen || "Now";

    // WIND
    var windDir = now && now.windDirection ? now.windDirection : "";
    var windSpeedRaw = now && now.windSpeed ? now.windSpeed : "";
    var wind = parseWindSpeed(windSpeedRaw);
    var speed = wind.speed;
    var gust = resolveGustMph(now, wind);

    if (windSpeedEl) windSpeedEl.textContent = speed ? (speed + " mph") : "—";
    if (windDirEl) windDirEl.textContent = windDir || "—";
    if (windGustEl) windGustEl.textContent = "Gust " + (gust ? (Math.round(gust) + " mph") : "—");
    if (windCondEl) windCondEl.textContent = (now && now.shortForecast) ? now.shortForecast : "—";

    var deg = compassToDegrees(windDir);
    if (windNeedleEl) {
      windNeedleEl.style.setProperty("--dir", deg + "deg");
    }

    // Risk label + halo intensity
    var risk = classifyWindRisk(gust || speed || 0);
    if (riskLabelEl) riskLabelEl.textContent = risk.label;
    dashboardSignals.weather.risk = risk.label;

    if (gustHaloEl) {
      gustHaloEl.style.opacity = risk.haloOpacity;
      gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10), 0 0 0 0 rgba(0,0,0,0), 0 0 0 0 rgba(0,0,0,0)";
      gustHaloEl.style.boxShadow = "inset 0 0 0 2px rgba(255,255,255,.10), 0 0 26px rgba(" + risk.haloColor + "," + risk.haloOpacity + ")";
    }

    // TEMP gauge
    var nowTemp = (now && now.temperature !== undefined && now.temperature !== null) ? parseFloat(now.temperature) : NaN;
    if (tempValueEl) tempValueEl.textContent = Number.isFinite(nowTemp) ? (Math.round(nowTemp) + "°") : "—";

    var lo = Number.POSITIVE_INFINITY;
    var hi = Number.NEGATIVE_INFINITY;
    periods.forEach(function (p) {
      var t = (p && p.temperature !== undefined && p.temperature !== null) ? parseFloat(p.temperature) : NaN;
      if (!Number.isFinite(t)) return;
      if (t < lo) lo = t;
      if (t > hi) hi = t;
    });
    if (!Number.isFinite(lo) || !Number.isFinite(hi) || lo === hi) {
      lo = 40; hi = 90;
    }
    if (tempLoLabelEl) tempLoLabelEl.textContent = Math.round(lo) + "°";
    if (tempHiLabelEl) tempHiLabelEl.textContent = Math.round(hi) + "°";
    var pct = Number.isFinite(nowTemp) ? Math.round(((nowTemp - lo) / (hi - lo)) * 100) : 50;
    pct = clamp(pct, 4, 94);
    var tempWrapEl = document.querySelector(".fpw-wx__temp");
    if (tempWrapEl) {
      var midTemp = lo + ((hi - lo) * 0.55);
      var markerTemp = Number.isFinite(nowTemp) ? nowTemp : midTemp;
      tempWrapEl.style.setProperty("--pct", pct);
      tempWrapEl.style.setProperty("--temp-cold", tempColorAtF(lo, 0.70));
      tempWrapEl.style.setProperty("--temp-mid", tempColorAtF(midTemp, 0.68));
      // Peak color tracks forecast high temp (absolute weather scale).
      tempWrapEl.style.setProperty("--temp-hot", tempColorAtF(hi, 0.74));
      tempWrapEl.style.setProperty("--temp-marker", tempColorAtF(markerTemp, 0.95));
      tempWrapEl.style.setProperty("--temp-marker-glow", tempColorAtF(markerTemp, 0.30));
    }

    // Build timeline bars + gust spikes
    var maxGust = 0;
    rows.forEach(function (p) {
      var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
      var gResolved = resolveGustMph(p, w);
      if (gResolved > maxGust) maxGust = gResolved;
      if (w.speed > maxGust) maxGust = w.speed;
    });
    if (maxGust <= 0) maxGust = 25;

    if (timelineEl) {
      timelineEl.innerHTML = "";
      rows.forEach(function (p, idx) {
        var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
        var g = resolveGustMph(p, w);
        var t = (p && p.temperature !== undefined && p.temperature !== null) ? parseFloat(p.temperature) : NaN;

        var when = formatTimeOfDay(p && p.startTime ? p.startTime : "") || ((p && p.name) ? abbreviateWhen(p.name) : formatForecastWhen(p && p.startTime ? p.startTime : ""));

        var windPct = clamp(Math.round((w.speed / maxGust) * 100), 0, 100);
        var gustPct = clamp(Math.round((g / maxGust) * 100), 0, 100);

        var rainPct = inferRainPct(p);

        var bar = document.createElement("div");
        bar.className = "fpw-wx__bar";

        var top = document.createElement("div");
        top.className = "fpw-wx__barTop";

        var whenEl = document.createElement("div");
        whenEl.className = "fpw-wx__barWhen";
        whenEl.textContent = when || "—";

        var tempEl = document.createElement("div");
        tempEl.className = "fpw-wx__barTemp";
        tempEl.textContent = Number.isFinite(t) ? (Math.round(t) + "°") : "—";

        top.appendChild(whenEl);
        top.appendChild(tempEl);

        var meters = document.createElement("div");
        meters.className = "fpw-wx__barMeters";

        meters.appendChild(buildMeterRow("wind", windPct, (w.speed ? (w.speed + " mph") : "—")));
        meters.appendChild(buildMeterRow("gust", gustPct, (g ? (Math.round(g) + " mph") : "—")));
        meters.appendChild(buildMeterRow("rain", rainPct, (rainPct !== null && rainPct !== undefined ? (rainPct + "%") : "—")));

        bar.appendChild(top);
        bar.appendChild(meters);

        var meta = document.createElement("div");
        meta.className = "fpw-wx__barMeta";

        var chipW = document.createElement("span");
        chipW.className = "chip";
        chipW.innerHTML = "Wind <b>" + (w.speed ? (w.speed + " mph") : "—") + "</b>";

        var chipG = document.createElement("span");
        chipG.className = "chip";
        chipG.innerHTML = "Gust <b>" + (g ? (Math.round(g) + " mph") : "—") + "</b>";

        var chipR = document.createElement("span");
        chipR.className = "chip";
        chipR.innerHTML = "Rain <b>" + (rainPct !== null && rainPct !== undefined ? (rainPct + "%") : "—") + "</b>";

        meta.appendChild(chipW);
        meta.appendChild(chipG);
        meta.appendChild(chipR);
        bar.appendChild(meta);

        // Flag if risk is high for this period
        var r = classifyWindRisk(g || w.speed || 0);
        if (r.level >= 3) {
          var flag = document.createElement("div");
          flag.className = "fpw-wx__barFlag";
          bar.appendChild(flag);
        }

        timelineEl.appendChild(bar);
      });

      // Overlay float plan window (if available)
      renderPlanOverlay(rows);
    }

    if (gustSpikesEl) {
      gustSpikesEl.innerHTML = "";
      if (gustLabelsEl) gustLabelsEl.innerHTML = "";
      rows.forEach(function (p) {
        var w = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
        var g = resolveGustMph(p, w);
        var hPct = clamp(Math.round((g / maxGust) * 100), 2, 100);

        var spike = document.createElement("div");
        spike.className = "fpw-wx__spike " + (g >= 18 ? "hot" : (g <= 9 ? "ok" : ""));
        spike.style.height = hPct + "%";
        spike.title = g ? (g + " mph") : "—";

        var sheen = document.createElement("i");
        spike.appendChild(sheen);

        gustSpikesEl.appendChild(spike);
      });

      if (gustLabelsEl) {
        gustLabelsEl.style.gridTemplateColumns = "repeat(" + rows.length + ", minmax(0, 1fr))";
        rows.forEach(function (p2, idx2) {
          var tick = document.createElement("span");
          tick.className = "fpw-wx__spikeLabelTick";
          tick.textContent = formatHourOnly(p2 && p2.startTime ? p2.startTime : "") || "—";
          gustLabelsEl.appendChild(tick);
        });
      }
    }

    refreshMissionSummary();
    renderRecommendedNextSteps();

    if (gustValueEl) {
      gustValueEl.textContent = (gust || speed) ? (Math.round(gust || speed) + " mph") : "—";
    }
  }

  function ensureTideResizeObserver() {
    if (tideResizeObserver || !window.ResizeObserver) return;
    var wrap = document.getElementById("tideGraph");
    if (!wrap) return;
    tideResizeObserver = new window.ResizeObserver(function (entries) {
      if (!entries || !entries.length) return;
      var nextWidth = Math.round(entries[0].contentRect && entries[0].contentRect.width ? entries[0].contentRect.width : 0);
      if (!nextWidth) return;
      if (Math.abs(nextWidth - tideLastWrapWidth) < 2) return;
      tideLastWrapWidth = nextWidth;
      if (tideLastMarine) {
        renderTideGraph(tideLastMarine);
      }
    });
    tideResizeObserver.observe(wrap);
  }

  function renderTideGraph(marine) {
    ensureTideResizeObserver();
    var wrap = document.getElementById("tideGraph");
    var svg = document.getElementById("tideGraphSvg");
    var titleEl = document.getElementById("tideGraphTitle");
    var stationEl = document.getElementById("tideGraphStation");
    var nowEl = document.getElementById("tideGraphNowValue");
    var startEl = document.getElementById("tideGraphStart");
    var endEl = document.getElementById("tideGraphEnd");
    var emptyEl = document.getElementById("tideGraphEmpty");

    if (!wrap || !svg) return;

    tideLastMarine = marine || null;

    var marineMeta = (marine && (marine.META || marine.meta)) ? (marine.META || marine.meta) : {};
    var tide = null;
    var waterLevelCurrent = null;
    var series = [];
    var sourceType = "tide";

    if (marine) {
      tide = marine.tide || marine.TIDE || null;
      if (!tide) {
        tide = marine.waterLevel || marine.WATERLEVEL || null;
        sourceType = "waterLevel";
      }
      waterLevelCurrent = marine.waterLevelCurrent || marine.WATERLEVELCURRENT || null;
      if (!tide && waterLevelCurrent) {
        sourceType = "waterLevel";
      }
    }
    if (tide) {
      series = Array.isArray(tide.series) ? tide.series : (Array.isArray(tide.SERIES) ? tide.SERIES : []);
    }
    if (titleEl) {
      titleEl.textContent = (sourceType === "waterLevel") ? "Water Level (ft)" : "Tide (ft)";
    }
    if (!tide || !series.length) {
      svg.innerHTML = "";
      if (stationEl) {
        if (waterLevelCurrent && waterLevelCurrent.stationName) {
          var fullCurrentStation = String(waterLevelCurrent.stationName).trim();
          var stationMaxLen2 = 24;
          var shortCurrentStation = fullCurrentStation;
          if (fullCurrentStation.length > stationMaxLen2) {
            shortCurrentStation = fullCurrentStation.slice(0, stationMaxLen2 - 3).trimEnd() + "...";
          }
          stationEl.textContent = shortCurrentStation;
          stationEl.title = fullCurrentStation;
        } else {
          stationEl.textContent = "";
          stationEl.removeAttribute("title");
        }
      }
      if (nowEl) {
        if (waterLevelCurrent && waterLevelCurrent.h !== undefined && waterLevelCurrent.h !== null && !isNaN(parseFloat(waterLevelCurrent.h))) {
          nowEl.textContent = "Now " + parseFloat(waterLevelCurrent.h).toFixed(1) + " ft";
        } else {
          nowEl.textContent = "Now —";
        }
      }
      if (startEl) startEl.textContent = "—";
      if (endEl) endEl.textContent = "—";
      if (emptyEl) {
        var emptyMsg = "Tide data unavailable.";
        if (marineMeta) {
          if (marineMeta.tideUnavailable) {
            emptyMsg = marineMeta.tideUnavailable;
          } else if (marineMeta.waterLevelUnavailable) {
            emptyMsg = marineMeta.waterLevelUnavailable;
          } else if (sourceType === "waterLevel") {
            emptyMsg = "Water level data unavailable.";
          }
        }
        if (waterLevelCurrent && waterLevelCurrent.h !== undefined && waterLevelCurrent.h !== null && !isNaN(parseFloat(waterLevelCurrent.h))) {
          emptyMsg = "Current water level available; trend graph is unavailable right now.";
        }
        emptyEl.textContent = emptyMsg;
        emptyEl.classList.remove("d-none");
      }
      wrap.classList.remove("d-none");
      return;
    }

    if (emptyEl) emptyEl.classList.add("d-none");
    if (stationEl) {
      var fullStation = String(tide.stationName || tide.STATIONNAME || "").trim();
      var stationMaxLen = 24;
      var shortStation = fullStation;
      if (fullStation.length > stationMaxLen) {
        shortStation = fullStation.slice(0, stationMaxLen - 3).trimEnd() + "...";
      }
      stationEl.textContent = shortStation;
      stationEl.title = fullStation;
    }
    wrap.classList.remove("d-none");

    var minH = Number.POSITIVE_INFINITY;
    var maxH = Number.NEGATIVE_INFINITY;
    var points = [];

    function parseTideDate(raw) {
      if (!raw) return null;
      var s = String(raw).trim();
      var d = new Date(s);
      if (!isNaN(d.getTime())) return d;
      if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(s)) {
        d = new Date(s.replace(" ", "T") + "Z");
        if (!isNaN(d.getTime())) return d;
        d = new Date(s.replace(" ", "T"));
        if (!isNaN(d.getTime())) return d;
      }
      return null;
    }

    series.forEach(function (p) {
      var h = parseFloat((p && p.h !== undefined) ? p.h : (p ? p.H : NaN));
      if (!Number.isFinite(h)) return;
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
      var tRaw = p && (p.t || p.T) ? (p.t || p.T) : "";
      var dt = parseTideDate(tRaw);
      points.push({ h: h, tRaw: tRaw, dt: dt });
    });
    if (!Number.isFinite(minH) || !Number.isFinite(maxH) || minH === maxH) {
      minH = (Number.isFinite(minH) ? minH - 1 : 0);
      maxH = (Number.isFinite(maxH) ? maxH + 1 : 1);
    }

    var wrapRect = wrap.getBoundingClientRect ? wrap.getBoundingClientRect() : null;
    var wrapWidth = Math.round((wrapRect && wrapRect.width) ? wrapRect.width : (wrap.offsetWidth || wrap.clientWidth || 0));
    var w = Math.round(wrapWidth || svg.clientWidth || 320);
    var hgt = Math.round(svg.clientHeight || 84);
    tideLastWrapWidth = wrapWidth || w;
    if (w < 120) w = 320;
    if (hgt < 40) hgt = 120;
    svg.setAttribute("viewBox", "0 0 " + w + " " + hgt);
    var padTop = 8;
    var padBottom = 14;
    var padLeft = 30;
    var padRight = 30;
    var plotW = (w - padLeft - padRight);
    var plotH = (hgt - padTop - padBottom);
    var dx = (points.length > 1) ? (plotW / (points.length - 1)) : 0;
    var path = "";
    var area = "";

    points.forEach(function (p, i) {
      var v = parseFloat(p.h);
      if (!Number.isFinite(v)) v = minH;
      var x = padLeft + (dx * i);
      var y = padTop + plotH * (1 - ((v - minH) / (maxH - minH)));
      p.x = x;
      p.y = y;
      path += (i === 0 ? "M" : "L") + x.toFixed(2) + " " + y.toFixed(2) + " ";
      area += (i === 0 ? "M" : "L") + x.toFixed(2) + " " + y.toFixed(2) + " ";
    });

    var lastX = padLeft + dx * (points.length - 1);
    var areaPath = area + "L " + lastX.toFixed(2) + " " + (hgt - padBottom).toFixed(2)
      + " L " + padLeft.toFixed(2) + " " + (hgt - padBottom).toFixed(2) + " Z";

    function formatAxisHour(raw) {
      var dt = parseTideDate(raw);
      if (!dt) return "";
      var h = dt.getHours() % 12;
      return String(h === 0 ? 12 : h);
    }

    var axesOverlay = "";
    var xAxisY = (hgt - padBottom).toFixed(2);
    var yAxisX = padLeft.toFixed(2);
    axesOverlay += "<line class=\"fpw-wx__tideAxisLine\" x1=\"" + yAxisX + "\" y1=\"" + padTop.toFixed(2) + "\" x2=\"" + yAxisX + "\" y2=\"" + xAxisY + "\"/>";
    axesOverlay += "<line class=\"fpw-wx__tideAxisLine\" x1=\"" + yAxisX + "\" y1=\"" + xAxisY + "\" x2=\"" + (w - padRight).toFixed(2) + "\" y2=\"" + xAxisY + "\"/>";

    var yTicks = 4;
    var yi;
    for (yi = 0; yi <= yTicks; yi++) {
      var fracY = yi / yTicks;
      var yVal = maxH - ((maxH - minH) * fracY);
      var yPos = (padTop + (plotH * fracY));
      axesOverlay += "<line class=\"fpw-wx__tideAxisTick\" x1=\"" + (padLeft - 4).toFixed(2) + "\" y1=\"" + yPos.toFixed(2) + "\" x2=\"" + padLeft.toFixed(2) + "\" y2=\"" + yPos.toFixed(2) + "\"/>";
      axesOverlay += "<text class=\"fpw-wx__tideAxisLabel y\" x=\"" + (padLeft - 6).toFixed(2) + "\" y=\"" + (yPos + 3).toFixed(2) + "\">" + yVal.toFixed(1) + "</text>";
    }

    var xTickCount = Math.min(5, points.length);
    var xi;
    for (xi = 0; xi < xTickCount; xi++) {
      var idx = Math.round((xi * (points.length - 1)) / Math.max(1, (xTickCount - 1)));
      idx = Math.max(0, Math.min(points.length - 1, idx));
      var px = points[idx].x;
      var lbl = formatAxisHour(points[idx].tRaw);
      axesOverlay += "<line class=\"fpw-wx__tideAxisTick\" x1=\"" + px.toFixed(2) + "\" y1=\"" + xAxisY + "\" x2=\"" + px.toFixed(2) + "\" y2=\"" + (hgt - padBottom + 4).toFixed(2) + "\"/>";
      if (lbl) {
        axesOverlay += "<text class=\"fpw-wx__tideAxisLabel x\" x=\"" + px.toFixed(2) + "\" y=\"" + (hgt - 1).toFixed(2) + "\">" + lbl + "</text>";
      }
    }

    var nowMs = Date.now();
    var currentH = null;
    var currentX = null;
    var currentY = null;
    var i;
    for (i = 0; i < points.length - 1; i++) {
      var a = points[i];
      var b = points[i + 1];
      if (!a.dt || !b.dt) continue;
      var ams = a.dt.getTime();
      var bms = b.dt.getTime();
      if (bms <= ams) continue;
      if (nowMs >= ams && nowMs <= bms) {
        var r = (nowMs - ams) / (bms - ams);
        currentH = a.h + ((b.h - a.h) * r);
        currentX = a.x + ((b.x - a.x) * r);
        currentY = a.y + ((b.y - a.y) * r);
        break;
      }
    }
    if (currentH === null) {
      var nearest = null;
      points.forEach(function (pnt) {
        if (!pnt.dt) return;
        var diff = Math.abs(nowMs - pnt.dt.getTime());
        if (!nearest || diff < nearest.diff) {
          nearest = { diff: diff, p: pnt };
        }
      });
      if (nearest && nearest.p) {
        currentH = nearest.p.h;
        currentX = nearest.p.x;
        currentY = nearest.p.y;
      }
    }

    var nowOverlay = "";
    if (currentH !== null && currentX !== null && currentY !== null) {
      var tickY = currentY.toFixed(2);
      var guideStartX = padLeft.toFixed(2);
      nowOverlay = ""
        + "<line class=\"fpw-wx__tideGuide\" x1=\"" + guideStartX + "\" y1=\"" + tickY + "\" x2=\"" + (w - padRight).toFixed(2) + "\" y2=\"" + tickY + "\"/>"
        + "<circle class=\"fpw-wx__tideNowHalo\" cx=\"" + currentX.toFixed(2) + "\" cy=\"" + currentY.toFixed(2) + "\" r=\"6\"/>"
        + "<circle class=\"fpw-wx__tideNowDot\" cx=\"" + currentX.toFixed(2) + "\" cy=\"" + currentY.toFixed(2) + "\" r=\"3\"/>";
      if (nowEl) nowEl.textContent = "Now " + currentH.toFixed(1) + " ft";
    } else if (nowEl) {
      nowEl.textContent = "Now —";
    }

    var highIdx = -1;
    var lowIdx = -1;
    var highVal = Number.NEGATIVE_INFINITY;
    var lowVal = Number.POSITIVE_INFINITY;
    points.forEach(function (p, idx) {
      if (!Number.isFinite(p.h)) return;
      if (p.h > highVal) {
        highVal = p.h;
        highIdx = idx;
      }
      if (p.h < lowVal) {
        lowVal = p.h;
        lowIdx = idx;
      }
    });

    function clamp(n, min, max) {
      return Math.max(min, Math.min(max, n));
    }

    function buildExtremaLabel(pt, cls, preferAbove) {
      if (!pt) return "";
      var label = pt.h.toFixed(1) + " ft";
      var textW = Math.max(46, (label.length * 4.2));
      var tx = clamp(pt.x - (textW / 2), padLeft + 2, (w - padRight - textW - 2));
      var yOffset = preferAbove ? -7 : 11;
      var ty = pt.y + yOffset;
      if (preferAbove && ty < (padTop + 7)) ty = pt.y + 11;
      if (!preferAbove && ty > (hgt - padBottom - 2)) ty = pt.y - 7;
      return ""
        + "<circle class=\"fpw-wx__tideExtDot " + cls + "\" cx=\"" + pt.x.toFixed(2) + "\" cy=\"" + pt.y.toFixed(2) + "\" r=\"2.8\"/>"
        + "<text class=\"fpw-wx__tideExtLabel " + cls + "\" x=\"" + tx.toFixed(2) + "\" y=\"" + ty.toFixed(2) + "\">" + label + "</text>";
    }

    var extremaOverlay = "";
    if (highIdx >= 0) {
      extremaOverlay += buildExtremaLabel(points[highIdx], "high", true);
    }
    if (lowIdx >= 0) {
      var lowPreferAbove = false;
      if (highIdx >= 0 && Math.abs(points[highIdx].x - points[lowIdx].x) < 44) {
        lowPreferAbove = true;
      }
      extremaOverlay += buildExtremaLabel(points[lowIdx], "low", lowPreferAbove);
    }

    svg.innerHTML = ""
      + "<defs>"
      + "<linearGradient id=\"tideFill\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
      + "<stop offset=\"0%\" stop-color=\"rgba(59,130,246,.45)\"/>"
      + "<stop offset=\"100%\" stop-color=\"rgba(59,130,246,0)\"/>"
      + "</linearGradient>"
      + "</defs>"
      + axesOverlay
      + "<path d=\"" + areaPath + "\" fill=\"url(#tideFill)\"/>"
      + "<path d=\"" + path + "\" fill=\"none\" stroke=\"rgba(59,130,246,.9)\" stroke-width=\"2\"/>"
      + extremaOverlay
      + nowOverlay;

    if (startEl) startEl.textContent = series[0] && (series[0].t || series[0].T) ? (series[0].t || series[0].T) : "—";
    if (endEl) endEl.textContent = series[series.length - 1] && (series[series.length - 1].t || series[series.length - 1].T) ? (series[series.length - 1].t || series[series.length - 1].T) : "—";
    wrap.classList.remove("d-none");
  }

  function renderWeatherSummary(summary, message) {
    var summaryEl = document.getElementById("weatherSummary");
    if (!summaryEl) return;
    var text = summary || message || "Forecast unavailable.";
    summaryEl.dataset.baseSummary = text;
    dashboardSignals.weather.summary = text;
    applySummaryDecoration(summaryEl);
    refreshMissionSummary();
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

  function setVisibilityHorizon(visMi, stationId, obsTimeIso) {
    var root = document.getElementById("visHorizon");
    if (!root) return;

    var valEl = document.getElementById("visValue");
    var statusEl = document.getElementById("visStatus");
    var fogEl = document.getElementById("visFog");
    var rangeEl = document.getElementById("visRangeText");
    var foot = document.getElementById("visFootnote");
    var horizonLine = root.querySelector(".vis-horizonLine");
    var grid = root.querySelector(".vis-grid");
    var hasNum = (typeof visMi === "number") && isFinite(visMi);
    var label = "";
    var state = "clear";
    var status = "CLEAR";
    var capped = 0;
    var fog = 0;
    var localObsText = "";

    if (!valEl || !statusEl || !fogEl || !rangeEl || !foot || !horizonLine || !grid) return;

    if (!hasNum) {
      valEl.innerHTML = "— <span class=\"vis-unit\">mi</span>";
      statusEl.textContent = "UNKNOWN";
      root.setAttribute("data-vis-state", "unknown");
      fogEl.style.opacity = "0.35";
      grid.style.opacity = "0.30";
      horizonLine.style.opacity = "0.55";
      horizonLine.style.boxShadow = "0 0 8px rgba(255,255,255,.08)";
      rangeEl.textContent = "Range: —";
      foot.textContent = "No METAR visibility available";
      return;
    }

    label = (visMi >= 10) ? "10+" : (visMi < 1 ? visMi.toFixed(1) : Math.round(visMi).toString());
    valEl.innerHTML = label + " <span class=\"vis-unit\">mi</span>";
    rangeEl.textContent = "Range: " + label + " mi";

    if (visMi < 1) {
      state = "fog";
      status = "FOG";
    } else if (visMi < 2) {
      state = "restricted";
      status = "RESTRICTED";
    } else if (visMi < 4) {
      state = "haze";
      status = "HAZE";
    } else if (visMi < 7) {
      state = "good";
      status = "GOOD";
    }

    root.setAttribute("data-vis-state", state);
    statusEl.textContent = status;

    capped = Math.max(0, Math.min(10, visMi));
    fog = (10 - capped) / 10;
    fogEl.style.opacity = (0.10 + fog * 0.55).toFixed(2);
    grid.style.opacity = (0.65 - fog * 0.35).toFixed(2);
    horizonLine.style.opacity = (0.95 - fog * 0.35).toFixed(2);
    horizonLine.style.boxShadow = "0 0 " + (8 + (1 - fog) * 10) + "px rgba(255,255,255," + (0.08 + (1 - fog) * 0.10) + ")";

    if (stationId && obsTimeIso) {
      localObsText = "";
      try {
        localObsText = (new Date(obsTimeIso)).toLocaleString();
      } catch (eObsTime) {
        localObsText = String(obsTimeIso);
      }
      foot.textContent = "METAR " + stationId + " • " + localObsText;
    } else {
      foot.textContent = "Based on latest METAR";
    }
  }

  // Surface obs (METAR) hydration for pressure + visibility cards.
  function renderWeatherSurface(surface) {
    var pressureCardEl = document.querySelector(".fpw-wx__pressure");
    var pressureTrendRowEl = document.getElementById("weatherPressureTrendRow");
    var pressureNeedleEl = document.getElementById("pressureNeedle");
    var pressureValueEl = document.getElementById("weatherPressureValue");
    var pressureArrowEl = document.getElementById("weatherPressureTrend");
    var pressureTrendLabelEl = document.getElementById("weatherPressureTrendLabel");
    var pressureRateEl = document.getElementById("weatherPressureRate");
    var pressureSparklineLineEl = document.getElementById("weatherPressureSparklineLine");
    var visCardEl = document.querySelector(".fpw-wx__vis");
    var data = surface || {};
    var pressureRaw = (data.pressure_inhg !== undefined && data.pressure_inhg !== null) ? data.pressure_inhg : data.PRESSURE_INHG;
    var visibilityRaw = (data.visibility_mi !== undefined && data.visibility_mi !== null) ? data.visibility_mi : data.VISIBILITY_MI;
    var trendRaw = (data.pressure_trend !== undefined && data.pressure_trend !== null) ? data.pressure_trend : data.PRESSURE_TREND;
    var pressureRateRaw = (data.pressure_rate_per_hr !== undefined && data.pressure_rate_per_hr !== null) ? data.pressure_rate_per_hr : data.PRESSURE_RATE_PER_HR;
    var stationRaw = (data.station_id !== undefined && data.station_id !== null) ? data.station_id : data.STATION_ID;
    var obsTimeRaw = (data.observation_time !== undefined && data.observation_time !== null) ? data.observation_time : data.OBSERVATION_TIME;
    var pressureNum = parseFloat(pressureRaw);
    var visibilityNum = parseFloat(visibilityRaw);
    var pressureRateNum = parseFloat(pressureRateRaw);
    var stationTxt = stationRaw ? String(stationRaw).trim() : "";
    var obsTimeTxt = "";
    var obsDate = null;
    var trendTxt = trendRaw ? String(trendRaw).trim().toLowerCase() : "";
    var trendArrow = "→";
    var trendLabel = "Unknown";
    var trendRateText = "—";
    var obsLabel = "";
    var sparklinePoints = "0,15 20,15 40,15 60,15 80,15 100,15";
    var sparklineWidth = "55%";
    var hasTrendState = false;
    var hasTrendData = false;

    if (obsTimeRaw !== undefined && obsTimeRaw !== null && String(obsTimeRaw).trim()) {
      obsDate = new Date(obsTimeRaw);
      if (obsDate && !Number.isNaN(obsDate.getTime())) {
        obsTimeTxt = obsDate.toLocaleString();
      } else {
        obsTimeTxt = String(obsTimeRaw).trim();
      }
    }

    if (!trendTxt && Number.isFinite(pressureRateNum)) {
      if (pressureRateNum >= 0.06) {
        trendTxt = "rapid_rise";
      } else if (pressureRateNum > 0.01) {
        trendTxt = "rising";
      } else if (pressureRateNum <= -0.06) {
        trendTxt = "rapid_fall";
      } else if (pressureRateNum < -0.01) {
        trendTxt = "falling";
      } else {
        trendTxt = "steady";
      }
    }

    if (trendTxt === "up") trendTxt = "rising";
    if (trendTxt === "down") trendTxt = "falling";
    if (
      trendTxt !== "rapid_fall"
      && trendTxt !== "falling"
      && trendTxt !== "steady"
      && trendTxt !== "rising"
      && trendTxt !== "rapid_rise"
    ) {
      trendTxt = "";
    }

    if (trendTxt === "rapid_fall") {
      trendArrow = "↓";
      trendLabel = "Rapid Fall";
      sparklinePoints = "0,6 20,9 40,12 60,16 80,21 100,25";
      sparklineWidth = "90%";
      hasTrendState = true;
    } else if (trendTxt === "falling") {
      trendArrow = "↓";
      trendLabel = "Falling";
      sparklinePoints = "0,10 20,12 40,14 60,16 80,18 100,20";
      sparklineWidth = "78%";
      hasTrendState = true;
    } else if (trendTxt === "steady") {
      trendArrow = "→";
      trendLabel = "Steady";
      sparklinePoints = "0,15 20,15 40,15 60,15 80,15 100,15";
      sparklineWidth = "55%";
      hasTrendState = true;
    } else if (trendTxt === "rising") {
      trendArrow = "↑";
      trendLabel = "Rising";
      sparklinePoints = "0,20 20,18 40,16 60,14 80,12 100,10";
      sparklineWidth = "78%";
      hasTrendState = true;
    } else if (trendTxt === "rapid_rise") {
      trendArrow = "↑";
      trendLabel = "Rapid Rise";
      sparklinePoints = "0,25 20,21 40,17 60,13 80,9 100,6";
      sparklineWidth = "90%";
      hasTrendState = true;
    }

    if (pressureCardEl) {
      hasTrendData = hasTrendState && Number.isFinite(pressureRateNum);
      if (hasTrendData) {
        pressureCardEl.setAttribute("data-trend", trendTxt);
      } else {
        pressureCardEl.removeAttribute("data-trend");
      }
    }

    if (pressureTrendRowEl) {
      // Keep row space reserved so dial position does not shift when trend appears/disappears.
      pressureTrendRowEl.classList.remove("d-none");
      if (hasTrendData) {
        pressureTrendRowEl.classList.remove("pressure-sub--hidden");
        pressureTrendRowEl.removeAttribute("aria-hidden");
      } else {
        pressureTrendRowEl.classList.add("pressure-sub--hidden");
        pressureTrendRowEl.setAttribute("aria-hidden", "true");
      }
    }

    if (pressureValueEl) {
      if (Number.isFinite(pressureNum) && pressureNum > 0) {
        pressureValueEl.textContent = pressureNum.toFixed(2);
      } else {
        pressureValueEl.textContent = "—";
      }
    }

    if (pressureNeedleEl) {
      var pressureMin = 28.8;
      var pressureMax = 30.8;
      var pressureClamped = Number.isFinite(pressureNum) && pressureNum > 0 ? Math.max(pressureMin, Math.min(pressureMax, pressureNum)) : 29.8;
      var pressureRatio = (pressureClamped - pressureMin) / (pressureMax - pressureMin);
      // Map exactly to this semicircle dial: 28.8 (left) -> 29.8 (top) -> 30.8 (right).
      var pressureAngle = -90 + (pressureRatio * 180);
      pressureNeedleEl.style.transform = "rotate(" + pressureAngle.toFixed(2) + "deg)";
    }

    if (pressureArrowEl) {
      pressureArrowEl.textContent = trendArrow;
    }

    if (pressureTrendLabelEl) {
      pressureTrendLabelEl.textContent = trendLabel;
    }

    if (pressureRateEl) {
      if (Number.isFinite(pressureRateNum)) {
        trendRateText = (pressureRateNum >= 0 ? "+" : "") + pressureRateNum.toFixed(2) + "/hr";
      }
      pressureRateEl.textContent = trendRateText;
    }

    if (pressureSparklineLineEl) {
      if (
        pressureSparklineLineEl.tagName
        && pressureSparklineLineEl.tagName.toLowerCase() === "polyline"
      ) {
        pressureSparklineLineEl.setAttribute("points", sparklinePoints);
      } else {
        pressureSparklineLineEl.style.width = sparklineWidth;
      }
    }

    setVisibilityHorizon(
      (Number.isFinite(visibilityNum) ? visibilityNum : NaN),
      stationTxt,
      (obsTimeRaw !== undefined && obsTimeRaw !== null ? String(obsTimeRaw) : "")
    );

    if (stationTxt) {
      obsLabel = "Obs: " + stationTxt + (obsTimeTxt ? " • " + obsTimeTxt + " (local)" : "");
    }

    [pressureCardEl, pressureNeedleEl, pressureValueEl, pressureArrowEl, pressureTrendLabelEl, pressureRateEl, visCardEl, document.getElementById("visValue"), document.getElementById("visStatus"), document.getElementById("visFootnote")].forEach(function (el) {
      if (!el) return;
      if (obsLabel) {
        el.setAttribute("title", obsLabel);
      } else {
        el.removeAttribute("title");
      }
    });
  }

  function formatWaveDirection(directionDeg) {
    var labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    var normalized = 0;
    var idx = 0;
    var rounded = 0;
    if (!Number.isFinite(directionDeg)) {
      return "--";
    }
    normalized = directionDeg % 360;
    if (normalized < 0) normalized += 360;
    idx = Math.round(normalized / 45) % 8;
    rounded = Math.round(normalized);
    if (rounded < 10) return labels[idx] + " 00" + rounded + "°";
    if (rounded < 100) return labels[idx] + " 0" + rounded + "°";
    return labels[idx] + " " + rounded + "°";
  }

  function renderWaveHeight(marine) {
    var waveEl = document.getElementById("wxWaveHeight");
    var waveCard = document.querySelector(".wave-card");
    var needle = document.getElementById("seaNeedle");
    var waveAmp = document.getElementById("seaWaveAmp");
    var frontTrack = document.getElementById("seaWaveFrontTrack");
    var backTrack = document.getElementById("seaWaveBackTrack");
    var beaufortEl = document.getElementById("seaBeaufortLevel");
    var periodEl = document.getElementById("seaWavePeriodValue");
    var directionEl = document.getElementById("seaWaveDirectionValue");
    var trendEl = document.getElementById("seaWaveTrendValue");
    var titleLabelEl = document.getElementById("seaWaveTitleLabel");
    var marineData = marine || {};
    var wavesData = marineData.waves || marineData.WAVES || {};
    var waveHeightFt = NaN;
    var hasWaveReading = false;
    var periodSec = NaN;
    var directionDeg = NaN;
    var maxScale = 12;
    var clamped = 0;
    var ratio = 0;
    var angle = -120;
    var ampScale = 0.8;
    var ampShift = 14;
    var severity = "calm";
    var beaufortLevel = 0;
    var trendLabel = "STEADY";
    var trendClass = "steady";
    var delta = 0;
    var frontSpeed = 6;
    var backSpeed = 9;

    if (marineData.wave_height_ft !== undefined && marineData.wave_height_ft !== null) {
      waveHeightFt = parseFloat(marineData.wave_height_ft);
    } else if (marineData.WAVE_HEIGHT_FT !== undefined && marineData.WAVE_HEIGHT_FT !== null) {
      waveHeightFt = parseFloat(marineData.WAVE_HEIGHT_FT);
    } else if (wavesData.height !== undefined && wavesData.height !== null) {
      waveHeightFt = parseFloat(wavesData.height);
    }

    if (Number.isFinite(waveHeightFt) && waveHeightFt >= 0) {
      hasWaveReading = true;
    } else {
      waveHeightFt = 0;
    }

    if (hasWaveReading) {
      clamped = Math.min(Math.max(waveHeightFt, 0), maxScale);
    } else {
      clamped = 0;
    }
    ratio = clamped / maxScale;
    angle = -90 + (ratio * 180);
    ampScale = 0.8 + (ratio * 0.72);
    ampShift = 14 - (ratio * 18);

    if (waveEl) {
      waveEl.textContent = hasWaveReading ? clamped.toFixed(1) : "--";
    }
    if (titleLabelEl) {
      titleLabelEl.textContent = hasWaveReading ? "WAVE HEIGHT" : "NO WAVE OBSERVATION";
    }

    if (needle) {
      needle.style.transform = "rotate(" + angle.toFixed(2) + "deg)";
    }

    if (waveAmp) {
      waveAmp.style.transform = "translateY(" + ampShift.toFixed(1) + "px) scaleY(" + ampScale.toFixed(2) + ")";
    }

    if (clamped < 2) {
      severity = "calm";
      frontSpeed = 6;
      backSpeed = 9;
    } else if (clamped < 5) {
      severity = "moderate";
      frontSpeed = 5;
      backSpeed = 8;
    } else if (clamped < 8) {
      severity = "rough";
      frontSpeed = 4;
      backSpeed = 6.5;
    } else {
      severity = "severe";
      frontSpeed = 3;
      backSpeed = 5;
    }

    if (frontTrack) {
      frontTrack.style.animationDuration = frontSpeed + "s";
    }
    if (backTrack) {
      backTrack.style.animationDuration = backSpeed + "s";
    }

    if (waveCard) {
      waveCard.classList.remove("wave-calm", "wave-moderate", "wave-rough", "wave-severe");
      waveCard.classList.add("wave-" + severity);
      waveCard.setAttribute("data-severity", severity);
      if (hasWaveReading) {
        waveCard.classList.remove("no-wave-data");
      } else {
        waveCard.classList.add("no-wave-data");
      }
    }

    if (wavesData.period !== undefined && wavesData.period !== null) {
      periodSec = parseFloat(wavesData.period);
    }
    if (wavesData.directionDeg !== undefined && wavesData.directionDeg !== null) {
      directionDeg = parseFloat(wavesData.directionDeg);
    }

    if (beaufortEl) {
      if (hasWaveReading) {
        beaufortLevel = Math.max(0, Math.min(12, Math.round(clamped / 0.8)));
        beaufortEl.textContent = "Level " + beaufortLevel;
      } else {
        beaufortEl.textContent = "Level --";
      }
    }

    if (periodEl) {
      if (Number.isFinite(periodSec) && periodSec > 0) {
        periodEl.textContent = periodSec.toFixed(periodSec < 10 ? 1 : 0) + " s";
      } else {
        periodEl.textContent = "--";
      }
    }

    if (directionEl) {
      if (Number.isFinite(directionDeg) && directionDeg >= 0) {
        directionEl.textContent = formatWaveDirection(directionDeg);
      } else {
        directionEl.textContent = "--";
      }
    }

    if (!hasWaveReading) {
      seaStateLastWaveHeight = null;
    }
    if (hasWaveReading && Number.isFinite(seaStateLastWaveHeight)) {
      delta = clamped - seaStateLastWaveHeight;
      if (delta > 0.15) {
        trendLabel = "RISING";
        trendClass = "rising";
      } else if (delta < -0.15) {
        trendLabel = "FALLING";
        trendClass = "falling";
      }
    }

    if (hasWaveReading) {
      seaStateLastWaveHeight = clamped;
    }

    if (trendEl) {
      trendEl.classList.remove("rising", "falling", "steady");
      trendEl.classList.add(trendClass);
      trendEl.textContent = trendLabel;
    }
    renderWeatherPreview();
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
    var hi = summaryEl.dataset.hi;
    var lo = summaryEl.dataset.lo;
    var parts = [];
    if (base) {
      parts.push(base);
    }
    if (hi && lo) {
      parts.push( hi + "°/" + lo + "°");
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
    titleEl.textContent = "";
  }


  function normalizeZip(value) {
    return (value || "")
      .toString()
      .replace(/\D/g, "")
      .slice(0, 5);
  }

  function normalizeCoordinateInput(value) {
    return (value || "").toString().trim();
  }

  function isValidZip(zip) {
    return zip && zip.length === 5;
  }

  function parseCoordinateValue(value, minVal, maxVal) {
    var txt = normalizeCoordinateInput(value);
    var parsed = 0;
    if (!txt.length) return { valid: false, empty: true, value: null };
    if (!/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)$/.test(txt)) {
      return { valid: false, empty: false, value: null };
    }
    parsed = parseFloat(txt);
    if (!Number.isFinite(parsed) || parsed < minVal || parsed > maxVal) {
      return { valid: false, empty: false, value: null };
    }
    return { valid: true, empty: false, value: parsed };
  }

  function weatherUrl(location, extras) {
    var loc = location || {};
    var mode = String(loc.mode || "zip").toLowerCase();
    var query = "method=handle&action=search&returnformat=json";
    if (mode === "coords") {
      query += "&lat=" + encodeURIComponent(loc.lat);
      query += "&lon=" + encodeURIComponent(loc.lon);
    } else {
      query += "&zip=" + encodeURIComponent(loc.zip || "");
    }
    var url = WEATHER_BASE_URL + "?" + query;
    if (extras) {
      url += extras;
    }
    return url;
  }

  function fetchWeatherJson(url) {
    return fetch(url, { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Request failed with status " + response.status);
        }
        return response.json();
      });
  }

  function hydrateMarineTrend(location, requestSeq) {
    return fetchWeatherJson(weatherUrl(location, "&marineOnly=1&marineMode=full"))
      .then(function (payload) {
        if (requestSeq !== weatherRequestSeq) return;
        if (!payload || payload.SUCCESS === false) return;
        var data = payload.DATA || {};
        if (data.MARINE) {
          renderTideGraph(data.MARINE);
          renderWaveHeight(data.MARINE);
        }
      })
      .catch(function () {
        // Keep initial quick render if trend hydration fails.
      });
  }

  function loadWeather(location) {
    var loadingEl = document.getElementById("weatherLoading");
    if (!loadingEl) {
      return;
    }
    weatherRequestSeq += 1;
    var requestSeq = weatherRequestSeq;

    toggleHidden(loadingEl, false);
    clearWeatherError();

    return fetchWeatherJson(weatherUrl(location, "&marineMode=quick"))
      .then(function (payload) {
        if (requestSeq !== weatherRequestSeq) return;
        if (!payload || payload.SUCCESS === false) {
          var message = payload && payload.MESSAGE ? payload.MESSAGE : null;
          throw new Error(message || "Weather data unavailable.");
        }

        var data = payload.DATA || {};
        renderWeatherSummary(data.SUMMARY, payload.MESSAGE);
        renderWeatherAnchor(data.META);
        renderWeatherAlerts(data.ALERTS);
        renderWeatherForecast(data.FORECAST);
        renderWeatherSurface(data.surface || data.SURFACE || null);
        renderTideGraph(data.MARINE);
        renderWaveHeight(data.MARINE);
        hydrateMarineTrend(location, requestSeq);
      })
      .catch(function (err) {
        if (requestSeq !== weatherRequestSeq) return;
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        renderWeatherSurface(null);
        renderTideGraph(null);
        renderWaveHeight(null);
        setWeatherError((err && err.message) ? err.message : null);
      })
      .finally(function () {
        toggleHidden(loadingEl, true);
      });
  }

  function initWeatherPanel(initialZip, initialLatLng) {
    var refreshBtn = document.getElementById("weatherRefreshBtn");
    var zipInput = document.getElementById("weatherZip");
    var locationModeEl = document.getElementById("weatherLocationMode");
    var zipBlockEl = document.getElementById("weatherZipBlock");
    if (!zipBlockEl && zipInput && typeof zipInput.closest === "function") {
      zipBlockEl = zipInput.closest(".fpw-wx__zipBlock");
    }
    var coordsLatBlockEl = document.getElementById("weatherCoordsBlock");
    var coordsLonBlockEl = document.getElementById("weatherCoordsLonBlock");
    var latInput = document.getElementById("weatherLat");
    var lonInput = document.getElementById("weatherLon");
    if (!refreshBtn) {
      return;
    }

    updateWeatherTitleDate();

    if (zipInput && initialZip) {
      zipInput.value = normalizeZip(initialZip);
    }

    if (latInput && initialLatLng && Number.isFinite(initialLatLng.lat)) {
      latInput.value = String(initialLatLng.lat);
    }
    if (lonInput && initialLatLng && Number.isFinite(initialLatLng.lng)) {
      lonInput.value = String(initialLatLng.lng);
    }

    function clearWeatherPanelsForError() {
      renderWeatherSummary("", "");
      renderWeatherAnchor(null);
      renderWeatherAlerts([]);
      renderWeatherForecast([]);
      renderWeatherSurface(null);
      renderTideGraph(null);
      renderWaveHeight(null);
    }

    function activeLocationMode() {
      var mode = locationModeEl ? String(locationModeEl.value || "zip").toLowerCase() : "zip";
      return mode === "coords" ? "coords" : "zip";
    }

    function syncLocationModeUI() {
      var mode = activeLocationMode();
      if (zipBlockEl) zipBlockEl.classList.toggle("d-none", mode !== "zip");
      if (coordsLatBlockEl) coordsLatBlockEl.classList.toggle("d-none", mode !== "coords");
      if (coordsLonBlockEl) coordsLonBlockEl.classList.toggle("d-none", mode !== "coords");
    }

    function requestWeatherFromInput(invalidZipMessage) {
      var mode = activeLocationMode();
      var zip = "";
      var latRaw = "";
      var lonRaw = "";
      var latParsed = {};
      var lonParsed = {};
      var location = {};

      if (mode === "coords") {
        latRaw = normalizeCoordinateInput(latInput ? latInput.value : "");
        lonRaw = normalizeCoordinateInput(lonInput ? lonInput.value : "");
        if (latInput) latInput.value = latRaw;
        if (lonInput) lonInput.value = lonRaw;

        if ((latRaw && !lonRaw) || (!latRaw && lonRaw)) {
          clearWeatherPanelsForError();
          setWeatherError("Enter both latitude and longitude.");
          return;
        }

        latParsed = parseCoordinateValue(latRaw, -90, 90);
        if (!latParsed.valid) {
          clearWeatherPanelsForError();
          setWeatherError("Enter a valid latitude between -90 and 90.");
          return;
        }

        lonParsed = parseCoordinateValue(lonRaw, -180, 180);
        if (!lonParsed.valid) {
          clearWeatherPanelsForError();
          setWeatherError("Enter a valid longitude between -180 and 180.");
          return;
        }

        location = {
          mode: "coords",
          lat: latParsed.value,
          lon: lonParsed.value
        };
      } else {
        zip = normalizeZip(zipInput ? zipInput.value : "");
        if (zipInput) {
          zipInput.value = zip;
        }

        if (!isValidZip(zip)) {
          var msg = invalidZipMessage;
          if (!msg) {
            msg = zip ? "Enter a valid 5-digit ZIP code." : "Home port ZIP is required. Update it in Account settings.";
          }
          clearWeatherPanelsForError();
          setWeatherError(msg);
          return;
        }

        location = {
          mode: "zip",
          zip: zip
        };
      }

      loadWeather(location);
    }

    refreshBtn.addEventListener("click", function () {
      requestWeatherFromInput();
    });

    if (locationModeEl) {
      locationModeEl.addEventListener("change", function () {
        syncLocationModeUI();
      });
    }

    syncLocationModeUI();
    if (AUTO_LOAD_HOME_PORT_WEATHER) {
      requestWeatherFromInput("Home port ZIP is required. Update it in Account settings.");
    } else {
      clearWeatherError();
      renderWeatherSummary("Weather ready - press Refresh to load.", "");
    }
  }

  function formatNumber(value, decimals) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "0";
    var places = (typeof decimals === "number") ? decimals : 0;
    return n.toLocaleString(undefined, {
      minimumFractionDigits: places,
      maximumFractionDigits: places
    });
  }

  function escapeHtml(value) {
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  modules.expeditionTimeline = (function () {
    var currentRouteCode = "";
    var panel = null;
    var summaryEl = null;
    var subtitleEl = null;
    var loadingEl = null;
    var unauthorizedEl = null;
    var errorEl = null;
    var errorTextEl = null;
    var bodyEl = null;
    var routeListEl = null;
    var routeEmptyEl = null;
    var accordionEl = null;
    var retryBtn = null;
    var requestSeq = 0;

    function routeUrl(routeCode) {
      return BASE_PATH + "/api/v1/route.cfc?method=handle&action=getTimeline&routeCode=" + encodeURIComponent(routeCode || "") + "&returnformat=json";
    }

    function routeBuilderUrl(action, params) {
      var query = "method=handle&action=" + encodeURIComponent(action) + "&returnformat=json";
      var k;
      params = params || {};
      for (k in params) {
        if (!Object.prototype.hasOwnProperty.call(params, k)) continue;
        if (params[k] === undefined || params[k] === null || params[k] === "") continue;
        query += "&" + encodeURIComponent(k) + "=" + encodeURIComponent(params[k]);
      }
      return BASE_PATH + "/api/v1/routeBuilder.cfc?" + query;
    }

    function voyageUrl(action, params) {
      var query = "method=handle&action=" + encodeURIComponent(action) + "&returnformat=json";
      var k;
      params = params || {};
      for (k in params) {
        if (!Object.prototype.hasOwnProperty.call(params, k)) continue;
        if (params[k] === undefined || params[k] === null || params[k] === "") continue;
        query += "&" + encodeURIComponent(k) + "=" + encodeURIComponent(params[k]);
      }
      return BASE_PATH + "/api/v1/voyage.cfc?" + query;
    }

    function setState(stateName, message) {
      toggleHidden(loadingEl, stateName !== "loading");
      toggleHidden(unauthorizedEl, stateName !== "unauthorized");
      toggleHidden(errorEl, stateName !== "error");
      toggleHidden(bodyEl, stateName !== "ready");

      if (stateName === "loading" && summaryEl) {
        summaryEl.textContent = "Loading expedition timeline...";
      }
      if (stateName === "error" && errorTextEl) {
        errorTextEl.textContent = message || "Unable to load expedition timeline.";
      }
      if (stateName === "unauthorized" && summaryEl) {
        summaryEl.textContent = "Sign in required";
      }
    }

    function renderEmptyRoutes() {
      if (summaryEl) summaryEl.textContent = "No routes yet";
      if (subtitleEl) subtitleEl.textContent = "Create your first route";
      if (routeListEl) routeListEl.innerHTML = "";
      if (routeEmptyEl) toggleHidden(routeEmptyEl, false);
      if (accordionEl) {
        accordionEl.innerHTML = "";
        toggleHidden(accordionEl, true);
      }
      setRouteSignals("No routes yet", "Create your first route", 0);
      setState("ready");
    }

    function normalizeStatus(status) {
      var s = (status || "").toString().toUpperCase();
      return s === "COMPLETED" ? "COMPLETED" : "NOT_STARTED";
    }

    function renderSummary(data) {
      var totals = data && data.TOTALS ? data.TOTALS : {};
      var pct = Number.isFinite(parseFloat(totals.PCT_COMPLETE)) ? parseFloat(totals.PCT_COMPLETE) : 0;
      var totalNm = Number.isFinite(parseFloat(totals.TOTAL_NM)) ? parseFloat(totals.TOTAL_NM) : 0;
      var totalLocks = Number.isFinite(parseFloat(totals.TOTAL_LOCKS)) ? parseFloat(totals.TOTAL_LOCKS) : 0;
      var summaryText = Math.round(pct) + "% complete • " + formatNumber(totalNm, 1) + " NM • " + formatNumber(totalLocks, 0) + " locks";
      var routeName = (data && data.ROUTE && data.ROUTE.NAME) ? data.ROUTE.NAME : "Route";
      if (summaryEl) {
        summaryEl.textContent = summaryText;
      }
      if (subtitleEl && routeName) {
        subtitleEl.textContent = routeName;
      }
      setRouteSignals(routeName, summaryText, pct);
    }

    function renderRouteList(routes, activeCode) {
      if (!routeListEl) return;
      var list = Array.isArray(routes) ? routes : [];
      if (!list.length) {
        routeListEl.innerHTML = "";
        if (routeEmptyEl) toggleHidden(routeEmptyEl, false);
        return;
      }
      if (routeEmptyEl) toggleHidden(routeEmptyEl, true);
      routeListEl.innerHTML = list.map(function (route) {
        var totals = route && route.TOTALS ? route.TOTALS : {};
        var isActive = route && route.SHORT_CODE && activeCode && route.SHORT_CODE === activeCode;
        var routeInstanceId = route && route.ROUTE_INSTANCE_ID !== undefined && route.ROUTE_INSTANCE_ID !== null
          ? parseInt(route.ROUTE_INSTANCE_ID, 10)
          : (route && route.route_instance_id !== undefined && route.route_instance_id !== null
            ? parseInt(route.route_instance_id, 10)
            : 0);
        var pct = Number.isFinite(parseFloat(totals.PCT_COMPLETE)) ? Math.round(parseFloat(totals.PCT_COMPLETE)) : 0;
        var nm = Number.isFinite(parseFloat(totals.TOTAL_NM)) ? parseFloat(totals.TOTAL_NM) : 0;
        var locks = Number.isFinite(parseFloat(totals.TOTAL_LOCKS)) ? parseFloat(totals.TOTAL_LOCKS) : 0;
        var routeInstanceAttr = Number.isFinite(routeInstanceId) && routeInstanceId > 0
          ? ' data-route-instance-id="' + routeInstanceId + '"'
          : "";
        return ''
          + '<div class="expedition-route-card ' + (isActive ? 'is-active' : '') + '" data-route-code="' + escapeHtml(route.SHORT_CODE || "") + '"' + routeInstanceAttr + '>'
          + '  <div>'
          + '    <div class="expedition-route-name">' + escapeHtml(route.NAME || route.SHORT_CODE || "Route") + '</div>'
          + '    <div class="expedition-route-meta">' + pct + '% complete • ' + formatNumber(nm, 1) + ' NM • ' + formatNumber(locks, 0) + ' locks</div>'
          + '  </div>'
          + '  <div class="expedition-route-actions">'
          + '    <button type="button" class="btn-secondary js-expedition-build-floatplans">Build Float Plans</button>'
          + '    <button type="button" class="btn-secondary js-expedition-follower-page">Follower Page</button>'
          + '    <button type="button" class="btn-secondary js-expedition-view-edit">View / Edit</button>'
          + '    <button type="button" class="btn-secondary js-expedition-delete">Delete</button>'
          + '  </div>'
          + '</div>';
      }).join("");
    }

    function renderTimeline(data) {
      if (!accordionEl) return;
      // Keep dashboard panel condensed: route card only, no expandable rows.
      accordionEl.innerHTML = "";
      toggleHidden(accordionEl, true);
    }

    function setActiveRoute(routeCode) {
      if (!routeCode) return Promise.resolve();
      return fetch(routeBuilderUrl("setActiveRoute", { routeCode: routeCode }), { credentials: "same-origin" }).catch(function () {
        return null;
      });
    }

    function openEditor(routeCode) {
      var rb = window.FPW && window.FPW.DashboardModules ? window.FPW.DashboardModules.routeBuilder : null;
      if (rb && typeof rb.openEditorForRoute === "function") {
        rb.openEditorForRoute(routeCode);
      }
    }

    function deleteRoute(routeCode) {
      if (!routeCode) return Promise.resolve();
      return fetchJson(routeBuilderUrl("deleteRoute", { routeCode: routeCode }))
        .then(function (payload) {
          if (!payload || payload.SUCCESS === false) {
            throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to delete route.");
          }
          if (currentRouteCode === routeCode) currentRouteCode = "";
          return load();
        })
        .catch(function (err) {
          setState("error", (err && err.message) ? err.message : "Unable to delete route.");
        });
    }

    function requestBuildFloatPlans(routeCode, rebuild) {
      if (!routeCode) return Promise.resolve({ SUCCESS: false, MESSAGE: "routeCode is required." });
      return fetchJson(routeBuilderUrl("buildFloatPlansFromRoute"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({
          routeCode: routeCode,
          mode: "DAILY",
          rebuild: rebuild ? 1 : 0
        })
      });
    }

    function requestEnsureFollowerPage(routeCode, routeInstanceId) {
      var body = { routeCode: routeCode };
      var rid = parseInt(routeInstanceId, 10);
      if (Number.isFinite(rid) && rid > 0) {
        body.routeInstanceId = rid;
      }
      return fetchJson(voyageUrl("ownerEnsureStream"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(body)
      });
    }

    function payloadSuccess(payload) {
      if (!payload) return false;
      if (payload.ok === true || payload.success === true || payload.SUCCESS === true) return true;
      return false;
    }

    function payloadCode(payload) {
      if (!payload) return "";
      if (payload.code !== undefined && payload.code !== null && payload.code !== "") return String(payload.code).toUpperCase();
      if (payload.CODE !== undefined && payload.CODE !== null && payload.CODE !== "") return String(payload.CODE).toUpperCase();
      if (payload.ERROR && payload.ERROR.CODE) return String(payload.ERROR.CODE).toUpperCase();
      return "";
    }

    function payloadMessage(payload, fallbackText) {
      if (payload && payload.message !== undefined && payload.message !== null && payload.message !== "") {
        return String(payload.message);
      }
      if (payload && payload.MESSAGE !== undefined && payload.MESSAGE !== null && payload.MESSAGE !== "") {
        return String(payload.MESSAGE);
      }
      if (payload && payload.ERROR && payload.ERROR.MESSAGE) {
        return String(payload.ERROR.MESSAGE);
      }
      return fallbackText || "Request failed.";
    }

    function payloadData(payload) {
      if (!payload || typeof payload !== "object") return {};
      if (payload.data && typeof payload.data === "object") return payload.data;
      if (payload.DATA && typeof payload.DATA === "object") return payload.DATA;
      return payload;
    }

    function showActionError(actionName, routeCode, payloadOrError, fallbackText) {
      var routeLabel = routeCode || "unknown route";
      var message = fallbackText || "Request failed.";
      if (payloadOrError) {
        if (payloadOrError.message) {
          message = String(payloadOrError.message);
        } else if (typeof payloadOrError === "object") {
          message = payloadMessage(payloadOrError, fallbackText || message);
        }
      }
      var fullMessage = actionName + " failed for route " + routeLabel + ": " + message;
      if (utils && typeof utils.showDashboardAlert === "function") {
        utils.showDashboardAlert(fullMessage, "danger");
        return;
      }
      if (utils && typeof utils.showAlertModal === "function") {
        utils.showAlertModal(fullMessage);
        return;
      }
      setState("error", fullMessage);
    }

    function copyFollowerUrl(followUrl) {
      if (!followUrl) return Promise.resolve(false);
      if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
        return navigator.clipboard.writeText(followUrl)
          .then(function () { return true; })
          .catch(function () { return false; });
      }
      return Promise.resolve(false);
    }

    function openFollowerUrlWithCopy(followUrl) {
      if (!followUrl) return Promise.resolve(false);
      window.open(followUrl, "_blank", "noopener");
      return copyFollowerUrl(followUrl)
        .then(function (copied) {
          if (copied) return true;
          window.prompt("Copy follower page link:", followUrl);
          return false;
        });
    }

    function ensureFollowerPage(routeCode, routeInstanceId, triggerButton) {
      var originalText = "";
      if (!routeCode) return Promise.resolve();
      if (triggerButton) {
        originalText = triggerButton.textContent;
        triggerButton.disabled = true;
        triggerButton.textContent = "Creating...";
      }

      return requestEnsureFollowerPage(routeCode, routeInstanceId)
        .then(function (ensurePayload) {
          if (payloadSuccess(ensurePayload)) {
            return ensurePayload;
          }

          var code = payloadCode(ensurePayload);
          if (code.indexOf("NO_FLOATPLAN") === -1) {
            throw ensurePayload || new Error("Unable to prepare follower page.");
          }

          return requestBuildFloatPlans(routeCode, false)
            .then(function (buildPayload) {
              if (!buildPayload || buildPayload.SUCCESS === false) {
                throw buildPayload || new Error("Unable to build float plans from route.");
              }
              return requestEnsureFollowerPage(routeCode, routeInstanceId);
            });
        })
        .then(function (ensurePayload) {
          if (!payloadSuccess(ensurePayload)) {
            throw ensurePayload || new Error("Unable to prepare follower page.");
          }
          var data = payloadData(ensurePayload);
          var followUrl = data && data.follow && data.follow.url ? data.follow.url : "";
          if (!followUrl && data && data.follow && data.follow.path) {
            followUrl = window.location.origin + data.follow.path;
          }
          if (!followUrl) {
            throw new Error("Follower page URL is missing from ownerEnsureStream response.");
          }
          return openFollowerUrlWithCopy(followUrl)
            .then(function (copied) {
              if (utils && typeof utils.showDashboardAlert === "function") {
                utils.showDashboardAlert(
                  copied ? "Follower page ready. Link copied to clipboard." : "Follower page ready. Copy link dialog shown.",
                  "success"
                );
              }
            });
        })
        .catch(function (errOrPayload) {
          showActionError("Follower Page", routeCode, errOrPayload, "Unable to create follower page.");
        })
        .finally(function () {
          if (triggerButton) {
            triggerButton.disabled = false;
            triggerButton.textContent = originalText || "Follower Page";
          }
        });
    }

    function buildFloatPlans(routeCode, triggerButton) {
      if (!routeCode) return Promise.resolve();
      var originalText = "";
      if (triggerButton) {
        originalText = triggerButton.textContent;
        triggerButton.disabled = true;
        triggerButton.textContent = "Building...";
      }

      return requestBuildFloatPlans(routeCode, false)
        .then(function (payload) {
          if (!payload || payload.SUCCESS === true) {
            return payload;
          }

          var errorCode = payload && payload.ERROR && payload.ERROR.CODE
            ? String(payload.ERROR.CODE).toUpperCase()
            : "";

          if (errorCode === "FLOATPLANS_ALREADY_EXIST") {
            var ask = (utils && typeof utils.showConfirmModal === "function")
              ? utils.showConfirmModal("Draft float plans already exist for this route. Rebuild and replace them?")
              : Promise.resolve(window.confirm("Draft float plans already exist for this route. Rebuild and replace them?"));
            return ask.then(function (confirmed) {
              if (!confirmed) return { CANCELLED: true };
              return requestBuildFloatPlans(routeCode, true);
            });
          }
          return payload;
        })
        .then(function (payload) {
          if (!payload || payload.CANCELLED) return;
          if (!payload || payload.SUCCESS === false) {
            throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to build float plans from route.");
          }
          var createdCount = Number.isFinite(parseInt(payload.CREATED_COUNT, 10))
            ? parseInt(payload.CREATED_COUNT, 10)
            : 0;
          if (utils && typeof utils.showDashboardAlert === "function") {
            utils.showDashboardAlert(
              "Created " + createdCount + " draft float plan" + (createdCount === 1 ? "" : "s") + " from route.",
              "success"
            );
          }
          if (document && typeof window.CustomEvent === "function") {
            document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated", {
              detail: {
                routeCode: routeCode,
                routeInstanceId: payload.ROUTE_INSTANCE_ID || 0,
                createdCount: createdCount
              }
            }));
          }
        })
        .catch(function (err) {
          var msg = (err && err.message) ? err.message : "Unable to build float plans from route.";
          if (utils && typeof utils.showAlertModal === "function") {
            utils.showAlertModal(msg);
          } else {
            setState("error", msg);
          }
        })
        .finally(function () {
          if (triggerButton) {
            triggerButton.disabled = false;
            triggerButton.textContent = originalText || "Build Float Plans";
          }
        });
    }

    function fetchJson(url, options) {
      var fetchOptions = options || {};
      if (!Object.prototype.hasOwnProperty.call(fetchOptions, "credentials")) {
        fetchOptions.credentials = "same-origin";
      }
      return fetch(url, fetchOptions)
        .then(function (response) {
          if (response.status === 401 || response.status === 403) {
            var authErr = new Error("Unauthorized");
            authErr.code = "UNAUTHORIZED";
            throw authErr;
          }
          return response.json();
        });
    }

    function load(routeCodeOverride) {
      requestSeq += 1;
      var currentSeq = requestSeq;
      setState("loading");

      return fetchJson(routeBuilderUrl("listUserRoutes"))
        .then(function (routesPayload) {
          if (currentSeq !== requestSeq) return null;
          if (!routesPayload || routesPayload.SUCCESS === false) {
            if (routesPayload && routesPayload.AUTH === false) {
              setState("unauthorized");
              return null;
            }
            throw new Error((routesPayload && routesPayload.MESSAGE) ? routesPayload.MESSAGE : "Unable to load routes.");
          }
          var routes = Array.isArray(routesPayload.ROUTES) ? routesPayload.ROUTES : [];
          if (!routes.length) {
            renderEmptyRoutes();
            return null;
          }
          var selected = routeCodeOverride || currentRouteCode || routesPayload.ACTIVE_ROUTE_CODE || routes[0].SHORT_CODE;
          var hasSelected = routes.some(function (route) {
            return route && route.SHORT_CODE === selected;
          });
          if (!hasSelected) selected = routes[0].SHORT_CODE;
          currentRouteCode = selected;
          renderRouteList(routes, selected);
          return fetchJson(routeUrl(selected));
        })
        .then(function (payload) {
          if (currentSeq !== requestSeq || !payload) return;
          if (!payload || payload.SUCCESS === false) {
            if (payload && payload.AUTH === false) {
              setState("unauthorized");
              return;
            }
            throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load expedition timeline.");
          }
          renderSummary(payload);
          renderTimeline(payload);
          setState("ready");
        })
        .catch(function (err) {
          if (currentSeq !== requestSeq) return;
          if (err && err.code === "UNAUTHORIZED") {
            setState("unauthorized");
            return;
          }
          setState("error", (err && err.message) ? err.message : "Unable to load expedition timeline.");
        });
    }

    function init() {
      panel = document.getElementById("expeditionTimelinePanel");
      if (!panel) return;
      summaryEl = document.getElementById("expeditionTimelineSummary");
      subtitleEl = document.getElementById("expeditionTimelineSubtitle");
      loadingEl = document.getElementById("expeditionTimelineLoading");
      unauthorizedEl = document.getElementById("expeditionTimelineUnauthorized");
      errorEl = document.getElementById("expeditionTimelineError");
      errorTextEl = document.getElementById("expeditionTimelineErrorText");
      bodyEl = document.getElementById("expeditionTimelineBody");
      routeListEl = document.getElementById("expeditionRouteList");
      routeEmptyEl = document.getElementById("expeditionRouteEmpty");
      accordionEl = document.getElementById("expeditionTimelineAccordion");
      retryBtn = document.getElementById("expeditionTimelineRetry");

      if (retryBtn) {
        retryBtn.addEventListener("click", function () {
          load();
        });
      }
      if (routeListEl) {
        routeListEl.addEventListener("click", function (event) {
          var target = event.target;
          if (!target) return;
          var card = target.closest(".expedition-route-card");
          if (!card) return;
          var routeCode = card.getAttribute("data-route-code");
          if (!routeCode) return;
          if (target.classList.contains("js-expedition-view-edit")) {
            setActiveRoute(routeCode);
            openEditor(routeCode);
            return;
          }
          if (target.classList.contains("js-expedition-build-floatplans")) {
            buildFloatPlans(routeCode, target);
            return;
          }
          if (target.classList.contains("js-expedition-follower-page")) {
            var routeInstanceId = parseInt(card.getAttribute("data-route-instance-id") || "0", 10);
            if (!Number.isFinite(routeInstanceId)) routeInstanceId = 0;
            ensureFollowerPage(routeCode, routeInstanceId, target);
            return;
          }
          if (target.classList.contains("js-expedition-delete")) {
            var confirmDelete = function () {
              deleteRoute(routeCode);
            };
            if (utils && typeof utils.showConfirmModal === "function") {
              utils.showConfirmModal("Delete this route?")
                .then(function (confirmed) {
                  if (!confirmed) return;
                  confirmDelete();
                });
            } else {
              if (!window.confirm("Delete this route?")) return;
              confirmDelete();
            }
            return;
          }
        });
      }
      document.addEventListener("fpw:routes-updated", function (event) {
        var routeCode = event && event.detail ? event.detail.routeCode : "";
        load(routeCode);
      });
      load();
    }

    return {
      init: init,
      load: load
    };
  })();

  window.FPW.DashboardModules = modules;

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
    bindQuickActions();
    bindWeatherPreviewActions();
    bindNextStepsActions();
    bindRouteStatusActions();
    renderRouteStatusPanel();
    refreshMissionSummary();
    renderMonitoringSummary();
    renderRecommendedNextSteps();
    updateSetupIntroMetrics();

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
    if (modules.expeditionTimeline && modules.expeditionTimeline.init) {
      modules.expeditionTimeline.init();
    }
    if (modules.routeBuilder && modules.routeBuilder.init) {
      modules.routeBuilder.init();
    }

    document.addEventListener("fpw:floatplans-updated", function () {
      refreshDerivedSignalsFromState();
    });

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
        var homePortZip = "";
        if (utils.resolveHomePortZip) {
          homePortZip = utils.resolveHomePortZip(data.USER);
        }
        initWeatherPanel(homePortZip, state.homePortLatLng || null);

        var readyEvent = null;
        if (typeof Event === "function") {
          readyEvent = new Event("fpw:dashboard:user-ready");
        } else {
          readyEvent = document.createEvent("Event");
          readyEvent.initEvent("fpw:dashboard:user-ready", true, true);
        }
        document.dispatchEvent(readyEvent);
        startDerivedSignalsPolling();
        startMonitoringPolling();
        window.setTimeout(function () {
          refreshDerivedSignalsFromState();
        }, 1200);
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

  }

  window.FPW_DASHBOARD_VERSION = "20260211y";
  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
