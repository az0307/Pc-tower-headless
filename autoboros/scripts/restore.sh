#!/bin/bash
set -euo pipefail

REPO="${HOME}/backups/restic"
PASS_FILE="${HOME}/backups/.restic-pass"
SNAPSHOT="${1:-latest}"

echo "=== AUTOBOROS Restore ==="
echo "  Repo: $REPO | Snapshot: $SNAPSHOT"

[[ ! -f "$PASS_FILE" ]] && { echo "FATAL: Missing $PASS_FILE"; exit 1; }

restic -r "$REPO" snapshots --password-file "$PASS_FILE"
read -p "Restore snapshot $SNAPSHOT? [y/N] " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

# Restored data may include /etc secrets: keep it out of world-readable /tmp.
RESTORE_DIR="${RESTORE_DIR:-${HOME}/autoboros-restore}"
mkdir -p "$RESTORE_DIR"
chmod 700 "$RESTORE_DIR"
restic -r "$REPO" restore "$SNAPSHOT" --target "$RESTORE_DIR" --password-file "$PASS_FILE"

echo "Restore complete. Review ${RESTORE_DIR}/ and copy manually."
