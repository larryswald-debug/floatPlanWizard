// Updated to support modal-driven init/destroy for the float plan wizard.
// /fpw/assets/js/app/floatplanWizard.js
(function (window, document, Vue) {
  "use strict";

  function normalizeBasePath(value) {
    if (!value) return "";
    var normalized = String(value).replace(/\/+$/, "");
    if (normalized === "/") return "";
    if (/^https?:\/\//i.test(normalized)) return normalized;
    return normalized.charAt(0) === "/" ? normalized : "/" + normalized;
  }

  function getScriptBasePath(fileName) {
    var script = document.currentScript;
    if (!script || !script.getAttribute) return "";

    var src = script.getAttribute("src") || "";
    if (!src) return "";

    var anchor = document.createElement("a");
    anchor.href = src;

    var scriptPath = anchor.pathname || src;
    var marker = "/assets/js/app/" + fileName;
    var markerIndex = scriptPath.toLowerCase().indexOf(marker.toLowerCase());

    if (markerIndex === -1) return "";
    return normalizeBasePath(scriptPath.slice(0, markerIndex));
  }

  function getLocationBasePath() {
    var basePath = window.location.pathname || "";
    basePath = basePath.replace(/[?#].*$/, "");
    basePath = basePath.replace(/\/api\/v1(\/.*)?$/i, "");
    basePath = basePath.replace(/\/(app|admin|assets|tests)(\/.*)?$/i, "");
    basePath = basePath.replace(/\/[^/]*\.(cfm|cfc)$/i, "");
    basePath = basePath.replace(/\/$/, "");
    return normalizeBasePath(basePath);
  }

  var BASE_PATH = (function () {
    if (Object.prototype.hasOwnProperty.call(window, "FPW_BASE")) {
      return normalizeBasePath(window.FPW_BASE);
    }

    return getScriptBasePath("floatplanWizard.js") || getLocationBasePath();
  })();

  if (!Vue) {
    console.error("Vue is required for the float plan wizard.");
  }

  var wizardApp = null;
  var wizardAppInstance = null;
  var wizardMountEl = null;
  var wizardTemplateHtml = "";

  var DEFAULT_TIMEZONES = [
    "US/Eastern",
    "US/Central",
    "US/Mountain",
    "US/Pacific",
    "US/Alaska",
    "US/Hawaii",
    "America/Puerto_Rico",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "America/New_York",
    "America/Phoenix",
    "America/Anchorage",
    "Pacific/Honolulu"
  ];

  var STATE_TO_TIMEZONE = {
    AL: "US/Central",
    AK: "US/Alaska",
    AZ: "US/Mountain",
    AR: "US/Central",
    CA: "US/Pacific",
    CO: "US/Mountain",
    CT: "US/Eastern",
    DE: "US/Eastern",
    FL: "US/Eastern",
    GA: "US/Eastern",
    HI: "US/Hawaii",
    ID: "US/Mountain",
    IL: "US/Central",
    IN: "US/Eastern",
    IA: "US/Central",
    KS: "US/Central",
    KY: "US/Eastern",
    LA: "US/Central",
    ME: "US/Eastern",
    MD: "US/Eastern",
    MA: "US/Eastern",
    MI: "US/Eastern",
    MN: "US/Central",
    MS: "US/Central",
    MO: "US/Central",
    MT: "US/Mountain",
    NE: "US/Central",
    NV: "US/Pacific",
    NH: "US/Eastern",
    NJ: "US/Eastern",
    NM: "US/Mountain",
    NY: "US/Eastern",
    NC: "US/Eastern",
    ND: "US/Central",
    OH: "US/Eastern",
    OK: "US/Central",
    OR: "US/Pacific",
    PA: "US/Eastern",
    RI: "US/Eastern",
    SC: "US/Eastern",
    SD: "US/Central",
    TN: "US/Central",
    TX: "US/Central",
    UT: "US/Mountain",
    VT: "US/Eastern",
    VA: "US/Eastern",
    WA: "US/Pacific",
    WV: "US/Eastern",
    WI: "US/Central",
    WY: "US/Mountain",
    DC: "US/Eastern",
    PR: "America/Puerto_Rico"
  };

  var STATE_NAME_TO_CODE = {
    ALABAMA: "AL",
    ALASKA: "AK",
    ARIZONA: "AZ",
    ARKANSAS: "AR",
    CALIFORNIA: "CA",
    COLORADO: "CO",
    CONNECTICUT: "CT",
    DELAWARE: "DE",
    FLORIDA: "FL",
    GEORGIA: "GA",
    HAWAII: "HI",
    IDAHO: "ID",
    ILLINOIS: "IL",
    INDIANA: "IN",
    IOWA: "IA",
    KANSAS: "KS",
    KENTUCKY: "KY",
    LOUISIANA: "LA",
    MAINE: "ME",
    MARYLAND: "MD",
    MASSACHUSETTS: "MA",
    MICHIGAN: "MI",
    MINNESOTA: "MN",
    MISSISSIPPI: "MS",
    MISSOURI: "MO",
    MONTANA: "MT",
    NEBRASKA: "NE",
    NEVADA: "NV",
    "NEW HAMPSHIRE": "NH",
    "NEW JERSEY": "NJ",
    "NEW MEXICO": "NM",
    "NEW YORK": "NY",
    "NORTH CAROLINA": "NC",
    "NORTH DAKOTA": "ND",
    OHIO: "OH",
    OKLAHOMA: "OK",
    OREGON: "OR",
    PENNSYLVANIA: "PA",
    "RHODE ISLAND": "RI",
    "SOUTH CAROLINA": "SC",
    "SOUTH DAKOTA": "SD",
    TENNESSEE: "TN",
    TEXAS: "TX",
    UTAH: "UT",
    VERMONT: "VT",
    VIRGINIA: "VA",
    WASHINGTON: "WA",
    "WEST VIRGINIA": "WV",
    WISCONSIN: "WI",
    WYOMING: "WY",
    "DISTRICT OF COLUMBIA": "DC",
    "PUERTO RICO": "PR"
  };

  function normalizeStateCode(stateValue) {
    if (!stateValue) {
      return "";
    }
    var normalized = stateValue.toString().trim().toUpperCase();
    if (!normalized) {
      return "";
    }
    if (STATE_TO_TIMEZONE[normalized]) {
      return normalized;
    }
    if (STATE_NAME_TO_CODE[normalized]) {
      return STATE_NAME_TO_CODE[normalized];
    }
    return "";
  }

  function getTimezoneForState(stateValue) {
    var code = normalizeStateCode(stateValue);
    if (!code) {
      return "";
    }
    return STATE_TO_TIMEZONE[code] || "";
  }

  function toArray(value) {
    return Array.isArray(value) ? value.slice() : [];
  }

  function numeric(value) {
    var num = parseInt(value, 10);
    return isNaN(num) ? 0 : num;
  }

  function memberAccessValue(access, key, fallbackValue) {
    var source = access && typeof access === "object" ? access : {};
    var upperKey = String(key || "").toUpperCase();
    if (Object.prototype.hasOwnProperty.call(source, key)) {
      return source[key];
    }
    if (upperKey && Object.prototype.hasOwnProperty.call(source, upperKey)) {
      return source[upperKey];
    }
    return fallbackValue;
  }

  function truthyAccessValue(value) {
    if (value === true || value === 1) {
      return true;
    }
    var normalized = String(value == null ? "" : value).trim().toLowerCase();
    return normalized === "true" || normalized === "1";
  }

  function getAppPrefix() {
    return BASE_PATH;
  }

  function buildPdfPreviewUrl(floatPlanId) {
    var planId = numeric(floatPlanId);
    if (!planId) {
      return "";
    }
    return getAppPrefix() + "/api/v1/floatplan.cfc?method=handle&action=previewpdf&id=" + encodeURIComponent(planId);
  }

  function createEmptyFloatPlan() {
    return {
      FLOATPLANID: 0,
      NAME: "",
      VESSELID: 0,
      OPERATORID: 0,
      OPERATOR_HAS_PFD: true,
      EMAIL: "",
      RESCUE_AUTHORITY: "",
      RESCUE_AUTHORITY_PHONE: "",
      RESCUE_CENTERID: 0,
      DEPARTING_FROM: "",
      DEPARTURE_TIME: "",
      DEPARTURE_TIMEZONE: "",
      DEPARTURE_TIME_UTC: "",
      RETURNING_TO: "",
      RETURN_TIME: "",
      RETURN_TIMEZONE: "",
      RETURN_TIME_UTC: "",
      FOOD_DAYS_PER_PERSON: "",
      WATER_DAYS_PER_PERSON: "",
      NOTES: "",
      DO_NOT_SEND: false,
      STATUS: "Draft"
    };
  }

  function pad2(value) {
    return value < 10 ? "0" + value : "" + value;
  }

  function toDateTimeLocal(value) {
    if (value === undefined || value === null) {
      return "";
    }
    if (value instanceof Date) {
      return [
        value.getFullYear(),
        "-",
        pad2(value.getMonth() + 1),
        "-",
        pad2(value.getDate()),
        "T",
        pad2(value.getHours()),
        ":",
        pad2(value.getMinutes())
      ].join("");
    }
    var raw = ("" + value).trim();
    if (!raw) return "";
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(raw)) {
      return raw.slice(0, 16);
    }
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(raw)) {
      return raw.replace(" ", "T").slice(0, 16);
    }
    var parsed = new Date(raw);
    if (!isNaN(parsed.getTime())) {
      return toDateTimeLocal(parsed);
    }
    return "";
  }

  function normalizeFloatPlan(source) {
    var plan = createEmptyFloatPlan();
    if (source && typeof source === "object") {
      Object.keys(source).forEach(function (key) {
        plan[key] = source[key];
      });
    }
    plan.FLOATPLANID = numeric(plan.FLOATPLANID);
    plan.VESSELID = numeric(plan.VESSELID);
    plan.OPERATORID = numeric(plan.OPERATORID);
    plan.OPERATOR_HAS_PFD = !!plan.OPERATOR_HAS_PFD;
    plan.RESCUE_CENTERID = numeric(plan.RESCUE_CENTERID);
    plan.DEPARTURE_TIME = toDateTimeLocal(plan.DEPARTURE_TIME);
    plan.RETURN_TIME = toDateTimeLocal(plan.RETURN_TIME);
    return plan;
  }

  function getRescueCenterField(center, key) {
    if (!center || typeof center !== "object") {
      return "";
    }
    if (center[key] !== undefined && center[key] !== null) {
      return center[key];
    }
    var upperKey = key.toUpperCase();
    if (center[upperKey] !== undefined && center[upperKey] !== null) {
      return center[upperKey];
    }
    return "";
  }

  function normalizeRescueCenter(center) {
    if (!center || typeof center !== "object") {
      center = {};
    }
    var normalized = {
      recId: numeric(getRescueCenterField(center, "recId")),
      rcName: (getRescueCenterField(center, "rcName") || "").toString().trim(),
      rcPhone: (getRescueCenterField(center, "rcPhone") || "").toString().trim(),
      rcDistrict: (getRescueCenterField(center, "rcDistrict") || "").toString().trim(),
      rcArea: (getRescueCenterField(center, "rcArea") || "").toString().trim(),
      rcLocation: (getRescueCenterField(center, "rcLocation") || "").toString().trim()
    };
    return normalized;
  }

  function normalizePassengerSelection(entry) {
    if (!entry) return null;
    var id = numeric(entry.PASSENGERID || entry.passengerId || entry.PASSID || entry.passId);
    if (id <= 0) return null;
    return {
      PASSENGERID: id,
      HAS_PFD: entry.HAS_PFD !== undefined ? !!entry.HAS_PFD : true,
      SORT_ORDER: numeric(entry.SORT_ORDER || entry.sortOrder)
    };
  }

  function normalizeContactSelection(entry) {
    if (!entry) return null;
    var id = numeric(entry.CONTACTID || entry.contactId);
    if (id <= 0) return null;
    return {
      CONTACTID: id,
      SORT_ORDER: numeric(entry.SORT_ORDER || entry.sortOrder)
    };
  }

  function normalizeWaypointSelection(entry) {
    if (!entry) return null;
    var id = numeric(entry.WAYPOINTID || entry.waypointId || entry.wpId);
    if (!id) return null;
    return {
      WAYPOINTID: id,
      SORT_ORDER: numeric(entry.SORT_ORDER || entry.sortOrder),
      REASON_FOR_STOP: entry.REASON_FOR_STOP || entry.reasonForStop || "",
      DEPART_MODE: entry.DEPART_MODE || entry.departMode || "",
      ARRIVAL_TIME: entry.ARRIVAL_TIME || entry.arrivalTime || "",
      DEPARTURE_TIME: entry.DEPARTURE_TIME || entry.departureTime || ""
    };
  }

  function parseHomePortFlag(value) {
    if (value === undefined || value === null) {
      return 0;
    }
    if (typeof value === "boolean") {
      return value ? 1 : 0;
    }
    var normalized = (typeof value === "string") ? value.trim().toLowerCase() : "";
    if (normalized === "true" || normalized === "1") {
      return 1;
    }
    if (normalized === "false" || normalized === "0") {
      return 0;
    }
    return numeric(value);
  }

  function normalizeHomePort(source) {
    if (!source || typeof source !== "object") {
      return null;
    }
    var isHomePortValue = parseHomePortFlag(
      source.ISHOMEPORT ||
      source.isHomePort ||
      source.is_home_port ||
      source.isHomeport ||
      source.is_homeport ||
      source.home_port ||
      source.homePort ||
      0
    );
    if (isHomePortValue <= 0) {
      return null;
    }
    var rawState = (source.STATE || source.state || "").toString().trim();
    var stateCode = normalizeStateCode(rawState);
    return {
      recId: numeric(source.RECID || source.recId || 0),
      address: (source.ADDRESS || source.address || "").toString().trim(),
      city: (source.CITY || source.city || "").toString().trim(),
      state: stateCode || rawState.toUpperCase(),
      zip: (source.ZIP || source.zip || "").toString().trim(),
      phone: (source.PHONE || source.phone || "").toString().trim(),
      lat: (source.LAT || source.lat || "").toString().trim(),
      lng: (source.LNG || source.lng || "").toString().trim(),
      isHomePort: true
    };
  }

  function getPlanIdFromQuery() {
    var search = window.location.search || "";
    if (typeof URLSearchParams === "undefined") {
      var match = search.match(/[?&](?:id|planId|floatPlanId)=([0-9]+)/i);
      return match ? numeric(match[1]) : 0;
    }
    var params = new URLSearchParams(search);
    return numeric(params.get("id") || params.get("planId") || params.get("floatPlanId"));
  }

  function getOneTripCheckoutReturn() {
    var search = window.location.search || "";
    var state = "";
    var product = "";
    if (!search) return "";
    if (typeof URLSearchParams === "undefined") {
      var stateMatch = search.match(/[?&]stripe_checkout=(success|cancel)(?:&|$)/i);
      var productMatch = search.match(/[?&]fpw_checkout=one_trip(?:&|$)/i);
      return stateMatch && productMatch ? String(stateMatch[1]).toLowerCase() : "";
    }
    var params = new URLSearchParams(search);
    state = String(params.get("stripe_checkout") || "").trim().toLowerCase();
    product = String(params.get("fpw_checkout") || "").trim().toLowerCase();
    return product === "one_trip" && (state === "success" || state === "cancel") ? state : "";
  }

  function clearOneTripCheckoutReturnFromLocation() {
    if (!window.history || typeof window.history.replaceState !== "function" || typeof URLSearchParams === "undefined") return;
    var params = new URLSearchParams(window.location.search || "");
    params.delete("stripe_checkout");
    params.delete("fpw_checkout");
    var query = params.toString();
    window.history.replaceState({}, document.title, window.location.pathname + (query ? "?" + query : "") + (window.location.hash || ""));
  }

  function sortByOrder(list, field) {
    return list.sort(function (a, b) {
      return numeric(a[field]) - numeric(b[field]);
    });
  }

  function findName(list, idField, labelField, id) {
    var targetId = numeric(id);
    for (var i = 0; i < list.length; i++) {
      if (numeric(list[i][idField]) === targetId) {
        return list[i][labelField] || "";
      }
    }
    return "";
  }

  function summarizeSelections(selections, sourceList, idField, labelField) {
    if (!selections.length) return "";
    var names = [];
    for (var i = 0; i < selections.length; i++) {
      var selectionId = numeric(selections[i][idField]);
      var found = null;
      for (var j = 0; j < sourceList.length; j++) {
        if (numeric(sourceList[j][idField]) === selectionId) {
          found = sourceList[j];
          break;
        }
      }
      if (found && found[labelField]) {
        names.push(found[labelField]);
      } else if (selectionId) {
        names.push("#" + selectionId);
      }
    }
    return names.join(", ");
  }

  function normalizeSearchQuery(value) {
    return String(value || "").toLowerCase().trim();
  }

  function toSearchableText(entry, fields) {
    var parts = [];
    for (var i = 0; i < fields.length; i++) {
      var key = fields[i];
      if (entry && entry[key] !== undefined && entry[key] !== null) {
        parts.push(String(entry[key]));
      }
    }
    return parts.join(" ").toLowerCase();
  }

  var RESCUE_AUTHORITY_SELECTION_FIELD = "RESCUE_AUTHORITY_SELECTION";
  var RESCUE_AUTHORITY_SELECTION_MESSAGE = "Select a rescue authority.";
  var NA_RESCUE_CENTER_ID = -1;
  var NA_RESCUE_AUTHORITY_LABEL = "N/A - Call 911";
  var NA_RESCUE_AUTHORITY_PHONE = "911";

  function normalizeRouteDefaults(source) {
    var defaults = {
      IS_FROM_ROUTE: false,
      OPERATOR_ID: 0,
      OPERATOR_SOURCE: "",
      DATES_SOURCE: "",
      DEPARTING_FROM_DEFAULT: "",
      RETURNING_TO_DEFAULT: "",
      DEPARTURE_TIME_DEFAULT: "",
      RETURN_TIME_DEFAULT: "",
      LEG_COUNT: 0,
      WAYPOINT_SELECTIONS: []
    };
    if (source && typeof source === "object") {
      Object.keys(source).forEach(function (key) {
        defaults[key] = source[key];
      });
    }
    defaults.IS_FROM_ROUTE = !!defaults.IS_FROM_ROUTE;
    defaults.OPERATOR_ID = numeric(defaults.OPERATOR_ID);
    defaults.LEG_COUNT = numeric(defaults.LEG_COUNT);
    defaults.WAYPOINT_SELECTIONS = toArray(defaults.WAYPOINT_SELECTIONS);
    return defaults;
  }

  var FLOATPLAN_VALIDATION_RULES = {
    NAME: {
      presence: {
        allowEmpty: false,
        message: "Float plan name is required."
      }
    },
    VESSELID: {
      presence: {
        allowEmpty: false,
        message: "Select a vessel."
      },
      numericality: {
        onlyInteger: true,
        greaterThan: 0,
        message: "Select a vessel."
      }
    },
    OPERATORID: {
      presence: {
        allowEmpty: false,
        message: "Select an operator."
      },
      numericality: {
        onlyInteger: true,
        greaterThan: 0,
        message: "Select an operator."
      }
    },
    DEPARTING_FROM: {
      presence: {
        allowEmpty: false,
        message: "Departure location is required."
      }
    },
    DEPARTURE_TIME: {
      presence: {
        allowEmpty: false,
        message: "Departure date and time are required."
      }
    },
    DEPARTURE_TIMEZONE: {
      presence: {
        allowEmpty: false,
        message: "Departure time zone is required."
      }
    },
    RETURNING_TO: {
      presence: {
        allowEmpty: false,
        message: "Return location is required."
      }
    },
    RETURN_TIME: {
      presence: {
        allowEmpty: false,
        message: "Return date and time are required."
      }
    },
    RETURN_TIMEZONE: {
      presence: {
        allowEmpty: false,
        message: "Return time zone is required."
      }
    },
    EMAIL: {
      presence: {
        allowEmpty: false,
        message: "Email is required."
      },
      email: {
        message: "Enter a valid email address."
      }
    },
    RESCUE_AUTHORITY: {
      presence: {
        allowEmpty: false,
        message: "Rescue authority is required."
      }
    },
    RESCUE_AUTHORITY_PHONE: {
      presence: {
        allowEmpty: false,
        message: "Rescue authority phone is required."
      }
    }
  };

  var REQUIRED_FLOATPLAN_KEYS = [
    "NAME",
    "VESSELID",
    "OPERATORID",
    "DEPARTING_FROM",
    "DEPARTURE_TIME",
    "DEPARTURE_TIMEZONE",
    "RETURNING_TO",
    "RETURN_TIME",
    "RETURN_TIMEZONE",
    "RESCUE_AUTHORITY",
    "RESCUE_AUTHORITY_PHONE"
  ];

  function buildFloatplanConstraints(keys) {
    var result = {};
    keys.forEach(function (key) {
      var rule = FLOATPLAN_VALIDATION_RULES[key];
      if (rule) {
        result[key] = rule;
      }
    });
    return result;
  }

  function isEmptyValue(value) {
    if (value === undefined || value === null) {
      return true;
    }
    if (typeof value === "string") {
      return value.trim().length === 0;
    }
    return false;
  }


  function getPresenceMessageFor(key) {
    var rule = FLOATPLAN_VALIDATION_RULES[key];
    if (rule && rule.presence && rule.presence.message) {
      return rule.presence.message;
    }
    return "This field is required.";
  }

  function getTimeZoneOffset(timeZone, date) {
    if (!timeZone || !date) return 0;
    try {
      var formatter = new Intl.DateTimeFormat("en-US", {
        timeZone: timeZone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
      });
      var parts = formatter.formatToParts(date);
      var values = {};
      for (var i = 0; i < parts.length; i++) {
        var part = parts[i];
        if (part.type !== "literal") {
          values[part.type] = part.value;
        }
      }
      var tzMillis = Date.UTC(
        parseInt(values.year, 10),
        parseInt(values.month, 10) - 1,
        parseInt(values.day, 10),
        parseInt(values.hour, 10),
        parseInt(values.minute, 10),
        parseInt(values.second, 10)
      );
      return tzMillis - date.getTime();
    } catch (err) {
      return 0;
    }
  }

  function parseDateTimeInTimeZone(value, timeZone) {
    if (!value && value !== 0) return null;
    var raw = String(value).trim();
    if (!raw) return null;
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(raw)) {
      raw = raw.replace(" ", "T");
    }
    var match = raw.match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?/);
    if (!match) {
      var parsed = new Date(raw);
      return isNaN(parsed.getTime()) ? null : parsed;
    }
    var year = parseInt(match[1], 10);
    var month = parseInt(match[2], 10) - 1;
    var day = parseInt(match[3], 10);
    var hour = parseInt(match[4] || "0", 10);
    var minute = parseInt(match[5] || "0", 10);
    var second = parseInt(match[6] || "0", 10);
    var utcDate = new Date(Date.UTC(year, month, day, hour, minute, second));
    if (!timeZone) {
      return utcDate;
    }
    var offset = getTimeZoneOffset(timeZone, utcDate);
    return new Date(utcDate.getTime() - offset);
  }

  function toClientUtcIso(value, timeZone) {
    var parsed = parseDateTimeInTimeZone(value, timeZone);
    return parsed && !isNaN(parsed.getTime()) ? parsed.toISOString() : "";
  }

  function applyClientUtcFields(plan) {
    if (!plan) return;
    plan.DEPARTURE_TIME_UTC = toClientUtcIso(plan.DEPARTURE_TIME, plan.DEPARTURE_TIMEZONE);
    plan.RETURN_TIME_UTC = toClientUtcIso(plan.RETURN_TIME, plan.RETURN_TIMEZONE);
  }

  var STEP_VALIDATION_CONSTRAINTS = {
    1: buildFloatplanConstraints(["NAME", "VESSELID", "OPERATORID"]),
    2: buildFloatplanConstraints([
      "DEPARTING_FROM",
      "DEPARTURE_TIME",
      "DEPARTURE_TIMEZONE",
      "RETURNING_TO",
      "RETURN_TIME",
      "RETURN_TIMEZONE"
    ]),
    3: buildFloatplanConstraints([]),
    6: buildFloatplanConstraints(REQUIRED_FLOATPLAN_KEYS)
  };

  function createWizardApp(options) {
    options = options || {};
    var onSaved = options.onSaved;
    var onDeleted = options.onDeleted;
    var initialMemberAccess = options.memberAccess && typeof options.memberAccess === "object"
      ? options.memberAccess
      : {};
    var initialPlanId = numeric(options.planId || 0);
    var contactStep = numeric(options.contactStep || 0);
    var returnSurface = String(options.returnSurface || "standalone_wizard").trim().toLowerCase();
    if (["dashboard_modal", "standalone_wizard"].indexOf(returnSurface) === -1) {
      returnSurface = "standalone_wizard";
    }
    if (!initialPlanId) {
      initialPlanId = getPlanIdFromQuery();
    }
    var totalSteps = numeric(options.totalSteps || 0) || 6;
    var oneTripCheckoutReturn = getOneTripCheckoutReturn();
    if (oneTripCheckoutReturn) {
      clearOneTripCheckoutReturnFromLocation();
    }
    var initialStep = oneTripCheckoutReturn ? totalSteps : numeric(options.startStep || 1);
    if (initialStep < 1) {
      initialStep = 1;
    }
    if (initialStep > totalSteps) {
      initialStep = totalSteps;
    }

    var app = Vue.createApp({
      data: function () {
      return {


        fieldErrors: {

        },


        step: initialStep,
        totalSteps: totalSteps,
        isLoading: true,
        isSaving: false,
        checkoutBusy: false,
        statusMessage: null,
        memberAccess: initialMemberAccess,
        premiumSendReceipt: { found: false },
        timezones: DEFAULT_TIMEZONES.slice(),
        fp: {
          FLOATPLAN: createEmptyFloatPlan(),
          PASSENGERS: [],
          CONTACTS: [],
          WAYPOINTS: []
        },
        vessels: [],
        operators: [],
        passengers: [],
        contacts: [],
        waypoints: [],
        rescueCenters: [],
        homePort: null,
        homePortTimezone: "",
        selectedRescueCenterId: 0,
        NA_RESCUE_CENTER_ID: NA_RESCUE_CENTER_ID,
        rescueCenterSyncing: false,
        pdfPreviewUrl: "",
        pdfPreviewObjectUrl: "",
        pdfPreviewLoading: false,
        pdfPreviewError: "",
        contactStep: contactStep,
        returnSurface: returnSurface,
        initialPlanId: initialPlanId,
        manifestActiveTab: "passengers",
        passengerSearchQuery: "",
        contactSearchQuery: "",
        manifestSummaryOpen: true,
        waypointSearchQuery: "",
        mobileWaypointsSummaryOpen: true,
        routeDefaults: normalizeRouteDefaults({}),
        routeReturnSuggestion: {
          isLoading: false,
          requestId: 0,
          applying: false,
          lastDepartureKey: "",
          lastReturnTime: "",
          lastReturnTimezone: "",
          lastReturnUtc: "",
          manualReturnEdited: false
        }
      };
    },

    computed: {
      premiumSendCreditCount: function () {
        return numeric(memberAccessValue(this.memberAccess, "premiumSendCreditCount", 0));
      },

      hasGeneralPremiumAccess: function () {
        return truthyAccessValue(memberAccessValue(this.memberAccess, "hasGeneralPremium", false))
          || truthyAccessValue(memberAccessValue(this.memberAccess, "hasPremium", false));
      },

      hasCommittedPremiumSend: function () {
        return truthyAccessValue(memberAccessValue(this.premiumSendReceipt, "found", false));
      },

      canSendPremiumFloatPlan: function () {
        return this.hasCommittedPremiumSend
          || truthyAccessValue(memberAccessValue(this.memberAccess, "canSendPremiumFloatPlan", false));
      },

      oneTripCheckoutAvailable: function () {
        return truthyAccessValue(memberAccessValue(this.memberAccess, "oneTripCheckoutAvailable", false));
      },

      premiumSendAvailabilityMessage: function () {
        if (this.hasCommittedPremiumSend) {
          return "Premium Save & Send is already committed for this float plan. Retrying returns the original result without another email or credit.";
        }
        if (this.hasGeneralPremiumAccess) {
          return "Your active Premium membership includes Premium Save & Send. No credit will be consumed.";
        }
        if (this.premiumSendCreditCount > 0) {
          return this.premiumSendCreditCount + " Premium Send Credit" + (this.premiumSendCreditCount === 1 ? "" : "s") + " available.";
        }
        return "Your Draft and planning work are preserved. Premium Save & Send requires one credit or an active membership.";
      },

      currentVesselName: function () {
        return findName(this.vessels, "VESSELID", "VESSELNAME", this.fp.FLOATPLAN.VESSELID) || "(none selected)";
      },

      currentOperatorName: function () {
        return findName(this.operators, "OPERATORID", "OPERATORNAME", this.fp.FLOATPLAN.OPERATORID) || "(none selected)";
      },

      passengerSummary: function () {
        return summarizeSelections(this.fp.PASSENGERS, this.passengers, "PASSENGERID", "PASSENGERNAME");
      },

      contactSummary: function () {
        return summarizeSelections(this.fp.CONTACTS, this.contacts, "CONTACTID", "CONTACTNAME");
      },

      selectedPassengerDetails: function () {
        var details = [];
        var selected = Array.isArray(this.fp.PASSENGERS) ? this.fp.PASSENGERS : [];
        var source = Array.isArray(this.passengers) ? this.passengers : [];
        for (var i = 0; i < selected.length; i++) {
          var selectedId = numeric(selected[i].PASSENGERID);
          if (!selectedId) continue;
          var label = "";
          for (var j = 0; j < source.length; j++) {
            if (numeric(source[j].PASSENGERID) === selectedId) {
              label = (source[j].PASSENGERNAME || "").toString().trim();
              break;
            }
          }
          details.push({
            id: selectedId,
            label: label || ("Passenger #" + selectedId)
          });
        }
        return details;
      },

      selectedContactDetails: function () {
        var details = [];
        var selected = Array.isArray(this.fp.CONTACTS) ? this.fp.CONTACTS : [];
        var source = Array.isArray(this.contacts) ? this.contacts : [];
        for (var i = 0; i < selected.length; i++) {
          var selectedId = numeric(selected[i].CONTACTID);
          if (!selectedId) continue;
          var label = "";
          for (var j = 0; j < source.length; j++) {
            if (numeric(source[j].CONTACTID) === selectedId) {
              label = (source[j].CONTACTNAME || "").toString().trim();
              break;
            }
          }
          details.push({
            id: selectedId,
            label: label || ("Contact #" + selectedId)
          });
        }
        return details;
      },

      filteredPassengers: function () {
        var list = Array.isArray(this.passengers) ? this.passengers : [];
        var query = normalizeSearchQuery(this.passengerSearchQuery);
        if (!query) {
          return list;
        }
        return list.filter(function (entry) {
          var searchable = toSearchableText(entry, [ "PASSENGERNAME", "PHONE", "NOTES", "passengerName", "phone", "notes" ]);
          return searchable.indexOf(query) !== -1;
        });
      },

      filteredContacts: function () {
        var list = Array.isArray(this.contacts) ? this.contacts : [];
        var query = normalizeSearchQuery(this.contactSearchQuery);
        if (!query) {
          return list;
        }
        return list.filter(function (entry) {
          var searchable = toSearchableText(entry, [ "CONTACTNAME", "PHONE", "EMAIL", "contactName", "phone", "email" ]);
          return searchable.indexOf(query) !== -1;
        });
      },

      selectedWaypointDetails: function () {
        var details = [];
        var selected = Array.isArray(this.fp.WAYPOINTS) ? this.fp.WAYPOINTS : [];
        var source = Array.isArray(this.waypoints) ? this.waypoints : [];
        for (var i = 0; i < selected.length; i++) {
          var selectedId = numeric(selected[i].WAYPOINTID);
          if (!selectedId) continue;
          var label = "";
          for (var j = 0; j < source.length; j++) {
            if (numeric(source[j].WAYPOINTID) === selectedId) {
              label = (source[j].WAYPOINTNAME || "").toString().trim();
              break;
            }
          }
          details.push({
            id: selectedId,
            label: label || ("Waypoint #" + selectedId),
            position: details.length + 1
          });
        }
        return details;
      },

      filteredWaypoints: function () {
        var list = Array.isArray(this.waypoints) ? this.waypoints : [];
        var query = normalizeSearchQuery(this.waypointSearchQuery);
        if (!query) {
          return list;
        }
        return list.filter(function (entry) {
          var searchable = toSearchableText(entry, [ "WAYPOINTNAME", "NOTES", "CITY", "STATE", "waypointName", "notes", "city", "state" ]);
          return searchable.indexOf(query) !== -1;
        });
      },

      waypointSummary: function () {
        return summarizeSelections(this.fp.WAYPOINTS, this.waypoints, "WAYPOINTID", "WAYPOINTNAME");
      },
      nextButtonLabel: function () {
        return this.step === this.totalSteps - 1 ? "Review Float Plan" : "Next";
      }
    },

    watch: {
      step: function (nextStep, prevStep) {
        if (nextStep !== prevStep) {
          this.clearStatus();
          if (nextStep === this.totalSteps) {
            this.loadPdfPreview();
          }
        }
      },
      "fp.FLOATPLAN.RESCUE_AUTHORITY": function () {
        this.syncRescueCenterSelection();
      },
      "fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE": function () {
        this.syncRescueCenterSelection();
      },
      "fp.FLOATPLAN.DEPARTURE_TIME": function () {
        this.requestRouteReturnSuggestion();
      },
      "fp.FLOATPLAN.DEPARTURE_TIMEZONE": function () {
        this.requestRouteReturnSuggestion();
      },
      "fp.FLOATPLAN.RETURN_TIME": function (nextValue) {
        this.handleReturnTimeChanged(nextValue);
      }
    },

    created: function () {
      this.loadBootstrap();
    },

    methods: {


      
      validateStep: function (stepNumber) {
        this.clearFieldErrors();

        var payload = this.fp ? this.fp.FLOATPLAN || {} : {};
        var constraints = STEP_VALIDATION_CONSTRAINTS[stepNumber];
        var validator = window.validate;
        var needsContactValidation = stepNumber === this.contactStep;

        // If no validator, allow step
        if ((!constraints || typeof validator !== "function") && !needsContactValidation) {
          return true;
        }

        // Validate.js returns object map when format is "grouped"
        var errors = null;
        if (constraints && typeof validator === "function") {
          errors = validator(payload, constraints, { format: "grouped", fullMessages: false });
        }


        // Custom cross-field rules for step 2 (or final step 6)
        if ((stepNumber === 2 || stepNumber === 6) && payload.DEPARTURE_TIME && payload.RETURN_TIME) {
          var depart = parseDateTimeInTimeZone(payload.DEPARTURE_TIME, payload.DEPARTURE_TIMEZONE);
          var ret = parseDateTimeInTimeZone(payload.RETURN_TIME, payload.RETURN_TIMEZONE);
          var now = new Date();
          if (depart && ret && ret <= depart) {
            if (!errors) errors = {};
            errors.RETURN_TIME = ["Return must be after departure."];
          }
          if (ret && ret < now) {
            if (!errors) errors = {};
            errors.RETURN_TIME = ["Return must be in the future."];
          }
        }

        if (stepNumber === 3 || stepNumber === 6) {
          var rescueSelectedId = numeric(this.selectedRescueCenterId);
          var rescueIsNotApplicable = rescueSelectedId === NA_RESCUE_CENTER_ID;
          var rescueIsValid = rescueSelectedId > 0 || rescueIsNotApplicable;
          if (rescueIsNotApplicable && errors && errors.RESCUE_AUTHORITY_PHONE) {
            delete errors.RESCUE_AUTHORITY_PHONE;
            if (!Object.keys(errors).length) {
              errors = null;
            }
          }
          if (!rescueIsValid) {
            if (!errors) errors = {};
            errors[RESCUE_AUTHORITY_SELECTION_FIELD] = [RESCUE_AUTHORITY_SELECTION_MESSAGE];
          }
        }

        if (needsContactValidation) {
          var contactCount = 0;
          var selectedContacts = (this.fp && Array.isArray(this.fp.CONTACTS)) ? this.fp.CONTACTS : [];
          for (var contactIndex = 0; contactIndex < selectedContacts.length; contactIndex++) {
            if (numeric(selectedContacts[contactIndex].CONTACTID) > 0) {
              contactCount++;
            }
          }
          if (contactCount <= 0) {
            if (!errors) errors = {};
            errors.CONTACTS = ["Select at least one contact."];
          }
        }

        if (!errors) {
          this.clearStatus(); // keep your existing status alert behavior optional
          return true;
        }

        // Push each field’s first message into fieldErrors
        var keys = Object.keys(errors);
        for (var i = 0; i < keys.length; i++) {
          var field = keys[i];
          var msgArr = errors[field];
          var msg = (Array.isArray(msgArr) && msgArr.length) ? msgArr[0] : "Invalid value.";
          this.setFieldError(field, msg);
        }

        this.clearStatus();
        this.$nextTick(this.focusFirstError);
        return false;
      },

      validateStepsThrough: function (targetStep) {
        var lastStep = Math.min(numeric(targetStep), this.totalSteps);
        for (var stepNumber = 1; stepNumber <= lastStep; stepNumber++) {
          if (!this.validateStep(stepNumber)) {
            if (this.step !== stepNumber) {
              this.step = stepNumber;
            }
            this.$nextTick(this.focusFirstError);
            return false;
          }
        }
        return true;
      },

      clearFieldError: function (field) {
        if (this.fieldErrors && this.fieldErrors[field]) {
          delete this.fieldErrors[field];
        }
      },

      applyHomePortDefaults: function () {
        if (!this.homePort || !this.homePort.isHomePort) {
          return;
        }
        var plan = this.fp && this.fp.FLOATPLAN ? this.fp.FLOATPLAN : {};
        if (isEmptyValue(plan.DEPARTING_FROM)) {
          plan.DEPARTING_FROM = "Home Port";
        }
        if (isEmptyValue(plan.RETURNING_TO)) {
          plan.RETURNING_TO = "Home Port";
        }
        var timezone = this.homePortTimezone || getTimezoneForState(this.homePort.state);
        if (timezone && isEmptyValue(plan.DEPARTURE_TIMEZONE)) {
          plan.DEPARTURE_TIMEZONE = timezone;
        }
        if (timezone && isEmptyValue(plan.RETURN_TIMEZONE)) {
          plan.RETURN_TIMEZONE = timezone;
        }
      },

      isFromRoutePlan: function () {
        if (this.routeDefaults && this.routeDefaults.IS_FROM_ROUTE) {
          return true;
        }
        return numeric(this.fp && this.fp.FLOATPLAN ? this.fp.FLOATPLAN.ROUTE_INSTANCE_ID : 0) > 0;
      },

      applyRouteDefaults: function () {
        if (!this.isFromRoutePlan()) {
          return;
        }
        var plan = this.fp && this.fp.FLOATPLAN ? this.fp.FLOATPLAN : {};
        var defaults = this.routeDefaults || {};
        var chosenOperatorId = numeric(defaults.OPERATOR_ID);
        if (numeric(plan.OPERATORID) <= 0) {
          if (chosenOperatorId <= 0 && Array.isArray(this.operators) && this.operators.length) {
            chosenOperatorId = numeric(this.operators[0].OPERATORID);
            if (chosenOperatorId > 0) {
              defaults.OPERATOR_SOURCE = "first_available";
            }
          }
          if (chosenOperatorId > 0) {
            plan.OPERATORID = chosenOperatorId;
          }
        }

        if (isEmptyValue(plan.DEPARTING_FROM) && defaults.DEPARTING_FROM_DEFAULT) {
          plan.DEPARTING_FROM = defaults.DEPARTING_FROM_DEFAULT;
        }
        if (isEmptyValue(plan.RETURNING_TO) && defaults.RETURNING_TO_DEFAULT) {
          plan.RETURNING_TO = defaults.RETURNING_TO_DEFAULT;
        }
        if (isEmptyValue(plan.DEPARTURE_TIMEZONE)) {
          plan.DEPARTURE_TIMEZONE = this.homePortTimezone || "";
        }
        if (isEmptyValue(plan.RETURN_TIMEZONE)) {
          plan.RETURN_TIMEZONE = this.homePortTimezone || "";
        }

        if ((!Array.isArray(this.fp.WAYPOINTS) || !this.fp.WAYPOINTS.length) && Array.isArray(defaults.WAYPOINT_SELECTIONS) && defaults.WAYPOINT_SELECTIONS.length) {
          this.fp.WAYPOINTS = sortByOrder(
            defaults.WAYPOINT_SELECTIONS
              .map(normalizeWaypointSelection)
              .filter(function (item) { return !!item; }),
            "SORT_ORDER"
          );
        }
      },

      handleReturnTimeChanged: function (nextValue) {
        var state = this.routeReturnSuggestion;
        if (!state || state.applying) {
          return;
        }
        var normalizedValue = toDateTimeLocal(nextValue);
        if (!normalizedValue) {
          state.manualReturnEdited = false;
          state.lastReturnTime = "";
          state.lastReturnTimezone = "";
          state.lastReturnUtc = "";
          this.requestRouteReturnSuggestion();
          return;
        }
        if (state.lastReturnTime && normalizedValue === state.lastReturnTime) {
          return;
        }
        state.manualReturnEdited = true;
      },

      handleDepartureTimingChanged: function (field) {
        this.clearFieldError(field);
        this.$nextTick(this.requestRouteReturnSuggestion);
      },

      handleReturnTimeInput: function () {
        var self = this;
        this.clearFieldError("RETURN_TIME");
        this.$nextTick(function () {
          self.handleReturnTimeChanged(self.fp.FLOATPLAN.RETURN_TIME);
        });
      },

      requestRouteReturnSuggestion: function () {
        var state = this.routeReturnSuggestion;
        var plan = this.fp && this.fp.FLOATPLAN ? this.fp.FLOATPLAN : {};
        if (!state || this.isLoading || !this.isFromRoutePlan()) {
          return;
        }
        if (!window.Api || typeof window.Api.suggestFloatPlanReturnTime !== "function") {
          return;
        }

        var planId = numeric(plan.FLOATPLANID || this.initialPlanId);
        var departureTime = toDateTimeLocal(plan.DEPARTURE_TIME);
        var departureTimezone = (plan.DEPARTURE_TIMEZONE || "").toString().trim();
        if (!(planId > 0) || !departureTime || !departureTimezone) {
          return;
        }

        var currentReturnTime = toDateTimeLocal(plan.RETURN_TIME);
        if (currentReturnTime && (!state.lastReturnTime || currentReturnTime !== state.lastReturnTime)) {
          return;
        }
        if (state.manualReturnEdited && currentReturnTime !== state.lastReturnTime) {
          return;
        }

        var departureKey = [planId, departureTime, departureTimezone].join("|");
        state.requestId += 1;
        var requestId = state.requestId;
        state.lastDepartureKey = departureKey;
        state.isLoading = true;

        window.Api.suggestFloatPlanReturnTime({
          floatPlanId: planId,
          DEPARTURE_TIME: departureTime,
          DEPARTURE_TIMEZONE: departureTimezone
        })
          .then(function (data) {
            if (requestId !== state.requestId) {
              return;
            }
            var suggestedReturnTime = toDateTimeLocal(data && data.SUGGESTED_RETURN_TIME);
            if (!suggestedReturnTime) {
              return;
            }
            var latestReturnTime = toDateTimeLocal(plan.RETURN_TIME);
            if (latestReturnTime && (!state.lastReturnTime || latestReturnTime !== state.lastReturnTime)) {
              return;
            }
            if (state.manualReturnEdited && latestReturnTime !== state.lastReturnTime) {
              return;
            }

            var suggestedTimezone = (data.SUGGESTED_RETURN_TIMEZONE || departureTimezone || "").toString().trim();
            state.applying = true;
            try {
              plan.RETURN_TIME = suggestedReturnTime;
              if (suggestedTimezone && (isEmptyValue(plan.RETURN_TIMEZONE) || plan.RETURN_TIMEZONE === state.lastReturnTimezone)) {
                plan.RETURN_TIMEZONE = suggestedTimezone;
              }
              state.lastReturnTime = suggestedReturnTime;
              state.lastReturnTimezone = suggestedTimezone;
              state.lastReturnUtc = (data.SUGGESTED_RETURN_TIME_UTC || "").toString();
              state.manualReturnEdited = false;
            } finally {
              state.applying = false;
            }
          })
          .catch(function () {
            // Return-time suggestions are optional; existing validation still requires explicit timing before save/send.
          })
          .finally(function () {
            if (requestId === state.requestId) {
              state.isLoading = false;
            }
          });
      },

      nextStep: function () {
        if (this.step >= this.totalSteps) {
          return;
        }
        if (!this.validateStep(this.step)) {
          return;
        }
        this.step += 1;
        this.clearStatus();
      },

      prevStep: function () {
        if (this.step > 1) {
          this.step -= 1;
          this.clearStatus();
        }
      },

      setStatus: function (message, ok) {
        if (!message) {
          this.statusMessage = null;
          return;
        }
        this.statusMessage = {
          ok: ok !== false,
          message: message
        };
      },

      clearStatus: function () {
        this.statusMessage = null;
      },

      handleError: function (err, fallback) {
        var message = fallback || "Unexpected error.";
        if (err) {
          if (typeof err === "string") {
            message = err;
          } else if (err.MESSAGE) {
            message = err.MESSAGE;
          } else if (err.message) {
            message = err.message;
          }
        }
        console.error("Float plan wizard error", err);
        this.setStatus(message, false);
      },

      handleRescueCenterSelection: function (event) {
        if (this.rescueCenterSyncing) {
          return;
        }
        this.rescueCenterSyncing = true;
        var selectedRaw = (
          event && event.target && event.target.value !== undefined
            ? event.target.value
            : this.selectedRescueCenterId
        );
        var selectedId = numeric(
          selectedRaw
        );
        this.selectedRescueCenterId = selectedId;
        this.fp.FLOATPLAN.RESCUE_CENTERID = selectedId;
        var match = null;
        for (var i = 0; i < this.rescueCenters.length; i++) {
          if (numeric(this.rescueCenters[i].recId) === selectedId) {
            match = this.rescueCenters[i];
            break;
          }
        }

        if (selectedId === NA_RESCUE_CENTER_ID) {
          this.fp.FLOATPLAN.RESCUE_AUTHORITY = NA_RESCUE_AUTHORITY_LABEL;
          this.fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE = NA_RESCUE_AUTHORITY_PHONE;
        } else if (match) {
          this.fp.FLOATPLAN.RESCUE_AUTHORITY = match.rcName || "";
          this.fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE = match.rcPhone || "";
        } else {
          this.fp.FLOATPLAN.RESCUE_AUTHORITY = "";
          this.fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE = "";
        }

        this.rescueCenterSyncing = false;
        this.syncRescueCenterSelection();
        this.clearFieldError(RESCUE_AUTHORITY_SELECTION_FIELD);
      },

      formatRescueCenterLabel: function (center) {
        if (!center) {
          return "";
        }
        var name = (center.rcName || "").trim();
        if (!name) {
          name = center.rcDistrict || center.rcArea || "";
        }
        if (!name) {
          name = "Rescue Center #" + numeric(center.recId);
        }
        var location = (center.rcLocation || "").trim();
        return location ? name + " — " + location : name;
      },

      syncRescueCenterSelection: function () {
        if (this.rescueCenterSyncing) {
          return;
        }
        this.rescueCenterSyncing = true;
        var authority = (this.fp.FLOATPLAN.RESCUE_AUTHORITY || "").trim();
        var phone = (this.fp.FLOATPLAN.RESCUE_AUTHORITY_PHONE || "").trim();
        var storedCenterId = numeric(this.fp.FLOATPLAN.RESCUE_CENTERID);
        var matchId = 0;

        if (
          storedCenterId === NA_RESCUE_CENTER_ID ||
          (authority === NA_RESCUE_AUTHORITY_LABEL && phone === NA_RESCUE_AUTHORITY_PHONE)
        ) {
          matchId = NA_RESCUE_CENTER_ID;
        } else if (storedCenterId !== 0) {
          for (var j = 0; j < this.rescueCenters.length; j++) {
            if (numeric(this.rescueCenters[j].recId) === storedCenterId) {
              matchId = storedCenterId;
              break;
            }
          }
        }

        if (!matchId && authority && phone) {
          var normalizedName = authority.toLowerCase();
          var normalizedPhone = phone;
          for (var k = 0; k < this.rescueCenters.length; k++) {
            var center = this.rescueCenters[k];
            if (
              center &&
              center.rcName &&
              center.rcPhone &&
              String(center.rcName).toLowerCase().trim() === normalizedName &&
              String(center.rcPhone).trim() === normalizedPhone
            ) {
              matchId = numeric(center.recId);
              break;
            }
          }
        }

        this.selectedRescueCenterId = matchId;
        this.fp.FLOATPLAN.RESCUE_CENTERID = matchId;
        if (matchId > 0 || matchId === NA_RESCUE_CENTER_ID) {
          this.clearFieldError(RESCUE_AUTHORITY_SELECTION_FIELD);
        }
        this.rescueCenterSyncing = false;
      },

      getPlanId: function () {
        return numeric(this.fp.FLOATPLAN.FLOATPLANID || this.initialPlanId);
      },

      loadPdfPreview: function () {
        var self = this;
        var planId = this.getPlanId();
        var previewRequestUrl = buildPdfPreviewUrl(planId);
        this.pdfPreviewError = "";

        if (!planId || !previewRequestUrl) {
          this.releasePdfPreviewObjectUrl();
          this.pdfPreviewUrl = "";
          this.pdfPreviewLoading = false;
          this.pdfPreviewError = "Save this float plan to generate a PDF preview.";
          return;
        }

        this.releasePdfPreviewObjectUrl();
        this.pdfPreviewUrl = "";
        this.pdfPreviewLoading = true;

        fetch(previewRequestUrl, {
          method: "GET",
          credentials: "include",
          headers: {
            Accept: "application/pdf"
          }
        })
          .then(function (response) {
            var contentType = String(response.headers.get("content-type") || "").toLowerCase();
            if (!response.ok || contentType.indexOf("application/pdf") === -1) {
              return response.text().then(function (bodyText) {
                var message = "Unable to generate PDF preview.";
                try {
                  var errorBody = JSON.parse(bodyText || "{}");
                  if (errorBody && errorBody.MESSAGE) {
                    message = errorBody.MESSAGE;
                  }
                } catch (parseError) {
                  // Preserve the generic message for non-JSON failures.
                }
                throw { MESSAGE: message, status: response.status || 500 };
              });
            }
            return response.blob();
          })
          .then(function (pdfBlob) {
            self.pdfPreviewObjectUrl = window.URL.createObjectURL(pdfBlob);
            self.pdfPreviewUrl = self.pdfPreviewObjectUrl;
            self.pdfPreviewLoading = false;
          })
          .catch(function (err) {
            self.pdfPreviewLoading = false;
            self.releasePdfPreviewObjectUrl();
            self.pdfPreviewUrl = "";
            self.pdfPreviewError = (err && err.MESSAGE) ? err.MESSAGE : "Unable to generate PDF preview.";
          });
      },

      releasePdfPreviewObjectUrl: function () {
        if (this.pdfPreviewObjectUrl && window.URL && typeof window.URL.revokeObjectURL === "function") {
          window.URL.revokeObjectURL(this.pdfPreviewObjectUrl);
        }
        this.pdfPreviewObjectUrl = "";
      },

      isPassengerSelected: function (id) {
        var target = numeric(id);
        return this.fp.PASSENGERS.some(function (item) {
          return numeric(item.PASSENGERID) === target;
        });
      },

      togglePassenger: function (passenger) {
        var id = passenger ? numeric(passenger.PASSENGERID) : 0;
        if (!id) return;
        for (var i = 0; i < this.fp.PASSENGERS.length; i++) {
          if (numeric(this.fp.PASSENGERS[i].PASSENGERID) === id) {
            this.fp.PASSENGERS.splice(i, 1);
            return;
          }
        }
        this.fp.PASSENGERS.push({
          PASSENGERID: id,
          HAS_PFD: passenger.HAS_PFD !== undefined ? !!passenger.HAS_PFD : true,
          SORT_ORDER: this.fp.PASSENGERS.length + 1
        });
      },

      isContactSelected: function (id) {
        var target = numeric(id);
        if (target <= 0) return false;
        return this.fp.CONTACTS.some(function (item) {
          return numeric(item.CONTACTID) === target;
        });
      },

      toggleContact: function (contact) {
        var id = contact ? numeric(contact.CONTACTID) : 0;
        if (id <= 0) return;
        for (var i = 0; i < this.fp.CONTACTS.length; i++) {
          if (numeric(this.fp.CONTACTS[i].CONTACTID) === id) {
            this.fp.CONTACTS.splice(i, 1);
            this.clearFieldError("CONTACTS");
            return;
          }
        }
        this.fp.CONTACTS.push({
          CONTACTID: id,
          SORT_ORDER: this.fp.CONTACTS.length + 1
        });
        this.clearFieldError("CONTACTS");
      },

      isWaypointSelected: function (id) {
        var target = numeric(id);
        return this.fp.WAYPOINTS.some(function (item) {
          return numeric(item.WAYPOINTID) === target;
        });
      },

      toggleWaypoint: function (waypoint) {
        var id = waypoint ? numeric(waypoint.WAYPOINTID) : 0;
        if (!id) return;
        for (var i = 0; i < this.fp.WAYPOINTS.length; i++) {
          if (numeric(this.fp.WAYPOINTS[i].WAYPOINTID) === id) {
            this.fp.WAYPOINTS.splice(i, 1);
            return;
          }
        }
        this.fp.WAYPOINTS.push({
          WAYPOINTID: id,
          SORT_ORDER: this.fp.WAYPOINTS.length + 1,
          REASON_FOR_STOP: "",
          DEPART_MODE: "",
          ARRIVAL_TIME: "",
          DEPARTURE_TIME: ""
        });
      },

      loadBootstrap: function () {
        var self = this;
        if (!window.Api || typeof window.Api.getFloatPlanBootstrap !== "function") {
          this.isLoading = false;
          this.handleError("API helper not available.", "Unable to load float plan.");
          return;
        }

        this.isLoading = true;
        var planId = this.initialPlanId;
        if (!(planId > 0)) {
          this.isLoading = false;
          this.handleError("New float plans must be created from a route.", "Unable to load float plan.");
          return;
        }
        var request = window.Api.getFloatPlanBootstrap(planId);

        request
          .then(function (data) {
            self.vessels = toArray(data.VESSELS);
            self.operators = toArray(data.OPERATORS);
            self.passengers = toArray(data.PASSENGERS);
            self.contacts = toArray(data.CONTACTS);
            self.waypoints = toArray(data.WAYPOINTS);
            self.rescueCenters = toArray(data.RESCUE_CENTERS).map(function (center) {
              return normalizeRescueCenter(center);
            });
            self.routeDefaults = normalizeRouteDefaults(data.ROUTE_DEFAULTS || {});
            self.memberAccess = data.MEMBER_ACCESS || data.memberAccess || self.memberAccess || {};
            self.premiumSendReceipt = data.PREMIUM_SEND_RECEIPT || data.premiumSendReceipt || { found: false };

            self.fp.FLOATPLAN = normalizeFloatPlan(data.FLOATPLAN);
            self.fp.PASSENGERS = sortByOrder(
              toArray(data.PLAN_PASSENGERS)
                .map(normalizePassengerSelection)
                .filter(function (item) { return !!item; }),
              "SORT_ORDER"
            );

            self.fp.CONTACTS = sortByOrder(
              toArray(data.PLAN_CONTACTS)
                .map(normalizeContactSelection)
                .filter(function (item) { return !!item; }),
              "SORT_ORDER"
            );

            self.fp.WAYPOINTS = sortByOrder(
              toArray(data.PLAN_WAYPOINTS)
                .map(normalizeWaypointSelection)
                .filter(function (item) { return !!item; }),
              "SORT_ORDER"
            );

            self.homePort = normalizeHomePort(data.HOME_PORT || data.HOMEPORT || data.homePort || {});
            self.homePortTimezone = getTimezoneForState(self.homePort ? self.homePort.state : "");
            self.applyHomePortDefaults();
            self.applyRouteDefaults();
            self.syncRescueCenterSelection();

            self.initialPlanId = numeric(self.fp.FLOATPLAN.FLOATPLANID) || self.initialPlanId;
            self.isLoading = false;
            self.clearStatus();
            if (oneTripCheckoutReturn === "success") {
              self.setStatus("Checkout completed. Your Premium Send Credit is available; this Draft has not been sent.", true);
            } else if (oneTripCheckoutReturn === "cancel") {
              self.setStatus("Checkout was canceled. Your Draft is saved and has not been sent.", false);
            }
            self.requestRouteReturnSuggestion();
            if (self.step === self.totalSteps) {
              self.loadPdfPreview();
            }
          })
          .catch(function (err) {
            self.isLoading = false;
            self.handleError(err, "Unable to load float plan.");
          });
      },

      clearFieldErrors: function () {
        this.fieldErrors = {};
      },

      setFieldError: function (field, message) {
        if (!field) return;
        if (!this.fieldErrors) this.fieldErrors = {};
        this.fieldErrors[field] = message || "Invalid value.";
      },

      hasError: function (field) {
        return !!(this.fieldErrors && this.fieldErrors[field]);
      },

      getError: function (field) {
        return (this.fieldErrors && this.fieldErrors[field]) ? this.fieldErrors[field] : "";
      },

      focusFirstError: function () {
        var keys = this.fieldErrors ? Object.keys(this.fieldErrors) : [];
        if (!keys.length) return;

        // Focus by name attr first (preferred)
        var first = keys[0];
        var el = document.querySelector('[name="' + first + '"]');
        if (el && typeof el.focus === "function") {
          el.focus();
        }
      }
      ,
      applySaveResponse: function (response) {
        var savedWaypoints = sortByOrder(
          toArray(response.PLAN_WAYPOINTS)
            .map(normalizeWaypointSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        var savedContacts = sortByOrder(
          toArray(response.PLAN_CONTACTS)
            .map(normalizeContactSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        this.fp.FLOATPLAN = normalizeFloatPlan(response.FLOATPLAN || response);
        this.syncRescueCenterSelection();
        this.fp.PASSENGERS = sortByOrder(
          toArray(response.PLAN_PASSENGERS)
            .map(normalizePassengerSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        this.fp.CONTACTS = savedContacts;
        this.fp.WAYPOINTS = savedWaypoints;
        if (
          !this.fp.WAYPOINTS.length
          && this.isFromRoutePlan()
          && this.routeDefaults
          && Array.isArray(this.routeDefaults.WAYPOINT_SELECTIONS)
          && this.routeDefaults.WAYPOINT_SELECTIONS.length
        ) {
          this.fp.WAYPOINTS = sortByOrder(
            this.routeDefaults.WAYPOINT_SELECTIONS
              .map(normalizeWaypointSelection)
              .filter(function (item) { return !!item; }),
            "SORT_ORDER"
          );
        }
        this.initialPlanId = numeric(this.fp.FLOATPLAN.FLOATPLANID) || this.initialPlanId;
      },

      submitPlan: function () {
        var self = this;
        if (!window.Api || typeof window.Api.saveFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to save float plan.");
          return;
        }

        if (!this.validateStepsThrough(this.step)) {
          return;
        }
        applyClientUtcFields(this.fp.FLOATPLAN);

        this.isSaving = true;
        this.setStatus("Saving your float plan…", true);

        window.Api.saveFloatPlan({
          FLOATPLAN: this.fp.FLOATPLAN,
          PASSENGERS: this.fp.PASSENGERS,
          CONTACTS: this.fp.CONTACTS,
          WAYPOINTS: this.fp.WAYPOINTS
        })
        .then(function (response) {
          self.applySaveResponse(response);
          self.setStatus("Float plan saved successfully.", true);
          self.isSaving = false;
          if (self.step === self.totalSteps) {
            self.loadPdfPreview();
          }
          if (typeof onSaved === "function") {
            onSaved(response, self);
          }
        })
        .catch(function (err) {
          self.isSaving = false;
          self.handleError(err, "Unable to save float plan.");
        });
      },

      startPremiumCheckout: function (priceSelector) {
        var self = this;
        var selector = String(priceSelector || "").trim().toLowerCase();
        if (this.checkoutBusy) {
          return;
        }
        if (["one_trip", "monthly", "yearly"].indexOf(selector) === -1) {
          this.setStatus("Choose Buy One Trip, Monthly Membership, or Annual Membership.", false);
          return;
        }
        if (selector === "one_trip" && !this.oneTripCheckoutAvailable) {
          this.setStatus("Buy One Trip is not configured right now. Your Draft remains saved; Monthly and Annual remain available.", false);
          return;
        }
        if (!window.Api || typeof window.Api.createPremiumCheckoutSession !== "function") {
          this.setStatus("Premium checkout is not available right now.", false);
          return;
        }

        if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
          window.FPWAnalytics.track(
            selector === "one_trip" ? "buy_one_trip_clicked" : (selector === "monthly" ? "monthly_selected" : "annual_selected"),
            { source: "premium_send_review" }
          );
        }
        this.checkoutBusy = true;
        this.setStatus("Opening secure Stripe Checkout...", true);
        window.Api.createPremiumCheckoutSession(
          selector,
          selector === "one_trip" ? this.getPlanId() : 0,
          selector === "one_trip" ? this.returnSurface : ""
        )
          .then(function (response) {
            var checkoutUrl = response && (response.checkoutUrl || response.CHECKOUT_URL)
              ? String(response.checkoutUrl || response.CHECKOUT_URL)
              : "";
            if (!checkoutUrl) {
              throw response || { MESSAGE: "Premium checkout is not available right now." };
            }
            if (window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
              window.FPWAnalytics.track("begin_checkout", {
                checkout_type: selector,
                source: "premium_send_review"
              });
            }
            window.location.href = checkoutUrl;
          })
          .catch(function (err) {
            self.checkoutBusy = false;
            self.handleError(err, "Premium checkout is not available right now.");
          });
      },

      submitPlanAndSend: function () {
        var self = this;
        var wasCommitted = this.hasCommittedPremiumSend;
        var sendPromise = null;

        if (!window.Api || typeof window.Api.sendFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to send float plan.");
          return;
        }
        if (!this.canSendPremiumFloatPlan) {
          this.setStatus("Premium Save & Send requires one Premium Send Credit or an active monthly or annual membership.", false);
          return;
        }

        if (wasCommitted) {
          this.isSaving = true;
          this.setStatus("Loading the original committed Premium send result...", true);
          sendPromise = Promise.resolve();
        } else {
          if (!window.Api || typeof window.Api.saveFloatPlan !== "function") {
            this.handleError("API helper not available.", "Unable to save float plan.");
            return;
          }
          if (!this.validateStepsThrough(this.totalSteps)) {
            return;
          }
          if (!this.fp || !Array.isArray(this.fp.CONTACTS) || this.fp.CONTACTS.length === 0) {
            this.setStatus("Select at least one contact to send this float plan.", false);
            return;
          }
          applyClientUtcFields(this.fp.FLOATPLAN);
          this.isSaving = true;
          this.setStatus("Saving and sending your float plan...", true);
          sendPromise = window.Api.saveFloatPlan({
            FLOATPLAN: this.fp.FLOATPLAN,
            PASSENGERS: this.fp.PASSENGERS,
            CONTACTS: this.fp.CONTACTS,
            WAYPOINTS: this.fp.WAYPOINTS
          }).then(function (response) {
            self.applySaveResponse(response);
          });
        }

        sendPromise
          .then(function () {
            return window.Api.sendFloatPlan(self.getPlanId());
          })
          .then(function (response) {
            self.premiumSendReceipt = {
              found: true,
              originalResponse: response || {}
            };
            if (!wasCommitted && self.fp && self.fp.FLOATPLAN) {
              self.fp.FLOATPLAN.STATUS = "ACTIVE";
            }
            self.setStatus(response && response.MESSAGE ? response.MESSAGE : "Float plan sent to selected contacts.", true);
            self.isSaving = false;
            if (!wasCommitted && window.FPWAnalytics && typeof window.FPWAnalytics.track === "function") {
              window.FPWAnalytics.track("active_cruise_started", {
                plan_type: "premium_route",
                source: "float_plan_wizard"
              });
            }
            if (self.step === self.totalSteps) {
              self.loadPdfPreview();
            }
            if (typeof onSaved === "function") {
              onSaved(response, self);
            }
          })
          .catch(function (err) {
            self.isSaving = false;
            self.handleError(err, "Unable to save and send float plan.");
          });
      },

      confirmDelete: function () {
        var planId = this.getPlanId();
        if (planId <= 0) {
          return;
        }
        if (this.isFromRoutePlan()) {
          if (window.FPW && window.FPW.DashboardUtils && window.FPW.DashboardUtils.showAlertModal) {
            window.FPW.DashboardUtils.showAlertModal("Delete the parent route to remove a route-linked float plan.");
          } else {
            window.alert("Delete the parent route to remove a route-linked float plan.");
          }
          return;
        }
        var statusVal = "";
        if (this.fp && this.fp.FLOATPLAN && this.fp.FLOATPLAN.STATUS !== undefined) {
          statusVal = String(this.fp.FLOATPLAN.STATUS || "").trim().toUpperCase();
        }
        if (this.step === this.totalSteps && statusVal.length && statusVal !== "DRAFT" && statusVal !== "CLOSED") {
          if (window.FPW && window.FPW.DashboardUtils && window.FPW.DashboardUtils.showAlertModal) {
            window.FPW.DashboardUtils.showAlertModal("Only draft or closed float plans can be deleted.");
          } else {
            window.alert("Only draft or closed float plans can be deleted.");
          }
          return;
        }
        var confirmMessage = "Delete this float plan? This cannot be undone.";
        if (window.FPW && window.FPW.DashboardUtils && window.FPW.DashboardUtils.showConfirmModal) {
          window.FPW.DashboardUtils.showConfirmModal(confirmMessage)
            .then(function (confirmed) {
              if (!confirmed) return;
              this.deletePlan(planId);
            }.bind(this));
          return;
        }
        if (!window.confirm(confirmMessage)) {
          return;
        }
        this.deletePlan(planId);
      },

      deletePlan: function (planId) {
        var self = this;
        if (!window.Api || typeof window.Api.deleteFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to delete float plan.");
          return;
        }
        this.isSaving = true;
        this.setStatus("Deleting float plan…", true);

          window.Api.deleteFloatPlan(planId)
          .then(function () {
            self.isSaving = false;
            self.setStatus("Float plan deleted.", true);
            if (typeof onDeleted === "function") {
              onDeleted(planId, self);
            } else {
              window.setTimeout(function () {
                window.location.href = BASE_PATH + "/app/dashboard.cfm";
              }, 600);
            }
          })
          .catch(function (err) {
            self.isSaving = false;
            if (window.FPW && window.FPW.DashboardUtils && window.FPW.DashboardUtils.showAlertModal) {
              window.FPW.DashboardUtils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to delete float plan.");
            } else {
              window.alert((err && err.MESSAGE) ? err.MESSAGE : "Unable to delete float plan.");
            }
          });
      }
    },

    beforeUnmount: function () {
      this.releasePdfPreviewObjectUrl();
    },

    watch: {
      isSaving: function (value) {
        setCloseDisabled(!!value);
      }
    }
  });
    return app;
  }

  function setCloseDisabled(disabled) {
    var modal = document.getElementById("floatPlanWizardModal");
    if (!modal) {
      return;
    }
    var closeButton = modal.querySelector(".btn-close");
    if (!closeButton) {
      return;
    }
    closeButton.disabled = disabled;
    closeButton.setAttribute("aria-disabled", disabled ? "true" : "false");
  }

  function initWizard(options) {
    if (!Vue) {
      console.error("Vue is required for the float plan wizard.");
      return null;
    }

    options = options || {};
    var mountEl = options.mountEl || document.getElementById("wizardApp");
    if (!mountEl) {
      return null;
    }
    if (options.contactStep == null && mountEl.dataset && mountEl.dataset.contactStep) {
      options.contactStep = mountEl.dataset.contactStep;
    }
    if (options.totalSteps == null && mountEl.dataset && mountEl.dataset.totalSteps) {
      options.totalSteps = mountEl.dataset.totalSteps;
    }

    destroyWizard();
    wizardMountEl = mountEl;
    if (!wizardTemplateHtml) {
      wizardTemplateHtml = mountEl.innerHTML;
    }
    wizardApp = createWizardApp(options);
    wizardAppInstance = wizardApp.mount(mountEl);
    if (wizardAppInstance && options.startStep != null) {
      var startStep = numeric(options.startStep);
      if (startStep > 0) {
        var maxSteps = numeric(wizardAppInstance.totalSteps) || 6;
        if (startStep > maxSteps) {
          startStep = maxSteps;
        }
        wizardAppInstance.step = startStep;
      }
    }
    return wizardAppInstance;
  }

  function destroyWizard() {
    if (wizardApp) {
      wizardApp.unmount();
    }
    if (wizardMountEl && wizardTemplateHtml) {
      wizardMountEl.innerHTML = wizardTemplateHtml;
    }
    setCloseDisabled(false);
    wizardApp = null;
    wizardAppInstance = null;
    wizardMountEl = null;
  }

  window.FloatPlanWizard = window.FloatPlanWizard || {};
  Object.assign(window.FloatPlanWizard, {
    init: initWizard,
    destroy: destroyWizard
  });

  var autoMountEl = document.getElementById("wizardApp");
  if (autoMountEl && autoMountEl.getAttribute("data-init") !== "manual") {
    initWizard({ mountEl: autoMountEl });
  }
})(window, document, window.Vue);
