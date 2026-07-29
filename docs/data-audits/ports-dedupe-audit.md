# FPW Ports Library De-Duplication Audit

Date: 2026-07-08

## Scope

This audit covers only the Great Loop Ports Library de-duplication phase. It created the redirect support needed to preserve old duplicate public URLs, executed a conservative local de-duplication of confirmed duplicate port records, updated dependent route references, and verified the public Ports Library still renders.

No Bridges, Locks, waypoint, map-library, Stripe, entitlement, or unrelated UI files were intentionally changed.

## Snapshot and Export Paths

- Database export before data changes: `.codex-snapshots/ports-dedupe/20260708-113102/ports_dedupe_pre.sql`
- Pre-change counts: `.codex-snapshots/ports-dedupe/20260708-113102/counts_before.tsv`
- Dry-run output: `.codex-snapshots/ports-dedupe/20260708-113102/dedupe_dry_run.tsv`
- Execute output: `.codex-snapshots/ports-dedupe/20260708-113102/dedupe_execute.tsv`
- Second execute/idempotency output: `.codex-snapshots/ports-dedupe/20260708-113102/dedupe_execute_second_pass.tsv`
- Validation output: `.codex-snapshots/ports-dedupe/20260708-113102/validation_after.tsv`
- Sitemap snapshot: `.codex-snapshots/ports-dedupe/20260708-113102/sitemap.xml.pre-dedupe.bak`
- Additional file snapshots:
  - `.codex-snapshots/ports-dedupe/20260708-113102/file-snapshots/gitignore.pre-tools-sql.bak`
  - `.codex-snapshots/ports-dedupe/20260708-113102/file-snapshots/PortsLibraryService.cfc.pre-trailing-cleanup.bak`
  - `.codex-snapshots/ports-dedupe/20260708-113102/file-snapshots/great-loop-port.cfm.pre-trailing-cleanup.bak`

## Tables Inspected

- `ports`
- `port_profiles`
- `port_services`
- `port_tags`
- `port_nearby_assets`
- `port_images`
- `segment_library`
- `route_template_detours`
- `port_slug_redirects`

## Files Inspected

- `app/great-loop-port.cfm`
- `app/great-loop-ports.cfm`
- `admin/great-loop-ports.cfm`
- `api/v1/PortsLibraryService.cfc`
- `api/v1/ports.cfc`
- `api/v1/adminGreatLoopPorts.cfc`
- `assets/js/app/ports-library.js`
- `assets/js/app/admin/great-loop-ports.js`
- `sitemap.xml`
- `db/migrations/20260705_ports_support_tables.sql`
- `db/migrations/20260707_port_images.sql`

## Count Before

| Table | Count |
| --- | ---: |
| `ports` | 184 |
| `port_profiles` | 184 |
| `port_services` | 184 |
| `port_tags` | 1061 |
| `port_nearby_assets` | 0 |
| `port_images` | 4 |

## Duplicate Detection Method

The confirmed duplicate set used conservative matching only:

- Same normalized port name.
- Same state/province.
- Same or matching waterway/loop context.
- Coordinates within a small radius, verified with the imported support data.
- Public slug was ID-prefixed and safely mappable to one canonical row.

Ambiguous same-name rows were intentionally left alone when the coordinates or route context did not prove they were the same real-world port.

## Canonical Mapping

| Duplicate ID | Duplicate slug | Canonical ID | Canonical slug |
| ---: | --- | ---: | --- |
| 137 | `137-peoria-il` | 38 | `38-peoria-il` |
| 142 | `142-paducah-ky` | 37 | `37-paducah-ky` |
| 146 | `146-demopolis-al` | 15 | `15-demopolis-al` |
| 147 | `147-mobile-al` | 29 | `29-mobile-al` |
| 148 | `148-pensacola-fl` | 64 | `64-pensacola-fl` |
| 149 | `149-panama-city-fl` | 66 | `66-panama-city-fl` |
| 150 | `150-carrabelle-fl` | 68 | `68-carrabelle-fl` |
| 151 | `151-tarpon-springs-fl` | 51 | `51-tarpon-springs-fl` |
| 154 | `154-fort-myers-fl` | 19 | `19-fort-myers-fl` |
| 157 | `157-stuart-fl` | 49 | `49-stuart-fl` |
| 158 | `158-fort-lauderdale-fl` | 108 | `108-fort-lauderdale-fl` |
| 161 | `161-jacksonville-fl` | 112 | `112-jacksonville-fl` |
| 165 | `165-myrtle-beach-sc` | 31 | `31-myrtle-beach-sc` |
| 171 | `171-solomons-md` | 45 | `45-solomons-md` |
| 172 | `172-annapolis-md` | 2 | `2-annapolis-md` |
| 173 | `173-chesapeake-city-md` | 10 | `10-chesapeake-city-md` |
| 175 | `175-atlantic-city-nj` | 118 | `118-atlantic-city-nj` |
| 182 | `182-buffalo-ny` | 127 | `127-buffalo-ny` |
| 183 | `183-erie-pa` | 128 | `128-erie-pa` |
| 184 | `184-cleveland-oh` | 129 | `129-cleveland-oh` |
| 186 | `186-mackinac-island-mi` | 27 | `27-mackinac-island-mi` |
| 201 | `201-oswego-ny` | 35 | `35-oswego-ny` |

## Merge and Removal Actions

- Inserted 22 rows into `port_slug_redirects` before duplicate deletion.
- Copied duplicate tags to canonical ports with `INSERT IGNORE`.
- Verified against the pre-change export that duplicate rows had no duplicate-only scalar, image, or service fields requiring canonical updates.
- Deleted duplicate support rows from `port_nearby_assets`, `port_tags`, `port_images`, `port_services`, and `port_profiles`.
- Deleted the 22 confirmed duplicate rows from `ports`.
- Removed the 22 duplicate public URL entries from `sitemap.xml`.
- Did not delete image files.
- Did not rewrite canonical display names.
- Did not alter schema beyond the Ports-only redirect table.

## References Updated

- `segment_library.start_port_id`: 22 old duplicate references retargeted to canonical IDs.
- `segment_library.end_port_id`: 23 old duplicate references retargeted to canonical IDs.
- `route_template_detours.insert_after_port_id`: update statement included; post-validation found 0 old duplicate references.

## Redirect Handling

`app/great-loop-port.cfm` now checks `port_slug_redirects` only after direct ID and slug lookup fail. When an old duplicate slug is found, it issues a 301 redirect to the canonical slug.

Example verified redirect:

- `/fpw/great-loop/ports/173-chesapeake-city-md/`
- redirects to `/fpw/great-loop/ports/10-chesapeake-city-md/`

## Records Left Untouched as Ambiguous

These same-name/state groups remain because they were not proven duplicates by conservative location/context rules:

| Name | State code | IDs |
| --- | --- | --- |
| Cairo | IL | 7, 141 |
| Charleston | SC | 9, 164 |
| Chicago | IL | 11, 134 |
| Detroit | MI | 16, 185 |
| Joliet | IL | 87, 135 |
| Milwaukee | WI | 133, 189 |
| New York | NY | 120, 177 |
| Norfolk | VA | 34, 170 |
| Sarasota | FL | 105, 153 |
| Savannah | GA | 44, 162 |
| Syracuse | NY | 125, 181 |
| West Palm Beach | FL | 109, 159 |

## Count After

| Table | Count |
| --- | ---: |
| `ports` | 162 |
| `port_profiles` | 162 |
| `port_services` | 162 |
| `port_tags` | 891 |
| `port_nearby_assets` | 0 |
| `port_images` | 4 |
| `port_slug_redirects` | 22 |

## Commands Run

```bash
docker exec cfdev-mysql mysqldump -uroot -prootpassword --single-transaction FPW ports port_profiles port_services port_tags port_nearby_assets port_images segment_library route_template_detours > ".codex-snapshots/ports-dedupe/20260708-113102/ports_dedupe_pre.sql"

docker exec -i cfdev-mysql mysql -uroot -prootpassword FPW < db/migrations/20260708_ports_dedupe_redirects.sql

docker exec -i cfdev-mysql mysql -uroot -prootpassword FPW < db/maintenance/20260708_ports_dedupe.sql > .codex-snapshots/ports-dedupe/20260708-113102/dedupe_dry_run.tsv

docker exec -i cfdev-mysql mysql -uroot -prootpassword --init-command="SET @execute_ports_dedupe=1" FPW < db/maintenance/20260708_ports_dedupe.sql > .codex-snapshots/ports-dedupe/20260708-113102/dedupe_execute.tsv

docker exec -i cfdev-mysql mysql -uroot -prootpassword --init-command="SET @execute_ports_dedupe=1" FPW < db/maintenance/20260708_ports_dedupe.sql > .codex-snapshots/ports-dedupe/20260708-113102/dedupe_execute_second_pass.tsv
```

The maintenance script was moved after execution from ignored `db/maintenance/20260708_ports_dedupe.sql` to tracked `db/tools/20260708_ports_dedupe.sql`. Future dry-run and execute commands should use the tracked `db/tools` path.

## Validation Results

Database validation:

- Final table counts match expected de-duped counts.
- Confirmed 0 removed duplicate IDs remain in `ports`.
- Confirmed 22 canonical rows remain.
- Confirmed 22 redirect rows exist.
- Confirmed 0 orphan rows in `port_profiles`, `port_services`, `port_tags`, `port_nearby_assets`, and `port_images`.
- Confirmed 0 duplicate slugs.
- Confirmed 0 old duplicate references remain in `segment_library.start_port_id`, `segment_library.end_port_id`, or `route_template_detours.insert_after_port_id`.
- Second execute pass kept counts unchanged.

Endpoint/browser validation:

- Public Ports page rendered at `/fpw/great-loop/ports/`.
- Public Ports page showed 162 total records and 161 map-ready rows.
- API list endpoint returned 161 map-ready rows by default.
- Browser search for `Chesapeake City` rendered only the canonical `10-chesapeake-city-md` result link.
- Canonical detail page `/fpw/great-loop/ports/10-chesapeake-city-md/` rendered with map, Quick Facts, and Add to My Waypoints panel.
- Duplicate URL `/fpw/great-loop/ports/173-chesapeake-city-md/` redirected to `/fpw/great-loop/ports/10-chesapeake-city-md/`.
- Relevant Ports/Admin browser console errors: none found.
- Admin page reached `/fpw/admin/great-loop-ports.cfm`, but the current browser session was not admin-authorized, so live edit/save/upload smoke was not performed.
- Code inspection confirmed the admin page still contains the edit modal, image upload input, image preview area, map frame, latitude/longitude fields, save control, and delete control behind the existing authorization branch.

## Known Limitations

- This local run hard-deleted only the 22 confirmed duplicate rows after export, redirect insertion, reference retargeting, and validation. The export path above is the rollback source.
- No redirect-history system existed before this phase; `port_slug_redirects` is Ports-specific and only used after normal ID/slug lookup fails.
- Admin edit/save/upload was not browser-tested because the active browser session was not logged in as an admin.
- A pre-existing URL assembly issue was observed outside this de-dupe scope: API `DETAIL_URL` values can double-prefix ID-bearing slugs, such as `/great-loop/ports/10-10-chesapeake-city-md/`. The canonical page still resolves by ID, but this should be addressed separately.
