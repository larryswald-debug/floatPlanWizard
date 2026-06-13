(function (window, document) {
  "use strict";

  var state = {
    slug: "",
    token: "",
    streamId: 0,
    source: "",
    pageContext: {},
    mapInstance: null
  };

  var dom = {};

  function toInt(value, fallback) {
    var n = parseInt(value, 10);
    return Number.isFinite(n) ? n : (fallback || 0);
  }

  function readPageContext() {
    var el = document.getElementById("followFullMapContext");
    var parsed;
    if (!el) return {};
    try {
      parsed = JSON.parse(el.textContent || "{}");
    } catch (err) {
      return {};
    }
    return parsed && typeof parsed === "object" ? parsed : {};
  }

  function getBasePath() {
    return window.FPW_BASE || state.pageContext.fpwBase || "";
  }

  function apiUrl(action) {
    return getBasePath() + "/api/v1/voyage.cfc?method=handle&action=" + encodeURIComponent(action) + "&returnFormat=json";
  }

  function readSlugTokenFromUrl() {
    var params = new URLSearchParams(window.location.search || "");
    return {
      slug: String(params.get("slug") || "").trim(),
      token: String(params.get("t") || "").trim(),
      streamId: toInt(params.get("stream_id"), 0),
      source: String(params.get("source") || "").trim()
    };
  }

  function buildFollowFallbackUrl() {
    var params = new URLSearchParams();

    if (state.slug) {
      params.set("slug", state.slug);
    }
    if (state.token) {
      params.set("t", state.token);
    }
    if (state.streamId > 0) {
      params.set("stream_id", String(state.streamId));
    }

    return window.location.origin + getBasePath() + "/app/follow.cfm" + (params.toString() ? ("?" + params.toString()) : "");
  }

  function fetchJson(action, payload) {
    return fetch(apiUrl(action), {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json; charset=utf-8"
      },
      body: JSON.stringify(payload || {})
    })
      .then(function (res) { return res.text(); })
      .then(function (txt) {
        var json;
        try {
          json = txt ? JSON.parse(txt) : {};
        } catch (err) {
          throw new Error("Non-JSON response from voyage API.");
        }
        if (!json || json.SUCCESS === false) {
          var msg = (json && json.ERROR && json.ERROR.MESSAGE) || json.MESSAGE || "Unable to load full map.";
          throw new Error(msg);
        }
        return json;
      });
  }

  function maximizeWindow() {
    try {
      window.moveTo(0, 0);
      window.resizeTo(
        window.screen && window.screen.availWidth ? window.screen.availWidth : window.outerWidth,
        window.screen && window.screen.availHeight ? window.screen.availHeight : window.outerHeight
      );
      window.focus();
    } catch (err) {
      return;
    }
  }

  function syncMapSize() {
    if (!state.mapInstance || typeof state.mapInstance.invalidateSize !== "function") return;
    window.setTimeout(function () {
      state.mapInstance.invalidateSize();
    }, 0);
  }

  function setStatus(message) {
    if (!dom.statusEl) return;
    dom.statusEl.textContent = String(message || "").trim() || "Preparing the live route map.";
  }

  function setTitles(title, subtitle) {
    if (dom.titleEl) {
      dom.titleEl.textContent = String(title || "").trim() || "Live route map";
    }
    if (dom.subtitleEl) {
      dom.subtitleEl.textContent = String(subtitle || "").trim() || "Viewing the current Follow route in a dedicated window.";
    }
  }

  function renderMap(payloadMap) {
    var api = window.FPWFollowMap;
    var mapData = (payloadMap && typeof payloadMap === "object") ? payloadMap : {};
    var routeGeo = mapData.routeGeo || {};
    var pins = Array.isArray(mapData.pins) ? mapData.pins : [];
    var current = (mapData.current && typeof mapData.current === "object") ? mapData.current : {};

    if (!api || typeof api.initFollowMap !== "function") {
      throw new Error("Follow map renderer is unavailable.");
    }

    state.mapInstance = api.initFollowMap("followFullMap", {});
    if (
      state.source === "active-cruise" &&
      window.FPW &&
      typeof window.FPW.attachLeafletMarineLayers === "function"
    ) {
      window.FPW.attachLeafletMarineLayers({
        map: state.mapInstance,
        includeRadar: false
      });
      if (typeof window.FPW.attachLeafletWeatherOverlays === "function") {
        window.FPW.attachLeafletWeatherOverlays({
          map: state.mapInstance,
          mode: "activeCruise"
        });
      }
    }
    api.renderRoute(routeGeo);
    api.renderPins(pins);
    api.fitBoundsToRoute(routeGeo, pins);

    if (current.lat !== undefined && current.lng !== undefined) {
      api.updateBoatMarker(current.lat, current.lng, current.label || "Current position");
    }

    syncMapSize();
  }

  function closeWindow() {
    try {
      window.close();
    } catch (err) {}

    window.setTimeout(function () {
      if (dom.backLink) {
        dom.backLink.focus();
      }
    }, 150);
  }

  function handleBackLinkClick(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
    closeWindow();
  }

  function bindUi() {
    dom.titleEl = document.getElementById("followFullMapTitle");
    dom.subtitleEl = document.getElementById("followFullMapSubtitle");
    dom.statusEl = document.getElementById("followFullMapStatus");
    dom.closeBtn = document.getElementById("closeFullMapBtn");
    dom.backLink = document.getElementById("backToFollowPageLink");

    if (dom.closeBtn) {
      dom.closeBtn.addEventListener("click", closeWindow);
    }
    if (dom.backLink) {
      dom.backLink.addEventListener("click", handleBackLinkClick);
    }

    window.addEventListener("resize", syncMapSize);
    window.addEventListener("load", function () {
      maximizeWindow();
      syncMapSize();
    });
  }

  function bootstrap() {
    setStatus("Loading the current Follow map.");
    return fetchJson("getStreamBootstrap", {
      slug: state.slug,
      stream_id: state.streamId,
      t: state.token
    }).then(function (res) {
      var stream = (res.stream && typeof res.stream === "object") ? res.stream : {};
      var topCards = (res.topCards && typeof res.topCards === "object") ? res.topCards : {};
      var nextStop = String(topCards.next_stop || "").trim();

      state.streamId = toInt(stream.id || stream.stream_id || state.streamId, state.streamId);
      state.slug = String(stream.slug || state.slug || "").trim();

      if (dom.backLink) {
        dom.backLink.href = buildFollowFallbackUrl();
      }

      setTitles(
        String(stream.title || "").trim() || "Live route map",
        nextStop ? ("Next stop: " + nextStop) : "Viewing the current Follow route in a dedicated window."
      );
      renderMap(res.map || {});
      setStatus("Close this window with the X above, or use Back to Follow Page.");
      return res;
    });
  }

  function init() {
    var route = readSlugTokenFromUrl();

    state.pageContext = readPageContext();
    state.slug = route.slug;
    state.token = route.token;
    state.streamId = route.streamId;
    state.source = route.source;

    bindUi();

    if (dom.backLink) {
      dom.backLink.href = buildFollowFallbackUrl();
    }

    bootstrap().catch(function (err) {
      var message = (err && err.message) ? err.message : "Unable to load full map.";
      setTitles("Unable to load map", "Use the link below to return to the Follow page.");
      setStatus(message);
    });
  }

  document.addEventListener("DOMContentLoaded", init);
})(window, document);
