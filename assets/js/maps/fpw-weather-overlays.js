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

  function weatherWmsUrl(target) {
    return getFpwApiBase() + "/wmsProxy.cfc?method=tile&target=" + encodeURIComponent(target);
  }

  var overlayRegistry = {
    radar: {
      label: "NOAA/NWS Radar",
      target: "nws-radar",
      layers: "radar_base_reflectivity_time",
      styles: "",
      opacity: 0.6,
      attribution: "NOAA/NWS",
      modes: { weather: true, activeCruise: false }
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
      layers: "satellite:goes_visible_imagery",
      styles: "",
      opacity: 0.48,
      attribution: "NOAA nowCOAST",
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

  function createWmsOverlay(definition) {
    if (!window.L || !definition) return null;
    return window.L.tileLayer.wms(weatherWmsUrl(definition.target), {
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
