#!/usr/bin/env bash

set -euo pipefail

readonly FPW_STRIPE_DEV_FORWARD_URL="http://localhost:8500/fpw/api/v1/stripeWebhook.cfc?method=handle"
readonly FPW_STRIPE_DEV_EVENTS="checkout.session.completed,checkout.session.async_payment_succeeded,customer.subscription.created,customer.subscription.updated,customer.subscription.paused,customer.subscription.resumed,customer.subscription.deleted,invoice.payment_succeeded,invoice.payment_failed"

if ! command -v stripe >/dev/null 2>&1; then
  echo "Stripe CLI is not installed or is not on PATH." >&2
  exit 1
fi

exec stripe listen \
  --events "${FPW_STRIPE_DEV_EVENTS}" \
  --forward-to "${FPW_STRIPE_DEV_FORWARD_URL}"
