# Premium Send Credit cutover configuration

Phase 3 uses one server-authoritative setting:

- `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED`
- Optional; missing or false preserves the legacy launch-trial signup and messaging.
- Accepted true values are `1`, `true`, `yes`, and `on` (case-insensitive).
- The browser cannot activate the cutover.

One-trip Checkout also requires both:

- `FPW_STRIPE_PRICE_ONE_TRIP`: the environment-specific Stripe one-time Price ID. This value remains server-only.
- `FPW_STRIPE_ONE_TRIP_DISPLAY_AMOUNT`: the approved customer-facing amount. Set this to `$4.99` (USD) for the one-trip product.

If either one-trip value is missing, customer surfaces show Buy One Trip as unavailable and the server does not create a one-trip Checkout Session.

## Environment procedure

Local development and staging must use Stripe test-mode credentials and an approved active one-time Price in the expected currency. Set both one-trip values, then explicitly set `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=true` and reload the ColdFusion application.

Production activation is a separate deployment step:

1. Confirm the live one-time Price and approved display amount.
2. Add the two one-trip values to the production private configuration.
3. Deploy and validate while the cutover flag remains false.
4. Set `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=true`.
5. Reload the application through the authenticated administrative reload path.
6. Run the launch smoke checks before announcing the cutover.

Do not commit private Stripe configuration or Price IDs.

## Rollback

Set `FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED=false` and reload the application. New signup returns to the legacy trial redirect and no new complimentary credit is granted. Existing credits, receipts, trials, paid subscriptions, and promotional entitlements are retained; rollback never deletes or restores financial or credit history.
