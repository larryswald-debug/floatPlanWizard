(function () {
  "use strict";

  var mapEl = document.getElementById("fpwLockMap");
  var dataEl = document.getElementById("fpwLockMapData");
  var emptyMapEl = document.querySelector("[data-lock-empty-map]");
  var formEl = document.querySelector("[data-lock-filter-form]");
  var detailUrlBase = formEl ? formEl.getAttribute("data-lock-detail-url-base") || "" : "";
  var statusEl = document.querySelector("[data-lock-filter-status]");
  var resultSummaryEl = document.querySelector("[data-lock-result-summary]");
  var resultListEl = document.querySelector("[data-lock-result-list]");
  var emptyListEl = document.querySelector("[data-lock-empty-list]");
  var viewButtons = Array.prototype.slice.call(document.querySelectorAll("[data-lock-view-button]"));
  var viewPanels = Array.prototype.slice.call(document.querySelectorAll("[data-lock-view-panel]"));
  var mapCardEl = document.querySelector(".fpw-lock-map-card");
  var mapViewPanelEl = document.querySelector('[data-lock-view-panel="map"]');
  var waterwayPanelEl = document.querySelector(".fpw-lock-waterways");
  var waterwayShortcutLinks = Array.prototype.slice.call(document.querySelectorAll("[data-lock-waterway-shortcut]"));
  var locks = [];
  var map = null;
  var markerLayer = null;
  var bounds = null;

  function parseMapData() {
    if (!dataEl) {
      return [];
    }
    try {
      var parsed = JSON.parse(dataEl.textContent || "[]");
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function buildDetailUrl(lock) {
    var slug = lock && lock.slug ? String(lock.slug) : "";
    if (detailUrlBase && slug) {
      return detailUrlBase.replace(/\/?$/, "/") + encodeURIComponent(slug) + "/";
    }
    return lock.detailUrl || lock.url || "";
  }

  function normalizeLock(lock) {
    return {
      id: lock.id || "",
      name: lock.lockName || lock.name || "",
      slug: lock.slug || "",
      city: lock.city || "",
      state: lock.state || "",
      waterway: lock.waterway || "",
      lockSystem: lock.lockSystem || lock.lock_system || "",
      phone: lock.phone || "",
      vhf: lock.vhf || "",
      lat: lock.latitude || lock.lat || "",
      lng: lock.longitude || lock.lng || "",
      url: buildDetailUrl(lock)
    };
  }

  function normalizeLocks(nextLocks) {
    if (!Array.isArray(nextLocks)) {
      return [];
    }
    return nextLocks.map(normalizeLock);
  }

  function markerPopup(lock) {
    var location = [lock.city, lock.state].filter(Boolean).join(", ");
    var bits = [];
    if (lock.vhf) bits.push("VHF " + lock.vhf);
    if (lock.phone) bits.push(lock.phone);
    return ""
      + '<div class="fpw-lock-popup">'
      + "<strong>" + escapeHtml(lock.name) + "</strong>"
      + (location ? "<span>" + escapeHtml(location) + "</span>" : "")
      + (lock.waterway ? "<span>" + escapeHtml(lock.waterway) + "</span>" : "")
      + (bits.length ? "<small>" + escapeHtml(bits.join(" | ")) + "</small>" : "")
      + (lock.url ? '<a href="' + escapeHtml(lock.url) + '">Open lock guide</a>' : "")
      + "</div>";
  }

  function addBaseLayer(targetMap) {
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(targetMap);
  }

  function renderMarkers(nextLocks) {
    var normalizedLocks = normalizeLocks(nextLocks);
    var markerLocks = normalizedLocks.filter(function (lock) {
      return Number.isFinite(Number(lock.lat)) && Number.isFinite(Number(lock.lng));
    });

    locks = markerLocks;
    bounds = null;

    if (!map || !markerLayer) {
      return;
    }

    markerLayer.clearLayers();

    if (!markerLocks.length) {
      map.setView([39.5, -95.5], 4);
      if (emptyMapEl) emptyMapEl.hidden = normalizedLocks.length !== 0;
      return;
    }

    if (emptyMapEl) emptyMapEl.hidden = true;
    bounds = window.L.latLngBounds([]);

    markerLocks.forEach(function (lock) {
      var point = [Number(lock.lat), Number(lock.lng)];
      bounds.extend(point);
      window.L.marker(point).addTo(markerLayer).bindPopup(markerPopup(lock));
    });

    if (markerLocks.length === 1) {
      map.setView([Number(markerLocks[0].lat), Number(markerLocks[0].lng)], 10);
    } else if (bounds.isValid()) {
      map.fitBounds(bounds.pad(0.18));
    }
  }

  function initMap() {
    if (!mapEl || !window.L) {
      return;
    }

    map = window.L.map(mapEl, {
      zoomControl: true,
      attributionControl: true
    });

    addBaseLayer(map);
    markerLayer = window.L.layerGroup().addTo(map);
    renderMarkers(parseMapData());
  }

  function syncWaterwayHeight() {
    if (!mapCardEl || !waterwayPanelEl) {
      return;
    }
    if (window.innerWidth <= 1180) {
      waterwayPanelEl.style.removeProperty("--fpw-lock-waterway-max-height");
      return;
    }
    if (mapViewPanelEl && mapViewPanelEl.hidden) {
      return;
    }

    var panelRect = mapCardEl.getBoundingClientRect();
    var mapRect = mapEl ? mapEl.getBoundingClientRect() : panelRect;
    var height = mapRect.bottom - panelRect.top;
    if (height > 0) {
      waterwayPanelEl.style.setProperty("--fpw-lock-waterway-max-height", height + "px");
    }
  }

  function initDetailMap() {
    var detailMapEl = document.getElementById("fpwLockDetailMap");
    if (!detailMapEl || !window.L) {
      return;
    }

    var lat = Number(detailMapEl.getAttribute("data-lat"));
    var lng = Number(detailMapEl.getAttribute("data-lng"));
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return;
    }

    var detailMap = window.L.map(detailMapEl, {
      zoomControl: true,
      attributionControl: true
    }).setView([lat, lng], 14);

    addBaseLayer(detailMap);

    var lock = {
      name: detailMapEl.getAttribute("data-lock-name") || "Lock location",
      city: detailMapEl.getAttribute("data-city") || "",
      state: detailMapEl.getAttribute("data-state") || "",
      waterway: detailMapEl.getAttribute("data-waterway") || "",
      phone: detailMapEl.getAttribute("data-phone") || "",
      vhf: detailMapEl.getAttribute("data-vhf") || ""
    };

    window.L.marker([lat, lng]).addTo(detailMap).bindPopup(markerPopup(lock));

    window.setTimeout(function () {
      detailMap.invalidateSize();
    }, 100);
  }

  function initLockImageModal() {
    var openButton = document.querySelector("[data-lock-image-open]");
    var modal = document.querySelector("[data-lock-image-modal]");
    if (!openButton || !modal) {
      return;
    }

    var closeButtons = Array.prototype.slice.call(modal.querySelectorAll("[data-lock-image-close]"));
    var closeButton = modal.querySelector(".fpw-lock-image-modal__close");
    var lastActiveElement = null;

    function setModalOpen(isOpen) {
      modal.hidden = !isOpen;
      document.body.classList.toggle("is-lock-image-modal-open", isOpen);
      openButton.setAttribute("aria-expanded", isOpen ? "true" : "false");

      if (isOpen) {
        lastActiveElement = document.activeElement;
        window.setTimeout(function () {
          if (closeButton) {
            closeButton.focus();
          }
        }, 0);
      } else if (lastActiveElement && typeof lastActiveElement.focus === "function") {
        lastActiveElement.focus();
      }
    }

    openButton.addEventListener("click", function () {
      setModalOpen(true);
    });

    closeButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        setModalOpen(false);
      });
    });

    document.addEventListener("keydown", function (event) {
      if (!modal.hidden && event.key === "Escape") {
        setModalOpen(false);
      }
    });
  }

  function setView(viewName) {
    viewButtons.forEach(function (button) {
      var isActive = button.getAttribute("data-lock-view-button") === viewName;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-pressed", isActive ? "true" : "false");
    });

    viewPanels.forEach(function (panel) {
      panel.hidden = panel.getAttribute("data-lock-view-panel") !== viewName;
    });

    if (viewName === "map" && map) {
      window.setTimeout(function () {
        map.invalidateSize();
        if (bounds && bounds.isValid()) {
          map.fitBounds(bounds.pad(0.18));
        }
        syncWaterwayHeight();
      }, 0);
    }
  }

  function getControl(selector) {
    return formEl ? formEl.querySelector(selector) : null;
  }

  function collectFilters() {
    var stateSelect = getControl("[data-lock-state-select]");
    var waterwaySelect = getControl("[data-lock-waterway-select]");

    return {
      state: stateSelect ? stateSelect.value : "",
      waterway: waterwaySelect ? waterwaySelect.value : ""
    };
  }

  function appendFilters(params, filters) {
    if (filters.state) params.set("state", filters.state);
    if (filters.waterway) params.set("waterway", filters.waterway);
  }

  function apiUrl(action, filters) {
    var endpoint = formEl ? formEl.getAttribute("data-lock-api-endpoint") : "";
    var url = new URL(endpoint || "/api/v1/greatLoopLocks.cfc?method=handle&returnFormat=json", window.location.origin);
    url.searchParams.set("action", action);
    appendFilters(url.searchParams, filters || {});
    return url.toString();
  }

  function pageUrl(filters) {
    var pagePath = formEl ? formEl.getAttribute("data-lock-page-url") : window.location.pathname;
    var url = new URL(pagePath || window.location.pathname, window.location.origin);
    appendFilters(url.searchParams, filters || {});
    return url.pathname + url.search;
  }

  function fetchJson(action, filters) {
    return fetch(apiUrl(action, filters), {
      method: "GET",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json"
      }
    }).then(function (response) {
      if (!response.ok) {
        throw new Error("Lock API request failed.");
      }
      return response.json();
    }).then(function (data) {
      if (!data || data.success !== true) {
        throw new Error(data && data.message ? data.message : "Lock API response failed.");
      }
      return data;
    });
  }

  function setStatus(message, isError) {
    if (!statusEl) {
      return;
    }
    statusEl.textContent = message || "";
    statusEl.hidden = !message;
    statusEl.classList.toggle("is-error", !!isError);
  }

  function setApplyBusy(isBusy) {
    var applyButton = getControl("[data-lock-apply]");
    if (applyButton) {
      applyButton.disabled = !!isBusy;
    }
  }

  function setSelectBusy(selectEl, isBusy) {
    if (selectEl) {
      selectEl.disabled = !!isBusy;
    }
  }

  function populateSelect(selectEl, options, selectedValue) {
    if (!selectEl) {
      return;
    }

    var valueToSelect = selectedValue || "";
    var html = '<option value="">All</option>';
    var hasSelectedValue = !valueToSelect;

    (Array.isArray(options) ? options : []).forEach(function (option) {
      var optionValue = option && option.value ? String(option.value) : "";
      var optionLabel = option && option.label ? String(option.label) : optionValue;
      var isSelected = optionValue === valueToSelect;
      if (isSelected) {
        hasSelectedValue = true;
      }
      html += '<option value="' + escapeHtml(optionValue) + '"' + (isSelected ? " selected" : "") + ">"
        + escapeHtml(optionLabel)
        + "</option>";
    });

    selectEl.innerHTML = html;
    if (!hasSelectedValue) {
      selectEl.value = "";
    }
  }

  function renderResultSummary(summary) {
    if (!resultSummaryEl || !summary) {
      return;
    }
    var total = Number(summary.total || 0);
    resultSummaryEl.textContent = total === 1
      ? "1 reviewed lock matches the current filters."
      : total + " reviewed locks match the current filters.";
  }

  function renderList(nextLocks) {
    var normalized = normalizeLocks(nextLocks);
    var html = "";

    if (!resultListEl || !emptyListEl) {
      return;
    }

    normalized.forEach(function (lock) {
      var location = [lock.city, lock.state].filter(Boolean).join(", ");
      html += ""
        + '<article class="fpw-lock-result-card">'
        + "<div>"
        + '<h3><a href="' + escapeHtml(lock.url) + '">' + escapeHtml(lock.name) + "</a></h3>"
        + "<p>" + escapeHtml(location)
        + (lock.waterway ? " &bull; " + escapeHtml(lock.waterway) : "")
        + "</p>"
        + "</div>"
        + "<dl>"
        + "<div><dt>VHF</dt><dd>" + escapeHtml(lock.vhf || "Not listed") + "</dd></div>"
        + "<div><dt>Phone</dt><dd>" + escapeHtml(lock.phone || "Not listed") + "</dd></div>"
        + "</dl>"
        + "</article>";
    });

    resultListEl.innerHTML = html;
    resultListEl.hidden = normalized.length === 0;
    emptyListEl.hidden = normalized.length !== 0;
  }

  function renderLockResults(data) {
    var resultLocks = data && Array.isArray(data.locks) ? data.locks : [];
    renderMarkers(resultLocks);
    renderList(resultLocks);
    renderResultSummary(data ? data.summary : {});
    window.setTimeout(syncWaterwayHeight, 0);
  }

  function setActiveWaterwayShortcut(waterwayValue) {
    var selectedValue = waterwayValue || "";
    waterwayShortcutLinks.forEach(function (link) {
      var isActive = selectedValue && link.getAttribute("data-waterway") === selectedValue;
      link.classList.toggle("is-active", !!isActive);
      if (isActive) {
        link.setAttribute("aria-current", "true");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  function handleAjaxError(err) {
    if (window.console && typeof window.console.error === "function") {
      window.console.error("FPW lock filter update failed", err);
    }
    setStatus("Unable to update lock filters. Please try again.", true);
  }

  function loadOptions(filters, waterwayValue) {
    var waterwaySelect = getControl("[data-lock-waterway-select]");

    setSelectBusy(waterwaySelect, true);
    setStatus("Updating lock filters...", false);

    return fetchJson("filterOptions", filters).then(function (data) {
      populateSelect(waterwaySelect, data.waterways, waterwayValue || "");
      setStatus("", false);
      return data;
    }).catch(function (err) {
      handleAjaxError(err);
    }).then(function (data) {
      setSelectBusy(waterwaySelect, false);
      return data;
    });
  }

  function applyFilters() {
    var filters = collectFilters();

    setApplyBusy(true);
    setStatus("Updating lock results...", false);

    return fetchJson("locks", filters).then(function (data) {
      renderLockResults(data);
      window.history.replaceState({}, "", pageUrl(filters));
      setActiveWaterwayShortcut(filters.waterway);
      setStatus("", false);
      return data;
    }).catch(function (err) {
      handleAjaxError(err);
    }).then(function (data) {
      setApplyBusy(false);
      return data;
    });
  }

  function clearFilters() {
    var stateSelect = getControl("[data-lock-state-select]");
    var waterwaySelect = getControl("[data-lock-waterway-select]");
    var emptyFilters = {};

    if (stateSelect) stateSelect.value = "";
    if (waterwaySelect) waterwaySelect.value = "";
    setActiveWaterwayShortcut("");

    setApplyBusy(true);
    setSelectBusy(waterwaySelect, true);
    setStatus("Clearing lock filters...", false);

    return Promise.all([
      fetchJson("filterOptions", emptyFilters),
      fetchJson("locks", emptyFilters)
    ]).then(function (results) {
      populateSelect(waterwaySelect, results[0].waterways, "");
      renderLockResults(results[1]);
      window.history.replaceState({}, "", pageUrl(emptyFilters));
      setActiveWaterwayShortcut("");
      setStatus("", false);
      return results;
    }).catch(function (err) {
      handleAjaxError(err);
    }).then(function (results) {
      setApplyBusy(false);
      setSelectBusy(waterwaySelect, false);
      return results;
    });
  }

  viewButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      setView(button.getAttribute("data-lock-view-button") || "map");
    });
  });

  initMap();
  initDetailMap();
  initLockImageModal();
  syncWaterwayHeight();
  window.setTimeout(syncWaterwayHeight, 150);
  window.addEventListener("load", syncWaterwayHeight);
  window.addEventListener("resize", syncWaterwayHeight);

  if (!formEl || !window.fetch || !window.Promise) {
    return;
  }

  var stateSelect = getControl("[data-lock-state-select]");
  var waterwaySelect = getControl("[data-lock-waterway-select]");
  var clearLink = getControl("[data-lock-clear]");

  function applyWaterwayShortcut(link) {
    var waterwayValue = link ? link.getAttribute("data-waterway") || "" : "";
    if (!waterwayValue) {
      return;
    }

    if (stateSelect) stateSelect.value = "";
    if (waterwaySelect) waterwaySelect.value = "";
    setActiveWaterwayShortcut(waterwayValue);

    loadOptions({}, waterwayValue).then(function (data) {
      if (data) {
        if (waterwaySelect) waterwaySelect.value = waterwayValue;
        applyFilters();
      }
    });
  }

  if (window.history && window.history.replaceState) {
    var currentParams = new URLSearchParams(window.location.search);
    if (currentParams.has("q")
      || currentParams.has("hasVhf")
      || currentParams.has("hasPhone")
      || currentParams.has("hasNotes")
      || currentParams.has("lockSystem")
      || currentParams.has("lock_system")) {
      window.history.replaceState({}, "", pageUrl(collectFilters()));
    }
  }

  if (stateSelect) {
    stateSelect.addEventListener("change", function () {
      if (waterwaySelect) waterwaySelect.value = "";
      loadOptions({ state: stateSelect.value }, "").then(function (data) {
        if (data) {
          applyFilters();
        }
      });
    });
  }

  if (waterwaySelect) {
    setActiveWaterwayShortcut(waterwaySelect.value);

    waterwaySelect.addEventListener("change", function () {
      applyFilters();
    });
  }

  waterwayShortcutLinks.forEach(function (link) {
    link.addEventListener("click", function (event) {
      if (event.defaultPrevented
        || event.button !== 0
        || event.metaKey
        || event.ctrlKey
        || event.shiftKey
        || event.altKey) {
        return;
      }
      event.preventDefault();
      applyWaterwayShortcut(link);
    });

    link.addEventListener("keydown", function (event) {
      if (event.key === " ") {
        event.preventDefault();
        applyWaterwayShortcut(link);
      }
    });
  });

  formEl.addEventListener("submit", function (event) {
    event.preventDefault();
    applyFilters();
  });

  if (clearLink) {
    clearLink.addEventListener("click", function (event) {
      event.preventDefault();
      clearFilters();
    });
  }
})();
