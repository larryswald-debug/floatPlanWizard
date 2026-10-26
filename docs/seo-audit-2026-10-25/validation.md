# Audit artifact validation — 2026-10-25

- Application source baseline: main at 94e20aa374a43959fa0be7f8ee1bd5819c588d7a; initial working tree clean.
- Final Git status: only the new docs/seo-audit-2026-10-25/ directory is untracked. No tracked file changes, staged changes or commits.
- git diff --check passed (tracked-file whitespace gate; does not validate untracked Markdown).
- Parsed every delivered CSV/JSON and the captured sitemap XML. Findings have 12 unique IDs and all required fields populated.
- URL inventory: 1,269 observations / 1,262 distinct requested URLs. Seven query URLs have multiple observation timestamps.
- Recheck ledger: 195 pairs, 178 query responses 200 and 17 query responses 404; the persistent-port subset has exactly 17 rows.
- PDF inventory: 17 rows. Browser sample inventory: 14 rows, seven URLs at two widths.
- Verified recorded input hashes against current source/export files. Checked report-local links and source path existence.
- Checked narrative counts and search arithmetic against recorded data; kept query coverage and missing absolute dates explicit.
- Only audit artifacts were edited. All fixes are recommendations, not implemented or validated fixes.

No application test suite, live authenticated route test, production configuration change, index submission or real-device test was performed. The local ColdFusion runtime was unavailable. See audit.md for detailed methodology and limitations.
