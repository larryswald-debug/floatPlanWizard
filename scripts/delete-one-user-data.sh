#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DB_CONTAINER="${FPW_DB_CONTAINER:-cfdev-mysql}"
DB_NAME="${FPW_DB_NAME:-FPW}"
BACKUP_ROOT="${FPW_ONE_USER_DELETE_BACKUP_DIR:-${REPO_ROOT}/.codex-db-backups}"
SQL_TEMPLATE="${SCRIPT_DIR}/delete-one-user-data.sql"

USER_ID=""
EMAIL=""
MODE="dry-run"
CONFIRMED="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/delete-one-user-data.sh --email user@example.com
  scripts/delete-one-user-data.sh --user-id 123
  scripts/delete-one-user-data.sh --email user@example.com --execute --i-understand-this-deletes-one-fpw-user

Options:
  --email EMAIL        Resolve the target user by users.email.
  --user-id ID        Resolve the target user by users.userId.
  --dry-run           Preview only. This is the default.
  --execute           Delete the resolved user and commit.
  --i-understand-this-deletes-one-fpw-user
                      Required with --execute.

Environment overrides:
  FPW_DB_CONTAINER                 Docker MySQL container. Default: cfdev-mysql
  FPW_DB_NAME                      Database name. Default: FPW
  FPW_ONE_USER_DELETE_BACKUP_DIR   Backup/report root. Default: .codex-db-backups

Execute mode creates a full database dump before running the SQL cleanup.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)
      EMAIL="${2:-}"
      shift
      ;;
    --user-id)
      USER_ID="${2:-}"
      shift
      ;;
    --dry-run)
      MODE="dry-run"
      ;;
    --execute)
      MODE="execute"
      ;;
    --i-understand-this-deletes-one-fpw-user)
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

if [[ -z "$USER_ID" && -z "$EMAIL" ]]; then
  echo "Provide --email or --user-id." >&2
  usage >&2
  exit 2
fi

if [[ -n "$USER_ID" && ! "$USER_ID" =~ ^[0-9]+$ ]]; then
  echo "--user-id must be numeric." >&2
  exit 2
fi

if [[ "$MODE" == "execute" && "$CONFIRMED" != "true" ]]; then
  echo "Refusing execute mode without --i-understand-this-deletes-one-fpw-user." >&2
  exit 2
fi

if [[ ! -f "$SQL_TEMPLATE" ]]; then
  echo "SQL template not found: $SQL_TEMPLATE" >&2
  exit 1
fi

sql_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

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

USER_ID_SQL="NULL"
if [[ -n "$USER_ID" ]]; then
  USER_ID_SQL="$USER_ID"
fi

EMAIL_SQL="$(sql_quote "$EMAIL")"
EXECUTE_SQL="0"
CONFIRM_SQL="''"
if [[ "$MODE" == "execute" ]]; then
  EXECUTE_SQL="1"
  CONFIRM_SQL="$(sql_quote "I UNDERSTAND THIS DELETES ONE FPW USER")"
fi

MATCH_QUERY="
SELECT userId, email
FROM users
WHERE (
    ${USER_ID_SQL} IS NOT NULL
    AND userId = CAST(${USER_ID_SQL} AS UNSIGNED)
  )
  OR (
    ${EMAIL_SQL} <> ''
    AND LOWER(email) = LOWER(${EMAIL_SQL})
  )
ORDER BY userId;
"

MATCHES="$(printf '%s\n' "$MATCH_QUERY" | mysql_query)"
MATCH_COUNT="$(printf '%s\n' "$MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ "$MATCH_COUNT" != "1" ]]; then
  echo "Expected exactly one matching user, found ${MATCH_COUNT}." >&2
  if [[ -n "$MATCHES" ]]; then
    printf '%s\n' "$MATCHES" >&2
  fi
  exit 1
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${BACKUP_ROOT}/delete-one-user-${RUN_ID}"
mkdir -p "$RUN_DIR"

RENDERED_SQL="${RUN_DIR}/delete-one-user-data-rendered.sql"
REPORT="${RUN_DIR}/report.txt"

awk \
  -v user_id_sql="$USER_ID_SQL" \
  -v email_sql="$EMAIL_SQL" \
  -v execute_sql="$EXECUTE_SQL" \
  -v confirm_sql="$CONFIRM_SQL" '
    /^SET @fpw_delete_user_id = / {
      print "SET @fpw_delete_user_id = " user_id_sql ";"
      next
    }
    /^SET @fpw_delete_email = / {
      print "SET @fpw_delete_email = " email_sql ";"
      next
    }
    /^SET @fpw_delete_execute = / {
      print "SET @fpw_delete_execute = " execute_sql ";"
      next
    }
    /^SET @fpw_delete_confirmation = / {
      print "SET @fpw_delete_confirmation = " confirm_sql ";"
      next
    }
    { print }
  ' "$SQL_TEMPLATE" > "$RENDERED_SQL"

{
  echo "FPW one-user cleanup"
  echo "mode: ${MODE}"
  echo "run_id: ${RUN_ID}"
  echo "database: ${DB_NAME}"
  echo "db_container: ${DB_CONTAINER}"
  echo "backup_dir: ${RUN_DIR}"
  echo "sql_template: ${SQL_TEMPLATE}"
  echo "rendered_sql: ${RENDERED_SQL}"
  echo "matched_user:"
  printf '%s\n' "$MATCHES"
} | tee "$REPORT"

if [[ "$MODE" == "execute" ]]; then
  DB_BACKUP="${RUN_DIR}/${DB_NAME}-before-delete-one-user.sql"
  echo "Writing database backup: ${DB_BACKUP}" | tee -a "$REPORT"
  mysqldump_database > "$DB_BACKUP"
  if [[ ! -s "$DB_BACKUP" ]]; then
    echo "Database backup was not created or is empty. No data was changed." >&2
    exit 1
  fi
  echo "db_backup: ${DB_BACKUP}" >> "$REPORT"
fi

echo "Running SQL cleanup (${MODE})." | tee -a "$REPORT"
mysql_file < "$RENDERED_SQL" | tee "${RUN_DIR}/mysql-output.txt"
echo "mysql_output: ${RUN_DIR}/mysql-output.txt" >> "$REPORT"

echo "One-user cleanup ${MODE} complete. See ${RUN_DIR}."
