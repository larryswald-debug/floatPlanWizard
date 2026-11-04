(function () {
  "use strict";
  var panel = document.querySelector("[data-library-waypoint]");
  if (!panel) return;
  var button = panel.querySelector("[data-library-waypoint-save]");
  if (!button) return;

  var member = panel.querySelector("[data-library-waypoint-member]");
  var guest = panel.querySelector("[data-library-waypoint-guest]");
  var status = panel.querySelector("[data-library-waypoint-status]");

  function showMember(loggedIn) {
    member.hidden = !loggedIn;
    guest.hidden = loggedIn;
  }

  function request(endpoint, payload) {
    var options = { credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" } };
    if (payload) {
      options.method = "POST";
      options.headers["Content-Type"] = "application/json";
      options.body = JSON.stringify(payload);
    }
    return fetch(panel.dataset.api + "/" + endpoint + ".cfc?method=handle&returnFormat=json", options)
      .then(function (response) {
        if (response.status === 401) return { AUTH: false };
        if (!response.ok) throw new Error("Request failed.");
        return response.json();
      });
  }

  request("me").then(function (data) {
    showMember(data.AUTH === true || data.auth === true);
  }).catch(function () {
    status.textContent = "Unable to check sign-in. Refresh this page to try again.";
  });

  button.addEventListener("click", function () {
    if (button.disabled || member.hidden) return;
    button.disabled = true;
    button.textContent = "Adding...";
    status.textContent = "";
    request("waypoint", { action: "save", library: panel.dataset.library, slug: panel.dataset.slug, recordId: panel.dataset.recordId })
      .then(function (data) {
        if (data.AUTH === false) {
          showMember(false);
          status.textContent = "Your session has expired. Sign in again to save this waypoint.";
        } else if (data.SUCCESS === true) {
          button.textContent = "Added";
          status.textContent = data.ALREADY_SAVED ? "Already in your custom waypoints." : "Added to your custom waypoints.";
        } else {
          throw new Error(data.MESSAGE || "Unable to save this waypoint. Please try again.");
        }
      }).catch(function (error) {
        button.disabled = false;
        button.textContent = "Add to My Waypoints";
        status.textContent = error.message === "Request failed." || error.name !== "Error"
          ? "Unable to save this waypoint. Please try again." : error.message;
      });
  });
}());
