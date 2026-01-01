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

      var chartLayer = window.L.tileLayer.wms(chartWmsUrl, {
        layers: chartLayerNames,
        format: "image/png",
        transparent: false,
        version: "1.3.0"
      }).addTo(map);

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
        "NOAA Nautical Chart": chartLayer
      };
      var overlays = {
        "nowCOAST Radar": radarLayer
      };

      layersControl = window.L.control.layers(baseLayers, overlays, { collapsed: false }).addTo(map);
      window.L.control.scale({ imperial: true, metric: false }).addTo(map);

      radarOpacityControl = createRadarOpacityControl(setRadarOpacity);
      if (radarOpacityControl) {
        radarOpacityControl.addTo(map);
        radarOpacityControl.setEnabled(false);
      }

      map.on("overlayadd", function (event) {
        if (radarOpacityControl && event.layer === radarLayer) {
          radarOpacityControl.setEnabled(true);
        }
        if (event.layer === radarLayer) {
          if (radarTime) {
            applyRadarTime(radarTime);
          } else {
            fetchRadarTime();
          }
        }
      });
      map.on("overlayremove", function (event) {
        if (radarOpacityControl && event.layer === radarLayer) {
          radarOpacityControl.setEnabled(false);
        }
      });

      map.on("click", function (event) {
        if (!event || !event.latlng || !onMapClick) return;
        onMapClick(event.latlng.lat, event.latlng.lng);
      });

      map.on("moveend", function () {
        if (onMoveEnd) onMoveEnd();
      });

      map.setView([center.lat, center.lng], defaultZoom);
      map.whenReady(function () {
        fetchRadarTime();
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
