# AUTOBOROS ULTIMATUM v3.0

> **Debian 13 Trixie — Headless Tower for Vista-Era Hardware**
>
> Gateway, monitoring, vault, notes, analytics, wiki, whiteboard on ≤4GB RAM.
> Heavy automation runs on worker laptops via Ansible.

[![CI](https://github.com/YOURNAME/autoboros/actions/workflows/ci.yml/badge.svg)](https://github.com/YOURNAME/autoboros/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-13_Trixie-A81D33?logo=debian)](https://www.debian.org/releases/trixie/)

```
    +------------------------------------------+
    |      🐍  AUTOBOROS ULTIMATUM v3.0  🐍    |
    |      Headless • Matrix • Secure          |
    |      EOL: 2028 → 2030 → 2035           |
    +------------------------------------------+
```

## What's New in v3.0

| Feature | v2 | v3 |
|---------|-----|-----|
| **Tier system** | No | **Tier 0-3** based on RAM |
| **Beszel monitoring** | None | **48MB hub + agent** |
| **Memos notes** | None | **64MB quick-capture** |
| **Pocket ID** | None | **128MB passkey auth** |
| **Plausible analytics** | None | **512MB GDPR analytics** |
| **NocoDB** | None | **256MB Airtable alt** |
| **Karakeep** | None | **256MB AI bookmarks** |
| **Excalidraw** | None | **64MB whiteboard** |
| **Activepieces** | None | **512MB Zapier alt (worker)** |
| **Docmost** | None | **512MB wiki (worker)** |
| **App deployment** | Single compose | **Per-app compose files** |
| **Image versions** | `:latest` | **Pinned versions** |
| **ZRAM** | 75% fixed | **Adaptive 50/75/100%** |

## Quick Start

```bash
git clone https://github.com/YOURNAME/autoboros.git ~/autoboros
cd ~/autoboros
bash install.sh
# Configure .env, start core, reboot
bash performance-upgrade.sh
# Reboot again
bash scripts/setup-all-apps.sh tier1  # or tier2, all
bash scripts/health-check.sh
```

## App Tiers

### Tier 0 — Core (always running, ~224MB)
| Service | RAM | Role |
|---------|-----|------|
| Caddy | 64MB | Reverse proxy |
| Beszel Hub | 48MB | System monitoring |
| Uptime Kuma | 80MB | Uptime monitoring |
| Watchtower | 32MB | Auto-updates |

### Tier 1 — Essential (deploy as needed, ≤256MB each)
| Service | RAM | Role |
|---------|-----|------|
| Homarr | 192MB | Dashboard |
| Dockge | 192MB | Container manager |
| Vaultwarden | 192MB | Password vault |
| Memos | 64MB | Quick notes |
| Pocket ID | 128MB | Passkey auth |

### Tier 2 — Power (≤512MB each)
| Service | RAM | Role |
|---------|-----|------|
| Plausible | 512MB | GDPR analytics |
| NocoDB | 256MB | Database spreadsheet |
| Karakeep | 256MB | AI bookmarks |
| Excalidraw | 64MB | Whiteboard |

### Tier 3 — Workers only (on laptops)
| Service | RAM | Role |
|---------|-----|------|
| n8n | 512MB | Workflow automation |
| Trilium | 512MB | Knowledge base |
| Activepieces | 512MB | Zapier alternative |
| Docmost | 512MB | Wiki |
| Changedetection | 256MB | Website monitor |
| Stirling-PDF | 512MB | PDF tools |

## File Layout

```
autoboros/
├── install.sh                 # Base setup (13 phases, tier-aware)
├── performance-upgrade.sh     # Aggressive kernel tuning
├── docker-compose.yml         # Tier 0 core only
├── Caddyfile                  # All routes including apps
├── Caddyfile.env              # Environment template
├── apps/
│   ├── homarr.yml             # Tier 1
│   ├── dockge.yml
│   ├── vaultwarden.yml
│   ├── memos.yml
│   ├── pocket-id.yml
│   ├── plausible.yml          # Tier 2
│   ├── nocodb.yml
│   ├── karakeep.yml
│   ├── excalidraw.yml
│   ├── n8n.yml                # Tier 3 (workers)
│   ├── trilium.yml
│   ├── activepieces.yml
│   ├── docmost.yml
│   ├── changedetection.yml
│   └── stirling-pdf.yml
├── scripts/
│   ├── setup-beszel.sh        # Hub + agent setup
│   ├── setup-all-apps.sh     # Deploy by tier
│   ├── health-check.sh       # System verification
│   ├── restore.sh            # Backup restoration
│   ├── uninstall.sh          # Clean removal
│   └── update-check.sh       # Update + EOL warnings
├── ansible/                   # Worker laptop deployment
├── backup.sh                  # Weekly restic backup
├── .restic-exclude            # Backup exclusions
├── n8n-workflow.json          # Changedetection pipeline
├── docs/                      # Full documentation
├── .github/workflows/ci.yml   # ShellCheck + compose validation
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

## Performance Features

- **Adaptive ZRAM**: 50% (≥4GB), 75% (2-4GB), 100% (<2GB)
- **zswap** kernel compression
- **BBR** TCP congestion control
- **CPU governor** auto-detected (performance/ondemand)
- **15+ services disabled** on headless
- **noatime** filesystem mounts
- **mitigations=off** option for ≤2GB
- **EarlyOOM** guardian
- **3MB log limits** per container

## EOL Timeline

```
2025-08  Debian 13.0 released
2026-05  Debian 13.5 current
2028-08  Full support ENDS     ← Plan migration
2030-06  LTS support ENDS
2035-06  Paid ELTS ENDS
```

## Documentation

- [Installation](docs/INSTALL.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Hardware Guide](docs/HARDWARE.md)
- [Contributing](CONTRIBUTING.md)

## License

MIT — see [LICENSE](LICENSE)
