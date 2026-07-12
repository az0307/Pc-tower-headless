#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  AUTOBOROS ULTIMATUM v3.0
#  Debian 13 Trixie — Headless Tower (Vista-Era / <=4GB RAM)
#  EOL: 2028-08-09 (Full) -> 2030-06-30 (LTS) -> 2035-06-30 (ELTS)
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$HOME"

echo ""
echo "    +------------------------------------------+"
echo "    |      AUTOBOROS ULTIMATUM v3.0            |"
echo "    |      Headless • Matrix • Secure          |"
echo "    |      EOL: 2028 -> 2030 -> 2035         |"
echo "    +------------------------------------------+"
echo ""

# -- Phase 0: Pre-flight ---------------------------------------
echo "=== [0/13] Pre-flight Checks ==="

if ! grep -q "trixie" /etc/os-release 2>/dev/null; then
    echo "WARNING: Optimized for Debian 13 Trixie."
    echo "Current: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    read -p "Continue? [y/N] " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "FATAL: Debian 13 requires x86_64. Current: $(uname -m)"
    echo "Use Debian 12 Bookworm or antiX for 32-bit."
    exit 1
fi

if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "FATAL: Root or passwordless sudo required."
    exit 1
fi

RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_MB=$((RAM_KB / 1024))
RAM_GB=$((RAM_MB / 1024))
echo "  RAM: ${RAM_MB}MB (~${RAM_GB}GB)"

# Determine tier
if [[ $RAM_MB -lt 2048 ]]; then
    TIER="ULTRA"
    ZRAM_PCT=100
    echo "  TIER: ULTRA-LOW (<=2GB) — Tier 0 only, no Vaultwarden"
elif [[ $RAM_MB -lt 4096 ]]; then
    TIER="LOW"
    ZRAM_PCT=75
    echo "  TIER: LOW (2-4GB) — Tier 0 + Tier 1"
else
    TIER="STANDARD"
    ZRAM_PCT=50
    echo "  TIER: STANDARD (>=4GB) — All tiers available"
fi

ROOT_FREE_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,""); print $4}')
echo "  Disk free: ${ROOT_FREE_GB}GB"
[[ $ROOT_FREE_GB -lt 10 ]] && echo "  WARNING: <10GB free."

# -- Phase 1: Base System --------------------------------------
echo ""
echo "=== [1/13] Base System ==="
sudo apt-get update
sudo apt-get full-upgrade -y
sudo apt-get install -y --no-install-recommends \
    bash-completion fzf eza bat fd-find ripgrep zoxide \
    zram-tools earlyoom ufw unattended-upgrades fail2ban \
    lm-sensors smartmontools jq btop curl wget git rsync htop \
    restic docker.io docker-compose-v2 tailscale \
    bc figlet vlock logrotate cron cpufrequtils

# -- Phase 2: Docker -------------------------------------------
echo ""
echo "=== [2/13] Docker Daemon ==="
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKEREEOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "3m", "max-file": "2" },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": { "nofile": { "Name": "nofile", "Hard": 64000, "Soft": 64000 } },
  "features": { "buildkit": true },
  "builder": { "gc": { "enabled": true, "defaultKeepStorage": "2GB" } },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
DOCKEREEOF
sudo systemctl restart docker
sudo systemctl enable docker

# -- Phase 3: ZRAM (adaptive) ----------------------------------
echo ""
echo "=== [3/13] ZRAM (${ZRAM_PCT}% RAM, lz4) ==="
sudo tee /etc/default/zramswap > /dev/null <<ZRAMEOF
ALGO=lz4
PERCENT=${ZRAM_PCT}
PRIORITY=100
ZRAMEOF
sudo systemctl enable zramswap
sudo systemctl restart zramswap
sleep 1 && zramctl || true

# -- Phase 4: EarlyOOM -----------------------------------------
echo ""
echo "=== [4/13] EarlyOOM ==="
sudo tee /etc/default/earlyoom > /dev/null <<'EOOMEOF'
EARLYOOM_ARGS="-r 60 -m 4,2 -s 100,50 --prefer '^(node|java|python|chrome|firefox)' --avoid '^(ssh|sshd|dockerd|systemd|systemd-journald)$'"
EOOMEOF
sudo systemctl enable earlyoom
sudo systemctl restart earlyoom

# -- Phase 5: UFW ----------------------------------------------
echo ""
echo "=== [5/13] UFW Firewall ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'Caddy HTTP'
sudo ufw allow 443/tcp comment 'Caddy HTTPS'
sudo ufw allow 41641/udp comment 'Tailscale'
sudo ufw allow 8090/tcp comment 'Beszel Hub'
sudo ufw --yes enable

# -- Phase 6: Unattended Upgrades -----------------------------
echo ""
echo "=== [6/13] Unattended Upgrades ==="
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<'UPGEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
UPGEOF

sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'AUTOEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTOEOF

# -- Phase 7: Fail2ban -----------------------------------------
echo ""
echo "=== [7/13] Fail2ban ==="
sudo tee /etc/fail2ban/jail.local > /dev/null <<'F2BEOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
F2BEOF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# -- Phase 8: Tailscale ---------------------------------------
echo ""
echo "=== [8/13] Tailscale ==="
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable tailscaled
sudo tailscale up --ssh --accept-dns=false || true
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "PENDING")
echo "  Tailscale IP: $TAILSCALE_IP"

# -- Phase 9: Directories --------------------------------------
echo ""
echo "=== [9/13] Directory Structure ==="
mkdir -p "${USER_HOME}/docker"/{caddy,homarr/configs,homarr/icons,homarr/data,dockge/data,backups}
mkdir -p "${USER_HOME}/backups"/{restic,scripts,configs,logs}
mkdir -p "${USER_HOME}/.config/autoboros"
mkdir -p "${USER_HOME}/apps"

# Copy core files
for f in docker-compose.yml Caddyfile Caddyfile.env; do
    [[ -f "${SCRIPT_DIR}/$f" ]] && cp "${SCRIPT_DIR}/$f" "${USER_HOME}/docker/$f" && echo "  Copied $f"
done

# Copy apps
if [[ -d "${SCRIPT_DIR}/apps" ]]; then
    cp -r "${SCRIPT_DIR}/apps"/* "${USER_HOME}/apps/"
    echo "  Copied apps/"
fi

# -- Phase 10: MOTD -------------------------------------------
echo ""
echo "=== [10/13] MOTD ==="
sudo tee /etc/update-motd.d/10-autoboros > /dev/null <<'MOTDEOF'
#!/bin/bash
DARK_GREEN='\e[38;5;22m'
MID_GREEN='\e[38;5;28m'
BRIGHT_GREEN='\e[1;32m'
DIM='\e[90m'
RESET='\e[0m'
echo -e "${DARK_GREEN}"
figlet -f small "AUTOBOROS" 2>/dev/null || echo "  AUTOBOROS"
echo -e "${MID_GREEN}  ~  Ultimatum v3.0  ~  ${RESET}"
echo -e "${DIM}  $(uptime -p 2>/dev/null || uptime) | $(free -h | awk '/^Mem:/ {print "RAM: "$3"/"$2}') | $(df -h / | awk 'NR==2 {print "Disk: "$5" used"}') | $(tailscale ip -4 2>/dev/null || echo 'Tailscale: OFF')${RESET}"
echo ""
MOTDEOF
sudo chmod +x /etc/update-motd.d/10-autoboros
sudo rm -f /etc/update-motd.d/10-uname /etc/update-motd.d/10-help-text 2>/dev/null || true

# -- Phase 11: .bashrc ----------------------------------------
echo ""
echo "=== [11/13] Shell Environment ==="
[[ -f "${USER_HOME}/.bashrc" ]] && cp "${USER_HOME}/.bashrc" "${USER_HOME}/.bashrc.autoboros-backup.$(date +%Y%m%d)"

cat >> "${USER_HOME}/.bashrc" <<'BASHRCEOF'

# ═══════════════════════════════════════════════════════════════
#  AUTOBOROS v3.0 — Shell Environment
# ═══════════════════════════════════════════════════════════════

DARK_GREEN='\[\e[38;5;22m\]'
MID_GREEN='\[\e[38;5;28m\]'
BRIGHT_GREEN='\[\e[1;32m\]'
ACCENT_GREEN='\[\e[38;5;46m\]'
DIM='\[\e[90m\]'
RESET='\[\e[0m\]'
PS1="${DARK_GREEN}\u${MID_GREEN}@${BRIGHT_GREEN}\h${MID_GREEN}:${DARK_GREEN}\w${ACCENT_GREEN}\$${RESET} "

alias ls='eza --icons --git --color=always 2>/dev/null || ls --color=auto'
alias ll='eza -alF --icons --git --color=always 2>/dev/null || ls -alF --color=auto'
alias la='eza -a --icons --color=always 2>/dev/null || ls -A --color=auto'
alias cat='bat --paging=never --color=always 2>/dev/null || cat'
alias find='fd 2>/dev/null || find'
alias grep='rg 2>/dev/null || grep --color=auto'
alias cd='z 2>/dev/null || cd'

alias mem='echo "=== Memory ===" && free -h && echo "" && echo "=== ZRAM ===" && zramctl 2>/dev/null && echo "" && echo "=== Swap ===" && swapon --show 2>/dev/null && echo "" && echo "=== EarlyOOM ===" && earlyoom-status 2>/dev/null || systemctl status earlyoom --no-pager 2>/dev/null || true'
alias update='sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean'
alias health='echo "=== Docker ===" && docker ps --format "table {{.Names}}\t{{.Status}}\t{{.MemUsage}}" 2>/dev/null && echo "" && echo "=== Disk ===" && df -h / && echo "" && echo "=== Memory ===" && free -h'
alias backup='restic -r ~/backups/restic backup ~/docker ~/apps --exclude ~/docker/caddy/data --exclude ~/docker/homarr/data --tag "manual-$(date +%Y%m%d)"'
alias backup-list='restic -r ~/backups/restic snapshots'
alias lock='vlock -c'
alias matrix='cmatrix -C green -b 2>/dev/null || echo "Install cmatrix: sudo apt install cmatrix"'
alias ports='sudo ss -tlnp | grep LISTEN'
alias services='systemctl list-units --type=service --state=running | grep -E "(docker|tailscale|fail2ban|earlyoom|zram)"'

alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dstats='docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
alias dlogs='docker logs --tail 50 -f'
alias dcup='cd ~/docker && docker compose up -d'
alias dcdown='cd ~/docker && docker compose down'
alias dcrestart='cd ~/docker && docker compose restart'
alias dcupdate='cd ~/docker && docker compose pull && docker compose up -d'
alias appup='cd ~/apps && docker compose -f $1 up -d'
alias appdown='cd ~/apps && docker compose -f $1 down'

eval "$(zoxide init bash)" 2>/dev/null || true
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

export TAILSCALE_DOMAIN="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // "local"' | sed 's/\.$//')"
BASHRCEOF

# -- Phase 12: Beszel Agent -----------------------------------
echo ""
echo "=== [12/13] Beszel Agent (Monitoring) ==="
if [[ -f "${SCRIPT_DIR}/scripts/setup-beszel.sh" ]]; then
    bash "${SCRIPT_DIR}/scripts/setup-beszel.sh" agent-only
else
    echo "  setup-beszel.sh not found, skipping"
fi

# -- Phase 13: Summary ----------------------------------------
echo ""
echo "    +----------------------------------------------+"
echo "    |      AUTOBOROS v3.0 INSTALLED                |"
echo "    +----------------------------------------------+"
echo ""
echo "  Tier:       $TIER (${RAM_MB}MB RAM)"
echo "  System:     $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "  Kernel:     $(uname -r)"
echo "  RAM:        $(free -h | awk '/^Mem:/ {print $2}') ($(free -h | awk '/^Mem:/ {print $3}') used)"
echo "  ZRAM:       $(zramctl --noheadings 2>/dev/null | awk '{print $4}' || echo 'N/A')"
echo "  Disk:       $(df -h / | awk 'NR==2 {print $5}') used on /"
echo "  Tailscale:  $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
echo ""
echo "  Core next steps:"
echo "    1. Edit ~/docker/caddy/.env -> set TAILSCALE_DOMAIN"
echo "    2. cd ~/docker && docker compose up -d"
echo "    3. REBOOT, then run: bash performance-upgrade.sh"
echo ""
echo "  App deployment:"
if [[ "$TIER" == "ULTRA" ]]; then
    echo "    TIER ULTRA: Only Tier 0 apps. Skip Vaultwarden."
    echo "    Available: memos, pocket-id (lightweight)"
elif [[ "$TIER" == "LOW" ]]; then
    echo "    TIER LOW: Tier 0 + Tier 1 apps."
    echo "    Run: bash scripts/setup-all-apps.sh tier1"
else
    echo "    TIER STANDARD: All tiers available."
    echo "    Run: bash scripts/setup-all-apps.sh all"
fi
echo ""
echo "  EOL: 2028-08-09 (Full) -> 2030-06-30 (LTS) -> 2035-06-30 (ELTS)"
echo ""
