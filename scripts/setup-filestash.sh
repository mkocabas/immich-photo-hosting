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
echo "[5/6] Creating configuration files..."

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  filestash:
    image: machines/filestash:latest
    container_name: filestash
    restart: unless-stopped
    ports:
      - "8334:8334"
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
    driver: bridge

volumes:
  filestash-data:
  caddy-data:
  caddy-config:
COMPOSE_EOF

# Create Caddyfile
cat > Caddyfile << 'CADDY_EOF'
upload.kiliclar.photos {
    reverse_proxy filestash:8334

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

echo ""
echo "[6/6] Starting services..."
docker compose pull
docker compose up -d

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
echo "Access your upload portal at:"
echo "  https://${DOMAIN}"
echo ""
echo "First-time setup:"
echo "  1. Open https://${DOMAIN}"
echo "  2. Select 'htpasswd' for authentication"
echo "  3. Set username/password for your group"
echo "  4. Select 'S3' as backend"
echo "  5. Configure B2 credentials (see docs/deployment-guide.md)"
echo ""
echo "Useful commands:"
echo "  View logs:     cd ${INSTALL_DIR} && docker compose logs -f"
echo "  Restart:       cd ${INSTALL_DIR} && docker compose restart"
echo "  Stop:          cd ${INSTALL_DIR} && docker compose down"
echo "  Update:        cd ${INSTALL_DIR} && docker compose pull && docker compose up -d"
echo "  Re-run setup:  Re-run this script (safe to re-run)"
echo ""
