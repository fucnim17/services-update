#!/bin/bash
# Copyright (C) 2025 Niklas Fuchshofer
#
# Dieses Skript ist unter der GNU General Public License Version 3 oder
# einer späteren Version lizenziert.
# Siehe LICENSE-Datei für weitere Details.
#
# -----------------------------------------------------------------------------
# Skript zum Aktualisieren von Ghostfolio und zugehörigen Diensten

# Variablen
COMPOSE_FILE="/root/ghostfolio/docker/docker-compose.yml"
LOG_FILE="update-ghostfolio.log"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Funktionen

log() {
  echo "[${TIMESTAMP}] $1" | tee -a "$LOG_FILE"
}

error() {
  log "ERROR: $1"
  exit 1
}

# Skriptstart
log "Starte Ghostfolio Update Skript..."

# 1. Docker Compose Pull
log "Ziehe neueste Docker Images..."
docker compose -f "$COMPOSE_FILE" pull || error "Docker Compose Pull fehlgeschlagen!"

# 2. Docker Compose Up
log "Starte Docker Compose..."
docker compose -f "$COMPOSE_FILE" up -d || error "Docker Compose Up fehlgeschlagen!"

# 3. Docker Image Prune
log "Entferne ungenutzte Docker Images..."
docker image prune -a -f || log "Docker Image Prune fehlgeschlagen (kein Problem, wenn keine Images entfernt wurden)."

# 4. Docker Update (Restart Policy)
log "Aktualisiere Restart Policy für Ghostfolio Container..."
docker update --restart unless-stopped ghostfolio || error "Docker Update für Ghostfolio fehlgeschlagen!"
docker update --restart unless-stopped gf-postgres || error "Docker Update für gf-postgres fehlgeschlagen!"
docker update --restart unless-stopped gf-redis || error "Docker Update für gf-redis fehlgeschlagen!"

# Skriptende
log "Ghostfolio Update abgeschlossen."
exit 0
