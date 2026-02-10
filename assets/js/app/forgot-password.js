// /fpw/assets/js/app/forgot-password.js
(function (window, document) {
  "use strict";

  var AuthUtils = window.FPW && window.FPW.AuthUtils;
  if (!AuthUtils) {
    console.error("forgot-password.js: auth-utils not loaded");
    return;
  }

  var BASE_PATH = AuthUtils.BASE_PATH;
  var API_BASE = AuthUtils.API_BASE;
  var $ = AuthUtils.$;
  var showAlert = function (msg, type) {
    AuthUtils.showAlert("fpAlert", msg, type);
  };

  function showDevLink(url) {
    var wrap = $("devLinkWrap");
    var link = $("devResetLink");
    if (!wrap || !link) return;

    wrap.classList.remove("d-none");
    link.textContent = url;
    link.href = url;
  }

  var pick = AuthUtils.pick;
  var fetchJson = AuthUtils.fetchJson;

  function resolveResetUrl(data) {
    // Accept many possible key spellings/casing
    var resetUrl = pick(data, [
      "RESET_URL", "reset_url",
      "RESETURL", "reseturl",
      "resetUrl", "ResetUrl"
    ]);

    var token = pick(data, [
      "TOKEN", "token",
      "RESET_TOKEN", "reset_token",
      "resetToken"
    ]);

    if (!resetUrl && token) {
      resetUrl = BASE_PATH + "/app/reset-password.cfm?token=" + encodeURIComponent(String(token));
    }

    return resetUrl;
  }

  document.addEventListener("DOMContentLoaded", function () {
    var form = $("forgotForm");
    var emailEl = $("email");
    var btn = $("sendBtn");

    // Hard fail early if markup is missing
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
      btn.textContent = "Sending…";

      // Hide dev link area each run
      var wrap = $("devLinkWrap");
      if (wrap) wrap.classList.add("d-none");

      try {
        var data = await fetchJson(API_BASE + "/password_reset.cfc?method=handle", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          strictSuccess: false,
          body: JSON.stringify({ action: "request", email: email })
        });

        console.log("password_reset response:", data);
        console.log("password_reset keys:", Object.keys(data || {}));

        showAlert(
          (data && data.MESSAGE) ? data.MESSAGE : "If that email exists, we sent password reset instructions.",
          "success"
        );

        var resetUrl = resolveResetUrl(data);

        console.log("resolved resetUrl:", resetUrl);

        if (resetUrl) {
          showDevLink(resetUrl);
        } else {
          showAlert(
            "Request succeeded, but no reset link was returned by the API. Check the Network response for RESET_URL or TOKEN.",
            "warning"
          );
        }

      } catch (err) {
        console.error("forgot-password error:", err);
        showAlert((err && err.MESSAGE) ? err.MESSAGE : "Request failed (see console).", "danger");
      } finally {
        btn.disabled = false;
        btn.textContent = "Send Reset Link";
      }
    });
  });

})(window, document);
