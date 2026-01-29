(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  var utils = window.FPW.DashboardUtils || {};

  var confirmModalEl = null;
  var confirmModal = null;
  var confirmMessageEl = null;
  var confirmOkBtn = null;
  var confirmResolver = null;
  var alertModalEl = null;
  var alertModal = null;
  var alertMessageEl = null;

  function getNested(obj, path, fallback) {
    if (!obj) return fallback;
    var current = obj;
    for (var i = 0; i < path.length; i++) {
      var key = path[i];
      if (!current || current[key] === undefined || current[key] === null) {
        return fallback;
      }
      current = current[key];
    }
    return current;
  }

  function resolveHomePortLatLng(user) {
    var profile = getNested(user, ["PROFILE"], null) || getNested(user, ["profile"], null) || {};
    var homePort = getNested(profile, ["HOMEPORT"], null)
      || getNested(profile, ["homePort"], null)
      || getNested(user, ["HOMEPORT"], null)
      || getNested(user, ["homePort"], null)
      || {};
    var lat = getNested(homePort, ["LAT"], null) || getNested(homePort, ["lat"], null) || getNested(homePort, ["latitude"], null);
    var lng = getNested(homePort, ["LNG"], null) || getNested(homePort, ["lng"], null) || getNested(homePort, ["longitude"], null);
    if (lat !== undefined && lat !== null && lng !== undefined && lng !== null) {
      var latNum = parseFloat(lat);
      var lngNum = parseFloat(lng);
      if (!isNaN(latNum) && !isNaN(lngNum)) {
        return { lat: latNum, lng: lngNum };
      }
    }
    console.warn("Home Port lat/lng missing; using default for waypoint map.");
    return { lat: 28.2323, lng: -82.7418 };
  }

  function ensureAuthResponse(data) {
    return window.AppAuth ? window.AppAuth.ensureAuthenticated(data) : true;
  }

  function showDashboardAlert(message, type) {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;

    alertEl.textContent = message || "";
    alertEl.classList.remove("d-none", "alert-success", "alert-danger", "alert-warning", "alert-info");

    var alertType = type || "info";
    alertEl.classList.add("alert-" + alertType);

    if (!message) {
      alertEl.classList.add("d-none");
    }
  }

  function clearDashboardAlert() {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;
    alertEl.classList.add("d-none");
    alertEl.textContent = "";
  }

  function pick(obj, keys, fallback) {
    if (!obj) return fallback;
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (obj[key] !== undefined && obj[key] !== null && String(obj[key]).length) {
        return obj[key];
      }
    }
    return fallback;
  }

  function escapeHtml(value) {
    if (value === undefined || value === null) return "";
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatPlanDate(value) {
    if (!value) return "";
    var date = new Date(value);
    if (isNaN(date.getTime())) {
      return String(value);
    }
    var datePart = date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    var timePart = date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
    return datePart + " " + timePart;
  }

  function parsePlanDate(value) {
    if (!value) return 0;
    var date = new Date(value);
    var time = date.getTime();
    return isNaN(time) ? 0 : time;
  }

  function debounce(fn, delay) {
    var timerId = null;
    return function () {
      var args = arguments;
      if (timerId) {
        window.clearTimeout(timerId);
      }
      timerId = window.setTimeout(function () {
        timerId = null;
        fn.apply(null, args);
      }, delay);
    };
  }

  function normalizeSearch(value) {
    return String(value || "").trim().toLowerCase();
  }

  function ensureConfirmModal() {
    if (!confirmModalEl) {
      confirmModalEl = document.getElementById("confirmModal");
      if (confirmModalEl) {
        confirmMessageEl = confirmModalEl.querySelector("#confirmModalMessage");
        confirmOkBtn = confirmModalEl.querySelector("#confirmModalOk");
      }
    }

    if (confirmModalEl && !confirmModal && window.bootstrap && window.bootstrap.Modal) {
      confirmModal = new window.bootstrap.Modal(confirmModalEl);
    }

    if (confirmModalEl && !confirmModalEl.dataset.listenersAttached) {
      if (confirmOkBtn) {
        confirmOkBtn.addEventListener("click", function () {
          if (confirmResolver) {
            confirmResolver(true);
          }
          confirmResolver = null;
          if (confirmModal) {
            confirmModal.hide();
          }
        });
      }
      confirmModalEl.addEventListener("hidden.bs.modal", function () {
        if (confirmResolver) {
          confirmResolver(false);
          confirmResolver = null;
        }
      });
      confirmModalEl.dataset.listenersAttached = "true";
    }
  }

  function showConfirmModal(message) {
    ensureConfirmModal();
    if (!confirmModalEl || !confirmModal) {
      return Promise.resolve(window.confirm(message || "Are you sure?"));
    }
    if (confirmMessageEl) {
      confirmMessageEl.textContent = message || "Are you sure?";
    }
    confirmModalEl.style.zIndex = "2000";
    confirmModal.show();
    window.setTimeout(function () {
      var backdrops = document.querySelectorAll(".modal-backdrop");
      if (backdrops.length) {
        backdrops[backdrops.length - 1].style.zIndex = "1990";
      }
    }, 0);
    return new Promise(function (resolve) {
      confirmResolver = resolve;
    });
  }

  function ensureAlertModal() {
    if (!alertModalEl) {
      alertModalEl = document.getElementById("alertModal");
      if (alertModalEl) {
        alertMessageEl = alertModalEl.querySelector("#alertModalMessage");
      }
    }

    if (alertModalEl && !alertModal && window.bootstrap && window.bootstrap.Modal) {
      alertModal = new window.bootstrap.Modal(alertModalEl);
    }
  }

  function showAlertModal(message) {
    ensureAlertModal();
    if (!alertModalEl || !alertModal) {
      window.alert(message || "");
      return;
    }
    if (alertMessageEl) {
      alertMessageEl.textContent = message || "";
    }
    alertModalEl.style.zIndex = "2000";
    alertModal.show();
    window.setTimeout(function () {
      var backdrops = document.querySelectorAll(".modal-backdrop");
      if (backdrops.length) {
        backdrops[backdrops.length - 1].style.zIndex = "1990";
      }
    }, 0);
  }

  function setFieldError(inputEl, errorEl, message) {
    if (inputEl) {
      inputEl.classList.add("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = message || "";
    }
  }

  function clearFieldError(inputEl, errorEl) {
    if (inputEl) {
      inputEl.classList.remove("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = "";
    }
  }

  utils.getNested = getNested;
  utils.resolveHomePortLatLng = resolveHomePortLatLng;
  utils.ensureAuthResponse = ensureAuthResponse;
  utils.showDashboardAlert = showDashboardAlert;
  utils.clearDashboardAlert = clearDashboardAlert;
  utils.pick = pick;
  utils.escapeHtml = escapeHtml;
  utils.formatPlanDate = formatPlanDate;
  utils.parsePlanDate = parsePlanDate;
  utils.debounce = debounce;
  utils.normalizeSearch = normalizeSearch;
  utils.ensureConfirmModal = ensureConfirmModal;
  utils.showConfirmModal = showConfirmModal;
  utils.ensureAlertModal = ensureAlertModal;
  utils.showAlertModal = showAlertModal;
  utils.setFieldError = setFieldError;
  utils.clearFieldError = clearFieldError;

  window.FPW.DashboardUtils = utils;
})(window, document);
