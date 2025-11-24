#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
# -----------------------------------------------------------------------------
# Script to update and backup services like Jellyfin, Paperless and PhotoPrism
# -----------------------------------------------------------------------------

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
DATE=$(date +%Y-%m-%d)
ORIGINAL_DIR=$(pwd)

# Load environment variables from .env
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Function to print a separator line with date
print_separator() {
    local message="${1:-}"
    echo "============================================================" >> "$LOG_FILE"
    echo "==== ${DATE} - ${message} ===="                                                               >> "$LOG_FILE"
    echo "============================================================" >> "$LOG_FILE"
}

# Function to log messages with a timestamp
log() {
    echo "[${TIMESTAMP}] $1" | tee -a "$LOG_FILE"
}

# Function to log errors and exit the script
error() {
    log "ERROR: $1"
    print_separator "SCRIPT FAILED"
    echo "" >> "$LOG_FILE"
    exit 1
}

# Script start
print_separator "STARTING SERVICES UPDATE"
log "Starting Services Update Script..."

# 1. ========== Jellyfin Update ==========
if [[ "${UPDATE_JELLYFIN}" == "true" ]]; then

    # 1.1 Docker Compose Down
    log "Stopping Jellyfin services..."
    docker compose -f "$JELLYFIN_COMPOSE_FILE" down || error "Failed to stop Jellyfin services!"

    # 1.2 Docker Compose Pull
    log "Pulling latest Jellyfin Docker Images..."
    docker compose -f "$JELLYFIN_COMPOSE_FILE" pull || error "Jellyfin Docker Compose Pull failed!"

    # 1.3 Docker Compose Up
    log "Starting Jellyfin services..."
    docker compose -f "$JELLYFIN_COMPOSE_FILE" up -d || error "Jellyfin Docker Compose Up failed!"

    log "Jellyfin Update completed."
fi

# 2. ========== Memos Backup & Update ==========
if [[ "${UPDATE_MEMOS}" == "true" ]]; then

    # 2.1 Execute Backup
    log "Starting Memos Backup..."
    cp -r "${MEMOS_DIRECTORY}/memos_prod.db" "${MEMOS_BACKUP_DIRECTORY}/memos_prod.db.bak"

        # 2.2 Docker Compose Down
    log "Stopping Memos services..."
    docker compose -f "$MEMOS_COMPOSE_FILE" down || error "Failed to stop Memos services!"

    # 2.3 Docker Compose Pull
    log "Pulling latest Memos Docker Images..."
    docker compose -f "$MEMOS_COMPOSE_FILE" pull || error "Memos Docker Compose Pull failed!"

    # 2.4 Docker Compose Up
    log "Starting Memos Docker Compose..."
    docker compose -f "$MEMOS_COMPOSE_FILE" up -d || error "Memos Docker Compose Up failed!"

    log "Memos Backup & Update completed."
fi

# 3. ========== Adguard Home Update ==========
if [[ "${UPDATE_ADGUARDHOME}" == "true" ]]; then

    # 3.1 Docker Compose Down
    log "Stopping Adguard Home services..."
    docker compose -f "$ADGUARDHOME_COMPOSE_FILE" down || error "Failed to stop Adguard Home services!"

    # 3.2 Docker Compose Pull
    log "Pulling latest Adguard Home Docker Images..."
    docker compose -f "$ADGUARDHOME_COMPOSE_FILE" pull || error "Adguard Home Docker Compose Pull failed!"

    # 3.3 Docker Compose Up
    log "Starting Adguard Home services..."
    docker compose -f "$ADGUARDHOME_COMPOSE_FILE" up -d || error "Adguard Home Docker Compose Up failed!"

    log "Adguard Home Update completed."
fi

# 4. ========== Paperless Backup & Update ==========
if [[ "${UPDATE_PAPERLESS}" == "true" ]]; then

    # 4.1 Execute Backup
    log "Starting Paperless Backup..."
    cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
    docker compose exec webserver document_exporter ../export -z -d || error "Paperless document export failed!"
    cd "$ORIGINAL_DIR"  || error "Could not change back to home directory!"

    # 4.2 Docker Compose Down
    log "Stopping Paperless services..."
    docker compose -f "$PAPERLESS_COMPOSE_FILE" down || error "Failed to stop Paperless services!"

    # 4.3 Docker Compose Pull
    log "Pulling latest Paperless Docker images..."
    docker compose -f "$PAPERLESS_COMPOSE_FILE" pull || error "Paperless Docker Compose Pull failed!"

    # 4.4 Docker Compose Up
    log "Starting Paperless services..."
    docker compose -f "$PAPERLESS_COMPOSE_FILE" up -d || error "Paperless Docker Compose Up failed!"

    log "Paperless Backup & Update completed."
fi

# 5. ========== PhotoPrism Update ==========
if [[ "${UPDATE_PHOTOPRISM}" == "true" ]]; then

    # 5.1 Pull latest images
    log "Pulling latest PhotoPrism images..."
    sudo podman pull docker.io/photoprism/photoprism:latest || error "Failed to pull PhotoPrism image!"

    # 5.2 Restart service
    log "Restarting PhotoPrism service..."
    sudo systemctl restart pod-photoprism.service || error "Failed to restart PhotoPrism!"

    log "PhotoPrism Update completed."
fi

# 6. ========== qbittorrent Update ==========
if [[ "${UPDATE_QBITTORRENT}" == "true" ]]; then

    # 6.1 Docker Compose Down
    log "Stopping qbittorrent services..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" down || error "Failed to stop qbittorrent services!"

    # 6.2 Docker Compose Pull
    log "Pulling latest qbittorrent Docker Images..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" pull || error "qbittorrent Docker Compose Pull failed!"

    # 6.3 Docker Compose Up
    log "Starting qbittorrent services..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" up -d || error "qbittorrente Docker Compose Up failed!"

    log "qbittorrent Update completed."
fi

# 7. ========== Dockpeek Update ==========
if [[ "${UPDATE_DOCKPEEK}" == "true" ]]; then

    # 7.1 Docker Compose Down
    log "Stopping Dockpeek services..."
    docker compose -f "$DOCKPEEK_COMPOSE_FILE" down || error "Failed to stop Dockpeek services!"

    # 7.2 Docker Compose Pull
    log "Pulling latest Dockpeek Docker Images..."
    docker compose -f "$DOCKPEEK_COMPOSE_FILE" pull || error "Dockpeek Docker Compose Pull failed!"

    # 7.3 Docker Compose Up
    log "Starting Dockpeek services..."
    docker compose -f "$DOCKPEEK_COMPOSE_FILE" up -d || error "Dockpeek Docker Compose Up failed!"

    log "Dockpeek Update completed."
fi

# 8. ========== OmniTools Update ==========
if [[ "${UPDATE_OMNITOOLS}" == "true" ]]; then

    # 8.1 Docker Compose Down
    log "Stopping OmniTools services..."
    docker compose -f "$OMNITOOLS_COMPOSE_FILE" down || error "Failed to stop OmniTools services!"

    # 8.2 Docker Compose Pull
    log "Pulling latest OmniTools Docker Images..."
    docker compose -f "$OMNITOOLS_COMPOSE_FILE" pull || error "OmniTools Docker Compose Pull failed!"

    # 8.3 Docker Compose Up
    log "Starting OmniTools services..."
    docker compose -f "$OMNITOOLS_COMPOSE_FILE" up -d || error "OmniTools Docker Compose Up failed!"

    log "OmniTools Update completed."
fi

# 9. ========== Homepage Update ==========
if [[ "${UPDATE_HOMEPAGE}" == "true" ]]; then

    # 9.1 Docker Compose Down
    log "Stopping Homepage services..."
    docker compose -f "$HOMEPAGE_COMPOSE_FILE" down || error "Failed to stop Homepage services!"

    # 9.2 Docker Compose Pull
    log "Pulling latest Homepage Docker Images..."
    docker compose -f "$HOMEPAGE_COMPOSE_FILE" pull || error "Homepage Docker Compose Pull failed!"

    # 9.3 Docker Compose Up
    log "Starting Homepage services..."
    docker compose -f "$HOMEPAGE_COMPOSE_FILE" up -d || error "Homepage Docker Compose Up failed!"

    log "Homepage Update completed."
fi

# 10. ========== Docker Image Prune ==========
log "Removing unused Docker Images..."
docker image prune -a -f || log "Docker Image Prune failed (no problem if no images were removed)."

# 11. ========== Podman Image Prune ==========
log "Removing unused Podman Images..."
podman image prune -a -f || log "Podman Image Prune failed (no problem if no images were removed)."

# Script end
log "All selected services update completed."
print_separator "SERVICES UPDATE COMPLETED SUCCESSFULLY"
echo "" >> "$LOG_FILE"
exit 0
