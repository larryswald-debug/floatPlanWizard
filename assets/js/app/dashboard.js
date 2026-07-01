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
  var tideSelectedRange = "today";
  var tideRangeControlsBound = false;
  var weatherRequestSeq = 0;
  var weatherQuickAbortController = null;
  var weatherHydrationAbortController = null;
  var weatherScanConsoleState = {
    active: false,
    failed: false,
    startTime: 0,
    elapsedTimer: 0,
    stepTimer: 0,
    slowTimer: 0,
    extendedTimer: 0,
    stepIndex: 0,
    lastAnnouncedStep: -1
  };
  var WEATHER_SCAN_STEP_LABELS = [
    "Resolving weather location…",
    "Checking cached marine conditions…",
    "Requesting latest forecast…",
    "Reading coastal forecast and marine conditions…",
    "Checking advisories…",
    "Loading wind, wave, and tide context…",
    "Preparing your boating weather briefing…"
  ];
  var WEATHER_SCAN_SLOW_MESSAGE = "Fresh NOAA/NWS marine data can take a few seconds.";
  var WEATHER_SCAN_EXTENDED_MESSAGE = "Still working. Your briefing will appear automatically when the weather data returns.";
  var WEATHER_SCAN_READY_MESSAGE = "Weather briefing ready.";
  var WEATHER_SCAN_ERROR_MESSAGE = "Weather data did not respond. Please try again, and always check official weather sources before departure.";
  var WEATHER_SCAN_HYDRATION_MESSAGE = "Updating detailed marine context…";
  var WEATHER_HYDRATION_TIMEOUT_MS = 25000;
  var AUTO_LOAD_HOME_PORT_WEATHER = true;
  var weatherBriefingState = { data: {}, payload: null, location: null };
  var weatherMapInstance = null;
  var weatherMapHasCentered = false;
  var weatherMapOverlayController = null;
  var weatherMapModalControlsBound = false;
  var weatherMapModalPreviousFocus = null;
  var seaStateLastWaveHeight = null;
  var monitoringPollTimer = 0;
  var derivedSignalsPollTimer = 0;
  var dashboardSignals = {
    routes: {
      total: 0
    },
    routeName: "No Active Trip",
    routeSummary: "Your routes, float plans, and trip setup are ready.",
    routeProgressPct: 0,
    activeRoute: {
      name: "",
      isActive: false
    },
    floatPlans: {
      active: 0,
      draft: 0,
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
    activeTrip: "Active Trip",
    routeProgress: "Trip Progress",
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
      || normalized === "no active trip"
      || normalized === "no active route"
      || normalized === "route"
      || normalized === "not available";
  }

  function isMissionSummaryPlaceholder(text) {
    var normalized = normalizeMissionText(text, "", 140).toLowerCase();
    if (!normalized) return true;
    return normalized === "create your first route."
      || normalized === "create your first route"
      || normalized === "no active trip is available."
      || normalized === "no active trip is available"
      || normalized === "activate a monitored float plan to begin monitoring."
      || normalized === "activate a monitored float plan to begin monitoring"
      || normalized === "no active trip"
      || normalized === "waiting for route data"
      || normalized === "no active route"
      || normalized === "no routes yet"
      || normalized === "no data";
  }

  function collectMissionSummaryData() {
    return {
      user: state.currentUser || null,
      vessels: (state.vesselState && Array.isArray(state.vesselState.all)) ? state.vesselState.all : [],
      activeRoute: dashboardSignals.activeRoute || { name: "", isActive: false }
    };
  }

  function getPlanningNested(obj, path, fallback) {
    return utils.getNested ? utils.getNested(obj, path, fallback) : fallback;
  }

  function getPlanningHomePort(user) {
    var profile = getPlanningNested(user, ["PROFILE"], null) || getPlanningNested(user, ["profile"], null) || {};
    return getPlanningNested(profile, ["HOMEPORT"], null)
      || getPlanningNested(profile, ["homePort"], null)
      || getPlanningNested(user, ["HOMEPORT"], null)
      || getPlanningNested(user, ["homePort"], null)
      || {};
  }

  function pickPlanningValue(source, keys) {
    return utils.pick ? utils.pick(source, keys, "") : "";
  }

  function normalizePlanningValue(value, maxLength) {
    return normalizeMissionText(value, "", maxLength || 0);
  }

  function formatPlanningNumber(value) {
    var parsed = parseFloat(value);
    if (!Number.isFinite(parsed)) {
      return "";
    }
    return parsed.toFixed(1).replace(/\.0$/, "");
  }

  function buildHomePortPlanningContext(user) {
    var homePort = getPlanningHomePort(user);
    var address = normalizePlanningValue(pickPlanningValue(homePort, ["address", "ADDRESS"]), 42);
    var city = normalizePlanningValue(pickPlanningValue(homePort, ["city", "CITY"]), 28);
    var stateValue = normalizePlanningValue(pickPlanningValue(homePort, ["state", "STATE"]), 12);
    var cityState = "";
    var value = "";

    if (city && stateValue) {
      cityState = city + ", " + stateValue;
    } else {
      cityState = city || stateValue;
    }

    value = address || cityState || "No Home Port";

    return {
      value: value,
      meta: address && cityState ? cityState : "",
      hasMeta: !!(address && cityState)
    };
  }

  function isPlanningDefaultVessel(vessel) {
    var raw = pickPlanningValue(vessel, ["ISDEFAULTVESSEL", "isDefaultVessel"]);
    return String(raw) === "1" || String(raw).toLowerCase() === "true";
  }

  function buildDefaultVesselPlanningContext(vessels) {
    var vesselList = Array.isArray(vessels) ? vessels : [];
    var defaultVessel = null;
    var i = 0;
    var name = "";
    var cruiseSpeed = "";
    var fuelBurn = "";
    var meta = [];

    for (i = 0; i < vesselList.length; i += 1) {
      if (isPlanningDefaultVessel(vesselList[i])) {
        defaultVessel = vesselList[i];
        break;
      }
    }

    if (!defaultVessel) {
      return { value: "Not set", meta: "", hasMeta: false };
    }

    name = normalizePlanningValue(pickPlanningValue(defaultVessel, ["VESSELNAME", "vesselName", "name", "NAME"]), 42) || "Not set";
    cruiseSpeed = formatPlanningNumber(pickPlanningValue(defaultVessel, ["MOST_EFFICIENT_SPEED_KN", "MOST_EFFICIENT_SPEED", "mostEfficientSpeed"]));
    fuelBurn = formatPlanningNumber(pickPlanningValue(defaultVessel, ["GPH_AT_MOST_EFFICIENT_SPEED", "GALLONS_PER_HOUR", "gallonsPerHour"]));

    if (cruiseSpeed) {
      meta.push("Cruise: " + cruiseSpeed + " kn");
    }
    if (fuelBurn) {
      meta.push("Fuel Burn: " + fuelBurn + " GPH");
    }

    return {
      value: name,
      meta: meta.join("   "),
      hasMeta: meta.length > 0
    };
  }

  function buildActiveRoutePlanningContext(activeRoute) {
    var route = activeRoute || {};
    var isActive = route.isActive === true;
    var routeName = normalizePlanningValue(route.name, 56);

    if (!isActive || !routeName) {
      return { value: "0", meta: "", isActive: false };
    }

    return { value: routeName, meta: "Active", isActive: true };
  }

  function buildMissionSummaryModel(source, recomputedAt) {
    var payload = source || {};
    var summaryDate = (recomputedAt && !Number.isNaN(recomputedAt.getTime()))
      ? recomputedAt
      : (missionSummaryState.lastRecomputedAt || new Date());

    return {
      updatedAtLabel: formatMissionSummaryUpdatedAt(summaryDate),
      context: {
        homePort: buildHomePortPlanningContext(payload.user),
        defaultVessel: buildDefaultVesselPlanningContext(payload.vessels),
        activeRoute: buildActiveRoutePlanningContext(payload.activeRoute)
      }
    };
  }

  function updateSetupIntroMetrics() {
    setText("setupMetricVessels", dashboardSignals.setup.vessels);
    setText("setupMetricContacts", dashboardSignals.setup.contacts);
    setText("setupMetricPassengers", dashboardSignals.setup.passengers);
    setText("setupMetricOperators", dashboardSignals.setup.operators);
    setText("setupMetricWaypoints", dashboardSignals.setup.waypoints);
  }

  function renderRouteStatusPanel() {
    var pct = parseRouteProgressPct(dashboardSignals.routeProgressPct);
    var progressBar = document.getElementById("routeStatusProgressBar");
    setText("routeStatusName", dashboardSignals.routeName || "No Active Trip");
    setText("routeStatusMeta", dashboardSignals.routeSummary || "Your routes, float plans, and trip setup are ready.");
    setText("routeStatusProgressLabel", Math.round(pct) + "% complete");
    if (progressBar) {
      progressBar.style.width = pct + "%";
    }
  }

  function renderPlanningContextText(valueId, metaId, data, valueFallback) {
    var metaEl = document.getElementById(metaId);
    var item = data || {};
    setText(valueId, normalizeMissionText(item.value, valueFallback || "", 64));
    if (!metaEl) return;
    metaEl.textContent = normalizeMissionText(item.meta, "", 96);
    metaEl.classList.toggle("d-none", !(item.hasMeta || item.isActive));
  }

  function renderMissionSummary(model) {
    var summaryModel = model && model.context ? model : buildMissionSummaryModel(collectMissionSummaryData(), missionSummaryState.lastRecomputedAt || new Date());
    var context = summaryModel.context || {};

    renderPlanningContextText("planningHomePortValue", "planningHomePortMeta", context.homePort, "No Home Port");
    renderPlanningContextText("planningDefaultVesselValue", "planningDefaultVesselMeta", context.defaultVessel, "Not set");
    renderPlanningContextText("planningActiveRouteValue", "planningActiveRouteMeta", context.activeRoute, "0");
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

  function openWeatherPanelFromDashboard() {
    window.location.href = BASE_PATH + "/app/weather.cfm";
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
    if (action === "create-basic-float-plan") {
      if (modules.basicFloatPlan && typeof modules.basicFloatPlan.open === "function") {
        modules.basicFloatPlan.open();
      } else {
        scrollToPanel("#expeditionTimelinePanel");
      }
      return;
    }
    if (action === "generate-route") {
      if (!triggerExistingButton("openRouteBuilderBtn")) {
        scrollToPanel("#expeditionTimelinePanel");
      }
      return;
    }
    if (action === "new-float-plan") {
      scrollToPanel("#expeditionTimelinePanel");
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
      if (modules.basicFloatPlan && typeof modules.basicFloatPlan.isBasicMode === "function" && modules.basicFloatPlan.isBasicMode()) {
        scrollToPanel("#waypointsPanel");
        if (utils.showDashboardAlert) {
          utils.showDashboardAlert("Basic float plans use the destination field for one-time trip stops. Upgrade to Premium to save reusable waypoints.", "warning");
        }
        return;
      }
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
      scrollToPanel("#expeditionTimelinePanel");
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
      var draftBtn = event.target && event.target.closest ? event.target.closest("[data-current-draft-action]") : null;
      if (draftBtn) {
        if (event && typeof event.preventDefault === "function") {
          event.preventDefault();
        }
        triggerCurrentDraftViewSendAction();
        return;
      }
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
    bindPanelQuickActions("missionSummaryPanel");
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

  function getSetupCount(key) {
    var value = dashboardSignals && dashboardSignals.setup ? parseInt(dashboardSignals.setup[key], 10) : 0;
    return Number.isFinite(value) && value > 0 ? value : 0;
  }

  function refreshRouteReadinessSetupLabels() {
    var vesselCount = getSetupCount("vessels");
    var contactCount = getSetupCount("contacts");
    Array.prototype.forEach.call(document.querySelectorAll('[data-fpw-route-setup-count="vessels"]'), function (el) {
      el.textContent = vesselCount > 0 ? formatNumber(vesselCount, 0) + " saved" : "setup pending";
      el.classList.toggle("fpw-text-success", vesselCount > 0);
      el.classList.toggle("fpw-text-muted", vesselCount <= 0);
    });
    Array.prototype.forEach.call(document.querySelectorAll('[data-fpw-route-setup-count="contacts"]'), function (el) {
      el.textContent = formatNumber(contactCount, 0) + " saved";
      el.classList.toggle("fpw-text-success", contactCount > 0);
      el.classList.toggle("fpw-text-muted", contactCount <= 0);
    });
  }

  function refreshDerivedSignalsFromState() {
    var plans = (state.floatPlanState && Array.isArray(state.floatPlanState.all)) ? state.floatPlanState.all : [];
    var routes = (state.routeState && Array.isArray(state.routeState.all)) ? state.routeState.all : [];
    var activePlans = 0;
    var draftPlans = 0;
    var i = 0;
    var status = "";

    dashboardSignals.routes.total = routes.length;
    for (i = 0; i < plans.length; i += 1) {
      status = normalizeStatusUpper(plans[i] && (plans[i].STATUS || plans[i].status));
      if (status === "ACTIVE" || status === "OPEN") {
        activePlans += 1;
      }
      if (status === "DRAFT") {
        draftPlans += 1;
      }
    }
    if (draftPlans === 0 && getCurrentDraftGroupForDisplay()) {
      draftPlans = 1;
    }
    dashboardSignals.floatPlans.active = activePlans;
    dashboardSignals.floatPlans.draft = draftPlans;
    dashboardSignals.floatPlans.total = plans.length;

    dashboardSignals.setup.vessels = (state.vesselState && Array.isArray(state.vesselState.all)) ? state.vesselState.all.length : 0;
    dashboardSignals.setup.contacts = (state.contactState && Array.isArray(state.contactState.all)) ? state.contactState.all.length : 0;
    dashboardSignals.setup.passengers = (state.passengerState && Array.isArray(state.passengerState.all)) ? state.passengerState.all.length : 0;
    dashboardSignals.setup.operators = (state.operatorState && Array.isArray(state.operatorState.all)) ? state.operatorState.all.length : 0;
    dashboardSignals.setup.waypoints = (state.waypointState && Array.isArray(state.waypointState.all)) ? state.waypointState.all.length : 0;

    updateSetupIntroMetrics();
    refreshRouteReadinessSetupLabels();
    refreshMissionSummary();
    renderRecommendedNextSteps();
    updateCurrentDraftActionButtons();
  }

  function loadMonitoringSummary() {
    var url = BASE_PATH + "/api/v1/floatplans.cfc?method=getMonitoredPlans&returnformat=json";
    dashboardSignals.monitoring.message = "Loading monitoring summary…";

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

        refreshMissionSummary();
        renderRecommendedNextSteps();
      })
      .catch(function (err) {
        dashboardSignals.monitoring.loaded = false;
        dashboardSignals.monitoring.message = (err && err.message) ? err.message : "Monitoring summary unavailable.";
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
    dashboardSignals.routeName = routeName || "No Active Trip";
    dashboardSignals.routeSummary = summaryText || "Your routes, float plans, and trip setup are ready.";
    dashboardSignals.routeProgressPct = parseRouteProgressPct(progressPct);
    renderRouteStatusPanel();
    refreshMissionSummary();
    renderRecommendedNextSteps();
  }

  function normalizeDashboardPlanId(value) {
    var planId = parseInt(value, 10);
    if (!Number.isFinite(planId) || planId <= 0) {
      return 0;
    }
    return planId;
  }

  function getCurrentDraftGroupForDisplay() {
    var group = state.currentRouteGroup && typeof state.currentRouteGroup === "object"
      ? state.currentRouteGroup
      : null;
    var planId = 0;
    var currentState = "";
    var status = "";
    var isDraft = false;
    if (!group || !group.HAS_CURRENT_GROUP) {
      return null;
    }
    planId = normalizeDashboardPlanId(group.FLOATPLAN_ID !== undefined ? group.FLOATPLAN_ID : group.FLOATPLANID);
    if (planId <= 0) {
      return null;
    }
    currentState = String(group.CURRENT_STATE || "").trim().toUpperCase();
    status = String(group.STATUS || "").trim().toUpperCase();
    isDraft = group.IS_DRAFT === true || currentState === "DRAFT" || status === "DRAFT";
    if (!isDraft) {
      return null;
    }
    return {
      planId: planId,
      routeName: normalizeMissionText(group.ROUTE_NAME || group.ROUTENAME || group.NAME, "this route", 72),
      floatPlanName: normalizeMissionText(group.FLOATPLAN_NAME || group.FLOATPLANNAME, "Draft float plan", 96)
    };
  }

  function findCurrentDraftViewSendButton() {
    var draft = getCurrentDraftGroupForDisplay();
    var selector = "";
    var button = null;
    if (!draft || draft.planId <= 0) {
      return null;
    }
    selector = '.expedition-route-current-group[data-plan-id="' + draft.planId + '"] .js-expedition-plan-view';
    button = document.querySelector(selector);
    if (button) {
      return button;
    }
    return document.querySelector('.expedition-route-card[data-current-group-state="DRAFT"] .js-expedition-plan-view');
  }

  function setDraftActionButtonState(button, hasAction) {
    if (!button) return;
    button.disabled = !hasAction;
    button.classList.toggle("d-none", !hasAction);
    button.setAttribute("aria-hidden", hasAction ? "false" : "true");
  }

  function updateCurrentDraftActionButtons() {
    var hasDraftAction = !!findCurrentDraftViewSendButton();
    setDraftActionButtonState(document.getElementById("dashboardHeroDraftPlanBtn"), hasDraftAction);
    setDraftActionButtonState(document.getElementById("dashboardNextStepDraftPlanBtn"), hasDraftAction);
  }

  function triggerCurrentDraftViewSendAction() {
    var existingButton = findCurrentDraftViewSendButton();
    if (!existingButton || typeof existingButton.click !== "function") {
      updateCurrentDraftActionButtons();
      return false;
    }
    existingButton.click();
    return true;
  }

  function renderRecommendedNextSteps() {
    var listEl = document.getElementById("nextStepsList");
    var emptyEl = document.getElementById("nextStepsEmpty");
    var steps = [];
    var draftGroup = getCurrentDraftGroupForDisplay();
    var markup = "";

    if (!listEl || !emptyEl) return;

    if (draftGroup) {
      steps.push({
        title: "You have a draft float plan attached to " + draftGroup.routeName + ".",
        meta: "Review and send it to activate monitoring for this route.",
        action: "draft-view-send",
        actionLabel: "View & Send Float Plan"
      });
    } else if (state.isBasicMember) {
      steps.push({
        title: "Create a Basic Float Plan",
        meta: "Basic members can send one-day float plans with up to 2 saved waypoints.",
        action: "create-basic-float-plan",
        actionLabel: "Create Basic Float Plan"
      });
    } else if ((dashboardSignals.floatPlans.total || 0) === 0) {
      steps.push({
        title: "Activate a route",
        meta: "No current draft or active route/float-plan group exists.",
        action: "open-expedition",
        actionLabel: "Open Routes"
      });
    }

    if (dashboardSignals.monitoring.loaded && (dashboardSignals.monitoring.overdue || 0) > 0) {
      steps.push({
        title: "Review overdue monitoring plans",
        meta: dashboardSignals.monitoring.overdue + " monitored plan(s) are currently overdue.",
        action: "open-expedition",
        actionLabel: "Open Routes"
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
      updateCurrentDraftActionButtons();
      return;
    }

    toggleHidden(emptyEl, true);
    markup = steps.slice(0, 1).map(function (step) {
      var actionMarkup = step.action === "draft-view-send"
        ? '<button type="button" class="btn-primary" id="dashboardNextStepDraftPlanBtn" data-current-draft-action="view-send">' + escapeHtml(step.actionLabel) + '</button>'
        : '<button type="button" class="btn-primary" data-quick-action="' + escapeHtml(step.action) + '">' + escapeHtml(step.actionLabel) + '</button>';
      return ''
        + '<article class="next-step-item">'
        + '  <div class="next-step-main">'
        + '    <p class="next-step-title">' + escapeHtml(step.title) + '</p>'
        + '    <p class="next-step-meta">' + escapeHtml(step.meta) + '</p>'
        + '  </div>'
        + '  <div class="next-step-actions">' + actionMarkup + '</div>'
        + '</article>';
    }).join("");
    listEl.innerHTML = markup;
    updateCurrentDraftActionButtons();
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

  function getWeatherScanConsoleEls() {
    return {
      root: document.getElementById("weatherLoading"),
      location: document.getElementById("weatherScanLocation"),
      elapsed: document.getElementById("weatherScanElapsed"),
      step: document.getElementById("weatherScanStep"),
      liveStatus: document.getElementById("weatherScanLiveStatus"),
      slowMessage: document.getElementById("weatherScanSlowMessage"),
      extendedMessage: document.getElementById("weatherScanExtendedMessage"),
      hydrationBadge: document.getElementById("weatherMarineHydrationBadge"),
      checklistItems: document.querySelectorAll("[data-weather-scan-step]")
    };
  }

  function clearWeatherScanConsoleTimers() {
    if (weatherScanConsoleState.elapsedTimer) {
      window.clearInterval(weatherScanConsoleState.elapsedTimer);
      weatherScanConsoleState.elapsedTimer = 0;
    }
    if (weatherScanConsoleState.stepTimer) {
      window.clearInterval(weatherScanConsoleState.stepTimer);
      weatherScanConsoleState.stepTimer = 0;
    }
    if (weatherScanConsoleState.slowTimer) {
      window.clearTimeout(weatherScanConsoleState.slowTimer);
      weatherScanConsoleState.slowTimer = 0;
    }
    if (weatherScanConsoleState.extendedTimer) {
      window.clearTimeout(weatherScanConsoleState.extendedTimer);
      weatherScanConsoleState.extendedTimer = 0;
    }
  }

  function formatWeatherScanElapsed() {
    if (!weatherScanConsoleState.startTime) return "0s";
    return Math.max(0, Math.floor((Date.now() - weatherScanConsoleState.startTime) / 1000)) + "s";
  }

  function updateWeatherScanConsoleElapsed() {
    var els = getWeatherScanConsoleEls();
    if (els.elapsed) {
      els.elapsed.textContent = formatWeatherScanElapsed();
    }
  }

  function weatherScanLocationLabel(location) {
    if (location && String(location.mode || "zip").toLowerCase() === "zip" && location.zip) {
      return "Checking ZIP " + location.zip;
    }
    if (location && String(location.mode || "").toLowerCase() === "coords") {
      return "Checking selected coordinates";
    }
    return "Checking your selected weather location";
  }

  function setWeatherScanConsoleStep(stepIndex, announce) {
    var els = getWeatherScanConsoleEls();
    var maxIndex = WEATHER_SCAN_STEP_LABELS.length - 1;
    var boundedIndex = Math.max(0, Math.min(maxIndex, parseInt(stepIndex, 10) || 0));
    var label = WEATHER_SCAN_STEP_LABELS[boundedIndex] || WEATHER_SCAN_STEP_LABELS[0];

    weatherScanConsoleState.stepIndex = boundedIndex;
    if (els.step) {
      els.step.textContent = label;
    }
    if (els.liveStatus && announce && weatherScanConsoleState.lastAnnouncedStep !== boundedIndex) {
      els.liveStatus.textContent = label;
      weatherScanConsoleState.lastAnnouncedStep = boundedIndex;
    }
    Array.prototype.forEach.call(els.checklistItems || [], function (item) {
      var itemIndex = parseInt(item.getAttribute("data-weather-scan-step"), 10);
      item.classList.toggle("is-done", Number.isFinite(itemIndex) && itemIndex < boundedIndex);
      item.classList.toggle("is-active", Number.isFinite(itemIndex) && itemIndex === boundedIndex);
    });
  }

  function showWeatherScanConsoleMessage(el, message) {
    if (!el) return;
    el.textContent = message;
    toggleHidden(el, false);
  }

  function markWeatherScanConsoleSlow() {
    if (!weatherScanConsoleState.active) return;
    var els = getWeatherScanConsoleEls();
    showWeatherScanConsoleMessage(els.slowMessage, WEATHER_SCAN_SLOW_MESSAGE);
    if (els.liveStatus) {
      els.liveStatus.textContent = WEATHER_SCAN_SLOW_MESSAGE;
    }
  }

  function markWeatherScanConsoleExtendedWait() {
    if (!weatherScanConsoleState.active) return;
    var els = getWeatherScanConsoleEls();
    showWeatherScanConsoleMessage(els.extendedMessage, WEATHER_SCAN_EXTENDED_MESSAGE);
    if (els.liveStatus) {
      els.liveStatus.textContent = WEATHER_SCAN_EXTENDED_MESSAGE;
    }
  }

  function resetWeatherScanConsole() {
    var els = getWeatherScanConsoleEls();
    clearWeatherScanConsoleTimers();
    weatherScanConsoleState.active = false;
    weatherScanConsoleState.failed = false;
    weatherScanConsoleState.startTime = 0;
    weatherScanConsoleState.stepIndex = 0;
    weatherScanConsoleState.lastAnnouncedStep = -1;
    if (els.root) {
      els.root.classList.remove("is-error");
      toggleHidden(els.root, true);
    }
    if (els.slowMessage) toggleHidden(els.slowMessage, true);
    if (els.extendedMessage) toggleHidden(els.extendedMessage, true);
    setWeatherScanConsoleStep(0, false);
    updateWeatherScanConsoleElapsed();
  }

  function startWeatherScanConsole(location) {
    var els = getWeatherScanConsoleEls();
    if (!els.root) return;

    clearWeatherScanConsoleTimers();
    weatherScanConsoleState.active = true;
    weatherScanConsoleState.failed = false;
    weatherScanConsoleState.startTime = Date.now();
    weatherScanConsoleState.stepIndex = 0;
    weatherScanConsoleState.lastAnnouncedStep = -1;

    els.root.classList.remove("is-error");
    if (els.location) {
      els.location.textContent = weatherScanLocationLabel(location);
    }
    if (els.slowMessage) toggleHidden(els.slowMessage, true);
    if (els.extendedMessage) toggleHidden(els.extendedMessage, true);
    hideMarineHydrationBadge();
    toggleHidden(els.root, false);
    updateWeatherScanConsoleElapsed();
    setWeatherScanConsoleStep(0, true);

    weatherScanConsoleState.elapsedTimer = window.setInterval(updateWeatherScanConsoleElapsed, 1000);
    weatherScanConsoleState.stepTimer = window.setInterval(function () {
      if (!weatherScanConsoleState.active) return;
      setWeatherScanConsoleStep(weatherScanConsoleState.stepIndex + 1, true);
    }, 1800);
    weatherScanConsoleState.slowTimer = window.setTimeout(markWeatherScanConsoleSlow, 5000);
    weatherScanConsoleState.extendedTimer = window.setTimeout(markWeatherScanConsoleExtendedWait, 10000);
  }

  function completeWeatherScanConsole() {
    var els = getWeatherScanConsoleEls();
    clearWeatherScanConsoleTimers();
    weatherScanConsoleState.active = false;
    weatherScanConsoleState.failed = false;
    if (els.step) {
      els.step.textContent = WEATHER_SCAN_READY_MESSAGE;
    }
    if (els.liveStatus) {
      els.liveStatus.textContent = WEATHER_SCAN_READY_MESSAGE;
    }
    if (els.root) {
      els.root.classList.remove("is-error");
      toggleHidden(els.root, true);
    }
  }

  function failWeatherScanConsole(message) {
    var els = getWeatherScanConsoleEls();
    clearWeatherScanConsoleTimers();
    weatherScanConsoleState.active = false;
    weatherScanConsoleState.failed = true;
    if (els.step) {
      els.step.textContent = message || WEATHER_SCAN_ERROR_MESSAGE;
    }
    if (els.liveStatus) {
      els.liveStatus.textContent = message || WEATHER_SCAN_ERROR_MESSAGE;
    }
    if (els.root) {
      els.root.classList.add("is-error");
      toggleHidden(els.root, false);
    }
  }

  function showMarineHydrationBadge() {
    var els = getWeatherScanConsoleEls();
    if (!els.hydrationBadge) return;
    els.hydrationBadge.textContent = WEATHER_SCAN_HYDRATION_MESSAGE;
    toggleHidden(els.hydrationBadge, false);
  }

  function hideMarineHydrationBadge() {
    var els = getWeatherScanConsoleEls();
    if (!els.hydrationBadge) return;
    toggleHidden(els.hydrationBadge, true);
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

  function mergeWeatherBriefingData(nextData) {
    var next = nextData || {};
    var key = "";
    var meta = getWeatherMeta(next);
    var request = meta && (meta.REQUEST || meta.request) ? (meta.REQUEST || meta.request) : {};
    var isMarineOnly = String(request.marineOnly || request.MARINEONLY || "") === "1";
    weatherBriefingState.data = weatherBriefingState.data || {};

    function isEmptyWeatherValue(value) {
      if (value === undefined || value === null) return true;
      if (typeof value === "string") return value.trim() === "";
      if (Array.isArray(value)) return value.length === 0;
      if (typeof value === "object") {
        return Object.keys(value).every(function (childKey) {
          return isEmptyWeatherValue(value[childKey]);
        });
      }
      return false;
    }

    Object.keys(next).forEach(function (rawKey) {
      key = rawKey;
      if (next[key] === undefined || next[key] === null) return;
      if (isMarineOnly && /^(SUMMARY|FORECAST|ALERTS|MAP_LAYERS|surface|SURFACE|MARINE|marine|ZONE_FORECAST|zone_forecast|zoneForecast)$/.test(key) && isEmptyWeatherValue(next[key])) return;
      if (isMarineOnly && /^(META|meta)$/.test(key) && typeof next[key] === "object" && typeof weatherBriefingState.data[key] === "object") {
        var currentMeta = weatherBriefingState.data[key] || {};
        var nextMeta = next[key] || {};
        var mergedMeta = Object.assign({}, currentMeta, nextMeta);
        var currentSources = currentMeta.SOURCES || currentMeta.sources || {};
        var nextSources = nextMeta.SOURCES || nextMeta.sources || {};
        var currentAlertsSource = currentSources.ALERTS || currentSources.alerts || {};
        var nextAlertsSource = nextSources.ALERTS || nextSources.alerts || {};
        var currentCache = currentMeta.CACHE || currentMeta.cache || {};
        var nextCache = nextMeta.CACHE || nextMeta.cache || {};
        var currentAlertsCache = currentCache.ALERTS || currentCache.alerts || {};
        var nextAlertsCache = nextCache.ALERTS || nextCache.alerts || {};
        var nextAlertsCacheStatus = String(weatherPick(nextAlertsCache, ["status", "STATUS"], "") || "").toLowerCase();

        if (!isEmptyWeatherValue(currentSources) || !isEmptyWeatherValue(nextSources)) {
          mergedMeta.SOURCES = Object.assign({}, currentSources, nextSources);
          if (!isEmptyWeatherValue(currentAlertsSource) && isEmptyWeatherValue(nextAlertsSource)) {
            mergedMeta.SOURCES.ALERTS = currentAlertsSource;
          }
        }
        if (!isEmptyWeatherValue(currentCache) || !isEmptyWeatherValue(nextCache)) {
          mergedMeta.CACHE = Object.assign({}, currentCache, nextCache);
          if (!isEmptyWeatherValue(currentAlertsCache) && (isEmptyWeatherValue(nextAlertsCache) || nextAlertsCacheStatus === "unavailable")) {
            mergedMeta.CACHE.ALERTS = currentAlertsCache;
          }
        }
        weatherBriefingState.data[key] = mergedMeta;
        return;
      }
      weatherBriefingState.data[key] = next[key];
    });
    return weatherBriefingState.data;
  }

  function weatherValue(value, fallback) {
    var text = "";
    if (value !== undefined && value !== null) {
      text = String(value).replace(/\s+/g, " ").trim();
    }
    if (!text || text === "--" || text.toLowerCase() === "null" || text.toLowerCase() === "undefined") {
      return fallback !== undefined ? fallback : "—";
    }
    return text;
  }

  function weatherPick(obj, keys, fallback) {
    var source = obj || {};
    var i = 0;
    var key = "";
    for (i = 0; i < keys.length; i++) {
      key = keys[i];
      if (source[key] !== undefined && source[key] !== null && String(source[key]).trim() !== "") {
        return source[key];
      }
    }
    return fallback;
  }

  function weatherNumber(value) {
    var parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : NaN;
  }

  function formatWeatherNumber(value, decimals, fallback) {
    var n = weatherNumber(value);
    if (!Number.isFinite(n)) return fallback || "—";
    return n.toFixed(decimals);
  }

  function formatWeatherTime(value, fallback, options) {
    var raw = weatherValue(value, "");
    var parsed = null;
    if (!raw) return fallback || "—";
    parsed = new Date(raw);
    if (Number.isNaN(parsed.getTime()) && /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(raw)) {
      parsed = new Date(raw.replace(" ", "T"));
    }
    if (Number.isNaN(parsed.getTime())) return raw;
    try {
      return parsed.toLocaleString(undefined, options || { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZoneName: "short" });
    } catch (e) {
      return parsed.toLocaleString();
    }
  }

  function formatWeatherHour(value) {
    return formatWeatherTime(value, "—", { hour: "numeric" });
  }

  function setWeatherText(id, value, fallback) {
    var el = document.getElementById(id);
    if (!el) return;
    el.textContent = weatherValue(value, fallback || "—");
  }

  function setWeatherHtml(id, html) {
    var el = document.getElementById(id);
    if (!el) return;
    el.innerHTML = html || "";
  }

  function setWeatherLink(id, href, label) {
    var el = document.getElementById(id);
    var hasHref = weatherValue(href, "");
    if (!el) return;
    el.textContent = label || "View all NOAA marine alerts";
    if (hasHref) {
      el.setAttribute("href", hasHref);
      el.setAttribute("target", "_blank");
      el.setAttribute("rel", "noopener");
      el.classList.remove("d-none");
    } else {
      el.removeAttribute("target");
      el.removeAttribute("rel");
      el.setAttribute("href", "#");
      el.classList.remove("d-none");
    }
  }

  function getWeatherMeta(data) {
    return (data && (data.META || data.meta)) ? (data.META || data.meta) : {};
  }

  function getWeatherSurface(data) {
    return (data && (data.surface || data.SURFACE)) ? (data.surface || data.SURFACE) : {};
  }

  function getWeatherMarine(data) {
    return (data && (data.MARINE || data.marine)) ? (data.MARINE || data.marine) : {};
  }

  function getWeatherForecast(data) {
    var forecast = data && (data.FORECAST || data.forecast);
    return Array.isArray(forecast) ? forecast : [];
  }

  function getWeatherAlerts(data) {
    var alerts = data && (data.ALERTS || data.alerts);
    return Array.isArray(alerts) ? alerts : [];
  }

  function getWeatherAlertField(alert, keys, fallback) {
    return weatherValue(weatherPick(alert || {}, keys, ""), fallback !== undefined ? fallback : "");
  }

  function getWeatherAlertSourceMeta(data) {
    var meta = getWeatherMeta(data);
    var sources = meta && (meta.sources || meta.SOURCES) ? (meta.sources || meta.SOURCES) : {};
    return sources && (sources.alerts || sources.ALERTS) ? (sources.alerts || sources.ALERTS) : {};
  }

  function getWeatherAlertCacheMeta(data) {
    var meta = getWeatherMeta(data);
    var cache = meta && (meta.cache || meta.CACHE) ? (meta.cache || meta.CACHE) : {};
    return cache && (cache.alerts || cache.ALERTS) ? (cache.alerts || cache.ALERTS) : {};
  }

  function getWeatherAlertStatusCode(data) {
    var source = getWeatherAlertSourceMeta(data);
    var status = weatherPick(source, ["status", "STATUS", "httpStatus", "HTTPSTATUS"], "");
    var parsed = weatherNumber(status);
    return Number.isFinite(parsed) ? parsed : NaN;
  }

  function weatherAlertsUnavailable(data, payload) {
    var cacheMeta = getWeatherAlertCacheMeta(data);
    var cacheStatus = String(weatherPick(cacheMeta, ["status", "STATUS"], "") || "").toLowerCase();
    var statusCode = getWeatherAlertStatusCode(data);
    var hasData = !!(data && Object.keys(data).length);

    if (payload && payload.SUCCESS === false) return true;
    if (Number.isFinite(statusCode) && statusCode > 0 && (statusCode < 200 || statusCode >= 300)) return true;
    if (cacheStatus === "unavailable" || cacheStatus === "error" || cacheStatus === "failed") return true;
    return !hasData;
  }

  function weatherAlertRiskRank(alert) {
    var eventName = getWeatherAlertField(alert, ["event", "EVENT", "name", "NAME"], "").toLowerCase();
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
    var i = 0;

    for (i = 0; i < order.length; i++) {
      if (eventName.indexOf(order[i]) >= 0) return i;
    }
    return order.length + 1;
  }

  function weatherAlertSeverityRank(alert) {
    var severity = getWeatherAlertField(alert, ["severity", "SEVERITY"], "").toLowerCase();
    if (severity === "extreme") return 0;
    if (severity === "severe") return 1;
    if (severity === "moderate") return 2;
    if (severity === "minor") return 3;
    return 4;
  }

  function weatherAlertUrgencyRank(alert) {
    var urgency = getWeatherAlertField(alert, ["urgency", "URGENCY"], "").toLowerCase();
    if (urgency === "immediate") return 0;
    if (urgency === "expected") return 1;
    if (urgency === "future") return 2;
    if (urgency === "past") return 3;
    return 4;
  }

  function weatherAlertEffectiveTime(alert) {
    var raw = getWeatherAlertField(alert, ["effective", "EFFECTIVE", "onset", "ONSET", "sent", "SENT"], "");
    var parsed = raw ? Date.parse(raw) : NaN;
    return Number.isFinite(parsed) ? parsed : Number.MAX_SAFE_INTEGER;
  }

  function sortWeatherAlertsForDisplay(alerts) {
    return (Array.isArray(alerts) ? alerts.slice() : []).sort(function (a, b) {
      var rankDelta = weatherAlertRiskRank(a) - weatherAlertRiskRank(b);
      var severityDelta = weatherAlertSeverityRank(a) - weatherAlertSeverityRank(b);
      var urgencyDelta = weatherAlertUrgencyRank(a) - weatherAlertUrgencyRank(b);
      if (rankDelta) return rankDelta;
      if (severityDelta) return severityDelta;
      if (urgencyDelta) return urgencyDelta;
      return weatherAlertEffectiveTime(a) - weatherAlertEffectiveTime(b);
    });
  }

  function weatherAlertRiskClass(alert) {
    var rank = weatherAlertRiskRank(alert);
    var severity = weatherAlertSeverityRank(alert);
    if (rank <= 4 || severity <= 1) return "alert-risk-high";
    if (rank <= 8 || severity === 2) return "alert-risk-caution";
    return "alert-risk-low";
  }

  function formatWeatherAlertTime(value) {
    return formatWeatherTime(value, "—", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
  }

  function formatWeatherAlertShortTime(value) {
    return formatWeatherTime(value, "—", { hour: "numeric", minute: "2-digit" });
  }

  function getWeatherAlertExpiresValue(alert) {
    return getWeatherAlertField(alert, ["expires", "EXPIRES", "ends", "ENDS"], "");
  }

  function getWeatherAlertWeb(alert) {
    var web = getWeatherAlertField(alert, ["web", "WEB"], "");
    return /^https?:\/\//i.test(web) ? web : "";
  }

  function getWeatherAlertsCheckedAt(data) {
    var source = getWeatherAlertSourceMeta(data);
    var sourceCache = source && (source.cache_meta || source.CACHE_META) ? (source.cache_meta || source.CACHE_META) : {};
    var cache = getWeatherAlertCacheMeta(data);
    var raw = weatherPick(sourceCache, ["cached_at_utc", "CACHED_AT_UTC"], "");
    if (!raw) raw = weatherPick(cache, ["cached_at_utc", "CACHED_AT_UTC", "provider_time_utc", "PROVIDER_TIME_UTC", "provider_time_display", "PROVIDER_TIME_DISPLAY"], "");
    return raw ? formatWeatherCacheTime(raw) : "—";
  }

  function getWeatherAlertsPanelLocation(data, location) {
    var resolved = formatWeatherLocation(data, location);
    var zip = getWeatherZip(data, location);
    if (resolved !== "—" && zip !== "—" && resolved.indexOf(zip) === -1) {
      return resolved + " / ZIP " + zip;
    }
    if (resolved !== "—") return resolved;
    if (zip !== "—") return "ZIP " + zip;
    return "this location";
  }

  function appendWeatherAlertText(parent, tagName, className, text) {
    var el = document.createElement(tagName);
    if (className) el.className = className;
    el.textContent = weatherValue(text, "—");
    parent.appendChild(el);
    return el;
  }

  function appendWeatherAlertMeta(dl, label, value, extraClass) {
    var wrap = document.createElement("div");
    var dt = document.createElement("dt");
    var dd = document.createElement("dd");
    if (extraClass) wrap.className = extraClass;
    dt.textContent = label;
    dd.textContent = weatherValue(value, "—");
    wrap.appendChild(dt);
    wrap.appendChild(dd);
    dl.appendChild(wrap);
  }

  function setActiveNoaaAlertsPanelExpanded(expanded) {
    var panel = document.getElementById("activeNoaaAlertsPanel");
    var body = document.getElementById("activeNoaaAlertsBody");
    var toggle = document.getElementById("activeNoaaAlertsToggle");
    var trigger = document.getElementById("weatherDetailsLink");
    if (!panel || !body || !toggle) return;

    body.hidden = !expanded;
    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    toggle.setAttribute("aria-label", expanded ? "Hide active NOAA alerts" : "Show active NOAA alerts");
    panel.classList.toggle("weather-alerts-panel--expanded", expanded);
    panel.classList.toggle("weather-alerts-panel--collapsed", !expanded);
    if (trigger) trigger.setAttribute("aria-expanded", expanded ? "true" : "false");
  }

  function showActiveNoaaAlertsPanel() {
    var panel = document.getElementById("activeNoaaAlertsPanel");
    if (!panel) return;
    panel.hidden = false;
    panel.classList.remove("d-none");
    setActiveNoaaAlertsPanelExpanded(true);
    if (typeof panel.scrollIntoView === "function") {
      panel.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  function bindMarineAlertsPanelControls() {
    var trigger = document.getElementById("weatherDetailsLink");
    var panel = document.getElementById("activeNoaaAlertsPanel");
    var header = document.getElementById("activeNoaaAlertsHeader");
    var toggle = document.getElementById("activeNoaaAlertsToggle");

    if (trigger && trigger.dataset.bound !== "true") {
      trigger.dataset.bound = "true";
      trigger.addEventListener("click", function (event) {
        event.preventDefault();
        showActiveNoaaAlertsPanel();
      });
    }

    if (toggle && toggle.dataset.bound !== "true") {
      toggle.dataset.bound = "true";
      toggle.addEventListener("click", function (event) {
        var expanded = toggle.getAttribute("aria-expanded") === "true";
        event.preventDefault();
        event.stopPropagation();
        setActiveNoaaAlertsPanelExpanded(!expanded);
      });
    }

    if (header && header.dataset.bound !== "true") {
      header.dataset.bound = "true";
      header.addEventListener("click", function (event) {
        var toggleButton = document.getElementById("activeNoaaAlertsToggle");
        var expanded = toggleButton && toggleButton.getAttribute("aria-expanded") === "true";
        if (event.target && event.target.closest && event.target.closest("button")) return;
        setActiveNoaaAlertsPanelExpanded(!expanded);
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
        detail = detailId ? document.getElementById(detailId) : null;
        if (!detail) return;
        isOpen = detail.hidden;
        detail.hidden = !isOpen;
        button.setAttribute("aria-expanded", isOpen ? "true" : "false");
      });
    }
  }

  function renderMarineAlertsSummary(data, payload, location) {
    var alerts = sortWeatherAlertsForDisplay(getWeatherAlerts(data));
    var unavailable = weatherAlertsUnavailable(data, payload);
    var statusText = unavailable ? "Alerts Unavailable" : (alerts.length ? alerts.length + " Active" : "No Active Alerts");
    var summaryText = unavailable ? "NOAA alerts are unavailable right now." : (alerts.length ? "Review active NOAA marine alerts" : "No active NOAA alerts for this location.");
    var highest = alerts.length ? getWeatherAlertField(alerts[0], ["event", "EVENT", "headline", "HEADLINE"], "Marine alert") : "";
    var icon = document.getElementById("weatherAlertIcon");
    var highestEl = document.getElementById("weatherAlertHighest");
    var list = document.getElementById("weatherAlertsActiveNow");

    setWeatherText("weatherAlertStatus", statusText);
    setWeatherText("weatherAlertSummary", summaryText);
    if (highestEl) {
      highestEl.textContent = highest ? "Highest Risk: " + highest : (unavailable ? "Check official NOAA/NWS sources before departure." : "");
    }
    setWeatherText("weatherAlertsCheckedAt", getWeatherAlertsCheckedAt(data));

    if (icon) {
      icon.textContent = unavailable ? "!" : (alerts.length ? "!" : "✓");
    }

    if (!list) return;
    list.textContent = "";

    if (unavailable) {
      appendWeatherAlertText(list, "li", "", "NOAA alerts unavailable.");
      return;
    }
    if (!alerts.length) {
      appendWeatherAlertText(list, "li", "", "No active NOAA alerts.");
      return;
    }

    alerts.slice(0, 4).forEach(function (alert) {
      var li = document.createElement("li");
      var dot = document.createElement("span");
      var name = document.createElement("span");
      var expire = document.createElement("span");
      var expiresValue = getWeatherAlertExpiresValue(alert);
      dot.className = "weather-alert-dot " + weatherAlertRiskClass(alert);
      name.className = "weather-alert-mini-name";
      expire.className = "weather-alert-mini-expire";
      name.textContent = getWeatherAlertField(alert, ["event", "EVENT", "headline", "HEADLINE"], "Marine alert");
      expire.textContent = expiresValue ? "Expires " + formatWeatherAlertShortTime(expiresValue) : "Expires —";
      li.appendChild(dot);
      li.appendChild(name);
      li.appendChild(expire);
      list.appendChild(li);
    });
  }

  function renderWeatherAlertDetailBlock(parent, alert, detailId) {
    var detail = document.createElement("div");
    var grid = document.createElement("div");
    var source = getWeatherAlertField(alert, ["senderName", "SENDERNAME", "sender", "SENDER"], "");
    detail.className = "weather-alert-detail";
    detail.id = detailId;
    detail.hidden = true;
    grid.className = "weather-alert-detail-grid";

    [
      ["Headline", getWeatherAlertField(alert, ["headline", "HEADLINE"], "")],
      ["Instruction", getWeatherAlertField(alert, ["instruction", "INSTRUCTION"], "")],
      ["Source", source],
      ["Effective", formatWeatherAlertTime(getWeatherAlertField(alert, ["effective", "EFFECTIVE"], ""))],
      ["Expires", formatWeatherAlertTime(getWeatherAlertExpiresValue(alert))],
      ["Area", getWeatherAlertField(alert, ["areaDesc", "AREADESC"], "")]
    ].forEach(function (item) {
      var block = document.createElement("div");
      appendWeatherAlertText(block, "h4", "", item[0]);
      appendWeatherAlertText(block, "p", "", item[1]);
      grid.appendChild(block);
    });

    var description = document.createElement("div");
    description.className = "weather-alert-detail-wide";
    appendWeatherAlertText(description, "h4", "", "Description");
    appendWeatherAlertText(description, "p", "", getWeatherAlertField(alert, ["description", "DESCRIPTION"], ""));
    grid.appendChild(description);

    detail.appendChild(grid);
    appendWeatherAlertText(detail, "div", "weather-alert-disclaimer", "Use official NOAA/NWS sources and local marine safety channels for final go/no-go decisions.");
    parent.appendChild(detail);
  }

  function renderWeatherAlertRow(list, alert, index) {
    var article = document.createElement("article");
    var main = document.createElement("div");
    var titleWrap = document.createElement("div");
    var meta = document.createElement("dl");
    var actions = document.createElement("div");
    var detailId = "weatherAlertDetail" + index;
    var detailButton = document.createElement("button");
    var web = getWeatherAlertWeb(alert);
    var eventName = getWeatherAlertField(alert, ["event", "EVENT", "name", "NAME"], "Marine alert");
    var headline = getWeatherAlertField(alert, ["headline", "HEADLINE", "description", "DESCRIPTION"], "");

    article.className = "weather-alert-row " + weatherAlertRiskClass(alert);
    main.className = "weather-alert-row__main";
    meta.className = "weather-alert-meta-grid";
    actions.className = "weather-alert-row__actions";

    appendWeatherAlertText(titleWrap, "h3", "", eventName);
    appendWeatherAlertText(titleWrap, "p", "", headline);

    appendWeatherAlertMeta(meta, "Severity", getWeatherAlertField(alert, ["severity", "SEVERITY"], ""));
    appendWeatherAlertMeta(meta, "Urgency", getWeatherAlertField(alert, ["urgency", "URGENCY"], ""));
    appendWeatherAlertMeta(meta, "Certainty", getWeatherAlertField(alert, ["certainty", "CERTAINTY"], ""));
    appendWeatherAlertMeta(meta, "Effective", formatWeatherAlertTime(getWeatherAlertField(alert, ["effective", "EFFECTIVE"], "")));
    appendWeatherAlertMeta(meta, "Expires", formatWeatherAlertTime(getWeatherAlertExpiresValue(alert)));
    appendWeatherAlertMeta(meta, "Area", getWeatherAlertField(alert, ["areaDesc", "AREADESC"], ""), "weather-alert-area");

    detailButton.type = "button";
    detailButton.className = "weather-alert-detail-btn";
    detailButton.setAttribute("aria-expanded", "false");
    detailButton.setAttribute("aria-controls", detailId);
    detailButton.setAttribute("data-weather-alert-detail", "1");
    detailButton.textContent = "Details";
    actions.appendChild(detailButton);

    if (web) {
      var link = document.createElement("a");
      link.className = "weather-alert-official-link";
      link.href = web;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = "Official NOAA Alert";
      // Keep the official alert URL wired for future use while hiding the launch button.
      link.hidden = true;
      link.setAttribute("aria-hidden", "true");
      link.tabIndex = -1;
      actions.appendChild(link);
    }

    main.appendChild(titleWrap);
    main.appendChild(meta);
    main.appendChild(actions);
    article.appendChild(main);
    renderWeatherAlertDetailBlock(article, alert, detailId);
    list.appendChild(article);
  }

  function renderActiveNoaaAlertsPanel(data, payload, location) {
    var panel = document.getElementById("activeNoaaAlertsPanel");
    var title = document.getElementById("weatherAlertsPanelTitle");
    var badge = document.getElementById("weatherAlertsPanelBadge");
    var stateEl = document.getElementById("weatherAlertsPanelState");
    var list = document.getElementById("activeNoaaAlertsList");
    var alerts = sortWeatherAlertsForDisplay(getWeatherAlerts(data));
    var unavailable = weatherAlertsUnavailable(data, payload);
    var locationLabel = getWeatherAlertsPanelLocation(data, location);

    if (!panel || !stateEl || !list) return;

    if (title) title.textContent = "Active NOAA Alerts for " + locationLabel;
    if (badge) badge.textContent = unavailable ? "Unavailable" : (alerts.length ? alerts.length + " Active" : "No Active Alerts");

    panel.hidden = false;
    panel.classList.remove("d-none");
    stateEl.textContent = "";
    list.textContent = "";

    if (unavailable) {
      appendWeatherAlertText(stateEl, "strong", "", "NOAA alerts unavailable right now.");
      appendWeatherAlertText(stateEl, "span", "", "Check official NOAA/NWS sources before departure.");
      setActiveNoaaAlertsPanelExpanded(false);
      return;
    }

    if (!alerts.length) {
      appendWeatherAlertText(stateEl, "strong", "", "No active NOAA alerts for this location.");
      appendWeatherAlertText(stateEl, "span", "", "Conditions can change quickly. Review the latest marine forecast before departure.");
      setActiveNoaaAlertsPanelExpanded(false);
      return;
    }

    stateEl.textContent = "";
    alerts.forEach(function (alert, index) {
      renderWeatherAlertRow(list, alert, index + 1);
    });
    setActiveNoaaAlertsPanelExpanded(false);
  }

  function renderMarineAlertsDisplay(data, payload, location) {
    bindMarineAlertsPanelControls();
    renderMarineAlertsSummary(data || {}, payload || null, location || {});
    renderActiveNoaaAlertsPanel(data || {}, payload || null, location || {});
  }

  function getWeatherWaves(marine) {
    return (marine && (marine.waves || marine.WAVES)) ? (marine.waves || marine.WAVES) : {};
  }

  function getWeatherTide(marine) {
    var tide = marine && (marine.tide || marine.TIDE);
    if (!tide && marine) tide = marine.waterLevel || marine.WATERLEVEL;
    return tide || {};
  }

  function getWeatherTideSeries(tide) {
    var series = tide && (tide.series || tide.SERIES);
    return Array.isArray(series) ? series : [];
  }

  function getWeatherWaterLevelCurrent(marine) {
    return (marine && (marine.waterLevelCurrent || marine.WATERLEVELCURRENT)) ? (marine.waterLevelCurrent || marine.WATERLEVELCURRENT) : {};
  }

  function formatWeatherLocation(data, location) {
    var meta = getWeatherMeta(data);
    var request = meta && (meta.REQUEST || meta.request) ? (meta.REQUEST || meta.request) : {};
    var requestZip = weatherPick(meta, ["resolved_zip", "RESOLVED_ZIP"], weatherPick(request, ["zip", "ZIP"], location && location.zip ? location.zip : ""));
    var resolved = weatherPick(meta, ["resolved_display", "RESOLVED_DISPLAY", "resolvedDisplay", "RESOLVEDDISPLAY", "resolvedLocation", "RESOLVEDLOCATION", "resolved_location", "RESOLVED_LOCATION", "location", "LOCATION", "name", "NAME"], "");
    var city = weatherPick(meta, ["resolved_city", "RESOLVED_CITY", "city", "CITY"], "");
    var stateVal = weatherPick(meta, ["resolved_state", "RESOLVED_STATE", "state", "STATE", "stateCode", "STATECODE"], "");
    var place = weatherPick(meta, ["resolved_place", "RESOLVED_PLACE", "place", "PLACE"], "");
    var locationType = String(weatherPick(meta, ["resolved_location_type", "RESOLVED_LOCATION_TYPE"], "")).toLowerCase();
    var isZipRequest = locationType === "zip" || !!requestZip || !!(location && location.zip);
    var homePort = state.currentUser ? getPlanningHomePort(state.currentUser) : {};
    var homeZip = weatherPick(homePort, ["zip", "ZIP", "postalCode", "POSTALCODE"], "");
    var allowHomePortFallback = !!(requestZip && homeZip && String(requestZip) === String(homeZip));

    if (!resolved && place) {
      resolved = place + (stateVal ? ", " + stateVal : "");
    }
    if (!resolved && city) {
      resolved = city + (stateVal ? ", " + stateVal : "");
    }
    if (!resolved && isZipRequest && !allowHomePortFallback) {
      resolved = requestZip ? "ZIP " + requestZip : "";
    }
    if (!resolved && allowHomePortFallback) {
      city = weatherPick(homePort, ["city", "CITY"], "");
      stateVal = weatherPick(homePort, ["state", "STATE"], "");
      resolved = city ? city + (stateVal ? ", " + stateVal : "") : "";
    }
    return weatherValue(resolved, "—");
  }

  function getWeatherZip(data, location) {
    var meta = getWeatherMeta(data);
    var request = meta && (meta.REQUEST || meta.request) ? (meta.REQUEST || meta.request) : {};
    var zip = weatherPick(meta, ["resolved_zip", "RESOLVED_ZIP", "zip", "ZIP", "postalCode", "POSTALCODE"], weatherPick(request, ["zip", "ZIP"], ""));
    if (!zip && location && location.zip) zip = location.zip;
    return weatherValue(zip, "—");
  }

  function getWeatherAnchor(meta) {
    var anchor = meta && (meta.anchor || meta.ANCHOR) ? (meta.anchor || meta.ANCHOR) : {};
    var lat = weatherPick(anchor, ["lat", "LAT", "latitude", "LATITUDE"], weatherPick(meta, ["anchorLat", "ANCHORLAT", "anchor_lat", "ANCHOR_LAT", "lat", "LAT"], ""));
    var lon = weatherPick(anchor, ["lon", "LON", "lng", "LNG", "longitude", "LONGITUDE"], weatherPick(meta, ["anchorLon", "ANCHORLON", "anchor_lon", "ANCHOR_LON", "lon", "LON", "lng", "LNG"], ""));
    var latNum = weatherNumber(lat);
    var lonNum = weatherNumber(lon);
    if (Number.isFinite(latNum) && Number.isFinite(lonNum)) {
      return { label: latNum.toFixed(4) + ", " + lonNum.toFixed(4), lat: latNum, lon: lonNum };
    }
    return { label: "—", lat: NaN, lon: NaN };
  }

  function weatherRiskClass(label) {
    var value = String(label || "").toLowerCase();
    if (value === "extreme" || value === "high") return "risk-high";
    if (value === "caution" || value === "moderate") return "risk-caution";
    if (value === "good" || value === "low") return "risk-good";
    return "risk-low";
  }

  function weatherRiskDisplay(label) {
    return String(label || "").toLowerCase() === "low" ? "Good" : weatherValue(label, "—");
  }

  function weatherSkyIcon(summary) {
    var text = String(summary || "").toLowerCase();
    if (text.indexOf("rain") >= 0 || text.indexOf("shower") >= 0 || text.indexOf("storm") >= 0) return "☔";
    if (text.indexOf("cloud") >= 0 || text.indexOf("overcast") >= 0) return "☁";
    if (text.indexOf("night") >= 0 || text.indexOf("clear") >= 0 && text.indexOf("sun") < 0) return "☾";
    return "☀";
  }

  function formatWeatherWind(period) {
    var wind = parseWindSpeed(period && period.windSpeed ? period.windSpeed : "");
    var dir = period && period.windDirection ? period.windDirection : "";
    return (dir ? dir + " " : "") + (wind.speed ? wind.speed + " mph" : "—");
  }

  function renderMarineWeatherHeader(data, location) {
    var meta = getWeatherMeta(data);
    var surface = getWeatherSurface(data);
    var marine = getWeatherMarine(data);
    var tide = getWeatherTide(marine);
    var updated = weatherPick(meta, ["updatedAt", "UPDATEDAT", "updated_at", "UPDATED_AT", "dataUpdated", "DATAUPDATED", "generatedAt", "GENERATEDAT"], "");
    var obsTime = weatherPick(surface, ["observation_time", "OBSERVATION_TIME", "observed_at", "OBSERVED_AT"], "");
    var station = weatherPick(surface, ["station_id", "STATION_ID", "station", "STATION"], "");
    var tideStation = weatherPick(tide, ["stationName", "STATIONNAME", "station", "STATION"], weatherPick(getWeatherWaterLevelCurrent(marine), ["stationName", "STATIONNAME"], ""));
    var anchor = getWeatherAnchor(meta);
    var zip = getWeatherZip(data, location);
    var request = meta && (meta.REQUEST || meta.request) ? (meta.REQUEST || meta.request) : {};
    var locationType = String(weatherPick(meta, ["resolved_location_type", "RESOLVED_LOCATION_TYPE"], weatherPick(request, ["mode", "MODE"], location && location.mode ? location.mode : ""))).toLowerCase();
    var coordinateLat = Number.isFinite(anchor.lat) ? anchor.lat : weatherNumber(location && location.lat);
    var coordinateLon = Number.isFinite(anchor.lon) ? anchor.lon : weatherNumber(location && location.lon);
    var coordinateLabel = Number.isFinite(coordinateLat) && Number.isFinite(coordinateLon) ? coordinateLat.toFixed(4) + ", " + coordinateLon.toFixed(4) : anchor.label;
    var locationDetailLabelEl = document.getElementById("weatherLocationDetailLabel");

    if (locationType === "coords") {
      setWeatherText("weatherResolvedLocation", "Coordinates");
      if (locationDetailLabelEl) locationDetailLabelEl.textContent = "";
      setWeatherText("weatherZipDisplay", coordinateLabel);
    } else {
      setWeatherText("weatherResolvedLocation", formatWeatherLocation(data, location));
      if (locationDetailLabelEl) locationDetailLabelEl.textContent = "ZIP";
      setWeatherText("weatherZipDisplay", zip);
    }
    setWeatherText("weatherMetarStation", station);
    setWeatherText("weatherTideStationShort", tideStation);
    setWeatherText("weatherUpdatedAt", updated || obsTime ? "Updated " + formatWeatherTime(updated || obsTime) : "Updated —");
    setWeatherText("weatherAnchorMeta", "Anchor: " + anchor.label);
    setWeatherText("weatherTimezoneLabel", (new Date()).toLocaleTimeString(undefined, { timeZoneName: "short" }).split(" ").pop() || "—");
  }

  function renderMarineRisk(data) {
    var forecast = getWeatherForecast(data);
    var marine = getWeatherMarine(data);
    var waves = getWeatherWaves(marine);
    var surface = getWeatherSurface(data);
    var alerts = getWeatherAlerts(data);
    var now = forecast[0] || {};
    var wind = parseWindSpeed(now.windSpeed || "");
    var gust = resolveGustMph(now, wind);
    var risk = classifyWindRisk(gust || wind.speed || 0);
    var riskLabel = weatherRiskDisplay(risk.label);
    var waveHeight = weatherPick(marine, ["wave_height_ft", "WAVE_HEIGHT_FT"], weatherPick(waves, ["height", "HEIGHT"], ""));
    var visibility = weatherPick(surface, ["visibility_mi", "VISIBILITY_MI"], "");

    setWeatherText("weatherRiskValue", riskLabel);
    setWeatherText("weatherRiskSubtext", risk.level >= 2 ? "Use caution for small craft" : "Favorable for nearshore boating");
    setWeatherText("weatherRiskWind", "Wind " + formatWeatherWind(now));
    setWeatherText("weatherRiskGusts", gust ? "Gusts up to " + Math.round(gust) + " mph" : "Gusts —");
    setWeatherText("weatherRiskSeas", Number.isFinite(weatherNumber(waveHeight)) ? "Seas " + weatherNumber(waveHeight).toFixed(1) + " ft" : "Seas —");
    setWeatherText("weatherRiskSeasNote", "Short-period chop");
    setWeatherText("weatherRiskVisibility", Number.isFinite(weatherNumber(visibility)) ? "Visibility " + (weatherNumber(visibility) >= 10 ? "10+" : weatherNumber(visibility).toFixed(1)) + " mi" : "Visibility —");
    setWeatherText("weatherRiskVisibilityNote", Number.isFinite(weatherNumber(visibility)) && weatherNumber(visibility) >= 7 ? "Clear" : "—");
    setWeatherText("weatherRiskAlerts", alerts.length ? alerts.length + " active" : "None active");
    setWeatherText("weatherAlertStatus", alerts.length ? alerts.length + " Active" : "None");
    setWeatherText("weatherAlertSummary", alerts.length ? "Review active NOAA marine alerts" : "No active marine alerts");
    setWeatherText("weatherRiskRecommendation", risk.level >= 2 ? "Conditions are manageable near shore but may be uncomfortable for smaller boats or exposed water." : "Conditions look favorable, but review the hourly table before departure.");
  }

  function renderConditionsNow(data) {
    var forecast = getWeatherForecast(data);
    var surface = getWeatherSurface(data);
    var now = forecast[0] || {};
    var wind = parseWindSpeed(now.windSpeed || "");
    var gust = resolveGustMph(now, wind);
    var temp = weatherNumber(now.temperature);
    var summary = weatherValue(now.shortForecast || data.SUMMARY || data.summary, "—");
    var pressure = weatherPick(surface, ["pressure_inhg", "PRESSURE_INHG"], "");
    var visibility = weatherPick(surface, ["visibility_mi", "VISIBILITY_MI"], "");
    var humidity = weatherPick(surface, ["humidity", "HUMIDITY", "relative_humidity", "RELATIVE_HUMIDITY"], "");
    var dewPoint = weatherPick(surface, ["dewpoint_f", "DEWPOINT_F", "dewPointF", "DEWPOINTF"], "");
    var station = weatherPick(surface, ["station_id", "STATION_ID", "station", "STATION"], "");
    var obsTime = weatherPick(surface, ["observation_time", "OBSERVATION_TIME", "observed_at", "OBSERVED_AT"], now.startTime || "");

    setWeatherText("weatherConditionIcon", weatherSkyIcon(summary));
    setWeatherText("weatherConditionText", summary);
    setWeatherText("weatherCurrentTemp", Number.isFinite(temp) ? Math.round(temp) + "°F" : "—");
    setWeatherText("weatherFeelsLike", Number.isFinite(temp) ? Math.round(temp) + "°" : "—");
    setWeatherText("weatherCurrentWind", formatWeatherWind(now));
    setWeatherText("weatherCurrentGusts", gust ? Math.round(gust) + " mph" : "—");
    setWeatherText("weatherPressure", Number.isFinite(weatherNumber(pressure)) ? weatherNumber(pressure).toFixed(2) + " inHg" : "—");
    setWeatherText("weatherVisibility", Number.isFinite(weatherNumber(visibility)) ? (weatherNumber(visibility) >= 10 ? "10+ mi" : weatherNumber(visibility).toFixed(1) + " mi") : "—");
    setWeatherText("weatherHumidity", Number.isFinite(weatherNumber(humidity)) ? Math.round(weatherNumber(humidity)) + "%" : "—");
    setWeatherText("weatherDewPoint", Number.isFinite(weatherNumber(dewPoint)) ? Math.round(weatherNumber(dewPoint)) + "°F" : "—");
    setWeatherText("weatherObservedAt", obsTime ? formatWeatherTime(obsTime, "—", { hour: "numeric", minute: "2-digit", timeZoneName: "short" }) : "—");
    setWeatherText("weatherObservedStation", station);
  }

  function renderWavesPanel(data) {
    var marine = getWeatherMarine(data);
    var waves = getWeatherWaves(marine);
    var waveHeight = weatherPick(marine, ["wave_height_ft", "WAVE_HEIGHT_FT"], weatherPick(waves, ["height", "HEIGHT"], ""));
    var period = weatherPick(waves, ["period", "PERIOD"], "");
    var direction = weatherPick(waves, ["directionDeg", "DIRECTIONDEG", "direction_deg", "DIRECTION_DEG"], "");
    var heightNum = weatherNumber(waveHeight);
    var level = Number.isFinite(heightNum) ? Math.max(0, Math.min(12, Math.round(heightNum / 0.8))) : NaN;

    setWeatherText("weatherWaveHeight", Number.isFinite(heightNum) ? heightNum.toFixed(1) : "—");
    setWeatherText("weatherWaveTrendTop", "Steady");
    setWeatherText("weatherWavePeriod", Number.isFinite(weatherNumber(period)) ? weatherNumber(period).toFixed(weatherNumber(period) < 10 ? 1 : 0) + " sec" : "—");
    setWeatherText("weatherWaveDirection", Number.isFinite(weatherNumber(direction)) ? formatWaveDirection(weatherNumber(direction)) : "—");
    setWeatherText("weatherWaveLevel", Number.isFinite(level) ? "Level " + level : "—");
    setWeatherText("weatherWaveTrend", "Steady");
    setWeatherText("weatherWaveNote", Number.isFinite(heightNum) && heightNum < 2 ? "Short-period light chop. Manageable nearshore." : "Review seas and period before departure.");
  }

  function getWeatherTideTimezone(tide) {
    return String(weatherPick(tide, ["tz", "TZ", "timezone", "TIMEZONE"], "")).toLowerCase();
  }

  function parseWeatherTideDate(raw, tideTz) {
    if (!raw) return null;
    var s = String(raw).trim();
    var normalized = s.replace(" ", "T");
    var useUtc = tideTz === "gmt" || tideTz === "utc";
    var hasZone = /(?:z|[+-]\d{2}:?\d{2})$/i.test(normalized);
    var d = null;
    if (useUtc && !hasZone && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(normalized)) {
      d = new Date(normalized + "Z");
      if (!Number.isNaN(d.getTime())) return d;
    }
    d = new Date(s);
    if (!Number.isNaN(d.getTime())) return d;
    if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(s)) {
      d = new Date(normalized + "Z");
      if (!Number.isNaN(d.getTime())) return d;
      d = new Date(normalized);
      if (!Number.isNaN(d.getTime())) return d;
    }
    return null;
  }

  function formatWeatherTideTime(value, tideTz, fallback, options) {
    var raw = weatherValue(value, "");
    var parsed = raw ? parseWeatherTideDate(raw, tideTz) : null;
    if (!raw) return fallback || "—";
    if (!parsed) return raw;
    try {
      return parsed.toLocaleString(undefined, options || { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZoneName: "short" });
    } catch (e) {
      return parsed.toLocaleString();
    }
  }

  function parseWeatherTidePoint(point, tideTz) {
    var h = weatherNumber(point && (point.h !== undefined ? point.h : point.H));
    var rawTime = point && (point.t || point.T || point.time || point.TIME);
    var type = point && (point.type || point.TYPE || point.ty || point.TY);
    var dt = parseWeatherTideDate(rawTime, tideTz);
    return { h: h, rawTime: rawTime || "", type: weatherValue(type, ""), dt: dt };
  }

  function normalizeWeatherTideRange(range) {
    return String(range || "").toLowerCase() === "tomorrow" ? "tomorrow" : "today";
  }

  function getWeatherTideRangeDate(range) {
    var d = new Date();
    if (normalizeWeatherTideRange(range) === "tomorrow") {
      d.setDate(d.getDate() + 1);
    }
    d.setHours(0, 0, 0, 0);
    return d;
  }

  function isSameWeatherTideLocalDay(dt, target) {
    return !!(dt && target)
      && dt.getFullYear() === target.getFullYear()
      && dt.getMonth() === target.getMonth()
      && dt.getDate() === target.getDate();
  }

  function filterWeatherTideSeriesForRange(series, tideTz, range) {
    var source = Array.isArray(series) ? series : [];
    var target = getWeatherTideRangeDate(range);
    return source.filter(function (point) {
      var parsed = parseWeatherTidePoint(point, tideTz);
      return parsed.dt && isSameWeatherTideLocalDay(parsed.dt, target);
    });
  }

  function getSelectedWeatherTideSeries(series, tideTz) {
    return filterWeatherTideSeriesForRange(series, tideTz, tideSelectedRange);
  }

  function getFirstWeatherTidePoint(series, tideTz) {
    var points = (Array.isArray(series) ? series : [])
      .map(function (p) { return parseWeatherTidePoint(p, tideTz); })
      .filter(function (p) { return Number.isFinite(p.h) && p.dt; })
      .sort(function (a, b) { return a.dt.getTime() - b.dt.getTime(); });
    return points.length ? points[0] : null;
  }

  function interpolateWeatherTideCurrent(series, tideTz, nowMs) {
    var points = series.map(function (p) { return parseWeatherTidePoint(p, tideTz); }).filter(function (p) { return Number.isFinite(p.h); });
    var currentH = null;
    var i;
    var nowVal = Number.isFinite(nowMs) ? nowMs : Date.now();
    for (i = 0; i < points.length - 1; i++) {
      var a = points[i];
      var b = points[i + 1];
      if (!a.dt || !b.dt) continue;
      var ams = a.dt.getTime();
      var bms = b.dt.getTime();
      if (bms <= ams) continue;
      if (nowVal >= ams && nowVal <= bms) {
        var r = (nowVal - ams) / (bms - ams);
        currentH = a.h + ((b.h - a.h) * r);
        break;
      }
    }
    if (currentH === null) {
      var nearest = null;
      points.forEach(function (pnt) {
        if (!pnt.dt) return;
        var diff = Math.abs(nowVal - pnt.dt.getTime());
        if (!nearest || diff < nearest.diff) {
          nearest = { diff: diff, p: pnt };
        }
      });
      if (nearest && nearest.p) {
        currentH = nearest.p.h;
      }
    }
    return currentH;
  }

  function deriveWeatherTideTrend(series, tideTz, nowMs) {
    var points = series.map(function (p) { return parseWeatherTidePoint(p, tideTz); }).filter(function (p) { return Number.isFinite(p.h) && p.dt; });
    var nowVal = Number.isFinite(nowMs) ? nowMs : Date.now();
    var i;
    if (points.length < 2) return "";
    for (i = 0; i < points.length - 1; i++) {
      var a = points[i];
      var b = points[i + 1];
      var aType = String(a.type || "").toUpperCase().charAt(0);
      var bType = String(b.type || "").toUpperCase().charAt(0);
      var ams = a.dt.getTime();
      var bms = b.dt.getTime();
      if (bms <= ams) continue;
      if (nowVal >= ams && nowVal < bms) {
        if (aType === "L" && bType === "H") {
          return "Rising until " + formatWeatherTideTime(b.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" });
        }
        if (aType === "H" && bType === "L") {
          return "Falling until " + formatWeatherTideTime(b.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" });
        }
        return "";
      }
    }
    return "";
  }

  function findTideExtrema(series, targetType, fallbackMax, tideTz) {
    var points = series.map(function (p) { return parseWeatherTidePoint(p, tideTz); }).filter(function (p) { return Number.isFinite(p.h); });
    var typed = points.filter(function (p) { return String(p.type || "").toUpperCase().charAt(0) === targetType; });
    var pool = typed.length ? typed : points;
    var best = null;
    pool.forEach(function (p) {
      if (!best) { best = p; return; }
      if (fallbackMax && p.h > best.h) best = p;
      if (!fallbackMax && p.h < best.h) best = p;
    });
    return best;
  }

  function updateTideRangeControls() {
    var buttons = document.querySelectorAll("[data-tide-range]");
    Array.prototype.forEach.call(buttons, function (button) {
      var isActive = normalizeWeatherTideRange(button.getAttribute("data-tide-range")) === tideSelectedRange;
      button.classList.toggle("toggle-active", isActive);
      button.setAttribute("aria-pressed", isActive ? "true" : "false");
    });
  }

  function bindTideRangeControls() {
    var group = document.querySelector(".weather-toggle-group");
    if (!group) return;
    updateTideRangeControls();
    if (tideRangeControlsBound) return;
    group.addEventListener("click", function (event) {
      var target = event.target && event.target.closest ? event.target.closest("[data-tide-range]") : null;
      var nextRange = "";
      if (!target || !group.contains(target)) return;
      nextRange = normalizeWeatherTideRange(target.getAttribute("data-tide-range"));
      if (nextRange === tideSelectedRange) return;
      tideSelectedRange = nextRange;
      updateTideRangeControls();
      renderTidePanel(weatherBriefingState.data || {});
      renderTideGraph(tideLastMarine);
    });
    tideRangeControlsBound = true;
  }

  function renderTidePanel(data) {
    var marine = getWeatherMarine(data);
    var tide = getWeatherTide(marine);
    var waterLevel = getWeatherWaterLevelCurrent(marine);
    var series = getWeatherTideSeries(tide);
    var tideTz = getWeatherTideTimezone(tide);
    var selectedRange = normalizeWeatherTideRange(tideSelectedRange);
    var selectedSeries = getSelectedWeatherTideSeries(series, tideTz);
    var current = weatherPick(waterLevel, ["h", "H", "height", "HEIGHT"], "");
    var currentNum = weatherNumber(current);
    var high = findTideExtrema(series, "H", true, tideTz);
    var low = findTideExtrema(series, "L", false, tideTz);
    var summaryHigh = findTideExtrema(selectedSeries, "H", true, tideTz);
    var summaryLow = findTideExtrema(selectedSeries, "L", false, tideTz);
    var summaryFirst = getFirstWeatherTidePoint(selectedSeries, tideTz);
    var station = weatherPick(tide, ["stationName", "STATIONNAME", "station", "STATION"], weatherPick(waterLevel, ["stationName", "STATIONNAME"], ""));

    bindTideRangeControls();
    if (!Number.isFinite(currentNum) && series.length) {
      currentNum = interpolateWeatherTideCurrent(series, tideTz, Date.now());
    }
    var tideTrendLabel = weatherPick(waterLevel, ["trend", "TREND", "direction", "DIRECTION"], weatherPick(tide, ["trend", "TREND"], ""));
    if (!tideTrendLabel) {
      tideTrendLabel = deriveWeatherTideTrend(series, tideTz, Date.now());
    }
    setWeatherText("weatherCurrentTide", Number.isFinite(currentNum) ? currentNum.toFixed(1) : "—");
    setWeatherText("weatherTideDirection", tideTrendLabel);
    setWeatherText("weatherNextHighTideHeight", high ? high.h.toFixed(1) + " ft" : "—");
    setWeatherText("weatherNextHighTideTime", high ? formatWeatherTideTime(high.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherText("weatherNextLowTideHeight", low ? low.h.toFixed(1) + " ft" : "—");
    setWeatherText("weatherNextLowTideTime", low ? formatWeatherTideTime(low.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherText("weatherTideTrend", tideTrendLabel);
    setWeatherText("weatherTideStation", station);
    setWeatherText("weatherTideChartStation", station);
    setWeatherText("weatherTideSummaryCurrentLabel", selectedRange === "tomorrow" ? "Day Start" : "Current");
    setWeatherText("weatherTideSummaryCurrent", selectedRange === "tomorrow"
      ? (summaryFirst ? summaryFirst.h.toFixed(1) + " ft" : "—")
      : (Number.isFinite(currentNum) ? currentNum.toFixed(1) + " ft" : "—"));
    setWeatherText("weatherTideSummaryCurrentTrend", selectedRange === "tomorrow"
      ? (summaryFirst ? formatWeatherTideTime(summaryFirst.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" }) : "—")
      : tideTrendLabel);
    setWeatherText("weatherTideSummaryHighTime", summaryHigh ? formatWeatherTideTime(summaryHigh.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherText("weatherTideSummaryHighHeight", summaryHigh ? summaryHigh.h.toFixed(1) + " ft" : "—");
    setWeatherText("weatherTideSummaryLowTime", summaryLow ? formatWeatherTideTime(summaryLow.rawTime, tideTz, "—", { hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherText("weatherTideSummaryLowHeight", summaryLow ? summaryLow.h.toFixed(1) + " ft" : "—");
    setWeatherText("weatherTideSummaryNextHighTime", summaryHigh ? formatWeatherTideTime(summaryHigh.rawTime, tideTz, "—", { month: "numeric", day: "numeric", hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherText("weatherTideSummaryNextHighHeight", summaryHigh ? summaryHigh.h.toFixed(1) + " ft" : "—");
  }

  function renderHourlyBriefingTable(data) {
    var rows = getWeatherForecast(data).slice(0, 12);
    var tbody = document.getElementById("weatherHourlyRows");
    var marine = getWeatherMarine(data);
    var waves = getWeatherWaves(marine);
    var waveHeight = weatherPick(marine, ["wave_height_ft", "WAVE_HEIGHT_FT"], weatherPick(waves, ["height", "HEIGHT"], ""));
    var maxGust = 0;
    var rainMax = 0;
    if (!tbody) return;
    tbody.innerHTML = "";
    if (!rows.length) {
      tbody.innerHTML = "<tr><td colspan=\"8\">Weather forecast unavailable.</td></tr>";
      setWeatherText("weatherHourlySummary", "—");
      return;
    }
    rows.forEach(function (p) {
      var wind = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
      var gust = resolveGustMph(p, wind);
      var rain = inferRainPct(p);
      if (gust > maxGust) maxGust = gust;
      if (rain > rainMax) rainMax = rain;
    });
    rows.forEach(function (p) {
      var wind = parseWindSpeed(p && p.windSpeed ? p.windSpeed : "");
      var gust = resolveGustMph(p, wind);
      var rain = inferRainPct(p);
      var temp = weatherNumber(p && p.temperature);
      var risk = weatherRiskDisplay(classifyWindRisk(gust || wind.speed || 0).label);
      var tr = document.createElement("tr");
      tr.innerHTML = ""
        + "<td>" + escapeHtml(formatWeatherHour(p && p.startTime ? p.startTime : "") || weatherValue(p && p.name, "—")) + "</td>"
        + "<td>" + escapeHtml(formatWeatherWind(p)) + "</td>"
        + "<td>" + escapeHtml(gust ? Math.round(gust) + " mph" : "—") + "</td>"
        + "<td>" + escapeHtml(Number.isFinite(weatherNumber(waveHeight)) ? weatherNumber(waveHeight).toFixed(1) : "—") + "</td>"
        + "<td>" + escapeHtml(rain !== null && rain !== undefined ? rain + "%" : "—") + "</td>"
        + "<td>" + escapeHtml(Number.isFinite(temp) ? Math.round(temp) + "°" : "—") + "</td>"
        + "<td>" + escapeHtml(weatherSkyIcon(p && p.shortForecast)) + "</td>"
        + "<td><span class=\"risk-badge " + weatherRiskClass(risk) + "\">" + escapeHtml(risk) + "</span></td>";
      tbody.appendChild(tr);
    });
    setWeatherText("weatherHourlySummary", "Wind easing this evening • Gusts peak near " + (maxGust ? Math.round(maxGust) + " mph" : "—") + " • " + (rainMax ? "Rain risk up to " + rainMax + "%" : "No rain expected"));
  }

  function renderSourceDetails(data, location) {
    var meta = getWeatherMeta(data);
    var surface = getWeatherSurface(data);
    var marine = getWeatherMarine(data);
    var tide = getWeatherTide(marine);
    var waterLevel = getWeatherWaterLevelCurrent(marine);
    var anchor = getWeatherAnchor(meta);
    var station = weatherPick(surface, ["station_id", "STATION_ID", "station", "STATION"], "");
    var tideStation = weatherPick(tide, ["stationName", "STATIONNAME", "station", "STATION"], weatherPick(waterLevel, ["stationName", "STATIONNAME"], ""));
    var updated = weatherPick(meta, ["updatedAt", "UPDATEDAT", "updated_at", "UPDATED_AT", "dataUpdated", "DATAUPDATED", "generatedAt", "GENERATEDAT"], weatherPick(surface, ["observation_time", "OBSERVATION_TIME"], ""));

    setWeatherText("weatherSourceName", weatherPick(meta, ["source", "SOURCE", "weatherSource", "WEATHER_SOURCE"], "NOAA / NWS"));
    setWeatherText("weatherForecastType", weatherPick(meta, ["forecastType", "FORECASTTYPE", "forecast_type", "FORECAST_TYPE"], "Marine"));
    setWeatherText("weatherSourceResolvedLocation", formatWeatherLocation(data, location));
    setWeatherText("weatherSourceAnchor", anchor.label);
    setWeatherText("weatherSourceZip", getWeatherZip(data, location));
    setWeatherText("weatherSourceObservationStation", station);
    setWeatherText("weatherSourceTideStation", tideStation);
    setWeatherText("weatherSourceDataUpdated", updated ? formatWeatherTime(updated) : "—");
    var cacheReport = getWeatherCacheReport(data);
    var primaryCache = pickPrimaryWeatherCache(cacheReport);
    setWeatherText("weatherSourceCacheStatus", primaryCache ? weatherCacheStatusLabel(weatherPick(primaryCache, ["status", "STATUS"], "")) : "—");
    setWeatherText("weatherSourceCachedAt", primaryCache ? formatWeatherCacheTime(weatherPick(primaryCache, ["cached_at_utc", "CACHED_AT_UTC"], "")) : "—");
    setWeatherText("weatherSourceCacheExpires", primaryCache ? formatWeatherCacheTime(weatherPick(primaryCache, ["expires_at_utc", "EXPIRES_AT_UTC"], "")) : "—");
    setWeatherText("weatherSourceDataAge", primaryCache ? formatWeatherDuration(weatherPick(primaryCache, ["age_seconds", "AGE_SECONDS"], "")) : "—");
    setWeatherText("weatherSourceRefreshWindow", primaryCache ? formatWeatherRefreshWindow(primaryCache) : "—");
    setWeatherText("weatherSourceProvider", weatherPick(meta, ["provider", "PROVIDER"], "NOAA"));
    renderSourceCacheRows(cacheReport);
  }

  function getWeatherCacheReport(data) {
    var meta = getWeatherMeta(data || {});
    return (meta && (meta.CACHE || meta.cache)) || {};
  }

  function weatherCacheStatusLabel(status) {
    var value = String(status || "").toLowerCase();
    if (value === "fresh_fetch") return "Live fetch";
    if (value === "cache_hit") return "Cached";
    if (value === "bypass") return "Cache bypassed";
    if (value === "unavailable") return "Unavailable";
    if (value === "error") return "Error";
    if (value === "expired_not_used") return "Expired, not used";
    if (value === "not_reported" || value === "unknown") return "Unknown";
    return status ? weatherValue(status, "Unknown") : "Unknown";
  }

  function formatWeatherDuration(rawSeconds) {
    var seconds = weatherNumber(rawSeconds);
    var minutes = 0;
    var hours = 0;
    if (!Number.isFinite(seconds)) return "—";
    minutes = Math.max(0, Math.round(seconds / 60));
    if (minutes < 1) return "<1 min";
    if (minutes < 60) return minutes + " min";
    hours = Math.floor(minutes / 60);
    minutes = minutes % 60;
    return hours + "h" + (minutes ? " " + minutes + "m" : "");
  }

  function formatWeatherCacheTime(rawValue) {
    var value = weatherValue(rawValue, "");
    return value ? formatWeatherTime(value, "—") : "—";
  }

  function formatWeatherRefreshWindow(cacheBlock) {
    var ttl = weatherPick(cacheBlock, ["ttl_seconds", "TTL_SECONDS"], "");
    var expiresIn = weatherPick(cacheBlock, ["expires_in_seconds", "EXPIRES_IN_SECONDS"], "");
    var ttlText = formatWeatherDuration(ttl);
    var expiresText = formatWeatherDuration(expiresIn);
    if (ttlText === "—" && expiresText === "—") return "—";
    if (expiresText === "—") return ttlText;
    if (ttlText === "—") return expiresText + " remaining";
    return ttlText + " window; " + expiresText + " remaining";
  }

  function pickPrimaryWeatherCache(cacheReport) {
    var order = ["surface", "forecast", "marine", "tide", "zone_forecast", "alerts"];
    var i = 0;
    var key = "";
    for (i = 0; i < order.length; i += 1) {
      key = order[i];
      if (cacheReport && (cacheReport[key] || cacheReport[key.toUpperCase()])) {
        return cacheReport[key] || cacheReport[key.toUpperCase()];
      }
    }
    return null;
  }

  function renderSourceCacheRows(cacheReport) {
    var tbody = document.getElementById("weatherSourceCacheRows");
    var order = ["forecast", "alerts", "surface", "marine", "tide", "zone_forecast"];
    if (!tbody) return;
    tbody.innerHTML = "";
    if (!cacheReport || !Object.keys(cacheReport).length) {
      tbody.innerHTML = "<tr><td colspan=\"5\">Cache details unavailable.</td></tr>";
      return;
    }
    order.forEach(function (key) {
      var block = cacheReport[key] || cacheReport[key.toUpperCase()];
      var label = "";
      var provider = "";
      var status = "";
      var providerTime = "";
      var expires = "";
      var tr = null;
      if (!block) return;
      label = weatherPick(block, ["label", "LABEL"], key.replace(/_/g, " "));
      provider = weatherPick(block, ["source", "SOURCE"], "—");
      status = weatherCacheStatusLabel(weatherPick(block, ["status", "STATUS"], ""));
      providerTime = weatherPick(block, ["provider_time_display", "PROVIDER_TIME_DISPLAY", "provider_time_utc", "PROVIDER_TIME_UTC"], "");
      expires = weatherPick(block, ["expires_at_utc", "EXPIRES_AT_UTC"], "");
      tr = document.createElement("tr");
      tr.innerHTML = ""
        + "<td>" + escapeHtml(label) + "</td>"
        + "<td>" + escapeHtml(provider) + "</td>"
        + "<td>" + escapeHtml(status) + "</td>"
        + "<td>" + escapeHtml(providerTime ? formatWeatherCacheTime(providerTime) : "—") + "</td>"
        + "<td>" + escapeHtml(expires ? formatWeatherCacheTime(expires) : "—") + "</td>";
      tbody.appendChild(tr);
    });
    if (!tbody.children.length) {
      tbody.innerHTML = "<tr><td colspan=\"5\">Cache details unavailable.</td></tr>";
    }
  }

  function normalizeWeatherMapLayers(rawLayers) {
    var layers = [];
    if (Array.isArray(rawLayers)) {
      rawLayers.forEach(function (layer) {
        if (typeof layer === "string") layers.push(layer);
        else if (layer && typeof layer === "object") layers.push(weatherValue(layer.label || layer.LABEL || layer.name || layer.NAME || layer.title || layer.TITLE || layer.key || layer.KEY, ""));
      });
    } else if (rawLayers && typeof rawLayers === "object") {
      Object.keys(rawLayers).forEach(function (key) {
        var layer = rawLayers[key];
        if (typeof layer === "string") layers.push(layer);
        else if (layer && typeof layer === "object") layers.push(weatherValue(layer.name || layer.NAME || layer.title || layer.TITLE || key, ""));
        else layers.push(key);
      });
    }
    return layers.filter(function (layerName) { return !!weatherValue(layerName, ""); });
  }

  function appendDefaultWeatherMapLayerLabels(layers) {
    var requiredLayers = ["Radar", "Marine Warnings", "Wind Forecast", "Cloud / Satellite", "Surface Fronts"];
    var existing = {};

    layers.forEach(function (layerName) {
      existing[String(layerName).toLowerCase()] = true;
    });

    requiredLayers.forEach(function (layerName) {
      var key = layerName.toLowerCase();
      if (!existing[key]) {
        layers.push(layerName);
        existing[key] = true;
      }
    });

    return layers;
  }

  function renderMapLayersPanel(data) {
    var layers = appendDefaultWeatherMapLayerLabels(normalizeWeatherMapLayers(data && (data.MAP_LAYERS || data.map_layers || data.mapLayers)));
    var listEl = document.getElementById("weatherMapLayerList");
    setWeatherText("weatherMapLayerCount", layers.length);
    if (!listEl) return;
    listEl.innerHTML = "";
    if (!layers.length) {
      listEl.innerHTML = "<li>No map layers delivered for this location.</li>";
      return;
    }
    layers.forEach(function (name) {
      var li = document.createElement("li");
      li.textContent = name;
      listEl.appendChild(li);
    });
  }

  function resolveWeatherMapAnchor(data, location) {
    var anchor = getWeatherAnchor(getWeatherMeta(data));
    var loc = location || {};
    var lat = NaN;
    var lon = NaN;

    if (Number.isFinite(anchor.lat) && Number.isFinite(anchor.lon)) {
      return anchor;
    }
    if (String(loc.mode || "").toLowerCase() === "coords") {
      lat = weatherNumber(loc.lat);
      lon = weatherNumber(loc.lon);
      if (Number.isFinite(lat) && Number.isFinite(lon)) {
        return { label: lat.toFixed(4) + ", " + lon.toFixed(4), lat: lat, lon: lon };
      }
    }
    return { label: "—", lat: NaN, lon: NaN };
  }

  function initWeatherLeafletMap() {
    var mapEl = document.getElementById("weatherLeafletMap");
    if (!mapEl || !window.L) return null;
    if (weatherMapInstance) return weatherMapInstance;

    weatherMapInstance = window.L.map(mapEl, {
      zoomControl: true,
      attributionControl: true
    }).setView([28.2326, -82.7327], 7);

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap"
    }).addTo(weatherMapInstance);

    if (window.FPW && typeof window.FPW.attachLeafletWeatherOverlays === "function") {
      weatherMapOverlayController = window.FPW.attachLeafletWeatherOverlays({
        map: weatherMapInstance,
        mode: "weather"
      });
    }

    mapEl.__fpwWeatherMap = weatherMapInstance;
    mapEl.__fpwWeatherOverlayController = weatherMapOverlayController;
    setTimeout(function () {
      if (weatherMapInstance) weatherMapInstance.invalidateSize();
    }, 0);

    return weatherMapInstance;
  }

  function renderWeatherLeafletMap(data, location) {
    var map = initWeatherLeafletMap();
    var anchor = resolveWeatherMapAnchor(data, location);
    var zoom = 9;
    if (!map || !Number.isFinite(anchor.lat) || !Number.isFinite(anchor.lon)) return;

    if (weatherMapHasCentered && typeof map.getZoom === "function") {
      zoom = map.getZoom();
    }
    map.setView([anchor.lat, anchor.lon], zoom);
    weatherMapHasCentered = true;
    setTimeout(function () {
      if (map) map.invalidateSize();
    }, 0);
  }

  function invalidateWeatherMapAfterModalOpen() {
    var map = weatherMapInstance || initWeatherLeafletMap();
    if (!map) return;
    setTimeout(function () {
      if (map && typeof map.invalidateSize === "function") {
        map.invalidateSize();
      }
    }, 80);
  }

  function openWeatherMapModal() {
    var modal = document.getElementById("weatherMapModal");
    var closeButton = document.getElementById("weatherMapModalClose");
    if (!modal) return;

    weatherMapModalPreviousFocus = document.activeElement;
    modal.hidden = false;
    modal.setAttribute("aria-hidden", "false");
    if (document.body) {
      document.body.classList.add("weather-map-modal-open");
    }
    renderWeatherLeafletMap(weatherBriefingState.data || {}, weatherBriefingState.location || {});
    invalidateWeatherMapAfterModalOpen();
    if (closeButton && typeof closeButton.focus === "function") {
      closeButton.focus();
    }
  }

  function closeWeatherMapModal() {
    var modal = document.getElementById("weatherMapModal");
    if (!modal || modal.hidden) return;

    modal.hidden = true;
    modal.setAttribute("aria-hidden", "true");
    if (document.body) {
      document.body.classList.remove("weather-map-modal-open");
    }
    if (
      weatherMapModalPreviousFocus
      && typeof weatherMapModalPreviousFocus.focus === "function"
      && document.contains(weatherMapModalPreviousFocus)
    ) {
      weatherMapModalPreviousFocus.focus();
    }
    weatherMapModalPreviousFocus = null;
  }

  function bindWeatherMapModalControls() {
    var openButton = document.getElementById("weatherMapLayersButton");
    var closeButton = document.getElementById("weatherMapModalClose");
    var modal = document.getElementById("weatherMapModal");
    if (weatherMapModalControlsBound || !modal) return;

    if (openButton) {
      openButton.addEventListener("click", openWeatherMapModal);
    }
    if (closeButton) {
      closeButton.addEventListener("click", closeWeatherMapModal);
    }
    modal.addEventListener("click", function (event) {
      if (event.target && event.target.getAttribute("data-weather-map-close") !== null) {
        closeWeatherMapModal();
      }
    });
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && !modal.hidden) {
        closeWeatherMapModal();
      }
    });
    weatherMapModalControlsBound = true;
  }

  function getWeatherZoneForecast(data) {
    return (data && (data.ZONE_FORECAST || data.zone_forecast || data.zoneForecast)) || {};
  }

  function renderZoneForecastPanel(data) {
    var zone = getWeatherZoneForecast(data);
    var unavailableEl = document.getElementById("weatherZoneForecastUnavailable");
    var contentEl = document.getElementById("weatherZoneForecastContent");
    var periodsEl = document.getElementById("weatherZoneForecastPeriods");
    var synopsisBlock = document.getElementById("weatherZoneForecastSynopsisBlock");
    var rawAvailable = zone && weatherPick(zone, ["available", "AVAILABLE"], false);
    var available = rawAvailable === true || String(rawAvailable).toLowerCase() === "true";
    var zoneId = weatherValue(weatherPick(zone, ["zone_id", "ZONE_ID", "zoneId", "ZONEID"], ""), "");
    var zoneName = weatherValue(weatherPick(zone, ["zone_name", "ZONE_NAME", "zoneName", "ZONENAME"], ""), "");
    var office = weatherValue(weatherPick(zone, ["office", "OFFICE", "wfo", "WFO"], ""), "");
    var source = weatherValue(weatherPick(zone, ["source", "SOURCE"], "NOAA/NWS Coastal Waters Forecast"), "NOAA/NWS Coastal Waters Forecast");
    var sourceUrl = weatherValue(weatherPick(zone, ["source_url", "SOURCE_URL", "sourceUrl", "SOURCEURL"], ""), "");
    var synopsis = weatherValue(weatherPick(zone, ["synopsis", "SYNOPSIS"], ""), "");
    var periods = weatherPick(zone, ["periods", "PERIODS"], []);
    var cacheReport = getWeatherCacheReport(data);
    var cacheBlock = (cacheReport && (cacheReport.zone_forecast || cacheReport.ZONE_FORECAST)) || {};
    var zoneReason = weatherValue(weatherPick(zone, ["reason", "REASON"], ""), "");
    var zoneTiming = weatherPick(zone, ["timing", "TIMING"], {});
    var zoneTimingMs = weatherPick(zoneTiming, ["total_ms", "TOTAL_MS", "totalMs", "TOTALMS"], "");
    var zoneTimingText = zoneTimingMs !== "" && zoneTimingMs !== null && zoneTimingMs !== undefined ? " • Zone: " + zoneTimingMs + "ms" : "";
    var unavailableMessage = zoneReason ? "NOAA coastal marine zone forecast is not available for this location. " + zoneReason : "NOAA coastal marine zone forecast is not available for this location.";

    setWeatherText("weatherZoneForecastMeta", available && zoneId ? zoneId + (zoneName ? " · " + zoneName : "") : "—");
    setWeatherText("weatherZoneForecastOffice", available && office ? "Issued by NWS " + office : "Source: " + source);
    setWeatherText("weatherZoneForecastCacheMeta", "Provider updated: " + formatWeatherCacheTime(weatherPick(cacheBlock, ["provider_time_display", "PROVIDER_TIME_DISPLAY", "provider_time_utc", "PROVIDER_TIME_UTC"], "")) + " • Cache: " + weatherCacheStatusLabel(weatherPick(cacheBlock, ["status", "STATUS"], "")) + " • Expires: " + formatWeatherCacheTime(weatherPick(cacheBlock, ["expires_at_utc", "EXPIRES_AT_UTC"], "")) + zoneTimingText);

    if (!available) {
      if (unavailableEl) {
        unavailableEl.textContent = unavailableMessage;
        unavailableEl.classList.remove("d-none");
      }
      if (contentEl) contentEl.classList.add("d-none");
      return;
    }

    if (unavailableEl) unavailableEl.classList.add("d-none");
    if (contentEl) contentEl.classList.remove("d-none");

    setWeatherText("weatherZoneForecastSynopsis", synopsis || "—");
    if (synopsisBlock) synopsisBlock.classList.toggle("d-none", !synopsis);

    if (periodsEl) {
      periodsEl.innerHTML = "";
      if (Array.isArray(periods) && periods.length) {
        periods.forEach(function (period) {
          var name = weatherValue(weatherPick(period, ["name", "NAME"], ""), "—");
          var forecast = weatherValue(weatherPick(period, ["forecast", "FORECAST"], ""), "—");
          var article = document.createElement("article");
          article.className = "zone-forecast-period";
          article.innerHTML = "<h3>" + escapeHtml(name) + "</h3><p>" + escapeHtml(forecast) + "</p>";
          periodsEl.appendChild(article);
        });
      } else {
        periodsEl.innerHTML = "<article class=\"zone-forecast-period\"><p>NOAA coastal marine zone forecast periods are not available for this location.</p></article>";
      }
    }

    if (sourceUrl) {
      setWeatherHtml("weatherZoneForecastSource", "Source: <a href=\"" + escapeHtml(sourceUrl) + "\" target=\"_blank\" rel=\"noopener\">" + escapeHtml(source) + "</a>");
    } else {
      setWeatherText("weatherZoneForecastSource", "Source: " + source);
    }
  }

  function renderBestWindowPanel() {
    setWeatherText("weatherBestWindowTime", "Based on current marine forecast");
    setWeatherText("weatherBestWindowSummary", "Review the next 12 hours table before departure.");
    setWeatherText("weatherWatchAfterTime", "—");
    setWeatherText("weatherWatchAfterSummary", "Use the hourly forecast table for changing wind, rain, visibility, and marine risk.");
  }

  function renderActiveCruiseWeatherAddOn(data) {
    var forecast = getWeatherForecast(data);
    var marine = getWeatherMarine(data);
    var waves = getWeatherWaves(marine);
    var surface = getWeatherSurface(data);
    var now = forecast[0] || {};
    var wind = parseWindSpeed(now.windSpeed || "");
    var gust = resolveGustMph(now, wind);
    var waveHeight = weatherPick(marine, ["wave_height_ft", "WAVE_HEIGHT_FT"], weatherPick(waves, ["height", "HEIGHT"], ""));
    var visibility = weatherPick(surface, ["visibility_mi", "VISIBILITY_MI"], "");
    var emptyEl = document.getElementById("weatherActiveCruiseEmpty");
    var routeName = dashboardSignals.activeRoute && dashboardSignals.activeRoute.name ? dashboardSignals.activeRoute.name : "—";

    setWeatherText("weatherActiveRouteName", routeName);
    setWeatherText("weatherActiveWind", formatWeatherWind(now));
    setWeatherText("weatherActiveGusts", gust ? Math.round(gust) + " mph" : "—");
    setWeatherText("weatherActiveSeas", Number.isFinite(weatherNumber(waveHeight)) ? weatherNumber(waveHeight).toFixed(1) + " ft" : "—");
    setWeatherText("weatherActiveVisibility", Number.isFinite(weatherNumber(visibility)) ? (weatherNumber(visibility) >= 10 ? "10+ mi" : weatherNumber(visibility).toFixed(1) + " mi") : "—");
    setWeatherText("weatherActiveUpdatedAt", weatherPick(getWeatherMeta(data), ["updatedAt", "UPDATEDAT", "updated_at", "UPDATED_AT"], "") ? formatWeatherTime(weatherPick(getWeatherMeta(data), ["updatedAt", "UPDATEDAT", "updated_at", "UPDATED_AT"], ""), "—", { hour: "numeric", minute: "2-digit" }) : "—");
    setWeatherHtml("weatherActiveNextSix", "<li>Weather context is loaded from this page only.</li><li>Review the next 12 hours table before departure.</li>");
    setWeatherText("weatherActiveCruiseImpact", "No active cruise weather context available on this page yet.");
    if (emptyEl) emptyEl.hidden = false;
  }

  function renderMarineWeatherBriefing(data, payload, location) {
    var merged = mergeWeatherBriefingData(data || {});
    weatherBriefingState.payload = payload || weatherBriefingState.payload;
    weatherBriefingState.location = location || weatherBriefingState.location;

    renderMarineWeatherHeader(merged, weatherBriefingState.location || location || {});
    renderMarineRisk(merged);
    renderMarineAlertsDisplay(merged, payload, weatherBriefingState.location || location || {});
    bindWeatherMapModalControls();
    renderWeatherLeafletMap(merged, weatherBriefingState.location || location || {});
    renderConditionsNow(merged);
    renderWavesPanel(merged);
    renderTidePanel(merged);
    renderHourlyBriefingTable(merged);
    renderSourceDetails(merged, weatherBriefingState.location || location || {});
    renderMapLayersPanel(merged);
    renderZoneForecastPanel(merged);
    renderBestWindowPanel(merged);
    renderActiveCruiseWeatherAddOn(merged);
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

    var tideTz = getWeatherTideTimezone(tide);
    series = getSelectedWeatherTideSeries(series, tideTz);
    if (!series.length) {
      svg.innerHTML = "";
      if (startEl) startEl.textContent = "—";
      if (endEl) endEl.textContent = "—";
      if (nowEl) nowEl.textContent = normalizeWeatherTideRange(tideSelectedRange) === "tomorrow" ? "Tomorrow —" : "Now —";
      if (emptyEl) {
        emptyEl.textContent = normalizeWeatherTideRange(tideSelectedRange) === "tomorrow"
          ? "Tide data unavailable for tomorrow."
          : "Tide data unavailable for today.";
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

    series.forEach(function (p) {
      var parsed = parseWeatherTidePoint(p, tideTz);
      var h = parsed.h;
      if (!Number.isFinite(h)) return;
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
      points.push(parsed);
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
      var dt = parseWeatherTideDate(raw, tideTz);
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

    var showCurrentMarker = normalizeWeatherTideRange(tideSelectedRange) === "today";
    var nowMs = Date.now();
    var currentH = null;
    var currentX = null;
    var currentY = null;
    var i;
    if (showCurrentMarker) {
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
      nowEl.textContent = showCurrentMarker ? "Now —" : "Tomorrow";
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

  function createWeatherAbortController() {
    if (typeof window === "undefined" || !("AbortController" in window)) {
      return null;
    }
    return new window.AbortController();
  }

  function abortWeatherController(controller) {
    if (Array.isArray(controller)) {
      controller.forEach(function (childController) {
        abortWeatherController(childController);
      });
      return;
    }
    if (controller && typeof controller.abort === "function") {
      try {
        controller.abort();
      } catch (err) {
        // Ignore browser abort edge cases; the request sequence guard still applies.
      }
    }
  }

  function isWeatherAbortError(err) {
    return !!(err && (err.name === "AbortError" || err.code === 20));
  }

  function createWeatherTimeoutError(message) {
    var err = new Error(message || "Weather request timed out.");
    err.name = "TimeoutError";
    return err;
  }

  function isWeatherTimeoutError(err) {
    return !!(err && err.name === "TimeoutError");
  }

  function fetchWeatherJson(url, options) {
    var fetchOptions = { credentials: "same-origin" };
    var timeoutMs = options && options.timeoutMs ? parseInt(options.timeoutMs, 10) : 0;
    var timeoutTimer = 0;
    var settled = false;

    if (options && options.signal) {
      fetchOptions.signal = options.signal;
    }

    return new Promise(function (resolve, reject) {
      function finish(callback, value) {
        if (settled) return;
        settled = true;
        if (timeoutTimer) {
          window.clearTimeout(timeoutTimer);
          timeoutTimer = 0;
        }
        callback(value);
      }

      if (Number.isFinite(timeoutMs) && timeoutMs > 0) {
        timeoutTimer = window.setTimeout(function () {
          if (options && typeof options.onTimeout === "function") {
            options.onTimeout();
          }
          finish(reject, createWeatherTimeoutError());
        }, timeoutMs);
      }

      fetch(url, fetchOptions)
        .then(function (response) {
          if (!response.ok) {
            throw new Error("Request failed with status " + response.status);
          }
          return response.json();
        })
        .then(function (payload) {
          finish(resolve, payload);
        })
        .catch(function (err) {
          finish(reject, err);
        });
    });
  }

  function hydrateMarineTrend(location, requestSeq) {
    var hydrationControllers = [];
    if (requestSeq === weatherRequestSeq) {
      showMarineHydrationBadge();
    }
    abortWeatherController(weatherHydrationAbortController);
    weatherHydrationAbortController = hydrationControllers;

    function requestMarineDetail(detail) {
      var hydrationController = createWeatherAbortController();
      var detailMode = "full";
      if (hydrationController) {
        hydrationControllers.push(hydrationController);
      }

      return fetchWeatherJson(weatherUrl(location, "&marineOnly=1&marineMode=" + encodeURIComponent(detailMode) + "&marineDetail=" + encodeURIComponent(detail)), {
        signal: hydrationController ? hydrationController.signal : null,
        timeoutMs: WEATHER_HYDRATION_TIMEOUT_MS,
        onTimeout: function () {
          abortWeatherController(hydrationController);
        }
      }).then(function (payload) {
        if (requestSeq !== weatherRequestSeq) return;
        if (!payload || payload.SUCCESS === false) return;
        var data = payload.DATA || {};
        if (data.MARINE) {
          renderTideGraph(data.MARINE);
          renderWaveHeight(data.MARINE);
        }
        renderMarineWeatherBriefing(data, payload, location);
      }).catch(function (err) {
        if (isWeatherAbortError(err) || isWeatherTimeoutError(err)) return;
        // Keep initial quick render if trend hydration fails.
      });
    }

    return Promise.all([
      requestMarineDetail("marine"),
      requestMarineDetail("zoneForecast")
    ]).finally(function () {
        if (requestSeq === weatherRequestSeq) {
          hideMarineHydrationBadge();
          weatherHydrationAbortController = null;
        }
      });
  }

  function loadWeather(location) {
    var loadingEl = document.getElementById("weatherLoading");
    if (!loadingEl) {
      return;
    }
    weatherRequestSeq += 1;
    var requestSeq = weatherRequestSeq;

    abortWeatherController(weatherQuickAbortController);
    abortWeatherController(weatherHydrationAbortController);
    weatherQuickAbortController = createWeatherAbortController();
    weatherHydrationAbortController = null;
    weatherBriefingState.data = {};
    weatherBriefingState.payload = null;
    weatherBriefingState.location = location || null;
    tideLastMarine = null;

    clearWeatherError();
    startWeatherScanConsole(location);

    return fetchWeatherJson(weatherUrl(location, "&marineMode=summary"), {
      signal: weatherQuickAbortController ? weatherQuickAbortController.signal : null
    })
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
        renderMarineWeatherBriefing(data, payload, location);
        completeWeatherScanConsole();
        hydrateMarineTrend(location, requestSeq);
      })
      .catch(function (err) {
        if (isWeatherAbortError(err)) return;
        if (requestSeq !== weatherRequestSeq) return;
        renderWeatherSummary("", "");
        renderWeatherAnchor(null);
        renderWeatherAlerts([]);
        renderWeatherForecast([]);
        renderWeatherSurface(null);
        renderTideGraph(null);
        renderWaveHeight(null);
        weatherBriefingState.data = {};
        renderMarineWeatherBriefing({}, null, location);
        failWeatherScanConsole(WEATHER_SCAN_ERROR_MESSAGE);
        setWeatherError((err && err.message) ? err.message : null);
      })
      .finally(function () {
        if (requestSeq === weatherRequestSeq) {
          weatherQuickAbortController = null;
        }
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
      weatherBriefingState.data = {};
      renderMarineWeatherBriefing({}, null, null);
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
    var panel = null;
    var collapseToggleBtn = null;
    var summaryEl = null;
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
    var selectedRouteCode = "";
    var followShareModalEl = null;
    var followShareModal = null;
    var followShareUrlEl = null;
    var followShareOpenLink = null;
    var followShareSmsLink = null;
    var followShareCopyBtn = null;
    var followShareStatusEl = null;

    function routeUrl(routeCode) {
      return BASE_PATH + "/api/v1/route.cfc?method=handle&action=getTimeline&routeCode=" + encodeURIComponent(routeCode || "") + "&returnformat=json";
    }

    function setRoutesPanelCollapsed(collapsed) {
      if (!panel) return;
      panel.classList.toggle("is-collapsed", !!collapsed);
      if (collapseToggleBtn) {
        collapseToggleBtn.setAttribute("aria-expanded", collapsed ? "false" : "true");
        collapseToggleBtn.textContent = collapsed ? "Expand" : "Collapse";
      }
    }

    function ensureRoutesPanelCollapseControls() {
      var panelBody = null;
      var createRouteBtn = document.getElementById("openRouteBuilderBtn");
      var i;

      if (!panel) return;

      for (i = 0; i < panel.children.length; i += 1) {
        if (panel.children[i].classList && panel.children[i].classList.contains("card-body")) {
          panelBody = panel.children[i];
          break;
        }
      }
      if (panelBody && !panelBody.id) {
        panelBody.id = "expeditionTimelinePanelBody";
      }

      collapseToggleBtn = document.getElementById("toggleRoutesPanelBtn");
      if (collapseToggleBtn || !createRouteBtn || !createRouteBtn.parentNode) return;

      collapseToggleBtn = document.createElement("button");
      collapseToggleBtn.type = "button";
      collapseToggleBtn.className = "btn-secondary";
      collapseToggleBtn.id = "toggleRoutesPanelBtn";
      collapseToggleBtn.setAttribute("aria-controls", "expeditionTimelinePanelBody");
      collapseToggleBtn.setAttribute("aria-expanded", "true");
      collapseToggleBtn.textContent = "Collapse";
      createRouteBtn.parentNode.insertBefore(collapseToggleBtn, createRouteBtn);
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
      if (routeListEl) routeListEl.innerHTML = "";
      if (routeEmptyEl) toggleHidden(routeEmptyEl, false);
      if (accordionEl) {
        accordionEl.innerHTML = "";
        toggleHidden(accordionEl, true);
      }
      dashboardSignals.routes.total = 0;
      refreshMissionSummary();
      renderRecommendedNextSteps();
      updateCurrentDraftActionButtons();
    }

    function normalizeStatus(status) {
      var s = (status || "").toString().toUpperCase();
      return s === "COMPLETED" ? "COMPLETED" : "NOT_STARTED";
    }

    function buildRouteSummaryText(totals) {
      totals = totals && typeof totals === "object" ? totals : {};
      var pct = Number.isFinite(parseFloat(totals.PCT_COMPLETE)) ? parseFloat(totals.PCT_COMPLETE) : 0;
      var totalNm = Number.isFinite(parseFloat(totals.TOTAL_NM)) ? parseFloat(totals.TOTAL_NM) : 0;
      var totalLocks = Number.isFinite(parseFloat(totals.TOTAL_LOCKS)) ? parseFloat(totals.TOTAL_LOCKS) : 0;
      return Math.round(pct) + "% complete • " + formatNumber(totalNm, 1) + " NM • " + formatNumber(totalLocks, 0) + " locks";
    }

    function buildRouteSubtitle(route, currentGroup) {
      var description = route && route.DESCRIPTION !== undefined && route.DESCRIPTION !== null
        ? String(route.DESCRIPTION).trim()
        : "";
      if (description) return description;
      if (currentGroup && currentGroup.floatPlanName) return currentGroup.floatPlanName;
      if (route && route.SHORT_CODE) return String(route.SHORT_CODE);
      return "Saved route";
    }

    /* Route readiness setup helpers live in the outer dashboard scope. */

    function buildRouteStatusPills(currentState) {
      if (currentState === "ACTIVE") {
        return ""
          + '<div class="fpw-status-pill-group">'
          + '  <span class="fpw-status-pill fpw-status-pill-active">Active Route</span>'
          + '  <span class="fpw-status-pill fpw-status-pill-monitoring">Monitoring Active</span>'
          + '</div>';
      }
      if (currentState === "DRAFT") {
        return '<span class="fpw-status-pill fpw-status-pill-draft">Draft Group</span>';
      }
      return '<span class="fpw-status-pill fpw-status-pill-saved">Saved Route</span>';
    }

    function firstFiniteRouteTotal(totals, keys) {
      var source = totals && typeof totals === "object" ? totals : {};
      var key = "";
      var raw = "";
      var value = 0;
      for (var i = 0; i < keys.length; i += 1) {
        key = keys[i];
        if (!Object.prototype.hasOwnProperty.call(source, key)) continue;
        raw = source[key];
        value = parseFloat(raw);
        if (Number.isFinite(value)) return value;
      }
      return 0;
    }

    function buildRouteSummaryList(route, totals) {
      var source = totals && typeof totals === "object" ? totals : {};
      var routeSource = route && typeof route === "object" ? route : {};
      var endpoints = routeSource.ROUTE_ENDPOINTS && typeof routeSource.ROUTE_ENDPOINTS === "object" ? routeSource.ROUTE_ENDPOINTS : {};
      var distanceNm = firstFiniteRouteTotal(source, ["TOTAL_NM", "total_nm"]);
      var estimatedHours = firstFiniteRouteTotal(source, ["ESTIMATED_HOURS", "ESTIMATED_TIME_HOURS", "TOTAL_HOURS", "total_hours"]);
      var waypointCount = firstFiniteRouteTotal(source, ["WAYPOINT_COUNT", "TOTAL_WAYPOINTS", "waypoint_count", "waypointCount"]);
      var locks = firstFiniteRouteTotal(source, ["TOTAL_LOCKS", "LOCK_COUNT", "lock_count"]);
      var startLabel = endpoints.START_LABEL !== undefined && endpoints.START_LABEL !== null ? String(endpoints.START_LABEL).trim() : "";
      var endLabel = endpoints.END_LABEL !== undefined && endpoints.END_LABEL !== null ? String(endpoints.END_LABEL).trim() : "";
      var hasDefaultVessel = source.HAS_DEFAULT_VESSEL === true || source.HAS_DEFAULT_VESSEL === 1 || source.HAS_DEFAULT_VESSEL === "1";
      var fuelLabel = source.FUEL_ESTIMATE_LABEL !== undefined && source.FUEL_ESTIMATE_LABEL !== null
        ? String(source.FUEL_ESTIMATE_LABEL).trim()
        : "";
      if (!fuelLabel) {
        fuelLabel = hasDefaultVessel ? "Fuel estimate unavailable" : "Requires default vessel";
      }
      if (!startLabel) startLabel = "Start unavailable";
      if (!endLabel) endLabel = "End unavailable";
      return ""
        + '<div class="fpw-route-summary-list fpw-route-summary-compact" aria-label="Route summary">'
        + '  <div class="fpw-route-summary-row fpw-route-summary-row--points">'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--distance"><span class="fpw-route-summary-icon fpw-route-summary-icon--distance" aria-hidden="true"></span><div class="fpw-route-summary-copy"><span class="fpw-route-summary-label">Distance nautical mile</span><strong class="fpw-route-summary-value">' + formatNumber(distanceNm, 1) + ' NM</strong></div></div>'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--endpoints"><span class="fpw-route-summary-icon fpw-route-summary-icon--endpoints" aria-hidden="true"></span><div class="fpw-route-summary-copy fpw-route-summary-copy--point"><span class="fpw-route-summary-label">Start point</span><strong class="fpw-route-summary-value">' + escapeHtml(startLabel) + '</strong></div><div class="fpw-route-summary-copy fpw-route-summary-copy--point"><span class="fpw-route-summary-label">End point</span><strong class="fpw-route-summary-value">' + escapeHtml(endLabel) + '</strong></div></div>'
        + '  </div>'
        + '  <div class="fpw-route-summary-row fpw-route-summary-row--time-locks">'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--time"><span class="fpw-route-summary-icon fpw-route-summary-icon--time" aria-hidden="true"></span><div class="fpw-route-summary-copy"><span class="fpw-route-summary-label">Estimated time to complete</span><strong class="fpw-route-summary-value">' + (estimatedHours > 0 ? formatNumber(estimatedHours, 1) + ' hrs' : 'Unavailable') + '</strong></div></div>'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--locks"><span class="fpw-route-summary-icon fpw-route-summary-icon--locks" aria-hidden="true"></span><div class="fpw-route-summary-copy"><span class="fpw-route-summary-label">Number of locks</span><strong class="fpw-route-summary-value">' + formatNumber(locks, 0) + '</strong></div></div>'
        + '  </div>'
        + '  <div class="fpw-route-summary-row fpw-route-summary-row--fuel-waypoints">'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--fuel"><span class="fpw-route-summary-icon fpw-route-summary-icon--fuel" aria-hidden="true"></span><div class="fpw-route-summary-copy"><span class="fpw-route-summary-label">Estimated fuel needed</span><strong class="fpw-route-summary-value">' + escapeHtml(fuelLabel) + '</strong></div></div>'
        + '    <div class="fpw-route-summary-cell fpw-route-summary-cell--waypoints"><span class="fpw-route-summary-icon fpw-route-summary-icon--waypoints" aria-hidden="true"></span><div class="fpw-route-summary-copy"><span class="fpw-route-summary-label">Number of waypoints</span><strong class="fpw-route-summary-value">' + formatNumber(waypointCount, 0) + '</strong></div></div>'
        + '  </div>'
        + '</div>';
    }

    function buildSavedRouteReadiness() {
      var vesselCount = getSetupCount("vessels");
      var contactCount = getSetupCount("contacts");
      return ""
        + '<div class="fpw-route-readiness">'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--plan" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Float Plan</span><strong class="fpw-text-warning">Not attached</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--vessel" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Vessel</span><strong data-fpw-route-setup-count="vessels" class="' + (vesselCount > 0 ? 'fpw-text-success' : 'fpw-text-muted') + '">' + (vesselCount > 0 ? formatNumber(vesselCount, 0) + ' saved' : 'setup pending') + '</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--contacts" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Contacts</span><strong data-fpw-route-setup-count="contacts" class="' + (contactCount > 0 ? 'fpw-text-success' : 'fpw-text-muted') + '">' + formatNumber(contactCount, 0) + ' saved</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--fuel" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Fuel estimate</span><strong class="fpw-text-muted">pending</strong></div></div>'
        + '</div>';
    }

    function buildActiveRouteReadiness(route, currentGroup) {
      var routeName = route && route.NAME ? String(route.NAME) : "Active route";
      var weatherText = dashboardSignals && dashboardSignals.weather && dashboardSignals.weather.summary
        ? dashboardSignals.weather.summary
        : "Forecast unavailable";
      return ""
        + '<div class="fpw-route-readiness fpw-route-readiness--live">'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--current" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Current route</span><strong class="fpw-text-teal">' + escapeHtml(routeName) + '</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--checkin" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Last check-in</span><strong class="fpw-text-muted">unavailable</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--update" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Next expected update</span><strong class="fpw-text-muted">unavailable</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--weather" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Weather</span><strong class="fpw-text-warning">' + escapeHtml(weatherText) + '</strong></div></div>'
        + '  <div class="fpw-route-readiness__item"><span class="fpw-route-readiness__icon fpw-route-readiness__icon--fuel" aria-hidden="true"></span><div><span class="fpw-route-readiness__label">Fuel range</span><strong class="fpw-text-muted">pending</strong></div></div>'
        + '</div>';
    }

    function buildRouteThumbnail(isActive, pct, nm) {
      var safePct = Math.round(clamp(pct, 0, 100));
      var safeNm = Number.isFinite(parseFloat(nm)) ? parseFloat(nm) : 0;
      var modifier = isActive ? ' fpw-route-thumbnail--active' : '';
      var label = isActive ? '<span class="fpw-route-thumbnail__label">Current leg</span>' : '';
      return ""
        + '<aside class="fpw-route-thumbnail' + modifier + '" aria-label="Route preview">'
        + label
        + '  <svg class="fpw-route-thumbnail__svg" viewBox="0 0 420 260" role="img" aria-label="Abstract route preview">'
        + '    <rect x="0" y="0" width="420" height="260" class="fpw-thumb-grid"></rect>'
        + '    <circle cx="210" cy="130" r="108" class="fpw-thumb-radar-ring"></circle>'
        + '    <circle cx="210" cy="130" r="72" class="fpw-thumb-radar-ring"></circle>'
        + '    <circle cx="210" cy="130" r="36" class="fpw-thumb-radar-ring"></circle>'
        + (isActive
          ? '    <path class="fpw-thumb-route fpw-thumb-route--complete" d="M 58 190 C 90 174, 112 166, 132 134 C 152 104, 164 94, 192 84 C 219 74, 240 70, 263 64"></path><path class="fpw-thumb-route fpw-thumb-route--remaining" d="M 263 64 C 306 62, 323 34, 360 28 C 374 26, 388 26, 402 28"></path><circle cx="263" cy="64" r="20" class="fpw-current-pulse"></circle><circle cx="263" cy="64" r="12" class="fpw-current-ring"></circle><circle cx="263" cy="64" r="6" class="fpw-current-dot"></circle><circle cx="58" cy="190" r="8" class="fpw-thumb-dot fpw-thumb-dot--start"></circle><circle cx="402" cy="28" r="8" class="fpw-thumb-dot fpw-thumb-dot--finish"></circle>'
          : '    <path class="fpw-thumb-route fpw-thumb-route--complete" d="M 95 162 C 118 188, 148 198, 184 180 C 218 164, 232 170, 260 150 C 295 126, 328 126, 346 76 C 354 55, 365 42, 377 26"></path><path class="fpw-thumb-route fpw-thumb-route--remaining" d="M 95 162 C 126 152, 132 118, 154 102 C 184 78, 225 84, 248 42 C 278 34, 331 38, 377 26"></path><circle cx="95" cy="162" r="8" class="fpw-thumb-dot fpw-thumb-dot--start"></circle><circle cx="377" cy="26" r="8" class="fpw-thumb-dot fpw-thumb-dot--finish"></circle><g class="fpw-thumb-legend" transform="translate(28 194)"><circle cx="0" cy="0" r="5" class="fpw-thumb-dot--start"></circle><text x="14" y="5">Start</text><circle cx="0" cy="28" r="5" class="fpw-thumb-dot--finish"></circle><text x="14" y="33">Finish</text></g>')
        + '  </svg>'
        + (isActive ? '<div class="fpw-thumbnail-progress"><div class="fpw-thumbnail-progress__topline"><span class="fpw-thumbnail-progress__dial" aria-hidden="true" style="--fpw-progress:' + safePct + '%;"></span><span>' + safePct + '% complete • ' + formatNumber(safeNm, 1) + ' NM</span></div><div class="fpw-thumbnail-progress__bar" aria-hidden="true"><span style="width:' + safePct + '%;"></span></div></div>' : '')
        + '</aside>';
    }

    function renderNoActiveTrip(message) {
      var text = "Your routes, float plans, and trip setup are ready.";
      if (typeof message === "string" && message.trim()) {
        text = message.trim();
      } else if (message && typeof message === "object") {
        text = payloadMessage(message, text);
      }
      if (summaryEl) {
        summaryEl.textContent = text;
      }
      dashboardSignals.activeRoute = { name: "", isActive: false };
      setRouteSignals("No Active Trip", text, 0);
    }

    function renderActiveTripSummary(activeTrip) {
      var trip = activeTrip && typeof activeTrip === "object" ? activeTrip : {};
      var totals = trip && trip.TOTALS ? trip.TOTALS : {};
      var pct = Number.isFinite(parseFloat(totals.PCT_COMPLETE)) ? parseFloat(totals.PCT_COMPLETE) : 0;
      var routeName = trip.ROUTE_NAME || (trip.ROUTE && trip.ROUTE.NAME) || "Route";
      var tripName = trip.FLOATPLAN_NAME || routeName || "Active trip";
      var summaryText = routeName + " • " + buildRouteSummaryText(totals);

      if (trip.SUCCESS !== true) {
        renderNoActiveTrip(trip);
        return;
      }
      if (summaryEl) {
        summaryEl.textContent = summaryText;
      }
      dashboardSignals.activeRoute = { name: routeName, isActive: true };
      setRouteSignals(tripName, summaryText, pct);
    }

    function normalizeRouteCurrentGroup(route) {
      var group = route && route.CURRENT_GROUP && typeof route.CURRENT_GROUP === "object"
        ? route.CURRENT_GROUP
        : null;
      if (!group || !group.HAS_CURRENT_GROUP) {
        return null;
      }
      var planId = normalizePlanId(group.FLOATPLAN_ID !== undefined ? group.FLOATPLAN_ID : group.FLOATPLANID);
      if (planId <= 0) {
        return null;
      }
      return {
        floatPlanId: planId,
        floatPlanName: String(group.FLOATPLAN_NAME || group.FLOATPLANNAME || "").trim(),
        status: String(group.STATUS || "").trim().toUpperCase(),
        currentState: String(group.CURRENT_STATE || "").trim().toUpperCase(),
        isDraft: !!group.IS_DRAFT,
        isActive: !!group.IS_ACTIVE
      };
    }

    function firstRouteString(source, keys) {
      var obj = source && typeof source === "object" ? source : {};
      var value = "";
      for (var i = 0; i < keys.length; i += 1) {
        if (!Object.prototype.hasOwnProperty.call(obj, keys[i])) continue;
        if (obj[keys[i]] === undefined || obj[keys[i]] === null) continue;
        value = String(obj[keys[i]]).trim();
        if (value) return value;
      }
      return "";
    }

    function getRouteEndpoints(route) {
      var source = route && typeof route === "object" ? route : {};
      var endpoints = source.ROUTE_ENDPOINTS && typeof source.ROUTE_ENDPOINTS === "object" ? source.ROUTE_ENDPOINTS : {};
      return {
        start: firstRouteString(endpoints, ["START_LABEL", "startLabel", "start_label"]) || firstRouteString(source, ["START_LABEL", "START_POINT", "START_NAME", "START_WAYPOINT_NAME"]),
        end: firstRouteString(endpoints, ["END_LABEL", "endLabel", "end_label"]) || firstRouteString(source, ["END_LABEL", "END_POINT", "END_NAME", "END_WAYPOINT_NAME"])
      };
    }

    function getRouteTypeLabel(route) {
      var explicit = firstRouteString(route, ["ROUTE_TYPE", "TYPE", "routeType", "type"]);
      var description = firstRouteString(route, ["DESCRIPTION", "description"]);
      if (explicit) return explicit.charAt(0).toUpperCase() + explicit.slice(1).toLowerCase();
      if (firstRouteString(route, ["TEMPLATE_CODE", "ROUTE_TEMPLATE_CODE", "templateCode"])) return "Template";
      if (description && description.toLowerCase().indexOf("template") !== -1) return "Template";
      return "Custom";
    }

    function formatRouteUpdatedLabel(route) {
      var raw = firstRouteString(route, ["UPDATED_AT", "UPDATEDAT", "UPDATED", "LAST_UPDATED", "MODIFIED_AT", "CREATED_AT", "CREATEDAT"]);
      var parsed = null;
      if (!raw) return "—";
      parsed = new Date(raw);
      if (Number.isNaN(parsed.getTime())) return raw;
      return parsed.toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric"
      });
    }

    function getRouteStatusLabel(currentState, isRouteForActiveTrip) {
      if (currentState === "ACTIVE" || isRouteForActiveTrip) return "Active";
      if (currentState === "DRAFT") return "Draft";
      return "Saved";
    }

    function getRouteSummaryValues(route, totals) {
      var source = totals && typeof totals === "object" ? totals : {};
      var endpoints = getRouteEndpoints(route);
      var distanceNm = firstFiniteRouteTotal(source, ["TOTAL_NM", "total_nm"]);
      var estimatedHours = firstFiniteRouteTotal(source, ["ESTIMATED_HOURS", "ESTIMATED_TIME_HOURS", "TOTAL_HOURS", "total_hours"]);
      var waypointCount = firstFiniteRouteTotal(source, ["WAYPOINT_COUNT", "TOTAL_WAYPOINTS", "waypoint_count", "waypointCount"]);
      var locks = firstFiniteRouteTotal(source, ["TOTAL_LOCKS", "LOCK_COUNT", "lock_count"]);
      var hasDefaultVessel = source.HAS_DEFAULT_VESSEL === true || source.HAS_DEFAULT_VESSEL === 1 || source.HAS_DEFAULT_VESSEL === "1";
      var fuelLabel = source.FUEL_ESTIMATE_LABEL !== undefined && source.FUEL_ESTIMATE_LABEL !== null
        ? String(source.FUEL_ESTIMATE_LABEL).trim()
        : "";
      if (!fuelLabel) {
        fuelLabel = hasDefaultVessel ? "Fuel estimate unavailable" : "Requires default vessel";
      }
      return {
        distance: formatNumber(distanceNm, 1) + " NM",
        estimatedHours: estimatedHours > 0 ? formatNumber(estimatedHours, 1) + " hrs" : "Unavailable",
        waypoints: formatNumber(waypointCount, 0),
        locks: formatNumber(locks, 0),
        fuel: fuelLabel,
        start: endpoints.start || "Start unavailable",
        end: endpoints.end || "End unavailable"
      };
    }

    function buildRouteDataAttributes(route, routeInstanceId, currentState, currentRouteGroup) {
      var routeCode = route && route.SHORT_CODE ? String(route.SHORT_CODE) : "";
      var html = ' data-route-code="' + escapeHtml(routeCode) + '"';
      if (Number.isFinite(routeInstanceId) && routeInstanceId > 0) {
        html += ' data-route-instance-id="' + routeInstanceId + '"';
      }
      if (currentState) {
        html += ' data-current-group-state="' + escapeHtml(currentState) + '"';
      }
      if (currentRouteGroup) {
        html += ' data-current-floatplan-id="' + currentRouteGroup.floatPlanId + '"';
      }
      return html;
    }

    function buildActionContextOpen(currentGroup, extraClass) {
      if (!currentGroup) return "";
      return '<div class="expedition-route-current-group ' + escapeHtml(extraClass || "") + '" data-plan-id="' + currentGroup.floatPlanId + '" data-plan-status="' + escapeHtml(currentGroup.status) + '" data-current-state="' + escapeHtml(currentGroup.currentState) + '">';
    }

    function buildRouteTableActions(currentGroup, currentState, showActiveCruiseAction, showTripPageAction, showActivateRouteAction) {
      var html = buildActionContextOpen(currentGroup, "fpw-route-table-actions");
      if (!currentGroup) html += '<div class="fpw-route-table-actions">';
      if (currentState === "ACTIVE" && currentGroup) {
        html += showActiveCruiseAction ? '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--cruise js-expedition-active-cruise" aria-label="Open Active Cruise" title="Open Active Cruise"></button>' : "";
        html += showTripPageAction ? '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--follow js-expedition-trip-page" aria-label="Follow Page" title="Follow Page"></button>' : "";
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--edit-route js-expedition-view-edit" aria-label="Edit Route" title="Edit Route"></button>';
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--cancel js-expedition-plan-cancel" data-action="cancel" data-plan-id="' + currentGroup.floatPlanId + '" aria-label="Cancel" title="Cancel"></button>';
      } else if (currentGroup) {
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--send js-expedition-plan-view" data-action="view" data-plan-id="' + currentGroup.floatPlanId + '" aria-label="View and Send Float Plan" title="View & Send Float Plan"></button>';
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--edit-plan js-expedition-plan-edit" data-action="edit" data-plan-id="' + currentGroup.floatPlanId + '" aria-label="Edit Float Plan" title="Edit Float Plan"></button>';
        html += showActivateRouteAction ? '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--activate js-expedition-build-floatplans" aria-label="Activate Route" title="Activate Route"></button>' : "";
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--edit-route js-expedition-view-edit" aria-label="Edit Route" title="Edit Route"></button>';
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--delete js-expedition-delete" aria-label="Delete" title="Delete"></button>';
      } else {
        html += showActivateRouteAction ? '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--activate js-expedition-build-floatplans" aria-label="Activate Route" title="Activate Route"></button>' : "";
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--edit-route js-expedition-view-edit" aria-label="Edit Route" title="Edit Route"></button>';
        html += '<button type="button" class="fpw-route-icon-action fpw-route-icon-action--delete js-expedition-delete" aria-label="Delete" title="Delete"></button>';
      }
      html += '</div>';
      return html;
    }

    function buildRouteDetailActions(currentGroup, currentState, showActiveCruiseAction, showTripPageAction, showActivateRouteAction) {
      var html = buildActionContextOpen(currentGroup, "fpw-route-detail-actions");
      if (!currentGroup) html += '<div class="fpw-route-detail-actions">';
      if (currentState === "ACTIVE" && currentGroup) {
        html += showActiveCruiseAction ? '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--primary js-expedition-active-cruise">Open Active Cruise</button>' : "";
        html += '<button type="button" class="fpw-route-workspace-btn js-expedition-view-edit">Edit Route</button>';
        html += showTripPageAction ? '<button type="button" class="fpw-route-workspace-btn js-expedition-trip-page">Follow Page</button>' : "";
        html += '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--danger js-expedition-plan-cancel" data-action="cancel" data-plan-id="' + currentGroup.floatPlanId + '">Cancel</button>';
      } else if (currentGroup) {
        html += '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--primary js-expedition-plan-view" data-action="view" data-plan-id="' + currentGroup.floatPlanId + '">View &amp; Send Float Plan</button>';
        html += '<button type="button" class="fpw-route-workspace-btn js-expedition-plan-edit" data-action="edit" data-plan-id="' + currentGroup.floatPlanId + '">Edit Float Plan</button>';
        html += showActivateRouteAction ? '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--primary js-expedition-build-floatplans">Activate Route</button>' : "";
        html += '<button type="button" class="fpw-route-workspace-btn js-expedition-view-edit">Edit Route</button>';
        html += '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--danger js-expedition-delete">Delete</button>';
      } else {
        html += showActivateRouteAction ? '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--primary js-expedition-build-floatplans">Activate Route</button>' : "";
        html += '<button type="button" class="fpw-route-workspace-btn js-expedition-view-edit">Edit Route</button>';
        html += '<button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--danger js-expedition-delete">Delete</button>';
      }
      html += '</div>';
      return html;
    }

    function buildRouteDetailPreview(route, totals) {
      var summary = getRouteSummaryValues(route, totals);
      return ""
        + '<div class="fpw-route-detail-preview" aria-label="Route preview">'
        + '  <svg viewBox="0 0 420 210" role="img" aria-label="Display-only route preview">'
        + '    <rect x="0" y="0" width="420" height="210" class="fpw-route-preview-sea"></rect>'
        + '    <path d="M 45 150 C 110 190, 172 184, 220 158 C 278 126, 330 118, 382 56" class="fpw-route-preview-line"></path>'
        + '    <circle cx="45" cy="150" r="8" class="fpw-route-preview-point fpw-route-preview-point--start"></circle>'
        + '    <circle cx="382" cy="56" r="8" class="fpw-route-preview-point fpw-route-preview-point--end"></circle>'
        + '    <text x="60" y="154" class="fpw-route-preview-label">' + escapeHtml(summary.start) + '</text>'
        + '    <text x="255" y="52" class="fpw-route-preview-label">' + escapeHtml(summary.end) + '</text>'
        + '  </svg>'
        + '</div>';
    }

    function buildRouteStatusText(currentState, isRouteForActiveTrip) {
      var label = getRouteStatusLabel(currentState, isRouteForActiveTrip);
      var modifier = label.toLowerCase();
      return '<span class="fpw-route-status-text fpw-route-status-text--' + escapeHtml(modifier) + '">' + escapeHtml(label) + '</span>';
    }

    function buildActiveRouteSubRow(route, routeMeta) {
      var currentGroup = routeMeta.currentRouteGroup;
      var planId = currentGroup ? normalizePlanId(currentGroup.floatPlanId) : 0;
      var title = currentGroup && currentGroup.floatPlanName ? currentGroup.floatPlanName : "active float plan";
      if (!currentGroup || routeMeta.currentState !== "ACTIVE" || planId <= 0) {
        return "";
      }
      return ""
        + '<div class="expedition-route-card fpw-route-active-subrow"' + routeMeta.dataAttrs + '>'
        + '  <div class="fpw-route-active-subrow-copy">'
        + '    <strong>Float plan ready</strong>'
        + '    <a href="#" class="fpw-route-active-link js-expedition-download-pdf" data-plan-id="' + planId + '" aria-label="Download PDF Float Plan for ' + escapeHtml(title) + '">Download PDF Float Plan</a>'
        + '  </div>'
        + '  <button type="button" class="fpw-route-workspace-btn fpw-route-workspace-btn--primary fpw-route-share-btn js-expedition-share-follow" data-plan-id="' + planId + '">Share Follow Link</button>'
        + '</div>';
    }

    function buildRouteRow(route, routeMeta) {
      var totals = routeMeta.totals;
      var summary = getRouteSummaryValues(route, totals);
      var subtitle = buildRouteSubtitle(route, routeMeta.currentRouteGroup);
      return ""
        + '<div class="expedition-route-card fpw-routes-table-row' + (routeMeta.isSelected ? ' is-selected' : '') + (routeMeta.isRouteForActiveTrip ? ' is-active' : '') + '"' + routeMeta.dataAttrs + ' role="button" tabindex="0">'
        + '  <div class="fpw-route-cell fpw-route-cell--route"><span class="fpw-route-favorite" aria-hidden="true"></span><div><strong>' + escapeHtml(route.NAME || route.SHORT_CODE || "Route") + '</strong><span>' + escapeHtml(subtitle) + '</span></div></div>'
        + '  <div class="fpw-route-cell fpw-route-cell--points"><span>' + escapeHtml(summary.start) + '</span><span>' + escapeHtml(summary.end) + '</span></div>'
        + '  <div class="fpw-route-cell">' + escapeHtml(summary.distance) + '</div>'
        + '  <div class="fpw-route-cell fpw-route-cell--duration">' + escapeHtml(summary.estimatedHours) + '</div>'
        + '  <div class="fpw-route-cell">' + buildRouteStatusText(routeMeta.currentState, routeMeta.isRouteForActiveTrip) + '</div>'
        + '  <div class="fpw-route-cell fpw-route-cell--actions">' + buildRouteTableActions(routeMeta.currentRouteGroup, routeMeta.currentState, routeMeta.showActiveCruiseAction, routeMeta.showTripPageAction, routeMeta.showActivateRouteAction) + '</div>'
        + '</div>';
    }

    function buildSelectedRouteDetail(route, routeMeta) {
      var totals = routeMeta.totals;
      var summary = getRouteSummaryValues(route, totals);
      var typeLabel = getRouteTypeLabel(route);
      var subtitle = buildRouteSubtitle(route, routeMeta.currentRouteGroup);
      return ""
        + '<aside class="expedition-route-card fpw-route-detail-pane"' + routeMeta.dataAttrs + '>'
        + '  <div class="fpw-route-detail-status-row">' + buildRouteStatusText(routeMeta.currentState, routeMeta.isRouteForActiveTrip) + '<span class="fpw-route-detail-star" aria-hidden="true"></span></div>'
        + '  <h3>' + escapeHtml(route.NAME || route.SHORT_CODE || "Route") + '</h3>'
        + '  <span class="fpw-route-detail-type">' + escapeHtml(typeLabel) + '</span>'
        + '  <p>' + escapeHtml(subtitle) + '</p>'
        + '  <dl class="fpw-route-detail-facts">'
        + '    <div><dt>Start</dt><dd>' + escapeHtml(summary.start) + '</dd></div>'
        + '    <div><dt>Distance</dt><dd>' + escapeHtml(summary.distance) + '</dd></div>'
        + '    <div><dt>End</dt><dd>' + escapeHtml(summary.end) + '</dd></div>'
        + '    <div><dt>Waypoints</dt><dd>' + escapeHtml(summary.waypoints) + '</dd></div>'
        + '    <div><dt>Est. Duration</dt><dd>' + escapeHtml(summary.estimatedHours) + '</dd></div>'
        + '    <div><dt>Est. Fuel Needed</dt><dd>' + escapeHtml(summary.fuel) + '</dd></div>'
        + '  </dl>'
        +      buildRouteDetailPreview(route, totals)
        + '  <div class="fpw-route-detail-action-title">Route Actions</div>'
        +      buildRouteDetailActions(routeMeta.currentRouteGroup, routeMeta.currentState, routeMeta.showActiveCruiseAction, routeMeta.showTripPageAction, routeMeta.showActivateRouteAction)
        + '</aside>';
    }

    function buildCurrentGroupRow(route, pct) {
      var currentGroup = normalizeRouteCurrentGroup(route);
      if (!currentGroup) {
        return buildSavedRouteReadiness();
      }
      var title = currentGroup.floatPlanName || (currentGroup.currentState === "ACTIVE" ? "Active float plan" : "Draft float plan");
      if (currentGroup.currentState === "ACTIVE") {
        return buildActiveRouteReadiness(route, currentGroup, pct);
      }
      return ""
        + '<div class="fpw-route-floatplan-card" data-plan-id="' + currentGroup.floatPlanId + '" data-plan-status="' + escapeHtml(currentGroup.status) + '" data-current-state="' + escapeHtml(currentGroup.currentState) + '">'
        + '  <div class="fpw-route-floatplan-label">Draft Float Plan Attached</div>'
        + '  <h4>' + escapeHtml(title) + '</h4>'
        + '  <p>Saved in draft state. Send this float plan to activate the route.</p>'
        + '</div>';
    }

    function getRouteRenderMeta(route, activeCode) {
      var totals = route && route.TOTALS ? route.TOTALS : {};
      var currentRouteGroup = normalizeRouteCurrentGroup(route);
      var activeTripFloatPlanId = normalizeActiveFloatPlanId(state.activeTripFloatPlanId);
      var currentGroupFloatPlanId = currentRouteGroup
        ? normalizeActiveFloatPlanId(currentRouteGroup.floatPlanId)
        : 0;
      var isRouteForActiveTrip = (route && route.SHORT_CODE && activeCode && route.SHORT_CODE === activeCode)
        || (activeTripFloatPlanId > 0 && currentGroupFloatPlanId === activeTripFloatPlanId);
      var currentState = currentRouteGroup ? currentRouteGroup.currentState : "";
      var showActivateRouteAction = currentState !== "ACTIVE";
      var showActiveCruiseAction = activeTripFloatPlanId > 0 && !!isRouteForActiveTrip;
      var showTripPageAction = activeTripFloatPlanId > 0 && !!isRouteForActiveTrip;
      var routeInstanceId = route && route.ROUTE_INSTANCE_ID !== undefined && route.ROUTE_INSTANCE_ID !== null
        ? parseInt(route.ROUTE_INSTANCE_ID, 10)
        : (route && route.route_instance_id !== undefined && route.route_instance_id !== null
          ? parseInt(route.route_instance_id, 10)
          : 0);
      if (!Number.isFinite(routeInstanceId)) routeInstanceId = 0;
      return {
        totals: totals,
        isRouteForActiveTrip: !!isRouteForActiveTrip,
        currentRouteGroup: currentRouteGroup,
        currentState: currentState,
        showActivateRouteAction: showActivateRouteAction,
        showActiveCruiseAction: showActiveCruiseAction,
        showTripPageAction: showTripPageAction,
        dataAttrs: buildRouteDataAttributes(route, routeInstanceId, currentState, currentRouteGroup),
        routeInstanceId: routeInstanceId,
        isSelected: false
      };
    }

    function renderRouteList(routes, activeCode, currentGroupPayload) {
      if (!routeListEl) return;
      var list = Array.isArray(routes) ? routes.slice() : [];
      var activeTripRouteIndex = -1;
      var selectedRoute = null;
      activeTripRouteIndex = list.findIndex(function (route) {
        if (!route) return false;
        if (activeCode && route.SHORT_CODE && route.SHORT_CODE === activeCode) return true;
        var routeMeta = getRouteRenderMeta(route, activeCode);
        return routeMeta.isRouteForActiveTrip || routeMeta.currentState === "ACTIVE";
      });
      if (activeTripRouteIndex > 0) {
        list = [list[activeTripRouteIndex]]
          .concat(list.slice(0, activeTripRouteIndex))
          .concat(list.slice(activeTripRouteIndex + 1));
      }
      if (!list.length) {
        dashboardSignals.routes.total = 0;
        routeListEl.innerHTML = "";
        if (routeEmptyEl) toggleHidden(routeEmptyEl, false);
        refreshMissionSummary();
        renderRecommendedNextSteps();
        return;
      }
      dashboardSignals.routes.total = list.length;
      if (routeEmptyEl) toggleHidden(routeEmptyEl, true);
      selectedRoute = list.find(function (route) {
        return route && route.SHORT_CODE && route.SHORT_CODE === selectedRouteCode;
      });
      if (!selectedRoute && activeCode) {
        selectedRoute = list.find(function (route) {
          return route && route.SHORT_CODE && route.SHORT_CODE === activeCode;
        });
      }
      if (!selectedRoute) selectedRoute = list[0];
      selectedRouteCode = selectedRoute && selectedRoute.SHORT_CODE ? String(selectedRoute.SHORT_CODE) : "";
      routeListEl.innerHTML = ""
        + '<div class="fpw-route-workspace">'
        + '  <div class="fpw-routes-table-pane">'
        + '    <div class="fpw-routes-table" role="table" aria-label="Saved routes">'
        + '      <div class="fpw-routes-table-head" role="row">'
        + '        <div>Route Name</div><div>Start / End</div><div>Distance</div><div>Est. Duration</div><div>Status</div><div>Actions</div>'
        + '      </div>'
        + list.map(function (route) {
          var meta = getRouteRenderMeta(route, activeCode);
          meta.isSelected = !!(route && route.SHORT_CODE && route.SHORT_CODE === selectedRouteCode);
          return buildRouteRow(route, meta) + buildActiveRouteSubRow(route, meta);
        }).join("")
        + '    </div>'
        + '    <div class="fpw-routes-count">1-' + formatNumber(list.length, 0) + ' of ' + formatNumber(list.length, 0) + ' routes</div>'
        + '  </div>'
        +      buildSelectedRouteDetail(selectedRoute, getRouteRenderMeta(selectedRoute, activeCode))
        + '</div>';
      refreshMissionSummary();
      renderRecommendedNextSteps();
      updateCurrentDraftActionButtons();
    }

    function selectRoute(routeCode) {
      var routes = (state.routeState && Array.isArray(state.routeState.all)) ? state.routeState.all : [];
      selectedRouteCode = routeCode || "";
      renderRouteList(routes, state.activeTripRouteCode || "", state.currentRouteGroup || {});
    }

    function renderTimeline(data) {
      if (!accordionEl) return;
      // Keep dashboard panel condensed: route card only, no expandable rows.
      accordionEl.innerHTML = "";
      toggleHidden(accordionEl, true);
    }

    function openEditor(routeCode) {
      var rb = window.FPW && window.FPW.DashboardModules ? window.FPW.DashboardModules.routeBuilder : null;
      if (rb && typeof rb.openEditorForRoute === "function") {
        rb.openEditorForRoute(routeCode);
      }
    }

    function getFloatPlansModule() {
      return window.FPW && window.FPW.DashboardModules ? window.FPW.DashboardModules.floatplans : null;
    }

    function openCurrentGroupWizard(planId, startStep) {
      var floatPlansModule = getFloatPlansModule();
      if (!floatPlansModule || typeof floatPlansModule.openWizardForPlan !== "function") {
        return false;
      }
      return !!floatPlansModule.openWizardForPlan(planId, startStep);
    }

    function checkInCurrentGroup(planId, triggerButton) {
      var floatPlansModule = getFloatPlansModule();
      if (!floatPlansModule || typeof floatPlansModule.checkInFloatPlan !== "function") {
        return false;
      }
      floatPlansModule.checkInFloatPlan(planId, triggerButton);
      return true;
    }

    function cancelCurrentGroup(planId, triggerButton) {
      var floatPlansModule = getFloatPlansModule();
      if (!floatPlansModule || typeof floatPlansModule.cancelFloatPlan !== "function") {
        return false;
      }
      floatPlansModule.cancelFloatPlan(planId, triggerButton);
      return true;
    }

    function deleteRoute(routeCode) {
      if (!routeCode) return Promise.resolve();
      return fetchJson(routeBuilderUrl("deleteRoute", { routeCode: routeCode }))
        .then(function (payload) {
          if (!payload || payload.SUCCESS === false) {
            throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to delete route.");
          }
          return load();
        })
        .catch(function (err) {
          setState("error", (err && err.message) ? err.message : "Unable to delete route.");
        });
    }

    function requestBuildFloatPlans(routeCode, rebuild, routeInstanceId) {
      if (!routeCode) return Promise.resolve({ SUCCESS: false, MESSAGE: "routeCode is required." });
      var rid = parseInt(routeInstanceId, 10);
      var body = {
        routeCode: routeCode,
        mode: "SINGLE_MASTER",
        rebuild: rebuild ? 1 : 0
      };
      if (Number.isFinite(rid) && rid > 0) {
        body.routeInstanceId = rid;
      }
      return fetchJson(routeBuilderUrl("buildFloatPlansFromRoute"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify(body)
      });
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

    function getPayloadErrorCode(payload) {
      if (!payload || typeof payload !== "object") return "";
      if (payload.errorCode !== undefined && payload.errorCode !== null) {
        return String(payload.errorCode).trim().toUpperCase();
      }
      if (payload.ERROR && payload.ERROR.CODE !== undefined && payload.ERROR.CODE !== null) {
        return String(payload.ERROR.CODE).trim().toUpperCase();
      }
      if (payload.ERROR_CODE !== undefined && payload.ERROR_CODE !== null) {
        return String(payload.ERROR_CODE).trim().toUpperCase();
      }
      return "";
    }

    function isBasicRouteLibraryRestriction(payload) {
      return getPayloadErrorCode(payload) === "BASIC_SAVED_ROUTE_RESTRICTED";
    }

    function renderBasicRoutePanel(payload) {
      var basicModule = window.FPW && window.FPW.DashboardModules
        ? window.FPW.DashboardModules.basicFloatPlan
        : null;
      state.isBasicMember = true;
      state.activeTripFloatPlanId = 0;
      state.activeTripRouteCode = "";
      state.currentRouteGroup = { HAS_CURRENT_GROUP: false };
      state.routeState = state.routeState || {};
      state.routeState.all = [];
      state.floatPlanState = state.floatPlanState || { all: [], filtered: [], query: "" };
      state.floatPlanState.all = [];
      state.floatPlanState.filtered = [];
      dashboardSignals.routes.total = 0;
      dashboardSignals.activeRoute = { name: "", isActive: false };
      setRouteSignals(
        "Basic Float Plan",
        "Create a one-day Basic float plan without saving a reusable route.",
        0
      );
      if (summaryEl) {
        summaryEl.textContent = "Basic float-plan-first workspace";
      }
      if (routeEmptyEl) toggleHidden(routeEmptyEl, true);
      if (accordionEl) {
        accordionEl.innerHTML = "";
        toggleHidden(accordionEl, true);
      }
      if (basicModule && typeof basicModule.renderPanel === "function") {
        basicModule.renderPanel(routeListEl, payload);
      } else if (routeListEl) {
        routeListEl.innerHTML = ""
          + '<article class="fpw-basic-floatplan-panel">'
          + '  <div class="fpw-basic-floatplan-main">'
          + '    <span class="fpw-basic-kicker">Basic member flow</span>'
          + '    <h3>Basic Float Plan</h3>'
          + '    <p>Create a simple one-day float plan with up to 2 saved waypoints.</p>'
          + '    <button type="button" class="btn-primary" data-basic-floatplan-open>Create Basic Float Plan</button>'
          + '  </div>'
          + '</article>';
      }
      refreshMissionSummary();
      renderRecommendedNextSteps();
      updateCurrentDraftActionButtons();
    }

    function renderBasicAccessPanel(payload) {
      renderBasicRoutePanel(payload || {
        SUCCESS: false,
        ERROR: "BASIC_SAVED_ROUTE_RESTRICTED",
        errorCode: "BASIC_SAVED_ROUTE_RESTRICTED",
        MESSAGE: "Basic members use the Basic Float Plan flow."
      });
      setState("ready");
    }

    function normalizeFloatPlanId(value) {
      var planId = parseInt(value, 10);
      if (!Number.isFinite(planId) || planId <= 0) {
        return 0;
      }
      return planId;
    }

    function normalizePlanId(value) {
      return normalizeFloatPlanId(value);
    }

    function extractPlanIdsFromArray(values) {
      var list = Array.isArray(values) ? values : [];
      var ids = [];
      var i = 0;
      var planId = 0;
      for (i = 0; i < list.length; i += 1) {
        planId = normalizeFloatPlanId(list[i]);
        if (planId > 0) {
          ids.push(planId);
        }
      }
      return ids;
    }

    function extractPlanIdsFromObjects(entries) {
      var list = Array.isArray(entries) ? entries : [];
      var ids = [];
      var i = 0;
      var entry = null;
      var planId = 0;
      for (i = 0; i < list.length; i += 1) {
        entry = list[i] && typeof list[i] === "object" ? list[i] : null;
        if (!entry) continue;
        planId = normalizeFloatPlanId(entry.FLOATPLAN_ID !== undefined ? entry.FLOATPLAN_ID : entry.FLOATPLANID);
        if (planId > 0) {
          ids.push(planId);
        }
      }
      return ids;
    }

    function extractSingleCreatedFloatPlanId(payload) {
      var createdCount = Number.isFinite(parseInt(payload && payload.CREATED_COUNT, 10))
        ? parseInt(payload.CREATED_COUNT, 10)
        : 0;
      var planIds = [];

      if (createdCount !== 1) {
        throw new Error("Activate Route requires exactly one draft float plan.");
      }

      planIds = extractPlanIdsFromArray(payload && payload.FLOATPLAN_IDS);
      if (planIds.length > 1) {
        throw new Error("Activate Route expected one float plan id but received multiple.");
      }
      if (planIds.length === 1) {
        return planIds[0];
      }

      planIds = extractPlanIdsFromObjects(payload && payload.FLOATPLANS);
      if (planIds.length > 1) {
        throw new Error("Activate Route expected one float plan id but received multiple.");
      }
      if (planIds.length === 1) {
        return planIds[0];
      }

      throw new Error("The created float plan id is unavailable.");
    }

    function notifyFloatPlansUpdated(routeCode, routeInstanceId, createdCount) {
      if (document && typeof window.CustomEvent === "function") {
        document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated", {
          detail: {
            routeCode: routeCode,
            routeInstanceId: routeInstanceId || 0,
            createdCount: createdCount || 0
          }
        }));
      }
    }

    function openCreatedFloatPlanWizard(planId) {
      var floatPlansModule = window.FPW && window.FPW.DashboardModules ? window.FPW.DashboardModules.floatplans : null;
      if (!floatPlansModule || typeof floatPlansModule.openWizardForPlan !== "function") {
        return false;
      }
      return !!floatPlansModule.openWizardForPlan(planId, 1);
    }


    function buildFloatPlans(routeCode, triggerButton, routeInstanceId) {
      if (!routeCode) return Promise.resolve();
      var originalText = "";
      var rid = parseInt(routeInstanceId, 10);
      if (!Number.isFinite(rid)) {
        rid = 0;
      }
      if (triggerButton) {
        originalText = triggerButton.textContent;
        triggerButton.disabled = true;
        triggerButton.textContent = "Building...";
      }

      return requestBuildFloatPlans(routeCode, false, rid)
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
              return requestBuildFloatPlans(routeCode, true, rid);
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
          var createdPlanId = 0;
          var wizardOpened = false;
          try {
            createdPlanId = extractSingleCreatedFloatPlanId(payload);
          } catch (planErr) {
            if (createdCount > 0) {
              notifyFloatPlansUpdated(routeCode, payload.ROUTE_INSTANCE_ID || 0, createdCount);
            }
            throw planErr;
          }
          wizardOpened = openCreatedFloatPlanWizard(createdPlanId);
          if (!wizardOpened) {
            notifyFloatPlansUpdated(routeCode, payload.ROUTE_INSTANCE_ID || 0, createdCount);
            throw new Error("Draft float plan was created, but the wizard could not be opened.");
          }
          if (createdCount > 0 && !(payload && payload.REUSED_EXISTING) && window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
            window.FPWAnalytics.track("float_plan_created", {
              created_count: createdCount,
              plan_type: "premium_route",
              source: "route_activation"
            });
          }
          if (utils && typeof utils.showDashboardAlert === "function") {
            var successMessage = payload && payload.REUSED_EXISTING
              ? "Opened the existing draft route/float-plan group."
              : ("Created " + createdCount + " draft route/float-plan group" + (createdCount === 1 ? "" : "s") + " from route.");
            utils.showDashboardAlert(
              successMessage,
              "success"
            );
          }
          notifyFloatPlansUpdated(routeCode, payload.ROUTE_INSTANCE_ID || 0, createdCount);
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
            triggerButton.textContent = originalText || "Activate Route";
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
            return response.json()
              .then(function (payload) {
                if (isBasicRouteLibraryRestriction(payload)) {
                  return payload;
                }
                var authErr = new Error("Unauthorized");
                authErr.code = "UNAUTHORIZED";
                authErr.payload = payload;
                throw authErr;
              })
              .catch(function (err) {
                if (err && err.code === "UNAUTHORIZED") {
                  throw err;
                }
                var authErr = new Error("Unauthorized");
                authErr.code = "UNAUTHORIZED";
                throw authErr;
              });
          }
          return response.json();
        });
    }

    function normalizeActiveFloatPlanId(value) {
      var planId = parseInt(value, 10);
      if (!Number.isFinite(planId) || planId <= 0) {
        return 0;
      }
      return planId;
    }

    function resolveFollowTarget(payload) {
      var data = payload && typeof payload === "object"
        ? ((payload.data && typeof payload.data === "object")
          ? payload.data
          : ((payload.DATA && typeof payload.DATA === "object") ? payload.DATA : null))
        : null;
      var follow = data && data.follow && typeof data.follow === "object"
        ? data.follow
        : null;
      if (!follow) return "";
      if (follow.url !== undefined && follow.url !== null && follow.url !== "") {
        return String(follow.url);
      }
      if (follow.path !== undefined && follow.path !== null && follow.path !== "") {
        return String(follow.path);
      }
      return "";
    }

    function buildGeneratedFloatPlanPdfUrl(fileName) {
      var safeName = String(fileName || "").trim();
      if (!safeName) return "";
      return BASE_PATH + "/api/api_assets/floatPlans/user_float_plans/" + encodeURIComponent(safeName) + "?t=" + encodeURIComponent(Date.now());
    }

    function triggerPdfDownload(url) {
      var link = document.createElement("a");
      link.href = url;
      link.target = "_blank";
      link.rel = "noopener";
      link.download = "";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }

    function setActionBusy(actionEl, isBusy, busyText) {
      if (!actionEl) return;
      if (isBusy) {
        if (!actionEl.dataset.originalText) {
          actionEl.dataset.originalText = actionEl.textContent || "";
        }
        actionEl.setAttribute("aria-busy", "true");
        actionEl.classList.add("is-loading");
        if (busyText) actionEl.textContent = busyText;
        return;
      }
      actionEl.removeAttribute("aria-busy");
      actionEl.classList.remove("is-loading");
      if (actionEl.dataset.originalText) {
        actionEl.textContent = actionEl.dataset.originalText;
        delete actionEl.dataset.originalText;
      }
    }

    function openCurrentFloatPlanPdf(planId, actionEl) {
      var id = normalizePlanId(planId);
      if (id <= 0 || !window.Api || typeof window.Api.createFloatPlanPdf !== "function") {
        if (utils && typeof utils.showAlertModal === "function") {
          utils.showAlertModal("Unable to generate float plan PDF.");
        } else {
          window.alert("Unable to generate float plan PDF.");
        }
        return;
      }
      setActionBusy(actionEl, true, "Preparing PDF...");
      window.Api.createFloatPlanPdf(id)
        .then(function (fileName) {
          var pdfUrl = buildGeneratedFloatPlanPdfUrl(fileName);
          if (!pdfUrl) {
            throw { MESSAGE: "Unable to generate float plan PDF." };
          }
          triggerPdfDownload(pdfUrl);
        })
        .catch(function (err) {
          var message = (err && err.MESSAGE) ? err.MESSAGE : "Unable to generate float plan PDF.";
          if (utils && typeof utils.showAlertModal === "function") {
            utils.showAlertModal(message);
          } else {
            window.alert(message);
          }
        })
        .then(function () {
          setActionBusy(actionEl, false);
        });
    }

    function normalizeFollowShareUrl(url) {
      var value = String(url || "").trim();
      if (!value) return "";
      if (/^https?:\/\//i.test(value)) return value;
      if (value.charAt(0) === "/") return window.location.origin + value;
      return value;
    }

    function buildSmsHref(followUrl) {
      return "sms:?&body=" + encodeURIComponent("Follow our trip: " + followUrl);
    }

    function setFollowShareStatus(message) {
      if (followShareStatusEl) {
        followShareStatusEl.textContent = message || "";
      }
    }

    function ensureFollowShareModal() {
      if (!followShareModalEl) {
        followShareModalEl = document.getElementById("followShareModal");
        if (followShareModalEl) {
          followShareUrlEl = document.getElementById("followShareUrl");
          followShareOpenLink = document.getElementById("followShareOpenLink");
          followShareSmsLink = document.getElementById("followShareSmsLink");
          followShareCopyBtn = document.getElementById("followShareCopyBtn");
          followShareStatusEl = document.getElementById("followShareStatus");
        }
      }
      if (followShareModalEl && !followShareModal && window.bootstrap && window.bootstrap.Modal) {
        followShareModal = new window.bootstrap.Modal(followShareModalEl);
      }
      if (followShareCopyBtn && !followShareCopyBtn.dataset.listenersAttached) {
        followShareCopyBtn.addEventListener("click", function () {
          var url = followShareUrlEl ? String(followShareUrlEl.value || "").trim() : "";
          if (!url) return;
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(url).then(function () {
              setFollowShareStatus("Follow link copied.");
            }).catch(function () {
              window.prompt("Copy this link:", url);
            });
            return;
          }
          window.prompt("Copy this link:", url);
        });
        followShareCopyBtn.dataset.listenersAttached = "true";
      }
    }

    function showFollowShareModal(followUrl) {
      var url = normalizeFollowShareUrl(followUrl);
      if (!url) return;
      ensureFollowShareModal();
      if (followShareUrlEl) followShareUrlEl.value = url;
      if (followShareOpenLink) followShareOpenLink.href = url;
      if (followShareSmsLink) followShareSmsLink.href = buildSmsHref(url);
      setFollowShareStatus("");
      if (followShareModalEl && followShareModal) {
        followShareModalEl.style.zIndex = "2000";
        followShareModal.show();
        window.setTimeout(function () {
          var backdrops = document.querySelectorAll(".modal-backdrop");
          if (backdrops.length) {
            backdrops[backdrops.length - 1].style.zIndex = "1990";
          }
        }, 0);
        return;
      }
      window.prompt("Copy this link:", url);
    }

    function openFollowShare(actionEl) {
      setActionBusy(actionEl, true, "Loading...");
      return fetchJson(voyageUrl("ownerEnsureStream"))
        .then(function (payload) {
          var followTarget = "";
          if (!payload || payload.SUCCESS === false || payload.success === false) {
            throw { MESSAGE: "Unable to load Follow page link." };
          }
          followTarget = resolveFollowTarget(payload);
          if (!followTarget) {
            throw { MESSAGE: "Unable to load Follow page link." };
          }
          showFollowShareModal(followTarget);
          if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
            window.FPWAnalytics.track("follow_page_shared", {
              source: "dashboard_share_button"
            });
          }
        })
        .catch(function (err) {
          var message = (err && err.MESSAGE) ? err.MESSAGE : "Unable to load Follow page link.";
          if (utils && typeof utils.showAlertModal === "function") {
            utils.showAlertModal(message);
          } else {
            window.alert(message);
          }
        })
        .then(function () {
          setActionBusy(actionEl, false);
        });
    }

    function openTripPage() {
      var popup = null;
      try {
        popup = window.open("", "_blank");
      } catch (err) {
        popup = null;
      }
      return fetchJson(voyageUrl("ownerEnsureStream"))
        .then(function (payload) {
          var followTarget = "";
          if (!payload || payload.SUCCESS === false || payload.success === false) {
            if (popup && !popup.closed) {
              popup.close();
            }
            return "";
          }
          followTarget = resolveFollowTarget(payload);
          if (!followTarget) {
            if (popup && !popup.closed) {
              popup.close();
            }
            return "";
          }
          if (popup && !popup.closed) {
            popup.opener = null;
            popup.location = followTarget;
            return followTarget;
          }
          window.open(followTarget, "_blank", "noopener");
          return followTarget;
        })
        .catch(function () {
          if (popup && !popup.closed) {
            try {
              popup.close();
            } catch (err) {
              // Ignore popup cleanup issues; the dashboard itself should remain unchanged.
            }
          }
          return "";
        });
    }

    function load() {
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
            if (isBasicRouteLibraryRestriction(routesPayload)) {
              renderBasicRoutePanel(routesPayload);
              setState("ready");
              return null;
            }
            throw new Error((routesPayload && routesPayload.MESSAGE) ? routesPayload.MESSAGE : "Unable to load routes.");
          }
          state.isBasicMember = false;
          if (modules.basicFloatPlan && typeof modules.basicFloatPlan.setBasicMode === "function") {
            modules.basicFloatPlan.setBasicMode(false);
          }
          var routes = Array.isArray(routesPayload.ROUTES) ? routesPayload.ROUTES : [];
          var currentGroup = (routesPayload.CURRENT_GROUP && typeof routesPayload.CURRENT_GROUP === "object")
            ? routesPayload.CURRENT_GROUP
            : { HAS_CURRENT_GROUP: false };
          var activeTrip = (routesPayload.ACTIVE_TRIP && typeof routesPayload.ACTIVE_TRIP === "object")
            ? routesPayload.ACTIVE_TRIP
            : {};
          var activeTripFloatPlanId = (activeTrip.SUCCESS === true)
            ? normalizeActiveFloatPlanId(activeTrip.FLOATPLAN_ID !== undefined ? activeTrip.FLOATPLAN_ID : activeTrip.FLOATPLANID)
            : 0;
          var activeTripRouteCode = (activeTrip.SUCCESS === true && activeTrip.ROUTE_CODE)
            ? String(activeTrip.ROUTE_CODE)
            : "";

          state.activeTripFloatPlanId = activeTripFloatPlanId;
          state.activeTripRouteCode = activeTripRouteCode;
          state.currentRouteGroup = currentGroup;
          state.routeState = state.routeState || {};
          state.routeState.all = routes.slice();
          state.floatPlanState = state.floatPlanState || { all: [], filtered: [], query: "" };
          state.floatPlanState.all = currentGroup.HAS_CURRENT_GROUP ? [{
            FLOATPLANID: normalizePlanId(currentGroup.FLOATPLAN_ID !== undefined ? currentGroup.FLOATPLAN_ID : currentGroup.FLOATPLANID),
            PLANNAME: String(currentGroup.FLOATPLAN_NAME || ""),
            STATUS: String(currentGroup.STATUS || "")
          }] : [];
          state.floatPlanState.filtered = state.floatPlanState.all.slice();
          if (document && typeof window.CustomEvent === "function") {
            document.dispatchEvent(new window.CustomEvent("fpw:active-trip-updated", {
              detail: {
                floatPlanId: activeTripFloatPlanId
              }
            }));
          }

          if (!routes.length) {
            renderEmptyRoutes();
          } else {
            renderRouteList(routes, activeTripRouteCode, currentGroup);
          }

          renderActiveTripSummary(activeTrip);
          renderTimeline();
          refreshDerivedSignalsFromState();
          setState("ready");
          return null;
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
      collapseToggleBtn = document.getElementById("toggleRoutesPanelBtn");
      ensureRoutesPanelCollapseControls();
      summaryEl = document.getElementById("expeditionTimelineSummary");
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
      if (collapseToggleBtn) {
        collapseToggleBtn.addEventListener("click", function () {
          setRoutesPanelCollapsed(!panel.classList.contains("is-collapsed"));
        });
        setRoutesPanelCollapsed(panel.classList.contains("is-collapsed"));
      }
      if (routeListEl) {
        routeListEl.addEventListener("click", function (event) {
          var target = event.target;
          if (!target) return;
          var card = target.closest(".expedition-route-card");
          var currentGroupRow = target.closest(".expedition-route-current-group");
          var currentGroupState = card ? String(card.getAttribute("data-current-group-state") || "").trim().toUpperCase() : "";
          var currentFloatPlanId = card ? normalizePlanId(card.getAttribute("data-current-floatplan-id")) : 0;
          var currentGroupPlanId = currentGroupRow ? normalizePlanId(currentGroupRow.getAttribute("data-plan-id")) : 0;
          var deleteMessage = "Delete this route?";
          if (!card) return;
          var routeCode = card.getAttribute("data-route-code");
          var routeInstanceId = parseInt(card.getAttribute("data-route-instance-id") || "0", 10);
          if (!Number.isFinite(routeInstanceId)) routeInstanceId = 0;
          if (!routeCode) return;
          var pdfAction = target.closest(".js-expedition-download-pdf");
          var shareFollowAction = target.closest(".js-expedition-share-follow");
          if (pdfAction) {
            event.preventDefault();
            openCurrentFloatPlanPdf(normalizePlanId(pdfAction.getAttribute("data-plan-id")) || currentFloatPlanId, pdfAction);
            return;
          }
          if (shareFollowAction) {
            event.preventDefault();
            openFollowShare(shareFollowAction);
            return;
          }
          if (!target.closest("button") && card.classList.contains("fpw-routes-table-row")) {
            selectRoute(routeCode);
            return;
          }
          if (target.classList.contains("js-expedition-active-cruise")) {
            window.open(BASE_PATH + "/app/active-cruise.cfm", "_blank", "noopener");
            return;
          }
          if (target.classList.contains("js-expedition-trip-page")) {
            openTripPage();
            return;
          }
          if (target.classList.contains("js-expedition-view-edit")) {
            openEditor(routeCode);
            return;
          }
          if (target.classList.contains("js-expedition-build-floatplans")) {
            buildFloatPlans(routeCode, target, routeInstanceId);
            return;
          }
          if (target.classList.contains("js-expedition-plan-view")) {
            openCurrentGroupWizard(currentGroupPlanId, 6);
            return;
          }
          if (target.classList.contains("js-expedition-plan-edit")) {
            openCurrentGroupWizard(currentGroupPlanId, 1);
            return;
          }
          if (target.classList.contains("js-expedition-plan-checkin")) {
            if (utils && typeof utils.showConfirmModal === "function") {
              utils.showConfirmModal("Check in this active route/float-plan group?")
                .then(function (confirmed) {
                  if (!confirmed) return;
                  checkInCurrentGroup(currentGroupPlanId, target);
                });
            } else if (window.confirm("Check in this active route/float-plan group?")) {
              checkInCurrentGroup(currentGroupPlanId, target);
            }
            return;
          }
          if (target.classList.contains("js-expedition-plan-cancel")) {
            if (utils && typeof utils.showConfirmModal === "function") {
              utils.showConfirmModal("Cancel this active route/float-plan group? This ends the active trip without requiring all legs to be complete first.")
                .then(function (confirmed) {
                  if (!confirmed) return;
                  cancelCurrentGroup(currentGroupPlanId, target);
                });
            } else if (window.confirm("Cancel this active route/float-plan group? This ends the active trip without requiring all legs to be complete first.")) {
              cancelCurrentGroup(currentGroupPlanId, target);
            }
            return;
          }
          if (target.classList.contains("js-expedition-delete")) {
            var confirmDelete = function () {
              deleteRoute(routeCode);
            };
            if (currentGroupState === "ACTIVE" && currentFloatPlanId > 0) {
              if (utils && typeof utils.showAlertModal === "function") {
                utils.showAlertModal("This route has the current active route/float-plan group. Use Check-In or Cancel before deleting the route.");
              } else {
                window.alert("This route has the current active route/float-plan group. Use Check-In or Cancel before deleting the route.");
              }
              return;
            }
            if (currentGroupState === "DRAFT" && currentFloatPlanId > 0) {
              deleteMessage = "Delete this draft route/float-plan group? This deletes both the route and its draft float plan.";
            } else {
              deleteMessage = "Delete this route? Any attached float plan history for this route will also be deleted.";
            }
            if (utils && typeof utils.showConfirmModal === "function") {
              utils.showConfirmModal(deleteMessage)
                .then(function (confirmed) {
                  if (!confirmed) return;
                  confirmDelete();
                });
            } else {
              if (!window.confirm(deleteMessage)) return;
              confirmDelete();
            }
            return;
          }
        });
      }
      document.addEventListener("fpw:routes-updated", function (event) {
        if (state.isBasicMember) {
          renderBasicAccessPanel();
          return;
        }
        load();
      });
      document.addEventListener("fpw:floatplans-updated", function () {
        if (state.isBasicMember) {
          renderBasicAccessPanel();
          return;
        }
        load();
      });
    }

    return {
      init: init,
      load: load,
      renderBasicPanel: renderBasicAccessPanel
    };
})();
  window.FPW.DashboardModules = modules;

  function resolveMemberAccess(payload) {
    if (!payload || typeof payload !== "object") {
      return null;
    }
    if (payload.ACCESS && typeof payload.ACCESS === "object") {
      return payload.ACCESS;
    }
    if (payload.access && typeof payload.access === "object") {
      return payload.access;
    }
    return null;
  }

  function hasPremiumMemberAccess(access) {
    var value = access && Object.prototype.hasOwnProperty.call(access, "hasPremium")
      ? access.hasPremium
      : (access && Object.prototype.hasOwnProperty.call(access, "HASPREMIUM") ? access.HASPREMIUM : false);
    if (value === true || value === 1) {
      return true;
    }
    return String(value).trim().toLowerCase() === "true" || String(value).trim() === "1";
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
    bindQuickActions();
    bindWeatherPreviewActions();
    bindNextStepsActions();
    bindRouteStatusActions();
    renderRouteStatusPanel();
    refreshMissionSummary();
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
    if (modules.basicFloatPlan && modules.basicFloatPlan.init) {
      modules.basicFloatPlan.init();
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

    (Api.getCurrentMemberAccess ? Api.getCurrentMemberAccess() : Api.getCurrentUser())
      .then(function (data) {
        var user = data && (data.USER || data.user);
        var memberAccess = resolveMemberAccess(data);
        var hasPremium = memberAccess ? hasPremiumMemberAccess(memberAccess) : null;

        // data.SUCCESS already checked in Api.request
        if (utils.ensureAuthResponse && !utils.ensureAuthResponse(data)) {
          return;
        }

        if (!user) {
          redirectToLogin();
          return;
        }

        populateUserInfo(user);
        state.currentUser = user;
        state.memberAccess = memberAccess;
        if (utils.resolveHomePortLatLng) {
          state.homePortLatLng = utils.resolveHomePortLatLng(user);
        }
        var homePortZip = "";
        if (utils.resolveHomePortZip) {
          homePortZip = utils.resolveHomePortZip(user);
        }
        initWeatherPanel(homePortZip, state.homePortLatLng || null);

        if (memberAccess && hasPremium === false && modules.expeditionTimeline && typeof modules.expeditionTimeline.renderBasicPanel === "function") {
          modules.expeditionTimeline.renderBasicPanel({
            SUCCESS: false,
            ERROR: "BASIC_SAVED_ROUTE_RESTRICTED",
            errorCode: "BASIC_SAVED_ROUTE_RESTRICTED",
            MESSAGE: "Basic members use the Basic Float Plan flow.",
            ACCESS: memberAccess,
            access: memberAccess
          });
        } else if (modules.expeditionTimeline && typeof modules.expeditionTimeline.load === "function") {
          modules.expeditionTimeline.load();
        }

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

    bindLogoutButton();
  }

  function bindLogoutButton() {
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
  document.addEventListener("DOMContentLoaded", function () {
    initDashboard();
  });
})(window, document);
