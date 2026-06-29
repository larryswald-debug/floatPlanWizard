(function () {
  "use strict";

  var app = document.querySelector("[data-fpw-preview-app]");
  if (!app || app.getAttribute("data-fpw-preview-bound") === "true") {
    return;
  }
  app.setAttribute("data-fpw-preview-bound", "true");

  var nav = app.querySelector("[data-fpw-preview-subnav]");
  var stage = app.querySelector("[data-fpw-preview-stage]");
  var buttons = Array.prototype.slice.call(app.querySelectorAll("[data-menu]"));
  var panels = Array.prototype.slice.call(app.querySelectorAll("[data-panel]"));

  function getPanel(key) {
    var i;
    for (i = 0; i < panels.length; i += 1) {
      if (panels[i].getAttribute("data-panel") === key) {
        return panels[i];
      }
    }
    return null;
  }

  function setActiveButton(key, isOpen) {
    buttons.forEach(function (button) {
      var matches = button.getAttribute("data-menu") === key;
      button.classList.toggle("is-active", matches && isOpen);
      button.setAttribute("aria-expanded", matches && isOpen && getPanel(key) ? "true" : "false");
    });
  }

  function closePanels(activeKey) {
    panels.forEach(function (panel) {
      panel.classList.remove("is-visible");
      panel.hidden = true;
    });
    setActiveButton(activeKey || "", false);
  }

  function openPanel(key) {
    var panel = getPanel(key);
    if (!panel) {
      closePanels(key);
      setActiveButton(key, true);
      return;
    }
    panels.forEach(function (candidate) {
      var shouldShow = candidate === panel;
      candidate.hidden = !shouldShow;
      candidate.classList.toggle("is-visible", shouldShow);
    });
    setActiveButton(key, true);
  }

  buttons.forEach(function (button) {
    button.addEventListener("click", function (event) {
      var key = button.getAttribute("data-menu");
      event.preventDefault();
      if (getPanel(key)) {
        openPanel(key);
      } else {
        closePanels(key);
        setActiveButton(key, true);
      }
    });
  });

  app.addEventListener("click", function (event) {
    var anchor = event.target.closest("a[href='#']");
    if (anchor) {
      event.preventDefault();
    }
  });

  document.addEventListener("click", function (event) {
    if (!stage || !nav) {
      return;
    }
    if (stage.contains(event.target) || nav.contains(event.target)) {
      return;
    }
    closePanels("");
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      closePanels("");
    }
  });

  openPanel("trip-planning");
})();
