const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupTrackedData,
  createCleanupState,
  postJson,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const { buildTraceEmail, buildTracePrefix } = require("../support/fpwNames");
const {
  buildFloatPlansFromRoute: requestBuildFloatPlansFromRoute,
  currentGroupActionSelector,
  loginApprovedUser,
  openRouteBuilder
} = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

const TEMPLATE_CODE = "GULF-CORE";
const TEMPLATE_NAME = "Gulf Coast (Core) — Mobile to Tarpon Springs";
const sharedState = createCleanupState();
let sharedSupport = null;
const OVERRIDE_POINTS = [
  { lat: 30.23042, lon: -87.93513 },
  { lat: 30.11864, lon: -87.7421 },
  { lat: 29.98012, lon: -87.51422 }
];

function buildRouteStartDate(daysFromNow) {
  const value = new Date();
  value.setDate(value.getDate() + daysFromNow);
  return value.toISOString().slice(0, 10);
}

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

async function openModal(page, openSelector, modalSelector) {
  const modal = page.locator(modalSelector);
  await page.click(openSelector);
  const openedByClick = await modal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!openedByClick) {
    await page.evaluate(([buttonSelector, targetSelector]) => {
      const openBtn = document.querySelector(buttonSelector);
      if (openBtn) {
        openBtn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      }
      const modalEl = document.querySelector(targetSelector);
      if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) {
        return;
      }
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }, [openSelector, modalSelector]);
  }
  await expect(modal).toBeVisible({ timeout: 30000 });
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

async function selectFirstRescueAuthority(page) {
  const selector = page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]');
  const options = await selector.locator("option").evaluateAll((nodes) => {
    return nodes
      .map((node) => ({ value: node.value }))
      .filter((item) => item.value && item.value !== "0");
  });
  await selector.selectOption(options[0].value);
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

async function closeWizard(page) {
  await page.locator("#floatPlanWizardModal .btn-close").click();
  await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
}

async function createSupportVessel(page, prefix) {
  const vesselName = `${prefix} Gulf Core Vessel`;
  const response = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
    await openModal(page, "#addVesselBtn", "#vesselModal");
    await page.fill("#vesselName", vesselName);
    await page.fill("#vesselType", "Motor Yacht");
    await page.fill("#vesselLength", "41");
    await page.fill("#vesselColor", "White");
    await page.click("#saveVesselBtn");
  });
  const vesselId = Number(response.VESSELID || 0);
  trackId(sharedState, "vesselIds", vesselId);
  return { vesselId, vesselName };
}

async function createSupportOperator(page, prefix) {
  const operatorName = `${prefix} Gulf Core Operator`;
  const response = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await openModal(page, "#addOperatorBtn", "#operatorModal");
    await page.fill("#operatorName", operatorName);
    await page.fill("#operatorPhone", "5555556161");
    await page.click("#saveOperatorBtn");
  });
  const operatorId = Number(response.OPERATORID || 0);
  trackId(sharedState, "operatorIds", operatorId);
  return { operatorId, operatorName };
}

async function createSupportContact(page, prefix) {
  const contactName = `AAA ${prefix} Gulf Core Contact`;
  const contactEmail = buildTraceEmail(prefix, "gulf-core-contact");
  const response = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await openModal(page, "#addContactBtn", "#contactModal");
    await page.fill("#contactName", contactName);
    await page.fill("#contactPhone", "5555556262");
    await page.fill("#contactEmail", contactEmail);
    await page.click("#saveContactBtn");
  });
  const contactId = Number(response.CONTACTID || 0);
  trackId(sharedState, "contactIds", contactId);
  return { contactId, contactName, contactEmail };
}

async function ensureSupportData(page, prefix) {
  if (sharedSupport) {
    return sharedSupport;
  }
  sharedSupport = {
    ...(await createSupportVessel(page, prefix)),
    ...(await createSupportOperator(page, prefix)),
    ...(await createSupportContact(page, prefix))
  };
  return sharedSupport;
}

async function setDirection(page, direction) {
  const toggle = page.locator("#routeGenDirectionToggle");
  const directionInput = page.locator("#routeGenDirection");
  await page.waitForFunction(() => {
    const input = document.querySelector("#routeGenDirection");
    return !!(input && input.value);
  }, { timeout: 30000 });
  if ((await directionInput.inputValue()) === direction) {
    return;
  }
  await expect(toggle).toBeEnabled({ timeout: 30000 });
  const desiredChecked = direction === "CW";
  if ((await toggle.isChecked()) !== desiredChecked) {
    await toggle.click();
  }
  await expect(directionInput).toHaveValue(direction);
}

async function waitForPreviewReady(page) {
  await expect(page.locator("#routeGenLegList .fpw-routegen__leg").first()).toBeVisible({ timeout: 30000 });
}

async function closeRouteBuilderModal(page) {
  const modal = page.locator("#routeBuilderModal");
  if (await modal.isVisible().catch(() => false)) {
    await expect(page.locator("#routeGenCancelBtn")).toBeVisible({ timeout: 15000 });
    await page.click("#routeGenCancelBtn");
  }
  await expect(modal).toBeHidden({ timeout: 30000 });
}

async function ensureRouteName(page, value) {
  const input = page.locator("#routeGenRouteName");
  await expect(input).toBeVisible({ timeout: 15000 });
  if (!String(await input.inputValue()).trim()) {
    await input.fill(value);
  }
}

async function configureTemplatePreview(page, direction, expectedStart, expectedEnd) {
  const optionsPayload = await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_getoptions", {
    template_code: TEMPLATE_CODE,
    direction
  });
  const initialOptionsPayload = direction === "CCW" ? optionsPayload : await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_getoptions", {
    template_code: TEMPLATE_CODE,
    direction: "CCW"
  });
  expect(optionsPayload.SUCCESS).toBe(true);
  expect(initialOptionsPayload.SUCCESS).toBe(true);
  expect(optionsPayload.DATA.template.code).toBe(TEMPLATE_CODE);
  expect(optionsPayload.DATA.direction).toBe(direction);
  expect(Array.isArray(optionsPayload.DATA.optionalStops)).toBe(true);
  expect(optionsPayload.DATA.optionalStops.length).toBe(0);

  await openRouteBuilder(page);
  await page.selectOption("#routeGenTemplateSelect", TEMPLATE_CODE);
  await page.fill("#routeGenStartDate", buildRouteStartDate(10));
  await selectOptionContainingText(page, "#routeGenStartLocation", initialOptionsPayload.DATA.startOptions[0].label);
  await selectOptionContainingText(page, "#routeGenEndLocation", initialOptionsPayload.DATA.endOptions[initialOptionsPayload.DATA.endOptions.length - 1].label);
  if (direction !== "CCW") {
    await setDirection(page, direction);
  }
  await selectOptionContainingText(page, "#routeGenStartLocation", expectedStart);
  await selectOptionContainingText(page, "#routeGenEndLocation", expectedEnd);
  await expect(page.locator("[data-stop-code]")).toHaveCount(0);
  await expect(page.locator("#routeGenDirection")).toHaveValue(direction);
  await waitForPreviewReady(page);
}

async function generateTemplateRoute(page, direction) {
  await ensureRouteName(page, TEMPLATE_CODE + " " + direction + " " + Date.now());
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_generate", `"template_code":"${TEMPLATE_CODE}"`, async () => {
    await page.click("#routeGenGenerateBtn");
  });
  expect(payload.SUCCESS).toBe(true);
  const routeCode = String(payload.ROUTE_CODE || payload.DATA.route_code || "").trim();
  expect(routeCode).not.toBe("");
  trackValue(sharedState, "routeCodes", routeCode);
  await closeRouteBuilderModal(page);
  await expect(page.locator(`[data-route-code="${routeCode}"]`)).toBeVisible({ timeout: 30000 });
  return routeCode;
}

async function openGeneratedRouteEditor(page, routeCode) {
  const routeCard = page.locator(`[data-route-code="${routeCode}"]`);
  const routeName = String(await routeCard.locator(".expedition-route-name").textContent() || "").trim();
  await routeCard.locator(".js-expedition-view-edit").click();
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#routeGenRouteName")).toHaveValue(routeName, { timeout: 30000 });
  await expect(page.locator("#routeGenRouteCode")).toContainText(routeCode, { timeout: 30000 });
}

async function saveAndClearOverride(page) {
  const openMapButton = page.locator('#routeGenLegList [data-leg-action="open-map"]').first();
  await expect(openMapButton).toBeVisible({ timeout: 30000 });
  await openMapButton.click();
  try {
    await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  } catch (error) {
    await openMapButton.click();
    await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 30000 });
  }
  await page.waitForFunction(() => {
    return !!window.FPW?.DashboardModules?.routeBuilder?.test?.isReady?.();
  }, { timeout: 30000 });
  await page.waitForFunction(() => {
    const snapshot = window.FPW?.DashboardModules?.routeBuilder?.test?.snapshot?.();
    return !!snapshot && !String(snapshot.status || "").includes("Loading geometry");
  }, { timeout: 30000 });
  const geometryReady = await page.evaluate((points) => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(points);
  }, OVERRIDE_POINTS);
  expect(geometryReady).toBe(true);
  await expect(page.locator("#routeGenLegMapStatus")).toContainText("Test geometry loaded.", { timeout: 30000 });

  const savePayload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_savelegoverride", '"route_code"', async () => {
    await page.click("#routeGenLegSaveBtn");
  });
  expect(savePayload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenLegMapSource")).toContainText("user override", { timeout: 30000 });

  const clearPayload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_clearlegoverride", '"route_code"', async () => {
    await page.click("#routeGenLegRevertBtn");
  });
  expect(clearPayload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenLegMapSource")).toContainText("default", { timeout: 30000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegMapPanel")).not.toHaveClass(/is-open/, { timeout: 30000 });
}

async function saveRouteUpdate(page) {
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_update", '"route_code"', async () => {
    await page.click("#routeGenSaveBtn");
  });
  expect(payload.SUCCESS).toBe(true);
}

async function buildFloatPlansFromRoute(page, routeCode) {
  const built = await requestBuildFloatPlansFromRoute(page, routeCode);
  const payload = built && built.payload ? built.payload : {};
  if ((!Array.isArray(payload.FLOATPLAN_IDS) || !payload.FLOATPLAN_IDS.length) && Array.isArray(built && built.floatPlanIds)) {
    payload.FLOATPLAN_IDS = built.floatPlanIds.slice();
  }
  expect(payload.SUCCESS).toBe(true);
  expect(Number(payload.CREATED_COUNT || 0)).toBeGreaterThan(0);
  for (const floatPlanId of payload.FLOATPLAN_IDS || []) {
    trackId(sharedState, "floatPlanIds", floatPlanId);
  }
  return payload;
}

async function saveRouteDerivedFloatPlan(page, support, floatPlanId, timezone, dayOffset) {
  const wizardModal = page.locator("#floatPlanWizardModal");
  if (await page.locator(".modal-backdrop.show").count()) {
    await expect(wizardModal).toBeVisible({ timeout: 30000 });
  } else {
    await page.locator(currentGroupActionSelector(floatPlanId, "edit")).click();
  }
  await expect(wizardModal).toBeVisible({ timeout: 30000 });
  const planName = await page.inputValue('[name="NAME"]');
  trackValue(sharedState, "pdfPrefixes", planName.replace(/[^A-Za-z0-9_-]+/g, "_"));
  await selectOptionContainingText(page, '[name="VESSELID"]', support.vesselName);
  await selectOptionContainingText(page, '[name="OPERATORID"]', support.operatorName);
  await clickWizardNext(page);
  if (!(await page.inputValue("#departingFrom")).trim()) {
    await page.fill("#departingFrom", "Mobile");
  }
  if (!(await page.inputValue("#returningTo")).trim()) {
    await page.fill("#returningTo", "Tarpon Springs");
  }
  await page.fill('[name="DEPARTURE_TIME"]', buildDateTimeLocal(dayOffset, 8));
  await page.fill('[name="RETURN_TIME"]', buildDateTimeLocal(dayOffset + 1, 17));
  await page.selectOption("#departureTimezone", timezone);
  await page.selectOption("#returnTimezone", timezone);
  await clickWizardNext(page);
  await page.fill('#floatPlanWizardModal input[type="email"]', support.contactEmail);
  await selectFirstRescueAuthority(page);
  await clickWizardNext(page);
  await clickManifestContactsTab(page);
  await page.getByRole("button", { name: support.contactName, exact: false }).click();
  await clickWizardNext(page);
  await clickWizardNext(page);
  const savePayload = await waitForApi(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"save"', async () => {
    await page.getByRole("button", { name: "Save Float Plan", exact: true }).click();
  });
  expect(savePayload.SUCCESS).toBe(true);
  const bootstrap = await postJson(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
    action: "bootstrap",
    floatPlanId
  });
  const floatPlan = bootstrap.FLOATPLAN || {};
  expect(String(floatPlan.DEPARTURE_TIMEZONE || "")).toBe(timezone);
  expect(String(floatPlan.RETURN_TIMEZONE || "")).toBe(timezone);
  await closeWizard(page);
}

async function deleteRouteCard(page, routeCode) {
  const responsePromise = page.waitForResponse((response) => {
    return response.url().includes("/fpw/api/v1/routeBuilder.cfc?")
      && response.url().includes("action=deleteRoute")
      && response.url().includes(`routeCode=${encodeURIComponent(routeCode)}`)
      && response.request().method() === "GET";
  }, { timeout: 30000 });
  await page.locator(`[data-route-code="${routeCode}"] .js-expedition-delete`).click();
  await expect(page.locator("#confirmModal")).toBeVisible({ timeout: 30000 });
  await page.click("#confirmModalOk");
  const payload = await (await responsePromise).json();
  expect(payload.SUCCESS).toBe(true);
  sharedState.routeCodes = sharedState.routeCodes.filter((value) => value !== routeCode);
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

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });
});

test("GULF-CORE CCW generates, loads, saves, builds float plans, and applies US/Eastern route-derived persistence", async ({ page }, testInfo) => {
  const consoleErrors = attachConsoleErrorCollector(page);
  const prefix = buildTracePrefix(testInfo, "route-template-gulf-core", "ccw");
  await loginApprovedUser(page);
  const support = await ensureSupportData(page, prefix);

  await configureTemplatePreview(page, "CCW", "Mobile", "Tarpon Springs");
  const routeCode = await generateTemplateRoute(page, "CCW");
  await openGeneratedRouteEditor(page, routeCode);
  await saveRouteUpdate(page);
  await saveAndClearOverride(page);
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });

  const buildPayload = await buildFloatPlansFromRoute(page, routeCode);
  await saveRouteDerivedFloatPlan(page, support, Number(buildPayload.FLOATPLAN_IDS[0]), "US/Eastern", 20);
  await deleteRouteCard(page, routeCode);

  await assertNoConsoleErrors(consoleErrors);
});

test("GULF-CORE CW generates, loads, saves, builds float plans, and applies US/Central route-derived persistence", async ({ page }, testInfo) => {
  const consoleErrors = attachConsoleErrorCollector(page);
  const prefix = buildTracePrefix(testInfo, "route-template-gulf-core", "cw");
  await loginApprovedUser(page);
  const support = await ensureSupportData(page, prefix);

  await configureTemplatePreview(page, "CW", "Tarpon Springs", "Mobile");
  const routeCode = await generateTemplateRoute(page, "CW");
  await openGeneratedRouteEditor(page, routeCode);
  await saveAndClearOverride(page);
  await saveRouteUpdate(page);
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });

  const buildPayload = await buildFloatPlansFromRoute(page, routeCode);
  await saveRouteDerivedFloatPlan(page, support, Number(buildPayload.FLOATPLAN_IDS[0]), "US/Central", 24);
  await deleteRouteCard(page, routeCode);

  await assertNoConsoleErrors(consoleErrors);
});
