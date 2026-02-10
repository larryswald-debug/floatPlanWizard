// /fpw/assets/js/app/reset-password.js
(function (window, document) {
  "use strict";

  var AuthUtils = window.FPW && window.FPW.AuthUtils;
  if (!AuthUtils) {
    console.error("reset-password.js: auth-utils not loaded");
    return;
  }

  var BASE_PATH = AuthUtils.BASE_PATH;
  var API_BASE = AuthUtils.API_BASE;
  var $ = AuthUtils.$;
  var showAlert = function (msg, type) {
    AuthUtils.showAlert("rpAlert", msg, type);
  };
  var fetchJson = AuthUtils.fetchJson;

  document.addEventListener("DOMContentLoaded", function () {
    $("resetForm").addEventListener("submit", async function (evt) {
      evt.preventDefault();

      var token = ($("token").value || "").trim();
      var newPassword = ($("newPassword").value || "").trim();
      var confirmPassword = ($("confirmPassword").value || "").trim();

      if (!token) {
        showAlert("Missing reset token. Please request a new reset link.", "danger");
        return;
      }
      if (newPassword.length < 8) {
        showAlert("Password must be at least 8 characters.", "warning");
        return;
      }
      if (newPassword !== confirmPassword) {
        showAlert("Passwords do not match.", "warning");
        return;
      }

      var btn = $("resetBtn");
      btn.disabled = true;
      btn.textContent = "Updating…";

      try {
        var data = await fetchJson(API_BASE + "/password_reset.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            action: "confirm",
            token: token,
            newPassword: newPassword
          })
        });

        showAlert(data.MESSAGE || "Password updated. Redirecting to sign in…", "success");

        setTimeout(function () {
          window.location.href = BASE_PATH + "/app/login.cfm";
        }, 900);

      } catch (err) {
        console.error(err);
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Reset failed.", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Update Password";
      }
    });
  });

})(window, document);
