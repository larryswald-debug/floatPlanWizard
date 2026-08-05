(function () {
  "use strict";

  if (window.__FPW_ACTION_CTA_TRACKING_BOUND__) return;
  window.__FPW_ACTION_CTA_TRACKING_BOUND__ = true;

  document.addEventListener("click", function (event) {
    var target = event.target && event.target.closest
      ? event.target.closest("[data-fpw-action-cta][data-fpw-track]")
      : null;
    var eventName;

    if (!target) return;

    eventName = target.getAttribute("data-fpw-track") || "";
    if (!eventName) return;

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
