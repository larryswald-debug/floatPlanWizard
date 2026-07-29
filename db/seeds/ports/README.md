# Great Loop Ports Support Table Seeds

This directory contains database-only seed/import support for the Great Loop Ports Library support data.

This phase does not create public pages, map UI, API routes, waypoint UI changes, or front-end behavior.

## Source CSV Bundle

Expected local source path from the FPW repo root:

```text
imports/ports/fpw_ports_mysql_import_csv_bundle/
```

Expected files:

```text
ports_cleaned.csv
port_profiles.csv
port_services.csv
port_tags.csv
port_nearby_assets.csv
data_review.csv
source_catalog.csv
schema_notes.csv
import_order.csv
mysql_import.sql
```

## Actual CSV Counts Observed During Discovery

These counts are CSV data rows, excluding headers:

| CSV | Data rows |
| --- | ---: |
| `ports_cleaned.csv` | 185 |
| `port_profiles.csv` | 185 |
| `port_services.csv` | 185 |
| `port_tags.csv` | 1091 |
| `port_nearby_assets.csv` | 0 |
| `data_review.csv` | 171 |

The local development database had 185 existing `ports` rows during discovery. The import script upserts by `ports.id` and inserts missing seed rows without truncating `ports`.

## Import Order

1. Run the support-table migration.
2. Load `ports_cleaned.csv` into staging.
3. Load `port_profiles.csv` into staging.
4. Load `port_services.csv` into staging.
5. Load `port_tags.csv` into staging.
6. Load `port_nearby_assets.csv` into staging.
7. Upsert staging data into `ports` and the four support tables.
8. Run validation and data-quality report SQL.

## Local Development Import

From the FPW repo root, after backing up the database:

```bash
mysql --local-infile=1 -u USER -p DATABASE < db/migrations/20260705_ports_support_tables.sql
mysql --local-infile=1 -u USER -p DATABASE < db/seeds/ports/import_ports_support_tables.sql
mysql -u USER -p DATABASE < db/seeds/ports/validate_ports_support_tables.sql
mysql -u USER -p DATABASE < db/seeds/ports/data_quality_report.sql
```

The import script uses relative CSV paths such as:

```text
imports/ports/fpw_ports_mysql_import_csv_bundle/ports_cleaned.csv
```

If your MySQL client runs from a different working directory, edit the `LOAD DATA LOCAL INFILE` paths before running.

## Staging / Production Fallback

Do not assume production has `LOAD DATA LOCAL INFILE` enabled.

If `LOCAL INFILE` is disabled:

1. Run `db/migrations/20260705_ports_support_tables.sql`.
2. Run only the staging table creation section of `db/seeds/ports/import_ports_support_tables.sql`.
3. Load each CSV into its matching staging table with host-approved tooling:
   - `ports_cleaned.csv` -> `fpw_port_ports_cleaned_stage`
   - `port_profiles.csv` -> `fpw_port_profiles_stage`
   - `port_services.csv` -> `fpw_port_services_stage`
   - `port_tags.csv` -> `fpw_port_tags_stage`
   - `port_nearby_assets.csv` -> `fpw_port_nearby_assets_stage`
4. Run the upsert section of `db/seeds/ports/import_ports_support_tables.sql` starting at section `4. Upsert staged CSV data into production tables`.
5. Run the validation and data-quality report scripts.

The staging tables are named with `fpw_port_*_stage` and are not public application tables.

## Non-Destructive Behavior

The import script does not truncate or delete from these production tables:

```text
ports
port_profiles
port_services
port_tags
port_nearby_assets
```

It only truncates staging tables. The production upsert keeps suspicious rows and marks them with `data_quality_status` instead of deleting them.

## Service Boolean Meaning

Service columns in `port_services` are nullable by design:

```text
NULL = unknown / not verified yet
0    = verified no
1    = verified yes
```

Do not convert blank CSV service values to `0`.

## Data Quality Status Values

Use these meanings when reviewing rows:

| Status | Meaning |
| --- | --- |
| `verified` | Source-backed and reviewed. |
| `derived_unverified` | Derived from coordinate/state/name heuristics but not manually verified. |
| `needs_review` | Should be reviewed before being treated as reliable. |
| `bad_coordinates` | Coordinates are missing, zero, or obviously invalid. |
| `missing_coordinates` | No usable coordinates. |
| `duplicate_name_review` | Duplicate or ambiguous port name. |

Suspicious rows should remain in the database until manually reviewed.

## Files In This Directory

| File | Purpose |
| --- | --- |
| `import_ports_support_tables.sql` | Creates staging tables, optionally loads CSVs, and upserts support data. |
| `validate_ports_support_tables.sql` | Counts and relational integrity checks after import. |
| `data_quality_report.sql` | Manual data review queries for questionable records. |

## Validation Queries

Run:

```bash
mysql -u USER -p DATABASE < db/seeds/ports/validate_ports_support_tables.sql
```

Review all non-empty issue sections. Expected post-import table counts should be close to:

```text
ports: about 185 depending on existing local data
port_profiles: 185
port_services: 185
port_tags: 1091
port_nearby_assets: 0 initially
```

Do not treat these as hard failures if the CSV bundle changes. The CSV files are the source of truth.



