# Contributing to AUTOBOROS

## Philosophy

Target: Vista-era headless towers with <=4GB RAM.

- **Lean over feature-rich**: >128MB? Goes on worker
- **Batteries included, swappable**: Works out of box, easy to swap
- **Headless first**: No GUI, no mDNS, no BT, no printers
- **EOL-aware**: Every decision considers 2028->2030->2035

## PR Guidelines

1. Test on 2GB RAM VM minimum
2. Include `docker stats --no-stream` before/after
3. Update CHANGELOG.md
4. Keep `set -euo pipefail`
5. Prefer Alpine images
6. Pin image versions, not `:latest`

## Testing

```bash
qemu-system-x86_64 -m 2048 -cdrom debian-13-netinst.iso ...
```
