#!/bin/bash
#
# Debian Server Post-Install Script (Bookworm / Trixie)
# Professional edition - hardened, idempotent where practical, with modern QoL
#
# Usage: sudo bash debian-server-postinstall.sh
# Supports Debian 12 (Bookworm) and Debian 13 (Trixie)
# Test in a VM first!

set -euo pipefail

# ========================== CONFIGURATION ==========================
NEW_HOSTNAME="srv01"
ADMIN_USER=""                    # Set username to create (or leave empty)
TIMEZONE="Etc/UTC"               # e.g. Australia/Melbourne
SSH_PORT=22
ENABLE_COCKPIT=false
INSTALL_DOCKER=false
INSTALL_QOL_TOOLS=true           # Modern CLI + TUI tools (atuin, yazi, lazygit, etc.)
INSTALL_AICHAT=true              # AI assistant in terminal (supports Gemini)
LEGACY_HARDWARE=false            # Add tweaks for old CPUs (Vista era / Core 2 era)
MINIMAL_MODE=false               # Aggressive minimalism for low-RAM/old hardware (disables most QoL)
FORCE_KEY_ONLY=false             # true = disable SSH passwords even if no key is found (lockout risk!)
# ===================================================================

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# --- Detect Debian version ---
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-unknown}"
else
    CODENAME="unknown"
fi

if [[ "$CODENAME" != "bookworm" && "$CODENAME" != "trixie" ]]; then
    echo "WARNING: This script is designed for Debian 12 (Bookworm) or Debian 13 (Trixie)."
    echo "Detected: $CODENAME"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=== Debian Headless Server Post-Install (Pro) ==="
echo "Detected: Debian $CODENAME"
echo "Starting at $(date)"
echo

# 1. Backup and update sources.list
echo "[1] Backing up and updating APT sources..."
cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%F_%T)" 2>/dev/null || true

cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware

deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
EOF

# 2. Full system upgrade
echo "[2] Full system upgrade..."
apt update
apt full-upgrade -y
apt autoremove -y --purge
apt clean

# 3. Essential packages
echo "[3] Installing essential packages..."
apt install -y \
    sudo vim nano htop curl wget git ca-certificates gnupg lsb-release \
    net-tools iputils-ping dnsutils systemd-timesyncd ufw fail2ban \
    unattended-upgrades apt-listchanges needrestart

# 4. Admin user
if [[ -n "$ADMIN_USER" ]]; then
    if id "$ADMIN_USER" &>/dev/null; then
        echo "[4] User $ADMIN_USER exists → adding to sudo group"
        usermod -aG sudo "$ADMIN_USER"
    else
        echo "[4] Creating admin user: $ADMIN_USER"
        adduser --gecos "" --disabled-password "$ADMIN_USER"
        usermod -aG sudo "$ADMIN_USER"
        echo "Set a password for $ADMIN_USER:"
        passwd "$ADMIN_USER"
    fi
else
    echo "[4] No ADMIN_USER set — ensure your user has sudo access"
fi

# 5. Hostname
echo "[5] Setting hostname to $NEW_HOSTNAME..."
hostnamectl set-hostname "$NEW_HOSTNAME"
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts || true

# 6. Timezone & NTP
echo "[6] Setting timezone and NTP..."
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

# 7. Harden SSH
echo "[7] Hardening SSH..."
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F_%T)" 2>/dev/null || true
# Remove any Stage 0 temporary drop-in; this hardened config takes over fully.
rm -f /etc/ssh/sshd_config.d/00-remote-access.conf 2>/dev/null || true

# Lockout guard: only disable password auth if the login user actually has an
# SSH key installed — otherwise a remote run of this script would lock you out.
KEY_TARGET_USER="${ADMIN_USER:-${SUDO_USER:-}}"
PASSWORD_AUTH="no"
KBD_AUTH="no"
if [[ "$FORCE_KEY_ONLY" != "true" ]]; then
    _authkeys=""
    if [[ -n "$KEY_TARGET_USER" ]] && id "$KEY_TARGET_USER" &>/dev/null; then
        _home="$(getent passwd "$KEY_TARGET_USER" | cut -d: -f6)"
        _authkeys="$_home/.ssh/authorized_keys"
    fi
    if [[ -z "$_authkeys" || ! -s "$_authkeys" ]]; then
        echo ">>> WARNING: no SSH key found for '${KEY_TARGET_USER:-<unknown user>}'."
        echo "    Keeping PASSWORD login ENABLED so you are not locked out remotely."
        echo "    Install a key first:  ssh-copy-id ${KEY_TARGET_USER:-youruser}@<host>"
        echo "    then re-run with FORCE_KEY_ONLY=true to switch to key-only."
        PASSWORD_AUTH="yes"
        KBD_AUTH="yes"
    else
        echo ">>> SSH key found for '$KEY_TARGET_USER' → disabling password login (key-only)."
    fi
else
    echo ">>> FORCE_KEY_ONLY=true → disabling password login regardless of key presence."
fi

cat > /etc/ssh/sshd_config << EOF
# Debian ${CODENAME^} Hardened SSH Config (generated $(date +%F))
Port $SSH_PORT
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication $PASSWORD_AUTH
KbdInteractiveAuthentication $KBD_AUTH
UsePAM yes

AllowTcpForwarding no
PermitTunnel no
X11Forwarding no
Compression delayed
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 15
ClientAliveInterval 300
ClientAliveCountMax 2

SyslogFacility AUTH
LogLevel VERBOSE

AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
DebianBanner no
EOF

sshd -t
systemctl restart ssh
systemctl enable ssh

if [[ "$PASSWORD_AUTH" == "no" ]]; then
    echo ">>> SSH is now key-only. Run from your workstation:"
    echo "    ssh-copy-id -p $SSH_PORT youruser@$NEW_HOSTNAME"
else
    echo ">>> SSH still allows PASSWORD login (no key was found)."
    echo "    Install your key, then re-run with FORCE_KEY_ONLY=true to lock it down:"
    echo "    ssh-copy-id -p $SSH_PORT ${KEY_TARGET_USER:-youruser}@$NEW_HOSTNAME"
fi

# 8. Firewall (UFW) - safer handling
echo "[8] Configuring UFW firewall..."
if ! ufw status | grep -q "Status: active"; then
    ufw --force reset || true
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "$SSH_PORT"/tcp comment 'SSH access'
    ufw --force enable
fi
ufw reload

# 9. Automatic security updates
echo "[9] Configuring unattended-upgrades..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

dpkg-reconfigure -plow unattended-upgrades || true
systemctl enable --now unattended-upgrades

# 10. Fail2ban
echo "[10] Configuring Fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
maxretry = 4
bantime = 24h
EOF

systemctl enable --now fail2ban

# Legacy hardware tweaks (optional)
if [[ "$LEGACY_HARDWARE" == "true" ]]; then
    echo "[Legacy] Applying tweaks for old hardware (Vista/Core 2 era)..."
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
        # Common safe tweaks for old Intel CPUs
        LEGACY_PARAMS="intel_idle.max_cstate=1 processor.max_cstate=1"
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$LEGACY_PARAMS /" /etc/default/grub
        update-grub
        echo "    → Added legacy CPU parameters: $LEGACY_PARAMS"
    fi
fi

# 11. Docker (optional)
if [[ "$INSTALL_DOCKER" == "true" ]]; then
    echo "[11] Installing Docker (official repo)..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker

    if [[ -n "$ADMIN_USER" ]] && id "$ADMIN_USER" &>/dev/null; then
        usermod -aG docker "$ADMIN_USER"
        echo ">>> Added $ADMIN_USER to docker group (log out/in to use without sudo)"
    fi
else
    echo "[11] Skipping Docker"
fi

# 12. QoL Tools (Modern CLI + TUI)
if [[ "$INSTALL_QOL_TOOLS" == "true" && "$MINIMAL_MODE" == "false" ]]; then
    echo "[12] Installing modern QoL CLI + TUI tools..."
    apt install -y \
        zsh tmux neovim fzf ripgrep bat fd-find zoxide atuin starship \
        eza dust duf btop tldr lnav

    # yazi (file manager) - via cargo (note: pulls build deps)
    if ! command -v yazi &>/dev/null; then
        echo "    → Installing yazi (via cargo)..."
        apt install -y cargo || true
        cargo install --locked yazi-fm yazi-cli 2>/dev/null || echo "    yazi install skipped or failed"
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        install lazygit /usr/local/bin
        rm -f lazygit.tar.gz lazygit
    fi

    echo ">>> QoL tools installed. Add to your ~/.zshrc:"
    echo '    eval "$(starship init zsh)"'
    echo '    eval "$(zoxide init zsh)"'
    echo '    eval "$(atuin init zsh)"'
    echo '    alias ls="eza --icons --git"'
    echo '    alias cat="bat --paging=never"'
else
    echo "[12] Skipping QoL tools"
fi

# 13. aichat (AI assistant in terminal)
if [[ "$INSTALL_AICHAT" == "true" && "$MINIMAL_MODE" == "false" ]]; then
    echo "[13] Installing aichat (supports Gemini, Claude, etc.)..."
    if ! command -v aichat &>/dev/null; then
        apt install -y cargo || true
        cargo install aichat 2>/dev/null || echo "    aichat install skipped or failed (try manually)"
    fi
    echo ">>> Configure aichat with your Gemini API key:"
    echo "    aichat --config"
    echo "    or edit ~/.config/aichat/config.yaml"
else
    echo "[13] Skipping aichat"
fi

# 14. Cockpit (optional web UI)
if [[ "$ENABLE_COCKPIT" == "true" ]]; then
    echo "[14] Installing Cockpit..."
    apt install -y cockpit cockpit-bridge cockpit-system
    systemctl enable --now cockpit.socket
    ufw allow 9090/tcp comment 'Cockpit'
else
    echo "[14] Skipping Cockpit"
fi

# 15. Final verification & cleanup
echo "[15] Final verification and cleanup..."
apt autoremove -y
apt clean

echo
echo "=== Post-install Complete ==="
echo
echo "Next steps:"
echo "  1. Test SSH key login from your workstation"
echo "  2. Verify services:"
echo "     sudo systemctl status ssh ufw fail2ban unattended-upgrades"
if [[ "$INSTALL_DOCKER" == "true" ]]; then
    echo "     sudo systemctl status docker"
fi
echo "  3. Reboot recommended:"
echo "     sudo reboot"
echo
echo "Script finished at $(date)"