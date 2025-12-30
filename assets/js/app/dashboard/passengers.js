(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var passengerState = state.passengerState || { all: [] };

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

  function updatePassengersSummary(passengers) {
    if (!passengers || !passengers.length) {
      setPassengersSummary("No passengers yet");
      return;
    }

    setPassengersSummary(passengers.length + " total");
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
      var passengerId = utils.pick(passenger, ["PASSENGERID", "ID"], "");
      var name = utils.pick(passenger, ["PASSENGERNAME", "NAME"], "");
      var phone = utils.pick(passenger, ["PHONE"], "");
      var gender = utils.pick(passenger, ["GENDER"], "");
      var nameText = name || "Unnamed passenger";
      var metaParts = [];
      if (phone) metaParts.push("Phone: " + phone);
      if (gender) metaParts.push("Gender: " + gender);
      if (!metaParts.length) metaParts.push("Phone: N/A");
      var metaText = metaParts.join(" • ");

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + utils.escapeHtml(nameText) + "</div>" +
            "<small>" + utils.escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="passenger-edit-' + utils.escapeHtml(passengerId) + '" data-action="edit" data-passenger-id="' + utils.escapeHtml(passengerId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="passenger-delete-' + utils.escapeHtml(passengerId) + '" data-action="delete" data-passenger-id="' + utils.escapeHtml(passengerId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var passengers = data.PASSENGERS || data.passengers || [];
        passengers = passengers.slice().sort(function (a, b) {
          var aName = utils.pick(a, ["PASSENGERNAME", "NAME"], "").toLowerCase();
          var bName = utils.pick(b, ["PASSENGERNAME", "NAME"], "").toLowerCase();
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
        utils.showDashboardAlert("Unable to load passengers. Please try again later.", "danger");
      });
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
          utils.clearFieldError(passengerNameInput, passengerNameError);
        });
      }
      if (passengerPhoneInput) {
        passengerPhoneInput.addEventListener("input", function () {
          utils.clearFieldError(passengerPhoneInput, passengerPhoneError);
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

  function clearPassengerValidation() {
    utils.clearFieldError(passengerNameInput, passengerNameError);
    utils.clearFieldError(passengerPhoneInput, passengerPhoneError);
  }

  function resetPassengerForm() {
    if (passengerFormEl && passengerFormEl.reset) {
      passengerFormEl.reset();
    }
    if (passengerIdInput) passengerIdInput.value = "0";
    clearPassengerValidation();
  }

  function populatePassengerForm(passenger) {
    if (!passenger) {
      resetPassengerForm();
      return;
    }
    if (passengerIdInput) passengerIdInput.value = utils.pick(passenger, ["PASSENGERID", "ID"], 0);
    if (passengerNameInput) passengerNameInput.value = utils.pick(passenger, ["PASSENGERNAME", "NAME"], "");
    if (passengerPhoneInput) passengerPhoneInput.value = utils.pick(passenger, ["PHONE"], "");
    if (passengerAgeInput) passengerAgeInput.value = utils.pick(passenger, ["AGE"], "");
    if (passengerGenderInput) passengerGenderInput.value = utils.pick(passenger, ["GENDER"], "");
    if (passengerNotesInput) passengerNotesInput.value = utils.pick(passenger, ["NOTES"], "");
    clearPassengerValidation();
  }

  function openPassengerModal(passenger) {
    ensurePassengerModal();
    if (!passengerModalEl || !passengerModal) {
      return;
    }
    var passengerId = passenger ? utils.pick(passenger, ["PASSENGERID", "ID"], 0) : 0;
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

  function isValidPhone(value) {
    if (!value) return false;
    var digits = String(value).replace(/\D/g, "");
    if (digits.length === 11 && digits.charAt(0) === "1") {
      digits = digits.slice(1);
    }
    return digits.length === 10;
  }

  function savePassenger() {
    if (!window.Api || typeof window.Api.savePassenger !== "function") {
      utils.showAlertModal("Passengers API is unavailable.");
      return;
    }

    var payload = buildPassengerPayload();
    clearPassengerValidation();
    var hasError = false;
    if (!payload.PASSENGERNAME) {
      utils.setFieldError(passengerNameInput, passengerNameError, "Name is required.");
      hasError = true;
    }
    if (payload.PHONE && !isValidPhone(payload.PHONE)) {
      utils.setFieldError(passengerPhoneInput, passengerPhoneError, "Enter a valid US phone number.");
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
        if (!utils.ensureAuthResponse(data)) {
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
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save passenger.");
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
      var currentId = utils.pick(list[i], ["PASSENGERID", "ID"], 0);
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadPassengers();
      })
      .catch(function (err) {
        console.error("Failed to delete passenger:", err);
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
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
          if (!utils.ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            utils.showAlertModal(data.MESSAGE || "This passenger cannot be deleted.");
            return;
          }
          var passenger = findPassengerById(passengerId);
          var passengerName = passenger ? utils.pick(passenger, ["PASSENGERNAME", "NAME"], "") : "";
          var confirmText = passengerName ? "Delete " + passengerName + "?" : "Delete this passenger?";
          utils.showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deletePassenger(passengerId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check passenger usage:", err);
          utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check passenger usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function initPassengers() {
    var listEl = document.getElementById("passengersList");
    var addPassengerBtn = document.getElementById("addPassengerBtn");
    if (!listEl && !addPassengerBtn) return;

    ensurePassengerModal();

    if (addPassengerBtn) {
      addPassengerBtn.addEventListener("click", function () {
        openPassengerModal(null);
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handlePassengersListClick);
    }

    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadPassengers();
    });
  }

  window.FPW.DashboardModules.passengers = {
    init: initPassengers
  };
})(window, document);
