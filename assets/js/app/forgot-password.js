// /fpw/assets/js/app/forgot-password.js
(function (window, document) {
  "use strict";

  var AuthUtils = window.FPW && window.FPW.AuthUtils;
  if (!AuthUtils) {
    console.error("forgot-password.js: auth-utils not loaded");
    return;
  }

  var API_BASE = AuthUtils.API_BASE;
  var $ = AuthUtils.$;
  var showAlert = function (msg, type) {
    AuthUtils.showAlert("fpAlert", msg, type);
  };
  var fetchJson = AuthUtils.fetchJson;
  var genericSuccessMessage = "If an account exists for that email, we sent a password reset link.";

  document.addEventListener("DOMContentLoaded", function () {
    var form = $("forgotForm");
    var emailEl = $("email");
    var btn = $("sendBtn");

    if (!form || !emailEl || !btn) {
      console.error("forgot-password.js: required elements missing", {
        forgotForm: !!form,
        email: !!emailEl,
        sendBtn: !!btn
      });
      return;
    }

    form.addEventListener("submit", async function (evt) {
      evt.preventDefault();

      var email = (emailEl.value || "").trim();
      if (!email) {
        showAlert("Please enter your email.", "warning");
        return;
      }

      btn.disabled = true;
      btn.textContent = "Sending...";

      try {
        var data = await fetchJson(API_BASE + "/password_reset.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          strictSuccess: false,
          body: JSON.stringify({ action: "request", email: email })
        });

        showAlert(
          (data && data.MESSAGE) ? data.MESSAGE : genericSuccessMessage,
          "success"
        );
      } catch (err) {
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Request failed.", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Send Reset Link";
      }
    });
  });

})(window, document);
