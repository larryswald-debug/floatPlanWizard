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
    var passwordEl = $("password");
    var confirmPasswordEl = $("confirmPassword");
    var addressEl = $("address");
    var cityEl = $("city");
    var stateEl = $("state");
    var zipEl = $("zip");
    var phoneEl = $("phone");
    var websiteEl = $("website");
    var termsAcceptedEl = $("termsAccepted");
    var btn = $("joinButton");

    if (!form || !firstNameEl || !lastNameEl || !emailEl || !passwordEl || !confirmPasswordEl || !termsAcceptedEl || !btn) {
      console.error("join.js: required elements missing", {
        joinForm: !!form,
        firstName: !!firstNameEl,
        lastName: !!lastNameEl,
        email: !!emailEl,
        password: !!passwordEl,
        confirmPassword: !!confirmPasswordEl,
        termsAccepted: !!termsAcceptedEl,
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
      var password = passwordEl.value || "";
      var confirmPassword = confirmPasswordEl.value || "";
      var address = addressEl ? (addressEl.value || "").trim() : "";
      var city = cityEl ? (cityEl.value || "").trim() : "";
      var state = stateEl ? (stateEl.value || "").trim() : "";
      var zip = zipEl ? (zipEl.value || "").trim() : "";
      var phone = phoneEl ? (phoneEl.value || "").trim() : "";
      var website = websiteEl ? (websiteEl.value || "").trim() : "";
      var termsAccepted = !!termsAcceptedEl.checked;

      if (!firstName || !lastName || !email) {
        showAlert("First name, last name, and email are required.", "warning");
        return;
      }

      if (!password) {
        showAlert("Password is required.", "warning");
        return;
      }

      if (password.length < 8) {
        showAlert("Password must be at least 8 characters.", "warning");
        return;
      }

      if (!confirmPassword || password !== confirmPassword) {
        showAlert("Password and confirmation do not match.", "warning");
        return;
      }

      if (!termsAccepted) {
        showAlert("Agree to the Terms of Service and Privacy Policy to continue.", "warning");
        return;
      }

      btn.disabled = true;
      btn.textContent = "Creating...";

      try {
        var payload = {
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          termsAccepted: true,
          address: address,
          city: city,
          state: state,
          zip: zip,
          phone: phone,
          website: website
        };

        var data = await fetchJson(API_BASE + "/join.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });

        var msg = (data && data.MESSAGE) ? data.MESSAGE : "User created.";
        var redirectUrl = data && (data.redirectUrl || data.REDIRECT_URL);

        showAlert(msg, "success");
        if (redirectUrl) {
          window.location.href = redirectUrl;
          return;
        }
        form.reset();
      } catch (err) {
        console.error("join error:", err);
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Request failed (see console).", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Create Account";
      }
    });
  });

})(window, document);
