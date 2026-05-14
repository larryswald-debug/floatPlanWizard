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

  function setMessage(message, tone) {
    var el = $("startTrialMessage");
    if (!el) return;
    el.textContent = message || "";
    el.classList.remove("membership-message-error", "membership-message-success");
    if (tone === "error" || tone === "danger") el.classList.add("membership-message-error");
    if (tone === "success") el.classList.add("membership-message-success");
  }

  function setBusy(isBusy) {
    var button = $("activateLaunchTrialBtn");
    if (!button) return;
    button.disabled = !!isBusy;
    button.setAttribute("aria-disabled", isBusy ? "true" : "false");
    button.textContent = isBusy ? "Opening..." : "Activate Free Trial";
  }

  function checkoutUrlFrom(payload) {
    return payload && (payload.checkoutUrl || payload.CHECKOUT_URL)
      ? String(payload.checkoutUrl || payload.CHECKOUT_URL).trim()
      : "";
  }

  function messageForError(error) {
    var code = getErrorCode(error).toUpperCase();
    if (code === "FREE_TRIAL_ALREADY_USED") return "A free trial has already been used for this account.";
    if (code === "LAUNCH_PROMO_NOT_AVAILABLE") return "The launch trial is not available right now.";
    if (code === "LAUNCH_PROMO_AMBIGUOUS") return "Launch trial setup needs attention before checkout can start.";
    if (code === "ALREADY_PREMIUM") return "Your account already has Premium access.";
    if (code === "STRIPE_CONFIG_MISSING") return "Trial checkout is not available right now.";
    if (code === "STRIPE_CHECKOUT_FAILED") return "Trial checkout could not be started.";
    if (code === "STRIPE_CHECKOUT_LOOKUP_FAILED") return "Free-trial checkout could not be checked. Please try again shortly.";
    if (code === "STRIPE_CHECKOUT_CONFIRMATION_PENDING") return "Free-trial checkout is being confirmed. Please refresh shortly.";
    if (code === "AUTH_REQUIRED") return "Log in to start the launch trial.";
    return (error && (error.MESSAGE || error.message)) ? (error.MESSAGE || error.message) : "Launch trial could not be started.";
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
      setMessage("Ready to start your no-credit-card Premium trial.", "success");
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
    setMessage("Opening secure Stripe Checkout...", "info");

    try {
      var data = await window.Api.startLaunchTrial();
      var nextAction = String((data && (data.nextAction || data.NEXTACTION)) || "").trim().toLowerCase();
      var checkoutUrl = checkoutUrlFrom(data);

      if (!data || (data.SUCCESS !== true && data.success !== true)) {
        throw data || { MESSAGE: "Launch trial could not be started." };
      }
      if (nextAction !== "stripe_trial_checkout" || !checkoutUrl) {
        throw { MESSAGE: "Trial checkout could not be started." };
      }

      window.location.href = checkoutUrl;
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
