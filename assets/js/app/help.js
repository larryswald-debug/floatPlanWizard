(function () {
  "use strict";

  var searchInput = document.querySelector("[data-help-search]");
  var clearButton = document.querySelector("[data-help-search-clear]");
  var statusEl = document.querySelector("[data-help-search-status]");
  var emptyEl = document.querySelector("[data-help-empty]");
  var sections = Array.prototype.slice.call(document.querySelectorAll("[data-help-section]"));
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll("[data-help-toc-link]"));

  if (!sections.length) {
    return;
  }

  function normalize(value) {
    return String(value || "").toLowerCase().replace(/\s+/g, " ").trim();
  }

  function searchableText(section) {
    return normalize([
      section.id,
      section.getAttribute("data-help-keywords"),
      section.textContent
    ].join(" "));
  }

  var indexedSections = sections.map(function (section) {
    return {
      section: section,
      text: searchableText(section)
    };
  });

  function setActiveLink(id) {
    tocLinks.forEach(function (link) {
      var isActive = link.getAttribute("href") === "#" + id;
      link.classList.toggle("is-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "true");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  function applySearch() {
    var query = normalize(searchInput ? searchInput.value : "");
    var shown = 0;

    indexedSections.forEach(function (item) {
      var isMatch = !query || item.text.indexOf(query) !== -1;
      item.section.hidden = !isMatch;
      if (isMatch) {
        shown += 1;
      }
    });

    if (emptyEl) {
      emptyEl.hidden = shown !== 0;
    }

    if (statusEl) {
      if (!query) {
        statusEl.textContent = "Search by topic, task, or boating situation.";
      } else if (shown === 1) {
        statusEl.textContent = "1 help topic matches \"" + query + "\".";
      } else {
        statusEl.textContent = shown + " help topics match \"" + query + "\".";
      }
    }
  }

  if (searchInput) {
    searchInput.addEventListener("input", applySearch);
  }

  if (clearButton) {
    clearButton.addEventListener("click", function () {
      if (searchInput) {
        searchInput.value = "";
        searchInput.focus();
      }
      applySearch();
    });
  }

  tocLinks.forEach(function (link) {
    link.addEventListener("click", function (event) {
      var selector = link.getAttribute("href");
      var target = selector ? document.querySelector(selector) : null;
      if (!target) {
        return;
      }
      event.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
      setActiveLink(target.id);
      if (window.history && typeof window.history.replaceState === "function") {
        window.history.replaceState(null, "", selector);
      }
    });
  });

  if ("IntersectionObserver" in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          setActiveLink(entry.target.id);
        }
      });
    }, {
      rootMargin: "-20% 0px -65% 0px",
      threshold: 0
    });

    sections.forEach(function (section) {
      observer.observe(section);
    });
  }

  applySearch();
})();
