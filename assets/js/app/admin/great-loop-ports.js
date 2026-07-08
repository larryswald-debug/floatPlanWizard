(function (window, document) {
  "use strict";

  var config = window.FPW_GREAT_LOOP_PORTS_ADMIN || {};
  var endpoint = config.endpoint || ((window.FPW_API_BASE || ((window.FPW_BASE || "") + "/api/v1")) + "/adminGreatLoopPorts.cfc?method=handle");
  var nonce = config.nonce || "";
  var defaultCenter = { lat: 27.8, lng: -82.7 };

  var serviceFields = [
    "fuel_available",
    "diesel_available",
    "gas_available",
    "pumpout_available",
    "transient_dockage_available",
    "anchorage_available",
    "mooring_available",
    "provisioning_available",
    "restaurants_nearby",
    "marine_supply_nearby",
    "laundry_nearby",
    "transportation_nearby"
  ];

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    requestSeq: 0,
    currentPort: null
  };

  var els = {};
  var portModal = null;
  var mapController = null;

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

  function toFloat(value) {
    var n = parseFloat(value);
    return isNaN(n) ? null : n;
  }

  function hasCoord(lat, lng) {
    return typeof lat === "number" && !isNaN(lat) && typeof lng === "number" && !isNaN(lng);
  }

  function fmtCoord(value) {
    var n = toFloat(value);
    if (n === null) return "";
    return n.toFixed(7);
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
      state: els.filterState.value || "",
      loopSegment: els.filterLoopSegment.value || "",
      waterway: els.filterWaterway.value || "",
      qualityStatus: els.filterQualityStatus.value || "",
      coordStatus: els.filterCoordStatus.value || "",
      imageStatus: els.filterImageStatus.value || "",
      limit: toInt(els.filterLimit.value) || 50,
      offset: state.offset
    };
  }

  function setSelectOptions(selectEl, options, labelAll) {
    var html = '<option value="">' + escapeHtml(labelAll || "All") + '</option>';
    (options || []).forEach(function (option) {
      html += '<option value="' + escapeHtml(option.value || "") + '">' + escapeHtml(option.label || option.value || "") + "</option>";
    });
    selectEl.innerHTML = html;
  }

  function setServiceSelectOptions() {
    serviceFields.forEach(function (fieldName) {
      var selectEl = document.querySelector('[data-service-field="' + fieldName + '"]');
      if (!selectEl) return;
      selectEl.innerHTML = ""
        + '<option value="">Unknown</option>'
        + '<option value="1">Yes</option>'
        + '<option value="0">No</option>';
    });
  }

  async function loadFacets() {
    try {
      var data = await callApi("facets", {});
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load filter options.");
      }
      var payload = data.DATA || {};
      setSelectOptions(els.filterState, payload.states || []);
      setSelectOptions(els.filterLoopSegment, payload.loopSegments || []);
      setSelectOptions(els.filterWaterway, payload.waterways || []);
      setSelectOptions(els.filterQualityStatus, payload.qualityStatuses || []);
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load filter options.", "error");
    }
  }

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " Great Loop port(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = state.offset <= 0;
    els.nextPageBtn.disabled = state.offset + state.limit >= state.total;
  }

  function renderRowImage(row) {
    var image = row && row.image ? row.image : {};
    var hasImage = image.hasImage === true || image.hasImage === "true";
    var hasThumbnail = image.hasThumbnail === true || image.hasThumbnail === "true";
    var imageUrl = hasThumbnail ? image.thumbnailUrl : (image.sourceUrl || image.thumbnailUrl || "");
    var status = hasImage ? (hasThumbnail ? "Has image" : "Source image") : "No image";

    if (!hasImage || !imageUrl) {
      return '<td class="fpw-admin-port-image-cell">'
        + '<div class="fpw-admin-port-row-thumb-placeholder">No image</div>'
        + '<span class="fpw-admin-image-status">No image</span>'
        + "</td>";
    }

    return '<td class="fpw-admin-port-image-cell">'
      + '<img class="fpw-admin-port-row-thumb" src="' + escapeHtml(imageUrl) + '" alt="' + escapeHtml((row.name || "Port") + " image thumbnail") + '" loading="lazy" decoding="async" onerror="this.classList.add(\'is-hidden\'); this.nextElementSibling.textContent=\'Image unavailable\';">'
      + '<span class="fpw-admin-image-status">' + escapeHtml(status) + "</span>"
      + "</td>";
  }

  function renderFlags(row) {
    var flags = [];
    if (row.is_major_port === 1 || row.is_major_port === true || row.is_major_port === "1") {
      flags.push('<span class="badge-soft ok">Major</span>');
    }
    if (row.is_hidden_gem === 1 || row.is_hidden_gem === true || row.is_hidden_gem === "1") {
      flags.push('<span class="badge-soft">Hidden gem</span>');
    }
    return flags.length ? flags.join(" ") : '<span class="small-muted">None</span>';
  }

  function renderCoords(row) {
    var lat = fmtCoord(row.lat);
    var lng = fmtCoord(row.lng);
    if (!lat || !lng || lat === "0.0000000" || lng === "0.0000000") {
      return '<span class="badge-soft warn">Missing</span>';
    }
    return '<span class="small-muted">' + escapeHtml(lat) + ", " + escapeHtml(lng) + "</span>";
  }

  function renderTable() {
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="11">No Great Loop ports found.</td></tr>';
      return;
    }

    els.tableBody.innerHTML = state.items.map(function (row) {
      var portId = toInt(row.id);
      return ""
        + "<tr>"
        + '  <td class="num">' + portId + "</td>"
        + "  <td>" + escapeHtml(row.name || "") + "</td>"
        + renderRowImage(row)
        + "  <td>" + escapeHtml(row.state || "") + (row.state_code ? " (" + escapeHtml(row.state_code) + ")" : "") + "</td>"
        + "  <td>" + escapeHtml(row.waterway || "") + "</td>"
        + "  <td>" + escapeHtml(row.loop_segment || "") + "</td>"
        + "  <td>" + renderCoords(row) + "</td>"
        + "  <td>" + escapeHtml(row.data_quality_status || "") + "</td>"
        + "  <td>" + renderFlags(row) + "</td>"
        + "  <td>" + escapeHtml(row.profile_updated_at || "") + "</td>"
        + '  <td class="actions"><button type="button" class="btn-inline" data-action="edit" data-port-id="' + portId + '">Edit</button> '
        + '<button type="button" class="btn-inline danger" data-action="delete" data-port-id="' + portId + '" data-port-name="' + escapeHtml(row.name || "") + '">Delete</button></td>'
        + "</tr>";
    }).join("");
  }

  async function loadPorts(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="11">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load ports.");
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
      els.tableBody.innerHTML = '<tr><td colspan="11">Unable to load ports.</td></tr>';
      showMessage(els.message, err.message || "Unable to load ports.", "error");
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
    if (el) el.checked = value === true || value === "true" || value === 1 || value === "1";
  }

  function parseModalCoords() {
    var lat = toFloat(els.modalLatitude.value);
    var lng = toFloat(els.modalLongitude.value);
    if (!hasCoord(lat, lng)) {
      return null;
    }
    return { lat: lat, lng: lng };
  }

  function setMapContextFromForm() {
    if (!mapController) return;
    var coords = parseModalCoords();
    mapController.setContext({
      center: coords || defaultCenter,
      waypoint: coords || null,
      zoom: coords ? 11 : 5
    });
  }

  function setModalCoords(lat, lng) {
    els.modalLatitude.value = Number(lat).toFixed(7);
    els.modalLongitude.value = Number(lng).toFixed(7);
    setMapContextFromForm();
  }

  function normalizeDateTimeForInput(value) {
    var txt = String(value || "").trim();
    if (!txt) return "";
    return txt.replace(" ", "T").slice(0, 16);
  }

  function normalizeDateTimeForPayload(value) {
    return String(value || "").trim().replace("T", " ");
  }

  function renderImagePreview(port) {
    var image = port && port.image ? port.image : {};
    var hasImage = image.hasImage === true || image.hasImage === "true";
    if (!hasImage) {
      els.imagePreview.innerHTML = '<div class="port-image-empty">No image</div>';
      if (els.imageActions) els.imageActions.hidden = true;
      if (els.deleteImageBtn) els.deleteImageBtn.disabled = true;
      return;
    }

    els.imagePreview.innerHTML = ""
      + '<a href="' + escapeHtml(image.sourceUrl || image.thumbnailUrl || "") + '" target="_blank" rel="noopener">'
      + '  <img src="' + escapeHtml(image.thumbnailUrl || image.sourceUrl || "") + '" alt="' + escapeHtml((port.name || "Port") + " image") + '">'
      + "</a>"
      + '<div class="small-muted">'
      + '  <div><strong>' + escapeHtml(image.fileName || "") + "</strong></div>"
      + '  <div>Current admin image.</div>'
      + "</div>";
    if (els.imageActions) els.imageActions.hidden = false;
    if (els.deleteImageBtn) els.deleteImageBtn.disabled = false;
  }

  function fillForm(port) {
    setValue("modalPortId", port.id || 0);
    setValue("modalPortIdDisplay", port.id || 0);
    setValue("modalPortName", port.name || "");
    setValue("modalSlug", port.slug || "");
    setValue("modalState", port.state || "");
    setValue("modalStateCode", port.state_code || "");
    setValue("modalCountry", port.country || "");
    setValue("modalRegion", port.region || "");
    setValue("modalWaterway", port.waterway || "");
    setValue("modalLoopSegment", port.loop_segment || "");
    setValue("modalLatitude", port.lat || "");
    setValue("modalLongitude", port.lng || "");
    setValue("modalMileMarker", port.mile_marker || "");
    setValue("modalPortType", port.port_type || "");
    setValue("modalDataQualityStatus", port.data_quality_status || "needs_review");
    setValue("modalSourceUrl", port.source_url || "");
    setValue("modalLastReviewedAt", normalizeDateTimeForInput(port.last_reviewed_at));
    setChecked("modalIsMajorPort", port.is_major_port);
    setChecked("modalIsHiddenGem", port.is_hidden_gem);
    setValue("modalShortDescription", port.short_description || "");
    setValue("modalServicesSummary", port.services_summary || "");
    setValue("modalApproachNotes", port.approach_notes || "");
    setValue("modalSourceNotes", port.source_notes || "");
    setValue("modalTagsText", port.tagsText || "");

    serviceFields.forEach(function (fieldName) {
      var selectEl = document.querySelector('[data-service-field="' + fieldName + '"]');
      if (selectEl) selectEl.value = port[fieldName] === null || port[fieldName] === undefined ? "" : String(port[fieldName]);
    });

    if (els.imageFile) els.imageFile.value = "";
    state.currentPort = port;
    renderImagePreview(port);
    els.modalLabel.textContent = port.name || "Great Loop Port";
    showMessage(els.modalMessage, "", "");
    setMapContextFromForm();
  }

  async function openEditModal(portId) {
    showMessage(els.message, "", "");
    showMessage(els.modalMessage, "", "");
    try {
      var data = await callApi("get", { id: portId });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load port.");
      }
      fillForm((data.DATA || {}).port || {});
      portModal.show();
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load port.", "error");
    }
  }

  async function deletePortById(portId, portName) {
    var label = portName ? (portName + " (#" + portId + ")") : ("port #" + portId);
    var confirmation = "";

    if (!portId) return;
    confirmation = window.prompt("Type " + portId + " to permanently delete " + label + ".");
    if (confirmation === null) return;

    showMessage(els.message, "Deleting port...", "info");
    try {
      var data = await callApi("delete", { nonce: nonce, id: portId, confirmation: confirmation });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to delete port.");
      }
      await loadFacets();
      await loadPorts(true);
      showMessage(els.message, data.MESSAGE || "Port deleted.", "success");
    } catch (err) {
      showMessage(els.message, err.message || "Unable to delete port.", "error");
    }
  }

  function collectPortPayload() {
    var payload = {
      id: toInt(getValue("modalPortId")),
      name: getValue("modalPortName"),
      state: getValue("modalState"),
      state_code: getValue("modalStateCode"),
      country: getValue("modalCountry"),
      region: getValue("modalRegion"),
      waterway: getValue("modalWaterway"),
      loop_segment: getValue("modalLoopSegment"),
      lat: getValue("modalLatitude"),
      lng: getValue("modalLongitude"),
      mile_marker: getValue("modalMileMarker"),
      port_type: getValue("modalPortType"),
      data_quality_status: getValue("modalDataQualityStatus") || "needs_review",
      source_url: getValue("modalSourceUrl"),
      last_reviewed_at: normalizeDateTimeForPayload(getValue("modalLastReviewedAt")),
      is_major_port: byId("modalIsMajorPort").checked ? 1 : 0,
      is_hidden_gem: byId("modalIsHiddenGem").checked ? 1 : 0,
      short_description: getValue("modalShortDescription"),
      services_summary: getValue("modalServicesSummary"),
      approach_notes: getValue("modalApproachNotes"),
      source_notes: getValue("modalSourceNotes"),
      tagsText: getValue("modalTagsText")
    };

    serviceFields.forEach(function (fieldName) {
      var selectEl = document.querySelector('[data-service-field="' + fieldName + '"]');
      payload[fieldName] = selectEl ? selectEl.value : "";
    });
    return payload;
  }

  function validateCurrentPort() {
    var name = getValue("modalPortName");
    var latRaw = getValue("modalLatitude");
    var lngRaw = getValue("modalLongitude");
    var lat = null;
    var lng = null;

    if (!name.length) {
      throw new Error("Port name is required.");
    }
    if (latRaw.length) {
      lat = toFloat(latRaw);
      if (lat === null || lat < -90 || lat > 90) {
        throw new Error("Latitude must be between -90 and 90.");
      }
    }
    if (lngRaw.length) {
      lng = toFloat(lngRaw);
      if (lng === null || lng < -180 || lng > 180) {
        throw new Error("Longitude must be between -180 and 180.");
      }
    }
  }

  async function uploadSelectedImage(portId) {
    if (!els.imageFile || !els.imageFile.files || !els.imageFile.files.length) {
      return null;
    }

    var formData = new FormData();
    formData.append("nonce", nonce);
    formData.append("id", String(portId));
    formData.append("imageFile", els.imageFile.files[0]);

    var response = await fetch(endpoint + "&action=uploadImage", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Accept": "application/json" },
      body: formData
    });

    var data = null;
    try {
      data = await response.json();
    } catch (jsonError) {
      data = { SUCCESS: false, MESSAGE: "Invalid JSON response.", ERROR: { MESSAGE: jsonError.message || "" } };
    }

    if (!response.ok && (!data || data.SUCCESS !== false)) {
      throw new Error("Image upload failed with HTTP " + response.status + ".");
    }
    if (!data || data.SUCCESS !== true) {
      throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Image upload failed.");
    }
    return data;
  }

  async function deleteCurrentImage() {
    var portId = toInt(getValue("modalPortId"));
    var portName = getValue("modalPortName") || "this port";

    if (portId <= 0 || !state.currentPort || !state.currentPort.image
        || !(state.currentPort.image.hasImage === true || state.currentPort.image.hasImage === "true")) {
      return;
    }

    if (!window.confirm("Delete the image and thumbnail for " + portName + "?")) {
      return;
    }

    els.deleteImageBtn.disabled = true;
    showMessage(els.modalMessage, "Deleting image...", "info");

    try {
      var data = await callApi("deleteImage", { nonce: nonce, id: portId });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to delete image.");
      }

      var updatedPort = (data.DATA || {}).port || {};
      state.currentPort = updatedPort;
      if (els.imageFile) els.imageFile.value = "";
      renderImagePreview(updatedPort);
      await loadPorts(false);
      showMessage(els.modalMessage, "Port image deleted.", "success");
    } catch (err) {
      showMessage(els.modalMessage, err.message || "Unable to delete image.", "error");
      els.deleteImageBtn.disabled = false;
    }
  }

  async function saveCurrentPort() {
    var portPayload = collectPortPayload();
    els.saveBtn.disabled = true;
    showMessage(els.modalMessage, "Saving...", "info");

    try {
      validateCurrentPort();
      var saveData = await callApi("save", { nonce: nonce, port: portPayload });
      if (!saveData || saveData.SUCCESS !== true) {
        throw new Error((saveData && (saveData.MESSAGE || (saveData.ERROR && saveData.ERROR.MESSAGE))) || "Unable to save port.");
      }

      var savedPort = (saveData.DATA || {}).port || {};
      var uploadData = await uploadSelectedImage(toInt(savedPort.id || portPayload.id));

      if (uploadData && uploadData.DATA && uploadData.DATA.port) {
        savedPort = uploadData.DATA.port;
      }

      renderImagePreview(savedPort);
      await loadPorts(false);
      portModal.hide();
      showMessage(els.message, "Port saved." + (uploadData ? " Image saved." : ""), "success");
    } catch (err) {
      showMessage(els.modalMessage, err.message || "Unable to save port.", "error");
    } finally {
      els.saveBtn.disabled = false;
    }
  }

  function bindEvents() {
    els.filtersForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadPorts(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterSearch.value = "";
      els.filterState.value = "";
      els.filterLoopSegment.value = "";
      els.filterWaterway.value = "";
      els.filterQualityStatus.value = "";
      els.filterCoordStatus.value = "";
      els.filterImageStatus.value = "";
      els.filterLimit.value = "50";
      state.offset = 0;
      loadPorts(true);
    });

    els.prevPageBtn.addEventListener("click", function () {
      state.offset = Math.max(0, state.offset - state.limit);
      loadPorts(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      state.offset += state.limit;
      loadPorts(false);
    });

    els.tableBody.addEventListener("click", function (event) {
      var deleteBtn = event.target.closest("[data-action='delete']");
      var editBtn = null;

      if (deleteBtn) {
        deletePortById(toInt(deleteBtn.getAttribute("data-port-id")), deleteBtn.getAttribute("data-port-name") || "");
        return;
      }

      editBtn = event.target.closest("[data-action='edit']");
      if (!editBtn) return;
      openEditModal(toInt(editBtn.getAttribute("data-port-id")));
    });

    els.modalLatitude.addEventListener("change", setMapContextFromForm);
    els.modalLongitude.addEventListener("change", setMapContextFromForm);
    els.clearMapPointBtn.addEventListener("click", function () {
      els.modalLatitude.value = "";
      els.modalLongitude.value = "";
      setMapContextFromForm();
    });
    els.saveBtn.addEventListener("click", saveCurrentPort);
    if (els.deleteImageBtn) {
      els.deleteImageBtn.addEventListener("click", deleteCurrentImage);
    }
  }

  function initMap() {
    if (!window.FPW || typeof window.FPW.initLeafletWaypointMap !== "function" || !els.modal || !els.mapEl) {
      return;
    }

    mapController = window.FPW.initLeafletWaypointMap({
      modalEl: els.modal,
      mapEl: els.mapEl,
      onMapClick: function (lat, lng) {
        setModalCoords(lat, lng);
      },
      onMarkerDragEnd: function (lat, lng) {
        setModalCoords(lat, lng);
      }
    });
  }

  function cacheElements() {
    els.message = byId("greatLoopPortsMessage");
    els.filtersForm = byId("greatLoopPortsFilters");
    els.filterSearch = byId("filterSearch");
    els.filterState = byId("filterState");
    els.filterLoopSegment = byId("filterLoopSegment");
    els.filterWaterway = byId("filterWaterway");
    els.filterQualityStatus = byId("filterQualityStatus");
    els.filterCoordStatus = byId("filterCoordStatus");
    els.filterImageStatus = byId("filterImageStatus");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.summaryLine = byId("greatLoopPortsSummaryLine");
    els.tableBody = byId("greatLoopPortsTableBody");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");

    els.modal = byId("greatLoopPortModal");
    els.modalLabel = byId("greatLoopPortModalLabel");
    els.modalMessage = byId("greatLoopPortModalMessage");
    els.mapEl = byId("greatLoopPortMap");
    els.modalLatitude = byId("modalLatitude");
    els.modalLongitude = byId("modalLongitude");
    els.clearMapPointBtn = byId("clearMapPointBtn");
    els.imagePreview = byId("modalImagePreview");
    els.imageActions = byId("modalImageActions");
    els.imageFile = byId("modalImageFile");
    els.deleteImageBtn = byId("deletePortImageBtn");
    els.saveBtn = byId("saveGreatLoopPortBtn");
  }

  function init() {
    cacheElements();
    if (!els.filtersForm || !els.tableBody || !els.modal || !window.bootstrap) {
      return;
    }
    setServiceSelectOptions();
    portModal = new window.bootstrap.Modal(els.modal);
    initMap();
    bindEvents();
    loadFacets().then(function () {
      return loadPorts(true);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);


