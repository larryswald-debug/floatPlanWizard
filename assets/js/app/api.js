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

  function listGet(resourceName, options) {
    options = options || {};
    var params = [];

    if (options.limit) {
      params.push("limit=" + encodeURIComponent(options.limit));
    }

    var path = "/" + resourceName + ".cfc?method=handle";
    if (params.length) {
      path += (path.indexOf("?") === -1 ? "?" : "&") + params.join("&");
    }

    return request(path, { method: "GET" });
  }

  function postWithPayloadAction(path, payload, action) {
    payload = payload || {};
    payload.action = action;
    return request(path, {
      method: "POST",
      body: payload
    });
  }

  function postWithIdAction(path, action, idKey, idValue) {
    var body = { action: action };
    body[idKey] = idValue;
    return request(path, {
      method: "POST",
      body: body
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
      return listGet("floatplans", options);
    },

    getFloatPlanBootstrap: function (floatPlanId) {
      var path = "/floatplan.cfc?method=handle&action=bootstrap";
      if (floatPlanId) {
        path += "&id=" + encodeURIComponent(floatPlanId);
      }
      return request(path, { method: "GET" });
    },

    getVessels: function (options) {
      return listGet("vessels", options);
    },

    getContacts: function (options) {
      return listGet("contacts", options);
    },

    getPassengers: function (options) {
      return listGet("passengers", options);
    },

    getOperators: function (options) {
      return listGet("operators", options);
    },

    getWaypoints: function (options) {
      return listGet("waypoints", options);
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
      return postWithPayloadAction("/passenger.cfc?method=handle", payload, "save");
    },

    deletePassenger: function (passengerId) {
      return postWithIdAction("/passenger.cfc?method=handle", "delete", "passengerId", passengerId);
    },

    canDeletePassenger: function (passengerId) {
      return postWithIdAction("/passenger.cfc?method=handle", "candelete", "passengerId", passengerId);
    },

    saveOperator: function (payload) {
      return postWithPayloadAction("/operator.cfc?method=handle", payload, "save");
    },

    deleteOperator: function (operatorId) {
      return postWithIdAction("/operator.cfc?method=handle", "delete", "operatorId", operatorId);
    },

    canDeleteOperator: function (operatorId) {
      return postWithIdAction("/operator.cfc?method=handle", "candelete", "operatorId", operatorId);
    },

    saveWaypoint: function (payload) {
      return postWithPayloadAction("/waypoint.cfc?method=handle", payload, "save");
    },

    deleteWaypoint: function (waypointId) {
      return postWithIdAction("/waypoint.cfc?method=handle", "delete", "waypointId", waypointId);
    },

    canDeleteWaypoint: function (waypointId) {
      return postWithIdAction("/waypoint.cfc?method=handle", "candelete", "waypointId", waypointId);
    },

    saveVessel: function (payload) {
      return postWithPayloadAction("/vessel.cfc?method=handle", payload, "save");
    },

    deleteVessel: function (vesselId) {
      return postWithIdAction("/vessel.cfc?method=handle", "delete", "vesselId", vesselId);
    },

    canDeleteVessel: function (vesselId) {
      return postWithIdAction("/vessel.cfc?method=handle", "candelete", "vesselId", vesselId);
    },

    saveContact: function (payload) {
      return postWithPayloadAction("/contact.cfc?method=handle", payload, "save");
    },

    deleteContact: function (contactId) {
      return postWithIdAction("/contact.cfc?method=handle", "delete", "contactId", contactId);
    },

    canDeleteContact: function (contactId) {
      return postWithIdAction("/contact.cfc?method=handle", "candelete", "contactId", contactId);
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
