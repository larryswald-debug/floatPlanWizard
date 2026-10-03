# Recovery Center

Current implementation contract, 2026-10-03. Historical recovery validation documents retain their original results; this document supersedes their destination-keyed delivery and fixed seven-day recovery rules. Other seven-day product settings are unchanged.

## Four independent concepts

| Concept | Authority | Meaning |
| --- | --- | --- |
| Recovery cycle | Original validated enrollment product-event ID | One existing enrollment; no restart or recurring-cycle feature |
| Recovery contact | Contiguous confirmed SENT ledger rows, numbered 1–3 | Automated sequence position |
| Destination A/B/C/D | Existing classifier and destination resolver | Actual current product progress and where the member resumes |
| Transport attempt | Claim token and attempt_count, maximum 3 per contact | Submission or permitted known-failure retry |
| Engagement | Attributed durable activity/share evidence | Observed behavior; sequence completion alone is not engagement |

A is Add Vessel, B is Trip Planner, C is Saved/Planned Route, D is Draft Editor. Contact #1 can begin at any verified destination. Contacts #1, #2 and #3 can all point to A or C. Accepted messages and elapsed time never create progress evidence.

After confirmed acceptance of Contact #3, the automated sequence is complete. Pause/resume, exclusions, activity, destination changes and elapsed time preserve the original cycle and contact position. Uncertain transport or ledger confirmation holds the sequence. Known failures retry the same contact within the independent three-attempt limit.

## Existing engine and per-contact processing

The original enrollment, classifier, policy, ledger, renderer, transport and scheduled runner remain the execution path. No second recovery ledger or automated sender was added.

1. Read validated enrollment and immutable event ID, current settings and administrative state.
2. Validate genuine progress/coverage, sharing, ownership, preferences, lifecycle and clocks using existing safeguards.
3. Under the member row lock, validate contiguous accepted contact history and derive the next number. Reject gaps, foreign enrollment IDs, unresolved claims and exhausted retries.
4. Re-evaluate eligibility with the owned claim token; choose current destination and render contact-specific copy.
5. Independently recheck settings revision, effective start/state revision, product evidence, destination and recipient/preferences.
6. Commit preparation and submit outside the database transaction through the existing multipart mail helper.
7. Confirm the terminal ledger transition using the claim token. Unconfirmed acceptance holds the contact.
8. Preserve initial evaluation and immutable message-attempt content/destination, then record the final decision and transport outcome.

Reporting failures cannot create a retry or duplicate send. Required settings/state/preference/authorization failures hold processing. Pre-send cancellation rolls back an unsubmitted claim, preserving contact position and retry allowance. Run evaluations retain the cancellation separately from initial eligibility.

## Timing and reset

The singleton settings table defaults to 24 / 24 / 24 hours:

- First Recovery Delay applies to Contact #1.
- Recovery Stage Interval is spacing between numbered Contacts #2 and #3.
- Recovery Attribution Window is independent from sending eligibility.

All three accept whole hours from 1 through 720. Reads do not use an indefinite cache. Eligibility uses the latest applicable effective start, stage-entry time, qualifying activity time and confirmed accepted-message time, plus the first delay or subsequent interval. Meaningful activity can postpone a contact without resetting its number.

Settings Preview Impact is read-only for durable data. It compares current authoritative evaluations with the proposed values, showing affected members, earlier/later eligibility, newly immediate contacts and earliest resulting eligibility. Saving requires a fresh actor-bound review token, POST, CSRF and explicit confirmation. The service re-evaluates the impact and atomically writes settings and old/new audit values. Saving sends no mail.

The one-time reset requires an empty delivery ledger and an unchanged reviewed cohort. One database-generated UTC T0 is stored as an effective-start overlay for existing enrollments. Original events, metadata, progress and coverage remain intact. The reset is audited per member and as a cohort operation. New signups retain their real enrollment timestamps. A completed reset cannot be repeated.

## Storage and observability

The adapted delivery table has unique (recovery_enrollment_event_id, contact_number), separate destination_stage and contact-number checks 1–3. Existing claim/status/time safeguards remain.

The five supporting tables store current settings, per-member administrative state, executions, immutable initial/final evaluations and immutable rendered message attempts. Message attempt identity is unique (delivery_id, transport_attempt_number); personal messages have a separate unique submission_identity. Core searchable identity, destination, template, contact, attempt, status and timestamps use typed columns.

Dry runs create observable runs/evaluations without enrollment, claims or sends. Initial eligibility and later cancellation/send results are distinct. Runs with missing reporting evidence expose gaps; unfinished runs retain a missing completion record. SMTP acceptance is labeled accepted, never delivered or bounced.

Product events link to typed evaluations/messages for recovery history. fpw_admin_audit_log records settings, reset, state and personal follow-up actions. Administrative personal content is stored only in the protected message record; tokens/secrets are not listed in reports.

## Tracking and attribution

Open and click tokens contain a random public reference and purpose-bound HMAC, with no member ID, email or destination payload. They are valid for 90 days from accepted_at_utc.

Invalid/expired opens return the same transparent image with no recorded signal. Invalid/expired clicks redirect to the fixed FPW entry point. Valid clicks revalidate the stored destination and use existing authentication continuation; tokens never authenticate members. Authenticated foreign-member clicks cannot access the original member's destination.

The accepted automated message retains its attribution-window setting and deadline. Each source event is attributed once to the latest accepted automated contact for the same member whose frozen window contains the source timestamp. Opens/clicks remain observable after that deadline but never extend/reopen attribution.

Authenticated returns are distinct from engagement. Durable meaningful member activity and successful sharing qualify as engagement. Opens, clicks, login, ordinary page views and unchanged saves do not. Existing committed activity sources, nonfatal post-request observation and bounded reconciliation supply evidence. Original source timestamps and source-event IDs are retained.

Preview HTML comes from the actual renderer or stored historical snapshot. Bearer tokens are redacted, images/active links are removed and the browser preview is sandboxed with network access disabled. Recovery transport logs omit recipients, subjects, bodies and raw transport exceptions.

## Administrative interface

/admin/recovery-center.cfm uses existing administrative authorization, CSRF, shared navigation and vanilla JavaScript conventions.

- Dashboard: current enrollment/eligibility/state metrics, independent response funnel, timing and latest run, attention list.
- Recovery Queue: current contact and destination, reason, eligibility timestamp, search, filters and pagination.
- Runs: dry-run/processing executions, totals, completeness and per-member initial/final decisions.
- Members: current classification, last accepted contact and historical destination, message/evaluation/activity history, safe previews and controls.
- Performance: accepted-message cohorts grouped by contact, destination and template; explicit denominators, independent signals, late counts and missing tracking.
- Settings: three independent timing values, impact review, atomic save/audit and guarded initial reset.

Pause, Resume, Exclude and Remove Exclusion preserve clocks and history. Eligibility refresh records a dry evaluation without sending. No Force Send, Skip Contact, Restart Cycle or Manual Recovered control exists.

Personal follow-up resolves its recipient from the database and honors pause/exclusion/non-essential preferences. Preview/confirmation bind immutable content and recipient to the administrator. A unique durable submission record prevents replay. The existing transport submits outside transactions; outcome and audit remain separate from automated contacts. Personal messages do not consume contacts, alter clocks or participate in automated attribution.

## Email copy

[Exact implemented copy, CTA labels and template versions](recovery-center-email-copy.md). Shared rendering chooses contact number plus current destination; there are twelve copy configurations and one shared automated renderer.

## Local rollout and production boundary

Use the four 20261003_001_recovery_center migration files. Before migration, snapshot/checksum every affected existing file, record Git state and back up the database. Stop native scheduling and all manual recovery processing. The processor maintenance sentinel is .codex-snapshots/recovery-center-migration.lock.

Independently verify the enrollment population and empty delivery ledger. The migration deliberately stops on existing deliveries rather than deleting them or guessing contact numbers. An already transitioned or partially applied schema requires review; do not blindly rerun. MySQL 8.0.43 was the local validation engine; production database-dialect validation and production execution remain separate.

Deploy schema and contact-aware code together while processing remains stopped. Verify schema/indexes, reset, timing, dry-run reporting, canonical-account sequences and local/non-delivering transport before considering operational sending. The guarded down migration refuses to erase any recovery execution, state, message, delivery, reset or changed settings.

See the implementation completion report for actual local timestamps, checksums, runtime/browser proof, cleanup and limitations. This document does not authorize production sending.

### MariaDB migration retry

The current migration uses `DROP CONSTRAINT` for CHECK removal in both directions, compatible with MariaDB and MySQL 8.0.19+. After a failed/interrupted run, use the updated read-only preflight before retrying. It reports version, ledger columns/indexes/constraints, supporting tables and guard routines. A full fresh retry requires an empty original stage ledger and no new supporting tables or leftover guard routine. Existing support tables now cause the upgrade guard to stop before ledger alteration. Always stop on the first SQL error; do not use a continue-on-error client option. See the completion report's MariaDB correction section for the 2026-10-03 production error, exact correction, backups and local validation limits.
