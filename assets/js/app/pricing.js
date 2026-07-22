(function (window, document) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";
  var JOIN_PATH = BASE_PATH + "/app/join.cfm";

  function getCheckoutUrl(payload) {
    return payload && (payload.checkoutUrl || payload.CHECKOUT_URL)
      ? String(payload.checkoutUrl || payload.CHECKOUT_URL)
      : "";
  }

  function getErrorCode(error) {
    if (error && typeof error.ERROR === "string") return String(error.ERROR);
    if (error && typeof error.errorCode === "string") return String(error.errorCode);
    if (error && error.ERROR && error.ERROR.CODE) return String(error.ERROR.CODE);
    return "";
  }

  function setButtonsBusy(buttons, busy) {
    buttons.forEach(function (button) {
      button.disabled = busy || button.getAttribute("aria-disabled") === "true";
    });
  }

  function startCheckout(button, buttons) {
    var checkoutType = String(button.getAttribute("data-pricing-checkout") || "").trim().toLowerCase();
    var originalText = button.textContent;

    if (button.disabled || button.getAttribute("aria-disabled") === "true") {
      return;
    }

    if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
      window.FPWAnalytics.track(
        checkoutType === "one_trip" ? "buy_one_trip_clicked" : (checkoutType === "monthly" ? "monthly_selected" : "annual_selected"),
        { source: "pricing_page" }
      );
    }

    if (!window.Api || typeof window.Api.createPremiumCheckoutSession !== "function") {
      window.alert("Premium checkout is not available right now.");
      return;
    }

    setButtonsBusy(buttons, true);
    button.textContent = "Opening...";

    window.Api.createPremiumCheckoutSession(checkoutType)
      .then(function (data) {
        var checkoutUrl = getCheckoutUrl(data);
        if (!data || (data.SUCCESS !== true && data.success !== true) || !checkoutUrl) {
          throw data || { MESSAGE: "Premium checkout is not available right now." };
        }
        if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
          window.FPWAnalytics.track("begin_checkout", {
            checkout_type: checkoutType || "premium",
            source: "pricing_page"
          });
        }
        window.location.href = checkoutUrl;
      })
      .catch(function (err) {
        var code = getErrorCode(err).toUpperCase();
        if (code === "AUTH_REQUIRED" || code === "INVALID_SESSION") {
          window.location.href = JOIN_PATH;
          return;
        }
        if (code === "ALREADY_PREMIUM") {
          window.alert("Your account already has Premium access.");
          return;
        }
        window.alert((err && (err.MESSAGE || err.message)) ? (err.MESSAGE || err.message) : "Premium checkout is not available right now.");
      })
      .finally(function () {
        setButtonsBusy(buttons, false);
        button.textContent = originalText;
      });
  }

  document.addEventListener("DOMContentLoaded", function () {
    var buttons = Array.prototype.slice.call(document.querySelectorAll("[data-pricing-checkout]"));
    buttons.forEach(function (button) {
      button.addEventListener("click", function () {
        startCheckout(button, buttons);
      });
    });
  });
})(window, document);
