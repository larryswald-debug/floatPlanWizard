(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};
  var utils = window.FPW.DashboardUtils || {};

  var STEP_KEYS = ["vessel", "contact", "passengers", "operator", "waypoints"];
  var WORKFLOW_MODAL_IDS = [
    "vesselModal",
    "contactModal",
    "passengerModal",
    "operatorModal",
    "waypointModal"
  ];

  var initialized = false;
  var panelEl = null;
  var visibilityToggleEl = null;
  var stepsEl = null;
  var statusEl = null;
  var continueBtn = null;
  var completeEl = null;
  var welcomeOpenBtn = null;
  var modalEl = null;
  var modal = null;
  var modalContentEl = null;
  var accessMessageEl = null;
  var modalErrorEl = null;
  var addBoatBtn = null;
  var exploreBtn = null;
  var tourBtn = null;
  var closeBtn = null;
  var currentState = null;
  var routeReadinessAlertMessage = "";
  var requestSeq = 0;
  var refreshTimer = 0;
  var acknowledgmentBusy = false;
  var visibilityBusy = false;
  var refreshPendingAfterVisibilitySave = false;
  var acknowledgedInSession = false;
  var autoOpenHandled = false;
  var lastFocusEl = null;
  var afterHideAction = null;

  function getErrorMessage(err, fallback) {
    if (err && err.MESSAGE) return String(err.MESSAGE);
    if (err && err.message) return String(err.message);
    return fallback;
  }

  function extractState(payload) {
    var candidate = null;
    if (!payload || typeof payload !== "object") return null;
    if (payload.ONBOARDING && typeof payload.ONBOARDING === "object") {
      candidate = payload.ONBOARDING;
    } else if (payload.onboarding && typeof payload.onboarding === "object") {
      candidate = payload.onboarding;
    } else if (
      Object.prototype.hasOwnProperty.call(payload, "autoOpenWelcome")
      || Object.prototype.hasOwnProperty.call(payload, "checklist")
    ) {
      candidate = payload;
    }
    if (!candidate || !candidate.checklist || typeof candidate.checklist !== "object") {
      return null;
    }
    return candidate;
  }

  function isSuccessfulResponse(payload) {
    return !!(payload && (payload.SUCCESS === true || payload.success === true));
  }

  function setPanelStatus(message, isError) {
    if (!statusEl) return;
    statusEl.textContent = message || "";
    statusEl.classList.toggle("is-error", isError === true);
  }

  function showRouteReadinessAlert(message) {
    routeReadinessAlertMessage = String(message || "").trim();
    if (
      routeReadinessAlertMessage
      && utils
      && typeof utils.showDashboardAlert === "function"
    ) {
      utils.showDashboardAlert(routeReadinessAlertMessage, "warning");
    }
  }

  function clearRouteReadinessAlert() {
    var alertEl = document.getElementById("dashboardAlert");
    var displayedMessage = alertEl ? String(alertEl.textContent || "").trim() : "";
    if (
      routeReadinessAlertMessage
      && displayedMessage === routeReadinessAlertMessage
      && utils
      && typeof utils.clearDashboardAlert === "function"
    ) {
      utils.clearDashboardAlert();
    }
    routeReadinessAlertMessage = "";
  }

  function formatMissingRouteSetupItems(items) {
    if (!items.length) return "";
    if (items.length === 1) return items[0];
    if (items.length === 2) return items[0] + " and " + items[1];
    return items.slice(0, -1).join(", ") + ", and " + items[items.length - 1];
  }

  function getMissingRouteSetupItems(state) {
    var checklist = state && state.checklist && typeof state.checklist === "object"
      ? state.checklist
      : {};
    var missing = [];
    var savedWaypointCount = Math.max(0, parseInt(checklist.savedWaypointCount, 10) || 0);
    var requiredWaypointCount = Math.max(1, parseInt(checklist.requiredWaypointCount, 10) || 2);
    var remainingWaypointCount = Math.max(0, requiredWaypointCount - savedWaypointCount);

    if (checklist.vessel !== true) {
      missing.push("a vessel");
    }
    if (checklist.contact !== true) {
      missing.push("a shore contact with name, phone, and email");
    }
    if (checklist.operator !== true) {
      missing.push("an operator");
    }
    if (checklist.waypoints !== true) {
      if (remainingWaypointCount === 1) {
        missing.push(
          "1 more waypoint ("
          + savedWaypointCount
          + " of "
          + requiredWaypointCount
          + " saved)"
        );
      } else if (remainingWaypointCount > 1) {
        missing.push(
          remainingWaypointCount
          + " more waypoints ("
          + savedWaypointCount
          + " of "
          + requiredWaypointCount
          + " saved)"
        );
      } else {
        missing.push("the required saved waypoints");
      }
    }

    return missing;
  }

  function setModalError(message) {
    if (!modalErrorEl) return;
    modalErrorEl.textContent = message || "";
    modalErrorEl.classList.toggle("d-none", !message);
  }

  function setAcknowledgmentBusy(isBusy) {
    var controls = [addBoatBtn, exploreBtn, tourBtn, closeBtn];
    acknowledgmentBusy = isBusy === true;
    controls.forEach(function (control) {
      if (control) control.disabled = acknowledgmentBusy;
    });
    if (modalContentEl) {
      modalContentEl.setAttribute("aria-busy", acknowledgmentBusy ? "true" : "false");
    }
  }

  function setVisibilityBusy(isBusy) {
    visibilityBusy = isBusy === true;
    if (visibilityToggleEl) {
      visibilityToggleEl.disabled = visibilityBusy;
      visibilityToggleEl.setAttribute("aria-busy", visibilityBusy ? "true" : "false");
    }
  }

  function renderChecklist(state) {
    var checklist = state.checklist || {};
    var firstIncompleteStep = String(checklist.firstIncompleteStep || "").trim().toLowerCase();
    var allComplete = checklist.allComplete === true;
    var savedWaypointCount = Math.max(0, parseInt(checklist.savedWaypointCount, 10) || 0);
    var requiredWaypointCount = Math.max(1, parseInt(checklist.requiredWaypointCount, 10) || 2);

    STEP_KEYS.forEach(function (key) {
      var item = stepsEl ? stepsEl.querySelector('[data-onboarding-step="' + key + '"]') : null;
      var stepStatus = item ? item.querySelector("[data-onboarding-step-status]") : null;
      var isOptional = key === "passengers";
      var isComplete = checklist[key] === true;
      var isCurrent = !isOptional && !allComplete && !isComplete && firstIncompleteStep === key;
      if (!item) return;
      item.classList.toggle("is-complete", isComplete);
      item.classList.toggle("is-current", isCurrent);
      if (isCurrent) {
        item.setAttribute("aria-current", "step");
      } else {
        item.removeAttribute("aria-current");
      }
      if (stepStatus) {
        if (isOptional && !isComplete) {
          stepStatus.textContent = "Optional";
        } else if (key === "waypoints" && !isComplete) {
          stepStatus.textContent = (isCurrent ? "Next step · " : "")
            + savedWaypointCount
            + " of "
            + requiredWaypointCount
            + " added";
        } else {
          stepStatus.textContent = isComplete ? "Complete" : (isCurrent ? "Next step" : "Not complete");
        }
      }
    });

    if (continueBtn) {
      continueBtn.classList.remove("d-none");
      continueBtn.disabled = false;
      continueBtn.textContent = allComplete ? "Create My Route" : "Continue Setup";
    }
    if (completeEl) {
      completeEl.classList.toggle("d-none", !allComplete);
    }
  }

  function renderWelcomeMessage(state) {
    var message = String(state.welcomeMessage || "").trim();
    if (!accessMessageEl) return;
    accessMessageEl.textContent = message;
    accessMessageEl.classList.toggle("d-none", !message);
  }

  function renderGettingStartedVisibility(state) {
    var isHidden = state.gettingStartedHidden === true;
    if (panelEl) {
      panelEl.hidden = isHidden;
      panelEl.setAttribute("aria-busy", "false");
    }
    if (visibilityToggleEl) {
      visibilityToggleEl.checked = !isHidden;
      visibilityToggleEl.disabled = visibilityBusy;
      visibilityToggleEl.setAttribute("aria-busy", visibilityBusy ? "true" : "false");
    }
  }

  function renderState(state) {
    currentState = state;
    renderChecklist(state);
    renderWelcomeMessage(state);
    renderGettingStartedVisibility(state);
    setPanelStatus("", false);
  }

  function restoreFocus() {
    var target = lastFocusEl;
    lastFocusEl = null;
    if (!target || !document.documentElement.contains(target) || typeof target.focus !== "function") {
      target = continueBtn && !continueBtn.classList.contains("d-none") ? continueBtn : welcomeOpenBtn;
    }
    if (target && typeof target.focus === "function") {
      target.focus();
    }
  }

  function showWelcome(trigger) {
    if (!modal || !currentState) {
      setPanelStatus("Welcome details are unavailable. Please try again.", true);
      return false;
    }
    lastFocusEl = trigger || (
      document.activeElement
      && document.activeElement !== document.body
      && typeof document.activeElement.focus === "function"
        ? document.activeElement
        : null
    );
    setModalError("");
    renderWelcomeMessage(currentState);
    modal.show();
    return true;
  }

  function hydrate(payload, options) {
    var state = extractState(payload);
    var hydrateOptions = options || {};
    if (!state) {
      if (visibilityToggleEl) {
        visibilityToggleEl.disabled = true;
        visibilityToggleEl.setAttribute("aria-busy", "false");
      }
      if (panelEl) {
        panelEl.hidden = false;
        panelEl.setAttribute("aria-busy", "false");
      }
      setPanelStatus("Getting Started status is unavailable. Please refresh and try again.", true);
      return false;
    }
    renderState(state);
    if (
      hydrateOptions.allowAutoOpen === true
      && state.autoOpenWelcome === true
      && !autoOpenHandled
    ) {
      autoOpenHandled = true;
      window.setTimeout(function () {
        showWelcome(null);
      }, 0);
    }
    return true;
  }

  function showVisibilityError(message) {
    if (panelEl && !panelEl.hidden) {
      setPanelStatus(message, true);
      return;
    }
    if (utils && typeof utils.showDashboardAlert === "function") {
      utils.showDashboardAlert(message, "danger");
    }
  }

  function saveGettingStartedVisibility(hidden) {
    if (visibilityBusy) return;
    if (
      !window.Api
      || typeof window.Api.setDashboardGettingStartedHidden !== "function"
    ) {
      if (currentState) renderGettingStartedVisibility(currentState);
      showVisibilityError("Getting Started display settings are unavailable. Please refresh and try again.");
      return;
    }

    setPanelStatus("Saving Getting Started display preference…", false);
    requestSeq += 1;
    setVisibilityBusy(true);
    window.Api.setDashboardGettingStartedHidden(hidden)
      .then(function (payload) {
        var responseState = extractState(payload);
        if (!isSuccessfulResponse(payload) || !responseState) {
          throw payload || new Error("Getting Started display preference was not confirmed.");
        }
        requestSeq += 1;
        renderState(responseState);
      })
      .catch(function (err) {
        if (currentState) renderGettingStartedVisibility(currentState);
        showVisibilityError(
          getErrorMessage(
            err,
            "Unable to save the Getting Started display preference. Please try again."
          )
        );
      })
      .finally(function () {
        setVisibilityBusy(false);
        if (refreshPendingAfterVisibilitySave) {
          refreshPendingAfterVisibilitySave = false;
          scheduleRefresh();
        }
      });
  }

  function refresh() {
    var seq = 0;
    if (visibilityBusy) {
      refreshPendingAfterVisibilitySave = true;
      return Promise.resolve(currentState);
    }
    if (!window.Api || typeof window.Api.getDashboardOnboardingState !== "function") {
      return Promise.reject(new Error("Getting Started service is unavailable."));
    }
    requestSeq += 1;
    seq = requestSeq;
    if (panelEl) panelEl.setAttribute("aria-busy", "true");
    return window.Api.getDashboardOnboardingState()
      .then(function (payload) {
        if (seq !== requestSeq) return currentState;
        if (!hydrate(payload, { allowAutoOpen: false })) {
          throw new Error("Getting Started status was not returned.");
        }
        return currentState;
      })
      .catch(function (err) {
        if (seq === requestSeq) {
          if (panelEl) panelEl.setAttribute("aria-busy", "false");
          setPanelStatus(getErrorMessage(err, "Unable to refresh Getting Started status."), true);
        }
        throw err;
      });
  }

  function validateRouteCreationReadiness() {
    return refresh()
      .then(function (state) {
        var checklist = state && state.checklist && typeof state.checklist === "object"
          ? state.checklist
          : {};
        var missing = [];
        var message = "";

        if (checklist.allComplete === true) {
          clearRouteReadinessAlert();
          return true;
        }

        missing = getMissingRouteSetupItems(state);
        message = missing.length
          ? "Before creating a route, complete Getting Started by saving "
            + formatMissingRouteSetupItems(missing)
            + "."
          : "Before creating a route, complete all Getting Started requirements.";
        showRouteReadinessAlert(message);
        return false;
      })
      .catch(function () {
        showRouteReadinessAlert(
          "Unable to verify route setup. Please try again before creating a route."
        );
        return false;
      });
  }

  function scheduleRefresh() {
    if (refreshTimer) window.clearTimeout(refreshTimer);
    refreshTimer = window.setTimeout(function () {
      refreshTimer = 0;
      if (visibilityBusy) {
        refreshPendingAfterVisibilitySave = true;
        return;
      }
      refresh().catch(function () {
        // The checklist keeps its last confirmed state and displays the refresh error.
      });
    }, 180);
  }

  function openWelcome(trigger) {
    setPanelStatus("Refreshing welcome details…", false);
    if (welcomeOpenBtn) welcomeOpenBtn.disabled = true;
    return refresh()
      .then(function () {
        showWelcome(trigger || welcomeOpenBtn);
      })
      .finally(function () {
        if (welcomeOpenBtn) welcomeOpenBtn.disabled = false;
      });
  }

  function clickExistingButton(buttonId) {
    var button = document.getElementById(buttonId);
    var style = button ? window.getComputedStyle(button) : null;
    if (
      !button
      || typeof button.click !== "function"
      || button.disabled
      || button.hidden
      || button.getAttribute("aria-disabled") === "true"
      || (style && (style.display === "none" || style.visibility === "hidden"))
    ) {
      return false;
    }
    button.click();
    return true;
  }

  function executeContinueTarget(target) {
    var action = target && target.action ? String(target.action).trim().toLowerCase() : "";
    var succeeded = false;

    if (action === "add-vessel") {
      succeeded = clickExistingButton("addVesselBtn");
    } else if (action === "add-contact") {
      succeeded = clickExistingButton("addContactBtn");
    } else if (action === "add-passenger") {
      succeeded = clickExistingButton("addPassengerBtn");
    } else if (action === "add-operator") {
      succeeded = clickExistingButton("addOperatorBtn");
    } else if (action === "add-waypoint") {
      succeeded = clickExistingButton("addWaypointBtn");
    } else if (action === "create-route") {
      succeeded = clickExistingButton("openRouteBuilderBtn");
    }

    if (!succeeded) {
      setPanelStatus("The next setup action is unavailable for this account.", true);
      return false;
    }
    setPanelStatus("", false);
    return true;
  }

  function startDashboardTour() {
    if (!window.FPWHelpTour || typeof window.FPWHelpTour.start !== "function") {
      setPanelStatus("The dashboard tour is unavailable. Refresh the dashboard and try again.", true);
      restoreFocus();
      return;
    }
    if (!window.FPWHelpTour.start("dashboard")) {
      setPanelStatus("The dashboard tour could not find its page sections.", true);
      restoreFocus();
    }
  }

  function finishWelcomeAction(action) {
    if (action === "boat") {
      if (!executeContinueTarget({ action: "add-vessel" })) restoreFocus();
      return;
    }
    if (action === "tour") {
      startDashboardTour();
      return;
    }
    restoreFocus();
  }

  function hideWelcome(action) {
    afterHideAction = function () {
      finishWelcomeAction(action);
    };
    if (modal && modalEl && modalEl.classList.contains("show")) {
      modal.hide();
    } else {
      var callback = afterHideAction;
      afterHideAction = null;
      callback();
    }
  }

  function updateStateFromAcknowledgment(payload) {
    var responseState = extractState(payload);
    if (responseState) {
      renderState(responseState);
    } else if (payload && payload.acknowledgedAt && currentState) {
      currentState.acknowledgedAt = payload.acknowledgedAt;
    }
    acknowledgedInSession = true;
  }

  function acknowledgeAndProceed(action) {
    var alreadyAcknowledged = acknowledgedInSession || !!(currentState && currentState.acknowledgedAt);
    if (acknowledgmentBusy) return;
    setModalError("");
    if (alreadyAcknowledged) {
      hideWelcome(action);
      return;
    }
    if (!window.Api || typeof window.Api.acknowledgeDashboardOnboarding !== "function") {
      setModalError("Welcome acknowledgment is unavailable. Please refresh and try again.");
      return;
    }

    setAcknowledgmentBusy(true);
    window.Api.acknowledgeDashboardOnboarding()
      .then(function (payload) {
        if (!isSuccessfulResponse(payload)) {
          throw payload || new Error("Welcome acknowledgment was not confirmed.");
        }
        updateStateFromAcknowledgment(payload);
        hideWelcome(action);
      })
      .catch(function (err) {
        setModalError(getErrorMessage(err, "Unable to save your Welcome acknowledgment. Please try again."));
      })
      .finally(function () {
        setAcknowledgmentBusy(false);
      });
  }

  function bindWorkflowRefreshes() {
    WORKFLOW_MODAL_IDS.forEach(function (id) {
      var workflowModal = document.getElementById(id);
      if (workflowModal) {
        workflowModal.addEventListener("hidden.bs.modal", scheduleRefresh);
      }
    });
  }

  function cacheDom() {
    panelEl = document.getElementById("dashboardGettingStartedPanel");
    visibilityToggleEl = document.getElementById("dashboardGettingStartedVisibilityToggle");
    stepsEl = document.getElementById("dashboardGettingStartedSteps");
    statusEl = document.getElementById("dashboardGettingStartedStatus");
    continueBtn = document.getElementById("dashboardGettingStartedContinueBtn");
    completeEl = document.getElementById("dashboardGettingStartedComplete");
    welcomeOpenBtn = document.getElementById("dashboardWelcomeOpenBtn");
    modalEl = document.getElementById("welcomeOnboardingModal");
    modalContentEl = modalEl ? modalEl.querySelector(".modal-content") : null;
    accessMessageEl = document.getElementById("welcomeOnboardingAccessMessage");
    modalErrorEl = document.getElementById("welcomeOnboardingError");
    addBoatBtn = document.getElementById("welcomeOnboardingAddBoatBtn");
    exploreBtn = document.getElementById("welcomeOnboardingExploreBtn");
    tourBtn = document.getElementById("welcomeOnboardingTourBtn");
    closeBtn = document.getElementById("welcomeOnboardingCloseBtn");
    return !!(
      panelEl
      && visibilityToggleEl
      && stepsEl
      && modalEl
    );
  }

  function init() {
    if (initialized) return;
    if (!cacheDom()) return;
    initialized = true;
    if (window.bootstrap && window.bootstrap.Modal) {
      modal = new window.bootstrap.Modal(modalEl, {
        backdrop: "static",
        keyboard: false,
        focus: true
      });
    }

    if (continueBtn) {
      continueBtn.addEventListener("click", function () {
        if (!currentState || !currentState.continueTarget) {
          setPanelStatus("The next setup action is unavailable for this account.", true);
          return;
        }
        executeContinueTarget(currentState.continueTarget);
      });
    }
    if (welcomeOpenBtn) {
      welcomeOpenBtn.addEventListener("click", function () {
        openWelcome(welcomeOpenBtn).catch(function () {
          // The card displays the focused refresh error.
        });
      });
    }
    visibilityToggleEl.addEventListener("change", function () {
      saveGettingStartedVisibility(visibilityToggleEl.checked !== true);
    });
    if (addBoatBtn) addBoatBtn.addEventListener("click", function () { acknowledgeAndProceed("boat"); });
    if (exploreBtn) exploreBtn.addEventListener("click", function () { acknowledgeAndProceed("explore"); });
    if (tourBtn) tourBtn.addEventListener("click", function () { acknowledgeAndProceed("tour"); });
    if (closeBtn) closeBtn.addEventListener("click", function () { acknowledgeAndProceed("close"); });

    modalEl.addEventListener("shown.bs.modal", function () {
      if (addBoatBtn) addBoatBtn.focus();
    });
    modalEl.addEventListener("hidden.bs.modal", function () {
      var callback = afterHideAction;
      afterHideAction = null;
      setAcknowledgmentBusy(false);
      if (callback) {
        callback();
      } else {
        restoreFocus();
      }
    });
    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape" || !modalEl.classList.contains("show")) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      acknowledgeAndProceed("close");
    }, true);

    bindWorkflowRefreshes();
  }

  window.FPW.DashboardModules.onboarding = {
    init: init,
    hydrate: hydrate,
    refresh: refresh,
    openWelcome: openWelcome,
    validateRouteCreationReadiness: validateRouteCreationReadiness
  };
})(window, document);
