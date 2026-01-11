#!/bin/bash
# rclone mount script for Backblaze B2
# Kiliclar Photo Project

set -e

# Configuration
RCLONE_REMOTE="kiliclar-b2"
BUCKET_NAME="kiliclar-photos-library"
MOUNT_POINT="/mnt/photos"
CACHE_DIR="/var/cache/rclone"
LOG_FILE="/var/log/rclone-mount.log"

# Cache settings
VFS_CACHE_MODE="full"
VFS_CACHE_MAX_SIZE="100G"
VFS_CACHE_MAX_AGE="168h"  # 7 days
VFS_READ_AHEAD="128M"

# Create directories if they don't exist
mkdir -p "${MOUNT_POINT}"
mkdir -p "${CACHE_DIR}"

echo "$(date): Starting rclone mount..." >> "${LOG_FILE}"

# Mount with optimal settings for Immich
rclone mount "${RCLONE_REMOTE}:${BUCKET_NAME}" "${MOUNT_POINT}" \
    --vfs-cache-mode "${VFS_CACHE_MODE}" \
    --vfs-cache-max-size "${VFS_CACHE_MAX_SIZE}" \
    --vfs-cache-max-age "${VFS_CACHE_MAX_AGE}" \
    --vfs-read-ahead "${VFS_READ_AHEAD}" \
    --cache-dir "${CACHE_DIR}" \
    --dir-cache-time 5m \
    --poll-interval 1m \
    --buffer-size 256M \
    --transfers 8 \
    --checkers 8 \
    --allow-other \
    --uid 1000 \
    --gid 1000 \
    --umask 002 \
    --log-file "${LOG_FILE}" \
    --log-level INFO

echo "$(date): rclone mount stopped" >> "${LOG_FILE}"
