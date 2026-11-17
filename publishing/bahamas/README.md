# Bahamas release and source maintenance

Current architecture: an independent public Bahamas guide and browser-only sample calculator, November 15, 2026. Production deployment is separate.

The November 7, November 9 and earlier November 15 implementation reports are historical evidence. The entire route-import/planning subsystem and numeric Route Generator distance-entry feature have been removed. Do not apply their deployment, migration or workflow instructions. The current implementation report is `full-route-import-rollback-20261115.json`.

## Source of truth
The editorial data file `templates/fort-lauderdale-bimini-v1.json` supplies public coordinates, two 50.3 NM sample legs and worksheet assumptions. It has no member-data import contract. The separate worksheet retains its illustrative 60 NM legs, 20-knot speed and 18 GPH consumption.

The page-local sample calculator uses the fixed 100.6 NM sample distance and editable speed, underway GPH, percentage reserve and usable fuel. Defaults come from the existing article worksheet: 20 knots, 18 US gal/h, 20% and 190 US gal. Time, base fuel, reserve fuel, required fuel and remaining margin update in the browser. Values reset on reload; the calculator uses no API, account writes, cookies or local storage. This calculator was explicitly authorized after historical inspection found no prior standalone editable public sample. The former 6.5 underway hours/day input belonged to the removed importer and is not recreated.

Brown’s Marina replaces the earlier Big Game Club overnight candidate. Its first-party page supplies the exact original location text; datum and coordinate revision are unstated. The point is a candidate marina destination reference, not a berth reservation, offshore waypoint or reviewed approach. PE is the rounded reference in NOAA Coast Pilot 4 chapter 10, revised November 1, 2026; it is not a Florida berth. USCG current-notice retrieval returned 403. Current notices remain a member research task.

## Publication gate
There is no route-import CTA. Keep `status: draft` and `verification.publication_ready: false` until separately approved editorial/indexing release. Noindex and no-store behavior are unchanged.

Draft pages emit noindex and no-store. Bahamas remains absent from the shared navigation, Cruising Guides index and sitemap pending the release gate. Exact IIS/Tomcat clean URLs and private publishing-source deny rules are required. The pages’ private underscore includes are denied separately by IIS; retain equivalent Tomcat rules. Robots directives are not access control.

When gates pass, add only the hub and first itinerary to navigation/sitemap; set truthful publication/update dates; verify clean200, index301 once, missing404, canonical/schema and source denial in the deployed environment. Do not publish later-phase placeholders.

## Maintenance
Review regulatory and service information monthly; authority links quarterly; geography on dataset revisions. The source register records access/effective dates, retrieval limits, reviewer status and next review. A retrieved source never means safe passage, fuel availability or a confirmed berth. Resolve source conflicts rather than manufacturing a verification date. Existing normal routes remain independent of the guide definition.

Natural Earth data and minor-island polygons are public domain. GeoNames geographic labels are CC BY 4.0; Eleuthera’s label was retrieved from Mapcarta, which identifies GeoNames3572435. Label coordinates are editorial map references. Two historical context photographs are included as local responsive copies: Port Everglades PIO’s December 17, 2017 aerial and Pietro’s August 17, 2014 Alice Town waterfront photograph. Both file-specific Commons pages license reuse under CC BY-SA 4.0. Visible captions retain attribution, source and license links, dates and proportional-resize/no-crop disclosure; `assets.json` records dimensions, source revisions and SHA-256 hashes. Proprietary charts remain excluded.

The self-contained SVGs do not use public tile servers. Rebuild source-derived maps and the time/fuel chart from the repository root with `node publishing/bahamas/build-assets.mjs`; check the visible HTML equivalents and rendered layout after changes. `crossing-decisions.svg` is an original concept diagram, not a forecast or current compensation model.

## Later phases, not public placeholders
P2: distinct crossing, entry/return, fuel/provisioning/communications and Bimini pages, plus a separately sourced seven-knot example. Retain the current hub anchors as summaries. P3: substantive Abacos, Exumas, Berry Islands, Eleuthera and Grand Bahama pages, and a separately versioned northern Exumas example. Each needs completed source records, original assets and endpoint-specific mileage semantics. No member records or shared ports/segments are seeded.

## Analytics
No new vendor events are emitted by the Bahamas page script. Establish consent enforcement before enabling the approved public metadata events. Never send private route identifiers, coordinates, custom names, dates, notes or continuation tokens to vendors. Existing required server-side product events remain separate.

## Release verification
Exercise anonymous and signed-in public guide loads, every sample input, invalid values and reload reset. Confirm no route/waypoint API calls or account writes, and retain keyboard/mobile/desktop layout checks. Independently exercise the normal geometry editor, saved-route workflow, ordinary authentication and downstream views. Local evidence does not establish production behavior.

## Retired subsystem and rollback
The `guide_route_imports` table is already absent from the local database. No further schema change or data conversion was required for this full rollback. All creation/conversion/retirement scripts for this abandoned subsystem are removed from active source; historical execution evidence remains in private snapshots.

Existing ordinary source routes, waypoints, saved instances and historical override rows are preserved independently. The original geometry reader honors their stored distances; an intentional future geometry save recalculates distance from the drawn line. No additional migration of the 15 preserved source routes is performed. See the current report for snapshots, data handling, checks and limitations. No commit, push or production deployment is part of this work.

Keep existing HTTP denials for private publishing sources, tests, snapshots and previously generated guide PDFs. Historical source and validation reports remain provenance only.
