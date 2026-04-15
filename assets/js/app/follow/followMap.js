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
  var routeLineStyle = {
    color: "#5b7cfa",
    weight: 4,
    opacity: 0.92,
    lineJoin: "round",
    lineCap: "round"
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

  function normalizeSegmentCoordinates(rawSegment) {
    var coords = [];
    var i;
    var pt;
    var normalized;

    if (!Array.isArray(rawSegment)) return coords;

    for (i = 0; i < rawSegment.length; i += 1) {
      pt = rawSegment[i];
      if (Array.isArray(pt) && pt.length >= 2) {
        normalized = {
          lat: safeNum(pt[1]),
          lng: safeNum(pt[0])
        };
      } else {
        normalized = normalizePoint(pt);
      }
      if (!normalized || normalized.lat === null || normalized.lng === null) continue;
      coords.push([normalized.lat, normalized.lng]);
    }

    return coords.length >= 2 ? coords : [];
  }

  function normalizeRouteSegments(routeGeo) {
    var segments = [];
    var coords = [];
    var i;

    if (!routeGeo) return segments;

    if (Array.isArray(routeGeo)) {
      coords = normalizeSegmentCoordinates(routeGeo);
      if (coords.length) segments.push(coords);
      return segments;
    }

    if (routeGeo.type === "MultiLineString" && Array.isArray(routeGeo.coordinates)) {
      for (i = 0; i < routeGeo.coordinates.length; i += 1) {
        coords = normalizeSegmentCoordinates(routeGeo.coordinates[i]);
        if (coords.length) segments.push(coords);
      }
      return segments;
    }

    if (routeGeo.type === "LineString" && Array.isArray(routeGeo.coordinates)) {
      coords = normalizeSegmentCoordinates(routeGeo.coordinates);
      if (coords.length) segments.push(coords);
      return segments;
    }

    if (Array.isArray(routeGeo.coordinates)) {
      if (
        routeGeo.coordinates.length &&
        Array.isArray(routeGeo.coordinates[0]) &&
        Array.isArray(routeGeo.coordinates[0][0])
      ) {
        for (i = 0; i < routeGeo.coordinates.length; i += 1) {
          coords = normalizeSegmentCoordinates(routeGeo.coordinates[i]);
          if (coords.length) segments.push(coords);
        }
        return segments;
      }
      coords = normalizeSegmentCoordinates(routeGeo.coordinates);
      if (coords.length) segments.push(coords);
      return segments;
    }

    return segments;
  }

  function normalizeRouteCoordinates(routeGeo) {
    var segments = normalizeRouteSegments(routeGeo);
    var coords = [];
    var i;
    var j;

    for (i = 0; i < segments.length; i += 1) {
      for (j = 0; j < segments[i].length; j += 1) {
        coords.push(segments[i][j]);
      }
    }

    return coords;
  }

  function makePinIcon(type) {
    var pinType = String(type || "intermediate").toLowerCase();
    var size = 17;
    var anchor = 8.5;
    if (pinType !== "start" && pinType !== "end") {
      pinType = "intermediate";
    }

    return window.L.divIcon({
      className: "marine-poi-icon follow-map-marker",
      html: '<span class="follow-pin ' + pinType + '"></span>',
      iconSize: [size, size],
      iconAnchor: [anchor, anchor]
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
    state.routeLayer = window.L.layerGroup().addTo(state.map);

    state.pinLayer = window.L.layerGroup().addTo(state.map);

    return state.map;
  }

  function renderRoute(routeGeo) {
    var segments = normalizeRouteSegments(routeGeo);
    var coords = [];
    var i;
    var j;
    if (!state.map || !state.routeLayer) return coords;

    state.routeLayer.clearLayers();

    for (i = 0; i < segments.length; i += 1) {
      window.L.polyline(segments[i], routeLineStyle).addTo(state.routeLayer);
      for (j = 0; j < segments[i].length; j += 1) {
        coords.push(segments[i][j]);
      }
    }
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
          className: "marine-poi-icon follow-map-marker",
          html: '<span class="follow-boat-marker"></span>',
          iconSize: [17, 17],
          iconAnchor: [8.5, 8.5]
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
