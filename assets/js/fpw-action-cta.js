(function () {
  "use strict";

  var SIGNUP_ATTRIBUTION_STORAGE_KEY = "fpw_signup_attribution";
  var SIGNUP_ATTRIBUTION_CONTENT_TYPES = {
    boat_fuel_calculator: "seo_tool",
    great_loop_locks: "seo_hub"
  };

  if (window.__FPW_ACTION_CTA_TRACKING_BOUND__) return;
  window.__FPW_ACTION_CTA_TRACKING_BOUND__ = true;

  function buildSignupAttribution(target) {
    var landingKey = target.getAttribute("data-fpw-track-source-page") || "";
    var contentType = SIGNUP_ATTRIBUTION_CONTENT_TYPES[landingKey] || "";
    var ctaType = target.getAttribute("data-fpw-track-cta-type") || "";
    var authState = target.getAttribute("data-fpw-track-auth-state") || "";
    var destinationKey = target.getAttribute("data-fpw-track-destination-key") || "";

    if (authState !== "signed_out" || destinationKey !== "join" || !contentType || ctaType !== "plan_route") {
      return null;
    }

    return {
      landing_key: landingKey,
      source_content_type: contentType,
      cta_type: ctaType
    };
  }

  function storeSignupAttribution(target) {
    var attribution = buildSignupAttribution(target);
    if (!attribution) return;

    try {
      window.sessionStorage.setItem(SIGNUP_ATTRIBUTION_STORAGE_KEY, JSON.stringify(attribution));
    } catch (storageError) {}
  }

  document.addEventListener("click", function (event) {
    var target = event.target && event.target.closest
      ? event.target.closest("[data-fpw-action-cta][data-fpw-track]")
      : null;
    var eventName;

    if (!target) return;

    eventName = target.getAttribute("data-fpw-track") || "";
    if (!eventName) return;

    storeSignupAttribution(target);

    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
        window.FPWAnalytics.track(eventName, {
          source_page: target.getAttribute("data-fpw-track-source-page") || "",
          section: target.getAttribute("data-fpw-track-section") || "",
          cta_type: target.getAttribute("data-fpw-track-cta-type") || "",
          label: target.getAttribute("data-fpw-track-label") || "",
          auth_state: target.getAttribute("data-fpw-track-auth-state") || "",
          destination_key: target.getAttribute("data-fpw-track-destination-key") || ""
        });
      }
    } catch (error) {}
  });
})();
