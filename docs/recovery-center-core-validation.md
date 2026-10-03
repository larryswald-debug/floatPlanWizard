# Recovery Center core implementation and validation

Validated locally on 2026-10-03 through MCPCFC against the `fpw` datasource. This records the contact-sequence engine work; the Recovery Center UI, email copy, schema/settings/state, tracking, and attribution have separate validation evidence.

## Implemented behavior

Exactly three recovery contacts share the member's immutable canonical enrollment event ID. A/B/C/D is recalculated product progress and current recovery destination; it is never a contact counter. The existing ledger now claims `(recovery_enrollment_event_id,contact_number)`, keeps `destination_stage` separate, and retains the three-attempt transport cap. No automatic restart or fourth contact exists.

The classifier reads current database timing settings and effective member start/state. The enrollment timestamp remains the original immutable event time. The first contact uses First Recovery Delay; later contacts require their preceding accepted contact and Recovery Stage Interval, plus the existing progress/activity clocks and safeguards. Actual destination changes require valid canonical product evidence.

The existing sender evaluates before claiming, re-evaluates under the member lock, builds the numbered contact for the current verified destination, and independently rechecks eligibility, destination ownership, recipient, compliance, state revision/start, and timing revision after rendering immediately before transport. It retains the existing synchronous transport boundary and nonreplayable unknown outcome. Optional observation hooks cannot redefine send eligibility or contact identity. The file maintenance gate rejects a batch before writes.

An invalid future accepted timestamp is rejected against database UTC before sequence completion, including a corrupt contact #3. Initial classifier exceptions produce a held evaluation available to observability.

## Runtime results

The complete core run returned HTTP 200 with **163 passed, zero failed, zero errors**, 2026-10-03 17:37:19 UTC:

| TestBox bundle | Passed |
| --- | ---: |
| `InactiveMemberRecoveryPolicySpec` | 31 |
| `InactiveMemberRecoveryLedgerSpec` | 7 |
| `InactiveMemberRecoveryClassifierSpec` | 32 |
| `InactiveMemberRecoverySenderSpec` | 21 |
| `InactiveMemberRecoveryEnrollmentSpec` | 22 |
| `InactiveMemberRecoveryEnrollmentIntegrationSpec` | 12 |
| `InactiveMemberRecoveryReadinessSpec` | 30 |
| `InactiveMemberRecoverySignupSpec` | 8 |

After adding observation stubs to the enrollment/readiness fixtures to prevent orphan audit runs, those affected suites returned HTTP 200, **52/52**, at 17:38:48 UTC.

A final read-only review found two reporting edge cases: a missing transport outcome discarded optional finalization failure/message identity, and an unavailable observer during dry-run did not increment the run's observation-gap count. Both received narrow reporting fixes; contact claims, eligibility, and transport decisions were unchanged. The affected sender suite, including two new regressions, then returned HTTP 200, **23/23**, at 17:46:34 UTC. The new tests verify a missing OUTCOME plus finalization exception remains nonreplayable, reports its gap, and addresses the same message; observer-unavailable dry-run reports its gap without a claim or transport. Final direct checks remained fixture users 0, ledger 0, messages 0, runs 1, evaluations 2, with genuine rollout run 30 preserved.

MCPCFC invocation, fixed local base `http://localhost:8500/fpw/`:

```text
callFPWLocalEndpoint(
  path="tests/inactive-member-recovery-core-runner.cfm",
  query={confirm:"RUN_RECOVERY_CORE_TESTS",suite:"all"})
```

Targeted reruns use `suite:"Enrollment,Readiness"` and, after the reporting review fixes, `suite:"Sender"`. The runner returns compact per-bundle counts and failures, uses an explicit suite allowlist, and requires the local host/port and confirmation value.

Additional existing regression suites were executed:

| Runner and query | Exact tested bundles | Passed |
| --- | --- | ---: |
| `tests/auth-continuation-runner.cfm?confirm=RUN_AUTH_CONTINUATION_TESTS` | `AuthContinuationSpec`, `InactiveMemberRecoveryActionPathSpec` | 19 |
| `tests/inactive-member-recovery-destination-runner.cfm?confirm=RUN_INACTIVE_MEMBER_RECOVERY_DESTINATION_TESTS` | `InactiveMemberRecoveryDestinationSpec` | 15 |
| `tests/recovery-center-activity-runner.cfm?confirm=RUN_RECOVERY_ACTIVITY_TESTS` | Full `MemberActivityEvidenceSpec` with a fresh canonical disposable member, vessel, and two waypoints | 11 |

The final full activity run returned HTTP 200 at 17:37:53 UTC; its exact disposable member was deleted and remaining users was zero. The earlier no-fixture activity run (2/2) is not substituted for this full 11-test result.

Root also reported the four updated core Node contract files passed **22/22**. That static result is separate from the CFML/database tests above.

## Scenarios asserted

- Contact #1 may begin at A, B, C, or D and uses that destination's existing verified action.
- Contacts #1, #2, and #3 can all remain at A; the same three-contact sequence can all remain at C and use the owned route.
- A failed contact #2 at A retries contact #2 at B after legitimate product progress and a fresh timing evaluation, with transport attempt count incremented.
- Completion cannot restart after destination progress, elapsed time, or another claim; contact #4 is rejected.
- Canonical enrollment ownership, duplicate/skipped contact rejection, claim-token ownership, durable sharing, opt-out, monitoring, coverage, activity, clocks, and product-history regression remain enforced.
- Final post-render changes in progress, sharing, opt-out, and monitoring cancel without a send or consumed claim.
- Explicit 24-hour defaults and independently configured first/subsequent timing are distinct from the retained 168-hour nondefault scenarios.
- Simultaneous CF-thread ledger claims produce one winner. Two CF-thread sender workers synchronized before claiming produce exactly one accepted submission for a new contact and for a definite failed-contact retry.
- Definite failures stop at three transport attempts; ambiguous transport and uncertain SENT confirmation do not replay.
- Dry-run, render/compliance cancellation, retry rollback, batch bounds, live-disabled default, immutable enrollment, signup enrollment, readiness coverage, authenticated continuation/action paths, verified destinations, and meaningful activity all pass.

The CF-thread sender assertion sums each worker's non-delivering transport counter because ColdFusion copies CFC thread attributes. It also independently verifies the durable ledger row and attempt count; it does not infer success solely from aggregates.

## Cleanup and retained rollout evidence

Disposable fixture cleanup removes message/evaluation/delivery/state records before enrollment events and users. Final direct checks found zero core fixture users, zero delivery rows, and zero message rows.

The explicitly approved old test runs `4,5,6,7,8,9,13,14,15` were removed only with exact ID, `execution_source='internal'`, `status='COMPLETED'`, zero evaluation, and zero message guards. Exactly nine rows were removed; other runs were unchanged (7 before, 7 after).

Additional proven core test runs `20,21,22,31,32,33` matched the 17:32 and 17:37 all-suite executions and the three previously unstubbed enrollment/readiness sender calls. The same guards removed exactly six rows; other runs were unchanged (1 before, 1 after). Those fixture constructors now use `RecoveryCoreObservationStub`, and the 52-test rerun created no runs.

The temporary local cleanup endpoint was deleted after each use. The only remaining run was the genuine `local_rollout_validation` run **30**, COMPLETED, with its two evaluations and zero messages. The existing members' approved reset overlay was preserved.

## Exact core file scope

Original tracked files were covered before implementation by `.codex-snapshots/20261003T165055Z-recovery-center/files` and its checksum manifest. MCPCFC exact patches additionally created per-patch backups. Tracked files changed in this core work:

- `includes/InactiveMemberRecoveryEnrollmentService.cfc`
- `includes/InactiveMemberRecoveryLedgerService.cfc`
- `includes/InactiveMemberRecoveryPolicy.cfc`
- `includes/InactiveMemberRecoveryClassifierService.cfc`
- `api/v1/InactiveMemberRecoveryService.cfc`
- `app/scheduled/run-inactive-member-recovery.cfm`
- `tests/specs/InactiveMemberRecoveryPolicySpec.cfc`
- `tests/specs/InactiveMemberRecoveryLedgerSpec.cfc`
- `tests/specs/InactiveMemberRecoveryClassifierSpec.cfc`
- `tests/specs/InactiveMemberRecoverySenderSpec.cfc`
- `tests/specs/InactiveMemberRecoveryEnrollmentSpec.cfc`
- `tests/specs/InactiveMemberRecoveryEnrollmentIntegrationSpec.cfc`
- `tests/specs/InactiveMemberRecoveryReadinessSpec.cfc`
- `tests/support/RecoveryOrchestrationFixture.cfc`
- `tests/support/RecoveryOrchestrationRaceClassifier.cfc`
- `tests/support/RecoveryOrchestrationLedgerStub.cfc`
- `tests/support/RecoveryOrchestrationEmailStub.cfc`
- `tests/support/RecoveryEnrollmentFixture.cfc`
- `tests/inactive-member-recovery-sender-command.cfm`
- `tests/inactive-member-recovery-ledger-command.cfm`
- `tests/inactive-member-recovery-ledger.playwright.js`
- `tests/inactive-member-recovery-policy.test.mjs`
- `tests/inactive-member-recovery-ledger.test.mjs`
- `tests/inactive-member-recovery-classifier.test.mjs`
- `tests/inactive-member-recovery-sender.test.mjs`
- `docs/inactive-member-recovery-threshold.md`
- `docs/inactive-member-recovery-ledger.md`
- `docs/inactive-member-recovery-classifier.md`
- `docs/inactive-member-recovery-sender.md`
- `tests/support/RecoveryReadinessFixture.cfc`

New core files:

- `tests/support/RecoveryCoreObservationStub.cfc`
- `tests/inactive-member-recovery-core-runner.cfm`
- `tests/recovery-center-activity-runner.cfm`
- `docs/recovery-center-core-validation.md`

Relevant inspected/executed existing paths left unchanged by core work:

- `tests/auth-continuation-runner.cfm`
- `tests/specs/AuthContinuationSpec.cfc`
- `tests/specs/InactiveMemberRecoveryActionPathSpec.cfc`
- `tests/inactive-member-recovery-destination-runner.cfm`
- `tests/specs/InactiveMemberRecoveryDestinationSpec.cfc`
- `tests/member-activity-runner.cfm`
- `tests/specs/MemberActivityEvidenceSpec.cfc`
- `tests/support/MemberActivityHarness.cfc`
- `tests/specs/InactiveMemberRecoverySignupSpec.cfc`

The four current policy/ledger/classifier/sender documents describe the new contact contract. Their retained historical validation is explicitly labeled historical.

## Validation limits

Core transports were injected non-delivering stubs. These results do not claim production delivery, production scheduler execution, or exactly-once inbox delivery. The separate presentation agent's MailHog test is not counted as a core transport test.

No private Stripe configuration was read or changed. The legacy sender command's `runnerChecks` operation was explicitly not run because it modifies private configuration. The updated ledger Playwright spec was not rerun in this core pass; its concurrency/contact assertions were exercised directly by the CFML suites above. No production mutation or migration was performed by this core task.
