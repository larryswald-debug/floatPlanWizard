# Non-Essential Email Compliance Contract

## Scope

This contract prepares future non-essential FPW email for eligibility checking and compliant footer rendering. It does not send email and does not add recovery templates, classification, scheduling, ledger behavior, CRM, analytics, pricing, or lifecycle behavior.

## Eligibility

Call `api.v1.email.checkNonEssentialEmailEligibility(email, userId)` before rendering or sending a non-essential message.

The method returns only:

- `eligible`: boolean.
- `code`: `ELIGIBLE`, `OPTED_OUT`, `INVALID_EMAIL`, `PREFERENCE_LOOKUP_FAILED`, or `UNSUBSCRIBE_URL_FAILED`.
- `unsubscribeUrl`: populated only for `ELIGIBLE`.

The helper validates the recipient, calls the existing `EmailOptOutService.isOptedOut(email, "non_essential")`, and then creates a URL through the existing signed-token mechanism. Preference lookup or signed-link creation failure returns an ineligible result. The helper does not send or log email.

## Footer rendering

Pass the complete eligible result to `api.v1.email.buildNonEssentialEmailComplianceFooter(eligibility)`. The non-essential footer:

- rejects an ineligible or malformed result;
- requires a signed `/unsubscribe.cfm?t=...` URL;
- keeps the signed unsubscribe destination distinct from `/app/account.cfm#email-preferences`;
- renders both HTML and plain text;
- requires the configured business mailing address.

The unsigned `/unsubscribe.cfm` fallback was removed from the non-essential footer path. The existing service footer remains separate. Existing welcome, password-reset, departure-reminder, safe-arrival, and other operational send behavior is not reclassified by this prerequisite.

## Business mailing address configuration

The address source is the existing private JSON configuration selected by `application.stripeConfigPath` (falling back to `/_fpw_private/stripe-config.json`). Configure the approved single-line mailing address as:

```json
{
  "FPW_BUSINESS_MAILING_ADDRESS": "approved legal mailing address"
}
```

No approved address was present in repository documentation or the active local private configuration during implementation. Until an approved value is supplied, non-essential footer rendering throws `email.BusinessMailingAddressRequired` and therefore fails closed. A missing, unreadable, malformed, null, or empty value is treated as unavailable. The implementation does not invent or backfill an address.

Operational footers keep their established rendering when this value is absent. When the approved value is configured, the centralized footer configuration can render it without changing the signed unsubscribe contract.

## Privacy and diagnostics

Use the account `userId` with its canonical email where available so the existing token stores an email hash and user reference rather than the raw email. Eligibility results do not return an email address. The new helper does not log tokens, email bodies, recipient addresses, user/trip data, or configuration content.
