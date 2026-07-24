# Premium Send Credit production deployment and cutover

This runbook deploys the Membership and Premium Send Credit changes without activating them until the database, application, and Stripe configuration have been verified.

## Runtime authority

The server-authoritative cutover setting is:

- `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED`
- Missing or false preserves the legacy launch-trial signup and messaging.
- Accepted true values are `1`, `true`, `yes`, and `on` (case-insensitive).
- The browser cannot activate the cutover.

The application reads its private Stripe configuration from `/_fpw_private/stripe-config.json`. The committed `stripe-config-prod.example.json` file is a template only and is not the runtime configuration.

One-trip Checkout requires:

- `FPW_STRIPE_PRICE_ONE_TRIP`: the approved active Stripe live-mode, one-time Price ID for the USD one-trip product.
- `FPW_STRIPE_ONE_TRIP_DISPLAY_AMOUNT`: the approved customer-facing amount, `$4.99`.
- The existing live Stripe secret key, webhook signing secret, Checkout URLs, and portal return URL.

Never commit, print, or copy private Stripe secrets into deployment logs, tickets, or this repository. The display amount is presentation data; the Stripe Price remains the payment authority.

## Files and schema authority

Use these files without copying their DDL into another script:

1. `database/migrations/20260721_001_membership_premium_send_credits.preflight.sql`
2. `database/migrations/20260721_001_membership_premium_send_credits.up.sql`
3. `database/migrations/20260721_001_membership_premium_send_credits.verify.sql`
4. `database/migrations/20260721_001_membership_premium_send_credits.down.sql` only under the rollback conditions below
5. `scripts/reset-user-data-for-prod.sql` to reinstall the reset procedure after the new tables exist

The forward migration creates only `premium_send_credits` and `premium_send_receipts`. The verification migration is the canonical schema, index, foreign-key, and CHECK-constraint proof.

The canonical migration files support:

- MySQL 8.0.16 or newer.
- MariaDB 10.5.26 or newer within the 10.5 release series.

Production currently requires the MariaDB path. The receipt response is stored
as `LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin` with a named
`JSON_VALID` CHECK constraint so the schema and validation behavior are
deterministic on both supported engines. MariaDB CHECK-constraint enforcement
must remain enabled. A future MariaDB series upgrade requires separate
compatibility validation and is not part of this feature deployment.

## Required pre-deployment evidence

Before changing production:

1. Record the exact Git commit being deployed.
2. Confirm the deployment artifact contains the five files listed above.
3. Confirm the real production connection selects the `FPW` database.
4. Obtain and verify a recoverable production database backup or provider snapshot.
5. Back up the currently deployed application files and `/_fpw_private/stripe-config.json` outside the public web root.
6. Record the current Stripe webhook endpoint configuration without recording its signing secret.
7. Confirm an approved maintenance and rollback operator is available.
8. Confirm the production private configuration has `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=false` or omits it.
9. Do not use a SQL client's `--force` option. Every SQL refusal must stop deployment.

The production hostname, username, credential source, and backup mechanism are environment-owned values and are intentionally not stored in this repository. For the MariaDB production server, a safe CLI invocation prompts for the password and explicitly selects `FPW`:

```sh
mariadb --host="<approved-production-host>" --user="<approved-production-user>" --password --database=FPW < <approved-sql-file>
```

If the approved environment exposes only the compatibility command name
`mysql`, the same options may be used with that client. Do not place the
password value on the command line.

## Database deployment

Run each file as a separate command and retain its output as deployment evidence.

1. Run the production preflight:

   ```text
   database/migrations/20260721_001_membership_premium_send_credits.preflight.sql
   ```

   Continue only when it reports `preflight_status = PASS`. It must confirm the `FPW` database, a supported database engine and version, enabled CHECK-constraint enforcement, absence of both migration tables, required prerequisite tables, exact parent key types, and InnoDB parent tables.

2. Run the canonical forward migration:

   ```text
   database/migrations/20260721_001_membership_premium_send_credits.up.sql
   ```

3. Immediately run the canonical verification:

   ```text
   database/migrations/20260721_001_membership_premium_send_credits.verify.sql
   ```

   Continue only when it reports `verification_status = PASS`. Initial production row counts must be recorded. The migration itself does not grant credits to existing members.

4. Reinstall the production reset procedure against the selected `FPW` database:

   ```text
   scripts/reset-user-data-for-prod.sql
   ```

5. Run only its safe preview:

   ```sql
   CALL FPW.fpw_reset_user_data_for_prod(0, '');
   ```

   The preview must complete without a schema-classification mismatch. Do not call the procedure with `p_execute = 1` during deployment.

Because MySQL and MariaDB DDL perform implicit commits, the two CREATE TABLE statements are not transactionally atomic. If the forward migration stops after creating only one table, stop deployment. Do not rerun it and do not manually drop anything until the partial state and verified backup have been reviewed.

## Application deployment with cutover disabled

1. Keep `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=false` in the real production `/_fpw_private/stripe-config.json`.
2. Add and independently verify the live one-trip Price ID and `$4.99` display amount.
3. Deploy the approved application artifact.
4. Reload FPW through the authenticated administrative POST form at `admin/application-reload.cfm`.
5. Confirm the reload success message.
6. Confirm existing login, account, planning, Basic Save and Send, subscription billing, and existing Premium behavior still operate.
7. Confirm the one-trip cutover remains disabled before continuing.

## Stripe webhook readiness

The production Stripe webhook endpoint must resolve to the deployed `api/v1/stripeWebhook.cfc` component. Confirm its exact public URL from the existing production Stripe endpoint configuration; do not construct or guess the URL from a local path.

Preserve all existing subscribed events. Confirm that the endpoint receives at least:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.paused`
- `customer.subscription.resumed`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

The webhook signing secret in `/_fpw_private/stripe-config.json` must belong to that exact live production endpoint. A Stripe CLI listener secret is not a production webhook secret.

Do not activate the cutover until a signed production webhook delivery can reach the endpoint successfully.

### Local development listener

Use the canonical development listener from the FPW repository:

```bash
./scripts/start-stripe-listener-dev.sh
```

Run exactly one FPW Stripe listener at a time. Stop any older listener before starting this script. The script forwards the complete checkout, subscription, and invoice event set handled by `StripeEntitlementService.cfc` to:

```text
http://localhost:8500/fpw/api/v1/stripeWebhook.cfc?method=handle
```

Each new Stripe CLI listener prints a new `whsec_...` signing secret. Copy that new value to `FPW_STRIPE_WEBHOOK_SECRET` in the local `/_fpw_private/stripe-config.json`, reload the local FPW application through the authenticated administrative reload action, and never commit the secret.

For a Monthly or Annual development checkout, verify that `stripe_webhook_events` records both `checkout.session.completed` and a subscription lifecycle event. The checkout event records an inactive mapping only. `customer.subscription.created`, `customer.subscription.updated`, or `invoice.payment_succeeded` must subsequently activate the Stripe-managed Premium entitlement.

## Activation

1. Set `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=true` in the real private configuration.
2. Reload FPW through the authenticated administrative POST form.
3. Confirm the application reload succeeded.
4. Create one new disposable production-validation member using an approved non-customer address.
5. Confirm signup creates exactly one AVAILABLE `complimentary_signup` credit.
6. Confirm Membership and Billing displays one available Premium Send Credit.
7. Complete one approved live-mode one-trip purchase.
8. Confirm the signed webhook creates exactly one additional AVAILABLE `stripe_one_trip` credit and the displayed count becomes two.
9. Prepare a disposable Draft float plan and perform Premium Save and Send once.
10. Confirm the float plan becomes ACTIVE, exactly one credit becomes CONSUMED and binds to that float plan, one receipt exists, and the remaining available count is one.
11. Retry the same send and confirm the original committed result is returned without another email, receipt, or credit consumption.
12. Confirm Active Cruise, monitoring, and private Follow access work only for the credit-bound float plan.
13. Retain the validation evidence and remove only disposable data through the approved user-deletion workflow. Do not directly delete credit or receipt history.

Do not announce the cutover until these checks pass.

## Rollback

### Normal rollback after activation

1. Set `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=false`.
2. Reload the application through the authenticated administrative POST form.
3. Confirm new signup returns to the legacy trial behavior and one-trip purchase is unavailable.
4. Preserve `premium_send_credits`, `premium_send_receipts`, Stripe webhook records, and all financial history.
5. If application files are rolled back, leave the additive tables in place.

Credits are never restored or reused when a float plan is closed or cancelled.

### Schema rollback before any application data exists

The guarded down migration may be used only when both new tables exist and both are empty:

```text
database/migrations/20260721_001_membership_premium_send_credits.down.sql
```

It intentionally refuses to drop either table after any credit or receipt exists. Never bypass that guard in production. After a successful empty-table rollback, reinstall `scripts/reset-user-data-for-prod.sql` from the previously deployed application version so its schema classification matches the restored schema.

### Failed or partial DDL

A failed forward migration can leave a partial schema because of MySQL and MariaDB implicit DDL commits. Stop, preserve the error output, inspect the actual schema, and use the verified database backup or a separately approved corrective migration. Do not improvise a destructive repair.
