(function (window, document) {
  "use strict";

  var endpoint = "/fpw/api/v1/adminWaypoints.cfc?method=handle";
  var defaultCenter = { lat: 27.8, lng: -82.7 };

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    selected: {},
    requestSeq: 0
  };

  var els = {};
  var waypointModal = null;
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
    return n.toFixed(6);
  }

  function showMessage(message, type) {
    if (!els.message) return;
    if (!message) {
      els.message.className = "msg";
      els.message.textContent = "";
      return;
    }
    els.message.className = "msg " + (type || "info");
    els.message.textContent = message;
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
      userId: (els.filterUserId.value || "").trim(),
      email: (els.filterUserEmail.value || "").trim(),
      search: (els.filterSearch.value || "").trim(),
      hasCoords: els.filterHasCoords.value || "all",
      limit: toInt(els.filterLimit.value) || 50,
      offset: state.offset
    };
  }

  function collectSelectedIds() {
    var ids = [];
    Object.keys(state.selected).forEach(function (id) {
      if (state.selected[id]) ids.push(toInt(id));
    });
    return ids.filter(function (id) { return id > 0; });
  }

  function updateSelectionSummary() {
    if (!els.selectionSummary) return;
    els.selectionSummary.textContent = collectSelectedIds().length + " selected";
  }

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " waypoint(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = (state.offset <= 0);
    els.nextPageBtn.disabled = (state.offset + state.limit >= state.total);
  }

  function syncSelectAllCheckbox() {
    if (!els.selectAllRows) return;
    if (!state.items.length) {
      els.selectAllRows.checked = false;
      return;
    }
    var allSelected = state.items.every(function (row) {
      return !!state.selected[String(row.WAYPOINTID)];
    });
    els.selectAllRows.checked = allSelected;
  }

  function renderTable() {
    if (!els.tableBody) return;
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="8">No waypoints found.</td></tr>';
      syncSelectAllCheckbox();
      updateSelectionSummary();
      return;
    }

    var html = state.items.map(function (row) {
      var id = toInt(row.WAYPOINTID);
      var checked = state.selected[String(id)] ? "checked" : "";
      var userLabel = "#" + escapeHtml(row.USERID) + " " + escapeHtml(row.USER_EMAIL || "");
      var coord = "";
      if (String(row.LATITUDE || "").trim() && String(row.LONGITUDE || "").trim()) {
        coord = escapeHtml(fmtCoord(row.LATITUDE)) + ", " + escapeHtml(fmtCoord(row.LONGITUDE));
      } else {
        coord = "<span class=\"small-muted\">(blank)</span>";
      }
      return ""
        + "<tr>"
        + "  <td><input type=\"checkbox\" class=\"row-check\" data-waypoint-id=\"" + id + "\" " + checked + "></td>"
        + "  <td class=\"num\">" + id + "</td>"
        + "  <td>" + userLabel + "</td>"
        + "  <td>" + escapeHtml(row.WAYPOINTNAME || "") + "</td>"
        + "  <td>" + coord + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USAGE_COUNT || 0) + "</td>"
        + "  <td>" + escapeHtml(row.NOTES || "") + "</td>"
        + "  <td class=\"actions\">"
        + "    <button type=\"button\" class=\"btn-inline\" data-action=\"edit\" data-waypoint-id=\"" + id + "\">Edit</button> "
        + "    <button type=\"button\" class=\"btn-inline danger\" data-action=\"delete\" data-waypoint-id=\"" + id + "\">Delete</button>"
        + "  </td>"
        + "</tr>";
    }).join("");

    els.tableBody.innerHTML = html;
    syncSelectAllCheckbox();
    updateSelectionSummary();
  }

  async function loadWaypoints(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="8">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;

      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load waypoints.");
      }

      var payload = data.DATA || {};
      state.items = Array.isArray(payload.items) ? payload.items : [];
      state.total = toInt(payload.total) || 0;

      renderTable();
      updateSummaryLine();
      showMessage("", "");
    } catch (error) {
      state.items = [];
      state.total = 0;
      renderTable();
      updateSummaryLine();
      showMessage(error.message || "Unable to load waypoints.", "error");
    }
  }

  function getRowById(waypointId) {
    var target = toInt(waypointId);
    var i;
    for (i = 0; i < state.items.length; i++) {
      if (toInt(state.items[i].WAYPOINTID) === target) {
        return state.items[i];
      }
    }
    return null;
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
    var context = {
      center: coords || defaultCenter,
      waypoint: coords || null
    };
    mapController.setContext(context);
  }

  function setModalCoords(lat, lng) {
    els.modalLatitude.value = Number(lat).toFixed(6);
    els.modalLongitude.value = Number(lng).toFixed(6);
    setMapContextFromForm();
  }

  function resetModalForm() {
    els.modalWaypointId.value = "0";
    els.modalUserId.value = "";
    els.modalUserSearch.value = "";
    els.modalUserLookup.innerHTML = '<option value="">Select user…</option>';
    els.modalWaypointName.value = "";
    els.modalLatitude.value = "";
    els.modalLongitude.value = "";
    els.modalNotes.value = "";
    els.modalUsageCount.value = "0";
    setMapContextFromForm();
  }

  function populateModal(row) {
    resetModalForm();
    if (!row) return;
    els.modalWaypointId.value = String(row.WAYPOINTID || 0);
    els.modalUserId.value = String(row.USERID || "");
    els.modalWaypointName.value = String(row.WAYPOINTNAME || "");
    els.modalLatitude.value = String(row.LATITUDE || "");
    els.modalLongitude.value = String(row.LONGITUDE || "");
    els.modalNotes.value = String(row.NOTES || "");
    els.modalUsageCount.value = String(row.USAGE_COUNT || 0);
    setMapContextFromForm();
  }

  function openModal(row) {
    if (!waypointModal) return;
    els.modalTitle.textContent = row ? "Edit Waypoint" : "Add Waypoint";
    if (row) {
      populateModal(row);
    } else {
      resetModalForm();
    }
    waypointModal.show();
  }

  function validateModal() {
    var userId = toInt(els.modalUserId.value);
    var name = (els.modalWaypointName.value || "").trim();
    var latRaw = (els.modalLatitude.value || "").trim();
    var lngRaw = (els.modalLongitude.value || "").trim();

    if (userId <= 0) {
      throw new Error("User ID is required.");
    }
    if (!name.length) {
      throw new Error("Waypoint name is required.");
    }
    if (latRaw.length) {
      var lat = toFloat(latRaw);
      if (lat === null || lat < -90 || lat > 90) {
        throw new Error("Latitude must be between -90 and 90.");
      }
    }
    if (lngRaw.length) {
      var lng = toFloat(lngRaw);
      if (lng === null || lng < -180 || lng > 180) {
        throw new Error("Longitude must be between -180 and 180.");
      }
    }
  }

  function buildModalPayload() {
    return {
      waypoint: {
        waypointId: toInt(els.modalWaypointId.value),
        userId: toInt(els.modalUserId.value),
        name: (els.modalWaypointName.value || "").trim(),
        latitude: (els.modalLatitude.value || "").trim(),
        longitude: (els.modalLongitude.value || "").trim(),
        notes: (els.modalNotes.value || "").trim()
      }
    };
  }

  async function saveModalWaypoint() {
    try {
      validateModal();
      var data = await callApi("save", buildModalPayload());
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Save failed.");
      }
      waypointModal.hide();
      showMessage("Waypoint saved.", "success");
      await loadWaypoints(false);
    } catch (error) {
      showMessage(error.message || "Unable to save waypoint.", "error");
    }
  }

  async function deleteOne(waypointId) {
    var unlink = !!els.deleteMode.checked;
    if (!window.confirm("Delete waypoint #" + waypointId + (unlink ? " (unlink enabled)" : "") + "?")) {
      return;
    }
    try {
      var data = await callApi("delete", {
        waypointId: toInt(waypointId),
        unlinkFloatplans: unlink
      });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Delete failed.");
      }
      delete state.selected[String(waypointId)];
      showMessage("Waypoint deleted.", "success");
      await loadWaypoints(false);
    } catch (error) {
      showMessage(error.message || "Unable to delete waypoint.", "error");
    }
  }

  async function deleteSelected() {
    var ids = collectSelectedIds();
    if (!ids.length) {
      showMessage("Select one or more rows first.", "info");
      return;
    }
    var unlink = !!els.deleteMode.checked;
    if (!window.confirm("Delete " + ids.length + " selected waypoint(s)?" + (unlink ? " (unlink enabled)" : ""))) {
      return;
    }
    try {
      var data = await callApi("batchDelete", {
        waypointIds: ids,
        unlinkFloatplans: unlink
      });
      if (!data || data.SUCCESS !== true) {
        var payload = data && data.DATA ? data.DATA : null;
        var msg = data && data.MESSAGE ? data.MESSAGE : "Batch delete completed with errors.";
        if (payload) {
          msg += " Deleted: " + (payload.deletedCount || 0) + ", Failed: " + (payload.failedCount || 0) + ".";
        }
        throw new Error(msg);
      }
      state.selected = {};
      showMessage("Deleted " + ids.length + " waypoint(s).", "success");
      await loadWaypoints(false);
    } catch (error) {
      showMessage(error.message || "Unable to batch delete.", "error");
      await loadWaypoints(false);
    }
  }

  async function loadUsersForLookup() {
    var search = (els.modalUserSearch.value || "").trim();
    try {
      var data = await callApi("listUsers", { search: search, limit: 200 });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load users.");
      }
      var users = (data.DATA && Array.isArray(data.DATA.users)) ? data.DATA.users : [];
      var selectedUser = toInt(els.modalUserId.value);
      var options = ['<option value="">Select user…</option>'];
      users.forEach(function (u) {
        var uid = toInt(u.userId);
        var selected = (uid === selectedUser) ? " selected" : "";
        var label = "#" + uid + " " + (u.email || "") + " (" + (u.waypointCount || 0) + ")";
        options.push('<option value="' + uid + '"' + selected + ">" + escapeHtml(label) + "</option>");
      });
      els.modalUserLookup.innerHTML = options.join("");
    } catch (error) {
      showMessage(error.message || "Unable to load users.", "error");
    }
  }

  function bindEvents() {
    els.filterForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadWaypoints(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterUserId.value = "";
      els.filterUserEmail.value = "";
      els.filterSearch.value = "";
      els.filterHasCoords.value = "all";
      els.filterLimit.value = "50";
      state.selected = {};
      state.offset = 0;
      loadWaypoints(true);
    });

    els.filterLimit.addEventListener("change", function () {
      state.offset = 0;
      loadWaypoints(true);
    });

    els.addWaypointBtn.addEventListener("click", function () {
      openModal(null);
    });

    els.batchDeleteBtn.addEventListener("click", function () {
      deleteSelected();
    });

    els.prevPageBtn.addEventListener("click", function () {
      if (state.offset <= 0) return;
      state.offset = Math.max(0, state.offset - state.limit);
      loadWaypoints(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      if (state.offset + state.limit >= state.total) return;
      state.offset += state.limit;
      loadWaypoints(false);
    });

    els.selectAllRows.addEventListener("change", function () {
      state.items.forEach(function (row) {
        var id = String(toInt(row.WAYPOINTID));
        if (!id || id === "0") return;
        state.selected[id] = !!els.selectAllRows.checked;
      });
      renderTable();
    });

    els.tableBody.addEventListener("click", function (event) {
      var target = event.target;
      if (!target) return;
      var action = target.getAttribute("data-action");
      var waypointId = toInt(target.getAttribute("data-waypoint-id"));
      if (!action || waypointId <= 0) return;
      if (action === "edit") {
        var row = getRowById(waypointId);
        if (row) openModal(row);
      } else if (action === "delete") {
        deleteOne(waypointId);
      }
    });

    els.tableBody.addEventListener("change", function (event) {
      var target = event.target;
      if (!target || !target.classList.contains("row-check")) return;
      var waypointId = toInt(target.getAttribute("data-waypoint-id"));
      if (waypointId <= 0) return;
      state.selected[String(waypointId)] = !!target.checked;
      syncSelectAllCheckbox();
      updateSelectionSummary();
    });

    els.saveWaypointBtn.addEventListener("click", function () {
      saveModalWaypoint();
    });

    els.modalLoadUsersBtn.addEventListener("click", function () {
      loadUsersForLookup();
    });

    els.modalUserLookup.addEventListener("change", function () {
      var selected = toInt(els.modalUserLookup.value);
      if (selected > 0) {
        els.modalUserId.value = String(selected);
      }
    });

    els.modalLatitude.addEventListener("change", setMapContextFromForm);
    els.modalLongitude.addEventListener("change", setMapContextFromForm);

    els.clearMapPointBtn.addEventListener("click", function () {
      els.modalLatitude.value = "";
      els.modalLongitude.value = "";
      setMapContextFromForm();
    });
  }

  function initMap() {
    if (!window.FPW || typeof window.FPW.initLeafletWaypointMap !== "function" || !els.modalEl || !els.mapEl) {
      return;
    }

    mapController = window.FPW.initLeafletWaypointMap({
      modalEl: els.modalEl,
      mapEl: els.mapEl,
      onMapClick: function (lat, lng) {
        setModalCoords(lat, lng);
      },
      onMarkerDragEnd: function (lat, lng) {
        setModalCoords(lat, lng);
      }
    });
  }

  function cacheDom() {
    els.message = byId("adminWaypointMessage");
    els.filterForm = byId("adminWaypointFilters");
    els.filterUserId = byId("filterUserId");
    els.filterUserEmail = byId("filterUserEmail");
    els.filterSearch = byId("filterSearch");
    els.filterHasCoords = byId("filterHasCoords");
    els.filterLimit = byId("filterLimit");
    els.deleteMode = byId("deleteMode");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.addWaypointBtn = byId("addWaypointBtn");
    els.batchDeleteBtn = byId("batchDeleteBtn");
    els.summaryLine = byId("waypointSummaryLine");
    els.selectionSummary = byId("selectionSummary");
    els.tableBody = byId("waypointTableBody");
    els.selectAllRows = byId("selectAllRows");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");

    els.modalEl = byId("adminWaypointModal");
    els.mapEl = byId("adminWaypointMap");
    els.modalTitle = byId("adminWaypointModalLabel");
    els.modalWaypointId = byId("modalWaypointId");
    els.modalUserId = byId("modalUserId");
    els.modalUserSearch = byId("modalUserSearch");
    els.modalUserLookup = byId("modalUserLookup");
    els.modalLoadUsersBtn = byId("modalLoadUsersBtn");
    els.modalWaypointName = byId("modalWaypointName");
    els.modalLatitude = byId("modalLatitude");
    els.modalLongitude = byId("modalLongitude");
    els.modalNotes = byId("modalNotes");
    els.modalUsageCount = byId("modalUsageCount");
    els.clearMapPointBtn = byId("clearMapPointBtn");
    els.saveWaypointBtn = byId("saveWaypointBtn");
  }

  function initModal() {
    if (!els.modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
    waypointModal = new window.bootstrap.Modal(els.modalEl);
  }

  function init() {
    cacheDom();
    if (!els.filterForm || !els.tableBody) return;
    initModal();
    initMap();
    bindEvents();
    loadWaypoints(true);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
