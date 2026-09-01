# Schema and data snapshot before Step 2 edits

Datasource: local `fpw`; table: `vessels`; rows: 14.

Read-only `information_schema.COLUMNS` evidence:

- `primaryPropulsion`: `VARCHAR(45) NULL DEFAULT NULL`
- `auxPropulsion`: `VARCHAR(45) NULL DEFAULT NULL`
- `primaryFuelCapacity`: `VARCHAR(45) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL`
- `auxFuelCapacity`: `VARCHAR(45) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL`
- `trailer`: `VARCHAR(45) NULL DEFAULT NULL`
- `fuel_capacity`: `DECIMAL(10,2) NULL DEFAULT NULL`

All 14 local rows contained NULL for every field newly proposed for exposure. Specifically, primary/auxiliary propulsion, primary/auxiliary fuel capacity, and trailer each had zero populated values. Existing `fuel_capacity` was populated in 13 rows and remains an independent total-capacity concept.

The migration directory's current latest prefix was `20260831_001_departure_reminder_deliveries`; no `20260831_002_*` file existed.
