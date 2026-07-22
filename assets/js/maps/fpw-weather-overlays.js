(function (window) {
  "use strict";

  window.FPW = window.FPW || {};

  function getFpwApiBase() {
    var path = "";
    var marker = -1;

    if (window.FPW_API_BASE) {
      return String(window.FPW_API_BASE).replace(/\/+$/, "");
    }
    if (typeof window.FPW_BASE !== "undefined") {
      return String(window.FPW_BASE || "").replace(/\/+$/, "") + "/api/v1";
    }
    if (window.location && window.location.pathname) {
      path = String(window.location.pathname || "");
      marker = path.toLowerCase().indexOf("/app/");
      if (marker < 0) {
        marker = path.toLowerCase().indexOf("/admin/");
      }
      if (marker > 0) {
        return path.slice(0, marker).replace(/\/+$/, "") + "/api/v1";
      }
    }
    return "/api/v1";
  }

  var directNoaaWmsUrls = {
    "nws-radar": "https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer",
    "fpw-wind-forecast": "https://nowcoast.noaa.gov/geoserver/ows",
    "fpw-satellite": "https://nowcoast.noaa.gov/geoserver/ows",
    "fpw-surface-fronts": "https://mapservices.weather.noaa.gov/vector/services/outlooks/natl_fcst_wx_chart/MapServer/WMSServer",
    "fpw-wwa": "https://mapservices.weather.noaa.gov/eventdriven/services/WWA/watch_warn_adv/MapServer/WMSServer",
    "fpw-observed-wind": "https://mapservices.weather.noaa.gov/vector/services/obs/surface_obs/MapServer/WMSServer"
  };

  function weatherWmsUrl(target) {
    return directNoaaWmsUrls[target] || "";
  }

  var overlayRegistry = {
    radar: {
      label: "NOAA/NWS Radar",
      target: "nws-radar",
      layers: "radar_base_reflectivity_time",
      styles: "",
      opacity: 0.6,
      attribution: "NOAA/NWS",
      modes: { weather: true, activeCruise: true }
    },
    windForecast: {
      label: "Wind Forecast",
      target: "fpw-wind-forecast",
      layers: "ndfd_wind:wind_velocity",
      styles: "wind_arrows_from_uv",
      opacity: 0.78,
      attribution: "NOAA/NDFD",
      modes: { weather: true, activeCruise: true }
    },
    satellite: {
      label: "Cloud / Satellite",
      target: "fpw-satellite",
      layers: "satellite:global_longwave_imagery_mosaic",
      styles: "",
      opacity: 0.48,
      attribution: "NOAA nowCOAST",
      singleImage: true,
      modes: { weather: true, activeCruise: true }
    },
    surfaceFronts: {
      label: "Surface Fronts",
      target: "fpw-surface-fronts",
      layers: "34",
      styles: "",
      opacity: 0.82,
      attribution: "NOAA/NWS WPC",
      modes: { weather: true, activeCruise: true }
    },
    marineWarnings: {
      label: "Marine Warnings / WWA",
      target: "fpw-wwa",
      layers: "0,1",
      styles: "",
      opacity: 0.72,
      attribution: "NOAA/NWS",
      modes: { weather: true, activeCruise: true }
    }
  };

  function shouldIncludeOverlay(definition, mode) {
    var modes = definition && definition.modes ? definition.modes : {};
    return modes[mode] === true;
  }

  function buildSingleImageWmsUrl(url, definition, map) {
    var size = map.getSize();
    var bounds = map.getBounds();
    var crs = window.L.CRS.EPSG3857;
    var projectedSw = crs.project(bounds.getSouthWest());
    var projectedNe = crs.project(bounds.getNorthEast());
    var params = null;

    if (!size || size.x < 1 || size.y < 1) return "";

    params = {
      service: "WMS",
      request: "GetMap",
      layers: definition.layers,
      styles: definition.styles || "",
      format: "image/png",
      transparent: true,
      version: "1.3.0",
      width: Math.max(1, Math.round(size.x)),
      height: Math.max(1, Math.round(size.y)),
      crs: "EPSG:3857",
      bbox: [projectedSw.x, projectedSw.y, projectedNe.x, projectedNe.y].join(",")
    };

    return url + window.L.Util.getParamString(params, url);
  }

  function createSingleImageWmsOverlay(definition, url) {
    var SingleImageWmsOverlay = null;

    if (!window.L || !definition || !url || !window.L.Layer || !window.L.imageOverlay) return null;

    SingleImageWmsOverlay = window.L.Layer.extend({
      initialize: function () {
        this._map = null;
        this._imageLayer = null;
        this._pendingImageLayer = null;
        this._refreshHandler = this._refresh.bind(this);
      },

      onAdd: function (map) {
        this._map = map;
        this._refresh();
        map.on("moveend zoomend resize", this._refreshHandler, this);
      },

      onRemove: function (map) {
        map.off("moveend zoomend resize", this._refreshHandler, this);
        this._removeLayer(this._pendingImageLayer);
        this._removeLayer(this._imageLayer);
        this._pendingImageLayer = null;
        this._imageLayer = null;
        this._map = null;
      },

      getAttribution: function () {
        return definition.attribution || "NOAA";
      },

      _removeLayer: function (layer) {
        if (this._map && layer && this._map.hasLayer(layer)) {
          this._map.removeLayer(layer);
        }
      },

      _refresh: function () {
        var map = this._map;
        var imageUrl = "";
        var nextImageLayer = null;

        if (!map) return;
        imageUrl = buildSingleImageWmsUrl(url, definition, map);
        if (!imageUrl) return;

        this._removeLayer(this._pendingImageLayer);
        nextImageLayer = window.L.imageOverlay(imageUrl, map.getBounds(), {
          opacity: definition.opacity,
          interactive: false,
          attribution: definition.attribution || "NOAA"
        });
        this._pendingImageLayer = nextImageLayer;

        nextImageLayer.once("load", function () {
          if (this._pendingImageLayer !== nextImageLayer) {
            this._removeLayer(nextImageLayer);
            return;
          }
          this._removeLayer(this._imageLayer);
          this._imageLayer = nextImageLayer;
          this._pendingImageLayer = null;
        }, this);

        nextImageLayer.once("error", function () {
          if (this._pendingImageLayer === nextImageLayer) {
            this._pendingImageLayer = null;
          }
          this._removeLayer(nextImageLayer);
        }, this);

        nextImageLayer.addTo(map);
      }
    });

    return new SingleImageWmsOverlay();
  }

  function createWmsOverlay(definition) {
    var url = "";
    if (!window.L || !definition) return null;
    url = weatherWmsUrl(definition.target);
    if (!url) return null;
    if (definition.singleImage) return createSingleImageWmsOverlay(definition, url);
    return window.L.tileLayer.wms(url, {
      layers: definition.layers,
      styles: definition.styles || "",
      format: "image/png",
      transparent: true,
      version: "1.3.0",
      crs: window.L.CRS.EPSG3857,
      opacity: definition.opacity,
      attribution: definition.attribution || "NOAA"
    });
  }

  function resolveLayersControl(map) {
    if (map && map.__fpwMarineLayersController && typeof map.__fpwMarineLayersController.getLayersControl === "function") {
      return map.__fpwMarineLayersController.getLayersControl();
    }
    return null;
  }

  window.FPW.attachLeafletWeatherOverlays = function attachLeafletWeatherOverlays(options) {
    var settings = options || {};
    var map = settings.map || null;
    var mode = String(settings.mode || "weather").toLowerCase() === "activecruise" ? "activeCruise" : "weather";
    var layersControl = settings.layersControl || null;
    var layers = {};

    if (!map || !window.L || typeof map.addLayer !== "function") {
      return null;
    }
    if (map.__fpwWeatherOverlaysController) {
      return map.__fpwWeatherOverlaysController;
    }

    layersControl = layersControl || resolveLayersControl(map);
    if (!layersControl) {
      layersControl = window.L.control.layers({}, {}, { collapsed: false }).addTo(map);
    }

    Object.keys(overlayRegistry).forEach(function (key) {
      var definition = overlayRegistry[key];
      var layer = null;
      if (!shouldIncludeOverlay(definition, mode)) return;
      layer = createWmsOverlay(definition);
      if (!layer) return;
      layers[key] = layer;
      layersControl.addOverlay(layer, definition.label);
    });

    map.__fpwWeatherOverlaysController = {
      getLayersControl: function () {
        return layersControl;
      },
      getLayers: function () {
        return layers;
      },
      getRegistry: function () {
        return overlayRegistry;
      }
    };

    return map.__fpwWeatherOverlaysController;
  };
})(window);


