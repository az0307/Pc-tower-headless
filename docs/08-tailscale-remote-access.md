# Remote Access with Tailscale

Tailscale is a WireGuard-based mesh VPN. It's the highest "security per effort"
way to reach a headless tower from anywhere — your phone, a laptop on another
network — without opening any inbound ports on your router or exposing SSH to the
public internet.

This pairs well with the key-only SSH hardening in
`scripts/debian-server-postinstall.sh`: the server stays closed to the internet
(UFW default-deny inbound), and you reach it over the private Tailscale network
instead.

The `autoboros/` stack in this repo already installs and brings up Tailscale as one
of its bootstrap phases; this doc is the standalone equivalent for a plain server.

---

## Why Tailscale for a Homelab Tower

- No inbound port-forwarding on the router — nothing to expose or get scanned.
- Every device gets a stable `100.x.y.z` address on your private tailnet.
- Works across NAT, mobile data, and different networks transparently.
- SSH, web dashboards, and any other service become reachable by tailnet IP or
  MagicDNS name, only to devices you've authorized.

---

## Install on the Server

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

`tailscale up` prints an authentication URL — open it in any browser and sign in to
add the tower to your tailnet. To bring it up non-interactively (e.g. from a script),
use a pre-generated [auth key](https://tailscale.com/kb/1085/auth-keys):

```bash
sudo tailscale up --auth-key tskey-auth-XXXXXXXX
```

Get the server's tailnet address:

```bash
tailscale ip -4        # e.g. 100.64.1.2
tailscale status       # see all devices on your tailnet
```

### Recommended flags for a headless server

```bash
# Disallow inbound connections initiated to this node beyond what you intend,
# and advertise a stable hostname via MagicDNS:
sudo tailscale up --ssh=false --hostname=tower

# Optional: only accept traffic, don't route for others (default for a leaf node)
```

Enable **MagicDNS** in the Tailscale admin console so you can use
`ssh youruser@tower` instead of the raw `100.x` address.

---

## Install on Clients

**Phone (Android/iOS):** install the Tailscale app from the Play Store / App Store,
or on Android from [F-Droid](https://f-droid.org/packages/com.tailscale.ipn/). Sign
in with the same account; the tower appears in the device list.

**Laptop / desktop:** same `curl … | sh` one-liner on Linux, or the desktop app on
macOS/Windows.

---

## Connect

Once both ends are on the tailnet:

```bash
# By tailnet IP
ssh youruser@100.64.1.2

# By MagicDNS name (if enabled)
ssh youruser@tower
```

Web dashboards from the `autoboros/` stack (Homarr, Beszel, Vaultwarden, etc.) are
reachable the same way — by the tower's tailnet IP/name behind Caddy — without any
public exposure.

---

## Firewall Interaction (UFW)

The hardening script sets UFW to deny inbound by default and allows only your SSH
port. Tailscale traffic arrives on the `tailscale0` interface and generally works
without extra rules because it's established as outbound-initiated WireGuard.

If you want to **restrict SSH to Tailscale only** (a strong posture — nothing on the
LAN or internet can even reach SSH), allow SSH on the tailscale interface and remove
the general SSH allow:

```bash
sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH via Tailscale'
sudo ufw delete allow 22/tcp        # drop the LAN/internet SSH rule (adjust if you use a custom port)
sudo ufw reload
```

> Do this only **after** you've confirmed you can SSH in over Tailscale — otherwise
> you can lock yourself out of a headless box. Keep physical/console access handy the
> first time.

---

## Reference

| Scenario | Command |
|----------|---------|
| Server: install | `curl -fsSL https://tailscale.com/install.sh \| sh` |
| Server: bring up | `sudo tailscale up` |
| Server: unattended | `sudo tailscale up --auth-key tskey-auth-...` |
| Get tailnet IP | `tailscale ip -4` |
| List devices | `tailscale status` |
| Connect (IP) | `ssh youruser@100.64.X.Y` |
| Connect (MagicDNS) | `ssh youruser@tower` |

---

## Hardening Notes

1. Keep SSH **key-only** (the postinstall script already does this) even over Tailscale.
2. Consider restricting SSH to the `tailscale0` interface (above) once Tailscale is proven.
3. Use Tailscale **ACLs** in the admin console to limit which devices can reach the tower.
4. Enable **key expiry** and review your device list periodically.
5. Tailscale is remote *access*, not a substitute for backups or fail2ban — keep those too.
