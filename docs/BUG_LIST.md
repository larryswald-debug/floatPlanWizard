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
