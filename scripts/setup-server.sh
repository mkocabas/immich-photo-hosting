#!/bin/bash
# Server Setup Script for Kiliclar Photo Project
# Run this on a fresh Ubuntu 22.04 server

set -e

echo "=========================================="
echo "Kiliclar Photo Project - Server Setup"
echo "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Configuration
TIMEZONE="Europe/Istanbul"
SSH_PORT=22

echo ""
echo "[1/8] Updating system packages..."
apt update && apt upgrade -y

echo ""
echo "[2/8] Setting timezone to ${TIMEZONE}..."
timedatectl set-timezone ${TIMEZONE}

echo ""
echo "[3/8] Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    ufw \
    fail2ban \
    rclone \
    fuse3

echo ""
echo "[4/8] Installing Docker..."
# Remove old versions
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install prerequisites
apt install -y ca-certificates gnupg

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

echo ""
echo "[5/8] Configuring firewall (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ${SSH_PORT}/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo ""
echo "[6/8] Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo ""
echo "[7/8] Setting up automatic security updates..."
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

echo ""
echo "[8/8] Creating directory structure..."
mkdir -p /mnt/photos
mkdir -p /opt/immich
mkdir -p /opt/filestash
mkdir -p /var/backups/immich

echo ""
echo "=========================================="
echo "Server setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Configure rclone: rclone config"
echo "2. Set up rclone mount service"
echo "3. Copy docker-compose files to /opt/immich"
echo "4. Configure .env file"
echo "5. Start services with: docker compose up -d"
echo ""
echo "Security reminders:"
echo "- Disable password authentication in /etc/ssh/sshd_config"
echo "- Add your SSH public key to ~/.ssh/authorized_keys"
echo ""
