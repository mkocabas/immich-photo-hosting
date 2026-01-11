# Deployment Guide

This guide documents the complete deployment process for the Kiliclar Photo Project.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Backblaze B2 Setup](#phase-1-backblaze-b2-setup)
3. [Phase 2: Domain Registration](#phase-2-domain-registration)
4. [Phase 3: Filestash Deployment](#phase-3-filestash-deployment)
5. [Phase 4: Immich Deployment](#phase-4-immich-deployment)
6. [Phase 5: Photo Migration](#phase-5-photo-migration)
7. [Maintenance](#maintenance)

---

## Prerequisites

- Backblaze B2 account
- Hetzner account
- Domain name
- SSH key pair (generate with `ssh-keygen -t ed25519`)
- Local machine with `rclone` installed

---

## Phase 1: Backblaze B2 Setup

### 1.1 Create Account

1. Go to https://www.backblaze.com/b2/
2. Sign up for a new account
3. Verify your email

### 1.2 Create Buckets

Create 3 buckets in the B2 dashboard:

| Bucket Name | Purpose |
|-------------|---------|
| `kiliclar-photos-collection` | Friend uploads during collection phase |
| `kiliclar-photos-library` | Immich photo storage |
| `kiliclar-photos-backups` | Database backups |

Settings for each bucket:
- **Files in Bucket:** Private
- **Default Encryption:** Enabled
- **Object Lock:** Disabled

### 1.3 Create Application Key

1. Go to **App Keys** in B2 dashboard
2. Click **Add a New Application Key**
3. Settings:
   - **Name:** `kiliclar-admin`
   - **Allow access to Bucket(s):** All
   - **Type of Access:** Read and Write
4. Click **Create New Key**
5. **IMPORTANT:** Save both `keyID` and `applicationKey` immediately (shown only once)

### 1.4 Configure rclone

Create rclone config file at `~/.config/rclone/rclone.conf`:

```ini
[kiliclar-b2]
type = b2
account = YOUR_KEY_ID
key = YOUR_APPLICATION_KEY
```

Test connection:

```bash
rclone lsd kiliclar-b2:
```

Expected output: list of your buckets.

---

## Phase 2: Domain Registration

### 2.1 Register Domain

Recommended registrars:
- **Porkbun** (https://porkbun.com) - Cheapest, free WHOIS privacy
- **Cloudflare** (https://www.cloudflare.com/products/registrar/) - At-cost pricing

Register: `kiliclar.photos` (or your chosen domain)

### 2.2 DNS Records

Add these A records (IPs will be available after server provisioning):

| Type | Host | Answer | TTL |
|------|------|--------|-----|
| A | upload | `<filestash-server-ip>` | 300 |
| A | photos | `<immich-server-ip>` | 300 |

---

## Phase 3: Filestash Deployment

Filestash provides the web upload interface for collecting photos from friends.

### 3.1 Provision Server

1. Go to https://console.hetzner.cloud/
2. Create new project: `kiliclar-photos`
3. Add Server:
   - **Location:** Choose nearest (e.g., us-east, eu-central)
   - **Image:** Ubuntu 22.04
   - **Type:** CX22 (2 vCPU, 4GB RAM, 40GB SSD)
   - **Networking:** Public IPv4 enabled
   - **SSH Keys:** Add your public key
   - **Name:** `filestash`
4. Note the public IP address

### 3.2 Configure DNS

Add A record for `upload.kiliclar.photos` pointing to the server IP.

Verify propagation:

```bash
dig upload.kiliclar.photos +short
```

### 3.3 Deploy Filestash

**Option A: Using setup script (recommended)**

```bash
# SSH into server
ssh root@<server-ip>

# Download and run setup script
curl -sSL https://raw.githubusercontent.com/<your-repo>/main/scripts/setup-filestash.sh | bash
```

**Option B: Manual deployment**

```bash
# SSH into server
ssh root@<server-ip>

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Create directory
mkdir -p /opt/filestash && cd /opt/filestash

# Copy files from this repo
# - docker/filestash/docker-compose.yml
# - docker/filestash/Caddyfile

# Or create them inline:
cat > docker-compose.yml << 'EOF'
version: "3.8"

services:
  filestash:
    image: machines/filestash:latest
    container_name: filestash
    restart: unless-stopped
    ports:
      - "8334:8334"
    environment:
      - APPLICATION_URL=https://upload.kiliclar.photos
    volumes:
      - filestash-data:/app/data/state
    networks:
      - filestash-network

  caddy:
    image: caddy:2-alpine
    container_name: filestash-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - filestash-network
    depends_on:
      - filestash

networks:
  filestash-network:

volumes:
  filestash-data:
  caddy-data:
  caddy-config:
EOF

cat > Caddyfile << 'EOF'
upload.kiliclar.photos {
    reverse_proxy filestash:8334
    request_body {
        max_size 10GB
    }
}
EOF

# Start services
docker compose up -d
```

### 3.4 Configure Filestash Backend

1. Open https://upload.kiliclar.photos
2. Complete initial setup
3. Go to **Admin** → **Backend**
4. Select **S3** (Backblaze B2 is S3-compatible)
5. Configure:
   - **Endpoint:** `s3.us-west-004.backblazeb2.com` (check your bucket for region)
   - **Access Key ID:** Your B2 keyID
   - **Secret Access Key:** Your B2 applicationKey
   - **Bucket:** `kiliclar-photos-collection`
   - **Region:** `us-west-004` (match your bucket region)
6. Save and test connection

### 3.5 Create Upload Folders

Create a folder for each contributor:

```bash
rclone mkdir kiliclar-b2:kiliclar-photos-collection/ali
rclone mkdir kiliclar-b2:kiliclar-photos-collection/mehmet
rclone mkdir kiliclar-b2:kiliclar-photos-collection/ayse
# ... repeat for all ~100 people
```

Or create a script:

```bash
#!/bin/bash
NAMES=(ali mehmet ayse fatma ...)
for name in "${NAMES[@]}"; do
    rclone mkdir kiliclar-b2:kiliclar-photos-collection/$name
    echo "Created folder for $name"
done
```

---

## Phase 4: Immich Deployment

Immich provides the photo viewing platform with face recognition and search.

### 4.1 Provision Dedicated Server

1. Go to https://www.hetzner.com/dedicated-rootserver
2. Select **AX42**:
   - AMD Ryzen 5 3600 (6 cores, 12 threads)
   - 64GB DDR4 RAM
   - 2x 512GB NVMe SSD
3. Configure:
   - **Location:** Falkenstein or Helsinki
   - **Operating System:** Ubuntu 22.04
   - **SSH Key:** Add your public key
4. Order and wait for provisioning (can take hours)

### 4.2 Initial Server Setup

```bash
# SSH into server
ssh root@<immich-server-ip>

# Run base setup script
curl -sSL https://raw.githubusercontent.com/<your-repo>/main/scripts/setup-server.sh | bash
```

Or manually:

```bash
# Update system
apt update && apt upgrade -y

# Set timezone
timedatectl set-timezone Europe/Istanbul

# Install essentials
apt install -y curl wget git htop ufw fail2ban rclone fuse3

# Install Docker
curl -fsSL https://get.docker.com | sh

# Configure firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create directories
mkdir -p /mnt/photos /opt/immich /var/backups/immich
```

### 4.3 Configure rclone

```bash
# Create rclone config
mkdir -p ~/.config/rclone
cat > ~/.config/rclone/rclone.conf << 'EOF'
[kiliclar-b2]
type = b2
account = YOUR_KEY_ID
key = YOUR_APPLICATION_KEY
EOF

# Test connection
rclone lsd kiliclar-b2:
```

### 4.4 Setup rclone Mount

```bash
# Create systemd service
cat > /etc/systemd/system/rclone-mount.service << 'EOF'
[Unit]
Description=rclone mount for Backblaze B2
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount kiliclar-b2:kiliclar-photos-library /mnt/photos \
    --config /root/.config/rclone/rclone.conf \
    --vfs-cache-mode full \
    --vfs-cache-max-size 100G \
    --vfs-cache-max-age 168h \
    --cache-dir /var/cache/rclone \
    --allow-other \
    --uid 1000 \
    --gid 1000 \
    --log-level INFO \
    --log-file /var/log/rclone-mount.log

ExecStop=/bin/fusermount -uz /mnt/photos
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
systemctl daemon-reload
systemctl enable rclone-mount
systemctl start rclone-mount

# Verify
df -h /mnt/photos
```

### 4.5 Deploy Immich

```bash
cd /opt/immich

# Copy docker-compose.yml from repo or create it
# See: docker/immich/docker-compose.yml

# Create .env file
cat > .env << 'EOF'
IMMICH_VERSION=release
UPLOAD_LOCATION=/mnt/photos

DB_HOSTNAME=database
DB_USERNAME=postgres
DB_PASSWORD=CHANGE_ME_SECURE_PASSWORD
DB_DATABASE_NAME=immich

REDIS_HOSTNAME=redis

IMMICH_MACHINE_LEARNING_ENABLED=true

# Generate with: openssl rand -base64 32
JWT_SECRET=CHANGE_ME_RANDOM_SECRET

TZ=Europe/Istanbul
EOF

# Create Caddyfile
cat > Caddyfile << 'EOF'
photos.kiliclar.photos {
    reverse_proxy immich-server:2283
    encode gzip zstd
    request_body {
        max_size 50GB
    }
}
EOF

# Start services
docker compose up -d
```

### 4.6 Configure DNS

Add A record for `photos.kiliclar.photos` pointing to the Immich server IP.

### 4.7 Initial Immich Setup

1. Open https://photos.kiliclar.photos
2. Create admin account
3. Go to **Administration** → **Settings**
4. Configure as needed

---

## Phase 5: Photo Migration

After collection is complete, migrate photos to Immich.

### 5.1 Check Collection Status

```bash
# See total size and file count
rclone size kiliclar-b2:kiliclar-photos-collection

# List contributors
rclone lsf kiliclar-b2:kiliclar-photos-collection --dirs-only
```

### 5.2 Run Migration

```bash
# SSH to Immich server
ssh root@<immich-server-ip>

# Sync photos from collection to library
rclone sync kiliclar-b2:kiliclar-photos-collection kiliclar-b2:kiliclar-photos-library/import \
    --progress \
    --transfers 16 \
    --checkers 32
```

### 5.3 Trigger Library Scan

1. Open Immich admin panel
2. Go to **Administration** → **Jobs**
3. Click **Run** on "Library Scan"

Or via API:

```bash
curl -X POST "https://photos.kiliclar.photos/api/library/scan" \
    -H "x-api-key: YOUR_API_KEY"
```

### 5.4 Monitor Processing

ML processing will take several days for large libraries:
- Thumbnail generation: 2-3 days
- Face detection: 3-5 days
- CLIP indexing: 2-3 days

Monitor progress in **Administration** → **Jobs**.

---

## Maintenance

### Backup Database

Backups run daily at 3:00 AM via systemd timer.

Manual backup:

```bash
/opt/immich/scripts/backup-db.sh
```

### Update Immich

```bash
cd /opt/immich
docker compose pull
docker compose up -d
```

### Update Filestash

```bash
cd /opt/filestash
docker compose pull
docker compose up -d
```

### View Logs

```bash
# Immich
docker compose -f /opt/immich/docker-compose.yml logs -f

# Filestash
docker compose -f /opt/filestash/docker-compose.yml logs -f

# rclone mount
tail -f /var/log/rclone-mount.log
```

### Check B2 Mount

```bash
df -h /mnt/photos
systemctl status rclone-mount
```

---

## Troubleshooting

### SSL Certificate Issues

Caddy automatically handles SSL. If issues occur:

```bash
docker compose restart caddy
docker compose logs caddy
```

### B2 Mount Disconnected

```bash
systemctl restart rclone-mount
journalctl -u rclone-mount -f
```

### Immich Not Responding

```bash
cd /opt/immich
docker compose ps
docker compose restart
docker compose logs -f
```

### DNS Not Propagating

Check propagation status:

```bash
dig upload.kiliclar.photos +short
dig photos.kiliclar.photos +short
```

Use https://dnschecker.org for global propagation check.
