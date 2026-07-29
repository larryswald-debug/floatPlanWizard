const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupCurrentRouteFloatPlanGroup,
  cleanupTrackedData,
  createCleanupState,
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

async function waitForApi(page, urlPart, bodyPart, trigger) {
  const responsePromise = page.waitForResponse((response) => {
    if (!response.url().includes(urlPart)) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    const postData = response.request().postData() || "";
    return !bodyPart || postData.includes(bodyPart);
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
      .map((node) => ({ value: node.value }))
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

async function advanceWizardToReview(page, contactName, passengerName, waypointName) {
  await expect(page.locator("#departingFrom")).toBeVisible({ timeout: 30000 });
  await page.fill('[name="DEPARTURE_TIME"]', buildDateTimeLocal(1, 8));
  await page.fill('[name="RETURN_TIME"]', buildDateTimeLocal(1, 18));
  await clickWizardNext(page);
  await expect(page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]')).toBeVisible({ timeout: 30000 });
  await selectFirstRescueAuthority(page);
  await clickWizardNext(page);
  await page.fill('input[placeholder="Search passengers..."]', passengerName);
  await page.getByRole("button", { name: passengerName, exact: false }).click();
  await clickManifestContactsTab(page);
  await page.fill('input[placeholder="Search contacts..."]', contactName);
  await page.getByRole("button", { name: contactName, exact: false }).click();
  await clickWizardNext(page);
  await expect(page.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('input[placeholder="Search waypoints..."]')).toHaveCount(0);
  await expect(page.locator(".fpw-manifest--waypoints")).toContainText("In Route");
  await clickWizardNext(page);
  await expect(page.getByRole("button", { name: "Save Float Plan", exact: true })).toBeVisible({ timeout: 30000 });
}

async function createSupportVessel(page, state, vesselName) {
  const response = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addVesselBtn");
    await expect(page.locator("#vesselModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#vesselName", vesselName);
    await page.fill("#vesselType", "Center Console");
    await page.fill("#vesselLength", "28");
    await page.fill("#vesselColor", "White");
    await page.click("#saveVesselBtn");
  });
  const vesselId = Number(response.VESSELID || 0);
  trackId(state, "vesselIds", vesselId);
  return vesselId;
}

async function createSupportOperator(page, state, operatorName) {
  const response = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addOperatorBtn");
    await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#operatorName", operatorName);
    await page.click("#saveOperatorBtn");
  });
  const operatorId = Number(response.OPERATORID || 0);
  trackId(state, "operatorIds", operatorId);
  return operatorId;
}

test("dashboard contacts, passengers, and waypoints cover validation, search, ordering, updates, and current delete behavior", async ({ page }, testInfo) => {
  test.slow();
  const state = createCleanupState();
  const prefix = buildTracePrefix(testInfo, "dashboard-contacts-passengers-waypoints", "crud-search-blocking");
  const consoleErrors = attachConsoleErrorCollector(page);

  await loginApprovedUser(page);
  await cleanupCurrentRouteFloatPlanGroup(page);
  await waitForSummaryLoaded(page, "#contactsSummary");
  await waitForSummaryLoaded(page, "#passengersSummary");
  await waitForSummaryLoaded(page, "#waypointsSummary");

  await page.click("#addContactBtn");
  await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
  await page.click("#saveContactBtn");
  await expect(page.locator("#contactNameError")).toContainText("Contact name is required.");
  await expect(page.locator("#contactPhoneError")).toContainText("Phone is required.");
  await expect(page.locator("#contactEmailError")).toContainText("Email is required.");
  await page.locator("#contactModal .btn-close").click();
  await expect(page.locator("#contactModal")).toBeHidden({ timeout: 30000 });

  const contactZuluName = `AAB ${prefix} Contact`;
  const contactAlphaName = `AAA ${prefix} Contact`;
  const contactZuluPayload = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addContactBtn");
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactName", contactZuluName);
    await page.fill("#contactPhone", "5555551100");
    await page.fill("#contactEmail", buildTraceEmail(prefix, "zulu-contact"));
    await page.click("#saveContactBtn");
  });
  const contactZuluId = Number(contactZuluPayload.CONTACTID || 0);
  trackId(state, "contactIds", contactZuluId);
  const contactAlphaPayload = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addContactBtn");
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactName", contactAlphaName);
    await page.fill("#contactPhone", "5555552200");
    await page.fill("#contactEmail", buildTraceEmail(prefix, "alpha-contact"));
    await page.click("#saveContactBtn");
  });
  const contactAlphaId = Number(contactAlphaPayload.CONTACTID || 0);
  trackId(state, "contactIds", contactAlphaId);
  await expect(page.locator("#contactsList")).toContainText(contactAlphaName, { timeout: 30000 });
  await expect(page.locator("#contactsList")).toContainText(contactZuluName, { timeout: 30000 });

  const contactTitles = await page.locator("#contactsList .list-item .list-title").evaluateAll((nodes) => {
    return nodes.map((node) => (node.textContent || "").trim());
  });
  expect(contactTitles.indexOf(contactAlphaName)).toBeGreaterThanOrEqual(0);
  expect(contactTitles.indexOf(contactZuluName)).toBeGreaterThanOrEqual(0);
  expect(contactTitles.indexOf(contactAlphaName)).toBeLessThan(contactTitles.indexOf(contactZuluName));

  await page.click("#addPassengerBtn");
  await expect(page.locator("#passengerModal")).toBeVisible({ timeout: 30000 });
  await page.click("#savePassengerBtn");
  await expect(page.locator("#passengerNameError")).toContainText("Name is required.");
  await page.locator("#passengerModal .btn-close").click();
  await expect(page.locator("#passengerModal")).toBeHidden({ timeout: 30000 });

  const passengerZuluName = `AAB ${prefix} Passenger`;
  const passengerAlphaName = `AAA ${prefix} Passenger`;
  const passengerZuluPayload = await waitForApi(page, "/fpw/api/v1/passenger.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addPassengerBtn");
    await expect(page.locator("#passengerModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#passengerName", passengerZuluName);
    await page.fill("#passengerPhone", "5555553300");
    await page.fill("#passengerAge", "34");
    await page.fill("#passengerGender", "Female");
    await page.fill("#passengerNotes", "Passenger notes");
    await page.click("#savePassengerBtn");
  });
  const passengerZuluId = Number(passengerZuluPayload.PASSENGERID || 0);
  trackId(state, "passengerIds", passengerZuluId);
  const passengerAlphaPayload = await waitForApi(page, "/fpw/api/v1/passenger.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addPassengerBtn");
    await expect(page.locator("#passengerModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#passengerName", passengerAlphaName);
    await page.fill("#passengerPhone", "5555554400");
    await page.fill("#passengerAge", "29");
    await page.fill("#passengerGender", "Male");
    await page.fill("#passengerNotes", "Alpha notes");
    await page.click("#savePassengerBtn");
  });
  const passengerAlphaId = Number(passengerAlphaPayload.PASSENGERID || 0);
  trackId(state, "passengerIds", passengerAlphaId);
  await expect(page.locator("#passengersList")).toContainText(passengerAlphaName, { timeout: 30000 });
  await expect(page.locator("#passengersList")).toContainText(passengerZuluName, { timeout: 30000 });

  const passengerTitles = await page.locator("#passengersList .list-item .list-title").evaluateAll((nodes) => {
    return nodes.map((node) => (node.textContent || "").trim());
  });
  expect(passengerTitles.indexOf(passengerAlphaName)).toBeGreaterThanOrEqual(0);
  expect(passengerTitles.indexOf(passengerZuluName)).toBeGreaterThanOrEqual(0);
  expect(passengerTitles.indexOf(passengerAlphaName)).toBeLessThan(passengerTitles.indexOf(passengerZuluName));

  await page.click("#addWaypointBtn");
  await expect(page.locator("#waypointModal")).toBeVisible({ timeout: 30000 });
  await page.click("#saveWaypointBtn");
  await expect(page.locator("#waypointNameError")).toContainText("Name is required.");
  await page.locator("#waypointModal .btn-close").click();
  await expect(page.locator("#waypointModal")).toBeHidden({ timeout: 30000 });

  const waypointOlderName = buildEntityName(prefix, "Waypoint Older");
  const waypointNewerName = buildEntityName(prefix, "Waypoint Newer");
  const waypointOlderPayload = await waitForApi(page, "/fpw/api/v1/waypoint.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addWaypointBtn");
    await expect(page.locator("#waypointModal")).toBeVisible({ timeout: 30000 });
    const waypointNameInput = page.locator("#waypointName");
    await waypointNameInput.click();
    await waypointNameInput.fill(waypointOlderName);
    await expect(waypointNameInput).toHaveValue(waypointOlderName);
    await page.fill("#waypointLatitude", "27.950575");
    await page.fill("#waypointLongitude", "-82.457178");
    await page.fill("#waypointNotes", "Older note");
    await page.click("#saveWaypointBtn");
  });
  const waypointOlderId = Number(waypointOlderPayload.WAYPOINTID || 0);
  trackId(state, "waypointIds", waypointOlderId);
  const waypointNewerPayload = await waitForApi(page, "/fpw/api/v1/waypoint.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addWaypointBtn");
    await expect(page.locator("#waypointModal")).toBeVisible({ timeout: 30000 });
    const waypointNameInput = page.locator("#waypointName");
    await waypointNameInput.click();
    await waypointNameInput.fill(waypointNewerName);
    await expect(waypointNameInput).toHaveValue(waypointNewerName);
    await page.fill("#waypointLatitude", "27.771889");
    await page.fill("#waypointLongitude", "-82.638611");
    await page.fill("#waypointNotes", "Newer note");
    await page.click("#saveWaypointBtn");
  });
  const waypointNewerId = Number(waypointNewerPayload.WAYPOINTID || 0);
  trackId(state, "waypointIds", waypointNewerId);
  await expect(page.locator("#waypointsList")).toContainText(waypointNewerName, { timeout: 30000 });
  await expect(page.locator("#waypointsList")).toContainText(waypointOlderName, { timeout: 30000 });

  const waypointTitles = await page.locator("#waypointsList .list-item .list-title").evaluateAll((nodes) => {
    return nodes.map((node) => (node.textContent || "").trim());
  });
  expect(waypointTitles.indexOf(waypointNewerName)).toBeGreaterThanOrEqual(0);
  expect(waypointTitles.indexOf(waypointOlderName)).toBeGreaterThanOrEqual(0);
  expect(waypointTitles.indexOf(waypointNewerName)).toBeLessThan(waypointTitles.indexOf(waypointOlderName));

  const contactUpdatePayload = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click(`#contact-edit-${contactAlphaId}`);
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactPhone", "5555552211");
    await page.click("#saveContactBtn");
  });
  expect(Number(contactUpdatePayload.CONTACTID || 0)).toBe(contactAlphaId);

  const passengerUpdatePayload = await waitForApi(page, "/fpw/api/v1/passenger.cfc?method=handle", '"action":"save"', async () => {
    await page.click(`#passenger-edit-${passengerAlphaId}`);
    await expect(page.locator("#passengerModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#passengerNotes", "Alpha notes updated");
    await page.click("#savePassengerBtn");
  });
  expect(Number(passengerUpdatePayload.PASSENGERID || 0)).toBe(passengerAlphaId);

  const waypointUpdatePayload = await waitForApi(page, "/fpw/api/v1/waypoint.cfc?method=handle", '"action":"save"', async () => {
    await page.click(`#waypoint-edit-${waypointOlderId}`);
    await expect(page.locator("#waypointModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#waypointNotes", "Older note updated");
    await page.click("#saveWaypointBtn");
  });
  expect(Number(waypointUpdatePayload.WAYPOINTID || 0)).toBe(waypointOlderId);

  const vesselName = buildEntityName(prefix, "Blocking Vessel");
  const operatorName = buildEntityName(prefix, "Blocking Operator");
  await createSupportVessel(page, state, vesselName);
  await createSupportOperator(page, state, operatorName);

  const buildPayload = await buildFloatPlansFromFirstRoute(page);
  for (const createdId of buildPayload.floatPlanIds) {
    trackId(state, "floatPlanIds", createdId);
  }
  if (buildPayload.createdTemporaryRoute && buildPayload.routeCode) {
    trackValue(state, "routeCodes", buildPayload.routeCode);
  }
  const createdFloatPlanId = Number(buildPayload.floatPlanIds[0] || 0);
  expect(createdFloatPlanId).toBeGreaterThan(0);
  await page.locator(currentGroupActionSelector(createdFloatPlanId, "edit")).click();
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 30000 });
  const floatPlanName = buildEntityName(prefix, "Blocking Manifest Plan");
  await page.fill('[name="NAME"]', floatPlanName);
  await selectOptionContainingText(page, '[name="VESSELID"]', vesselName);
  await selectOptionContainingText(page, '[name="OPERATORID"]', operatorName);
  await clickWizardNext(page);
  await expect(page.locator("#departingFrom")).toBeVisible({ timeout: 30000 });
  await page.fill("#departingFrom", "Tampa");
  await page.fill("#returningTo", "Tampa");
  await page.selectOption("#departureTimezone", "US/Eastern");
  await page.selectOption("#returnTimezone", "US/Eastern");
  await advanceWizardToReview(page, contactAlphaName, passengerAlphaName, waypointNewerName);
  const savePayload = await waitForApi(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"save"', async () => {
    await page.getByRole("button", { name: "Save Float Plan", exact: true }).click();
  });
  const floatPlanId = Number(savePayload.FLOATPLAN.FLOATPLANID || savePayload.FLOATPLANID || 0);
  expect(floatPlanId).toBe(createdFloatPlanId);
  trackValue(state, "pdfPrefixes", floatPlanName.replace(/[^A-Za-z0-9_-]+/g, "_"));
  await page.locator("#floatPlanWizardModal .btn-close").click();
  await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });

  await page.locator(currentGroupActionSelector(floatPlanId, "edit")).click();
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 30000 });
  await clickWizardNext(page);
  await clickWizardNext(page);
  await clickWizardNext(page);
  await expect(page.locator('input[placeholder="Search passengers..."]')).toBeVisible({ timeout: 30000 });
  await page.fill('input[placeholder="Search passengers..."]', "AAA");
  await expect(page.locator(".fpw-manifest__list")).toContainText(passengerAlphaName);
  await clickManifestContactsTab(page);
  await page.fill('input[placeholder="Search contacts..."]', "AAA");
  await expect(page.locator(".fpw-manifest__list")).toContainText(contactAlphaName);
  await clickWizardNext(page);
  await expect(page.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('input[placeholder="Search waypoints..."]')).toHaveCount(0);
  await expect(page.locator(".fpw-manifest--waypoints")).toContainText("In Route");
  await page.locator("#floatPlanWizardModal .btn-close").click();
  await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });

  await page.click(`#contact-delete-${contactAlphaId}`);
  await expect(page.locator("#alertModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#alertModalMessage")).toContainText(floatPlanName);
  await closeAlertModal(page);

  await page.click(`#passenger-delete-${passengerAlphaId}`);
  await expect(page.locator("#alertModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#alertModalMessage")).toContainText(floatPlanName);
  await closeAlertModal(page);

  await page.click(`#waypoint-delete-${waypointNewerId}`);
  await expect(page.locator("#confirmModal")).toBeVisible({ timeout: 30000 });
  const waypointDeletePayload = await waitForApi(page, "/fpw/api/v1/waypoint.cfc?method=handle", '"action":"delete"', async () => {
    await page.click("#confirmModalOk");
  });
  expect(waypointDeletePayload.SUCCESS).toBe(true);
  state.waypointIds = state.waypointIds.filter((id) => id !== waypointNewerId);

  await cleanupTrackedData(page, state);
  await assertNoConsoleErrors(consoleErrors);
});
