// /fpw/assets/js/app/api.js
(function () {
  "use strict";

  console.log("api.js loaded OK");

  var API_BASE = "/fpw/api/v1";

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

    return fetch(API_BASE + path, fetchOptions)
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
      return request("/auth.cfm", {
        method: "POST",
        body: { action: "login", email: email, password: password }
      });
    },

    logout: function () {
      return request("/auth.cfm", {
        method: "POST",
        body: { action: "logout" }
      });
    },

    getCurrentUser: function () {
      return request("/me.cfm", { method: "GET" });
    }
  };

  console.log("Api methods:", Object.keys(window.Api));
})();
