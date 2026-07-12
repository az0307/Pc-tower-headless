# Architecture

## Tier System

AUTOBOROS v3.0 organizes apps into tiers based on resource requirements:

### Tier 0 — Core Infrastructure (<=512MB total)
Always running. Gateway, monitoring, auto-updates.

| Service | RAM | Role |
|---------|-----|------|
| Caddy | 64MB | Reverse proxy |
| Beszel Hub | 48MB | System monitoring |
| Uptime Kuma | 80MB | Uptime monitoring |
| Watchtower | 32MB | Auto-updates |

### Tier 1 — Essential Apps (<=256MB each)
Lightweight utilities. Deploy based on need.

| Service | RAM | Role |
|---------|-----|------|
| Homarr | 192MB | Dashboard |
| Dockge | 192MB | Container manager |
| Vaultwarden | 192MB | Password vault |
| Memos | 64MB | Quick notes |
| Pocket ID | 128MB | Passkey auth |

### Tier 2 — Power Apps (<=512MB each)
Heavier but useful. Deploy if RAM allows.

| Service | RAM | Role |
|---------|-----|------|
| Plausible | 512MB | Analytics |
| NocoDB | 256MB | Database spreadsheet |
| Karakeep | 256MB | Bookmark archiver |
| Excalidraw | 64MB | Whiteboard |

### Tier 3 — Worker Only (>=512MB each)
Never on tower. Always on laptops/workers.

| Service | RAM | Role |
|---------|-----|------|
| n8n | 512MB | Workflow automation |
| Trilium | 512MB | Knowledge base |
| Activepieces | 512MB | Zapier alternative |
| Docmost | 512MB | Wiki |
| Changedetection | 256MB | Website monitoring |
| Stirling-PDF | 512MB | PDF tools |

## Network

```
User -> Tailscale -> Tower:443 -> Caddy -> Service
                                    |
                                    +-> beszel:8090
                                    +-> homarr:7575
                                    +-> vaultwarden:80
                                    +-> etc.
```

## Data Flow

```
App Data -> Docker Volume -> Restic -> ~/backups/restic
```

## EOL

- 2028-08-09: Full support ends
- 2030-06-30: LTS ends
- 2035-06-30: ELTS ends
