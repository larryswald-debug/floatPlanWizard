# Inactive-member recovery timing and contact policy

Current contract: 2026-10-03. Exactly **three automated recovery contacts**, independently classified A/B/C/D destinations, and configurable First Recovery Delay / Recovery Stage Interval / Attribution Window defaults of **24 / 24 / 24 hours**. Production sending still requires separate deployment and enablement authorization. See [Recovery Center](recovery-center.md).

## Authority and independent concepts

`includes/InactiveMemberRecoveryPolicy.cfc` is a deterministic, read-only evaluator with no I/O or runtime clock. `evaluate(evidence)` consumes verified server evidence supplied by the authoritative classifier; `isQualifyingActivity(action)` validates the supplied action attributes. An ELIGIBLE result is a calculation, not a send claim or continuing authorization. The sender revalidates evidence both at claim time and immediately before sending.

A/B/C/D answer where a member should resume: A Add Vessel, B Trip Planner, C current owned route work, D current valid Draft. Precedence remains **Shared → D → C → B → A**. A saved named route counts as C without legs. Highest verified product progress and current evidence must agree; deletion cannot erase higher-stage or successful-sharing history. Time passing cannot advance product progress.

Contact #1/#2/#3 answer which automated contact is next. Contacts can all use destination A or C; contact #1 can begin at B, C, or D. Only accepted contact history advances the contact number. Failed transport retries retain that number; uncertainty holds the sequence. Contact #3 completes the sequence permanently for its original enrollment; no #4 or automatic restart exists.

## Timing

The settings service supplies integer hours from 1 through 720. There is no silent fixed-seven-day fallback.

```text
anchor = MAX(effective recovery start,
             verified current destination-stage entry,
             latest qualifying meaningful activity, if any,
             previous accepted automated contact, if any)
interval = First Recovery Delay for contact #1,
           Recovery Stage Interval for contacts #2 and #3
eligible_at = anchor + interval elapsed UTC seconds
eligible = now >= eligible_at, subject to every independent safety gate
```

The original immutable enrollment event identifies the sequence. A separately audited one-time reset changes only the effective start, never enrollment identity, coverage, product progress, accepted history, or contact count. Subsequent enrollments use their own enrollment timestamp. Resume and Remove Exclusion do not reset timing.

Attribution Window is independent of send timing and is frozen per accepted message by the observability service. It is not a policy input and does not advance a contact. Tracking remains valid for 90 days; late signals do not extend attribution.

All policy clocks are canonical whole-second UTC strings `YYYY-MM-DDTHH:mm:ssZ`. Invalid dates, offsets, fractions, ambiguous/local clocks, future clocks, or conflicting histories hold eligibility. `java.time.Instant` elapsed seconds make DST irrelevant.

## Evidence contract

Required fields are `account_exists`, `stage`, `highest_verified_stage`, `has_successful_share`, `verification`, `exclusions`, `contact_number` (1–3), `contact_total` (3), `current_contact_recovery`, `first_delay_seconds`, `stage_interval_seconds`, `now_utc`, `enrollment_utc` (effective start), `current_stage_entered_utc`, `latest_activity`, and `last_recovery`.

The six verification flags are `stage_history`, `activity_coverage`, `sharing_history`, `recovery_history`, `ownership`, and `lifecycle`; each must be a native boolean true. Exclusions explicitly verify `opt_out`, `administrator_or_test`, `invalid_recipient`, `active_trip_or_monitoring`, `contradictory_lifecycle`, and `other` as false. Missing checks never default to verified proof. Enrollment is only a timing anchor; absent instrumentation is not inactivity.

`current_contact_recovery` is `never_sent`, `sent`, or `possibly_sent`. A sent contact cannot replay, and an unresolved current or previous attempt holds. `last_recovery` is:

```cfml
{state="never_sent"} // valid only before contact #1
{state="sent",contact_number=1,at_utc="2026-10-03T12:00:00Z"} // before contact #2
{state="possibly_sent"} // always held
```

The accepted previous contact must be exactly current contact minus one. Destination rank is never used as a send-order test.

`latest_activity` is explicit verified absence `{state="none_verified"}`, or a recorded UTC timestamp and verified action. Allowed entities: vessel, shore_contact, operator, passenger, saved_waypoint, route, route_leg, draft, draft_contacts. Creation requires successful, member-initiated, owned, persisted evidence; save additionally requires a change. Login, page views, opens, clicks, unchanged saves, failures, purchases, deletion, and automated maintenance are not meaningful-activity anchors.

## Results and verification

All results return `eligible`, `decision`, `reason`, and `interval_seconds` (zero when held before timing). Eligible/deferred results additionally return `contact_number`, `contact_total`, `anchor_utc`, `eligible_at_utc`, and nonnegative `seconds_until_eligible`. Held/suppressed results omit predictive clocks. No recipient details or raw input metadata are returned.

The localhost-confirmed policy runner executes `tests/specs/InactiveMemberRecoveryPolicySpec.cfc`. Current runtime checks cover the default 24-hour boundary, independent first/later settings, same-destination contacts, contact cap, missing/invalid settings, product-history safeguards, qualifying activity, conservative UTC parsing, DST, and deterministic input preservation. Explicit 168-hour test cases verify that a supported nondefault configured interval remains valid; they do not define the default.

This policy does not enroll accounts, reconstruct old history, write delivery state, or send mail. The classifier, ledger, sender, and Recovery Center retain their separate responsibilities.
