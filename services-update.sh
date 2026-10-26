#!/bin/bash
# Copyright (C) 2026 Niklas Fuchshofer
#
# This script is licensed under the GNU General Public License Version 3 or
# any later version.
# See LICENSE file for more details.
# -----------------------------------------------------------------------------
# Script to update and backup services like Jellyfin, Paperless and PhotoPrism
# -----------------------------------------------------------------------------

set -euo pipefail

DATE=$(date +%Y-%m-%d)
ORIGINAL_DIR=$(pwd)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env in script directory
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
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
# working directory, so the log always ends up in the same place.
if [[ "$LOG_FILE" != /* ]]; then
    LOG_FILE="$SCRIPT_DIR/${LOG_FILE#./}"
fi

LOG_DIR="$(dirname "$LOG_FILE")"
if [[ ! -d "$LOG_DIR" ]] && ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    echo "Could not create log directory: $LOG_DIR"
    exit 1
fi
LOG_FILE="$(cd "$LOG_DIR" && pwd)/$(basename "$LOG_FILE")"

# Rotate log if larger than 10 MB (keep one .old backup)
if [[ -f "$LOG_FILE" ]]; then
    log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [[ "$log_size" -gt 10485760 ]]; then
        mv -f "$LOG_FILE" "${LOG_FILE}.old"
        : > "$LOG_FILE"
        echo "[$(date +%Y-%m-%d_%H-%M-%S)] Log rotated (previous size: ${log_size} bytes)" >> "$LOG_FILE"
    fi
fi

# Accumulator for the final summary report (sent via stdout / email)
SUMMARY=""

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

# Print a separator with date to the log file only
print_separator_log() {
    local message="${1:-}"
    {
        echo "============================================================"
        echo "==== ${DATE} - ${message} ===="
        echo "============================================================"
    } >> "$LOG_FILE"
}

# Write a timestamped message to the log file only (detailed operation logs)
log_detail() {
    echo "[$(date +%Y-%m-%d_%H-%M-%S)] $1" >> "$LOG_FILE"
}

# Write a timestamped message to stdout (email) AND the log file
log_both() {
    local msg="[$(date +%Y-%m-%d_%H-%M-%S)] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# Run a command redirecting all output to the log file.
run_silent() {
    "$@" >> "$LOG_FILE" 2>&1
}

# Run a command, capture its output to a variable, write to log, and echo it back.
run_and_capture() {
    local output exit_code
    set +e
    output=$("$@" 2>&1)
    exit_code=$?
    set -e
    echo "$output" >> "$LOG_FILE"
    echo "$output"
    return $exit_code
}

# Check whether a pull output indicates that a new image was actually downloaded.
# Returns 0 if something was updated/pulled, 1 if everything was already up to date.
_was_updated() {
    local output="$1"
    # Docker Compose indicators
    echo "$output" | grep -qiE "downloaded newer image|pull complete" && return 0
    # Podman indicators (actually pulled new image)
    echo "$output" | grep -qiE "storing signatures|writing manifest" && return 0
    return 1
}

# Log an error message to both destinations and abort the script.
# Disables the ERR trap to avoid recursive invocation.
error() {
    trap - ERR
    log_both "ERROR: $1"
    print_separator_log "SCRIPT FAILED"
    exit 1
}

# Verify that an enabled service is configured correctly
require_compose() {
    local name="$1" file="${2:-}"
    [[ -n "$file" ]] || error "$name is enabled but its compose file path is not set!"
    [[ -f "$file" ]] || error "$name compose file not found: $file"
}

# Append a line to the summary accumulator
add_summary() {
    SUMMARY+="$1"$'\n'
}

# Generic update routine for Docker Compose based services.
update_docker_service() {
    local name="$1" compose_file="$2"
    require_compose "$name" "$compose_file"

    log_detail "Stopping $name service..."
    run_silent docker compose -f "$compose_file" down || error "Failed to stop $name services!"

    log_detail "Pulling latest $name images..."
    local pull_output exit_code
    set +e
    pull_output=$(run_and_capture docker compose -f "$compose_file" pull)
    exit_code=$?
    set -e
    [[ $exit_code -eq 0 ]] || error "$name Docker Compose Pull failed!"

    if _was_updated "$pull_output"; then
        add_summary "[OK] $name: Updated"
    else
        add_summary "[OK] $name: Up to date"
    fi

    log_detail "Starting $name service..."
    run_silent docker compose -f "$compose_file" up -d || error "$name Docker Compose Up failed!"

    log_detail "$name update completed."
}

# Trap any unhandled error to a generic message with line number.
trap 'error "Unexpected error at line ${LINENO:-?}"' ERR

# On exit, always emit the summary (so we see partial results even on failure).
trap '{
    if [[ -n "${SUMMARY:-}" ]]; then
        echo ""
        echo "Services Update Summary - $DATE"
        echo -n "$SUMMARY"
        echo "---"
    fi
} | tee -a "$LOG_FILE"' EXIT

# ---------------------------------------------------------------------------
# Script Start
# ---------------------------------------------------------------------------

print_separator_log "STARTING SERVICES UPDATE"
log_detail "Starting Services Update Script..."
log_detail "Logging to: $LOG_FILE"

# 1-9. Docker Compose services (generic handler)
[[ "${UPDATE_JELLYFIN:-}" == "true" ]] && update_docker_service "Jellyfin" "${JELLYFIN_COMPOSE_FILE:-}"
[[ "${UPDATE_MEMOS:-}" == "true" ]] && update_docker_service "Memos" "${MEMOS_COMPOSE_FILE:-}"
[[ "${UPDATE_ADGUARDHOME:-}" == "true" ]] && update_docker_service "AdGuard Home" "${ADGUARDHOME_COMPOSE_FILE:-}"
[[ "${UPDATE_QBITTORRENT:-}" == "true" ]] && update_docker_service "qBittorrent" "${QBITTORRENT_COMPOSE_FILE:-}"
[[ "${UPDATE_DOCKPEEK:-}" == "true" ]] && update_docker_service "Dockpeek" "${DOCKPEEK_COMPOSE_FILE:-}"
[[ "${UPDATE_OMNITOOLS:-}" == "true" ]] && update_docker_service "OmniTools" "${OMNITOOLS_COMPOSE_FILE:-}"
[[ "${UPDATE_HOMEPAGE:-}" == "true" ]] && update_docker_service "Homepage" "${HOMEPAGE_COMPOSE_FILE:-}"
[[ "${UPDATE_PANGOLIN:-}" == "true" ]] && update_docker_service "Pangolin" "${PANGOLIN_COMPOSE_FILE:-}"
[[ "${UPDATE_OPENWEBUI:-}" == "true" ]] && update_docker_service "OpenWebUI" "${OPENWEBUI_COMPOSE_FILE:-}"

# 10. Paperless (backup before update)
if [[ "${UPDATE_PAPERLESS:-}" == "true" ]]; then
    require_compose "Paperless" "${PAPERLESS_COMPOSE_FILE:-}"
    [[ -n "${PAPERLESS_DIRECTORY:-}" ]] || error "Paperless is enabled but PAPERLESS_DIRECTORY is not set!"
    [[ -d "$PAPERLESS_DIRECTORY" ]] || error "Paperless directory not found: $PAPERLESS_DIRECTORY"

    log_detail "Starting Paperless backup..."
    cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
    run_silent docker compose exec -T webserver document_exporter ../export -z -d --no-progress-bar || error "Paperless document export failed!"
    cd "$ORIGINAL_DIR" || error "Could not change back to home directory!"

    update_docker_service "Paperless" "${PAPERLESS_COMPOSE_FILE:-}"
fi

# 11. PhotoPrism (Podman + systemctl)
if [[ "${UPDATE_PHOTOPRISM:-}" == "true" ]]; then
    log_detail "Stopping PhotoPrism service..."
    run_silent sudo systemctl stop pod-photoprism.service || error "Failed to stop PhotoPrism service!"

    log_detail "Pulling latest PhotoPrism image..."
    pull_output="" exit_code=0
    set +e
    pull_output=$(run_and_capture sudo podman pull docker.io/photoprism/photoprism:latest)
    exit_code=$?
    set -e
    [[ $exit_code -eq 0 ]] || error "Failed to pull PhotoPrism image!"

    if _was_updated "$pull_output"; then
        add_summary "[OK] PhotoPrism: Updated"
    else
        add_summary "[OK] PhotoPrism: Up to date"
    fi

    log_detail "Starting PhotoPrism service..."
    run_silent sudo systemctl start pod-photoprism.service || error "Failed to start PhotoPrism!"

    log_detail "PhotoPrism update completed."
fi

# 12. Docker System Prune
log_detail "Removing unused Docker containers, images, networks, and build cache..."
docker_prune_output=""
docker_prune_exit=0
set +e
docker_prune_output=$(docker system prune -a -f 2>&1)
docker_prune_exit=$?
set -e
echo "$docker_prune_output" >> "$LOG_FILE"

if [[ $docker_prune_exit -eq 0 ]]; then
    docker_reclaimed=$(echo "$docker_prune_output" | grep -i "total reclaimed space" | sed 's/.*Total reclaimed space: *//i' || echo "N/A")
    add_summary "[OK] Docker Prune: ${docker_reclaimed} reclaimed"
else
    add_summary "[FAIL] Docker Prune: Failed (see log)"
fi

# 13. Podman System Prune
log_detail "Removing unused Podman containers, images, networks, and build cache..."
podman_prune_output=""
podman_prune_exit=0
set +e
podman_prune_output=$(podman system prune -a -f 2>&1)
podman_prune_exit=$?
set -e
echo "$podman_prune_output" >> "$LOG_FILE"

if [[ $podman_prune_exit -eq 0 ]]; then
    podman_reclaimed=$(echo "$podman_prune_output" | grep -i "total reclaimed space" | sed 's/.*Total reclaimed space: *//i' || echo "N/A")
    add_summary "[OK] Podman Prune: ${podman_reclaimed} reclaimed"
else
    add_summary "[FAIL] Podman Prune: Failed (see log)"
fi

exit 0