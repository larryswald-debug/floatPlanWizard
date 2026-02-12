(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var BASE_PATH = window.FPW_BASE || "";
  var TEMPLATE_CODE = "GREAT_LOOP_CCW";

  var modalEl = null;
  var modal = null;
  var openBtn = null;
  var formEl = null;
  var startDateEl = null;
  var startLocationEl = null;
  var endLocationEl = null;
  var generateBtn = null;
  var backBtn = null;
  var saveBtn = null;
  var doneBtn = null;
  var step1El = null;
  var step2El = null;
  var alertEl = null;
  var statusEl = null;
  var summaryEl = null;
  var routeNameEl = null;
  var routeCodeEl = null;
  var timelineEl = null;
  var locationsListEl = null;
  var saveIndicatorEl = null;

  var currentRouteCode = "";
  var currentTimeline = null;
  var knownLocations = [];
  var loadSeq = 0;
  var saveSeq = 0;
  var originalSegments = {};
  var isDirty = false;
  var isSaving = false;

  function escapeHtml(value) {
    if (utils.escapeHtml) return utils.escapeHtml(value);
    return String(value === undefined || value === null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatNum(value, decimals) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "0";
    var places = (typeof decimals === "number") ? decimals : 0;
    return n.toLocaleString(undefined, {
      minimumFractionDigits: places,
      maximumFractionDigits: places
    });
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

  function notifyRoutesUpdated(routeCode) {
    if (!document || typeof window.CustomEvent !== "function") return;
    document.dispatchEvent(new window.CustomEvent("fpw:routes-updated", {
      detail: { routeCode: routeCode || "" }
    }));
  }

  function fetchJson(url, options) {
    return fetch(url, options || { credentials: "same-origin" })
      .then(function (res) {
        if (res.status === 401 || res.status === 403) {
          var authErr = new Error("Unauthorized");
          authErr.code = "UNAUTHORIZED";
          throw authErr;
        }
        return res.json();
      });
  }

  function showAlert(message, type) {
    if (!alertEl) return;
    alertEl.classList.remove("d-none", "alert-danger", "alert-warning", "alert-success", "alert-info");
    alertEl.classList.add("alert-" + (type || "warning"));
    alertEl.textContent = message || "";
    if (!message) {
      alertEl.classList.add("d-none");
    }
  }

  function clearAlert() {
    showAlert("", "info");
  }

  function setStatus(text) {
    if (!statusEl) return;
    statusEl.textContent = text || "";
  }

  function setSavingIndicator(text) {
    if (!saveIndicatorEl) return;
    saveIndicatorEl.textContent = text || "";
  }

  function setStep(stepNum) {
    if (!step1El || !step2El) return;
    if (stepNum === 1) {
      step1El.classList.remove("d-none");
      step2El.classList.add("d-none");
      if (backBtn) backBtn.classList.add("d-none");
      if (saveBtn) saveBtn.classList.add("d-none");
      if (doneBtn) doneBtn.classList.add("d-none");
      if (generateBtn) generateBtn.classList.remove("d-none");
    } else {
      step1El.classList.add("d-none");
      step2El.classList.remove("d-none");
      if (backBtn) backBtn.classList.remove("d-none");
      if (saveBtn) saveBtn.classList.remove("d-none");
      if (doneBtn) doneBtn.classList.remove("d-none");
      if (generateBtn) generateBtn.classList.add("d-none");
    }
  }

  function normalizeFieldValue(field, value) {
    if (field === "lock_count") {
      var i = parseInt(value, 10);
      return Number.isFinite(i) ? String(i) : "";
    }
    if (field === "dist_nm") {
      var n = parseFloat(value);
      return Number.isFinite(n) ? String(n) : "";
    }
    return String(value === undefined || value === null ? "" : value).trim();
  }

  function rebuildOriginalSegments(payload) {
    originalSegments = {};
    var sections = payload && Array.isArray(payload.SECTIONS) ? payload.SECTIONS : [];
    var i;
    var j;
    for (i = 0; i < sections.length; i += 1) {
      var segs = Array.isArray(sections[i].SEGMENTS) ? sections[i].SEGMENTS : [];
      for (j = 0; j < segs.length; j += 1) {
        var seg = segs[j] || {};
        var id = parseInt(seg.ID, 10);
        if (!id) continue;
        originalSegments[id] = {
          start_name: normalizeFieldValue("start_name", seg.START_NAME),
          end_name: normalizeFieldValue("end_name", seg.END_NAME),
          dist_nm: normalizeFieldValue("dist_nm", seg.DIST_NM),
          lock_count: normalizeFieldValue("lock_count", seg.LOCK_COUNT),
          notes: normalizeFieldValue("notes", seg.NOTES)
        };
      }
    }
  }

  function markDirty(flag) {
    isDirty = !!flag;
    if (isDirty) {
      setSavingIndicator("Unsaved changes");
    } else if (!isSaving) {
      setSavingIndicator("");
    }
  }

  function collectChangesBySegment() {
    var changes = {};
    if (!timelineEl) return changes;
    var segments = timelineEl.querySelectorAll(".routebuilder-segment");
    var sIdx;
    for (sIdx = 0; sIdx < segments.length; sIdx += 1) {
      var wrap = segments[sIdx];
      var segmentId = parseInt(wrap.getAttribute("data-segment-id"), 10);
      if (!segmentId || !originalSegments[segmentId]) continue;
      var inputs = wrap.querySelectorAll(".rb-seg-input");
      var idx;
      for (idx = 0; idx < inputs.length; idx += 1) {
        var input = inputs[idx];
        var field = input.getAttribute("data-field");
        if (!field) continue;
        var edited = normalizeFieldValue(field, input.value);
        var baseline = normalizeFieldValue(field, originalSegments[segmentId][field]);
        if (edited !== baseline) {
          if (!changes[segmentId]) changes[segmentId] = {};
          changes[segmentId][field] = (field === "notes" ? input.value : edited);
        }
      }
    }
    return changes;
  }

  function confirmDiscardIfDirty() {
    if (!isDirty) return Promise.resolve(true);
    if (utils.showConfirmModal) {
      return utils.showConfirmModal("You have unsaved route changes. Discard changes?");
    }
    return Promise.resolve(window.confirm("You have unsaved route changes. Discard changes?"));
  }

  function collectKnownLocationsFromTimeline(payload) {
    var seen = {};
    var ordered = [];
    var sections = payload && Array.isArray(payload.SECTIONS) ? payload.SECTIONS : [];
    var i;
    var j;
    var a;
    var b;

    function addInRouteOrder(name) {
      if (!name) return;
      if (seen[name]) return;
      seen[name] = true;
      ordered.push(name);
    }

    for (i = 0; i < sections.length; i += 1) {
      var segs = Array.isArray(sections[i].SEGMENTS) ? sections[i].SEGMENTS : [];
      for (j = 0; j < segs.length; j += 1) {
        a = (segs[j].START_NAME || "").toString().trim();
        b = (segs[j].END_NAME || "").toString().trim();
        addInRouteOrder(a);
        addInRouteOrder(b);
      }
    }
    knownLocations = ordered;
    renderLocationDatalist();
  }

  function renderLocationDatalist() {
    if (!locationsListEl) return;
    locationsListEl.innerHTML = knownLocations.map(function (name) {
      return '<option value="' + escapeHtml(name) + '"></option>';
    }).join("");
  }

  function renderSummary(payload) {
    if (!summaryEl || !routeNameEl || !routeCodeEl) return;
    var totals = payload && payload.TOTALS ? payload.TOTALS : {};
    var route = payload && payload.ROUTE ? payload.ROUTE : {};
    summaryEl.textContent = formatNum(totals.TOTAL_NM, 1) + " NM • " + formatNum(totals.TOTAL_LOCKS, 0) + " locks • " + formatNum(totals.PCT_COMPLETE, 0) + "% complete";
    routeNameEl.textContent = route.NAME || "Generated Route";
    routeCodeEl.textContent = (payload && payload.ROUTE_CODE) ? payload.ROUTE_CODE : (route.SHORT_CODE || "");
  }

  function renderTimelineEditor(payload) {
    if (!timelineEl) return;
    var sections = payload && Array.isArray(payload.SECTIONS) ? payload.SECTIONS : [];
    var html = "";
    var i;
    for (i = 0; i < sections.length; i += 1) {
      var sec = sections[i] || {};
      var secId = "routeBuilderSection" + i;
      var headingId = secId + "Heading";
      var collapseId = secId + "Collapse";
      var show = (sec.IS_ACTIVE_DEFAULT || i === 0) ? "show" : "";
      var segs = Array.isArray(sec.SEGMENTS) ? sec.SEGMENTS : [];
      var segHtml = "";
      var j;
      for (j = 0; j < segs.length; j += 1) {
        var seg = segs[j] || {};
        var segmentId = seg.ID || 0;
        segHtml += ''
          + '<div class="routebuilder-segment" data-segment-id="' + escapeHtml(segmentId) + '">'
          + '  <div class="routebuilder-segment-row">'
          + '    <div class="routebuilder-field">'
          + '      <label>Start</label>'
          + '      <input class="form-control form-control-sm rb-seg-input" list="routeBuilderLocations" data-field="start_name" value="' + escapeHtml(seg.START_NAME || "") + '">'
          + '    </div>'
          + '    <div class="routebuilder-field">'
          + '      <label>End</label>'
          + '      <input class="form-control form-control-sm rb-seg-input" list="routeBuilderLocations" data-field="end_name" value="' + escapeHtml(seg.END_NAME || "") + '">'
          + '    </div>'
          + '    <div class="routebuilder-field routebuilder-field-sm">'
          + '      <label>NM</label>'
          + '      <input class="form-control form-control-sm rb-seg-input" type="number" step="0.1" data-field="dist_nm" value="' + escapeHtml(seg.DIST_NM) + '">'
          + '    </div>'
          + '    <div class="routebuilder-field routebuilder-field-sm">'
          + '      <label>Locks</label>'
          + '      <input class="form-control form-control-sm rb-seg-input" type="number" step="1" data-field="lock_count" value="' + escapeHtml(seg.LOCK_COUNT) + '">'
          + '    </div>'
          + '  </div>'
          + '  <div class="routebuilder-segment-row">'
          + '    <div class="routebuilder-field routebuilder-field-notes">'
          + '      <label>Notes</label>'
          + '      <input class="form-control form-control-sm rb-seg-input" data-field="notes" value="' + escapeHtml(seg.NOTES || "") + '">'
          + '    </div>'
          + '  </div>'
          + '</div>';
      }
      if (!segHtml) {
        segHtml = '<div class="routebuilder-empty">No segments in this section.</div>';
      }

      html += ''
        + '<div class="accordion-item">'
        + '  <h2 class="accordion-header" id="' + headingId + '">'
        + '    <button class="accordion-button ' + (show ? "" : "collapsed") + '" type="button" data-bs-toggle="collapse" data-bs-target="#' + collapseId + '" aria-expanded="' + (show ? "true" : "false") + '" aria-controls="' + collapseId + '">'
        + '      <span class="routebuilder-section-title">' + escapeHtml(sec.NAME || "Section") + '</span>'
        + '      <span class="routebuilder-section-meta">' + formatNum(sec.TOTALS && sec.TOTALS.NM, 1) + ' NM • ' + formatNum(sec.TOTALS && sec.TOTALS.LOCKS, 0) + ' locks</span>'
        + '    </button>'
        + '  </h2>'
        + '  <div id="' + collapseId + '" class="accordion-collapse collapse ' + show + '" aria-labelledby="' + headingId + '" data-bs-parent="#routeBuilderTimelineEditor">'
        + '    <div class="accordion-body">' + segHtml + '</div>'
        + '  </div>'
        + '</div>';
    }
    timelineEl.innerHTML = html || '<div class="routebuilder-empty">No timeline data.</div>';
  }

  function renderWarnings(payload) {
    var warnings = payload && Array.isArray(payload.WARNINGS) ? payload.WARNINGS : [];
    if (warnings.length) {
      showAlert(warnings.join(" "), "warning");
    } else {
      clearAlert();
    }
  }

  function loadTemplateLocations() {
    return fetchJson(apiUrl("getTimeline", { routeCode: TEMPLATE_CODE }), { credentials: "same-origin" })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) return;
        collectKnownLocationsFromTimeline(payload);
      })
      .catch(function () {
        // best effort only
      });
  }

  function readStep1() {
    return {
      startDate: startDateEl ? String(startDateEl.value || "").trim() : "",
      startLocation: startLocationEl ? String(startLocationEl.value || "").trim() : "",
      endLocation: endLocationEl ? String(endLocationEl.value || "").trim() : ""
    };
  }

  function validateStep1(input) {
    if (!input.startDate || !input.startLocation || !input.endLocation) {
      showAlert("Start date, start location, and planned end location are required.", "danger");
      return false;
    }
    return true;
  }

  function generateRoute() {
    var input = readStep1();
    if (!validateStep1(input)) return;
    clearAlert();
    setStatus("Generating route...");
    setSavingIndicator("");
    loadSeq += 1;
    var seq = loadSeq;

    fetchJson(apiUrl("generateRoute"), {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input)
    })
      .then(function (payload) {
        if (seq !== loadSeq) return;
        if (!payload || payload.SUCCESS === false) {
          if (payload && payload.AUTH === false) {
            throw new Error("Unauthorized. Please log in again.");
          }
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to generate route.");
        }
        currentRouteCode = payload.ROUTE_CODE || (payload.ROUTE && payload.ROUTE.SHORT_CODE) || "";
        currentTimeline = payload;
        collectKnownLocationsFromTimeline(payload);
        renderWarnings(payload);
        renderSummary(payload);
        renderTimelineEditor(payload);
        rebuildOriginalSegments(payload);
        markDirty(false);
        setStatus("Route generated.");
        setStep(2);
        notifyRoutesUpdated(currentRouteCode);
      })
      .catch(function (err) {
        showAlert((err && err.message) ? err.message : "Unable to generate route.", "danger");
        setStatus("");
      });
  }

  function reloadTimeline() {
    if (!currentRouteCode) return Promise.resolve();
    setStatus("Refreshing...");
    return fetchJson(apiUrl("getTimeline", { routeCode: currentRouteCode }), { credentials: "same-origin" })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to refresh route.");
        }
        currentTimeline = payload;
        renderSummary(payload);
        renderTimelineEditor(payload);
        rebuildOriginalSegments(payload);
        markDirty(false);
        setStatus("Saved.");
      })
      .catch(function (err) {
        showAlert((err && err.message) ? err.message : "Unable to refresh route.", "danger");
        throw err;
      });
  }

  function setActiveRoute(routeCode) {
    if (!routeCode) return Promise.resolve();
    return fetchJson(apiUrl("setActiveRoute", { routeCode: routeCode }), { credentials: "same-origin" })
      .catch(function () {
        return null;
      });
  }

  function saveSegmentChanges(segmentId, changedFields) {
    var payload = {
      routeCode: currentRouteCode,
      segmentId: segmentId
    };
    Object.keys(changedFields || {}).forEach(function (field) {
      payload[field] = changedFields[field];
    });

    return fetchJson(apiUrl("updateSegment"), {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    })
      .then(function (res) {
        if (!res || res.SUCCESS === false) {
          throw new Error((res && res.MESSAGE) ? res.MESSAGE : "Save failed.");
        }
        return res;
      });
  }

  function saveAllChanges() {
    if (!currentRouteCode) return Promise.resolve(false);
    if (isSaving) return Promise.resolve(false);
    var changesBySegment = collectChangesBySegment();
    var segmentIds = Object.keys(changesBySegment);
    if (!segmentIds.length) {
      markDirty(false);
      setStatus("No changes to save.");
      return Promise.resolve(false);
    }

    isSaving = true;
    saveSeq += 1;
    var seq = saveSeq;
    setSavingIndicator("Saving...");
    clearAlert();

    var chain = Promise.resolve();
    segmentIds.forEach(function (segId) {
      chain = chain.then(function () {
        return saveSegmentChanges(parseInt(segId, 10), changesBySegment[segId]);
      });
    });

    return chain
      .then(function () {
        if (seq !== saveSeq) return;
        setSavingIndicator("Saved");
        isSaving = false;
        return reloadTimeline().then(function () {
          window.setTimeout(function () {
            if (seq === saveSeq && !isDirty) setSavingIndicator("");
          }, 1000);
          return true;
        });
      })
      .catch(function (err) {
        isSaving = false;
        showAlert((err && err.message) ? err.message : "Unable to save segment.", "danger");
        setSavingIndicator("Unsaved changes");
        throw err;
      });
  }

  function resetModal() {
    currentRouteCode = "";
    currentTimeline = null;
    originalSegments = {};
    setStep(1);
    setStatus("");
    markDirty(false);
    clearAlert();
    if (summaryEl) summaryEl.textContent = "—";
    if (routeNameEl) routeNameEl.textContent = "Generated Route";
    if (routeCodeEl) routeCodeEl.textContent = "";
    if (timelineEl) timelineEl.innerHTML = "";
  }

  function openModal() {
    if (!modalEl || !modal) return;
    resetModal();
    if (startDateEl && !startDateEl.value) {
      var d = new Date();
      var yyyy = d.getFullYear();
      var mm = String(d.getMonth() + 1).padStart(2, "0");
      var dd = String(d.getDate()).padStart(2, "0");
      startDateEl.value = yyyy + "-" + mm + "-" + dd;
    }
    modal.show();
  }

  function openEditorForRoute(routeCode) {
    if (!routeCode || !modal) return;
    resetModal();
    currentRouteCode = String(routeCode);
    clearAlert();
    setStatus("Loading route...");
    setStep(2);
    modal.show();
    setActiveRoute(currentRouteCode);
    fetchJson(apiUrl("getTimeline", { routeCode: currentRouteCode }), { credentials: "same-origin" })
      .then(function (payload) {
        if (!payload || payload.SUCCESS === false) {
          throw new Error((payload && payload.MESSAGE) ? payload.MESSAGE : "Unable to load route.");
        }
        currentTimeline = payload;
        collectKnownLocationsFromTimeline(payload);
        renderWarnings(payload);
        renderSummary(payload);
        renderTimelineEditor(payload);
        rebuildOriginalSegments(payload);
        markDirty(false);
        setStatus("Route loaded.");
      })
      .catch(function (err) {
        showAlert((err && err.message) ? err.message : "Unable to load route.", "danger");
        setStatus("");
      });
  }

  function onEditorInput(event) {
    var target = event.target;
    if (!target || !target.classList || !target.classList.contains("rb-seg-input")) return;
    if (step2El && !step2El.classList.contains("d-none")) {
      markDirty(true);
      setStatus("You have unsaved changes.");
    }
  }

  function bindEvents() {
    if (openBtn) {
      openBtn.addEventListener("click", function () {
        openModal();
      });
    }
    if (formEl) {
      formEl.addEventListener("submit", function (e) {
        e.preventDefault();
        if (step1El && !step1El.classList.contains("d-none")) {
          generateRoute();
        } else {
          saveAllChanges();
        }
      });
    }
    if (generateBtn) {
      generateBtn.addEventListener("click", function () {
        generateRoute();
      });
    }
    if (backBtn) {
      backBtn.addEventListener("click", function () {
        confirmDiscardIfDirty().then(function (confirmed) {
          if (!confirmed) return;
          markDirty(false);
          setStep(1);
        });
      });
    }
    if (saveBtn) {
      saveBtn.addEventListener("click", function () {
        saveAllChanges();
      });
    }
    if (doneBtn) {
      doneBtn.addEventListener("click", function () {
        var maybeSave = isDirty ? saveAllChanges() : Promise.resolve(false);
        maybeSave.then(function () {
          if (modal) modal.hide();
          notifyRoutesUpdated(currentRouteCode);
        });
      });
    }
    if (timelineEl) {
      timelineEl.addEventListener("input", onEditorInput, true);
      timelineEl.addEventListener("change", onEditorInput, true);
    }
    if (modalEl && !modalEl.dataset.rbListeners) {
      modalEl.addEventListener("click", function (e) {
        var dismissBtn = e.target && e.target.closest ? e.target.closest('[data-bs-dismiss="modal"]') : null;
        if (!dismissBtn || !isDirty) return;
        e.preventDefault();
        e.stopPropagation();
        confirmDiscardIfDirty().then(function (confirmed) {
          if (!confirmed) return;
          markDirty(false);
          if (modal) modal.hide();
        });
      }, true);
      modalEl.addEventListener("hidden.bs.modal", function () {
        resetModal();
      });
      modalEl.dataset.rbListeners = "true";
    }
  }

  function init() {
    modalEl = document.getElementById("routeBuilderModal");
    openBtn = document.getElementById("openRouteBuilderBtn");
    if (!modalEl || !openBtn) return;

    if (window.bootstrap && window.bootstrap.Modal) {
      modal = new window.bootstrap.Modal(modalEl);
    }

    formEl = document.getElementById("routeBuilderForm");
    startDateEl = document.getElementById("routeBuilderStartDate");
    startLocationEl = document.getElementById("routeBuilderStartLocation");
    endLocationEl = document.getElementById("routeBuilderEndLocation");
    generateBtn = document.getElementById("routeBuilderGenerateBtn");
    backBtn = document.getElementById("routeBuilderBackBtn");
    saveBtn = document.getElementById("routeBuilderSaveBtn");
    doneBtn = document.getElementById("routeBuilderDoneBtn");
    step1El = document.getElementById("routeBuilderStep1");
    step2El = document.getElementById("routeBuilderStep2");
    alertEl = document.getElementById("routeBuilderAlert");
    statusEl = document.getElementById("routeBuilderStatus");
    summaryEl = document.getElementById("routeBuilderSummary");
    routeNameEl = document.getElementById("routeBuilderRouteName");
    routeCodeEl = document.getElementById("routeBuilderRouteCode");
    timelineEl = document.getElementById("routeBuilderTimelineEditor");
    locationsListEl = document.getElementById("routeBuilderLocations");
    saveIndicatorEl = document.getElementById("routeBuilderSaveIndicator");

    bindEvents();
    loadTemplateLocations();
    resetModal();
  }

  window.FPW.DashboardModules.routeBuilder = {
    init: init,
    reloadTimeline: reloadTimeline,
    openEditorForRoute: openEditorForRoute
  };
})(window, document);
