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
  var vesselModalEl = null;
  var vesselModal = null;
  var vesselFormEl = null;
  var vesselModalTitleEl = null;
  var vesselIdInput = null;
  var vesselNameInput = null;
  var vesselRegistrationInput = null;
  var vesselTypeInput = null;
  var vesselLengthInput = null;
  var vesselMakeInput = null;
  var vesselModelInput = null;
  var vesselColorInput = null;
  var vesselHomePortInput = null;
  var vesselSaveBtn = null;
  var vesselNameError = null;
  var vesselTypeError = null;
  var vesselLengthError = null;
  var vesselColorError = null;
  var contactModalEl = null;
  var contactModal = null;
  var contactFormEl = null;
  var contactModalTitleEl = null;
  var contactIdInput = null;
  var contactNameInput = null;
  var contactPhoneInput = null;
  var contactEmailInput = null;
  var contactSaveBtn = null;
  var contactNameError = null;
  var contactPhoneError = null;
  var contactEmailError = null;
  var confirmModalEl = null;
  var confirmModal = null;
  var confirmMessageEl = null;
  var confirmOkBtn = null;
  var confirmResolver = null;
  var alertModalEl = null;
  var alertModal = null;
  var alertMessageEl = null;
  var passengerModalEl = null;
  var passengerModal = null;
  var passengerFormEl = null;
  var passengerModalTitleEl = null;
  var passengerIdInput = null;
  var passengerNameInput = null;
  var passengerPhoneInput = null;
  var passengerAgeInput = null;
  var passengerGenderInput = null;
  var passengerNotesInput = null;
  var passengerSaveBtn = null;
  var passengerNameError = null;
  var passengerPhoneError = null;
  var operatorModalEl = null;
  var operatorModal = null;
  var operatorFormEl = null;
  var operatorModalTitleEl = null;
  var operatorIdInput = null;
  var operatorNameInput = null;
  var operatorPhoneInput = null;
  var operatorNotesInput = null;
  var operatorSaveBtn = null;
  var operatorNameError = null;
  var operatorPhoneError = null;
  var waypointModalEl = null;
  var waypointModal = null;
  var waypointFormEl = null;
  var waypointModalTitleEl = null;
  var waypointIdInput = null;
  var waypointNameInput = null;
  var waypointLatitudeInput = null;
  var waypointLongitudeInput = null;
  var waypointNotesInput = null;
  var waypointSaveBtn = null;
  var waypointNameError = null;

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
      var vesselType = pick(vessel, ["TYPE", "VESSELTYPE"], "");
      var length = pick(vessel, ["LENGTH"], "");
      var color = pick(vessel, ["COLOR"], "");
      var nameText = name || "Unnamed vessel";
      var metaParts = [];
      if (reg) metaParts.push("Registration: " + reg);
      if (vesselType) metaParts.push(vesselType);
      if (length) metaParts.push("Length: " + length);
      if (color) metaParts.push("Color: " + color);
      if (!metaParts.length) metaParts.push("Registration: N/A");
      var metaText = metaParts.join(" • ");

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + escapeHtml(nameText) + "</div>" +
            "<small>" + escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="vessel-edit-' + escapeHtml(vesselId) + '" data-action="edit" data-vessel-id="' + escapeHtml(vesselId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="vessel-delete-' + escapeHtml(vesselId) + '" data-action="delete" data-vessel-id="' + escapeHtml(vesselId) + '">Delete</button>' +
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
            '<button class="btn-secondary" type="button" id="contact-edit-' + escapeHtml(contactId) + '" data-action="edit" data-contact-id="' + escapeHtml(contactId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="contact-delete-' + escapeHtml(contactId) + '" data-action="delete" data-contact-id="' + escapeHtml(contactId) + '">Delete</button>' +
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
            '<button class="btn-secondary" type="button" id="passenger-edit-' + escapeHtml(passengerId) + '" data-action="edit" data-passenger-id="' + escapeHtml(passengerId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="passenger-delete-' + escapeHtml(passengerId) + '" data-action="delete" data-passenger-id="' + escapeHtml(passengerId) + '">Delete</button>' +
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
            '<button class="btn-secondary" type="button" id="operator-edit-' + escapeHtml(operatorId) + '" data-action="edit" data-operator-id="' + escapeHtml(operatorId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="operator-delete-' + escapeHtml(operatorId) + '" data-action="delete" data-operator-id="' + escapeHtml(operatorId) + '">Delete</button>' +
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
            '<button class="btn-secondary" type="button" id="waypoint-edit-' + escapeHtml(waypointId) + '" data-action="edit" data-waypoint-id="' + escapeHtml(waypointId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="waypoint-delete-' + escapeHtml(waypointId) + '" data-action="delete" data-waypoint-id="' + escapeHtml(waypointId) + '">Delete</button>' +
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

  function ensureVesselModal() {
    if (!vesselModalEl) {
      vesselModalEl = document.getElementById("vesselModal");
      if (vesselModalEl) {
        vesselFormEl = vesselModalEl.querySelector("#vesselForm");
        vesselModalTitleEl = vesselModalEl.querySelector("#vesselModalLabel");
        vesselIdInput = vesselModalEl.querySelector("#vesselId");
        vesselNameInput = vesselModalEl.querySelector("#vesselName");
        vesselRegistrationInput = vesselModalEl.querySelector("#vesselRegistration");
        vesselTypeInput = vesselModalEl.querySelector("#vesselType");
        vesselLengthInput = vesselModalEl.querySelector("#vesselLength");
        vesselMakeInput = vesselModalEl.querySelector("#vesselMake");
        vesselModelInput = vesselModalEl.querySelector("#vesselModel");
        vesselColorInput = vesselModalEl.querySelector("#vesselColor");
        vesselHomePortInput = vesselModalEl.querySelector("#vesselHomePort");
        vesselSaveBtn = vesselModalEl.querySelector("#saveVesselBtn");
        vesselNameError = vesselModalEl.querySelector("#vesselNameError");
        vesselTypeError = vesselModalEl.querySelector("#vesselTypeError");
        vesselLengthError = vesselModalEl.querySelector("#vesselLengthError");
        vesselColorError = vesselModalEl.querySelector("#vesselColorError");
      }
    }

    if (vesselModalEl && !vesselModal && window.bootstrap && window.bootstrap.Modal) {
      vesselModal = new window.bootstrap.Modal(vesselModalEl);
    }

    if (vesselModalEl && !vesselModalEl.dataset.listenersAttached) {
      if (vesselFormEl) {
        vesselFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (vesselNameInput) {
        vesselNameInput.addEventListener("input", function () {
          clearFieldError(vesselNameInput, vesselNameError);
        });
      }
      if (vesselTypeInput) {
        vesselTypeInput.addEventListener("input", function () {
          clearFieldError(vesselTypeInput, vesselTypeError);
        });
      }
      if (vesselLengthInput) {
        vesselLengthInput.addEventListener("input", function () {
          clearFieldError(vesselLengthInput, vesselLengthError);
        });
      }
      if (vesselColorInput) {
        vesselColorInput.addEventListener("input", function () {
          clearFieldError(vesselColorInput, vesselColorError);
        });
      }
      if (vesselSaveBtn) {
        vesselSaveBtn.addEventListener("click", function () {
          saveVessel();
        });
      }
      vesselModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureContactModal() {
    if (!contactModalEl) {
      contactModalEl = document.getElementById("contactModal");
      if (contactModalEl) {
        contactFormEl = contactModalEl.querySelector("#contactForm");
        contactModalTitleEl = contactModalEl.querySelector("#contactModalLabel");
        contactIdInput = contactModalEl.querySelector("#contactId");
        contactNameInput = contactModalEl.querySelector("#contactName");
        contactPhoneInput = contactModalEl.querySelector("#contactPhone");
        contactEmailInput = contactModalEl.querySelector("#contactEmail");
        contactSaveBtn = contactModalEl.querySelector("#saveContactBtn");
        contactNameError = contactModalEl.querySelector("#contactNameError");
        contactPhoneError = contactModalEl.querySelector("#contactPhoneError");
        contactEmailError = contactModalEl.querySelector("#contactEmailError");
      }
    }

    if (contactModalEl && !contactModal && window.bootstrap && window.bootstrap.Modal) {
      contactModal = new window.bootstrap.Modal(contactModalEl);
    }

    if (contactModalEl && !contactModalEl.dataset.listenersAttached) {
      if (contactFormEl) {
        contactFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (contactPhoneInput) {
        contactPhoneInput.addEventListener("input", function () {
          contactPhoneInput.value = formatUsPhoneInput(contactPhoneInput.value);
          clearFieldError(contactPhoneInput, contactPhoneError);
        });
      }
      if (contactNameInput) {
        contactNameInput.addEventListener("input", function () {
          clearFieldError(contactNameInput, contactNameError);
        });
      }
      if (contactEmailInput) {
        contactEmailInput.addEventListener("input", function () {
          clearFieldError(contactEmailInput, contactEmailError);
        });
      }
      if (contactSaveBtn) {
        contactSaveBtn.addEventListener("click", function () {
          saveContact();
        });
      }
      contactModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensurePassengerModal() {
    if (!passengerModalEl) {
      passengerModalEl = document.getElementById("passengerModal");
      if (passengerModalEl) {
        passengerFormEl = passengerModalEl.querySelector("#passengerForm");
        passengerModalTitleEl = passengerModalEl.querySelector("#passengerModalLabel");
        passengerIdInput = passengerModalEl.querySelector("#passengerId");
        passengerNameInput = passengerModalEl.querySelector("#passengerName");
        passengerPhoneInput = passengerModalEl.querySelector("#passengerPhone");
        passengerAgeInput = passengerModalEl.querySelector("#passengerAge");
        passengerGenderInput = passengerModalEl.querySelector("#passengerGender");
        passengerNotesInput = passengerModalEl.querySelector("#passengerNotes");
        passengerSaveBtn = passengerModalEl.querySelector("#savePassengerBtn");
        passengerNameError = passengerModalEl.querySelector("#passengerNameError");
        passengerPhoneError = passengerModalEl.querySelector("#passengerPhoneError");
      }
    }

    if (passengerModalEl && !passengerModal && window.bootstrap && window.bootstrap.Modal) {
      passengerModal = new window.bootstrap.Modal(passengerModalEl);
    }

    if (passengerModalEl && !passengerModalEl.dataset.listenersAttached) {
      if (passengerFormEl) {
        passengerFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (passengerNameInput) {
        passengerNameInput.addEventListener("input", function () {
          clearFieldError(passengerNameInput, passengerNameError);
        });
      }
      if (passengerPhoneInput) {
        passengerPhoneInput.addEventListener("input", function () {
          passengerPhoneInput.value = formatUsPhoneInput(passengerPhoneInput.value);
          clearFieldError(passengerPhoneInput, passengerPhoneError);
        });
      }
      if (passengerSaveBtn) {
        passengerSaveBtn.addEventListener("click", function () {
          savePassenger();
        });
      }
      passengerModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureOperatorModal() {
    if (!operatorModalEl) {
      operatorModalEl = document.getElementById("operatorModal");
      if (operatorModalEl) {
        operatorFormEl = operatorModalEl.querySelector("#operatorForm");
        operatorModalTitleEl = operatorModalEl.querySelector("#operatorModalLabel");
        operatorIdInput = operatorModalEl.querySelector("#operatorId");
        operatorNameInput = operatorModalEl.querySelector("#operatorName");
        operatorPhoneInput = operatorModalEl.querySelector("#operatorPhone");
        operatorNotesInput = operatorModalEl.querySelector("#operatorNotes");
        operatorSaveBtn = operatorModalEl.querySelector("#saveOperatorBtn");
        operatorNameError = operatorModalEl.querySelector("#operatorNameError");
        operatorPhoneError = operatorModalEl.querySelector("#operatorPhoneError");
      }
    }

    if (operatorModalEl && !operatorModal && window.bootstrap && window.bootstrap.Modal) {
      operatorModal = new window.bootstrap.Modal(operatorModalEl);
    }

    if (operatorModalEl && !operatorModalEl.dataset.listenersAttached) {
      if (operatorFormEl) {
        operatorFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (operatorNameInput) {
        operatorNameInput.addEventListener("input", function () {
          clearFieldError(operatorNameInput, operatorNameError);
        });
      }
      if (operatorPhoneInput) {
        operatorPhoneInput.addEventListener("input", function () {
          operatorPhoneInput.value = formatUsPhoneInput(operatorPhoneInput.value);
          clearFieldError(operatorPhoneInput, operatorPhoneError);
        });
      }
      if (operatorSaveBtn) {
        operatorSaveBtn.addEventListener("click", function () {
          saveOperator();
        });
      }
      operatorModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureWaypointModal() {
    if (!waypointModalEl) {
      waypointModalEl = document.getElementById("waypointModal");
      if (waypointModalEl) {
        waypointFormEl = waypointModalEl.querySelector("#waypointForm");
        waypointModalTitleEl = waypointModalEl.querySelector("#waypointModalLabel");
        waypointIdInput = waypointModalEl.querySelector("#waypointId");
        waypointNameInput = waypointModalEl.querySelector("#waypointName");
        waypointLatitudeInput = waypointModalEl.querySelector("#waypointLatitude");
        waypointLongitudeInput = waypointModalEl.querySelector("#waypointLongitude");
        waypointNotesInput = waypointModalEl.querySelector("#waypointNotes");
        waypointSaveBtn = waypointModalEl.querySelector("#saveWaypointBtn");
        waypointNameError = waypointModalEl.querySelector("#waypointNameError");
      }
    }

    if (waypointModalEl && !waypointModal && window.bootstrap && window.bootstrap.Modal) {
      waypointModal = new window.bootstrap.Modal(waypointModalEl);
    }

    if (waypointModalEl && !waypointModalEl.dataset.listenersAttached) {
      if (waypointFormEl) {
        waypointFormEl.addEventListener("submit", function (event) {
          event.preventDefault();
        });
      }
      if (waypointNameInput) {
        waypointNameInput.addEventListener("input", function () {
          clearFieldError(waypointNameInput, waypointNameError);
        });
      }
      if (waypointSaveBtn) {
        waypointSaveBtn.addEventListener("click", function () {
          saveWaypoint();
        });
      }
      waypointModalEl.dataset.listenersAttached = "true";
    }
  }

  function ensureConfirmModal() {
    if (!confirmModalEl) {
      confirmModalEl = document.getElementById("confirmModal");
      if (confirmModalEl) {
        confirmMessageEl = confirmModalEl.querySelector("#confirmModalMessage");
        confirmOkBtn = confirmModalEl.querySelector("#confirmModalOk");
      }
    }

    if (confirmModalEl && !confirmModal && window.bootstrap && window.bootstrap.Modal) {
      confirmModal = new window.bootstrap.Modal(confirmModalEl);
    }

    if (confirmModalEl && !confirmModalEl.dataset.listenersAttached) {
      if (confirmOkBtn) {
        confirmOkBtn.addEventListener("click", function () {
          if (confirmResolver) {
            confirmResolver(true);
          }
          confirmResolver = null;
          if (confirmModal) {
            confirmModal.hide();
          }
        });
      }
      confirmModalEl.addEventListener("hidden.bs.modal", function () {
        if (confirmResolver) {
          confirmResolver(false);
          confirmResolver = null;
        }
      });
      confirmModalEl.dataset.listenersAttached = "true";
    }
  }

  function showConfirmModal(message) {
    ensureConfirmModal();
    if (!confirmModalEl || !confirmModal) {
      return Promise.resolve(window.confirm(message || "Are you sure?"));
    }
    if (confirmMessageEl) {
      confirmMessageEl.textContent = message || "Are you sure?";
    }
    confirmModal.show();
    return new Promise(function (resolve) {
      confirmResolver = resolve;
    });
  }

  function ensureAlertModal() {
    if (!alertModalEl) {
      alertModalEl = document.getElementById("alertModal");
      if (alertModalEl) {
        alertMessageEl = alertModalEl.querySelector("#alertModalMessage");
      }
    }

    if (alertModalEl && !alertModal && window.bootstrap && window.bootstrap.Modal) {
      alertModal = new window.bootstrap.Modal(alertModalEl);
    }
  }

  function showAlertModal(message) {
    ensureAlertModal();
    if (!alertModalEl || !alertModal) {
      window.alert(message || "");
      return;
    }
    if (alertMessageEl) {
      alertMessageEl.textContent = message || "";
    }
    alertModal.show();
  }

  function resetContactForm() {
    if (contactFormEl && contactFormEl.reset) {
      contactFormEl.reset();
    }
    if (contactIdInput) contactIdInput.value = "0";
    clearContactValidation();
  }

  function populateContactForm(contact) {
    if (!contact) {
      resetContactForm();
      return;
    }
    if (contactIdInput) contactIdInput.value = pick(contact, ["CONTACTID", "ID"], 0);
    if (contactNameInput) contactNameInput.value = pick(contact, ["CONTACTNAME", "NAME"], "");
    if (contactPhoneInput) contactPhoneInput.value = pick(contact, ["PHONE"], "");
    if (contactEmailInput) contactEmailInput.value = pick(contact, ["EMAIL"], "");
    clearContactValidation();
  }

  function populatePassengerForm(passenger) {
    if (!passenger) {
      resetPassengerForm();
      return;
    }
    if (passengerIdInput) passengerIdInput.value = pick(passenger, ["PASSENGERID", "ID"], 0);
    if (passengerNameInput) passengerNameInput.value = pick(passenger, ["PASSENGERNAME", "NAME"], "");
    if (passengerPhoneInput) passengerPhoneInput.value = pick(passenger, ["PHONE"], "");
    if (passengerAgeInput) passengerAgeInput.value = pick(passenger, ["AGE"], "");
    if (passengerGenderInput) passengerGenderInput.value = pick(passenger, ["GENDER"], "");
    if (passengerNotesInput) passengerNotesInput.value = pick(passenger, ["NOTES"], "");
    clearPassengerValidation();
  }

  function populateOperatorForm(operator) {
    if (!operator) {
      resetOperatorForm();
      return;
    }
    if (operatorIdInput) operatorIdInput.value = pick(operator, ["OPERATORID", "ID"], 0);
    if (operatorNameInput) operatorNameInput.value = pick(operator, ["OPERATORNAME", "NAME"], "");
    if (operatorPhoneInput) operatorPhoneInput.value = pick(operator, ["PHONE"], "");
    if (operatorNotesInput) operatorNotesInput.value = pick(operator, ["NOTES"], "");
    clearOperatorValidation();
  }

  function populateWaypointForm(waypoint) {
    if (!waypoint) {
      resetWaypointForm();
      return;
    }
    if (waypointIdInput) waypointIdInput.value = pick(waypoint, ["WAYPOINTID", "ID"], 0);
    if (waypointNameInput) waypointNameInput.value = pick(waypoint, ["WAYPOINTNAME", "NAME"], "");
    if (waypointLatitudeInput) waypointLatitudeInput.value = pick(waypoint, ["LATITUDE"], "");
    if (waypointLongitudeInput) waypointLongitudeInput.value = pick(waypoint, ["LONGITUDE"], "");
    if (waypointNotesInput) waypointNotesInput.value = pick(waypoint, ["NOTES"], "");
    clearWaypointValidation();
  }

  function openWaypointModal(waypoint) {
    ensureWaypointModal();
    if (!waypointModalEl || !waypointModal) {
      return;
    }
    var waypointId = waypoint ? pick(waypoint, ["WAYPOINTID", "ID"], 0) : 0;
    if (waypointModalTitleEl) {
      waypointModalTitleEl.textContent = waypointId ? "Edit Waypoint" : "Add Waypoint";
    }
    populateWaypointForm(waypoint);
    waypointModal.show();
  }

  function buildWaypointPayload() {
    return {
      WAYPOINTID: parseInt(waypointIdInput ? waypointIdInput.value : "0", 10) || 0,
      WAYPOINTNAME: waypointNameInput ? waypointNameInput.value.trim() : "",
      LATITUDE: waypointLatitudeInput ? waypointLatitudeInput.value.trim() : "",
      LONGITUDE: waypointLongitudeInput ? waypointLongitudeInput.value.trim() : "",
      NOTES: waypointNotesInput ? waypointNotesInput.value.trim() : ""
    };
  }

  function saveWaypoint() {
    if (!window.Api || typeof window.Api.saveWaypoint !== "function") {
      showAlertModal("Waypoints API is unavailable.");
      return;
    }

    var payload = buildWaypointPayload();
    clearWaypointValidation();
    var hasError = false;
    if (!payload.WAYPOINTNAME) {
      setFieldError(waypointNameInput, waypointNameError, "Name is required.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (waypointSaveBtn) {
      waypointSaveBtn.disabled = true;
      waypointSaveBtn.textContent = "Saving…";
    }

    Api.saveWaypoint({ waypoint: payload })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (waypointModal) {
          waypointModal.hide();
        }
        loadWaypoints();
      })
      .catch(function (err) {
        console.error("Failed to save waypoint:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save waypoint.");
      })
      .finally(function () {
        if (waypointSaveBtn) {
          waypointSaveBtn.disabled = false;
          waypointSaveBtn.textContent = "Save Waypoint";
        }
      });
  }

  function findWaypointById(waypointId) {
    var list = waypointState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = pick(list[i], ["WAYPOINTID", "ID"], 0);
      if (String(currentId) === String(waypointId)) {
        return list[i];
      }
    }
    return null;
  }

  function deleteWaypoint(waypointId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteWaypoint !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteWaypoint(waypointId)
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadWaypoints();
      })
      .catch(function (err) {
        console.error("Failed to delete waypoint:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handleWaypointsListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-waypoint-id]");
    if (!button) return;

    var waypointId = button.getAttribute("data-waypoint-id");
    var action = button.getAttribute("data-action");
    if (!waypointId) return;

    if (action === "edit") {
      var waypoint = findWaypointById(waypointId);
      openWaypointModal(waypoint);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeleteWaypoint !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeleteWaypoint(waypointId)
        .then(function (data) {
          if (!ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            showAlertModal(data.MESSAGE || "This waypoint cannot be deleted.");
            return;
          }
          var waypoint = findWaypointById(waypointId);
          var waypointName = waypoint ? pick(waypoint, ["WAYPOINTNAME", "NAME"], "") : "";
          var confirmText = waypointName ? "Delete " + waypointName + "?" : "Delete this waypoint?";
          showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteWaypoint(waypointId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check waypoint usage:", err);
          showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check waypoint usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }
  function openOperatorModal(operator) {
    ensureOperatorModal();
    if (!operatorModalEl || !operatorModal) {
      return;
    }
    var operatorId = operator ? pick(operator, ["OPERATORID", "ID"], 0) : 0;
    if (operatorModalTitleEl) {
      operatorModalTitleEl.textContent = operatorId ? "Edit Operator" : "Add Operator";
    }
    populateOperatorForm(operator);
    operatorModal.show();
  }

  function buildOperatorPayload() {
    return {
      OPERATORID: parseInt(operatorIdInput ? operatorIdInput.value : "0", 10) || 0,
      OPERATORNAME: operatorNameInput ? operatorNameInput.value.trim() : "",
      PHONE: operatorPhoneInput ? operatorPhoneInput.value.trim() : "",
      NOTES: operatorNotesInput ? operatorNotesInput.value.trim() : ""
    };
  }

  function saveOperator() {
    if (!window.Api || typeof window.Api.saveOperator !== "function") {
      showAlertModal("Operators API is unavailable.");
      return;
    }

    var payload = buildOperatorPayload();
    clearOperatorValidation();
    var hasError = false;
    if (!payload.OPERATORNAME) {
      setFieldError(operatorNameInput, operatorNameError, "Name is required.");
      hasError = true;
    }
    if (payload.PHONE && !isValidPhone(payload.PHONE)) {
      setFieldError(operatorPhoneInput, operatorPhoneError, "Enter a valid US phone number.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (operatorSaveBtn) {
      operatorSaveBtn.disabled = true;
      operatorSaveBtn.textContent = "Saving…";
    }

    Api.saveOperator({ operator: payload })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (operatorModal) {
          operatorModal.hide();
        }
        loadOperators();
      })
      .catch(function (err) {
        console.error("Failed to save operator:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save operator.");
      })
      .finally(function () {
        if (operatorSaveBtn) {
          operatorSaveBtn.disabled = false;
          operatorSaveBtn.textContent = "Save Operator";
        }
      });
  }

  function findOperatorById(operatorId) {
    var list = operatorState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = pick(list[i], ["OPERATORID", "ID"], 0);
      if (String(currentId) === String(operatorId)) {
        return list[i];
      }
    }
    return null;
  }

  function deleteOperator(operatorId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteOperator !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteOperator(operatorId)
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadOperators();
      })
      .catch(function (err) {
        console.error("Failed to delete operator:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handleOperatorsListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-operator-id]");
    if (!button) return;

    var operatorId = button.getAttribute("data-operator-id");
    var action = button.getAttribute("data-action");
    if (!operatorId) return;

    if (action === "edit") {
      var operator = findOperatorById(operatorId);
      openOperatorModal(operator);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeleteOperator !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeleteOperator(operatorId)
        .then(function (data) {
          if (!ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            showAlertModal(data.MESSAGE || "This operator cannot be deleted.");
            return;
          }
          var operator = findOperatorById(operatorId);
          var operatorName = operator ? pick(operator, ["OPERATORNAME", "NAME"], "") : "";
          var confirmText = operatorName ? "Delete " + operatorName + "?" : "Delete this operator?";
          showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteOperator(operatorId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check operator usage:", err);
          showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check operator usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }
  function openPassengerModal(passenger) {
    ensurePassengerModal();
    if (!passengerModalEl || !passengerModal) {
      return;
    }
    var passengerId = passenger ? pick(passenger, ["PASSENGERID", "ID"], 0) : 0;
    if (passengerModalTitleEl) {
      passengerModalTitleEl.textContent = passengerId ? "Edit Passenger/Crew" : "Add Passenger/Crew";
    }
    populatePassengerForm(passenger);
    passengerModal.show();
  }

  function buildPassengerPayload() {
    return {
      PASSENGERID: parseInt(passengerIdInput ? passengerIdInput.value : "0", 10) || 0,
      PASSENGERNAME: passengerNameInput ? passengerNameInput.value.trim() : "",
      PHONE: passengerPhoneInput ? passengerPhoneInput.value.trim() : "",
      AGE: passengerAgeInput ? passengerAgeInput.value.trim() : "",
      GENDER: passengerGenderInput ? passengerGenderInput.value.trim() : "",
      NOTES: passengerNotesInput ? passengerNotesInput.value.trim() : ""
    };
  }

  function savePassenger() {
    if (!window.Api || typeof window.Api.savePassenger !== "function") {
      showAlertModal("Passengers API is unavailable.");
      return;
    }

    var payload = buildPassengerPayload();
    clearPassengerValidation();
    var hasError = false;
    if (!payload.PASSENGERNAME) {
      setFieldError(passengerNameInput, passengerNameError, "Name is required.");
      hasError = true;
    }
    if (payload.PHONE && !isValidPhone(payload.PHONE)) {
      setFieldError(passengerPhoneInput, passengerPhoneError, "Enter a valid US phone number.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (passengerSaveBtn) {
      passengerSaveBtn.disabled = true;
      passengerSaveBtn.textContent = "Saving…";
    }

    Api.savePassenger({ passenger: payload })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (passengerModal) {
          passengerModal.hide();
        }
        loadPassengers();
      })
      .catch(function (err) {
        console.error("Failed to save passenger:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save passenger.");
      })
      .finally(function () {
        if (passengerSaveBtn) {
          passengerSaveBtn.disabled = false;
          passengerSaveBtn.textContent = "Save Passenger";
        }
      });
  }

  function findPassengerById(passengerId) {
    var list = passengerState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = pick(list[i], ["PASSENGERID", "ID"], 0);
      if (String(currentId) === String(passengerId)) {
        return list[i];
      }
    }
    return null;
  }

  function deletePassenger(passengerId, triggerButton) {
    if (!window.Api || typeof window.Api.deletePassenger !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deletePassenger(passengerId)
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadPassengers();
      })
      .catch(function (err) {
        console.error("Failed to delete passenger:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handlePassengersListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-passenger-id]");
    if (!button) return;

    var passengerId = button.getAttribute("data-passenger-id");
    var action = button.getAttribute("data-action");
    if (!passengerId) return;

    if (action === "edit") {
      var passenger = findPassengerById(passengerId);
      openPassengerModal(passenger);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeletePassenger !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeletePassenger(passengerId)
        .then(function (data) {
          if (!ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            showAlertModal(data.MESSAGE || "This passenger cannot be deleted.");
            return;
          }
          var passenger = findPassengerById(passengerId);
          var passengerName = passenger ? pick(passenger, ["PASSENGERNAME", "NAME"], "") : "";
          var confirmText = passengerName ? "Delete " + passengerName + "?" : "Delete this passenger?";
          showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deletePassenger(passengerId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check passenger usage:", err);
          showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check passenger usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function openContactModal(contact) {
    ensureContactModal();
    if (!contactModalEl || !contactModal) {
      return;
    }
    var contactId = contact ? pick(contact, ["CONTACTID", "ID"], 0) : 0;
    if (contactModalTitleEl) {
      contactModalTitleEl.textContent = contactId ? "Edit Contact" : "Add Contact";
    }
    populateContactForm(contact);
    contactModal.show();
  }

  function buildContactPayload() {
    return {
      CONTACTID: parseInt(contactIdInput ? contactIdInput.value : "0", 10) || 0,
      CONTACTNAME: contactNameInput ? contactNameInput.value.trim() : "",
      PHONE: contactPhoneInput ? contactPhoneInput.value.trim() : "",
      EMAIL: contactEmailInput ? contactEmailInput.value.trim() : ""
    };
  }

  function isValidEmail(value) {
    if (!value) return false;
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  function isValidPhone(value) {
    if (!value) return false;
    var digits = String(value).replace(/\D/g, "");
    if (digits.length === 11 && digits.charAt(0) === "1") {
      digits = digits.slice(1);
    }
    return digits.length === 10;
  }

  function formatUsPhoneInput(value) {
    var digits = String(value || "").replace(/\D/g, "");
    if (digits.charAt(0) === "1" && digits.length > 10) {
      digits = digits.slice(1);
    }
    digits = digits.slice(0, 10);

    if (digits.length <= 3) {
      return digits.length ? "(" + digits : "";
    }
    if (digits.length <= 6) {
      return "(" + digits.slice(0, 3) + ") " + digits.slice(3);
    }
    return "(" + digits.slice(0, 3) + ") " + digits.slice(3, 6) + "-" + digits.slice(6);
  }

  function saveContact() {
    if (!window.Api || typeof window.Api.saveContact !== "function") {
      showAlertModal("Contacts API is unavailable.");
      return;
    }

    var payload = buildContactPayload();
    clearContactValidation();
    var hasError = false;
    if (!payload.CONTACTNAME) {
      setFieldError(contactNameInput, contactNameError, "Contact name is required.");
      hasError = true;
    }
    if (!payload.PHONE) {
      setFieldError(contactPhoneInput, contactPhoneError, "Phone is required.");
      hasError = true;
    } else if (!isValidPhone(payload.PHONE)) {
      setFieldError(contactPhoneInput, contactPhoneError, "Enter a valid US phone number.");
      hasError = true;
    }
    if (!payload.EMAIL) {
      setFieldError(contactEmailInput, contactEmailError, "Email is required.");
      hasError = true;
    } else if (!isValidEmail(payload.EMAIL)) {
      setFieldError(contactEmailInput, contactEmailError, "Enter a valid email address.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (contactSaveBtn) {
      contactSaveBtn.disabled = true;
      contactSaveBtn.textContent = "Saving…";
    }

    Api.saveContact({ contact: payload })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (contactModal) {
          contactModal.hide();
        }
        loadContacts();
      })
      .catch(function (err) {
        console.error("Failed to save contact:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save contact.");
      })
      .finally(function () {
        if (contactSaveBtn) {
          contactSaveBtn.disabled = false;
          contactSaveBtn.textContent = "Save Contact";
        }
      });
  }

  function findContactById(contactId) {
    var list = contactState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = pick(list[i], ["CONTACTID", "ID"], 0);
      if (String(currentId) === String(contactId)) {
        return list[i];
      }
    }
    return null;
  }

  function deleteContact(contactId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteContact !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteContact(contactId)
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadContacts();
      })
      .catch(function (err) {
        console.error("Failed to delete contact:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handleContactsListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-contact-id]");
    if (!button) return;

    var contactId = button.getAttribute("data-contact-id");
    var action = button.getAttribute("data-action");
    if (!contactId) return;

    if (action === "edit") {
      var contact = findContactById(contactId);
      openContactModal(contact);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeleteContact !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeleteContact(contactId)
        .then(function (data) {
          if (!ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            showAlertModal(data.MESSAGE || "This contact cannot be deleted.");
            return;
          }
          var contact = findContactById(contactId);
          var contactName = contact ? pick(contact, ["CONTACTNAME", "NAME"], "") : "";
          var confirmText = contactName ? "Delete " + contactName + "?" : "Delete this contact?";
          showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteContact(contactId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check contact usage:", err);
          showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check contact usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function setFieldError(inputEl, errorEl, message) {
    if (inputEl) {
      inputEl.classList.add("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = message || "";
    }
  }

  function clearFieldError(inputEl, errorEl) {
    if (inputEl) {
      inputEl.classList.remove("is-invalid");
    }
    if (errorEl) {
      errorEl.textContent = "";
    }
  }

  function clearVesselValidation() {
    clearFieldError(vesselNameInput, vesselNameError);
    clearFieldError(vesselTypeInput, vesselTypeError);
    clearFieldError(vesselLengthInput, vesselLengthError);
    clearFieldError(vesselColorInput, vesselColorError);
  }

  function clearContactValidation() {
    clearFieldError(contactNameInput, contactNameError);
    clearFieldError(contactPhoneInput, contactPhoneError);
    clearFieldError(contactEmailInput, contactEmailError);
  }

  function clearPassengerValidation() {
    clearFieldError(passengerNameInput, passengerNameError);
    clearFieldError(passengerPhoneInput, passengerPhoneError);
  }

  function clearOperatorValidation() {
    clearFieldError(operatorNameInput, operatorNameError);
    clearFieldError(operatorPhoneInput, operatorPhoneError);
  }

  function clearWaypointValidation() {
    clearFieldError(waypointNameInput, waypointNameError);
  }

  function resetVesselForm() {
    if (vesselFormEl && vesselFormEl.reset) {
      vesselFormEl.reset();
    }
    if (vesselIdInput) vesselIdInput.value = "0";
    clearVesselValidation();
  }

  function resetPassengerForm() {
    if (passengerFormEl && passengerFormEl.reset) {
      passengerFormEl.reset();
    }
    if (passengerIdInput) passengerIdInput.value = "0";
    clearPassengerValidation();
  }

  function resetOperatorForm() {
    if (operatorFormEl && operatorFormEl.reset) {
      operatorFormEl.reset();
    }
    if (operatorIdInput) operatorIdInput.value = "0";
    clearOperatorValidation();
  }

  function resetWaypointForm() {
    if (waypointFormEl && waypointFormEl.reset) {
      waypointFormEl.reset();
    }
    if (waypointIdInput) waypointIdInput.value = "0";
    clearWaypointValidation();
  }

  function populateVesselForm(vessel) {
    if (!vessel) {
      resetVesselForm();
      return;
    }
    if (vesselIdInput) vesselIdInput.value = pick(vessel, ["VESSELID", "ID"], 0);
    if (vesselNameInput) vesselNameInput.value = pick(vessel, ["VESSELNAME", "NAME"], "");
    if (vesselRegistrationInput) vesselRegistrationInput.value = pick(vessel, ["REGISTRATION", "REGNO"], "");
    if (vesselTypeInput) vesselTypeInput.value = pick(vessel, ["TYPE"], "");
    if (vesselLengthInput) vesselLengthInput.value = pick(vessel, ["LENGTH"], "");
    if (vesselMakeInput) vesselMakeInput.value = pick(vessel, ["MAKE"], "");
    if (vesselModelInput) vesselModelInput.value = pick(vessel, ["MODEL"], "");
    if (vesselColorInput) vesselColorInput.value = pick(vessel, ["COLOR"], "");
    if (vesselHomePortInput) vesselHomePortInput.value = pick(vessel, ["HOMEPORT"], "");
    clearVesselValidation();
  }

  function openVesselModal(vessel) {
    ensureVesselModal();
    if (!vesselModalEl || !vesselModal) {
      return;
    }
    var vesselId = vessel ? pick(vessel, ["VESSELID", "ID"], 0) : 0;
    if (vesselModalTitleEl) {
      vesselModalTitleEl.textContent = vesselId ? "Edit Vessel" : "Add Vessel";
    }
    populateVesselForm(vessel);
    vesselModal.show();
  }

  function buildVesselPayload() {
    return {
      VESSELID: parseInt(vesselIdInput ? vesselIdInput.value : "0", 10) || 0,
      VESSELNAME: vesselNameInput ? vesselNameInput.value.trim() : "",
      REGISTRATION: vesselRegistrationInput ? vesselRegistrationInput.value.trim() : "",
      TYPE: vesselTypeInput ? vesselTypeInput.value.trim() : "",
      LENGTH: vesselLengthInput ? vesselLengthInput.value.trim() : "",
      MAKE: vesselMakeInput ? vesselMakeInput.value.trim() : "",
      MODEL: vesselModelInput ? vesselModelInput.value.trim() : "",
      COLOR: vesselColorInput ? vesselColorInput.value.trim() : "",
      HOMEPORT: vesselHomePortInput ? vesselHomePortInput.value.trim() : ""
    };
  }

  function saveVessel() {
    if (!window.Api || typeof window.Api.saveVessel !== "function") {
      showAlertModal("Vessel API is unavailable.");
      return;
    }

    var payload = buildVesselPayload();
    clearVesselValidation();
    var hasError = false;
    if (!payload.VESSELNAME) {
      setFieldError(vesselNameInput, vesselNameError, "Vessel name is required.");
      hasError = true;
    }
    if (!payload.TYPE) {
      setFieldError(vesselTypeInput, vesselTypeError, "Vessel type is required.");
      hasError = true;
    }
    if (!payload.LENGTH) {
      setFieldError(vesselLengthInput, vesselLengthError, "Vessel length is required.");
      hasError = true;
    }
    if (!payload.COLOR) {
      setFieldError(vesselColorInput, vesselColorError, "Hull color is required.");
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (vesselSaveBtn) {
      vesselSaveBtn.disabled = true;
      vesselSaveBtn.textContent = "Saving…";
    }

    Api.saveVessel({ vessel: payload })
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (data.SUCCESS !== true) {
          throw data;
        }
        if (vesselModal) {
          vesselModal.hide();
        }
        loadVessels();
      })
      .catch(function (err) {
        console.error("Failed to save vessel:", err);
        showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save vessel.");
      })
      .finally(function () {
        if (vesselSaveBtn) {
          vesselSaveBtn.disabled = false;
          vesselSaveBtn.textContent = "Save Vessel";
        }
      });
  }

  function findVesselById(vesselId) {
    var list = vesselState.all || [];
    for (var i = 0; i < list.length; i++) {
      var currentId = pick(list[i], ["VESSELID", "ID"], 0);
      if (String(currentId) === String(vesselId)) {
        return list[i];
      }
    }
    return null;
  }

  function deleteVessel(vesselId, triggerButton) {
    if (!window.Api || typeof window.Api.deleteVessel !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Deleting…";
    }

    Api.deleteVessel(vesselId)
      .then(function (data) {
        if (!ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadVessels();
      })
      .catch(function (err) {
        console.error("Failed to delete vessel:", err);
        showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function handleVesselsListClick(event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest("button[data-vessel-id]");
    if (!button) return;

    var vesselId = button.getAttribute("data-vessel-id");
    var action = button.getAttribute("data-action");
    if (!vesselId) return;

    if (action === "edit") {
      var vessel = findVesselById(vesselId);
      openVesselModal(vessel);
    } else if (action === "delete") {
      if (!window.Api || typeof window.Api.canDeleteVessel !== "function") {
        return;
      }
      button.disabled = true;
      Api.canDeleteVessel(vesselId)
        .then(function (data) {
          if (!ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            showAlertModal(data.MESSAGE || "This vessel cannot be deleted.");
            return;
          }
          var vessel = findVesselById(vesselId);
          var vesselName = vessel ? pick(vessel, ["VESSELNAME", "NAME"], "") : "";
          var confirmText = vesselName ? "Delete " + vesselName + "?" : "Delete this vessel?";
          showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteVessel(vesselId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check vessel usage:", err);
          showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check vessel usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
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
    ensureVesselModal();
    ensureContactModal();
    ensurePassengerModal();
    ensureOperatorModal();
    ensureWaypointModal();
    ensureConfirmModal();
    ensureAlertModal();
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

    var addVesselBtn = document.getElementById("addVesselBtn");
    if (addVesselBtn) {
      addVesselBtn.addEventListener("click", function () {
        openVesselModal(null);
      });
    }

    var addContactBtn = document.getElementById("addContactBtn");
    if (addContactBtn) {
      addContactBtn.addEventListener("click", function () {
        openContactModal(null);
      });
    }

    var addPassengerBtn = document.getElementById("addPassengerBtn");
    if (addPassengerBtn) {
      addPassengerBtn.addEventListener("click", function () {
        openPassengerModal(null);
      });
    }

    var addOperatorBtn = document.getElementById("addOperatorBtn");
    if (addOperatorBtn) {
      addOperatorBtn.addEventListener("click", function () {
        openOperatorModal(null);
      });
    }

    var addWaypointBtn = document.getElementById("addWaypointBtn");
    if (addWaypointBtn) {
      addWaypointBtn.addEventListener("click", function () {
        openWaypointModal(null);
      });
    }

    var listEl = document.getElementById("floatPlansList");
    if (listEl) {
      listEl.addEventListener("click", handleFloatPlansListClick);
    }

    var vesselsListEl = document.getElementById("vesselsList");
    if (vesselsListEl) {
      vesselsListEl.addEventListener("click", handleVesselsListClick);
    }

    var contactsListEl = document.getElementById("contactsList");
    if (contactsListEl) {
      contactsListEl.addEventListener("click", handleContactsListClick);
    }

    var passengersListEl = document.getElementById("passengersList");
    if (passengersListEl) {
      passengersListEl.addEventListener("click", handlePassengersListClick);
    }

    var operatorsListEl = document.getElementById("operatorsList");
    if (operatorsListEl) {
      operatorsListEl.addEventListener("click", handleOperatorsListClick);
    }

    var waypointsListEl = document.getElementById("waypointsList");
    if (waypointsListEl) {
      waypointsListEl.addEventListener("click", handleWaypointsListClick);
    }
  }

  document.addEventListener("DOMContentLoaded", initDashboard);
})(window, document);
