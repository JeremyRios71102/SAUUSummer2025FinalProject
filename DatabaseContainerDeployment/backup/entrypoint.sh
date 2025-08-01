#!/usr/bin/env bash
set -euo pipefail

#This will authorize access to Google Cloud's serivces with the SA key from 
the secrets
echo "Activating GCP service account..."
gcloud auth activate-service-account --key-file=/run/secrets/gcp_sa_key >/dev/null 2>&1
gcloud config set storage/parallel_composite_upload_enabled True >/dev/null 2>&1

CRON="${BACKUP_CRON:-0 2 * * *}"
echo "$CRON /app/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontab
touch /var/log/backup.log
cron -f
