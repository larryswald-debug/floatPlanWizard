const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupBlockingActiveTestFloatPlans,
  cleanupCurrentRouteFloatPlanGroup,
  cleanupTrackedData,
  createCleanupState,
  postJson,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const { buildTraceEmail, buildTracePrefix } = require("../support/fpwNames");
const {
  buildFloatPlansFromFirstRoute,
  currentGroupActionSelector,
  loginApprovedUser
} = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

const sharedState = createCleanupState();
let sharedSupport = null;

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

async function postSetupJson(page, url, payload) {
  const response = await page.context().request.post(url, {
    data: payload || {}
  });
  const json = await response.json();
  if (!response.ok() || !json || json.SUCCESS === false) {
    throw new Error(`Request failed for ${url}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function clickWizardNext(page) {
  const nextButton = page.locator("#floatPlanWizardModal").getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await expect(nextButton).toBeVisible({ timeout: 30000 });
  await nextButton.click();
}

async function clickManifestContactsTab(page) {
  const contactsTab = page.getByRole("tab", { name: "Contacts", exact: true });
  await expect(contactsTab).toBeVisible({ timeout: 30000 });
  await contactsTab.click();
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

async function closeWizard(page) {
  await page.locator("#floatPlanWizardModal .btn-close").click();
  await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
}

async function waitForWizardOpen(page, timeout) {
  await page.waitForFunction(() => {
    const modal = document.querySelector("#floatPlanWizardModal");
    if (!modal) {
      return false;
    }
    return modal.classList.contains("show") && modal.getAttribute("aria-hidden") !== "true";
  }, { timeout: timeout || 30000 });
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: timeout || 30000 });
}

async function openPlanForEdit(page, floatPlanId) {
  const editButton = page.locator(currentGroupActionSelector(floatPlanId, "edit"));
  await expect(editButton).toBeVisible({ timeout: 30000 });
  for (let attempt = 0; attempt < 2; attempt += 1) {
    await editButton.evaluate((node) => {
      node.scrollIntoView({ block: "center", inline: "nearest" });
    });
    await editButton.click();
    try {
      await waitForWizardOpen(page, 5000);
      return;
    } catch (error) {
      if (attempt === 1) {
        throw error;
      }
    }
  }
}

async function deleteDraftGroup(page, routeCode) {
  const deletePayload = await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
    routeCode
  });
  expect(deletePayload.SUCCESS).toBe(true);
}

async function createSupportVessel(page, prefix) {
  const vesselName = `${prefix} Manual Vessel`;
  const response = await postSetupJson(page, "/fpw/api/v1/vessel.cfc?method=handle", {
    action: "save",
    VESSEL: {
      VESSELNAME: vesselName,
      TYPE: "Cruiser",
      LENGTH: "36",
      COLOR: "White",
      REGISTRATION: "FL-MANUAL-01",
      HOMEPORT: "Tarpon Springs",
      MAX_SPEED: "24",
      MOST_EFFICIENT_SPEED: "15",
      GPH: "5",
      GPH_AT_MAX_SPEED: "9",
      FUEL_CAPACITY: "220",
      MAKE: "Carver",
      MODEL: "Voyager"
    }
  });
  const vesselId = Number(response.VESSELID || 0);
  trackId(sharedState, "vesselIds", vesselId);
  return { vesselId, vesselName };
}

async function createSupportOperator(page, prefix) {
  const operatorName = `${prefix} Manual Operator`;
  const response = await postSetupJson(page, "/fpw/api/v1/operator.cfc?method=handle", {
    action: "save",
    OPERATOR: {
      OPERATORNAME: operatorName,
      PHONE: "5555556060",
      NOTES: "Manual timezone operator"
    }
  });
  const operatorId = Number(response.OPERATORID || 0);
  trackId(sharedState, "operatorIds", operatorId);
  return { operatorId, operatorName };
}

async function createSupportContact(page, prefix) {
  const contactName = `AAA ${prefix} Manual Contact`;
  const contactEmail = buildTraceEmail(prefix, "manual-contact");
  const response = await postSetupJson(page, "/fpw/api/v1/contact.cfc?method=handle", {
    action: "save",
    CONTACT: {
      CONTACTNAME: contactName,
      PHONE: "5555557070",
      EMAIL: contactEmail
    }
  });
  const contactId = Number(response.CONTACTID || 0);
  trackId(sharedState, "contactIds", contactId);
  return { contactId, contactName, contactEmail };
}

async function createSupportPassenger(page, prefix) {
  const passengerName = `AAA ${prefix} Manual Passenger`;
  const response = await postSetupJson(page, "/fpw/api/v1/passenger.cfc?method=handle", {
    action: "save",
    PASSENGER: {
      PASSENGERNAME: passengerName,
      PHONE: "5555558080",
      AGE: "41",
      GENDER: "Female",
      NOTES: "Manual timezone passenger"
    }
  });
  const passengerId = Number(response.PASSENGERID || 0);
  trackId(sharedState, "passengerIds", passengerId);
  return { passengerId, passengerName };
}

async function createSupportWaypoint(page, prefix) {
  const waypointName = `${prefix} Manual Waypoint`;
  const response = await postSetupJson(page, "/fpw/api/v1/waypoint.cfc?method=handle", {
    action: "save",
    WAYPOINT: {
      WAYPOINTNAME: waypointName,
      LATITUDE: "27.950575",
      LONGITUDE: "-82.457178",
      NOTES: "Manual timezone waypoint"
    }
  });
  const waypointId = Number(response.WAYPOINTID || 0);
  trackId(sharedState, "waypointIds", waypointId);
  return { waypointId, waypointName };
}

async function ensureSupportData(page, prefix) {
  if (sharedSupport) {
    return sharedSupport;
  }
  sharedSupport = {
    ...(await createSupportVessel(page, prefix)),
    ...(await createSupportOperator(page, prefix)),
    ...(await createSupportContact(page, prefix)),
    ...(await createSupportPassenger(page, prefix)),
    ...(await createSupportWaypoint(page, prefix))
  };
  return sharedSupport;
}

async function createDraftFloatPlan(page, support, options) {
  const buildPayload = await buildFloatPlansFromFirstRoute(page);
  for (const floatPlanId of buildPayload.floatPlanIds) {
    trackId(sharedState, "floatPlanIds", floatPlanId);
  }
  if (buildPayload.createdTemporaryRoute && buildPayload.routeCode) {
    trackValue(sharedState, "routeCodes", buildPayload.routeCode);
  }
  const routeDraftId = Number(buildPayload.floatPlanIds[0] || 0);
  expect(routeDraftId).toBeGreaterThan(0);
  await openPlanForEdit(page, routeDraftId);

  await page.fill('[name="NAME"]', options.planName);
  await selectOptionContainingText(page, '[name="VESSELID"]', support.vesselName);
  await selectOptionContainingText(page, '[name="OPERATORID"]', support.operatorName);
  await clickWizardNext(page);

  await expect(page.locator("#departingFrom")).toBeVisible({ timeout: 30000 });
  await page.fill("#departingFrom", options.departingFrom);
  await page.fill("#returningTo", options.returningTo);
  await page.fill('[name="DEPARTURE_TIME"]', options.departureTime);
  await page.fill('[name="RETURN_TIME"]', options.returnTime);
  await page.selectOption("#departureTimezone", options.departureTimezone);
  await page.selectOption("#returnTimezone", options.returnTimezone);
  await clickWizardNext(page);

  await expect(page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]')).toBeVisible({ timeout: 30000 });
  await page.fill('#floatPlanWizardModal input[type="email"]', support.contactEmail);
  await selectFirstRescueAuthority(page);
  if (options.notes) {
    await page.locator("#floatPlanWizardModal section:visible textarea.form-control").fill(options.notes);
  }
  await clickWizardNext(page);

  await expect(page.locator('input[placeholder="Search passengers..."]')).toBeVisible({ timeout: 30000 });
  await page.fill('input[placeholder="Search passengers..."]', "AAA");
  await page.getByRole("button", { name: support.passengerName, exact: false }).click();
  await clickManifestContactsTab(page);
  await page.fill('input[placeholder="Search contacts..."]', "AAA");
  await page.getByRole("button", { name: support.contactName, exact: false }).click();
  await clickWizardNext(page);

  await expect(page.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('input[placeholder="Search waypoints..."]')).toHaveCount(0);
  await expect(page.locator(".fpw-manifest--waypoints")).toContainText("In Route");
  await clickWizardNext(page);
  await expect(page.getByRole("button", { name: "Save Float Plan", exact: true })).toBeVisible({ timeout: 30000 });

  const savePayload = await waitForApi(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"save"', async () => {
    await page.getByRole("button", { name: "Save Float Plan", exact: true }).click();
  });
  const floatPlanId = Number(savePayload.FLOATPLAN.FLOATPLANID || savePayload.FLOATPLANID || 0);
  expect(floatPlanId).toBe(routeDraftId);
  trackValue(sharedState, "pdfPrefixes", options.planName.replace(/[^A-Za-z0-9_-]+/g, "_"));
  await closeWizard(page);
  await expect(page.locator(currentGroupActionSelector(floatPlanId, "edit"))).toBeVisible({ timeout: 30000 });

  return {
    floatPlanId,
    planName: options.planName,
    routeCode: buildPayload.routeCode
  };
}

async function assertPlanPersistence(page, planRef, expected) {
  const bootstrap = await postJson(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
    action: "bootstrap",
    floatPlanId: planRef.floatPlanId
  });
  const floatPlan = bootstrap.FLOATPLAN || {};
  expect(String(floatPlan.NAME || "")).toBe(planRef.planName);
  expect(String(floatPlan.DEPARTING_FROM || "")).toBe(expected.departingFrom);
  expect(String(floatPlan.RETURNING_TO || "")).toBe(expected.returningTo);
  expect(String(floatPlan.DEPARTURE_TIMEZONE || "")).toBe(expected.departureTimezone);
  expect(String(floatPlan.RETURN_TIMEZONE || "")).toBe(expected.returnTimezone);
}

test.afterAll(async ({ browser }) => {
  if (!sharedSupport) {
    return;
  }
  const page = await browser.newPage();
  await loginApprovedUser(page);
  await cleanupTrackedData(page, sharedState);
  await page.close();
});

test("manual float plans save and reload across the approved timezone matrix", async ({ page }, testInfo) => {
  const consoleErrors = attachConsoleErrorCollector(page);
  const prefix = buildTracePrefix(testInfo, "floatplans-manual-timezones", "persist-reload-matrix");
  await loginApprovedUser(page);
  await cleanupCurrentRouteFloatPlanGroup(page);
  const support = await ensureSupportData(page, prefix);

  const scenarios = [
    {
      key: "eastern",
      planName: `${prefix} Eastern Day Cruise`,
      departingFrom: "Tarpon Springs",
      returningTo: "Tarpon Springs",
      departureTime: buildDateTimeLocal(1, 9),
      returnTime: buildDateTimeLocal(1, 17),
      departureTimezone: "US/Eastern",
      returnTimezone: "US/Eastern",
      notes: "Short local day cruise"
    },
    {
      key: "central",
      planName: `${prefix} Central Multi Day`,
      departingFrom: "New Orleans",
      returningTo: "Mobile",
      departureTime: buildDateTimeLocal(2, 8),
      returnTime: buildDateTimeLocal(4, 18),
      departureTimezone: "US/Central",
      returnTimezone: "US/Central",
      notes: "Multi-day route"
    },
    {
      key: "pacific",
      planName: `${prefix} Pacific Route`,
      departingFrom: "San Diego",
      returningTo: "Long Beach",
      departureTime: buildDateTimeLocal(5, 7),
      returnTime: buildDateTimeLocal(6, 16),
      departureTimezone: "US/Pacific",
      returnTimezone: "US/Pacific",
      notes: "Pacific persistence"
    },
    {
      key: "alaska",
      planName: `${prefix} Alaska Route`,
      departingFrom: "Juneau",
      returningTo: "Sitka",
      departureTime: buildDateTimeLocal(7, 10),
      returnTime: buildDateTimeLocal(8, 15),
      departureTimezone: "US/Alaska",
      returnTimezone: "US/Alaska",
      notes: "Alaska persistence"
    },
    {
      key: "hawaii",
      planName: `${prefix} Hawaii Route`,
      departingFrom: "Honolulu",
      returningTo: "Maui",
      departureTime: buildDateTimeLocal(9, 8),
      returnTime: buildDateTimeLocal(10, 14),
      departureTimezone: "US/Hawaii",
      returnTimezone: "US/Hawaii",
      notes: "Hawaii persistence"
    },
    {
      key: "puerto-rico",
      planName: `${prefix} Puerto Rico Route`,
      departingFrom: "San Juan",
      returningTo: "Ponce",
      departureTime: buildDateTimeLocal(11, 9),
      returnTime: buildDateTimeLocal(12, 13),
      departureTimezone: "America/Puerto_Rico",
      returnTimezone: "America/Puerto_Rico",
      notes: "Puerto Rico persistence"
    }
  ];

  for (const scenario of scenarios) {
    const planRef = await createDraftFloatPlan(page, support, scenario);
    await assertPlanPersistence(page, planRef, scenario);
    await deleteDraftGroup(page, planRef.routeCode);
    sharedState.floatPlanIds = sharedState.floatPlanIds.filter((id) => id !== planRef.floatPlanId);
    sharedState.routeCodes = sharedState.routeCodes.filter((code) => code !== planRef.routeCode);
  }

  await assertNoConsoleErrors(consoleErrors);
});
