# Changelog

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
