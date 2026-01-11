#!/bin/bash
# Filestash Server Setup Script
# Kiliclar Photo Project
#
# Run this script on a fresh Ubuntu 22.04 server
# Usage: curl -sSL <raw-url> | bash
#    or: ./setup-filestash.sh

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
echo "[1/5] Updating system packages..."
apt update && apt upgrade -y

echo ""
echo "[2/5] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "Docker already installed, skipping..."
fi

echo ""
echo "[3/5] Creating directory structure..."
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

echo ""
echo "[4/5] Creating configuration files..."

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE_EOF'
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
echo "[5/5] Starting services..."
docker compose pull
docker compose up -d

echo ""
echo "=========================================="
echo "Filestash setup complete!"
echo "=========================================="
echo ""
echo "Service status:"
docker compose ps
echo ""
echo "Next steps:"
echo "1. Wait for DNS propagation (check: dig ${DOMAIN})"
echo "2. Access https://${DOMAIN}"
echo "3. Configure Filestash to connect to Backblaze B2"
echo ""
echo "Useful commands:"
echo "  View logs:     docker compose logs -f"
echo "  Restart:       docker compose restart"
echo "  Stop:          docker compose down"
echo "  Update:        docker compose pull && docker compose up -d"
echo ""
