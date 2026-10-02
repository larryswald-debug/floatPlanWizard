// /fpw/assets/js/app/core.js

(function (window, document) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";

  function showLoginAlert(message, type) {
    var alertEl = document.getElementById("loginAlert");
    if (!alertEl) return;

    alertEl.classList.remove("d-none", "alert-success", "alert-danger", "alert-info");
    alertEl.classList.add("alert-" + (type || "info"));
    alertEl.textContent = message;
  }

  function clearLoginAlert() {
    var alertEl = document.getElementById("loginAlert");
    if (!alertEl) return;
    alertEl.classList.add("d-none");
    alertEl.textContent = "";
  }

  function getRecoveryReturnPath(form) {
    var candidate = form.getAttribute("data-recovery-return") || "";
    if (!candidate || typeof window.URL !== "function") return "";
    try {
      var target = new window.URL(candidate, window.location.origin);
      var idMatch = target.search.match(/&(?:routeId|routeInstanceId|floatPlanId)=([0-9]+)$/);
      if (target.origin !== window.location.origin ||
          target.pathname !== BASE_PATH + "/app/dashboard.cfm" ||
          candidate !== target.pathname + target.search ||
          !/^\?recoveryAction=(?:(?:vessel|planner|routes|plans)|route&(?:routeId|routeInstanceId)=[1-9][0-9]{0,9}|draft&floatPlanId=[1-9][0-9]{0,9})$/.test(target.search) ||
          (idMatch && Number(idMatch[1]) > 2147483647)) return "";
      return candidate;
    } catch (err) {
      return "";
    }
  }

  function initLoginForm() {
    var form = document.getElementById("loginForm");
    if (!form || !window.Api || typeof window.Api.login !== "function") {
      return;
    }

    var emailInput = document.getElementById("email");
    var passwordInput = document.getElementById("password");
    var loginButton = document.getElementById("loginButton");

    form.addEventListener("submit", function (evt) {
      evt.preventDefault();
      clearLoginAlert();

      var email = (emailInput.value || "").trim();
      var password = (passwordInput.value || "").trim();

      if (!email || !password) {
        showLoginAlert("Please enter both email and password.", "danger");
        return;
      }

      loginButton.disabled = true;
      loginButton.textContent = "Signing in...";

      var intentToken = form.getAttribute("data-auth-intent") || "";
      Api.login(email, password, intentToken)
        .then(function (data) {
          if (data.SUCCESS !== true || data.AUTH !== true) throw data;
          showLoginAlert("Login successful. Redirecting...", "success");

          setTimeout(function () {
            if (intentToken && window.AppAuth) window.AppAuth.navigateContinuation(data.REDIRECT_URL);
            else window.location.href = getRecoveryReturnPath(form) || BASE_PATH + "/app/dashboard.cfm";
          }, 800);
        })
        .catch(function (err) {
          var msg =
            (err && (err.MESSAGE || err.message)) ||
            "Login failed. Please check your credentials.";
          showLoginAlert(msg, "danger");
        })
        .finally(function () {
          loginButton.disabled = false;
          loginButton.textContent = "Log In";
        });
    });
  }

  function initLogoutButton() {
    var logoutBtn = document.getElementById("logoutButton");
    if (!logoutBtn || !window.Api || typeof window.Api.logout !== "function") {
      return;
    }

    logoutBtn.addEventListener("click", function () {
      Api.logout()
        .catch(function (err) {
          console.error("Logout failed:", err);
        })
        .finally(function () {
          if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
            window.AppAuth.redirectToLogin();
          } else {
            window.location.href = BASE_PATH + "/index.cfm";
          }
        });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initLoginForm();
    initLogoutButton();
  });

})(window, document);
