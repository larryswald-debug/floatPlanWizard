# FPW Vessel CRUD Step 2 Safest Fix Snapshot

Created before source edits on 2026-08-31.

## Source hashes (SHA-256)

- `app/dashboard.cfm`: `f29d5c0b1edfd83a6850d29fc93761e222dce19ba53e36cafbd6fefbdc5b0553`
- `assets/js/app/dashboard/vessels.js`: `d1233c2fbf7084c6d0bad69fff856b85f45c5bb4deca878cc7a110fa73495c28`
- `assets/js/app/admin/vessel-manager.js`: `f7ffd61137c74a8b28eff8b0b8d6f2e1300e38dee399eabbdfd3d2d11eedc362`
- `api/v1/vessel.cfc`: `fa3c24b4093c84003dc76d0b6a8f518af6ed249031d99c3f32a8ffce701cd77d`
- `api/v1/vessels.cfc`: `00248ce695acd20c77b8247799b5dec33ad2d41d98b9d765297cae74ff172f2e`
- `api/v1/adminVessels.cfc`: `d8898417964c1b53aa3cfdb2fa838dd699f0e4cb0a5672b02b7988a13b5d9fb1`
- `api/api_assets/floatPlanUtils.cfc`: `516404d5c5d9cc332281ff0513f62f86dadf9fd6375321d234b42534f31a968d`
- `admin/vessel-manager.cfm`: `4db5dc5cd07b0959c92e4c2df73f0ca85bfd84957da052627d9f692811f6a0d9`
- `tests/onboarding-runner.cfm`: `231fda98db558a7f6b9cced6578167843cf78bfa5d7fe601344374bdbac22b4a`

## New paths absent before implementation

- `database/migrations/20260831_002_vessel_fuel_capacities.preflight.sql`
- `database/migrations/20260831_002_vessel_fuel_capacities.up.sql`
- `database/migrations/20260831_002_vessel_fuel_capacities.verify.sql`
- `database/migrations/20260831_002_vessel_fuel_capacities.down.sql`
- `tests/vessel-crud-expanded-fields.test.mjs`
- `tests/vessel-crud-expanded-fields.spec.js`
- `tests/specs/VesselPdfPresentationContractSpec.cfc`
- `tests/vessel-pdf-presentation-runner.cfm`

## Scope decision

The owner selected the Safest Fix. `trailer` is deferred and must not be exposed or otherwise changed in this phase.
