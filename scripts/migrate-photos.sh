#!/bin/bash
# Photo Migration Script
# Kiliclar Photo Project
#
# This script migrates collected photos from the collection bucket
# to the Immich library bucket and triggers a library scan

set -e

# Configuration
RCLONE_REMOTE="kiliclar-b2"
COLLECTION_BUCKET="kiliclar-photos-collection"
LIBRARY_BUCKET="kiliclar-photos-library"
LOG_FILE="/var/log/photo-migration.log"
IMMICH_API_URL="http://localhost:2283/api"
IMMICH_API_KEY=""  # Set this before running

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "${LOG_FILE}"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check rclone
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed"
        exit 1
    fi

    # Check rclone config
    if ! rclone listremotes | grep -q "${RCLONE_REMOTE}"; then
        log_error "rclone remote '${RCLONE_REMOTE}' not configured"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

show_collection_stats() {
    log "Gathering collection statistics..."

    # Count files
    local file_count=$(rclone size "${RCLONE_REMOTE}:${COLLECTION_BUCKET}" --json 2>/dev/null | jq -r '.count // 0')
    local total_size=$(rclone size "${RCLONE_REMOTE}:${COLLECTION_BUCKET}" --json 2>/dev/null | jq -r '.bytes // 0')
    local human_size=$(numfmt --to=iec-i --suffix=B ${total_size} 2>/dev/null || echo "${total_size} bytes")

    echo ""
    echo "=========================================="
    echo "Collection Bucket Statistics"
    echo "=========================================="
    echo "Total files: ${file_count}"
    echo "Total size:  ${human_size}"
    echo ""

    # List folders (contributors)
    echo "Contributors:"
    rclone lsf "${RCLONE_REMOTE}:${COLLECTION_BUCKET}" --dirs-only | while read folder; do
        local folder_size=$(rclone size "${RCLONE_REMOTE}:${COLLECTION_BUCKET}/${folder}" --json 2>/dev/null | jq -r '.bytes // 0')
        local folder_count=$(rclone size "${RCLONE_REMOTE}:${COLLECTION_BUCKET}/${folder}" --json 2>/dev/null | jq -r '.count // 0')
        printf "  %-20s %10s files, %s\n" "${folder}" "${folder_count}" "$(numfmt --to=iec-i --suffix=B ${folder_size} 2>/dev/null)"
    done
    echo ""
}

migrate_photos() {
    log "Starting photo migration..."

    # Sync from collection to library bucket
    # Using --progress to show transfer progress
    rclone sync "${RCLONE_REMOTE}:${COLLECTION_BUCKET}" "${RCLONE_REMOTE}:${LIBRARY_BUCKET}/import" \
        --progress \
        --transfers 16 \
        --checkers 32 \
        --stats 30s \
        --stats-log-level NOTICE \
        --log-file "${LOG_FILE}" \
        --log-level INFO

    if [[ $? -eq 0 ]]; then
        log_success "Photo migration completed!"
    else
        log_error "Photo migration failed!"
        exit 1
    fi
}

trigger_library_scan() {
    if [[ -z "${IMMICH_API_KEY}" ]]; then
        log_warning "IMMICH_API_KEY not set, skipping library scan trigger"
        echo ""
        echo "To trigger a library scan manually:"
        echo "1. Open Immich web interface"
        echo "2. Go to Administration > Jobs"
        echo "3. Click 'Run' on 'Library Scan'"
        return
    fi

    log "Triggering Immich library scan..."

    curl -X POST "${IMMICH_API_URL}/library/scan" \
        -H "x-api-key: ${IMMICH_API_KEY}" \
        -H "Content-Type: application/json"

    if [[ $? -eq 0 ]]; then
        log_success "Library scan triggered!"
    else
        log_warning "Failed to trigger library scan via API"
    fi
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "Kiliclar Photo Migration Script"
    echo "=========================================="
    echo ""

    check_prerequisites
    show_collection_stats

    # Confirm before proceeding
    read -p "Do you want to proceed with the migration? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        migrate_photos
        trigger_library_scan

        echo ""
        log_success "Migration complete!"
        echo ""
        echo "Next steps:"
        echo "1. Check Immich web interface for imported photos"
        echo "2. Monitor ML processing in Administration > Jobs"
        echo "3. Face clustering will take several hours/days for large libraries"
    else
        log "Migration cancelled by user"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-key)
            IMMICH_API_KEY="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --stats-only)
            check_prerequisites
            show_collection_stats
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --api-key KEY    Immich API key for triggering library scan"
            echo "  --dry-run        Show what would be done without making changes"
            echo "  --stats-only     Only show collection statistics"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

main
