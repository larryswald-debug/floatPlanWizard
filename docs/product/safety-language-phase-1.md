# Safety Language Phase 1

## Scope and controlling audit

This change implements the customer-facing safety-language corrections in findings F039 through F057 and the Priority 0 safety/legal section of `docs/product/customer-facing-language-audit.md`.

The implementation is limited to customer-facing wording, labels, accessibility text, and adjacent safety presentation. It does not change monitoring algorithms, states, timers, recipients, triggers, route calculations, check-in behavior, payment behavior, entitlements, credit consumption, database schema, or API response shape.

## Audit findings addressed

| Findings | Surface | Correction |
|---|---|---|
| F039-F041 | Follow | Removed real-time/live/current-position claims; separated reported GPS check-ins from estimated route progress and retained the existing update timestamp. |
| F042-F044 | Active Cruise | Reframed the map as a planned-route view; added the no-position state; renamed the selected person to Shore Contact. |
| F045 | Monitoring | Identified monitoring as automated and stated staff and shore-contact responsibilities. |
| F046-F048 | Homepage and Welcome | Removed continuity, guaranteed-currency, and safe-return implications. |
| F049-F050 | Basic and Premium delivery email | Reframed the attachment as precautionary information; added contact-first, direct-emergency-authority, non-verification, non-dispatch, and delivery/receipt limitations. |
| F051-F053 | Missed, escalated, and assistance email | Identified automated or captain-reported source; removed professional-escalation/verified-distress implications; added non-dispatch and delivery limitations. |
| F054-F055 | Guided tour | Replaced live/current-position and professional-monitor terminology. |
| F056-F057 | Reachable legacy demo | Removed timely-response and 24/7 implications and replaced tracking presentation with shared trip status. |

## Files changed

Application and presentation:

- `app/follow.cfm`
- `app/follow-full-map.cfm`
- `app/active-cruise.cfm`
- `app/monitoring.cfm`
- `app/dashboard.cfm`
- `partials/fpw-conversion-landing.cfm`
- `assets/admin/index.cfm`
- `assets/css/follow.css`
- `assets/js/app/follow/follow.js`
- `assets/js/app/follow/followFullMap.js`
- `assets/js/app/follow/followMap.js`
- `assets/js/app/home-visual-tour.js`

API/service copy:

- `api/v1/voyage.cfc`
- `api/v1/RouteMapGeometryService.cfc`
- `api/v1/ActiveCruiseViewModelService.cfc`
- `api/v1/MonitoringConsoleViewModelService.cfc`
- `api/v1/floatplan.cfc`
- `api/v1/OverdueAlertService.cfc`

Tests and documentation:

- `tests/safety-language-phase-1.test.mjs`
- `tests/safety-language-phase-1.spec.js`
- `docs/product/safety-language-phase-1.md`

The controlling audit report was a pre-existing untracked input and was not modified.

## Before-and-after phrase inventory

| Removed or corrected | Replacement intent |
|---|---|
| Follow along in real time | Follow the planned route, reported progress, trip updates, comments, and latest check-in |
| Live now | Latest check-in - Updated [existing timestamp] |
| Live route view with current position | Planned route, reported or estimated route progress, completed legs, and destination |
| Current Location | Reported Progress |
| Current position map fallback | Estimated route progress |
| Float Plan Monitor | Shore Contact |
| Monitor | Contact |
| Emergency monitor not named | Shore contact not named |
| See how FPW is monitoring | View the automated monitoring status |
| FPW keeps the plan alive | FPW keeps trip information available |
| Active Cruise keeps timing and status current | Captains can report updates and check-ins during the trip |
| keep them informed until you return safely | keep them updated through supported check-ins and notices |
| call the selected Rescue Authority when late | Contact the boater first, follow the agreed response plan, and contact an appropriate emergency authority directly if an emergency may exist |
| FPW Monitoring Alert: Missed Check-In | FPW Automated Notice: Scheduled Check-In Not Recorded |
| FPW Monitoring Alert: Escalated | FPW Automated Notice: Check-In Still Unresolved |
| FPW Assistance Needed Alert | FPW Notice: Captain Reported Assistance May Be Needed |
| 24/7 peace of mind | Automated trip status notices |
| Tracking | Shared |

## Approved terminology used

- Planned route
- Latest reported position
- Latest check-in
- Reported progress
- Estimated route progress
- Updated [timestamp]
- Shore contact
- Automated monitoring
- Automated check-in status
- Automated notice
- Captain-reported status
- Precautionary trip information

## Position-source and timestamp rules

Follow has two distinct existing sources:

1. `trackLog.entries` represents supported Active Cruise check-in events. When an entry has GPS coordinates, Follow labels the newest such entry as the latest reported position, displays its existing `sourceLabel`, and associates it with `occurredAtLocalLabel` or the existing UTC fallback.
2. `map.current` is produced by `RouteMapGeometryService.buildRouteMapData()`. It is based on a completed route-leg endpoint or the first planned route point when no completed endpoint exists. It is therefore labeled estimated route progress and is never called the current vessel position.

When Follow has no GPS-bearing check-in entry, it displays: “No position update has been reported yet.” The adjacent clarification states that route-progress markers are estimated and FPW is not continuous live vessel tracking.

The Active Cruise V2 map model explicitly returns `currentPosition.available = false` with no canonical current-position source. Active Cruise therefore displays the planned route and the no-position state; it does not invent a source or timestamp.

Monitoring continues to use its existing latest GPS check-in model, captured time, stale-state warning, and accuracy warning. Only its explanatory wording changed.

## Email safety language

Basic and Premium delivery emails retain the same recipient discovery, subject, HTML format, PDF attachment, send timing, activation/transaction flow, failure behavior, and complimentary/purchased credit parity. Both now say:

- The float plan is precautionary trip information.
- A late return is not proof that FPW verified an emergency.
- The recipient should first try to contact the boater and follow the agreed response plan.
- If an emergency may exist, the recipient should contact an appropriate emergency authority directly and provide the float-plan details.
- FPW does not independently verify emergencies or dispatch assistance.
- Email delivery and recipient receipt/read status are not guaranteed.

User-selected emergency-authority data remains visible as informational data from the float plan. It is not presented as an authority contacted or dispatched by FPW.

Missed and escalated notices identify the source as FPW automated check-in status. Assistance notices identify the source as captain-reported status. Internal alert type keys and monitoring status codes remain unchanged.

## Legacy demo reachability

`assets/admin/index.cfm` is routed through the application and returned HTTP 401 to an unauthenticated local request. `Application.cfc` applies the admin authentication path to `/assets/admin/`. This establishes that the file is executable/reachable behind admin authentication, rather than an inert repository artifact. The safety phrases in F056-F057 were therefore corrected. Prelaunch ownership and unrelated stale lifecycle content remain outside this phase.

## Tests run

- `node --test tests/safety-language-phase-1.test.mjs`: 8 tests passed; 0 failed.
- `node --check`:
  - `assets/js/app/follow/follow.js`
  - `assets/js/app/follow/followFullMap.js`
  - `assets/js/app/follow/followMap.js`
  - `assets/js/app/home-visual-tour.js`
  - Result: all passed.
- MCPCFC local requests:
  - `app/follow.cfm`: HTTP 200.
  - `app/follow-full-map.cfm`: HTTP 200.
  - `index.cfm`: HTTP 200.
  - Modified CFC component routes returned the expected CFC Explorer redirect after ColdFusion compilation.
- Existing TestBox runners:
  - Premium Send Credit runner: HTTP 503 `TESTBOX_NOT_INSTALLED`.
  - Welcome Onboarding runner: HTTP 503 `TESTBOX_NOT_INSTALLED`.
  - These are environment limitations, not passing results.
- MCPCFC Playwright:
  - The targeted spec was accepted by path but could not launch because the MCPCFC runtime reported `nodeFound=false` and `npxFound=false`.
  - No standalone/local Playwright fallback was used.
- `git diff --check`: passed with no output.

## Manual checks

- Homepage at 1440 x 900: corrected copy rendered without horizontal overflow.
- Homepage at 390 x 844: corrected copy remained readable without horizontal overflow.
- Follow full-map no-stream/error state at 1440 x 900 and 390 x 844: layout remained within the viewport.
- Follow no-slug route: existing loader/error behavior was observed; it is not evidence for a populated trip.
- Authenticated Dashboard, Active Cruise, and Monitoring views were not available in the in-app browser session. Their updated copy is covered by source contract tests and ColdFusion component compilation, but authenticated populated-state visual validation remains outstanding.

## MailHog validation

Five messages were rendered in local MailHog using synthetic `.test` recipients and generic data:

- Basic float-plan delivery: HTML rendered; synthetic PDF attachment present.
- Premium float-plan delivery: matching HTML rendered; synthetic PDF attachment present.
- Missed-check-in notice: plain text rendered.
- Unresolved/escalated-state notice: plain text rendered.
- Assistance-may-be-needed notice: plain text rendered.

The rendered copy showed the intended automated or captain-reported source, non-verification/non-dispatch language, and delivery limitation. Source contract tests separately verify that both production delivery blocks contain the same approved wording and retain both existing `cfmailparam` PDF attachment lines.

This was a presentation/contract render, not an end-to-end invocation of the production send functions. No real address or customer data was used. The five synthetic MailHog messages were deleted after inspection.

## Behavior-preservation review

The complete diff was reviewed for behavior changes:

- No database migration or schema change was added.
- No monitoring state, state transition, timer, escalation delay, evaluator, scheduler, recipient query, or trigger changed.
- No route geometry, leg progress, ETA, check-in persistence, or map calculation changed.
- No email recipient, send timing, `cfmail` type, PDF attachment, transaction, or failure path changed.
- No API key or response field was added, removed, or renamed.
- No payment, Stripe, pricing, membership, entitlement, access gate, credit grant, credit lock, credit consumption, or receipt logic changed.
- No 21-day wording or behavior was introduced.

## Remaining safety-language and validation risks

- A populated Follow trip with and without GPS-bearing check-ins still needs authenticated/canonical end-to-end visual validation.
- Authenticated Active Cruise, Monitoring, and Welcome views still need desktop/mobile visual validation.
- The MCPCFC Playwright runtime requires Node availability before the new targeted browser spec can run.
- Repo-local TestBox must be installed before the existing disposable regression suites can run.
- Production send functions were not invoked; MailHog validation covered synthetic rendering plus production-source contracts, not end-to-end triggers, recipient selection, PDF generation, or delivery.
- Email and network delivery remain best-effort and cannot be proven by MailHog acceptance.
- Product-contract, legal-text, legacy lifecycle, and proposed duration work identified outside F039-F057 remains deferred.

## Explicitly deferred work

- Basic Save & Send product-contract decisions
- Free versus paid product access
- Pricing and entitlement terminology outside direct safety overstatements
- Monthly/Annual behavior
- Three-Day Pass behavior
- Credit consumption
- Monitoring duration/end-state changes
- Any proposed 21-day duration limit, disclosure, grace rule, or enforcement
- Terms of Service and Privacy Policy changes
- SMS or delivery-receipt implementation

## Rollback

All tracked changes are recoverable from branch point `4d5d6687f437ffcaf5e3f7e28c304c939fae5c73`.

To roll back this uncommitted phase only:

1. Restore the tracked files listed in “Files changed” to the branch point with `git restore -- <exact tracked paths>`.
2. Remove only the three new Phase 1 files:
   - `tests/safety-language-phase-1.test.mjs`
   - `tests/safety-language-phase-1.spec.js`
   - `docs/product/safety-language-phase-1.md`
3. Do not remove `docs/product/customer-facing-language-audit.md`; it predates this implementation and is the controlling audit input.
4. Verify the rollback with `git status --short` and `git diff --check`.
