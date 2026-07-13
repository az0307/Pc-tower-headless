# Changelog

## The `srv` command — one short command for everything

A daily-driver CLI/TUI front door to the whole toolkit, designed to be easy to type
*and* easy to voice-dictate (Wispr Flow-friendly), covering the tower today and VPS
hosts later.

### Added

- `bin/srv` — the command. Dashboard widget (`srv status`), health checks, updates,
  TUI widget launcher (btop/duf/dust/lazydocker/lnav/yazi), autoboros app-stack
  actions, Tailscale, backups, logs, and saved-host SSH (`srv tower`, `srv vps1`).
  Best-practice interaction layer:
  - **fuzzy search** in every picker (gum filter → fzf → plain fallback)
  - **typo correction** — unambiguous close matches prompt "Did you mean…"
  - **memory** — 3 most-used actions float to the top of the menu (★)
  - **single-letter shortcuts** (`s` `h` `u` `m` `w` `c` `a` `t` `b` `l`)
  - **dictation-friendly** — case-insensitive, prefix/synonym matching, extra words ignored
- `completions/srv.bash` — shell tab completion (commands + saved host names).
- `scripts/install-srv.sh` — installs `srv`, a `tower` alias, and the completion;
  offers gum (Charm apt repo) for pretty menus.
- `docs/09-srv-command.md` — reference.

## Stage 0 remote-access bootstrap + lockout guard

Adds a gentle "go headless first" onboarding path so you can set up remote SSH at
the tower, verify it from your laptop, unplug the monitor, and finish the rest
remotely — without risking a lockout.

### Added

- `scripts/00-enable-remote-access.sh` — Stage 0 bootstrap: installs/enables the SSH
  server, sets the login user's password, turns on **password** auth via a clean
  drop-in, opens the firewall only if UFW is already active, runs connectivity checks
  (sshd active, port listening, user exists, default route), and prints the exact
  `ssh user@<ip>` command to use. Idempotent.
- `docs/00-remote-access-bootstrap.md` — the go-headless-first workflow end to end.

### Changed

- `scripts/debian-server-postinstall.sh` — added a **lockout guard**: password login
  is now disabled only when the login user has an installed SSH key (else it stays on
  with a warning), so running the hardener remotely can't lock you out. New
  `FORCE_KEY_ONLY` flag overrides the guard. The hardener also removes the Stage 0
  drop-in when it takes over, and its final message reflects whether password auth
  was kept.
- `README.md` — documented Stage 0 and the recommended order (Stage 0 → key →
  hardening).

## Consolidation — initial repo

This repository was assembled by consolidating four separate uploads into one
coherent, deduplicated toolkit for a headless Debian 12/13 server (with a focus on
Vista-era tower hardware and Tailscale remote access).

### Sources merged

| Source upload | Disposition |
|---------------|-------------|
| `debian12-postinstall.sh` (standalone hardening script) | **Superseded.** Its logic is a strict subset of the "Meta Server Bootstrap" post-install script. Dropped in favor of the canonical `scripts/debian-server-postinstall.sh`. |
| `debian12-headless-server-setup-guide.md` (standalone guide) | **Superseded.** Content is covered by `docs/01-installation-guide.md`, which additionally supports Debian 13 (Trixie) and legacy hardware. |
| `debian12-server-bootstrap.tar.gz` ("Debian 12 Meta Server Bootstrap") | **Adopted as the canonical base.** Its post-install script became `scripts/debian-server-postinstall.sh`; its six docs became `docs/01`–`docs/06`. |
| `autoboros.zip` (AUTOBOROS ULTIMATUM v3.0 self-hosting stack) | **Kept intact** as the `autoboros/` subdirectory (Layer 3 app stack). |

### Added

- `docs/07-tower-fresh-install.md` — repurposing an old Vista-era desktop tower as a
  headless Debian server (adapted and generalized from home-lab notes in
  `kali-backup-system`; de-Kali-fied to plain Debian).
- `docs/08-tailscale-remote-access.md` — standalone Tailscale setup for secure remote
  access without port-forwarding (adapted from the same source; expanded with
  UFW/interface-restriction guidance).
- `README.md` — unifying overview describing the three layers (base OS + hardening,
  physical tower + remote access, self-hosted apps).

### De-duplication notes

- The three overlapping hardening scripts/guides were reduced to **one** canonical
  script + guide set. The Bootstrap versions won because they are strict supersets
  (Bookworm **and** Trixie detection, optional Docker/QoL/`aichat`, and explicit
  legacy-hardware handling).
- `autoboros/install.sh` overlaps with `scripts/debian-server-postinstall.sh` (both do
  base hardening). They are intentionally kept separate as two entry points — general
  server vs. dedicated app host — and the README explains when to use which rather
  than merging them.

### Not changed

- The `autoboros/` subtree is preserved as-is from its upload, including its own
  `README.md`, `docs/`, `LICENSE`, and CI workflow.
