// /fpw/assets/js/app/floatplanWizard.js
(function (window, document, Vue) {
  "use strict";

  if (!Vue) {
    console.error("Vue is required for the float plan wizard.");
    return;
  }

  var mountEl = document.getElementById("wizardApp");
  if (!mountEl) {
    return;
  }

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

  function toArray(value) {
    return Array.isArray(value) ? value.slice() : [];
  }

  function numeric(value) {
    var num = parseInt(value, 10);
    return isNaN(num) ? 0 : num;
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
    "EMAIL",
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
    3: buildFloatplanConstraints([
      "EMAIL",
      "RESCUE_AUTHORITY",
      "RESCUE_AUTHORITY_PHONE"
    ]),
    7: buildFloatplanConstraints(REQUIRED_FLOATPLAN_KEYS)
  };

  var app = Vue.createApp({
    data: function () {
      return {
        step: 1,
        totalSteps: 7,
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
        selectedRescueCenterId: 0,
        rescueCenterSyncing: false,
        initialPlanId: getPlanIdFromQuery()
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
        var payload = this.fp ? this.fp.FLOATPLAN || {} : {};
        if (stepNumber === 1) {
          var nameValue = (payload.NAME || "").trim();
          if (!nameValue) {
            this.setStatus("Float plan name is required.", false);
            return false;
          }
        }
        if (stepNumber === 2) {
          var routeFields = [
            "DEPARTING_FROM",
            "DEPARTURE_TIME",
            "DEPARTURE_TIMEZONE",
            "RETURNING_TO",
            "RETURN_TIME",
            "RETURN_TIMEZONE"
          ];
          for (var i = 0; i < routeFields.length; i++) {
            var key = routeFields[i];
            if (isEmptyValue(payload[key])) {
              this.setStatus(getPresenceMessageFor(key), false);
              return false;
            }
          }
        }
        var constraints = STEP_VALIDATION_CONSTRAINTS[stepNumber];
        var validator = window.validate;
        if (!constraints || typeof validator !== "function") {
          return true;
        }
        var errors = validator(payload, constraints, { format: "flat", fullMessages: false });
        if (!errors) {
          this.clearStatus();
          return true;
        }
        this.setStatus(errors[0], false);
        return false;
      },

      nextStep: function () {
        if (this.step >= this.totalSteps) {
          return;
        }
        if (!this.validateStep(this.step)) {
          return;
        }
        this.step += 1;
      },

      prevStep: function () {
        if (this.step > 1) {
          this.step -= 1;
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

      handleRescueCenterSelection: function () {
        if (this.rescueCenterSyncing) {
          return;
        }
        this.rescueCenterSyncing = true;
        var selectedId = numeric(this.selectedRescueCenterId);
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
        var matchId = 0;

        if (authority && phone) {
          var normalizedName = authority.toLowerCase();
          var normalizedPhone = phone;
          for (var j = 0; j < this.rescueCenters.length; j++) {
            var center = this.rescueCenters[j];
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
        this.rescueCenterSyncing = false;
      },

      getPlanId: function () {
        return numeric(this.fp.FLOATPLAN.FLOATPLANID || this.initialPlanId);
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
          })
          .catch(function (err) {
            self.isLoading = false;
            self.handleError(err, "Unable to load float plan.");
          });
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
          self.fp.FLOATPLAN = normalizeFloatPlan(response.FLOATPLAN || response);
          self.syncRescueCenterSelection();
          self.fp.PASSENGERS = sortByOrder(
            toArray(response.PLAN_PASSENGERS)
              .map(normalizePassengerSelection)
              .filter(function (item) { return !!item; }),
            "SORT_ORDER"
          );
          self.fp.CONTACTS = sortByOrder(
            toArray(response.PLAN_CONTACTS)
              .map(normalizeContactSelection)
              .filter(function (item) { return !!item; }),
            "SORT_ORDER"
          );
          self.fp.WAYPOINTS = sortByOrder(
            toArray(response.PLAN_WAYPOINTS)
              .map(normalizeWaypointSelection)
              .filter(function (item) { return !!item; }),
            "SORT_ORDER"
          );

          self.initialPlanId = numeric(self.fp.FLOATPLAN.FLOATPLANID) || self.initialPlanId;
          self.setStatus("Float plan saved successfully.", true);
          self.isSaving = false;
        })
        .catch(function (err) {
          self.isSaving = false;
          self.handleError(err, "Unable to save float plan.");
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
            window.setTimeout(function () {
              window.location.href = "/fpw/app/dashboard.cfm";
            }, 600);
          })
          .catch(function (err) {
            self.isSaving = false;
            self.handleError(err, "Unable to delete float plan.");
          });
      }
    }
  });

  app.mount(mountEl);
})(window, document, window.Vue);
