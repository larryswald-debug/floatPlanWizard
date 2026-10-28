# CODEX TASK — FloatPlanWizard Public Navigation Redesign (Approved Design — STRICT FIDELITY)

## Objective and approval contract
Implement the **user-approved FloatPlanWizard navigation mockup** in the existing FPW ColdFusion website. Use the attached implementation bundle as the definitive visual reference and starting code. **No creative redesign is authorized.** Do not change the layout, ordering, navigation hierarchy, text labels, typography proportions, colors, icon choices, spacing, hero treatment, image placement, interactions, or desktop/mobile patterns without first explaining the conflict and requesting Larry's explicit approval. Avoid any extra features or stylistic opinions. This is a navigation project, **not** a rewrite of the Chesapeake article.

## Required inputs — inspect FIRST
1. `approved-navigation-mockup.png` (primary visual authority)
2. `implementation-visual-reference.png` (supplementary illustration)
3. `index.html` (reference semantic HTML)
4. `css/navigation.css` (reference design tokens and layout)
5. `js/navigation.js` (reference interactions)
6. `images/` (all supplied local SVG icon and photo assets)
7. `README.md` (integration constraints)

These artifacts are reference files; do not deploy the standalone demo page. The actual production site must use existing CFML includes/templates, existing working URLs, authentic logged-in permissions, and real application data.

## Required header layout (desktop)
- Retain the existing thin top Free Membership announcement bar. Match sample weight, text, height, and position.
- Main header: logo/wordmark left; center navigation **Plan a Trip | Explore | Learn | Tools | Help**; right actions: search icon, **Pricing**, saturated cyan **Start Free**, Login.
- Match navy-black background, cyan selected state, icon sizing, typography, horizontal rhythm and header height from mockup. Existing FPW wordmark/logo has priority over improvised replacement artwork if its shape differs.
- Use exactly the supplied icon asset family; do not introduce mismatched Font Awesome/Bootstrap/emoji icons in the new header.
- Menu activation is **click/tap**, not automatic hover. One menu open at a time; second click toggles it closed; click outside and Escape close it. Maintain focus visibility.
- Mega menus float beneath the appropriate trigger with a small top pointer, navy background, thin cyan outline and restrained shadow. They must not flash, jitter, stick, or open when cursor merely passes through the navigation.
- Keep image-heavy decoration only where in mockup; **no giant promotional cards** or third-level flyouts.

## Explore mega menu (pixel and content priority)
- Two balanced columns with a subtle vertical divider and cyan uppercase headings.
- Left: CRUISING GUIDES → Chesapeake Bay Cruising Guide (image, title, concise description), Great Loop Planning Guide (image, title, concise description), All Cruising Guides.
- Right: GREAT LOOP LIBRARIES → Ports & Marinas, Anchorages, Bridges, Locks, Waterway Routes, Search the Great Loop. Each is a scan-friendly single-row destination with a line icon at left and arrow at right.
- Use supplied `thumb-chesapeake.jpg`, `thumb-greatloop.jpg` and SVG images. If an existing approved FPW image is more faithful to the visual reference, propose the exact substitution and obtain approval BEFORE making it.
- The current Chesapeake Guide must remain linked and searchable; keep its existing URL, content, canonical, breadcrumb, and sitemap entry.

## Remaining menus (exact hierarchy)
- Plan a Trip: Route & Trip Generator, My Routes, My Vessels; Create a Float Plan, Active Cruise, Follow a Trip.
- Learn: Solo Boating Safety, Shore Contact Guide, Boating Emergencies; Why Use a Float Plan, How FPW Works.
- Tools: Fuel Calculator, Boat Loan & Ownership Calculator; Marine Weather, Route Timing Tools.
- Help: Help Center, User Manual; FAQ, Contact Support.
- Display only links to actual supported FPW pages/features. If an item is not a standalone real destination, use the existing documented parent page **only after reporting the mapping decision**; do not create fake URLs or new application features.
- Treat member-only items according to the real authentication/authorization architecture; preserve existing intended access control and redirect patterns.
- Pricing stays a top-level link, not a menu.

## Mobile/tablet
- Replace the desktop nav at the breakpoint shown by the reference (approximately 1040 px) with a visible menu toggle.
- Use a navy slide-out drawer with large legible accordion rows: Plan a Trip, Explore, Learn, Tools, Help, followed by Pricing, Start Free, Login. Target 48px or larger touch areas. One expanded subsection at a time if existing patterns permit.
- Close by Escape, close button, backdrop/tap outside; lock or manage background scroll appropriately; trap focus in modal drawer if implemented as modal, restore focus on close. Must work with VoiceOver and keyboard.
- Do not add a radial menu, floating Dynamic Island, or Active Cruise controls to the public website navigation. Those concepts are out of scope.

## Page hero and secondary nav
- Match the Chesapeake hero shown in the mockup only if the user-approved scope includes replacing the current hero. The supplied hero image is a **local reference crop from generated artwork**, not a verified clean full-width original photograph. Before changing the live hero, demonstrate how it looks on desktop/mobile and obtain explicit approval for any substitution or crop changes. Do not allow photo distortion or text overlays from embedded mockup imagery.
- Breadcrumbs and guide content are preserved. The example guide-level secondary tabs may be added only if the existing anchor targets are verified and the design matches the approved mockup; otherwise report the missing anchors and seek approval.
- No content rewriting, no mass redirects, no sitemap updates, no metadata modifications.

## Integrate into existing code, do not replace app logic
1. Find the real shared public header and menu includes, CFML templates, desktop/mobile CSS, existing JS click handlers and feature-specific nav rules.
2. Inventory every current nav destination and map each to the approved hierarchy. Provide an old → new menu mapping table with actual URLs before editing.
3. Identify links that must remain accessible but do not appear in the mockup (e.g., Terms, Privacy, account/security settings, admin only). Preserve them in their existing appropriate footer/account locations; report any navigation conflict before removing a link.
4. Port only the appropriate markup, classes, CSS and JS into existing project conventions, preserving server-side auth and localization if any.
5. Reference the supplied local SVG icons and image assets; sanitize/optimize as needed **without visible changes**. Respect CSP and existing asset versioning; use stable build-version cache busting, not per-request random query strings.
6. Do not add new frameworks, fonts, CDN dependencies, new routes, or database changes.
7. Keep indexable menu links as real `<a href="...">` HTML links. Use `<button>` only for expanding/collapsing menus. No JavaScript-only link navigation.
8. Preserve Cloudflare caching and existing SEO URL/rewrite fixes; test authenticated vs public output, ensuring no private page leaks into public caches.

## Functional acceptance tests — required
- Desktop: header and Explore menu faithfully match approved visual; test at widths 1440, 1280 and 1100; menus not clipped or wider than viewport.
- Mobile: test at 390, 430 and 768 px; no horizontal scrolling; 48px minimum practical tap targets; drawer is usable with thumb/keyboard/VoiceOver.
- Click toggles menus; opening another closes first; outside click/Escape closes; focus remains logical; screen readers announce expanded state correctly.
- All actual links work, with permissions and login behavior unchanged; no blank, guessed or dead `#` destinations in integrated production implementation.
- Confirm authenticated dashboards and non-public actions are NOT accidentally moved into public cacheable output.
- No regression to route creation, float-plan activation, weather, Great Loop, guides, login, signup or pricing.
- Test actual Chesapeake and Great Loop clean URLs without diagnostic cache-busting query strings; do not expand into another full SEO crawl.
- Create before/after screenshots with consistent viewport and state: desktop closed, desktop Explore open, Plan a Trip open, mobile closed, mobile drawer open and section expanded.

## Visual acceptance and change control (NON-NEGOTIABLE)
- Take a screenshot of the new implementation and place it side by side with `approved-navigation-mockup.png` at equivalent dimensions.
- Document any differences and whether caused by actual content or responsive behavior; **do not silently 'improve' or reinterpret the design**.
- If the current site's architecture, real link inventory, or source imagery makes exact fidelity impossible, STOP that affected portion, present the smallest necessary decision and request Larry's approval. Implement unaffected faithful sections only.
- Do not deploy without Larry's explicit approval. No SSL, Cloudflare, SEO rewrite, backend, navigation-permission, or unrelated content changes.

## Deliverables
A. Changed-file inventory and concise implementation summary.
B. Exact old → new navigation link map with authenticated/public access labels.
C. Desktop and mobile screenshot comparison with mockup.
D. Functional and accessibility test results, including link checks.
E. Exact unresolved issues/approval requests; NO unauthorized design changes.

**Definition of done:** The FPW public header and mega-menu experience reproduce the approved mockup in layout, styling, content hierarchy and behavior while preserving all existing site functionality and URLs. If fidelity cannot be achieved, disclose the gap rather than changing the design.
