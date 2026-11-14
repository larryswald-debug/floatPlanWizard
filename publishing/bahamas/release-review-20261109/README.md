# Bahamas release-readiness review — November 9, 2026

Start with the [owner decision and requirement matrix](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/publishing/bahamas/release-review-20261109/OWNER-REVIEW.md), then [screenshots and PDFs](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/publishing/bahamas/release-review-20261109/EVIDENCE.md). Exact source/test/asset edits are in [changed-files.json](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/publishing/bahamas/release-review-20261109/changed-files.json); deployment and rollback steps are in [deployment-checklist.json](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/publishing/bahamas/release-review-20261109/deployment-checklist.json).

The candidate is ready for owner review. It remains unpublished. The approved local CLOB setting correction passed long-snapshot and regression checks; the official PDF template remains unchanged at the owner’s direction. See the owner report for source, runtime, delivery and production limitations.

## Public content and publication review

The active guide remains a release preview: manifest status `draft`, `publication_ready:false`, no import control, noindex and no-store. The shared navigation, guide index and sitemap have not been changed.

The best release candidate is the complete personal-copy workflow with both movement mileages initially unset. The guide now explains exactly how members measure their intended water path, enter each estimate and method, record review, and retain an incomplete planning draft. The separately illustrated 60 nm legs never become route data. The safer manual-only guide would omit automatic import, but it does not satisfy the adopted release requirement.

## Review artifacts

- `content-source-asset-review.json`: item-by-item content/visual/source decisions, verification limits and exact touched files.
- `../assets.json`: file-specific photograph authors, dates, source revisions, CC BY-SA 4.0 links, dimensions, byte counts and SHA-256 hashes; Natural Earth data provenance.
- `publication-after-approval.patch`: exact future publication/nav/index/sitemap patch. **Not applied.**

## Publication patch

Only after the owner explicitly approves publication and the root release/deployment checks are satisfied:

1. Re-read the current manifest/source limits and owner report. Resolve or consciously accept the documented checklist-only Customs/CBP boundaries; do not invent missing mileage.
2. Check the patch against the exact release checkout with `git apply --check publishing/bahamas/release-review-20261109/publication-after-approval.patch`.
3. Review the four-file patch: manifest status+readiness flag; guide index title/description/visible card/ItemList; Explore card+active state; exactly two canonical sitemap URLs.
4. Applying the patch is a separate authorized action. It enables the existing CTA and indexing branch through the manifest. It does not deploy, migrate a database, alter robot policies, enable vendor events or modify production configuration.
5. In the deployment environment, verify clean 200 and single-hop index aliases, canonical agreement, private source denial, anonymous/authenticated import, null-draft save/reopen and guarded Float Plan progression before release is called complete.

The new sitemap entries omit `lastmod` rather than inventing a future publication date. Existing index dates are preserved. Confirm the index/nav layout at 390/768/1440 after applying the future patch; the active preview intentionally cannot prove that new navigation layout.

## Sources and rights

Brown’s is a candidate **marina destination reference**, with original source notation and unstated datum/revision retained. PE is NOAA’s rounded maritime reference, excluding Florida berth movements. No additional offshore waypoint is required merely to complete the model.

The two local photographs are historical context: Port Everglades PIO (December 17, 2017) for staging/traffic research, and Pietro’s Alice Town waterfront (August 17, 2014) for local days. Each visible caption supplies source, creator, date, license and proportional-resize/no-crop disclosure. Neither identifies current approach, berth, fuel availability or safety.

Natural Earth country geometry is now 1:10m rather than 1:110m; minor-island shapes are retained. The source download hash and clipping/reduction method are in assets.json. The checked-in context GeoJSON lets `build-assets.mjs` rebuild all four SVGs offline with Node built-ins. No tiles, paid provider or proprietary chart data are included.

## Local evidence limits

MCPCF confirmed both pages 200 with noindex/no-store and denied the private patch 403. Isolated Playwright confirmed one H1, matching canonical/schema, no missing section anchors and no import control on either page. The paginated hub (9 pages) and itinerary (11 pages) PDFs were visually checked for figure/table fit, estimate/provenance labels and readable photo captions. Frontend supplies the final multi-width screenshots and interaction checks. Public print PDF paths and visual evidence are recorded in the JSON. Production/CDN/cache/WAF/crawler verification is separate.


