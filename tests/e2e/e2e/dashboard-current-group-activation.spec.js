require("./test-hooks");

const { test, expect } = require("@playwright/test");
const {
  cleanupTrackedData,
  createCleanupState,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const {
  buildFloatPlansFromFirstRoute,
  createDedicatedRouteForFloatPlans,
  currentGroupActionSelector,
  currentGroupRowSelector,
  loginApprovedUser
} = require("../support/fpwSession");

test.describe.configure({ timeout: 120000 });

function requestBodyMatches(requestBody, bodyPart) {
  if (!bodyPart) {
    return true;
  }
  if (!requestBody) {
    return false;
  }
  if (requestBody.includes(bodyPart)) {
    return true;
  }
  const pairMatch = /"([^"]+)"\s*:\s*"([^"]*)"/.exec(bodyPart);
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

async function clickWizardNext(modal, page) {
  const nextButton = page.getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await expect(nextButton).toBeVisible({ timeout: 30000 });
  await nextButton.click();
}

async function confirmModalOk(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.click("#confirmModalOk");
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

async function refreshRoutesFromDashboard(page) {
  await page.evaluate(() => {
    document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated", {
      detail: {
        routeCode: "",
        routeInstanceId: 0,
        createdCount: 0
      }
    }));
  });
}

async function createSupportVessel(page, state, suffix) {
  const vesselName = `PW Active Vessel ${suffix}`;
  const response = await waitForApi(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addVesselBtn");
    await expect(page.locator("#vesselModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#vesselName", vesselName);
    await page.fill("#vesselType", "Center Console");
    await page.fill("#vesselLength", "28");
    await page.fill("#vesselColor", "White");
    await page.fill("#vesselMaxSpeed", "28");
    await page.fill("#vesselMostEfficientSpeed", "18");
    await page.fill("#vesselGallonsPerHour", "6");
    await page.fill("#vesselGphAtMaxSpeed", "10");
    await page.fill("#vesselFuelCapacity", "280");
    await page.fill("#vesselMake", "Nordic");
    await page.fill("#vesselModel", "Pilot");
    await page.click("#saveVesselBtn");
  });
  trackId(state, "vesselIds", Number(response.VESSELID || 0));
  return { vesselName };
}

async function createSupportOperator(page, state, suffix) {
  const operatorName = `PW Active Operator ${suffix}`;
  const response = await waitForApi(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addOperatorBtn");
    await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#operatorName", operatorName);
    await page.fill("#operatorPhone", "5555556262");
    await page.click("#saveOperatorBtn");
  });
  trackId(state, "operatorIds", Number(response.OPERATORID || 0));
  return { operatorName };
}

async function createSupportContact(page, state, suffix) {
  const contactName = `AAA PW Active Contact ${suffix}`;
  const contactEmail = `pw-active-contact-${suffix}@example.com`;
  const response = await waitForApi(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addContactBtn");
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactName", contactName);
    await page.fill("#contactPhone", "5555551212");
    await page.fill("#contactEmail", contactEmail);
    await page.click("#saveContactBtn");
  });
  trackId(state, "contactIds", Number(response.CONTACTID || 0));
  return { contactName };
}

async function fillAndSendFloatPlan(page, planId, planName, support) {
  await page.locator(currentGroupActionSelector(planId, "edit")).click();
  const modal = page.locator("#floatPlanWizardModal");
  await expect(modal).toBeVisible({ timeout: 20000 });

  await modal.locator('[name="NAME"]').fill(planName);
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const vessel = root.querySelector('[name="VESSELID"]');
    const operator = root.querySelector('[name="OPERATORID"]');
    return !!vessel && !!operator && vessel.options.length > 1 && operator.options.length > 1;
  }, { timeout: 30000 });
  await selectOptionContainingText(page, '[name="VESSELID"]', support.vesselName);
  await selectOptionContainingText(page, '[name="OPERATORID"]', support.operatorName);
  await clickWizardNext(modal, page);

  await modal.locator('[name="DEPARTING_FROM"]').fill("Test Marina");
  await modal.locator('[name="DEPARTURE_TIME"]').fill("2027-01-01T08:00");
  await modal.locator('[name="DEPARTURE_TIMEZONE"]').selectOption({ index: 1 });
  await modal.locator('[name="RETURNING_TO"]').fill("Test Marina");
  await modal.locator('[name="RETURN_TIME"]').fill("2027-01-01T18:00");
  await modal.locator('[name="RETURN_TIMEZONE"]').selectOption({ index: 1 });
  await clickWizardNext(modal, page);

  await modal.locator('input[type="email"]').fill(process.env.FPW_EMAIL || "");
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const rescue = root.querySelector('[name="RESCUE_AUTHORITY_SELECTION"]');
    return !!rescue && rescue.options.length > 1;
  }, { timeout: 30000 });
  await modal.locator('[name="RESCUE_AUTHORITY_SELECTION"]').selectOption({ index: 1 });
  await clickWizardNext(modal, page);

  await expect(modal.locator('input[placeholder="Search passengers..."]')).toBeVisible({ timeout: 30000 });
  await page.getByRole("tab", { name: "Contacts", exact: true }).click();
  await modal.locator('input[placeholder="Search contacts..."]').fill(support.contactName);
  const firstContactButton = modal.getByRole("button", { name: support.contactName, exact: false }).first();
  await expect(firstContactButton).toBeVisible({ timeout: 30000 });
  await firstContactButton.click();
  await expect(firstContactButton).toHaveAttribute("aria-pressed", "true", { timeout: 10000 });
  await clickWizardNext(modal, page);
  await expect(page.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible({ timeout: 30000 });
  await clickWizardNext(modal, page);
  const saveAndSendButton = modal.getByRole("button", { name: "Save & Send", exact: true });
  await expect(saveAndSendButton).toBeVisible({ timeout: 30000 });

  const sendPayload = await waitForApi(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"send"', async () => {
    await saveAndSendButton.click();
  });
  expect(sendPayload.SUCCESS).toBe(true);
  await expect(modal.locator(".wizard-alert.alert-success")).toContainText(/Float plan sent to/i, { timeout: 30000 });
  await modal.locator(".btn-close").click();
  await expect(modal).toBeHidden({ timeout: 15000 });
}

test("Routes panel keeps the current active group on the route row and requires cancel before delete", async ({ page }) => {
  const state = createCleanupState();
  const suffix = Date.now();

  await loginApprovedUser(page);

  try {
    const support = {
      ...(await createSupportVessel(page, state, suffix)),
      ...(await createSupportOperator(page, state, suffix)),
      ...(await createSupportContact(page, state, suffix))
    };
    const built = await buildFloatPlansFromFirstRoute(page);
    const planId = built.floatPlanIds[0] || 0;
    expect(planId).toBeGreaterThan(0);
    trackId(state, "floatPlanIds", planId);
    if (built.createdTemporaryRoute && built.routeCode) {
      trackValue(state, "routeCodes", built.routeCode);
    }

    await fillAndSendFloatPlan(page, planId, `Playwright Active Group ${suffix}`, support);

    const activeGroupRow = page.locator(currentGroupRowSelector(planId));
    await expect(activeGroupRow).toBeVisible({ timeout: 20000 });
    await expect(activeGroupRow).toContainText(/Active Float Plan/i);
    await expect(activeGroupRow.locator('[data-action="cancel"]')).toBeVisible();
    await expect(activeGroupRow.locator('[data-action="checkin"]')).toBeVisible();
    await expect(activeGroupRow.locator('[data-action="delete"]')).toHaveCount(0);

    const routeCard = page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"]`).first();
    const activeCruisePopupPromise = page.waitForEvent("popup");
    await routeCard.locator(".js-expedition-active-cruise").click();
    const activeCruisePage = await activeCruisePopupPromise;
    await activeCruisePage.waitForLoadState("domcontentloaded");
    await expect(activeCruisePage).toHaveURL(/\/fpw\/app\/active-cruise\.cfm/i, { timeout: 30000 });
    await expect(activeCruisePage.locator("body")).not.toContainText("No active trip is available for this account.", { timeout: 30000 });
    await expect(activeCruisePage.locator('[data-fpw-field="floatPlan.id"]')).toContainText(String(planId), { timeout: 30000 });
    await activeCruisePage.close();

    const ownerEnsureResponsePromise = page.waitForResponse((response) => {
      return response.request().method() === "GET"
        && response.url().includes("/fpw/api/v1/voyage.cfc?method=handle&action=ownerEnsureStream");
    }, { timeout: 30000 });
    const tripPagePopupPromise = page.waitForEvent("popup");
    await routeCard.locator(".js-expedition-trip-page").click();
    const tripPage = await tripPagePopupPromise;
    const ownerEnsurePayload = await (await ownerEnsureResponsePromise).json();
    const ownerEnsureSuccess = ownerEnsurePayload.SUCCESS === true || ownerEnsurePayload.success === true;
    const ownerEnsureData = ownerEnsurePayload.data && typeof ownerEnsurePayload.data === "object"
      ? ownerEnsurePayload.data
      : (ownerEnsurePayload.DATA && typeof ownerEnsurePayload.DATA === "object" ? ownerEnsurePayload.DATA : {});
    const ownerEnsureFollow = ownerEnsureData.follow && typeof ownerEnsureData.follow === "object"
      ? ownerEnsureData.follow
      : {};
    expect(ownerEnsureSuccess).toBe(true);
    expect(String(ownerEnsureFollow.url || ownerEnsureFollow.path || "")).toContain("/fpw/app/follow.cfm");
    await expect(tripPage).toHaveURL(/\/fpw\/app\/follow\.cfm\?slug=/i, { timeout: 30000 });
    await expect(tripPage.locator("#followLoaderPhase")).toContainText(/Follow Page Loading|Finalizing Display/, { timeout: 30000 });
    await tripPage.close();

    const secondaryRoute = await createDedicatedRouteForFloatPlans(page);
    trackValue(state, "routeCodes", secondaryRoute.routeCode);
    await refreshRoutesFromDashboard(page);
    const secondaryActivateButton = page.locator(`.expedition-route-card[data-route-code="${secondaryRoute.routeCode}"] .js-expedition-build-floatplans`).first();
    await expect(secondaryActivateButton).toBeVisible({ timeout: 20000 });
    await secondaryActivateButton.click();
    await expect(page.locator("#alertModal")).toBeVisible({ timeout: 15000 });
    await expect(page.locator("#alertModalMessage")).toContainText("Another route already has the current route/float-plan group.");
    await page.locator("#alertModal .btn-close, #alertModal .btn-primary, #alertModal .btn-secondary").first().click().catch(() => {});
    await page.keyboard.press("Escape").catch(() => {});

    await page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"] .js-expedition-delete`).click();
    await expect(page.locator("#alertModal")).toBeVisible({ timeout: 15000 });
    await expect(page.locator("#alertModalMessage")).toContainText("Use Check-In or Cancel before deleting the route.");
    await page.locator("#alertModal .btn-close, #alertModal .btn-primary, #alertModal .btn-secondary").first().click().catch(() => {});
    await page.keyboard.press("Escape").catch(() => {});

    await page.locator(currentGroupActionSelector(planId, "cancel")).click();
    await confirmModalOk(page);
    await expect(page.locator(currentGroupRowSelector(planId))).toHaveCount(0, { timeout: 30000 });
    await expect(page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"]`)).toHaveCount(1, { timeout: 30000 });

    await page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"] .js-expedition-delete`).click();
    await confirmModalOk(page);
    await expect(page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"]`)).toHaveCount(0, { timeout: 30000 });
    state.floatPlanIds = [];
    state.routeCodes = [];
  } finally {
    await cleanupTrackedData(page, state).catch(() => {});
  }
});
