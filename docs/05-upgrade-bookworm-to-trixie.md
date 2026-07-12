# Upgrading from Debian 12 (Bookworm) to Debian 13 (Trixie)

This guide covers a clean and safe upgrade path from Debian 12 to Debian 13 on a headless server.

> **Warning**: Always test upgrades in a VM or snapshot first. Have backups ready.

## Recommended Approach: Fresh Install (Preferred for Servers)

For headless servers, the cleanest and most reliable method is usually a **fresh install** using the updated `debian-server-postinstall.sh` script rather than an in-place `dist-upgrade`.

### Steps for Fresh Install

1. **Backup everything important**
   - `/etc` (especially configs)
   - Important data volumes
   - Database dumps
   - User home directories

2. **Install Debian 13 (Trixie)** using the netinst ISO

3. **Run the updated bootstrap script**
   ```bash
   sudo bash debian-server-postinstall.sh
   ```
   The script will auto-detect Trixie and configure everything correctly.

4. **Restore your data and services**

This approach avoids most upgrade-related surprises.

---

## Alternative: In-Place Upgrade (Advanced)

Only do this if you have a strong reason to preserve the exact system state.

### Preparation

```bash
sudo apt update
sudo apt full-upgrade
sudo apt install deborphan
```

### Main Upgrade Steps

1. **Update sources.list**
   ```bash
   sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
   sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*.list 2>/dev/null || true
   ```

2. **Minimal upgrade first**
   ```bash
   sudo apt update
   sudo apt upgrade --without-new-pkgs
   ```

3. **Full dist-upgrade**
   ```bash
   sudo apt full-upgrade
   ```

4. **Remove obsolete packages**
   ```bash
   sudo apt autoremove --purge
   sudo deborphan | xargs sudo apt purge -y
   ```

5. **Reboot**
   ```bash
   sudo reboot
   ```

6. **Verify**
   ```bash
   cat /etc/debian_version
   uname -r
   ```

---

## Post-Upgrade Tasks

After upgrading (or fresh installing Trixie):

- Re-run parts of your postinstall script if needed (especially QoL tools and `aichat`)
- Check service status: `systemctl --failed`
- Review logs: `journalctl -p 3 -xb`
- Update your monitoring/backup scripts if any paths changed

---

## Recommendation

For most headless server setups in 2026:

- **Prefer a fresh Trixie install** + re-run `debian-server-postinstall.sh`
- Only do in-place upgrade if you have very specific reasons and good backups + snapshots

The dual-support script makes moving to Trixie very straightforward.