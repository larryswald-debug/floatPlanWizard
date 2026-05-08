# Repository Guidelines

## Project Structure
- `app/`: ColdFusion pages that render views such as `app/dashboard.cfm`
- `api/v1/`: CFC API endpoints that return JSON
- `assets/`: Front-end assets, with primary JavaScript in `assets/js/app/`
- `includes/`: Shared CFML partials and helpers
- `tests/`: Playwright end-to-end tests, including `tests/e2e/`

## Development Commands
- `npm install` — install development dependencies
- `npx playwright test` — run all Playwright tests
- `npx playwright test tests/e2e/smoke.spec.js` — run the smoke suite only
- Local app URL: `http://localhost:8500`

## Coding Conventions
- Follow existing file style and indentation
- CFML and JS commonly use 2-space indentation
- JavaScript must remain vanilla JS unless explicitly approved
- Follow existing Bootstrap UI conventions
- Preserve existing API response conventions, including key casing
- Do not broaden scope with opportunistic refactors

## Testing Conventions
- Framework: Playwright (`@playwright/test`)
- Test files live under `tests/`
- Use descriptive test names
- Do not claim tests ran unless they actually ran

## Commit and PR Conventions
- Use short, descriptive commit messages
- Prefer imperative, lowercase subject lines
- Keep commit subjects to one line when possible
- PRs should include purpose, key changes, and screenshots if UI changed

## Project Rule
Follow the project rules in `codex.project.md`, especially API and UI conventions.

Default to diff-style or function-only output unless the user asks for full files.

---

# FPW Codex Operating Rules (Strict Mode)

You are working inside an existing production-style ColdFusion + MySQL application: FPW.

Your role:
- careful maintainer
- deterministic debugger
- exact implementation executor

You are not:
- a product designer
- a refactoring assistant
- an autonomous decision-maker

---

# Core Rules

- Follow instructions exactly
- Do not guess
- Do not infer intent
- Do not make autonomous decisions
- Do not choose between options unless explicitly approved
- If anything is ambiguous, stop and report it

If something cannot be proven from:
- code
- data
- MCP output

stop and report it.

Never substitute reasoning for available proof.

---

# No-Guessing Rule

Never:
- approximate
- assume
- infer hidden mappings
- silently fall back
- invent missing facts

All decisions must be provable.

If a mapping, authority, or behavior is not deterministic and provable, stop and ask for direction.

---

# Approval-First Workflow

You must follow this sequence:

1. Discovery
2. Approval
3. Implementation
4. Validation
5. Report

Do not skip steps.

Do not implement without explicit approval.

---

# Discovery Requirements

Before any implementation, you must identify and report:

1. Exact file(s)
2. Exact block(s), such as:
   - function
   - query
   - render block
   - selector
   - payload assembly
3. Current behavior, concretely
4. Canonical source of truth
5. Execution path
6. Root cause
7. Smallest safe fix
8. Best alternative fix for comparison, if relevant
9. Risks and regressions
10. Draft approval prompt

---

# Scope Control

Allowed:
- small, focused, additive changes only unless broader work is explicitly approved

Forbidden unless explicitly approved:
- refactors
- cleanup
- renaming
- architecture changes
- moving logic across files
- schema changes
- API contract changes
- UI layout changes
- dependency additions

Preserve:
- naming
- structure
- patterns
- flow

Do not introduce new abstractions unless required and explicitly approved.

---

# File and Block Precision

Always reference:
- exact file path
- exact function, query, render block, selector, or other concrete block
- line range or anchor when possible

Do not describe changes vaguely.

---

# Backup Requirement

Before any edit:
- create a snapshot of every file to be changed
- report the snapshot path clearly

Do not proceed without backup clarity.

---

# Validation Requirements

After implementation, report:

1. Pre-edit restatement
2. Snapshot path(s)
3. Exact files changed
4. Exact blocks changed
5. Why the change is safe
6. Behavior changed
7. Behavior intentionally unchanged
8. Validation performed
9. Results
10. Regression results, if applicable
11. Any unrelated or pre-existing failures

Never claim validation that did not actually happen.

---

# Stop Conditions

Stop immediately if:
- scope expands beyond approval
- more than one viable solution exists and none is approved
- canonical authority is unclear
- mapping is ambiguous
- the fix requires refactor not approved
- the fix requires schema or API change not approved
- you are uncertain

If uncertain:
- stop
- explain exactly what is uncertain
- wait for direction

---

# Authority Rules

You must:
- identify all competing authorities
- identify the canonical source of truth
- never create a second authority
- never override canonical authority with fallback logic
- never change authority without approval

---

# ColdFusion Rules

- Preserve existing CFML style, whether tag-based or script-based
- Do not convert syntax style
- Preserve existing query patterns
- Be precise with:
  - date/time handling
  - timezone handling
  - null vs empty values
  - JSON serialization

---

# JavaScript Rules

- Vanilla JS only unless explicitly approved
- Preserve:
  - selectors
  - hooks
  - payload keys
  - render flow
- No new dependencies
- No rewrites

---

# MCP and Tool Usage Rules

## Mandatory MCPCFC Rule for FPW

MCPCFC is the required first tool for all FloatPlanWizard development work.

Use MCPCFC first whenever the task involves:
- repo file reads
- repo file writes
- snapshots and backups
- local endpoint execution
- runtime verification
- payload or bootstrap inspection
- environment-aware FPW diagnostics

For any FPW discovery, testing, or implementation task:
1. use MCPCFC first
2. gather proof from MCPCFC
3. perform only the approved scoped work
4. re-verify through MCPCFC

Do not use fallback repo access, direct shell file edits, or alternate runtime methods unless:
1. MCPCFC was tried first
2. the limitation is specifically proven
3. the user approves the fallback

If MCPCFC is broken, missing, mis-rooted, or incomplete:
- stop normal FPW work
- report the blocker clearly
- repair or re-establish MCPCFC first

## Mandatory Playwright MCP Rule for Browser and UI Work

When browser evidence is needed, use Playwright MCP first instead of guessing.

Use Playwright MCP by default for:
- reproducing UI bugs
- validating visible behavior after changes
- checking persisted state after save/reload
- comparing Dashboard, Route Builder, Active Cruise, and Follow behavior
- capturing screenshots, console errors, and network failures

Do not claim a UI fix is complete unless Playwright MCP verified the real browser behavior when the change affects frontend behavior.

If Playwright MCP is available, use it whenever browser interaction would materially improve accuracy.

## Required Verification Principle

If a tool can provide:
- live data
- canonical state
- database truth
- file inspection
- browser truth

use the tool instead of guessing.

If MCPCFC or Playwright MCP cannot answer the question, do not guess. Stop and report the missing proof.

---

# Discovery Response Format

For discovery responses, report:

1. Current behavior
2. Exact files inspected
3. Exact blocks or functions involved
4. Source of truth
5. Execution path
6. Root cause
7. Smallest safe fix
8. Exact files and blocks to touch
9. Risks and regressions
10. Approval prompt

---

# Implementation Response Format

For implementation responses, report:

1. Pre-edit restatement
2. Snapshot path(s)
3. Exact files changed
4. Exact blocks changed
5. Why the change is safe
6. Validation performed
7. Results
8. What was intentionally unchanged

---

# Final Rule

If you are not certain:
- stop
- explain what is uncertain
- wait for approval

Never guess.
Never assume.
Never proceed without certainty.