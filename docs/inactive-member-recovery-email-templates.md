# Inactive-Member Recovery Email Template Contract

Status: implemented for template and rendering only. Automatic recovery delivery is not enabled or authorized.

## Architecture and authority boundary

`api.v1.email.buildInactiveMemberRecoveryEmail(stage, eligibility, firstName?, verifiedDraftUrl?)` is the single shared builder. A private four-stage configuration supplies only the approved subject, body, and CTA label. The builder reuses the existing environment-aware URL resolver, base email layout, and `buildNonEssentialEmailComplianceFooter()` output.

The builder does not classify, evaluate policy, claim or write the ledger, schedule, or send email. It does not query member, vessel, route, Draft, recipient, or activity state. The upstream contract remains **Shared → D → C → B → A**; a future sender may call this builder only after the classifier and ledger authorize delivery.

## Production copy and destinations

| Verified stage | Subject | Body | CTA | Destination |
| --- | --- | --- | --- | --- |
| A | Add your boat to FloatPlanWizard | Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans. | Continue Vessel Setup | Environment-aware Dashboard |
| B | Ready to plan your first trip? | Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip. | Start Planning a Trip | Environment-aware Dashboard |
| C | Pick up your trip planning | You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready. | Continue Trip Planning | Environment-aware Dashboard |
| D | Your Float Plan is waiting | You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore. | Continue Your Float Plan | Explicitly supplied, same-origin verified Draft URL; otherwise Dashboard |

The Stage D builder accepts no plan ID. Its optional argument is named `verifiedDraftUrl` to preserve the internal caller contract: ownership and Draft status must already be verified before the URL is supplied. The builder accepts only the current environment origin and the authenticated `/app/floatplan-wizard.cfm` path. A malformed or cross-origin supplied URL fails without message bodies; omission uses Dashboard.

## Compliance and safety

Every successful rendering requires an eligible non-essential compliance result. The existing footer enforces a signed unsubscribe URL, a separate Manage Preferences destination, and the business address loaded through `FPW_BUSINESS_MAILING_ADDRESS`. The address and unsubscribe token are not generated or hard-coded by the stage configuration.

Unknown stages return `INVALID_RECOVERY_STAGE`. Invalid supplied Draft URLs return `INVALID_VERIFIED_DRAFT_URL`. Missing, malformed, or ineligible compliance input returns `NON_ESSENTIAL_COMPLIANCE_REQUIRED`. Every failure result has empty subject, HTML body, plain-text body, CTA label, and CTA URL.

HTML and plain text share the same subject, body, CTA label, destination, closing, and compliance footer. The HTML uses the established 640-pixel email layout and one existing-style product CTA button. Footer links are compliance/navigation links, not additional product CTAs.

Personalization is limited to an optional caller-supplied first name. Control whitespace is normalized, length is bounded, and HTML is escaped. Vessel names, route names, destinations, contacts, timestamps, inactivity duration, stage codes, and internal object IDs are not template inputs.
