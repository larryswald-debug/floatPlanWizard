// Updated to launch the float plan wizard in a modal and refresh after save.
(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var modules = window.FPW.DashboardModules || {};

  var BASE_PATH = window.FPW_BASE || "";
  var FALLBACK_LOGIN_URL = BASE_PATH + "/app/login.cfm";

  function getLoginUrl() {
    if (window.AppAuth && window.AppAuth.loginUrl) {
      return window.AppAuth.loginUrl;
    }
    return FALLBACK_LOGIN_URL;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = getLoginUrl();
  }

  function populateUserInfo(user) {
    var nameEl = document.getElementById("userName");
    var emailEl = document.getElementById("userEmail");

    if (nameEl) {
      nameEl.textContent = (user && user.NAME) ? user.NAME : "";
    }

    if (emailEl) {
      emailEl.textContent = (user && user.EMAIL) ? user.EMAIL : "";
    }
  }

  function initDashboard() {
    if (utils.clearDashboardAlert) {
      utils.clearDashboardAlert();
    }
    if (utils.ensureConfirmModal) {
      utils.ensureConfirmModal();
    }
    if (utils.ensureAlertModal) {
      utils.ensureAlertModal();
    }

    if (modules.floatplans && modules.floatplans.init) {
      modules.floatplans.init();
    }
    if (modules.vessels && modules.vessels.init) {
      modules.vessels.init();
    }
    if (modules.contacts && modules.contacts.init) {
      modules.contacts.init();
    }
    if (modules.passengers && modules.passengers.init) {
      modules.passengers.init();
    }
    if (modules.operators && modules.operators.init) {
      modules.operators.init();
    }
    if (modules.waypoints && modules.waypoints.init) {
      modules.waypoints.init();
    }
    if (modules.alerts && modules.alerts.init) {
      modules.alerts.init();
    }

    Api.getCurrentUser()
      .then(function (data) {
        // data.SUCCESS already checked in Api.request
        if (utils.ensureAuthResponse && !utils.ensureAuthResponse(data)) {
          return;
        }

        if (!data.USER) {
          redirectToLogin();
          return;
        }

        populateUserInfo(data.USER);
        if (utils.resolveHomePortLatLng) {
          state.homePortLatLng = utils.resolveHomePortLatLng(data.USER);
        }

        var readyEvent = null;
        if (typeof Event === "function") {
          readyEvent = new Event("fpw:dashboard:user-ready");
        } else {
          readyEvent = document.createEvent("Event");
          readyEvent.initEvent("fpw:dashboard:user-ready", true, true);
        }
        document.dispatchEvent(readyEvent);
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        redirectToLogin();
      });

    // Wire up logout
    var logoutBtn = document.getElementById("logoutButton");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", function () {
        Api.logout()
          .catch(function (err) {
            console.error("Logout failed:", err);
            // Ignore errors, just send them to login
          })
          .finally(function () {
            redirectToLogin();
          });
      });
    }
  }

  window.FPW_DASHBOARD_VERSION = "20251227r";
  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
