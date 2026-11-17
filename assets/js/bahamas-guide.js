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
  var sample = root.querySelector("[data-bh-sample-calculator]");
  if (sample) {
    var distance = Number(sample.getAttribute("data-bh-sample-distance"));
    var fields = Array.prototype.slice.call(sample.querySelectorAll("[data-bh-sample-input]"));
    var outputs = sample.querySelectorAll("[data-bh-sample-output]");
    var error = sample.querySelector("#bhSampleError");

    function showSampleError(message) {
      error.textContent = message;
      error.hidden = !message;
      if (message) outputs.forEach(function (output) { output.textContent = "—"; });
    }

    function updateSample() {
      var values = {};
      var valid = Number.isFinite(distance) && distance > 0;
      fields.forEach(function (field) {
        var key = field.getAttribute("data-bh-sample-input");
        var text = field.value.trim();
        var value = Number(text);
        var fieldValid = text !== "" && Number.isFinite(value) && (key === "speed" ? value > 0 : value >= 0);
        field.setAttribute("aria-invalid", fieldValid ? "false" : "true");
        valid = valid && fieldValid;
        values[key] = value;
      });
      if (!valid) {
        showSampleError("Enter a speed greater than zero and non-negative consumption, reserve and usable-fuel values. All four sample values are required.");
        return;
      }
      var hours = distance / values.speed;
      var base = hours * values.burn;
      var reserve = base * values.reserve / 100;
      var required = base + reserve;
      var margin = values.usable - required;
      var minutes = Math.round(hours * 60);
      if (![hours, base, reserve, required, margin, minutes].every(Number.isFinite)) {
        showSampleError("These sample values are too large to calculate. Enter smaller values.");
        return;
      }
      var estimates = {
        time: Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " min",
        base: base,
        reserve: reserve,
        required: required,
        margin: margin
      };
      showSampleError("");
      outputs.forEach(function (output) {
        var key = output.getAttribute("data-bh-sample-output");
        output.textContent = key === "time" ? estimates.time : estimates[key].toFixed(1) + " US gal";
      });
    }

    fields.forEach(function (field) {
      field.addEventListener("input", updateSample);
      field.addEventListener("change", updateSample);
    });
    updateSample();
  }
  // Vendor engagement events stay disabled until the site's consent policy is verified.
  // No personal trip, location, performance or auth-continuation data is sent here.
}());
