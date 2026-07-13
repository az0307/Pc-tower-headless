# `srv` — One Short Command for Your Servers

`srv` is the front door to this toolkit: a single, easy-to-type (and easy-to-dictate)
command that wraps everything — status dashboard, health checks, updates, the app
stack, Tailscale, backups, logs, and SSH-ing between your machines (the tower today,
your VPSes tomorrow).

Built on open-source pieces: [gum](https://github.com/charmbracelet/gum) for menus and
fuzzy filtering (falls back to `fzf`, then plain menus), and btop/duf/dust/lazydocker/
lnav as the widget layer.

---

## Install

```bash
cd debian12-headless-server
sudo bash scripts/install-srv.sh
```

That installs `/usr/local/bin/srv`, a `tower` alias, and bash tab completion.
Run it on the server; running it on your laptop too is useful for `srv connect`.

---

## Use

```bash
srv              # dashboard + interactive menu (type to fuzzy-filter, Enter to run)
srv s            # status  (single-letter shortcuts)
srv health       # health checks
srv update       # apt + app updates
srv w            # pick a TUI widget (btop, duf, dust, lazydocker, lnav, yazi)
srv tower        # ssh straight to a saved host by name
srv connect      # or pick a host from the fuzzy list
```

### QoL behaviors (why it feels smart)

| Behavior | What it does |
|---|---|
| **Fuzzy search** | Every picker is type-to-filter (gum filter / fzf). `srv` → type `bak` → Backup. |
| **Predictive text** | Tab completion at the shell: `srv <TAB>` suggests commands *and* your saved hosts; `srv connect <TAB>` completes host names. |
| **Typo correction** | `srv statsu` → "Did you mean: srv **status**?" (edit-distance match, only when unambiguous). |
| **Memory** | Your 3 most-used actions float to the top of the menu, marked ★. Stored in `~/.config/srv/history`. |
| **Shortcuts** | `s` status · `h` health · `u` update · `m` monitor · `w` widgets · `c` connect · `a` apps · `t` tailscale · `b` backup · `l` logs |
| **Dictation-friendly** | Case-insensitive, prefix + synonym matching, extra words ignored — "srv health check please" works. `tower` alias is a real word voice tools won't mangle. |
| **Buttons / TUI** | Menus are arrow-key + Enter (mouse-free "buttons"); the widget layer gives you full TUIs. |

### Hosts (tower now, VPS later)

```bash
srv hosts        # → add
#   name: tower      target: aaron@192.168.1.75
#   name: vps1       target: root@203.0.113.10     (or a Tailscale 100.x address)

srv tower        # then this just works
srv vps1         # and so will this
```

Hosts live in `~/.config/srv/hosts` (one `name user@address` per line).

### Configuration

| File | Purpose |
|---|---|
| `~/.config/srv/config` | cached repo path (`SRV_REPO=...`) |
| `~/.config/srv/hosts` | saved SSH hosts |
| `~/.config/srv/history` | usage memory for the ★ recent section |

The repo path is auto-detected (`~/meta-automation-hub/debian12-headless-server` and
friends); override with `export SRV_REPO=/path/to/debian12-headless-server`.

### zsh completion

```zsh
# ~/.zshrc
autoload -U +X bashcompinit && bashcompinit
source /path/to/debian12-headless-server/completions/srv.bash
```

---

## What each command maps to

| Command | Under the hood |
|---|---|
| `status` | live dashboard: OS, uptime/load, RAM+swap, disk, LAN + Tailscale IPs, Docker count, SSH/UFW/fail2ban state |
| `health` | `autoboros/scripts/health-check.sh` when present, else built-in checks |
| `update` | `apt full-upgrade` + optional app-stack update check + `needrestart` |
| `stage0` | `scripts/00-enable-remote-access.sh` (go-headless bootstrap) |
| `harden` | `scripts/debian-server-postinstall.sh` (with confirm) |
| `apps` | autoboros install / tier deploy / health / core-up |
| `backup` | `autoboros/backup.sh` (restic) |
| `tailscale` | install if missing, `tailscale up` / `tailscale status` |
| `logs` | `journalctl -f` or lnav |
| `tools` | installs the QoL toolkit (btop, duf, fzf, ripgrep, bat, fd, zoxide, tldr, lnav, gum) |
