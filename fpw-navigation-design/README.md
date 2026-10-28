# FloatPlanWizard approved navigation reference

This directory is a dependency-free, runnable **visual and behavioral reference** for Codex. Open `index.html` in a browser. It is **not a production drop-in**: navigation targets are intentionally unmapped, search is simulated, and the Chesapeake body is not replaced. The original mockup is the visual authority; assets are local self-contained derivatives prepared for implementation. No third-party images are required.

## Visual authority
- `approved-navigation-mockup.png` — user-approved original design concept (exact visual target)
- `implementation-visual-reference.png` — detailed visual reference for header/open Explore menu and image assets
- `css/navigation.css` — fixed layout/visual styles reference
- `index.html` — accessible semantic desktop/mobile markup reference
- `js/navigation.js` — one-menu-at-a-time, click, outside click, Escape behavior
- `images/*` — local SVG icons and photographic crops generated for reference

## Integration rules
- Do not copy the full example page into FPW; port *only* the shared header/navigation structure, CSS, JS and images into existing CFML includes/components.
- Match every `data-destination` value to an **existing** actual authorized FPW URL; never guess URLs.
- Preserve current auth gating, logged-in navigation, feature flags, SEO URLs, canonical and sitemap rules.
- Keep the existing FPW logo artwork if it is higher fidelity than the provided reference logo mark.
- Do not modify screenshots, approved layout, categories, colors, spacing, iconography or wording without prior approval. If a hard limitation prevents exact reproduction, report it and stop.
- Screenshots in this bundle are a visual target, not assets to display as interactive navigation.
- Cropped photos are reference assets from the generated artwork; test crop suitability at each breakpoint and request approval before substitutions.
