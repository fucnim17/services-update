#!/bin/bash
# Copyright (C) 2026 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
# -----------------------------------------------------------------------------
# Script to update and backup services like Jellyfin, Paperless and PhotoPrism
# -----------------------------------------------------------------------------

# Abort on unset variables and report failures inside pipelines
set -uo pipefail

DATE=$(date +%Y-%m-%d)
ORIGINAL_DIR=$(pwd)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env in script directory
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/.env"
    set +a
else
    echo ".env file not found in script directory: $SCRIPT_DIR"
    exit 1
fi

# Resolve the log file path before anything is written to it
if [[ -z "${LOG_FILE:-}" ]]; then
    echo "LOG_FILE is not set in $SCRIPT_DIR/.env"
    exit 1
fi

# A relative path is resolved against the script directory, not the current
# working directory, so the log always ends up in the same place - no matter
# from where the script is started (e.g. by cron)
if [[ "$LOG_FILE" != /* ]]; then
    LOG_FILE="$SCRIPT_DIR/${LOG_FILE#./}"
fi

LOG_DIR="$(dirname "$LOG_FILE")"
if [[ ! -d "$LOG_DIR" ]] && ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    echo "Could not create log directory: $LOG_DIR"
    exit 1
fi
LOG_FILE="$(cd "$LOG_DIR" && pwd)/$(basename "$LOG_FILE")"

# Send everything - including the output of the docker/podman commands - to the
# terminal and to the log file, so a failure reason is recorded as well
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to print a separator line with date
print_separator() {
    local message="${1:-}"
    echo "============================================================"
    echo "==== ${DATE} - ${message} ===="
    echo "============================================================"
}

# Function to log messages with a timestamp
log() {
    echo "[$(date +%Y-%m-%d_%H-%M-%S)] $1"
}

# Function to log errors and exit the script
error() {
    log "ERROR: $1"
    print_separator "SCRIPT FAILED"
    echo ""
    exit 1
}

# Function to verify that an enabled service is configured correctly
require_compose() {
    local name="$1" file="${2:-}"
    [[ -n "$file" ]] || error "$name is enabled but its compose file path is not set!"
    [[ -f "$file" ]] || error "$name compose file not found: $file"
}

# Script start
print_separator "STARTING SERVICES UPDATE"
log "Starting Services Update Script..."
log "Logging to: $LOG_FILE"

# 1. ========== Jellyfin Update ==========
if [[ "${UPDATE_JELLYFIN:-}" == "true" ]]; then

    require_compose "Jellyfin" "${JELLYFIN_COMPOSE_FILE:-}"

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

# 2. ========== Memos Update ==========
if [[ "${UPDATE_MEMOS:-}" == "true" ]]; then

    require_compose "Memos" "${MEMOS_COMPOSE_FILE:-}"

    # 2.1 Docker Compose Down
    log "Stopping Memos services..."
    docker compose -f "$MEMOS_COMPOSE_FILE" down || error "Failed to stop Memos services!"

    # 2.2 Docker Compose Pull
    log "Pulling latest Memos Docker Images..."
    docker compose -f "$MEMOS_COMPOSE_FILE" pull || error "Memos Docker Compose Pull failed!"

    # 2.3 Docker Compose Up
    log "Starting Memos Docker Compose..."
    docker compose -f "$MEMOS_COMPOSE_FILE" up -d || error "Memos Docker Compose Up failed!"

    log "Memos Update completed."
fi

# 3. ========== Adguard Home Update ==========
if [[ "${UPDATE_ADGUARDHOME:-}" == "true" ]]; then

    require_compose "Adguard Home" "${ADGUARDHOME_COMPOSE_FILE:-}"

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
if [[ "${UPDATE_PAPERLESS:-}" == "true" ]]; then

    require_compose "Paperless" "${PAPERLESS_COMPOSE_FILE:-}"
    [[ -n "${PAPERLESS_DIRECTORY:-}" ]] || error "Paperless is enabled but PAPERLESS_DIRECTORY is not set!"
    [[ -d "$PAPERLESS_DIRECTORY" ]] || error "Paperless directory not found: $PAPERLESS_DIRECTORY"

    # 4.1 Execute Backup
    log "Starting Paperless Backup..."
    cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
    docker compose exec -T webserver document_exporter ../export -z -d --no-progress-bar || error "Paperless document export failed!"
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
if [[ "${UPDATE_PHOTOPRISM:-}" == "true" ]]; then

    # 5.1 Stop service
    log "Stopping PhotoPrism service..."
    sudo systemctl stop pod-photoprism.service || error "Failed to stop PhotoPrism image!"

    # 5.2 Pull latest images
    log "Pulling latest PhotoPrism images..."
    sudo podman pull docker.io/photoprism/photoprism:latest || error "Failed to pull PhotoPrism image!"

    # 5.3 Start service
    log "Starting PhotoPrism service..."
    sudo systemctl start pod-photoprism.service || error "Failed to start PhotoPrism!"

    log "PhotoPrism Update completed."
fi

# 6. ========== qbittorrent Update ==========
if [[ "${UPDATE_QBITTORRENT:-}" == "true" ]]; then

    require_compose "qbittorrent" "${QBITTORRENT_COMPOSE_FILE:-}"

    # 6.1 Docker Compose Down
    log "Stopping qbittorrent services..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" down || error "Failed to stop qbittorrent services!"

    # 6.2 Docker Compose Pull
    log "Pulling latest qbittorrent Docker Images..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" pull || error "qbittorrent Docker Compose Pull failed!"

    # 6.3 Docker Compose Up
    log "Starting qbittorrent services..."
    docker compose -f "$QBITTORRENT_COMPOSE_FILE" up -d || error "qbittorrent Docker Compose Up failed!"

    log "qbittorrent Update completed."
fi

# 7. ========== Dockpeek Update ==========
if [[ "${UPDATE_DOCKPEEK:-}" == "true" ]]; then

    require_compose "Dockpeek" "${DOCKPEEK_COMPOSE_FILE:-}"

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
if [[ "${UPDATE_OMNITOOLS:-}" == "true" ]]; then

    require_compose "OmniTools" "${OMNITOOLS_COMPOSE_FILE:-}"

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
if [[ "${UPDATE_HOMEPAGE:-}" == "true" ]]; then

    require_compose "Homepage" "${HOMEPAGE_COMPOSE_FILE:-}"

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

# 10. ========== Docker System Prune ==========
log "Removing unused Docker containers, images, networks, and build cache..."
docker system prune -a -f || log "Docker System Prune failed."

# 11. ========== Podman System Prune ==========
log "Removing unused Podman containers, images, networks, and build cache..."
podman system prune -a -f || log "Podman System Prune failed."

# Script end
log "All selected services update completed."
print_separator "SERVICES UPDATE COMPLETED SUCCESSFULLY"
echo ""
exit 0
