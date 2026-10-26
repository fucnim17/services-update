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
# Preserves the original exit code so failures can still be caught.
run_silent() {
    "$@" >> "$LOG_FILE" 2>&1
}

# Run a command, capture its output to a variable, write to log, and echo it back.
# Preserves the original exit code so the caller can check for failures.
run_and_capture() {
    local output
    output=$("$@" 2>&1)
    local exit_code=$?
    echo "$output" >> "$LOG_FILE"
    echo "$output"
    return $exit_code
}

# Check whether a pull output indicates that the image was already up to date.
# Returns 0 if up to date, 1 otherwise.
_is_up_to_date() {
    local output="$1"
    echo "$output" | grep -qiE "already up to date|up to date"
}

# Log an error message to both destinations and abort the script
error() {
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

# ---------------------------------------------------------------------------
# Script Start
# ---------------------------------------------------------------------------

print_separator_log "STARTING SERVICES UPDATE"
log_detail "Starting Services Update Script..."
log_detail "Logging to: $LOG_FILE"

# ---------------------------------------------------------------------------
# 1. ========== Jellyfin Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_JELLYFIN:-}" == "true" ]]; then
    require_compose "Jellyfin" "${JELLYFIN_COMPOSE_FILE:-}"

    log_detail "Stopping Jellyfin services..."
    run_silent docker compose -f "$JELLYFIN_COMPOSE_FILE" down || error "Failed to stop Jellyfin services!"

    log_detail "Pulling latest Jellyfin Docker images..."
    pull_output=$(run_and_capture docker compose -f "$JELLYFIN_COMPOSE_FILE" pull) \
        || error "Jellyfin Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Jellyfin         Up to date"
    else
        add_summary "[OK]    Jellyfin         Updated"
    fi

    log_detail "Starting Jellyfin services..."
    run_silent docker compose -f "$JELLYFIN_COMPOSE_FILE" up -d || error "Jellyfin Docker Compose Up failed!"

    log_detail "Jellyfin Update completed."
fi

# ---------------------------------------------------------------------------
# 2. ========== Memos Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_MEMOS:-}" == "true" ]]; then
    require_compose "Memos" "${MEMOS_COMPOSE_FILE:-}"

    log_detail "Stopping Memos services..."
    run_silent docker compose -f "$MEMOS_COMPOSE_FILE" down || error "Failed to stop Memos services!"

    log_detail "Pulling latest Memos Docker images..."
    pull_output=$(run_and_capture docker compose -f "$MEMOS_COMPOSE_FILE" pull) \
        || error "Memos Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Memos            Up to date"
    else
        add_summary "[OK]    Memos            Updated"
    fi

    log_detail "Starting Memos services..."
    run_silent docker compose -f "$MEMOS_COMPOSE_FILE" up -d || error "Memos Docker Compose Up failed!"

    log_detail "Memos Update completed."
fi

# ---------------------------------------------------------------------------
# 3. ========== Adguard Home Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_ADGUARDHOME:-}" == "true" ]]; then
    require_compose "Adguard Home" "${ADGUARDHOME_COMPOSE_FILE:-}"

    log_detail "Stopping Adguard Home services..."
    run_silent docker compose -f "$ADGUARDHOME_COMPOSE_FILE" down || error "Failed to stop Adguard Home services!"

    log_detail "Pulling latest Adguard Home Docker images..."
    pull_output=$(run_and_capture docker compose -f "$ADGUARDHOME_COMPOSE_FILE" pull) \
        || error "Adguard Home Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    AdGuard Home     Up to date"
    else
        add_summary "[OK]    AdGuard Home     Updated"
    fi

    log_detail "Starting Adguard Home services..."
    run_silent docker compose -f "$ADGUARDHOME_COMPOSE_FILE" up -d || error "Adguard Home Docker Compose Up failed!"

    log_detail "Adguard Home Update completed."
fi

# ---------------------------------------------------------------------------
# 4. ========== Paperless Backup & Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_PAPERLESS:-}" == "true" ]]; then
    require_compose "Paperless" "${PAPERLESS_COMPOSE_FILE:-}"
    [[ -n "${PAPERLESS_DIRECTORY:-}" ]] || error "Paperless is enabled but PAPERLESS_DIRECTORY is not set!"
    [[ -d "$PAPERLESS_DIRECTORY" ]] || error "Paperless directory not found: $PAPERLESS_DIRECTORY"

    log_detail "Starting Paperless Backup..."
    cd "$PAPERLESS_DIRECTORY" || error "Could not change to Paperless directory!"
    run_silent docker compose exec -T webserver document_exporter ../export -z -d --no-progress-bar || error "Paperless document export failed!"
    cd "$ORIGINAL_DIR" || error "Could not change back to home directory!"

    log_detail "Stopping Paperless services..."
    run_silent docker compose -f "$PAPERLESS_COMPOSE_FILE" down || error "Failed to stop Paperless services!"

    log_detail "Pulling latest Paperless Docker images..."
    pull_output=$(run_and_capture docker compose -f "$PAPERLESS_COMPOSE_FILE" pull) \
        || error "Paperless Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Paperless        Up to date"
    else
        add_summary "[OK]    Paperless        Updated"
    fi

    log_detail "Starting Paperless services..."
    run_silent docker compose -f "$PAPERLESS_COMPOSE_FILE" up -d || error "Paperless Docker Compose Up failed!"

    log_detail "Paperless Backup & Update completed."
fi

# ---------------------------------------------------------------------------
# 5. ========== PhotoPrism Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_PHOTOPRISM:-}" == "true" ]]; then
    log_detail "Stopping PhotoPrism service..."
    run_silent sudo systemctl stop pod-photoprism.service || error "Failed to stop PhotoPrism image!"

    log_detail "Pulling latest PhotoPrism images..."
    pull_output=$(run_and_capture sudo podman pull docker.io/photoprism/photoprism:latest) \
        || error "Failed to pull PhotoPrism image!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    PhotoPrism       Up to date"
    else
        add_summary "[OK]    PhotoPrism       Updated"
    fi

    log_detail "Starting PhotoPrism service..."
    run_silent sudo systemctl start pod-photoprism.service || error "Failed to start PhotoPrism!"

    log_detail "PhotoPrism Update completed."
fi

# ---------------------------------------------------------------------------
# 6. ========== qbittorrent Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_QBITTORRENT:-}" == "true" ]]; then
    require_compose "qbittorrent" "${QBITTORRENT_COMPOSE_FILE:-}"

    log_detail "Stopping qbittorrent services..."
    run_silent docker compose -f "$QBITTORRENT_COMPOSE_FILE" down || error "Failed to stop qbittorrent services!"

    log_detail "Pulling latest qbittorrent Docker images..."
    pull_output=$(run_and_capture docker compose -f "$QBITTORRENT_COMPOSE_FILE" pull) \
        || error "qbittorrent Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    qBittorrent      Up to date"
    else
        add_summary "[OK]    qBittorrent      Updated"
    fi

    log_detail "Starting qbittorrent services..."
    run_silent docker compose -f "$QBITTORRENT_COMPOSE_FILE" up -d || error "qbittorrent Docker Compose Up failed!"

    log_detail "qbittorrent Update completed."
fi

# ---------------------------------------------------------------------------
# 7. ========== Dockpeek Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_DOCKPEEK:-}" == "true" ]]; then
    require_compose "Dockpeek" "${DOCKPEEK_COMPOSE_FILE:-}"

    log_detail "Stopping Dockpeek services..."
    run_silent docker compose -f "$DOCKPEEK_COMPOSE_FILE" down || error "Failed to stop Dockpeek services!"

    log_detail "Pulling latest Dockpeek Docker images..."
    pull_output=$(run_and_capture docker compose -f "$DOCKPEEK_COMPOSE_FILE" pull) \
        || error "Dockpeek Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Dockpeek         Up to date"
    else
        add_summary "[OK]    Dockpeek         Updated"
    fi

    log_detail "Starting Dockpeek services..."
    run_silent docker compose -f "$DOCKPEEK_COMPOSE_FILE" up -d || error "Dockpeek Docker Compose Up failed!"

    log_detail "Dockpeek Update completed."
fi

# ---------------------------------------------------------------------------
# 8. ========== OmniTools Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_OMNITOOLS:-}" == "true" ]]; then
    require_compose "OmniTools" "${OMNITOOLS_COMPOSE_FILE:-}"

    log_detail "Stopping OmniTools services..."
    run_silent docker compose -f "$OMNITOOLS_COMPOSE_FILE" down || error "Failed to stop OmniTools services!"

    log_detail "Pulling latest OmniTools Docker images..."
    pull_output=$(run_and_capture docker compose -f "$OMNITOOLS_COMPOSE_FILE" pull) \
        || error "OmniTools Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    OmniTools        Up to date"
    else
        add_summary "[OK]    OmniTools        Updated"
    fi

    log_detail "Starting OmniTools services..."
    run_silent docker compose -f "$OMNITOOLS_COMPOSE_FILE" up -d || error "OmniTools Docker Compose Up failed!"

    log_detail "OmniTools Update completed."
fi

# ---------------------------------------------------------------------------
# 9. ========== Homepage Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_HOMEPAGE:-}" == "true" ]]; then
    require_compose "Homepage" "${HOMEPAGE_COMPOSE_FILE:-}"

    log_detail "Stopping Homepage services..."
    run_silent docker compose -f "$HOMEPAGE_COMPOSE_FILE" down || error "Failed to stop Homepage services!"

    log_detail "Pulling latest Homepage Docker images..."
    pull_output=$(run_and_capture docker compose -f "$HOMEPAGE_COMPOSE_FILE" pull) \
        || error "Homepage Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Homepage         Up to date"
    else
        add_summary "[OK]    Homepage         Updated"
    fi

    log_detail "Starting Homepage services..."
    run_silent docker compose -f "$HOMEPAGE_COMPOSE_FILE" up -d || error "Homepage Docker Compose Up failed!"

    log_detail "Homepage Update completed."
fi

# ---------------------------------------------------------------------------
# 10. ========== Pangolin Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_PANGOLIN:-}" == "true" ]]; then
    require_compose "Pangolin" "${PANGOLIN_COMPOSE_FILE:-}"

    log_detail "Stopping Pangolin services..."
    run_silent docker compose -f "$PANGOLIN_COMPOSE_FILE" down || error "Failed to stop Pangolin services!"

    log_detail "Pulling latest Pangolin Docker images..."
    pull_output=$(run_and_capture docker compose -f "$PANGOLIN_COMPOSE_FILE" pull) \
        || error "Pangolin Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    Pangolin         Up to date"
    else
        add_summary "[OK]    Pangolin         Updated"
    fi

    log_detail "Starting Pangolin services..."
    run_silent docker compose -f "$PANGOLIN_COMPOSE_FILE" up -d || error "Pangolin Docker Compose Up failed!"

    log_detail "Pangolin Update completed."
fi

# ---------------------------------------------------------------------------
# 11. ========== OpenWebUI Update ==========
# ---------------------------------------------------------------------------
if [[ "${UPDATE_OPENWEBUI:-}" == "true" ]]; then
    require_compose "OpenWebUI" "${OPENWEBUI_COMPOSE_FILE:-}"

    log_detail "Stopping OpenWebUI services..."
    run_silent docker compose -f "$OPENWEBUI_COMPOSE_FILE" down || error "Failed to stop OpenWebUI services!"

    log_detail "Pulling latest OpenWebUI Docker images..."
    pull_output=$(run_and_capture docker compose -f "$OPENWEBUI_COMPOSE_FILE" pull) \
        || error "OpenWebUI Docker Compose Pull failed!"

    if _is_up_to_date "$pull_output"; then
        add_summary "[OK]    OpenWebUI        Up to date"
    else
        add_summary "[OK]    OpenWebUI        Updated"
    fi

    log_detail "Starting OpenWebUI services..."
    run_silent docker compose -f "$OPENWEBUI_COMPOSE_FILE" up -d || error "OpenWebUI Docker Compose Up failed!"

    log_detail "OpenWebUI Update completed."
fi

# ---------------------------------------------------------------------------
# 12. ========== Docker System Prune ==========
# ---------------------------------------------------------------------------
log_detail "Removing unused Docker containers, images, networks, and build cache..."
docker_prune_output=$(docker system prune -a -f 2>&1)
docker_prune_exit=$?
echo "$docker_prune_output" >> "$LOG_FILE"

if [[ $docker_prune_exit -eq 0 ]]; then
    docker_reclaimed=$(echo "$docker_prune_output" | grep -i "total reclaimed space" || echo "Total reclaimed space: N/A")
    add_summary "[OK]    Docker Prune     ${docker_reclaimed}"
else
    add_summary "[FAIL]  Docker Prune     Failed (see log)"
fi

# ---------------------------------------------------------------------------
# 13. ========== Podman System Prune ==========
# ---------------------------------------------------------------------------
log_detail "Removing unused Podman containers, images, networks, and build cache..."
podman_prune_output=$(podman system prune -a -f 2>&1)
podman_prune_exit=$?
echo "$podman_prune_output" >> "$LOG_FILE"

if [[ $podman_prune_exit -eq 0 ]]; then
    podman_reclaimed=$(echo "$podman_prune_output" | grep -i "total reclaimed space" || echo "Total reclaimed space: N/A")
    add_summary "[OK]    Podman Prune     ${podman_reclaimed}"
else
    add_summary "[FAIL]  Podman Prune     Failed (see log)"
fi

# ---------------------------------------------------------------------------
# Summary Report (stdout -> email, also appended to log)
# ---------------------------------------------------------------------------
{
    echo ""
    echo "============================================================"
    echo "==== ${DATE} - SERVICES UPDATE SUMMARY ===="
    echo "============================================================"
    echo -n "$SUMMARY"
    echo "============================================================"
} | tee -a "$LOG_FILE"

exit 0
