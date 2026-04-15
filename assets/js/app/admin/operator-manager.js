(function (window, document) {
  "use strict";

  var endpoint = "/fpw/api/v1/adminOperators.cfc?method=handle";

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    requestSeq: 0
  };

  var els = {};
  var operatorModal = null;

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

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " operator(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = (state.offset <= 0);
    els.nextPageBtn.disabled = (state.offset + state.limit >= state.total);
  }

  function renderTable() {
    if (!els.tableBody) return;
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="9">No operators found.</td></tr>';
      return;
    }

    var html = state.items.map(function (row) {
      var operatorId = toInt(row.OPERATORID);
      var ownerName = [row.USER_FIRSTNAME || "", row.USER_LASTNAME || ""].join(" ").trim();
      if (!ownerName) ownerName = "(blank)";
      return ""
        + "<tr>"
        + "  <td class=\"num\">" + operatorId + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USERID || "") + "</td>"
        + "  <td>" + escapeHtml(row.USER_EMAIL || "") + "</td>"
        + "  <td>" + escapeHtml(ownerName) + "</td>"
        + "  <td>" + escapeHtml(row.OPERATORNAME || "") + "</td>"
        + "  <td>" + escapeHtml(row.PHONE || "") + "</td>"
        + "  <td class=\"num\">" + escapeHtml(row.USAGE_COUNT || 0) + "</td>"
        + "  <td>" + escapeHtml(row.NOTES || "") + "</td>"
        + "  <td class=\"actions\">"
        + "    <button type=\"button\" class=\"btn-inline\" data-action=\"edit\" data-operator-id=\"" + operatorId + "\">Edit</button> "
        + "    <button type=\"button\" class=\"btn-inline danger\" data-action=\"delete\" data-operator-id=\"" + operatorId + "\">Delete</button>"
        + "  </td>"
        + "</tr>";
    }).join("");

    els.tableBody.innerHTML = html;
  }

  async function loadOperators(resetPaging) {
    if (resetPaging) {
      state.offset = 0;
    }
    state.limit = toInt(els.filterLimit.value) || 50;

    var reqId = ++state.requestSeq;
    els.tableBody.innerHTML = '<tr><td colspan="9">Loading...</td></tr>';

    try {
      var data = await callApi("list", collectFilters());
      if (reqId !== state.requestSeq) return;

      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load operators.");
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
      showMessage(error.message || "Unable to load operators.", "error");
    }
  }

  function resetModalForm() {
    els.modalOperatorId.value = "0";
    els.modalUserId.value = "";
    els.modalUserId.readOnly = false;
    els.modalUserSearch.value = "";
    els.modalUserLookup.innerHTML = '<option value="">Select user…</option>';
    els.modalUserSearch.disabled = false;
    els.modalUserLookup.disabled = false;
    els.modalLoadUsersBtn.disabled = false;
    els.modalOperatorName.value = "";
    els.modalPhone.value = "";
    els.modalUsageCount.value = "0";
    els.modalNotes.value = "";
    els.ownerModeHint.textContent = "Owner can only be set when creating an operator.";
  }

  function setOwnerEditable(isEditable) {
    els.modalUserId.readOnly = !isEditable;
    els.modalUserSearch.disabled = !isEditable;
    els.modalUserLookup.disabled = !isEditable;
    els.modalLoadUsersBtn.disabled = !isEditable;
    els.ownerModeHint.textContent = isEditable
      ? "Owner can be selected while creating a new operator."
      : "Owner is read-only after creation.";
  }

  function populateModal(row) {
    resetModalForm();
    if (!row) {
      setOwnerEditable(true);
      return;
    }
    els.modalOperatorId.value = String(row.OPERATORID || 0);
    els.modalUserId.value = String(row.USERID || "");
    els.modalOperatorName.value = String(row.OPERATORNAME || "");
    els.modalPhone.value = String(row.PHONE || "");
    els.modalUsageCount.value = String(row.USAGE_COUNT || 0);
    els.modalNotes.value = String(row.NOTES || "");
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
        var label = "#" + uid + " " + (u.email || "") + " (" + (u.operatorCount || 0) + ")";
        options.push('<option value="' + uid + '"' + selected + ">" + escapeHtml(label) + "</option>");
      });
      els.modalUserLookup.innerHTML = options.join("");
    } catch (error) {
      showMessage(error.message || "Unable to load users.", "error");
    }
  }

  function openModal(row) {
    if (!operatorModal) return;
    els.modalTitle.textContent = row ? "Edit Operator" : "Add Operator";
    populateModal(row || null);
    operatorModal.show();
    if (!row) {
      loadUsersForLookup();
    }
  }

  async function loadOperatorAndOpen(operatorId) {
    try {
      var data = await callApi("get", { operatorId: toInt(operatorId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load operator.");
      }
      var row = data.DATA && data.DATA.operator ? data.DATA.operator : null;
      if (!row) {
        throw new Error("Operator not found.");
      }
      openModal(row);
    } catch (error) {
      showMessage(error.message || "Unable to load operator.", "error");
    }
  }

  function validateModal() {
    var operatorId = toInt(els.modalOperatorId.value);
    var userId = toInt(els.modalUserId.value);
    var name = (els.modalOperatorName.value || "").trim();

    if (operatorId <= 0 && userId <= 0) {
      throw new Error("Owner user ID is required when creating an operator.");
    }
    if (!name.length) {
      throw new Error("Operator name is required.");
    }
  }

  function buildModalPayload() {
    return {
      operator: {
        operatorId: toInt(els.modalOperatorId.value),
        userId: toInt(els.modalUserId.value),
        name: (els.modalOperatorName.value || "").trim(),
        phone: (els.modalPhone.value || "").trim(),
        notes: (els.modalNotes.value || "").trim()
      }
    };
  }

  async function saveModalOperator() {
    try {
      validateModal();
      var data = await callApi("save", buildModalPayload());
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Save failed.");
      }
      operatorModal.hide();
      showMessage("Operator saved.", "success");
      await loadOperators(false);
    } catch (error) {
      showMessage(error.message || "Unable to save operator.", "error");
    }
  }

  async function deleteOne(operatorId) {
    if (!window.confirm("Delete operator #" + operatorId + "?")) {
      return;
    }
    try {
      var data = await callApi("delete", { operatorId: toInt(operatorId) });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Delete failed.");
      }
      showMessage("Operator deleted.", "success");
      await loadOperators(false);
    } catch (error) {
      showMessage(error.message || "Unable to delete operator.", "error");
    }
  }

  function bindEvents() {
    els.filterForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadOperators(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterUserId.value = "";
      els.filterUserEmail.value = "";
      els.filterSearch.value = "";
      els.filterLimit.value = "50";
      state.offset = 0;
      loadOperators(true);
    });

    els.filterLimit.addEventListener("change", function () {
      state.offset = 0;
      loadOperators(true);
    });

    els.addOperatorBtn.addEventListener("click", function () {
      openModal(null);
    });

    els.prevPageBtn.addEventListener("click", function () {
      if (state.offset <= 0) return;
      state.offset = Math.max(0, state.offset - state.limit);
      loadOperators(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      if (state.offset + state.limit >= state.total) return;
      state.offset += state.limit;
      loadOperators(false);
    });

    els.tableBody.addEventListener("click", function (event) {
      var target = event.target;
      if (!target) return;
      var action = target.getAttribute("data-action");
      var operatorId = toInt(target.getAttribute("data-operator-id"));
      if (!action || operatorId <= 0) return;
      if (action === "edit") {
        loadOperatorAndOpen(operatorId);
      } else if (action === "delete") {
        deleteOne(operatorId);
      }
    });

    els.saveOperatorBtn.addEventListener("click", function () {
      saveModalOperator();
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
    els.message = byId("adminOperatorMessage");
    els.filterForm = byId("adminOperatorFilters");
    els.filterUserId = byId("filterUserId");
    els.filterUserEmail = byId("filterUserEmail");
    els.filterSearch = byId("filterSearch");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.addOperatorBtn = byId("addOperatorBtn");
    els.summaryLine = byId("operatorSummaryLine");
    els.tableBody = byId("operatorTableBody");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");

    els.modalEl = byId("adminOperatorModal");
    els.modalTitle = byId("adminOperatorModalLabel");
    els.modalOperatorId = byId("modalOperatorId");
    els.modalUserId = byId("modalUserId");
    els.modalUserSearch = byId("modalUserSearch");
    els.modalUserLookup = byId("modalUserLookup");
    els.modalLoadUsersBtn = byId("modalLoadUsersBtn");
    els.modalOperatorName = byId("modalOperatorName");
    els.modalPhone = byId("modalPhone");
    els.modalUsageCount = byId("modalUsageCount");
    els.modalNotes = byId("modalNotes");
    els.ownerModeHint = byId("modalOwnerModeHint");
    els.saveOperatorBtn = byId("saveOperatorBtn");
  }

  function initModal() {
    if (!els.modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
    operatorModal = new window.bootstrap.Modal(els.modalEl);
  }

  function init() {
    cacheDom();
    if (!els.filterForm || !els.tableBody) return;
    initModal();
    bindEvents();
    loadOperators(true);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
