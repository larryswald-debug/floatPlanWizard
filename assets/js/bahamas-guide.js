(function () {
  "use strict";
  var root = document.querySelector(".bh-page");
  if (!root) return;
  root.querySelectorAll("[data-bh-print]").forEach(function (button) {
    button.addEventListener("click", function () { window.print(); });
  });
  root.querySelectorAll("[data-bh-region]").forEach(function (link) {
    link.addEventListener("click", function () {
      root.querySelectorAll("[data-bh-region]").forEach(function (item) { item.removeAttribute("aria-current"); });
      root.querySelectorAll(".bh-region").forEach(function (item) { item.classList.remove("is-selected"); });
      link.setAttribute("aria-current", "true");
      var target = document.getElementById(link.getAttribute("data-bh-region"));
      if (target) target.classList.add("is-selected");
    });
  });
  // Vendor engagement events stay disabled until the site's consent policy is verified.
  // No personal trip, location, performance or auth-continuation data is sent here.
}());

