(function (window, document) {
  "use strict";

  var AuthUtils = window.FPW && window.FPW.AuthUtils;
  if (!AuthUtils) {
    console.error("join.js: auth-utils not loaded");
    return;
  }

  var $ = AuthUtils.$;
  var API_BASE = AuthUtils.API_BASE;
  var showAlert = function (message, type) {
    AuthUtils.showAlert("joinAlert", message, type);
  };
  var clearAlert = function () {
    AuthUtils.clearAlert("joinAlert");
  };
  var fetchJson = AuthUtils.fetchJson;

  document.addEventListener("DOMContentLoaded", function () {
    var form = $("joinForm");
    var firstNameEl = $("firstName");
    var lastNameEl = $("lastName");
    var emailEl = $("email");
    var addressEl = $("address");
    var cityEl = $("city");
    var stateEl = $("state");
    var zipEl = $("zip");
    var phoneEl = $("phone");
    var btn = $("joinButton");

    if (!form || !firstNameEl || !lastNameEl || !emailEl || !btn) {
      console.error("join.js: required elements missing", {
        joinForm: !!form,
        firstName: !!firstNameEl,
        lastName: !!lastNameEl,
        email: !!emailEl,
        joinButton: !!btn
      });
      return;
    }

    form.addEventListener("submit", async function (evt) {
      evt.preventDefault();
      clearAlert();

      var firstName = (firstNameEl.value || "").trim();
      var lastName = (lastNameEl.value || "").trim();
      var email = (emailEl.value || "").trim();
      var address = addressEl ? (addressEl.value || "").trim() : "";
      var city = cityEl ? (cityEl.value || "").trim() : "";
      var state = stateEl ? (stateEl.value || "").trim() : "";
      var zip = zipEl ? (zipEl.value || "").trim() : "";
      var phone = phoneEl ? (phoneEl.value || "").trim() : "";

      if (!firstName || !lastName || !email) {
        showAlert("First name, last name, and email are required.", "warning");
        return;
      }

      btn.disabled = true;
      btn.textContent = "Creating...";

      try {
        var payload = {
          firstName: firstName,
          lastName: lastName,
          email: email,
          address: address,
          city: city,
          state: state,
          zip: zip,
          phone: phone
        };

        var data = await fetchJson(API_BASE + "/join.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });

        var msg = (data && data.MESSAGE) ? data.MESSAGE : "User created.";
        if (data && data.TEMP_PASSWORD) {
          msg += " Default password: " + data.TEMP_PASSWORD;
        }

        showAlert(msg, "success");
        form.reset();
      } catch (err) {
        console.error("join error:", err);
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Request failed (see console).", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Create User";
      }
    });
  });

})(window, document);
