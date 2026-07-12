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

mkdir -p /tmp/autoboros-restore
restic -r "$REPO" restore "$SNAPSHOT" --target /tmp/autoboros-restore --password-file "$PASS_FILE"

echo "Restore complete. Review /tmp/autoboros-restore/ and copy manually."
