(function (window, document) {
  "use strict";

  var config = window.FPW_GREAT_LOOP_LOCKS_ADMIN || {};
  var endpoint = config.endpoint || ((window.FPW_API_BASE || ((window.FPW_BASE || "") + "/api/v1")) + "/adminGreatLoopLocks.cfc?method=handle");
  var nonce = config.nonce || "";

  var state = {
    items: [],
    total: 0,
    limit: 50,
    offset: 0,
    requestSeq: 0,
    currentLock: null
  };

  var els = {};
  var lockModal = null;

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
      q: (els.filterSearch.value || "").trim(),
      state: els.filterState.value || "",
      waterway: els.filterWaterway.value || "",
      lockSystem: els.filterLockSystem.value || "",
      publicStatus: els.filterPublicStatus.value || "",
      imageStatus: els.filterImageStatus.value || "",
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
      setSelectOptions(els.filterState, payload.states || []);
      setSelectOptions(els.filterWaterway, payload.waterways || []);
      setSelectOptions(els.filterLockSystem, payload.lockSystems || []);
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load filter options.", "error");
    }
  }

  function updateSummaryLine() {
    var start = state.total === 0 ? 0 : (state.offset + 1);
    var end = Math.min(state.offset + state.items.length, state.total);
    els.summaryLine.textContent = "Showing " + start + " - " + end + " of " + state.total + " Great Loop lock(s)";
    els.pagerInfo.textContent = "Page " + (Math.floor(state.offset / state.limit) + 1);
    els.prevPageBtn.disabled = state.offset <= 0;
    els.nextPageBtn.disabled = state.offset + state.limit >= state.total;
  }

  function renderRowImage(row) {
    var image = row && row.image ? row.image : {};
    var hasImage = image.hasImage === true || image.hasImage === "true";
    var hasThumbnail = image.hasThumbnail === true || image.hasThumbnail === "true";
    var imageUrl = hasThumbnail ? image.thumbnailUrl : (image.sourceUrl || image.thumbnailUrl || "");
    var status = hasImage ? (hasThumbnail ? "Has image" : "Missing thumbnail") : "No image";

    if (!hasImage || !imageUrl) {
      return '<td class="fpw-admin-lock-image-cell">'
        + '<div class="fpw-admin-lock-row-thumb-placeholder">No image</div>'
        + '<span class="fpw-admin-image-status">No image</span>'
        + "</td>";
    }

    return '<td class="fpw-admin-lock-image-cell">'
      + '<img class="fpw-admin-lock-row-thumb" src="' + escapeHtml(imageUrl) + '" alt="' + escapeHtml((row.lock_name || "Lock") + " image thumbnail") + '" loading="lazy" decoding="async" onerror="this.classList.add(\'is-hidden\'); this.nextElementSibling.textContent=\'Image unavailable\';">'
      + '<span class="fpw-admin-image-status">' + escapeHtml(status) + "</span>"
      + "</td>";
  }

  function renderTable() {
    if (!state.items.length) {
      els.tableBody.innerHTML = '<tr><td colspan="12">No Great Loop locks found.</td></tr>';
      return;
    }

    els.tableBody.innerHTML = state.items.map(function (row) {
      var lockId = toInt(row.id);
      var hasImage = row.hasImage === true || row.hasImage === "true";
      var publicLabel = row.is_public === true || row.is_public === "true" || row.is_public === 1 ? "Public" : "Hidden";
      return ""
        + "<tr>"
        + '  <td class="num">' + lockId + "</td>"
        + "  <td>" + escapeHtml(row.lock_name || "") + "</td>"
        + renderRowImage(row)
        + "  <td>" + escapeHtml(row.waterway || "") + "</td>"
        + "  <td>" + escapeHtml(row.lock_system || "") + "</td>"
        + "  <td>" + escapeHtml(row.city || "") + "</td>"
        + "  <td>" + escapeHtml(row.state || "") + "</td>"
        + "  <td>" + escapeHtml(row.phone || "") + "</td>"
        + "  <td>" + escapeHtml(row.vhf || "") + "</td>"
        + '  <td><span class="badge-soft ' + (publicLabel === "Public" ? "ok" : "warn") + '">' + publicLabel + "</span></td>"
        + "  <td>" + escapeHtml(row.last_reviewed_at || "") + "</td>"
        + '  <td class="actions"><button type="button" class="btn-inline" data-action="edit" data-lock-id="' + lockId + '">Edit</button></td>'
        + "</tr>";
    }).join("");
  }

  async function loadLocks(resetPaging) {
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
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Failed to load locks.");
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
      els.tableBody.innerHTML = '<tr><td colspan="12">Unable to load locks.</td></tr>';
      showMessage(els.message, err.message || "Unable to load locks.", "error");
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

  function renderImagePreview(lock) {
    var image = lock && lock.image ? lock.image : {};
    var hasImage = image.hasImage === true || image.hasImage === "true";
    if (!hasImage) {
      els.imagePreview.innerHTML = '<div class="lock-image-empty">No image</div>';
      if (els.imageActions) els.imageActions.hidden = true;
      if (els.deleteImageBtn) els.deleteImageBtn.disabled = true;
      return;
    }

    els.imagePreview.innerHTML = ""
      + '<a href="' + escapeHtml(image.sourceUrl || image.thumbnailUrl || "") + '" target="_blank" rel="noopener">'
      + '  <img src="' + escapeHtml(image.thumbnailUrl || image.sourceUrl || "") + '" alt="' + escapeHtml((lock.lock_name || "Lock") + " image") + '">'
      + "</a>"
      + '<div class="small-muted">'
      + '  <div><strong>' + escapeHtml(image.fileName || "") + "</strong></div>"
      + '  <div>Current detail-header image.</div>'
      + "</div>";
    if (els.imageActions) els.imageActions.hidden = false;
    if (els.deleteImageBtn) els.deleteImageBtn.disabled = false;
  }

  function fillForm(lock) {
    setValue("modalLockId", lock.id || 0);
    setValue("modalLockName", lock.lock_name || "");
    setValue("modalSlug", lock.slug || "");
    setValue("modalWaterway", lock.waterway || "");
    setValue("modalLockSystem", lock.lock_system || "");
    setValue("modalOperatingAuthority", lock.operating_authority || "");
    setValue("modalCity", lock.city || "");
    setValue("modalState", lock.state || "");
    setValue("modalZip", lock.zip || "");
    setValue("modalCountry", lock.country || "");
    setValue("modalLatitude", lock.latitude || "");
    setValue("modalLongitude", lock.longitude || "");
    setValue("modalPhone", lock.phone || "");
    setValue("modalVhf", lock.vhf || "");
    setValue("modalSourceName", lock.source_name || "");
    setValue("modalSourceUrl", lock.source_url || "");
    setValue("modalLastReviewedAt", lock.last_reviewed_at || "");
    setValue("modalSortOrder", lock.sort_order || "");
    setChecked("modalIsPublic", lock.is_public);
    setValue("modalNote", lock.note || "");
    setValue("modalApproachNotes", lock.approach_notes || "");
    setValue("modalOperatingNotes", lock.operating_notes || "");
    setValue("modalSpecialInstructions", lock.special_instructions || "");
    if (els.imageFile) els.imageFile.value = "";
    state.currentLock = lock;
    renderImagePreview(lock);
    els.modalLabel.textContent = lock.lock_name || "Great Loop Lock";
    showMessage(els.modalMessage, "", "");
  }

  async function openEditModal(lockId) {
    showMessage(els.message, "", "");
    showMessage(els.modalMessage, "", "");
    try {
      var data = await callApi("get", { id: lockId });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to load lock.");
      }
      fillForm((data.DATA || {}).lock || {});
      lockModal.show();
    } catch (err) {
      showMessage(els.message, err.message || "Unable to load lock.", "error");
    }
  }

  function collectLockPayload() {
    return {
      id: toInt(getValue("modalLockId")),
      lock_name: getValue("modalLockName"),
      slug: getValue("modalSlug"),
      latitude: getValue("modalLatitude"),
      longitude: getValue("modalLongitude"),
      note: getValue("modalNote"),
      city: getValue("modalCity"),
      state: getValue("modalState"),
      zip: getValue("modalZip"),
      phone: getValue("modalPhone"),
      vhf: getValue("modalVhf"),
      waterway: getValue("modalWaterway"),
      lock_system: getValue("modalLockSystem"),
      operating_authority: getValue("modalOperatingAuthority"),
      country: getValue("modalCountry"),
      approach_notes: getValue("modalApproachNotes"),
      operating_notes: getValue("modalOperatingNotes"),
      special_instructions: getValue("modalSpecialInstructions"),
      source_name: getValue("modalSourceName"),
      source_url: getValue("modalSourceUrl"),
      last_reviewed_at: getValue("modalLastReviewedAt"),
      is_public: byId("modalIsPublic").checked ? 1 : 0,
      sort_order: getValue("modalSortOrder")
    };
  }

  async function uploadSelectedImage(lockId) {
    if (!els.imageFile || !els.imageFile.files || !els.imageFile.files.length) {
      return null;
    }

    var formData = new FormData();
    formData.append("nonce", nonce);
    formData.append("id", String(lockId));
    formData.append("imageFile", els.imageFile.files[0]);

    var response = await fetch(endpoint + "&action=uploadImage", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Accept": "application/json",
        "X-CSRF-Token": window.FPW_ADMIN_CSRF_TOKEN || "" },
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
    var lockId = toInt(getValue("modalLockId"));
    var lockName = getValue("modalLockName") || "this lock";

    if (lockId <= 0 || !state.currentLock || !state.currentLock.image
        || !(state.currentLock.image.hasImage === true || state.currentLock.image.hasImage === "true")) {
      return;
    }

    if (!window.confirm("Delete the image and thumbnail for " + lockName + "? The public page will show the placeholder until a new image is uploaded.")) {
      return;
    }

    els.deleteImageBtn.disabled = true;
    showMessage(els.modalMessage, "Deleting image...", "info");

    try {
      var data = await callApi("deleteImage", { nonce: nonce, id: lockId });
      if (!data || data.SUCCESS !== true) {
        throw new Error((data && (data.MESSAGE || (data.ERROR && data.ERROR.MESSAGE))) || "Unable to delete image.");
      }

      var updatedLock = (data.DATA || {}).lock || {};
      state.currentLock = updatedLock;
      if (els.imageFile) els.imageFile.value = "";
      renderImagePreview(updatedLock);
      await loadLocks(false);
      showMessage(els.modalMessage, "Lock image deleted.", "success");
    } catch (err) {
      showMessage(els.modalMessage, err.message || "Unable to delete image.", "error");
      els.deleteImageBtn.disabled = false;
    }
  }

  async function saveCurrentLock() {
    var lockPayload = collectLockPayload();
    els.saveBtn.disabled = true;
    showMessage(els.modalMessage, "Saving...", "info");

    try {
      var saveData = await callApi("save", { nonce: nonce, lock: lockPayload });
      if (!saveData || saveData.SUCCESS !== true) {
        throw new Error((saveData && (saveData.MESSAGE || (saveData.ERROR && saveData.ERROR.MESSAGE))) || "Unable to save lock.");
      }

      var savedLock = (saveData.DATA || {}).lock || {};
      var uploadData = await uploadSelectedImage(toInt(savedLock.id || lockPayload.id));
      var warnings = (saveData.DATA && Array.isArray(saveData.DATA.warnings)) ? saveData.DATA.warnings : [];

      if (uploadData && uploadData.DATA && uploadData.DATA.lock) {
        savedLock = uploadData.DATA.lock;
      }

      renderImagePreview(savedLock);
      await loadLocks(false);
      lockModal.hide();

      showMessage(
        els.message,
        "Lock saved." + (uploadData ? " Image saved." : "") + (warnings.length ? " " + warnings.join(" ") : ""),
        warnings.length ? "info" : "success"
      );
    } catch (err) {
      showMessage(els.modalMessage, err.message || "Unable to save lock.", "error");
    } finally {
      els.saveBtn.disabled = false;
    }
  }

  function bindEvents() {
    els.filtersForm.addEventListener("submit", function (event) {
      event.preventDefault();
      loadLocks(true);
    });

    els.resetFiltersBtn.addEventListener("click", function () {
      els.filterSearch.value = "";
      els.filterState.value = "";
      els.filterWaterway.value = "";
      els.filterLockSystem.value = "";
      els.filterPublicStatus.value = "";
      els.filterImageStatus.value = "";
      els.filterLimit.value = "50";
      state.offset = 0;
      loadLocks(true);
    });

    els.prevPageBtn.addEventListener("click", function () {
      state.offset = Math.max(0, state.offset - state.limit);
      loadLocks(false);
    });

    els.nextPageBtn.addEventListener("click", function () {
      state.offset += state.limit;
      loadLocks(false);
    });

    els.tableBody.addEventListener("click", function (event) {
      var btn = event.target.closest("[data-action='edit']");
      if (!btn) return;
      openEditModal(toInt(btn.getAttribute("data-lock-id")));
    });

    els.saveBtn.addEventListener("click", saveCurrentLock);
    if (els.deleteImageBtn) {
      els.deleteImageBtn.addEventListener("click", deleteCurrentImage);
    }
  }

  function cacheElements() {
    els.message = byId("greatLoopLocksMessage");
    els.filtersForm = byId("greatLoopLocksFilters");
    els.filterSearch = byId("filterSearch");
    els.filterState = byId("filterState");
    els.filterWaterway = byId("filterWaterway");
    els.filterLockSystem = byId("filterLockSystem");
    els.filterPublicStatus = byId("filterPublicStatus");
    els.filterImageStatus = byId("filterImageStatus");
    els.filterLimit = byId("filterLimit");
    els.resetFiltersBtn = byId("resetFiltersBtn");
    els.summaryLine = byId("greatLoopLocksSummaryLine");
    els.tableBody = byId("greatLoopLocksTableBody");
    els.prevPageBtn = byId("prevPageBtn");
    els.nextPageBtn = byId("nextPageBtn");
    els.pagerInfo = byId("pagerInfo");
    els.modal = byId("greatLoopLockModal");
    els.modalLabel = byId("greatLoopLockModalLabel");
    els.modalMessage = byId("greatLoopLockModalMessage");
    els.imagePreview = byId("modalImagePreview");
    els.imageActions = byId("modalImageActions");
    els.imageFile = byId("modalImageFile");
    els.deleteImageBtn = byId("deleteLockImageBtn");
    els.saveBtn = byId("saveGreatLoopLockBtn");
  }

  function init() {
    cacheElements();
    if (!els.filtersForm || !els.tableBody || !els.modal || !window.bootstrap) {
      return;
    }
    lockModal = new window.bootstrap.Modal(els.modal);
    bindEvents();
    loadFacets().then(function () {
      return loadLocks(true);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);

