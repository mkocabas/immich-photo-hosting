# Kiliclar Photo Project

Shared photo repository for ~100 friends with face recognition and natural language search.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Users (~100 people)                       │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
                    ▼                           ▼
    ┌───────────────────────────┐   ┌───────────────────────────┐
    │   upload.kiliclar.photos │   │  photos.kiliclar.photos │
    │        (Filestash)         │   │         (Immich)           │
    │     Hetzner CX22 VPS      │   │    Hetzner AX42 Dedicated  │
    └───────────────────────────┘   └───────────────────────────┘
                    │                           │
                    ▼                           ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    Backblaze B2 Storage                      │
    │              (kiliclar-photos-collection)                    │
    │              (kiliclar-photos-library)                       │
    │              (kiliclar-photos-backups)                       │
    └─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
kiliclar_photo_project/
├── docker/
│   ├── immich/
│   │   ├── docker-compose.yml   # Immich deployment
│   │   ├── .env.template        # Environment template
│   │   └── Caddyfile            # Reverse proxy config
│   └── filestash/
│       ├── docker-compose.yml   # Filestash deployment
│       └── Caddyfile            # Upload portal proxy
├── scripts/
│   ├── setup-server.sh          # Initial server setup
│   ├── mount-b2.sh              # B2 mount script
│   ├── backup-db.sh             # Database backup
│   └── migrate-photos.sh        # Photo migration
├── systemd/
│   ├── rclone-mount.service     # Persistent B2 mount
│   ├── immich-backup.service    # Backup service
│   └── immich-backup.timer      # Daily backup timer
├── docs/
│   ├── yukleme-web.md           # Web upload guide (TR)
│   ├── yukleme-rclone.md        # rclone guide (TR)
│   └── kullanim-kilavuzu.md     # User guide (TR)
└── README.md
```

## Prerequisites

- Backblaze B2 account
- Hetzner account
- Domain name (e.g., kiliclar.photos)

## Deployment

### Phase 1: Collection Setup

1. Create Backblaze B2 bucket:
   ```bash
   # Create bucket: kiliclar-photos-collection
   # Enable S3-compatible API
   # Generate application key
   ```

2. Deploy Filestash on Hetzner CX22:
   ```bash
   ssh root@<filestash-vps-ip>
   git clone <this-repo> /opt/kiliclar
   cd /opt/kiliclar/docker/filestash
   docker compose up -d
   ```

3. Configure DNS:
   ```
   A upload.kiliclar.photos -> <filestash-vps-ip>
   ```

### Phase 2: Immich Deployment

1. Provision Hetzner AX42 dedicated server

2. Run server setup:
   ```bash
   ssh root@<immich-server-ip>
   git clone <this-repo> /opt/kiliclar
   chmod +x /opt/kiliclar/scripts/*.sh
   /opt/kiliclar/scripts/setup-server.sh
   ```

3. Configure rclone:
   ```bash
   rclone config
   # Create remote: kiliclar-b2
   # Type: b2
   # Account: <your-account-id>
   # Key: <your-application-key>
   ```

4. Install systemd services:
   ```bash
   cp /opt/kiliclar/systemd/*.service /etc/systemd/system/
   cp /opt/kiliclar/systemd/*.timer /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable --now rclone-mount.service
   systemctl enable --now immich-backup.timer
   ```

5. Deploy Immich:
   ```bash
   cd /opt/kiliclar/docker/immich
   cp .env.template .env
   # Edit .env with secure passwords
   docker compose up -d
   ```

6. Configure DNS:
   ```
   A photos.kiliclar.photos -> <immich-server-ip>
   ```

### Phase 3: Migration

Run the migration script after collection is complete:
```bash
/opt/kiliclar/scripts/migrate-photos.sh --stats-only  # Preview
/opt/kiliclar/scripts/migrate-photos.sh               # Execute
```

## Monthly Costs

| Component | Cost |
|-----------|------|
| Hetzner AX42 (Immich) | $58 |
| Hetzner CX22 (Filestash) | $5 |
| Backblaze B2 (20TB) | $120 |
| Domain | ~$2 |
| **Total** | **~$185/month** |

## Maintenance

### Backups

Database backups run automatically at 3:00 AM daily. Check status:
```bash
systemctl status immich-backup.timer
journalctl -u immich-backup.service
```

### Monitoring

```bash
# Check Immich status
docker compose -f /opt/kiliclar/docker/immich/docker-compose.yml ps

# Check B2 mount
df -h /mnt/photos

# Check rclone mount logs
tail -f /var/log/rclone-mount.log
```

### Updates

```bash
cd /opt/kiliclar/docker/immich
docker compose pull
docker compose up -d
```

## Troubleshooting

### B2 mount disconnected
```bash
systemctl restart rclone-mount.service
```

### Immich not responding
```bash
cd /opt/kiliclar/docker/immich
docker compose restart
```

### Check ML processing status
Open Immich web UI → Administration → Jobs

## Documentation

- [Web Upload Guide (Turkish)](docs/yukleme-web.md)
- [rclone Upload Guide (Turkish)](docs/yukleme-rclone.md)
- [Platform User Guide (Turkish)](docs/kullanim-kilavuzu.md)

## License

Private project for Kiliclar friend group.
