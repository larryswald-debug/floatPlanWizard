// Run with MCP Playwright browser_run_code_unsafe's filename argument.
// These isolated rendering checks complement the database contract suite and real email-link proof.
async (page) => {
  const context = await page.context().browser().newContext();
  const p = await context.newPage();
  const base = "http://localhost:8500/fpw";
  const requests = [];
  const errors = [];
  const results = [];
  const dangerousText = '<img src=x onerror="window.completedContactXss=true">';
  const payload = {
    SUCCESS: true,
    view_mode: "completed_read_only",
    completed_trip: {
      trip_name: dangerousText,
      vessel_name: "Test Vessel",
      destination: "Test Anchorage",
      completed_at_utc: "2026-09-03T16:00:00Z",
      completed_at_local: "Sep 3, 2026 12:00 PM",
      completion_timezone: "America/New_York"
    }
  };
  function check(condition, message) {
    if (!condition) throw new Error(message);
  }
  p.on("pageerror", error => errors.push(error.message));
  p.on("request", request => {
    if (request.url().includes("/api/")) requests.push(request.url());
  });
  await p.route("**/api/v1/voyage.cfc?*", route => route.fulfill({
    status: 200, contentType: "application/json", body: JSON.stringify(payload)
  }));
  try {
    await p.goto(base + "/app/follow.cfm?slug=render-test&t=render-token", { waitUntil: "domcontentloaded" });
    await p.locator("#followCompleted").waitFor({ state: "visible" });
    check(await p.locator("#followCompletedTrip").textContent() === dangerousText, "Summary must render as text");
    check(await p.locator("#followCompleted img").count() === 0, "Summary must not create HTML elements");
    check(await p.evaluate(() => !window.completedContactXss), "Summary text executed script");
    check(await p.locator("#followCompletedTime").getAttribute("datetime") === payload.completed_trip.completed_at_utc, "Canonical UTC time missing");
    check((await p.locator("#followCompletedTime").textContent()).includes("America/New_York"), "Timezone missing");
    for (const width of [320, 390, 768, 1440]) {
      await p.setViewportSize({ width, height: 900 });
      check(!await p.locator(".app").isVisible(), "Live controls visible at " + width);
      check(!await p.locator("#followLoader").isVisible(), "Loader visible at " + width);
      check(!await p.locator("#followTerminalError").isVisible(), "Error visible at " + width);
      check(await p.locator("#followCompletedHeading").evaluate(el => el === document.activeElement), "Completion heading lacks focus");
      check(await p.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth), "Horizontal overflow at " + width);
      results.push("completed layout " + width + "px: PASS");
    }
    check(requests.length === 1 && requests[0].includes("action=getStreamBootstrap"), "Completed view requested live APIs");
    check(await p.locator(".leaflet-container").count() === 0, "Completed view initialized a map");
    results.push("safe text, timezone, focus and bootstrap-only network: PASS");

    await p.goto(base + "/app/follow-full-map.cfm?slug=render-test&t=render-token", { waitUntil: "domcontentloaded" });
    await p.getByText("Trip Completed Safely", { exact: true }).waitFor();
    check(await p.getByText("Live monitoring has ended.", { exact: true }).isVisible(), "Full-map completed message missing");
    check(await p.locator(".leaflet-container").count() === 0, "Full-map initialized a completed map");
    check((await p.locator("#backToFollowPageLink").getAttribute("href")).includes("follow.cfm"), "Back link missing");
    results.push("full-map completed compatibility: PASS");

    delete payload.completed_trip;
    await p.goto(base + "/app/follow.cfm?slug=render-test&t=render-token", { waitUntil: "domcontentloaded" });
    await p.locator("#followTerminalError").waitFor({ state: "visible" });
    check(!await p.locator(".app").isVisible(), "Malformed response exposed live interface");
    check(!await p.locator("#followCompleted").isVisible(), "Malformed response exposed completion");
    check(errors.length === 0, "Browser runtime errors: " + errors.join(", "));
    results.push("malformed completed response fails closed: PASS");
    return { SUCCESS: true, checks: results };
  } finally {
    await context.close();
  }
}
