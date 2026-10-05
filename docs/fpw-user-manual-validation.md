# FPW Member Manual — Implementation and Validation

Date: October 4, 2026. Local development only.

## Public-access correction — October 4, 2026

The owner subsequently requested that everyone be able to read the manual. This replaces the original requirement for an authenticated manual.

The original `app/user-manual.cfm:2` included `includes/require_auth.cfm`. That guard redirects a request without a recognized session user to `/index.cfm?notice=member-required`, matching the reported notice. MCPCFC reproduced HTTP 302 before the change. The user's specific browser session was not inspected, so this does not diagnose why a session they expected to be signed in was not recognized.

The narrow fix replaces that include with `includes/fpw_base_path.cfm`, which supplies the existing URL base without an authentication gate. The Help introduction no longer says **Sign-in required**. Only `app/user-manual.cfm`, `app/help.cfm`, and this validation record changed in this correction. The 27 chapters, Markdown manual, CSS, JavaScript, shared authentication service, and other page guards were preserved.

Pre-edit checksummed snapshots and Git state are in:

`/Users/lawrencewald/.codex/backups/fpw-manual-public-GpyDKk`

Follow-up validation through MCPCFC and MCP Playwright:

- Direct unauthenticated manual request: HTTP 200, with no redirect.
- A fresh isolated browser with zero initial cookies rendered all 27 chapters and no member-required notice.
- Anonymous Help → manual navigation worked. Exactly one manual link exists; the restriction text is absent.
- Search for **secure night** showed three chapters; Clear restored all 27.
- Desktop at 1440 × 1000 and phone at 390 × 844 rendered successfully. The phone page had no document-level horizontal overflow.
- No browser console or page errors were observed.
- A signed-out Dashboard request still returned HTTP 302 to the member-required entry.
- `git diff --check` passed. No accounts or other database fixtures were created for this correction; the isolated browser context was closed.

The backup directory contains `manual-public-desktop.png` and `manual-public-phone.png`. This is local public-access proof; production and the user's original signed-in browser session were not tested. The original authentication results below are retained as historical evidence, not as the current manual access rule.

## Delivered scope

The requested member manual is available in two formats:

- [Markdown manual](fpw-user-manual.md).
- [Public application page](../app/user-manual.cfm), served locally at `http://localhost:8500/fpw/app/user-manual.cfm`.
- The existing Help introduction links to **Open the complete member manual**.

Both versions contain the same 27 chapters in nine parts and 18 worked scenarios. The web page adds chapter search, contents navigation, responsive tables, keyboard focus, and a print layout. Companion, administration, and internal diagnostic procedures are excluded from the member instructions.

The chosen implementation follows the approved conservative documentation approach: explain confirmed primary workflows and explicitly describe the current accuracy limits. No application behavior was changed to make the documentation easier to write.

## Exact file scope

| File | Change |
|---|---|
| `docs/fpw-user-manual.md` | New complete member manual. |
| `app/user-manual.cfm` | New public manual; shared FPW page layout and static chapter markup. |
| `assets/css/user-manual.css` | New scoped reading, contents, responsive-table, focus, and print styles. |
| `assets/js/app/user-manual.js` | New vanilla-JavaScript chapter filtering, Clear/Escape, hash handling, and native-print control. |
| `app/help.cfm` | One introductory paragraph linking to the public manual. Existing Help content and search remain unchanged. |
| `docs/fpw-user-manual-validation.md` | This implementation and validation record. |

`docs/fpw-user-manual-discovery-plan.md` was already untracked at the start of this writing phase. Its checksum remains unchanged. It retains the detailed feature matrix, source inventory, owner-only Companion appendix, screenshot plan, and unresolved-experience record.

No API, schema, configuration, dependency, billing, mail, recovery, trip, or Companion implementation files changed. No commit or push was performed during this writing phase.

## Execution path and implementation choices

The reader follows **Help → Open the complete member manual**. The page includes `includes/fpw_base_path.cfm` before its HTML and uses the existing shared header styles, top navigation, footer, and footer scripts. It does not require authentication; account and trip operations retain their existing authentication requirements. It sends `Cache-Control: no-store` and a noindex/nofollow directive.

The Markdown and static CFML chapter markup were created from the same chapter collection. There is no runtime Markdown parser or additional dependency. A source comment in the CFML identifies the Markdown counterpart for future synchronized edits.

The script reads only the manual's own text. Search changes chapter and contents visibility; it does not call an API or modify account state. Search output uses `textContent`, including user-entered search text. All chapters remain readable without JavaScript. Printing includes all chapters even if a search filter is active.

Chapter and contents offsets accommodate the shared sticky header. Wide tables scroll inside the document instead of widening the phone viewport. Focusable table regions support keyboard access. Table headings have column scope and chapters have labelled headings.

## Content coverage

| Chapters | Coverage |
|---|---|
| 1–2 | Current Dashboard navigation, setup readiness, saved information, and first-trip sequence. |
| 3–7 | Vessels, operators, passengers/crew, shore contacts, waypoints, required fields, reuse, and deletion restrictions. |
| 8–14 | My Routes, current Route Generator, persistence boundaries, geometry, Great Loop references, assumptions, estimates, weather, and independent fuel calculator. |
| 15–17 | Six-step Dashboard Wizard, saved PDF, Basic/Premium sending, access/credits, uncertainty, Follow sharing, and voyage updates. |
| 18–21 | Active Cruise, check-ins, monitoring, delays, overnight timing, leg operations, private/public notes, and contact links. |
| 22–23 | Explicit successful closure, cancellation, notices, and the read-only completed record. |
| 24–25 | Profile, home port, passwords, membership, Help, and smaller-screen use. |
| 26–27 | Eighteen worked scenarios, common problems, trip states, and monitoring states. |

The source-backed distinctions retained throughout include:

- Main Review Basic sends a PDF to one selected saved contact and preserves the Draft without operational activation.
- Premium sending activates the eligible trip; purchasing access does not itself send.
- **Upgrade to Premium Send** can immediately begin saving/sending when access is available. It is not merely navigation back to an option. Final independent source review corrected this wording in both versions.
- Sharing a Follow link is separate from the initial PDF email.
- Scheduled departure, actual departure, estimated arrival, explicit leg completion, and final closure are separate.
- Delayed, Add Delay Time, Secure Night, and Daily Start Time have distinct effects.
- Progress and position displays are not continuous GPS tracking or proof of arrival.
- SMTP submission is not proof of recipient delivery.
- The completed-trip owner page has a verified email entry; no Dashboard history tab is invented.

### Current product ambiguities handled in the prose

The vessel form's KPH labels conflict with the planner's knots labels. The manual warns about this mismatch and does not claim an automatic conversion. It does not change performance values or unit handling.

The primary instructions use the Dashboard's six-step Wizard. If checkout returns to the other Wizard, the manual directs the member back to the Dashboard workflow and does not combine its alternate Basic behavior with Review Basic.

The manual uses the route summary's Final Arrival for the complete route. It does not equate that with the current-leg ETA.

Unverified weather-favorite, Follow Privacy, and Follow Text Link behavior is not taught as working functionality. The verified Dashboard share path is used.

Companion is absent from the member manual because it is not currently member available.

## Backup evidence

Pre-edit snapshot directory:

`/Users/lawrencewald/.codex/backups/fpw-user-manual-qY0d4b`

The snapshot includes the original Help page, the pre-existing discovery document, a baseline record of Git state and absent new targets, and `SHA256SUMS`.

| Snapshot file | SHA-256 |
|---|---|
| `app/help.cfm` | `47d6ccbfef4bcc0b68f37f691471c0327687ea4cbb1e22aaf08b97b28a76639f` |
| `docs/fpw-user-manual-discovery-plan.md` | `3d016dfeb331739420a00c30ccfed748b8c51391d3f3ada688e19ff86e871815` |
| `baseline.json` | `aa13d5932da540674a4154afc7508b15b0ae9e0c71d443da18198d7ef2539e20` |

Baseline HEAD: `df1c42a886075dd433fdf21201df40ee266e3445`, on `main`, aligned with `origin/main`. The discovery document was the only initial untracked file. Existing files were covered before edits; MCPCFC exact patches also generated their normal snapshots.

## Validation performed

Repository and runtime inspection used MCPCFC. Browser proof used MCP Playwright. Shell use was limited to Git checks, Node syntax checking, and checksum/backup work.

### Original authenticated-page validation (before public-access correction)

| Check | Observed result |
|---|---|
| Signed-out request to the manual | HTTP 302 to `/fpw/index.cfm?notice=member-required`; no manual body returned. |
| Signed-in request with a fresh disposable modern-hash account | HTTP 200; correct manual title and all 27 chapters. |
| Response caching | `Cache-Control: no-store`. |
| Help entry | One matching new manual link; navigation opens the authenticated 27-chapter page. |
| JavaScript disabled | Authenticated page returns 200 and all 27 chapters remain visible; inactive search controls stay hidden; contents anchors work. |
| Runtime and console errors | None observed during the authenticated manual checks and final reload. |

### Search, navigation, print, and presentation

- Search filters chapters and their matching contents links. No-result messaging, Clear/focus, and Escape were checked.
- An HTML-like search string remained text; it did not create an image element.
- All manual fragment links resolve to existing elements. The page has no duplicate IDs.
- Contents navigation was checked beyond URL changes: the destination heading settles below FPW's sticky header on desktop and phone.
- Navigating to a hidden chapter by fragment clears the search and reveals the chapter.
- The print button invokes the browser's print function once. Print-media emulation shows all 27 chapters during an active search and hides search/contents controls.
- There are 13 manual tables; all column headers have scope. A 460px table scrolls inside a 328px phone content region.
- Keyboard focus reaches the scrollable table region.
- Desktop at 1440 × 1000, tablet at 768px, and phone at 390 × 844 were checked. Tablet and phone pages had no document-level horizontal overflow.
- The saved Markdown and CFML matched the shared final chapter sources. The Markdown contains all 27 chapter texts, 18 scenarios, no private filesystem paths or test account details, and no Companion instructions.

Visual evidence is stored outside the repository in the snapshot directory:

- `manual-desktop.png`
- `manual-desktop-chapter.png`
- `manual-phone.png`
- `manual-phone-chapter.png`

The chapter screenshots were visually inspected. They show readable text, correctly offset headings, the desktop contents panel, and contained phone table scrolling.

### Source review

The existing discovery report remains the complete inspection inventory. Focused writing-phase checks covered the current Dashboard forms and navigation, route modal/controller, Wizard controller, standalone Wizard return link, Account controller, Weather page/controller, active/monitoring/completed surfaces, and authentication guard/layout conventions.

Independent reviews checked vessel/planning/weather/calculator instructions and the Wizard/send/access/Follow/Account/scenario/troubleshooting text. Exact-label checks included **Leg Sequence**, **Edit Route**, **Open NOAA Map**, **Back to Dashboard**, and **Home port saved.** The final review found and corrected the Premium upgrade wording described above.

These are source and manual-page validations. They are not evidence that every boating workflow was executed in a browser during this documentation task.

### Disposable data and cleanup

Browser proof used the existing local-only, POST/confirmation-guarded `tests/auth-endpoint-security-fixture.cfm` in an isolated browser context. Its setup creates four disposable users; only the fresh modern-hash change-role account was used for sign-in.

Fixture run: `0f93210049065925e021719168faacf5`.

Fixture cleanup returned HTTP 200 with `SUCCESS=true` and `CLEANED=true`. A subsequent MCPCFC database query confirmed:

- Zero users matching that fixture's exact email prefix.
- Zero product events for its four user IDs (6273–6276).

The fixture cleanup also invokes its existing account-bound auth-counter cleanup. The isolated authenticated browser contexts were closed. The original browser tab/session was left separate.

No member trip, check-in, payment, Premium send, or mail transport action was performed for this manual-page proof.

### Repository checks

- `node --check assets/js/app/user-manual.js` passed.
- `git diff --check` passed after removing tool-added trailing blank lines.
- `git diff --no-index --check /dev/null <new-file>` checked each new implementation file without whitespace diagnostics. Exit 1 for those commands means the new file differs from the empty file.
- The pre-existing discovery document's checksum still equals its pre-edit snapshot.
- The tracked Help diff contains only the approved new paragraph.

No application engine suite was run: this task changed documentation and the manual presentation only. No pre-existing application test failure was discovered by these limited checks. Early browser harness attempts required correction for the tool's function wrapper, transient context handling, and numeric CSS IDs; they were test-code errors, not application defects. An initial whitespace check found a tool-added blank line at Help's EOF; it was corrected and the check passed.

## Limitations and publication evidence

The manual is text-complete for the approved primary web workflow. The 26 application screenshot subjects and callouts remain in the discovery report's capture plan; they were not captured or embedded into the member manual. The screenshots above validate the new manual interface itself.

The eighteen scenarios are written procedures, not eighteen executed end-to-end tests. Product form success/error paths, sending, billing, operational trip transitions, and device-specific touch behavior were not reenacted during this writing phase. Production deployment and production member behavior were not tested.

The print controls and print-media visibility were tested; a paginated PDF export was not produced or visually audited page by page.

Known product ambiguities were documented, not repaired. Future edits should update both prose versions together and repeat the manual-page checks.

## Final working-tree scope

Expected final status for this writing phase:

```text
 M app/help.cfm
?? app/user-manual.cfm
?? assets/css/user-manual.css
?? assets/js/app/user-manual.js
?? docs/fpw-user-manual-discovery-plan.md
?? docs/fpw-user-manual-validation.md
?? docs/fpw-user-manual.md
```

The discovery file predates this phase. All remaining entries belong to the requested manual implementation. Changes remain uncommitted.
