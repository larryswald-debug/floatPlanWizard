(function (window, document) {
  "use strict";

  function $(id) {
    return document.getElementById(id);
  }

  function getErrorCode(error) {
    if (error && typeof error.ERROR === "string") return String(error.ERROR);
    if (error && typeof error.errorCode === "string") return String(error.errorCode);
    return "";
  }

  function getAccess(payload) {
    if (!payload || typeof payload !== "object") return null;
    if (payload.ACCESS && typeof payload.ACCESS === "object") return payload.ACCESS;
    if (payload.access && typeof payload.access === "object") return payload.access;
    return null;
  }

  function hasPremium(access) {
    var value = access && Object.prototype.hasOwnProperty.call(access, "hasPremium")
      ? access.hasPremium
      : (access && Object.prototype.hasOwnProperty.call(access, "HASPREMIUM") ? access.HASPREMIUM : false);
    if (value === true || value === 1) return true;
    return String(value).trim().toLowerCase() === "true" || String(value).trim() === "1";
  }

  function buttonIconMarkup() {
    return '<svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
      '<path d="M5 3v4"></path><path d="M3 5h4"></path><path d="M19 13v4"></path><path d="M17 15h4"></path>' +
      '<path d="M11 6l1.5 3.5L16 11l-3.5 1.5L11 16l-1.5-3.5L6 11l3.5-1.5L11 6z"></path>' +
      '</svg>';
  }

  function arrowIconMarkup() {
    return '<svg class="fpw-inline-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
      '<path d="M5 12h14"></path><path d="M13 6l6 6-6 6"></path>' +
      '</svg>';
  }

  function infoIconMarkup() {
    return '<span class="fpw-status-info-icon" aria-hidden="true">' +
      '<svg class="fpw-inline-icon" viewBox="0 0 24 24" focusable="false">' +
      '<circle cx="12" cy="12" r="9"></circle><path d="M12 11v5"></path><path d="M12 7h.01"></path>' +
      '</svg></span>';
  }

  function setMessage(message, tone) {
    var el = $("startTrialMessage");
    if (!el) return;
    el.classList.remove("membership-message-error", "membership-message-success");
    if (tone === "error" || tone === "danger") el.classList.add("membership-message-error");
    if (tone === "success") el.classList.add("membership-message-success");
    el.innerHTML = infoIconMarkup() + '<span class="fpw-status-message-copy"></span>';
    var copy = el.querySelector(".fpw-status-message-copy");
    if (!copy) return;
    if (message === "Ready to start. No payment information is required.") {
      copy.innerHTML = 'Ready to start. <strong>No payment information</strong> is required.';
      return;
    }
    copy.textContent = message || "";
  }

  function setBusy(isBusy) {
    var button = $("activateLaunchTrialBtn");
    if (!button) return;
    button.disabled = !!isBusy;
    button.setAttribute("aria-disabled", isBusy ? "true" : "false");
    button.innerHTML = buttonIconMarkup() + (isBusy ? "Starting trial..." : "Start Your Free Trial") + arrowIconMarkup();
  }

  function messageForError(error) {
    var code = getErrorCode(error).toUpperCase();
    if (code === "FREE_TRIAL_ALREADY_USED") return "A free trial has already been used for this account.";
    if (code === "LAUNCH_PROMO_NOT_AVAILABLE") return "The launch trial is not available right now.";
    if (code === "LAUNCH_PROMO_AMBIGUOUS") return "Launch trial setup needs attention before the trial can start.";
    if (code === "ALREADY_PREMIUM") return "Your account already has Premium access.";
    if (code === "STRIPE_CONFIG_MISSING") return "Trial activation is not available right now.";
    if (code === "STRIPE_SUBSCRIPTION_FAILED") return "Trial subscription could not be started.";
    if (code === "STRIPE_SUBSCRIPTION_LOOKUP_FAILED") return "Existing Stripe subscriptions could not be checked. Please try again shortly.";
    if (code === "STRIPE_CUSTOMER_CREATE_FAILED" || code === "STRIPE_CUSTOMER_UPDATE_FAILED") return "Billing customer setup could not be completed.";
    if (code === "STRIPE_CUSTOMER_MAPPING_CONFLICT") return "Billing customer setup needs account support.";
    if (code === "AUTH_REQUIRED") return "Log in to start the launch trial.";
    return (error && (error.MESSAGE || error.message)) ? (error.MESSAGE || error.message) : "Launch trial could not be started.";
  }

  function statusFrom(payload) {
    return String((payload && (payload.status || payload.STATUS)) || "").trim().toLowerCase();
  }

  function redirectUrlFrom(payload) {
    return payload && (payload.redirectUrl || payload.REDIRECT_URL)
      ? String(payload.redirectUrl || payload.REDIRECT_URL).trim()
      : "/app/dashboard.cfm";
  }

  function successMessageForStatus(payload) {
    var status = statusFrom(payload);
    if (status === "already_premium") return "Your account already has Premium access. Opening the dashboard...";
    if (status === "already_trialing" || status === "already_active") return "Your Premium trial is already active. Opening the dashboard...";
    return (payload && (payload.MESSAGE || payload.message))
      ? (payload.MESSAGE || payload.message)
      : "Your Premium trial has started. Activation may take a moment.";
  }

  async function loadStatus() {
    if (!window.Api || typeof window.Api.getCurrentMemberAccess !== "function") {
      setBusy(false);
      setMessage("Membership status could not be checked.", "error");
      return;
    }

    try {
      var data = await window.Api.getCurrentMemberAccess();
      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw data || { ERROR: "AUTH_REQUIRED" };
      }
      if (hasPremium(getAccess(data))) {
        var button = $("activateLaunchTrialBtn");
        if (button) button.classList.add("d-none");
        setMessage("Your account already has Premium access. Go to Account to manage membership details.", "success");
        return;
      }
      setBusy(false);
      setMessage("Ready to start. No payment information is required.", "success");
    } catch (err) {
      setBusy(true);
      setMessage(messageForError(err), "error");
    }
  }

  async function startTrial() {
    if (!window.Api || typeof window.Api.startLaunchTrial !== "function") {
      setMessage("Launch trial activation is not available right now.", "error");
      return;
    }

    setBusy(true);
    setMessage("Starting your trial through Stripe. No payment information is required.", "info");

    try {
      var data = await window.Api.startLaunchTrial();
      var nextAction = String((data && (data.nextAction || data.NEXTACTION)) || "").trim().toLowerCase();

      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw data || { MESSAGE: "Launch trial could not be started." };
      }
      if (nextAction !== "stripe_trial_subscription") {
        throw { MESSAGE: "Trial subscription could not be started." };
      }

      setMessage(successMessageForStatus(data), "success");
      window.setTimeout(function () {
        window.location.href = redirectUrlFrom(data);
      }, 1400);
    } catch (err) {
      setBusy(false);
      setMessage(messageForError(err), "error");
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    var button = $("activateLaunchTrialBtn");
    if (button) {
      button.addEventListener("click", startTrial);
    }
    loadStatus();
  });
})(window, document);









