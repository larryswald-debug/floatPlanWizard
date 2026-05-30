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
  var invalidLinkMessage = "This reset link is invalid or has expired. Please request a new password reset.";

  function getResetToken() {
    var params = new URLSearchParams(window.location.search || "");
    return (params.get("token") || "").trim();
  }

  function setFormEnabled(enabled) {
    var newPasswordEl = $("newPassword");
    var confirmPasswordEl = $("confirmPassword");
    var btn = $("resetBtn");

    if (newPasswordEl) newPasswordEl.disabled = !enabled;
    if (confirmPasswordEl) confirmPasswordEl.disabled = !enabled;
    if (btn) btn.disabled = !enabled;
  }

  document.addEventListener("DOMContentLoaded", function () {
    var form = $("resetForm");
    var newPasswordEl = $("newPassword");
    var confirmPasswordEl = $("confirmPassword");
    var btn = $("resetBtn");
    var token = getResetToken();

    if (!form || !newPasswordEl || !confirmPasswordEl || !btn) {
      console.error("reset-password.js: required elements missing", {
        resetForm: !!form,
        newPassword: !!newPasswordEl,
        confirmPassword: !!confirmPasswordEl,
        resetBtn: !!btn
      });
      return;
    }

    if (!token) {
      setFormEnabled(false);
      showAlert(invalidLinkMessage, "danger");
      return;
    }

    fetchJson(API_BASE + "/password_reset.cfc?method=handle", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "validate",
        token: token
      })
    }).catch(function (err) {
      setFormEnabled(false);
      showAlert((err && err.MESSAGE) ? err.MESSAGE : invalidLinkMessage, "danger");
    });

    form.addEventListener("submit", async function (evt) {
      evt.preventDefault();

      var newPassword = (newPasswordEl.value || "").trim();
      var confirmPassword = (confirmPasswordEl.value || "").trim();

      if (!token) {
        showAlert(invalidLinkMessage, "danger");
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

      btn.disabled = true;
      btn.textContent = "Updating...";

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

        showAlert(data.MESSAGE || "Your password has been reset. You can now sign in.", "success");

        setTimeout(function () {
          window.location.href = BASE_PATH + "/app/login.cfm";
        }, 1200);

      } catch (err) {
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Reset failed.", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Update Password";
      }
    });
  });

})(window, document);
