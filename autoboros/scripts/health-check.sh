#!/bin/bash
set -euo pipefail

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "  [PASS] $name"
        ((PASS++))
    else
        echo "  [FAIL] $name"
        ((FAIL++))
    fi
}

echo "=== AUTOBOROS v3.0 Health Check ==="
echo "  Host: $(hostname) | $(date -Iseconds)"
echo ""

echo "--- System ---"
check "Docker running" "systemctl is-active docker"
check "Tailscale connected" "tailscale status"
check "UFW active" "ufw status | grep -q 'Status: active'"
check "Fail2ban running" "systemctl is-active fail2ban"
check "EarlyOOM running" "systemctl is-active earlyoom"
check "ZRAM active" "zramctl | grep -q lz4"
check "Unattended upgrades" "systemctl is-active unattended-upgrades"

echo ""
echo "--- Tier 0 Containers ---"
check "Caddy" "docker ps | grep -q 'caddy'"
check "Beszel Hub" "docker ps | grep -q 'beszel-hub'"
check "Uptime Kuma" "docker ps | grep -q 'uptime-kuma'"
check "Watchtower" "docker ps | grep -q 'watchtower'"

echo ""
echo "--- Resources ---"
RAM_USED=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
echo "  RAM usage: ${RAM_USED}%"
[[ $RAM_USED -lt 90 ]] && { echo "  [PASS] RAM usage"; ((PASS++)); } || { echo "  [FAIL] RAM usage >90%"; ((FAIL++)); }

DISK_USED=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
echo "  Disk usage: ${DISK_USED}%"
[[ $DISK_USED -lt 90 ]] && { echo "  [PASS] Disk usage"; ((PASS++)); } || { echo "  [FAIL] Disk usage >90%"; ((FAIL++)); }

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
