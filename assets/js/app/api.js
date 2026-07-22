// /fpw/assets/js/app/api.js
(function () {
  "use strict";

  console.log("api.js loaded OK");

  function normalizeBasePath(value) {
    if (!value) return "";
    var normalized = String(value).replace(/\/+$/, "");
    if (normalized === "/") return "";
    if (/^https?:\/\//i.test(normalized)) return normalized;
    return normalized.charAt(0) === "/" ? normalized : "/" + normalized;
  }

  function getScriptBasePath(fileName) {
    var script = document.currentScript;
    if (!script || !script.getAttribute) return "";

    var src = script.getAttribute("src") || "";
    if (!src) return "";

    var anchor = document.createElement("a");
    anchor.href = src;

    var scriptPath = anchor.pathname || src;
    var marker = "/assets/js/app/" + fileName;
    var markerIndex = scriptPath.toLowerCase().indexOf(marker.toLowerCase());

    if (markerIndex === -1) return "";
    return normalizeBasePath(scriptPath.slice(0, markerIndex));
  }

  function getLocationBasePath() {
    var basePath = window.location.pathname || "";
    basePath = basePath.replace(/[?#].*$/, "");
    basePath = basePath.replace(/\/api\/v1(\/.*)?$/i, "");
    basePath = basePath.replace(/\/(app|admin|assets|tests)(\/.*)?$/i, "");
    basePath = basePath.replace(/\/[^/]*\.(cfm|cfc)$/i, "");
    basePath = basePath.replace(/\/$/, "");
    return normalizeBasePath(basePath);
  }

  // Compute API base dynamically. Prefer the server-provided base values,
  // then derive the mount from this script path, then fall back to location.
  var API_BASE = (function () {
    var configuredApiBase = normalizeBasePath(window.FPW_API_BASE);
    if (configuredApiBase) return configuredApiBase;

    if (Object.prototype.hasOwnProperty.call(window, "FPW_BASE")) {
      return normalizeBasePath(window.FPW_BASE) + "/api/v1";
    }

    var scriptBasePath = getScriptBasePath("api.js");
    if (scriptBasePath) return scriptBasePath + "/api/v1";

    return getLocationBasePath() + "/api/v1";
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

    getCurrentMemberAccess: function () {
      return request("/me.cfc?method=handle", { method: "GET" });
    },

    createPremiumCheckoutSession: function (interval, floatPlanId) {
      var intervalValue = String(interval || "").trim().toLowerCase();
      var planId = parseInt(floatPlanId, 10) || 0;
      var body = { interval: intervalValue };
      if (intervalValue !== "monthly" && intervalValue !== "yearly" && intervalValue !== "three_day_pass" && intervalValue !== "one_trip") {
        return Promise.reject({
          SUCCESS: false,
          success: false,
          ERROR: "INVALID_PRICE_SELECTOR",
          errorCode: "INVALID_PRICE_SELECTOR",
          MESSAGE: "Choose monthly, yearly, one-trip, or 3-Day Pass Premium billing.",
          message: "Choose monthly, yearly, one-trip, or 3-Day Pass Premium billing."
        });
      }
      if (intervalValue === "one_trip" && planId > 0) {
        body.floatPlanId = planId;
      }
      return request("/billing.cfc?method=handle&action=createcheckoutsession", {
        method: "POST",
        body: body
      });
    },

    confirmPremiumOneTripCheckout: function (returnNonce) {
      var nonce = String(returnNonce || "").trim().toLowerCase();
      if (!/^[a-f0-9]{64}$/.test(nonce)) {
        return Promise.reject({
          SUCCESS: false,
          success: false,
          ERROR: "INVALID_CHECKOUT_CONFIRMATION",
          errorCode: "INVALID_CHECKOUT_CONFIRMATION",
          MESSAGE: "One-trip checkout confirmation is invalid.",
          message: "One-trip checkout confirmation is invalid."
        });
      }
      return request("/billing.cfc?method=handle&action=confirmonetripcheckout", {
        method: "POST",
        body: { returnNonce: nonce }
      });
    },

    createBillingPortalSession: function () {
      return request("/billing.cfc?method=handle&action=createportal", {
        method: "POST",
        body: {}
      });
    },

    validatePromoCode: function (code) {
      var codeValue = String(code || "").trim();
      if (!codeValue) {
        return Promise.reject({
          SUCCESS: false,
          success: false,
          ERROR: "CODE_REQUIRED",
          errorCode: "CODE_REQUIRED",
          MESSAGE: "Enter a promo code.",
          message: "Enter a promo code."
        });
      }
      return request("/promo.cfc?method=handle&action=validate", {
        method: "POST",
        body: { code: codeValue }
      });
    },

    redeemPromoCode: function (code) {
      var codeValue = String(code || "").trim();
      if (!codeValue) {
        return Promise.reject({
          SUCCESS: false,
          success: false,
          ERROR: "CODE_REQUIRED",
          errorCode: "CODE_REQUIRED",
          MESSAGE: "Enter a promo code.",
          message: "Enter a promo code."
        });
      }
      return request("/promo.cfc?method=handle&action=redeem", {
        method: "POST",
        body: { code: codeValue }
      });
    },

    startLaunchTrial: function () {
      return request("/promo.cfc?method=handle&action=startlaunchtrial", {
        method: "POST",
        body: {}
      });
    },

    getFloatPlans: function (options) {
      return listGet("floatplans", options);
    },

    getFloatPlanBootstrap: function (floatPlanId) {
      if (!(parseInt(floatPlanId, 10) > 0)) {
        return Promise.reject({
          MESSAGE: "New float plans must be created from a route."
        });
      }
      var path = "/floatplan.cfc?method=handle&action=bootstrap";
      path += "&id=" + encodeURIComponent(floatPlanId);
      return request(path, { method: "GET" });
    },

    suggestFloatPlanReturnTime: function (payload) {
      return request("/floatplan.cfc?method=handle&action=suggestReturnTime", {
        method: "POST",
        body: payload || {}
      });
    },

    getBasicFloatPlanDrafts: function () {
      return request("/floatplan.cfc?method=handle&action=listbasicdrafts", { method: "GET" });
    },

    getBasicFloatPlanCurrent: function () {
      return request("/floatplan.cfc?method=handle&action=getbasiccurrent", { method: "GET" });
    },

	    getBasicFloatPlanDraft: function (floatPlanId) {
	      var id = parseInt(floatPlanId, 10);
	      if (!(id > 0)) {
        return Promise.reject({
          MESSAGE: "Basic float plan draft id is required."
        });
      }
	      return request("/floatplan.cfc?method=handle&action=getbasicdraft&id=" + encodeURIComponent(id), { method: "GET" });
	    },

	    getBasicRescueAuthorities: function () {
	      return request("/floatplan.cfc?method=handle&action=getbasicrescueauthorities", { method: "GET" });
	    },

	    getBasicFloatPlanPdfDownloadUrl: function (floatPlanId) {
      var id = parseInt(floatPlanId, 10);
      if (!(id > 0)) {
        return "";
      }
      return API_BASE + "/floatplan.cfc?method=handle&action=downloadbasicpdf&id=" + encodeURIComponent(id);
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

    saveBasicFloatPlan: function (payload) {
      payload = payload || {};
      payload.action = "savebasic";
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

    sendBasicFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "sendbasic",
          floatPlanId: floatPlanId
        }
      });
    },

    closeBasicFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "closebasic",
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

    cancelFloatPlan: function (floatPlanId) {
      return request("/floatplan.cfc?method=handle", {
        method: "POST",
        body: {
          action: "cancel",
          floatPlanId: floatPlanId
        }
      });
    },

    submitFloatPlanCheckIn: function (payload) {
      return request("/floatplan.cfc?method=handle&action=checkin", {
        method: "POST",
        body: payload || {}
      });
    },

    completeActiveCruiseLeg: function (payload) {
      return request("/floatplan.cfc?method=handle&action=completeleg", {
        method: "POST",
        body: payload || {}
      });
    },

    startNextActiveCruiseLeg: function (payload) {
      return request("/floatplan.cfc?method=handle&action=startnextleg", {
        method: "POST",
        body: payload || {}
      });
    },

    addActiveCruiseDelay: function (payload) {
      return request("/floatplan.cfc?method=handle&action=adddelay", {
        method: "POST",
        body: payload || {}
      });
    },

    clearActiveCruiseDelay: function (payload) {
      return request("/floatplan.cfc?method=handle&action=cleardelay", {
        method: "POST",
        body: payload || {}
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
      return Promise.reject({
        MESSAGE: "Clone Float Plan is no longer supported."
      });
    },

    getFloatPlanPdfPreviewUrl: function (floatPlanId) {
      var id = parseInt(floatPlanId, 10);
      if (!(id > 0)) {
        return "";
      }
      return API_BASE + "/floatplan.cfc?method=handle&action=previewpdf&id=" + encodeURIComponent(id);
    }
  };

  console.log("Api methods:", Object.keys(window.Api));
})();
