# Inactive-Member Recovery Email Template Contract

Status: stage-specific destinations implemented. Production recovery sending remains separately gated.

## Architecture and authority boundary

`api.v1.email.buildInactiveMemberRecoveryEmail(stage, eligibility, firstName?, verifiedDraftUrl?, verifiedRouteUrl?)` is the single shared builder. A private four-stage configuration supplies only the approved subject, body, and CTA label. The builder reuses the existing environment-aware URL resolver, base email layout, and `buildNonEssentialEmailComplianceFooter()` output.

The builder is template and rendering only. It does not classify, evaluate policy, claim or write the ledger, schedule, or send email. It does not query member, vessel, route, Draft, recipient, or activity state. The upstream contract remains **Shared → D → C → B → A**; the sender calls this builder only after the classifier and ledger authorize delivery.

## Production copy and destinations

| Verified stage | Subject | Body | CTA | Destination |
| --- | --- | --- | --- | --- |
| A | Add your boat to FloatPlanWizard | Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans. | Continue Vessel Setup | Dashboard deep link opens Add Vessel |
| B | Ready to plan your first trip? | Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip. | Start Planning a Trip | Dashboard deep link enters the existing new-route readiness/Trip Planner workflow |
| C | Pick up your trip planning | You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready. | Continue Trip Planning | Verified saved-route or planned-instance deep link; otherwise Routes |
| D | Your Float Plan is waiting | You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore. | Continue Your Float Plan | Verified Draft deep link opens its Basic or route-backed editor; otherwise Float Plans/Routes |

The builder accepts no member/object IDs. Its optional `verifiedRouteUrl` and `verifiedDraftUrl` arguments are internal, nonremote inputs. Ownership/current eligibility must already be verified by `InactiveMemberRecoveryDestinationService`. The builder accepts either its canonical relative Dashboard action path or the same path under the configured public base URL; external, malformed, unsupported, or wrong-stage destinations fail without message bodies.

## Selection, continuation, and fallback

- A: `/app/dashboard.cfm?recoveryAction=vessel`.
- B: `/app/dashboard.cfm?recoveryAction=planner`. Existing onboarding readiness remains effective.
- C: `recoveryAction=route&routeId=<id>` for the newest active owned saved route by `updated_at DESC,id DESC`, matching `listMyRoutes`. If none exists, use `routeInstanceId=<id>` for an owned clean PLANNED generated route, matching the generated Routes ordering and newest-instance editor convention. No route is created by following this link.
- D: `recoveryAction=draft&floatPlanId=<id>` only for a unique eligible owned Draft. Multiple candidates are ambiguous and use the plan-list fallback; no arbitrary Draft is chosen. Canonical Basic Drafts open the existing Basic editor.
- C fallback: `recoveryAction=routes`. D fallback: `recoveryAction=plans`. Missing, foreign, inactive/advanced, unreadable, or otherwise invalid targets never produce a guessed object URL. Click-time failure focuses the existing Routes/Float Plans panel.

The sender resolves destinations after its unchanged fresh stage/eligibility check. The authenticated Dashboard rechecks the requested object's ownership and current state before rendering the action payload; existing member APIs check ownership again when loading the editor.

`InactiveMemberRecoveryActionPathService` reconstructs only fixed recovery actions and canonical positive integer IDs. It rejects unknown fields and arbitrary return URLs. Anonymous recovery links use the existing login page, whose server-rendered safe destination is consumed after successful login. Stale-session redirects retain that same validated context. Ordinary login redirects are unchanged.

No recovery campaign parameters or click-tracking hooks existed in the prior builder/sender. This change retains the four message types/copy/labels, stage accounting, multipart layout, and compliance links; it does not invent a new campaign or tracking system.

## Compliance and safety

Every successful rendering requires an eligible non-essential compliance result. The existing footer enforces a signed unsubscribe URL, a separate Manage Preferences destination, and the business address loaded through `FPW_BUSINESS_MAILING_ADDRESS`. The address and unsubscribe token are not generated or hard-coded by the stage configuration.

Unknown stages return `INVALID_RECOVERY_STAGE`. Invalid supplied Draft URLs return `INVALID_VERIFIED_DRAFT_URL`; invalid supplied route URLs return `INVALID_VERIFIED_ROUTE_URL`. Missing, malformed, or ineligible compliance input returns `NON_ESSENTIAL_COMPLIANCE_REQUIRED`. Every failure result has empty subject, HTML body, plain-text body, CTA label, and CTA URL.

HTML and plain text share the same subject, body, CTA label, destination, closing, and compliance footer. The HTML uses the established 640-pixel email layout and one existing-style product CTA button. Footer links are compliance/navigation links, not additional product CTAs.

Personalization is limited to an optional caller-supplied first name. Control whitespace is normalized, length is bounded, and HTML is escaped. Vessel names, route names, destinations, contacts, timestamps, inactivity duration, stage codes, and internal object IDs are not template inputs.
