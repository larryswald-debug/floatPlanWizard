FPW Great Loop leg reference

Local development URL:
http://localhost:8500/fpw/fpw_great_loop_clockwise/index.html#search

The existing index.html URL is internally rewritten to index.cfm. The CFML page
uses the shared FPW base-path helper, navigation, footer, and navigation styles.
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
- IIS source rule: fpw/web.config (unchanged in this task; not deployed/tested on IIS)
- robots.txt continues to disallow this directory.
- The service exposes no remote API method and accepts no user route selector.

Validation:
- tests/specs/GreatLoopReferenceServiceSpec.cfc (synthetic, read-only live tests)
- tests/great-loop-reference-runner.cfm (localhost:8500 and confirmation guarded)
- tests/great-loop-reference-page.spec.js (live model, desktop/mobile, no-JS)
- output/playwright/great-loop-template-locks-2026-10-28/review.html
