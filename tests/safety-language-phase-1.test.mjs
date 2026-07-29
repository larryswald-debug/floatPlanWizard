import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import test from "node:test";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));

function read(relativePath) {
  return readFileSync(path.join(repositoryRoot, relativePath), "utf8");
}

function occurrences(source, phrase) {
  return source.split(phrase).length - 1;
}

const customerFacingFiles = [
  "app/follow.cfm",
  "app/follow-full-map.cfm",
  "app/active-cruise.cfm",
  "app/monitoring.cfm",
  "app/dashboard.cfm",
  "assets/js/app/follow/follow.js",
  "assets/js/app/follow/followFullMap.js",
  "assets/js/app/follow/followMap.js",
  "assets/js/app/home-visual-tour.js",
  "partials/fpw-conversion-landing.cfm",
  "assets/admin/index.cfm",
  "api/v1/floatplan.cfc",
  "api/v1/OverdueAlertService.cfc",
  "api/v1/voyage.cfc"
];

test("removes the audited unsupported phrases from their active customer-facing sources", () => {
  const source = customerFacingFiles.map(read).join("\n").toLowerCase();
  const unsupportedPhrases = [
    "follow along in real time",
    "live now",
    "live route view with current position",
    "float plan monitor",
    "emergency monitor",
    "see how fpw is monitoring",
    "24/7 peace of mind",
    "until you return safely",
    "fpw keeps the plan alive",
    "keeps timing and status current",
    "if the member does not return on time",
    "fpw monitoring alert: missed check-in",
    "fpw monitoring alert: escalated",
    "fpw assistance needed alert"
  ];

  for (const phrase of unsupportedPhrases) {
    assert.equal(source.includes(phrase), false, `Unsupported phrase remains: ${phrase}`);
  }
});

test("labels Follow route progress separately from actual reported check-in GPS", () => {
  const followMarkup = read("app/follow.cfm");
  const followScript = read("assets/js/app/follow/follow.js");
  const mapService = read("api/v1/RouteMapGeometryService.cfc");

  assert.match(followMarkup, /Planned route, estimated route progress, completed legs, and destination\./);
  assert.match(followMarkup, /data-fpw-field="map-position-note"/);
  assert.match(followScript, /Latest reported position:/);
  assert.match(followScript, /Source: /);
  assert.match(followScript, /Updated /);
  assert.match(followScript, /No position update has been reported yet\./);
  assert.match(followScript, /The route-progress marker is estimated and is not the reported position\./);
  assert.match(followScript, /Latest check-in · Updated /);
  assert.match(mapService, /"Estimated route progress"/);
});

test("keeps Active Cruise on the planned-route source and uses shore-contact terminology", () => {
  const activeCruise = read("app/active-cruise.cfm");
  const viewModel = read("api/v1/ActiveCruiseViewModelService.cfc");

  assert.match(activeCruise, /Planned route, reported progress, completed legs, and destination\./);
  assert.match(activeCruise, /No position update has been reported yet\./);
  assert.match(activeCruise, /<h3>Shore Contact<\/h3>/);
  assert.match(activeCruise, /Shore contact not named/);
  assert.match(activeCruise, /aria-label="Shore contact actions"/);
  assert.match(viewModel, /No canonical current-position source is exposed to the Active Cruise V2 view model\./);
  assert.match(viewModel, /Shore contact not named/);
});

test("describes Monitoring as automated and preserves the non-live-tracking limitation", () => {
  const monitoringPage = read("app/monitoring.cfm");
  const monitoringViewModel = read("api/v1/MonitoringConsoleViewModelService.cfc");

  assert.match(monitoringPage, /View the automated monitoring status for/);
  assert.match(monitoringPage, /FPW staff are not continuously watching this trip\./);
  assert.match(monitoringPage, /The shore contact remains responsible/);
  assert.match(monitoringPage, /Not live vessel tracking/);
  assert.match(monitoringViewModel, /This is not continuous live vessel tracking/);
  assert.match(monitoringViewModel, /latest reported position/);
});

test("keeps Basic and Premium delivery-email safety language in parity", () => {
  const floatPlan = read("api/v1/floatplan.cfc");
  const requiredPhrases = [
    "This float plan is precautionary trip information.",
    "If the boater is overdue, first try to contact them using the information provided and follow the response plan you agreed upon.",
    "FPW does not independently verify emergencies or dispatch assistance.",
    "Email delivery is not guaranteed, and FPW does not confirm that a recipient has received or read this message.",
    "Emergency authority information from this float plan:"
  ];

  for (const phrase of requiredPhrases) {
    assert.equal(occurrences(floatPlan, phrase), 2, `Basic/Premium parity failed for: ${phrase}`);
  }
  assert.equal(occurrences(floatPlan, "<cfmailparam type=\"application/pdf\" file=\"#pdfPath#\">"), 2);
});

test("identifies automated and captain-reported alert sources without changing internal status codes", () => {
  const alerts = read("api/v1/OverdueAlertService.cfc");

  assert.match(alerts, /FPW Automated Notice: Scheduled Check-In Not Recorded - /);
  assert.match(alerts, /FPW's automated system did not record the expected check-in by the scheduled time\./);
  assert.match(alerts, /FPW Automated Notice: Check-In Still Unresolved - /);
  assert.match(alerts, /not confirmation of distress or professional emergency escalation\./);
  assert.match(alerts, /FPW Notice: Captain Reported Assistance May Be Needed - /);
  assert.match(alerts, /Notice Source: Captain-reported status/);
  assert.equal(occurrences(alerts, "Electronic-message delivery and receipt are not guaranteed."), 3);
  assert.match(alerts, /"MISSED_OWNER"/);
  assert.match(alerts, /"ESCALATED_CONTACTS"/);
  assert.match(alerts, /"ASSISTANCE_NEEDED"/);
});

test("keeps tour, Welcome, homepage, and reachable demo wording aligned", () => {
  const tour = read("assets/js/app/home-visual-tour.js");
  const home = read("partials/fpw-conversion-landing.cfm");
  const dashboard = read("app/dashboard.cfm");
  const legacyDemo = read("assets/admin/index.cfm");

  assert.match(tour, /label: "Planned route view"/);
  assert.match(tour, /label: "Shore Contact"/);
  assert.match(home, /FPW keeps trip information available\./);
  assert.match(home, /Captains can report updates and check-ins during the trip/);
  assert.match(dashboard, /keep them updated through supported check-ins and notices\./);
  assert.match(legacyDemo, /delivery and response are not guaranteed\./);
  assert.match(legacyDemo, /<strong>Automated<\/strong><span>trip status notices<\/span>/);
});

test("does not introduce the deferred 21-day product rule", () => {
  const source = customerFacingFiles.map(read).join("\n");
  assert.doesNotMatch(source, /\b21[\s-]*days?\b/i);
});
