(function (window, document) {
  "use strict";

  var endpoint = (window.FPW_API_BASE || ((window.FPW_BASE || "") + "/api/v1")) + "/adminUsers.cfc?method=handle";
  var deletePhrase = "I UNDERSTAND THIS DELETES ONE FPW USER";

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    requestSeq: 0,
    activeUserId: 0,
    deleteUserId: 0
  };

  var els = {};
  var userModal = null;
  var deleteModal = null;

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
    var txt = String(value === null || value === undefined ? "" : value).trim().toLowerCase();
    return txt === "1" || txt === "true" || txt === "yes" || txt === "y" || txt === "on";
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
      search: (els.filterSearch.value || "").trim(),
      email: (els.filterEmail.value || "").trim(),
      phone: (els.filterPhone.value || "").trim(),
      userId: (els.filterUserId.value || "").trim(),
      limit: toInt(els.filterLimit.value) || 50,
      offset: state.offset
    };
  }

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " user(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = (state.offset <= 0);
    els.nextPageBtn.disabled = (state.offset + state.limit >= state.total);
  }

  function renderRows() {
    if (!state.items.length) {
      els.tableBody.innerHTML = "<tr><td colspan=\"8\">No users found.</td></tr>";
      updateSummaryLine();
      return;
    }

    els.tableBody.innerHTML = state.items.map(function (item) {
      var name = [item.firstName || "", item.lastName || ""].join(" ").trim();
      return [
        "<tr>",
        "<td class=\"num\">" + escapeHtml(item.userId) + "</td>",
        "<td>" + escapeHtml(name || "(No name)") + "</td>",
        "<td>" + escapeHtml(item.email || "") + "</td>",
        "<td>" + escapeHtml(item.mobilePhone || "") + "</td>",
        "<td>" + escapeHtml(item.addressPhones || "") + "</td>",
        "<td>" + escapeHtml(item.created || "") + "</td>",
        "<td>" + escapeHtml(item.lastLogin || "") + "</td>",
        "<td class=\"actions\">",
        "<button type=\"button\" class=\"btn-inline\" data-action=\"edit\" data-user-id=\"" + escapeHtml(item.userId) + "\">Edit</button> ",
        "<button type=\"button\" class=\"btn-inline danger\" data-action=\"delete\" data-user-id=\"" + escapeHtml(item.userId) + "\">Delete</button>",
        "</td>",
        "</tr>"
      ].join("");
    }).join("");
    updateSummaryLine();
  }

  async function loadUsers() {
    var seq = ++state.requestSeq;
    var filters = collectFilters();
    state.limit = filters.limit;
    showMessage("Loading users...", "info");
    els.tableBody.innerHTML = "<tr><td colspan=\"8\">Loading...</td></tr>";

    try {
      var data = await callApi("list", filters);
      if (seq !== state.requestSeq) return;
      if (!data.SUCCESS) {
        state.items = [];
        state.total = 0;
        renderRows();
        showMessage(data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data.MESSAGE || "Unable to load users."), "error");
        return;
      }
      state.items = data.DATA && data.DATA.items ? data.DATA.items : [];
      state.total = data.DATA && typeof data.DATA.total !== "undefined" ? toInt(data.DATA.total) : state.items.length;
      renderRows();
      showMessage("", "info");
    } catch (err) {
      state.items = [];
      state.total = 0;
      renderRows();
      showMessage(err && err.message ? err.message : "Unable to load users.", "error");
    }
  }

  function addressTemplate(address) {
    var row = address || {};
    return [
      "<div class=\"address-card\" data-address-row>",
      "<input type=\"hidden\" data-field=\"recId\" value=\"" + escapeHtml(row.recId || 0) + "\">",
      "<div class=\"row row-gap\">",
      "<div class=\"col-md-4\"><label class=\"form-label\">Address</label><input type=\"text\" class=\"form-control\" data-field=\"address\" maxlength=\"200\" value=\"" + escapeHtml(row.address || "") + "\"></div>",
      "<div class=\"col-md-2\"><label class=\"form-label\">City</label><input type=\"text\" class=\"form-control\" data-field=\"city\" maxlength=\"45\" value=\"" + escapeHtml(row.city || "") + "\"></div>",
      "<div class=\"col-md-2\"><label class=\"form-label\">State</label><input type=\"text\" class=\"form-control\" data-field=\"state\" maxlength=\"45\" value=\"" + escapeHtml(row.state || "") + "\"></div>",
      "<div class=\"col-md-2\"><label class=\"form-label\">Zip</label><input type=\"text\" class=\"form-control\" data-field=\"zip\" maxlength=\"45\" value=\"" + escapeHtml(row.zip || "") + "\"></div>",
      "<div class=\"col-md-2\"><label class=\"form-label\">Phone</label><input type=\"text\" class=\"form-control\" data-field=\"phone\" maxlength=\"45\" value=\"" + escapeHtml(row.phone || "") + "\"></div>",
      "</div>",
      "<div class=\"row row-gap mt-1\">",
      "<div class=\"col-md-3\"><label class=\"form-label\">Latitude</label><input type=\"text\" class=\"form-control\" data-field=\"lat\" maxlength=\"45\" value=\"" + escapeHtml(row.lat || "") + "\"></div>",
      "<div class=\"col-md-3\"><label class=\"form-label\">Longitude</label><input type=\"text\" class=\"form-control\" data-field=\"lng\" maxlength=\"45\" value=\"" + escapeHtml(row.lng || "") + "\"></div>",
      "<div class=\"col-md-3 d-flex align-items-end\"><label class=\"form-check\"><input class=\"form-check-input\" type=\"checkbox\" data-field=\"isHomePort\"" + (boolValue(row.isHomePort) ? " checked" : "") + "> Home Port</label></div>",
      "<div class=\"col-md-3 d-flex align-items-end justify-content-end\"><button type=\"button\" class=\"btn btn-outline-secondary btn-sm\" data-action=\"clear-address\">Clear Fields</button></div>",
      "</div>",
      "</div>"
    ].join("");
  }

  function renderAddresses(addresses) {
    var rows = Array.isArray(addresses) ? addresses : [];
    if (!rows.length) {
      els.addressRows.innerHTML = addressTemplate({});
      return;
    }
    els.addressRows.innerHTML = rows.map(addressTemplate).join("");
  }

  function setUserForm(user) {
    state.activeUserId = toInt(user.userId);
    els.modalUserId.value = state.activeUserId;
    els.modalUserIdDisplay.value = state.activeUserId;
    els.modalFirstName.value = user.firstName || "";
    els.modalLastName.value = user.lastName || "";
    els.modalEmail.value = user.email || "";
    els.modalMobilePhone.value = user.mobilePhone || "";
    els.modalHostekUserId.value = user.hostekUserId || "";
    els.modalCreated.value = user.created || "";
    els.modalLastLogin.value = user.lastLogin || "";
    els.modalLastUpdate.value = user.lastUpdate || "";
    els.modalPhotoFileId.value = user.photoFileId || "";
    els.modalRequestReset.value = user.requestReset || "";
    els.modalResetId.value = user.resetId || "";
    els.modalPasswordCreated.value = user.passwordCreated || "";
    renderAddresses(user.addresses || []);
  }

  async function openUser(userId) {
    showMessage("Loading user " + userId + "...", "info");
    try {
      var data = await callApi("get", { userId: userId });
      if (!data.SUCCESS) {
        showMessage(data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data.MESSAGE || "Unable to load user."), "error");
        return;
      }
      setUserForm(data.DATA.user || {});
      showMessage("", "info");
      userModal.show();
    } catch (err) {
      showMessage(err && err.message ? err.message : "Unable to load user.", "error");
    }
  }

  function collectAddresses() {
    return Array.prototype.slice.call(els.addressRows.querySelectorAll("[data-address-row]")).map(function (row) {
      function field(name) {
        var el = row.querySelector("[data-field=\"" + name + "\"]");
        if (!el) return "";
        if (el.type === "checkbox") return el.checked;
        return (el.value || "").trim();
      }
      return {
        recId: toInt(field("recId")),
        address: field("address"),
        city: field("city"),
        state: field("state"),
        zip: field("zip"),
        phone: field("phone"),
        lat: field("lat"),
        lng: field("lng"),
        isHomePort: field("isHomePort")
      };
    });
  }

  async function saveUser() {
    var payload = {
      userId: toInt(els.modalUserId.value),
      firstName: (els.modalFirstName.value || "").trim(),
      lastName: (els.modalLastName.value || "").trim(),
      email: (els.modalEmail.value || "").trim(),
      mobilePhone: (els.modalMobilePhone.value || "").trim(),
      hostekUserId: (els.modalHostekUserId.value || "").trim(),
      addresses: collectAddresses()
    };

    if (!payload.userId) {
      showMessage("User ID is missing.", "error");
      return;
    }
    if (!payload.email) {
      showMessage("Email is required.", "error");
      return;
    }

    els.saveUserBtn.disabled = true;
    try {
      var data = await callApi("save", payload);
      if (!data.SUCCESS) {
        showMessage(data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data.MESSAGE || "Unable to save user."), "error");
        return;
      }
      showMessage(data.MESSAGE || "User saved.", "success");
      userModal.hide();
      await loadUsers();
    } catch (err) {
      showMessage(err && err.message ? err.message : "Unable to save user.", "error");
    } finally {
      els.saveUserBtn.disabled = false;
    }
  }

  function renderDeleteCounts(counts) {
    var rows = Array.isArray(counts) ? counts : [];
    if (!rows.length) {
      els.deleteCounts.innerHTML = "<div class=\"p-2\">No related rows found.</div>";
      return;
    }
    els.deleteCounts.innerHTML = [
      "<table class=\"table table-sm table-striped\"><thead><tr><th>Table</th><th class=\"text-end\">Rows</th></tr></thead><tbody>",
      rows.map(function (row) {
        return "<tr><td>" + escapeHtml(row.tableName || row.table_name || "") + "</td><td class=\"text-end\">" + escapeHtml(row.rowsBefore || row.rows_before || 0) + "</td></tr>";
      }).join(""),
      "</tbody></table>"
    ].join("");
  }

  async function openDelete(userId) {
    state.deleteUserId = toInt(userId);
    els.deleteConfirmation.value = "";
    els.executeDeleteUserBtn.disabled = true;
    els.deleteSummary.className = "msg info";
    els.deleteSummary.textContent = "Loading delete preview...";
    els.deleteCounts.innerHTML = "";
    deleteModal.show();

    try {
      var data = await callApi("deletePreview", { userId: state.deleteUserId });
      if (!data.SUCCESS) {
        els.deleteSummary.className = "msg error";
        els.deleteSummary.textContent = data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data.MESSAGE || "Unable to preview delete.");
        return;
      }
      var target = data.DATA.target || {};
      els.deleteSummary.className = "msg info";
      els.deleteSummary.textContent = "Target: user " + target.userId + " / " + (target.email || "") + ". Total related rows: " + (data.DATA.totalRows || 0) + ".";
      renderDeleteCounts(data.DATA.counts || []);
    } catch (err) {
      els.deleteSummary.className = "msg error";
      els.deleteSummary.textContent = err && err.message ? err.message : "Unable to preview delete.";
    }
  }

  async function executeDelete() {
    var confirmation = (els.deleteConfirmation.value || "").trim();
    if (confirmation !== deletePhrase) {
      els.deleteSummary.className = "msg error";
      els.deleteSummary.textContent = "Confirmation text does not match.";
      return;
    }

    els.executeDeleteUserBtn.disabled = true;
    try {
      var data = await callApi("deleteExecute", {
        userId: state.deleteUserId,
        confirmation: confirmation
      });
      if (!data.SUCCESS) {
        els.deleteSummary.className = "msg error";
        els.deleteSummary.textContent = data.ERROR && data.ERROR.MESSAGE ? data.ERROR.MESSAGE : (data.MESSAGE || "Unable to delete user.");
        return;
      }
      deleteModal.hide();
      if (userModal) userModal.hide();
      showMessage(data.MESSAGE || "User deleted.", "success");
      await loadUsers();
    } catch (err) {
      els.deleteSummary.className = "msg error";
      els.deleteSummary.textContent = err && err.message ? err.message : "Unable to delete user.";
    } finally {
      els.executeDeleteUserBtn.disabled = ((els.deleteConfirmation.value || "").trim() !== deletePhrase);
    }
  }

  function bindEvents() {
    els.filters.addEventListener("submit", function (event) {
      event.preventDefault();
      state.offset = 0;
      loadUsers();
    });
    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterSearch.value = "";
      els.filterEmail.value = "";
      els.filterPhone.value = "";
      els.filterUserId.value = "";
      els.filterLimit.value = "50";
      state.offset = 0;
      loadUsers();
    });
    els.prevPageBtn.addEventListener("click", function () {
      state.offset = Math.max(0, state.offset - state.limit);
      loadUsers();
    });
    els.nextPageBtn.addEventListener("click", function () {
      state.offset += state.limit;
      loadUsers();
    });
    els.tableBody.addEventListener("click", function (event) {
      var btn = event.target.closest("button[data-action]");
      if (!btn) return;
      var userId = toInt(btn.getAttribute("data-user-id"));
      if (!userId) return;
      if (btn.getAttribute("data-action") === "edit") {
        openUser(userId);
      } else if (btn.getAttribute("data-action") === "delete") {
        openDelete(userId);
      }
    });
    els.addAddressBtn.addEventListener("click", function () {
      els.addressRows.insertAdjacentHTML("beforeend", addressTemplate({}));
    });
    els.addressRows.addEventListener("click", function (event) {
      var btn = event.target.closest("button[data-action=\"clear-address\"]");
      if (!btn) return;
      var row = btn.closest("[data-address-row]");
      if (!row) return;
      Array.prototype.slice.call(row.querySelectorAll("input")).forEach(function (input) {
        if (input.getAttribute("data-field") === "recId") return;
        if (input.type === "checkbox") {
          input.checked = false;
        } else {
          input.value = "";
        }
      });
    });
    els.saveUserBtn.addEventListener("click", saveUser);
    els.openDeleteUserBtn.addEventListener("click", function () {
      openDelete(toInt(els.modalUserId.value));
    });
    els.deleteConfirmation.addEventListener("input", function () {
      els.executeDeleteUserBtn.disabled = ((els.deleteConfirmation.value || "").trim() !== deletePhrase);
    });
    els.executeDeleteUserBtn.addEventListener("click", executeDelete);
  }

  function init() {
    els = {
      message: byId("adminUserMessage"),
      filters: byId("adminUserFilters"),
      filterSearch: byId("filterSearch"),
      filterEmail: byId("filterEmail"),
      filterPhone: byId("filterPhone"),
      filterUserId: byId("filterUserId"),
      filterLimit: byId("filterLimit"),
      resetFiltersBtn: byId("resetFiltersBtn"),
      summaryLine: byId("userSummaryLine"),
      tableBody: byId("userTableBody"),
      prevPageBtn: byId("prevPageBtn"),
      nextPageBtn: byId("nextPageBtn"),
      pagerInfo: byId("pagerInfo"),
      modalUserId: byId("modalUserId"),
      modalUserIdDisplay: byId("modalUserIdDisplay"),
      modalFirstName: byId("modalFirstName"),
      modalLastName: byId("modalLastName"),
      modalEmail: byId("modalEmail"),
      modalMobilePhone: byId("modalMobilePhone"),
      modalHostekUserId: byId("modalHostekUserId"),
      modalCreated: byId("modalCreated"),
      modalLastLogin: byId("modalLastLogin"),
      modalLastUpdate: byId("modalLastUpdate"),
      modalPhotoFileId: byId("modalPhotoFileId"),
      modalRequestReset: byId("modalRequestReset"),
      modalResetId: byId("modalResetId"),
      modalPasswordCreated: byId("modalPasswordCreated"),
      addressRows: byId("addressRows"),
      addAddressBtn: byId("addAddressBtn"),
      saveUserBtn: byId("saveUserBtn"),
      openDeleteUserBtn: byId("openDeleteUserBtn"),
      deleteSummary: byId("deleteUserSummary"),
      deleteCounts: byId("deleteUserCounts"),
      deleteConfirmation: byId("deleteConfirmation"),
      executeDeleteUserBtn: byId("executeDeleteUserBtn")
    };

    if (!els.filters || !window.bootstrap) return;
    userModal = new window.bootstrap.Modal(byId("adminUserModal"));
    deleteModal = new window.bootstrap.Modal(byId("deleteUserModal"));
    bindEvents();
    loadUsers();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
