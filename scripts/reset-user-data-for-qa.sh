#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DB_CONTAINER="${FPW_DB_CONTAINER:-cfdev-mysql}"
DB_NAME="${FPW_DB_NAME:-FPW}"
BACKUP_ROOT="${FPW_QA_RESET_BACKUP_DIR:-${REPO_ROOT}/.codex-db-backups}"
PDF_DIR="${FPW_USER_PDF_DIR:-${REPO_ROOT}/api/api_assets/floatPlans/user_float_plans}"

MODE="dry-run"
CONFIRMED="false"

WIPE_TABLES=(
  "backup_route_instance_legs_endpoint_norm_20260221_222027"
  "backup_route_instance_legs_endpoint_norm_20260221_233840"
  "backup_route_instance_legs_lockcount_20260221_093626"
  "backup_route_instance_legs_lockcount_glreusev2_20260221_103545"
  "companion_pairing_codes"
  "companion_devices"
  "contacts"
  "email_optout"
  "emails_sent"
  "floatplan_activity_segments"
  "floatplan_alert_history"
  "floatplan_basic_details"
  "floatplan_captain_log_entries"
  "floatplan_companion_events"
  "floatplan_contacts"
  "floatplan_emailsent"
  "floatplan_events"
  "floatplan_history"
  "floatplan_monitor_events"
  "floatplan_monitoring"
  "floatplan_notification_log"
  "floatplan_notifications"
  "floatplan_operators"
  "floatplan_passengers"
  "floatplan_vessels"
  "floatplan_waypoints"
  "floatplans"
  "floatplans_sent"
  "floatplans_tosend"
  "fpw_early_access"
  "fpw_email_log"
  "fpw_notification_log"
  "fpw_promo_redemptions"
  "great_loop_bridge_import_logs"
  "member_entitlements"
  "member_premium_trip_entitlements"
  "messages"
  "operators"
  "passengers"
  "premium_send_credits"
  "premium_send_receipts"
  "premium_trip_creation_sessions"
  "premium_trip_entitlement_events"
  "product_events"
  "reset_tokens"
  "route_instance_leg_progress"
  "route_instance_legs"
  "route_instance_sections"
  "route_instances"
  "route_leg_user_overrides"
  "stripe_webhook_events"
  "user_route_legs"
  "user_route_progress"
  "user_routes"
  "user_segment_overrides"
  "user_stripe_customers"
  "users_address"
  "users_hostek"
  "users"
  "vessel_images"
  "vessels"
  "voyage_comments"
  "voyage_reactions"
  "voyage_followers"
  "voyage_posts"
  "voyage_streams"
  "waypoints"
)

PRESERVE_TABLES=(
  "backup_segment_library_lockcount_20260221_093626"
  "backup_segment_library_lockcount_glreusev2_20260221_103545"
  "boat_mans"
  "canonical_locks"
  "fpw_port_nearby_assets_stage"
  "fpw_port_ports_cleaned_stage"
  "fpw_port_profiles_stage"
  "fpw_port_services_stage"
  "fpw_port_tags_stage"
  "fpw_promo_codes"
  "greatLoop_anchorages"
  "great_loop_bridges"
  "great_loop_locks"
  "gsm_gsmsettings"
  "gulf-and-west-coast-anchorages-import-additions"
  "lock_delay_model"
  "loop_routes"
  "loop_sections"
  "loop_segment_distance_audit"
  "loop_segments"
  "loop_segments_backup_20260219_143430"
  "ports"
  "ports_backup_20260219_165733"
  "ports_backup_20260219_165815"
  "port_images"
  "port_nearby_assets"
  "port_profiles"
  "port_services"
  "port_slug_redirects"
  "port_tags"
  "rbk_loop_routes_20260213_154747_372853_s3"
  "rbk_loop_routes_20260213_155058_984486_s3"
  "rbk_ports_20260213_154507_135767_s1"
  "rbk_ports_20260213_154747_372853_s1"
  "rbk_ports_20260213_155058_984486_s1"
  "rbk_route_template_segments_20260213_155058_984486_s4"
  "rbk_segment_library_20260213_154747_372853_s2"
  "rbk_segment_library_20260213_155058_984486_s2"
  "rescuecenters"
  "route_leg_locks"
  "route_template_detour_segments"
  "route_template_detours"
  "route_template_segments"
  "segment_geometries"
  "segment_library"
  "states"
  "waterway_milepoints"
  "weather_cache"
  "weather_point_hourly_cache"
  "zcta2025_coordinates"
  "fpw_admin_audit_log"
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/reset-user-data-for-qa.sh [--dry-run]
  scripts/reset-user-data-for-qa.sh --execute --i-understand-this-deletes-local-fpw-user-data

Environment overrides:
  FPW_DB_CONTAINER              Docker MySQL container name. Default: cfdev-mysql
  FPW_DB_NAME                   Database name. Default: FPW
  FPW_QA_RESET_BACKUP_DIR       Backup/report root. Default: .codex-db-backups
  FPW_USER_PDF_DIR              Generated float-plan PDF directory.

Dry-run is the default. Execute mode creates a full DB dump and PDF archive
before deleting user-owned/runtime rows and generated user PDFs.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      ;;
    --execute)
      MODE="execute"
      ;;
    --i-understand-this-deletes-local-fpw-user-data)
      CONFIRMED="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$MODE" == "execute" && "$CONFIRMED" != "true" ]]; then
  echo "Refusing execute mode without --i-understand-this-deletes-local-fpw-user-data." >&2
  exit 2
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${BACKUP_ROOT}/qa-user-data-reset-${RUN_ID}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fpw-qa-reset.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$RUN_DIR"

mysql_query() {
  docker exec -i -e FPW_DB_NAME="$DB_NAME" "$DB_CONTAINER" sh -lc \
    'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql -uroot "$FPW_DB_NAME" --batch --raw --skip-column-names'
}

mysql_file() {
  docker exec -i -e FPW_DB_NAME="$DB_NAME" "$DB_CONTAINER" sh -lc \
    'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql -uroot "$FPW_DB_NAME"'
}

mysqldump_database() {
  docker exec -i -e FPW_DB_NAME="$DB_NAME" "$DB_CONTAINER" sh -lc \
    'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysqldump --single-transaction --routines --triggers --events --databases "$FPW_DB_NAME"'
}

quote_identifier() {
  local value="$1"
  value="${value//\`/\`\`}"
  printf '`%s`' "$value"
}

write_counts() {
  local output="$1"
  shift
  {
    for table in "$@"; do
      printf "SELECT '%s', COUNT(*) FROM %s;\n" "$table" "$(quote_identifier "$table")"
    done
  } | mysql_query > "$output"
}

validate_table_classification() {
  local db_tables="${TMP_DIR}/db-tables.txt"
  local classified_tables="${TMP_DIR}/classified-tables.txt"
  local unknown_tables="${TMP_DIR}/unknown-tables.txt"
  local missing_tables="${TMP_DIR}/missing-tables.txt"

  printf "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;\n" \
    | mysql_query | sort -u > "$db_tables"
  printf '%s\n' "${WIPE_TABLES[@]}" "${PRESERVE_TABLES[@]}" | sort -u > "$classified_tables"

  comm -23 "$db_tables" "$classified_tables" > "$unknown_tables"
  comm -13 "$db_tables" "$classified_tables" > "$missing_tables"

  if [[ -s "$unknown_tables" || -s "$missing_tables" ]]; then
    echo "Table classification mismatch. No data was changed." >&2
    if [[ -s "$unknown_tables" ]]; then
      echo "Unknown DB tables:" >&2
      sed 's/^/  /' "$unknown_tables" >&2
    fi
    if [[ -s "$missing_tables" ]]; then
      echo "Configured tables missing from DB:" >&2
      sed 's/^/  /' "$missing_tables" >&2
    fi
    exit 1
  fi
}

write_wipe_sql() {
  local output="$1"
  local auto_inc_tables="${TMP_DIR}/auto-increment-tables.txt"

  printf "SELECT DISTINCT TABLE_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND EXTRA LIKE '%%auto_increment%%';\n" \
    | mysql_query | sort -u > "$auto_inc_tables"

  {
    echo "SET FOREIGN_KEY_CHECKS=0;"
    for table in "${WIPE_TABLES[@]}"; do
      printf "DELETE FROM %s;\n" "$(quote_identifier "$table")"
    done
    for table in "${WIPE_TABLES[@]}"; do
      if grep -Fxq "$table" "$auto_inc_tables"; then
        printf "ALTER TABLE %s AUTO_INCREMENT = 1;\n" "$(quote_identifier "$table")"
      fi
    done
    echo "SET FOREIGN_KEY_CHECKS=1;"
  } > "$output"
}

pdf_file_count() {
  if [[ ! -d "$PDF_DIR" ]]; then
    echo "0"
    return
  fi
  find "$PDF_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '
}

pdf_size_summary() {
  if [[ ! -d "$PDF_DIR" ]]; then
    echo "missing"
    return
  fi
  du -sh "$PDF_DIR" | awk '{print $1}'
}

assert_wipe_counts_zero() {
  local counts_file="$1"
  local nonzero="${TMP_DIR}/nonzero-wipe-counts.txt"
  awk -F '\t' '$2 != 0 { print }' "$counts_file" > "$nonzero"
  if [[ -s "$nonzero" ]]; then
    echo "Wipe validation failed. Nonzero user-owned tables remain:" >&2
    sed 's/^/  /' "$nonzero" >&2
    exit 1
  fi
}

assert_preserve_counts_unchanged() {
  local before_file="$1"
  local after_file="$2"
  if ! diff -u "$before_file" "$after_file" > "${TMP_DIR}/preserve-counts.diff"; then
    echo "Preserve validation failed. Preserved table counts changed:" >&2
    cat "${TMP_DIR}/preserve-counts.diff" >&2
    exit 1
  fi
}

validate_table_classification

BEFORE_WIPE_COUNTS="${RUN_DIR}/wipe-table-counts-before.tsv"
BEFORE_PRESERVE_COUNTS="${RUN_DIR}/preserve-table-counts-before.tsv"
AFTER_WIPE_COUNTS="${RUN_DIR}/wipe-table-counts-after.tsv"
AFTER_PRESERVE_COUNTS="${RUN_DIR}/preserve-table-counts-after.tsv"
WIPE_SQL="${RUN_DIR}/user-data-wipe.sql"
REPORT="${RUN_DIR}/report.txt"

write_counts "$BEFORE_WIPE_COUNTS" "${WIPE_TABLES[@]}"
write_counts "$BEFORE_PRESERVE_COUNTS" "${PRESERVE_TABLES[@]}"

{
  echo "FPW QA user-data reset"
  echo "mode: ${MODE}"
  echo "run_id: ${RUN_ID}"
  echo "database: ${DB_NAME}"
  echo "db_container: ${DB_CONTAINER}"
  echo "backup_dir: ${RUN_DIR}"
  echo "user_pdf_dir: ${PDF_DIR}"
  echo "user_pdf_entry_count_before: $(pdf_file_count)"
  echo "user_pdf_size_before: $(pdf_size_summary)"
  echo "wipe_table_count: ${#WIPE_TABLES[@]}"
  echo "preserve_table_count: ${#PRESERVE_TABLES[@]}"
  echo "wipe_counts_before: ${BEFORE_WIPE_COUNTS}"
  echo "preserve_counts_before: ${BEFORE_PRESERVE_COUNTS}"
} | tee "$REPORT"

if [[ "$MODE" == "dry-run" ]]; then
  echo "Dry run complete. No data was changed."
  exit 0
fi

DB_BACKUP="${RUN_DIR}/${DB_NAME}-before-user-data-reset.sql"
PDF_BACKUP="${RUN_DIR}/user_float_plans-before-reset.tar.gz"

echo "Writing database backup: ${DB_BACKUP}"
mysqldump_database > "$DB_BACKUP"
if [[ ! -s "$DB_BACKUP" ]]; then
  echo "Database backup was not created or is empty. No data was changed." >&2
  exit 1
fi

if [[ -d "$PDF_DIR" ]]; then
  echo "Writing generated PDF backup: ${PDF_BACKUP}"
  tar -czf "$PDF_BACKUP" -C "$(dirname "$PDF_DIR")" "$(basename "$PDF_DIR")"
  if [[ ! -s "$PDF_BACKUP" ]]; then
    echo "PDF backup was not created or is empty. No data was changed." >&2
    exit 1
  fi
else
  echo "Generated PDF directory does not exist; skipping PDF archive." | tee -a "$REPORT"
fi

write_wipe_sql "$WIPE_SQL"
echo "Executing user-data wipe SQL: ${WIPE_SQL}"
mysql_file < "$WIPE_SQL"

if [[ -d "$PDF_DIR" ]]; then
  find "$PDF_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

write_counts "$AFTER_WIPE_COUNTS" "${WIPE_TABLES[@]}"
write_counts "$AFTER_PRESERVE_COUNTS" "${PRESERVE_TABLES[@]}"
assert_wipe_counts_zero "$AFTER_WIPE_COUNTS"
assert_preserve_counts_unchanged "$BEFORE_PRESERVE_COUNTS" "$AFTER_PRESERVE_COUNTS"

{
  echo "db_backup: ${DB_BACKUP}"
  echo "pdf_backup: ${PDF_BACKUP}"
  echo "wipe_sql: ${WIPE_SQL}"
  echo "wipe_counts_after: ${AFTER_WIPE_COUNTS}"
  echo "preserve_counts_after: ${AFTER_PRESERVE_COUNTS}"
  echo "user_pdf_entry_count_after: $(pdf_file_count)"
  echo "user_pdf_size_after: $(pdf_size_summary)"
  echo "result: success"
} | tee -a "$REPORT"

echo "QA user-data reset complete."
