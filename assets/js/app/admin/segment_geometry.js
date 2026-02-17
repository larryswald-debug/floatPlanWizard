/*
Manual test steps:
1) Login as admin.
2) Open /fpw/app/admin/segment_geometry.cfm.
3) Select a segment and click Load (expect no geometry first time for untouched rows).
4) Draw one polyline roughly matching the route.
5) Click Save and confirm status shows success with version=1 and dist_nm_calc.
6) Reload page and click Load again; confirm polyline reappears and version persists.
7) Draw a revised polyline and click Save; confirm version increments to 2.
8) Verify loop_segments.active_geom_version and loop_segments.dist_nm_calc updated in DB.
9) Confirm existing route generator still behaves normally (this feature is additive).
*/
(function (window, document) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var API_URL = BASE_PATH + "/api/v1/segmentGeometry.cfc?method=handle&returnFormat=json";

  var dom = {
    segmentSelect: null,
    loadBtn: null,
    saveBtn: null,
    clearBtn: null,
    pointCount: null,
    computedNm: null,
    version: null,
    status: null
  };

  var state = {
    map: null,
    drawnItems: null,
    activeLayer: null,
    segments: []
  };

  function toInt(value) {
    var n = parseInt(value, 10);
    return Number.isFinite(n) ? n : 0;
  }

  function toNum(value) {
    var n = parseFloat(value);
    return Number.isFinite(n) ? n : 0;
  }

  function round6(value) {
    return Math.round(toNum(value) * 1000000) / 1000000;
  }

  function formatNm(value) {
    var n = parseFloat(value);
    if (!Number.isFinite(n)) return "--";
    return n.toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }

  function setStatus(message, type) {
    if (!dom.status) return;
    dom.status.textContent = message || "";
    dom.status.classList.remove("error");
    dom.status.classList.remove("success");
    if (type === "error") dom.status.classList.add("error");
    if (type === "success") dom.status.classList.add("success");
  }

  function setReadouts(pointCount, nm, version) {
    if (dom.pointCount) {
      dom.pointCount.textContent = Number.isFinite(pointCount) ? String(pointCount) : "0";
    }
    if (dom.computedNm) {
      dom.computedNm.textContent = Number.isFinite(parseFloat(nm)) ? formatNm(nm) : "--";
    }
    if (dom.version) {
      dom.version.textContent = Number.isFinite(parseFloat(version)) ? String(parseInt(version, 10)) : "--";
    }
  }

  function updatePointCountFromLayer() {
    if (!state.activeLayer) {
      setReadouts(0, NaN, NaN);
      return;
    }

    var points = extractPoints(state.activeLayer);
    if (dom.pointCount) dom.pointCount.textContent = String(points.length);
  }

  function apiPost(action, payload) {
    var body = Object.assign({}, payload || {}, { action: action });

    return fetch(API_URL, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    })
      .then(function (res) {
        return res.text().then(function (txt) {
          var data;
          try {
            data = txt ? JSON.parse(txt) : {};
          } catch (err) {
            throw new Error("Non-JSON response from segment geometry API.");
          }

          if (!res.ok) {
            throw new Error((data && data.MESSAGE) ? data.MESSAGE : ("HTTP " + res.status));
          }

          if (data && data.AUTH === false) {
            throw new Error(data.MESSAGE || "Unauthorized");
          }

          if (!data || data.SUCCESS !== true) {
            var errMsg = (data && data.MESSAGE) ? data.MESSAGE : "API request failed.";
            if (data && data.ERROR && data.ERROR.MESSAGE) {
              errMsg += " " + data.ERROR.MESSAGE;
            }
            throw new Error(errMsg.trim());
          }

          return data;
        });
      });
  }

  function getSelectedSegmentId() {
    if (!dom.segmentSelect) return 0;
    return toInt(dom.segmentSelect.value);
  }

  function clearPolyline() {
    if (state.activeLayer && state.drawnItems) {
      state.drawnItems.removeLayer(state.activeLayer);
    }
    state.activeLayer = null;
    if (dom.pointCount) dom.pointCount.textContent = "0";
  }

  function setActiveLayer(layer) {
    if (!state.drawnItems) return;

    if (state.activeLayer) {
      state.drawnItems.removeLayer(state.activeLayer);
      state.activeLayer = null;
    }

    if (layer) {
      state.activeLayer = layer;
      state.drawnItems.addLayer(layer);
    }

    updatePointCountFromLayer();
  }

  function extractPoints(layer) {
    if (!layer || typeof layer.getLatLngs !== "function") return [];

    var latlngs = layer.getLatLngs();
    if (!Array.isArray(latlngs)) return [];

    if (latlngs.length && Array.isArray(latlngs[0])) {
      latlngs = latlngs[0];
    }

    return latlngs
      .filter(function (pt) {
        return pt && Number.isFinite(pt.lat) && Number.isFinite(pt.lng);
      })
      .map(function (pt) {
        return {
          lat: round6(pt.lat),
          lon: round6(pt.lng)
        };
      });
  }

  function populateSegmentSelect(segments) {
    if (!dom.segmentSelect) return;

    dom.segmentSelect.innerHTML = "";

    if (!Array.isArray(segments) || !segments.length) {
      var emptyOption = document.createElement("option");
      emptyOption.value = "";
      emptyOption.textContent = "No segments found";
      dom.segmentSelect.appendChild(emptyOption);
      return;
    }

    var defaultOption = document.createElement("option");
    defaultOption.value = "";
    defaultOption.textContent = "Select a segment";
    dom.segmentSelect.appendChild(defaultOption);

    segments.forEach(function (segment) {
      var option = document.createElement("option");
      option.value = String(segment.id || "");

      var start = segment.start_name || "Unknown Start";
      var end = segment.end_name || "Unknown End";
      var canonicalNm = Number.isFinite(parseFloat(segment.dist_nm)) ? formatNm(segment.dist_nm) : "--";
      var calcNm = Number.isFinite(parseFloat(segment.dist_nm_calc)) ? formatNm(segment.dist_nm_calc) : "--";

      option.textContent = start + " -> " + end + " (id " + segment.id + ") [nm " + canonicalNm + ", calc " + calcNm + "]";
      dom.segmentSelect.appendChild(option);
    });
  }

  function loadSegments() {
    setStatus("Loading canonical segments...");

    return apiPost("listSegments", {})
      .then(function (response) {
        state.segments = (response.DATA && Array.isArray(response.DATA.segments)) ? response.DATA.segments : [];
        populateSegmentSelect(state.segments);
        setStatus("Segments loaded. Select one and click Load.", "success");
      })
      .catch(function (err) {
        populateSegmentSelect([]);
        setStatus("Unable to load segments. " + err.message, "error");
      });
  }

  function pointsFromGeometryData(data) {
    if (!data) return [];

    if (Array.isArray(data.points) && data.points.length) {
      return data.points
        .map(function (p) {
          var lat = toNum(p.lat !== undefined ? p.lat : p.latitude);
          var lon = toNum(p.lon !== undefined ? p.lon : (p.lng !== undefined ? p.lng : p.longitude));
          if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
          return { lat: lat, lon: lon };
        })
        .filter(Boolean);
    }

    if (typeof data.polyline_json === "string" && data.polyline_json.trim().length) {
      try {
        var parsed = JSON.parse(data.polyline_json);
        if (Array.isArray(parsed)) {
          return parsed
            .map(function (p) {
              var lat = toNum(p.lat !== undefined ? p.lat : p.latitude);
              var lon = toNum(p.lon !== undefined ? p.lon : (p.lng !== undefined ? p.lng : p.longitude));
              if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
              return { lat: lat, lon: lon };
            })
            .filter(Boolean);
        }
      } catch (err) {
        return [];
      }
    }

    return [];
  }

  function loadGeometryForSelected() {
    var segmentId = getSelectedSegmentId();
    if (!segmentId) {
      setStatus("Select a segment first.", "error");
      return;
    }

    setStatus("Loading active geometry...");

    apiPost("getActiveGeometry", { segmentId: segmentId })
      .then(function (response) {
        var data = response.DATA || {};

        clearPolyline();

        if (!data.exists) {
          setReadouts(0, NaN, NaN);
          setStatus("No saved geometry for this segment yet. Draw a polyline and click Save.", "success");
          return;
        }

        var points = pointsFromGeometryData(data);
        if (points.length >= 2) {
          var latlngs = points.map(function (p) {
            return [p.lat, p.lon];
          });
          var layer = window.L.polyline(latlngs, {
            color: "#5ab3ff",
            weight: 4,
            opacity: 0.95
          });
          setActiveLayer(layer);

          var bounds = layer.getBounds();
          if (bounds && bounds.isValid()) {
            state.map.fitBounds(bounds, { padding: [24, 24] });
          }
        }

        setReadouts(toInt(data.point_count), parseFloat(data.dist_nm_calc), toInt(data.version));
        setStatus("Loaded geometry version " + toInt(data.version) + ".", "success");
      })
      .catch(function (err) {
        setStatus("Load failed. " + err.message, "error");
      });
  }

  function saveGeometry() {
    var segmentId = getSelectedSegmentId();
    if (!segmentId) {
      setStatus("Select a segment first.", "error");
      return;
    }

    if (!state.activeLayer) {
      setStatus("Draw a polyline before saving.", "error");
      return;
    }

    var points = extractPoints(state.activeLayer);
    if (points.length < 2) {
      setStatus("Polyline must contain at least 2 points.", "error");
      return;
    }

    setStatus("Saving geometry...");

    apiPost("saveGeometry", {
      segmentId: segmentId,
      points: points,
      source: "manual_draw"
    })
      .then(function (response) {
        var data = response.DATA || {};
        setReadouts(toInt(data.point_count), parseFloat(data.dist_nm_calc), toInt(data.version));
        setStatus("Saved geometry version " + toInt(data.version) + " (" + formatNm(data.dist_nm_calc) + " NM).", "success");
        loadSegments();
      })
      .catch(function (err) {
        setStatus("Save failed. " + err.message, "error");
      });
  }

  function clearGeometryUi() {
    clearPolyline();
    setReadouts(0, NaN, NaN);
    setStatus("Polyline cleared.");
  }

  function initMap() {
    state.map = window.L.map("geometryMap", {
      center: [39.5, -95.5],
      zoom: 4,
      zoomControl: true
    });

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; OpenStreetMap contributors',
      maxZoom: 19
    }).addTo(state.map);

    state.drawnItems = new window.L.FeatureGroup();
    state.map.addLayer(state.drawnItems);

    var drawControl = new window.L.Control.Draw({
      draw: {
        polyline: {
          shapeOptions: {
            color: "#5ab3ff",
            weight: 4,
            opacity: 0.95
          }
        },
        polygon: false,
        rectangle: false,
        circle: false,
        marker: false,
        circlemarker: false
      },
      edit: {
        featureGroup: state.drawnItems,
        edit: true,
        remove: true
      }
    });

    state.map.addControl(drawControl);

    state.map.on(window.L.Draw.Event.CREATED, function (evt) {
      setActiveLayer(evt.layer);
      setStatus("Polyline ready. Click Save to store a new geometry version.");
    });

    state.map.on(window.L.Draw.Event.EDITED, function () {
      updatePointCountFromLayer();
      setStatus("Polyline updated. Click Save to create a new version.");
    });

    state.map.on(window.L.Draw.Event.DELETED, function () {
      state.activeLayer = null;
      setReadouts(0, NaN, NaN);
      setStatus("Polyline removed. Draw a new one or Load an existing geometry.");
    });
  }

  function bindEvents() {
    if (dom.loadBtn) {
      dom.loadBtn.addEventListener("click", function () {
        loadGeometryForSelected();
      });
    }

    if (dom.saveBtn) {
      dom.saveBtn.addEventListener("click", function () {
        saveGeometry();
      });
    }

    if (dom.clearBtn) {
      dom.clearBtn.addEventListener("click", function () {
        clearGeometryUi();
      });
    }
  }

  function initDom() {
    dom.segmentSelect = document.getElementById("segmentSelect");
    dom.loadBtn = document.getElementById("loadSegmentBtn");
    dom.saveBtn = document.getElementById("saveGeometryBtn");
    dom.clearBtn = document.getElementById("clearGeometryBtn");
    dom.pointCount = document.getElementById("pointCountValue");
    dom.computedNm = document.getElementById("computedNmValue");
    dom.version = document.getElementById("versionValue");
    dom.status = document.getElementById("geometryStatus");
  }

  function init() {
    initDom();

    if (!dom.segmentSelect || !document.getElementById("geometryMap")) {
      return;
    }

    initMap();
    bindEvents();
    loadSegments();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
