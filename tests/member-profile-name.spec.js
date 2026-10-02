const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// Run real wizard methods with an isolated Vue host. No HTTP, database, PDF, or mail.
function wizard(api = {}, options = {}) {
  let instance;
  const document = { currentScript: null, getElementById: () => null };
  const window = {
    FPW_BASE: "/fpw",
    location: { pathname: "/fpw/app/dashboard.cfm", search: "" },
    Api: api,
    setTimeout,
    Vue: {
      createApp(definition) {
        instance = definition.data();
        Object.entries(definition.methods).forEach(([key, value]) => { instance[key] = value.bind(instance); });
        Object.entries(definition.computed).forEach(([key, value]) => {
          Object.defineProperty(instance, key, { get: value.bind(instance) });
        });
        instance.$refs = { memberFirstName: { focus() {} } };
        instance.$nextTick = (callback) => Promise.resolve().then(callback);
        return { mount: () => instance, unmount() {} };
      }
    }
  };
  const source = fs.readFileSync(path.join(__dirname, "../assets/js/app/floatplanWizard.js"), "utf8");
  vm.runInNewContext(source, { window, document, console: { error() {} }, URLSearchParams, Promise, setTimeout });
  window.FloatPlanWizard.init({ planId: 123, mountEl: { dataset: {}, innerHTML: "" }, ...options });
  instance.isLoading = false;
  instance.validateStep = () => true;
  instance.validateStepsThrough = () => true;
  instance.loadPdfPreview = () => {};
  return instance;
}
const tick = () => new Promise((resolve) => setImmediate(resolve));

test("an existing first-only or last-only member skips capture without changing operator", async () => {
  let writes = 0;
  const app = wizard({ updateProfileName: async () => { writes++; } });
  app.fp.FLOATPLAN.OPERATORID = 72;
  app.applyMemberProfile({ FNAME: "", LNAME: "Rivera" });
  expect(app.memberNameRequired).toBe(false);
  expect(app.memberDisplayName).toBe("Rivera");
  await app.nextStep();
  expect(app.step).toBe(2);
  expect(writes).toBe(0);
  expect(app.fp.FLOATPLAN.OPERATORID).toBe(72);
});

test("blank and oversized names block Continue and Save before any write", async () => {
  let writes = 0;
  const app = wizard({
    updateProfileName: async () => { writes++; },
    saveFloatPlan: async () => { writes++; }
  });
  app.memberFirstName = "   ";
  await app.nextStep();
  expect(app.step).toBe(1);
  expect(app.memberNameError).toContain("first or last");
  app.memberFirstName = "X".repeat(46);
  await app.submitPlan();
  expect(writes).toBe(0);
  expect(app.step).toBe(1);
});

test("Continue waits for one trimmed name-only save and ignores a duplicate click", async () => {
  let finish, writes = 0, sent;
  const app = wizard({
    updateProfileName: (payload) => {
      writes++;
      sent = payload;
      return new Promise((resolve) => { finish = resolve; });
    }
  });
  app.memberFirstName = "  Lee  ";
  const pending = app.nextStep();
  expect(app.step).toBe(1);
  expect(app.isSaving).toBe(true);
  await app.nextStep();
  expect(writes).toBe(1);
  expect(JSON.parse(JSON.stringify(sent))).toEqual({ fName: "Lee", lName: "" });
  finish({ SUCCESS: true, PROFILE: { FNAME: "Lee", LNAME: "" } });
  await pending;
  expect(app.step).toBe(2);
  expect(app.memberNameRequired).toBe(false);
  expect(app.isSaving).toBe(false);
});

test("name failure preserves input and prevents the plan action", async () => {
  let planWrites = 0;
  const app = wizard({
    updateProfileName: async () => { throw { MESSAGE: "Please retry name save." }; },
    saveFloatPlan: async () => { planWrites++; }
  });
  app.memberLastName = "Rivera";
  await app.submitPlan();
  expect(planWrites).toBe(0);
  expect(app.memberLastName).toBe("Rivera");
  expect(app.step).toBe(1);
  expect(app.statusMessage.message).toBe("Please retry name save.");
});

test("a later plan failure keeps saved profile identity for the next retry", async () => {
  let profileWrites = 0, planWrites = 0;
  const app = wizard({
    updateProfileName: async (payload) => { profileWrites++; return { SUCCESS: true, PROFILE: payload }; },
    saveFloatPlan: async () => { planWrites++; throw { MESSAGE: "Plan validation failed." }; }
  });
  app.memberFirstName = "Lee";
  await app.submitPlan();
  await tick();
  expect(app.memberDisplayName).toBe("Lee");
  expect(app.memberNameRequired).toBe(false);
  await app.submitPlan();
  await tick();
  expect(profileWrites).toBe(1);
  expect(planWrites).toBe(2);
});

test("a committed Premium send retry bypasses name capture and all new saves", async () => {
  let sends = 0, writes = 0;
  const app = wizard({
    updateProfileName: async () => { writes++; },
    saveFloatPlan: async () => { writes++; },
    sendFloatPlan: async () => { sends++; return { SUCCESS: true, IDEMPOTENT_REPLAY: true }; }
  });
  app.premiumSendReceipt = { found: true };
  await app.submitPlanAndSend();
  await tick();
  expect(sends).toBe(1);
  expect(writes).toBe(0);
  expect(app.memberNameRequired).toBe(true);
});

test("a server name guard restores the first screen without discarding the plan", () => {
  const app = wizard();
  app.applyMemberProfile({ fName: "Lee" });
  app.step = 6;
  app.basicReviewConfirmationOpen = true;
  app.fp.FLOATPLAN.NAME = "Saved journey";
  app.fp.FLOATPLAN.OPERATORID = 91;
  app.handleError({ ERROR: "PROFILE_NAME_REQUIRED", MESSAGE: "Enter your name." });
  expect(app.step).toBe(1);
  expect(app.memberNameRequired).toBe(true);
  expect(app.basicReviewConfirmationOpen).toBe(false);
  expect(app.fp.FLOATPLAN.NAME).toBe("Saved journey");
  expect(app.fp.FLOATPLAN.OPERATORID).toBe(91);
});

test("opening nameless direct Review returns to name capture before PDF preview", async () => {
  let previews = 0;
  const app = wizard({
    getFloatPlanBootstrap: async () => ({
      FLOATPLAN: { FLOATPLANID: 123 }, MEMBER_PROFILE: { FNAME: "", LNAME: "" }
    })
  }, { startStep: 6 });
  app.applyHomePortDefaults = () => {};
  app.applyRouteDefaults = () => {};
  app.syncRescueCenterSelection = () => {};
  app.requestRouteReturnSuggestion = () => {};
  app.loadPdfPreview = () => { previews++; };
  app.loadBootstrap();
  await tick();
  expect(app.step).toBe(1);
  expect(previews).toBe(0);
});

function basicForm(apiOverrides = {}) {
  const elements = {};
  const listeners = {};
  function element(id) {
    if (elements[id]) return elements[id];
    const classes = new Set();
    const handlers = {};
    const value = {
      id, value: "", textContent: "", innerHTML: "", disabled: false, dataset: {}, handlers,
      classList: {
        add(...names) { names.forEach((name) => classes.add(name)); },
        remove(...names) { names.forEach((name) => classes.delete(name)); },
        toggle(name, force) { if (force) classes.add(name); else classes.delete(name); },
        contains(name) { return classes.has(name); }
      },
      addEventListener(type, callback) { handlers[type] = callback; },
      querySelectorAll(selector) {
        return id === "basicFloatPlanModal" && selector.includes("data-bs-dismiss") ? [element("closeButton")] : [];
      },
      reset() { Object.values(elements).forEach((field) => { field.value = ""; }); },
      focus() {},
      getAttribute() { return ""; }
    };
    elements[id] = value;
    return value;
  }
  const document = {
    getElementById: element,
    addEventListener(type, callback) { listeners[type] = callback; }
  };
  const window = {
    FPW: {}, FPW_BASE: "/fpw", setTimeout,
    location: { pathname: "/fpw/app/dashboard.cfm", search: "" },
    Api: {
      getProfileName: async () => ({ SUCCESS: true, PROFILE: { FNAME: "", LNAME: "" } }),
      getBasicFloatPlanDraft: async () => ({
        SUCCESS: true, FLOATPLAN: { FLOATPLANID: 77, NAME: "Protected draft" },
        BASIC_DETAILS: { VESSEL_NAME: "Original vessel", CAPTAIN_NAME: "Original captain" }
      }),
      ...apiOverrides
    }
  };
  const source = fs.readFileSync(path.join(__dirname, "../assets/js/app/dashboard/basic-floatplan.js"), "utf8");
  vm.runInNewContext(source, { window, document, Promise, setTimeout });
  const app = window.FPW.DashboardModules.basicFloatPlan;
  app.init();
  return {
    app, elements,
    savedDraftSend() {
      const trigger = {
        id: "", textContent: "Send Float Plan",
        closest() { return this; },
        hasAttribute(name) { return name === "data-basic-floatplan-send-draft"; },
        getAttribute() { return "77"; }
      };
      listeners.click({ target: trigger, preventDefault() {}, stopPropagation() {}, stopImmediatePropagation() {} });
    },
    fillValidDefaults() {
      Object.entries({
        basicPlanName: "Replacement", basicPlanVesselName: "Vessel", basicPlanOperatorName: "Operator",
        basicPlanCaptainName: "Captain", basicPlanEmail: "captain@example.test", basicAuthorityId: "1",
        basicDepartingFrom: "Port", basicDestination: "Marina",
        basicDepartureTime: "2026-10-02T10:00", basicReturnTime: "2026-10-02T12:00",
        basicDepartureTimezone: "UTC", basicReturnTimezone: "UTC",
        basicContactName: "Contact", basicContactEmail: "contact@example.test", basicMemberFirstName: "Lee"
      }).forEach(([id, value]) => { element(id).value = value; });
    }
  };
}

test("Basic nameless-send recovery preserves a failed draft load and blocks default-value writes", async () => {
  let saves = 0, names = 0, sends = 0;
  const form = basicForm({
    sendBasicFloatPlan: async () => { sends++; throw { ERROR: "PROFILE_NAME_REQUIRED", MESSAGE: "Enter your name." }; },
    getBasicFloatPlanDraft: async () => { throw { MESSAGE: "Draft could not be loaded." }; },
    updateProfileName: async () => { names++; },
    saveBasicFloatPlan: async () => { saves++; }
  });
  form.savedDraftSend();
  await tick();
  await tick();
  expect(form.elements.basicFloatPlanMessage.textContent).toBe("Draft could not be loaded.");
  expect(form.elements.basicFloatPlanSaveBtn.disabled).toBe(true);
  expect(form.elements.basicFloatPlanSendBtn.disabled).toBe(true);
  expect(form.elements.closeButton.disabled).toBe(false);
  form.fillValidDefaults();
  // Call handlers directly as well as checking disabled buttons: keyboard/programmatic calls cannot save.
  form.elements.basicFloatPlanSaveBtn.handlers.click();
  form.elements.basicFloatPlanSendBtn.handlers.click();
  await tick();
  expect(saves).toBe(0);
  expect(names).toBe(0);
  expect(sends).toBe(1);
});

test("Basic failed profile loading keeps its error when delayed options finish", async () => {
  let finishOptions;
  const form = basicForm({
    getProfileName: async () => { throw { MESSAGE: "Sender profile unavailable." }; },
    getPassengers: () => new Promise((resolve) => { finishOptions = resolve; })
  });
  expect(await form.app.open(77)).toBe(false);
  finishOptions({ SUCCESS: true, PASSENGERS: [] });
  await tick();
  expect(form.elements.basicFloatPlanMessage.textContent).toBe("Sender profile unavailable.");
  expect(form.elements.basicFloatPlanSaveBtn.disabled).toBe(true);
  expect(form.elements.basicFloatPlanSendBtn.disabled).toBe(true);
  expect(form.elements.closeButton.disabled).toBe(false);
});

test("Basic reopening after a load failure unlocks only the successfully hydrated draft", async () => {
  let attempts = 0;
  const form = basicForm({
    getBasicFloatPlanDraft: async () => {
      if (++attempts === 1) throw { MESSAGE: "Temporary draft error." };
      return { SUCCESS: true, FLOATPLAN: { FLOATPLANID: 77, NAME: "Protected draft" },
        BASIC_DETAILS: { VESSEL_NAME: "Original vessel", CAPTAIN_NAME: "Original captain" } };
    }
  });
  expect(await form.app.open(77)).toBe(false);
  expect(form.elements.basicFloatPlanSaveBtn.disabled).toBe(true);
  expect(await form.app.open(77)).toBe(true);
  expect(form.elements.basicFloatPlanId.value).toBe("77");
  expect(form.elements.basicPlanName.value).toBe("Protected draft");
  expect(form.elements.basicPlanVesselName.value).toBe("Original vessel");
  expect(form.elements.basicPlanCaptainName.value).toBe("Original captain");
  expect(form.elements.basicFloatPlanSaveBtn.disabled).toBe(false);
  expect(form.elements.basicFloatPlanSendBtn.disabled).toBe(false);
  expect(form.elements.basicMemberNameSection.classList.contains("d-none")).toBe(false);
});
