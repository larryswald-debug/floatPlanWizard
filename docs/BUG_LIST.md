# FPW Bug List

## 2026-04-22 - Intermittent `deleteroute` HTML 500 during Route Builder teardown

- Status: Open
- Area: Route Builder cleanup / saved-route delete lifecycle
- Triggering test: `tests/e2e/e2e/routebuilder-torture-reverse-race.spec.js:177`
- Surfaced in teardown: `tests/e2e/support/routebuilderCleanup.js:60`
- Server transaction boundary: `api/v1/routeBuilder.cfc:3463`

### Proven behavior

- A Route Builder cleanup call to `deleteroute` returned an HTML `500` instead of the normal JSON response.
- Immediately after the warning, the route row and its related normalized route-instance rows were still present, so the delete transaction did not commit.
- A later authenticated delete against the same route succeeded.
- A later full Route Builder rerun passed cleanly (`198 passed`) and did not reproduce the warning.

### Proven root-cause boundary

- The failure was an intermittent unhandled server-side exception inside the `deleteRoute()` transaction block in `api/v1/routeBuilder.cfc`.
- The exact failing SQL statement or exact underlying exception text is still not proven.

### Diagnostic state

- Local diagnostic instrumentation is now present around `deleteRoute()` so a future failure can log structured exception detail.
- Route Builder cleanup logging now emits the full non-JSON `responseBody` for future `deleteroute` failures.

## 2026-04-23 - `auth-login` scenario fails on valid empty-routes dashboard state

- Status: Open
- Area: Dashboard login smoke / non-admin Playwright coverage
- Triggering test: `tests/e2e/scenarios/auth-login.spec.js:7`
- Exact failing assertion: `tests/e2e/scenarios/auth-login.spec.js:13`
- Related canonical readiness helper: `tests/e2e/support/fpwSession.js:23`

### Proven behavior

- The targeted rerun failed deterministically across Chromium, Firefox, and WebKit (`3 failed`).
- The dashboard loaded successfully after login, with:
  - `#missionSummaryTitle = "Mission Summary"`
  - `#expeditionTimelineTitle = "Routes"`
  - `#openRouteBuilderBtn` visible
- The failure is that `#expeditionRouteList` is hidden when the account has no current routes, so the scenario times out waiting for a populated route-list container to be visible.

### Proven root-cause boundary

- The scenario still assumes the post-login dashboard must expose a visible populated route list.
- The current canonical dashboard readiness helper in `tests/e2e/support/fpwSession.js:23` already treats either `#expeditionRouteList` or `#expeditionRouteEmpty` as valid ready states.
- The exact failing assertion in `tests/e2e/scenarios/auth-login.spec.js:13` is therefore stricter than the current dashboard contract.

### Diagnostic state

- No application failure was proven in the targeted rerun.
- This is currently a deterministic test-side failure against the valid empty-routes dashboard state.

## 2026-04-23 - Intermittent broad-run failure in `custom-routes-supported-flows`

- Status: Open
- Area: Custom Routes browser matrix / broad non-admin Playwright sweep
- Surfaced in broad rerun: `tests/e2e/scenarios/custom-routes-supported-flows.spec.js`
- Broad-run failure label: `custom routes cover create, load, waypoint legs, out-and-back, remove, soft-delete/reactivate, and geometry override`

### Proven behavior

- The interrupted broad non-admin Playwright rerun surfaced this scenario as a failure once.
- A targeted rerun immediately afterward passed across Chromium, Firefox, and WebKit (`3 passed`).
- No deterministic failing line or deterministic failing assertion is currently proven from the isolated rerun.

### Proven root-cause boundary

- The failure exists as a broad-run signal only.
- The exact failing step, exact assertion, and exact underlying cause are not yet isolated.

### Diagnostic state

- This currently fits the same pattern as an intermittent or broad-suite interaction issue, not a proven deterministic scenario failure.
- More isolation would be required before describing it as anything more specific.
