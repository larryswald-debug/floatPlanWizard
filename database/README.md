# FPW database migrations

FPW uses inspected SQL migration files instead of a general-purpose migration framework.

## Naming

Use `YYYYMMDD_NNN_description.up.sql`, `YYYYMMDD_NNN_description.down.sql`, and `YYYYMMDD_NNN_description.verify.sql`. A production-specific, read-only prerequisite gate may use the matching `YYYYMMDD_NNN_description.preflight.sql` name. A preflight is an adjunct to the migration trilogy and must not duplicate or replace its schema definitions.

## Execution order

1. Verify the target connection is the local `FPW` database.
2. Inspect the forward migration.
3. Apply the `.up.sql` file.
4. Run the matching `.verify.sql` file.
5. For rollback validation, inspect and run the guarded `.down.sql` file.
6. Confirm removal, then reapply and reverify the forward migration.

Example from the local MySQL container:

```sh
docker exec -i cfdev-mysql sh -lc 'mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" FPW' < database/migrations/<migration>.up.sql
```

Use the matching `.verify.sql` or guarded `.down.sql` path for verification or rollback. The explicit `cfdev-mysql` container and `FPW` database arguments are required local-target safeguards.

Never execute the local Docker command against staging or production.

## Production execution

Production requires a separately approved deployment plan and an operator-supplied production database connection. Do not record production credentials in this repository or in shell history.

For `20260721_001_membership_premium_send_credits`, use this database-file order:

1. Select the production `FPW` database without using the SQL client's `--force` option.
2. Run `20260721_001_membership_premium_send_credits.preflight.sql`.
3. Stop if the preflight does not report `PASS`.
4. Run `20260721_001_membership_premium_send_credits.up.sql`.
5. Run `20260721_001_membership_premium_send_credits.verify.sql`.
6. Stop if verification does not report `PASS`.

The preflight does not create or modify application tables or application data. It validates the selected database, supported database engine and version, MariaDB CHECK-constraint enforcement, table absence, prerequisite tables, foreign-key column compatibility, and InnoDB parent tables. This migration supports MySQL 8.0.16 or newer and MariaDB 10.5.26 or newer within the 10.5 release series. The forward and verification files remain the only schema authority.

The complete production sequencing, configuration, application reload, Stripe webhook, smoke-test, and rollback notes are in `docs/premium-send-credit-cutover.md`.

For `20260724_001_stripe_subscription_entitlement_uniqueness`, run the `.up.sql`
and `.verify.sql` files after `20260721_001_membership_premium_send_credits` has
been applied. The forward migration refuses to add the unique Stripe
subscription binding when duplicate non-null `stripe_subscription_id` values
exist. Resolve and audit any duplicates before retrying; the migration never
deletes or merges entitlement records. The guarded rollback removes only the
exact named unique index and never changes entitlement data.

For `20260724_002_add_welcome_onboarding_seen_at`, run the `.preflight.sql`,
`.up.sql`, and `.verify.sql` files in that order without the SQL client's
`--force` option. The preflight is read-only and refuses to continue unless the
selected database is exactly `FPW`, `users.userId` has the expected definition,
and `users.welcomeOnboardingSeenAt` is absent. The forward migration captures
the current maximum `userId` and existing-user count before adding
`welcomeOnboardingSeenAt DATETIME(6) NULL DEFAULT NULL`. It backfills only users
at or below that captured cutoff, leaving later accounts `NULL` and eligible
for the welcome onboarding flow. Record the cutoff, count, and UTC timestamp
reported by the forward migration.

Rollback deletes all persisted welcome-acknowledgment timestamps. The down
migration therefore refuses to run unless the operator sets this exact
same-session confirmation immediately before sourcing the file:

```sql
SET @fpw_confirm_drop_welcome_onboarding_seen_at =
  'DROP_WELCOME_ONBOARDING_SEEN_AT';
SOURCE database/migrations/20260724_002_add_welcome_onboarding_seen_at.down.sql;
```

Prefer disabling the onboarding feature while leaving the compatible nullable
column in place when schema rollback is not explicitly required.

For `20260724_003_add_getting_started_hidden`, run the `.preflight.sql`,
`.up.sql`, and `.verify.sql` files in that order before the application
rollout, without the SQL client's `--force` option. The read-only preflight
requires the exact `20260724_002` column definition and refuses to continue
when `users.gettingStartedHidden` already exists. The forward migration adds
`gettingStartedHidden TINYINT(1) NULL DEFAULT NULL` without a data backfill:
`NULL` retains automatic visibility, `0` records an explicit Show choice, and
`1` records an explicit Hide choice.

Rollback deletes every persisted Getting Started visibility choice. The down
migration therefore requires this exact same-session confirmation:

```sql
SET @fpw_confirm_drop_getting_started_hidden =
  'DROP_GETTING_STARTED_HIDDEN';
SOURCE database/migrations/20260724_003_add_getting_started_hidden.down.sql;
```

## Single-trip access lifecycle Phase 1

For `20260801_001_single_trip_access_lifecycle`, deploy the database migration
before application code that reads or writes the new lifecycle fields. Use this
order without the SQL client's `--force` option:

1. Select the production `FPW` database.
2. Take and verify a recoverable database backup or snapshot.
3. Quiesce Premium Save & Send and float-plan lifecycle writes until verification
   completes; the DDL is not transactional and the backfill must use one stable
   deployment snapshot.
4. Run `20260801_001_single_trip_access_lifecycle.preflight.sql` and stop unless
   it reports `PASS`.
5. Run `20260801_001_single_trip_access_lifecycle.up.sql` once.
6. Run `20260801_001_single_trip_access_lifecycle.verify.sql` and stop unless it
   reports `PASS`.
7. Deploy and reload the matching application release, then restore writes.

The forward migration repeats the exact source-column and CHECK-enforcement
guards in its own database session. Its cross-table DDL still uses implicit
commits. If any forward DDL statement fails, stop with writes quiesced: do not
rerun the up migration and do not run the guarded down migration against a
partial object set. Inspect the exact objects left in `information_schema` and
restore the verified database snapshot or prepare an explicitly reviewed manual
repair before continuing.

The preflight reports safe internal IDs and refuses unsafe credit, receipt,
member, float-plan, or active-authorization bindings. It reports historical
general-Premium interval values as unproven rather than fabricating Monthly or
Annual history. Canonical active Basic plans are excluded only when their latest
monitoring record proves `monitoring_mode = 'basic'`.

The forward migration extends `premium_send_receipts` with the separate access
window, membership snapshot, and access-ending fields; adds `floatplans.expiredAt`
and `floatplans.end_reason`; and adds the supporting indexes, CHECK constraints,
and exact `(member_entitlement_id, user_id)` foreign-key binding. It does not
change the existing `original_response_json` storage type. One database
`UTC_TIMESTAMP(6)` value supplies the complete rollout grace period for every
existing active credit-origin plan: start at deployment UTC and expire exactly
21 days later. Ended credit-origin plans receive historical metadata and are not
reactivated. General-Premium receipts receive no single-trip expiry, and their
historical interval snapshot remains `NULL`.

After the matching application release is live, configure a production
ColdFusion scheduled task to request this token-protected endpoint every 15
minutes:

```text
/app/scheduled/run-single-trip-expiration.cfm?token=<production monitor token>
```

The endpoint uses the existing application monitor token, defaults to a bounded
batch of 100, and accepts an optional `limit` from 1 through 500. Keep the token
out of the repository, deployment logs, and validation output. Repository code
does not create the ColdFusion scheduled task; production scheduling is a
separate operator action. Request-time authorization still enforces the exact
database UTC expiration boundary between scheduled runs.

## Day 36 departure reminders

After migration `20260831_001_departure_reminder_deliveries` and the matching
application release are deployed, configure a production ColdFusion scheduled
task to request this token-protected endpoint every 15 minutes:

```text
/app/scheduled/run-departure-reminders.cfm?token=<production monitor token>
```

The endpoint uses the existing application monitor token, defaults to a bounded
batch of 100, and accepts an optional `limit` from 1 through 500. Each reminder
has a 30-minute due window: the pre-departure occurrence opens two hours before
the persisted UTC departure, and the not-started occurrence opens 30 minutes
after it. The delivery ledger and its unique occurrence key prevent repeated or
concurrent scheduler runs from sending the same reminder for the same scheduled
departure. A materially changed `departureTimeUTC` creates a new occurrence.
Known failed sends may be reclaimed only while the occurrence window remains
open and only up to three total attempts. A `CLAIMED` delivery is never
automatically reclaimed, because SMTP may have accepted the message before an
interrupted worker recorded `SENT`.

Keep the token out of the repository, deployment logs, and validation output.
Repository code does not create the ColdFusion scheduled task; production
scheduling remains a separate operator action. Do not enable this task until the
ledger migration and matching application release are both live.

Rollback is destructive to the new lifecycle metadata. First place Premium
Save & Send and all trip-lifecycle request paths in maintenance, drain in-flight
requests, and stop the expiration task. While that traffic remains quiesced,
deploy and reload application code that does not require these columns, run the
guarded down migration, verify the expected schema removal, and only then
restore traffic. This avoids both old-code/new-schema receipt failures and
in-flight Phase 1 requests reaching a schema whose lifecycle columns have been
dropped. The down migration deliberately leaves every `EXPIRED` status
unchanged and never restores, refunds, or deletes credits or receipts. It
requires this exact same-session confirmation:

```sql
SET @fpw_confirm_drop_single_trip_access_lifecycle =
  'DROP_SINGLE_TRIP_ACCESS_LIFECYCLE';
SOURCE database/migrations/20260801_001_single_trip_access_lifecycle.down.sql;
```

Because each down-migration DDL statement commits independently, a partial down
failure is not automatically rerunnable. Keep traffic quiesced, stop, and use
the verified backup or an explicitly reviewed manual repair before continuing.

Once any plan has become `EXPIRED`, this destructive schema rollback is not a
reapplicable rollback path: it preserves the `EXPIRED` status while removing the
timestamps and reason needed by the forward preflight and CHECK constraint.
Reapplying then requires an explicitly reviewed forward repair using the
verified pre-rollback backup; the migration intentionally will not guess or
reconstruct those lifecycle timestamps.

## Verification

Verification files must identify the selected database, expected tables, columns, indexes, foreign keys, and CHECK constraints. Application validation must use disposable local records and remove them afterward.

## Rollback limitations

MySQL and MariaDB DDL perform implicit commits. A rollback script cannot provide transactional rollback for table creation or removal. Every down migration must therefore be guarded and deterministic.

A rollback must refuse to drop a populated application table unless that specific destructive operation and its data handling have been explicitly authorized. Disposable validation records must be removed before the guarded rollback is run.

## Arrival monitoring (Phase 2, observation only)

Use the four `20261101_001_arrival_overdue_monitoring` migration scripts. Run preflight on the intended development FPW database, then up and verify with a client that stops on SQL errors. MySQL DDL implicitly commits. Inspect a partial installation before retrying. The up script creates no trip revisions and starts in OFF.

After verification, an authorized development operator can set `fpw_arrival_rollout.mode` on row 1 to `OBSERVE`; use `OFF` to stop independent evaluation. Enrollment, deadline revisions and terminal suppression are lifecycle records. They are maintained after installation so a restart or mode change cannot discard a revision or reopen a stopped trip. Observation alone never enables email.

The migration records an immutable database UTC observation cutoff. Each revision retains its own historical-only classification. Treat all Phase 2 events as observations, including for trips that become overdue after the migration. A later live rollout requires a separate durable enablement watermark before it can classify any delivery. Do not reuse the observation cutoff as a live-mail cutoff.

Use the guarded `tests/arrival-monitoring-phase2-runner.cfm` only in local development. The down migration is for an unused, OFF installation. After observations or history exist, turn evaluation OFF, preserve all rows and investigate before any separately approved schema removal.

## Initial arrival-overdue email (Phase 3)

Apply the dated `20261101_002_arrival_overdue_delivery` preflight, up and verify scripts in order after verifying Phase 2. The migration creates an OFF dispatch control with no activation timestamp, and empty notice, recipient delivery and attempt tables. Notice slot zero records the initial overdue alert. Hourly observations do not create hourly email.

The monitoring runner returns a separate `ARRIVAL_DELIVERY` summary. The two top-level keys below belong in the site's existing `_fpw_private/scheduler-config.json`. Set `FPW_ARRIVAL_EMAIL_ENABLED` to the JSON boolean `true` and provide a stable string of at least 32 characters in `FPW_ARRIVAL_RECIPIENT_KEY` when ready. The worker and mail sender read the file at delivery checks. An edit takes effect without a ColdFusion restart. Production uses its configured SMTP transport. Local development sends eligible arrival emails to MailHog.

```json
{
  "FPW_ARRIVAL_EMAIL_ENABLED": false,
  "FPW_ARRIVAL_RECIPIENT_KEY": ""
}
```

Keep these disabled defaults in version control. Provision each installation's own key in its protected working copy and preserve it during deployments. The file stays inside the web root. IIS uses the deny rule in `web.config`, and the standalone development Tomcat uses the equivalent rule in `wwwroot/WEB-INF/rewrite.config`. Before provisioning a host's key, verify that a direct request to `/_fpw_private/scheduler-config.json` returns 403 or 404. If migrating an active installation from environment variables, reuse the exact existing recipient key so queued recipients retain their identities. A key rotation requires reconciliation of outstanding deliveries.

In development and production, activating a Basic or route-backed float plan creates its `ALLOWLIST` row in the same transaction. On each pass, **Run FPW Monitor** also enrolls a batch of already-active, open plans that have no row. Existing per-trip settings take precedence, including `OFF` and `CAPTURE`. Enrollment is independent of the site email flag and the global dispatch mode.

On the first eligible pass at or after the saved return time, the monitor sends the captain **FloatPlanWizard Reminder: Close Your Float Plan** at the plan owner's account email. The reminder asks the captain to close the plan after arriving safely or update the return time if still underway. The eligible shore contacts receive their existing overdue alert on that same pass. Each message has its own recipients and delivery record.

The captain receives at most one successful reminder per float plan. The existing `floatplan_alert_history` table stores its `CAPTAIN_CLOSEOUT` receipt. FPW registers it at activation, or on a monitor pass for existing active plans. A deadline that had already passed at registration gets no catch-up reminder. Before submission the worker checks the saved deadline, current plan and site permissions, and whether the plan is still open. A completed final leg can leave the plan open for captain closeout. Closing, cancelling, expiring, or stopping monitoring suppresses further sends. A definite transient failure follows the 5-, 15- and 30-minute retry intervals. An ambiguous submission is recorded as `UNKNOWN`. The scheduled-task response reports these outcomes under `ARRIVAL_DELIVERY.captainReminders`.

Row zero of `fpw_arrival_dispatch_control` controls site-wide delivery. Production accepts `ALLOWLIST` or `LIVE`. New notices require observation to be on and the deadline to fall after both the site and per-trip activation cutoffs. An overdue trip first enrolled today gets no catch-up email for that deadline. A recipient delivery already queued legitimately under production `LIVE` can finish under its original authorization. Before submission, the worker rechecks both generations, the deadline revision, final arrival and selected recipient. `CAPTURE` requires a development environment, an injected in-process sink and a specific capture scope.

Each valid, normalized, selected recipient receives one initial delivery identity. Missing/invalid selections and zero-valid-recipient incidents are recorded on the notice. The application stores a keyed, plan-bound fingerprint instead of an address. A native synchronous mail call runs outside SQL transactions. A bounded, connection-pinned DB named lock serializes handoff with conflicting lifecycle commits. Verify dedicated JDBC connections and named-lock support on the target ColdFusion/DB combination before enabling transport. A competing terminal action may briefly wait for a handoff already in flight. Submission to transport cannot be recalled or treated as proof of inbox delivery.

For a definite retryable failure, retry after 5, then 15, then 30 minutes measured from the preceding failed attempt. Four attempts exhaust this notice. An abandoned pre-handoff claim can be reclaimed. If handoff may have started but the outcome was not durably recorded, mark it UNKNOWN for operator reconciliation. Do not manually replay UNKNOWN solely because the lease expired.

### Shore-contact arrival time changes

After verifying Phase 3, select the target database explicitly (`USE fpw;` in production or `USE FPW;` in local development). Run the `20261102_001_shore_arrival_time_change.preflight.sql`, `.up.sql` and `.verify.sql` scripts from `database/migrations/` in order. Check for `PASS` at each stage. The migration extends the existing notice constraint to accept slot one for schedule changes. Use the updated application for both saves and scheduled delivery. The down script permits rollback only while slot one is unused.

When an authorized edit changes an active plan's saved return instant, the save queues **FloatPlanWizard Update: Expected Arrival Time Changed** for each distinct, valid shore-contact address on the newly saved plan. The email gives the previous and revised arrival in their respective local time zones and UTC. FPW attempts delivery immediately after the save commits, using the same site and trip permissions as arrival alerts. A draft, an unchanged instant, or a rejected save creates no update. The monitor retries outstanding deliveries and reports them under `ARRIVAL_DELIVERY.deadlineChanges`. Recipient removal, a superseding revision or trip completion suppresses a stale delivery. Enabling the feature does not replay past edits.

### Routine evening checkpoints

Before installing the matching monitor code, select the intended database (`USE FPW;` in development or `USE fpw;` in production) and run the `20261103_001_routine_checkpoint_kind` preflight, up and verify scripts in order. Each must report `PASS`. The nullable `floatplan_monitoring.checkpoint_kind` records how the current checkpoint was selected. The down script refuses to discard recorded reasons.

On a started route, 6 PM is an evening checkpoint only on local dates before the saved expected arrival date of an overnight trip. FPW uses the departure time zone and calendar dates, including trips shorter than 24 hours. A Monday–Thursday trip can have evening checkpoints on Monday, Tuesday and Wednesday. Basic planned returns, earlier planned-return checkpoints and Daily Start have their own timing. A qualifying missed check-in still goes to the captain after grace, then to the selected contacts if escalation becomes due. The independent arrival notices use the saved arrival instant.

An authorized arrival edit reconciles the pending evening in the save transaction. A same-day extension before 6 PM can arm that evening. An extension after 6 PM can arm the next eligible evening. The monitor rechecks the stored checkpoint date before either routine notice. Earlier rows whose source is uncertain retain their existing schedule until the next checkpoint is selected.

### Test a development trip in MailHog

1. Run the local ColdFusion, MySQL, and MailHog containers. Use the development scheduler config with the email flag enabled and a stable development-only recipient key. The scheduled worker connects directly to `mailhog:1025`. Global `LIVE` does not enable this development transport.
2. For initial local setup, connect to the **development** database at `localhost:3307`, select `FPW`, and review the existing allowlist. Set observation and global dispatch as shown. All plans with a positive `ALLOWLIST` row are in scope.

   ```sql
   USE `FPW`;
   SELECT plan_id, mode FROM fpw_arrival_dispatch_control WHERE plan_id = 0 OR mode = 'ALLOWLIST';
   START TRANSACTION;
   UPDATE fpw_arrival_rollout SET mode = 'OBSERVE' WHERE id = 1 AND mode = 'OFF';
   UPDATE fpw_arrival_dispatch_control SET mode = 'ALLOWLIST', generation = generation + 1
   WHERE plan_id = 0 AND mode <> 'ALLOWLIST';
   COMMIT;
   ```

3. Create and activate a test float plan with a selected shore contact and a saved return time in the future. To verify automatic enrollment, replace `NULL` with its **Float Plan ID** in the same development connection.

   ```sql
   SET @plan_id = NULL;
   SELECT plan_id, mode, activated_at_utc
   FROM fpw_arrival_dispatch_control WHERE plan_id = @plan_id AND plan_id > 0;
   ```

4. Activate monitoring and start the trip if it is route-backed. Leave final arrival unconfirmed and the plan open. On the first eligible **Run FPW Monitor** pass at or after the deadline, look for **FloatPlanWizard Reminder: Close Your Float Plan** addressed to the owner and **FloatPlanWizard Alert: Expected Arrival Time Has Passed** addressed to the shore contact in [local MailHog](http://localhost:8025/).
5. To remove the trip from the local allowlist, set its positive `plan_id` row to `OFF` and increment `generation` by one.

Operators can review incidents and delivery outcomes without selecting addresses or tokens:

```sql
SELECT n.plan_id, n.revision_id, n.slot_no, n.state AS notice_state,
       n.recipient_count, n.invalid_count, n.reason AS selection_reason,
       d.id AS delivery_id, d.state AS delivery_state, d.attempt_count,
       d.next_attempt_utc, d.submitted_at_utc, d.reason AS delivery_reason
FROM fpw_arrival_notices n
LEFT JOIN fpw_arrival_deliveries d ON d.notice_id = n.id
WHERE n.state = 'NO_RECIPIENTS' OR n.invalid_count > 0
   OR d.state IN ('FAILED_RETRYABLE', 'FAILED_PERMANENT', 'UNKNOWN')
ORDER BY n.created_at_utc DESC, d.id
LIMIT 100;
```

Use `fpw_arrival_attempts.delivery_id` for the numbered attempts and timestamps. An accepted transport handoff is SUBMITTED. Only external provider evidence can substantiate delivery. For rollback, disable arrival dispatch, advance the scope generation, and retain the ledgers. Preserve ambiguous in-flight attempts for reconciliation. The down migration refuses a used installation. The dedicated test harness is `python3 tests/support/run-arrival-delivery-phase3-isolated.py`. It uses disposable development containers and captured mail.
