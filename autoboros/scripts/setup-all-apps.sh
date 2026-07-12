#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  Deploy AUTOBOROS Apps by Tier
#  Usage: bash scripts/setup-all-apps.sh [tier0|tier1|tier2|tier3|all]
# ═══════════════════════════════════════════════════════════════

TIER="${1:-tier1}"
APPS_DIR="$HOME/apps"

echo "=== AUTOBOROS App Deployment: $TIER ==="

deploy() {
    local file="$1"
    if [[ -f "$APPS_DIR/$file" ]]; then
        echo "  Deploying: $file"
        docker compose -f "$APPS_DIR/$file" up -d
    else
        echo "  SKIP: $file not found"
    fi
}

case "$TIER" in
    tier0)
        echo "Tier 0 is already running via docker-compose.yml"
        ;;
    tier1)
        deploy "homarr.yml"
        deploy "dockge.yml"
        deploy "vaultwarden.yml"
        deploy "memos.yml"
        deploy "pocket-id.yml"
        ;;
    tier2)
        deploy "plausible.yml"
        deploy "nocodb.yml"
        deploy "karakeep.yml"
        deploy "excalidraw.yml"
        ;;
    tier3)
        echo "WARNING: Tier 3 apps should run on WORKER laptops"
        echo "Copy these to your worker and deploy there:"
        ls "$APPS_DIR"/n8n.yml "$APPS_DIR"/trilium.yml "$APPS_DIR"/activepieces.yml "$APPS_DIR"/docmost.yml "$APPS_DIR"/changedetection.yml "$APPS_DIR"/stirling-pdf.yml 2>/dev/null || true
        ;;
    all)
        echo "Deploying all tower apps (Tier 0-2)..."
        for f in homarr.yml dockge.yml vaultwarden.yml memos.yml pocket-id.yml plausible.yml nocodb.yml karakeep.yml excalidraw.yml; do
            deploy "$f"
        done
        echo ""
        echo "Tier 3 apps (workers) not deployed. Copy to workers manually."
        ;;
    *)
        echo "Usage: $0 [tier0|tier1|tier2|tier3|all]"
        exit 1
        ;;
esac

echo ""
echo "Deployed. Run 'health' to verify."
