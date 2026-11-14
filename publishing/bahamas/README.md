# Bahamas release and source maintenance

Implementation date: November 7, 2026. Readiness review: November 9, 2026. No production deployment is implied.

See the [November 9 release-readiness review](release-review-20261109/README.md) for current content/source/asset reconciliation, rendered evidence and the unapplied publication patch. The earlier November 7 implementation and November 9 readiness evidence remain historical; the subsequent [owner-supplied mileage update](mileage-update-20261109.json) supersedes their null-default statements.

## Source of truth
The versioned template `templates/fort-lauderdale-bimini-v1.json` supplies the public worksheet, stops, movement legs, timeline and imported personal-copy snapshot. New imports start with owner-supplied planning estimates of 50.3 NM outbound and 50.3 NM return along the same example path in reverse (100.6 NM total). The existing `source_reported_estimate` and `distance_method` fields carry “Example route distance — review for your trip.” Measurement method, chart source and date are unspecified; leg source references/dates are empty, while coordinate sources remain on stops. Every imported leg remains unreviewed. The separate 60 nm values exist only in `worksheet` (120 NM illustration) and are not imported. Existing personal snapshots and member edits are not rewritten.

The [member-attribution update](attribution-update-20261109.json) records the later edit/save/export checks. Changing a guide leg’s mileage clears its previous active source/method, references and review, and labels the new value “Member-entered estimate.” The original imported mileage and provenance remain in the source snapshot. A draft may retain the new mileage with no method; complete-trip saves require a source/method, and Float Plan creation additionally requires current member review.

Brown’s Marina replaces the earlier Big Game Club overnight candidate. Its first-party page supplies the exact original location text; datum and coordinate revision are unstated. The point is a candidate marina destination reference, not a berth reservation, offshore waypoint or reviewed approach. PE is the rounded reference in NOAA Coast Pilot 4 chapter 10, revised November 1, 2026; it is not a Florida berth. USCG current-notice retrieval returned 403. Current notices remain a member research task.

## Publication gate
Keep status `draft` and `verification.publication_ready=false` until release verification is complete. The temporary local-only published toggle used to exercise the actual anonymous CTA/auth/import path has been restored to draft. Local validation is recorded in `implementation-checks.json`. The earlier before-test manifest is historical evidence only: do not restore it over the current NOAA endpoint and embedded source-register snapshot.

Draft pages emit noindex and no-store. Bahamas remains absent from the shared navigation, Cruising Guides index and sitemap pending the release gate. Exact IIS/Tomcat clean URLs and private publishing-source deny rules are required. The pages’ private underscore includes are denied separately by IIS; retain equivalent Tomcat rules. Robots directives are not access control.

When gates pass, add only the hub and first itinerary to navigation/sitemap; set truthful publication/update dates; verify clean200, index301 once, missing404, canonical/schema and source denial in the deployed environment. Do not publish later-phase placeholders.

## Maintenance
Review regulatory and service information monthly; authority links quarterly; geography on dataset revisions. The source register records access/effective dates, retrieval limits, reviewer status and next review. A retrieved source never means safe passage, fuel availability or a confirmed berth. Resolve source conflicts rather than manufacturing a verification date. Critical failures may suspend new imports while preserving existing copies.

Natural Earth data and minor-island polygons are public domain. GeoNames geographic labels are CC BY 4.0; Eleuthera’s label was retrieved from Mapcarta, which identifies GeoNames3572435. Label coordinates never enter imported waypoints. Two historical context photographs are included as local responsive copies: Port Everglades PIO’s December 17, 2017 aerial and Pietro’s August 17, 2014 Alice Town waterfront photograph. Both file-specific Commons pages license reuse under CC BY-SA 4.0. Visible captions retain attribution, source and license links, dates and proportional-resize/no-crop disclosure; `assets.json` records dimensions, source revisions and SHA-256 hashes. Proprietary charts remain excluded.

The self-contained SVGs do not use public tile servers. Rebuild source-derived maps and the time/fuel chart from the repository root with `node publishing/bahamas/build-assets.mjs`; check the visible HTML equivalents and rendered layout after changes. `crossing-decisions.svg` is an original concept diagram, not a forecast or current compensation model.

## Later phases, not public placeholders
P2: distinct crossing, entry/return, fuel/provisioning/communications and Bimini pages, plus a separately sourced seven-knot example. Retain the current hub anchors as summaries. P3: substantive Abacos, Exumas, Berry Islands, Eleuthera and Grand Bahama pages, and a separately versioned northern Exumas example. Each needs completed source records, original assets, endpoint-specific mileage semantics and the same save/review/export contract. No shared ports/segments are seeded.

## Analytics
No new vendor events are emitted by the Bahamas page script. Establish consent enforcement before enabling the approved public metadata events. Never send private route identifiers, coordinates, custom names, dates, notes or continuation tokens to vendors. Existing required server-side product events remain separate.

## Release verification
Exercise actual anonymous sign-in and registration/Continue; signed-in import; concurrent/retried selection; owned draft edit/save/reopen; complete save retry/history; per-leg review invalidation and all float-plan boundaries; estimates in printed summaries/PDF supplements; schematic/member-plotted map distinction; Basic/Premium and nonguide regressions; keyboard and390/768/1440 layouts; production cache/routing checks. Local evidence is not production proof.

## Completed local implementation
The MySQL migration was applied and verified locally. The complete import-to-draft and complete-save workflow, current-review guards, saved map labels, planning print and actual merged float-plan PDF were exercised. Details, exact changed-file inventory and evidence paths are in `implementation-checks.json`. Nothing has been committed, pushed or deployed.

Dated source snapshots are under `.codex-snapshots/bahamas-guide-20261107/`. The compressed development database backup is outside the webroot at `/Users/lawrencewald/Docker/cf-mysql-dev/.codex-snapshots/bahamas-guide-20261107/database/fpw-before-guide-imports.sql.gz`; gzip integrity was verified. The dated source-snapshot URL, publishing sources and new guide PDF filenames are denied by the local Tomcat rules. Equivalent IIS rules are in `web.config` and require deployed verification.

The user-approved local ColdFusion container repair installed `libfreetype6`, `fontconfig` and `fonts-dejavu-core` with required dependencies, then restarted the container. This changed the running container only; no Dockerfile dependency change was made. A rebuilt container needs equivalent font support. Rendered PDFs retain the current Adobe Developer/Trial watermark; production engine licensing and rendering remain deployment checks.

Remaining release work is final editorial review of current entry/return procedures and source limitations, deployed runtime/schema/routing/cache/indexability checks, and the final publication switch with navigation/sitemap entries. Vendor guide analytics remain disabled until consent behavior is established. No navigation geometry, berth, fuel availability or independent navigation verification is claimed.

