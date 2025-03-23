#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
#
# -----------------------------------------------------------------------------
# Script to update Jellyfin, Ghostfolio and backup Paperless

# Variables
GHOSTFOLIO_COMPOSE_FILE="/root/ghostfolio/docker/docker-compose.yml"
JELLYFIN_COMPOSE_FILE="/root/jellyfin/docker-compose.yml"
PAPERLESS_DIRECTORY="/root/paperless-ngx/docker/compose"
LOG_FILE="/root/services-update/services-update.log"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
ORIGINAL_DIR=$(pwd)

# Functions

# Function to log messages with a timestamp
log() {
  echo "[${TIMESTAMP}] $1" | tee -a "$LOG_FILE"
}

# Function to log errors and exit the script
error() {
  log "ERROR: $1"
  exit 1
}

# Script start
log "Starting Services Update Script..."

# 1. Jellyfin Update
log "Starting Jellyfin Update..."

# 1.1 Docker Compose Pull
log "Pulling latest Jellyfin Docker Images..."
docker compose -f "$JELLYFIN_COMPOSE_FILE" pull || error "Jellyfin Docker Compose Pull failed!"

# 1.2 Docker Compose Up
log "Starting Jellyfin Docker Compose..."
docker compose -f "$JELLYFIN_COMPOSE_FILE" up -d || error "Jellyfin Docker Compose Up failed!"

log "Jellyfin Update completed."

# 2. Ghostfolio Update
log "Starting Ghostfolio Update..."

# 2.1 Docker Compose Pull
log "Pulling latest Docker Images..."
docker compose -f "$GHOSTFOLIO_COMPOSE_FILE" pull || error "Docker Compose Pull failed!"

# 2.2 Docker Compose Up
log "Starting Docker Compose..."
docker compose -f "$GHOSTFOLIO_COMPOSE_FILE" up -d || error "Docker Compose Up failed!"

# 2.3 Docker Update (Restart Policy)
log "Updating Restart Policy for Ghostfolio Container..."
docker update --restart unless-stopped ghostfolio || error "Docker Update for Ghostfolio failed!"
docker update --restart unless-stopped gf-postgres || error "Docker Update for gf-postgres failed!"
docker update --restart unless-stopped gf-redis || error "Docker Update for gf-redis failed!"

log "Ghostfolio Update completed."

# 3. Docker Image Prune
log "Removing unused Docker Images..."
docker image prune -a -f || log "Docker Image Prune failed (no problem if no images were removed)."

# 4. Paperless Backup
log "Starting Paperless Backup..."

cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
docker compose exec webserver document_exporter ../export -z || error "Paperless document export failed!"
cd "$ORIGINAL_DIR" || error "Could not change back to original directory!"

log "Paperless Backup completed."

# Script end
log "All services update completed."
exit 0
