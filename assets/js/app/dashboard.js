// /fpw/assets/js/app/dashboard.js

(function (window, document) {
  "use strict";

  var floatPlanState = {
    plans: []
  };

  var FALLBACK_LOGIN_URL = "/fpw/app/login.cfm";

  function getLoginUrl() {
    if (window.AppAuth && window.AppAuth.loginUrl) {
      return window.AppAuth.loginUrl;
    }
    return FALLBACK_LOGIN_URL;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = getLoginUrl();
  }

  function ensureAuthResponse(data) {
    return window.AppAuth ? window.AppAuth.ensureAuthenticated(data) : true;
  }

  var FLOAT_PLAN_LIMIT = 5;

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

  function pick(obj, keys, fallback) {
    if (!obj) return fallback;
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (obj[key] !== undefined && obj[key] !== null && String(obj[key]).length) {
        return obj[key];
      }
    }
    return fallback;
  }

  function escapeHtml(value) {
    if (value === undefined || value === null) return "";
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatPlanDate(value) {
    if (!value) return "";
    var date = new Date(value);
    if (isNaN(date.getTime())) {
      return String(value);
    }
    var datePart = date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    var timePart = date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
    return datePart + " " + timePart;
  }

  function setFloatPlansSummary(text) {
    var el = document.getElementById("floatPlansSummary");
    if (!el) return;
    el.textContent = text;
  }

  function updateFloatPlansSummary(plans) {
    if (!plans || !plans.length) {
      setFloatPlansSummary("No plans yet");
      return;
    }

    var activeCount = 0;
    for (var i = 0; i < plans.length; i++) {
      var status = pick(plans[i], ["STATUS", "status"], "");
      if (status && ["ACTIVE", "OPEN"].indexOf(String(status).toUpperCase()) !== -1) {
        activeCount++;
      }
    }

    var summaryText = activeCount + " active • " + plans.length + " total";
    setFloatPlansSummary(summaryText);
  }

  function setFloatPlansMessage(text, isError) {
    var messageEl = document.getElementById("floatPlansMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function renderStatusBadge(status) {
    if (!status) return "";
    var normalized = String(status).toUpperCase();
    var cls = "bg-secondary";

    switch (normalized) {
      case "OPEN":
      case "ACTIVE":
        cls = "bg-success";
        break;
      case "SUBMITTED":
        cls = "bg-primary";
        break;
      case "OVERDUE":
        cls = "bg-danger";
        break;
      case "COMPLETED":
      case "CLOSED":
        cls = "bg-dark";
        break;
      case "DRAFT":
      default:
        cls = "bg-secondary";
        break;
    }

    return '<span class="badge ' + cls + '">' + escapeHtml(normalized) + "</span>";
  }

  function renderFloatPlans(plans) {
    var listEl = document.getElementById("floatPlansList");
    if (!listEl) return;

    updateFloatPlansSummary(plans);

    if (!plans || !plans.length) {
      listEl.innerHTML = "";
      setFloatPlansMessage("You don’t have any float plans yet.", false);
      return;
    }

    setFloatPlansMessage("", false);

    var rows = plans.map(function (plan) {
      var id = pick(plan, ["FLOATPLANID", "PLANID", "ID"], "");
      var name = pick(plan, ["PLANNAME", "NAME"], "");
      if (!name && id) {
        name = "Plan #" + id;
      }
      var status = pick(plan, ["STATUS", "status"], "");
      var depart = formatPlanDate(pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt"], ""));
      var returnBy = formatPlanDate(pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt"], ""));
      var vessel = pick(plan, ["VESSELNAME", "VESSEL"], "");
      var updated = formatPlanDate(pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], ""));
      var waypointCount = parseInt(pick(plan, ["WAYPOINTCOUNT", "waypointCount"], 0), 10);
      if (isNaN(waypointCount)) waypointCount = 0;

      var metaParts = [];
      if (depart) metaParts.push("Departs " + depart);
      if (returnBy) metaParts.push("Return " + returnBy);
      if (waypointCount > 0) {
        metaParts.push(waypointCount + " waypoint" + (waypointCount === 1 ? "" : "s"));
      }
      if (vessel) metaParts.push(vessel);
      var metaText = metaParts.join(" • ");
      var statusBadge = renderStatusBadge(status);
      var updatedText = updated ? "Updated " + updated : "";

      var statusLine = "";
      if (statusBadge || metaText) {
        statusLine =
          '<div class="list-meta">' +
          (statusBadge ? statusBadge : "") +
          (statusBadge && metaText ? '<span class="meta-sep">•</span>' : "") +
          (metaText ? escapeHtml(metaText) : "") +
          "</div>";
      }

      var updatedLine = updatedText
        ? '<div class="list-meta text-muted">' + escapeHtml(updatedText) + "</div>"
        : "";

      return (
        '<div class="list-item list-item-multi" data-plan-id="' + escapeHtml(id) + '">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(name || "Untitled Plan") + "</div>" +
            statusLine +
            updatedLine +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" data-action="edit" data-plan-id="' + escapeHtml(id) + '">Edit</button>' +
            '<button class="btn-danger" type="button" data-action="delete" data-plan-id="' + escapeHtml(id) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function loadFloatPlans(limit) {
    limit = limit || FLOAT_PLAN_LIMIT;
    setFloatPlansSummary("Loading…");
    setFloatPlansMessage("Loading float plans…", false);

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getFloatPlans !== "function") {
      setFloatPlansMessage("Float plan API is unavailable.", true);
      setFloatPlansSummary("Unavailable");
      return;
    }

    Api.getFloatPlans({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var plans = data.PLANS || data.FLOATPLANS || data.floatplans || [];
        floatPlanState.plans = plans;
        renderFloatPlans(plans);
      })
      .catch(function (err) {
        console.error("Failed to load float plans:", err);
        setFloatPlansMessage("Unable to load float plans right now.", true);
        setFloatPlansSummary("Error");
        showDashboardAlert("Unable to load float plans. Please try again later.", "danger");
      });
  }

  function navigateToFloatPlanWizard(planId) {
    var url = "/fpw/app/floatplan-wizard.cfm";
    if (planId) {
      url += "?id=" + encodeURIComponent(planId);
    }
    window.location.href = url;
  }

  var wizardModalInstance = null;
  var wizardMountEl = null;
  var wizardTemplateHtml = "";

  function getWizardMount() {
    if (!wizardMountEl) {
      wizardMountEl = document.getElementById("wizardApp");
      if (wizardMountEl && !wizardTemplateHtml) {
        wizardTemplateHtml = wizardMountEl.innerHTML;
      }
    }
    return wizardMountEl;
  }

  function resetWizardDom() {
    if (wizardMountEl && wizardTemplateHtml) {
      wizardMountEl.innerHTML = wizardTemplateHtml;
    }
  }

  function ensureWizardModal() {
    if (wizardModalInstance) {
      return wizardModalInstance;
    }

    var modalEl = document.getElementById("floatPlanWizardModal");
    if (!modalEl || !window.bootstrap) {
      return null;
    }

    wizardModalInstance = new bootstrap.Modal(modalEl, { backdrop: "static", keyboard: false });
    modalEl.addEventListener("hidden.bs.modal", function () {
      if (window.FloatPlanWizard && typeof window.FloatPlanWizard.unmount === "function") {
        window.FloatPlanWizard.unmount();
      }
      resetWizardDom();
      wizardMountEl = null;
    });

    return wizardModalInstance;
  }

  function handleWizardSaved() {
    if (wizardModalInstance) {
      wizardModalInstance.hide();
    }
    loadFloatPlans(FLOAT_PLAN_LIMIT);
  }

  function openFloatPlanWizard(planId) {
    var modal = ensureWizardModal();
    var mountTarget = getWizardMount();

    if (!modal || !mountTarget || !window.FloatPlanWizard || typeof window.FloatPlanWizard.mount !== "function") {
      navigateToFloatPlanWizard(planId);
      return;
    }

    var numericPlanId = parseInt(planId, 10);
    if (isNaN(numericPlanId)) {
      numericPlanId = 0;
    }

    var instance = window.FloatPlanWizard.getInstance && window.FloatPlanWizard.getInstance();

    if (instance && instance.vm && typeof instance.vm.resetWizard === "function") {
      instance.vm.resetWizard(numericPlanId);
      instance.vm.callbacks = instance.vm.callbacks || {};
      instance.vm.callbacks.onSaved = handleWizardSaved;
    } else {
      instance = window.FloatPlanWizard.mount(mountTarget, {
        initialPlanId: numericPlanId,
        onSaved: handleWizardSaved
      });
    }

    modal.show();
  }

  function handleFloatPlansListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-plan-id]");
    if (!button) return;

    var planId = button.getAttribute("data-plan-id");
    var action = button.getAttribute("data-action");

    if (!planId) return;

    if (action === "edit") {
      openFloatPlanWizard(planId);
    } else if (action === "delete") {
      if (!window.confirm("Delete this float plan?")) {
        return;
      }
      deleteFloatPlan(planId, button);
    }
  }

  function deleteFloatPlan(planId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteFloatPlan !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteFloatPlan(planId)
      .then(function (data) {
        if (!data.SUCCESS) {
          throw data;
        }
        loadFloatPlans(FLOAT_PLAN_LIMIT);
      })
      .catch(function (err) {
        console.error("Failed to delete float plan:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
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
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (!data.USER) {
          redirectToLogin();
          return;
        }

        populateUserInfo(data.USER);
        loadFloatPlans(FLOAT_PLAN_LIMIT);
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        redirectToLogin();
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
            redirectToLogin();
          });
      });
    }

    var addPlanBtn = document.getElementById("addFloatPlanBtn");
    if (addPlanBtn) {
      addPlanBtn.addEventListener("click", function () {
        openFloatPlanWizard();
      });
    }

    var viewAllBtn = document.getElementById("viewAllFloatPlansBtn");
    if (viewAllBtn) {
      viewAllBtn.addEventListener("click", function () {
        navigateToFloatPlanWizard();
      });
    }

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.addEventListener("click", handleFloatPlansListClick);
    }
  }

  document.addEventListener("DOMContentLoaded", initDashboard);

})(window, document);
