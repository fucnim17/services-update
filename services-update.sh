#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
# -----------------------------------------------------------------------------
# Script to update Jellyfin, Paperless, PhotoPrism and backup Paperless
# -----------------------------------------------------------------------------

# Variables
JELLYFIN_COMPOSE_FILE="/root/jellyfin/docker-compose.yml"

MEMOS_DIRECTORY="/root/.memos"
MEMOS_COMPOSE_FILE="/root/memos/docker-compose.yml"
MEMOS_BACKUP_DIRECTORY="/srv/dev-disk-by-uuid-1662b18d-6525-436b-9831-0d970568c184/data/000_Dokumente"

ADGUARDHOME_COMPOSE_FILE="/root/adguardhome/docker-compose.yml"

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

# 1. ========== Jellyfin Update ==========
log "Starting Jellyfin Update..."

# 1.1 Docker Compose Pull
log "Pulling latest Jellyfin Docker Images..."
docker compose -f "$JELLYFIN_COMPOSE_FILE" pull || error "Jellyfin Docker Compose Pull failed!"

# 1.2 Docker Compose Up
log "Starting Jellyfin services..."
docker compose -f "$JELLYFIN_COMPOSE_FILE" up -d || error "Jellyfin Docker Compose Up failed!"

log "Jellyfin Update completed."

# 2. ========== Memos Backup & Update ==========
log "Starting Memos Backup..."

# 2.1 Change to Memos directory and execute Backup
cd "$MEMOS_DIRECTORY" || error "Could not change to Memos directory!"
cp -r ~/.memos/memos_prod.db ${MEMOS_BACKUP_DIRECTORY}/memos_prod.db.bak

log "Starting Memos Update..."

# 2.2 Docker Compose Pull
log "Pulling latest Memos Docker Images..."
docker compose -f "$MEMOS_COMPOSE_FILE" pull || error "Memos Docker Compose Pull failed!"

# 2.3 Docker Compose Up
log "Starting Memos Docker Compose..."
docker compose -f "$MEMOS_COMPOSE_FILE" up -d || error "Memos Docker Compose Up failed!"

# 2.4 Return to original directory
cd "$ORIGINAL_DIR" || error "Could not change back to original directory!"

log "Memos Backup & Update completed."

# 3. ========== Adguard Home Update ==========
log "Starting Adguard Home Update..."

# 3.1 Docker Compose Pull
log "Pulling latest Adguard Home Docker Images..."
docker compose -f "$ADGUARDHOME_COMPOSE_FILE" pull || error "Adguard Home Docker Compose Pull failed!"

# 3.2 Docker Compose Up
log "Starting Memos Docker Compose..."
docker compose -f "$ADGUARDHOME_COMPOSE_FILE" up -d || error "Adguard Home Docker Compose Up failed!"

log "Adgaurd Home Update completed."

# 4. ========== Paperless Backup & Update ==========
log "Starting Paperless Backup..."

# 4.1 Change to Paperless directory and execute Backup
cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
docker compose exec webserver document_exporter ../export -z -d || error "Paperless document export failed!"

log "Starting Paperless Update..."

# 4.2 Docker Compose Down
log "Stopping Paperless services..."
docker compose down || error "Failed to stop Paperless services!"

# 4.3 PDocker Compose Pull
log "Pulling latest Paperless Docker images..."
docker compose pull || error "Failed to pull latest Paperless Docker images!"

# 4.4 Docker Compose Up
log "Starting Paperless services..."
docker compose up -d || error "Failed to start Paperless services!"

# 4.5 Return to original directory
cd "$ORIGINAL_DIR" || error "Could not change back to original directory!"

log "Paperless Backup & Update completed."

# 5. ========== PhotoPrism Update ==========
log "Starting PhotoPrism Update..."

# 5.1 Pull latest images
log "Pulling latest PhotoPrism images..."
sudo podman pull docker.io/photoprism/photoprism:latest || error "Failed to pull PhotoPrism image!"

# 5.2 Restart service
log "Restarting PhotoPrism service..."
sudo systemctl restart pod-photoprism.service || error "Failed to restart PhotoPrism!"

log "PhotoPrism Update completed."

# 6. ========== FileBroser Update ==========
# log "Starting FileBrowser Update..."

# 6.1 Pull latest images
# log "Pulling latest FileBrower images..."
# sudo podman pull docker.io/filebrowser/filebrowser:latest || error "Failed to pull FileBrowser image!"

# 6.2 Restart services in correct order
# log "Restarting FileBrowser services..."
# sudo podman restart filebrowser-app || error "Failed to restart FileBrowser"

# 7. ========== Docker Image Prune ==========
log "Removing unused Docker Images..."
docker image prune -a -f || log "Docker Image Prune failed (no problem if no images were removed)."

# 8. ========== Podman Image Prune ==========
log "Removing unused Podman Images..."
podman image prune -a -f || log "Podman Image Prune failed (no problem if no images were removed)."

# Script end
log "All services update completed."
print_separator "SERVICES UPDATE COMPLETED SUCCESSFULLY"
echo "" >> "$LOG_FILE"
exit 0
