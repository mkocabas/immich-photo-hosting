#!/bin/bash
# Database Backup Script for Immich
# Kiliclar Photo Project
#
# This script backs up the PostgreSQL database to Backblaze B2

set -e

# Configuration
BACKUP_DIR="/var/backups/immich"
RCLONE_REMOTE="kiliclar-b2"
BACKUP_BUCKET="kiliclar-photos-backups"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="immich_db_${TIMESTAMP}.sql.gz"
LOG_FILE="/var/log/immich-backup.log"

# Docker container names
POSTGRES_CONTAINER="immich_postgres"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

log "Starting Immich database backup..."

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Dump database from Docker container
log "Dumping PostgreSQL database..."
docker exec "${POSTGRES_CONTAINER}" pg_dump -U postgres -d immich | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

# Check if backup was successful
if [[ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]]; then
    log "ERROR: Backup file was not created!"
    exit 1
fi

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
log "Local backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to Backblaze B2
log "Uploading to Backblaze B2..."
rclone copy "${BACKUP_DIR}/${BACKUP_FILE}" "${RCLONE_REMOTE}:${BACKUP_BUCKET}/database/"

if [[ $? -eq 0 ]]; then
    log "Successfully uploaded to B2"
else
    log "ERROR: Failed to upload to B2!"
    exit 1
fi

# Clean up old local backups
log "Cleaning up local backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "immich_db_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# Clean up old remote backups
log "Cleaning up remote backups older than ${RETENTION_DAYS} days..."
rclone delete "${RCLONE_REMOTE}:${BACKUP_BUCKET}/database/" --min-age ${RETENTION_DAYS}d

log "Backup completed successfully!"

# Output status for systemd
echo "Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})"
