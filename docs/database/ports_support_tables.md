# Great Loop Ports Support Tables

This document describes the database-only foundation for the future FloatPlanWizard Great Loop Ports Library.

This phase only adds database support objects and import/validation documentation. It does not create public pages, public maps, API routes, waypoint UI changes, CSS, or JavaScript behavior.

## Read-Only Backend/API Phase

The follow-up backend phase adds a read-only JSON API and service layer for the imported support tables:

- `api/v1/ports.cfc`
- `api/v1/PortsLibraryService.cfc`

The endpoint is intentionally read-only and exposes `list`, `detail`, `filters`, and `quality` actions for future Ports Library UI work. It does not create public `/great-loop/ports/` pages, map JavaScript, CSS, navigation links, sitemap entries, waypoint save behavior, or Locks/Bridges behavior.

## Tables

### `ports`

Existing base table. The import script treats `ports.id` as the stable key from `ports_cleaned.csv`.

The import upsert is non-destructive:

- It does not truncate or delete `ports` rows.
- It inserts missing CSV seed rows by `id`.
- It updates safe base fields from CSV data.
- It preserves existing major/hidden-gem flags when they are already set.
- It does not use invalid CSV coordinates to overwrite existing usable coordinates.

### `port_profiles`

One row per port for details and classification.

Stores:

- `slug`
- normalized `state_code`
- `country`
- `waterway`
- `loop_segment`
- `mile_marker`
- `port_type`
- descriptive copy
- approach/service summary placeholders
- `data_quality_status`
- source notes and source URL
- review timestamps

This table is the main future source for public Great Loop port listing/detail metadata.

### `port_services`

One row per port for boater service availability.

Important value meanings:

```text
NULL = unknown / not verified yet
0    = verified no
1    = verified yes
```

Most initial service values are expected to be `NULL` because the CSV bundle intentionally avoids treating unverified services as false.

### `port_tags`

Flexible many-to-one tags for each port.

Tags can support later filtering, review workflows, and UI badges. Candidate/review/inferred tags should be rendered honestly in future UI; they should not be presented as fully verified facts without review.

### `port_nearby_assets`

Generic future link table from a port to nearby reference assets.

Expected future `asset_type` values may include:

```text
lock
bridge
tide_station
weather_station
marina
anchorage
```

The initial CSV has no nearby asset rows, so this table is expected to start empty.

## Migration

Migration file:

```text
db/migrations/20260705_ports_support_tables.sql
```

Run after backing up the database:

```bash
mysql -u USER -p DATABASE < db/migrations/20260705_ports_support_tables.sql
```

The migration uses:

- `CREATE TABLE IF NOT EXISTS`
- `ENGINE=InnoDB`
- `DEFAULT CHARSET=utf8mb4`
- `COLLATE=utf8mb4_unicode_ci`

It avoids MySQL 8-only collations and does not drop existing data.

Existing-table limitation: if a support table already exists with a different shape, `CREATE TABLE IF NOT EXISTS` will not retrofit missing indexes or foreign keys. Run the validation script and compare index output with the migration.

## Import Source

Expected source directory from the FPW repo root:

```text
imports/ports/fpw_ports_mysql_import_csv_bundle/
```

Expected import order:

1. `ports_cleaned.csv`
2. `port_profiles.csv`
3. `port_services.csv`
4. `port_tags.csv`
5. `port_nearby_assets.csv`

Supporting review/reference files:

```text
data_review.csv
source_catalog.csv
schema_notes.csv
import_order.csv
mysql_import.sql
```

## Import Script

Import file:

```text
db/seeds/ports/import_ports_support_tables.sql
```

Local development run:

```bash
mysql --local-infile=1 -u USER -p DATABASE < db/seeds/ports/import_ports_support_tables.sql
```

The script creates persistent staging tables named:

```text
fpw_port_ports_cleaned_stage
fpw_port_profiles_stage
fpw_port_services_stage
fpw_port_tags_stage
fpw_port_nearby_assets_stage
```

Then it loads CSV files into staging and upserts to production tables.

## Production Import Without LOCAL INFILE

Some hosts disable `LOAD DATA LOCAL INFILE`. In that case:

1. Run the migration.
2. Run the staging table creation section of `import_ports_support_tables.sql`.
3. Load each CSV into the corresponding staging table using host tooling.
4. Run the upsert section of `import_ports_support_tables.sql`.
5. Run validation and data-quality reports.

Do not manually import blank service values as `0`. Keep blanks as `NULL` or empty staging values so the upsert converts them to `NULL`.

## Validation

Validation file:

```text
db/seeds/ports/validate_ports_support_tables.sql
```

Run:

```bash
mysql -u USER -p DATABASE < db/seeds/ports/validate_ports_support_tables.sql
```

The validation script checks:

- table counts
- support table presence
- expected indexes/keys
- ports without profiles
- ports without service rows
- support rows without matching ports
- duplicate slugs
- duplicate tags per port
- null/blank slugs
- invalid coordinates
- `lat = 0 AND lng = 0`
- missing `data_quality_status`
- blank `loop_segment`
- rows marked `needs_review`
- rows marked `bad_coordinates`
- rows marked `derived_unverified`

## Data Quality Report

Report file:

```text
db/seeds/ports/data_quality_report.sql
```

Run:

```bash
mysql -u USER -p DATABASE < db/seeds/ports/data_quality_report.sql
```

The report has separate sections for:

1. Missing coordinates
2. Zero coordinates
3. Suspicious coordinates
4. Blank state/state_code
5. Blank region/loop segment
6. Duplicate names
7. Duplicate slugs
8. Rows marked `needs_review`
9. Rows marked `bad_coordinates`
10. Rows with no source URL
11. Rows with service fields still `NULL`
12. Rows with `is_major_port = 0` and no useful tags
13. Rows with `is_hidden_gem = 0` and no useful tags

## Data Quality Status Meanings

```text
verified
```

Source-backed and reviewed.

```text
derived_unverified
```

Derived from coordinate/state/name heuristics but not manually verified.

```text
needs_review
```

Should be reviewed before being treated as reliable.

```text
bad_coordinates
```

Coordinates are missing, zero, or obviously invalid.

```text
missing_coordinates
```

No usable coordinates.

```text
duplicate_name_review
```

Duplicate or ambiguous port name.

Do not remove suspicious rows automatically. Mark them for review and keep them out of public/map experiences until later application logic decides how to handle them.

## Expected Counts From Current CSV Bundle

Current bundle discovery found:

```text
ports_cleaned.csv: 185 data rows
port_profiles.csv: 185 data rows
port_services.csv: 185 data rows
port_tags.csv: 1091 data rows
port_nearby_assets.csv: 0 data rows
data_review.csv: 171 data rows
```

After import, expected table counts should be near:

```text
ports: about 185 depending on existing local data
port_profiles: 185
port_services: 185
port_tags: 1091
port_nearby_assets: 0 initially
```

The CSV bundle is the source of truth. Do not hardcode these counts in application logic.

## Intentionally Not Included Yet

This phase intentionally does not include:

- public Great Loop ports pages
- `/great-loop/ports/` routes
- public map UI
- map JavaScript
- CSS changes
- waypoint UI changes
- `api/v1/waypoint.cfc` changes
- `assets/js/app/api.js` changes
- Locks or Bridges behavior changes
- Stripe changes
- monitoring changes
- float plan save/send changes

## Next API / Front-End Phase

A later phase can build on these tables by adding:

- read-only Great Loop Ports API endpoints
- admin review workflows for `data_quality_status`
- public listing/detail pages
- map markers that exclude bad/missing coordinates by default
- UI labels that distinguish verified facts from derived/unverified data
- links from ports to nearby locks, bridges, tide stations, weather stations, marinas, and anchorages
- waypoint integration only after separate approval


