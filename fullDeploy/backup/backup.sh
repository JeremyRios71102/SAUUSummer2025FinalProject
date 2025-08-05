#!/usr/bin/env bash
set -euo pipefail

#Change the HOST and DB if necessary
MYSQL_HOST="${MYSQL_HOST:-db}"
MYSQL_DB="${MYSQL_DB:-firefly}"
MYSQL_USER="$(cat /run/secrets/app_db_user)"
MYSQL_PW="$(cat /run/secrets/app_db_password)"
STAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
TMP="/tmp/${MYSQL_DB}-${STAMP}.sql.gz"

echo "[$(date -Is)] Starting backup..."
mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p "$MYSQL_PW" \
	--single-transaction --quick --routines --triggers --events "$MYSQL_DB" \
	| gzip -9 > "$TMP"

gsutil cp "$TMP" "$DEST"
rm -f "$TMP"
echo "[$(date -Is)] Backup uploaded to $DEST"
