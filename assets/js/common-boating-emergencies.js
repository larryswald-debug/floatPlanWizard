(function () {
  "use strict";

  if (window.__fpwBoatingEmergencyGuideBound) {
    return;
  }
  window.__fpwBoatingEmergencyGuideBound = true;

  var GUIDE_ID = "boating_emergencies";

  function track(eventName, fields) {
    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
        window.FPWAnalytics.track(eventName, fields);
      }
    } catch (error) {
      // Analytics must never delay emergency-reference navigation or printing.
    }
  }

  function destinationPath(link) {
    try {
      return new URL(link.href, window.location.href).pathname;
    } catch (error) {
      return "";
    }
  }

  function destinationHost(link) {
    try {
      return new URL(link.href, window.location.href).hostname;
    } catch (error) {
      return "";
    }
  }

  document.addEventListener("click", function (event) {
    if (!event.target || typeof event.target.closest !== "function") {
      return;
    }

    var cardLink = event.target.closest("[data-fpw-guide-card]");
    if (cardLink) {
      track("guide_card_download", {
        guide_id: GUIDE_ID,
        card_id: cardLink.getAttribute("data-card-id") || "unknown",
        file_name: cardLink.getAttribute("data-file-name") || "unknown",
        placement: cardLink.getAttribute("data-placement") || "download_section"
      });
      return;
    }

    var printButton = event.target.closest("[data-fpw-guide-print]");
    if (printButton) {
      track("guide_print_select", {
        guide_id: GUIDE_ID,
        placement: printButton.getAttribute("data-placement") || "unknown"
      });
      window.print();
      return;
    }

    var tocLink = event.target.closest("[data-fpw-guide-toc]");
    if (tocLink) {
      track("guide_toc_select", {
        guide_id: GUIDE_ID,
        section_id: tocLink.getAttribute("data-section-id") || "unknown"
      });
      return;
    }

    var ctaLink = event.target.closest(
      '[data-fpw-action-cta][data-fpw-track="guide_cta_select"]'
    );
    if (ctaLink) {
      track("guide_cta_select", {
        guide_id: GUIDE_ID,
        cta_name: ctaLink.getAttribute("data-fpw-track-cta-type") || "unknown",
        placement: ctaLink.getAttribute("data-fpw-track-section") || "unknown",
        destination_path: destinationPath(ctaLink)
      });
      return;
    }

    var sourceLink = event.target.closest("[data-fpw-guide-source]");
    if (sourceLink) {
      track("guide_source_select", {
        guide_id: GUIDE_ID,
        source_org: sourceLink.getAttribute("data-source-org") || "unknown",
        destination_host: destinationHost(sourceLink),
        section_id: sourceLink.getAttribute("data-section-id") || "sources"
      });
    }
  });
})();
