# FloatPlanWizard Recovery Center — Administrator User Manual

An operations guide for the FPW site administrator and owner.

**Verified against the current implementation: October 4, 2026.** This guide describes available controls; it does not certify that production deployment or live sending is enabled. Recovery Center dates and times are **UTC**. The separate Scheduled Tasks page displays its own effective scheduler timezone.

[Open the printable Admin manual](../admin/recovery-center-user-manual.cfm). In that version, use your browser’s Print command to print or save as PDF.

## 1. What the Recovery Center is

Recovery Center helps you follow up with enrolled members who have unfinished FPW setup or planning work. It shows who is waiting, what FPW would send next, what happened during processing, and what members did afterward.

FPW can send **exactly three automated recovery contacts** per enrolled recovery sequence:

| Recovery contact | Purpose |
| --- | --- |
| #1 | Initial reminder |
| #2 | Practical follow-up |
| #3 | Final automated reminder |

**Contact number identifies the position in the three-contact sequence. Destination stage answers “Where should this member resume FPW?”** They are independent. “Next recovery contact: #2” normally means Contact #1 has been accepted and #2 is next. Contact #2 can still point to destination A.

**Returned** means qualifying authenticated behavior was observed within an accepted automated message’s attribution window. **Engaged** means qualifying meaningful FPW work or successful sharing was observed in that window. Neither is established by sending an email.

Recovery Center has six views: **Dashboard**, **Recovery Queue**, **Runs**, **Members**, **Performance**, and **Settings**. It also supports individual pauses, exclusions, previews, and personal follow-up.

It does not provide Force Send, Skip Contact, Restart Cycle, Manual Recovered, a manual transport-retry button, or an automated-template editor. It does not prove inbox delivery. Enrollment and scheduled-task management have separate Admin pages.

## 2. Getting Started

1. Sign in with an administrator account and open **Admin → Recovery Center**.
2. Confirm the page loads and its six views are available. Resolve any unavailable/session error before taking actions.
3. Open **Settings** and check the three displayed timing values. Defaults are 24 / 24 / 24 hours; saved values may differ.
4. Open **Members** or **Recovery Queue** and confirm the intended members are enrolled. Use **Recovery Enrollment** if enrollment needs review.
5. Review the queue’s **Decision**, **Reason**, and **Eligible UTC**. Check **Needs attention** and held members.
6. Open **Admin → Scheduled Tasks**. Use **Refresh scheduler state** to check the actual recovery schedule, including whether it is paused.
7. Confirm the runner’s intended mode and production readiness with the technical operator. In **Recovery Center → Runs**, check recent execution, mode, results, and errors.

A visible Recovery Center, an enrolled member, or an active schedule alone does not establish that emails can send. Follow section 7 before expecting automated mail.

On the **Dashboard**, member counts such as **Enrolled**, **Eligible now**, **Waiting**, **Held**, **Paused**, **Excluded**, **Sequence complete**, and **Needs attention** can overlap. Do not add them together as separate populations. The attention preview shows only the first ten matching members, not a severity ranking.

## 3. How members enter Recovery

Keep these three steps separate:

| Step | What it means |
| --- | --- |
| Enrollment | FPW has recorded the member’s recovery starting point. |
| Eligibility | The next contact currently passes timing, preference, history, and state checks. |
| Sending | An authorized processing run prepares and submits that contact, then records its result. |

Normal successful signup automatically attempts enrollment after the account is saved. The administrator usually does nothing. If enrollment cannot be confirmed, signup can still succeed; investigate a missing member rather than assuming signup guaranteed enrollment. Login and recovery processing do not enroll members.

Use the separate **Admin → Recovery Enrollment** page to review selected existing members:

1. Enter **Member IDs to review**: 1–100 distinct positive member IDs, separated by commas or whitespace.
2. Click **Preview selected members**.
3. Review each row’s **Outcome**, **Reason**, **Enrollment UTC**, **Coverage at review**, and any **Diagnostic reference**.
4. Confirm that the intended candidates are marked **ENROLLABLE**. Other outcomes require review, not an assumption that enrollment will happen.
5. Check **I reviewed these member IDs and authorize enrollment of this eligible selection.**
6. Click **Enroll reviewed eligible members** within the 15-minute review period.
7. Read **Newly enrolled**, **Already enrolled**, **Skipped**, and **Failures**, including the individual results.
8. Return to **Recovery Center → Recovery Queue** or **Members** and search for the member.

There is no “enroll all” control. If the review expires, preview again.

Already-enrolled members retain their original enrollment and contact position. Re-enrollment does not restart recovery. Enrollment does not send mail, change a schedule, bypass the first delay, or supply missing historical evidence. A member can enroll successfully and still be held because **Coverage at review** is unverified. Give the diagnostic reference or hold reason to the technical operator.

## 4. Recovery timing

| Setting | Default | What it controls |
| --- | --- | --- |
| First Recovery Delay | 24 hours | Waiting period before Contact #1 can become eligible. |
| Recovery Stage Interval | 24 hours | Spacing before Contacts #2 and #3. “Stage” in this setting means contact spacing, not progress from A to B. |
| Recovery Attribution Window | 24 hours | Time after an accepted automated message in which qualifying return/engagement can be credited to it. |

Each setting independently accepts a whole number from **1 through 720 hours**.

For Contact #1, FPW applies the first delay to the latest relevant starting point, including effective enrollment start, genuine progress-stage entry, and qualifying activity. For Contacts #2 and #3, it applies the contact interval using those checks and the prior accepted contact’s time.

Later qualifying meaningful activity or genuine progress can postpone the next contact. It does not put the member back at Contact #1. Login, an ordinary page view, an open, or a click is not by itself meaningful activity for this inactivity calculation.

**Example:** With 24-hour settings and no later qualifying activity, Contact #1 can become eligible 24 hours after the effective start. Contact #2 can become eligible 24 hours after #1 is accepted; #3 can become eligible 24 hours after #2 is accepted. Later qualifying activity can move those times later.

**Eligible UTC is an earliest eligibility time, not a delivery appointment.** The next authorized scheduled batch must still evaluate and accept the contact.

After Contact #3 is accepted, the **Automated sequence complete** label applies. This does not mean the member returned or engaged. Time passing, activity, destination changes, pause/resume, and exclusion changes do not restart the sequence.

Attribution settings are frozen on each accepted message. Changing that setting affects future accepted messages, not earlier messages’ deadlines. Changing any timing value does not itself send mail.

## 5. How to change timing settings

1. Open **Settings**.
2. Enter **First Recovery Delay (hours)**, **Recovery Stage Interval (hours)**, and **Recovery Attribution Window (hours)**.
3. Click **Preview impact**.
4. Review the counts and the member/contact/destination rows showing before-and-after eligibility.
5. Pay particular attention to the warning about newly immediate eligibility.
6. Check **I reviewed the affected members and any immediately eligible contacts.**
7. Click **Save reviewed timing**.
8. Look for **Reviewed timing settings saved. No mail was sent.**
9. Verify the displayed values and the before/after entry in **Settings & administrative audit**.

The preview means:

| Impact item | How to use it |
| --- | --- |
| Affected members | Members whose calculated eligibility time changes. An attribution-only change may not change this count. |
| Earlier eligibility | Calculable eligibility times that move earlier. |
| Later eligibility | Calculable eligibility times that move later. |
| Newly immediate eligibility | Members not eligible under the current values who become eligible under the proposed values. They may be considered by the next authorized processing run. |
| Earliest resulting eligibility | The earliest calculable proposed timestamp. It is not a scheduled send time. |

Read the current/proposed decisions alongside timestamps; a date alone does not remove a block.

Editing a setting invalidates the preview. Reviews expire after 15 minutes and can be used once. If you see **IMPACT_CHANGED_REVIEW_AGAIN**, create a new preview and review the changed population before saving.

### Setup only: one-time recovery-start reset

The Settings page also has a rollout control: **Preview initial reset**.

Use it only as part of the approved initial deployment, with recovery processing stopped and the technical operator’s backup and deployment checks complete:

1. Click **Preview initial reset** and review the existing enrolled cohort count.
2. Check **I reviewed the cohort and authorize the one-time recovery-start reset.**
3. Click **Apply reviewed reset**.
4. Verify the recorded completion time and member count.

This records one new effective UTC starting point for the reviewed existing cohort while preserving original enrollment, progress, and history. Later signups keep their actual enrollment start.

It requires empty recovery delivery history, including attempts or claims, and can run only once. After completion, the preview is disabled. This is not a member restart tool or a fix for slow recovery.

For **COHORT_CHANGED_REVIEW_AGAIN**, review again. For **RESET_REQUIRES_EMPTY_LEDGER** or **RESET_ALREADY_COMPLETED**, stop and have the technical operator verify the rollout state. Do not delete history to make the reset available. Local reset evidence does not establish that production has been reset.

## 6. Understanding the Recovery Queue

The queue includes enrolled members who are waiting, blocked, paused, or complete as well as eligible members. It is not a list of guaranteed upcoming emails.

| Column | Meaning |
| --- | --- |
| Member | Click the email address to open member detail. |
| Recovery contact | The next contact, such as **#2 of 3**, **Automated sequence complete**, or **Unknown**. |
| Current destination | The member’s currently verified A/B/C/D destination. |
| Decision | Broad eligibility result. |
| Reason | The specific explanation for that result. |
| Eligible UTC | Calculated eligibility time, where available. |
| Response | Member-level **Returned** and **Engaged** observations from attributed automated-contact history. |

The queue does **not** have a last-send, opened, clicked, or message-result column. Open the member to see **Last accepted contact**, **Last accepted destination**, and **Message history**.

| Decision or state | Plain meaning |
| --- | --- |
| ELIGIBLE | Current checks permit consideration of the next contact. It has not necessarily sent. |
| DEFERRED | Waiting for the required interval or a later activity-based time. |
| SUPPRESSED | A verified block applies, such as pause, exclusion, preference, completed sequence, or an unresolved claim. Read the reason. |
| HELD | Missing, contradictory, unavailable, or uncertain evidence prevents safe processing. |
| Automated sequence complete | All three automated contacts were accepted. It is separate from Returned/Engaged. |

In member history, **SEND_ACCEPTED** is the recorded submission result, while **Opened**, **Clicked**, **Returned UTC**, and **Engaged UTC** are separate observations. A failure is **SEND_FAILED**; an unresolved result is **OUTCOME_UNKNOWN**. Section 13 explains each message result.

To search and filter:

1. Enter a first name, email, or member ID in **Search member**.
2. Optionally select **Destination stage**, **Next contact**, and **Recovery state**.
3. In **Decision**, use an exact decision such as **ELIGIBLE**, **DEFERRED**, **HELD**, or **SUPPRESSED**. Matching ignores letter case; this field does not search reason text.
4. Click **Apply filters**.
5. Use **Previous** and **Next** for lists longer than 25 members.

To clear filters, clear the text fields, select the “All” options, and click **Apply filters**. There is no separate reset-filters button.

**Eligibility evaluated at … UTC** identifies the snapshot time. Sending performs fresh checks. The **Members** view offers the same member columns with **Search member → Search**, without the queue’s additional filters.

## 7. How automated recovery emails are actually sent

The administrator normally does not click a Send button for automated recovery.

1. The member is enrolled.
2. Current timing and other requirements make the next contact eligible.
3. The native scheduled task invokes the protected recovery process.
4. FPW checks enrollment, contact history, administrative state, preferences, and eligibility.
5. It determines the next numbered contact from confirmed accepted history and checks the member’s actual current A/B/C/D progress.
6. It reserves that contact and rechecks eligibility and destination.
7. It renders that contact’s wording with the current valid destination.
8. Immediately before submission, it independently revalidates state, ownership, preferences, and destination. Stale preparation is canceled.
9. It submits through the mail transport and records the outcome.
10. Only confirmed accepted history allows progression to the next contact.

All of these must be true: a valid enrolled member, a due contact, valid history/destination/preferences/state, an authorized runner, permitted live processing, and an actual execution. Processing uses bounded batches, so one run may not evaluate every member.

### Check the schedule outside Recovery Center

Open **Admin → Scheduled Tasks** and click **Refresh scheduler state**. Inspect **Environment**, **Effective scheduler timezone**, and **Existing FPW tasks**.

Find the task with approved endpoint **/app/scheduled/run-inactive-member-recovery.cfm**. Task names vary. Check **Frequency**, **Start date / time**, **Timeout**, and **Paused**.

Confirm its intended dry-run or processing mode with the technical operator: the task listing hides protected runner parameters. If resuming the approved task is appropriate, use its **Resume**, refresh scheduler state, then inspect **Recovery Center → Runs** for actual execution and mode.

A member’s **Resume recovery** is different from a scheduled task’s **Resume**. Neither changes the runner’s live permission or repairs its authorization.

### If an approved schedule must be created

First check that the intended schedule does not already exist, then:

1. Click **New Scheduled Task**.
2. Enter **Task Name**, **Group**, and **Scope**. Use the environment’s required name prefix: **FPW_PROD_** or **FPW_DEV_**.
3. For **Script to run**, choose **Inactive member recovery (new schedules use dry run)**.
4. Enter a future **Start Date** and **Start Time** in the displayed scheduler timezone.
5. Choose the approved frequency: **Every** with Hours/Minutes/Seconds, **One-Time**, or **Recurring** with Daily/Weekly/Monthly.
6. Set optional end date/time and **Request timeout in seconds** as required for the approved schedule.
7. Click **Create Schedule**, refresh native state, and verify the subsequent run.

Creation makes the future-start task active. Ordinary new recovery schedules use dry run; an existing reserved configured identity can preserve its configured mode. Confirm the resulting mode. **Edit** changes schedule details, not the runner’s dry-run/live setting or credentials. If the page is read-only or a control is disabled, use the displayed reason and technical operator rather than attempting a bypass.

There is no live-send toggle in Recovery Center. Production deployment, runner authorization, live permission, and transport readiness require technical verification outside this page.

Scheduled Tasks also has generic **Run Now**: it requires the exact task name and **Request Run Now** confirmation. It invokes the configured mode, potentially live, with all recovery safeguards. **Run requested** proves only that the scheduler accepted the request. It does not force a particular member’s email or prove completion. Normal recovery operation uses the approved schedule.

## 8. What prevents an automated recovery email from sending

Use **Recovery Queue → Reason** or open the member’s current **Decision** and **Reason**. For a historical attempt, inspect **Runs** and **Message history**.

| Example | What to check or do |
| --- | --- |
| Meaningful activity happened later | The next eligibility time may move later. Review activity and Eligible UTC. |
| Member is actively using relevant trip features or has successfully shared | A product-state suppression may apply. Respect the recorded reason. |
| Still waiting | Check **DEFERRED_WAITING_FOR_INTERVAL** and Eligible UTC. |
| Paused or excluded | Check both flags in member detail. Only clear the intended block. |
| Non-essential-email opt-out or unverifiable preference | Respect the preference; there is no composer override. |
| Invalid or unverifiable destination/ownership | Refresh eligibility; escalate a persistent hold. |
| Unresolved previous send | Review the attempt result. Obtain technical reconciliation before another submission. |
| Sequence complete | There is no automated Contact #4. |
| Missing history, coverage, settings, or other validation | Read the hold reason and have the technical operator resolve the evidence or configuration issue. |
| Runner or scheduler unavailable | Check native task state, latest run, and authorized runner configuration. |

A prepared email can be canceled when state or destination changes before submission. Cancellation does not consume a contact.

## 9. Recovery Contact #1, #2, and #3

**#1** is the initial reminder, **#2** the practical follow-up, and **#3** the final automated reminder. There is no Contact #4 and no automatic restart.

For example, each contact below can be independently eligible:

| Contact | Current destination at that send |
| --- | --- |
| #1 | A — Add Vessel |
| #2 | A — Add Vessel |
| #3 | B — Trip Planner, because the member actually saved a vessel |

All three can also point to A, or all three to C, if that remains the valid destination. Contact #1 can start at any valid destination.

A known send failure retries the **same contact**, subject to the existing limit of three transport attempts. Those attempts are not three recovery contacts. An uncertain result holds the sequence. Earlier attempt content stays in history even if a retry uses a newly valid destination.

## 10. A/B/C/D destinations

| Stage | Resume point | Email button |
| --- | --- | --- |
| A — Add Vessel | Continue vessel setup. | **Continue Vessel Setup** |
| B — Trip Planner | Plan a trip using saved vessel details. | **Start Planning a Trip** |
| C — Saved/Planned Route | Continue valid saved planning work. | **Continue Trip Planning** |
| D — Draft Float Plan | Finish a valid draft Float Plan. The interface calls this **Draft Editor**. | **Continue Your Float Plan** |

FPW recalculates the destination before every automated send using actual progress, ownership, and available valid objects. Time and accepted contacts do not create progress.

**Current destination** describes the member now. A destination shown in an older message describes that particular attempt. A difference is expected when the member has progressed.

## 11. Email tracking and reactions

| Signal | What it establishes |
| --- | --- |
| Opened | A tracking image request was observed. |
| Clicked | A valid recovery link request was observed. |
| Returned | Qualifying authenticated behavior occurred within the message’s attribution window. |
| Engaged | Qualifying durable, meaningful FPW work or successful sharing occurred within that window. |

Opens are approximate: mail software can preload or block images. A positive open is not proof the person read the email, and zero opens is not proof they did not. Link scanners can also produce clicks.

An authenticated login or qualifying member-page visit can establish Returned. Engagement requires meaningful activity, such as creating or changing qualifying member/planning data or successfully sharing. Login, ordinary views, unchanged saves, opens, and clicks alone do not establish engagement.

The attribution window defaults to **24 hours**, using the configured value when the message is accepted. Look at **Attribution deadline UTC** for the actual frozen deadline. FPW credits qualifying behavior to the latest accepted automated contact whose window contains the original activity time, without repeatedly crediting the same source activity.

Open/click tracking remains valid for **90 days from acceptance**. Signals after the attribution deadline can appear as late opens/clicks while tracking is still valid. They do not extend or reopen attribution. Activity outside the window can appear in the timeline without becoming an attributed response to that earlier message.

Recovery links do not sign anyone in or bypass normal account access. Personal follow-ups do not use the automated tracking/attribution metrics.

## 12. Needs Attention

Use **Recovery Queue → Recovery state → Needs attention → Apply filters** for the full list.

A member can need attention when:

- An automated send failed or has an unknown outcome, without a later confirmed success for that same contact.
- An automated preparation remains unresolved for more than ten minutes.
- The latest accepted automated message’s attribution deadline has passed without attributed engagement.
- The current contact has a recorded failure.

A later accepted automated message replaces the previous accepted message for the deadline check. An old failed attempt does not keep its failure flag after that same contact succeeds.

“No response,” “opened but no return,” “clicked but no return,” and “returned but no engagement” are ways to interpret message history. They are **not separate queue filter categories**. A return alone does not satisfy engagement, and sequence completion can coexist with Needs attention.

For each exception:

1. Open the member and inspect the latest automated message, its result, deadline, and observations.
2. Check current eligibility, preferences-related reasons, pause/exclusion, and meaningful activity.
3. For failure or unknown outcome, have the technical operator investigate. Do not repeatedly resend.
4. For an expired window without engagement, decide whether an allowed personal follow-up would help. Do not reset or force the automated sequence.

Not every processing error appears in this list. Review **HELD** decisions and **FAILED**, **INCOMPLETE**, or **COMPLETED_WITH_GAPS** runs separately.

## 13. Member Recovery Detail

Open a member by clicking their email in **Recovery Queue** or **Members**.

The summary shows **Member ID**, **Next recovery contact**, **Current destination stage**, **Last accepted contact**, **Last accepted destination**, **Decision**, **Reason**, **Eligible UTC**, **Paused**, **Excluded**, **Returned**, and **Engaged**.

Returned/Engaged in this summary can reflect an earlier automated contact. Use the message rows to understand the latest contact. **Unknown** means verification is unavailable; it is not the same as “no,” “not paused,” or “no activity.”

Below the summary:

| Section | Use it to… |
| --- | --- |
| Current message preview | Inspect what the next contact would currently look like. |
| Message history | Read contact, destination, transport attempt, result, acceptance time, attribution deadline, open/click counts, and return/engagement times; preview stored content. |
| Eligibility history | Compare the original and final decisions recorded during earlier evaluations. |
| Activity & recovery timeline | Follow enrollment, recovery events, and recorded authenticated/member activity by UTC time. |
| Personal follow-up | Review and submit a separate administrator-written email if allowed. |

There is no dedicated “last activity” summary field. Read relevant member-action entries in **Activity & recovery timeline**, newest first. The latest administrator or recovery event is not necessarily qualifying inactivity activity. The timeline uses recorded event names and does not include every site action; use **Eligible UTC** and the current reason for the eligibility conclusion.

Message results mean:

| Result | Meaning |
| --- | --- |
| PREPARED | Preparation recorded; no final result yet. |
| SEND_ACCEPTED | Mail transport acceptance recorded; automated sends also require confirmed contact history. This is not delivery, a read, or engagement. |
| SEND_FAILED | Submission is known to have failed. |
| OUTCOME_UNKNOWN | Submission or required confirmation could not be safely established. Investigation is required. |
| CANCELED | Prepared attempt canceled, for example after state/destination changed. It was not accepted as a contact. |

Opened/Clicked in message history are observation counts and can exceed one. A **Personal** row is separate from numbered automated contacts.

Messages, evaluations, and timeline each paginate independently, 25 rows at a time. Use **Previous messages / Next messages**, **Previous evaluations / Next evaluations**, and **Previous history / Next history**.

## 14. Previewing a recovery email

1. Open the member.
2. Under **Current message preview**, click **Preview next contact**.
3. Check the subject shown in the dialog.
4. Check the **Contact**, **Destination**, and **Template** metadata.
5. Verify the destination-specific button, greeting, personalization, and wording.
6. Expand **Plain text** if you want to inspect the text alternative.
7. Click **Close**.

For example, **recovery.contact_2.destination_B.v1** means Contact #2 using destination B and template version 1.

Preview uses current information. Waiting or paused members can preview when the destination and rendering checks succeed. It does not send anything, record tracking, or prove the member is eligible. Preview links are disabled and bearer tokens are redacted. A destination or compliance validation problem can prevent a preview. If Next recovery contact is Unknown, the preview can default to Contact #1; treat it as illustrative and resolve the hold before relying on it as the actual next contact.

After the sequence completes, **Preview next contact** is disabled. To see an earlier attempt, use its **Message history → Preview**. That shows the historical content and destination rather than today’s classification. An accepted historical message shows what was submitted, not proof of inbox delivery.

## 15. Sending a personal follow-up email

Use personal follow-up when a member needs individual help, after reviewing their history.

1. Open the member and inspect recent messages, results, and activity.
2. Confirm **Paused** and **Excluded** are false and review the current reason for any email-preference block. FPW checks preferences again on the server.
3. Scroll to the inline **Personal follow-up** form.
4. Enter **Subject** (1–160 characters).
5. Enter **Message (plain text)** (1–10,000 characters). Formatting is plain text; a shared sign-off and compliance footer are added.
6. Click **Review personal follow-up**.
7. Read the preview, then click **Close**. Check the displayed recipient and subject summary.
8. Check **I reviewed the recipient and content and authorize this personal follow-up.**
9. Click **Send reviewed follow-up**.
10. Read **Personal follow-up result: [status]. No automatic retry was attempted.**
11. Reopen current member history if needed and verify the **Personal** message row’s **Result** and **Accepted UTC**. The activity/recovery timeline provides additional recorded recovery events.

FPW resolves the recipient from the member record. There is no editable “To” address or option to override compliance restrictions.

Personal follow-up is allowed while automation is waiting, after a previous contact, or after sequence completion, provided the member and preferences permit it. Pause, exclusion, non-essential-email opt-out, invalid recipient, or unverifiable required checks block it.

It does not consume a numbered contact, change recovery timing, or enter automated performance/attribution reporting. Missing automated tracking on a personal row is not a send failure.

If you edit content, reopen the member, or the review expires after 15 minutes, review again. Changed member/recipient/state information can also invalidate preparation.

There is no automatic personal-email retry. For a known failure, resolve the cause before a fresh reviewed submission. For an unknown result or an unverified server response, reopen history and obtain technical reconciliation before submitting again.

## 16. Pause Recovery

Use pause for a temporary, deliberate stop to a member’s recovery emails.

1. Open the correct member.
2. Click **Pause recovery**.
3. Confirm the completed action and **Paused** state in the summary.

This action takes effect without a second confirmation dialog. It blocks both automated recovery and personal follow-up.

Contact position and all history remain. **Clocks continue while paused.** Pause does not erase an earlier message or undo mail already submitted.

## 17. Resume Recovery

1. Open the member and check their current reason, timing, and exclusion state.
2. Click **Resume recovery**.
3. Confirm **Paused** is false and read the refreshed decision and **Eligible UTC**.

Resume acts without a second confirmation dialog. Because clocks continued, the member may already be eligible; do not rely on an extra eligibility-warning dialog.

Resume clears only pause. An excluded member remains excluded. It does not send immediately or start/resume the scheduled task. The next authorized processing run performs all send checks.

## 18. Exclude from Recovery

Use exclusion when the member should remain out of recovery until you explicitly decide otherwise.

1. Open the correct member.
2. Click **Exclude member**.
3. Confirm **Excluded** is true.

The action is immediate, without a second confirmation dialog. Exclusion is indefinite until removed and blocks both automated and personal recovery emails. It preserves enrollment, clocks, contact position, and history.

## 19. Remove Exclusion

1. Open the member and confirm that restoring recovery is appropriate.
2. Click **Remove exclusion**.
3. Confirm **Excluded** is false, then check **Paused**, **Decision**, **Reason**, and **Eligible UTC**.

Removing exclusion does not clear a separate pause. Timing and history remain, so the next contact may already be eligible. This action does not send email; the scheduler still performs automated processing.

## 20. Eligibility Refresh

Use this after relevant member activity/state changes or while investigating an unexpected decision.

1. Open the member.
2. Click **Refresh eligibility**.
3. Read the refreshed contact, destination, decision, reason, and eligibility time.
4. Review the new **Eligibility history** entry or the **admin_refresh** dry run in **Runs**.

It records a fresh evaluation. It does not enroll the member, claim a contact, send mail, or override a hold.

The header’s **Refresh view** simply reloads the current view. It is different from this recorded member evaluation. To verify an uncertain message result, reopen the member’s current message history rather than assuming a list refresh proves the outcome.

## 21. Recovery Runs

A run is one execution of recovery evaluation/processing. It can come from the runner or an administrator’s eligibility refresh.

Open **Runs**. The list shows **Run**, **Source**, **Mode**, **Status**, **Started UTC**, **Finished UTC**, **Evaluated**, **Eligible**, **Accepted**, **Failed**, and **Unknown outcome**.

- **Evaluated:** members actually evaluated in that execution.
- **Eligible:** initially eligible evaluations; later checks can still cancel preparation.
- **Accepted:** recorded accepted submissions, not delivered emails.
- **Failed / Unknown outcome:** known failures versus unresolved outcomes.
- **Dry run:** records decisions without enrollment, contact claims, or email.
- **Processing:** execution in processing mode; this does not guarantee any member sent.

Waiting, suppressed, and held are visible in member-level decisions. They are not separate columns in the current run list.

| Run status | Meaning |
| --- | --- |
| RUNNING | No final completion recorded yet. |
| COMPLETED | Execution completed with expected reporting. |
| COMPLETED_WITH_GAPS | Reporting records or totals have gaps; investigate before relying on totals. |
| FAILED | The run did not complete successfully. |
| INCOMPLETE | A run remains unfinished for more than five minutes; do not treat it as completed. |

Click a **Run** to see its **Status**, **Source**, **Mode**, **Error**, and member rows. Compare **Initial decision** with **Final decision**, then read **Reason** and **Outcome**. The Outcome field can repeat the final decision; use member message history for detailed transport results.

A historically eligible member can have a later canceled or held result. Historical decisions remain as recorded even if current settings or progress differ.

Use **Previous / Next** for runs and **Previous run evaluations / Next run evaluations** for long member lists.

Some authorization or live-permission failures happen before a run can be recorded. No recent run does not prove the scheduler is working. Check native task state and the runner error with the technical operator.

## 22. Performance

Open **Performance**. **Accepted-message cohort** offers **Last 7 days**, **Last 30 days** (default), **Last 90 days**, and **All history**.

Optionally choose **Contact**, **Destination stage**, and an exact **Template** identifier, then click **Apply filters**. You can copy the template identifier from a message preview.

The summary reports **Accepted messages**, **Observed opens**, **Observed clicks**, **Returned**, and **Engaged**. These count accepted automated messages with at least one corresponding observation, not unique people or total repeated signal events. Personal follow-ups are excluded.

The table groups by the combination of contact, destination, and template. **Open rate**, **Click rate**, **Return rate**, and **Engaged rate** display a numerator, accepted-message denominator, and percentage. A zero denominator shows **no accepted messages**. **Late opens** and **Late clicks** identify late signal counts. Late opens/clicks also contribute to overall observed opens/clicks and their rates. The late counts are subsets of recorded signals; do not add them to the overall totals.

**Example:** If Contact #2 at destination A has 10 accepted messages and 2 with attributed engagement, its Engaged rate is 2/10, or 20%. That says nothing about how destination stage B maps to contact number.

Keep the time basis straight:

- The main cohort is selected by when messages were accepted. Later observations can update those messages’ results.
- **Activity in the selected period** uses the first observed open/click or attributed response time. It can include responses to messages accepted before that period.
- The Dashboard **Recovery funnel** uses all history; Performance starts at 30 days. Match the periods before comparing.
- Funnel signals are independent observations, not necessarily a steadily narrowing series.

**Accepted messages without tracking** identifies missing tracking within the selected cohort. **All-time accepted ledger contacts without message telemetry (all contacts/destinations)** is a global all-history count, unaffected by these filters.

Unknown or missing historical tracking is not proof of zero response. Use observed engagement and its denominator for practical comparisons, while remembering the report shows association with recovery messages, not proof those messages caused the activity.

## 23. Common everyday workflows

| I want to… | Shortest path |
| --- | --- |
| A. Know who will get an email next | **Recovery Queue → Decision: ELIGIBLE → Apply filters**. Inspect Eligible UTC and reasons. This shows current candidates, not a guaranteed send order. |
| B. Know why a member did not get an email | **Members → Search → member → Decision/Reason**, then Message history and the relevant Run. |
| C. See what email a member received | **Member → Message history → accepted row → Preview**. This proves submitted content, not delivery. |
| D. Personally follow up | **Member → history → Personal follow-up → Review personal follow-up → confirm → Send reviewed follow-up**. |
| E. Stop recovery for one member | **Member → Pause recovery** for a temporary stop, or **Exclude member** for an indefinite stop. Both block personal follow-up too. |
| F. Change timing for everyone | **Settings → edit hours → Preview impact → review/check confirmation → Save reviewed timing**. |
| G. Know whether recovery is working | **Performance → choose period/filters**, then inspect engagement rates and denominators. Use Runs and Needs attention to investigate exceptions. |

## 24. Troubleshooting

| Issue | What to do |
| --- | --- |
| No members appear | Clear filters and search again. Review the member in **Recovery Enrollment**. Successful signup alone is not proof enrollment completed. Escalate enrollment failures or page/session errors. |
| Member waits longer than expected | Check current timing values, effective-start/reset history, later meaningful activity/progress, prior accepted contact, and Eligible UTC. Then check the next scheduled run and batch coverage. |
| Email did not send | Check current reason, history, run mode/results, and native task state. Dry runs and settings saves send nothing. Have the technical operator verify authorization/live permission if needed. |
| Send failed | Open the failed attempt and current reason. Known automated failures retry the same contact within the attempt limit; unknown outcomes hold. There is no manual retry button. Escalate persistent failures. |
| Member clicked but is not Engaged | A click does not establish meaningful authenticated activity. Check the actual action and frozen attribution deadline. |
| Member is sequence complete | Three contacts were accepted. There is no Contact #4 or restart control. Review response history; use a permitted personal follow-up if appropriate. |
| Personal follow-up button is disabled | Check pause/exclusion and whether review/confirmation is complete. Server checks can still block preferences, recipient, or stale context. Read the returned reason; do not override it. |
| Settings made members immediately eligible | Review the impact warning before saving. Saving does not send, but the next authorized processing run can. If already saved, inspect the queue before further changes. |
| Recovery task is paused | Use **Scheduled Tasks → Refresh scheduler state**. Resume only the intended, approved task after confirming mode/readiness; verify the next Run. Member Resume does not resume the task. |
| Data is Unknown or tracking is unavailable | Unknown is unverified, not a negative result. Check the field’s reason and missing-tracking counts. The UI does not provide a universal “Not Tracked” status. |
| Review expired or changed | Preview/review again. Do not reuse an old settings, enrollment, or personal-send confirmation. |
| Operation or server response could not be verified | Reopen current history/state before retrying. For possible email submission, obtain reconciliation to avoid a duplicate. |
| Run is failed, incomplete, or has gaps | Inspect the Run’s Error and member rows; provide the run identifier to the technical operator. Do not assume absent reporting means no submission. |

## 25. Safety and operating guidance

- Check the member identity before Pause, Resume, Exclude, or Remove exclusion: these actions have no second confirmation dialog.
- Remember that pauses/exclusions preserve clocks. Clearing them can leave a contact immediately eligible.
- Saving settings, enrollment, previews, and eligibility refresh do not send email.
- Treat **SEND_ACCEPTED** as transport acceptance, not delivered or bounced.
- Do not treat Opened as proof of reading or Clicked as engagement.
- Verify production deployment, runner mode, and mail readiness before enabling operational sending. This manual is not that verification.
- Use **Needs attention** for exceptions, along with Held decisions and run errors, rather than manually intervening in every waiting member.
- Resolve an unknown send outcome before initiating another message. Do not delete history or attempt to restart a completed sequence.

## 26. Quick Reference

### Timing and sequence

| Setting | Default |
| --- | --- |
| First Recovery Delay | 24 hours before Contact #1 eligibility |
| Recovery Stage Interval | 24 hours before Contacts #2 and #3 |
| Recovery Attribution Window | 24 hours, frozen per accepted message |

Each setting: whole hours, 1–720. Later qualifying activity/progress can delay eligibility. Tracking validity: 90 days. Recovery Center times: UTC.

**Contacts:** #1 initial reminder → #2 practical follow-up → #3 final reminder → Automated sequence complete. No #4. Failed transport retries retain the same contact number.

**Destinations:** A Add Vessel · B Trip Planner · C Saved/Planned Route · D Draft Editor (Draft Float Plan). Destination is freshly checked and is independent of contact number.

### Read the result

| Label | Meaning |
| --- | --- |
| ELIGIBLE / DEFERRED | Currently eligible / waiting |
| SUPPRESSED / HELD | Verified block / insufficient or uncertain verification |
| SEND_ACCEPTED | Submission accepted; not proof of delivery |
| SEND_FAILED / OUTCOME_UNKNOWN | Known failure / unresolved result requiring investigation |
| Returned / Engaged | Attributed authenticated return / meaningful activity |
| Sequence complete | Three contacts accepted; not proof of engagement |

### Where to go

| Task | Location/action |
| --- | --- |
| Review/enroll selected members | **Admin → Recovery Enrollment** |
| Find due members or blockers | **Recovery Queue → filters → Apply filters** |
| Preview next or earlier email | **Member → Preview next contact / Message history → Preview** |
| Stop temporarily / indefinitely | **Member → Pause recovery / Exclude member** |
| Restore participation | **Resume recovery / Remove exclusion**; check both flags |
| Recheck a member | **Refresh eligibility**; no email |
| Personal email | **Personal follow-up → Review → confirm → Send reviewed follow-up** |
| Change timing | **Settings → Preview impact → confirm → Save reviewed timing** |
| Inspect processing / effectiveness | **Runs / Performance** |
| Verify the actual schedule | **Admin → Scheduled Tasks → Refresh scheduler state** |

**Remember:** pause/exclusion preserve clocks and history. Clearing a block can leave a member already eligible. Personal email is separate but honors blocks. Unknown outcomes need investigation before another send. No automated Send button exists in Recovery Center.
