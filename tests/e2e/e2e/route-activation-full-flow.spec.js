require("./test-hooks");

const { test, expect } = require("@playwright/test");
const fs = require("fs/promises");

const {
  closeRouteBuilder,
  generateRoute,
  gotoDashboard,
  prepareGreatLoopPreview,
  saveRoute,
  snapshotPreviewLegs,
  waitForDashboardReady
} = require("../support/routebuilderHarness");
const {
  cleanupCurrentRouteFloatPlanGroup,
  cleanupTrackedData,
  createCleanupState,
  postJson,
  trackId,
  trackValue
} = require("../support/fpwCleanup");

test.describe.configure({ timeout: 300000 });

function buildUniqueEmail(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}@example.com`;
}

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

function parseRequestBody(request) {
  const raw = String(request.postData() || "");
  if (!raw) {
    return { raw, parsed: {} };
  }
  try {
    return { raw, parsed: JSON.parse(raw) };
  } catch (error) {
    const params = new URLSearchParams(raw);
    const parsed = {};
    for (const [key, value] of params.entries()) {
      parsed[key] = value;
    }
    return { raw, parsed };
  }
}

async function waitForApiExchange(page, urlPart, bodyPart, trigger) {
  const responsePromise = page.waitForResponse((response) => {
    if (!response.url().includes(urlPart)) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    return requestBodyMatches(response.request().postData() || "", bodyPart);
  }, { timeout: 30000 });
  await trigger();
  const response = await responsePromise;
  const request = response.request();
  let responsePayload = null;
  const responseText = await response.text().catch(() => "");

  try {
    responsePayload = responseText ? JSON.parse(responseText) : {};
  } catch (error) {
    responsePayload = null;
  }

  return {
    url: response.url(),
    status: response.status(),
    request: parseRequestBody(request),
    response: responsePayload,
    responseText
  };
}

async function selectOptionContainingText(page, selector, text) {
  await page.waitForFunction(([selectSelector, wanted]) => {
    const select = document.querySelector(selectSelector);
    if (!select) {
      return false;
    }
    return Array.from(select.options || []).some((option) => {
      return String(option.value || "").trim()
        && String(option.textContent || "").toLowerCase().includes(String(wanted || "").toLowerCase());
    });
  }, [selector, text], { timeout: 30000 });

  const value = await page.locator(selector).evaluate((select, wanted) => {
    const match = Array.from(select.options || []).find((option) => {
      return String(option.value || "").trim()
        && String(option.textContent || "").toLowerCase().includes(String(wanted || "").toLowerCase());
    });
    if (!match) {
      return "";
    }
    select.value = match.value;
    select.dispatchEvent(new Event("change", { bubbles: true }));
    return match.value;
  }, text);
  expect(value).not.toBe("");
  return value;
}

async function clickWizardNext(modal, page) {
  const nextButton = page.getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await expect(nextButton).toBeVisible({ timeout: 30000 });
  await nextButton.click();
  await expect(modal).toBeVisible({ timeout: 30000 });
}

function formatDateTimeLocal(dateValue) {
  const pad = (value) => String(value).padStart(2, "0");
  return [
    dateValue.getFullYear(),
    pad(dateValue.getMonth() + 1),
    pad(dateValue.getDate())
  ].join("-") + "T" + [
    pad(dateValue.getHours()),
    pad(dateValue.getMinutes())
  ].join(":");
}

function currentGroupRowSelector(planId) {
  return `.expedition-route-current-group[data-plan-id="${planId}"]`;
}

function currentGroupActionSelector(planId, action) {
  return `${currentGroupRowSelector(planId)} [data-action="${action}"]`;
}

function currentGroupRowLocator(page, planId) {
  return page.locator(currentGroupRowSelector(planId)).first();
}

function currentGroupActionLocator(page, planId, action) {
  return page.locator(currentGroupActionSelector(planId, action)).first();
}

function normalizeFloatPlanIds(payload) {
  let floatPlanIds = Array.isArray(payload?.FLOATPLAN_IDS)
    ? payload.FLOATPLAN_IDS.map((value) => Number(value || 0)).filter((value) => Number.isFinite(value) && value > 0)
    : [];

  if (!floatPlanIds.length && Array.isArray(payload?.FLOATPLANS)) {
    floatPlanIds = payload.FLOATPLANS
      .map((entry) => Number(entry?.FLOATPLAN_ID || entry?.FLOATPLANID || 0))
      .filter((value) => Number.isFinite(value) && value > 0);
  }

  return floatPlanIds;
}

function attachPageDiagnostics(page, diagnostics, label) {
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") {
      diagnostics.console.push({
        page: label,
        type: message.type(),
        text: message.text()
      });
    }
  });
  page.on("pageerror", (error) => {
    diagnostics.console.push({
      page: label,
      type: "pageerror",
      text: error.message
    });
  });
  page.on("requestfailed", (request) => {
    const url = request.url();
    if (url.includes("/fpw/")) {
      diagnostics.network.push({
        page: label,
        url,
        failure: request.failure()?.errorText || ""
      });
    }
  });
  page.on("response", (response) => {
    const url = response.url();
    if (url.includes("/fpw/api/") && response.status() >= 400) {
      diagnostics.network.push({
        page: label,
        url,
        status: response.status()
      });
    }
  });
  page.on("dialog", async (dialog) => {
    diagnostics.dialogs.push({
      page: label,
      type: dialog.type(),
      message: dialog.message()
    });
    await dialog.dismiss().catch(() => {});
  });
}

async function createDisposableUser(page) {
  const email = buildUniqueEmail("phase4o-route-flow");
  const password = "changeIt";
  const response = await page.context().request.post("/fpw/api/v1/join.cfc?method=handle&returnFormat=json", {
    data: {
      firstName: "Phase4O",
      lastName: "Disposable",
      email,
      password
    }
  });
  const payload = await response.json();
  expect(response.ok()).toBeTruthy();
  expect(payload.SUCCESS).toBe(true);

  const loginPayload = await postJson(page, "/fpw/api/v1/auth.cfc?method=handle&returnFormat=json", {
    action: "login",
    email,
    password
  });
  expect(loginPayload.SUCCESS).toBe(true);

  await gotoDashboard(page);
  return {
    email,
    userId: Number(payload.USERID || 0)
  };
}

async function createSupportVessel(page, state, suffix) {
  const vesselName = `PW Phase4O Vessel ${suffix}`;
  const exchange = await waitForApiExchange(page, "/fpw/api/v1/vessel.cfc?method=handle", '"action":"save"', async () => {
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
  expect(exchange.response?.SUCCESS).toBe(true);
  trackId(state, "vesselIds", Number(exchange.response?.VESSELID || 0));
  return { vesselName };
}

async function createSupportOperator(page, state, suffix) {
  const operatorName = `PW Phase4O Operator ${suffix}`;
  const exchange = await waitForApiExchange(page, "/fpw/api/v1/operator.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addOperatorBtn");
    await expect(page.locator("#operatorModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#operatorName", operatorName);
    await page.fill("#operatorPhone", "5555556262");
    await page.click("#saveOperatorBtn");
  });
  expect(exchange.response?.SUCCESS).toBe(true);
  trackId(state, "operatorIds", Number(exchange.response?.OPERATORID || 0));
  return { operatorName };
}

async function createSupportContact(page, state, suffix) {
  const contactName = `AAA PW Phase4O Contact ${suffix}`;
  const contactEmail = `pw-phase4o-contact-${suffix}@example.com`;
  const exchange = await waitForApiExchange(page, "/fpw/api/v1/contact.cfc?method=handle", '"action":"save"', async () => {
    await page.click("#addContactBtn");
    await expect(page.locator("#contactModal")).toBeVisible({ timeout: 30000 });
    await page.fill("#contactName", contactName);
    await page.fill("#contactPhone", "5555551212");
    await page.fill("#contactEmail", contactEmail);
    await page.click("#saveContactBtn");
  });
  expect(exchange.response?.SUCCESS).toBe(true);
  trackId(state, "contactIds", Number(exchange.response?.CONTACTID || 0));
  return { contactName };
}

async function createNewRouteThroughGenerator(page, state, suffix) {
  const routeName = `PW Phase4O Route ${suffix}`;
  const startDate = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

  await prepareGreatLoopPreview(page, {
    routeName,
    templateLabel: "great loop",
    direction: "CCW",
    startDate
  });

  const previewLegs = await snapshotPreviewLegs(page);
  expect(previewLegs.length).toBeGreaterThan(0);

  const generated = await generateRoute(page);
  const routeCode = generated.routeCode;
  trackValue(state, "routeCodes", routeCode);

  const saveButton = page.locator("#routeGenSaveBtn");
  let explicitSaveResult = { attempted: false, reason: "routegen_generate returned persisted route code" };
  if (await saveButton.isVisible().catch(() => false)) {
    const isEnabled = await saveButton.isEnabled().catch(() => false);
    if (isEnabled) {
      explicitSaveResult = {
        attempted: true,
        result: await saveRoute(page)
      };
    }
  }

  await closeRouteBuilder(page);
  await gotoDashboard(page);

  const routeCard = page.locator(`.expedition-route-card[data-route-code="${routeCode}"]`).first();
  await expect(routeCard).toBeVisible({ timeout: 30000 });
  const routeInstanceId = Number(await routeCard.getAttribute("data-route-instance-id") || 0);
  expect(routeInstanceId).toBeGreaterThan(0);

  return {
    routeName,
    routeCode,
    routeInstanceId,
    previewLegs,
    generatePayload: generated.payload,
    explicitSaveResult
  };
}

async function activateGeneratedRoute(page, routeCode) {
  const routeCard = page.locator(`.expedition-route-card[data-route-code="${routeCode}"]`).first();
  await expect(routeCard).toBeVisible({ timeout: 30000 });
  const activateButton = routeCard.locator(".js-expedition-build-floatplans").first();
  await expect(activateButton).toBeVisible({ timeout: 30000 });

  const exchange = await waitForApiExchange(
    page,
    "/fpw/api/v1/routeBuilder.cfc?method=handle&action=buildFloatPlansFromRoute",
    routeCode,
    async () => {
      await activateButton.click();
    }
  );
  expect(exchange.response?.SUCCESS).toBe(true);
  const floatPlanIds = normalizeFloatPlanIds(exchange.response || {});
  expect(floatPlanIds.length).toBeGreaterThan(0);

  const planId = floatPlanIds[0];
  await expect(currentGroupRowLocator(page, planId)).toBeVisible({ timeout: 30000 });

  return {
    exchange,
    floatPlanIds,
    planId,
    routeInstanceId: Number(exchange.response?.ROUTE_INSTANCE_ID || 0)
  };
}

async function fillAndSendFloatPlan(page, planId, planName, support, ownerEmail) {
  const modal = page.locator("#floatPlanWizardModal");
  const wizardAlreadyOpen = await modal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!wizardAlreadyOpen) {
    await currentGroupActionLocator(page, planId, "edit").click();
  }
  await expect(modal).toBeVisible({ timeout: 30000 });

  const departure = new Date(Date.now() + (2 * 60 * 60 * 1000));
  const returning = new Date(Date.now() + (10 * 60 * 60 * 1000));

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

  await modal.locator('[name="DEPARTING_FROM"]').fill("Phase4O Test Marina");
  await modal.locator('[name="DEPARTURE_TIME"]').fill(formatDateTimeLocal(departure));
  await selectOptionContainingText(page, '[name="DEPARTURE_TIMEZONE"]', "Eastern");
  await modal.locator('[name="RETURNING_TO"]').fill("Phase4O Test Marina");
  await modal.locator('[name="RETURN_TIME"]').fill(formatDateTimeLocal(returning));
  await selectOptionContainingText(page, '[name="RETURN_TIMEZONE"]', "Eastern");
  await clickWizardNext(modal, page);

  await modal.locator('input[type="email"]').fill(ownerEmail);
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

  await expect(page.getByRole("heading", { name: /Step 5.*Waypoints/i })).toBeVisible({ timeout: 30000 });
  await clickWizardNext(modal, page);

  const saveAndSendButton = modal.getByRole("button", { name: "Save & Send", exact: true });
  await expect(saveAndSendButton).toBeVisible({ timeout: 30000 });
  const exchange = await waitForApiExchange(page, "/fpw/api/v1/floatplan.cfc?method=handle", '"action":"send"', async () => {
    await saveAndSendButton.click();
  });
  expect(exchange.response?.SUCCESS).toBe(true);
  await expect(modal.locator(".wizard-alert.alert-success")).toContainText(/Float plan sent to/i, { timeout: 30000 });
  await modal.locator(".btn-close").click();
  await expect(modal).toBeHidden({ timeout: 15000 });

  return {
    exchange,
    departure,
    returning
  };
}

async function loadFloatPlanBootstrap(page, floatPlanId) {
  const payload = await postJson(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
    action: "bootstrap",
    floatPlanId
  });
  expect(payload.SUCCESS).toBe(true);
  return payload;
}

async function loadProjection(page, floatPlanId) {
  const response = await page.context().request.get(
    `/fpw/api/v1/voyage.cfc?action=getTripProgressProjection&method=handle&returnformat=json&floatplan_id=${encodeURIComponent(floatPlanId)}`
  );
  const payload = await response.json();
  expect(response.ok()).toBeTruthy();
  expect(payload.success).toBe(true);
  return payload;
}

function getActivitySegmentCount(projection) {
  return Array.isArray(projection?.activitySegments) ? projection.activitySegments.length : 0;
}

function getRouteTimeline(projection) {
  return projection?.routeTimeline || {};
}

async function openActiveCruiseFromRouteCard(page, routeCode, diagnostics) {
  const routeCard = page.locator(`.expedition-route-card[data-route-code="${routeCode}"]`).first();
  await expect(routeCard).toBeVisible({ timeout: 30000 });
  const popupPromise = page.waitForEvent("popup");
  await routeCard.locator(".js-expedition-active-cruise").click();
  const activeCruisePage = await popupPromise;
  attachPageDiagnostics(activeCruisePage, diagnostics, "active-cruise");
  await activeCruisePage.waitForLoadState("domcontentloaded");
  await expect(activeCruisePage).toHaveURL(/\/fpw\/app\/active-cruise\.cfm/i, { timeout: 30000 });
  await expect(activeCruisePage.locator("body")).not.toContainText("No active trip is available for this account.", { timeout: 30000 });
  await expect(activeCruisePage.locator("#fpw-active-cruise-hooks")).toBeAttached({ timeout: 30000 });
  return activeCruisePage;
}

async function readActiveCruiseHooks(activeCruisePage) {
  return activeCruisePage.locator("#fpw-active-cruise-hooks").evaluate((node) => JSON.parse(node.textContent || "{}"));
}

async function submitFirstOnTrackCheckIn(activeCruisePage) {
  const modal = activeCruisePage.locator("#fpwCheckInModal");
  const exchangePromise = waitForApiExchange(
    activeCruisePage,
    "/fpw/api/v1/floatplan.cfc?method=handle&action=checkin",
    '"status":"On Track"',
    async () => {
      await activeCruisePage.click("#fpwCheckInBtn");
      await expect(modal).toHaveAttribute("aria-hidden", "false", { timeout: 30000 });
      await modal.locator('[data-status="On Track"]').click();
      await activeCruisePage.click("#fpwCheckInSubmitBtn");
    }
  );

  const exchange = await exchangePromise;
  await activeCruisePage.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
  await expect(activeCruisePage.locator("#fpw-active-cruise-hooks")).toBeAttached({ timeout: 30000 });
  return exchange;
}

test("Route generator to Active Cruise first On Track check-in starts the trip", async ({ page }, testInfo) => {
  const state = createCleanupState();
  const diagnostics = {
    console: [],
    network: [],
    dialogs: []
  };
  const result = {
    disposableUser: {},
    route: {},
    activation: {},
    send: {},
    activeCruiseBeforeCheckin: {},
    checkin: {},
    afterCheckin: {},
    cleanup: {}
  };
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;

  attachPageDiagnostics(page, diagnostics, "dashboard");

  try {
    const user = await createDisposableUser(page);
    result.disposableUser = {
      email: user.email,
      userId: user.userId,
      cleanup: "User account is disposable; no approved user-delete API is used by this browser spec."
    };

    await cleanupCurrentRouteFloatPlanGroup(page);
    await waitForDashboardReady(page);

    const support = {
      ...(await createSupportVessel(page, state, suffix)),
      ...(await createSupportOperator(page, state, suffix)),
      ...(await createSupportContact(page, state, suffix))
    };
    const generatedRoute = await createNewRouteThroughGenerator(page, state, suffix);
    result.route = {
      name: generatedRoute.routeName,
      code: generatedRoute.routeCode,
      routeInstanceId: generatedRoute.routeInstanceId,
      previewLegs: generatedRoute.previewLegs.length,
      explicitSaveAttempted: generatedRoute.explicitSaveResult.attempted === true
    };

    const activated = await activateGeneratedRoute(page, generatedRoute.routeCode);
    const planId = activated.planId;
    trackId(state, "floatPlanIds", planId);
    result.activation = {
      planId,
      floatPlanIds: activated.floatPlanIds,
      routeInstanceId: activated.routeInstanceId || generatedRoute.routeInstanceId,
      request: activated.exchange.request.parsed,
      response: activated.exchange.response
    };

    const sent = await fillAndSendFloatPlan(
      page,
      planId,
      `PW Phase4O Plan ${suffix}`,
      support,
      user.email
    );
    const activeGroupRow = currentGroupRowLocator(page, planId);
    await expect(activeGroupRow).toBeVisible({ timeout: 30000 });
    await expect(activeGroupRow).toHaveAttribute("data-plan-status", "ACTIVE", { timeout: 30000 });
    await expect(activeGroupRow).toHaveAttribute("data-current-state", "ACTIVE", { timeout: 30000 });

    const bootstrapAfterSend = await loadFloatPlanBootstrap(page, planId);
    const floatPlanAfterSend = bootstrapAfterSend.FLOATPLAN || {};
    const routeInstanceIdAfterSend = Number(floatPlanAfterSend.ROUTE_INSTANCE_ID || floatPlanAfterSend.route_instance_id || 0);
    const projectionAfterSend = await loadProjection(page, planId);
    const timelineAfterSend = getRouteTimeline(projectionAfterSend);
    const legsAfterSend = Array.isArray(timelineAfterSend.legs) ? timelineAfterSend.legs : [];

    expect(String(floatPlanAfterSend.STATUS || "").toUpperCase()).toBe("ACTIVE");
    expect(routeInstanceIdAfterSend).toBeGreaterThan(0);
    expect(timelineAfterSend.available).toBe(true);
    expect(timelineAfterSend.authority).toBe("scheduled_projection");
    expect(legsAfterSend.length).toBe(generatedRoute.previewLegs.length);
    expect(Number(timelineAfterSend.currentLegOrder || 0)).toBe(1);
    expect(legsAfterSend.every((leg) => !String(leg.startedAtUtc || "").trim())).toBe(true);
    expect(legsAfterSend.every((leg) => !String(leg.completedAtUtc || "").trim())).toBe(true);
    expect(Number(projectionAfterSend.eventLedger?.count || 0)).toBe(0);
    expect(getActivitySegmentCount(projectionAfterSend)).toBe(0);
    expect(Number(projectionAfterSend.monitoringState?.monitoringId || 0)).toBeGreaterThan(0);
    expect(String(projectionAfterSend.monitoringState?.monitorState || "").toUpperCase()).toBe("ACTIVE");
    expect(String(projectionAfterSend.monitoringState?.expectedCheckinAtUtc || "")).not.toBe("");

    result.send = {
      request: sent.exchange.request.parsed,
      response: sent.exchange.response,
      floatPlanStatus: floatPlanAfterSend.STATUS || "",
      routeInstanceId: routeInstanceIdAfterSend,
      routeTimelineAuthority: timelineAfterSend.authority || "",
      routeTimelineLegs: legsAfterSend.length,
      routeTimelineCurrentLegOrder: timelineAfterSend.currentLegOrder || 0,
      routeProgressStartedRowsFromProjection: legsAfterSend.filter((leg) => String(leg.startedAtUtc || "").trim()).length,
      monitoringId: projectionAfterSend.monitoringState?.monitoringId || 0,
      monitoringState: projectionAfterSend.monitoringState?.monitorState || "",
      expectedCheckinAtUtc: projectionAfterSend.monitoringState?.expectedCheckinAtUtc || "",
      eventLedgerCount: projectionAfterSend.eventLedger?.count || 0,
      activitySegmentCount: getActivitySegmentCount(projectionAfterSend)
    };

    const activeCruisePage = await openActiveCruiseFromRouteCard(page, generatedRoute.routeCode, diagnostics);
    const hooks = await readActiveCruiseHooks(activeCruisePage);
    const pageContext = hooks.CONTEXT || hooks.context || {};
    expect(Number(pageContext.FLOATPLANID || pageContext.floatPlanId || 0)).toBe(planId);

    const canonicalProjection = hooks.CANONICALPROJECTION || hooks.canonicalProjection || {};
    const hookRouteTimeline = canonicalProjection.ROUTETIMELINE || canonicalProjection.routeTimeline || {};
    const hookLegs = hookRouteTimeline.LEGS || hookRouteTimeline.legs || [];
    expect(canonicalProjection.AVAILABLE || canonicalProjection.available).toBe(true);
    expect(hookRouteTimeline.AVAILABLE || hookRouteTimeline.available).toBe(true);
    expect(hookRouteTimeline.AUTHORITY || hookRouteTimeline.authority).toBe("scheduled_projection");
    expect(Number(hookRouteTimeline.CURRENTLEGORDER || hookRouteTimeline.currentLegOrder || 0)).toBe(1);
    expect(hookLegs.length).toBe(generatedRoute.previewLegs.length);

    await expect(activeCruisePage.locator("[data-route-plan-leg]")).toHaveCount(generatedRoute.previewLegs.length, { timeout: 30000 });
    const renderedAuthorities = await activeCruisePage.locator("[data-route-plan-leg]").evaluateAll((nodes) => {
      return nodes.map((node) => node.getAttribute("data-route-plan-authority") || "");
    });
    expect(renderedAuthorities.every((authority) => authority === "scheduled_projection")).toBe(true);

    result.activeCruiseBeforeCheckin = {
      hookCanonicalAvailable: canonicalProjection.AVAILABLE || canonicalProjection.available,
      hookRouteTimelineAvailable: hookRouteTimeline.AVAILABLE || hookRouteTimeline.available,
      hookRouteTimelineAuthority: hookRouteTimeline.AUTHORITY || hookRouteTimeline.authority,
      hookRouteTimelineLegs: hookLegs.length,
      renderedRouteLegs: renderedAuthorities.length,
      renderedAuthorities: Array.from(new Set(renderedAuthorities))
    };

    const beforeCheckinStartedRows = legsAfterSend.filter((leg) => String(leg.startedAtUtc || "").trim()).length;
    expect(beforeCheckinStartedRows).toBe(0);

    const checkinExchange = await submitFirstOnTrackCheckIn(activeCruisePage);
    result.checkin = {
      request: checkinExchange.request.parsed,
      response: checkinExchange.response,
      responseText: checkinExchange.responseText,
      url: checkinExchange.url,
      status: checkinExchange.status
    };
    let projectionAfterCheckin = null;
    let timelineAfterCheckin = {};
    let legsAfterCheckin = [];
    let startedLegsAfterCheckin = [];
    try {
      projectionAfterCheckin = await loadProjection(activeCruisePage, planId);
      timelineAfterCheckin = getRouteTimeline(projectionAfterCheckin);
      legsAfterCheckin = Array.isArray(timelineAfterCheckin.legs) ? timelineAfterCheckin.legs : [];
      startedLegsAfterCheckin = legsAfterCheckin.filter((leg) => String(leg.startedAtUtc || "").trim());
      result.afterCheckin = {
        routeTimelineAuthority: timelineAfterCheckin.authority || "",
        routeTimelineLegs: legsAfterCheckin.length,
        routeTimelineCurrentLegOrder: timelineAfterCheckin.currentLegOrder || 0,
        startedRowsFromProjection: startedLegsAfterCheckin.length,
        firstStartedLegOrder: startedLegsAfterCheckin[0]?.routeLegOrder || 0,
        firstStartedAtUtc: startedLegsAfterCheckin[0]?.startedAtUtc || "",
        eventLedgerCount: projectionAfterCheckin.eventLedger?.count || 0,
        activitySegmentCount: getActivitySegmentCount(projectionAfterCheckin),
        monitoringState: projectionAfterCheckin.monitoringState?.monitorState || "",
        lastCheckinAtUtc: projectionAfterCheckin.monitoringState?.lastCheckinAtUtc || "",
        latestActivityStatus: projectionAfterCheckin.latestActivity?.status || ""
      };
    } catch (error) {
      result.afterCheckin = {
        error: error.message
      };
    }

    expect(checkinExchange.response?.MESSAGE || "").not.toContain("Float plan API error");
    expect(checkinExchange.response?.success === true || checkinExchange.response?.SUCCESS === true).toBe(true);

    expect(startedLegsAfterCheckin.length).toBeGreaterThan(0);
    expect(Number(projectionAfterCheckin?.eventLedger?.count || 0)).toBeGreaterThan(0);
    expect(getActivitySegmentCount(projectionAfterCheckin)).toBeGreaterThan(0);
    expect(String(projectionAfterCheckin?.monitoringState?.lastCheckinAtUtc || "")).not.toBe("");
    expect(String(projectionAfterCheckin?.latestActivity?.status || "")).not.toBe("");

    expect(diagnostics.dialogs).toEqual([]);
    expect(diagnostics.network).toEqual([]);
    expect(diagnostics.console).toEqual([]);
  } finally {
    result.diagnostics = diagnostics;
    await fs.writeFile(testInfo.outputPath("phase4o-result.json"), JSON.stringify(result, null, 2), "utf8")
      .catch(() => {});
    await cleanupTrackedData(page, state)
      .then(() => {
        result.cleanup = {
          routeAndFloatPlanCleanupAttempted: true,
          routeCodes: state.routeCodes.slice(),
          floatPlanIds: state.floatPlanIds.slice()
        };
      })
      .catch((error) => {
        result.cleanup = {
          routeAndFloatPlanCleanupAttempted: true,
          error: error.message
        };
      });
    console.log(`[phase4o-result] ${JSON.stringify(result)}`);
  }
});
