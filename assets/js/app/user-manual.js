(function () {
  "use strict";
  var root = document.querySelector(".fpw-manual");
  if (!root) return;
  var search = root.querySelector("[data-manual-search]");
  var searchPanel = root.querySelector(".fpw-manual-search");
  var clear = root.querySelector("[data-manual-clear]");
  var status = root.querySelector("[data-manual-status]");
  var empty = root.querySelector("[data-manual-empty]");
  var print = root.querySelector("[data-manual-print]");
  var chapters = Array.prototype.slice.call(root.querySelectorAll("[data-manual-chapter]"));
  var links = Array.prototype.slice.call(root.querySelectorAll("[data-manual-toc]"));
  var groups = Array.prototype.slice.call(root.querySelectorAll("[data-manual-group]"));
  function normalize(text) { return String(text || "").toLowerCase().replace(/\s+/g, " ").trim(); }
  var index = chapters.map(function (chapter) { return { element: chapter, text: normalize(chapter.textContent) }; });
  function applySearch() {
    var query = normalize(search.value);
    var shown = 0;
    index.forEach(function (entry) {
      entry.element.hidden = !!query && entry.text.indexOf(query) === -1;
      if (!entry.element.hidden) shown++;
    });
    links.forEach(function (link) {
      var target = document.getElementById(link.hash.slice(1));
      link.parentElement.hidden = !target || target.hidden;
    });
    groups.forEach(function (group) {
      group.hidden = !Array.prototype.some.call(group.querySelectorAll("li"), function (li) { return !li.hidden; });
    });
    empty.hidden = shown !== 0;
    status.textContent = query
      ? shown + (shown === 1 ? " chapter matches" : " chapters match") + ' "' + search.value.trim() + '".'
      : "All " + chapters.length + " chapters are shown.";
  }
  function resetSearch() { search.value = ""; applySearch(); }
  function targetForHash(hash) {
    if (!hash || hash === "#") return null;
    try {
      var target = document.getElementById(decodeURIComponent(hash.slice(1)));
      return target && target.hasAttribute("data-manual-chapter") ? target : null;
    } catch (_) { return null; }
  }
  function markChapter(target) {
    links.forEach(function (link) {
      if (link.hash.slice(1) === target.id) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  }
  function revealHash() {
    var target = targetForHash(window.location.hash);
    if (!target) return;
    var wasHidden = target.hidden;
    if (wasHidden) resetSearch();
    markChapter(target);
    if (wasHidden) {
      // Re-align only when filtering prevented the browser's native fragment scroll.
      window.requestAnimationFrame(function () {
        target.scrollIntoView({
          behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
          block: "start"
        });
      });
    }
  }
  // Native navigation runs after this handler, even when the fragment is unchanged.
  document.addEventListener("click", function (event) {
    var link = event.target.closest("a[href]");
    if (!link || event.defaultPrevented || event.button !== 0
      || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey
      || link.hasAttribute("download") || (link.target && link.target !== "_self")) return;
    var url;
    try { url = new URL(link.href, window.location.href); } catch (_) { return; }
    if (url.origin !== window.location.origin || url.pathname !== window.location.pathname
      || url.search !== window.location.search) return;
    var target = targetForHash(url.hash);
    if (!target) return;
    if (target.hidden) resetSearch();
    markChapter(target);
  }, true);
  searchPanel.hidden = false;
  print.hidden = false;
  search.addEventListener("input", applySearch);
  search.addEventListener("keydown", function (event) {
    if (event.key === "Escape") { resetSearch(); search.focus(); }
  });
  clear.addEventListener("click", function () { resetSearch(); search.focus(); });
  print.addEventListener("click", function () { window.print(); });
  window.addEventListener("hashchange", revealHash);
  applySearch();
  revealHash();
})();
