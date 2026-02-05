(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var floatPlanState = state.floatPlanState || { all: [], filtered: [], query: "" };

  var BASE_PATH = window.FPW_BASE || "";
  var FLOAT_PLAN_LIMIT = 100;
  var wizardModalEl = null;
  var wizardModal = null;
  var wizardMountEl = null;
  var cloneModalEl = null;
  var cloneModal = null;
  var cloneMessageEl = null;
  var cloneOkButton = null;

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
      var status = utils.pick(plans[i], ["STATUS", "status"], "");
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

  function renderStatusBadge(status) {
    var normalized = String(status || "").toUpperCase();
    var label = normalized || "UNKNOWN";
    var badgeClass = "badge bg-secondary";

    if (["ACTIVE", "OPEN"].indexOf(normalized) !== -1) {
      badgeClass = "badge bg-success";
      label = "Active";
    } else if (["PENDING"].indexOf(normalized) !== -1) {
      badgeClass = "badge bg-warning text-dark";
      label = "Pending";
    } else if (["CLOSED", "COMPLETED"].indexOf(normalized) !== -1) {
      badgeClass = "badge bg-secondary";
      label = "Closed";
    } else if (["CANCELLED", "CANCELED"].indexOf(normalized) !== -1) {
      badgeClass = "badge bg-dark";
      label = "Cancelled";
    }

    return '<span class="' + badgeClass + '">' + utils.escapeHtml(label) + "</span>";
  }

  function getStatusLabel(status) {
    var normalized = String(status || "").toUpperCase();
    if (!normalized) return "";
    if (["ACTIVE", "OPEN"].indexOf(normalized) !== -1) {
      return "Active";
    }
    if (["PENDING"].indexOf(normalized) !== -1) {
      return "Pending";
    }
    if (["CLOSED", "COMPLETED"].indexOf(normalized) !== -1) {
      return "Closed";
    }
    if (["CANCELLED", "CANCELED"].indexOf(normalized) !== -1) {
      return "Cancelled";
    }
    return status;
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
      var id = utils.pick(plan, ["FLOATPLANID", "PLANID", "ID"], "");
      var name = utils.pick(plan, ["PLANNAME", "NAME"], "");
      if (!name && id) {
        name = "Plan #" + id;
      }
      var status = utils.pick(plan, ["STATUS", "status"], "");
      var departureTimezone = utils.pick(plan, ["DEPARTURE_TIMEZONE", "departureTimezone", "departTimezone"], "");
      var returnTimezone = utils.pick(plan, ["RETURN_TIMEZONE", "returnTimezone"], "");
      var depart = utils.formatPlanDate(
        utils.pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt"], ""),
        { assumeUtc: true, timeZone: departureTimezone, includeTimeZone: true }
      );
      var returnBy = utils.formatPlanDate(
        utils.pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt"], ""),
        { assumeUtc: true, timeZone: returnTimezone, includeTimeZone: true }
      );
      var vessel = utils.pick(plan, ["VESSELNAME", "VESSEL"], "");
      var updated = utils.formatPlanDate(utils.pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], ""));
      var waypointCount = parseInt(utils.pick(plan, ["WAYPOINTCOUNT", "waypointCount"], 0), 10);
      if (isNaN(waypointCount)) waypointCount = 0;
      var statusText = getStatusLabel(status);
      var normalizedStatus = String(status || "").trim().toUpperCase();
      var checkInButton = (normalizedStatus === "ACTIVE" || normalizedStatus === "OVERDUE")
        ? '<button class="btn-success" type="button" data-action="checkin" data-plan-id="' + utils.escapeHtml(id) + '">Check-In</button>'
        : "";

      var metaParts = [];
      if (statusText) metaParts.push("Status: " + statusText);
      if (depart) metaParts.push("Departs " + depart);
      if (returnBy) metaParts.push("Return " + returnBy);
      if (waypointCount > 0) {
        metaParts.push(waypointCount + " waypoint" + (waypointCount === 1 ? "" : "s"));
      }
      if (vessel) metaParts.push(vessel);
      var metaText = metaParts.join(" • ");
      var updatedText = updated ? "Updated " + updated : "";

      var metaPartsInline = [];
      if (metaText) {
        metaPartsInline.push(utils.escapeHtml(metaText));
      }
      if (updatedText) {
        metaPartsInline.push(utils.escapeHtml(updatedText));
      }
      var metaInline = metaPartsInline.length
        ? "<small>" + metaPartsInline.join(" • ") + "</small>"
        : "";

      return (
        '<div class="list-item" data-plan-id="' + utils.escapeHtml(id) + '">' +
          '<div class="list-main">' +
            '<div class="list-title">' + utils.escapeHtml(name || "Untitled Plan") + ":</div>" +
            metaInline +
          "</div>" +
          '<div class="list-actions">' +
            checkInButton +
            '<button class="btn-secondary" type="button" data-action="view" data-plan-id="' + utils.escapeHtml(id) + '">View &amp; Send</button>' +
            '<button class="btn-secondary" type="button" data-action="clone" data-plan-id="' + utils.escapeHtml(id) + '">Clone</button>' +
            '<button class="btn-secondary" type="button" data-action="edit" data-plan-id="' + utils.escapeHtml(id) + '">Edit</button>' +
            '<button class="btn-danger" type="button" data-action="delete" data-plan-id="' + utils.escapeHtml(id) + '" data-plan-status="' + utils.escapeHtml(status) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
    listEl.scrollTop = scrollTop;
  }

  function buildPlanSearchText(plan) {
    var name = utils.pick(plan, ["PLANNAME", "NAME"], "");
    var status = utils.pick(plan, ["STATUS", "status"], "");
    var vessel = utils.pick(plan, ["VESSELNAME", "VESSEL"], "");
    var depart = utils.pick(plan, ["DEPARTDATETIME", "DEPARTUREDATE", "departAt", "DEPARTURE_TIME", "DEPARTING_FROM"], "");
    var returnBy = utils.pick(plan, ["RETURNDATETIME", "RETURNDATE", "returnAt", "RETURN_TIME", "RETURNING_TO", "DESTINATION"], "");
    var departureTimezone = utils.pick(plan, ["DEPARTURE_TIMEZONE", "departureTimezone", "departTimezone"], "");
    var returnTimezone = utils.pick(plan, ["RETURN_TIMEZONE", "returnTimezone"], "");
    var updated = utils.pick(plan, ["UPDATEDDATE", "UPDATEDAT", "MODIFIEDDATE"], "");
    var pieces = [
      name,
      status,
      vessel,
      depart,
      returnBy,
      updated,
      utils.formatPlanDate(depart, { assumeUtc: true, timeZone: departureTimezone, includeTimeZone: true }),
      utils.formatPlanDate(returnBy, { assumeUtc: true, timeZone: returnTimezone, includeTimeZone: true }),
      utils.formatPlanDate(updated)
    ];
    return utils.normalizeSearch(pieces.join(" "));
  }

  function applyFloatPlanFilter(rawQuery) {
    var query = utils.normalizeSearch(rawQuery);
    floatPlanState.query = query;

    var source = floatPlanState.all || [];
    var filtered = query
      ? source.filter(function (plan) {
          return buildPlanSearchText(plan).indexOf(query) !== -1;
        })
      : source.slice();

    floatPlanState.filtered = filtered;
    setFloatPlansFilterCount(filtered.length, source.length);
    renderFloatPlansList(filtered, source.length);
  }

  function initFloatPlansFilter() {
    var inputEl = document.getElementById("floatPlansFilterInput");
    var clearBtn = document.getElementById("floatPlansFilterClear");
    if (!inputEl) return;

    var debouncedFilter = utils.debounce(function () {
      applyFloatPlanFilter(inputEl.value);
    }, 200);

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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var plans = data.PLANS || data.FLOATPLANS || data.floatplans || [];
        plans = plans.slice().sort(function (a, b) {
          var aCreated = utils.parsePlanDate(utils.pick(a, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          var bCreated = utils.parsePlanDate(utils.pick(b, ["CREATEDDATE", "CREATEDAT", "DATECREATED", "CREATED_ON", "CREATED", "createdAt", "created_on"], ""));
          if (aCreated !== bCreated) {
            return bCreated - aCreated;
          }
          var aId = parseInt(utils.pick(a, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
          var bId = parseInt(utils.pick(b, ["FLOATPLANID", "PLANID", "ID"], 0), 10);
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
        utils.showDashboardAlert("Unable to load float plans. Please try again later.", "danger");
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
    } else if (action === "checkin") {
      utils.showConfirmModal("Check in this float plan?")
        .then(function (confirmed) {
          if (!confirmed) return;
          checkInFloatPlan(planId, button);
        });
    } else if (action === "delete") {
      var planStatus = button.getAttribute("data-plan-status") || "";
      var normalizedStatus = String(planStatus).trim().toUpperCase();
      if (normalizedStatus === "ACTIVE" || normalizedStatus === "OVERDUE") {
        utils.showAlertModal("Active or overdue float plans cannot be deleted.");
        return;
      }
      utils.showConfirmModal("Delete this float plan?")
        .then(function (confirmed) {
          if (!confirmed) return;
          deleteFloatPlan(planId, button);
        });
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
        var clonedName = utils.pick(data, ["CLONED_NAME", "PLANNAME"], "");
        if (!clonedName && data.FLOATPLAN) {
          clonedName = utils.pick(data.FLOATPLAN, ["NAME", "PLANNAME"], "");
        }
        showCloneModal(clonedName);
      })
      .catch(function (err) {
        console.error("Failed to clone float plan:", err);
        utils.showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Clone failed.", "danger");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Clone";
        }
      });
  }

  function checkInFloatPlan(planId, triggerButton) {
    if (!window.Api || typeof window.Api.checkInFloatPlan !== "function") {
      return;
    }

    var originalText = "";
    if (triggerButton) {
      originalText = triggerButton.textContent;
      triggerButton.disabled = true;
      triggerButton.textContent = "Checking in...";
    }

    Api.checkInFloatPlan(planId)
      .then(function (data) {
        if (!data.SUCCESS) {
          var statusLabel = utils.pick(data, ["STATUS", "status"], "");
          var message = (data && data.MESSAGE) ? data.MESSAGE : "Check-in failed.";
          if (statusLabel) {
            message += " Current status: " + statusLabel + ".";
          }
          throw { MESSAGE: message };
        }
        loadFloatPlans(FLOAT_PLAN_LIMIT);
      })
      .catch(function (err) {
        console.error("Failed to check in float plan:", err);
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Check-in failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Check-In";
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
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
      })
      .finally(function () {
        if (triggerButton) {
          triggerButton.disabled = false;
          triggerButton.textContent = originalText || "Delete";
        }
      });
  }

  function initFloatPlans() {
    var listEl = document.getElementById("floatPlansList");
    var addPlanBtn = document.getElementById("addFloatPlanBtn");
    if (!listEl && !addPlanBtn) return;

    ensureWizardModal();
    ensureCloneModal();
    initFloatPlansFilter();

    if (addPlanBtn) {
      addPlanBtn.addEventListener("click", function () {
        openWizard(0);
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handleFloatPlansListClick);
    }

    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadFloatPlans(FLOAT_PLAN_LIMIT);
    });
  }

  window.FPW.DashboardModules.floatplans = {
    init: initFloatPlans
  };
})(window, document);
