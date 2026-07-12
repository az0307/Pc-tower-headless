# Repurposing a Vista-Era Tower as a Headless Debian Server

This guide covers taking an old desktop tower (Windows XP / Vista era, ~2006–2009,
often locked to a guest account with no admin access) and turning it into a clean,
headless Debian server.

It complements `01-installation-guide.md` (the generic install/hardening walkthrough)
and `06-legacy-hardware-checklist.md` (old-hardware specifics). Start here if the
machine still boots into its original OS and you need to get Debian onto it.

---

## The Typical Situation

```
Old tower boots to Windows XP / Vista (often a locked Guest account)
No admin access, can't install anything
One spinning hard drive (e.g. 400GB)
Core 2 Duo/Quad, 2–4GB RAM
```

You do not need the existing OS or its password. You are going to wipe the drive
and install Debian fresh.

---

## Getting Debian Onto the Machine (easiest first)

### Option 1 — Boot from USB (recommended)

**You need:** another PC to write the USB, and an 8GB+ flash drive.

1. On another machine, download the Debian **netinst** ISO (see
   `01-installation-guide.md` → Preparation). For most Vista-era machines use
   **amd64**; for genuinely 32-bit-only hardware use **i386**.
2. Write it to USB with [Rufus](https://rufus.ie) (DD image mode) on Windows, or
   `dd` on Linux/macOS.
3. Plug the USB into the tower.
4. Power on and press the boot-menu key — commonly **F12**, **Del**, **F2**, or
   **Esc** (varies by BIOS).
5. Select the USB device and boot the Debian installer.

### Option 2 — Network boot (PXE)

If the machine won't boot from USB (some old BIOSes are picky):

1. Connect the tower to your router by Ethernet.
2. Run a PXE server on another machine on the LAN.
3. Set the tower to network-boot in BIOS.

This is more involved; only reach for it if USB genuinely fails.

### Option 3 — Pull the drive and image it elsewhere

The quickest route when the BIOS is uncooperative:

1. Power off, unplug the tower.
2. Open the case and remove the hard drive.
3. Connect it to another machine (SATA-to-USB adapter or internal port).
4. Wipe it and install/flash Debian from that machine.
5. Put the drive back in the tower.

> Booting the installer directly on the tower (Option 1) is almost always simpler
> than imaging the drive elsewhere — prefer it unless you have no choice.

---

## Installer Choices for a Headless Tower

Follow `01-installation-guide.md` for the full walkthrough. The choices that matter
most on old hardware:

- **Text-mode install** — more reliable than the graphical installer on old GPUs.
- **Software selection** — deselect everything except **SSH server** and
  **standard system utilities**. No desktop environment.
- **Non-free firmware** — leave it enabled; old NICs and chipsets often need it.
- **GRUB** — install to the primary disk (MBR on most Vista-era boards).
- If you hit high idle CPU/heat or boot stalls, add
  `intel_idle.max_cstate=1 processor.max_cstate=1` at the GRUB stage (see
  `06-legacy-hardware-checklist.md`).

After install, the tower boots straight to a text login prompt — headless by design.

---

## First Network Setup

A server benefits from a predictable address. You can either reserve a DHCP lease
on your router (simplest) or set a static address on the tower.

### Static IP with systemd-networkd (recommended on modern Debian)

Create `/etc/systemd/network/20-wired.network`:

```ini
[Match]
Name=en*

[Network]
Address=192.168.1.75/24
Gateway=192.168.1.1
DNS=1.1.1.1
DNS=8.8.8.8
```

```bash
sudo systemctl enable --now systemd-networkd
sudo systemctl restart systemd-networkd
```

> On a fresh Debian install that still uses `/etc/network/interfaces`, the classic
> equivalent is an `iface … inet static` stanza followed by
> `sudo systemctl restart networking`. Prefer whichever your install already uses;
> don't run both managers at once.

### Confirm SSH is up

```bash
sudo systemctl enable --now ssh
ip -4 addr        # note the tower's address
```

Then run the hardening script from `scripts/debian-server-postinstall.sh` and
harden SSH to key-only (see `01-installation-guide.md` §4.6). For remote access
from outside the LAN, see `08-tailscale-remote-access.md`.

---

## Where the Tower Fits in a Small Home Lab

A common layout: a hotspot/router for internet, your daily laptop as the control
machine, and the old tower as the always-on headless server.

```
                    +------------------+
                    |   Router / GW    |  <- Internet
                    |   192.168.1.1    |
                    +---------+--------+
                              |
        +---------------------+---------------------+
        |                     |                     |
        v                     v                     v
+---------------+   +------------------+   +------------------+
|  Laptop       |   |  Debian Tower    |   |  Other device    |
|  (control)    |   |  (headless srv)  |   |  (NAS / spare)   |
|  192.168.1.100|   |  192.168.1.75    |   |  ...             |
+---------------+   +------------------+   +------------------+
```

Once the base server is up, the `autoboros/` stack in this repo turns the tower into
a reverse-proxied host for lightweight self-hosted apps (dashboard, vault, notes,
monitoring, analytics) sized for ≤4GB RAM. See `autoboros/README.md`.

---

## Checklist

- [ ] Debian netinst written to USB (amd64, or i386 for 32-bit-only hardware)
- [ ] Booted the installer on the tower (or imaged the pulled drive)
- [ ] SSH server + standard utilities only; no desktop
- [ ] Predictable address (DHCP reservation or static)
- [ ] `scripts/debian-server-postinstall.sh` run, SSH hardened to key-only
- [ ] (Optional) Tailscale up for remote access — see `08-tailscale-remote-access.md`
- [ ] (Optional) `autoboros/` app stack deployed
