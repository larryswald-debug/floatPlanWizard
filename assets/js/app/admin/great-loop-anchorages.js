(function (window, document) {
  "use strict";

  var config = window.FPW_GREAT_LOOP_ANCHORAGES_ADMIN || {};
  var endpoint = config.endpoint || ((window.FPW_API_BASE || ((window.FPW_BASE || "") + "/api/v1")) + "/adminGreatLoopAnchorages.cfc?method=handle");
  var nonce = config.nonce || "";

  var defaultMapCenter = { lat: 39.5, lng: -82.5 };

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    requestSeq: 0,
    currentAnchorage: null,
    mode: "edit",
    map: null,
    marker: null
  };

  var els = {};
  var anchorageModal = null;

  function byId(id) {
    return document.getElementById(id);
  }

  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function toInt(value) {
    var n = parseInt(value, 10);
    return isNaN(n) ? 0 : n;
  }

  function boolValue(value) {
    return value === true || value === "true" || value === 1 || value === "1";
  }

  function getCoord(id) {
    var value = getValue(id);
    if (!value) return null;
    var n = parseFloat(value);
    return isNaN(n) ? null : n;
  }

  function hasValidCoords(lat, lng) {
    return lat !== null && lng !== null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  function formatCoord(value) {
    return Number(value).toFixed(7);
  }

  function showMessage(target, message, type) {
    if (!target) return;
    if (!message) {
      target.className = "msg";
      target.textContent = "";
      return;
    }
    target.className = "msg " + (type || "info");
    target.textContent = message;
  }

  async function callApi(action, payload) {
    var requestPayload = Object.assign({ action: action }, payload || {});
    var response = await fetch(endpoint + "&action=" + encodeURIComponent(action), {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json"
      },
      body: JSON.stringify(requestPayload)
    });

    var data = null;
    try {
      data = await response.json();
    } catch (jsonError) {
      data = {
        SUCCESS: false,
        MESSAGE: "Invalid JSON response.",
        ERROR: { MESSAGE: jsonError && jsonError.message ? jsonError.message : "Unable to parse JSON." }
      };
    }

    if (!response.ok && (!data || data.SUCCESS !== false)) {
      return {
        SUCCESS: false,
        MESSAGE: "Request failed with HTTP " + response.status,
        ERROR: { MESSAGE: "HTTP " + response.status }
      };
    }
    return data || { SUCCESS: false, MESSAGE: "Unknown API error." };
  }

  function collectFilters() {
    return {
      q: (els.filterSearch.value || "").trim(),
      locationGroup: els.filterLocationGroup.value || "",
      waterway: els.filterWaterway.value || "",
      stateProvince: els.filterStateProvince.value || "",
      country: els.filterCountry.value || "",
      anchorageType: els.filterAnchorageType.value || "",
      publicStatus: els.filterPublicStatus.value || "",
      verificationStatus: els.filterVerificationStatus.value || "",
      limit: toInt(els.filterLimit.value) || 50,
      offset: state.offset
    };
  }

  function setSelectOptions(selectEl, options) {
    var html = '<option value="">All</option>';
    (options || []).forEach(function (option) {
      html += '<option value="' + escapeHtml(option.value || "") + '">' + escapeHtml(option.label || option.value || "") + "</option>";
    });
    selectEl.innerHTML = html;
  }

  async function loadFacets() {
    try {
      var data = await callApi("facets", {});
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load filter options.");
      }
      var payload = data.DATA || {};
      setSelectOptions(els.filterLocationGroup, payload.locationGroups || []);
      setSelectOptions(els.filterWaterway, payload.waterways || []);
      setSelectOptions(els.filterStateProvince, payload.states || []);
      setSelectOptions(els.filterCountry, payload.countries || []);
      setSelectOptions(els.filterAnchorageType, payload.anchorageTypes || []);
      setSelectOptions(els.filterPublicStatus, payload.publicStatuses || []);
      setSelectOptions(els.filterVerificationStatus, payload.verificationStatuses || []);
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load filter options.", "error");
    }
  }

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " anchorage row(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = state.offset <= 0;
    els.nextPageBtn.disabled = state.offset + state.limit >= state.total;
  }

  function renderTable() {
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="12">No Great Loop anchorages found.</td></tr>';
      return;
    }

    els.tableBody.innerHTML = state.items.map(function (row) {
      var id = row.anchorage_id || "";
      var isPublished = boolValue(row.is_published);
      var coords = row.latitude !== "" && row.longitude !== "" ? formatCoord(row.latitude) + ", " + formatCoord(row.longitude) : "";
      return ""
        + "<tr>"
        + '  <td class="num">' + escapeHtml(id) + "</td>"
        + "  <td>" + escapeHtml(row.anchorage_name || "") + "</td>"
        + "  <td>" + escapeHtml(row.location_group || "") + "</td>"
        + "  <td>" + escapeHtml(row.waterway || "") + "</td>"
        + "  <td>" + escapeHtml(row.nearest_city || "") + "</td>"
        + "  <td>" + escapeHtml(row.state_province || "") + "</td>"
        + "  <td>" + escapeHtml(row.country || "") + "</td>"
        + "  <td>" + escapeHtml(row.anchorage_type || "") + "</td>"
        + '  <td><span class="badge-soft ' + (isPublished ? "ok" : "warn") + '">' + (isPublished ? "Published" : "Hidden") + "</span></td>"
        + "  <td>" + escapeHtml(row.verification_status || "") + "</td>"
        + "  <td>" + escapeHtml(coords) + "</td>"
        + '  <td class="actions">'
        + '    <button type="button" class="btn-inline" data-action="edit" data-anchorage-id="' + escapeHtml(id) + '">Edit</button> '
        + '    <button type="button" class="btn-inline danger" data-action="delete" data-anchorage-id="' + escapeHtml(id) + '">Delete</button>'
        + "  </td>"
        + "</tr>";
    }).join("");
  }

  async function loadAnchorages(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="12">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load anchorages.");
      }

      var payload = data.DATA || {};
      state.items = Array.isArray(payload.items) ? payload.items : [];
      state.total = toInt(payload.total) || 0;
      state.limit = toInt(payload.limit) || state.limit;
      state.offset = toInt(payload.offset) || 0;

      renderTable();
      updateSummaryLine();
      showMessage(els.message, "", "");
    } catch (err) {
      els.tableBody.innerHTML = '<tr><td colspan="12">Unable to load anchorages.</td></tr>';
      showMessage(els.message, err.message || "Unable to load anchorages.", "error");
    }
  }

  function setValue(id, value) {
    var el = byId(id);
    if (el) el.value = value === null || value === undefined ? "" : value;
  }

  function getValue(id) {
    var el = byId(id);
    return el ? (el.value || "").trim() : "";
  }

  function setChecked(id, value) {
    var el = byId(id);
    if (el) el.checked = boolValue(value);
  }

  function setModalCoords(lat, lng) {
    setValue("modalLatitude", formatCoord(lat));
    setValue("modalLongitude", formatCoord(lng));
    setMapMarker(lat, lng);
  }

  function fillForm(anchorage) {
    setValue("modalAnchorageId", anchorage.anchorage_id || "");
    setValue("modalAnchorageIdDisplay", anchorage.anchorage_id || "(new)");
    setValue("modalAnchorageName", anchorage.anchorage_name || "");
    setValue("modalSlug", anchorage.slug || "");
    setValue("modalLocationGroup", anchorage.location_group || "");
    setValue("modalWaterway", anchorage.waterway || "");
    setValue("modalNearestCity", anchorage.nearest_city || "");
    setValue("modalStateProvince", anchorage.state_province || "");
    setValue("modalCountry", anchorage.country || "");
    setValue("modalAnchorageType", anchorage.anchorage_type || "");
    setValue("modalPublicStatus", anchorage.public_status || "");
    setValue("modalHolding", anchorage.holding || "");
    setValue("modalProtection", anchorage.protection || "");
    setValue("modalShoreAccess", anchorage.shore_access || "");
    setValue("modalVerificationStatus", anchorage.verification_status || "needs_verification");
    setValue("modalLatitude", anchorage.latitude === null || anchorage.latitude === undefined ? "" : anchorage.latitude);
    setValue("modalLongitude", anchorage.longitude === null || anchorage.longitude === undefined ? "" : anchorage.longitude);
    setValue("modalSourceName", anchorage.source_name || "");
    setValue("modalSourceUrl", anchorage.source_url || "");
    setValue("modalGreatLoopRelevance", anchorage.great_loop_relevance || "");
    setValue("modalDuplicateReviewNote", anchorage.duplicate_review_note || "");
    setValue("modalLastReviewed", anchorage.last_reviewed || "");
    setValue("modalReviewedBy", anchorage.reviewed_by || "");
    setValue("modalReviewedAt", (anchorage.reviewed_at || "").replace(" ", "T"));
    setChecked("modalIsPublished", anchorage.is_published);
    setValue("modalNotes", anchorage.notes || "");
    setValue("modalNavWarning", anchorage.nav_warning || "");
    setValue("modalReviewerNotes", anchorage.reviewer_notes || "");

    state.currentAnchorage = anchorage;
    els.modalLabel.textContent = anchorage.anchorage_id ? (anchorage.anchorage_name || anchorage.anchorage_id) : "New Great Loop Anchorage";
    els.deleteBtn.hidden = !anchorage.anchorage_id;
    showMessage(els.modalMessage, "", "");
    closeMapPanel();
  }

  function collectAnchoragePayload() {
    return {
      anchorage_id: getValue("modalAnchorageId"),
      anchorage_name: getValue("modalAnchorageName"),
      slug: getValue("modalSlug"),
      location_group: getValue("modalLocationGroup"),
      waterway: getValue("modalWaterway"),
      nearest_city: getValue("modalNearestCity"),
      state_province: getValue("modalStateProvince"),
      country: getValue("modalCountry"),
      anchorage_type: getValue("modalAnchorageType"),
      public_status: getValue("modalPublicStatus"),
      holding: getValue("modalHolding"),
      protection: getValue("modalProtection"),
      shore_access: getValue("modalShoreAccess"),
      verification_status: getValue("modalVerificationStatus"),
      latitude: getValue("modalLatitude"),
      longitude: getValue("modalLongitude"),
      source_name: getValue("modalSourceName"),
      source_url: getValue("modalSourceUrl"),
      great_loop_relevance: getValue("modalGreatLoopRelevance"),
      duplicate_review_note: getValue("modalDuplicateReviewNote"),
      last_reviewed: getValue("modalLastReviewed"),
      reviewed_by: getValue("modalReviewedBy"),
      reviewed_at: getValue("modalReviewedAt"),
      is_published: byId("modalIsPublished").checked ? 1 : 0,
      notes: getValue("modalNotes"),
      nav_warning: getValue("modalNavWarning"),
      reviewer_notes: getValue("modalReviewerNotes")
    };
  }

  function newAnchorageTemplate() {
    return {
      anchorage_id: "",
      anchorage_name: "",
      slug: "",
      location_group: "",
      verification_status: "needs_verification",
      is_published: 0
    };
  }

  async function openEditModal(anchorageId) {
    showMessage(els.message, "", "");
    showMessage(els.modalMessage, "", "");
    try {
      var data = await callApi("get", { id: anchorageId });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load anchorage.");
      }
      state.mode = "edit";
      fillForm((data.DATA || {}).anchorage || {});
      anchorageModal.show();
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load anchorage.", "error");
    }
  }

  function openNewModal() {
    state.mode = "create";
    fillForm(newAnchorageTemplate());
    anchorageModal.show();
  }

  async function saveCurrentAnchorage() {
    var payload = collectAnchoragePayload();
    var action = state.mode === "create" || !payload.anchorage_id ? "create" : "save";
    els.saveBtn.disabled = true;
    showMessage(els.modalMessage, "Saving...", "info");

    try {
      var data = await callApi(action, { nonce: nonce, anchorage: payload });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to save anchorage.");
      }

      var savedAnchorage = (data.DATA || {}).anchorage || {};
      state.mode = "edit";
      fillForm(savedAnchorage);
      await loadFacets();
      await loadAnchorages(false);
      anchorageModal.hide();
      showMessage(els.message, data.MESSAGE || "Anchorage saved.", "success");
    } catch (err) {
      showMessage(els.modalMessage, err.message || "Unable to save anchorage.", "error");
    } finally {
      els.saveBtn.disabled = false;
    }
  }

  async function deleteAnchorageById(anchorageId) {
    if (!anchorageId) return;
    var confirmation = window.prompt("Type " + anchorageId + " to permanently delete this anchorage row.");
    if (confirmation === null) return;

    showMessage(els.message, "Deleting anchorage...", "info");
    try {
      var data = await callApi("delete", { nonce: nonce, id: anchorageId, confirmation: confirmation });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to delete anchorage.");
      }
      if (anchorageModal) anchorageModal.hide();
      await loadFacets();
      await loadAnchorages(true);
      showMessage(els.message, data.MESSAGE || "Anchorage deleted.", "success");
    } catch (err) {
      showMessage(els.modal && els.modal.classList.contains("show") ? els.modalMessage : els.message, err.message || "Unable to delete anchorage.", "error");
    }
  }

  function closeMapPanel() {
    if (els.mapPanel) els.mapPanel.hidden = true;
    if (els.toggleMapBtn) els.toggleMapBtn.textContent = "Open Map";
    destroyMap();
  }

  function toggleMapPanel() {
    if (!els.mapPanel) return;
    els.mapPanel.hidden = !els.mapPanel.hidden;
    els.toggleMapBtn.textContent = els.mapPanel.hidden ? "Open Map" : "Close Map";
    if (!els.mapPanel.hidden) {
      ensureMap();
    } else {
      destroyMap();
    }
  }

  function ensureMap() {
    if (!window.L || !els.mapEl) {
      showMessage(els.modalMessage, "Leaflet map is not available. Latitude and longitude can still be edited manually.", "error");
      return;
    }

    if (!state.map) {
      state.map = window.L.map(els.mapEl, { zoomControl: true, attributionControl: true });
      window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "&copy; OpenStreetMap contributors"
      }).addTo(state.map);
      state.map.on("click", function (event) {
        if (!event || !event.latlng) return;
        setModalCoords(event.latlng.lat, event.latlng.lng);
      });
    }

    syncMapFromForm();
    setTimeout(function () {
      if (state.map) state.map.invalidateSize();
    }, 0);
  }

  function syncMapFromForm() {
    if (!state.map || !window.L) return;
    var lat = getCoord("modalLatitude");
    var lng = getCoord("modalLongitude");

    if (hasValidCoords(lat, lng)) {
      state.map.setView([lat, lng], 15);
      setMapMarker(lat, lng);
    } else {
      state.map.setView([defaultMapCenter.lat, defaultMapCenter.lng], 5);
      clearMapMarker();
    }
  }

  function setMapMarker(lat, lng) {
    if (!state.map || !window.L) return;
    if (!state.marker) {
      state.marker = window.L.marker([lat, lng], { draggable: true }).addTo(state.map);
      state.marker.on("dragend", function (event) {
        if (!event || !event.target) return;
        var next = event.target.getLatLng();
        setModalCoords(next.lat, next.lng);
      });
    } else {
      state.marker.setLatLng([lat, lng]);
      if (!state.map.hasLayer(state.marker)) {
        state.marker.addTo(state.map);
      }
    }
  }

  function clearMapMarker() {
    if (!state.marker) return;
    state.marker.remove();
    state.marker = null;
  }

  function destroyMap() {
    if (!state.map) return;
    state.map.off();
    state.map.remove();
    state.map = null;
    state.marker = null;
  }

  function bindEvents() {
    els.filtersForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadAnchorages(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterSearch.value = "";
      els.filterLocationGroup.value = "";
      els.filterWaterway.value = "";
      els.filterStateProvince.value = "";
      els.filterCountry.value = "";
      els.filterAnchorageType.value = "";
      els.filterPublicStatus.value = "";
      els.filterVerificationStatus.value = "";
      els.filterLimit.value = "50";
      state.offset = 0;
      loadAnchorages(true);
    });

    els.addAnchorageBtn.addEventListener("click", openNewModal);

    els.prevPageBtn.addEventListener("click", function () {
      state.offset = Math.max(0, state.offset - state.limit);
      loadAnchorages(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      state.offset += state.limit;
      loadAnchorages(false);
    });

    els.tableBody.addEventListener("click", function (event) {
      var btn = event.target.closest("[data-action]");
      if (!btn) return;
      var anchorageId = btn.getAttribute("data-anchorage-id") || "";
      if (btn.getAttribute("data-action") === "edit") {
        openEditModal(anchorageId);
      } else if (btn.getAttribute("data-action") === "delete") {
        deleteAnchorageById(anchorageId);
      }
    });

    els.saveBtn.addEventListener("click", saveCurrentAnchorage);
    els.deleteBtn.addEventListener("click", function () {
      deleteAnchorageById(getValue("modalAnchorageId"));
    });
    els.toggleMapBtn.addEventListener("click", toggleMapPanel);
    els.modalLatitude.addEventListener("change", function () {
      if (state.map) syncMapFromForm();
    });
    els.modalLongitude.addEventListener("change", function () {
      if (state.map) syncMapFromForm();
    });
    els.modal.addEventListener("hidden.bs.modal", function () {
      closeMapPanel();
    });
  }

  function cacheElements() {
    els.message = byId("greatLoopAnchoragesMessage");
    els.filtersForm = byId("greatLoopAnchoragesFilters");
    els.filterSearch = byId("filterSearch");
    els.filterLocationGroup = byId("filterLocationGroup");
    els.filterWaterway = byId("filterWaterway");
    els.filterStateProvince = byId("filterStateProvince");
    els.filterCountry = byId("filterCountry");
    els.filterAnchorageType = byId("filterAnchorageType");
    els.filterPublicStatus = byId("filterPublicStatus");
    els.filterVerificationStatus = byId("filterVerificationStatus");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.addAnchorageBtn = byId("addAnchorageBtn");
    els.summaryLine = byId("greatLoopAnchoragesSummaryLine");
    els.tableBody = byId("greatLoopAnchoragesTableBody");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");
    els.modal = byId("greatLoopAnchorageModal");
    els.modalLabel = byId("greatLoopAnchorageModalLabel");
    els.modalMessage = byId("greatLoopAnchorageModalMessage");
    els.saveBtn = byId("saveGreatLoopAnchorageBtn");
    els.deleteBtn = byId("deleteGreatLoopAnchorageBtn");
    els.toggleMapBtn = byId("toggleAnchorageMapBtn");
    els.mapPanel = byId("anchorageMapPanel");
    els.mapEl = byId("adminAnchorageMap");
    els.modalLatitude = byId("modalLatitude");
    els.modalLongitude = byId("modalLongitude");
  }

  function init() {
    cacheElements();
    if (!els.filtersForm || !els.tableBody || !els.modal || !window.bootstrap) {
      return;
    }
    anchorageModal = new window.bootstrap.Modal(els.modal);
    bindEvents();
    loadFacets().then(function () {
      return loadAnchorages(true);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
