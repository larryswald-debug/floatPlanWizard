const { expect } = require("@playwright/test");
const {
  addMyRouteWaypointLeg,
  callRouteBuilderAction,
  callWaypointAction,
  closeRouteBuilder,
  createMyRouteViaUi,
  ensureRouteName,
  generateRoute,
  loadMyRoutePreview,
  openRouteBuilder,
  prepareGreatLoopPreview,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveOverrideForLeg,
  saveRoute,
  setMyRouteStartWaypoint,
  snapshotPreviewLegs
} = require("./routebuilderHarness");
const { findLegByOrder } = require("./routebuilderAssertions");

function uniqueName(prefix) {
  const stamp = new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 14);
  const token = Math.random().toString(16).slice(2, 10);
  return `${String(prefix || "routebuilder-torture").trim()}-${stamp}-${token}`;
}

function buildDeterministicGeometry(seed) {
  const offset = (parseInt(seed || 0, 10) || 0) * 0.01;
  const baseLat = 41.75 + offset;
  const baseLng = -87.65 - offset;
  return [
    { lat: Number((baseLat).toFixed(6)), lon: Number((baseLng).toFixed(6)) },
    { lat: Number((baseLat + 0.08).toFixed(6)), lon: Number((baseLng - 0.11).toFixed(6)) },
    { lat: Number((baseLat + 0.15).toFixed(6)), lon: Number((baseLng - 0.05).toFixed(6)) }
  ];
}

async function addOverridesByOrder(page, routeCode, overrideOrders) {
  const orders = Array.from(overrideOrders || []).map((value) => parseInt(value || 0, 10) || 0).filter((value) => value > 0);
  for (const order of orders) {
    const currentLegs = await snapshotPreviewLegs(page);
    const leg = findLegByOrder(currentLegs, order);
    expect(leg, `Cannot save override for route ${routeCode} at order ${order} because the leg was not found.`).toBeTruthy();
    const geometryPayload = await callRouteBuilderAction(page, "routegen_getleggeometry", {
      route_code: routeCode,
      leg_order: order
    });
    expect(!!geometryPayload?.SUCCESS, `routegen_getleggeometry failed for route ${routeCode} order ${order}: ${geometryPayload?.MESSAGE || "unknown error"}`).toBeTruthy();
    const data = geometryPayload.DATA || {};
    const routeLegId = parseInt(data.route_leg_id || leg.routeLegId || 0, 10) || 0;
    const segmentId = parseInt(data.segment_id || leg.segmentId || 0, 10) || 0;
    expect(routeLegId, `Resolved route_leg_id was missing for route ${routeCode} order ${order}.`).toBeGreaterThan(0);
    const payload = await callRouteBuilderAction(page, "routegen_savelegoverride", {
      route_code: routeCode,
      route_leg_id: routeLegId,
      leg_order: leg.order,
      segment_id: segmentId,
      geometry: buildDeterministicGeometry(order),
      override_fields: {}
    });
    expect(!!payload?.SUCCESS, `routegen_savelegoverride failed for route ${routeCode} order ${order}: ${payload?.MESSAGE || "unknown error"}`).toBeTruthy();
  }
  await page.waitForTimeout(200);
  return orders;
}

async function createGeneratedRouteFixture(page, cleanup, options) {
  const opts = options || {};
  const routeName = String(opts.routeName || uniqueName(opts.namePrefix || "rb-generated")).trim();
  const direction = String(opts.direction || "CCW").trim().toUpperCase();

  await prepareGreatLoopPreview(page, {
    routeName,
    direction,
    startDate: opts.startDate
  });

  const preGenerateLegs = await snapshotPreviewLegs(page);
  expect(preGenerateLegs.length).toBeGreaterThan(1);

  const generateResult = await generateRoute(page);
  const routeCode = cleanup ? cleanup.trackRouteCode(generateResult.routeCode) : generateResult.routeCode;

  const appliedOverrideOrders = await addOverridesByOrder(page, routeCode, opts.overrideOrders || []);
  let saveResult = null;
  if (opts.saveAfterSetup) {
    saveResult = await saveRoute(page);
  }
  const currentLegs = await snapshotPreviewLegs(page);

  if (opts.closeAfterCreate !== false) {
    await closeRouteBuilder(page);
  }

  return {
    routeCode,
    routeName,
    generateResult,
    appliedOverrideOrders,
    preGenerateLegs,
    currentLegs,
    saveResult
  };
}

async function createExistingGeneratedRouteFixture(page, cleanup, options) {
  const fixture = await createGeneratedRouteFixture(page, cleanup, {
    closeAfterCreate: true,
    ...(options || {})
  });
  await reloadDashboard(page);
  await reopenExistingRouteFromDashboard(page, fixture.routeCode);
  fixture.reopenedLegs = await snapshotPreviewLegs(page);
  return fixture;
}

async function createHeavilyEditedGeneratedRouteFixture(page, cleanup, options) {
  const opts = options || {};
  const fixture = await createGeneratedRouteFixture(page, cleanup, {
    closeAfterCreate: false,
    overrideOrders: opts.overrideOrders || [1, 2, 5],
    saveAfterSetup: !!opts.saveAfterSetup,
    direction: opts.direction || "CCW",
    namePrefix: opts.namePrefix || "rb-heavy"
  });

  const cycles = Math.max(parseInt(opts.cycles || 0, 10) || 0, 1);
  const cycleStates = [];
  for (let i = 0; i < cycles; i += 1) {
    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const saveResult = await saveRoute(page);
    const savedLegs = await snapshotPreviewLegs(page);
    cycleStates.push({
      cycle: i + 1,
      reversedLegs,
      savedLegs,
      saveResult
    });
  }

  fixture.cycleStates = cycleStates;
  fixture.currentLegs = await snapshotPreviewLegs(page);
  if (opts.reloadAfterCycles) {
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    fixture.reopenedLegs = await snapshotPreviewLegs(page);
  } else if (opts.closeAfterCreate !== false) {
    await closeRouteBuilder(page);
  }
  return fixture;
}

async function createWaypointFixture(page, cleanup, options) {
  const opts = options || {};
  const waypointName = String(opts.name || uniqueName(opts.namePrefix || "rb-waypoint")).trim();
  let waypointPayload = null;
  try {
    waypointPayload = await callWaypointAction(page, "save", {
      waypoint: {
        name: waypointName,
        latitude: String(opts.latitude || "41.88"),
        longitude: String(opts.longitude || "-87.62"),
        notes: String(opts.notes || "Route Builder torture test waypoint")
      }
    });
  } catch (error) {
    throw new Error(`Unable to create waypoint ${waypointName}: ${error?.message || error}`);
  }
  expect(!!waypointPayload?.SUCCESS, `Unable to create waypoint ${waypointName}.`).toBeTruthy();
  const waypointId = cleanup
    ? cleanup.trackWaypointId(waypointPayload.WAYPOINTID)
    : waypointPayload.WAYPOINTID;
  return {
    waypointId: parseInt(waypointId || 0, 10) || 0,
    waypointName,
    payload: waypointPayload
  };
}

async function createMyRouteFixture(page, cleanup, options) {
  const opts = options || {};
  const myRouteName = String(opts.routeName || uniqueName(opts.namePrefix || "rb-my-route")).trim();
  const waypointCount = Math.max(parseInt(opts.waypointCount || 3, 10) || 3, 3);
  const waypoints = [];

  for (let index = 0; index < waypointCount; index += 1) {
    waypoints.push(await createWaypointFixture(page, cleanup, {
      namePrefix: `${myRouteName}-wp-${index + 1}`,
      latitude: (41.80 + (index * 0.1)).toFixed(4),
      longitude: (-87.70 - (index * 0.1)).toFixed(4)
    }));
  }

  await openRouteBuilder(page);
  const createResult = await createMyRouteViaUi(page, myRouteName);
  const routeId = cleanup ? cleanup.trackMyRouteId(createResult.routeId) : createResult.routeId;

  await setMyRouteStartWaypoint(page, routeId, waypoints[0].waypointName);
  for (let index = 1; index < waypoints.length; index += 1) {
    await addMyRouteWaypointLeg(page, routeId, waypoints[index].waypointName);
  }
  await loadMyRoutePreview(page, routeId);
  const previewLegs = await snapshotPreviewLegs(page);

  let generatedRoute = null;
  if (opts.generateExpedition) {
    const expeditionName = String(opts.expeditionName || uniqueName(`${myRouteName}-expedition`)).trim();
    await ensureRouteName(page, expeditionName);
    const generateResult = await generateRoute(page);
    const routeCode = cleanup ? cleanup.trackRouteCode(generateResult.routeCode) : generateResult.routeCode;
    generatedRoute = {
      routeCode,
      routeName: expeditionName,
      generateResult
    };
  }

  return {
    routeId,
    routeName: myRouteName,
    waypoints,
    previewLegs,
    generatedRoute
  };
}

module.exports = {
  addOverridesByOrder,
  buildDeterministicGeometry,
  createExistingGeneratedRouteFixture,
  createGeneratedRouteFixture,
  createHeavilyEditedGeneratedRouteFixture,
  createMyRouteFixture,
  createWaypointFixture,
  uniqueName
};
