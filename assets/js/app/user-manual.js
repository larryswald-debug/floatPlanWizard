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
  function revealHash() {
    var id;
    try { id = decodeURIComponent(window.location.hash.slice(1)); } catch (_) { return; }
    var target = document.getElementById(id);
    if (!target || !target.hasAttribute("data-manual-chapter")) return;
    if (target.hidden) resetSearch();
    links.forEach(function (link) {
      if (link.hash.slice(1) === id) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  }
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
