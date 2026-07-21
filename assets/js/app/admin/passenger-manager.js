(function (window, document) {
  "use strict";

  var endpoint = (window.FPW_API_BASE || ((window.FPW_BASE || "") + "/api/v1")) + "/adminPassengers.cfc?method=handle";

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    selected: {},
    requestSeq: 0
  };

  var els = {};
  var passengerModal = null;

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
        "Accept": "application/json",
        "X-CSRF-Token": window.FPW_ADMIN_CSRF_TOKEN || ""
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
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " passenger(s)";
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
      return !!state.selected[String(row.PASSENGERID)];
    });
    els.selectAllRows.checked = allSelected;
  }

  function renderTable() {
    if (!els.tableBody) return;
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="13">No passengers found.</td></tr>';
      syncSelectAllCheckbox();
      updateSelectionSummary();
      return;
    }

    var html = state.items.map(function (row) {
      var passengerId = toInt(row.PASSENGERID);
      var checked = state.selected[String(passengerId)] ? "checked" : "";
      var ownerName = [row.USER_FIRSTNAME || "", row.USER_LASTNAME || ""].join(" ").trim();
      if (!ownerName) ownerName = "(blank)";
      return ""
        + "<tr>"
        + "  <td><input type=\"checkbox\" class=\"row-check\" data-passenger-id=\"" + passengerId + "\" " + checked + "></td>"
        + "  <td class=\"num\">" + passengerId + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USERID || "") + "</td>"
        + "  <td>" + escapeHtml(row.USER_EMAIL || "") + "</td>"
        + "  <td>" + escapeHtml(ownerName) + "</td>"
        + "  <td>" + escapeHtml(row.PASSENGERNAME || "") + "</td>"
        + "  <td>" + escapeHtml(row.PHONE || "") + "</td>"
        + "  <td>" + escapeHtml(row.AGE || "") + "</td>"
        + "  <td>" + escapeHtml(row.GENDER || "") + "</td>"
        + "  <td>" + escapeHtml(boolLabel(row.HAS_PFD)) + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USAGE_COUNT || 0) + "</td>"
        + "  <td>" + escapeHtml(row.NOTES || "") + "</td>"
        + "  <td class=\"actions\">"
        + "    <button type=\"button\" class=\"btn-inline\" data-action=\"edit\" data-passenger-id=\"" + passengerId + "\">Edit</button> "
        + "    <button type=\"button\" class=\"btn-inline danger\" data-action=\"delete\" data-passenger-id=\"" + passengerId + "\">Delete</button>"
        + "  </td>"
        + "</tr>";
    }).join("");

    els.tableBody.innerHTML = html;
    syncSelectAllCheckbox();
    updateSelectionSummary();
  }

  async function loadPassengers(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="13">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;

      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load passengers.");
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
      showMessage(error.message || "Unable to load passengers.", "error");
    }
  }

  function resetModalForm() {
    els.modalPassengerId.value = "0";
    els.modalUserId.value = "";
    els.modalUserId.readOnly = false;
    els.modalUserSearch.value = "";
    els.modalUserLookup.innerHTML = '<option value="">Select user…</option>';
    els.modalUserLookup.disabled = false;
    els.modalLoadUsersBtn.disabled = false;
    els.modalPassengerName.value = "";
    els.modalPhone.value = "";
    els.modalAge.value = "";
    els.modalGender.value = "";
    els.modalNotes.value = "";
    els.modalUsageCount.value = "0";
    els.modalPfdDisplay.value = "Yes";
    els.ownerModeHint.textContent = "Owner can only be set when creating a passenger.";
  }

  function setOwnerEditable(isEditable) {
    els.modalUserId.readOnly = !isEditable;
    els.modalUserSearch.disabled = !isEditable;
    els.modalUserLookup.disabled = !isEditable;
    els.modalLoadUsersBtn.disabled = !isEditable;
    els.ownerModeHint.textContent = isEditable
      ? "Owner can be selected while creating a new passenger."
      : "Owner is read-only after creation.";
  }

  function populateModal(row) {
    resetModalForm();
    if (!row) {
      setOwnerEditable(true);
      return;
    }
    els.modalPassengerId.value = String(row.PASSENGERID || 0);
    els.modalUserId.value = String(row.USERID || "");
    els.modalPassengerName.value = String(row.PASSENGERNAME || "");
    els.modalPhone.value = String(row.PHONE || "");
    els.modalAge.value = String(row.AGE || "");
    els.modalGender.value = String(row.GENDER || "");
    els.modalNotes.value = String(row.NOTES || "");
    els.modalUsageCount.value = String(row.USAGE_COUNT || 0);
    els.modalPfdDisplay.value = boolLabel(row.HAS_PFD);
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
        var label = "#" + uid + " " + (u.email || "") + " (" + (u.passengerCount || 0) + ")";
        options.push('<option value="' + uid + '"' + selected + ">" + escapeHtml(label) + "</option>");
      });
      els.modalUserLookup.innerHTML = options.join("");
    } catch (error) {
      showMessage(error.message || "Unable to load users.", "error");
    }
  }

  function openModal(row) {
    if (!passengerModal) return;
    els.modalTitle.textContent = row ? "Edit Passenger" : "Add Passenger";
    populateModal(row || null);
    passengerModal.show();
    if (!row) {
      loadUsersForLookup();
    }
  }

  async function loadPassengerAndOpen(passengerId) {
    try {
      var data = await callApi("get", { passengerId: toInt(passengerId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load passenger.");
      }
      var row = data.DATA && data.DATA.passenger ? data.DATA.passenger : null;
      if (!row) {
        throw new Error("Passenger not found.");
      }
      openModal(row);
    } catch (error) {
      showMessage(error.message || "Unable to load passenger.", "error");
    }
  }

  function validateModal() {
    var passengerId = toInt(els.modalPassengerId.value);
    var userId = toInt(els.modalUserId.value);
    var name = (els.modalPassengerName.value || "").trim();

    if (passengerId <= 0 && userId <= 0) {
      throw new Error("Owner user ID is required when creating a passenger.");
    }
    if (!name.length) {
      throw new Error("Passenger name is required.");
    }
  }

  function buildModalPayload() {
    return {
      passenger: {
        passengerId: toInt(els.modalPassengerId.value),
        userId: toInt(els.modalUserId.value),
        name: (els.modalPassengerName.value || "").trim(),
        phone: (els.modalPhone.value || "").trim(),
        age: (els.modalAge.value || "").trim(),
        gender: (els.modalGender.value || "").trim(),
        notes: (els.modalNotes.value || "").trim()
      }
    };
  }

  async function saveModalPassenger() {
    try {
      validateModal();
      var data = await callApi("save", buildModalPayload());
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Save failed.");
      }
      passengerModal.hide();
      showMessage("Passenger saved.", "success");
      await loadPassengers(false);
    } catch (error) {
      showMessage(error.message || "Unable to save passenger.", "error");
    }
  }

  async function deleteOne(passengerId) {
    if (!window.confirm("Delete passenger #" + passengerId + "?")) {
      return;
    }
    try {
      var data = await callApi("delete", { passengerId: toInt(passengerId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Delete failed.");
      }
      delete state.selected[String(passengerId)];
      showMessage("Passenger deleted.", "success");
      await loadPassengers(false);
    } catch (error) {
      showMessage(error.message || "Unable to delete passenger.", "error");
    }
  }

  async function deleteSelected() {
    var ids = collectSelectedIds();
    if (!ids.length) {
      showMessage("Select one or more rows first.", "info");
      return;
    }
    if (!window.confirm("Delete " + ids.length + " selected passenger(s)?")) {
      return;
    }
    try {
      var data = await callApi("batchDelete", {
        passengerIds: ids
      });
      var payload = data && data.DATA ? data.DATA : {};
      var blockedLabels = Array.isArray(payload.results)
        ? payload.results
            .filter(function (item) { return item && item.success === false; })
            .map(function (item) {
              var id = toInt(item.passengerId);
              var name = item.passengerName ? String(item.passengerName).trim() : "";
              return name ? ("#" + id + " " + name) : ("#" + id);
            })
        : [];

      state.selected = {};
      await loadPassengers(false);

      if (data && data.SUCCESS === true) {
        showMessage("Deleted " + (payload.deletedCount || 0) + " passenger(s).", "success");
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
      await loadPassengers(false);
      showMessage(error.message || "Unable to batch delete.", "error");
    }
  }

  function bindEvents() {
    els.filterForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadPassengers(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterUserId.value = "";
      els.filterUserEmail.value = "";
      els.filterSearch.value = "";
      els.filterLimit.value = "50";
      state.selected = {};
      state.offset = 0;
      loadPassengers(true);
    });

    els.filterLimit.addEventListener("change", function () {
      state.offset = 0;
      loadPassengers(true);
    });

    els.addPassengerBtn.addEventListener("click", function () {
      openModal(null);
    });

    els.batchDeleteBtn.addEventListener("click", function () {
      deleteSelected();
    });

    els.prevPageBtn.addEventListener("click", function () {
      if (state.offset <= 0) return;
      state.offset = Math.max(0, state.offset - state.limit);
      loadPassengers(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      if (state.offset + state.limit >= state.total) return;
      state.offset += state.limit;
      loadPassengers(false);
    });

    els.selectAllRows.addEventListener("change", function () {
      state.items.forEach(function (row) {
        var id = String(toInt(row.PASSENGERID));
        if (!id || id === "0") return;
        state.selected[id] = !!els.selectAllRows.checked;
      });
      renderTable();
    });

    els.tableBody.addEventListener("click", function (event) {
      var target = event.target;
      if (!target) return;
      var action = target.getAttribute("data-action");
      var passengerId = toInt(target.getAttribute("data-passenger-id"));
      if (!action || passengerId <= 0) return;
      if (action === "edit") {
        loadPassengerAndOpen(passengerId);
      } else if (action === "delete") {
        deleteOne(passengerId);
      }
    });

    els.tableBody.addEventListener("change", function (event) {
      var target = event.target;
      if (!target || !target.classList.contains("row-check")) return;
      var passengerId = toInt(target.getAttribute("data-passenger-id"));
      if (passengerId <= 0) return;
      state.selected[String(passengerId)] = !!target.checked;
      syncSelectAllCheckbox();
      updateSelectionSummary();
    });

    els.savePassengerBtn.addEventListener("click", function () {
      saveModalPassenger();
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
    els.message = byId("adminPassengerMessage");
    els.filterForm = byId("adminPassengerFilters");
    els.filterUserId = byId("filterUserId");
    els.filterUserEmail = byId("filterUserEmail");
    els.filterSearch = byId("filterSearch");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.addPassengerBtn = byId("addPassengerBtn");
    els.batchDeleteBtn = byId("batchDeleteBtn");
    els.summaryLine = byId("passengerSummaryLine");
    els.selectionSummary = byId("selectionSummary");
    els.tableBody = byId("passengerTableBody");
    els.selectAllRows = byId("selectAllRows");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");

    els.modalEl = byId("adminPassengerModal");
    els.modalTitle = byId("adminPassengerModalLabel");
    els.modalPassengerId = byId("modalPassengerId");
    els.modalUserId = byId("modalUserId");
    els.modalUserSearch = byId("modalUserSearch");
    els.modalUserLookup = byId("modalUserLookup");
    els.modalLoadUsersBtn = byId("modalLoadUsersBtn");
    els.modalPassengerName = byId("modalPassengerName");
    els.modalPhone = byId("modalPhone");
    els.modalAge = byId("modalAge");
    els.modalGender = byId("modalGender");
    els.modalNotes = byId("modalNotes");
    els.modalUsageCount = byId("modalUsageCount");
    els.modalPfdDisplay = byId("modalPfdDisplay");
    els.ownerModeHint = byId("modalOwnerModeHint");
    els.savePassengerBtn = byId("savePassengerBtn");
  }

  function initModal() {
    if (!els.modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
    passengerModal = new window.bootstrap.Modal(els.modalEl);
  }

  function init() {
    cacheDom();
    if (!els.filterForm || !els.tableBody) return;
    initModal();
    bindEvents();
    loadPassengers(true);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);

