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
  var API_ROOT = API_BASE.replace(/\/v1$/, "");

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

    getVessels: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/vessels.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getContacts: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/contacts.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getPassengers: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/passengers.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getOperators: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/operators.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getWaypoints: function (options) {
      options = options || {};
      var params = [];

      if (options.limit) {
        params.push("limit=" + encodeURIComponent(options.limit));
      }

      var path = "/waypoints.cfc?method=handle";
      if (params.length) {
        path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
      }

      return request(path, { method: "GET" });
    },

    getMarinePlaces: function (payload) {
      return request("/MarinePOI.cfc?method=getPlacesPOIs", {
        method: "POST",
        body: payload || {}
      });
    },

    getNavAids: function (payload) {
      return request("/NavAids.cfc?method=getNavAids", {
        method: "POST",
        body: payload || {}
      });
    },

    enrichPlace: function (payload) {
      return request("/PlacesEnrich.cfc?method=enrichPlace", {
        method: "POST",
        body: payload || {}
      });
    },

    savePassenger: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/passenger.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deletePassenger: function (passengerId) {
      return request("/passenger.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          passengerId: passengerId
        }
      });
    },

    canDeletePassenger: function (passengerId) {
      return request("/passenger.cfc?method=handle", {
        method: "POST",
        body: {
          action: "candelete",
          passengerId: passengerId
        }
      });
    },

    saveOperator: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/operator.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deleteOperator: function (operatorId) {
      return request("/operator.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          operatorId: operatorId
        }
      });
    },

    canDeleteOperator: function (operatorId) {
      return request("/operator.cfc?method=handle", {
        method: "POST",
        body: {
          action: "candelete",
          operatorId: operatorId
        }
      });
    },

    saveWaypoint: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/waypoint.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deleteWaypoint: function (waypointId) {
      return request("/waypoint.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          waypointId: waypointId
        }
      });
    },

    canDeleteWaypoint: function (waypointId) {
      return request("/waypoint.cfc?method=handle", {
        method: "POST",
        body: {
          action: "candelete",
          waypointId: waypointId
        }
      });
    },

    saveVessel: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/vessel.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deleteVessel: function (vesselId) {
      return request("/vessel.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          vesselId: vesselId
        }
      });
    },

    canDeleteVessel: function (vesselId) {
      return request("/vessel.cfc?method=handle", {
        method: "POST",
        body: {
          action: "candelete",
          vesselId: vesselId
        }
      });
    },

    saveContact: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/contact.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    deleteContact: function (contactId) {
      return request("/contact.cfc?method=handle", {
        method: "POST",
        body: {
          action: "delete",
          contactId: contactId
        }
      });
    },

    canDeleteContact: function (contactId) {
      return request("/contact.cfc?method=handle", {
        method: "POST",
        body: {
          action: "candelete",
          contactId: contactId
        }
      });
    },

    saveFloatPlan: function (payload) {
      payload = payload || {};
      payload.action = "save";
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: payload
      });
    },

    sendFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "send",
          floatPlanId: floatPlanId
        }
      });
    },

    checkInFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "checkin",
          floatPlanId: floatPlanId
        }
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
    },

    createFloatPlanPdf: function (floatPlanId) {
      var path = API_ROOT + "/api_assets/floatPlanUtils.cfc?method=createPDF&floatPlanId=" + encodeURIComponent(floatPlanId);
      return fetch(path, {
        method: "GET",
        credentials: "include"
      })
        .then(function (res) {
          return res.text().then(function (txt) {
            var trimmed = (txt || "").trim();
            if (!res.ok || !trimmed || trimmed.toLowerCase() === "false") {
              throw {
                MESSAGE: "Unable to generate float plan PDF.",
                status: res.status || 500,
                RAW: txt
              };
            }
            return trimmed;
          });
        });
    }
  };

  console.log("Api methods:", Object.keys(window.Api));
})();
