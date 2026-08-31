(function () {
  "use strict";

  if (window.__fpwFloatPlanGuideBound) {
    return;
  }
  window.__fpwFloatPlanGuideBound = true;

  function track(eventName, fields) {
    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
        window.FPWAnalytics.track(eventName, fields);
      }
    } catch (error) {
      // Analytics must never delay guide navigation or printing.
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

  function clearChecklistPrintMode() {
    document.body.classList.remove("fpw-float-guide-checklist-print");
  }

  window.addEventListener("afterprint", clearChecklistPrintMode);

  document.addEventListener("click", function (event) {
    if (!event.target || typeof event.target.closest !== "function") {
      return;
    }

    var printButton = event.target.closest("[data-fpw-float-guide-print]");
    if (printButton) {
      document.body.classList.add("fpw-float-guide-checklist-print");
      window.print();
      return;
    }

    var tocLink = event.target.closest("[data-fpw-float-guide-toc]");
    if (tocLink) {
      track("float_plan_guide_toc_select", {
        section_id: tocLink.getAttribute("data-section-id") || "unknown"
      });
      return;
    }

    var sourceLink = event.target.closest("[data-fpw-float-guide-source]");
    if (sourceLink) {
      track("float_plan_official_source_select", {
        source_org: sourceLink.getAttribute("data-source-org") || "unknown",
        section_id: sourceLink.getAttribute("data-section-id") || "sources",
        destination_host: destinationHost(sourceLink)
      });
      return;
    }

    var relatedLink = event.target.closest("[data-fpw-float-guide-related]");
    if (relatedLink) {
      track("float_plan_related_guide_select", {
        guide_key: relatedLink.getAttribute("data-guide-key") || "unknown",
        placement: relatedLink.getAttribute("data-placement") || "unknown",
        destination_path: destinationPath(relatedLink)
      });
      return;
    }

    var ctaLink = event.target.closest("[data-fpw-float-guide-cta]");
    if (ctaLink) {
      track("float_plan_guide_cta_select", {
        cta_name: ctaLink.getAttribute("data-cta-name") || "unknown",
        placement: ctaLink.getAttribute("data-placement") || "unknown",
        auth_state: ctaLink.getAttribute("data-auth-state") || "unknown",
        destination_path: destinationPath(ctaLink)
      });
    }
  });
})();
