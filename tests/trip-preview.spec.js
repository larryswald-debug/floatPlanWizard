const { test, expect } = require("@playwright/test");

const BASE = process.env.FPW_BASE_URL || "http://localhost:8500/fpw";
const RUNNER = BASE + "/tests/trip-preview-runner.cfm";
const CONFIRM = "RUN_TRIP_PREVIEW_TESTS";
const TELEMETRY = /google-analytics|googletagmanager|plausible\.io|clarity\.ms/i;

async function fixtureAction(request, action, fixture, extra = {}) {
  const response = await request.get(RUNNER, { params: { confirm: CONFIRM, action, ...(fixture ? { fixture } : {}), ...extra } });
  expect(response.ok(), action + ": " + response.status()).toBe(true);
  const data = await response.json();
  expect(data.SUCCESS, JSON.stringify(data)).toBe(true);
  return data;
}
async function withFixture(request, options, run) {
  const fixture = await fixtureAction(request, "setup", null, options);
  try { return await run(fixture); }
  finally { await fixtureAction(request, "cleanup", fixture.fixture); }
}
async function login(page, fixture, member = "owner") {
  await fixtureAction(page.request, "login", fixture.fixture, { member });
}
function previewUrl(view, id) {
  return BASE + "/app/" + (view === "follow" ? "follow" : "active-cruise") + ".cfm?mode=preview&floatPlanId=" + encodeURIComponent(id);
}
function privacyHeaders(response) {
  const headers = response.headers();
  expect(headers["cache-control"]).toBe("no-store");
  expect(headers["referrer-policy"]).toBe("no-referrer");
  expect(headers["x-robots-tag"]).toBe("noindex, nofollow");
}
async function openPreview(page, view, id) {
  const response = await page.goto(previewUrl(view, id));
  expect(response.status()).toBe(200);
  privacyHeaders(response);
  await expect(page.locator('[data-trip-preview-view="' + view + '"]')).toBeVisible();
  await expect(page.getByRole("link", { name: "Continue Float Plan", exact: true })).toBeVisible();
  if (view === "follow") await expect(page.locator("body")).not.toHaveClass(/follow-loading/);
}

test.describe("owned Draft trip preview", () => {
  test.setTimeout(120000);

  for (const width of [1440, 390]) {
    test("shared renderers, inert controls, maps and privacy at " + width + "px", async ({ page }, testInfo) => {
      await page.setViewportSize({ width, height: 900 });
      return withFixture(page.request, { withDueTrip: 1 }, async fixture => {
        await login(page, fixture);
        const before = (await fixtureAction(page.request, "snapshot", fixture.fixture)).snapshot;
        const forbidden = [];
        const observedRequests = [];
        const errors = [];
        page.on("pageerror", error => errors.push(error.message));
        page.on("request", request => {
          if (/\/api\/v1\/.*\.cfc/i.test(request.url()) || TELEMETRY.test(request.url())) forbidden.push(request.url());
          observedRequests.push({url: request.url(), referer: request.headers().referer || ""});
        });
        await page.addInitScript(() => {
          window.__previewGeolocationCalls = 0;
          navigator.geolocation.getCurrentPosition = () => { window.__previewGeolocationCalls += 1; };
          navigator.geolocation.watchPosition = () => { window.__previewGeolocationCalls += 1; return 1; };
        });
        for (const view of ["active_cruise", "follow", "active_cruise", "follow"]) {
          await openPreview(page, view, fixture.floatPlanId);
          const map = page.locator(".leaflet-container").first();
          await expect(map).toBeVisible();
          await map.locator(".leaflet-control-zoom-in").click();
          const mapBox = await map.boundingBox();
          await page.mouse.move(mapBox.x + mapBox.width / 2, mapBox.y + mapBox.height / 2);
          await page.mouse.down();
          await page.mouse.move(mapBox.x + mapBox.width / 2 + 30, mapBox.y + mapBox.height / 2 + 15, { steps: 4 });
          await page.mouse.up();
          expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);
          expect(await page.evaluate(() => window.__previewGeolocationCalls)).toBe(0);
          expect(await page.locator('script[src*="plausible"],script[src*="clarity"],script[src*="googletagmanager"]').count()).toBe(0);
          const continueLink = page.getByRole("link", { name: "Continue Float Plan", exact: true });
          expect(await continueLink.getAttribute("href")).toBe("/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=" + fixture.floatPlanId);
          const disabled = view === "follow"
            ? page.locator("#copyLinkBtn, #privacyBtn, #openFullMapBtn")
            : page.locator("[data-ac-v2-action], [data-ac-v2-timing-action], #fpwV2PaceSlider, #fpwV2WeatherForm button, #fpwV2WeatherApplyBtn, .captain-note-save");
          expect(await disabled.count()).toBeGreaterThan(0);
          for (const control of await disabled.all()) await expect(control).toBeDisabled();
          if (view === "follow") {
            const pdf = page.locator('[data-fpw-field="float-plan-download-action"]');
            await expect(pdf).toHaveAttribute("aria-disabled", "true");
            expect(await pdf.getAttribute("href")).toBeNull();
          }
          await disabled.evaluateAll(nodes => nodes.forEach(node => { node.disabled = false; node.click(); }));
          await page.waitForTimeout(150);
          expect(page.url()).toBe(previewUrl(view, fixture.floatPlanId));
          if (view === "active_cruise") {
            await page.locator("#fpwActiveCruiseV2OpenFullMapBtn").click();
            await expect(page.locator("#fpwActiveCruiseV2FullMap")).toBeVisible();
            await expect(page.locator("#fpwActiveCruiseV2FullMapStatus")).not.toHaveClass(/is-visible/);
            await page.waitForFunction(() => {
              const map = document.querySelector("#fpwActiveCruiseV2FullMap");
              const tiles = Array.from(map.querySelectorAll("img.leaflet-tile"));
              return !map.classList.contains("leaflet-zoom-anim") && tiles.length > 0
                && tiles.every(tile => tile.complete && tile.naturalWidth > 0);
            });
            const policies = await page.locator("#fpwActiveCruiseV2FullMap img.leaflet-tile").evaluateAll(nodes => nodes.map(node => node.referrerPolicy));
            expect(policies.length).toBeGreaterThan(0);
            for (const policy of policies) expect(policy).toBe("origin");
            await page.screenshot({path: testInfo.outputPath("active-full-map-" + width + ".png")});
            await page.locator("#fpwActiveCruiseV2FullMapClose").click();
          }
          const inlinePolicies = await map.locator("img.leaflet-tile").evaluateAll(nodes => nodes.map(node => node.referrerPolicy));
          expect(inlinePolicies.length).toBeGreaterThan(0);
          for (const policy of inlinePolicies) expect(policy).toBe("origin");
          await page.screenshot({ path: testInfo.outputPath(view + "-" + width + ".png") });
        }
        expect(forbidden).toEqual([]);
        expect(errors).toEqual([]);
        const after = (await fixtureAction(page.request, "snapshot", fixture.fixture)).snapshot;
        expect(after).toEqual(before);
        const osm = [], other = [];
        for (const entry of observedRequests) {
          const isOsmTile = /^https:\/\/[abc]\.tile\.openstreetmap\.org\/\d+\/\d+\/\d+\.png$/.test(entry.url);
          expect(entry.referer, entry.url).toBe(isOsmTile ? new URL(BASE).origin + "/" : "");
          (isOsmTile ? osm : other).push(entry);
        }
        expect(osm.length).toBeGreaterThan(0);
        return {osmRequests: osm.length, osmReferers: [...new Set(osm.map(entry => entry.referer))],
          otherRequests: other.length, otherReferers: [...new Set(other.map(entry => entry.referer))]};
      });
    });
  }

  test("ownership, malformed IDs, query tampering and anonymous redirect headers", async ({ page, browser }) => {
    await withFixture(page.request, {}, async fixture => {
      await login(page, fixture, "other");
      for (const view of ["active_cruise", "follow"]) {
        const foreign = await page.request.get(previewUrl(view, fixture.floatPlanId), { maxRedirects: 0 });
        expect(foreign.status()).toBe(404);
        privacyHeaders(foreign);
      }
      await login(page, fixture);
      for (const view of ["active_cruise", "follow"]) {
        for (const id of ["0", "-1", "01", "1e2", fixture.floatPlanId + "bad", "2147483648", "", " " + fixture.floatPlanId, fixture.floatPlanId + "\n", fixture.floatPlanId + "\t"]) {
          const invalid = await page.request.get(previewUrl(view, id), { maxRedirects: 0 });
          expect(invalid.status()).toBe(404);
          privacyHeaders(invalid);
        }
        const tampered = await page.request.get(previewUrl(view, fixture.floatPlanId) + "&stream_id=999999&slug=other&t=other&userId=" + fixture.otherId);
        expect(tampered.status()).toBe(200);
        privacyHeaders(tampered);
      }
      const anonymous = await browser.newContext();
      try {
        for (const view of ["active_cruise", "follow"]) {
          const response = await anonymous.request.get(previewUrl(view, fixture.floatPlanId), { maxRedirects: 0 });
          expect(response.status()).toBe(302);
          privacyHeaders(response);
          expect(response.headers().location).toContain("/index.cfm?notice=member-required");
        }
        const continuation = await anonymous.request.get(BASE + "/app/dashboard.cfm?recoveryAction=draft&floatPlanId=" + fixture.floatPlanId, { maxRedirects: 0 });
        expect(continuation.status()).toBe(302);
        expect(continuation.headers().location).toContain("/app/login.cfm?recoveryAction=draft&floatPlanId=" + fixture.floatPlanId);
      } finally { await anonymous.close(); }
    });
  });

  for (const view of ["active_cruise", "follow"]) {
    test("Continue Float Plan opens exact Draft at step 1 from " + view, async ({ page }) => {
      await withFixture(page.request, {}, async fixture => {
        await login(page, fixture);
        await openPreview(page, view, fixture.floatPlanId);
        const mutations = [];
        const continuationReferrers = [];
        page.on("request", request => {
          if (request.isNavigationRequest() && request.url().includes("/app/dashboard.cfm")) continuationReferrers.push(request.headers().referer || "");
          if (/action=(save|send|createpdf|downloadfloatplanpdf|activate|buildfloatplans)/i.test(request.url())) mutations.push(request.url());
        });
        await page.getByRole("link", { name: "Continue Float Plan", exact: true }).click();
        await expect(page.locator("#floatPlanWizardModal")).toBeVisible();
        await expect(page.getByRole("heading", { name: "Step 1 – Basics", exact: true })).toBeVisible();
        await expect(page.locator('#floatPlanWizardModal input[name="NAME"]')).toHaveValue(fixture.floatPlanName);
        expect(mutations).toEqual([]);
        expect(continuationReferrers).toEqual([""]);
      });
    });
  }

  for (const behavior of ["callback", "timeout", "unavailable", "throw"]) for (const launchView of ["follow", "active_cruise"]) {
    test(launchView + " dashboard launch is once-only with " + behavior + " analytics", async ({ page }) => {
      await withFixture(page.request, {}, async fixture => {
        await login(page, fixture);
        const events = [];
        await page.exposeFunction("recordPreviewAttempt", event => events.push(event));
        await page.addInitScript(mode => {
          if (mode === "unavailable") return;
          window.gtag = function (command, name, params) {
            if (name !== "preview_requested") return;
            window.recordPreviewAttempt({ command, name, view: params.view, timeout: params.event_timeout });
            if (mode === "throw") throw new Error("Analytics unavailable");
            if (mode === "callback") setTimeout(() => { params.event_callback(); params.event_callback(); }, 150);
          };
        }, behavior);
        await page.route(TELEMETRY, route => route.abort());
        await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
        const action = page.locator('.js-expedition-trip-preview[data-preview-view="' + launchView + '"]').first();
        await expect(action).toBeVisible();
        let navigations = 0;
        let navigationAt = 0;
        page.on("request", request => {
          if (request.isNavigationRequest() && request.url().includes("/app/" + (launchView === "follow" ? "follow" : "active-cruise") + ".cfm?mode=preview")) {
            navigations += 1;
            navigationAt = Date.now();
          }
        });
        const started = Date.now();
        await action.evaluate(button => {
          button.dispatchEvent(new MouseEvent("click", { bubbles: true }));
          button.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        });
        await page.waitForURL(previewUrl(launchView, fixture.floatPlanId));
        const navigationDelay = navigationAt - started;
        expect(navigationDelay).toBeLessThan(1600);
        if (behavior === "timeout" || behavior === "throw") expect(navigationDelay).toBeGreaterThanOrEqual(900);
        else expect(navigationDelay).toBeLessThan(900);
        expect(navigations).toBe(1);
        expect(events.length).toBe(behavior === "unavailable" ? 0 : 1);
        if (events.length) expect(events[0]).toEqual({ command: "event", name: "preview_requested", view: launchView, timeout: 1000 });
      });
    });
  }

  test("crafted Draft operations reject before unrelated due-trip expiration", async ({ page }) => {
    await withFixture(page.request, { withDueTrip: 1 }, async fixture => {
      await login(page, fixture);
      const before = (await fixtureAction(page.request, "snapshot", fixture.fixture)).snapshot;
      for (const action of ["checkin", "completeleg", "startnextleg", "savecaptainlogentry", "adddelay", "cleardelay", "updatedailystart", "updateactivepace"]) {
        const response = await page.request.post(BASE + "/api/v1/floatplan.cfc?method=handle&action=" + action + "&returnFormat=json", {
          data: { floatPlanId: fixture.floatPlanId, status: "Underway", expectedLegOrder: 1, note: "Preview rejection test",
            noteText: "Preview rejection test", minutes: 10, delayMinutes: 10, dailyStartLocalTime: "08:00", pace: "normal" }
        });
        const data = await response.json();
        expect(data.SUCCESS, action + ": " + JSON.stringify(data)).toBe(false);
        expect(data.MESSAGE).not.toBe("Application error");
      }
      const weather = await page.request.post(BASE + "/api/v1/voyage.cfc?method=handle&action=getactivecruiseweather", {
        data: { floatPlanId: fixture.floatPlanId, point: "start", routeLegOrder: 1 }
      });
      expect((await weather.json()).SUCCESS).toBe(false);
      const after = (await fixtureAction(page.request, "snapshot", fixture.fixture)).snapshot;
      // Ordinary rejected APIs retain normal activity attribution; operational state must stay unchanged.
      expect(after.operational).toEqual(before.operational);
    });
  });

  test("normal Active Cruise keeps existing responsive layout and operational controls", async ({ page }, testInfo) => {
    return withFixture(page.request, { activeScheduled: 1 }, async fixture => {
      await login(page, fixture);
      await page.route(TELEMETRY, route => route.abort());
      const before = (await fixtureAction(page.request, "snapshot", fixture.fixture)).snapshot;
      const errors = [], tileResponses = [];
      page.on("pageerror", error => errors.push(error.message));
      page.on("response", response => {
        if (/tile\.openstreetmap\.org/.test(response.url())) tileResponses.push({status:response.status(),referer:response.request().headers().referer || ""});
      });
      const response = await page.goto(BASE + "/app/active-cruise.cfm?floatPlanId=" + fixture.floatPlanId);
      expect(response.status()).toBe(200);
      expect(await page.locator("[data-trip-preview-view]").count()).toBe(0);
      await expect(page.locator("#fpwActiveCruiseV2Map")).toHaveAttribute("data-ac-v2-map-rendered", "true");
      const widths = [];
      for (const width of [360, 390, 760, 1024, 1440]) {
        await page.setViewportSize({width, height:900});
        await page.waitForTimeout(100);
        for (const selector of [".fpw-app-subnav", ".fpw-app-subnav-inner", "main.main > .shell", ".hero", ".top-actions", ".active-cruise-map-canvas", "#fpwActiveCruiseV2Map", ".leg-grid", ".route-plan-box", ".route-plan-leg-side", "#acCheckInPanel", "#fpwV2TimingPanel"]) {
          const boxes = await page.locator(selector).evaluateAll(nodes => nodes.map(node => {const r=node.getBoundingClientRect();return {left:r.left,right:r.right};}));
          expect(boxes.length,selector).toBeGreaterThan(0);
          for(const box of boxes) {
            expect(box.left,selector+" at "+width).toBeGreaterThanOrEqual(-1);
            expect(box.right,selector+" at "+width).toBeLessThan(width+2);
          }
        }
        const docWidth=await page.evaluate(()=>document.documentElement.scrollWidth);
        expect(docWidth).toBeLessThan(width+2);
        widths.push({width,documentWidth:docWidth});
      }
      expect(await page.getByRole("button", {name: "On Track", exact: true}).isEnabled()).toBe(true);
      expect(await page.locator("#fpwV2PaceSlider").isEnabled()).toBe(true);
      expect(await page.evaluate(()=>typeof window.FPWActiveCruiseV2.bindActionPanel)).toBe("function");
      expect(await page.evaluate(()=>typeof window.FPWActiveCruiseV2.fetchAndRefresh)).toBe("function");
      expect(await page.locator(".hero").evaluate(node=>getComputedStyle(node).gridTemplateColumns.trim().split(/\s+/).length)).toBe(2);
      await page.locator("#fpwActiveCruiseV2Map .leaflet-control-zoom-in").click();
      await page.screenshot({path:testInfo.outputPath("normal-active-1440.png")});
      expect(errors).toEqual([]);
      const after=(await fixtureAction(page.request,"snapshot",fixture.fixture)).snapshot;
      expect(after.operational).toEqual(before.operational);
      expect(after.generatedFiles).toEqual(before.generatedFiles);
      return {widths,tileResponses};
    });
  });

  test("normal Follow retains private-token authorization and existing renderer", async ({ page, browser }, testInfo) => {
    return withFixture(page.request, {activeScheduled:1}, async fixture => {
      await page.route(TELEMETRY, route=>route.abort());
      const errors=[], tileResponses=[];
      page.on("pageerror", error=>errors.push(error.message));
      page.on("response", response=>{
        if(/tile\.openstreetmap\.org/.test(response.url())) tileResponses.push({status:response.status(),referer:response.request().headers().referer || ""});
      });
      const api=BASE+"/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&slug="+fixture.followSlug;
      for(const suffix of ["","&t=wrong-token"]) {
        const denied=await (await page.request.get(api+suffix)).json();
        expect(denied.SUCCESS).toBe(false);
        expect(denied.ERROR.CODE).toBe("INVALID_SHARE_TOKEN");
      }
      const valid=await (await page.request.get(api+"&t="+fixture.followToken)).json();
      expect(valid.SUCCESS).toBe(true);
      const keys=[];
      function walk(value) {if(Array.isArray(value))return value.forEach(walk);if(value&&typeof value==="object")Object.keys(value).forEach(key=>{keys.push(key.toLowerCase());walk(value[key]);});}
      walk(valid);
      for(const key of ["owner_user_id","author_user_id","user_id","userid","member_id","account_id"])expect(keys.includes(key)).toBe(false);
      const response=await page.goto(BASE+fixture.followPath);
      expect(response.status()).toBe(200);
      await expect(page.locator("body")).not.toHaveClass(/follow-loading/);
      expect(await page.locator("[data-trip-preview-view]").count()).toBe(0);
      await expect(page.locator(".leaflet-container").first()).toBeVisible();
      expect(await page.locator("#copyLinkBtn").isEnabled()).toBe(true);
      expect(await page.locator("#openFullMapBtn").isEnabled()).toBe(true);
      for(const width of [390,1440]) {
        await page.setViewportSize({width,height:900});
        expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThan(width+2);
        await page.locator(".leaflet-control-zoom-in").first().click();
        await page.screenshot({path:testInfo.outputPath("normal-follow-"+width+".png")});
      }
      expect(errors).toEqual([]);
      return {tileResponses};
    });
  });

  for (const view of ["active_cruise", "follow"]) {
    test(view + " scopes the production-origin Referer exception to OSM images", async ({ page }) => {
      return withFixture(page.request, {}, async fixture => {
        await login(page, fixture);
        const localOrigin = new URL(BASE).origin;
        const productionOrigin = "https://floatplanwizard.com";
        const requests = [];
        // Serve local fixtures under the production origin; no FPW production request is sent.
        await page.route(productionOrigin + "/**", async route => {
          const target = new URL(route.request().url());
          if (target.pathname.endsWith("/app/dashboard.cfm")) {
            await route.fulfill({status:200, contentType:"text/html", body:"<p>Navigation privacy probe</p>"});
            return;
          }
          const localResponse = await page.request.get(localOrigin + target.pathname + target.search);
          await route.fulfill({response:localResponse});
        });
        await page.route("https://preview-referrer-check.invalid/**", route => route.fulfill({status:200,body:"ok"}));
        page.on("request", request => requests.push({url:request.url(), referer:request.headers().referer || "", type:request.resourceType()}));
        const url = previewUrl(view,fixture.floatPlanId).replace(localOrigin,productionOrigin);
        const response = await page.goto(url);
        expect(response.status()).toBe(200);
        privacyHeaders(response);
        await page.locator(".leaflet-tile-loaded").first().waitFor();
        await page.evaluate(() => fetch("https://preview-referrer-check.invalid/non-tile", {mode:"no-cors"}));
        await page.getByRole("link",{name:"Continue Float Plan",exact:true}).click();
        await page.waitForURL(/dashboard\.cfm/);
        const tiles = requests.filter(entry => /^https:\/\/[abc]\.tile\.openstreetmap\.org\/\d+\/\d+\/\d+\.png$/.test(entry.url));
        expect(tiles.length).toBeGreaterThan(0);
        for (const entry of requests) {
          const isTile=tiles.includes(entry);
          expect(entry.referer,entry.url).toBe(isTile ? productionOrigin + "/" : "");
          if (isTile) expect(entry.type).toBe("image");
        }
        return {view, origin:productionOrigin, tileRequests:tiles.length,
          tileReferers:[...new Set(tiles.map(entry=>entry.referer))],
          nonTileReferers:[...new Set(requests.filter(entry=>!tiles.includes(entry)).map(entry=>entry.referer))],
          navigationReferer:requests.find(entry=>entry.url.includes("/app/dashboard.cfm")).referer,
          note:"Local fixture responses served by Playwright routes; no FPW production backend contacted."};
      });
    });
  }

  test("dashboard keeps compact rows and orders saved Draft summary actions without overlap", async ({ page }, testInfo) => {
    return withFixture(page.request, {}, async fixture => {
      await login(page, fixture);
      await page.route(TELEMETRY, route => route.abort());
      const widths = [];
      for (const width of [1678, 1440, 1024, 768, 390]) {
        await page.setViewportSize({width, height:1000});
        await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
        const row = page.locator(".fpw-routes-table-row").first();
        const detail = page.locator(".fpw-route-detail-pane");
        await expect(row).toBeVisible();
        await expect(detail).toBeVisible();
        expect(await row.locator(".js-expedition-trip-preview").count()).toBe(0);
        expect(await detail.locator(".js-expedition-trip-preview").count()).toBe(2);
        expect(await detail.locator(".fpw-route-detail-actions button").allTextContents()).toEqual([
          "Complete Float Plan", "Edit Route", "Preview Active Cruise", "Preview Follow Page", "Delete"
        ]);
        expect(await detail.locator(".js-expedition-build-floatplans").count()).toBe(0);
        expect(await detail.locator(".js-expedition-plan-edit").getAttribute("data-plan-id")).toBe(String(fixture.floatPlanId));
        const rowBounds = await row.locator(".fpw-route-cell--actions").evaluate(cell => {
          const c = cell.getBoundingClientRect();
          return {left:c.left, right:c.right, controls:Array.from(cell.querySelectorAll("button")).map(button => {
            const b=button.getBoundingClientRect();return {left:b.left,right:b.right};
          })};
        });
        expect(rowBounds.controls.length).toBeGreaterThan(0);
        for (const control of rowBounds.controls) {
          expect(control.left).toBeGreaterThanOrEqual(rowBounds.left-1);
          expect(control.right).toBeLessThan(rowBounds.right+2);
        }
        const details = await detail.locator(".fpw-route-detail-actions").evaluate(container => {
          const c=container.getBoundingClientRect();
          return {left:c.left,right:c.right,controls:Array.from(container.querySelectorAll("button")).map(button => {
            const b=button.getBoundingClientRect(), range=document.createRange();
            range.selectNodeContents(button);
            const text=range.getBoundingClientRect();
            return {left:b.left,right:b.right,top:b.top,bottom:b.bottom,textLeft:text.left,textRight:text.right};
          })};
        });
        for (const control of details.controls) {
          expect(control.left).toBeGreaterThanOrEqual(details.left-1);
          expect(control.right).toBeLessThan(details.right+2);
          expect(control.textLeft).toBeGreaterThanOrEqual(control.left-1);
          expect(control.textRight).toBeLessThan(control.right+2);
        }
        for (let i=0;i<details.controls.length;i++) for(let j=i+1;j<details.controls.length;j++) {
          const a=details.controls[i],b=details.controls[j];
          expect(Math.min(a.right,b.right)-Math.max(a.left,b.left)>1
            && Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top)>1).toBe(false);
        }
        const disposition = details.controls[4];
        expect(Math.abs(disposition.left-details.left)).toBeLessThan(1);
        expect(Math.abs(disposition.right-details.right)).toBeLessThan(1);
        expect(disposition.top).toBeGreaterThanOrEqual(details.controls[3].bottom);
        if(width>760) {
          expect(details.controls[0].top).toBe(details.controls[1].top);
          expect(details.controls[2].top).toBe(details.controls[3].top);
          expect(details.controls[2].top).toBeGreaterThanOrEqual(details.controls[0].bottom);
        }
        const responsive = await detail.evaluate(pane => {
          const actions = pane.querySelector(".fpw-route-detail-actions");
          const table = document.querySelector(".fpw-routes-table-pane");
          return {documentWidth:document.documentElement.scrollWidth,
            actionColumns:getComputedStyle(actions).gridTemplateColumns.trim().split(/\s+/).length,
            detailTop:pane.getBoundingClientRect().top,tableBottom:table.getBoundingClientRect().bottom};
        });
        expect(responsive.documentWidth).toBeLessThan(width+2);
        if(width===390) {
          expect(responsive.actionColumns).toBe(1);
          expect(responsive.detailTop).toBeGreaterThanOrEqual(responsive.tableBottom-1);
        }
        widths.push({width,actionColumnWidth:rowBounds.right-rowBounds.left,previewButtons:2,documentWidth:responsive.documentWidth});
        if(width===1678) {
          await row.screenshot({path:testInfo.outputPath("dashboard-row-fixed-desktop.png")});
          await detail.screenshot({path:testInfo.outputPath("dashboard-summary-order-desktop.png")});
        }
        if(width===390) await detail.screenshot({path:testInfo.outputPath("dashboard-summary-order-mobile.png")});
      }
      for (const view of ["active_cruise","follow"]) {
        await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
        await page.locator('.fpw-route-detail-actions .js-expedition-trip-preview[data-preview-view="'+view+'"]').click();
        await page.waitForURL(previewUrl(view,fixture.floatPlanId));
        await expect(page.getByRole("link",{name:"Continue Float Plan",exact:true})).toBeVisible();
      }
      return {widths,bothSelectedDraftLaunches:"passed"};
    });
  });

  test("saved-route summary preserves disabled preview states and disposition policy", async ({ page }, testInfo) => {
    return withFixture(page.request, {}, async fixture => {
      await login(page, fixture);
      await page.route(TELEMETRY, route => route.abort());
      let state = {hasDraft:false, archive:false};
      // Exercise renderer states through the real route response shape without changing trip lifecycle data.
      await page.route("**/api/v1/routeBuilder.cfc?**", async route => {
        const query = new URL(route.request().url()).searchParams;
        if(query.get("action") !== "listUserRoutes") return route.continue();
        const response = await route.fetch();
        const payload = await response.json();
        expect(payload.SUCCESS).toBe(true);
        const item = payload.ROUTES.find(item => item.SHORT_CODE === fixture.routeCode);
        expect(!!item).toBe(true);
        if(state.hasDraft) item.CURRENT_GROUP.PREVIEW_READY = false;
        else {
          item.CURRENT_GROUP = {HAS_CURRENT_GROUP:false};
          item.HAS_CURRENT_GROUP = false;
          payload.CURRENT_GROUP = {HAS_CURRENT_GROUP:false};
        }
        item.CAN_ARCHIVE = state.archive;
        item.CAN_DELETE = !state.archive;
        await route.fulfill({response, json:payload});
      });
      const proof=[];
      for(const width of [1440,390]) for(const hasDraft of [false,true]) for(const archive of [false,true]) {
        state={hasDraft,archive};
        await page.setViewportSize({width,height:1000});
        await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
        const actions=page.locator(".fpw-route-detail-actions");
        await expect(actions).toBeVisible();
        const labels=[hasDraft?"Complete Float Plan":"Draft Float Plan","Edit Route","Preview Active Cruise","Preview Follow Page",archive?"Archive":"Delete"];
        expect(await actions.locator("button").allTextContents()).toEqual(labels);
        expect(await actions.locator(hasDraft?".js-expedition-plan-edit":".js-expedition-build-floatplans").count()).toBe(1);
        const previews=actions.locator(".js-expedition-trip-preview");
        for(const button of await previews.all()) {
          await expect(button).toBeDisabled();
          await expect(button).toHaveAttribute("data-preview-ready","0");
        }
        // Simulate the persisted-pageshow handler; this does not assert a real browser BFCache restore.
        await previews.evaluateAll(buttons => buttons.forEach(button => button.setAttribute("aria-busy","true")));
        await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pageshow",{persisted:true})));
        for(const button of await previews.all()) {
          await expect(button).toBeDisabled();
          expect(await button.getAttribute("aria-busy")).toBeNull();
        }
        const requests=[];
        const capture=request=>{if(/mode=preview/.test(request.url()))requests.push(request.url());};
        page.on("request",capture);
        await previews.evaluateAll(buttons=>buttons.forEach(button=>{button.disabled=false;button.click();}));
        await page.waitForTimeout(100);
        expect(requests).toEqual([]);
        expect(page.url().includes("dashboard.cfm")).toBe(true);
        await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pageshow",{persisted:true})));
        page.off("request",capture);
        const bounds=await actions.evaluate(container=>{
          const c=container.getBoundingClientRect(),b=container.lastElementChild.getBoundingClientRect();
          return {left:c.left,right:c.right,buttonLeft:b.left,buttonRight:b.right,span:getComputedStyle(container.lastElementChild).gridColumn,documentWidth:document.documentElement.scrollWidth};
        });
        expect(bounds.span).toBe("1 / -1");
        expect(Math.abs(bounds.left-bounds.buttonLeft)).toBeLessThan(1);
        expect(Math.abs(bounds.right-bounds.buttonRight)).toBeLessThan(1);
        expect(bounds.documentWidth).toBeLessThan(width+2);
        proof.push({width,hasDraft,archive,labels,disabledPreviews:2,dispositionSpan:bounds.span});
        if(width===1440&&!hasDraft&&archive)await actions.screenshot({path:testInfo.outputPath("dashboard-summary-saved-archive.png")});
      }
      await page.unroute("**/api/v1/routeBuilder.cfc?**");
      await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
      const ready=page.locator(".fpw-route-detail-actions .js-expedition-trip-preview");
      await ready.first().waitFor();
      await ready.evaluateAll(buttons=>buttons.forEach(button=>{button.disabled=true;button.setAttribute("aria-busy","true");}));
      await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent("pageshow",{persisted:true})));
      for(const button of await ready.all()) {
        expect(await button.isEnabled()).toBe(true);
        expect(await button.getAttribute("aria-busy")).toBeNull();
      }
      await ready.first().evaluate(button=>button.removeAttribute("data-preview-ready"));
      await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent("pageshow",{persisted:true})));
      await expect(ready.first()).toBeDisabled();
      return {states:proof,persistedPageshowHandler:"eligible restored; ineligible and missing readiness disabled",note:"Saved/ineligible/Archive presentation states injected into local fixture route responses."};
    });
  });

  test("ACTIVE route summary retains operational controls and existing grid", async ({ page }, testInfo) => {
    return withFixture(page.request,{activeScheduled:1},async fixture=>{
      await login(page,fixture);
      await page.route(TELEMETRY,route=>route.abort());
      const widths=[];
      for(const width of [1440,390]) {
        await page.setViewportSize({width,height:1000});
        await page.goto(BASE + "/app/dashboard.cfm?dashboardPanel=routes");
        const actions=page.locator(".fpw-route-detail-actions");
        await expect(actions).toBeVisible();
        const labels=await actions.locator("button").allTextContents();
        expect(labels).toEqual(["Open Active Cruise","Edit Route","Follow Page","Cancel"]);
        expect(await page.locator(".fpw-route-detail-actions--saved").count()).toBe(0);
        expect(await actions.locator(".js-expedition-trip-preview").count()).toBe(0);
        expect(await actions.locator(".js-expedition-plan-cancel").getAttribute("data-plan-id")).toBe(String(fixture.floatPlanId));
        for(const button of await actions.locator("button").all())expect(await button.isEnabled()).toBe(true);
        expect(await actions.locator(".js-expedition-plan-cancel").evaluate(button=>getComputedStyle(button).gridColumn)).toBe("auto");
        expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThan(width+2);
        widths.push({width,labels});
        if(width===1440)await actions.screenshot({path:testInfo.outputPath("dashboard-summary-active-unchanged.png")});
      }
      return {widths};
    });
  });

});
