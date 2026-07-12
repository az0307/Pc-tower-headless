#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  Beszel Setup — Hub + Agent
#  Usage: bash scripts/setup-beszel.sh [hub|agent-only|full]
# ═══════════════════════════════════════════════════════════════

MODE="${1:-hub}"
USER_HOME="$HOME"

echo "=== Beszel Setup ($MODE) ==="

if [[ "$MODE" == "hub" ]] || [[ "$MODE" == "full" ]]; then
    echo "  Hub is deployed via docker-compose.yml (beszel-hub service)"
    echo "  Access at: https://beszel.YOUR-TAILSCALE-DOMAIN"
fi

if [[ "$MODE" == "agent-only" ]] || [[ "$MODE" == "full" ]]; then
    echo "  Installing Beszel Agent..."

    # Get hub key from user
    read -p "Enter Beszel Hub public key: " HUB_KEY

    docker run -d         --name beszel-agent         --restart unless-stopped         --network host         -v /var/run/docker.sock:/var/run/docker.sock:ro         -e KEY="$HUB_KEY"         -e PORT=45876         --memory=32m         --cpus=0.1         henrygd/beszel-agent:0.18.7

    echo "  Agent installed. Add this host in Beszel Hub UI."
fi

echo "  Done."
