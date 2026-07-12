# Troubleshooting

## Installation

### "FATAL: Debian 13 requires x86_64"
Your CPU is 32-bit. Use Debian 12 Bookworm or antiX.

### OOM during install
```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
```

## Containers

### Caddy won't start
```bash
docker logs caddy
# Check .env exists and TAILSCALE_DOMAIN is set
```

### Vaultwarden 502
Wait 60s on old CPUs. Check `docker logs vaultwarden`.

### Docker "no space left"
```bash
docker system prune -af --volumes
df -h /
```

## Performance

### Still OOM after upgrade
```bash
free -h
zramctl
cat /proc/sys/vm/swappiness
# Reduce app mem_limits in compose files, or disable Vaultwarden
```

### GRUB recovery
Hold Shift -> Advanced -> Recovery -> `mount -o remount,rw /` -> edit `/etc/default/grub` -> `update-grub`

## Tailscale

### "Tailscale: OFF"
```bash
sudo tailscale up --ssh --accept-dns=false
tailscale status
tailscale ip -4
```

## Backup

### "FATAL: Password file missing"
```bash
openssl rand -base64 32 > ~/backups/.restic-pass
```
