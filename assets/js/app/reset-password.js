// /fpw/assets/js/app/reset-password.js
(function (window, document) {
  "use strict";

  function $(id) { return document.getElementById(id); }

  function showAlert(msg, type) {
    var el = $("rpAlert");
    el.classList.remove("d-none", "alert-success", "alert-danger", "alert-info", "alert-warning");
    el.classList.add("alert-" + (type || "info"));
    el.textContent = msg;
  }

  async function fetchJson(url, options) {
    options = options || {};
    options.credentials = "include";
    var res = await fetch(url, options);
    var txt = await res.text();
    var data;
    try { data = txt ? JSON.parse(txt) : {}; }
    catch (e) { throw { MESSAGE: "Non-JSON response", RAW: txt }; }
    if (!res.ok || data.SUCCESS === false) { throw data; }
    return data;
  }

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
        var data = await fetchJson("/fpw/api/v1/password_reset.cfm", {
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
          window.location.href = "/fpw/app/login.cfm";
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
