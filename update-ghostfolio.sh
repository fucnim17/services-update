#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
#
# -----------------------------------------------------------------------------
# Script to update Ghostfolio and related services

REPO_ROOT=$(git rev-parse --show-toplevel)

# Variables
COMPOSE_FILE="/root/ghostfolio/docker/docker-compose.yml"
LOG_FILE="$REPO_ROOT/update-ghostfolio.log"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

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
log "Starting Ghostfolio Update Script..."

# 1. Docker Compose Pull
log "Pulling latest Docker Images..."
docker compose -f "$COMPOSE_FILE" pull || error "Docker Compose Pull failed!"

# 2. Docker Compose Up
log "Starting Docker Compose..."
docker compose -f "$COMPOSE_FILE" up -d || error "Docker Compose Up failed!"

# 3. Docker Image Prune
log "Removing unused Docker Images..."
docker image prune -a -f || log "Docker Image Prune failed (no problem if no images were removed)."

# 4. Docker Update (Restart Policy)
log "Updating Restart Policy for Ghostfolio Container..."
docker update --restart unless-stopped ghostfolio || error "Docker Update for Ghostfolio failed!"
docker update --restart unless-stopped gf-postgres || error "Docker Update for gf-postgres failed!"
docker update --restart unless-stopped gf-redis || error "Docker Update for gf-redis failed!"

# Script end
log "Ghostfolio Update completed."
exit 0
