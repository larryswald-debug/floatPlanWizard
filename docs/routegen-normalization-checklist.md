# Route Generator Normalization Checklist

Scope: `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc`

## Migration Order

1. Apply `db/migrations/20260220_01_routegen_normalization_phase1.sql`.
2. Apply `db/migrations/20260220_02_routegen_normalization_backfill.sql`.
3. Verify row counts and key joins.
4. Ship API dual-read/dual-write changes.
5. Flip read preference to normalized tables.
6. Keep legacy writes until parity is confirmed, then retire.

## Shared Helpers (Add First)

- [ ] Add `routegenResolveRouteInstanceByCode(userId, routeCode)` to centralize route ownership + `route_instance_id`.
- [ ] Add `routegenLoadNormalizedLegs(routeInstanceId)` to read ordered legs from `route_instance_legs`.
- [ ] Add `routegenLoadNormalizedProgress(userId, routeInstanceId)` from `route_instance_leg_progress`.
- [ ] Add `routegenGetEffectiveLegRows(userId, routeInstanceId)` precedence:
  - route leg override (`route_leg_user_overrides`)
  - segment override (`user_segment_overrides`)
  - canonical geometry (`segment_geometries`)
  - base leg values (`route_instance_legs`)
- [ ] Add write helpers:
  - `routegenUpsertInstanceSections(routeInstanceId, legsPayload)`
  - `routegenUpsertInstanceLegs(routeInstanceId, legsPayload)`
  - `routegenUpsertLegProgress(userId, routeInstanceId, legsPayload)`

## Endpoint-by-Endpoint Plan

### Route Generation / Update

- [ ] `action=routegen_generate` -> `routegenGenerate`
  - Keep current `loop_routes/loop_sections/loop_segments` writes during transition.
  - Also write `route_instance_sections` + `route_instance_legs` (same ordered legs).
  - Also seed `route_instance_leg_progress`.
- [ ] `action=routegen_update` -> `routegenUpdate`
  - Keep current legacy rewrite path for now.
  - Rebuild normalized sections/legs in the same transaction.
  - Preserve override mapping by leg order using normalized `leg_order`.

### Timeline / Edit Context

- [ ] `action=gettimeline` -> `getTimeline`
  - Read sections/legs/progress from normalized tables first.
  - Use effective values (`computed_nm`, geometry-derived NM overrides).
  - Keep response JSON shape unchanged.
- [ ] `action=routegen_geteditcontext` -> `routegenGetEditContext`
  - Replace legacy leg loads with normalized legs + effective override values.
  - Keep existing edit payload keys unchanged.

### Leg Geometry / Overrides

- [ ] `action=routegen_getleggeometry` -> `routegenGetLegGeometry`
  - Resolve route leg by `(route_instance_id, leg_order)` or normalized leg id mapping.
  - Prefer route-leg override, then segment override, then canonical/default.
- [ ] `action=routegen_savelegoverride` -> `routegenSaveLegOverride`
  - Continue route-leg specific override writes to `route_leg_user_overrides`.
  - Ensure `route_leg_order` matches normalized `leg_order`.
- [ ] `action=routegen_clearlegoverride` -> `routegenClearLegOverride`
  - Delete only route-leg override row; return effective fallback NM from normalized read.
- [ ] `action=routegen_savesegmentoverride` -> `routegenSaveSegmentOverride`
  - Move writes to `user_segment_overrides` (keep legacy write optionally for overlap window).
- [ ] `action=routegen_clearsegmentoverride` -> `routegenClearSegmentOverride`
  - Delete from `user_segment_overrides`; return canonical/default effective values.
- [ ] `action=routegen_listlegoverrides` -> `routegenListLegOverrides`
  - Return route-leg overrides keyed by normalized leg order.

### Float Plans / Route Lifecycle

- [ ] `action=buildfloatplansfromroute` -> `buildFloatPlansFromRoute`
  - Build day aggregates from normalized effective legs.
  - Keep floatplans write behavior unchanged.
- [ ] `action=deleteroute` -> `deleteRoute`
  - Delete normalized artifacts:
    - `route_instance_leg_progress`
    - `route_instance_legs`
    - `route_instance_sections`
    - relevant `route_leg_user_overrides`
    - relevant `user_segment_overrides` (only if scoped cleanup is intended)
  - Keep existing legacy cleanup until cutover is complete.

### Legacy Actions (Maintain Compatibility During Cutover)

- [ ] `action=generateroute` -> `generateRoute`
  - Dual-write normalized tables for old flow parity.
- [ ] `action=generateroutefromtemplate` -> `generateRouteFromTemplate`
  - Dual-write normalized tables for old flow parity.
- [ ] `action=updatesegment` -> `updateSegment`
  - Update normalized leg snapshot fields when legacy loop segment is edited.

## Verification Checklist

- [ ] For each `route_instances.id`, `route_instance_legs` count equals legacy generated leg count.
- [ ] Timeline totals from normalized read match legacy totals before cutover.
- [ ] Save/clear route-leg override changes effective NM immediately and survives reload.
- [ ] Save/clear segment override applies to matching legs and survives reload.
- [ ] Route delete removes normalized rows and does not orphan related data.

## Cutover and Cleanup

- [ ] Add a feature flag for normalized reads (admin-only first).
- [ ] After parity window, stop writing legacy `loop_sections/loop_segments` for route generator paths.
- [ ] Remove fallback code paths only after two successful release cycles.
