// /fpw/assets/js/app/forgot-password.js
(function (window, document) {
  "use strict";

  function $(id) { return document.getElementById(id); }

  function showAlert(msg, type) {
    var el = $("fpAlert");
    if (!el) return;

    el.classList.remove("d-none", "alert-success", "alert-danger", "alert-info", "alert-warning");
    el.classList.add("alert-" + (type || "info"));
    el.textContent = msg;
  }

  function showDevLink(url) {
    var wrap = $("devLinkWrap");
    var link = $("devResetLink");
    if (!wrap || !link) return;

    wrap.classList.remove("d-none");
    link.textContent = url;
    link.href = url;
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

    if (!res.ok) {
      data.status = res.status;
      throw data;
    }

    return data;
  }

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
      resetUrl = "/fpw/app/reset-password.cfm?token=" + encodeURIComponent(String(token));
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
        var data = await fetchJson("/fpw/api/v1/password_reset.cfm", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
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
