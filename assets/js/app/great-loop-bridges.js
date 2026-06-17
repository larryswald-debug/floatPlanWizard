(function (window, document) {
  "use strict";

  var formEl = document.querySelector("[data-bridge-filter-form]");
  var resultShellEl = document.querySelector("[data-bridge-results-shell]");
  var resultListEl = document.querySelector("[data-bridge-result-list]");
  var emptyListEl = document.querySelector("[data-bridge-empty-list]");
  var summaryEl = document.querySelector("[data-bridge-result-summary]");
  var statusEl = document.querySelector("[data-bridge-filter-status]");
  var mapEl = document.getElementById("fpwBridgeMap");
  var detailMapEl = document.getElementById("fpwBridgeDetailMap");
  var emptyMapEl = document.querySelector("[data-bridge-empty-map]");
  var map = null;
  var markers = [];

  function escapeHtml(value) {
    return String(value === null || value === undefined ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function getControl(selector) {
    return formEl ? formEl.querySelector(selector) : null;
  }

  function collectFilters() {
    return {
      q: valueOf("[name='q']"),
      routeSegment: valueOf("[name='routeSegment']"),
      routeVariant: valueOf("[name='routeVariant']"),
      waterway: valueOf("[name='waterway']"),
      stateProvince: valueOf("[name='stateProvince']"),
      bridgeType: valueOf("[name='bridgeType']"),
      verificationStatus: valueOf("[name='verificationStatus']"),
      publicStatus: valueOf("[name='publicStatus']"),
      drawbridgeOnly: checkedValue("[name='drawbridgeOnly']"),
      airDraftConcern: checkedValue("[name='airDraftConcern']"),
      hasContact: checkedValue("[name='hasContact']"),
      hasCoordinates: checkedValue("[name='hasCoordinates']")
    };
  }

  function valueOf(selector) {
    var el = getControl(selector);
    return el ? (el.value || "").trim() : "";
  }

  function checkedValue(selector) {
    var el = getControl(selector);
    return el && el.checked ? "1" : "";
  }

  function resetOtherDropdownFilters(sourceControl) {
    if (!formEl || !sourceControl || sourceControl.tagName !== "SELECT") return;
    Array.prototype.slice.call(formEl.querySelectorAll("select")).forEach(function (selectEl) {
      if (selectEl !== sourceControl) {
        selectEl.value = "";
      }
    });
    Array.prototype.slice.call(formEl.querySelectorAll("input[type='checkbox']")).forEach(function (checkboxEl) {
      checkboxEl.checked = false;
    });
  }

  function appendFilters(params, filters) {
    Object.keys(filters || {}).forEach(function (key) {
      if (filters[key]) {
        params.set(key, filters[key]);
      } else {
        params.delete(key);
      }
    });
  }

  function apiUrl(action, filters) {
    var endpoint = formEl ? formEl.getAttribute("data-bridge-api-endpoint") : "";
    var url = new URL(endpoint, window.location.origin);
    url.searchParams.set("action", action);
    appendFilters(url.searchParams, filters || {});
    return url.toString();
  }

  function pageUrl(filters) {
    var pagePath = formEl ? formEl.getAttribute("data-bridge-page-url") : window.location.pathname;
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
      if (!response.ok) throw new Error("Bridge API request failed.");
      return response.json();
    }).then(function (data) {
      if (!data || data.success !== true) {
        throw new Error(data && data.message ? data.message : "Bridge API response failed.");
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

  function initMap() {
    var dataNode = document.getElementById("fpwBridgeMapData");
    var initialRows = [];
    if (!mapEl || !window.L) return;
    try {
      initialRows = dataNode ? JSON.parse(dataNode.textContent || "[]") : [];
    } catch (err) {
      initialRows = [];
    }
    map = window.L.map(mapEl, { scrollWheelZoom: false });
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 18,
      attribution: "&copy; OpenStreetMap"
    }).addTo(map);
    renderMarkers(initialRows);
  }

  function initDetailMap() {
    if (!detailMapEl || !window.L) return;
    var lat = parseFloat(detailMapEl.getAttribute("data-lat"));
    var lng = parseFloat(detailMapEl.getAttribute("data-lng"));
    var name = detailMapEl.getAttribute("data-name") || "Bridge location";
    if (isNaN(lat) || isNaN(lng)) return;
    var detailMap = window.L.map(detailMapEl, { scrollWheelZoom: false }).setView([lat, lng], 13);
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 18,
      attribution: "&copy; OpenStreetMap"
    }).addTo(detailMap);
    window.L.marker([lat, lng]).addTo(detailMap).bindPopup(escapeHtml(name));
  }

  function renderMarkers(rows) {
    var bounds = [];
    if (!map) return;
    markers.forEach(function (marker) { map.removeLayer(marker); });
    markers = [];
    (rows || []).forEach(function (bridge) {
      var lat = parseFloat(bridge.latitude || bridge.lat);
      var lng = parseFloat(bridge.longitude || bridge.lng);
      var marker = null;
      if (isNaN(lat) || isNaN(lng)) return;
      marker = window.L.marker([lat, lng]).addTo(map);
      marker.bindPopup('<strong>' + escapeHtml(bridge.bridge_name || bridge.name) + '</strong><br><a href="' + escapeHtml(bridge.url || "#") + '">View bridge</a>');
      markers.push(marker);
      bounds.push([lat, lng]);
    });
    if (bounds.length) {
      map.fitBounds(bounds, { padding: [28, 28], maxZoom: 10 });
    } else {
      map.setView([38, -84], 5);
    }
  }

  function renderSummary(summary) {
    if (!summaryEl) return;
    var total = Number(summary && summary.total ? summary.total : 0);
    var markers = Number(summary && summary.markers ? summary.markers : 0);
    summaryEl.textContent = total + " bridge planning record" + (total === 1 ? "" : "s") + " match, with " + markers + " map marker" + (markers === 1 ? "" : "s") + ".";
  }

  function renderEmptyMapState(summary, rows) {
    var total = Number(summary && summary.total ? summary.total : 0);
    if (!total && rows && rows.length) {
      total = rows.length;
    }
    if (emptyMapEl) {
      emptyMapEl.hidden = total !== 0;
    }
  }

  function renderList(bridges) {
    var html = "";
    if (!resultListEl || !emptyListEl) return;
    if (resultShellEl) resultShellEl.hidden = false;
    (bridges || []).forEach(function (bridge) {
      var image = bridge.image || {};
      var location = [bridge.nearest_city, bridge.state_province].filter(Boolean).join(", ");
      var clearance = bridge.vertical_clearance_closed_ft ? bridge.vertical_clearance_closed_ft + " ft closed" : "Clearance not verified";
      html += '<article class="fpw-bridge-card">'
        + '<img src="' + escapeHtml(image.url || "") + '" alt="" loading="lazy" decoding="async">'
        + '<div>'
        + '<h3><a href="' + escapeHtml(bridge.url || "#") + '">' + escapeHtml(bridge.bridge_name || "") + '</a></h3>'
        + '<p>' + escapeHtml([bridge.waterway, bridge.route_segment].filter(Boolean).join(" - ")) + '</p>'
        + '<p>' + escapeHtml(location || "Location not verified") + (bridge.mile_marker ? " - MM " + escapeHtml(bridge.mile_marker) : "") + '</p>'
        + '<p>' + escapeHtml(bridge.bridge_type || "Bridge type not verified") + ' - ' + escapeHtml(clearance) + '</p>'
        + '<div class="fpw-bridge-badges">'
        + '<span class="fpw-bridge-badge">' + escapeHtml(bridge.public_status || "planning_only") + '</span>'
        + (bridge.is_drawbridge === 1 || bridge.is_drawbridge === "1" ? '<span class="fpw-bridge-badge fpw-bridge-badge--warn">Drawbridge</span>' : "")
        + (bridge.air_draft_concern ? '<span class="fpw-bridge-badge fpw-bridge-badge--warn">Air draft concern</span>' : "")
        + '</div>'
        + '</div>'
        + '</article>';
    });
    resultListEl.innerHTML = html;
    resultListEl.hidden = !bridges.length;
    emptyListEl.hidden = !!bridges.length;
  }

  function applyFilters() {
    var filters = collectFilters();
    setStatus("Updating bridge results...", false);
    return fetchJson("bridges", filters).then(function (data) {
      renderMarkers(data.bridges || []);
      renderList(data.bridges || []);
      renderSummary(data.summary || {});
      renderEmptyMapState(data.summary || {}, data.bridges || []);
      if (window.history && window.history.replaceState) {
        window.history.replaceState({}, "", pageUrl(filters));
      }
      setStatus("", false);
    }).catch(function (err) {
      if (window.console && window.console.error) window.console.error("FPW bridge filter update failed", err);
      setStatus("Unable to update bridge filters. Please try again.", true);
    });
  }

  initMap();
  initDetailMap();

  if (!formEl || !window.fetch || !window.Promise) return;

  formEl.addEventListener("submit", function (event) {
    event.preventDefault();
    applyFilters();
  });

  Array.prototype.slice.call(formEl.querySelectorAll("select,input[type='checkbox']")).forEach(function (control) {
    control.addEventListener("change", function () {
      resetOtherDropdownFilters(control);
      applyFilters();
    });
  });
})(window, document);
