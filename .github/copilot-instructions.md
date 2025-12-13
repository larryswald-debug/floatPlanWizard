# Copilot instructions — FPW ColdFusion app

This file gives concise, actionable guidance for AI coding agents working in this repository.

1) Big picture
- ColdFusion (CFML) web app. Server-side API endpoints are ColdFusion components in `api/v1/*.cfc`.
- Frontend lives under `assets/js/app/*` and CFM pages under `app/*.cfm`. `Application.cfc` enforces session rules.
- Database datasource name: `fpw` (CF datasource configured in CF Admin). SQL calls use `<cfquery datasource="fpw">`.

2) Common request/response conventions
- Each CFC exposes a remote `handle` method and returns JSON. Endpoints are called like:
  `/fpw/api/v1/auth.cfc?method=handle` (client code builds `/api/v1` base automatically).
- JSON payload keys/shape are important: responses commonly include `SUCCESS`, `MESSAGE`, `ERROR`, and sometimes `USER`/`PROFILE`.
- Many endpoints call `serializeJSON(response)`, output it, then `cfabort` — avoid adding extra output after those calls.

3) Authentication & session shape
- Session-based auth: `session.user` is set on login. The code intentionally duplicates keys in several casings:
  `id`, `userId`, `USERID`, `email`, `EMAIL`, `firstName`, `FIRSTNAME`, `lastName`, `LASTNAME`.
- When updating responses or session objects, preserve these fields so frontend and other CFCs can access them regardless of case.

4) Password & security patterns
- Passwords are stored as SHA-256 hex (uppercase in some flows). Legacy plaintext rows are tolerated.
- When creating/updating passwords follow existing behavior: `ucase(hash(password, "SHA-256", "UTF-8"))` for storage.
- SQL queries use `cfqueryparam` with explicit types — follow this pattern to avoid regressions.

5) Frontend API client details
- `assets/js/app/api.js` computes `API_BASE` by inspecting the first path segment; can be overridden with `window.FPW_API_BASE`.
- Requests use `fetch` with `credentials: "include"` (relies on CF session cookie). Keep `returnFormat=json` behavior in mind — the client appends it when calling CFCs.

6) Error handling & control flow
- CFCs use `cftry/cfcatch` and return structured error JSON. Many handlers `cfabort` after writing JSON — do not change that flow unless updating all callers.

7) Developer workflows & quick checks
- Start a local CFML server (Adobe CF or Lucee) with webroot pointing to the repository parent so `/fpw` is reachable.
- Ensure a CF datasource named `fpw` is configured and points to the MySQL instance used by the project.
- Quick API smoke test (example):
  curl -i "http://localhost:8500/fpw/api/v1/auth.cfc?method=handle" \
    -H "Content-Type: application/json" \
    -d '{"action":"login","email":"you@example.com","password":"secret"}' \
    -c cookiejar

8) Files to inspect when making changes
- `Application.cfc` — session & routing enforcement for `/app/` pages.
- `api/v1/*.cfc` — server API implementations (auth, me, profile, homeport, password_reset).
- `assets/js/app/api.js` — browser API wrapper and `API_BASE` logic.
- `app/*.cfm` — frontend CFM pages that depend on server behavior.

9) Pull request guidance for AI changes
- Keep backward-compatible JSON shapes (`SUCCESS`, `MESSAGE`, `ERROR`).
- Preserve `session.user` casing variants and `fpw` datasource usage.
- Follow existing SQL param styles and `cfsetting enablecfoutputonly` / `cfcontent` pattern.

If any part of this repo's environment (CF server, datasource name, or webroot) is different locally, tell me the differences and I will update or expand these instructions.
