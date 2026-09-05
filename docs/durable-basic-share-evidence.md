# Durable Basic review sharing evidence

`BasicReviewSendService.send` accepts only an owned, saved **route-backed Draft**
with a valid selected contact. Eligibility is unchanged. A successful review send
leaves the plan `DRAFT`; it does not enable monitoring, consume credit, or create Follow.

After the email service reports submission success, `completeReceipt` atomically
commits the `SENT` receipt and an existing `product_events` event:

- `event_name`: `basic_send_completed`
- `event_source`: `basic_review_send` (additive allowlisted source)
- `user_id`: actual member from the locked receipt
- `entity_type`: `float_plan`
- `entity_id`: actual plan from the locked receipt, retained as a historical reference
- `metadata_json`: `{}`; no recipient, token, route, message, or other private details
- `idempotency_key`: `basic_send_completed:basic_review_receipt:<receipt-id>`

This means **successful application-reported email submission**, not confirmed
inbox delivery, reading, operational activation, or rescue monitoring.

The live product-event table has no plan foreign key. Supported parent-route
deletion removes its drafts and cascades Basic review receipts without deleting
these member-owned events. The receipt remains trip-specific. No delete logic or
schema is changed. Replaying the same request does not resend or add an event;
a deliberate new-token resend has a different receipt/event and does not change
the existence-based suppression result.

## Future recovery query contract

Use a parameterized member ID resolved by the caller. Require an extant account;
do **not** join events to deletable plans, routes, contacts, or receipts:

```sql
SELECT EXISTS (
  SELECT 1
  FROM users u
  WHERE u.userId = :userId
    AND EXISTS (
      SELECT 1
      FROM product_events e
      WHERE e.user_id = u.userId
        AND e.entity_type = 'float_plan'
        AND (
          (e.event_name = 'basic_send_completed'
            AND e.event_source IN ('basic_save_send', 'basic_review_send'))
          OR
          (e.event_name = 'premium_send_completed'
            AND e.event_source = 'premium_save_send')
        )
    )
) AS previously_shared;
```

A true result means `Already shared/activated` and excludes every pre-activation
recovery stage A/B/C/D. False is **not** proof that an older member never shared:
existing operational Basic/Premium event writes remain best-effort, and historical
Basic review events were not backfilled. Retained successful receipts can still
provide additional positive evidence. Never infer historical success from drafts.

## Failure boundary and privacy

Failed validation, missing recipients, failed PDF generation, and reported email
failure do not write successful-share events. If email submission succeeds but
event/receipt finalization fails, the transaction rolls back and the existing
receipt stays `PROCESSING`. The response is `BASIC_REVIEW_CONFIRMATION_PENDING`,
explicitly warning against resending; the same request remains non-replayable.
No automatic reconciliation or new delivery state is introduced. SMTP and SQL
cannot be committed atomically; an uncertain submission must not be called a
confirmed application success.

Existing account-deletion behavior is unchanged: the inspected administrator
delete specification does not explicitly delete `product_events`, and that table
has no account cascade. The query above does not classify deleted accounts.
Changing historical event-retention/privacy policy is outside this fix.

## Verification

The local guarded `tests/basic-review-send-runner.cfm` executes focused TestBox
coverage with disposable, real-ID member/route/draft/contact records and the
existing non-delivering PDF/email stubs. Tests cover successful send, normal
parent-route deletion and receipt cascade, unsent deletion, failures, same-token
replay/new-token resend, ownership, metadata restrictions, preserved route-backed
eligibility, event rollback, and existing Basic/Premium event compatibility.
Fixtures and events are cleaned using a run-specific prefix. No recovery sender,
schedule, ledger, timing, backfill, or payment changes are included.
