// Updated to support modal-driven init/destroy for the float plan wizard.
// /fpw/assets/js/app/floatplanWizard.js
(function (window, document, Vue) {
  "use strict";

  var BASE_PATH = window.FPW_BASE || "";

  if (!Vue) {
    console.error("Vue is required for the float plan wizard.");
  }

  var wizardApp = null;
  var wizardAppInstance = null;
  var wizardMountEl = null;
  var wizardTemplateHtml = "";

  var DEFAULT_TIMEZONES = [
    "UTC",
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

  function getAppPrefix() {
    var firstSegment = (window.location.pathname.split("/")[1] || "");
    return firstSegment ? "/" + firstSegment : "";
  }

  function buildPdfPreviewUrl(fileName, cacheBust) {
    if (!fileName) {
      return "";
    }
    var url = getAppPrefix() + "/api/api_assets/floatPlans/user_float_plans/" + encodeURIComponent(fileName);
    if (cacheBust) {
      url += (url.indexOf("?") === -1 ? "?" : "&") + "t=" + encodeURIComponent(cacheBust);
    }
    return url;
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
      RETURNING_TO: "",
      RETURN_TIME: "",
      RETURN_TIMEZONE: "",
      FOOD_DAYS_PER_PERSON: "",
      WATER_DAYS_PER_PERSON: "",
      NOTES: "",
      DO_NOT_SEND: false,
      STATUS: "Draft"
    };
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
    if (!id) return null;
    return {
      PASSENGERID: id,
      HAS_PFD: entry.HAS_PFD !== undefined ? !!entry.HAS_PFD : true,
      SORT_ORDER: numeric(entry.SORT_ORDER || entry.sortOrder)
    };
  }

  function normalizeContactSelection(entry) {
    if (!entry) return null;
    var id = numeric(entry.CONTACTID || entry.contactId);
    if (!id) return null;
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

  var RESCUE_AUTHORITY_SELECTION_FIELD = "RESCUE_AUTHORITY_SELECTION";
  var RESCUE_AUTHORITY_SELECTION_MESSAGE = "Select a rescue authority.";

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
    var initialPlanId = numeric(options.planId || 0);
    var contactStep = numeric(options.contactStep || 0);
    if (!initialPlanId) {
      initialPlanId = getPlanIdFromQuery();
    }
    var totalSteps = 6;
    var initialStep = numeric(options.startStep || 1);
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
        statusMessage: null,
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
        rescueCenterSyncing: false,
        pdfPreviewUrl: "",
        pdfPreviewLoading: false,
        pdfPreviewError: "",
        contactStep: contactStep,
        initialPlanId: initialPlanId
      };
    },

    computed: {
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


        // Custom cross-field rule (return after departure) for step 2 (or final step 6)
        if ((stepNumber === 2 || stepNumber === 6) && payload.DEPARTURE_TIME && payload.RETURN_TIME) {
          var depart = new Date(payload.DEPARTURE_TIME);
          var ret = new Date(payload.RETURN_TIME);
          if (!isNaN(depart.getTime()) && !isNaN(ret.getTime()) && ret <= depart) {
            if (!errors) errors = {};
            errors.RETURN_TIME = ["Return must be after departure."];
          }
        }

        if ((stepNumber === 3 || stepNumber === 6) && numeric(this.selectedRescueCenterId) <= 0) {
          if (!errors) errors = {};
          errors[RESCUE_AUTHORITY_SELECTION_FIELD] = [RESCUE_AUTHORITY_SELECTION_MESSAGE];
        }

        if (needsContactValidation) {
          var contactCount = (this.fp && this.fp.CONTACTS) ? this.fp.CONTACTS.length : 0;
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
        var selectedId = numeric(
          event && event.target && event.target.value !== undefined
            ? event.target.value
            : this.selectedRescueCenterId
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

        if (match) {
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

        if (storedCenterId > 0) {
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
        if (matchId > 0) {
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
        this.pdfPreviewError = "";

        if (!planId) {
          this.pdfPreviewUrl = "";
          this.pdfPreviewLoading = false;
          this.pdfPreviewError = "Save this float plan to generate a PDF preview.";
          return;
        }

        if (!window.Api || typeof window.Api.createFloatPlanPdf !== "function") {
          this.pdfPreviewUrl = "";
          this.pdfPreviewLoading = false;
          this.pdfPreviewError = "PDF preview service is unavailable.";
          return;
        }

        this.pdfPreviewLoading = true;
        window.Api.createFloatPlanPdf(planId)
          .then(function (fileName) {
            self.pdfPreviewUrl = buildPdfPreviewUrl(fileName, Date.now());
            self.pdfPreviewLoading = false;
          })
          .catch(function (err) {
            self.pdfPreviewLoading = false;
            self.pdfPreviewUrl = "";
            self.pdfPreviewError = (err && err.MESSAGE) ? err.MESSAGE : "Unable to generate PDF preview.";
          });
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
        return this.fp.CONTACTS.some(function (item) {
          return numeric(item.CONTACTID) === target;
        });
      },

      toggleContact: function (contact) {
        var id = contact ? numeric(contact.CONTACTID) : 0;
        if (!id) return;
        for (var i = 0; i < this.fp.CONTACTS.length; i++) {
          if (numeric(this.fp.CONTACTS[i].CONTACTID) === id) {
            this.fp.CONTACTS.splice(i, 1);
            return;
          }
        }
        this.fp.CONTACTS.push({
          CONTACTID: id,
          SORT_ORDER: this.fp.CONTACTS.length + 1
        });
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
        var request = planId > 0 ? window.Api.getFloatPlanBootstrap(planId) : window.Api.getFloatPlanBootstrap();

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

            self.fp.FLOATPLAN = normalizeFloatPlan(data.FLOATPLAN);
            self.homePort = normalizeHomePort(data.HOME_PORT || data.HOMEPORT || data.homePort || {});
            self.homePortTimezone = getTimezoneForState(self.homePort ? self.homePort.state : "");
            self.applyHomePortDefaults();

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

            self.syncRescueCenterSelection();

            self.initialPlanId = numeric(self.fp.FLOATPLAN.FLOATPLANID) || self.initialPlanId;
            self.isLoading = false;
            self.clearStatus();
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
        this.fp.FLOATPLAN = normalizeFloatPlan(response.FLOATPLAN || response);
        this.syncRescueCenterSelection();
        this.fp.PASSENGERS = sortByOrder(
          toArray(response.PLAN_PASSENGERS)
            .map(normalizePassengerSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        this.fp.CONTACTS = sortByOrder(
          toArray(response.PLAN_CONTACTS)
            .map(normalizeContactSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        this.fp.WAYPOINTS = sortByOrder(
          toArray(response.PLAN_WAYPOINTS)
            .map(normalizeWaypointSelection)
            .filter(function (item) { return !!item; }),
          "SORT_ORDER"
        );
        this.initialPlanId = numeric(this.fp.FLOATPLAN.FLOATPLANID) || this.initialPlanId;
      },

      submitPlan: function () {
        var self = this;
        if (!window.Api || typeof window.Api.saveFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to save float plan.");
          return;
        }

        if (!this.validateStep(this.totalSteps)) {
          return;
        }

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

      submitPlanAndSend: function () {
        var self = this;
        if (!window.Api || typeof window.Api.saveFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to save float plan.");
          return;
        }
        if (!window.Api || typeof window.Api.sendFloatPlan !== "function") {
          this.handleError("API helper not available.", "Unable to send float plan.");
          return;
        }

        if (!this.validateStep(this.totalSteps)) {
          return;
        }
        if (!this.fp || !Array.isArray(this.fp.CONTACTS) || this.fp.CONTACTS.length === 0) {
          this.setStatus("Select at least one contact to send this float plan.", false);
          return;
        }

        this.isSaving = true;
        this.setStatus("Saving and sending your float plan...", true);

        window.Api.saveFloatPlan({
          FLOATPLAN: this.fp.FLOATPLAN,
          PASSENGERS: this.fp.PASSENGERS,
          CONTACTS: this.fp.CONTACTS,
          WAYPOINTS: this.fp.WAYPOINTS
        })
        .then(function (response) {
          self.applySaveResponse(response);
          return window.Api.sendFloatPlan(self.getPlanId());
        })
        .then(function (response) {
          self.setStatus(response && response.MESSAGE ? response.MESSAGE : "Float plan sent to selected contacts.", true);
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
          self.handleError(err, "Unable to save and send float plan.");
        });
      },

      confirmDelete: function () {
        var planId = this.getPlanId();
        if (planId <= 0) {
          return;
        }
        if (!window.confirm("Delete this float plan? This cannot be undone.")) {
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
            self.handleError(err, "Unable to delete float plan.");
          });
      }
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
