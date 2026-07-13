#!/bin/bash
#
# Install the `srv` command system-wide.
#
#   sudo bash scripts/install-srv.sh
#
# Installs:
#   /usr/local/bin/srv            the command
#   /usr/local/bin/tower          alias (same command — dictation-friendly)
#   /etc/bash_completion.d/srv    tab completion (predictive text)
#
# Optional extras (offered interactively): gum for pretty fuzzy menus,
# and the wider QoL toolkit via `srv tools`.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run with sudo (installs into /usr/local/bin)."
    exit 1
fi

echo "=== Installing srv ==="

install -m 0755 "$REPO_DIR/bin/srv" /usr/local/bin/srv
ln -sf /usr/local/bin/srv /usr/local/bin/tower
echo "  ✔ /usr/local/bin/srv (+ 'tower' alias)"

if [[ -d /etc/bash_completion.d ]]; then
    install -m 0644 "$REPO_DIR/completions/srv.bash" /etc/bash_completion.d/srv
    echo "  ✔ tab completion → /etc/bash_completion.d/srv (new shells)"
else
    echo "  ● bash-completion not installed — for tab completion:"
    echo "      sudo apt install bash-completion   # then re-run this installer"
fi

# zsh hint (no system change)
echo "  ● zsh users: add to ~/.zshrc:"
echo "      autoload -U +X bashcompinit && bashcompinit"
echo "      source $REPO_DIR/completions/srv.bash"

if ! command -v gum &>/dev/null; then
    echo
    read -r -p "Install gum for pretty fuzzy menus (Charm apt repo)? [y/N] " r
    if [[ "$r" =~ ^[Yy] ]]; then
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
            > /etc/apt/sources.list.d/charm.list
        apt update && apt install -y gum
    else
        echo "  ● skipped — srv falls back to fzf or plain menus. Later: srv tools"
    fi
fi

echo
echo "=== Done ==="
echo "  Try:   srv            (dashboard + menu)"
echo "         srv status     srv s"
echo "         srv widgets    srv w"
echo "         srv hosts      → add your tower + future VPSes"
echo "         srv tower      → ssh straight in (after adding it)"
