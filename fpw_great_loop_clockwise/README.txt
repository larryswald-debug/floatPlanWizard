FPW Great Loop leg reference

Local development URL:
http://localhost:8500/fpw/fpw_great_loop_clockwise/#search

The menu and canonical URL use /fpw_great_loop_clockwise/. This clean URL serves
index.cfm internally. No index.html file exists. Explicit index.cfm, index.html,
and no-slash links redirect permanently to the clean URL. The page uses the
shared FPW base-path helper, navigation, footer, and navigation styles.
The page stylesheet is scoped to this reference so it does not change shared UI.

Live data:
- api/v1/GreatLoopReferenceService.cfc reads the active public Great Loop template
  on each request. It selects the unique default in the GREAT_LOOP_ family, or
  the sole eligible active template. Ambiguous/missing templates return a
  friendly unavailable page; there is no hardcoded itinerary fallback.
- route_template_segments supplies stored counterclockwise order.
- segment_library and ports supply regions and endpoint names using the Route
  Generator's name precedence. Consecutive regions form the displayed sections.
- route_leg_locks maps the selected template short_code and leg order to
  canonical_locks names, in seq order.
- Estimated lock time = lock_delay_model.base_cycle_min + typical_wait_min.
  Mapped lock counts take precedence over segment_library.lock_count.
- Missing mappings retain the segment count but show names/time unavailable.
  Incomplete delay models show an unavailable estimate, never a partial total.
- Lock names are searchable and expandable. Counts and estimates stay visible.
- This is read-only: no route creation, schema changes, or database writes.
- The legacy URL retains "clockwise" for link compatibility; the displayed
  counterclockwise direction follows the stored Route Generator order.

Verified development data on October 28, 2026:
GL_REUSE_V2 / GREAT_LOOP_REUSABLE_V2, 56 legs, 16 regions, 68 mapped locks,
2,265 estimated lock minutes (37 hr 45 min). These are verification results,
not constants used to render the page.

Routing and access:
- Local Tomcat: wwwroot/WEB-INF/rewrite.config
- IIS source rules: fpw/web.config (not deployed/tested on IIS).
- The clean trailing-slash URL returns 200 while internally serving index.cfm.
  Explicit index.cfm, retired index.html, and no-slash requests redirect to the
  clean URL, preserving query strings and browser fragments.
- Redirects check the original request to avoid internal rewrite loops.
- Local canonical alias checks apply to /fpw/. The separate restored /fpw_prod/
  HTML rewrite remains intact; the production mirror files were not updated.
- robots.txt allows the exact clean canonical, direct redirect aliases, and the
  directory's rendering assets. Other directory files remain blocked.
- The service exposes no remote API method and accepts no user route selector.

Validation:
- tests/specs/GreatLoopReferenceServiceSpec.cfc (synthetic, read-only live tests)
- tests/great-loop-reference-runner.cfm (localhost:8500 and confirmation guarded)
- tests/great-loop-reference-page.spec.js (live model, desktop/mobile, no-JS)
- output/playwright/great-loop-template-locks-2026-10-28/review.html

SEO (October 29, 2026):
- Canonical: https://floatplanwizard.com/fpw_great_loop_clockwise/
- Unique title and description, index/follow on successful pages, Open Graph and
  Twitter metadata, and one sitemap entry for the clean URL.
- CollectionPage, BreadcrumbList, and ItemList JSON-LD describe the page and its
  currently rendered active-template legs. Names, counts, and time summaries
  are generated from the same model as the visible cards.
- Unavailable responses retain HTTP 503, use noindex/follow, and omit JSON-LD.
- This prepares the development source for indexing after deployment. No
  production deployment or search-engine submission was performed.
- Tests: great-loop-reference-seo.test.mjs and great-loop-reference-seo.spec.js.
- Evidence: output/playwright/great-loop-clean-url-2026-10-29/review.html

Shared Cruise Timeline (October 29, 2026):
- RouteTimelineService.calculateCruiseTimeline is the single daily calculation
  path for both the authenticated generator and this public page. The existing
  generateCruiseTimeline wrapper retains ownership and effective-distance loading.
- RouteTemplatePlanningService supplies the generator's template legs and
  canonical lock details. GreatLoopReferenceService always selects the active
  public Great Loop template on the server; callers cannot supply user/route IDs,
  arbitrary legs, distances, or private member overrides.
- assets/js/app/shared/cruise-timeline-view.js and assets/css/cruise-timeline.css
  provide the common generator/public table, lock panel and daily rollups.
  The existing SharedFuelMath provides the calculation-summary formatting.
- timeline.cfm is a read-only, no-store, noindex POST handler for bounded planning
  inputs and selected template-leg lock details. It makes no persistent writes.
- The page captures the browser clock once and rounds forward to the next whole
  local hour. Exact hours remain unchanged. Manual departure changes persist.
  As explicitly approved, only its local calendar date is passed to the unchanged
  daily engine. This does not calculate clock-time departures or arrival ETAs.
- Planning defaults come from the canonical engine. Missing fuel is displayed as
  unavailable. Daily status colors are the engine's unchanged risk classifications.
- Best/Typical/Worst lock-panel values retain the generator's wait-only convention;
  timeline hours retain its base-cycle-plus-typical-wait calculation.
- Existing template order, crawlable reference cards, SEO metadata, shared
  navigation, search and region expand/collapse controls remain intact.
- Evidence: output/playwright/great-loop-shared-timeline-2026-10-29/review.html
- Snapshot: .codex-snapshots/great-loop-shared-timeline-20261029T121559-0400/
- No production modification, schema change or deployment.
