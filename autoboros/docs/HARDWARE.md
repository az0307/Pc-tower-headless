# Hardware Guide

## Minimum

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | x86_64, 1GHz | Core 2 Duo / Athlon 64 X2 |
| RAM | 1GB | 2-4GB |
| Disk | 10GB free | 20GB+ SSD |
| Network | 100Mbps Ethernet | Gigabit Ethernet |

## Tested Hardware

| Machine | CPU | RAM | Status |
|---------|-----|-----|--------|
| Dell OptiPlex 745 | Core 2 Duo E6400 | 2GB DDR2 | Tier 0-1 only |
| Dell OptiPlex 755 | Core 2 Duo E6550 | 4GB DDR2 | All tiers |
| HP dc7800 | Core 2 Duo E6550 | 4GB DDR2 | All tiers |
| Lenovo M57 | Core 2 Duo E4500 | 2GB DDR2 | Tier 0-1 only |
| Lenovo M720q | i5-8400T | 8GB DDR4 | All tiers + workers |

## Upgrades

- **RAM**: DDR2 ~$5-10 for 2GB kit
- **SSD**: 120GB SATA ~$15-20 (biggest impact)
- **CPU**: Core 2 Quad Q6600 ~$5-10 (if socket supports)
- **NIC**: Intel PRO/1000 PCIe ~$5 (better than Realtek)

## Power

- Remove dedicated GPU (headless)
- Disable unused SATA in BIOS
- Set CPU C-states to max
- Use performance-upgrade.sh governor tuning
- Consider 80+ PSU for 24/7

## What NOT to Run

- Plex/Jellyfin (transcoding)
- Home Assistant (use Pi)
- Minecraft server
- Elasticsearch
- AI/ML inference
