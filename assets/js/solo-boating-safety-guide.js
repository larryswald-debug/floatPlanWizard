(function () {
  "use strict";

  if (window.__fpwSoloPdfDownloadsBound) {
    return;
  }
  window.__fpwSoloPdfDownloadsBound = true;

  document.addEventListener("click", function (event) {
    if (!event.target || typeof event.target.closest !== "function") {
      return;
    }

    var link = event.target.closest(
      "[data-fpw-solo-pdf-download][data-fpw-track], [data-fpw-solo-ebook-download][data-fpw-track]"
    );
    if (!link) {
      return;
    }

    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
        var fields = {
          source_page: link.getAttribute("data-fpw-track-source-page"),
          section: link.getAttribute("data-fpw-track-section"),
          document_key: link.getAttribute("data-fpw-track-document-key"),
          label: link.getAttribute("data-fpw-track-label")
        };
        var format = link.getAttribute("data-fpw-track-format");
        if (format) {
          fields.format = format;
        }
        window.FPWAnalytics.track(link.getAttribute("data-fpw-track"), fields);
      }
    } catch (error) {
      // Analytics must never delay or block a direct publication download.
    }
  });
})();
