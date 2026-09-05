# Inactive-member recovery: approved seven-day policy

Status: **APPROVED — 7 DAYS; policy-only implementation. Sending is not enabled or authorized.**

The threshold is **168 elapsed hours / 604,800 seconds** for every stage A–D, with no stage-specific exceptions. This is product judgment, not an industry benchmark or proven optimum. The First 90 Days timing recommendation remains unverified; departure-reminder timing is unrelated.

## Scope and trust boundary

`includes/InactiveMemberRecoveryPolicy.cfc` is a standalone, deterministic policy evaluator. It has no database queries, sender, scheduler, remote methods, enrollment writes, history store, instrumentation, or production caller. Its public methods are `evaluate(evidence)` and `isQualifyingActivity(action)`.

The evaluator consumes a **server-verified evidence projection**, not raw request parameters, browser events, arbitrary analytics rows, or user-supplied claims. Verification booleans assert facts already established by a future trusted caller; this helper cannot prove those facts itself. Missing evidence holds eligibility false.

An `ELIGIBLE` result is only a calculation on the supplied snapshot. It is not a send claim, durable history, or continuing authorization. A future implementation must collect trustworthy evidence, claim candidates safely, and revalidate all gates both at claim time and immediately before sending. None of that integration is included here.

## Stage contract

Precedence is **Shared → D → C → B → A**. `highest_verified_stage` means the highest stage ever verified, including evidence retained after entity deletion. The current A–D stage must match it; regression or contradictory classification holds the member out.

| Stage | Verified entry | Clock requirement |
| --- | --- | --- |
| A | Account creation without higher-stage evidence | UTC signup event, or account creation only with verified timezone provenance |
| B | First successful creation of an owned vessel | Corresponding verified UTC vessel-created event; never substitute signup time |
| C | First owned saved named route or qualifying owned planned route instance | Verified creation timestamp normalized to UTC; updates do not establish entry |
| D | First owned Draft creation, including generated Drafts | Verified Draft creation timestamp normalized to UTC |
| Shared | Successful Basic or Premium sharing | Permanently suppress A–D; retained successful receipts are also positive evidence |

A **saved named route counts as C without legs**. The evaluator does not inspect route legs or classify live records. A generated Draft can jump directly to D, bypassing A–C recovery. Use the first verified entry into a stage; additional same-stage creations are activity, not another stage entry.

Deletion/recreation must not erase higher-stage history, sharing evidence, or recovery-send history. This component enforces the supplied history but does not persist it. Newly observed records must not be treated as proof of historical transitions. No speculative backfill is allowed.

## Timing and enrollment

```text
anchor_utc = MAX(enrollment_utc,
                 current_stage_entered_utc,
                 latest qualifying activity, if any under reliable coverage,
                 last recovery sent, if any under reliable history)
eligible_at_utc = anchor_utc + 604800 seconds
time_eligible = now_utc >= eligible_at_utc
```

Advancement, qualifying activity, enrollment grace, and cross-stage send spacing each require a full seven-day interval. Each stage may send **once only**. A same-stage successful send suppresses recovery; an unresolved possibly-sent attempt holds it. An unresolved attempt at any stage cannot establish safe cross-stage spacing and also holds it.

Reliable existing accounts receive a fresh seven-day grace starting at recovery enrollment. Existing accounts with unreliable stage clocks, activity coverage, or sharing/recovery history stay held out. Enrollment does not retroactively prove missing history. It must not create an immediate launch-day backlog.

All input clocks must already be normalized to canonical whole-second UTC strings: `YYYY-MM-DDTHH:mm:ssZ`. Ambiguous local dates, offsets, fractional seconds, invalid calendar dates, and noncanonical values are held rather than guessed or truncated. A future caller must establish timezone provenance before normalization; `Z` must not simply be appended to a local database timestamp. The current supplied `now_utc` is also trusted caller input, never read from the server clock by this helper.

Internally the helper parses `java.time.Instant` and compares epoch seconds. It never uses local midnight, calendar-day differences, or the server/member timezone. DST does not alter the duration. Evidence clocks later than supplied `now_utc` hold the member out. Other lifecycle/time contradictions must be detected by the caller and reflected in verification/exclusion flags.

## Exact input contract

All fields below are required unless an explicit alternative is stated. Enum values are case-sensitive. Proof/exclusion values must be native booleans: strings such as `"true"`, `"yes"`, and numeric `1` are not verified proof. Struct field names follow normal case-insensitive CFML semantics.

| Field | Meaning |
| --- | --- |
| `account_exists` | Verified `true` |
| `stage` | Verified `A`, `B`, `C`, or `D`; `Shared` suppresses |
| `highest_verified_stage` | Highest ever verified stage, not just currently retained entities; `Shared` suppresses |
| `has_successful_share` | Explicit `false` under reliable history; `true` suppresses regardless of other missing inputs |
| `verification` | All six booleans below must be `true` |
| `exclusions` | All six booleans below must be `false` |
| `current_stage_recovery` | `never_sent`, `sent`, or `possibly_sent`, based on retained stage history |
| `now_utc` | Authoritative evaluation instant |
| `enrollment_utc` | Verified recovery enrollment instant, not signup by default |
| `current_stage_entered_utc` | First verified entry to the selected stage |
| `latest_activity` | Explicit verified absence, or the latest qualifying action and UTC clock, as below |
| `last_recovery` | Explicit verified absence, the latest successful send at any stage, or an unresolved attempt, as below |

`verification` must contain:

- `stage_history`: classification, first-entry clock, highest-ever history, and source/timezone provenance are sufficient.
- `activity_coverage`: trustworthy evidence covers **all** qualifying saved actions over the relevant interval; absent instrumentation is not inactivity.
- `sharing_history`: successful Basic/Premium sharing history is reliable, including retained evidence after supported deletion.
- `recovery_history`: durable stage-send and cross-stage history is complete; recreating an entity does not reset it.
- `ownership`: all supplied records and events belong to the same member or their owned entities.
- `lifecycle`: account/entity/history relationships and timestamp chronology are consistent.

`exclusions` must explicitly check `opt_out`, `administrator_or_test`, `invalid_recipient`, `active_trip_or_monitoring`, `contradictory_lifecycle`, and `other` established exclusions. Any true exclusion prevents eligibility; missing or malformed checks hold it. Unknown verification must not be defaulted to true, nor unknown exclusions to false.

### Qualifying activity

`latest_activity` is either `{state = "none_verified"}` or:

```cfml
{
  state = "recorded",
  at_utc = "2026-09-07T12:00:00Z",
  action = {
    entity = "vessel",
    operation = "save",
    changed = true,
    successful = true,
    member_initiated = true,
    owned = true,
    persisted = true
  }
}
```

Allowed entities are `vessel`, `shore_contact`, `operator`, `passenger`, `saved_waypoint`, `route`, `route_leg`, `draft`, and `draft_contacts` (saved Draft contact selections). `create` requires a successful member-initiated owned persisted creation. `save` additionally requires an actual change. Ownership for a route leg or Draft selection includes its parent relationship.

`isQualifyingActivity(action)` checks these supplied action attributes; it does not authenticate an event or establish coverage. Login, page views, modal opens, unchanged saves, failed validation, browser-only actions, purchases, deletion, and automated maintenance do not qualify. Unknown extra fields such as `login_at_utc` are ignored and never used as clocks.

A caller must select the latest **qualifying** action, not the latest generic event. If it asserts a nonqualifying action as `latest_activity`, the evaluator holds the input instead of pretending activity coverage is complete. `none_verified` is valid only with complete activity coverage and must not contain an action or timestamp.

### Recovery history

`last_recovery` is one of:

```cfml
{state = "never_sent"}
{state = "sent", stage = "B", at_utc = "2026-09-07T00:00:00Z"}
{state = "possibly_sent"}
```

A sent record must name a lower stage than the current never-sent stage. A same/higher-stage send contradicts the supplied stage/send history and holds it. `never_sent` must not include a send timestamp or stage. Unknown states hold it. A verified failed, definitively unsent attempt does not count as sent, but any uncertainty must remain `possibly_sent` until resolved by a future system.

## Results

Every result contains only `eligible`, `decision`, `reason`, and `interval_seconds`. `decision` is `ELIGIBLE`, `DEFERRED`, `HELD`, or `SUPPRESSED`. Only `ELIGIBLE` sets `eligible = true`.

`ELIGIBLE` and `DEFERRED` additionally return `anchor_utc`, `eligible_at_utc`, and nonnegative `seconds_until_eligible`. Held/suppressed results intentionally omit predictive dates. No member identifiers, recipient details, raw evidence, or input metadata are returned. Reasons identify the first relevant decision gate; they are not an exhaustive audit of the input.

Safe empty-input example:

```cfml
policy = createObject("component", "fpw.includes.InactiveMemberRecoveryPolicy");
result = policy.evaluate({}); // HELD; eligible = false
```

## Validation and limits

Runtime contract coverage is in `tests/specs/InactiveMemberRecoveryPolicySpec.cfc`. The localhost-only TestBox runner is:

```text
http://localhost:8500/fpw/tests/inactive-member-recovery-policy-runner.cfm?confirm=RUN_INACTIVE_MEMBER_RECOVERY_POLICY_TESTS
```

Static scope checks run with:

```sh
node --test tests/inactive-member-recovery-policy.test.mjs
```

Tests use in-memory evidence only. Stage C/D cases validate already-classified inputs, not actual route/Draft creation. Sharing/deletion and same-stage tests validate supplied retained history, not persistence through a database deletion. The implementation does not verify live member eligibility or deliver any email.

Reliable UTC activity coverage, historical enrollment checks, durable non-regressing stage/send history, and complete sharing suppression remain integration prerequisites. This task does not add those records, repair legacy data, instrument product actions, enroll accounts, or schedule/send recovery. Existing Basic/Premium sharing, departure reminders, and application flows are unchanged.
