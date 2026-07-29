const { wait } = require("./routebuilderHarness");

async function withDelayedRouteBuilderAction(page, actionName, delaysMs, callback) {
  const hits = [];
  const routeMatcher = /\/fpw\/api\/v1\/routeBuilder\.cfc\?/i;
  const normalizedAction = String(actionName || "").trim();

  const handler = async (route) => {
    const url = route.request().url();
    if (!routeMatcher.test(url) || !url.includes(`action=${normalizedAction}`)) {
      await route.continue();
      return;
    }
    const hitIndex = hits.length;
    const delayMs = Array.isArray(delaysMs) ? (Number(delaysMs[hitIndex] || 0) || 0) : (Number(delaysMs || 0) || 0);
    hits.push({
      index: hitIndex + 1,
      action: normalizedAction,
      delayMs,
      url
    });
    if (delayMs > 0) {
      await wait(delayMs);
    }
    await route.continue();
  };

  await page.route("**/fpw/api/v1/routeBuilder.cfc?**", handler);
  try {
    const result = await callback({
      getHits() {
        return hits.slice();
      }
    });
    return {
      result,
      hits: hits.slice()
    };
  } finally {
    try {
      await page.unroute("**/fpw/api/v1/routeBuilder.cfc?**", handler);
    } catch (error) {
      if (!/Target page, context or browser has been closed/i.test(String(error && error.message || ""))) {
        throw error;
      }
    }
  }
}

async function withDelayedPreviews(page, delaysMs, callback) {
  return withDelayedRouteBuilderAction(page, "routegen_preview", delaysMs, callback);
}

async function withDelayedSaves(page, delaysMs, callback) {
  return withDelayedRouteBuilderAction(page, "routegen_update", delaysMs, callback);
}

async function withDelayedGeometry(page, delaysMs, callback) {
  return withDelayedRouteBuilderAction(page, "routegen_getleggeometry", delaysMs, callback);
}

async function withFailedRouteBuilderAction(page, actionName, failurePayload, callback) {
  const hits = [];
  const routeMatcher = /\/fpw\/api\/v1\/routeBuilder\.cfc\?/i;
  const normalizedAction = String(actionName || "").trim();
  const responsePayload = (failurePayload && typeof failurePayload === "object")
    ? failurePayload
    : { SUCCESS: false, MESSAGE: "Injected Route Builder failure." };

  const handler = async (route) => {
    const request = route.request();
    const url = request.url();
    if (!routeMatcher.test(url) || !url.includes(`action=${normalizedAction}`)) {
      await route.continue();
      return;
    }
    hits.push({
      action: normalizedAction,
      method: request.method(),
      url
    });
    await route.fulfill({
      status: 200,
      contentType: "application/json; charset=utf-8",
      body: JSON.stringify(responsePayload)
    });
  };

  await page.route("**/fpw/api/v1/routeBuilder.cfc?**", handler);
  try {
    const result = await callback({
      getHits() {
        return hits.slice();
      }
    });
    return {
      result,
      hits: hits.slice()
    };
  } finally {
    await page.unroute("**/fpw/api/v1/routeBuilder.cfc?**", handler);
  }
}

module.exports = {
  withFailedRouteBuilderAction,
  withDelayedGeometry,
  withDelayedPreviews,
  withDelayedRouteBuilderAction,
  withDelayedSaves
};
