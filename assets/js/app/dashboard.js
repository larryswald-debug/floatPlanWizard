// Updated to launch the float plan wizard in a modal and refresh after save.
(function (window, document) {
  "use strict";

  var floatPlanState = {
    all: [],
    filtered: [],
    query: ""
  };

  var vesselState = {
    all: []
  };

  var contactState = {
    all: []
  };

  var passengerState = {
    all: []
  };

  var operatorState = {
    all: []
  };

  var waypointState = {
    all: []
  };

  var BASE_PATH = window.FPW_BASE || "";
  var FALLBACK_LOGIN_URL = BASE_PATH + "/app/login.cfm";

  function getLoginUrl() {
    if (window.AppAuth && window.AppAuth.loginUrl) {
      return window.AppAuth.loginUrl;
    }
    return FALLBACK_LOGIN_URL;
  }

  function redirectToLogin() {
    if (window.AppAuth && typeof window.AppAuth.redirectToLogin === "function") {
      window.AppAuth.redirectToLogin();
      return;
    }
    window.location.href = getLoginUrl();
  }

  function ensureAuthResponse(data) {
    return window.AppAuth ? window.AppAuth.ensureAuthenticated(data) : true;
  }

  var FLOAT_PLAN_LIMIT = 100;
  var wizardModalEl = null;
  var wizardModal = null;
  var wizardMountEl = null;
  var cloneModalEl = null;
  var cloneModal = null;
  var cloneMessageEl = null;
  var cloneOkButton = null;

  function showDashboardAlert(message, type) {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;

    alertEl.textContent = message || "";
    alertEl.classList.remove("d-none", "alert-success", "alert-danger", "alert-warning", "alert-info");

    var alertType = type || "info";
    alertEl.classList.add("alert-" + alertType);

    if (!message) {
      alertEl.classList.add("d-none");
    }
  }

  function clearDashboardAlert() {
    var alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return;
    alertEl.classList.add("d-none");
    alertEl.textContent = "";
  }

  function pick(obj, keys, fallback) {
    if (!obj) return fallback;
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (obj[key] !== undefined && obj[key] !== null && String(obj[key]).length) {
        return obj[key];
      }
    }
    return fallback;
  }

  function escapeHtml(value) {
    if (value === undefined || value === null) return "";
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function formatPlanDate(value) {
    if (!value) return "";
    var date = new Date(value);
    if (isNaN(date.getTime())) {
      return String(value);
    }
    var datePart = date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    var timePart = date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
    return datePart + " " + timePart;
  }

  function parsePlanDate(value) {
    if (!value) return 0;
    var date = new Date(value);
    var time = date.getTime();
    return isNaN(time) ? 0 : time;
  }

  function debounce(fn, delay) {
    var timerId = null;
    return function () {
      var args = arguments;
      if (timerId) {
        window.clearTimeout(timerId);
      }
      timerId = window.setTimeout(function () {
        timerId = null;
        fn.apply(null, args);
      }, delay);
    };
  }

  function normalizeSearch(value) {
    return String(value || "").trim().toLowerCase();
  }

  function setFloatPlansSummary(text) {
    var el = document.getElementById("floatPlansSummary");
    if (!el) return;
    el.textContent = text;
  }

  function updateFloatPlansSummary(plans) {
    if (!plans || !plans.length) {
      setFloatPlansSummary("No plans yet");
      return;
    }

    var activeCount = 0;
    for (var i = 0; i < plans.length; i++) {
      var status = pick(plans[i], ["STATUS", "status"], "");
      if (status && ["ACTIVE", "OPEN"].indexOf(String(status).toUpperCase()) !== -1) {
        activeCount++;
      }
    }

    var summaryText = activeCount + " active • " + plans.length + " total";
    setFloatPlansSummary(summaryText);
  }

  function setFloatPlansFilterCount(filteredCount, totalCount) {
    var countEl = document.getElementById("floatPlansFilterCount");
    if (!countEl) return;
    countEl.textContent = "Showing " + filteredCount + " of " + totalCount;
  }

  function setFloatPlansMessage(text, isError) {
    var messageEl = document.getElementById("floatPlansMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function setVesselsSummary(text) {
    var el = document.getElementById("vesselsSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setVesselsMessage(text, isError) {
    var messageEl = document.getElementById("vesselsMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function setContactsSummary(text) {
    var el = document.getElementById("contactsSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setContactsMessage(text, isError) {
    var messageEl = document.getElementById("contactsMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function setPassengersSummary(text) {
    var el = document.getElementById("passengersSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setPassengersMessage(text, isError) {
    var messageEl = document.getElementById("passengersMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function setOperatorsSummary(text) {
    var el = document.getElementById("operatorsSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setOperatorsMessage(text, isError) {
    var messageEl = document.getElementById("operatorsMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function setWaypointsSummary(text) {
    var el = document.getElementById("waypointsSummary");
    if (!el) return;
    el.textContent = text;
  }

  function setWaypointsMessage(text, isError) {
    var messageEl = document.getElementById("waypointsMessage");
    if (!messageEl) return;

    if (!text) {
      messageEl.textContent = "";
      messageEl.classList.add("d-none");
      messageEl.classList.remove("text-danger");
      return;
    }

    messageEl.textContent = text;
    messageEl.classList.remove("d-none");
    messageEl.classList.toggle("text-danger", !!isError);
  }

  function updateVesselsSummary(vessels) {
    if (!vessels || !vessels.length) {
      setVesselsSummary("No vessels yet");
      return;
    }

    setVesselsSummary(vessels.length + " total");
  }

  function updateContactsSummary(contacts) {
    if (!contacts || !contacts.length) {
      setContactsSummary("No contacts yet");
      return;
    }

    setContactsSummary(contacts.length + " total");
  }

  function updatePassengersSummary(passengers) {
    if (!passengers || !passengers.length) {
      setPassengersSummary("No passengers yet");
      return;
    }

    setPassengersSummary(passengers.length + " total");
  }

  function updateOperatorsSummary(operators) {
    if (!operators || !operators.length) {
      setOperatorsSummary("No operators yet");
      return;
    }

    setOperatorsSummary(operators.length + " total");
  }

  function updateWaypointsSummary(waypoints) {
    if (!waypoints || !waypoints.length) {
      setWaypointsSummary("No waypoints yet");
      return;
    }

    setWaypointsSummary(waypoints.length + " total");
  }

  function renderVesselsList(vessels) {
    var listEl = document.getElementById("vesselsList");
    if (!listEl) return;

    if (!vessels || !vessels.length) {
      listEl.innerHTML = "";
      setVesselsMessage("You don’t have any vessels yet.", false);
      return;
    }

    setVesselsMessage("", false);

    var rows = vessels.map(function (vessel) {
      var vesselId = pick(vessel, ["VESSELID", "ID"], "");
      var name = pick(vessel, ["VESSELNAME", "NAME"], "");
      var reg = pick(vessel, ["REGISTRATION", "REGNO"], "");
      var nameText = name || "Unnamed vessel";
      var regText = reg ? "Registration: " + reg : "Registration: N/A";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(nameText) + "</div>" +
            "<small>" + escapeHtml(regText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="vessel-edit-' + escapeHtml(vesselId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="vessel-delete-' + escapeHtml(vesselId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function renderContactsList(contacts) {
    var listEl = document.getElementById("contactsList");
    if (!listEl) return;

    if (!contacts || !contacts.length) {
      listEl.innerHTML = "";
      setContactsMessage("You don’t have any contacts yet.", false);
      return;
    }

    setContactsMessage("", false);

    var rows = contacts.map(function (contact) {
      var contactId = pick(contact, ["CONTACTID", "ID"], "");
      var name = pick(contact, ["CONTACTNAME", "NAME"], "");
      var phone = pick(contact, ["PHONE"], "");
      var email = pick(contact, ["EMAIL"], "");
      var metaParts = [];

      if (phone) metaParts.push(phone);
      if (email) metaParts.push(email);

      var metaText = metaParts.length ? metaParts.join(" • ") : "No contact details";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(name || "Unnamed contact") + "</div>" +
            "<small>" + escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="contact-edit-' + escapeHtml(contactId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="contact-delete-' + escapeHtml(contactId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function renderPassengersList(passengers) {
    var listEl = document.getElementById("passengersList");
    if (!listEl) return;

    if (!passengers || !passengers.length) {
      listEl.innerHTML = "";
      setPassengersMessage("You don’t have any passengers yet.", false);
      return;
    }

    setPassengersMessage("", false);

    var rows = passengers.map(function (passenger) {
      var passengerId = pick(passenger, ["PASSENGERID", "ID"], "");
      var name = pick(passenger, ["PASSENGERNAME", "NAME"], "");
      var phone = pick(passenger, ["PHONE"], "");
      var age = pick(passenger, ["AGE"], "");
      var gender = pick(passenger, ["GENDER"], "");
      var metaParts = [];

      if (phone) metaParts.push(phone);
      if (age) metaParts.push("Age " + age);
      if (gender) metaParts.push(gender);

      var metaText = metaParts.length ? metaParts.join(" • ") : "No passenger details";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(name || "Unnamed passenger") + "</div>" +
            "<small>" + escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="passenger-edit-' + escapeHtml(passengerId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="passenger-delete-' + escapeHtml(passengerId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function renderOperatorsList(operators) {
    var listEl = document.getElementById("operatorsList");
    if (!listEl) return;

    if (!operators || !operators.length) {
      listEl.innerHTML = "";
      setOperatorsMessage("You don’t have any operators yet.", false);
      return;
    }

    setOperatorsMessage("", false);

    var rows = operators.map(function (operator) {
      var operatorId = pick(operator, ["OPERATORID", "ID"], "");
      var name = pick(operator, ["OPERATORNAME", "NAME"], "");
      var phone = pick(operator, ["PHONE"], "");
      var notes = pick(operator, ["NOTES"], "");
      var metaParts = [];

      if (phone) metaParts.push(phone);
      if (notes) metaParts.push(notes);

      var metaText = metaParts.length ? metaParts.join(" • ") : "No operator details";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(name || "Unnamed operator") + "</div>" +
            "<small>" + escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="operator-edit-' + escapeHtml(operatorId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="operator-delete-' + escapeHtml(operatorId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function renderWaypointsList(waypoints) {
    var listEl = document.getElementById("waypointsList");
    if (!listEl) return;

    if (!waypoints || !waypoints.length) {
      listEl.innerHTML = "";
      setWaypointsMessage("You don’t have any waypoints yet.", false);
      return;
    }

    setWaypointsMessage("", false);

    var rows = waypoints.map(function (waypoint) {
      var waypointId = pick(waypoint, ["WAYPOINTID", "ID"], "");
      var name = pick(waypoint, ["WAYPOINTNAME", "NAME"], "");
      var latitude = pick(waypoint, ["LATITUDE"], "");
      var longitude = pick(waypoint, ["LONGITUDE"], "");
      var notes = pick(waypoint, ["NOTES"], "");
      var metaParts = [];

      if (latitude && longitude) {
        metaParts.push(latitude + ", " + longitude);
      }
      if (notes) {
        metaParts.push(notes);
      }

      var metaText = metaParts.length ? metaParts.join(" • ") : "No waypoint details";

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(name || "Unnamed waypoint") + "</div>" +
            "<small>" + escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="waypoint-edit-' + escapeHtml(waypointId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="waypoint-delete-' + escapeHtml(waypointId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
  }

  function renderStatusBadge(status) {
    if (!status) return "";
    var normalized = String(status).toUpperCase();
    var cls = "bg-secondary";

    switch (normalized) {
      case "OPEN":
      case "ACTIVE":
        cls = "bg-success";
        break;
      case "SUBMITTED":
        cls = "bg-primary";
        break;
      case "OVERDUE":
        cls = "bg-danger";
        break;
      case "COMPLETED":
      case "CLOSED":
        cls = "bg-dark";
        break;
      case "DRAFT":
        return "";
      default:
        cls = "bg-secondary";
        break;
    }

    return '<span class="badge ' + cls + '">' + escapeHtml(normalized) + "</span>";
  }

  function renderFloatPlansList(plans, totalCount) {
    var listEl = document.getElementById("floatPlansList");
    if (!listEl) return;

    var currentQuery = floatPlanState.query || "";
    if (!plans || !plans.length) {
      listEl.innerHTML = "";
      if (!totalCount) {
        setFloatPlansMessage("You don’t have any float plans yet.", false);
      } else if (currentQuery) {
        setFloatPlansMessage("No float plans match your filter.", false);
      } else {
        setFloatPlansMessage("You don’t have any float plans yet.", false);
      }
      return;
    }

    setFloatPlansMessage("", false);

    var scrollTop = listEl.scrollTop;
    var rows = plans.map(function (plan) {
      var id = pick(plan, ["FLOATPLANID", "PLANID", "ID"], "");
      var name = pick(plan, ["PLANNAME", "NAME"], "");
      if (!name && id) {
        name = "Plan #" + id;
      }
      var status = pick(plan, ["STATUS", "status"], "");
      var depart = formatPlanDate(pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt"], ""));
      var returnBy = formatPlanDate(pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt"], ""));
      var vessel = pick(plan, ["VESSELNAME", "VESSEL"], "");
      var updated = formatPlanDate(pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], ""));
      var waypointCount = parseInt(pick(plan, ["WAYPOINTCOUNT", "waypointCount"], 0), 10);
      if (isNaN(waypointCount)) waypointCount = 0;

      var metaParts = [];
      if (depart) metaParts.push("Departs " + depart);
      if (returnBy) metaParts.push("Return " + returnBy);
      if (waypointCount > 0) {
        metaParts.push(waypointCount + " waypoint" + (waypointCount === 1 ? "" : "s"));
      }
      if (vessel) metaParts.push(vessel);
      var metaText = metaParts.join(" • ");
      var statusBadge = renderStatusBadge(status);
      var updatedText = updated ? "Updated " + updated : "";

      var metaPartsInline = [];
      if (statusBadge) {
        metaPartsInline.push(statusBadge);
      }
      if (metaText) {
        metaPartsInline.push('<span class="list-meta-text">' + escapeHtml(metaText) + "</span>");
      }
      if (updatedText) {
        metaPartsInline.push('<span class="list-meta-text text-white">' + escapeHtml(updatedText) + "</span>");
      }
      var metaInline = metaPartsInline.length
        ? '<div class="list-meta list-meta-inline">' + metaPartsInline.join('<span class="meta-sep">•</span>') + "</div>"
        : "";

      return (
        '<div class="list-item list-item-single" data-plan-id="' + escapeHtml(id) + '">' +
          '<div class="list-col-name">' +
            '<div class="list-title">' + escapeHtml(name || "Untitled Plan") + ":</div>" +
          "</div>" +
          '<div class="list-col-summary">' +
            metaInline +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" data-action="view" data-plan-id="' + escapeHtml(id) + '">View &amp; Send</button>' +
            '<button class="btn-secondary" type="button" data-action="clone" data-plan-id="' + escapeHtml(id) + '">Clone</button>' +
            '<button class="btn-secondary" type="button" data-action="edit" data-plan-id="' + escapeHtml(id) + '">Edit</button>' +
            '<button class="btn-danger" type="button" data-action="delete" data-plan-id="' + escapeHtml(id) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
    listEl.scrollTop = scrollTop;
  }

  function buildPlanSearchText(plan) {
    var name = pick(plan, ["PLANNAME", "NAME"], "");
    var status = pick(plan, ["STATUS", "status"], "");
    var vessel = pick(plan, ["VESSELNAME", "VESSEL"], "");
    var depart = pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt", "DEPARTURE_TIME", "DEPARTING_FROM"], "");
    var returnBy = pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt", "RETURN_TIME", "RETURNING_TO", "DESTINATION"], "");
    var updated = pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], "");
    var pieces = [
      name,
      status,
      vessel,
      depart,
      returnBy,
      updated,
      formatPlanDate(depart),
      formatPlanDate(returnBy),
      formatPlanDate(updated)
    ];
    return normalizeSearch(pieces.join(" "));
  }

  function applyFloatPlanFilter(rawQuery) {
    var normalized = normalizeSearch(rawQuery);
    floatPlanState.query = normalized;

    var source = floatPlanState.all || [];
    var filtered = normalized
      ? source.filter(function (plan) {
          return buildPlanSearchText(plan).indexOf(normalized) !== -1;
        })
      : source.slice();

    floatPlanState.filtered = filtered;
    renderFloatPlansList(filtered, source.length);
    setFloatPlansFilterCount(filtered.length, source.length);

    var clearBtn = document.getElementById("floatPlansFilterClear");
    if (clearBtn) {
      clearBtn.disabled = !normalized;
    }
  }

  function initFloatPlansFilter() {
    var inputEl = document.getElementById("floatPlansFilterInput");
    var clearBtn = document.getElementById("floatPlansFilterClear");
    if (!inputEl) return;

    var debouncedFilter = debounce(function () {
      applyFloatPlanFilter(inputEl.value);
    }, 250);

    inputEl.addEventListener("input", function () {
      debouncedFilter();
    });

    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        inputEl.value = "";
        applyFloatPlanFilter("");
        inputEl.focus();
      });
    }
  }

  function loadFloatPlans(limit) {
    limit = limit || FLOAT_PLAN_LIMIT;
    setFloatPlansSummary("Loading…");
    setFloatPlansMessage("Loading float plans…", false);

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getFloatPlans !== "function") {
      setFloatPlansMessage("Float plan API is unavailable.", true);
      setFloatPlansSummary("Unavailable");
      return;
    }

    Api.getFloatPlans({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var plans = data.PLANS || data.FLOATPLANS || data.floatplans || [];
        plans = plans.slice().sort(function (a, b) {
          var aCreated = parsePlanDate(pick(a, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          var bCreated = parsePlanDate(pick(b, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          if (aCreated !== bCreated) {
            return bCreated - aCreated;
          }
          var aId = parseInt(pick(a, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
          var bId = parseInt(pick(b, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
          if (isNaN(aId)) aId = 0;
          if (isNaN(bId)) bId = 0;
          return bId - aId;
        });
        floatPlanState.all = plans;
        updateFloatPlansSummary(plans);
        var inputEl = document.getElementById("floatPlansFilterInput");
        applyFloatPlanFilter(inputEl ? inputEl.value : "");
      })
      .catch(function (err) {
        console.error("Failed to load float plans:", err);
        setFloatPlansMessage("Unable to load float plans right now.", true);
        setFloatPlansSummary("Error");
        showDashboardAlert("Unable to load float plans. Please try again later.", "danger");
      });
  }

  function loadVessels(limit) {
    limit = limit || 100;
    setVesselsSummary("Loading…");
    setVesselsMessage("Loading vessels…", false);

    var listEl = document.getElementById("vesselsList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getVessels !== "function") {
      setVesselsMessage("Vessels API is unavailable.", true);
      setVesselsSummary("Unavailable");
      return;
    }

    Api.getVessels({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var vessels = data.VESSELS || data.vessels || [];
        vessels = vessels.slice().sort(function (a, b) {
          var aName = pick(a, ["VESSELNAME", "NAME"], "").toLowerCase();
          var bName = pick(b, ["VESSELNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        vesselState.all = vessels;
        updateVesselsSummary(vessels);
        renderVesselsList(vessels);
      })
      .catch(function (err) {
        console.error("Failed to load vessels:", err);
        setVesselsMessage("Unable to load vessels right now.", true);
        setVesselsSummary("Error");
        showDashboardAlert("Unable to load vessels. Please try again later.", "danger");
      });
  }

  function loadContacts(limit) {
    limit = limit || 100;
    setContactsSummary("Loading…");
    setContactsMessage("Loading contacts…", false);

    var listEl = document.getElementById("contactsList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getContacts !== "function") {
      setContactsMessage("Contacts API is unavailable.", true);
      setContactsSummary("Unavailable");
      return;
    }

    Api.getContacts({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var contacts = data.CONTACTS || data.contacts || [];
        contacts = contacts.slice().sort(function (a, b) {
          var aName = pick(a, ["CONTACTNAME", "NAME"], "").toLowerCase();
          var bName = pick(b, ["CONTACTNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        contactState.all = contacts;
        updateContactsSummary(contacts);
        renderContactsList(contacts);
      })
      .catch(function (err) {
        console.error("Failed to load contacts:", err);
        setContactsMessage("Unable to load contacts right now.", true);
        setContactsSummary("Error");
        showDashboardAlert("Unable to load contacts. Please try again later.", "danger");
      });
  }

  function loadPassengers(limit) {
    limit = limit || 100;
    setPassengersSummary("Loading…");
    setPassengersMessage("Loading passengers…", false);

    var listEl = document.getElementById("passengersList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getPassengers !== "function") {
      setPassengersMessage("Passengers API is unavailable.", true);
      setPassengersSummary("Unavailable");
      return;
    }

    Api.getPassengers({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var passengers = data.PASSENGERS || data.passengers || [];
        passengers = passengers.slice().sort(function (a, b) {
          var aName = pick(a, ["PASSENGERNAME", "NAME"], "").toLowerCase();
          var bName = pick(b, ["PASSENGERNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        passengerState.all = passengers;
        updatePassengersSummary(passengers);
        renderPassengersList(passengers);
      })
      .catch(function (err) {
        console.error("Failed to load passengers:", err);
        setPassengersMessage("Unable to load passengers right now.", true);
        setPassengersSummary("Error");
        showDashboardAlert("Unable to load passengers. Please try again later.", "danger");
      });
  }

  function loadOperators(limit) {
    limit = limit || 100;
    setOperatorsSummary("Loading…");
    setOperatorsMessage("Loading operators…", false);

    var listEl = document.getElementById("operatorsList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getOperators !== "function") {
      setOperatorsMessage("Operators API is unavailable.", true);
      setOperatorsSummary("Unavailable");
      return;
    }

    Api.getOperators({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var operators = data.OPERATORS || data.operators || [];
        operators = operators.slice().sort(function (a, b) {
          var aName = pick(a, ["OPERATORNAME", "NAME"], "").toLowerCase();
          var bName = pick(b, ["OPERATORNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        operatorState.all = operators;
        updateOperatorsSummary(operators);
        renderOperatorsList(operators);
      })
      .catch(function (err) {
        console.error("Failed to load operators:", err);
        setOperatorsMessage("Unable to load operators right now.", true);
        setOperatorsSummary("Error");
        showDashboardAlert("Unable to load operators. Please try again later.", "danger");
      });
  }

  function loadWaypoints(limit) {
    limit = limit || 100;
    setWaypointsSummary("Loading…");
    setWaypointsMessage("Loading waypoints…", false);

    var listEl = document.getElementById("waypointsList");
    if (listEl) {
      listEl.innerHTML = "";
    }

    if (!window.Api || typeof window.Api.getWaypoints !== "function") {
      setWaypointsMessage("Waypoints API is unavailable.", true);
      setWaypointsSummary("Unavailable");
      return;
    }

    Api.getWaypoints({ limit: limit })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var waypoints = data.WAYPOINTS || data.waypoints || [];
        waypoints = waypoints.slice().sort(function (a, b) {
          var aName = pick(a, ["WAYPOINTNAME", "NAME"], "").toLowerCase();
          var bName = pick(b, ["WAYPOINTNAME", "NAME"], "").toLowerCase();
          if (aName < bName) return -1;
          if (aName > bName) return 1;
          return 0;
        });
        waypointState.all = waypoints;
        updateWaypointsSummary(waypoints);
        renderWaypointsList(waypoints);
      })
      .catch(function (err) {
        console.error("Failed to load waypoints:", err);
        setWaypointsMessage("Unable to load waypoints right now.", true);
        setWaypointsSummary("Error");
        showDashboardAlert("Unable to load waypoints. Please try again later.", "danger");
      });
  }

  function ensureWizardModal() {
    if (!wizardModalEl) {
      wizardModalEl = document.getElementById("floatPlanWizardModal");
      if (wizardModalEl) {
        wizardMountEl = wizardModalEl.querySelector("#wizardApp");
      }
    }

    if (wizardModalEl && !wizardModal && window.bootstrap && window.bootstrap.Modal) {
      wizardModal = new window.bootstrap.Modal(wizardModalEl);
    }

    if (wizardModalEl && !wizardModalEl.dataset.listenersAttached) {
      wizardModalEl.addEventListener("hidden.bs.modal", function () {
        if (window.FloatPlanWizard && typeof window.FloatPlanWizard.destroy === "function") {
          window.FloatPlanWizard.destroy();
        }
      });
      var closeButton = wizardModalEl.querySelector(".btn-close");
      if (closeButton) {
        closeButton.addEventListener("click", function () {
          if (window.FloatPlanWizard && typeof window.FloatPlanWizard.destroy === "function") {
            window.FloatPlanWizard.destroy();
          }
        });
      }
      wizardModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureCloneModal() {
    if (!cloneModalEl) {
      cloneModalEl = document.getElementById("floatPlanCloneModal");
      if (cloneModalEl) {
        cloneMessageEl = cloneModalEl.querySelector("[data-clone-message]");
        cloneOkButton = cloneModalEl.querySelector("[data-clone-ok]");
      }
    }

    if (cloneModalEl && !cloneModal && window.bootstrap && window.bootstrap.Modal) {
      cloneModal = new window.bootstrap.Modal(cloneModalEl);
    }

    if (cloneModalEl && !cloneModalEl.dataset.listenersAttached) {
      if (cloneOkButton) {
        cloneOkButton.addEventListener("click", function () {
          if (cloneModal) {
            cloneModal.hide();
          }
          window.location.href = BASE_PATH + "/app/dashboard.cfm";
        });
      }
      cloneModalEl.dataset.listenersAttached = "true";
    }
  }

  function showCloneModal(planName) {
    ensureCloneModal();
    if (!cloneModalEl || !cloneModal) {
      if (planName) {
        window.alert("Float plan cloned: " + planName);
      } else {
        window.alert("Float plan cloned.");
      }
      return;
    }

    if (cloneMessageEl) {
      var safeName = planName ? String(planName) : "";
      cloneMessageEl.textContent = safeName
        ? "Float plan has been cloned: " + safeName
        : "Float plan has been cloned.";
    }

    cloneModal.show();
  }

  function openWizard(planId, startStep) {
    ensureWizardModal();
    if (!wizardModalEl || !wizardModal) {
      return;
    }

    if (window.FloatPlanWizard && typeof window.FloatPlanWizard.init === "function") {
      window.FloatPlanWizard.init({
        mountEl: wizardMountEl,
        planId: planId,
        startStep: startStep,
        contactStep: 4,
        onSaved: function () {
          loadFloatPlans(FLOAT_PLAN_LIMIT);
          if (wizardModal) {
            wizardModal.show();
          }
        },
        onDeleted: function () {
          wizardModal.hide();
          loadFloatPlans(FLOAT_PLAN_LIMIT);
        }
      });
    }

    wizardModal.show();
  }

  function handleFloatPlansListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-plan-id]");
    if (!button) return;

    var planId = button.getAttribute("data-plan-id");
    var action = button.getAttribute("data-action");

    if (!planId) return;

    if (action === "edit") {
      openWizard(planId);
    } else if (action === "view") {
      openWizard(planId, 6);
    } else if (action === "clone") {
      cloneFloatPlan(planId, button);
    } else if (action === "delete") {
      if (!window.confirm("Delete this float plan?")) {
        return;
      }
      deleteFloatPlan(planId, button);
    }
  }

  function cloneFloatPlan(planId, triggerButton) {
    if (!window.Api || typeof window.Api.cloneFloatPlan !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Cloning...";
    }

    Api.cloneFloatPlan(planId)
      .then(function (data) {
        if (!data.SUCCESS) {
          throw data;
        }
        loadFloatPlans(FLOAT_PLAN_LIMIT);
        var clonedName = pick(data, ["CLONED_NAME", "PLANNAME"], "");
        if (!clonedName && data.FLOATPLAN) {
          clonedName = pick(data.FLOATPLAN, ["NAME", "PLANNAME"], "");
        }
        showCloneModal(clonedName);
      })
      .catch(function (err) {
        console.error("Failed to clone float plan:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Clone failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Clone";
        }
      });
  }

  function deleteFloatPlan(planId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteFloatPlan !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteFloatPlan(planId)
      .then(function (data) {
        if (!data.SUCCESS) {
          throw data;
        }
        loadFloatPlans(FLOAT_PLAN_LIMIT);
      })
      .catch(function (err) {
        console.error("Failed to delete float plan:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function populateUserInfo(user) {
    var nameEl = document.getElementById("userName");
    var emailEl = document.getElementById("userEmail");

    if (nameEl) {
      nameEl.textContent = (user && user.NAME) ? user.NAME : "";
    }

    if (emailEl) {
      emailEl.textContent = (user && user.EMAIL) ? user.EMAIL : "";
    }
  }

  function initDashboard() {
    clearDashboardAlert();
    ensureWizardModal();
    ensureCloneModal();
    initFloatPlansFilter();

    Api.getCurrentUser()
      .then(function (data) {
        // data.SUCCESS already checked in Api.request
        if (!ensureAuthResponse(data)) {
          return;
        }

        if (!data.USER) {
          redirectToLogin();
          return;
        }

        populateUserInfo(data.USER);
        loadFloatPlans(FLOAT_PLAN_LIMIT);
        loadVessels();
        loadContacts();
        loadPassengers();
        loadOperators();
        loadWaypoints();
      })
      .catch(function (err) {
        console.error("Failed to load current user:", err);
        // If the API fails, assume not logged in and send to login
        redirectToLogin();
      });

    // Wire up logout
    var logoutBtn = document.getElementById("logoutButton");
    if (logoutBtn) {
      logoutBtn.addEventListener("click", function () {
        Api.logout()
          .catch(function (err) {
            console.error("Logout failed:", err);
            // Ignore errors, just send them to login
          })
          .finally(function () {
            redirectToLogin();
          });
      });
    }

    var addPlanBtn = document.getElementById("addFloatPlanBtn");
    if (addPlanBtn) {
      addPlanBtn.addEventListener("click", function () {
        openWizard(0);
      });
    }

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.addEventListener("click", handleFloatPlansListClick);
    }
  }

  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
