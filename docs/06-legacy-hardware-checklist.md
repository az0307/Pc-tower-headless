# Legacy / Vista-Era Hardware Testing Checklist

Use this checklist when installing on older PCs (Core 2 Duo/Quad, early Core i-series, ~2-4GB RAM, 2006–2009 hardware).

## Pre-Installation

- [ ] Use the correct ISO:
  - Most Vista-era machines → `amd64` netinst
  - Very old 32-bit only hardware → `i386` netinst
- [ ] Verify the ISO checksum
- [ ] Create bootable USB (Rufus in DD mode or `dd`)
- [ ] Have physical access or serial console ready (old hardware often lacks IPMI)

## During Installation (Debian Installer)

- [ ] Choose **text mode** install (more reliable on old hardware)
- [ ] When selecting software, **only** enable:
  - SSH server
  - standard system utilities
- [ ] Make sure **non-free-firmware** is available (it is included in modern netinst)
- [ ] At GRUB installation screen, you can add these parameters if needed:
  ```
  intel_idle.max_cstate=1 processor.max_cstate=1
  ```
- [ ] Choose guided partitioning (simple is better on old drives)

## Post-Installation (Run the Script)

Recommended flags for old hardware:

```bash
LEGACY_HARDWARE=true
MINIMAL_MODE=true          # Skip heavy QoL tools
INSTALL_DOCKER=false
INSTALL_QOL_TOOLS=false
INSTALL_AICHAT=false
```

Or a balanced setup:

```bash
LEGACY_HARDWARE=true
INSTALL_QOL_TOOLS=true     # Light modern tools still useful
MINIMAL_MODE=false
```

## Post-Install Verification

- [ ] Boot completes without long pauses or high fan noise
- [ ] CPU temperature and frequency look reasonable (`sensors` or `htop`)
- [ ] No excessive CPU usage at idle
- [ ] Network works (old NICs sometimes need firmware — already included)
- [ ] SSH login works from another machine
- [ ] Run `needrestart` and handle any services that need restarting

## Common Fixes for Old Hardware

| Symptom                    | Possible Fix                                      | How |
|---------------------------|---------------------------------------------------|-----|
| High idle CPU / heat      | `intel_idle.max_cstate=1`                        | Set via LEGACY_HARDWARE=true or manually in GRUB |
| Slow boot / long pauses   | Disable some C-states or use `acpi=off` (last resort) | GRUB parameters |
| Old network card not working | Ensure `non-free-firmware` was installed        | Already in sources.list |
| Graphics issues (if not headless) | Use `nomodeset`                              | GRUB parameter |
| Very low RAM (<2GB)       | Use `MINIMAL_MODE=true` + skip Docker/QoL       | Script flag |

## Recommended Tools on Old Hardware

Even in minimal mode, these are usually safe and useful:

- `htop` or `btop` (light monitoring)
- `vim` or `nano`
- `curl`, `wget`, `git`
- `fail2ban` + `ufw`
- `unattended-upgrades`

Avoid installing heavy tools like full Docker or many TUI apps if RAM is very limited.

## Final Tips

- Old mechanical hard drives benefit from `noatime` in `/etc/fstab`
- Consider adding `zram` for better memory handling on low-RAM machines
- Test thoroughly before putting into production use

This checklist + the `LEGACY_HARDWARE=true` + `MINIMAL_MODE=true` combination gives you a very reliable setup on Vista-era hardware.