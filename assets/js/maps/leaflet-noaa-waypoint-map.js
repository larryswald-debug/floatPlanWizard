(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};

  window.FPW.initLeafletWaypointMap = function initLeafletWaypointMap(options) {
    var settings = options || {};
    var modalEl = settings.modalEl || null;
    var mapEl = settings.mapEl || null;
    var onMapClick = settings.onMapClick || null;
    var onMarkerDragEnd = settings.onMarkerDragEnd || null;
    var onMoveEnd = settings.onMoveEnd || null;
    var onMapReady = settings.onMapReady || null;
    var onMapDestroy = settings.onMapDestroy || null;

    var map = null;
    var waypointMarker = null;
    var homePortMarker = null;
    var layersControl = null;
    var radarLayer = null;
    var radarOpacityControl = null;
    var radarOpacity = 0.6;
    var radarTime = "";
    var radarWanted = false;
    var radarVisible = false;
    var radarCoverageBounds = null;
    var radarNoteControl = null;
    var suppressRadarToggle = false;
    var chartsOverlay = null;
    var chartsWanted = false;
    var chartsVisible = false;
    var chartsZoomNoteControl = null;
    var pendingContext = null;

    var defaultCenter = { lat: 27.8, lng: -82.7 };
    var defaultZoom = 11;

    // GetCapabilities URL (NOAA chart WMS):
    // https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer?SERVICE=WMS&REQUEST=GetCapabilities&VERSION=1.3.0
    var chartWmsUrl = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer";
    var chartLayerNames = "0,1,2,3,4,5,6,7,8,9,10,11,12";

    // NWS eventdriven radar GetCapabilities URL (via proxy):
    // /fpw/api/v1/wmsProxy.cfc?method=tile&target=nws-radar&SERVICE=WMS&REQUEST=GetCapabilities&VERSION=1.3.0
    // Selected layer name: "radar_base_reflectivity_time".
    var radarWmsUrl = "/fpw/api/v1/wmsProxy.cfc?method=tile&target=nws-radar";
    var radarLayerName = "radar_base_reflectivity_time";
    var radarCoverageBbox3857 = {
      minx: -19592230.379600,
      miny: 1005534.115038,
      maxx: 16698456.861354,
      maxy: 11753184.615300
    };
    var chartsZoomThreshold = 6;

    // TODO: Optional nowCOAST warnings overlay. Use GetCapabilities on a nowCOAST WMS warnings service to pick layer names.

    function createLetterIcon(label, color, size) {
      if (!window.L) return null;
      var diameter = size || 26;
      return window.L.divIcon({
        className: "marine-poi-icon",
        html: '<span style="background:' + color + '; width:' + diameter + 'px; height:' + diameter + 'px;">' + label + "</span>",
        iconSize: [diameter, diameter],
        iconAnchor: [diameter / 2, diameter / 2],
        popupAnchor: [0, -diameter / 2]
      });
    }

    function createRadarOpacityControl(onChange) {
      if (!window.L) return null;
      var container = null;
      var input = null;
      var control = window.L.control({ position: "topright" });
      control.onAdd = function () {
        container = window.L.DomUtil.create("div", "leaflet-control radar-opacity-control");
        container.innerHTML = ""
          + "<label>Radar opacity</label>"
          + '<input type="range" min="0" max="100" step="5" value="' + Math.round(radarOpacity * 100) + '">';
        input = container.querySelector("input");
        window.L.DomEvent.disableClickPropagation(container);
        window.L.DomEvent.disableScrollPropagation(container);
        if (input) {
          input.addEventListener("input", function () {
            var value = parseInt(input.value, 10) / 100;
            if (onChange) onChange(value);
          });
        }
        return container;
      };
      control.setEnabled = function (enabled) {
        if (!container) return;
        container.classList.toggle("is-disabled", !enabled);
      };
      return control;
    }

    function createRadarNoteControl() {
      if (!window.L) return null;
      var container = null;
      var control = window.L.control({ position: "topright" });
      control.onAdd = function () {
        container = window.L.DomUtil.create("div", "leaflet-control radar-coverage-note");
        container.style.fontSize = "12px";
        container.style.padding = "6px 8px";
        container.style.borderRadius = "6px";
        container.style.background = "rgba(0, 0, 0, 0.65)";
        container.style.color = "#fff";
        container.style.display = "none";
        container.innerHTML = "Radar hidden (outside coverage)";
        return container;
      };
      control.setVisible = function (visible) {
        if (!container) return;
        container.style.display = visible ? "block" : "none";
      };
      return control;
    }

    function createChartsZoomNoteControl() {
      if (!window.L) return null;
      var container = null;
      var control = window.L.control({ position: "topright" });
      control.onAdd = function () {
        container = window.L.DomUtil.create("div", "leaflet-control charts-coverage-note");
        container.style.fontSize = "12px";
        container.style.padding = "6px 8px";
        container.style.borderRadius = "6px";
        container.style.background = "rgba(0, 0, 0, 0.65)";
        container.style.color = "#fff";
        container.style.display = "none";
        container.innerHTML = "NOAA charts are best viewed when zoomed in.";
        return container;
      };
      control.setVisible = function (visible) {
        if (!container) return;
        container.style.display = visible ? "block" : "none";
      };
      return control;
    }

    function expandBounds(bounds, factor) {
      if (!bounds) return bounds;
      var sw = bounds.getSouthWest();
      var ne = bounds.getNorthEast();
      var latSpan = ne.lat - sw.lat;
      var lngSpan = ne.lng - sw.lng;
      var latPad = latSpan * factor;
      var lngPad = lngSpan * factor;
      var nextSw = window.L.latLng(sw.lat - latPad, sw.lng - lngPad);
      var nextNe = window.L.latLng(ne.lat + latPad, ne.lng + lngPad);
      return window.L.latLngBounds(nextSw, nextNe);
    }

    function setRadarOpacity(value) {
      radarOpacity = value;
      if (radarLayer && radarLayer.setOpacity) {
        radarLayer.setOpacity(value);
      }
    }

    function applyRadarTime(value) {
      radarTime = value || "";
      if (radarLayer && radarLayer.setParams && radarTime) {
        radarLayer.setParams({ time: radarTime });
        if (radarLayer.redraw) {
          radarLayer.redraw();
        }
      }
    }

    function updateChartsZoomVisibility() {
      if (!map || !chartsOverlay) return;
      var zoom = map.getZoom();
      if (chartsWanted && zoom <= chartsZoomThreshold) {
        if (map.hasLayer(chartsOverlay)) {
          map.removeLayer(chartsOverlay);
        }
        chartsVisible = false;
        if (chartsZoomNoteControl) chartsZoomNoteControl.setVisible(true);
      } else if (chartsWanted && zoom > chartsZoomThreshold) {
        if (!map.hasLayer(chartsOverlay)) {
          chartsOverlay.addTo(map);
        }
        chartsVisible = true;
        if (chartsZoomNoteControl) chartsZoomNoteControl.setVisible(false);
      } else {
        if (map.hasLayer(chartsOverlay)) {
          map.removeLayer(chartsOverlay);
        }
        chartsVisible = false;
        if (chartsZoomNoteControl) chartsZoomNoteControl.setVisible(false);
      }
    }

    function ensureRadarCoverageBounds() {
      if (radarCoverageBounds || !map || !window.L) return;
      var crs = map.options.crs;
      var sw = crs.unproject(window.L.point(radarCoverageBbox3857.minx, radarCoverageBbox3857.miny));
      var ne = crs.unproject(window.L.point(radarCoverageBbox3857.maxx, radarCoverageBbox3857.maxy));
      radarCoverageBounds = window.L.latLngBounds(sw, ne);
    }

    function updateRadarVisibility() {
      if (!map || !radarLayer) return;
      ensureRadarCoverageBounds();
      var inCoverage = false;
      if (radarCoverageBounds) {
        var viewBounds = map.getBounds();
        var paddedView = expandBounds(viewBounds, 0.5);
        inCoverage = radarCoverageBounds.intersects(paddedView);
      }

      if (radarWanted && inCoverage) {
        if (!map.hasLayer(radarLayer)) {
          suppressRadarToggle = true;
          radarLayer.addTo(map);
          suppressRadarToggle = false;
        }
        radarVisible = true;
        if (radarNoteControl) radarNoteControl.setVisible(false);
        if (radarOpacityControl) radarOpacityControl.setEnabled(true);
      } else if (radarWanted && !inCoverage) {
        if (map.hasLayer(radarLayer)) {
          suppressRadarToggle = true;
          map.removeLayer(radarLayer);
          suppressRadarToggle = false;
        }
        radarVisible = false;
        if (radarNoteControl) radarNoteControl.setVisible(true);
        if (radarOpacityControl) radarOpacityControl.setEnabled(false);
      } else {
        if (map.hasLayer(radarLayer)) {
          suppressRadarToggle = true;
          map.removeLayer(radarLayer);
          suppressRadarToggle = false;
        }
        radarVisible = false;
        if (radarNoteControl) radarNoteControl.setVisible(false);
        if (radarOpacityControl) radarOpacityControl.setEnabled(false);
      }
    }

    function fetchRadarTime() {
      var url = radarWmsUrl + "&SERVICE=WMS&REQUEST=GetCapabilities&VERSION=1.3.0";
      return fetch(url, { credentials: "same-origin" })
        .then(function (res) { return res.text(); })
        .then(function (text) {
          var latest = "";
          try {
            var parser = new window.DOMParser();
            var xmlDoc = parser.parseFromString(text, "text/xml");
            var dimensions = xmlDoc.getElementsByTagName("Dimension");
            for (var i = 0; i < dimensions.length; i++) {
              var dim = dimensions[i];
              if (dim.getAttribute("name") === "time") {
                latest = dim.textContent || "";
                break;
              }
            }
          } catch (err) {
            latest = "";
          }
          if (!latest) return;
          var parts = latest.split("/");
          var value = parts.length > 1 ? parts[1] : parts[0];
          if (value) {
            applyRadarTime(value.trim());
          }
        })
        .catch(function () { /* Ignore radar time fetch errors. */ });
    }

    function buildMap(center) {
      if (!window.L || !mapEl) {
        return null;
      }

      mapEl.innerHTML = "";

      map = window.L.map(mapEl, {
        zoomControl: true,
        attributionControl: true
      });

      var osmLayer = window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "\u00A9 OpenStreetMap contributors"
      }).addTo(map);

      chartsOverlay = window.L.tileLayer.wms(chartWmsUrl, {
        layers: chartLayerNames,
        format: "image/png",
        transparent: true,
        version: "1.3.0",
        attribution: "NOAA"
      });

      radarLayer = window.L.tileLayer.wms(radarWmsUrl, {
        layers: radarLayerName,
        styles: "",
        format: "image/png",
        transparent: true,
        version: "1.3.0",
        crs: window.L.CRS.EPSG3857,
        opacity: radarOpacity
      });
      if (radarTime) {
        radarLayer.setParams({ time: radarTime });
      }

      var baseLayers = {
        "OpenStreetMap": osmLayer
      };
      var overlays = {
        "NOAA Nautical Charts": chartsOverlay,
        "NOAA/NWS Radar": radarLayer
      };

      layersControl = window.L.control.layers(baseLayers, overlays, { collapsed: false }).addTo(map);
      window.L.control.scale({ imperial: true, metric: false }).addTo(map);

      radarOpacityControl = createRadarOpacityControl(setRadarOpacity);
      if (radarOpacityControl) {
        radarOpacityControl.addTo(map);
        radarOpacityControl.setEnabled(false);
      }
      radarNoteControl = createRadarNoteControl();
      if (radarNoteControl) {
        radarNoteControl.addTo(map);
        radarNoteControl.setVisible(false);
      }
      chartsZoomNoteControl = createChartsZoomNoteControl();
      if (chartsZoomNoteControl) {
        chartsZoomNoteControl.addTo(map);
        chartsZoomNoteControl.setVisible(false);
      }

      map.on("overlayadd", function (event) {
        if (event.layer === radarLayer) {
          if (suppressRadarToggle) return;
          radarWanted = true;
          if (radarTime) {
            applyRadarTime(radarTime);
          } else {
            fetchRadarTime();
          }
          updateRadarVisibility();
        }
      });
      map.on("overlayremove", function (event) {
        if (event.layer === radarLayer) {
          if (suppressRadarToggle) return;
          radarWanted = false;
          updateRadarVisibility();
        }
      });

      map.on("overlayadd", function (event) {
        if (event.layer === chartsOverlay) {
          chartsWanted = true;
          updateChartsZoomVisibility();
        }
      });
      map.on("overlayremove", function (event) {
        if (event.layer === chartsOverlay) {
          chartsWanted = false;
          updateChartsZoomVisibility();
        }
      });

      map.on("click", function (event) {
        if (!event || !event.latlng || !onMapClick) return;
        onMapClick(event.latlng.lat, event.latlng.lng);
      });

      map.on("moveend", function () {
        updateRadarVisibility();
        if (onMoveEnd) onMoveEnd();
      });
      map.on("zoomend", function () {
        updateChartsZoomVisibility();
        updateRadarVisibility();
      });

      map.setView([center.lat, center.lng], defaultZoom);
      map.whenReady(function () {
        fetchRadarTime();
        updateChartsZoomVisibility();
        updateRadarVisibility();
        if (onMapReady) onMapReady(map);
      });

      return map;
    }

    function destroyMap() {
      if (!map) return;
      map.off();
      map.remove();
      map = null;
      waypointMarker = null;
      homePortMarker = null;
      layersControl = null;
      radarLayer = null;
      radarOpacityControl = null;
      radarNoteControl = null;
      radarCoverageBounds = null;
      radarWanted = false;
      radarVisible = false;
      chartsOverlay = null;
      chartsWanted = false;
      chartsVisible = false;
      chartsZoomNoteControl = null;
      if (onMapDestroy) onMapDestroy();
    }

    function ensureMap() {
      if (!map) {
        buildMap((pendingContext && pendingContext.center) || defaultCenter);
      }
      applyContext(pendingContext);
      if (map) {
        setTimeout(function () {
          map.invalidateSize();
        }, 0);
      }
    }

    function applyContext(context) {
      if (!map || !context) return;
      if (context.center) {
        map.setView([context.center.lat, context.center.lng], context.zoom || defaultZoom);
      }
      if (context.homePort) {
        setHomePortMarker(context.homePort.lat, context.homePort.lng);
      } else {
        clearHomePortMarker();
      }
      if (context.waypoint) {
        setWaypointMarker(context.waypoint.lat, context.waypoint.lng);
      } else {
        clearWaypointMarker();
      }
    }

    function clearWaypointMarker() {
      if (!waypointMarker) return;
      waypointMarker.remove();
      waypointMarker = null;
    }

    function clearHomePortMarker() {
      if (!homePortMarker) return;
      homePortMarker.remove();
      homePortMarker = null;
    }

    function setWaypointMarker(lat, lng) {
      if (!map || !window.L) return;
      var icon = createLetterIcon("W", "#1e88e5", 26);
      if (!waypointMarker) {
        waypointMarker = window.L.marker([lat, lng], {
          draggable: true,
          icon: icon
        }).addTo(map);
        waypointMarker.on("dragend", function (event) {
          if (!event || !event.target) return;
          var next = event.target.getLatLng();
          if (onMarkerDragEnd) onMarkerDragEnd(next.lat, next.lng);
        });
      } else {
        waypointMarker.setLatLng([lat, lng]);
        if (waypointMarker.setIcon && icon) waypointMarker.setIcon(icon);
        if (!map.hasLayer(waypointMarker)) {
          waypointMarker.addTo(map);
        }
      }
    }

    function setHomePortMarker(lat, lng) {
      if (!map || !window.L) return;
      var icon = createLetterIcon("H", "#2e7d32", 24);
      if (!homePortMarker) {
        homePortMarker = window.L.marker([lat, lng], { icon: icon }).addTo(map);
      } else {
        homePortMarker.setLatLng([lat, lng]);
        if (homePortMarker.setIcon && icon) homePortMarker.setIcon(icon);
        if (!map.hasLayer(homePortMarker)) {
          homePortMarker.addTo(map);
        }
      }
    }

    function setContext(context) {
      pendingContext = context || null;
      if (map) {
        applyContext(pendingContext);
      }
    }

    if (modalEl && !modalEl.dataset.leafletWaypointMapBound) {
      modalEl.addEventListener("shown.bs.modal", function () {
        ensureMap();
      });
      modalEl.addEventListener("hidden.bs.modal", function () {
        destroyMap();
      });
      modalEl.dataset.leafletWaypointMapBound = "true";
    }

    return {
      getMap: function () {
        return map;
      },
      setContext: setContext,
      setWaypointMarker: setWaypointMarker,
      setHomePortMarker: setHomePortMarker,
      destroy: destroyMap
    };
  };
})(window, document);
