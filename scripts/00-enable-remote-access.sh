#!/bin/bash
#
# Stage 0 — Enable Remote SSH Access
#
# Run this AT THE TOWER, with the monitor and keyboard still attached, right
# after a fresh Debian install. It gets password-based SSH working and verifies
# it, so you can then UNPLUG THE MONITOR and finish the whole setup remotely
# from your laptop.
#
# Usage:  sudo bash 00-enable-remote-access.sh
#
# This is a deliberately gentle first step. Password SSH is a TEMPORARY bridge:
# once you can log in from your laptop, install your SSH key (ssh-copy-id) and
# run ./debian-server-postinstall.sh to harden the box to key-only access.
#
# Idempotent: safe to run more than once.

set -euo pipefail

# ========================== CONFIGURATION ==========================
ADMIN_USER=""            # SSH user to enable. Empty = auto-detect the normal login user.
SET_PASSWORD=true        # Prompt to (re)set that user's password for SSH login.
PERMIT_ROOT_LOGIN=false  # Allow root over SSH with a password (not recommended).
SSH_PORT=22
# ===================================================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this with sudo (needs to configure sshd)."
    exit 1
fi

echo "=== Stage 0: Enable Remote SSH Access ==="
echo "Host: $(hostname)   Date: $(date)"
echo

# --- Resolve which user will log in over SSH ---
if [[ -z "$ADMIN_USER" ]]; then
    ADMIN_USER="${SUDO_USER:-}"
fi
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "root" ]]; then
    # Fall back to the first regular (human) account.
    ADMIN_USER="$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd || true)"
fi
echo "[1/6] SSH login user: ${ADMIN_USER:-<none found — will create one>}"

# --- Install and enable the SSH server ---
echo "[2/6] Installing and enabling OpenSSH server..."
apt update
apt install -y openssh-server
systemctl enable --now ssh

# --- Ensure the user exists and (optionally) set its password ---
echo "[3/6] Preparing the login user..."
if [[ -z "$ADMIN_USER" ]]; then
    read -r -p "      No user found. Enter a username to create: " ADMIN_USER
fi
if ! id "$ADMIN_USER" &>/dev/null; then
    echo "      Creating user $ADMIN_USER and adding to sudo group..."
    adduser --gecos "" "$ADMIN_USER"        # prompts for a password
    usermod -aG sudo "$ADMIN_USER"
elif [[ "$SET_PASSWORD" == "true" ]]; then
    echo "      Set/confirm the SSH password for $ADMIN_USER:"
    passwd "$ADMIN_USER"
fi

# --- Turn on password authentication via a clean drop-in ---
echo "[4/6] Enabling password authentication (temporary bridge)..."
install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-remote-access.conf << EOF
# Stage 0 temporary remote access — added by 00-enable-remote-access.sh
# Replace with key-only hardening later via debian-server-postinstall.sh
Port $SSH_PORT
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PubkeyAuthentication yes
PermitRootLogin $([[ "$PERMIT_ROOT_LOGIN" == "true" ]] && echo "yes" || echo "prohibit-password")
EOF

sshd -t
systemctl restart ssh

# --- Firewall: only touch UFW if it's already active ---
echo "[5/6] Checking firewall..."
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "$SSH_PORT"/tcp comment 'SSH (stage0)' || true
    echo "      UFW active — allowed port $SSH_PORT/tcp."
else
    echo "      UFW not active — nothing to open (default Debian has no host firewall yet)."
fi

# --- Verification checks ---
echo "[6/6] Running checks..."
ok=true
if systemctl is-active --quiet ssh; then echo "      [OK]   sshd is active"; else echo "      [FAIL] sshd is NOT active"; ok=false; fi
if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then echo "      [OK]   listening on port $SSH_PORT"; else echo "      [FAIL] not listening on port $SSH_PORT"; ok=false; fi
if id "$ADMIN_USER" &>/dev/null; then echo "      [OK]   user $ADMIN_USER exists"; else echo "      [FAIL] user $ADMIN_USER missing"; ok=false; fi
if ip route | grep -q '^default'; then echo "      [OK]   network has a default route"; else echo "      [WARN] no default route — check the Ethernet cable"; fi

echo
echo "================================================================"
if [[ "$ok" == "true" ]]; then
    echo " Remote SSH is ready. Connect from your LAPTOP using one of:"
    echo
    for ip in $(hostname -I); do
        printf '     ssh %s@%s\n' "$ADMIN_USER" "$ip"
    done
    echo
    echo " Steps from here:"
    echo "   1. Open a terminal on your laptop and run one of the commands above."
    echo "   2. Log in with the password you just set. If it works —"
    echo "   3. UNPLUG THE MONITOR AND KEYBOARD. The tower is now headless."
    echo "   4. Everything else is done over SSH from your laptop:"
    echo "        # install your key so you can drop the password later:"
    echo "        ssh-copy-id $ADMIN_USER@<ip-above>        # run this ON your laptop"
    echo "        # then harden to key-only + firewall + fail2ban:"
    echo "        cd <repo>/debian12-headless-server"
    echo "        sudo bash scripts/debian-server-postinstall.sh"
    echo
    echo " NOTE: password SSH is on for now. The hardening script will switch to"
    echo "       key-only automatically ONCE it detects your installed key, so you"
    echo "       cannot lock yourself out. Until then, fail2ban is recommended and"
    echo "       Tailscale (docs/08) is the safest way to expose this beyond the LAN."
else
    echo " One or more checks FAILED — do NOT unplug the monitor yet."
    echo " Re-check the messages above (is the Ethernet plugged in? did sshd start?)."
fi
echo "================================================================"
