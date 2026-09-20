# Boat Loan and Ownership Cost Calculator — local implementation handoff

September 19, 2026. Implemented against the user's pasted version 1.0 specification, with subsequent sticky-results, CTA, shared-navigation and development-routing updates. **Local implementation complete; not deployed.** This handoff summarizes earlier implementation and verification records; updating this document does not constitute a fresh test run. Production hosting and the manual checks below remain unverified, so this report does not claim production release readiness.

## Behavior

The public calculator supports price and reverse-budget directions, financed/cash purchases, Quick/Detailed presentation, itemized fuel/storage/preparation, separate repair savings, amortization, five/ten-year projections, optional resale, three isolated scenarios, browser save/restore/deletion, fragment sharing and browser printing. It starts with empty financial assumptions. All three illustrative examples come from the production calculation engine. No accounts, paid APIs, new database tables, write endpoints or framework dependencies were introduced.

Local preview: http://127.0.0.1:8500/fpw/boat-loan-calculator/

Desktop results use native sticky positioning inside the full-height right column. The measured inset is `min(header obstruction + 16, viewport height - 16 - panel height)`: short cards stay below the header, while tall cards scroll until their bottom is 16px above the viewport bottom. The card remains contained by the calculator grid and moves away before full-width comparison/education content. Border-box ResizeObservers handle panel/header changes without a scroll handler; a scoped focus helper reveals obscured results controls and expanded disclosures. Widths at or below 950px and print retain normal document flow. No independent results scrollbar was added.

Three promotional placements are present: a Trip Planner card after the results summary (also shown for empty/incomplete/invalid results), an inline Fuel Calculator link after the fuel explanation, and a closing Trip Planner CTA after the FAQ. The old bottom-of-results promotional pair was replaced; Save/Share/Print remain grouped. Promotional content is excluded from print, and no calculator figures are transferred to the destinations.

## Source findings and integration

- The existing public fuel page is `boat-fuel-calculator/boat-fuel-calculator.cfm`. It directly includes the shared analytics helper, public navigation and footer; its calculations remain unchanged.
- The general shared-head chain is `includes/header_styles.cfm` → `includes/html_head.cfm` → `includes/analytics_ga4.cfm`, with Clarity included by `html_head.cfm`. Direct public includes are an alternate path. All those shared files remain unchanged.
- The new page explicitly establishes `request.fpwBase` before using `includes/top_nav.cfm` and `includes/footer.cfm`, preserving `/fpw` local mounting and production root links. It reuses existing layout/navigation styles and the existing social preview asset.
- The existing fuel calculator and lock-detail CTAs send signed-out visitors to `app/join.cfm`, signed-in visitors to `app/dashboard.cfm`. The dashboard uses `includes/require_auth.cfm` and hosts Route Builder. No supported boat-cost field-transfer contract was found. The new CTA follows those destinations and discloses the account requirement and absence of transfer.
- `/boat-loan-calculator/` maps to `boat-loan-calculator/index.cfm`. The repository's three feature-local IIS `web.config` rules handle slash canonicalization, original `index.cfm` request canonicalization and internal rewriting. They were already sufficient when shared navigation was added. The canonical host is `https://floatplanwizard.com`; IIS runtime remains unverified.
- Existing sitemap mechanism: root `sitemap.xml`. One canonical entry was added, along with contextual links from the fuel calculator and How It Works.
- Shared desktop/mobile navigation now lists **Fuel Calculator → Boat Loan & Ownership Calculator → Marine Weather** under Resources → Planning Tools. The new row uses the existing application-base helper, outline SVG system and selected-page treatment. Its description is “Estimate loan payments and the ongoing cost of owning a boat.” A measured desktop menu-height constraint keeps bottom rows reachable; mobile retains its existing scrollable drawer. Existing navigation analytics and destinations are preserved.

## Files

Existing application integration files changed:

| File | Change |
|---|---|
| `boat-fuel-calculator/boat-fuel-calculator.cfm` | One contextual calculator link |
| `how-it-works.cfm` | One contextual link paragraph |
| `sitemap.xml` | One canonical URL entry |
| `web.config` | Three feature-specific canonical/rewrite rules |
| `includes/top_nav.cfm` | One shared calculator row/icon, active-route refinement and measured Resources menu height |
| `assets/css/top-nav.css` | Desktop Resources content overflow constraint; existing mobile presentation retained |

New runtime files:

- `boat-loan-calculator/index.cfm`: public page, metadata, JSON-LD, education, page-local tracker guards and links.
- `boat-loan-calculator/examples.cfm`: checked-in, generated crawlable assumptions/results.
- `assets/js/boat-cost-engine.js`: versioned raw contract, independent validation, cents normalization, amortization, forward and reverse models, examples and deterministic insights.
- `assets/js/boat-cost-state.js`: strict compact share codec, browser persistence and enumerated event adapter, including CTA placement/destination allowlists.
- `assets/js/boat-cost-ui.js`: DOM interface, results/comparisons, save/share/print behavior, imported-state handling, sticky measurement/focus support and delegated CTA events.
- `assets/js/boat-cost-bootstrap.js`: synchronous URL capture/scrubbing and guarded shared analytics bridge.
- `assets/js/boat-cost-analytics.js`: page-local sanitized Plausible initialization.
- `assets/css/boat-cost.css`: scoped nautical styling, responsive layout, sticky results, CTA styling and print rules.

Build/test files include `scripts/generate-boat-cost-examples.cjs`, the `tests/boat-cost*` engine/state/integration/browser/privacy suites, `tests/boat-cost-clean-route.spec.js`, the updated `tests/public-resources-nav.test.mjs` and `tests/public-resources-nav.spec.js`, and this handoff. The route regression checks assert calculator content as well as HTTP status, canonical redirects, query preservation, assets, navigation and existing clean-route behavior. Node is used only for development/testing/generating the checked-in example HTML; ColdFusion hosting needs no Node runtime.

Generated `output/playwright/` screenshots, PDFs, JSON evidence and local verification scripts remain local/ignored, as do `.codex-snapshots/` backups. They are not repository or deployment assets; evidence links below are available only on a workspace retaining those outputs.

## Development routing and repository boundary

The application Git root is `wwwroot/fpw`. Development Dockerfiles, `docker-compose.yml`, and `config/tomcat/` live in the containing development project, outside that Git root, and remain local. Do not copy runtime rules, startup wrappers, image snapshots or server settings into the public webroot to include them in the application commit.

From the development project root (`/Users/larrywald/Docker/cf-mysql-dev` on this machine), `config/tomcat/rewrite.config` is mounted read-only at `/opt/coldfusion/cfusion/runtime/conf/Catalina/localhost/rewrite.config`. `config/tomcat/start-with-rewrites.sh` is mounted at `/opt/fpw-dev/start-with-rewrites.sh`; the `coldfusion` Compose service invokes it with `command: ["start"]`. The wrapper enables exactly one Host-level Tomcat RewriteValve and delegates to Adobe's normal startup script. Rules and activation survive service recreation; existing rules, mounts, data volumes and unrelated services are retained.

The current local rules serve `/fpw/boat-loan-calculator/` as the public CFM calculator with HTTP 200. No-slash and original explicit `index.cfm` requests receive one HTTP 301 to the friendly URL; the original-request guard prevents internal rewrite loops. Host, port and encoded/repeated query parameters survive HTTP routing. The calculator's intentional JavaScript query scrubbing before analytics remains separate and unchanged. Existing Fuel Calculator and How It Works clean routes also passed the later route checks; earlier directory-listing/302/404 observations predated this setup and are superseded.

See the external [Tomcat setup notes](../../../config/tomcat/README.md) for portable mount paths, prerequisites, preserved-image details, rollback and the normal apply command: `docker compose up -d --no-deps --no-build --pull never --force-recreate coldfusion`, run from the development project root. Those local setup files are not part of the application Git commit. Production continues using this repository's root-level IIS `web.config`, without the development `/fpw` prefix or Tomcat syntax.

## Arithmetic and state decisions

Input money is validated as decimal dollars and normalized to integer cents. Percentage-derived amounts and annualized rows round half-up once. Loan amortization retains full precision, handles zero/subnormal positive rates, caps payments at payoff and clears final residue. The UI includes a display-only rounding adjustment when independently rounded monthly rows differ from the headline (Fixture B: +$0.01).

Purchase cash, financed extras, preparation, recurring expenses and reserve allocations are separate. Unknown, explicitly entered zero, illustrative and excluded values remain distinct. The engine returns independent readiness flags rather than promoting partial sums to a complete ownership estimate. Invalid/incomplete edits stale an existing result; sharing and printing of that result are disabled. Native browser printing also suppresses stale figures.

The reverse solver searches whole cents, holds operating/preparation/reserve assumptions fixed, calls the forward engine, checks both cash and monthly constraints, and verifies the next cent fails except at the supported maximum. Missing future financing assumptions cannot masquerade as an affordability ceiling.

Raw scenario schema version is 1; example configuration is `2026-09-19.v1`. Monetary/profile bounds and imported structure are validated independently of the DOM. State is a bounded US-state/DC enum; labels are local-only plain text. Quick/Detailed keeps assumptions; changing populated units requires confirmation. Active grouped/detail bases never count twice.

## Privacy and analytics

Only this page sets the existing request-scoped rendered guards to suppress automatic GA4/Plausible initialization. Clarity and TrustedSite are not included here. The existing `FPWAnalytics.track` helper contract is retained with a page-local implementation; unchanged pages retain their original tracking behavior.

The first executable script captures a fragment in memory and removes both query and fragment before tracking. UI import validates the entire scenario before applying it, clears captured state, and handles later same-document links. URL cleanup failure disables sharing and tracking. The HTTP/meta referrer policy is `no-referrer`.

This page uses the site's existing Plausible property. Automatic pageviews, form, outbound-link, download and hash collection are disabled; a manual canonical pageview and enumerated `boat_cost_*` events are permitted. A request transform reconstructs the allowed event payload with canonical URL and null referrer. Unknown events, amounts and free text are discarded. Event names follow the specification; permitted parameters are calculator version, direction, view, purchase mode, completeness, origin, scenario count, destination, placement and coarse error code. Calculation events occur only after explicit calculation. Sharing events require fulfilled clipboard copy; printing counts opening the dialog, not PDF completion. No new sitewide consent behavior was added; `plausible_ignore`, Do Not Track and Global Privacy Control are honored on this page. No cookie-based GA events are emitted here.

The three promotional anchors emit `boat_cost_cta` through the existing privacy-aware helper with only calculator version, fixed `placement` and fixed `destination`. One delegated listener survives results rerenders without adding duplicate handlers:

| Placement | Destination metadata | Existing link flow |
|---|---|---|
| `right_results` | `trip_planner` | Anonymous `app/join.cfm`; signed-in `app/dashboard.cfm` |
| `fuel_help` | `fuel_calculator` | Existing `boat-fuel-calculator/boat-fuel-calculator.cfm` link; normal server canonicalization applies |
| `after_faq` | `trip_planner` | Same session-aware planner destination and account/no-transfer disclosure |

Saving is explicit under `fpw.boatCost.v1`, maximum three scenarios, 180-day expiry, never computed results. Delete/expiry touch only that key. Sharing includes only the active allowlisted scenario in a URL fragment, omits labels, preserves statuses and rejects oversize links (4,096 characters) or decoded payloads (8 KiB). It has no backend or short-link service.

Sharing was enabled only after network inspection passed on all three installed browser engines. The tests use the actual downloaded Plausible script with every outgoing analytics POST captured and fulfilled locally; no test analytics were submitted to production. Tested script SHA256: `c915560ef263278925e96ae46ada86e61f14b522736ede4338b3dbd04d99a387`. Its engagement events reuse sanitized pageview URL/props; they were also inspected. Re-run the network gate if tracker code/configuration changes.

Reference for the page-local transport controls: https://plausible.io/docs/script-extensions . Financial terminology was checked against the linked CFPB interest-rate/APR explanation; the page does not offer live rates, quotes, tax advice or lender recommendations.

## Verification

Run commands from the repository root. Use the explicit Playwright output directories: the repository already tracks older files under default `test-results`, and the runner clears its selected output directory.

```sh
node --test tests/boat-cost-engine.test.mjs tests/boat-cost-state.test.mjs tests/boat-cost-integration.test.mjs tests/public-resources-nav.test.mjs
node scripts/generate-boat-cost-examples.cjs --check
npx playwright test tests/boat-cost.spec.js --workers=1 --reporter=line --output=.codex-snapshots/boat-cost-20260919/browser-results
FPW_PLAUSIBLE_SCRIPT=/tmp/fpw-boat-cost-plausible.js npx playwright test tests/boat-cost-privacy.spec.js --browser=all --workers=1 --reporter=line --output=.codex-snapshots/boat-cost-20260919/privacy-results
npx playwright test tests/boat-fuel-range.spec.js --grep 'standard range|One-Third Rule|decimal, missing' --workers=1 --reporter=line --output=.codex-snapshots/boat-cost-20260919/fuel-results
npx playwright test tests/boat-cost-clean-route.spec.js tests/public-resources-nav.spec.js --grep-invert 'public Resources navigation fits|dropdown exclusivity' --browser=all --workers=1 --reporter=line --output=output/playwright/calculator-navigation/regression
git diff --check
```

If the temporary Plausible snapshot is unavailable, omit `FPW_PLAUSIBLE_SCRIPT`; the privacy suite fetches the current real script and still intercepts all event submissions. Recheck its hash when comparing runs.

Repository check-in checks (September 19, 2026): 66 Node checks passed (38 engine, 12 state, 5 feature integration and 11 navigation); generated examples matched `--check`. The generator now creates its backup directory when needed, and regeneration was checked in an isolated fixture without an existing `.codex-snapshots/` directory. Current feature scripts/CSS total **37,555 bytes gzip (36.67 KiB)** using the integration test's Node `zlib.gzipSync` calculation, below 50 KiB.

Initial calculator verification results (historical, before the later sticky/CTA/navigation updates):

- 65 Node tests passed: 38 engine tests, 12 state tests, 5 feature integration tests, 10 existing public-navigation source tests.
- 11 calculator browser checks passed, including explicit confirmation, stale native-print suppression, three-scenario isolation, reverse financing/cash, browser storage, no-JavaScript content and screenshots.
- 18 privacy/browser tests passed across Chromium, Firefox and WebKit.
- 3 existing fuel calculation regression checks passed (range, One-Third Rule, decimal/missing/invalid/reset cases).
- Generated static examples match the production engine. New JavaScript syntax checks and `git diff --check` passed. `web.config` and `sitemap.xml` parse as XML.
- Local ColdFusion returned HTTP 200 for the new clean route, existing fuel route and `how-it-works.cfm`. Signed-out CTA targets and dashboard's authentication gate were checked without credentials.
- The initial feature asset budget check passed; the current byte count is recorded above. Calculation itself makes no request; explicit analytics actions send only permitted events.
- Installed browser engines: Chromium 143.0.7499.4, Firefox 144.0.2, WebKit 26.0. These are the available bundled engines, not a claim that native current Safari or iOS was exercised.
- 320 CSS-pixel width and 720 CSS-pixel reflow (equivalent layout width for a 1440-pixel window at 200% browser zoom) passed without whole-page horizontal overflow. CSS body zoom is not browser zoom and was not used to claim native zoom coverage. Input labels, keyboard movement, linked error focus and accessible table scroll regions were checked; live updates are restrained. Measured contrast ratios for main text, muted help text, the primary button and focus outline are 15.18:1, 9.39:1, 9.19:1 and 12.41:1 respectively. Keyboard focus is preserved when selectors rebuild form controls. No formal WCAG certification or screen-reader audit is claimed.
- Browser-generated Letter and A4 samples are three readable pages including all assumptions. Rendered pages were visually inspected; extracted text boxes remain inside page margins, with no blank pages or clipped content. Expanded amortization, navigation and controls are omitted. This is browser print evidence, not a new PDF service.

Later September 19 verification records (historical; not fresh browser reruns for this handoff refresh):

- Sticky results: 714 focused assertions passed across Chromium, Firefox and WebKit. Tests covered short/tall cards at 1280×720 and 1440×900, both scroll directions, the sticking threshold, middle and section end, expanded results, scenario/validation changes, dynamic header size, keyboard access, responsive reflow and print lifecycle. Tall-panel bottoms measured 16px above the viewport bottom. Existing 55 Node and 10 calculator browser regressions also passed.
- CTA additions: 247 focused UI assertions and 708 sticky assertions passed across the three engines; 55 Node, 10 calculator browser and 6 privacy regressions passed. Forty-five intercepted clicks across five UI states emitted one event each with only fixed placement/destination metadata and calculator version. Opt-out, Do Not Track and Global Privacy Control suppressed tracking; financial inputs, labels and share fragments were absent from inspected requests. The three promotional placements were absent from print.
- Shared navigation and durable routing: all 33 selected runtime checks passed across Chromium, Firefox and WebKit after service recreation (32 in the combined run and the remaining WebKit check on targeted rerun). Checks covered actual public calculator content, one-hop HTTP 301 normalization, original-request guards, encoded/repeated queries, both loopback hostnames/port 8500, asset loading, a $1,418.64 example result, and existing Fuel Calculator/How It Works clean routes. The shared header was checked on the homepage, calculator and Shore Contact Guide at 1280×720, 1440×900, 390×844 and 640×360, including order/copy, selected state, wrapping, keyboard reachability of the bottom row and Escape. Activation and routes survived a second ColdFusion service recreation; unrelated service container IDs and data volumes were retained.
- WebKit on macOS used Option+Tab to include links under its keyboard preference; no browser preference or production navigation code was changed for testing. The 640×360 navigation viewport is equivalent layout reflow for 200% zoom at 1280×720, not actual browser UI zoom. Native Safari, native print preview and actual browser zoom were not exercised because UI permissions were unavailable.

Local evidence summaries: [sticky results](../output/playwright/boat-cost-sticky/README.md), [CTA placements and analytics](../output/playwright/boat-cost-cta/README.md), and [navigation screenshots](../output/playwright/calculator-navigation/). These records describe their respective historical state: the CTA summary's directory-listing workaround preceded the later Tomcat rewrite setup. Current routing is documented above and in the external Tomcat notes.

Initial local evidence (ignored artifacts, not included in a fresh checkout):

- [Desktop](../output/playwright/boat-cost/desktop.png)
- [320px mobile results](../output/playwright/boat-cost/mobile.png)
- [Print screenshot](../output/playwright/boat-cost/print.png)
- [Letter PDF](../output/playwright/boat-cost/print-letter.pdf)
- [A4 PDF](../output/playwright/boat-cost/print-a4.pdf)

An additional existing suite, `node --test tests/public-pdf-sitemap.test.mjs`, returned 1 pass / 2 failures. Its hard-coded expected downloads omit six existing emergency PDFs, and its robots expectation differs from the existing `robots.txt`. Neither failure depends on the new non-PDF sitemap entry; downloads and robots are unchanged. These unrelated failures were not repaired.

The full existing public-navigation browser suite also has two stale expectations: title-case rendered “Boating Safety” despite the existing uppercase CSS treatment, and an old tab order placing Common Emergencies between the two guide links. They were left unchanged. The focused route/navigation command above excludes only those two tests; active-state, analytics and destination checks remain included.

## Requirement-to-test mapping

| Acceptance IDs | Evidence |
|---|---|
| AC01–03 | Engine fixture A–I, principal/extras/reserve identity, zero principal/rate/hours, payoff tests |
| AC04 | Engine statuses, save/share roundtrip, screen partial labels, printed assumptions |
| AC05–06 | Reverse F/G, next-cent proof, cash/monthly shortfalls, upper bound and incomplete assumptions |
| AC07 | Quick/Detailed browser preservation and confirmed input-basis replacement/cancel checks |
| AC08 | Three-scenario clone/edit/delete/baseline browser test; invalid values suppressed |
| AC09 | State malformed/version/size/injection tests; browser initial/same-document import |
| AC10 | State expiry/key-only delete/quota tests; browser save/reload/restore/blocked storage |
| AC11–12 | 18 intercepted-network privacy tests; all event fields allowlisted, cleanup failure and opt-out tests |
| AC13 | Labels, keyboard/error focus, 320px and zoom-equivalent reflow checks; manual assistive-technology/native zoom audit remains unrun |
| AC14 | Available Chromium/Firefox/WebKit tested; native Safari/iPhone and production runtime explicitly unverified |
| AC15 | Letter/A4 rendering and text-bound checks, stale native-print guard, print screenshots |
| AC16 | Source/HTTP metadata, canonical/sitemap tests, generated examples, contextual links and no-JS browser check; production redirects unrun |
| AC17 | Existing fuel arithmetic and public-navigation regressions; verified account-entry destinations; authenticated planner unrun |
| AC18 | Diff inspection: no schema/endpoints/dependencies/production mutations or hidden market defaults |
| AC19 | Engine monotonicity, floating-point boundary, annualization, payoff and rounding properties |
| AC20 | This handoff distinguishes executed checks, legacy failures and remaining environment checks |
| Sticky results follow-up | Historical geometry, keyboard, resize and print checks; scoped CSS/measurement helper, normal mobile flow and grid containment |
| CTA follow-up | Historical placement/state/print checks and intercepted fixed-metadata events for `right_results`, `fuel_help` and `after_faq` |
| Navigation/routing follow-up | `tests/public-resources-nav*` and `tests/boat-cost-clean-route.spec.js`; historical post-recreation browser/HTTP checks; external durable Tomcat setup notes |

## Remaining release checks and limits

Production IIS/Hostek compatibility is **unverified**. The durable local Host RewriteValve setup now provides the clean calculator page, single-hop HTTP 301 canonical redirects and preserved HTTP queries, with successful Fuel Calculator and How It Works clean-route regression checks. Those Tomcat results do not verify IIS. The repository IIS XML and the existing three calculator rules were reviewed locally; no running production configuration was changed.

Before public release, verify Hostek/IIS canonical redirects and script delivery, native Safari/iPhone, actual browser UI zoom and assistive-technology behavior, authenticated dashboard navigation, and production analytics dashboard receipt under the owner's existing account settings. No credentials or production data were used. Search Console data and downstream signup/trip attribution were not accessed. No first-release capability was intentionally deferred, but these unrun environment/manual checks are not marked passed.

After release, compare Search Console impressions/clicks/CTR/query groups over comparable 28-day windows. Use complete entered calculations divided by starts as a completion signal; report illustrative usage separately. Save/share/compare are utility signals, and planner clicks are navigation signals, not signups or trips. The client events cannot establish downstream activation without existing account attribution.

## Local use, deployment and rollback

1. Use the local ColdFusion environment with the external durable Tomcat setup described above and open the local preview URL. No calculator database setup is needed. A checkout of this application repository alone does not install the external Compose/routing configuration.
2. If examples or formulas change, run `node scripts/generate-boat-cost-examples.cjs`, then the unit and relevant browser checks. Review generated example HTML in the diff.
3. For a separately authorized deployment, include the calculator runtime files (including generated examples) and the application integration changes listed above, including shared navigation/styles and the IIS rules. Deploy atomically so links do not precede the page/assets. Tests, generated verification artifacts, local backups, Docker files and Tomcat configuration are not production web assets. Do not overwrite shared analytics, authentication, billing or planning files.
4. Verify production routing, headers, privacy requests and existing fuel/planning entry points. Configure/view event reporting only through the owner's normal analytics process; this task did not mutate analytics account settings.
5. For an application rollback, review the original calculator, sticky, CTA and navigation snapshots under `.codex-snapshots/boat-cost-20260919/`, `boat-cost-sticky-20260919/`, `boat-cost-cta-20260919/` and `calculator-navigation-20260919/`. Revert only the intended feature changes, including shared navigation additions, contextual links, sitemap entry and IIS rules, before withdrawing the calculator runtime files. Do not blindly restore older whole files over later unrelated work. Development routing rollback is separate and documented in the external Tomcat notes; preserve the local runtime image and data volumes. Browser estimates use a feature-specific key and can be removed with the feature's delete action.

No push, deployment, email, production mutation, auth/billing/monitoring change or database migration was performed as part of the calculator, sticky, CTA and navigation work. Repository check-in is separate from deployment; external development configuration and generated verification artifacts remain local.
