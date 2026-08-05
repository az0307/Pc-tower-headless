# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**Pc-tower-headless** (repo name `debian12-headless-server`, canonical clone dir `Pc-tower-headless` / `debian12-headless-server`) is a bash-script + Markdown toolkit for turning a machine — including old, low-RAM hardware — into a hardened, headless Debian 12/13 server with Tailscale remote access and an optional self-hosted app stack. There is no compiled application, no package.json, no build system — everything is shell scripts and docs, meant to be run directly with `bash`/`sudo bash`.

The repo merges four previously separate uploads into one deduplicated toolkit — see `CHANGELOG.md` for the full merge history and rationale (why the "Meta Server Bootstrap" script won over two other overlapping hardening scripts, why `autoboros/` was kept as its own subtree, etc.).

### The four layers

| Layer | What it is | Where |
|-------|-----------|-------|
| **1. Base OS + hardening** | Post-install script + guides: SSH key-only, UFW, Fail2ban, unattended-upgrades, optional Docker/QoL/AI tooling. Works on any Debian box. | `scripts/`, `docs/01`–`docs/06` |
| **2. Physical tower + remote access** | Repurposing an old (Vista-era) desktop, reaching it via Tailscale without port-forwarding. | `docs/07`, `docs/08` |
| **3. Self-hosted apps** | Tier-based Docker app stack sized for ≤4GB RAM, deployed independently of layer 1. | `autoboros/` (its own subtree with its own README/CHANGELOG/LICENSE/CI) |
| **4. The `srv` command** | Daily-driver CLI/TUI front door wrapping all of the above — dashboard, health, updates, widget launcher, app-stack actions, Tailscale, backups, saved-host SSH. | `bin/srv`, `docs/09` |

**Important overlap to know about:** `autoboros/install.sh` *also* does base hardening (UFW, Fail2ban, Docker, Tailscale, ZRAM) as part of standing up the app host. `scripts/debian-server-postinstall.sh` and `autoboros/install.sh` are two independent entry points, not layered — use the postinstall script for a general-purpose server, use `autoboros/install.sh` when the tower's job is specifically to host the app stack. Don't try to "merge" these; the README and CHANGELOG explicitly document why they stay separate.

## Commands

There is no build/lint/test toolchain for the top-level repo. Validate shell scripts with:

```bash
bash -n scripts/debian-server-postinstall.sh   # syntax check, no execution
shellcheck scripts/*.sh bin/srv                # if shellcheck is installed
```

`autoboros/` has its own CI (`autoboros/.github/workflows/ci.yml`, GitHub Actions on push/PR to `main`): ShellCheck (severity: warning) over the whole tree, `docker compose config` validation of `autoboros/docker-compose.yml` and every `autoboros/apps/*.yml`, and markdownlint over all `.md` files.

### Running the toolkit

```bash
# Stage 0 — enable + verify password SSH before hardening (run at the console)
sudo bash scripts/00-enable-remote-access.sh

# Layer 1 — base hardening (review the CONFIGURATION block at the top first)
nano scripts/debian-server-postinstall.sh
sudo bash scripts/debian-server-postinstall.sh

# Layer 3 — self-hosted app stack
cd autoboros
bash install.sh                          # base + Docker + Tailscale + tuning (13 phases)
# configure .env, start core, reboot, then:
bash scripts/setup-all-apps.sh tier1     # tier1 / tier2 / all
bash scripts/health-check.sh

# Layer 4 — install the srv daily-driver command
sudo bash scripts/install-srv.sh   # installs srv (+ `tower` alias) and tab completion
srv                                # dashboard + fuzzy menu
srv hosts                          # save tower + future VPSes → srv tower / srv vps1
```

## Architecture

### `scripts/debian-server-postinstall.sh` — canonical hardening script

Single ~340-line idempotent-where-practical script, `set -euo pipefail`, must run as root. Entirely controlled by a `CONFIGURATION` block at the top (no CLI flags) — edit the file before running:

```
NEW_HOSTNAME, ADMIN_USER, TIMEZONE, SSH_PORT,
ENABLE_COCKPIT, INSTALL_DOCKER, INSTALL_QOL_TOOLS, INSTALL_AICHAT,
LEGACY_HARDWARE, MINIMAL_MODE, FORCE_KEY_ONLY
```

Runs as 15 numbered phases (APT sources → full upgrade → essential packages → admin user → hostname → timezone/NTP → SSH hardening → UFW → unattended-upgrades → Fail2ban → legacy hardware tweaks → Docker (optional) → QoL tools (optional) → aichat (optional) → Cockpit (optional) → cleanup). Auto-detects Bookworm vs Trixie from `/etc/os-release` and warns (with a prompt to continue) on anything else.

**Lockout guard** (the key safety mechanism): SSH password auth is only disabled if the target admin user already has an `authorized_keys` file installed; otherwise password auth stays on with a warning. `FORCE_KEY_ONLY=true` overrides this and always goes key-only — real lockout risk if used carelessly. The script also removes the Stage 0 drop-in (`/etc/ssh/sshd_config.d/00-remote-access.conf`) since it fully replaces `/etc/ssh/sshd_config`.

### `scripts/00-enable-remote-access.sh` — Stage 0 bootstrap

Meant to run once, at the console, before hardening. Installs/enables sshd, sets the login user's password, enables password auth via a clean drop-in (not by editing the main sshd_config), opens the firewall only if UFW is already active, runs connectivity checks (sshd active, port listening, user exists, default route), and prints the exact `ssh user@<ip>` command. Idempotent — safe to re-run.

### `bin/srv` — the daily-driver command

Single ~430-line bash script (`set -uo pipefail`), config-driven and dependency-optional (falls back gracefully without `gum`/`fzf`). Structure to know if extending it:

- **`COMMANDS` array** (line ~46) — the single source of truth for every subcommand: `name|shortcut|synonyms|description`. Add a new subcommand here, then add a `cmd_<name>()` function, then wire it into the `case` in `run_cmd()`.
- **`resolve()`** — turns arbitrary user input into a canonical command name: exact name/shortcut → synonym/prefix match → saved-host name (`__host__`) → Levenshtein typo correction within distance 2 (`__suggest__:<name>`, only if unambiguous).
- **`find_repo()`** — locates the toolkit repo checkout by checking `~/.config/srv/config` cache, then `$SRV_REPO`, then a hardcoded list of likely clone paths (`~/Pc-tower-headless`, `~/pc-tower-headless`, etc.), then relative to the script's own location. Caches the result. Most `cmd_*` functions call `need_repo` and shell out to scripts under `$REPO/scripts/` or `$REPO/autoboros/`.
- **Config/state files**: `~/.config/srv/config` (`SRV_REPO=` cache), `~/.config/srv/hosts` (`name  user@address`, space-separated), `~/.config/srv/history` (usage log for the "3 most-used commands float to the top" menu behavior).
- **`pick()` / `confirm()` / `input()`** — the UI abstraction layer: prefers `gum`, falls back to `fzf`, falls back to plain `select`/`read`. Any new interactive prompt should go through these rather than calling `gum`/`read` directly.

`completions/srv.bash` provides bash/zsh tab completion for subcommands and saved host names; keep it in sync with the `COMMANDS` array if subcommands change.

### `autoboros/` — self-hosted app stack (independent subtree)

"AUTOBOROS ULTIMATUM v3.0" — Debian 13 Trixie headless tower stack, sized for ≤4GB RAM. Has its own `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, and CI — treat it as a semi-independent project nested in this repo (per the root CHANGELOG: "kept intact... Not changed").

- **`install.sh`** — 13-phase base installer (Pre-flight → Base System → Docker → adaptive ZRAM → EarlyOOM → UFW → Unattended Upgrades → Fail2ban → Tailscale → Directories → MOTD → `.bashrc` env → Beszel Agent → Summary). Tier-aware from Phase 0.
- **App tiers** (deploy via `scripts/setup-all-apps.sh <tier>`): Tier 0 core (Caddy, Beszel Hub, Uptime Kuma, Watchtower — always running, ~224MB) is started via `docker-compose.yml`; Tier 1 "Essential" (Homarr, Dockge, Vaultwarden, Memos, Pocket ID, ≤256MB each), Tier 2 "Power" (Plausible, NocoDB, Karakeep, Excalidraw, ≤512MB each), and Tier 3 "Workers only" (n8n, Trilium, Activepieces, Docmost, Changedetection, Stirling-PDF — meant for worker laptops, not the tower itself) are each a standalone compose file under `apps/*.yml`.
- **`Caddyfile`** — reverse-proxy routes for all apps; `Caddyfile.env` is the environment template (real `.env` is git-ignored).
- **`performance-upgrade.sh`** — aggressive kernel/perf tuning (adaptive ZRAM 50/75/100% by RAM tier, zswap, BBR, CPU governor, `noatime`, optional `mitigations=off` for ≤2GB, 3MB per-container log limits) — run after `install.sh` and a reboot.
- **`scripts/`** — `setup-beszel.sh` (hub+agent), `setup-all-apps.sh <tier>`, `health-check.sh`, `restore.sh`, `uninstall.sh`, `update-check.sh` (also flags EOL: full support ends 2028-08, LTS 2030-06, paid ELTS 2035-06).
- **`ansible/`** — deployment target for Tier 3 (heavy automation apps run on worker laptops, not the tower).
- **`backup.sh`** + **`.restic-exclude`** — weekly restic backup.
- **Contributing philosophy** (`autoboros/CONTRIBUTING.md`): lean over feature-rich (>128MB → goes on a worker, not the tower), headless-first (no GUI/mDNS/BT/printers), EOL-aware, prefer Alpine images, pin image versions (never `:latest`), keep `set -euo pipefail`, test on a 2GB RAM VM minimum, include `docker stats --no-stream` before/after in PRs, update `CHANGELOG.md`.

## Conventions

- All scripts use `set -euo pipefail` (or `set -uo pipefail` for `bin/srv`, which needs to tolerate some non-zero returns for its picker fallbacks) — preserve this when editing.
- Scripts that mutate system state (SSH config, firewall, packages) back up the file they're changing first (e.g. `sshd_config.bak.$(date +%F_%T)`) — follow this pattern for new mutations.
- `scripts/debian-server-postinstall.sh` is configured via variables at the top of the file, not CLI flags/env vars (aside from `FORCE_KEY_ONLY`, which can also be set as an env var override) — keep new options in that same block.
- Never commit secrets: `.gitignore` excludes `.env`, `*.key`, `*.pem`, `id_ed25519*`, `id_rsa*`, backups/archives, and OS/editor cruft.
- Docs are numbered (`docs/00`–`docs/09`) in the order a reader would want them; when adding a new guide, slot it into that numbering rather than appending arbitrarily.
- `autoboros/` pins image versions and prefers Alpine — don't introduce `:latest` tags there.
