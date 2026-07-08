(function (window, document) {
  "use strict";

  var formEl = document.querySelector("[data-ports-filter-form]");
  var mapEl = document.getElementById("fpwPortsMap");
  var detailMapEl = document.getElementById("fpwPortDetailMap");
  var dataEl = document.getElementById("fpwPortsMapData");
  var detailDataEl = document.getElementById("fpwPortDetailData");
  var resultListEl = document.querySelector("[data-ports-result-list]");
  var emptyListEl = document.querySelector("[data-ports-empty-list]");
  var emptyMapEl = document.querySelector("[data-ports-empty-map]");
  var summaryEl = document.querySelector("[data-ports-result-summary]");
  var statusEl = document.querySelector("[data-ports-filter-status]");
  var totalCountEl = document.querySelector("[data-ports-total-count]");
  var viewButtons = Array.prototype.slice.call(document.querySelectorAll("[data-ports-view-button]"));
  var viewPanels = Array.prototype.slice.call(document.querySelectorAll("[data-ports-view-panel]"));
  var map = null;
  var markerLayer = null;
  var detailMap = null;
  var detailMarker = null;
  var currentRows = [];
  var markerById = {};
  var portsById = {};
  var addedPortIds = {};
  var authState = {
    checked: false,
    loggedIn: false
  };

  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function slugify(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 220);
  }

  function getConfig(name, fallback) {
    if (!formEl) return fallback || "";
    return formEl.getAttribute(name) || fallback || "";
  }

  function normalizeBasePath(value) {
    if (!value) return "";
    var normalized = String(value).replace(/\/+$/, "");
    if (normalized === "/") return "";
    return normalized.charAt(0) === "/" ? normalized : "/" + normalized;
  }

  function scriptBasePath() {
    var script = document.currentScript;
    var src = script && script.getAttribute ? (script.getAttribute("src") || "") : "";
    var marker = "/assets/js/app/ports-library.js";
    var markerIndex = src.toLowerCase().indexOf(marker);
    if (markerIndex === -1) return "";
    return normalizeBasePath(src.slice(0, markerIndex));
  }

  function locationBasePath() {
    var basePath = window.location.pathname || "";
    basePath = basePath.replace(/[?#].*$/, "");
    basePath = basePath.replace(/\/api\/v1(\/.*)?$/i, "");
    basePath = basePath.replace(/\/great-loop(\/.*)?$/i, "");
    basePath = basePath.replace(/\/(app|admin|assets|tests)(\/.*)?$/i, "");
    basePath = basePath.replace(/\/[^/]*\.(cfm|cfc)$/i, "");
    basePath = basePath.replace(/\/$/, "");
    return normalizeBasePath(basePath);
  }

  function appBasePath() {
    return normalizeBasePath(window.FPW_BASE || "") || scriptBasePath() || locationBasePath();
  }

  function apiBasePath() {
    return normalizeBasePath(window.FPW_API_BASE || "") || (appBasePath() + "/api/v1");
  }

  function detailBase() {
    return getConfig("data-ports-detail-base", appBasePath() + "/great-loop/ports/");
  }

  function loginUrl() {
    return getConfig("data-ports-login-url", appBasePath() + "/app/login.cfm");
  }

  function joinUrl() {
    return getConfig("data-ports-join-url", appBasePath() + "/app/join.cfm");
  }

  function detailSegment(item) {
    var id = Number(item.id || item.ID || 0);
    var slug = slugify(item.slug || item.SLUG || "");
    var prefix = String(id) + "-";
    var fallback = slugify((item.name || item.NAME || "port") + " " + (item.stateCode || item.STATE_CODE || ""));

    if (!id) return slug || fallback;
    if (slug && slug.indexOf(prefix) === 0) return slug;
    if (slug) return prefix + slug;
    return prefix + fallback;
  }

  function detailUrl(item) {
    var base = detailBase().replace(/\/?$/, "/");
    return base + detailSegment(item) + "/";
  }

  function parseJsonElement(element, fallback) {
    if (!element) return fallback;
    try {
      var parsed = JSON.parse(element.textContent || "");
      return parsed || fallback;
    } catch (err) {
      return fallback;
    }
  }

  function tagLabel(value) {
    var tag = String(value || "").trim().toLowerCase();
    if (tag === "major-stop-candidate") return "Major stop candidate";
    if (tag === "route-gateway-candidate") return "Route gateway candidate";
    if (tag === "needs-review") return "Needs review";
    if (tag === "bad-coordinates") return "Bad coordinates";
    if (tag === "coordinate-state-mismatch") return "Coordinate/state review";
    if (tag === "duplicate-name-review") return "Duplicate name review";
    if (tag === "duplicate-name-state-review") return "Duplicate name/state review";
    if (tag === "needs-route-segment-review") return "Route segment review";
    if (tag === "non-loop-or-side-route-review") return "Side-route review";
    tag = tag.replace(/-/g, " ");
    return tag ? tag.charAt(0).toUpperCase() + tag.slice(1) : "";
  }

  function qualityLabel(value) {
    var status = String(value || "").trim().toLowerCase();
    if (status === "verified") return "Verified";
    if (status === "derived_unverified") return "Derived, not verified";
    if (status === "needs_review") return "Needs review";
    if (status === "bad_coordinates") return "Coordinate review needed";
    if (status === "missing_coordinates") return "Coordinates missing";
    if (status === "duplicate_name_review") return "Duplicate name review";
    return status ? tagLabel(status.replace(/_/g, "-")) : "Needs review";
  }

  function isUserFacingTag(value) {
    var tag = String(value || "").trim().toLowerCase();
    if (!tag) return false;
    if (tag.indexOf("state-") === 0) return false;
    return ["location-seeded", "loop-segment-inferred", "segment-inferred"].indexOf(tag) === -1;
  }

  function visibleTags(tags) {
    var out = [];
    (Array.isArray(tags) ? tags : []).forEach(function (tag) {
      if (isUserFacingTag(tag) && out.length < 4) {
        out.push(tag);
      }
    });
    return out;
  }

  function hasTag(item, expectedTag) {
    return (item.tags || []).some(function (tag) {
      return String(tag || "").toLowerCase() === expectedTag;
    });
  }

  function normalizePort(row) {
    row = row || {};
    var id = Number(row.ID || row.id || 0);
    var lat = Number(row.LAT !== undefined ? row.LAT : row.lat);
    var lng = Number(row.LNG !== undefined ? row.LNG : row.lng);
    var tags = Array.isArray(row.TAGS) ? row.TAGS : (Array.isArray(row.tags) ? row.tags : []);
    var mapReadyValue = row.MAP_READY !== undefined ? row.MAP_READY : row.mapReady;
    var item = {
      id: id,
      name: row.NAME || row.name || "",
      state: row.STATE || row.state || "",
      stateCode: row.STATE_CODE || row.stateCode || row.state_code || "",
      country: row.COUNTRY || row.country || "",
      lat: Number.isFinite(lat) ? lat : null,
      lng: Number.isFinite(lng) ? lng : null,
      loopSegment: row.LOOP_SEGMENT || row.loopSegment || row.loop_segment || "",
      waterway: row.WATERWAY || row.waterway || "",
      slug: row.SLUG || row.slug || "",
      dataQualityStatus: row.DATA_QUALITY_STATUS || row.dataQualityStatus || row.data_quality_status || "",
      mapReady: mapReadyValue !== false,
      tags: tags,
      services: row.SERVICES || row.services || {},
      source: row
    };
    item.url = row.URL || row.url || detailUrl(item);
    item.canSave = item.mapReady && item.lat !== null && item.lng !== null && item.lat !== 0 && item.lng !== 0;
    return item;
  }

  function rememberRows(rows) {
    currentRows = (rows || []).map(normalizePort);
    portsById = {};
    currentRows.forEach(function (item) {
      if (item.id) {
        portsById[String(item.id)] = item;
      }
    });
  }

  function locationText(item) {
    return [item.state, item.stateCode, item.country].filter(Boolean).join(", ") || "Location not listed";
  }

  function routeText(item) {
    return [item.loopSegment, item.waterway].filter(Boolean).join(" - ") || "Route segment not listed";
  }

  function badgesHtml(item) {
    var html = "";
    var tags = visibleTags(item.tags);
    if (hasTag(item, "major-stop-candidate") && tags.indexOf("major-stop-candidate") === -1) {
      tags.unshift("major-stop-candidate");
    }
    tags.slice(0, 3).forEach(function (tag) {
      html += '<span class="fpw-ports-badge' + (tag === "major-stop-candidate" ? " fpw-ports-badge--accent" : "") + '">' + escapeHtml(tagLabel(tag)) + "</span>";
    });
    html += '<span class="fpw-ports-badge fpw-ports-badge--muted">' + escapeHtml(qualityLabel(item.dataQualityStatus)) + "</span>";
    return html;
  }

  function isSuppressedPopupBadge(value) {
    var normalized = String(value || "").trim().toLowerCase().replace(/_/g, "-");
    return [
      "duplicate-name-review",
      "duplicate-name-state-review",
      "major-stop-candidate",
      "needs-review"
    ].indexOf(normalized) !== -1;
  }

  function popupBadgesHtml(item) {
    var html = "";
    var status = String(item.dataQualityStatus || "").trim();
    var tags = visibleTags(item.tags).filter(function (tag) {
      return !isSuppressedPopupBadge(tag);
    });

    tags.slice(0, 3).forEach(function (tag) {
      html += '<span class="fpw-ports-badge">' + escapeHtml(tagLabel(tag)) + "</span>";
    });
    if (status && !isSuppressedPopupBadge(status)) {
      html += '<span class="fpw-ports-badge fpw-ports-badge--muted">' + escapeHtml(qualityLabel(status)) + "</span>";
    }
    return html;
  }

  function authPromptHtml() {
    return '<p class="fpw-ports-anon-only">Sign in to add this port to your custom waypoints. <a href="' + escapeHtml(loginUrl()) + '">Log in</a> or <a href="' + escapeHtml(joinUrl()) + '">join FPW</a>.</p>';
  }

  function addButtonHtml(item) {
    if (!item.canSave) {
      return '<p class="fpw-ports-add-status is-error">This port does not have map-ready coordinates yet.</p>';
    }
    return '<button type="button" class="fpw-ports-btn fpw-ports-btn--small fpw-ports-member-only" data-port-add data-port-id="' + escapeHtml(item.id) + '">' + (addedPortIds[String(item.id)] ? "Added" : "Add to My Waypoints") + "</button>";
  }

  function popupHtml(item) {
    return ""
      + '<div class="fpw-ports-popup">'
      + "<strong>" + escapeHtml(item.name) + "</strong>"
      + "<span>" + escapeHtml(locationText(item)) + "</span>"
      + (item.loopSegment ? "<span>" + escapeHtml(item.loopSegment) + "</span>" : "")
      + (item.url ? '<a href="' + escapeHtml(item.url) + '">View Details</a>' : "")
      + "</div>";
  }

  function addBaseLayer(targetMap) {
    var baseLayer = window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(targetMap);

    if (window.FPW && typeof window.FPW.attachLeafletMarineLayers === "function") {
      window.FPW.attachLeafletMarineLayers({
        map: targetMap,
        baseLayer: baseLayer,
        includeRadar: false
      });
    }
  }

  function renderMarkers(rows) {
    var markerRows = (rows || currentRows).filter(function (item) {
      return item.mapReady && Number.isFinite(item.lat) && Number.isFinite(item.lng) && item.lat !== 0 && item.lng !== 0;
    });
    var bounds = null;

    if (!map || !markerLayer) return;
    markerLayer.clearLayers();
    markerById = {};

    if (!markerRows.length) {
      map.setView([38.5, -84], 5);
      if (emptyMapEl) emptyMapEl.hidden = (rows || currentRows).length !== 0;
      return;
    }

    if (emptyMapEl) emptyMapEl.hidden = true;
    bounds = window.L.latLngBounds([]);
    markerRows.forEach(function (item) {
      var point = [item.lat, item.lng];
      var marker = window.L.marker(point).addTo(markerLayer).bindPopup(popupHtml(item));
      bounds.extend(point);
      markerById[String(item.id)] = marker;
    });

    if (markerRows.length === 1) {
      map.setView([markerRows[0].lat, markerRows[0].lng], 12);
    } else if (bounds.isValid()) {
      map.fitBounds(bounds.pad(0.16), { maxZoom: 9 });
    }
  }

  function renderSummary(rows) {
    var list = rows || currentRows;
    var markers = list.filter(function (item) {
      return item.mapReady && Number.isFinite(item.lat) && Number.isFinite(item.lng) && item.lat !== 0 && item.lng !== 0;
    }).length;
    if (summaryEl) {
      summaryEl.textContent = list.length + " port" + (list.length === 1 ? "" : "s") + " match, with " + markers + " map marker" + (markers === 1 ? "" : "s") + ".";
    }
    if (totalCountEl) {
      totalCountEl.textContent = markers;
    }
  }

  function renderList(rows) {
    var html = "";
    var list = rows || currentRows;
    if (!resultListEl || !emptyListEl) return;

    list.forEach(function (item) {
      html += '<article class="fpw-ports-result-card" data-port-card data-port-id="' + escapeHtml(item.id) + '">'
        + "<div>"
        + '<h3><a href="' + escapeHtml(item.url) + '">' + escapeHtml(item.name) + "</a></h3>"
        + "<p>" + escapeHtml(locationText(item)) + "</p>"
        + "<p>" + escapeHtml(routeText(item)) + "</p>"
        + '<div class="fpw-ports-badges">' + badgesHtml(item) + "</div>"
        + "</div>"
        + '<div class="fpw-ports-card-actions">'
        + '<a class="fpw-ports-btn fpw-ports-btn--small" href="' + escapeHtml(item.url) + '">View Details</a>'
        + addButtonHtml(item)
        + authPromptHtml()
        + '<p class="fpw-ports-add-status" data-port-add-status="' + escapeHtml(item.id) + '" aria-live="polite"></p>'
        + "</div>"
        + "</article>";
    });

    resultListEl.innerHTML = html;
    resultListEl.hidden = list.length === 0;
    emptyListEl.hidden = list.length !== 0;
    syncAddedButtons();
  }

  function setView(viewName) {
    viewButtons.forEach(function (button) {
      var active = button.getAttribute("data-ports-view-button") === viewName;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", active ? "true" : "false");
    });
    viewPanels.forEach(function (panel) {
      panel.hidden = panel.getAttribute("data-ports-view-panel") !== viewName;
    });
    if (viewName === "map" && map) {
      window.setTimeout(function () { map.invalidateSize(); }, 0);
    }
  }

  function initMap() {
    if (!mapEl || !window.L) return;
    map = window.L.map(mapEl, { zoomControl: true, attributionControl: true });
    addBaseLayer(map);
    markerLayer = window.L.layerGroup().addTo(map);
    renderMarkers(currentRows);
  }

  function initDetailMap() {
    if (!detailMapEl || !window.L) return;
    var lat = Number(detailMapEl.getAttribute("data-lat"));
    var lng = Number(detailMapEl.getAttribute("data-lng"));
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    var detailData = normalizePort(parseJsonElement(detailDataEl, {}));
    if (!detailData.id) {
      detailData = normalizePort({
        ID: detailMapEl.getAttribute("data-port-id") || 0,
        NAME: detailMapEl.getAttribute("data-name") || "Port location",
        LAT: lat,
        LNG: lng,
        LOOP_SEGMENT: detailMapEl.getAttribute("data-loop-segment") || "",
        WATERWAY: detailMapEl.getAttribute("data-waterway") || "",
        URL: detailMapEl.getAttribute("data-url") || window.location.pathname
      });
    }
    detailMap = window.L.map(detailMapEl, { zoomControl: true, attributionControl: true }).setView([lat, lng], 13);
    addBaseLayer(detailMap);
    detailMarker = window.L.marker([lat, lng]).addTo(detailMap).bindPopup(popupHtml(detailData));
    portsById[String(detailData.id)] = detailData;
    window.setTimeout(function () { detailMap.invalidateSize(); }, 100);
  }

  function refreshDetailPopup() {
    if (!detailMarker || !detailDataEl) return;
    var detailData = normalizePort(parseJsonElement(detailDataEl, {}));
    if (detailData.id) {
      detailMarker.bindPopup(popupHtml(detailData));
    }
  }

  function valueOf(selector) {
    var el = formEl ? formEl.querySelector(selector) : null;
    return el ? String(el.value || "").trim() : "";
  }

  function checked(selector) {
    var el = formEl ? formEl.querySelector(selector) : null;
    return !!(el && el.checked);
  }

  function collectFilters() {
    var tag = checked("[name='majorStop']") ? "major-stop-candidate" : valueOf("[name='tag']");
    return {
      q: valueOf("[name='q']"),
      stateCode: valueOf("[name='stateCode']"),
      loopSegment: valueOf("[name='loopSegment']"),
      tag: tag,
      majorStop: checked("[name='majorStop']") ? "1" : ""
    };
  }

  function appendFilters(params, filters) {
    params.set("mapReady", "1");
    ["q", "stateCode", "loopSegment", "tag"].forEach(function (key) {
      if (filters && filters[key]) params.set(key, filters[key]);
      else params.delete(key);
    });
  }

  function apiUrl(action, filters) {
    var endpoint = getConfig("data-ports-api-endpoint", (window.FPW_API_BASE || "/api/v1") + "/ports.cfc?method=handle&returnFormat=json");
    var url = new URL(endpoint, window.location.origin);
    url.searchParams.set("action", action);
    if (action === "list") {
      appendFilters(url.searchParams, filters || {});
    }
    return url.toString();
  }

  function pageUrl(filters) {
    var pagePath = getConfig("data-ports-page-url", window.location.pathname);
    var url = new URL(pagePath || window.location.pathname, window.location.origin);
    appendFilters(url.searchParams, filters || {});
    if (filters && filters.majorStop) url.searchParams.set("majorStop", filters.majorStop);
    else url.searchParams.delete("majorStop");
    if (filters && filters.majorStop) url.searchParams.delete("tag");
    return url.pathname + url.search;
  }

  function fetchJson(action, filters) {
    return fetch(apiUrl(action, filters), {
      method: "GET",
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    }).then(function (response) {
      if (!response.ok) throw new Error("Ports API request failed.");
      return response.json();
    }).then(function (data) {
      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw new Error((data && (data.MESSAGE || data.message)) ? (data.MESSAGE || data.message) : "Ports API response failed.");
      }
      return data;
    });
  }

  function apiRequest(path, options) {
    options = options || {};
    if (!window.fetch || !window.Promise) {
      return Promise.reject({ MESSAGE: "Ports API is unavailable." });
    }

    var headers = options.headers || {};
    headers["Accept"] = "application/json";
    headers["Content-Type"] = "application/json";

    return fetch(new URL(apiBasePath() + path, window.location.origin).toString(), {
      method: options.method || "GET",
      credentials: "same-origin",
      headers: headers,
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined
    }).then(function (response) {
      return response.text().then(function (text) {
        var data = {};
        try {
          data = text ? JSON.parse(text) : {};
        } catch (err) {
          data = { SUCCESS: false, MESSAGE: "Non-JSON response from API", RAW: text };
        }
        if (!response.ok || data.SUCCESS === false) {
          data.status = response.status;
          throw data;
        }
        return data;
      });
    });
  }

  function getCurrentUser() {
    if (window.Api && typeof window.Api.getCurrentUser === "function") {
      return window.Api.getCurrentUser();
    }
    return apiRequest("/me.cfc?method=handle&returnFormat=json", { method: "GET" });
  }

  function saveWaypoint(payload) {
    if (window.Api && typeof window.Api.saveWaypoint === "function") {
      return window.Api.saveWaypoint(payload);
    }
    payload = payload || {};
    payload.action = "save";
    return apiRequest("/waypoint.cfc?method=handle&returnFormat=json", {
      method: "POST",
      body: payload
    });
  }

  function setStatus(message, isError) {
    if (!statusEl) return;
    statusEl.textContent = message || "";
    statusEl.hidden = !message;
    statusEl.classList.toggle("is-error", !!isError);
  }

  function applyFilters(updateHistory) {
    var filters = collectFilters();
    setStatus("Updating port results...", false);
    return fetchJson("list", filters).then(function (data) {
      rememberRows(data.PORTS || data.ports || []);
      renderMarkers(currentRows);
      renderList(currentRows);
      renderSummary(currentRows);
      if (updateHistory !== false && window.history && window.history.replaceState) {
        window.history.replaceState({}, "", pageUrl(filters));
      }
      setStatus("", false);
    }).catch(function () {
      setStatus("Unable to update port filters. Please try again.", true);
    });
  }

  function loadFilterOptions() {
    if (!formEl) return;
    fetchJson("filters", {}).then(function () {
      formEl.setAttribute("data-ports-filters-loaded", "true");
    }).catch(function () {
      formEl.setAttribute("data-ports-filters-loaded", "false");
    });
  }

  function clearFilters(event) {
    if (event) event.preventDefault();
    if (!formEl) return;
    Array.prototype.slice.call(formEl.querySelectorAll("input, select")).forEach(function (control) {
      if (control.type === "checkbox") control.checked = false;
      else control.value = "";
    });
    applyFilters(true);
  }

  function clearSiblingDropdownFilters(activeSelect) {
    if (!formEl || !activeSelect || !activeSelect.value) return;
    ["stateCode", "loopSegment", "tag"].forEach(function (name) {
      var selectEl = formEl.querySelector("[name='" + name + "']");
      if (selectEl && selectEl !== activeSelect) {
        selectEl.value = "";
      }
    });
    var majorStop = formEl.querySelector("[name='majorStop']");
    if (majorStop) {
      majorStop.checked = false;
    }
  }

  function focusCardMarker(card) {
    var id = card ? card.getAttribute("data-port-id") : "";
    var marker = id ? markerById[String(id)] : null;
    if (!map || !marker) return;
    setView("map");
    map.setView(marker.getLatLng(), Math.max(map.getZoom(), 11));
    marker.openPopup();
  }

  function setAuthClasses(loggedIn) {
    if (!document.body) return;
    document.body.classList.toggle("is-ports-logged-in", !!loggedIn);
    document.body.classList.toggle("is-ports-anonymous", !loggedIn);
  }

  function updateAuthState() {
    return getCurrentUser().then(function (data) {
      authState.checked = true;
      authState.loggedIn = !!(data && (data.AUTH === true || data.auth === true));
      setAuthClasses(authState.loggedIn);
      renderMarkers(currentRows);
      refreshDetailPopup();
      return authState;
    }).catch(function () {
      authState.checked = true;
      authState.loggedIn = false;
      setAuthClasses(false);
      return authState;
    });
  }

  function waypointName(item) {
    var name = String(item.name || "Great Loop Port").trim();
    return name.length > 45 ? name.slice(0, 45) : name;
  }

  function savePortToWaypoints(item) {
    if (!authState.loggedIn) {
      return Promise.reject({ MESSAGE: "Sign in to add this port to your custom waypoints." });
    }
    if (!item || !item.canSave) {
      return Promise.reject({ MESSAGE: "This port does not have map-ready coordinates yet." });
    }
    return saveWaypoint({
      waypoint: {
        WAYPOINTID: 0,
        WAYPOINTNAME: waypointName(item),
        LATITUDE: String(item.lat),
        LONGITUDE: String(item.lng),
        NOTES: "Added from Great Loop Ports Library: " + item.name
      }
    });
  }

  function cssEscape(value) {
    if (window.CSS && typeof window.CSS.escape === "function") {
      return window.CSS.escape(String(value));
    }
    return String(value).replace(/["\\]/g, "\\$&");
  }

  function statusTargets(portId) {
    return Array.prototype.slice.call(document.querySelectorAll("[data-port-add-status='" + cssEscape(portId) + "']"));
  }

  function buttonTargets(portId) {
    return Array.prototype.slice.call(document.querySelectorAll("[data-port-add][data-port-id='" + cssEscape(portId) + "']"));
  }

  function setPortStatus(portId, message, isError) {
    statusTargets(portId).forEach(function (target) {
      target.textContent = message || "";
      target.classList.toggle("is-error", !!isError);
    });
  }

  function syncAddedButtons() {
    Object.keys(addedPortIds).forEach(function (portId) {
      buttonTargets(portId).forEach(function (button) {
        button.disabled = true;
        button.textContent = "Added";
      });
    });
  }

  function handleAddClick(event) {
    var button = event.target.closest("[data-port-add]");
    var portId = button ? button.getAttribute("data-port-id") : "";
    var item = portId ? portsById[String(portId)] : null;
    if (!button || !portId) return;

    event.preventDefault();
    if (addedPortIds[String(portId)]) return;

    if (!item) {
      item = normalizePort(parseJsonElement(detailDataEl, {}));
      if (item && item.id) portsById[String(item.id)] = item;
    }

    button.disabled = true;
    button.textContent = "Adding...";
    setPortStatus(portId, "", false);

    savePortToWaypoints(item).then(function (data) {
      if (!data || data.SUCCESS !== true) {
        throw data || {};
      }
      addedPortIds[String(portId)] = true;
      buttonTargets(portId).forEach(function (target) {
        target.disabled = true;
        target.textContent = "Added";
      });
      setPortStatus(portId, "Added to your custom waypoints.", false);
    }).catch(function (err) {
      button.disabled = false;
      button.textContent = "Add to My Waypoints";
      setPortStatus(portId, (err && (err.MESSAGE || err.message)) ? (err.MESSAGE || err.message) : "Unable to add this port.", true);
    });
  }

  function initPortImageModal() {
    var openButton = document.querySelector("[data-port-image-open]");
    var modal = document.querySelector("[data-port-image-modal]");
    if (!openButton || !modal) {
      return;
    }

    var closeButtons = Array.prototype.slice.call(modal.querySelectorAll("[data-port-image-close]"));
    var closeButton = modal.querySelector(".fpw-ports-image-modal__close");
    var lastActiveElement = null;

    function setModalOpen(isOpen) {
      modal.hidden = !isOpen;
      document.body.classList.toggle("is-ports-image-modal-open", isOpen);
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

  rememberRows(parseJsonElement(dataEl, []));
  renderSummary(currentRows);

  if (detailDataEl) {
    var detailPort = normalizePort(parseJsonElement(detailDataEl, {}));
    if (detailPort.id) portsById[String(detailPort.id)] = detailPort;
  }

  viewButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      setView(button.getAttribute("data-ports-view-button") || "map");
    });
  });

  if (resultListEl) {
    resultListEl.addEventListener("click", function (event) {
      var card = event.target.closest("[data-port-card]");
      if (!card || event.target.closest("a") || event.target.closest("button")) return;
      focusCardMarker(card);
    });
  }

  document.addEventListener("click", handleAddClick);

  initMap();
  initDetailMap();
  initPortImageModal();
  updateAuthState();

  if (formEl && window.fetch && window.Promise) {
    loadFilterOptions();
    formEl.addEventListener("submit", function (event) {
      event.preventDefault();
      applyFilters(true);
    });
    Array.prototype.slice.call(formEl.querySelectorAll("select")).forEach(function (selectEl) {
      selectEl.addEventListener("change", function () {
        clearSiblingDropdownFilters(selectEl);
        applyFilters(true);
      });
    });
    var majorStop = formEl.querySelector("[name='majorStop']");
    if (majorStop) {
      majorStop.addEventListener("change", function () {
        var tagInput = formEl.querySelector("[name='tag']");
        if (tagInput) tagInput.value = "";
        applyFilters(true);
      });
    }
    var clearLink = formEl.querySelector("[data-ports-clear]");
    if (clearLink) clearLink.addEventListener("click", clearFilters);
    applyFilters(false);
  }
})(window, document);










