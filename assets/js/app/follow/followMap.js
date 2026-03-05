(function (window) {
  "use strict";

  var state = {
    map: null,
    routeLayer: null,
    pinLayer: null,
    boatMarker: null,
    defaultView: [39.5, -95.5],
    defaultZoom: 4
  };

  function hasLeaflet() {
    return !!(window.L && typeof window.L.map === "function");
  }

  function safeNum(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return null;
    return n;
  }

  function normalizePoint(raw) {
    if (!raw || typeof raw !== "object") return null;
    var lat = safeNum(raw.lat !== undefined ? raw.lat : raw.latitude);
    var lng = safeNum(
      raw.lng !== undefined ? raw.lng :
        (raw.lon !== undefined ? raw.lon : raw.longitude)
    );
    if (lat === null || lng === null) return null;
    return { lat: lat, lng: lng };
  }

  function normalizeRouteCoordinates(routeGeo) {
    var coords = [];
    var i;
    var pt;
    var normalized;
    if (!routeGeo) return coords;

    if (Array.isArray(routeGeo)) {
      for (i = 0; i < routeGeo.length; i += 1) {
        normalized = normalizePoint(routeGeo[i]);
        if (normalized) coords.push([normalized.lat, normalized.lng]);
      }
      return coords;
    }

    if (routeGeo.type === "LineString" && Array.isArray(routeGeo.coordinates)) {
      for (i = 0; i < routeGeo.coordinates.length; i += 1) {
        pt = routeGeo.coordinates[i];
        if (!Array.isArray(pt) || pt.length < 2) continue;
        normalized = {
          lat: safeNum(pt[1]),
          lng: safeNum(pt[0])
        };
        if (normalized.lat === null || normalized.lng === null) continue;
        coords.push([normalized.lat, normalized.lng]);
      }
      return coords;
    }

    if (Array.isArray(routeGeo.coordinates)) {
      for (i = 0; i < routeGeo.coordinates.length; i += 1) {
        pt = routeGeo.coordinates[i];
        if (!Array.isArray(pt) || pt.length < 2) continue;
        normalized = {
          lat: safeNum(pt[1]),
          lng: safeNum(pt[0])
        };
        if (normalized.lat === null || normalized.lng === null) continue;
        coords.push([normalized.lat, normalized.lng]);
      }
      return coords;
    }

    return coords;
  }

  function makePinIcon(type) {
    var pinType = String(type || "intermediate").toLowerCase();
    if (pinType !== "start" && pinType !== "end") {
      pinType = "intermediate";
    }

    return window.L.divIcon({
      className: "",
      html: '<span class="follow-pin ' + pinType + '"></span>',
      iconSize: pinType === "intermediate" ? [8, 8] : [12, 12],
      iconAnchor: pinType === "intermediate" ? [4, 4] : [6, 6]
    });
  }

  function initFollowMap(containerId, mapOptions) {
    var opts = mapOptions || {};
    var tileUrl = opts.tileUrl || "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
    var tileOptions = opts.tileOptions || {
      maxZoom: 18,
      attribution: "&copy; OpenStreetMap"
    };

    if (!hasLeaflet()) {
      throw new Error("Leaflet is not loaded.");
    }

    if (state.map) {
      return state.map;
    }

    state.map = window.L.map(containerId, {
      zoomControl: true,
      preferCanvas: true
    }).setView(state.defaultView, state.defaultZoom);

    window.L.tileLayer(tileUrl, tileOptions).addTo(state.map);
    state.routeLayer = window.L.polyline([], {
      color: "#5b7cfa",
      weight: 4,
      opacity: 0.92,
      lineJoin: "round",
      lineCap: "round"
    }).addTo(state.map);

    state.pinLayer = window.L.layerGroup().addTo(state.map);

    return state.map;
  }

  function renderRoute(routeGeo) {
    var coords = normalizeRouteCoordinates(routeGeo);
    if (!state.map || !state.routeLayer) return coords;

    state.routeLayer.setLatLngs(coords);
    return coords;
  }

  function renderPins(pins) {
    var list = Array.isArray(pins) ? pins : [];
    var i;
    var pin;
    var point;
    var marker;
    var seq;
    var label;

    if (!state.map || !state.pinLayer) return;

    state.pinLayer.clearLayers();

    for (i = 0; i < list.length; i += 1) {
      pin = list[i] || {};
      point = normalizePoint(pin);
      if (!point) continue;

      marker = window.L.marker([point.lat, point.lng], {
        icon: makePinIcon(pin.type)
      }).addTo(state.pinLayer);

      seq = safeNum(pin.sequence);
      label = String(pin.label || "Point").trim() || "Point";
      if (seq !== null) {
        label = label + " (#" + String(Math.round(seq)) + ")";
      }
      marker.bindTooltip(label, {
        direction: "top",
        opacity: 0.92
      });
    }
  }

  function fitBoundsToRoute(routeGeo, pins) {
    var coords = normalizeRouteCoordinates(routeGeo);
    var pinList = Array.isArray(pins) ? pins : [];
    var i;
    var p;

    if (!state.map || !window.L) return;

    for (i = 0; i < pinList.length; i += 1) {
      p = normalizePoint(pinList[i]);
      if (!p) continue;
      coords.push([p.lat, p.lng]);
    }

    if (!coords.length) {
      state.map.setView(state.defaultView, state.defaultZoom);
      return;
    }

    if (coords.length === 1) {
      state.map.setView(coords[0], 9);
      return;
    }

    state.map.fitBounds(window.L.latLngBounds(coords), {
      padding: [22, 22],
      maxZoom: 11
    });
  }

  function updateBoatMarker(lat, lng, label) {
    var p = normalizePoint({ lat: lat, lng: lng });
    var tooltip = String(label || "Current position").trim() || "Current position";

    if (!state.map || !p) return;

    if (!state.boatMarker) {
      state.boatMarker = window.L.marker([p.lat, p.lng], {
        icon: window.L.divIcon({
          className: "",
          html: '<span class="follow-boat-marker"></span>',
          iconSize: [14, 14],
          iconAnchor: [7, 7]
        })
      }).addTo(state.map);
    } else {
      state.boatMarker.setLatLng([p.lat, p.lng]);
    }

    state.boatMarker.bindTooltip(tooltip, {
      direction: "right",
      opacity: 0.9
    });
  }

  window.FPWFollowMap = {
    initFollowMap: initFollowMap,
    renderRoute: renderRoute,
    renderPins: renderPins,
    fitBoundsToRoute: fitBoundsToRoute,
    updateBoatMarker: updateBoatMarker
  };
})(window);
