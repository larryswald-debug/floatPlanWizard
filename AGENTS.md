# Repository Guidelines

## Project Structure & Module Organization
- `app/`: ColdFusion pages (CFML) that render views like `app/dashboard.cfm`.
- `api/v1/`: CFC API endpoints; responses are JSON and follow existing key casing.
- `assets/`: Front-end assets. Primary JS lives in `assets/js/app/`.
- `includes/`: Shared CFML partials and helpers.
- `tests/`: Playwright end-to-end tests (see `tests/e2e/`).

## Build, Test, and Development Commands
- `npm install`: Install dev dependencies (Playwright).
- `npx playwright test`: Run all Playwright tests in `tests/`.
- `npx playwright test tests/e2e/smoke.spec.js`: Run the smoke suite only.
- ColdFusion server: run the app at `http://localhost:8500` (see `playwright.config.js`).

## Coding Style & Naming Conventions
- Indentation: follow existing file style (CFML and JS commonly use 2 spaces).
- JavaScript: vanilla JS (no jQuery) and Bootstrap UI conventions.
- API responses: JSON with `SUCCESS` and `AUTH` flags when applicable; keep key casing.
- Avoid broad refactors; update focused functions/blocks to preserve layout and behavior.

## Testing Guidelines
- Framework: Playwright (`@playwright/test`).
- Test location: `tests/` with specs like `*.spec.js`.
- Naming: keep descriptive names (e.g., `smoke.spec.js` for critical flow coverage).
- Base URL is `http://localhost:8500`; adjust only if the local server differs.

## Commit & Pull Request Guidelines
- Commit messages are short and descriptive (see recent history: “re aligned the dashboard”).
- Prefer imperative, lowercase subject lines; keep to one line when possible.
- PRs should include: purpose, key changes, and any UI screenshots if visuals changed.

## Agent-Specific Instructions
- Follow the project rules in `codex.project.md`, especially API and UI conventions.
- Default to diff-style or function-only output unless asked for full files.
