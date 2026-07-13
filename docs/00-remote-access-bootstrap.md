# Stage 0 — Go Headless First (Remote Access Bootstrap)

The goal of this stage: get SSH working from your laptop **before** you do any
hardening, so you can unplug the monitor and keyboard and finish the entire setup
remotely. It removes the biggest risk of headless setup — locking yourself out of a
box you can no longer see.

This is the recommended very first step after a fresh Debian install on the tower.

---

## The Flow

```
[at the tower, monitor attached]           [from your laptop]
        │
        ▼
  run Stage 0 script  ──────────────►  ssh user@tower  (password)
  (enables password SSH,                       │
   sets password, checks)                      │  works?
        │                                       ▼
        ▼                              UNPLUG THE MONITOR
  checks pass                                   │
                                                ▼
                                    ssh-copy-id user@tower   (install key)
                                                │
                                                ▼
                                    run debian-server-postinstall.sh
                                    (auto-detects the key → key-only + firewall
                                     + fail2ban + everything else)
```

Password SSH here is a **temporary bridge**, only long enough to install your key.
The hardening script then switches the box to key-only automatically.

---

## 1. At the Tower (monitor + keyboard attached)

After the fresh Debian install (see `07-tower-fresh-install.md`), log in at the
console and get the repo onto the machine, then run Stage 0:

```bash
# get the code (needs the network up — Ethernet recommended)
sudo apt update && sudo apt install -y git
git clone https://github.com/az0307/meta-automation-hub.git
cd meta-automation-hub/debian12-headless-server

# enable + verify remote SSH
sudo bash scripts/00-enable-remote-access.sh
```

The script will:

- install and enable the OpenSSH server,
- make sure your login user exists and let you **set its password**,
- turn on password authentication (temporary drop-in config),
- open the firewall for SSH **only if** UFW is already active,
- run checks (sshd active, port listening, user exists, network up),
- print the exact `ssh user@<ip>` command(s) to use from your laptop.

Config knobs at the top of the script (optional):

```bash
ADMIN_USER=""            # empty = auto-detect your normal login user
SET_PASSWORD=true        # prompt to set/confirm the SSH password
PERMIT_ROOT_LOGIN=false  # leave false; log in as your user and use sudo
SSH_PORT=22
```

## 2. From Your Laptop — Verify

Run the command the script printed, e.g.:

```bash
ssh youruser@192.168.1.75
```

Log in with the password you just set. **If this works, you're safe to unplug the
monitor and keyboard.** The tower is now fully headless.

> If it doesn't connect: check the Ethernet cable, confirm both machines are on the
> same network, and re-run the Stage 0 script on the tower to see the checks again.

## 3. Install Your Key (still from the laptop)

```bash
ssh-copy-id youruser@192.168.1.75
```

This copies your public key to the server so you can log in without a password. (No
key yet? Make one with `ssh-keygen -t ed25519` first.)

## 4. Harden — the Rest of the Setup, Remotely

Now SSH in and run the main hardening script:

```bash
ssh youruser@192.168.1.75
cd meta-automation-hub/debian12-headless-server
sudo bash scripts/debian-server-postinstall.sh
```

The hardening script has a **lockout guard**: it checks whether your key is
installed before disabling password login.

- **Key found** → it switches to key-only SSH, enables UFW + fail2ban, etc.
- **No key found** → it keeps password login on and warns you, so a remote run can
  never lock you out. Install the key, then re-run with `FORCE_KEY_ONLY=true`.

From here, continue with the optional layers:

- **Remote access from anywhere:** `08-tailscale-remote-access.md`
- **Self-hosted apps:** `../autoboros/README.md`

---

## Security Notes

- Password SSH is fine on a trusted LAN as a short bridge, but don't leave it exposed
  to the internet. Move to key-only (step 4) promptly, and use **Tailscale** rather
  than port-forwarding if you need access from outside the LAN.
- `fail2ban` (installed by the hardening script) mitigates brute-force attempts while
  password auth is briefly on.
- Never enable `PERMIT_ROOT_LOGIN` with a password on an internet-reachable host.
