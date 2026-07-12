# Installation Guide

## Prerequisites

- **CPU**: x86_64 (amd64) — Debian 13 dropped i386
- **RAM**: 1GB minimum, 2GB+ recommended
- **Disk**: 10GB free minimum
- **Network**: Ethernet, Tailscale account
- **OS**: Debian 13 Trixie (fresh headless install)

## Step 1: Install Debian 13

- No desktop environment
- Standard system utilities only
- SSH server enabled
- GRUB on primary disk

## Step 2: Clone Repository

```bash
git clone https://github.com/YOURNAME/autoboros.git ~/autoboros
cd ~/autoboros
```

## Step 3: Run Base Installer

```bash
bash install.sh
```

12 phases: pre-flight, base packages, Docker, ZRAM, EarlyOOM, UFW, unattended upgrades, Fail2ban, Tailscale, directories, MOTD, shell env, Beszel agent hook.

## Step 4: Configure

```bash
cp ~/docker/caddy/.env.example ~/docker/caddy/.env
nano ~/docker/caddy/.env
# Set TAILSCALE_DOMAIN
```

## Step 5: Start Core Services

```bash
cd ~/docker
docker compose up -d
```

## Step 6: Reboot + Performance Upgrade

```bash
sudo reboot
# After reboot:
bash ~/autoboros/performance-upgrade.sh
sudo reboot
```

## Step 7: Deploy Apps by Tier

```bash
# Tier 1 (<=2GB RAM towers)
bash scripts/setup-all-apps.sh tier1

# Tier 2 (2-4GB RAM towers)
bash scripts/setup-all-apps.sh tier2

# All tower apps (>=4GB)
bash scripts/setup-all-apps.sh all

# Workers (on laptops)
ansible-playbook -i ansible/inventory.ini ansible/site.yml --ask-become-pass
```

## Step 8: Verify

```bash
bash scripts/health-check.sh
mem
```
