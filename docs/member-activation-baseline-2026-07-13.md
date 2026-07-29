# FPW Member Activation Baseline

Date: 2026-07-13

## Purpose

This baseline records the first formal review of genuine external-member activation in FloatPlanWizard. It establishes a reusable starting point for personalized outreach and for measuring replies, return visits, and progression through the activation funnel.

This document is reporting and documentation only. It does not change application behavior, member access, entitlements, email delivery, routes, float plans, or analytics instrumentation.

## Scope and Evidence Reviewed

The baseline covers four genuine external members identified in the verified July 13, 2026 database review. Four internal or test users were excluded.

Evidence was limited to the supplied verified facts concerning:

- Account creation dates.
- Entitlement status.
- Saved vessel and shore-contact records.
- Route and route-leg evidence.
- Float-plan creation, activation, send, check-in, and close evidence.
- Same-day versus later-calendar-day activity.
- Application welcome-email success logging.

Successful application email logging is treated only as evidence that FPW recorded the send operation. It is not proof of inbox placement, delivery, opening, or link clicking. No raw SQL dumps or email-log lines are included in this repository document.

## Funnel Definitions

| Stage | Definition | Required evidence |
| ---: | --- | --- |
| 1. Signup completed | A genuine external-member account was successfully created. | Verified user record with a supplied signup date. |
| 2. Vessel created | The member saved at least one vessel. | Verified vessel row linked to the member. |
| 3. Shore contact created | The member saved at least one shore contact. | Verified saved shore-contact row linked to the member. |
| 4. Route started | The member began route construction and saved route evidence. | Verified route record or route leg. |
| 5. Route completed | The route has sufficient verified completion evidence for trip planning. | Completed route structure and required leg or generation evidence. |
| 6. Float plan created | At least one float-plan record exists for the member. | Verified float-plan row linked to the member. |
| 7. Float plan activated | The member activated a float plan for operational use. | Verified activation status or activation event. |
| 8. Plan shared with another person | The plan was sent to someone other than the member. | Verified destination belongs to another person and a send was recorded. |
| 9. Trip completed | The activated trip reached a completed or closed state. | Verified check-in and completion or close evidence. |
| 10. Returned on another calendar day | The member had verified activity on a later calendar day. | Verified dated activity on a calendar day after the earlier activity. |

Important distinctions:

- A partial route is not a completed route.
- Sending a plan to oneself is not meaningful sharing with another person.
- Same-day activity is not a later-day return.
- A successful application email log is not proof of inbox delivery or engagement.

## Anonymized Member Baseline

| Member | Access | Highest verified stage | Verified activation evidence | Later-day return |
| --- | --- | --- | --- | --- |
| Member A | Basic/public flow | Completed float-plan workflow | Two float plans were activated, sent, checked in, and closed; sharing was self-directed rather than to another person. | No verified later-day return |
| Member B | Premium | Vessel setup | A vessel was saved; no shore contact, route, or float plan was verified. | No verified later-day return |
| Member C | No entitlement found | Signup | No vessel, shore contact, route, or float plan was verified. | No verified later-day return |
| Member D | Premium | Partial route | A route was started with one verified leg, but no completed route, route instance, route progress, or float plan was verified. | No verified later-day return; possible same-day activity is excluded |

## Aggregate Metrics

| Metric | Count |
| --- | ---: |
| Genuine external members reviewed | 4 |
| Internal/test users excluded | 4 |
| Members with a vessel | 2 |
| Members with a saved shore contact | 0 |
| Members with a route started | 1 |
| Members with a completed route | 0 |
| Members with a float plan created | 1 |
| Members with a float plan activated | 1 |
| Members with a completed float plan | 1 |
| Members who meaningfully shared a plan with another person | 0 |
| Members with a verified later-day return | 0 |

## Key Findings

- FPW currently has multiple activation drop-off points rather than one universal onboarding failure.
- No genuine member created a saved shore contact.
- Neither Premium member reached an activated float plan.
- The Basic-flow member completed the float-plan lifecycle but sent the plan to himself.
- The Premium route-builder member stopped with a partial route.
- The immediate next step is personalized outreach followed by measurement of replies and returns.

## Working Hypotheses

These are working hypotheses, not verified causes:

- **Member A:** The primary friction may be retention and meaningful sharing after completing the core float-plan workflow.
- **Member B:** The next step after vessel creation may not have been sufficiently clear.
- **Member C:** Immediate onboarding may not have presented one clear first action.
- **Member D:** Route-builder completion may have become unclear after the route was started.

## Personalized Outreach Plan

No outreach is marked as sent in this baseline.

| Member | Outreach purpose | Offer | Initial status |
| --- | --- | --- | --- |
| Member A | Request feedback about the completed float-plan experience. | Personal assistance only; no promotion or trial extension. | Pending |
| Member B | Offer personal help creating the first trip. | Personal assistance only; no promotion or trial extension. | Pending |
| Member C | Offer one simple starting step and personal help. | Personal assistance only; no promotion or trial extension. | Pending |
| Member D | Offer help finishing the route and ask where the process became unclear. | Personal assistance only; no promotion or trial extension. | Pending |

## Measurement Plan

For each member, update the private tracking workbook when evidence becomes available:

1. Record the outreach date only after the message is confirmed sent.
2. Record delivery status without treating application success logging as inbox-delivery proof.
3. Record reply status and a concise reply summary.
4. Record whether the member returns to FPW after outreach.
5. Record the next action and follow-up date.
6. Review results after seven days.
7. Review activation and return evidence again after thirty days.

Later activity should be counted as a return only when it occurs on another calendar day. Funnel stages should advance only when the required evidence is verified.

## Privacy Statement

This repository document is intentionally redacted. It contains only anonymized labels Member A through Member D and aggregate activation evidence.

Member names, email addresses, user IDs, vessel names, outreach subjects, and other identifying details are maintained only in a private workbook outside the Git repository and outside the public webroot. Password hashes, reset tokens, session identifiers, Stripe identifiers, authentication data, raw database dumps, and raw email logs are not part of this baseline document.
