const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupCurrentRouteFloatPlanGroup,
  cleanupTrackedData,
  createCleanupState,
  postJson,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const { buildEntityName, buildTraceEmail, buildTracePrefix } = require("../support/fpwNames");
const {
  buildFloatPlansFromFirstRoute,
  currentGroupActionSelector,
  loginApprovedUser,
  waitForSummaryLoaded
} = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

function buildDateTimeLocal(daysFromNow, hour) {
  const value = new Date();
  value.setSeconds(0, 0);
  value.setDate(value.getDate() + daysFromNow);
  value.setHours(hour, 0, 0, 0);
  const yyyy = value.getFullYear();
  const mm = String(value.getMonth() + 1).padStart(2, "0");
  const dd = String(value.getDate()).padStart(2, "0");
  const hh = String(value.getHours()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}T${hh}:00`;
}

function requestBodyMatches(postData, bodyPart) {
  const requestBody = String(postData || "");
  if (!bodyPart) {
    return true;
  }
  if (requestBody.includes(bodyPart)) {
    return true;
  }
  const pairMatch = /"([^"]+)":"([^"]+)"/.exec(bodyPart);
  if (pairMatch) {
    const key = pairMatch[1];
    const value = pairMatch[2];
    return requestBody.includes(`${key}=${value}`) || requestBody.includes(`${key}=${encodeURIComponent(value)}`);
  }
  const keyMatch = /"([^"]+)"/.exec(bodyPart);
  if (keyMatch) {
    const key = keyMatch[1];
    return requestBody.includes(`"${key}"`) || requestBody.includes(`${key}=`);
  }
  return false;
}

async function waitForApi(page, urlPart, bodyPart, trigger) {
  const responsePromise = page.waitForResponse((response) => {
    if (!response.url().includes(urlPart)) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    const postData = response.request().postData() || "";
    return requestBodyMatches(postData, bodyPart);
  }, { timeout: 30000 });
  await trigger();
  const response = await responsePromise;
  return response.json();
}

async function closeAlertModal(page) {
  const modal = page.locator("#alertModal");
  if (!(await modal.isVisible().catch(() => false))) {
    return;
  }
  await modal.locator("button").last().click();
  await expect(modal).toBeHidden({ timeout: 30000 });
}

async function selectOptionContainingText(page, selector, text) {
  await page.waitForFunction(([selectSelector, wanted]) => {
    const select = document.querySelector(selectSelector);
    if (!select) {
      return false;
    }
    return Array.from(select.options).some((option) => {
      return String(option.textContent || "").includes(wanted);
    });
  }, [selector, text], { timeout: 30000 });
  const options = await page.locator(`${selector} option`).evaluateAll((nodes) => {
    return nodes.map((node) => ({
      text: String(node.textContent || "").trim(),
      value: node.value
    }));
  });
  const match = options.find((option) => option.text.includes(text));
  await page.selectOption(selector, match.value);
}

async function selectFirstRescueAuthority(page) {
  const selector = page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]');
  const options = await selector.locator("option").evaluateAll((nodes) => {
    return nodes
      .map((node) => ({ value: node.value, text: (node.textContent || "").trim() }))
      .filter((item) => item.value && item.value !== "0");
  });
  await selector.selectOption(options[0].value);
}

async function clickWizardNext(page) {
  const nextButton = page.getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await expect(nextButton).toBeVisible({ timeout: 30000 });
  await nextButton.click();
}

async function clickManifestContactsTab(page) {
  const contactsTab = page.getByRole("tab", { name: "Contacts", exact: true });
  await expect(contactsTab).toBeVisible({ timeout: 30000 });
  await contactsTab.click();
}

async function advanceWizardToManifestStep(page) {
  await expect(page.locator("#departingFrom")).toBeVisible({ timeout: 30000 });
  await page.fill('[name="DEPARTURE_TIME"]', buildDateTimeLocal(1, 9));
  await page.fill('[name="RETURN_TIME"]', buildDateTimeLocal(2, 18));
  await clickWizardNext(page);
  await expect(page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]')).toBeVisible({ timeout: 30000 });
  await selectFirstRescueAuthority(page);
  await clickWizardNext(page);
  await expect(page.locator('input[placeholder="Search passengers..."]')).toBeVisible({ timeout: 30000 });
}

async function createBlockingFloatPlan(page, state, prefix, vesselName, operatorName, contactName) {
  const floatPlanName = buildEntityName(prefix, "Blocking Float Plan");
  const buildPayload = await buildFloatPlansFromFirstRoute(page);
  for (const floatPlanId of buildPayload.floatPlanIds) {
    trackId(state, "floatPlanIds", floatPlanId);
  }
  if (buildPayload.createdTemporaryRoute && buildPayload.routeCode) {
    trackValue(state, "routeCodes", buildPayload.routeCode);
  }
  const floatPlanId = Number(buildPayload.floatPlanIds[0] || 0);
  expect(floatPlanId).toBeGreaterThan(0);
  await page.locator(currentGroupActionSelector(floatPlanId, "edit")).click();
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 30000 });
  await page.fill('[name="NAME"]', floatPlanName);
  await selectOptionContainingText(page, '[name="VESSELID"]', vesselName);
  await selectOptionContainingText(page, '[name="OPERATORID"]', operatorName);
  await clickWizardNext(page);
  await expect(page.locator("#departingFrom")).toBeVisible({ timeout: 30000 });
  await page.fill("#departingFrom", "Tarpon Springs");
  await page.fill("#returningTo", "Tarpon Springs");
  await page.selectOption("#departureTimezone", "US/Eastern");
  await page.selectOption("#returnTimezone", "US/Eastern");

  await advanceWizardToManifestStep(page);
  await clickManifestContactsTab(page);
  await page.getByRole("button", { name: contactName, exact: false }).click();
  await clickWizardNext(page);
  await expect(page.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('input[placeholder="Search waypoints..."]')).toHaveCount(0);
  await expect(page.locator(".fpw-manifest--waypoints")).toContainText("In Route");
  await clickWizardNext(page);
  await expect(page.getByRole("button", { name: "Save Float Plan", exact: true })).toBeVisible({ timeout: 30000 });

  const savePayload = await waitForApi(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"save"', async () => {
    await page.getByRole("button", { name: "Save Float Plan", exact: true }).click();
  });
  const savedPlanId = Number(savePayload.FLOATPLAN.FLOATPLANID || savePayload.FLOATPLANID || 0);
  expect(savedPlanId).toBe(floatPlanId);
  trackValue(state, "pdfPrefixes", floatPlanName.replace(/[^A-Za-z0-9_-]+/g, "_"));

  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 30000 });
  await page.locator("#floatPlanWizardModal .btn-close").click();
  await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });
  return {
    floatPlanId,
    floatPlanName,
    routeCode: buildPayload.routeCode
  };
}

async function saveVessel(page, vessel) {
  const response = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#saveVesselBtn");
  });
  const vesselId = Number(response.VESSELID || 0);
  await expect(page.locator("#vesselModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator("#vesselsList")).toContainText(vessel.name, { timeout: 30000 });
  return vesselId;
}

async function createVessel(page, state, name, makeDefault) {
  await page.click("#addVesselBtn");
  await expect(page.locator("#vesselModal")).toBeVisible({ timeout: 30000 });
  await page.fill("#vesselName", name);
  await page.fill("#vesselType", "Motor Yacht");
  await page.fill("#vesselLength", "42");
  await page.fill("#vesselColor", "White");
  await page.fill("#vesselRegistration", "FL-1234-AA");
  await page.fill("#vesselHomePort", "Tarpon Springs");
  await page.fill("#vesselMaxSpeed", "28");
  await page.fill("#vesselMostEfficientSpeed", "18");
  await page.fill("#vesselGallonsPerHour", "6");
  await page.fill("#vesselGphAtMaxSpeed", "10");
  await page.fill("#vesselFuelCapacity", "280");
  await page.fill("#vesselMake", "Nordic");
  await page.fill("#vesselModel", "Pilot");
  await page.setChecked("#vesselIsDefault", !!makeDefault);
  const vesselId = await saveVessel(page, { name });
  trackId(state, "vesselIds", vesselId);
  return vesselId;
}

async function createOperator(page, state, name, phone, notes) {
  const response = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addOperatorBtn");
    await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#operatorName", name);
    await page.fill("#operatorPhone", phone);
    await page.fill("#operatorNotes", notes);
    await page.click("#saveOperatorBtn");
  });
  const operatorId = Number(response.OPERATORID || 0);
  trackId(state, "operatorIds", operatorId);
  await expect(page.locator("#operatorModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator("#operatorsList")).toContainText(name, { timeout: 30000 });
  return operatorId;
}

async function createContact(page, state, name, email) {
  const response = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addContactBtn");
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactName", name);
    await page.fill("#contactPhone", "5555551212");
    await page.fill("#contactEmail", email);
    await page.click("#saveContactBtn");
  });
  const contactId = Number(response.CONTACTID || 0);
  trackId(state, "contactIds", contactId);
  await expect(page.locator("#contactModal")).toBeHidden({ timeout: 30000 });
  return contactId;
}

test("dashboard vessels and operators cover required fields, optional fields, ordering, updates, and linked delete blocking", async ({ page }, testInfo) => {
  const state = createCleanupState();
  const prefix = buildTracePrefix(testInfo, "dashboard-vessels-operators", "crud-linked-delete");
  const consoleErrors = attachConsoleErrorCollector(page);

  await loginApprovedUser(page);
  await cleanupCurrentRouteFloatPlanGroup(page);
  await waitForSummaryLoaded(page, "#vesselsSummary");
  await waitForSummaryLoaded(page, "#operatorsSummary");

  await page.click("#addVesselBtn");
  await expect(page.locator("#vesselModal")).toBeVisible({ timeout: 30000 });
  await page.click("#saveVesselBtn");
  await expect(page.locator("#vesselNameError")).toContainText("Vessel name is required.");
  await expect(page.locator("#vesselTypeError")).toContainText("Vessel type is required.");
  await expect(page.locator("#vesselLengthError")).toContainText("Vessel length is required.");
  await expect(page.locator("#vesselColorError")).toContainText("Hull color is required.");
  await page.locator("#vesselModal .btn-close").click();
  await expect(page.locator("#vesselModal")).toBeHidden({ timeout: 30000 });

  const vesselOlderName = buildEntityName(prefix, "Vessel Older");
  const vesselNewerName = buildEntityName(prefix, "Vessel Newer");
  const vesselOlderId = await createVessel(page, state, vesselOlderName, false);
  const vesselNewerId = await createVessel(page, state, vesselNewerName, false);

  const vesselTitles = await page.locator("#vesselsList .list-item .list-title").evaluateAll((nodes) => {
    return nodes.map((node) => (node.textContent || "").trim());
  });
  expect(vesselTitles.indexOf(vesselNewerName)).toBeGreaterThanOrEqual(0);
  expect(vesselTitles.indexOf(vesselOlderName)).toBeGreaterThanOrEqual(0);
  expect(vesselTitles.indexOf(vesselNewerName)).toBeLessThan(vesselTitles.indexOf(vesselOlderName));

  const vesselUpdatePayload = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
    await page.click(`#vessel-edit-${vesselOlderId}`);
    await expect(page.locator("#vesselModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#vesselRegistration", "FL-9999-ZZ");
    await page.fill("#vesselModel", "Pilot Updated");
    await page.fill("#vesselColor", "Blue");
    await page.click("#saveVesselBtn");
  });
  expect(Number(vesselUpdatePayload.VESSELID || 0)).toBe(vesselOlderId);
  await expect(page.locator("#vesselsList")).toContainText("Color: Blue");

  await page.click("#addOperatorBtn");
  await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
  await page.click("#saveOperatorBtn");
  await expect(page.locator("#operatorNameError")).toContainText("Name is required.");
  await page.locator("#operatorModal .btn-close").click();
  await expect(page.locator("#operatorModal")).toBeHidden({ timeout: 30000 });

  const operatorZuluName = buildEntityName(prefix, "Zulu Operator");
  const operatorAlphaName = buildEntityName(prefix, "Alpha Operator");
  await createOperator(page, state, operatorZuluName, "5555553300", "Zulu notes");
  const operatorAlphaId = await createOperator(page, state, operatorAlphaName, "5555552200", "Alpha notes");

  const operatorTitles = await page.locator("#operatorsList .list-item .list-title").evaluateAll((nodes) => {
    return nodes.map((node) => (node.textContent || "").trim());
  });
  expect(operatorTitles.indexOf(operatorAlphaName)).toBeGreaterThanOrEqual(0);
  expect(operatorTitles.indexOf(operatorZuluName)).toBeGreaterThanOrEqual(0);
  expect(operatorTitles.indexOf(operatorAlphaName)).toBeLessThan(operatorTitles.indexOf(operatorZuluName));

  const operatorUpdatePayload = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await page.click(`#operator-edit-${operatorAlphaId}`);
    await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#operatorNotes", "Alpha notes updated");
    await page.click("#saveOperatorBtn");
  });
  expect(Number(operatorUpdatePayload.OPERATORID || 0)).toBe(operatorAlphaId);
  await expect(page.locator("#operatorsList")).toContainText("Phone: (555) 555-2200");

  const contactName = buildEntityName(prefix, "Blocking Contact");
  await createContact(page, state, contactName, buildTraceEmail(prefix, "blocking-contact"));
  const blockingPlan = await createBlockingFloatPlan(page, state, prefix, vesselNewerName, operatorAlphaName, contactName);

  await page.click(`#vessel-delete-${vesselNewerId}`);
  await expect(page.locator("#alertModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#alertModalMessage")).toContainText(blockingPlan.floatPlanName);
  await closeAlertModal(page);

  await page.click(`#operator-delete-${operatorAlphaId}`);
  await expect(page.locator("#alertModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#alertModalMessage")).toContainText(blockingPlan.floatPlanName);
  await closeAlertModal(page);

  const routeDeletePayload = await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
    routeCode: blockingPlan.routeCode
  });
  expect(routeDeletePayload.SUCCESS).toBe(true);
  state.floatPlanIds = state.floatPlanIds.filter((id) => id !== blockingPlan.floatPlanId);
  state.routeCodes = state.routeCodes.filter((code) => code !== blockingPlan.routeCode);

  const vesselDeletePayload = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"delete"', async () => {
    await page.click(`#vessel-delete-${vesselNewerId}`);
    await expect(page.locator("#confirmModal")).toBeVisible({ timeout: 30000 });
    await page.click("#confirmModalOk");
  });
  expect(vesselDeletePayload.SUCCESS).toBe(true);
  state.vesselIds = state.vesselIds.filter((id) => id !== vesselNewerId);

  const operatorDeletePayload = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"delete"', async () => {
    await page.click(`#operator-delete-${operatorAlphaId}`);
    await expect(page.locator("#confirmModal")).toBeVisible({ timeout: 30000 });
    await page.click("#confirmModalOk");
  });
  expect(operatorDeletePayload.SUCCESS).toBe(true);
  state.operatorIds = state.operatorIds.filter((id) => id !== operatorAlphaId);

  await cleanupTrackedData(page, state);
  await assertNoConsoleErrors(consoleErrors);
});
