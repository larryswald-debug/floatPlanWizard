(function () {
  "use strict";
  var drawer = document.getElementById("fpwHelpDrawer");
  if (!drawer || drawer.dataset.bound || typeof drawer.showModal !== "function" || !window.fetch) return;
  drawer.dataset.bound = "true";

  var manualUrl = new URL(drawer.dataset.manualUrl, window.location.href);
  var content = drawer.querySelector("[data-help-content]");
  var scroll = drawer.querySelector("[data-help-scroll]");
  var status = drawer.querySelector("[data-help-status]");
  var retry = drawer.querySelector("[data-help-retry]");
  var full = drawer.querySelector("[data-help-full]");
  var closeButton = drawer.querySelector("[data-help-close]");
  var triggers = Array.prototype.slice.call(document.querySelectorAll("a.fpw-context-help"));
  var manualPromise = null;
  var currentUrl = manualUrl;
  var opener = null;
  var savedPage = null;
  var closeTimer = null;
  var loadVersion = 0;
  var closing = false;

  function isManual(url) {
    return url.origin === manualUrl.origin && url.pathname === manualUrl.pathname && !url.search;
  }

  function rememberStyle(element, property) {
    return { element: element, property: property, value: element.style.getPropertyValue(property), priority: element.style.getPropertyPriority(property) };
  }

  function lockPage() {
    var html = document.documentElement;
    var body = document.body;
    var gap = window.innerWidth - html.clientWidth;
    savedPage = {
      x: window.scrollX, y: window.scrollY,
      styles: [rememberStyle(html, "overflow"), rememberStyle(body, "overflow"), rememberStyle(body, "padding-right"), rememberStyle(html, "scroll-behavior")]
    };
    // Freeze an in-progress smooth scroll at the position where help was opened.
    html.style.setProperty("scroll-behavior", "auto");
    window.scrollTo(savedPage.x, savedPage.y);
    if (gap > 0) body.style.setProperty("padding-right", (parseFloat(getComputedStyle(body).paddingRight) + gap) + "px");
    html.style.setProperty("overflow", "hidden");
    body.style.setProperty("overflow", "hidden");
  }

  function restorePage() {
    if (!savedPage) return;
    var saved = savedPage;
    savedPage = null;
    saved.styles.forEach(function (item) {
      if (item.value) item.element.style.setProperty(item.property, item.value, item.priority);
      else item.element.style.removeProperty(item.property);
    });
    triggers.forEach(function (link) { link.setAttribute("aria-expanded", "false"); });
    if (opener && opener.isConnected) opener.focus({ preventScroll: true });
    document.documentElement.style.setProperty("scroll-behavior", "auto");
    window.scrollTo(saved.x, saved.y);
    var behavior = saved.styles[3];
    if (behavior.value) behavior.element.style.setProperty(behavior.property, behavior.value, behavior.priority);
    else behavior.element.style.removeProperty(behavior.property);
  }

  function close() {
    if (!drawer.open || closing) return;
    closing = true;
    loadVersion++;
    drawer.classList.remove("is-visible");
    function finish() {
      closeTimer = null;
      drawer.close();
      closing = false;
      restorePage();
    }
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) finish();
    else closeTimer = window.setTimeout(finish, 220);
  }

  function getManual() {
    if (manualPromise) return manualPromise;
    var controller = new AbortController();
    var timeout = window.setTimeout(function () { controller.abort(); }, 15000);
    manualPromise = fetch(manualUrl.href, { credentials: "same-origin", signal: controller.signal })
      .then(function (response) {
        if (!response.ok || !isManual(new URL(response.url)) || !(response.headers.get("content-type") || "").includes("text/html")) throw new Error("Help unavailable");
        return response.text();
      })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, "text/html");
        if (!doc.querySelector("[data-manual-chapter]") || !doc.getElementById("manualContents")) throw new Error("Help unavailable");
        return doc;
      })
      .catch(function (error) { manualPromise = null; throw error; })
      .finally(function () { window.clearTimeout(timeout); });
    return manualPromise;
  }

  function safeUrl(value, image) {
    try {
      var url = new URL(value, manualUrl);
      if (/^https?:$/.test(url.protocol) || (!image && /^(mailto|tel):$/.test(url.protocol))) return url.href;
    } catch (_) { /* Ignore unusable resource URLs. */ }
    return "";
  }

  function prepareContent(source) {
    var clone = source.cloneNode(true);
    // Import documentation only: never run scripts or embed application chrome.
    clone.querySelectorAll("script, style, link, meta, base, iframe, object, embed, form").forEach(function (node) { node.remove(); });
    var nodes = [clone].concat(Array.prototype.slice.call(clone.querySelectorAll("*")));
    nodes.forEach(function (node) {
      Array.prototype.slice.call(node.attributes).forEach(function (attr) {
        if (/^on/i.test(attr.name) || attr.name === "srcdoc") node.removeAttribute(attr.name);
      });
      if (node.id) {
        node.dataset.helpSourceId = node.id;
        node.id = "fpw-help-" + node.id;
      }
      ["aria-labelledby", "aria-describedby", "headers", "for"].forEach(function (attr) {
        if (node.hasAttribute(attr)) node.setAttribute(attr, node.getAttribute(attr).split(/\s+/).map(function (id) { return "fpw-help-" + id; }).join(" "));
      });
      ["src", "poster"].forEach(function (attr) {
        if (node.hasAttribute(attr)) {
          var resolved = safeUrl(node.getAttribute(attr), true);
          if (resolved) node.setAttribute(attr, resolved);
          else node.removeAttribute(attr);
        }
      });
      if (node.hasAttribute("srcset")) {
        node.setAttribute("srcset", node.getAttribute("srcset").split(",").map(function (candidate) {
          var parts = candidate.trim().split(/\s+/);
          var resolved = safeUrl(parts.shift(), true);
          return resolved ? [resolved].concat(parts).join(" ") : "";
        }).filter(Boolean).join(", "));
      }
      if (node.tagName === "A" && node.hasAttribute("href")) {
        var href = safeUrl(node.getAttribute("href"), false);
        if (!href) { node.removeAttribute("href"); return; }
        node.href = href;
        if (!isManual(new URL(href))) {
          node.target = "_blank";
          node.rel = "noopener";
        }
      }
    });
    return clone;
  }

  function showContent(url) {
    var version = ++loadVersion;
    currentUrl = url;
    full.href = url.href;
    content.replaceChildren();
    content.setAttribute("aria-busy", "true");
    status.hidden = false;
    status.textContent = "Loading help…";
    retry.hidden = true;
    scroll.scrollTop = 0;
    getManual().then(function (doc) {
      if (version !== loadVersion || !drawer.open || closing) return;
      var id = decodeURIComponent(url.hash.slice(1)) || "manualContents";
      var target = doc.getElementById(id);
      var source = target && (target.closest("[data-manual-chapter]") || target.closest("#manualContents"));
      if (!source) throw new Error("Help section unavailable");
      var clone = prepareContent(source);
      content.replaceChildren(clone);
      content.removeAttribute("aria-busy");
      status.textContent = "";
      status.hidden = true;
      var heading = clone.querySelector("h2");
      if (heading) { heading.tabIndex = -1; heading.focus({ preventScroll: true }); }
      scroll.scrollTop = 0;
      if (target !== source) {
        var destination = document.getElementById("fpw-help-" + id);
        if (destination) scroll.scrollTop += destination.getBoundingClientRect().top - scroll.getBoundingClientRect().top - 24;
      }
    }).catch(function () {
      if (version !== loadVersion || !drawer.open || closing) return;
      content.removeAttribute("aria-busy");
      status.hidden = false;
      status.textContent = "Help could not be loaded. Try again or open the full manual in a new tab. Your page is still here.";
      retry.hidden = false;
    });
  }

  function open(link) {
    var url = new URL(link.href);
    if (!isManual(url)) return false;
    if (closeTimer) window.clearTimeout(closeTimer);
    closeTimer = null;
    closing = false;
    opener = link;
    if (!drawer.open) {
      lockPage();
      drawer.showModal();
      closeButton.focus({ preventScroll: true });
    }
    link.setAttribute("aria-expanded", "true");
    // Establish the offscreen position before starting the transition.
    void drawer.offsetWidth;
    drawer.classList.add("is-visible");
    showContent(url);
    return true;
  }

  triggers.forEach(function (link) {
    link.setAttribute("aria-haspopup", "dialog");
    link.setAttribute("aria-controls", drawer.id);
    link.setAttribute("aria-expanded", "false");
    link.addEventListener("click", function (event) {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      if (open(link)) event.preventDefault();
    });
  });
  content.addEventListener("click", function (event) {
    var link = event.target.closest("a[href]");
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || link.target === "_blank") return;
    var url = new URL(link.href);
    if (isManual(url)) { event.preventDefault(); showContent(url); }
  });
  retry.addEventListener("click", function () { showContent(currentUrl); });
  closeButton.addEventListener("click", close);
  drawer.addEventListener("cancel", function (event) { event.preventDefault(); close(); });
  drawer.addEventListener("keydown", function (event) {
    if (event.key === "Escape") event.stopPropagation();
    if (event.key !== "Tab") return;
    event.stopPropagation();
    var focusable = Array.prototype.slice.call(drawer.querySelectorAll("a[href], button, input, select, textarea, [tabindex]")).filter(function (node) {
      return !node.disabled && node.tabIndex >= 0 && node.getClientRects().length && getComputedStyle(node).visibility !== "hidden";
    });
    var index = focusable.indexOf(document.activeElement);
    if (event.shiftKey && index <= 0) {
      event.preventDefault();
      focusable[focusable.length - 1].focus();
    } else if (!event.shiftKey && (index === -1 || index === focusable.length - 1)) {
      event.preventDefault();
      focusable[0].focus();
    }
  });
  drawer.addEventListener("close", function () { if (!drawer.open) restorePage(); });
  drawer.addEventListener("click", function (event) {
    if (event.target !== drawer) return;
    var bounds = drawer.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) close();
  });
})();
