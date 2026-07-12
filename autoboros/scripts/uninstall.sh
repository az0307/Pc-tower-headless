#!/bin/bash
set -euo pipefail

echo "=== AUTOBOROS Uninstall ==="
read -p "Type 'AUTOBOROS' to confirm full removal: " CONFIRM
echo
[[ "$CONFIRM" == "AUTOBOROS" ]] || { echo "Aborted."; exit 1; }

echo "Stopping all containers..."
cd ~/docker && docker compose down 2>/dev/null || true
for f in ~/apps/*.yml; do
    [[ -f "$f" ]] && docker compose -f "$f" down 2>/dev/null || true
done

echo "Disabling services..."
sudo systemctl disable --now fail2ban earlyoom zramswap tailscaled unattended-upgrades 2>/dev/null || true

echo "Removing packages..."
sudo apt-get remove -y zram-tools earlyoom fail2ban unattended-upgrades 2>/dev/null || true

echo "Restoring .bashrc..."
LATEST=$(ls -t ~/.bashrc.autoboros-backup.* 2>/dev/null | head -n1)
[[ -n "$LATEST" ]] && cp "$LATEST" ~/.bashrc

sudo rm -f /etc/update-motd.d/10-autoboros /etc/sysctl.d/99-autoboros-performance.conf
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' /etc/default/grub
sudo update-grub

echo "Uninstall complete. Data preserved in ~/docker/ and ~/backups/"
