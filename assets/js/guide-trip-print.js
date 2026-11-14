(function () {
  "use strict";
  var button = document.getElementById("guidePrintButton");
  if (button) button.addEventListener("click", function () { window.print(); });
}());

