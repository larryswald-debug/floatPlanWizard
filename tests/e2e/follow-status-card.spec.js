const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const HARNESS_PATH = "/fpw/test-harness/follow-status-card.html";
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
    "  <title>Follow Status Card Harness</title>",
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

function buildBootstrapPayload(overrides = {}) {
  const topCardsStatus = overrides.topCardsStatus || "All Good";
  const voyageProgressStatus = overrides.voyageProgressStatus || topCardsStatus;
  const voyageProgressStatusVariant = overrides.voyageProgressStatusVariant || "good";
  const voyageProgressStatusCopy = overrides.voyageProgressStatusCopy || "Monitoring is active and the trip is reporting normally.";

  return {
    SUCCESS: true,
    AUTH: true,
    stream: {
      id: 115,
      stream_id: 115,
      title: "Caldesi to Old Tampa Bay",
      status: topCardsStatus,
      privacy_mode: "public",
      allow_interactions: true,
      slug: "follow-status-card-test",
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
      status: topCardsStatus,
      voyage_progress_status: voyageProgressStatus,
      voyage_progress_status_variant: voyageProgressStatusVariant,
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
      voyage_progress_status_copy: voyageProgressStatusCopy,
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
    posts: []
  };
}

async function openFollowStatusCardHarness(page, bootstrapPayload) {
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
      body: JSON.stringify(bootstrapPayload)
    });
  });

  await page.route("**/api/v1/voyage.cfc?method=handle&action=listPosts&returnFormat=json", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildPostsPayload())
    });
  });

  await page.goto(`${HARNESS_PATH}?slug=follow-status-card-test&t=token-123&stream_id=115`, {
    waitUntil: "domcontentloaded"
  });

  await expect(page.locator("#followLoader")).toBeHidden();
}

[
  {
    name: "Delayed",
    payload: buildBootstrapPayload({
      topCardsStatus: "All Good",
      voyageProgressStatus: "Delayed",
      voyageProgressStatusVariant: "warning",
      voyageProgressStatusCopy: "Latest check-in reported Delayed."
    }),
    expectedTitle: "Delayed",
    expectedCopy: "Latest check-in reported Delayed.",
    expectedDotColor: "rgb(255, 184, 77)",
    expectedPillColor: "rgb(35, 139, 77)"
  },
  {
    name: "Changed Plan",
    payload: buildBootstrapPayload({
      topCardsStatus: "All Good",
      voyageProgressStatus: "Changed Plan",
      voyageProgressStatusVariant: "warning",
      voyageProgressStatusCopy: "Latest check-in reported Changed Plan."
    }),
    expectedTitle: "Changed Plan",
    expectedCopy: "Latest check-in reported Changed Plan.",
    expectedDotColor: "rgb(255, 184, 77)",
    expectedPillColor: "rgb(35, 139, 77)"
  },
  {
    name: "Assistance Needed",
    payload: buildBootstrapPayload({
      topCardsStatus: "All Good",
      voyageProgressStatus: "Assistance Needed",
      voyageProgressStatusVariant: "danger",
      voyageProgressStatusCopy: "Latest check-in reported Assistance Needed."
    }),
    expectedTitle: "Assistance Needed",
    expectedCopy: "Latest check-in reported Assistance Needed.",
    expectedDotColor: "rgb(239, 90, 90)",
    expectedPillColor: "rgb(200, 61, 61)"
  },
  {
    name: "All Good",
    payload: buildBootstrapPayload({
      topCardsStatus: "All Good",
      voyageProgressStatus: "All Good",
      voyageProgressStatusVariant: "good",
      voyageProgressStatusCopy: "Monitoring is active and the trip is reporting normally."
    }),
    expectedTitle: "All Good",
    expectedCopy: "Monitoring is active and the trip is reporting normally.",
    expectedDotColor: "rgb(43, 191, 101)",
    expectedPillColor: "rgb(35, 139, 77)"
  }
].forEach(({ name, payload, expectedTitle, expectedCopy, expectedDotColor, expectedPillColor }) => {
  test(`Follow Voyage Progress reflects ${name} without changing other status surfaces`, async ({ page }) => {
    await openFollowStatusCardHarness(page, payload);

    await expect(page.locator(".app [data-fpw-field='trip-card-status-pill']")).toHaveText("All Good");
    await expect(page.locator(".app [data-fpw-field='journey-status-pill']")).toHaveText(expectedTitle);
    await expect(page.locator(".app [data-fpw-field='card-status-title']")).toHaveText(expectedTitle);
    await expect(page.locator(".app [data-fpw-field='card-status-value']")).toHaveText("Apr 14, 2026 2:15 PM");
    await expect(page.locator(".app [data-fpw-field='card-status-copy']")).toHaveText(expectedCopy);
    await expect(page.locator(".app [data-fpw-field='journey-status-pill']")).toHaveCSS("color", expectedPillColor);
    await expect(page.locator(".app .status-dot")).toHaveCSS("background-color", expectedDotColor);
  });
});
