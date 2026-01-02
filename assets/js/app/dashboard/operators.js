(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var operatorState = state.operatorState || { all: [] };

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

  function updateOperatorsSummary(operators) {
    if (!operators || !operators.length) {
      setOperatorsSummary("No operators yet");
      return;
    }

    setOperatorsSummary(operators.length + " total");
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
      var operatorId = utils.pick(operator, ["OPERATORID", "ID"], "");
      var name = utils.pick(operator, ["OPERATORNAME", "NAME"], "");
      var phone = utils.pick(operator, ["PHONE"], "");
      var nameText = name || "Unnamed operator";
      var metaParts = [];
      if (phone) metaParts.push("Phone: " + phone);
      if (!metaParts.length) metaParts.push("Phone: N/A");
      var metaText = metaParts.join(" • ");

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + utils.escapeHtml(nameText) + "</div>" +
            "<small>" + utils.escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="operator-edit-' + utils.escapeHtml(operatorId) + '" data-action="edit" data-operator-id="' + utils.escapeHtml(operatorId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="operator-delete-' + utils.escapeHtml(operatorId) + '" data-action="delete" data-operator-id="' + utils.escapeHtml(operatorId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var operators = data.OPERATORS || data.operators || [];
        operators = operators.slice().sort(function (a, b) {
          var aName = utils.pick(a, ["OPERATORNAME", "NAME"], "").toLowerCase();
          var bName = utils.pick(b, ["OPERATORNAME", "NAME"], "").toLowerCase();
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
        utils.showDashboardAlert("Unable to load operators. Please try again later.", "danger");
      });
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
          utils.clearFieldError(operatorNameInput, operatorNameError);
        });
      }
      if (operatorPhoneInput) {
        operatorPhoneInput.addEventListener("input", function () {
          operatorPhoneInput.value = formatUsPhoneInput(operatorPhoneInput.value);
          utils.clearFieldError(operatorPhoneInput, operatorPhoneError);
        });
        operatorPhoneInput.addEventListener("blur", function () {
          operatorPhoneInput.value = formatUsPhoneInput(operatorPhoneInput.value);
        });
        operatorPhoneInput.addEventListener("keyup", function () {
          operatorPhoneInput.value = formatUsPhoneInput(operatorPhoneInput.value);
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

  function clearOperatorValidation() {
    utils.clearFieldError(operatorNameInput, operatorNameError);
    utils.clearFieldError(operatorPhoneInput, operatorPhoneError);
  }

  function resetOperatorForm() {
    if (operatorFormEl && operatorFormEl.reset) {
      operatorFormEl.reset();
    }
    if (operatorIdInput) operatorIdInput.value = "0";
    clearOperatorValidation();
  }

  function populateOperatorForm(operator) {
    if (!operator) {
      resetOperatorForm();
      return;
    }
    if (operatorIdInput) operatorIdInput.value = utils.pick(operator, ["OPERATORID", "ID"], 0);
    if (operatorNameInput) operatorNameInput.value = utils.pick(operator, ["OPERATORNAME", "NAME"], "");
    if (operatorPhoneInput) {
      operatorPhoneInput.value = formatUsPhoneInput(utils.pick(operator, ["PHONE"], ""));
    }
    if (operatorNotesInput) operatorNotesInput.value = utils.pick(operator, ["NOTES"], "");
    clearOperatorValidation();
  }

  function openOperatorModal(operator) {
    ensureOperatorModal();
    if (!operatorModalEl || !operatorModal) {
      return;
    }
    var operatorId = operator ? utils.pick(operator, ["OPERATORID", "ID"], 0) : 0;
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

  function saveOperator() {
    if (!window.Api || typeof window.Api.saveOperator !== "function") {
      utils.showAlertModal("Operators API is unavailable.");
      return;
    }

    var payload = buildOperatorPayload();
    clearOperatorValidation();
    var hasError = false;
    if (!payload.OPERATORNAME) {
      utils.setFieldError(operatorNameInput, operatorNameError, "Name is required.");
      hasError = true;
    }
    if (payload.PHONE && !isValidPhone(payload.PHONE)) {
      utils.setFieldError(operatorPhoneInput, operatorPhoneError, "Enter a valid US phone number.");
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
        if (!utils.ensureAuthResponse(data)) {
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
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save operator.");
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
      var currentId = utils.pick(list[i], ["OPERATORID", "ID"], 0);
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadOperators();
      })
      .catch(function (err) {
        console.error("Failed to delete operator:", err);
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.");
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
          if (!utils.ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            utils.showAlertModal(data.MESSAGE || "This operator cannot be deleted.");
            return;
          }
          var operator = findOperatorById(operatorId);
          var operatorName = operator ? utils.pick(operator, ["OPERATORNAME", "NAME"], "") : "";
          var confirmText = operatorName ? "Delete " + operatorName + "?" : "Delete this operator?";
          utils.showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteOperator(operatorId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check operator usage:", err);
          utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check operator usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function initOperators() {
    var listEl = document.getElementById("operatorsList");
    var addOperatorBtn = document.getElementById("addOperatorBtn");
    if (!listEl && !addOperatorBtn) return;

    ensureOperatorModal();

    if (addOperatorBtn) {
      addOperatorBtn.addEventListener("click", function () {
        openOperatorModal(null);
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handleOperatorsListClick);
    }

    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadOperators();
    });
  }

  window.FPW.DashboardModules.operators = {
    init: initOperators
  };
})(window, document);
