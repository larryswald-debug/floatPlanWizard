(function (window, document) {
  "use strict";

  var tours = {};
  var activeTour = null;

  function storageGet(key) {
    try {
      return window.localStorage ? window.localStorage.getItem(key) : null;
    } catch (err) {
      return null;
    }
  }

  function storageSet(key, value) {
    try {
      if (window.localStorage) {
        window.localStorage.setItem(key, value);
      }
    } catch (err) {
      // localStorage can be blocked; the tour should still run manually.
    }
  }

  function parsePositiveId(value) {
    var parsed = parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }

  function isDashboardPage() {
    return document.body
      && String(document.body.getAttribute("data-fpw-page") || "").toLowerCase() === "dashboard";
  }

  function isElementVisible(el) {
    var rect = null;
    var style = null;
    if (!el || !document.documentElement.contains(el)) return false;
    rect = el.getBoundingClientRect();
    if (!rect || rect.width <= 0 || rect.height <= 0) return false;
    style = window.getComputedStyle ? window.getComputedStyle(el) : null;
    if (style && (style.display === "none" || style.visibility === "hidden" || style.opacity === "0")) {
      return false;
    }
    return true;
  }

  function getLinkedHashTarget(el) {
    var href = "";
    if (!el || !el.getAttribute) return null;
    href = el.getAttribute("href") || "";
    if (href.charAt(0) !== "#") return null;
    try {
      return document.getElementById(href.slice(1));
    } catch (err) {
      return null;
    }
  }

  function isLockedTarget(el) {
    var linkedTarget = getLinkedHashTarget(el);
    if (!el) return true;
    if (el.classList && el.classList.contains("fpw-basic-locked-panel")) return true;
    if (el.getAttribute && el.getAttribute("aria-disabled") === "true") return true;
    if (el.closest && el.closest(".fpw-basic-locked-panel")) return true;
    if (linkedTarget) {
      if (linkedTarget.classList && linkedTarget.classList.contains("fpw-basic-locked-panel")) return true;
      if (linkedTarget.getAttribute && linkedTarget.getAttribute("aria-disabled") === "true") return true;
    }
    return false;
  }

  function findStepTarget(step) {
    var primary = null;
    var fallback = null;
    if (!step || !step.selector) return null;
    primary = document.querySelector(step.selector);
    if (primary && isElementVisible(primary) && !isLockedTarget(primary)) {
      return primary;
    }
    if (primary && !isElementVisible(primary) && step.skipWhenPrimaryHidden) {
      return null;
    }
    if (step.fallbackSelector && !primary) {
      fallback = document.querySelector(step.fallbackSelector);
      if (fallback && isElementVisible(fallback) && !isLockedTarget(fallback)) {
        return fallback;
      }
    }
    return null;
  }

  function resolveSteps(steps) {
    var resolved = [];
    (steps || []).forEach(function (step) {
      var target = findStepTarget(step);
      if (target) {
        resolved.push({
          title: step.title,
          text: step.text,
          target: target
        });
      }
    });
    return resolved;
  }

  function buildLayer() {
    var layer = document.createElement("div");
    layer.className = "fpw-help-tour-layer";
    layer.setAttribute("data-fpw-help-tour-layer", "true");
    layer.innerHTML = ""
      + '<div class="fpw-help-tour-scrim" aria-hidden="true"></div>'
      + '<div class="fpw-help-tour-spotlight" aria-hidden="true"></div>'
      + '<section class="fpw-help-tour-card" role="dialog" aria-modal="false" aria-labelledby="fpwHelpTourTitle">'
      + '  <button type="button" class="fpw-help-tour-close" data-tour-close aria-label="Close tour">x</button>'
      + '  <p class="fpw-help-tour-kicker" data-tour-count></p>'
      + '  <h2 class="fpw-help-tour-title" id="fpwHelpTourTitle" data-tour-title></h2>'
      + '  <p class="fpw-help-tour-copy" data-tour-copy></p>'
      + '  <div class="fpw-help-tour-actions">'
      + '    <button type="button" data-tour-skip>Skip</button>'
      + '    <div class="fpw-help-tour-action-group">'
      + '      <button type="button" data-tour-back>Back</button>'
      + '      <button type="button" class="fpw-help-tour-primary" data-tour-next>Next</button>'
      + '    </div>'
      + '  </div>'
      + '</section>';
    document.body.appendChild(layer);
    return layer;
  }

  function getLayer() {
    return document.querySelector("[data-fpw-help-tour-layer]") || buildLayer();
  }

  function clearTarget() {
    if (activeTour && activeTour.currentTarget) {
      activeTour.currentTarget.classList.remove("fpw-help-tour-target");
      activeTour.currentTarget = null;
    }
  }

  function positionTour() {
    var rect = null;
    var card = null;
    var spotlight = null;
    var cardRect = null;
    var top = 0;
    var left = 0;
    var margin = 14;
    if (!activeTour || !activeTour.currentTarget || !activeTour.layer) return;
    card = activeTour.layer.querySelector(".fpw-help-tour-card");
    spotlight = activeTour.layer.querySelector(".fpw-help-tour-spotlight");
    rect = activeTour.currentTarget.getBoundingClientRect();
    if (!card || !spotlight || !rect) return;

    spotlight.style.left = Math.max(8, rect.left - 6) + "px";
    spotlight.style.top = Math.max(8, rect.top - 6) + "px";
    spotlight.style.width = Math.max(0, rect.width + 12) + "px";
    spotlight.style.height = Math.max(0, rect.height + 12) + "px";

    cardRect = card.getBoundingClientRect();
    top = rect.bottom + margin;
    if (top + cardRect.height > window.innerHeight - margin) {
      top = rect.top - cardRect.height - margin;
    }
    if (top < margin) {
      top = margin;
    }
    left = rect.left + Math.min(24, Math.max(0, rect.width - cardRect.width) / 2);
    left = Math.min(Math.max(margin, left), Math.max(margin, window.innerWidth - cardRect.width - margin));
    card.style.top = Math.round(top) + "px";
    card.style.left = Math.round(left) + "px";
  }

  function renderActiveStep() {
    var step = null;
    var layer = null;
    var countEl = null;
    var titleEl = null;
    var copyEl = null;
    var backBtn = null;
    var nextBtn = null;
    if (!activeTour || !activeTour.steps.length) return;
    step = activeTour.steps[activeTour.index];
    layer = activeTour.layer;
    clearTarget();
    activeTour.currentTarget = step.target;
    activeTour.currentTarget.classList.add("fpw-help-tour-target");

    countEl = layer.querySelector("[data-tour-count]");
    titleEl = layer.querySelector("[data-tour-title]");
    copyEl = layer.querySelector("[data-tour-copy]");
    backBtn = layer.querySelector("[data-tour-back]");
    nextBtn = layer.querySelector("[data-tour-next]");
    if (countEl) countEl.textContent = (activeTour.index + 1) + " of " + activeTour.steps.length;
    if (titleEl) titleEl.textContent = step.title || "";
    if (copyEl) copyEl.textContent = step.text || "";
    if (backBtn) backBtn.disabled = activeTour.index === 0;
    if (nextBtn) nextBtn.textContent = activeTour.index === activeTour.steps.length - 1 ? "Done" : "Next";

    try {
      step.target.scrollIntoView({ behavior: "smooth", block: "center", inline: "nearest" });
    } catch (err) {
      step.target.scrollIntoView();
    }
    window.setTimeout(positionTour, 260);
    positionTour();
  }

  function markSeen(tour) {
    if (tour && tour.storageKey) {
      storageSet(tour.storageKey, "1");
    }
  }

  function closeTour(markDismissed) {
    var layer = null;
    if (!activeTour) return;
    if (markDismissed) {
      markSeen(activeTour);
    }
    clearTarget();
    layer = activeTour.layer;
    if (layer && layer.parentNode) {
      layer.parentNode.removeChild(layer);
    }
    window.removeEventListener("resize", positionTour);
    window.removeEventListener("scroll", positionTour, true);
    activeTour = null;
  }

  function bindLayer(layer) {
    if (!layer || layer.getAttribute("data-tour-bound") === "true") return;
    layer.addEventListener("click", function (event) {
      var closeBtn = event.target.closest("[data-tour-close]");
      var skipBtn = event.target.closest("[data-tour-skip]");
      var backBtn = event.target.closest("[data-tour-back]");
      var nextBtn = event.target.closest("[data-tour-next]");
      if (closeBtn || skipBtn) {
        closeTour(true);
        return;
      }
      if (backBtn && activeTour) {
        activeTour.index = Math.max(0, activeTour.index - 1);
        renderActiveStep();
        return;
      }
      if (nextBtn && activeTour) {
        if (activeTour.index >= activeTour.steps.length - 1) {
          closeTour(true);
          return;
        }
        activeTour.index += 1;
        renderActiveStep();
      }
    });
    layer.setAttribute("data-tour-bound", "true");
  }

  function start(name, options) {
    var tour = tours[name];
    var resolved = null;
    var layer = null;
    var startOptions = options || {};
    var storageKey = "";
    if (!tour) return false;
    resolved = resolveSteps(tour.steps);
    if (!resolved.length) return false;
    storageKey = resolveTourStorageKey(tour, name);
    closeTour(false);
    layer = getLayer();
    bindLayer(layer);
    activeTour = {
      name: name,
      steps: resolved,
      index: 0,
      layer: layer,
      storageKey: storageKey,
      auto: startOptions.auto === true,
      currentTarget: null
    };
    window.addEventListener("resize", positionTour);
    window.addEventListener("scroll", positionTour, true);
    renderActiveStep();
    return true;
  }

  function maybeAutoStart(name) {
    var tour = tours[name];
    var storageKey = "";
    if (!tour || !tour.storageKey) return false;
    storageKey = resolveTourStorageKey(tour, name);
    if (storageKey && storageGet(storageKey) === "1") return false;
    return start(name, { auto: true });
  }

  function register(name, steps, options) {
    tours[name] = {
      steps: steps || [],
      storageKey: options && options.storageKey ? options.storageKey : ""
    };
  }

  function getDashboardUserId() {
    var state = window.FPW && window.FPW.DashboardState ? window.FPW.DashboardState : {};
    var user = state.currentUser || {};
    return parsePositiveId(user.USERID || user.userId || user.ID || user.id);
  }

  function resolveTourStorageKey(tour, name) {
    var baseKey = tour && tour.storageKey ? tour.storageKey : "";
    var userId = 0;
    if (!baseKey) return "";
    if (name === "dashboard") {
      userId = getDashboardUserId();
      if (userId > 0) {
        return baseKey + ".user." + userId;
      }
    }
    return baseKey;
  }

  function bindDashboardTourTriggers() {
    var triggers = document.querySelectorAll("[data-tour-start='dashboard']");
    Array.prototype.forEach.call(triggers, function (trigger) {
      if (trigger.getAttribute("data-tour-bound") === "true") return;
      trigger.addEventListener("click", function () {
        start("dashboard", { force: true });
      });
      trigger.setAttribute("data-tour-bound", "true");
    });
  }

  function registerDashboardTour() {
    if (!isDashboardPage()) return;
    register("dashboard", [
      {
        selector: "[data-tour-id='dashboard-vessel-setup']",
        title: "Add your vessel",
        text: "Start by adding the boat you will use for your trip. Your vessel details help build a more complete float plan."
      },
      {
        selector: "[data-tour-id='dashboard-contacts-setup']",
        title: "Add your contacts",
        text: "Add the people who should receive your float plan and know your trip details."
      },
      {
        selector: "[data-tour-id='dashboard-passengers-setup']",
        title: "Add passengers",
        text: "Add the people expected to be onboard so your float plan reflects who is traveling with you."
      },
      {
        selector: "[data-tour-id='dashboard-operators-setup']",
        title: "Add your operator",
        text: "Add the captain or operator responsible for the trip so the float plan has the right boating contact information."
      },
      {
        selector: "[data-tour-id='dashboard-waypoints']",
        title: "Use waypoints when helpful",
        text: "Waypoints are optional, but they help describe useful stops, markers, and places you may use when planning routes."
      },
      {
        selector: "[data-tour-id='dashboard-create-route']",
        fallbackSelector: "[data-tour-id='dashboard-route-workspace']",
        skipWhenPrimaryHidden: true,
        title: "Create your route",
        text: "After your setup information is ready, start a route and review the trip details before creating or sending a float plan."
      }
    ], {
      storageKey: "fpw.help.dashboard.v1.seen"
    });
    bindDashboardTourTriggers();
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && activeTour) {
      closeTour(true);
    }
  });

  document.addEventListener("show.bs.modal", function () {
    closeTour(false);
  });

  document.addEventListener("DOMContentLoaded", function () {
    registerDashboardTour();
  });

  window.FPWHelpTour = {
    register: register,
    start: start,
    maybeAutoStart: maybeAutoStart
  };
})(window, document);
