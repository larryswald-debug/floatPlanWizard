(function (window, document) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var API_BASE = window.FPW_API_BASE || (BASE_PATH + "/api/v1");

  function $(id) { return document.getElementById(id); }

  function showAlert(alertId, message, type) {
    var el = $(alertId);
    if (!el) return;

    el.classList.remove("d-none", "alert-success", "alert-danger", "alert-info", "alert-warning");
    el.classList.add("alert-" + (type || "info"));
    el.textContent = message;
  }

  function clearAlert(alertId) {
    var el = $(alertId);
    if (!el) return;
    el.classList.add("d-none");
    el.textContent = "";
  }

  // Tries to pull a value from multiple possible key names
  function pick(obj, keys) {
    if (!obj) return null;
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (obj[k] !== undefined && obj[k] !== null && String(obj[k]).length) {
        return obj[k];
      }
    }
    return null;
  }

  async function fetchJson(url, options) {
    options = options || {};
    var strictSuccess = options.strictSuccess !== false;
    var res = await fetch(url, {
      method: options.method || "GET",
      headers: options.headers || {},
      body: options.body,
      credentials: "include"
    });

    var txt = await res.text();
    var data;
    try {
      data = txt ? JSON.parse(txt) : {};
    } catch (e) {
      throw { MESSAGE: "Non-JSON response from API", RAW: txt, status: res.status };
    }

    if (!res.ok || (strictSuccess && data.SUCCESS === false)) {
      data.status = res.status;
      throw data;
    }

    return data;
  }

  window.FPW = window.FPW || {};
  window.FPW.AuthUtils = {
    BASE_PATH: BASE_PATH,
    API_BASE: API_BASE,
    $: $,
    showAlert: showAlert,
    clearAlert: clearAlert,
    fetchJson: fetchJson,
    pick: pick
  };
})(window, document);
