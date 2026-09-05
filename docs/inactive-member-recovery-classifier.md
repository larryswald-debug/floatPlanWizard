# Inactive-Member Recovery Classifier Contract

Status: implemented as a read-only prerequisite. Recovery sending is not enabled or authorized.

## Public contract

`InactiveMemberRecoveryClassifierService.evaluateMember(userId, nowUtc, enrollmentUtc?)` evaluates one current member. It returns the current classification, stable decision code, eligibility flag, UTC stage/activity/recovery clocks, current-stage ledger state, the existing policy decision, and a PII-free evidence summary.

The service does not send email, claim recovery, or write the ledger. It does not create product events, mutate member or product state, add a scheduler, or expose a remote endpoint. A future runner may iterate over `evaluateMember()`; this task deliberately adds no batch report or batch-send surface.

## Precedence and current stage

The exact precedence is **Shared → D → C → B → A**.

- Shared: any ownership-consistent, positive successful-share event, surviving successful receipt, or owned Float Plan initial-send timestamp. It immediately returns `SUPPRESSED_ALREADY_SHARED` and bypasses A–D timing.
- D: at least one owned, lifecycle-clean Float Plan whose current status is `DRAFT`. Active or terminal plans do not count.
- C: no D/Shared evidence and at least one owned saved `user_routes` record or clean, owned `PLANNED` route instance. A saved named route with zero legs counts as C.
- B: no C/D/Shared evidence and at least one currently owned vessel.
- A: a current account with no verified higher-stage evidence.

Durable evidence of a higher previously reached stage prevents downgrade after deletion. Conflicting ownership, lifecycle, history, or future clocks return a hold; the classifier does not repair or reinterpret records.

## Stage-entry clocks

Stage entry uses the first durable UTC event for the selected stage:

| Stage | Required source |
| --- | --- |
| A | `sign_up`, entity `user`, source `member_signup`, matching current user ID |
| B | `vessel_created`, entity `vessel`, source `member_api` |
| C | earliest of `user_route_created`/`user_route` and `route_created`/`route_instance`, source `member_api` |
| D | `float_plan_created`, entity `float_plan`, source `member_api` |

Current rows never substitute for a missing durable stage clock. Existing local row timestamps with unproven timezone provenance are not backfilled or promoted to stage-entry authority.

## Activity and enrollment

The latest activity query is the maximum `product_events.occurred_at_utc` for the member, source `member_api`, and this exact allowlist:

`vessel_created`, `vessel_updated`, `shore_contact_created`, `shore_contact_updated`, `operator_created`, `operator_updated`, `passenger_created`, `passenger_updated`, `waypoint_created`, `waypoint_updated`, `user_route_created`, `user_route_updated`, `route_created`, `route_updated`, `route_segment_updated`, `float_plan_created`, `float_plan_updated`.

A null result is reported as `NO_QUALIFYING_ACTIVITY_EVIDENCE`; it is not presented as proven inactivity. In this narrow service, a caller-supplied enrollment UTC is an explicit upstream attestation that stage, activity, sharing, and recovery coverage from enrollment was reviewed. Missing enrollment returns `ENROLLMENT_EVIDENCE_REQUIRED`. No enrollment record or timestamp is invented.

## Suppression authorities

- Share: `basic_send_completed` from `basic_save_send`/`basic_review_send`; `premium_send_completed` from `premium_save_send`; successful Basic and Premium receipts; and owned `floatplans.initialSentAt`.
- Recovery ledger: reads the current-stage status and latest successful recovery across all stages from `inactive_member_recovery_deliveries`. `SENT` and unresolved `CLAIMED` states suppress. `FAILED` returns `HOLD_RETRY_DECISION_REQUIRED`; the classifier does not decide or claim a retry.
- Preferences: `EmailOptOutService.isOptedOut(email, "non_essential")`; lookup failure holds closed.
- Administrator: the existing authoritative active entitlement check in `AdminAuthorizationService`; no email/name heuristic.
- Test account: no canonical production flag exists. `TEST_ACCOUNT_SUPPRESSION REQUIRES EXPLICIT CONFIG/INPUT`; the classifier adds no heuristic.
- Recipient: current invalid email suppresses; more than one current user with the same normalized email holds as ambiguous.
- Active work: active Float Plans, started-but-unfinished routes/legs, and enabled unresolved monitoring suppress as `SUPPRESSED_ACTIVE_TRIP`.

## Policy mapping and stable outcomes

After fact verification, the classifier calls the existing `InactiveMemberRecoveryPolicy.evaluate()` method. It supplies the selected stage, durable stage-entry UTC, latest qualifying activity UTC when present, explicit enrollment UTC, latest recovery-sent UTC when present, current-stage send state, verified exclusion booleans, and current UTC. The policy remains the sole authority for the 604,800-second threshold, recent-activity delay, and cross-stage spacing.

Stable outcomes include `ELIGIBLE`, `SUPPRESSED_ALREADY_SHARED`, `SUPPRESSED_OPTED_OUT`, `SUPPRESSED_ADMIN`, `SUPPRESSED_INVALID_EMAIL`, `SUPPRESSED_ACTIVE_TRIP`, `SUPPRESSED_STAGE_ALREADY_SENT`, `SUPPRESSED_UNRESOLVED_CLAIM`, `SUPPRESSED_RECENT_ACTIVITY`, `SUPPRESSED_CROSS_STAGE_SPACING`, `HOLD_INCOMPLETE_STAGE_CLOCK`, `HOLD_INCOMPLETE_ACTIVITY_EVIDENCE`, `HOLD_CONTRADICTORY_EVIDENCE`, `HOLD_PREFERENCE_LOOKUP_FAILED`, `HOLD_DUPLICATE_EMAIL_IDENTITY`, and `MEMBER_NOT_FOUND`. Additional narrow outcomes are `ENROLLMENT_EVIDENCE_REQUIRED`, `HOLD_ADMIN_LOOKUP_FAILED`, `HOLD_RETRY_DECISION_REQUIRED`, and `DEFERRED_WAITING_FOR_INTERVAL`.

Diagnostics contain only IDs, classifications, stable codes, generic event/source names, booleans, ledger state, and canonical UTC timestamps. They exclude names, email addresses, coordinates, Float Plan content, Follow tokens, and private trip details.

## Historical limitation

The implementation is conservative and forward-looking. Existing positive creation/share events remain useful evidence, but missing historical events, edits, or receipts are not reconstructed from current rows, login times, file timestamps, or mixed-local database timestamps. A current object with no verified stage-entry event is held instead of treated as old enough to contact.
