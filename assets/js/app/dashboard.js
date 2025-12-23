// Updated to launch the float plan wizard in a modal and refresh after save.
(function (window, document) {
  "use strict";

  var floatPlanState = {
    all: [],
    filtered: [],
    query: ""
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

  var FLOAT_PLAN_LIMIT = 100;
  var wizardModalEl = null;
  var wizardModal = null;
  var wizardMountEl = null;
  var cloneModalEl = null;
  var cloneModal = null;
  var cloneMessageEl = null;
  var cloneOkButton = null;

  function showDashboardAlert(message, type) {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;

    alertEl.textContent = message || "";
    alertEl.classList.remove("d-none", "alert-success", "alert-danger", "alert-warning", "alert-info");

    var alertType = type || "info";
    alertEl.classList.add("alert-" + alertType);

    if (!message) {
      alertEl.classList.add("d-none");
    }
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

  function parsePlanDate(value) {
    if (!value) return 0;
    var date = new Date(value);
    var time = date.getTime();
    return isNaN(time) ? 0 : time;
  }

  function debounce(fn, delay) {
    var timerId = null;
    return function () {
      var args = arguments;
      if (timerId) {
        window.clearTimeout(timerId);
      }
      timerId = window.setTimeout(function () {
        timerId = null;
        fn.apply(null, args);
      }, delay);
    };
  }

  function normalizeSearch(value) {
    return String(value || "").trim().toLowerCase();
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

  function setFloatPlansFilterCount(filteredCount, totalCount) {
    var countEl = document.getElementById("floatPlansFilterCount");
    if (!countEl) return;
    countEl.textContent = "Showing " + filteredCount + " of " + totalCount;
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
        return "";
      default:
        cls = "bg-secondary";
        break;
    }

    return '<span class="badge ' + cls + '">' + escapeHtml(normalized) + "</span>";
  }

  function renderFloatPlansList(plans, totalCount) {
    var listEl = document.getElementById("floatPlansList");
    if (!listEl) return;

    var currentQuery = floatPlanState.query || "";
    if (!plans || !plans.length) {
      listEl.innerHTML = "";
      if (!totalCount) {
        setFloatPlansMessage("You don’t have any float plans yet.", false);
      } else if (currentQuery) {
        setFloatPlansMessage("No float plans match your filter.", false);
      } else {
        setFloatPlansMessage("You don’t have any float plans yet.", false);
      }
      return;
    }

    setFloatPlansMessage("", false);

    var scrollTop = listEl.scrollTop;
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

      var metaPartsInline = [];
      if (statusBadge) {
        metaPartsInline.push(statusBadge);
      }
      if (metaText) {
        metaPartsInline.push('<span class="list-meta-text">' + escapeHtml(metaText) + "</span>");
      }
      if (updatedText) {
        metaPartsInline.push('<span class="list-meta-text text-muted">' + escapeHtml(updatedText) + "</span>");
      }
      var metaInline = metaPartsInline.length
        ? '<div class="list-meta list-meta-inline">' + metaPartsInline.join('<span class="meta-sep">•</span>') + "</div>"
        : "";

      return (
        '<div class="list-item list-item-single" data-plan-id="' + escapeHtml(id) + '">' +
          '<div class="list-col-name">' +
            '<div class="list-title">' + escapeHtml(name || "Untitled Plan") + ":</div>" +
          "</div>" +
          '<div class="list-col-summary">' +
            metaInline +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" data-action="view" data-plan-id="' + escapeHtml(id) + '">View</button>' +
            '<button class="btn-secondary" type="button" data-action="send" data-plan-id="' + escapeHtml(id) + '">Send</button>' +
            '<button class="btn-secondary" type="button" data-action="clone" data-plan-id="' + escapeHtml(id) + '">Clone</button>' +
            '<button class="btn-secondary" type="button" data-action="edit" data-plan-id="' + escapeHtml(id) + '">Edit</button>' +
            '<button class="btn-danger" type="button" data-action="delete" data-plan-id="' + escapeHtml(id) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
    listEl.scrollTop = scrollTop;
  }

  function buildPlanSearchText(plan) {
    var name = pick(plan, ["PLANNAME", "NAME"], "");
    var status = pick(plan, ["STATUS", "status"], "");
    var vessel = pick(plan, ["VESSELNAME", "VESSEL"], "");
    var depart = pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt", "DEPARTURE_TIME", "DEPARTING_FROM"], "");
    var returnBy = pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt", "RETURN_TIME", "RETURNING_TO", "DESTINATION"], "");
    var updated = pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], "");
    var pieces = [
      name,
      status,
      vessel,
      depart,
      returnBy,
      updated,
      formatPlanDate(depart),
      formatPlanDate(returnBy),
      formatPlanDate(updated)
    ];
    return normalizeSearch(pieces.join(" "));
  }

  function applyFloatPlanFilter(rawQuery) {
    var normalized = normalizeSearch(rawQuery);
    floatPlanState.query = normalized;

    var source = floatPlanState.all || [];
    var filtered = normalized
      ? source.filter(function (plan) {
          return buildPlanSearchText(plan).indexOf(normalized) !== -1;
        })
      : source.slice();

    floatPlanState.filtered = filtered;
    renderFloatPlansList(filtered, source.length);
    setFloatPlansFilterCount(filtered.length, source.length);

    var clearBtn = document.getElementById("floatPlansFilterClear");
    if (clearBtn) {
      clearBtn.disabled = !normalized;
    }
  }

  function initFloatPlansFilter() {
    var inputEl = document.getElementById("floatPlansFilterInput");
    var clearBtn = document.getElementById("floatPlansFilterClear");
    if (!inputEl) return;

    var debouncedFilter = debounce(function () {
      applyFloatPlanFilter(inputEl.value);
    }, 250);

    inputEl.addEventListener("input", function () {
      debouncedFilter();
    });

    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        inputEl.value = "";
        applyFloatPlanFilter("");
        inputEl.focus();
      });
    }
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
        plans = plans.slice().sort(function (a, b) {
          var aCreated = parsePlanDate(pick(a, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          var bCreated = parsePlanDate(pick(b, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          if (aCreated !== bCreated) {
            return bCreated - aCreated;
          }
          var aId = parseInt(pick(a, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
          var bId = parseInt(pick(b, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
          if (isNaN(aId)) aId = 0;
          if (isNaN(bId)) bId = 0;
          return bId - aId;
        });
        floatPlanState.all = plans;
        updateFloatPlansSummary(plans);
        var inputEl = document.getElementById("floatPlansFilterInput");
        applyFloatPlanFilter(inputEl ? inputEl.value : "");
      })
      .catch(function (err) {
        console.error("Failed to load float plans:", err);
        setFloatPlansMessage("Unable to load float plans right now.", true);
        setFloatPlansSummary("Error");
        showDashboardAlert("Unable to load float plans. Please try again later.", "danger");
      });
  }

  function ensureWizardModal() {
    if (!wizardModalEl) {
      wizardModalEl = document.getElementById("floatPlanWizardModal");
      if (wizardModalEl) {
        wizardMountEl = wizardModalEl.querySelector("#wizardApp");
      }
    }

    if (wizardModalEl && !wizardModal && window.bootstrap && window.bootstrap.Modal) {
      wizardModal = new window.bootstrap.Modal(wizardModalEl);
    }

    if (wizardModalEl && !wizardModalEl.dataset.listenersAttached) {
      wizardModalEl.addEventListener("hidden.bs.modal", function () {
        if (window.FloatPlanWizard && typeof window.FloatPlanWizard.destroy === "function") {
          window.FloatPlanWizard.destroy();
        }
      });
      var closeButton = wizardModalEl.querySelector(".btn-close");
      if (closeButton) {
        closeButton.addEventListener("click", function () {
          if (window.FloatPlanWizard && typeof window.FloatPlanWizard.destroy === "function") {
            window.FloatPlanWizard.destroy();
          }
        });
      }
      wizardModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureCloneModal() {
    if (!cloneModalEl) {
      cloneModalEl = document.getElementById("floatPlanCloneModal");
      if (cloneModalEl) {
        cloneMessageEl = cloneModalEl.querySelector("[data-clone-message]");
        cloneOkButton = cloneModalEl.querySelector("[data-clone-ok]");
      }
    }

    if (cloneModalEl && !cloneModal && window.bootstrap && window.bootstrap.Modal) {
      cloneModal = new window.bootstrap.Modal(cloneModalEl);
    }

    if (cloneModalEl && !cloneModalEl.dataset.listenersAttached) {
      if (cloneOkButton) {
        cloneOkButton.addEventListener("click", function () {
          if (cloneModal) {
            cloneModal.hide();
          }
          window.location.href = "/fpw/app/dashboard.cfm";
        });
      }
      cloneModalEl.dataset.listenersAttached = "true";
    }
  }

  function showCloneModal(planName) {
    ensureCloneModal();
    if (!cloneModalEl || !cloneModal) {
      if (planName) {
        window.alert("Float plan cloned: " + planName);
      } else {
        window.alert("Float plan cloned.");
      }
      return;
    }

    if (cloneMessageEl) {
      var safeName = planName ? String(planName) : "";
      cloneMessageEl.textContent = safeName
        ? "Float plan has been cloned: " + safeName
        : "Float plan has been cloned.";
    }

    cloneModal.show();
  }

  function openWizard(planId, startStep) {
    ensureWizardModal();
    if (!wizardModalEl || !wizardModal) {
      return;
    }

    if (window.FloatPlanWizard && typeof window.FloatPlanWizard.init === "function") {
      window.FloatPlanWizard.init({
        mountEl: wizardMountEl,
        planId: planId,
        startStep: startStep,
        onSaved: function () {
          loadFloatPlans(FLOAT_PLAN_LIMIT);
          if (wizardModal) {
            wizardModal.show();
          }
        },
        onDeleted: function () {
          wizardModal.hide();
          loadFloatPlans(FLOAT_PLAN_LIMIT);
        }
      });
    }

    wizardModal.show();
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
      openWizard(planId);
    } else if (action === "view") {
      openWizard(planId, 6);
    } else if (action === "clone") {
      cloneFloatPlan(planId, button);
    } else if (action === "delete") {
      if (!window.confirm("Delete this float plan?")) {
        return;
      }
      deleteFloatPlan(planId, button);
    }
  }

  function cloneFloatPlan(planId, triggerButton) {
    if (!window.Api || typeof window.Api.cloneFloatPlan !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Cloning...";
    }

    Api.cloneFloatPlan(planId)
      .then(function (data) {
        if (!data.SUCCESS) {
          throw data;
        }
        loadFloatPlans(FLOAT_PLAN_LIMIT);
        var clonedName = pick(data, ["CLONED_NAME", "PLANNAME"], "");
        if (!clonedName && data.FLOATPLAN) {
          clonedName = pick(data.FLOATPLAN, ["NAME", "PLANNAME"], "");
        }
        showCloneModal(clonedName);
      })
      .catch(function (err) {
        console.error("Failed to clone float plan:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Clone failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Clone";
        }
      });
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
      nameEl.textContent = (user && user.NAME) ? user.NAME : "";
    }

    if (emailEl) {
      emailEl.textContent = (user && user.EMAIL) ? user.EMAIL : "";
    }
  }

  function initDashboard() {
    clearDashboardAlert();
    ensureWizardModal();
    ensureCloneModal();
    initFloatPlansFilter();

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
    var logoutBtn = document.getElementById("logoutButton");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", function () {
        Api.logout()
          .catch(function (err) {
            console.error("Logout failed:", err);
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
        openWizard(0);
      });
    }

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.addEventListener("click", handleFloatPlansListClick);
    }
  }

  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
