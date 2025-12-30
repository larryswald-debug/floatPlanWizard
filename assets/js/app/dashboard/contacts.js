(function (window, document) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardModules = window.FPW.DashboardModules || {};

  var utils = window.FPW.DashboardUtils || {};
  var state = window.FPW.DashboardState || {};
  var contactState = state.contactState || { all: [] };

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

  function updateContactsSummary(contacts) {
    if (!contacts || !contacts.length) {
      setContactsSummary("No contacts yet");
      return;
    }

    setContactsSummary(contacts.length + " total");
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
      var contactId = utils.pick(contact, ["CONTACTID", "ID"], "");
      var name = utils.pick(contact, ["CONTACTNAME", "NAME"], "");
      var phone = utils.pick(contact, ["PHONE"], "");
      var email = utils.pick(contact, ["EMAIL"], "");
      var nameText = name || "Unnamed contact";
      var metaParts = [];
      if (phone) metaParts.push("Phone: " + phone);
      if (email) metaParts.push("Email: " + email);
      if (!metaParts.length) metaParts.push("Phone: N/A");
      var metaText = metaParts.join(" • ");

      return (
        '<div class="list-item">' +
          '<div class="list-main">' +
            '<div class="list-title">' + utils.escapeHtml(nameText) + "</div>" +
            "<small>" + utils.escapeHtml(metaText) + "</small>" +
          "</div>" +
          '<div class="list-actions">' +
            '<button class="btn-secondary" type="button" id="contact-edit-' + utils.escapeHtml(contactId) + '" data-action="edit" data-contact-id="' + utils.escapeHtml(contactId) + '">Edit</button>' +
            '<button class="btn-danger" type="button" id="contact-delete-' + utils.escapeHtml(contactId) + '" data-action="delete" data-contact-id="' + utils.escapeHtml(contactId) + '">Delete</button>' +
          "</div>" +
        "</div>"
      );
    }).join("");

    listEl.innerHTML = rows;
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }

        if (data.SUCCESS !== true) {
          throw data;
        }

        var contacts = data.CONTACTS || data.contacts || [];
        contacts = contacts.slice().sort(function (a, b) {
          var aName = utils.pick(a, ["CONTACTNAME", "NAME"], "").toLowerCase();
          var bName = utils.pick(b, ["CONTACTNAME", "NAME"], "").toLowerCase();
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
        utils.showDashboardAlert("Unable to load contacts. Please try again later.", "danger");
      });
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
          utils.clearFieldError(contactPhoneInput, contactPhoneError);
        });
      }
      if (contactNameInput) {
        contactNameInput.addEventListener("input", function () {
          utils.clearFieldError(contactNameInput, contactNameError);
        });
      }
      if (contactEmailInput) {
        contactEmailInput.addEventListener("input", function () {
          utils.clearFieldError(contactEmailInput, contactEmailError);
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

  function clearContactValidation() {
    utils.clearFieldError(contactNameInput, contactNameError);
    utils.clearFieldError(contactPhoneInput, contactPhoneError);
    utils.clearFieldError(contactEmailInput, contactEmailError);
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
    if (contactIdInput) contactIdInput.value = utils.pick(contact, ["CONTACTID", "ID"], 0);
    if (contactNameInput) contactNameInput.value = utils.pick(contact, ["CONTACTNAME", "NAME"], "");
    if (contactPhoneInput) contactPhoneInput.value = utils.pick(contact, ["PHONE"], "");
    if (contactEmailInput) contactEmailInput.value = utils.pick(contact, ["EMAIL"], "");
    clearContactValidation();
  }

  function openContactModal(contact) {
    ensureContactModal();
    if (!contactModalEl || !contactModal) {
      return;
    }
    var contactId = contact ? utils.pick(contact, ["CONTACTID", "ID"], 0) : 0;
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
      utils.showAlertModal("Contacts API is unavailable.");
      return;
    }

    var payload = buildContactPayload();
    clearContactValidation();
    var hasError = false;
    if (!payload.CONTACTNAME) {
      utils.setFieldError(contactNameInput, contactNameError, "Contact name is required.");
      hasError = true;
    }
    if (!payload.PHONE) {
      utils.setFieldError(contactPhoneInput, contactPhoneError, "Phone is required.");
      hasError = true;
    } else if (!isValidPhone(payload.PHONE)) {
      utils.setFieldError(contactPhoneInput, contactPhoneError, "Enter a valid US phone number.");
      hasError = true;
    }
    if (!payload.EMAIL) {
      utils.setFieldError(contactEmailInput, contactEmailError, "Email is required.");
      hasError = true;
    } else if (!isValidEmail(payload.EMAIL)) {
      utils.setFieldError(contactEmailInput, contactEmailError, "Enter a valid email address.");
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
        if (!utils.ensureAuthResponse(data)) {
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
        utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to save contact.");
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
      var currentId = utils.pick(list[i], ["CONTACTID", "ID"], 0);
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
        if (!utils.ensureAuthResponse(data)) {
          return;
        }
        if (!data.SUCCESS) {
          throw data;
        }
        loadContacts();
      })
      .catch(function (err) {
        console.error("Failed to delete contact:", err);
        utils.showDashboardAlert((err && err.MESSAGE) ? err.MESSAGE : "Delete failed.", "danger");
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
          if (!utils.ensureAuthResponse(data)) {
            return;
          }
          if (data.SUCCESS !== true) {
            throw data;
          }
          if (!data.CANDELETE) {
            utils.showAlertModal(data.MESSAGE || "This contact cannot be deleted.");
            return;
          }
          var contact = findContactById(contactId);
          var contactName = contact ? utils.pick(contact, ["CONTACTNAME", "NAME"], "") : "";
          var confirmText = contactName ? "Delete " + contactName + "?" : "Delete this contact?";
          utils.showConfirmModal(confirmText).then(function (confirmed) {
            if (!confirmed) return;
            deleteContact(contactId, button);
          });
        })
        .catch(function (err) {
          console.error("Failed to check contact usage:", err);
          utils.showAlertModal((err && err.MESSAGE) ? err.MESSAGE : "Unable to check contact usage.");
        })
        .finally(function () {
          button.disabled = false;
        });
    }
  }

  function initContacts() {
    var listEl = document.getElementById("contactsList");
    var addContactBtn = document.getElementById("addContactBtn");
    if (!listEl && !addContactBtn) return;

    ensureContactModal();

    if (addContactBtn) {
      addContactBtn.addEventListener("click", function () {
        openContactModal(null);
      });
    }

    if (listEl) {
      listEl.addEventListener("click", handleContactsListClick);
    }

    document.addEventListener("fpw:dashboard:user-ready", function () {
      loadContacts();
    });
  }

  window.FPW.DashboardModules.contacts = {
    init: initContacts
  };
})(window, document);
