(function (window, document) {
  "use strict";

  var slides = [
    {
      id: "route-builder",
      title: "Build the Route",
      summary: "Turn waypoints, vessel details, fuel, pace, and route legs into one working plan.",
      image: "tour-route-builder-full.png",
      alt: "FloatPlanWizard Route Generator full page",
      hotspots: [
        { id: "route-name", x: 17, y: 13, label: "Name the trip", copy: "Start with a route name your crew can recognize." },
        { id: "waypoint-builder", x: 17, y: 28, label: "Build by waypoints", copy: "Choose start and end points, then add legs." },
        { id: "route-summary", x: 50, y: 13, label: "Route math", copy: "Distance, hours, fuel, speed, and locks update together." },
        { id: "cruise-timeline", x: 51, y: 43, label: "Leg sequence", copy: "Review every route leg before leaving the dock." },
        { id: "vessel-inputs", x: 86, y: 13, label: "Vessel profile", copy: "Speed and fuel details shape the plan." },
        { id: "pace-controls", x: 86, y: 44, label: "Pace and reserve", copy: "Adjust pace, weather, reserve, and daily hours." }
      ]
    },
    {
      id: "route-leg-details",
      title: "Review Leg Details",
      summary: "Expand a route row to see leg details, daily slices, and timing context before editing geometry.",
      image: "tour-route-leg-details-full.png",
      alt: "FloatPlanWizard Route Generator row expanded with leg details",
      hotspots: [
        { id: "selected-leg", x: 51, y: 19, label: "Expanded route leg", copy: "Open any row to inspect the leg before departure." },
        { id: "lock-summary", x: 51, y: 24, label: "Lock details", copy: "Lock counts and timing ranges stay attached to the selected leg." },
        { id: "cruise-days", x: 52, y: 33, label: "Cruise day slices", copy: "Long legs split across travel days using the daily-hours setting." },
        { id: "day-rollup", x: 53, y: 45, label: "Day rollup", copy: "Fuel, reserve, hours, and grouped legs are shown together." },
        { id: "edit-map-button", x: 68, y: 19, label: "Edit Route", copy: "Jump from the row into the route map when geometry needs review." }
      ]
    },
    {
      id: "route-edit-map",
      title: "Edit the Route Map",
      summary: "Open a leg map, inspect the default geometry, and save route overrides when needed.",
      image: "tour-route-edit-map-full.png",
      alt: "FloatPlanWizard leg geometry map opened from Edit Route",
      hotspots: [
        { id: "leg-title", x: 16, y: 7, label: "Leg geometry", copy: "The map opens in the context of the selected route leg." },
        { id: "computed-distance", x: 13, y: 11, label: "Computed distance", copy: "The computed nautical miles are visible while editing." },
        { id: "map-path", x: 51, y: 55, label: "Map geometry", copy: "Start and end markers frame the route segment on the map." },
        { id: "map-layers", x: 87, y: 28, label: "Map layers", copy: "Switch map layers while reviewing route geometry." },
        { id: "save-overrides", x: 87, y: 95, label: "Save override", copy: "Save a corrected path only when the route geometry needs it." }
      ]
    },
    {
      id: "schedule-timing",
      title: "Set the Schedule",
      summary: "Use route math, speed, weather, and daily underway hours to shape practical timing.",
      image: "tour-schedule-timing-full.png",
      alt: "FloatPlanWizard route schedule and timing full page",
      hotspots: [
        { id: "travel-hours", x: 44, y: 13, label: "Travel hours", copy: "Route distance becomes estimated time underway." },
        { id: "adjusted-speed", x: 63, y: 13, label: "Adjusted speed", copy: "Pace and weather change the effective speed." },
        { id: "leg-eta-table", x: 52, y: 38, label: "Leg timing", copy: "Each leg carries distance and timing context." },
        { id: "weather-margin", x: 82, y: 31, label: "Weather margin", copy: "Weather factor adds planning cushion." },
        { id: "daily-hours", x: 82, y: 37, label: "Underway hours", copy: "Daily hours define how much travel fits in a day." },
        { id: "departure-context", x: 17, y: 80, label: "Trip start", copy: "Show when the route is expected to begin." }
      ]
    },
    {
      id: "float-plan-generation",
      title: "Generate the Float Plan",
      summary: "Review the route-backed plan and generate a shareable, downloadable float-plan record.",
      image: "tour-float-plan-generation-full.png",
      alt: "FloatPlanWizard float plan review and PDF generation screen",
      hotspots: [
        { id: "review-step", x: 20, y: 10, label: "Review step", copy: "The final review step gathers the float plan output in one place." },
        { id: "generated-pdf", x: 62, y: 34, label: "Float plan output", copy: "Generate a readable float plan from the trip setup." },
        { id: "plan-pages", x: 22, y: 42, label: "Plan pages", copy: "Preview each generated page before saving or sending." },
        { id: "route-import", x: 63, y: 44, label: "Route imported", copy: "Route details carry into the float plan." },
        { id: "save-plan", x: 68, y: 85, label: "Save plan", copy: "Save the generated record before taking the trip live." },
        { id: "send-activate", x: 68, y: 91, label: "Save and send", copy: "Send the plan and move into monitoring when ready." }
      ]
    },
    {
      id: "active-cruise-monitoring",
      title: "Monitor Active Cruise",
      summary: "Run the underway trip from one command view with route context, check-ins, and delay tools.",
      image: "tour-active-cruise-full.png",
      alt: "FloatPlanWizard Active Cruise full page",
      hotspots: [
        { id: "trip-status", x: 50, y: 4, label: "Underway status", copy: "The active trip state is visible at the top." },
        { id: "route-map", x: 30, y: 17, label: "Live route view", copy: "Map shows route, current position, and destination." },
        { id: "trip-facts", x: 29, y: 32, label: "Trip facts", copy: "Departure, leg, distance, next stop, and ETA stay together." },
        { id: "monitor-card", x: 78, y: 10, label: "Float Plan Monitor", copy: "Monitor status and contact options are attached." },
        { id: "checkin-controls", x: 78, y: 18, label: "Check-ins", copy: "Report On Track, Delayed, Changed Plan, or Secure Night." },
        { id: "delay-tools", x: 78, y: 34, label: "Delay timing", copy: "Manual delay adjusts the trip timeline." }
      ]
    },
    {
      id: "follow-share",
      title: "Share the Follow Page",
      summary: "Give family or friends one private page for route progress, check-ins, and trip context.",
      image: "tour-follow-page-full.png",
      alt: "FloatPlanWizard shared Follow page full page",
      hotspots: [
        { id: "share-link", x: 9, y: 5, label: "Private share link", copy: "Family gets one private page for the trip." },
        { id: "voyage-progress", x: 50, y: 4, label: "Voyage progress", copy: "Status, current leg, check-in, and conditions are summarized." },
        { id: "follow-map", x: 56, y: 10, label: "Shared map", copy: "Route and progress are visible in one map." },
        { id: "track-log", x: 10, y: 8, label: "Track log", copy: "Check-ins are listed chronologically." },
        { id: "float-plan-card", x: 9, y: 15, label: "Float plan access", copy: "Followers can download the filed float plan when allowed." },
        { id: "cruise-timeline", x: 55, y: 46, label: "Cruise timeline", copy: "Followers can scan route legs and planned timing." },
        { id: "voyage-stream", x: 55, y: 94, label: "Voyage stream", copy: "Posts and check-ins build a readable trip stream." }
      ]
    },
    {
      id: "dashboard-workflow",
      title: "Manage the Workflow",
      summary: "Move from saved routes to float plans, Active Cruise, and Follow sharing from the dashboard.",
      image: "tour-dashboard-workflow-full.png",
      alt: "FloatPlanWizard Dashboard full page",
      hotspots: [
        { id: "summary-strip", x: 55, y: 8, label: "Trip context", copy: "Home port, vessel, active route, and readiness are visible." },
        { id: "route-list", x: 39, y: 16, label: "Saved routes", copy: "Routes can be reused, reviewed, and opened." },
        { id: "float-plan-ready", x: 45, y: 22, label: "Float plan ready", copy: "Route rows show when float-plan output is ready." },
        { id: "selected-route", x: 55, y: 34, label: "Route details", copy: "Selected route details stay visible beside the list." },
        { id: "active-actions", x: 55, y: 43, label: "Launch actions", copy: "Open Active Cruise or the Follow Page from the route." },
        { id: "sidebar-nav", x: 5, y: 34, label: "Workspace navigation", copy: "Routes, float plans, monitoring, weather, vessels, contacts, and waypoints stay in reach." }
      ]
    }
  ];

  var activeSlide = 0;
  var activeHotspot = 0;
  var lastRenderedSlide = -1;
  var modal = null;
  var imageBasePath = getBasePath();
  var lastFocused = null;

  function normalizeBasePath(value) {
    if (!value) return "";
    var normalized = String(value).replace(/\/+$/, "");
    if (normalized === "/") return "";
    return normalized.charAt(0) === "/" ? normalized : "/" + normalized;
  }

  function getBasePath() {
    var script = document.currentScript;
    var src = script && script.getAttribute ? script.getAttribute("src") : "";
    var anchor;
    var pathname;
    var markerIndex;

    if (src) {
      anchor = document.createElement("a");
      anchor.href = src;
      pathname = anchor.pathname || src;
      markerIndex = pathname.toLowerCase().indexOf("/assets/js/app/home-visual-tour.js");
      if (markerIndex >= 0) {
        return normalizeBasePath(pathname.slice(0, markerIndex));
      }
    }

    pathname = window.location.pathname || "";
    markerIndex = pathname.toLowerCase().indexOf("/index.cfm");
    if (markerIndex >= 0) {
      return normalizeBasePath(pathname.slice(0, markerIndex));
    }
    return "";
  }

  function track(eventName, params) {
    if (!window.FPWAnalytics || typeof window.FPWAnalytics.track !== "function") {
      return;
    }
    window.FPWAnalytics.track(eventName, params || {});
  }

  function createButton(className, text, type) {
    var button = document.createElement("button");
    button.type = type || "button";
    button.className = className;
    button.textContent = text;
    return button;
  }

  function buildModal() {
    var wrapper = document.createElement("div");
    wrapper.className = "fpw-visual-tour-modal";
    wrapper.setAttribute("data-fpw-visual-tour-modal", "");
    wrapper.setAttribute("hidden", "");

    wrapper.innerHTML = ''
      + '<div class="fpw-visual-tour-backdrop" data-fpw-visual-tour-close></div>'
      + '<div class="fpw-visual-tour-dialog" role="dialog" aria-modal="true" aria-labelledby="fpwVisualTourTitle">'
      + '  <div class="fpw-visual-tour-header">'
      + '    <div>'
      + '      <p class="fpw-visual-tour-kicker">Visual walkthrough</p>'
      + '      <h2 class="fpw-visual-tour-title" id="fpwVisualTourTitle"></h2>'
      + '      <p class="fpw-visual-tour-summary" data-fpw-visual-tour-summary></p>'
      + '    </div>'
      + '    <button type="button" class="fpw-visual-tour-close" data-fpw-visual-tour-close aria-label="Close visual tour">x</button>'
      + '  </div>'
      + '  <div class="fpw-visual-tour-body">'
      + '    <div class="fpw-visual-tour-stage" data-fpw-visual-tour-stage>'
      + '      <div class="fpw-visual-tour-image-shell">'
      + '        <img class="fpw-visual-tour-image" data-fpw-visual-tour-image alt="">'
      + '        <div class="fpw-visual-tour-hotspots" data-fpw-visual-tour-hotspots></div>'
      + '      </div>'
      + '    </div>'
      + '    <aside class="fpw-visual-tour-panel" aria-label="Selected screenshot details">'
      + '      <div class="fpw-visual-tour-progress" data-fpw-visual-tour-progress></div>'
      + '      <div class="fpw-visual-tour-copy">'
      + '        <p class="fpw-visual-tour-step" data-fpw-visual-tour-step></p>'
      + '        <h3 data-fpw-visual-tour-slide-title></h3>'
      + '        <p data-fpw-visual-tour-slide-copy></p>'
      + '      </div>'
      + '      <div class="fpw-visual-tour-callout" data-fpw-visual-tour-callout aria-live="polite"></div>'
      + '    </aside>'
      + '  </div>'
      + '  <div class="fpw-visual-tour-footer">'
      + '    <div class="fpw-visual-tour-nav">'
      + '      <button type="button" class="fpw-visual-tour-button" data-fpw-visual-tour-prev>Previous</button>'
      + '      <button type="button" class="fpw-visual-tour-button" data-fpw-visual-tour-next>Next</button>'
      + '    </div>'
      + '    <a class="fpw-visual-tour-button primary" data-fpw-visual-tour-cta href="' + imageBasePath + '/app/join.cfm">Start Free</a>'
      + '  </div>'
      + '</div>';

    document.body.appendChild(wrapper);
    return wrapper;
  }

  function query(selector) {
    return modal ? modal.querySelector(selector) : null;
  }

  function renderProgress() {
    var progress = query("[data-fpw-visual-tour-progress]");
    if (!progress) return;
    progress.innerHTML = "";
    slides.forEach(function (slide, index) {
      var dot = createButton("fpw-visual-tour-dot", "");
      dot.setAttribute("aria-label", "Show " + slide.title);
      dot.classList.toggle("is-active", index === activeSlide);
      dot.addEventListener("click", function () {
        activeSlide = index;
        activeHotspot = 0;
        render();
        track("home_visual_tour_slide", { slide_id: slide.id, slide_index: index + 1, source: "progress" });
      });
      progress.appendChild(dot);
    });
  }

  function renderHotspots(slide) {
    var container = query("[data-fpw-visual-tour-hotspots]");
    if (!container) return;
    container.innerHTML = "";
    slide.hotspots.forEach(function (hotspot, index) {
      var button = createButton("fpw-visual-tour-hotspot", String(index + 1));
      button.style.left = hotspot.x + "%";
      button.style.top = hotspot.y + "%";
      button.classList.toggle("is-active", index === activeHotspot);
      button.setAttribute("aria-label", hotspot.label + ": " + hotspot.copy);
      button.addEventListener("click", function () {
        activeHotspot = index;
        renderCallout(slide);
        renderHotspots(slide);
        track("home_visual_tour_hotspot", {
          slide_id: slide.id,
          hotspot_id: hotspot.id,
          hotspot_index: index + 1
        });
      });
      container.appendChild(button);
    });
  }

  function renderCallout(slide) {
    var callout = query("[data-fpw-visual-tour-callout]");
    var hotspot = slide.hotspots[activeHotspot] || slide.hotspots[0];
    if (!callout || !hotspot) return;
    callout.innerHTML = ''
      + '<span class="fpw-visual-tour-callout-number">' + (activeHotspot + 1) + '</span>'
      + '<h4>' + hotspot.label + '</h4>'
      + '<p>' + hotspot.copy + '</p>';
  }

  function render() {
    var slide = slides[activeSlide];
    var image = query("[data-fpw-visual-tour-image]");
    var title = query("#fpwVisualTourTitle");
    var summary = query("[data-fpw-visual-tour-summary]");
    var step = query("[data-fpw-visual-tour-step]");
    var slideTitle = query("[data-fpw-visual-tour-slide-title]");
    var slideCopy = query("[data-fpw-visual-tour-slide-copy]");
    var prev = query("[data-fpw-visual-tour-prev]");
    var next = query("[data-fpw-visual-tour-next]");
    var stage = query("[data-fpw-visual-tour-stage]");

    if (!slide) return;

    if (stage && lastRenderedSlide !== activeSlide) {
      stage.scrollTop = 0;
      stage.scrollLeft = 0;
    }
    lastRenderedSlide = activeSlide;
    if (image) {
      image.src = imageBasePath + "/assets/images/home/" + slide.image;
      image.alt = slide.alt;
    }
    if (title) title.textContent = slide.title;
    if (summary) summary.textContent = slide.summary;
    if (step) step.textContent = "Step " + (activeSlide + 1) + " of " + slides.length;
    if (slideTitle) slideTitle.textContent = slide.title;
    if (slideCopy) slideCopy.textContent = slide.summary;
    if (prev) prev.disabled = activeSlide === 0;
    if (next) next.textContent = activeSlide === slides.length - 1 ? "Restart" : "Next";

    renderProgress();
    renderHotspots(slide);
    renderCallout(slide);
  }

  function openTour(startIndex) {
    lastFocused = document.activeElement;
    if (!modal) {
      modal = buildModal();
      bindModalEvents();
    }
    activeSlide = Math.max(0, Math.min(slides.length - 1, startIndex || 0));
    activeHotspot = 0;
    lastRenderedSlide = -1;
    render();
    modal.removeAttribute("hidden");
    document.body.classList.add("fpw-visual-tour-open");
    var close = query("[data-fpw-visual-tour-close]");
    if (close) close.focus();
    track("home_visual_tour_open", { slide_id: slides[activeSlide].id, source: "product_preview" });
  }

  function closeTour() {
    if (!modal) return;
    modal.setAttribute("hidden", "");
    document.body.classList.remove("fpw-visual-tour-open");
    if (lastFocused && typeof lastFocused.focus === "function") {
      lastFocused.focus();
    }
  }

  function showNext() {
    if (activeSlide >= slides.length - 1) {
      activeSlide = 0;
    } else {
      activeSlide += 1;
    }
    activeHotspot = 0;
    render();
    track("home_visual_tour_slide", {
      slide_id: slides[activeSlide].id,
      slide_index: activeSlide + 1,
      source: "next"
    });
  }

  function showPrevious() {
    if (activeSlide <= 0) return;
    activeSlide -= 1;
    activeHotspot = 0;
    render();
    track("home_visual_tour_slide", {
      slide_id: slides[activeSlide].id,
      slide_index: activeSlide + 1,
      source: "previous"
    });
  }

  function bindModalEvents() {
    if (!modal) return;
    modal.addEventListener("click", function (event) {
      if (event.target.closest("[data-fpw-visual-tour-close]")) {
        closeTour();
        return;
      }
      if (event.target.closest("[data-fpw-visual-tour-next]")) {
        showNext();
        return;
      }
      if (event.target.closest("[data-fpw-visual-tour-prev]")) {
        showPrevious();
        return;
      }
      if (event.target.closest("[data-fpw-visual-tour-cta]")) {
        track("home_visual_tour_cta", { slide_id: slides[activeSlide].id, source: "modal" });
      }
    });
  }

  function bindGlobalEvents() {
    document.addEventListener("click", function (event) {
      var trigger = event.target.closest("[data-fpw-visual-tour-open]");
      if (!trigger) return;
      event.preventDefault();
      openTour(0);
    });

    document.addEventListener("keydown", function (event) {
      if (!modal || modal.hasAttribute("hidden")) return;
      if (event.key === "Escape") {
        event.preventDefault();
        closeTour();
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        showNext();
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        showPrevious();
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    bindGlobalEvents();
  });
})(window, document);
