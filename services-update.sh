#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
# -----------------------------------------------------------------------------
# Script to update Jellyfin, Ghostfolio, Paperless, PhotoPrism and backup Paperless
# -----------------------------------------------------------------------------

# Variables
GHOSTFOLIO_COMPOSE_FILE="/root/ghostfolio/docker/docker-compose.yml"
JELLYFIN_COMPOSE_FILE="/root/jellyfin/docker-compose.yml"
PAPERLESS_DIRECTORY="/root/paperless-ngx/docker/compose"
PAPERLESS_COMPOSE_FILE="${PAPERLESS_DIRECTORY}/docker-compose.yml"
LOG_FILE="/root/services-update/services-update.log"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
DATE=$(date +%Y-%m-%d)
ORIGINAL_DIR=$(pwd)

# Function to print a separator line with date
print_separator() {
  local message="${1:-}"
  echo "============================================================" >> "$LOG_FILE"
  echo "==== ${DATE} - ${message} ====" >> "$LOG_FILE"
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
  echo "" >> "$LOG_FILE"  # Add empty line at the end
  exit 1
}

# Script start
print_separator "STARTING SERVICES UPDATE"
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

# 3. Paperless Update
log "Starting Paperless Update..."

# 3.1 Change to Paperless directory
cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"

# 3.2 Stop Paperless
log "Stopping Paperless services..."
docker compose down || error "Failed to stop Paperless services!"

# 3.3 Pull latest Paperless images
log "Pulling latest Paperless Docker images..."
docker compose pull || error "Failed to pull latest Paperless Docker images!"

# 3.4 Start Paperless services
log "Starting Paperless services..."
docker compose up -d || error "Failed to start Paperless services!"

# 3.5 Return to original directory
cd "$ORIGINAL_DIR" || error "Could not change back to original directory!"

log "Paperless Update completed."

# 4. PhotoPrism Update
log "Starting PhotoPrism Update..."

# 4.1 Pull latest images
log "Pulling latest PhotoPrism images..."
sudo podman pull docker.io/photoprism/photoprism:latest || error "Failed to pull PhotoPrism image!"
sudo podman pull docker.io/mariadb:latest || error "Failed to pull MariaDB image!"

# 4.2 Restart services in correct order
log "Restarting PhotoPrism services..."
sudo systemctl restart pod-photoprism.service || log "WARNING: Failed to restart pod service"
sleep 3
sudo systemctl restart container-photoprism-db.service || log "WARNING: Failed to restart database service"
sleep 5 
sudo systemctl restart container-photoprism-app.service || log "WARNING: Failed to restart app service"

# 4.3 Check if services are running
log "Checking if PhotoPrism services are running..."
sleep 3
if [ "$(sudo podman pod ps -f name=photoprism --format '{{.Status}}' | grep -c 'Running')" -gt 0 ]; then
    log "PhotoPrism pod is running."
else
    log "WARNING: PhotoPrism pod is not running. Check logs with: sudo journalctl -u pod-photoprism.service"
fi

log "PhotoPrism Update completed."

# 5. Docker Image Prune
log "Removing unused Docker Images..."
docker image prune -a -f || log "Docker Image Prune failed (no problem if no images were removed)."

# 6. Podman Image Prune
log "Removing unused Podman Images..."
podman image prune -a -f || log "Podman Image Prune failed (no problem if no images were removed)."

# 7. Paperless Backup
log "Starting Paperless Backup..."

cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
docker compose exec webserver document_exporter ../export -z || error "Paperless document export failed!"
cd "$ORIGINAL_DIR" || error "Could not change back to original directory!"

log "Paperless Backup completed."

# Script end
log "All services update completed."
print_separator "SERVICES UPDATE COMPLETED SUCCESSFULLY"
echo "" >> "$LOG_FILE"
exit 0
