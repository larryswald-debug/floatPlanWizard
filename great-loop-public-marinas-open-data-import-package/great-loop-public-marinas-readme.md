# FPW Great Loop Public Marinas Import Package

## What this package is

This package is the safe way to build a Great Loop marina database without copying proprietary marina directories.

It includes:

- `great-loop-public-marinas-import-template.csv` — DB import CSV headers.
- `generate_great_loop_marinas_overpass.py` — script to pull marina candidates from OpenStreetMap/Overpass.
- `great-loop-public-marinas-table-suggestion.sql` — suggested MySQL table.
- `overpass-great-loop-marinas-query-notes.md` — route-group/query notes.

## Why the CSV is a template, not a completed marina dataset

A truthful “all public marinas on the Great Loop” dataset cannot be produced from a few search-result pages. The major marina directories are proprietary/commercial/community datasets and should not be copied into FPW. The open-data path is to query OpenStreetMap and then review candidates before public launch.

The script queries OSM features tagged:

- `leisure=marina`
- `seamark:harbour:category=marina`
- `harbour=marina`

inside broad Great Loop corridor bounding boxes.

## License / attribution

OpenStreetMap data is licensed under the Open Data Commons Open Database License (ODbL). If FPW publishes OSM-derived marina data, FPW should credit OpenStreetMap contributors and make the ODbL license clear.

Attribution text example:

> Marina location data includes information from OpenStreetMap contributors, available under the Open Database License.

Source:
https://www.openstreetmap.org/copyright

## Recommended process

1. Put this package somewhere outside production.
2. Run the generator locally with internet access:

```bash
python3 -m pip install requests
python3 generate_great_loop_marinas_overpass.py --out great-loop-public-marinas-import-seed.csv
```

3. Import into a staging/admin table, not directly to public pages.
4. Review every row:
   - Is it actually reachable from the Great Loop route?
   - Is it public/transient friendly?
   - Is it private, members-only, military, industrial, or a yacht club with no transient slips?
   - Is the coordinate at the marina, not the city centroid?
   - Are fuel/pumpout/power/water fields present or unknown?
5. Publish only reviewed rows.

## Important FPW public-page warning

Every public marina page should include:

> This marina reference is for trip planning only. Always verify current charts, marina availability, access rules, fuel, depth, bridge/lock restrictions, weather, and local notices before relying on this information.

## Suggested public routes

```text
/boating-guides/great-loop-marinas/
/boating-guides/great-loop-marinas/florida-west-coast/
/boating-guides/great-loop-marinas/lake-michigan-east-shore/
/boating-guides/great-loop-marinas/{marina-slug}/
```

## Suggested import staging flags

Keep these fields:

- `verification_status`
- `is_published`
- `reviewed_by`
- `reviewed_at`
- `reviewer_notes`

Default everything to unpublished until reviewed.
