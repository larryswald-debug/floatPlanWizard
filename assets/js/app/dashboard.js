// /fpw/assets/js/app/dashboard.js

(function (window, document) {
  "use strict";

  function showDashboardAlert(message, type) {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;

    alertEl.classList.remove("d-none", "alert-success", "alert-danger", "alert-info");
    alertEl.classList.add("alert-" + (type || "info"));
    alertEl.textContent = message;
  }

  function clearDashboardAlert() {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;
    alertEl.classList.add("d-none");
    alertEl.textContent = "";
  }

  function populateUserInfo(user) {
    var nameEl = document.getElementById("userName");
    var emailEl = document.getElementById("userEmail");

    if (nameEl) {
      var fullName = [
        user.firstName || user.FIRSTNAME || "",
        user.lastName || user.LASTNAME || ""
      ].join(" ").trim();
      nameEl.textContent = fullName || "(no name)";
    }

    if (emailEl) {
      emailEl.textContent = user.email || user.EMAIL || "(no email)";
    }
  }

  function initDashboard() {
    if (!window.Api || typeof window.Api.getCurrentUser !== "function") {
      console.error("Api.getCurrentUser is not available.");
      return;
    }

    clearDashboardAlert();

    // Check current user
    Api.getCurrentUser()
      .then(function (data) {
        // data.SUCCESS already checked in Api.request
        if (!data.AUTH || !data.USER) {
          // Not logged in -> back to login page
          window.location.href = "/fpw/app/login.cfm";
          return;
        }

        populateUserInfo(data.USER);
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        window.location.href = "/fpw/app/login.cfm";
      });

    // Wire up logout
    var logoutButton = document.getElementById("logoutButton");
    if (logoutButton) {
      logoutButton.addEventListener("click", function () {
        if (!window.Api || typeof window.Api.logout !== "function") {
          return;
        }

        logoutButton.disabled = true;
        logoutButton.textContent = "Logging out…";

        Api.logout()
          .catch(function () {
            // Ignore errors, just send them to login
          })
          .finally(function () {
            window.location.href = "/fpw/app/login.cfm";
          });
      });
    }
  }

  document.addEventListener("DOMContentLoaded", initDashboard);

})(window, document);
