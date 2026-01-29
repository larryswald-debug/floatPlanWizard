# FloatPlanWizard (FPW) – Codex Context

This file is the authoritative orientation document for AI assistants (Codex).
READ THIS FILE FIRST before scanning or modifying the repository.

======================================================================

## What this repo is

FloatPlanWizard.com (FPW) is a ColdFusion + MySQL web/mobile application.

Primary purpose:
- Create and manage float plans
- Monitor float plans on a schedule
- Detect check-in due and overdue conditions
- Notify designated contacts automatically
- Surface monitoring and alert status in a dashboard UI

This is an active, production-oriented project.
Avoid speculative refactors or invented patterns.

======================================================================

## Local Development (Docker)

FPW runs entirely in Docker for local development.

### Start (build + run)
docker compose up -d --build

### Start (run without rebuilding)
docker compose up -d

### Stop containers (keep data)
docker compose stop

### Stop and remove containers (KEEP database data)
docker compose down

### Stop and remove containers AND volumes (DELETES DATABASE DATA)
docker compose down -v

======================================================================

## Inspecting the Running Stack

### List services and container state
docker compose ps

### List service names (use for logs/exec)
docker compose config --services

### View logs (all services)
docker compose logs -f

### View logs for a single service
docker compose logs -f <service>

### Enter a running container shell
docker compose exec <service> sh
# or if bash exists:
docker compose exec <service> bash

======================================================================

## Database Access (MySQL – typical pattern)

If the MySQL service is named `db`:

docker compose exec db mysql -u root -p

If environment variables are configured:

docker compose exec db mysql -u root -p"$MYSQL_ROOT_PASSWORD"

======================================================================

## App Access (Local URL)

To discover the local app URL and port:

docker compose ps

Look under the PORTS column (e.g. `0.0.0.0:8500->8500/tcp`).

Typical examples:
- http://localhost:8500
- http://localhost:8080

======================================================================

## Project Structure (Entry Points)

- app/
  ColdFusion `.cfm` pages (primary web UI)

- api/v1/
  API endpoints implemented as CFCs

- assets/js/app/
  Front-end JavaScript modules (dashboard, monitoring UI)

- includes/
  Shared CFML utilities, helpers, mailers

- tests/
  TestBox specs and Playwright tests

======================================================================

## Monitoring System (High Level)

Monitoring is an automated watchdog that:

1. Runs on a schedule (CF scheduled task or triggered endpoint)
2. Queries active/open float plans
3. Computes time-based state:
   - Not yet due
   - Check-in due
   - Overdue
4. Sends notifications (email baseline)
5. Logs notifications to prevent duplicates
6. Surfaces monitoring state in the dashboard

Key rules:
- Time logic must be consistent across save/edit/monitor
- Notifications must be idempotent (no repeated spam)
- Monitoring state is derived, not manually set

======================================================================

## Tests

- Uses TestBox (and Playwright where applicable)
- Tests validate time logic, API contracts, and monitoring behavior

### Known failing test (last working state)
- FloatPlanSaveTimeShiftSpec.cfc
- Error: `Element SUCCESS is undefined in BEFORE`

This indicates a mismatch between:
- expected response shape in the test
- current API/service return structure

Assume implementation is likely correct and the test needs alignment,
unless proven otherwise.

======================================================================

## Rules for Codex (Do Not Ignore)

1. Search for existing patterns before writing new code
2. Do NOT refactor unless explicitly requested
3. Keep diffs minimal and match existing style
4. Do NOT invent endpoints, tables, or config values
5. If unsure, ask targeted clarification questions before changing code

======================================================================

## Current Focus

- Monitoring reliability
- Time-based logic correctness
- Notification dedupe and logging
- TestBox stability and contract alignment
- Dashboard/API hardening

======================================================================

END OF CONTEXT

