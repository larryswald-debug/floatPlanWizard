const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const HARNESS_PATH = "/fpw/test-harness/follow-loader.html";
const FOLLOW_TEMPLATE = fs.readFileSync(
  path.join(__dirname, "../../app/follow.cfm"),
  "utf8"
);
const FOLLOW_BODY = extractBetween(
  FOLLOW_TEMPLATE,
  '<body class="follow-body follow-loading">',
  '<script id="followPageContext" type="application/json">'
).trim();

function extractBetween(html, startMarker, endMarker) {
  const startIndex = html.indexOf(startMarker);
  const endIndex = html.indexOf(endMarker);

  if (startIndex === -1) {
    throw new Error(`Unable to locate start marker: ${startMarker}`);
  }
  if (endIndex === -1 || endIndex <= startIndex) {
    throw new Error(`Unable to locate end marker after ${startMarker}`);
  }

  return html.slice(startIndex + startMarker.length, endIndex);
}

function buildHarnessHtml() {
  return [
    "<!DOCTYPE html>",
    '<html lang="en">',
    "<head>",
    '  <meta charset="UTF-8">',
    '  <meta name="viewport" content="width=device-width, initial-scale=1">',
    "  <title>Follow Loader Harness</title>",
    '  <script>window.FPW_BASE = "/fpw"; window.FPW_API_BASE = "/fpw/api/v1";</script>',
    '  <link rel="stylesheet" href="http://localhost:8500/fpw/assets/css/follow.css">',
    "  <script>",
    "    window.L = {",
    "      map: function () {",
    "        return {",
    "          setView: function () { return this; },",
    "          fitBounds: function () { return this; }",
    "        };",
    "      },",
    "      tileLayer: function () {",
    "        return { addTo: function () { return this; } };",
    "      },",
    "      layerGroup: function () {",
    "        return {",
    "          addTo: function () { return this; },",
    "          clearLayers: function () {}",
    "        };",
    "      },",
    "      polyline: function () {",
    "        return { addTo: function () { return this; } };",
    "      },",
    "      marker: function () {",
    "        return {",
    "          addTo: function () { return this; },",
    "          bindTooltip: function () { return this; },",
    "          setLatLng: function () { return this; }",
    "        };",
    "      },",
    "      divIcon: function () { return {}; },",
    "      latLngBounds: function (coords) { return coords; }",
    "    };",
    "  </script>",
    "</head>",
    '<body class="follow-body follow-loading">',
    FOLLOW_BODY,
    '  <script id="followPageContext" type="application/json">{"fpwBase":"/fpw"}</script>',
    '  <script src="http://localhost:8500/fpw/assets/js/app/follow/followMap.js"></script>',
    '  <script src="http://localhost:8500/fpw/assets/js/app/follow/follow.js"></script>',
    "</body>",
    "</html>"
  ].join("\n");
}

function buildBootstrapPayload() {
  return {
    SUCCESS: true,
    AUTH: true,
    stream: {
      id: 115,
      stream_id: 115,
      title: "Caldesi to Old Tampa Bay",
      status: "Underway",
      privacy_mode: "public",
      allow_interactions: true,
      slug: "follow-loader-test",
      is_owner: false,
      owner_user_id: 187
    },
    sidebar: {
      viewer_count: 4,
      vessel_name: "Waypoint Runner",
      last_checkin: "Apr 14, 2026 2:15 PM",
      last_checkin_utc: "2026-04-14T18:15:00Z",
      privacy_label: "Public",
      monitoring_summary: "Active with missed check-in rules enabled",
      monitor_state_text_html: "<strong>Monitoring active</strong><br />No missed check-ins on this voyage",
      monitor_state_label: "Healthy"
    },
    topCards: {
      status: "Underway",
      last_checkin: "Apr 14, 2026 2:15 PM",
      last_checkin_utc: "2026-04-14T18:15:00Z",
      location_label: "Caldesi Island",
      next_stop: "Old Tampa Bay",
      eta: "Apr 14, 2026 6:00 PM",
      eta_utc: "2026-04-14T22:00:00Z",
      conditions: "No active hazards reported"
    },
    pinned: {
      miles: 42.4,
      miles_today_nm: 18.2,
      days: 2,
      locks: 0,
      wildlife: 1,
      updated_label: "Apr 14, 2026 2:15 PM"
    },
    body: {
      page_subtitle: "Follow along in real time: location, progress, updates, comments, and trip confidence.",
      journey_subtitle: "Current leg is active.",
      journey_departed_value: "Home Port",
      journey_departed_meta: "Apr 14, 2026 8:00 AM",
      journey_departed_meta_utc: "2026-04-14T12:00:00Z",
      journey_checkin_meta: "Next update expected within 1 hr.",
      card_status_copy: "Monitoring is active and the trip is reporting normally.",
      card_location_copy: "Heading toward the current active route target.",
      card_destination_copy: "Next major stop and expected overnight destination.",
      card_arrival_copy: "Approximate based on current pace, route progress, and last update.",
      card_conditions_copy: "Current trip conditions and caution state.",
      trip_summary_confidence: "Tracking confidence: High",
      trip_summary_mode: "Trip mode: Route-based monitoring",
      trip_summary_safety: "Safety state: Normal",
      family_confidence_subtitle: "Built to reassure viewers with plain-language trip and safety status.",
      timeline_next_update: "Within 1 hr"
    },
    map: {
      routeGeo: {
        type: "MultiLineString",
        coordinates: [
          [
            [-82.84, 28.03],
            [-82.78, 27.99]
          ]
        ]
      },
      pins: [
        { lat: 28.03, lng: -82.84, label: "Caldesi Island", sequence: 1, type: "start" },
        { lat: 27.99, lng: -82.78, label: "Old Tampa Bay", sequence: 2, type: "end" }
      ],
      current: {
        lat: 28.03,
        lng: -82.84,
        label: "Caldesi Island"
      }
    },
    legWeather: {
      start: {
        available: true,
        summary: "Light chop",
        alerts_count: 0,
        top_alert_severity: "",
        forecast_short: "Clear",
        wind_speed: "6 mph",
        wind_direction: "ESE"
      },
      end: {
        available: true,
        summary: "Calm",
        alerts_count: 0,
        top_alert_severity: "",
        forecast_short: "Clear",
        wind_speed: "5 mph",
        wind_direction: "SE"
      },
      conditions: {
        available: true,
        headline: "Current leg endpoint conditions",
        summary: "Calm",
        meta: "Based on current leg start and next stop point weather."
      }
    },
    timeline: {
      summary: {
        total_nm: 42.4,
        total_locks: 0,
        total_hours: 8.5,
        total_days: 2,
        fuel_est: 25.4,
        reserve_est: 5.1,
        required_fuel_est: 30.5,
        max_hours_per_day: 8.5,
        effective_speed_kn: 12.0,
        fuel_burn_gph: 3.0,
        reserve_pct: 20,
        completed_legs: 0
      },
      legs: [
        {
          day_bucket: 1,
          leg_order: 1,
          label: "Caldesi Island -> Old Tampa Bay",
          start_name: "Caldesi Island",
          end_name: "Old Tampa Bay",
          dist_nm: 18.2,
          hours: 1.5,
          locks: 0,
          lock_details: {
            lock_count: 0,
            lock_message: "No locks mapped for this leg.",
            totals: {
              base_cycle_min: 0,
              best_wait_min: 0,
              typical_wait_min: 0,
              worst_wait_min: 0
            },
            locks: []
          },
          cumulative_hours: 1.5,
          progress: {
            percent_complete: 55,
            last_update_ts: "2026-04-14T18:15:00Z"
          }
        }
      ],
      meta: {
        inputs_source: "route_instances.routegen_inputs_json",
        missing_inputs: [],
        zero_speed_guard: false,
        progress_source: "route_instance_leg_progress",
        formula: "leg_hours=dist_nm/effective_speed_kn;day_bucket=ceil(cumulative_hours/max_hours_per_day)",
        rounding: { nm_decimals: 2, hours_decimals: 2, fuel_decimals: 2 }
      }
    }
  };
}

function buildPostsPayload() {
  return {
    SUCCESS: true,
    AUTH: true,
    posts: [
      {
        id: 901,
        stream_id: 115,
        author_type: "owner",
        title: "Made good time through the pass",
        body: "Conditions stayed calm and the route is on schedule.",
        post_type: "text",
        event_type: "",
        location_label: "Caldesi Island",
        media_url: "",
        media_thumb_url: "",
        created_utc: "2026-04-14T18:10:00Z",
        reaction_counts: { like: 1, love: 0, boat: 1, wave: 0 },
        viewer_reactions: {},
        comments: []
      }
    ]
  };
}

async function openFollowLoaderHarness(page, options = {}) {
  const bootstrapDelayMs = options.bootstrapDelayMs === undefined ? 250 : options.bootstrapDelayMs;
  const postsDelayMs = options.postsDelayMs === undefined ? 250 : options.postsDelayMs;
  const bootstrapPayload = options.bootstrapPayload || buildBootstrapPayload();
  const postsPayload = options.postsPayload || buildPostsPayload();

  await page.addInitScript(() => {
    const pushUnique = (list, value) => {
      const nextValue = String(value || "").trim();
      if (!nextValue) return;
      if (list[list.length - 1] === nextValue) return;
      list.push(nextValue);
    };

    window.__followLoaderHistory = { phases: [], percents: [] };
    const textContentDescriptor = Object.getOwnPropertyDescriptor(Node.prototype, "textContent");

    if (textContentDescriptor && textContentDescriptor.get && textContentDescriptor.set) {
      Object.defineProperty(Node.prototype, "textContent", {
        configurable: true,
        enumerable: textContentDescriptor.enumerable,
        get() {
          return textContentDescriptor.get.call(this);
        },
        set(value) {
          if (this && this.id === "followLoaderPhase") {
            pushUnique(window.__followLoaderHistory.phases, value);
          }
          if (this && this.id === "followLoaderPercent") {
            pushUnique(window.__followLoaderHistory.percents, value);
          }
          return textContentDescriptor.set.call(this, value);
        }
      });
    }

    document.addEventListener("DOMContentLoaded", () => {
      const phaseEl = document.getElementById("followLoaderPhase");
      const percentEl = document.getElementById("followLoaderPercent");
      pushUnique(window.__followLoaderHistory.phases, phaseEl ? phaseEl.textContent : "");
      pushUnique(window.__followLoaderHistory.percents, percentEl ? percentEl.textContent : "");
    });
  });

  await page.route(`**${HARNESS_PATH}**`, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "text/html",
      body: buildHarnessHtml()
    });
  });

  await page.route("**/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&returnFormat=json", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, bootstrapDelayMs));
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(bootstrapPayload)
    });
  });

  await page.route("**/api/v1/voyage.cfc?method=handle&action=listPosts&returnFormat=json", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, postsDelayMs));
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(postsPayload)
    });
  });

  await page.goto(`${HARNESS_PATH}?slug=follow-loader-test&t=token-123&stream_id=115`, {
    waitUntil: "domcontentloaded"
  });
}

test.describe("Follow loader overlay", () => {
  test("blocks the Follow shell until bootstrapStream fully completes", async ({ page }) => {
    await openFollowLoaderHarness(page, {
      bootstrapDelayMs: 800,
      postsDelayMs: 800
    });

    const loader = page.locator("#followLoader");
    const app = page.locator(".app");

    await expect(loader).toBeVisible();
    await expect(page.locator("#followLoaderPhase")).toHaveText("Follow Page Loading");
    await expect(page.locator("#followLoaderPercent")).toHaveText("18%");
    await expect(app).toHaveCSS("visibility", "hidden");
    await expect(page.locator(".app [data-fpw-field='page-title']")).not.toBeVisible();

    await expect(page.locator("#followLoaderPercent")).toHaveText("92%");
    await expect(page.locator("#followLoaderPhase")).toHaveText("Finalizing Display");
    await expect(page.locator("#followLoaderMessage")).toHaveText("Loading voyage stream posts.");

    await expect(loader).toBeHidden();
    await expect(app).toHaveCSS("visibility", "visible");
    await expect(page.locator(".app [data-fpw-field='page-title']")).toHaveText("Caldesi to Old Tampa Bay");
    await expect(page.locator(".app [data-fpw-field='journey-current-leg-value']")).toHaveText("Caldesi Island -> Old Tampa Bay");
    await expect(page.locator(".app [data-fpw-field='stream-feed'] .feed-card")).toHaveCount(1);

    const loaderHistory = await page.evaluate(() => window.__followLoaderHistory || { phases: [], percents: [] });
    expect(loaderHistory.phases).toEqual(expect.arrayContaining([
      "Follow Page Loading",
      "Float Plan Loading",
      "Weather Loading",
      "Route Loading",
      "Finalizing Display"
    ]));
    expect(loaderHistory.percents).toEqual(expect.arrayContaining([
      "18%",
      "38%",
      "58%",
      "78%",
      "92%"
    ]));
  });

  test("keeps the loader visible and surfaces the caught error text on failure", async ({ page }) => {
    await page.route(`**${HARNESS_PATH}**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "text/html",
        body: buildHarnessHtml()
      });
    });

    await page.route("**/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&returnFormat=json", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(buildBootstrapPayload())
      });
    });

    await page.route("**/api/v1/voyage.cfc?method=handle&action=listPosts&returnFormat=json", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          SUCCESS: false,
          ERROR: { MESSAGE: "Unable to load voyage stream." }
        })
      });
    });

    await page.goto(`${HARNESS_PATH}?slug=follow-loader-test&t=token-123&stream_id=115`, {
      waitUntil: "domcontentloaded"
    });

    const loader = page.locator("#followLoader");
    const app = page.locator(".app");

    await expect(loader).toBeVisible();
    await expect(app).toHaveCSS("visibility", "hidden");
    await expect(page.locator("#followLoaderMessage")).toHaveText("Unable to load voyage stream.");
    await expect(page.locator("#followLoaderPhase")).toHaveText("Finalizing Display");
  });
});
