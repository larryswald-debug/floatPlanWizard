// /fpw/assets/js/app/api.js
(function () {
  "use strict";

  console.log("api.js loaded OK");

  // Compute API base dynamically. If the app is served under a first
  // path segment (e.g. "/fpw"), use that. Allow an explicit override
  // via `window.FPW_API_BASE` for environments where detection fails.
  var API_BASE = (function () {
    if (window.FPW_API_BASE) return window.FPW_API_BASE;
    var firstSegment = (window.location.pathname.split('/')[1] || "");
    var prefix = firstSegment ? "/" + firstSegment : "";
    return prefix + "/api/v1";
  })();

  function request(path, options) {
    options = options || {};

    var headers = options.headers || {};
    headers["Content-Type"] = "application/json";

    var fetchOptions = {
      method: options.method || "GET",
      headers: headers,
      credentials: "include"
    };

    if (options.body !== undefined && options.body !== null) {
      fetchOptions.body = JSON.stringify(options.body);
    }

    // If calling a CFC without an explicit returnFormat, request JSON
    var fullPath = API_BASE + path;
    if (/\.cfc(\?|$)/i.test(fullPath) && !/returnformat=/i.test(fullPath)) {
      fullPath += (fullPath.indexOf('?') === -1 ? '?' : '&') + 'returnFormat=json';
    }

    return fetch(fullPath, fetchOptions)
      .then(function (res) {
        return res.text().then(function (txt) {
          var data;
          try {
            data = txt ? JSON.parse(txt) : {};
          } catch (e) {
            data = { SUCCESS: false, MESSAGE: "Non-JSON response from API", RAW: txt };
          }

          if (!res.ok || data.SUCCESS === false) {
            data.status = res.status;
            throw data;
          }
          return data;
        });
      });
  }

  window.Api = {
    login: function (email, password) {
      return request("/auth.cfc?method=handle", {
        method: "POST",
        body: { action: "login", email: email, password: password }
      });
    },

    logout: function () {
      return request("/auth.cfc?method=handle", {
        method: "POST",
        body: { action: "logout" }
      });
    },

    getCurrentUser: function () {
      return request("/me.cfc?method=handle", { method: "GET" });
    },

    getFloatPlans: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/floatplans.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getFloatPlanBootstrap: function (floatPlanId) {
      var path = "/floatplan.cfc?method=handle&action=bootstrap";
      if (floatPlanId) {
        path += "&id=" + encodeURIComponent(floatPlanId);
      }
      return request(path, { method: "GET" });
    },

    saveFloatPlan: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deleteFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          floatPlanId: floatPlanId
        }
      });
    },

    cloneFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "clone",
          floatPlanId: floatPlanId
        }
      });
    }
  };

  console.log("Api methods:", Object.keys(window.Api));
})();
