#!/bin/bash
set -euo pipefail

echo "=== AUTOBOROS Update Check ==="
echo "  $(date -Iseconds)"
echo ""

echo "--- Debian Security ---"
apt-get update > /dev/null 2>&1
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c security || true)
echo "  Security updates: $UPGRADABLE"

echo ""
echo "--- Docker Images ---"
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read img; do
    echo "  $img"
done

echo ""
echo "--- EOL Countdown ---"
NOW=$(date +%s)
DAYS_FULL=$(( ($(date -d "2028-08-09" +%s) - NOW) / 86400 ))
DAYS_LTS=$(( ($(date -d "2030-06-30" +%s) - NOW) / 86400 ))
echo "  Full support ends in $DAYS_FULL days (2028-08-09)"
echo "  LTS ends in $DAYS_LTS days (2030-06-30)"
if [[ $DAYS_FULL -lt 365 ]]; then echo "  WARNING: <1 year of full support!"; fi
