(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var BASE_PATH = window.FPW_BASE || "";

  var PACE_PRESETS = [
    { key: "RELAXED", label: "Relaxed", factor: 0.25 },
    { key: "BALANCED", label: "Balanced", factor: 0.50 },
    { key: "AGGRESSIVE", label: "Aggressive", factor: 1.00 }
  ];
  var DEFAULT_MAX_SPEED_KN = 20;
  var DEFAULT_WEATHER_FACTOR_PCT = 0;
  var DEFAULT_RESERVE_PCT = 20;
  var FUEL_BURN_BASIS_MAX = "MAX_SPEED";

  var dom = {};
  var modal = null;

  var state = {
    templates: [],
    activeTemplateCode: "",
    activeTemplateIsLoop: true,
    options: {
      startOptions: [],
      endOptions: [],
      optionalStops: []
    },
    selectedStopCodes: {},
    userId: "",
    userIdPromise: null,
    optionReqSeq: 0,
    previewReqSeq: 0,
    previewTimer: 0,
    manualOverrides: {
      cruisingSpeed: false
    },
    freshStartSession: false,
    modalMode: "generator",
    pendingDraft: null,
    lastGeneratedRouteCode: "",
    activeRouteCode: "",
    modalInitSeq: 0,
    editorBaseline: null,
    suppressAutoSelectOnce: false
  };

  function isActiveModalInit(seq) {
    return seq === state.modalInitSeq;
  }

  function invalidateAsyncResponses() {
    state.optionReqSeq += 1;
    state.previewReqSeq += 1;
  }

  function escapeHtml(value) {
    if (utils.escapeHtml) return utils.escapeHtml(value);
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
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

  function formatCurrency(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "--";
    return "$" + n.toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }

  function coerceBool(value, fallback) {
    if (value === true || value === false) return value;
    if (value === 1 || value === "1") return true;
    if (value === 0 || value === "0") return false;
    var text = String(value === undefined || value === null ? "" : value).trim().toLowerCase();
    if (!text) return !!fallback;
    if (text === "true" || text === "yes" || text === "y" || text === "on") return true;
    if (text === "false" || text === "no" || text === "n" || text === "off") return false;
    return !!fallback;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = (BASE_PATH || "") + "/index.cfm";
  }

  function authError(message) {
    var err = new Error(message || "Unauthorized");
    err.code = "UNAUTHORIZED";
    return err;
  }

  function apiUrl(action, params) {
    var query = "method=handle&action=" + encodeURIComponent(action) + "&returnFormat=json";
    var k;
    params = params || {};
    for (k in params) {
      if (!Object.prototype.hasOwnProperty.call(params, k)) continue;
      if (params[k] === undefined || params[k] === null || params[k] === "") continue;
      query += "&" + encodeURIComponent(k) + "=" + encodeURIComponent(params[k]);
    }
    return BASE_PATH + "/api/v1/routeBuilder.cfc?" + query;
  }

  function fetchJson(url, options) {
    var fetchOptions = options || {};
    if (!Object.prototype.hasOwnProperty.call(fetchOptions, "credentials")) {
      fetchOptions.credentials = "same-origin";
    }

    return fetch(url, fetchOptions)
      .then(function (res) {
        if (res.status === 401 || res.status === 403) {
          throw authError("Unauthorized");
        }
        return res.text();
      })
      .then(function (txt) {
        var payload = {};
        try {
          payload = txt ? JSON.parse(txt) : {};
        } catch (e) {
          var parseErr = new Error("Non-JSON response from API.");
          parseErr.code = "BAD_JSON";
          throw parseErr;
        }
        if (payload && payload.AUTH === false) {
          throw authError("Unauthorized");
        }
        return payload;
      });
  }

  function setStatus(message) {
    if (!dom.statusEl) return;
    dom.statusEl.textContent = message || "";
  }

  function showError(message) {
    if (!dom.errorEl) return;
    dom.errorEl.textContent = message || "";
    dom.errorEl.classList.remove("d-none");
  }

  function clearError() {
    if (!dom.errorEl) return;
    dom.errorEl.textContent = "";
    dom.errorEl.classList.add("d-none");
  }

  function setRouteCodeBadge(routeCode) {
    if (!dom.routeCodeEl) return;
    dom.routeCodeEl.textContent = routeCode ? routeCode : "Draft";
  }

  function setModalModeUI() {
    var isEditor = state.modalMode === "editor";
    if (dom.generateBtn) dom.generateBtn.classList.toggle("d-none", isEditor);
    if (dom.saveBtn) dom.saveBtn.classList.toggle("d-none", !isEditor);
    if (dom.resetBtn) dom.resetBtn.textContent = isEditor ? "Reset to Saved" : "Reset";
    if (dom.hintLineEl) {
      dom.hintLineEl.textContent = isEditor
        ? "Editing existing route: Preview updates, then Save Route to update this route."
        : "Recommended flow: Preview -> Generate Route -> Build Float Plans from dashboard.";
    }
  }

  function notifyRoutesUpdated(routeCode) {
    if (!document || typeof window.CustomEvent !== "function") return;
    document.dispatchEvent(new window.CustomEvent("fpw:routes-updated", {
      detail: { routeCode: routeCode || "" }
    }));
  }

  function normalizeDirection(value) {
    return String(value || "").toUpperCase() === "CW" ? "CW" : "CCW";
  }

  function getDirectionValue() {
    if (dom.directionEl && dom.directionEl.value !== undefined && dom.directionEl.value !== null && dom.directionEl.value !== "") {
      return normalizeDirection(dom.directionEl.value);
    }
    if (dom.directionToggleEl) {
      return dom.directionToggleEl.checked ? "CW" : "CCW";
    }
    return "CCW";
  }

  function setDirectionValue(value) {
    var normalized = normalizeDirection(value);
    if (dom.directionEl) {
      dom.directionEl.value = normalized;
    }
    if (dom.directionToggleEl) {
      dom.directionToggleEl.checked = (normalized === "CW");
    }
    if (dom.directionStateEl) {
      dom.directionStateEl.textContent = (normalized === "CW")
        ? "Clockwise (CW)"
        : "Counterclockwise (CCW)";
    }
  }

  function hasLocationSelections() {
    var startVal = dom.startSelectEl ? String(dom.startSelectEl.value || "").trim() : "";
    var endVal = dom.endSelectEl ? String(dom.endSelectEl.value || "").trim() : "";
    return !!(startVal && endVal);
  }

  function updateDirectionControlAvailability() {
    var enabled = hasLocationSelections();
    if (dom.directionToggleEl) dom.directionToggleEl.disabled = !enabled;
    if (dom.directionEl) dom.directionEl.disabled = !enabled;
  }

  function getSelectedPaceIndex() {
    if (!dom.paceEl) return 0;
    var idx = parseInt(dom.paceEl.value, 10);
    if (!Number.isFinite(idx) || idx < 0) return 0;
    if (idx > 2) return 2;
    return idx;
  }

  function getSelectedPacePreset() {
    return PACE_PRESETS[getSelectedPaceIndex()] || PACE_PRESETS[0];
  }

  function getPaceIndexByKey(paceKey) {
    var key = String(paceKey || "").toUpperCase();
    var i;
    for (i = 0; i < PACE_PRESETS.length; i += 1) {
      if (PACE_PRESETS[i].key === key) return i;
    }
    return 0;
  }

  function updatePaceLabel() {
    if (!dom.paceLabelEl) return;
    var preset = getSelectedPacePreset();
    var percent = Math.round((Number.isFinite(preset.factor) ? preset.factor : 1) * 100);
    dom.paceLabelEl.textContent = preset.label + " (" + percent + "%)";
  }

  function getMaxSpeedKn() {
    var value = parseFloat(dom.cruisingSpeedEl ? dom.cruisingSpeedEl.value : "");
    if (!Number.isFinite(value) || value <= 0) {
      value = DEFAULT_MAX_SPEED_KN;
    }
    return value;
  }

  function getEffectiveCruisingSpeed() {
    var preset = getSelectedPacePreset();
    var factor = Number.isFinite(preset.factor) ? preset.factor : 1;
    var speed = getMaxSpeedKn() * factor;
    if (!Number.isFinite(speed) || speed <= 0) speed = DEFAULT_MAX_SPEED_KN;
    return Math.round(speed * 10) / 10;
  }

  function applyPaceDefaults(force) {
    if (dom.cruisingSpeedEl && (force || !String(dom.cruisingSpeedEl.value || "").trim().length)) {
      dom.cruisingSpeedEl.value = String(DEFAULT_MAX_SPEED_KN);
    }
  }

  function updatePaceOverrideUI() {
    if (dom.paceOverrideHintEl) dom.paceOverrideHintEl.classList.add("d-none");
    if (dom.resetPaceBtn) dom.resetPaceBtn.classList.add("d-none");
  }

  function roundTo2(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return 0;
    return Math.round(n * 100) / 100;
  }

  function normalizeFuelBurnBasis(value) {
    // Burn basis is locked to max speed in dev.
    return FUEL_BURN_BASIS_MAX;
  }

  function getFuelBurnBasis() {
    return FUEL_BURN_BASIS_MAX;
  }

  function setFuelBurnBasis(value) {
    var normalized = normalizeFuelBurnBasis(value);
    if (dom.fuelBurnBasisEl) {
      dom.fuelBurnBasisEl.value = normalized;
    }
    return normalized;
  }

  function getFuelBurnInputGph() {
    var burnVal = parseFloat(dom.fuelBurnGphEl ? dom.fuelBurnGphEl.value : "");
    if (!Number.isFinite(burnVal) || burnVal <= 0) return 0;
    if (burnVal > 1000) burnVal = 1000;
    return roundTo2(burnVal);
  }

  function getWeatherFactorPct() {
    var pct = parseFloat(dom.weatherFactorPctEl ? dom.weatherFactorPctEl.value : "");
    if (!Number.isFinite(pct) || pct < 0) return 0;
    if (pct > 60) pct = 60;
    return roundTo2(pct);
  }

  function getFuelBurnModelValues() {
    var inputBurn = getFuelBurnInputGph();
    var pace = getSelectedPacePreset();
    var paceRatio = Number.isFinite(pace.factor) ? pace.factor : 1;
    if (paceRatio < 0.05) paceRatio = 0.05;
    if (paceRatio > 1) paceRatio = 1;
    var pacePow = Math.pow(paceRatio, 3);
    var weatherPct = getWeatherFactorPct();
    var weatherAdj = weatherPct / 100;
    var maxSpeedBurn = 0;
    var paceAdjustedBurn = 0;
    var weatherAdjustedBurn = 0;

    if (inputBurn > 0) {
      maxSpeedBurn = inputBurn;
      if (!Number.isFinite(maxSpeedBurn) || maxSpeedBurn < 0) maxSpeedBurn = 0;
      if (maxSpeedBurn > 1000) maxSpeedBurn = 1000;
      maxSpeedBurn = roundTo2(maxSpeedBurn);

      paceAdjustedBurn = roundTo2(maxSpeedBurn * pacePow);
      weatherAdjustedBurn = roundTo2(paceAdjustedBurn * (1 + weatherAdj));
    }

    return {
      basis: FUEL_BURN_BASIS_MAX,
      inputBurn: roundTo2(inputBurn),
      maxSpeedBurn: maxSpeedBurn,
      paceAdjustedBurn: roundTo2(paceAdjustedBurn),
      weatherAdjustedBurn: roundTo2(weatherAdjustedBurn)
    };
  }

  function updateFuelBurnBasisUI() {
    var model = getFuelBurnModelValues();

    if (dom.fuelBurnLabelEl) {
      dom.fuelBurnLabelEl.textContent = "Fuel burn at max speed (GPH)";
    }
    if (dom.fuelBurnHintEl) {
      dom.fuelBurnHintEl.textContent = "FPW derives pace and weather adjusted burn from max speed burn.";
    }
    if (dom.fuelBurnDerivedEl) {
      if (model.inputBurn <= 0) {
        dom.fuelBurnDerivedEl.textContent = "Derived burn at current pace + weather: -- GPH";
      } else {
        dom.fuelBurnDerivedEl.textContent =
          "Derived burn at current pace + weather: " + formatNumber(model.weatherAdjustedBurn, 2) + " GPH.";
      }
    }
  }

  function getUserScope() {
    return state.userId ? String(state.userId) : "anon";
  }

  function draftKey(templateCode) {
    return "fpw:routegen:draft:" + getUserScope() + ":" + String(templateCode || "none");
  }

  function templateMemoryKey() {
    return "fpw:routegen:last-template:" + getUserScope();
  }

  function saveTemplateMemory(templateCode) {
    try {
      window.localStorage.setItem(templateMemoryKey(), String(templateCode || ""));
    } catch (e) {
      // no-op
    }
  }

  function readTemplateMemory() {
    try {
      return String(window.localStorage.getItem(templateMemoryKey()) || "").trim();
    } catch (e) {
      return "";
    }
  }

  function readDraft(templateCode) {
    var key = draftKey(templateCode);
    try {
      var raw = window.localStorage.getItem(key);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object") return null;
      return parsed;
    } catch (e) {
      return null;
    }
  }

  function saveDraft() {
    if (!state.activeTemplateCode) return;
    var payload = {
      template_code: state.activeTemplateCode,
      direction: getDirectionValue(),
      start_segment_id: dom.startSelectEl ? String(dom.startSelectEl.value || "") : "",
      end_segment_id: dom.endSelectEl ? String(dom.endSelectEl.value || "") : "",
      start_date: dom.startDateEl ? String(dom.startDateEl.value || "") : "",
      pace: getSelectedPacePreset().key,
      pace_index: getSelectedPaceIndex(),
      cruising_speed: String(getMaxSpeedKn()),
      effective_cruising_speed: String(getEffectiveCruisingSpeed()),
      underway_hours_per_day: dom.underwayHoursEl ? String(dom.underwayHoursEl.value || "") : "8",
      comfort_profile: dom.comfortProfileEl ? String(dom.comfortProfileEl.value || "") : "",
      overnight_bias: dom.overnightBiasEl ? String(dom.overnightBiasEl.value || "") : "",
      fuel_burn_gph: dom.fuelBurnGphEl ? String(dom.fuelBurnGphEl.value || "") : "",
      fuel_burn_gph_input: dom.fuelBurnGphEl ? String(dom.fuelBurnGphEl.value || "") : "",
      fuel_burn_basis: getFuelBurnBasis(),
      idle_burn_gph: dom.idleBurnGphEl ? String(dom.idleBurnGphEl.value || "") : "",
      idle_hours_total: dom.idleHoursTotalEl ? String(dom.idleHoursTotalEl.value || "") : "",
      weather_factor_pct: dom.weatherFactorPctEl ? String(dom.weatherFactorPctEl.value || "") : String(DEFAULT_WEATHER_FACTOR_PCT),
      reserve_pct: dom.reservePctEl ? String(dom.reservePctEl.value || "") : String(DEFAULT_RESERVE_PCT),
      fuel_price_per_gal: dom.fuelPricePerGalEl ? String(dom.fuelPricePerGalEl.value || "") : "",
      optional_stop_flags: Object.keys(state.selectedStopCodes).filter(function (code) {
        return !!state.selectedStopCodes[code];
      }),
      overrides: {
        cruisingSpeed: !!state.manualOverrides.cruisingSpeed
      }
    };
    try {
      window.localStorage.setItem(draftKey(state.activeTemplateCode), JSON.stringify(payload));
    } catch (e) {
      // no-op
    }
  }

  function applyDraftToForm(draft) {
    if (!draft) return;

    if (dom.startDateEl && draft.start_date) {
      dom.startDateEl.value = String(draft.start_date);
    }
    if (draft.direction) {
      setDirectionValue(draft.direction);
    }

    if (dom.paceEl && draft.pace_index !== undefined && draft.pace_index !== null && draft.pace_index !== "") {
      var idx = parseInt(draft.pace_index, 10);
      if (Number.isFinite(idx) && idx >= 0 && idx <= 2) {
        dom.paceEl.value = String(idx);
      }
    }

    state.manualOverrides.cruisingSpeed = !!(draft.overrides && draft.overrides.cruisingSpeed);

    applyPaceDefaults(false);

    if (dom.cruisingSpeedEl && draft.cruising_speed !== undefined && draft.cruising_speed !== null && draft.cruising_speed !== "") {
      dom.cruisingSpeedEl.value = String(draft.cruising_speed);
    }
    if (dom.underwayHoursEl && draft.underway_hours_per_day !== undefined && draft.underway_hours_per_day !== null && draft.underway_hours_per_day !== "") {
      dom.underwayHoursEl.value = String(draft.underway_hours_per_day);
    }
    if (dom.comfortProfileEl && draft.comfort_profile) {
      dom.comfortProfileEl.value = String(draft.comfort_profile);
    }
    if (dom.overnightBiasEl && draft.overnight_bias) {
      dom.overnightBiasEl.value = String(draft.overnight_bias);
    }
    setFuelBurnBasis(FUEL_BURN_BASIS_MAX);
    if (
      dom.fuelBurnGphEl &&
      (draft.fuel_burn_gph !== undefined && draft.fuel_burn_gph !== null)
    ) {
      dom.fuelBurnGphEl.value = String(draft.fuel_burn_gph);
    }
    if (dom.idleBurnGphEl && draft.idle_burn_gph !== undefined && draft.idle_burn_gph !== null) {
      dom.idleBurnGphEl.value = String(draft.idle_burn_gph || "");
    }
    if (dom.idleHoursTotalEl && draft.idle_hours_total !== undefined && draft.idle_hours_total !== null) {
      dom.idleHoursTotalEl.value = String(draft.idle_hours_total || "");
    }
    if (dom.weatherFactorPctEl && draft.weather_factor_pct !== undefined && draft.weather_factor_pct !== null) {
      dom.weatherFactorPctEl.value = String(draft.weather_factor_pct || DEFAULT_WEATHER_FACTOR_PCT);
    }
    if (dom.reservePctEl && draft.reserve_pct !== undefined && draft.reserve_pct !== null) {
      dom.reservePctEl.value = String(draft.reserve_pct || DEFAULT_RESERVE_PCT);
    }
    if (dom.fuelPricePerGalEl && draft.fuel_price_per_gal !== undefined && draft.fuel_price_per_gal !== null) {
      dom.fuelPricePerGalEl.value = String(draft.fuel_price_per_gal || "");
    }

    state.selectedStopCodes = {};
    if (Array.isArray(draft.optional_stop_flags)) {
      draft.optional_stop_flags.forEach(function (code) {
        state.selectedStopCodes[String(code)] = true;
      });
    }

    state.pendingDraft = draft;
    updatePaceLabel();
    updatePaceOverrideUI();
    updateFuelBurnBasisUI();
  }

  function clearPreview() {
    if (dom.totalNmEl) dom.totalNmEl.innerHTML = "0 <small>NM</small>";
    if (dom.estimatedDaysEl) dom.estimatedDaysEl.textContent = "0";
    if (dom.estimatedDaysSubEl) dom.estimatedDaysSubEl.textContent = "Pace-driven estimate";
    if (dom.lockCountEl) dom.lockCountEl.textContent = "0";
    if (dom.offshoreCountEl) dom.offshoreCountEl.textContent = "0";
    if (dom.estimatedFuelEl) dom.estimatedFuelEl.innerHTML = "-- <small>gal</small>";
    if (dom.estimatedFuelSubEl) dom.estimatedFuelSubEl.textContent = "Required = base + reserve";
    if (dom.fuelCostEl) dom.fuelCostEl.innerHTML = "-- <small>USD</small>";
    if (dom.fuelCostSubEl) dom.fuelCostSubEl.textContent = "Required fuel x price";
    if (dom.legCountEl) dom.legCountEl.textContent = "0 legs";
    if (dom.legListEl) dom.legListEl.innerHTML = '<div class="fpw-routegen__empty">Pick template/start/end to see a live preview.</div>';
  }

  function getTemplateByCode(code) {
    var target = String(code || "").trim();
    var i;
    for (i = 0; i < state.templates.length; i += 1) {
      var t = state.templates[i] || {};
      if (String(t.SHORT_CODE || t.CODE || "").trim() === target) {
        return t;
      }
    }
    return null;
  }

  function getTemplateDisplayName(template) {
    if (!template) return "-";
    var name = String(template.NAME || "").trim();
    var shortCode = String(template.SHORT_CODE || template.CODE || "").trim();
    return name || shortCode || "Template";
  }

  function getTemplateValue(template) {
    return String(template && (template.SHORT_CODE || template.CODE) ? (template.SHORT_CODE || template.CODE) : "").trim();
  }

  function getTemplateOptionLabel(template, nameCounts) {
    var baseName = getTemplateDisplayName(template);
    var key = baseName.toLowerCase();
    var shortCode = String(template && (template.SHORT_CODE || template.CODE) ? (template.SHORT_CODE || template.CODE) : "").trim();
    if (nameCounts && nameCounts[key] > 1 && shortCode) {
      return baseName + " [" + shortCode + "]";
    }
    return baseName;
  }

  function updateTemplateMeta(template) {
    if (!dom.templateMetaEl) return;
    if (!template) {
      dom.templateMetaEl.textContent = "";
      return;
    }
    var description = String(template.DESCRIPTION || "").trim();
    dom.templateMetaEl.textContent = description || "";
  }

  function renderTemplateSelect() {
    if (!dom.templateSelectEl) return;
    if (!state.templates.length) {
      dom.templateSelectEl.innerHTML = '<option value="">No templates available</option>';
      dom.templateSelectEl.value = "";
      dom.templateSelectEl.disabled = true;
      updateTemplateMeta(null);
      return;
    }

    var nameCounts = {};
    state.templates.forEach(function (template) {
      var key = getTemplateDisplayName(template).toLowerCase();
      nameCounts[key] = (nameCounts[key] || 0) + 1;
    });

    var options = ['<option value="">Select template</option>'];
    state.templates.forEach(function (template) {
      var value = getTemplateValue(template);
      if (!value) return;
      var label = getTemplateOptionLabel(template, nameCounts);
      options.push(
        '<option value="' + escapeHtml(value) + '" title="' + escapeHtml(getTemplateDisplayName(template)) + '">'
        + escapeHtml(label)
        + '</option>'
      );
    });

    dom.templateSelectEl.innerHTML = options.join("");
    dom.templateSelectEl.disabled = false;
    if (state.activeTemplateCode) {
      dom.templateSelectEl.value = state.activeTemplateCode;
    }
    if (state.activeTemplateCode && dom.templateSelectEl.value !== state.activeTemplateCode) {
      dom.templateSelectEl.value = "";
    }
  }

  function getSelectedOptionMeta(list, selectedValue) {
    var target = String(selectedValue || "").trim();
    if (!target || !Array.isArray(list)) return null;
    var i;
    for (i = 0; i < list.length; i += 1) {
      var row = list[i] || {};
      var rowValue = String(
        row.value !== undefined ? row.value :
          (row.SEGMENT_ID !== undefined ? row.SEGMENT_ID : (row.segment_id !== undefined ? row.segment_id : ""))
      ).trim();
      if (rowValue === target) {
        return row;
      }
    }
    return null;
  }

  function optionOrderIndex(row) {
    var idx = parseInt(
      row && row.order_index !== undefined ? row.order_index :
        (row && row.ORDER_INDEX !== undefined ? row.ORDER_INDEX : 0),
      10
    );
    return Number.isFinite(idx) ? idx : 0;
  }

  function optionLabelText(row) {
    return String(
      row && row.label !== undefined ? row.label :
        (row && row.LABEL !== undefined ? row.LABEL : "")
    ).trim();
  }

  function optionSegmentId(row) {
    return String(
      row && row.value !== undefined ? row.value :
        (row && row.SEGMENT_ID !== undefined ? row.SEGMENT_ID : (row && row.segment_id !== undefined ? row.segment_id : ""))
    ).trim();
  }

  function optionLabelKey(row) {
    return optionLabelText(row).toLowerCase();
  }

  function findOptionByLabel(list, label) {
    var target = String(label || "").trim().toLowerCase();
    if (!target || !Array.isArray(list)) return null;
    var i;
    for (i = 0; i < list.length; i += 1) {
      if (optionLabelKey(list[i]) === target) {
        return list[i];
      }
    }
    return null;
  }

  function resolveSelectionSegmentId(list, preferredSegmentId, preferredLabel) {
    var byId = getSelectedOptionMeta(list, preferredSegmentId);
    if (byId) return optionSegmentId(byId);

    var byLabel = findOptionByLabel(list, preferredLabel);
    if (byLabel) return optionSegmentId(byLabel);

    return "";
  }

  function uniqueStartOptionsForDisplay(list) {
    var rows = Array.isArray(list) ? list : [];
    var chosen = {};
    var i;
    var row;
    var key;
    var existing;

    for (i = 0; i < rows.length; i += 1) {
      row = rows[i] || {};
      key = optionLabelKey(row);
      if (!key) continue;
      existing = chosen[key];
      // Prefer earliest occurrence for start selection (e.g. Chicago => Leg 1).
      if (!existing || optionOrderIndex(row) < optionOrderIndex(existing)) {
        chosen[key] = row;
      }
    }

    return Object.keys(chosen)
      .map(function (k) { return chosen[k]; })
      .sort(function (a, b) {
        return optionOrderIndex(a) - optionOrderIndex(b);
      });
  }

  function uniqueEndOptionsForDisplay(list, selectedStartSegmentId, selectedStartMeta, allowWrap) {
    var rows = Array.isArray(list) ? list : [];
    var chosen = {};
    var i;
    var row;
    var key;
    var existing;
    var n = rows.length;
    var startSegId = String(selectedStartSegmentId || "").trim();
    var startOrder = 0;
    var canWrap = !!allowWrap;

    for (i = 0; i < rows.length; i += 1) {
      row = rows[i] || {};
      if (optionSegmentId(row) === startSegId) {
        startOrder = optionOrderIndex(row);
        break;
      }
    }

    function forwardDistance(targetOrder) {
      if (!startOrder || !n) return targetOrder;
      if (targetOrder >= startOrder) return targetOrder - startOrder;
      return (n - startOrder) + targetOrder;
    }

    function isNonWrapOrder(targetOrder) {
      if (!startOrder) return true;
      return targetOrder >= startOrder;
    }

    for (i = 0; i < rows.length; i += 1) {
      row = rows[i] || {};
      if (!canWrap && startOrder > 0 && optionOrderIndex(row) < startOrder) {
        continue;
      }
      key = optionLabelKey(row);
      if (!key) continue;
      existing = chosen[key];
      if (!existing) {
        chosen[key] = row;
        continue;
      }

      var rowOrder = optionOrderIndex(row);
      var existingOrder = optionOrderIndex(existing);
      var rowNonWrap = isNonWrapOrder(rowOrder);
      var existingNonWrap = isNonWrapOrder(existingOrder);
      var rowDist = forwardDistance(rowOrder);
      var existingDist = forwardDistance(existingOrder);

      // For loops, keep furthest duplicate to preserve wrap behavior.
      // For non-loop templates, keep nearest valid duplicate to avoid over-extending routes.
      if (
        (rowNonWrap && !existingNonWrap) ||
        (
          rowNonWrap === existingNonWrap
          && (
            (canWrap && (rowDist > existingDist || (rowDist === existingDist && rowOrder > existingOrder)))
            || (!canWrap && (rowDist < existingDist || (rowDist === existingDist && rowOrder < existingOrder)))
          )
        )
      ) {
        chosen[key] = row;
      }
    }

    var startKey = "";
    if (selectedStartMeta && typeof selectedStartMeta === "object") {
      startKey = optionLabelKey(selectedStartMeta);
    }

    var out = Object.keys(chosen)
      .map(function (k) { return chosen[k]; })
      .sort(function (a, b) {
        var aKey = optionLabelKey(a);
        var bKey = optionLabelKey(b);
        if (startKey && aKey === startKey && bKey !== startKey) return -1;
        if (startKey && bKey === startKey && aKey !== startKey) return 1;

        var aDist = forwardDistance(optionOrderIndex(a));
        var bDist = forwardDistance(optionOrderIndex(b));
        if (aDist !== bDist) return aDist - bDist;
        return optionOrderIndex(a) - optionOrderIndex(b);
      });

    for (i = 0; i < out.length; i += 1) {
      out[i] = Object.assign({}, out[i], {
        display_order: i + 1
      });
    }

    return out;
  }

  function renderSelect(selectEl, list, placeholder, selectedValue) {
    if (!selectEl) return;
    var desired = String(selectedValue || "").trim();
    var options = ['<option value="">' + escapeHtml(placeholder || "Select") + '</option>'];

    (Array.isArray(list) ? list : []).forEach(function (row) {
      var value = String(
        row && row.value !== undefined ? row.value :
          (row && row.SEGMENT_ID !== undefined ? row.SEGMENT_ID : (row && row.segment_id !== undefined ? row.segment_id : ""))
      ).trim();
      if (!value) return;

      var label = String(
        row && row.label !== undefined ? row.label :
          (row && row.LABEL !== undefined ? row.LABEL : "")
      ).trim();
      var hint = String(
        row && row.hint !== undefined ? row.hint :
          (row && row.HINT !== undefined ? row.HINT : "")
      ).trim();
      var orderIndex = parseInt(
        row && row.display_order !== undefined ? row.display_order :
          (row && row.DISPLAY_ORDER !== undefined ? row.DISPLAY_ORDER :
            (row && row.order_index !== undefined ? row.order_index :
              (row && row.ORDER_INDEX !== undefined ? row.ORDER_INDEX : 0))),
        10
      );

      var text = label || value;
      if (Number.isFinite(orderIndex) && orderIndex > 0) {
        text = "Leg " + orderIndex + " - " + text;
      }

      options.push(
        '<option value="' + escapeHtml(value) + '"' + (hint ? ' title="' + escapeHtml(hint) + '"' : '') + '>'
        + escapeHtml(text)
        + '</option>'
      );
    });

    selectEl.innerHTML = options.join("");
    selectEl.value = desired;
    if (desired && selectEl.value !== desired) {
      selectEl.value = "";
    }
  }

  function renderOptionalStops() {
    if (!dom.optionalStopsEl) return;

    var list = Array.isArray(state.options.optionalStops) ? state.options.optionalStops : [];
    if (!list.length) {
      dom.optionalStopsEl.innerHTML = '<div class="fpw-routegen__empty">No optional stops available for this template.</div>';
      return;
    }

    dom.optionalStopsEl.innerHTML = list.map(function (stop) {
      var code = String(stop.code || stop.CODE || "").trim();
      var name = String(stop.name || stop.NAME || code || "Optional stop");
      var description = String(stop.description || stop.DESCRIPTION || "").trim();
      var deltaNm = parseFloat(stop.delta_nm !== undefined ? stop.delta_nm : stop.DELTA_NM);
      var deltaDays = parseFloat(stop.delta_days !== undefined ? stop.delta_days : stop.DELTA_DAYS);
      var offshoreDelta = parseInt(stop.offshore_leg_delta !== undefined ? stop.offshore_leg_delta : stop.OFFSHORE_LEG_DELTA, 10);
      var selected = !!state.selectedStopCodes[code];

      var chips = [];
      if (Number.isFinite(deltaDays) && deltaDays > 0) chips.push("+~" + deltaDays + " day" + (deltaDays === 1 ? "" : "s"));
      if (Number.isFinite(deltaNm) && deltaNm > 0) chips.push("+~" + formatNumber(deltaNm, 0) + " NM");
      if (Number.isFinite(offshoreDelta) && offshoreDelta > 0) chips.push("Offshore +" + offshoreDelta);

      return ''
        + '<div class="fpw-routegen__stop">'
        + '  <div class="fpw-routegen__stopinfo">'
        + '    <div class="fpw-routegen__stopname">' + escapeHtml(name) + '</div>'
        + '    <div class="fpw-routegen__stopdesc">' + escapeHtml(description || chips.join(" - ") || "Optional detour") + '</div>'
        + '  </div>'
        + '  <button type="button" class="fpw-routegen__stoptoggle ' + (selected ? 'is-on' : '') + '" data-stop-code="' + escapeHtml(code) + '" aria-pressed="' + (selected ? 'true' : 'false') + '">'
        +      (selected ? 'On' : 'Off')
        + '  </button>'
        + '</div>';
    }).join("");
  }

  function renderOptions() {
    var selectedStart = dom.startSelectEl ? String(dom.startSelectEl.value || "") : "";
    var selectedEnd = dom.endSelectEl ? String(dom.endSelectEl.value || "") : "";
    var startDisplayOptions = uniqueStartOptionsForDisplay(state.options.startOptions);
    var i = 0;
    var selectedStartExists = false;
    var selectedEndExists = false;
    var suppressAutoSelectOnce = !!state.suppressAutoSelectOnce;
    var allowAutoSelect = !(state.modalMode === "generator" && state.freshStartSession) && !suppressAutoSelectOnce;
    var pendingStartLabel = "";
    var pendingEndLabel = "";

    if (state.pendingDraft) {
      if (state.pendingDraft.start_segment_id !== undefined && state.pendingDraft.start_segment_id !== null && state.pendingDraft.start_segment_id !== "") {
        selectedStart = String(state.pendingDraft.start_segment_id);
      }
      if (state.pendingDraft.end_segment_id !== undefined && state.pendingDraft.end_segment_id !== null && state.pendingDraft.end_segment_id !== "") {
        selectedEnd = String(state.pendingDraft.end_segment_id);
      }
      if (state.pendingDraft.start_label !== undefined && state.pendingDraft.start_label !== null) {
        pendingStartLabel = String(state.pendingDraft.start_label || "").trim();
      }
      if (state.pendingDraft.end_label !== undefined && state.pendingDraft.end_label !== null) {
        pendingEndLabel = String(state.pendingDraft.end_label || "").trim();
      }
      state.pendingDraft = null;
    }

    if (!getSelectedOptionMeta(startDisplayOptions, selectedStart) && pendingStartLabel) {
      selectedStart = resolveSelectionSegmentId(startDisplayOptions, selectedStart, pendingStartLabel);
    }

    for (i = 0; i < startDisplayOptions.length; i += 1) {
      if (optionSegmentId(startDisplayOptions[i]) === selectedStart) {
        selectedStartExists = true;
        break;
      }
    }
    if (!selectedStartExists && allowAutoSelect && startDisplayOptions.length) {
      selectedStart = optionSegmentId(startDisplayOptions[0]);
    }

    var selectedStartMeta = getSelectedOptionMeta(state.options.startOptions, selectedStart);
    var endDisplayOptions = uniqueEndOptionsForDisplay(
      state.options.endOptions,
      selectedStart,
      selectedStartMeta,
      state.activeTemplateIsLoop
    );

    if (!getSelectedOptionMeta(endDisplayOptions, selectedEnd) && pendingEndLabel) {
      selectedEnd = resolveSelectionSegmentId(endDisplayOptions, selectedEnd, pendingEndLabel);
    }

    for (i = 0; i < endDisplayOptions.length; i += 1) {
      if (optionSegmentId(endDisplayOptions[i]) === selectedEnd) {
        selectedEndExists = true;
        break;
      }
    }
    if (!selectedEndExists && allowAutoSelect && endDisplayOptions.length) {
      selectedEnd = optionSegmentId(endDisplayOptions[0]);
    }

    renderSelect(dom.startSelectEl, startDisplayOptions, "Select start location", selectedStart);
    renderSelect(dom.endSelectEl, endDisplayOptions, "Select end location", selectedEnd);
    updateDirectionControlAvailability();

    renderOptionalStops();
    state.suppressAutoSelectOnce = false;
  }

  function extractUserId(payload) {
    var user = payload && payload.USER ? payload.USER : {};
    if (!user || typeof user !== "object") return "";
    return String(
      user.userId !== undefined ? user.userId :
        (user.USERID !== undefined ? user.USERID :
          (user.id !== undefined ? user.id : ""))
    ).trim();
  }

  function ensureUserId() {
    if (state.userId) return Promise.resolve(state.userId);
    if (state.userIdPromise) return state.userIdPromise;

    state.userIdPromise = fetchJson(BASE_PATH + "/api/v1/me.cfc?method=handle&returnFormat=json", {
      credentials: "same-origin"
    })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          if (payload && payload.AUTH === false) {
            throw authError("Unauthorized");
          }
          return "";
        }
        state.userId = extractUserId(payload);
        return state.userId;
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
        }
        return "";
      })
      .finally(function () {
        state.userIdPromise = null;
      });

    return state.userIdPromise;
  }

  function loadTemplates() {
    return fetchJson(apiUrl("listRouteTemplates"), { credentials: "same-origin" })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load templates.");
        }
        var list = payload && payload.DATA && Array.isArray(payload.DATA.ROUTES) ? payload.DATA.ROUTES : [];
        if (!list.length) {
          throw new Error("No templates were returned by FPW.");
        }
        state.templates = list;
        renderTemplateSelect();
      });
  }

  function fetchEditContext(routeCode) {
    var code = String(routeCode || "").trim();
    if (!code) return Promise.resolve({});
    return fetchJson(apiUrl("routegen_geteditcontext"), {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify({ route_code: code })
    })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load route edit context.");
        }
        return payload.DATA || {};
      });
  }

  function applyEditContext(editData) {
    var data = editData || {};
    var inputs = data && data.inputs ? data.inputs : data;
    if (!inputs || typeof inputs !== "object") return;

    var templateCode = String(
      inputs.template_code !== undefined ? inputs.template_code :
        (inputs.TEMPLATE_CODE !== undefined ? inputs.TEMPLATE_CODE : "")
    ).trim();
    if (templateCode) {
      setActiveTemplate(templateCode, { restoreDraft: false, rememberSelection: false });
    }

    if (inputs.direction !== undefined || inputs.DIRECTION !== undefined) {
      setDirectionValue(inputs.direction !== undefined ? inputs.direction : inputs.DIRECTION);
    }
    if (dom.startDateEl && (inputs.start_date !== undefined || inputs.START_DATE !== undefined)) {
      dom.startDateEl.value = String(inputs.start_date !== undefined ? inputs.start_date : inputs.START_DATE);
    }
    if (dom.paceEl && (inputs.pace !== undefined || inputs.PACE !== undefined)) {
      dom.paceEl.value = String(getPaceIndexByKey(inputs.pace !== undefined ? inputs.pace : inputs.PACE));
    }

    updatePaceLabel();
    state.manualOverrides.cruisingSpeed = false;
    applyPaceDefaults(true);
    updatePaceOverrideUI();

    if (dom.cruisingSpeedEl && (inputs.cruising_speed !== undefined || inputs.CRUISING_SPEED !== undefined)) {
      dom.cruisingSpeedEl.value = String(inputs.cruising_speed !== undefined ? inputs.cruising_speed : inputs.CRUISING_SPEED);
    }
    if (dom.underwayHoursEl && (inputs.underway_hours_per_day !== undefined || inputs.UNDERWAY_HOURS_PER_DAY !== undefined)) {
      dom.underwayHoursEl.value = String(
        inputs.underway_hours_per_day !== undefined ? inputs.underway_hours_per_day : inputs.UNDERWAY_HOURS_PER_DAY
      );
    }
    if (dom.comfortProfileEl && (inputs.comfort_profile !== undefined || inputs.COMFORT_PROFILE !== undefined)) {
      dom.comfortProfileEl.value = String(inputs.comfort_profile !== undefined ? inputs.comfort_profile : inputs.COMFORT_PROFILE);
    }
    if (dom.overnightBiasEl && (inputs.overnight_bias !== undefined || inputs.OVERNIGHT_BIAS !== undefined)) {
      dom.overnightBiasEl.value = String(inputs.overnight_bias !== undefined ? inputs.overnight_bias : inputs.OVERNIGHT_BIAS);
    }
    setFuelBurnBasis(FUEL_BURN_BASIS_MAX);
    if (
      dom.fuelBurnGphEl &&
      (
        inputs.fuel_burn_gph !== undefined
        || inputs.FUEL_BURN_GPH !== undefined
      )
    ) {
      dom.fuelBurnGphEl.value = String(
        inputs.fuel_burn_gph !== undefined ? inputs.fuel_burn_gph : inputs.FUEL_BURN_GPH
      );
    }
    if (dom.idleBurnGphEl && (inputs.idle_burn_gph !== undefined || inputs.IDLE_BURN_GPH !== undefined)) {
      dom.idleBurnGphEl.value = String(inputs.idle_burn_gph !== undefined ? inputs.idle_burn_gph : inputs.IDLE_BURN_GPH);
    }
    if (dom.idleHoursTotalEl && (inputs.idle_hours_total !== undefined || inputs.IDLE_HOURS_TOTAL !== undefined)) {
      dom.idleHoursTotalEl.value = String(
        inputs.idle_hours_total !== undefined ? inputs.idle_hours_total : inputs.IDLE_HOURS_TOTAL
      );
    }
    if (dom.weatherFactorPctEl && (inputs.weather_factor_pct !== undefined || inputs.WEATHER_FACTOR_PCT !== undefined)) {
      dom.weatherFactorPctEl.value = String(
        inputs.weather_factor_pct !== undefined ? inputs.weather_factor_pct : inputs.WEATHER_FACTOR_PCT
      );
    }
    if (dom.reservePctEl && (inputs.reserve_pct !== undefined || inputs.RESERVE_PCT !== undefined)) {
      dom.reservePctEl.value = String(
        inputs.reserve_pct !== undefined ? inputs.reserve_pct : inputs.RESERVE_PCT
      );
    }
    if (dom.fuelPricePerGalEl && (inputs.fuel_price_per_gal !== undefined || inputs.FUEL_PRICE_PER_GAL !== undefined)) {
      dom.fuelPricePerGalEl.value = String(
        inputs.fuel_price_per_gal !== undefined ? inputs.fuel_price_per_gal : inputs.FUEL_PRICE_PER_GAL
      );
    }

    state.selectedStopCodes = {};
    var stopFlags = inputs.optional_stop_flags !== undefined ? inputs.optional_stop_flags : inputs.OPTIONAL_STOP_FLAGS;
    if (Array.isArray(stopFlags)) {
      stopFlags.forEach(function (code) {
        state.selectedStopCodes[String(code)] = true;
      });
    }

    state.pendingDraft = {
      start_segment_id: String(
        inputs.start_segment_id !== undefined ? inputs.start_segment_id :
          (inputs.START_SEGMENT_ID !== undefined ? inputs.START_SEGMENT_ID : "")
      ).trim(),
      end_segment_id: String(
        inputs.end_segment_id !== undefined ? inputs.end_segment_id :
          (inputs.END_SEGMENT_ID !== undefined ? inputs.END_SEGMENT_ID : "")
      ).trim()
    };

    state.editorBaseline = {
      template_code: templateCode || state.activeTemplateCode,
      direction: getDirectionValue(),
      start_date: dom.startDateEl ? String(dom.startDateEl.value || "") : "",
      pace_index: getSelectedPaceIndex(),
      cruising_speed: dom.cruisingSpeedEl ? String(dom.cruisingSpeedEl.value || "") : "",
      underway_hours_per_day: dom.underwayHoursEl ? String(dom.underwayHoursEl.value || "") : "8",
      comfort_profile: dom.comfortProfileEl ? String(dom.comfortProfileEl.value || "") : "PREFER_INSIDE",
      overnight_bias: dom.overnightBiasEl ? String(dom.overnightBiasEl.value || "") : "MARINAS",
      fuel_burn_gph: dom.fuelBurnGphEl ? String(dom.fuelBurnGphEl.value || "") : "",
      fuel_burn_gph_input: dom.fuelBurnGphEl ? String(dom.fuelBurnGphEl.value || "") : "",
      fuel_burn_basis: getFuelBurnBasis(),
      idle_burn_gph: dom.idleBurnGphEl ? String(dom.idleBurnGphEl.value || "") : "",
      idle_hours_total: dom.idleHoursTotalEl ? String(dom.idleHoursTotalEl.value || "") : "",
      weather_factor_pct: dom.weatherFactorPctEl ? String(dom.weatherFactorPctEl.value || "") : String(DEFAULT_WEATHER_FACTOR_PCT),
      reserve_pct: dom.reservePctEl ? String(dom.reservePctEl.value || "") : String(DEFAULT_RESERVE_PCT),
      fuel_price_per_gal: dom.fuelPricePerGalEl ? String(dom.fuelPricePerGalEl.value || "") : "",
      optional_stop_flags: Object.keys(state.selectedStopCodes).filter(function (code) {
        return !!state.selectedStopCodes[code];
      }),
      start_segment_id: state.pendingDraft.start_segment_id,
      end_segment_id: state.pendingDraft.end_segment_id,
      start_label: String(
        inputs.start_location_label !== undefined ? inputs.start_location_label :
          (inputs.START_LOCATION_LABEL !== undefined ? inputs.START_LOCATION_LABEL : "")
      ).trim(),
      end_label: String(
        inputs.end_location_label !== undefined ? inputs.end_location_label :
          (inputs.END_LOCATION_LABEL !== undefined ? inputs.END_LOCATION_LABEL : "")
      ).trim()
    };
    updateFuelBurnBasisUI();
  }

  function setActiveTemplate(templateCode, options) {
    var opts = options || {};
    var restoreDraft = (opts.restoreDraft !== undefined) ? !!opts.restoreDraft : !state.freshStartSession;
    var rememberSelection = (opts.rememberSelection !== undefined) ? !!opts.rememberSelection : true;
    var allowEmpty = !!opts.allowEmpty;
    var freshGeneratorMode = (state.modalMode === "generator" && state.freshStartSession);
    var desired = String(templateCode || "").trim();
    var template = getTemplateByCode(desired);

    if (!template && !allowEmpty && !freshGeneratorMode && state.templates.length) {
      template = state.templates[0];
    }
    if (!template) {
      state.activeTemplateCode = "";
      state.activeTemplateIsLoop = true;
      renderTemplateSelect();
      updateTemplateMeta(null);
      if (dom.previewTemplateEl) {
        dom.previewTemplateEl.textContent = "Template: -";
      }
      state.pendingDraft = null;
      return;
    }

    state.activeTemplateCode = getTemplateValue(template);
    state.activeTemplateIsLoop = true;
    if (rememberSelection) {
      saveTemplateMemory(state.activeTemplateCode);
    }
    renderTemplateSelect();
    if (dom.templateSelectEl) {
      dom.templateSelectEl.value = state.activeTemplateCode;
    }
    updateTemplateMeta(template);

    if (dom.previewTemplateEl) {
      dom.previewTemplateEl.textContent = "Template: " + getTemplateDisplayName(template);
    }

    if (!restoreDraft) {
      state.pendingDraft = null;
      return;
    }

    var draft = readDraft(state.activeTemplateCode);
    applyDraftToForm(draft);
  }

  function collectFormPayload() {
    var selectedStops = Object.keys(state.selectedStopCodes).filter(function (code) {
      return !!state.selectedStopCodes[code];
    });
    var fuelModel = getFuelBurnModelValues();

    var selectedStartMeta = getSelectedOptionMeta(state.options.startOptions, dom.startSelectEl ? dom.startSelectEl.value : "");
    var selectedEndMeta = getSelectedOptionMeta(state.options.endOptions, dom.endSelectEl ? dom.endSelectEl.value : "");

    return {
      template_code: state.activeTemplateCode,
      direction: getDirectionValue(),
      start_segment_id: dom.startSelectEl ? String(dom.startSelectEl.value || "") : "",
      end_segment_id: dom.endSelectEl ? String(dom.endSelectEl.value || "") : "",
      start_location_label: selectedStartMeta ? String(selectedStartMeta.LABEL || selectedStartMeta.label || "") : "",
      end_location_label: selectedEndMeta ? String(selectedEndMeta.LABEL || selectedEndMeta.label || "") : "",
      start_date: dom.startDateEl ? String(dom.startDateEl.value || "") : "",
      pace: getSelectedPacePreset().key,
      cruising_speed: String(getMaxSpeedKn()),
      effective_cruising_speed: String(getEffectiveCruisingSpeed()),
      underway_hours_per_day: dom.underwayHoursEl ? String(dom.underwayHoursEl.value || "") : "8",
      comfort_profile: dom.comfortProfileEl ? String(dom.comfortProfileEl.value || "") : "PREFER_INSIDE",
      overnight_bias: dom.overnightBiasEl ? String(dom.overnightBiasEl.value || "") : "MARINAS",
      fuel_burn_gph: (fuelModel.maxSpeedBurn > 0 ? String(fuelModel.maxSpeedBurn) : ""),
      fuel_burn_gph_input: (fuelModel.inputBurn > 0 ? String(fuelModel.inputBurn) : ""),
      fuel_burn_basis: fuelModel.basis,
      idle_burn_gph: dom.idleBurnGphEl ? String(dom.idleBurnGphEl.value || "") : "",
      idle_hours_total: dom.idleHoursTotalEl ? String(dom.idleHoursTotalEl.value || "") : "",
      weather_factor_pct: dom.weatherFactorPctEl ? String(dom.weatherFactorPctEl.value || "") : String(DEFAULT_WEATHER_FACTOR_PCT),
      reserve_pct: dom.reservePctEl ? String(dom.reservePctEl.value || "") : String(DEFAULT_RESERVE_PCT),
      fuel_price_per_gal: dom.fuelPricePerGalEl ? String(dom.fuelPricePerGalEl.value || "") : "",
      optional_stop_flags: selectedStops
    };
  }

  function canPreview(payload) {
    var p = payload || collectFormPayload();
    return !!(p.template_code && p.start_segment_id && p.end_segment_id && p.start_date);
  }

  function fetchOptions() {
    if (!state.activeTemplateCode) return Promise.resolve();

    state.optionReqSeq += 1;
    var seq = state.optionReqSeq;

    var requestPayload = {
      template_code: state.activeTemplateCode,
      direction: getDirectionValue()
    };

    setStatus("Loading available start/end locations...");

    return fetchJson(apiUrl("routegen_getOptions"), {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(requestPayload)
    })
      .then(function (payload) {
        if (seq !== state.optionReqSeq) return;
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load route options.");
        }

        var data = payload.DATA || {};
        state.options.startOptions = Array.isArray(data.startOptions) ? data.startOptions : (Array.isArray(data.START_OPTIONS) ? data.START_OPTIONS : []);
        state.options.endOptions = Array.isArray(data.endOptions) ? data.endOptions : (Array.isArray(data.END_OPTIONS) ? data.END_OPTIONS : []);
        state.options.optionalStops = Array.isArray(data.optionalStops) ? data.optionalStops : (Array.isArray(data.OPTIONAL_STOPS) ? data.OPTIONAL_STOPS : []);
        var templateMeta = (data.template && typeof data.template === "object") ? data.template : (data.TEMPLATE || {});
        var isLoopRaw = (
          templateMeta.is_loop !== undefined ? templateMeta.is_loop :
            (templateMeta.IS_LOOP !== undefined ? templateMeta.IS_LOOP :
              (data.is_loop !== undefined ? data.is_loop : data.IS_LOOP))
        );
        state.activeTemplateIsLoop = coerceBool(isLoopRaw, true);

        renderOptions();
        setStatus("Options loaded.");
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to load route options.");
      });
  }

  function renderLegs(legs) {
    if (!dom.legListEl) return;
    var list = Array.isArray(legs) ? legs : [];
    if (!list.length) {
      dom.legListEl.innerHTML = '<div class="fpw-routegen__empty">No legs available for the current selection.</div>';
      return;
    }

    dom.legListEl.innerHTML = list.map(function (leg, idx) {
      var order = parseInt(
        leg.order_index !== undefined ? leg.order_index :
          (leg.ORDER_INDEX !== undefined ? leg.ORDER_INDEX : (idx + 1)),
        10
      );
      if (!Number.isFinite(order) || order <= 0) order = idx + 1;

      var startName = String(leg.start_name !== undefined ? leg.start_name : (leg.START_NAME !== undefined ? leg.START_NAME : "")).trim();
      var endName = String(leg.end_name !== undefined ? leg.end_name : (leg.END_NAME !== undefined ? leg.END_NAME : "")).trim();
      var nm = parseFloat(leg.dist_nm !== undefined ? leg.dist_nm : leg.DIST_NM);
      var lockCount = parseInt(
        leg.lock_count !== undefined ? leg.lock_count :
          (leg.LOCK_COUNT !== undefined ? leg.LOCK_COUNT : 0),
        10
      );
      var isOffshore = !!(leg.is_offshore || leg.IS_OFFSHORE);
      var isOptional = !!(leg.is_optional || leg.IS_OPTIONAL);
      if (!Number.isFinite(lockCount) || lockCount < 0) lockCount = 0;

      var flags = "";
      if (isOffshore) flags += '<span class="fpw-routegen__flag">Offshore</span>';
      if (isOptional) flags += '<span class="fpw-routegen__flag">Optional</span>';

      return ''
        + '<div class="fpw-routegen__leg">'
        + '  <div class="fpw-routegen__legidx">' + String(order).padStart(2, "0") + '</div>'
        + '  <div class="fpw-routegen__legroute">'
        + '    <div class="fpw-routegen__legname">' + escapeHtml((startName || "Start") + " -> " + (endName || "End")) + flags + '</div>'
        + '  </div>'
        + '  <div class="fpw-routegen__leglocks">' + formatNumber(lockCount, 0) + '</div>'
        + '  <div class="fpw-routegen__legnm">' + formatNumber(Number.isFinite(nm) ? nm : 0, 1) + ' NM</div>'
        + '</div>';
    }).join("");
  }

  function renderPreviewPayload(payload, fromTimeline) {
    var sourceData = payload && payload.DATA ? payload.DATA : payload;
    var totals = sourceData && sourceData.totals ? sourceData.totals : (sourceData && sourceData.TOTALS ? sourceData.TOTALS : {});
    var legs = sourceData && sourceData.legs ? sourceData.legs : (sourceData && sourceData.LEGS ? sourceData.LEGS : []);
    var paceLabel = getSelectedPacePreset().label;

    var totalNm = parseFloat(
      totals.total_nm !== undefined ? totals.total_nm :
        (totals.TOTAL_NM !== undefined ? totals.TOTAL_NM : 0)
    );
    var estimatedDays = parseFloat(
      totals.estimated_days !== undefined ? totals.estimated_days :
        (totals.ESTIMATED_DAYS !== undefined ? totals.ESTIMATED_DAYS : 0)
    );
    var lockCount = parseInt(
      totals.lock_count !== undefined ? totals.lock_count :
        (totals.LOCK_COUNT !== undefined ? totals.LOCK_COUNT : (totals.TOTAL_LOCKS !== undefined ? totals.TOTAL_LOCKS : 0)),
      10
    );
    var offshoreLegCount = parseInt(
      totals.offshore_leg_count !== undefined ? totals.offshore_leg_count :
        (totals.OFFSHORE_LEG_COUNT !== undefined ? totals.OFFSHORE_LEG_COUNT : 0),
      10
    );
    var estimatedFuelGallons = parseFloat(
      totals.required_fuel_gallons !== undefined ? totals.required_fuel_gallons :
        (totals.REQUIRED_FUEL_GALLONS !== undefined ? totals.REQUIRED_FUEL_GALLONS :
          (totals.estimated_fuel_gallons !== undefined ? totals.estimated_fuel_gallons :
            (totals.ESTIMATED_FUEL_GALLONS !== undefined ? totals.ESTIMATED_FUEL_GALLONS : NaN)))
    );
    var baseFuelGallons = parseFloat(
      totals.base_fuel_gallons !== undefined ? totals.base_fuel_gallons :
        (totals.BASE_FUEL_GALLONS !== undefined ? totals.BASE_FUEL_GALLONS : NaN)
    );
    var reserveFuelGallons = parseFloat(
      totals.reserve_fuel_gallons !== undefined ? totals.reserve_fuel_gallons :
        (totals.RESERVE_FUEL_GALLONS !== undefined ? totals.RESERVE_FUEL_GALLONS : NaN)
    );
    var reservePct = parseFloat(
      totals.reserve_pct !== undefined ? totals.reserve_pct :
        (totals.RESERVE_PCT !== undefined ? totals.RESERVE_PCT : NaN)
    );
    var fuelCostEstimate = parseFloat(
      totals.fuel_cost_estimate !== undefined ? totals.fuel_cost_estimate :
        (totals.FUEL_COST_ESTIMATE !== undefined ? totals.FUEL_COST_ESTIMATE : NaN)
    );
    var runHours = parseFloat(
      totals.run_hours !== undefined ? totals.run_hours :
        (totals.TOTAL_RUN_HOURS !== undefined ? totals.TOTAL_RUN_HOURS :
          (totals.total_run_hours !== undefined ? totals.total_run_hours : NaN))
    );
    var idleHours = parseFloat(
      totals.idle_hours !== undefined ? totals.idle_hours :
        (totals.IDLE_HOURS_TOTAL !== undefined ? totals.IDLE_HOURS_TOTAL : NaN)
    );
    var totalHours = parseFloat(
      totals.total_hours !== undefined ? totals.total_hours :
        (totals.TOTAL_HOURS !== undefined ? totals.TOTAL_HOURS : NaN)
    );
    var fuelPricePerGal = parseFloat(
      totals.fuel_price_per_gal !== undefined ? totals.fuel_price_per_gal :
        (totals.FUEL_PRICE_PER_GAL !== undefined ? totals.FUEL_PRICE_PER_GAL : NaN)
    );

    if (dom.totalNmEl) dom.totalNmEl.innerHTML = formatNumber(Number.isFinite(totalNm) ? totalNm : 0, 1) + ' <small>NM</small>';
    if (dom.estimatedDaysEl) dom.estimatedDaysEl.textContent = String(Number.isFinite(estimatedDays) ? Math.max(0, Math.round(estimatedDays)) : 0);
    if (dom.lockCountEl) dom.lockCountEl.textContent = String(Number.isFinite(lockCount) ? Math.max(0, lockCount) : 0);
    if (dom.offshoreCountEl) dom.offshoreCountEl.textContent = String(Number.isFinite(offshoreLegCount) ? Math.max(0, offshoreLegCount) : 0);
    if (dom.estimatedFuelEl) {
      if (Number.isFinite(estimatedFuelGallons) && estimatedFuelGallons >= 0) {
        dom.estimatedFuelEl.innerHTML = formatNumber(estimatedFuelGallons, 1) + ' <small>gal</small>';
      } else {
        dom.estimatedFuelEl.innerHTML = "-- <small>gal</small>";
      }
    }
    if (dom.fuelCostEl) {
      if (Number.isFinite(fuelCostEstimate) && fuelCostEstimate >= 0 && Number.isFinite(fuelPricePerGal) && fuelPricePerGal > 0) {
        dom.fuelCostEl.innerHTML = formatCurrency(fuelCostEstimate) + ' <small>USD</small>';
      } else {
        dom.fuelCostEl.innerHTML = "-- <small>USD</small>";
      }
    }

    if (dom.legCountEl) {
      dom.legCountEl.textContent = String(Array.isArray(legs) ? legs.length : 0) + " legs";
    }

    if (dom.estimatedDaysSubEl) {
      if (fromTimeline) {
        dom.estimatedDaysSubEl.textContent = "Generated route timeline";
      } else if (Number.isFinite(runHours) && Number.isFinite(idleHours) && Number.isFinite(totalHours)) {
        dom.estimatedDaysSubEl.textContent = "Run " + formatNumber(runHours, 1) + "h + Idle " + formatNumber(idleHours, 1) + "h = " + formatNumber(totalHours, 1) + "h";
      } else {
        dom.estimatedDaysSubEl.textContent = "Pace: " + paceLabel;
      }
    }
    if (dom.estimatedFuelSubEl) {
      if (fromTimeline) {
        dom.estimatedFuelSubEl.textContent = "Fuel estimate unavailable from timeline";
      } else if (Number.isFinite(baseFuelGallons) && Number.isFinite(reserveFuelGallons) && Number.isFinite(reservePct)) {
        dom.estimatedFuelSubEl.textContent = "Base " + formatNumber(baseFuelGallons, 1) + " + Reserve (" + formatNumber(reservePct, 0) + "%) " + formatNumber(reserveFuelGallons, 1);
      } else {
        dom.estimatedFuelSubEl.textContent = "Required = base + reserve";
      }
    }
    if (dom.fuelCostSubEl) {
      if (fromTimeline) {
        dom.fuelCostSubEl.textContent = "Cost estimate unavailable from timeline";
      } else if (Number.isFinite(fuelPricePerGal) && fuelPricePerGal > 0) {
        dom.fuelCostSubEl.textContent = "Required fuel x $" + formatNumber(fuelPricePerGal, 2) + "/gal";
      } else {
        dom.fuelCostSubEl.textContent = "Enter fuel price to estimate";
      }
    }

    renderLegs(legs);
  }

  function schedulePreview() {
    if (state.previewTimer) {
      window.clearTimeout(state.previewTimer);
      state.previewTimer = 0;
    }
    state.previewTimer = window.setTimeout(function () {
      state.previewTimer = 0;
      previewRoute(false);
    }, 250);
  }

  function previewRoute(forceRefresh) {
    var payload = collectFormPayload();
    if (!canPreview(payload)) {
      if (forceRefresh) {
        showError("Select a template, start location, end location, and start date to preview.");
      } else {
        clearError();
      }
      setStatus("Waiting for required fields.");
      clearPreview();
      return Promise.resolve(null);
    }

    clearError();
    state.previewReqSeq += 1;
    var seq = state.previewReqSeq;

    if (forceRefresh) {
      setStatus("Refreshing preview...");
    } else {
      setStatus("Updating preview...");
    }

    if (dom.previewBtn) dom.previewBtn.disabled = true;

    return fetchJson(apiUrl("routegen_preview"), {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(payload)
    })
      .then(function (resPayload) {
        if (seq !== state.previewReqSeq) return null;
        if (!resPayload || resPayload.SUCCESS === false) {
          throw new Error((resPayload && resPayload.MESSAGE) ? resPayload.MESSAGE : "Preview failed.");
        }
        renderPreviewPayload(resPayload, false);
        setStatus(forceRefresh ? "Preview updated." : "Preview ready.");
        if (state.modalMode !== "editor") {
          saveDraft();
        }
        return resPayload;
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return null;
        }
        showError((err && err.message) ? err.message : "Unable to preview route.");
        setStatus("Preview failed.");
        return null;
      })
      .finally(function () {
        if (dom.previewBtn) dom.previewBtn.disabled = false;
      });
  }

  function generateRoute() {
    var payload = collectFormPayload();
    if (!canPreview(payload)) {
      showError("Select a template, start location, end location, and start date before generating.");
      return;
    }

    clearError();
    setStatus("Generating route...");
    if (dom.generateBtn) dom.generateBtn.disabled = true;

    previewRoute(true)
      .then(function (previewPayload) {
        if (!previewPayload) {
          throw new Error("Cannot generate route without a valid preview.");
        }

        return fetchJson(apiUrl("routegen_generate"), {
          method: "POST",
          credentials: "same-origin",
          headers: { "Content-Type": "application/json; charset=utf-8" },
          body: JSON.stringify(payload)
        });
      })
      .then(function (responsePayload) {
        if (!responsePayload || responsePayload.SUCCESS === false) {
          throw new Error((responsePayload && responsePayload.MESSAGE) ? responsePayload.MESSAGE : "Unable to generate route.");
        }

        var data = responsePayload.DATA || {};
        var routeCode = String(
          data.route_code !== undefined ? data.route_code :
            (data.ROUTE_CODE !== undefined ? data.ROUTE_CODE : (responsePayload.ROUTE_CODE !== undefined ? responsePayload.ROUTE_CODE : ""))
        ).trim();

        state.lastGeneratedRouteCode = routeCode;
        state.activeRouteCode = routeCode;
        setRouteCodeBadge(routeCode || "Generated");
        setStatus("Route generated.");

        if (utils && typeof utils.showDashboardAlert === "function") {
          utils.showDashboardAlert("Route generated successfully.", "success");
        }

        notifyRoutesUpdated(routeCode);

        if (modal) {
          modal.hide();
        }
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to generate route.");
        setStatus("Generate failed.");
      })
      .finally(function () {
        if (dom.generateBtn) dom.generateBtn.disabled = false;
      });
  }

  function saveEditedRoute() {
    var routeCode = String(state.activeRouteCode || "").trim();
    if (!routeCode) {
      showError("No route selected to save.");
      return;
    }

    var payload = collectFormPayload();
    payload.route_code = routeCode;

    if (!canPreview(payload)) {
      showError("Select a template, start location, end location, and start date before saving.");
      return;
    }

    clearError();
    setStatus("Saving route...");
    if (dom.saveBtn) dom.saveBtn.disabled = true;

    previewRoute(true)
      .then(function (previewPayload) {
        if (!previewPayload) {
          throw new Error("Cannot save route without a valid preview.");
        }

        return fetchJson(apiUrl("routegen_update"), {
          method: "POST",
          credentials: "same-origin",
          headers: { "Content-Type": "application/json; charset=utf-8" },
          body: JSON.stringify(payload)
        });
      })
      .then(function (responsePayload) {
        if (!responsePayload || responsePayload.SUCCESS === false) {
          throw new Error((responsePayload && responsePayload.MESSAGE) ? responsePayload.MESSAGE : "Unable to save route.");
        }

        var data = responsePayload.DATA || {};
        var savedRouteCode = String(
          data.route_code !== undefined ? data.route_code :
            (data.ROUTE_CODE !== undefined ? data.ROUTE_CODE : routeCode)
        ).trim();

        state.activeRouteCode = savedRouteCode || routeCode;
        setRouteCodeBadge(state.activeRouteCode);
        setStatus("Route saved.");

        if (utils && typeof utils.showDashboardAlert === "function") {
          utils.showDashboardAlert("Route saved successfully.", "success");
        }

        notifyRoutesUpdated(state.activeRouteCode);
        return previewRoute(true);
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to save route.");
        setStatus("Save failed.");
      })
      .finally(function () {
        if (dom.saveBtn) dom.saveBtn.disabled = false;
      });
  }

  function loadExistingRoute(routeCode) {
    if (!routeCode) return Promise.resolve();
    clearError();
    setStatus("Loading route " + routeCode + "...");
    setRouteCodeBadge(routeCode);
    state.activeRouteCode = String(routeCode);

    return fetchJson(apiUrl("getTimeline", { routeCode: routeCode }), { credentials: "same-origin" })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load route timeline.");
        }

        var sections = Array.isArray(payload.SECTIONS) ? payload.SECTIONS : [];
        var flatLegs = [];
        sections.forEach(function (section) {
          var segs = Array.isArray(section.SEGMENTS) ? section.SEGMENTS : [];
          segs.forEach(function (seg) {
            flatLegs.push({
              ORDER_INDEX: seg.ORDER_INDEX,
              START_NAME: seg.START_NAME,
              END_NAME: seg.END_NAME,
              DIST_NM: seg.DIST_NM,
              LOCK_COUNT: seg.LOCK_COUNT,
              IS_OFFSHORE: false,
              IS_OPTIONAL: false
            });
          });
        });

        var previewLike = {
          TOTALS: {
            TOTAL_NM: payload.TOTALS && payload.TOTALS.TOTAL_NM ? payload.TOTALS.TOTAL_NM : 0,
            ESTIMATED_DAYS: 0,
            LOCK_COUNT: payload.TOTALS && payload.TOTALS.TOTAL_LOCKS ? payload.TOTALS.TOTAL_LOCKS : 0,
            OFFSHORE_LEG_COUNT: 0
          },
          LEGS: flatLegs
        };

        renderPreviewPayload(previewLike, true);
        setStatus("Route loaded.");
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to load route.");
        setStatus("Route load failed.");
      });
  }

  function setTodayIfMissing() {
    if (!dom.startDateEl) return;
    if (dom.startDateEl.value) return;
    var d = new Date();
    var yyyy = d.getFullYear();
    var mm = String(d.getMonth() + 1).padStart(2, "0");
    var dd = String(d.getDate()).padStart(2, "0");
    dom.startDateEl.value = yyyy + "-" + mm + "-" + dd;
  }

  function resetGeneratorState() {
    clearError();
    clearPreview();
    setRouteCodeBadge("Draft");
    setStatus("Ready");

    state.options = {
      startOptions: [],
      endOptions: [],
      optionalStops: []
    };
    state.selectedStopCodes = {};
    state.pendingDraft = null;
    state.manualOverrides.cruisingSpeed = false;
    state.editorBaseline = null;
    state.suppressAutoSelectOnce = false;
    state.activeTemplateCode = "";

    if (dom.templateSelectEl) {
      dom.templateSelectEl.innerHTML = '<option value="">Select template</option>';
      dom.templateSelectEl.value = "";
      dom.templateSelectEl.disabled = false;
    }
    updateTemplateMeta(null);
    if (dom.previewTemplateEl) {
      dom.previewTemplateEl.textContent = "Template: -";
    }
    setDirectionValue("CCW");
    if (dom.startDateEl) dom.startDateEl.value = "";
    if (dom.startSelectEl) {
      dom.startSelectEl.innerHTML = '<option value="">Select start location</option>';
      dom.startSelectEl.value = "";
    }
    if (dom.endSelectEl) {
      dom.endSelectEl.innerHTML = '<option value="">Select end location</option>';
      dom.endSelectEl.value = "";
    }
    if (dom.paceEl) dom.paceEl.value = "0";
    if (dom.underwayHoursEl) dom.underwayHoursEl.value = "8";
    if (dom.comfortProfileEl) dom.comfortProfileEl.value = "PREFER_INSIDE";
    if (dom.overnightBiasEl) dom.overnightBiasEl.value = "MARINAS";
    setFuelBurnBasis(FUEL_BURN_BASIS_MAX);
    if (dom.fuelBurnGphEl) dom.fuelBurnGphEl.value = "";
    if (dom.idleBurnGphEl) dom.idleBurnGphEl.value = "";
    if (dom.idleHoursTotalEl) dom.idleHoursTotalEl.value = "";
    if (dom.weatherFactorPctEl) dom.weatherFactorPctEl.value = String(DEFAULT_WEATHER_FACTOR_PCT);
    if (dom.reservePctEl) dom.reservePctEl.value = String(DEFAULT_RESERVE_PCT);
    if (dom.fuelPricePerGalEl) dom.fuelPricePerGalEl.value = "";
    setTodayIfMissing();
    updatePaceLabel();
    applyPaceDefaults(true);
    updatePaceOverrideUI();
    updateFuelBurnBasisUI();
    updateDirectionControlAvailability();
    setModalModeUI();
  }

  function openModal(mode, routeCode, launchOptions) {
    if (!modal) return;
    var options = launchOptions || {};
    var editorMode = mode === "editor";
    var freshStart = !!options.freshStart && !editorMode;
    state.modalInitSeq += 1;
    var initSeq = state.modalInitSeq;
    invalidateAsyncResponses();
    state.freshStartSession = freshStart;
    state.modalMode = editorMode ? "editor" : "generator";
    state.activeRouteCode = editorMode ? String(routeCode || "").trim() : "";

    resetGeneratorState();
    if (editorMode && state.activeRouteCode) {
      setRouteCodeBadge(state.activeRouteCode);
    }
    modal.show();

    ensureUserId()
      .then(function () {
        if (!isActiveModalInit(initSeq)) return null;
        return loadTemplates();
      })
      .then(function () {
        if (!isActiveModalInit(initSeq)) return null;
        if (editorMode && state.activeRouteCode) {
          return fetchEditContext(state.activeRouteCode)
            .then(function (editData) {
              if (!isActiveModalInit(initSeq)) return null;
              applyEditContext(editData);
              if (!state.activeTemplateCode && state.templates.length) {
                setActiveTemplate(String(state.templates[0].SHORT_CODE || state.templates[0].CODE || "").trim(), {
                  restoreDraft: false,
                  rememberSelection: false
                });
              }
              return fetchOptions();
            })
            .catch(function () {
              if (!isActiveModalInit(initSeq)) return null;
              if (state.templates.length) {
                setActiveTemplate(String(state.templates[0].SHORT_CODE || state.templates[0].CODE || "").trim(), {
                  restoreDraft: false,
                  rememberSelection: false
                });
              }
              return fetchOptions();
            });
        }

        var preferred = "";
        if (!freshStart) {
          preferred = readTemplateMemory();
        }
        if (!freshStart && !preferred && state.templates.length) {
          preferred = String(state.templates[0].SHORT_CODE || state.templates[0].CODE || "").trim();
        }

        setActiveTemplate(preferred, {
          restoreDraft: !freshStart,
          rememberSelection: !freshStart,
          allowEmpty: freshStart
        });
        return fetchOptions();
      })
      .then(function () {
        if (!isActiveModalInit(initSeq)) return null;
        if (editorMode && state.activeRouteCode) {
          return previewRoute(true);
        }
        return previewRoute(false);
      })
      .catch(function (err) {
        if (!isActiveModalInit(initSeq)) return;
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to initialize route generator.");
        setStatus("Initialization failed.");
      });
  }

  function closeModal() {
    state.modalInitSeq += 1;
    invalidateAsyncResponses();
    if (modal) {
      modal.hide();
    }
  }

  function onFormChange() {
    clearError();
    updateFuelBurnBasisUI();
    updateDirectionControlAvailability();
    if (state.modalMode !== "editor") {
      saveDraft();
    }
    schedulePreview();
  }

  function onTemplateSelectChange() {
    if (!dom.templateSelectEl) return;
    var code = String(dom.templateSelectEl.value || "").trim();
    if (!code || code === state.activeTemplateCode) return;

    // In fresh "new route" sessions, align template change to default direction first.
    // Users can still switch to CW explicitly afterward.
    if (state.freshStartSession) {
      setDirectionValue("CCW");
    }

    if (dom.startSelectEl) dom.startSelectEl.value = "";
    if (dom.endSelectEl) dom.endSelectEl.value = "";
    updateDirectionControlAvailability();

    setActiveTemplate(code);
    fetchOptions().then(function () {
      onFormChange();
    });
  }

  function resetGeneratorSelections() {
    clearError();
    if (state.previewTimer) {
      window.clearTimeout(state.previewTimer);
      state.previewTimer = 0;
    }
    invalidateAsyncResponses();

    state.selectedStopCodes = {};
    state.pendingDraft = {
      start_segment_id: "",
      end_segment_id: "",
      start_label: "",
      end_label: ""
    };
    state.manualOverrides.cruisingSpeed = false;
    state.suppressAutoSelectOnce = true;

    if (dom.paceEl) dom.paceEl.value = "0";
    if (dom.underwayHoursEl) dom.underwayHoursEl.value = "8";
    if (dom.comfortProfileEl) dom.comfortProfileEl.value = "PREFER_INSIDE";
    if (dom.overnightBiasEl) dom.overnightBiasEl.value = "MARINAS";
    setFuelBurnBasis(FUEL_BURN_BASIS_MAX);
    if (dom.fuelBurnGphEl) dom.fuelBurnGphEl.value = "";
    if (dom.idleBurnGphEl) dom.idleBurnGphEl.value = "";
    if (dom.idleHoursTotalEl) dom.idleHoursTotalEl.value = "";
    if (dom.weatherFactorPctEl) dom.weatherFactorPctEl.value = String(DEFAULT_WEATHER_FACTOR_PCT);
    if (dom.reservePctEl) dom.reservePctEl.value = String(DEFAULT_RESERVE_PCT);
    if (dom.fuelPricePerGalEl) dom.fuelPricePerGalEl.value = "";

    applyPaceDefaults(true);
    updatePaceLabel();
    updatePaceOverrideUI();
    updateFuelBurnBasisUI();
    renderOptions();

    if (dom.startSelectEl) dom.startSelectEl.value = "";
    if (dom.endSelectEl) dom.endSelectEl.value = "";
    updateDirectionControlAvailability();

    clearPreview();
    setStatus("Waiting for required fields.");
    saveDraft();
  }

  function resetEditorToBaseline() {
    var baseline = state.editorBaseline;
    if (!baseline || typeof baseline !== "object") {
      showError("No baseline found for this route.");
      return;
    }

    clearError();
    if (state.previewTimer) {
      window.clearTimeout(state.previewTimer);
      state.previewTimer = 0;
    }
    invalidateAsyncResponses();
    setStatus("Resetting to saved route...");

    state.manualOverrides.cruisingSpeed = false;

    if (baseline.template_code) {
      setActiveTemplate(String(baseline.template_code), { restoreDraft: false, rememberSelection: false });
    }
    setDirectionValue(baseline.direction);
    if (dom.startDateEl) {
      dom.startDateEl.value = String(baseline.start_date || "");
    }
    if (dom.paceEl) {
      var idx = parseInt(baseline.pace_index, 10);
      dom.paceEl.value = String(Number.isFinite(idx) && idx >= 0 && idx <= 2 ? idx : 0);
    }

    applyPaceDefaults(true);
    updatePaceLabel();

    if (dom.cruisingSpeedEl) dom.cruisingSpeedEl.value = String(baseline.cruising_speed || "");
    if (dom.underwayHoursEl) dom.underwayHoursEl.value = String(baseline.underway_hours_per_day || "8");
    if (dom.comfortProfileEl) dom.comfortProfileEl.value = String(baseline.comfort_profile || "PREFER_INSIDE");
    if (dom.overnightBiasEl) dom.overnightBiasEl.value = String(baseline.overnight_bias || "MARINAS");
    setFuelBurnBasis(FUEL_BURN_BASIS_MAX);
    if (dom.fuelBurnGphEl) {
      dom.fuelBurnGphEl.value = String(baseline.fuel_burn_gph || "");
    }
    if (dom.idleBurnGphEl) dom.idleBurnGphEl.value = String(baseline.idle_burn_gph || "");
    if (dom.idleHoursTotalEl) dom.idleHoursTotalEl.value = String(baseline.idle_hours_total || "");
    if (dom.weatherFactorPctEl) dom.weatherFactorPctEl.value = String(baseline.weather_factor_pct || DEFAULT_WEATHER_FACTOR_PCT);
    if (dom.reservePctEl) dom.reservePctEl.value = String(baseline.reserve_pct || DEFAULT_RESERVE_PCT);
    if (dom.fuelPricePerGalEl) dom.fuelPricePerGalEl.value = String(baseline.fuel_price_per_gal || "");
    updatePaceOverrideUI();
    updateFuelBurnBasisUI();

    state.selectedStopCodes = {};
    if (Array.isArray(baseline.optional_stop_flags)) {
      baseline.optional_stop_flags.forEach(function (code) {
        state.selectedStopCodes[String(code)] = true;
      });
    }

    state.pendingDraft = {
      start_segment_id: String(baseline.start_segment_id || ""),
      end_segment_id: String(baseline.end_segment_id || ""),
      start_label: String(baseline.start_label || ""),
      end_label: String(baseline.end_label || "")
    };

    fetchOptions()
      .then(function () {
        return previewRoute(true);
      })
      .catch(function (err) {
        if (err && err.code === "UNAUTHORIZED") {
          redirectToLogin();
          return;
        }
        showError((err && err.message) ? err.message : "Unable to reset this route.");
      });
  }

  function onResetClick() {
    if (state.modalMode === "editor") {
      resetEditorToBaseline();
      return;
    }
    resetGeneratorSelections();
  }

  function queueDirectionSwapDraft() {
    var currentStartId = dom.startSelectEl ? String(dom.startSelectEl.value || "").trim() : "";
    var currentEndId = dom.endSelectEl ? String(dom.endSelectEl.value || "").trim() : "";
    var startMeta = getSelectedOptionMeta(state.options.startOptions, currentStartId);
    var endMeta = getSelectedOptionMeta(state.options.endOptions, currentEndId);
    var startLabel = startMeta ? optionLabelText(startMeta) : "";
    var endLabel = endMeta ? optionLabelText(endMeta) : "";

    state.pendingDraft = {
      start_segment_id: currentEndId,
      end_segment_id: currentStartId,
      start_label: endLabel,
      end_label: startLabel
    };
  }

  function onDirectionControlChange() {
    clearError();
    setDirectionValue(dom.directionToggleEl ? (dom.directionToggleEl.checked ? "CW" : "CCW") : getDirectionValue());
    setStatus("Switching direction...");
    queueDirectionSwapDraft();

    if (dom.directionToggleEl) dom.directionToggleEl.disabled = true;
    if (dom.directionEl) dom.directionEl.disabled = true;
    if (dom.startSelectEl) dom.startSelectEl.disabled = true;
    if (dom.endSelectEl) dom.endSelectEl.disabled = true;
    if (dom.previewBtn) dom.previewBtn.disabled = true;
    if (dom.generateBtn) dom.generateBtn.disabled = true;
    if (dom.saveBtn) dom.saveBtn.disabled = true;

    fetchOptions()
      .then(function () {
        onFormChange();
      })
      .finally(function () {
        updateDirectionControlAvailability();
        if (dom.startSelectEl) dom.startSelectEl.disabled = false;
        if (dom.endSelectEl) dom.endSelectEl.disabled = false;
        if (dom.previewBtn) dom.previewBtn.disabled = false;
        if (dom.generateBtn) dom.generateBtn.disabled = false;
        if (dom.saveBtn) dom.saveBtn.disabled = false;
      });
  }

  function onStopToggleClick(event) {
    var target = event.target;
    if (!target) return;
    var btn = target.closest("[data-stop-code]");
    if (!btn) return;

    var code = String(btn.getAttribute("data-stop-code") || "").trim();
    if (!code) return;

    state.selectedStopCodes[code] = !state.selectedStopCodes[code];
    renderOptionalStops();
    onFormChange();
  }

  function bindEvents() {
    if (dom.openBtn) {
      dom.openBtn.addEventListener("click", function () {
        openModal("generator", "", { freshStart: true });
      });
    }

    if (dom.closeBtn) {
      dom.closeBtn.addEventListener("click", closeModal);
    }

    if (dom.cancelBtn) {
      dom.cancelBtn.addEventListener("click", closeModal);
    }

    if (dom.previewBtn) {
      dom.previewBtn.addEventListener("click", function () {
        previewRoute(true);
      });
    }

    if (dom.resetBtn) {
      dom.resetBtn.addEventListener("click", onResetClick);
    }

    if (dom.generateBtn) {
      dom.generateBtn.addEventListener("click", generateRoute);
    }

    if (dom.saveBtn) {
      dom.saveBtn.addEventListener("click", saveEditedRoute);
    }

    if (dom.templateSelectEl) {
      dom.templateSelectEl.addEventListener("change", onTemplateSelectChange);
    }

    if (dom.optionalStopsEl) {
      dom.optionalStopsEl.addEventListener("click", onStopToggleClick);
    }

    if (dom.directionToggleEl) {
      dom.directionToggleEl.addEventListener("change", onDirectionControlChange);
    } else if (dom.directionEl) {
      dom.directionEl.addEventListener("change", onDirectionControlChange);
    }

    if (dom.startDateEl) {
      dom.startDateEl.addEventListener("change", onFormChange);
    }

    if (dom.startSelectEl) {
      dom.startSelectEl.addEventListener("change", function () {
        if (dom.endSelectEl) dom.endSelectEl.value = "";
        renderOptions();
        onFormChange();
      });
    }

    if (dom.endSelectEl) {
      dom.endSelectEl.addEventListener("change", onFormChange);
    }

    if (dom.paceEl) {
      dom.paceEl.addEventListener("input", function () {
        updatePaceLabel();
        applyPaceDefaults(false);
        updatePaceOverrideUI();
        onFormChange();
      });
    }

    if (dom.cruisingSpeedEl) {
      dom.cruisingSpeedEl.addEventListener("input", function () {
        state.manualOverrides.cruisingSpeed = true;
        updatePaceOverrideUI();
        onFormChange();
      });
    }

    if (dom.underwayHoursEl) {
      dom.underwayHoursEl.addEventListener("input", onFormChange);
      dom.underwayHoursEl.addEventListener("change", onFormChange);
    }
    if (dom.fuelBurnGphEl) {
      dom.fuelBurnGphEl.addEventListener("input", onFormChange);
      dom.fuelBurnGphEl.addEventListener("change", onFormChange);
    }
    if (dom.idleBurnGphEl) {
      dom.idleBurnGphEl.addEventListener("input", onFormChange);
      dom.idleBurnGphEl.addEventListener("change", onFormChange);
    }
    if (dom.idleHoursTotalEl) {
      dom.idleHoursTotalEl.addEventListener("input", onFormChange);
      dom.idleHoursTotalEl.addEventListener("change", onFormChange);
    }
    if (dom.weatherFactorPctEl) {
      dom.weatherFactorPctEl.addEventListener("input", onFormChange);
      dom.weatherFactorPctEl.addEventListener("change", onFormChange);
    }
    if (dom.reservePctEl) {
      dom.reservePctEl.addEventListener("input", onFormChange);
      dom.reservePctEl.addEventListener("change", onFormChange);
    }
    if (dom.fuelPricePerGalEl) {
      dom.fuelPricePerGalEl.addEventListener("input", onFormChange);
      dom.fuelPricePerGalEl.addEventListener("change", onFormChange);
    }

    if (dom.resetPaceBtn) {
      dom.resetPaceBtn.addEventListener("click", function () {
        state.manualOverrides.cruisingSpeed = false;
        if (dom.cruisingSpeedEl) dom.cruisingSpeedEl.value = String(DEFAULT_MAX_SPEED_KN);
        applyPaceDefaults(true);
        updatePaceOverrideUI();
        onFormChange();
      });
    }

    if (dom.comfortProfileEl) {
      dom.comfortProfileEl.addEventListener("change", onFormChange);
    }

    if (dom.overnightBiasEl) {
      dom.overnightBiasEl.addEventListener("change", onFormChange);
    }

    if (dom.modalEl && !dom.modalEl.dataset.routegenBound) {
      dom.modalEl.addEventListener("hidden.bs.modal", function () {
        state.modalInitSeq += 1;
        invalidateAsyncResponses();
        if (state.previewTimer) {
          window.clearTimeout(state.previewTimer);
          state.previewTimer = 0;
        }
      });
      dom.modalEl.dataset.routegenBound = "true";
    }
  }

  function cacheDom() {
    dom.modalEl = document.getElementById("routeBuilderModal");
    dom.openBtn = document.getElementById("openRouteBuilderBtn");
    dom.root = document.getElementById("fpwRouteGen");

    if (!dom.modalEl || !dom.openBtn || !dom.root) return false;

    dom.closeBtn = document.getElementById("routeGenCloseBtn");
    dom.cancelBtn = document.getElementById("routeGenCancelBtn");
    dom.previewBtn = document.getElementById("routeGenPreviewBtn");
    dom.resetBtn = document.getElementById("routeGenResetBtn");
    dom.saveBtn = document.getElementById("routeGenSaveBtn");
    dom.generateBtn = document.getElementById("routeGenGenerateBtn");
    dom.hintLineEl = document.getElementById("routeGenHintLine");
    dom.errorEl = document.getElementById("routeGenError");
    dom.statusEl = document.getElementById("routeGenStatus");
    dom.routeCodeEl = document.getElementById("routeGenRouteCode");

    dom.templateSelectEl = document.getElementById("routeGenTemplateSelect");
    dom.templateMetaEl = document.getElementById("routeGenTemplateMeta");
    dom.startSelectEl = document.getElementById("routeGenStartLocation");
    dom.endSelectEl = document.getElementById("routeGenEndLocation");
    dom.startDateEl = document.getElementById("routeGenStartDate");
    dom.directionEl = document.getElementById("routeGenDirection");
    dom.directionToggleEl = document.getElementById("routeGenDirectionToggle");
    dom.directionStateEl = document.getElementById("routeGenDirectionState");
    dom.paceEl = document.getElementById("routeGenPace");
    dom.paceLabelEl = document.getElementById("routeGenPaceLabel");
    dom.paceOverrideHintEl = document.getElementById("routeGenPaceOverrideHint");
    dom.resetPaceBtn = document.getElementById("routeGenResetPaceBtn");

    dom.cruisingSpeedEl = document.getElementById("routeGenCruisingSpeed");
    dom.underwayHoursEl = document.getElementById("routeGenUnderwayHoursPerDay");
    dom.comfortProfileEl = document.getElementById("routeGenComfortProfile");
    dom.overnightBiasEl = document.getElementById("routeGenOvernightBias");
    dom.fuelBurnLabelEl = document.getElementById("routeGenFuelBurnLabel");
    dom.fuelBurnGphEl = document.getElementById("routeGenFuelBurnGph");
    dom.fuelBurnHintEl = document.getElementById("routeGenFuelBurnHint");
    dom.fuelBurnDerivedEl = document.getElementById("routeGenFuelBurnDerived");
    dom.idleBurnGphEl = document.getElementById("routeGenIdleBurnGph");
    dom.idleHoursTotalEl = document.getElementById("routeGenIdleHoursTotal");
    dom.weatherFactorPctEl = document.getElementById("routeGenWeatherFactorPct");
    dom.reservePctEl = document.getElementById("routeGenReservePct");
    dom.fuelPricePerGalEl = document.getElementById("routeGenFuelPricePerGal");
    dom.optionalStopsEl = document.getElementById("routeGenOptionalStops");

    dom.previewTemplateEl = document.getElementById("routeGenPreviewTemplate");
    dom.totalNmEl = document.getElementById("routeGenTotalNm");
    dom.estimatedDaysEl = document.getElementById("routeGenEstimatedDays");
    dom.estimatedDaysSubEl = document.getElementById("routeGenEstimatedDaysSub");
    dom.lockCountEl = document.getElementById("routeGenLockCount");
    dom.offshoreCountEl = document.getElementById("routeGenOffshoreCount");
    dom.estimatedFuelEl = document.getElementById("routeGenEstimatedFuel");
    dom.estimatedFuelSubEl = document.getElementById("routeGenEstimatedFuelSub");
    dom.fuelCostEl = document.getElementById("routeGenFuelCost");
    dom.fuelCostSubEl = document.getElementById("routeGenFuelCostSub");
    dom.legCountEl = document.getElementById("routeGenLegCount");
    dom.legListEl = document.getElementById("routeGenLegList");

    return true;
  }

  function reloadTimeline() {
    if (!state.activeRouteCode) {
      return Promise.resolve();
    }
    return loadExistingRoute(state.activeRouteCode);
  }

  function openEditorForRoute(routeCode) {
    if (!routeCode) return;
    openModal("editor", routeCode, { freshStart: false });
  }

  function init() {
    if (!cacheDom()) return;

    if (window.bootstrap && window.bootstrap.Modal) {
      modal = new window.bootstrap.Modal(dom.modalEl);
    }

    bindEvents();
    resetGeneratorState();
  }

  window.FPW.DashboardModules.routeBuilder = {
    init: init,
    reloadTimeline: reloadTimeline,
    openEditorForRoute: openEditorForRoute
  };
})(window, document);
