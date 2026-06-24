(function (window, document) {
  "use strict";

  var formEl = document.querySelector("[data-anchorage-filter-form]");
  var mapEl = document.getElementById("fpwAnchorageMap");
  var detailMapEl = document.getElementById("fpwAnchorageDetailMap");
  var dataEl = document.getElementById("fpwAnchorageMapData");
  var resultListEl = document.querySelector("[data-anchorage-result-list]");
  var emptyListEl = document.querySelector("[data-anchorage-empty-list]");
  var emptyMapEl = document.querySelector("[data-anchorage-empty-map]");
  var summaryEl = document.querySelector("[data-anchorage-result-summary]");
  var statusEl = document.querySelector("[data-anchorage-filter-status]");
  var viewButtons = Array.prototype.slice.call(document.querySelectorAll("[data-anchorage-view-button]"));
  var viewPanels = Array.prototype.slice.call(document.querySelectorAll("[data-anchorage-view-panel]"));
  var map = null;
  var markerLayer = null;
  var markerBySlug = {};
  var noaaLayerByMap = new WeakMap();
  var noaaWarned = false;
  var noaaWmsUrl = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer";
  var noaaLayerNames = "0,1,2,3,4,5,6,7,8,9,10,11,12";

  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function parseMapData() {
    if (!dataEl) return [];
    try {
      var parsed = JSON.parse(dataEl.textContent || "[]");
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  function getControl(selector) {
    return formEl ? formEl.querySelector(selector) : null;
  }

  function collectFilters() {
    return {
      q: valueOf("[name='q']"),
      locationGroup: valueOf("[name='locationGroup']"),
      waterway: valueOf("[name='waterway']"),
      stateProvince: valueOf("[name='stateProvince']"),
      country: valueOf("[name='country']"),
      anchorageType: valueOf("[name='anchorageType']"),
      publicStatus: valueOf("[name='publicStatus']")
    };
  }

  function valueOf(selector) {
    var el = getControl(selector);
    return el ? (el.value || "").trim() : "";
  }

  function appendFilters(params, filters) {
    Object.keys(filters || {}).forEach(function (key) {
      if (filters[key]) params.set(key, filters[key]);
      else params.delete(key);
    });
  }

  function apiUrl(action, filters) {
    var endpoint = formEl ? formEl.getAttribute("data-anchorage-api-endpoint") : "";
    var url = new URL(endpoint || "/api/v1/greatLoopAnchorages.cfc?method=handle&returnFormat=json", window.location.origin);
    url.searchParams.set("action", action);
    appendFilters(url.searchParams, filters || {});
    return url.toString();
  }

  function pageUrl(filters) {
    var pagePath = formEl ? formEl.getAttribute("data-anchorage-page-url") : window.location.pathname;
    var url = new URL(pagePath || window.location.pathname, window.location.origin);
    appendFilters(url.searchParams, filters || {});
    return url.pathname + url.search;
  }

  function fetchJson(action, filters) {
    return fetch(apiUrl(action, filters), {
      method: "GET",
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    }).then(function (response) {
      if (!response.ok) throw new Error("Anchorage API request failed.");
      return response.json();
    }).then(function (data) {
      if (!data || data.success !== true) {
        throw new Error(data && data.message ? data.message : "Anchorage API response failed.");
      }
      return data;
    });
  }

  function setStatus(message, isError) {
    if (!statusEl) return;
    statusEl.textContent = message || "";
    statusEl.hidden = !message;
    statusEl.classList.toggle("is-error", !!isError);
  }

  function addBaseLayer(targetMap) {
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(targetMap);
  }

  function getNoaaLayer(targetMap) {
    var existing = noaaLayerByMap.get(targetMap);
    if (existing) return existing;
    var layer = window.L.tileLayer.wms(noaaWmsUrl, {
      layers: noaaLayerNames,
      format: "image/png",
      transparent: true,
      version: "1.3.0",
      attribution: "NOAA"
    });
    layer.on("tileerror", function () {
      if (!noaaWarned && window.console && typeof window.console.warn === "function") {
        noaaWarned = true;
        window.console.warn("NOAA nautical chart layer failed to load; base map and anchorage markers remain available.");
      }
    });
    noaaLayerByMap.set(targetMap, layer);
    return layer;
  }

  function bindNoaaToggle(targetMap, root) {
    var scope = root || document;
    var toggle = scope.querySelector("[data-noaa-chart-toggle]");
    if (!targetMap || !toggle || !window.L) return;
    toggle.addEventListener("change", function () {
      var layer = getNoaaLayer(targetMap);
      if (toggle.checked) {
        layer.addTo(targetMap);
      } else if (targetMap.hasLayer(layer)) {
        targetMap.removeLayer(layer);
      }
    });
  }

  function normalizeAnchorage(row) {
    var slug = row.slug || "";
    var base = formEl ? formEl.getAttribute("data-anchorage-detail-url-base") || "" : "";
    return {
      anchorage_id: row.anchorage_id || "",
      slug: slug,
      anchorage_name: row.anchorage_name || row.name || "",
      nearest_city: row.nearest_city || "",
      state_province: row.state_province || "",
      country: row.country || "",
      location_group: row.location_group || "",
      waterway: row.waterway || "",
      latitude: row.latitude || row.lat || "",
      longitude: row.longitude || row.lng || "",
      anchorage_type: row.anchorage_type || "",
      holding: row.holding || "",
      protection: row.protection || "",
      public_status: row.public_status || "",
      url: row.url || (base && slug ? base.replace(/\/?$/, "/") + encodeURIComponent(slug) + "/" : "")
    };
  }

  function popupHtml(item) {
    var location = [item.nearest_city, item.state_province, item.country].filter(Boolean).join(", ");
    return ""
      + '<div class="fpw-anchorage-popup">'
      + "<strong>" + escapeHtml(item.anchorage_name) + "</strong>"
      + (location ? "<span>" + escapeHtml(location) + "</span>" : "")
      + (item.waterway ? "<span>" + escapeHtml(item.waterway) + "</span>" : "")
      + (item.location_group ? "<span>" + escapeHtml(item.location_group) + "</span>" : "")
      + (item.anchorage_type ? "<small>Type: " + escapeHtml(item.anchorage_type) + "</small>" : "")
      + (item.protection ? "<small>Protection: " + escapeHtml(item.protection) + "</small>" : "")
      + (item.holding ? "<small>Holding: " + escapeHtml(item.holding) + "</small>" : "")
      + (item.public_status ? "<small>Status: " + escapeHtml(item.public_status) + "</small>" : "")
      + (item.url ? '<a href="' + escapeHtml(item.url) + '">Open anchorage guide</a>' : "")
      + "</div>";
  }

  function renderMarkers(rows) {
    var bounds = null;
    var markerRows = (rows || []).map(normalizeAnchorage).filter(function (item) {
      return Number.isFinite(Number(item.latitude)) && Number.isFinite(Number(item.longitude));
    });

    if (!map || !markerLayer) return;
    markerLayer.clearLayers();
    markerBySlug = {};

    if (!markerRows.length) {
      map.setView([38.5, -84], 5);
      if (emptyMapEl) emptyMapEl.hidden = (rows || []).length !== 0;
      return;
    }

    if (emptyMapEl) emptyMapEl.hidden = true;
    bounds = window.L.latLngBounds([]);
    markerRows.forEach(function (item) {
      var point = [Number(item.latitude), Number(item.longitude)];
      var marker = window.L.marker(point).addTo(markerLayer).bindPopup(popupHtml(item));
      bounds.extend(point);
      markerBySlug[item.slug] = marker;
    });

    if (markerRows.length === 1) {
      map.setView([Number(markerRows[0].latitude), Number(markerRows[0].longitude)], 12);
    } else if (bounds.isValid()) {
      map.fitBounds(bounds.pad(0.18), { maxZoom: 10 });
    }
  }

  function initMap() {
    if (!mapEl || !window.L) return;
    map = window.L.map(mapEl, { zoomControl: true, attributionControl: true });
    addBaseLayer(map);
    markerLayer = window.L.layerGroup().addTo(map);
    renderMarkers(parseMapData());
    bindNoaaToggle(map, document);
  }

  function initDetailMap() {
    if (!detailMapEl || !window.L) return;
    var lat = Number(detailMapEl.getAttribute("data-lat"));
    var lng = Number(detailMapEl.getAttribute("data-lng"));
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    var detailMap = window.L.map(detailMapEl, { zoomControl: true, attributionControl: true }).setView([lat, lng], 15);
    var item = {
      anchorage_name: detailMapEl.getAttribute("data-name") || "Anchorage location",
      nearest_city: detailMapEl.getAttribute("data-location") || "",
      waterway: detailMapEl.getAttribute("data-waterway") || "",
      location_group: detailMapEl.getAttribute("data-location-group") || "",
      anchorage_type: detailMapEl.getAttribute("data-type") || "",
      protection: detailMapEl.getAttribute("data-protection") || "",
      holding: detailMapEl.getAttribute("data-holding") || "",
      public_status: detailMapEl.getAttribute("data-public-status") || ""
    };
    addBaseLayer(detailMap);
    window.L.marker([lat, lng]).addTo(detailMap).bindPopup(popupHtml(item)).openPopup();
    bindNoaaToggle(detailMap, detailMapEl.closest(".fpw-anchorage-panel") || document);
    window.setTimeout(function () { detailMap.invalidateSize(); }, 100);
  }

  function renderSummary(summary) {
    if (!summaryEl) return;
    var total = Number(summary && summary.total ? summary.total : 0);
    var markers = Number(summary && summary.markers ? summary.markers : 0);
    summaryEl.textContent = total + " published anchorage reference" + (total === 1 ? "" : "s") + " match, with " + markers + " map marker" + (markers === 1 ? "" : "s") + ".";
  }

  function renderList(rows) {
    var html = "";
    var normalized = (rows || []).map(normalizeAnchorage);
    if (!resultListEl || !emptyListEl) return;
    normalized.forEach(function (item) {
      var location = [item.nearest_city, item.state_province, item.country].filter(Boolean).join(", ");
      html += '<article class="fpw-anchorage-result-card" data-anchorage-card data-slug="' + escapeHtml(item.slug) + '">'
        + "<div>"
        + '<h3><a href="' + escapeHtml(item.url || "#") + '">' + escapeHtml(item.anchorage_name) + "</a></h3>"
        + "<p>" + escapeHtml(location || "Location not listed") + "</p>"
        + "<p>" + escapeHtml([item.location_group, item.waterway].filter(Boolean).join(" - ") || "Waterway not listed") + "</p>"
        + "</div>"
        + "<dl>"
        + "<div><dt>Type</dt><dd>" + escapeHtml(item.anchorage_type || "Not listed") + "</dd></div>"
        + "<div><dt>Holding</dt><dd>" + escapeHtml(item.holding || "Not listed") + "</dd></div>"
        + "<div><dt>Protection</dt><dd>" + escapeHtml(item.protection || "Not listed") + "</dd></div>"
        + "<div><dt>Status</dt><dd>" + escapeHtml(item.public_status || "Planning reference") + "</dd></div>"
        + "</dl>"
        + "</article>";
    });
    resultListEl.innerHTML = html;
    resultListEl.hidden = normalized.length === 0;
    emptyListEl.hidden = normalized.length !== 0;
  }

  function focusCardMarker(card) {
    var slug = card ? card.getAttribute("data-slug") : "";
    var marker = slug ? markerBySlug[slug] : null;
    if (!map || !marker) return;
    setView("map");
    map.setView(marker.getLatLng(), Math.max(map.getZoom(), 13));
    marker.openPopup();
  }

  function setView(viewName) {
    viewButtons.forEach(function (button) {
      var isActive = button.getAttribute("data-anchorage-view-button") === viewName;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-pressed", isActive ? "true" : "false");
    });
    viewPanels.forEach(function (panel) {
      panel.hidden = panel.getAttribute("data-anchorage-view-panel") !== viewName;
    });
    if (viewName === "map" && map) {
      window.setTimeout(function () { map.invalidateSize(); }, 0);
    }
  }

  function applyFilters() {
    var filters = collectFilters();
    setStatus("Updating anchorage results...", false);
    return fetchJson("anchorages", filters).then(function (data) {
      renderMarkers(data.anchorages || []);
      renderList(data.anchorages || []);
      renderSummary(data.summary || {});
      if (window.history && window.history.replaceState) {
        window.history.replaceState({}, "", pageUrl(filters));
      }
      setStatus("", false);
    }).catch(function (err) {
      if (window.console && window.console.error) window.console.error("FPW anchorage filter update failed", err);
      setStatus("Unable to update anchorage filters. Please try again.", true);
    });
  }

  function resetOtherSelects(activeSelect) {
    if (!formEl || !activeSelect) return;
    Array.prototype.slice.call(formEl.querySelectorAll("select")).forEach(function (selectEl) {
      if (selectEl !== activeSelect) {
        selectEl.value = "";
      }
    });
  }

  function clearFilters(event) {
    if (event) event.preventDefault();
    if (!formEl) return;
    Array.prototype.slice.call(formEl.querySelectorAll("input, select")).forEach(function (control) {
      control.value = "";
    });
    return applyFilters();
  }

  viewButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      setView(button.getAttribute("data-anchorage-view-button") || "map");
    });
  });

  if (resultListEl) {
    resultListEl.addEventListener("click", function (event) {
      var card = event.target.closest("[data-anchorage-card]");
      if (!card || event.target.closest("a")) return;
      focusCardMarker(card);
    });
  }

  initMap();
  initDetailMap();

  if (formEl && window.fetch && window.Promise) {
    formEl.addEventListener("submit", function (event) {
      event.preventDefault();
      applyFilters();
    });
    Array.prototype.slice.call(formEl.querySelectorAll("select")).forEach(function (selectEl) {
      selectEl.addEventListener("change", function () {
        resetOtherSelects(selectEl);
        applyFilters();
      });
    });
    var clearLink = formEl.querySelector("[data-anchorage-clear]");
    if (clearLink) clearLink.addEventListener("click", clearFilters);
  }
})(window, document);
