# FPW Test Coverage Matrix

Last updated: 2026-02-23

This matrix maps critical FPW surfaces to automated coverage so uncovered areas are explicit.

## Dashboard UI Modules

| Surface | Primary Tests |
|---|---|
| Vessels CRUD | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-vessels-operators-crud.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |
| Operators CRUD | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-vessels-operators-crud.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |
| Contacts CRUD | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-contacts-passengers-crud.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |
| Passengers CRUD | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-contacts-passengers-crud.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |
| Waypoints CRUD + map click | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-waypoints-crud.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |
| Float-plan list lifecycle (filter/view/clone/delete/check-in wiring) | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-floatplans-lifecycle.spec.js` |
| Weather/tide/alerts widgets (success + empty + error) | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/dashboard-live-widgets.spec.js` |
| Account home-port persistence | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/account-homeport.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/DashboardCrudSpec.cfc` |

## Route Builder UI

| Surface | Primary Tests |
|---|---|
| Template preview/generate flow | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-template.spec.js` |
| Lock panel expand/retry + map action continuity | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-lock-panel.spec.js` |
| Geometry deterministic save/clear/reopen stability | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-map-deterministic.spec.js` |
| Geometry draw gesture (cross-browser fallback) | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-map-gesture.spec.js` |
| Accessibility/performance/concurrency probes | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-accessibility.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-performance.spec.js`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/e2e/routebuilder-concurrency.spec.js` |

## API Integration (TestBox)

| API Component | Covered Actions |
|---|---|
| `floatplan.cfc` | `bootstrap`, `save`, `send` (validation), `clone`, `checkin`, `delete`, `deleteallbyuser/deleteallbyuserid`, invalid action, auth guard via `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/FloatPlanActionsSpec.cfc` |
| `routeBuilder.cfc` | `routegen_getoptions`, `routegen_preview`, `routegen_generate`, `routegen_geteditcontext`, `routegen_update`, `routegen_getleggeometry`, `routegen_savelegoverride`, `routegen_clearlegoverride`, `routegen_listlegoverrides`, `routegen_getleglocks`, auth guard via `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/RouteBuilderActionsSpec.cfc` and `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/RouteLegOverridesSpec.cfc` |
| Route-to-float-plan linkage/build | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/RouteInstancePhase1Spec.cfc`, `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/integration/RouteToFloatPlansBuildSpec.cfc` |

## Mobile Coverage

| Surface | Primary Tests |
|---|---|
| Route builder open/close smoke | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/mobile-smoke.mobile.spec.js` |
| Setup-panel scroll + map overlay reopen | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/tests/e2e/mobile-smoke.mobile.spec.js` |

## Residual Risk

- Real polyline-completion gestures remain less deterministic than API-backed geometry tests; keep one Chromium gesture smoke and rely on deterministic map tests for stable regression detection.
- Shared-user data in dev can create state coupling between tests unless cleanup is consistently run.
