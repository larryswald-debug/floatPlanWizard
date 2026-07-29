# Authoritative Backend Event Firing Points

## Executive Summary

This report maps the current FloatPlanWizard backend paths that can authoritatively establish the requested funnel events. It is discovery only: no analytics calls, schema changes, database writes, or application behavior changes are proposed or implemented here.

Seven events have a clear backend success boundary in the current application. Five require a product definition or a missing lifecycle state before they can be instrumented without guessing:

- Clear backend boundary: `sign_up`, `login`, `vessel_created`, `shore_contact_created`, route-backed `trip_activated`, `trip_completed`, and `purchase`.
- Definition or lifecycle gap: `email_verified`, `route_started`, `route_completed`, `float_plan_created`, and `trip_shared`.
- High-confidence mappings: 6. Medium-confidence mappings: 5. Low-confidence mappings: 1.
- The safest first event to implement is `sign_up`: one production endpoint owns the successful account insert. Its remaining duplicate risk is the absence of a database uniqueness constraint on normalized email.
- The highest-risk event to implement incorrectly is `purchase`: checkout creation, trial activation, promo redemption, entitlement access, and a successful paid transaction are separate concepts.
- Existing GA4 and Clarity integrations are client-side, public-site integrations. FPW application paths are explicitly excluded, so they are not authoritative sources for these backend lifecycle events (`includes/analytics_ga4.cfm:1-52`, `includes/analytics_clarity.cfm:1-37`).
- Backend instrumentation should occur only after the authoritative database operation has committed. Analytics failure must be isolated so it cannot roll back or change a user action, monitoring transition, email result, or Stripe webhook response.
- Event timestamps should be server-authoritative UTC. The current code mixes server-local `NOW()`/CFML `now()` with `UTC_TIMESTAMP()`, so an analytics layer must normalize deliberately instead of inheriting whichever convention a path currently uses.

No event payload should include names, email addresses, phone numbers, vessel details, shore-contact or passenger details, coordinates, database IDs, route IDs, float-plan IDs, tokens, Stripe identifiers, request bodies, authentication data, or session data.

## Event Map

| Event | Authoritative Source | Exact Firing Point | Transaction Boundary | Entity / Cardinality | Idempotency Strategy | Safe Metadata | Confidence | Unresolved Decision |
|---|---|---|---|---|---|---|---|---|
| `sign_up` | `api/v1/join.cfc:195-237` | After the `users` insert succeeds and `LAST_INSERT_ID()` returns a positive user ID; do not wait for the optional welcome email | No encompassing transaction exists; fire after the successful insert, isolated from later optional work | Account; once per newly persisted user | Internal creation key; add/confirm normalized-email uniqueness before relying on email-level deduplication. Never export the key | `signup_method=password`, `account_tier=basic` | High | Whether duplicate prevention must be strengthened before instrumentation |
| `email_verified` | No current source | None. The application has no canonical verified state or verification-token workflow | Missing | Account; once on unverified-to-verified transition | Future atomic transition from no verified timestamp to a verified timestamp | `verification_method=email_link` only after such a workflow exists | Low | Canonical state, token rules, expiry, and repeated-link behavior |
| `login` | `api/v1/auth.cfc:55-144` | After password verification, `lastLogin` update, session rotation, and authenticated session creation succeed | No explicit DB transaction; authentication success is established before the success response | Authentication attempt; every successful explicit password login | One event per successful endpoint execution; request correlation may suppress retries internally but must not be exported | `auth_method=password` | High | Whether the metric means every successful login or only a newly established session |
| `vessel_created` | Member: `api/v1/vessel.cfc:183-226`; admin: `api/v1/adminVessels.cfc:370-475` | Member: after the insert returns `generatedKey`; admin: after insert, positive `LAST_INSERT_ID()`, and successful reload | No encompassing transaction; member default-vessel clearing precedes the insert | Vessel; once per new row, never on update | Internal vessel creation ID plus source path; never export the ID | `creation_source=member` or `admin` | High | Whether admin-created vessels belong in the product funnel |
| `shore_contact_created` | `api/v1/contact.cfc:65-139` | After the create branch insert returns `generatedKey`; never in the update branch | No explicit transaction | Shore contact; once per new row | Internal contact creation ID; never export it. The schema has no natural duplicate constraint | `creation_source=member` | High | Whether intentional duplicate contacts should count separately |
| `route_started` | Candidate: `api/v1/routeBuilder.cfc:1820-1900` | Recommended candidate: after a new `user_routes` row is inserted, excluding preview, restore/reactivation, and page load | Insert is not wrapped in a broader transaction | Route-building intent; once per new persisted custom route | Unique `(user_id, route_name)` plus internal route ID; do not export either | `route_source=custom` | Medium | Template-based routes have no equivalent persisted “start”; define what “started” means across builders |
| `route_completed` | Candidate: `api/v1/routeBuilder.cfc:12134-12310` | Recommended candidate: after `routegenGenerate` commits the generated route, route instance, and normalized legs and returns success | Explicit transaction encompasses generated route, route instance, and leg persistence | Generated route instance; once per first successful generation | Internal route-instance ID; ignore preview and later update/reverse operations | `route_source=custom|template`, `trip_type=one_way|round_trip` | Medium | No canonical builder-completed flag exists; approve generation success as the definition or add a lifecycle state |
| `float_plan_created` | `api/v1/floatplan.cfc:3580-4043`, `api/v1/floatplan.cfc:4047-4430`, `api/v1/routeBuilder.cfc:3151-3568` | Recommended candidate: after a transaction commits a newly inserted `floatplans` DRAFT row and all required selections/details; exclude update and reuse paths | Explicit save/build transaction | Float plan; once per newly persisted plan entity | Internal float-plan ID; route build must distinguish new insert from reuse/rebuild. Never export the ID | `plan_type=basic|route_backed`, `creation_source=direct|route_builder` | Medium | Does “created” mean persisted draft or a later ready/finalized plan? |
| `trip_activated` | Route-backed: `api/v1/floatplan.cfc:5940-6090`, `api/v1/floatplan.cfc:8023-8190` | After the first explicit ON_TRACK check-in transaction establishes `route_instances.started_at` and the first leg’s `started_at`; never on Active Cruise page load or scheduled send alone | Explicit check-in transaction; monitoring start is part of the operational transition | Operational trip / route instance; once | Atomic PLANNED-to-ACTIVE transition with previously-null `started_at`; never export route or plan IDs | `plan_type=route_backed`, `activation_method=on_track_checkin` | Medium | Basic plans have no route-instance operational-start proof; decide whether successful send/monitoring activation is equivalent |
| `trip_shared` | Candidate: `api/v1/floatplan.cfc:7061-7303`, `api/v1/floatplan.cfc:7328-7620` | Recommended candidate: after a send-to-contacts operation returns success following at least one accepted `cfmail` submission and successful plan/monitoring state transition | Email submission occurs before the plan/monitoring transaction; no durable delivery transaction exists | Float plan; once for current DRAFT-to-ACTIVE send flow | DRAFT-only send gate plus internal float-plan identity; do not treat token creation, copy, or follow-page view as sharing | `share_method=email`, coarse `recipient_count_bucket` if approved | Medium | Is “shared” send accepted, delivery confirmed, link copied, invitation created, or first recipient access? |
| `trip_completed` | Route-backed: `api/v1/floatplan.cfc:5041-5215`, `includes/RouteProgressService.cfc:190-330`; basic: `api/v1/floatplan.cfc:6970-7045` | After the close transaction commits `status=CLOSED`, `closedAt`, and closed/disabled monitoring; route-backed plans must also satisfy final-leg completion gating | Explicit close transaction | Float plan / trip; once | Atomic non-CLOSED-to-CLOSED transition and existing idempotent monitoring close | `plan_type=basic|route_backed`, `completion_method=arrival_checkin|basic_close` | High | None for the current lifecycle definition |
| `purchase` | `api/v1/stripeWebhook.cfc:1-83`, `includes/StripeEntitlementService.cfc:10-313`, `includes/StripeEntitlementService.cfc:426-511` | Subscription: after a verified `invoice.payment_succeeded` for a known subscription successfully upserts an active entitlement. One-time pass: after verified, paid `checkout.session.completed` successfully creates the entitlement | Signature verification precedes service dispatch; webhook registration, entitlement mutation, and final event-result update are not one encompassing transaction | Successful payment transaction; once per charge/payment | Unique webhook event ID plus internal invoice/payment identity; never export Stripe or database identifiers | `purchase_type=subscription|three_day_pass`, `billing_period=initial|renewal` only if deterministically derived | High | Count first paid conversion only or every successful renewal? |

## Detailed Event Findings

### 1. `sign_up`

**Canonical source and execution path.** The production signup path is `api/v1/join.cfc`. It validates the submitted email and checks for an existing row at lines 170-193, hashes the password and inserts `users` at lines 195-237, optionally writes an address at lines 239-263, updates `lastLogin` and establishes `session.user` at lines 264-285, attempts a non-fatal welcome email at lines 286-300, and returns success at lines 302-316.

**Authoritative firing point.** The first authoritative account-creation boundary is the successful `users` insert plus a positive `LAST_INSERT_ID()`. The welcome email is explicitly non-fatal and therefore cannot define signup success. The event should be emitted after the account insert is committed and must not cause signup failure if analytics is unavailable.

**Cardinality and duplicate risk.** Count once per newly persisted account. The endpoint performs an application-level duplicate-email query, but the inspected `users` schema has no unique email index. Two concurrent requests could therefore pass the check. Instrumentation should not conceal that application race, and email must not be sent as an analytics key.

**Existing test evidence.** `tests/integration/PublicSignupContractSpec.cfc:70-129` covers invalid input, duplicate email, a successful Basic account, persistence, and subsequent login.

**Privacy.** Permit only coarse method/tier metadata. Exclude all submitted form values, email, name, phone, address, user ID, password material, request body, and session contents.

### 2. `email_verified`

**Canonical source and execution path.** None exists. The inspected `users` schema contains no verified flag, verified timestamp, or verification-token columns. Repository searches found no email-verification endpoint or verification-token state. `includes/email.cfc:5-58` sends the welcome email; password-reset mail is a separate recovery workflow and is not proof that the account owner verified an address.

**Authoritative firing point.** No event can be fired without inventing state. A future implementation needs a canonical, one-time state transition—preferably a server-authoritative verified timestamp written only after a valid, unexpired, single-purpose token is consumed.

**Cardinality and duplicate risk.** Count once on the atomic transition from unverified to verified. Reused links should return the existing verified state without generating another event.

**Product/implementation gap.** Decide the verification requirement and token semantics, then approve the required persistence and endpoint work separately. Do not instrument welcome-mail submission, login, password reset, or an email-link click as `email_verified`.

**Privacy.** The event may describe the method but must not include the address or token.

### 3. `login`

**Canonical source and execution path.** `api/v1/auth.cfc:55-88` looks up the account, lines 91-106 verify the password and reject failure, lines 108-114 update `lastLogin`, and lines 116-144 rotate the session, create `session.user`, and return success.

**Authoritative firing point.** Emit only after password verification and authenticated session establishment succeed. A page request that merely restores or uses an existing session is not a login. A failed password attempt is not a login.

**Cardinality and duplicate risk.** If the intended metric is successful authentications, every successful explicit login counts. If the intended metric is newly established sessions, product must define the session boundary before implementation. `Application.cfc:54-116` provides a per-request correlation identifier, but it is not a persisted analytics deduplication record.

**Existing test evidence.** `tests/integration/AuthLoginContractSpec.cfc:17-48` verifies a successful password login and response/session contract.

**Privacy.** Permit `auth_method=password`. Exclude email, user ID, login body, password, session identifiers, request correlation values, IP address, and user agent unless separately approved under a privacy policy.

### 4. `vessel_created`

**Canonical source and execution path.** Member creation is the create branch in `api/v1/vessel.cfc:183-226`; updates use a different branch. Administrative creation exists separately in `api/v1/adminVessels.cfc:370-475`.

**Authoritative firing point.** For member creation, emit after the insert returns a generated key. For admin creation, emit after the insert returns a positive ID and the created vessel reload succeeds. Never emit from update, list, default-selection, or delete paths.

**Transaction risk.** The member path clears an existing default before the new insert and does not wrap the full sequence in one transaction. Analytics must follow the successful insert and cannot be allowed to alter that behavior.

**Existing test evidence.** `tests/integration/VesselOperatorCrudContractSpec.cfc:25-76` exercises invalid create, successful create, update, and operator linkage. Dashboard CRUD tests cover the member-facing list/create/delete path.

**Privacy.** Permit only the source path if needed. Exclude vessel name, type, registration/documentation number, dimensions, hailing port, MMSI, radio details, equipment, operator data, and vessel ID.

### 5. `shore_contact_created`

**Canonical source and execution path.** `api/v1/contact.cfc:65-77` enforces Premium access, lines 80-104 validate input and optional ID, lines 106-115 update an existing contact, lines 116-129 insert a new contact and read `generatedKey`, and lines 131-139 return success.

**Authoritative firing point.** Emit only from the insert branch after a generated key exists. Updates, list reads, float-plan association, and deletion are not creation.

**Cardinality and duplicate risk.** Count each persisted contact entity once. The inspected schema has no natural uniqueness rule for contacts, so two intentionally or accidentally duplicate rows are two entities. Product may decide otherwise, but analytics should not inspect PII to deduplicate.

**Existing test evidence.** `tests/integration/ContactPassengerWaypointCrudContractSpec.cfc:25-64` covers invalid and successful contact creation; Dashboard CRUD coverage exercises create/list/delete.

**Privacy.** Do not include the contact’s name, email, phone, relationship, address, database ID, or any associated passenger/float-plan data.

### 6. `route_started`

**Competing authorities.** A custom “My Route” is first persisted by `createUserRoute` in `api/v1/routeBuilder.cfc:1820-1900`. The function either reactivates/restores an existing same-name route or inserts a new `user_routes` row. Template-driven route work can remain preview-only until generation and therefore has no equivalent persisted draft-start boundary. Separately, `route_instances.started_at` represents an operational trip start, not route-builder engagement.

**Recommended definition.** Define `route_started` as the first successful persistence of route-building intent. Under current code, the only deterministic candidate is a new `user_routes` insert. Exclude page load, preview, an existing-route restore, and route-instance operational start.

**Gap.** The candidate does not cover template-based starts. A cross-builder metric requires either a product-approved different definition or a new canonical lifecycle record. Do not fire client-side on “start” clicks and call it authoritative backend completion.

**Cardinality and duplicate risk.** One per new route-building entity. `user_routes` has a unique `(user_id, route_name)` constraint, which makes same-name restore distinguishable from insert.

**Existing test evidence.** `tests/integration/CustomRouteLifecycleSpec.cfc:1-67` covers create, leg mutation, preview, delete, and same-name reactivation.

**Privacy.** Exclude route name, waypoints, coordinates, notes, distances, route code, and all route/database IDs.

### 7. `route_completed`

**Canonical candidate and execution path.** `routegenGenerate` in `api/v1/routeBuilder.cfc:12134-12310` validates the generation request and, inside a transaction, creates the generated route, a PLANNED `route_instances` row, and normalized legs before returning “Route generated.” `routegenUpdate` at lines 12470-12620 can later update/reverse/rebuild the same instance and is not first completion.

**Recommended definition.** Treat the first successful generation transaction as builder completion. It proves that a usable route instance and normalized legs were persisted. Exclude preview, validation failure, update, reverse, and trip operational completion.

**Gap.** There is no builder-completed flag or timestamp. If product means a later user confirmation, saving a float plan, or finishing the trip, this candidate is wrong and a distinct state is required.

**Cardinality and duplicate risk.** Count once per first generated route instance. Use the internal instance identity and the insert-vs-update outcome; do not export the identity.

**Existing test evidence.** `tests/integration/RouteInstancePhase1Spec.cfc:54-135` verifies generated instance persistence. `tests/integration/RouteTemplateLifecycleSpec.cfc:17-58` covers preview, generate, update, and delete.

**Privacy.** Safe metadata is limited to coarse source/trip type. Exclude names, codes, waypoint content, coordinates, distances, dates, route JSON, and IDs.

### 8. `float_plan_created`

**Competing creation paths.** The general/Premium save flow is `saveFloatPlan` at `api/v1/floatplan.cfc:3580-4043`; the Basic flow is `saveBasicFloatPlan` at lines 4047-4430. Both insert a DRAFT `floatplans` row inside a transaction with dependent details/selections. Route-backed creation also occurs in `buildFloatPlansFromRoute` at `api/v1/routeBuilder.cfc:3151-3568`, which can reuse existing plans or purge/rebuild draft plans.

**Recommended definition.** Define creation as the successful commit of a newly inserted DRAFT plan and its required dependent state. Do not count updates or reuse responses. A rebuild that replaces one draft with another needs a deterministic insert outcome and a product decision about whether replacement is another creation.

**Gap.** Current creation is always persistence of a draft; there is no separate canonical “ready” or “finalized” state. If the funnel means a completed, sendable plan rather than a saved draft, do not use the insert boundary.

**Cardinality and duplicate risk.** One per new persisted float-plan entity. Route-builder reuse and rebuild behavior must be tested explicitly to prevent duplicate events.

**Existing test evidence.** `tests/integration/RouteTemplateBuildFloatPlansSpec.cfc:20-70` verifies that first build creates and a repeated build can reuse existing plan state.

**Privacy.** Permit only coarse plan type and creation source. Exclude plan name, operator/vessel/contact/passenger data, itinerary, dates, coordinates, route data, and IDs.

### 9. `trip_activated`

**Competing authorities.** Sending a plan changes it from DRAFT to ACTIVE and may schedule monitoring (`api/v1/floatplan.cfc:7061-7303`, `api/v1/floatplan.cfc:7328-7620`). That state means the plan was sent/monitoring was initialized; it is not, for route-backed plans, proof that the vessel began the trip. Active Cruise and Follow bootstrap paths call `ensureOperationalStartForScheduledPlan` (`api/v1/floatplan.cfc:7600-7690`), which reads operational-start state but does not create it.

**Authoritative route-backed firing point.** The first supported ON_TRACK check-in follows `api/v1/floatplan.cfc:5940-6090` and calls `startOperationalTripNow` at lines 8023-8190 in the check-in transaction. The authoritative transition updates a PLANNED route instance to ACTIVE with `started_at`, starts the first uncompleted leg, and ensures monitoring. Emit only after that transaction commits.

**Basic-plan gap.** Basic plans have no route instance or leg-start proof. Product must decide whether a successful send plus monitoring activation is the Basic equivalent, or whether Basic trips need their own explicit start state.

**Cardinality and duplicate risk.** Route-backed activation is once per route instance, guarded by previously-null `started_at` and PLANNED-to-ACTIVE semantics. Later check-ins and page loads must not repeat it.

**Existing test evidence.** `tests/integration/TripActivationRegressionSpec.cfc:360-420` proves the first ON_TRACK check-in starts exactly the first leg and that a second check-in does not move the start timestamp. Lines 430-490 prove unsupported pre-departure statuses do not start the trip.

**Privacy.** Exclude check-in notes, positions, coordinates, timing details that can reveal travel, float-plan/route IDs, and monitoring payloads. Coarse plan type and activation method are sufficient.

### 10. `trip_shared`

**Competing authorities.** The send-to-contacts functions submit email and then transition plan/monitoring state (`api/v1/floatplan.cfc:7061-7303`, `api/v1/floatplan.cfc:7328-7620`). A voyage-stream token can be created later by `ensureVoyageStreamForFloatPlan` at lines 6592-6675. `api/v1/voyage.cfc:3360-3540` can create/return an owner follow URL, while `assets/js/app/follow/follow.js:2087-2104` only copies a link to the client clipboard. None of token creation, copy, or follow-page rendering proves that another person received a share.

**Recommended definition.** Define `trip_shared` as successful server-side submission of at least one shore-contact email followed by successful plan/monitoring transition and endpoint success. This means “accepted for sending,” not “delivered” or “viewed.”

**Transaction and observability risk.** Email submission occurs before the state transaction. A message may be accepted even if later state/monitoring work fails. The inspected current send path does not write a durable per-recipient delivery log. If product requires confirmed delivery or recipient access, the current application has no authoritative record.

**Cardinality and duplicate risk.** The current send path requires DRAFT and transitions it, making successful send effectively once per plan. Link copy can happen repeatedly and must not drive this backend event.

**Privacy.** Exclude contact identities, addresses, tokens, URLs, plan/stream IDs, and exact recipient counts. A coarse recipient-count bucket would require explicit privacy approval.

### 11. `trip_completed`

**Canonical route-backed execution path.** `checkInFloatPlan` at `api/v1/floatplan.cfc:5041-5215` validates the current plan and monitoring state and calls `RouteProgressService.markCompletionFromFloatPlanCheckin`. `includes/RouteProgressService.cfc:190-330` blocks closure unless the final leg is already complete or active; when active, it marks that leg complete. The enclosing transaction writes `floatplans.status=CLOSED`, `checkedInAt`, and `closedAt`, then closes monitoring. A failure in a required close step aborts the transaction.

**Basic execution path.** `closeBasicFloatPlan` at `api/v1/floatplan.cfc:6970-7045` closes an active Basic plan and its monitoring in a transaction.

**Authoritative firing point.** Emit after the close transaction commits all required state. A final-leg check-in that is blocked, a page view, or monitoring lateness is not completion.

**Cardinality and duplicate risk.** Count once on the first non-CLOSED-to-CLOSED transition. Monitoring close is already idempotent; `api/v1/monitor.cfc:770-830` treats an already closed plan as closed without recreating the transition. No production reopen path was found.

**Existing test evidence.** `tests/integration/RouteProgressCloseGatingSpec.cfc:15-115` proves closure is blocked without final-leg eligibility and succeeds when the final leg is active. `tests/integration/FloatPlanLifecycleContractSpec.cfc:49-193` covers closed-history preservation and monitoring gating.

**Privacy.** Permit coarse plan type/completion method only. Exclude positions, notes, itinerary, timestamps that expose travel, route/plan IDs, contact data, and monitoring details.

### 12. `purchase`

**Canonical execution path.** `api/v1/stripeWebhook.cfc:1-83` reads the raw webhook, verifies its signature, requires an event ID, and passes only verified events to `StripeEntitlementService.processVerifiedEvent`. `includes/StripeEntitlementService.cfc:10-52` registers/deduplicates and dispatches events; lines 57-84 select supported event types; lines 86-121 process completed checkout; lines 140-178 process subscription state; lines 200-222 process successful invoice payment; lines 243-313 upsert Stripe-backed entitlement state; and lines 426-511 register and finalize webhook processing.

**Authoritative paid boundaries.**

- Subscription: a verified `invoice.payment_succeeded` for a known FPW subscription, followed by successful active-entitlement upsert.
- One-time three-day pass: a verified `checkout.session.completed` whose payment status is paid, followed by successful entitlement creation.

A completed subscription checkout maps the customer/subscription but intentionally does not prove paid Premium access. Trialing subscription state can grant trial entitlement but is not a paid purchase. Checkout-session creation, success-page return, promo redemption, founder/lifetime entitlement, administrative grant, failed invoice, cancellation, and refund are not `purchase`.

**Cardinality and duplicate risk.** The schema has a unique webhook event ID, and duplicate delivery short-circuits. The purchase entity should be the successful payment transaction. Internal invoice/payment identity should protect against semantically duplicate events, but no Stripe identifier may be exported.

**Transaction risk.** Webhook registration, entitlement mutation, and final processed marker are not one encompassing database transaction. Future analytics must never change webhook success/failure. A durable outbox written with the entitlement mutation would be the strongest delivery design, but it would require separately approved schema work; a direct call would need a post-success, isolated failure path.

**Existing test evidence.** `tests/integration/StripePremiumFoundationSpec.cfc:15-174` covers duplicate delivery, checkout mapping without Premium grant, active/trialing subscription states, invoice success/failure, and cancellation behavior. Lines 243-252 specifically assert that checkout completion or a success URL alone does not grant Premium.

**Privacy.** Exclude Stripe customer, subscription, checkout, invoice, payment-intent and event identifiers; prices if disallowed by policy; user and entitlement IDs; raw webhook bodies; signatures; billing details; and authentication/configuration values.

## Cross-Cutting Findings

### Existing analytics are not backend authority

`includes/analytics_ga4.cfm:1-25` blocks FPW application paths and limits loading to production public pages. Lines 27-39 expose a browser `track` wrapper only when client analytics is available. `assets/js/fpw-conversion-landing.js:43-78` tracks marketing interactions and tagged clicks through `gtag`/data layer. These signals can describe public-site interaction, but they cannot prove account, route, plan, monitoring, or payment state.

`Application.cfc:54-116` establishes shared request context and administrative protections, while `Application.cfc:120-130` performs administrative audit work. There is no existing funnel-event dispatcher in the common request lifecycle.

### Transaction boundaries and failure isolation

- Emit only after the database boundary that proves the event.
- Analytics failure must never roll back signup, authentication, CRUD, route generation, plan save, monitoring, trip close, or entitlement work.
- For non-transactional creation endpoints, emit after a confirmed generated ID and before returning success, inside an isolated non-fatal path.
- For transactional lifecycle events, emit after commit. Do not emit inside a transaction if a later statement can roll it back.
- Stripe processing needs stronger delivery semantics than routine events. A durable outbox is preferred if schema work is separately approved; otherwise use the verified post-entitlement success boundary and do not alter the webhook response on analytics failure.
- Email sharing has an unavoidable split boundary today: external email submission occurs before the plan/monitoring commit. “Accepted for send” and “share operation fully succeeded” are therefore different facts.

### Timestamp authority

Creation/login/route code often uses server-local `NOW()` or CFML `now()`; monitoring, trip close, and entitlement code commonly uses `UTC_TIMESTAMP()` or UTC-specific fields. Analytics timestamps should be generated server-side in UTC at the authoritative transition and should not use browser time. A single convention must be selected before implementation and verified against retry behavior.

### Alternate code paths

- Vessel creation has member and admin paths.
- Route building has custom persisted routes, template preview/generation, update/reverse, and route-to-float-plan build paths.
- Float plans have Basic, general/Premium, and route-builder creation paths.
- Activation differs between scheduled plan activation and route-backed operational start; Basic plans lack route-instance start state.
- Sharing can mean email submission, token generation, clipboard copy, invitation, delivery, or first recipient access; only email submission currently has a backend workflow tied to plan state.
- Completion has route-gated and Basic close paths.
- Purchase has subscription invoice, one-time paid checkout, subscription state, and non-purchase entitlement sources.

### Idempotency

A frontend-only event is insufficient for authoritative deduplication. Use internal entity/transition keys and keep them out of analytics payloads. Strong existing guards include the unique webhook event ID, `user_routes(user_id, route_name)`, route-instance start state, DRAFT-to-ACTIVE send gating, and non-CLOSED-to-CLOSED completion. Weaker areas include application-only signup email checks, vessel/contact duplicates, and route/plan rebuild semantics.

### Privacy exclusions

The analytics contract should explicitly deny:

- Names, email addresses, phone numbers, postal addresses, and free text.
- Vessel names, registration/documentation numbers, radio identifiers, equipment, hailing ports, dimensions, and operator details.
- Shore-contact and passenger details.
- Waypoints, coordinates, routes, itinerary details, travel notes, exact departure/return/check-in data, and monitoring state that could expose location.
- Database IDs of any kind, including user, vessel, contact, route, route-instance, float-plan, stream, follower, entitlement, redemption, and monitoring IDs.
- Route codes, float-plan IDs, share/follow/reset/verification/CSRF tokens, and generated URLs.
- Stripe customer, subscription, checkout, invoice, payment-intent, and event identifiers.
- Request bodies, webhook bodies, authentication values, password material, signatures, cookies, and session data.

Use only allow-listed, coarse enumerations documented for each event. Do not serialize application objects or forward endpoint payloads.

## Recommended Implementation Order

The order below follows the requested funnel sequence. Where a definition is blocked, skip implementation until the named decision/state exists; do not invent a fallback event.

1. **`sign_up`** — safest first implementation because one endpoint owns account insertion. Confirm duplicate strategy and isolate emission from the optional welcome email.
2. **`email_verified`** — blocked. Implement only after a canonical verification workflow and state transition are approved.
3. **`login`** — implement after deciding “every successful authentication” versus “new session.”
4. **`vessel_created`** — add to member create; include admin create only if product approves that funnel population.
5. **`shore_contact_created`** — add only to the insert branch.
6. **`route_started`** — blocked on a cross-builder definition. Do not use route-instance operational start.
7. **`route_completed`** — use first generation commit only if product approves generation as builder completion.
8. **`float_plan_created`** — approve draft-persisted semantics and route rebuild behavior first.
9. **`trip_activated`** — implement route-backed operational start after commit; decide Basic equivalence separately.
10. **`trip_shared`** — approve “email accepted and operation succeeded” or add the durable share state required by another definition.
11. **`trip_completed`** — implement after the close transaction across both route-backed and Basic paths.
12. **`purchase`** — implement last, with webhook-level idempotency, paid-only semantics, failure isolation, and first-purchase-versus-renewal policy explicitly approved.

Within each step, add targeted contract coverage before enabling transport to GA4 or another destination. Do not couple event emission to the success response until a failure-isolated delivery design exists.

## Product Decisions Required

1. **`email_verified`:** Is email verification a required account lifecycle state? If yes, approve the canonical verified state, token purpose/expiry/reuse behavior, and separately scoped persistence/API work.
2. **`login`:** Does the funnel count every successful password authentication or only a newly established session?
3. **`vessel_created`:** Are administrative creations included, excluded, or reported as a separate source?
4. **`shore_contact_created`:** Does each persisted duplicate contact count as a creation, or is a non-PII canonical deduplication rule required?
5. **`route_started`:** Is this first persisted custom-route intent, first preview/generation request, or a new cross-builder lifecycle state?
6. **`route_completed`:** Is successful first route generation the completion boundary, or is a later explicit user action/state required?
7. **`float_plan_created`:** Does creation mean persisted DRAFT or a later ready/finalized plan? How should route-plan rebuild replacement count?
8. **`trip_activated`:** For Basic plans, is successful send/monitoring activation equivalent to operational trip start?
9. **`trip_shared`:** Does shared mean server-accepted email, confirmed delivery, link copy, invitation persistence, or first recipient access?
10. **`purchase`:** Is GA4 `purchase` emitted for the first paid conversion only or for every successful renewal? Confirm the one-time pass treatment and any allowed value/currency metadata.
11. **All events:** Approve a strict metadata allow-list, server-UTC timestamp convention, internal idempotency store/strategy, retry policy, retention, consent behavior, and analytics failure policy before implementation.

## Test Matrix

No tests were executed during this discovery because the request prohibits database writes and the relevant integration suites create/modify fixture rows. The following matrix is the targeted validation plan for later, approved instrumentation work.

| Event | Positive Test | Duplicate / Retry Test | Negative / Alternate-Path Test | Privacy Assertion |
|---|---|---|---|---|
| `sign_up` | Successful persisted Basic account emits once after insert | Retry/concurrent same normalized email does not double-count one account | Validation failure, duplicate rejection, address failure policy, and welcome-email failure do not emit incorrectly | Payload contains no form values, email, name, phone, address, user ID, password, request, or session data |
| `email_verified` | Valid unexpired token atomically transitions to verified and emits once | Reused link returns verified without another event | Invalid/expired/wrong-purpose token, welcome email, login, and password reset do not emit | No email or token |
| `login` | Successful password verification plus session creation emits once per approved semantic unit | Retried response/request follows approved request/session deduplication | Wrong password, unknown email, locked/disabled policy, and existing-session page view do not emit | No credential, email, user ID, cookie, session, IP, or request body |
| `vessel_created` | Member create emits once; admin path follows approved inclusion policy | Response retry/update/default change does not repeat | Invalid insert and update do not emit | No vessel/operator fields or IDs |
| `shore_contact_created` | Premium member insert emits once | Update/retry behavior follows entity insert result | Basic gate, validation failure, update, and delete do not emit | No contact identity, phone, email, relationship, or IDs |
| `route_started` | Approved first persisted start path emits once | Same-name restore/reactivation and retry do not repeat | Preview/page load/template path follows approved definition; trip operational start does not emit this event | No names, waypoints, coordinates, dates, route codes/JSON, or IDs |
| `route_completed` | First successful generation commit emits once | Update/reverse/rebuild/retry does not repeat for same completion entity | Preview, validation failure, rolled-back leg persistence, and trip completion do not emit | Only approved coarse source/type fields |
| `float_plan_created` | New Basic, general/Premium, and route-backed inserts emit according to approved semantics | Update/reuse/rebuild replacement follows explicit counting rule | Validation failure, transaction rollback, preview, and load do not emit | No plan/vessel/contact/passenger/route/travel fields or IDs |
| `trip_activated` | First route-backed ON_TRACK check-in commits instance/leg start and emits once | Second check-in, reload, and retried response do not repeat | Scheduled send, Active Cruise/Follow bootstrap, unsupported pre-departure status, and failed monitoring start do not emit | No positions, notes, exact travel times, route/plan IDs, or monitoring payload |
| `trip_shared` | Approved successful send boundary with at least one recipient emits once | Repeated token generation/copy and endpoint retry do not repeat | No contacts, mail failure, monitoring rollback, token creation, copy, page view, and demo paths do not emit | No contact details, tokens, URLs, stream/plan IDs, or exact count unless approved |
| `trip_completed` | Route final-leg eligible close and Basic close each emit once after commit | Already-CLOSED close/retry does not repeat | Blocked final leg, monitoring-close failure/rollback, lateness/escalation, and page view do not emit | No route, location, notes, monitoring payload, travel timestamps, or IDs |
| `purchase` | Verified known-subscription paid invoice and verified paid one-time checkout emit per approved charge semantics | Duplicate webhook event and semantic payment retry emit once | Invalid signature, checkout creation/success URL, unpaid checkout, trialing state, unknown mapping, failed invoice, promo, lifetime/admin entitlement, cancellation, and refund do not emit purchase | No raw webhook, billing/customer data, Stripe IDs, user/entitlement IDs, secrets, signatures, or auth/config values |

Static validation for this report should confirm that this documentation file is the only task-created file, all database inspection was read-only, all mappings cite code/schema evidence, no secret/private value appears in the report, and `git diff --check` succeeds.

