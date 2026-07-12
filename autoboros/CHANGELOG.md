# Changelog

## [3.0.0] - 2026-07-06

### Added
- Beszel monitoring hub + agent (lightweight Prometheus alternative, ~30MB RAM)
- Docmost wiki/knowledge base (Confluence alternative, collaborative editing)
- Memos quick-capture notes (timeline-style, single Go binary, ~20MB)
- Karakeep bookmark archiver (formerly Hoarder, AI-tagged bookmarks)
- Plausible Analytics (GDPR-compliant, cookie-free, ~512MB)
- Activepieces automation (Zapier alternative, 150+ integrations)
- Excalidraw whiteboard (infinite canvas, E2E encrypted, static web app)
- NocoDB database spreadsheet (Airtable alternative, SQLite default)
- Pocket ID passkey auth (OIDC provider, passwordless)
- Beszel agent for worker laptop monitoring
- `apps/` directory with individual compose files per app
- `scripts/setup-beszel.sh` for hub + agent auto-configuration
- `scripts/setup-all-apps.sh` for one-command app deployment
- Full hardware compatibility matrix (tested: OptiPlex 745/755, dc7800, M57, ThinkCentre M720q)

### Changed
- Architecture: hub-and-spoke with **app tiers**
  - **Tier 0** (Tower, <=512MB): Caddy, Beszel Hub, Uptime Kuma, Watchtower
  - **Tier 1** (Tower, <=256MB each): Vaultwarden, Homarr, Dockge, Memos, Pocket ID
  - **Tier 2** (Tower, <=512MB each): Plausible, NocoDB, Karakeep, Excalidraw
  - **Tier 3** (Workers only): n8n, Trilium, Activepieces, Docmost, Changedetection, Stirling-PDF
- Docker log limits: 5MB x 2 -> **3MB x 2** (even more aggressive)
- ZRAM: 75% -> **adaptive** (50% if >=4GB, 75% if <4GB, 100% if <2GB)
- `install.sh` now detects RAM tier and suggests app deployment strategy
- `performance-upgrade.sh` adds Beszel agent auto-install

### Fixed
- All container images pinned to specific versions (not `:latest`)
- Health check intervals increased to reduce CPU wakeups on old hardware
- Beszel hub replaces Netdata/Crowdsec bloat (~30MB vs ~600MB)

## [2.0.0] - 2026-06-25

- Performance upgrade script
- Aggressive kernel tuning
- Tower RAM budget down to ~816MB

## [1.0.0] - 2026-06-21

- Initial release
