#!/bin/bash
# Filestash Server Setup Script
# Kiliclar Photo Project
#
# Run this script on a fresh Ubuntu 22.04 server
# Usage: curl -sSL <raw-url> | bash
#    or: ./setup-filestash.sh
#
# Safe to re-run - will clean up and reinstall

set -e

echo "=========================================="
echo "Kiliclar Photo Project - Filestash Setup"
echo "=========================================="

# Configuration
INSTALL_DIR="/opt/filestash"
DOMAIN="upload.kiliclar.photos"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

echo ""
echo "[1/6] Updating system packages..."
apt update && apt upgrade -y

echo ""
echo "[2/6] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "Docker already installed, skipping..."
fi

echo ""
echo "[3/6] Cleaning up previous installation (if any)..."
if [[ -d "${INSTALL_DIR}" ]] && [[ -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    cd ${INSTALL_DIR}
    docker compose down -v 2>/dev/null || true
    rm -rf ${INSTALL_DIR}/*
    echo "Previous installation cleaned up"
else
    echo "No previous installation found"
fi

echo ""
echo "[4/6] Creating directory structure..."
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

echo ""
echo "[5/6] Downloading official Filestash docker-compose and configuring..."

# Download official docker-compose.yml
curl -O https://downloads.filestash.app/latest/docker-compose.yml

# Create Caddyfile for reverse proxy
cat > Caddyfile << 'CADDY_EOF'
upload.kiliclar.photos {
    reverse_proxy localhost:8334

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }

    # Allow large uploads (10GB max)
    request_body {
        max_size 10GB
    }
}
CADDY_EOF

# Install Caddy for HTTPS
echo "Installing Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy

# Copy Caddyfile to Caddy config location
cp Caddyfile /etc/caddy/Caddyfile

echo ""
echo "[6/6] Starting services..."
docker compose pull
docker compose up -d

# Restart Caddy with new config
systemctl restart caddy

# Wait for services to start
sleep 3

echo ""
echo "=========================================="
echo "Filestash setup complete!"
echo "=========================================="
echo ""
echo "Service status:"
docker compose ps
echo ""
echo "Caddy status:"
systemctl status caddy --no-pager | head -5
echo ""
echo "Access your upload portal at:"
echo "  https://${DOMAIN}"
echo ""
echo "Admin panel:"
echo "  https://${DOMAIN}/admin"
echo "  Password: ${ADMIN_PASSWORD}"
echo ""
echo "First-time admin setup:"
echo "  1. Open https://${DOMAIN}/admin"
echo "  2. Enter admin password: ${ADMIN_PASSWORD}"
echo "  3. Configure backend (S3) with B2 credentials"
echo "  4. Configure authentication (htpasswd)"
echo ""
echo "Useful commands:"
echo "  View logs:        cd ${INSTALL_DIR} && docker compose logs -f"
echo "  Restart docker:   cd ${INSTALL_DIR} && docker compose restart"
echo "  Restart caddy:    systemctl restart caddy"
echo "  Stop:             cd ${INSTALL_DIR} && docker compose down"
echo "  Update:           cd ${INSTALL_DIR} && docker compose pull && docker compose up -d"
echo ""
