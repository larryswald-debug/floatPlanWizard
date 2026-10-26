# FloatPlanWizard first-pass SEO audit — 2026-10-25

**Audit only.** No fixes were implemented. Production is the authority for live behavior; repository evidence explains possible execution paths but does not prove deployment. Priority is qualified boating visitors, useful tool engagement and member registrations.

## Executive assessment

The most urgent issue is unreliable access to Great Loop reference URLs. The initial sitemap crawl found **121 HTTP 404 responses and 22 self-redirect loops among 720 URLs**. After expanding through links and supplied page exports, **178 of 195 failed Great Loop URLs returned a usable 200 response when a diagnostic query was added**; 17 port URLs remained 404. This is strong evidence of URL-dependent response inconsistency with visible cache involvement. It does not identify the exact CDN/origin configuration error or prove when Google encountered it.

The public product has a useful foundation: the fuel calculator clearly answers a concrete task, public calculators are accessible before registration, the Great Loop trip-planning guide already explains real controls with screenshots and limitations, and the safety content offers printable supporting materials. The seven representative page families rendered without page-level horizontal overflow at the two tested widths. Canonical tags and server-rendered headings are broadly present on intended public pages; all 798 JSON-LD scripts parsed in the 814 successful direct HTTPS HTML responses analyzed were syntactically valid.

Content quality needs attention in the ports library. Public pages expose seed provenance, missing service/approach details and records marked Needs Review, including Kingston, Jamaica presented as a Great Loop port. Improving the reliability and relevance of existing references has stronger evidence behind it than publishing more pages.

The supplied exports show fewer clicks and impressions, particularly for the fuel calculator. They do **not** establish seasonality, a hosting cause, a Google indexing loss, or conversion performance. Their absolute dates and property identity are missing, and the query table covers very little of the aggregate traffic.

### Five highest-priority actions

| Order | Finding | Concrete next action |
|---|---|---|
| 1 | **SEO-001** | Diagnose and repair clean-URL/cache response inconsistency; verify the 178 recoverable references before considering any removal. |
| 2 | **SEO-002** | Reconcile the 17 persistent port 404s with intended retirements or verified replacements, then align sitemap and links. |
| 3 | **SEO-003** | Resolve effective production redirect rules: eliminate HTTPS-to-HTTP hops and normalize the home/index entry path. |
| 4 | **SEO-010** | Review and gate publication of unsuitable/unreviewed port records; preserve internal IDs and genuine useful references. |
| 5 | **SEO-009** | Obtain dated, complete search exports and diagnose the fuel page's 27-click decline before changing its already relevant title. |

P1 means the first implementation/investigation tranche; P2 follows once URL reliability and content identity are understood; P3 is a later improvement. Priority is not a claim of a Google penalty. No critical security defect or private-data exposure was established in this SEO audit.

## Scope, environments and evidence

| Item | Observed scope / limitation |
|---|---|
| Repository | `/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw`; branch `main`; commit `94e20aa374a43959fa0be7f8ee1bd5819c588d7a`. Initial working tree was clean. Only new audit files were created. |
| Audit date | 2026-10-25, America/New_York. Crawl records retain UTC timestamps; principal crawl 13:52:34–14:07:39 UTC, query checks and browser samples within this session; final port facet probes 14:17:03 UTC. |
| Tooling | MCPCF was unavailable. The user explicitly authorized read-only shell inspection and audit artifacts. Website GET/render evidence used MCP Playwright; no alternate shell website fetch was used. No dependencies installed. |
| Production | Public `https://floatplanwizard.com`; response headers show Cloudflare and ASP.NET, and some error bodies identify IIS 10. This does not expose the effective origin configuration or prove its revision. |
| Development | ColdFusion/CFML on the local container setup, vanilla JavaScript and Bootstrap 5.3.3 in shared styles. Docker daemon was unavailable and `http://localhost:8500/fpw/` refused the connection. No container was started; there is no local runtime pass. |
| Public request coverage | All 720 sitemap URLs, additional same-site links and export URLs, selected aliases, boundary shells, three deliberately nonexistent paths and two port filters. 1,072 distinct baseline/variant URLs, plus 195 diagnostic rechecks and two facet probes: **1,269 observation rows covering 1,262 distinct requested URLs**; seven diagnostic URLs were observed more than once. |
| Request budget | API fetch concurrency was at most two; redirects were bounded. Saved crawl/recheck records contain 1,741 HTTP hops, plus bootstrap/facet probes and browser-render asset traffic. An interrupted batch caused approximately 200 duplicate page fetches; these are included in saved crawl evidence where retained. This is a bounded audit, not an exhaustive parameter crawl. |
| Deep browser samples | Home, fuel calculator, signup, trip-planning guide, Olmsted lock, loan/ownership calculator and emergencies guide; 1440×900 and 390×844; Chromium 155.0.8059.80; 14 samples. Tracking/API/non-GET requests were blocked in these controlled renders. |
| PDF coverage | 17 unique public PDFs fetched and text-extracted; two representative first pages rendered and visually inspected. No full-document visual or accessibility certification. |
| Search data | Six supplied CSVs in `/Users/lawrencewald/Downloads/floatplanwizard-2/`; no authenticated Search Console or GA4 access used. |

The initial sitemap responses were 577 final 200, 121 final 404 and 22 unresolved self-301 loops. This is **80.1% / 16.8% / 3.1%** of the sitemap at observation time. The 577 includes HTML and PDFs. Later query rechecks are recorded separately and do not overwrite the original clean-URL result.

### Source and deployment map

The main source paths reviewed were the root landing pages, clean-route wrappers in `great-loop/*/index.cfm`, corresponding `app/great-loop-*.cfm` templates, library services, the shared navigation/footer, route-builder UI/JavaScript/server handlers, robots/sitemap and public guide/calculator templates. Source hashes are retained in [input-manifest.csv](input-manifest.csv).

* [includes/fpw_base_path.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/fpw_base_path.cfm:1) supplies `request.fpwBase`/API-base handling for production root versus `/fpw`. [includes/html_head.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/html_head.cfm:1) includes that helper, favicon and analytics; it is **not** a central title/canonical generator. Titles, descriptions and JSON-LD are principally page/template-owned.
* Home includes [includes/prelaunch_top_nav.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/prelaunch_top_nav.cfm:1), which uses the active shared navigation. [includes/top_nav.cfm:525](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav.cfm:525) already has the clean fuel link locally; live markup differs. [includes/footer.cfm:315](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/footer.cfm:315) still owns the legacy footer destinations.
* The repository's production-target [web.config:8](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:8) uses IIS URL Rewrite, including explicit index/host/HTTPS/clean-route handling and a PDF Link-header outbound rule at line 591. **The deployed file and effective inherited IIS/Cloudflare settings were not accessible.** Recommendations about production rule order require that evidence before edits.
* The actual local filesystem routing file inspected was [wwwroot/WEB-INF/rewrite.config](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/WEB-INF/rewrite.config:1): Tomcat rewrite syntax, with trip-planning lines 5–6, fuel 15–18, guides 20–43, libraries 45–65 and Help 67–71. There are no loan-calculator rules in this particular file. The loan handoff documentation describes additional Host RewriteValve setup under a different local home path. The referenced `config/tomcat/rewrite.config` and startup wrapper are absent under this actual development root, and the stopped/unavailable runtime prevented confirmation of its effective configuration. Absence here is **not** proof the development URL is broken.
* The container compose setup maps the webroot into `/app` and publishes ColdFusion at port 8500, with separate ColdFusion configuration/log storage. IIS and Tomcat rules are not interchangeable. No private Stripe configuration or database contents were read.
* The sitemap is a checked-in XML URL set; no generator was identified in the inspected publishing/scripts paths. The live sitemap and source sitemap have identical text after trimming surrounding whitespace.

### Public inventory and intended indexing

[url-inventory.csv](url-inventory.csv) records every requested URL, observation time, status/chain, final URL, canonical, HTML/header robots, title, description, H1, content type, sitemap membership and an explicitly qualified intended-indexability assessment. It is an **observation inventory**, not a list of Google-indexed URLs. Robots-disallow is documented separately below; it is not silently equated with noindex.

| Family / representative entry | Assessment |
|---|---|
| Home, `/about`, `/how-it-works/`, `/app/pricing.cfm`, `/faq/` | Public acquisition/support content; clean primary pages returned 200. Titles and descriptions communicate planning, sharing and account entry. Alias handling needs SEO-003. |
| `/app/join.cfm`, `/app/login.cfm` | Join is public acquisition content and rendered successfully; login is an account entry, robots-disallowed and not a priority organic landing page. No form was submitted. |
| `/great-loop/trip-planning/` | Public planning guide and navigation entry to route work; usable text is returned in HTML. The source and guide explain actual workflow, with qualifications below. |
| `/great-loop/locks/`, `/bridges/`, `/ports/`, `/anchorages/` under `/great-loop/` | Hubs, taxonomy and detail references use shared templates. The sitemap has 324 lock, 206 bridge, 163 port URLs and one anchorage hub. Reliability and port content are the main findings. |
| `/boat-fuel-calculator/`, `/boat-loan-calculator/` | Public useful tools before registration, with explanatory HTML. Calculation interactions depend on JavaScript; no financial or navigation accuracy certification was performed. Legacy fuel app route needs canonical review. |
| `/why-use-a-float-plan/`, `/solo-boating-safety-guide/`, `/shore-contact-overdue-boater/`, `/common-boating-emergencies/` | Distinct intents: rationale, solo preparation, shore-contact response, and emergency preparation. These are not presumed cannibalizing simply because safety topics overlap. |
| `/help/`, `/app/user-manual.cfm`, `/app/contact.cfm`, `/press.cfm` | Public support/content entry pages checked; manual intentionally noindex,nofollow and no-store. Its exclusion is not an SEO defect. No support request sent. |
| Dashboard / Route Generator / Trip Planner | Member actions are reached through account/dashboard and existing CTAs. No invented public Route Generator URL is recommended. Anonymous dashboard/monitoring requests redirected to the member-required home notice. |
| Follow / Monitor / Active Cruise / preview / completed trips | Private/token/member families should remain outside search. Only tokenless Follow shells and anonymous entry behavior were fetched; authenticated, tokenized, monitoring actions and operational endpoints were excluded. Source-only preview/completed directives are not production validation. |
| PDFs | 11 sitemap PDFs plus six linked emergency PDFs; status/text/canonical policy below. Media kit ZIPs, images and video were not treated as crawlable HTML/PDF pages. |

The crawl followed public HTML/PDF destinations but deliberately did not enumerate every filter combination, search query, sorting state, private route, API, administrative route or token. Two port state filters were specifically checked to assess discovery. External links were sampled for authoritative references, not exhaustively crawled. Source-only `/boating-guides/nautical-charts/` has a rewrite declaration but no matching local guide file in the inspected path and returned 404; it was not linked in the sampled live navigation/sitemap, so no speculative restoration is proposed.

## Findings and implementation backlog

Each finding below records the observed behavior, likely impact, exact correction options and verification. Root causes are stated only where supported. The CSV contains the same 12 stable IDs and all implementation fields. [Validation notes](validation.md) record the artifact checks and unchanged-source check. Effort estimates are planning estimates, exclude approval/deployment waiting time and do not authorize implementation. Before implementing, establish fresh source/configuration backup coverage and approve the exact scope; this audit only adds new files to a clean baseline.

### SEO-001 — Clean Great Loop URLs return cache-dependent 404s and self-redirects

**Confirmed defect · P1 · severity: high.** Confidence: high for responses; medium for cache involvement; origin cause unverified. Category: Crawl reliability.

**Evidence (production + source):** Of 720 sitemap URLs, 121 returned 404 and 22 ended in self-301 loops. Across the expanded crawl, 195 failed Great Loop URLs were rechecked with ?fpw_seo_audit=20261025: 178 returned 200 and 17 remained 404. For example, the 92nd Street bridge returned 301 Location equal to its own requested HTTPS URL, CF-Cache-Status HIT (Age 14773 on repeated hops); its query variant returned 200. Aberdeen returned a cached 404 while its query variant returned 200. See cache-rechecks.csv for every pair. Query behavior and cache headers establish response inconsistency, not the exact Cloudflare/origin misconfiguration.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/great-loop/bridges/92nd-street-bridge-glb-0135/](https://floatplanwizard.com/great-loop/bridges/92nd-street-bridge-glb-0135/), [/great-loop/locks/aberdeen-lock-and-dam/](https://floatplanwizard.com/great-loop/locks/aberdeen-lock-and-dam/), [/great-loop/ports/187-charlevoix-mi/](https://floatplanwizard.com/great-loop/ports/187-charlevoix-mi/), [/great-loop/anchorages/state/ny/](https://floatplanwizard.com/great-loop/anchorages/state/ny/).

Source anchors: [web.config:78](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:78); [great-loop/locks/index.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/locks/index.cfm:1); [great-loop/bridges.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/bridges.cfm:1); [great-loop/anchorages/index.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/anchorages/index.cfm:1).

**Impact:** Ordinary visitors and crawlers following clean links can fail to reach otherwise available planning references. The observations do not prove when this began or explain the export-period traffic change.

**Safest Fix:** After reviewing effective production rules, use a narrowly scoped cache bypass for affected public library paths if it is confirmed to restore correct responses; repair the specific bad rule and invalidate only affected cache entries under separate implementation authorization.

**Best Fix:** Reconcile Cloudflare cache keys, redirects, proxy HTTPS handling and deployed IIS rewrite rules. Establish one clean-URL response contract, correct its root cause, then remove contaminated cached responses and verify that fresh responses stay correct. Do not remove the 178 recoverable pages from the sitemap as if they were retired.

Effort: 1–3 days investigation and repair; depends on configuration access. Dependencies: Read-only effective CDN/IIS configuration, deploy history and origin logs; implementation approval. Risks: A broad purge or blanket bypass can mask the cause, increase load or disturb private cache rules. Do not change application data to compensate for cached errors.

**Post-fix verification:** Retest all 195 clean/query pairs with bounded GETs after authorized changes; valid pages should give stable 200 and clean canonicals, with no self Location or HTTPS downgrade. Repeat after cache warming; inspect verified crawler logs if available.

### SEO-002 — Seventeen sitemap port URLs remain 404 on both requests

**Confirmed defect · P1 · severity: high.** Confidence: high for 404 and sitemap inclusion; retirement intent unverified. Category: Sitemap / retired URLs.

**Evidence (production + source):** All 17 persistent failures are listed in persistent-port-404s.csv. Clean and diagnostic-query requests both return 404; the page says the port is unavailable. The source resolves ID, then slug, then the existing port_slug_redirects mapping before returning 404. Production records/mappings were not inspected, so missing, retired and mismapped records cannot be distinguished.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/great-loop/ports/141-cairo-il/](https://floatplanwizard.com/great-loop/ports/141-cairo-il/), [/great-loop/ports/179-albany-ny/](https://floatplanwizard.com/great-loop/ports/179-albany-ny/), [/great-loop/ports/164-charleston-sc/](https://floatplanwizard.com/great-loop/ports/164-charleston-sc/).

Source anchors: [sitemap.xml:188](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/sitemap.xml:188); [app/great-loop-port.cfm:7](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-port.cfm:7); [api/v1/PortsLibraryService.cfc:87](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PortsLibraryService.cfc:87); [api/v1/PortsLibraryService.cfc:116](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PortsLibraryService.cfc:116).

**Impact:** The sitemap promotes unavailable destinations and may send users to a dead end. Some similarly named surviving ports exist, but a name alone is insufficient evidence for a replacement.

**Safest Fix:** Confirm retirement intent for these exact 17 URLs; remove intentionally unavailable URLs from the sitemap and relevant links while retaining a true 404/410.

**Best Fix:** Reconcile each old record with its correct current entity. Use the existing redirect mechanism for a verified equivalent only, retain 404/410 where none exists, and synchronize sitemap and links. Keep the investigation separate from the recoverable cache failures in SEO-001.

Effort: 0.5–1.5 days after record ownership is clear. Dependencies: Production port and redirect mapping read access; content owner. Risks: Wrong redirects can send boaters to a different city or waterway. Do not redirect all missing ports to home or the library hub.

**Post-fix verification:** Every removed URL is absent from sitemap; each approved replacement uses one permanent redirect to a 200 canonical page; truly retired pages retain a correct error status.

### SEO-003 — Production redirect behavior diverges from repository rules

**Confirmed defect · P1 · severity: medium.** Confidence: high for live behavior and source difference; deployed cause unverified. Category: Canonical routing.

**Evidence (production + source):** Direct /index.cfm and /INDEX.cfm return 200 with a root canonical. http://www.floatplanwizard.com/ redirects to https://floatplanwizard.com/index.cfm, which remains 200. Slashless HTTPS calculator and trip-planning URLs redirect first to HTTP and then back to HTTPS. Direct directory index variants also return 200 with clean canonicals. Repository web.config contains root-index, host, HTTPS and clean-route rules, but the effective deployed configuration is unavailable.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/index.cfm](https://floatplanwizard.com/index.cfm), [http://www.floatplanwizard.com/](http://www.floatplanwizard.com/), [/boat-fuel-calculator](https://floatplanwizard.com/boat-fuel-calculator), [/boat-loan-calculator](https://floatplanwizard.com/boat-loan-calculator), [/how-it-works.cfm](https://floatplanwizard.com/how-it-works.cfm).

Source anchors: [web.config:8](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:8); [web.config:28](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:28); [web.config:348](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:348); [web.config:514](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:514).

**Impact:** Unnecessary hops and alternate entry URLs complicate consolidation and delay access. Correct canonical tags mitigate several duplicates; there is no proof Google selected the wrong canonical.

**Safest Fix:** Correct only the demonstrated HTTPS downgrade and root-index cases in the effective production rule layer, preserving request guards and semantic query parameters.

**Best Fix:** Review rule precedence across CDN and IIS and normalize host, scheme and applicable aliases directly to the intended HTTPS canonical in one redirect. Maintain a separate equivalent test matrix for Tomcat development routing.

Effort: 0.5–2 days after deployment access. Dependencies: Effective IIS and CDN rules; avoid copying IIS rules into Tomcat. Risks: Redirecting internal rewrites without THE_REQUEST-style guards can create loops. Preserve legitimate parameters and /fpw development mount.

**Post-fix verification:** Test HTTP/HTTPS, www/non-www, slash/no slash, explicit indexes, legacy .cfm, case and query variants. Require no HTTPS-to-HTTP hops and no loop; preserve meaningful query strings.

### SEO-004 — Public legacy app routes compete with clean canonical pages

**Confirmed defect · P2 · severity: medium.** Confidence: high for conflicting signals; ranking effect unverified. Category: Canonical metadata.

**Evidence (production + source):** The legacy public fuel page returns 200 without a canonical or description; robots.txt allows it. The app lock library and Olmsted detail return 200 with self-canonicals, while the clean versions separately self-canonicalize. Source branches on isCleanLockRoute to create these competing canonical targets.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/app/fuel-calculator.cfm](https://floatplanwizard.com/app/fuel-calculator.cfm), [/app/great-loop-locks.cfm](https://floatplanwizard.com/app/great-loop-locks.cfm), [/app/great-loop-lock.cfm?slug=olmsted-locks-and-dam](https://floatplanwizard.com/app/great-loop-lock.cfm?slug=olmsted-locks-and-dam).

Source anchors: [app/fuel-calculator.cfm:19](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/fuel-calculator.cfm:19); [app/great-loop-locks.cfm:61](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-locks.cfm:61); [app/great-loop-lock.cfm:78](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-lock.cfm:78).

**Impact:** Duplicate public route families provide inconsistent consolidation signals. Keyword cannibalization and lost rankings are hypotheses, not demonstrated effects.

**Safest Fix:** If the content is equivalent, canonicalize legacy app routes to the verified clean public counterparts while preserving member actions and existing links.

**Best Fix:** Audit whether any legacy route has distinct functionality or parameters; permanently redirect truly redundant public GET routes to clean equivalents, otherwise retain the route with a consistent canonical and aligned structured-data URLs.

Effort: 0.5–1 day. Dependencies: Confirm route equivalence and member entry behavior; SEO-001 reliability. Risks: A blanket /app redirect could break authenticated workflows, API callers or useful filters.

**Post-fix verification:** Legacy/public pairs resolve or canonicalize to the same 200 target; source, rendered HTML and JSON-LD agree; member navigation and meaningful parameters still work.

### SEO-005 — Shared navigation still sends visitors through legacy aliases

**Confirmed defect · P2 · severity: medium.** Confidence: high. Category: Internal links / deployed version.

**Evidence (production + source):** Live navigation and footer link to /boat-fuel-calculator/boat-fuel-calculator.cfm; footer Help links to /app/help.cfm. Those routes redirect to public destinations. Local active top_nav.cfm already uses the clean fuel path, while the local footer retains the legacy aliases. This is a confirmed source/live discrepancy for the navigation link, not proof that all local files are deployed.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/](https://floatplanwizard.com/), [/great-loop/trip-planning/](https://floatplanwizard.com/great-loop/trip-planning/), [/boat-fuel-calculator/boat-fuel-calculator.cfm](https://floatplanwizard.com/boat-fuel-calculator/boat-fuel-calculator.cfm), [/app/help.cfm](https://floatplanwizard.com/app/help.cfm).

Source anchors: [includes/top_nav.cfm:525](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav.cfm:525); [includes/top_nav.cfm:686](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/top_nav.cfm:686); [includes/footer.cfm:315](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/footer.cfm:315); [includes/footer.cfm:326](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/includes/footer.cfm:326); [index.cfm:603](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/index.cfm:603).

**Impact:** Sitewide links pay redirect costs and reinforce aliases. A source-only edit could duplicate a change already present locally and fail to address deployment.

**Safest Fix:** Verify which active navigation version is deployed; publish the already-correct link where appropriate and narrowly update the footer targets using the existing base-path variable.

**Best Fix:** Align active shared navigation/footer with the verified canonical route map and add a focused deployed-link check to the existing release verification process.

Effort: 2–4 hours plus deployment verification. Dependencies: Resolve source/live version mismatch; SEO-003 final route map. Risks: Preserve auth hooks, labels, analytics attributes and /fpw versus root behavior; do not refactor navigation.

**Post-fix verification:** Inspect real rendered hrefs on home, guide and calculator at mobile/desktop; clean links reach final 200 destinations directly in each environment.

### SEO-006 — Exclusion directives are uneven across Follow shells and a public mockup

**Opportunity · P2 · severity: medium.** Confidence: high for observed directives; intended mockup availability requires owner confirmation. Category: Indexing boundaries.

**Evidence (production + source):** Anonymous Follow shells return 200 without HTML robots or X-Robots-Tag noindex; their paths are disallowed in robots.txt. The source applies noindex to Follow preview mode only. /family.cfm is a 200 Voyage Stream Mockup with no exclusion directive and no matching robots disallow. No private token or trip was accessed. The member manual correctly returns noindex,nofollow; completed-trip/preview exclusions are source-only checks.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/app/follow.cfm](https://floatplanwizard.com/app/follow.cfm), [/follow/](https://floatplanwizard.com/follow/), [/app/follow-full-map.cfm](https://floatplanwizard.com/app/follow-full-map.cfm), [/family.cfm](https://floatplanwizard.com/family.cfm).

Source anchors: [robots.txt:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/robots.txt:1); [app/follow.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/follow.cfm:1); [app/follow-full-map.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/follow-full-map.cfm:1); [family.cfm:1](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/family.cfm:1); [app/completed-trip.cfm:140](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/completed-trip.cfm:140); [app/user-manual.cfm:10](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/user-manual.cfm:10).

**Impact:** Crawl blocking alone does not ensure a URL will never appear in search. The mockup could be discovered as an unintended public result. No actual private indexing or disclosure was demonstrated.

**Safest Fix:** Add noindex at the existing response/template boundary for intentionally non-searchable public shells; apply it to the mockup if it must remain accessible. Keep authentication and token validation intact.

**Best Fix:** Document intended indexing per route family, enforce noindex consistently for non-searchable responses, and withdraw the prototype if it has no approved public purpose. Decide crawler access narrowly after reviewing any actual indexed URLs; do not broadly remove private robots restrictions.

Effort: 0.5–1 day. Dependencies: Owner decision on mockup; source review of all response modes; implementation approval. Risks: A noindex directive cannot be read by a crawler blocked from fetching the URL. Robots is not access control. Do not index private trip pages or loosen authentication.

**Post-fix verification:** Verify unauthenticated, invalid-token and explicitly authorized preview responses without exposing private data; inspect headers/meta and access controls. Use Search Console existing records to establish whether unwanted URLs are indexed.

### SEO-007 — Sitemap coverage, PDF canonicals and modification dates need one policy

**Opportunity · P2 · severity: medium.** Confidence: high for listed mismatches; indexing effect unverified. Category: Sitemap / PDFs.

**Evidence (production + source):** The static sitemap contains 720 URLs, including seven solo pamphlet PDFs whose HTTP Link canonical points to the HTML solo guide. It lists only the anchorage hub, while 218 additional direct clean anchorage pages returned 200 in the crawl (further failed URLs recovered in query rechecks). Emergency-guide sitemap lastmod is 2026-08-22 while Article dateModified is 2026-08-23; the visible reviewed date is August 22. No sitemap generator was identified. Dates do not by themselves establish which revision date is correct.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/sitemap.xml](https://floatplanwizard.com/sitemap.xml), [/great-loop/anchorages/](https://floatplanwizard.com/great-loop/anchorages/), [/downloads/solo-boater-trip-planning-guide.pdf](https://floatplanwizard.com/downloads/solo-boater-trip-planning-guide.pdf), [/common-boating-emergencies/](https://floatplanwizard.com/common-boating-emergencies/).

Source anchors: [sitemap.xml:36](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/sitemap.xml:36); [sitemap.xml:44](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/sitemap.xml:44); [sitemap.xml:112](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/sitemap.xml:112); [web.config:591](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/web.config:591); [common-boating-emergencies.cfm:61](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/common-boating-emergencies.cfm:61).

**Impact:** Canonical signals and sitemap membership are inconsistent; useful reference coverage and lastmod maintenance are uneven. Sitemap omission does not prove a page is undiscovered or unindexed.

**Safest Fix:** Review canonical intent: if the HTML guide is preferred, remove the seven noncanonical PDF entries while keeping downloadable links. Add only vetted, canonical, stable-200 anchorage pages and correct dates from actual content-change evidence.

**Best Fix:** Use a documented canonical public-URL manifest or existing publishing workflow to produce a validated sitemap from published records, with truthful significant modification dates and exclusion rules. A generator is a later scoped implementation, not part of this audit.

Effort: 0.5–1 day manual alignment; 1–3 days for a separately approved generator. Dependencies: SEO-001/002 stable URLs; content owner; PDF indexing policy. Risks: Do not add filter permutations, diagnostic queries, unreviewed port rows or private pages. Never set all lastmod dates to today or noindex all PDFs automatically.

**Post-fix verification:** Sitemap URLs are final canonical 200 targets, dates match meaningful changes, intended PDFs retain extractable text and correct headers; compare eligible public records with sitemap output.

### SEO-008 — Large raster assets create avoidable mobile transfer weight

**Opportunity · P2 · severity: medium.** Confidence: high for bytes; field performance effect unverified. Category: Performance.

**Evidence (production + source):** In the 390px controlled browser samples, the fuel CSS image transferred 1,575,850 bytes, signup CSS image 1,613,513 bytes, and home preview plus background 778,629 + 486,249 bytes. The same asset URLs are used at desktop size. The 14 initial render samples had no page overflow and initial CLS 0; no field CWV or Lighthouse score was obtained. Two-page pamphlet PDFs are also about 1.26 MB, despite being text-extractable.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/](https://floatplanwizard.com/), [/boat-fuel-calculator/](https://floatplanwizard.com/boat-fuel-calculator/), [/app/join.cfm](https://floatplanwizard.com/app/join.cfm).

Source anchors: [assets/css/fpw-conversion-landing.css:200](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/fpw-conversion-landing.css:200); [boat-fuel-calculator/boat-fuel-calculator.cfm:330](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm:330); [boat-fuel-calculator/boat-fuel-calculator.cfm:1474](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm:1474); [assets/css/auth-pages.css:947](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/css/auth-pages.css:947).

**Impact:** Large downloads can burden mobile visitors before tool use or registration, especially on slower links. This is a byte-weight opportunity, not proof of poor field LCP or conversion loss.

**Safest Fix:** Compress/resize the specific heavy assets with visual review, preserve layout dimensions and existing CSS hooks, and avoid lazy-loading the actual LCP element.

**Best Fix:** Provide appropriately sized modern-format variants with responsive selection and a fallback, prioritizing fuel and signup. Optimize PDF image payloads separately without damaging text, print quality or accessibility.

Effort: 0.5–2 days including visual verification. Dependencies: Original assets and approved appearance; baseline image snapshots. Risks: Overcompression can damage UI screenshots and printed emergency cards. Broad CSS/image refactors are unnecessary.

**Post-fix verification:** Compare transferred bytes and screenshots at 390px/1440px; repeat controlled loading under a stated network profile and review field CWV when supplied. Verify no layout shifts, lost text or form changes.

### SEO-009 — Fuel-page click loss is measurable; its cause is unresolved

**Unverified concern · P1 · severity: high business priority.** Confidence: high for arithmetic; low for causal attribution. Category: Search performance investigation.

**Evidence (supplied exports; production title reviewed):** Fuel clicks fell 56 to 29 (-48.2%), impressions 12,028 to 9,962 (-17.2%), and computed CTR 0.466% to 0.291%; exported position improved 5.90 to 5.67. This accounts for 27 of the 43 fewer page-row clicks (62.8%). The query export has 0 current clicks and only 678 impressions, versus device totals 110 and 16,837. Absolute dates, property identity and daily data are absent.

Observed: Exports inspected 2026-10-25; exported absolute periods unknown. Examples: [/boat-fuel-calculator/](https://floatplanwizard.com/boat-fuel-calculator/).

Source anchors: [/Users/lawrencewald/Downloads/floatplanwizard-2/Pages.csv](/Users/lawrencewald/Downloads/floatplanwizard-2/Pages.csv); [/Users/lawrencewald/Downloads/floatplanwizard-2/Queries.csv](/Users/lawrencewald/Downloads/floatplanwizard-2/Queries.csv).

**Impact:** The largest organic landing-page opportunity is losing clicks, but position alone cannot identify query mix, seasonality, SERP changes or technical causation. Rewriting an already relevant title without query evidence may miss the cause.

**Safest Fix:** Obtain dated daily/page/query/device exports and isolate the fuel page before changing copy. Keep the existing useful free-tool title and task explanation while investigating.

**Best Fix:** Diagnose equal finalized date windows plus year-over-year cohorts and deployment/error chronology. Once supported, test one specific snippet or tool-entry improvement and evaluate qualified engagement/registration with defined analytics events.

Effort: 0.5–1 day analysis once data is available; experiment duration depends on traffic. Dependencies: Exact export requests in report; no GA4 conversion definitions supplied. Risks: Very low click counts and missing queries can produce unstable conclusions. No promised recovery, seasonality claim or hosting attribution.

**Post-fix verification:** Recalculate CTR from totals; compare like-for-like dates, query/device/country mix and field landing behavior. Record a hypothesis and measurement window before any copy test.

### SEO-010 — Public port references expose unreviewed seed records

**Confirmed defect · P1 · severity: high.** Confidence: high for published placeholders; record corrections require review. Category: Content quality / reference trust.

**Evidence (production + source):** Kingston, Jamaica is publicly presented as a Great Loop port with loop segment and waterway Needs Review and coordinates in Jamaica. Columbus, Ohio has the same review placeholders. Of 142 successful direct port-detail URL responses in the base crawl (includes one alias), 141 say approach notes have not been verified; eight contain Needs Review. Even the Kingston, NY page says services and approach notes are unverified. These counts describe fetched responses, not all database entities. The source lookup by ID/slug does not require a reviewed publication status.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/great-loop/ports/24-kingston-jm-01/](https://floatplanwizard.com/great-loop/ports/24-kingston-jm-01/), [/great-loop/ports/13-columbus-oh/](https://floatplanwizard.com/great-loop/ports/13-columbus-oh/), [/great-loop/ports/178-kingston-ny/](https://floatplanwizard.com/great-loop/ports/178-kingston-ny/).

Source anchors: [app/great-loop-port.cfm:184](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-port.cfm:184); [app/great-loop-port.cfm:419](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-port.cfm:419); [api/v1/PortsLibraryService.cfc:87](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PortsLibraryService.cfc:87); [api/v1/PortsLibraryService.cfc:290](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/PortsLibraryService.cfc:290).

**Impact:** A search visitor looking for a useful Great Loop stop receives seed provenance and placeholders, sometimes for an evidently mismatched place. Accurate city disambiguation and useful local detail matter more than expanding the number of indexable records.

**Safest Fix:** Have the content owner classify suspect/unreviewed records and temporarily exclude confirmed unsuitable pages from search/public lists using an approved publication rule; retain any needed internal planning records. Do not mass-delete or merge by name.

**Best Fix:** Introduce a narrowly scoped reviewed-publication gate for port references and sitemap eligibility. Verify location/entity, route relevance and source-backed services/approach notes, then publish concise useful content with state/country disambiguation in title/H1. Use real equivalents for approved consolidations.

Effort: 1–2 days for gating/design; editorial review varies by record. Dependencies: Authoritative location/port sources, production record access, owner decisions; SEO-002 reconciliation. Risks: Existing waypoints may reference IDs. Data deletion or automatic geography correction is outside scope. A generic disclaimer does not verify a record.

**Post-fix verification:** Spot-check reviewed records against sources; excluded records are absent from public sitemap/listing and have the intended response directives; internal waypoint use is preserved; names and canonical identities are unambiguous.

### SEO-011 — Lock template labels secondary references as official sources

**Confirmed defect · P2 · severity: medium.** Confidence: high for label mismatch; operational data accuracy not determined. Category: Content trust.

**Evidence (production + source):** The shared detail template always titles the section Official Source and the link Open official source. Pickwick points to waterwayguide.com/lock/5-33/pickwick-locks-and-dam, a secondary reference; Olmsted points to USACE. The template does not distinguish authority links from secondary guides. This audit did not validate every phone, VHF channel or operating schedule.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/great-loop/locks/pickwick-locks-and-dam/](https://floatplanwizard.com/great-loop/locks/pickwick-locks-and-dam/), [/great-loop/locks/olmsted-locks-and-dam/](https://floatplanwizard.com/great-loop/locks/olmsted-locks-and-dam/).

Source anchors: [app/great-loop-lock.cfm:465](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-lock.cfm:465).

**Impact:** The label overstates the authority of some references, reducing clarity where boaters need to verify current operational information.

**Safest Fix:** Use a neutral Source / reference label for the existing source_url field and retain the visible instruction to verify with the official authority.

**Best Fix:** Distinguish actual authority/contact links from secondary reference links in reviewed records and render accurate labels. Add current authority sources where missing, without claiming live status.

Effort: 1–3 hours for neutral wording; record review separately scoped. Dependencies: Content/source ownership; no new schema or data model required for narrow fix. Risks: Do not replace valid secondary sources with guessed official URLs or alter operational facts without verification.

**Post-fix verification:** Inspect Pickwick and an actual USACE-backed page; labels match provenance, existing URLs and safety caveats remain intact; source review dates represent real review.

### SEO-012 — Reference pages can better connect research to the existing planning workflow

**Opportunity · P3 · severity: low.** Confidence: high for available content; conversion effect unmeasured. Category: Internal links / conversion.

**Evidence (production + source):** The trip-planning guide already has screenshots, a Chicago/Starved Rock research example, geometry-based per-leg NM overrides, explicit lock-time limitations and a manual fuel-calculator handoff. Lock detail related links emphasize fuel/safety; the guide is available in global navigation but has no equivalent contextual link in that planning paragraph. Source confirms geometry-derived override distance and separate idle hours/fuel handling; authenticated runtime was unavailable.

Observed: 2026-10-25; individual UTC timestamps in response-evidence.json. Examples: [/great-loop/locks/olmsted-locks-and-dam/](https://floatplanwizard.com/great-loop/locks/olmsted-locks-and-dam/), [/great-loop/trip-planning/](https://floatplanwizard.com/great-loop/trip-planning/), [/boat-fuel-calculator/](https://floatplanwizard.com/boat-fuel-calculator/).

Source anchors: [app/great-loop-lock.cfm:389](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/app/great-loop-lock.cfm:389); [great-loop/trip-planning/index.cfm:268](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/trip-planning/index.cfm:268); [great-loop/trip-planning/index.cfm:309](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/trip-planning/index.cfm:309); [great-loop/trip-planning/index.cfm:354](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/great-loop/trip-planning/index.cfm:354); [assets/js/app/dashboard/routebuilder.js:5646](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/assets/js/app/dashboard/routebuilder.js:5646); [api/v1/routeBuilder.cfc:11953](/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/api/v1/routeBuilder.cfc:11953).

**Impact:** A specific next-step link may help reference visitors learn how to use the tool before registering. There is no measured funnel or registration-lift evidence.

**Safest Fix:** Add one contextual link from a relevant lock planning paragraph to the existing guide section, preserving all action hooks and current CTAs.

**Best Fix:** Use a small number of accurate contextual handoffs: lock reference to timing guidance, path review to saved geometry/NM, corrected daily distance to manual fuel check, then reviewed route to Float Plan. Reuse the existing guide rather than create overlapping thin articles.

Effort: 2–4 hours editorial/link work. Dependencies: Confirm deployed guide/source alignment; no new product promises. Risks: Do not describe a numeric mileage input, automatic lock-delay timeline adjustment, live lock queues or automatic public-calculator synchronization; current guide explicitly says otherwise.

**Post-fix verification:** Check anchors, meaningful link text, desktop/mobile placement and base paths; verify wording against current controls before implementation; measure only with agreed existing analytics definitions.

### Implementation sequence

| Stage | Findings | Completion evidence |
|---|---|---|
| Immediate diagnosis and targeted repair | SEO-001, SEO-002, SEO-003 | Stable clean URL responses; correct retirement/replacement map; no self-loop or HTTPS downgrade. |
| Parallel content/data investigation | SEO-010, SEO-009 | Reviewed port publication decisions; dated comparable performance cohorts and a supported fuel-page hypothesis. |
| Consolidation and narrow corrections | SEO-004, SEO-005, SEO-006, SEO-007, SEO-011 | Canonicals, deployed links, exclusions, sitemap/PDF policy and source labels agree with intended behavior. |
| Later measurable improvements | SEO-008, SEO-012 | Reduced bytes with preserved appearance; accurate contextual handoffs and agreed engagement measurement. |

No recommendation here requires a broad redesign, framework migration, dependency addition or speculative content expansion.

## Search-performance assessment

### Supplied export completeness

`Filters.csv` says **Search type: Web (text-based)** and **Date: Last 28 days**. The dimension columns compare “Last 28 days” with “Previous 28 days.” No absolute date range, property name, export timestamp or daily Chart/Date table was included. The requested windows appear equal in name, but completeness, lag and actual dates cannot be verified from these files. The export was inspected on October 25; that does not make October 25 its data end date.

| File | Data rows | Meaning / limitation |
|---|---:|---|
| Pages.csv | 877 | Page-row performance; enough to identify material landing-page losses, not causal timing. |
| Queries.csv | 504 | Only 0 current clicks / 678 impressions and 3 previous clicks / 1,090 impressions; severely incomplete relative to aggregate totals. |
| Countries.csv | 170 | Totals match Devices, with small counts in most countries. |
| Devices.csv | 3 | Desktop/mobile/tablet; totals match Countries. |
| Search appearance.csv | 0 | Header-only export; no conclusion about rich-result presence or eligibility. |
| Filters.csv | 2 | Search type and relative date labels only. |

There are no Page indexing reasons, submitted sitemap results, URL Inspection exports, field Core Web Vitals, GA4 landing pages, engagement or registration/conversion data. Existing GA4/Plausible/Clarity includes in source do not prove tracking quality, event definitions or conversion outcomes.

### Totals and major page groups

CTR below is **sum(clicks) / sum(impressions)**. Position is an impression-weighted approximation from rounded exported row positions; it is not a precise property-wide rank or a fixed-keyword comparison.

| Dimension aggregation | Previous clicks → current | Previous impressions → current | Previous CTR → current |
|---|---:|---:|---:|
| Countries / Devices | 152 → 110 (−27.6%) | 20,423 → 16,837 (−17.6%) | 0.744% → 0.653% |
| Page rows | 153 → 110 (−28.1%) | 20,682 → 17,028 (−17.7%) | 0.740% → 0.646% |

The page and other totals differ; they are not forced to reconcile. Search Console aggregation behavior and omitted data can produce different totals. The precise reason for the one-click and impression differences cannot be established without matching property/date/filter metadata. Google's [performance-data explanation](https://developers.google.com/search/blog/2022/10/performance-data-deep-dive) describes aggregation and query-privacy limits.

| Page group | Clicks previous → current | Impressions previous → current | CTR previous → current | Weighted position previous → current |
|---|---:|---:|---:|---:|
| boat-fuel-calculator | 56 → 29 | 12,028 → 9,962 | 0.466% → 0.291% | 5.90 → 5.67 |
| great-loop/locks | 32 → 21 | 3,789 → 3,334 | 0.845% → 0.630% | 8.14 → 7.99 |
| great-loop/bridges | 39 → 26 | 1,883 → 1,704 | 2.071% → 1.526% | 7.30 → 7.06 |
| great-loop/anchorages | 19 → 23 | 1,274 → 966 | 1.491% → 2.381% | 8.79 → 7.37 |
| great-loop/ports | 2 → 2 | 404 → 407 | 0.495% → 0.491% | 10.84 → 9.38 |
| great-loop/trip-planning | 0 → 2 | 0 → 16 | n/a → 12.500% | n/a → 6.00 |
| boat-loan-calculator | 0 → 0 | 9 → 56 | 0.000% → 0.000% | 5.22 → 7.55 |
| home | 4 → 2 | 118 → 47 | 3.390% → 4.255% | 9.08 → 12.23 |
| shore-contact-overdue-boater | 1 → 2 | 308 → 158 | 0.325% → 1.266% | 5.12 → 5.25 |
| common-boating-emergencies | 0 → 0 | 333 → 136 | 0.000% → 0.000% | 10.99 → 13.22 |

The fuel page accounts for **58.5% of current page-row impressions** and **62.8% of the net page-row click decline**. Its current title is “Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost”; its description explicitly covers distance, cruising speed, burn, reserve, range, time and cost. A generic recommendation to add these terms would repeat what is already present. Its slightly improved aggregate position alongside lower CTR/impressions is compatible with multiple explanations, including changed query mix; it is not proof of either lost rankings or seasonality.

Anchorages gained four clicks despite fewer impressions. Individual small winners include the Calumet River bridge page (4 → 10 clicks, 112 → 101 impressions) and Lake Sylvia anchorage (0 → 4 clicks, 19 → 13 impressions). Those are useful review candidates, not statistically established content formulas. The loan calculator's 56 impressions and zero clicks are too few to diagnose a conversion/snippet failure. The trip-planning guide's two clicks are similarly preliminary.

Mobile changed from 88 to 61 clicks and 13,928 to 11,826 impressions; desktop 55 to 47 clicks and 6,120 to 4,746 impressions; tablet 9 to 2 clicks and 375 to 265 impressions. Mobile represents **70.2% of current impressions and 55.5% of current clicks**, reinforcing the practical value of mobile transfer/readability work, without establishing its cause. United States traffic dominates (133 → 99 clicks; 16,182 → 13,651 impressions); Canada is 10 → 6 clicks and 1,576 → 885 impressions. Most other country changes are too small to interpret reliably.

The 504 query rows contain **no matches** for the audit's brand pattern (`float\s*plan\s*wizard|floatplanwizard|\bfpw\b`). That is not evidence of zero brand demand. Current query impressions are only **4.0%** of Devices/Countries impressions and current query clicks are zero versus 110. Anonymization, export/filter limitations or an incomplete selection may contribute; this audit cannot identify which. Consequently, a meaningful branded/nonbranded traffic split or a reliable top-query opportunity list cannot be produced from these rows.

The data supports a decline in these two relative windows and a concentration of click loss on the fuel page. It **cannot establish year-over-year boating seasonality**, hosting impact, a technical-incident start date, or conversion loss. Today's cache defects are actionable independently; linking them to the export decline requires dated evidence.

### Exact additional evidence needed

1. **Search Console performance:** identify the property and export the daily chart plus pages, queries, devices and countries for **2025-06-25 through 2026-10-24**, retaining absolute dates, search type and all filters. Exclude/flag incomplete recent days. For focused comparison, use **2026-09-25–2026-10-22**, **2026-08-28–2026-09-24**, and **2025-09-25–2025-10-22**, but only if those dates are fully processed; otherwise shift both 28-day current/prior windows together and record the replacement dates. Export fuel-page-filtered query×device and page×date data separately. Preserve separate property/page aggregation, and document row limits/anonymized queries.
2. **Indexing and canonical selection:** current Page indexing reason counts with example URLs, current sitemap submission/read results, and existing URL Inspection records for the root, fuel page, one self-loop, one recoverable 404, one persistent port 404 and an omitted anchorage. These are read-only requests; no sitemap submission, validation request or indexing request was made.
3. **Incident timing:** effective Cloudflare cache/redirect configuration and IIS rules, plus deploy/rule change history and sanitized response/access-error summaries for **2026-08-28–2026-10-25**. Include verified crawler identification if available; a spoofed Googlebot user agent is not verification.
4. **Field performance:** current mobile/desktop Search Console CWV or CrUX URL/origin reports, with their stated 28-day collection period. Lab samples here do not substitute for that distribution.
5. **GA4 or the actual analytics source of truth:** landing-page/session-source/device and agreed engagement/registration events for the same comparison periods. Supply event definitions, consent/internal-traffic rules and attribution settings. Do not add new instrumentation until the existing measurement is understood.

## Technical, content and usability checks

### Routing, robots and canonicals

Robots and sitemap both returned 200. Robots permits useful public libraries/tools and has exclusions for `/api/`, administrative/testing routes, account/dashboard/monitoring families, Follow routes and token patterns. Source/live response observations are in the inventory. No production hostname leakage to localhost or the development mount was found in the sampled primary canonical values. This is not an assertion that every generated authenticated URL was checked.

Three deliberately nonexistent public paths returned real 404s: `/fpw-seo-audit-missing-20261025/`, `/fpw-seo-audit-missing-20261025.cfm`, and `/great-loop/locks/fpw-seo-audit-missing-20261025/`. Some generic failures display an IIS error page; a helpful recovery page could improve usability later, while retaining the 404 status. No blanket soft-404 conclusion is justified from three probes. An error page's canonical does not turn its HTTP 404 into a valid indexable page.

Case and query testing found that uppercase fuel and UTM variants can return 200 while declaring the clean lowercase canonical. That alone is not a critical defect. Direct-index variants similarly have a mitigating canonical, but the observed scheme downgrade and deployment discrepancies still deserve repair. The full redirect chains are retained in response evidence.

Google treats redirects, canonicals and sitemap inclusion as different consolidation signals; a sitemap should normally list preferred canonical URLs. See [canonical consolidation guidance](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls) and [sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap). A crawler must be able to retrieve a response to read its noindex directive; robots exclusions are not authentication. See [robots meta and X-Robots-Tag guidance](https://developers.google.com/search/docs/crawling-indexing/robots-meta-tag). Status handling is described in [Google's HTTP response documentation](https://developers.google.com/search/docs/crawling-indexing/http-network-errors).

### Metadata, structured data and duplication

Core public pages have meaningful titles/descriptions and a clear main H1. No missing `alt` attributes were found in the 814 successful direct HTTPS HTML responses scanned; attribute presence is not a judgment that every alternative text is useful. Empty decorative alternatives can be correct. Missing descriptions/canonicals on login, Follow shells or the intentionally excluded manual are not bulk metadata-writing opportunities; route purpose comes first. Privacy/terms canonical housekeeping is lower value than the prioritized defects.

Duplicate titles include expected redirects/aliases and genuinely ambiguous port names such as Chicago, Columbus and Kingston. Some are different places; others may be duplicate entities. A unique title alone will not fix duplicate or wrong port records. Resolve entity identity and publication quality first (SEO-010), then include state/country where it helps the searcher. No keyword-cannibalization claim is supported by the incomplete query export.

JSON-LD includes Organization, WebSite, WebPage, Article, BreadcrumbList, ItemList and Place structures, plus FAQ markup on some pages. All 798 scripts in the defined sample parsed as JSON. This checks syntax only: the official Rich Results Test was not run, and schema presence is not proof of eligibility or enhanced display. **FAQ rich results were retired in May 2026**, according to [Google's documentation updates](https://developers.google.com/search/updates); do not invest in FAQ markup expecting a rich-result benefit. Existing useful visible FAQs can remain. Retain only markup matching visible content and valid provenance; follow [structured-data policies](https://developers.google.com/search/docs/appearance/structured-data/sd-policies).

### Internal discovery and content intent

The limited static-link graph reaches most sitemap pages within one to three links from home. Its first pass found 153 sitemap URLs unreached, overwhelmingly ports, because the port hub renders ten randomly selected featured rows and the initial graph deliberately collapsed filter queries. **These are not proven orphans.** Source `app/great-loop-ports.cfm:117–140,189–197` selects the random ten; source state/segment links at 468/476 are normal hrefs. A later GET of `?stateCode=NY` returned 200 with crawlable links to Albany, Kingston, Oswego and other New York details; `?stateCode=JM-01` linked Kingston, Jamaica. Exact sitewide click depth remains unmeasured across all facets. Keep the existing server-rendered browse links; only consider a stable all-reviewed-ports directory if full crawl data later shows a real gap.

Across the graph, 174 clean internal destinations returned 404 or an unresolved 301 in the initial baseline; this count substantially overlaps SEO-001/002 and is not a separate 174-item template backlog. Global navigation provides broad discovery but does not replace contextual links explaining what a visitor should do next. Google's [link guidance](https://developers.google.com/search/docs/crawling-indexing/links-crawlable) supports descriptive crawlable hrefs.

The planning guide already connects route creation, editing geometry, saving overrides, reloading to inspect effective NM, lock research, idle hours/fuel and manual calculator checks. Source review traced `saveLegOverride` in `assets/js/app/dashboard/routebuilder.js:5646–5724`, the Computed NM / Save Overrides controls in `includes/modals/route_generator_modal.cfm:1782–1801`, effective override selection in `api/v1/routeBuilder.cfc:11953–11967`, and summary hours/idle fuel in the route-builder server logic around 9138–9261. This is **source-path verification**, not a live authenticated end-to-end test. The guide correctly avoids promising automatic lock-delay scheduling, a numeric per-leg mileage field, live lock queues or automatic synchronization with the public calculator/Float Plan.

Safety guide topics are distinct and supported by cited references, a positive foundation. The [U.S. Coast Guard Auxiliary Float Plan Central](https://floatplancentral.cgaux.org/) and [National Weather Service safe-boating guidance](https://www.weather.gov/safety/safeboating-during) were sampled as primary references. The NAVCEN radio-information URL could not be retrieved by the web reader (403); that is a tool/access limitation, not proof the site's outbound link is broken. This audit did not certify every safety instruction, VHF channel, lock schedule or external source. Port quality and misleading “official source” labels are specific findings, not a generic demand for longer copy. Google's [helpful-content guidance](https://developers.google.com/search/docs/fundamentals/creating-helpful-content) favors reliable usefulness; a fixed word count would not establish that.

Home and signup communicate planning/sharing and free account entry, and the fuel/ownership tools can be inspected before joining. Registration remains necessary for saved/member actions. No form submissions or authenticated route calculations were performed. Suggested contextual CTAs and reduced image weight are **usability hypotheses** until supported by a defined funnel, not measured conversion findings.

### PDFs

All 17 sampled PDFs returned **200 / application/pdf** and contained extractable text. The 45-page solo-boating guide is about 2.41 MB; its cover had no extracted text but the remaining pages did. Seven two-page solo pamphlets are about 1.26 MB each; the USCG form is three pages/about 414 KB; two press PDFs are two pages/about 1.26 MB each; the six emergency PDFs are approximately 57–74 KB and one or two pages. Exact bytes, page counts, SHA-256, text counts, header canonicals and observed linking-page examples are in [pdf-inventory.csv](pdf-inventory.csv).

The seven solo pamphlets return `Link: <https://floatplanwizard.com/solo-boating-safety-guide/>; rel="canonical"`, matching the source outbound rule. Their simultaneous sitemap inclusion needs the explicit policy decision in SEO-007. The six emergency PDFs are linked from the guide despite not appearing in the sitemap; omission is not automatically a defect. Their descriptive guide links provide discovery and context. Do not blanket-noindex useful downloads or replace them with image-only documents.

The pypdf reader emitted repair warnings about some object offsets but opened/extracted all files; this is not proof of pristine PDF structure. Only the trip-planning pamphlet and emergency-card first pages received visual inspection; both were readable. Full tagging, reading order, form behavior and every printed page were not audited.

### Performance and mobile samples

Fresh isolated Chromium contexts used desktop 1440×900 and mobile-width 390×844 viewports, reduced-motion preference, no CPU/network throttling, and an initial-viewport observation ending roughly 1.2 seconds after load. These are viewport profiles on the available machine, not a physical phone. Analytics/API/non-GET requests were blocked to avoid recording funnel activity or invoking operations. Resource timings omit opaque cross-origin transfer sizes; lazy content below the fold was not fully loaded. These conditions can make results faster or behavior different from an ordinary visit.

| URL | Desktop observed LCP ms | 390px observed LCP ms | Initial CLS / overflow |
|---|---:|---:|---|
| `/` | 628 | 788 | 0 / none in both samples |
| `/boat-fuel-calculator/` | 648 | 1800 | 0 / none in both samples |
| `/app/join.cfm` | 952 | 460 | 0 / none in both samples |
| `/great-loop/trip-planning/` | 480 | 300 | 0 / none in both samples |
| `/great-loop/locks/olmsted-locks-and-dam/` | 2388 | 292 | 0 / none in both samples |
| `/boat-loan-calculator/` | 548 | 368 | 0 / none in both samples |
| `/common-boating-emergencies/` | 468 | 232 | 0 / none in both samples |

All 14 page navigations returned 200 and recorded no page JavaScript errors. The desktop Olmsted LCP candidate was a map tile, illustrating why comparing isolated timings as page rankings would be misleading. No INP interaction distribution was measured. There are **no Lighthouse scores, field CWV pass/fail results or sitewide speed claims** in this audit. See [Google's CWV explanation](https://developers.google.com/search/docs/appearance/core-web-vitals) for the distinction between metrics and the user experience they describe.

Shared CSS and external Bootstrap/font/map assets remain part of the loading path; maps and calculator outputs depend on JavaScript, while headings and editorial text are returned in HTML. No broad async/defer rewrite is recommended without a profile because it can break existing script order. The observed byte-heavy images provide a more concrete first optimization target.

The mobile Resources menu opened, remained within the viewport width and closed with Escape (`aria-expanded=false`). Its scroll height was 1,611px on an 844px viewport, so the menu requires scrolling; no claim of comprehensive keyboard, touch-target or screen-reader compliance is made. Selected screenshots and complete browser sample metadata accompany this report.

## Evidence artifacts and limitations

| Artifact | Purpose |
|---|---|
| [findings.csv](findings.csv) | 12 stable findings with classification, priority, confidence, source/evidence, Safest Fix, Best Fix, effort, dependencies, risks and verification. |
| [url-inventory.csv](url-inventory.csv) | Requested public/diagnostic/boundary URLs with status, chain, metadata and intended-indexability qualification. |
| [response-evidence.json](response-evidence.json) | Timestamped response chains, selected headers and metadata; cookies and raw page bodies omitted. |
| [cache-rechecks.csv](cache-rechecks.csv), [persistent-port-404s.csv](persistent-port-404s.csv) | All 195 clean/query comparisons and the exact 17 persistent failures. |
| [production-robots.txt](production-robots.txt), [production-sitemap.xml](production-sitemap.xml) | Read-only snapshots of the fetched public discovery files. |
| [pdf-inventory.csv](pdf-inventory.csv) | All 17 PDF status/type/size/text/header checks. |
| [browser-samples.csv](browser-samples.csv), [browser-evidence.json](browser-evidence.json), screenshots/ | 14 controlled renders and selected visual evidence. |
| [search-page-groups.csv](search-page-groups.csv), [search-analysis.json](search-analysis.json) | Recomputed group totals and supplied-export completeness/movers. |
| [input-manifest.csv](input-manifest.csv) | Audited source/export paths and SHA-256 snapshots. |

Temporary full responses, downloaded PDFs and diagnostic scripts remain outside the application at `/tmp/fpw-seo-audit-2026-10-25/`; they are not a deployment requirement. The committed-style documentation directory is the durable deliverable; nothing was committed.

The material unresolved questions are the effective production cache/rewrite configuration and incident timing; correct port identity/publication decisions; Google-selected canonicals and indexing reasons; exact dates/completeness of the search exports; field performance; and defined conversion measurement. No backlinks, keyword volumes, private user records, actual Googlebot access, live paid entitlements, authenticated planning flow, production database contents or real-device performance were claimed.

Validation was read-only: source review, public bounded GETs, controlled browser observations, PDF parsing/limited visual review and arithmetic on supplied exports. No application test suite was run because no implementation was made and the local runtime was unavailable. **No application/configuration/dependency/database changes, account actions, emails, operational requests, analytics submissions, commits, pushes, deployments, cache purges, sitemap submissions or indexing requests were made.** Public GETs naturally appear in access logs; browser analytics endpoints were blocked. Only the dated audit artifacts and temporary diagnostic evidence were written.
