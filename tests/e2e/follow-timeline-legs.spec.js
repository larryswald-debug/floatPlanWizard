const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const HARNESS_PATH = "/fpw/test-harness/follow-timeline-legs.html";
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
    "  <title>Follow Timeline Harness</title>",
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
      title: "Old Tampa Bay - Full Route",
      status: "All Good",
      privacy_mode: "public",
      allow_interactions: true,
      slug: "follow-timeline-test",
      is_owner: false,
      owner_user_id: 187
    },
    sidebar: {
      viewer_count: 0,
      vessel_name: "Big Blue",
      last_checkin: "Apr 14, 2026 7:33 PM",
      last_checkin_utc: "2026-04-14T19:33:50Z",
      privacy_label: "Public share page",
      monitoring_summary: "Active with missed check-in rules enabled",
      monitor_state_text_html: "<strong>Monitoring active</strong><br />No missed check-ins on this voyage",
      monitor_state_label: "Healthy"
    },
    topCards: {
      status: "All Good",
      last_checkin: "Apr 14, 2026 7:33 PM",
      last_checkin_utc: "2026-04-14T19:33:50Z",
      location_label: "Caldesi Island",
      next_stop: "Old Tampa Bay",
      eta: "Apr 14, 2026 6:07 PM",
      eta_utc: "2026-04-14T22:07:53Z",
      conditions: "No active hazards reported"
    },
    pinned: {
      miles: 179.5,
      miles_today_nm: 44.5,
      days: 3,
      locks: 0,
      wildlife: 0,
      updated_label: "Apr 14, 2026 7:33 PM"
    },
    body: {
      page_subtitle: "Follow along in real time: location, progress, updates, comments, and trip confidence.",
      journey_subtitle: "Current leg is active.",
      journey_departed_value: "Home",
      journey_departed_meta: "Apr 14, 2026 4:00 PM",
      journey_departed_meta_utc: "2026-04-14T16:00:00Z",
      journey_checkin_meta: "6 min since last check-in",
      card_status_copy: "Monitoring is active and the trip is reporting normally.",
      card_location_copy: "Heading toward the current active route target.",
      card_destination_copy: "Next major stop and expected overnight destination.",
      card_arrival_copy: "Approximate based on current pace, route progress, and last update.",
      card_conditions_copy: "Current trip conditions and caution state.",
      trip_summary_confidence: "Tracking confidence: Low",
      trip_summary_mode: "Trip mode: Route-based monitoring",
      trip_summary_safety: "Safety state: Normal",
      family_confidence_subtitle: "Built to reassure viewers with plain-language trip and safety status.",
      timeline_next_update: "Within 1 hr",
      journey_checkin_value: "Checked in at Apr 14, 2026 7:33 PM"
    },
    map: {
      routeGeo: {
        type: "MultiLineString",
        coordinates: [
          [
            [-82.74, 28.23],
            [-82.81, 28.03]
          ],
          [
            [-82.81, 28.03],
            [-82.61, 27.94]
          ],
          [
            [-82.61, 27.94],
            [-82.74, 28.23]
          ]
        ]
      },
      pins: [
        { lat: 28.232381, lng: -82.742108, label: "Home", sequence: 1, type: "start" },
        { lat: 28.0325547, lng: -82.8188125, label: "Caldesi Island", sequence: 2, type: "leg_end" },
        { lat: 27.9446465, lng: -82.6143236, label: "Old Tampa Bay", sequence: 3, type: "end" }
      ],
      current: {
        lat: 28.0325547,
        lng: -82.8188125,
        label: "Caldesi Island"
      }
    },
    legWeather: {
      start: {
        available: true,
        summary: "Sunny • Wind 10 mph NW",
        alerts_count: 0,
        top_alert_severity: "",
        forecast_short: "Sunny",
        wind_speed: "10 mph",
        wind_direction: "NW"
      },
      end: {
        available: false,
        summary: "",
        alerts_count: 0,
        top_alert_severity: "",
        forecast_short: "",
        wind_speed: "",
        wind_direction: ""
      },
      conditions: {
        available: true,
        headline: "Leg-start point conditions",
        summary: "Sunny • Wind 10 mph NW",
        meta: "Based on available current leg point weather."
      }
    },
    timeline: {
      summary: {
        total_nm: 156.0,
        total_locks: 0,
        total_hours: 10.84,
        total_days: 2,
        fuel_est: 97.56,
        reserve_est: 32.19,
        required_fuel_est: 129.75,
        max_hours_per_day: 6.5,
        effective_speed_kn: 14.4,
        fuel_burn_gph: 9.0,
        reserve_pct: 33,
        completed_legs: 1
      },
      legs: [
        {
          day_bucket: 1,
          leg_order: 1,
          label: "Home -> Caldesi Island",
          start_name: "Home",
          end_name: "Caldesi Island",
          dist_nm: 17.0,
          hours: 1.18,
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
          cumulative_hours: 1.18,
          progress: {
            percent_complete: 100,
            last_update_ts: "2026-04-14T17:44:28Z"
          }
        },
        {
          day_bucket: 1,
          leg_order: 2,
          label: "Caldesi Island -> Old Tampa Bay",
          start_name: "Caldesi Island",
          end_name: "Old Tampa Bay",
          dist_nm: 63.0,
          hours: 4.38,
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
          cumulative_hours: 5.56,
          progress: {
            percent_complete: 0,
            last_update_ts: "2026-04-14T17:44:53Z"
          }
        },
        {
          day_bucket: 2,
          leg_order: 3,
          label: "Old Tampa Bay -> Home",
          start_name: "Old Tampa Bay",
          end_name: "Home",
          dist_nm: 76.0,
          hours: 5.28,
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
          cumulative_hours: 10.84,
          progress: {
            percent_complete: 0,
            last_update_ts: "2026-04-14T16:38:39Z"
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

async function openFollowTimelineHarness(page) {
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
      body: JSON.stringify(buildPostsPayload())
    });
  });

  await page.goto(`${HARNESS_PATH}?slug=follow-timeline-test&t=token-123&stream_id=115`, {
    waitUntil: "domcontentloaded"
  });
}

test.describe("Follow cruise timeline legs", () => {
  test("renders completed and upcoming route legs in order", async ({ page }) => {
    await openFollowTimelineHarness(page);

    await expect(page.locator("#followLoader")).toBeHidden();
    await expect(page.locator(".app")).toHaveCSS("visibility", "visible");

    const rows = page.locator(".app [data-fpw-field='timeline-events'] .follow-timeline-legwrap");

    await expect(rows).toHaveCount(3);
    await expect(rows.nth(0).locator(".follow-timeline-legidx")).toHaveText("01");
    await expect(rows.nth(1).locator(".follow-timeline-legidx")).toHaveText("02");
    await expect(rows.nth(2).locator(".follow-timeline-legidx")).toHaveText("03");

    await expect(rows.nth(0).locator(".follow-timeline-legname")).toHaveText("Home -> Caldesi Island");
    await expect(rows.nth(1).locator(".follow-timeline-legname")).toHaveText("Caldesi Island -> Old Tampa Bay");
    await expect(rows.nth(2).locator(".follow-timeline-legname")).toHaveText("Old Tampa Bay -> Home");

    await expect(rows.nth(0).locator(".follow-timeline-legmeta")).toContainText("Progress 100%");
    await expect(rows.nth(1).locator(".follow-timeline-legmeta")).toContainText("Progress 0%");
    await expect(rows.nth(2).locator(".follow-timeline-legmeta")).toContainText("Progress 0%");

    await rows.nth(0).locator(".follow-timeline-leg").click();
    await expect(rows.nth(0).locator(".follow-timeline-legpanel")).toBeVisible();
    await expect(rows.nth(0).locator(".follow-timeline-legpaneltitle")).toContainText("Leg 01");
  });
});
