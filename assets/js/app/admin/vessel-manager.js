(function (window, document) {
  "use strict";

  var endpoint = "/fpw/api/v1/adminVessels.cfc?method=handle";

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    selected: {},
    requestSeq: 0
  };

  var els = {};
  var vesselModal = null;

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

  function boolLabel(value) {
    var txt = String(value === null || value === undefined ? "" : value).trim().toLowerCase();
    return (txt === "1" || txt === "true" || txt === "yes" || txt === "y" || txt === "on") ? "Yes" : "No";
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
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " vessel(s)";
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
      return !!state.selected[String(row.VESSELID)];
    });
    els.selectAllRows.checked = allSelected;
  }

  function renderTable() {
    if (!els.tableBody) return;
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="21">No vessels found.</td></tr>';
      syncSelectAllCheckbox();
      updateSelectionSummary();
      return;
    }

    var html = state.items.map(function (row) {
      var vesselId = toInt(row.VESSELID);
      var checked = state.selected[String(vesselId)] ? "checked" : "";
      var ownerName = [row.USER_FIRSTNAME || "", row.USER_LASTNAME || ""].join(" ").trim() || "(blank)";
      return ""
        + "<tr>"
        + "  <td><input type=\"checkbox\" class=\"row-check\" data-vessel-id=\"" + vesselId + "\" " + checked + "></td>"
        + "  <td class=\"num\">" + vesselId + "</td>"
        + "  <td>" + escapeHtml(row.USERID || "") + "</td>"
        + "  <td>" + escapeHtml(row.USER_EMAIL || "") + "</td>"
        + "  <td>" + escapeHtml(ownerName) + "</td>"
        + "  <td>" + escapeHtml(row.VESSELNAME || "") + "</td>"
        + "  <td>" + escapeHtml(row.REGISTRATION || "") + "</td>"
        + "  <td>" + escapeHtml(row.TYPE || "") + "</td>"
        + "  <td>" + escapeHtml(row.MAKE || "") + "</td>"
        + "  <td>" + escapeHtml(row.MODEL || "") + "</td>"
        + "  <td>" + escapeHtml(row.LENGTH || "") + "</td>"
        + "  <td>" + escapeHtml(row.COLOR || "") + "</td>"
        + "  <td>" + escapeHtml(row.HOMEPORT || "") + "</td>"
        + "  <td>" + escapeHtml(boolLabel(row.ISDEFAULTVESSEL)) + "</td>"
        + "  <td>" + escapeHtml(row.MAX_SPEED || "") + "</td>"
        + "  <td>" + escapeHtml(row.MOST_EFFICIENT_SPEED || "") + "</td>"
        + "  <td>" + escapeHtml(row.GALLONS_PER_HOUR || "") + "</td>"
        + "  <td>" + escapeHtml(row.GPH_AT_MAX_SPEED || "") + "</td>"
        + "  <td>" + escapeHtml(row.FUEL_CAPACITY || "") + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USAGE_COUNT || 0) + "</td>"
        + "  <td class=\"actions\">"
        + "    <button type=\"button\" class=\"btn-inline\" data-action=\"edit\" data-vessel-id=\"" + vesselId + "\">Edit</button> "
        + "    <button type=\"button\" class=\"btn-inline danger\" data-action=\"delete\" data-vessel-id=\"" + vesselId + "\">Delete</button>"
        + "  </td>"
        + "</tr>";
    }).join("");

    els.tableBody.innerHTML = html;
    syncSelectAllCheckbox();
    updateSelectionSummary();
  }

  async function loadVessels(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="21">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;

      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load vessels.");
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
      showMessage(error.message || "Unable to load vessels.", "error");
    }
  }

  function resetModalForm() {
    els.modalVesselId.value = "0";
    els.modalUserId.value = "";
    els.modalUserId.readOnly = false;
    els.modalUserSearch.value = "";
    els.modalUserLookup.innerHTML = '<option value="">Select user…</option>';
    els.modalUserSearch.disabled = false;
    els.modalUserLookup.disabled = false;
    els.modalLoadUsersBtn.disabled = false;
    els.modalVesselName.value = "";
    els.modalRegistration.value = "";
    els.modalTypeOfVessel.value = "";
    els.modalMake.value = "";
    els.modalModel.value = "";
    els.modalLengthOfVessel.value = "";
    els.modalMaxSpeed.value = "";
    els.modalMostEfficientSpeed.value = "";
    els.modalGallonsPerHour.value = "";
    els.modalGphAtMaxSpeed.value = "";
    els.modalFuelCapacity.value = "";
    els.modalIsDefaultVessel.checked = true;
    els.modalHullColor.value = "";
    els.modalHailingPort.value = "";
    els.modalUsageCount.value = "0";
    els.ownerModeHint.textContent = "Owner can only be set when creating a vessel.";
  }

  function setOwnerEditable(isEditable) {
    els.modalUserId.readOnly = !isEditable;
    els.modalUserSearch.disabled = !isEditable;
    els.modalUserLookup.disabled = !isEditable;
    els.modalLoadUsersBtn.disabled = !isEditable;
    els.ownerModeHint.textContent = isEditable
      ? "Owner can be selected while creating a new vessel."
      : "Owner is read-only after creation.";
  }

  function populateModal(row) {
    resetModalForm();
    if (!row) {
      setOwnerEditable(true);
      return;
    }
    els.modalVesselId.value = String(row.VESSELID || 0);
    els.modalUserId.value = String(row.USERID || "");
    els.modalVesselName.value = String(row.VESSELNAME || "");
    els.modalRegistration.value = String(row.REGISTRATION || "");
    els.modalTypeOfVessel.value = String(row.TYPE || "");
    els.modalMake.value = String(row.MAKE || "");
    els.modalModel.value = String(row.MODEL || "");
    els.modalLengthOfVessel.value = String(row.LENGTH || "");
    els.modalMaxSpeed.value = String(row.MAX_SPEED || "");
    els.modalMostEfficientSpeed.value = String(row.MOST_EFFICIENT_SPEED || "");
    els.modalGallonsPerHour.value = String(row.GALLONS_PER_HOUR || "");
    els.modalGphAtMaxSpeed.value = String(row.GPH_AT_MAX_SPEED || "");
    els.modalFuelCapacity.value = String(row.FUEL_CAPACITY || "");
    els.modalIsDefaultVessel.checked = boolLabel(row.ISDEFAULTVESSEL) === "Yes";
    els.modalHullColor.value = String(row.COLOR || "");
    els.modalHailingPort.value = String(row.HOMEPORT || "");
    els.modalUsageCount.value = String(row.USAGE_COUNT || 0);
    setOwnerEditable(false);
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
        var label = "#" + uid + " " + (u.email || "") + " (" + (u.vesselCount || 0) + ")";
        options.push('<option value="' + uid + '"' + selected + ">" + escapeHtml(label) + "</option>");
      });
      els.modalUserLookup.innerHTML = options.join("");
    } catch (error) {
      showMessage(error.message || "Unable to load users.", "error");
    }
  }

  function openModal(row) {
    if (!vesselModal) return;
    els.modalTitle.textContent = row ? "Edit Vessel" : "Add Vessel";
    populateModal(row || null);
    vesselModal.show();
    if (!row) {
      loadUsersForLookup();
    }
  }

  async function loadVesselAndOpen(vesselId) {
    try {
      var data = await callApi("get", { vesselId: toInt(vesselId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load vessel.");
      }
      var row = data.DATA && data.DATA.vessel ? data.DATA.vessel : null;
      if (!row) {
        throw new Error("Vessel not found.");
      }
      openModal(row);
    } catch (error) {
      showMessage(error.message || "Unable to load vessel.", "error");
    }
  }

  function validateModal() {
    var vesselId = toInt(els.modalVesselId.value);
    var userId = toInt(els.modalUserId.value);
    var vesselName = (els.modalVesselName.value || "").trim();
    var vesselType = (els.modalTypeOfVessel.value || "").trim();
    var lengthVal = (els.modalLengthOfVessel.value || "").trim();
    var colorVal = (els.modalHullColor.value || "").trim();

    if (vesselId <= 0 && userId <= 0) {
      throw new Error("Owner user ID is required when creating a vessel.");
    }
    if (!vesselName.length) {
      throw new Error("Vessel name is required.");
    }
    if (!vesselType.length) {
      throw new Error("Vessel type is required.");
    }
    if (!lengthVal.length) {
      throw new Error("Length of vessel is required.");
    }
    if (!colorVal.length) {
      throw new Error("Hull color is required.");
    }
  }

  function buildModalPayload() {
    return {
      vessel: {
        vesselId: toInt(els.modalVesselId.value),
        userId: toInt(els.modalUserId.value),
        vesselName: (els.modalVesselName.value || "").trim(),
        registration: (els.modalRegistration.value || "").trim(),
        typeOfVessel: (els.modalTypeOfVessel.value || "").trim(),
        make: (els.modalMake.value || "").trim(),
        model: (els.modalModel.value || "").trim(),
        lengthOfVessel: (els.modalLengthOfVessel.value || "").trim(),
        max_speed: (els.modalMaxSpeed.value || "").trim(),
        most_efficient_speed: (els.modalMostEfficientSpeed.value || "").trim(),
        gallons_per_hour: (els.modalGallonsPerHour.value || "").trim(),
        gph_at_max_speed: (els.modalGphAtMaxSpeed.value || "").trim(),
        fuel_capacity: (els.modalFuelCapacity.value || "").trim(),
        isDefaultVessel: els.modalIsDefaultVessel.checked ? 1 : 0,
        hullColor: (els.modalHullColor.value || "").trim(),
        hailingPort: (els.modalHailingPort.value || "").trim()
      }
    };
  }

  async function saveModalVessel() {
    try {
      validateModal();
      var data = await callApi("save", buildModalPayload());
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Save failed.");
      }
      vesselModal.hide();
      showMessage("Vessel saved.", "success");
      await loadVessels(false);
    } catch (error) {
      showMessage(error.message || "Unable to save vessel.", "error");
    }
  }

  async function deleteOne(vesselId) {
    if (!window.confirm("Delete vessel #" + vesselId + "?")) {
      return;
    }
    try {
      var data = await callApi("delete", { vesselId: toInt(vesselId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Delete failed.");
      }
      delete state.selected[String(vesselId)];
      showMessage("Vessel deleted.", "success");
      await loadVessels(false);
    } catch (error) {
      showMessage(error.message || "Unable to delete vessel.", "error");
    }
  }

  async function deleteSelected() {
    var ids = collectSelectedIds();
    if (!ids.length) {
      showMessage("Select one or more rows first.", "info");
      return;
    }
    if (!window.confirm("Delete " + ids.length + " selected vessel(s)?")) {
      return;
    }
    try {
      var data = await callApi("batchDelete", {
        vesselIds: ids
      });
      var payload = data && data.DATA ? data.DATA : {};
      var blockedLabels = Array.isArray(payload.results)
        ? payload.results
            .filter(function (item) { return item && item.success === false; })
            .map(function (item) {
              var id = toInt(item.vesselId);
              var name = item.vesselName ? String(item.vesselName).trim() : "";
              return name ? ("#" + id + " " + name) : ("#" + id);
            })
        : [];

      state.selected = {};
      await loadVessels(false);

      if (data && data.SUCCESS === true) {
        showMessage("Deleted " + (payload.deletedCount || 0) + " vessel(s).", "success");
        return;
      }

      var msg = (data && data.MESSAGE) ? data.MESSAGE : "Batch delete completed with errors.";
      if (payload) {
        msg += " Deleted: " + (payload.deletedCount || 0) + ", Failed: " + (payload.failedCount || 0) + ".";
      }
      if (blockedLabels.length) {
        msg += " Blocked: " + blockedLabels.join(", ") + ".";
      }
      showMessage(msg, "error");
    } catch (error) {
      await loadVessels(false);
      showMessage(error.message || "Unable to batch delete.", "error");
    }
  }

  function bindEvents() {
    els.filterForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadVessels(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterUserId.value = "";
      els.filterUserEmail.value = "";
      els.filterSearch.value = "";
      els.filterLimit.value = "50";
      state.selected = {};
      state.offset = 0;
      loadVessels(true);
    });

    els.filterLimit.addEventListener("change", function () {
      state.offset = 0;
      loadVessels(true);
    });

    els.addVesselBtn.addEventListener("click", function () {
      openModal(null);
    });

    els.batchDeleteBtn.addEventListener("click", function () {
      deleteSelected();
    });

    els.prevPageBtn.addEventListener("click", function () {
      if (state.offset <= 0) return;
      state.offset = Math.max(0, state.offset - state.limit);
      loadVessels(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      if (state.offset + state.limit >= state.total) return;
      state.offset += state.limit;
      loadVessels(false);
    });

    els.selectAllRows.addEventListener("change", function () {
      state.items.forEach(function (row) {
        var id = String(toInt(row.VESSELID));
        if (!id || id === "0") return;
        state.selected[id] = !!els.selectAllRows.checked;
      });
      renderTable();
    });

    els.tableBody.addEventListener("click", function (event) {
      var target = event.target;
      if (!target) return;
      var action = target.getAttribute("data-action");
      var vesselId = toInt(target.getAttribute("data-vessel-id"));
      if (!action || vesselId <= 0) return;
      if (action === "edit") {
        loadVesselAndOpen(vesselId);
      } else if (action === "delete") {
        deleteOne(vesselId);
      }
    });

    els.tableBody.addEventListener("change", function (event) {
      var target = event.target;
      if (!target || !target.classList.contains("row-check")) return;
      var vesselId = toInt(target.getAttribute("data-vessel-id"));
      if (vesselId <= 0) return;
      state.selected[String(vesselId)] = !!target.checked;
      syncSelectAllCheckbox();
      updateSelectionSummary();
    });

    els.saveVesselBtn.addEventListener("click", function () {
      saveModalVessel();
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
  }

  function cacheDom() {
    els.message = byId("adminVesselMessage");
    els.filterForm = byId("adminVesselFilters");
    els.filterUserId = byId("filterUserId");
    els.filterUserEmail = byId("filterUserEmail");
    els.filterSearch = byId("filterSearch");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.addVesselBtn = byId("addVesselBtn");
    els.batchDeleteBtn = byId("batchDeleteBtn");
    els.summaryLine = byId("vesselSummaryLine");
    els.selectionSummary = byId("selectionSummary");
    els.tableBody = byId("vesselTableBody");
    els.selectAllRows = byId("selectAllRows");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");

    els.modalEl = byId("adminVesselModal");
    els.modalTitle = byId("adminVesselModalLabel");
    els.modalVesselId = byId("modalVesselId");
    els.modalUserId = byId("modalUserId");
    els.modalUserSearch = byId("modalUserSearch");
    els.modalUserLookup = byId("modalUserLookup");
    els.modalLoadUsersBtn = byId("modalLoadUsersBtn");
    els.modalVesselName = byId("modalVesselName");
    els.modalRegistration = byId("modalRegistration");
    els.modalTypeOfVessel = byId("modalTypeOfVessel");
    els.modalMake = byId("modalMake");
    els.modalModel = byId("modalModel");
    els.modalLengthOfVessel = byId("modalLengthOfVessel");
    els.modalMaxSpeed = byId("modalMaxSpeed");
    els.modalMostEfficientSpeed = byId("modalMostEfficientSpeed");
    els.modalGallonsPerHour = byId("modalGallonsPerHour");
    els.modalGphAtMaxSpeed = byId("modalGphAtMaxSpeed");
    els.modalFuelCapacity = byId("modalFuelCapacity");
    els.modalIsDefaultVessel = byId("modalIsDefaultVessel");
    els.modalHullColor = byId("modalHullColor");
    els.modalHailingPort = byId("modalHailingPort");
    els.modalUsageCount = byId("modalUsageCount");
    els.ownerModeHint = byId("modalOwnerModeHint");
    els.saveVesselBtn = byId("saveVesselBtn");
  }

  function initModal() {
    if (!els.modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
    vesselModal = new window.bootstrap.Modal(els.modalEl);
  }

  function init() {
    cacheDom();
    if (!els.filterForm || !els.tableBody) return;
    initModal();
    bindEvents();
    loadVessels(true);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
