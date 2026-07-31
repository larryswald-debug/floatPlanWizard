# FPW Customer-Facing Product Language Audit

Audit date: 2026-07-29

Audit branch: `analysis/customer-facing-product-language-audit`

Baseline: `main` at `4d5d6687f437ffcaf5e3f7e28c304c939fae5c73`

Pending branch reviewed separately: `codex/membership-premium-send-credits-phase-2` at `344d52e9`

## Executive Summary

- **Customer-facing surfaces inspected:** 40 requested surface classes, plus two cross-cutting artifact classes (tracked legacy mirrors and the pending feature branch), for 42 audit units.
- **Contradictory or potentially misleading phrases:** 70.
- **By severity:** 11 Critical, 38 High, 20 Medium, 1 Low.
- **By issue category:** 10 Planning paywall; 2 Free-trip ambiguity; 4 Unlimited-duration implication; 10 Safety overstatement; 5 Professional-monitoring implication; 5 Terminology conflict; 0 Complimentary-credit mismatch; 12 Retired product; 2 Pricing inconsistency; 10 Missing disclosure; 10 Other.
- **Highest-risk customer misunderstanding:** active code and copy say registered members may send a Basic operational float plan and receive Basic monitoring for free. The controlling contract says FPW charges for sending and monitoring an operational float plan. This is a behavior-and-copy conflict, not a copy-only defect.
- **Highest-risk legal or safety implication:** the Follow and Active Cruise experiences use “real time,” “Live now,” and “current position,” while the implemented product displays plan state, route projection, and the latest shared check-in rather than independent continuous tracking. Delivery and alert emails also lack adjacent limits on delivery, detection, response, and rescue.
- **Most frequently used outdated term:** **Trial** has the widest source footprint in the audited evidence set (15 files). This is a file-presence comparison, not a count of rendered UI occurrences. **3-Day Pass** is the clearest retired product name still supported by code and present in dormant and legal copy.
- **Recommended first surface to correct:** resolve the Basic operational-plan product-contract decision first; then correct Follow’s “real time,” “Live now,” and “current position” wording as Priority 0.
- **21-day limit:** proposed only. It is not enforced or described as live. Premium return dates may exceed 21 days, consumed credits do not expire by trip duration, and monitoring has no duration-expired state.
- **Free planning / paid sending and monitoring consistency:** no. Current active planning access is free, but active copy and behavior also provide free Basic sending and monitoring. Dormant branches, tracked mirrors, legal text, and one pending route-creation UI gate separately imply restrictions on planning.

## Current Product Contract

### Verified current behavior

- Authentication, not Premium, is the backend gate for planning tools. `api/v1/MemberAccessGateService.cfc:52-56` requires a signed-in member; `api/v1/MemberEntitlementService.cfc:64-75,134-170` reports planning access and unlimited planning waypoints/trip days, saved routes, and multi-day planning.
- The current implementation has two operational send paths:
  - Basic Send permits a route-less, same-day/24-hour plan with at most two waypoints, sends a precautionary email, activates the plan, and starts Basic monitoring (`api/v1/MemberAccessGateService.cfc:166-255`; `api/v1/floatplan.cfc:7997-8155`).
  - Premium Save & Send requires an available Premium Send Credit or general Premium, produces Premium delivery, activates the plan, consumes the credit for that exact plan, and starts scheduled monitoring (`api/v1/MemberAccessGateService.cfc:59-133`; `api/v1/floatplan.cfc:8296-8469`).
- Complimentary-signup, purchased one-trip, promotion, and admin-grant credits use the same AVAILABLE/CONSUMED mechanics. Their source is retained for reporting rather than capability differences (`api/v1/PremiumSendCreditService.cfc:13-191`).
- A consumed credit has no duration-expiration column and remains the exact active plan’s operational-access source (`database/migrations/20260721_001_membership_premium_send_credits.up.sql:46-90`; `api/v1/PremiumSendCreditService.cfc:446-535`).
- The legacy 3-Day Pass remains accepted in checkout and entitlement code and grants an exact 72-hour UTC entitlement (`api/v1/StripeCheckoutService.cfc:46-64`; `api/v1/MemberEntitlementService.cfc:175-208,237-245`).
- Monitoring uses ACTIVE, LATE, MISSED, ESCALATED, RESOLVED, and CLOSED states, with a 60-minute missed-check-in grace and 120-minute escalation delay. There is no EXPIRED state or trip-duration cutoff (`api/v1/monitor.cfc:90-95,560-626,765-830`).

### Approved business direction

- Registered members receive all listed planning capabilities without consuming a trip credit.
- A complimentary or purchased trip credit is consumed only by a successful Premium Save & Send and provides the same applicable send-and-monitor capability.
- Monthly and Annual memberships provide ongoing applicable sending and monitoring under implemented entitlement rules.
- FPW organizes and shares trip information and automates defined reminders/notices; it is not emergency dispatch, professional monitoring, rescue coordination, or a guarantee of message delivery, overdue detection, intervention, or response.

### Proposed future behavior

- A maximum of 21 consecutive monitored days for one trip credit is proposed. No report statement treats it as implemented.

### Uncertain behavior requiring Larry’s decision

- Whether Basic operational sending/monitoring remains a supported exception or must be removed to conform to the controlling contract.
- Canonical customer name for the one-trip product and whether “Premium trip,” “Trip credit,” or “Premium Send Credit” should lead.
- Whether the proposed 21-day maximum applies only to one-trip credits or also to Monthly/Annual member trips, and what happens at the limit.
- Whether any duration grace period exists after the monitored window; the current 60/120-minute check-in timers are not such a grace period.
- Whether “Float Plan Monitor” may denote a shore contact or must be replaced to avoid implying staffed professional monitoring.

## Surface Inventory

| Surface | Primary Files | Customer Purpose | Current Product Terms Used | Audit Status |
|---|---|---|---|---|
| 1. Homepage | `partials/fpw-conversion-landing.cfm`, `index.cfm` | Explain product and conversion offer | Free Membership, Basic sending, Premium trip, monitoring | High risk |
| 2. Pricing page | `app/pricing.cfm`, `assets/js/app/pricing.js` | Compare free, one-trip, Monthly, Annual | Premium Send Credit, Buy One Trip, general Premium, 3-Day Pass | High risk |
| 3. Join and registration pages | `app/join.cfm`, registration endpoints | Create a member account | Free membership, first Premium trip, trial in dormant branch | High risk |
| 4. Welcome overlay | `app/dashboard.cfm:343-392` | Orient a new member | plan, share, return safely | Misleading |
| 5. Dashboard | `app/dashboard.cfm`, `assets/js/app/dashboard.js` | Manage routes, Drafts, and active plans | Basic Save & Send, Premium | High risk |
| 6. Getting Started guidance | `app/dashboard.cfm`, `assets/js/app/dashboard/onboarding.js`, `api/v1/OnboardingService.cfc` | Complete setup | route, passenger, contact | Needs product decision |
| 7. Route Generator and Route Builder guidance | `assets/js/app/dashboard/routebuilder.js`, `app/dashboard.cfm` | Create and save routes | generated route, My Route | Clear on `main`; pending restriction |
| 8. Float Plan Wizard | `app/floatplan-wizard.cfm`, `assets/js/app/floatplanWizard.js` | Prepare a Draft | Basic Save & Send, Premium Save & Send | High risk |
| 9. Save & Send step | `app/floatplan-wizard.cfm`, `assets/js/app/floatplanWizard.js`, `api/v1/floatplan.cfc` | Commit and send a plan | Premium Send Credit, active membership, Basic send | High risk |
| 10. Trip-credit selection or confirmation | `assets/js/app/floatplanWizard.js`, `assets/js/app/account.js` | Choose and confirm paid access | Buy One Trip, Premium Send Credit | Minor inconsistency |
| 11. Account page | `app/account.cfm`, `assets/js/app/account.js` | View access and credit state | Free Member, Premium Send Credits, Premium access | Misleading |
| 12. Membership and upgrade screens | `app/account.cfm`, `app/pricing.cfm`, `app/start-trial.cfm` | Upgrade or manage access | Monthly, Annual, Premium access, trial | High risk |
| 13. Stripe Checkout preparation and success | `api/v1/StripeCheckoutService.cfc`, `assets/js/app/account.js`, `assets/js/app/floatplanWizard.js` | Open and confirm checkout | one-trip, 3-Day Pass, Premium access | High risk |
| 14. Billing Portal links and surrounding copy | `app/account.cfm`, `assets/js/app/account.js` | Manage recurring billing | Manage Billing, Premium access | Minor inconsistency |
| 15. FAQ | `faq/index.cfm` | Answer product questions | trial, free-access, membership | Misleading |
| 16. Terms of Service | `terms_of_service.cfm` | State legal terms | Free Tier, 3-Day Pass, trials, subscriptions | High risk |
| 17. Privacy or safety disclaimers | `privacy_policy.cfm`, `includes/footer.cfm`, Terms, Help, FAQ | Define data and safety limits | not live tracking, not emergency service | Clear |
| 18. Active Cruise | `app/active-cruise.cfm`, `api/v1/ActiveCruiseViewModelService.cfc` | Operate an active trip | live route, current position, Monitor | High risk |
| 19. Follow page | `app/follow.cfm`, `assets/js/app/follow/follow.js`, `api/v1/voyage.cfc` | Share trip state with shore | real time, Live now, current position | High risk |
| 20. Monitoring explanations | `app/monitoring.cfm`, `api/v1/MonitoringConsoleViewModelService.cfc` | Explain automated monitoring | monitoring, not live tracking | Misleading |
| 21. Overdue-status explanations | `app/monitoring.cfm`, `api/v1/monitor.cfc`, `api/v1/OverdueAlertService.cfc` | Explain missed/escalated state | Late, Missed, Escalated | Minor inconsistency |
| 22. Demo pages | `assets/admin/index.cfm`, `assets/js/app/home-visual-tour.js` | Demonstrate product | 24/7 peace of mind, live route, Monitor | High risk |
| 23. Help text | `app/help.cfm` and tracked mirrors | Explain use and access | Free planning, Basic trips, Premium route tools | High risk |
| 24. Tooltips | `app/dashboard.cfm`, `app/active-cruise.cfm`, application JS | Explain controls | Premium, monitoring, status | Minor inconsistency |
| 25. Guided-tour copy | `assets/js/app/home-visual-tour.js`, `assets/js/app/dashboard/help-tour.js` | Walk through workflows | Save & Send, monitoring, live route | High risk |
| 26. Modal dialogs | `app/dashboard.cfm`, `app/floatplan-wizard.cfm` | Confirm operational actions | Basic Save & Send, Premium | High risk |
| 27. Banner notices | `includes/top_nav.cfm`, calculator promo strips | Promote current offer | Free Membership, first Premium trip | High risk |
| 28. Error messages | API CFCs and `assets/js/app/*.js` | Explain denied/failed actions | Premium Trip credit, Premium access, 3-Day Pass | Misleading |
| 29. Empty states | Dashboard, Active Cruise, Monitoring templates | Explain unavailable/no-data state | no route, no monitor, no current position | Misleading |
| 30. Existing transactional emails | `api/v1/email.cfc`, `api/v1/floatplan.cfc`, `api/v1/OverdueAlertService.cfc`, `index.cfm` | Welcome, reset, delivery, monitoring, launch list | launch/beta, monitoring alert | High risk |
| 31. Welcome emails | `api/v1/email.cfc` | Welcome registered members | launch/beta | Minor inconsistency |
| 32. Upgrade emails | repository search | Upgrade paid access | none | Not found |
| 33. Float-plan delivery emails | `api/v1/floatplan.cfc` | Deliver plan/PDF to contact | precautionary delivery, Rescue Authority | High risk |
| 34. Monitoring and overdue emails | `api/v1/OverdueAlertService.cfc` | Send missed/escalated/assistance notices | monitoring alert, escalated | High risk |
| 35. Completion emails | current source search; retired `_orig` template | Notify return/close | retired back-in-port message | Not found |
| 36. Credit-consumption notices | `assets/js/app/floatplanWizard.js`, `api/v1/PremiumSendCreditService.cfc` | Explain credit availability/use | Send Credit, committed send | Minor inconsistency |
| 37. Renewal, expiration and cancellation emails | current source search | Billing lifecycle email | none | Not found |
| 38. Admin-configured or database-driven public copy | `fpw_promo_codes.public_description`; admin templates | Public promotion description | no current rows | Clear |
| 39. Structured data or metadata plan descriptions | `index.cfm`, public-page metadata, FAQ data | Search/social description | overdue monitoring, free plan | Minor inconsistency |
| 40. Page titles and meta descriptions | public CFML templates | Browser/search description | monitoring, planning, trip | Minor inconsistency |
| Cross-cutting: tracked legacy mirrors | `assets/app/*`, `api/app/*`, `app/*_orig.cfm`, `assets/admin/index.cfm` | Duplicate/legacy deployable-looking sources | trial, 3-Day Pass, Premium route tools | High risk |
| Cross-cutting: pending feature branch | six feature-only commits relative to the merge base; Dashboard onboarding/Route Builder files | Proposed route readiness and bathymetry work | Getting Started, Create Route | Needs product decision |

Separate mobile wording was searched where a distinct source exists. Most responsive views share the same CFML/JavaScript strings; no independent native-mobile copy bundle was found.

## Complete Findings

| ID | Severity | Category | Surface | File | Line | Exact Phrase | What It Implies | Why It Conflicts | Current Verified Behavior | Recommended Direction |
|---|---|---|---|---|---:|---|---|---|---|---|
| F001 | Critical | Other | Banner notice | `includes/top_nav.cfm` | 230 | “Full planning and Basic sending included” | Operational sending is a free-member benefit. | The controlling contract says sending and monitoring are the paid event. | Authenticated members can currently send Basic plans and start Basic monitoring. | Decide the Basic exception before changing copy or behavior. |
| F002 | Critical | Other | Homepage | `partials/fpw-conversion-landing.cfm` | 224 | “Full planning and Basic sending” | Free membership includes operational sending. | It contradicts the controlling paid-send contract. | Basic Send is implemented and free for authenticated members. | Resolve the contract/behavior conflict; then make all conversion copy consistent. |
| F003 | Critical | Other | Pricing | `app/pricing.cfm` | 130 | “send Basic float plans at no cost” | A send-and-monitor transaction costs nothing. | It directly contradicts the controlling contract. | Basic send, activation, email, and monitoring are implemented. | Product decision first; do not solve as copy-only. |
| F004 | Critical | Other | Join | `app/join.cfm` | 122 | “send Basic float plans at no cost” | Signup grants free operational sending. | It conflicts with the approved direction. | Current Basic access is authenticated-free. | Align behavior and the controlling contract, then revise signup claims. |
| F005 | Critical | Other | Help | `app/help.cfm` | 74 | “Basic float-plan sending” | Free membership includes sending. | Paid sending/monitoring is not communicated consistently. | Basic sending and monitoring are active paths. | Make Help reflect the chosen Basic policy. |
| F006 | Critical | Other | Dashboard modal | `app/dashboard.cfm` | 1168 | “Basic Save & Send remains free” | The operational action is explicitly free. | This is the exact action the controlling contract says is paid. | Backend permits the action without a credit. | Treat as product-contract blocker, not a wording-only defect. |
| F007 | Critical | Other | Float Plan Wizard modal | `app/floatplan-wizard.cfm` | 410 | “Basic Save & Send remains free” | The paid event has a free parallel path. | It defeats a universal “paid sending and monitoring” claim. | Basic flow activates and monitors a route-less one-day plan. | Decide whether Basic is a documented exception or is removed. |
| F008 | High | Other | Account | `assets/js/app/account.js` | 350 | “Planning and Basic sending are included.” | Account status confirms free sending as entitlement. | The controlling contract limits free access to planning. | `canSendBasicFloatPlan` is true for authenticated members. | Couple any copy correction to the product decision. |
| F009 | High | Other | Send confirmation | `api/v1/floatplan.cfc` | 8152 | “Basic float plan sent to … contact” | A free Basic send is a successful operational product. | Conflicts with universal paid sending. | This response follows successful email, activation, and monitoring start. | Preserve only if Basic remains an explicit contract exception. |
| F010 | High | Planning paywall | Pricing feature strip | `app/pricing.cfm` | 197 | “Route-based float plans” | Route-based planning is a Premium inclusion. | Route planning and route-based Draft preparation are approved free planning. | Backend planning access is authentication-only. | Remove planning capabilities from Premium-only groupings. |
| F011 | High | Planning paywall | Pricing feature strip | `app/pricing.cfm` | 202 | “NOAA Nautical Charts” | NOAA charts are part of the paid trip. | NOAA charts and marine planning layers are approved free planning. | No Premium planning gate was found. | Present charts under free planning, not paid activation. |
| F012 | High | Planning paywall | Pricing feature strip | `app/pricing.cfm` | 203 | “Premium route generator” | Route generation requires Premium. | Route Generator is an approved free-member planning tool. | Planning access is authentication-only. | Retire the Premium planning label. |
| F013 | High | Planning paywall | Homepage dormant branch | `partials/fpw-conversion-landing.cfm` | 231 | “Add route planning … when you need more” | Route planning is an upgrade. | It conflicts with approved free planning and current backend access. | The live flag selected the newer branch during runtime inspection; this source remains executable if the flag changes. | Delete or synchronize the dormant branch after product-copy approval. |
| F014 | High | Planning paywall | Pricing dormant comparison | `app/pricing.cfm` | 402 | “Custom Route Generator” with Free “×” | Free members cannot generate routes. | Route generation is approved free and currently not Premium-gated. | This is in the inactive flag branch. | Remove the restriction from every flag branch. |
| F015 | High | Planning paywall | Help dormant branch | `app/help.cfm` | 78 | “Premium adds saved routes” | Saved routes require Premium. | Saved routes are approved free planning. | Current access exposes saved routes to authenticated users. | Synchronize or remove dormant help copy. |
| F016 | High | Planning paywall | Help dormant branch | `app/help.cfm` | 122 | “Premium route tools” | Route creation/reuse is paid. | Those are free planning functions. | The current flag branch says planning is free. | Use one access model in all branches. |
| F017 | High | Planning paywall | Terms | `terms_of_service.cfm` | 596-599 | “restrictions on saved routes … waypoints” | FPW may present core planning as restricted free-tier functionality. | It contradicts the controlling contract’s unconditional registered-member planning list. | Current code reports unlimited free planning limits. | Obtain legal/product approval to align the Free Tier description. |
| F018 | High | Planning paywall | Tracked Help mirrors | `assets/app/help.cfm` | 74 | “Premium adds saved routes” | A mirror describes free planning as Premium. | It can diverge from the canonical executed template and the approved model. | Live reachability of this mirror was not proven; browser navigation was blocked. | Establish deployment ownership, then remove/synchronize reachable copies. |
| F019 | High | Planning paywall | Pending feature branch | `assets/js/app/dashboard/onboarding.js` | 410-413 (branch) | “Before creating a route, complete Getting Started” | Route Builder is blocked until a multi-record checklist is complete. | The approved direction makes planning available to registered members; the checklist also requires a passenger while current welcome copy says passengers are optional. | The pending branch calls this validation from `assets/js/app/dashboard/routebuilder.js:7695-7739` and fails closed; `api/v1/OnboardingService.cfc:85-174` requires vessel, shore contact, passenger, operator, and two waypoints. | Do not merge the gate until Larry decides whether onboarding may block planning and whether passenger is required. |
| F020 | High | Retired product | Pricing dormant branch | `app/pricing.cfm` | 336-352 | “3-Day Pass” | A retired 72-hour access product is for sale. | The controlling model is complimentary/purchased trip credit plus memberships. | Checkout still accepts the selector, but the active credit-model branch does not display it. | Retire or explicitly retain across code, legal, and checkout as one decision. |
| F021 | High | Retired product | Terms | `terms_of_service.cfm` | 630-636 | “3-Day Pass” | The retired pass remains a legally offered product. | It conflicts with the current trip-credit framing. | Backend still supports exact 72-hour entitlement. | Decide product status before legal revision or code retirement. |
| F022 | Medium | Retired product | Start-trial dormant source | `app/start-trial.cfm` | 648-653 | “Free Premium trial” | New users start a time-based Premium trial. | The active offer is a complimentary send credit, not a lesser temporary trial. | The live credit-model flag redirects before this body renders. | Remove or isolate dormant trial UI when safe. |
| F023 | Medium | Retired product | Join dormant branch | `app/join.cfm` | 82-83 | “Premium route tools included for your first month” | Planning is temporarily Premium and trial-limited. | Planning is approved free; complimentary credit is for a real paid-capability trip. | Inactive under the inspected flag. | Synchronize inactive signup copy. |
| F024 | Medium | Retired product | Homepage dormant pricing | `partials/fpw-conversion-landing.cfm` | 236 | “3-Day Pass” | The retired pass remains a current choice. | It competes with Buy One Trip / credit language. | Dormant under the inspected flag; backend remains capable. | Resolve pass status and delete stale choices. |
| F025 | Medium | Retired product | Tracked start-trial mirror | `assets/app/start-trial.cfm` | 42 | “Memorial Day Premium trial” | A date-bound launch promotion is still current. | It is stale and inconsistent with the credit model. | Reachability was not proven; source is tracked. | Establish whether deployed; then remove or archive. |
| F026 | Medium | Retired product | API error | `assets/js/app/api.js` | 199-200 | “one-trip, or 3-Day Pass Premium billing” | Both one-trip credit and retired pass are supported customer choices. | Mixed models create checkout ambiguity. | Backend selector still accepts both. | Remove only after the 3-Day Pass retirement decision. |
| F027 | Medium | Retired product | Welcome email | `api/v1/email.cfc` | 173, 189 | “During this launch/beta period” | The service is still in launch/beta. | It is stale lifecycle wording unrelated to the current model. | This is the current welcome-email template. | Replace after product/legal review; no email was sent in this audit. |
| F028 | High | Retired product | Launch-list email | `index.cfm` | 134 | “upcoming launch of FloatPlanWizard” | FPW has not launched. | It materially misstates current availability. | A POST handler can still send this email; the audit did not submit it. | Disable/retire the handler or update it after explicit implementation approval. |
| F029 | High | Retired product | Launch-list email | `index.cfm` | 138 | “scheduled to launch in Spring 2026” | A past launch date is promised. | On 2026-07-29 the date is stale. | The handler remains in active root source. | Treat as a stale transactional path, not merely hidden page copy. |
| F030 | Medium | Retired product | Legacy demo | `assets/admin/index.cfm` | 1777 | “Launching this spring” | A legacy page presents FPW as prelaunch. | It conflicts with current product availability. | Tracked source; public reachability unverified. | Determine ownership/reachability, then remove or archive. |
| F031 | Medium | Retired product | Terms | `terms_of_service.cfm` | 639-654 | “Launch Trial or Promotional Trial” | Trials remain a current contract family. | Customer pages are moving to credits, while trial code and legal terms remain. | Trial and promo entitlement code still exists. | Product/legal decision: supported legacy entitlement versus customer offer. |
| F032 | Medium | Terminology conflict | Account promo | `app/account.cfm` | 193 | “Existing trial and promotional access remains supported.” | Trial access is a current customer concept. | It mixes historical time-based entitlements with credits and subscriptions. | Legacy trial/promotional access is still supported by backend logic. | Label as legacy access if it remains support-only. |
| F033 | Medium | Terminology conflict | Pricing | `app/pricing.cfm` | 169, 182, 192 | “General Premium access” | A customer should know what “general” means and how it differs from a credit. | The phrase is undefined and can suggest a feature tier rather than entitlement scope. | Code uses general Premium for non-exact-plan operational access. | Define or replace with Monthly/Annual membership language. |
| F034 | Medium | Terminology conflict | Account checkout | `assets/js/app/account.js` | 578-593 | “Premium access confirmed.” | One undifferentiated status covers subscription and other entitlements. | It obscures whether checkout confirmed Monthly, Annual, pass, trial, or another source. | Access sources are distinguishable in the response. | Name the confirmed product/entitlement. |
| F035 | High | Unlimited-duration implication | Homepage Buy One Trip | `partials/fpw-conversion-landing.cfm` | 225 | “One complete Premium trip.” | One credit covers the trip however long it lasts. | A 21-day limit is proposed but not implemented or disclosed. | Current Premium validation checks only that return is in the future. | Add duration only after rules and enforcement are approved. |
| F036 | High | Unlimited-duration implication | Pricing | `app/pricing.cfm` | 192 | “one complete Premium trip” | Credit duration is bounded by completion, not time. | It can permit a never-ending active trip in customer expectation. | No single-trip maximum exists. | Do not state 21 days until enforcement exists; flag duration as currently unspecified. |
| F037 | High | Unlimited-duration implication | Join | `app/join.cfm` | 79 | “first complete Premium trip” | The complimentary credit lasts through any complete trip. | No duration qualification exists. | Complimentary and purchased credits have the same no-expiry mechanics. | Preserve parity; add the same approved duration disclosure to both. |
| F038 | High | Unlimited-duration implication | Help | `app/help.cfm` | 78 | “one complete Premium trip” | Monitoring continues for the whole trip without a maximum. | The future 21-day proposal is absent and current monitoring has no duration cutoff. | Monitoring ends through explicit workflow, not a trip-duration timer. | Disclose only the verified rule; later update all one-trip surfaces together. |
| F039 | Critical | Safety overstatement | Follow page | `app/follow.cfm` | 106 | “Follow along in real time” | FPW continuously tracks the vessel. | The Follow page is not independent real-time tracking. | It presents plan data, projections, and shared check-ins. | Remove real-time implication and identify data freshness/source. |
| F040 | Critical | Safety overstatement | Follow map | `app/follow.cfm` | 165 | “Live route view with current position” | The map is a live, current vessel location. | Last check-in or projected state can be stale. | No continuous tracking guarantee exists. | Describe planned route/latest shared check-in and show timestamp. |
| F041 | Critical | Safety overstatement | Follow status chip | `assets/js/app/follow/follow.js` | 878 | “Live now” | The displayed position/status is currently live. | “Updated” time does not turn a discrete check-in into continuous tracking. | Data refresh reflects reported application state. | Replace with timestamped “latest update/check-in” intent. |
| F042 | High | Safety overstatement | Active Cruise map | `app/active-cruise.cfm` | 3609 | “Live route view with current position” | Captain view continuously knows vessel position. | Current position may be route projection or latest reported point. | The product is not a vessel-tracking service. | Use source-specific, timestamped route/check-in language. |
| F043 | High | Professional-monitoring implication | Active Cruise | `app/active-cruise.cfm` | 4063 | “Float Plan Monitor” | A dedicated professional monitors the plan. | The displayed person is a selected shore contact. | View-model selects the first relevant contact. | Use shore-contact terminology unless a staffed service is implemented. |
| F044 | High | Professional-monitoring implication | Active Cruise empty state | `app/active-cruise.cfm` | 4068 | “Emergency monitor not named” | FPW expects a professional emergency monitor. | No such service is implemented. | This is a fallback label for a contact name. | Replace concept after product/safety approval. |
| F045 | High | Professional-monitoring implication | Monitoring page | `app/monitoring.cfm` | 738-739 | “See how FPW is monitoring” | FPW personnel are watching the trip. | Monitoring is automated state evaluation; FPW assumes no shore-contact responsibility. | The same page correctly says “Not live vessel tracking.” | Explicitly identify automated monitoring and responsible contact. |
| F046 | High | Safety overstatement | Homepage | `partials/fpw-conversion-landing.cfm` | 163 | “FPW keeps the plan alive.” | FPW continuously maintains/observes the operational plan. | It can overstate continuity and reliability. | Updates depend on application events and communications. | Qualify as shared/updateable trip information. |
| F047 | High | Safety overstatement | Homepage | `partials/fpw-conversion-landing.cfm` | 182 | “keeps timing and status current” | Timing/status accuracy is guaranteed. | Updates can be delayed, absent, or stale. | State is updated by user/check-in/system events. | Describe updates without guaranteeing currency. |
| F048 | High | Safety overstatement | Welcome overlay | `app/dashboard.cfm` | 359 | “keep them informed until you return safely” | Delivery and ongoing information continue until a safe return. | FPW cannot guarantee delivery, a safe return, or indefinite monitoring. | Messaging and monitoring depend on explicit workflows and infrastructure. | Remove outcome/continuity guarantee; retain organize/share purpose. |
| F049 | Critical | Safety overstatement | Float-plan delivery email | `api/v1/floatplan.cfc` | 8076-8083, 8392-8399 | “If the member does not return on time, call the selected Rescue Authority” | The contact should escalate directly based on FPW’s return time and the selected label. | It omits checking the captain, using judgment, and FPW’s non-emergency/delivery limits; it can imply rescue coordination. | Email is precautionary delivery only; FPW does not independently confirm distress. | Safety/legal review the instruction before any wording change. |
| F050 | High | Missing disclosure | Float-plan delivery email | `api/v1/floatplan.cfc` | 8083, 8399 | “Float Plan Precautionary Delivery” | Delivery of the message/PDF completes the paid safety function. | No adjacent notice says email delivery is not guaranteed or that receipt/response is not confirmed. | `cfmail` submission is not end-recipient delivery proof. | Add an approved delivery/receipt limitation and alternative-sharing guidance. |
| F051 | High | Missing disclosure | Monitoring email | `api/v1/OverdueAlertService.cfc` | 270-304 | “FPW Monitoring Alert: Missed Check-In” | FPW detected an overdue event conclusively. | The body does not explain automated evaluation, possible stale/missing data, or emergency limitations. | Trigger follows the monitoring state machine and may fail silently at the caller. | Add approved automation, verification, and emergency-channel context. |
| F052 | High | Missing disclosure | Monitoring email | `api/v1/OverdueAlertService.cfc` | 354-388 | “FPW Monitoring Alert: Escalated” | FPW has professionally escalated an emergency. | Recipient may infer staffed response or rescue coordination. | Code sends an automated contact email; no dispatcher is involved. | State what was automated and what the shore contact must verify/do. |
| F053 | High | Missing disclosure | Assistance email | `api/v1/OverdueAlertService.cfc` | 454-459 | “FPW Assistance Needed Alert” | FPW has confirmed need or is coordinating assistance. | It lacks a non-confirmation and non-response qualification. | It relays a reported status/note. | Distinguish member-reported status from verified distress. |
| F054 | High | Safety overstatement | Guided visual tour | `assets/js/app/home-visual-tour.js` | 86 | “Map shows route, current position, and destination.” | Demo promises current location. | It repeats the live-tracking implication. | Actual product may show last shared/check-in position. | Synchronize with approved Follow/Active Cruise safety language. |
| F055 | High | Professional-monitoring implication | Guided visual tour | `assets/js/app/home-visual-tour.js` | 88 | “Float Plan Monitor” | Demo depicts a staffed monitor role. | Actual record is a shore contact. | No professional monitoring service is implemented. | Rename role consistently across demo and product. |
| F056 | Medium | Safety overstatement | Legacy demo | `assets/admin/index.cfm` | 1783 | “Automatic overdue alerts help contacts act quickly” | Alerts will arrive and support timely intervention. | Delivery, detection, and action are not guaranteed. | Automated email attempts exist; caller catches failures. | If reachable, add limitations and shore-contact responsibility. |
| F057 | High | Professional-monitoring implication | Legacy demo | `assets/admin/index.cfm` | 1830 | “24/7 peace of mind” | FPW provides always-on reliable monitoring. | No staffed 24/7 monitoring or availability guarantee exists. | Monitoring is automated and infrastructure-dependent. | Remove if reachable; do not reuse in current marketing. |
| F058 | High | Missing disclosure | Pricing Buy One Trip | `app/pricing.cfm` | 147-158 | “Buy One Trip” | Product scope is complete without duration terms. | A material proposed limit exists, but current behavior and copy are silent. | No maximum is enforced. | Keep current limitation explicit as “duration not yet defined” internally; publish only after decision/enforcement. |
| F059 | High | Missing disclosure | Save & Send availability | `assets/js/app/floatplanWizard.js` | 891-901 | “requires one credit or an active membership” | Credit/membership is the only material limit. | Duration and end-of-monitoring behavior are absent. | Premium send checks only future return and entitlement. | Add a consistent disclosure once duration behavior is approved. |
| F060 | High | Missing disclosure | Terms | `terms_of_service.cfm` | 584-724 | “Subscriptions, Trials, Payments…” | Legal terms cover the current access catalog. | They describe passes/trials but not the current Premium Send Credit consumption model or complimentary/purchased parity. | Credit consumption and parity are implemented. | Legal review a current credit section; do not silently repurpose pass terms. |
| F061 | Medium | Missing disclosure | Monthly/Annual pricing | `app/pricing.cfm` | 160-186 | “General Premium access” | Membership trip duration and monitoring limits are understood. | The code/report evidence does not establish whether member trips are unlimited or subject to future 21-day limits. | General Premium has no trip-duration maximum. | Larry must decide membership duration policy before customer disclosure. |
| F062 | Medium | Missing disclosure | Complimentary-trip promotion | `app/join.cfm` | 125 | “first complete Premium trip is included” | Complimentary credit is complete but has no defined monitored duration. | The future proposal would be material and must apply equally to purchased credit. | Credits are capability-equal and currently duration-unlimited. | Preserve parity in any future duration disclosure. |
| F063 | Medium | Missing disclosure | Monitoring explanation | `app/monitoring.cfm` | 734-739 | “Not live vessel tracking” / “FPW is monitoring” | Tracking limits are disclosed, but monitoring’s end condition is understood. | No duration-expiry/end-of-service explanation appears near the automated monitoring description. | Monitoring can remain active/escalted until explicit close/resolution; no EXPIRED state. | Explain end conditions after product behavior is decided. |
| F064 | Medium | Terminology conflict | Error message | `api/v1/MemberAccessGateService.cfc` | 127 | “Premium Trip credit” | “Trip credit” and “Premium Send Credit” are interchangeable official names. | Customer-facing names vary across gate, checkout, pricing, and account. | Backend object is `PremiumSendCredit`; checkout label is Buy One Trip. | Choose one customer term and map internal terminology separately. |
| F065 | Low | Terminology conflict | Contact page | `app/contact.cfm` | 108, 139 | “Premium access” | Support category covers a single well-defined product. | The phrase can mean subscription, legacy trial/pass, founder access, or exact-trip credit. | Backend distinguishes those sources. | Use broader “membership or trip-credit access” after canonical naming. |
| F066 | Medium | Pricing inconsistency | Pricing | `app/pricing.cfm` | 250 | “Complimentary and purchased Premium Send Credits grant the same capabilities.” | This is the parity contract. | Correct in isolation, but adjacent Basic free send and planning-as-Premium items make the product table internally inconsistent. | Credit parity is verified. | Preserve this sentence while correcting surrounding access model. |
| F067 | Medium | Free-trip ambiguity | Homepage | `partials/fpw-conversion-landing.cfm` | 221-224 | “First Premium trip for new members” | The included trip may be what unlocks the listed Route Builder and saved planning tools. | Planning is independently free; the card mixes planning and complimentary paid capability. | Planning access does not consume the credit. | Separate free planning from the included send-and-monitor transaction. |
| F068 | Medium | Free-trip ambiguity | Join | `app/join.cfm` | 79-80 | “Planning is free. Use one included trip…” | Mostly correct, but “trip” is not explicitly identified as a send credit consumed at successful Premium Save & Send. | A user may not know when the benefit is used. | Credit consumption occurs on successful committed Premium send. | Clarify consumption event after canonical naming is chosen. |
| F069 | Medium | Pricing inconsistency | Stripe selector | `api/v1/StripeCheckoutService.cfc` | 46-64 | “monthly, yearly, three_day_pass, one_trip” | Two different one-off products are simultaneously valid. | Customer offers and legal terms cannot be made coherent without a product decision. | Both selectors remain accepted. | Decide whether 3-Day Pass remains supported purchase or legacy entitlement only. |
| F070 | High | Other | Pending feature branch | `assets/js/app/dashboard/onboarding.js` | 128-130 (branch) | “a passenger” | A passenger is mandatory before route creation. | Current welcome language treats passengers as trip information and the controlling contract lists passenger management as free planning, not a prerequisite. | Pending UI gate consumes canonical `allComplete`; service requires a passenger. | Best fix: make route creation independent of onboarding completion. Safest Fix: omit the gate from the merge until requirements are approved. |

Notes:

- Branch-qualified line references were verified with `git show codex/membership-premium-send-credits-phase-2:<path>`.
- Tracked mirror reachability is **not** claimed. Browser navigation to mirror-like URLs was blocked with `net::ERR_BLOCKED_BY_CLIENT`, and no fallback was used.
- Correct statements are documented in the surface and safety reviews; the findings table intentionally contains only contradictions, ambiguities, stale phrases, or material missing disclosures.

## Findings by Surface

### 1. Homepage

- **Files inspected:** `partials/fpw-conversion-landing.cfm`, root `index.cfm`, homepage metadata, `assets/js/app/home-visual-tour.js`.
- **Correct:** free planning is stated; an explicit “not an emergency dispatch service” disclaimer appears at `partials/fpw-conversion-landing.cfm:53`.
- **Outdated:** the dormant pricing branch advertises route planning as paid and a 3-Day Pass; the launch-list email says the launch is upcoming/Spring 2026.
- **Ambiguous:** “first Premium trip,” “keeps the plan alive,” and “keeps timing and status current.”
- **Missing:** one-trip duration, message-delivery limits near product claims, and explicit credit-consumption timing.
- **Severity / priority:** Critical / P1 for contract; High / P0 for safety wording.
- **Dependency:** Basic-send policy, canonical one-trip name, duration policy.

### 2. Pricing page

- **Files inspected:** `app/pricing.cfm`, `assets/js/app/pricing.js`, active and inactive flag branches.
- **Correct:** complimentary and purchased credits are stated to grant the same capabilities (`app/pricing.cfm:250`); planning is described as free in the active branch.
- **Outdated:** dormant 3-Day Pass and Premium-planning tables remain executable.
- **Ambiguous:** “general Premium access,” “one complete Premium trip.”
- **Missing:** current duration terms and current credit model in legal cross-reference.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic product-contract, 3-Day Pass status, canonical naming, duration.

### 3. Join and registration pages

- **Files inspected:** `app/join.cfm`, registration flow references, tracked join mirror.
- **Correct:** active copy says planning is free and the included trip covers Premium delivery, Active Cruise, monitoring, and Follow.
- **Outdated:** dormant one-month Premium route-tools trial.
- **Ambiguous:** Basic sending at no cost; “first complete Premium trip” does not name the consumption event.
- **Missing:** duration terms.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic-send policy and one-trip naming.

### 4. Welcome overlay

- **Files inspected:** `app/dashboard.cfm:343-392`, onboarding JS/service.
- **Correct:** describes planning and sharing with someone ashore.
- **Outdated:** none identified in the active overlay.
- **Ambiguous:** “keep them informed until you return safely” implies continuity and outcome.
- **Missing:** messaging/monitoring limitations.
- **Severity / priority:** High / P1.
- **Dependency:** approved safety direction.

### 5. Dashboard

- **Files inspected:** `app/dashboard.cfm`, `assets/js/app/dashboard.js`.
- **Correct:** Draft and route workflows remain accessible on `main`.
- **Outdated:** none in active credit branch.
- **Ambiguous:** free Basic Save & Send contradicts the controlling contract.
- **Missing:** one consistent statement of when paid capability begins.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic operational-flow decision.

### 6. Getting Started guidance

- **Files inspected:** `app/dashboard.cfm`, `assets/js/app/dashboard/onboarding.js`, `api/v1/OnboardingService.cfc`; pending branch versions.
- **Correct:** on `main`, the checklist guides setup without proving a paywall.
- **Outdated:** none proven.
- **Ambiguous:** service canonical completion requires a passenger, while the product presentation does not consistently say a passenger is mandatory.
- **Missing:** approved distinction between recommended readiness and enforced planning prerequisite.
- **Severity / priority:** High / P1 if pending branch merges.
- **Dependency:** onboarding prerequisite and passenger-required decisions.

### 7. Route Generator and Route Builder guidance

- **Files inspected:** `assets/js/app/dashboard/routebuilder.js`, Dashboard route-builder template, access services, pending branch.
- **Correct:** `main` backend planning access is authentication-only.
- **Outdated:** dormant public copy calls these Premium route tools.
- **Ambiguous:** pending branch blocks opening Route Builder until Getting Started is complete.
- **Missing:** explicit free-planning confirmation at the point of entry.
- **Severity / priority:** High / P1.
- **Dependency:** pending-branch merge decision.

### 8. Float Plan Wizard

- **Files inspected:** `app/floatplan-wizard.cfm`, `assets/js/app/floatplanWizard.js`.
- **Correct:** Draft work is preserved through checkout; Premium requirements are displayed before send.
- **Outdated:** none in active branch.
- **Ambiguous:** Basic Save & Send is explicitly free.
- **Missing:** Premium trip-duration/end-of-monitoring disclosure.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic policy and duration.

### 9. Save & Send step

- **Files inspected:** wizard template/JS, `api/v1/floatplan.cfc`, access gate and credit service.
- **Correct:** Premium credit is consumed only after successful committed send; retry does not send/consume again.
- **Outdated:** none identified.
- **Ambiguous:** parallel Basic free operational path.
- **Missing:** duration and delivery limitations.
- **Severity / priority:** Critical / P1; email safety is P0.
- **Dependency:** Basic policy, safety/legal language, duration.

### 10. Trip-credit selection or confirmation interfaces

- **Files inspected:** `assets/js/app/floatplanWizard.js:891-901,1703-1706,1827-1886`, `assets/js/app/account.js:490-650`.
- **Correct:** checkout success says the Draft has not yet been sent; cancellation says no credit was purchased.
- **Outdated:** none in active one-trip return flow.
- **Ambiguous:** Buy One Trip versus Premium Send Credit.
- **Missing:** duration.
- **Severity / priority:** Medium / P1.
- **Dependency:** canonical one-trip customer term.

### 11. Account page

- **Files inspected:** `app/account.cfm`, `assets/js/app/account.js`.
- **Correct:** exposes planning, Basic send, credit count, exact-trip access, and billing source separately.
- **Outdated:** retains trial/promotional access terminology.
- **Ambiguous:** “Premium access confirmed”; free Basic sending contract.
- **Missing:** duration and clearer product-specific checkout status.
- **Severity / priority:** High / P1.
- **Dependency:** naming and Basic policy.

### 12. Membership and upgrade screens

- **Files inspected:** Pricing, Account, `app/start-trial.cfm`, `assets/js/app/start-trial.js`.
- **Correct:** active pricing separates one trip from recurring Monthly/Annual.
- **Outdated:** dormant 30-day trial and 3-Day Pass flows/copy.
- **Ambiguous:** “general Premium access.”
- **Missing:** whether membership trips have a duration maximum.
- **Severity / priority:** High / P1.
- **Dependency:** legacy entitlement support and duration policy.

### 13. Stripe Checkout preparation and success messaging

- **Files inspected:** `api/v1/StripeCheckoutService.cfc`, Account/Wizard JS, webhook/entitlement paths.
- **Correct:** success is confirmed by backend state rather than redirect alone.
- **Outdated:** selector and errors still accept/name `three_day_pass`.
- **Ambiguous:** undifferentiated “Premium access confirmed.”
- **Missing:** external Stripe-hosted product/price display names were not inspected because private Stripe configuration and external checkout were out of scope.
- **Severity / priority:** High / P1.
- **Dependency:** 3-Day Pass status; Stripe catalog verification in a separately authorized task.

### 14. Billing Portal links and surrounding copy

- **Files inspected:** `app/account.cfm:185-189`, `assets/js/app/account.js:658+`.
- **Correct:** portal is limited to Stripe-managed recurring billing.
- **Outdated:** none identified.
- **Ambiguous:** surrounding “Premium access” can include non-Stripe sources not manageable in the portal.
- **Missing:** explicit distinction between billing management and credit history.
- **Severity / priority:** Medium / P1.
- **Dependency:** terminology choice.

### 15. FAQ

- **Files inspected:** `faq/index.cfm`, especially membership and safety entries.
- **Correct:** FAQ says FPW is not emergency dispatch or live GPS tracking (`faq/index.cfm:407,478-482,863-867`).
- **Outdated:** it directs users to trial/free-access offers rather than plainly stating current free planning (`faq/index.cfm:596-609`).
- **Ambiguous:** “trial, free-access, or membership details.”
- **Missing:** credit parity, consumption event, duration.
- **Severity / priority:** Medium / P3.
- **Dependency:** canonical product contract.

### 16. Terms of Service

- **Files inspected:** `terms_of_service.cfm`, including safety and billing sections.
- **Correct:** detailed limits disclaim live monitoring, rescue, emergency service, and guaranteed contact (`terms_of_service.cfm:473-535`).
- **Outdated:** 3-Day Pass and trial families dominate billing terms.
- **Ambiguous:** Free Tier reserves restrictions on saved routes/waypoints contrary to approved direction.
- **Missing:** Premium Send Credit, complimentary/purchased parity, and current consumption event.
- **Severity / priority:** High / P3, with legal review.
- **Dependency:** product decisions and counsel review.

### 17. Privacy or safety disclaimers

- **Files inspected:** `privacy_policy.cfm:599-614`, `includes/footer.cfm:340-342`, Help, FAQ, Terms.
- **Correct:** consistently says FPW is not emergency, dispatch, tracking, rescue, or professional navigation.
- **Outdated:** none identified in the principal disclaimer blocks.
- **Ambiguous:** disclaimers are not always adjacent to stronger operational claims.
- **Missing:** email/SMS/internet delivery guarantee language near transactional surfaces.
- **Severity / priority:** Medium / P0 adjacency work.
- **Dependency:** legal/safety approval.

### 18. Active Cruise

- **Files inspected:** `app/active-cruise.cfm`, `api/v1/ActiveCruiseViewModelService.cfc`.
- **Correct:** state/status data and contact details are exposed.
- **Outdated:** none identified.
- **Ambiguous:** “Live route,” “current position,” “Float Plan Monitor,” “Emergency monitor.”
- **Missing:** source/timestamp qualification adjacent to map and contact role.
- **Severity / priority:** High / P2.
- **Dependency:** approved location/status terminology and contact-role naming.

### 19. Follow page

- **Files inspected:** `app/follow.cfm`, `assets/js/app/follow/follow.js`, `api/v1/voyage.cfc`.
- **Correct:** update timestamps are available.
- **Outdated:** none identified.
- **Ambiguous:** “real time,” “Live now,” “current position” materially overstate the data.
- **Missing:** adjacent non-tracking and freshness disclaimer.
- **Severity / priority:** Critical / P0.
- **Dependency:** none for intent; legal/product approval before copy implementation.

### 20. Monitoring explanations

- **Files inspected:** `app/monitoring.cfm`, `api/v1/MonitoringConsoleViewModelService.cfc`, `api/v1/monitor.cfc`.
- **Correct:** prominently says “Not live vessel tracking” and identifies last shared GPS location.
- **Outdated:** none identified.
- **Ambiguous:** “FPW is monitoring” may imply staff.
- **Missing:** end-of-monitoring/duration behavior and delivery limits.
- **Severity / priority:** High / P2.
- **Dependency:** automated-monitoring label and duration decision.

### 21. Overdue-status explanations

- **Files inspected:** Monitoring UI, monitor state machine, OverdueAlertService.
- **Correct:** state names reflect implemented ACTIVE/LATE/MISSED/ESCALATED flow.
- **Outdated:** legacy overdue-email jobs are retired in current service.
- **Ambiguous:** “Escalated” does not say to whom/what; it can imply professional escalation.
- **Missing:** automation, verification, and emergency-action limits.
- **Severity / priority:** High / P2.
- **Dependency:** safety/legal response language.

### 22. Demo pages

- **Files inspected:** `assets/admin/index.cfm`, `assets/js/app/home-visual-tour.js`.
- **Correct:** depicts route/status workflow.
- **Outdated:** prelaunch, trial, and Spring launch copy in legacy demo.
- **Ambiguous:** “24/7 peace of mind,” live route, Float Plan Monitor.
- **Missing:** disclaimer adjacency and artifact ownership.
- **Severity / priority:** High / P0 if reachable; P3 cleanup otherwise.
- **Dependency:** determine whether tracked demo is deployed/reachable.

### 23. Help text

- **Files inspected:** `app/help.cfm`, `api/app/help.cfm`, `assets/app/help.cfm`.
- **Correct:** active branch says planning/saved routes are free and contains strong safety notes.
- **Outdated:** inactive and mirrored branches call saved routes and route tools Premium.
- **Ambiguous:** Basic free send and “complete trip.”
- **Missing:** duration.
- **Severity / priority:** High / P3.
- **Dependency:** Basic and duration decisions; mirror ownership.

### 24. Tooltips

- **Files inspected:** title/data-help/disabled-reason strings across Dashboard, Wizard, Active Cruise, and Monitoring.
- **Correct:** most tooltips describe current control state without pricing claims.
- **Outdated:** none uniquely identified outside parent surfaces.
- **Ambiguous:** contact/monitor and current-position vocabulary inherits parent-surface risk.
- **Missing:** source/freshness on position help.
- **Severity / priority:** Medium / P2-P3.
- **Dependency:** parent-surface terminology.

### 25. Guided-tour copy

- **Files inspected:** `assets/js/app/home-visual-tour.js`, Dashboard help tour.
- **Correct:** sequence from plan to send to monitoring matches the operational flow.
- **Outdated:** none uniquely identified.
- **Ambiguous:** live/current position and Float Plan Monitor.
- **Missing:** non-tracking qualifier.
- **Severity / priority:** High / P3 after P0 product surfaces.
- **Dependency:** Follow/Active Cruise approved wording.

### 26. Modal dialogs

- **Files inspected:** Basic/Premium send dialogs in Dashboard and Wizard; operational confirmations in Active Cruise.
- **Correct:** Premium dialog preserves Draft and describes credit/member gate.
- **Outdated:** none identified.
- **Ambiguous:** Basic Save & Send is free despite controlling contract.
- **Missing:** duration/delivery limitations.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic policy.

### 27. Banner notices

- **Files inspected:** `includes/top_nav.cfm`, homepage and calculator promo strips.
- **Correct:** active banners say planning is free and included Premium trip is for eligible members.
- **Outdated:** dormant banners offer Premium-free launch periods.
- **Ambiguous:** “Basic sending included”; “first complete Premium trip.”
- **Missing:** consumption event and duration.
- **Severity / priority:** Critical / P1.
- **Dependency:** Basic policy and naming.

### 28. Error messages

- **Files inspected:** access gate, credit, Stripe, floatplan APIs and app JS.
- **Correct:** errors preserve Drafts and identify Premium send requirement.
- **Outdated:** 3-Day Pass selector/errors remain.
- **Ambiguous:** Premium Trip credit versus Premium Send Credit versus Premium access.
- **Missing:** product-specific status in some checkout errors.
- **Severity / priority:** Medium / P1-P3.
- **Dependency:** canonical terminology and pass status.

### 29. Empty states

- **Files inspected:** Dashboard, Active Cruise, Follow, Monitoring empty/fallback strings.
- **Correct:** no-plan/no-data states generally avoid billing claims.
- **Outdated:** none uniquely identified.
- **Ambiguous:** “Emergency monitor not named” creates a professional role even when absent.
- **Missing:** clear “shore contact” fallback and stale/no-position explanation.
- **Severity / priority:** High / P2.
- **Dependency:** contact-role naming.

### 30. Existing transactional emails

- **Files inspected:** `api/v1/email.cfc`, `api/v1/floatplan.cfc`, `api/v1/OverdueAlertService.cfc`, `index.cfm`; retired `_orig`.
- **Correct:** password reset contains no product-access claim; welcome email contains a general safety disclaimer.
- **Outdated:** launch/beta and upcoming Spring 2026 launch.
- **Ambiguous:** monitoring/escalation subjects can imply confirmation or professional response.
- **Missing:** delivery guarantees/limits and clear automation/source context.
- **Severity / priority:** Critical / P0-P2.
- **Dependency:** safety/legal review; launch-list ownership.

### 31. Welcome emails

- **Files inspected:** `api/v1/email.cfc:142-201`.
- **Correct:** safety disclaimer says FPW does not replace emergency services.
- **Outdated:** “launch/beta period.”
- **Ambiguous:** none material beyond lifecycle status.
- **Missing:** current free-planning/paid-operational model is not explained.
- **Severity / priority:** Medium / P3.
- **Dependency:** approved compact welcome positioning.

### 32. Upgrade emails

- **Files inspected:** current CFML/JS email-sending paths and subject definitions.
- **Correct/outdated/ambiguous:** no current upgrade email template found.
- **Missing:** not a defect by itself; no email should be invented in this audit.
- **Severity / priority:** None / Not found.
- **Dependency:** none.

### 33. Float-plan delivery emails

- **Files inspected:** Basic and Premium blocks in `api/v1/floatplan.cfc:8065-8111,8381-8539`.
- **Correct:** both credit sources reach the same Premium delivery path; Basic/Premium email body wording is currently parallel.
- **Outdated:** none identified.
- **Ambiguous:** call selected Rescue Authority instruction.
- **Missing:** delivery/receipt limits, non-confirmation of distress, shore-contact responsibility.
- **Severity / priority:** Critical / P0.
- **Dependency:** safety/legal approval.

### 34. Monitoring and overdue emails

- **Files inspected:** `api/v1/OverdueAlertService.cfc`, monitor callers.
- **Correct:** subjects identify Missed Check-In, Escalated, and Assistance Needed states.
- **Outdated:** current service explicitly retires legacy scheduled jobs.
- **Ambiguous:** “Escalated” and “Assistance Needed” lack source/verification context.
- **Missing:** non-professional-monitoring, delivery, and emergency-response limits.
- **Severity / priority:** High / P0-P2.
- **Dependency:** safety/legal policy and sender-domain operational configuration; no deliverability test was run.

### 35. Completion emails

- **Files inspected:** current mail senders and `api/api_assets/floatPlanUtils_orig.cfc:235-338`.
- **Correct/outdated/ambiguous:** no current completion email was found; retired `_orig` has “back in port” messages and promises updates continuing until return/close.
- **Missing:** current product does not expose a verified completion-email contract.
- **Severity / priority:** Not found / P3 only if feature is reintroduced.
- **Dependency:** explicit product decision; do not revive retired templates.

### 36. Credit-consumption notices

- **Files inspected:** Wizard JS, Account JS, PremiumSendCreditService.
- **Correct:** successful checkout says credit is available and Draft not sent; retry says no second credit/email.
- **Outdated:** none identified.
- **Ambiguous:** internal Premium Send Credit versus customer Buy One Trip.
- **Missing:** exact “consumed on successful Premium Save & Send” explanation in all conversion surfaces.
- **Severity / priority:** Medium / P1.
- **Dependency:** canonical term.

### 37. Renewal, expiration and cancellation emails

- **Files inspected:** current mail senders, billing services, Terms.
- **Correct/outdated/ambiguous:** no current renewal, entitlement-expiration, subscription-cancellation, or credit-expiration email template found.
- **Missing:** absence is not classified as a copy defect without a notification requirement.
- **Severity / priority:** None / Not found.
- **Dependency:** separate product/compliance requirement if these emails are desired.

### 38. Admin-configured or database-driven public copy

- **Files inspected:** schema metadata using read-only database queries; `fpw_promo_codes.public_description`; admin/content source searches.
- **Correct:** no current promo-code public-description rows were returned.
- **Outdated/ambiguous:** none in current database evidence.
- **Missing:** route/port/user content was not treated as business-model copy.
- **Severity / priority:** Clear.
- **Dependency:** none; no database writes occurred.

### 39. Structured data or metadata containing plan descriptions

- **Files inspected:** root metadata, FAQ structured content, public-page meta variables.
- **Correct:** safety FAQ says not live tracking/emergency dispatch.
- **Outdated:** launch/prelaunch metadata exists in a tracked legacy admin page.
- **Ambiguous:** “overdue monitoring” metadata lacks adjacent limitations but is not a guarantee by itself.
- **Missing:** concise current free-planning/paid-operation distinction.
- **Severity / priority:** Medium / P3.
- **Dependency:** finalized contract.

### 40. Page titles and meta descriptions

- **Files inspected:** public templates and shared metadata definitions that describe planning/monitoring.
- **Correct:** principal current descriptions are mostly functional.
- **Outdated:** legacy admin metadata is prelaunch.
- **Ambiguous:** monitoring/tracking descriptions can inherit parent-page implications.
- **Missing:** consistent product-model sentence.
- **Severity / priority:** Medium / P3.
- **Dependency:** parent-surface copy corrections.

### Cross-cutting: tracked legacy mirrors

- **Files inspected:** `assets/app/*`, `api/app/*`, `app/pricing_orig.cfm`, snapshot/original templates, `assets/admin/index.cfm`.
- **Correct:** some mirrors carry strong monitoring disclaimers.
- **Outdated:** trials, 3-Day Pass, Premium-only planning, prelaunch/Spring 2026.
- **Ambiguous:** artifact deployment/ownership.
- **Missing:** live reachability proof; Browser blocked navigation and the required tool policy prohibited unapproved fallback.
- **Severity / priority:** High / P3 after reachability decision.
- **Dependency:** deployment ownership.

### Cross-cutting: pending `codex/membership-premium-send-credits-phase-2`

- **Files inspected:** full branch diff and six feature-only commits.
- **Comparison baseline:** the graph has three `main`-only merge commits and six feature-only commits. The `main` tree and merge-base tree are identical (`86894ab17e546ccaaa2fc1832cacf7d6cf1425fe`), so the direct tree comparison isolates the feature branch content despite the non-linear history.
- **Diff size:** 132 files changed, 8,057 insertions, 86 deletions; 104 files are binary. Much of the scope is bathymetry proof-of-concept data/assets rather than membership language.
- **Feature-only commits:** `27e0a0f` route-creation warning/gate; `35dd9bb` migration changes; `f34ab59` PDF save-path fix; `ef95441` and `95b2b47` template-display changes; `344d52e` bathymetry work.
- **Correct:** no direct mutation of `main` occurred; the pending branch was inspected read-only.
- **Outdated:** no new pricing-copy model was identified.
- **Ambiguous:** route-creation readiness becomes a hard UI gate; passenger is mandatory. The branch also contains unrelated bathymetry POC/binary scope.
- **Missing:** product approval for an onboarding planning gate.
- **Severity / priority:** High / pre-merge.
- **Dependency:** do not merge the gate without a decision. A separate branch defect changes `floatPlanUtils.cfc`’s expected `getString` function declaration to whitespace at line 885 while callers remain; this is a non-language merge validation risk.

## Terminology Inventory

| Term | Files / Surfaces | Current Meaning in Context | Approved Meaning | Status | Recommended Action |
|---|---|---|---|---|---|
| Trial | `app/start-trial.cfm`, start-trial JS/API, Terms, promo, join/home dormant copy, tracked mirrors | Time-based Premium entitlement; launch/promotional offer; legacy access source | Not part of the current complimentary-trip-credit offer unless retained explicitly for legacy support | Retired | Remove from current offers; label legacy entitlement support internally/precisely. |
| Pass | Pricing dormant branch, Terms, Stripe services, mirrors | 3-Day/72-hour nonrecurring Premium entitlement | No approved current customer role in the credit model | Retired | Decide retirement versus supported legacy product; align code/legal/UI. |
| Premium access | Account, checkout, promo, Terms, start-trial | Ambiguous umbrella for subscription, trial, pass, founder, promotion, or exact-trip operational access | Use product-specific Monthly/Annual membership or trip-credit capability | Ambiguous | Replace generic confirmation/status where the source is known. |
| Complimentary trip | Homepage, Join, Pricing/Help concept | Included Premium-capability trip for eligible members | Same capability as a purchased trip credit | Approved | Tie explicitly to one credit and successful Premium Save & Send. |
| Free trip | No exact literal use found in selected current sources; “first trip included” implies it | Possible shorthand for included trip | Avoid if it can imply planning is unlocked by the trip | Undefined | Do not introduce; separate free planning from complimentary operational credit. |
| Trip credit | Gate error, requirements, audit contract | One send-and-monitor transaction | Canonical candidate for customer-facing one-trip entitlement | Ambiguous | Larry selects whether this or Send Credit is canonical. |
| Send credit | Pricing, Account, Wizard, backend service | AVAILABLE/CONSUMED unit used by Premium Save & Send | Same unit whether complimentary or purchased; includes applicable monitoring after send | Approved | Consider customer label “Trip credit” with internal mapping, or consistently retain full “Premium Send Credit.” |
| Monitoring | Homepage, Pricing, Active Cruise, Monitoring, emails, legal | Basic/Premium automation, a state machine, a contact role, and sometimes implied human activity | Automated monitoring/reminders/notices according to implemented behavior | Conflicting | Always qualify automated versus contact responsibility; never imply staff. |
| Membership | Join, Pricing, Account, Terms | Free account membership, recurring Premium Monthly/Annual, founder/lifetime | Free membership for planning; Monthly/Annual for ongoing operational access | Ambiguous | Always qualify Free, Monthly, or Annual. |
| Save & Send | Dashboard, Wizard, Help, backend | Basic free path and Premium credit/member path | Controlling contract says sending/monitoring is paid; current implementation conflicts | Conflicting | Resolve Basic exception first; then use Premium Save & Send consistently for credit consumption. |

Additional audited terms:

- **One-trip credit / Buy One Trip / Premium trip / Single trip:** customer labels vary; no approved canonical winner is encoded.
- **Monitoring credit:** exact phrase not found.
- **Trip pass / Premium pass:** concepts appear through 3-Day Pass/pass-based legal language, not as a consistent current customer product.
- **Active Cruise access:** exact-trip after consumed credit or general Premium; not planning access.
- **Entitlement:** appropriate internal/legal term, but too abstract as the leading customer product name.

## Safety-Language Review

| Exact wording | Evidence | Actual implemented behavior | Risk of misunderstanding | Safer direction |
|---|---|---|---|---|
| “Follow along in real time” | `app/follow.cfm:106` | Presents plan/progress data and discrete shared updates/check-ins. | Continuous vessel tracking. | State that viewers see the plan and latest reported update, with time. |
| “Live route view with current position” | `app/follow.cfm:165`; `app/active-cruise.cfm:3609` | Route plus application-derived/latest shared position state. | Independently current GPS position. | Identify route projection or latest shared check-in source. |
| “Live now” | `assets/js/app/follow/follow.js:878` | UI refreshes current server state. | Continuous live feed. | Use “latest update” plus timestamp. |
| “Float Plan Monitor” / “Emergency monitor” | `app/active-cruise.cfm:4063-4068` | Displays a selected shore contact. | Staffed/professional emergency monitor. | Call the person a shore/trip contact. |
| “See how FPW is monitoring” | `app/monitoring.cfm:738-739` | Automated state evaluation and alerts. | Human FPW surveillance. | Say “automated monitoring status.” |
| “keeps timing and status current” | `partials/fpw-conversion-landing.cfm:182` | Updates depend on user/system events. | Accuracy and availability guarantee. | Describe update capability, not guaranteed currency. |
| “until you return safely” | `app/dashboard.cfm:359` | No guarantee of return, delivery, or duration. | Guaranteed continuity/outcome. | Limit to organizing and sharing information. |
| “call the selected Rescue Authority” | `api/v1/floatplan.cfc:8076-8083,8392-8399` | A precautionary plan email is sent; no distress confirmation or rescue coordination occurs. | FPW instruction/selection substitutes for shore-contact judgment and official emergency guidance. | Legal/safety review a clear verification and official-channel direction. |
| “Missed Check-In,” “Escalated,” “Assistance Needed” | `api/v1/OverdueAlertService.cfc:270-459` | Automated state or reported status emails. | Confirmed emergency/professional escalation. | Identify automation/source and recipient responsibility. |
| “24/7 peace of mind” | `assets/admin/index.cfm:1830` | No staffed 24/7 service. | Always-on professional monitoring/availability. | Remove if reachable. |

No current phrase explicitly guarantees rescue, but the combinations above reasonably imply live awareness, staffed monitoring, timely intervention, or confirmed escalation. Correct counter-language exists in Terms, Privacy, Footer, Help, FAQ, and Monitoring; the material risk is that it is not adjacent to Follow, Active Cruise, delivery email, and alert-email claims.

## Planning-Access Review

| Restriction/evidence | Layer | Finding |
|---|---|---|
| `api/v1/MemberAccessGateService.cfc:52-56` and `api/v1/MemberEntitlementService.cfc:64-75,134-170` | Backend | Planning requires authentication only; free limits are unlimited/null for waypoints and trip days, and saved routes/multi-day planning are allowed. |
| Active Homepage/Pricing/Join/Help | Copy | States planning is free. This matches backend. |
| `app/pricing.cfm:197,202,203` | Copy | Active Premium feature strip incorrectly includes route-based plans, NOAA charts, and Premium route generator. |
| `app/pricing.cfm:273-426` | Legacy executable flag branch | Custom Route Generator and saved route tools are shown as unavailable to Free; 3-Day Pass/trials are advertised. |
| `partials/fpw-conversion-landing.cfm:230-236` | Legacy executable flag branch | Upgrade is said to add route planning and Premium route tools. |
| `app/help.cfm:74,78,96,122` | Multiple flag branches | Active branch is free-planning; inactive branch says routes/saved routes require Premium. |
| `assets/app/help.cfm`, `api/app/help.cfm`, pricing mirrors | Tracked legacy code | Mirrors preserve Premium planning claims; live reachability unverified. |
| `terms_of_service.cfm:594-600` | Legal copy | Free Tier may restrict saved routes, waypoints, and related planning despite controlling direction. |
| `faq/index.cfm:593-609` | Supporting copy | Does not plainly state free planning; refers to trial/free-access possibilities. |
| Pending Route Builder readiness | UI state, pending branch | Hard-blocks route creation until `allComplete`; backend planning entitlement itself remains auth-only. |
| `api/v1/OnboardingService.cfc:85-174` | Backend readiness service | `allComplete` requires passenger, operator, vessel, complete shore contact, and two waypoints. This is not a Premium entitlement gate, but the pending UI converts it into a planning restriction. |
| Tests searched | Tests | Tests assert access/credit behavior, including Basic operational flow; no test evidence established a Premium gate for planning on `main`. |

The strongest contradiction is not “backend blocks while copy says free” on `main`; the backend currently allows planning. It is (a) active/dormant copy inconsistency and (b) the pending branch’s non-entitlement onboarding gate. The branch should not merge with that gate until the prerequisite policy is approved.

## Trip-Duration Review

1. **Current verified behavior — enforced maximum:** no single-trip Premium maximum was found. `api/v1/MemberEntitlementService.cfc:134-170` returns `maxTripDays = null` for Premium.
2. **Current verified behavior — where duration is calculated:** Basic sending constrains a route-less return window to one day/24 hours through access and send validation. The legacy 3-Day Pass computes a 72-hour entitlement expiration. Premium one-trip credit duration is not calculated.
3. **Current verified behavior — more than 21 days:** Premium Send validates that the return is in the future but does not reject a return more than 21 days after departure (`api/v1/floatplan.cfc:8296-8469`). Therefore a longer trip can pass this duration gate if all other validation succeeds.
4. **Current verified behavior — indefinite monitoring:** the state machine can remain active or escalated until an explicit close/cancel/check-in/resolution path; no trip-duration cutoff was found.
5. **Missing behavior — expired state:** monitoring states do not include EXPIRED (`api/v1/monitor.cfc:90-95`).
6. **Current verified behavior — safety grace:** there is a 60-minute missed-check-in grace and a 120-minute escalation delay. These timers govern missed-check-in transitions, not a post-21-day trip grace.
7. **Contradictory copy — completion/return:** “one complete Premium trip” appears on Homepage, Pricing, Join, and Help; “until you return safely” appears in Welcome; a retired email template promises notices continuing until return/check-in/close. These imply completion-based rather than time-based service.
8. **Missing copy — disclosure surfaces:** Homepage one-trip card, Pricing, Join, Welcome, Wizard/Save & Send, checkout confirmation, Account credit display, Help, FAQ, Terms, delivery email, Active Cruise, Follow, and Monitoring would need synchronized disclosure if a limit becomes real.

**Proposed 21-day rule:** this is a product direction only. Before publication it requires at least a defined start/end calculation, timezone rule, boundary behavior, pre-send validation, active-trip behavior at expiry, notification behavior, state model, grace policy, Monthly/Annual applicability, tests, and legal/customer copy. This audit does not implement or claim any of those.

## Email Audit

| Email | Trigger | Recipient | Subject | Relevant wording / terms | Safety implication | Upgrade implication | Model match |
|---|---|---|---|---|---|---|---|
| Welcome | Successful account workflow calling `api/v1/email.cfc` | New member | “Welcome to FloatPlanWizard.com” | “launch/beta period”; general onboarding | Contains an appropriate general safety disclaimer | Does not explain current credit model | Partial; stale lifecycle wording |
| Password reset | Reset request | Account email | “Reset your FloatPlanWizard password” | Reset/security wording only | None identified | None | Clear |
| Root launch-list confirmation | Root POST handler | Submitted address | “Thanks for joining the FloatPlanWizard launch list” | “upcoming launch”; “scheduled to launch Spring 2026” | None material | Implies prelaunch access | Incorrect/stale |
| Basic float-plan delivery | Successful Basic Send | Selected contact(s) | “Float Plan Precautionary Delivery: [plan]” | Instructs contact to call selected Rescue Authority if late | May imply FPW-confirmed escalation path; lacks delivery/emergency limits | Confirms free operational send path | Conflicts with controlling paid-send contract and safety limits |
| Premium float-plan delivery | Successful Premium Send | Selected contact(s) | Same precautionary subject | Same rescue instruction; PDF delivery | Same risk; no receipt guarantee | Does not distinguish complimentary/purchased source, which correctly preserves parity | Capability parity matches; safety disclosure incomplete |
| Missed Check-In | Monitoring state transition | Plan owner | “FPW Monitoring Alert: Missed Check-In - [plan]” | Status/time/plan ID | Can imply conclusive detection; no automation/delivery/emergency qualifier | None | Operational state matches; safety context incomplete |
| Escalated | Monitoring escalation | Monitoring contact | “FPW Monitoring Alert: Escalated - [plan]” | Status/time/plan ID | Can imply professional escalation/rescue coordination | None | State matches; role/limits incomplete |
| Assistance Needed | Reported assistance status | Configured recipient | “FPW Assistance Needed Alert: [plan]” | Status/note/plan ID | May imply confirmed need; no source/response qualifier | None | Relay behavior matches; safety context incomplete |
| Contact Us | Contact form | Support/admin | “Float Plan Wizard Contact Us: [name]” | Customer-submitted inquiry | Internal recipient workflow; not a product promise | Category may mention Premium access | Clear for audit purpose |
| Completion | Current source search | — | — | No current template found; retired `_orig` has back-in-port notices | Retired template overpromises continuing notifications | None | Not found/currently inactive |
| Upgrade | Current source search | — | — | No current template found | None | No current upgrade email | Not found |
| Renewal/expiration/cancellation | Current source search | — | — | No current templates found | None | Billing lifecycle notices not present in mail paths | Not found; no requirement inferred |

No emails were sent. Deliverability, sender-domain production configuration, Stripe receipts, and external payment-processor emails were not tested or inspected.

## Prioritized Correction Plan

### Priority 0 — Immediate safety or legal risk

| Surface | Problem category | Proposed intent | Dependencies | Risk if left unchanged |
|---|---|---|---|---|
| Follow page | Safety overstatement | Describe plan/latest reported update, not real-time/current tracking | Product/legal approval | Shore contact may rely on stale data as live location. |
| Active Cruise map/contact | Safety and professional-monitoring implication | Identify data source/time and call the person a shore contact | Contact-role decision | Captain may believe FPW or a professional monitors the vessel. |
| Float-plan delivery email | Safety overstatement / missing disclosure | Frame as precautionary information; define recipient verification and official emergency channels | Safety/legal review | Recipient may treat email/return time as verified distress or guaranteed delivery. |
| Monitoring/overdue emails | Missing disclosure | Identify automated state/report source and response limits | Safety/legal review | “Escalated” may be read as professional/rescue escalation. |
| Reachable legacy demo, if any | Professional-monitoring implication | Remove “24/7 peace of mind” and guaranteed/timely alert implications | Reachability/ownership proof | Public page could make unsupported service claims. |

### Priority 1 — Core conversion surfaces

| Surface | Problem category | Proposed intent | Dependencies | Risk if left unchanged |
|---|---|---|---|---|
| Product contract / Basic flow | Other | Decide whether every operational send is paid or Basic is an explicit exception | Larry product decision | All core copy remains logically impossible to make consistent. |
| Homepage, Pricing, Join, banners | Contract, planning paywall, duration | Separate free planning from credit/member operational capability | Basic policy, one-trip name, duration | Conversion and billing expectations conflict. |
| Welcome, Dashboard, Wizard, Save & Send | Contract and safety | State exact transition from Draft/planning to operational paid service | Basic policy | In-product action contradicts marketing contract. |
| Account/upgrade/checkout | Terminology | Name Buy One Trip/credit and Monthly/Annual specifically | Canonical naming; pass status | Users cannot tell what was purchased or confirmed. |
| Pending feature branch | Planning paywall | Keep Route Builder available to registered members; make onboarding guidance nonblocking | Onboarding prerequisite decision | Merge would create an unapproved planning restriction. |

### Priority 2 — Operational trip surfaces

| Surface | Problem category | Proposed intent | Dependencies | Risk if left unchanged |
|---|---|---|---|---|
| Monitoring page | Professional-monitoring implication | Say automated monitoring; state end conditions | Duration/end-state decision | Users may assume staff watch the trip. |
| Active Cruise/Follow empty states | Terminology/safety | Use shore-contact and latest-update language | P0 terminology | Fallbacks retain unsupported roles. |
| Overdue explanations | Safety/missing disclosure | Explain state transition, source, and recipient responsibility | Monitoring policy | State names imply verified emergency escalation. |
| Completion/close flow | Missing disclosure | Define whether any completion notice exists and when monitoring ends | Product decision | Customer expectations remain completion-based and indefinite. |

### Priority 3 — Supporting content

| Surface | Problem category | Proposed intent | Dependencies | Risk if left unchanged |
|---|---|---|---|---|
| FAQ / Help | Planning, retired product, duration | State free planning and current paid operational products | P1 decisions | Support content continues to contradict core pages. |
| Terms / Privacy / footer | Legal model alignment | Add current credit model and preserve strong safety limits | Counsel/product approval | Legal terms describe passes/trials rather than current transaction. |
| Tours / tooltips / metadata | Safety/terminology | Inherit corrected parent-surface terms | P0-P2 copy | Secondary sources reintroduce old claims. |
| Legacy mirrors | Retired product/planning paywall | Establish deploy ownership, then remove/synchronize | Reachability decision | Stale customer pages may reappear or be deployed accidentally. |

## Product Decisions Required

| Question | Current conflicting evidence | Available options | Recommended option | Risk of each option |
|---|---|---|---|---|
| Is Basic operational Save & Send/monitoring still a product? | Controlling contract says all operational send/monitor is paid; current code/copy implements free Basic send/monitor. | A: remove/disable Basic operational path; B: approve Basic as a narrow free exception and amend contract; C: redefine Basic as planning/export only. | **Best Fix:** C if product intent permits—free planning/export, paid operational send/monitor. **Safest Fix:** B temporarily, because it matches live behavior without silent behavior change. | A/C require behavior, migration/test/support analysis; B weakens the stated revenue contract and preserves two operational tiers. |
| Final customer name for one-trip product? | Buy One Trip, Premium trip, Trip credit, Premium Trip credit, Premium Send Credit. | Lead with Trip Credit; lead with Premium Send Credit; lead with Buy One Trip. | Use **Trip Credit** as customer noun, “Buy One Trip” as CTA, and keep Premium Send Credit internal if Larry approves. | Changing names requires coordinated UI/email/legal/analytics review; retaining all terms preserves confusion. |
| Does “Premium trip” remain approved? | Used heavily on conversion surfaces; not the backend entitlement name. | Retain as experience label; retire in favor of trip credit. | Retain only as a descriptive capability, never as the purchased unit. | Retire may reduce marketing clarity; retain without definition obscures consumption. |
| Is 3-Day Pass still purchasable or legacy-only? | Checkout/backend/legal support it; active credit pricing hides it; dormant/mirrors advertise it. | Current product; legacy entitlement support only; fully retire. | Legacy-support only, unless Larry explicitly wants it sold. | Full retirement needs code/data/Stripe analysis; keeping it purchasable fragments pricing. |
| Does the 21-day maximum become enforced? | Proposed direction; no code, state, or current copy. | No limit; enforce 21 days; per-product limits. | Enforce only after end-to-end behavior and customer/legal copy are approved together. | Copy-first misrepresents behavior; behavior-first can end monitoring unexpectedly. |
| What starts/ends the 21 days? | Send/activation timestamps, departure/return dates, and monitoring start can differ. | From successful send; departure; monitoring activation; scheduled departure. | Use an explicitly stored monitored-window start tied to activation/departure rules; do not infer. | Each choice affects advance sending, timezone boundaries, and active trips. |
| Is there a post-limit safety grace? | Current 60/120-minute timers are missed-check-in transition timers only. | None; notification-only grace; continued monitoring grace. | Decide separately; do not reuse check-in timers. | Grace can create billing/safety expectations; no grace may stop service abruptly. |
| Do Monthly/Annual member trips have a duration maximum? | General Premium currently has none; proposed text names “single trip credit.” | Same 21 days; no per-trip limit while active; separate extended-cruise rule. | Keep separate from credit policy until extended-cruising requirements are approved. | Unlimited trips create operational burden; universal 21-day limit may contradict membership positioning. |
| May onboarding block Route Builder? | Pending branch requires `allComplete`; approved planning contract says registered members may plan. | Hard gate; warning only; contextual prompts. | Warning/contextual prompts only. | Hard gate contradicts free access and can block clean new users; warning may permit incomplete Drafts. |
| Is a passenger required? | `OnboardingService.cfc` requires one; welcome/product language does not consistently present it as mandatory. | Required; optional; required only for specific operational send. | Optional for planning; validate operational requirements only where actually necessary. | Requiring it blocks solo/no-passenger planning; optional may require explicit zero-passenger confirmation. |
| Will FPW ever provide human professional monitoring? | “Float Plan Monitor” language implies it; no implementation exists; legal copy disclaims it. | Never/currently no; future separately approved service. | State “no professional human monitoring” for the current product. | Leaving future possibility vague increases current reliance risk. |
| What notification channels and delivery guarantees apply? | Current reviewed emails use `cfmail`; no SMS guarantee or end-recipient confirmation was proven. | Best-effort email only; add channels/receipts later; guarantee with operational service. | State best-effort and user responsibility now. | Guarantees are unsupported; broad disclaimers without useful guidance can reduce confidence. |

## Validation

- [x] No application files were changed.
- [x] No customer-facing copy was edited.
- [x] No database writes occurred; database inspection used SELECT/read-only metadata and returned no current promo public-description rows.
- [x] Every finding has repository evidence or is explicitly labeled as a missing disclosure tied to cited source behavior.
- [x] Current-tree line references were checked against `main`; pending-branch references were checked with `git show`.
- [x] Proposed 21-day rules are not presented as implemented.
- [x] No secrets, private configuration contents, Stripe credentials, private member data, or production personal data appear in this report.
- [x] No real customer email address, phone number, vessel name, or trip detail appears in this report.
- [x] No email was sent and no checkout, webhook, billing, database mutation, or deployment was performed.
- [x] Runtime evidence was limited to the local pricing page under the current flag; tracked mirror reachability remains unverified because the required Browser path returned `net::ERR_BLOCKED_BY_CLIENT` and no fallback was authorized.
- [x] `git diff --check` returned no output; because the report is intentionally untracked, `git diff --no-index --check /dev/null docs/product/customer-facing-language-audit.md` was also run and returned no output.

Validation scope note: repository/source evidence does not prove production deployment state, external Stripe catalog wording, production email deliverability, or whether tracked legacy mirrors are publicly routed. Those remain explicitly unverified.
