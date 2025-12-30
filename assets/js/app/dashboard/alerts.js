(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  function initAlerts() {
    var listEl = document.getElementById("alertsList");
    var emptyEl = document.getElementById("alertsEmpty");
    if (!listEl && !emptyEl) return;
  }

  window.FPW.DashboardModules.alerts = {
    init: initAlerts
  };
})(window, document);
