# Floatplans timezone debug harness

This harness targets the authenticated Float Plans workflow on the FPW dashboard.

Resolved app target from the repo:
- base URL: `http://localhost:8500`
- page path: `/fpw/app/dashboard.cfm`
- login path: `/fpw/index.cfm`
- ready selector: `#floatPlansPanel`

Why this screen:
- the dashboard list renders UTC-backed float plan timestamps through explicit plan timezones in [assets/js/app/dashboard/floatplans.js](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/floatplans.js)
- the wizard step 2 exposes floating wall-clock inputs in [app/dashboard.cfm](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/dashboard.cfm)
- the save path stores UTC-backed timestamps plus source timezones in [api/v1/floatplan.cfc](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/floatplan.cfc)

The harness keeps the host baseline on `America/New_York` and tests alternate timezones only through fresh Playwright contexts with `timezoneId`.

## Environment variables

- `FLOATPLANS_BASE_URL`
- `FLOATPLANS_PATH`
- `APP_READY_SELECTOR`
- `FLOATPLAN_PROBES`
- `TIME_FIELDS`
- `HOST_TIMEZONE`
- `LOCALE`
- `ALL_TIMEZONES`
- `OUTPUT_DIR`
- `SCREENSHOT_MODE`
- `TEST_INSTANTS`
- `USE_CLOCK`

Defaults:
- `FLOATPLANS_BASE_URL=http://localhost:8500`
- `FLOATPLANS_PATH=/fpw/app/dashboard.cfm`
- `APP_READY_SELECTOR=#floatPlansPanel`
- `HOST_TIMEZONE=America/New_York`
- `LOCALE=en-US`
- `ALL_TIMEZONES=0`
- `OUTPUT_DIR=floatplans-timezone-debug-output`
- `SCREENSHOT_MODE=failures`
- `USE_CLOCK=1`

## Commands

Critical sweep:

```bash
FLOATPLANS_BASE_URL=http://localhost:8500 \
FLOATPLANS_PATH=/fpw/app/dashboard.cfm \
HOST_TIMEZONE=America/New_York \
LOCALE=en-US \
APP_READY_SELECTOR='#floatPlansPanel' \
FLOATPLAN_PROBES="$(cat ./playwright-mcp.floatplans.example.json | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.stringify(JSON.parse(s).probes)))')" \
TIME_FIELDS="$(cat ./playwright-mcp.floatplans.example.json | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.stringify(JSON.parse(s).timeFields)))')" \
SCREENSHOT_MODE=failures \
USE_CLOCK=1 \
ALL_TIMEZONES=0 \
node ./floatplans-timezone-debug.mjs
```

Full sweep:

```bash
FLOATPLANS_BASE_URL=http://localhost:8500 \
FLOATPLANS_PATH=/fpw/app/dashboard.cfm \
HOST_TIMEZONE=America/New_York \
LOCALE=en-US \
APP_READY_SELECTOR='#floatPlansPanel' \
FLOATPLAN_PROBES="$(cat ./playwright-mcp.floatplans.example.json | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.stringify(JSON.parse(s).probes)))')" \
TIME_FIELDS="$(cat ./playwright-mcp.floatplans.example.json | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>console.log(JSON.stringify(JSON.parse(s).timeFields)))')" \
SCREENSHOT_MODE=failures \
USE_CLOCK=1 \
ALL_TIMEZONES=1 \
node ./floatplans-timezone-debug.mjs
```

Package scripts:

```bash
npm run timezone:test:critical
npm run timezone:test:all
```

## Artifacts

Each invocation writes a new run directory under:

`floatplans-timezone-debug-output/`

Per run:
- `resolved-spec.json`
- `fixture.json`
- `auth-state.json`
- `runs/<timezone>.json`
- `summary.json`
- `summary.md`
- `screenshots/*.png` on failures

## Notes

- The connected `mcpcfc` server in this Codex session does not expose `getFloatplansTimezoneSpec`, so the harness inputs were resolved from the live repo and MCPCFC file inspection instead.
- The harness creates a temporary route-backed float plan, uses it for probing, then cleans it up at the end of the run.
- The dashboard page is loaded once per timezone context. The Playwright clock is then moved across the required instants inside that same context. That keeps the all-timezone sweep practical while still freezing deterministic instants for browser and page facts.
