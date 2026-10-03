# Recovery Center observability and backend validation

Local implementation evidence, 2026-10-03 UTC. This document records this subsystem's work; the full Recovery Center completion report owns rollout, exact email copy, browser screenshots, and final repository state.

## Implemented contracts

Automated contact number (1–3), current destination A–D, transport attempt number, and observed engagement are separate fields. The existing delivery ledger remains the sending authority. Observability never authorizes another send.

- Runs preserve settings revisions and timing values, initial evaluations, terminal outcomes, and explicitly incomplete telemetry. The sender calls beginRun, recordEvaluation, finalizeEvaluation, prepareMessage, finalizeMessage, and finishRun; each optional hook is isolated from delivery authority.
- Evaluations retain initial decision/reason/eligibility separately from final cancellation/send outcomes. The stored timing context includes classifier source timestamps, policy anchors, state revision, settings, and contact history. Authoritative destination resolution populates typed destination fields.
- Message preparation stores an immutable attempt snapshot before transport: recipient, subject, text/HTML, destination and object, contact number, template/version, administrator for personal mail, and transport attempt. Finalization changes only permitted terminal status/timestamps; a later attempt does not rewrite the earlier content.
- Only confirmed accepted automated messages receive attribution deadlines. Accepted means transport acceptance confirmed in the ledger; it does not claim delivery, a bounce result, a human open, or engagement. An uncertain message cannot be tracked or attributed as accepted.
- Personal messages use durable submission identities and separate snapshots, with no automated contact, tracking token, or attribution window.

## Tracking, previews, attribution

Open/click tokens contain a random 256-bit public reference and a purpose-bound HMAC; they contain no user ID, email address, or destination payload. Signatures use constant-time comparison. Tracking requires an accepted automated message and a database UTC timestamp within 90 days of acceptance. A second guarded mutation check prevents recording an event if the token expires after verification.

Invalid/expired opens return the ordinary transparent image. Invalid/expired clicks return the fixed mounted FPW entry point. Clicks validate the stored action path, re-resolve owned destination objects through the existing destination service, and use the existing authentication continuation. A token never establishes a member session. Wrong-member authenticated clicks cannot bypass ownership. Endpoints apply no-store and no-referrer headers.

The message stores independent open/click counters, first/latest signal timestamps, and late-signal counters. Product events retain one idempotent first open/click event; repeat counts do not manufacture repeated engagement. Late signals remain visible without extending attribution.

Attribution selects the latest accepted automated message for the same member whose frozen attribution interval contains the original activity timestamp. Existing canonical member API mutations and successful sharing contracts establish meaningful activity. Login and authenticated page return establish Returned only. Views, opens, clicks, future events, mismatched event/entity contracts, and ordinary login do not establish engagement. Source-event locking and idempotency keys deduplicate reconciliation, while stored source timestamps prevent delayed observation from changing the reporting period.

The Application post-request hook runs only for an authenticated-page marker or a member API endpoint, excludes admin/failed requests, and catches observation failures. Tracking pages and test endpoints do not run that observation hook. A bounded reconciliation pass provides recovery for missed optional observations.

Historical previews use the stored rendering, redact raw and encoded bearer values, remove tracking images and active resources, and disable links. The entity-encoded unsubscribe-token regression is covered. Preview never records a tracking event.

## Files

Existing files changed, under pre-edit snapshot coverage `.codex-snapshots/20261003T165055Z-recovery-center/files`:

- `Application.cfc`: narrowly scoped nonfatal post-request observation, failed-request marker, sensitive authIntent log-key redaction.
- `includes/require_auth.cfm`: successful authenticated GET marker.
- `includes/ProductEventService.cfc`: allowlisted recovery observation/admin events and constrained source-event/admin metadata.

New implementation files:

- `includes/InactiveMemberRecoveryObservabilityService.cfc`
- `includes/InactiveMemberRecoveryTrackingService.cfc`
- `includes/InactiveMemberRecoveryAttributionService.cfc`
- `app/recovery-open.cfm`
- `app/recovery-click.cfm`

New validation files:

- `tests/specs/InactiveMemberRecoveryObservabilitySpec.cfc`
- `tests/inactive-member-recovery-observability-runner.cfm`
- `tests/specs/InactiveMemberRecoverySettingsSpec.cfc`
- `tests/inactive-member-recovery-settings-runner.cfm`
- `docs/recovery-center-observability-validation.md`

Integration sources inspected include the ledger, classifier, policy, enrollment/coverage, destination/action-path, authentication continuation, settings/state, admin Recovery Center, sender, email builder, migration DDL, and existing member activity contracts. Their implementation ownership and complete changed-file inventory are in the main report.

## Runtime validation

All calls used MCPCFC against the local ColdFusion application and the verified `fpw` database. No real mail transport was used by these suites. Runners require localhost/port 8500, the exact confirmation value, and DATABASE() = fpw.

| Suite | Execution at this subtask boundary | Result |
| --- | --- | --- |
| Recovery settings/state/reset | 2026-10-03 17:31:04 UTC | 15 passed, 0 failed, 0 errors |
| Recovery observability/tracking/attribution/reporting | 2026-10-03 17:33:56 UTC | 28 passed, 0 failed, 0 errors |

The 28 observability cases cover stable initial/final decisions; explicit telemetry gaps; purpose-bound opaque tokens; repeated and concurrent signal counting; signature tampering; unaccepted and expired messages; expiry between validation and mutation; late signals; encoded-token preview redaction; latest-message attribution; login/page return without engagement; frozen-window boundaries and original timestamps; same-member isolation; personal replay/separation; terminal-status immutability; authentication continuation; invalid destinations and deleted-draft fallback; wrong-member clicks; enrollment ownership; future/mismatched sources; contact/destination/template combinations; independent accepted-message denominators; source-period versus accepted-cohort reporting; missing historical tracking; persisted run totals; failure/accepted-retry/deadline/engagement Needs Attention behavior; distinct paginated results; and three independent contacts sharing destination C.

The 15 settings/state/reset cases cover strict independent 1–720-hour settings and defaults; current uncached reads; read-only impact preview; settings old/new audit and stale-confirmation rejection; transactional audit failure rollback; state controls preserving clocks and contact history; exclusion and resume; corrupt canonical enrollment returning HELD/Unknown without false contact or queue/dashboard failure; cross-member enrollment rejection; one whole-second database UTC reset anchor; unchanged enrollment metadata/product evidence and zero sends/claims; later signup timing; nonempty-ledger reset refusal; and stale cohort/audit-failure rollback.

The reset tests use disposable canonical accounts and enclosing rollback transactions. They do not perform the actual baseline reset. The new-signup post-reset test uses a rollback-scoped reset marker because ColdFusion does not permit its normal read-committed signup transaction inside the serializable reset wrapper.

The final new Needs Attention case initially used the new-contact claim method for a retry; correcting the test to call the existing retryFailedContact method produced the final 28/28 pass. An earlier browser-discovered encoded-token preview leak and a final review-discovered expiry race were fixed and included in the passing regressions.

## Cleanup and rollout boundary

After the final suite, direct read-only database verification showed:

- 0 disposable observability/settings users.
- 0 delivery ledger rows, 0 message rows, and 0 member-state rows.
- The original 2 recovery enrollment events still present.
- Settings revision 3 after the separately authorized UI same-value save; values remain 24/24/24 hours.
- Actual one-time reset timestamp still NULL at this test boundary.

The shared test lane was then released to the parent for a clean database backup and the separately coordinated local baseline reset. Final reset population/T0 and later cleanup are recorded by the main rollout report.

This proof is local. It does not establish production deployment, production schedule execution, real inbox delivery, provider bounce/webhook behavior, or tracking completeness for messages that were sent without optional telemetry. Optional reporting gaps are shown explicitly; required state/timing/authorization/preferences and contact progression remain fail-closed in the core sender.

## Final pagination follow-up

After the real reset, the affected observability/reporting suite passed **29/29**, including a new complete-history pagination regression: 201 messages, 201 evaluations, history beyond 100 rows, settings audit beyond 30 rows, safe selectors and at most 100 rows per response. Targeted MCP Playwright proof passed **33/33**, with zero console errors and preserved actual reset/run30. See the presentation and completion reports for the final exact evidence and cleanup. The earlier 28-test result above remains the recorded pre-reset execution.
