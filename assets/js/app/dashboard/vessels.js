(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var vesselState = state.vesselState || { all: [] };

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

  function updateVesselsSummary(vessels) {
    if (!vessels || !vessels.length) {
      setVesselsSummary("No vessels yet");
      return;
    }

    setVesselsSummary(vessels.length + " total");
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
      var vesselId = utils.pick(vessel, ["VESSELID", "ID"], "");
      var name = utils.pick(vessel, ["VESSELNAME", "NAME"], "");
      var reg = utils.pick(vessel, ["REGISTRATION", "REGNO"], "");
      var vesselType = utils.pick(vessel, ["TYPE", "VESSELTYPE"], "");
      var length = utils.pick(vessel, ["LENGTH"], "");
      var color = utils.pick(vessel, ["COLOR"], "");
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
            '<div class="list-title">' + utils.escapeHtml(nameText) + "</div>" +
            "<small>" + utils.escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="vessel-edit-' + utils.escapeHtml(vesselId) + '" data-action="edit" data-vessel-id="' + utils.escapeHtml(vesselId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="vessel-delete-' + utils.escapeHtml(vesselId) + '" data-action="delete" data-vessel-id="' + utils.escapeHtml(vesselId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var vessels = data.VESSELS || data.vessels || [];
        vessels = vessels.slice().sort(function (a, b) {
          var aName = utils.pick(a, ["VESSELNAME", "NAME"], "").toLowerCase();
          var bName = utils.pick(b, ["VESSELNAME", "NAME"], "").toLowerCase();
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
        utils.showDashboardAlert("Unable to load vessels. Please try again later.", "danger");
      });
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
          utils.clearFieldError(vesselNameInput, vesselNameError);
        });
      }
      if (vesselTypeInput) {
        vesselTypeInput.addEventListener("input", function () {
          utils.clearFieldError(vesselTypeInput, vesselTypeError);
        });
      }
      if (vesselLengthInput) {
        vesselLengthInput.addEventListener("input", function () {
          utils.clearFieldError(vesselLengthInput, vesselLengthError);
        });
      }
      if (vesselColorInput) {
        vesselColorInput.addEventListener("input", function () {
          utils.clearFieldError(vesselColorInput, vesselColorError);
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

  function clearVesselValidation() {
    utils.clearFieldError(vesselNameInput, vesselNameError);
    utils.clearFieldError(vesselTypeInput, vesselTypeError);
    utils.clearFieldError(vesselLengthInput, vesselLengthError);
    utils.clearFieldError(vesselColorInput, vesselColorError);
  }

  function resetVesselForm() {
    if (vesselFormEl && vesselFormEl.reset) {
      vesselFormEl.reset();
    }
    if (vesselIdInput) vesselIdInput.value = "0";
    clearVesselValidation();
  }

  function populateVesselForm(vessel) {
    if (!vessel) {
      resetVesselForm();
      return;
    }
    if (vesselIdInput) vesselIdInput.value = utils.pick(vessel, ["VESSELID", "ID"], 0);
    if (vesselNameInput) vesselNameInput.value = utils.pick(vessel, ["VESSELNAME", "NAME"], "");
    if (vesselRegistrationInput) vesselRegistrationInput.value = utils.pick(vessel, ["REGISTRATION", "REGNO"], "");
    if (vesselTypeInput) vesselTypeInput.value = utils.pick(vessel, ["TYPE"], "");
    if (vesselLengthInput) vesselLengthInput.value = utils.pick(vessel, ["LENGTH"], "");
    if (vesselMakeInput) vesselMakeInput.value = utils.pick(vessel, ["MAKE"], "");
    if (vesselModelInput) vesselModelInput.value = utils.pick(vessel, ["MODEL"], "");
    if (vesselColorInput) vesselColorInput.value = utils.pick(vessel, ["COLOR"], "");
    if (vesselHomePortInput) vesselHomePortInput.value = utils.pick(vessel, ["HOMEPORT"], "");
    clearVesselValidation();
  }

  function openVesselModal(vessel) {
    ensureVesselModal();
    if (!vesselModalEl || !vesselModal) {
      return;
    }
    var vesselId = vessel ? utils.pick(vessel, ["VESSELID", "ID"], 0) : 0;
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
      utils.showAlertModal("Vessel API is unavailable.");
      return;
    }

    var payload = buildVesselPayload();
    clearVesselValidation();
    var hasError = false;
    if (!payload.VESSELNAME) {
      utils.setFieldError(vesselNameInput, vesselNameError, "Vessel name is required.");
      hasError = true;
    }
    if (!payload.TYPE) {
      utils.setFieldError(vesselTypeInput, vesselTypeError, "Vessel type is required.");
      hasError = true;
    }
    if (!payload.LENGTH) {
      utils.setFieldError(vesselLengthInput, vesselLengthError, "Vessel length is required.");
      hasError = true;
    }
    if (!payload.COLOR) {
      utils.setFieldError(vesselColorInput, vesselColorError, "Hull color is required.");
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
        if (!utils.ensureAuthResponse(data)) {
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
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save vessel.");
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
      var currentId = utils.pick(list[i], ["VESSELID", "ID"], 0);
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadVessels();
      })
      .catch(function (err) {
        console.error("Failed to delete vessel:", err);
        utils.showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
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
          if (!utils.ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            utils.showAlertModal(data.MESSAGE || "This vessel cannot be deleted.");
            return;
          }
          var vessel = findVesselById(vesselId);
          var vesselName = vessel ? utils.pick(vessel, ["VESSELNAME", "NAME"], "") : "";
          var confirmText = vesselName ? "Delete " + vesselName + "?" : "Delete this vessel?";
          utils.showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteVessel(vesselId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check vessel usage:", err);
          utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check vessel usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function initVessels() {
    var listEl = document.getElementById("vesselsList");
    var addVesselBtn = document.getElementById("addVesselBtn");
    if (!listEl && !addVesselBtn) return;

    ensureVesselModal();

    if (addVesselBtn) {
      addVesselBtn.addEventListener("click", function () {
        openVesselModal(null);
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handleVesselsListClick);
    }

    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadVessels();
    });
  }

  window.FPW.DashboardModules.vessels = {
    init: initVessels
  };
})(window, document);
