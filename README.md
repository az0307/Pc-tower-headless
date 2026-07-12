# Debian 12 Headless Server

**A consolidated, opinionated toolkit for turning a machine — including an old
Vista-era tower — into a secure, low-maintenance, genuinely pleasant headless
Debian 12/13 server, with Tailscale remote access and an optional self-hosted app
stack.**

This repo merges four previously separate pieces of work into one coherent whole:

- A hardened, configurable **post-install script** (base security + optional Docker,
  modern CLI/TUI tooling, and an in-terminal AI assistant).
- A full set of **guides** — install, long-term "meta user" practices, community
  favorites, QoL/TUI tooling, Bookworm→Trixie upgrades, and a legacy-hardware
  checklist.
- **Tower + Tailscale** docs for repurposing an old desktop and reaching it from
  anywhere.
- **`autoboros/`** — a complete, tier-based **self-hosting stack** (Caddy, monitoring,
  vault, notes, analytics, dashboards…) sized for ≤4GB RAM.

> The four uploads that seeded this repo overlapped heavily (three were variations of
> the same hardening script/guide). They've been deduplicated down to a single
> canonical script and guide set — see [`CHANGELOG.md`](CHANGELOG.md) for exactly what
> was merged.

---

## Layers

Think of the repo as three layers you can adopt independently:

| Layer | What it is | Where |
|-------|-----------|-------|
| **1. Base OS + hardening** | One script + guides to install and secure a headless Debian server (SSH key-only, UFW, Fail2ban, unattended-upgrades, optional Docker/QoL/AI tooling). Works on any server — VPS, VM, bare metal, or an old tower. | `scripts/`, `docs/01`–`docs/06` |
| **2. The physical tower + remote access** | Repurposing a Vista-era desktop, plus Tailscale for reaching it from anywhere without opening ports. | `docs/07`, `docs/08` |
| **3. Self-hosted apps** | An optional, resource-tiered Docker app stack for the tower. Deploy only the tiers your RAM allows. | `autoboros/` |

You can stop after Layer 1 for a plain hardened server, or go all the way to a
self-hosted homelab on 15-year-old hardware.

---

## Quick Start

### Layer 1 — base server

```bash
# On a fresh minimal Debian 12 (Bookworm) or 13 (Trixie) install:
git clone <this-repo-url> debian12-headless-server
cd debian12-headless-server

# Review and set the flags at the top of the script
nano scripts/debian-server-postinstall.sh

# Run as root
sudo bash scripts/debian-server-postinstall.sh
```

The script auto-detects Bookworm vs Trixie and is configured entirely by flags at the
top (hardening is always on; Docker, QoL tools, `aichat`, Cockpit, legacy-hardware
tweaks, and minimal mode are opt-in).

### Layer 2 — old tower + remote access

- New to the tower? Start with [`docs/07-tower-fresh-install.md`](docs/07-tower-fresh-install.md).
- Want to reach it from your phone/laptop anywhere? [`docs/08-tailscale-remote-access.md`](docs/08-tailscale-remote-access.md).

### Layer 3 — self-hosted apps

```bash
cd autoboros
bash install.sh                          # base + Docker + Tailscale + tuning
# configure .env, start core, reboot, then:
bash scripts/setup-all-apps.sh tier1     # deploy apps by tier (tier1 / tier2 / all)
bash scripts/health-check.sh
```

See [`autoboros/README.md`](autoboros/README.md) for the full tier breakdown and
per-app RAM budgets.

> **Note on overlap:** `autoboros/install.sh` also does base hardening (UFW, Fail2ban,
> Docker, Tailscale, ZRAM) as part of standing up the app host. If you're deploying
> the autoboros stack, you don't need to run `scripts/debian-server-postinstall.sh`
> first — pick the entry point that matches your goal. Use the postinstall script for
> a general-purpose server; use autoboros when the tower's job is to host the apps.

---

## Repository Layout

```
debian12-headless-server/
├── README.md                          # you are here
├── CHANGELOG.md                       # what was consolidated, and why
├── LICENSE                            # MIT
├── scripts/
│   └── debian-server-postinstall.sh   # canonical base hardening + QoL script (Bookworm/Trixie)
├── docs/
│   ├── 01-installation-guide.md       # minimal headless install + hardening walkthrough
│   ├── 02-meta-best-practices.md      # long-term philosophy, evolution path
│   ├── 03-community-favorites.md      # most-loved 2026 tools (Netdata, restic, Caddy, …)
│   ├── 04-qol-tui-smart-cli.md        # modern smart CLI + TUI tooling
│   ├── 05-upgrade-bookworm-to-trixie.md
│   ├── 06-legacy-hardware-checklist.md # Vista-era / low-RAM specifics
│   ├── 07-tower-fresh-install.md      # repurposing an old desktop tower
│   └── 08-tailscale-remote-access.md  # secure remote access, no port-forwarding
└── autoboros/                         # optional tier-based self-hosting stack (see its own README)
```

---

## Design Principles

- **Minimal attack surface** — netinst base, deny-inbound firewall, key-only SSH.
- **Runs on old hardware** — explicit Vista-era / low-RAM support (legacy + minimal modes).
- **Secure remote access without exposure** — Tailscale instead of port-forwarding.
- **Reproducible & documented** — configs and decisions live in version control; the
  guides push you toward Ansible/IaC as you grow.
- **Pleasant to live with** — optional modern shell + TUI stack so you actually enjoy
  maintaining it for years.

---

## License

MIT — see [`LICENSE`](LICENSE).
