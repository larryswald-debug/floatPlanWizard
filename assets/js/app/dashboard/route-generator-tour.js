(function (window, document) {
  "use strict";

  var STORAGE_BASE_KEY = "fpw.routeGeneratorTour.v1.seen";
  var ROOT_SELECTOR = "#fpwRouteGen";
  var MODAL_SELECTOR = "#routeBuilderModal";
  var TARGET_CLASS = "fpw-help-tour-target";
  var WAIT_INTERVAL_MS = 450;

  var active = null;

  var steps = [
    {
      selector: '[data-tour="route-name"], #routeGenRouteName',
      title: "Name your route",
      text: "Start by naming the route you want to build. This name also fills the Create Route field."
    },
    {
      selector: '[data-tour="route-create"], #routeGenMyRouteCreateBtn',
      title: "Create the route",
      text: "Click Create to save this route shell before choosing waypoints."
    },
    {
      selector: '[data-tour="route-start-waypoint"], #routeGenMyRouteStartWaypointSelect',
      waitAnchor: '[data-tour="route-create"], #routeGenMyRouteCreateBtn',
      title: "Choose the start waypoint",
      text: "After the route is created, select the waypoint where this route starts.",
      waitText: "Create the route first, then the start waypoint control will unlock.",
      isReady: function () {
        return isEnabledControl("#routeGenMyRouteStartWaypointSelect");
      }
    },
    {
      selector: '[data-tour="route-add-leg-waypoint"], #routeGenMyRouteAddWaypointLegBtn',
      waitAnchor: '[data-tour="route-start-waypoint"], #routeGenMyRouteStartWaypointSelect',
      title: "Add a waypoint leg",
      text: "Choose the next waypoint and add it as a leg in this route.",
      waitText: "Choose a start waypoint first, then add a leg endpoint.",
      isReady: function () {
        return isEnabledControl("#routeGenMyRouteAddWaypointLegBtn");
      }
    },
    {
      selector: '[data-tour="route-load"], #routeGenMyRouteLoadBtn',
      title: "Load the route",
      text: "Use Load to preview the saved route in the cruise timeline.",
      waitText: "Select or create a My Route, then Load can preview it.",
      isReady: function () {
        var selectEl = document.getElementById("routeGenMyRouteSelect");
        return !!(selectEl && String(selectEl.value || "").trim());
      }
    },
    {
      selector: '[data-tour="route-cruise-timeline-leg"], #routeGenLegList .fpw-routegen__leg[data-leg-order]',
      waitAnchor: '[data-tour="route-load"], #routeGenMyRouteLoadBtn',
      title: "Review the cruise timeline",
      text: "Each leg appears in the cruise timeline after the route is loaded.",
      waitText: "Click Load to build the cruise timeline. The tour will continue when a leg appears.",
      isReady: function () {
        var legEl = query('[data-tour="route-cruise-timeline-leg"], #routeGenLegList .fpw-routegen__leg[data-leg-order]');
        return !!(legEl && isVisible(legEl));
      }
    }
  ];

  function init() {
    var modalEl = document.querySelector(MODAL_SELECTOR);
    var manualStartEl = document.querySelector('[data-tour-start="route-generator"]');

    if (!modalEl || !document.querySelector(ROOT_SELECTOR)) {
      return;
    }

    modalEl.addEventListener("shown.bs.modal", function () {
      window.setTimeout(function () {
        maybeAutoStart();
      }, 260);
    });

    modalEl.addEventListener("hidden.bs.modal", function () {
      closeTour(true);
    });

    if (manualStartEl) {
      manualStartEl.addEventListener("click", function () {
        startTour({ manual: true });
      });
    }
  }

  function maybeAutoStart() {
    if (!isRouteGeneratorOpen() || hasSeenTour()) {
      return;
    }
    startTour({ manual: false });
  }

  function startTour(options) {
    if (!isRouteGeneratorOpen()) {
      return;
    }

    closeTour(false);

    active = {
      index: 0,
      layer: buildLayer(),
      target: null,
      waiting: false,
      waitTimer: 0,
      observer: null,
      keydownHandler: null
    };

    active.keydownHandler = function (event) {
      if (event.key === "Escape") {
        closeTour(true);
      }
    };

    document.addEventListener("keydown", active.keydownHandler);
    document.body.appendChild(active.layer);
    renderStep();
  }

  function closeTour(markSeen) {
    if (!active) {
      return;
    }

    var focusTarget = active.target;

    if (markSeen) {
      setSeenTour();
    }

    clearWaiting();
    clearTarget();

    if (active.keydownHandler) {
      document.removeEventListener("keydown", active.keydownHandler);
    }

    if (active.layer && active.layer.parentNode) {
      active.layer.parentNode.removeChild(active.layer);
    }

    active = null;

    focusTourTarget(focusTarget);
  }

  function nextStep() {
    if (!active || active.waiting) {
      return;
    }

    if (active.index >= steps.length - 1) {
      closeTour(true);
      return;
    }

    active.index += 1;
    renderStep();
  }

  function previousStep() {
    if (!active || active.index <= 0) {
      return;
    }

    active.index -= 1;
    renderStep();
  }

  function renderStep() {
    if (!active || !isRouteGeneratorOpen()) {
      closeTour(false);
      return;
    }

    clearWaiting();

    var step = steps[active.index];
    var target = query(step.selector);
    var isReady = isStepReady(step, target);
    var anchor = isReady ? target : query(step.waitAnchor || step.selector);

    if (!anchor) {
      anchor = query(ROOT_SELECTOR);
    }

    active.waiting = !isReady;
    setTarget(anchor);
    updateLayerContent(step, isReady);
    positionLayer(anchor);

    if (!isReady) {
      scheduleWaiting();
    }
  }

  function updateLayerContent(step, isReady) {
    var card = active.layer.querySelector(".fpw-help-tour-card");
    var kicker = active.layer.querySelector("[data-route-tour-kicker]");
    var title = active.layer.querySelector("[data-route-tour-title]");
    var copy = active.layer.querySelector("[data-route-tour-copy]");
    var wait = active.layer.querySelector("[data-route-tour-wait]");
    var backBtn = active.layer.querySelector("[data-route-tour-back]");
    var nextBtn = active.layer.querySelector("[data-route-tour-next]");

    if (card) {
      card.classList.toggle("is-waiting", !isReady);
    }
    if (kicker) {
      kicker.textContent = String(active.index + 1) + " of " + String(steps.length);
    }
    if (title) {
      title.textContent = step.title;
    }
    if (copy) {
      copy.textContent = step.text;
    }
    if (wait) {
      wait.hidden = isReady;
      wait.textContent = isReady ? "" : (step.waitText || "Complete the highlighted action to continue.");
    }
    if (backBtn) {
      backBtn.disabled = active.index === 0;
    }
    if (nextBtn) {
      nextBtn.disabled = !isReady;
      nextBtn.textContent = active.index >= steps.length - 1 ? "Done" : (!isReady ? "Waiting" : "Next");
    }

    focusPrimaryControl();
  }

  function buildLayer() {
    var layer = document.createElement("div");
    layer.className = "fpw-help-tour-layer";
    layer.setAttribute("data-fpw-route-generator-tour-layer", "true");
    layer.innerHTML = ''
      + '<div class="fpw-help-tour-scrim" aria-hidden="true"></div>'
      + '<div class="fpw-help-tour-spotlight" aria-hidden="true"></div>'
      + '<div class="fpw-help-tour-card" role="dialog" aria-modal="false" aria-labelledby="routeTourTitle">'
      + '  <button type="button" class="fpw-help-tour-close" data-route-tour-close aria-label="Close route generator tour">×</button>'
      + '  <p class="fpw-help-tour-kicker" data-route-tour-kicker></p>'
      + '  <h2 id="routeTourTitle" class="fpw-help-tour-title" data-route-tour-title></h2>'
      + '  <p class="fpw-help-tour-copy" data-route-tour-copy></p>'
      + '  <p class="fpw-help-tour-wait" data-route-tour-wait aria-live="polite" hidden></p>'
      + '  <div class="fpw-help-tour-actions">'
      + '    <button type="button" data-route-tour-skip>Skip</button>'
      + '    <div class="fpw-help-tour-action-group">'
      + '      <button type="button" data-route-tour-back>Back</button>'
      + '      <button type="button" class="fpw-help-tour-primary" data-route-tour-next>Next</button>'
      + '    </div>'
      + '  </div>'
      + '</div>';

    layer.querySelector("[data-route-tour-close]").addEventListener("click", function () {
      closeTour(true);
    });
    layer.querySelector("[data-route-tour-skip]").addEventListener("click", function () {
      closeTour(true);
    });
    layer.querySelector("[data-route-tour-back]").addEventListener("click", previousStep);
    layer.querySelector("[data-route-tour-next]").addEventListener("click", nextStep);

    return layer;
  }

  function scheduleWaiting() {
    if (!active) {
      return;
    }

    var rootEl = query(ROOT_SELECTOR);

    active.waitTimer = window.setInterval(function () {
      var step = steps[active.index];
      var target = query(step.selector);
      if (isStepReady(step, target)) {
        renderStep();
      }
    }, WAIT_INTERVAL_MS);

    if (rootEl && window.MutationObserver) {
      active.observer = new MutationObserver(function () {
        var step = steps[active.index];
        var target = query(step.selector);
        if (isStepReady(step, target)) {
          renderStep();
        } else {
          positionLayer(active.target);
        }
      });
      active.observer.observe(rootEl, {
        attributes: true,
        childList: true,
        subtree: true
      });
    }
  }

  function clearWaiting() {
    if (!active) {
      return;
    }

    if (active.waitTimer) {
      window.clearInterval(active.waitTimer);
      active.waitTimer = 0;
    }
    if (active.observer) {
      active.observer.disconnect();
      active.observer = null;
    }
  }

  function setTarget(target) {
    clearTarget();
    active.target = target || null;
    if (active.target) {
      active.target.classList.add(TARGET_CLASS);
      if (typeof active.target.scrollIntoView === "function") {
        active.target.scrollIntoView({
          block: "center",
          inline: "nearest",
          behavior: "smooth"
        });
        window.setTimeout(function (target) {
          if (active && active.target === target) {
            positionLayer(target);
          }
        }, 260, active.target);
      }
    }
  }

  function clearTarget() {
    if (active && active.target) {
      active.target.classList.remove(TARGET_CLASS);
      active.target = null;
    }
  }

  function positionLayer(anchor) {
    if (!active || !anchor || !active.layer) {
      return;
    }

    window.requestAnimationFrame(function () {
      if (!active || !active.layer || !anchor) {
        return;
      }

      var rect = anchor.getBoundingClientRect();
      var spotlight = active.layer.querySelector(".fpw-help-tour-spotlight");
      var card = active.layer.querySelector(".fpw-help-tour-card");
      var margin = 14;
      var viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
      var viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;

      if (spotlight) {
        spotlight.style.left = Math.max(8, rect.left - 6) + "px";
        spotlight.style.top = Math.max(8, rect.top - 6) + "px";
        spotlight.style.width = Math.max(20, rect.width + 12) + "px";
        spotlight.style.height = Math.max(20, rect.height + 12) + "px";
      }

      if (!card) {
        return;
      }

      var cardWidth = card.offsetWidth || 360;
      var cardHeight = card.offsetHeight || 220;
      var left = rect.right + margin;
      var top = rect.top;

      if (viewportWidth <= 760) {
        left = 16;
        top = rect.bottom + margin;
        if (top + cardHeight > viewportHeight - 16) {
          top = Math.max(16, rect.top - cardHeight - margin);
        }
      } else if (left + cardWidth > viewportWidth - 16) {
        left = rect.left - cardWidth - margin;
        if (left < 16) {
          left = Math.max(16, Math.min(rect.left, viewportWidth - cardWidth - 16));
          top = rect.bottom + margin;
        }
      }

      top = Math.max(16, Math.min(top, viewportHeight - cardHeight - 16));
      card.style.left = left + "px";
      card.style.top = top + "px";
    });
  }

  function focusPrimaryControl() {
    window.setTimeout(function () {
      if (!active || !active.layer) {
        return;
      }
      var nextBtn = active.layer.querySelector("[data-route-tour-next]");
      var skipBtn = active.layer.querySelector("[data-route-tour-skip]");
      var focusEl = (nextBtn && !nextBtn.disabled) ? nextBtn : skipBtn;
      if (focusEl && typeof focusEl.focus === "function") {
        focusEl.focus();
      }
    }, 0);
  }

  function focusTourTarget(target) {
    if (!target || !isVisible(target)) {
      return;
    }

    var focusEl = isNaturallyFocusable(target) ? target : target.querySelector("button, input, select, textarea, a[href], [tabindex]");
    if (focusEl && typeof focusEl.focus === "function") {
      try {
        focusEl.focus({ preventScroll: true });
      } catch (err) {
        focusEl.focus();
      }
    }
  }

  function isNaturallyFocusable(el) {
    if (!el || !el.tagName) {
      return false;
    }
    var tagName = String(el.tagName).toLowerCase();
    return tagName === "button"
      || tagName === "input"
      || tagName === "select"
      || tagName === "textarea"
      || (tagName === "a" && el.hasAttribute("href"))
      || el.hasAttribute("tabindex");
  }

  function isStepReady(step, target) {
    if (typeof step.isReady === "function") {
      return step.isReady();
    }
    return !!(target && isVisible(target));
  }

  function isEnabledControl(selector) {
    var control = query(selector);
    return !!(control && isVisible(control) && !control.disabled);
  }

  function query(selector) {
    if (!selector) {
      return null;
    }
    try {
      return document.querySelector(selector);
    } catch (err) {
      return null;
    }
  }

  function isVisible(el) {
    if (!el) {
      return false;
    }
    var rect = el.getBoundingClientRect();
    return !!(rect.width || rect.height || el.getClientRects().length);
  }

  function isRouteGeneratorOpen() {
    var modalEl = query(MODAL_SELECTOR);
    var rootEl = query(ROOT_SELECTOR);
    return !!(modalEl && rootEl && modalEl.classList.contains("show") && isVisible(rootEl));
  }

  function hasSeenTour() {
    try {
      return window.localStorage.getItem(getStorageKey()) === "1";
    } catch (err) {
      return false;
    }
  }

  function setSeenTour() {
    try {
      window.localStorage.setItem(getStorageKey(), "1");
    } catch (err) {
      return;
    }
  }

  function getStorageKey() {
    var userId = getDashboardUserId();
    return userId ? (STORAGE_BASE_KEY + ".user." + String(userId)) : STORAGE_BASE_KEY;
  }

  function getDashboardUserId() {
    var state = window.FPW && window.FPW.DashboardState ? window.FPW.DashboardState : {};
    var user = state.currentUser || state.user || null;
    var raw = user
      ? (user.USERID !== undefined ? user.USERID :
        (user.userId !== undefined ? user.userId :
          (user.ID !== undefined ? user.ID : user.id)))
      : "";
    var parsed = parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : "";
  }

  window.addEventListener("resize", function () {
    if (active && active.target) {
      positionLayer(active.target);
    }
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);
