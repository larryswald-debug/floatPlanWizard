# FPW Codex Project Rules

## Context
This repo is Float Plan Wizard (FPW).
- Server: ColdFusion (CFML/CFC)
- Client: Vanilla JavaScript (no jQuery), Bootstrap UI
- Webroot: /fpw

## Where things live
- Pages: /fpw/app/
- Includes: /fpw/includes/
- JS: /fpw/assets/js/app/
- APIs: /fpw/api/v1/ (CFC endpoints)

## API conventions
- APIs are CFCs in /fpw/api/v1/
- Authentication is session-based (see api/v1/me.cfc + api/v1/auth.cfc)
- All API responses are JSON and include SUCCESS and AUTH flags when applicable
- Do not change existing response key casing conventions used by the app
- Use cfsetting enablecfoutputonly + cfcontent application/json; charset=utf-8

## Front-end conventions
- Use the existing dashboard structure in /fpw/app/dashboard.cfm
- Use /fpw/assets/js/app/dashboard.js patterns (DOM IDs, rendering, alerts)
- Do not change UI layout/styling unless explicitly asked
- Prefer updating specific functions over rewriting whole files

## Output rules
- Default to DIFF or “function-only” output unless asked for full file
- No long explanations unless explicitly requested
