(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var waypointState = state.waypointState || { all: [] };

  var waypointModalEl = null;
  var waypointModal = null;
  var waypointFormEl = null;
  var waypointModalTitleEl = null;
  var waypointIdInput = null;
  var waypointNameInput = null;
  var waypointLatitudeInput = null;
  var waypointLongitudeInput = null;
  var waypointNotesInput = null;
  var waypointSaveBtn = null;
  var waypointNameError = null;
  var waypointMapEl = null;
  var waypointMapController = null;
  var waypointNameManual = false;
  var suppressWaypointNameInput = false;
  // INSERT START (waypoint naming helpers)
  var waypointNameCache = new Map();
  var waypointOriginalLatLng = null;
  var waypointNameResolveId = 0;
  // INSERT END
  var marineTideToggle = null;
  var marineTypeMarina = null;
  var marineTypeFuel = null;
  var marineTypeRamp = null;
  var marineStatusLine = null;
  var placeMarkers = [];
  var marineIdleTimer = null;
  var marinePlacesRequestId = 0;
  var marinePlaceDetailsRequestId = 0;
  var lastPlacesPois = [];
  var lastPlacesTypes = [];
  var lastPlacesCenter = null;
  var lastPlacesRadius = null;
  var pendingMarineReload = false;

  function setWaypointsSummary(text) {
    var el = document.getElementById("waypointsSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setWaypointsMessage(text, isError) {
    var messageEl = document.getElementById("waypointsMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function updateWaypointsSummary(waypoints) {
    if (!waypoints || !waypoints.length) {
      setWaypointsSummary("No waypoints yet");
      return;
    }

    setWaypointsSummary(waypoints.length + " total");
  }

  function renderWaypointsList(waypoints) {
    var listEl = document.getElementById("waypointsList");
    if (!listEl) return;

    if (!waypoints || !waypoints.length) {
      listEl.innerHTML = "";
      setWaypointsMessage("You don’t have any waypoints yet.", false);
      return;
    }

    setWaypointsMessage("", false);

    var rows = waypoints.map(function (waypoint) {
      var waypointId = utils.pick(waypoint, ["WAYPOINTID", "ID"], "");
      var name = utils.pick(waypoint, ["WAYPOINTNAME", "NAME"], "");
      var notes = utils.pick(waypoint, ["NOTES"], "");
      var nameText = name || "Unnamed waypoint";
      var metaText = notes ? "Notes: " + notes : "Notes: N/A";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + utils.escapeHtml(nameText) + "</div>" +
            "<small>" + utils.escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="waypoint-edit-' + utils.escapeHtml(waypointId) + '" data-action="edit" data-waypoint-id="' + utils.escapeHtml(waypointId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="waypoint-delete-' + utils.escapeHtml(waypointId) + '" data-action="delete" data-waypoint-id="' + utils.escapeHtml(waypointId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function loadWaypoints(limit) {
    limit = limit || 100;
    setWaypointsSummary("Loading…");
    setWaypointsMessage("Loading waypoints…", false);

    var listEl = document.getElementById("waypointsList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getWaypoints !== "function") {
      setWaypointsMessage("Waypoints API is unavailable.", true);
      setWaypointsSummary("Unavailable");
      return;
    }

    Api.getWaypoints({ limit: limit })
      .then(function (data) {
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var waypoints = data.WAYPOINTS || data.waypoints || [];
        waypoints = waypoints.slice().sort(function (a, b) {
          var aName = utils.pick(a, ["WAYPOINTNAME", "NAME"], "").toLowerCase();
          var bName = utils.pick(b, ["WAYPOINTNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        waypointState.all = waypoints;
        updateWaypointsSummary(waypoints);
        renderWaypointsList(waypoints);
      })
      .catch(function (err) {
        console.error("Failed to load waypoints:", err);
        setWaypointsMessage("Unable to load waypoints right now.", true);
        setWaypointsSummary("Error");
        utils.showDashboardAlert("Unable to load waypoints. Please try again later.", "danger");
      });
  }

  function ensureWaypointModal() {
    if (!waypointModalEl) {
      waypointModalEl = document.getElementById("waypointModal");
      if (waypointModalEl) {
        waypointFormEl = waypointModalEl.querySelector("#waypointForm");
        waypointModalTitleEl = waypointModalEl.querySelector("#waypointModalLabel");
        waypointIdInput = waypointModalEl.querySelector("#waypointId");
        waypointNameInput = waypointModalEl.querySelector("#waypointName");
        waypointLatitudeInput = waypointModalEl.querySelector("#waypointLatitude");
        waypointLongitudeInput = waypointModalEl.querySelector("#waypointLongitude");
        waypointNotesInput = waypointModalEl.querySelector("#waypointNotes");
        waypointSaveBtn = waypointModalEl.querySelector("#saveWaypointBtn");
        waypointNameError = waypointModalEl.querySelector("#waypointNameError");
        waypointMapEl = waypointModalEl.querySelector("#waypointMap");
        marineTideToggle = waypointModalEl.querySelector("#marineTideToggle");
        marineTypeMarina = waypointModalEl.querySelector("#marineTypeMarina");
        marineTypeFuel = waypointModalEl.querySelector("#marineTypeFuel");
        marineTypeRamp = waypointModalEl.querySelector("#marineTypeRamp");
      }
    }

    if (waypointModalEl && !waypointModal && window.bootstrap && window.bootstrap.Modal) {
      waypointModal = new window.bootstrap.Modal(waypointModalEl);
    }

    if (!waypointMapController && waypointModalEl && waypointMapEl && window.FPW && typeof window.FPW.initLeafletWaypointMap === "function") {
      waypointMapController = window.FPW.initLeafletWaypointMap({
        modalEl: waypointModalEl,
        mapEl: waypointMapEl,
        onMapClick: function (lat, lng) {
          setWaypointLocation(lat, lng, { updateName: true, reason: "click" });
        },
        onMarkerDragEnd: function (lat, lng) {
          setWaypointLocation(lat, lng, { updateName: true, reason: "drag" });
        },
        onMoveEnd: function () {
          debounceMapIdleReload(false);
        },
        onMapReady: function () {
          if (pendingMarineReload) {
            pendingMarineReload = false;
            debounceMapIdleReload(true);
          }
        },
        onMapDestroy: function () {
          clearPlacesPOIs();
        }
      });
    }

    if (waypointModalEl && !waypointModalEl.dataset.listenersAttached) {
      if (waypointFormEl) {
        waypointFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (waypointNameInput) {
        waypointNameInput.addEventListener("input", function () {
          if (!suppressWaypointNameInput) {
            waypointNameManual = true;
          }
          utils.clearFieldError(waypointNameInput, waypointNameError);
        });
      }
      if (waypointSaveBtn) {
        waypointSaveBtn.addEventListener("click", function () {
          saveWaypoint();
        });
      }
      waypointModalEl.dataset.listenersAttached = "true";
    }
  }

  function clearWaypointValidation() {
    utils.clearFieldError(waypointNameInput, waypointNameError);
  }

  function resetWaypointForm() {
    if (waypointFormEl && waypointFormEl.reset) {
      waypointFormEl.reset();
    }
    if (waypointIdInput) waypointIdInput.value = "0";
    clearWaypointValidation();
    waypointNameManual = false;
    waypointNameResolveId = 0;
    waypointOriginalLatLng = null;
  }

  function populateWaypointForm(waypoint) {
    if (!waypoint) {
      resetWaypointForm();
      return;
    }
    if (waypointIdInput) waypointIdInput.value = utils.pick(waypoint, ["WAYPOINTID", "ID"], 0);
    if (waypointNameInput) {
      suppressWaypointNameInput = true;
      waypointNameInput.value = utils.pick(waypoint, ["WAYPOINTNAME", "NAME"], "");
      suppressWaypointNameInput = false;
    }
    if (waypointLatitudeInput) waypointLatitudeInput.value = utils.pick(waypoint, ["LATITUDE"], "");
    if (waypointLongitudeInput) waypointLongitudeInput.value = utils.pick(waypoint, ["LONGITUDE"], "");
    if (waypointNotesInput) waypointNotesInput.value = utils.pick(waypoint, ["NOTES"], "");
    clearWaypointValidation();
    waypointNameManual = false;
    waypointNameResolveId = 0;
    var lat = parseFloat(utils.pick(waypoint, ["LATITUDE"], ""));
    var lng = parseFloat(utils.pick(waypoint, ["LONGITUDE"], ""));
    if (!isNaN(lat) && !isNaN(lng)) {
      waypointOriginalLatLng = { lat: lat, lng: lng };
    } else {
      waypointOriginalLatLng = null;
    }
  }

  function openWaypointModal(waypoint) {
    ensureWaypointModal();
    if (!waypointModalEl || !waypointModal) {
      return;
    }
    var waypointId = waypoint ? utils.pick(waypoint, ["WAYPOINTID", "ID"], 0) : 0;
    if (waypointModalTitleEl) {
      waypointModalTitleEl.textContent = waypointId ? "Edit Waypoint" : "Add Waypoint";
    }
    populateWaypointForm(waypoint);
    waypointModal.show();
  }

  function updateWaypointLatLngInputs(lat, lng) {
    if (waypointLatitudeInput) waypointLatitudeInput.value = lat.toFixed(6);
    if (waypointLongitudeInput) waypointLongitudeInput.value = lng.toFixed(6);
  }

  // INSERT START (waypoint naming)
  function waypointCacheKey(lat, lng) {
    return lat.toFixed(5) + "," + lng.toFixed(5);
  }

  function formatWaypointName(lat, lng) {
    return "Waypoint " + lat.toFixed(5) + ", " + lng.toFixed(5);
  }

  function setWaypointNameValue(value) {
    if (!waypointNameInput) return;
    suppressWaypointNameInput = true;
    waypointNameInput.value = value || "";
    suppressWaypointNameInput = false;
  }

  function setResolvingWaypointName() {
    if (waypointNameManual) return;
    setWaypointNameValue("Resolving...");
  }

  function shouldResolveNameForMove(lat, lng) {
    if (!waypointOriginalLatLng) return true;
    return haversineMeters(
      waypointOriginalLatLng.lat,
      waypointOriginalLatLng.lng,
      lat,
      lng
    ) > 50;
  }

  function resolveWaypointName(lat, lng) {
    var key = waypointCacheKey(lat, lng);
    if (waypointNameCache.has(key)) {
      return Promise.resolve(waypointNameCache.get(key));
    }
    return getMarineFeatureName(lat, lng)
      .then(function (marineName) {
        if (marineName) return marineName;
        return reverseGeocodeName(lat, lng);
      })
      .then(function (resolved) {
        var finalName = resolved || formatWaypointName(lat, lng);
        waypointNameCache.set(key, finalName);
        return finalName;
      })
      .catch(function () {
        var fallback = formatWaypointName(lat, lng);
        waypointNameCache.set(key, fallback);
        return fallback;
      });
  }

  function getMarineFeatureName(lat, lng) {
    var url = "/fpw/api/v1/marineName.cfc?method=lookup&lat=" + encodeURIComponent(lat) +
      "&lng=" + encodeURIComponent(lng);
    return fetch(url, { credentials: "same-origin" })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data && (data.success || data.SUCCESS)) {
          return data.name || data.NAME || "";
        }
        return "";
      })
      .catch(function () { return ""; });
  }

  function reverseGeocodeName(lat, lng) {
    if (!window.google || !window.google.maps || !window.google.maps.Geocoder) {
      return Promise.resolve("");
    }
    var geocoder = new window.google.maps.Geocoder();
    return new Promise(function (resolve) {
      geocoder.geocode({ location: { lat: lat, lng: lng } }, function (results, status) {
        if (status !== "OK" || !results || !results.length) {
          resolve("");
          return;
        }
        var name = pickBestGeocodeName(results);
        resolve(name || "");
      });
    });
  }

  function pickBestGeocodeName(results) {
    var preferredTypes = [
      "natural_feature",
      "point_of_interest",
      "establishment",
      "locality",
      "sublocality",
      "sublocality_level_1"
    ];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      if (!result || !result.types) continue;
      for (var t = 0; t < preferredTypes.length; t++) {
        if (result.types.indexOf(preferredTypes[t]) !== -1) {
          var picked = pickComponentName(result, preferredTypes);
          return cleanGeocodeName(picked || result.formatted_address || "");
        }
      }
    }
    return cleanGeocodeName(results[0].formatted_address || "");
  }

  function pickComponentName(result, preferredTypes) {
    if (!result || !result.address_components) return "";
    for (var i = 0; i < preferredTypes.length; i++) {
      for (var j = 0; j < result.address_components.length; j++) {
        var component = result.address_components[j];
        if (component.types && component.types.indexOf(preferredTypes[i]) !== -1) {
          return component.long_name || component.short_name || "";
        }
      }
    }
    return "";
  }

  function cleanGeocodeName(value) {
    if (!value) return "";
    var cleaned = value.replace(/,\\s*USA$/i, "");
    cleaned = cleaned.replace(/\\s+\\d{5}(-\\d{4})?$/i, "");
    return cleaned.trim();
  }

  function haversineMeters(lat1, lng1, lat2, lng2) {
    var rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad;
    var dLng = (lng2 - lng1) * rad;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return 6371000 * c;
  }
  // INSERT END

  function setWaypointLocation(lat, lng, options) {
    var settings = options || {};
    setWaypointMarker(lat, lng);
    updateWaypointLatLngInputs(lat, lng);
    if (!settings.updateName) return;
    if (waypointNameManual) return;
    if (settings.reason === "drag" && !shouldResolveNameForMove(lat, lng)) {
      return;
    }
    setResolvingWaypointName();
    var resolveId = ++waypointNameResolveId;
    resolveWaypointName(lat, lng).then(function (name) {
      if (resolveId !== waypointNameResolveId) return;
      if (waypointNameManual) return;
      setWaypointNameValue(name);
    });
  }

  function setMarineStatus(message, kind, allowHtml) {
    if (!marineStatusLine) {
      marineStatusLine = document.getElementById("marineStatusLine");
    }
    if (!marineStatusLine) return;
    if (allowHtml) {
      marineStatusLine.innerHTML = message || "";
    } else {
      marineStatusLine.textContent = message || "";
    }
    marineStatusLine.classList.remove("text-muted", "text-danger", "text-success", "text-warning");
    if (kind === "error") {
      marineStatusLine.classList.add("text-danger");
    } else if (kind === "warn") {
      marineStatusLine.classList.add("text-warning");
    } else if (kind === "success") {
      marineStatusLine.classList.add("text-success");
    } else {
      marineStatusLine.classList.add("text-muted");
    }
  }

  function setMarineLoadingStatus(text) {
    var label = text || "Loading marine POIs…";
    setMarineStatus(
      '<span class="spinner-border spinner-border-sm text-light me-1" role="status" aria-hidden="true"></span>' +
      '<span class="text-light">' + utils.escapeHtml(label) + '</span>',
      "info",
      true
    );
  }

  function getMarineFiltersFromUI() {
    var types = [];
    var marinaInput = document.getElementById("marineTypeMarina");
    var fuelInput = document.getElementById("marineTypeFuel");
    var rampInput = document.getElementById("marineTypeRamp");
    if (marinaInput && marinaInput.checked) types.push("marina");
    if (fuelInput && fuelInput.checked) types.push("fuel");
    if (rampInput && rampInput.checked) types.push("ramp");
    return {
      placesEnabled: types.length > 0,
      tideEnabled: !!(marineTideToggle && marineTideToggle.checked),
      types: types
    };
  }

  function getWaypointMap() {
    return waypointMapController ? waypointMapController.getMap() : null;
  }

  function getVisibleRadiusNm() {
    var map = getWaypointMap();
    if (!map || !map.getBounds) return null;
    var bounds = map.getBounds();
    if (!bounds) return null;
    var center = map.getCenter();
    var northEast = bounds.getNorthEast();
    if (!center || !northEast) return null;
    return computeDistanceNm(center.lat, center.lng, northEast.lat, northEast.lng);
  }

  function clearPlacesPOIs() {
    placeMarkers.forEach(function (marker) {
      marker.remove();
    });
    placeMarkers = [];
  }

  function createPlaceIcon(labelText, fillColor) {
    if (!window.L) return null;
    return window.L.divIcon({
      className: "marine-poi-icon",
      html: '<span style="background:' + fillColor + '">' + utils.escapeHtml(labelText) + "</span>",
      iconSize: [22, 22],
      iconAnchor: [11, 11],
      popupAnchor: [0, -10]
    });
  }

  function formatPlaceTypeLabel(type) {
    if (type === "marina") return "Marina";
    if (type === "fuel") return "Fuel Dock";
    if (type === "ramp") return "Boat Ramp";
    return "Place";
  }

  function computeDistanceNm(lat1, lng1, lat2, lng2) {
    var toRad = function (value) { return value * Math.PI / 180; };
    var earthRadiusKm = 6371;
    var dLat = toRad(lat2 - lat1);
    var dLng = toRad(lng2 - lng1);
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    var km = earthRadiusKm * c;
    return km / 1.852;
  }

  function isSubsetArray(subset, superset) {
    if (!subset || !subset.length) return true;
    if (!superset || !superset.length) return false;
    for (var i = 0; i < subset.length; i++) {
      if (superset.indexOf(subset[i]) === -1) {
        return false;
      }
    }
    return true;
  }

  function canUsePlacesCache(centerLat, centerLng, radiusNm, types) {
    if (!lastPlacesCenter || lastPlacesRadius === null) return false;
    var distance = computeDistanceNm(centerLat, centerLng, lastPlacesCenter.lat, lastPlacesCenter.lng);
    if (distance > 0.5) return false;
    if (Math.abs(radiusNm - lastPlacesRadius) > 2) return false;
    return isSubsetArray(types, lastPlacesTypes);
  }

  function renderPlacesFromCache(types) {
    var map = getWaypointMap();
    if (!map || !window.L) {
      setMarineStatus("Map unavailable.", "warn");
      return;
    }
    clearPlacesPOIs();
    if (!lastPlacesPois || !lastPlacesPois.length) {
      setMarineStatus("No results.", "warn");
      return;
    }
    var filtered = lastPlacesPois.filter(function (poi) {
      return !types.length || types.indexOf(poi.type) !== -1;
    });
    if (!filtered.length) {
      setMarineStatus("No results.", "warn");
      return;
    }
    filtered.forEach(function (poi) {
      if (poi.lat === undefined || poi.lat === null || poi.lng === undefined || poi.lng === null) return;
      var labelText = "P";
      var color = "#2f6fdf";
      if (poi.type === "marina") {
        labelText = "M";
        color = "#1e88e5";
      } else if (poi.type === "fuel") {
        labelText = "F";
        color = "#ff7043";
      } else if (poi.type === "ramp") {
        labelText = "R";
        color = "#43a047";
      }
      var marker = window.L.marker([poi.lat, poi.lng], {
        icon: createPlaceIcon(labelText, color)
      }).addTo(map);
      marker.on("click", function () {
        openMarineInfoWindow(poi, marker, "place");
      });
      placeMarkers.push(marker);
    });
    setMarineStatus("Loaded " + placeMarkers.length + " place" + (placeMarkers.length === 1 ? "" : "s") + ".", "success");
  }

  function applyPoiToWaypoint(poi) {
    if (!poi) return;
    var name = utils.pick(poi, ["name", "NAME"], "");
    var lat = utils.pick(poi, ["lat", "LAT"], null);
    var lng = utils.pick(poi, ["lng", "LNG"], null);
    if (waypointNameInput) {
      suppressWaypointNameInput = true;
      waypointNameInput.value = name || "";
      suppressWaypointNameInput = false;
    }
    if (lat !== undefined && lat !== null && lng !== undefined && lng !== null) {
      updateWaypointLatLngInputs(lat, lng);
      setWaypointMarker(lat, lng);
    }
  }

  function normalizePoi(poi) {
    if (!poi) return null;
    return {
      id: utils.pick(poi, ["id", "ID"], ""),
      source: utils.pick(poi, ["source", "SOURCE"], ""),
      type: utils.pick(poi, ["type", "TYPE"], ""),
      name: utils.pick(poi, ["name", "NAME"], ""),
      lat: utils.pick(poi, ["lat", "LAT"], null),
      lng: utils.pick(poi, ["lng", "LNG"], null),
      summary: utils.pick(poi, ["summary", "SUMMARY"], ""),
      details: utils.pick(poi, ["details", "DETAILS"], {}) || {}
    };
  }

  function buildPlaceInfoContent(poi, extraDetails) {
    var name = poi.name || "Marine Place";
    var typeLabel = formatPlaceTypeLabel(poi.type);
    var distanceText = "";
    if (state.homePortLatLng) {
      var distance = computeDistanceNm(state.homePortLatLng.lat, state.homePortLatLng.lng, poi.lat, poi.lng);
      distanceText = distance ? distance.toFixed(1) + " nm from home port" : "";
    }
    var details = extraDetails || {};
    var detailParts = [];
    if (details.phone) detailParts.push("Phone: " + utils.escapeHtml(details.phone));
    if (details.website) detailParts.push("Website: " + utils.escapeHtml(details.website));
    if (details.hours) detailParts.push("Hours: " + utils.escapeHtml(details.hours));
    if (details.rating) detailParts.push("Rating: " + utils.escapeHtml(details.rating));
    if (details.photo) detailParts.push("<img src=\"" + encodeURI(details.photo) + "\" alt=\"\" style=\"max-width:120px;border-radius:6px;\">");
    var detailHtml = detailParts.length ? "<div class=\"mt-2 small\">" + detailParts.join("<br>") + "</div>" : "";
    var summaryHtml = poi.summary ? "<div class=\"small text-muted\">" + utils.escapeHtml(poi.summary) + "</div>" : "";
    var distanceHtml = distanceText ? "<div class=\"small text-muted\">" + utils.escapeHtml(distanceText) + "</div>" : "";
    return ""
      + "<div style=\"min-width:220px;color:#1b1b1b\">"
      + "<div><strong>" + utils.escapeHtml(name) + "</strong></div>"
      + "<div class=\"small\">" + utils.escapeHtml(typeLabel) + "</div>"
      + summaryHtml
      + distanceHtml
      + "<div class=\"mt-2 d-flex gap-2\">"
      + "<button type=\"button\" class=\"btn btn-sm btn-primary\" id=\"marineUseWaypointBtn\">Use as Waypoint</button>"
      + "<button type=\"button\" class=\"btn btn-sm btn-outline-secondary\" id=\"marineMoreDetailsBtn\">More Details</button>"
      + "</div>"
      + detailHtml
      + "</div>";
  }

  function bindMarineInfoWindowActions(poi, type, marker) {
    var useBtn = document.getElementById("marineUseWaypointBtn");
    if (useBtn) {
      useBtn.addEventListener("click", function () {
        applyPoiToWaypoint(poi);
        if (marker && marker.closePopup) marker.closePopup();
      });
    }
    var detailsBtn = document.getElementById("marineMoreDetailsBtn");
    if (detailsBtn && type === "place") {
      detailsBtn.addEventListener("click", function () {
        if (!window.Api || typeof window.Api.enrichPlace !== "function") {
          return;
        }
        detailsBtn.disabled = true;
        detailsBtn.textContent = "Loading…";
        var requestId = ++marinePlaceDetailsRequestId;
        Api.enrichPlace({ lat: poi.lat, lng: poi.lng, name: poi.name || "" })
          .then(function (data) {
            if (requestId !== marinePlaceDetailsRequestId) return;
            if (data && data.SUCCESS && data.DETAILS) {
              var enriched = data.DETAILS;
              if (marker && marker.setPopupContent) {
                marker.setPopupContent(buildPlaceInfoContent(poi, {
                  phone: enriched.PHONE,
                  website: enriched.WEBSITE,
                  hours: enriched.HOURS,
                  rating: enriched.RATING,
                  photo: enriched.PHOTO
                }));
                setTimeout(function () {
                  bindMarineInfoWindowActions(poi, "place", marker);
                }, 0);
              }
            }
          })
          .catch(function () {
            if (marker && marker.setPopupContent) {
              marker.setPopupContent(buildPlaceInfoContent(poi, { }));
              setTimeout(function () {
                bindMarineInfoWindowActions(poi, "place", marker);
              }, 0);
            }
          });
      });
    }
  }

  function openMarineInfoWindow(poi, marker, type) {
    if (!marker || !marker.bindPopup) return;
    if (marker.getPopup && marker.getPopup()) {
      marker.setPopupContent(buildPlaceInfoContent(poi, null));
    } else {
      marker.bindPopup(buildPlaceInfoContent(poi, null), { maxWidth: 260 });
    }
    marker.openPopup();
    marker.once("popupopen", function () {
      bindMarineInfoWindowActions(poi, type === "nav" ? "nav" : "place", marker);
    });
  }

  function loadPlacesPOIs(centerLat, centerLng, radiusNm, types) {
    var map = getWaypointMap();
    if (!map || !window.L) {
      return Promise.resolve();
    }
    if (!window.Api || typeof window.Api.getMarinePlaces !== "function") {
      return Promise.resolve();
    }
    if (!types || !types.length) {
      clearPlacesPOIs();
      setMarineStatus("No place types selected.", "warn");
      return Promise.resolve();
    }
    var requestId = ++marinePlacesRequestId;
    var typeLabel = types && types.length ? types.join(", ") : "none";
    setMarineLoadingStatus("Loading marine POIs… (" + typeLabel + ")");
    return Api.getMarinePlaces({
      lat: centerLat,
      lng: centerLng,
      radiusNm: radiusNm,
      types: types
    })
      .then(function (data) {
        if (requestId !== marinePlacesRequestId) return;
        if (!data || data.SUCCESS !== true) {
          throw data;
        }
        clearPlacesPOIs();
        var pois = data.POIS || [];
        if (!pois.length) {
          setMarineStatus("No results.", "warn");
          return;
        }
        if (pois.length > 200) {
          pois = pois.slice(0, 200);
        }
        lastPlacesPois = [];
        pois.forEach(function (poi) {
          var normalized = normalizePoi(poi);
          if (!normalized || normalized.lat === undefined || normalized.lat === null || normalized.lng === undefined || normalized.lng === null) return;
          lastPlacesPois.push(normalized);
          var labelText = "P";
          var color = "#2f6fdf";
          if (normalized.type === "marina") {
            labelText = "M";
            color = "#1e88e5";
          } else if (normalized.type === "fuel") {
            labelText = "F";
            color = "#ff7043";
          } else if (normalized.type === "ramp") {
            labelText = "R";
            color = "#43a047";
          }
          var marker = window.L.marker([normalized.lat, normalized.lng], {
            icon: createPlaceIcon(labelText, color)
          }).addTo(map);
          marker.on("click", function () {
            openMarineInfoWindow(normalized, marker, "place");
          });
          placeMarkers.push(marker);
        });
        lastPlacesTypes = types.slice();
        lastPlacesCenter = { lat: centerLat, lng: centerLng };
        lastPlacesRadius = radiusNm;
        setMarineStatus("Loaded " + placeMarkers.length + " place" + (placeMarkers.length === 1 ? "" : "s") + ".", "success");
      })
      .catch(function (err) {
        if (requestId !== marinePlacesRequestId) return;
        console.warn("Failed to load marine POIs:", err);
        var detailText = "";
        if (err && err.DETAIL) {
          detailText = " (" + err.DETAIL + ")";
        }
        setMarineStatus(((err && err.MESSAGE) ? err.MESSAGE : "Error loading POIs.") + detailText, "error");
      });
  }

  function debounceMapIdleReload(force) {
    var map = getWaypointMap();
    if (!map) return;
    if (marineIdleTimer) {
      clearTimeout(marineIdleTimer);
    }
    var delay = force ? 100 : 350;
    marineIdleTimer = setTimeout(function () {
      var filters = getMarineFiltersFromUI();
      var visibleRadius = getVisibleRadiusNm();
      var effectiveRadius = (visibleRadius && !isNaN(visibleRadius)) ? visibleRadius : 10;

      if (!filters.placesEnabled) {
        marinePlacesRequestId += 1;
        clearPlacesPOIs();
      } else {
        var center = map.getCenter();
        if (center) {
          if (canUsePlacesCache(center.lat, center.lng, effectiveRadius, filters.types)) {
            marinePlacesRequestId += 1;
            renderPlacesFromCache(filters.types);
          } else {
            loadPlacesPOIs(center.lat, center.lng, effectiveRadius, filters.types);
          }
        }
      }
      if (!filters.placesEnabled) {
        setMarineStatus("Ready", "info");
      }
    }, delay);
  }

  function setWaypointMarker(lat, lng) {
    if (!waypointMapController) return;
    waypointMapController.setWaypointMarker(lat, lng);
  }

  function setHomePortMarker(lat, lng) {
    if (!waypointMapController) return;
    waypointMapController.setHomePortMarker(lat, lng);
  }

  function prepareWaypointMap(context) {
    if (!waypointMapController) return;
    waypointMapController.setContext(context);
  }

  function openWaypointModalAdd() {
    var fallback = state.homePortLatLng || { lat: 27.8, lng: -82.7 };
    openWaypointModal(null);
    pendingMarineReload = true;
    prepareWaypointMap({
      center: fallback,
      homePort: state.homePortLatLng,
      waypoint: null
    });
  }

  function openWaypointModalEdit(waypoint) {
    var lat = parseFloat(utils.pick(waypoint, ["LATITUDE"], ""));
    var lng = parseFloat(utils.pick(waypoint, ["LONGITUDE"], ""));
    var hasCoords = !isNaN(lat) && !isNaN(lng);
    var center = hasCoords ? { lat: lat, lng: lng } : (state.homePortLatLng || { lat: 27.8, lng: -82.7 });
    openWaypointModal(waypoint);
    var marinaInput = document.getElementById("marineTypeMarina");
    var fuelInput = document.getElementById("marineTypeFuel");
    var rampInput = document.getElementById("marineTypeRamp");
    if (marinaInput) marinaInput.checked = false;
    if (fuelInput) fuelInput.checked = false;
    if (rampInput) rampInput.checked = false;
    pendingMarineReload = true;
    prepareWaypointMap({
      center: center,
      homePort: state.homePortLatLng,
      waypoint: hasCoords ? { lat: lat, lng: lng } : null
    });
  }

  function buildWaypointPayload() {
    return {
      WAYPOINTID: parseInt(waypointIdInput ? waypointIdInput.value : "0", 10) || 0,
      WAYPOINTNAME: waypointNameInput ? waypointNameInput.value.trim() : "",
      LATITUDE: waypointLatitudeInput ? waypointLatitudeInput.value.trim() : "",
      LONGITUDE: waypointLongitudeInput ? waypointLongitudeInput.value.trim() : "",
      NOTES: waypointNotesInput ? waypointNotesInput.value.trim() : ""
    };
  }

  function saveWaypoint() {
    if (!window.Api || typeof window.Api.saveWaypoint !== "function") {
      utils.showAlertModal("Waypoints API is unavailable.");
      return;
    }

    var payload = buildWaypointPayload();
    clearWaypointValidation();
    var hasError = false;
    if (!payload.WAYPOINTNAME) {
      utils.setFieldError(waypointNameInput, waypointNameError, "Name is required.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (waypointSaveBtn) {
      waypointSaveBtn.disabled = true;
      waypointSaveBtn.textContent = "Saving…";
    }

    Api.saveWaypoint({ waypoint: payload })
      .then(function (data) {
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (waypointModal) {
          waypointModal.hide();
        }
        loadWaypoints();
      })
      .catch(function (err) {
        console.error("Failed to save waypoint:", err);
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save waypoint.");
      })
      .finally(function () {
        if (waypointSaveBtn) {
          waypointSaveBtn.disabled = false;
          waypointSaveBtn.textContent = "Save Waypoint";
        }
      });
  }

  function findWaypointById(waypointId) {
    var list = waypointState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = utils.pick(list[i], ["WAYPOINTID", "ID"], 0);
      if (String(currentId) === String(waypointId)) {
        return list[i];
      }
    }
    return null;
  }

  function deleteWaypoint(waypointId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteWaypoint !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteWaypoint(waypointId)
      .then(function (data) {
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadWaypoints();
      })
      .catch(function (err) {
        console.error("Failed to delete waypoint:", err);
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handleWaypointsListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-waypoint-id]");
    if (!button) return;

    var waypointId = button.getAttribute("data-waypoint-id");
    var action = button.getAttribute("data-action");
    if (!waypointId) return;

    if (action === "edit") {
      var waypoint = findWaypointById(waypointId);
      openWaypointModalEdit(waypoint);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeleteWaypoint !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeleteWaypoint(waypointId)
        .then(function (data) {
          if (!utils.ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            utils.showAlertModal(data.MESSAGE || "This waypoint cannot be deleted.");
            return;
          }
          var waypoint = findWaypointById(waypointId);
          var waypointName = waypoint ? utils.pick(waypoint, ["WAYPOINTNAME", "NAME"], "") : "";
          var confirmText = waypointName ? "Delete " + waypointName + "?" : "Delete this waypoint?";
          utils.showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteWaypoint(waypointId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check waypoint usage:", err);
          utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check waypoint usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function handleMarineControlChange(event) {
    var target = event.target;
    if (!target || !target.id) return;
    if (waypointModalEl && !waypointModalEl.contains(target)) return;
    var marineIds = {
      marineTideToggle: true,
      marineTypeMarina: true,
      marineTypeFuel: true,
      marineTypeRamp: true
    };
    if (!marineIds[target.id]) return;
    ensureWaypointModal();
    setMarineStatus("Updating marine layers…", "info");
    debounceMapIdleReload(true);
  }

  function initWaypoints() {
    var listEl = document.getElementById("waypointsList");
    var addWaypointBtn = document.getElementById("addWaypointBtn");
    if (!listEl && !addWaypointBtn) return;

    ensureWaypointModal();

    if (addWaypointBtn) {
      addWaypointBtn.addEventListener("click", function () {
        openWaypointModalAdd();
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handleWaypointsListClick);
    }

    document.addEventListener("change", handleMarineControlChange);
    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadWaypoints();
    });
  }

  window.FPW.DashboardModules.waypoints = {
    init: initWaypoints
  };
})(window, document);
