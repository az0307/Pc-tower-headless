#!/bin/bash
set -euo pipefail

REPO="${HOME}/backups/restic"
PASS_FILE="${HOME}/backups/.restic-pass"
DATE=$(date +%Y%m%d_%H%M)
TAG="autoboros-${DATE}"
LOG_FILE="${HOME}/backups/logs/backup-${DATE}.log"

mkdir -p "${HOME}/backups/logs"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== AUTOBOROS Backup: ${DATE} ==="

[[ ! -f "$PASS_FILE" ]] && { echo "FATAL: Missing $PASS_FILE"; exit 1; }
[[ ! -f "${REPO}/config" ]] && restic init -r "${REPO}" --password-file "$PASS_FILE"

cp "${HOME}/docker/docker-compose.yml" "${HOME}/backups/configs/" 2>/dev/null || true
cp "${HOME}/docker/caddy/Caddyfile" "${HOME}/backups/configs/" 2>/dev/null || true
cp -r "${HOME}/apps" "${HOME}/backups/configs/" 2>/dev/null || true

restic -r "${REPO}" backup     --tag "${TAG}"     --exclude-file "${HOME}/.restic-exclude"     "${HOME}/docker"     "${HOME}/apps"     /etc     /var/lib/docker/volumes     "${HOME}/backups/configs"

restic -r "${REPO}" forget --tag "autoboros" --keep-last 8 --prune --password-file "$PASS_FILE"

echo "=== Backup ${TAG} complete ==="
