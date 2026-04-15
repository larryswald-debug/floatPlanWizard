# Floatplans timezone debug summary

- Run mode: all
- Base URL: http://localhost:8500
- Path: /fpw/app/dashboard.cfm
- App ready selector: #floatPlansPanel
- Host timezone baseline: America/New_York
- Locale: en-US
- Timezones tested: 418
- Instants tested: 6
- Assertion failures: 0

## Probes

- floatplans-panel: dashboard -> #floatPlansPanel
- plan-row: dashboard -> #floatPlansList [data-plan-id="{{floatPlanId}}"]
- plan-meta: dashboard -> #floatPlansList [data-plan-id="{{floatPlanId}}"] small
- wizard-step-title: edit-step2 -> #floatPlanWizardModal h2.h5
- browser-fixed-now: fact -> browserFixedNowLocal
- departure-input: edit-step2 -> #floatPlanWizardModal [name="DEPARTURE_TIME"]
- departure-timezone: edit-step2 -> #departureTimezone
- return-input: edit-step2 -> #floatPlanWizardModal [name="RETURN_TIME"]
- return-timezone: edit-step2 -> #returnTimezone
- plan-meta: dashboard -> #floatPlansList [data-plan-id="{{floatPlanId}}"] small

## Root-cause patterns

- No assertion mismatches were found in the configured Floatplans fields. The harness mainly confirmed that floating wizard inputs and plan-list renderings stay stable across browser timezone emulation for this screen.

## Failures

- None
