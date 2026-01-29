# FPW Repo Map (Codex)

## Main Entry Points
- app/account.cfm: Account/profile management page wired to account JS and API calls.
- app/dashboard.cfm: Primary dashboard UI with float plan lists, alerts section, and modal wizard launcher.
- app/floatplan-wizard.cfm: Standalone float plan wizard page with multi-step form.
- app/login.cfm: Login page for session-based auth.
- app/forgot-password.cfm: Password reset request page.
- app/reset-password.cfm: Password reset completion page.
- api/v1/floatplan.cfc: Float plan CRUD actions, send-to-contacts flow, and check-in to close active/overdue plans.
- api/v1/floatplans.cfc: Float plan list API plus monitoring tick and monitored-plan summary endpoint.
- assets/js/app/floatplanWizard.js: Client-side wizard logic for loading/saving float plans.
- assets/js/app/dashboard/floatplans.js: Dashboard list UI for float plans, including check-in and delete flows.
- tests/runner.cfm: TestBox runner configuration for FPW spec execution.

## Monitoring / Notification Execution Path
- Monitoring: api/v1/floatplans.cfc (runMonitorTick) -> api/v1/floatplans.cfc (getMonitoredPlans) -> assets/js/app/dashboard.js (TODO polling hook).
- Notifications (precautionary send): api/v1/floatplan.cfc (sendFloatPlanToContacts) -> api/api_assets/floatPlanUtils.cfc (createPDF) -> api/v1/floatplan.cfc (cfmail send + status -> ACTIVE).

## Fragile / Core Logic (Avoid Casual Edits)
- api/v1/floatplan.cfc (save/send/checkin logic and API response shapes).
- api/v1/floatplans.cfc (monitoring tick + monitored plan status math).
- api/api_assets/floatPlanUtils.cfc (PDF generation and float plan data mapping).
- assets/js/app/floatplanWizard.js (wizard state, validation, payload formatting).
- assets/js/app/api.js (API request helper and endpoint wiring).
- tests/integration/FloatPlanSaveTimeShiftSpec.cfc (time regression contract for save/get).
