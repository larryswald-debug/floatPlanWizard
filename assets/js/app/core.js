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

      Api.login(email, password)
        .then(function () {
          showLoginAlert("Login successful. Redirecting...", "success");

          // Will 404 until we create dashboard.cfm – that’s okay for now
          setTimeout(function () {
            window.location.href = BASE_PATH + "/app/dashboard.cfm";
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
          loginButton.textContent = "Sign In";
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
